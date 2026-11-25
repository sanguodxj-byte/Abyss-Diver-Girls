"""Batch 02b Heavy & Specialty Cores — Production Kitbash Builders (MECH_MODELING_STANDARD v1.0).

Retains `core_std` (MK-II Standard Multi-Faceted Tactical Core).
All other cores in this batch have been migrated to sculpted non-boxy v2 builders
in `sculpted_cores_v2.py`, `sculpted_cores_v2_tactical.py`, and `sculpted_cores_v2_specialist.py`.
"""
import math
from mathutils import Vector
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d
from specs import HP_C1_RADIUS, HP_C1_CORE_Y_BOT


# ==============================================================================
# SHARED HEAVY CORE INDUSTRIAL SUB-ASSEMBLIES (PRIVATE HELPERS)
# ==============================================================================

def _add_periscope(kb: KitbashScene, prefix: str, w: float, h: float, pos, rot_deg=(0, 0, 0),
                   glass_slot: str = "glass", M_parent=None):
    """Armored recessed periscope housing with brow hood, deep bore cavity, and coated prism."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.box(f"{prefix}_hs", (w, h, 0.082), "dark", "frame_cnc", (0, 0, 0.026), (0, 0, 0), 0.007, 1, M_parent=M)
    kb.box(f"{prefix}_br", (w + 0.022, 0.022, 0.112), "gunmetal", "bolt_flange",
           (0, h * 0.5 + 0.014, -0.014), (10, 0, 0), 0.004, 1, M_parent=M)
    kb.box(f"{prefix}_cv", (w * 0.82, h * 0.56, 0.020), "bore", "plain_metal",
           (0, -0.004, -0.024), (0, 0, 0), 0.003, 1, M_parent=M)
    kb.box(f"{prefix}_gl", (w * 0.74, h * 0.44, 0.014), glass_slot, "plain_metal",
           (0, -0.004, -0.048), (0, 0, 0), 0.002, 1, M_parent=M)


def _add_armored_eye(kb: KitbashScene, prefix: str, w: float, h: float, pos, rot_deg=(0, 0, 0),
                     glass_slot: str = "glass", M_parent=None):
    """Heavy MBT central mantlet armored optical slit with brow guard, bolts, and bore recess."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.box(f"{prefix}_hs", (w, h, 0.115), "dark", "frame_cnc", (0, 0, 0), (0, 0, 0), 0.008, 1, M_parent=M)
    kb.box(f"{prefix}_br", (w + 0.024, 0.026, 0.110), "gunmetal", "bolt_flange",
           (0, h * 0.5 + 0.014, -0.030), (12, 0, 0), 0.005, 1, M_parent=M)
    kb.box(f"{prefix}_sl", (w + 0.016, 0.020, 0.088), "gunmetal", "bolt_flange",
           (0, -h * 0.5 - 0.012, -0.022), (-8, 0, 0), 0.004, 1, M_parent=M)
    kb.box(f"{prefix}_cv", (w * 0.80, h * 0.52, 0.020), "bore", "plain_metal",
           (0, -0.004, -0.056), (0, 0, 0), 0.003, 1, M_parent=M)
    kb.box(f"{prefix}_gl", (w * 0.66, h * 0.28, 0.014), glass_slot, "plain_metal",
           (0, -0.004, -0.080), (0, 0, 0), 0.002, 1, M_parent=M)
    for bi, bx in enumerate([-w * 0.36, w * 0.36]):
        kb.cyl(f"{prefix}_bt{bi}", 0.008, 0.010, 0.016, 6, "chrome", "plain_metal",
               (bx, h * 0.5 + 0.028, -0.042), (12, 0, 0), 0.002, M_parent=M)


def _add_optic_lens(kb: KitbashScene, prefix: str, r: float, pos, rot_deg=(90, 0, 0),
                    lens_slot: str = "emit_cyan", M_parent=None):
    """Multi-ring armored optical bezel with deep bore cavity and recessed objective lens."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.cyl(f"{prefix}_bz", r + 0.010, r + 0.012, 0.032, 12, "gunmetal", "gear_collar",
           (0, 0.006, 0), (0, 0, 0), 0.003, hollow_r=r * 0.84, M_parent=M)
    kb.cyl(f"{prefix}_br", r * 0.83, r * 0.83, 0.010, 10, "bore", "plain_metal",
           (0, 0.014, 0), (0, 0, 0), 0.001, M_parent=M)
    kb.cyl(f"{prefix}_ln", r * 0.78, r * 0.78, 0.010, 12, lens_slot, "plain_metal",
           (0, -0.004, 0), (0, 0, 0), 0.002, M_parent=M)


def _add_citv_sight(kb: KitbashScene, prefix: str, pos, rot_deg=(0, 0, 0),
                    head_slot: str = "armor_sub", lens_slot: str = "emit_cyan", M_parent=None):
    """Panoramic Commander Independent Thermal Viewer (CITV) with armored brow and twin lenses."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.cyl(f"{prefix}_ped", 0.128, 0.152, 0.115, 14, "dark", "gear_collar",
           (0, 0.058, 0), (0, 0, 0), 0.005, M_parent=M)
    kb.box(f"{prefix}_hd", (0.24, 0.175, 0.225), head_slot, "armor_pocket",
           (0, 0.175, 0), (0, 0, 0), 0.014, 1, M_parent=M)
    kb.box(f"{prefix}_cv", (0.175, 0.110, 0.036), "bore", "plain_metal",
           (0, 0.175, -0.104), (0, 0, 0), 0.004, 1, M_parent=M)
    _add_optic_lens(kb, f"{prefix}_l0", 0.036, (-0.042, 0.175, -0.116), (90, 0, 0), lens_slot, M_parent=M)
    _add_optic_lens(kb, f"{prefix}_l1", 0.025, (0.044, 0.175, -0.116), (90, 0, 0), "emit_amber", M_parent=M)
    kb.plate(f"{prefix}_cap", trap_2d(0.225, 0.180, 0.040, 0.010), 0.235, "gunmetal", "bolt_flange",
             (0, 0.270, 0), (0, 0, 0), 0.006, 1, M_parent=M)


def _add_back_dock(kb: KitbashScene, prefix: str, y_back: float, z_back: float,
                   w: float = 0.86, d: float = 0.50, tilt_deg: float = 0.0):
    """HP-B1 dorsal backpack twin guide-rail dock with stepped non-coplanar clamp flanges and hazard band."""
    M = g2b_mat((0.0, y_back, z_back), (tilt_deg, 0.0, 0.0))
    kb.box(f"{prefix}_base", (w, 0.068, d), "dark", "frame_cnc", (0, -0.056, 0), (0, 0, 0), 0.010, 1, M_parent=M)
    kb.box(f"{prefix}_deck", (w - 0.06, 0.036, d - 0.06), "gunmetal", "bolt_flange",
           (0, -0.008, 0), (0, 0, 0), 0.006, 1, M_parent=M)
    for ri, rx in enumerate([-w * 0.34, w * 0.34]):
        kb.box(f"{prefix}_rl{ri}", (0.068, 0.046, d * 0.84), "armor_sub", "armor_ribs",
               (rx, 0.022, 0), (0, 0, 0), 0.007, 1, M_parent=M)
        kb.cyl(f"{prefix}_bt{ri}", 0.011, 0.013, 0.020, 6, "chrome", "plain_metal",
               (rx, 0.052, -d * 0.28), (0, 0, 0), 0.002, M_parent=M)
    kb.box(f"{prefix}_hz", (w * 0.52, 0.020, 0.042), "hazard", "hazard",
           (0, 0.020, d * 0.44), (0, 0, 0), 0.003, 1, M_parent=M)


def _add_gen_dock(kb: KitbashScene, prefix: str, y_gen: float, z_gen: float,
                  w: float = 0.92, h: float = 0.70):
    """HP-G1 rear generator docking frame with zero-coplanar recessed bore bay & concentric busbars."""
    z_f = z_gen - 0.045
    kb.box(f"{prefix}_bay", (w - 0.08, h - 0.08, 0.052), "dark", "frame_cnc",
           (0, y_gen, z_f - 0.042), (0, 0, 0), 0.008, 1)
    kb.box(f"{prefix}_rec", (w - 0.20, h - 0.20, 0.020), "bore", "plain_metal",
           (0, y_gen, z_f - 0.006), (0, 0, 0), 0.003, 1)
    for yi, sy in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_hr{yi}", (w, 0.064, 0.084), "gunmetal", "bolt_flange",
               (0, y_gen + sy * (h * 0.5 - 0.022), z_f), (0, 0, 0), 0.008, 1)
    for xi, sx in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_vr{xi}", (0.064, h - 0.12, 0.084), "gunmetal", "bolt_flange",
               (sx * (w * 0.5 - 0.032), y_gen, z_f), (0, 0, 0), 0.008, 1)
        kb.cyl(f"{prefix}_bus{xi}", 0.020, 0.020, h * 0.54, 8, "copper", "plain_metal",
               (sx * (w * 0.34), y_gen, z_f + 0.014), (0, 0, 0), 0.003)
        kb.cyl(f"{prefix}_val{xi}", 0.030, 0.030, 0.036, 8, "brass", "gear_collar",
               (sx * (w * 0.34), y_gen + h * 0.16, z_f + 0.014), (0, 0, 0), 0.003)
    kb.box(f"{prefix}_hz", (w * 0.56, 0.034, 0.022), "hazard", "hazard",
           (0, y_gen - h * 0.5 - 0.015, z_f + 0.048), (0, 0, 0), 0.003, 1)


def _add_waist_gussets(kb: KitbashScene, prefix: str, y_collar: float = 0.21, r: float = 0.42, n: int = 6):
    """Radial heavy structural load-bearing gussets welding the hull tub to the HP-C1 slewing collar."""
    for gi in range(n):
        ang = math.tau * gi / n + math.pi / n
        gx = math.cos(ang) * r
        gz = math.sin(ang) * r
        yaw = -math.degrees(ang)
        kb.box(f"{prefix}_g{gi}", (0.14, 0.13, 0.052), "gunmetal", "bolt_flange",
               (gx, y_collar, gz), (0, yaw, 0), 0.007, 1)


def _add_slat_cage(kb: KitbashScene, prefix: str, x_side: float, y_c: float,
                   z_start: float, z_end: float, h: float, n_bars: int = 5):
    """Anti-HEAT spaced steel slat/bar armor cage welded to side hull via standoffs."""
    sx = 1.0 if x_side > 0.0 else -1.0
    z_mid = (z_start + z_end) * 0.5
    z_len = abs(z_end - z_start)
    for bi in range(n_bars):
        t = bi / max(1, n_bars - 1)
        zb = z_start + (z_end - z_start) * t
        kb.box(f"{prefix}_vb{bi}", (0.024, h, 0.024), "gunmetal", "plain_metal",
               (x_side, y_c, zb), (0, 0, 0), 0.004, 1)
    for ri, ry in enumerate([-h * 0.44, h * 0.44]):
        kb.box(f"{prefix}_hr{ri}", (0.034, 0.028, z_len + 0.04), "gunmetal", "bolt_flange",
               (x_side, y_c + ry, z_mid), (0, 0, 0), 0.004, 1)
        for si, sz in enumerate([z_start + 0.03, z_end - 0.03]):
            kb.box(f"{prefix}_st{ri}_{si}", (0.088, 0.032, 0.032), "dark", "frame_cnc",
                   (x_side - sx * 0.044, y_c + ry, sz), (0, 0, 0), 0.004, 1)


def _add_exhaust_stack(kb: KitbashScene, prefix: str, pos, rot_deg=(10, 0, 0), h: float = 0.28):
    """Perforated heat-shield exhaust jacket with hollow blackened pipe."""
    M = g2b_mat(pos, rot_deg)
    kb.cyl(f"{prefix}_pipe", 0.040, 0.044, h, 12, "dark", "plain_metal",
           (0, 0, 0), (0, 0, 0), 0.004, hollow_r=0.028, M_parent=M)
    kb.cyl(f"{prefix}_shld", 0.058, 0.058, h * 0.72, 14, "gunmetal", "vent_mesh",
           (0, -0.015, 0), (0, 0, 0), 0.004, hollow_r=0.050, M_parent=M, u_rep=2.0)


def _add_whip_antenna(kb: KitbashScene, prefix: str, pos, h: float = 0.88, tilt_x: float = -6.0):
    """Spring-mounted brass base + tapered tactical whip antenna."""
    x, y, z = pos
    kb.cyl(f"{prefix}_bs", 0.026, 0.034, 0.068, 10, "brass", "dust_boot",
           (x, y + 0.034, z), (0, 0, 0), 0.003)
    kb.cyl(f"{prefix}_wh", 0.005, 0.010, h, 8, "dark", "plain_metal",
           (x, y + 0.06 + h * 0.5, z), (tilt_x, 0, 0), 0.002)


def _oct_2d(r: float):
    """Regular 8-sided chamfered octagon outline in local XY plane."""
    a = r * 0.9239
    b = r * 0.3827
    return [
        (a, b), (b, a), (-b, a), (-a, b),
        (-a, -b), (-b, -a), (b, -a), (a, -b),
    ]


# ==============================================================================
# 8. core_std — MK-II Standard Multi-Faceted Tactical Core
# ==============================================================================

def build_core_std(kb: KitbashScene):
    """MK-II Standard Core: B.o.T multi-faceted chest armor, twin wing ERA, right-offset tri-optic sensor head."""
    # 1. Unified Compact HP-C1 Waist Collar + Dual Waist Hydraulics + Collar Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.11)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.09, r=0.31, n=4)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.20, 0.020, -0.15), (sx * 0.38, 0.22, -0.36), 0.018)

    # 2. Compact MK-II Recessed CNC Frame + Chamfered Outer Torso Shell (top 0.665m for flush HP-B1) + HP-A1
    kb.box("InnerCoreFrame", (1.16, 0.52, 0.92), "dark", "frame_cnc", (0, 0.38, 0.10), (0, 0, 0), 0.020, 1, tile_u=2.0)
    kb.plate("MainTorsoShell", crect_2d(1.48, 0.60, (0.16, 0.16, 0.09, 0.09)), 1.08, "armor_sub", "armor_panel",
             (0, 0.365, 0.10), (0, 0, 0), 0.024, 1)
    kb.arm_bulkhead("ArmMount", 0.78, 0.30, 0.0)
    _add_back_dock(kb, "BackDock", 0.68, 0.36, w=0.72, d=0.40)
    _add_gen_dock(kb, "GenDock", 0.12, 0.66, w=0.72, h=0.28)

    # 3. Multi-Faceted Central Chest Plate + Bolted Sub-Plate + Slotted Intake + Chin Glacis (strictly y >= 0.01)
    M_ch = g2b_mat((0.0, 0.36, -0.55), (-10.0, 0.0, 0.0))
    kb.plate("ChestCenterMain", crect_2d(0.78, 0.62, (0.14, 0.14, 0.18, 0.18)), 0.15, "armor", "armor_slab",
             (0, 0, 0), (0, 0, 0), 0.032, 2, M_parent=M_ch)
    kb.plate("ChestSubPlate", crect_2d(0.48, 0.22, (0.06, 0.06, 0.08, 0.08)), 0.060, "armor_oxide", "weld_plate",
             (0, -0.13, -0.092), (0, 0, 0), 0.014, 1, M_parent=M_ch)
    kb.decal("ChestUnitStencil", "unit_54", (0.24, 0.18), (0.0, 0.14, -0.082), (0, 0, 0), M_parent=M_ch)
    kb.decal("ChestLeftTri", "hazard_tri", (0.12, 0.12), (-0.25, 0.13, -0.082), (0, 0, 0), M_parent=M_ch)
    kb.louver_bay("ChestIntake", 0.34, 0.12, 0.036, (0, -0.14, -0.132), (0, 0, 0), blades=3, mesh_style=False, M_parent=M_ch)
    for bi, bx in enumerate([-0.24, -0.12, 0.0, 0.12, 0.24]):
        kb.cyl(f"ChestRivet_{bi}", 0.011, 0.013, 0.015, 6, "chrome", "plain_metal",
               (bx, 0.22, -0.075), (90, 0, 0), 0.002, M_parent=M_ch)
    kb.box("ChestHazard", (0.20, 0.036, 0.016), "hazard", "hazard", (0.14, 0.12, -0.076), (0, 0, 0), 0.003, 1, M_parent=M_ch)
    # Lower chin sloped armor kept safely above HP-C1 waist skirt clearance
    kb.plate("LowerChin", trap_2d(0.72, 1.00, 0.22, 0.05), 0.12, "armor_sub", "armor_ribs",
             (0, 0.08, -0.50), (24, 0, 0), 0.018, 1)

    # 4. Angled Twin Wing ERA Cheek Plates + Raised Angled Shoulder Armor Cowls + Side Louvers + Headlights
    for si, sx in enumerate([-1.0, 1.0]):
        M_wg = g2b_mat((sx * 0.53, 0.35, -0.45), (-8.0, sx * 28.0, 0.0))
        kb.plate(f"WingArmor_{si}", trap_2d(0.50, 0.42, 0.58, 0.055), 0.11, "armor", "armor_panel",
                 (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_wg)
        kb.era_block(f"WingERA_T_{si}", (0.22, 0.155, 0.052), "armor_sub", (0, 0.09, -0.074), (0, 0, 0), M_parent=M_wg)
        kb.era_block(f"WingERA_B_{si}", (0.22, 0.155, 0.052), "armor_sub", (0, -0.10, -0.074), (0, 0, 0), M_parent=M_wg)
        kb.box(f"WingAccent_{si}", (0.052, 0.38, 0.125), "accent", "plain_metal",
               (sx * 0.18, 0.0, 0.0), (0, 0, 0), 0.005, 1, M_parent=M_wg)
        # Raised canted shoulder armor cowl (kept |x| <= 0.77m & z <= 0.12 to clear HP-A1 & HP-B1!)
        M_sh = g2b_mat((sx * 0.56, 0.69, -0.14), (0.0, 0.0, -sx * 12.0))
        kb.plate(f"ShoulderCowl_{si}", trap_2d(0.46, 0.34, 0.20, 0.040), 0.36, "armor", "armor_hatch",
                 (0, 0, 0), (0, 90, 0), 0.018, 1, M_parent=M_sh)
        kb.box(f"ShoulderStripe_{si}", (0.048, 0.038, 0.36), "accent", "plain_metal",
               (0, 0.095, 0), (0, 0, 0), 0.004, 1, M_parent=M_sh)
        kb.grab_rail(f"ShoulderGrab_{si}", 0.18, 0.036, (0, 0.105, -0.04), (90, 0, 0), 0.010, M_parent=M_sh)
        # Side exhaust louver bay (clear of ArmMount) + lower caged headlights + tow shackles + pipes
        kb.louver_bay(f"SideVent_{si}", 0.32, 0.22, 0.044, (sx * 0.752, 0.29, 0.40), (0, sx * -90.0, 0),
                      blades=4, mesh_style=(si == 1))
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.28, 0.085, -0.61), (0, sx * -8.0, 0))
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.43, 0.08, -0.56), scale=0.95)
        kb.tube_path(f"FlankLine_{si}",
                     [(sx * 0.72, 0.18, 0.16), (sx * 0.74, 0.12, 0.42), (sx * 0.48, 0.12, 0.60)],
                     0.013, 8, "copper" if si == 0 else "gunmetal", "plain_metal" if si == 0 else "braid_hose")

    # 5. Signature Right-Offset Tri-Optic Composite Sensor Head + Left Hatch + Dorsal Radiator + Whip Antenna
    M_hd = g2b_mat((0.22, 0.84, -0.26), (0.0, 0.0, 0.0))
    kb.cyl("HeadNeck", 0.155, 0.175, 0.14, 14, "dark", "gear_collar", (0, -0.14, 0.04), (0, 0, 0), 0.005, M_parent=M_hd)
    kb.bolt_ring("HeadNeckBolts", 0.16, 8, 0.008, (0, -0.10, 0.04), (0, 0, 0), M_parent=M_hd)
    kb.plate("HeadArmor", crect_2d(0.46, 0.31, (0.10, 0.04, 0.02, 0.08)), 0.52, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.020, 1, M_parent=M_hd)
    kb.box("HeadBrow", (0.48, 0.032, 0.145), "gunmetal", "bolt_flange", (0, 0.125, -0.23), (8, 0, 0), 0.005, 1, M_parent=M_hd)
    kb.plate("HeadChin", trap_2d(0.42, 0.32, 0.11, 0.02), 0.09, "armor_sub", "armor_ribs",
             (0, -0.105, -0.245), (-22, 0, 0), 0.010, 1, M_parent=M_hd)
    kb.box("HeadVisorRecess", (0.36, 0.056, 0.022), "bore", "plain_metal", (0, 0.072, -0.256), (0, 0, 0), 0.003, 1, M_parent=M_hd)
    kb.box("HeadVisorGlass", (0.34, 0.044, 0.018), "glass", "plain_metal", (0, 0.072, -0.268), (0, 0, 0), 0.003, 1, M_parent=M_hd)
    kb.cyl("HeadTrunnion", 0.062, 0.062, 0.54, 12, "gunmetal", "gear_collar", (0, 0.0, 0.04), (0, 0, 90), 0.004, M_parent=M_hd)
    for oi, (ox, orad) in enumerate([(-0.11, 0.024), (0.0, 0.036), (0.11, 0.024)]):
        _add_optic_lens(kb, f"TriOptic_{oi}", orad, (ox, -0.042, -0.276), (90, 0, 0),
                        "emit_amber" if oi != 1 else "emit_cyan", M_parent=M_hd)

    # Left roof circular hatch + forward periscope + dorsal radiator (clear of HP-B1!) + whip + exhausts
    kb.cupola_hatch("LeftCmdHatch", (-0.20, 0.67, -0.18))
    _add_periscope(kb, "LeftFrontPeri", 0.14, 0.068, (-0.20, 0.73, -0.36), (0, 0, 0), "glass")
    kb.louver_bay("DorsalVent", 0.54, 0.18, 0.036, (0, 0.684, 0.02), (90, 0, 0), blades=4, mesh_style=False)
    _add_whip_antenna(kb, "CommWhip", (-0.54, 0.665, 0.48), h=0.92, tilt_x=-5.0)
    kb.stowage_rack("RightRearStow", (0.56, 0.46, 0.715), (0, 180, 0))
    for si, sx in enumerate([-1.0, 1.0]):
        _add_exhaust_stack(kb, f"Exh_{si}", (sx * 0.56, 0.54, 0.62), (14, 0, 0), 0.20)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-0.78, 0.30, 0.0))
    kb.add_marker("SOCKET_arm_r", (0.78, 0.30, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  0.68, 0.36))
    kb.add_marker("SOCKET_gen",   (0.0,  0.12, 0.66))


