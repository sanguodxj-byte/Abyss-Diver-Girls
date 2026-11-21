# -*- coding: utf-8 -*-
"""将全员 11 张三视图的纯色背景（黑底/灰底）无损统一为纯白底 (#FFFFFF)。

保留角色内部 100% 原始像素，通过外部连通域 + 低方差封闭镂空检测 + 抗锯齿边缘反解，
彻底去除黑边/灰边并输出统一纯净白底。
"""

import glob
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = r"D:\123\qianyuanshaonv"
REV = os.path.join(ROOT, "review")
NAMES = ["奈绪", "零", "胡桃", "莉娜", "米娅", "阿堇", "小满", "诗织", "鸦", "霓虹", "银"]


def convert_to_white(path: str):
    im = Image.open(path).convert("RGB")
    arr = np.array(im, dtype=np.float32)
    h, w, _ = arr.shape

    # Sample background color from the 4 corners
    corners = np.array([
        arr[4, 4], arr[4, w - 5], arr[h - 5, 4], arr[h - 5, w - 5],
        arr[4, w // 2], arr[h - 5, w // 2],
    ])
    bg = np.median(corners, axis=0)

    # Already pure white? Just snap near-white border background cleanly to exact 255
    if np.all(bg >= 250):
        diff_w = np.max(np.abs(arr - 255.0), axis=2)
        near_w = diff_w <= 4
        # Border-connected near-white -> exact 255
        labeled, _ = ndimage.label(near_w)
        border_labels = set(np.unique(np.concatenate([
            labeled[0, :], labeled[-1, :], labeled[:, 0], labeled[:, -1]
        ]))) - {0}
        mask = np.isin(labeled, list(border_labels))
        out = arr.copy()
        out[mask] = 255.0
        Image.fromarray(out.astype(np.uint8)).save(path)
        return bg, "already_white_normalized"

    is_black = np.max(bg) < 20
    dist = np.max(np.abs(arr - bg[None, None, :]), axis=2)

    # 1. External border-connected background mask
    tol_ext = 10.0 if is_black else 15.0
    cand_ext = dist <= tol_ext
    labeled_ext, _ = ndimage.label(cand_ext)
    border_labels = set(np.unique(np.concatenate([
        labeled_ext[0, :], labeled_ext[-1, :], labeled_ext[:, 0], labeled_ext[:, -1]
    ]))) - {0}
    bg_mask = np.isin(labeled_ext, list(border_labels))

    # 2. Enclosed background holes ONLY for non-black backgrounds (grey/colored bg),
    # because pure black (0,0,0) shadows can appear inside black hair/trousers.
    holes_added = 0
    if not is_black:
        tol_hole = 9.0
        cand_hole = (dist <= tol_hole) & (~bg_mask)
        labeled_h, num_h = ndimage.label(cand_hole)
        if num_h > 0:
            counts = np.bincount(labeled_h.ravel())
            for lid in range(1, num_h + 1):
                if counts[lid] < 18:
                    continue
                ys, xs = np.where(labeled_h == lid)
                patch = arr[ys, xs]
                if float(np.std(patch)) <= 2.5:
                    bg_mask[ys, xs] = True
                    holes_added += 1

    # 3. Anti-aliased boundary transition (1-2px ring right outside bg_mask)
    # Build smooth foreground alpha: 0 on bg_mask, 1 deep inside character
    dil1 = ndimage.binary_dilation(bg_mask, iterations=1) & (~bg_mask)
    dil2 = ndimage.binary_dilation(bg_mask, iterations=2) & (~bg_mask) & (~dil1)

    out = arr.copy()
    out[bg_mask] = 255.0

    if is_black:
        # On black bg, boundary pixels are dark ink lineart blended with black (0,0,0).
        # Compute how close each boundary pixel is to pure black vs dark ink (~35)
        for ring, strength in [(dil1, 0.85), (dil2, 0.35)]:
            ys, xs = np.where(ring)
            if len(ys) == 0:
                continue
            pix = arr[ys, xs]
            d = np.max(np.abs(pix - bg[None, :]), axis=1)
            # Very dark fringe pixels (d < 22) blend smoothly toward white so black halo disappears
            w_bg = np.clip(1.0 - (d / 28.0), 0.0, 1.0) * strength
            # Keep ink crisp dark (~28) on the foreground side
            out[ys, xs] = pix * (1.0 - w_bg[:, None]) + 255.0 * w_bg[:, None]
    else:
        # On flat grey bg (e.g. 151/159/216), solve color unmixing for boundary ring
        for ring, thresh in [(dil1, 45.0), (dil2, 22.0)]:
            ys, xs = np.where(ring)
            if len(ys) == 0:
                continue
            pix = arr[ys, xs]
            d = np.max(np.abs(pix - bg[None, :]), axis=1)
            close = d < thresh
            if not np.any(close):
                continue
            alpha = np.clip(d[close] / thresh, 0.0, 1.0)
            # Re-composite onto pure white 255
            # Estimate foreground color by pushing away from bg slightly
            fg = np.clip((pix[close] - (1.0 - alpha[:, None]) * bg[None, :]) / np.maximum(alpha[:, None], 0.25), 0.0, 255.0)
            out[ys[close], xs[close]] = fg * alpha[:, None] + 255.0 * (1.0 - alpha[:, None])

    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(path)
    return bg, f"converted_to_white(holes={holes_added})"


def main():
    for tmp in glob.glob(os.path.join(REV, "_tmp_*")):
        try:
            os.remove(tmp)
        except OSError:
            pass

    for name in NAMES:
        p = os.path.join(REV, f"{name}_三视图.png")
        bg, status = convert_to_white(p)
        print(f"{name}: orig_bg={tuple(int(x) for x in bg)} -> {status}")


if __name__ == "__main__":
    main()
