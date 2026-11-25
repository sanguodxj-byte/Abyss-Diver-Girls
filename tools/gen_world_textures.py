#!/usr/bin/env python3
"""
写实工业世界与植被 PBR 贴图离线生成器（输出无缝 PNG 到 assets/textures/world/）。
所有平铺贴图采用周期性 FFT 噪声与周期坐标构造，严格保证四方连续无缝平铺；
所有 Alpha 裁切植物贴图对透明像素执行多级 RGB 边缘颜色外扩（dilation），彻底消除 Mipmap 黑边/白边。
用法：python tools/gen_world_textures.py
"""
import os
import sys
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "world")
os.makedirs(OUT, exist_ok=True)
FOLIAGE_ONLY = "--foliage-only" in sys.argv


def fnoise(h, w, beta=2.0, lo=0.0, seed=1, ax=1.0, ay=1.0):
    """四方连续 1/f^beta 各向异性/同性分形噪声，返回 0..1。"""
    r = np.random.default_rng(seed)
    wn = r.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] / ay
    fx = (np.fft.fftfreq(w)[None, :] * (w / h)) / ax
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(f, beta / 2.0)
    if lo > 0:
        amp *= 1.0 - np.exp(-(f / lo) ** 2)
    amp[0, 0] = 0.0
    n = np.real(np.fft.ifft2(np.fft.fft2(wn) * amp))
    n -= n.min()
    mx = n.max()
    return n / mx if mx > 1e-8 else np.zeros((h, w))


def blur(a, s):
    """周期高斯模糊（FFT）。"""
    h, w = a.shape[:2]
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * (np.pi * s) ** 2 * (fx * fx + fy * fy))
    if a.ndim == 3:
        out = np.empty_like(a)
        for c in range(a.shape[2]):
            out[..., c] = np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * g))
        return out
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-8), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    if np.ndim(a) == 3 and np.ndim(t) == 2:
        t = t[..., None]
    elif np.ndim(b) == 3 and np.ndim(t) == 2:
        t = t[..., None]
    return a + (b - a) * t


def normal_from_height(hgt, strength):
    """周期差分法线（OpenGL +Y 朝上，适配 Godot）。"""
    gx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * strength
    gy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(hgt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True) + 1e-8
    return n * 0.5 + 0.5


def normal_from_height_clamped(hgt, strength):
    """非周期边缘夹取法线（用于单株枝叶裁切贴图）。"""
    hp = np.pad(hgt, 1, mode="edge")
    gx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * strength
    gy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * strength
    n = np.dstack([-gx, gy, np.ones_like(hgt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True) + 1e-8
    return n * 0.5 + 0.5


def dilate_rgb_by_alpha(rgb, alpha, iters=18):
    """将有效像素的 RGB 向透明区域外扩，彻底杜绝 Mipmap 采样黑边/灰边。"""
    c = rgb.copy()
    m = alpha > 0.08
    for _ in range(iters):
        if m.all():
            break
        acc = np.zeros_like(c)
        cnt = np.zeros(alpha.shape, dtype=np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            mc = np.roll(np.roll(m, dy, 0), dx, 1)
            cc = np.roll(np.roll(c, dy, 0), dx, 1)
            # 阻止跨边界卷绕污染
            if dy == -1:
                mc[-1, :] = False
            elif dy == 1:
                mc[0, :] = False
            if dx == -1:
                mc[:, -1] = False
            elif dx == 1:
                mc[:, 0] = False
            w = mc.astype(np.float32)
            acc += cc * w[..., None]
            cnt += w
        fill = (~m) & (cnt > 0)
        c[fill] = acc[fill] / cnt[fill, None]
        m = m | fill
    return c


def save_rgb(name, a):
    Image.fromarray((np.clip(a, 0.0, 1.0) * 255.0).astype(np.uint8), "RGB").save(os.path.join(OUT, name))


def save_rgba(name, rgb, alpha):
    rgb_pad = dilate_rgb_by_alpha(rgb, alpha, iters=20)
    rgba = np.dstack([rgb_pad, alpha])
    Image.fromarray((np.clip(rgba, 0.0, 1.0) * 255.0).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))


def voronoi_periodic(h, w, cells_y, cells_x, jitter=0.82, seed=10):
    """快速周期性网格 Voronoi：返回 (d1, d2-d1, cell_id_hash)。"""
    r = np.random.default_rng(seed)
    ox = r.uniform(0.5 - 0.5 * jitter, 0.5 + 0.5 * jitter, (cells_y, cells_x))
    oy = r.uniform(0.5 - 0.5 * jitter, 0.5 + 0.5 * jitter, (cells_y, cells_x))
    cid = r.uniform(0.0, 1.0, (cells_y, cells_x))

    yy = np.linspace(0.0, cells_y, h, endpoint=False)[:, None]
    xx = np.linspace(0.0, cells_x, w, endpoint=False)[None, :]
    iy = np.floor(yy).astype(np.int32)
    ix = np.floor(xx).astype(np.int32)
    fy = yy - iy
    fx = xx - ix

    d1 = np.full((h, w), 1e9, dtype=np.float32)
    d2 = np.full((h, w), 1e9, dtype=np.float32)
    best_id = np.zeros((h, w), dtype=np.float32)

    for dy in (-1, 0, 1):
        ny = (iy + dy) % cells_y
        for dx in (-1, 0, 1):
            nx = (ix + dx) % cells_x
            px = dx + ox[ny, nx] - fx
            py = dy + oy[ny, nx] - fy
            d = np.sqrt(px * px + py * py)
            m1 = d < d1
            d2 = np.where(m1, d1, np.minimum(d2, d))
            best_id = np.where(m1, cid[ny, nx], best_id)
            d1 = np.where(m1, d, d1)
    return d1, d2 - d1, best_id


H, W = 512, 512
v = np.linspace(0.0, 1.0, H, endpoint=False)[:, None] * np.ones((1, W))
u = np.ones((H, 1)) * np.linspace(0.0, 1.0, W, endpoint=False)[None, :]


# ==============================================================================
# 10. 写实纵裂龟甲老树皮 (bark_a / bark_n — 消除斑马条纹，改用各向异性 Voronoi 纵裂鳞片)
# ==============================================================================
def _gen_bark_and_foliage():
    # 10. Bark (512x512 seamless) — 浮点双线性域扭曲，彻底消除锯齿阶梯边
    bk_lo = fnoise(H, W, 2.3, seed=1001, ax=0.55, ay=3.2)
    bk_mid = fnoise(H, W, 1.55, seed=1002, ax=0.40, ay=3.8)
    bk_hi = fnoise(H, W, 0.95, seed=1003, ax=0.65, ay=2.6)
    bk_fine = fnoise(H, W, 0.80, seed=1006)
    # 纵向拉长 Voronoi 树皮鳞甲（2 尺度叠加 + 浮点双线性扭曲）
    _, v_edge1, v_id1 = voronoi_periodic(H, W, 8, 22, jitter=0.90, seed=1011)
    _, v_edge2, v_id2 = voronoi_periodic(H, W, 18, 44, jitter=0.92, seed=1012)
    shift_x = (bk_lo - 0.5) * 16.0 + (bk_mid - 0.5) * 5.5
    ys_idx = np.arange(H)[:, None]
    fx = (np.arange(W, dtype=np.float32)[None, :] + shift_x) % W
    x0 = np.floor(fx).astype(np.int32)
    x1 = (x0 + 1) % W
    tx = fx - x0
    e1 = v_edge1[ys_idx, x0] * (1.0 - tx) + v_edge1[ys_idx, x1] * tx
    id1 = v_id1[ys_idx, x0] * (1.0 - tx) + v_id1[ys_idx, x1] * tx
    e2 = v_edge2[ys_idx, x0] * (1.0 - tx) + v_edge2[ys_idx, x1] * tx
    id2 = v_id2[ys_idx, x0] * (1.0 - tx) + v_id2[ys_idx, x1] * tx

    deep_crack = 1.0 - ss(0.025, 0.22, e1 + (bk_mid - 0.5) * 0.12)
    sub_crack = 1.0 - ss(0.02, 0.15, e2)
    fissure = np.clip(deep_crack * 0.88 + sub_crack * 0.30, 0.0, 1.0)
    plate_var = (id1 - 0.5) * 0.13 + (id2 - 0.5) * 0.07
    lichen = ss(0.77, 0.93, fnoise(H, W, 2.1, seed=1005)) * (1.0 - fissure * 0.88) * 0.55

    bark_val = np.clip(
        0.58
        + plate_var
        + (bk_lo - 0.5) * 0.13
        + (bk_mid - 0.5) * 0.09
        + (bk_hi - 0.5) * 0.09
        + (bk_fine - 0.5) * 0.05
        - fissure * 0.33,
        0.18,
        0.78,
    )
    bark_rgb = np.dstack([
        bark_val * 1.02 - lichen * 0.06,
        bark_val * 0.95 + lichen * 0.05,
        bark_val * 0.86 - lichen * 0.05,
    ])
    bark_h = np.clip((1.0 - fissure * 0.82) * (0.52 + plate_var * 0.8 + bk_hi * 0.26) + bk_fine * 0.12, 0.0, 1.0)
    save_rgb("bark_a.png", bark_rgb)
    save_rgb("bark_n.png", normal_from_height(bark_h, 6.4))

    # ==============================================================================
    # 11. 1024x1024 高密写实针叶冷杉/油松枝簇裁切贴图 (pine_frond_a RGBA / pine_frond_n RGB)
    # 自然纺锤锥形分叉冷杉枝束 + 非预乘直通 Alpha 合成（彻底杜绝发黑毛边）
    # ==============================================================================
    FH, FW = 1024, 1024
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    pu = xx / (FW - 1.0)
    pv = 1.0 - yy / (FH - 1.0)  # pv=0 枝根, pv=1 枝梢
    micro_n = fnoise(FH, FW, 1.4, seed=1199)
    macro_n = fnoise(FH, FW, 2.3, seed=1198)

    pine_alpha = np.zeros((FH, FW), dtype=np.float32)
    pine_rgb = np.zeros((FH, FW, 3), dtype=np.float32)
    pine_h = np.zeros((FH, FW), dtype=np.float32)
    rng_p = np.random.default_rng(1123)

    # 自然收尖的非对称冷杉枝束骨架（中下部丰满、顶部自然收尖，枝组间有真实呼吸空隙）
    twigs = []
    # (x0, y0, x1, y1, tw_r, is_main, depth_layer)
    twigs.append((0.50, 0.02, 0.503, 0.94, 0.0078, True, 1))
    # 主干两侧非对称节位
    branch_specs = [
        (0.11, -1.0, 0.25, 0.44), (0.14,  1.0, 0.27, 0.42),
        (0.23, -1.0, 0.35, 0.46), (0.26,  1.0, 0.34, 0.48),
        (0.36, -1.0, 0.33, 0.50), (0.39,  1.0, 0.31, 0.52),
        (0.49, -1.0, 0.27, 0.56), (0.52,  1.0, 0.26, 0.54),
        (0.62, -1.0, 0.20, 0.62), (0.65,  1.0, 0.19, 0.64),
        (0.74, -1.0, 0.14, 0.72), (0.77,  1.0, 0.13, 0.70),
        (0.84, -1.0, 0.08, 0.80), (0.86,  1.0, 0.075, 0.82),
    ]
    for idx, (y0, side, reach, rise) in enumerate(branch_specs):
        r_j = reach * rng_p.uniform(0.92, 1.08)
        x0 = 0.50 + side * 0.004
        x1 = np.clip(0.50 + side * r_j, 0.07, 0.93)
        y1 = np.clip(y0 + r_j * rise + 0.02, 0.08, 0.95)
        # 背层暗影辅枝（略窄，只做立体厚度，不扩大外缘成方框）
        twigs.append((x0, y0 + 0.008, x0 + (x1 - x0) * 0.86, min(0.94, y1 + 0.015), 0.0044, False, 0))
        # 前层主侧枝
        twigs.append((x0, y0, x1, y1, 0.0048, False, 1))
        if idx < 10:
            for frac, s_ang in ((0.40, 0.34), (0.68, -0.18)):
                mx = x0 + (x1 - x0) * frac
                my = y0 + (y1 - y0) * frac
                s_r = r_j * rng_p.uniform(0.30, 0.42)
                sx1 = np.clip(mx + side * s_r, 0.07, 0.93)
                sy1 = np.clip(my + s_r * (rise + s_ang), 0.08, 0.95)
                twigs.append((mx, my, sx1, sy1, 0.0034, False, 0 if s_ang < 0 else 1))

    twigs.sort(key=lambda t: t[6])
    for x0, y0, x1, y1, tw_r, is_main, layer in twigs:
        dx, dy = x1 - x0, y1 - y0
        seg_len = float(np.hypot(dx, dy)) + 1e-6
        ux, uy = dx / seg_len, dy / seg_len
        nx_t, ny_t = -uy, ux

        rx = pu - x0
        ry = pv - y0
        t_proj = rx * ux + ry * uy
        s_perp = rx * nx_t + ry * ny_t
        abs_s = np.abs(s_perp)

        needle_len = (0.056 if is_main else (0.068 if layer == 0 else 0.062)) * (1.0 - 0.20 * y0)
        t_root = t_proj - abs_s * 0.90
        in_band = (t_root >= -0.012) & (t_root <= seg_len + 0.016) & (abs_s <= needle_len * 1.12)
        if not np.any(in_band):
            continue

        sub_t = t_root[in_band]
        sub_s = s_perp[in_band]
        sub_as = abs_s[in_band]
        sub_mn = micro_n[in_band]
        sub_ma = macro_n[in_band]

        # 高频清脆针束，内芯饱满密实（逆光天空下呈现蓬松冷杉枝廓而非空心鱼骨）
        n_coord = sub_t * 275.0 + np.sign(sub_s) * 2.1 + np.sin(sub_t * 59.0) * 0.7 + sub_mn * 2.1
        c1 = 0.5 + 0.5 * np.sin(n_coord)
        c2 = 0.5 + 0.5 * np.sin(n_coord * 1.71 + 1.3)
        c3 = 0.5 + 0.5 * np.sin(n_coord * 0.53 + 2.7)
        tip_reach = needle_len * (0.58 + 0.26 * c1 + 0.20 * c2) * (0.88 + 0.12 * np.sin(sub_t * 31.0))
        tip_fade = ss(0.0, 0.014, sub_t + 0.008) * (1.0 - ss(seg_len - 0.012, seg_len + 0.014, sub_t))
        rr = sub_as / (tip_reach + 1e-5)

        n_mask = (1.0 - ss(0.78, 1.03, rr)) * tip_fade
        outer_sep = ss(0.46, 0.95, rr)
        strand = np.maximum(c1, c2 * 0.88)
        n_mask *= (1.0 - outer_sep * (1.0 - ss(0.24, 0.60, strand)))
        n_mask = ss(0.16, 0.58, n_mask)

        # 物理准确 PBR sRGB 寒带针叶色板（sRGB 0.28..0.52 -> 线性 0.06..0.23，逆光与背阴绝不压成黑炭剪影）
        dry_p = ss(0.74, 0.93, sub_ma * 0.55 + c3 * 0.45)
        shade_l = 0.80 if layer == 0 else 1.00
        c_base = np.array([0.24, 0.30, 0.22], dtype=np.float32) * shade_l
        c_mid = np.array([0.33, 0.41, 0.28], dtype=np.float32) * shade_l
        c_tip = np.array([0.43, 0.49, 0.33], dtype=np.float32) * shade_l
        c_dry = np.array([0.50, 0.42, 0.28], dtype=np.float32) * shade_l

        rt = np.clip(rr, 0.0, 1.0)[:, None]
        col_n = c_base * (1.0 - rt) + c_mid * rt
        col_n = col_n * (1.0 - rt * 0.42) + c_tip * (rt * 0.42)
        col_n = col_n * (1.0 - dry_p[:, None] * 0.36) + c_dry * (dry_p[:, None] * 0.36)
        col_n *= (0.87 + 0.26 * sub_mn[:, None])
        h_n = (0.22 if layer == 0 else 0.44) + (1.0 - rt[:, 0]) * 0.28 + strand * 0.24

        t_cl = np.clip(t_proj[in_band], 0.0, seg_len)
        d_tw = np.hypot(pu[in_band] - (x0 + ux * t_cl), pv[in_band] - (y0 + uy * t_cl))
        tw_w = tw_r * (1.0 - 0.45 * (t_cl / seg_len))
        tw_mask = 1.0 - ss(tw_w * 0.55, tw_w * 1.10, d_tw)
        tw_col = np.array([0.22, 0.17, 0.13], dtype=np.float32) * shade_l

        comb_a = np.maximum(n_mask, tw_mask)
        comb_c = col_n * (1.0 - tw_mask[:, None] * 0.85) + tw_col * (tw_mask[:, None] * 0.85)
        comb_h = np.maximum(h_n * n_mask, tw_mask * (0.58 if layer == 0 else 0.82))

        old_a = pine_alpha[in_band]
        cur_c = pine_rgb[in_band]
        # Porter-Duff Straight-Alpha 正确叠加（永不向黑色背景预乘，杜绝黑边）
        cur_c = cur_c * (1.0 - np.clip(comb_a * 0.18, 0.0, 0.18)[:, None])
        out_a = comb_a + old_a * (1.0 - comb_a)
        w_eff = np.where(out_a > 1e-5, comb_a / np.maximum(out_a, 1e-5), 0.0)[:, None]
        pine_rgb[in_band] = np.where((comb_a > 0.01)[:, None], cur_c * (1.0 - w_eff) + comb_c * w_eff, cur_c)
        pine_alpha[in_band] = np.clip(out_a, 0.0, 1.0)
        pine_h[in_band] = np.where(comb_a > 0.25, np.maximum(pine_h[in_band], comb_h), pine_h[in_band])

    save_rgba("pine_frond_a.png", pine_rgb, pine_alpha)
    save_rgb("pine_frond_n.png", normal_from_height_clamped(pine_h, 4.8))

    # ==============================================================================
    # 12. 1024x1024 高密写实阔叶乔木细叶枝簇裁切贴图 (broadleaf_a RGBA / broadleaf_n RGB)
    # 460+ 片真实比例细小叶片紧贴分叉细枝簇生（零浮空离群叶 + 饱满内芯 + 非预乘直通 Alpha）
    # ==============================================================================
    bl_alpha = np.zeros((FH, FW), dtype=np.float32)
    bl_rgb = np.zeros((FH, FW, 3), dtype=np.float32)
    bl_h = np.zeros((FH, FW), dtype=np.float32)
    rng_b = np.random.default_rng(1217)
    leaf_tex = fnoise(FH, FW, 1.35, seed=1251)
    leaf_var_n = fnoise(FH, FW, 2.2, seed=1252)

    # 紧凑自然的多级分叉细枝骨架（形成丰满的树冠叶团，而非稀疏骨架）
    bl_twigs = [
        (0.50, 0.04, 0.495, 0.88, 0.0072),
        (0.50, 0.16, 0.21, 0.46, 0.0052),
        (0.50, 0.19, 0.79, 0.48, 0.0052),
        (0.497, 0.34, 0.17, 0.68, 0.0046),
        (0.497, 0.37, 0.83, 0.70, 0.0046),
        (0.495, 0.54, 0.26, 0.86, 0.0040),
        (0.495, 0.56, 0.74, 0.87, 0.0040),
        # 二级侧枝填充内芯与中缘
        (0.35, 0.31, 0.16, 0.33, 0.0034),
        (0.65, 0.33, 0.84, 0.35, 0.0034),
        (0.33, 0.51, 0.16, 0.56, 0.0032),
        (0.67, 0.53, 0.84, 0.58, 0.0032),
        (0.39, 0.69, 0.25, 0.78, 0.0028),
        (0.61, 0.71, 0.75, 0.80, 0.0028),
        (0.42, 0.44, 0.33, 0.62, 0.0030),
        (0.58, 0.46, 0.67, 0.64, 0.0030),
        (0.46, 0.66, 0.38, 0.85, 0.0028),
        (0.54, 0.68, 0.62, 0.86, 0.0028),
    ]

    # 生成 ~470 片真实小叶，叶柄紧贴所在细枝（偏移 <= 0.022，彻底杜绝浮空孤立叶）
    leaves = []
    for ti, (x0, y0, x1, y1, _) in enumerate(bl_twigs):
        n_on_twig = 36 if ti < 7 else 22
        base_ang = float(np.arctan2(y1 - y0, x1 - x0))
        for k in range(n_on_twig):
            ft = (k + 0.5 + rng_b.uniform(-0.22, 0.22)) / float(n_on_twig)
            ft = float(np.clip(ft, 0.06, 1.00))
            bx = x0 + (x1 - x0) * ft + rng_b.uniform(-0.022, 0.022)
            by = y0 + (y1 - y0) * ft + rng_b.uniform(-0.020, 0.020)
            if bx < 0.08 or bx > 0.92 or by < 0.08 or by > 0.92:
                continue
            side_s = -1.0 if (k % 2 == 0) else 1.0
            ang = base_ang + side_s * rng_b.uniform(0.25, 1.25) + rng_b.uniform(-0.20, 0.20)
            # 内芯叶略宽实、外缘叶清秀细密
            r_cent = float(np.hypot((bx - 0.50) * 1.15, (by - 0.52) * 1.10))
            sz_k = 1.12 if r_cent < 0.24 else 0.96
            lw = rng_b.uniform(0.024, 0.041) * sz_k
            ll = lw * rng_b.uniform(1.50, 1.95)
            layer = 0 if (k % 3 == 0) else (1 if (k % 3 == 1) else 2)
            leaves.append((layer, bx, by, ang, lw, ll, rng_b.uniform(0.0, 1.0), rng_b.uniform(-0.18, 0.18)))

    def _stamp_leaves(subset):
        for layer, lx, ly, ang, lw, ll, tone, bend in subset:
            ca, sa = np.cos(ang), np.sin(ang)
            du = pu - lx
            dv = pv - ly
            lu = (du * ca + dv * sa) / ll
            lv = (-du * sa + dv * ca) / lw
            lv = lv - bend * (lu * lu)

            box = (lu >= -0.04) & (lu <= 1.06) & (np.abs(lv) <= 1.28)
            if not np.any(box):
                continue
            slu = lu[box]
            slv = lv[box]
            aslv = np.abs(slv)
            s_tex = leaf_tex[box]
            s_var = leaf_var_n[box]

            cl_u = np.clip(slu, 0.0, 1.0)
            profile = (np.sin(cl_u * np.pi) ** 0.78) * (1.0 - 0.30 * cl_u)
            serrate = 0.052 * np.sin(slu * 38.0) * ss(0.14, 0.88, slu)
            half_w = np.maximum(0.018, profile + serrate)
            edge_d = aslv / half_w
            l_mask = (1.0 - ss(0.86, 1.02, edge_d)) * ss(-0.02, 0.05, slu) * (1.0 - ss(0.95, 1.02, slu))

            midrib = (1.0 - ss(0.025, 0.095, aslv)) * (1.0 - ss(0.75, 0.96, cl_u))
            side_v = (1.0 - ss(0.04, 0.17, np.abs(np.mod((slu - aslv * 0.45) * 8.0, 1.0) - 0.5))) * (1.0 - edge_d * 0.55)
            vein = np.clip(midrib * 0.65 + side_v * 0.30, 0.0, 1.0)

            # 物理准确 PBR sRGB 去饱和阔叶色板（sRGB 0.30..0.56 -> 线性 0.07..0.27，低饱和写实而非发黑或荧光绿）
            c_deep = np.array([0.28, 0.35, 0.23], dtype=np.float32)
            c_olive = np.array([0.36, 0.44, 0.27], dtype=np.float32)
            c_sage = np.array([0.45, 0.50, 0.32], dtype=np.float32)
            c_dry = np.array([0.55, 0.46, 0.29], dtype=np.float32)
            if tone < 0.42:
                base_c = lerp(c_deep, c_olive, tone / 0.42)
            elif tone < 0.82:
                base_c = lerp(c_olive, c_sage, (tone - 0.42) / 0.40)
            else:
                base_c = lerp(c_sage, c_dry, (tone - 0.82) / 0.18)

            depth_mul = 0.74 if layer == 0 else (0.92 if layer == 1 else 1.06)
            grad = (0.82 + 0.24 * cl_u - 0.10 * np.clip(edge_d, 0.0, 1.0) + (s_tex - 0.5) * 0.16 + (s_var - 0.5) * 0.10)[:, None]
            l_col = base_c[None, :] * depth_mul * grad + np.array([0.030, 0.036, 0.015], dtype=np.float32)[None, :] * vein[:, None] * depth_mul

            prev_a = bl_alpha[box]
            cur_c = bl_rgb[box]
            sh_rim = (1.0 - ss(0.92, 1.28, edge_d)) * (1.0 - l_mask) * (prev_a > 0.18)
            cur_c = cur_c * (1.0 - sh_rim[:, None] * 0.28)

            # Porter-Duff Straight-Alpha 正确叠加（永不向黑色背景预乘）
            out_a = l_mask + prev_a * (1.0 - l_mask)
            w_eff = np.where(out_a > 1e-5, l_mask / np.maximum(out_a, 1e-5), 0.0)[:, None]
            vis = l_mask > 0.02
            bl_rgb[box] = np.where(vis[:, None], cur_c * (1.0 - w_eff) + l_col * w_eff, cur_c)
            bl_alpha[box] = np.clip(out_a, 0.0, 1.0)
            lh_base = 0.20 if layer == 0 else (0.45 if layer == 1 else 0.72)
            lh = (lh_base + 0.24 * (1.0 - np.clip(edge_d, 0.0, 1.0)) - 0.10 * aslv + vein * 0.10) * l_mask
            bl_h[box] = np.where(l_mask > 0.35, lh, bl_h[box])

    _stamp_leaves([l for l in leaves if l[0] == 0])
    # 木质细枝穿插在背叶与中/表叶之间（直通 Alpha）
    for x0, y0, x1, y1, tr in bl_twigs:
        dx, dy = x1 - x0, y1 - y0
        sl = float(np.hypot(dx, dy)) + 1e-6
        t_p = np.clip(((pu - x0) * dx + (pv - y0) * dy) / (sl * sl), 0.0, 1.0)
        dist = np.hypot(pu - (x0 + dx * t_p), pv - (y0 + dy * t_p))
        tm = 1.0 - ss(tr * (1.0 - 0.42 * t_p) * 0.55, tr * (1.0 - 0.42 * t_p) * 1.15, dist)
        out_a = tm + bl_alpha * (1.0 - tm)
        w_eff = np.where(out_a > 1e-5, tm / np.maximum(out_a, 1e-5), 0.0)[..., None]
        tw_c = np.array([0.22, 0.18, 0.14], dtype=np.float32) * (0.85 + 0.30 * leaf_tex[..., None])
        bl_rgb = np.where((tm > 0.02)[..., None], bl_rgb * (1.0 - w_eff) + tw_c * w_eff, bl_rgb)
        bl_alpha = np.clip(out_a, 0.0, 1.0)
        bl_h = np.where(tm > 0.25, np.maximum(bl_h, 0.42), bl_h)
    _stamp_leaves([l for l in leaves if l[0] == 1])
    _stamp_leaves([l for l in leaves if l[0] == 2])

    save_rgba("broadleaf_a.png", bl_rgb, bl_alpha)
    save_rgb("broadleaf_n.png", normal_from_height_clamped(bl_h, 5.0))


_gen_bark_and_foliage()
if FOLIAGE_ONLY:
    print("Regenerated bark & foliage textures only in:", os.path.abspath(OUT))
    sys.exit(0)



# ==============================================================================
# 1. 轧制重工钢板底纹 (steel_plate_a / steel_plate_n)
# 连续无缝热轧氧化皮、拉丝微纹理与轻微擦痕，供全尺寸机械部件、枪管、装甲与钢结构通用三平面采样
# ==============================================================================
n_lo = fnoise(H, W, 2.4, seed=101)
n_mid = fnoise(H, W, 1.55, seed=102)
n_roll = fnoise(H, W, 1.35, seed=103, ax=6.0, ay=0.65)
n_brush = fnoise(H, W, 1.05, seed=106, ax=9.0, ay=0.45)
n_pit = fnoise(H, W, 0.88, seed=104)
mill_scale = ss(0.36, 0.74, blur(n_mid, 1.4) * 0.65 + n_lo * 0.35)
scuff = ss(0.78, 0.94, fnoise(H, W, 1.15, seed=105, ax=4.2, ay=0.85))

steel_val = np.clip(
    0.82
    + (n_lo - 0.5) * 0.085
    + (n_mid - 0.5) * 0.055
    + (n_roll - 0.5) * 0.050
    + (n_brush - 0.5) * 0.032
    + (n_pit - 0.5) * 0.028
    - (mill_scale - 0.5) * 0.045
    + scuff * 0.038,
    0.70,
    0.93,
)
steel_rgb = np.dstack([
    steel_val * (0.992 - (mill_scale - 0.5) * 0.012),
    steel_val * 1.000,
    steel_val * (1.012 + (mill_scale - 0.5) * 0.014),
])
steel_h = (
    n_lo * 0.28
    + n_mid * 0.18
    + n_roll * 0.22
    + n_brush * 0.12
    + n_pit * 0.08
    - mill_scale * 0.10
    - ss(0.76, 0.93, n_pit) * 0.06
)
save_rgb("steel_plate_a.png", steel_rgb)
save_rgb("steel_plate_n.png", normal_from_height(steel_h, 2.2))


# ==============================================================================
# 2. 工业现浇模板混凝土 (concrete_a / concrete_n)
# ==============================================================================
c_lo = fnoise(H, W, 2.5, seed=201)
c_mid = fnoise(H, W, 1.6, seed=202)
c_grain = fnoise(H, W, 1.2, seed=203, ax=5.5, ay=0.7)  # 木模板横纹
c_agg = fnoise(H, W, 0.75, seed=204)                   # 砂石细骨料
c_streak = fnoise(H, W, 1.8, seed=205, ax=0.35, ay=4.5)  # 雨水垂向水渍

boards = 6.0
bv = np.mod(v * boards + (c_lo - 0.5) * 0.025, 1.0)
b_idx = np.floor(v * boards)
b_seam = 1.0 - ss(0.010, 0.034, np.minimum(bv, 1.0 - bv))
b_tone = np.sin(b_idx * 53.7) * 0.5 + 0.5

# 对拉螺杆浅封堵印与微弱水痕（保持低对比度，兼容墙面立面与场坪双旋转采样）
tu = np.mod(u * 4.0 + np.mod(np.floor(v * 4.0), 2.0) * 0.5, 1.0) - 0.5
tv = np.mod(v * 4.0, 1.0) - 0.5
td = np.sqrt((tu * 4.0) ** 2 + (tv * 4.0) ** 2)
tie_hole = np.clip(1.0 - (td / 0.14) ** 2, 0.0, 1.0)
tie_drip = np.exp(-((tu * 22.0) ** 2)) * ss(0.0, 0.04, tv) * (1.0 - ss(0.04, 0.32, tv))

# 砂浆风化斑驳与微孔隙
c_spall = ss(0.62, 0.86, blur(c_mid, 1.5) * 0.6 + c_agg * 0.4)
micro_pit = ss(0.76, 0.94, c_agg)

conc_val = (
    0.84
    + (c_lo - 0.5) * 0.15
    + (c_grain - 0.5) * 0.070
    + (c_agg - 0.5) * 0.085
    + (b_tone - 0.5) * 0.042
    - (c_streak - 0.5) * 0.11
    - b_seam * 0.065
    - tie_hole * 0.11
    - tie_drip * 0.055
    - c_spall * 0.075
    - micro_pit * 0.06
)
conc_rgb = np.dstack([
    conc_val + tie_drip * 0.015,
    conc_val * 0.995,
    conc_val * 0.982 - tie_drip * 0.02,
])
conc_h = (
    c_lo * 0.32 + c_grain * 0.20 + c_agg * 0.24
    - b_seam * 0.12 - tie_hole * 0.22 - c_spall * 0.12
    - micro_pit * 0.16
)
save_rgb("concrete_a.png", conc_rgb)
save_rgb("concrete_n.png", normal_from_height(conc_h, 3.6))


# ==============================================================================
# 3. 重工业顺丁错缝砖墙 (brick_a / brick_n)
# ==============================================================================
b_courses = 12.0
b_cols = 6.0
by = v * b_courses + (fnoise(H, W, 2.6, seed=301) - 0.5) * 0.04
cy_idx = np.floor(by)
bx = u * b_cols + np.mod(cy_idx, 2.0) * 0.5 + (fnoise(H, W, 2.6, seed=302) - 0.5) * 0.025
cx_idx = np.floor(bx)
fu = np.mod(bx, 1.0)
fv = np.mod(by, 1.0)

# 灰缝宽度（横向略厚于竖向，带砖边微崩角噪声）
chip_n = fnoise(H, W, 1.2, seed=303)
mort_y = 1.0 - ss(0.055, 0.115, np.minimum(fv, 1.0 - fv) + (chip_n - 0.5) * 0.035)
mort_x = 1.0 - ss(0.030, 0.068, np.minimum(fu, 1.0 - fu) + (chip_n - 0.5) * 0.025)
mortar = np.clip(np.maximum(mort_y, mort_x), 0.0, 1.0)

# 每块砖独立窑变色差（使用周期索引保证无缝）
iy_mod = np.mod(cy_idx, b_courses)
ix_mod = np.mod(cx_idx, b_cols)
brick_id = np.mod(np.sin(iy_mod * 127.1 + ix_mod * 311.7) * 43758.5453, 1.0)
brick_id2 = np.mod(np.sin(iy_mod * 269.5 + ix_mod * 183.3) * 24634.6345, 1.0)

b_surf = fnoise(H, W, 1.1, seed=304)
b_soot = fnoise(H, W, 2.3, seed=305)
efflor = ss(0.72, 0.90, fnoise(H, W, 2.0, seed=306))  # 轻微泛碱白霜

# 保持均值约 0.80 中性偏暖，乘以建筑红棕/赭石/暗灰底色都能呈现丰富窑变砖色
brick_face_v = (
    0.82
    + (brick_id - 0.5) * 0.24
    - ss(0.82, 0.98, brick_id2) * 0.20  # 少量过火青黑砖
    + (b_surf - 0.5) * 0.10
    - (b_soot - 0.5) * 0.12
)
brick_r = brick_face_v * (1.03 + (brick_id2 - 0.5) * 0.08)
brick_g = brick_face_v * (0.98 - (brick_id2 - 0.5) * 0.03)
brick_b = brick_face_v * (0.93 - (brick_id2 - 0.5) * 0.07)
brick_col = np.dstack([brick_r, brick_g, brick_b])
brick_col = lerp(brick_col, np.array([0.88, 0.87, 0.85]), efflor * 0.25)

mort_v = 0.52 + (b_surf - 0.5) * 0.12 - (b_soot - 0.5) * 0.08
mort_col = np.dstack([mort_v * 0.98, mort_v * 0.98, mort_v * 0.96])
brick_rgb = lerp(brick_col, mort_col, mortar)
# 砖缝上沿微小投影暗线
top_lip = ss(0.08, 0.16, fv) * (1.0 - ss(0.16, 0.26, fv)) * (1.0 - mort_x)
brick_rgb *= (1.0 - top_lip[..., None] * 0.10)

brick_h = (1.0 - mortar) * (0.62 + (brick_id - 0.5) * 0.10 + b_surf * 0.18) + mortar * (0.12 + chip_n * 0.08)
save_rgb("brick_a.png", brick_rgb)
save_rgb("brick_n.png", normal_from_height(brick_h, 4.6))


# ==============================================================================
# 4. 梯形压型波纹钢墙板 (corrugated_a / corrugated_n)
# ==============================================================================
ribs = 10.0
ru_c = np.mod(u * ribs, 1.0)
# 梯形波峰/波谷剖面：0..0.25 斜坡上, 0.25..0.55 波峰平顶, 0.55..0.80 斜坡下, 0.80..1.0 波谷
trap = ss(0.04, 0.26, ru_c) * (1.0 - ss(0.54, 0.76, ru_c))
c_dent = fnoise(H, W, 1.9, seed=401)
c_fine = fnoise(H, W, 1.1, seed=402, ax=0.6, ay=4.0)
c_rust_n = fnoise(H, W, 2.1, seed=403)
sheet_id = np.sin(np.floor(v * 2.0) * 19.7 + np.floor(u * 2.0) * 43.3) * 0.5 + 0.5

# 横向搭接板缝（2 道搭接 + 波峰自攻螺栓）
lap_v = np.mod(v * 2.0, 1.0)
lap_line = 1.0 - ss(0.008, 0.025, lap_v)
lap_shadow = ss(0.005, 0.02, lap_v) * (1.0 - ss(0.02, 0.09, lap_v))
bolt_dx = (ru_c - 0.40) * ribs * 0.55
bolt_dy = (lap_v - 0.965) * 2.0 * 8.0
bolt = np.clip(1.0 - (bolt_dx * bolt_dx + bolt_dy * bolt_dy) / 0.08, 0.0, 1.0)

# 波谷藏污与搭接处微锈
trough_ao = (1.0 - trap) * 0.20
lap_rust = (lap_shadow * 0.7 + (1.0 - ss(0.0, 0.14, 1.0 - lap_v)) * 0.4) * ss(0.45, 0.78, c_rust_n)

corr_val = (
    0.85
    + (trap - 0.5) * 0.18
    + (c_fine - 0.5) * 0.07
    + (c_dent - 0.5) * 0.08
    + (sheet_id - 0.5) * 0.06
    - trough_ao
    - lap_line * 0.30
    - lap_shadow * 0.18
    + bolt * 0.10
)
corr_rgb = np.dstack([corr_val, corr_val, corr_val * 1.01])
corr_rgb = lerp(corr_rgb, np.array([0.48, 0.31, 0.20]), np.clip(lap_rust, 0.0, 1.0) * 0.50)
corr_h = trap * 0.76 + (c_dent - 0.5) * 0.09 + c_fine * 0.05 - lap_line * 0.35 + bolt * 0.28 + ss(0.0, 0.02, 1.0 - lap_v) * 0.12
save_rgb("corrugated_a.png", corr_rgb)
save_rgb("corrugated_n.png", normal_from_height(corr_h, 4.8))


# ==============================================================================
# 5. 直立锁边 / 工业金属瓦屋面 (roof_seam_a / roof_seam_n)
# ==============================================================================
seams_n = 8.0
su = np.mod(u * seams_n, 1.0)
strip_id = np.sin(np.floor(u * seams_n) * 31.3 + np.floor(v * 3.0) * 17.9) * 0.5 + 0.5
# 窄高直立锁边肋 + 中间两道微加强浅筋
standing_rib = 1.0 - ss(0.03, 0.085, np.minimum(su, 1.0 - su))
stiffener = (1.0 - ss(0.015, 0.05, np.abs(su - 0.34))) + (1.0 - ss(0.015, 0.05, np.abs(su - 0.66)))
rf_v = np.mod(v * 3.0, 1.0)
rf_step = 1.0 - ss(0.008, 0.028, rf_v)
rf_wash = fnoise(H, W, 1.8, seed=501, ax=0.5, ay=3.8)
rf_lo = fnoise(H, W, 2.3, seed=502)

rf_val = (
    0.84
    + standing_rib * 0.14
    + stiffener * 0.05
    + (strip_id - 0.5) * 0.07
    + (rf_lo - 0.5) * 0.11
    - (rf_wash - 0.5) * 0.10
    - rf_step * 0.26
    - ss(0.01, 0.08, rf_v) * (1.0 - ss(0.08, 0.18, rf_v)) * 0.12
)
rf_rgb = np.dstack([rf_val, rf_val * 0.995, rf_val * 0.99])
rf_h = standing_rib * 0.72 + stiffener * 0.18 + rf_lo * 0.12 - rf_step * 0.38
save_rgb("roof_seam_a.png", rf_rgb)
save_rgb("roof_seam_n.png", normal_from_height(rf_h, 4.4))


# ==============================================================================
# 5b. 沥青油毡防水工业平屋面 (tar_roof_a / tar_roof_n)
# ==============================================================================
tr_lo = fnoise(H, W, 2.4, seed=551)
tr_mid = fnoise(H, W, 1.4, seed=552)
tr_agg = fnoise(H, W, 0.75, seed=553)
tr_rolls = 5.0
tr_u = np.mod(u * tr_rolls + (tr_lo - 0.5) * 0.02, 1.0)
tr_v = np.mod(v * 2.0, 1.0)
roll_id = np.sin(np.floor(u * tr_rolls) * 29.1 + np.floor(v * 2.0) * 13.7) * 0.5 + 0.5
felt_seam_u = 1.0 - ss(0.010, 0.036, np.minimum(tr_u, 1.0 - tr_u))
felt_seam_v = 1.0 - ss(0.008, 0.026, tr_v)
felt_seam = np.maximum(felt_seam_u, felt_seam_v * 0.75)
tar_patch = ss(0.68, 0.88, tr_lo * 0.65 + tr_mid * 0.35)
grit_sprinkle = ss(0.72, 0.92, tr_agg)

tr_val = (
    0.78
    + (tr_lo - 0.5) * 0.13
    + (tr_mid - 0.5) * 0.09
    + (roll_id - 0.5) * 0.06
    + grit_sprinkle * 0.09
    - tar_patch * 0.14
    - felt_seam * 0.22
)
tr_rgb = np.dstack([tr_val * 1.00, tr_val * 0.995, tr_val * 0.985])
tr_rgb = lerp(tr_rgb, np.array([0.48, 0.46, 0.43]), grit_sprinkle * 0.22)
tr_h = tr_lo * 0.24 + tr_mid * 0.18 + grit_sprinkle * 0.24 + tr_agg * 0.18 - felt_seam * 0.32
save_rgb("tar_roof_a.png", tr_rgb)
save_rgb("tar_roof_n.png", normal_from_height(tr_h, 3.6))


# ==============================================================================
# 6. 粗骨料工业沥青路面 (asphalt_a / asphalt_n)
# ==============================================================================
a_lo = fnoise(H, W, 2.4, seed=601)
a_agg1 = fnoise(H, W, 0.65, seed=602)
a_agg2 = fnoise(H, W, 0.95, seed=603)
a_patch = fnoise(H, W, 2.1, seed=605)
oil_stain = ss(0.66, 0.88, a_patch * 0.65 + a_lo * 0.35)
repair_patch = ss(0.72, 0.84, blur(a_patch, 2.0)) * (1.0 - ss(0.84, 0.94, blur(a_patch, 2.0)))
pebble_dots = ss(0.66, 0.88, a_agg1) * 0.55 + ss(0.72, 0.92, a_agg2) * 0.45

asph_val = (
    0.81
    + (a_lo - 0.5) * 0.14
    + (pebble_dots - 0.25) * 0.24
    - oil_stain * 0.14
    - repair_patch * 0.09
)
asph_rgb = np.dstack([asph_val * 0.99, asph_val * 0.995, asph_val * 1.015])
asph_h = a_agg1 * 0.40 + a_agg2 * 0.30 + a_lo * 0.20 - repair_patch * 0.10
save_rgb("asphalt_a.png", asph_rgb)
save_rgb("asphalt_n.png", normal_from_height(asph_h, 3.8))


# ==============================================================================
# 7. 层理节理山岩 (rock_strata_a / rock_strata_n)
# ==============================================================================
rk_lo = fnoise(H, W, 2.5, seed=701)
rk_mid = fnoise(H, W, 1.6, seed=702)
rk_hi = fnoise(H, W, 0.85, seed=703)
rk_chip = fnoise(H, W, 1.3, seed=706, ax=2.2, ay=0.6)
# 倾斜弯曲沉积岩层理 + 连续岩石节理微沟槽（无网状 Voronoi 铁丝网）
strata_coord = v * 7.5 + u * 0.85 + (rk_lo - 0.5) * 2.4 + (rk_mid - 0.5) * 0.70
strata_step = np.mod(strata_coord, 1.0)
strata_ledge = 1.0 - ss(0.03, 0.16, strata_step)
strata_band = np.sin(np.floor(strata_coord) * 19.3) * 0.5 + 0.5

fissure_field = fnoise(H, W, 1.9, seed=707, ax=0.75, ay=2.2)
fissure = (1.0 - ss(0.01, 0.08, np.abs(fissure_field - 0.5 + (rk_hi - 0.5) * 0.10))) * ss(0.35, 0.80, rk_lo)
vein = (1.0 - ss(0.01, 0.045, np.abs(fissure_field - 0.28 + (rk_mid - 0.5) * 0.08))) * ss(0.55, 0.85, rk_lo)

rk_val = (
    0.83
    + (strata_band - 0.5) * 0.16
    + (rk_lo - 0.5) * 0.16
    + (rk_mid - 0.5) * 0.11
    + (rk_hi - 0.5) * 0.10
    + (rk_chip - 0.5) * 0.08
    - strata_ledge * 0.22
    - fissure * 0.18
    + vein * 0.14
)
rk_rgb = np.dstack([rk_val * 1.01, rk_val * 0.995, rk_val * 0.97])
rk_h = (
    (1.0 - strata_step) * 0.36
    + rk_lo * 0.34
    + rk_mid * 0.24
    + rk_hi * 0.14
    + rk_chip * 0.12
    - fissure * 0.26
    - strata_ledge * 0.30
)
save_rgb("rock_strata_a.png", rk_rgb)
save_rgb("rock_strata_n.png", normal_from_height(rk_h, 4.8))


# ==============================================================================
# 8. 自然废土泥壤与压实粉土颗粒地面 (ground_soil_a / ground_soil_n)
# ==============================================================================
s_lo = fnoise(H, W, 2.5, seed=801)
s_mid = fnoise(H, W, 1.6, seed=802)
s_hi = fnoise(H, W, 0.95, seed=803)
s_wind = fnoise(H, W, 1.8, seed=804, ax=2.6, ay=0.75)
d_grit, e_grit, id_grit = voronoi_periodic(H, W, 64, 64, jitter=0.92, seed=805)

# 柔和有机土块起伏 + 嵌入泥土的细碎矿物砂砾（零刺眼白斑与白线）
grit_body = ss(0.015, 0.085, e_grit + (s_hi - 0.5) * 0.03)
grit_crevice = 1.0 - grit_body
grit_shade = (id_grit - 0.5) * 0.10 * grit_body - grit_crevice * 0.045
clod_bump = (s_mid - 0.5) * 0.12 + (blur(s_hi, 1.1) - 0.5) * 0.07 + (s_wind - 0.5) * 0.06

soil_val = (
    0.82
    + (s_lo - 0.5) * 0.13
    + clod_bump
    + (s_hi - 0.5) * 0.045
    + grit_shade * 0.72
)
soil_val = np.clip(soil_val, 0.72, 0.90)
soil_rgb = np.dstack([
    soil_val * (1.015 + (s_lo - 0.5) * 0.025),
    soil_val * 0.995,
    soil_val * (0.955 - (s_lo - 0.5) * 0.02),
])
soil_h = blur(
    s_lo * 0.34 + s_mid * 0.28 + s_wind * 0.14 + s_hi * 0.10 + grit_body * (0.10 + id_grit * 0.08),
    0.55,
)
save_rgb("ground_soil_a.png", soil_rgb)
save_rgb("ground_soil_n.png", normal_from_height(soil_h, 3.0))


# ==============================================================================
# 9. 压实工业道砟与细碎矿渣地坪 (ground_gravel_a / ground_gravel_n)
# ==============================================================================
g_lo = fnoise(H, W, 2.3, seed=901)
g_mid = fnoise(H, W, 1.5, seed=905)
g_hi = fnoise(H, W, 0.95, seed=902)
_, e_g1, id_g1 = voronoi_periodic(H, W, 76, 76, jitter=0.92, seed=903)
_, e_g2, id_g2 = voronoi_periodic(H, W, 118, 118, jitter=0.92, seed=904)

# 高频细骨料嵌入 55% 压实砂土基质，保留粗砺质感但彻底消除彩色玻璃式大 Voronoi 网格
stone1 = ss(0.015, 0.11, e_g1 + (g_hi - 0.5) * 0.04)
stone2 = ss(0.015, 0.12, e_g2 + (g_hi - 0.5) * 0.03)
agg_mix = (id_g1 - 0.5) * 0.14 * stone1 * 0.65 + (id_g2 - 0.5) * 0.12 * stone2 * 0.45
agg_crevice = (1.0 - stone1) * 0.055 + (1.0 - stone2) * 0.035
fines_val = (g_lo - 0.5) * 0.12 + (g_mid - 0.5) * 0.09 + (g_hi - 0.5) * 0.05
grav_val = np.clip(
    0.82
    + fines_val * 0.62
    + agg_mix * 0.45
    - agg_crevice * 0.45,
    0.70,
    0.92,
)
grav_rgb = np.dstack([
    grav_val * (1.005 + (id_g1 - 0.5) * 0.025),
    grav_val * 0.996,
    grav_val * (0.982 - (id_g1 - 0.5) * 0.025),
])
grav_h = blur(
    g_lo * 0.24 + g_mid * 0.20 + fines_val * 0.10
    + 0.45 * (stone1 * (0.24 + id_g1 * 0.12) + stone2 * (0.16 + id_g2 * 0.08)),
    0.55,
)
save_rgb("ground_gravel_a.png", grav_rgb)
save_rgb("ground_gravel_n.png", normal_from_height(grav_h, 3.4))



# ==============================================================================
# 13. 废土野草与芦苇丛裁切贴图 (grass_tuft_a 256x256 RGBA)
# 底部 v=1.0 生根，向上弯曲散开草叶与草穗
# ==============================================================================
GH, GW = 256, 256
gyy, gxx = np.mgrid[0:GH, 0:GW].astype(np.float32)
gu = gxx / (GW - 1.0)
gv = 1.0 - gyy / (GH - 1.0)  # gv=0 底边根部, gv=1 顶部草尖

gr_alpha = np.zeros((GH, GW), dtype=np.float32)
gr_rgb = np.zeros((GH, GW, 3), dtype=np.float32)
rng_g = np.random.default_rng(1301)

for i in range(34):
    root_x = 0.50 + rng_g.uniform(-0.28, 0.28)
    lean = (root_x - 0.50) * 1.15 + rng_g.uniform(-0.26, 0.26)
    bh = rng_g.uniform(0.48, 0.94)
    bw = rng_g.uniform(0.014, 0.026)
    has_plume = (i % 6 == 0) and (bh > 0.72)

    t_y = np.clip(gv / bh, 0.0, 1.1)
    cx = root_x + lean * (t_y ** 1.65)
    # 草叶向上渐细收尖
    half_bw = bw * (1.0 - 0.82 * np.clip(t_y, 0.0, 1.0) ** 1.2) * (gv <= bh)
    if has_plume:
        plume = ss(0.72, 0.82, t_y) * (1.0 - ss(0.96, 1.04, t_y))
        half_bw = np.maximum(half_bw, bw * 2.1 * plume * (0.65 + 0.35 * np.sin(gv * 95.0)))

    dx_g = np.abs(gu - cx)
    b_mask = (1.0 - ss(half_bw * 0.55, half_bw * 1.15 + 1e-4, dx_g)) * (gv <= bh * 1.03) * ss(0.0, 0.03, gv)

    tone_g = rng_g.uniform(0.0, 1.0)
    c_root = np.array([0.16, 0.16, 0.09], dtype=np.float32)
    c_mid_g = lerp(np.array([0.27, 0.32, 0.16]), np.array([0.38, 0.36, 0.20]), tone_g)
    c_tip_g = np.array([0.52, 0.46, 0.27], dtype=np.float32)

    ty_c = np.clip(t_y, 0.0, 1.0)[..., None]
    b_col = c_root * (1.0 - ss(0.0, 0.35, ty_c)) + c_mid_g * ss(0.0, 0.35, ty_c)
    b_col = lerp(b_col, c_tip_g, ss(0.62, 0.98, ty_c) * (0.85 if has_plume else 0.55))

    vis_g = b_mask > gr_alpha * 0.75
    gr_rgb = np.where(vis_g[..., None], gr_rgb * (1.0 - b_mask[..., None]) + b_col * b_mask[..., None], gr_rgb)
    gr_alpha = np.maximum(gr_alpha, b_mask)

save_rgba("grass_tuft_a.png", gr_rgb, gr_alpha)


# ==============================================================================
# 14. 全景写实工业阴天/碎积云天空层贴图 (sky_clouds.png, 1024x512 RGBA)
# ==============================================================================
SH, SW = 512, 1024
sy = np.linspace(0.0, 1.0, SH, endpoint=False)[:, None] * np.ones((1, SW))
cl_lo = fnoise(SH, SW, 2.5, seed=1401, ax=1.8, ay=1.0)
cl_mid = fnoise(SH, SW, 1.6, seed=1402, ax=2.2, ay=1.0)
cl_hi = fnoise(SH, SW, 1.0, seed=1403, ax=2.6, ay=1.2)
cl_wisp = fnoise(SH, SW, 1.3, seed=1404, ax=4.0, ay=0.8)

# 仅保留上半球 (sy < 0.5) 碎积云与层云带，地平线 (0.48) 与天顶 (0.04) 平滑渐隐
hemisphere = (1.0 - ss(0.36, 0.49, sy)) * ss(0.03, 0.16, sy)
cl_raw = cl_lo * 0.52 + cl_mid * 0.30 + cl_hi * 0.12 + cl_wisp * 0.06
cl_alpha = ss(0.42, 0.78, cl_raw) * hemisphere

# 云顶向阳暖灰白 + 云底厚重冷青灰体积感
lit_top = ss(0.35, 0.75, cl_mid * 0.6 + (1.0 - sy * 1.6) * 0.4)
cl_v = 0.58 + lit_top * 0.38 - ss(0.58, 0.88, cl_lo) * 0.14
cl_rgb = np.dstack([
    cl_v * (1.01 + lit_top * 0.03),
    cl_v * 1.00,
    cl_v * (0.99 - lit_top * 0.02 + (1.0 - lit_top) * 0.04),
])
save_rgba("sky_clouds.png", cl_rgb, np.clip(cl_alpha, 0.0, 1.0))


# ==============================================================================
# 15. 360度球面无缝等距柱状全景天空盒贴图 (skybox_clouds_pano.png / skybox_horizon_pano.png, 2048x1024 RGB)
# 在三维单位球面上采样周期性 3D FFT 分形场，严格消除经度接缝与天顶/天底极点缩聚畸变
# ==============================================================================
def fnoise3(n=144, beta=2.4, lo=0.0, seed=1, ax=1.0, ay=1.0, az=1.0):
    """三维周期性 1/f^(beta/2) 分形噪声体，返回 (n, n, n) 范围 0..1。"""
    rng3 = np.random.default_rng(seed)
    wn = rng3.standard_normal((n, n, n)).astype(np.float32)
    fz = np.fft.fftfreq(n)[:, None, None] / az
    fy = np.fft.fftfreq(n)[None, :, None] / ay
    fx = np.fft.fftfreq(n)[None, None, :] / ax
    f = np.sqrt(fx * fx + fy * fy + fz * fz)
    f[0, 0, 0] = 1.0
    amp = 1.0 / np.power(f, beta / 2.0)
    if lo > 0.0:
        amp *= 1.0 - np.exp(-((f / lo) ** 2))
    amp[0, 0, 0] = 0.0
    vol = np.real(np.fft.ifftn(np.fft.fftn(wn) * amp)).astype(np.float32)
    vol -= vol.min()
    mx = vol.max()
    return vol / mx if mx > 1e-8 else np.zeros((n, n, n), dtype=np.float32)


def sample_vol3(vol, px, py, pz):
    """三维周期三线性插值采样，坐标单位为体素索引。"""
    n = vol.shape[0]
    x = np.mod(px, n)
    y = np.mod(py, n)
    z = np.mod(pz, n)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    z0 = np.floor(z).astype(np.int32)
    x1 = (x0 + 1) % n
    y1 = (y0 + 1) % n
    z1 = (z0 + 1) % n
    tx = (x - x0).astype(np.float32)
    ty = (y - y0).astype(np.float32)
    tz = (z - z0).astype(np.float32)
    c000 = vol[z0, y0, x0]
    c100 = vol[z0, y0, x1]
    c010 = vol[z0, y1, x0]
    c110 = vol[z0, y1, x1]
    c001 = vol[z1, y0, x0]
    c101 = vol[z1, y0, x1]
    c011 = vol[z1, y1, x0]
    c111 = vol[z1, y1, x1]
    c00 = c000 * (1.0 - tx) + c100 * tx
    c10 = c010 * (1.0 - tx) + c110 * tx
    c01 = c001 * (1.0 - tx) + c101 * tx
    c11 = c011 * (1.0 - tx) + c111 * tx
    c0 = c00 * (1.0 - ty) + c10 * ty
    c1 = c01 * (1.0 - ty) + c11 * ty
    return c0 * (1.0 - tz) + c1 * tz


PH, PW = 1024, 2048
pv = (np.arange(PH, dtype=np.float32) + 0.5) / PH
pu = (np.arange(PW, dtype=np.float32) + 0.5) / PW
theta = pv[:, None] * np.pi          # 0 (天顶 +Y) .. pi (天底 -Y)
phi = (pu[None, :] - 0.5) * 2.0 * np.pi  # -pi .. +pi，与 atan(d.x, d.z) 严格对齐
sin_t = np.sin(theta)
dx = sin_t * np.cos(phi)
dy = np.broadcast_to(np.cos(theta), (PH, PW)).copy()
dz = sin_t * np.sin(phi)

# 15a. skybox_clouds_pano.png: R=主积云/层积云密度, G=高空卷云/次层流云密度, B=云体垂直受光梯度与厚度
N3 = 144
v_warp_x = fnoise3(N3, beta=3.0, seed=1501)
v_warp_z = fnoise3(N3, beta=3.0, seed=1502)
v_cum_lo = fnoise3(N3, beta=2.8, seed=1503, ax=1.35, ay=0.72, az=1.35)
v_cum_hi = fnoise3(N3, beta=1.75, seed=1504, ax=1.15, ay=0.85, az=1.15)
v_cirrus = fnoise3(N3, beta=2.1, seed=1505, ax=2.4, ay=0.55, az=1.6)

# 球面展平投影半径随仰角温和拉伸，地平线云带层次绵密且天顶连续无极点畸变
proj_scale = 34.0 / (0.38 + 0.62 * np.abs(dy))
sx = dx * proj_scale + 72.0
sy3 = dy * 28.0 + 72.0
sz = dz * proj_scale + 72.0

wx = (sample_vol3(v_warp_x, sx * 0.45, sy3 * 0.45, sz * 0.45) - 0.5) * 9.5
wz = (sample_vol3(v_warp_z, sx * 0.45 + 31.0, sy3 * 0.45 + 17.0, sz * 0.45 + 53.0) - 0.5) * 9.5

c_lo = sample_vol3(v_cum_lo, sx + wx, sy3, sz + wz)
c_hi = sample_vol3(v_cum_hi, sx * 2.15 + wx * 0.6, sy3 * 2.15, sz * 2.15 + wz * 0.6)
c_lo_up = sample_vol3(v_cum_lo, sx + wx, sy3 + 2.4, sz + wz)

# 主云团密度 (R)：地平线略上方积云最厚，向天顶自然疏朗过渡，下半球平滑衰减
upper_mask = ss(-0.04, 0.09, dy) * (1.0 - 0.22 * ss(0.55, 0.98, dy))
cum_raw = c_lo * 0.66 + c_hi * 0.34
ch_r = np.clip(ss(0.34, 0.80, cum_raw) * upper_mask, 0.0, 1.0)

# 次层流云与高空纤缕卷云 (G)
sx2 = dx * (42.0 / (0.45 + 0.55 * np.abs(dy))) + 37.0
sz2 = dz * (42.0 / (0.45 + 0.55 * np.abs(dy))) + 89.0
cir_a = sample_vol3(v_cirrus, sx2 + wx * 0.4, sy3 * 0.8 + 19.0, sz2 - wz * 0.4)
cir_b = sample_vol3(v_cum_hi, sx2 * 1.7, sy3 * 1.4 + 41.0, sz2 * 1.7)
cir_mask = ss(-0.02, 0.14, dy)
ch_g = np.clip(ss(0.38, 0.82, cir_a * 0.70 + cir_b * 0.30) * cir_mask, 0.0, 1.0)

# 云顶垂直受光浮雕梯度 (B)：上采样差值编码云朵顶部亮面与底部暗部体积厚度
vert_grad = np.clip(0.52 + (c_lo - c_lo_up) * 3.2 + (c_hi - 0.5) * 0.35, 0.0, 1.0)
ch_b = np.clip(vert_grad * 0.78 + (1.0 - ss(0.45, 0.86, c_lo)) * 0.22, 0.0, 1.0)

save_rgb("skybox_clouds_pano.png", np.dstack([ch_r, ch_g, ch_b]))

# 15b. skybox_horizon_pano.png: R=360度远山/台地轮廓与岩面浮雕, G=远景废土工业天际线剪影, B=深渊地下岩穹与发光菌脉
az_mtn1 = fnoise(1, PW, beta=2.4, seed=1510)[0][None, :]
az_mtn2 = fnoise(1, PW, beta=1.6, seed=1511)[0][None, :]
az_mesa = fnoise(1, PW, beta=2.1, seed=1512)[0][None, :]
# 远山高度轮廓（仰角 dy 约 -0.04 .. +0.14）
ridge_far_h = 0.012 + np.power(az_mtn1, 1.45) * 0.105 + (az_mtn2 - 0.5) * 0.028
ridge_mesa_h = 0.005 + ss(0.32, 0.68, az_mesa) * 0.068 + (az_mtn2 - 0.5) * 0.012
ridge_h = np.maximum(ridge_far_h, ridge_mesa_h * 0.92)
rock_tex = sample_vol3(v_cum_hi, dx * 55.0 + 14.0, dy * 65.0 + 30.0, dz * 55.0 + 22.0)
ridge_mask = ss(ridge_h + 0.008, ridge_h - 0.006, dy) * ss(-0.18, -0.03, dy)
ridge_relief = np.clip(0.35 + (ridge_h - dy) * 4.2 + (rock_tex - 0.5) * 0.42, 0.0, 1.0)
hz_r = np.clip(ridge_mask * (0.45 + 0.55 * ridge_relief), 0.0, 1.0)

# 远景工业废墟/断桥/高塔天际线剪影 (G)：按方位角成簇分布，避免单调一字排开
ind_cluster = ss(0.46, 0.72, fnoise(1, PW, beta=2.6, seed=1515)[0])[None, :]
# 离散高低错落的工业塔架与残垣宽度分箱
cols_coarse = np.floor(pu * 180.0).astype(np.int32)
cols_fine = np.floor(pu * 520.0).astype(np.int32)
rng_ind = np.random.default_rng(1516)
h_table_c = rng_ind.random(180).astype(np.float32)
h_table_f = rng_ind.random(520).astype(np.float32)
block_h = (np.power(h_table_c[cols_coarse], 2.2) * 0.065 + np.power(h_table_f[cols_fine], 5.5) * 0.085)[None, :]
ind_h = block_h * ind_cluster + 0.004 * az_mtn2
ind_mask = ss(ind_h + 0.003, ind_h - 0.003, dy) * ss(-0.14, -0.02, dy)
hz_g = np.clip(ind_mask * (0.55 + 0.45 * (rock_tex * 0.6 + 0.4)), 0.0, 1.0)

# 地下深渊岩穹与生物发光裂隙 (B)：球面钟乳岩层肌理 + 锐利分形裂隙网
v_cav_a = fnoise3(N3, beta=2.5, seed=1520, ax=1.2, ay=1.5, az=1.2)
v_cav_b = fnoise3(N3, beta=1.8, seed=1521, ax=1.6, ay=1.2, az=1.6)
cav_s1 = sample_vol3(v_cav_a, dx * 38.0 + wx * 0.5 + 40.0, dy * 34.0 + 40.0, dz * 38.0 + wz * 0.5 + 40.0)
cav_s2 = sample_vol3(v_cav_b, dx * 76.0 + 18.0, dy * 64.0 + 18.0, dz * 76.0 + 18.0)
# 裂隙发光脉络：取 |cav_s1 - 0.5| 极小值带形成蜿蜒生物菌脉，打包在高亮区 (>0.75)
vein = ss(0.032, 0.003, np.abs(cav_s1 - 0.50)) * ss(0.42, 0.72, cav_s2) * ss(-0.05, 0.20, dy)
strata = np.clip(cav_s1 * 0.55 + cav_s2 * 0.45, 0.0, 1.0) * 0.70
hz_b = np.clip(strata + vein * 0.55, 0.0, 1.0)

save_rgb("skybox_horizon_pano.png", np.dstack([hz_r, hz_g, hz_b]))

print("Generated world & foliage textures in:", os.path.abspath(OUT))
for fn in sorted(os.listdir(OUT)):
    if fn.endswith(".png"):
        print(" -", fn)

