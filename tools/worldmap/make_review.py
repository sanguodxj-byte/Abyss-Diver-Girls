# 审图拼图：worldmap_vs_ingame.png（每个战区：大地图裁切 / 游戏内正交俯视 / 游戏内小地图）与 worldmap_ui.png（降落页截图）。
# 先跑 tests/worldmap_3d.gd 与 tests/worldmap.gd（有界面）生成 review/ 下的截图，再运行本脚本；输出到 tools/worldmap/out/。
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REV = os.path.join(ROOT, "review")
OUT = os.path.join(ROOT, "tools/worldmap/out")
FONT = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/fusion-pixel-12px-zh_hans.ttf"), 12)
BG = (14, 15, 14)
CREAM = (219, 214, 191)
AMBER = (255, 176, 33)


def text(dr, xy, t, c=CREAM):
    dr.text(xy, t, font=FONT, fill=c)


def vs_ingame():
    meta = json.load(open(os.path.join(ROOT, "assets/ui/worldmap/worldmap.json"), encoding="utf-8"))
    wm = Image.open(os.path.join(ROOT, "assets/ui/worldmap/wm_1m.png")).convert("RGB")
    ids = [m for m in ["greyport", "redlake", "ironbelt", "dustfield", "canyon", "abyss_maw"] if m in meta["maps"]]
    S, PAD, HEAD = 360, 12, 22
    W = PAD + 3 * (S + PAD)
    H = 40 + len(ids) * (S + HEAD + PAD)
    im = Image.new("RGB", (W, H), BG)
    dr = ImageDraw.Draw(im)
    dr.fontmode = "1"
    text(dr, (PAD, 10), "左：降落页大地图裁切（1 像素 = 1 米，建筑按 24 个种子占用不少于一半时绘制）  中：游戏内正交俯视（种子 1）  右：游戏内小地图（同一局）", AMBER)
    y = 40
    for mid in ids:
        m = meta["maps"][mid]
        text(dr, (PAD, y + 4), "%s  %s" % (m["name"], mid))
        y += HEAD
        im.paste(wm.crop((m["x"], m["y"], m["x"] + S, m["y"] + S)), (PAD, y))
        p3 = os.path.join(REV, "wm3d_%s.png" % mid)
        if os.path.exists(p3):
            im.paste(Image.open(p3).convert("RGB").resize((S, S), Image.LANCZOS), (PAD + S + PAD, y))
        pm = os.path.join(REV, "wm3d_%s_mini.png" % mid)
        if os.path.exists(pm):
            im.paste(Image.open(pm).convert("RGB").resize((S, S), Image.NEAREST), (PAD + 2 * (S + PAD), y))
        y += S + PAD
    im.save(os.path.join(OUT, "worldmap_vs_ingame.png"), optimize=True)


def ui():
    shots = [("hubwm_1_default.png", "默认 ×0.5：选中灰港市（琥珀框 + 飞空艇），未解锁战区斜线阴影 + 锁"),
             ("hubwm_2_hover.png", "悬停：赤湖新区米白高亮（演示时按全部解锁显示）"),
             ("hubwm_3_zoom1.png", "放大一档 ×1：1 像素 = 1 米，青色转场口"),
             ("hubwm_4_zoom2.png", "放大两档 ×2：遗迹 / 撤离点名称"),
             ("hubwm_0_overview.png", "最远 ×0.25：整片城市群与地下竖井"),
             ("hubwm_5_locked.png", "未解锁战区特写")]
    w, h = 1280, 720
    HEAD = 20
    im = Image.new("RGB", (2 * w + 12, 3 * (h + HEAD) + 8), BG)
    dr = ImageDraw.Draw(im)
    dr.fontmode = "1"
    for i, (f, cap) in enumerate(shots):
        x = (i % 2) * (w + 12)
        y = (i // 2) * (h + HEAD) + 4
        text(dr, (x + 4, y + 3), cap, AMBER)
        p = os.path.join(REV, f)
        if os.path.exists(p):
            im.paste(Image.open(p).convert("RGB").resize((w, h), Image.NEAREST), (x, y + HEAD))
    im.save(os.path.join(OUT, "worldmap_ui.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    vs_ingame()
    ui()
    print("ok")
