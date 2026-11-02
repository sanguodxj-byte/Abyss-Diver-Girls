"""去背景：分割模型出前景蒙版，本地合成 RGBA，并把半透明边缘里混进去的背景色剥掉。

剥色按 C = a*F + (1-a)*B 反解前景色 F；B、F 用按透明度加权的大半径模糊做局部估计，
所以复杂背景（不只是纯色底）也能去掉毛边上的底色。
"""
import argparse
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.dont_write_bytecode = True  # 工具目录只放源码，同目录模块互相导入时不生成缓存
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_comfy as ac  # noqa: E402


def mask_of(client, im, model="BiRefNet"):
    g = ac.Graph(client)
    li = g.add("LoadImage", image=client.upload(ac.flatten(im), "cutout.png"))
    names = client.choices("LoadBackgroundRemovalModel", "bg_removal_name")
    bg = g.add("LoadBackgroundRemovalModel", bg_removal_name=ac.resolve(names, model, "去背景模型"))
    m = g.add("RemoveBackground", bg_removal_model=bg[0], image=li[0])
    pv = g.add("PreviewImage", images=g.add("MaskToImage", mask=m[0])[0])
    res = client.run(g)
    out = res.images(pv)
    if not out:
        raise ac.ComfyError("去背景没有返回蒙版")
    mk = out[0].convert("L")
    if mk.size != im.size:
        mk = mk.resize(im.size, Image.LANCZOS)
    return mk, res


def _wblur(rgb, w, k):
    num = cv2.GaussianBlur(rgb * w[..., None], (k, k), 0)
    den = cv2.GaussianBlur(w, (k, k), 0)
    return num / np.maximum(den, 1e-4)[..., None]


def compose(im, mask, floor=0.03, ceil=0.97, defringe=True):
    rgb = np.asarray(ac.flatten(im), dtype=np.float32) / 255.0
    a = np.asarray(mask, dtype=np.float32) / 255.0
    # 两端收紧：分割模型在纯背景上常留 1%～3% 的雾，在实心区也偶有 98% 的洞
    a = np.clip((a - floor) / max(ceil - floor, 1e-3), 0.0, 1.0)
    if defringe:
        k = max(9, (min(a.shape) // 48) | 1)
        fg = _wblur(rgb, a ** 2, k)
        bg = _wblur(rgb, (1.0 - a) ** 2, k)
        safe = np.maximum(a, 0.05)[..., None]
        solved = np.clip((rgb - (1.0 - a[..., None]) * bg) / safe, 0.0, 1.0)
        # 透明度低的像素反解误差大，向局部前景估计过渡
        t = np.clip((a - 0.15) / 0.5, 0.0, 1.0)[..., None]
        edge = solved * t + fg * (1.0 - t)
        inner = (a >= 0.995)[..., None]
        rgb = np.where(inner, rgb, edge)
    out = np.dstack([rgb, a])
    return Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def trim(im, pad):
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if not box:
        return im
    x0, y0, x1, y1 = box
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(im.width, x1 + pad), min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def main():
    ac.stdout_utf8()
    p = argparse.ArgumentParser(description="去背景并输出 RGBA PNG")
    p.add_argument("inputs", nargs="+")
    p.add_argument("--out", help="单张输入时的输出路径")
    p.add_argument("--out-dir", dest="out_dir", help="多张输入时的输出目录，文件名加 --suffix")
    p.add_argument("--suffix", default="_cut")
    p.add_argument("--model", default="BiRefNet", help="去背景模型名或其唯一子串")
    p.add_argument("--trim", type=int, default=-1, help="按不透明区裁边并留出的像素；-1 不裁")
    p.add_argument("--floor", type=float, default=0.03, help="低于此值的透明度归零")
    p.add_argument("--ceil", type=float, default=0.97, help="高于此值的透明度归一")
    p.add_argument("--no-defringe", dest="defringe", action="store_false")
    p.add_argument("--save-mask", dest="save_mask", action="store_true", help="另存 _mask.png 灰度蒙版")
    p.add_argument("--mask-from", dest="mask_from",
                   help="复用已有蒙版：灰度图或 RGBA 图的透明通道；同一立绘的表情差分共用一个轮廓")
    a = p.parse_args()
    a.inputs = ac.expand_inputs(a.inputs)
    if not a.inputs:
        p.error("没有匹配到图片")
    if len(a.inputs) > 1 and not a.out_dir:
        p.error("多张输入需要 --out-dir")
    shared = None
    if a.mask_from:
        ref = Image.open(a.mask_from)
        ref.load()
        # RGBA 的透明通道已经收紧过两端，再收一次会把半透明边吃掉
        shared = (ref.getchannel("A"), True) if ref.mode == "RGBA" else (ref.convert("L"), False)
    client = None
    if shared is None:
        client = ac.Client()
        if not client.online():
            print("生图服务 %s 不在线" % client.host, file=sys.stderr)
            return 2
    for src in a.inputs:
        im = Image.open(src)
        im.load()
        res = None
        if shared is not None:
            mk = shared[0].resize(im.size, Image.LANCZOS) if shared[0].size != im.size else shared[0]
            floor, ceil = (0.0, 1.0) if shared[1] else (a.floor, a.ceil)
        else:
            mk, res = mask_of(client, im, a.model)
            floor, ceil = a.floor, a.ceil
        rgba = compose(im, mk, floor, ceil, a.defringe)
        if a.trim >= 0:
            rgba = trim(rgba, a.trim)
        if a.out and len(a.inputs) == 1:
            dst = a.out
        else:
            stem = os.path.splitext(os.path.basename(src))[0]
            dst = os.path.join(a.out_dir or os.path.dirname(src), stem + a.suffix + ".png")
        meta = dict(ac.read_meta(src))
        meta["cutout"] = {"model": a.model if res else None, "mask_from": os.path.basename(a.mask_from or "") or None,
                          "floor": floor, "ceil": ceil, "defringe": a.defringe, "trim": a.trim}
        ac.save_png(rgba, dst, meta)
        if a.save_mask:
            mk.save(os.path.splitext(dst)[0] + "_mask.png")
        print(json.dumps({"out": os.path.abspath(dst), "size": list(rgba.size),
                          "wall_s": round(res.wall, 1) if res else 0.0, "run_s": round(res.run, 1) if res else 0.0},
                         ensure_ascii=False), flush=True)
    if client is not None:
        # 去背景模型用完即卸载，释放显存与系统内存给后续采样任务
        client.free()
    return 0


if __name__ == "__main__":
    sys.exit(main())
