# 机库二级菜单的像素风贴图（2 倍像素格，硬边，限定色板）。用法：python3 tools/gen_hub_ui.py（项目根目录）
#   frame9.png       主面板：倒角 + 灰边 + 四角琥珀角标            九宫格边距 12
#   card9.png        内卡片：深灰底 + 细边                          九宫格边距 6
#   card9_on.png     选中卡片：琥珀边 + 暖色底                      九宫格边距 6
#   avf9.png         头像框：黑描边 + 金属斜面 + 角钉              九宫格边距 10
#   avf9_on.png      头像框（选中）：琥珀金属
#   avf9_lead.png    头像框（主角）：金色 + 角部三角饰
#   tag9.png         小标签底（等级、稀有度）                       九宫格边距 4
from PIL import Image

K = 2
BLACK = (8, 8, 10, 255)
D1 = (20, 21, 24)
D2 = (30, 32, 37)
D3 = (38, 40, 45)
G1 = (52, 55, 61)
G2 = (78, 83, 92)
G3 = (122, 128, 138)
G4 = (180, 184, 190)
A0 = (60, 40, 14)
A1 = (110, 70, 14)
A2 = (150, 96, 14)
A3 = (205, 135, 20)
A4 = (255, 176, 32)
A5 = (255, 206, 84)
A6 = (255, 232, 160)


def canvas(w, h):
    return [[(0, 0, 0, 0) for _ in range(w)] for _ in range(h)]


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


def save(g, name):
    h, w = len(g), len(g[0])
    im = Image.new("RGBA", (w * K, h * K))
    px = im.load()
    for y in range(h):
        for x in range(w):
            for dy in range(K):
                for dx in range(K):
                    px[x * K + dx, y * K + dy] = g[y][x]
    im.save("assets/ui/" + name)


def chamfer_box(w, h, ch, layers, body):
    """layers: 由外到内的描边色；ch: 倒角像素数。"""
    g = canvas(w, h)
    for y in range(h):
        for x in range(w):
            # 到各边的距离
            d = min(x, y, w - 1 - x, h - 1 - y)
            # 倒角：角部按对角距离
            cx = min(x, w - 1 - x)
            cy = min(y, h - 1 - y)
            if cx + cy < ch:
                continue
            dd = min(d, cx + cy - ch)
            if dd < len(layers):
                c = layers[dd]
                if callable(c):
                    c = c(x, y, w, h)
                g[y][x] = rgba(c)
            else:
                g[y][x] = rgba(body) if len(body) == 4 else rgba(body, 255)
    return g


def bevel(light, dark):
    def f(x, y, w, h):
        return light if (x + y) < (w + h) / 2 - (abs(x - y) * 0) and (y < h / 2 or x < w / 2) and not (x > w / 2 and y > h / 2) else dark
    return f


def frame9():
    w = h = 24
    g = chamfer_box(w, h, 2, [BLACK, G2, (14, 15, 18)], (18, 19, 22, 232))
    # 顶部高光一条
    for x in range(3, w - 3):
        g[1][x] = rgba(G3)
    # 四角琥珀角标（L 形，长 4）
    for (sx, sy, dx, dy) in [(1, 1, 1, 1), (w - 2, 1, -1, 1), (1, h - 2, 1, -1), (w - 2, h - 2, -1, -1)]:
        for i in range(2, 6):
            g[sy][sx + dx * i] = rgba(A4)
            g[sy + dy * i][sx] = rgba(A4)
        g[sy + dy][sx + dx] = rgba(A4)
    save(g, "frame9.png")


def card9(on=False):
    w = h = 12
    if on:
        g = chamfer_box(w, h, 1, [A3], (70, 46, 14, 210))
        for x in range(2, w - 2):
            g[1][x] = rgba(A1)
        g[1][1] = rgba(A5)
        g[h - 2][w - 2] = rgba(A5)
    else:
        g = chamfer_box(w, h, 1, [G1], (26, 27, 31, 215))
        for x in range(2, w - 2):
            g[1][x] = rgba(D3)
    save(g, "card9_on.png" if on else "card9.png")


def avatar_frame(kind):
    w = h = 16
    if kind == "lead":
        hi, mid, lo = A6, A4, A2
    elif kind == "on":
        hi, mid, lo = A5, A3, A1
    else:
        hi, mid, lo = G4, G2, G1
    g = canvas(w, h)
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            cx, cy = min(x, w - 1 - x), min(y, h - 1 - y)
            if cx + cy < 1:
                continue
            if d == 0:
                g[y][x] = BLACK
            elif d == 1:
                # 左上亮、右下暗的金属斜面
                g[y][x] = rgba(hi if (x <= y and x < w - 2) or (y == 1 and x < w - 2) else mid) if (x == 1 or y == 1) else rgba(lo)
            elif d == 2:
                g[y][x] = rgba(mid if (x == 2 or y == 2) else lo)
            elif d == 3:
                g[y][x] = BLACK
    # 角钉
    for (x, y) in [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]:
        g[y][x] = rgba(hi)
    if kind == "lead":
        # 角部三角饰（覆盖外缘）
        for (sx, sy, dx, dy) in [(0, 0, 1, 1), (w - 1, 0, -1, 1)]:
            for i in range(3):
                for j in range(3 - i):
                    g[sy + dy * i][sx + dx * j] = rgba(A5)
            g[sy][sx] = (0, 0, 0, 0)
    save(g, "avf9_%s.png" % kind if kind != "n" else "avf9.png")


def tag9():
    w, h = 8, 8
    g = chamfer_box(w, h, 1, [BLACK], (A3[0], A3[1], A3[2], 255))
    for x in range(2, w - 2):
        g[1][x] = rgba(A5)
    save(g, "tag9.png")
    g = chamfer_box(w, h, 1, [BLACK], (G1[0], G1[1], G1[2], 255))
    for x in range(2, w - 2):
        g[1][x] = rgba(G2)
    save(g, "tag9_g.png")


frame9()
card9(False)
card9(True)
avatar_frame("n")
avatar_frame("on")
avatar_frame("lead")
tag9()
print("ok")
