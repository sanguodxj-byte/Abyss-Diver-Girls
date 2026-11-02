"""裁头像：按检测到的脸框取正方形，输出一个或多个边长。

正方形边长 = 脸框高 × zoom，中心按脸框中心下移 shift × 脸框高，让下巴与肩线入画。
同一角色的各表情差分用 --share-box 共用第一张的脸框，切换表情时头像不跳位。
"""
import argparse
import json
import os
import sys

from PIL import Image

sys.dont_write_bytecode = True  # 工具目录只放源码，同目录模块互相导入时不生成缓存
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_comfy as ac  # noqa: E402


def square(box, size, zoom, shift):
    W, H = size
    x0, y0, x1, y1 = box
    fh = max(1, y1 - y0)
    side = min(int(round(fh * zoom)), W, H)
    cx = (x0 + x1) / 2.0
    cy = (y0 + y1) / 2.0 + shift * fh
    left = int(round(cx - side / 2.0))
    top = int(round(cy - side / 2.0))
    left = max(0, min(left, W - side))
    top = max(0, min(top, H - side))
    return left, top, left + side, top + side


def main():
    ac.stdout_utf8()
    p = argparse.ArgumentParser(description="按脸框裁正方形头像")
    p.add_argument("inputs", nargs="+")
    p.add_argument("--out-dir", dest="out_dir", help="缺省与源图同目录")
    p.add_argument("--suffix", default="_avatar")
    p.add_argument("--sizes", default="256", help="逗号分隔的输出边长，例如 256,128,64")
    p.add_argument("--zoom", type=float, default=1.7, help="正方形边长相对脸框高的倍数；检测框已含刘海")
    p.add_argument("--shift", type=float, default=0.1, help="中心相对脸框中心下移的比例")
    p.add_argument("--box", help="直接给脸框 x0,y0,x1,y1（像素或 0～1 比例），跳过检测")
    p.add_argument("--detect", default="face", help="检测目标")
    p.add_argument("--threshold", type=float, default=0.3)
    p.add_argument("--share-box", dest="share_box", action="store_true", help="全部输入共用第一张的脸框")
    a = p.parse_args()
    a.inputs = ac.expand_inputs(a.inputs)
    if not a.inputs:
        p.error("没有匹配到图片")
    sizes = [int(s) for s in a.sizes.split(",") if s.strip()]
    client = None
    shared = None
    if a.share_box and not a.box and a.detect == "face":
        for candidate in a.inputs:
            c_meta = ac.read_meta(candidate)
            c_box = c_meta.get("box") or (c_meta.get("avatar") or {}).get("face_box")
            if isinstance(c_box, list) and len(c_box) == 4:
                shared = tuple(int(x) for x in c_box)
                break
    for src in a.inputs:
        im = Image.open(src)
        im.load()
        src_meta = ac.read_meta(src)
        saved_box = src_meta.get("box") or (src_meta.get("avatar") or {}).get("face_box")
        if a.box:
            box = ac.parse_box(a.box, im.size)
        elif a.share_box and shared:
            box = shared
        elif a.detect == "face" and isinstance(saved_box, list) and len(saved_box) == 4:
            box = tuple(int(x) for x in saved_box)
        else:
            if client is None:
                client = ac.Client()
                if not client.online():
                    print("生图服务 %s 不在线" % client.host, file=sys.stderr)
                    return 2
            box = ac.detect_box(client, im, a.detect, a.threshold)
            if box is None:
                print("%s 没有检测到「%s」" % (src, a.detect), file=sys.stderr)
                return 3
        shared = shared or box
        crop = square(box, im.size, a.zoom, a.shift)
        head = im.crop(crop)
        stem = os.path.splitext(os.path.basename(src))[0]
        outs = []
        for s in sizes:
            dst = os.path.join(a.out_dir or os.path.dirname(os.path.abspath(src)),
                               "%s%s%s.png" % (stem, a.suffix, "" if len(sizes) == 1 else "_%d" % s))
            meta = dict(ac.read_meta(src))
            meta["avatar"] = {"face_box": box, "crop": crop, "size": s, "zoom": a.zoom, "shift": a.shift}
            ac.save_png(head.resize((s, s), Image.LANCZOS), dst, meta)
            outs.append(os.path.abspath(dst))
        print(json.dumps({"src": os.path.abspath(src), "face_box": box, "crop": crop, "out": outs},
                         ensure_ascii=False), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
