import sys, glob, os
from PIL import Image, ImageDraw
tags = sys.argv[1].split(',')
out = sys.argv[2]
rows = []
for t in tags:
    fs = sorted(glob.glob(f'/workspace/work/anim_shots/{t}_*.png'))
    if fs: rows.append((t, fs))
W = 320; H = 180
cols = max(len(f) for _, f in rows)
im = Image.new('RGB', (cols * W, len(rows) * H), (0, 0, 0))
d = ImageDraw.Draw(im)
for r, (t, fs) in enumerate(rows):
    for c, f in enumerate(fs):
        im.paste(Image.open(f).convert('RGB').resize((W, H)), (c * W, r * H))
    d.text((4, r * H + 4), t, fill=(255, 255, 0))
im.save(out)
print(out, im.size)
