# 像素绘制小库：限色色板 + 画布 + 基础图元（tools/gen_tarkov_px.py、tools/px_icons.py 共用）。
# 约定：所有贴图按「美术像素」绘制，保存时整数倍最近邻放大（界面统一 2 倍，与头像 px48/px20、物品图标一致），
# 保存前每个像素吸附到色板，硬边、无抗锯齿、无渐变。
import glob
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
K = 2  # 1 美术像素 = 2 逻辑像素

# ---------------------------------------------------------------- 色板
# 机库 UI 的橄榄深灰 / 米白（scripts/hub_kit.gd 的 BG0~CREAM）与琥珀（UI.ACCENT）
GRAY = [(8, 8, 10), (14, 15, 14), (19, 20, 18), (24, 25, 23), (29, 30, 28), (36, 37, 34), (41, 41, 37),
        (52, 53, 48), (64, 66, 57), (78, 80, 72), (102, 103, 89), (120, 122, 110), (140, 138, 120),
        (160, 160, 145), (190, 187, 168), (219, 214, 191), (240, 236, 220)]
AMBER = [(60, 40, 14), (110, 70, 14), (150, 97, 13), (205, 135, 20), (255, 176, 33), (255, 206, 84), (255, 232, 160)]
# 状态色与稀有度色（hub_kit OK_C / NG_C、GameData.RARITY_COLORS、模块主色）
ACCENT = [(115, 217, 102), (55, 120, 60), (30, 60, 35), (242, 89, 77), (150, 40, 35), (90, 24, 22),
          (102, 166, 255), (45, 75, 140), (24, 36, 70), (224, 133, 255), (110, 50, 140), (50, 24, 70),
          (77, 217, 242), (30, 110, 130), (180, 240, 250)]


def _avatar_palette(n=28):
    """角色头像（assets/avatars/px48）的合并色板：每人量化 12 色后再合并量化。"""
    cols = []
    for f in sorted(glob.glob(os.path.join(ROOT, "assets/avatars/px48/*.png"))):
        im = Image.open(f).convert("RGB").resize((48, 48), Image.NEAREST)
        q = im.quantize(colors=12, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        pal = q.getpalette()
        for cnt, i in q.getcolors():
            cols.append(tuple(pal[i * 3:i * 3 + 3]))
    if not cols:
        return []
    strip = Image.new("RGB", (len(cols), 1))
    strip.putdata(cols)
    q = strip.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()
    return [tuple(pal[i * 3:i * 3 + 3]) for _, i in q.getcolors()]


AVATAR = _avatar_palette()
PALETTE = []
for c in GRAY + AMBER + ACCENT + AVATAR:
    if c not in PALETTE and not (c[0] + c[1] + c[2] < 6 and (8, 8, 10) in PALETTE):
        PALETTE.append(c)

_snap_cache = {}


def snap(c):
    c = tuple(int(v) for v in c[:3])
    if c in _snap_cache:
        return _snap_cache[c]
    best, bd = None, 1e18
    for p in PALETTE:
        dr, dg, db = c[0] - p[0], c[1] - p[1], c[2] - p[2]
        rm = (c[0] + p[0]) / 2
        d = (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db
        if d < bd:
            bd, best = d, p
    _snap_cache[c] = best
    return best


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def ramp(c):
    """主色 → [暗, 中, 亮, 高光]（吸附色板）"""
    c = tuple(c[:3])
    return [snap(mix(c, (10, 10, 12), 0.45)), snap(c), snap(mix(c, (250, 246, 230), 0.3)), snap(mix(c, (255, 252, 240), 0.6))]


def hexc(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


# 常用色阶（暗 → 亮）
OUT = (8, 8, 10)
METAL = [(52, 53, 48), (102, 103, 89), (160, 160, 145), (219, 214, 191)]
GUN = [(24, 25, 23), (52, 53, 48), (78, 80, 72), (140, 138, 120)]
STEEL = [(36, 37, 34), (78, 80, 72), (120, 122, 110), (190, 187, 168)]
AMB = [(110, 70, 14), (205, 135, 20), (255, 176, 33), (255, 232, 160)]
BRASS = [(60, 40, 14), (150, 97, 13), (205, 135, 20), (255, 206, 84)]
RED = [(90, 24, 22), (150, 40, 35), (242, 89, 77), (255, 206, 84)]
GRN = [(30, 60, 35), (55, 120, 60), (115, 217, 102), (219, 214, 191)]
BLU = [(24, 36, 70), (45, 75, 140), (102, 166, 255), (180, 240, 250)]
CYN = [(30, 110, 130), (77, 217, 242), (180, 240, 250), (240, 236, 220)]
PUR = [(50, 24, 70), (110, 50, 140), (224, 133, 255), (240, 236, 220)]
OLIVE = [(30, 32, 22), (64, 66, 57), (102, 103, 89), (140, 138, 120)]
BROWN = ramp((109, 59, 39))
WOOD = ramp((135, 90, 72))
PAPER = [(140, 138, 120), (190, 187, 168), (219, 214, 191), (240, 236, 220)]
SKIN = ramp((212, 170, 135))
WHITE = (240, 236, 220)
CREAM = (219, 214, 191)


# ---------------------------------------------------------------- 画布
class Cv:
    def __init__(s, w, h, fill=None):
        s.w, s.h = w, h
        f = None if fill is None else _rgba(fill)
        s.p = [[f] * w for _ in range(h)]

    def px(s, x, y, c):
        if c is None:
            return
        x, y = int(x), int(y)
        if 0 <= x < s.w and 0 <= y < s.h:
            s.p[y][x] = _rgba(c)

    def pw(s, x, y, c):
        """平铺纹理用：坐标取模环绕"""
        s.px(int(x) % s.w, int(y) % s.h, c)

    def get(s, x, y):
        if 0 <= x < s.w and 0 <= y < s.h:
            return s.p[y][x]
        return None

    def rect(s, x, y, w, h, c, wrap=False):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                (s.pw if wrap else s.px)(xx, yy, c)

    def srect(s, x, y, w, h, r):
        """左上受光的立体块：中色填充，上 / 左亮，下 / 右暗"""
        s.rect(x, y, w, h, r[1])
        if h >= 2:
            s.rect(x, y + h - 1, w, 1, r[0])
        if w >= 3:
            s.rect(x + w - 1, y, 1, h, r[0])
        s.rect(x, y, w, 1, r[2])
        if w >= 3 and h >= 3:
            s.rect(x, y, 1, h - 1, r[2])

    def frame(s, x, y, w, h, c):
        s.rect(x, y, w, 1, c)
        s.rect(x, y + h - 1, w, 1, c)
        s.rect(x, y, 1, h, c)
        s.rect(x + w - 1, y, 1, h, c)

    def line(s, x0, y0, x1, y1, c, t=1):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            s.rect(x0, y0, t, t, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def disc(s, cx, cy, r, c):
        for y in range(s.h):
            for x in range(s.w):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    s.px(x, y, c)

    def sdisc(s, cx, cy, r, rm):
        for y in range(s.h):
            for x in range(s.w):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                d2 = dx * dx + dy * dy
                if d2 <= r * r:
                    k = (dx + dy) / max(r, 0.01)
                    c = rm[1]
                    if k < -0.7:
                        c = rm[2]
                    if k > 0.75 or d2 > (r - 0.9) ** 2 and k > 0.2:
                        c = rm[0]
                    s.px(x, y, c)
        hx, hy = int(cx - r * 0.45), int(cy - r * 0.45)
        if r >= 2.5:
            s.px(hx, hy, rm[3])

    def ring(s, cx, cy, r0, r1, c):
        for y in range(s.h):
            for x in range(s.w):
                d2 = (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2
                if r0 * r0 < d2 <= r1 * r1:
                    s.px(x, y, c)

    def poly_rows(s, rows, x0, y0, legend):
        """ASCII 小图：rows 为字符串列表，legend 字符 → 颜色（'.' 透明）"""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != "." and ch != " " and ch in legend:
                    s.px(x0 + i, y0 + j, legend[ch])

    def outline(s, c=OUT, diag=False):
        src = [row[:] for row in s.p]
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (-1, -1), (1, -1), (-1, 1)] if diag else [])
        for y in range(s.h):
            for x in range(s.w):
                if src[y][x] is not None and src[y][x][3] > 0:
                    continue
                for dx, dy in nb:
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < s.w and 0 <= yy < s.h and src[yy][xx] is not None and src[yy][xx][3] > 0:
                        s.p[y][x] = _rgba(c)
                        break

    def blit(s, o, x0, y0):
        for y in range(o.h):
            for x in range(o.w):
                if o.p[y][x] is not None:
                    s.px(x0 + x, y0 + y, o.p[y][x])

    def image(s, k=K):
        im = Image.new("RGBA", (s.w, s.h), (0, 0, 0, 0))
        pix = im.load()
        for y in range(s.h):
            for x in range(s.w):
                c = s.p[y][x]
                if c is not None and c[3] > 0:
                    sc = snap(c)
                    pix[x, y] = (sc[0], sc[1], sc[2], c[3])
        if k != 1:
            im = im.resize((s.w * k, s.h * k), Image.NEAREST)
        return im

    def save(s, path, k=K):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        s.image(k).save(path)


def _rgba(c):
    if len(c) == 4:
        return tuple(int(v) for v in c)
    return (int(c[0]), int(c[1]), int(c[2]), 255)


def alpha(c, a):
    return (c[0], c[1], c[2], a)


# 3×5 点阵字（舱壁编号喷漆）
FONT35 = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"], "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "011", "001", "111"], "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"], "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "111"], "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"], "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"], "H": ["101", "101", "111", "101", "101"], "K": ["101", "110", "100", "110", "101"],
    "L": ["100", "100", "100", "100", "111"], "M": ["101", "111", "111", "101", "101"], "N": ["111", "101", "101", "101", "101"],
    "O": ["111", "101", "101", "101", "111"], "P": ["110", "101", "110", "100", "100"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"], "W": ["101", "101", "111", "111", "101"],
    "X": ["101", "101", "010", "101", "101"], "Y": ["101", "101", "010", "010", "010"], "-": ["000", "000", "111", "000", "000"],
    "?": ["111", "001", "011", "000", "010"], " ": ["000"] * 5, "/": ["001", "001", "010", "100", "100"], ".": ["000", "000", "000", "000", "010"],
}


def stencil(cv, text, x, y, c, wrap=False, gap=1):
    for ch in text:
        g = FONT35.get(ch.upper(), FONT35["?"])
        for j, row in enumerate(g):
            for i, b in enumerate(row):
                if b == "1":
                    (cv.pw if wrap else cv.px)(x + i, y + j, c)
        x += 3 + gap
    return x
