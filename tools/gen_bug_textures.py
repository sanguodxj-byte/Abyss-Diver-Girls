#!/usr/bin/env python3
"""
虫族手绘贴图生成器（离线运行，输出 PNG 到 assets/textures/bugs/）。
贴图按 Godot SphereMesh / CylinderMesh 的 UV 布局绘制：
  u = 绕轴一圈（水平方向，必须左右无缝），v = 从顶（背面）到底（腹面）。
所有噪声都用 FFT 滤波白噪声生成，天然四方连续，不会出现接缝。
用法：python3 tools/gen_bug_textures.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "bugs")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def fnoise(h, w, beta=2.0, lo=0.0, seed=None):
    """四方连续 1/f^beta 分形噪声，返回 0..1。"""
    r = np.random.default_rng(seed) if seed is not None else rng
    wn = r.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :] * (w / h)  # 保持各向同性
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(f, beta / 2.0)
    if lo > 0:
        amp *= 1.0 - np.exp(-(f / lo) ** 2)
    amp[0, 0] = 0
    n = np.real(np.fft.ifft2(np.fft.fft2(wn) * amp))
    n -= n.min()
    return n / n.max()


def blur(a, s):
    """周期高斯模糊（FFT）。"""
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi * s) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def dots(h, w, n, rmin, rmax, seed):
    """随机凹坑/刻点（周期），返回 0..1 高度坑。"""
    r = np.random.default_rng(seed)
    out = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w]
    for _ in range(n):
        cy, cx = r.uniform(0, h), r.uniform(0, w)
        rad = r.uniform(rmin, rmax)
        y0, y1 = int(cy - rad * 2), int(cy + rad * 2) + 1
        x0, x1 = int(cx - rad * 2), int(cx + rad * 2) + 1
        ys = np.arange(y0, y1) % h
        xs = np.arange(x0, x1) % w
        dy = (np.arange(y0, y1) - cy)[:, None]
        dx = (np.arange(x0, x1) - cx)[None, :]
        d = np.sqrt(dx * dx + dy * dy) / rad
        out[np.ix_(ys, xs)] = np.maximum(out[np.ix_(ys, xs)], np.clip(1 - d * d, 0, 1))
    return out


def normal_from_height(hgt, strength):
    gx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * strength
    gy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(hgt)])  # OpenGL 风格（Godot 用 +Y）
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def save_rgb(name, a):
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name))


def save_l(name, a):
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").save(os.path.join(OUT, name))


def lerp(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a + (b - a) * t


def C(hexs):
    hexs = hexs.lstrip("#")
    return np.array([int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# ------------------------------------------------------------ 甲壳
H, W = 512, 1024
v = np.linspace(0, 1, H)[:, None] * np.ones((1, W))  # 0 背 → 1 腹
u = np.ones((H, 1)) * np.linspace(0, 1, W, endpoint=False)[None, :]

n_lo = fnoise(H, W, 2.4, seed=1)
n_mid = fnoise(H, W, 1.6, seed=2)
n_hi = fnoise(H, W, 0.9, seed=3)
pits = dots(H, W, 1400, 1.0, 2.2, seed=4)
# 纵向刻纹（沿 v 方向的细沟，鞘翅/背板常见）
stri_phase = u * 40 * np.pi * 2 + (n_lo - 0.5) * 3.0
striae = ss(0.86, 1.0, 0.5 + 0.5 * np.cos(stri_phase))
# 横向生长纹（随 v 的细密环纹）
growth = 0.5 + 0.5 * np.sin(v * 140 + n_mid * 8)
# 伤痕划痕：长条细线
scr = np.zeros((H, W))
r = np.random.default_rng(11)
for _ in range(22):
    y, x = r.uniform(0, H), r.uniform(0, W)
    ang = r.uniform(0, np.pi)
    ln = r.uniform(20, 90)
    for t in np.linspace(0, 1, int(ln)):
        yy, xx = int(y + np.sin(ang) * ln * t) % H, int(x + np.cos(ang) * ln * t) % W
        scr[yy, xx] = 1
scr = np.clip(blur(scr, 0.8) * 4, 0, 1)

height = (n_lo * 0.5 + n_mid * 0.25 + n_hi * 0.08 - pits * 0.35 - striae * 0.1 * ss(0.45, 0.85, 1 - v)
          + growth * 0.02 - scr * 0.12)
save_rgb("chitin_n.png", normal_from_height(blur(height, 0.6), 9.0))

# 粗糙度：整体湿润有光泽，凹坑里积灰发哑，腹面和磨损处更哑
rough = 0.28 + 0.25 * ss(0.55, 0.85, n_mid) + 0.35 * pits + 0.2 * ss(0.6, 1.0, v) + 0.15 * scr
save_l("chitin_r.png", rough)

PALETTES = {
    # 背色 / 侧色 / 腹色 / 斑点色 / 边缘高光色
    "ling": ("#2a1210", "#5a2a1c", "#7f604a", "#120807", "#8a4a30"),
    "spitter": ("#26241a", "#4d4a30", "#8f8366", "#14120c", "#6a6640"),
    "beetle": ("#141010", "#2e241c", "#6a5440", "#070505", "#5a4630"),
}
for kind, (c_back, c_side, c_belly, c_spot, c_hi) in PALETTES.items():
    back, side, belly, spot, hi = map(C, (c_back, c_side, c_belly, c_spot, c_hi))
    seed = {"ling": 21, "spitter": 22, "beetle": 23}[kind]
    m1 = fnoise(H, W, 2.0, seed=seed)
    m2 = fnoise(H, W, 1.3, seed=seed + 100)
    col = lerp(back, side, ss(0.15, 0.55, v + (m1 - 0.5) * 0.25))
    col = lerp(col, belly, ss(0.62, 0.98, v + (m1 - 0.5) * 0.15))
    # 斑驳：不规则深色斑块（虎斑/云斑）
    if kind == "ling":
        stripes = ss(0.55, 0.62, 0.5 + 0.5 * np.sin(u * 2 * np.pi * 9 + m1 * 6))
        col = lerp(col, spot, stripes * ss(0.6, 0.2, v) * 0.75)
    elif kind == "spitter":
        blot = ss(0.6, 0.68, m2)
        col = lerp(col, spot, blot * ss(0.75, 0.25, v) * 0.85)
        col = lerp(col, C("#6f6a3a"), ss(0.75, 0.8, m1) * ss(0.7, 0.3, v) * 0.5)
    else:
        col = lerp(col, hi, ss(0.7, 0.9, n_mid) * ss(0.5, 0.0, v) * 0.35)  # 铜色光泽斑
    # 纵纹、刻点在颜色上的体现
    col = col * (1 - 0.12 * striae[..., None] * ss(0.45, 0.85, 1 - v)[..., None])
    col = col * (1 - 0.3 * pits[..., None])
    # 隆起处偏亮（受磨）
    col = lerp(col, hi, ss(0.62, 0.85, n_lo) * 0.25)
    # 划痕露出浅色角质
    col = lerp(col, side * 1.4, scr * 0.3)
    # 腹侧泥污
    col = lerp(col, C("#3b3226"), ss(0.75, 1.0, v) * ss(0.4, 0.8, m2) * 0.7)
    col *= (0.88 + 0.24 * n_hi[..., None])
    save_rgb("chitin_%s.png" % kind, col)

# ------------------------------------------------------------ 腿节（圆柱 UV：v 沿长度）
LH, LW = 512, 256
lv = np.linspace(0, 1, LH)[:, None] * np.ones((1, LW))
lu = np.ones((LH, 1)) * np.linspace(0, 1, LW, endpoint=False)[None, :]
ln_ = fnoise(LH, LW, 1.8, seed=31)
# 刚毛：短斜线
hair = np.zeros((LH, LW))
r = np.random.default_rng(32)
for _ in range(900):
    y, x = r.uniform(0, LH), r.uniform(0, LW)
    for t in range(7):
        hair[int(y + t) % LH, int(x + t * 0.4) % LW] = 1.0 - t / 8.0
hair = np.clip(blur(hair, 0.5) * 2.5, 0, 1)
ring = ss(0.92, 1.0, np.abs(np.sin(lv * np.pi * 3)))  # 关节环
lh = ln_ * 0.4 - hair * 0.4 - ring * 0.5
save_rgb("leg_n.png", normal_from_height(blur(lh, 0.6), 6.0))
save_l("leg_r.png", 0.32 + 0.3 * hair + 0.25 * ring + 0.15 * ss(0.5, 0.9, ln_))
for kind, (c_back, c_side, c_belly, c_spot, c_hi) in PALETTES.items():
    back, side, belly, spot, hi = map(C, (c_back, c_side, c_belly, c_spot, c_hi))
    col = lerp(side, back, ss(0.0, 1.0, lv))  # 近端偏浅，远端偏深
    col = lerp(col, belly, ss(0.85, 0.95, 1 - np.abs(np.sin(lv * np.pi * 3 + 0.6))) * 0.5)  # 浅色环带
    col = lerp(col, spot, ring * 0.8)
    col = lerp(col, spot, hair * 0.7)
    col *= (0.85 + 0.3 * ln_[..., None])
    save_rgb("leg_%s.png" % kind, col)

# ------------------------------------------------------------ 复眼（六边形小眼）
EH, EW = 256, 512
yy, xx = np.mgrid[0:EH, 0:EW].astype(float)
s = 7.0
q = (xx * np.sqrt(3) / 3 - yy / 3) / s
rr = yy * 2 / 3 / s
cx, cz = q, rr
cy = -cx - cz
rx, ry, rz = np.round(cx), np.round(cy), np.round(cz)
dx, dy, dz = np.abs(rx - cx), np.abs(ry - cy), np.abs(rz - cz)
fix_x = (dx > dy) & (dx > dz)
fix_y = (~fix_x) & (dy > dz)
rx = np.where(fix_x, -ry - rz, rx)
ry = np.where(fix_y, -rx - rz, ry)
d = np.maximum(np.maximum(np.abs(cx - rx), np.abs(cy - ry)), np.abs(cz - rz))
facet = 1 - ss(0.25, 0.5, d)
en = fnoise(EH, EW, 1.5, seed=41)
save_rgb("eye_n.png", normal_from_height(facet * 0.6 + en * 0.2, 4.0))
eye = lerp(C("#0b0807"), C("#3a2414"), facet * 0.5 + en * 0.3)
eye = lerp(eye, C("#6a3a10"), ss(0.7, 0.95, en) * 0.4)  # 琥珀色反光
save_rgb("eye_a.png", eye)

# ------------------------------------------------------------ 薄膜/酸囊（脉络）
MH, MW = 512, 1024
m1 = fnoise(MH, MW, 1.4, seed=51)
m2 = fnoise(MH, MW, 1.4, seed=52)
vein = np.maximum(ss(0.82, 0.97, 1 - np.abs(m1 * 2 - 1)), ss(0.86, 0.98, 1 - np.abs(m2 * 2 - 1)) * 0.7)
mh = fnoise(MH, MW, 2.2, seed=53)
save_rgb("membrane_n.png", normal_from_height(blur(vein * 0.5 + mh * 0.4, 0.8), 6.0))
mem = lerp(C("#6e5a44"), C("#9a8460"), mh)
mem = lerp(mem, C("#3a1810"), vein * 0.8)
save_rgb("membrane_a.png", mem)
sac = lerp(C("#3a4a14"), C("#7a8a30"), mh)
sac = lerp(sac, C("#2a3208"), vein * 0.85)
save_rgb("sac_a.png", sac)
save_l("sac_e.png", (1 - vein) * (0.4 + 0.6 * mh))

# ------------------------------------------------------------ 颚/爪（角质：基部深，尖端琥珀）
KH, KW = 256, 128
kv = np.linspace(0, 1, KH)[:, None] * np.ones((1, KW))
kn = fnoise(KH, KW, 1.6, seed=61)
claw = lerp(C("#4a3420"), C("#120c08"), ss(0.1, 0.9, kv + (kn - 0.5) * 0.2))
claw *= (0.85 + 0.3 * kn[..., None])
save_rgb("claw_a.png", claw)
print("bug textures ->", os.path.abspath(OUT))
