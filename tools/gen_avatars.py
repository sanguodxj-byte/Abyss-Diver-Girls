# 从立绘裁出头像，生成像素风头像（限色、硬边、整数倍最近邻放大）。
# 用法：python3 tools/gen_avatars.py   （在项目根目录执行）
#   assets/avatars/<id>.png        256×256：64 像素格 ×4（AssetPaths.avatar 约定尺寸）
#   assets/avatars/px48/<id>.png    96×96：48 像素格 ×2（交易/图鉴大头像）
#   assets/avatars/px20/<id>.png    40×40：20 像素格 ×2（顶栏队伍、商人列表小头像）
import os
from PIL import Image

IDS = ["nao", "rei", "kurumi", "lina", "laojiao", "ajin", "xiaoman", "shiori", "karasu", "nihong", "gin"]
# 每人的裁切框（1024 立绘坐标）：中心 x, 中心 y, 边长
DEFAULT = (500, 390, 560)
CROP = {
    "nao": (500, 350, 640),
    "rei": (500, 360, 640),
    "kurumi": (520, 370, 680),
    "lina": (510, 340, 640),
    "laojiao": (500, 380, 640),
    "ajin": (510, 330, 640),
    "xiaoman": (520, 380, 660),
    "shiori": (500, 350, 640),
    "karasu": (500, 360, 640),
    "nihong": (510, 340, 640),
    "gin": (500, 340, 640),
}
SIZES = [("", 64, 4), ("px48", 48, 2), ("px20", 20, 2)]


def crop(im, cid):
    cx, cy, s = CROP.get(cid, DEFAULT)
    h = s // 2
    return im.crop((cx - h, cy - h, cx + h, cy + h))


def pixelate(src, n, colors):
    small = src.resize((n, n), Image.LANCZOS)
    q = small.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    return q


def main():
    root = "assets/avatars"
    for sub, n, k in SIZES:
        os.makedirs(os.path.join(root, sub) if sub else root, exist_ok=True)
    for cid in IDS:
        im = Image.open("assets/portraits/%s.png" % cid).convert("RGB")
        c = crop(im, cid)
        for sub, n, k in SIZES:
            px = pixelate(c, n, 48 if n >= 48 else 24)
            out = px.resize((n * k, n * k), Image.NEAREST)
            out.save(os.path.join(root, sub, cid + ".png") if sub else os.path.join(root, cid + ".png"))
    print("ok", len(IDS))


if __name__ == "__main__":
    main()
