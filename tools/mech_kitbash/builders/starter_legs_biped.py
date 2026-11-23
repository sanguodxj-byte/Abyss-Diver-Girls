"""ST-8 (legs_biped) High-Precision Articulated Biped Chassis — Production Standard (MECH_MODELING_STANDARD v1.0)."""
import math
from mathutils import Vector
from kitbash_lib import KitbashScene, g2b_mat, g2b_bone_mat, crect_2d, trap_2d


def build_legs_biped(kb: KitbashScene):
    hip = 1.62
    socket_y = hip + 0.55  # 2.17m exact match to legs_biped.gd

    # ==========================================================================
    # 1. PELVIS & UNIFIED HP-C1 WAIST PEDESTAL (static Body group)
    # ==========================================================================
    kb.use_group("Body")
    # Heavy forged structural pelvis cradle + upper skirt deck
    kb.box("PelvisFrame", (1.04, 0.34, 0.66), "dark", "frame_cnc", (0, hip + 0.04, 0.02), (0, 0, 0), 0.022, 1, tile_u=2.0)
    kb.box("PelvisDeck", (0.86, 0.18, 0.58), "armor_sub", "armor_pocket", (0, hip + 0.23, 0.02), (0, 0, 0), 0.018, 1)
    # Multi-layer sloped codpiece / front ballistic apron + hazard stripe + forged tow shackles
    kb.plate("FrontSkirt", trap_2d(0.64, 0.90, 0.46, 0.07), 0.11, "armor", "armor_panel", (0, hip + 0.02, -0.38), (16, 0, 0), 0.016, 1)
    kb.plate("FrontSkirtSub", trap_2d(0.42, 0.62, 0.28, 0.05), 0.055, "armor_sub", "armor_ribs", (0, hip - 0.03, -0.45), (16, 0, 0), 0.010, 1)
    kb.box("FrontSkirtHaz", (0.38, 0.055, 0.024), "hazard", "hazard", (0, hip + 0.17, -0.45), (16, 0, 0), 0.004, 1)
    kb.grab_rail("PelvisGrab", 0.26, 0.038, (0, hip - 0.15, -0.43), (16, 0, 0), 0.010)
    for si, sx in enumerate([-0.24, 0.24]):
        kb.tow_shackle(f"PelvisTow_{si}", (sx, hip - 0.16, -0.42), (0, 0, 90), 0.85)
    # Rear sloped armored exhaust skirt + recessed louver vent bay
    kb.plate("RearSkirt", trap_2d(0.74, 0.94, 0.42, 0.06), 0.11, "armor_sub", "armor_hatch", (0, hip + 0.02, 0.38), (-14, 0, 0), 0.016, 1)
    kb.louver_bay("PelvisRearVent", 0.44, 0.16, 0.045, (0, hip + 0.05, 0.445), (-14, 180, 0), blades=4, mesh_style=False)
    # 4 exposed waist stabilizing hydraulic struts (with accordion dust boots!)
    for sx_i, sx_g in enumerate([-0.34, 0.34]):
        kb.hydraulic(f"WaistStabF_{sx_i}", (sx_g, hip + 0.23, -0.22), (sx_g * 0.76, hip + 0.47, -0.17), 0.022)
        kb.hydraulic(f"WaistStabR_{sx_i}", (sx_g, hip + 0.23,  0.22), (sx_g * 0.76, hip + 0.47,  0.17), 0.022)
    # Unified HP-C1 Waist Pedestal (r=0.360m, top <= socket_y - 0.015m) + 4 braided waist hydraulic hoses
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.24)
    for hi, ang in enumerate([0.22, -0.22, math.pi - 0.22, math.pi + 0.22]):
        ca, sa = math.cos(ang), math.sin(ang)
        kb.tube_path(f"WaistHose_{hi}",
                     [(ca * 0.32, hip + 0.27, sa * 0.32), (ca * 0.37, hip + 0.37, sa * 0.37), (ca * 0.30, hip + 0.47, sa * 0.30)],
                     0.016, 8, "gunmetal", "braid_hose", add_clamps=False)

    # ==========================================================================
    # 2. ARTICULATED REVERSE-JOINT BIPED LEGS (Leg_L & Leg_R -> Knee -> Ankle)
    # ==========================================================================
    KN = Vector((0.0, -0.78, -0.34))
    AN = Vector((0.0, -1.30,  0.20))
    sole_rel = -1.56 - hip  # Exact match to legs_biped.gd line 102

    for side_tag, sx in [("Leg_L", -0.62), ("Leg_R", 0.62)]:
        side = -1.0 if sx < 0 else 1.0
        g_leg = kb.add_group(side_tag, side_tag, pos=(sx, hip, 0.0))
        kb.use_group(g_leg)
        kb.add_marker("MARK_SOLE", (0.0, sole_rel, 0.0), parent_key=g_leg)

        # Hip heavy actuator drum + spaced beveled hip skirt shield + grab iron
        kb.actuator_drum(f"{side_tag}_HipDrum", (-side * 0.04, 0, 0), 0.225, 0.38)
        kb.plate(f"{side_tag}_HipShield", crect_2d(0.64, 0.50, (0.15, 0.08, 0.04, 0.14)), 0.09, "armor_sub", "armor_panel",
                 (side * 0.27, -0.02, 0.0), (0, side * 90.0, 0), 0.014, 1)
        kb.plate(f"{side_tag}_HipShield2", crect_2d(0.42, 0.24, (0.06, 0.04, 0.02, 0.06)), 0.04, "armor", "armor_ribs",
                 (side * 0.325, 0.02, 0.02), (0, side * 90.0, 0), 0.008, 1)
        kb.grab_rail(f"{side_tag}_HipGrab", 0.20, 0.036, (side * 0.33, 0.16, 0.0), (0, side * -90.0, 0), 0.010)

        # Thigh bone frame (H=0 -> KN)
        M_th = g2b_bone_mat((0, 0, 0), KN)
        l1 = KN.length
        kb.box(f"{side_tag}_ThighBeam", (0.22, l1, 0.24), "dark", "frame_cnc", (0, -l1 * 0.5, 0.02), (0, 0, 0), 0.014, 1, M_parent=M_th)
        kb.hydraulic(f"{side_tag}_ThighHydA", (side * 0.13, -0.06, 0.16), (side * 0.11, -l1 + 0.10, 0.14), 0.028, M_parent=M_th)
        kb.hydraulic(f"{side_tag}_ThighHydB", (-side * 0.11, -0.06, 0.16), (-side * 0.09, -l1 + 0.10, 0.14), 0.022, M_parent=M_th)
        # Layered front & side thigh armor plates with countersunk bolts & tactical accent band
        kb.plate(f"{side_tag}_ThighF1", trap_2d(0.32, 0.48, l1 * 0.84, 0.07), 0.12, "armor", "armor_panel",
                 (0, -l1 * 0.46, -0.16), (-4, 0, 0), 0.016, 1, M_parent=M_th)
        kb.plate(f"{side_tag}_ThighF2", crect_2d(0.28, l1 * 0.48, (0.06, 0.06, 0.02, 0.02)), 0.065, "armor_sub", "armor_hatch",
                 (0, -l1 * 0.36, -0.24), (-4, 0, 0), 0.010, 1, M_parent=M_th)
        kb.box(f"{side_tag}_ThighAcc", (0.055, l1 * 0.28, 0.022), "accent", "plain_metal",
               (side * 0.09, -l1 * 0.36, -0.282), (-4, 0, 0), 0.004, 1, M_parent=M_th)
        kb.plate(f"{side_tag}_ThighSide", crect_2d(0.22, l1 * 0.68, (0.02, 0.07, 0.07, 0.02)), 0.36, "armor", "armor_ribs",
                 (side * 0.22, -l1 * 0.48, -0.02), (0, side * 90.0, 0), 0.014, 1, M_parent=M_th)
        kb.bolt_ring(f"{side_tag}_ThighBlts", 0.08, 4, 0.010, (side * 0.402, -l1 * 0.48, -0.02), (0, 0, side * -90.0), M_parent=M_th)
        # Braided rear leg hydraulic hose
        kb.tube_path(f"{side_tag}_ThighHose", [(side * 0.11, -0.12, 0.22), (side * 0.12, -0.48, 0.26), (side * 0.09, -0.80, -0.12)],
                     0.022, 8, "gunmetal", "braid_hose", add_clamps=True)

        # Heavy Knee Actuator Drum + Multi-Layer Angled Ballistic Knee Guard
        kb.actuator_drum(f"{side_tag}_KneeDrum", KN, 0.18, 0.40)
        M_kp = g2b_mat((KN.x, KN.y + 0.02, KN.z - 0.18), (-12, 0, 0))
        kb.plate(f"{side_tag}_KneeBase", trap_2d(0.36, 0.44, 0.34, 0.06), 0.14, "armor_sub", "armor_pocket", (0, -0.02, 0.02), (0, 0, 0), 0.014, 1, M_parent=M_kp)
        kb.plate(f"{side_tag}_KneeCap", trap_2d(0.22, 0.32, 0.24, 0.04), 0.09, "armor", "armor_panel", (0, 0.02, -0.065), (-8, 0, 0), 0.010, 1, M_parent=M_kp)
        kb.box(f"{side_tag}_KneeBrow", (0.28, 0.038, 0.14), "gunmetal", "bolt_flange", (0, 0.155, -0.02), (0, 0, 0), 0.006, 1, M_parent=M_kp)
        for kxi, kx in enumerate([-0.21, 0.21]):
            kb.cyl(f"{side_tag}_KPin_{kxi}", 0.030, 0.030, 0.038, 8, "chrome", "plain_metal", (kx, 0.02, 0.02), (0, 0, 90), 0.004, M_parent=M_kp)

        # ---- KNEE PIVOT GROUP (Shin) ----
        g_knee = kb.add_group(f"{side_tag}/Knee", "Knee", pos=(KN.x, KN.y, KN.z), parent_key=g_leg)
        kb.use_group(g_knee)
        rel_an = AN - KN
        l2 = rel_an.length
        M_sh = g2b_bone_mat((0, 0, 0), rel_an)
        kb.box(f"{side_tag}_ShinBeam", (0.18, l2, 0.20), "dark", "frame_cnc", (0, -l2 * 0.5, 0.02), (0, 0, 0), 0.012, 1, M_parent=M_sh)
        kb.plate(f"{side_tag}_ShinFront", trap_2d(0.28, 0.44, l2 * 0.90, 0.06), 0.11, "armor", "armor_panel",
                 (0, -l2 * 0.50, -0.14), (0, 0, 0), 0.014, 1, M_parent=M_sh)
        # Perforated shin cooling heat-shield panel!
        kb.louver_bay(f"{side_tag}_ShinVent", 0.20, 0.22, 0.032, (0, -l2 * 0.36, -0.205), (0, 0, 0), blades=4, mesh_style=True, M_parent=M_sh)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{side_tag}_ShinSide_{s2i}", crect_2d(0.14, l2 * 0.72, (0.05, 0.02, 0.02, 0.05)), 0.24, "armor_sub", "armor_ribs",
                     (s2 * 0.18, -l2 * 0.48, -0.03), (0, 90, 0), 0.010, 1, M_parent=M_sh)
        kb.hydraulic(f"{side_tag}_ShinHyd", (0, -0.08, 0.17), (rel_an.x, rel_an.y + 0.12, rel_an.z + 0.13), 0.032)
        kb.tube_path(f"{side_tag}_ShinHose", [(-side * 0.10, 0.0, 0.11), (-side * 0.12, -0.26, 0.26), (-side * 0.08, rel_an.y + 0.08, rel_an.z + 0.06)],
                     0.018, 8, "gunmetal", "braid_hose", add_clamps=False)

        # ---- ANKLE PIVOT GROUP (Foot + 3 Articulated Cast-Steel Claws + Hydraulic Heel Spur) ----
        g_ank = kb.add_group(f"{side_tag}/Ankle", "Ankle", pos=(rel_an.x, rel_an.y, rel_an.z), parent_key=g_knee)
        kb.use_group(g_ank)
        kb.actuator_drum(f"{side_tag}_AnkDrum", (0, 0, 0), 0.13, 0.34)
        ft_off = Vector((0.0, -1.50, 0.08)) - AN
        M_ft = g2b_mat((ft_off.x, ft_off.y, ft_off.z), (0, 0, 0))
        kb.box(f"{side_tag}_FootBlock", (0.38, 0.16, 0.40), "gunmetal", "frame_cnc", (0, 0.02, 0.04), (0, 0, 0), 0.016, 1, M_parent=M_ft)
        kb.plate(f"{side_tag}_FootInstep", trap_2d(0.38, 0.28, 0.30, 0.04), 0.11, "armor_sub", "armor_panel",
                 (0, 0.13, -0.09), (-68, 0, 0), 0.012, 1, M_parent=M_ft)
        # 3 heavy forged steel toes with knuckle pins & rubber shock treads
        for ti, (tx, tyaw, tl) in enumerate([(-0.18, -16.0, 0.44), (0.0, 0.0, 0.54), (0.18, 16.0, 0.44)]):
            M_toe = M_ft @ g2b_mat((tx, -0.02, -0.13), (0, tyaw, 0))
            kb.cyl(f"{side_tag}_ToeKnk_{ti}", 0.048, 0.048, 0.13, 12, "dark", "gear_collar", (0, 0.01, 0), (0, 0, 90), 0.005, M_parent=M_toe)
            kb.box(f"{side_tag}_ToeArm_{ti}", (0.12, 0.10, tl * 0.65), "armor", "armor_ribs", (0, 0.01, -tl * 0.34), (6, 0, 0), 0.010, 1, M_parent=M_toe)
            kb.plate(f"{side_tag}_ToeClaw_{ti}", trap_2d(0.11, 0.07, tl * 0.42, 0.015), 0.085, "gunmetal", "bolt_flange",
                     (0, -0.01, -tl * 0.78), (90, 0, 0), 0.008, 1, M_parent=M_toe)
            kb.box(f"{side_tag}_ToePad_{ti}", (0.125, 0.036, tl * 0.86), "rubber", "dust_boot", (0, -0.06, -tl * 0.45), (0, 0, 0), 0.006, 1, M_parent=M_toe)
        # Rear hydraulic recoil-spade heel spur
        M_spur = M_ft @ g2b_mat((0, -0.02, 0.22), (0, 180, 0))
        kb.box(f"{side_tag}_HeelArm", (0.15, 0.10, 0.30), "armor_sub", "armor_pocket", (0, 0.01, -0.14), (8, 0, 0), 0.010, 1, M_parent=M_spur)
        kb.box(f"{side_tag}_HeelPad", (0.16, 0.036, 0.28), "rubber", "dust_boot", (0, -0.06, -0.14), (0, 0, 0), 0.006, 1, M_parent=M_spur)
        kb.hydraulic(f"{side_tag}_HeelHyd", (0, 0.14, 0.16), (0, 0.02, 0.34), 0.020, M_parent=M_ft)
        kb.box(f"{side_tag}_HeelHaz", (0.12, 0.028, 0.075), "hazard", "hazard", (0, 0.10, 0.24), (0, 0, 0), 0.003, 1, M_parent=M_ft)

    # Standard HP-C1 Core Socket Marker
    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))
