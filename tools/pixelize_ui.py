# 把 assets/ui 下的 UI 贴图统一转成像素风：半分辨率重采样 → 硬边透明 → 限色 → 最近邻放大回原尺寸
# 用法：python3 tools/pixelize_ui.py <原图目录> <输出目录>
import sys, os, glob
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
# 玩家方色板（金属黑灰 + 亮橙黄），外加白/灰用于图标
PAL = [(8, 8, 10), (20, 21, 24), (30, 32, 37), (38, 40, 45), (52, 55, 61), (78, 83, 92), (122, 128, 138),
       (180, 184, 190), (236, 236, 232), (255, 255, 255),
       (60, 40, 14), (110, 70, 14), (150, 96, 14), (205, 135, 20), (255, 176, 32), (255, 206, 84), (255, 232, 160),
       (200, 60, 50), (240, 96, 80), (90, 200, 120), (170, 140, 255)]
pal_img = Image.new("P", (1, 1))
flat = [c for rgb in PAL for c in rgb]
pal_img.putpalette(flat + [0] * (768 - len(flat)))

def chunk(name, w, h):
    if name.startswith("ic_"):
        return 2            # 技能图标：32×32 像素格
    if name in ("corner.png", "radar_ring.png"):
        return 2
    return 2

def pixelize(path, out):
    name = os.path.basename(path)
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    k = chunk(name, w, h)
    sw, sh = max(1, w // k), max(1, h // k)
    small = im.resize((sw, sh), Image.BOX)
    r, g, b, a = small.split()
    rgb = Image.merge("RGB", (r, g, b)).quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB")
    # 透明度量化成 4 档，最低档直接剔除，杜绝半透明羽化边
    a = a.point(lambda v: 0 if v < 48 else (255 if v > 200 else (int(round(v / 64.0)) * 64)))
    small = Image.merge("RGBA", (*rgb.split(), a))
    big = small.resize((sw * k, sh * k), Image.NEAREST)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(big, (0, 0))
    # 尺寸不能整除时，用最近邻补齐最后一行/列
    if sw * k != w or sh * k != h:
        canvas = small.resize((w, h), Image.NEAREST)
    canvas.save(out)

os.makedirs(OUT, exist_ok=True)
for p in sorted(glob.glob(os.path.join(SRC, "*.png"))):
    pixelize(p, os.path.join(OUT, os.path.basename(p)))
print("ok")
