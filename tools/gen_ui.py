# 生成 HUD / 主题贴图：玩家方 = 金属黑灰 + 亮橙黄（铁血紫留给敌方）
import os, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = "/workspace/work/salvage_crew/assets/ui"
os.makedirs(OUT, exist_ok=True)
SS = 4
random.seed(7)

BG = (20, 21, 24)
STEEL = (38, 40, 45)
STEEL2 = (52, 55, 61)
EDGE = (78, 83, 92)
HI = (122, 128, 138)
ACC = (255, 176, 32)
ACC2 = (255, 206, 84)
ACCD = (150, 96, 14)
BLK = (8, 8, 10)


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def down(img):
    w, h = img.size
    return img.resize((w // SS, h // SS), Image.LANCZOS)


def S(v):
    return [int(x * SS) for x in v] if isinstance(v, (list, tuple)) else int(v * SS)


def chamfer(x0, y0, x1, y1, c):
    """八角切角矩形顶点；c 可为单值或 (tl,tr,br,bl)"""
    if not isinstance(c, (list, tuple)):
        c = (c, c, c, c)
    tl, tr, br, bl = c
    return [(x0 + tl, y0), (x1 - tr, y0), (x1, y0 + tr), (x1, y1 - br), (x1 - br, y1), (x0 + bl, y1), (x0, y1 - bl), (x0, y0 + tl)]


def P(pts):
    return [(int(x * SS), int(y * SS)) for x, y in pts]


def grain(img, amt=10, brushed=True):
    w, h = img.size
    n = Image.effect_noise((w, h), amt * 2.0).convert("L")
    if brushed:
        n = n.resize((max(1, w // 24), h)).resize((w, h), Image.BILINEAR)
    a = img.split()[3]
    rgb = img.convert("RGB")
    nn = Image.merge("RGB", (n, n, n))
    rgb = ImageChops.add(ImageChops.subtract(rgb, Image.new("RGB", (w, h), (12, 12, 12))), ImageChops.multiply(nn, Image.new("RGB", (w, h), (24, 24, 24))))
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def metal_plate(w, h, c=10, fill=STEEL, edge=EDGE, top_acc=None, hazard=False, inner=True, alpha=235):
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    pts = chamfer(1, 1, w - 2, h - 2, c)
    d.polygon(P(pts), fill=fill + (alpha,))
    im = grain(im, 9)
    d = ImageDraw.Draw(im)
    # 斜面：上/左亮边，下/右暗边
    d.line(P(pts[7:] + pts[:3]), fill=HI + (255,), width=S(1.2))
    d.line(P(pts[2:7]), fill=BLK + (255,), width=S(1.6))
    if inner:
        ip = chamfer(5, 5, w - 6, h - 6, max(2, c - 4))
        d.line(P(ip + [ip[0]]), fill=(0, 0, 0, 120), width=S(1))
        ip2 = chamfer(6, 6, w - 7, h - 7, max(2, c - 4))
        d.line(P(ip2 + [ip2[0]]), fill=edge + (70,), width=S(0.8))
    if top_acc:
        d.polygon(P([(c + 4, 1), (min(w - c - 4, c + 4 + top_acc), 1), (min(w - c - 4, c + 4 + top_acc) - 3, 4), (c + 7, 4)]), fill=ACC + (255,))
    if hazard:
        hz(d, w - 30, h - 9, 22, 5)
    return im


def hz(d, x, y, w, h):
    """橙黑警示斜纹"""
    for i in range(-2, int(w / 4) + 2):
        x0 = x + i * 4
        d.polygon(P([(x0, y + h), (x0 + 2, y + h), (x0 + 2 + h, y), (x0 + h, y)]), fill=ACC + (230,))
    d.rectangle(P([(x - 6, y - 1), (x - 0.5, y + h + 1)]), fill=(0, 0, 0, 0))


def save(im, name):
    im.save(os.path.join(OUT, name))


def rivet(d, x, y, r=1.6):
    d.ellipse(P([(x - r, y - r), (x + r, y + r)]), fill=EDGE + (255,))
    d.ellipse(P([(x - r * 0.5, y - r * 0.7), (x + r * 0.2, y - r * 0.1)]), fill=HI + (255,))


# ---------------------------------------------------------------- 九宫格主题
def nine_panel():
    im = metal_plate(96, 96, 12, top_acc=34)
    d = ImageDraw.Draw(im)
    for x, y in [(9, 9), (87, 9), (9, 87), (87, 87)]:
        rivet(d, x, y)
    save(down(im), "panel9.png")
    # 左侧橙条面板（消息条、目标）
    im = metal_plate(64, 40, 6, fill=(16, 17, 20), alpha=210, inner=False)
    d = ImageDraw.Draw(im)
    d.polygon(P([(1, 7), (5, 3), (5, 37), (1, 33)]), fill=ACC + (255,))
    save(down(im), "strip9.png")
    im = metal_plate(64, 40, 6, fill=(26, 12, 10), alpha=215, inner=False)
    d = ImageDraw.Draw(im)
    d.polygon(P([(1, 7), (5, 3), (5, 37), (1, 33)]), fill=(255, 70, 40, 255))
    save(down(im), "strip9_warn.png")


def buttons():
    for name, fill, edge, acc in [("btn_n", STEEL, EDGE, ACCD), ("btn_h", STEEL2, ACCD, ACC), ("btn_p", (70, 46, 10), ACC, ACC2), ("btn_d", (26, 27, 30), (40, 42, 46), (60, 60, 60))]:
        im = metal_plate(72, 40, 8, fill=fill, edge=edge, inner=False)
        d = ImageDraw.Draw(im)
        d.polygon(P([(8, 35), (64, 35), (61, 38), (11, 38)]), fill=acc + (255,))
        d.line(P([(3, 12), (3, 28)]), fill=acc + (255,), width=S(1.5))
        save(down(im), name + ".png")
    # 主行动按钮（亮橙黄）
    for name, f in [("btn_main_n", (220, 140, 18)), ("btn_main_h", (255, 176, 32)), ("btn_main_p", (176, 104, 10))]:
        im = canvas(96, 44)
        d = ImageDraw.Draw(im)
        d.polygon(P(chamfer(1, 1, 94, 42, (12, 2, 12, 2))), fill=f + (255,))
        im = grain(im, 6)
        d = ImageDraw.Draw(im)
        d.line(P([(13, 2), (93, 2)]), fill=(255, 230, 150, 255), width=S(1))
        for i in range(5):
            x = 70 + i * 5
            d.polygon(P([(x, 40), (x + 2, 40), (x + 7, 33), (x + 5, 33)]), fill=(30, 20, 5, 200))
        save(down(im), name + ".png")


def lists():
    im = canvas(48, 48)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(1, 1, 46, 46, 6)), fill=(10, 11, 13, 200))
    d.line(P(chamfer(1, 1, 46, 46, 6) + [(7, 1)]), fill=EDGE + (160,), width=S(1))
    for x, y in [(1, 1), (46, 1), (1, 46), (46, 46)]:
        pass
    d.line(P([(7, 1), (16, 1)]), fill=ACC + (255,), width=S(1.5))
    save(down(im), "list9.png")
    im = canvas(48, 24)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(0, 1, 47, 22, 4)), fill=(255, 176, 32, 46))
    d.line(P([(0, 3), (0, 20)]), fill=ACC + (255,), width=S(2.5))
    save(down(im), "sel9.png")
    im = canvas(48, 24)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(0, 1, 47, 22, 4)), fill=(255, 255, 255, 14))
    save(down(im), "hover9.png")
    # 进度条
    im = canvas(48, 12)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(0, 0, 47, 11, 3)), fill=(6, 6, 8, 220))
    d.line(P(chamfer(0, 0, 47, 11, 3) + [(3, 0)]), fill=EDGE + (200,), width=S(1))
    save(down(im), "bar_bg9.png")
    im = canvas(48, 12)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(1, 2, 46, 9, 2)), fill=ACC + (255,))
    for i in range(0, 48, 4):
        d.line(P([(i, 2), (i, 9)]), fill=(120, 70, 0, 160), width=S(0.8))
    d.line(P([(2, 2.5), (45, 2.5)]), fill=ACC2 + (255,), width=S(0.8))
    save(down(im), "bar_fill9.png")
    # 滚动条
    im = canvas(12, 48)
    d = ImageDraw.Draw(im)
    d.rectangle(P([(4, 0), (8, 48)]), fill=(255, 255, 255, 14))
    save(down(im), "scroll9.png")
    im = canvas(12, 48)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(3, 1, 9, 47, 2)), fill=EDGE + (255,))
    save(down(im), "grab9.png")
    im = canvas(12, 48)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(3, 1, 9, 47, 2)), fill=ACC + (255,))
    save(down(im), "grab9_h.png")
    # 键帽
    im = canvas(32, 32)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(1, 1, 30, 30, 4)), fill=(30, 31, 35, 255))
    im = grain(im, 6)
    d = ImageDraw.Draw(im)
    d.polygon(P([(1, 25), (30, 25), (30, 26), (26, 30), (5, 30), (1, 26)]), fill=ACC + (255,))
    d.line(P([(5, 1.5), (26, 1.5)]), fill=HI + (255,), width=S(1))
    save(down(im), "key9.png")
    # 提示条
    im = metal_plate(64, 36, 8, fill=(14, 15, 18), alpha=225, inner=False)
    d = ImageDraw.Draw(im)
    d.line(P([(8, 34.5), (56, 34.5)]), fill=ACC + (255,), width=S(1.5))
    save(down(im), "prompt9.png")


# ---------------------------------------------------------------- L 形状态栏
def corner():
    W, H = 232, 232
    im = canvas(W, H)
    d = ImageDraw.Draw(im)
    outer = [(0, 14), (14, 0), (W - 34, 0), (W - 20, 14), (W - 2, 14), (W - 2, H - 2), (14, H - 2), (0, H - 16)]
    d.polygon(P(outer), fill=STEEL + (238,))
    im = grain(im, 10)
    d = ImageDraw.Draw(im)
    d.line(P(outer[:4] + [outer[7], outer[0]]), fill=HI + (255,), width=S(1.3))
    d.line(P([outer[4], outer[5], outer[6]]), fill=BLK + (255,), width=S(2))
    # 全息窗口：深色凹槽 + 网格
    wx0, wy0, wx1, wy1 = 12, 22, W - 12, H - 40
    win = chamfer(wx0, wy0, wx1, wy1, (10, 4, 10, 4))
    d.polygon(P(win), fill=(5, 7, 9, 255))
    for gx in range(wx0 + 8, wx1, 12):
        d.line(P([(gx, wy0 + 2), (gx, wy1 - 2)]), fill=(255, 176, 32, 14), width=S(0.6))
    for gy in range(wy0 + 8, wy1, 12):
        d.line(P([(wx0 + 2, gy), (wx1 - 2, gy)]), fill=(255, 176, 32, 14), width=S(0.6))
    d.line(P(win + [win[0]]), fill=(0, 0, 0, 255), width=S(1.6))
    d.line(P([win[3], win[4], win[5], win[6]]), fill=EDGE + (200,), width=S(1))
    # 窗口四角括号
    L = 12
    for (x, y, sx, sy) in [(wx0 + 4, wy0 + 4, 1, 1), (wx1 - 4, wy0 + 4, -1, 1), (wx0 + 4, wy1 - 4, 1, -1), (wx1 - 4, wy1 - 4, -1, -1)]:
        d.line(P([(x, y + sy * L), (x, y), (x + sx * L, y)]), fill=ACC + (220,), width=S(1.4))
    # 投影发射器：窗口底部的发光槽
    ex = (wx0 + wx1) / 2
    d.polygon(P([(ex - 42, wy1 - 1), (ex + 42, wy1 - 1), (ex + 34, wy1 + 5), (ex - 34, wy1 + 5)]), fill=(30, 32, 36, 255))
    d.rectangle(P([(ex - 30, wy1 + 1), (ex + 30, wy1 + 3)]), fill=ACC + (255,))
    # 底部信息条（结构/能源读数底板）
    by0 = H - 34
    d.polygon(P([(14, by0), (W - 10, by0), (W - 10, H - 8), (20, H - 8), (14, H - 14)]), fill=(12, 13, 15, 255))
    d.line(P([(14, by0), (W - 10, by0)]), fill=EDGE + (255,), width=S(1))
    # 顶部铭牌 + 警示斜纹
    d.polygon(P([(18, 4), (W - 40, 4), (W - 36, 8), (W - 40, 12), (18, 12)]), fill=(16, 17, 19, 255))
    hz(d, W - 30, 15, 22, 4)
    for x, y in [(6, 30), (6, H - 30), (W - 7, 24), (W - 7, H - 12)]:
        rivet(d, x, y, 1.8)
    # 侧面通风槽
    for i in range(5):
        d.rectangle(P([(3, 90 + i * 8), (6, 94 + i * 8)]), fill=BLK + (255,))
    save(down(im), "corner.png")


def rails():
    # 竖向子弹槽（可平铺）：两条凹槽导轨，导轨间刻度
    W, H = 76, 64
    im = canvas(W, H)
    d = ImageDraw.Draw(im)
    d.rectangle(P([(0, 0), (W, H)]), fill=STEEL + (232,))
    im = grain(im, 10)
    d = ImageDraw.Draw(im)
    d.line(P([(1, 0), (1, H)]), fill=HI + (255,), width=S(1.2))
    d.line(P([(W - 1, 0), (W - 1, H)]), fill=BLK + (255,), width=S(1.6))
    for cx in (20, 56):
        d.rectangle(P([(cx - 15, 0), (cx + 15, H)]), fill=(6, 7, 9, 255))
        d.line(P([(cx - 15, 0), (cx - 15, H)]), fill=(0, 0, 0, 255), width=S(1.2))
        d.line(P([(cx + 15, 0), (cx + 15, H)]), fill=EDGE + (150,), width=S(0.8))
    for y in range(0, H, 8):
        d.line(P([(37, y), (39 if y % 16 else 41, y)]), fill=ACC + (150,), width=S(0.8))
    save(down(im), "rail_v.png")
    # 子弹槽顶端盖
    im = canvas(W, 26)
    d = ImageDraw.Draw(im)
    d.polygon(P([(0, 26), (0, 12), (12, 0), (W - 1, 0), (W - 1, 26)]), fill=STEEL2 + (240,))
    im = grain(im, 8)
    d = ImageDraw.Draw(im)
    d.line(P([(0, 12), (12, 0), (W - 1, 0)]), fill=HI + (255,), width=S(1.2))
    d.polygon(P([(16, 5), (W - 6, 5), (W - 6, 9), (16, 9)]), fill=ACC + (255,))
    hz(d, 22, 14, 44, 5)
    save(down(im), "rail_v_cap.png")
    # 横向技能导轨（可平铺）
    W, H = 64, 88
    im = canvas(W, H)
    d = ImageDraw.Draw(im)
    d.rectangle(P([(0, 0), (W, H)]), fill=STEEL + (232,))
    im = grain(im, 10, brushed=False)
    d = ImageDraw.Draw(im)
    d.line(P([(0, 1), (W, 1)]), fill=HI + (255,), width=S(1.2))
    d.line(P([(0, H - 1), (W, H - 1)]), fill=BLK + (255,), width=S(1.6))
    d.rectangle(P([(0, H - 14), (W, H - 6)]), fill=(8, 8, 10, 255))
    for x in range(0, W, 8):
        d.line(P([(x, H - 14), (x, H - 12 if x % 16 else H - 10)]), fill=ACC + (130,), width=S(0.8))
    save(down(im), "rail_h.png")
    im = canvas(30, 88)
    d = ImageDraw.Draw(im)
    d.polygon(P([(0, 0), (16, 0), (29, 14), (29, 87), (0, 87)]), fill=STEEL2 + (240,))
    im = grain(im, 8)
    d = ImageDraw.Draw(im)
    d.line(P([(0, 1), (16, 1), (29, 14)]), fill=HI + (255,), width=S(1.2))
    d.polygon(P([(18, 24), (24, 30), (24, 70), (18, 70)]), fill=ACC + (255,))
    save(down(im), "rail_h_cap.png")


# ---------------------------------------------------------------- 子弹贴图（水平横放，弹头朝右）
def bullets():
    def brass(d, x0, y0, x1, y1):
        d.rectangle(P([(x0, y0), (x1, y1)]), fill=(196, 146, 52, 255))
        d.rectangle(P([(x0, y0), (x1, y0 + (y1 - y0) * 0.3)]), fill=(240, 202, 112, 255))
        d.rectangle(P([(x0, y1 - (y1 - y0) * 0.22), (x1, y1)]), fill=(120, 84, 24, 255))

    # 机炮弹 56x12
    im = canvas(56, 12)
    d = ImageDraw.Draw(im)
    d.rectangle(P([(2, 1.5), (6, 10.5)]), fill=(150, 108, 36, 255))
    brass(d, 6, 2.5, 36, 9.5)
    d.polygon(P([(36, 2.5), (44, 2.5), (54, 6), (44, 9.5), (36, 9.5)]), fill=(170, 92, 52, 255))
    d.polygon(P([(36, 2.5), (44, 2.5), (52, 5), (36, 5)]), fill=(222, 140, 92, 255))
    d.line(P([(10, 2.5), (10, 9.5)]), fill=(90, 60, 14, 255), width=S(0.8))
    save(down(im), "ammo_mg.png")
    # 霰弹 60x18
    im = canvas(60, 18)
    d = ImageDraw.Draw(im)
    d.rectangle(P([(1, 1), (5, 17)]), fill=(150, 108, 36, 255))
    brass(d, 5, 2, 18, 16)
    d.rectangle(P([(18, 2), (58, 16)]), fill=(46, 48, 54, 255))
    d.rectangle(P([(18, 2), (58, 6)]), fill=(84, 88, 96, 255))
    d.rectangle(P([(18, 13), (58, 16)]), fill=(24, 25, 28, 255))
    d.rectangle(P([(26, 6.5), (50, 12)]), fill=ACC + (255,))
    d.line(P([(58, 2), (58, 16)]), fill=(14, 14, 16, 255), width=S(1.4))
    save(down(im), "ammo_shell.png")
    # 激光能量电池 52x16
    im = canvas(52, 16)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(1, 1, 51, 15, 3)), fill=(40, 42, 48, 255))
    d.rectangle(P([(8, 4), (44, 12)]), fill=(255, 196, 60, 255))
    d.rectangle(P([(8, 4), (44, 6.5)]), fill=(255, 240, 180, 255))
    for x in (17, 26, 35):
        d.line(P([(x, 3), (x, 13)]), fill=(40, 42, 48, 255), width=S(1.2))
    d.rectangle(P([(46, 5), (51, 11)]), fill=(150, 154, 162, 255))
    gl = im.filter(ImageFilter.GaussianBlur(S(2)))
    im = Image.alpha_composite(gl, im)
    save(down(im), "ammo_cell.png")
    # 火焰燃料罐 56x16
    im = canvas(56, 16)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(P([(2, 1.5), (48, 14.5)]), radius=S(3), fill=(176, 92, 18, 255))
    d.rectangle(P([(4, 2), (46, 5)]), fill=(232, 150, 52, 255))
    for x in (12, 24, 36):
        d.rectangle(P([(x, 1), (x + 2, 15)]), fill=(52, 54, 60, 255))
    d.rectangle(P([(48, 4), (54, 12)]), fill=(120, 124, 132, 255))
    hz(d, 16, 10, 16, 3)
    save(down(im), "ammo_fuel.png")


# ---------------------------------------------------------------- 技能槽 + 图标
def slots():
    im = canvas(84, 84)
    d = ImageDraw.Draw(im)
    pts = chamfer(1, 1, 82, 82, (14, 3, 14, 3))
    d.polygon(P(pts), fill=(26, 27, 31, 250))
    im = grain(im, 8)
    d = ImageDraw.Draw(im)
    d.polygon(P(chamfer(6, 6, 77, 77, (10, 2, 10, 2))), fill=(8, 9, 11, 255))
    d.line(P(pts[7:] + pts[:3]), fill=HI + (255,), width=S(1.2))
    d.line(P(pts[2:7]), fill=BLK + (255,), width=S(1.8))
    d.line(P([(18, 2.5), (66, 2.5)]), fill=ACC + (255,), width=S(1.6))
    for x, y in [(5, 79), (79, 5)]:
        rivet(d, x, y, 1.4)
    save(down(im), "slot.png")
    im = canvas(84, 84)
    d = ImageDraw.Draw(im)
    d.line(P(chamfer(2, 2, 81, 81, (14, 3, 14, 3)) + [(16, 2)]), fill=ACC2 + (255,), width=S(2.2))
    gl = im.filter(ImageFilter.GaussianBlur(S(3)))
    save(down(Image.alpha_composite(gl, im)), "slot_ready.png")
    # 宽键帽（SPACE）与窄键帽
    for name, w in [("cap_wide.png", 84), ("cap.png", 34)]:
        im = canvas(w, 22)
        d = ImageDraw.Draw(im)
        d.polygon(P(chamfer(1, 1, w - 2, 20, 4)), fill=(34, 35, 40, 255))
        d.polygon(P([(1, 15), (w - 2, 15), (w - 2, 16), (w - 6, 20), (5, 20), (1, 16)]), fill=ACC + (255,))
        d.line(P([(5, 2), (w - 6, 2)]), fill=HI + (255,), width=S(1))
        save(down(im), name)


def icon(name, draw):
    im = canvas(64, 64)
    d = ImageDraw.Draw(im)
    draw(d)
    a = down(im)
    # 发光底
    glow = a.filter(ImageFilter.GaussianBlur(2.2))
    out = Image.alpha_composite(glow, a)
    out.save(os.path.join(OUT, "ic_" + name + ".png"))


W_ = (255, 255, 255, 255)


def icons():
    def dash(d):
        for i, x in enumerate((8, 20, 32)):
            d.polygon(P([(x, 18), (x + 12, 32), (x, 46), (x + 6, 46), (x + 18, 32), (x + 6, 18)]), fill=(255, 255, 255, 110 + i * 70))
        d.polygon(P([(44, 22), (56, 32), (44, 42)]), fill=W_)
    def leap(d):
        d.arc(P([(8, 14), (56, 70)]), 200, 340, fill=W_, width=S(4))
        d.polygon(P([(48, 22), (58, 30), (46, 34)]), fill=W_)
        d.polygon(P([(6, 50), (20, 50), (24, 56), (2, 56)]), fill=W_)
        d.polygon(P([(42, 50), (58, 50), (62, 56), (38, 56)]), fill=W_)
    def blink(d):
        d.ellipse(P([(4, 24), (20, 40)]), outline=(255, 255, 255, 140), width=S(2))
        for i in range(4):
            d.line(P([(22 + i * 6, 32), (25 + i * 6, 32)]), fill=W_, width=S(2))
        d.polygon(P([(44, 20), (56, 32), (44, 44), (32, 32)]), fill=W_)
        d.polygon(P([(44, 26), (50, 32), (44, 38), (38, 32)]), fill=(0, 0, 0, 255))
    def ram(d):
        d.polygon(P([(10, 20), (36, 20), (52, 32), (36, 44), (10, 44)]), fill=W_)
        d.polygon(P([(14, 26), (32, 26), (40, 32), (32, 38), (14, 38)]), fill=(0, 0, 0, 255))
        for y in (16, 32, 48):
            d.line(P([(54, y - 4), (60, y)]), fill=W_, width=S(2.5))
    def missile(d):
        for k, x in enumerate((14, 30, 46)):
            y = 14 + (k % 2) * 8
            d.polygon(P([(x, y), (x + 5, y + 8), (x + 5, y + 34), (x - 5, y + 34), (x - 5, y + 8)]), fill=W_)
            d.polygon(P([(x - 5, y + 28), (x - 9, y + 38), (x - 5, y + 34)]), fill=W_)
            d.polygon(P([(x + 5, y + 28), (x + 9, y + 38), (x + 5, y + 34)]), fill=W_)
    def shield(d):
        pts = [(32, 6), (54, 14), (52, 36), (32, 58), (12, 36), (10, 14)]
        d.polygon(P(pts), outline=W_, width=S(4))
        d.polygon(P([(32, 16), (44, 21), (42, 34), (32, 46)]), fill=W_)
    def lock(d):
        d.rectangle(P([(16, 30), (48, 54)]), fill=(255, 255, 255, 120))
        d.arc(P([(20, 12), (44, 40)]), 180, 360, fill=(255, 255, 255, 120), width=S(4))
    def decoy(d):
        d.ellipse(P([(20, 20), (44, 44)]), outline=W_, width=S(3))
        d.ellipse(P([(28, 28), (36, 36)]), fill=W_)
        for a in range(0, 360, 90):
            r = math.radians(a + 45)
            d.line(P([(32 + math.cos(r) * 16, 32 + math.sin(r) * 16), (32 + math.cos(r) * 26, 32 + math.sin(r) * 26)]), fill=W_, width=S(3))
        d.arc(P([(4, 4), (60, 60)]), 200, 250, fill=(255, 255, 255, 150), width=S(2))
        d.arc(P([(4, 4), (60, 60)]), 20, 70, fill=(255, 255, 255, 150), width=S(2))
    def overdrive(d):
        d.polygon(P([(36, 4), (16, 36), (30, 36), (24, 60), (48, 26), (34, 26), (42, 4)]), fill=W_)
    def quake(d):
        d.polygon(P([(24, 8), (40, 8), (40, 30), (48, 30), (32, 44), (16, 30), (24, 30)]), fill=W_)
        d.line(P([(4, 52), (14, 48), (22, 56), (32, 48), (42, 56), (50, 48), (60, 52)]), fill=W_, width=S(3))
    def charge(d):
        d.rectangle(P([(14, 14), (46, 56)]), outline=W_, width=S(3))
        d.rectangle(P([(24, 8), (36, 14)]), fill=W_)
        d.polygon(P([(32, 20), (22, 38), (30, 38), (26, 52), (40, 32), (32, 32), (36, 20)]), fill=W_)
    def vent(d):
        for i in range(3):
            x = 16 + i * 16
            d.line(P([(x, 56), (x - 4, 44), (x + 4, 32), (x - 4, 20), (x, 8)]), fill=W_, width=S(3.5))
        d.rectangle(P([(6, 56), (58, 60)]), fill=W_)
    def repair(d):
        d.polygon(P([(14, 50), (40, 24), (44, 28), (18, 54)]), fill=W_)
        d.ellipse(P([(36, 8), (58, 30)]), outline=W_, width=S(4))
        d.polygon(P([(46, 6), (54, 6), (50, 18)]), fill=(0, 0, 0, 255))
        d.rectangle(P([(6, 8), (22, 12)]), fill=W_)
        d.rectangle(P([(12, 2), (16, 18)]), fill=W_)
    for n, f in [("dash", dash), ("leap", leap), ("blink", blink), ("ram", ram), ("missile", missile), ("shield", shield), ("lock", lock),
                 ("decoy", decoy), ("overdrive", overdrive), ("quake", quake), ("charge", charge), ("vent", vent), ("repair", repair)]:
        icon(n, f)


# ---------------------------------------------------------------- 雷达框 + 准星不改
def radar():
    S0 = 200
    im = canvas(S0, S0)
    d = ImageDraw.Draw(im)
    c = S0 / 2
    d.ellipse(P([(4, 4), (S0 - 4, S0 - 4)]), outline=STEEL2 + (255,), width=S(9))
    d.ellipse(P([(4, 4), (S0 - 4, S0 - 4)]), outline=HI + (255,), width=S(1.2))
    d.ellipse(P([(12, 12), (S0 - 12, S0 - 12)]), outline=BLK + (255,), width=S(1.5))
    for a in range(0, 360, 10):
        r = math.radians(a)
        r0, r1 = (c - 8, c - 2) if a % 30 else (c - 12, c - 2)
        d.line(P([(c + math.cos(r) * r0, c + math.sin(r) * r0), (c + math.cos(r) * r1, c + math.sin(r) * r1)]), fill=(ACC + (255,)) if a % 90 == 0 else (190, 194, 200, 200), width=S(1.2 if a % 30 else 2))
    d.arc(P([(1, 1), (S0 - 1, S0 - 1)]), 300, 340, fill=ACC + (255,), width=S(3))
    d.arc(P([(1, 1), (S0 - 1, S0 - 1)]), 120, 160, fill=ACC + (255,), width=S(3))
    save(down(im), "radar_ring.png")


nine_panel(); buttons(); lists(); corner(); rails(); bullets(); slots(); icons(); radar()
print("ok", len(os.listdir(OUT)))
