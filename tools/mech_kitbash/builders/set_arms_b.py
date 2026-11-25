"""
Pack B High-Precision Industrial Mech Arm Weapon Builders (Canonical Right Arm side=+1.0)
MECH_MODELING_STANDARD v1.5 — Zero-Clip Rich Mechanical Standard.

Modules:
  1. build_arm_rail  (RG-9 电磁轨道炮,        MUZZLE z = -2.18)
  2. build_arm_laser (LZ-42 电磁线圈/激光步枪, MUZZLE z = -2.00)
  3. build_arm_gau8  (GAU-8/30 复仇者七管机炮, MUZZLE z = -2.34)
  4. build_arm_rh120 (L55-120 莱茵金属坦克炮,  MUZZLE z = -3.06)
  5. build_arm_tow2b (TOW-2B 陶式双联导弹箱,   MUZZLE z = -0.92)
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


def _trunnion_bridge(kb: KitbashScene, prefix: str, cy: float, cheek_outer_x: float):
    """
    Clean mechanical pitch-trunnion adapter uniting a1_shoulder_mount's yoke (yk ends at x=0.53)
    to the weapon receiver's inboard armor cheek with proud bolted flange (0mm Z-fight, 0mm deep_clip, 0mm float).
    """
    # Proud rectangular trunnion flange seated cleanly onto inboard cheek face (outer face 16mm proud of cheek)
    flg_x = cheek_outer_x - 0.004
    kb.box(f"{prefix}_flg", (0.032, 0.24, 0.28), "gunmetal", "bolt_flange",
           (flg_x, cy, 0.0), (0, 0, 0), 0.005, 1)
    # Cylindrical elevation axle uniting yoke (x=0.53) cleanly into flange (x=flg_x - 0.016)
    x_a0 = 0.512
    x_a1 = flg_x - 0.006
    kb.cyl(f"{prefix}_axle", 0.098, 0.098, max(0.032, x_a1 - x_a0), 16, "dark", "gear_collar",
           ((x_a0 + x_a1) * 0.5, cy, 0.0), (0, 0, 90), 0.004, u_rep=2.0)
    # 4 proud chrome hex mounting bolts on the inboard face of the flange (0mm burial!)
    for bi, (by, bz) in enumerate([(-0.088, -0.105), (0.088, -0.105), (-0.088, 0.105), (0.088, 0.105)]):
        kb.cyl(f"{prefix}_bt{bi}", 0.011, 0.013, 0.016, 6, "chrome", "plain_metal",
               (flg_x - 0.022, cy + by, bz), (0, 0, 90), 0.002)


# ==============================================================================
# 1. RG-9 电磁轨道炮 (arm_rail) — MUZZLE z = -2.18
# ==============================================================================
def build_arm_rail(kb: KitbashScene):
    # 1. Standardized HP-A1 Shoulder Adapter (strictly x >= 0.010 -> 0mm core clash)
    kb.a1_shoulder_mount("A1Rail", heavy=False)
    cx, cy = 0.77, -0.02
    _trunnion_bridge(kb, "RailTrun", cy, cheek_outer_x=0.564)

    # 2. Angular High-Voltage Armored Shoulder Pauldron (strictly outboard x >= 0.18, y >= 0.28)
    M_sh = g2b_mat((0.46, 0.45, 0.02), (0, 0, -10.0))
    kb.plate("PauldronMain", trap_2d(0.76, 0.50, 0.22, 0.06), 0.46, "armor", "armor_panel",
             (0, 0, 0), (0, 90, 0), 0.012, 1, M_parent=M_sh)
    kb.plate("PauldronSub", trap_2d(0.56, 0.36, 0.14, 0.04), 0.068, "armor_sub", "armor_ribs",
             (0.258, -0.01, 0), (0, 90, 0), 0.008, 1, M_parent=M_sh)
    kb.box("PauldronHazard", (0.014, 0.085, 0.42), "hazard", "hazard",
           (0.296, -0.015, 0), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    kb.box("PauldronAccent", (0.014, 0.036, 0.36), "accent", "plain_metal",
           (0.296, 0.056, 0), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    kb.grab_rail("PauldronGrab", 0.22, 0.034, (0.0, 0.106, 0.0), (90, 0, 0), 0.009, M_parent=M_sh)
    for bi, bz in enumerate([-0.18, 0.18]):
        kb.cyl(f"PauldronBolt_{bi}", 0.011, 0.013, 0.018, 6, "chrome", "plain_metal",
               (0.296, -0.070, bz), (0, 0, 90), 0.002, M_parent=M_sh)

    # 3. Breech Capacitor Bank, Radiator Fin Array & Armored Receiver
    M_g = g2b_mat((cx, cy, 0.0), (0, 0, 0))
    # Main CNC breech receiver (x_local ∈ [-0.17, +0.17] -> world x ∈ [0.58, 0.92])
    kb.box("BreechCore", (0.34, 0.40, 0.78), "dark", "frame_cnc",
           (0, 0.0, -0.04), (0, 0, 0), 0.014, 1, M_parent=M_g, tile_u=2.0)
    # Left & right beveled side armor plates (proud outward, 0 Z-fighting)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"BreechCheek_{sxi}", crect_2d(0.72, 0.35, (0.08, 0.04, 0.05, 0.08)), 0.044,
                 "armor", "armor_panel", (sx * 0.184, 0.0, -0.04), (0, 90, 0), 0.009, 1, M_parent=M_g)
    # Outboard side cooling louver bay (front facing +X -> rot=(0,-90,0)) + chrome rivets + HV hazard badge
    kb.louver_bay("BreechLouver", 0.30, 0.14, 0.034, (0.214, -0.01, -0.02), (0, -90, 0),
                  blades=5, mesh_style=False, M_parent=M_g)
    for ri in range(5):
        kb.cyl(f"BreechRivet_{ri}", 0.009, 0.011, 0.014, 6, "chrome", "plain_metal",
               (0.208, 0.132, -0.30 + ri * 0.13), (0, 0, 90), 0.002, M_parent=M_g)
    kb.box("BreechHazard", (0.012, 0.056, 0.24), "hazard", "hazard",
           (0.209, -0.115, 0.14), (0, 0, 0), 0.002, 1, M_parent=M_g)

    # Rear armored capacitor bulkhead & service hatch
    kb.box("RearBulkhead", (0.30, 0.34, 0.09), "gunmetal", "bolt_flange",
           (0, 0.0, 0.38), (0, 0, 0), 0.010, 1, M_parent=M_g)
    kb.box("RearHatch", (0.22, 0.22, 0.028), "armor_sub", "armor_hatch",
           (0, 0.01, 0.432), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.grab_rail("RearGrab", 0.16, 0.028, (0, 0.01, 0.444), (0, 180, 0), 0.008, M_parent=M_g)

    # Dorsal armored heat-sink fin array (7 spaced radiator fins mounted on recessed base rail)
    kb.box("FinBasePlate", (0.28, 0.032, 0.66), "armor_sub", "armor_ribs",
           (0, 0.208, -0.04), (0, 0, 0), 0.006, 1, M_parent=M_g)
    for fi in range(7):
        fz = -0.30 + fi * 0.088
        kb.box(f"DorsalFin_{fi}", (0.29, 0.068, 0.022), "gunmetal", "plain_metal",
               (0, 0.252, fz), (0, 0, 0), 0.003, 1, M_parent=M_g)
    for sxi, sx in enumerate([-0.10, 0.10]):
        kb.box(f"FinTieBar_{sxi}", (0.022, 0.020, 0.62), "dark", "plain_metal",
               (sx, 0.278, -0.04), (0, 0, 0), 0.003, 1, M_parent=M_g)

    # Under-slung 2x2 High-Voltage Pulse Capacitor Bank + Cradle + Clamping Straps
    kb.box("CapCradle", (0.30, 0.048, 0.60), "gunmetal", "bolt_flange",
           (0, -0.214, -0.08), (0, 0, 0), 0.006, 1, M_parent=M_g)
    for ci, sx in enumerate([-0.086, 0.086]):
        for ri, ry in enumerate([-0.282, -0.402]):
            kb.cyl(f"CapCell_{ci}_{ri}", 0.052, 0.052, 0.56, 14, "armor_dark", "gear_collar",
                   (sx, ry, -0.08), (90, 0, 0), 0.005, M_parent=M_g, u_rep=2.0)
            kb.cyl(f"CapFrontCap_{ci}_{ri}", 0.038, 0.042, 0.034, 12, "chrome", "plain_metal",
                   (sx, ry, -0.372), (-90, 0, 0), 0.003, M_parent=M_g)
            kb.cyl(f"CapRearCap_{ci}_{ri}", 0.046, 0.046, 0.026, 12, "copper", "bolt_flange",
                   (sx, ry, 0.208), (90, 0, 0), 0.003, M_parent=M_g)
    # Two vertical saddle straps tying lower capacitor bank tightly into CapCradle (zero floating!)
    for si, sz in enumerate([-0.24, 0.08]):
        kb.box(f"CapStrap_{si}", (0.295, 0.255, 0.036), "dark", "bolt_flange",
               (0, -0.335, sz), (0, 0, 0), 0.004, 1, M_parent=M_g)

    # Braided High-Voltage Power Cables (Capacitor bank -> copper rail bus terminals)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.cyl(f"RailTermLug_{sxi}", 0.026, 0.028, 0.068, 10, "copper", "gear_collar",
               (sx * 0.115, -0.125, -0.50), (0, 0, 90), 0.003, M_parent=M_g)
        kb.cyl(f"CapTermLug_{sxi}", 0.024, 0.026, 0.058, 10, "brass", "bolt_flange",
               (sx * 0.145, -0.320, -0.30), (0, 0, 90), 0.003, M_parent=M_g)
        kb.tube_path(f"HVCable_{sxi}",
                     [(sx * 0.155, -0.320, -0.30),
                      (sx * 0.205, -0.265, -0.40),
                      (sx * 0.185, -0.175, -0.48),
                      (sx * 0.130, -0.125, -0.50)],
                     0.021, 8, "gunmetal", "braid_hose", M_parent=M_g)

    # 4. Twin Parallel Armored Accelerator Rails + Recessed Emit-Cyan Plasma Channel (z = -0.42..-2.06)
    for syi, sy in enumerate([-1.0, 1.0]):
        # Heavy machined structural accelerator beam
        kb.box(f"RailBeam_{syi}", (0.156, 0.082, 1.66), "dark", "frame_cnc",
               (0, sy * 0.116, -1.24), (0, 0, 0), 0.010, 1, M_parent=M_g, tile_u=3.0)
        # Stepped outer armored rail cowling (clearly proud vertically & horizontally -> 0 Z-fighting)
        kb.box(f"RailArmor_{syi}", (0.188, 0.036, 1.56), "armor", "armor_ribs",
               (0, sy * 0.172, -1.21), (0, 0, 0), 0.007, 1, M_parent=M_g, tile_u=3.0)
        # Inner solid copper conductive armature rail facing the central plasma gap
        kb.box(f"RailCopper_{syi}", (0.092, 0.022, 1.64), "copper", "plain_metal",
               (0, sy * 0.066, -1.24), (0, 0, 0), 0.003, 1, M_parent=M_g)

    # Recessed central bore spine + proud dual-sided emit_cyan plasma track cleanly between rails!
    kb.box("PlasmaSpineBore", (0.044, 0.056, 1.56), "bore", "plain_metal",
           (0, 0.0, -1.21), (0, 0, 0), 0.003, 1, M_parent=M_g)
    # Two vertical gusset bridges anchoring PlasmaSpineBore cleanly to upper & lower copper rails (zero floating!)
    for bi, bz in enumerate([-0.68, -1.24, -1.80]):
        kb.box(f"SpineAnchor_{bi}", (0.036, 0.125, 0.044), "dark", "plain_metal",
               (0, 0.0, bz), (0, 0, 0), 0.002, 1, M_parent=M_g)
    # Cleanly seated emit_cyan plasma rails along left & right flanks of the recessed spine (2mm overlap -> 0% buried, 0 Z-fighting!)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.box(f"PlasmaChannel_{sxi}", (0.010, 0.022, 1.48), "emit_cyan", "plain_metal",
               (sx * 0.025, 0.0, -1.21), (0, 0, 0), 0.002, 1, M_parent=M_g)

    # 6 Segmented Anti-Lorentz Clamp Collars with Ceramic Insulator Pads & Chrome Tie-Bolts
    for ci in range(6):
        zz = -0.54 - ci * 0.28
        for sxi, sx in enumerate([-1.0, 1.0]):
            # Outer gunmetal C-clamp jaw gripping rail beams at |x| = 0.078 (clear of plasma strip at |x| = 0.030!)
            kb.box(f"ClampJaw_{ci}_{sxi}", (0.052, 0.36, 0.088), "gunmetal", "bolt_flange",
                   (sx * 0.118, 0.0, zz), (0, 0, 0), 0.008, 1, M_parent=M_g)
            # Ceramic/armor_sub insulator pad clamped onto beam flank
            kb.box(f"ClampIns_{ci}_{sxi}", (0.028, 0.22, 0.068), "armor_sub", "armor_pocket",
                   (sx * 0.084, 0.0, zz), (0, 0, 0), 0.004, 1, M_parent=M_g)
        # Top & bottom cross tie-bars bridging the jaws above/below rail armor
        for syi, sy in enumerate([-1.0, 1.0]):
            kb.box(f"ClampTie_{ci}_{syi}", (0.285, 0.042, 0.074), "dark", "armor_ribs",
                   (0, sy * 0.198, zz), (0, 0, 0), 0.006, 1, M_parent=M_g)
            kb.cyl(f"ClampBolt_{ci}_{syi}", 0.013, 0.015, 0.315, 6, "chrome", "plain_metal",
                   (0, sy * 0.198, zz), (0, 0, 90), 0.002, M_parent=M_g)

    # 5. Arc-Shunt Muzzle Frame & True Hollow Rectangular Bore (reaches z = -2.18)
    # 4 frame walls forming an authentic open rectangular accelerator muzzle aperture (0.11 x 0.13m)
    kb.box("MuzzleFrameTop", (0.28, 0.085, 0.145), "dark", "frame_cnc",
           (0, 0.125, -2.105), (0, 0, 0), 0.009, 1, M_parent=M_g)
    kb.box("MuzzleFrameBot", (0.28, 0.085, 0.145), "dark", "frame_cnc",
           (0, -0.125, -2.105), (0, 0, 0), 0.009, 1, M_parent=M_g)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.box(f"MuzzleFrameSide_{sxi}", (0.082, 0.18, 0.145), "gunmetal", "bolt_flange",
               (sx * 0.100, 0.0, -2.105), (0, 0, 0), 0.008, 1, M_parent=M_g)
        kb.box(f"MuzzleArcVane_{sxi}", (0.022, 0.13, 0.095), "copper", "plain_metal",
               (sx * 0.148, 0.0, -2.105), (0, 0, 0), 0.003, 1, M_parent=M_g)
    kb.box("MuzzleBoreBack", (0.118, 0.165, 0.045), "bore", "plain_metal",
           (0, 0.0, -2.060), (0, 0, 0), 0.002, 1, M_parent=M_g)
    # Compact dorsal target-designator optic box above forward rail clamp
    kb.box("RailOpticBox", (0.11, 0.082, 0.24), "armor_dark", "frame_cnc",
           (0, 0.248, -1.68), (0, 0, 0), 0.008, 1, M_parent=M_g)
    kb.cyl("RailOpticBezel", 0.030, 0.032, 0.034, 14, "gunmetal", "plain_metal",
           (0, 0.248, -1.805), (-90, 0, 0), 0.003, hollow_r=0.022, M_parent=M_g)
    kb.cyl("RailOpticGlass", 0.021, 0.021, 0.012, 14, "glass", "plain_metal",
           (0, 0.248, -1.804), (-90, 0, 0), 0.002, M_parent=M_g)

    # Exact MUZZLE marker aligned with rectangular muzzle tip
    kb.add_marker("MUZZLE", (cx, cy, -2.18))


# ==============================================================================
# 2. LZ-42 电磁线圈/聚焦激光步枪 (arm_laser) — MUZZLE z = -2.00
# ==============================================================================
def build_arm_laser(kb: KitbashScene):
    # 1. Standardized HP-A1 Shoulder Adapter (strictly x >= 0.010 -> 0mm core clash)
    kb.a1_shoulder_mount("A1Laser", heavy=False)
    cx, cy = 0.78, -0.02
    _trunnion_bridge(kb, "LaserTrun", cy, cheek_outer_x=0.565)

    # 2. Sleek Faceted Optical-Grade Shoulder Pauldron
    M_sh = g2b_mat((0.45, 0.44, 0.02), (0, 0, -10.0))
    kb.plate("PauldronMain", trap_2d(0.74, 0.48, 0.21, 0.06), 0.44, "armor", "armor_panel",
             (0, 0, 0), (0, 90, 0), 0.012, 1, M_parent=M_sh)
    kb.plate("PauldronSub", trap_2d(0.54, 0.34, 0.13, 0.04), 0.065, "armor_sub", "armor_pocket",
             (0.245, -0.01, 0), (0, 90, 0), 0.008, 1, M_parent=M_sh)
    kb.box("PauldronAccent", (0.014, 0.048, 0.40), "accent", "plain_metal",
           (0.282, 0.01, 0), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    kb.grab_rail("PauldronGrab", 0.20, 0.032, (0.0, 0.102, 0.0), (90, 0, 0), 0.009, M_parent=M_sh)

    # 3. Armored Optical/Coil Receiver + Dorsal/Ventral Radiator Fin Array + Cryo-Coolant Cell
    M_g = g2b_mat((cx, cy, 0.0), (0, 0, 0))
    # Main optical capacitor receiver (x_local ∈ [-0.18, +0.18] -> world x ∈ [0.56, 0.92])
    kb.box("OpticRecCore", (0.36, 0.40, 0.94), "dark", "frame_cnc",
           (0, 0.0, -0.32), (0, 0, 0), 0.014, 1, M_parent=M_g, tile_u=2.0)
    # Chamfered side armor shrouds on left & right flanks
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"RecShroud_{sxi}", crect_2d(0.88, 0.35, (0.10, 0.04, 0.07, 0.10)), 0.046,
                 "armor", "armor_panel", (sx * 0.192, 0.0, -0.32), (0, 90, 0), 0.009, 1, M_parent=M_g)
    # Top sloped optical capacitor cowl + proud accent stripe
    kb.plate("RecTopCowl", trap_2d(0.82, 0.58, 0.095, 0.03), 0.34, "armor_sub", "armor_hatch",
             (0, 0.228, -0.34), (0, 90, 0), 0.009, 1, M_parent=M_g)
    kb.box("RecAccentBar", (0.014, 0.040, 0.48), "accent", "plain_metal",
           (0.218, 0.115, -0.34), (0, 0, 0), 0.002, 1, M_parent=M_g)
    # Inboard cooling louver bay (facing -X -> rot=(0,+90,0))
    kb.louver_bay("RecInboardVent", 0.34, 0.15, 0.034, (-0.222, 0.0, -0.44), (0, 90, 0),
                  blades=5, mesh_style=False, M_parent=M_g)

    # Dorsal & Ventral Radiator Heat-Sink Fin Arrays
    for fi in range(8):
        fz = 0.02 - fi * 0.088
        kb.box(f"VentralFin_{fi}", (0.31, 0.068, 0.020), "gunmetal", "plain_metal",
               (0, -0.228, fz), (0, 0, 0), 0.003, 1, M_parent=M_g)
    for fi in range(7):
        fz = -0.06 - fi * 0.086
        kb.box(f"DorsalRadFin_{fi}", (0.24, 0.048, 0.018), "gunmetal", "plain_metal",
               (0, 0.292, fz), (0, 0, 0), 0.002, 1, M_parent=M_g)
    # Side radiator fin bank mounted on rear outboard shroud
    kb.box("SideRadBase", (0.034, 0.16, 0.28), "dark", "bolt_flange",
           (0.224, 0.0, 0.02), (0, 0, 0), 0.004, 1, M_parent=M_g)
    for fi in range(5):
        fz = 0.12 - fi * 0.050
        kb.box(f"SideRadFin_{fi}", (0.046, 0.145, 0.016), "gunmetal", "plain_metal",
               (0.252, 0.0, fz), (0, 0, 0), 0.002, 1, M_parent=M_g)

    # Outboard Cryo-Coolant / Pulse Cell Box + Retention Bands + Braided Coolant Pipes
    kb.box("CryoCellBox", (0.16, 0.22, 0.44), "armor_sub", "armor_pocket",
           (0.286, -0.075, -0.34), (0, 0, 0), 0.010, 1, M_parent=M_g)
    for bi, bz in enumerate([-0.46, -0.22]):
        kb.box(f"CryoStrap_{bi}", (0.178, 0.236, 0.028), "dark", "bolt_flange",
               (0.286, -0.075, bz), (0, 0, 0), 0.004, 1, M_parent=M_g)
    kb.box("CryoHazard", (0.012, 0.046, 0.18), "hazard", "hazard",
           (0.370, -0.075, -0.34), (0, 0, 0), 0.002, 1, M_parent=M_g)
    kb.cyl("CryoValveFront", 0.028, 0.032, 0.052, 12, "brass", "gear_collar",
           (0.275, -0.075, -0.575), (-90, 0, 0), 0.003, M_parent=M_g)
    kb.cyl("CryoValveTop", 0.024, 0.026, 0.044, 10, "brass", "gear_collar",
           (0.275, 0.048, -0.22), (0, 0, 0), 0.003, M_parent=M_g)
    # Braided coolant pipe 1: CryoCell front valve -> barrel coil cooling manifold
    kb.tube_path("CoolantPipeLower",
                 [(0.275, -0.075, -0.58), (0.265, -0.105, -0.72), (0.175, -0.085, -0.86), (0.115, -0.045, -0.92)],
                 0.019, 8, "gunmetal", "braid_hose", M_parent=M_g)
    # Braided coolant pipe 2: CryoCell top valve -> dorsal optical manifold
    kb.tube_path("CoolantPipeUpper",
                 [(0.275, 0.055, -0.22), (0.265, 0.175, -0.18), (0.145, 0.260, -0.20), (0.065, 0.265, -0.36)],
                 0.016, 8, "copper", "braid_hose", M_parent=M_g)

    # 4. Stacked Copper & Gunmetal Focusing Coil Barrel + Truss Handguards (z = -0.78..-1.76)
    kb.cyl("OpticalTube", 0.080, 0.084, 1.00, 18, "gunmetal", "plain_metal",
           (0, 0.0, -1.28), (-90, 0, 0), 0.004, M_parent=M_g)
    # 6 Stacked Focusing Coil Stages (wound copper coil + stepped gunmetal stator ring)
    for ci in range(6):
        cz = -0.89 - ci * 0.150
        kb.cyl(f"FocusCoilCu_{ci}", 0.116, 0.116, 0.072, 18, "copper", "gear_collar",
               (0, 0.0, cz), (-90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)
        kb.cyl(f"FocusStator_{ci}", 0.126, 0.126, 0.024, 18, "dark", "bolt_flange",
               (0, 0.0, cz - 0.046), (-90, 0, 0), 0.003, M_parent=M_g, u_rep=2.0)

    # Upper & lower armored skeletal barrel handguards strictly outside coil radius (|y| > 0.126)
    kb.plate("UpperGuard", trap_2d(0.92, 0.78, 0.072, 0.022), 0.22, "armor", "armor_ribs",
             (0, 0.156, -1.28), (0, 90, 0), 0.008, 1, M_parent=M_g)
    kb.plate("LowerGuard", trap_2d(0.78, 0.90, 0.072, 0.022), 0.22, "armor_sub", "armor_ribs",
             (0, -0.156, -1.28), (0, 90, 0), 0.008, 1, M_parent=M_g)
    # 3 Machined Clamp Collars uniting UpperGuard, LowerGuard & OpticalTube (clear of guard faces!)
    for cci, zz in enumerate([-0.96, -1.34, -1.70]):
        for sxi, sx in enumerate([-1.0, 1.0]):
            kb.box(f"CoilClampSide_{cci}_{sxi}", (0.040, 0.38, 0.056), "gunmetal", "bolt_flange",
                   (sx * 0.132, 0.0, zz), (0, 0, 0), 0.006, 1, M_parent=M_g)
        for syi, sy in enumerate([-1.0, 1.0]):
            kb.box(f"CoilClampBridge_{cci}_{syi}", (0.295, 0.036, 0.048), "dark", "armor_ribs",
                   (0, sy * 0.200, zz), (0, 0, 0), 0.004, 1, M_parent=M_g)
            kb.cyl(f"CoilClampBolt_{cci}_{syi}", 0.012, 0.014, 0.32, 6, "chrome", "plain_metal",
                   (0, sy * 0.200, zz), (0, 0, 90), 0.002, M_parent=M_g)

    # Outboard copper feed busbar + brass voltage regulator box + proud amber status diode
    kb.box("CoilBusbar", (0.024, 0.032, 0.76), "copper", "plain_metal",
           (0.162, 0.0, -1.30), (0, 0, 0), 0.003, 1, M_parent=M_g)
    kb.box("CoilRegBox", (0.044, 0.062, 0.092), "brass", "armor_pocket",
           (0.168, 0.0, -1.14), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.cyl("CoilRegLed", 0.010, 0.010, 0.012, 10, "emit_amber", "plain_metal",
           (0.193, 0.0, -1.14), (0, 0, 90), 0.001, M_parent=M_g)

    # 5. Recessed Obsidian Glass Focusing Aperture + Pinpoint Emit-Cyan Core + Protective Muzzle Shroud (z = -2.00)
    # Protective machined outer muzzle shroud (hollow cylindrical collar z = -1.76..-1.96) + stepped crown ring (-1.94..-2.00)
    kb.cyl("MuzzleShroud", 0.114, 0.122, 0.20, 20, "dark", "frame_cnc",
           (0, 0.0, -1.86), (-90, 0, 0), 0.006, hollow_r=0.076, M_parent=M_g, u_rep=2.0)
    kb.cyl("MuzzleCrownRing", 0.126, 0.126, 0.056, 20, "gunmetal", "bolt_flange",
           (0, 0.0, -1.972), (-90, 0, 0), 0.004, hollow_r=0.084, M_parent=M_g, u_rep=2.0)
    # 4 radial muzzle cooling/protector fins seated on shroud exterior
    for fi in range(4):
        fa = math.tau * (fi + 0.5) / 4.0
        kb.box(f"MuzzleFin_{fi}", (0.024, 0.042, 0.18), "gunmetal", "armor_ribs",
               (math.cos(fa) * 0.124, math.sin(fa) * 0.124, -1.86),
               (0, 0, math.degrees(fa) - 90.0), 0.004, 1, M_parent=M_g)
    # Deep pitch-black emitter chamber backing inside hollow shroud (z = -1.80..-1.86)
    kb.cyl("ApertureBack", 0.076, 0.076, 0.060, 16, "bore", "plain_metal",
           (0, 0.0, -1.83), (-90, 0, 0), 0.002, M_parent=M_g)
    # Recessed Obsidian Glass Focusing Lens (strictly recessed inside shroud at z = -1.86..-1.882, 0 burial!)
    kb.cyl("FocusGlassLens", 0.070, 0.070, 0.022, 18, "glass", "plain_metal",
           (0, 0.0, -1.868), (-90, 0, 0), 0.003, M_parent=M_g)
    # Pinpoint Emit-Cyan Emitter Core proud 10mm on front of obsidian lens (only 3mm seating -> 0% buried!)
    kb.cyl("FocusEmitCore", 0.022, 0.024, 0.014, 14, "emit_cyan", "plain_metal",
           (0, 0.0, -1.883), (-90, 0, 0), 0.002, M_parent=M_g)

    # Dorsal Optical Ballistic Rangefinder Sight (obsidian glass optic, mounted cleanly above CoilClampBridge)
    kb.box("LaserSightBody", (0.105, 0.084, 0.28), "dark", "frame_cnc",
           (0, 0.254, -1.66), (0, 0, 0), 0.008, 1, M_parent=M_g)
    kb.cyl("LaserSightBezel", 0.032, 0.034, 0.042, 14, "gunmetal", "plain_metal",
           (0, 0.254, -1.815), (-90, 0, 0), 0.003, hollow_r=0.024, M_parent=M_g)
    kb.cyl("LaserSightGlass", 0.023, 0.023, 0.012, 14, "glass", "plain_metal",
           (0, 0.254, -1.812), (-90, 0, 0), 0.002, M_parent=M_g)

    # Exact MUZZLE marker aligned with focusing shroud aperture
    kb.add_marker("MUZZLE", (cx, cy, -2.00))


# ==============================================================================
# 3. GAU-8/30 复仇者七管 30mm 加特林 (arm_gau8) — MUZZLE z = -2.34
# ==============================================================================
def build_arm_gau8(kb: KitbashScene):
    # 1. Heavy HP-A1 Shoulder Adapter (strictly x >= 0.010 -> 0mm core clash)
    kb.a1_shoulder_mount("A1Gau8", heavy=True)
    cx, cy = 0.81, -0.03
    _trunnion_bridge(kb, "Gau8Trun", cy, cheek_outer_x=0.564)

    # 2. Heavy Armored Shoulder Shield Pauldron
    M_sh = g2b_mat((0.54, 0.54, 0.04), (0, 0, -10.0))
    kb.plate("PauldronMain", trap_2d(0.90, 0.62, 0.26, 0.07), 0.56, "armor", "armor_panel",
             (0, 0, 0), (0, 90, 0), 0.014, 1, M_parent=M_sh)
    kb.plate("PauldronSub", trap_2d(0.70, 0.46, 0.17, 0.05), 0.085, "armor_sub", "armor_hatch",
             (0.305, -0.015, 0), (0, 90, 0), 0.009, 1, M_parent=M_sh)
    kb.box("PauldronHazard", (0.014, 0.14, 0.52), "hazard", "hazard",
           (0.354, -0.02, 0), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    kb.grab_rail("PauldronGrab", 0.24, 0.038, (0.0, 0.128, 0.0), (90, 0, 0), 0.010, M_parent=M_sh)
    for bi, bz in enumerate([-0.22, 0.0, 0.22]):
        kb.cyl(f"PauldronBolt_{bi}", 0.012, 0.014, 0.020, 6, "chrome", "plain_metal",
               (0.354, 0.068, bz), (0, 0, 90), 0.002, M_parent=M_sh)

    # 3. Heavy Rotary Receiver Breech Housing
    M_g = g2b_mat((cx, cy, 0.0), (0, 0, 0))
    # Main CNC receiver (x_local ∈ [-0.21, +0.21] -> world x ∈ [0.56, 0.98])
    kb.box("Gau8RecCore", (0.42, 0.44, 0.72), "dark", "frame_cnc",
           (0, 0.0, -0.08), (0, 0, 0), 0.015, 1, M_parent=M_g, tile_u=2.0)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"Gau8SidePlate_{sxi}", crect_2d(0.68, 0.37, (0.07, 0.05, 0.05, 0.07)), 0.044,
                 "armor", "armor_panel", (sx * 0.224, 0.0, -0.08), (0, 90, 0), 0.009, 1, M_parent=M_g)
    # Outboard recessed cooling vent louver + rivets + accent trim
    kb.louver_bay("Gau8VentBay", 0.30, 0.14, 0.036, (0.254, -0.01, -0.08), (0, -90, 0),
                  blades=5, mesh_style=False, M_parent=M_g)
    for ri in range(6):
        kb.cyl(f"Gau8Rivet_{ri}", 0.009, 0.011, 0.014, 6, "chrome", "plain_metal",
               (0.248, 0.140, -0.34 + ri * 0.105), (0, 0, 90), 0.002, M_parent=M_g)
    kb.box("Gau8TopHatch", (0.34, 0.036, 0.48), "armor_sub", "armor_hatch",
           (0, 0.228, -0.06), (0, 0, 0), 0.006, 1, M_parent=M_g)
    kb.grab_rail("Gau8TopGrab", 0.20, 0.032, (0.0, 0.245, -0.14), (90, 0, 0), 0.009, M_parent=M_g)

    # 4. Bulky Rear Transverse Cylindrical Linkless Ammo Drum with Armored Ribs (z = +0.62)
    # Structural chassis bridge connecting breech (+0.28) solidly to transverse drum (+0.38)
    kb.box("DrumBridge", (0.32, 0.24, 0.28), "dark", "frame_cnc",
           (0, -0.01, 0.36), (0, 0, 0), 0.010, 1, M_parent=M_g)
    dz_drum = 0.62
    kb.cyl("LinklessDrum", 0.252, 0.252, 0.50, 22, "armor_sub", "armor_panel",
           (0, -0.01, dz_drum), (0, 0, 90), 0.010, M_parent=M_g, u_rep=2.0)
    # Left & right bolted drum end rims + 8-bolt rings + central gearbox axle hub
    for sxi, sx in enumerate([-0.242, 0.242]):
        kb.cyl(f"DrumRim_{sxi}", 0.268, 0.268, 0.034, 22, "gunmetal", "bolt_flange",
               (sx, -0.01, dz_drum), (0, 0, 90), 0.005, M_parent=M_g, u_rep=2.0)
        kb.bolt_ring(f"DrumBolts_{sxi}", 0.175, 8, 0.012,
                     (sx + math.copysign(0.019, sx), -0.01, dz_drum),
                     (0, 0, -90 if sx > 0 else 90), M_parent=M_g)
    kb.cyl("DrumAxleHub", 0.088, 0.088, 0.56, 14, "dark", "gear_collar",
           (0, -0.01, dz_drum), (0, 0, 90), 0.005, M_parent=M_g)
    # Central proud hazard ammunition band flanked by 6 pairs of split armored reinforcement ribs (0 clip/burial!)
    kb.cyl("DrumHazardBand", 0.261, 0.261, 0.068, 22, "hazard", "hazard",
           (0, -0.01, dz_drum), (0, 0, 90), 0.002, M_parent=M_g, u_rep=2.0)
    for ri in range(6):
        a = math.tau * ri / 6.0 + math.pi / 6.0
        ry = -0.01 + math.sin(a) * 0.256
        rz = dz_drum + math.cos(a) * 0.256
        for sxi, rx in enumerate([-0.142, 0.142]):
            kb.box(f"DrumRib_{ri}_{sxi}", (0.155, 0.028, 0.032), "dark", "armor_ribs",
                   (rx, ry, rz), (math.degrees(a), 0, 0), 0.004, 1, M_parent=M_g)

    # 5. Dual Closed-Loop Feed & Return Chute Ducts (Drum <-> Breech)
    for dyi, dy in enumerate([-0.165, 0.155]):
        kb.box(f"ChuteDuct_{dyi}", (0.125, 0.088, 0.44), "gunmetal", "armor_ribs",
               (0.150, dy, 0.30), (0, 0, 0), 0.008, 1, M_parent=M_g)
        for ci, cz in enumerate([0.18, 0.32, 0.44]):
            kb.box(f"ChuteBand_{dyi}_{ci}", (0.142, 0.104, 0.028), "dark", "bolt_flange",
                   (0.150, dy, cz), (0, 0, 0), 0.003, 1, M_parent=M_g)

    # 6. Twin Ventral Hydraulic Drive Motors + Brass Fittings + Braided Hoses
    for mi, mx in enumerate([-0.115, 0.115]):
        kb.cyl(f"HydMotor_{mi}", 0.068, 0.068, 0.40, 14, "dark", "gear_collar",
               (mx, -0.275, -0.08), (-90, 0, 0), 0.005, M_parent=M_g, u_rep=2.0)
        kb.cyl(f"HydManifold_{mi}", 0.074, 0.074, 0.044, 14, "brass", "bolt_flange",
               (mx, -0.275, 0.132), (-90, 0, 0), 0.004, M_parent=M_g)
        kb.cyl(f"HydNose_{mi}", 0.056, 0.064, 0.052, 12, "gunmetal", "plain_metal",
               (mx, -0.275, -0.296), (-90, 0, 0), 0.004, M_parent=M_g)
        # Mounting cradle lug tying motor cleanly into breech underside
        kb.box(f"HydMount_{mi}", (0.095, 0.070, 0.28), "gunmetal", "bolt_flange",
               (mx, -0.225, -0.08), (0, 0, 0), 0.005, 1, M_parent=M_g)
        sx = -1.0 if mi == 0 else 1.0
        kb.tube_path(f"HydHose_{mi}",
                     [(mx, -0.275, 0.145),
                      (mx + sx * 0.075, -0.265, 0.24),
                      (mx + sx * 0.080, -0.175, 0.34),
                      (mx + sx * 0.020, -0.110, 0.38)],
                     0.017, 8, "gunmetal", "braid_hose", M_parent=M_g)

    # 7. Iconic A-10 7-Barrel Rotary Cluster (6 Outer + 1 Center) + 3 Perforated Clamp Discs (z = -2.34)
    kb.cyl("RotorHousing", 0.188, 0.198, 0.26, 22, "dark", "gear_collar",
           (0, 0.0, -0.55), (-90, 0, 0), 0.008, M_parent=M_g, u_rep=2.0)
    kb.bolt_ring("RotorBolts", 0.158, 8, 0.011, (0, 0.0, -0.684), (-90, 0, 0), M_parent=M_g)
    # Upper armored heat-deflector hood over forward rotor collar
    kb.plate("RotorHood", trap_2d(0.42, 0.30, 0.44, 0.04), 0.055, "armor", "armor_panel",
             (0, 0.195, -0.82), (88, 0, 0), 0.008, 1, M_parent=M_g)
    kb.box("RotorHoodMesh", (0.24, 0.018, 0.30), "gunmetal", "vent_mesh",
           (0, 0.228, -0.82), (2, 0, 0), 0.003, 1, M_parent=M_g)

    # 6 outer barrels at r_ring=0.096 + 1 center barrel at (0,0), EACH with smooth hollow barrel_bore!
    barrel_coords = [(0.0, 0.0)]
    for bi in range(6):
        a = math.tau * bi / 6.0
        barrel_coords.append((math.cos(a) * 0.096, math.sin(a) * 0.096))

    for bi, (bx, by) in enumerate(barrel_coords):
        kb.cyl(f"GauBarrel_{bi}", 0.027, 0.029, 1.66, 10, "gunmetal" if bi > 0 else "dark", "plain_metal",
               (bx, by, -1.46), (-90, 0, 0), 0.002, M_parent=M_g)
        # Hollow smooth plain_metal muzzle crown extending to z = -2.292 - 0.048 = -2.340!
        kb.barrel_bore(f"GauBore_{bi}", 0.028, 0.019, (bx, by, -2.292),
                       depth=0.068, rot_deg=(-90, 0, 0), segs=10, M_parent=M_g)

    # 3 Heavy Perforated Clamp Discs (hollow outer clamp ring + inner collar + 6 radial perforated webs!)
    for ci, zz in enumerate([-1.02, -1.56, -2.10]):
        kb.cyl(f"ClampRing_{ci}", 0.152, 0.152, 0.056, 20, "gunmetal", "bolt_flange",
               (0, 0.0, zz), (-90, 0, 0), 0.005, hollow_r=0.118, M_parent=M_g, u_rep=2.0)
        kb.cyl(f"ClampBand_{ci}", 0.160, 0.160, 0.022, 20, "dark", "gear_collar",
               (0, 0.0, zz), (-90, 0, 0), 0.003, hollow_r=0.146, M_parent=M_g, u_rep=2.0)
        kb.cyl(f"ClampHub_{ci}", 0.042, 0.042, 0.052, 12, "dark", "bolt_flange",
               (0, 0.0, zz), (-90, 0, 0), 0.003, M_parent=M_g)
        for si in range(6):
            sa = math.tau * si / 6.0
            kb.box(f"ClampWeb_{ci}_{si}", (0.095, 0.020, 0.044), "dark", "plain_metal",
                   (math.cos(sa) * 0.080, math.sin(sa) * 0.080, zz),
                   (0, 0, math.degrees(sa)), 0.003, 1, M_parent=M_g)

    # Forward armored muzzle shroud collar framing the 7-barrel cluster right behind crowns
    kb.cyl("MuzzleShroudCollar", 0.156, 0.152, 0.082, 22, "armor", "armor_ribs",
           (0, 0.0, -2.225), (-90, 0, 0), 0.005, hollow_r=0.125, M_parent=M_g, u_rep=2.0)
    for si in range(3):
        sa = math.tau * si / 3.0 + math.pi / 6.0
        kb.box(f"ShroudStrut_{si}", (0.042, 0.018, 0.042), "gunmetal", "plain_metal",
               (math.cos(sa) * 0.112, math.sin(sa) * 0.112, -2.225),
               (0, 0, math.degrees(sa)), 0.002, 1, M_parent=M_g)

    # Exact MUZZLE marker aligned with 7-barrel muzzle crown tips
    kb.add_marker("MUZZLE", (cx, cy, -2.34))


# ==============================================================================
# 4. L55-120 莱茵金属 120mm 长管滑膛坦克炮 (arm_rh120) — MUZZLE z = -3.06
# ==============================================================================
def build_arm_rh120(kb: KitbashScene):
    # 1. Heavy HP-A1 Shoulder Adapter (strictly x >= 0.010 -> 0mm core clash)
    kb.a1_shoulder_mount("A1Rh120", heavy=True)
    cx, cy = 0.82, -0.03
    _trunnion_bridge(kb, "Rh120Trun", cy, cheek_outer_x=0.564)

    # 2. Leopard 2A7 Composite Shoulder Pauldron
    M_sh = g2b_mat((0.54, 0.55, 0.04), (0, 0, -10.0))
    kb.plate("PauldronMain", trap_2d(0.92, 0.64, 0.26, 0.07), 0.56, "armor", "armor_panel",
             (0, 0, 0), (0, 90, 0), 0.014, 1, M_parent=M_sh)
    kb.plate("PauldronSub", trap_2d(0.72, 0.48, 0.17, 0.05), 0.088, "armor_sub", "armor_pocket",
             (0.308, -0.015, 0), (0, 90, 0), 0.009, 1, M_parent=M_sh)
    kb.box("PauldronAccent", (0.014, 0.055, 0.48), "accent", "plain_metal",
           (0.358, 0.01, 0), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    kb.grab_rail("PauldronGrab", 0.24, 0.038, (0.0, 0.128, 0.0), (90, 0, 0), 0.010, M_parent=M_sh)

    # 3. Armored Breech Cradle, Sliding Wedge Breechblock & Dorsal Recoil Recuperators
    M_g = g2b_mat((cx, cy, 0.0), (0, 0, 0))
    # Main armored breech cradle (x_local ∈ [-0.22, +0.22] -> world x ∈ [0.56, 1.00])
    kb.box("BreechCradle", (0.44, 0.46, 0.94), "armor_sub", "frame_cnc",
           (0, 0.0, 0.06), (0, 0, 0), 0.016, 1, M_parent=M_g, tile_u=2.0)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"CradleCheek_{sxi}", crect_2d(0.86, 0.39, (0.08, 0.05, 0.05, 0.08)), 0.044,
                 "armor", "armor_panel", (sx * 0.234, 0.0, 0.06), (0, 90, 0), 0.009, 1, M_parent=M_g)
    # Inboard rear cooling louver bay strictly BEHIND trunnion/yoke (z ∈ [+0.22, +0.46]) + outboard rivets
    kb.louver_bay("CradleVentBay", 0.24, 0.16, 0.036, (-0.264, -0.01, 0.34), (0, 90, 0),
                  blades=5, mesh_style=False, M_parent=M_g)
    for ri in range(6):
        kb.cyl(f"CradleRivet_{ri}", 0.010, 0.012, 0.014, 6, "chrome", "plain_metal",
               (0.258, 0.148, -0.26 + ri * 0.13), (0, 0, 90), 0.002, M_parent=M_g)
    kb.grab_rail("CradleTopGrab", 0.22, 0.034, (0, 0.234, 0.34), (90, 0, 0), 0.009, M_parent=M_g)

    # Rear sliding-wedge breechblock & recoil guard rail
    kb.box("BreechBlock", (0.34, 0.34, 0.26), "gunmetal", "bolt_flange",
           (0, 0.01, 0.65), (0, 0, 0), 0.012, 1, M_parent=M_g)
    kb.box("BreechHatch", (0.24, 0.22, 0.030), "armor_dark", "armor_hatch",
           (0, 0.01, 0.788), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.cyl("RecoilGuardBar", 0.026, 0.026, 0.38, 12, "chrome", "plain_metal",
           (0, 0.125, 0.81), (0, 0, 90), 0.003, M_parent=M_g)
    for sxi, sx in enumerate([-0.16, 0.16]):
        kb.box(f"GuardBracket_{sxi}", (0.034, 0.048, 0.068), "dark", "plain_metal",
               (sx, 0.125, 0.78), (0, 0, 0), 0.004, 1, M_parent=M_g)

    # Twin Dorsal Hydraulic Recoil Recuperator Cylinders + Chrome Rods + Equalizer Hose
    for sxi, sx in enumerate([-0.135, 0.135]):
        kb.cyl(f"Recuperator_{sxi}", 0.056, 0.056, 0.60, 14, "dark", "gear_collar",
               (sx, 0.275, -0.05), (-90, 0, 0), 0.005, M_parent=M_g, u_rep=2.0)
        kb.cyl(f"RecupSeal_{sxi}", 0.062, 0.062, 0.034, 14, "brass", "bolt_flange",
               (sx, 0.275, -0.355), (-90, 0, 0), 0.003, M_parent=M_g)
        kb.cyl(f"RecupRod_{sxi}", 0.034, 0.034, 0.18, 12, "chrome", "plain_metal",
               (sx, 0.275, -0.44), (-90, 0, 0), 0.003, M_parent=M_g)
    kb.tube_path("RecupEqualizer",
                 [(-0.135, 0.295, 0.24), (-0.06, 0.345, 0.28), (0.06, 0.345, 0.28), (0.135, 0.295, 0.24)],
                 0.015, 8, "gunmetal", "braid_hose", M_parent=M_g)

    # 4. Leopard 2A7 Arrowhead Wedge Composite Gun Mantlet Shield + EMES-15 Gunner Optic
    # Main vertical composite mantlet bulkhead (z = -0.39..-0.55)
    kb.plate("MantletBack", trap_2d(0.47, 0.39, 0.48, 0.055), 0.16, "armor", "armor_panel",
             (0, 0.01, -0.47), (0, 0, 0), 0.014, 1, M_parent=M_g)
    # Iconic upper & lower sloped arrowhead wedge composite plates forming the sharp Leopard 2A7 prow!
    kb.plate("MantletWedgeUp", trap_2d(0.44, 0.34, 0.24, 0.04), 0.082, "armor", "armor_panel",
             (0, 0.135, -0.605), (30, 0, 0), 0.010, 1, M_parent=M_g)
    kb.plate("MantletWedgeDn", trap_2d(0.44, 0.34, 0.24, 0.04), 0.082, "armor_sub", "armor_ribs",
             (0, -0.115, -0.605), (-30, 0, 0), 0.010, 1, M_parent=M_g)
    # Central barrel exit trunnion collar bridging arrowhead prow smoothly to barrel root
    kb.cyl("MantletCollar", 0.134, 0.142, 0.16, 20, "dark", "bolt_flange",
           (0, 0.0, -0.64), (-90, 0, 0), 0.006, M_parent=M_g, u_rep=2.0)
    kb.box("MantletAccent", (0.34, 0.022, 0.056), "accent", "plain_metal",
           (0, 0.258, -0.47), (0, 0, 0), 0.003, 1, M_parent=M_g)

    # Dorsal EMES-15 Auxiliary Gunner Sight Box with Dual Obsidian Glass Optics
    kb.box("SightPedestal", (0.18, 0.068, 0.22), "gunmetal", "bolt_flange",
           (0, 0.265, -0.50), (0, 0, 0), 0.006, 1, M_parent=M_g)
    kb.box("SightHousing", (0.23, 0.135, 0.25), "armor_dark", "armor_pocket",
           (0, 0.355, -0.51), (0, 0, 0), 0.010, 1, M_parent=M_g)
    kb.box("SightHood", (0.236, 0.020, 0.075), "gunmetal", "plain_metal",
           (0, 0.422, -0.645), (8, 0, 0), 0.003, 1, M_parent=M_g)
    for onm, ox, orad, pip in [("Main", -0.048, 0.036, None), ("Lrf", 0.052, 0.025, "emit_amber")]:
        kb.cyl(f"SightBezel_{onm}", orad + 0.008, orad + 0.010, 0.028, 16, "gunmetal", "plain_metal",
               (ox, 0.355, -0.642), (-90, 0, 0), 0.002, hollow_r=orad * 0.84, M_parent=M_g)
        kb.cyl(f"SightGlass_{onm}", orad * 0.82, orad * 0.82, 0.012, 16, "glass", "plain_metal",
               (ox, 0.355, -0.638), (-90, 0, 0), 0.002, M_parent=M_g)
        if pip:
            kb.cyl(f"SightPip_{onm}", 0.007, 0.007, 0.010, 10, pip, "plain_metal",
                   (ox, 0.355, -0.644), (-90, 0, 0), 0.001, M_parent=M_g)

    # 5. Outboard Side-Mounted MG3 Coaxial Machine-Gun Box with Mini Barrel
    kb.box("MG3MountBrk", (0.068, 0.14, 0.34), "gunmetal", "bolt_flange",
           (0.268, 0.04, -0.18), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.box("MG3Receiver", (0.135, 0.19, 0.48), "armor_dark", "armor_pocket",
           (0.355, 0.04, -0.18), (0, 0, 0), 0.010, 1, M_parent=M_g)
    kb.box("MG3FeedCover", (0.115, 0.028, 0.32), "gunmetal", "armor_hatch",
           (0.355, 0.144, -0.16), (0, 0, 0), 0.004, 1, M_parent=M_g)
    kb.box("MG3Hazard", (0.012, 0.040, 0.16), "hazard", "hazard",
           (0.426, -0.01, -0.18), (0, 0, 0), 0.002, 1, M_parent=M_g)
    kb.cyl("MG3Shroud", 0.028, 0.030, 0.40, 12, "gunmetal", "vent_mesh",
           (0.355, 0.06, -0.61), (-90, 0, 0), 0.003, M_parent=M_g, u_rep=2.0)
    kb.cyl("MG3Barrel", 0.015, 0.018, 0.24, 10, "dark", "plain_metal",
           (0.355, 0.06, -0.92), (-90, 0, 0), 0.002, M_parent=M_g)
    kb.barrel_bore("MG3Bore", 0.018, 0.011, (0.355, 0.06, -1.032),
                   depth=0.040, rot_deg=(-90, 0, 0), segs=10, M_parent=M_g)

    # 6. L/55 3-Section Stepped Fiberglass Thermal Barrel Shroud + Eccentric Bore Evacuator + MRS + Smooth Hollow Muzzle
    # Section 1: Rear heavy fiberglass thermal shroud (z = -0.70..-1.50, tapered forward!)
    kb.cyl("ThermalSec1", 0.106, 0.118, 0.80, 18, "armor_sub", "armor_panel",
           (0, 0.0, -1.10), (-90, 0, 0), 0.005, M_parent=M_g, u_rep=2.0)
    for bi, (bz, br) in enumerate([(-0.86, 0.123), (-1.32, 0.116)]):
        kb.cyl(f"ThermalBand1_{bi}", br, br, 0.038, 18, "dark", "bolt_flange",
               (0, 0.0, bz), (-90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)

    # Eccentric Offset Cylindrical Bore Evacuator / Fume Extractor (offset +24mm UP along +Y!)
    kb.cyl("BoreEvacuator", 0.146, 0.148, 0.48, 22, "armor", "armor_panel",
           (0, 0.024, -1.72), (-90, 0, 0), 0.009, M_parent=M_g, u_rep=2.0)
    for ei, (ez, er0, er1) in enumerate([(-1.495, 0.152, 0.126), (-1.945, 0.122, 0.152)]):
        kb.cyl(f"EvacCollar_{ei}", er0, er1, 0.048, 22, "dark", "gear_collar",
               (0, 0.020, ez), (-90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)
    kb.box("EvacDrainLug", (0.044, 0.028, 0.12), "gunmetal", "bolt_flange",
           (0, -0.124, -1.72), (0, 0, 0), 0.004, 1, M_parent=M_g)

    # Section 2: Mid fiberglass thermal shroud (z = -1.94..-2.50, clean 20mm seat into evacuator!)
    kb.cyl("ThermalSec2", 0.090, 0.098, 0.56, 18, "armor_sub", "armor_panel",
           (0, 0.0, -2.22), (-90, 0, 0), 0.005, M_parent=M_g, u_rep=2.0)
    kb.cyl("ThermalBand2", 0.104, 0.104, 0.038, 18, "dark", "bolt_flange",
           (0, 0.0, -2.22), (-90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)

    # Section 3: Forward tapered thermal jacket (z = -2.48..-2.91) + exposed machined muzzle collar (-2.88..-2.985)
    kb.cyl("ThermalSec3", 0.080, 0.088, 0.43, 18, "gunmetal", "plain_metal",
           (0, 0.0, -2.695), (-90, 0, 0), 0.004, M_parent=M_g)
    kb.cyl("ThermalBand3", 0.095, 0.095, 0.036, 18, "dark", "bolt_flange",
           (0, 0.0, -2.54), (-90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)
    kb.cyl("MuzzleSleeve", 0.090, 0.092, 0.105, 18, "dark", "gear_collar",
           (0, 0.0, -2.932), (-90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)

    # Top Muzzle-Reference Sensor (MRS) Mast seated cleanly on MuzzleSleeve
    kb.box("MRSBase", (0.048, 0.038, 0.068), "gunmetal", "bolt_flange",
           (0, 0.098, -2.93), (0, 0, 0), 0.004, 1, M_parent=M_g)
    kb.box("MRSMast", (0.036, 0.072, 0.052), "armor_dark", "frame_cnc",
           (0, 0.146, -2.93), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.cyl("MRSMirrorGlass", 0.015, 0.015, 0.012, 12, "glass", "plain_metal",
           (0, 0.156, -2.900), (90, 0, 0), 0.002, M_parent=M_g)

    # Smooth machined hollow 120mm barrel_bore muzzle extending to exact z = -3.06!
    kb.barrel_bore("Rh120Bore", 0.082, 0.060, (0, 0.0, -2.976),
                   depth=0.120, rot_deg=(-90, 0, 0), segs=20, M_parent=M_g)

    # Exact MUZZLE marker aligned with 120mm hollow crown tip
    kb.add_marker("MUZZLE", (cx, cy, -3.06))


# ==============================================================================
# 5. TOW-2B 陶式双联攻顶反坦克导弹箱 (arm_tow2b) — MUZZLE z = -0.92
# ==============================================================================
def build_arm_tow2b(kb: KitbashScene):
    # 1. Heavy HP-A1 Shoulder Adapter (strictly x >= 0.010 -> 0mm core clash)
    kb.a1_shoulder_mount("A1Atgm", heavy=True)
    cx, cy = 0.85, -0.02
    _trunnion_bridge(kb, "AtgmTrun", cy, cheek_outer_x=0.566)

    # 2. Heavy Bradley-Style Boxy Shoulder Pauldron
    M_sh = g2b_mat((0.54, 0.54, 0.04), (0, 0, -10.0))
    kb.plate("PauldronMain", trap_2d(0.88, 0.62, 0.25, 0.06), 0.54, "armor", "armor_panel",
             (0, 0, 0), (0, 90, 0), 0.014, 1, M_parent=M_sh)
    kb.plate("PauldronSub", trap_2d(0.68, 0.46, 0.16, 0.04), 0.082, "armor_sub", "armor_hatch",
             (0.296, -0.015, 0), (0, 90, 0), 0.009, 1, M_parent=M_sh)
    kb.box("PauldronHazard", (0.014, 0.11, 0.46), "hazard", "hazard",
           (0.344, -0.02, 0), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    kb.grab_rail("PauldronGrab", 0.24, 0.036, (0.0, 0.124, 0.0), (90, 0, 0), 0.010, M_parent=M_sh)

    # 3. Bradley-Style Twin-Cell Armored ATGM Launcher Box
    M_g = g2b_mat((cx, cy, 0.0), (0, 0, 0))
    # Main armored launcher pod hull (x_local ∈ [-0.25, +0.25] -> world x ∈ [0.60, 1.10], z ∈ [-0.72, +0.52])
    kb.box("AtgmPodHull", (0.50, 0.38, 1.24), "armor_sub", "armor_panel",
           (0, 0.0, -0.10), (0, 0, 0), 0.016, 1, M_parent=M_g, tile_u=2.0)
    # Left & right beveled composite side cheek plates + rivets
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"PodSidePlate_{sxi}", crect_2d(1.12, 0.32, (0.08, 0.05, 0.05, 0.08)), 0.044,
                 "armor", "armor_panel", (sx * 0.262, 0.0, -0.10), (0, 90, 0), 0.009, 1, M_parent=M_g)
    for ri in range(6):
        kb.cyl(f"PodRivet_{ri}", 0.010, 0.012, 0.014, 6, "chrome", "plain_metal",
               (0.286, 0.120, -0.52 + ri * 0.168), (0, 0, 90), 0.002, M_parent=M_g)
    # Rear backblast hazard warning stripe on outboard flank + inboard forward cooling louver bay (clear of trunnion!)
    kb.box("PodRearHazard", (0.012, 0.072, 0.28), "hazard", "hazard",
           (0.288, -0.082, 0.24), (0, 0, 0), 0.002, 1, M_parent=M_g)
    kb.louver_bay("PodInboardVent", 0.32, 0.15, 0.034, (-0.292, 0.0, -0.40), (0, 90, 0),
                  blades=5, mesh_style=False, M_parent=M_g)

    # 4 transverse dorsal structural stiffening ribs + dorsal reload grab rail
    for ri, rz in enumerate([-0.54, -0.24, 0.06, 0.36]):
        kb.box(f"PodTopRib_{ri}", (0.516, 0.030, 0.052), "gunmetal", "armor_ribs",
               (0, 0.198, rz), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.grab_rail("PodTopGrab", 0.24, 0.034, (0, 0.192, -0.09), (90, 0, 0), 0.009, M_parent=M_g)
    # Ventral umbilical conduit rail + braided guidance cable into outboard TAS-4 turret
    kb.box("PodBottomRail", (0.36, 0.044, 0.96), "dark", "frame_cnc",
           (0, -0.204, -0.08), (0, 0, 0), 0.006, 1, M_parent=M_g)
    kb.tube_path("TASGuidanceCable",
                 [(0.18, -0.195, -0.02), (0.32, -0.185, -0.04), (0.37, -0.125, -0.12), (0.36, -0.085, -0.18)],
                 0.016, 8, "gunmetal", "braid_hose", M_parent=M_g)

    # Front & rear armored end-bulkhead frames (cleanly stepped 12mm proud of hull ends -> 0 Z-fighting!)
    kb.box("PodFrontFrame", (0.46, 0.34, 0.052), "dark", "bolt_flange",
           (0, 0.0, -0.715), (0, 0, 0), 0.007, 1, M_parent=M_g)
    kb.box("PodRearFrame", (0.46, 0.34, 0.052), "dark", "bolt_flange",
           (0, 0.0, 0.515), (0, 0, 0), 0.007, 1, M_parent=M_g)

    # 4. Top-Hinged Lifted Blast Shield Hood + Dual Hydraulic Support Struts
    # Hinge knuckles + chrome hinge pin at (0, +0.198, -0.710) uniting hood solidly to pod
    for hi, hx in enumerate([-0.145, 0.145]):
        kb.box(f"HoodHinge_{hi}", (0.046, 0.042, 0.052), "gunmetal", "bolt_flange",
               (hx, 0.198, -0.708), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.cyl("HoodHingePin", 0.013, 0.013, 0.42, 10, "chrome", "plain_metal",
           (0, 0.202, -0.712), (0, 0, 90), 0.002, M_parent=M_g)

    # Lifted blast shield hood pitched +28° UP-AND-FORWARD around hinge
    M_hood = M_g @ g2b_mat((0, 0.202, -0.712), (28.0, 0, 0))
    kb.plate("BlastHoodPlate", crect_2d(0.48, 0.31, (0.04, 0.04, 0.04, 0.04)), 0.038,
             "armor", "armor_panel", (0, 0.014, -0.155), (90, 0, 0), 0.007, 1, M_parent=M_hood)
    kb.box("BlastHoodRibL", (0.026, 0.024, 0.26), "dark", "armor_ribs",
           (-0.175, -0.010, -0.150), (0, 0, 0), 0.003, 1, M_parent=M_hood)
    kb.box("BlastHoodRibR", (0.026, 0.024, 0.26), "dark", "armor_ribs",
           (0.175, -0.010, -0.150), (0, 0, 0), 0.003, 1, M_parent=M_hood)
    kb.box("BlastHoodAccent", (0.40, 0.012, 0.044), "accent", "plain_metal",
           (0, 0.036, -0.265), (0, 0, 0), 0.002, 1, M_parent=M_hood)

    # Dual Hydraulic Support Struts uniting PodFrontFrame to underside of BlastHoodPlate!
    ang = math.radians(28.0)
    hood_y_to = 0.202 + (-0.008) * math.cos(ang) - (-0.220) * math.sin(ang)
    hood_z_to = -0.712 + (-0.008) * math.sin(ang) + (-0.220) * math.cos(ang)
    for si, sx in enumerate([-0.205, 0.205]):
        kb.box(f"StrutBrk_{si}", (0.040, 0.048, 0.044), "dark", "bolt_flange",
               (sx, 0.045, -0.735), (0, 0, 0), 0.004, 1, M_parent=M_g)
        kb.hydraulic(f"HoodStrut_{si}", (sx, 0.045, -0.742), (sx, hood_y_to, hood_z_to),
                     r=0.013, M_parent=M_g)

    # 5. Twin Ribbed Circular Missile Launch Tubes + Recessed Bore + Seated TOW-2B Warheads + Rear Exhaust Cones
    for ti, tx in enumerate([-0.125, 0.125]):
        # Front protruding hollow ribbed circular launch tube (z = -0.70..-0.855, 15mm seat into PodFrontFrame!)
        kb.cyl(f"LaunchTube_{ti}", 0.098, 0.098, 0.155, 20, "dark", "plain_metal",
               (tx, 0.0, -0.778), (-90, 0, 0), 0.004, hollow_r=0.082, M_parent=M_g)
        # Dual machined circular stiffening ribs around each launch tube mouth
        for ri, rz in enumerate([-0.756, -0.812]):
            kb.cyl(f"TubeRib_{ti}_{ri}", 0.106, 0.106, 0.022, 20, "gunmetal", "gear_collar",
                   (tx, 0.0, rz), (-90, 0, 0), 0.003, hollow_r=0.092, M_parent=M_g, u_rep=2.0)
        # Pitch-black recessed launch tube bore interior seated firmly against PodFrontFrame
        kb.cyl(f"TubeBore_{ti}", 0.081, 0.081, 0.048, 16, "bore", "plain_metal",
               (tx, 0.0, -0.728), (-90, 0, 0), 0.002, M_parent=M_g)

        # Seated TOW-2B Top-Attack Warhead Nose + Dual-EFP Brass Band + Copper Stand-Off Probe Rod (0 floating!)
        # Missile body base seats 20mm solidly into TubeBore!
        kb.cyl(f"MissileBase_{ti}", 0.062, 0.062, 0.082, 16, "armor_dark", "armor_panel",
               (tx, 0.0, -0.770), (-90, 0, 0), 0.003, M_parent=M_g)
        kb.cyl(f"MissileBand_{ti}", 0.070, 0.070, 0.018, 16, "brass", "gear_collar",
               (tx, 0.0, -0.785), (-90, 0, 0), 0.002, M_parent=M_g)
        # Tapered ogive/conical warhead nose (local +Y = Godot -Z forward!)
        kb.lathe(f"MissileNose_{ti}", [
            (0.0, 0.0), (0.062, 0.0), (0.056, 0.028), (0.040, 0.054), (0.022, 0.072), (0.0, 0.074)
        ], 16, "armor_sub", "plain_metal", (tx, 0.0, -0.805), (-90, 0, 0), M_parent=M_g)
        # Top-attack stand-off probe rod seated cleanly into warhead nose tip (reaches exact z = -0.922!)
        kb.cyl(f"MissileProbe_{ti}", 0.008, 0.014, 0.070, 10, "copper", "plain_metal",
               (tx, 0.0, -0.888), (-90, 0, 0), 0.002, M_parent=M_g)

        # Rear Flared Blast Exhaust Cone + Recessed Exhaust Bore + Protective Cross-Bar
        kb.cyl(f"ExhaustCone_{ti}", 0.112, 0.096, 0.165, 20, "gunmetal", "gear_collar",
               (tx, 0.0, 0.592), (90, 0, 0), 0.004, hollow_r=0.078, M_parent=M_g, u_rep=2.0)
        kb.cyl(f"ExhaustBore_{ti}", 0.078, 0.078, 0.042, 16, "bore", "plain_metal",
               (tx, 0.0, 0.532), (90, 0, 0), 0.002, M_parent=M_g)
        kb.cyl(f"ExhaustRing_{ti}", 0.118, 0.118, 0.022, 20, "dark", "bolt_flange",
               (tx, 0.0, 0.658), (90, 0, 0), 0.003, hollow_r=0.102, M_parent=M_g, u_rep=2.0)

    # 6. Outboard TAS-4 Thermal Sight Turret Box with Obsidian Glass Optical Window
    kb.box("TASMountBridge", (0.056, 0.19, 0.38), "dark", "bolt_flange",
           (0.285, 0.02, -0.20), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.box("TASTurretBox", (0.175, 0.25, 0.50), "armor_sub", "armor_pocket",
           (0.382, 0.02, -0.20), (0, 0, 0), 0.012, 1, M_parent=M_g)
    kb.box("TASTopHood", (0.184, 0.024, 0.12), "gunmetal", "plain_metal",
           (0.382, 0.148, -0.455), (8, 0, 0), 0.004, 1, M_parent=M_g)
    kb.grab_rail("TASGuardRail", 0.14, 0.028, (0.382, 0.145, -0.14), (90, 0, 0), 0.008, M_parent=M_g)
    # Side cooling louver bay on outboard TAS-4 wall (facing +X -> rot=(0,-90,0))
    kb.louver_bay("TASVentBay", 0.22, 0.11, 0.030, (0.476, 0.02, -0.16), (0, -90, 0),
                  blades=4, mesh_style=True, M_parent=M_g)
    # Recessed dark front optical housing + Dual Obsidian Glass Windows (Main Thermal + Tracker)
    kb.box("TASOpticFrame", (0.145, 0.20, 0.034), "dark", "frame_cnc",
           (0.382, 0.02, -0.455), (0, 0, 0), 0.004, 1, M_parent=M_g)
    # Upper wide obsidian thermal optical window
    kb.box("TASThermalGlass", (0.112, 0.072, 0.016), "glass", "plain_metal",
           (0.382, 0.062, -0.472), (0, 0, 0), 0.002, 1, M_parent=M_g)
    # Lower circular IR tracker bezel + obsidian lens + amber tracker diode
    kb.cyl("TASTrackerBezel", 0.036, 0.038, 0.026, 16, "gunmetal", "plain_metal",
           (0.382, -0.034, -0.474), (-90, 0, 0), 0.002, hollow_r=0.027, M_parent=M_g)
    kb.cyl("TASTrackerGlass", 0.026, 0.026, 0.012, 16, "glass", "plain_metal",
           (0.382, -0.034, -0.470), (-90, 0, 0), 0.002, M_parent=M_g)
    kb.cyl("TASTrackerPip", 0.008, 0.008, 0.010, 10, "emit_amber", "plain_metal",
           (0.382, -0.034, -0.476), (-90, 0, 0), 0.001, M_parent=M_g)

    # Exact MUZZLE marker aligned with twin warhead probe launch tips
    kb.add_marker("MUZZLE", (cx, cy, -0.92))
