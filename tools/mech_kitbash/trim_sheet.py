"""
Generate a crisp 2048x2048 AAA Hard-Surface Mecha Industrial Trim Sheet:
  - mech_trim_a.png   : Neutral grayscale albedo detail + baked crevice darkening + bare-metal bevel edge wear + hazard band
  - mech_trim_n.png   : Crisp tangent-space normal map from exact mathematical heightfield
  - mech_trim_orm.png : R=AO, G=Roughness, B=Metallic boost
Bands (V=0 at top of image, V=1 at bottom of image — matching Godot/glTF standard UV):
  Band 0 (V 0.00..0.24): Heavy armored plates, machined beveled panel seams, recessed maintenance hatches, countersunk hex bolts
  Band 1 (V 0.24..0.42): Stamped structural ribs, flanged stiffener channels, oval lightening cutouts, perimeter rivets
  Band 2 (V 0.42..0.58): Deep angled radiator intake louvers (left half) + slotted perforated heat-shield grille (right half)
  Band 3 (V 0.58..0.72): Accordion hydraulic dust boot ridges (left) + braided steel cable weave (mid) + machined gear/knurl collar (right)
  Band 4 (V 0.72..0.84): Worn industrial hazard chevron stripe + bolted inspection plate strip + weld seams
  Band 5 (V 0.84..1.00): Cast-steel inner frame, CNC milled pockets, circular inspection ports, heavy hex bolt flange
"""
import os
import math
import numpy as np
from scipy.ndimage import gaussian_filter, sobel
from PIL import Image

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures"))
os.makedirs(OUT_DIR, exist_ok=True)
S = 2048

rng = np.random.default_rng(42)

# Multi-scale tileable procedural noise (for RHA rolled steel micro-grain & wear breakup)
def tile_noise(size, freq, seed=0):
    r = np.random.default_rng(seed)
    g = r.random((freq, freq), dtype=np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0

n_lo = tile_noise(S, 16, 11)
n_md = tile_noise(S, 64, 23)
n_hi = tile_noise(S, 256, 37)
# Fine directional rolled-steel grain
n_grain = tile_noise(S, 512, 51)
n_steel = 0.45 * n_lo + 0.35 * n_md + 0.20 * n_hi

# Buffers
H = np.full((S, S), 0.55, dtype=np.float32)       # Height [0..1]
AO = np.ones((S, S), dtype=np.float32)            # Ambient Occlusion [0..1]
ROUGH = np.full((S, S), 0.52, dtype=np.float32)   # Roughness [0..1]
METAL = np.zeros((S, S), dtype=np.float32)        # Extra metallic mask [0..1]
WEAR = np.zeros((S, S), dtype=np.float32)         # Bare-metal convex edge wear [0..1]
COLOR_OVR = np.zeros((S, S, 4), dtype=np.float32) # RGBA optional painted overlay (e.g. hazard chevrons)

# Add subtle rolled steel mill-scale micro-texture everywhere
H += (n_steel - 0.5) * 0.018 + (n_grain - 0.5) * 0.008
ROUGH += (n_steel - 0.5) * 0.16

def ypx(v): return int(round(v * S))
def xpx(u): return int(round(u * S))

def draw_groove_h(v, width_px=8, depth=0.32, u0=0.0, u1=1.0):
    yc = ypx(v)
    x0, x1 = xpx(u0), xpx(u1)
    half = max(2, width_px // 2)
    ys = np.arange(max(0, yc - half - 4), min(S, yc + half + 5))
    dist = np.abs(ys - yc).astype(np.float32)
    # V-beveled machined seam profile
    prof = np.clip(1.0 - dist / (half + 0.5), 0.0, 1.0)
    prof_smooth = prof * prof * (3.0 - 2.0 * prof)
    rim = np.exp(-((dist - (half + 2.0)) / 2.2) ** 2)
    H[ys, x0:x1] -= prof_smooth[:, None] * depth
    AO[ys, x0:x1] *= (1.0 - prof_smooth[:, None] * 0.72)
    ROUGH[ys, x0:x1] = np.maximum(ROUGH[ys, x0:x1], 0.55 + prof_smooth[:, None] * 0.40)
    WEAR[ys, x0:x1] = np.maximum(WEAR[ys, x0:x1], rim[:, None] * 0.78)

def draw_groove_v(u, width_px=8, depth=0.32, v0=0.0, v1=1.0):
    xc = xpx(u)
    y0, y1 = ypx(v0), ypx(v1)
    half = max(2, width_px // 2)
    xs = np.arange(max(0, xc - half - 4), min(S, xc + half + 5))
    dist = np.abs(xs - xc).astype(np.float32)
    prof = np.clip(1.0 - dist / (half + 0.5), 0.0, 1.0)
    prof_smooth = prof * prof * (3.0 - 2.0 * prof)
    rim = np.exp(-((dist - (half + 2.0)) / 2.2) ** 2)
    H[y0:y1, xs] -= prof_smooth[None, :] * depth
    AO[y0:y1, xs] *= (1.0 - prof_smooth[None, :] * 0.72)
    ROUGH[y0:y1, xs] = np.maximum(ROUGH[y0:y1, xs], 0.55 + prof_smooth[None, :] * 0.40)
    WEAR[y0:y1, xs] = np.maximum(WEAR[y0:y1, xs], rim[None, :] * 0.78)

def draw_bevel_rect(u0, v0, u1, v1, dh=0.14, bev_px=10, metallic_rim=0.55):
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
        AO[y0:y1, x0:x1] *= (1.0 - ramp * 0.48)
        ROUGH[y0:y1, x0:x1] = np.maximum(ROUGH[y0:y1, x0:x1], 0.62 + ramp * 0.25)
    else:
        # Raised beveled plate: subtle contact shadow just outside, edge wear on bevel crest!
        rim = np.exp(-((d - bev_px * 0.85) / 2.6) ** 2)
        WEAR[y0:y1, x0:x1] = np.maximum(WEAR[y0:y1, x0:x1], rim * metallic_rim)
        outer_ao = np.exp(-(d / 3.2) ** 2) * 0.38
        AO[y0:y1, x0:x1] *= (1.0 - outer_ao)

def draw_bolt(u, v, rad_px=10, countersunk=True):
    cx, cy = xpx(u), ypx(v)
    r_pad = rad_px + 8
    y0, y1 = max(0, cy - r_pad), min(S, cy + r_pad + 1)
    x0, x1 = max(0, cx - r_pad), min(S, cx + r_pad + 1)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    dx = (xx - cx).astype(np.float32)
    dy = (yy - cy).astype(np.float32)
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    # Hex distance function
    hex_r = r * np.cos((np.mod(ang + math.pi / 6.0, math.pi / 3.0)) - math.pi / 6.0)

    if countersunk:
        # Recessed circular pocket
        pocket = np.clip(1.0 - (r - rad_px * 0.95) / 4.0, 0.0, 1.0)
        H[y0:y1, x0:x1] -= pocket * 0.22
        AO[y0:y1, x0:x1] *= (1.0 - pocket * 0.65)
        # Raised hex bolt head inside pocket
        head = np.clip(1.0 - (hex_r - rad_px * 0.58) / 2.2, 0.0, 1.0)
        H[y0:y1, x0:x1] += head * 0.26
        # Inner socket recess
        sock = np.clip(1.0 - (r - rad_px * 0.24) / 1.5, 0.0, 1.0)
        H[y0:y1, x0:x1] -= sock * 0.14
        AO[y0:y1, x0:x1] *= (1.0 - sock * 0.55)
        METAL[y0:y1, x0:x1] = np.maximum(METAL[y0:y1, x0:x1], head * 0.85)
        ROUGH[y0:y1, x0:x1] = np.where(head > 0.3, 0.24, ROUGH[y0:y1, x0:x1])
        WEAR[y0:y1, x0:x1] = np.maximum(WEAR[y0:y1, x0:x1], head * 0.55)
    else:
        head = np.clip(1.0 - (hex_r - rad_px * 0.72) / 2.5, 0.0, 1.0)
        H[y0:y1, x0:x1] += head * 0.22
        ring_ao = np.exp(-((r - rad_px * 0.95) / 2.5) ** 2)
        AO[y0:y1, x0:x1] *= (1.0 - ring_ao * 0.45)
        METAL[y0:y1, x0:x1] = np.maximum(METAL[y0:y1, x0:x1], head * 0.85)
        ROUGH[y0:y1, x0:x1] = np.where(head > 0.3, 0.26, ROUGH[y0:y1, x0:x1])
        WEAR[y0:y1, x0:x1] = np.maximum(WEAR[y0:y1, x0:x1], head * 0.50)

# ==============================================================================
# BAND 0 (V 0.00..0.24): HEAVY RHA ARMOR PANELS, SEAMS, HATCHES & COUNTERSUNK BOLTS
# ==============================================================================
draw_groove_h(0.004, 10, 0.34)
draw_groove_h(0.238, 10, 0.34)
draw_groove_h(0.120, 8, 0.28)
for u in [0.0, 0.25, 0.50, 0.75]:
    draw_groove_v(u + 0.002, 8, 0.30, 0.0, 0.24)
# Upper sub-row: Raised beveled applique armor panels with perimeter countersunk hex bolts
for i in range(4):
    u0 = i * 0.25 + 0.016
    u1 = (i + 1) * 0.25 - 0.016
    draw_bevel_rect(u0, 0.018, u1, 0.104, dh=0.11, bev_px=11, metallic_rim=0.72)
    # Recessed inner latch/inspection slot on alternating panels
    if i % 2 == 0:
        draw_bevel_rect(u0 + 0.055, 0.042, u1 - 0.055, 0.080, dh=-0.10, bev_px=6)
        draw_bevel_rect(u0 + 0.080, 0.052, u1 - 0.080, 0.070, dh=0.07, bev_px=4, metallic_rim=0.6)
    else:
        # Welded twin reinforcement strips
        for sv in [0.036, 0.072]:
            draw_bevel_rect(u0 + 0.025, sv, u1 - 0.025, sv + 0.016, dh=0.07, bev_px=4, metallic_rim=0.65)
    for bu in np.linspace(u0 + 0.016, u1 - 0.016, 4):
        draw_bolt(bu, 0.028, 8, True)
        draw_bolt(bu, 0.094, 8, True)
# Lower sub-row (V 0.12..0.24): Maintenance access hatches + diagonal service seams + bolt rows
for i in range(4):
    u0 = i * 0.25 + 0.012
    u1 = (i + 1) * 0.25 - 0.012
    draw_bevel_rect(u0, 0.132, u1, 0.226, dh=0.06, bev_px=8, metallic_rim=0.58)
    # Recessed rectangular access door
    draw_bevel_rect(u0 + 0.028, 0.148, u1 - 0.028, 0.210, dh=-0.06, bev_px=5)
    draw_bevel_rect(u0 + 0.036, 0.155, u1 - 0.036, 0.203, dh=0.09, bev_px=6, metallic_rim=0.68)
    # Recessed D-ring latch pocket on right side of hatch
    draw_bevel_rect(u1 - 0.066, 0.170, u1 - 0.044, 0.188, dh=-0.12, bev_px=4)
    for bu in [u0 + 0.014, u1 - 0.014]:
        for bv in [0.144, 0.179, 0.214]:
            draw_bolt(bu, bv, 7, True)

# ==============================================================================
# BAND 1 (V 0.24..0.42): STAMPED STRUCTURAL RIBS, FLANGES & LIGHTENING POCKETS
# ==============================================================================
draw_groove_h(0.418, 10, 0.34)
# Horizontal stamped stiffening ribs along full strip (V 0.25..0.33)
for rv in [0.258, 0.282, 0.306]:
    draw_bevel_rect(0.008, rv, 0.992, rv + 0.016, dh=0.16, bev_px=7, metallic_rim=0.78)
for bu in np.linspace(0.02, 0.98, 24):
    draw_bolt(bu, 0.248, 6, False)
    draw_bolt(bu, 0.332, 6, False)
# Lower half (V 0.34..0.415): Recessed CNC structural lightening pockets with raised borders
for i in range(8):
    u0 = i * 0.125 + 0.012
    u1 = (i + 1) * 0.125 - 0.012
    draw_bevel_rect(u0, 0.346, u1, 0.408, dh=0.08, bev_px=6, metallic_rim=0.62)
    draw_bevel_rect(u0 + 0.014, 0.358, u1 - 0.014, 0.396, dh=-0.22, bev_px=8)
    draw_bolt(u0 + 0.006, 0.377, 5, True)
    draw_bolt(u1 - 0.006, 0.377, 5, True)

# ==============================================================================
# BAND 2 (V 0.42..0.58): RADIATOR INTAKE LOUVERS (LEFT) + HEAT-SHIELD PERFORATIONS (RIGHT)
# ==============================================================================
draw_groove_h(0.578, 10, 0.34)
# Left half (U 0.0..0.50): 14 deeply sloped high-contrast armored intake louvers
y0, y1 = ypx(0.426), ypx(0.572)
x0, x1 = xpx(0.012), xpx(0.488)
yy = np.arange(y0, y1, dtype=np.float32)
period = (y1 - y0) / 14.0
phase = np.mod(yy - y0, period) / period  # 0..1 per louver blade
# Sawtooth blade height: sharp deep intake gap at phase 0..0.28, rising armored blade 0.28..0.92, chamfer drop
blade_h = np.where(phase < 0.26, -0.36, -0.36 + ((phase - 0.26) / 0.66) * 0.54)
blade_h = np.where(phase > 0.92, 0.18 - ((phase - 0.92) / 0.08) * 0.54, blade_h)
blade_ao = np.where(phase < 0.32, 0.16, 0.30 + ((phase - 0.32) / 0.68) * 0.70)
H[y0:y1, x0:x1] = 0.55 + blade_h[:, None]
AO[y0:y1, x0:x1] = blade_ao[:, None]
ROUGH[y0:y1, x0:x1] = np.where(phase < 0.32, 0.94, 0.38)[:, None]
WEAR[y0:y1, x0:x1] = np.where((phase > 0.84) & (phase < 0.94), 0.72, 0.0)[:, None]
# Vertical structural divider bars across louvers
for du in [0.17, 0.33]:
    draw_bevel_rect(du - 0.010, 0.424, du + 0.010, 0.574, dh=0.22, bev_px=5, metallic_rim=0.75)

# Right half (U 0.50..1.00): Perforated armored heat-shield grille (staggered deep circular/slotted holes)
rx0, rx1 = xpx(0.512), xpx(0.988)
yy2, xx2 = np.mgrid[y0:y1, rx0:rx1]
gx = (xx2 - rx0).astype(np.float32) / 28.0
gy = (yy2 - y0).astype(np.float32) / 24.0
row_idx = np.floor(gy)
gx = gx + np.mod(row_idx, 2.0) * 0.5
fx = np.mod(gx, 1.0) - 0.5
fy = np.mod(gy, 1.0) - 0.5
rad = np.sqrt((fx * 1.0) ** 2 + (fy * 1.0) ** 2)
hole = np.clip(1.0 - (rad - 0.28) / 0.09, 0.0, 1.0)
rim_h = np.exp(-((rad - 0.38) / 0.06) ** 2)
H[y0:y1, rx0:rx1] -= hole * 0.42
AO[y0:y1, rx0:rx1] *= (1.0 - hole * 0.86)
ROUGH[y0:y1, rx0:rx1] = np.where(hole > 0.4, 0.96, 0.40)
METAL[y0:y1, rx0:rx1] = np.where(hole < 0.3, 0.55, 0.0)
WEAR[y0:y1, rx0:rx1] = np.maximum(WEAR[y0:y1, rx0:rx1], rim_h * 0.65)

# ==============================================================================
# BAND 3 (V 0.58..0.72): DUST BOOT BELLOWS / BRAIDED HOSE / MACHINED KNURL GEAR
# ==============================================================================
draw_groove_h(0.718, 10, 0.34)
y0, y1 = ypx(0.584), ypx(0.714)
# Left (U 0.0..0.34): Deep accordion rubber dust boot corrugations
x0, x1 = xpx(0.0), xpx(0.34)
yy = np.arange(y0, y1, dtype=np.float32)
bellows = np.sin((yy - y0) / (y1 - y0) * math.tau * 10.0)
H[y0:y1, x0:x1] = 0.52 + bellows[:, None] * 0.28
AO[y0:y1, x0:x1] = 0.42 + (bellows[:, None] * 0.5 + 0.5) * 0.58
ROUGH[y0:y1, x0:x1] = 0.78 - (bellows[:, None] * 0.5 + 0.5) * 0.22
# Mid (U 0.34..0.68): Braided stainless hydraulic hose mesh
x0, x1 = xpx(0.34), xpx(0.68)
yy2, xx2 = np.mgrid[y0:y1, x0:x1]
w1 = np.sin((xx2 + yy2) * 0.32)
w2 = np.sin((xx2 - yy2) * 0.32)
braid = np.maximum(w1, w2) * 0.5 + 0.5
H[y0:y1, x0:x1] = 0.48 + braid * 0.16
AO[y0:y1, x0:x1] = 0.45 + braid * 0.55
METAL[y0:y1, x0:x1] = 0.72
ROUGH[y0:y1, x0:x1] = 0.34
# Right (U 0.68..1.00): Precision machined slewing gear teeth / knurled collar
x0, x1 = xpx(0.68), xpx(1.0)
xx = np.arange(x0, x1, dtype=np.float32)
teeth = np.clip(np.sin((xx - x0) / (x1 - x0) * math.tau * 24.0) * 2.2, -1.0, 1.0)
H[y0:y1, x0:x1] = 0.52 + teeth[None, :] * 0.24
AO[y0:y1, x0:x1] = 0.35 + (teeth[None, :] * 0.5 + 0.5) * 0.65
METAL[y0:y1, x0:x1] = 0.80
ROUGH[y0:y1, x0:x1] = 0.32
WEAR[y0:y1, x0:x1] = np.maximum(WEAR[y0:y1, x0:x1], np.clip(teeth[None, :], 0.0, 1.0) * 0.55)

# ==============================================================================
# BAND 4 (V 0.72..0.84): WORN HAZARD CHEVRON BAND + BOLTED TRIM STRIP
# ==============================================================================
draw_groove_h(0.838, 10, 0.34)
y0, y1 = ypx(0.728), ypx(0.830)
x0, x1 = xpx(0.0), xpx(0.50)
yy2, xx2 = np.mgrid[y0:y1, x0:x1]
chev = np.mod((xx2 + yy2) / 64.0, 1.0)
is_yel = (chev < 0.52).astype(np.float32)
# Chipped worn paint mask
chip = (n_steel[y0:y1, x0:x1] * 0.65 + n_hi[y0:y1, x0:x1] * 0.35)
paint_a = np.clip((chip - 0.16) * 4.5, 0.0, 1.0)
COLOR_OVR[y0:y1, x0:x1, 0] = is_yel * 0.78 + (1.0 - is_yel) * 0.08
COLOR_OVR[y0:y1, x0:x1, 1] = is_yel * 0.58 + (1.0 - is_yel) * 0.085
COLOR_OVR[y0:y1, x0:x1, 2] = is_yel * 0.14 + (1.0 - is_yel) * 0.095
COLOR_OVR[y0:y1, x0:x1, 3] = paint_a * 0.92
# Right half (U 0.50..1.00): Bolted heavy flange strip with weld beads
draw_bevel_rect(0.51, 0.734, 0.99, 0.824, dh=0.10, bev_px=8, metallic_rim=0.70)
for bu in np.linspace(0.535, 0.965, 12):
    draw_bolt(bu, 0.779, 9, False)

# ==============================================================================
# BAND 5 (V 0.84..1.00): CAST-STEEL INNER FRAME, MILLED POCKETS & INSPECTION PORTS
# ==============================================================================
for i in range(6):
    u0 = i / 6.0 + 0.010
    u1 = (i + 1) / 6.0 - 0.010
    draw_bevel_rect(u0, 0.852, u1, 0.986, dh=0.09, bev_px=8, metallic_rim=0.60)
    if i % 2 == 0:
        # Deep CNC pocket + diagonal rib
        draw_bevel_rect(u0 + 0.018, 0.870, u1 - 0.018, 0.968, dh=-0.20, bev_px=8)
    else:
        # Circular bolted inspection port
        cx, cy = xpx((u0 + u1) * 0.5), ypx(0.919)
        r_p = 74
        py0, py1 = cy - r_p - 12, cy + r_p + 12
        px0, px1 = cx - r_p - 12, cx + r_p + 12
        yy2, xx2 = np.mgrid[py0:py1, px0:px1]
        rr = np.sqrt((xx2 - cx).astype(np.float32) ** 2 + (yy2 - cy).astype(np.float32) ** 2)
        ring = np.exp(-((rr - r_p * 0.78) / 9.0) ** 2)
        well = np.clip(1.0 - (rr - r_p * 0.58) / 5.0, 0.0, 1.0)
        H[py0:py1, px0:px1] += ring * 0.18 - well * 0.16
        AO[py0:py1, px0:px1] *= (1.0 - well * 0.42)
        WEAR[py0:py1, px0:px1] = np.maximum(WEAR[py0:py1, px0:px1], ring * 0.70)
        for bi in range(6):
            ba = math.tau * bi / 6.0
            draw_bolt((u0 + u1) * 0.5 + math.cos(ba) * 0.036, 0.919 + math.sin(ba) * 0.036, 5, False)

# ==============================================================================
# SYNTHESIZE FINAL MAPS: NORMAL, ALBEDO DETAIL, ORM
# ==============================================================================
# Smooth tiny aliasing slightly before Sobel normal extraction
H_s = gaussian_filter(H, sigma=0.65)
gx = sobel(H_s, axis=1) * 3.8
gy = sobel(H_s, axis=0) * 3.8
# OpenGL/Godot tangent-space normal (+X right, +Y up -> invert image Y gradient)
nx = -gx
ny = gy
nz = np.ones_like(H_s)
nlen = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
nx /= nlen; ny /= nlen; nz /= nlen
norm_rgb = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1)
norm_u8 = np.clip(norm_rgb * 255.0, 0, 255).astype(np.uint8)

# Modulated wear breakup with noise so edge wear looks realistically chipped, not drawn with a ruler
wear_broken = np.clip(WEAR * (0.45 + 0.85 * n_hi) * (0.65 + 0.55 * n_md), 0.0, 1.0)
AO = np.clip(AO, 0.14, 1.0)
ROUGH = np.clip(ROUGH - wear_broken * 0.34, 0.16, 0.98)
METAL = np.clip(np.maximum(METAL, wear_broken * 0.82), 0.0, 1.0)

# Neutral grayscale detail albedo (around 0.78 on flat armor so tinting works cleanly, bright on bare-metal wear, dark in grooves)
base_luma = np.clip((0.76 + (n_steel - 0.5) * 0.12) * (0.38 + 0.62 * AO) + wear_broken * 0.24, 0.08, 1.0)
alb = np.stack([base_luma, base_luma, base_luma], axis=-1)
# Blend optional painted hazard band
ovr_a = COLOR_OVR[:, :, 3:4]
alb = alb * (1.0 - ovr_a) + (COLOR_OVR[:, :, :3] * (0.45 + 0.55 * AO[:, :, None])) * ovr_a
alb_u8 = np.clip(alb * 255.0, 0, 255).astype(np.uint8)

orm = np.stack([AO, ROUGH, METAL], axis=-1)
orm_u8 = np.clip(orm * 255.0, 0, 255).astype(np.uint8)

Image.fromarray(alb_u8, "RGB").save(os.path.join(OUT_DIR, "mech_trim_a.png"), optimize=True)
Image.fromarray(norm_u8, "RGB").save(os.path.join(OUT_DIR, "mech_trim_n.png"), optimize=True)
Image.fromarray(orm_u8, "RGB").save(os.path.join(OUT_DIR, "mech_trim_orm.png"), optimize=True)

for fn in ["mech_trim_a.png", "mech_trim_n.png", "mech_trim_orm.png"]:
    kb = os.path.getsize(os.path.join(OUT_DIR, fn)) / 1024.0
    print(f"[trim_sheet] saved {fn}: {kb:.1f} KB")
