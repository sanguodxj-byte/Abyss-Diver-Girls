# -*- coding: utf-8 -*-
r"""零噪点纯绿幕（#00FF00）抠图与内点色彩外推去绿边（Interior Color Inpainting & Neutral Despill）。

彻底根除两类异常噪点：
1. 严禁对半透明边缘执行 RGB / alpha 除法反解（该除法会把微小的 R/B 误差放大 5 倍，变成刺眼的品红/亮紫噪点）；
   改为从紧邻的不透明干净前景内点（alpha >= 0.95 且无绿溢）通过最近邻距离变换外推边缘 RGB，再配合平滑 Alpha 通道。
2. 对所有发丝夹缝中的暗绿/半绿像素（g_excess > 6）全局计算连续透明通道并执行 G <= 0.5*(R+B) 中性去绿，彻底消灭发丝内部残留绿斑。
"""

import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage


def matte_green_screen(img_rgb: Image.Image, cid: str = "") -> Image.Image:
    rgb = np.asarray(img_rgb.convert("RGB"), dtype=np.float32)
    h, w, _ = rgb.shape
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    max_rb = np.maximum(r, b)
    avg_rb = 0.5 * (r + b)
    g_excess = g - max_rb

    # 服装固有暗青/暗橄榄保护掩码（仅小满与胡桃存在偏绿固有色）
    protect = np.zeros((h, w), dtype=bool)
    if cid == "xiaoman":
        # 小满：暗青背心与发尾内挑染（B 显著较高，G < 148，g_excess < 44）
        protect = (b > r - 6.0) & (g < 148.0) & (g_excess < 44.0)
    elif cid == "kurumi":
        # 胡桃：暗橄榄野战夹克（暖橄榄色 R > B + 8，G < 135，g_excess < 36）
        protect = (r - b > 8.0) & (g < 135.0) & (g_excess < 36.0)

    # 1. 连续色键 Alpha：所有未受保护且带绿幕分量的像素（含极细发丝夹缝）直接按绿色超出量计算透明度
    # 纯绿背景 g_excess 约 140~240；半绿发丝夹缝 g_excess 约 12~90
    eff_excess = np.where(protect, np.maximum(0.0, g_excess - 38.0), g_excess)
    bg_strength = np.clip((eff_excess - 6.0) / 48.0, 0.0, 1.0)
    sure_bg = (~protect) & (g > 115.0) & (g_excess > 45.0)

    alpha = np.where(sure_bg, 0.0, 1.0 - bg_strength)
    # 轻微高斯柔化 Alpha 过渡，消除锯齿感
    alpha_smooth = ndimage.gaussian_filter(alpha, sigma=0.55)
    alpha = np.where(alpha < 0.98, np.minimum(alpha, alpha_smooth), alpha)
    alpha = np.where(alpha < 0.04, 0.0, alpha)

    # 2. 清理主体之外的游离微小噪点
    fg_bin = alpha > 0.12
    fg_lbl, fg_n = ndimage.label(fg_bin)
    if fg_n > 1:
        fg_sizes = np.bincount(fg_lbl.ravel())
        fg_sizes[0] = 0
        main_id = int(np.argmax(fg_sizes))
        min_keep = int(max(250, round((w * h) / 6000)))
        keep_fg = np.zeros(fg_n + 1, dtype=bool)
        for comp_id in range(1, fg_n + 1):
            if comp_id == main_id or fg_sizes[comp_id] >= min_keep:
                keep_fg[comp_id] = True
        alpha = np.where(keep_fg[fg_lbl], alpha, 0.0)

    # 3. 中性去绿溢（绝不除以 alpha，彻底杜绝品红/亮绿噪点）
    out_r = r.copy()
    out_g = g.copy()
    out_b = b.copy()

    # 对所有非保护区将 G 压回 avg(R, B) 中性上界，消灭任何绿光残留
    neutral_g = np.where(protect, np.minimum(out_g, max_rb + 18.0), np.minimum(out_g, avg_rb + 1.5))
    out_g = neutral_g

    # 4. 对半透明边缘像素（0 < alpha < 0.92），用紧邻的不透明干净前景内点 RGB 外推替代，消除绿幕暗边与杂色点
    clean_interior = (alpha >= 0.92) & (eff_excess <= 10.0)
    if np.any(clean_interior):
        _, (iy, ix) = ndimage.distance_transform_edt(~clean_interior, return_indices=True)
        edge_band = (alpha > 0.0) & (alpha < 0.92)
        blend_w = np.clip(1.0 - alpha / 0.92, 0.0, 1.0)
        out_r = np.where(edge_band, out_r * (1.0 - blend_w) + out_r[iy, ix] * blend_w, out_r)
        out_g = np.where(edge_band, out_g * (1.0 - blend_w) + out_g[iy, ix] * blend_w, out_g)
        out_b = np.where(edge_band, out_b * (1.0 - blend_w) + out_b[iy, ix] * blend_w, out_b)

    zero = alpha <= 0.01
    out_r = np.where(zero, 0.0, out_r)
    out_g = np.where(zero, 0.0, out_g)
    out_b = np.where(zero, 0.0, out_b)

    rgba = np.stack([
        np.clip(out_r + 0.5, 0, 255).astype(np.uint8),
        np.clip(out_g + 0.5, 0, 255).astype(np.uint8),
        np.clip(out_b + 0.5, 0, 255).astype(np.uint8),
        np.clip(alpha * 255.0 + 0.5, 0, 255).astype(np.uint8),
    ], axis=-1)
    return Image.fromarray(rgba, mode="RGBA")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--cid", default="")
    args = ap.parse_args()
    im = Image.open(args.input)
    out = matte_green_screen(im, cid=args.cid)
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    out.save(args.output, format="PNG")
    print(f"[matte] {args.input} -> {args.output} ({out.size[0]}x{out.size[1]} RGBA)")


if __name__ == "__main__":
    main()
