"""ST-8 (legs_biped) Muscular B.o.T-Scale Articulated Biped Chassis — Production Standard."""
import math
from mathutils import Vector
from kitbash_lib import KitbashScene, g2b_mat, g2b_bone_mat, crect_2d, trap_2d


def build_legs_biped(kb: KitbashScene):
    hip = 1.62
    socket_y = hip + 0.41  # 2.03m low-profile flush waist interface!

    # 1. HEAVY PELVIS CRADLE & COMPACT HP-C1 WAIST RING
    kb.use_group("Body")
    kb.box("PelvisFrame", (0.86, 0.38, 0.76), "dark", "frame_cnc", (0, hip + 0.04, 0.02), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("PelvisDeck", (0.82, 0.20, 0.66), "armor_sub", "armor_pocket", (0, hip + 0.24, 0.02), (0, 0, 0), 0.018, 1)
    kb.plate("FrontSkirt", trap_2d(0.72, 0.92, 0.48, 0.07), 0.13, "armor", "armor_slab", (0, hip + 0.02, -0.42), (16, 0, 0), 0.018, 1)
    kb.plate("FrontSkirtSub", trap_2d(0.48, 0.70, 0.30, 0.05), 0.065, "armor_sub", "armor_ribs", (0, hip - 0.03, -0.502), (16, 0, 0), 0.010, 1)
    kb.box("FrontSkirtHaz", (0.42, 0.054, 0.024), "hazard", "hazard", (0, hip + 0.17, -0.460), (16, 0, 0), 0.004, 1)
    kb.grab_rail("PelvisGrab", 0.30, 0.038, (0, hip - 0.15, -0.556), (16, 0, 0), 0.011)
    for si, sx in enumerate([-0.28, 0.28]):
        kb.tow_shackle(f"PelvisTow_{si}", (sx, hip - 0.16, -0.540), (0, 0, 90), 0.90)
    kb.plate("RearSkirt", trap_2d(0.84, 0.96, 0.44, 0.06), 0.12, "armor_sub", "armor_hatch", (0, hip + 0.02, 0.42), (-14, 0, 0), 0.016, 1)
    kb.louver_bay("PelvisRearVent", 0.50, 0.18, 0.045, (0, hip + 0.05, 0.490), (-14, 180, 0), blades=4, mesh_style=False)
    for sx_i, sx_g in enumerate([-0.34, 0.34]):
        kb.hydraulic(f"WaistStabF_{sx_i}", (sx_g, hip + 0.26, -0.22), (sx_g * 0.66, hip + 0.37, -0.15), 0.020)
        kb.hydraulic(f"WaistStabR_{sx_i}", (sx_g, hip + 0.26,  0.22), (sx_g * 0.66, hip + 0.37,  0.15), 0.020)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.32)
    for hi, ang in enumerate([0.22, -0.22, math.pi - 0.22, math.pi + 0.22]):
        ca, sa = math.cos(ang), math.sin(ang)
        kb.tube_path(f"WaistHose_{hi}",
                     [(ca * 0.32, hip + 0.29, sa * 0.32), (ca * 0.33, hip + 0.34, sa * 0.33), (ca * 0.26, hip + 0.38, sa * 0.26)],
                     0.015, 6, "gunmetal", "braid_hose", add_clamps=False)

    # 2. MUSCULAR REVERSE-JOINT BIPED LEGS (Leg_L & Leg_R -> Knee -> Ankle)
    KN = Vector((0.0, -0.78, -0.34))
    AN = Vector((0.0, -1.30,  0.20))
    sole_rel = -1.56 - hip

    for side_tag, sx in [("Leg_L", -0.70), ("Leg_R", 0.70)]:
        side = -1.0 if sx < 0 else 1.0
        g_leg = kb.add_group(side_tag, side_tag, pos=(sx, hip, 0.0))
        kb.use_group(g_leg)
        kb.add_marker("MARK_SOLE", (0.0, sole_rel, 0.0), parent_key=g_leg)

        # Oversized Hip Drum + Broad Spaced Hip Skirt Shield (stepped X planes)
        kb.actuator_drum(f"{side_tag}_HipDrum", (-side * 0.02, 0, 0), 0.26, 0.44)
        kb.plate(f"{side_tag}_HipShield", crect_2d(0.72, 0.56, (0.16, 0.09, 0.05, 0.15)), 0.11, "armor_sub", "armor_panel",
                 (side * 0.33, -0.02, 0.0), (0, side * 90.0, 0), 0.016, 1)
        kb.plate(f"{side_tag}_HipShield2", crect_2d(0.48, 0.28, (0.06, 0.04, 0.02, 0.06)), 0.055, "armor", "armor_ribs",
                 (side * 0.415, 0.02, 0.02), (0, side * 90.0, 0), 0.010, 1)
        kb.grab_rail(f"{side_tag}_HipGrab", 0.22, 0.040, (side * 0.395, 0.18, 0.0), (0, side * -90.0, 0), 0.011)

        # Muscular 3D Thigh Assembly (stepped narrower than KneeDrum 0.52 -> +/-0.26)
        M_th = g2b_bone_mat((0, 0, 0), KN)
        l1 = KN.length
        l1_s = l1 - 0.26
        y_th_m = -(0.14 + 0.5 * l1_s)
        kb.box(f"{side_tag}_ThighBeam", (0.34, l1_s, 0.44), "dark", "frame_cnc", (0, y_th_m, 0.02), (0, 0, 0), 0.018, 1, M_parent=M_th)
        kb.hydraulic(f"{side_tag}_ThighHydA", (side * 0.13, -0.12, 0.26), (side * 0.12, -l1 + 0.12, 0.24), 0.032, M_parent=M_th)
        kb.hydraulic(f"{side_tag}_ThighHydB", (-side * 0.11, -0.12, 0.26), (-side * 0.10, -l1 + 0.12, 0.24), 0.026, M_parent=M_th)
        kb.plate(f"{side_tag}_ThighF1", trap_2d(0.42, 0.54, l1_s * 0.94, 0.07), 0.16, "armor", "armor_slab",
                 (0, y_th_m, -0.24), (-4, 0, 0), 0.024, 1, M_parent=M_th)
        kb.plate(f"{side_tag}_ThighF2", crect_2d(0.34, l1_s * 0.54, (0.06, 0.06, 0.02, 0.02)), 0.075, "armor_oxide" if side > 0 else "armor_sub", "weld_plate",
                 (0, y_th_m + 0.06, -0.35), (-4, 0, 0), 0.014, 1, M_parent=M_th)
        if side > 0:
            kb.decal(f"{side_tag}_ThighUnit", "unit_17", (0.22, 0.22), (0, y_th_m + 0.06, -0.394), (-4, 0, 0), M_parent=M_th)
        else:
            kb.decal(f"{side_tag}_ThighTri", "hazard_tri", (0.16, 0.16), (0, y_th_m + 0.06, -0.394), (-4, 0, 0), M_parent=M_th)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{side_tag}_ThighSide_{s2i}", crect_2d(0.40, l1_s * 0.84, (0.04, 0.08, 0.08, 0.04)), 0.080, "armor", "armor_ribs",
                     (s2 * 0.198, y_th_m, 0.01), (0, s2 * 90.0, 0), 0.014, 1, M_parent=M_th)
        kb.tube_path(f"{side_tag}_ThighHose", [(side * 0.14, -0.12, 0.28), (side * 0.16, -0.48, 0.32), (side * 0.12, -0.80, -0.10)],
                     0.024, 5, "gunmetal", "braid_hose", add_clamps=False)

        # Oversized Knee Actuator Drum (widest X-step: 0.52 -> +/-0.26) + Ballistic Knee Guard
        kb.actuator_drum(f"{side_tag}_KneeDrum", KN, 0.22, 0.52)
        M_kp = g2b_mat((KN.x, KN.y + 0.02, KN.z - 0.26), (-12, 0, 0))
        kb.plate(f"{side_tag}_KneeBase", trap_2d(0.46, 0.56, 0.38, 0.06), 0.16, "armor_sub", "armor_pocket", (0, -0.02, 0.02), (0, 0, 0), 0.016, 1, M_parent=M_kp)
        kb.plate(f"{side_tag}_KneeCap", trap_2d(0.32, 0.42, 0.26, 0.04), 0.10, "armor", "armor_panel", (0, 0.02, -0.095), (-8, 0, 0), 0.012, 1, M_parent=M_kp)

        # ---- KNEE PIVOT GROUP (Broad Flared Shin Greave + Heavy Coil Shock) ----
        g_knee = kb.add_group(f"{side_tag}/Knee", "Knee", pos=(KN.x, KN.y, KN.z), parent_key=g_leg)
        kb.use_group(g_knee)
        rel_an = AN - KN
        l2 = rel_an.length
        l2_s = l2 - 0.26
        y_sh_m = -(0.14 + 0.5 * l2_s)
        M_sh = g2b_bone_mat((0, 0, 0), rel_an)
        kb.box(f"{side_tag}_ShinBeam", (0.32, l2_s, 0.40), "dark", "frame_cnc", (0, y_sh_m, 0.02), (0, 0, 0), 0.016, 1, M_parent=M_sh)
        kb.plate(f"{side_tag}_ShinFront", trap_2d(0.40, 0.52, l2_s * 0.94, 0.06), 0.15, "armor", "armor_slab",
                 (0, y_sh_m, -0.22), (0, 0, 0), 0.022, 1, M_parent=M_sh)
        kb.louver_bay(f"{side_tag}_ShinVent", 0.26, 0.22, 0.036, (0, y_sh_m + 0.04, -0.306), (0, 0, 0), blades=3, mesh_style=True, M_parent=M_sh)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{side_tag}_ShinSide_{s2i}", crect_2d(0.36, l2_s * 0.84, (0.06, 0.04, 0.04, 0.06)), 0.076, "armor_sub", "armor_ribs",
                     (s2 * 0.188, y_sh_m, 0.01), (0, 90, 0), 0.014, 1, M_parent=M_sh)
            kb.decal(f"{side_tag}_ShinTri_{s2i}", "hazard_tri", (0.13, 0.13), (s2 * 0.232, y_sh_m - 0.02, 0.01), (0, -s2 * 90.0, 0), M_parent=M_sh)
        kb.coil_shock(f"{side_tag}_ShinShock", (0, -0.10, 0.26), (rel_an.x, rel_an.y + 0.12, rel_an.z + 0.22), 0.044)
        kb.tube_path(f"{side_tag}_ShinHose", [(-side * 0.14, -0.04, 0.16), (-side * 0.16, -0.26, 0.30), (-side * 0.12, rel_an.y + 0.10, rel_an.z + 0.10)],
                     0.020, 5, "gunmetal", "braid_hose", add_clamps=False)

        # ---- ANKLE PIVOT GROUP (Wide Planted 3-Claw Siege Foot + Hydraulic Heel Spur) ----
        g_ank = kb.add_group(f"{side_tag}/Ankle", "Ankle", pos=(rel_an.x, rel_an.y, rel_an.z), parent_key=g_knee)
        kb.use_group(g_ank)
        kb.actuator_drum(f"{side_tag}_AnkDrum", (0, 0, 0), 0.165, 0.34)
        ft_off = Vector((0.0, -1.50, 0.08)) - AN
        M_ft = g2b_mat((ft_off.x, ft_off.y, ft_off.z), (0, 0, 0))
        kb.box(f"{side_tag}_FootBlock", (0.54, 0.18, 0.48), "gunmetal", "frame_cnc", (0, 0.02, 0.04), (0, 0, 0), 0.016, 1, M_parent=M_ft)
        kb.plate(f"{side_tag}_FootInstep", trap_2d(0.52, 0.38, 0.34, 0.04), 0.13, "armor_sub", "armor_panel",
                 (0, 0.14, -0.11), (-68, 0, 0), 0.014, 1, M_parent=M_ft)
        for ti, (tx, tyaw, tl) in enumerate([(-0.22, -16.0, 0.48), (0.0, 0.0, 0.58), (0.22, 16.0, 0.48)]):
            M_toe = M_ft @ g2b_mat((tx, -0.02, -0.15), (0, tyaw, 0))
            kb.cyl(f"{side_tag}_ToeKnk_{ti}", 0.056, 0.056, 0.16, 8, "dark", "gear_collar", (0, 0.01, 0), (0, 0, 90), 0.005, M_parent=M_toe)
            kb.box(f"{side_tag}_ToeArm_{ti}", (0.15, 0.11, tl * 0.68), "armor", "armor_ribs", (0, 0.01, -tl * 0.34), (6, 0, 0), 0.010, 1, M_parent=M_toe)
            kb.plate(f"{side_tag}_ToeClaw_{ti}", trap_2d(0.14, 0.08, tl * 0.44, 0.015), 0.095, "gunmetal", "bolt_flange",
                     (0, -0.01, -tl * 0.80), (90, 0, 0), 0.008, 1, M_parent=M_toe)
            kb.box(f"{side_tag}_ToePad_{ti}", (0.155, 0.038, tl * 0.88), "rubber", "dust_boot", (0, -0.06, -tl * 0.45), (0, 0, 0), 0.0, 1, M_parent=M_toe)
        M_spur = M_ft @ g2b_mat((0, -0.02, 0.24), (0, 180, 0))
        kb.box(f"{side_tag}_HeelArm", (0.26, 0.11, 0.34), "armor_sub", "armor_pocket", (0, 0.01, -0.15), (8, 0, 0), 0.010, 1, M_parent=M_spur)
        kb.box(f"{side_tag}_HeelPad", (0.28, 0.038, 0.32), "rubber", "dust_boot", (0, -0.06, -0.15), (0, 0, 0), 0.0, 1, M_parent=M_spur)
        kb.hydraulic(f"{side_tag}_HeelHyd", (0, 0.16, 0.18), (0, 0.02, 0.38), 0.024, M_parent=M_ft)
        kb.box(f"{side_tag}_HeelHaz", (0.20, 0.032, 0.085), "hazard", "hazard", (0, 0.11, 0.26), (0, 0, 0), 0.003, 1, M_parent=M_ft)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))
