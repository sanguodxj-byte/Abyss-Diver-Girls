# 降落页像素大地图生成器（v0.8 城市群）。
#
# 输入（都由 `godot --headless --path . -- --worldmap_export` 导出，是游戏自己的生成代码跑出来的实际数据）：
#   tools/worldmap/data/world/world.json        城市群全局要素：河流、湖、铁路、范围、各战区所在格子
#   tools/worldmap/data/world/tile_<x>_<z>.json 每个 360 米格子的确定性布局（scripts/world_city.gd）：区块栅格、道路、建筑轮廓、
#                                               街块、田块、公园、湿地水塘
#   tools/worldmap/data/<战区>.json              战区实际生成一局（固定种子）的局内数据：遗迹、撤离点、地标、转场口、山脊巨石、
#                                               示例种子的小型杂物
# 输出：assets/ui/worldmap/wm_1m.png / wm_2m.png / wm_4m.png  三档底图（1 美术像素 = 1 / 2 / 4 米）
#       assets/ui/worldmap/worldmap.json                      界面用的元数据（战区方块位置、撤离点、遗迹、转场口）
#       tools/worldmap/out/worldmap_full.png                   带标注的整张大地图（原尺寸，审图用）
#
# 世界观：一整片连续的城市群。底图就是世界坐标（灰港市中心 = 0, 0）按 1 米 1 像素平铺，范围见 world.json 的 rect；
# 每个战区是这张图上一块 360 米见方的窗口（游戏坐标 -180~180 → 方块内 0~360 像素），相邻战区共用边界，道路、河流、
# 街区跨边界连续。外围是城市群的边缘地形：东湾海岸与沙滩、河口湿地、东北港区卫星城、西部农田丘陵与山地、北部林带与水库、
# 南部荒漠、东南玄武岩台地，外环高速绕城一圈。零号深渊井是竖井，画成大地图下方的「地下剖面」插图。
#
# 建筑轮廓与高度档是确定的（城市群布局），游戏每局只随机外观细节；地形、道路、河湖、铁路、桥、遗迹、地标、撤离候选点
# 与游戏每局完全一致。
#
# 用色只取 tools/px_lib.py 的色板（保存前逐像素断言），硬边无抗锯齿。需要 numpy + Pillow。
import base64
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import px_lib  # noqa: E402

ROOT = px_lib.ROOT
DATA = os.path.join(ROOT, "tools/worldmap/data")
WDATA = os.path.join(DATA, "world")
OUT_UI = os.path.join(ROOT, "assets/ui/worldmap")
OUT_REV = os.path.join(ROOT, "tools/worldmap/out")
FONT = os.path.join(ROOT, "assets/fonts/fusion-pixel-12px-zh_hans.ttf")

T = 360          # 战区网格间距基准（米 = 1m 底图像素）
HALF = 180
UNDER_GAP = 84   # 地下插图与地表图之间的间隔
U_PAD = 60       # 地下竖井不规则岩洞向 360 基准框外延伸余量（总画布 480×480）

P = set(px_lib.PALETTE)


def C(*rgb):
    assert tuple(rgb) in P, rgb
    return np.array(rgb, dtype=np.uint8)


# ---------------------------------------------------------------- 色
OUT = C(8, 8, 10)
ZG = {  # 区块地表：(主色, 斑驳色)
    "D": (C(78, 80, 72), C(73, 69, 70)), "R": (C(76, 81, 79), C(89, 79, 85)), "I": (C(64, 66, 57), C(73, 69, 70)),
    "H": (C(52, 53, 48), C(64, 66, 57)), "Y": (C(73, 69, 70), C(90, 51, 35)), "M": (C(52, 53, 48), C(28, 46, 45)),
    "P": (C(55, 120, 60), C(30, 60, 35)), "F": (C(150, 97, 13), C(110, 70, 14)), "W": (C(130, 103, 90), C(115, 86, 85)),
    "T": (C(28, 46, 45), C(30, 60, 35)), "C": (C(89, 79, 85), C(76, 81, 79)), "S": (C(50, 24, 70), C(110, 50, 140)),
    "K": (C(46, 41, 40), C(35, 33, 35)), "L": (C(30, 60, 35), C(30, 110, 130)),
    "A": (C(24, 36, 70), C(45, 75, 140)), "B": (C(196, 172, 157), C(171, 166, 166)),
}
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
REED = C(110, 70, 14)
SEA = C(24, 36, 70)
SEA_W = C(45, 75, 140)
SHALLOW = C(30, 110, 130)
ROOF = {  # 屋顶：(主, 亮边, 暗边)
    "D": (C(118, 120, 126), C(143, 143, 147), C(89, 79, 85)), "R": (C(150, 40, 35), C(187, 149, 143), C(90, 24, 22)),
    "I": (C(102, 103, 89), C(140, 138, 120), C(64, 66, 57)), "H": (C(150, 97, 13), C(205, 135, 20), C(110, 70, 14)),
    "Y": (C(90, 51, 35), C(130, 103, 90), C(57, 19, 20)), "M": (C(78, 80, 72), C(120, 122, 110), C(52, 53, 48)),
    "F": (C(150, 40, 35), C(187, 149, 143), C(90, 24, 22)), "P": (C(137, 118, 122), C(171, 166, 166), C(89, 79, 85)),
    "W": (C(106, 100, 108), C(136, 131, 132), C(73, 69, 70)),
}
ROOF_APT = (C(137, 118, 122), C(171, 166, 166), C(89, 79, 85))

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


def obb(c, a, sx, sz):
    ux, uz = math.cos(a) * sx / 2, math.sin(a) * sx / 2
    vx, vz = -math.sin(a) * sz / 2, math.cos(a) * sz / 2
    return [(c[0] - ux - vx, c[1] - uz - vz), (c[0] + ux - vx, c[1] + uz - vz), (c[0] + ux + vx, c[1] + uz + vz), (c[0] - ux + vx, c[1] - uz + vz)]


class Canvas:
    """世界坐标 (x, z) → 像素 (x - ox, z - oz)"""

    def __init__(s, w, h, ox, oz):
        s.w, s.h, s.ox, s.oz = w, h, ox, oz
        s.a = np.zeros((h, w, 3), dtype=np.uint8)
        s.water = np.zeros((h, w), dtype=bool)
        s.road = np.zeros((h, w), dtype=bool)

    def px(s, p):
        return (p[0] - s.ox, p[1] - s.oz)

    def mask(s):
        im = Image.new("L", (s.w, s.h), 0)
        return im, ImageDraw.Draw(im)

    def line_mask(s, polys, width_of):
        """一组折线画成粗线掩膜（圆角接头）"""
        im, dr = s.mask()
        for pts, w in polys:
            xy = [s.px(p) for p in pts]
            ww = max(1, int(round(width_of(w))))
            if len(xy) >= 2:
                dr.line(xy, fill=255, width=ww, joint="curve")
                r = ww / 2
                for q in (xy[0], xy[-1]):
                    dr.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=255)
        return np.asarray(im) > 0

    def disc_mask(s, discs):
        im, dr = s.mask()
        for x, z, r in discs:
            q = s.px((x, z))
            dr.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=255)
        return np.asarray(im) > 0

    def poly_mask(s, polys):
        im, dr = s.mask()
        for pts in polys:
            if len(pts) >= 3:
                dr.polygon([s.px(p) for p in pts], fill=255)
        return np.asarray(im) > 0


def shade(a, mask):
    """mask 范围内的像素换成各自的暗色（投影）"""
    if not mask.any():
        return
    cols = a[mask]
    keys = cols[:, 0].astype(np.int32) * 65536 + cols[:, 1].astype(np.int32) * 256 + cols[:, 2]
    out = cols.copy()
    for k in np.unique(keys):
        c = (int(k) >> 16, (int(k) >> 8) & 255, int(k) & 255)
        out[keys == k] = DARK.get(c, (19, 20, 18))
    a[mask] = out


def shifted(m, dy, dx):
    o = np.zeros_like(m)
    h, w = m.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    o[yd, xd] = m[ys, xs]
    return o


# ---------------------------------------------------------------- 绘制
def draw_ground(cv, tiles, seed):
    """区块地表：每个格子的 2 米区块栅格放大到 1 米，主色 + 斑驳"""
    zt = np.full((cv.h, cv.w), "W", dtype="<U1")
    for t in tiles.values():
        n = t["rast_n"]
        r = np.frombuffer(base64.b64decode(t["rast_b64"]), dtype=np.uint8).reshape(n, n)
        r = np.repeat(np.repeat(r, 2, axis=0), 2, axis=1)
        x0 = int(round(t["origin"][0] - cv.ox))
        y0 = int(round(t["origin"][1] - cv.oz))
        sx0, sy0 = max(0, -x0), max(0, -y0)
        dx0, dy0 = max(0, x0), max(0, y0)
        w = min(r.shape[1] - sx0, cv.w - dx0)
        h = min(r.shape[0] - sy0, cv.h - dy0)
        if w <= 0 or h <= 0:
            continue
        zt[dy0:dy0 + h, dx0:dx0 + w] = r[sy0:sy0 + h, sx0:sx0 + w].view("S1").astype("<U1")
    n1 = noise(cv.h, cv.w, 3, seed)
    n2 = noise(cv.h, cv.w, 7, seed + 1)
    nz = n1 * 0.55 + n2 * 0.45
    # 区块交界过渡带：用细粒度噪声将相邻区块像素做有机交错融合（保留海岸线硬朗边界），消除生硬多边形分界
    zt_draw = zt.copy()
    dither_n = noise(cv.h, cv.w, 2, seed + 17)
    for step_r, prob in [(4, 0.32), (2, 0.45), (1, 0.52)]:
        for dy, dx in [(-step_r, 0), (step_r, 0), (0, -step_r), (0, step_r)]:
            nb_z = shifted(zt_draw, dy, dx)
            swap = (nb_z != "") & (nb_z != zt_draw) & (zt_draw != "A") & (nb_z != "A") & (dither_n < prob)
            zt_draw[swap] = nb_z[swap]
            dither_n = 1.0 - dither_n
    for z, (a, b) in ZG.items():
        m = zt_draw == z
        if not m.any():
            continue
        if z == "F":
            # 田块以外的农耕区先铺休耕土色，实际条田内再铺金黄耕地与垄线，避免出现多边形黄框
            cv.a[m] = C(130, 103, 90)
            cv.a[m & (nz > 0.62)] = C(110, 70, 14)
            continue
        cv.a[m] = a
        thr = {"T": 0.45, "P": 0.62, "S": 0.5, "K": 0.55, "F": 0.7, "L": 0.62, "A": 0.93, "B": 0.75}.get(z, 0.66)
        cv.a[m & (nz > thr)] = b
    # 海面 = 水
    cv.water |= zt == "A"
    cv.a[(zt == "A") & (noise(cv.h, cv.w, 2, seed + 9) < 0.08)] = WATER_D
    # 沙滩靠海一侧的浅水
    sea = zt == "A"
    near = shifted(sea, 0, 1) | shifted(sea, 0, -1) | shifted(sea, 1, 0) | shifted(sea, -1, 0)
    for k in range(2, 5):
        near |= shifted(sea, 0, -k) | shifted(sea, 0, k)
    cv.a[sea & ~shifted(sea, 0, 3)] = SHALLOW
    hv = noise(cv.h, cv.w, 2, seed + 5)
    cv.a[(zt == "S") & (hv > 0.93)] = HIVE_H
    cv.a[(zt == "K") & (hv > 0.9)] = ROCK_H
    cv.a[(zt == "L") & (hv > 0.88)] = REED
    return zt


def draw_fields(cv, tiles, zt):
    """农田垄线：顺着田块朝向，每 4.4 米一条（与游戏小地图一致）"""
    im, dr = cv.mask()
    for t in tiles.values():
        for fd in t["fields"]:
            pts = fd["poly"]
            if len(pts) < 3:
                continue
            a = fd["ang"]
            u = (math.cos(a), math.sin(a))
            v = (-math.sin(a), math.cos(a))
            ds = [p[0] * v[0] + p[1] * v[1] for p in pts]
            lo, hi = min(ds), max(ds)
            us = [p[0] * u[0] + p[1] * u[1] for p in pts]
            ulo, uhi = min(us) - 5, max(us) + 5
            d = lo + 2.0
            while d < hi:
                p0 = (u[0] * ulo + v[0] * d, u[1] * ulo + v[1] * d)
                p1 = (u[0] * uhi + v[0] * d, u[1] * uhi + v[1] * d)
                dr.line([cv.px(p0), cv.px(p1)], fill=255, width=1)
                d += 4.4
    rows = np.asarray(im) > 0
    pm = cv.poly_mask([fd["poly"] for t in tiles.values() for fd in t["fields"]])
    f_plot = pm & (zt == "F")
    cv.a[f_plot] = ZG["F"][0]
    cv.a[rows & f_plot] = FARM_ROW


def draw_trees(cv, zt, seed):
    """树林 / 公园 / 湿地：确定性散点树冠"""
    pts = []
    ys, xs = np.nonzero(((zt == "T") | (zt == "P") | (zt == "L")) & ~cv.water)
    if len(xs) == 0:
        return
    rs = np.random.RandomState(seed)
    idx = rs.rand(len(xs))
    dens = np.where(zt[ys, xs] == "T", 0.045, np.where(zt[ys, xs] == "P", 0.012, 0.01))
    sel = idx < dens
    for y, x in zip(ys[sel], xs[sel]):
        pts.append((x, y))
    sh = Image.new("L", (cv.w, cv.h), 0)
    cr = Image.new("L", (cv.w, cv.h), 0)
    ds, dc = ImageDraw.Draw(sh), ImageDraw.Draw(cr)
    for x, y in pts:
        ds.ellipse([x - 1.2, y - 1.2, x + 2.8, y + 2.8], fill=255)
        dc.ellipse([x - 2, y - 2, x + 2, y + 2], fill=255)
    shm = (np.asarray(sh) > 0) & ~cv.road & ~cv.water
    crm = (np.asarray(cr) > 0) & ~cv.road & ~cv.water
    shade(cv.a, shm & ~crm)
    cv.a[crm] = TREE
    for x, y in pts:
        if 0 <= y - 1 < cv.h and 0 <= x - 1 < cv.w and not cv.road[y - 1, x - 1]:
            cv.a[y - 1, x - 1] = TREE_H


def draw_water(cv, world, tiles, seed):
    rivers = world["rivers"]
    wet = [(r["pts"], r["w"]) for r in rivers if not r["dry"]]
    dry = [(r["pts"], r["w"]) for r in rivers if r["dry"]]
    m = cv.line_mask(dry, lambda w: w + 5) & ~cv.water
    cv.a[m] = DRY_BANK
    m = cv.line_mask(dry, lambda w: w) & ~cv.water
    cv.a[m] = DRY_BED
    m = cv.line_mask(wet, lambda w: w + 6)
    cv.a[m] = MUD
    lakes = list(world["lakes"])
    lake_polys = list(world.get("lake_polys", []))
    lake_mud_polys = list(world.get("lake_mud_polys", []))
    seen_lk = {(round(l[0], 1), round(l[1], 1)) for l in lakes}
    for t in tiles.values():
        tlk = t["lakes"]
        tlp = t.get("lake_polys", [])
        tlmp = t.get("lake_mud_polys", [])
        for idx, l in enumerate(tlk):
            key = (round(l[0], 1), round(l[1], 1))
            if key not in seen_lk:
                seen_lk.add(key)
                lakes.append(l)
                if idx < len(tlp):
                    lake_polys.append(tlp[idx])
                if idx < len(tlmp):
                    lake_mud_polys.append(tlmp[idx])
    m = cv.poly_mask(lake_mud_polys) if lake_mud_polys else cv.disc_mask([(l[0], l[1], l[2] + 2) for l in lakes])
    cv.a[m] = MUD
    lake_wm = cv.poly_mask(lake_polys) if lake_polys else cv.disc_mask([(l[0], l[1], l[2]) for l in lakes])
    wm = cv.line_mask(wet, lambda w: w) | lake_wm
    cv.a[wm] = WATER
    cv.water |= wm
    wn = noise(cv.h, cv.w, 2, seed + 7)
    cv.a[wm & (wn > 0.9)] = WATER_H
    cv.a[wm & (wn < 0.06)] = WATER_D


def draw_roads(cv, tiles):
    """道路：土路（车辙）/ 柏油（路缘 + 路面，宽路中线虚线），过水的地方画成桥面"""
    seen = set()
    paved, dirt, wide = [], [], []
    for t in tiles.values():
        for r in t["roads"]:
            key = (round(r["pts"][0][0], 1), round(r["pts"][0][1], 1), round(r["pts"][-1][0], 1), round(r["pts"][-1][1], 1), r["w"])
            if key in seen:
                continue
            seen.add(key)
            (dirt if r["dirt"] else paved).append((r["pts"], r["w"]))
            if not r["dirt"] and r["w"] >= 10:
                wide.append(r["pts"])
    water0 = cv.water.copy()
    dm = cv.line_mask(dirt, lambda w: w)
    cv.a[dm] = DIRT
    rut = cv.line_mask(dirt, lambda w: max(1.0, w - 4)) & ~cv.line_mask(dirt, lambda w: max(1.0, w - 6))
    cv.a[rut] = DIRT_R
    pm = cv.line_mask(paved, lambda w: w)
    cv.a[pm] = CURB
    im = cv.line_mask(paved, lambda w: w - 2.4)
    cv.a[im] = ASPH
    big = cv.line_mask([(pts, w) for pts, w in paved if w >= 11], lambda w: w - 2.4)
    cv.a[big] = ASPH_W
    road = dm | pm
    # 桥：路面压在水上的部分
    over = road & water0
    edge = over & ~(shifted(over, 1, 0) & shifted(over, -1, 0) & shifted(over, 0, 1) & shifted(over, 0, -1))
    cv.a[over] = DECK
    cv.a[edge] = OUT
    cv.road |= road
    # 中线虚线
    for pts in wide:
        acc = 0.0
        for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
            L = math.hypot(bx - ax, bz - az)
            n = max(1, int(L))
            for k in range(n):
                acc += L / n
                if int(acc / 4) % 2 == 0:
                    x, y = cv.px((ax + (bx - ax) * k / n, az + (bz - az) * k / n))
                    x, y = int(x), int(y)
                    if 0 <= x < cv.w and 0 <= y < cv.h and not water0[y, x]:
                        cv.a[y, x] = DASH
    return road


def draw_rails(cv, world, tiles):
    lines = [(l, 0) for l in world["rails"]]
    for t in tiles.values():
        for l in t.get("rails", []):
            lines.append((l, 0))
    m = cv.line_mask(lines, lambda w: 4)
    over_w = m & cv.water
    cv.a[m] = RAIL_B
    # 枕木：沿线每 3 米一道（用掩膜与网格近似）
    ties = cv.line_mask(lines, lambda w: 3) & ((np.add.outer(np.arange(cv.h), np.arange(cv.w)) % 3) == 0)
    cv.a[ties] = TIE
    cv.a[over_w & ~ties] = DECK
    r = cv.line_mask(lines, lambda w: 1)
    cv.a[r] = RAIL
    cv.road |= m


def draw_buildings(cv, tiles):
    """建筑轮廓（确定性布局）：投影 + 屋顶主色 + 亮边 / 暗边 + 描边"""
    by = {}
    seen = set()
    for t in tiles.values():
        for b in t["bldgs"]:
            key = (round(b["c"][0], 2), round(b["c"][1], 2))
            if key in seen:
                continue
            seen.add(key)
            k = "APT" if b["kind"] in ("apt", "tenement") else b["ch"]
            by.setdefault(k, []).append(obb(b["c"], b["ang"], b["sx"], b["sz"]))
    allm = cv.poly_mask([p for v in by.values() for p in v])
    sh = shifted(allm, 2, 2) | shifted(allm, 1, 1)
    shade(cv.a, sh & ~allm & ~cv.road & ~cv.water)
    up, dn = shifted(allm, 1, 0), shifted(allm, -1, 0)
    lf, rt = shifted(allm, 0, 1), shifted(allm, 0, -1)
    for k, polys in by.items():
        m = cv.poly_mask(polys)
        main, hi, lo = ROOF_APT if k == "APT" else ROOF.get(k, ROOF["W"])
        cv.a[m] = main
        cv.a[m & ~up] = hi
        cv.a[m & ~lf] = hi
        cv.a[m & ~dn] = lo
        cv.a[m & ~rt] = lo
    cv.a[allm & ~dn & ~rt] = OUT
    ys, xs = np.nonzero(allm & up & dn & lf & rt)
    for y, x in zip(ys, xs):
        if hash2(int(x), int(y), 4) > 0.985:
            cv.a[y, x] = OUT
    return allm


def draw_zone_extras(cv, zones):
    """战区里每局一致的山脊巨石 + 示例种子的小型杂物（不画在路上 / 水上）"""
    for d in zones.values():
        o = d["origin_world"]
        for p in d["ridge_pts"]:
            q = (p[0] + o[0], p[1] + o[1])
            m = cv.disc_mask([(q[0], q[1], 2.6)])
            cv.a[m] = OUT
            m = cv.disc_mask([(q[0], q[1], 2.0)])
            cv.a[m] = ROCK
            m = cv.disc_mask([(q[0] - 0.6, q[1] - 0.6, 1.0)])
            cv.a[m] = ROCK_H


# ---------------------------------------------------------------- 主流程
def main():
    world = json.load(open(os.path.join(WDATA, "world.json"), encoding="utf-8"))
    rx, rz, rw, rh = world["rect"]
    tiles = {}
    for f in os.listdir(WDATA):
        if f.startswith("tile_") and f.endswith(".json"):
            t = json.load(open(os.path.join(WDATA, f), encoding="utf-8"))
            tiles[tuple(t["tile"])] = t
    zones = {}
    for f in sorted(os.listdir(DATA)):
        if f.endswith(".json"):
            d = json.load(open(os.path.join(DATA, f), encoding="utf-8"))
            zones[d["id"]] = d
    surf = {k: v for k, v in world["zones"].items() if v["surface"] and k in zones}
    under = {}
    W = int(rw)
    Hs = int(rh)
    H = Hs + ((UNDER_GAP + T + U_PAD + 24) if under else 0)
    full = np.zeros((H, W, 3), dtype=np.uint8)
    full[:] = OUT
    if H > Hs:
        uh = H - Hs
        sub = np.empty((uh, W, 3), dtype=np.uint8)
        sub[:] = C(19, 20, 18)
        n_coarse = noise(uh, W, 14, 3101)
        n_med = noise(uh, W, 5, 3102)
        yy, xx = np.mgrid[0:uh, 0:W]
        strata = np.sin(yy * 0.085 + xx * 0.018 + n_coarse * 3.6) * 0.5 + 0.5
        sub[(strata > 0.56) & (n_med > 0.30)] = C(35, 33, 35)
        sub[(strata > 0.76) & (n_med > 0.54)] = C(46, 41, 40)
        sub[(n_coarse < 0.14) & (n_med < 0.25)] = C(8, 8, 10)
        sub[0:3, :] = C(8, 8, 10)
        sub[3:5, :] = C(73, 69, 70)
        sub[5:7, :] = C(35, 33, 35)
        full[Hs:] = sub

    # 1) 地表：整片城市群
    cv = Canvas(W, Hs, rx, rz)
    st = {k: v for k, v in tiles.items() if k[1] < 20}
    zt = draw_ground(cv, st, 1001)
    draw_fields(cv, st, zt)
    draw_water(cv, world, st, 1002)
    road = draw_roads(cv, st)
    draw_rails(cv, world, {})
    draw_zone_extras(cv, {k: zones[k] for k in surf})
    draw_trees(cv, zt, 1003)
    draw_buildings(cv, st)
    full[:Hs] = cv.a

    tile_origin = {}
    for mid, z in surf.items():
        tx, tz = z["tile"]
        tile_origin[mid] = (int(tx * T - HALF - rx), int(tz * T - HALF - rz))

    # 2) 地下竖井：画在地表图下方不规则塌陷洞窟剖面，横向对齐它上方的战区（SHAFT_PARENT）
    shaft_meta = None
    for mid, z in under.items():
        parent = zones[mid].get("shaft_parent", "canyon")
        px0 = tile_origin.get(parent, (W // 2 - HALF, 0))[0]
        ay = Hs + UNDER_GAP
        tx, tz = z["tile"]
        uw_sz = T + U_PAD * 2
        uc = Canvas(uw_sz, uw_sz, tx * T - HALF - U_PAD, tz * T - HALF - U_PAD)
        ut = {k: v for k, v in tiles.items() if abs(k[0] - tx) <= 1 and abs(k[1] - tz) <= 1}
        uz = draw_ground(uc, ut, 2001)
        uw = {"rivers": [], "lakes": [], "rails": []}
        draw_water(uc, uw, ut, 2002)
        draw_roads(uc, ut)
        draw_trees(uc, uz, 2003)
        draw_buildings(uc, ut)
        # 按不规则竖井多边形裁剪洞窟轮廓，外围生成参差黑曜岩断壁与地下剖面底色（消除方形外框）
        u_poly = [(tx * T + p[0], tz * T + p[1]) for p in zones[mid].get("poly", [])]
        x0 = max(0, px0 - U_PAD)
        y_dst = ay - U_PAD
        h_copy = min(uw_sz, H - y_dst)
        w_copy = min(uw_sz, W - x0)
        if len(u_poly) >= 3:
            inside_m = uc.poly_mask([u_poly])
            im_rim, dr_rim = uc.mask()
            xy_rim = [uc.px(p) for p in u_poly] + [uc.px(u_poly[0])]
            dr_rim.polygon([uc.px(p) for p in u_poly], fill=255)
            dr_rim.line(xy_rim, fill=255, width=20, joint="curve")
            rim_m = (np.asarray(im_rim) > 0) & ~inside_m
            rn = noise(uw_sz, uw_sz, 3, 2019)
            uc.a[~inside_m] = C(19, 20, 18)
            uc.a[rim_m & (rn > 0.34)] = C(35, 33, 35)
            uc.a[rim_m & (rn > 0.72)] = C(46, 41, 40)
            paste_m = (inside_m | rim_m)[:h_copy, :w_copy]
            dst = full[y_dst:y_dst + h_copy, x0:x0 + w_copy]
            dst[paste_m] = uc.a[:h_copy, :w_copy][paste_m]
        else:
            ring = np.ones((uw_sz, uw_sz), dtype=bool)
            ring[U_PAD:U_PAD + T, U_PAD:U_PAD + T] = False
            uc.a[ring] = C(19, 20, 18)
            full[y_dst:y_dst + h_copy, x0:x0 + w_copy] = uc.a[:h_copy, :w_copy]
        tile_origin[mid] = (px0, ay)
        if parent in tile_origin:
            sx = tile_origin[parent][0] + HALF
            p_poly = zones[parent].get("poly", [])
            p_max_z = max((pt[1] for pt in p_poly), default=HALF)
            u_min_z = min((pt[1] for pt in zones[mid].get("poly", [])), default=-HALF)
            y_top = int(round(tile_origin[parent][1] + HALF + p_max_z + 6))
            y_bot = int(round(ay + HALF + u_min_z - 8))
            for y in range(max(0, y_top), min(H, y_bot)):
                if (y // 4) % 2 == 0:
                    full[y, sx - 1:sx + 2] = C(255, 176, 33)
            shaft_meta = {"map": mid, "parent": parent, "x": sx, "y0": y_top - 4, "y1": y_bot}

    flat = full.reshape(-1, 3)
    u = np.unique(flat, axis=0)
    bad = [tuple(int(v) for v in c) for c in u if tuple(int(v) for v in c) not in P]
    assert not bad, "出现色板外的颜色：%s" % bad[:5]

    os.makedirs(OUT_UI, exist_ok=True)
    os.makedirs(OUT_REV, exist_ok=True)
    img = Image.fromarray(full, "RGB")
    img.save(os.path.join(OUT_UI, "wm_1m.png"), optimize=True)
    for k in (2, 4):
        down(full, k).save(os.path.join(OUT_UI, "wm_%dm.png" % k), optimize=True)

    gates_meta = []
    for mid in tile_origin:
        for g in zones[mid]["gates"]:
            al = max(set(g["along"]), key=g["along"].count)
            gp = g.get("pos", [0.0, 0.0])
            gt = g.get("tangent", [1.0, 0.0])
            gi = g.get("inward", [0.0, 1.0])
            gates_meta.append({"map": mid, "edge": g["edge"], "to": g["to"], "along": al, "lo": min(g["along"]), "hi": max(g["along"]),
                               "x": gp[0], "z": gp[1], "tx": gt[0], "tz": gt[1], "ix": gi[0], "iz": gi[1],
                               "freq": round(g["along"].count(al) / len(g["along"]), 2)})
    fill = [[nm, x - rx, z - rz] for nm, x, z in FILL_LABELS]
    meta = {"w": W, "h": H, "tile": T, "half": HALF, "gutter": 0, "levels": [1, 2, 4], "world_rect": world["rect"], "maps": {},
            "gates": gates_meta, "fill_labels": fill, "shaft": shaft_meta}
    for mid, (x0, y0) in tile_origin.items():
        d = zones[mid]
        meta["maps"][mid] = {"x": x0, "y": y0, "name": d["name"], "grid": world["zones"][mid]["tile"],
                             "poly": [[round(p[0], 1), round(p[1], 1)] for p in d.get("poly", [])],
                             "extracts": d["extracts"], "pois": [{"x": round(p["x"], 1), "z": round(p["z"], 1), "id": p["id"], "name": p["name"]} for p in d["pois"]],
                             "landmarks": landmarks_meta(d), "underground": mid in under}
    json.dump(meta, open(os.path.join(OUT_UI, "worldmap.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    annotate(img, meta, zones).save(os.path.join(OUT_REV, "worldmap_full.png"), optimize=True)
    print("worldmap %dx%d maps=%s" % (W, H, sorted(tile_origin)))


## 城市群外围的地名（世界坐标）
FILL_LABELS = [
    ["东湾", 800, -300], ["河口湿地", 560, 60], ["北湾岬角", 580, -640], ["北郊水库", -400, -800], ["北岭林带", -60, -720],
    ["西部丘陵", -420, -200], ["西郊农场", -260, 150], ["南部荒漠", -200, 760], ["东南玄武岩台地", 600, 560], ["外环高速", -300, 520],
]


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


def annotate(img, meta, zones):
    """审图用：逆时针旋转 90° 横置并叠战区边框、名牌、撤离点、遗迹、转场口、地名（界面里这些是实时绘制的）"""
    im = img.transpose(Image.Transpose.ROTATE_90)
    dr = ImageDraw.Draw(im)
    dr.fontmode = "1"
    font = ImageFont.truetype(FONT, 12)
    amber = (255, 176, 33)
    green = (115, 217, 102)
    cyan = (77, 217, 242)
    cream = (219, 214, 191)
    W0 = meta["w"]

    def b2m(u, v):
        return (v, W0 - u)

    def label(x, y, t, col=cream, bg=(8, 8, 10)):
        x, y = int(round(x)), int(round(y))
        tw = int(dr.textlength(t, font=font))
        dr.rectangle([x - tw // 2 - 3, y - 8, x + tw // 2 + 2, y + 7], fill=bg)
        dr.text((x - tw // 2, y - 7), t, font=font, fill=col)

    for mid, m in meta["maps"].items():
        x0, y0 = m["x"], m["y"]
        poly = m.get("poly", [])
        outline_col = amber if not m["underground"] else (160, 95, 205)
        if len(poly) >= 3:
            xy = [b2m(x0 + HALF + p[0], y0 + HALF + p[1]) for p in poly]
            xy_closed = xy + [xy[0]]
            dr.line(xy_closed, fill=(8, 8, 10), width=5, joint="curve")
            dr.line(xy_closed, fill=outline_col, width=2, joint="curve")
        else:
            corners = [b2m(x0, y0), b2m(x0 + T - 1, y0), b2m(x0 + T - 1, y0 + T - 1), b2m(x0, y0 + T - 1)]
            dr.polygon(corners, outline=outline_col, width=2)
            xy = corners
        for e in m["extracts"]:
            x, y = b2m(x0 + HALF + e["x"], y0 + HALF + e["z"])
            dr.rectangle([x - 4, y - 4, x + 3, y + 3], fill=(8, 8, 10))
            dr.rectangle([x - 2, y - 2, x + 1, y + 1], fill=green)
        for p in m["pois"]:
            x, y = b2m(x0 + HALF + p["x"], y0 + HALF + p["z"])
            dr.polygon([(x, y - 5), (x + 5, y), (x, y + 5), (x - 5, y)], fill=(8, 8, 10))
            dr.polygon([(x, y - 3), (x + 3, y), (x, y + 3), (x - 3, y)], fill=amber)
        cx = sum(pt[0] for pt in xy) / len(xy)
        cy = sum(pt[1] for pt in xy) / len(xy)
        top_y = min(pt[1] for pt in xy)
        label(cx, top_y + (cy - top_y) * 0.38, m["name"] + ("（地下竖井）" if m["underground"] else ""), amber)
    for g in meta["gates"]:
        m = meta["maps"][g["map"]]
        x0, y0 = m["x"], m["y"]
        gx, gz = b2m(x0 + HALF + g.get("x", 0.0), y0 + HALF + g.get("z", 0.0))
        rtx, rtz = g.get("tz", 0.0), -g.get("tx", 1.0)
        dr.line([(gx - rtx * 16, gz - rtz * 16), (gx + rtx * 16, gz + rtz * 16)], fill=(8, 8, 10), width=6)
        dr.line([(gx - rtx * 15, gz - rtz * 15), (gx + rtx * 15, gz + rtz * 15)], fill=cyan, width=3)
    for nm, x, y in meta["fill_labels"]:
        mx, my = b2m(x, y)
        label(mx, my, nm, (160, 160, 145))
    return im


if __name__ == "__main__":
    main()
