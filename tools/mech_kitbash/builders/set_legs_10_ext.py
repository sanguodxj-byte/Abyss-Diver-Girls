"""
Extended 10 High-Precision Mech Leg Chassis Pack — B.o.T Heavy-Duty & Precision Double-Pin Track Standard.
Covers all 10 extended articulated & tracked leg modules:
  1. legs_biped_scout   (LN-3 Muscular Digitigrade Biped w/ Dual Booster Pods & 3-Talon Hydraulic Raptor Feet)
  2. legs_quad_crab     (CR-6 Heavy Bunker Crab Quad w/ Winch, ERA-Tiled 3D Carapace Limbs & Wide Siege Pads)
  3. legs_quad_hound    (HD-4 Bio-Mechanical Sprint Quad w/ LIDAR Roll-Cage & Muscular Reverse-Joint Limbs)
  4. legs_quad_mammoth  (MM-10 Heavy Gantry Outrigger Quad w/ Twin-Cylinder Pile-Driver Columns & 4-Spade Feet)
  5. legs_hex_ant       (AT-6 Sapper Hexapod w/ Electric Winch, Spotlights, Cargo Rack & Heavy 6-Limb Rig)
  6. legs_hex_beetle    (BT-9 Heavy Carapace Hexapod w/ Twin Breaching Rams & ERA-Reinforced Beetle Limbs)
  7. legs_hex_colossus  (CL-12 Siege Fortress Hexapod w/ Battering Dozer Plow & 6 Twin-Ram Hydraulic Columns)
  8. legs_tread_light   (MT-2 High-Speed Christie Tracked Chassis w/ 44-Link Double-Pin Tracks & Dished Wheels)
  9. legs_tread_heavy   (KV-6 V-Dozer ERA Heavy Tracked Chassis w/ 50-Link Double-Pin Tracks & 6 Dual Bogies)
 10. legs_tread_siege   (DT-9 Obj-279 Nuclear-Blast Saucer + 4 Articulated 32-Link Double-Pin Track Pods)
"""
import math
from mathutils import Vector
from kitbash_lib import KitbashScene, g2b_mat, g2b_bone_mat, crect_2d, trap_2d
from leg_rig_lib import heavy_hyd, heavy_drum, build_precision_track_pod, build_heavy_spider_limb


# ==============================================================================
# 1. legs_biped_scout — LN-3 Muscular Digitigrade Recon Biped
# ==============================================================================
def build_legs_biped_scout(kb: KitbashScene):
    hip = 1.54
    socket_y = hip + 0.41  # 1.95m compact flush waist ring!

    kb.use_group("Body")
    kb.box("PelvisTruss", (0.80, 0.38, 0.72), "dark", "frame_cnc", (0, hip + 0.04, 0.0), (0, 0, 0), 0.020, 1)
    kb.box("PelvisDeck", (0.76, 0.18, 0.62), "armor_sub", "armor_pocket", (0, hip + 0.24, 0.02), (0, 0, 0), 0.016, 1)
    kb.plate("FrontApron", trap_2d(0.56, 0.80, 0.44, 0.06), 0.13, "armor", "armor_slab", (0, hip + 0.01, -0.40), (18, 0, 0), 0.018, 1)
    kb.plate("FrontApronSub", trap_2d(0.38, 0.56, 0.26, 0.04), 0.06, "armor_oxide", "weld_plate", (0, hip - 0.02, -0.482), (18, 0, 0), 0.010, 1)
    kb.decal("ScoutUnit", "ord_12", (0.20, 0.16), (0, hip - 0.02, -0.520), (18, 0, 0))
    kb.box("FrontHaz", (0.36, 0.044, 0.024), "hazard", "hazard", (0, hip + 0.16, -0.436), (18, 0, 0), 0.003, 1)
    kb.plate("RearApron", trap_2d(0.68, 0.92, 0.40, 0.06), 0.12, "armor_sub", "weld_plate", (0, hip + 0.01, 0.40), (-16, 0, 0), 0.016, 1)
    kb.louver_bay("ScoutRearVent", 0.48, 0.16, 0.040, (0, hip + 0.04, 0.468), (-16, 180, 0), blades=4)

    # Twin heavy angled vectored jump-booster pods on pelvis flanks
    for si, sx in enumerate([-0.54, 0.54]):
        sd = -1.0 if sx < 0 else 1.0
        M_bp = g2b_mat((sx, hip + 0.14, 0.28), (-28, sd * 14.0, sd * -12.0))
        kb.cyl(f"JumpPod_{si}", 0.125, 0.140, 0.54, 16, "armor_oxide", "armor_pocket", (0, 0, 0), (90, 0, 0), 0.008, M_parent=M_bp)
        kb.cyl(f"JumpCollar_{si}", 0.146, 0.146, 0.08, 16, "gunmetal", "gear_collar", (0, 0, 0.16), (90, 0, 0), 0.004, M_parent=M_bp)
        kb.cyl(f"JumpNoz_{si}", 0.082, 0.115, 0.15, 14, "dark", "plain_metal", (0, 0, 0.31), (90, 0, 0), 0.005, hollow_r=0.064, M_parent=M_bp)
        kb.cyl(f"JumpGlow_{si}", 0.056, 0.056, 0.024, 12, "emit_amber", "plain_metal", (0, 0, 0.27), (90, 0, 0), 0.002, M_parent=M_bp)

    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.32)
    for sx_i, sx_g in enumerate([-0.32, 0.32]):
        heavy_hyd(kb, f"WaistStab_{sx_i}", (sx_g, hip + 0.26, -0.20), (sx_g * 0.66, hip + 0.37, -0.14), 0.018, 8, pins=False)

    KN = Vector((0.0, -0.74, -0.36))
    AN = Vector((0.0, -1.26,  0.24))
    rel_an = AN - KN
    sole_rel = -1.44 - 0.096 - hip

    for side_tag, pfx, sx in [("Leg_L", "SL", -0.66), ("Leg_R", "SR", 0.66)]:
        side = -1.0 if sx < 0 else 1.0
        g_leg = kb.add_group(side_tag, side_tag, pos=(sx, hip, 0.0))
        kb.use_group(g_leg)
        kb.add_marker("MARK_SOLE", (0.0, sole_rel, 0.0), parent_key=g_leg)

        # Oversized hip drum + broad layered hip wing carapace (stepped X planes)
        heavy_drum(kb, f"{pfx}_Hip", (-side * 0.02, 0, 0), 0.24, 0.42, segs=16, n_bolts=6)
        kb.plate(f"{pfx}_HipWing", crect_2d(0.60, 0.48, (0.14, 0.08, 0.05, 0.12)), 0.10, "armor_sub", "armor_panel",
                 (side * 0.29, 0.02, 0.0), (0, side * 90.0, 0), 0.014, 1)
        kb.plate(f"{pfx}_HipWingSub", crect_2d(0.40, 0.26, (0.06, 0.04, 0.04, 0.06)), 0.055, "armor", "armor_ribs",
                 (side * 0.375, 0.04, 0.02), (0, side * 90.0, 0), 0.008, 1)

        # Muscular 3D Digitigrade Thigh Cowl + Twin Hydraulics + Heavy Coil Shock
        M_th = g2b_bone_mat((0, 0, 0), KN)
        l1 = KN.length
        l1_s = l1 - 0.26
        y_th_m = -(0.14 + 0.5 * l1_s)
        kb.box(f"{pfx}_ThCore", (0.30, l1_s, 0.40), "dark", "frame_cnc", (0, y_th_m, 0.02), (0, 0, 0), 0.016, 1, M_parent=M_th)
        kb.plate(f"{pfx}_ThFront", trap_2d(0.38, 0.48, l1_s * 0.94, 0.06), 0.15, "armor", "armor_slab", (0, y_th_m, -0.22), (-4, 0, 0), 0.020, 1, M_parent=M_th)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{pfx}_ThCheek{s2i}", crect_2d(0.36, l1_s * 0.84, (0.06, 0.06, 0.04, 0.04)), 0.072,
                     "armor_sub", "armor_ribs", (s2 * 0.184, y_th_m, 0.02), (0, s2 * 90.0, 0), 0.012, 1, M_parent=M_th)
        if side > 0:
            kb.decal(f"{pfx}_Tri", "hazard_tri", (0.14, 0.14), (0, y_th_m + 0.04, -0.304), (-4, 0, 0), M_parent=M_th)
        heavy_hyd(kb, f"{pfx}_ThHyd", (side * 0.11, -0.14, 0.24), (side * 0.11, -l1 + 0.14, 0.24), 0.026, 8, pins=False, M_parent=M_th)
        kb.coil_shock(f"{pfx}_ThShock", (-side * 0.08, -0.10, 0.22), (KN.x - side * 0.08, KN.y + 0.12, KN.z + 0.20), 0.036)

        # Heavy Knee Drum (widest X-step: 0.48 -> +/-0.24) + Forward Ballistic Knee Ram Cap
        heavy_drum(kb, f"{pfx}_KnDrum", KN, 0.20, 0.48, segs=14, n_bolts=4)
        M_kc = g2b_mat((KN.x, KN.y + 0.02, KN.z - 0.24), (-14, 0, 0))
        kb.plate(f"{pfx}_KneeCap", trap_2d(0.38, 0.46, 0.32, 0.05), 0.14, "armor_oxide" if side > 0 else "armor", "weld_plate",
                 (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_kc)

        # Muscular Flared Reverse-Joint Shin Greave + Coilover Shock
        g_knee = kb.add_group(f"{side_tag}/Knee", "Knee", pos=(KN.x, KN.y, KN.z), parent_key=g_leg)
        kb.use_group(g_knee)
        l2 = rel_an.length
        l2_s = l2 - 0.26
        y_sh_m = -(0.14 + 0.5 * l2_s)
        M_sh = g2b_bone_mat((0, 0, 0), rel_an)
        kb.box(f"{pfx}_ShinCore", (0.28, l2_s, 0.36), "dark", "frame_cnc", (0, y_sh_m, 0.02), (0, 0, 0), 0.014, 1, M_parent=M_sh)
        kb.plate(f"{pfx}_ShinFront", trap_2d(0.36, 0.48, l2_s * 0.94, 0.06), 0.14, "armor", "armor_slab", (0, y_sh_m, -0.20), (0, 0, 0), 0.018, 1, M_parent=M_sh)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{pfx}_ShinSide{s2i}", trap_2d(0.32, 0.24, l2_s * 0.84, 0.04), 0.068, "armor_sub", "weld_plate",
                     (s2 * 0.172, y_sh_m, 0.01), (0, s2 * 90.0, 0), 0.012, 1, M_parent=M_sh)
        kb.coil_shock(f"{pfx}_ShinShock", (0, -0.10, 0.24), (rel_an.x, rel_an.y + 0.12, rel_an.z + 0.20), 0.036)

        # Wide Planted 3-Talon Hydraulic Raptor Siege Foot
        g_ank = kb.add_group(f"{side_tag}/Ankle", "Ankle", pos=(rel_an.x, rel_an.y, rel_an.z), parent_key=g_knee)
        kb.use_group(g_ank)
        heavy_drum(kb, f"{pfx}_Ank", (0, 0, 0), 0.155, 0.32, segs=12, n_bolts=4)
        ft_off = Vector((0.0, -1.44, 0.06)) - AN
        M_ft = g2b_mat((ft_off.x, ft_off.y, ft_off.z), (0, 0, 0))
        kb.box(f"{pfx}_FootHub", (0.48, 0.16, 0.44), "gunmetal", "frame_cnc", (0, 0.02, 0.04), (0, 0, 0), 0.014, 1, M_parent=M_ft)
        kb.plate(f"{pfx}_Instep", trap_2d(0.46, 0.34, 0.30, 0.04), 0.12, "armor", "armor_panel", (0, 0.13, -0.10), (-66, 0, 0), 0.012, 1, M_parent=M_ft)
        for ti, (tx, tyaw, tl) in enumerate([(-0.18, -16.0, 0.44), (0.0, 0.0, 0.52), (0.18, 16.0, 0.44)]):
            M_t = M_ft @ g2b_mat((tx, -0.02, -0.14), (0, tyaw, 0))
            kb.box(f"{pfx}_Talon_{ti}", (0.13, 0.092, tl * 0.72), "armor_sub", "armor_ribs", (0, 0.024, -tl * 0.36), (6, 0, 0), 0.010, 1, M_parent=M_t)
            kb.plate(f"{pfx}_Claw_{ti}", trap_2d(0.11, 0.06, tl * 0.38, 0.015), 0.085, "chrome", "plain_metal", (0, 0.005, -tl * 0.80), (88, 0, 0), 0.008, 1, M_parent=M_t)
            pad_h = 0.042 if ti == 1 else 0.034
            pad_y = -0.055 if ti == 1 else -0.059
            pad_l = tl * 0.82 if ti == 1 else tl * 0.66
            pad_z = -tl * 0.46 if ti == 1 else -tl * 0.54
            kb.box(f"{pfx}_Pad_{ti}", (0.130, pad_h, pad_l), "rubber", "dust_boot", (0, pad_y, pad_z), (0, 0, 0), 0.0, 1, M_parent=M_t)
        kb.box(f"{pfx}_Heel", (0.28, 0.10, 0.34), "gunmetal", "bolt_flange", (0, 0.005, 0.28), (-8, 0, 0), 0.010, 1, M_parent=M_ft)
        kb.box(f"{pfx}_HeelPad", (0.30, 0.036, 0.32), "rubber", "dust_boot", (0, -0.060, 0.28), (0, 0, 0), 0.0, 1, M_parent=M_ft)
        heavy_hyd(kb, f"{pfx}_HeelHyd", (0, 0.15, 0.18), (0, 0.04, 0.36), 0.022, 6, pins=False, M_parent=M_ft)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


def _build_multi_hull_common(kb: KitbashScene, hip: float, socket_y: float, hull_w: float, hull_z: float, oxide_prow=False):
    kb.use_group("Body")
    kb.box("InnerHull", (hull_w * 0.78, 0.36, hull_z * 0.86), "dark", "frame_cnc", (0, hip, 0.0), (0, 0, 0), 0.022, 1)
    kb.plate("HullDeck", crect_2d(hull_w, hull_z, (0.28, 0.28, 0.26, 0.26)), 0.22, "armor", "armor_slab", (0, hip + 0.17, 0.0), (90, 0, 0), 0.020, 1)
    kb.plate("HullBelly", crect_2d(hull_w * 0.80, hull_z * 0.82, (0.22, 0.22, 0.22, 0.22)), 0.18, "armor_sub", "armor_pocket", (0, hip - 0.17, 0.0), (90, 0, 0), 0.016, 1)
    kb.cyl("Barbette", 0.32, 0.42, 0.075, 18, "armor_oxide" if oxide_prow else "armor_sub", "weld_plate", (0, hip + 0.30, 0.0), (0, 0, 0), 0.006)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.32)
    for gi in range(8):
        ga = math.tau * gi / 8.0
        kb.box(f"BarbRib{gi}", (0.040, 0.068, 0.10), "gunmetal", "bolt_flange",
               (math.cos(ga) * 0.36, hip + 0.30, math.sin(ga) * 0.36), (0, -math.degrees(ga), 0), 0.004, 1)


# ==============================================================================
# 2. legs_quad_crab — CR-6 Heavy Bunker Crab Quad
# ==============================================================================
def build_legs_quad_crab(kb: KitbashScene):
    hip = 1.24
    socket_y = hip + 0.40
    _build_multi_hull_common(kb, hip, socket_y, 1.76, 1.58, oxide_prow=True)
    kb.box("WinchFrame", (0.82, 0.22, 0.24), "gunmetal", "bolt_flange", (0, hip - 0.02, -0.88), (0, 0, 0), 0.012, 1)
    kb.cyl("WinchSpool", 0.105, 0.105, 0.48, 14, "copper", "braid_hose", (0, hip - 0.02, -0.94), (0, 0, 90), 0.004)
    kb.tow_shackle("WinchHook", (0, hip - 0.04, -1.06), (0, 0, 0), 1.05)
    kb.decal("CrabStencil", "unit_08", (0.24, 0.16), (0, hip + 0.16, -0.795), (0, 0, 0))
    for hi, hx in enumerate([-0.46, 0.46]):
        kb.headlight_cage(f"CrabLamp{hi}", (hx, hip + 0.12, -0.83), (0, 0, 0))
    kb.louver_bay("CrabRearVent", 0.68, 0.22, 0.045, (0, hip + 0.08, 0.81), (0, 180, 0), blades=5)

    KN = Vector((0.0, 0.36, 0.96))
    FT = Vector((0.0, -hip + 0.05, 1.44))
    for i, (px, py) in enumerate([(-1, -1), (1, -1), (-1, 1), (1, 1)]):
        yaw = math.degrees(math.atan2(px, py))
        build_heavy_spider_limb(kb, i, f"CR{i}", (px * 0.72, hip, py * 0.60), yaw, KN, FT,
                                scale_w=1.16, has_era=True, oxide_accent=True)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 3. legs_quad_hound — HD-4 Muscular Bio-Mechanical LIDAR Sprint Quad
# ==============================================================================
def build_legs_quad_hound(kb: KitbashScene):
    hip = 1.32
    socket_y = hip + 0.37
    kb.use_group("Body")
    kb.box("SpineBeam", (0.58, 0.34, 1.82), "dark", "frame_cnc", (0, hip + 0.03, 0.0), (0, 0, 0), 0.020, 1)
    kb.plate("SpineCarapace", crect_2d(1.12, 1.76, (0.24, 0.24, 0.20, 0.20)), 0.20, "armor", "armor_slab", (0, hip + 0.19, 0.0), (90, 0, 0), 0.018, 1)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.28)
    kb.eoir_gimbal("LidarHead", (0, hip + 0.08, -1.02))
    kb.grab_rail("LidarCageTop", 0.40, 0.14, (0, hip + 0.24, -1.02), (0, 0, 0), 0.012)
    kb.grab_rail("LidarCageBot", 0.40, 0.14, (0, hip - 0.06, -1.02), (0, 0, 0), 0.012)
    kb.louver_bay("HoundRearRad", 0.52, 0.20, 0.042, (0, hip + 0.06, 0.94), (0, 180, 0), blades=4, mesh_style=True)

    KN = Vector((0.0, -0.46, 0.52))
    FT = Vector((0.0, -(hip - 0.04) + 0.04, 0.86))
    for i, (px, py) in enumerate([(-1, -1), (1, -1), (-1, 1), (1, 1)]):
        yaw = math.degrees(math.atan2(px, py * 1.4))
        build_heavy_spider_limb(kb, i, f"HD{i}", (px * 0.54, hip - 0.04, py * 0.68), yaw, KN, FT,
                                scale_w=0.98, has_era=False, oxide_accent=False)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 4. legs_quad_mammoth — MM-10 Heavy Gantry Outrigger Quad
# ==============================================================================
def build_legs_quad_mammoth(kb: KitbashScene):
    hip = 1.52
    socket_y = hip + 0.40
    _build_multi_hull_common(kb, hip, socket_y, 1.76, 1.76, oxide_prow=False)
    for ci, (cx, cz) in enumerate([(-0.80, -0.80), (0.80, -0.80), (-0.80, 0.80), (0.80, 0.80)]):
        kb.box(f"CornerBumper{ci}", (0.26, 0.28, 0.26), "hazard", "hazard", (cx, hip + 0.04, cz), (0, 0, 0), 0.010, 1)
    kb.headlight_cage("MamLampL", (-0.42, hip + 0.10, -0.92))
    kb.headlight_cage("MamLampR", ( 0.42, hip + 0.10, -0.92))
    kb.louver_bay("MamVent", 0.70, 0.24, 0.045, (0, hip + 0.06, 0.90), (0, 180, 0), blades=5)

    KN = Vector((0.0, 0.10, 0.78))
    FT = Vector((0.0, -(hip + 0.02) + 0.06, 0.96))
    for i, (px, py) in enumerate([(-1, -1), (1, -1), (-1, 1), (1, 1)]):
        yaw = math.degrees(math.atan2(px, py))
        build_heavy_spider_limb(kb, i, f"MM{i}", (px * 0.74, hip + 0.02, py * 0.74), yaw, KN, FT,
                                scale_w=1.20, pile_style=True, oxide_accent=True)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 5. legs_hex_ant — AT-6 Combat Engineer Heavy Truss Hexapod
# ==============================================================================
def build_legs_hex_ant(kb: KitbashScene):
    hip = 1.18
    socket_y = hip + 0.40
    _build_multi_hull_common(kb, hip, socket_y, 1.18, 2.24, oxide_prow=False)
    for sx_i, sx in enumerate([-0.54, 0.54]):
        kb.cyl(f"SideLongTube{sx_i}", 0.046, 0.046, 2.02, 10, "gunmetal", "plain_metal", (sx, hip - 0.12, 0.0), (90, 0, 0), 0.003)
    kb.cyl("FrontWinch", 0.098, 0.098, 0.42, 12, "copper", "braid_hose", (0, hip - 0.04, -1.18), (0, 0, 90), 0.004)
    kb.box("WinchBrk", (0.86, 0.18, 0.16), "gunmetal", "bolt_flange", (0, hip - 0.04, -1.12), (0, 0, 0), 0.010, 1)
    kb.headlight_cage("AntLampL", (-0.34, hip + 0.12, -1.14))
    kb.headlight_cage("AntLampR", ( 0.34, hip + 0.12, -1.14))
    kb.stowage_rack("AntRearRack", (0, hip + 0.14, 1.18), (0, 180, 0))

    mounts = [(-0.56, -0.94, -0.78), (0.56, -0.94, -0.78), (-0.62, 0.0, 0.0), (0.62, 0.0, 0.0), (-0.56, 0.94, 0.78), (0.56, 0.94, 0.78)]
    KN = Vector((0.0, 0.28, 0.72))
    FT = Vector((0.0, -(hip - 0.02) + 0.04, 1.08))
    for i, (sx, sz, za) in enumerate(mounts):
        yaw = math.degrees(math.atan2(1.0 if sx > 0 else -1.0, za))
        build_heavy_spider_limb(kb, i, f"AT{i}", (sx, hip - 0.02, sz), yaw, KN, FT,
                                scale_w=0.88, compact_hex=True)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 6. legs_hex_beetle — BT-9 Heavy Carapace Assault Hexapod
# ==============================================================================
def build_legs_hex_beetle(kb: KitbashScene):
    hip = 1.26
    socket_y = hip + 0.40
    _build_multi_hull_common(kb, hip, socket_y, 1.58, 2.44, oxide_prow=True)
    for si, sx in enumerate([-0.38, 0.38]):
        M_rm = g2b_mat((sx, hip - 0.02, -1.34), (14, sx * -12.0, 0))
        kb.plate(f"BeetleHorn{si}", trap_2d(0.28, 0.10, 0.62, 0.02), 0.16, "gunmetal", "bolt_flange", (0, 0, -0.24), (82, 0, 0), 0.012, 1, M_parent=M_rm)
        kb.era_block(f"SideERA{si}", (0.44, 0.19, 0.065), "armor_oxide", (sx * 1.82, hip + 0.22, -0.46), (0, math.copysign(90.0, sx), math.copysign(22.0, -sx)))
    kb.decal("BeetleStencil", "unit_54", (0.26, 0.18), (0, hip + 0.19, -1.230), (0, 0, 0))

    mounts = [(-0.74, -1.00, -0.80), (0.74, -1.00, -0.80), (-0.80, 0.0, 0.0), (0.80, 0.0, 0.0), (-0.74, 1.00, 0.80), (0.74, 1.00, 0.80)]
    KN = Vector((0.0, 0.30, 0.82))
    FT = Vector((0.0, -(hip - 0.04) + 0.05, 1.24))
    for i, (sx, sz, za) in enumerate(mounts):
        yaw = math.degrees(math.atan2(1.0 if sx > 0 else -1.0, za))
        build_heavy_spider_limb(kb, i, f"BT{i}", (sx, hip - 0.04, sz), yaw, KN, FT,
                                scale_w=0.96, has_era=(i < 2), oxide_accent=True, compact_hex=True)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 7. legs_hex_colossus — CL-12 Super-Heavy Siege Fortress Hexapod
# ==============================================================================
def build_legs_hex_colossus(kb: KitbashScene):
    hip = 1.38
    socket_y = hip + 0.42
    _build_multi_hull_common(kb, hip, socket_y, 1.72, 2.68, oxide_prow=True)
    M_plw = g2b_mat((0, hip - 0.24, -1.50), (18, 0, 0))
    kb.plate("SiegePlow", trap_2d(1.68, 1.46, 0.52, 0.06), 0.16, "armor_oxide", "weld_plate", (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_plw)
    kb.box("PlowHaz", (1.36, 0.065, 0.024), "hazard", "hazard", (0, 0.18, -0.096), (0, 0, 0), 0.004, 1, M_parent=M_plw)
    for si, sx in enumerate([-0.50, 0.50]):
        heavy_hyd(kb, f"PlowRam{si}", (sx, hip - 0.06, -1.24), (sx, hip - 0.26, -1.46), 0.030, 8, pins=False)
        kb.cyl(f"ColStack{si}", 0.084, 0.084, 0.34, 12, "gunmetal", "vent_mesh", (sx * 1.12, hip + 0.36, 1.24), (0, 0, 0), 0.005, hollow_r=0.064, u_rep=2.0)

    mounts = [(-0.80, -1.08, -0.82), (0.80, -1.08, -0.82), (-0.88, 0.0, 0.0), (0.88, 0.0, 0.0), (-0.80, 1.08, 0.82), (0.80, 1.08, 0.82)]
    KN = Vector((0.0, 0.24, 0.80))
    FT = Vector((0.0, -(hip + 0.02) + 0.06, 1.12))
    for i, (sx, sz, za) in enumerate(mounts):
        yaw = math.degrees(math.atan2(1.0 if sx > 0 else -1.0, za))
        build_heavy_spider_limb(kb, i, f"CL{i}", (sx, hip + 0.02, sz), yaw, KN, FT,
                                scale_w=1.00, pile_style=True, oxide_accent=True, compact_hex=True)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 8. legs_tread_light — MT-2 High-Speed Christie Light Tracked Chassis
# ==============================================================================
def build_legs_tread_light(kb: KitbashScene):
    hip = 0.95
    socket_y = 1.21  # Compact 14cm light tank turret ring clearing rear gen_cell!
    kb.use_group("Body")
    kb.box("LightHull", (1.14, 0.46, 1.84), "dark", "frame_cnc", (0, 0.66, 0.0), (0, 0, 0), 0.020, 1)
    kb.plate("WedgeGlacis", trap_2d(1.04, 1.16, 0.54, 0.06), 0.13, "armor", "armor_slab", (0, 0.78, -0.96), (46, 0, 0), 0.016, 1)
    kb.decal("LightUnit", "ord_12", (0.20, 0.16), (0, 0.835, -1.015), (46, 0, 0))
    kb.plate("TopDeck", crect_2d(1.16, 1.54, (0.20, 0.20, 0.18, 0.18)), 0.20, "armor_sub", "armor_pocket", (0, 0.96, 0.04), (90, 0, 0), 0.014, 1)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, 1.05)
    for si, sx in enumerate([-0.38, 0.38]):
        kb.headlight_cage(f"MTLamp{si}", (sx, 0.92, -0.88))
        kb.cyl(f"Muffler{si}", 0.072, 0.072, 0.54, 14, "gunmetal", "vent_mesh", (sx, 0.88, 0.98), (0, 0, 90), 0.004, u_rep=2.0)

    y_trk = 0.318
    for t_name, pfx, sx in [("Track_L", "MTL", -0.84), ("Track_R", "MTR", 0.84)]:
        side = -1.0 if sx < 0 else 1.0
        g_tr = kb.add_group(t_name, t_name, pos=(sx, 0.0, 0.0))
        kb.use_group(g_tr)
        build_precision_track_pod(kb, pfx, side, y_trk, straight=1.84, r_arc=0.292, width=0.56,
                                  wheel_zs=[-0.66, -0.22, 0.22, 0.66], r_wheel=0.235, n_links=44,
                                  return_rollers=0, christie=True)
        kb.plate(f"{pfx}_PerfFender", crect_2d(2.24, 0.065, (0.06, 0.06, 0.0, 0.0)), 0.60, "armor", "vent_mesh",
                 (side * 0.02, 0.70, 0.0), (0, 90, 0), 0.010, 1)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 9. legs_tread_heavy — KV-6 V-Dozer ERA Siege Heavy Tracked Chassis
# ==============================================================================
def build_legs_tread_heavy(kb: KitbashScene):
    hip = 1.13
    socket_y = 1.34  # Flush 8cm heavy MBT turret ring!
    kb.use_group("Body")
    kb.box("KVHull", (1.34, 0.60, 2.18), "dark", "frame_cnc", (0, 0.76, 0.0), (0, 0, 0), 0.024, 1)
    kb.plate("KVDeck", crect_2d(1.38, 2.22, (0.24, 0.24, 0.22, 0.22)), 0.24, "armor", "armor_slab", (0, 1.14, 0.0), (90, 0, 0), 0.018, 1)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, 1.25)
    for si, sx in enumerate([-1.0, 1.0]):
        M_vb = g2b_mat((sx * 0.46, 0.48, -1.30), (14, sx * -20.0, 0))
        kb.plate(f"VDozerWing{si}", trap_2d(0.96, 0.88, 0.54, 0.04), 0.12, "armor_oxide", "weld_plate", (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_vb)
        kb.box(f"VDozerHaz{si}", (0.80, 0.055, 0.024), "hazard", "hazard", (0, 0.18, -0.076), (0, 0, 0), 0.003, 1, M_parent=M_vb)
        heavy_hyd(kb, f"DozerRam{si}", (sx * 0.44, 0.78, -1.02), (sx * 0.50, 0.52, -1.26), 0.030, 8, pins=False)
        kb.era_block(f"GlacisERA{si}", (0.46, 0.22, 0.065), "armor", (sx * 0.32, 0.98, -1.12), (34, 0, 0))
        kb.cyl(f"KVStack{si}", 0.080, 0.084, 0.24, 12, "gunmetal", "vent_mesh", (sx * 0.56, 1.32, 1.06), (0, 0, 0), 0.005, hollow_r=0.060)
    kb.louver_bay("KVRearVent", 0.78, 0.28, 0.048, (0, 0.88, 1.12), (0, 180, 0), blades=6)

    y_trk = 0.368
    for t_name, pfx, sx in [("Track_L", "KVL", -0.98), ("Track_R", "KVR", 0.98)]:
        side = -1.0 if sx < 0 else 1.0
        g_tr = kb.add_group(t_name, t_name, pos=(sx, 0.0, 0.0))
        kb.use_group(g_tr)
        build_precision_track_pod(kb, pfx, side, y_trk, straight=2.22, r_arc=0.342, width=0.68,
                                  wheel_zs=[-0.85, -0.51, -0.17, 0.17, 0.51, 0.85], r_wheel=0.205, n_links=38,
                                  return_rollers=2)
        kb.plate(f"{pfx}_Fend", crect_2d(2.64, 0.08, (0.08, 0.08, 0.0, 0.0)), 0.76, "armor_sub", "armor_panel",
                 (side * 0.04, 0.84, 0.0), (0, 90, 0), 0.012, 1)
        for ki in range(4):
            kz = -0.84 + ki * 0.56
            kb.era_block(f"{pfx}_SideERA{ki}", (0.50, 0.32, 0.075), "armor" if ki % 2 == 0 else "armor_oxide",
                         (side * 0.40, 0.64, kz), (0, side * -90.0, 0))

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 10. legs_tread_siege — DT-9 Obj-279 Nuclear-Blast Saucer + 4 Precision Track Pods
# ==============================================================================
def build_legs_tread_siege(kb: KitbashScene):
    hip = 1.19
    socket_y = 1.42  # Low-profile 11cm Obj-279 turret ring!
    kb.use_group("Body")
    kb.plate("SaucerUpper", crect_2d(1.68, 2.62, (0.42, 0.42, 0.38, 0.38)), 0.30, "armor", "armor_slab", (0, 1.16, 0.0), (90, 0, 0), 0.026, 1)
    kb.plate("SaucerBelly", crect_2d(1.30, 2.24, (0.32, 0.32, 0.30, 0.30)), 0.24, "armor_sub", "weld_plate", (0, 0.86, 0.0), (90, 0, 0), 0.022, 1)
    kb.cyl("SiegeBarbette", 0.33, 0.43, 0.075, 20, "armor_oxide", "armor_pocket", (0, 1.335, 0.0), (0, 0, 0), 0.006)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, 1.35)
    kb.decal("DTStencil", "unit_17", (0.26, 0.20), (0, 1.16, -1.326), (0, 0, 0))
    for sx_i, sx in enumerate([-0.44, 0.44]):
        kb.headlight_cage(f"DTLamp{sx_i}", (sx, 1.16, -1.28))
        kb.cyl(f"DTTank{sx_i}", 0.16, 0.16, 0.54, 16, "armor_sub", "armor_hatch", (sx, 1.24, 1.34), (0, 0, 90), 0.008)
    kb.louver_bay("DTRearVent", 0.84, 0.26, 0.048, (0, 0.98, 1.29), (0, 180, 0), blades=5)

    # 4 Articulated Precision Double-Pin Track Pods grouped under Track_L (-X) & Track_R (+X)
    y_trk = 0.298
    for t_name, pfx, sx in [("Track_L", "DTL", -0.98), ("Track_R", "DTR", 0.98)]:
        side = -1.0 if sx < 0 else 1.0
        g_tr = kb.add_group(t_name, t_name, pos=(sx, 0.0, 0.0))
        kb.use_group(g_tr)
        for pi, pz in enumerate([-0.94, 0.94]):
            sub_p = f"{pfx}{pi}"
            heavy_drum(kb, f"{sub_p}_Swg", (-side * 0.34, 0.62, pz), 0.19, 0.46, segs=12, n_bolts=0)
            heavy_hyd(kb, f"{sub_p}_Hyd", (-side * 0.26, 1.02, pz - math.copysign(0.18, pz)),
                      (-side * 0.02, 0.72, pz - math.copysign(0.32, pz)), 0.030, 8, pins=False)
            build_precision_track_pod(kb, sub_p, side, y_trk, straight=1.00, r_arc=0.272, width=0.58,
                                      wheel_zs=[-0.30, 0.0, 0.30], r_wheel=0.178, n_links=24,
                                      pos_off=(0.0, pz), return_rollers=1, compact_pod=True, skip_hidden_top=True)
            kb.plate(f"{sub_p}_Shld", trap_2d(1.26, 1.06, 0.36, 0.05), 0.10, "armor" if pi == 0 else "armor_sub", "armor_slab",
                     (side * 0.33, 0.54, pz), (0, side * 90.0, 0), 0.014, 1)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))
