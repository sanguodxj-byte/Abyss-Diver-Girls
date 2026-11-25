"""G-36 (arm_mg) High-Precision 6-Barrel Rapid Rotary Autocannon (Canonical Right Arm) — Zero-Clip Rich Mechanical Standard (v1.5)."""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


def build_arm_mg(kb: KitbashScene):
    # Canonical RIGHT arm (side = +1.0); origin (0,0,0) = HP-A1 mating face; mech_glb.gd mirrors cleanly for arm_l!
    # 1. Standardized HP-A1 Shoulder Adapter (strictly x >= 0.00 -> 0mm clash with core_scout!)
    kb.a1_shoulder_mount("A1Std", heavy=False)

    # 2. Spaced Chamfered Tactical Shoulder Pauldron (broad RHA armor_slab + B.o.T top caution chevron decal!)
    M_sh = g2b_mat((0.40, 0.42, 0.02), (0, 0, -10.0))
    kb.plate("PauldronMain", trap_2d(0.72, 0.50, 0.22, 0.06), 0.44, "armor", "armor_slab", (0, 0, 0), (0, 90, 0), 0.022, 2, M_parent=M_sh)
    kb.plate("PauldronSub", trap_2d(0.54, 0.36, 0.14, 0.04), 0.075, "armor_oxide", "weld_plate", (0.24, -0.01, 0), (0, 90, 0), 0.012, 1, M_parent=M_sh)
    kb.decal("PauldronTopChev", "caution_chev", (0.28, 0.28), (0.02, 0.114, -0.04), (90, 0, 0), M_parent=M_sh)
    kb.box("PauldronHazard", (0.014, 0.12, 0.44), "hazard", "hazard", (0.285, -0.01, 0), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    kb.grab_rail("PauldronGrab", 0.20, 0.032, (0.0, 0.108, 0.0), (90, 0, 0), 0.009, M_parent=M_sh)

    # 3. Rich CNC Armored Rotary Receiver (centered at arm x=0.25, y=0.0, z=0.0 matching arm_mg.gd!)
    M_arm = g2b_mat((0.25, 0.0, 0.0), (0, 0, 0))
    kb.box("ReceiverCore", (0.34, 0.36, 0.74), "dark", "frame_cnc", (0, -0.04, -0.28), (0, 0, 0), 0.014, 1, M_parent=M_arm, tile_u=2.0)
    kb.plate("ReceiverShroud", crect_2d(0.84, 0.36, (0.10, 0.0, 0.06, 0.09)), 0.42, "armor", "armor_panel",
             (0, 0.0, -0.28), (0, 90, 0), 0.012, 1, M_parent=M_arm)
    # Recessed outer cooling louver bay + top tactical rail + proud accent band + hydraulic loop
    kb.louver_bay("RecCoolingVent", 0.36, 0.15, 0.036, (0.222, -0.02, -0.38), (0, 90, 0), blades=5, mesh_style=False, M_parent=M_arm)
    kb.box("RecTopRail", (0.16, 0.034, 0.46), "gunmetal", "bolt_flange", (0, 0.195, -0.46), (0, 0, 0), 0.005, 1, M_parent=M_arm)
    kb.box("RecAccentStripe", (0.018, 0.044, 0.42), "accent", "plain_metal", (0.222, 0.125, -0.44), (0, 0, 0), 0.002, 1, M_parent=M_arm)
    kb.tube_path("RecHydLoop", [(0.16, -0.14, 0.06), (0.24, -0.22, -0.04), (0.18, -0.20, -0.24)], 0.016, 8, "gunmetal", "braid_hose", M_parent=M_arm)

    # 4. Side-Mounted Armored Olive Ammo Drum + Brass Lock Ring + Articulated Feed Chute (outboard x=+0.38)
    dx, dy, dz = 0.38, -0.11, 0.02
    kb.cyl("AmmoDrumBody", 0.232, 0.232, 0.246, 24, "armor_sub", "armor_panel", (dx, dy, dz), (0, 0, 90), 0.010, M_parent=M_arm, u_rep=2.0)
    for ri, rx in enumerate([dx - 0.095, dx + 0.095]):
        kb.cyl(f"DrumRim_{ri}", 0.252, 0.252, 0.028, 24, "dark", "bolt_flange", (rx, dy, dz), (0, 0, 90), 0.004, M_parent=M_arm, u_rep=2.0)
    kb.cyl("DrumAccentBand", 0.242, 0.242, 0.042, 24, "accent", "plain_metal", (dx, dy, dz), (0, 0, 90), 0.002, M_parent=M_arm)
    kb.cyl("DrumHub", 0.082, 0.082, 0.275, 16, "gunmetal", "gear_collar", (dx, dy, dz), (0, 0, 90), 0.005, M_parent=M_arm)
    kb.bolt_ring("DrumBolts", 0.15, 6, 0.012, (dx + 0.128, dy, dz), (0, 0, -90), M_parent=M_arm)
    for fi in range(3):
        t = fi / 2.0
        kb.box(f"FeedSeg_{fi}", (0.13, 0.11, 0.13), "gunmetal", "armor_ribs",
               (0.32 - t * 0.11, -0.22 + t * 0.05, -0.12 - t * 0.24), (0, 20, 0), 0.007, 1, M_parent=M_arm)

    # 5. Long Perforated Cooling Shroud + 6 Rotary Steel Barrels + Smooth Hollow Muzzles (exact z=-2.26!)
    kb.cyl("RotorCollar", 0.172, 0.178, 0.20, 22, "dark", "gear_collar", (0, 0, -0.78), (90, 0, 0), 0.008, M_parent=M_arm, u_rep=2.0)
    kb.bolt_ring("RotorBolts", 0.142, 6, 0.010, (0, 0, -0.882), (90, 0, 0), M_parent=M_arm)
    kb.cyl("CoolingJacket", 0.136, 0.136, 0.90, 20, "gunmetal", "vent_mesh", (0, 0, -1.33), (90, 0, 0), 0.006, hollow_r=0.108, M_parent=M_arm, u_rep=2.0)
    for ri in range(4):
        ra = math.tau * (ri + 0.5) / 4.0
        kb.box(f"JacketRib_{ri}", (0.020, 0.016, 0.84), "dark", "plain_metal",
               (math.cos(ra) * 0.139, math.sin(ra) * 0.139, -1.33), (0, 0, math.degrees(ra) - 90.0), 0.003, 1, M_parent=M_arm)
    for bi in range(6):
        a = math.tau * bi / 6.0
        bx, by = math.cos(a) * 0.076, math.sin(a) * 0.076
        kb.cyl(f"Barrel_{bi}", 0.028, 0.030, 1.32, 12, "dark", "plain_metal", (bx, by, -1.56), (90, 0, 0), 0.002, M_parent=M_arm)
        kb.barrel_bore(f"Bore_{bi}", 0.030, 0.020, (bx, by, -2.215), depth=0.055, segs=12, M_parent=M_arm)
    kb.cyl("CenterShaft", 0.038, 0.038, 1.34, 12, "gunmetal", "gear_collar", (0, 0, -1.57), (90, 0, 0), 0.003, M_parent=M_arm)
    for ci, (zz, cr) in enumerate([(-0.91, 0.148), (-1.34, 0.148), (-1.78, 0.146), (-2.12, 0.122)]):
        kb.cyl(f"BarrelClamp_{ci}", cr, cr, 0.048, 20, "dark", "bolt_flange", (0, 0, zz), (90, 0, 0), 0.005, M_parent=M_arm, u_rep=2.0)

    # Exact manifest.json MUZZLE marker (arm_offset (0.25,0,0) + (0,0,-2.26))
    kb.add_marker("MUZZLE", (0.25, 0.0, -2.26))
