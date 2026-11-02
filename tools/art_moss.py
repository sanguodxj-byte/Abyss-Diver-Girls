"""远程 ComfyUI 上的 MOSS-Image 生图客户端。

用途：本机不跑模型，只通过 HTTP 把任务交给远程 ComfyUI（Colab 上的 L4），取回生成的图。

接口地址取环境变量 ART_COMFY_HOST（例如 https://xxxx.trycloudflare.com 或 127.0.0.1:8188）；
本机 ComfyUI 与远程共用这一份客户端，只有节点图不同。

用法：
    python tools\\art_moss.py txt2img --prompt "..." --out review\\x.png
    python tools\\art_moss.py txt2img --prompt "..." --out out\\a.png --lora lora_moss_anime:1.0
    python tools\\art_moss.py img2img --init out\\base.png --prompt "..." --out out\\smile.png --denoise 0.35

成功时打印一行 JSON：{"file": 输出路径, "seed": 种子, "seconds": 耗时}
失败时退出码非 0，并把远程报错原样打印出来。

节点图与远程模型对应关系：
    UNETLoader   moss25d_int8.safetensors
    CLIPLoader   qwen35_int8.safetensors  type=moss_image
    VAELoader    flux2vae.safetensors
    KSampler     euler / sgm_uniform / steps 40 / cfg 3.0
"""

import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request
import uuid

HOST_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_host.txt")


def resolve_host():
    """接口地址优先级：环境变量 ART_COMFY_HOST → tools\\art_host.txt → 本机 8188。"""
    env = os.environ.get("ART_COMFY_HOST", "").strip()
    if env:
        return env.rstrip("/")
    try:
        with open(HOST_FILE, encoding="utf-8") as f:
            host = f.read().strip()
        if host:
            return host.rstrip("/")
    except OSError:
        pass
    return "http://127.0.0.1:8188"


HOST = resolve_host()
UNET = os.environ.get("ART_MOSS_UNET", "moss25d_int8.safetensors")
CLIP = os.environ.get("ART_MOSS_CLIP", "qwen35_int8.safetensors")
VAE = os.environ.get("ART_MOSS_VAE", "flux2vae.safetensors")


def _post_json(path, obj, timeout=120):
    body = json.dumps(obj).encode("utf-8")
    req = urllib.request.Request(HOST + path, data=body, headers={"Content-Type": "application/json"}, method="POST")
    return json.load(urllib.request.urlopen(req, timeout=timeout))


def _get_json(path, timeout=60):
    return json.load(urllib.request.urlopen(HOST + path, timeout=timeout))


def _upload(local_path):
    """把本地图送进远程 ComfyUI 的 input 目录，返回远程文件名。"""
    boundary = "----abyss" + uuid.uuid4().hex
    name = os.path.basename(local_path)
    with open(local_path, "rb") as f:
        data = f.read()
    parts = []
    parts.append(("--" + boundary + "\r\n").encode())
    parts.append(('Content-Disposition: form-data; name="image"; filename="%s"\r\n' % name).encode())
    parts.append(b"Content-Type: image/png\r\n\r\n")
    parts.append(data)
    parts.append(b"\r\n")
    parts.append(("--" + boundary + "\r\n").encode())
    parts.append(b'Content-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n')
    parts.append(("--" + boundary + "--\r\n").encode())
    req = urllib.request.Request(HOST + "/upload/image", data=b"".join(parts),
                                 headers={"Content-Type": "multipart/form-data; boundary=" + boundary}, method="POST")
    res = json.load(urllib.request.urlopen(req, timeout=180))
    return res.get("name", name)


def build_graph(prompt, negative, width, height, seed, steps, cfg, loras, init_name=None, denoise=1.0):
    g = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": negative}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "abyss"}},
    }
    # 模型链：底模 → 若干 LoRA（只改模型，不改文本编码器）
    model_ref = ["1", 0]
    for i, (name, strength) in enumerate(loras):
        nid = str(20 + i)
        g[nid] = {"class_type": "LoraLoaderModelOnly",
                  "inputs": {"model": model_ref, "lora_name": name, "strength_model": strength}}
        model_ref = [nid, 0]
    g["6"] = {"class_type": "SkipLayerGuidanceDiTSimple",
              "inputs": {"model": model_ref, "double_layers": "", "single_layers": "22",
                         "start_percent": 0.0, "end_percent": 1.0}}
    if init_name is None:
        g["7"] = {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}}
        latent_ref = ["7", 0]
    else:
        g["30"] = {"class_type": "LoadImage", "inputs": {"image": init_name}}
        g["31"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["30", 0], "vae": ["3", 0]}}
        latent_ref = ["31", 0]
    g["8"] = {"class_type": "KSampler",
              "inputs": {"model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": latent_ref,
                         "seed": seed, "steps": steps, "cfg": cfg, "sampler_name": "euler",
                         "scheduler": "sgm_uniform", "denoise": denoise}}
    g["9"] = {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}}
    return g


def wait_outputs(prompt_id, timeout_s):
    """等这一次任务出结果，返回输出节点里的图片信息。"""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        time.sleep(4)
        try:
            hist = _get_json("/history/" + prompt_id)
        except Exception:
            continue
        item = hist.get(prompt_id)
        if not item:
            continue
        if item.get("status", {}).get("status_str") == "error":
            raise RuntimeError("远程执行失败：" + json.dumps(item.get("status"), ensure_ascii=False)[:1200])
        outs = item.get("outputs") or {}
        if outs:
            images = []
            for node in outs.values():
                images.extend(node.get("images", []))
            if images:
                return images
    raise RuntimeError("等待超时（%d 秒）" % timeout_s)


def download(img, out_path):
    q = "/view?filename=%s&subfolder=%s&type=%s" % (img["filename"], img.get("subfolder", ""), img.get("type", "output"))
    data = urllib.request.urlopen(HOST + q, timeout=300).read()
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(data)
    return len(data)


def main(argv):
    ap = argparse.ArgumentParser(description="远程 ComfyUI 的 MOSS-Image 生图客户端")
    ap.add_argument("mode", choices=["txt2img", "img2img"])
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--negative", default="lowres, worst quality, low quality, jpeg artifacts, watermark, signature, "
                                        "bad anatomy, bad hands, extra digits, fewer digits, blurry, photorealistic, 3d render")
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=int, default=1024)
    ap.add_argument("--height", type=int, default=1024)
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--steps", type=int, default=40)
    ap.add_argument("--cfg", type=float, default=3.0)
    ap.add_argument("--lora", action="append", default=[], help="名字:强度，可重复；名字是远程 models\\loras 里的文件名")
    ap.add_argument("--init")
    ap.add_argument("--denoise", type=float, default=0.35)
    ap.add_argument("--timeout", type=int, default=900)
    a = ap.parse_args(argv)

    seed = a.seed if a.seed >= 0 else random.randint(1, 2 ** 31 - 1)
    loras = []
    for spec in a.lora:
        name, _, strength = spec.partition(":")
        name = name.strip()
        if not name.lower().endswith((".safetensors", ".pt", ".ckpt", ".bin")):
            name += ".safetensors"
        loras.append((name, float(strength) if strength else 1.0))

    init_name = None
    if a.mode == "img2img":
        if not a.init:
            print("img2img 需要 --init", file=sys.stderr)
            return 2
        init_name = _upload(a.init)

    graph = build_graph(a.prompt, a.negative, a.width, a.height, seed, a.steps, a.cfg, loras,
                        init_name=init_name, denoise=a.denoise if a.mode == "img2img" else 1.0)
    t0 = time.time()
    try:
        pid = _post_json("/prompt", {"prompt": graph, "client_id": str(uuid.uuid4())})["prompt_id"]
    except urllib.error.HTTPError as e:
        print("远程拒绝了任务：" + e.read().decode("utf-8", "replace")[:1500], file=sys.stderr)
        return 3
    images = wait_outputs(pid, a.timeout)
    size = download(images[0], a.out)
    print(json.dumps({"file": os.path.abspath(a.out), "seed": seed, "seconds": round(time.time() - t0, 1),
                      "bytes": size, "loras": [n for n, _ in loras]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
