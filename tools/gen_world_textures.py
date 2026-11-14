#!/usr/bin/env python3
"""
写实工业世界与植被 PBR 贴图离线生成器（输出无缝 PNG 到 assets/textures/world/）。
所有平铺贴图采用周期性 FFT 噪声与周期坐标构造，严格保证四方连续无缝平铺；
所有 Alpha 裁切植物贴图对透明像素执行多级 RGB 边缘颜色外扩（dilation），彻底消除 Mipmap 黑边/白边。
用法：python tools/gen_world_textures.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "world")
os.makedirs(OUT, exist_ok=True)


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
# 1. 轧制重工钢板 (steel_plate_a / steel_plate_n)
# ==============================================================================
n_lo = fnoise(H, W, 2.4, seed=101)
n_mid = fnoise(H, W, 1.5, seed=102)
n_roll = fnoise(H, W, 1.3, seed=103, ax=6.5, ay=0.6)  # 热轧拉丝横向纹理
n_pit = fnoise(H, W, 0.85, seed=104)

# 错缝焊接钢板分块（4 行 × 2 列错位）
rows = 4.0
ry = v * rows
row_idx = np.floor(ry)
ru = np.mod(u * 2.0 + np.mod(row_idx, 2.0) * 0.5, 1.0)
rv = np.mod(ry, 1.0)

seam_h = 1.0 - ss(0.008, 0.024, np.minimum(rv, 1.0 - rv))
seam_v = 1.0 - ss(0.006, 0.018, np.minimum(ru, 1.0 - ru))
seam = np.maximum(seam_h, seam_v)

# 板边铆钉阵列
riv_u = np.mod(ru * 14.0, 1.0) - 0.5
riv_dy_top = (rv - 0.055) * rows * 3.5
riv_dy_bot = (rv - 0.945) * rows * 3.5
riv_dx = riv_u * 1.35
riv_d = np.minimum(
    np.sqrt(riv_dx * riv_dx + riv_dy_top * riv_dy_top),
    np.sqrt(riv_dx * riv_dx + riv_dy_bot * riv_dy_bot),
)
rivet = np.clip(1.0 - (riv_d / 0.24) ** 2, 0.0, 1.0) * ss(0.08, 0.16, np.minimum(ru, 1.0 - ru))
rivet_ao = ss(0.20, 0.34, riv_d)
rivet_ring = (1.0 - rivet_ao) * (1.0 - rivet)

# 每块钢板轻微明暗差
plate_hash = np.sin((row_idx * 37.0 + np.floor(u * 2.0 + np.mod(row_idx, 2.0) * 0.5) * 91.0)) * 0.5 + 0.5
scuff = ss(0.76, 0.92, fnoise(H, W, 1.1, seed=105, ax=4.0, ay=0.8))

steel_val = (
    0.82
    + (n_lo - 0.5) * 0.11
    + (n_roll - 0.5) * 0.07
    + (n_pit - 0.5) * 0.04
    + (plate_hash - 0.5) * 0.045
    + scuff * 0.05
    - seam * 0.36
    - rivet_ring * 0.18
    + rivet * 0.06
)
steel_rgb = np.dstack([steel_val * 0.99, steel_val * 1.00, steel_val * 1.015])
steel_h = n_lo * 0.25 + n_roll * 0.22 + n_pit * 0.10 - seam * 0.55 + rivet * 0.42 - ss(0.72, 0.90, n_pit) * 0.08
save_rgb("steel_plate_a.png", steel_rgb)
save_rgb("steel_plate_n.png", normal_from_height(steel_h, 3.2))


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
b_seam = 1.0 - ss(0.010, 0.036, np.minimum(bv, 1.0 - bv))
b_tone = np.sin(b_idx * 53.7) * 0.5 + 0.5

# 对拉螺杆孔（每两层模板一排圆锥凹孔 + 下方锈水流痕）
tu = np.mod(u * 4.0 + np.mod(np.floor(v * 4.0), 2.0) * 0.5, 1.0) - 0.5
tv = np.mod(v * 4.0, 1.0) - 0.5
td = np.sqrt((tu * 4.0) ** 2 + (tv * 4.0) ** 2)
tie_hole = np.clip(1.0 - (td / 0.16) ** 2, 0.0, 1.0)
tie_drip = np.exp(-((tu * 22.0) ** 2)) * ss(0.0, 0.04, tv) * (1.0 - ss(0.04, 0.36, tv))

# 风化剥落斑驳与微孔隙（去除网状 Voronoi 裂纹，改为自然砂浆风化斑）
c_spall = ss(0.62, 0.86, blur(c_mid, 1.5) * 0.6 + c_agg * 0.4)
micro_pit = ss(0.76, 0.94, c_agg)

conc_val = (
    0.84
    + (c_lo - 0.5) * 0.15
    + (c_grain - 0.5) * 0.075
    + (c_agg - 0.5) * 0.09
    + (b_tone - 0.5) * 0.055
    - (c_streak - 0.5) * 0.12
    - b_seam * 0.14
    - tie_hole * 0.38
    - tie_drip * 0.15
    - c_spall * 0.08
    - micro_pit * 0.07
)
conc_rgb = np.dstack([
    conc_val + tie_drip * 0.03,
    conc_val * 0.995,
    conc_val * 0.98 - tie_drip * 0.04,
])
conc_h = (
    c_lo * 0.32 + c_grain * 0.22 + c_agg * 0.24
    - b_seam * 0.25 - tie_hole * 0.65 - c_spall * 0.14
    - micro_pit * 0.20
)
save_rgb("concrete_a.png", conc_rgb)
save_rgb("concrete_n.png", normal_from_height(conc_h, 4.0))


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
# 10. 纵裂老树皮 (bark_a / bark_n)
# ==============================================================================
bk_lo = fnoise(H, W, 2.2, seed=1001, ax=0.45, ay=3.5)
bk_mid = fnoise(H, W, 1.5, seed=1002, ax=0.35, ay=4.2)
bk_hi = fnoise(H, W, 0.9, seed=1003)

# 纵向交织裂沟
fiss_phase = u * 13.0 * np.pi * 2.0 + (bk_lo - 0.5) * 5.2 + np.sin(v * 4.0 * np.pi) * 0.9
ridge = 0.5 + 0.5 * np.cos(fiss_phase)
fissure = 1.0 - ss(0.18, 0.56, ridge + (bk_mid - 0.5) * 0.28)
plate_sc = ss(0.35, 0.75, fnoise(H, W, 1.6, seed=1004, ax=1.2, ay=0.8))
lichen = ss(0.78, 0.93, fnoise(H, W, 2.0, seed=1005)) * (1.0 - fissure)

bark_val = (
    0.78
    + ridge * 0.16
    + (bk_mid - 0.5) * 0.12
    + (bk_hi - 0.5) * 0.09
    + (plate_sc - 0.5) * 0.07
    - fissure * 0.44
)
bark_rgb = np.dstack([
    bark_val * 1.04 - lichen * 0.06,
    bark_val * 0.97 + lichen * 0.08,
    bark_val * 0.88 - lichen * 0.04,
])
bark_h = (1.0 - fissure) * (0.55 + ridge * 0.25 + plate_sc * 0.12) + bk_hi * 0.12
save_rgb("bark_a.png", bark_rgb)
save_rgb("bark_n.png", normal_from_height(bark_h, 5.4))


# ==============================================================================
# 11. 针叶松柏枝簇裁切贴图 (pine_frond_a RGBA / pine_frond_n RGB)
# UV 约定：底部中央 (u=0.5, v=1.0) 为枝条基部生根点，向上 (v->0.04) 辐射分叉松针扇
# ==============================================================================
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
pu = xx / (W - 1.0)
pv = 1.0 - yy / (H - 1.0)  # pv=0 在底边(枝根)，pv=1 在顶边(枝梢)

pine_alpha = np.zeros((H, W), dtype=np.float32)
pine_rgb = np.zeros((H, W, 3), dtype=np.float32)
pine_h = np.zeros((H, W), dtype=np.float32)

rng_p = np.random.default_rng(1101)

# 先收集所有小枝线段：(x0, y0, x1, y1, radius_twig, is_main)
twigs = []
# 中央主枝略带自然弧度
twigs.append((0.50, 0.02, 0.505, 0.90, 0.011, True))
# 左右 8 对羽状分叉侧枝 + 二级分叉，饱满覆盖扇形区域
pair_ys = [0.10, 0.20, 0.31, 0.42, 0.53, 0.64, 0.74, 0.83]
for idx, y0 in enumerate(pair_ys):
    reach = 0.42 * (1.0 - 0.52 * ((y0 - 0.08) / 0.82) ** 1.25)
    for side in (-1.0, 1.0):
        jx = rng_p.uniform(-0.012, 0.012)
        jy = rng_p.uniform(-0.015, 0.015)
        x0 = 0.50 + side * 0.004
        x1 = 0.50 + side * (reach + jx)
        y1 = min(0.95, y0 + reach * 0.52 + 0.06 + jy)
        twigs.append((x0, y0, x1, y1, 0.0065, False))
        # 二级分叉小枝让冠层内部更饱满无空洞
        if idx < 6:
            mx = x0 + (x1 - x0) * 0.48
            my = y0 + (y1 - y0) * 0.48
            sx1 = mx + side * reach * 0.42
            sy1 = min(0.94, my + reach * 0.44 + 0.04)
            twigs.append((mx, my, sx1, sy1, 0.005, False))
            sx2 = mx + side * reach * 0.36
            sy2 = max(0.06, my - reach * 0.06)
            twigs.append((mx, my, sx2, sy2, 0.005, False))

# 向量化绘制每个小枝周围密集辐射的松针束 + 木质小枝芯
for x0, y0, x1, y1, tw_r, is_main in twigs:
    dx, dy = x1 - x0, y1 - y0
    seg_len = float(np.hypot(dx, dy)) + 1e-6
    ux, uy = dx / seg_len, dy / seg_len
    nx_t, ny_t = -uy, ux

    # 点到线段投影坐标 t (沿枝 0..seg_len), s (垂直枝距离)
    rx = pu - x0
    ry = pv - y0
    t_proj = rx * ux + ry * uy
    s_perp = rx * nx_t + ry * ny_t

    # 松针斜向枝梢伸展，因此等效针叶轴坐标向后偏移 |s| * cot(针角)
    needle_len = (0.072 if is_main else 0.082) * (1.0 - 0.18 * (y0))
    abs_s = np.abs(s_perp)
    t_root = t_proj - abs_s * 0.82

    in_band = (t_root >= -0.01) & (t_root <= seg_len + 0.015) & (abs_s <= needle_len * 1.15)
    if not np.any(in_band):
        continue

    # 高频针簇条纹：多频率叠加形成层叠松针束且保留高覆盖率（防止远景 Mipmap 变稀疏）
    sub_pu = pu[in_band]
    sub_pv = pv[in_band]
    sub_t = t_root[in_band]
    sub_s = s_perp[in_band]
    sub_as = abs_s[in_band]

    needle_coord = sub_t * 145.0 + np.sign(sub_s) * 1.7 + np.sin(sub_t * 37.0) * 0.6
    comb1 = 0.5 + 0.5 * np.sin(needle_coord)
    comb2 = 0.5 + 0.5 * np.sin(needle_coord * 1.73 + 1.1)
    comb3 = 0.5 + 0.5 * np.sin(needle_coord * 0.61 + 2.4)
    # 单个针尖长度随 comb 起伏，内圈密集融合、外圈呈清晰针刺状
    tip_reach = needle_len * (0.48 + 0.34 * comb1 + 0.22 * comb2) * (0.85 + 0.15 * np.sin(sub_t * 23.0))
    tip_fade = ss(0.0, 0.02, sub_t + 0.01) * (1.0 - ss(seg_len - 0.01, seg_len + 0.02, sub_t))
    reach_ratio = sub_as / (tip_reach + 1e-5)

    n_mask = np.clip((1.05 - reach_ratio) * 3.4, 0.0, 1.0) * tip_fade
    # 外缘分针间隙
    outer_sep = ss(0.45, 0.95, reach_ratio)
    strand = np.maximum(comb1, comb2 * 0.85)
    n_mask *= (1.0 - outer_sep * (1.0 - ss(0.22, 0.68, strand)))

    # 针叶色彩：基部深墨绿 AO -> 中段写实冷杉暗橄榄绿 -> 针尖微暖阳光橄榄色 + 少量废土枯黄针
    dry_patch = ss(0.76, 0.94, comb3 * 0.6 + 0.4 * np.sin(sub_pu * 19.0 + sub_pv * 13.0))
    c_base = np.array([0.16, 0.22, 0.13], dtype=np.float32)
    c_mid = np.array([0.27, 0.36, 0.20], dtype=np.float32)
    c_tip = np.array([0.39, 0.46, 0.25], dtype=np.float32)
    c_dry = np.array([0.46, 0.37, 0.21], dtype=np.float32)

    rt = np.clip(reach_ratio, 0.0, 1.0)[:, None]
    col_n = c_base * (1.0 - rt) + c_mid * rt
    col_n = col_n * (1.0 - rt * 0.45) + c_tip * (rt * 0.45)
    col_n = col_n * (1.0 - dry_patch[:, None] * 0.35) + c_dry * (dry_patch[:, None] * 0.35)
    # 针背隆起高度
    h_n = 0.25 + (1.0 - rt[:, 0]) * 0.35 + strand * 0.28

    # 木质枝芯覆盖在最中心
    t_clamped = np.clip(t_proj[in_band], 0.0, seg_len)
    d_twig = np.hypot(pu[in_band] - (x0 + ux * t_clamped), pv[in_band] - (y0 + uy * t_clamped))
    tw_w = tw_r * (1.0 - 0.45 * (t_clamped / seg_len))
    tw_mask = 1.0 - ss(tw_w * 0.65, tw_w * 1.15, d_twig)
    tw_col = np.array([0.24, 0.18, 0.13], dtype=np.float32)

    comb_a = np.maximum(n_mask, tw_mask)
    comb_c = col_n * (1.0 - tw_mask[:, None] * 0.85) + tw_col * (tw_mask[:, None] * 0.85)
    comb_h = np.maximum(h_n * n_mask, tw_mask * 0.78)

    old_a = pine_alpha[in_band]
    over = comb_a > old_a * 0.82
    blend = np.clip(comb_a, 0.0, 1.0)
    cur_c = pine_rgb[in_band]
    pine_rgb[in_band] = np.where(over[:, None], cur_c * (1.0 - blend[:, None]) + comb_c * blend[:, None], cur_c)
    pine_alpha[in_band] = np.maximum(old_a, comb_a)
    pine_h[in_band] = np.maximum(pine_h[in_band], comb_h)

save_rgba("pine_frond_a.png", pine_rgb, pine_alpha)
save_rgb("pine_frond_n.png", normal_from_height_clamped(pine_h, 4.0))


# ==============================================================================
# 12. 废土阔叶白桦/杨树枝叶簇裁切贴图 (broadleaf_a RGBA / broadleaf_n RGB)
# ==============================================================================
bl_alpha = np.zeros((H, W), dtype=np.float32)
bl_rgb = np.zeros((H, W, 3), dtype=np.float32)
bl_h = np.zeros((H, W), dtype=np.float32)

rng_b = np.random.default_rng(1201)
# 先画木质分叉细枝骨架
bl_twigs = [
    (0.50, 0.02, 0.49, 0.82, 0.009),
    (0.50, 0.16, 0.22, 0.56, 0.006),
    (0.50, 0.20, 0.79, 0.58, 0.006),
    (0.49, 0.42, 0.24, 0.80, 0.0055),
    (0.49, 0.46, 0.76, 0.82, 0.0055),
    (0.34, 0.38, 0.14, 0.42, 0.0045),
    (0.66, 0.40, 0.86, 0.44, 0.0045),
]
for x0, y0, x1, y1, tr in bl_twigs:
    dx, dy = x1 - x0, y1 - y0
    sl = float(np.hypot(dx, dy)) + 1e-6
    t_p = np.clip(((pu - x0) * dx + (pv - y0) * dy) / (sl * sl), 0.0, 1.0)
    dist = np.hypot(pu - (x0 + dx * t_p), pv - (y0 + dy * t_p))
    tm = 1.0 - ss(tr * (1.0 - 0.4 * t_p) * 0.6, tr * (1.0 - 0.4 * t_p) * 1.2, dist)
    bl_alpha = np.maximum(bl_alpha, tm)
    bl_rgb = np.where((tm > 0.05)[..., None], np.array([0.27, 0.22, 0.17]), bl_rgb)
    bl_h = np.maximum(bl_h, tm * 0.65)

# 沿各分枝散布 58 片大小错落、带锯齿边缘与叶脉的叶片，保证饱满度与自然轮廓
leaf_anchors = []
for x0, y0, x1, y1, _ in bl_twigs:
    steps = 9
    for k in range(1, steps + 1):
        f_t = k / float(steps)
        bx_l = x0 + (x1 - x0) * f_t + rng_b.uniform(-0.045, 0.045)
        by_l = y0 + (y1 - y0) * f_t + rng_b.uniform(-0.035, 0.035)
        ang = np.arctan2(y1 - y0, x1 - x0) + rng_b.choice([-1.0, 1.0]) * rng_b.uniform(0.35, 1.05)
        lw = rng_b.uniform(0.058, 0.092)
        ll = lw * rng_b.uniform(1.45, 1.85)
        leaf_anchors.append((bx_l, by_l, ang, lw, ll, rng_b.uniform(0.0, 1.0)))

for lx, ly, ang, lw, ll, tone in leaf_anchors:
    ca, sa = np.cos(ang), np.sin(ang)
    # 叶片局部坐标：lu 沿叶主脉 (0 叶柄 .. 1 叶尖)，lv 横跨叶片 (-1 .. 1)
    du = pu - lx
    dv = pv - ly
    lu = (du * ca + dv * sa) / ll
    lv = (-du * sa + dv * ca) / lw

    box = (lu >= -0.05) & (lu <= 1.08) & (np.abs(lv) <= 1.25)
    if not np.any(box):
        continue

    slu = lu[box]
    slv = lv[box]
    aslv = np.abs(slv)

    # 卵圆渐尖叶形 + 细微边缘锯齿
    profile = np.sin(np.clip(slu, 0.0, 1.0) * np.pi) ** 0.72 * (1.0 - 0.28 * np.clip(slu, 0.0, 1.0))
    serrate = 0.045 * np.sin(slu * 42.0) * ss(0.15, 0.85, slu)
    half_w = np.maximum(0.02, profile + serrate)
    edge_d = aslv / half_w
    l_mask = 1.0 - ss(0.88, 1.04, edge_d)
    l_mask *= ss(-0.02, 0.04, slu) * (1.0 - ss(0.96, 1.03, slu))

    # 主叶脉与羽状侧脉凹凸
    midrib = 1.0 - ss(0.02, 0.09, aslv) * ss(0.0, 0.85, slu)
    side_vein = (1.0 - ss(0.04, 0.16, np.abs(np.mod((slu - aslv * 0.42) * 9.0, 1.0) - 0.5))) * (1.0 - edge_d * 0.5)
    vein_amt = np.clip(midrib * 0.7 + side_vein * 0.35, 0.0, 1.0)

    # 写实废土林木叶色：橄榄绿 / 灰苔绿 / 微秋黄褐渐变
    c_green = np.array([0.28, 0.37, 0.19], dtype=np.float32)
    c_olive = np.array([0.36, 0.42, 0.22], dtype=np.float32)
    c_ochre = np.array([0.46, 0.41, 0.22], dtype=np.float32)
    if tone < 0.55:
        base_c = lerp(c_green, c_olive, tone / 0.55)
    else:
        base_c = lerp(c_olive, c_ochre, (tone - 0.55) / 0.45)

    # 叶片中部受光微亮、基部微暗、叶脉偏浅黄绿
    grad = (0.82 + 0.26 * np.clip(slu, 0.0, 1.0) - 0.10 * edge_d)[:, None]
    l_col = base_c[None, :] * grad + np.array([0.05, 0.06, 0.02])[None, :] * vein_amt[:, None]

    # 叠压下层叶片时在边缘投下自然微阴影 AO
    prev_a = bl_alpha[box]
    cur_c = bl_rgb[box]
    shadow_rim = (1.0 - ss(0.95, 1.22, edge_d)) * (1.0 - l_mask) * (prev_a > 0.2)
    cur_c = cur_c * (1.0 - shadow_rim[:, None] * 0.26)

    vis = l_mask > 0.05
    bl_rgb[box] = np.where(vis[:, None], cur_c * (1.0 - l_mask[:, None]) + l_col * l_mask[:, None], cur_c)
    bl_alpha[box] = np.maximum(prev_a, l_mask)
    # V 字微折叶片法线高度
    lh = (0.35 + 0.35 * (1.0 - np.clip(edge_d, 0.0, 1.0)) - 0.15 * aslv + vein_amt * 0.14) * l_mask
    bl_h[box] = np.where(l_mask > 0.4, lh, bl_h[box])

save_rgba("broadleaf_a.png", bl_rgb, bl_alpha)
save_rgb("broadleaf_n.png", normal_from_height_clamped(bl_h, 3.8))


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

print("Generated world & foliage textures in:", os.path.abspath(OUT))
for fn in sorted(os.listdir(OUT)):
    if fn.endswith(".png"):
        print(" -", fn)
