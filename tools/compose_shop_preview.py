# -*- coding: utf-8 -*-
"""把立绘黑底转透明后叠到店铺场景做合成预览（flood fill 仅抠边缘连通黑底，不触碰角色内部深色）。"""
from PIL import Image
from collections import deque

SRC = r"D:\123\qianyuanshaonv\assets\portraits\deepseek_ref_v7.png"
SCENE = r"D:\123\qianyuanshaonv\review\shop_scene_1536.png"
OUT = r"D:\123\qianyuanshaonv\review\deepseek_in_shop_preview.png"

char = Image.open(SRC).convert("RGBA")
w, h = char.size
px = char.load()

# 从四边 flood fill：仅抠除与边缘连通的近纯黑背景（TOL 收紧到 12，防止吞掉黑色鞋子）
TOL = 12
def is_dark(p):
    return p[0] <= TOL and p[1] <= TOL and p[2] <= TOL

visited = [[False] * w for _ in range(h)]
q = deque()
for x in range(w):
    for y in (0, h - 1):
        if is_dark(px[x, y]) and not visited[y][x]:
            visited[y][x] = True
            q.append((x, y))
for y in range(h):
    for x in (0, w - 1):
        if is_dark(px[x, y]) and not visited[y][x]:
            visited[y][x] = True
            q.append((x, y))

while q:
    x, y = q.popleft()
    p = px[x, y]
    px[x, y] = (0, 0, 0, 0)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and is_dark(px[nx, ny]):
            visited[ny][nx] = True
            q.append((nx, ny))

# 低饱和深色压纯黑：鞋子等深灰像素在黑底上不易察觉，叠到亮场景会显形发灰；
# 仅压"无色偏的深灰"（三通道都低且彼此接近），深蓝裙/渐变发（B 通道明显高）与金色饰扣不受影响
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        mx, mn = max(r, g, b), min(r, g, b)
        if mx < 70 and (mx - mn) < 28:
            px[x, y] = (0, 0, 0, a)

# 裁剪到角色包围盒
bbox = char.getbbox()
char = char.crop(bbox)
print("cropped char size:", char.size)

# 缩放到目标高度（约场景高的 73%，修正过小）；NEAREST 保持硬边，避免半透明混色脏边
scene = Image.open(SCENE).convert("RGBA")
target_h = int(scene.height * 0.73)
scale = target_h / char.height
char = char.resize((int(char.width * scale), target_h), Image.NEAREST)

# 落位：柜台左前景，脚底贴地
pos_x = 200
pos_y = 846 - char.height
scene.alpha_composite(char, (pos_x, pos_y))
scene.convert("RGB").save(OUT)
print("saved:", OUT, "char drawn at", pos_x, pos_y, "size", char.size)
