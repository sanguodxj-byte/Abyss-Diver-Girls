"""B-40 (gen_cell) High-Precision Armored LiFePO4 Battery Bank — MECH_MODELING_STANDARD v1.0."""
from kitbash_lib import KitbashScene, g2b_mat, crect_2d


def build_gen_cell(kb: KitbashScene):
    # Origin (0,0,0) = HP-G1 mating face; +Z points rearward out of core back!
    # 1. Unified HP-G1 Mounting Bulkhead Plate + 4 Chrome Locking Pins & Amber Collars
    kb.plate("G1Plate", crect_2d(0.82, 0.66, (0.10, 0.10, 0.10, 0.10)), 0.11, "dark", "bolt_flange", (0, 0, 0.058), (0, 0, 0), 0.012, 1)
    for ci, (cx, cy) in enumerate([(-0.32, -0.24), (0.32, -0.24), (-0.32, 0.24), (0.32, 0.24)]):
        kb.cyl(f"LockPin_{ci}", 0.032, 0.034, 0.058, 10, "chrome", "plain_metal", (cx, cy, 0.128), (90, 0, 0), 0.004)
        kb.cyl(f"LockRing_{ci}", 0.048, 0.048, 0.018, 12, "accent", "gear_collar", (cx, cy, 0.162), (90, 0, 0), 0.003)

    # All battery bank assemblies sit on Back plane (z = +0.11)
    M_b = g2b_mat((0.0, 0.0, 0.11), (0, 0, 0))

    # 2. Armored Shock-Mounted Cabinet Frame + Spaced Side Armor Shields + Side Grab Irons
    kb.box("CabinetCore", (0.76, 0.58, 0.36), "armor_sub", "frame_cnc", (0, 0, 0.18), (0, 0, 0), 0.016, 1, M_parent=M_b)
    kb.box("CabinetTopCap", (0.78, 0.055, 0.38), "armor", "armor_ribs", (0, 0.295, 0.19), (0, 0, 0), 0.010, 1, M_parent=M_b)
    kb.box("CabinetHazard", (0.68, 0.038, 0.022), "hazard", "hazard", (0, 0.295, 0.385), (0, 0, 0), 0.003, 1, M_parent=M_b)
    for sxi, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"SideShield_{sxi}", crect_2d(0.38, 0.60, (0.0, 0.08, 0.08, 0.0)), 0.055, "armor", "armor_panel",
                 (sx * 0.395, 0, 0.19), (0, 90, 0), 0.010, 1, M_parent=M_b)
        kb.grab_rail(f"SideGrab_{sxi}", 0.22, 0.040, (sx * 0.425, 0.16, 0.19), (0, -sx * 90.0, 0), 0.010, M_parent=M_b)
        for bi, by in enumerate([-0.20, 0.0, 0.20]):
            kb.cyl(f"SideBolt_{sxi}_{bi}", 0.010, 0.012, 0.016, 6, "chrome", "plain_metal",
                   (sx * 0.428, by, 0.32), (0, 0, 90), 0.002, M_parent=M_b)

    # 3. 6 Heavy Cylindrical LiFePO4 Cell Modules + Machined Collar Rings + Positive/Negative Terminals
    for i in range(3):
        for j in range(2):
            cx, cy, cz = -0.22 + i * 0.22, 0.13 - j * 0.26, 0.22
            kb.cyl(f"Cell_{i}_{j}", 0.092, 0.092, 0.32, 16, "gunmetal", "armor_ribs", (cx, cy, cz), (90, 0, 0), 0.006, M_parent=M_b)
            kb.cyl(f"CellRing_{i}_{j}", 0.099, 0.099, 0.032, 16, "dark", "gear_collar", (cx, cy, cz + 0.12), (90, 0, 0), 0.004, M_parent=M_b)
            kb.cyl(f"CellCap_{i}_{j}", 0.072, 0.082, 0.020, 14, "armor_dark", "plain_metal", (cx, cy, cz + 0.162), (90, 0, 0), 0.003, M_parent=M_b)
            # Positive (red/copper) & Negative (black/copper) insulated terminal studs
            for ti, tx in enumerate([-0.036, 0.036]):
                boot_mat = "emit_red" if tx > 0 else "rubber"
                kb.cyl(f"TermBoot_{i}_{j}_{ti}", 0.018, 0.020, 0.028, 10, boot_mat, "plain_metal", (cx + tx, cy, cz + 0.175), (90, 0, 0), 0.003, M_parent=M_b)
                kb.cyl(f"TermPost_{i}_{j}_{ti}", 0.011, 0.011, 0.044, 8, "copper", "plain_metal", (cx + tx, cy, cz + 0.186), (90, 0, 0), 0.002, M_parent=M_b)

    # 4. Solid Copper Horizontal Busbar Rails + Steel Clamp Straps
    for ri, ry in enumerate([0.13, -0.13]):
        kb.box(f"CopperBus_{ri}", (0.52, 0.024, 0.014), "copper", "plain_metal", (0, ry + 0.036, 0.402), (0, 0, 0), 0.003, 1, M_parent=M_b)
        kb.box(f"ClampBar_{ri}", (0.68, 0.032, 0.024), "dark", "bolt_flange", (0, ry, 0.388), (0, 0, 0), 0.004, 1, M_parent=M_b)

    # 5. Central Explosion-Proof Main Cutoff Switch Box + Recessed 4-Segment Charge Meter
    kb.box("BreakerBox", (0.25, 0.105, 0.064), "armor", "armor_pocket", (0, 0, 0.39), (0, 0, 0), 0.008, 1, M_parent=M_b)
    kb.cyl("CutoffDial", 0.028, 0.030, 0.028, 12, "emit_red", "gear_collar", (-0.06, 0, 0.426), (90, 0, 0), 0.003, M_parent=M_b)
    kb.box("CutoffHandle", (0.080, 0.015, 0.018), "chrome", "plain_metal", (-0.06, 0, 0.440), (0, 0, 35), 0.003, 1, M_parent=M_b)
    kb.box("MeterRecess", (0.105, 0.034, 0.016), "bore", "plain_metal", (0.052, 0, 0.422), (0, 0, 0), 0.003, 1, M_parent=M_b)
    for seg in range(4):
        kb.box(f"ChargeSeg_{seg}", (0.016, 0.019, 0.010), "emit_core", "plain_metal", (0.018 + seg * 0.022, 0, 0.427), (0, 0, 0), 0.002, 1, M_parent=M_b)

    # 6. Lower Forced-Air Cooling Bay + Armored HV Output Cables
    kb.louver_bay("LowerCoolVent", 0.52, 0.085, 0.034, (0, -0.255, 0.365), (0, 180, 0), blades=4, mesh_style=True, M_parent=M_b)
    kb.tube_path("HV_Cable_Pos", [(-0.32, -0.24, 0.02), (-0.28, -0.32, 0.20), (-0.18, -0.27, 0.36)], 0.024, 8, "copper", "braid_hose", M_parent=M_b)
    kb.tube_path("HV_Cable_Neg", [(0.32, -0.24, 0.02), (0.28, -0.32, 0.20), (0.18, -0.27, 0.36)], 0.024, 8, "gunmetal", "braid_hose", M_parent=M_b)

    # Subtle glowing indicator light marker (matches gen_cell.gd line 53)
    kb.add_marker("LIGHT_core", (0.05, 0.0, 0.63))
