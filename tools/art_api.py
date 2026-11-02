"""远端图像接口（OpenAI 兼容）：文生图、带参考图与蒙版的编辑、列出可用模型。

密钥只从环境变量 ART_API_KEY 读取，不落盘、不打印；接口地址取 ART_API_BASE。
蒙版约定与其余 art_ 工具一致：白色 = 要重画的区域，提交前转换成接口要求的透明区蒙版。
"""
import argparse
import base64
import io
import json
import os
import sys
import time

import requests
from PIL import Image

sys.dont_write_bytecode = True  # 工具目录只放源码，同目录模块互相导入时不生成缓存
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_comfy as ac  # noqa: E402

API_BASE = os.environ.get("ART_API_BASE", "https://new.orbitix.site/v1").rstrip("/")
DEFAULT_MODEL = "gpt-image-2.5-flare"
# 全年龄项目：每次请求在提示词末尾追加全年龄着装约束，避免模型自发生成暴露领口。
SAFE_SUFFIX = " Wholesome all-ages illustration, modest clothing, zipped collar, no cleavage, no nsfw."


class ApiError(RuntimeError):
    pass


def _safe_prompt(prompt):
    text = (prompt or "").strip()
    if SAFE_SUFFIX.strip().lower() in text.lower():
        return text
    return text + SAFE_SUFFIX


def _headers():
    key = os.environ.get("ART_API_KEY", "").strip()
    if not key:
        raise ApiError("环境变量 ART_API_KEY 为空")
    return {"Authorization": "Bearer " + key}


def _call(method, path, **kw):
    # 网络错误与 5xx 立即重发，共 3 次，不退避；4xx 是请求本身的问题，直接报错
    last = None
    for _ in range(3):
        try:
            r = requests.request(method, API_BASE + path, headers=_headers(), timeout=900, **kw)
        except requests.RequestException as e:
            last = "网络错误：%s" % type(e).__name__
            continue
        if r.status_code < 500:
            if r.status_code != 200:
                raise ApiError("HTTP %d：%s" % (r.status_code, r.text[:1500]))
            return r.json()
        last = "HTTP %d：%s" % (r.status_code, r.text[:800])
    raise ApiError(last)


def _decode(data):
    out = []
    for item in data.get("data") or []:
        if item.get("b64_json"):
            raw = base64.b64decode(item["b64_json"])
        elif item.get("url"):
            raw = requests.get(item["url"], timeout=300).content
        else:
            continue
        im = Image.open(io.BytesIO(raw))
        im.load()
        out.append(im)
    if not out:
        raise ApiError("响应里没有图像：%s" % json.dumps(data, ensure_ascii=False)[:800])
    return out


def models():
    return sorted(m.get("id") for m in _call("GET", "/models").get("data") or [])


def generate(prompt, model=DEFAULT_MODEL, size="1024x1536", n=1, background=None, quality=None, fmt="png"):
    body = {"model": model, "prompt": _safe_prompt(prompt), "n": n, "size": size, "output_format": fmt}
    if background:
        body["background"] = background
    if quality:
        body["quality"] = quality
    return _decode(_call("POST", "/images/generations", json=body))


def _png(im):
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return buf.getvalue()


def edit(images, prompt, mask=None, model=DEFAULT_MODEL, size=None, background=None, quality=None, fmt="png", n=1):
    ims = [i if isinstance(i, Image.Image) else Image.open(i) for i in images]
    field = "image" if len(ims) == 1 else "image[]"
    files = [(field, ("image%d.png" % k, _png(im), "image/png")) for k, im in enumerate(ims)]
    if mask is not None:
        m = (mask if isinstance(mask, Image.Image) else Image.open(mask)).convert("L").resize(ims[0].size)
        rgba = Image.new("RGBA", m.size, (0, 0, 0, 255))
        rgba.putalpha(m.point(lambda v: 255 - v))
        files.append(("mask", ("mask.png", _png(rgba), "image/png")))
    data = {"model": model, "prompt": _safe_prompt(prompt), "n": str(n), "output_format": fmt}
    if size:
        data["size"] = size
    if background:
        data["background"] = background
    if quality:
        data["quality"] = quality
    return _decode(_call("POST", "/images/edits", data=data, files=files))


def _report(ims, out, model, t0, meta):
    n = len(ims)
    for i, im in enumerate(ims):
        path = ac.numbered(out, i, n)
        ac.save_png(im, path, meta)
        alpha = im.getchannel("A").getextrema() if im.mode == "RGBA" else None
        print(json.dumps({"out": os.path.abspath(path), "model": model, "size": list(im.size), "mode": im.mode,
                          "alpha_range": alpha, "wall_s": round(time.time() - t0, 1)}, ensure_ascii=False), flush=True)


def main():
    ac.stdout_utf8()
    p = argparse.ArgumentParser(description="远端图像接口")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("models")
    for name in ("gen", "edit"):
        s = sub.add_parser(name)
        s.add_argument("--prompt", required=True)
        s.add_argument("--out", required=True)
        s.add_argument("--model", default=DEFAULT_MODEL)
        s.add_argument("--size", default="1024x1536" if name == "gen" else None,
                       help="1024x1024 / 1024x1536 / 1536x1024 / auto")
        s.add_argument("--background", choices=["transparent", "opaque", "auto"])
        s.add_argument("--quality", choices=["low", "medium", "high", "auto"])
        s.add_argument("--n", type=int, default=1)
        if name == "edit":
            s.add_argument("--image", action="append", required=True, help="参考图，可重复")
            s.add_argument("--mask", help="白色 = 重画区域")
            s.add_argument("--box", help="x0,y0,x1,y1 像素或 0～1 比例，按框生成椭圆羽化蒙版")
            s.add_argument("--grow", type=float, default=0.12, help="框外扩比例")
            s.add_argument("--feather", type=float, default=0.015, help="羽化半径占短边比例")
            s.add_argument("--keep-outside", dest="keep_outside", action="store_true",
                           help="结果按蒙版贴回第一张参考图，蒙版外像素与原图一致")
    a = p.parse_args()
    try:
        if a.cmd == "models":
            print(json.dumps(models(), ensure_ascii=False))
            return 0
        t0 = time.time()
        meta = {"tool": "art_api", "cmd": a.cmd, "model": a.model, "prompt": a.prompt, "size": a.size,
                "background": a.background, "quality": a.quality}
        if a.cmd == "gen":
            ims = generate(a.prompt, a.model, a.size, a.n, a.background, a.quality)
        else:
            from art_edit import box_mask
            meta["images"] = [os.path.basename(i) for i in a.image]
            src = Image.open(a.image[0])
            src.load()
            mask = Image.open(a.mask).convert("L").resize(src.size) if a.mask else None
            if mask is None and a.box:
                meta["box"] = ac.parse_box(a.box, src.size)
                mask = box_mask(src.size, meta["box"], a.grow, "ellipse", a.feather)
            ims = edit(a.image, a.prompt, mask, a.model, a.size, a.background, a.quality, n=a.n)
            if a.keep_outside and mask is not None:
                # 接口会重画整张图，按蒙版贴回原图才能保证蒙版外逐像素不变
                mode = "RGBA" if src.mode == "RGBA" else "RGB"
                base = src.convert(mode)
                ims = [Image.composite(im.convert(mode).resize(src.size, Image.LANCZOS), base, mask) for im in ims]
                meta["keep_outside"] = True
        _report(ims, a.out, a.model, t0, meta)
        return 0
    except ApiError as e:
        print("接口错误：%s" % e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
