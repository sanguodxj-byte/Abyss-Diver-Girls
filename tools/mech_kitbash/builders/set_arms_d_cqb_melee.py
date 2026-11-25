"""
Extended Arm Weapon Pack D (10 CQB Shotguns, Quad AA Pods, CIWS, Flamethrower & Siege Melee) — B.o.T Standard.
Canonical Right Arm (side = +1.0, strictly x >= +0.010 zero-core-clash clearance):
  1. arm_aa12     (AA-12 40mm Auto-Shotgun w/ 20-Rd Ventral Drum, Tactical Floodlight & Breaching Crown)
  2. arm_ks60     (KS-60 60mm Heavy Riot Pump Shotgun w/ Full Tube Mag, Twin-Rod Forend & 5-Shell Saddle)
  3. arm_m45      (M45 Maxson Quadmount AA Pod w/ Armor Shield, 2x2 Perforated Barrels & 4 Tombstone Chests)
  4. arm_mk108    (MK 108-4X Quad 30mm Heavy Assault Pod w/ Twin Pneumatic Bottles & Sloped Mantlet)
  5. arm_phalanx  (MK15-20 Phalanx Block 1B CIWS w/ Tall Radome, HDTI FLIR Gimbal, Helical Drum & 6-Bbl M61A2)
  6. arm_m10flm   (M10-FLM Zippo High-Pressure Napalm Projector w/ Twin Ventral Tanks, Hoses & 6-Rod Igniter Cage)
  7. arm_cs88     (CS-88 Vermeer Tungsten-Carbide Armored Chainsaw w/ Radial Motor & 24-Tooth Cutter Chain)
  8. arm_hc40     (HC-40 Genesis Hydraulic Eagle-Beak Demolition Shear w/ 360 Wrist, Dual Rams & Chrome Blades)
  9. arm_pb09     (PB-09 Pyrotechnic-Hydraulic Siege Pile Bunker w/ 6-Chamber Revolver Drum & Tungsten Spike)
 10. arm_th60     (TH-60 Krupp HB-7000 Boxed Hydraulic Rock-Breaker w/ 4 Tie-Rods, N2 Dome & Chisel Moil)
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


# 1. arm_aa12 — AA-12 40mm Automatic Combat Shotgun
def build_arm_aa12(kb: KitbashScene):
    cx, cy = 0.646, -0.03
    _arm_mount_and_pauldron(kb, "AA12", cx, cy, heavy=False, oxide_shld=False, decal_key="unit_17")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Iconic AA-12 slab-sided constant-recoil polymer/stainless monolithic receiver
    kb.box("SlabRec", (0.30, 0.34, 1.18), "armor", "armor_slab", (0, 0.02, -0.22), (0, 0, 0), 0.016, 1, M_parent=M)
    kb.box("TopSightCarry", (0.14, 0.11, 0.78), "dark", "frame_cnc", (0, 0.23, -0.24), (0, 0, 0), 0.010, 1, M_parent=M)
    kb.box("ReflexGlass", (0.09, 0.055, 0.020), "glass", "plain_metal", (0, 0.25, -0.60), (0, 0, 0), 0.002, 1, M_parent=M)
    # Massive 20-round ventral drum magazine w/ front winder & bolt ring
    kb.cyl("DrumMag20", 0.23, 0.23, 0.30, 22, "armor_oxide", "armor_hatch", (0, -0.27, -0.24), (90, 0, 0), 0.012, M_parent=M, u_rep=2.0)
    kb.bolt_ring("DrumBolts", 0.16, 8, 0.010, (0, -0.27, -0.395), (90, 0, 0), M_parent=M)
    kb.box("DrumWinder", (0.18, 0.038, 0.036), "brass", "bolt_flange", (0, -0.27, -0.405), (0, 0, 28), 0.004, 1, M_parent=M)
    # Ribbed forend + recessed tactical floodlight + heavy 40mm barrel + toothed door-breaching choke!
    kb.box("ForendGrip", (0.26, 0.22, 0.56), "rubber", "armor_ribs", (0, -0.02, -1.04), (0, 0, 0), 0.014, 1, M_parent=M)
    kb.headlight_cage("TacLight", (0, -0.10, -1.34), (0, 0, 0), M_parent=M)
    kb.louver_bay("ShellEject", 0.26, 0.11, 0.028, (0.154, 0.06, -0.22), (0, -90, 0), blades=4, M_parent=M)
    kb.cyl("Barrel40", 0.048, 0.054, 0.92, 16, "gunmetal", "plain_metal", (0, 0.04, -1.24), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("BreachCrown", 0.064, 0.056, 0.14, 16, "dark", "gear_collar", (0, 0.04, -1.68), (90, 0, 0), 0.004, M_parent=M)
    for ti in range(6):
        ta = math.tau * ti / 6.0
        kb.box(f"CrownTooth_{ti}", (0.016, 0.016, 0.044), "chrome", "plain_metal",
               (math.cos(ta) * 0.054, 0.04 + math.sin(ta) * 0.054, -1.755), (0, 0, -math.degrees(ta)), 0.002, 1, M_parent=M)
    kb.barrel_bore("Bore40", 0.056, 0.038, (0, 0.04, -1.74), depth=0.06, segs=16, M_parent=M)
    kb.add_marker("MUZZLE", (0.646, 0.010, -1.770))


# 2. arm_ks60 — KS-60 60mm Heavy Riot Pump-Action Shotgun
def build_arm_ks60(kb: KitbashScene):
    cx, cy = 0.636, -0.03
    _arm_mount_and_pauldron(kb, "KS60", cx, cy, heavy=False, oxide_shld=True, decal_key="ord_12")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Milled steel KS-23M oversized riot receiver + top Picatinny rail + ghost-ring sight
    kb.plate("KSRec", crect_2d(0.86, 0.34, (0.08, 0.05, 0.04, 0.04)), 0.30, "armor_dark", "armor_slab", (0, 0.01, -0.08), (0, 90, 0), 0.016, 1, M_parent=M)
    kb.box("TopRail", (0.08, 0.030, 0.68), "dark", "armor_ribs", (0, 0.195, -0.10), (0, 0, 0), 0.004, 1, M_parent=M)
    # Outboard 5-shell quick-reload saddle rack w/ brass bases & oxide hulls!
    kb.box("SaddlePlate", (0.030, 0.18, 0.48), "gunmetal", "bolt_flange", (0.165, 0.01, -0.10), (0, 0, 0), 0.004, 1, M_parent=M)
    for si in range(5):
        sz = -0.28 + si * 0.09
        kb.cyl(f"ShellHull_{si}", 0.032, 0.032, 0.13, 12, "armor_oxide", "plain_metal", (0.205, 0.01, sz), (0, 0, 0), 0.003, M_parent=M)
        kb.cyl(f"ShellBrass_{si}", 0.035, 0.035, 0.045, 12, "brass", "gear_collar", (0.205, -0.065, sz), (0, 0, 0), 0.002, M_parent=M)
    # Top heavy rifled 60mm barrel + full-length underbarrel tubular magazine + figure-8 clamps + hydraulic pump!
    kb.cyl("RifledBbl60", 0.054, 0.062, 1.42, 18, "gunmetal", "plain_metal", (0, 0.06, -1.16), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("TubeMag60", 0.048, 0.048, 1.24, 16, "armor_sub", "armor_panel", (0, -0.065, -1.08), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("MagEndCap", 0.054, 0.052, 0.06, 16, "brass", "gear_collar", (0, -0.065, -1.72), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("PumpForend", 0.072, 0.072, 0.46, 16, "rubber", "dust_boot", (0, -0.065, -0.96), (90, 0, 0), 0.006, M_parent=M, u_rep=2.0)
    for sx in [-0.078, 0.078]:
        kb.cyl(f"ActionBar_{1 if sx > 0 else 0}", 0.012, 0.012, 0.56, 8, "chrome", "plain_metal", (sx, -0.05, -0.68), (90, 0, 0), 0.002, M_parent=M)
    for ci, cz in enumerate([-1.36, -1.64]):
        kb.box(f"Fig8Clamp_{ci}", (0.12, 0.25, 0.042), "dark", "bolt_flange", (0, -0.002, cz), (0, 0, 0), 0.006, 1, M_parent=M)
    kb.barrel_bore("Bore60", 0.060, 0.044, (0, 0.06, -1.89), depth=0.07, segs=18, M_parent=M)
    kb.add_marker("MUZZLE", (0.636, 0.030, -1.920))


# 3. arm_m45 — M45 Maxson Quadmount Heavy AA Turret
def build_arm_m45(kb: KitbashScene):
    cx, cy = 0.700, -0.03
    _arm_mount_and_pauldron(kb, "M45", cx, cy, heavy=True, oxide_shld=False, decal_key="unit_54")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Central Kraemer electric trunnion cradle + sloped armored AA gun shield
    kb.box("QuadCradle", (0.42, 0.40, 0.78), "dark", "frame_cnc", (0, 0.02, 0.04), (0, 0, 0), 0.016, 1, M_parent=M)
    kb.spaced_armor_plate("GunShield", (0.58, 0.48, 0.045), "armor", "armor_slab", (0, 0.08, -0.42), (-16, 0, 0), M_parent=M)
    kb.eoir_gimbal("ReflexRadarSight", (0, 0.34, -0.08), M_parent=M)
    # 4x M2 "Tombstone" side ammo chests + 2x2 quad perforated-jacket heavy .50/20mm barrels!
    for si, sx in enumerate([-0.295, 0.295]):
        for yi, by in enumerate([0.125, -0.105]):
            kb.box(f"TombChest_{si}_{yi}", (0.11, 0.20, 0.38), "armor_oxide" if yi == 0 else "armor_sub", "armor_hatch",
                   (sx, by, -0.05), (0, 0, 0), 0.010, 1, M_parent=M)
    coords = [(-0.115, 0.105), (0.115, 0.105), (-0.115, -0.055), (0.115, -0.055)]
    for bi, (bx, by) in enumerate(coords):
        kb.cyl(f"PerfJacket_{bi}", 0.042, 0.046, 0.64, 12, "dark", "vent_mesh", (bx, by, -0.74), (90, 0, 0), 0.004, M_parent=M, u_rep=2.0)
        kb.cyl(f"HeavyBbl_{bi}", 0.026, 0.032, 0.86, 12, "gunmetal", "plain_metal", (bx, by, -1.46), (90, 0, 0), 0.003, M_parent=M)
        kb.barrel_bore(f"QuadBore_{bi}", 0.036, 0.020, (bx, by, -1.91), depth=0.06, segs=12, M_parent=M)
    # Front X-brace barrel alignment spider
    kb.box("BraceH", (0.28, 0.028, 0.036), "gunmetal", "bolt_flange", (0, 0.025, -1.58), (0, 0, 0), 0.004, 1, M_parent=M)
    kb.box("BraceV", (0.032, 0.22, 0.036), "gunmetal", "bolt_flange", (0, 0.025, -1.58), (0, 0, 0), 0.004, 1, M_parent=M)
    kb.add_marker("MUZZLE", (0.700, 0.075, -1.950))


# 4. arm_mk108 — Rheinmetall MK 108-4X Quad 30mm Heavy Assault Pod
def build_arm_mk108(kb: KitbashScene):
    cx, cy = 0.700, -0.03
    _arm_mount_and_pauldron(kb, "MK108", cx, cy, heavy=True, oxide_shld=True, decal_key="hazard_tri")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Heavy boxed 4-gun breech cassette + sloped forward blast mantlet
    kb.box("PodCassette", (0.44, 0.42, 0.92), "armor", "armor_slab", (0, 0.01, 0.02), (0, 0, 0), 0.020, 1, M_parent=M)
    kb.plate("BlastMantlet", trap_2d(0.46, 0.36, 0.40, 0.05), 0.22, "armor_sub", "weld_plate", (0, 0.01, -0.52), (24, 0, 0), 0.014, 1, M_parent=M)
    kb.louver_bay("LinkChute", 0.36, 0.14, 0.034, (0, -0.215, 0.04), (-90, 0, 0), blades=5, M_parent=M)
    # Iconic twin dorsal compressed-air pneumatic charging bottles + copper air lines!
    for si, sx in enumerate([-0.11, 0.11]):
        kb.cyl(f"AirBottle_{si}", 0.072, 0.072, 0.58, 16, "armor_oxide" if si == 0 else "brass", "armor_panel",
               (sx, 0.28, 0.04), (90, 0, 0), 0.012, M_parent=M)
        kb.tube_path(f"AirPipe_{si}", [(sx, 0.28, -0.25), (sx * 1.3, 0.22, -0.36), (sx * 0.9, 0.14, -0.44)],
                     0.014, 8, "copper", "plain_metal", add_clamps=True, M_parent=M)
    # 2x2 stubby big-bore 30mm Mine-Shell barrels w/ conical blast dampers
    for bi, (bx, by) in enumerate([(-0.10, 0.085), (0.10, 0.085), (-0.10, -0.065), (0.10, -0.065)]):
        kb.cyl(f"Bbl30_{bi}", 0.040, 0.048, 0.88, 14, "gunmetal", "plain_metal", (bx, by, -1.04), (90, 0, 0), 0.004, M_parent=M)
        kb.cyl(f"ConeDamper_{bi}", 0.056, 0.042, 0.12, 14, "dark", "gear_collar", (bx, by, -1.46), (90, 0, 0), 0.004, M_parent=M)
        kb.barrel_bore(f"BoreMK_{bi}", 0.052, 0.032, (bx, by, -1.52), depth=0.06, segs=14, M_parent=M)
    kb.add_marker("MUZZLE", (0.700, -0.020, -1.550))


# 5. arm_phalanx — MK15-20 Phalanx Block 1B Close-In Weapon System
def build_arm_phalanx(kb: KitbashScene):
    cx, cy = 0.690, -0.03
    _arm_mount_and_pauldron(kb, "CIWS", cx, cy, heavy=True, oxide_shld=False, decal_key="unit_08")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Gun mount cradle + ventral 1,550-round helical ammunition drum + Block 1B side HDTI FLIR gimbal!
    kb.box("CIWSCradle", (0.40, 0.34, 0.82), "armor_sub", "armor_slab", (0, -0.02, 0.02), (0, 0, 0), 0.018, 1, M_parent=M)
    kb.cyl("HelicalDrum", 0.22, 0.22, 0.68, 20, "gunmetal", "armor_hatch", (0, -0.28, 0.04), (90, 0, 0), 0.012, M_parent=M, u_rep=2.0)
    kb.bolt_ring("DrumFrontBolts", 0.16, 8, 0.010, (0, -0.28, -0.305), (90, 0, 0), M_parent=M)
    kb.eoir_gimbal("Block1B_FLIR", (0.25, 0.22, -0.10), M_parent=M)
    # Iconic tall cylindrical + hemispherical Ku-band search/track radome ("R2-D2" silhouette!)
    rad_prof = [(0.0, -0.30), (0.23, -0.30), (0.24, -0.28), (0.24, 0.12)]
    for hi in range(1, 7):
        ang = (math.pi * 0.5) * (hi / 6.0)
        rad_prof.append((math.cos(ang) * 0.24, 0.12 + math.sin(ang) * 0.23))
    kb.lathe("KuRadome", rad_prof, 22, "armor", "armor_panel", (0, 0.49, 0.02), (0, 0, 0), M_parent=M, u_rep=2.0)
    kb.cyl("RadomeCollar", 0.255, 0.260, 0.065, 22, "dark", "bolt_flange", (0, 0.175, 0.02), (0, 0, 0), 0.005, M_parent=M, u_rep=2.0)
    # 6-barrel M61A2 20mm Gatling cluster + mid/muzzle spider clamps!
    kb.cyl("GatlingDrive", 0.135, 0.145, 0.36, 18, "dark", "gear_collar", (0, -0.02, -0.54), (90, 0, 0), 0.006, M_parent=M, u_rep=2.0)
    for bi in range(6):
        ba = math.tau * bi / 6.0
        bx, by = math.cos(ba) * 0.066, -0.02 + math.sin(ba) * 0.066
        kb.cyl(f"M61Bbl_{bi}", 0.018, 0.021, 1.32, 10, "gunmetal", "plain_metal", (bx, by, -1.34), (90, 0, 0), 0.002, M_parent=M)
    for ci, cz in enumerate([-1.05, -1.52, -1.92]):
        kb.cyl(f"BblClamp_{ci}", 0.098, 0.098, 0.042, 18, "dark", "bolt_flange", (0, -0.02, cz), (90, 0, 0), 0.004, M_parent=M)
    kb.barrel_bore("GatMuzzle", 0.096, 0.068, (0, -0.02, -1.99), depth=0.06, segs=18, M_parent=M)
    kb.add_marker("MUZZLE", (0.690, -0.050, -2.020))


# 6. arm_m10flm — M10-FLM "Zippo" High-Pressure Armored Napalm Projector
def build_arm_m10flm(kb: KitbashScene):
    cx, cy = 0.670, -0.03
    _arm_mount_and_pauldron(kb, "FLM", cx, cy, heavy=True, oxide_shld=True, decal_key="hazard_tri")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Armored valve manifold + ventral side-by-side Napalm fuel tank & high-pressure N2 cylinder!
    kb.box("ValveManifold", (0.38, 0.32, 0.86), "armor", "armor_slab", (0, 0.04, -0.04), (0, 0, 0), 0.016, 1, M_parent=M)
    kb.cyl("NapalmTank", 0.135, 0.135, 0.92, 18, "armor_oxide", "weld_plate", (0.11, -0.24, -0.06), (90, 0, 0), 0.016, M_parent=M, u_rep=2.0)
    kb.cyl("HazardBand", 0.139, 0.139, 0.12, 18, "hazard", "hazard", (0.11, -0.24, -0.28), (90, 0, 0), 0.003, M_parent=M, u_rep=2.0)
    kb.cyl("NitrogenTank", 0.098, 0.098, 0.86, 16, "gunmetal", "armor_panel", (-0.12, -0.22, -0.06), (90, 0, 0), 0.014, M_parent=M)
    kb.cyl("RegulatorBrass", 0.052, 0.058, 0.10, 12, "brass", "gear_collar", (-0.12, -0.22, -0.52), (90, 0, 0), 0.004, M_parent=M)
    for si, (sx, sy) in enumerate([(0.11, -0.24), (-0.12, -0.22)]):
        kb.tube_path(f"FeedHose_{si}", [(sx, sy, -0.52), (sx * 1.25, -0.10, -0.68), (sx * 0.45, 0.02, -0.82)],
                     0.022, 8, "gunmetal", "braid_hose", add_clamps=True, M_parent=M)
    # Perforated thermal shroud + projector nozzle + copper piezo igniter + 6-rod anti-impact flame cage!
    kb.cyl("ThermalShroud", 0.088, 0.094, 0.98, 16, "dark", "vent_mesh", (0, 0.04, -0.96), (90, 0, 0), 0.006, M_parent=M, u_rep=2.0)
    kb.cyl("NozzlePipe", 0.046, 0.056, 0.72, 16, "gunmetal", "plain_metal", (0, 0.04, -1.76), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("IgniterTip", 0.016, 0.022, 0.24, 10, "copper", "plain_metal", (0, -0.035, -2.02), (90, 0, 0), 0.002, M_parent=M)
    kb.cyl("PilotFlame", 0.014, 0.014, 0.03, 10, "emit_amber", "plain_metal", (0, -0.035, -2.14), (90, 0, 0), 0.002, M_parent=M)
    for ri in range(6):
        ra = math.tau * ri / 6.0
        kb.cyl(f"CageRod_{ri}", 0.010, 0.010, 0.44, 8, "chrome", "plain_metal",
               (math.cos(ra) * 0.098, 0.04 + math.sin(ra) * 0.098, -1.94), (90, 0, 0), 0.002, M_parent=M)
    kb.cyl("CageFrontRing", 0.106, 0.106, 0.028, 16, "dark", "bolt_flange", (0, 0.04, -2.14), (90, 0, 0), 0.003, hollow_r=0.082, M_parent=M)
    kb.barrel_bore("BoreFLM", 0.054, 0.036, (0, 0.04, -2.14), depth=0.06, segs=14, M_parent=M)
    kb.add_marker("MUZZLE", (0.670, 0.010, -2.180))


# 7. arm_cs88 — CS-88 Vermeer Tungsten-Carbide Armored Trencher Chainsaw
def build_arm_cs88(kb: KitbashScene):
    cx, cy = 0.670, -0.03
    _arm_mount_and_pauldron(kb, "CS88", cx, cy, heavy=True, oxide_shld=False, decal_key="caution_chev")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Massive radial hydraulic motor housing + hazard chip-guard hood + dual hydraulic hoses
    kb.box("MotorGearbox", (0.36, 0.40, 0.68), "armor_sub", "frame_cnc", (0, 0.0, 0.04), (0, 0, 0), 0.016, 1, M_parent=M)
    kb.actuator_drum("RadialMotor", (0.20, -0.02, -0.08), 0.20, 0.22, M_parent=M)
    kb.plate("ChipHood", trap_2d(0.76, 0.62, 0.18, 0.04), 0.22, "hazard", "hazard", (0, 0.22, -0.48), (0, 90, 0), 0.010, 1, M_parent=M)
    kb.tube_path("HydSupply", [(0.16, 0.16, 0.34), (0.24, 0.12, 0.10), (0.20, 0.04, -0.10)], 0.022, 8, "gunmetal", "braid_hose", add_clamps=True, M_parent=M)
    # 1.65m bolted manganese-steel guide bar + nose sprocket + 22 tungsten-carbide conical cutter teeth!
    kb.box("GuideBar", (0.068, 0.32, 1.66), "gunmetal", "weld_plate", (0, -0.01, -1.16), (0, 0, 0), 0.008, 1, M_parent=M)
    kb.cyl("NoseSprocket", 0.165, 0.165, 0.066, 20, "gunmetal", "bolt_flange", (0, -0.01, -1.99), (0, 0, 90), 0.006, M_parent=M)
    kb.bolt_ring("BarBolts", 0.10, 8, 0.010, (0.038, -0.01, -1.99), (0, 0, 90), M_parent=M)
    # Top & bottom straight cutter runs
    for ti in range(8):
        tz = -0.48 - ti * 0.20
        kb.box(f"TopLink_{ti}", (0.088, 0.042, 0.11), "dark", "gear_collar", (0, 0.165, tz), (0, 0, 0), 0.004, 1, M_parent=M)
        kb.cyl(f"TopTooth_{ti}", 0.008, 0.028, 0.11, 8, "chrome", "plain_metal", (0, 0.215, tz - 0.03), (52, 0, 0), 0.002, M_parent=M)
        kb.box(f"BotLink_{ti}", (0.088, 0.042, 0.11), "dark", "gear_collar", (0, -0.185, tz), (0, 0, 0), 0.004, 1, M_parent=M)
        kb.cyl(f"BotTooth_{ti}", 0.008, 0.028, 0.11, 8, "chrome", "plain_metal", (0, -0.235, tz + 0.03), (-128, 0, 0), 0.002, M_parent=M)
    # Nose arc cutter teeth reaching z = -2.29
    for ai in range(6):
        ang = -math.pi * 0.42 + (math.pi * 0.84) * (ai / 5.0)
        ty = -0.01 + math.sin(ang) * 0.205
        tz = -1.99 - math.cos(ang) * 0.205
        ty_t = -0.01 + math.sin(ang) * 0.265
        tz_t = -1.99 - math.cos(ang) * 0.265
        kb.box(f"NoseLink_{ai}", (0.088, 0.046, 0.085), "dark", "gear_collar", (0, ty, tz), (math.degrees(ang), 0, 0), 0.004, 1, M_parent=M)
        kb.cyl(f"NoseTooth_{ai}", 0.008, 0.030, 0.115, 8, "chrome", "plain_metal", (0, ty_t, tz_t), (90 + math.degrees(ang) - 25, 0, 0), 0.002, M_parent=M)
    kb.add_marker("MUZZLE", (0.670, -0.040, -2.290))


# 8. arm_hc40 — HC-40 Genesis Hydraulic Eagle-Beak Demolition Shear
def build_arm_hc40(kb: KitbashScene):
    cx, cy = 0.680, -0.03
    _arm_mount_and_pauldron(kb, "HC40", cx, cy, heavy=True, oxide_shld=True, decal_key="lift_cg")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # 360-degree brass/gunmetal planetary wrist rotator + heavy boxed pivot chassis
    kb.cyl("WristSlewing", 0.22, 0.23, 0.24, 22, "brass", "gear_collar", (0, 0, 0.10), (90, 0, 0), 0.008, M_parent=M, u_rep=2.0)
    kb.bolt_ring("WristBolts", 0.19, 10, 0.010, (0, 0, -0.025), (90, 0, 0), M_parent=M)
    kb.box("ShearChassis", (0.36, 0.42, 0.94), "armor_oxide", "armor_slab", (0, 0, -0.50), (0, 0, 0), 0.018, 1, M_parent=M)
    kb.actuator_drum("MainJawPivot", (0, 0.0, -0.98), 0.18, 0.42, M_parent=M)
    # Upper & lower high-pressure hydraulic rams driving the eagle-beak jaws!
    kb.hydraulic("UpperRam", (0, 0.26, -0.18), (0, 0.30, -1.24), 0.032, M_parent=M)
    kb.hydraulic("LowerRam", (0, -0.26, -0.18), (0, -0.28, -1.20), 0.028, M_parent=M)
    # Hooked Eagle-Beak upper piercing jaw & lower anvil jaw + replaceable chrome straight shear blades!
    up_pts = [(-0.52, -0.02), (0.50, 0.04), (0.42, 0.28), (-0.18, 0.26), (-0.54, 0.06)]
    dn_pts = [(-0.50, -0.04), (0.48, -0.06), (0.40, -0.26), (-0.22, -0.24), (-0.52, -0.10)]
    kb.plate("UpperEagleJaw", up_pts, 0.15, "armor", "weld_plate", (0, 0.04, -1.52), (0, 90, 0), 0.014, 1, M_parent=M)
    kb.plate("LowerAnvilJaw", dn_pts, 0.18, "armor_sub", "armor_slab", (0, -0.04, -1.50), (0, 90, 0), 0.014, 1, M_parent=M)
    kb.box("ChromeBladeUp", (0.042, 0.068, 0.56), "chrome", "plain_metal", (0.058, 0.045, -1.46), (-6, 0, 0), 0.004, 1, M_parent=M)
    kb.box("ChromeBladeDn", (0.042, 0.068, 0.56), "chrome", "plain_metal", (-0.058, -0.045, -1.46), (6, 0, 0), 0.004, 1, M_parent=M)
    kb.box("PiercingFang", (0.12, 0.14, 0.16), "chrome", "plain_metal", (0, 0.01, -2.01), (22, 0, 0), 0.006, 1, M_parent=M)
    kb.add_marker("MUZZLE", (0.680, -0.030, -2.080))


# 9. arm_pb09 — PB-09 Pyrotechnic-Hydraulic Siege Pile Bunker
def build_arm_pb09(kb: KitbashScene):
    cx, cy = 0.690, -0.03
    _arm_mount_and_pauldron(kb, "PB09", cx, cy, heavy=True, oxide_shld=False, decal_key="unit_54")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Massive 6-chamber pyrotechnic blank-cartridge revolver breech drum + heavy I-beam slide bed!
    kb.cyl("PyroDrum", 0.24, 0.24, 0.44, 22, "armor_dark", "armor_hatch", (0, 0.02, 0.24), (90, 0, 0), 0.012, M_parent=M, u_rep=2.0)
    for ci in range(6):
        ca = math.tau * ci / 6.0
        cx_c, cy_c = math.cos(ca) * 0.145, 0.02 + math.sin(ca) * 0.145
        kb.cyl(f"BlankCart_{ci}", 0.044, 0.044, 0.48, 12, "brass", "plain_metal", (cx_c, cy_c, 0.24), (90, 0, 0), 0.004, M_parent=M)
    kb.box("SlideIBeam", (0.38, 0.30, 1.76), "dark", "frame_cnc", (0, -0.02, -0.84), (0, 0, 0), 0.016, 1, M_parent=M)
    kb.box("TopRamCarriage", (0.28, 0.18, 0.88), "armor", "armor_slab", (0, 0.18, -0.52), (0, 0, 0), 0.014, 1, M_parent=M)
    for si, sx in enumerate([-0.21, 0.21]):
        kb.hydraulic(f"ReturnDamper_{si}", (sx, 0.02, -0.10), (sx, 0.02, -1.62), 0.030, M_parent=M)
    # Spiked breaching stand-off anvil + solid chrome tungsten-carbide armor-piercing spike!
    kb.box("BreachAnvil", (0.44, 0.38, 0.14), "hazard", "hazard", (0, -0.01, -1.74), (0, 0, 0), 0.010, 1, M_parent=M)
    kb.cyl("SpikeCollar", 0.105, 0.120, 0.24, 16, "gunmetal", "gear_collar", (0, -0.01, -1.88), (90, 0, 0), 0.006, M_parent=M)
    kb.cyl("TungstenShaft", 0.068, 0.078, 0.56, 8, "chrome", "plain_metal", (0, -0.01, -2.24), (90, 0, 0), 0.005, M_parent=M)
    kb.cyl("TungstenPoint", 0.008, 0.068, 0.24, 8, "chrome", "plain_metal", (0, -0.01, -2.56), (90, 0, 0), 0.003, M_parent=M)
    kb.louver_bay("GasExhaust", 0.32, 0.12, 0.032, (0, 0.275, -0.52), (-90, 0, 0), blades=4, M_parent=M)
    kb.add_marker("MUZZLE", (0.690, -0.040, -2.650))


# 10. arm_th60 — TH-60 Krupp HB-7000 Boxed Hydraulic Rock-Breaker Hammer
def build_arm_th60(kb: KitbashScene):
    cx, cy = 0.680, -0.03
    _arm_mount_and_pauldron(kb, "TH60", cx, cy, heavy=True, oxide_shld=True, decal_key="caution_chev")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Heavy boxed shock-isolated breaker housing + rubber elastomer damper blocks + dorsal N2 accumulator!
    kb.box("BreakerBox", (0.38, 0.40, 1.84), "armor_oxide", "armor_slab", (0, 0.0, -0.82), (0, 0, 0), 0.020, 1, M_parent=M)
    kb.spaced_armor_plate("OutboardWearPlate", (0.86, 0.32, 0.038), "armor", "weld_plate", (0.205, 0.0, -1.16), (0, -90, 0), M_parent=M)
    kb.box("RearElastomer", (0.34, 0.34, 0.16), "rubber", "dust_boot", (0, 0.0, 0.16), (0, 0, 0), 0.010, 1, M_parent=M)
    kb.cyl("N2Accumulator", 0.135, 0.155, 0.34, 18, "copper", "armor_panel", (0, 0.28, -0.18), (0, 0, 0), 0.014, M_parent=M)
    kb.bolt_ring("N2Bolts", 0.12, 8, 0.010, (0, 0.20, -0.18), (0, 0, 0), M_parent=M)
    for si, sx in enumerate([-0.12, 0.12]):
        kb.tube_path(f"HammerHose_{si}", [(sx, 0.22, 0.22), (sx * 1.35, 0.26, -0.02), (sx, 0.21, -0.34)],
                     0.022, 8, "gunmetal", "braid_hose", add_clamps=True, M_parent=M)
    # 4 exposed full-length chrome tie-rod through-bolts + hex nuts!
    for ti, (tx, ty) in enumerate([(-0.15, 0.16), (0.15, 0.16), (-0.15, -0.16), (0.15, -0.16)]):
        kb.cyl(f"TieRod_{ti}", 0.020, 0.020, 1.98, 8, "chrome", "plain_metal", (tx, ty, -0.82), (90, 0, 0), 0.002, M_parent=M)
        kb.cyl(f"FrontNut_{ti}", 0.036, 0.036, 0.055, 6, "brass", "plain_metal", (tx, ty, -1.78), (90, 0, 0), 0.003, M_parent=M)
    # Front bronze/gunmetal tool bushing + massive flat-wedge chisel moil point to z = -2.70!
    kb.cyl("FrontBushing", 0.135, 0.150, 0.22, 18, "gunmetal", "gear_collar", (0, 0.0, -1.84), (90, 0, 0), 0.008, M_parent=M)
    kb.cyl("MoilShank", 0.082, 0.086, 0.56, 16, "chrome", "plain_metal", (0, 0.0, -2.20), (90, 0, 0), 0.004, M_parent=M)
    kb.loft("ChiselWedge", [
        (-2.46, [(-0.075, -0.075), (0.075, -0.075), (0.075, 0.075), (-0.075, 0.075)]),
        (-2.70, [(-0.082, -0.012), (0.082, -0.012), (0.082, 0.012), (-0.082, 0.012)]),
    ], "chrome", "plain_metal", (0, 0, 0), (0, 0, 0), 0.004, 1, M_parent=M)
    kb.add_marker("MUZZLE", (0.680, -0.030, -2.700))
