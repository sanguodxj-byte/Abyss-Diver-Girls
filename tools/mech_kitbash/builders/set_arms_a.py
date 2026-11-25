"""
Mech Arm Weapon Pack A (Canonical Right Arm side=+1.0) — Zero-Clip Rich Mechanical Standard (v1.5).
Modules:
  1. arm_shotgun : SG-7 Heavy Breacher Twin-Barrel Shotgun        (MUZZLE z = -1.62)
  2. arm_ac30    : AC-30 30mm Bushmaster Chain-Drive Autocannon   (MUZZLE z = -2.70)
  3. arm_cannon  : CN-105 105mm Tank-Class Arm Cannon             (MUZZLE z = -3.30)
  4. arm_flamer  : FT-20 Twin-Tank Pressurized Napalm Flamer      (MUZZLE z = -1.45)
  5. arm_sniper  : M99 Long-Range Anti-Materiel Sniper Rifle      (MUZZLE z = -3.08)

Strict cross-module clearance:
  - HP-A1 mating flange starts strictly at x >= 0.00 (min_x >= -0.004, ZERO protrusion into -X torso).
  - All bulk armor/receiver/shield/drum/tank geometry sits strictly outboard at x >= +0.05.
  - Smooth plain_metal hollow gun muzzles via kb.barrel_bore(..., rot_deg=(-90, 0, 0)).
  - Obsidian glass optics, proud trim details, zero Z-fighting, zero buried details, zero floating parts.
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


def _build_pauldron(kb: KitbashScene, pos, rot_deg, main_trap, main_thick,
                    sub_trap, sub_thick, trim_slot="hazard", trim_band="hazard",
                    trim_h=0.12, trim_z=0.44, grab_w=0.20, grab_d=0.032, bolt_zs=(-0.16, 0.0, 0.16)):
    """Reusable multi-layer spaced chamfered shoulder pauldron strictly clearing core & receiver."""
    M_sh = g2b_mat(pos, rot_deg)
    kb.plate("PauldronMain", trap_2d(*main_trap), main_thick, "armor", "armor_panel",
             (0, 0, 0), (0, 90, 0), min(0.016, main_thick * 0.03), 1, M_parent=M_sh)
    # Seat sub-armor 5mm into PauldronMain outboard face (+main_thick*0.5)
    sub_cx = main_thick * 0.5 + sub_thick * 0.5 - 0.005
    kb.plate("PauldronSub", trap_2d(*sub_trap), sub_thick, "armor_sub", "armor_ribs",
             (sub_cx, -0.012, 0), (0, 90, 0), min(0.010, sub_thick * 0.14), 1, M_parent=M_sh)
    # Proud exterior hazard/accent stripe seated 2mm into PauldronSub outer face (ZERO burial, ZERO z-fight!)
    sub_outer = sub_cx + sub_thick * 0.5
    sub_h = sub_trap[2]
    trim_t = 0.014
    trim_h_eff = min(trim_h, sub_h * 0.48)
    kb.box("PauldronTrim", (trim_t, trim_h_eff, trim_z), trim_slot, trim_band,
           (sub_outer + trim_t * 0.5 - 0.002, -0.024, 0), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    # Top maintenance grab rail pointing strictly UP (+Y via rot_deg=(90,0,0)), seated 2mm into PauldronMain top
    main_h = main_trap[2]
    kb.grab_rail("PauldronGrab", grab_w, grab_d, (0.0, main_h * 0.5 - 0.002, 0.0), (90, 0, 0), 0.009, M_parent=M_sh)
    # Outboard armor retaining hex bolts squarely embedded into PauldronSub upper bevel face (ZERO floating!)
    bolt_y = -0.012 + sub_h * 0.28
    max_bz = sub_trap[1] * 0.36
    for bi, bz in enumerate(bolt_zs):
        bz_clamped = max(-max_bz, min(max_bz, bz))
        kb.cyl(f"PauldronBolt_{bi}", 0.012, 0.014, 0.018, 6, "chrome", "plain_metal",
               (sub_outer - 0.002, bolt_y, bz_clamped), (0, 0, 90), 0.002, M_parent=M_sh)


# ==============================================================================
# 1. arm_shotgun : SG-7 Heavy Breacher Twin-Barrel Shotgun (MUZZLE z = -1.62)
# ==============================================================================
def build_arm_shotgun(kb: KitbashScene):
    # 1. Standardized HP-A1 Shoulder Adapter (min_x = +0.010 -> 0mm clash with any core)
    kb.a1_shoulder_mount("A1Std", heavy=False)

    # 2. Spaced Chamfered Tactical Shoulder Pauldron (strictly outboard x >= 0.17)
    _build_pauldron(
        kb,
        pos=(0.40, 0.42, 0.02),
        rot_deg=(0, 0, -10.0),
        main_trap=(0.74, 0.50, 0.22, 0.06),
        main_thick=0.44,
        sub_trap=(0.56, 0.36, 0.145, 0.04),
        sub_thick=0.068,
        trim_slot="hazard",
        trim_band="hazard",
        trim_h=0.115,
        trim_z=0.42,
        grab_w=0.20,
        grab_d=0.032,
        bolt_zs=(-0.17, 0.0, 0.17),
    )

    # 3. Heavy Armored Breech & CNC-Milled Receiver (centered at x = 0.36, strictly outboard x >= 0.08)
    cx = 0.36
    M_arm = g2b_mat((cx, 0.0, 0.0), (0, 0, 0))

    # Primary CNC receiver forward of HP-A1 yoke (z in [-0.85, -0.15]; clean 2cm seat into yoke front at z=-0.17)
    kb.box("ReceiverCore", (0.38, 0.38, 0.70), "dark", "frame_cnc",
           (0, 0.0, -0.50), (0, 0, 0), 0.014, 1, M_parent=M_arm, tile_u=2.0)
    # Rear recoil counterbalance cap cleanly mated to back of yoke (z = +0.17)
    kb.box("BreechRearCap", (0.28, 0.24, 0.14), "gunmetal", "bolt_flange",
           (0.01, 0.0, 0.23), (0, 0, 0), 0.012, 1, M_parent=M_arm)
    kb.box("BreechRearPad", (0.22, 0.19, 0.042), "rubber", "dust_boot",
           (0.01, 0.0, 0.312), (0, 0, 0), 0.006, 1, M_parent=M_arm)

    # Bolted left & right receiver armor cheeks (inner face overlaps ReceiverCore by 4mm -> zero Z-fight!)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"RecCheek_{sxi}", crect_2d(0.64, 0.33, (0.08, 0.04, 0.05, 0.08)), 0.052, "armor", "armor_panel",
                 (sx * 0.212, 0.005, -0.50), (0, 90, 0), 0.009, 1, M_parent=M_arm)
        # Corner fasteners on cheeks
        for bi, (by, bz) in enumerate([(0.11, -0.26), (0.11, -0.74), (-0.11, -0.26), (-0.11, -0.74)]):
            kb.cyl(f"RecCheekBolt_{sxi}_{bi}", 0.009, 0.011, 0.014, 6, "chrome", "plain_metal",
                   (sx * 0.241, by, bz), (0, 0, 90), 0.002, M_parent=M_arm)

    # Top armored receiver hood + Picatinny sight rail + ghost-ring iron sight + proud accent stripe
    kb.box("RecTopHood", (0.34, 0.056, 0.62), "armor_sub", "armor_hatch",
           (0, 0.210, -0.50), (0, 0, 0), 0.010, 1, M_parent=M_arm)
    kb.box("RecTopRail", (0.13, 0.032, 0.54), "gunmetal", "bolt_flange",
           (0, 0.250, -0.52), (0, 0, 0), 0.004, 1, M_parent=M_arm, tile_u=2.5)
    kb.box("RearSightBase", (0.12, 0.042, 0.055), "dark", "frame_cnc",
           (0, 0.282, -0.28), (0, 0, 0), 0.004, 1, M_parent=M_arm)
    kb.cyl("RearSightRing", 0.028, 0.028, 0.032, 14, "gunmetal", "plain_metal",
           (0, 0.312, -0.28), (90, 0, 0), 0.003, hollow_r=0.018, M_parent=M_arm)
    kb.box("RecTopAccent", (0.012, 0.036, 0.44), "accent", "plain_metal",
           (0.242, 0.115, -0.50), (0, 0, 0), 0.002, 1, M_parent=M_arm)

    # Outboard ejection port frame + recessed black port opening (x_outer of RecCheek_1 = +0.238)
    kb.box("EjectFrame", (0.022, 0.098, 0.25), "gunmetal", "bolt_flange",
           (0.246, 0.068, -0.45), (0, 0, 0), 0.003, 1, M_parent=M_arm)
    kb.box("EjectBore", (0.012, 0.062, 0.205), "bore", "plain_metal",
           (0.256, 0.068, -0.45), (0, 0, 0), 0.002, 1, M_parent=M_arm)

    # Outboard 4-shell spare breacher saddle rack (crimson/amber hull + brass rims)
    kb.box("ShellRackBase", (0.028, 0.064, 0.35), "dark", "bolt_flange",
           (0.248, -0.058, -0.50), (0, 0, 0), 0.004, 1, M_parent=M_arm)
    for si in range(4):
        sz = -0.62 + si * 0.080
        kb.cyl(f"ShellClip_{si}", 0.029, 0.029, 0.028, 12, "gunmetal", "gear_collar",
               (0.274, -0.058, sz), (0, 0, 0), 0.002, M_parent=M_arm)
        kb.cyl(f"ShellHull_{si}", 0.025, 0.025, 0.115, 12, "accent", "plain_metal",
               (0.274, -0.042, sz), (0, 0, 0), 0.003, M_parent=M_arm)
        kb.cyl(f"ShellBrass_{si}", 0.028, 0.028, 0.036, 12, "brass", "plain_metal",
               (0.274, -0.112, sz), (0, 0, 0), 0.002, M_parent=M_arm)

    # Inboard cooling louver grille (rot=(0,90,0) faces -X; x_min = 0.36 - 0.266 = 0.094 >= 0.05!)
    kb.louver_bay("RecInboardVent", 0.34, 0.14, 0.032, (-0.249, -0.015, -0.50), (0, 90, 0),
                  blades=5, mesh_style=False, M_parent=M_arm)

    # Braided hydraulic buffer line looping from yoke into lower receiver
    kb.tube_path("RecHydLine", [(0.16, -0.12, 0.08), (0.24, -0.20, -0.06), (0.18, -0.16, -0.26)],
                 0.015, 8, "gunmetal", "braid_hose", M_parent=M_arm)

    # 4. Chunky Under-Slung High-Capacity Box + Twin Saddle-Drum Magazine
    kb.box("MagWell", (0.28, 0.075, 0.36), "dark", "frame_cnc",
           (0, -0.215, -0.46), (0, 0, 0), 0.008, 1, M_parent=M_arm)
    kb.box("MagBoxBody", (0.32, 0.22, 0.42), "armor_sub", "armor_ribs",
           (0, -0.355, -0.46), (0, 0, 0), 0.014, 1, M_parent=M_arm)
    kb.box("MagBasePlate", (0.35, 0.042, 0.45), "gunmetal", "bolt_flange",
           (0, -0.478, -0.46), (0, 0, 0), 0.006, 1, M_parent=M_arm)
    # Twin side-mounted drum magazine blisters + brass locking hubs (outboard-safe x >= 0.36 - 0.255 = 0.105!)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.cyl(f"DrumBlister_{sxi}", 0.112, 0.112, 0.105, 18, "armor_dark", "armor_panel",
               (sx * 0.195, -0.355, -0.46), (0, 0, 90), 0.008, M_parent=M_arm, u_rep=2.0)
        kb.cyl(f"DrumBlisterRim_{sxi}", 0.120, 0.120, 0.022, 18, "dark", "bolt_flange",
               (sx * 0.240, -0.355, -0.46), (0, 0, 90), 0.003, M_parent=M_arm)
        kb.cyl(f"DrumBlisterHub_{sxi}", 0.046, 0.046, 0.026, 12, "brass", "gear_collar",
               (sx * 0.256, -0.355, -0.46), (0, 0, 90), 0.003, M_parent=M_arm)

    # 5. Twin Side-by-Side 40mm Large-Bore Barrels + Perforated Vent-Mesh Shroud + Hydraulic Recoil Cylinder
    kb.box("BarrelTrunnion", (0.42, 0.28, 0.15), "gunmetal", "bolt_flange",
           (0, 0.02, -0.90), (0, 0, 0), 0.012, 1, M_parent=M_arm)
    # Front heavy barrel clamp + twin chrome fasteners
    kb.box("BarrelClamp", (0.42, 0.22, 0.095), "dark", "bolt_flange",
           (0, 0.02, -1.39), (0, 0, 0), 0.010, 1, M_parent=M_arm)
    for bi, bx in enumerate([-0.16, 0.16]):
        kb.cyl(f"ClampBoltTop_{bi}", 0.010, 0.012, 0.016, 6, "chrome", "plain_metal",
               (bx, 0.136, -1.39), (0, 0, 0), 0.002, M_parent=M_arm)
        kb.cyl(f"ClampBoltSide_{bi}", 0.010, 0.012, 0.016, 6, "chrome", "plain_metal",
               (math.copysign(0.216, bx), 0.02, -1.39), (0, 0, 90), 0.002, M_parent=M_arm)

    # Upper sloped ventilated heat-shield bridge between trunnion and clamp
    kb.plate("TopHeatShield", trap_2d(0.46, 0.34, 0.105, 0.025), 0.38, "armor", "armor_panel",
             (0, 0.162, -1.16), (0, 90, 0), 0.009, 1, M_parent=M_arm)
    kb.box("TopHeatMesh", (0.24, 0.018, 0.34), "gunmetal", "vent_mesh",
           (0, 0.220, -1.16), (0, 0, 0), 0.003, 1, M_parent=M_arm)
    kb.box("FrontSightPost", (0.044, 0.056, 0.046), "dark", "plain_metal",
           (0, 0.154, -1.39), (0, 0, 0), 0.004, 1, M_parent=M_arm)

    # Twin 40mm barrels + perforated cylindrical vent_mesh heat sleeves + breacher crowns + smooth hollow bores
    # Barrel ends at z = -1.571; barrel_bore at z = -1.571 with depth = 0.070, rot=(-90,0,0) -> tip at z = -1.620!
    for bi, ox in enumerate([-0.104, 0.104]):
        kb.cyl(f"BarrelTube_{bi}", 0.072, 0.074, 0.68, 16, "dark", "plain_metal",
               (ox, 0.04, -1.231), (90, 0, 0), 0.003, M_parent=M_arm)
        kb.cyl(f"BarrelShroud_{bi}", 0.094, 0.094, 0.44, 18, "gunmetal", "vent_mesh",
               (ox, 0.04, -1.16), (90, 0, 0), 0.004, hollow_r=0.078, M_parent=M_arm, u_rep=2.0)
        # Serrated breacher choke collar just behind crown
        kb.cyl(f"BarrelChoke_{bi}", 0.084, 0.084, 0.068, 16, "gunmetal", "gear_collar",
               (ox, 0.04, -1.525), (90, 0, 0), 0.004, M_parent=M_arm, u_rep=2.0)
        kb.barrel_bore(f"Bore_{bi}", 0.080, 0.058, (ox, 0.04, -1.571), depth=0.070,
                       rot_deg=(-90, 0, 0), segs=16, M_parent=M_arm)

    # Under-barrel hydraulic recoil damper cylinder + brass oil seal + chrome piston rod
    kb.cyl("RecoilHyd_cyl", 0.054, 0.054, 0.26, 14, "dark", "gear_collar",
           (0, -0.095, -1.03), (90, 0, 0), 0.004, M_parent=M_arm)
    kb.cyl("RecoilHyd_seal", 0.060, 0.060, 0.030, 14, "brass", "bolt_flange",
           (0, -0.095, -1.165), (90, 0, 0), 0.003, M_parent=M_arm)
    kb.cyl("RecoilHyd_rod", 0.036, 0.036, 0.36, 12, "chrome", "plain_metal",
           (0, -0.095, -1.22), (90, 0, 0), 0.002, M_parent=M_arm)

    # Exact MUZZLE marker aligned with twin-barrel midpoint tip
    kb.add_marker("MUZZLE", (cx, 0.04, -1.62))


# ==============================================================================
# 2. arm_ac30 : AC-30 30mm Bushmaster Chain-Drive Autocannon (MUZZLE z = -2.70)
# ==============================================================================
def build_arm_ac30(kb: KitbashScene):
    # 1. Standardized HP-A1 Shoulder Adapter
    kb.a1_shoulder_mount("A1Std", heavy=False)

    # 2. Sloped Armored Shoulder Pauldron (strictly outboard x >= 0.19)
    _build_pauldron(
        kb,
        pos=(0.44, 0.43, 0.03),
        rot_deg=(0, 0, -12.0),
        main_trap=(0.76, 0.48, 0.23, 0.06),
        main_thick=0.48,
        sub_trap=(0.58, 0.36, 0.155, 0.04),
        sub_thick=0.072,
        trim_slot="accent",
        trim_band="plain_metal",
        trim_h=0.125,
        trim_z=0.44,
        grab_w=0.22,
        grab_d=0.034,
        bolt_zs=(-0.18, 0.0, 0.18),
    )

    # 3. Bushmaster Chain-Drive Receiver + Side Electric Motor (centered at x = 0.64, y = -0.02)
    cx, cy = 0.64, -0.02
    M_g = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # CNC chain-drive receiver housing (root x in [0.46, 0.82], cleanly anchored onto A1Std yoke!)
    kb.box("ReceiverCore", (0.36, 0.38, 0.84), "dark", "frame_cnc",
           (0, 0.0, -0.10), (0, 0, 0), 0.016, 1, M_parent=M_g, tile_u=2.0)
    # Top chain-drive cam track cover + top grab rail + bolt fasteners
    kb.box("ChainDriveCover", (0.28, 0.095, 0.58), "gunmetal", "armor_ribs",
           (0, 0.232, -0.08), (0, 0, 0), 0.010, 1, M_parent=M_g)
    kb.grab_rail("ChainTopGrab", 0.22, 0.034, (0, 0.278, -0.18), (90, 0, 0), 0.009, M_parent=M_g)
    for bi, (bx, bz) in enumerate([(-0.11, -0.30), (0.11, -0.30), (-0.11, 0.14), (0.11, 0.14)]):
        kb.cyl(f"ChainBolt_{bi}", 0.009, 0.011, 0.014, 6, "chrome", "plain_metal",
               (bx, 0.284, bz), (0, 0, 0), 0.002, M_parent=M_g)
    # Rear breech service cap
    kb.box("RecRearCap", (0.28, 0.28, 0.075), "gunmetal", "bolt_flange",
           (0, 0.0, 0.345), (0, 0, 0), 0.008, 1, M_parent=M_g)

    # Bolted outboard & inboard armored side plates (inboard y in [-0.16, +0.16] clears A1Std_ykf cleanly!)
    kb.plate("RecSidePlate_R", crect_2d(0.76, 0.32, (0.04, 0.10, 0.06, 0.04)), 0.040, "armor_sub", "armor_hatch",
             (0.196, -0.005, -0.10), (0, 90, 0), 0.008, 1, M_parent=M_g)
    kb.plate("RecSidePlate_L", crect_2d(0.32, 0.30, (0.04, 0.06, 0.04, 0.04)), 0.038, "armor_sub", "armor_panel",
             (-0.195, -0.005, -0.34), (0, 90, 0), 0.008, 1, M_parent=M_g)

    # Outboard recessed cooling louver bay (rot=(0,-90,0) faces +X outboard!)
    kb.louver_bay("RecCoolingBay", 0.32, 0.135, 0.032, (0.226, -0.045, 0.02), (0, -90, 0),
                  blades=5, mesh_style=False, M_parent=M_g)

    # Side-mounted Bushmaster electric chain-drive motor + brass end cap + braided power conduit
    kb.box("DriveMotorMount", (0.09, 0.12, 0.18), "gunmetal", "bolt_flange",
           (0.215, 0.125, 0.12), (0, 0, 0), 0.007, 1, M_parent=M_g)
    kb.cyl("DriveMotorBody", 0.080, 0.080, 0.20, 18, "dark", "gear_collar",
           (0.295, 0.135, 0.12), (0, 0, 90), 0.006, M_parent=M_g, u_rep=2.0)
    kb.cyl("DriveMotorRing", 0.086, 0.086, 0.034, 18, "brass", "bolt_flange",
           (0.402, 0.135, 0.12), (0, 0, 90), 0.004, M_parent=M_g)
    kb.cyl("DriveMotorCap", 0.056, 0.062, 0.028, 14, "chrome", "plain_metal",
           (0.428, 0.135, 0.12), (0, 0, 90), 0.003, M_parent=M_g)
    kb.tube_path("DrivePowerCable",
                 [(0.31, 0.065, 0.12), (0.31, -0.08, 0.24), (0.16, -0.10, 0.24)],
                 0.016, 8, "gunmetal", "braid_hose", M_parent=M_g)

    # 4. Sloped Armored Gun Mantlet Shield (root x in [0.37, 0.91] -> 100% clear of core!)
    M_man = M_g @ g2b_mat((0, 0.0, -0.56), (10, 0, 0))
    kb.plate("GunMantlet", crect_2d(0.54, 0.50, (0.10, 0.10, 0.14, 0.14)), 0.11, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_man)
    kb.plate("MantletSubArmor", crect_2d(0.42, 0.34, (0.06, 0.06, 0.08, 0.08)), 0.038, "armor_sub", "armor_pocket",
             (0, -0.01, -0.068), (0, 0, 0), 0.008, 1, M_parent=M_man)
    kb.box("MantletAccent", (0.40, 0.042, 0.014), "accent", "plain_metal",
           (0, 0.190, -0.060), (0, 0, 0), 0.002, 1, M_parent=M_man)
    kb.box("MantletHazard", (0.14, 0.032, 0.014), "hazard", "hazard",
           (0.13, -0.195, -0.060), (0, 0, 0), 0.002, 1, M_parent=M_man)
    for bi, (bx, by) in enumerate([(-0.18, 0.13), (0.18, 0.13), (-0.16, -0.14), (0.16, -0.14)]):
        kb.cyl(f"MantletBolt_{bi}", 0.011, 0.013, 0.016, 6, "chrome", "plain_metal",
               (bx, by, -0.088), (90, 0, 0), 0.002, M_parent=M_man)

    # 5. Under-Slung Dual-Feed Armored Ammo Hopper & Twin Brass Link Chutes
    kb.box("AmmoHopperNeck", (0.26, 0.08, 0.38), "dark", "frame_cnc",
           (0, -0.22, 0.04), (0, 0, 0), 0.008, 1, M_parent=M_g)
    kb.box("AmmoHopperBody", (0.34, 0.26, 0.52), "armor_sub", "armor_hatch",
           (0, -0.37, 0.04), (0, 0, 0), 0.014, 1, M_parent=M_g)
    kb.box("AmmoHopperFloor", (0.36, 0.040, 0.54), "gunmetal", "bolt_flange",
           (0, -0.505, 0.04), (0, 0, 0), 0.006, 1, M_parent=M_g)
    # Twin articulated brass ammunition feed chutes curving up into dual-feed breech
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.tube_path(
            f"FeedChute_{sxi}",
            [(sx * 0.15, -0.32, -0.16), (sx * 0.24, -0.20, -0.26), (sx * 0.18, -0.04, -0.32)],
            0.030, 8, "brass", "gear_collar", add_clamps=False, M_parent=M_g
        )

    # 6. Fluted Recoil Sleeve + Bushmaster Anti-Whip Truss + Long 30mm Barrel + Dual-Baffle Brake + Hollow Bore
    kb.cyl("RecoilSleeve", 0.106, 0.106, 0.40, 20, "dark", "gear_collar",
           (0, 0.0, -0.80), (90, 0, 0), 0.006, M_parent=M_g, u_rep=2.0)
    for ri, rz in enumerate([-0.655, -0.955]):
        kb.cyl(f"SleeveCollar_{ri}", 0.118, 0.118, 0.036, 20, "gunmetal", "bolt_flange",
               (0, 0.0, rz), (90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)
    # Twin compact recoil dampers alongside recoil sleeve
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.cyl(f"SleeveHyd{sxi}_cyl", 0.032, 0.032, 0.22, 12, "gunmetal", "plain_metal",
               (sx * 0.125, -0.055, -0.71), (90, 0, 0), 0.003, M_parent=M_g)
        kb.cyl(f"SleeveHyd{sxi}_seal", 0.036, 0.036, 0.020, 12, "brass", "gear_collar",
               (sx * 0.125, -0.055, -0.825), (90, 0, 0), 0.002, M_parent=M_g)
        kb.cyl(f"SleeveHyd{sxi}_rod", 0.020, 0.020, 0.16, 10, "chrome", "plain_metal",
               (sx * 0.125, -0.055, -0.90), (90, 0, 0), 0.002, M_parent=M_g)

    # Stepped fluted rear barrel + long heavy precision 30mm barrel (ends cleanly inside brake nut at z = -2.43)
    kb.cyl("BarrelFluted", 0.070, 0.066, 0.56, 16, "dark", "gear_collar",
           (0, 0.0, -1.25), (90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)
    kb.cyl("BarrelMain", 0.056, 0.054, 0.98, 16, "dark", "plain_metal",
           (0, 0.0, -1.94), (90, 0, 0), 0.003, M_parent=M_g)
    kb.cyl("BarrelMidRing", 0.066, 0.066, 0.042, 16, "gunmetal", "bolt_flange",
           (0, 0.0, -1.66), (90, 0, 0), 0.004, M_parent=M_g)

    # Bushmaster exoskeleton anti-whip dorsal rail & 4 transverse clamp ribs
    kb.box("TrussSpine", (0.115, 0.024, 0.72), "gunmetal", "bolt_flange",
           (0, 0.092, -1.32), (0, 0, 0), 0.004, 1, M_parent=M_g, tile_u=2.5)
    for ti, tz in enumerate([-1.00, -1.22, -1.44, -1.66]):
        kb.box(f"TrussRib_{ti}", (0.135, 0.115, 0.028), "dark", "frame_cnc",
               (0, 0.036, tz), (0, 0, 0), 0.004, 1, M_parent=M_g)

    # Crisp Dual-Baffle Rectangular Muzzle Brake (z in [-2.68, -2.42]) + Hollow Bore (front tip = -2.700!)
    kb.cyl("MuzzleBrake_nut", 0.072, 0.072, 0.050, 16, "gunmetal", "gear_collar",
           (0, 0.0, -2.445), (90, 0, 0), 0.004, M_parent=M_g)
    kb.box("MuzzleBrake_top", (0.176, 0.030, 0.235), "dark", "frame_cnc",
           (0, 0.062, -2.568), (0, 0, 0), 0.004, 1, M_parent=M_g)
    kb.box("MuzzleBrake_bot", (0.176, 0.030, 0.235), "dark", "frame_cnc",
           (0, -0.062, -2.568), (0, 0, 0), 0.004, 1, M_parent=M_g)
    for bi, bz in enumerate([-2.468, -2.568, -2.668]):
        kb.box(f"MuzzleBrake_baf{bi}", (0.188, 0.148, 0.028), "gunmetal", "plain_metal",
               (0, 0.0, bz), (0, 0, 0), 0.004, 1, M_parent=M_g)
    kb.cyl("MuzzleBrake_core", 0.050, 0.050, 0.21, 14, "bore", "plain_metal",
           (0, 0.0, -2.568), (90, 0, 0), 0.002, M_parent=M_g)
    kb.barrel_bore("MuzzleBore", 0.056, 0.038, (0, 0.0, -2.659), depth=0.058,
                   rot_deg=(-90, 0, 0), segs=16, M_parent=M_g)

    # Exact MUZZLE marker aligned with 30mm barrel tip
    kb.add_marker("MUZZLE", (cx, cy, -2.70))


# ==============================================================================
# 3. arm_cannon : CN-105 105mm Tank-Class Arm Cannon (MUZZLE z = -3.30)
# ==============================================================================
def build_arm_cannon(kb: KitbashScene):
    # 1. Heavy Reinforced HP-A1 Double Flange + 4 Triangular Gussets + Heavy Mast
    kb.a1_shoulder_mount("A1Heavy", heavy=True)

    # 2. Massive Chamfered Heavy Shoulder Pauldron (identical safe envelope to arm_gatling: x >= 0.21)
    _build_pauldron(
        kb,
        pos=(0.52, 0.50, 0.04),
        rot_deg=(0, 0, -10.0),
        main_trap=(0.92, 0.64, 0.28, 0.07),
        main_thick=0.60,
        sub_trap=(0.74, 0.48, 0.19, 0.05),
        sub_thick=0.092,
        trim_slot="hazard",
        trim_band="hazard",
        trim_h=0.18,
        trim_z=0.58,
        grab_w=0.26,
        grab_d=0.040,
        bolt_zs=(-0.22, 0.0, 0.22),
    )

    # 3. Heavy 105mm Breech Block + Recoil Recuperators + Sloped Composite Gun Shield (x = 0.74, y = -0.04)
    cx, cy = 0.74, -0.04
    M_g = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Main CNC breech block (root x in [0.46, 1.02] -> cleanly bolts onto A1Heavy yoke!)
    kb.box("BreechCore", (0.56, 0.64, 1.04), "dark", "frame_cnc",
           (0, 0.0, 0.02), (0, 0, 0), 0.020, 1, M_parent=M_g, tile_u=2.0)
    # Rear sliding wedge breech housing + chrome operating bar + rear access hatch
    kb.box("BreechWedge", (0.44, 0.44, 0.24), "gunmetal", "bolt_flange",
           (0, 0.0, 0.64), (0, 0, 0), 0.014, 1, M_parent=M_g)
    kb.box("BreechRearHatch", (0.30, 0.22, 0.034), "armor_sub", "armor_hatch",
           (0, -0.06, 0.768), (0, 0, 0), 0.006, 1, M_parent=M_g)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.box(f"BreechBarBrk_{sxi}", (0.044, 0.055, 0.085), "dark", "plain_metal",
               (sx * 0.17, 0.13, 0.78), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.cyl("BreechChromeBar", 0.032, 0.032, 0.50, 12, "chrome", "plain_metal",
           (0, 0.13, 0.82), (0, 0, 90), 0.004, M_parent=M_g)

    # Outboard full spaced armor cheek + inboard fore/aft cheeks (leaving trunnion bay clear of A1Heavy_ykf!)
    kb.plate("BreechCheek_R", crect_2d(0.96, 0.56, (0.10, 0.08, 0.08, 0.10)), 0.062, "armor", "armor_panel",
             (0.304, 0.0, 0.02), (0, 90, 0), 0.010, 1, M_parent=M_g)
    kb.plate("BreechCheek_LF", crect_2d(0.30, 0.54, (0.06, 0.04, 0.04, 0.06)), 0.056, "armor", "armor_panel",
             (-0.302, 0.0, -0.34), (0, 90, 0), 0.010, 1, M_parent=M_g)
    kb.plate("BreechCheek_LR", crect_2d(0.30, 0.54, (0.04, 0.06, 0.06, 0.04)), 0.056, "armor", "armor_panel",
             (-0.302, 0.0, 0.37), (0, 90, 0), 0.010, 1, M_parent=M_g)
    # Inboard cooling louver bay on rear cheek (rot=(0,90,0) faces -X; root x_min = 0.74 - 0.354 = 0.386!)
    kb.louver_bay("BreechVent_L", 0.19, 0.24, 0.032, (-0.338, 0.0, 0.37), (0, 90, 0),
                  blades=5, mesh_style=False, M_parent=M_g)

    # Twin Upper Hydraulic Recoil Recuperator Cylinders + Twin Lower Buffer Cylinders
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.box(f"RecupBrk_{sxi}", (0.14, 0.12, 0.12), "gunmetal", "bolt_flange",
               (sx * 0.175, 0.32, 0.10), (0, 0, 0), 0.008, 1, M_parent=M_g)
        kb.cyl(f"RecupHyd{sxi}_cyl", 0.088, 0.088, 0.72, 16, "dark", "gear_collar",
               (sx * 0.175, 0.395, -0.10), (90, 0, 0), 0.006, M_parent=M_g, u_rep=2.0)
        kb.cyl(f"RecupHyd{sxi}_seal", 0.098, 0.098, 0.042, 16, "brass", "bolt_flange",
               (sx * 0.175, 0.395, -0.46), (90, 0, 0), 0.004, M_parent=M_g)
        kb.cyl(f"RecupHyd{sxi}_rod", 0.054, 0.054, 0.20, 12, "chrome", "plain_metal",
               (sx * 0.175, 0.395, -0.54), (90, 0, 0), 0.003, M_parent=M_g)
        # Lower auxiliary recoil dampers
        kb.cyl(f"LowerHyd{sxi}_cyl", 0.056, 0.056, 0.62, 14, "gunmetal", "plain_metal",
               (sx * 0.165, -0.355, -0.22), (90, 0, 0), 0.004, M_parent=M_g)
        kb.cyl(f"LowerHyd{sxi}_seal", 0.064, 0.064, 0.032, 14, "brass", "gear_collar",
               (sx * 0.165, -0.355, -0.53), (90, 0, 0), 0.003, M_parent=M_g)
        kb.cyl(f"LowerHyd{sxi}_rod", 0.034, 0.034, 0.22, 10, "chrome", "plain_metal",
               (sx * 0.165, -0.355, -0.62), (90, 0, 0), 0.002, M_parent=M_g)

    # Top Laser Rangefinder / Coaxial Fire-Control Sight Box (obsidian glass optics!)
    kb.box("RangefinderPed", (0.20, 0.14, 0.24), "dark", "frame_cnc",
           (0, 0.36, -0.40), (0, 0, 0), 0.008, 1, M_parent=M_g)
    kb.box("RangefinderBox", (0.28, 0.155, 0.28), "armor_dark", "armor_pocket",
           (0, 0.495, -0.40), (0, 0, 0), 0.012, 1, M_parent=M_g)
    kb.box("RangefinderHood", (0.295, 0.022, 0.11), "gunmetal", "plain_metal",
           (0, 0.570, -0.53), (8, 0, 0), 0.004, 1, M_parent=M_g)
    for onm, ox, orad, opip in [("lrf", -0.058, 0.036, "emit_cyan"), ("day", 0.062, 0.025, "emit_amber")]:
        kb.cyl(f"OpticBezel_{onm}", orad + 0.008, orad + 0.010, 0.024, 16, "gunmetal", "plain_metal",
               (ox, 0.495, -0.546), (90, 0, 0), 0.003, hollow_r=orad * 0.84, M_parent=M_g)
        kb.cyl(f"OpticGlass_{onm}", orad * 0.82, orad * 0.82, 0.014, 14, "glass", "plain_metal",
               (ox, 0.495, -0.544), (90, 0, 0), 0.002, M_parent=M_g)
        kb.cyl(f"OpticPip_{onm}", orad * 0.22, orad * 0.22, 0.015, 10, opip, "plain_metal",
               (ox, 0.495, -0.546), (90, 0, 0), 0.001, M_parent=M_g)
    kb.tube_path("BreechHydLoop",
                 [(-0.18, 0.39, 0.22), (-0.28, 0.24, 0.34), (-0.22, 0.08, 0.46)],
                 0.018, 8, "gunmetal", "braid_hose", M_parent=M_g)

    # 4. Massive Sloped Composite Gun Shield (root x in [0.30, 1.18] -> 100% clear of all cores!)
    M_shd = M_g @ g2b_mat((0, 0.02, -0.62), (8, 0, 0))
    kb.plate("GunShieldMain", crect_2d(0.88, 0.84, (0.16, 0.16, 0.20, 0.20)), 0.22, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.022, 1, M_parent=M_shd)
    kb.plate("GunShieldSub", crect_2d(0.72, 0.62, (0.12, 0.12, 0.14, 0.14)), 0.056, "armor_sub", "armor_ribs",
             (0, -0.01, -0.132), (0, 0, 0), 0.010, 1, M_parent=M_shd)
    kb.box("GunShieldAccent", (0.58, 0.052, 0.016), "accent", "plain_metal",
           (0, 0.345, -0.116), (0, 0, 0), 0.002, 1, M_parent=M_shd)
    # Maintenance grab rail seated cleanly on open rear roof of BreechCore (clears twin recuperators!)
    kb.grab_rail("BreechTopGrab", 0.24, 0.036, (0, 0.318, 0.36), (90, 0, 0), 0.010, M_parent=M_g)
    for bi, (bx, by) in enumerate([(-0.30, 0.20), (0.30, 0.20), (-0.30, -0.20), (0.30, -0.20),
                                   (-0.22, 0.32), (0.22, 0.32)]):
        kb.cyl(f"ShieldBolt_{bi}", 0.014, 0.016, 0.020, 6, "chrome", "plain_metal",
               (bx, by, -0.164 if abs(by) < 0.25 else -0.118), (90, 0, 0), 0.002, M_parent=M_shd)

    # 5. Outboard 3-Shell Ready-Round Armored Ammo Rack (+X cheek outer face is x = +0.335)
    kb.box("AmmoRackBack", (0.052, 0.48, 0.72), "dark", "bolt_flange",
           (0.354, -0.03, 0.02), (0, 0, 0), 0.008, 1, M_parent=M_g)
    kb.box("AmmoRackHood", (0.22, 0.044, 0.72), "armor_sub", "armor_ribs",
           (0.450, 0.205, 0.02), (0, 0, 0), 0.008, 1, M_parent=M_g)
    kb.box("AmmoRackFloor", (0.21, 0.036, 0.72), "gunmetal", "bolt_flange",
           (0.445, -0.265, 0.02), (0, 0, 0), 0.006, 1, M_parent=M_g)
    for ci, cz in enumerate([-0.14, 0.24]):
        kb.box(f"AmmoRackStrut_{ci}", (0.18, 0.45, 0.034), "gunmetal", "frame_cnc",
               (0.464, -0.03, cz), (0, 0, 0), 0.005, 1, M_parent=M_g)
    # 3 heavy 105mm brass-cased ready rounds stacked vertically inside rack
    for ri, ry in enumerate([-0.175, -0.030, 0.115]):
        rx = 0.460
        kb.cyl(f"Shell105_case{ri}", 0.052, 0.052, 0.45, 14, "brass", "plain_metal",
               (rx, ry, 0.125), (90, 0, 0), 0.004, M_parent=M_g)
        kb.cyl(f"Shell105_rim{ri}", 0.058, 0.058, 0.024, 14, "brass", "gear_collar",
               (rx, ry, 0.355), (90, 0, 0), 0.002, M_parent=M_g)
        # Warhead cone: rot=(90,0,0) maps r_top -> +Z (rear), r_bot -> -Z (pointed front nose!)
        kb.cyl(f"Shell105_nose{ri}", 0.051, 0.018, 0.22, 14, "armor_dark", "plain_metal",
               (rx, ry, -0.205), (90, 0, 0), 0.004, M_parent=M_g)
        kb.cyl(f"Shell105_band{ri}", 0.054, 0.054, 0.028, 14, "accent", "plain_metal",
               (rx, ry, -0.105), (90, 0, 0), 0.002, M_parent=M_g)

    # 6. Long Heavy 105mm Barrel + Mid-Barrel Bore Evacuator + Dual-Chamber Muzzle Brake + Hollow Bore
    kb.cyl("MantletCollar", 0.210, 0.205, 0.30, 22, "dark", "gear_collar",
           (0, 0.0, -0.85), (90, 0, 0), 0.008, M_parent=M_g, u_rep=2.0)
    kb.cyl("BarrelRoot", 0.148, 0.140, 0.56, 20, "armor_sub", "plain_metal",
           (0, 0.0, -1.24), (90, 0, 0), 0.005, M_parent=M_g)
    # Eccentric Cylindrical Bore Evacuator (Fume Extractor)
    kb.cyl("BoreEvacBody", 0.204, 0.204, 0.48, 22, "armor", "armor_panel",
           (0, 0.016, -1.72), (90, 0, 0), 0.012, M_parent=M_g, u_rep=2.0)
    for ei, ez in enumerate([-1.47, -1.97]):
        kb.cyl(f"BoreEvacRing_{ei}", 0.214, 0.214, 0.048, 22, "dark", "bolt_flange",
               (0, 0.016, ez), (90, 0, 0), 0.005, M_parent=M_g, u_rep=2.0)
    # Long forward thermal-sleeved 105mm barrel (ends cleanly inside brake nut at z = -2.935)
    kb.cyl("BarrelFwd", 0.134, 0.122, 1.00, 20, "armor_sub", "plain_metal",
           (0, 0.0, -2.435), (90, 0, 0), 0.005, M_parent=M_g)
    for si, (sz, sr) in enumerate([(-1.18, 0.152), (-2.26, 0.136), (-2.64, 0.130)]):
        kb.cyl(f"ThermalStrap_{si}", sr, sr, 0.036, 20, "dark", "bolt_flange",
               (0, 0.0, sz), (90, 0, 0), 0.003, M_parent=M_g)
    # Muzzle Reference Sensor (MRS) mast behind muzzle brake
    kb.box("MRS_Mast", (0.042, 0.088, 0.048), "gunmetal", "plain_metal",
           (0, 0.155, -2.84), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.cyl("MRS_Prism", 0.016, 0.016, 0.024, 10, "chrome", "plain_metal",
           (0, 0.195, -2.84), (90, 0, 0), 0.002, M_parent=M_g)

    # Bold Dual-Chamber Tank Muzzle Brake (z in [-3.255, -2.894]) + Hollow 105mm Bore (tip = -3.300!)
    kb.cyl("MuzzleBrake_nut", 0.152, 0.152, 0.072, 20, "dark", "gear_collar",
           (0, 0.0, -2.930), (90, 0, 0), 0.005, M_parent=M_g, u_rep=2.0)
    kb.box("MuzzleBrake_top", (0.34, 0.056, 0.310), "dark", "frame_cnc",
           (0, 0.126, -3.100), (0, 0, 0), 0.009, 1, M_parent=M_g)
    kb.box("MuzzleBrake_bot", (0.34, 0.056, 0.310), "dark", "frame_cnc",
           (0, -0.126, -3.100), (0, 0, 0), 0.009, 1, M_parent=M_g)
    for bi, bz in enumerate([-2.966, -3.100, -3.234]):
        kb.box(f"MuzzleBrake_baf{bi}", (0.36, 0.28, 0.042), "gunmetal", "bolt_flange",
               (0, 0.0, bz), (0, 0, 0), 0.007, 1, M_parent=M_g)
    kb.cyl("MuzzleBrake_core", 0.095, 0.095, 0.250, 18, "bore", "plain_metal",
           (0, 0.0, -3.100), (90, 0, 0), 0.003, M_parent=M_g)
    kb.barrel_bore("MuzzleBore", 0.118, 0.084, (0, 0.0, -3.258), depth=0.060,
                   rot_deg=(-90, 0, 0), segs=20, M_parent=M_g)

    # Exact MUZZLE marker aligned with 105mm cannon tip
    kb.add_marker("MUZZLE", (cx, cy, -3.30))


# ==============================================================================
# 4. arm_flamer : FT-20 Twin-Tank Pressurized Napalm Flamer (MUZZLE z = -1.45)
# ==============================================================================
def build_arm_flamer(kb: KitbashScene):
    # 1. Standardized HP-A1 Shoulder Adapter
    kb.a1_shoulder_mount("A1Std", heavy=False)

    # 2. Chamfered Industrial Shoulder Pauldron with Hazard Trim (strictly outboard x >= 0.18)
    _build_pauldron(
        kb,
        pos=(0.40, 0.42, 0.02),
        rot_deg=(0, 0, -10.0),
        main_trap=(0.72, 0.48, 0.22, 0.06),
        main_thick=0.44,
        sub_trap=(0.54, 0.36, 0.145, 0.04),
        sub_thick=0.068,
        trim_slot="hazard",
        trim_band="hazard",
        trim_h=0.12,
        trim_z=0.42,
        grab_w=0.20,
        grab_d=0.032,
        bolt_zs=(-0.16, 0.0, 0.16),
    )

    # 3. Armored Manifold Frame (centered at x = 0.38, strictly outboard x >= 0.15)
    cx = 0.38
    M_arm = g2b_mat((cx, 0.0, 0.0), (0, 0, 0))

    # CNC fuel-mixing manifold forward of HP-A1 yoke (z in [-0.77, -0.15]; clean 2cm seat on yoke!)
    kb.box("ManifoldCore", (0.32, 0.34, 0.62), "dark", "frame_cnc",
           (0, -0.02, -0.46), (0, 0, 0), 0.014, 1, M_parent=M_arm, tile_u=2.0)
    kb.box("ManifoldRearCap", (0.26, 0.22, 0.14), "gunmetal", "bolt_flange",
           (0.0, -0.02, 0.23), (0, 0, 0), 0.010, 1, M_parent=M_arm)
    # Upper armored manifold splash shroud + grab rail
    kb.box("ManifoldTopCowl", (0.34, 0.11, 0.56), "armor_sub", "armor_hatch",
           (0, 0.185, -0.48), (0, 0, 0), 0.012, 1, M_parent=M_arm)
    kb.grab_rail("ManifoldGrab", 0.20, 0.032, (0, 0.238, -0.46), (90, 0, 0), 0.008, M_parent=M_arm)

    # Inboard armor side cheek + recessed louver cooling bay (root x_min = 0.38 - 0.222 = 0.158 >= 0.05!)
    kb.plate("ManifoldCheek_L", crect_2d(0.56, 0.28, (0.06, 0.04, 0.04, 0.06)), 0.042, "armor", "armor_panel",
             (-0.176, -0.02, -0.46), (0, 90, 0), 0.008, 1, M_parent=M_arm)
    kb.louver_bay("ManifoldVent", 0.28, 0.125, 0.030, (-0.206, -0.02, -0.46), (0, 90, 0),
                  blades=4, mesh_style=False, M_parent=M_arm)

    # 4. Dual Pressurized Horizontal Napalm Fuel Tanks + Dark Retaining Straps + Brass Pressure Gauges
    # Saddle cradles linking ManifoldCore (+X face = +0.16) to dual tanks at tx = +0.285
    for ci, cz in enumerate([-0.26, -0.58]):
        kb.box(f"TankCradle_{ci}", (0.15, 0.44, 0.068), "dark", "bolt_flange",
               (0.205, -0.02, cz), (0, 0, 0), 0.007, 1, M_parent=M_arm)

    # One-piece domed cylindrical pressure-vessel lathe profile (total length 0.72, r = 0.128)
    tank_prof = [
        (0.0, -0.360), (0.056, -0.348), (0.098, -0.320), (0.122, -0.280), (0.128, -0.240),
        (0.128, 0.240), (0.122, 0.280), (0.098, 0.320), (0.056, 0.348), (0.0, 0.360),
    ]
    tx, tz = 0.290, -0.42
    for ti, (oy, tslot) in enumerate([(0.130, "accent"), (-0.160, "armor_sub")]):
        kb.lathe(f"FuelTank_{ti}", tank_prof, 20, tslot, "armor_panel",
                 (tx, oy, tz), (90, 0, 0), M_parent=M_arm, u_rep=2.0)
        # Dual dark rubber/steel retaining straps aligned directly with TankCradle_0/1
        for si, sz in enumerate([-0.26, -0.58]):
            kb.cyl(f"TankStrap_{ti}_{si}", 0.136, 0.136, 0.038, 20, "rubber", "bolt_flange",
                   (tx, oy, sz), (90, 0, 0), 0.004, M_parent=M_arm, u_rep=2.0)
        # Front brass pressure-regulator valve & rear brass fill plug
        kb.cyl(f"TankValveF_{ti}", 0.036, 0.032, 0.068, 12, "brass", "gear_collar",
               (tx, oy, -0.785), (90, 0, 0), 0.003, M_parent=M_arm)
        kb.cyl(f"TankCapR_{ti}", 0.034, 0.034, 0.038, 12, "brass", "plain_metal",
               (tx, oy, -0.055), (90, 0, 0), 0.003, M_parent=M_arm)

    # Proud hazard warning collar on upper tank center (r=0.134 proud of r=0.128 by 6mm -> ZERO Z-fight!)
    kb.cyl("TankHazardBand", 0.134, 0.134, 0.060, 20, "hazard", "hazard",
           (tx, 0.130, tz), (90, 0, 0), 0.003, M_parent=M_arm, u_rep=2.0)

    # Dual Outboard Brass Pressure Gauges with Obsidian Glass Faces mounted between tanks
    for gi, gz in enumerate([-0.26, -0.58]):
        kb.box(f"GaugeBlock_{gi}", (0.095, 0.11, 0.078), "dark", "frame_cnc",
               (0.325, -0.015, gz), (0, 0, 0), 0.006, 1, M_parent=M_arm)
        kb.cyl(f"GaugeBezel_{gi}", 0.042, 0.044, 0.028, 16, "brass", "gear_collar",
               (0.382, -0.015, gz), (0, 0, 90), 0.003, hollow_r=0.032, M_parent=M_arm)
        kb.cyl(f"GaugeGlass_{gi}", 0.031, 0.031, 0.014, 14, "glass", "plain_metal",
               (0.384, -0.015, gz), (0, 0, 90), 0.002, M_parent=M_arm)

    # Braided Fuel Transfer Hoses (braid_hose) + Rear Copper Pressure-Balance Line
    kb.tube_path("FuelHose_Top",
                 [(tx, 0.130, -0.80), (0.24, 0.10, -0.92), (0.06, 0.01, -0.86)],
                 0.021, 8, "gunmetal", "braid_hose", add_clamps=False, M_parent=M_arm)
    kb.tube_path("FuelHose_Bot",
                 [(tx, -0.160, -0.80), (0.24, -0.15, -0.96), (0.05, -0.08, -0.88)],
                 0.024, 8, "gunmetal", "braid_hose", add_clamps=False, M_parent=M_arm)
    kb.tube_path("BalancePipe_R",
                 [(tx, 0.130, -0.06), (0.35, -0.015, -0.02), (tx, -0.160, -0.06)],
                 0.014, 8, "copper", "plain_metal", add_clamps=False, M_parent=M_arm)

    # 5. Perforated Front Heat Shroud + Wide Flame Projector Nozzle + Underslung Pilot Igniter & Glow
    kb.cyl("ProjectorManifold", 0.114, 0.118, 0.15, 18, "dark", "bolt_flange",
           (0, -0.04, -0.82), (90, 0, 0), 0.006, M_parent=M_arm, u_rep=2.0)
    kb.cyl("FlameTube", 0.056, 0.056, 0.56, 16, "gunmetal", "plain_metal",
           (0, -0.04, -1.08), (90, 0, 0), 0.003, M_parent=M_arm)

    # Perforated vent_mesh cylindrical heat shroud cage + 4 protective cage bars + front collar
    kb.cyl("HeatShroudMesh", 0.102, 0.102, 0.44, 18, "gunmetal", "vent_mesh",
           (0, -0.04, -1.06), (90, 0, 0), 0.004, hollow_r=0.082, M_parent=M_arm, u_rep=2.0)
    for ri in range(4):
        ra = math.tau * (ri + 0.5) / 4.0
        kb.box(f"ShroudBar_{ri}", (0.016, 0.014, 0.44), "dark", "plain_metal",
               (math.cos(ra) * 0.105, -0.04 + math.sin(ra) * 0.105, -1.06),
               (0, 0, math.degrees(ra) - 90.0), 0.002, 1, M_parent=M_arm)
    kb.cyl("NozzleCollar", 0.108, 0.108, 0.046, 18, "dark", "bolt_flange",
           (0, -0.04, -1.28), (90, 0, 0), 0.004, M_parent=M_arm, u_rep=2.0)

    # Upper armored heat deflector hood + proud accent strip
    kb.plate("FlamerTopShield", trap_2d(0.46, 0.30, 0.10, 0.025), 0.25, "armor", "armor_panel",
             (0, 0.095, -1.04), (0, 90, 0), 0.008, 1, M_parent=M_arm)
    kb.box("FlamerTopAccent", (0.20, 0.014, 0.28), "accent", "plain_metal",
           (0, 0.150, -1.04), (0, 0, 0), 0.002, 1, M_parent=M_arm)

    # Flared blackened flame projector nozzle + wide smooth hollow bore (tip = -1.450!)
    # rot=(90,0,0): r_top -> +Z (rear), r_bot -> -Z (wide flared front, ends at -1.392 -> 13mm clear of FlameBore_br!)
    kb.cyl("NozzleBell", 0.072, 0.094, 0.112, 18, "dark", "gear_collar",
           (0, -0.04, -1.336), (90, 0, 0), 0.005, M_parent=M_arm, u_rep=2.0)
    kb.barrel_bore("FlameBore", 0.092, 0.068, (0, -0.04, -1.398), depth=0.074,
                   rot_deg=(-90, 0, 0), segs=18, M_parent=M_arm)

    # Underslung pilot igniter bracket + brass gas tube + copper tip + pinpoint emit_amber pilot flame!
    kb.box("IgniterBracket", (0.036, 0.105, 0.044), "dark", "bolt_flange",
           (0, -0.130, -1.275), (16, 0, 0), 0.004, 1, M_parent=M_arm)
    kb.cyl("IgniterPipe", 0.015, 0.015, 0.21, 10, "brass", "plain_metal",
           (0, -0.168, -1.335), (82, 0, 0), 0.002, M_parent=M_arm)
    kb.cyl("IgniterTip", 0.020, 0.018, 0.032, 10, "copper", "gear_collar",
           (0, -0.154, -1.430), (82, 0, 0), 0.002, M_parent=M_arm)
    # Pinpoint emit_amber pilot glow seated cleanly on IgniterTip (ZERO floating, ZERO burial!)
    kb.cyl("IgniterPilotGlow", 0.013, 0.005, 0.026, 10, "emit_amber", "plain_metal",
           (0, -0.151, -1.450), (82, 0, 0), 0.002, M_parent=M_arm)

    # Exact MUZZLE marker aligned with wide flame projector nozzle
    kb.add_marker("MUZZLE", (cx, -0.04, -1.45))


# ==============================================================================
# 5. arm_sniper : M99 Long-Range Anti-Materiel Sniper Rifle (MUZZLE z = -3.08)
# ==============================================================================
def build_arm_sniper(kb: KitbashScene):
    # 1. Standardized HP-A1 Shoulder Adapter
    kb.a1_shoulder_mount("A1Std", heavy=False)

    # 2. Sleek Stabilizer Shoulder Shield (strictly outboard x >= 0.18, set slightly aft to clear scope eye-line)
    _build_pauldron(
        kb,
        pos=(0.39, 0.42, 0.06),
        rot_deg=(0, 0, -10.0),
        main_trap=(0.66, 0.42, 0.20, 0.05),
        main_thick=0.40,
        sub_trap=(0.48, 0.30, 0.135, 0.035),
        sub_thick=0.060,
        trim_slot="accent",
        trim_band="plain_metal",
        trim_h=0.105,
        trim_z=0.36,
        grab_w=0.18,
        grab_d=0.030,
        bolt_zs=(-0.14, 0.0, 0.14),
    )

    # 3. Long CNC-Milled Sniper Receiver + Recoil Buffer Stock + 5-Round Box Magazine (x = 0.58, y = -0.02)
    cx, cy = 0.58, -0.02
    M_g = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Slim long CNC receiver (root x in [0.46, 0.70], y in [-0.15, +0.11] -> clears A1Std_ykf cleanly!)
    kb.box("ReceiverCore", (0.24, 0.26, 1.06), "dark", "frame_cnc",
           (0, 0.0, -0.06), (0, 0, 0), 0.014, 1, M_parent=M_g, tile_u=2.5)
    # Bolted side armor plates (inboard starts forward of yoke at z = -0.38)
    kb.plate("RecSidePlate_R", crect_2d(0.96, 0.22, (0.04, 0.04, 0.04, 0.04)), 0.032, "armor_sub", "armor_hatch",
             (0.132, 0.0, -0.06), (0, 90, 0), 0.006, 1, M_parent=M_g)
    kb.box("RecSidePlate_L", (0.032, 0.20, 0.36), "armor_sub", "armor_panel",
           (-0.132, 0.0, -0.38), (0, 0, 0), 0.006, 1, M_parent=M_g)

    # Rear recoil buffer stock + visible chrome buffer rod + rubber cheek rest & buttpad
    kb.box("RecoilStock", (0.18, 0.22, 0.26), "armor_sub", "armor_pocket",
           (0, -0.01, 0.58), (0, 0, 0), 0.012, 1, M_parent=M_g)
    kb.cyl("StockBufferRod", 0.036, 0.036, 0.24, 12, "chrome", "plain_metal",
           (0, -0.105, 0.56), (90, 0, 0), 0.003, M_parent=M_g)
    kb.box("StockButtPad", (0.20, 0.26, 0.056), "rubber", "dust_boot",
           (0, -0.02, 0.732), (0, 0, 0), 0.008, 1, M_parent=M_g)
    kb.box("StockCheekRest", (0.20, 0.052, 0.34), "rubber", "plain_metal",
           (0, 0.148, 0.34), (0, 0, 0), 0.008, 1, M_parent=M_g)

    # Outboard recessed ejection port + bolt-action charging handle
    kb.box("EjectPortFrame", (0.018, 0.078, 0.24), "gunmetal", "bolt_flange",
           (0.150, 0.042, -0.14), (0, 0, 0), 0.003, 1, M_parent=M_g)
    kb.box("EjectPortBore", (0.012, 0.052, 0.20), "bore", "plain_metal",
           (0.158, 0.042, -0.14), (0, 0, 0), 0.002, 1, M_parent=M_g)
    kb.cyl("BoltHandleStem", 0.018, 0.018, 0.092, 10, "chrome", "plain_metal",
           (0.184, 0.02, 0.08), (0, 0, 90), 0.002, M_parent=M_g)
    kb.cyl("BoltHandleKnob", 0.030, 0.030, 0.046, 12, "dark", "gear_collar",
           (0.236, 0.02, 0.08), (0, 0, 90), 0.003, M_parent=M_g)

    # 5-Round Vertical Box Magazine slung cleanly under breech
    kb.box("MagWell", (0.18, 0.072, 0.30), "gunmetal", "bolt_flange",
           (0, -0.155, -0.14), (0, 0, 0), 0.006, 1, M_parent=M_g)
    kb.box("BoxMagBody", (0.135, 0.28, 0.255), "dark", "armor_ribs",
           (0, -0.312, -0.152), (6, 0, 0), 0.010, 1, M_parent=M_g)
    kb.box("BoxMagFloor", (0.156, 0.036, 0.280), "gunmetal", "bolt_flange",
           (0, -0.456, -0.168), (6, 0, 0), 0.005, 1, M_parent=M_g)
    kb.box("BoxMagStripe", (0.010, 0.036, 0.21), "accent", "plain_metal",
           (0.070, -0.33, -0.154), (6, 0, 0), 0.002, 1, M_parent=M_g)

    # 4. Elevated Cantilevered Long-Focus Telescopic Optic Scope + Side Laser Rangefinder
    kb.box("TopPicRail", (0.105, 0.038, 0.90), "gunmetal", "bolt_flange",
           (0, 0.144, -0.33), (0, 0, 0), 0.005, 1, M_parent=M_g, tile_u=3.0)
    kb.box("ScopeMountBase", (0.098, 0.046, 0.44), "dark", "frame_cnc",
           (0, 0.182, -0.32), (0, 0, 0), 0.005, 1, M_parent=M_g)
    for ri, rz in enumerate([-0.18, -0.46]):
        kb.box(f"ScopeOptic_riser{ri}", (0.092, 0.092, 0.062), "dark", "bolt_flange",
               (0, 0.244, rz), (0, 0, 0), 0.006, 1, M_parent=M_g)
        kb.cyl(f"ScopeOptic_ring{ri}", 0.066, 0.066, 0.056, 16, "gunmetal", "gear_collar",
               (0, 0.305, rz), (90, 0, 0), 0.004, M_parent=M_g)
        for bi, bx in enumerate([-0.034, 0.034]):
            kb.cyl(f"ScopeBolt_{ri}_{bi}", 0.007, 0.008, 0.014, 6, "chrome", "plain_metal",
                   (bx, 0.370, rz), (0, 0, 0), 0.001, M_parent=M_g)

    # Telescopic main tube + brass ballistic elevation/windage turrets + front/rear obsidian glass lenses
    kb.cyl("ScopeOptic_tube", 0.048, 0.048, 0.60, 16, "dark", "plain_metal",
           (0, 0.305, -0.32), (90, 0, 0), 0.003, M_parent=M_g)
    kb.cyl("ScopeOptic_turT", 0.025, 0.025, 0.044, 14, "brass", "gear_collar",
           (0, 0.368, -0.32), (0, 0, 0), 0.003, M_parent=M_g)
    kb.cyl("ScopeOptic_turS", 0.023, 0.023, 0.040, 14, "brass", "gear_collar",
           (0.064, 0.305, -0.32), (0, 0, 90), 0.003, M_parent=M_g)
    # Front flared objective bell (rot=(90,0,0): r_top -> +Z rear, r_bot -> -Z wide front!) + sunshade + obsidian lens
    kb.cyl("ScopeOptic_obj", 0.049, 0.072, 0.145, 18, "armor_dark", "plain_metal",
           (0, 0.305, -0.665), (90, 0, 0), 0.004, M_parent=M_g)
    kb.cyl("ScopeOptic_shade", 0.074, 0.074, 0.098, 18, "dark", "gear_collar",
           (0, 0.305, -0.775), (90, 0, 0), 0.003, hollow_r=0.063, M_parent=M_g)
    kb.cyl("ScopeOptic_lensF", 0.062, 0.062, 0.016, 16, "glass", "plain_metal",
           (0, 0.305, -0.742), (90, 0, 0), 0.002, M_parent=M_g)
    # Rear ocular eyepiece bell + obsidian ocular lens
    kb.cyl("ScopeOptic_ocu", 0.062, 0.048, 0.14, 16, "dark", "gear_collar",
           (0, 0.305, 0.035), (90, 0, 0), 0.004, M_parent=M_g)
    kb.cyl("ScopeOptic_lensR", 0.050, 0.050, 0.016, 16, "glass", "plain_metal",
           (0, 0.305, 0.109), (90, 0, 0), 0.002, M_parent=M_g)

    # Compact side-mounted Laser Rangefinder housing (obsidian lens + pinpoint cyan laser pip)
    kb.box("LRFMountBrk", (0.075, 0.044, 0.10), "gunmetal", "plain_metal",
           (0.068, 0.252, -0.44), (0, 0, 0), 0.004, 1, M_parent=M_g)
    kb.box("LRFHousing", (0.094, 0.088, 0.21), "armor_dark", "armor_pocket",
           (0.125, 0.252, -0.44), (0, 0, 0), 0.008, 1, M_parent=M_g)
    kb.cyl("LRFOptic_bezel", 0.025, 0.027, 0.022, 14, "gunmetal", "plain_metal",
           (0.125, 0.252, -0.552), (90, 0, 0), 0.002, hollow_r=0.018, M_parent=M_g)
    kb.cyl("LRFOptic_glass", 0.017, 0.017, 0.012, 12, "glass", "plain_metal",
           (0.125, 0.252, -0.550), (90, 0, 0), 0.002, M_parent=M_g)
    kb.cyl("LRFOptic_pip", 0.006, 0.006, 0.013, 8, "emit_cyan", "plain_metal",
           (0.125, 0.252, -0.553), (90, 0, 0), 0.001, M_parent=M_g)

    # 5. Free-Floating Vented Forend + Barrel Clamp + Folded Tactical Bipod Legs
    kb.box("ForendShroud", (0.185, 0.185, 0.78), "armor", "armor_panel",
           (0, 0.010, -0.96), (0, 0, 0), 0.014, 1, M_parent=M_g)
    # Recessed mesh cooling vents on both flanks of forend
    kb.louver_bay("ForendVent_R", 0.44, 0.082, 0.024, (0.098, 0.012, -0.98), (0, -90, 0),
                  blades=5, mesh_style=True, M_parent=M_g)
    kb.louver_bay("ForendVent_L", 0.44, 0.082, 0.024, (-0.098, 0.012, -0.98), (0, 90, 0),
                  blades=5, mesh_style=True, M_parent=M_g)
    kb.box("ForendTopRail", (0.088, 0.024, 0.50), "gunmetal", "bolt_flange",
           (0, 0.112, -1.04), (0, 0, 0), 0.004, 1, M_parent=M_g, tile_u=2.0)

    # Heavy precision barrel clamp collar at front of forend
    kb.box("BarrelClamp", (0.205, 0.195, 0.096), "dark", "bolt_flange",
           (0, 0.014, -1.36), (0, 0, 0), 0.010, 1, M_parent=M_g)
    for bi, (bx, by) in enumerate([(-0.07, 0.116), (0.07, 0.116), (-0.106, 0.014), (0.106, 0.014)]):
        kb.cyl(f"BClampBolt_{bi}", 0.008, 0.010, 0.014, 6, "chrome", "plain_metal",
               (bx, by, -1.36), (0, 0, 0) if bi < 2 else (0, 0, 90), 0.002, M_parent=M_g)

    # Folded under-barrel tactical bipod legs (pivoting under BarrelClamp forward along z in [-1.34, -1.86])
    kb.box("BipodMount", (0.172, 0.066, 0.092), "gunmetal", "bolt_flange",
           (0, -0.106, -1.34), (0, 0, 0), 0.006, 1, M_parent=M_g)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.cyl(f"BipodJoint_{sxi}", 0.023, 0.023, 0.042, 10, "dark", "gear_collar",
               (sx * 0.096, -0.110, -1.34), (0, 0, 90), 0.003, M_parent=M_g)
        kb.cyl(f"BipodLeg_{sxi}", 0.018, 0.018, 0.34, 10, "dark", "plain_metal",
               (sx * 0.098, -0.116, -1.52), (88, 0, 0), 0.002, M_parent=M_g)
        kb.cyl(f"BipodCollar_{sxi}", 0.022, 0.022, 0.026, 10, "brass", "gear_collar",
               (sx * 0.098, -0.120, -1.67), (88, 0, 0), 0.002, M_parent=M_g)
        kb.cyl(f"BipodSlide_{sxi}", 0.013, 0.013, 0.20, 10, "chrome", "plain_metal",
               (sx * 0.098, -0.123, -1.75), (88, 0, 0), 0.002, M_parent=M_g)
        kb.box(f"BipodFoot_{sxi}", (0.040, 0.056, 0.048), "rubber", "plain_metal",
               (sx * 0.098, -0.127, -1.86), (0, 0, 0), 0.005, 1, M_parent=M_g)

    # 6. Long Heavy Free-Floating Precision Barrel + Flat Twin-Chamber Tank Muzzle Brake + Hollow Bore
    kb.cyl("BarrelHeavyRoot", 0.050, 0.046, 0.46, 16, "dark", "gear_collar",
           (0, 0.02, -1.56), (90, 0, 0), 0.004, M_parent=M_g, u_rep=2.0)
    kb.cyl("BarrelMatchMain", 0.036, 0.034, 1.06, 16, "gunmetal", "plain_metal",
           (0, 0.02, -2.28), (90, 0, 0), 0.003, M_parent=M_g)
    kb.cyl("BarrelTunerRing", 0.045, 0.045, 0.042, 16, "dark", "bolt_flange",
           (0, 0.02, -2.26), (90, 0, 0), 0.004, M_parent=M_g)

    # Flat Twin-Chamber Tank-Style Muzzle Brake (z in [-3.05, -2.78]) + Hollow Bore (tip = -3.080!)
    kb.cyl("MuzzleBrake_nut", 0.050, 0.050, 0.046, 16, "dark", "gear_collar",
           (0, 0.02, -2.80), (90, 0, 0), 0.003, M_parent=M_g)
    kb.box("MuzzleBrake_top", (0.210, 0.024, 0.245), "dark", "frame_cnc",
           (0, 0.064, -2.935), (0, 0, 0), 0.005, 1, M_parent=M_g)
    kb.box("MuzzleBrake_bot", (0.210, 0.024, 0.245), "dark", "frame_cnc",
           (0, -0.024, -2.935), (0, 0, 0), 0.005, 1, M_parent=M_g)
    for bi, bz in enumerate([-2.835, -2.935, -3.035]):
        kb.box(f"MuzzleBrake_baf{bi}", (0.224, 0.098, 0.026), "gunmetal", "plain_metal",
               (0, 0.02, bz), (0, 0, 0), 0.004, 1, M_parent=M_g)
    kb.cyl("MuzzleBrake_core", 0.034, 0.034, 0.21, 14, "bore", "plain_metal",
           (0, 0.02, -2.935), (90, 0, 0), 0.002, M_parent=M_g)
    kb.barrel_bore("MuzzleBore", 0.040, 0.027, (0, 0.02, -3.045), depth=0.050,
                   rot_deg=(-90, 0, 0), segs=16, M_parent=M_g)

    # Exact MUZZLE marker aligned with M99 barrel tip (M_g (0.58, -0.02, 0) + (0, 0.02, -3.08))
    kb.add_marker("MUZZLE", (cx, cy + 0.02, -3.08))
