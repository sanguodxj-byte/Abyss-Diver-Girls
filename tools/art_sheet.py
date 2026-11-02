"""拼审阅总览图：多张图按网格等比缩放排版，透明区垫棋盘格，每格下方标文件名。"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True  # 工具目录只放源码，同目录模块互相导入时不生成缓存
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_comfy as ac  # noqa: E402

FONT = os.path.join(ac.ROOT, "NotoSansSC-Subset.ttf")


def checker(size, step=16, c0=(205, 205, 205), c1=(240, 240, 240)):
    w, h = size
    im = Image.new("RGB", size, c1)
    d = ImageDraw.Draw(im)
    for y in range(0, h, step):
        for x in range((y // step) % 2 * step, w, step * 2):
            d.rectangle((x, y, x + step - 1, y + step - 1), fill=c0)
    return im


def fit_text(d, text, font, width):
    if d.textlength(text, font=font) <= width:
        return text
    while text and d.textlength(text + "…", font=font) > width:
        text = text[:-1]
    return text + "…"


def main():
    ac.stdout_utf8()
    p = argparse.ArgumentParser(description="审阅总览图")
    p.add_argument("inputs", nargs="+", help="文件或通配符")
    p.add_argument("--out", required=True)
    p.add_argument("--cols", type=int, default=0, help="列数；0 按数量自动")
    p.add_argument("--cell", type=int, default=384, help="每格长边像素")
    p.add_argument("--gap", type=int, default=12)
    p.add_argument("--no-label", dest="label", action="store_false")
    a = p.parse_args()
    files = ac.expand_inputs(a.inputs, exclude=[a.out])
    if not files:
        print("没有匹配到图片", file=sys.stderr)
        return 1
    n = len(files)
    cols = a.cols or min(n, max(1, int(round(n ** 0.5 * 1.4))))
    rows = (n + cols - 1) // cols
    try:
        font = ImageFont.truetype(FONT, max(12, a.cell // 22))
    except OSError:
        font = ImageFont.load_default()
    lh = (font.size + 10) if a.label and hasattr(font, "size") else (18 if a.label else 0)
    cw, ch = a.cell, a.cell
    W = cols * cw + (cols + 1) * a.gap
    H = rows * (ch + lh) + (rows + 1) * a.gap
    sheet = Image.new("RGB", (W, H), (34, 36, 40))
    d = ImageDraw.Draw(sheet)
    for i, f in enumerate(files):
        r, c = divmod(i, cols)
        x = a.gap + c * (cw + a.gap)
        y = a.gap + r * (ch + lh + a.gap)
        im = Image.open(f)
        im.load()
        im.thumbnail((cw, ch), Image.LANCZOS)
        ox, oy = x + (cw - im.width) // 2, y + (ch - im.height) // 2
        if im.mode in ("RGBA", "LA", "PA") or "transparency" in im.info:
            im = im.convert("RGBA")
            sheet.paste(checker(im.size), (ox, oy))
            sheet.paste(im, (ox, oy), im)
        else:
            sheet.paste(im.convert("RGB"), (ox, oy))
        if a.label:
            name = fit_text(d, os.path.splitext(os.path.basename(f))[0], font, cw)
            d.text((x, y + ch + 4), name, fill=(220, 222, 226), font=font)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    sheet.save(a.out)
    print(os.path.abspath(a.out), sheet.size, n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
