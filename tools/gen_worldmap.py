# 降落页像素大地图生成器（v0.7.2）。
#
# 输入：tools/worldmap/data/<战区>.json —— 由 `godot --headless --path . -- --worldmap_export` 导出，
#       是游戏自己的地图生成代码（scripts/raid.gd，经 tools/worldmap/export_raid.gd 固定种子调用）跑出来的实际数据。
# 输出：assets/ui/worldmap/wm_1m.png / wm_2m.png / wm_4m.png  三档底图（1 美术像素 = 1 / 2 / 4 米）
#       assets/ui/worldmap/worldmap.json                      界面用的元数据（战区方块位置、撤离点、遗迹、转场口）
#       tools/worldmap/out/worldmap_full.png                   带标注的整张大地图（原尺寸，审图用）
#
# 世界观：虚构的大型城市群。每个战区是 360 米见方的方块，方块内逐像素按游戏生成数据绘制（区块地表、道路、河流湖泊、
# 铁路、山脊巨石、桥、建筑占地、树木杂物），坐标 1:1 对应游戏世界坐标（-180~180 米）；方块按 scripts/world_link.gd 的
# LINKS 邻接拼成网格，方块之间是 72 米宽的环路带（环路 + 跨界河道），道路与河流在环路带里接续；网格外是同风格的郊野、
# 水库、卫星城、农场带、东湾海岸与外环高速。零号深渊井是竖井，画成裂谷矿区下方的「地下剖面」插图。
#
# 建筑：游戏每局 rng.randomize()，建筑 / 树木的有无与尺寸每局随机，但街区地块网格是确定的。大型建筑（占地 > 10 m²）
# 按导出的 N 个种子统计，某格在 ≥ 50% 的种子里被建筑占用才画成建筑；小型物件（树、矮墙、杂物）取示例种子 1。
# 地形、道路、河湖、铁路、桥、遗迹位置、地标、撤离候选点与游戏每局完全一致。
#
# 用色只取 tools/px_lib.py 的 63 色色板（保存前逐像素断言），硬边无抗锯齿。需要 numpy + Pillow。
import base64
import json
import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import px_lib  # noqa: E402

ROOT = px_lib.ROOT
DATA = os.path.join(ROOT, "tools/worldmap/data")
OUT_UI = os.path.join(ROOT, "assets/ui/worldmap")
OUT_REV = os.path.join(ROOT, "tools/worldmap/out")
FONT = os.path.join(ROOT, "assets/fonts/fusion-pixel-12px-zh_hans.ttf")

T = 360          # 战区边长（米 = 1m 底图像素）
HALF = 180
G = 72           # 环路带宽
ML, MR, MT = 200, 260, 160
ROAD_W = 10      # 环路
HWY_W = 16       # 外环高速
LANE = -20       # 跨界河道相对环路带中线的偏移

P = set(px_lib.PALETTE)


def C(*rgb):
    assert tuple(rgb) in P, rgb
    return np.array(rgb, dtype=np.uint8)


# ---------------------------------------------------------------- 色
OUT = C(8, 8, 10)
SHADOW = C(19, 20, 18)
ZG = {  # 区块地表：(主色, 斑驳色)
    "D": (C(78, 80, 72), C(73, 69, 70)), "R": (C(76, 81, 79), C(89, 79, 85)), "I": (C(64, 66, 57), C(73, 69, 70)),
    "H": (C(52, 53, 48), C(64, 66, 57)), "Y": (C(73, 69, 70), C(90, 51, 35)), "M": (C(52, 53, 48), C(28, 46, 45)),
    "P": (C(55, 120, 60), C(30, 60, 35)), "F": (C(150, 97, 13), C(110, 70, 14)), "W": (C(130, 103, 90), C(115, 86, 85)),
    "T": (C(28, 46, 45), C(30, 60, 35)), "C": (C(89, 79, 85), C(76, 81, 79)), "S": (C(50, 24, 70), C(110, 50, 140)),
    "K": (C(46, 41, 40), C(35, 33, 35)),
}
SIDEWALK = C(102, 103, 89)
FARM_ROW = C(110, 70, 14)
WATER = C(45, 75, 140)
WATER_D = C(24, 36, 70)
WATER_H = C(102, 166, 255)
MUD = C(46, 41, 40)
DRY_BED = C(196, 172, 157)
DRY_BANK = C(130, 103, 90)
ASPH = C(52, 53, 48)
ASPH_W = C(64, 66, 57)
CURB = C(120, 122, 110)
DASH = C(205, 135, 20)
DIRT = C(130, 103, 90)
DIRT_R = C(115, 86, 85)
DECK = C(140, 138, 120)
RAIL_B = C(46, 41, 40)
RAIL = C(160, 160, 145)
TIE = C(90, 51, 35)
ROCK = C(46, 41, 40)
ROCK_H = C(106, 100, 108)
TREE = C(30, 60, 35)
TREE_H = C(55, 120, 60)
TREE_D = C(28, 46, 45)
DEBRIS = C(35, 33, 35)
HIVE_H = C(224, 133, 255)
VERGE = (C(30, 60, 35), C(28, 46, 45))
SEA = C(24, 36, 70)
SEA_W = C(45, 75, 140)
SHALLOW = C(30, 110, 130)
SAND = C(196, 172, 157)
ROOF = {  # 屋顶：(主, 亮边, 暗边)
    "D": (C(118, 120, 126), C(143, 143, 147), C(89, 79, 85)), "R": (C(150, 40, 35), C(187, 149, 143), C(90, 24, 22)),
    "I": (C(102, 103, 89), C(140, 138, 120), C(64, 66, 57)), "H": (C(150, 97, 13), C(205, 135, 20), C(110, 70, 14)),
    "Y": (C(90, 51, 35), C(130, 103, 90), C(57, 19, 20)), "M": (C(78, 80, 72), C(120, 122, 110), C(52, 53, 48)),
    "F": (C(150, 40, 35), C(187, 149, 143), C(90, 24, 22)), "P": (C(137, 118, 122), C(171, 166, 166), C(89, 79, 85)),
    "W": (C(106, 100, 108), C(136, 131, 132), C(73, 69, 70)), "T": (C(106, 100, 108), C(136, 131, 132), C(73, 69, 70)),
    "C": (C(106, 100, 108), C(136, 131, 132), C(73, 69, 70)), "S": (C(110, 50, 140), C(224, 133, 255), C(50, 24, 70)),
    "K": (C(115, 86, 85), C(158, 140, 142), C(46, 41, 40)),   # 悬崖岩块
}

_pal = np.array(px_lib.PALETTE, dtype=np.int32)


def _darken_table():
    """每个色板色 → 比它暗约 40% 的色板色（投影用）"""
    t = {}
    for c in px_lib.PALETTE:
        d = np.array(c) * 0.58
        i = int(np.argmin(((_pal - d) ** 2).sum(1)))
        t[c] = tuple(int(v) for v in _pal[i])
    return t


DARK = _darken_table()


# ---------------------------------------------------------------- 工具
def noise(h, w, cell, seed):
    rs = np.random.RandomState(seed)
    gh, gw = h // cell + 2, w // cell + 2
    g = rs.rand(gh, gw)
    return np.kron(g, np.ones((cell, cell)))[:h, :w]


def hash2(x, y, s=0):
    v = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return (v ^ (v >> 16)) / 4294967295.0


def seg_dist(X, Z, pts):
    """像素中心到折线的距离（numpy 栅格）"""
    best = np.full(X.shape, 1e9)
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        dx, dz = bx - ax, bz - az
        L = max(dx * dx + dz * dz, 1e-6)
        t = np.clip(((X - ax) * dx + (Z - az) * dz) / L, 0, 1)
        d = np.hypot(X - (ax + t * dx), Z - (az + t * dz))
        best = np.minimum(best, d)
    return best


class Canvas:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.a = np.zeros((h, w, 3), dtype=np.uint8)
        s.water = np.zeros((h, w), dtype=bool)   # 有水（湿河道、湖、海）
        s.road = np.zeros((h, w), dtype=bool)
        yy, xx = np.mgrid[0:h, 0:w]
        s.X = xx + 0.5
        s.Y = yy + 0.5

    def sub(s, x0, y0, w, h):
        x0, y0 = max(0, x0), max(0, y0)
        return slice(y0, min(s.h, y0 + h)), slice(x0, min(s.w, x0 + w))

    def put(s, mask, col, sl=None):
        if sl is None:
            s.a[mask] = col
        else:
            s.a[sl][mask] = col

    def poly(s, pts, w, col, box=None, water=False, road=False):
        """在 box=(x0,y0,w,h) 范围内画粗折线（世界像素坐标）"""
        if box is None:
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            m = w / 2 + 2
            box = (int(min(xs) - m), int(min(ys) - m), int(max(xs) - min(xs) + 2 * m) + 1, int(max(ys) - min(ys) + 2 * m) + 1)
        sl = s.sub(*box)
        d = seg_dist(s.X[sl], s.Y[sl], pts)
        mk = d <= w / 2
        s.a[sl][mk] = col
        if water:
            s.water[sl] |= mk
        if road:
            s.road[sl] |= mk
        return sl, mk

    def disc(s, cx, cy, r, col, water=False):
        box = (int(cx - r - 1), int(cy - r - 1), int(2 * r + 3), int(2 * r + 3))
        sl = s.sub(*box)
        mk = (s.X[sl] - cx) ** 2 + (s.Y[sl] - cy) ** 2 <= r * r
        s.a[sl][mk] = col
        if water:
            s.water[sl] |= mk
        return sl, mk

    def rect(s, x0, y0, w, h, col, road=False):
        sl = s.sub(int(round(x0)), int(round(y0)), int(round(w)), int(round(h)))
        s.a[sl] = col
        if road:
            s.road[sl] = True


# ---------------------------------------------------------------- 布局（由 world_link.LINKS 决定）
def parse_links():
    src = open(os.path.join(ROOT, "scripts/world_link.gd"), encoding="utf-8").read()
    body = src[src.index("const LINKS"):]
    body = body[:body.index("\n}\n")]
    links = {}
    for m in re.finditer(r'"(\w+)":\s*\{([^}]*)\}', body):
        links[m.group(1)] = dict(re.findall(r'"([NSEW])":\s*"(\w+)"', m.group(2)))
    return links


DIRV = {"N": (0, -1), "S": (0, 1), "E": (1, 0), "W": (-1, 0)}
OPP = {"N": "S", "S": "N", "E": "W", "W": "E"}
SHAFTS = {"abyss_maw": "canyon"}   # 竖井战区：画在哪个地表战区下方


def layout(links, ids):
    pos = {"greyport": (0, 0)}
    queue = ["greyport"]
    while queue:
        a = queue.pop(0)
        for e, b in links.get(a, {}).items():
            if b not in pos:
                pos[b] = (pos[a][0] + DIRV[e][0], pos[a][1] + DIRV[e][1])
                queue.append(b)
            else:
                exp = (pos[a][0] + DIRV[e][0], pos[a][1] + DIRV[e][1])
                assert pos[b] == exp, "LINKS 邻接关系不能拼成网格：%s %s %s" % (a, e, b)
    mnx = min(p[0] for p in pos.values())
    mny = min(p[1] for p in pos.values())
    pos = {k: (v[0] - mnx, v[1] - mny) for k, v in pos.items()}
    cols = max(p[0] for p in pos.values()) + 1
    rows = max(p[1] for p in pos.values()) + 1
    # 网格左侧留一列郊野（城市群向西延伸）
    if cols < 3:
        pos = {k: (v[0] + 3 - cols, v[1]) for k, v in pos.items()}
        cols = 3
    return pos, cols, rows


# ---------------------------------------------------------------- 战区方块
def ground(cv, sl, X, Z, zones, seed):
    h, w = X.shape
    n1 = noise(h, w, 3, seed)
    n2 = noise(h, w, 7, seed + 1)
    nz = n1 * 0.55 + n2 * 0.45
    zi = np.clip(((X + HALF) // 40).astype(int), 0, 8)
    zj = np.clip(((Z + HALF) // 40).astype(int), 0, 8)
    zt = np.array([list(r) for r in zones])[zj, zi]
    out = cv.a[sl]
    for z, (a, b) in ZG.items():
        m = zt == z
        if not m.any():
            continue
        out[m] = a
        thr = {"T": 0.45, "P": 0.62, "S": 0.5, "K": 0.55, "F": 0.7}.get(z, 0.66)
        out[m & (nz > thr)] = b
    return zt


def render_tile(cv, d, ox, oy, seed):
    """战区方块：游戏坐标 (x, z) → 底图像素 (ox + x + 180, oy + z + 180)"""
    sl = cv.sub(ox, oy, T, T)
    X = cv.X[sl] - ox - HALF
    Z = cv.Y[sl] - oy - HALF
    zones = d["zones"]
    zt = ground(cv, sl, X, Z, zones, seed)
    a = cv.a[sl]
    tx = lambda x: ox + HALF + x  # noqa: E731
    ty = lambda z: oy + HALF + z  # noqa: E731
    box = (ox, oy, T, T)
    cells = d["cells"]
    # 人行道：城区格子里地块（_cell_rect）以外的一圈
    inside = np.zeros(X.shape, dtype=bool)
    for j in range(9):
        for i in range(9):
            r = cells[j][i]
            inside |= (X >= r[0]) & (X < r[0] + r[2]) & (Z >= r[1]) & (Z < r[1] + r[3])
    urban = np.isin(zt, ["D", "R", "I", "H", "Y"])
    a[urban & ~inside] = SIDEWALK
    # 农田垄线（与小地图一致：地块内每 4.4 米一条）
    for j in range(9):
        for i in range(9):
            if zones[j][i] != "F":
                continue
            r = cells[j][i]
            z = r[1] + 2.0
            while z < r[1] + r[3]:
                m = (np.abs(Z - z) < 0.6) & (X > r[0] + 2) & (X < r[0] + r[2] - 2)
                a[m] = FARM_ROW
                z += 4.4
    # 虫巢菌毯亮斑 / 悬崖高光 / 弹坑
    hv = noise(T, T, 2, seed + 5)
    a[(zt == "S") & (hv > 0.93)] = HIVE_H
    a[(zt == "K") & (hv > 0.9)] = ROCK_H
    for j in range(9):
        for i in range(9):
            if zones[j][i] != "C":
                continue
            for k in range(5):
                cx = -HALF + i * 40 + 6 + hash2(i, j, k) * 28
                cz = -HALF + j * 40 + 6 + hash2(j, i, k + 9) * 28
                r = 2.5 + hash2(i + k, j, 3) * 3.5
                dd = np.hypot(X - cx, Z - cz)
                a[(dd <= r) & (dd > r - 1.2)] = ROCK
                a[dd <= r - 1.2] = DEBRIS
    # 河流（湿：泥岸 w+6 → 水面；干：河岸 w+5 → 沙砾河床）
    rv = d["river"]
    if len(rv["pts"]) > 1:
        pts = [(tx(p[0]), ty(p[1])) for p in rv["pts"]]
        w = rv["w"]
        if rv["dry"]:
            cv.poly(pts, w + 5, DRY_BANK, box)
            cv.poly(pts, w, DRY_BED, box)
        else:
            cv.poly(pts, w + 6, MUD, box)
            cv.poly(pts, w, WATER, box, water=True)
            sl2, mk = cv.poly(pts, max(2, w - 8), WATER, box, water=True)
    for lk in d["lakes"]:
        cv.disc(tx(lk[0]), ty(lk[1]), lk[2] + 2, MUD)
    for lk in d["lakes"]:
        cv.disc(tx(lk[0]), ty(lk[1]), lk[2], WATER, water=True)
    # 水面波纹
    wm = cv.water[sl]
    wn = noise(T, T, 2, seed + 7)
    a[wm & (wn > 0.9)] = WATER_H
    a[wm & (wn < 0.06)] = WATER_D
    # 道路：自由路（土路 / 柏油带路缘），再画网格路
    for c in d["curves"]:
        pts = [(tx(p[0]), ty(p[1])) for p in c["pts"]]
        if c["dirt"]:
            cv.poly(pts, c["w"], DIRT, box, road=True)
            cv.poly(pts, max(1.0, c["w"] - 5), DIRT_R, box)
            cv.poly(pts, max(1.0, c["w"] - 7), DIRT, box)
        else:
            cv.poly(pts, c["w"], CURB, box, road=True)
            cv.poly(pts, c["w"] - 2.4, ASPH_W if c["w"] >= 11 else ASPH, box)
    for r in d["roads"]:
        x, z, w, h = r["rect"]
        if r["dirt"]:
            cv.rect(tx(x), ty(z), w, h, DIRT, road=True)
        else:
            cv.rect(tx(x), ty(z), w, h, CURB, road=True)
            cv.rect(tx(x) + 1.2, ty(z) + 1.2, w - 2.4, h - 2.4, ASPH_W if r["w"] >= 11 else ASPH)
    cv.road[sl] &= True
    # 宽路中线虚线（只画在直的网格路上）
    for r in d["roads"]:
        if r["dirt"] or r["w"] < 11:
            continue
        x, z, w, h = r["rect"]
        if r["v"]:
            cx = int(tx(x + w / 2))
            for yy in range(int(ty(z)), int(ty(z + h))):
                if (yy // 4) % 2 == 0 and oy <= yy < oy + T:
                    cv.a[yy, cx] = DASH
        else:
            cy = int(ty(z + h / 2))
            for xx in range(int(tx(x)), int(tx(x + w))):
                if (xx // 4) % 2 == 0 and ox <= xx < ox + T:
                    cv.a[cy, xx] = DASH
    # 桥
    for b in d["bridges"]:
        pts = [(tx(b[0][0]), ty(b[0][1])), (tx(b[1][0]), ty(b[1][1]))]
        cv.poly(pts, b[2] + 1.5, OUT, box)
        cv.poly(pts, b[2] - 1.0, DECK, box)
    # 铁路
    for l in d["rails"]:
        pts = [(tx(l[0][0]), ty(l[0][1])), (tx(l[1][0]), ty(l[1][1]))]
        cv.poly(pts, 4.0, RAIL_B, box)
        sl3, mk = cv.poly(pts, 3.0, RAIL_B, box)
        Xs, Ys = cv.X[sl3], cv.Y[sl3]
        horiz = abs(pts[1][0] - pts[0][0]) >= abs(pts[1][1] - pts[0][1])
        ties = mk & (((Xs if horiz else Ys).astype(int) % 3) == 0)
        cv.a[sl3][ties] = TIE
        cv.poly(pts, 1.0, RAIL, box)
    # 山脊巨石
    for p in d["ridge_pts"]:
        cv.disc(tx(p[0]), ty(p[1]), 2.6, OUT)
        cv.disc(tx(p[0]), ty(p[1]), 2.0, ROCK)
        cv.disc(tx(p[0]) - 0.6, ty(p[1]) - 0.6, 1.0, ROCK_H)
    # 小型物件（示例种子 1）：树林 / 公园里画树冠，其余画矮墙杂物
    for r in d["blocks_seed1"]:
        if r[2] * r[3] > 10.0:
            continue
        cx, cz = r[0] + r[2] / 2, r[1] + r[3] / 2
        if abs(cx) >= HALF or abs(cz) >= HALF:
            continue
        if cv.road[int(ty(cz)), int(tx(cx))]:
            continue   # 路上的废车 / 火桶每局随机，不画
        z = zones[min(8, int((cz + HALF) // 40))][min(8, int((cx + HALF) // 40))]
        if z in "TP" and r[2] < 2.0 and r[3] < 2.0:
            px, py = tx(cx), ty(cz)
            cv.disc(px + 0.8, py + 0.8, 2.2, DARK_C(cv, px + 2, py + 2))
            cv.disc(px, py, 2.0, TREE if z == "T" else TREE_D)
            cv.a[int(py) - 1, int(px) - 1] = TREE_H
        else:
            x0, y0 = int(math.floor(tx(r[0]))), int(math.floor(ty(r[1])))
            x1, y1 = int(math.ceil(tx(r[0] + r[2]))), int(math.ceil(ty(r[1] + r[3])))
            ys_, xs_ = slice(max(oy, y0), min(oy + T, y1)), slice(max(ox, x0), min(ox + T, x1))
            cv.a[ys_, xs_][~cv.road[ys_, xs_]] = DEBRIS
    # 大型建筑：≥50% 种子占用
    occ = np.frombuffer(base64.b64decode(d["occ_big_b64"]), dtype=np.uint8).reshape(T, T)
    bm = occ >= max(1, (d["seeds"] + 1) // 2)
    bm &= ~cv.road[cv.sub(ox, oy, T, T)]   # 道路优先：个别种子里挪到路上的地标 / 碎墙不画
    draw_buildings(cv, ox, oy, bm, zt)
    # 方块描边留给界面画（底图不画）


def DARK_C(cv, x, y):
    x, y = int(min(max(x, 0), cv.w - 1)), int(min(max(y, 0), cv.h - 1))
    return np.array(DARK[tuple(int(v) for v in cv.a[y, x])], dtype=np.uint8)


def shade(cv, sl, mask):
    """mask 范围内的像素换成各自的暗色（投影）"""
    sub = cv.a[sl]
    if not mask.any():
        return
    cols = sub[mask]
    keys = cols[:, 0].astype(np.int32) * 65536 + cols[:, 1].astype(np.int32) * 256 + cols[:, 2]
    out = cols.copy()
    for k in np.unique(keys):
        c = (int(k) >> 16, (int(k) >> 8) & 255, int(k) & 255)
        out[keys == k] = DARK.get(c, (19, 20, 18))
    sub[mask] = out


def draw_buildings(cv, ox, oy, bm, zt):
    sl = cv.sub(ox, oy, bm.shape[1], bm.shape[0])
    # 投影：右下 2 像素
    sh = np.zeros_like(bm)
    sh[2:, 2:] = bm[:-2, :-2]
    sh[1:, 1:] |= bm[:-1, :-1]
    shade(cv, sl, sh & ~bm & ~cv.road[sl])
    a = cv.a[sl]
    up = np.zeros_like(bm)
    up[1:, :] = bm[:-1, :]
    dn = np.zeros_like(bm)
    dn[:-1, :] = bm[1:, :]
    lf = np.zeros_like(bm)
    lf[:, 1:] = bm[:, :-1]
    rt = np.zeros_like(bm)
    rt[:, :-1] = bm[:, 1:]
    edge = bm & ~(up & dn & lf & rt)
    for z, (m, hi, lo) in ROOF.items():
        zm = bm & (zt == z)
        if not zm.any():
            continue
        a[zm] = m
        a[zm & ~up] = hi          # 上沿高光
        a[zm & ~lf] = hi
        a[zm & ~dn] = lo          # 下沿 / 右沿暗边
        a[zm & ~rt] = lo
    a[edge & ~dn & ~rt] = OUT
    # 屋顶设备点
    ys, xs = np.nonzero(bm & up & dn & lf & rt)
    for y, x in zip(ys, xs):
        if hash2(int(x + ox), int(y + oy), 4) > 0.985 and zt[y, x] != "K":
            a[y, x] = OUT


# ---------------------------------------------------------------- 郊野填充（虚构）
def suburb(cv, x0, y0, w, h, seed, kind):
    """填充格：kind = suburb 卫星城 / farm 农场带 / forest 林场 / hills 山地"""
    sl = cv.sub(x0, y0, w, h)
    hh, ww = cv.a[sl].shape[:2]
    n = noise(hh, ww, 3, seed) * 0.55 + noise(hh, ww, 9, seed + 1) * 0.45
    a = cv.a[sl]
    if kind == "suburb":
        a[:] = ZG["R"][0]
        a[n > 0.66] = ZG["R"][1]
        bm = np.zeros((hh, ww), dtype=bool)
        zt = np.full((hh, ww), "R")
        step = 60
        for gx in range(0, ww, step):
            cv.rect(x0 + gx, y0, 8, hh, CURB, road=True)
            cv.rect(x0 + gx + 1, y0, 6, hh, ASPH)
        for gy in range(0, hh, step):
            cv.rect(x0, y0 + gy, ww, 8, CURB, road=True)
            cv.rect(x0, y0 + gy + 1, ww, 6, ASPH)
        for gx in range(0, ww, step):
            for gy in range(0, hh, step):
                park = hash2(gx, gy, seed) < 0.18
                for lx in range(12, step - 8, 16):
                    for ly in range(12, step - 8, 16):
                        if park:
                            a[gy + ly - 4:gy + ly + 8, gx + lx - 4:gx + lx + 8] = ZG["P"][0]
                            if hash2(lx, ly, gx + gy) < 0.5:
                                cv.disc(x0 + gx + lx + 2, y0 + gy + ly + 2, 2.0, TREE)
                            continue
                        if hash2(gx + lx, gy + ly, seed) < 0.78:
                            bw = 6 + int(hash2(lx, gy, seed) * 4)
                            bh = 6 + int(hash2(gx, ly, seed) * 4)
                            bm[gy + ly:gy + ly + bh, gx + lx:gx + lx + bw] = True
        bm &= ~cv.road[sl]
        draw_buildings(cv, x0, y0, bm, zt)
    elif kind == "farm":
        a[:] = ZG["F"][0]
        for k in range(0, hh, 5):
            a[k, :] = FARM_ROW
        pat = noise(hh, ww, 50, seed)
        a[pat > 0.7] = ZG["W"][0]
        a[(pat > 0.7) & (n > 0.6)] = ZG["W"][1]
        bm = np.zeros((hh, ww), dtype=bool)
        for k in range(10):
            fx = int(hash2(k, 1, seed) * (ww - 30)) + 10
            fy = int(hash2(k, 2, seed) * (hh - 30)) + 10
            bm[fy:fy + 8, fx:fx + 9] = True
            bm[fy + 2:fy + 9, fx + 12:fx + 20] = True
        draw_buildings(cv, x0, y0, bm, np.full((hh, ww), "F"))
    elif kind == "forest":
        a[:] = TREE_D
        a[n > 0.5] = TREE
        for k in range(int(ww * hh / 70)):
            tx_ = int(hash2(k, 3, seed) * ww)
            ty_ = int(hash2(k, 4, seed) * hh)
            if n[min(ty_, hh - 1), min(tx_, ww - 1)] > 0.25:
                cv.disc(x0 + tx_ + 0.8, y0 + ty_ + 0.8, 2.2, TREE_D)
                cv.disc(x0 + tx_, y0 + ty_, 2.0, TREE)
                if 0 <= ty_ - 1 < hh and 0 <= tx_ - 1 < ww:
                    a[ty_ - 1, tx_ - 1] = TREE_H
    elif kind == "hills":
        a[:] = TREE_D
        a[n > 0.5] = TREE
        n3 = noise(hh, ww, 2, seed + 3)
        rk = noise(hh, ww, 16, seed + 6) > 0.7
        a[rk] = ZG["K"][0]
        a[rk & (n > 0.55)] = ZG["K"][1]
        a[rk & (n3 > 0.92)] = ROCK_H
        a[~rk & (n3 > 0.95)] = TREE_H
        # 等高线
        cnt = noise(hh, ww, 40, seed + 4) * 0.7 + noise(hh, ww, 13, seed + 8) * 0.3
        q = np.floor(cnt * 7)
        band = (q != np.roll(q, 1, 0)) | (q != np.roll(q, 1, 1))
        a[band] = ZG["K"][0]
    elif kind == "waste":
        a[:] = ZG["W"][0]
        a[n > 0.62] = ZG["W"][1]
        n3 = noise(hh, ww, 2, seed + 3)
        a[n3 > 0.94] = ROCK
    elif kind == "verge":
        a[:] = VERGE[0]
        a[n > 0.6] = VERGE[1]
        n3 = noise(hh, ww, 2, seed + 3)
        a[n3 > 0.95] = TREE
    elif kind == "under":
        a[:] = OUT
        a[n > 0.6] = C(19, 18, 18)
        n3 = noise(hh, ww, 2, seed + 3)
        a[n3 > 0.96] = C(35, 33, 35)


# ---------------------------------------------------------------- 主流程
def edge_crossings(pts, w):
    """折线与战区边界（|x|、|z| = 180）的交点：[(边, 沿边坐标, 交点外侧方向)]"""
    out = []
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        for e in "NSEW":
            if e in "EW":
                lim = HALF if e == "E" else -HALF
                if (ax - lim) * (bx - lim) < 0:
                    t = (lim - ax) / (bx - ax)
                    al = az + t * (bz - az)
                    if abs(al) <= HALF:
                        out.append((e, al))
            else:
                lim = HALF if e == "S" else -HALF
                if (az - lim) * (bz - lim) < 0:
                    t = (lim - az) / (bz - az)
                    al = ax + t * (bx - ax)
                    if abs(al) <= HALF:
                        out.append((e, al))
    return out


def road_ends(d):
    """伸出战区边界的道路：[(边, 沿边坐标, 路宽, 土路)]"""
    out = []
    for r in d["roads"]:
        x, z, w, h = r["rect"]
        if r["v"]:
            c = x + w / 2
            if z <= -HALF:
                out.append(("N", c, r["w"], r["dirt"]))
            if z + h >= HALF:
                out.append(("S", c, r["w"], r["dirt"]))
        else:
            c = z + h / 2
            if x <= -HALF:
                out.append(("W", c, r["w"], r["dirt"]))
            if x + w >= HALF:
                out.append(("E", c, r["w"], r["dirt"]))
    for cv in d["curves"]:
        for e, al in edge_crossings(cv["pts"], cv["w"]):
            out.append((e, al, cv["w"], cv["dirt"]))
    return out


def main():
    links = parse_links()
    maps = {}
    for f in sorted(os.listdir(DATA)):
        if f.endswith(".json"):
            d = json.load(open(os.path.join(DATA, f), encoding="utf-8"))
            maps[d["id"]] = d
    pos, cols, rows = layout(links, list(maps))
    shaft_rows = 1 if any(k in maps and v in pos for k, v in SHAFTS.items()) else 0
    W = ML + cols * T + (cols - 1) * G + MR
    grid_h = MT + rows * T + (rows - 1) * G
    AB_GAP = 112
    H = grid_h + (AB_GAP + T + 72 if shaft_rows else 140)
    cv = Canvas(W, H)
    ox = lambda c: ML + c * (T + G)  # noqa: E731
    oy = lambda r: MT + r * (T + G)  # noqa: E731
    occupied = {v: k for k, v in pos.items()}

    # 1) 底：郊野（北林 / 西山 / 南荒）+ 东湾海
    suburb(cv, 0, 0, W, H, 11, "waste")
    suburb(cv, ML - G, MT - G, cols * T + (cols + 1) * G, rows * T + (rows + 1) * G, 14, "verge")
    suburb(cv, 0, 0, W, MT - G // 2, 12, "forest")
    suburb(cv, 0, 0, ML - G // 2, grid_h, 13, "hills")
    # 网格内空格：按位置给虚构片区
    fill_names = []
    for r in range(rows):
        for c in range(cols):
            if (c, r) in occupied:
                continue
            if c == 0 and r == 0:
                kind, nm = "hills", "北郊山地"
            elif c == 0 and r == rows - 1:
                kind, nm = "farm", "西南农场带"
            elif c == 0:
                kind, nm = "suburb", "西郊卫星城"
            elif r == 0:
                kind, nm = "forest", "东北林场"
            else:
                kind, nm = "suburb", "卫星城"
            suburb(cv, ox(c), oy(r), T, T, 100 + r * 10 + c, kind)
            fill_names.append([nm, ox(c) + T // 2, oy(r) + T // 2 + (110 if kind == "hills" else 0)])
    # 东湾：海岸线在外环高速东侧
    coast_x = ox(cols - 1) + T + G // 2 + HWY_W // 2 + 30
    yy = np.arange(H)
    shore = coast_x + (np.sin(yy / 37.0) * 9 + np.sin(yy / 13.0 + 1) * 4).astype(int)
    for y in range(H):
        sx = shore[y]
        cv.a[y, sx:] = SEA
        cv.a[y, sx - 6:sx] = SAND
        cv.a[y, sx:sx + 5] = SHALLOW
        cv.water[y, sx:] = True
    wv = noise(H, W, 3, 77)
    sea_m = cv.water & (wv > 0.93)
    cv.a[sea_m] = SEA_W

    # 2) 战区方块位置（先画环路带，再画方块：方块会覆盖伸进去的接驳段，边界因此是干净的）
    tile_origin = {}
    for mid, (c, r) in pos.items():
        if mid in maps:
            tile_origin[mid] = (ox(c), oy(r))
    for mid, parent in SHAFTS.items():
        if mid in maps and parent in tile_origin:
            tile_origin[mid] = (tile_origin[parent][0], grid_h + AB_GAP)

    def W2(mid, x, z):
        o = tile_origin[mid]
        return (o[0] + HALF + x, o[1] + HALF + z)

    # 3) 环路带：河道（跨界接续）先画，再画环路、外环高速、道路接驳
    vx = [ML - G // 2] + [ox(c) + T + G // 2 for c in range(cols - 1)] + [ox(cols - 1) + T + G // 2]
    hy = [MT - G // 2] + [oy(r) + T + G // 2 for r in range(rows - 1)] + [grid_h + G // 2]
    rivers = []   # (pts, w, dry)
    done = set()
    for mid in pos:
        if mid not in maps:
            continue
        rv = maps[mid]["river"]
        if len(rv["pts"]) < 2:
            continue
        for e, al in edge_crossings(rv["pts"], rv["w"]):
            key = (mid, e)
            if key in done:
                continue
            done.add(key)
            c, r = pos[mid]
            dx, dy = DIRV[e]
            nb = occupied.get((c + dx, r + dy))
            p0 = W2(mid, *((HALF if e == "E" else -HALF, al) if e in "EW" else (al, HALF if e == "S" else -HALF)))
            # 环路带河道中线
            if e in "EW":
                lane = (vx[c + 1] if e == "E" else vx[c]) + LANE
                lane_pt = lambda a: (lane, a)  # noqa: E731
            else:
                lane = (hy[r + 1] if e == "S" else hy[r]) + LANE
                lane_pt = lambda a: (a, lane)  # noqa: E731
            if nb and nb in maps and len(maps[nb]["river"]["pts"]) > 1:
                hits = [h for h in edge_crossings(maps[nb]["river"]["pts"], maps[nb]["river"]["w"]) if h[0] == OPP[e]]
                if hits:
                    done.add((nb, OPP[e]))
                    al2 = hits[0][1]
                    p1 = W2(nb, *((HALF if OPP[e] == "E" else -HALF, al2) if OPP[e] in "EW" else (al2, HALF if OPP[e] == "S" else -HALF)))
                    a0 = p0[1] if e in "EW" else p0[0]
                    a1 = p1[1] if e in "EW" else p1[0]
                    pts = [p0, lane_pt(a0), lane_pt(a1), p1]
                    w = max(rv["w"], maps[nb]["river"]["w"])
                    rivers.append((pts, w, rv["dry"] and maps[nb]["river"]["dry"]))
                    continue
            # 无接续：网格外缘 → 直接向外流（东边入海）；内侧 → 沿环路带走到空格再拐进去
            ext = (c + dx < 0 or c + dx >= cols or r + dy < 0 or r + dy >= rows)
            if ext:
                far = (W + 10, p0[1]) if e == "E" else ((-10, p0[1]) if e == "W" else ((p0[0], -10) if e == "N" else (p0[0], H + 10)))
                rivers.append(([p0, far], rv["w"], rv["dry"]))
            elif (c + dx, r + dy) not in occupied:
                # 相邻是郊野空格：直流进去，湿河在格心汇成水库，干河床在格里散开
                tc, tr = c + dx, r + dy
                cx_, cy_ = ox(tc) + T // 2, oy(tr) + T // 2
                if e in "EW":
                    mid_pt = ((cx_ + p0[0]) / 2, p0[1])
                    end = (cx_ - 60 * dx, (p0[1] + cy_) / 2)
                else:
                    mid_pt = (p0[0], (cy_ + p0[1]) / 2)
                    end = ((p0[0] + cx_) / 2, cy_ - 60 * dy)
                rivers.append(([p0, mid_pt, end], rv["w"], rv["dry"]))
                if not rv["dry"]:
                    cv.disc(end[0], end[1], 50, MUD)
                    rivers.append(("lake", end, 0))
            else:
                a0 = p0[1] if e in "EW" else p0[0]
                # 找最近的空格（沿环路带向西 / 北）
                tgt = None
                for k in range(1, cols + rows):
                    for cand in ([(c - k, r + dy)] if e in "NS" else [(c + dx, r - k)]):
                        if 0 <= cand[0] < cols and 0 <= cand[1] < rows and cand not in occupied:
                            tgt = cand
                            break
                    if tgt:
                        break
                if tgt is None:
                    continue
                cx_, cy_ = ox(tgt[0]) + T // 2, oy(tgt[1]) + T // 2
                if e in "NS":
                    pts = [p0, lane_pt(a0), (cx_, lane), (cx_, cy_ + 40)]
                else:
                    pts = [p0, lane_pt(a0), (lane, cy_), (cx_ - 40, cy_)]
                rivers.append((pts, rv["w"], rv["dry"]))
                cv.disc(cx_, cy_, 58, MUD)
                cv.disc(cx_ + 22, cy_ + 18, 40, MUD)
                rivers.append(("lake", (cx_, cy_), 0))
    for rv in rivers:
        if rv[0] == "lake":
            (cx_, cy_) = rv[1]
            cv.disc(cx_, cy_, 55, WATER, water=True)
            cv.disc(cx_ + 22, cy_ + 18, 37, WATER, water=True)
            fill_names.append(["北郊水库", cx_, cy_ - 70])
            continue
        pts, w, dry = rv
        if dry:
            cv.poly(pts, w + 5, DRY_BANK)
            cv.poly(pts, w, DRY_BED)
        else:
            cv.poly(pts, w + 6, MUD)
            cv.poly(pts, w, WATER, water=True)
    # 环路 / 外环高速（遇水自动成桥）
    def gutter_road(pts, w, wide):
        sl, mk = cv.poly(pts, w, CURB)
        wet = mk & cv.water[sl]
        cv.road[sl] |= mk
        sl2, mk2 = cv.poly(pts, w - 2, ASPH_W if wide else ASPH)
        cv.a[sl][wet] = OUT
        sl3, mk3 = cv.poly(pts, w - 3, ASPH_W)
        cv.a[sl3][mk3 & cv.water[sl3]] = DECK
        # 中线
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        if abs(x1 - x0) > abs(y1 - y0):
            for x in range(int(min(x0, x1)), int(max(x0, x1))):
                if (x // 5) % 2 == 0 and 0 <= x < W and 0 <= int(y0) < H and not cv.water[int(y0), x]:
                    cv.a[int(y0), x] = DASH
                    if wide:
                        cv.a[int(y0) - 3, x] = CURB
                        cv.a[int(y0) + 3, x] = CURB
        else:
            for y in range(int(min(y0, y1)), int(max(y0, y1))):
                if (y // 5) % 2 == 0 and 0 <= y < H and 0 <= int(x0) < W and not cv.water[y, int(x0)]:
                    cv.a[y, int(x0)] = DASH
                    if wide:
                        cv.a[y, int(x0) - 3] = CURB
                        cv.a[y, int(x0) + 3] = CURB
    top, bot = hy[0], hy[-1]
    lft, rgt = vx[0], vx[-1]
    # 道路接驳：伸出边界的路接到环路中线
    stubs = []
    for mid in pos:
        if mid not in maps:
            continue
        c, r = pos[mid]
        for e, al, w, dirt in road_ends(maps[mid]):
            if e in "EW":
                gx = vx[c + 1] if e == "E" else vx[c]
                p0 = W2(mid, HALF if e == "E" else -HALF, al)
                stubs.append(([(p0[0], p0[1]), (gx, p0[1])], w, dirt))
            else:
                gy = hy[r + 1] if e == "S" else hy[r]
                p0 = W2(mid, al, HALF if e == "S" else -HALF)
                stubs.append(([(p0[0], p0[1]), (p0[0], gy)], w, dirt))
    for pts, w, dirt in stubs:
        sl, mk = cv.poly(pts, w, DIRT if dirt else CURB)
        wet = mk & cv.water[sl]
        cv.road[sl] |= mk
        if not dirt:
            cv.poly(pts, w - 2.4, ASPH)
        cv.a[sl][wet] = OUT
        sl3, mk3 = cv.poly(pts, max(1, w - 2), DECK)
        cv.a[sl3][mk3 & ~cv.water[sl3]] = (DIRT if dirt else ASPH)
    for i, x in enumerate(vx):
        wide = i in (0, len(vx) - 1)
        gutter_road([(x, top), (x, bot)], HWY_W if wide else ROAD_W, wide)
    for i, y in enumerate(hy):
        wide = i in (0, len(hy) - 1)
        gutter_road([(lft, y), (rgt, y)], HWY_W if wide else ROAD_W, wide)
    # 外环高速出城：西去 / 北去 / 南去，东接港口
    for y in hy[1:-1]:
        gutter_road([(0, y), (lft, y)], HWY_W, True)
    for x in vx[1:-1]:
        gutter_road([(x, 0), (x, top)], HWY_W, True)
        gutter_road([(x, bot), (x, H if not shaft_rows else bot + 40)], HWY_W, True)
    # 转场口（各种子众数）在方块边上的通道：没有路接驳的地方补一段土路
    gates_meta = []
    for mid in pos:
        if mid not in maps:
            continue
        c, r = pos[mid]
        for g in maps[mid]["gates"]:
            al = max(set(g["along"]), key=g["along"].count)
            e = g["edge"]
            gates_meta.append({"map": mid, "edge": e, "to": g["to"], "along": al, "lo": min(g["along"]), "hi": max(g["along"]),
                               "freq": round(g["along"].count(al) / len(g["along"]), 2)})
            near = any(s_e == e and abs(s_al - al) < 14 for s_e, s_al, _, _ in road_ends(maps[mid]))
            if not near:
                if e in "EW":
                    gx = vx[c + 1] if e == "E" else vx[c]
                    p0 = W2(mid, HALF if e == "E" else -HALF, al)
                    pts = [p0, (gx, p0[1])]
                else:
                    gy = hy[r + 1] if e == "S" else hy[r]
                    p0 = W2(mid, al, HALF if e == "S" else -HALF)
                    pts = [p0, (p0[0], gy)]
                sl, mk = cv.poly(pts, 8, DIRT)
                cv.a[sl][mk & cv.water[sl]] = DECK
    # 4) 战区方块
    for i, (mid, (c, r)) in enumerate(sorted(pos.items())):
        if mid in maps:
            render_tile(cv, maps[mid], ox(c), oy(r), 1000 + i * 17)
    for mid, parent in SHAFTS.items():
        if mid in maps and parent in tile_origin:
            ax, ay = tile_origin[mid]
            suburb(cv, ax - 24, ay - 24, T + 48, T + 48, 900, "under")
            render_tile(cv, maps[mid], ax, ay, 2000)
    # 竖井：裂谷矿区南缘 → 地下剖面，竖井虚线
    shaft_meta = None
    for mid, parent in SHAFTS.items():
        if mid in tile_origin and parent in tile_origin:
            px0, py0 = tile_origin[parent]
            sx = px0 + T // 2
            for y in range(py0 + T + 4, tile_origin[mid][1] - 24):
                if (y // 4) % 2 == 0:
                    cv.a[y, sx - 1:sx + 2] = C(255, 176, 33)
            shaft_meta = {"map": mid, "parent": parent, "x": sx, "y0": py0 + T, "y1": tile_origin[mid][1] - 24}
    # 郊野里的建筑不能压在环路上：已在 suburb 处理；断言色板
    flat = cv.a.reshape(-1, 3)
    u = np.unique(flat, axis=0)
    bad = [tuple(int(v) for v in c) for c in u if tuple(int(v) for v in c) not in P]
    assert not bad, "出现色板外的颜色：%s" % bad[:5]

    os.makedirs(OUT_UI, exist_ok=True)
    os.makedirs(OUT_REV, exist_ok=True)
    img = Image.fromarray(cv.a, "RGB")
    img.save(os.path.join(OUT_UI, "wm_1m.png"), optimize=True)
    for k in (2, 4):
        down(cv.a, k).save(os.path.join(OUT_UI, "wm_%dm.png" % k), optimize=True)

    meta = {"w": W, "h": H, "tile": T, "half": HALF, "gutter": G, "levels": [1, 2, 4], "maps": {}, "gates": gates_meta, "fill_labels": fill_names,
            "shaft": shaft_meta}
    for mid, (x0, y0) in tile_origin.items():
        d = maps[mid]
        meta["maps"][mid] = {"x": x0, "y": y0, "name": d["name"], "grid": list(pos.get(mid, (-1, -1))),
                             "extracts": d["extracts"], "pois": [{"x": round(p["x"], 1), "z": round(p["z"], 1), "id": p["id"], "name": p["name"]} for p in d["pois"]],
                             "landmarks": landmarks_meta(d),
                             "underground": mid in SHAFTS}
    json.dump(meta, open(os.path.join(OUT_UI, "worldmap.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    annotate(img, meta, maps).save(os.path.join(OUT_REV, "worldmap_full.png"), optimize=True)
    print("worldmap %dx%d maps=%s" % (W, H, sorted(tile_origin)))


def landmarks_meta(d):
    """地标：被街区占住时游戏会就近挪位（随建筑随机），取各种子众数位置，并给出范围"""
    out = []
    samples = d.get("landmark_samples") or [[l] for l in d["landmarks"]]
    for i, l in enumerate(d["landmarks"]):
        ps = [(s_["x"], s_["z"]) for s_ in samples[i]] if i < len(samples) else [(l["x"], l["z"])]
        mode = max(set(ps), key=ps.count)
        out.append({"type": l["type"], "x": mode[0], "z": mode[1], "x_lo": min(p[0] for p in ps), "x_hi": max(p[0] for p in ps),
                    "z_lo": min(p[1] for p in ps), "z_hi": max(p[1] for p in ps), "freq": round(ps.count(mode) / len(ps), 2)})
    return out


def down(a, k):
    """k 倍缩小：每块取出现最多的颜色（不产生新颜色）"""
    h, w = a.shape[0] // k, a.shape[1] // k
    blk = a[:h * k, :w * k].reshape(h, k, w, k, 3).transpose(0, 2, 1, 3, 4).reshape(h, w, k * k, 3)
    key = blk[..., 0].astype(np.int32) * 65536 + blk[..., 1].astype(np.int32) * 256 + blk[..., 2]
    out = np.zeros((h, w, 3), dtype=np.uint8)
    srt = np.sort(key, axis=2)
    # 众数：排序后最长连续段
    best = srt[:, :, 0].copy()
    bestn = np.ones((h, w), dtype=np.int32)
    run = np.ones((h, w), dtype=np.int32)
    for i in range(1, k * k):
        same = srt[:, :, i] == srt[:, :, i - 1]
        run = np.where(same, run + 1, 1)
        upd = run > bestn
        bestn = np.where(upd, run, bestn)
        best = np.where(upd, srt[:, :, i], best)
    out[..., 0] = best >> 16
    out[..., 1] = (best >> 8) & 255
    out[..., 2] = best & 255
    return Image.fromarray(out, "RGB")


def annotate(img, meta, maps):
    """审图用：叠战区边框、名牌、撤离点、遗迹、转场口、地名（界面里这些是实时绘制的）"""
    im = img.copy()
    dr = ImageDraw.Draw(im)
    dr.fontmode = "1"
    font = ImageFont.truetype(FONT, 12)
    amber = (255, 176, 33)
    green = (115, 217, 102)
    cyan = (77, 217, 242)
    cream = (219, 214, 191)

    def label(x, y, t, col=cream, bg=(8, 8, 10)):
        tw = int(dr.textlength(t, font=font))
        dr.rectangle([x - tw // 2 - 3, y - 8, x + tw // 2 + 2, y + 7], fill=bg)
        dr.text((x - tw // 2, y - 7), t, font=font, fill=col)

    for mid, m in meta["maps"].items():
        x0, y0 = m["x"], m["y"]
        dr.rectangle([x0 - 2, y0 - 2, x0 + T + 1, y0 + T + 1], outline=(8, 8, 10), width=2)
        dr.rectangle([x0 - 4, y0 - 4, x0 + T + 3, y0 + T + 3], outline=amber if not m["underground"] else (110, 50, 140), width=2)
        for e in m["extracts"]:
            x, y = x0 + HALF + e["x"], y0 + HALF + e["z"]
            dr.rectangle([x - 4, y - 4, x + 3, y + 3], fill=(8, 8, 10))
            dr.rectangle([x - 2, y - 2, x + 1, y + 1], fill=green)
        for p in m["pois"]:
            x, y = x0 + HALF + p["x"], y0 + HALF + p["z"]
            dr.polygon([(x, y - 5), (x + 5, y), (x, y + 5), (x - 5, y)], fill=(8, 8, 10))
            dr.polygon([(x, y - 3), (x + 3, y), (x, y + 3), (x - 3, y)], fill=amber)
        for lb in maps[mid]["labels"]:
            pass
        label(x0 + HALF, y0 + 14, m["name"] + ("（地下竖井）" if m["underground"] else ""), amber)
    for g in meta["gates"]:
        m = meta["maps"][g["map"]]
        x0, y0 = m["x"], m["y"]
        e, al = g["edge"], g["along"]
        if e in "EW":
            x = x0 + (T - 3 if e == "E" else 0)
            dr.rectangle([x, y0 + HALF + al - 16, x + 2, y0 + HALF + al + 16], fill=cyan)
        else:
            y = y0 + (T - 3 if e == "S" else 0)
            dr.rectangle([x0 + HALF + al - 16, y, x0 + HALF + al + 16, y + 2], fill=cyan)
    for nm, x, y in meta["fill_labels"]:
        label(int(x), int(y), nm, (160, 160, 145))
    return im


if __name__ == "__main__":
    main()
