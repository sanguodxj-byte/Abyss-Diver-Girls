"""
Generate B.o.T-grade 2048x2048 Heavy Military Hard-Surface Trim Sheet v2 + Companion Maps:
  - mech_trim_a.png    (2048x2048): Neutral grayscale RHA steel/cast albedo + TIG weld heat zones + grime streaks + hazard band
  - mech_trim_n.png    (2048x2048): Band-limited tangent-space normal map with rolled-steel pitting, weld ripples & machined seams
  - mech_trim_orm.png  (2048x2048): R=Cavity AO, G=Calibrated Roughness, B=Sharp Edge-Chip & Bare-Metal Mask
  - mech_detail_n.png  (512x512)  : Tileable micro-surface normal (cast-iron micropitting + CARC military paint grain)
  - mech_decal_a.png   (1024x512) : RGBA tactical stencils (unit numbers 17/54/08/12, hazard triangles, chevrons, lift marks, soot)

100% backward-compatible with MECH_MODELING_STANDARD v1.0 TRIM_BANDS, plus new B.o.T bands in previously unused regions:
  - armor_slab   (U 0.508..0.992, V 0.012..0.112): Broad clean RHA rolled-steel slab with perimeter weld bead (70% rest area!)
  - weld_plate   (U 0.508..0.992, V 0.128..0.228): Heavy TIG-welded applique armor plate + grime leak streaks
  - radiator_fin (U 0.672..0.992, V 0.850..0.988): High-density recessed reactor/weapon cooling fins
"""
import os
import math
import numpy as np
from scipy.ndimage import gaussian_filter, sobel
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures"))
os.makedirs(OUT_DIR, exist_ok=True)
S = 2048


def periodic_fbm(size: int, octaves=((8, 0.42), (20, 0.26), (52, 0.17), (128, 0.10), (320, 0.05)), seed=101, stretch_x=1.0):
    """True multi-octave periodic noise via spectral synthesis / smooth upsampling without boxy grid artifacts."""
    acc = np.zeros((size, size), dtype=np.float32)
    w_sum = 0.0
    for idx, (freq, weight) in enumerate(octaves):
        r = np.random.default_rng(seed + idx * 37)
        fx = max(2, int(round(freq / stretch_x)))
        fy = max(2, int(freq))
        grid = r.standard_normal((fy, fx)).astype(np.float32)
        # Pad periodically before bicubic resize so wrap-around at UV=0/1 is 100% seamless
        pad = 3
        gp = np.pad(grid, ((pad, pad), (pad, pad)), mode="wrap")
        g_min, g_ptp = float(gp.min()), max(float(np.ptp(gp)), 1e-5)
        gp_u8 = np.clip((gp - g_min) / g_ptp * 255.0, 0, 255).astype(np.uint8)
        big_h = int(round(size * (fy + 2 * pad) / fy))
        big_w = int(round(size * (fx + 2 * pad) / fx))
        up = np.asarray(Image.fromarray(gp_u8).resize((big_w, big_h), Image.BICUBIC), dtype=np.float32) / 255.0
        ox = int(round(size * pad / fx))
        oy = int(round(size * pad / fy))
        tile = up[oy:oy + size, ox:ox + size]
        acc += tile * weight
        w_sum += weight
    acc /= max(w_sum, 1e-5)
    p2, p98 = np.percentile(acc, [2, 98])
    return np.clip((acc - p2) / max(p98 - p2, 1e-5), 0.0, 1.0)


def cellular_pitting(size: int, cells: int = 96, seed: int = 77) -> np.ndarray:
    """Tileable cast-armor slag/sand micropitting field (0 = flat, 1 = sharp pit)."""
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / float(size) * cells
    ix = np.floor(xx).astype(np.int32)
    iy = np.floor(yy).astype(np.int32)
    fx = xx - ix
    fy = yy - iy
    ox = r.random((cells, cells), dtype=np.float32)
    oy = r.random((cells, cells), dtype=np.float32)
    pr = r.random((cells, cells), dtype=np.float32)
    min_d = np.full((size, size), 10.0, dtype=np.float32)
    pit_strength = np.zeros((size, size), dtype=np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx = (ix + dx) % cells
            cy = (iy + dy) % cells
            vx = dx + ox[cy, cx] - fx
            vy = dy + oy[cy, cx] - fy
            d = np.sqrt(vx * vx + vy * vy)
            mask = d < min_d
            min_d = np.where(mask, d, min_d)
            pit_strength = np.where(mask, pr[cy, cx], pit_strength)
    # Only ~30% of cells produce sharp cast-iron micropits
    active = (pit_strength > 0.70).astype(np.float32)
    pit = np.clip(1.0 - min_d / 0.24, 0.0, 1.0) ** 2 * active
    return pit


print("[trim_sheet v2] synthesizing RHA rolled/cast steel fields...")
n_macro = periodic_fbm(S, ((6, 0.50), (14, 0.32), (32, 0.18)), seed=11)
n_mottle = periodic_fbm(S, ((12, 0.45), (28, 0.35), (68, 0.20)), seed=29)
n_fine = periodic_fbm(S, ((64, 0.40), (160, 0.35), (380, 0.25)), seed=47)
n_roll = periodic_fbm(S, ((24, 0.35), (96, 0.40), (256, 0.25)), seed=63, stretch_x=3.5)
n_pits = cellular_pitting(S, 112, seed=89)
n_pits_fine = cellular_pitting(S, 240, seed=131)

# Buffers
H = np.full((S, S), 0.55, dtype=np.float32)
AO = np.ones((S, S), dtype=np.float32)
ROUGH = np.full((S, S), 0.60, dtype=np.float32)    # Military CARC matte baseline
CHIP = np.zeros((S, S), dtype=np.float32)          # Sharp edge-chip & bare-metal mask (ORM.B)
GRIME = np.zeros((S, S), dtype=np.float32)         # Dark soot / oil leak darkening
COLOR_OVR = np.zeros((S, S, 4), dtype=np.float32)

# Authentic RHA rolled steel mill-scale + cast micropits across the entire sheet
H += (n_macro - 0.5) * 0.016 + (n_roll - 0.5) * 0.012 + (n_fine - 0.5) * 0.010 - n_pits * 0.032 - n_pits_fine * 0.018
ROUGH += (n_mottle - 0.5) * 0.18 + (n_fine - 0.5) * 0.08 + n_pits * 0.14
AO *= (1.0 - n_pits * 0.18 - np.clip(n_mottle - 0.55, 0.0, 0.45) * 0.16)
GRIME += np.clip(n_mottle * 0.65 + n_macro * 0.35 - 0.52, 0.0, 0.48) * 0.35


def ypx(v): return int(round(v * S))
def xpx(u): return int(round(u * S))


def draw_groove_h(v, width_px=9, depth=0.36, u0=0.0, u1=1.0):
    yc = ypx(v)
    x0, x1 = xpx(u0), xpx(u1)
    half = max(2, width_px // 2)
    ys = np.arange(max(0, yc - half - 6), min(S, yc + half + 7))
    dist = np.abs(ys - yc).astype(np.float32)
    prof = np.clip(1.0 - dist / (half + 0.5), 0.0, 1.0)
    prof_s = prof * prof * (3.0 - 2.0 * prof)
    rim = np.exp(-((dist - (half + 2.2)) / 2.0) ** 2)
    H[ys, x0:x1] -= prof_s[:, None] * depth
    AO[ys, x0:x1] *= (1.0 - prof_s[:, None] * 0.80)
    ROUGH[ys, x0:x1] = np.maximum(ROUGH[ys, x0:x1], 0.68 + prof_s[:, None] * 0.28)
    CHIP[ys, x0:x1] = np.maximum(CHIP[ys, x0:x1], rim[:, None] * 0.86)


def draw_groove_v(u, width_px=9, depth=0.36, v0=0.0, v1=1.0):
    xc = xpx(u)
    y0, y1 = ypx(v0), ypx(v1)
    half = max(2, width_px // 2)
    xs = np.arange(max(0, xc - half - 6), min(S, xc + half + 7))
    dist = np.abs(xs - xc).astype(np.float32)
    prof = np.clip(1.0 - dist / (half + 0.5), 0.0, 1.0)
    prof_s = prof * prof * (3.0 - 2.0 * prof)
    rim = np.exp(-((dist - (half + 2.2)) / 2.0) ** 2)
    H[y0:y1, xs] -= prof_s[None, :] * depth
    AO[y0:y1, xs] *= (1.0 - prof_s[None, :] * 0.80)
    ROUGH[y0:y1, xs] = np.maximum(ROUGH[y0:y1, xs], 0.68 + prof_s[None, :] * 0.28)
    CHIP[y0:y1, xs] = np.maximum(CHIP[y0:y1, xs], rim[None, :] * 0.86)


def draw_weld_h(v, u0, u1, width_px=7, amp=0.09):
    """Scalloped TIG/MIG industrial weld bead along horizontal seam."""
    yc = ypx(v)
    x0, x1 = xpx(u0), xpx(u1)
    y0, y1 = max(0, yc - width_px - 3), min(S, yc + width_px + 4)
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    dy = (yy - yc) / max(1.0, width_px * 0.5)
    scallop = 0.5 + 0.5 * np.sin(xx * 0.62 + np.cos(dy * 1.4) * 1.6)
    env = np.clip(1.0 - dy * dy, 0.0, 1.0)
    bead = env * (0.55 + 0.45 * scallop)
    haz = np.exp(-(dy * dy) * 0.45) * (1.0 - env * 0.7)
    H[y0:y1, x0:x1] += bead * amp
    AO[y0:y1, x0:x1] *= (1.0 - haz * 0.34)
    GRIME[y0:y1, x0:x1] = np.maximum(GRIME[y0:y1, x0:x1], haz * 0.45)
    CHIP[y0:y1, x0:x1] = np.maximum(CHIP[y0:y1, x0:x1], bead * 0.58)
    ROUGH[y0:y1, x0:x1] = np.where(bead > 0.35, 0.36, ROUGH[y0:y1, x0:x1])


def draw_bevel_rect(u0, v0, u1, v1, dh=0.14, bev_px=11, metallic_rim=0.72, leak=False):
    x0, x1 = xpx(u0), xpx(u1)
    y0, y1 = ypx(v0), ypx(v1)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    dx = np.minimum(xx - x0, (x1 - 1) - xx).astype(np.float32)
    dy = np.minimum(yy - y0, (y1 - 1) - yy).astype(np.float32)
    d = np.minimum(dx, dy)
    ramp = np.clip(d / max(1.0, float(bev_px)), 0.0, 1.0)
    ramp = ramp * ramp * (3.0 - 2.0 * ramp)
    H[y0:y1, x0:x1] += ramp * dh
    if dh < 0:
        AO[y0:y1, x0:x1] *= (1.0 - ramp * 0.55)
        ROUGH[y0:y1, x0:x1] = np.maximum(ROUGH[y0:y1, x0:x1], 0.68 + ramp * 0.24)
        GRIME[y0:y1, x0:x1] = np.maximum(GRIME[y0:y1, x0:x1], ramp * 0.32)
    else:
        rim = np.exp(-((d - bev_px * 0.82) / 2.3) ** 2)
        CHIP[y0:y1, x0:x1] = np.maximum(CHIP[y0:y1, x0:x1], rim * metallic_rim)
        outer_ao = np.exp(-(d / 3.4) ** 2) * 0.44
        AO[y0:y1, x0:x1] *= (1.0 - outer_ao)
    if leak and y1 + 36 < S:
        ly0, ly1 = y1, min(S, y1 + 34)
        lyy, lxx = np.mgrid[ly0:ly1, x0:x1].astype(np.float32)
        fall = np.clip(1.0 - (lyy - ly0) / 34.0, 0.0, 1.0) ** 1.6
        st = n_fine[ly0:ly1, x0:x1] * 0.7 + n_mottle[ly0:ly1, x0:x1] * 0.3
        streak = fall * np.clip((st - 0.44) * 2.4, 0.0, 1.0) * 0.42
        GRIME[ly0:ly1, x0:x1] = np.maximum(GRIME[ly0:ly1, x0:x1], streak)
        ROUGH[ly0:ly1, x0:x1] = np.where(streak > 0.12, 0.42, ROUGH[ly0:ly1, x0:x1])


def draw_bolt(u, v, rad_px=10, countersunk=True, leak=True):
    cx, cy = xpx(u), ypx(v)
    r_pad = rad_px + 8
    y0, y1 = max(0, cy - r_pad), min(S, cy + r_pad + 1)
    x0, x1 = max(0, cx - r_pad), min(S, cx + r_pad + 1)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    dx = (xx - cx).astype(np.float32)
    dy = (yy - cy).astype(np.float32)
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    hex_r = r * np.cos((np.mod(ang + math.pi / 6.0, math.pi / 3.0)) - math.pi / 6.0)

    if countersunk:
        pocket = np.clip(1.0 - (r - rad_px * 0.96) / 3.8, 0.0, 1.0)
        H[y0:y1, x0:x1] -= pocket * 0.24
        AO[y0:y1, x0:x1] *= (1.0 - pocket * 0.72)
        head = np.clip(1.0 - (hex_r - rad_px * 0.58) / 2.0, 0.0, 1.0)
        H[y0:y1, x0:x1] += head * 0.28
        sock = np.clip(1.0 - (r - rad_px * 0.24) / 1.5, 0.0, 1.0)
        H[y0:y1, x0:x1] -= sock * 0.16
        AO[y0:y1, x0:x1] *= (1.0 - sock * 0.62)
        CHIP[y0:y1, x0:x1] = np.maximum(CHIP[y0:y1, x0:x1], head * 0.88)
        ROUGH[y0:y1, x0:x1] = np.where(head > 0.3, 0.24, ROUGH[y0:y1, x0:x1])
    else:
        head = np.clip(1.0 - (hex_r - rad_px * 0.74) / 2.3, 0.0, 1.0)
        H[y0:y1, x0:x1] += head * 0.24
        ring_ao = np.exp(-((r - rad_px * 0.96) / 2.6) ** 2)
        AO[y0:y1, x0:x1] *= (1.0 - ring_ao * 0.52)
        CHIP[y0:y1, x0:x1] = np.maximum(CHIP[y0:y1, x0:x1], head * 0.85)
        ROUGH[y0:y1, x0:x1] = np.where(head > 0.3, 0.26, ROUGH[y0:y1, x0:x1])

    # Downward hydraulic oil / rain grime tail under bolt
    if leak and cy + rad_px + 26 < S:
        ly0, ly1 = cy + int(rad_px * 0.6), min(S, cy + rad_px + 28)
        lx0, lx1 = max(0, cx - rad_px), min(S, cx + rad_px + 1)
        lyy, lxx = np.mgrid[ly0:ly1, lx0:lx1].astype(np.float32)
        wx = np.exp(-((lxx - cx) / max(2.2, rad_px * 0.42)) ** 2)
        wy = np.clip(1.0 - (lyy - ly0) / float(max(1, ly1 - ly0)), 0.0, 1.0) ** 1.5
        tail = wx * wy * (0.30 + 0.45 * n_mottle[ly0:ly1, lx0:lx1])
        GRIME[ly0:ly1, lx0:lx1] = np.maximum(GRIME[ly0:ly1, lx0:lx1], tail * 0.62)
        ROUGH[ly0:ly1, lx0:lx1] = np.where(tail > 0.14, 0.38, ROUGH[ly0:ly1, lx0:lx1])


# ==============================================================================
# BAND 0 (V 0.00..0.24):
#   LEFT  (U 0.00..0.50): Legacy compatible armor_panel (top) & armor_hatch (bot)
#   RIGHT (U 0.50..1.00): NEW B.o.T broad clean RHA armor_slab (top) & TIG weld_plate (bot)
# ==============================================================================
draw_groove_h(0.004, 10, 0.36)
draw_groove_h(0.238, 10, 0.36)
draw_groove_h(0.120, 9, 0.32)
for u in [0.0, 0.25, 0.50]:
    draw_groove_v(u + 0.002, 9, 0.34, 0.0, 0.24)

# Left Upper (0..0.50, 0..0.12): armor_panel
for i in range(2):
    u0 = i * 0.25 + 0.015
    u1 = (i + 1) * 0.25 - 0.015
    draw_bevel_rect(u0, 0.017, u1, 0.105, dh=0.12, bev_px=12, metallic_rim=0.82, leak=True)
    if i == 0:
        draw_bevel_rect(u0 + 0.052, 0.042, u1 - 0.052, 0.080, dh=-0.11, bev_px=6)
    else:
        draw_weld_h(0.022, u0 + 0.01, u1 - 0.01, 5, 0.07)
    for bu in np.linspace(u0 + 0.018, u1 - 0.018, 4):
        draw_bolt(bu, 0.028, 8, True, leak=True)
        draw_bolt(bu, 0.094, 8, True, leak=False)

# Left Lower (0..0.50, 0.12..0.24): armor_hatch
for i in range(2):
    u0 = i * 0.25 + 0.012
    u1 = (i + 1) * 0.25 - 0.012
    draw_bevel_rect(u0, 0.132, u1, 0.226, dh=0.08, bev_px=9, metallic_rim=0.72, leak=True)
    draw_bevel_rect(u0 + 0.028, 0.148, u1 - 0.028, 0.210, dh=-0.08, bev_px=5, leak=True)
    draw_bevel_rect(u0 + 0.035, 0.155, u1 - 0.035, 0.203, dh=0.10, bev_px=6, metallic_rim=0.78)
    draw_bevel_rect(u1 - 0.066, 0.170, u1 - 0.044, 0.188, dh=-0.14, bev_px=4)
    for bu in [u0 + 0.014, u1 - 0.014]:
        for bv in [0.145, 0.179, 0.213]:
            draw_bolt(bu, bv, 7, True, leak=(bv > 0.20))

# Right Upper (0.505..0.995, 0.008..0.116): NEW armor_slab — Broad unbroken 50mm RHA rolled armor slab!
# Subtle top/bottom chamfer + weld bead at edges, completely clean interior with authentic steel pitting & mottling
draw_weld_h(0.013, 0.508, 0.992, 6, 0.08)
draw_weld_h(0.111, 0.508, 0.992, 6, 0.08)
for bu in [0.545, 0.750, 0.955]:
    draw_bolt(bu, 0.022, 6, True, leak=True)

# Right Lower (0.505..0.995, 0.126..0.232): NEW weld_plate — Heavy TIG-welded applique plate
draw_bevel_rect(0.516, 0.134, 0.984, 0.224, dh=0.13, bev_px=13, metallic_rim=0.86, leak=True)
draw_weld_h(0.136, 0.522, 0.978, 7, 0.09)
draw_weld_h(0.222, 0.522, 0.978, 7, 0.09)
for bu in [0.542, 0.680, 0.820, 0.958]:
    draw_bolt(bu, 0.148, 8, False, leak=True)
    draw_bolt(bu, 0.210, 8, False, leak=False)

# ==============================================================================
# BAND 1 (V 0.24..0.42): STAMPED RIBS, FLANGES & CNC LIGHTENING POCKETS
# ==============================================================================
draw_groove_h(0.418, 10, 0.36)
for rv in [0.258, 0.282, 0.306]:
    draw_bevel_rect(0.008, rv, 0.992, rv + 0.016, dh=0.17, bev_px=7, metallic_rim=0.84)
for bu in np.linspace(0.02, 0.98, 24):
    draw_bolt(bu, 0.248, 6, False, leak=False)
    draw_bolt(bu, 0.332, 6, False, leak=True)
for i in range(8):
    u0 = i * 0.125 + 0.012
    u1 = (i + 1) * 0.125 - 0.012
    draw_bevel_rect(u0, 0.346, u1, 0.408, dh=0.09, bev_px=6, metallic_rim=0.68)
    draw_bevel_rect(u0 + 0.014, 0.358, u1 - 0.014, 0.396, dh=-0.24, bev_px=8)
    draw_bolt(u0 + 0.006, 0.377, 5, True, leak=False)
    draw_bolt(u1 - 0.006, 0.377, 5, True, leak=False)

# ==============================================================================
# BAND 2 (V 0.42..0.58): RADIATOR INTAKE LOUVERS (LEFT) + HEAT-SHIELD PERFORATIONS (RIGHT)
# ==============================================================================
draw_groove_h(0.578, 10, 0.36)
y0, y1 = ypx(0.426), ypx(0.572)
x0, x1 = xpx(0.012), xpx(0.488)
yy = np.arange(y0, y1, dtype=np.float32)
period = (y1 - y0) / 14.0
phase = np.mod(yy - y0, period) / period
blade_h = np.where(phase < 0.26, -0.38, -0.38 + ((phase - 0.26) / 0.66) * 0.56)
blade_h = np.where(phase > 0.92, 0.18 - ((phase - 0.92) / 0.08) * 0.56, blade_h)
blade_ao = np.where(phase < 0.32, 0.12, 0.28 + ((phase - 0.32) / 0.68) * 0.72)
H[y0:y1, x0:x1] = 0.55 + blade_h[:, None]
AO[y0:y1, x0:x1] = blade_ao[:, None]
ROUGH[y0:y1, x0:x1] = np.where(phase < 0.32, 0.95, 0.40)[:, None]
CHIP[y0:y1, x0:x1] = np.where((phase > 0.85) & (phase < 0.94), 0.82, 0.0)[:, None]
for du in [0.17, 0.33]:
    draw_bevel_rect(du - 0.010, 0.424, du + 0.010, 0.574, dh=0.22, bev_px=5, metallic_rim=0.80)

rx0, rx1 = xpx(0.512), xpx(0.988)
yy2, xx2 = np.mgrid[y0:y1, rx0:rx1]
gx = (xx2 - rx0).astype(np.float32) / 28.0
gy = (yy2 - y0).astype(np.float32) / 24.0
row_idx = np.floor(gy)
gx = gx + np.mod(row_idx, 2.0) * 0.5
fx = np.mod(gx, 1.0) - 0.5
fy = np.mod(gy, 1.0) - 0.5
rad = np.sqrt(fx * fx + fy * fy)
hole = np.clip(1.0 - (rad - 0.28) / 0.09, 0.0, 1.0)
rim_h = np.exp(-((rad - 0.38) / 0.06) ** 2)
H[y0:y1, rx0:rx1] -= hole * 0.44
AO[y0:y1, rx0:rx1] *= (1.0 - hole * 0.88)
ROUGH[y0:y1, rx0:rx1] = np.where(hole > 0.4, 0.96, 0.42)
CHIP[y0:y1, rx0:rx1] = np.maximum(CHIP[y0:y1, rx0:rx1], rim_h * 0.72)

# ==============================================================================
# BAND 3 (V 0.58..0.72): DUST BOOT BELLOWS / BRAIDED HOSE / MACHINED KNURL GEAR
# ==============================================================================
draw_groove_h(0.718, 10, 0.36)
y0, y1 = ypx(0.584), ypx(0.714)
x0, x1 = xpx(0.0), xpx(0.34)
yy = np.arange(y0, y1, dtype=np.float32)
bellows = np.sin((yy - y0) / (y1 - y0) * math.tau * 10.0)
H[y0:y1, x0:x1] = 0.52 + bellows[:, None] * 0.28
AO[y0:y1, x0:x1] = 0.38 + (bellows[:, None] * 0.5 + 0.5) * 0.62
ROUGH[y0:y1, x0:x1] = 0.84 - (bellows[:, None] * 0.5 + 0.5) * 0.18

x0, x1 = xpx(0.34), xpx(0.68)
yy2, xx2 = np.mgrid[y0:y1, x0:x1]
w1 = np.sin((xx2 + yy2) * 0.32)
w2 = np.sin((xx2 - yy2) * 0.32)
braid = np.maximum(w1, w2) * 0.5 + 0.5
H[y0:y1, x0:x1] = 0.48 + braid * 0.16
AO[y0:y1, x0:x1] = 0.42 + braid * 0.58
CHIP[y0:y1, x0:x1] = braid * 0.55
ROUGH[y0:y1, x0:x1] = 0.34

x0, x1 = xpx(0.68), xpx(1.0)
xx = np.arange(x0, x1, dtype=np.float32)
teeth = np.clip(np.sin((xx - x0) / (x1 - x0) * math.tau * 24.0) * 2.2, -1.0, 1.0)
H[y0:y1, x0:x1] = 0.52 + teeth[None, :] * 0.25
AO[y0:y1, x0:x1] = 0.30 + (teeth[None, :] * 0.5 + 0.5) * 0.70
ROUGH[y0:y1, x0:x1] = 0.32
CHIP[y0:y1, x0:x1] = np.maximum(CHIP[y0:y1, x0:x1], np.clip(teeth[None, :], 0.0, 1.0) * 0.72)

# ==============================================================================
# BAND 4 (V 0.72..0.84): WORN B.o.T HAZARD CHEVRON BAND + BOLTED TRIM STRIP
# ==============================================================================
draw_groove_h(0.838, 10, 0.36)
y0, y1 = ypx(0.728), ypx(0.830)
x0, x1 = xpx(0.0), xpx(0.50)
yy2, xx2 = np.mgrid[y0:y1, x0:x1]
chev = np.mod((xx2 + yy2) / 58.0, 1.0)
is_yel = (chev < 0.50).astype(np.float32)
chip_hz = n_mottle[y0:y1, x0:x1] * 0.55 + n_fine[y0:y1, x0:x1] * 0.45
paint_a = np.clip((chip_hz - 0.22) * 5.5, 0.0, 1.0)
# High-contrast B.o.T industrial amber-yellow & matte charcoal chevrons with bare steel chips
COLOR_OVR[y0:y1, x0:x1, 0] = is_yel * 0.86 + (1.0 - is_yel) * 0.075
COLOR_OVR[y0:y1, x0:x1, 1] = is_yel * 0.63 + (1.0 - is_yel) * 0.080
COLOR_OVR[y0:y1, x0:x1, 2] = is_yel * 0.12 + (1.0 - is_yel) * 0.088
COLOR_OVR[y0:y1, x0:x1, 3] = paint_a * 0.94
CHIP[y0:y1, x0:x1] = np.maximum(CHIP[y0:y1, x0:x1], (1.0 - paint_a) * 0.92)

draw_bevel_rect(0.51, 0.734, 0.99, 0.824, dh=0.11, bev_px=8, metallic_rim=0.76)
draw_weld_h(0.735, 0.515, 0.985, 5, 0.06)
for bu in np.linspace(0.535, 0.965, 12):
    draw_bolt(bu, 0.785, 8, False, leak=True)

# ==============================================================================
# BAND 5 (V 0.84..1.00):
#   LEFT  (U 0.00..0.66): Cast-steel inner frame CNC pockets & circular inspection ports
#   RIGHT (U 0.67..1.00): NEW B.o.T high-density cooling radiator fins
# ==============================================================================
for i in range(4):
    u0 = i * (0.66 / 4.0) + 0.010
    u1 = (i + 1) * (0.66 / 4.0) - 0.010
    draw_bevel_rect(u0, 0.852, u1, 0.986, dh=0.10, bev_px=8, metallic_rim=0.68)
    if i % 2 == 0:
        draw_bevel_rect(u0 + 0.018, 0.870, u1 - 0.018, 0.968, dh=-0.22, bev_px=8)
    else:
        cx, cy = xpx((u0 + u1) * 0.5), ypx(0.919)
        r_p = 74
        py0, py1 = cy - r_p - 12, cy + r_p + 12
        px0, px1 = cx - r_p - 12, cx + r_p + 12
        yy2, xx2 = np.mgrid[py0:py1, px0:px1]
        rr = np.sqrt((xx2 - cx).astype(np.float32) ** 2 + (yy2 - cy).astype(np.float32) ** 2)
        ring = np.exp(-((rr - r_p * 0.78) / 8.5) ** 2)
        well = np.clip(1.0 - (rr - r_p * 0.58) / 5.0, 0.0, 1.0)
        H[py0:py1, px0:px1] += ring * 0.19 - well * 0.18
        AO[py0:py1, px0:px1] *= (1.0 - well * 0.48)
        CHIP[py0:py1, px0:px1] = np.maximum(CHIP[py0:py1, px0:px1], ring * 0.78)
        for bi in range(6):
            ba = math.tau * bi / 6.0
            draw_bolt((u0 + u1) * 0.5 + math.cos(ba) * 0.036, 0.919 + math.sin(ba) * 0.036, 5, False, leak=False)

# Right (U 0.672..0.992, V 0.850..0.988): High-density radiator heat-sink fins
ry0, ry1 = ypx(0.848), ypx(0.990)
rx0, rx1 = xpx(0.670), xpx(0.994)
draw_groove_v(0.665, 8, 0.34, 0.84, 1.0)
xx_r = np.arange(rx0, rx1, dtype=np.float32)
fins = np.clip(np.sin((xx_r - rx0) / (rx1 - rx0) * math.tau * 22.0) * 2.6, -1.0, 1.0)
H[ry0:ry1, rx0:rx1] = 0.50 + fins[None, :] * 0.30
AO[ry0:ry1, rx0:rx1] = 0.18 + (fins[None, :] * 0.5 + 0.5) * 0.82
ROUGH[ry0:ry1, rx0:rx1] = np.where(fins[None, :] > 0.2, 0.30, 0.92)
CHIP[ry0:ry1, rx0:rx1] = np.where(fins[None, :] > 0.65, 0.75, 0.0)

# ==============================================================================
# SYNTHESIZE FINAL 2K TRIM MAPS (BAND-LIMITED NORMAL + HONEST ORM + MOTTLED ALBEDO)
# ==============================================================================
# Band-limit heightfield before Sobel so mipmaps never shimmer at 30m!
H_s = gaussian_filter(H, sigma=0.78)
gx = sobel(H_s, axis=1) * 4.1
gy = sobel(H_s, axis=0) * 4.1
nx = -gx
ny = gy
nz = np.ones_like(H_s)
nlen = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
nx /= nlen; ny /= nlen; nz /= nlen
norm_u8 = np.clip(np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1) * 255.0, 0, 255).astype(np.uint8)

# Crisp ragged edge-chipping breakup (high-contrast binary-leaning mask stored in ORM.B!)
chip_noise = n_fine * 0.58 + n_mottle * 0.42
chip_sharp = np.clip((CHIP * (0.50 + 0.85 * chip_noise) - 0.32) * 3.2, 0.0, 1.0)
AO_final = np.clip(AO * (1.0 - GRIME * 0.36), 0.10, 1.0)
ROUGH_final = np.clip(ROUGH + GRIME * 0.18 - chip_sharp * 0.36, 0.16, 0.96)

# Neutral grayscale detail albedo (~0.75 on clean armor so base_color * 1.33 = exact linear base_color!)
# Darkens in crevices/grime, subtly brightens on bare-metal bevels without washing flat panels white
base_luma = np.clip(
    (0.75 + (n_macro - 0.5) * 0.09 + (n_roll - 0.5) * 0.06)
    * (0.34 + 0.66 * AO_final)
    * (1.0 - GRIME * 0.32)
    + chip_sharp * 0.16,
    0.06, 1.0
)
alb = np.stack([base_luma, base_luma, base_luma], axis=-1)
ovr_a = COLOR_OVR[:, :, 3:4]
alb = alb * (1.0 - ovr_a) + (COLOR_OVR[:, :, :3] * (0.38 + 0.62 * AO_final[:, :, None])) * ovr_a
alb_u8 = np.clip(alb * 255.0, 0, 255).astype(np.uint8)
orm_u8 = np.clip(np.stack([AO_final, ROUGH_final, chip_sharp], axis=-1) * 255.0, 0, 255).astype(np.uint8)

Image.fromarray(alb_u8, "RGB").save(os.path.join(OUT_DIR, "mech_trim_a.png"), optimize=True)
Image.fromarray(norm_u8, "RGB").save(os.path.join(OUT_DIR, "mech_trim_n.png"), optimize=True)
Image.fromarray(orm_u8, "RGB").save(os.path.join(OUT_DIR, "mech_trim_orm.png"), optimize=True)

# ==============================================================================
# 2. GENERATE 512x512 MICRO-DETAIL NORMAL MAP (mech_detail_n.png)
#    Cast-steel micropitting + military CARC paint orange-peel grain
# ==============================================================================
DS = 512
d_coat = periodic_fbm(DS, ((24, 0.45), (64, 0.35), (144, 0.20)), seed=313)
d_roll = periodic_fbm(DS, ((18, 0.40), (72, 0.60)), seed=419, stretch_x=2.6)
d_pit = cellular_pitting(DS, 64, seed=521)
d_scr = periodic_fbm(DS, ((96, 0.70), (192, 0.30)), seed=617, stretch_x=6.0)
H_det = (d_coat - 0.5) * 0.055 + (d_roll - 0.5) * 0.035 - d_pit * 0.085 + np.clip(d_scr - 0.74, 0.0, 1.0) * 0.05
H_det_s = gaussian_filter(H_det, sigma=0.85, mode="wrap")
dgx = sobel(H_det_s, axis=1, mode="wrap") * 2.8
dgy = sobel(H_det_s, axis=0, mode="wrap") * 2.8
dnx, dny = -dgx, dgy
dnz = np.ones_like(H_det_s)
dnlen = np.sqrt(dnx * dnx + dny * dny + dnz * dnz) + 1e-6
det_u8 = np.clip(np.stack([dnx / dnlen * 0.5 + 0.5, dny / dnlen * 0.5 + 0.5, dnz / dnlen * 0.5 + 0.5], axis=-1) * 255.0, 0, 255).astype(np.uint8)
Image.fromarray(det_u8, "RGB").save(os.path.join(OUT_DIR, "mech_detail_n.png"), optimize=True)

# ==============================================================================
# 3. GENERATE 1024x512 TACTICAL STENCIL & MARKING ATLAS (mech_decal_a.png)
#    4x2 grid of 256x256 cells (UV cell (col, row): u = [col*0.25..(col+1)*0.25], v = [row*0.5..(row+1)*0.5])
#      (0,0) "17" unit stencil       (1,0) "54" unit stencil       (2,0) "08 // MK-IV"       (3,0) "12 // 30MM"
#      (0,1) Yellow Hazard Triangle  (1,1) Tactical Wing Chevron   (2,1) Hoist / CG Marker   (3,1) Exhaust Soot Ring
# ==============================================================================
DW, DH = 1024, 512
dec_img = Image.new("RGBA", (DW, DH), (0, 0, 0, 0))
dr = ImageDraw.Draw(dec_img)

font_paths = [
    r"C:\Windows\Fonts\bahnschrift.ttf",
    r"C:\Windows\Fonts\impact.ttf",
    r"C:\Windows\Fonts\arialbd.ttf",
]
font_path = next((p for p in font_paths if os.path.exists(p)), None)
f_big = ImageFont.truetype(font_path, 128) if font_path else ImageFont.load_default()
f_med = ImageFont.truetype(font_path, 76) if font_path else ImageFont.load_default()
f_sm = ImageFont.truetype(font_path, 26) if font_path else ImageFont.load_default()


def draw_centered_text(cx, cy, txt, font, fill, stroke=(24, 26, 28, 220), sw=3):
    bb = dr.textbbox((0, 0), txt, font=font, stroke_width=sw)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    dr.text((cx - tw // 2 - bb[0], cy - th // 2 - bb[1]), txt, font=font, fill=fill, stroke_fill=stroke, stroke_width=sw)


# Cell (0,0): B.o.T style "17" with tactical bar & stencil cuts
draw_centered_text(128, 118, "17", f_big, (236, 232, 218, 245))
dr.rectangle([58, 188, 198, 198], fill=(228, 162, 38, 240))
draw_centered_text(128, 218, "HVY // UNIT", f_sm, (220, 216, 204, 215), sw=2)

# Cell (1,0): "54" military unit stencil
draw_centered_text(256 + 128, 118, "54", f_big, (234, 230, 216, 245))
dr.rectangle([256 + 56, 42, 256 + 200, 50], fill=(234, 230, 216, 210))
draw_centered_text(256 + 128, 204, "VK-SERIES", f_sm, (228, 168, 42, 230), sw=2)

# Cell (2,0): "08" + technical spec block (like B.o.T weapon/shoulder hull)
draw_centered_text(512 + 92, 116, "08", f_med, (238, 234, 220, 245))
dr.rectangle([512 + 152, 74, 512 + 158, 162], fill=(232, 168, 38, 240))
dr.text((512 + 168, 76), "RHA-50\nLOT-4B\nNO STEP", font=f_sm, fill=(224, 220, 208, 225))
dr.rectangle([512 + 34, 184, 512 + 222, 194], fill=(232, 168, 38, 235))

# Cell (3,0): "12" + ordnance caliber warning
draw_centered_text(768 + 86, 112, "12", f_med, (238, 174, 44, 248))
dr.text((768 + 146, 78), "DANGER\n30MM\nAUTOCN", font=f_sm, fill=(236, 232, 218, 230))
dr.rectangle([768 + 34, 184, 768 + 222, 196], outline=(238, 174, 44, 235), width=4)

# Cell (0,1): B.o.T iconic Yellow-Black Hazard Triangle (seen on knees, turrets & shoulders!)
ox, oy = 0, 256
tri_outer = [(ox + 128, oy + 34), (ox + 224, oy + 206), (ox + 32, oy + 206)]
tri_inner = [(ox + 128, oy + 58), (ox + 202, oy + 194), (ox + 54, oy + 194)]
dr.polygon(tri_outer, fill=(24, 25, 28, 245))
dr.polygon(tri_inner, fill=(232, 172, 34, 248))
draw_centered_text(ox + 128, oy + 146, "!", f_med, (24, 25, 28, 250), stroke=(24, 25, 28, 0), sw=0)

# Cell (1,1): B.o.T weapon-pod top Yellow Diagonal Chevron Frame (strictly clipped inside cell [ox+24..ox+232])
ox, oy = 256, 256
cell_chevron = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
drc = ImageDraw.Draw(cell_chevron)
drc.rectangle([24, 38, 232, 218], outline=(232, 172, 34, 240), width=9)
stripe_box = Image.new("RGBA", (188, 66), (0, 0, 0, 0))
drs = ImageDraw.Draw(stripe_box)
for k in range(-2, 7):
    x_s = k * 38
    drs.polygon([(x_s, 0), (x_s + 20, 0), (x_s - 18, 66), (x_s - 38, 66)], fill=(232, 172, 34, 238))
cell_chevron.alpha_composite(stripe_box, (34, 48))
bb_c = drc.textbbox((0, 0), "CAUTION", font=f_sm, stroke_width=2)
drc.text((128 - (bb_c[2] - bb_c[0]) // 2 - bb_c[0], 166 - (bb_c[3] - bb_c[1]) // 2 - bb_c[1]),
         "CAUTION", font=f_sm, fill=(236, 230, 212, 235), stroke_fill=(24, 26, 28, 220), stroke_width=2)
dec_img.alpha_composite(cell_chevron, (ox, oy))

# Cell (2,1): Hoist Hook / Lift Point + CG Crosshair
ox, oy = 512, 256
dr.polygon([(ox + 128, oy + 36), (ox + 162, oy + 82), (ox + 94, oy + 82)], fill=(232, 172, 34, 245))
dr.ellipse([ox + 88, oy + 96, ox + 168, oy + 176], outline=(236, 232, 218, 235), width=7)
dr.pieslice([ox + 88, oy + 96, ox + 168, oy + 176], 0, 90, fill=(236, 232, 218, 225))
dr.pieslice([ox + 88, oy + 96, ox + 168, oy + 176], 180, 270, fill=(236, 232, 218, 225))
draw_centered_text(ox + 128, oy + 206, "LIFT // CG", f_sm, (232, 172, 34, 235), sw=2)

# Convert decal image to numpy to apply authentic chipped/weathered paint alpha & soot halo in Cell (3,1)
dec_arr = np.asarray(dec_img, dtype=np.float32) / 255.0
# Stencil cut-bridges + paint scrape erosion
w_n1 = periodic_fbm(DH, ((18, 0.5), (56, 0.5)), seed=811)
w_n2 = periodic_fbm(DH, ((96, 0.6), (220, 0.4)), seed=907)
w_full = np.concatenate([w_n1 * 0.5 + w_n2 * 0.5, np.roll(w_n1 * 0.5 + w_n2 * 0.5, 137, axis=0)], axis=1)
erode = np.clip((w_full - 0.26) * 2.6, 0.0, 1.0)
# Keep central text readable while chipping outer edges & random scratches
dec_arr[:, :768, 3] *= (0.42 + 0.58 * erode[:, :768])
dec_arr[:, :768, :3] *= (0.86 + 0.18 * w_full[:, :768, None])

# Cell (3,1): Exhaust / Muzzle Carbon Soot & Heat Scorch Halo
yy_s, xx_s = np.mgrid[0:256, 0:256].astype(np.float32)
rr_s = np.sqrt((xx_s - 128.0) ** 2 + (yy_s - 128.0) ** 2) / 112.0
soot_n = w_full[256:512, 768:1024]
soot_a = np.clip(1.0 - rr_s + (soot_n - 0.5) * 0.34, 0.0, 1.0) ** 1.7 * 0.88
warm_ring = np.exp(-((rr_s - 0.55) / 0.24) ** 2)
dec_arr[256:512, 768:1024, 0] = 0.04 + warm_ring * 0.18
dec_arr[256:512, 768:1024, 1] = 0.038 + warm_ring * 0.10
dec_arr[256:512, 768:1024, 2] = 0.035 + warm_ring * 0.05
dec_arr[256:512, 768:1024, 3] = soot_a

dec_u8 = np.clip(dec_arr * 255.0, 0, 255).astype(np.uint8)
Image.fromarray(dec_u8, "RGBA").save(os.path.join(OUT_DIR, "mech_decal_a.png"), optimize=True)

for fn in ["mech_trim_a.png", "mech_trim_n.png", "mech_trim_orm.png", "mech_detail_n.png", "mech_decal_a.png"]:
    kb = os.path.getsize(os.path.join(OUT_DIR, fn)) / 1024.0
    print(f"[trim_sheet v2] saved {fn}: {kb:.1f} KB")
