"""G-36 (arm_gatling) High-Precision 7-Barrel Rotary Cannon (Canonical Right Arm side=+1.0) — MECH_MODELING_STANDARD v1.0."""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


def build_arm_gatling(kb: KitbashScene):
    # Canonical RIGHT arm (side = +1.0); origin (0,0,0) = HP-A1 mating face; mech_glb.gd mirrors cleanly for arm_l!
    # 1. Unified Heavy HP-A1 Shoulder Adapter (flange + geared slewing race + yoke + heavy gussets)
    kb.a1_shoulder_mount("A1Heavy", heavy=True)

    # 2. Multi-Layer Spaced Heavy Shoulder Pauldron (at arm x=0.25 + 0.22 = 0.47)
    M_sh = g2b_mat((0.47, 0.48, 0.04), (0, 0, -12.0))
    kb.plate("PauldronMain", trap_2d(0.96, 0.66, 0.30, 0.08), 0.74, "armor", "armor_panel", (0, 0, 0), (0, 90, 0), 0.018, 1, M_parent=M_sh)
    kb.plate("PauldronSub", trap_2d(0.76, 0.50, 0.20, 0.05), 0.12, "armor_sub", "armor_ribs", (0.37, -0.02, 0), (0, 90, 0), 0.010, 1, M_parent=M_sh)
    kb.box("PauldronHazard", (0.045, 0.24, 0.72), "hazard", "hazard", (0.16, 0.01, 0), (0, 0, 0), 0.004, 1, M_parent=M_sh)
    kb.grab_rail("PauldronGrab", 0.24, 0.042, (0.0, 0.165, 0.0), (-90, 90, 0), 0.011, M_parent=M_sh)
    for bi, bz in enumerate([-0.26, 0.0, 0.26]):
        kb.cyl(f"PauldronBolt_{bi}", 0.014, 0.016, 0.024, 6, "chrome", "plain_metal", (0.435, 0.03, bz), (0, 0, 90), 0.002, M_parent=M_sh)

    # 3. Heavy Rotary Receiver Block (center at x=0.75, y=-0.04, z=0.0)
    M_g = g2b_mat((0.75, -0.04, 0.0), (0, 0, 0))
    kb.box("ReceiverCore", (0.56, 0.64, 0.96), "gunmetal", "frame_cnc", (0, 0, -0.02), (0, 0, 0), 0.018, 1, M_parent=M_g, tile_u=2.0)
    # Bolted spaced side armor cheeks on receiver
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"RecSidePlate_{sxi}", crect_2d(0.88, 0.52, (0.0, 0.12, 0.08, 0.0)), 0.065, "armor_sub", "armor_hatch",
                 (sx * 0.305, 0.0, -0.02), (0, 90, 0), 0.010, 1, M_parent=M_g)
    # Inner side recessed louver cooling bay
    kb.louver_bay("RecCoolingBay", 0.42, 0.20, 0.042, (-0.34, 0.0, 0.08), (0, -90, 0), blades=5, mesh_style=False, M_parent=M_g)
    # Top hydraulic rotary drive motor + brass coupling + braided hydraulic loop
    kb.cyl("DriveMotor", 0.145, 0.145, 0.40, 18, "dark", "gear_collar", (0, 0.38, 0.16), (90, 0, 0), 0.008, M_parent=M_g, u_rep=2.0)
    kb.cyl("DriveBrassRing", 0.158, 0.158, 0.042, 18, "brass", "bolt_flange", (0, 0.38, 0.37), (90, 0, 0), 0.005, M_parent=M_g)
    kb.cyl("DriveFrontCap", 0.125, 0.135, 0.045, 16, "gunmetal", "plain_metal", (0, 0.38, -0.06), (90, 0, 0), 0.005, M_parent=M_g)
    kb.tube_path("DriveHydLoop", [(0.0, 0.38, 0.38), (-0.18, 0.34, 0.44), (-0.24, 0.16, 0.34)], 0.022, 8, "gunmetal", "braid_hose", M_parent=M_g)
    kb.grab_rail("RecTopGrab", 0.24, 0.036, (0.0, 0.33, -0.26), (-90, 0, 0), 0.010, M_parent=M_g)

    # 4. Outer Heavy Linkless Ammo Drum Magazine + Articulated Feed Chute
    dx, dy, dz = 0.56, -0.10, 0.18
    kb.cyl("AmmoDrum", 0.38, 0.38, 0.40, 24, "armor_sub", "armor_panel", (dx, dy, dz), (0, 0, 90), 0.012, M_parent=M_g, u_rep=2.0)
    for ri, rx in enumerate([0.37, 0.75]):
        kb.cyl(f"DrumRim_{ri}", 0.398, 0.398, 0.038, 24, "dark", "bolt_flange", (rx, dy, dz), (0, 0, 90), 0.005, M_parent=M_g, u_rep=2.0)
    kb.cyl("DrumHazardBand", 0.388, 0.388, 0.068, 24, "hazard", "hazard", (dx, dy, dz), (0, 0, 90), 0.003, M_parent=M_g, u_rep=2.0)
    kb.cyl("DrumHub", 0.115, 0.115, 0.45, 14, "gunmetal", "gear_collar", (dx, dy, dz), (0, 0, 90), 0.006, M_parent=M_g)
    kb.bolt_ring("DrumBolts", 0.22, 8, 0.014, (0.768, dy, dz), (0, 0, -90), M_parent=M_g)
    for ri in range(6):
        a = math.tau * ri / 6.0
        kb.box(f"DrumRib_{ri}", (0.41, 0.034, 0.034), "dark", "plain_metal",
               (dx, dy + math.sin(a) * 0.27, dz + math.cos(a) * 0.27), (math.degrees(a), 0, 0), 0.004, 1, M_parent=M_g)
    # 5-segment armored articulated feed chute curving from drum into receiver
    for fi in range(5):
        t = fi / 4.0
        fx = 0.48 + (0.28 - 0.48) * t
        fy = -0.44 + (-0.22 - (-0.44)) * t - math.sin(t * math.pi) * 0.05
        fz = 0.02 + (-0.26 - 0.02) * t
        kb.box(f"FeedSeg_{fi}", (0.22, 0.145, 0.115), "gunmetal", "armor_ribs", (fx, fy, fz), (0, 0, -18.0), 0.009, 1, M_parent=M_g)

    # 5. GAU-8 Seven-Barrel Rotary Cluster + Geared Rotor Collar + Perforated Heat Shield + 3 Clamps
    kb.cyl("RotorCollar", 0.295, 0.305, 0.30, 24, "dark", "gear_collar", (0, 0, -0.62), (90, 0, 0), 0.010, M_parent=M_g, u_rep=2.0)
    kb.bolt_ring("RotorBolts", 0.25, 8, 0.012, (0, 0, -0.775), (90, 0, 0), M_parent=M_g)
    # Upper armored heat-shield / deflector shroud with perforated mesh strip!
    kb.plate("UpperShroud", trap_2d(0.52, 0.40, 0.62, 0.05), 0.085, "armor", "armor_panel", (0, 0.24, -0.98), (88, 0, 0), 0.012, 1, M_parent=M_g)
    kb.box("ShroudPerf", (0.34, 0.022, 0.46), "gunmetal", "vent_mesh", (0, 0.285, -0.98), (2, 0, 0), 0.004, 1, M_parent=M_g)

    # 7 precision gun barrels + deep hollow crowns + central drive shaft
    for bi in range(7):
        a = math.tau * bi / 7.0
        bx, by = math.cos(a) * 0.165, math.sin(a) * 0.165
        kb.cyl(f"Barrel_{bi}", 0.048, 0.050, 1.40, 12, "dark", "plain_metal", (bx, by, -1.45), (90, 0, 0), 0.003, M_parent=M_g)
        kb.barrel_bore(f"Bore_{bi}", 0.049, 0.034, (bx, by, -2.16), 0.085, segs=12, M_parent=M_g)
    kb.cyl("CenterShaft", 0.072, 0.072, 1.40, 12, "gunmetal", "gear_collar", (0, 0, -1.45), (90, 0, 0), 0.004, M_parent=M_g)

    # 3 heavy barrel clamp discs with bolt rings & outer clamping bands
    for ci, zz in enumerate([-0.95, -1.52, -2.08]):
        kb.cyl(f"ClampDisc_{ci}", 0.245, 0.245, 0.088, 22, "gunmetal", "bolt_flange", (0, 0, zz), (90, 0, 0), 0.006, M_parent=M_g, u_rep=2.0)
        kb.cyl(f"ClampBand_{ci}", 0.255, 0.255, 0.028, 22, "dark", "gear_collar", (0, 0, zz), (90, 0, 0), 0.003, M_parent=M_g, u_rep=2.0)

    # Standard MUZZLE Marker (in root coords: M_g origin (0.75, -0.04, 0) + (0, 0, -2.25))
    kb.add_marker("MUZZLE", (0.75, -0.04, -2.25))
