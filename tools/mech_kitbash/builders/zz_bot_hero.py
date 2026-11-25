"""
B.o.T (Battle of Titans) Hero Combat & Hangar Module Pack (MECH_MODELING_STANDARD + BOT_VISUAL_STANDARD).
Covers the 8 high-visibility modules across Hangar (spot_02), Raid (fps_shot / playshot), and Gallery:
  - legs_biped_assault (VK-5 Heavy Assault Biped Chassis)
  - arm_ac30           (AC-30 30mm Chain Autocannon w/ B.o.T Glowing Radiator Louver Pod)
  - arm_hmg            (HMG-24 Heavy Machine Gun w/ Perforated Shroud & Side Ammo Box)
  - arm_slug           (SLG-12 Breaching Cannon w/ 6-Round Brass/Oxide Shell Saddle)
  - back_missile       (MS-6 Twin 6-Cell Pods + B.o.T Center Spine Exposed Tactical Missile)
  - back_shield        (SH-3 Heavy Tri-Vane Phase Shield Projector w/ Radiator Arc)
  - gen_reactor        (RT-1 Micro-Reactor w/ B.o.T Twin Curved Glowing Green Louver Fans)
  - gen_diesel         (DS-6 Armored Turbo-Diesel APU w/ Twin Perforated Exhaust Stacks)
"""
import math
from mathutils import Vector
from kitbash_lib import KitbashScene, g2b_mat, g2b_bone_mat, crect_2d, trap_2d


# ==============================================================================
# 1. legs_biped_assault — VK-5 Heavy Tactical Assault Biped Chassis
# ==============================================================================
def build_legs_biped_assault(kb: KitbashScene):
    hip = 1.66
    socket_y = hip + 0.44  # 2.10m compact flush waist ring!

    kb.use_group("Body")
    # Heavy forged pelvis cradle + upper skirt deck (stepped clear of Leg_L/R HipDrum!)
    kb.box("PelvisFrame", (0.94, 0.44, 0.86), "dark", "frame_cnc", (0, hip + 0.05, 0.02), (0, 0, 0), 0.024, 1)
    kb.box("PelvisDeck", (0.90, 0.22, 0.74), "armor_sub", "armor_pocket", (0, hip + 0.26, 0.02), (0, 0, 0), 0.020, 1)
    # Central ballistic codpiece + B.o.T articulated left/right fauld skirts (VK-54 stencil on right!)
    kb.plate("Codpiece", trap_2d(0.44, 0.54, 0.54, 0.06), 0.22, "armor_oxide", "weld_plate",
             (0, hip - 0.04, -0.48), (10, 0, 0), 0.026, 1)
    kb.box("CodHazard", (0.32, 0.050, 0.024), "hazard", "hazard", (0, hip + 0.14, -0.605), (10, 0, 0), 0.004, 1)
    for fi, sx_f in enumerate([-0.46, 0.46]):
        sf = -1.0 if sx_f < 0 else 1.0
        M_fl = g2b_mat((sx_f, hip + 0.02, -0.46), (14, sf * -10.0, sf * -6.0))
        kb.plate(f"Fauld_{fi}", trap_2d(0.48, 0.40, 0.48, 0.05), 0.12, "armor", "armor_slab",
                 (0, -0.08, 0), (0, 0, 0), 0.024, 1, M_parent=M_fl)
        kb.cyl(f"FauldHinge_{fi}", 0.036, 0.036, 0.20, 12, "gunmetal", "gear_collar",
               (0, 0.14, 0.02), (0, 0, 90), 0.004, M_parent=M_fl)
        if sf > 0:
            kb.decal("FauldStencil", "unit_54", (0.24, 0.20), (0, -0.08, -0.068), (0, 0, 0), M_parent=M_fl)
        else:
            kb.decal("FauldTri", "hazard_tri", (0.14, 0.14), (0, -0.08, -0.068), (0, 0, 0), M_parent=M_fl)
    # Rear ballistic tail skirt + twin louver vents
    kb.plate("RearSkirt", trap_2d(1.04, 1.24, 0.48, 0.08), 0.14, "armor_sub", "armor_hatch",
             (0, hip - 0.01, 0.48), (-14, 0, 0), 0.022, 1)
    kb.louver_bay("RearPelvisVent", 0.60, 0.18, 0.045, (0, hip + 0.03, 0.560), (-14, 180, 0), blades=5, mesh_style=False)
    for sx_i, sx_g in enumerate([-0.36, 0.36]):
        kb.hydraulic(f"WaistStabF_{sx_i}", (sx_g, hip + 0.28, -0.22), (sx_g * 0.64, hip + 0.40, -0.15), 0.022)
        kb.hydraulic(f"WaistStabR_{sx_i}", (sx_g, hip + 0.28,  0.22), (sx_g * 0.64, hip + 0.40,  0.15), 0.022)
    kb.waist_collar_legs("HP_C1_Legs", socket_y, hip + 0.35)

    KN = Vector((0.0, -0.76, -0.22))
    AN = Vector((0.0, -1.38, -0.02))
    sole_rel = -1.66 - hip  # -3.32m exact match to legs_biped_assault.gd

    for side_tag, sx in [("Leg_L", -0.76), ("Leg_R", 0.76)]:
        side = -1.0 if sx < 0 else 1.0
        g_leg = kb.add_group(side_tag, side_tag, pos=(sx, hip, 0.0))
        kb.use_group(g_leg)
        kb.add_marker("MARK_SOLE", (0.0, sole_rel, 0.0), parent_key=g_leg)

        # Heavy hip drum + ERA side skirt shield (stepped X planes)
        kb.actuator_drum(f"{side_tag}_HipDrum", (-side * 0.02, 0, 0), 0.28, 0.48)
        M_hs = g2b_mat((side * 0.37, -0.04, 0.0), (0, side * 90.0, -side * 8.0))
        kb.plate(f"{side_tag}_HipShld", trap_2d(0.80, 0.62, 0.56, 0.08), 0.14, "armor_sub", "weld_plate",
                 (0, 0, 0), (0, 0, 0), 0.022, 1, M_parent=M_hs)
        kb.era_block(f"{side_tag}_HipERA", (0.40, 0.22, 0.072), "armor_oxide", (0, 0.06, -0.115), M_parent=M_hs)
        kb.grab_rail(f"{side_tag}_HipGrab", 0.24, 0.04, (0, 0.26, -0.02), (-90, 0, 0), 0.011, M_parent=M_hs)

        # Muscular Thigh assembly (stepped inside KneeDrum 0.60 -> +/-0.30)
        M_th = g2b_bone_mat((0, 0, 0), KN)
        l1 = KN.length
        l1_s = l1 - 0.26
        y_th_m = -(0.14 + 0.5 * l1_s)
        kb.box(f"{side_tag}_ThighCore", (0.40, l1_s, 0.50), "dark", "frame_cnc", (0, y_th_m, 0.02), (0, 0, 0), 0.020, 1, M_parent=M_th)
        kb.plate(f"{side_tag}_ThighFront", trap_2d(0.46, 0.56, l1_s * 0.94, 0.07), 0.17, "armor", "armor_slab",
                 (0, y_th_m, -0.28), (-2, 0, 0), 0.026, 1, M_parent=M_th)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{side_tag}_ThighSide_{s2i}", crect_2d(0.46, l1_s * 0.84, (0.06, 0.06, 0.05, 0.05)), 0.090, "armor_sub", "armor_ribs",
                     (s2 * 0.232, y_th_m, 0.0), (0, s2 * 90.0, 0), 0.016, 1, M_parent=M_th)
        kb.hydraulic(f"{side_tag}_ThighHydA", (side * 0.14, -0.12, 0.30), (side * 0.14, -l1 + 0.12, 0.26), 0.034, M_parent=M_th)
        kb.hydraulic(f"{side_tag}_ThighHydB", (-side * 0.14, -0.12, 0.30), (-side * 0.14, -l1 + 0.12, 0.26), 0.028, M_parent=M_th)

        kb.actuator_drum(f"{side_tag}_KneeDrum", KN, 0.24, 0.60)

        # Knee & Shin pivot group
        g_knee = kb.add_group(f"{side_tag}/Knee", "Knee", pos=(KN.x, KN.y, KN.z), parent_key=g_leg)
        kb.use_group(g_knee)
        rel_an = AN - KN
        l2 = rel_an.length
        l2_s = l2 - 0.26
        y_sh_m = -(0.14 + 0.5 * l2_s)
        M_sh = g2b_bone_mat((0, 0, 0), rel_an)

        # Tall ERA Ramming Knee Shield
        M_ks = g2b_mat((0, 0.08, -0.33), (-12, 0, 0))
        kb.plate(f"{side_tag}_KneeShield", trap_2d(0.54, 0.42, 0.50, 0.07), 0.18, "armor", "armor_slab",
                 (0, 0, 0), (0, 0, 0), 0.026, 1, M_parent=M_ks)
        kb.era_block(f"{side_tag}_KneeERA", (0.34, 0.17, 0.068), "armor_oxide", (0, 0.06, -0.130), M_parent=M_ks)
        kb.box(f"{side_tag}_KneeHaz", (0.36, 0.048, 0.024), "hazard", "hazard", (0, -0.13, -0.108), (0, 0, 0), 0.003, 1, M_parent=M_ks)

        # Flared heavy shin greaves (terminated cleanly above AnkDrum/SabatonCore!)
        kb.box(f"{side_tag}_ShinCore", (0.40, l2_s, 0.50), "dark", "frame_cnc", (0, y_sh_m, 0.04), (0, 0, 0), 0.020, 1, M_parent=M_sh)
        kb.plate(f"{side_tag}_ShinFront", trap_2d(0.56, 0.46, l2_s * 0.94, 0.07), 0.18, "armor", "armor_slab",
                 (0, y_sh_m, -0.28), (4, 0, 0), 0.026, 1, M_parent=M_sh)
        for s2i, s2 in enumerate([-1.0, 1.0]):
            kb.plate(f"{side_tag}_ShinSide_{s2i}", trap_2d(0.54, 0.42, l2_s * 0.88, 0.06), 0.092, "armor_sub", "weld_plate",
                     (s2 * 0.236, y_sh_m, 0.04), (0, s2 * 90.0, 0.0), 0.016, 1, M_parent=M_sh)
            if s2 * side > 0:
                kb.decal(f"{side_tag}_ShinTri", "hazard_tri", (0.15, 0.15), (s2 * 0.288, y_sh_m, 0.04), (0, -s2 * 90.0, 0), M_parent=M_sh)
        kb.coil_shock(f"{side_tag}_CalfShock", (side * 0.15, -0.08, 0.30), (rel_an.x + side * 0.14, rel_an.y + 0.12, rel_an.z + 0.26), 0.038)

        M_cp = M_sh @ g2b_mat((0, y_sh_m + 0.02, 0.37), (16, 0, 0))
        kb.box(f"{side_tag}_CalfPod", (0.42, 0.34, 0.22), "armor_sub", "armor_pocket", (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_cp)
        kb.louver_bay(f"{side_tag}_CalfVent", 0.32, 0.14, 0.036, (0, 0.06, 0.122), (0, 180, 0), blades=4, mesh_style=False, M_parent=M_cp)
        for ni, nzx in enumerate([-0.12, 0.12]):
            kb.cyl(f"{side_tag}_CalfNoz_{ni}", 0.068, 0.096, 0.13, 14, "gunmetal", "plain_metal", (nzx, -0.19, 0.04), (-20, 0, 0), 0.005, hollow_r=0.056, M_parent=M_cp)

        # Ankle & Wide Heavy Sabaton Boot
        g_ank = kb.add_group(f"{side_tag}/Ankle", "Ankle", pos=(rel_an.x, rel_an.y, rel_an.z), parent_key=g_knee)
        kb.use_group(g_ank)
        kb.actuator_drum(f"{side_tag}_AnkDrum", (0, 0, 0), 0.18, 0.36)
        ft_off = Vector((0.0, -1.54, -0.04)) - AN
        M_ft = g2b_mat((ft_off.x, ft_off.y, ft_off.z), (0, 0, 0))
        kb.box(f"{side_tag}_SabatonCore", (0.64, 0.20, 0.84), "gunmetal", "frame_cnc", (0, 0.02, -0.04), (0, 0, 0), 0.022, 1, M_parent=M_ft)
        kb.plate(f"{side_tag}_SabatonInstep", trap_2d(0.62, 0.46, 0.46, 0.06), 0.18, "armor", "armor_slab",
                 (0, 0.14, -0.24), (-68, 0, 0), 0.024, 1, M_parent=M_ft)
        kb.plate(f"{side_tag}_SabatonToe", trap_2d(0.60, 0.50, 0.26, 0.04), 0.14, "armor_oxide", "armor_ribs",
                 (0, 0.02, -0.48), (-24, 0, 0), 0.018, 1, M_parent=M_ft)
        kb.box(f"{side_tag}_SabatonSole", (0.68, 0.056, 0.90), "rubber", "dust_boot", (0, -0.095, -0.04), (0, 0, 0), 0.010, 1, M_parent=M_ft)
        kb.plate(f"{side_tag}_HeelSpade", trap_2d(0.54, 0.44, 0.24, 0.04), 0.10, "gunmetal", "bolt_flange",
                 (0, 0.0, 0.42), (24, 0, 0), 0.014, 1, M_parent=M_ft)
        for hi, hx in enumerate([-0.18, 0.18]):
            kb.hydraulic(f"{side_tag}_HeelHyd_{hi}", (hx, 0.18, 0.20), (hx, 0.02, 0.40), 0.026, M_parent=M_ft)

    kb.use_group("Body")
    kb.add_marker("SOCKET_core", (0.0, socket_y, 0.0))


# ==============================================================================
# 2. arm_ac30 — AC-30 30mm Chain Autocannon w/ B.o.T Glowing Radiator Pod
# ==============================================================================
def build_arm_ac30(kb: KitbashScene):
    kb.a1_shoulder_mount("A1Heavy", heavy=True)

    # Heavy B.o.T rectangular armored weapon pod + top yellow diagonal chevron + side glowing radiator louver fan!
    M_arm = g2b_mat((0.38, -0.02, 0.0), (0, 0, 0))
    kb.plate("PodUpperArmor", crect_2d(0.96, 0.44, (0.08, 0.08, 0.06, 0.06)), 0.48, "armor", "armor_slab",
             (0.04, 0.10, -0.18), (0, 90, 0), 0.026, 2, M_parent=M_arm)
    kb.decal("PodTopChevron", "caution_chev", (0.34, 0.34), (0.04, 0.323, -0.22), (90, 0, 0), M_parent=M_arm)
    kb.box("ReceiverCore", (0.38, 0.38, 1.02), "dark", "frame_cnc", (0.02, -0.02, -0.26), (0, 0, 0), 0.018, 1, M_parent=M_arm)
    kb.plate("GunMantlet", trap_2d(0.46, 0.38, 0.44, 0.06), 0.14, "armor_oxide", "weld_plate",
             (0.0, 0.02, -0.80), (-12, 0, 0), 0.022, 1, M_parent=M_arm)
    # B.o.T signature outboard glowing green heat-sink radiator louver bank (exact match to crop_mech_desert_0!)
    kb.box("RadPodHousing", (0.18, 0.30, 0.56), "armor_sub", "armor_pocket", (0.30, -0.02, -0.26), (0, 0, 0), 0.016, 1, M_parent=M_arm)
    kb.glow_radiator_arc("SideRadArc", (0.37, -0.02, -0.52), (0, 90, 0), r_outer=0.16, r_inner=0.07, depth=0.06,
                         arc_deg=140.0, blades=7, emit_slot="emit_green", M_parent=M_arm)
    # Under-slung dual-feed ammo cassette + chain drive motor drum
    kb.box("DualAmmoBox", (0.44, 0.26, 0.62), "armor_sub", "armor_hatch", (0.06, -0.35, -0.16), (0, 0, 0), 0.016, 1, M_parent=M_arm)
    kb.decal("AmmoTri", "hazard_tri", (0.14, 0.14), (0.285, -0.35, -0.16), (0, -90, 0), M_parent=M_arm)
    kb.cyl("ChainMotor", 0.105, 0.105, 0.26, 16, "copper", "gear_collar", (0.26, 0.22, 0.12), (0, 0, 90), 0.006, M_parent=M_arm)
    kb.tube_path("FeedHyd", [(0.22, -0.14, 0.14), (0.30, -0.24, -0.02), (0.24, -0.28, -0.24)], 0.016, 8, "gunmetal", "braid_hose", M_parent=M_arm)

    # Corrugated recoil boot + long fluted 30mm barrel + stabilizer truss + double-baffle muzzle brake
    kb.cyl("RecoilBoot", 0.115, 0.125, 0.38, 18, "rubber", "dust_boot", (-0.13, 0.0, -1.02), (90, 0, 0), 0.006, M_parent=M_arm, u_rep=2.0)
    kb.cyl("MainBarrel", 0.056, 0.072, 1.38, 18, "gunmetal", "plain_metal", (-0.13, 0.0, -1.86), (90, 0, 0), 0.004, M_parent=M_arm)
    for ci, zz in enumerate([-1.32, -1.76, -2.20]):
        kb.cyl(f"BarrelCollar_{ci}", 0.082, 0.082, 0.046, 18, "dark", "bolt_flange", (-0.13, 0.0, zz), (90, 0, 0), 0.005, M_parent=M_arm)
    kb.cyl("GasTube", 0.026, 0.028, 0.96, 12, "dark", "plain_metal", (-0.13, 0.095, -1.64), (90, 0, 0), 0.003, M_parent=M_arm)
    # Double-chamber rectangular naval/tank muzzle brake
    kb.box("MuzzleBrake", (0.16, 0.13, 0.22), "gunmetal", "frame_cnc", (-0.13, 0.0, -2.58), (0, 0, 0), 0.010, 1, M_parent=M_arm)
    kb.barrel_bore("AC30Bore", 0.058, 0.038, (-0.13, 0.0, -2.68), depth=0.06, segs=16, M_parent=M_arm)

    kb.add_marker("MUZZLE", (0.25, -0.02, -2.70))


# ==============================================================================
# 3. arm_hmg — HMG-24 Heavy Machine Gun (Perforated Shroud & Outboard Ammo Box)
# ==============================================================================
def build_arm_hmg(kb: KitbashScene):
    kb.a1_shoulder_mount("A1Std", heavy=False)

    M_sh = g2b_mat((0.38, 0.40, 0.02), (0, 0, -10.0))
    kb.plate("Pauldron", trap_2d(0.68, 0.48, 0.22, 0.05), 0.42, "armor", "armor_slab", (0, 0, 0), (0, 90, 0), 0.022, 2, M_parent=M_sh)
    kb.decal("PauldronChev", "caution_chev", (0.26, 0.26), (0.02, 0.113, -0.02), (90, 0, 0), M_parent=M_sh)

    M_arm = g2b_mat((0.35, -0.02, 0.0), (0, 0, 0))
    kb.box("Receiver", (0.34, 0.32, 0.94), "dark", "frame_cnc", (-0.06, -0.02, -0.26), (0, 0, 0), 0.016, 1, M_parent=M_arm)
    kb.plate("TopFeedCover", crect_2d(0.78, 0.14, (0.04, 0.04, 0.02, 0.02)), 0.36, "armor_sub", "armor_hatch",
             (-0.06, 0.18, -0.26), (0, 90, 0), 0.014, 1, M_parent=M_arm)
    kb.grab_rail("TopCarryHandle", 0.26, 0.055, (-0.06, 0.255, -0.34), (-90, 90, 0), 0.010, M_parent=M_arm)
    # Outboard olive/oxide munitions box + articulated brass ammo belt
    kb.box("AmmoBoxBracket", (0.16, 0.08, 0.44), "gunmetal", "bolt_flange", (0.22, -0.18, -0.18), (0, 0, 0), 0.008, 1, M_parent=M_arm)
    kb.plate("AmmoCan", crect_2d(0.48, 0.34, (0.04, 0.04, 0.04, 0.04)), 0.26, "armor_oxide", "weld_plate",
             (0.30, -0.06, -0.18), (0, 90, 0), 0.016, 1, M_parent=M_arm)
    kb.decal("AmmoCanTri", "hazard_tri", (0.14, 0.14), (0.432, -0.06, -0.18), (0, -90, 0), M_parent=M_arm)
    for bi in range(6):
        t = bi / 5.0
        kb.cyl(f"BeltRound_{bi}", 0.016, 0.018, 0.14, 8, "brass", "plain_metal",
               (0.26 - t * 0.14, -0.08 + math.sin(t * math.pi) * 0.12, -0.10 - t * 0.14), (90, 0, 0), 0.002, M_parent=M_arm)

    # Perforated heavy cooling jacket + heavy barrel + recoil buffer + armored optic + conical flash suppressor
    kb.hydraulic("HMGRecoil", (0.08, 0.14, 0.08), (0.08, 0.14, -0.58), 0.020, M_parent=M_arm)
    kb.louver_bay("HMGSideVent", 0.34, 0.14, 0.035, (-0.235, 0.02, -0.32), (0, -90, 0), blades=4, mesh_style=False, M_parent=M_arm)
    kb.eoir_gimbal("HMGOptic", (-0.06, 0.28, -0.58), M_parent=M_arm)
    kb.cyl("BarrelTrunnion", 0.125, 0.135, 0.22, 18, "gunmetal", "gear_collar", (-0.10, 0.0, -0.82), (90, 0, 0), 0.006, M_parent=M_arm)
    kb.bolt_ring("TrunnionBolts", 0.105, 8, 0.009, (-0.10, 0.0, -0.932), (90, 0, 0), M_parent=M_arm)
    kb.cyl("PerforatedJacket", 0.102, 0.102, 0.88, 18, "gunmetal", "vent_mesh", (-0.10, 0.0, -1.36), (90, 0, 0), 0.006, hollow_r=0.078, M_parent=M_arm, u_rep=2.0)
    for ci, zz in enumerate([-1.05, -1.42, -1.76]):
        kb.cyl(f"JacketClamp_{ci}", 0.110, 0.110, 0.036, 18, "dark", "bolt_flange", (-0.10, 0.0, zz), (90, 0, 0), 0.004, M_parent=M_arm)
    kb.cyl("HeavyBarrel", 0.046, 0.054, 1.34, 16, "dark", "plain_metal", (-0.10, 0.0, -1.56), (90, 0, 0), 0.003, M_parent=M_arm)
    kb.cyl("FlashCone", 0.074, 0.050, 0.16, 16, "gunmetal", "plain_metal", (-0.10, 0.0, -2.24), (90, 0, 0), 0.004, hollow_r=0.038, M_parent=M_arm)
    kb.barrel_bore("HMGBore", 0.052, 0.034, (-0.10, 0.0, -2.30), depth=0.05, segs=14, M_parent=M_arm)

    kb.add_marker("MUZZLE", (0.25, -0.02, -2.32))


# ==============================================================================
# 4. arm_slug — SLG-12 Heavy Breaching Slug Cannon (6-Shell Brass/Oxide Saddle)
# ==============================================================================
def build_arm_slug(kb: KitbashScene):
    kb.a1_shoulder_mount("A1Std", heavy=False)

    M_sh = g2b_mat((0.38, 0.38, 0.02), (0, 0, -8.0))
    kb.plate("Pauldron", trap_2d(0.64, 0.46, 0.20, 0.05), 0.40, "armor", "armor_slab", (0, 0, 0), (0, 90, 0), 0.022, 2, M_parent=M_sh)

    M_arm = g2b_mat((0.36, -0.02, 0.0), (0, 0, 0))
    kb.plate("BreachReceiver", crect_2d(0.88, 0.38, (0.08, 0.04, 0.04, 0.08)), 0.36, "armor", "weld_plate",
             (-0.08, 0.02, -0.24), (0, 90, 0), 0.020, 2, M_parent=M_arm)
    kb.box("EjectionPort", (0.032, 0.11, 0.28), "chrome", "plain_metal", (0.092, 0.06, -0.26), (0, 0, 0), 0.004, 1, M_parent=M_arm)
    kb.decal("RecTopChev", "caution_chev", (0.24, 0.24), (-0.08, 0.213, -0.24), (90, 0, 0), M_parent=M_arm)

    # 6-round outboard heavy shotgun shell saddle (brass rims + red-oxide hulls!)
    kb.box("ShellSaddle", (0.045, 0.20, 0.54), "dark", "bolt_flange", (0.11, -0.04, -0.24), (0, 0, 0), 0.006, 1, M_parent=M_arm)
    for si in range(6):
        sz = -0.04 - si * 0.080
        kb.cyl(f"ShellHull_{si}", 0.028, 0.028, 0.15, 12, "armor_oxide", "plain_metal", (0.145, -0.03, sz), (0, 0, 12), 0.003, M_parent=M_arm)
        kb.cyl(f"ShellBrass_{si}", 0.030, 0.030, 0.042, 12, "brass", "plain_metal", (0.135, -0.085, sz), (0, 0, 12), 0.002, M_parent=M_arm)

    # Over-under large-bore slug barrel + perforated heat shield + hydraulic pump guide + tactical reflex sight
    kb.hydraulic("PumpHyd", (-0.22, -0.05, -0.46), (-0.22, -0.05, -1.16), 0.018, M_parent=M_arm)
    kb.louver_bay("BreachHeatVent", 0.36, 0.14, 0.035, (-0.265, 0.04, -0.32), (0, -90, 0), blades=4, mesh_style=True, M_parent=M_arm)
    kb.headlight_cage("TacticalLamp", (-0.24, -0.06, -1.42), (0, 0, 0), M_parent=M_arm)
    kb.cyl("SlugBarrel", 0.068, 0.076, 1.12, 18, "gunmetal", "plain_metal", (-0.11, 0.07, -1.22), (90, 0, 0), 0.005, M_parent=M_arm)
    kb.cyl("BarrelHeatShield", 0.084, 0.084, 0.62, 18, "dark", "vent_mesh", (-0.11, 0.07, -1.04), (90, 0, 0), 0.004, hollow_r=0.072, M_parent=M_arm, u_rep=2.0)
    kb.cyl("MagTube", 0.052, 0.052, 0.96, 16, "dark", "plain_metal", (-0.11, -0.05, -1.14), (90, 0, 0), 0.004, M_parent=M_arm)
    kb.bolt_ring("MagCapBolts", 0.038, 6, 0.007, (-0.11, -0.05, -1.622), (90, 0, 0), M_parent=M_arm)
    kb.box("PumpForend", (0.20, 0.16, 0.48), "rubber", "dust_boot", (-0.11, -0.05, -1.12), (0, 0, 0), 0.014, 1, M_parent=M_arm)
    kb.box("VentRib", (0.062, 0.036, 0.96), "dark", "vent_louver", (-0.11, 0.152, -1.24), (0, 0, 0), 0.004, 1, M_parent=M_arm)
    kb.cyl("BarrelClamp", 0.082, 0.082, 0.065, 16, "gunmetal", "bolt_flange", (-0.11, 0.01, -1.52), (90, 0, 0), 0.005, M_parent=M_arm)
    kb.barrel_bore("SlugBore", 0.074, 0.050, (-0.11, 0.07, -1.78), depth=0.07, segs=18, M_parent=M_arm)

    kb.add_marker("MUZZLE", (0.25, 0.05, -1.82))


# ==============================================================================
# 5. back_missile — MS-6 Twin 6-Cell Pods + B.o.T Center Spine Tactical Missile
# ==============================================================================
def build_back_missile(kb: KitbashScene):
    # 1. Unified HP-B1 clamp (strictly y >= +0.004m so zero core-roof plunge!) + heavy transverse truss beam
    kb.box("B1Clamp", (0.86, 0.14, 0.40), "dark", "frame_cnc", (0, 0.074, 0.08), (0, 0, 0), 0.014, 1)
    kb.box("CrossBeam", (1.52, 0.14, 0.28), "dark", "bolt_flange", (0, 0.154, 0.12), (0, 0, 0), 0.016, 1)

    # 2. ICONIC B.o.T Center Dorsal Open Launch Rail + Exposed Tactical Cruise Missile!
    #    (Directly matches crop_mech_desert_0 & crop_mech_bunker_3 orange warhead + yellow/black booster + green core!)
    M_rail = g2b_mat((0, 0.54, 0.24), (-58, 0, 0))
    kb.box("CenterSpineRail", (0.22, 0.10, 1.06), "gunmetal", "armor_ribs", (0, -0.09, 0.0), (0, 0, 0), 0.010, 1, M_parent=M_rail)
    kb.box("RailHazardTop", (0.20, 0.024, 0.16), "hazard", "hazard", (0, -0.03, -0.44), (0, 0, 0), 0.003, 1, M_parent=M_rail)
    kb.box("RailHazardBot", (0.20, 0.024, 0.16), "hazard", "hazard", (0, -0.03,  0.44), (0, 0, 0), 0.003, 1, M_parent=M_rail)
    # Full-length exposed heavy tactical missile along rail
    kb.cyl("MslBody", 0.072, 0.072, 0.68, 18, "dark", "plain_metal", (0, 0.05, 0.06), (90, 0, 0), 0.004, M_parent=M_rail)
    kb.cyl("MslWarhead", 0.012, 0.072, 0.28, 18, "armor_oxide", "plain_metal", (0, 0.05, -0.42), (90, 0, 0), 0.003, M_parent=M_rail)
    kb.cyl("MslBandYel", 0.080, 0.080, 0.052, 18, "accent", "plain_metal", (0, 0.05, -0.24), (90, 0, 0), 0.002, M_parent=M_rail)
    kb.cyl("MslBandHaz", 0.080, 0.080, 0.068, 18, "hazard", "hazard", (0, 0.05, 0.22), (90, 0, 0), 0.002, M_parent=M_rail)
    kb.box("MslGlowCell", (0.042, 0.024, 0.16), "emit_green", "plain_metal", (0, 0.130, 0.02), (0, 0, 0), 0.002, 1, M_parent=M_rail)
    for fi in range(4):
        fa = math.pi * 0.25 + math.tau * fi / 4.0
        M_fn = M_rail @ g2b_mat((0, 0.05, 0.34), (0, 0, math.degrees(fa)))
        kb.plate(f"MslFin_{fi}", trap_2d(0.14, 0.06, 0.12, 0.01), 0.012, "gunmetal", "plain_metal",
                 (0, 0.11, 0), (0, 90, 0), 0.002, 1, M_parent=M_fn)

    # 3. Left & Right Hydraulic Elevation Pylons + Armored 6-Cell Missile Pods
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"Pylon_{si}", (0.20, 0.32, 0.26), "gunmetal", "bolt_flange", (sx * 0.64, 0.25, 0.15), (0, 0, sx * -14.0), 0.014, 1)
        kb.hydraulic(f"PodElevHyd_{si}", (sx * 0.28, 0.10, 0.08), (sx * 0.66, 0.30, 0.24), 0.024)
        M_pod = g2b_mat((sx * 0.77, 0.46, 0.18), (-16, 0, 0))
        kb.plate(f"PodShell_{si}", crect_2d(0.88, 0.48, (0.14, 0.06, 0.04, 0.04)), 0.58, "armor", "armor_slab",
                 (0, 0, 0), (0, 90, 0), 0.026, 2, M_parent=M_pod)
        kb.plate(f"PodCowl_{si}", crect_2d(0.52, 0.16, (0.04, 0.04, 0.02, 0.02)), 0.62, "armor_oxide", "weld_plate",
                 (0, 0.19, 0.10), (0, 90, 0), 0.014, 1, M_parent=M_pod)
        kb.decal(f"PodTri_{si}", "hazard_tri", (0.16, 0.16), (sx * 0.296, -0.02, -0.08), (0, sx * -90.0, 0), M_parent=M_pod)
        kb.grab_rail(f"PodGrab_{si}", 0.24, 0.042, (0, 0.275, -0.06), (-90, 90, 0), 0.010, M_parent=M_pod)
        kb.box(f"PodFace_{si}", (0.54, 0.42, 0.045), "gunmetal", "bolt_flange", (0, 0, -0.43), (0, 0, 0), 0.010, 1, M_parent=M_pod)
        for i in range(3):
            for j in range(2):
                mx, my = -0.165 + i * 0.165, 0.095 - j * 0.19
                kb.barrel_bore(f"Cell_{si}_{i}_{j}", 0.068, 0.056, (mx, my, -0.455), depth=0.10, segs=14, M_parent=M_pod)
                kb.cyl(f"Tip_{si}_{i}_{j}", 0.016, 0.044, 0.055, 12, "armor_oxide", "plain_metal", (mx, my, -0.452), (90, 0, 0), 0.003, M_parent=M_pod)
        kb.louver_bay(f"PodExhaust_{si}", 0.42, 0.26, 0.04, (0, 0, 0.445), (0, 180, 0), blades=4, mesh_style=False, M_parent=M_pod)


# ==============================================================================
# 6. back_shield — SH-3 Heavy Tri-Vane Field Shield Projector
# ==============================================================================
def build_back_shield(kb: KitbashScene):
    kb.box("B1Clamp", (0.82, 0.12, 0.42), "dark", "frame_cnc", (0, 0.05, 0.09), (0, 0, 0), 0.014, 1)
    # Armored high-voltage capacitor housing + oxide heat cowl + copper coil insulators
    kb.plate("GenBox", crect_2d(0.92, 0.42, (0.08, 0.08, 0.05, 0.05)), 0.56, "armor", "armor_slab",
             (0, 0.28, 0.26), (0, 0, 0), 0.024, 2)
    kb.box("GenTopDeck", (0.82, 0.08, 0.48), "armor_sub", "weld_plate", (0, 0.51, 0.26), (0, 0, 0), 0.014, 1)
    kb.decal("GenUnitDecal", "unit_08", (0.24, 0.14), (0, 0.556, 0.12), (-90, 180, 0))
    kb.louver_bay("GenRearVent", 0.52, 0.16, 0.038, (0, 0.26, 0.542), (0, 180, 0), blades=4, mesh_style=True)

    # 3 copper high-voltage bushing coils flanking central telescoping mast
    for ci, cx in enumerate([-0.26, 0.0, 0.26]):
        for ri in range(4):
            kb.cyl(f"Insulator_{ci}_{ri}", 0.052, 0.058, 0.026, 14, "copper", "plain_metal",
                   (cx, 0.58 + ri * 0.042, 0.26), (0, 0, 0), 0.003)
        kb.cyl(f"InsStem_{ci}", 0.028, 0.028, 0.22, 12, "chrome", "plain_metal", (cx, 0.64, 0.26), (0, 0, 0), 0.003)

    # Elevated Tri-Vane Armored Phase Emitter Crown
    kb.box("MastPylon", (0.20, 0.42, 0.22), "dark", "frame_cnc", (0, 0.82, 0.28), (-10, 0, 0), 0.014, 1)
    for si, sx in enumerate([-0.22, 0.22]):
        kb.hydraulic(f"MastHyd_{si}", (sx, 0.52, 0.16), (sx * 0.65, 0.88, 0.24), 0.020)
    M_crn = g2b_mat((0, 1.04, 0.30), (-8, 0, 0))
    kb.box("CrownHub", (0.86, 0.16, 0.22), "gunmetal", "bolt_flange", (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_crn)
    for vi, (vx, vyaw) in enumerate([(-0.34, 16.0), (0.0, 0.0), (0.34, -16.0)]):
        M_vn = M_crn @ g2b_mat((vx, 0.04, -0.02), (0, vyaw, 0))
        kb.plate(f"EmitterVane_{vi}", crect_2d(0.26, 0.32, (0.04, 0.04, 0.04, 0.04)), 0.14, "armor_sub", "armor_pocket",
                 (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_vn)
        kb.box(f"VaneRecess_{vi}", (0.20, 0.08, 0.016), "bore", "plain_metal", (0, 0.04, -0.064), (0, 0, 0), 0.003, 1, M_parent=M_vn)
        kb.box(f"VaneGlow_{vi}", (0.18, 0.036, 0.012), "emit_cyan", "plain_metal", (0, 0.04, -0.080), (0, 0, 0), 0.002, 1, M_parent=M_vn)
        kb.box(f"VaneGlowB_{vi}", (0.18, 0.036, 0.012), "emit_cyan", "plain_metal", (0, 0.04,  0.080), (0, 0, 0), 0.002, 1, M_parent=M_vn)


# ==============================================================================
# 7. gen_reactor — RT-1 Micro-Reactor w/ B.o.T Twin Curved Glowing Green Louvers
# ==============================================================================
def build_gen_reactor(kb: KitbashScene):
    # Origin (0,0,0) = HP-G1 mating face; +Z points rearward out of core back!
    kb.plate("G1Plate", crect_2d(0.86, 0.68, (0.10, 0.10, 0.10, 0.10)), 0.11, "dark", "bolt_flange", (0, 0, 0.058), (0, 0, 0), 0.014, 1)
    for ci, (cx, cy) in enumerate([(-0.34, -0.25), (0.34, -0.25), (-0.34, 0.25), (0.34, 0.25)]):
        kb.cyl(f"LockPin_{ci}", 0.032, 0.034, 0.058, 10, "chrome", "plain_metal", (cx, cy, 0.128), (90, 0, 0), 0.004)

    M_b = g2b_mat((0.0, 0.0, 0.11), (0, 0, 0))
    # Heavy faceted armored reactor containment carapace + oxide upper heat shroud
    kb.plate("ReactorCarapace", trap_2d(0.92, 0.76, 0.62, 0.09), 0.42, "armor", "armor_slab",
             (0, 0.02, 0.21), (0, 0, 0), 0.026, 2, M_parent=M_b)
    kb.plate("ReactorTopHood", crect_2d(0.68, 0.38, (0.06, 0.06, 0.04, 0.04)), 0.08, "armor_oxide", "weld_plate",
             (0, 0.33, 0.22), (90, 0, 0), 0.016, 1, M_parent=M_b)
    kb.decal("ReactorUnit17", "unit_17", (0.24, 0.22), (0, 0.14, 0.424), (0, 180, 0), M_parent=M_b)
    kb.box("ReactorHaz", (0.54, 0.042, 0.020), "hazard", "hazard", (0, -0.26, 0.422), (0, 0, 0), 0.003, 1, M_parent=M_b)

    # ICONIC B.o.T Twin Semi-Circular Recessed Glowing Lime-Green Radiator Louver Fans (left & right!)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.cyl(f"RadWell_{si}", 0.22, 0.23, 0.08, 20, "dark", "frame_cnc",
               (sx * 0.24, -0.02, 0.40), (90, 0, 0), 0.008, hollow_r=0.18, M_parent=M_b)
        kb.glow_radiator_arc(f"RadFan_{si}", (sx * 0.24, -0.02, 0.425), (0, 180, sx * -20.0),
                             r_outer=0.19, r_inner=0.08, depth=0.065, arc_deg=165.0, blades=9, emit_slot="emit_green", M_parent=M_b)
        kb.tube_path(f"CoolantLoop_{si}", [(sx * 0.36, 0.20, 0.04), (sx * 0.44, 0.12, 0.24), (sx * 0.34, -0.02, 0.38)],
                     0.024, 8, "copper", "plain_metal", M_parent=M_b)
        kb.grab_rail(f"SideGrab_{si}", 0.22, 0.040, (sx * 0.46, 0.04, 0.22), (0, -sx * 90.0, 0), 0.010, M_parent=M_b)

    kb.add_marker("LIGHT_core", (0.0, -0.02, 0.66))


# ==============================================================================
# 8. gen_diesel — DS-6 Heavy Armored Turbo-Diesel APU w/ Twin Exhaust Stacks
# ==============================================================================
def build_gen_diesel(kb: KitbashScene):
    kb.plate("G1Plate", crect_2d(0.84, 0.66, (0.10, 0.10, 0.10, 0.10)), 0.11, "dark", "bolt_flange", (0, 0, 0.058), (0, 0, 0), 0.014, 1)
    M_b = g2b_mat((0.0, 0.0, 0.11), (0, 0, 0))

    # Inline armored engine enclosure + cast-iron ribbed cylinder head + rear radiator grille
    kb.box("EngineBlock", (0.78, 0.56, 0.40), "armor", "armor_slab", (0, -0.02, 0.225), (0, 0, 0), 0.024, 2, M_parent=M_b)
    kb.box("ValveCover", (0.56, 0.12, 0.32), "armor_oxide", "armor_ribs", (0, 0.30, 0.21), (0, 0, 0), 0.014, 1, M_parent=M_b)
    kb.louver_bay("RearRadBay", 0.58, 0.34, 0.045, (0, -0.02, 0.435), (0, 180, 0), blades=6, mesh_style=False, M_parent=M_b)
    kb.decal("DieselSoot", "soot_ring", (0.24, 0.24), (-0.22, 0.14, 0.464), (0, 180, 0), M_parent=M_b)
    kb.decal("DieselTri", "hazard_tri", (0.14, 0.14), (0.24, -0.14, 0.464), (0, 180, 0), M_parent=M_b)
    kb.box("LowerBumper", (0.74, 0.055, 0.045), "hazard", "hazard", (0, -0.28, 0.440), (0, 0, 0), 0.005, 1, M_parent=M_b)

    # Twin vertical perforated exhaust mufflers + hinged rain caps + fuel filter canisters
    for si, sx in enumerate([-0.34, 0.34]):
        kb.box(f"ExhManifold_{si}", (0.14, 0.12, 0.16), "dark", "bolt_flange", (sx, 0.22, 0.18), (0, 0, 0), 0.008, 1, M_parent=M_b)
        kb.cyl(f"MufflerJacket_{si}", 0.072, 0.072, 0.48, 16, "gunmetal", "vent_mesh", (sx, 0.50, 0.18), (0, 0, 0), 0.005, hollow_r=0.056, M_parent=M_b, u_rep=2.0)
        kb.cyl(f"ExhPipe_{si}", 0.048, 0.052, 0.62, 14, "dark", "plain_metal", (sx, 0.54, 0.18), (0, 0, 0), 0.004, hollow_r=0.036, M_parent=M_b)
        kb.plate(f"RainFlap_{si}", crect_2d(0.12, 0.12, (0.02, 0.02, 0.02, 0.02)), 0.016, "gunmetal", "plain_metal",
                 (sx, 0.87, 0.18), (72, 0, 0), 0.003, 1, M_parent=M_b)
        kb.cyl(f"FuelFilter_{si}", 0.058, 0.058, 0.18, 14, "copper", "plain_metal", (sx * 1.12, -0.14, 0.22), (0, 0, 0), 0.004, M_parent=M_b)
        kb.tube_path(f"FuelLine_{si}", [(sx * 1.12, -0.04, 0.22), (sx * 1.18, 0.10, 0.22), (sx * 0.90, 0.20, 0.20)],
                     0.014, 8, "brass", "braid_hose", add_clamps=True, M_parent=M_b)
        kb.cyl(f"SideFuelDrum_{si}", 0.115, 0.115, 0.42, 18, "armor_sub", "armor_pocket", (sx * 1.38, 0.02, 0.20), (0, 0, 0), 0.008, M_parent=M_b)
        kb.bolt_ring(f"FuelDrumCap_{si}", 0.075, 8, 0.008, (sx * 1.38, 0.232, 0.20), (0, 0, 0), M_parent=M_b)
        kb.grab_rail(f"DieselGrab_{si}", 0.24, 0.040, (sx * 1.50, 0.02, 0.20), (0, -math.copysign(90.0, sx), 0), 0.010, M_parent=M_b)
    kb.louver_bay("TopAirIntake", 0.46, 0.20, 0.036, (0, 0.365, 0.20), (-90, 0, 0), blades=5, mesh_style=True, M_parent=M_b)
