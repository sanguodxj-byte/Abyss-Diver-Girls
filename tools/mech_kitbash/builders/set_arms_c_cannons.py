"""
Extended Arm Weapon Pack C (10 Heavy Cannons, Autocannons & Anti-Materiel Rifles) — B.o.T Standard.
Canonical Right Arm (side = +1.0, strictly x >= +0.010 zero-core-clash clearance):
  1. arm_2a46     (2A46-125 T-90M 125mm Smoothbore w/ ERA Shield, 5-Band Thermal Sleeve & Sosna-U)
  2. arm_2a72     (2A72-30 Bakhcha Space-Truss 30mm Autocannon w/ Bellows Spring & Coax PKTM)
  3. arm_ags152   (AGS-152 Zumwalt Faceted Stealth 152mm Naval Gun w/ Copper Water-Cooling Loops)
  4. arm_bofors40 (L70-40 Bofors 40mm L/70 w/ Top Clip Hopper, Brass 5-Rd Clip & 3P Muzzle Coils)
  5. arm_m242     (M242-25 Bushmaster 25mm Dual-Feed Chain Gun w/ Stacked Boxes & Fluted Barrel)
  6. arm_m68      (M68-105 Stryker Overhead 105mm Rifled Gun w/ Rear Carousel Drum & Pepperpot Brake)
  7. arm_m777     (M777-155 Titanium Truss 155mm Howitzer w/ Hydro-Gas Equilibrators & Double Brake)
  8. arm_amr      (NTW-20 Anti-Materiel Cannon w/ Twin Recoil Cylinders, Side Mag & Arrowhead Brake)
  9. arm_m82      (M82-35 Barrett 35mm Stamped Receiver, Vented Forend, Angled Mag & V-Chevron Brake)
 10. arm_ntw57    (NTW-57 Denel 57mm Recoil Sled, Horizontal Side Mag & Roll-Cage Optic Guard)
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


def _arm_mount_and_pauldron(kb: KitbashScene, pfx: str, cx: float, cy: float, heavy=True, oxide_shld=False, decal_key="caution_chev"):
    kb.a1_shoulder_mount(f"{pfx}_A1", heavy=heavy)
    # Trunnion bridge from yoke (x=0.52) to receiver inboard cheek
    flg_x = max(0.55, cx - 0.17)
    kb.box(f"{pfx}_TrFlg", (0.032, 0.24, 0.28), "gunmetal", "bolt_flange", (flg_x, cy, 0.0), (0, 0, 0), 0.005, 1)
    kb.cyl(f"{pfx}_TrAxl", 0.096, 0.096, max(0.036, flg_x - 0.505), 14, "dark", "gear_collar", ((0.505 + flg_x) * 0.5, cy, 0.0), (0, 0, 90), 0.004, u_rep=2.0)
    # B.o.T angled armored shoulder pauldron (top-mounted sub-plate & stencil so tall weapon receivers never clip!)
    M_sh = g2b_mat((0.33, 0.46, 0.02), (0, 0, -8.0))
    kb.plate(f"{pfx}_PldMain", trap_2d(0.74, 0.50, 0.22, 0.06), 0.24, "armor", "armor_slab", (0, 0, 0), (0, 90, 0), 0.014, 1, M_parent=M_sh)
    kb.plate(f"{pfx}_PldSub", crect_2d(0.16, 0.38, (0.03, 0.03, 0.03, 0.03)), 0.045, "armor_oxide" if oxide_shld else "armor_sub", "weld_plate",
             (0.0, 0.125, 0), (-90, 0, 0), 0.008, 1, M_parent=M_sh)
    kb.grab_rail(f"{pfx}_PldGrab", 0.18, 0.034, (-0.11, 0.04, 0), (0, 90, 90), 0.009, M_parent=M_sh)
    if decal_key:
        kb.decal(f"{pfx}_PldDec", decal_key, (0.14, 0.12), (0.0, 0.154, 0.0), (-90, 0, 0), M_parent=M_sh)


# 1. arm_2a46 — 2A46-125 T-90M 125mm Smoothbore Tank Cannon
def build_arm_2a46(kb: KitbashScene):
    cx, cy = 0.69, -0.03
    _arm_mount_and_pauldron(kb, "A2A46", cx, cy, heavy=True, oxide_shld=True, decal_key="unit_54")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    kb.box("BreechHouse", (0.40, 0.42, 0.88), "armor_sub", "armor_slab", (0, 0, 0.08), (0, 0, 0), 0.020, 1, M_parent=M)
    kb.box("StubEjectRear", (0.30, 0.26, 0.24), "dark", "frame_cnc", (0, 0.04, 0.62), (0, 0, 0), 0.014, 1, M_parent=M)
    kb.plate("EjectHatch", crect_2d(0.22, 0.14, (0.02, 0.02, 0.02, 0.02)), 0.03, "gunmetal", "armor_hatch", (0, 0.12, 0.745), (14, 0, 0), 0.004, 1, M_parent=M)
    # 4S23 Relikt / Kontakt-5 ERA angled mantlet shield + Sosna-U thermal sight
    for si, sx in enumerate([-0.14, 0.14]):
        kb.era_block(f"MantletERA_{si}", (0.20, 0.28, 0.068), "armor" if si == 0 else "armor_oxide", (sx, 0.06, -0.40), (24, sx * -16.0, 0), M_parent=M)
    kb.eoir_gimbal("SosnaU", (0.14, 0.34, -0.14), M_parent=M)
    # 125mm 2A46M-5 barrel with 5 strapped thermal shroud segments + bore evacuator + muzzle reference sensor
    kb.cyl("MainTube", 0.066, 0.078, 2.42, 18, "gunmetal", "plain_metal", (0, 0, -1.58), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("FumeExtractor", 0.105, 0.105, 0.44, 18, "armor", "armor_panel", (0, 0, -1.32), (90, 0, 0), 0.008, M_parent=M)
    for ti in range(5):
        tz = -0.68 - ti * 0.42
        if abs(tz - (-1.32)) > 0.22:
            kb.cyl(f"ThermSleeve_{ti}", 0.086, 0.088, 0.34, 16, "armor_sub", "armor_pocket", (0, 0, tz), (90, 0, 0), 0.004, M_parent=M)
            kb.cyl(f"ClampBand_{ti}", 0.094, 0.094, 0.026, 16, "chrome", "gear_collar", (0, 0, tz), (90, 0, 0), 0.002, M_parent=M)
    kb.box("MuzzleRefMast", (0.024, 0.075, 0.036), "brass", "plain_metal", (0, 0.095, -2.76), (0, 0, 0), 0.003, 1, M_parent=M)
    kb.barrel_bore("Bore125", 0.078, 0.062, (0, 0, -2.79), depth=0.09, segs=18, M_parent=M)
    kb.louver_bay("SideVent", 0.34, 0.16, 0.034, (0.205, -0.04, 0.12), (0, -90, 0), blades=4, M_parent=M)
    kb.add_marker("MUZZLE", (0.690, -0.030, -2.840))


# 2. arm_2a72 — 2A72-30 Bakhcha Space-Truss 30mm Autocannon
def build_arm_2a72(kb: KitbashScene):
    cx, cy = 0.658, -0.03
    _arm_mount_and_pauldron(kb, "A2A72", cx, cy, heavy=False, oxide_shld=False, decal_key="hazard_tri")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    kb.plate("RecBody", crect_2d(0.76, 0.38, (0.06, 0.06, 0.05, 0.05)), 0.36, "armor", "armor_slab", (0, 0, 0.04), (0, 90, 0), 0.018, 1, M_parent=M)
    kb.box("AmmoChute", (0.18, 0.24, 0.44), "armor_oxide", "armor_ribs", (0.22, -0.04, 0.06), (0, 0, 0), 0.012, 1, M_parent=M)
    # Coaxial PKTM 7.62mm MG + root bellows recoil spring sleeve
    kb.cyl("CoaxPKTM", 0.024, 0.028, 0.88, 10, "dark", "plain_metal", (0.16, 0.02, -0.78), (90, 0, 0), 0.002, M_parent=M)
    kb.cyl("RecoilBellows", 0.078, 0.082, 0.42, 16, "rubber", "dust_boot", (0, 0, -0.56), (90, 0, 0), 0.005, M_parent=M, u_rep=2.0)
    kb.cyl("Barrel30", 0.038, 0.046, 2.02, 16, "gunmetal", "plain_metal", (0, 0, -1.42), (90, 0, 0), 0.003, M_parent=M)
    # Iconic BMP-3M/BMD-4M triangular 3-rod steel space-truss barrel stabilizer cage!
    angs = [math.radians(90), math.radians(210), math.radians(330)]
    for ai, a in enumerate(angs):
        rx, ry = math.cos(a) * 0.105, math.sin(a) * 0.105
        kb.cyl(f"TrussLong_{ai}", 0.013, 0.013, 1.48, 8, "dark", "plain_metal", (rx, ry, -1.16), (90, 0, 0), 0.002, M_parent=M)
    for ri, rz in enumerate([-0.52, -0.92, -1.32, -1.72]):
        kb.cyl(f"TrussRing_{ri}", 0.112, 0.112, 0.026, 12, "gunmetal", "bolt_flange", (0, 0, rz), (90, 0, 0), 0.003, hollow_r=0.088, M_parent=M)
    # Twin-cone slotted muzzle brake + Bakhcha-U EO/IR sight + ejection louver
    kb.eoir_gimbal("BakhchaSight", (0.04, 0.28, -0.08), M_parent=M)
    kb.louver_bay("LinkEject", 0.28, 0.14, 0.030, (-0.185, -0.04, 0.08), (0, 90, 0), blades=4, M_parent=M)
    kb.cyl("BrakeCone", 0.062, 0.044, 0.14, 16, "dark", "gear_collar", (0, 0, -2.44), (90, 0, 0), 0.004, M_parent=M)
    kb.barrel_bore("Bore30", 0.056, 0.032, (0, 0, -2.48), depth=0.06, segs=14, M_parent=M)
    kb.add_marker("MUZZLE", (0.658, -0.030, -2.510))


# 3. arm_ags152 — AGS-152 Faceted Stealth Water-Cooled 152mm Naval Gun
def build_arm_ags152(kb: KitbashScene):
    cx, cy = 0.69, -0.03
    _arm_mount_and_pauldron(kb, "AGS", cx, cy, heavy=True, oxide_shld=False, decal_key="unit_08")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Zumwalt-inspired faceted radar-scattering stealth gunhouse + twin copper water-cooling jacket pipes
    kb.plate("StealthCasemate", trap_2d(0.48, 0.34, 0.46, 0.08), 0.96, "armor", "armor_slab", (0, 0.02, 0.04), (90, 0, 0), 0.022, 1, M_parent=M)
    kb.plate("ForwardGlacis", trap_2d(0.46, 0.28, 0.42, 0.06), 0.24, "armor_sub", "weld_plate", (0, 0.0, -0.52), (38, 0, 0), 0.016, 1, M_parent=M)
    kb.cyl("WaterJacket", 0.095, 0.105, 1.36, 18, "armor_dark", "armor_panel", (0, -0.01, -1.24), (90, 0, 0), 0.008, M_parent=M)
    kb.cyl("InnerTube152", 0.068, 0.076, 0.72, 18, "gunmetal", "plain_metal", (0, -0.01, -2.18), (90, 0, 0), 0.004, M_parent=M)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.tube_path(f"CoolantPipe_{si}", [(sx * 0.16, 0.08, -0.38), (sx * 0.14, 0.06, -1.10), (sx * 0.095, 0.02, -1.78)],
                     0.020, 8, "copper", "plain_metal", add_clamps=True, M_parent=M)
    kb.box("NavalBrake", (0.22, 0.16, 0.22), "dark", "bolt_flange", (0, -0.01, -2.50), (0, 0, 0), 0.012, 1, M_parent=M)
    kb.barrel_bore("Bore152", 0.082, 0.062, (0, -0.01, -2.58), depth=0.08, segs=18, M_parent=M)
    kb.glow_radiator_arc("RearCoolFan", (0, 0.02, 0.53), (0, 180, 0), r_outer=0.15, r_inner=0.06, depth=0.05, blades=8, emit_slot="emit_cyan", M_parent=M)
    kb.add_marker("MUZZLE", (0.690, -0.040, -2.600))


# 4. arm_bofors40 — L70-40 Bofors 40mm Top-Clip Autocannon
def build_arm_bofors40(kb: KitbashScene):
    cx, cy = 0.67, -0.03
    _arm_mount_and_pauldron(kb, "BOF", cx, cy, heavy=False, oxide_shld=True, decal_key="ord_12")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    kb.box("BreechCasing", (0.34, 0.38, 0.82), "armor", "armor_slab", (0, 0, 0.04), (0, 0, 0), 0.018, 1, M_parent=M)
    # Iconic Bofors top trapezoidal feed hopper + exposed vertical 5-round brass stripper clip!
    kb.plate("FeedHopper", trap_2d(0.28, 0.36, 0.28, 0.04), 0.38, "armor_sub", "armor_pocket", (0, 0.29, -0.04), (0, 0, 0), 0.012, 1, M_parent=M)
    for ri in range(5):
        ry = 0.28 + ri * 0.048
        kb.cyl(f"BofShell_{ri}", 0.020, 0.022, 0.22, 10, "brass", "plain_metal", (0, ry, -0.04), (90, 0, 0), 0.002, M_parent=M)
        kb.cyl(f"BofTip_{ri}", 0.008, 0.020, 0.07, 10, "armor_oxide", "plain_metal", (0, ry, -0.18), (90, 0, 0), 0.002, M_parent=M)
    # Tapered L/70 barrel + recoil spring drum + 3P proximity programming muzzle coils + conical flash hider!
    kb.cyl("RecoilDrum", 0.092, 0.098, 0.38, 16, "dark", "gear_collar", (0, 0.02, -0.54), (90, 0, 0), 0.005, M_parent=M)
    kb.cyl("BarrelL70", 0.038, 0.056, 1.72, 16, "gunmetal", "plain_metal", (0, 0.02, -1.52), (90, 0, 0), 0.003, M_parent=M)
    for ci, cz in enumerate([-2.22, -2.30]):
        kb.cyl(f"Coil3P_{ci}", 0.052, 0.052, 0.036, 14, "copper", "gear_collar", (0, 0.02, cz), (90, 0, 0), 0.003, M_parent=M)
    kb.cyl("FlashCone", 0.068, 0.040, 0.16, 16, "dark", "plain_metal", (0, 0.02, -2.43), (90, 0, 0), 0.004, hollow_r=0.052, M_parent=M)
    kb.louver_bay("CasingEject", 0.26, 0.14, 0.034, (0.175, -0.06, 0.18), (0, -90, 0), blades=4, M_parent=M)
    kb.add_marker("MUZZLE", (0.670, -0.010, -2.520))


# 5. arm_m242 — M242-25 Bushmaster Dual-Feed 25mm Chain Gun
def build_arm_m242(kb: KitbashScene):
    cx, cy = 0.646, -0.03
    _arm_mount_and_pauldron(kb, "M242", cx, cy, heavy=False, oxide_shld=False, decal_key="caution_chev")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    kb.box("ChainRec", (0.34, 0.36, 0.74), "dark", "frame_cnc", (0, 0, 0.02), (0, 0, 0), 0.016, 1, M_parent=M)
    # Stacked upper APDS & lower HEI-T dual-feed armored ammo boxes + external electric chain-drive motor drum
    kb.box("UpperAPBox", (0.24, 0.16, 0.56), "armor", "armor_slab", (0.24, 0.09, 0.04), (0, 0, 0), 0.012, 1, M_parent=M)
    kb.box("LowerHEBox", (0.24, 0.16, 0.56), "armor_oxide", "weld_plate", (0.24, -0.09, 0.04), (0, 0, 0), 0.012, 1, M_parent=M)
    kb.cyl("DriveMotor", 0.078, 0.078, 0.28, 14, "brass", "gear_collar", (-0.12, -0.18, 0.10), (90, 0, 0), 0.004, M_parent=M)
    kb.eoir_gimbal("IBASSight", (0.04, 0.28, -0.12), M_parent=M)
    # Heavy fluted 25mm barrel + perforated barrel support collar + slotted flash suppressor
    kb.cyl("SupportShroud", 0.072, 0.082, 0.44, 16, "armor_sub", "vent_mesh", (0, 0, -0.56), (90, 0, 0), 0.005, M_parent=M, u_rep=2.0)
    kb.cyl("FlutedBarrel", 0.036, 0.048, 1.44, 16, "gunmetal", "armor_ribs", (0, 0, -1.44), (90, 0, 0), 0.003, M_parent=M, u_rep=2.0)
    kb.barrel_bore("Bore25", 0.048, 0.028, (0, 0, -2.19), depth=0.06, segs=14, M_parent=M)
    kb.add_marker("MUZZLE", (0.646, -0.030, -2.220))


# 6. arm_m68 — M68-105 Stryker Overhead 105mm Rifled Gun + Rear Carousel Drum
def build_arm_m68(kb: KitbashScene):
    cx, cy = 0.67, -0.03
    _arm_mount_and_pauldron(kb, "M68", cx, cy, heavy=True, oxide_shld=False, decal_key="unit_17")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # M1128 MGS low-profile unmanned gun pod + large rear rotary autoloader drum + rubber accordion dust boot!
    kb.plate("MGSPod", crect_2d(0.84, 0.36, (0.10, 0.06, 0.06, 0.06)), 0.38, "armor", "armor_slab", (0, 0.02, -0.04), (0, 90, 0), 0.018, 1, M_parent=M)
    kb.cyl("CarouselDrum", 0.24, 0.24, 0.46, 20, "armor_sub", "armor_hatch", (0, 0.04, 0.56), (90, 0, 0), 0.012, M_parent=M, u_rep=2.0)
    kb.bolt_ring("DrumBolts", 0.18, 10, 0.010, (0, 0.04, 0.794), (90, 0, 0), M_parent=M)
    kb.cyl("MantletBoot", 0.105, 0.125, 0.32, 16, "rubber", "dust_boot", (0, 0, -0.58), (90, 0, 0), 0.006, M_parent=M, u_rep=2.0)
    kb.cyl("Barrel105", 0.056, 0.068, 1.88, 18, "gunmetal", "plain_metal", (0, 0, -1.62), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("Evac105", 0.094, 0.094, 0.38, 18, "armor_oxide", "weld_plate", (0, 0, -1.36), (90, 0, 0), 0.006, M_parent=M)
    # Multi-hole pepperpot muzzle brake
    kb.cyl("PepperpotBrake", 0.076, 0.072, 0.20, 18, "dark", "vent_mesh", (0, 0, -2.58), (90, 0, 0), 0.005, M_parent=M, u_rep=2.0)
    kb.barrel_bore("Bore105", 0.074, 0.052, (0, 0, -2.66), depth=0.08, segs=18, M_parent=M)
    kb.add_marker("MUZZLE", (0.670, -0.030, -2.680))


# 7. arm_m777 — M777-155 Titanium Truss 155mm Ultralight Howitzer
def build_arm_m777(kb: KitbashScene):
    cx, cy = 0.68, -0.03
    _arm_mount_and_pauldron(kb, "M777", cx, cy, heavy=True, oxide_shld=True, decal_key="lift_cg")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Interrupted-screw breech + sled recoil cradle + twin dorsal hydro-gas equilibrator cylinders!
    kb.box("SledCradle", (0.36, 0.16, 1.38), "dark", "frame_cnc", (0, -0.10, -0.44), (0, 0, 0), 0.014, 1, M_parent=M)
    kb.cyl("ScrewBreech", 0.135, 0.145, 0.44, 18, "gunmetal", "bolt_flange", (0, 0.02, 0.24), (90, 0, 0), 0.008, M_parent=M)
    for si, sx in enumerate([-0.12, 0.12]):
        kb.hydraulic(f"HydroGasEq_{si}", (sx, 0.22, 0.16), (sx, 0.14, -1.04), 0.028, M_parent=M)
    kb.cyl("Tube155", 0.068, 0.084, 2.52, 18, "armor", "plain_metal", (0, 0.02, -1.36), (90, 0, 0), 0.004, M_parent=M)
    # Iconic wide double-baffle M777 muzzle brake + forward towing lunette ring!
    kb.plate("DoubleBrake", trap_2d(0.32, 0.22, 0.24, 0.03), 0.16, "gunmetal", "bolt_flange", (0, 0.02, -2.70), (90, 0, 0), 0.010, 1, M_parent=M)
    kb.tow_shackle("MuzzleTowRing", (0, -0.02, -2.83), (0, 0, 0), 0.85, M_parent=M)
    kb.barrel_bore("Bore155", 0.082, 0.062, (0, 0.02, -2.81), depth=0.08, segs=18, M_parent=M)
    kb.add_marker("MUZZLE", (0.680, -0.010, -2.850))


# 8. arm_amr — NTW-20 Heavy Anti-Materiel Sniper Cannon
def build_arm_amr(kb: KitbashScene):
    cx, cy = 0.38, -0.02
    kb.a1_shoulder_mount("AMRA1", heavy=False)
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Heavy milled chassis + twin hydraulic recoil damper cylinders + side-mounted 20mm box magazine
    kb.box("AMRChassis", (0.30, 0.32, 0.96), "armor", "armor_slab", (0, 0, -0.22), (0, 0, 0), 0.016, 1, M_parent=M)
    kb.box("SideMag20", (0.28, 0.12, 0.24), "armor_oxide", "armor_ribs", (0.24, 0.02, -0.24), (0, 0, -8), 0.010, 1, M_parent=M)
    for si, sx in enumerate([-0.10, 0.10]):
        kb.hydraulic(f"AMRRecoil_{si}", (sx, -0.16, 0.18), (sx, -0.16, -1.16), 0.022, M_parent=M)
    # Long-range laser-rangefinding sniper scope + ultra-long fluted barrel + wide arrowhead brake
    kb.eoir_gimbal("LRFScope", (0, 0.28, -0.20), M_parent=M)
    kb.cyl("ScopeTube", 0.044, 0.052, 0.56, 14, "dark", "plain_metal", (0, 0.26, -0.52), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("ScopeLens", 0.046, 0.046, 0.018, 14, "glass", "plain_metal", (0, 0.26, -0.805), (90, 0, 0), 0.002, M_parent=M)
    kb.cyl("FlutedAMR", 0.038, 0.056, 2.66, 16, "gunmetal", "armor_ribs", (0, -0.01, -2.02), (90, 0, 0), 0.003, M_parent=M, u_rep=3.0)
    kb.plate("ArrowBrake", trap_2d(0.24, 0.12, 0.22, 0.02), 0.11, "dark", "bolt_flange", (0, -0.01, -3.38), (90, 0, 0), 0.008, 1, M_parent=M)
    kb.barrel_bore("BoreAMR", 0.046, 0.026, (0, -0.01, -3.45), depth=0.06, segs=14, M_parent=M)
    kb.decal("AMRStencil", "unit_08", (0.18, 0.14), (0.156, 0.04, 0.06), (0, -90, 0), M_parent=M)
    kb.add_marker("MUZZLE", (0.380, -0.030, -3.480))


# 9. arm_m82 — M82-35 Barrett 35mm Anti-Materiel Sniper Rifle
def build_arm_m82(kb: KitbashScene):
    cx, cy = 0.636, -0.03
    _arm_mount_and_pauldron(kb, "M82", cx, cy, heavy=False, oxide_shld=False, decal_key="unit_17")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Stamped upper/lower receiver + ventilated oval-slot handguard + forward-angled ribbed box mag + BORS scope + V-brake!
    kb.box("M82Upper", (0.28, 0.22, 1.36), "armor", "armor_slab", (0, 0.06, -0.44), (0, 0, 0), 0.014, 1, M_parent=M)
    kb.box("M82Lower", (0.24, 0.16, 0.76), "armor_sub", "frame_cnc", (0, -0.11, -0.22), (0, 0, 0), 0.012, 1, M_parent=M)
    kb.louver_bay("HandguardVentR", 0.48, 0.12, 0.028, (0.142, 0.06, -0.82), (0, -90, 0), blades=6, mesh_style=True, M_parent=M)
    kb.louver_bay("HandguardVentL", 0.48, 0.12, 0.028, (-0.142, 0.06, -0.82), (0, 90, 0), blades=6, mesh_style=True, M_parent=M)
    kb.box("BarrettMag", (0.16, 0.34, 0.28), "gunmetal", "armor_ribs", (0, -0.30, -0.32), (14, 0, 0), 0.010, 1, M_parent=M)
    # BORS ballistic computer scope on Picatinny rail + iconic Barrett carry handle & folded bipod
    kb.box("PicRail", (0.08, 0.036, 0.88), "dark", "armor_ribs", (0, 0.180, -0.38), (0, 0, 0), 0.004, 1, M_parent=M)
    kb.grab_rail("CarryHandle", 0.22, 0.075, (0.08, 0.20, -0.74), (0, 90, 0), 0.011, M_parent=M)
    for si, sx in enumerate([-0.11, 0.11]):
        kb.hydraulic(f"FoldBipod_{si}", (sx, -0.06, -1.08), (sx, -0.14, -0.58), 0.018, M_parent=M)
    kb.cyl("BORSScope", 0.048, 0.040, 0.48, 14, "dark", "plain_metal", (0, 0.26, -0.36), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("BORSLens", 0.046, 0.046, 0.016, 14, "glass", "plain_metal", (0, 0.26, -0.605), (90, 0, 0), 0.002, M_parent=M)
    kb.cyl("Barrel35", 0.038, 0.048, 1.56, 16, "gunmetal", "armor_ribs", (0, 0.02, -1.86), (90, 0, 0), 0.003, M_parent=M)
    kb.plate("VChevronBrake", trap_2d(0.26, 0.11, 0.22, 0.02), 0.12, "dark", "bolt_flange", (0, 0.02, -2.64), (90, 0, 0), 0.008, 1, M_parent=M)
    kb.barrel_bore("Bore35", 0.048, 0.030, (0, 0.02, -2.72), depth=0.06, segs=14, M_parent=M)
    kb.add_marker("MUZZLE", (0.636, -0.010, -2.740))


# 10. arm_ntw57 — NTW-57 Denel 57mm Long-Range Anti-Armor Rifle
def build_arm_ntw57(kb: KitbashScene):
    cx, cy = 0.658, -0.03
    _arm_mount_and_pauldron(kb, "NTW57", cx, cy, heavy=True, oxide_shld=True, decal_key="hazard_tri")
    M = g2b_mat((cx, cy, 0.0), (0, 0, 0))

    # Full-length lower recoil cradle sled + horizontal outboard heavy box mag + tubular roll-cage optic guard!
    kb.box("RecoilSled", (0.32, 0.14, 1.56), "dark", "frame_cnc", (0, -0.14, -0.46), (0, 0, 0), 0.014, 1, M_parent=M)
    kb.box("Breech57", (0.30, 0.28, 0.88), "armor", "armor_slab", (0, 0.04, -0.08), (0, 0, 0), 0.016, 1, M_parent=M)
    kb.box("HorizMag57", (0.34, 0.14, 0.30), "armor_oxide", "weld_plate", (0.28, 0.04, -0.14), (0, 0, 0), 0.012, 1, M_parent=M)
    kb.cyl("Optic57", 0.046, 0.052, 0.52, 14, "gunmetal", "plain_metal", (0, 0.26, -0.18), (90, 0, 0), 0.004, M_parent=M)
    kb.cyl("Optic57Gl", 0.048, 0.048, 0.016, 14, "glass", "plain_metal", (0, 0.26, -0.445), (90, 0, 0), 0.002, M_parent=M)
    kb.grab_rail("RollCageCarry", 0.62, 0.16, (0, 0.20, -0.18), (0, 90, 0), 0.014, M_parent=M)
    kb.hydraulic("SledDamper", (0, -0.04, -0.48), (0, -0.08, -1.22), 0.026, M_parent=M)
    kb.cyl("HeavyTube57", 0.044, 0.058, 2.24, 16, "gunmetal", "plain_metal", (0, 0.02, -1.60), (90, 0, 0), 0.004, M_parent=M)
    kb.box("BoxBrake57", (0.20, 0.14, 0.20), "dark", "bolt_flange", (0, 0.02, -2.70), (0, 0, 0), 0.010, 1, M_parent=M)
    kb.barrel_bore("Bore57", 0.056, 0.038, (0, 0.02, -2.78), depth=0.07, segs=16, M_parent=M)
    kb.add_marker("MUZZLE", (0.658, -0.010, -2.800))
