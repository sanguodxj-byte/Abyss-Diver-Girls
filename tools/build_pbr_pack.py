#!/usr/bin/env python3
"""
下载精选 Poly Haven CC0 1K PBR 实拍贴图 + 合成军工机甲/重工业专用 1K 无缝 PBR 贴图。
所有反照率贴图均按 mech_paint.gdshader 的 `at * 1.48` 约定校准中性均值（~0.68），
确保任意 base_color 染色后明度准确、无白斑克隆印章；法线严格采用 OpenGL (+Y 朝上)。
"""
import io
import os
import sys
import time
import requests
import numpy as np
from PIL import Image

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "world"))
os.makedirs(OUT, exist_ok=True)
SIZE = 1024


def fnoise(h, w, beta=2.0, lo=0.0, seed=1, ax=1.0, ay=1.0):
    r = np.random.default_rng(seed)
    wn = r.standard_normal((h, w)).astype(np.float32)
    fy = np.fft.fftfreq(h)[:, None] / ay
    fx = (np.fft.fftfreq(w)[None, :] * (w / h)) / ax
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(f, beta / 2.0)
    if lo > 0:
        amp *= 1.0 - np.exp(-(f / lo) ** 2)
    amp[0, 0] = 0.0
    n = np.real(np.fft.ifft2(np.fft.fft2(wn) * amp)).astype(np.float32)
    mn, mx = float(n.min()), float(n.max())
    return (n - mn) / (mx - mn) if mx - mn > 1e-8 else np.zeros((h, w), dtype=np.float32)


def blur_periodic(a, sigma):
    h, w = a.shape[:2]
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    if a.ndim == 3:
        out = np.empty_like(a)
        for c in range(a.shape[2]):
            out[..., c] = np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * g))
        return out
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g)).astype(np.float32)


def normal_from_height(hgt, strength):
    # OpenGL normal (+X right, +Y up -> -dy in image space)
    gx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * strength
    gy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(hgt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True) + 1e-8
    return np.clip(n * 0.5 + 0.5, 0.0, 1.0)


def _atomic_save(im, name):
    dst = os.path.join(OUT, name)
    tmp = dst + ".tmp.png"
    im.save(tmp, format="PNG")
    os.replace(tmp, dst)


def save_rgb(name, arr):
    _atomic_save(Image.fromarray((np.clip(arr, 0.0, 1.0) * 255.0).astype(np.uint8), "RGB"), name)


def save_rgba(name, rgb, alpha):
    rgba = np.dstack([np.clip(rgb, 0.0, 1.0), np.clip(alpha, 0.0, 1.0)])
    _atomic_save(Image.fromarray((rgba * 255.0).astype(np.uint8), "RGBA"), name)


def save_gray(name, arr):
    _atomic_save(Image.fromarray((np.clip(arr, 0.0, 1.0) * 255.0).astype(np.uint8), "L"), name)


def normalize_albedo(arr, target_mean=0.68, contrast=1.0, desat=0.0, clip_lo=0.22, clip_hi=0.96):
    """将实拍反照率归一化到指定中性亮度均值，抑制极端白斑并保留细腻层次。"""
    lum = arr[..., 0] * 0.299 + arr[..., 1] * 0.587 + arr[..., 2] * 0.114
    if desat > 0.0:
        arr = arr * (1.0 - desat) + lum[..., None] * desat
    cur_mean = float(np.mean(lum))
    if cur_mean > 1e-4:
        arr = arr * (target_mean / cur_mean)
    if contrast != 1.0:
        arr = target_mean + (arr - target_mean) * contrast
    return np.clip(arr, clip_lo, clip_hi)


def download_polyhaven(sess, asset_id, out_prefix, target_mean=0.68, contrast=1.05, desat=0.25, normal_boost=1.0, rough_range=None, pack_height=False):
    print(f"[PH] Fetching {asset_id} -> {out_prefix}_{{a,n,r}}.png (height={pack_height}) ...")
    info = None
    for attempt in range(4):
        try:
            r = sess.get(f"https://api.polyhaven.com/files/{asset_id}", timeout=15)
            r.raise_for_status()
            info = r.json()
            break
        except Exception as e:
            print(f"  retry meta {attempt}: {e}")
            time.sleep(1.0)
    if info is None:
        raise RuntimeError(f"Failed to fetch Poly Haven metadata for {asset_id}")

    def fetch_chan(ch_key):
        ch = info[ch_key]["1k"]
        fmt = "png" if "png" in ch else "jpg"
        url = ch[fmt]["url"]
        for attempt in range(4):
            try:
                resp = sess.get(url, timeout=30)
                resp.raise_for_status()
                im = Image.open(io.BytesIO(resp.content))
                if im.size != (SIZE, SIZE):
                    im = im.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
                return im
            except Exception as e:
                print(f"  retry dl {ch_key} {attempt}: {e}")
                time.sleep(1.0)
        raise RuntimeError(f"Failed download {url}")

    # 1. Albedo (+ optional Displacement packed into Alpha for zero-cost Height-Blend)
    im_a = fetch_chan("Diffuse").convert("RGB")
    arr_a = np.asarray(im_a, dtype=np.float32) / 255.0
    arr_a = normalize_albedo(arr_a, target_mean=target_mean, contrast=contrast, desat=desat)
    if pack_height:
        if "Displacement" in info:
            im_h = fetch_chan("Displacement")
            raw_h = np.asarray(im_h, dtype=np.float32)
            if raw_h.ndim == 3:
                raw_h = raw_h[..., 0]
            arr_h = raw_h / 65535.0 if raw_h.max() > 255.5 else raw_h / 255.0
        else:
            arr_h = arr_a[..., 0] * 0.299 + arr_a[..., 1] * 0.587 + arr_a[..., 2] * 0.114
        lo_h, hi_h = np.percentile(arr_h, [2, 98])
        if hi_h - lo_h > 1e-3:
            arr_h = np.clip((arr_h - lo_h) / (hi_h - lo_h), 0.0, 1.0)
        # 保留 >= 0.20 下限，彻底防止 Godot 导入器 fix_alpha_border 改写 RGB 像素
        arr_h = 0.20 + arr_h * 0.80
        save_rgba(f"{out_prefix}_a.png", arr_a, arr_h)
    else:
        save_rgb(f"{out_prefix}_a.png", arr_a)

    # 2. Normal (OpenGL nor_gl)
    im_n = fetch_chan("nor_gl").convert("RGB")
    arr_n = np.asarray(im_n, dtype=np.float32) / 255.0
    if normal_boost != 1.0:
        nxy = (arr_n[..., :2] * 2.0 - 1.0) * normal_boost
        nz = np.maximum(arr_n[..., 2:3] * 2.0 - 1.0, 0.15)
        nv = np.concatenate([nxy, nz], axis=2)
        nv /= np.linalg.norm(nv, axis=2, keepdims=True) + 1e-8
        arr_n = nv * 0.5 + 0.5
    save_rgb(f"{out_prefix}_n.png", arr_n)

    # 3. Roughness（Poly Haven 的 1K PNG 可能是 16-bit 灰度 I;16，不能直接 .convert("L")！）
    im_r = fetch_chan("Rough")
    raw_r = np.asarray(im_r, dtype=np.float32)
    if raw_r.ndim == 3:
        raw_r = raw_r[..., 0]
    arr_r = raw_r / 65535.0 if raw_r.max() > 255.5 else raw_r / 255.0
    if rough_range is not None:
        lo_p, hi_p = np.percentile(arr_r, [3, 97])
        if hi_p - lo_p > 1e-3:
            t = np.clip((arr_r - lo_p) / (hi_p - lo_p), 0.0, 1.0)
            arr_r = rough_range[0] + t * (rough_range[1] - rough_range[0])
    save_gray(f"{out_prefix}_r.png", arr_r)
    print(f"  OK {out_prefix}: albedo_mean={arr_a.mean():.2f}, rough=[{arr_r.min():.2f}..{arr_r.max():.2f}] (mean={arr_r.mean():.2f})")


def build_armor_rha():
    """1K 军工轧制均质装甲板 (CARC 哑光军漆橘皮细粒 + 热轧钢微起伏 + 细微服役擦痕，零大白斑)"""
    print("[GEN] armor_rha_{a,n,r}.png ...")
    n_macro = fnoise(SIZE, SIZE, 2.5, seed=201)
    n_roll = fnoise(SIZE, SIZE, 1.7, seed=202, ax=3.8, ay=0.85)
    n_peel = fnoise(SIZE, SIZE, 0.95, lo=0.04, seed=203)  # CARC 军用喷涂细腻橘皮
    n_micro = fnoise(SIZE, SIZE, 0.65, lo=0.10, seed=204)
    n_pit = np.clip((fnoise(SIZE, SIZE, 1.15, lo=0.05, seed=205) - 0.72) / 0.28, 0.0, 1.0)
    sc1 = np.clip((fnoise(SIZE, SIZE, 1.05, lo=0.04, seed=206, ax=7.5, ay=0.45) - 0.80) / 0.20, 0.0, 1.0)
    sc2 = np.clip((fnoise(SIZE, SIZE, 1.05, lo=0.04, seed=207, ax=0.55, ay=6.5) - 0.82) / 0.18, 0.0, 1.0)
    scuff = np.maximum(sc1, sc2) * (0.45 + 0.55 * n_macro)

    # 高度场：轧制波纹 + 橘皮细粒 - 微蚀坑 - 细划痕
    hgt = (
        (n_macro - 0.5) * 0.22
        + (n_roll - 0.5) * 0.16
        + (n_peel - 0.5) * 0.26
        + (n_micro - 0.5) * 0.14
        - n_pit * 0.28
        - scuff * 0.18
    )
    nrm = normal_from_height(hgt, 3.6)

    # 中性均值 ~0.68，让军用涂装色准确呈色同时保留高级实拍质感
    val = (
        0.68
        + (n_macro - 0.5) * 0.085
        + (n_roll - 0.5) * 0.055
        + (n_peel - 0.5) * 0.042
        - n_pit * 0.095
        + scuff * 0.095
    )
    # 极微冷暖工业色温变化
    rgb = np.dstack([
        val * (1.00 + (n_macro - 0.5) * 0.025),
        val * 1.00,
        val * (1.00 - (n_macro - 0.5) * 0.020),
    ])
    rgb = np.clip(rgb, 0.42, 0.90)

    # 粗糙度：漆面 0.50..0.68，微擦痕更光滑 0.28，微蚀坑更哑 0.80
    rough = np.clip(
        0.56
        + (n_macro - 0.5) * 0.14
        + (n_peel - 0.5) * 0.10
        + n_pit * 0.24
        - scuff * 0.26,
        0.24,
        0.86,
    )
    save_rgb("armor_rha_a.png", rgb)
    save_rgb("armor_rha_n.png", nrm)
    save_gray("armor_rha_r.png", rough)


def build_gunmetal():
    """1K 机加工拉丝烤蓝枪钢 (CNC 方向性拉丝刀纹 + 交叉细划痕 + 油膜高光/亚光强对比)"""
    print("[GEN] gunmetal_{a,n,r}.png ...")
    n_lo = fnoise(SIZE, SIZE, 2.3, seed=301)
    n_brush1 = fnoise(SIZE, SIZE, 1.05, lo=0.02, seed=302, ax=16.0, ay=0.30)
    n_brush2 = fnoise(SIZE, SIZE, 0.85, lo=0.05, seed=303, ax=24.0, ay=0.22)
    n_oil = blur_periodic(fnoise(SIZE, SIZE, 2.0, seed=304), 2.5)
    n_grain = fnoise(SIZE, SIZE, 0.70, lo=0.08, seed=305)
    sc = np.clip((fnoise(SIZE, SIZE, 0.95, lo=0.04, seed=306, ax=9.0, ay=0.65) - 0.80) / 0.20, 0.0, 1.0)
    wear_band = np.clip((n_lo - 0.52) / 0.48, 0.0, 1.0)

    hgt = (
        (n_brush1 - 0.5) * 0.34
        + (n_brush2 - 0.5) * 0.24
        + (n_grain - 0.5) * 0.14
        - sc * 0.22
    )
    nrm = normal_from_height(hgt, 4.2)

    val = (
        0.68
        + (n_lo - 0.5) * 0.12
        + (n_brush1 - 0.5) * 0.11
        + (n_brush2 - 0.5) * 0.06
        - (n_oil - 0.5) * 0.08
        + sc * 0.14
        + wear_band * 0.05
    )
    rgb = np.dstack([val * 0.985, val * 1.00, val * 1.025])
    rgb = np.clip(rgb, 0.36, 0.94)

    # 强粗糙度层次：抛光拉丝处 0.22，油污/氧化处 0.64
    rough = np.clip(
        0.42
        + (n_oil - 0.5) * 0.28
        - (n_brush1 - 0.5) * 0.14
        - sc * 0.22
        - wear_band * 0.10,
        0.18,
        0.74,
    )
    save_rgb("gunmetal_a.png", rgb)
    save_rgb("gunmetal_n.png", nrm)
    save_gray("gunmetal_r.png", rough)


def build_treadplate():
    """1K 重工业防滑花纹钢板 (正交交替菱形凸筋 + 磨亮筋顶 + 油污哑光凹谷)"""
    print("[GEN] treadplate_{a,n,r}.png ...")
    cells = 8
    y = np.linspace(0.0, cells, SIZE, endpoint=False)[:, None]
    x = np.linspace(0.0, cells, SIZE, endpoint=False)[None, :]
    iy = np.floor(y).astype(np.int32)
    ix = np.floor(x).astype(np.int32)
    fy = y - iy - 0.5
    fx = x - ix - 0.5

    # 交替 90° 旋转菱形凸条（经典 1-bar / 2-bar 重工防滑甲板）
    rot = ((ix + iy) & 1) == 1
    u = np.where(rot, fy, fx)
    v = np.where(rot, fx, fy)

    # 细长圆头梭形凸筋（长 0.34, 宽 0.095），中间留出凹槽呼吸感
    d = np.sqrt((u / 0.34) ** 2 + (v / 0.105) ** 2)
    # 光滑斜坡凸筋剖面
    lug = np.clip((1.0 - d) / 0.38, 0.0, 1.0)
    lug = lug * lug * (3.0 - 2.0 * lug)
    lug = blur_periodic(lug, 0.9)

    n_lo = fnoise(SIZE, SIZE, 2.2, seed=401)
    n_brush = fnoise(SIZE, SIZE, 1.1, lo=0.03, seed=402, ax=5.0, ay=0.8)
    n_grime = fnoise(SIZE, SIZE, 1.8, seed=403)
    sc = np.clip((fnoise(SIZE, SIZE, 1.0, lo=0.05, seed=404, ax=8.0, ay=0.6) - 0.78) / 0.22, 0.0, 1.0)

    hgt = lug * 0.85 + (n_brush - 0.5) * 0.09 + (n_lo - 0.5) * 0.06
    nrm = normal_from_height(hgt, 7.5)

    # 筋顶因长期踩踏/机甲碾压发亮光滑，凹谷积油灰较暗哑
    crest = np.clip((lug - 0.45) / 0.55, 0.0, 1.0)
    valley_ao = 1.0 - np.clip((0.45 - lug) / 0.45, 0.0, 1.0) * 0.28 * (0.55 + 0.45 * n_grime)
    val = (0.62 + crest * 0.24 + (n_lo - 0.5) * 0.10 + (n_brush - 0.5) * 0.05 + sc * 0.08) * valley_ao
    rgb = np.dstack([val * 0.99, val * 1.00, val * 1.02])
    rgb = normalize_albedo(rgb, target_mean=0.68, contrast=1.08, desat=0.1, clip_lo=0.30, clip_hi=0.95)

    rough = np.clip(
        0.70 - crest * 0.42 + (n_grime - 0.5) * 0.16 - sc * 0.18,
        0.20,
        0.88,
    )
    save_rgb("treadplate_a.png", rgb)
    save_rgb("treadplate_n.png", nrm)
    save_gray("treadplate_r.png", rough)


def build_rubber_tread():
    """1K 重型硫化橡胶与人字履带胎面 (模具肋条 + 橡胶细粒 + 凹槽灰尘)"""
    print("[GEN] rubber_tread_{a,n,r}.png ...")
    y = np.linspace(0.0, 10.0, SIZE, endpoint=False)[:, None]
    x = np.linspace(0.0, 4.0, SIZE, endpoint=False)[None, :]
    # 人字斜肋履带块
    chevron = y + np.abs((x % 1.0) - 0.5) * 1.6
    rib = np.sin(chevron * np.pi * 2.0)
    block = np.clip((rib + 0.15) / 0.55, 0.0, 1.0)
    # 纵向排水沟
    groove = np.clip((np.abs((x % 1.0) - 0.5) - 0.055) / 0.035, 0.0, 1.0)
    tread = blur_periodic(block * groove, 1.1)

    n_stipple = fnoise(SIZE, SIZE, 0.75, lo=0.06, seed=501)
    n_dust = fnoise(SIZE, SIZE, 2.0, seed=502)

    hgt = tread * 0.78 + (n_stipple - 0.5) * 0.16
    nrm = normal_from_height(hgt, 6.2)

    # 凹槽微积土灰，凸块深硫化黑灰
    dust_in_groove = (1.0 - tread) * (0.45 + 0.55 * n_dust)
    val = 0.62 + tread * 0.08 + dust_in_groove * 0.14 + (n_stipple - 0.5) * 0.06
    rgb = np.dstack([
        val * (1.0 + dust_in_groove * 0.08),
        val * (1.0 + dust_in_groove * 0.04),
        val * (1.0 - dust_in_groove * 0.06),
    ])
    rgb = normalize_albedo(rgb, target_mean=0.68, contrast=1.05, desat=0.0, clip_lo=0.38, clip_hi=0.92)
    rough = np.clip(0.84 - tread * 0.14 + dust_in_groove * 0.14 + (n_stipple - 0.5) * 0.08, 0.62, 0.96)
    save_rgb("rubber_tread_a.png", rgb)
    save_rgb("rubber_tread_n.png", nrm)
    save_gray("rubber_tread_r.png", rough)


def build_env_pack(sess):
    # 高清晰度 1K 地表/屋面/建筑混凝土/海岸巨石实拍 PBR（地表三套将 Displacement 打包至 A 通道供零开销高度混合）
    download_polyhaven(sess, "leafy_grass", "ground_grass", target_mean=0.60, contrast=1.24, desat=0.14, normal_boost=1.45, rough_range=(0.74, 0.96), pack_height=True)
    download_polyhaven(sess, "brown_mud_dry", "ground_soil", target_mean=0.66, contrast=1.22, desat=0.52, normal_boost=1.45, rough_range=(0.78, 0.98), pack_height=True)
    download_polyhaven(sess, "gravel_ground_01", "ground_gravel", target_mean=0.68, contrast=1.26, desat=0.62, normal_boost=1.50, rough_range=(0.72, 0.96), pack_height=True)
    download_polyhaven(sess, "box_profile_metal_sheet", "roof_seam", target_mean=0.68, contrast=1.22, desat=0.96, normal_boost=1.45, rough_range=(0.28, 0.78))
    download_polyhaven(sess, "concrete_wall_008", "concrete", target_mean=0.68, contrast=1.26, desat=0.68, normal_boost=1.40, rough_range=(0.68, 0.96))
    download_polyhaven(sess, "rock_boulder_cracked", "rock_strata", target_mean=0.66, contrast=1.24, desat=0.76, normal_boost=1.45, rough_range=(0.68, 0.96))


def main():
    sess = requests.Session()
    sess.headers["User-Agent"] = "AbyssDiverGirlsLookDev/1.0"
    env_only = "--env-only" in sys.argv

    if not env_only:
        # 1. Poly Haven CC0 实拍 1K PBR（机甲/结构金属/建材）
        download_polyhaven(sess, "metal_plate_02", "steel_plate", target_mean=0.68, contrast=1.05, desat=0.65, normal_boost=1.25, rough_range=(0.28, 0.74))
        download_polyhaven(sess, "rusty_metal_04", "rusted_metal", target_mean=0.66, contrast=1.10, desat=0.28, normal_boost=1.35, rough_range=(0.44, 0.94))
        download_polyhaven(sess, "rusty_metal_sheet", "armor_rha", target_mean=0.68, contrast=1.08, desat=0.92, normal_boost=1.25, rough_range=(0.36, 0.72))
        download_polyhaven(sess, "rust_coarse_01", "gunmetal", target_mean=0.68, contrast=1.12, desat=0.94, normal_boost=1.30, rough_range=(0.20, 0.62))
        download_polyhaven(sess, "metal_plate", "treadplate", target_mean=0.68, contrast=1.12, desat=0.72, normal_boost=1.30, rough_range=(0.24, 0.78))
        download_polyhaven(sess, "old_planks_02", "wood_plank", target_mean=0.68, contrast=1.15, desat=0.35, normal_boost=1.35, rough_range=(0.64, 0.94))
        download_polyhaven(sess, "grey_plaster_02", "plaster", target_mean=0.68, contrast=1.10, desat=0.65, normal_boost=1.30, rough_range=(0.74, 0.96))
        download_polyhaven(sess, "hessian_230", "fabric_canvas", target_mean=0.68, contrast=1.15, desat=0.45, normal_boost=1.40, rough_range=(0.82, 0.98))
        build_rubber_tread()

    # 2. 高清晰度地表/屋面/建筑/岩石实拍 PBR
    build_env_pack(sess)
    print("[ALL DONE] PBR texture pack built in:", OUT)


if __name__ == "__main__":
    main()
