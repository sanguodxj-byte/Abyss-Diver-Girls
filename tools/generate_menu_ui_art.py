import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = r"D:\123\qianyuanshaonv"
REVIEW_DIR = os.path.join(ROOT, "review")
os.makedirs(REVIEW_DIR, exist_ok=True)

def get_font(name_candidates, size):
    font_dirs = [r"C:\Windows\Fonts"]
    for cand in name_candidates:
        for d in font_dirs:
            p = os.path.join(d, cand)
            if os.path.exists(p):
                try:
                    return ImageFont.truetype(p, size)
                except Exception:
                    pass
    return ImageFont.load_default()

def draw_chamfer_rect(draw, bbox, c, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = bbox
    pts = [
        (x0 + c, y0), (x1 - c, y0),
        (x1, y0 + c), (x1, y1 - c),
        (x1 - c, y1), (x0 + c, y1),
        (x0, y1 - c), (x0, y0 + c)
    ]
    if fill:
        draw.polygon(pts, fill=fill)
    if outline:
        draw.polygon(pts, outline=outline)
        if width > 1:
            for w in range(1, width):
                sub_pts = [
                    (x0 + c + w, y0 + w), (x1 - c - w, y0 + w),
                    (x1 - w, y0 + c + w), (x1 - w, y1 - c - w),
                    (x1 - c - w, y1 - w), (x0 + c + w, y1 - w),
                    (x0 + w, y1 - c - w), (x0 + w, y0 + c + w)
                ]
                draw.polygon(sub_pts, outline=outline)

def make_gradient(width, height, top_color, bottom_color):
    base = Image.new('RGBA', (width, height))
    for y in range(height):
        t = y / max(1, height - 1)
        r = int(top_color[0] * (1 - t) + bottom_color[0] * t)
        g = int(top_color[1] * (1 - t) + bottom_color[1] * t)
        b = int(top_color[2] * (1 - t) + bottom_color[2] * t)
        a = int(top_color[3] * (1 - t) + bottom_color[3] * t)
        for x in range(width):
            base.putpixel((x, y), (r, g, b, a))
    return base

def render_artistic_title(title_text, is_chinese=True):
    if is_chinese:
        font_main = get_font(["msyhbd.ttc", "simhei.ttf", "Dengb.ttf"], 68)
        char_spacing = 14
    else:
        font_main = get_font(["bahnschrift.ttf", "impact.ttf", "arialbd.ttf"], 58)
        char_spacing = 6

    dummy = Image.new('RGBA', (1, 1))
    ddraw = ImageDraw.Draw(dummy)
    
    total_w = 0
    max_h = 0
    char_boxes = []
    for ch in title_text:
        box = ddraw.textbbox((0, 0), ch, font=font_main)
        cw = box[2] - box[0]
        ch_h = box[3] - box[1]
        char_boxes.append((cw, ch_h, box))
        total_w += cw + char_spacing
        if ch_h > max_h:
            max_h = ch_h
    total_w -= char_spacing

    pad = 40
    img_w = total_w + pad * 2
    img_h = max_h + pad * 2

    mask = Image.new('L', (img_w, img_h), 0)
    mdraw = ImageDraw.Draw(mask)
    cur_x = pad
    for idx, ch in enumerate(title_text):
        mdraw.text((cur_x, pad), ch, font=font_main, fill=255)
        cur_x += char_boxes[idx][0] + char_spacing

    # Stencil cuts
    stencil = Image.new('L', (img_w, img_h), 255)
    sdraw = ImageDraw.Draw(stencil)
    if is_chinese:
        for sx in range(pad + 18, img_w - pad, 105):
            sdraw.line([(sx, pad + 10), (sx + 20, pad + max_h + 10)], fill=0, width=3)
            sdraw.line([(sx - 15, pad + max_h // 2), (sx + 28, pad + max_h // 2)], fill=0, width=2)
    else:
        for sx in range(pad + 30, img_w - pad, 80):
            sdraw.line([(sx, pad + 8), (sx + 18, pad + max_h + 8)], fill=0, width=3)
            sdraw.line([(sx - 16, pad + int(max_h * 0.45)), (sx + 24, pad + int(max_h * 0.45))], fill=0, width=2)

    cut_mask = ImageChops.multiply(mask, stencil)

    stroke_mask = cut_mask.filter(ImageFilter.MaxFilter(5))
    chamfer_mask = ImageChops.subtract(stroke_mask, cut_mask)

    glow = Image.new('RGBA', (img_w, img_h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    cur_x = pad
    for idx, ch in enumerate(title_text):
        gdraw.text((cur_x, pad), ch, font=font_main, fill=(255, 145, 30, 210))
        cur_x += char_boxes[idx][0] + char_spacing
    glow = glow.filter(ImageFilter.GaussianBlur(14))

    grad = make_gradient(img_w, img_h, (252, 254, 255, 255), (75, 88, 108, 255))
    core = Image.new('RGBA', (img_w, img_h), (0, 0, 0, 0))
    core.paste(grad, (0, 0), cut_mask)

    stroke_img = Image.new('RGBA', (img_w, img_h), (225, 235, 250, 240))
    stroke_layer = Image.new('RGBA', (img_w, img_h), (0, 0, 0, 0))
    stroke_layer.paste(stroke_img, (0, 0), chamfer_mask)

    shadow_mask = cut_mask.filter(ImageFilter.GaussianBlur(3))
    shadow_layer = Image.new('RGBA', (img_w, img_h), (10, 12, 16, 240))
    shadow = Image.new('RGBA', (img_w, img_h), (0, 0, 0, 0))
    shadow.paste(shadow_layer, (4, 5), shadow_mask)

    out = Image.new('RGBA', (img_w, img_h), (0, 0, 0, 0))
    out = Image.alpha_composite(out, glow)
    out = Image.alpha_composite(out, shadow)
    out = Image.alpha_composite(out, stroke_layer)
    out = Image.alpha_composite(out, core)

    return out, pad

def build_menu_ui(version="zh"):
    is_zh = (version == "zh")
    base_bg = Image.open(r"canvas_base_clean.png").convert("RGBA")
    w, h = base_bg.size

    ui_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ui_layer)

    # Fonts
    font_mono_sm = get_font(["consola.ttf", "bahnschrift.ttf"], 12)
    font_mono_md = get_font(["consola.ttf", "bahnschrift.ttf"], 14)
    font_sub = get_font(["bahnschrift.ttf", "impact.ttf", "arialbd.ttf"], 16)
    font_lore = get_font(["msyh.ttc", "Deng.ttf", "simhei.ttf"], 13)
    font_btn_main = get_font(["msyhbd.ttc", "bahnschrift.ttf", "simhei.ttf"], 18 if is_zh else 17)
    font_btn_sub = get_font(["consola.ttf", "bahnschrift.ttf"], 11)

    # 1. Top HUD Coordinates and Telemetry
    draw.text((80, 42), "SYS.ONLINE  //  SECTOR 00: GREYPORT BASIN", font=font_mono_sm, fill=(255, 175, 45, 220))
    draw.text((80, 58), "LAT: 35°12'04\"N  LON: 114°28'50\"E  ALT: -420M  |  VISIBILITY: 42% DUST", font=font_mono_sm, fill=(130, 142, 160, 200))
    
    # Tactical line top
    draw.line([(80, 78), (480, 78)], fill=(80, 92, 110, 160), width=1)
    draw.rectangle([80, 76, 120, 80], fill=(255, 175, 45, 230))
    draw.line([(480, 78), (500, 98)], fill=(80, 92, 110, 160), width=1)

    # 2. Immersive Artistic Title
    title_str = "潜渊少女" if is_zh else "ABYSS DIVER GIRLS"
    title_img, pad = render_artistic_title(title_str, is_chinese=is_zh)
    
    title_pos_x = 80 - pad
    title_pos_y = 100 - pad
    ui_layer.paste(title_img, (title_pos_x, title_pos_y), title_img)

    # 3. Title Subtitle & Decals
    sub_y = 195
    if is_zh:
        draw.text((82, sub_y), "ABYSS DIVER GIRLS", font=font_sub, fill=(255, 185, 45, 240))
        draw.text((275, sub_y + 1), "// 战术深潜机兵部队 · 白鹭号打捞群", font=font_mono_sm, fill=(150, 165, 185, 220))
        
        # Hazard bar
        bar_x = 82
        bar_y = sub_y + 24
        draw.rectangle([bar_x, bar_y, bar_x + 160, bar_y + 4], fill=(255, 175, 45, 255))
        draw.line([(bar_x + 170, bar_y + 2), (bar_x + 420, bar_y + 2)], fill=(85, 100, 120, 180), width=1)
        for i in range(5):
            bx = bar_x + 180 + i * 16
            draw.polygon([(bx, bar_y), (bx + 8, bar_y), (bx + 4, bar_y + 4), (bx - 4, bar_y + 4)], fill=(255, 175, 45, 220))
    else:
        draw.text((82, sub_y), "SUB-TERRA MECHA EXTRACTION SHOOTER", font=font_sub, fill=(50, 225, 215, 240))
        draw.text((410, sub_y + 1), "// WING 08 · DEEP DIVER", font=font_mono_sm, fill=(150, 165, 185, 220))
        
        bar_x = 82
        bar_y = sub_y + 24
        draw.rectangle([bar_x, bar_y, bar_x + 180, bar_y + 4], fill=(50, 225, 215, 255))
        draw.line([(bar_x + 190, bar_y + 2), (bar_x + 460, bar_y + 2)], fill=(85, 100, 120, 180), width=1)
        for i in range(6):
            bx = bar_x + 200 + i * 16
            draw.polygon([(bx, bar_y), (bx + 8, bar_y), (bx + 4, bar_y + 4), (bx - 4, bar_y + 4)], fill=(255, 175, 45, 220))

    # 4. Buttons
    btn_start_y = 265
    btn_w = 340
    btn_h = 52
    btn_gap = 16

    buttons = [
        ("出击准备", "SORTIE // MISSION 01", True) if is_zh else ("DEPLOY MISSION", "SORTIE // SECTOR 01", True),
        ("机体整备", "HANGAR // ARMORY 02", False) if is_zh else ("MECHA HANGAR", "ARMORY // LOADOUT 02", False),
        ("战术设置", "SYSTEM // CONFIG 03", False) if is_zh else ("SYSTEM CONFIG", "SETTINGS // AUDIO GFX", False),
        ("撤出行动", "SHUTDOWN // TERMINATE", False) if is_zh else ("ABORT & EXIT", "TERMINATE // SHUTDOWN", False),
    ]

    for idx, (label, sub_label, active) in enumerate(buttons):
        by = btn_start_y + idx * (btn_h + btn_gap)
        bx0 = 82
        bx1 = bx0 + btn_w
        by0 = by
        by1 = by0 + btn_h

        if active:
            # Glow behind active button
            glow_box = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            gdraw = ImageDraw.Draw(glow_box)
            draw_chamfer_rect(gdraw, [bx0 - 2, by0 - 2, bx1 + 2, by1 + 2], 8, fill=(255, 165, 30, 45))
            glow_box = glow_box.filter(ImageFilter.GaussianBlur(8))
            ui_layer = Image.alpha_composite(ui_layer, glow_box)
            draw = ImageDraw.Draw(ui_layer)

            # Active button background plate
            draw_chamfer_rect(draw, [bx0, by0, bx1, by1], 8, fill=(32, 35, 44, 235), outline=(255, 175, 40, 255), width=2)
            # Left accent highlight strip
            draw.polygon([(bx0 + 2, by0 + 8), (bx0 + 8, by0 + 2), (bx0 + 8, by1 - 2), (bx0 + 2, by1 - 8)], fill=(255, 175, 40, 255))
            
            # Icon
            draw.text((bx0 + 24, by0 + 15), "▶", font=font_mono_md, fill=(255, 185, 50, 255))
            # Text
            draw.text((bx0 + 50, by0 + 14), label, font=font_btn_main, fill=(255, 255, 255, 255))
            draw.text((bx1 - 135, by0 + 19), sub_label, font=font_btn_sub, fill=(255, 195, 80, 230))
            # Tag marker
            draw.rectangle([bx1 - 24, by0 + 20, bx1 - 14, by0 + 30], fill=(50, 225, 215, 255))
        else:
            # Normal button
            draw_chamfer_rect(draw, [bx0, by0, bx1, by1], 8, fill=(20, 22, 28, 180), outline=(68, 78, 92, 180), width=1)
            # Icon
            draw.text((bx0 + 24, by0 + 16), "◇", font=font_mono_md, fill=(120, 135, 155, 200))
            # Text
            draw.text((bx0 + 50, by0 + 14), label, font=font_btn_main, fill=(205, 215, 228, 230))
            draw.text((bx1 - 135, by0 + 19), sub_label, font=font_btn_sub, fill=(110, 125, 145, 190))

    # 5. Bottom Lore Narrative
    lore_y = 575
    if is_zh:
        quote = "「云海之下陆地沦陷，信天翁号的少女们一次次驾机跃入深渊，在电池见底前把罐头与火种带回天空。」"
    else:
        quote = "\"Beneath the sea of clouds lies fallen earth. The girls of Albatross dive into the abyss, bringing back hope.\""
    
    draw.line([(82, lore_y - 12), (540, lore_y - 12)], fill=(75, 85, 100, 120), width=1)
    draw.text((82, lore_y), quote, font=font_lore, fill=(185, 195, 210, 185))

    # 6. Bottom Right Version & Status
    draw.text((w - 320, h - 48), "ABYSS DIVER GIRLS · BUILD v0.4.2", font=font_mono_sm, fill=(255, 175, 45, 200))
    draw.text((w - 320, h - 32), "REAL-TIME EXTRACTION  //  ONLINE READY", font=font_mono_sm, fill=(130, 142, 160, 180))

    # 7. Corner Tactical Brackets
    bw, bh = 24, 24
    pad_c = 28
    # Top-left
    draw.line([(pad_c, pad_c), (pad_c + bw, pad_c)], fill=(255, 175, 45, 220), width=2)
    draw.line([(pad_c, pad_c), (pad_c, pad_c + bh)], fill=(255, 175, 45, 220), width=2)
    # Top-right
    draw.line([(w - pad_c, pad_c), (w - pad_c - bw, pad_c)], fill=(255, 175, 45, 220), width=2)
    draw.line([(w - pad_c, pad_c), (w - pad_c, pad_c + bh)], fill=(255, 175, 45, 220), width=2)
    # Bottom-left
    draw.line([(pad_c, h - pad_c), (pad_c + bw, h - pad_c)], fill=(255, 175, 45, 220), width=2)
    draw.line([(pad_c, h - pad_c), (pad_c, h - pad_c - bh)], fill=(255, 175, 45, 220), width=2)
    # Bottom-right
    draw.line([(w - pad_c, h - pad_c), (w - pad_c - bw, h - pad_c)], fill=(255, 175, 45, 220), width=2)
    draw.line([(w - pad_c, h - pad_c), (w - pad_c, h - pad_c - bh)], fill=(255, 175, 45, 220), width=2)

    # Composite layers
    final_img = Image.alpha_composite(base_bg, ui_layer)
    return final_img

if __name__ == "__main__":
    zh_img = build_menu_ui("zh")
    en_img = build_menu_ui("en")

    zh_path = os.path.join(REVIEW_DIR, "主界面优化_中文版.png")
    en_path = os.path.join(REVIEW_DIR, "主界面优化_英文版.png")

    zh_img.save(zh_path)
    en_img.save(en_path)
    print("Generated and saved:")
    print(" ", zh_path)
    print(" ", en_path)
