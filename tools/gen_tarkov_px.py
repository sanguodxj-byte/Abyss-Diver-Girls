# v0.7.1 机库界面像素贴图（逐像素程序绘制，可复现；不使用 AI 生图或外部素材）。
# 用法：python3 tools/gen_tarkov_px.py   （项目根目录执行）
#
# 像素尺度：与角色像素头像一致，1 美术像素 = 2 逻辑像素（头像 px48 为 48 格 ×2、物品图标 16 格 ×2）。
#   九宫格 / 背景平铺贴图直接按 2 倍烘焙（StyleBoxTexture 不能缩放贴图，平铺模式 TILE_FIT 保持整像素）；
#   图集（物品、导航、地形、小图标）按 1 倍保存，运行时以 2 倍（大格 3 倍等整数倍）最近邻绘制。
# 色板：tools/px_lib.py —— 机库深灰 / 米白 / 琥珀 + 状态色 + 角色头像合并量化色，所有像素保存前吸附到色板。
#
# 产出 assets/ui/px/：
#   panel9  主面板：拉丝金属框 + 铆钉 + 凹槽内衬 + 琥珀角标            九宫格边距 16（8 格）
#   inset9  凹槽内衬（网格、列表、输入框、树）                          边距 6
#   plate9  面板标题栏铭牌（两端螺丝）                                   左右 14 / 上下 6
#   hazard  警示黄黑条平铺
#   card9 / card9_on        内卡片（普通 / 选中）                         边距 6
#   tip9                    悬停浮窗 / 右键菜单（不透明）                 边距 6
#   merchant9 / _h / _on    商人卡、战区卡（铜角 + 铆钉）                  边距 12
#   nameplate9              铜名牌（商人名）                               左右 10 / 上下 6
#   btn9_{n,h,p,d}          次级按钮                                        边距 8
#   btn9_main_{n,h,p,d}     主按钮（琥珀）                                  边距 8
#   nav9_{n,h,p,on}         底部导航四态：常态 / 悬停 / 按下 / 当前        边距 12
#   topbar9 / botbar9       顶部状态条 / 底部导航条底板
#   cell9_{empty,r0..r3}    物品格底板（空 / 按稀有度）                    边距 6
#   cell9_{sel,hover,bad}   物品格叠加层（选中 / 悬停 / 不满足要求）       边距 8
#   slot9_empty             装备空槽
#   bg_{base,trade,deploy,skills,stash,codex}  舱壁背景平铺（128×128）
#   chart                   世界地图海图底纹平铺
#   atlas16.png             16×16 图集：物品、导航、设施（1 倍）
#   atlas8.png              8×8 图集：顶栏状态、地图标记（1 倍）
#   terrain.png             8×8 战区地形格（1 倍），按 zones 字母
# 另生成 scripts/px_atlas.gd（图集索引，勿手改）与 review/px_sheet.png（4 倍素材表）。
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402
from px_lib import (ROOT, K, Cv, snap, mix, ramp, alpha, stencil, OUT, METAL, GUN, STEEL, AMB, BRASS, RED, GRN, BLU,  # noqa: E402
                    CYN, PUR, OLIVE, CREAM, WHITE, PALETTE)
import px_icons  # noqa: E402

OUTDIR = os.path.join(ROOT, "assets/ui/px")
SHEET = []  # (名称, PIL 图, 倍率说明)


def out(cv, name, k=K, sheet=True):
    path = os.path.join(OUTDIR, name + ".png")
    cv.save(path, k)
    if sheet:
        SHEET.append((name, cv.image(4), "%d×%d" % (cv.w, cv.h)))


def dist(x, y, w, h):
    return min(x, y, w - 1 - x, h - 1 - y)


def side(x, y, w, h):
    """离哪条边最近：'t' 'l' 'b' 'r'（左上优先）"""
    d = {"t": y, "l": x, "b": h - 1 - y, "r": w - 1 - x}
    return min(d, key=lambda k: (d[k], "tlbr".index(k)))


def rivet(c, x, y, big=True):
    c.px(x, y, (190, 187, 168))
    if big:
        c.px(x + 1, y, (120, 122, 110))
        c.px(x, y + 1, (102, 103, 89))
        c.px(x + 1, y + 1, (24, 25, 23))


def screw(c, x, y):
    """3×3 一字螺丝"""
    c.rect(x, y, 3, 3, (102, 103, 89))
    c.px(x, y, (160, 160, 145))
    c.px(x + 2, y + 2, (36, 37, 34))
    c.px(x, y + 2, (78, 80, 72))
    c.px(x + 2, y, (120, 122, 110))
    c.px(x + 1, y + 1, (24, 25, 23))
    c.px(x + 2, y, (24, 25, 23))
    c.px(x, y + 2, (24, 25, 23))


# ================================================================ 九宫格
def brushed(x, y, horiz):
    """拉丝金属：沿纹理方向的明暗短划"""
    k = (x * 3 + y * 17) % 7 if horiz else (y * 3 + x * 17) % 7
    return k


def panel9():
    w = h = 32
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            s = side(x, y, w, h)
            hz = s in ("t", "b")
            if d == 0:
                c.px(x, y, OUT)
            elif d in (1, 2):
                lit = s in ("t", "l")
                k = brushed(x, y, hz)
                if d == 1:
                    col = (140, 138, 120) if lit else (78, 80, 72)
                    if k == 0:
                        col = (160, 160, 145) if lit else (102, 103, 89)
                else:
                    col = (102, 103, 89) if lit else (52, 53, 48)
                    if k == 3:
                        col = (120, 122, 110) if lit else (64, 66, 57)
                c.px(x, y, col)
            elif d == 3:
                c.px(x, y, (8, 8, 10))
            elif d == 4 and s in ("t", "l"):
                c.px(x, y, alpha((11, 11, 11), 236))
            else:
                col = (19, 20, 18)
                if (y % 4 == 1) and ((x * 5 + y) % 9 == 0):
                    col = (24, 25, 23)
                c.px(x, y, alpha(col, 214))
    # 铆钉：角部附近 + 每段平铺边中点
    for x, y in [(5, 1), (w - 7, 1), (5, h - 3), (w - 7, h - 3), (1, 5), (w - 3, 5), (1, h - 7), (w - 3, h - 7),
                 (15, 1), (15, h - 3), (1, 15), (w - 3, 15)]:
        rivet(c, x, y)
    # 琥珀角标（外缘两像素粗的 L）
    for sx, sy, dx, dy in [(0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)]:
        for i in range(7):
            c.px(sx + dx * i, sy, AMB[2])
            c.px(sx, sy + dy * i, AMB[2])
        for i in range(4):
            c.px(sx + dx * i, sy + dy, AMB[1])
            c.px(sx + dx, sy + dy * i, AMB[1])
    out(c, "panel9")


def inset9():
    w = h = 12
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            s = side(x, y, w, h)
            if d == 0:
                c.px(x, y, (8, 8, 10) if s in ("t", "l") else (41, 41, 37))
            elif d == 1:
                c.px(x, y, alpha((11, 11, 11), 240) if s in ("t", "l") else alpha((19, 20, 18), 236))
            else:
                c.px(x, y, alpha((14, 15, 14), 232))
    out(c, "inset9")


def plate9():
    w, h = 32, 11
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            if y == h - 1:
                col = (8, 8, 10)
            elif y == 0:
                col = (64, 66, 57)
            elif y == h - 2:
                col = (24, 25, 23)
            else:
                col = (36, 37, 34)
                if brushed(x, y, True) == 2:
                    col = (41, 41, 37)
                if brushed(x, y, True) == 5:
                    col = (29, 30, 28)
            c.px(x, y, alpha(col, 245))
    screw(c, 2, 4)
    screw(c, w - 5, 4)
    out(c, "plate9")


def hazard():
    w, h = 8, 5
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            if y in (0, h - 1):
                c.px(x, y, OUT)
            else:
                c.px(x, y, AMB[2] if (x + y) % 8 < 4 else (19, 20, 18))
    out(c, "hazard")


def card9(on=False):
    w = h = 12
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            s = side(x, y, w, h)
            lit = s in ("t", "l")
            if d == 0:
                c.px(x, y, (8, 8, 10) if not on else AMB[0])
            elif d == 1:
                if on:
                    c.px(x, y, AMB[1] if lit else (110, 70, 14))
                else:
                    c.px(x, y, (64, 66, 57) if lit else (29, 30, 28))
            else:
                c.px(x, y, alpha((60, 40, 14) if on else (24, 25, 23), 228))
    for x, y in [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)]:
        c.px(x, y, AMB[3] if on else (120, 122, 110))
    out(c, "card9_on" if on else "card9")


def tip9():
    """悬停浮窗 / 右键菜单底板：不透明，压在内容之上也不透字"""
    w = h = 12
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            s = side(x, y, w, h)
            if d == 0:
                c.px(x, y, OUT)
            elif d == 1:
                c.px(x, y, (102, 103, 89) if s in ("t", "l") else (41, 41, 37))
            else:
                c.px(x, y, (14, 15, 14))
    c.rect(2, 2, 3, 1, AMB[2])
    c.rect(2, 2, 1, 3, AMB[2])
    out(c, "tip9")


def merchant9(state):
    w = h = 24
    c = Cv(w, h)
    on = state == "on"
    hv = state == "h"
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            s = side(x, y, w, h)
            lit = s in ("t", "l")
            if d == 0:
                c.px(x, y, OUT)
            elif d == 1:
                base = (140, 138, 120) if lit else (78, 80, 72)
                if hv:
                    base = (190, 187, 168) if lit else (102, 103, 89)
                if on:
                    base = AMB[2] if lit else AMB[1]
                c.px(x, y, base)
            elif d == 2:
                c.px(x, y, (52, 53, 48) if not on else (110, 70, 14))
            elif d == 3:
                c.px(x, y, (8, 8, 10))
            else:
                col = (24, 25, 23) if not hv else (29, 30, 28)
                if on:
                    col = (41, 33, 18)
                c.px(x, y, alpha(col, 236))
    # 铜包角（三角）
    br = BRASS if not on else AMB
    for sx, sy, dx, dy in [(0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)]:
        for i in range(5):
            for j in range(5 - i):
                c.px(sx + dx * i, sy + dy * j, br[2] if (i == 0 or j == 0) else br[1])
        c.px(sx + dx, sy + dy, br[3])
        c.px(sx + dx * 2, sy + dy * 2, OUT)
    for x, y in [(11, 1), (11, h - 3)]:
        rivet(c, x, y)
    out(c, "merchant9" + ("" if state == "n" else "_" + state))


def nameplate9():
    w, h = 24, 12
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            if d == 0:
                c.px(x, y, OUT)
            elif y == 1:
                c.px(x, y, BRASS[3])
            elif y == h - 2:
                c.px(x, y, BRASS[1])
            else:
                c.px(x, y, BRASS[2] if brushed(x, y, True) != 4 else (255, 206, 84))
    for x in (2, w - 3):
        c.px(x, 5, BRASS[0]); c.px(x, 6, (60, 40, 14)); c.px(x + (1 if x == 2 else -1), 5, BRASS[1])
    out(c, "nameplate9")


def btn9(state, main=False):
    w = h = 12
    c = Cv(w, h)
    if main:
        pal = {"n": ((255, 206, 84), (205, 135, 20), (150, 97, 13), OUT),
               "h": ((255, 232, 160), (255, 176, 33), (205, 135, 20), OUT),
               "p": ((110, 70, 14), (150, 97, 13), (205, 135, 20), OUT),
               "d": ((60, 40, 14), (60, 40, 14), (41, 33, 18), (24, 25, 23))}[state]
    else:
        pal = {"n": ((78, 80, 72), (41, 41, 37), (24, 25, 23), OUT),
               "h": ((140, 138, 120), (52, 53, 48), (29, 30, 28), (102, 103, 89)),
               "p": ((19, 20, 18), (60, 40, 14), (110, 70, 14), AMB[1]),
               "d": ((24, 25, 23), (19, 20, 18), (19, 20, 18), (24, 25, 23))}[state]
    hi, body, lo, ol = pal
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            s = side(x, y, w, h)
            if d == 0:
                if (x in (0, w - 1)) and (y in (0, h - 1)):
                    continue  # 切角
                c.px(x, y, ol)
            elif d == 1:
                c.px(x, y, hi if s in ("t", "l") else lo)
            else:
                c.px(x, y, alpha(body, 240 if not main else 255))
    if state != "d":
        dot = (24, 25, 23) if not main else (110, 70, 14)
        for x, y in [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]:
            c.px(x, y, dot)
    out(c, ("btn9_main_" if main else "btn9_") + state)


def nav9(state):
    w = h = 24
    c = Cv(w, h)
    body = {"n": (19, 20, 18), "h": (29, 30, 28), "p": (14, 15, 14), "on": (41, 33, 18)}[state]
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            s = side(x, y, w, h)
            if d == 0:
                c.px(x, y, {"n": (8, 8, 10), "h": (102, 103, 89), "p": (110, 70, 14), "on": (110, 70, 14)}[state])
            elif d == 1:
                if state == "p":
                    c.px(x, y, (8, 8, 10) if s in ("t", "l") else (52, 53, 48))
                else:
                    lit = s in ("t", "l")
                    c.px(x, y, ({"n": (41, 41, 37), "h": (78, 80, 72), "on": (110, 70, 14)}[state]) if lit else (14, 15, 14))
            else:
                col = body
                if state != "p" and (x + y * 3) % 11 == 0 and y > 3:
                    col = mix(body, (52, 53, 48), 0.35)
                c.px(x, y, alpha(col, 248))
    for x, y in [(3, 4), (w - 4, 4), (3, h - 4), (w - 4, h - 4)]:
        c.px(x, y, (64, 66, 57) if state in ("n", "p") else (120, 122, 110))
    if state == "on":
        c.rect(1, 1, w - 2, 2, AMB[2])
        c.rect(1, 3, w - 2, 1, AMB[0])
        for x in range(1, w - 1):
            if x % 4 == 0:
                c.px(x, 1, AMB[3])
        for sx, dx in [(1, 1), (w - 2, -1)]:
            for i in range(4):
                c.px(sx + dx * i, h - 2, AMB[2])
            c.px(sx, h - 3, AMB[2])
    out(c, "nav9_" + state)


def topbar9():
    w, h = 40, 18
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            if y == h - 1:
                col = OUT
            elif y == h - 2:
                col = (52, 53, 48)
            elif y == 0:
                col = (29, 30, 28)
            else:
                col = (14, 15, 14)
                if y < 3 and brushed(x, y, True) == 1:
                    col = (19, 20, 18)
            c.px(x, y, alpha(col, 250))
    rivet(c, 20, 1, big=False)
    c.px(20, 2, (24, 25, 23))
    out(c, "topbar9")


def botbar9():
    w, h = 40, 24
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            if y == 0 or y == 3:
                col = OUT
            elif y in (1, 2):
                col = AMB[1] if (x + y) % 8 < 4 else (14, 15, 14)
            elif y == 4:
                col = (41, 41, 37)
            else:
                col = (11, 11, 11)
                if (x * 7 + y * 3) % 13 == 0:
                    col = (14, 15, 14)
            c.px(x, y, alpha(col, 250))
    out(c, "botbar9")


RAR = [(41, 41, 37), (30, 60, 35), (24, 36, 70), (50, 24, 70)]
RAR_EDGE = [(78, 80, 72), (55, 120, 60), (45, 75, 140), (110, 50, 140)]


def cell9(kind):
    w = h = 12
    c = Cv(w, h)
    if kind == "empty" or kind == "slot":
        for y in range(h):
            for x in range(w):
                d = dist(x, y, w, h)
                s = side(x, y, w, h)
                if d == 0:
                    c.px(x, y, (8, 8, 10) if s in ("t", "l") else (29, 30, 28))
                elif d == 1 and s in ("t", "l"):
                    c.px(x, y, alpha((11, 11, 11), 240))
                else:
                    col = (19, 20, 18) if kind == "empty" else (14, 15, 14)
                    if kind == "empty" and (x, y) == (5, 5):
                        col = (29, 30, 28)
                    if kind == "slot" and (x + y) % 4 == 0 and 1 < x < w - 2 and 1 < y < h - 2:
                        col = (36, 37, 34)
                    c.px(x, y, alpha(col, 236))
        out(c, "cell9_empty" if kind == "empty" else "slot9_empty")
        return
    r = int(kind[1])
    base = RAR[r]
    edge = RAR_EDGE[r]
    for y in range(h):
        for x in range(w):
            d = dist(x, y, w, h)
            s = side(x, y, w, h)
            if d == 0:
                c.px(x, y, edge if s in ("t", "l") else mix(edge, (8, 8, 10), 0.4))
            elif d == 1:
                c.px(x, y, mix(base, (255, 255, 255), 0.12) if s in ("t", "l") else mix(base, (0, 0, 0), 0.3))
            else:
                col = base
                if (x + y) % 4 == 0:
                    col = mix(base, (0, 0, 0), 0.22)
                c.px(x, y, alpha(col, 245))
    out(c, "cell9_r%d" % r)


def cell_overlay(kind):
    w = h = 16
    c = Cv(w, h)
    if kind == "sel":
        c.frame(0, 0, w, h, AMB[2])
        c.frame(1, 1, w - 2, h - 2, alpha(AMB[0], 200))
        for sx, sy, dx, dy in [(0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)]:
            for i in range(4):
                c.px(sx + dx * i, sy, AMB[3])
                c.px(sx, sy + dy * i, AMB[3])
                c.px(sx + dx * i, sy + dy, AMB[2])
                c.px(sx + dx, sy + dy * i, AMB[2])
    elif kind == "hover":
        for sx, sy, dx, dy in [(0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)]:
            for i in range(4):
                c.px(sx + dx * i, sy, CREAM)
                c.px(sx, sy + dy * i, CREAM)
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                c.px(x, y, (255, 255, 255, 14))
    elif kind == "bad":
        c.frame(0, 0, w, h, RED[2])
        c.frame(1, 1, w - 2, h - 2, alpha(RED[0], 220))
        for y in range(2, h - 2):
            for x in range(2, w - 2):
                if (x - y) % 4 == 0:
                    c.px(x, y, alpha(RED[1], 110))
                else:
                    c.px(x, y, (90, 24, 22, 60))
    out(c, "cell9_" + kind)


# ================================================================ 背景平铺（64×64 格，烘焙 128×128）
def bg_base(c=None):
    w = h = 64
    c = Cv(w, h, (19, 20, 18))
    for y in range(h):
        for x in range(w):
            if (x * 13 + y * 7) % 23 == 0:
                c.px(x, y, (24, 25, 23))
    for t in range(64):
        for o in (0, 32):
            c.px(o, t, (11, 11, 11)); c.px(o + 1, t, (24, 25, 23))
            c.px(t, o, (11, 11, 11)); c.px(t, o + 1, (24, 25, 23))
    for px0 in (0, 32):
        for py0 in (0, 32):
            for dx, dy in [(4, 4), (28, 4), (4, 28), (28, 28)]:
                c.px(px0 + dx, py0 + dy, (36, 37, 34)); c.px(px0 + dx, py0 + dy + 1, (11, 11, 11))
    # 横向管线 + 法兰
    for x in range(64):
        for i, col in enumerate([(14, 15, 14), (36, 37, 34), (41, 41, 37), (29, 30, 28), (24, 25, 23), (11, 11, 11)]):
            c.px(x, 43 + i, col)
    for fx in (12, 44):
        c.rect(fx, 42, 2, 8, (52, 53, 48))
        c.px(fx, 42, (64, 66, 57))
    stencil(c, "03", 38, 6, (36, 37, 34))
    stencil(c, "B", 6, 6, (29, 30, 28))
    return c


def bg_trade():
    w = h = 64
    c = Cv(w, h, (32, 35, 35))
    for y in range(h):
        for x in range(w):
            m = x % 4
            col = (23, 27, 27) if m == 0 else ((35, 41, 41) if m == 1 else (32, 35, 35))
            if y in (0, 1, 62, 63) or y == 32:
                col = (19, 20, 18) if y != 1 else (36, 37, 34)
            c.px(x, y, col)
    for bx in (20, 52):
        c.rect(bx, 2, 2, 60, (41, 41, 37))
        c.rect(bx + 2, 2, 1, 60, (23, 27, 27))
        for hy in (12, 44):
            c.rect(bx - 2, hy, 6, 3, (52, 53, 48)); c.px(bx - 2, hy, (64, 66, 57))
    stencil(c, "C-12", 4, 6, (54, 49, 49))
    stencil(c, "MAX 24T", 26, 52, (54, 49, 49))
    return c


def bg_deploy():
    w = h = 64
    c = Cv(w, h, (23, 27, 27))
    for y in range(h):
        for x in range(w):
            if x % 32 == 0 or y % 32 == 0:
                c.px(x, y, (35, 41, 41))
            elif x % 8 == 0 or y % 8 == 0:
                if (x + y) % 2 == 0:
                    c.px(x, y, (32, 35, 35))
    import math
    for k, (cx, cy, r) in enumerate([(18, 40, 10), (18, 40, 6), (48, 16, 9)]):
        for a in range(0, 360, 6):
            x = cx + r * math.cos(math.radians(a)) * 1.2
            y = cy + r * math.sin(math.radians(a))
            c.pw(int(x), int(y), (26, 53, 50))
    for x, y in [(44, 44), (10, 12)]:
        for i in range(-2, 3):
            c.pw(x + i, y, (60, 40, 14)); c.pw(x, y + i, (60, 40, 14))
    return c


def bg_skills():
    w = h = 64
    c = Cv(w, h, (24, 25, 23))
    for y in range(2, h, 6):
        for x in range(2, w, 6):
            c.px(x, y, (11, 11, 11)); c.px(x + 1, y, (11, 11, 11))
            c.px(x, y + 1, (29, 30, 28))
    # 挂板上的工具剪影：扳手、锤子
    for i in range(14):
        c.px(8 + i, 50 - i, (36, 37, 34)); c.px(9 + i, 50 - i, (36, 37, 34))
    c.rect(21, 35, 4, 3, (36, 37, 34)); c.px(23, 35, (24, 25, 23))
    c.rect(44, 10, 3, 18, (36, 37, 34)); c.rect(40, 8, 11, 4, (41, 41, 37))
    return c


def bg_stash():
    w = h = 64
    c = Cv(w, h, (14, 15, 14))
    for x in range(w):
        for i, col in enumerate([(52, 53, 48), (36, 37, 34), (19, 20, 18)]):
            c.px(x, 28 + i, col)
            c.px(x, 60 + i, col)
    for y in range(h):
        c.px(0, y, (36, 37, 34)); c.px(1, y, (24, 25, 23)); c.px(2, y, (11, 11, 11))
    for x0, w0, h0, base in [(5, 14, 12, 28), (21, 10, 8, 28), (34, 18, 16, 28), (55, 7, 6, 28),
                             (6, 9, 10, 60), (17, 20, 14, 60), (40, 12, 9, 60)]:
        c.rect(x0, base - h0, w0, h0, (29, 30, 28))
        c.rect(x0, base - h0, w0, 1, (41, 41, 37))
        c.rect(x0, base - h0, 1, h0, (36, 37, 34))
        c.rect(x0 + w0 // 2 - 1, base - h0 + 2, 3, 2, (41, 41, 37))
    return c


def bg_codex():
    w = h = 64
    c = Cv(w, h, (24, 25, 23))
    for y0 in range(0, 64, 16):
        for x0 in (0, 32):
            c.rect(x0, y0, 32, 1, (11, 11, 11))
            c.rect(x0, y0, 1, 16, (11, 11, 11))
            c.rect(x0 + 1, y0 + 1, 31, 1, (36, 37, 34))
            c.rect(x0 + 12, y0 + 4, 8, 4, (41, 41, 37))
            c.rect(x0 + 13, y0 + 5, 6, 2, (64, 66, 57))
            c.rect(x0 + 13, y0 + 10, 6, 2, (52, 53, 48))
            c.px(x0 + 13, y0 + 11, (14, 15, 14)); c.px(x0 + 18, y0 + 11, (14, 15, 14))
    return c


def chart():
    w = h = 32
    c = Cv(w, h, (23, 27, 27))
    for y in range(h):
        for x in range(w):
            if x % 16 == 0 or y % 16 == 0:
                c.px(x, y, (32, 35, 35))
    for x, y in [(4, 6), (20, 22), (24, 8), (8, 24)]:
        c.px(x, y, (35, 41, 41)); c.px(x + 1, y - 1, (35, 41, 41)); c.px(x + 2, y, (35, 41, 41)); c.px(x + 3, y - 1, (35, 41, 41))
    return c


# ================================================================ 地形格（战区 zones 字母 → 8×8 图案）
ZONES = "DRIHYMPFWTCSK"


def terrain_tile(z):
    c = Cv(8, 8)
    if z == "D":   # 旧城中心：密集屋顶 + 暗街
        c.rect(0, 0, 8, 8, (64, 66, 57))
        c.rect(0, 3, 8, 1, (29, 30, 28)); c.rect(4, 0, 1, 8, (29, 30, 28))
        c.rect(0, 0, 3, 1, (102, 103, 89)); c.rect(5, 4, 3, 1, (102, 103, 89))
    elif z == "R":  # 居民区：小屋顶点
        c.rect(0, 0, 8, 8, (83, 58, 51))
        for x, y in [(1, 1), (5, 1), (1, 5), (5, 5)]:
            c.rect(x, y, 2, 2, (135, 90, 72)); c.px(x, y, (165, 122, 116))
    elif z == "I":  # 工业区：大厂房 + 烟囱
        c.rect(0, 0, 8, 8, (59, 60, 63))
        c.rect(1, 2, 6, 4, (78, 80, 72)); c.rect(1, 2, 6, 1, (109, 111, 118))
        c.px(6, 0, (36, 37, 34)); c.px(6, 1, (36, 37, 34))
    elif z == "H":  # 河港码头：水面 + 栈桥
        c.rect(0, 0, 8, 8, (45, 75, 140))
        c.rect(0, 0, 8, 2, (72, 77, 80))
        c.rect(2, 2, 1, 4, (102, 103, 89)); c.rect(5, 2, 1, 3, (102, 103, 89))
        c.px(1, 6, (102, 166, 255))
    elif z == "Y":  # 铁路编组站：平行铁轨
        c.rect(0, 0, 8, 8, (80, 36, 24))
        for y in (1, 5):
            c.rect(0, y, 8, 1, (136, 136, 142))
        for x in range(0, 8, 2):
            c.px(x, 2, (53, 35, 32)); c.px(x, 6, (53, 35, 32))
    elif z == "M":  # 军营：橄榄地 + 营房排
        c.rect(0, 0, 8, 8, (64, 66, 57))
        for y in (1, 4):
            c.rect(1, y, 6, 2, (102, 103, 89)); c.rect(1, y, 6, 1, (120, 122, 110))
    elif z == "P":  # 公园绿地：草地 + 树
        c.rect(0, 0, 8, 8, (30, 60, 35))
        c.rect(1, 1, 2, 2, (55, 120, 60)); c.rect(5, 4, 2, 2, (55, 120, 60)); c.px(2, 6, (55, 120, 60))
    elif z == "F":  # 农田：条带
        c.rect(0, 0, 8, 8, (110, 70, 14))
        for y in (1, 3, 5, 7):
            c.rect(0, y, 8, 1, (150, 97, 13))
    elif z == "W":  # 荒野：稀疏碎石
        c.rect(0, 0, 8, 8, (83, 58, 51))
        c.px(2, 2, (109, 59, 39)); c.px(6, 5, (109, 59, 39)); c.px(4, 7, (102, 81, 80))
    elif z == "T":  # 树林：密林
        c.rect(0, 0, 8, 8, (26, 53, 50))
        for x, y in [(0, 0), (4, 1), (2, 4), (6, 5), (0, 6)]:
            c.rect(x, y, 2, 2, (30, 60, 35)); c.px(x, y, (55, 120, 60))
    elif z == "C":  # 弹坑区
        c.rect(0, 0, 8, 8, (53, 35, 32))
        c.ring(4, 4, 1.4, 2.6, (109, 59, 39)); c.px(3, 3, (23, 27, 27))
    elif z == "S":  # 虫巢菌毯
        c.rect(0, 0, 8, 8, (50, 24, 70))
        c.rect(1, 1, 3, 2, (110, 50, 140)); c.rect(4, 5, 3, 2, (110, 50, 140)); c.px(2, 1, (224, 133, 255))
    elif z == "K":  # 悬崖
        c.rect(0, 0, 8, 8, (35, 41, 41))
        for i in range(8):
            c.px(i, (i * 3) % 8, (72, 77, 80)); c.px((i + 4) % 8, i, (23, 27, 27))
    return c


# ================================================================ 图集
def build_atlas16():
    ids = list(px_icons.ICONS.keys())
    px_icons.ICONS["fac_flask_b"] = (px_icons.ICONS["fac_flask"][0], (102, 166, 255))
    px_icons.ICONS["fac_star_b"] = (px_icons.ICONS["fac_star"][0], (77, 217, 242))
    ids = list(px_icons.ICONS.keys())
    cols = 16
    rows = (len(ids) + cols - 1) // cols
    atlas = Cv(cols * 16, rows * 16)
    index = {}
    for i, id_ in enumerate(ids):
        f, tint = px_icons.ICONS[id_]
        c = Cv(16, 16)
        f(c, tint)
        c.outline(OUT)
        atlas.blit(c, (i % cols) * 16, (i // cols) * 16)
        index[id_] = (i % cols, i // cols)
    atlas.save(os.path.join(OUTDIR, "atlas16.png"), 1)
    return atlas, index


def build_atlas8():
    ids = list(px_icons.SMALL.keys())
    atlas = Cv(len(ids) * 8, 8)
    index = {}
    for i, id_ in enumerate(ids):
        c = Cv(8, 8)
        px_icons.SMALL[id_](c)
        atlas.blit(c, i * 8, 0)
        index[id_] = i
    atlas.save(os.path.join(OUTDIR, "atlas8.png"), 1)
    return atlas, index


def build_terrain():
    atlas = Cv(len(ZONES) * 8, 8)
    for i, z in enumerate(ZONES):
        atlas.blit(terrain_tile(z), i * 8, 0)
    atlas.save(os.path.join(OUTDIR, "terrain.png"), 1)
    return atlas


# 物品 → 图集回退规则（运行时 scripts/item_icons.gd 使用）
WEAPON = {"mg": "arm_mg", "shotgun": "arm_shotgun", "flamer": "arm_flamer", "laser": "arm_laser", "railgun": "arm_railgun",
          "arc": "arm_arc", "mortar": "arm_mortar", "drill": "arm_drill", "plasma": "arm_plasma", "grenade": "arm_grenade",
          "flak": "arm_flak", "cryo": "arm_cryo", "sniper": "arm_sniper", "melee": "arm_drill", "missile": "back_missile"}
LEGS = {t: "legs_" + t for t in ["biped", "tread", "quad", "hover", "reverse", "titan", "wraith", "spring", "wheel"]}
BACK = {"missile": "back_missile", "shield": "back_shield", "none": "back_cargo", "cloak": "back_cloak", "drone": "back_drone",
        "jump": "back_jump", "turret": "back_turret", "mines": "back_mines", "repair": "back_repair"}
SLOT = {"core": "core_std", "legs": "legs_biped", "arm": "arm_mg", "back": "back_cargo", "gen": "gen_cell"}
CAT = {"food": "can_food", "misc": "bolts", "use": "fuel_cell", "money": "credit_s", "module": "unknown"}
FAC = {"hangar": "nav_maintenance", "workshop": "gift_wrench", "infirmary": "repair_kit", "lab": "fac_flask", "kitchen": "can_food",
       "research": "fac_flask_b", "ability": "gen_cell", "talent": "fac_star", "training": "fac_star_b", "meal": "biscuit"}


def gd_dict(d, fmt):
    items = ", ".join('"%s": %s' % (k, fmt(v)) for k, v in d.items())
    return "{" + items + "}"


def write_index(i16, i8):
    lines = [
        "extends RefCounted",
        "## 像素图集索引（tools/gen_tarkov_px.py 生成，勿手改）。图集按 1 倍保存，界面以 2 倍等整数倍最近邻绘制。",
        "## ICONS：assets/ui/px/atlas16.png 中 16×16 图标的格位（列, 行）；SMALL：atlas8.png 中 8×8 小图标序号；",
        "## TERRAIN：terrain.png 中 8×8 地形格的字母顺序。WEAPON / LEGS / BACK / SLOT / CAT / FAC 是物品没有专属图标时的回退。",
        "",
        "const ICONS := " + gd_dict(i16, lambda v: "Vector2i(%d, %d)" % v),
        "const SMALL := " + gd_dict(i8, lambda v: str(v)),
        'const TERRAIN := "%s"' % ZONES,
    ]
    for name, d in [("WEAPON", WEAPON), ("LEGS", LEGS), ("BACK", BACK), ("SLOT", SLOT), ("CAT", CAT), ("FAC", FAC)]:
        lines.append("const %s := " % name + gd_dict(d, lambda v: '"%s"' % v))
    with open(os.path.join(ROOT, "scripts/px_atlas.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")


# ================================================================ 素材表（4 倍）
def build_sheet(a16, i16, a8, i8, terr):
    font_path = os.path.join(ROOT, "assets/fonts/fusion-pixel-12px-zh_hans.ttf")
    font = ImageFont.truetype(font_path, 12)
    big = ImageFont.truetype(font_path, 24)
    W = 1800
    blocks = []
    # 九宫格 / 背景
    x = y = 0
    rowh = 0
    tiles = []
    for name, im, dims in SHEET:
        iw, ih = im.size
        if x + max(iw, 132) + 16 > W:
            x = 0
            y += rowh + 36
            rowh = 0
        tiles.append((name, im, dims, x, y))
        x += max(iw, 132) + 24
        rowh = max(rowh, ih)
    h1 = y + rowh + 40
    # 物品图集（每格放大 4 倍 + 名称）
    ids = list(i16.keys())
    cw, ch = 16 * 4 + 44, 16 * 4 + 22
    per = W // cw
    h2 = ((len(ids) + per - 1) // per) * ch + 40
    h3 = 8 * 4 * 2 + 80
    sheet = Image.new("RGB", (W + 40, h1 + h2 + h3 + 120), (11, 11, 11))
    d = ImageDraw.Draw(sheet)
    d.text((20, 10), "Abyss Diver Girls v0.7.1 机库像素贴图素材表（全部 4× 最近邻放大：1 美术像素 = 4×4）", fill=(255, 176, 33), font=big)
    oy = 56
    d.text((20, oy - 4), "九宫格 / 平铺背景", fill=(219, 214, 191), font=font)
    oy += 16
    for name, im, dims, tx, ty in tiles:
        d.rectangle([20 + tx - 1, oy + ty - 1, 20 + tx + im.size[0], oy + ty + im.size[1]], outline=(41, 41, 37))
        sheet.paste(im, (20 + tx, oy + ty), im)
        d.text((20 + tx, oy + ty + im.size[1] + 4), "%s %s" % (name, dims), fill=(160, 160, 145), font=font)
    oy += h1
    d.text((20, oy - 20), "16×16 图标（物品 / 导航 / 设施，%d 个）" % len(ids), fill=(219, 214, 191), font=font)
    aimg = a16.image(1)
    for i, id_ in enumerate(ids):
        cx, cy = i16[id_]
        tile = aimg.crop((cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16)).resize((64, 64), Image.NEAREST)
        tx, ty = 20 + (i % per) * cw, oy + (i // per) * ch
        d.rectangle([tx, ty, tx + 63, ty + 63], fill=(29, 30, 28))
        sheet.paste(tile, (tx, ty), tile)
        d.text((tx, ty + 66), id_[:17], fill=(140, 138, 120), font=font)
    oy += h2
    d.text((20, oy - 20), "8×8 小图标 / 地形格（%s）" % ZONES, fill=(219, 214, 191), font=font)
    s8 = a8.image(4)
    sheet.paste(s8, (20, oy), s8)
    tt = terr.image(4)
    sheet.paste(tt, (40 + s8.size[0], oy), tt)
    for i, id_ in enumerate(i8):
        d.text((20 + i * 32, oy + 36), id_[:4], fill=(140, 138, 120), font=font)
    for i, z in enumerate(ZONES):
        d.text((40 + s8.size[0] + i * 32 + 10, oy + 36), z, fill=(140, 138, 120), font=font)
    # 色板
    py = oy + 70
    for i, c in enumerate(PALETTE):
        d.rectangle([20 + i * 22, py, 20 + i * 22 + 19, py + 19], fill=c)
    d.text((20, py + 24), "色板 %d 色：机库深灰 / 米白 / 琥珀 + 状态色 + 角色头像合并量化色" % len(PALETTE), fill=(140, 138, 120), font=font)
    return sheet


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    panel9(); inset9(); plate9(); hazard(); card9(False); card9(True); tip9()
    for s in ("n", "h", "on"):
        merchant9(s)
    nameplate9()
    for s in ("n", "h", "p", "d"):
        btn9(s); btn9(s, True)
    for s in ("n", "h", "p", "on"):
        nav9(s)
    topbar9(); botbar9()
    for k in ("empty", "slot", "r0", "r1", "r2", "r3"):
        cell9(k)
    for k in ("sel", "hover", "bad"):
        cell_overlay(k)
    for name, f in [("bg_base", bg_base), ("bg_trade", bg_trade), ("bg_deploy", bg_deploy), ("bg_skills", bg_skills),
                    ("bg_stash", bg_stash), ("bg_codex", bg_codex), ("chart", chart)]:
        out(f(), name)
    a16, i16 = build_atlas16()
    a8, i8 = build_atlas8()
    terr = build_terrain()
    write_index(i16, i8)
    sheet = build_sheet(a16, i16, a8, i8, terr)
    os.makedirs(os.path.join(ROOT, "review"), exist_ok=True)
    sheet.save(os.path.join(ROOT, "review/px_sheet.png"))
    print("ok", len(i16), "icons,", len(i8), "small,", len(SHEET), "textures, palette", len(PALETTE))


if __name__ == "__main__":
    main()
