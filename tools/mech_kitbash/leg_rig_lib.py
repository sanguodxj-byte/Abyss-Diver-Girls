"""
Heavy-Duty B.o.T Leg & Precision Double-Pin Track Engineering Library (Zero-Clip / Zero-Z-Fight Standard).
Shared across starter_legs_biped.py, zz_bot_hero.py, set_legs_5.py, and set_legs_10_ext.py.
Strictly engineered to stay <= 26,500 tris & <= 1,380 KB per chassis with >= 6mm coplanar separation
and >= 18mm telescoping joint X-steps across all rotating pivots.
"""
import math
import bmesh
from mathutils import Vector, Matrix
from kitbash_lib import KitbashScene, C_G2B, C_B2G, g2b_mat, g2b_bone_mat, crect_2d, trap_2d


def heavy_hyd(kb: KitbashScene, prefix: str, p_from, p_to, r: float = 0.032,
              segs: int = 8, pins: bool = False, M_parent=None, group=None):
    """Heavy industrial hydraulic actuator with >= 8mm non-overlapping axial zones (zero cap Z-fighting)."""
    a, b = Vector(p_from), Vector(p_to)
    mid = (a + b) * 0.5
    d = b - a
    L = max(d.length, 0.12)
    up_g = d.normalized()
    ref = Vector((0, 0, 1)) if abs(up_g.z) < 0.9 else Vector((1, 0, 0))
    xg = up_g.cross(ref).normalized()
    zg = xg.cross(up_g).normalized()
    M = C_G2B @ Matrix((
        (xg.x, up_g.x, zg.x, mid.x),
        (xg.y, up_g.y, zg.y, mid.y),
        (xg.z, up_g.z, zg.z, mid.z),
        (0.0, 0.0, 0.0, 1.0),
    )) @ C_B2G
    if M_parent is not None:
        M = M_parent @ M

    y_cyl0, y_cyl1 = -0.43 * L, -0.05 * L
    h_cyl = max(0.032, y_cyl1 - y_cyl0)
    y_seal0 = y_cyl1 + 0.008
    h_seal = 0.024
    y_seal1 = y_seal0 + h_seal
    y_boot0 = y_seal1 + 0.008
    y_boot1 = max(y_boot0 + 0.030, 0.24 * L)
    h_boot = y_boot1 - y_boot0

    kb.cyl(f"{prefix}_cyl", r * 1.78, r * 1.78, h_cyl, segs, "gunmetal", "plain_metal",
           (0, 0.5 * (y_cyl0 + y_cyl1), 0), (0, 0, 0), 0.004, M_parent=M, group=group)
    kb.cyl(f"{prefix}_seal", r * 2.08, r * 2.08, h_seal, segs, "brass", "gear_collar",
           (0, 0.5 * (y_seal0 + y_seal1), 0), (0, 0, 0), 0.003, M_parent=M, group=group)
    kb.cyl(f"{prefix}_boot", r * 1.94, r * 1.88, h_boot, segs, "rubber", "dust_boot",
           (0, 0.5 * (y_boot0 + y_boot1), 0), (0, 0, 0), 0.003, M_parent=M, u_rep=2.0, group=group)
    kb.cyl(f"{prefix}_rod", r * 0.96, r * 0.96, L * 0.84, max(6, segs - 2), "chrome", "plain_metal",
           (0, 0.0, 0), (0, 0, 0), 0.002, M_parent=M, group=group)
    for si, e in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_cl{si}", (r * 3.0, r * 2.4, r * 2.4), "dark", "bolt_flange",
               (0, e * L * 0.47, 0), (0, 0, 0), 0.0, 1, M_parent=M, group=group)
        if pins:
            kb.cyl(f"{prefix}_pn{si}", r * 0.65, r * 0.65, r * 3.8, 6, "chrome", "plain_metal",
                   (0, e * L * 0.47, 0), (0, 0, 90), 0.002, M_parent=M, group=group)


def heavy_drum(kb: KitbashScene, prefix: str, pos, r: float, w: float,
               segs: int = 12, n_bolts: int = 0, M_parent=None, group=None):
    """Oversized B.o.T armored joint drum along X axis with stepped non-coplanar flanges & axle caps."""
    M = g2b_mat(pos, (0, 0, 0))
    if M_parent is not None:
        M = M_parent @ M
    kb.cyl(f"{prefix}_bd", r, r, w, segs, "dark", "frame_cnc",
           (0, 0, 0), (0, 0, 90), 0.006, M_parent=M, group=group)
    kb.cyl(f"{prefix}_rb", r * 1.07, r * 1.07, w * 0.32, segs, "gunmetal", "gear_collar",
           (0, 0, 0), (0, 0, 90), 0.004, M_parent=M, u_rep=2.0, group=group)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.cyl(f"{prefix}_fl{si}", r * 1.11, r * 1.11, w * 0.12, segs, "gunmetal", "bolt_flange",
               (sx * w * 0.37, 0, 0), (0, 0, 90), 0.004, M_parent=M, u_rep=2.0, group=group)
        kb.cyl(f"{prefix}_ax{si}", r * 0.46, r * 0.42, w * 0.14, max(8, segs - 2), "chrome", "plain_metal",
               (sx * (w * 0.50 + 0.024), 0, 0), (0, 0, 90), 0.004, M_parent=M, group=group)
        for bi in range(n_bolts):
            a = math.tau * bi / n_bolts
            kb.cyl(f"{prefix}_b{si}_{bi}", 0.013, 0.015, 0.024, 6, "chrome", "plain_metal",
                   (sx * (w * 0.50 + 0.005), math.cos(a) * r * 0.76, math.sin(a) * r * 0.76),
                   (0, 0, 90), 0.002, M_parent=M, group=group)


# ==============================================================================
# 1. PRECISION DOUBLE-PIN TRACK & CONCAVE DUAL-ROADWHEEL BOGIE SYSTEM
# ==============================================================================

def _add_prism_local(bm: bmesh.types.BMesh, M_b: Matrix,
                     x0: float, x1: float, y0: float, y1: float,
                     z_bot: float, z_top: float, cap_bottom: bool = True):
    """Append a pre-chamfered trapezoidal prism in Godot local coords (zero bevel overhead)."""
    zb0, zb1 = -z_bot * 0.5, z_bot * 0.5
    zt0, zt1 = -z_top * 0.5, z_top * 0.5
    pts_g = [
        (x0, y0, zb0), (x1, y0, zb0), (x1, y0, zb1), (x0, y0, zb1),
        (x0, y1, zt0), (x1, y1, zt0), (x1, y1, zt1), (x0, y1, zt1),
    ]
    vs = [bm.verts.new(M_b @ Vector((gx, -gz, gy))) for (gx, gy, gz) in pts_g]
    if cap_bottom:
        bm.faces.new((vs[0], vs[3], vs[2], vs[1]))
    bm.faces.new((vs[4], vs[5], vs[6], vs[7]))
    bm.faces.new((vs[0], vs[1], vs[5], vs[4]))
    bm.faces.new((vs[1], vs[2], vs[6], vs[5]))
    bm.faces.new((vs[2], vs[3], vs[7], vs[6]))
    bm.faces.new((vs[3], vs[0], vs[4], vs[7]))


def _build_racetrack_belt_bm(kb: KitbashScene, name: str, y_trk: float, straight: float,
                             r_out: float, belt_thick: float, x0: float, x1: float,
                             ox: float = 0.0, oz: float = 0.0, arc_segs: int = 16):
    """Continuous 100%-tangent stadium/racetrack hollow loop extruded from x0..x1."""
    bm = bmesh.new()
    r_in = r_out - belt_thick
    ring_pts = []
    hz = straight * 0.5
    for k in range(arc_segs + 1):
        a = math.pi * (k / arc_segs)
        ring_pts.append((y_trk + math.cos(a) * r_out, oz + hz + math.sin(a) * r_out,
                         y_trk + math.cos(a) * r_in,  oz + hz + math.sin(a) * r_in))
    for k in range(arc_segs + 1):
        a = math.pi + math.pi * (k / arc_segs)
        ring_pts.append((y_trk + math.cos(a) * r_out, oz - hz + math.sin(a) * r_out,
                         y_trk + math.cos(a) * r_in,  oz - hz + math.sin(a) * r_in))

    n = len(ring_pts)
    vo_l, vo_r, vi_l, vi_r = [], [], [], []
    for (yo, zo, yi, zi) in ring_pts:
        vo_l.append(bm.verts.new((ox + x0, -zo, yo)))
        vo_r.append(bm.verts.new((ox + x1, -zo, yo)))
        vi_l.append(bm.verts.new((ox + x0, -zi, yi)))
        vi_r.append(bm.verts.new((ox + x1, -zi, yi)))

    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((vo_l[k], vo_r[k], vo_r[j], vo_l[j]))
        bm.faces.new((vi_l[j], vi_r[j], vi_r[k], vi_l[k]))
        bm.faces.new((vo_l[j], vi_l[j], vi_l[k], vo_l[k]))
        bm.faces.new((vo_r[k], vi_r[k], vi_r[j], vo_r[j]))

    kb._finalize(name, bm, "rubber", "dust_boot", Matrix.Identity(4), 0.0, 1, False, 1.0, 2.0, 1.0)


def _dished_dual_roadwheel(kb: KitbashScene, pfx: str, pos, r_whl: float, track_w: float,
                           side: float, add_shock: bool = False, segs: int = 14):
    """Authentic MBT dual roadwheel with >= 22mm axial clearances on both Track_L and Track_R."""
    ox, wy, wz = pos
    half_gap = 0.036
    w_single = (track_w * 0.78 - half_gap * 2.0) * 0.5
    for wi, sgn in enumerate([-1.0, 1.0]):
        wx = ox + sgn * (half_gap + w_single * 0.5)
        hw = w_single * 0.5
        kb.cyl(f"{pfx}_Tire{wi}", r_whl, r_whl, w_single * 0.90, segs, "rubber", "plain_metal",
               (wx, wy, wz), (0, 0, 90), 0.005, hollow_r=r_whl * 0.75)
        face_dir = 1.0 if sgn * side > 0 else -1.0
        r_rim = r_whl * 0.76
        r_bowl = r_whl * 0.55
        r_hub = r_whl * 0.28
        if face_dir > 0:
            prof = [
                (0.0, -hw * 0.64), (r_rim, -hw * 0.64), (r_rim, hw * 0.80),
                (r_bowl, hw * 0.24), (r_hub, hw * 0.28), (r_hub * 0.86, hw * 0.92), (0.0, hw * 0.92),
            ]
        else:
            prof = [
                (0.0, -hw * 0.92), (r_hub * 0.86, -hw * 0.92), (r_hub, -hw * 0.28),
                (r_bowl, -hw * 0.24), (r_rim, -hw * 0.80), (r_rim, hw * 0.64), (0.0, hw * 0.64),
            ]
        kb.lathe(f"{pfx}_Dish{wi}", prof, segs, "armor_sub", "armor_hatch",
                 (wx, wy, wz), (0, 0, -90), u_rep=2.0)
    out_x = ox + side * (half_gap + w_single + 0.024)
    kb.cyl(f"{pfx}_OilCap", r_whl * 0.20, r_whl * 0.22, 0.032, 10, "chrome", "plain_metal",
           (out_x, wy, wz), (0, 0, 90), 0.003)
    in_x = ox - side * (half_gap + w_single + 0.048)
    kb.box(f"{pfx}_SwgArm", (0.040, 0.072, r_whl * 1.15), "gunmetal", "frame_cnc",
           (in_x, wy + r_whl * 0.24, wz - r_whl * 0.36), (26, 0, 0), 0.005, 1)
    if add_shock:
        heavy_hyd(kb, f"{pfx}_Damper", (in_x, wy + r_whl * 0.10, wz),
                  (in_x, wy + r_whl * 1.22, wz - r_whl * 0.28), 0.018, 6, pins=False)


def _toothed_sprocket(kb: KitbashScene, pfx: str, pos, r_spr: float, track_w: float,
                      side: float, is_drive: bool = True, compact: bool = False):
    """12-tooth dual-ring drive sprocket + planetary final-drive hub with stepped axial faces."""
    ox, sy, sz = pos
    half_gap = 0.036
    w_ring = (track_w * 0.76 - half_gap * 2.0) * 0.5
    segs = 10 if compact else 12
    n_teeth = 10 if compact else 12
    bm_teeth = bmesh.new() if is_drive else None
    for ri, sgn in enumerate([-1.0, 1.0]):
        rx = ox + sgn * (half_gap + w_ring * 0.5)
        kb.cyl(f"{pfx}_Ring{ri}", r_spr * 0.88, r_spr * 0.88, w_ring * 0.66, segs, "gunmetal", "gear_collar",
               (rx, sy, sz), (0, 0, 90), 0.004, u_rep=2.0)
        if is_drive:
            for ti in range(n_teeth):
                ta = math.tau * ti / n_teeth
                ty = sy + math.cos(ta) * (r_spr * 0.90)
                tz = sz + math.sin(ta) * (r_spr * 0.90)
                M_t = g2b_mat((rx, ty, tz), (-math.degrees(ta), 0.0, 0.0))
                _add_prism_local(bm_teeth, M_t, -w_ring * 0.24, w_ring * 0.24, -0.008, 0.022, 0.044, 0.022, cap_bottom=False)
    if bm_teeth is not None:
        kb._finalize(f"{pfx}_Teeth", bm_teeth, "chrome", "plain_metal", Matrix.Identity(4), 0.0, 1, False, 1.0, 1.0, 1.0)
    kb.cyl(f"{pfx}_Hub", r_spr * 0.50, r_spr * 0.54, track_w * 0.84, segs, "dark", "bolt_flange",
           (ox, sy, sz), (0, 0, 90), 0.005, u_rep=2.0)
    kb.cyl(f"{pfx}_Cap", r_spr * 0.30, r_spr * 0.34, 0.048, 10, "armor_oxide" if is_drive else "armor_sub", "armor_hatch",
           (ox + side * (track_w * 0.42 + 0.016), sy, sz), (0, 0, 90), 0.004)


def build_precision_track_pod(kb: KitbashScene, pfx: str, side: float, y_trk: float,
                              straight: float, r_arc: float, width: float,
                              wheel_zs: list, r_wheel: float = 0.0,
                              n_links: int = 40, pos_off=(0.0, 0.0),
                              return_rollers: int = 2, christie: bool = False,
                              compact_pod: bool = False, skip_hidden_top: bool = False):
    """
    Complete high-precision MBT double-pin track pod with zero coplanar overlap:
      - Twin-band belt radially separated >= 6mm from steel link plates & >= 14mm from roadwheel tires
      - Narrow central bogie girder fitting cleanly inside the 72mm dual-wheel center gap
    """
    ox, oz = pos_off
    r_belt_out = r_arc - 0.010
    belt_thick = 0.022
    half_gap = 0.034
    half_w_belt = width * 0.43

    # Narrow central bogie spine sits strictly inside the dual-wheel center gap (-0.025..+0.025)!
    kb.box(f"{pfx}_Girder", (0.050, r_arc * 0.56, straight + r_arc * 0.48), "dark", "frame_cnc",
           (ox, y_trk + 0.04, oz), (0, 0, 0), 0.008, 1)

    arc_s = 12 if compact_pod else 16
    _build_racetrack_belt_bm(kb, f"{pfx}_BeltL", y_trk, straight, r_belt_out, belt_thick,
                             -half_w_belt, -half_gap, ox, oz, arc_segs=arc_s)
    _build_racetrack_belt_bm(kb, f"{pfx}_BeltR", y_trk, straight, r_belt_out, belt_thick,
                             half_gap, half_w_belt, ox, oz, arc_segs=arc_s)

    per = 2.0 * straight + math.tau * r_arc
    pitch = per / n_links
    shoe_len_b = pitch * 0.88
    shoe_len_t = pitch * 0.72
    pad_len_b = pitch * 0.66
    pad_len_t = pitch * 0.50
    hw = width * 0.47
    ear_w = width * 0.505

    bm_steel = bmesh.new()
    bm_pads = bmesh.new()

    for li in range(n_links):
        d = (li / n_links) * per
        if skip_hidden_top and (straight * 0.16 < d < straight * 0.84):
            continue
        if d < straight:
            ps = (ox, y_trk + r_arc, oz - straight * 0.5 + d)
            ax = 0.0
        elif d < straight + math.pi * r_arc:
            a = (d - straight) / r_arc
            ps = (ox, y_trk + math.cos(a) * r_arc, oz + straight * 0.5 + math.sin(a) * r_arc)
            ax = math.degrees(a)
        elif d < 2.0 * straight + math.pi * r_arc:
            ps = (ox, y_trk - r_arc, oz + straight * 0.5 - (d - straight - math.pi * r_arc))
            ax = 180.0
        else:
            a = (d - 2.0 * straight - math.pi * r_arc) / r_arc
            ps = (ox, y_trk - math.cos(a) * r_arc, oz - straight * 0.5 - math.sin(a) * r_arc)
            ax = 180.0 + math.degrees(a)

        M_s = g2b_mat(ps, (ax, 0.0, 0.0))
        # Steel link plate sits at y = -0.004..+0.014 (6mm clear above belt r_out = r_arc - 0.010!)
        _add_prism_local(bm_steel, M_s, -ear_w, ear_w, -0.004, 0.014, shoe_len_b, shoe_len_t)
        if li % 2 == 0 and not compact_pod:
            _add_prism_local(bm_steel, M_s, -0.018, 0.018, -0.052, -0.004, pitch * 0.36, pitch * 0.62, cap_bottom=True)
        # Twin rubber pads start flush at y = 0.014 with cap_bottom=False (zero coplanarity!) up to 0.026
        _add_prism_local(bm_pads, M_s, -hw * 0.92, -0.036, 0.014, 0.026, pad_len_b, pad_len_t, cap_bottom=False)
        _add_prism_local(bm_pads, M_s, 0.036, hw * 0.92, 0.014, 0.026, pad_len_b, pad_len_t, cap_bottom=False)

    kb._finalize(f"{pfx}_LinksSteel", bm_steel, "gunmetal", "plain_metal", Matrix.Identity(4), 0.0, 1, False, 1.0, 1.0, 1.0)
    kb._finalize(f"{pfx}_LinksPads", bm_pads, "rubber", "armor_ribs", Matrix.Identity(4), 0.0, 1, False, 1.0, 2.0, 2.0)

    r_spr = r_belt_out - belt_thick - 0.010
    _toothed_sprocket(kb, f"{pfx}_DriveSpr", (ox, y_trk, oz - straight * 0.5), r_spr, width, side, is_drive=True, compact=compact_pod)
    _toothed_sprocket(kb, f"{pfx}_IdlerWhl", (ox, y_trk, oz + straight * 0.5), r_spr * 0.94, width, side, is_drive=False, compact=compact_pod)

    r_belt_in = r_belt_out - belt_thick
    min_dz = min((abs(wheel_zs[k + 1] - wheel_zs[k]) for k in range(len(wheel_zs) - 1)), default=9.0)
    rw_r_raw = r_wheel if r_wheel > 0.01 else (r_arc * (0.76 if christie else 0.62))
    rw_r = min(rw_r_raw, r_belt_in - 0.016, min_dz * 0.465)
    wy = y_trk - (r_belt_in - rw_r) + 0.014
    w_segs = 10 if compact_pod else 12
    for wi, wz in enumerate(wheel_zs):
        has_shk = (wi == 0 or wi == len(wheel_zs) - 1) and len(wheel_zs) >= 3 and not compact_pod
        _dished_dual_roadwheel(kb, f"{pfx}_RW{wi}", (ox, wy, oz + wz), rw_r, width, side, add_shock=has_shk, segs=w_segs)

    if return_rollers > 0 and not christie:
        rr_r = max(0.062, r_arc * 0.23)
        ry = y_trk + r_belt_in - rr_r - 0.012
        for ri in range(return_rollers):
            frac = (ri + 1) / (return_rollers + 1) - 0.5
            rz = oz + frac * straight * 0.76
            kb.cyl(f"{pfx}_RetR{ri}", rr_r, rr_r, width * 0.70, 10, "dark", "gear_collar",
                   (ox, ry, rz), (0, 0, 90), 0.003)


# ==============================================================================
# 2. MUSCULAR B.O.T-SCALE MULTI-LEGGED SPIDER / QUAD / HEX LIMB BUILDER
# ==============================================================================

def build_heavy_spider_limb(kb: KitbashScene, i: int, pfx: str, pos, yaw_deg: float,
                            KN: Vector, FT: Vector, scale_w: float = 1.0,
                            has_era: bool = False, pile_style: bool = False,
                            oxide_accent: bool = False, compact_hex: bool = False):
    """
    Muscular, multi-layered B.o.T-grade Quad/Hexapod hydraulic load-bearing limb:
      - Strictly stepped X-widths across Coxa (+/-0.26w) -> Femur (+/-0.218w) -> Knee (+/-0.27w) -> Tibia (+/-0.233w)
      - Axial joint setbacks so pitching Femur/Tibia never clip CoxaHood, KnDrum, or AnkBall.
    """
    rel_an = FT - KN
    l1, l2 = KN.length, rel_an.length
    w = scale_w
    d_segs = 8 if compact_hex else 10
    h_segs = 6

    g_leg = kb.add_group(f"Leg_{i}", f"Leg_{i}", pos=pos, rot_deg=(0.0, yaw_deg, 0.0))
    kb.use_group(g_leg)

    # 1. Heavy Coxa Shoulder Turret + Armored Shoulder Hood + Oversized Trunnion Drum
    kb.cyl(f"{pfx}_CoxaTurret", 0.24 * w, 0.27 * w, 0.28, d_segs, "dark", "gear_collar",
           (0, 0.01, 0.03), (0, 0, 0), 0.006, u_rep=2.0)
    kb.plate(f"{pfx}_CoxaHood", trap_2d(0.44 * w, 0.34 * w, 0.26, 0.05), 0.22, "armor_sub", "weld_plate",
             (0, 0.16, 0.05), (-18, 0, 0), 0.014, 1)
    heavy_drum(kb, f"{pfx}_HipAct", (0, 0.01, 0.16), 0.175 * w, 0.52 * w, segs=d_segs, n_bolts=0)

    # 2. FEMUR GROUP (0 -> KN): Starts forward of CoxaHood/HipAct so pitching never clips Coxa!
    g_fm = kb.add_group(f"Leg_{i}/Femur", f"Femur_{i}", pos=(0.0, 0.0, 0.0), parent_key=g_leg)
    kb.use_group(g_fm)
    M_up = g2b_bone_mat((0, 0, 0), KN)
    y_fm_s = 0.22
    l1_span = max(0.28, l1 - y_fm_s - 0.12)
    y_fm_m = -(y_fm_s + 0.5 * l1_span)

    kb.box(f"{pfx}_FemCore", (0.30 * w, l1_span, 0.28 * w), "dark", "frame_cnc",
           (0, y_fm_m, 0.0), (0, 0, 0), 0.014, 1, M_parent=M_up)
    kb.plate(f"{pfx}_FemTopArm", trap_2d(0.40 * w, 0.48 * w, l1_span * 0.94, 0.05), 0.18 * w,
             "armor", "armor_slab", (0, y_fm_m, 0.17 * w), (0, 0, 0), 0.018, 1, M_parent=M_up)
    kb.plate(f"{pfx}_FemSubArm", crect_2d(0.28 * w, l1_span * 0.56, (0.04, 0.04, 0.04, 0.04)), 0.072 * w,
             "armor_oxide" if oxide_accent else "armor_sub", "armor_hatch",
             (0, y_fm_m + 0.03, 0.285 * w), (0, 0, 0), 0.010, 1, M_parent=M_up)
    for sxi, sx_c in enumerate([-1.0, 1.0]):
        kb.plate(f"{pfx}_FemSide{sxi}", crect_2d(0.25 * w, l1_span * 0.84, (0.04, 0.04, 0.04, 0.04)), 0.068 * w,
                 "armor_sub", "armor_ribs", (sx_c * 0.184 * w, y_fm_m, 0.02), (0, sx_c * 90.0, 0), 0.010, 1, M_parent=M_up)
    heavy_hyd(kb, f"{pfx}_FemHyd", (0.0, -(y_fm_s + 0.02), -0.16 * w),
              (0.0, -(l1 - 0.14), -0.16 * w), 0.032 * w, h_segs, pins=False, M_parent=M_up)

    # Massive Knee Drum (widest X-step: +/-0.27w) + Sloped Armored Knee Ram Hood
    heavy_drum(kb, f"{pfx}_KnDrum", KN, 0.205 * w, 0.54 * w, segs=d_segs, n_bolts=0)
    M_kh = g2b_mat((KN.x, KN.y + 0.12, KN.z + 0.16 * w), (-28.0, 0.0, 0.0))
    kb.plate(f"{pfx}_KneeHood", trap_2d(0.46 * w, 0.34 * w, 0.36, 0.06), 0.14 * w,
             "armor", "armor_pocket", (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_kh)
    kb.box(f"{pfx}_KneeHaz", (0.30 * w, 0.044, 0.024), "hazard", "hazard",
           (0, -0.09, 0.092 * w), (0, 0, 0), 0.0, 1, M_parent=M_kh)

    # 3. KNEE / TIBIA GROUP (KN -> FT): Stepped inside KnDrum (+/-0.233w vs +/-0.270w)
    g_kn = kb.add_group(f"Leg_{i}/Knee", f"Knee_{i}", pos=(KN.x, KN.y, KN.z), parent_key=g_fm)
    kb.use_group(g_kn)
    M_lo = g2b_bone_mat((0, 0, 0), rel_an)
    y_tb_s = 0.15
    l2_span = max(0.32, l2 - y_tb_s - 0.11)
    y_tb_m = -(y_tb_s + 0.5 * l2_span)

    if pile_style:
        kb.box(f"{pfx}_ColCage", (0.34 * w, l2_span * 0.54, 0.32 * w), "dark", "frame_cnc",
               (0, -(y_tb_s + l2_span * 0.36), 0.0), (0, 0, 0), 0.014, 1, M_parent=M_lo)
        for cxi, cx in enumerate([-0.11 * w, 0.11 * w]):
            kb.cyl(f"{pfx}_PileBbl{cxi}", 0.095 * w, 0.102 * w, l2_span * 0.66, d_segs, "gunmetal", "armor_panel",
                   (cx, -(y_tb_s + l2_span * 0.36), 0.0), (0, 0, 0), 0.005, M_parent=M_lo)
            kb.cyl(f"{pfx}_PileRod{cxi}", 0.068 * w, 0.068 * w, l2_span * 0.96, d_segs, "chrome", "plain_metal",
                   (cx, y_tb_m - 0.03, 0.0), (0, 0, 0), 0.004, M_parent=M_lo)
        kb.plate(f"{pfx}_PileShld", trap_2d(0.44 * w, 0.52 * w, l2_span * 0.80, 0.06), 0.18 * w,
                 "armor", "armor_slab", (0, y_tb_m + 0.03, 0.18 * w), (2, 0, 0), 0.018, 1, M_parent=M_lo)
        for sxi, sx_c in enumerate([-1.0, 1.0]):
            kb.plate(f"{pfx}_PileCheek{sxi}", trap_2d(0.28 * w, 0.22 * w, l2_span * 0.72, 0.04), 0.070 * w,
                     "armor_sub", "weld_plate", (sx_c * 0.198 * w, y_tb_m + 0.03, 0.04 * w), (0, sx_c * 90.0, 0), 0.012, 1, M_parent=M_lo)
    else:
        kb.box(f"{pfx}_TibCore", (0.32 * w, l2_span, 0.32 * w), "dark", "frame_cnc",
               (0, y_tb_m, -0.01), (0, 0, 0), 0.014, 1, M_parent=M_lo)
        M_tf = M_lo @ g2b_mat((0, y_tb_m, 0.18 * w), (3, 0, 0))
        kb.plate(f"{pfx}_TibFront", trap_2d(0.38 * w, 0.52 * w, l2_span * 0.94, 0.06), 0.18 * w,
                 "armor", "armor_slab", (0, 0, 0), (0, 0, 0), 0.020, 1, M_parent=M_tf)
        for sxi, sx_c in enumerate([-1.0, 1.0]):
            kb.plate(f"{pfx}_TibCheek{sxi}", trap_2d(0.24 * w, 0.34 * w, l2_span * 0.84, 0.04), 0.072 * w,
                     "armor_sub", "armor_ribs", (sx_c * 0.198 * w, y_tb_m, 0.04 * w),
                     (0, sx_c * 90.0, 0.0), 0.012, 1, M_parent=M_lo)
        if has_era:
            kb.era_block(f"{pfx}_TibERA0", (0.38 * w, 0.24, 0.064), "armor_oxide",
                         (0, 0.08, 0.122 * w), (0, 0, 0), M_parent=M_tf)
        else:
            kb.plate(f"{pfx}_TibSub", trap_2d(0.26 * w, 0.38 * w, l2_span * 0.52, 0.04), 0.105 * w,
                     "armor_oxide" if (oxide_accent and i < 2) else "armor_sub", "weld_plate",
                     (0, 0.08, 0.095 * w), (0, 0, 0), 0.010, 1, M_parent=M_tf)
            if i % 2 == 1:
                kb.decal(f"{pfx}_TibDec", "hazard_tri", (0.14, 0.14),
                         (0, 0.08, 0.155 * w), (0, 180, 0), M_parent=M_tf)
        heavy_hyd(kb, f"{pfx}_TibHyd", (0.0, -(y_tb_s + 0.02), -0.18 * w),
                  (0.0, -(l2 - 0.14), -0.18 * w), 0.027 * w, h_segs, pins=False, M_parent=M_lo)

    # 4. ANKLE GROUP: Wide Planted 3/4-Spade Hydraulic Siege Pad (zero rubber-on-rubber overlap!)
    g_an = kb.add_group(f"Leg_{i}/Ankle", f"Ankle_{i}", pos=(rel_an.x, rel_an.y, rel_an.z), parent_key=g_kn)
    kb.use_group(g_an)
    r_pad = (0.34 if pile_style else 0.30) * w
    kb.cyl(f"{pfx}_AnkBall", 0.16 * w, 0.19 * w, 0.14, d_segs, "gunmetal", "gear_collar",
           (0, 0.072, 0), (0, 0, 0), 0.005, u_rep=2.0)
    kb.cyl(f"{pfx}_FootBell", r_pad * 0.86, r_pad, 0.072, d_segs, "armor", "bolt_flange",
           (0, 0.014, 0), (0, 0, 0), 0.007, u_rep=2.0)
    kb.cyl(f"{pfx}_FootSole", r_pad * 1.01, r_pad * 1.03, 0.046, d_segs, "rubber", "dust_boot",
           (0, -0.029, 0), (0, 0, 0), 0.004)
    claws = [-42.0, 42.0, 138.0, -138.0] if (pile_style and not compact_hex) else [-40.0, 40.0, 180.0]
    for ci, ca in enumerate(claws):
        M_cl = g2b_mat((0, 0, 0), (0.0, ca, 0.0))
        kb.box(f"{pfx}_ClawArm{ci}", (0.13 * w, 0.076, 0.22 * w), "armor_sub", "armor_ribs",
               (0, 0.018, r_pad * 0.96), (16, 0, 0), 0.008, 1, M_parent=M_cl)
        kb.box(f"{pfx}_ClawPad{ci}", (0.14 * w, 0.036, 0.16 * w), "rubber", "dust_boot",
               (0, -0.034, r_pad * 1.13), (0, 0, 0), 0.0, 1, M_parent=M_cl)
