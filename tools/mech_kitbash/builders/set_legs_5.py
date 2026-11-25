"""Production v1.5 Zero-Clip Hard-Surface Mech Leg Builders (5 Chassis Set).

Implements 5 articulated mech leg chassis matching MECH_MODELING_STANDARD v1.0 & v1.5 Zero-Clip Standard:
  1. legs_biped_assault (VK-5 Medium-Heavy Assault Biped — normal-joint humanoid, hinged skirts, ERA knee shields, calf thrusters, sabatons)
  2. legs_tread         (SAXX-1 Armored MBT Tracked Chassis — sloped glacis, periscope, headlights, fuel drums, 26-shoe tracks + side skirts)
  3. legs_quad          (AR-4 Arachne 4-Legged Spider Chassis — heavy octagonal hull, 8-rib barbette, 4 articulated truss spider legs)
  4. legs_hex           (HX-6 Faceted Cruiser 6-Legged Chassis — sleek faceted prow hull, 8-rib barbette, 6 articulated cruiser spider legs)
  5. legs_titan         (TT-8 Super-Heavy Reverse-Joint Titan — massive boxy pelvis, double skirts, ERA knee rams, 4-toe siege feet)

Compliance:
  - Unified HP-C1 waist pedestal strictly <= socket_y - 0.015m via kb.waist_collar_legs(...)
  - Exact node hierarchy & bone contracts verified against scripts/modules/mech_glb.gd & scripts/mech.gd
  - Zero intra-module clipping (clip_audit: zf=0, buried=0, deep=0, float=0)
  - Whitelisted mat_slot & 2K trim sheet bands only; <= 28,000 tris & <= 1450 KB per GLB
"""
import math
from mathutils import Vector, Matrix
from kitbash_lib import KitbashScene, C_G2B, C_B2G, g2b_mat, g2b_bone_mat, crect_2d, trap_2d
from leg_rig_lib import build_precision_track_pod, build_heavy_spider_limb


# ==============================================================================
# PRIVATE COMPACT MECHANICAL SUB-ASSEMBLIES (ZERO-CLIP & TRI-BUDGET TUNED)
# ==============================================================================

def _compact_hydraulic(kb: KitbashScene, prefix: str, p_from, p_to, r: float = 0.022,
                       segs: int = 8, pins: bool = True, M_parent=None, group=None):
    """Multi-part hydraulic cylinder + rubber dust boot + brass seal + chrome rod + clevises."""
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
    h_seal = 0.022
    y_seal1 = y_seal0 + h_seal
    y_boot0 = y_seal1 + 0.008
    y_boot1 = max(y_boot0 + 0.028, 0.24 * L)
    kb.cyl(f"{prefix}_cyl", r * 1.72, r * 1.72, h_cyl, segs, "gunmetal", "plain_metal",
           (0, 0.5 * (y_cyl0 + y_cyl1), 0), (0, 0, 0), 0.003, M_parent=M, group=group)
    kb.cyl(f"{prefix}_seal", r * 2.02, r * 2.02, h_seal, segs, "brass", "gear_collar",
           (0, 0.5 * (y_seal0 + y_seal1), 0), (0, 0, 0), 0.002, M_parent=M, group=group)
    kb.cyl(f"{prefix}_boot", r * 1.90, r * 1.84, y_boot1 - y_boot0, segs, "rubber", "dust_boot",
           (0, 0.5 * (y_boot0 + y_boot1), 0), (0, 0, 0), 0.002, M_parent=M, u_rep=2.0, group=group)
    kb.cyl(f"{prefix}_rod", r * 0.90, r * 0.90, L * 0.84, max(6, segs - 2), "chrome", "plain_metal",
           (0, 0.0, 0), (0, 0, 0), 0.002, M_parent=M, group=group)
    for si, e in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_cl{si}", (r * 3.0, r * 2.4, r * 2.4), "dark", "bolt_flange",
               (0, e * L * 0.48, 0), (0, 0, 0), 0.003 if pins else 0.0, 1, M_parent=M, group=group)
        if pins:
            kb.cyl(f"{prefix}_pn{si}", r * 0.62, r * 0.62, r * 3.8, 6, "chrome", "plain_metal",
                   (0, e * L * 0.48, 0), (0, 0, 90), 0.002, M_parent=M, group=group)


def _compact_actuator(kb: KitbashScene, prefix: str, pos, r: float, w: float,
                      segs: int = 12, n_bolts: int = 6, flanges: bool = True,
                      M_parent=None, group=None):
    """Joint actuator drum along X axis with stepped non-coplanar flanges, axle caps & bolt rings."""
    M = g2b_mat(pos, (0, 0, 0))
    if M_parent is not None:
        M = M_parent @ M
    kb.cyl(f"{prefix}_body", r, r, w, segs, "dark", "frame_cnc",
           (0, 0, 0), (0, 0, 90), 0.006, M_parent=M, group=group)
    kb.cyl(f"{prefix}_rib", r * 1.06, r * 1.06, w * 0.32, segs, "gunmetal", "gear_collar",
           (0, 0, 0), (0, 0, 90), 0.004, M_parent=M, u_rep=2.0, group=group)
    for si, sx in enumerate([-1.0, 1.0]):
        if flanges:
            kb.cyl(f"{prefix}_fl{si}", r * 1.10, r * 1.10, w * 0.12, segs, "gunmetal", "bolt_flange",
                   (sx * w * 0.37, 0, 0), (0, 0, 90), 0.004, M_parent=M, u_rep=2.0, group=group)
        kb.cyl(f"{prefix}_ax{si}", r * 0.44, r * 0.40, w * 0.14, max(8, segs - 2), "chrome", "plain_metal",
               (sx * (w * 0.50 + 0.024), 0, 0), (0, 0, 90), 0.003, M_parent=M, group=group)
        for bi in range(n_bolts):
            a = math.tau * bi / n_bolts
            kb.cyl(f"{prefix}_b{si}_{bi}", 0.011, 0.013, 0.024, 6, "chrome", "plain_metal",
                   (sx * (w * 0.50 + 0.005), math.cos(a) * r * 0.76, math.sin(a) * r * 0.76),
                   (0, 0, 90), 0.002, M_parent=M, group=group)


def _add_periscope(kb: KitbashScene, prefix: str, w: float, h: float, pos,
                   rot_deg=(0, 0, 0), M_parent=None, group=None):
    """Armored driver periscope housing with brow hood, recessed bore cavity, and obsidian glass prism."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.box(f"{prefix}_hs", (w, h, 0.088), "dark", "frame_cnc",
           (0, 0, 0.024), (0, 0, 0), 0.007, 1, M_parent=M, group=group)
    kb.box(f"{prefix}_br", (w + 0.024, 0.022, 0.112), "gunmetal", "bolt_flange",
           (0, h * 0.5 + 0.014, -0.016), (10, 0, 0), 0.004, 1, M_parent=M, group=group)
    kb.box(f"{prefix}_cv", (w * 0.80, h * 0.54, 0.020), "bore", "plain_metal",
           (0, -0.004, -0.028), (0, 0, 0), 0.003, 1, M_parent=M, group=group)
    kb.box(f"{prefix}_gl", (w * 0.72, h * 0.42, 0.014), "glass", "plain_metal",
           (0, -0.004, -0.052), (0, 0, 0), 0.002, 1, M_parent=M, group=group)


def _seated_tow_shackle(kb: KitbashScene, prefix: str, pos, rot_deg=(0, 0, 0),
                        scale: float = 1.0, M_parent=None, group=None):
    """Forged tow shackle mounted on a welded steel clevis lug (zero burial & zero float!).
    In local space, lug back sits at z = +0.022*scale; place pos at z_front - 0.014*scale for ~8mm embed.
    """
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.box(f"{prefix}_lug", (0.044 * scale, 0.046 * scale, 0.036 * scale), "dark", "bolt_flange",
           (0, 0, 0.004 * scale), (0, 0, 0), 0.004 * scale, 1, M_parent=M, group=group)
    kb.cyl(f"{prefix}_pin", 0.012 * scale, 0.012 * scale, 0.062 * scale, 8, "chrome", "plain_metal",
           (0, 0, -0.010 * scale), (0, 0, 90), 0.002 * scale, M_parent=M, group=group)
    kb.cyl(f"{prefix}_ring", 0.042 * scale, 0.042 * scale, 0.022 * scale, 12, "gunmetal", "plain_metal",
           (0, 0, -0.038 * scale), (0, 0, 90), 0.004 * scale, hollow_r=0.022 * scale, M_parent=M, group=group)


# ==============================================================================
# 1. legs_biped_assault — VK-5 Medium-Heavy Assault Biped Chassis
# ==============================================================================

def build_legs_biped_assault(kb: KitbashScene):
    """VK-5 Assault Biped: normal-joint humanoid legs, hinged skirts, ERA knee shields, calf thrusters, sabatons."""
    hip = 1.66
    socket_y = hip + 0.55  # 2.21m exact match to legs_biped_assault.gd

    # --------------------------------------------------------------------------
    # 1. TACTICAL PELVIS, CENTRAL GROIN, HINGED FRONT SKIRTS & HP-C1 WAIST
    # --------------------------------------------------------------------------
    kb.use_group("Body")
    kb.box("InnerPelvis", (0.86, 0.42, 0.78), "dark", "frame_cnc",
           (0, hip + 0.04, 0.02), (0, 0, 0), 0.022, 1, tile_u=2.0)
    kb.box("PelvisDeck", (0.82, 0.16, 0.66), "armor_sub", "armor_pocket",
           (0, hip + 0.26, 0.02), (0, 0, 0), 0.016, 1)
    for si, sx in enumerate([-0.45, 0.45]):
        kb.cyl(f"PelvisBoss{si}", 0.21, 0.23, 0.07, 12, "gunmetal", "gear_collar",
               (sx, hip, 0.0), (0, 0, 90), 0.006, u_rep=2.0)

    # Central assault wedge groin armor + sub-plate + accent stripe + seated tow shackle
    M_groin = g2b_mat((0.0, hip - 0.03, -0.43), (10.0, 0.0, 0.0))
    kb.plate("GroinArmor", trap_2d(0.36, 0.46, 0.52, 0.05), 0.14, "armor_sub", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_groin)
    kb.plate("GroinSub", trap_2d(0.24, 0.32, 0.30, 0.04), 0.055, "armor", "armor_ribs",
             (0, -0.02, -0.098), (0, 0, 0), 0.009, 1, M_parent=M_groin)
    kb.box("GroinAcc", (0.28, 0.046, 0.022), "accent", "plain_metal",
           (0, 0.165, -0.086), (0, 0, 0), 0.003, 1, M_parent=M_groin)
    kb.box("GroinHaz", (0.22, 0.036, 0.022), "hazard", "hazard",
           (0, -0.205, -0.086), (0, 0, 0), 0.003, 1, M_parent=M_groin)
    _seated_tow_shackle(kb, "GroinTow", (0.0, -0.14, -0.138), (0, 0, 0), 0.85, M_parent=M_groin)

    # Left & right angled hinged tactical front skirt flaps (Faulds)
    for fi, sx_f in enumerate([-0.42, 0.42]):
        side_f = -1.0 if sx_f < 0 else 1.0
        kb.box(f"SkirtMount{fi}", (0.14, 0.08, 0.14), "dark", "bolt_flange",
               (sx_f, hip + 0.14, -0.37), (0, 0, 0), 0.007, 1)
        M_fl = g2b_mat((sx_f, hip + 0.02, -0.45), (14.0, side_f * -10.0, side_f * -6.0))
        kb.cyl(f"SkirtHinge{fi}", 0.034, 0.034, 0.20, 10, "gunmetal", "gear_collar",
               (0, 0.13, 0.035), (0, 0, 90), 0.004, M_parent=M_fl)
        kb.plate(f"SkirtFlap{fi}", trap_2d(0.40, 0.34, 0.44, 0.05), 0.095, "armor", "armor_panel",
                 (0, -0.08, 0), (0, 0, 0), 0.014, 1, M_parent=M_fl)
        kb.plate(f"SkirtSub{fi}", trap_2d(0.28, 0.24, 0.24, 0.03), 0.038, "armor_sub", "armor_hatch",
                 (0, -0.08, -0.068), (0, 0, 0), 0.007, 1, M_parent=M_fl)
        if side_f < 0:
            kb.box(f"SkirtHaz{fi}", (0.20, 0.040, 0.022), "hazard", "hazard",
                   (0, -0.23, -0.062), (0, 0, 0), 0.003, 1, M_parent=M_fl)
        else:
            kb.box(f"SkirtAcc{fi}", (0.20, 0.040, 0.022), "accent", "plain_metal",
                   (0, -0.23, -0.062), (0, 0, 0), 0.003, 1, M_parent=M_fl)
        kb.grab_rail(f"SkirtGrab{fi}", 0.18, 0.032, (0, 0.06, -0.044), (0, 0, 0), 0.009, M_parent=M_fl)

    # Rear sloped armored tail skirt + recessed louver vent bay
    M_rsk = g2b_mat((0.0, hip + 0.01, 0.45), (-14.0, 0.0, 0.0))
    kb.plate("RearSkirt", trap_2d(0.92, 1.12, 0.44, 0.07), 0.11, "armor_sub", "armor_hatch",
             (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_rsk)
    kb.louver_bay("PelvisVent", 0.52, 0.18, 0.046, (0, 0.02, 0.070), (0, 180, 0),
                  blades=4, mesh_style=False, M_parent=M_rsk)

    # Unified HP-C1 waist pedestal (strictly <= socket_y - 0.015 = 2.195m) + 4 stabilizers + 4 hoses
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.325)
    for sxi, sx_g in enumerate([-0.34, 0.34]):
        _compact_hydraulic(kb, f"WaistHydF{sxi}", (sx_g, hip + 0.33, -0.23), (sx_g * 0.76, hip + 0.49, -0.17), 0.020, 6, pins=False)
        _compact_hydraulic(kb, f"WaistHydR{sxi}", (sx_g, hip + 0.33,  0.23), (sx_g * 0.76, hip + 0.49,  0.17), 0.020, 6, pins=False)
    for hi, ang in enumerate([0.22, -0.22, math.pi - 0.22, math.pi + 0.22]):
        ca, sa = math.cos(ang), math.sin(ang)
        kb.tube_path(f"WaistHose{hi}",
                     [(ca * 0.33, hip + 0.33, sa * 0.33),
                      (ca * 0.38, hip + 0.41, sa * 0.38),
                      (ca * 0.31, hip + 0.48, sa * 0.31)],
                     0.015, 6, "gunmetal", "braid_hose", add_clamps=False)

    # --------------------------------------------------------------------------
    # 2. ARTICULATED NORMAL-JOINT ASSAULT LEGS (Leg_L / Leg_R -> Knee -> Ankle)
    # --------------------------------------------------------------------------
    KN = Vector((0.0, -0.76, -0.22))
    AN = Vector((0.0, -1.38, -0.02))
    rel_an = AN - KN  # (0.0, -0.62, +0.20)
    sole_rel = -3.32  # Exact match to legs_biped_assault.gd (-1.54 - 0.12 - 1.66)

    for side_tag, pfx, sx in [("Leg_L", "LL", -0.70), ("Leg_R", "LR", 0.70)]:
        side = -1.0 if sx < 0 else 1.0
        g_leg = kb.add_group(side_tag, side_tag, pos=(sx, hip, 0.0))
        kb.use_group(g_leg)
        kb.add_marker("MARK_SOLE", (0.0, sole_rel, 0.0), parent_key=g_leg)

        # Hip actuator drum + mounted ERA side shield + top grab rail (stepped X planes)
        _compact_actuator(kb, f"{pfx}_HipDrum", (-side * 0.02, 0, 0), 0.24, 0.38, segs=14, n_bolts=4)
        kb.box(f"{pfx}_HipBrk", (0.12, 0.18, 0.24), "dark", "frame_cnc",
               (side * 0.24, -0.02, 0.0), (0, 0, 0), 0.010, 1)
        M_hsh = g2b_mat((side * 0.34, -0.03, 0.0), (0.0, side * -90.0, 0.0))
        kb.plate(f"{pfx}_HipShield", trap_2d(0.70, 0.54, 0.50, 0.07), 0.10, "armor_sub", "armor_panel",
                 (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_hsh)
        kb.era_block(f"{pfx}_HipERA", (0.36, 0.19, 0.064), "armor", (0, 0.04, -0.084), (0, 0, 0), M_parent=M_hsh)
        kb.grab_rail(f"{pfx}_HipGrab", 0.20, 0.036, (0, 0.246, 0.0), (90, 0, 0), 0.010, M_parent=M_hsh)

        # Thigh bone frame (H=0 -> KN): stepped narrower than KneeDrum (0.48 -> +/-0.240)
        M_th = g2b_bone_mat((0, 0, 0), KN)
        l1 = KN.length
        l1_s = l1 - 0.26
        y_th_m = -(0.14 + 0.5 * l1_s)
        kb.box(f"{pfx}_InnerThigh", (0.32, l1_s, 0.42), "dark", "frame_cnc",
               (0, y_th_m, 0.02), (0, 0, 0), 0.016, 1, M_parent=M_th)
        kb.plate(f"{pfx}_ThighFront", trap_2d(0.38, 0.46, l1_s * 0.94, 0.06), 0.12, "armor", "armor_panel",
                 (0, y_th_m, -0.24), (-2, 0, 0), 0.016, 1, M_parent=M_th)
        kb.plate(f"{pfx}_ThighFront2", crect_2d(0.28, l1_s * 0.48, (0.04, 0.04, 0.02, 0.02)), 0.050, "armor_sub", "armor_hatch",
                 (0, y_th_m + 0.06, -0.325), (-2, 0, 0), 0.008, 1, M_parent=M_th)
        kb.box(f"{pfx}_ThighAcc", (0.052, l1_s * 0.30, 0.022), "accent", "plain_metal",
               (side * 0.10, y_th_m + 0.06, -0.362), (-2, 0, 0), 0.003, 1, M_parent=M_th)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{pfx}_ThighSide{s2i}", crect_2d(0.40, l1_s * 0.84, (0.06, 0.06, 0.04, 0.04)), 0.070,
                     "armor_sub", "armor_ribs", (s2 * 0.188, y_th_m, 0.02), (0, s2 * -90.0, 0), 0.012, 1, M_parent=M_th)
        kb.box(f"{pfx}_ThighRail", (0.026, l1_s * 0.56, 0.052), "gunmetal", "bolt_flange",
               (side * 0.240, y_th_m, 0.02), (0, 0, 0), 0.004, 1, M_parent=M_th)
        _compact_hydraulic(kb, f"{pfx}_ThighHyd0", (side * 0.11, -0.12, 0.27), (side * 0.11, -l1 + 0.12, 0.24), 0.026, 8, pins=False, M_parent=M_th)
        _compact_hydraulic(kb, f"{pfx}_ThighHyd1", (-side * 0.11, -0.12, 0.27), (-side * 0.11, -l1 + 0.12, 0.24), 0.022, 8, pins=False, M_parent=M_th)
        kb.tube_path(f"{pfx}_ThighHose",
                     [(side * 0.15, -0.14, 0.22), (side * 0.22, -0.44, 0.24), (side * 0.14, KN.y + 0.06, KN.z + 0.14)],
                     0.020, 6, "gunmetal", "braid_hose", add_clamps=False)

        # Heavy Knee Actuator Drum (widest X-step at KN: 0.48 -> +/-0.240)
        _compact_actuator(kb, f"{pfx}_KneeDrum", KN, 0.195, 0.48, segs=14, n_bolts=4)

        # ---- KNEE PIVOT GROUP (Tall ERA Knee Shield + Flared Wanzer Shin + Rear Twin Thruster Pod) ----
        g_knee = kb.add_group(f"{side_tag}/Knee", "Knee", pos=(KN.x, KN.y, KN.z), parent_key=g_leg)
        kb.use_group(g_knee)
        l2 = rel_an.length
        l2_s = l2 - 0.26
        y_sh_m = -(0.14 + 0.5 * l2_s)
        M_sh = g2b_bone_mat((0, 0, 0), rel_an)

        kb.box(f"{pfx}_InnerShin", (0.32, l2_s, 0.42), "dark", "frame_cnc",
               (0, y_sh_m, 0.04), (0, 0, 0), 0.016, 1, M_parent=M_sh)
        kb.plate(f"{pfx}_ShinFront", trap_2d(0.46, 0.38, l2_s * 0.94, 0.06), 0.14, "armor", "armor_panel",
                 (0, y_sh_m, -0.24), (4, 0, 0), 0.016, 1, M_parent=M_sh)
        kb.louver_bay(f"{pfx}_ShinVent", 0.22, 0.20, 0.032, (0, y_sh_m - 0.02, -0.328), (4, 0, 0),
                      blades=4, mesh_style=True, M_parent=M_sh)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{pfx}_ShinSide{s2i}", trap_2d(0.48, 0.38, l2_s * 0.88, 0.05), 0.072, "armor_sub", "armor_ribs",
                     (s2 * 0.194, y_sh_m, 0.04), (0, s2 * -90.0, 0.0), 0.012, 1, M_parent=M_sh)

        # Tall upward-extending ERA Knee Shield mounted on Knee group!
        kb.box(f"{pfx}_KneeRiser", (0.24, 0.20, 0.16), "dark", "frame_cnc",
               (0, -0.06, -0.20), (-12, 0, 0), 0.010, 1)
        M_ksh = g2b_mat((0.0, 0.08, -0.28), (-12.0, 0.0, 0.0))
        kb.plate(f"{pfx}_KneeShield", trap_2d(0.46, 0.34, 0.46, 0.06), 0.13, "armor", "armor_panel",
                 (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_ksh)
        kb.era_block(f"{pfx}_KneeERA", (0.28, 0.15, 0.060), "armor_sub", (0, 0.07, -0.096), (0, 0, 0), M_parent=M_ksh)
        kb.box(f"{pfx}_KneeAcc", (0.30, 0.044, 0.022), "accent", "plain_metal",
               (0, -0.125, -0.080), (0, 0, 0), 0.003, 1, M_parent=M_ksh)
        kb.box(f"{pfx}_KneeBrow", (0.30, 0.034, 0.12), "gunmetal", "bolt_flange",
               (0, 0.24, -0.01), (0, 0, 0), 0.005, 1, M_parent=M_ksh)

        # Rear calf mobility thruster pod + vent + twin hollow nozzles (recessed deep bore, zero Z-fight!)
        M_pod = M_sh @ g2b_mat((0, y_sh_m + 0.02, 0.34), (16.0, 0.0, 0.0))
        kb.box(f"{pfx}_CalfPod", (0.36, 0.32, 0.20), "armor_sub", "armor_pocket",
               (0, 0, 0), (0, 0, 0), 0.015, 1, M_parent=M_pod)
        kb.louver_bay(f"{pfx}_CalfVent", 0.26, 0.12, 0.032, (0, 0.06, 0.114), (0, 180, 0),
                      blades=3, mesh_style=False, M_parent=M_pod)
        for nzi, nz_x in enumerate([-0.10, 0.10]):
            M_nz = M_pod @ g2b_mat((nz_x, -0.20, 0.025), (-18.0, 0.0, 0.0))
            kb.cyl(f"{pfx}_NozBell{nzi}", 0.056, 0.070, 0.12, 12, "gunmetal", "gear_collar",
                   (0, 0.0, 0), (0, 0, 0), 0.004, hollow_r=0.045, M_parent=M_nz)
            kb.cyl(f"{pfx}_NozBore{nzi}", 0.044, 0.044, 0.022, 10, "bore", "plain_metal",
                   (0, 0.024, 0), (0, 0, 0), 0.002, M_parent=M_nz)
        kb.tube_path(f"{pfx}_ShinHose",
                     [(-side * 0.15, -0.08, 0.14), (-side * 0.21, -0.32, 0.26), (-side * 0.14, rel_an.y + 0.10, rel_an.z + 0.10)],
                     0.016, 6, "gunmetal", "braid_hose", add_clamps=False)

        # ---- ANKLE PIVOT GROUP (Heavy Flat Sabaton Boot + Hydraulic Heel Spur) ----
        g_ank = kb.add_group(f"{side_tag}/Ankle", "Ankle", pos=(rel_an.x, rel_an.y, rel_an.z), parent_key=g_knee)
        kb.use_group(g_ank)
        _compact_actuator(kb, f"{pfx}_AnkDrum", (0, 0, 0), 0.155, 0.32, segs=12, n_bolts=4)
        ft_off = Vector((0.0, -1.54, -0.04)) - AN  # (0, -0.16, -0.02), world Y = 0.12m
        M_ft = g2b_mat((ft_off.x, ft_off.y, ft_off.z), (0, 0, 0))
        kb.box(f"{pfx}_AnkBridge", (0.24, 0.14, 0.22), "dark", "frame_cnc",
               (0, 0.09, 0.02), (0, 0, 0), 0.010, 1, M_parent=M_ft)
        kb.box(f"{pfx}_FootBlock", (0.50, 0.15, 0.72), "gunmetal", "frame_cnc",
               (0, -0.005, -0.04), (0, 0, 0), 0.015, 1, M_parent=M_ft)
        kb.plate(f"{pfx}_FootInstep", trap_2d(0.48, 0.38, 0.38, 0.05), 0.14, "armor", "armor_panel",
                 (0, 0.125, -0.22), (-66, 0, 0), 0.014, 1, M_parent=M_ft)
        M_tc = M_ft @ g2b_mat((0, 0.015, -0.43), (-20, 0, 0))
        kb.plate(f"{pfx}_ToeCap", trap_2d(0.48, 0.42, 0.22, 0.04), 0.12, "armor_sub", "armor_ribs",
                 (0, 0, 0), (0, 0, 0), 0.012, 1, M_parent=M_tc)
        kb.box(f"{pfx}_ToeHaz", (0.30, 0.036, 0.022), "hazard", "hazard",
               (0, 0.04, -0.074), (0, 0, 0), 0.003, 1, M_parent=M_tc)
        kb.box(f"{pfx}_FootSole", (0.56, 0.056, 0.80), "rubber", "dust_boot",
               (0, -0.092, -0.04), (0, 0, 0), 0.008, 1, M_parent=M_ft)
        # Rear hydraulic recoil heel spur (spade + rubber heel pad + twin recoil pistons)
        kb.plate(f"{pfx}_HeelSpade", trap_2d(0.44, 0.36, 0.20, 0.04), 0.095, "gunmetal", "bolt_flange",
                 (0, -0.005, 0.37), (22, 0, 0), 0.010, 1, M_parent=M_ft)
        kb.box(f"{pfx}_HeelPad", (0.42, 0.042, 0.14), "rubber", "dust_boot",
               (0, -0.099, 0.37), (0, 0, 0), 0.006, 1, M_parent=M_ft)
        for hhi, hhx in enumerate([-0.14, 0.14]):
            _compact_hydraulic(kb, f"{pfx}_HeelHyd{hhi}", (hhx, 0.12, 0.14), (hhx, 0.01, 0.35), 0.019, 6, pins=False, M_parent=M_ft)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 2. legs_tread — SAXX-1 Armored MBT Tracked Chassis
# ==============================================================================

def build_legs_tread(kb: KitbashScene):
    """SAXX-1 Armored MBT Tread Chassis: sloped glacis, periscope, headlights, fuel drums, 26-shoe tracks."""
    hip = 1.05
    socket_y = hip + 0.32  # 1.37m low-profile flush tank turret ring!

    # --------------------------------------------------------------------------
    # 1. ARMORED MBT HULL, GLACIS, PERISCOPE, HEADLIGHTS, REAR DECK & BARBETTE
    # --------------------------------------------------------------------------
    kb.use_group("Body")
    kb.box("InnerHull", (1.18, 0.54, 1.92), "dark", "frame_cnc",
           (0, 0.72, 0.02), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.plate("HullUpper", crect_2d(2.00, 0.34, (0.14, 0.32, 0.10, 0.06)), 1.24, "armor", "armor_panel",
             (0, 1.03, 0.04), (0, 90, 0), 0.018, 1)
    for si, sx in enumerate([-0.63, 0.63]):
        kb.box(f"FinalDrive{si}", (0.14, 0.30, 1.76), "gunmetal", "armor_pocket",
               (sx, 0.56, 0.0), (0, 0, 0), 0.012, 1)

    # Low-profile chamfered turret barbette apron + 8 gusset ribs + compact HP-C1 slewing ring
    kb.plate("BarbetteDeck", crect_2d(1.12, 1.18, (0.26, 0.26, 0.22, 0.22)), 0.12, "armor_sub", "armor_pocket",
             (0, 1.23, 0.0), (90, 0, 0), 0.014, 1)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, 1.27)
    for gi in range(8):
        ga = math.tau * gi / 8.0 + math.pi / 8.0
        kb.box(f"BarbRib{gi}", (0.042, 0.070, 0.10), "gunmetal", "bolt_flange",
               (math.cos(ga) * 0.31, 1.305, math.sin(ga) * 0.31), (0, -math.degrees(ga), 0), 0.004, 1)
    for hi, ang in enumerate([0.35, -0.35, math.pi - 0.35, math.pi + 0.35]):
        ca, sa = math.cos(ang), math.sin(ang)
        kb.tube_path(f"WaistHose{hi}",
                     [(ca * 0.38, 1.27, sa * 0.38), (ca * 0.34, 1.31, sa * 0.34), (ca * 0.27, 1.335, sa * 0.27)],
                     0.013, 6, "gunmetal", "braid_hose", add_clamps=False)

    # Driver armored periscope seated cleanly on front upper hull deck
    _add_periscope(kb, "DriverOptic", 0.24, 0.085, (0, 1.235, -0.68), (0, 0, 0))

    # True sloped MBT wedge glacis (+40 deg upper glacis sloping back + -36 deg lower glacis sloping under!)
    M_gl = g2b_mat((0.0, 0.87, -1.03), (40.0, 0.0, 0.0))
    kb.plate("GlacisUpper", trap_2d(1.06, 1.20, 0.48, 0.07), 0.13, "armor_sub", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_gl)
    kb.box("GlacisSplash", (0.94, 0.036, 0.044), "gunmetal", "bolt_flange",
           (0, 0.16, -0.078), (0, 0, 0), 0.005, 1, M_parent=M_gl)
    kb.box("GlacisAcc", (0.068, 0.34, 0.022), "accent", "plain_metal",
           (-0.38, -0.01, -0.080), (0, 0, 0), 0.003, 1, M_parent=M_gl)
    kb.era_block("GlacisERA0", (0.28, 0.18, 0.052), "armor", (-0.06, -0.03, -0.094), (0, 0, 0), M_parent=M_gl)
    kb.era_block("GlacisERA1", (0.28, 0.18, 0.052), "armor", (0.28, -0.03, -0.094), (0, 0, 0), M_parent=M_gl)

    M_lg = g2b_mat((0.0, 0.53, -1.06), (-36.0, 0.0, 0.0))
    kb.plate("GlacisLower", trap_2d(1.14, 1.00, 0.34, 0.05), 0.11, "dark", "armor_ribs",
             (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_lg)
    for ti, tx in enumerate([-0.34, 0.34]):
        _seated_tow_shackle(kb, f"FrontTow{ti}", (tx, 0.02, -0.072), (0, 0, 0), 1.0, M_parent=M_lg)

    # Twin armored headlight cages perched cleanly on front glacis/brow shoulders (proud, zero burial!)
    for hi, hx in enumerate([-0.42, 0.42]):
        kb.box(f"HlPed{hi}", (0.14, 0.10, 0.22), "dark", "frame_cnc",
               (hx, 1.06, -0.88), (0, 0, 0), 0.006, 1)
        kb.headlight_cage(f"Headlight{hi}", (hx, 1.11, -1.015), (0, 0, 0))

    # Rear louvered radiator deck, rear exhaust louver bay & dual external fuel drums
    kb.louver_bay("DeckVent", 0.72, 0.28, 0.042, (0, 1.213, 0.78), (90, 0, 0), blades=5, mesh_style=True)
    kb.louver_bay("RearVent", 0.66, 0.24, 0.046, (0, 0.85, 1.056), (0, 180, 0), blades=5, mesh_style=False)
    kb.box("RearHaz", (0.58, 0.042, 0.018), "hazard", "hazard", (0, 0.61, 0.985), (0, 0, 0), 0.003, 1)
    for di, dx in enumerate([-0.34, 0.34]):
        for ci, cx in enumerate([-0.14, 0.14]):
            kb.box(f"DrumBrk{di}_{ci}", (0.042, 0.08, 0.22), "dark", "bolt_flange",
                   (dx + cx, 1.08, 1.04), (0, 0, 0), 0.005, 1)
        kb.cyl(f"FuelDrum{di}", 0.145, 0.145, 0.46, 14, "armor_sub", "armor_hatch",
               (dx, 1.11, 1.15), (0, 0, 90), 0.008)
        for si, sx_s in enumerate([-0.14, 0.14]):
            kb.cyl(f"FuelStrap{di}_{si}", 0.153, 0.153, 0.026, 14, "dark", "gear_collar",
                   (dx + sx_s, 1.11, 1.15), (0, 0, 90), 0.003)
        kb.cyl(f"FuelCap{di}", 0.024, 0.028, 0.024, 8, "brass", "plain_metal",
               (dx, 1.26, 1.15), (0, 0, 0), 0.002)

    # --------------------------------------------------------------------------
    # 2. ARTICULATED LEFT & RIGHT ARMORED TRACK PODS (Track_L & Track_R)
    # --------------------------------------------------------------------------
    y_trk = 0.352
    for t_name, pfx, sx in [("Track_L", "TL", -0.92), ("Track_R", "TR", 0.92)]:
        side = -1.0 if sx < 0 else 1.0
        g_tr = kb.add_group(t_name, t_name, pos=(sx, 0.0, 0.0))
        kb.use_group(g_tr)

        build_precision_track_pod(kb, pfx, side, y_trk, straight=2.08, r_arc=0.326, width=0.64,
                                  wheel_zs=[-0.72, -0.36, 0.0, 0.36, 0.72], r_wheel=0.205,
                                  n_links=38, return_rollers=2, skip_hidden_top=True)

        # Heavy upper fender deck + 3 vertical stanchions anchoring fender to inner track beam
        kb.plate(f"{pfx}_Fender", crect_2d(2.44, 0.076, (0.06, 0.06, 0.0, 0.0)), 0.72, "armor_sub", "armor_panel",
                 (side * 0.04, 0.80, 0.0), (0, 90, 0), 0.012, 1)
        for pi, pz in enumerate([-0.82, 0.0, 0.82]):
            kb.box(f"{pfx}_FendPost{pi}", (0.12, 0.28, 0.10), "dark", "frame_cnc",
                   (-side * 0.16, 0.65, pz), (0, 0, 0), 0.007, 1)

        # 4 segmented bolted armored side skirts (hanging cleanly off outer fender edge)
        for ki in range(4):
            kz = -0.84 + ki * 0.56
            cuts = (0.14, 0.0, 0.05, 0.07) if ki == 0 else ((0.0, 0.14, 0.07, 0.05) if ki == 3 else (0.0, 0.0, 0.05, 0.05))
            mat_sk = "armor" if ki % 2 == 0 else "armor_sub"
            kb.plate(f"{pfx}_Skirt{ki}", crect_2d(0.53, 0.42, cuts), 0.082, mat_sk, "armor_panel",
                     (side * 0.375, 0.56, kz), (0, 90, 0), 0.014, 1)
            kb.box(f"{pfx}_SkHng{ki}", (0.054, 0.055, 0.36), "gunmetal", "bolt_flange",
                   (side * 0.395, 0.77, kz), (0, 0, 0), 0.005, 1)
        kb.box(f"{pfx}_SkirtAcc", (0.018, 0.048, 0.42), "accent", "plain_metal",
               (side * 0.422, 0.65, -0.82), (0, 0, 0), 0.003, 1)

        # Front & rear angled rubber mudflaps + armored fender toolboxes + hazard plate
        for mfi, (fz, ftilt) in enumerate([(-1.24, -16.0), (1.24, 16.0)]):
            kb.box(f"{pfx}_Mudflap{mfi}", (0.68, 0.24, 0.044), "rubber", "dust_boot",
                   (side * 0.04, 0.66, fz), (ftilt, 0, 0), 0.007, 1)
        kb.box(f"{pfx}_Toolbox", (0.28, 0.15, 0.54), "armor", "armor_hatch",
               (side * 0.12, 0.908, 0.36), (0, 0, 0), 0.012, 1)
        kb.box(f"{pfx}_FendBoxF", (0.24, 0.11, 0.32), "armor_sub", "armor_pocket",
               (side * 0.12, 0.885, -0.66), (0, 0, 0), 0.010, 1)
        kb.box(f"{pfx}_FendHaz", (0.22, 0.040, 0.018), "hazard", "hazard",
               (side * 0.12, 0.90, -0.825), (0, 0, 0), 0.003, 1)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 3. legs_quad — AR-4 Arachne Heavy 4-Legged Spider Chassis
# ==============================================================================

def build_legs_quad(kb: KitbashScene):
    """AR-4 Arachne Quad Chassis: octagonal armored hull, 8-rib barbette, 4 articulated truss spider legs."""
    hip = 1.40
    socket_y = hip + 0.41  # 1.81m compact low-profile slewing ring!

    # --------------------------------------------------------------------------
    # 1. OCTAGONAL ARMORED HULL, 8-RIB BARBETTE, HEADLIGHTS & REAR VENT
    # --------------------------------------------------------------------------
    kb.use_group("Body")
    kb.box("InnerHull", (1.12, 0.36, 1.12), "dark", "frame_cnc",
           (0, hip, 0.0), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.plate("HullTop", crect_2d(1.46, 1.46, (0.35, 0.35, 0.35, 0.35)), 0.22, "armor", "armor_panel",
             (0, hip + 0.17, 0.0), (90, 0, 0), 0.018, 1)
    kb.plate("HullBelly", crect_2d(1.16, 1.16, (0.28, 0.28, 0.28, 0.28)), 0.18, "armor_sub", "armor_pocket",
             (0, hip - 0.17, 0.0), (90, 0, 0), 0.016, 1)

    # Low-profile conical turret barbette + 8 radial ribs + compact HP-C1 slewing ring
    kb.cyl("BarbetteCone", 0.32, 0.42, 0.08, 16, "armor_sub", "armor_ribs",
           (0, hip + 0.30, 0.0), (0, 0, 0), 0.006)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.32)
    for gi in range(8):
        ga = math.tau * gi / 8.0
        kb.box(f"BarbRib{gi}", (0.042, 0.072, 0.10), "gunmetal", "bolt_flange",
               (math.cos(ga) * 0.36, hip + 0.30, math.sin(ga) * 0.36),
               (0, -math.degrees(ga), 0), 0.005, 1)
    for hi in range(4):
        ha = math.tau * hi / 4.0 + 0.40
        ca, sa = math.cos(ha), math.sin(ha)
        kb.tube_path(f"WaistHose{hi}",
                     [(ca * 0.43, hip + 0.27, sa * 0.43),
                      (ca * 0.37, hip + 0.33, sa * 0.37),
                      (ca * 0.27, hip + 0.37, sa * 0.27)],
                     0.014, 6, "gunmetal", "braid_hose", add_clamps=False)

    # Front armor details: twin headlight cages, tow shackle, grab rail, hazard stripe
    for hi, hx in enumerate([-0.28, 0.28]):
        kb.headlight_cage(f"Headlight{hi}", (hx, hip + 0.11, -0.755), (0, 0, 0))
    _seated_tow_shackle(kb, "FrontTow", (0.0, hip - 0.04, -0.62), (0, 0, 0), 0.95)
    kb.box("FrontHaz", (0.40, 0.042, 0.018), "hazard", "hazard", (0, hip + 0.22, -0.735), (0, 0, 0), 0.003, 1)
    kb.grab_rail("FrontGrab", 0.28, 0.036, (0, hip + 0.266, -0.56), (90, 0, 0), 0.010)
    # Rear cooling louver bay + grab rail
    kb.louver_bay("RearVent", 0.50, 0.20, 0.046, (0, hip + 0.11, 0.745), (0, 180, 0), blades=5, mesh_style=False)
    kb.grab_rail("RearGrab", 0.32, 0.036, (0, hip + 0.266, 0.56), (90, 0, 0), 0.010)

    # --------------------------------------------------------------------------
    # 2. FOUR ARTICULATED HEAVY SPIDER LEGS (Leg_0..Leg_3 -> Femur_i -> Knee_i -> Ankle_i)
    # --------------------------------------------------------------------------
    KN = Vector((0.0, 0.44, 0.98))
    FT = Vector((0.0, -hip + 0.05, 1.42))
    for i, (px, py) in enumerate([(-1, -1), (1, -1), (-1, 1), (1, 1)]):
        yaw_deg = math.degrees(math.atan2(px, py))
        build_heavy_spider_limb(kb, i, f"Q{i}", (px * 0.62, hip, py * 0.62), yaw_deg, KN, FT,
                                scale_w=1.12, oxide_accent=True)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 4. legs_hex — HX-6 Faceted Cruiser 6-Legged Spider Chassis
# ==============================================================================

def build_legs_hex(kb: KitbashScene):
    """HX-6 Cruiser Hex Chassis: faceted armored prow hull, periscope, headlights, twin rear vents, 6 spider legs."""
    hip = 1.28
    socket_y = hip + 0.41  # 1.69m compact low-profile slewing ring!

    # --------------------------------------------------------------------------
    # 1. SLEEK FACETED CRUISER HULL, ANGLED PROW, PERISCOPE, VENTS & 8-RIB BARBETTE
    # --------------------------------------------------------------------------
    kb.use_group("Body")
    kb.box("InnerHull", (0.88, 0.34, 1.96), "dark", "frame_cnc",
           (0, hip, 0.0), (0, 0, 0), 0.022, 1, tile_u=2.0)
    kb.plate("HullDeck", crect_2d(1.24, 2.26, (0.30, 0.30, 0.28, 0.28)), 0.22, "armor", "armor_panel",
             (0, hip + 0.17, 0.0), (90, 0, 0), 0.016, 1)
    kb.plate("HullBelly", crect_2d(0.96, 1.94, (0.24, 0.24, 0.24, 0.24)), 0.18, "armor_sub", "armor_pocket",
             (0, hip - 0.17, 0.0), (90, 0, 0), 0.014, 1)

    # Low-profile conical barbette + 8 stiffening ribs + compact HP-C1 slewing ring
    kb.cyl("BarbetteCone", 0.32, 0.42, 0.08, 14, "armor_sub", "armor_ribs",
           (0, hip + 0.30, 0.0), (0, 0, 0), 0.006)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.32)
    for gi in range(8):
        ga = math.tau * gi / 8.0
        kb.box(f"BarbRib{gi}", (0.040, 0.072, 0.10), "gunmetal", "bolt_flange",
               (math.cos(ga) * 0.36, hip + 0.30, math.sin(ga) * 0.36),
               (0, -math.degrees(ga), 0), 0.005, 1)

    # Sloped +36 deg armored wedge prow + accent + driver periscope + twin headlights + tow shackle
    M_prow = g2b_mat((0.0, hip + 0.04, -1.11), (36.0, 0.0, 0.0))
    kb.plate("ProwArmor", trap_2d(1.10, 0.92, 0.42, 0.06), 0.13, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.015, 1, M_parent=M_prow)
    kb.box("ProwAcc", (0.56, 0.042, 0.022), "accent", "plain_metal",
           (0, 0.11, -0.078), (0, 0, 0), 0.003, 1, M_parent=M_prow)
    kb.box("ProwHaz", (0.42, 0.036, 0.022), "hazard", "hazard",
           (0, -0.13, -0.078), (0, 0, 0), 0.003, 1, M_parent=M_prow)
    _add_periscope(kb, "DriverOptic", 0.24, 0.080, (0, hip + 0.315, -0.88), (0, 0, 0))
    for hi, hx in enumerate([-0.34, 0.34]):
        kb.headlight_cage(f"Headlight{hi}", (hx, hip + 0.12, -1.14), (0, 0, 0))
    _seated_tow_shackle(kb, "FrontTow", (0.0, hip - 0.10, -1.09), (0, 0, 0), 0.90)

    # Rear cruiser deck service hatch + twin rear louver exhaust bays + upright fore-aft deck grab rails
    kb.box("RearHatch", (0.52, 0.044, 0.34), "armor_sub", "armor_hatch",
           (0, hip + 0.296, 0.72), (0, 0, 0), 0.007, 1)
    for vi, vx in enumerate([-0.28, 0.28]):
        kb.louver_bay(f"RearVent{vi}", 0.36, 0.20, 0.042, (vx, hip + 0.06, 1.145), (0, 180, 0),
                      blades=4, mesh_style=False)
    for gi, gx in enumerate([-0.46, 0.46]):
        M_gr = g2b_mat((gx, hip + 0.280, 0.64), (0.0, 90.0, 0.0))
        kb.grab_rail(f"DeckGrab{gi}", 0.28, 0.034, (0, 0, 0), (90, 0, 0), 0.009, M_parent=M_gr)

    # --------------------------------------------------------------------------
    # 2. SIX ARTICULATED HEAVY SPIDER LEGS (Leg_0..Leg_5 -> Femur_i -> Knee_i -> Ankle_i)
    # --------------------------------------------------------------------------
    mounts = [
        (-0.64, -0.96, -0.78), (0.64, -0.96, -0.78),
        (-0.70,  0.0,   0.0),  (0.70,  0.0,   0.0),
        (-0.64,  0.96,  0.78), (0.64,  0.96,  0.78),
    ]
    KN = Vector((0.0, 0.34, 0.82))
    FT = Vector((0.0, -hip + 0.05, 1.22))
    for i, (sx, sz, z_aim) in enumerate(mounts):
        yaw_deg = math.degrees(math.atan2(1.0 if sx > 0 else -1.0, z_aim))
        build_heavy_spider_limb(kb, i, f"H{i}", (sx, hip, sz), yaw_deg, KN, FT,
                                scale_w=0.92, compact_hex=True)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 5. legs_titan — TT-8 Super-Heavy Reverse-Joint Titan Biped Chassis
# ==============================================================================

def build_legs_titan(kb: KitbashScene):
    """TT-8 Titan Biped: massive boxy pelvis, double skirts, ERA knee rams, dual pistons, 4-toe siege feet."""
    hip = 1.72
    socket_y = hip + 0.47  # 2.19m compact low-profile slewing ring clearing outer hips!

    # --------------------------------------------------------------------------
    # 1. MASSIVE BOXY TITAN PELVIS, DOUBLE-LAYERED SKIRTS & HEAVY WAIST COLUMN
    # --------------------------------------------------------------------------
    kb.use_group("Body")
    kb.box("InnerPelvis", (1.06, 0.64, 1.22), "dark", "frame_cnc",
           (0, hip + 0.04, 0.02), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.box("PelvisDeck", (1.02, 0.18, 1.00), "armor_sub", "armor_pocket",
           (0, hip + 0.29, 0.02), (0, 0, 0), 0.018, 1)
    for si, sx in enumerate([-0.55, 0.55]):
        kb.cyl(f"PelvisBoss{si}", 0.30, 0.33, 0.08, 14, "gunmetal", "gear_collar",
               (sx, hip, 0.0), (0, 0, 90), 0.008, u_rep=2.0)

    # Double-layered front ballistic siege apron + accent + hazard + twin heavy tow shackles + grab rail
    M_fsk = g2b_mat((0.0, hip - 0.05, -0.68), (14.0, 0.0, 0.0))
    kb.plate("FrontSkirt1", trap_2d(0.96, 1.18, 0.62, 0.11), 0.18, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_fsk)
    kb.plate("FrontSkirt2", trap_2d(0.68, 0.96, 0.34, 0.07), 0.10, "armor_sub", "armor_ribs",
             (0, -0.02, -0.142), (0, 0, 0), 0.012, 1, M_parent=M_fsk)
    kb.box("FrontAcc", (0.68, 0.064, 0.024), "accent", "plain_metal",
           (0, 0.235, -0.108), (0, 0, 0), 0.004, 1, M_parent=M_fsk)
    kb.box("FrontHaz", (0.54, 0.048, 0.024), "hazard", "hazard",
           (0, -0.245, -0.108), (0, 0, 0), 0.003, 1, M_parent=M_fsk)
    kb.grab_rail("PelvisGrab", 0.38, 0.042, (0, 0.135, -0.188), (0, 0, 0), 0.011, M_parent=M_fsk)
    for ti, tx in enumerate([-0.36, 0.36]):
        _seated_tow_shackle(kb, f"PelvisTow{ti}", (tx, -0.17, -0.118), (0, 0, 0), 1.15, M_parent=M_fsk)

    # Rear double-layered ballistic skirt + wide cooling louver mesh bay
    M_rsk = g2b_mat((0.0, hip - 0.05, 0.68), (-12.0, 0.0, 0.0))
    kb.plate("RearSkirt", trap_2d(1.02, 1.18, 0.56, 0.10), 0.18, "armor_sub", "armor_hatch",
             (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_rsk)
    kb.louver_bay("PelvisVent", 0.74, 0.22, 0.050, (0, 0.01, 0.114), (0, 180, 0),
                  blades=5, mesh_style=True, M_parent=M_rsk)

    # Compact stepped waist collar + unified HP-C1 slewing ring + 6 short hydraulic hoses
    kb.cyl("WaistPlinth", 0.33, 0.40, 0.07, 16, "gunmetal", "armor_ribs",
           (0, hip + 0.38, 0.0), (0, 0, 0), 0.006)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.39)
    for hi in range(6):
        ha = math.tau * hi / 6.0 + 0.30
        ca, sa = math.cos(ha), math.sin(ha)
        kb.tube_path(f"WaistHose{hi}",
                     [(ca * 0.42, hip + 0.36, sa * 0.42),
                      (ca * 0.37, hip + 0.40, sa * 0.37),
                      (ca * 0.28, hip + 0.43, sa * 0.28)],
                     0.015, 6, "gunmetal", "braid_hose", add_clamps=False)

    # --------------------------------------------------------------------------
    # 2. SUPER-HEAVY REVERSE-JOINT TITAN LEGS (Leg_L / Leg_R -> Knee -> Ankle)
    # --------------------------------------------------------------------------
    KN = Vector((0.0, -0.74, -0.34))
    AN = Vector((0.0, -1.24,  0.20))
    rel_an = AN - KN  # (0.0, -0.50, +0.54)
    sole_rel = -3.425  # Exact match to legs_titan.gd (-1.52 - 0.185 - 1.72)

    for side_tag, pfx, sx in [("Leg_L", "TL", -0.92), ("Leg_R", "TR", 0.92)]:
        side = -1.0 if sx < 0 else 1.0
        g_leg = kb.add_group(side_tag, side_tag, pos=(sx, hip, 0.0))
        kb.use_group(g_leg)
        kb.add_marker("MARK_SOLE", (0.0, sole_rel, 0.0), parent_key=g_leg)

        # Colossal hip actuator drum + massive armored hip shield + ERA strip + 4 heavy bolts + grab rail
        _compact_actuator(kb, f"{pfx}_HipDrum", (-side * 0.02, 0, 0), 0.40, 0.54, segs=14, n_bolts=4)
        kb.box(f"{pfx}_HipMount", (0.16, 0.30, 0.44), "dark", "frame_cnc",
               (side * 0.32, -0.04, 0.0), (0, 0, 0), 0.014, 1)
        M_hsh = g2b_mat((side * 0.46, -0.06, 0.0), (0.0, side * -90.0, 0.0))
        kb.plate(f"{pfx}_HipShield", crect_2d(1.18, 0.94, (0.28, 0.14, 0.04, 0.24)), 0.15, "armor_sub", "armor_panel",
                 (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_hsh)
        kb.box(f"{pfx}_HipAcc", (0.68, 0.088, 0.024), "accent", "plain_metal",
               (0, 0.31, -0.092), (0, 0, 0), 0.004, 1, M_parent=M_hsh)
        kb.era_block(f"{pfx}_HipERA", (0.56, 0.24, 0.068), "armor",
                     (0, -0.02, -0.112), (0, 0, 0), M_parent=M_hsh)
        for bi in range(4):
            kb.cyl(f"{pfx}_HipBolt{bi}", 0.026, 0.030, 0.036, 6, "chrome", "plain_metal",
                   (-0.39 + bi * 0.26, -0.34, -0.096), (90, 0, 0), 0.003, M_parent=M_hsh)
        kb.grab_rail(f"{pfx}_HipGrab", 0.28, 0.042, (0, 0.18, -0.080), (0, 0, 0), 0.011, M_parent=M_hsh)

        # Bulky reverse-joint Titan thigh (H=0 -> KN): stepped narrower than KneeDrum (0.74 -> +/-0.37)
        M_th = g2b_bone_mat((0, 0, 0), KN)
        l1 = KN.length
        l1_s = l1 - 0.28
        y_th_m = -(0.15 + 0.5 * l1_s)
        kb.box(f"{pfx}_InnerThigh", (0.52, l1_s, 0.72), "armor_sub", "armor_pocket",
               (0, y_th_m, 0.04), (0, 0, 0), 0.024, 1, M_parent=M_th)
        kb.plate(f"{pfx}_ThighF1", trap_2d(0.56, 0.70, l1_s * 0.94, 0.10), 0.16, "armor", "armor_panel",
                 (0, y_th_m, -0.40), (-3, 0, 0), 0.018, 1, M_parent=M_th)
        kb.plate(f"{pfx}_ThighF2", crect_2d(0.44, l1_s * 0.54, (0.08, 0.08, 0.02, 0.02)), 0.090, "armor_sub", "armor_hatch",
                 (0, y_th_m + 0.06, -0.525), (-3, 0, 0), 0.012, 1, M_parent=M_th)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{pfx}_ThighSide{s2i}", crect_2d(0.66, l1_s * 0.84, (0.10, 0.14, 0.14, 0.10)), 0.084,
                     "armor", "armor_ribs", (s2 * 0.304, y_th_m, 0.04), (0, s2 * -90.0, 0), 0.014, 1, M_parent=M_th)
        for ri in range(5):
            ry = -0.18 - (l1_s - 0.08) * ri / 4.0
            kb.cyl(f"{pfx}_ThighRiv{ri}", 0.016, 0.019, 0.028, 6, "chrome", "plain_metal",
                   (side * 0.354, ry, -0.18), (0, 0, 90), 0.002, M_parent=M_th)
        kb.box(f"{pfx}_ThighRear", (0.42, l1_s * 0.76, 0.20), "dark", "frame_cnc",
               (0, y_th_m, 0.52), (0, 0, 0), 0.014, 1, M_parent=M_th)
        for hxi, hx in enumerate([-0.15, 0.15]):
            _compact_hydraulic(kb, f"{pfx}_ThighHyd{hxi}",
                               (hx, -0.16, 0.69), (hx, -l1 + 0.16, 0.69), 0.036, 8, pins=False, M_parent=M_th)
        kb.tube_path(f"{pfx}_ThighHose",
                     [(side * 0.22, -0.18, 0.48), (side * 0.32, -0.50, 0.46), (side * 0.22, KN.y + 0.04, KN.z + 0.22)],
                     0.028, 6, "gunmetal", "braid_hose", add_clamps=False)

        # Heavy Knee Actuator Drum (widest X-step: 0.74 -> +/-0.37) + ERA Battering-Ram Knee Guard
        _compact_actuator(kb, f"{pfx}_KneeDrum", KN, 0.33, 0.74, segs=14, n_bolts=4)
        M_kp = g2b_mat((KN.x, KN.y + 0.04, KN.z - 0.40), (-10.0, 0.0, 0.0))
        kb.plate(f"{pfx}_KneeBase", trap_2d(0.70, 0.80, 0.52, 0.10), 0.22, "armor_sub", "armor_pocket",
                 (0, -0.02, 0.02), (0, 0, 0), 0.018, 1, M_parent=M_kp)
        kb.plate(f"{pfx}_KneeCap", trap_2d(0.46, 0.56, 0.34, 0.07), 0.12, "armor", "armor_panel",
                 (0, 0.03, -0.145), (-8, 0, 0), 0.012, 1, M_parent=M_kp)
        kb.era_block(f"{pfx}_KneeERA", (0.36, 0.16, 0.068), "armor_sub",
                     (0, 0.05, -0.238), (-8, 0, 0), M_parent=M_kp)
        for kxi, kx in enumerate([-0.42, 0.42]):
            kb.cyl(f"{pfx}_KneePin{kxi}", 0.046, 0.046, 0.060, 8, "chrome", "plain_metal",
                   (kx, 0.03, 0.02), (0, 0, 90), 0.005, M_parent=M_kp)

        # ---- KNEE PIVOT GROUP (Thick Armored Shins + Dual Heavy Rear Pistons) ----
        g_knee = kb.add_group(f"{side_tag}/Knee", "Knee", pos=(KN.x, KN.y, KN.z), parent_key=g_leg)
        kb.use_group(g_knee)
        l2 = rel_an.length
        l2_s = l2 - 0.24
        y_sh_m = -(0.13 + 0.5 * l2_s)
        M_sh = g2b_bone_mat((0, 0, 0), rel_an)

        kb.box(f"{pfx}_InnerShin", (0.48, l2_s, 0.70), "armor_sub", "armor_pocket",
               (0, y_sh_m, 0.05), (0, 0, 0), 0.022, 1, M_parent=M_sh)
        kb.plate(f"{pfx}_ShinFront", trap_2d(0.50, 0.64, l2_s * 0.94, 0.08), 0.16, "armor", "armor_panel",
                 (0, y_sh_m, -0.38), (0, 0, 0), 0.018, 1, M_parent=M_sh)
        kb.louver_bay(f"{pfx}_ShinVent", 0.34, 0.22, 0.038, (0, y_sh_m + 0.02, -0.478), (0, 0, 0),
                      blades=4, mesh_style=True, M_parent=M_sh)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{pfx}_ShinSide{s2i}", crect_2d(0.62, l2_s * 0.84, (0.10, 0.06, 0.06, 0.10)), 0.084,
                     "armor", "armor_ribs", (s2 * 0.284, y_sh_m, 0.05), (0, s2 * -90.0, 0), 0.012, 1, M_parent=M_sh)
            kb.grab_rail(f"{pfx}_ShinGrab{s2i}", 0.22, 0.040,
                         (s2 * 0.332, y_sh_m + 0.08, 0.05), (0, s2 * -90.0, 0), 0.011, M_parent=M_sh)
        _compact_hydraulic(kb, f"{pfx}_ShinHydMain", (0.0, -0.10, 0.44),
                           (rel_an.x, rel_an.y + 0.20, rel_an.z + 0.38), 0.052, 8, pins=False)
        _compact_hydraulic(kb, f"{pfx}_ShinHydAux", (side * 0.22, -0.10, 0.40),
                           (rel_an.x + side * 0.22, rel_an.y + 0.20, rel_an.z + 0.34), 0.036, 8, pins=False)

        # ---- ANKLE PIVOT GROUP (Elephantine 4-Toe Siege Foot + Articulated Knuckles + Hydraulic Heel Spade) ----
        g_ank = kb.add_group(f"{side_tag}/Ankle", "Ankle", pos=(rel_an.x, rel_an.y, rel_an.z), parent_key=g_knee)
        kb.use_group(g_ank)
        _compact_actuator(kb, f"{pfx}_AnkDrum", (0, 0, 0), 0.24, 0.44, segs=12, n_bolts=4)
        ft_off = Vector((0.0, -1.50, 0.06)) - AN  # (0, -0.26, -0.14) -> world Y = +0.22m (ground = -0.22m!)
        M_ft = g2b_mat((ft_off.x, ft_off.y, ft_off.z), (0, 0, 0))

        kb.box(f"{pfx}_AnkBridge", (0.36, 0.20, 0.34), "dark", "frame_cnc",
               (0, 0.16, 0.10), (0, 0, 0), 0.014, 1, M_parent=M_ft)
        kb.box(f"{pfx}_FootBlock", (0.82, 0.30, 0.96), "gunmetal", "frame_cnc",
               (0, 0.00, 0.0), (0, 0, 0), 0.020, 1, M_parent=M_ft)
        kb.plate(f"{pfx}_FootInstep", trap_2d(0.80, 0.58, 0.50, 0.07), 0.18, "armor_sub", "armor_panel",
                 (0, 0.21, -0.20), (-58, 0, 0), 0.016, 1, M_parent=M_ft)
        kb.box(f"{pfx}_FootSole", (0.86, 0.080, 1.00), "rubber", "dust_boot",
               (0, -0.180, 0.0), (0, 0, 0), 0.010, 1, M_parent=M_ft)

        for ti in range(4):
            tx = -0.315 + ti * 0.21
            tyaw = (ti - 1.5) * 7.5
            M_toe = M_ft @ g2b_mat((tx, -0.04, -0.47), (0.0, tyaw, 0.0))
            kb.cyl(f"{pfx}_ToeKnk{ti}", 0.052, 0.052, 0.16, 8, "dark", "gear_collar",
                   (0, 0.06, 0.02), (0, 0, 90), 0.004, M_parent=M_toe)
            kb.plate(f"{pfx}_ToeArm{ti}", trap_2d(0.17, 0.13, 0.28, 0.025), 0.16, "armor", "armor_ribs",
                     (0, 0.00, -0.11), (-72, 0, 0), 0.011, 1, M_parent=M_toe)
            kb.box(f"{pfx}_ToeTip{ti}", (0.16, 0.065, 0.095), "gunmetal", "bolt_flange",
                   (0, -0.10, -0.24), (16, 0, 0), 0.007, 1, M_parent=M_toe)
            kb.box(f"{pfx}_ToePad{ti}", (0.175, 0.065, 0.31), "rubber", "dust_boot",
                   (0, -0.1475, -0.11), (0, 0, 0), 0.007, 1, M_parent=M_toe)

        kb.box(f"{pfx}_HeelSpade", (0.62, 0.22, 0.24), "armor_sub", "armor_pocket",
               (0, -0.03, 0.54), (12, 0, 0), 0.015, 1, M_parent=M_ft)
        kb.box(f"{pfx}_HeelPad", (0.60, 0.060, 0.20), "rubber", "dust_boot",
               (0, -0.190, 0.54), (0, 0, 0), 0.007, 1, M_parent=M_ft)
        for hhi, hhx in enumerate([-0.22, 0.22]):
            _compact_hydraulic(kb, f"{pfx}_HeelHyd{hhi}",
                               (hhx, 0.19, 0.28), (hhx, 0.01, 0.55), 0.030, 6, pins=False, M_parent=M_ft)
        kb.box(f"{pfx}_HeelHaz", (0.26, 0.032, 0.090), "hazard", "hazard",
               (0, 0.165, 0.43), (0, 0, 0), 0.003, 1, M_parent=M_ft)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))
