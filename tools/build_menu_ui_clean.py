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
        font_main = get_font(["msyhbd.ttc", "simhei.ttf", "Dengb.ttf"], 76)
        char_spacing = 18
    else:
        font_main = get_font(["bahnschrift.ttf", "impact.ttf", "arialbd.ttf"], 66)
        char_spacing = 8

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

    # Stencil cuts (mechanical incisions)
    stencil = Image.new('L', (img_w, img_h), 255)
    sdraw = ImageDraw.Draw(stencil)
    if is_chinese:
        for sx in range(pad + 24, img_w - pad, 115):
            sdraw.line([(sx, pad + 6), (sx + 24, pad + max_h + 14)], fill=0, width=3)
            sdraw.line([(sx - 18, pad + max_h // 2), (sx + 32, pad + max_h // 2)], fill=0, width=2)
    else:
        for sx in range(pad + 35, img_w - pad, 85):
            sdraw.line([(sx, pad + 6), (sx + 22, pad + max_h + 10)], fill=0, width=3)
            sdraw.line([(sx - 16, pad + int(max_h * 0.46)), (sx + 26, pad + int(max_h * 0.46))], fill=0, width=2)

    cut_mask = ImageChops.multiply(mask, stencil)

    stroke_mask = cut_mask.filter(ImageFilter.MaxFilter(5))
    chamfer_mask = ImageChops.subtract(stroke_mask, cut_mask)

    glow = Image.new('RGBA', (img_w, img_h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    cur_x = pad
    for idx, ch in enumerate(title_text):
        gdraw.text((cur_x, pad), ch, font=font_main, fill=(255, 145, 30, 220))
        cur_x += char_boxes[idx][0] + char_spacing
    glow = glow.filter(ImageFilter.GaussianBlur(14))

    grad = make_gradient(img_w, img_h, (255, 255, 255, 255), (70, 85, 105, 255))
    core = Image.new('RGBA', (img_w, img_h), (0, 0, 0, 0))
    core.paste(grad, (0, 0), cut_mask)

    stroke_img = Image.new('RGBA', (img_w, img_h), (230, 240, 255, 240))
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

def get_prepared_backdrop():
    return Image.open('canvas_base_clean.png').convert("RGBA")

def build_clean_menu_ui(version="zh"):
    is_zh = (version == "zh")
    base_bg = get_prepared_backdrop()
    w, h = base_bg.size

    ui_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ui_layer)

    # Fonts: only typography and clean button fonts
    font_sub = get_font(["bahnschrift.ttf", "impact.ttf", "arialbd.ttf"], 18)
    font_btn = get_font(["msyhbd.ttc", "bahnschrift.ttf", "simhei.ttf"], 22 if is_zh else 20)

    # 1. Immersive Artistic Title
    title_str = "潜渊少女" if is_zh else "ABYSS DIVER GIRLS"
    title_img, pad = render_artistic_title(title_str, is_chinese=is_zh)
    
    title_pos_x = 90 - pad
    title_pos_y = 120 - pad
    ui_layer.paste(title_img, (title_pos_x, title_pos_y), title_img)

    # 2. Subtitle & Minimalist Accent Bar
    sub_y = 230
    bar_y = sub_y + 30
    bar_x = 92
    if is_zh:
        draw.text((bar_x, sub_y), "ABYSS DIVER GIRLS", font=font_sub, fill=(255, 185, 45, 240))
        draw.rectangle([bar_x, bar_y, bar_x + 180, bar_y + 4], fill=(255, 175, 45, 255))
    else:
        draw.rectangle([bar_x, bar_y - 10, bar_x + 220, bar_y - 6], fill=(255, 175, 45, 255))

    # 3. Canonical Buttons: exactly ["出击准备", "设置", "退出游戏"] (and English equivalents)
    btn_start_y = 310
    btn_w = 280
    btn_h = 56
    btn_gap = 20

    buttons = [
        ("出击准备", True) if is_zh else ("START", True),
        ("设置", False) if is_zh else ("SETTINGS", False),
        ("退出游戏", False) if is_zh else ("EXIT", False),
    ]

    for idx, (label, active) in enumerate(buttons):
        by = btn_start_y + idx * (btn_h + btn_gap)
        bx0 = 92
        bx1 = bx0 + btn_w
        by0 = by
        by1 = by0 + btn_h

        if active:
            # Active glowing halo
            glow_box = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            gdraw = ImageDraw.Draw(glow_box)
            draw_chamfer_rect(gdraw, [bx0 - 3, by0 - 3, bx1 + 3, by1 + 3], 8, fill=(255, 165, 30, 50))
            glow_box = glow_box.filter(ImageFilter.GaussianBlur(8))
            ui_layer = Image.alpha_composite(ui_layer, glow_box)
            draw = ImageDraw.Draw(ui_layer)

            # Active plate
            draw_chamfer_rect(draw, [bx0, by0, bx1, by1], 8, fill=(32, 36, 46, 235), outline=(255, 175, 40, 255), width=2)
            # Left accent highlight bar
            draw.polygon([(bx0 + 2, by0 + 8), (bx0 + 8, by0 + 2), (bx0 + 8, by1 - 2), (bx0 + 2, by1 - 8)], fill=(255, 175, 40, 255))
            
            # Button text
            draw.text((bx0 + 32, by0 + 13), label, font=font_btn, fill=(255, 255, 255, 255))
        else:
            # Inactive plate
            draw_chamfer_rect(draw, [bx0, by0, bx1, by1], 8, fill=(20, 22, 28, 175), outline=(68, 78, 92, 175), width=1)
            
            # Button text
            draw.text((bx0 + 32, by0 + 13), label, font=font_btn, fill=(205, 215, 228, 230))

    final_img = Image.alpha_composite(base_bg, ui_layer)
    return final_img

if __name__ == "__main__":
    zh_img = build_clean_menu_ui("zh")
    en_img = build_clean_menu_ui("en")

    zh_path = os.path.join(REVIEW_DIR, "主界面优化_中文版.png")
    en_path = os.path.join(REVIEW_DIR, "主界面优化_英文版.png")

    zh_img.save(zh_path)
    en_img.save(en_path)
    print("Clean UI generated and saved:")
    print(" ", zh_path)
    print(" ", en_path)
