"""
Extended Arm Weapon Pack E (8 ATGM Racks, Rocket Pods, Recoilless Rifles, MICLIC & Thermobaric MLRS) — B.o.T Standard.
Canonical Right Arm (side = +1.0, strictly x >= +0.010 zero-core-clash clearance):
  1. arm_cg84     (CG84-X2 Saab Carl Gustaf M4 Twin 84mm Recoilless Rifles w/ Venturi Cones & 4-Rd Rack)
  2. arm_kornet   (9M133-X4 Kornet-EM Quad ATGM Rack w/ Rubber End-Bumpers & 1PN79M Thermal Sight)
  3. arm_lau61    (LAU-61 Hydra-70 19-Tube 70mm Rocket Pod w/ BRU Pylon, 19-Bore Face & Exhaust Cone)
  4. arm_m299     (M299-HF4 Longbow Open-Rail Quad Hellfire Launcher w/ 4 Exposed AGM-114L Missiles)
  5. arm_miclic   (M58-CLC MICLIC Open C-4 Coiled Line-Charge Tub, Elevated MK22 Rocket & ERA Shield)
  6. arm_ram116   (MK49-RAM 11-Cell Rolling Airframe Missile Box w/ 4+3+4 Bores & Twin ESM Horns)
  7. arm_rpo93    (RPO-93X4 Shmel Quad 93mm Thermobaric Pack w/ Quick-Release Bands & Open/Capped Tubes)
  8. arm_tos220   (TOS-220 Solntsepyok 6-Tube 220mm Thermobaric MLRS Box w/ Kontakt-5 ERA Roof)
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


def _arm_mount_and_pauldron(kb: KitbashScene, pfx: str, cx: float, cy: float, heavy=True, oxide_shld=False, decal_key="caution_chev"):
    kb.a1_shoulder_mount(f"{pfx}_A1", heavy=heavy)
    flg_x = max(0.55, cx - 0.17)
    kb.box(f"{pfx}_TrFlg", (0.032, 0.24, 0.28), "gunmetal", "bolt_flange", (flg_x, cy, 0.0), (0, 0, 0), 0.005, 1)
    kb.cyl(f"{pfx}_TrAxl", 0.096, 0.096, max(0.036, flg_x - 0.505), 14, "dark", "gear_collar", ((0.505 + flg_x) * 0.5, cy, 0.0), (0, 0, 90), 0.004, u_rep=2.0)
    M_sh = g2b_mat((0.33, 0.46, 0.02), (0, 0, -8.0))
    kb.plate(f"{pfx}_PldMain", trap_2d(0.74, 0.50, 0.22, 0.06), 0.24, "armor", "armor_slab", (0, 0, 0), (0, 90, 0), 0.014, 1, M_parent=M_sh)
    kb.plate(f"{pfx}_PldSub", crect_2d(0.16, 0.38, (0.03, 0.03, 0.03, 0.03)), 0.045, "armor_oxide" if oxide_shld else "armor_sub", "weld_plate",
             (0.0, 0.125, 0), (-90, 0, 0), 0.008, 1, M_parent=M_sh)
    kb.grab_rail(f"{pfx}_PldGrab", 0.18, 0.034, (-0.11, 0.04, 0), (0, 90, 90), 0.009, M_parent=M_sh)
    if decal_key:
        kb.decal(f"{pfx}_PldDec", decal_key, (0.14, 0.12), (0.0, 0.154, 0.0), (-90, 0, 0), M_parent=M_sh)


# 1. arm_cg84 — CG84-X2 Saab Carl Gustaf M4 Twin 84mm Recoilless Rifles
def build_arm_cg84(kb: KitbashScene):
    cx, cy = 0.646, -0.03
    _arm_mount_and_pauldron(kb, "CG84", cx, cy, heavy=False, oxide_shld=False, decal_key="ord_12")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # CNC twin-cradle clamp spine + Saab FCD-558 smart ballistic FCS sight
    kb.box("CradleSpine", (0.26, 0.36, 0.88), "dark", "frame_cnc", (0, 0.0, -0.22), (0, 0, 0), 0.014, 1, M_parent=M)
    kb.eoir_gimbal("SaabFCS", (-0.02, 0.28, -0.24), M_parent=M)
    # Over-under carbon-wrapped 84mm rifled tubes + flared rear Venturi backblast cones!
    for ti, ty in enumerate([0.095, -0.085]):
        kb.cyl(f"CarbonTube_{ti}", 0.068, 0.072, 1.76, 18, "armor_dark", "armor_pocket", (0, ty, -0.44), (90, 0, 0), 0.004, M_parent=M, u_rep=2.0)
        kb.cyl(f"MuzzleBumper_{ti}", 0.082, 0.076, 0.08, 18, "rubber", "dust_boot", (0, ty, -1.30), (90, 0, 0), 0.004, M_parent=M)
        kb.barrel_bore(f"Bore84_{ti}", 0.078, 0.056, (0, ty, -1.33), depth=0.07, segs=18, M_parent=M)
        # Iconic hinged rear Venturi exhaust cone
        kb.cyl(f"VenturiCone_{ti}", 0.068, 0.112, 0.28, 18, "gunmetal", "gear_collar", (0, ty, 0.56), (90, 0, 0), 0.005, hollow_r=0.052, M_parent=M)
    # Outboard 2x2 quick-reload rack holding 4 exposed 84mm MT-756 / HEAT-751 tandem rounds!
    kb.box("ReloadRack", (0.21, 0.28, 0.44), "armor_sub", "bolt_flange", (0.255, 0.0, -0.18), (0, 0, 0), 0.010, 1, M_parent=M)
    for ri, (rx, ry) in enumerate([(0.225, 0.072), (0.320, 0.072), (0.225, -0.072), (0.320, -0.072)]):
        kb.cyl(f"SpareCase_{ri}", 0.036, 0.036, 0.42, 12, "brass", "plain_metal", (rx, ry, -0.06), (90, 0, 0), 0.003, M_parent=M)
        kb.cyl(f"SpareWarhead_{ri}", 0.018, 0.038, 0.20, 12, "armor_oxide", "plain_metal", (rx, ry, -0.36), (90, 0, 0), 0.003, M_parent=M)
        kb.cyl(f"SpareProbe_{ri}", 0.006, 0.008, 0.10, 8, "copper", "plain_metal", (rx, ry, -0.50), (90, 0, 0), 0.001, M_parent=M)
    kb.add_marker("MUZZLE", (0.646, 0.065, -1.360))


# 2. arm_kornet — 9M133-X4 Kornet-EM Quad Laser-Beam-Riding ATGM Rack
def build_arm_kornet(kb: KitbashScene):
    cx, cy = 0.720, -0.03
    _arm_mount_and_pauldron(kb, "KOR", cx, cy, heavy=True, oxide_shld=True, decal_key="unit_54")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # 3 open CNC clamping frames + central elevation cradle + dorsal 1PN79M thermal/laser sight!
    kb.box("CenterHub", (0.28, 0.26, 0.78), "dark", "frame_cnc", (0, 0.0, -0.02), (0, 0, 0), 0.014, 1, M_parent=M)
    for fi, fz in enumerate([-0.58, -0.04, 0.50]):
        kb.box(f"ClampFrame_{fi}", (0.50, 0.48, 0.055), "gunmetal", "bolt_flange", (0, 0.01, fz), (0, 0, 0), 0.008, 1, M_parent=M)
    kb.eoir_gimbal("Sight1PN79M", (0, 0.36, -0.10), M_parent=M)
    # 2x2 spiraled fiberglass 9M133M-2 canisters w/ thick rubber shock end-bumpers!
    for ti, (tx, ty) in enumerate([(-0.125, 0.130), (0.125, 0.130), (-0.125, -0.110), (0.125, -0.110)]):
        kb.cyl(f"KornetTube_{ti}", 0.092, 0.092, 1.56, 16, "armor_oxide" if ti < 2 else "armor", "armor_ribs",
               (tx, ty, -0.04), (90, 0, 0), 0.005, M_parent=M, u_rep=2.0)
        for ei, ez in enumerate([-0.82, 0.74]):
            kb.cyl(f"RubberEnd_{ti}_{ei}", 0.112, 0.112, 0.085, 10, "rubber", "dust_boot", (tx, ty, ez), (90, 0, 0), 0.008, M_parent=M)
        kb.barrel_bore(f"KornetBore_{ti}", 0.094, 0.074, (tx, ty, -0.85), depth=0.07, segs=16, M_parent=M)
        kb.cyl(f"MslNose_{ti}", 0.022, 0.066, 0.12, 12, "brass", "plain_metal", (tx, ty, -0.82), (90, 0, 0), 0.003, M_parent=M)
    kb.add_marker("MUZZLE", (0.720, 0.100, -0.880))


# 3. arm_lau61 — LAU-61C/A Hydra-70 19-Tube 70mm Heavy Rocket Pod
def build_arm_lau61(kb: KitbashScene):
    cx, cy = 0.696, -0.03
    _arm_mount_and_pauldron(kb, "LAU", cx, cy, heavy=False, oxide_shld=False, decal_key="unit_08")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Dorsal NATO BRU-42 suspension pylon beam + sway braces suspending cylindrical 19-shot pod!
    kb.box("BRUPylon", (0.20, 0.14, 1.08), "dark", "frame_cnc", (0, 0.24, -0.06), (0, 0, 0), 0.012, 1, M_parent=M)
    for si, sz in enumerate([-0.38, 0.28]):
        kb.cyl(f"SuspLug_{si}", 0.036, 0.044, 0.14, 12, "chrome", "bolt_flange", (0, 0.16, sz), (0, 0, 0), 0.004, M_parent=M)
    kb.cyl("PodBody", 0.245, 0.245, 1.84, 24, "armor", "armor_panel", (0, -0.05, -0.06), (90, 0, 0), 0.012, M_parent=M, u_rep=2.0)
    kb.cyl("HazardBand", 0.249, 0.249, 0.10, 24, "hazard", "hazard", (0, -0.05, -0.78), (90, 0, 0), 0.003, M_parent=M, u_rep=2.0)
    kb.cyl("RearExhaustCone", 0.155, 0.245, 0.28, 24, "gunmetal", "weld_plate", (0, -0.05, 0.99), (90, 0, 0), 0.008, hollow_r=0.125, M_parent=M, u_rep=2.0)
    # Exact 1 + 6 + 12 = 19 concentric 70mm honeycomb bores & recessed Hydra warheads at z = -1.00!
    bores = [(0.0, 0.0)]
    for i in range(6):
        a = math.tau * i / 6.0
        bores.append((math.cos(a) * 0.088, math.sin(a) * 0.088))
    for i in range(12):
        a = math.tau * i / 12.0 + math.pi / 12.0
        bores.append((math.cos(a) * 0.176, math.sin(a) * 0.176))
    for bi, (bx, by) in enumerate(bores):
        kb.barrel_bore(f"HydraBore_{bi}", 0.036, 0.026, (bx, -0.05 + by, -0.99), depth=0.05, segs=10, M_parent=M)
        if bi % 2 == 0:
            kb.cyl(f"HydraTip_{bi}", 0.008, 0.024, 0.05, 8, "brass" if bi == 0 else "armor_oxide", "plain_metal",
                   (bx, -0.05 + by, -0.97), (90, 0, 0), 0.002, M_parent=M)
    kb.add_marker("MUZZLE", (0.696, -0.080, -1.020))


# 4. arm_m299 — M299-HF4 Longbow Open-Rail Quad Hellfire Launcher
def build_arm_m299(kb: KitbashScene):
    cx, cy = 0.700, -0.03
    _arm_mount_and_pauldron(kb, "M299", cx, cy, heavy=True, oxide_shld=False, decal_key="ord_12")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Central electronics spine + umbilical junction pods + 4 open launch rails!
    kb.box("ElectronicsSpine", (0.18, 0.34, 1.38), "dark", "frame_cnc", (0, 0.005, -0.14), (0, 0, 0), 0.014, 1, M_parent=M)
    for yi, ry in enumerate([0.158, -0.148]):
        kb.box(f"CrossArm_{yi}", (0.36, 0.065, 0.96), "gunmetal", "bolt_flange", (0, ry, -0.14), (0, 0, 0), 0.008, 1, M_parent=M)
    # 4x 100% exposed AGM-114L/R Hellfire missiles w/ glass seeker domes, warhead bands & X-fins!
    for mi, (mx, my) in enumerate([(-0.155, 0.158), (0.155, 0.158), (-0.155, -0.148), (0.155, -0.148)]):
        kb.cyl(f"AGMBody_{mi}", 0.082, 0.082, 1.48, 16, "armor_dark", "armor_panel", (mx, my, -0.22), (90, 0, 0), 0.005, M_parent=M)
        kb.cyl(f"AGMSeeker_{mi}", 0.038, 0.082, 0.15, 16, "glass", "plain_metal", (mx, my, -1.02), (90, 0, 0), 0.008, M_parent=M)
        kb.cyl(f"AGMBand_{mi}", 0.090, 0.090, 0.065, 16, "brass", "plain_metal", (mx, my, -0.72), (90, 0, 0), 0.002, M_parent=M)
        kb.cyl(f"AGMNozzle_{mi}", 0.068, 0.052, 0.08, 14, "bore", "plain_metal", (mx, my, 0.56), (90, 0, 0), 0.003, M_parent=M)
        for fi in range(2):
            fa = 45.0 + fi * 90.0
            kb.box(f"TailFin_{mi}_{fi}", (0.010, 0.22, 0.24), "gunmetal", "plain_metal", (mx, my, 0.36), (0, 0, fa), 0.002, 1, M_parent=M)
            kb.box(f"Strake_{mi}_{fi}", (0.008, 0.19, 0.38), "armor_sub", "plain_metal", (mx, my, -0.22), (0, 0, fa), 0.002, 1, M_parent=M)
    kb.add_marker("MUZZLE", (0.700, 0.128, -1.100))


# 5. arm_miclic — M58-CLC MICLIC Rocket Line-Charge & ERA Breaching Shield Arm
def build_arm_miclic(kb: KitbashScene):
    cx, cy = 0.690, -0.03
    _arm_mount_and_pauldron(kb, "MIC", cx, cy, heavy=True, oxide_shld=True, decal_key="hazard_tri")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Open armored C-4 line-charge container tub + folded bi-fold top doors + outboard ERA breaching shield!
    kb.box("ChargeTub", (0.44, 0.32, 1.66), "armor", "armor_slab", (0, -0.08, -0.22), (0, 0, 0), 0.018, 1, M_parent=M)
    for si, sx in enumerate([-0.22, 0.22]):
        kb.plate(f"OpenDoor_{si}", crect_2d(1.56, 0.20, (0.03, 0.03, 0.03, 0.03)), 0.028, "armor_sub", "armor_hatch",
                 (sx * 1.12, 0.14, -0.22), (0, 90, sx * -145.0), 0.005, 1, M_parent=M)
    for ei, ez in enumerate([-0.76, -0.22, 0.32]):
        kb.era_block(f"ShieldERA_{ei}", (0.48, 0.34, 0.065), "armor_oxide" if ei == 1 else "armor",
                     (0.275, -0.06, ez), (0, -90, 0), M_parent=M)
    # 5 coiled figure-8 loops of M58 C-4 explosive line charge inside open tub!
    for ci in range(5):
        cz = -0.78 + ci * 0.28
        kb.tube_path(f"C4Coil_{ci}", [(-0.14, 0.08, cz - 0.08), (0.14, 0.11, cz), (-0.14, 0.09, cz + 0.08)],
                     0.034, 8, "hazard" if ci % 2 == 0 else "armor_oxide", "braid_hose", add_clamps=False, M_parent=M)
    # Elevated angled gantry launch rail + 5-inch MK22 Mod 4 solid rocket w/ tip at (0, +0.365, -1.810)!
    kb.box("RearGantry", (0.12, 0.38, 0.14), "dark", "frame_cnc", (0, 0.18, 0.28), (-10, 0, 0), 0.008, 1, M_parent=M)
    kb.box("FrontGantry", (0.12, 0.34, 0.12), "dark", "frame_cnc", (0, 0.22, -0.82), (14, 0, 0), 0.008, 1, M_parent=M)
    M_rk = M @ g2b_mat((0, 0.29, -0.96), (6.0, 0, 0))
    kb.box("LaunchRail", (0.10, 0.055, 1.56), "gunmetal", "bolt_flange", (0, -0.09, 0.10), (0, 0, 0), 0.006, 1, M_parent=M_rk)
    kb.cyl("MK22Motor", 0.064, 0.064, 1.32, 16, "armor_oxide", "plain_metal", (0, 0.0, -0.04), (90, 0, 0), 0.004, M_parent=M_rk)
    kb.cyl("MK22Nose", 0.012, 0.064, 0.24, 16, "brass", "plain_metal", (0, 0.0, -0.78), (90, 0, 0), 0.003, M_parent=M_rk)
    for fi in range(2):
        kb.box(f"MK22Fin_{fi}", (0.010, 0.20, 0.20), "chrome", "plain_metal", (0, 0.0, 0.50), (0, 0, 45 + fi * 90), 0.002, 1, M_parent=M_rk)
    kb.tube_path("TowCable", [(0, 0.29, -0.32), (0, 0.16, 0.08), (0, 0.09, -0.22)], 0.018, 8, "rubber", "braid_hose", add_clamps=True, M_parent=M)
    kb.add_marker("MUZZLE", (0.690, 0.335, -1.810))


# 6. arm_ram116 — MK49-RAM 11-Cell Rolling Airframe Missile Launcher
def build_arm_ram116(kb: KitbashScene):
    cx, cy = 0.730, -0.03
    _arm_mount_and_pauldron(kb, "RAM", cx, cy, heavy=True, oxide_shld=False, decal_key="unit_17")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Chamfered octagonal naval MK49 armored launcher box + rear blow-out louver door!
    kb.plate("MK49Box", crect_2d(0.60, 0.50, (0.11, 0.11, 0.11, 0.11)), 1.56, "armor", "armor_slab", (0, 0.0, 0.02), (0, 0, 0), 0.020, 1, M_parent=M)
    kb.box("FaceRecess", (0.48, 0.38, 0.04), "dark", "bolt_flange", (0, 0.0, -0.755), (0, 0, 0), 0.006, 1, M_parent=M)
    kb.louver_bay("RearBlowout", 0.44, 0.32, 0.045, (0, 0.0, 0.81), (0, 180, 0), blades=6, M_parent=M)
    # Twin forward AN/SLQ-32 ESM RF interferometer horn antennas!
    for si, sx in enumerate([-0.24, 0.24]):
        kb.cyl(f"ESMHorn_{si}", 0.056, 0.032, 0.26, 12, "gunmetal", "gear_collar", (sx, 0.24, -0.66), (90, 0, 0), 0.004, M_parent=M)
        kb.cyl(f"ESMDome_{si}", 0.048, 0.048, 0.024, 12, "glass", "plain_metal", (sx, 0.24, -0.79), (90, 0, 0), 0.003, M_parent=M)
    # Staggered 4 + 3 + 4 = 11 RIM-116 launch cells w/ passive-RF/IR seeker tips!
    cells = [(-0.165, 0.115), (-0.055, 0.115), (0.055, 0.115), (0.165, 0.115),
             (-0.110, 0.0),   (0.0, 0.0),     (0.110, 0.0),
             (-0.165, -0.115), (-0.055, -0.115), (0.055, -0.115), (0.165, -0.115)]
    for ci, (bx, by) in enumerate(cells):
        kb.barrel_bore(f"RAMCell_{ci}", 0.048, 0.036, (bx, by, -0.77), depth=0.06, segs=12, M_parent=M)
        kb.cyl(f"RAMSeeker_{ci}", 0.010, 0.028, 0.048, 10, "chrome" if ci % 2 == 0 else "brass", "plain_metal",
               (bx, by, -0.784), (90, 0, 0), 0.002, M_parent=M)
    kb.add_marker("MUZZLE", (0.730, -0.030, -0.790))


# 7. arm_rpo93 — RPO-93X4 "Shmel-M" Quad 93mm Thermobaric Assault Pack
def build_arm_rpo93(kb: KitbashScene):
    cx, cy = 0.688, -0.03
    _arm_mount_and_pauldron(kb, "RPO", cx, cy, heavy=False, oxide_shld=True, decal_key="hazard_tri")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Open CNC cross-frame + 3 eccentric quick-release steel clamping straps + optical sight!
    kb.box("CrossCore", (0.24, 0.24, 1.12), "dark", "frame_cnc", (0, 0.0, -0.12), (0, 0, 0), 0.012, 1, M_parent=M)
    for si, sz in enumerate([-0.68, -0.14, 0.42]):
        kb.box(f"StrapBand_{si}", (0.48, 0.48, 0.048), "gunmetal", "gear_collar", (0, 0.0, sz), (0, 0, 0), 0.012, 1, M_parent=M)
        kb.box(f"LatchLever_{si}", (0.042, 0.14, 0.056), "brass", "bolt_flange", (0.255, 0.0, sz), (0, 0, 0), 0.004, 1, M_parent=M)
    kb.eoir_gimbal("ShmelOptic", (0, 0.34, -0.22), M_parent=M)
    # 2x2 93mm fiberglass tubes: upper 2 open bores w/ brass thermobaric capsules, lower 2 w/ frangible end-caps!
    for ti, (tx, ty) in enumerate([(-0.122, 0.122), (0.122, 0.122), (-0.122, -0.118), (0.122, -0.118)]):
        kb.cyl(f"ShmelTube_{ti}", 0.094, 0.094, 1.84, 16, "armor_sub", "armor_panel", (tx, ty, -0.15), (90, 0, 0), 0.006, M_parent=M, u_rep=2.0)
        kb.cyl(f"RedStripe_{ti}", 0.097, 0.097, 0.09, 16, "accent", "plain_metal", (tx, ty, -0.86), (90, 0, 0), 0.002, M_parent=M)
        kb.cyl(f"RearVentCap_{ti}", 0.104, 0.104, 0.075, 16, "rubber", "dust_boot", (tx, ty, 0.78), (90, 0, 0), 0.006, M_parent=M)
        if ti < 2:
            kb.barrel_bore(f"RPOBore_{ti}", 0.096, 0.076, (tx, ty, -1.08), depth=0.07, segs=16, M_parent=M)
            kb.cyl(f"ThermoCapsule_{ti}", 0.058, 0.072, 0.10, 14, "brass", "plain_metal", (tx, ty, -1.05), (90, 0, 0), 0.006, M_parent=M)
        else:
            kb.cyl(f"SealCap_{ti}", 0.104, 0.104, 0.065, 16, "rubber", "armor_hatch", (tx, ty, -1.08), (90, 0, 0), 0.006, M_parent=M)
    kb.add_marker("MUZZLE", (0.688, 0.092, -1.110))


# 8. arm_tos220 — TOS-220 "Solntsepyok" 6-Tube 220mm Armored Thermobaric MLRS
def build_arm_tos220(kb: KitbashScene):
    cx, cy = 0.730, -0.03
    _arm_mount_and_pauldron(kb, "TOS", cx, cy, heavy=True, oxide_shld=True, decal_key="unit_54")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Heavy rectangular armored launch container + blast-ribbed cheek plates + 5 dorsal Kontakt-5 ERA tiles!
    kb.box("LaunchBox", (0.64, 0.46, 2.34), "armor", "armor_slab", (0, 0.02, -0.22), (0, 0, 0), 0.022, 1, M_parent=M)
    kb.spaced_armor_plate("OutboardCheek", (1.68, 0.36, 0.040), "armor_sub", "armor_ribs", (0.335, 0.02, -0.22), (0, -90, 0), M_parent=M)
    for ei in range(5):
        ez = -1.06 + ei * 0.42
        kb.era_block(f"RoofERA_{ei}", (0.56, 0.36, 0.062), "armor_oxide" if ei % 2 == 1 else "armor",
                     (0, 0.28, ez), (-82, 0, 0), M_parent=M)
    kb.eoir_gimbal("TOSLaserSight", (-0.18, 0.34, -0.92), M_parent=M)
    kb.louver_bay("RearBlastDoor", 0.54, 0.34, 0.050, (0, 0.02, 0.96), (0, 180, 0), blades=6, M_parent=M)
    # 3x2 array of 6x 220mm rifled thermobaric launch bores + recessed MO.1.01.04M warhead noses!
    for ry in [0.115, -0.085]:
        for xi, rx in enumerate([-0.195, 0.0, 0.195]):
            idx = f"{0 if ry > 0 else 1}_{xi}"
            kb.barrel_bore(f"TOS220_{idx}", 0.088, 0.070, (rx, ry, -1.40), depth=0.07, segs=16, M_parent=M)
            kb.cyl(f"TOSWarhead_{idx}", 0.036, 0.066, 0.11, 14, "armor_oxide" if xi == 1 else "brass", "plain_metal",
                   (rx, ry, -1.37), (90, 0, 0), 0.005, M_parent=M)
    kb.add_marker("MUZZLE", (0.730, -0.010, -1.430))
