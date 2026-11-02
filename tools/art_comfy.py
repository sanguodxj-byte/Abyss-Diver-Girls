"""本地生图服务的通信层：提交 API 格式工作流，经 websocket 等待完成事件，再取回输出图。

其余 art_ 工具共用这里的连接、上传、节点图构建、提示词拼装与 SDXL 常用子图。
"""
import io
import json
import os
import random
import sys
import time
import uuid

import numpy as np
import requests
import websocket
from PIL import Image, PngImagePlugin

HOST = os.environ.get("ART_COMFY_HOST", "127.0.0.1:8188")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "review")
DEFAULT_CKPT = "oneObsession_v24.safetensors"
DEFAULT_LORAS = (
    "Better-Hands-IL.safetensors:0.55",
)

# 全年龄项目：这组负面词对每一次采样强制追加，任何参数都关不掉。
SAFETY_NEG = (
    "nsfw, nude, naked, nipples, underwear, panties, bra, lingerie, swimsuit, bikini, "
    "cleavage, sideboob, underboob, see-through clothes, lewd, suggestive, sexual, erotic, "
    "seductive pose, spread legs, upskirt, pantyshot, large breasts, huge breasts"
)
# 动漫底模通用的画质负面词；做 Logo、字样类素材时可整体替换。
BASE_NEG = (
    "lowres, worst quality, low quality, bad anatomy, bad hands, extra fingers, missing fingers, "
    "fused fingers, extra limbs, deformed, blurry, jpeg artifacts, signature, watermark, "
    "username, text, cropped, out of frame"
)
# 全作锁定的机甲废土日式少女画风正负向公共词。
STYLE_POS = (
    "anime style, clean cel shading, crisp lineart, mecha pilot aesthetic, "
    "soft even lighting, modest practical attire"
)
STYLE_NEG = (
    "backlight, shadowed face, harsh black shadows, dirty face, smudge on face, "
    "3d, photorealistic, glossy oily skin, neon oversaturated, chibi, multiple views, "
    "complex cluttered background, lens flare, hand covering face"
)
QUALITY_POS = "masterpiece, best quality, amazing quality, very aesthetic, absurdres"
# 动漫底模按分级标签训练，general 把采样拉向全年龄分布。
SAFE_POS = "general"

SIZES = {
    "portrait": (832, 1216),
    "bust": (896, 1152),
    "square": (1024, 1024),
    "landscape": (1216, 832),
    "wide": (1344, 768),
    "tall": (768, 1344),
}


def stdout_utf8():
    """管道输出默认走系统代码页，中文会乱码；统一改成 UTF-8。"""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass


class ComfyError(RuntimeError):
    pass


class Client:
    """一个实例对应一个 client_id；websocket 只收到本 client 提交的任务的事件，
    多个工具同时排队也不会串号。"""

    def __init__(self, host=HOST, deadline=7200):
        self.host = host
        self.base = "http://" + host
        self.client_id = uuid.uuid4().hex
        self.deadline = deadline
        self._info = {}

    def get(self, path, **params):
        r = requests.get(self.base + path, params=params or None, timeout=60)
        r.raise_for_status()
        return r

    def online(self):
        try:
            return self.get("/system_stats").json()
        except requests.RequestException:
            return None

    def node_info(self, cls):
        if cls not in self._info:
            data = self.get("/object_info/" + cls).json()
            if cls not in data:
                raise ComfyError("服务端没有节点 " + cls)
            self._info[cls] = data[cls]
        return self._info[cls]

    def choices(self, cls, field):
        spec = self.node_info(cls)["input"]["required"][field]
        if isinstance(spec[0], list):
            return spec[0]
        return spec[1].get("options", [])

    def upload(self, path_or_image, name=None):
        """上传到服务端 input\\art_tools，返回 LoadImage 可直接引用的名字。
        文件名加随机前缀，并行上传同名文件不会互相覆盖。"""
        if isinstance(path_or_image, Image.Image):
            buf = io.BytesIO()
            path_or_image.save(buf, format="PNG")
            data = buf.getvalue()
            base = name or "image.png"
        else:
            with open(path_or_image, "rb") as f:
                data = f.read()
            base = name or os.path.basename(path_or_image)
        stem = os.path.splitext(base)[0]
        fname = "%s_%s.png" % (uuid.uuid4().hex[:8], "".join(c if c.isalnum() or c in "-_" else "_" for c in stem))
        files = {"image": (fname, data, "image/png")}
        r = requests.post(self.base + "/upload/image", files=files,
                          data={"subfolder": "art_tools", "type": "input", "overwrite": "true"}, timeout=120)
        r.raise_for_status()
        info = r.json()
        sub = info.get("subfolder") or ""
        return (sub + "/" if sub else "") + info["name"]

    def run(self, graph):
        """提交并等待完成。先连 websocket 再提交，保证不漏掉开头的事件。"""
        prompt = graph.to_prompt() if isinstance(graph, Graph) else graph
        t0 = time.time()
        ws = websocket.create_connection("ws://%s/ws?clientId=%s" % (self.host, self.client_id), timeout=30)
        try:
            r = requests.post(self.base + "/prompt", json={"prompt": prompt, "client_id": self.client_id}, timeout=120)
            if r.status_code != 200:
                raise ComfyError("提交被拒绝 %d：%s" % (r.status_code, r.text[:2000]))
            pid = r.json()["prompt_id"]
            outputs, t_start = self._listen(ws, pid, t0)
        finally:
            ws.close()
        if not outputs:
            # 命中缓存的输出节点同样经 websocket 回放 executed；这里只在一张图都没收到时，
            # 于完成事件之后读一次历史记录兜底，不做轮询
            outputs = self.history_outputs(pid)
        t1 = time.time()
        return Result(self, pid, outputs, wall=t1 - t0, run=t1 - (t_start or t0))

    def _listen(self, ws, pid, t0):
        outputs = {}
        t_start = None
        end = t0 + self.deadline
        while True:
            left = end - time.time()
            if left <= 0:
                raise ComfyError("任务 %s 超过 %d 秒仍未完成" % (pid, self.deadline))
            ws.settimeout(min(left, 600))
            try:
                msg = ws.recv()
            except websocket.WebSocketTimeoutException:
                # 排在别人的长任务后面时本 client 收不到任何事件，属正常等待
                continue
            if not msg:
                raise ComfyError("websocket 被服务端关闭")
            if not isinstance(msg, str):
                continue  # 二进制帧是采样预览图
            ev = json.loads(msg)
            kind, data = ev.get("type"), ev.get("data") or {}
            if data.get("prompt_id") != pid:
                continue
            if kind == "execution_start":
                t_start = time.time()
            elif kind == "executed" and data.get("output"):
                outputs[str(data["node"])] = data["output"]
            elif kind == "execution_error":
                raise ComfyError("节点 %s(%s) 出错：%s\n%s" % (
                    data.get("node_id"), data.get("node_type"), data.get("exception_message"),
                    "".join(data.get("traceback") or [])[-3000:]))
            elif kind == "execution_interrupted":
                raise ComfyError("任务 %s 被中断" % pid)
            elif kind == "execution_success" or (kind == "executing" and data.get("node") is None):
                return outputs, t_start

    def history_outputs(self, pid):
        h = self.get("/history/" + pid).json().get(pid, {})
        return {str(k): v for k, v in (h.get("outputs") or {}).items()}

    def fetch(self, ref):
        r = self.get("/view", filename=ref["filename"], subfolder=ref.get("subfolder", ""), type=ref.get("type", "output"))
        im = Image.open(io.BytesIO(r.content))
        im.load()
        return im

    def free(self):
        """卸载模型并清空显存缓存，给后面的大模型腾地方。"""
        requests.post(self.base + "/free", json={"unload_models": True, "free_memory": True}, timeout=60)


class Result:
    def __init__(self, client, pid, outputs, wall, run):
        self.client = client
        self.prompt_id = pid
        self.outputs = outputs
        self.wall = wall
        self.run = run

    def images(self, node=None):
        nodes = [str(node.id if isinstance(node, Node) else node)] if node is not None else sorted(self.outputs, key=lambda k: int(k) if k.isdigit() else 0)
        out = []
        for n in nodes:
            for ref in (self.outputs.get(n) or {}).get("images", []):
                out.append(self.client.fetch(ref))
        return out


class Node:
    def __init__(self, nid, cls, inputs):
        self.id = nid
        self.cls = cls
        self.inputs = inputs

    def __getitem__(self, i):
        return [str(self.id), i]


class Graph:
    """API 格式工作流构建器。没给的必填控件取服务端声明的默认值，
    节点新增参数时工作流不会因缺字段被拒收。"""

    def __init__(self, client):
        self.client = client
        self.nodes = []

    def add(self, cls, **inputs):
        node = Node(len(self.nodes) + 1, cls, inputs)
        self.nodes.append(node)
        return node

    def to_prompt(self):
        prompt = {}
        for n in self.nodes:
            req = self.client.node_info(n.cls)["input"].get("required", {})
            full = {}
            for k, spec in req.items():
                if k not in n.inputs:
                    d = _default(spec)
                    if d is not None:
                        full[k] = d
            for k, v in n.inputs.items():
                full[k] = v[0] if isinstance(v, Node) else v
            prompt[str(n.id)] = {"class_type": n.cls, "inputs": full}
        return prompt


def _default(spec):
    kind = spec[0]
    opts = spec[1] if len(spec) > 1 and isinstance(spec[1], dict) else {}
    if isinstance(kind, list):
        return opts.get("default", kind[0] if kind else None)
    if kind == "COMBO":
        o = opts.get("options") or []
        return opts.get("default", o[0] if o else None)
    if kind in ("INT", "FLOAT", "BOOLEAN", "STRING"):
        return opts.get("default", {"INT": 0, "FLOAT": 0.0, "BOOLEAN": False, "STRING": ""}[kind])
    return None


def resolve(choices, want, kind):
    """按 精确名 → 忽略大小写与扩展名 → 唯一子串 的顺序匹配服务端可选项。"""
    if want in choices:
        return want
    def norm(s):
        return os.path.splitext(s.replace("\\", "/").split("/")[-1])[0].lower()
    hits = [c for c in choices if norm(c) == norm(want)]
    if len(hits) != 1:
        hits = [c for c in choices if want.lower() in c.lower()]
    if len(hits) == 1:
        return hits[0]
    raise ComfyError("%s「%s」匹配到 %d 个：%s" % (kind, want, len(hits), ", ".join(hits[:12]) or "无"))


def parse_loras(client, specs):
    """"名字:权重" 列表 → [(服务端文件名, 权重)]，权重缺省 1.0。"""
    names = client.choices("LoraLoader", "lora_name")
    out = []
    for s in specs or []:
        name, sep, w = s.rpartition(":")
        weight = 1.0
        if not sep:
            name = s
        else:
            try:
                weight = float(w)
            except ValueError:
                name = s
        out.append((resolve(names, name, "LoRA"), weight))
    return out


def ckpt_name(client, want):
    return resolve(client.choices("CheckpointLoaderSimple", "ckpt_name"), want or DEFAULT_CKPT, "checkpoint")


def load_sdxl(g, ckpt, loras=(), clip_skip=0):
    ck = g.add("CheckpointLoaderSimple", ckpt_name=ckpt)
    model, clip, vae = ck[0], ck[1], ck[2]
    for name, w in loras:
        lo = g.add("LoraLoader", model=model, clip=clip, lora_name=name, strength_model=w, strength_clip=w)
        model, clip = lo[0], lo[1]
    if clip_skip:
        clip = g.add("CLIPSetLastLayer", clip=clip, stop_at_clip_layer=-abs(clip_skip))[0]
    return model, clip, vae


def join_tags(*parts):
    seen = set()
    out = []
    for p in parts:
        for raw in (p or "").split(","):
            t = raw.strip()
            k = t.lower()
            if t and k not in seen:
                seen.add(k)
                out.append(t)
    return ", ".join(out)


def pos_prompt(text, quality=True, style=True):
    return join_tags(QUALITY_POS if quality else "", SAFE_POS, STYLE_POS if style else "", text)


def neg_prompt(text="", base=BASE_NEG, style=True):
    return join_tags(base, STYLE_NEG if (style and base) else "", text, SAFETY_NEG)


def encode(g, clip, text):
    return g.add("CLIPTextEncode", clip=clip, text=text)[0]


def ksample(g, model, pos, neg, latent, seed, steps=28, cfg=5.5, sampler="euler_ancestral", scheduler="normal", denoise=1.0):
    return g.add("KSampler", model=model, seed=seed, steps=steps, cfg=cfg, sampler_name=sampler,
                 scheduler=scheduler, positive=pos, negative=neg, latent_image=latent, denoise=denoise)[0]


def vae_decode(g, vae, samples, tile_size=512, overlap=64):
    """分块解码潜变量，控制显存激活峰值，避免触发共享显存交换。"""
    return g.add("VAEDecodeTiled", samples=samples, vae=vae, tile_size=tile_size, overlap=overlap)[0]


def vae_encode(g, vae, pixels, tile_size=512, overlap=64):
    """分块编码像素，控制显存激活峰值。"""
    return g.add("VAEEncodeTiled", pixels=pixels, vae=vae, tile_size=tile_size, overlap=overlap)[0]


def new_seed():
    return random.randrange(1, 2 ** 50)


def parse_size(s):
    if s in SIZES:
        return SIZES[s]
    w, _, h = s.lower().partition("x")
    w, h = int(w), int(h)
    # 潜空间按 8 像素对齐，取 64 的倍数让 SDXL 构图更稳
    return max(64, w // 64 * 64), max(64, h // 64 * 64)


def expand_inputs(patterns, exclude=()):
    """命令行参数里的通配符自行展开：Windows 的 cmd 与 PowerShell 不会替程序展开。"""
    import glob
    skip = {os.path.abspath(x) for x in exclude if x}
    out = []
    for pat in patterns:
        hits = sorted(glob.glob(pat)) if any(ch in pat for ch in "*?[") else [pat]
        out.extend(f for f in hits if os.path.isfile(f) and os.path.abspath(f) not in skip and f not in out)
    return out


def parse_box(s, size):
    """"x0,y0,x1,y1"；四个数都在 0～1 之间时按图宽高的比例解释。"""
    v = [float(x) for x in s.replace(" ", "").split(",")]
    if len(v) != 4:
        raise ValueError("框需要 4 个数：" + s)
    if all(0.0 <= x <= 1.0 for x in v):
        w, h = size
        v = [v[0] * w, v[1] * h, v[2] * w, v[3] * h]
    x0, y0, x1, y1 = (int(round(x)) for x in v)
    return min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)


def numbered(path, i, n):
    if n <= 1:
        return path
    stem, ext = os.path.splitext(path)
    return "%s_%02d%s" % (stem, i + 1, ext or ".png")


def save_png(im, path, meta=None):
    """生成参数以 JSON 写进 PNG 的 parameters 文本块，图本身就能复现。"""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    info = None
    if meta:
        info = PngImagePlugin.PngInfo()
        info.add_text("parameters", json.dumps(meta, ensure_ascii=False))
    im.save(path, format="PNG", pnginfo=info)
    return path


def read_meta(path):
    try:
        return json.loads(Image.open(path).info.get("parameters", ""))
    except (ValueError, OSError):
        return {}


def flatten(im, bg=(255, 255, 255)):
    """带透明通道的图压到纯色底上；检测模型只吃 RGB，透明区残留的颜色会造成误检。"""
    if im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        base = Image.new("RGB", im.size, bg)
        base.paste(im, mask=im.split()[3])
        return base
    return im.convert("RGB")


def detect_box(client, image, prompt="face", threshold=0.3, max_frac=0.6):
    """开放词表检测 + 分割，返回面积最大的目标像素框 (x0, y0, x1, y1)；没检到返回 None。
    框面积超过整图 max_frac 的结果视为误检丢弃。"""
    im = image if isinstance(image, Image.Image) else Image.open(image)
    flat = flatten(im)
    g = Graph(client)
    li = g.add("LoadImage", image=client.upload(flat, "detect.png"))
    sam = g.add("SAMModelLoader (segment anything)",
                model_name=resolve(client.choices("SAMModelLoader (segment anything)", "model_name"), "sam_hq_vit_b", "SAM"))
    dino = g.add("GroundingDinoModelLoader (segment anything)",
                 model_name=resolve(client.choices("GroundingDinoModelLoader (segment anything)", "model_name"), "SwinT", "检测模型"))
    seg = g.add("GroundingDinoSAMSegment (segment anything)", sam_model=sam[0], grounding_dino_model=dino[0],
                image=li[0], prompt=prompt, threshold=threshold)
    pv = g.add("PreviewImage", images=g.add("MaskToImage", mask=seg[1])[0])
    res = client.run(g)
    W, H = flat.size
    best, best_area = None, 0
    for mim in res.images(pv):
        a = np.asarray(mim.convert("L")) > 127
        if a.shape != (H, W) or not a.any():
            continue
        ys, xs = np.nonzero(a)
        box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        area = (box[2] - box[0]) * (box[3] - box[1])
        if area > max_frac * W * H:
            continue
        if area > best_area:
            best, best_area = box, area
    # 检测与分割模型用完即卸载，避免与后续 SDXL 大底模同时驻留触发内存交换
    client.free()
    return best
