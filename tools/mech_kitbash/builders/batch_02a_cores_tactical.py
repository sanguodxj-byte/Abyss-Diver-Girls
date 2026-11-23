"""Batch 02a Tactical Cores — Production Kitbash Builders (MECH_MODELING_STANDARD v1.0).

Contains all 10 high-precision tactical core torso modules for batch_02a_cores_tactical:
  1. core_abv_shredder     (M1150-B Assault Breacher Vehicle)
  2. core_assault          (AS-2 / AS-3 Wedge Assault Core)
  3. core_bmpt_terminator  (BMPT-72 Terminator Urban Fire Support)
  4. core_bradley_busk     (M2A4-BK Bradley Urban Survival Kit)
  5. core_command          (CMD-1 / CM-7 Tactical Command Bridge)
  6. core_fennek_recon     (FNK-4 Low-Profile Stealth Recon)
  7. core_fortress         (FT-5 / FT-9 Super-Heavy Fortress Core)
  8. core_heavy            (BW-3 / HV-3 Heavy Assault Core)
  9. core_ka52_alligator   (KA-52M Side-by-Side Gunship Core)
 10. core_krasukha_ew      (1RL257 Krasukha-4 Electronic Warfare Shelter)

Compliance:
  - Unified HP-C1 waist collar (r=0.360m, y_bot=-0.005m) via kb.waist_collar_core(...)
  - Symmetrical HP-A1 shoulder bulkheads via kb.arm_bulkhead(...)
  - Exact SOCKET_arm_l / SOCKET_arm_r / SOCKET_back / SOCKET_gen from manifest.json
  - Whitelisted mat_slot & band_key only; 3-layer industrial detail; 10,000-22,000 tris budget
"""
import math
from mathutils import Vector
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d
from specs import HP_C1_RADIUS, HP_C1_CORE_Y_BOT


# ==============================================================================
# SHARED TACTICAL CORE INDUSTRIAL SUB-ASSEMBLIES (PRIVATE HELPERS)
# ==============================================================================

def _add_periscope(kb: KitbashScene, prefix: str, w: float, h: float, pos, rot_deg=(0, 0, 0),
                   glass_slot: str = "glass", M_parent=None):
    """Armored recessed periscope housing with brow hood, deep bore cavity, and coated prism."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.box(f"{prefix}_hs", (w, h, 0.082), "dark", "frame_cnc", (0, 0, 0.024), (0, 0, 0), 0.007, 1, M_parent=M)
    kb.box(f"{prefix}_br", (w + 0.018, 0.022, 0.110), "gunmetal", "bolt_flange",
           (0, h * 0.5 + 0.008, -0.014), (10, 0, 0), 0.004, 1, M_parent=M)
    kb.box(f"{prefix}_cv", (w * 0.82, h * 0.56, 0.024), "bore", "plain_metal",
           (0, -0.004, -0.022), (0, 0, 0), 0.003, 1, M_parent=M)
    kb.box(f"{prefix}_gl", (w * 0.74, h * 0.44, 0.016), glass_slot, "plain_metal",
           (0, -0.004, -0.036), (0, 0, 0), 0.002, 1, M_parent=M)


def _add_optic_lens(kb: KitbashScene, prefix: str, r: float, pos, rot_deg=(90, 0, 0),
                    lens_slot: str = "emit_cyan", M_parent=None):
    """Multi-ring armored optical bezel with deep bore cavity and recessed objective lens."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.cyl(f"{prefix}_bz", r + 0.010, r + 0.012, 0.028, 12, "gunmetal", "gear_collar",
           (0, 0.008, 0), (0, 0, 0), 0.003, hollow_r=r * 0.84, M_parent=M)
    kb.cyl(f"{prefix}_br", r * 0.85, r * 0.85, 0.010, 10, "bore", "plain_metal",
           (0, -0.002, 0), (0, 0, 0), 0.001, M_parent=M)
    kb.cyl(f"{prefix}_ln", r * 0.78, r * 0.78, 0.014, 12, lens_slot, "plain_metal",
           (0, 0.004, 0), (0, 0, 0), 0.002, M_parent=M)


def _add_back_dock(kb: KitbashScene, prefix: str, y_back: float, z_back: float,
                   w: float = 0.86, d: float = 0.50, tilt_deg: float = 0.0):
    """HP-B1 dorsal backpack twin guide-rail dock with clamp flanges and hazard warning band."""
    M = g2b_mat((0.0, y_back, z_back), (tilt_deg, 0.0, 0.0))
    kb.box(f"{prefix}_base", (w, 0.070, d), "dark", "frame_cnc", (0, -0.042, 0), (0, 0, 0), 0.010, 1, M_parent=M)
    kb.box(f"{prefix}_deck", (w - 0.06, 0.036, d - 0.06), "gunmetal", "bolt_flange",
           (0, -0.006, 0), (0, 0, 0), 0.006, 1, M_parent=M)
    for ri, rx in enumerate([-w * 0.34, w * 0.34]):
        kb.box(f"{prefix}_rl{ri}", (0.068, 0.046, d * 0.84), "armor_sub", "armor_ribs",
               (rx, 0.012, 0), (0, 0, 0), 0.007, 1, M_parent=M)
        kb.cyl(f"{prefix}_bt{ri}", 0.011, 0.013, 0.016, 6, "chrome", "plain_metal",
               (rx, 0.040, -d * 0.28), (0, 0, 0), 0.002, M_parent=M)
    kb.box(f"{prefix}_hz", (w * 0.62, 0.018, 0.042), "hazard", "hazard",
           (0, 0.015, d * 0.44), (0, 0, 0), 0.003, 1, M_parent=M)


def _add_gen_dock(kb: KitbashScene, prefix: str, y_gen: float, z_gen: float,
                  w: float = 0.92, h: float = 0.70):
    """HP-G1 rear generator docking frame with bolt rails, recessed bore bay, and power busbars."""
    z_f = z_gen - 0.045
    kb.box(f"{prefix}_bay", (w - 0.06, h - 0.06, 0.050), "dark", "frame_cnc",
           (0, y_gen, z_f - 0.035), (0, 0, 0), 0.008, 1)
    kb.box(f"{prefix}_rec", (w - 0.16, h - 0.16, 0.024), "bore", "plain_metal",
           (0, y_gen, z_f - 0.010), (0, 0, 0), 0.003, 1)
    for yi, sy in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_hr{yi}", (w, 0.068, 0.088), "gunmetal", "bolt_flange",
               (0, y_gen + sy * (h * 0.5 - 0.025), z_f), (0, 0, 0), 0.008, 1)
    for xi, sx in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_vr{xi}", (0.068, h - 0.06, 0.088), "gunmetal", "bolt_flange",
               (sx * (w * 0.5 - 0.034), y_gen, z_f), (0, 0, 0), 0.008, 1)
        kb.cyl(f"{prefix}_bus{xi}", 0.022, 0.022, h * 0.52, 8, "copper", "plain_metal",
               (sx * (w * 0.34), y_gen, z_f - 0.005), (0, 0, 0), 0.003)
        kb.cyl(f"{prefix}_val{xi}", 0.028, 0.028, 0.034, 8, "brass", "gear_collar",
               (sx * (w * 0.34), y_gen + h * 0.18, z_f + 0.004), (0, 0, 0), 0.003)
    kb.box(f"{prefix}_hz", (w * 0.56, 0.034, 0.018), "hazard", "hazard",
           (0, y_gen - h * 0.5 - 0.015, z_f + 0.038), (0, 0, 0), 0.003, 1)


def _add_slat_cage(kb: KitbashScene, prefix: str, x_side: float, y_c: float,
                   z_start: float, z_end: float, h: float, n_bars: int = 5):
    """Anti-RPG spaced steel slat/bar armor cage welded to side hull via standoffs."""
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
            kb.box(f"{prefix}_st{ri}_{si}", (0.085, 0.032, 0.032), "dark", "frame_cnc",
                   (x_side - sx * 0.042, y_c + ry, sz), (0, 0, 0), 0.004, 1)


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


# ==============================================================================
# 1. core_abv_shredder — M1150-B Assault Breacher Vehicle Core
# ==============================================================================

def build_core_abv_shredder(kb: KitbashScene):
    """M1150-B Assault Breacher Core: 6x heavy glacis ERA, hydraulic stowed V-mine plow, 8-tube LMS."""
    # 1. Unified HP-C1 Waist Ring + Dual Waist Stabilizer Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.24)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.24, 0.05, -0.30), (sx * 0.34, 0.34, -0.44), 0.022)

    # 2. Heavy Inner CNC Chassis + Spaced Side Bulkheads + HP-A1 Arm Mounts
    kb.box("InnerHullTub", (1.60, 1.04, 1.44), "dark", "frame_cnc", (0, 0.76, 0.06), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("LowerBellyPan", (1.32, 0.16, 1.24), "armor_dark", "armor_ribs", (0, 0.22, 0.04), (0, 0, 0), 0.014, 1)
    kb.arm_bulkhead("ArmMount", 1.16, 0.82, 0.02)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"ShoulderPylon_{si}", (0.30, 0.48, 0.56), "armor_sub", "armor_pocket",
               (sx * 0.94, 0.82, 0.02), (0, 0, 0), 0.016, 1)
        kb.box(f"ShoulderCowl_{si}", (0.28, 0.16, 0.76), "armor", "armor_ribs",
               (sx * 0.86, 1.18, 0.04), (0, 0, sx * -16.0), 0.014, 1)

    # 3. Sloped 38-deg ABV Reactive Glacis + 6 Heavy ERA Blocks (2x3)
    M_glacis = g2b_mat((0.0, 0.96, -0.68), (38.0, 0.0, 0.0))
    glacis_xy = trap_2d(1.52, 1.32, 0.62, 0.07)
    kb.plate("GlacisArmor", glacis_xy, 0.14, "armor", "armor_panel", (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_glacis)
    for ri, ry in enumerate([-0.14, 0.14]):
        for ci, cx in enumerate([-0.44, 0.0, 0.44]):
            kb.era_block(f"GlacisERA_{ri}_{ci}", (0.37, 0.21, 0.068), "armor_sub" if (ri + ci) % 2 == 0 else "armor",
                         (cx, ry, -0.105), (0, 0, 0), M_parent=M_glacis)
    kb.box("GlacisHazard", (0.36, 0.048, 0.020), "hazard", "hazard", (0, 0.30, -0.085), (0, 0, 0), 0.003, 1, M_parent=M_glacis)
    kb.grab_rail("GlacisGrab", 0.34, 0.045, (0, 0.31, -0.075), (0, 0, 0), 0.011, M_parent=M_glacis)

    # 4. Stowed Hydraulic V-Shaped Comb Mine Plow + Twin Heavy Lift Cylinders
    kb.box("PlowCenterYoke", (0.48, 0.28, 0.30), "dark", "frame_cnc", (0, 0.48, -0.82), (0, 0, 0), 0.016, 1)
    kb.box("PlowYokeHazard", (0.42, 0.055, 0.022), "hazard", "hazard", (0, 0.56, -0.97), (0, 0, 0), 0.003, 1)
    plow_wing_xy = trap_2d(0.72, 0.62, 0.32, 0.04)
    for si, sx in enumerate([-1.0, 1.0]):
        M_pw = g2b_mat((sx * 0.40, 0.46, -0.92), (14.0, sx * -26.0, 0.0))
        kb.plate(f"PlowWing_{si}", plow_wing_xy, 0.085, "gunmetal", "armor_ribs",
                 (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_pw)
        kb.box(f"PlowRib_{si}", (0.58, 0.045, 0.042), "dark", "bolt_flange",
               (0, 0.11, -0.055), (0, 0, 0), 0.006, 1, M_parent=M_pw)
        for ti, tx in enumerate([-0.24, -0.08, 0.08, 0.24]):
            kb.box(f"PlowTine_{si}_{ti}", (0.046, 0.16, 0.082), "accent", "plain_metal",
                   (tx, -0.16, -0.055), (22, 0, 0), 0.006, 1, M_parent=M_pw)
        # Heavy Hydraulic Lift Ram linking upper glacis to plow wing
        kb.hydraulic(f"PlowLiftHyd_{si}", (sx * 0.46, 0.80, -0.82), (sx * 0.40, 0.52, -0.94), 0.030)
        kb.tube_path(f"PlowHose_{si}", [
            (sx * 0.56, 0.74, -0.74), (sx * 0.64, 0.60, -0.80), (sx * 0.50, 0.50, -0.88)
        ], 0.013, 8, "gunmetal", "braid_hose")
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.66, 0.72, -0.86), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.30, 0.24, -0.86), (0, 0, 90), scale=1.15)

    # 5. Twin 4-Tube (8 Total) Lane-Marking System (LMS) Dispenser Pods + Flank Armor & Cooling
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"FlankArmor_{si}", (0.98, 0.56, 0.072), "armor", "armor_panel",
                              (sx * 0.86, 0.62, 0.10), (0, sx * -90.0, 0))
        kb.box(f"LMSPod_{si}", (0.24, 0.36, 0.60), "armor_sub", "armor_hatch",
               (sx * 0.99, 0.52, 0.26), (0, 0, 0), 0.015, 1)
        kb.box(f"FrontBreachBox_{si}", (0.22, 0.36, 0.52), "dark", "armor_pocket",
               (sx * 0.96, 0.52, -0.36), (0, 0, 0), 0.014, 1)
        for ti, tz in enumerate([-0.18, -0.06, 0.06, 0.18]):
            kb.cyl(f"LMSTube_{si}_{ti}", 0.032, 0.032, 0.14, 10, "brass", "gear_collar",
                   (sx * 1.05, 0.74, 0.26 + tz), (0, 0, sx * -16.0), 0.003, hollow_r=0.022)
        kb.louver_bay(f"SideCooler_{si}", 0.42, 0.22, 0.055, (sx * 0.89, 0.96, 0.38),
                      (0, sx * -90.0, 0), blades=4, mesh_style=(si == 1))
        kb.tube_path(f"CoolantLine_{si}", [
            (sx * 0.84, 0.36, 0.44), (sx * 0.88, 0.26, 0.12), (sx * 0.66, 0.20, -0.18)
        ], 0.015, 8, "copper" if si == 0 else "brass", "plain_metal")
        kb.grab_rail(f"FlankGrab_{si}", 0.28, 0.042, (sx * 0.91, 1.06, -0.24), (0, sx * -90.0, 0), 0.010)

    # 6. Roof Deck, Commander Cupola (Left), Panoramic CITV Dual-Optic Turret (Right), Exhausts
    kb.spaced_armor_plate("RoofDeck", (1.46, 0.92, 0.075), "armor", "armor_panel", (0, 1.32, 0.06), (90, 0, 0))
    kb.louver_bay("RoofRadiator", 0.64, 0.30, 0.060, (0, 1.34, 0.24), (90, 0, 0), blades=5, mesh_style=False)
    kb.cupola_hatch("CmdCupola", (-0.44, 1.35, -0.34))

    # Panoramic CITV Dual-Optic Sight Turret (Right Roof)
    M_citv = g2b_mat((0.44, 1.35, -0.34), (0, 0, 0))
    kb.cyl("CITV_Ped", 0.125, 0.148, 0.11, 16, "dark", "gear_collar", (0, 0.055, 0), (0, 0, 0), 0.006, M_parent=M_citv)
    kb.box("CITV_Head", (0.25, 0.18, 0.23), "armor_sub", "armor_pocket", (0, 0.175, 0), (0, 0, 0), 0.014, 1, M_parent=M_citv)
    kb.box("CITV_Brow", (0.27, 0.026, 0.25), "gunmetal", "bolt_flange", (0, 0.270, -0.01), (6, 0, 0), 0.005, 1, M_parent=M_citv)
    kb.box("CITV_Rec", (0.18, 0.11, 0.036), "bore", "plain_metal", (0, 0.175, -0.105), (0, 0, 0), 0.004, 1, M_parent=M_citv)
    _add_optic_lens(kb, "CITV_FLIR", 0.038, (-0.044, 0.175, -0.116), (90, 0, 0), "emit_cyan", M_parent=M_citv)
    _add_optic_lens(kb, "CITV_TV", 0.026, (0.046, 0.175, -0.116), (90, 0, 0), "emit_amber", M_parent=M_citv)

    for si, sx in enumerate([-0.56, 0.56]):
        _add_exhaust_stack(kb, f"Exhaust_{si}", (sx, 1.42, 0.62), (12, 0, 0), h=0.26)
    _add_whip_antenna(kb, "RearWhip", (-0.64, 1.36, 0.54), h=0.86)

    # 7. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.56, 0.54, w=0.86, d=0.50)
    _add_gen_dock(kb, "GenDock", 0.72, 0.96, w=0.92, h=0.72)

    kb.add_marker("SOCKET_arm_l", (-1.16, 0.82, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.16, 0.82, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.56, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.72, 0.96))


# ==============================================================================
# 2. core_assault — AS-2 / AS-3 Wedge Assault Core
# ==============================================================================

def build_core_assault(kb: KitbashScene):
    """AS-2/AS-3 Wedge Assault Core: 35-deg sloped wedge glacis, twin arm nacelles, 3-periscope bank."""
    # 1. Unified HP-C1 Waist Ring + Dual Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.20)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.28, 0.02, -0.22), (sx * 0.36, 0.24, -0.36), 0.020)

    # 2. Compact Inner CNC Chassis + Lower Belly Tray + HP-A1 Arm Bulkheads
    kb.box("BellyTray", (1.12, 0.22, 1.04), "dark", "frame_cnc", (0, 0.20, 0.04), (0, 0, 0), 0.018, 1)
    kb.box("InnerHull", (1.28, 0.84, 1.18), "dark", "frame_cnc", (0, 0.66, 0.08), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 0.80, 0.45, 0.0)

    # 3. Iconic 35-deg Wedge Glacis + Dual ERA Bricks + Lower -30-deg Chin Armor
    M_gl = g2b_mat((0.0, 0.72, -0.60), (35.0, 0.0, 0.0))
    kb.plate("UpperGlacis", trap_2d(1.34, 1.02, 0.76, 0.07), 0.11, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_gl)
    for ei, ex in enumerate([-0.32, 0.04]):
        kb.era_block(f"FrontERA_{ei}", (0.29, 0.22, 0.058), "armor_sub", (ex, 0.03, -0.072), (0, 0, 0), M_parent=M_gl)
    kb.box("GlacisAccent", (0.98, 0.055, 0.022), "accent", "plain_metal", (0, 0.30, -0.062), (0, 0, 0), 0.004, 1, M_parent=M_gl)
    kb.box("GlacisHazard", (0.24, 0.045, 0.020), "hazard", "hazard", (0.36, -0.18, -0.062), (0, 0, 0), 0.003, 1, M_parent=M_gl)
    kb.grab_rail("GlacisGrab", 0.28, 0.042, (-0.18, 0.28, -0.060), (0, 0, 0), 0.010, M_parent=M_gl)

    kb.plate("LowerChin", trap_2d(1.00, 1.32, 0.36, 0.05), 0.095, "armor_sub", "armor_ribs",
             (0, 0.30, -0.58), (-30, 0, 0), 0.014, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.43, 0.42, -0.74), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.48, 0.20, -0.73), (0, 0, 90), scale=1.0)

    # 4. Twin Armored Arm-Mount Nacelles + Upper Sloped Sponsons + Smoke Pods
    sponson_xy = trap_2d(0.78, 0.58, 0.22, 0.04)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"NacelleSide_{si}", (0.74, 0.54, 0.072), "armor_sub", "armor_hatch",
                              (sx * 0.72, 0.46, 0.05), (0, sx * -90.0, 0))
        kb.plate(f"NacelleCrown_{si}", sponson_xy, 0.30, "armor", "armor_panel",
                 (sx * 0.68, 0.82, 0.04), (0, 90, sx * -8.0), 0.016, 1)
        kb.box(f"NacelleAccent_{si}", (0.32, 0.16, 0.048), "accent", "plain_metal",
               (sx * 0.68, 0.82, -0.18), (0, 0, sx * -8.0), 0.004, 1)
        kb.grab_rail(f"NacelleGrab_{si}", 0.22, 0.038, (sx * 0.68, 0.95, 0.08), (90, 90, 0), 0.009)
        kb.louver_bay(f"NacelleRearVent_{si}", 0.34, 0.17, 0.050, (sx * 0.64, 0.38, 0.50),
                      (0, 180, 0), blades=4, mesh_style=False)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.62, 0.96, -0.34), (-22, sx * -14.0, 0))
        kb.tube_path(f"SideCoolant_{si}", [
            (sx * 0.64, 0.24, 0.34), (sx * 0.68, 0.18, 0.02), (sx * 0.44, 0.16, -0.26)
        ], 0.013, 8, "copper" if si == 0 else "brass", "plain_metal")

    # 5. Roof: 3-Periscope Armored Bank + Commander Cupola (Right) + Stabilized Sight Head (Left)
    kb.spaced_armor_plate("RoofArmor", (1.20, 0.68, 0.068), "armor", "armor_panel", (0, 1.08, -0.06), (90, 0, 0))
    for pi, px in enumerate([-0.26, 0.0, 0.26]):
        _add_periscope(kb, f"RoofPeri_{pi}", 0.16, 0.088, (px, 1.13, -0.36), (0, (pi - 1) * -18.0, 0))
    kb.cupola_hatch("CmdCupola", (0.24, 1.11, 0.08))

    # Left Stabilized Twin-Optic Gunnery Sight Head
    M_sh = g2b_mat((-0.36, 1.17, -0.18), (0, 0, 0))
    kb.plate("SightHead", crect_2d(0.32, 0.19, (0.05, 0.02, 0.02, 0.04)), 0.30, "armor", "armor_pocket",
             (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_sh)
    kb.box("SightBrow", (0.34, 0.024, 0.11), "gunmetal", "bolt_flange", (0, 0.088, -0.135), (8, 0, 0), 0.004, 1, M_parent=M_sh)
    _add_optic_lens(kb, "SightOpt_L", 0.030, (-0.068, -0.008, -0.156), (90, 0, 0), "emit_amber", M_parent=M_sh)
    _add_optic_lens(kb, "SightOpt_R", 0.026, (0.068, -0.008, -0.156), (90, 0, 0), "emit_cyan", M_parent=M_sh)
    kb.tube_path("SightCable", [(-0.46, 1.12, -0.06), (-0.52, 1.06, 0.08), (-0.44, 1.02, 0.20)],
                 0.011, 8, "gunmetal", "braid_hose")

    # 6. Rear Sloped Engine Deck (14-deg) + Twin Side Radiator Louver Bays + Exhausts + Whip
    for si, sx in enumerate([-0.50, 0.50]):
        kb.louver_bay(f"DeckVent_{si}", 0.22, 0.44, 0.048, (sx, 1.09, 0.42), (76, 0, 0),
                      blades=5, mesh_style=(si == 1))
        _add_exhaust_stack(kb, f"Exhaust_{si}", (sx * 0.92, 1.12, 0.64), (16, 0, 0), h=0.22)
    _add_whip_antenna(kb, "CommsWhip", (-0.55, 1.08, 0.55), h=0.88)

    # 7. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.06, 0.40, w=0.78, d=0.46, tilt_deg=-14.0)
    _add_gen_dock(kb, "GenDock", 0.55, 0.68, w=0.90, h=0.68)

    kb.add_marker("SOCKET_arm_l", (-0.80, 0.45, 0.0))
    kb.add_marker("SOCKET_arm_r", (0.80, 0.45, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  1.06, 0.40))
    kb.add_marker("SOCKET_gen",   (0.0,  0.55, 0.68))


# ==============================================================================
# 3. core_bmpt_terminator — BMPT-72 Terminator Urban Fire Support Core
# ==============================================================================

def build_core_bmpt_terminator(kb: KitbashScene):
    """BMPT-72 Terminator Core: twin shoulder AGS-30 30mm grenade sponsons, 5x Kontakt-5 ERA, slat cages."""
    # 1. Unified HP-C1 Waist Ring + Dual Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.24)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.05, -0.30), (sx * 0.34, 0.34, -0.44), 0.022)

    # 2. Armored Heavy Urban Chassis + HP-A1 Arm Bulkheads
    kb.box("InnerHull", (1.58, 1.00, 1.44), "dark", "frame_cnc", (0, 0.75, 0.06), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("LowerBelly", (1.30, 0.18, 1.20), "armor_dark", "armor_ribs", (0, 0.22, 0.04), (0, 0, 0), 0.014, 1)
    kb.arm_bulkhead("ArmMount", 1.14, 0.80, 0.04)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"ShoulderPylon_{si}", (0.30, 0.48, 0.54), "armor_sub", "armor_pocket",
               (sx * 0.92, 0.80, 0.04), (0, 0, 0), 0.016, 1)

    # 3. Frontal 5-Block Kontakt-5 ERA Array + Driver Armored Periscope Hood + Headlights
    M_era = g2b_mat((0.0, 0.62, -0.76), (34.0, 0.0, 0.0))
    kb.plate("GlacisBacking", trap_2d(1.48, 1.32, 0.46, 0.06), 0.12, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_era)
    for ki, kx in enumerate([-0.46, -0.23, 0.0, 0.23, 0.46]):
        kb.era_block(f"Kontakt5_{ki}", (0.21, 0.26, 0.062), "armor_sub" if ki % 2 == 1 else "armor",
                     (kx, 0.0, -0.095), (0, 0, 0), M_parent=M_era)
    kb.box("DriverHood", (0.38, 0.17, 0.24), "armor_sub", "armor_hatch", (0, 0.92, -0.68), (0, 0, 0), 0.014, 1)
    _add_periscope(kb, "DriverPeri", 0.28, 0.085, (0, 0.94, -0.76), (4, 0, 0))
    kb.box("FrontHazard", (0.42, 0.042, 0.020), "hazard", "hazard", (0, 0.36, -0.82), (-20, 0, 0), 0.003, 1)

    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.58, 0.42, -0.82), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.34, 0.26, -0.80), (0, 0, 90), scale=1.1)

    # 4. Signature Twin Front Shoulder AGS-30 30mm Automatic Grenade Sponsons + Ammo Snail Drums
    mantlet_xy = trap_2d(0.38, 0.30, 0.26, 0.04)
    for si, sx in enumerate([-1.0, 1.0]):
        M_ags = g2b_mat((sx * 0.66, 0.94, -0.64), (0, 0, 0))
        kb.box(f"AGSHouse_{si}", (0.42, 0.32, 0.48), "armor", "armor_pocket", (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_ags)
        kb.plate(f"AGSMantlet_{si}", mantlet_xy, 0.080, "armor_sub", "armor_ribs",
                 (0, 0.02, -0.24), (18, 0, 0), 0.012, 1, M_parent=M_ags)
        # Shroud + 30mm Barrel + Real Hollow Barrel Bore
        kb.cyl(f"AGSShroud_{si}", 0.048, 0.056, 0.22, 14, "dark", "vent_mesh",
               (0, -0.02, -0.32), (90, 0, 0), 0.004, M_parent=M_ags)
        kb.cyl(f"AGSBarrel_{si}", 0.031, 0.033, 0.20, 12, "gunmetal", "plain_metal",
               (0, -0.02, -0.47), (90, 0, 0), 0.003, M_parent=M_ags)
        kb.barrel_bore(f"AGSMuzzle_{si}", 0.034, 0.022, (0, -0.02, -0.575), depth=0.065, rot_deg=(90, 0, 0), segs=12, M_parent=M_ags)
        # External Side Circular Ammo Snail-Drum + 6-Bolt Flange + Braided Feed Chute
        kb.cyl(f"AGSDrum_{si}", 0.125, 0.125, 0.088, 16, "dark", "armor_hatch",
               (sx * 0.22, -0.01, -0.04), (0, 0, 90), 0.006, M_parent=M_ags)
        kb.bolt_ring(f"AGSDrumBolt_{si}", 0.086, 6, 0.010,
                     (sx * 0.266, -0.01, -0.04), (0, 0, sx * -90.0), M_parent=M_ags)
        kb.tube_path(f"AGSFeed_{si}", [
            (sx * 0.20, -0.10, 0.04), (sx * 0.18, -0.18, 0.18), (sx * 0.06, -0.16, 0.28)
        ], 0.014, 8, "gunmetal", "braid_hose", M_parent=M_ags)

    # 5. Side Urban Survivability: Backing Plate + 3x Side ERA Bricks + Rear Anti-RPG Slat Cages
    skirt_xy = crect_2d(1.12, 0.34, (0.05, 0.05, 0.05, 0.05))
    for si, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"SideSkirt_{si}", skirt_xy, 0.055, "armor_sub", "armor_panel",
                 (sx * 0.96, 0.48, 0.02), (0, 90, 0), 0.010, 1)
        for ei, ez in enumerate([-0.34, 0.0, 0.34]):
            kb.era_block(f"SideERA_{si}_{ei}", (0.30, 0.28, 0.050), "armor" if ei % 2 == 0 else "armor_sub",
                         (sx * 1.02, 0.48, ez), (0, sx * -90.0, 0))
        _add_slat_cage(kb, f"RearSlat_{si}", sx * 1.06, 0.62, 0.36, 0.76, h=0.46, n_bars=4)
        kb.louver_bay(f"SideVent_{si}", 0.36, 0.20, 0.050, (sx * 0.84, 1.02, 0.34),
                      (0, sx * -90.0, 0), blades=4, mesh_style=(si == 0))
        kb.tube_path(f"Coolant_{si}", [
            (sx * 0.80, 0.30, 0.46), (sx * 0.84, 0.24, 0.08), (sx * 0.56, 0.20, -0.22)
        ], 0.014, 8, "copper" if si == 0 else "brass", "plain_metal")

    # 6. Roof: Left Ramka Stabilized Fire-Control Turret + Right Commander Cupola + Exhausts
    kb.spaced_armor_plate("RoofArmor", (1.44, 0.88, 0.072), "armor", "armor_panel", (0, 1.26, 0.04), (90, 0, 0))
    M_ramka = g2b_mat((-0.40, 1.29, -0.28), (0, 0, 0))
    kb.cyl("Ramka_Ped", 0.20, 0.24, 0.16, 16, "armor_sub", "gear_collar", (0, 0.08, 0), (0, 0, 0), 0.008, M_parent=M_ramka)
    kb.box("Ramka_Body", (0.35, 0.21, 0.28), "armor", "armor_pocket", (0, 0.24, 0), (0, 0, 0), 0.015, 1, M_parent=M_ramka)
    _add_periscope(kb, "Ramka_Eye", 0.19, 0.11, (0, 0.24, -0.145), (0, 0, 0), glass_slot="emit_amber", M_parent=M_ramka)
    kb.grab_rail("Ramka_Grab", 0.20, 0.036, (0, 0.36, 0.04), (90, 0, 0), 0.009, M_parent=M_ramka)

    kb.cupola_hatch("CmdCupola", (0.42, 1.29, -0.30))
    for si, sx in enumerate([-0.54, 0.54]):
        _add_exhaust_stack(kb, f"Exhaust_{si}", (sx, 1.38, 0.62), (12, 0, 0), h=0.25)
    _add_whip_antenna(kb, "TacticalWhip", (0.62, 1.30, 0.50), h=0.90)

    # 7. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.52, 0.54, w=0.84, d=0.50)
    _add_gen_dock(kb, "GenDock", 0.68, 0.96, w=0.92, h=0.72)

    kb.add_marker("SOCKET_arm_l", (-1.14, 0.80, 0.04))
    kb.add_marker("SOCKET_arm_r", (1.14, 0.80, 0.04))
    kb.add_marker("SOCKET_back",  (0.0,  1.52, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.68, 0.96))


# ==============================================================================
# 4. core_bradley_busk — M2A4-BK Bradley Urban Survival Kit Core
# ==============================================================================

def build_core_bradley_busk(kb: KitbashScene):
    """M2A4-BK Bradley BUSK Core: 46-deg glacis w/ right louver + BRAT ERA belt, Driver Shield & ISU."""
    # 1. Unified HP-C1 Waist Ring + Dual Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.24)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.05, -0.30), (sx * 0.34, 0.34, -0.44), 0.022)

    # 2. High-Profile Angular Bradley Hull + HP-A1 Arm Bulkheads
    kb.box("InnerHull", (1.54, 1.06, 1.44), "dark", "frame_cnc", (0, 0.77, 0.06), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("LowerBelly", (1.26, 0.16, 1.22), "armor_dark", "armor_ribs", (0, 0.22, 0.04), (0, 0, 0), 0.014, 1)
    kb.arm_bulkhead("ArmMount", 1.12, 0.80, 0.02)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"ShoulderPylon_{si}", (0.30, 0.48, 0.54), "armor_sub", "armor_pocket",
               (sx * 0.89, 0.80, 0.02), (0, 0, 0), 0.016, 1)

    # 3. 46-deg Bradley Glacis: Right Powerpack Intake Louver Bay + Left Dual Tall BRAT ERA
    M_gl = g2b_mat((0.0, 0.90, -0.68), (46.0, 0.0, 0.0))
    kb.plate("BradleyGlacis", trap_2d(1.48, 1.36, 0.56, 0.06), 0.12, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_gl)
    kb.louver_bay("GlacisEngineVent", 0.56, 0.34, 0.052, (0.34, 0.02, -0.072), (0, 0, 0),
                  blades=6, mesh_style=False, M_parent=M_gl)
    for ei, ex in enumerate([-0.46, -0.14]):
        kb.era_block(f"UpperBRAT_{ei}", (0.28, 0.34, 0.070), "armor_sub", (ex, 0.0, -0.088), (0, 0, 0), M_parent=M_gl)

    # Lower -18-deg BUSK Belt with 4 Heavy BRAT ERA Bricks + Headlights + Tow Shackles
    M_belt = g2b_mat((0.0, 0.50, -0.82), (-18.0, 0.0, 0.0))
    kb.box("LowerBUSKBelt", (1.46, 0.32, 0.16), "armor_sub", "armor_ribs", (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_belt)
    for bi, bx in enumerate([-0.48, -0.16, 0.16, 0.48]):
        kb.era_block(f"LowerBRAT_{bi}", (0.28, 0.24, 0.078), "armor" if bi % 2 == 0 else "armor_sub",
                     (bx, 0.0, -0.112), (0, 0, 0), M_parent=M_belt)
    kb.box("FrontHazard", (0.50, 0.042, 0.020), "hazard", "hazard", (0, -0.17, -0.082), (0, 0, 0), 0.003, 1, M_parent=M_belt)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.62, 0.72, -0.85), (0, sx * -8.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.36, 0.28, -0.84), (0, 0, 90), scale=1.08)

    # 4. Left-Roof Driver BUSK Transparent Armor Shield Cage (3 Angled Periscopes)
    kb.spaced_armor_plate("RoofDeck", (1.42, 0.88, 0.072), "armor", "armor_panel", (0, 1.30, 0.04), (90, 0, 0))
    M_drv = g2b_mat((-0.42, 1.32, -0.40), (0, 0, 0))
    kb.box("DriverRing", (0.44, 0.16, 0.36), "armor", "armor_hatch", (0, 0.06, 0), (0, 0, 0), 0.014, 1, M_parent=M_drv)
    _add_periscope(kb, "BUSK_PeriC", 0.15, 0.092, (0.0, 0.18, -0.15), (0, 0, 0), "glass", M_parent=M_drv)
    _add_periscope(kb, "BUSK_PeriL", 0.14, 0.090, (-0.18, 0.18, -0.13), (0, 42, 0), "glass", M_parent=M_drv)
    _add_periscope(kb, "BUSK_PeriR", 0.14, 0.090, (0.18, 0.18, -0.13), (0, -42, 0), "glass", M_parent=M_drv)
    kb.grab_rail("DriverCageBar", 0.38, 0.048, (0, 0.25, -0.16), (0, 0, 0), 0.009, M_parent=M_drv)

    # 5. Right-Roof Bradley ISU (Integrated Sight Unit) Boxy FLIR/Day Optical Turret
    M_isu = g2b_mat((0.42, 1.32, -0.34), (0, 0, 0))
    kb.box("ISU_Body", (0.38, 0.27, 0.34), "armor", "armor_pocket", (0, 0.13, 0), (0, 0, 0), 0.016, 1, M_parent=M_isu)
    kb.box("ISU_Hood", (0.40, 0.026, 0.12), "gunmetal", "bolt_flange", (0, 0.27, -0.15), (8, 0, 0), 0.004, 1, M_parent=M_isu)
    kb.box("ISU_Rec", (0.30, 0.18, 0.045), "bore", "plain_metal", (0, 0.13, -0.16), (0, 0, 0), 0.005, 1, M_parent=M_isu)
    _add_optic_lens(kb, "ISU_FLIR", 0.048, (-0.065, 0.13, -0.172), (90, 0, 0), "emit_cyan", M_parent=M_isu)
    _add_optic_lens(kb, "ISU_Day", 0.032, (0.068, 0.13, -0.172), (90, 0, 0), "emit_amber", M_parent=M_isu)

    # 6. Twin 4-Tube Smoke Dischargers + Dense 2x3 Side BRAT ERA Box Tiles + Stowage & Coolant
    skirt_xy = crect_2d(1.14, 0.44, (0.05, 0.05, 0.05, 0.05))
    for si, sx in enumerate([-1.0, 1.0]):
        # 4-Tube Forward Smoke Discharger Bank (matching bradley_busk.gd)
        M_sm = g2b_mat((sx * 0.78, 1.18, -0.54), (-22.0, sx * -16.0, 0.0))
        kb.box(f"SmokeRack_{si}", (0.34, 0.046, 0.090), "gunmetal", "bolt_flange", (0, -0.038, 0.035), (0, 0, 0), 0.005, 1, M_parent=M_sm)
        for k in range(4):
            tx = (k - 1.5) * 0.078
            kb.cyl(f"SmokeTube_{si}_{k}", 0.034, 0.033, 0.18, 12, "dark", "plain_metal",
                   (tx, 0.01, -0.01), (90, 0, 0), 0.004, hollow_r=0.023, M_parent=M_sm)
            kb.cyl(f"SmokeCap_{si}_{k}", 0.037, 0.037, 0.020, 12, "brass", "gear_collar",
                   (tx, 0.01, 0.075), (90, 0, 0), 0.003, M_parent=M_sm)
        # Side BRAT Box ERA Array (2 rows x 3 cols = 6 tiles per side)
        kb.plate(f"SideBacking_{si}", skirt_xy, 0.050, "armor_sub", "armor_ribs",
                 (sx * 0.96, 0.54, 0.02), (0, 90, 0), 0.010, 1)
        for ri, ry in enumerate([0.44, 0.64]):
            for ci, cz in enumerate([-0.34, 0.02, 0.38]):
                kb.era_block(f"SideBRAT_{si}_{ri}_{ci}", (0.31, 0.175, 0.052),
                             "armor" if (ri + ci) % 2 == 0 else "armor_sub",
                             (sx * 1.02, ry, cz), (0, sx * -90.0, 0))
        kb.tube_path(f"SideHyd_{si}", [
            (sx * 0.84, 0.30, 0.44), (sx * 0.86, 0.24, 0.02), (sx * 0.56, 0.22, -0.32)
        ], 0.014, 8, "copper" if si == 0 else "gunmetal", "plain_metal" if si == 0 else "braid_hose")

    kb.stowage_rack("RearStowage", (0.0, 1.36, 0.14), (90, 0, 0))
    for si, sx in enumerate([-0.54, 0.54]):
        _add_exhaust_stack(kb, f"Exhaust_{si}", (sx, 1.40, 0.62), (12, 0, 0), h=0.24)
    _add_whip_antenna(kb, "RearWhip", (-0.64, 1.32, 0.48), h=0.92)

    # 7. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.54, 0.54, w=0.84, d=0.50)
    _add_gen_dock(kb, "GenDock", 0.70, 0.94, w=0.92, h=0.72)

    kb.add_marker("SOCKET_arm_l", (-1.12, 0.80, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.12, 0.80, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.54, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.70, 0.94))


# ==============================================================================
# 5. core_command — CMD-1 / CM-7 Tactical Command Bridge Core
# ==============================================================================

def build_core_command(kb: KitbashScene):
    """CMD-1/CM-7 Tactical Command Core: tall armored bridge, 3-pane visor, AESA mast, twin comms pods."""
    # 1. Unified HP-C1 Waist Ring + Dual Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.20)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.26, 0.02, -0.22), (sx * 0.34, 0.24, -0.34), 0.020)

    # 2. Tall Command Hull Chassis + HP-A1 Arm Bulkheads
    kb.box("BellyTray", (1.06, 0.22, 0.96), "dark", "frame_cnc", (0, 0.20, 0.04), (0, 0, 0), 0.018, 1)
    kb.box("InnerHull", (1.18, 0.98, 1.08), "dark", "frame_cnc", (0, 0.74, 0.05), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 0.75, 0.42, 0.0)

    # 3. Armored Tactical Bridge Front (12-deg tilt) + Wide 3-Pane Bulletproof Visor + Chin EO/IR
    M_br = g2b_mat((0.0, 0.76, -0.54), (12.0, 0.0, 0.0))
    kb.plate("BridgeFront", crect_2d(1.16, 0.84, (0.20, 0.20, 0.10, 0.10)), 0.14, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_br)
    # Recessed 3-Pane Armored Bridge Visor
    kb.box("VisorFrame", (0.90, 0.18, 0.085), "dark", "frame_cnc", (0, 0.20, -0.080), (0, 0, 0), 0.010, 1, M_parent=M_br)
    kb.box("VisorRecess", (0.80, 0.10, 0.028), "bore", "plain_metal", (0, 0.20, -0.115), (0, 0, 0), 0.003, 1, M_parent=M_br)
    kb.box("VisorBrow", (0.94, 0.036, 0.135), "gunmetal", "bolt_flange", (0, 0.29, -0.115), (10, 0, 0), 0.006, 1, M_parent=M_br)
    for pi, (px, pw) in enumerate([(-0.26, 0.23), (0.0, 0.24), (0.26, 0.23)]):
        kb.box(f"VisorGlass_{pi}", (pw, 0.078, 0.018), "glass", "plain_metal", (px, 0.20, -0.126), (0, 0, 0), 0.002, 1, M_parent=M_br)
    for mi, mx in enumerate([-0.135, 0.135]):
        kb.box(f"VisorMullion_{mi}", (0.026, 0.125, 0.048), "dark", "bolt_flange", (mx, 0.20, -0.130), (0, 0, 0), 0.004, 1, M_parent=M_br)
        kb.cyl(f"MullionPin_{mi}", 0.008, 0.010, 0.014, 6, "chrome", "plain_metal", (mx, 0.20, -0.156), (90, 0, 0), 0.002, M_parent=M_br)
    kb.grab_rail("VisorGuard", 0.84, 0.052, (0, 0.14, -0.125), (0, 0, 0), 0.008, M_parent=M_br)
    kb.box("BridgeAccent", (0.98, 0.052, 0.026), "accent", "plain_metal", (0, -0.22, -0.075), (0, 0, 0), 0.004, 1, M_parent=M_br)
    kb.box("BridgeHazard", (0.28, 0.046, 0.020), "hazard", "hazard", (0.30, -0.06, -0.075), (0, 0, 0), 0.003, 1, M_parent=M_br)

    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.40, 0.38, -0.64), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.26, 0.22, -0.62), (0, 0, 90), scale=1.0)
    kb.eoir_gimbal("ChinDatalinkEOIR", (0.0, 0.22, -0.58))

    # 4. Shoulder Blocks + Elevated Encrypted Comms Pods + Smoke Pods + Braided Coax Runs
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"SideArmor_{si}", (0.66, 0.54, 0.070), "armor_sub", "armor_hatch",
                              (sx * 0.65, 0.44, 0.02), (0, sx * -90.0, 0))
        # Elevated Shoulder Comms Box
        kb.box(f"CommsPod_{si}", (0.36, 0.26, 0.50), "armor", "armor_pocket",
               (sx * 0.60, 1.36, 0.0), (0, 0, 0), 0.016, 1)
        kb.louver_bay(f"CommsVent_{si}", 0.28, 0.14, 0.044, (sx * 0.60, 1.36, -0.26), (0, 0, 0), blades=4, mesh_style=False)
        kb.box(f"CommsAccent_{si}", (0.036, 0.052, 0.26), "accent", "plain_metal",
               (sx * 0.785, 1.36, 0.0), (0, 0, 0), 0.004, 1)
        kb.grab_rail(f"CommsGrab_{si}", 0.20, 0.038, (sx * 0.60, 1.50, 0.0), (90, 90, 0), 0.009)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.58, 1.12, -0.44), (-22, sx * -18.0, 0))
        kb.tube_path(f"CommsConduit_{si}", [
            (sx * 0.60, 1.24, 0.16), (sx * 0.68, 1.04, 0.24), (sx * 0.62, 0.84, 0.26)
        ], 0.014, 8, "copper" if si == 0 else "gunmetal", "plain_metal" if si == 0 else "braid_hose")

    # 5. Composite Phased-Array Recon Mast (Left Front) + SATCOM Radome (Right Roof) + Dual Whips
    kb.spaced_armor_plate("RoofDeck", (1.14, 0.64, 0.068), "armor", "armor_panel", (0, 1.24, -0.06), (90, 0, 0))
    kb.cyl("MastBase", 0.095, 0.110, 0.085, 16, "gunmetal", "gear_collar", (-0.42, 1.29, -0.30), (0, 0, 0), 0.005)
    kb.cyl("MastCol", 0.054, 0.060, 0.54, 12, "dark", "frame_cnc", (-0.42, 1.56, -0.30), (0, 0, 0), 0.005)
    M_aesa = g2b_mat((-0.42, 1.88, -0.30), (0, -22, 0))
    kb.box("AESA_Back", (0.54, 0.30, 0.085), "armor_sub", "armor_panel", (0, 0, 0), (-10, 0, 0), 0.014, 1, M_parent=M_aesa)
    kb.box("AESA_Face", (0.46, 0.22, 0.022), "armor_dark", "vent_mesh", (0, 0, -0.048), (-10, 0, 0), 0.004, 1, M_parent=M_aesa)
    for gi, gx in enumerate([-0.24, 0.24]):
        kb.grab_rail(f"AESA_Guard_{gi}", 0.14, 0.036, (gx, 0, -0.02), (0, 0, 90), 0.008, M_parent=M_aesa)
    kb.cyl("MastEO_Neck", 0.042, 0.052, 0.08, 12, "gunmetal", "gear_collar", (0, 0.18, 0), (0, 0, 0), 0.003, M_parent=M_aesa)
    kb.box("MastEO_Head", (0.14, 0.12, 0.14), "dark", "armor_pocket", (0, 0.25, 0), (0, 0, 0), 0.020, 1, M_parent=M_aesa)
    _add_optic_lens(kb, "MastEO_Lens", 0.030, (0, 0.25, -0.072), (90, 0, 0), "emit_cyan", M_parent=M_aesa)

    # Right Roof Low-Profile SATCOM Radome Dish + Dual Spring Whip Antennas
    kb.cyl("SatcomBase", 0.19, 0.22, 0.072, 18, "armor", "bolt_flange", (0.22, 1.29, -0.18), (0, 0, 0), 0.007)
    kb.cyl("SatcomDome", 0.14, 0.17, 0.040, 16, "armor_sub", "armor_hatch", (0.22, 1.34, -0.18), (0, 0, 0), 0.005)
    kb.bolt_ring("SatcomBolts", 0.18, 8, 0.009, (0.22, 1.33, -0.18), (0, 0, 0))
    _add_whip_antenna(kb, "Whip_1", (0.56, 1.49, 0.12), h=0.98, tilt_x=-4.0)
    _add_whip_antenna(kb, "Whip_2", (0.72, 1.49, 0.12), h=0.76, tilt_x=-8.0)

    # Rear Cooling + Exhausts
    kb.louver_bay("RearCooler", 0.44, 0.20, 0.048, (0, 1.06, 0.56), (0, 180, 0), blades=4, mesh_style=True)
    for si, sx in enumerate([-0.42, 0.42]):
        _add_exhaust_stack(kb, f"Exhaust_{si}", (sx, 1.24, 0.54), (14, 0, 0), h=0.22)

    # 6. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.22, 0.30, w=0.82, d=0.44, tilt_deg=-14.0)
    _add_gen_dock(kb, "GenDock", 0.60, 0.60, w=0.88, h=0.68)

    kb.add_marker("SOCKET_arm_l", (-0.75, 0.42, 0.0))
    kb.add_marker("SOCKET_arm_r", (0.75, 0.42, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  1.22, 0.30))
    kb.add_marker("SOCKET_gen",   (0.0,  0.60, 0.60))


# ==============================================================================
# 6. core_fennek_recon — FNK-4 Low-Profile Stealth Recon Core
# ==============================================================================

def build_core_fennek_recon(kb: KitbashScene):
    """FNK-4 Fennek Stealth Recon Core: lowest faceted stealth hull, 3-way visor, BAA 3-in-1 recon mast."""
    # 1. Unified HP-C1 Waist Ring + Compact Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.22)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.28), (sx * 0.32, 0.28, -0.42), 0.020)

    # 2. Low-Profile Compact Stealth Chassis + HP-A1 Arm Bulkheads
    kb.box("InnerHull", (1.30, 0.74, 1.34), "dark", "frame_cnc", (0, 0.62, 0.06), (0, 0, 0), 0.022, 1, tile_u=2.0)
    kb.box("LowerSkid", (1.06, 0.14, 1.14), "armor_dark", "armor_ribs", (0, 0.20, 0.04), (0, 0, 0), 0.012, 1)
    kb.arm_bulkhead("ArmMount", 0.94, 0.64, 0.02)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"ShoulderPylon_{si}", (0.24, 0.44, 0.52), "armor_sub", "armor_pocket",
               (sx * 0.74, 0.64, 0.02), (0, 0, 0), 0.015, 1)

    # 3. Multi-Faceted Stealth Prow (64-deg Upper + -54-deg Lower) + 3-Way Anti-Laser Visor Bank
    kb.plate("StealthUpperGlacis", trap_2d(1.32, 1.04, 0.54, 0.07), 0.11, "armor", "armor_panel",
             (0, 0.80, -0.74), (64, 0, 0), 0.016, 1)
    kb.plate("StealthLowerChin", trap_2d(1.28, 0.98, 0.44, 0.06), 0.11, "armor_sub", "armor_ribs",
             (0, 0.48, -0.76), (-54, 0, 0), 0.015, 1)
    kb.box("StealthNoseHazard", (0.30, 0.036, 0.018), "hazard", "hazard", (0, 0.66, -0.92), (0, 0, 0), 0.003, 1)
    kb.box("VisorCab", (0.98, 0.24, 0.34), "armor", "armor_hatch", (0, 0.96, -0.50), (0, 0, 0), 0.016, 1)
    _add_periscope(kb, "FennekVisorC", 0.40, 0.125, (0.0, 0.99, -0.67), (12, 0, 0), "glass")
    _add_periscope(kb, "FennekVisorL", 0.26, 0.115, (-0.35, 0.99, -0.61), (10, 36, 0), "glass")
    _add_periscope(kb, "FennekVisorR", 0.26, 0.115, (0.35, 0.99, -0.61), (10, -36, 0), "glass")
    kb.grab_rail("ProwGrab", 0.34, 0.038, (0, 0.88, -0.74), (64, 0, 0), 0.009)

    # 4. Faceted Tumblehome Side Stealth Skirts + Caged Headlights + Tow Shackles + Smoke Pods
    skirt_xy = trap_2d(1.18, 0.96, 0.34, 0.05)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"StealthSkirt_{si}", skirt_xy, 0.10, "armor_sub", "armor_panel",
                 (sx * 0.74, 0.66, 0.02), (0, 90, sx * -18.0), 0.015, 1)
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.48, 0.54, -0.85), (0, sx * -12.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.28, 0.30, -0.84), (0, 0, 90), scale=0.95)
        kb.louver_bay(f"SideMesh_{si}", 0.34, 0.16, 0.046, (sx * 0.76, 0.84, 0.32),
                      (0, sx * -90.0, 0), blades=4, mesh_style=(si == 1))
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.62, 0.98, -0.30), (-20, sx * -18.0, 0))
        kb.tube_path(f"ReconCoolant_{si}", [
            (sx * 0.68, 0.34, 0.40), (sx * 0.72, 0.28, 0.04), (sx * 0.48, 0.24, -0.32)
        ], 0.013, 8, "copper" if si == 0 else "brass", "plain_metal")

    # 5. Signature Telescoping BAA 3-in-1 Thermal/Laser/TV Recon Mast (Left Roof)
    kb.spaced_armor_plate("RoofArmor", (1.22, 0.80, 0.068), "armor", "armor_panel", (0, 1.00, 0.04), (90, 0, 0))
    M_baa = g2b_mat((-0.38, 1.02, -0.24), (0, 0, 0))
    kb.cyl("BAA_BaseTube", 0.088, 0.108, 0.24, 14, "dark", "gear_collar", (0, 0.12, 0), (0, 0, 0), 0.006, M_parent=M_baa)
    kb.cyl("BAA_Seal", 0.092, 0.092, 0.028, 14, "brass", "bolt_flange", (0, 0.24, 0), (0, 0, 0), 0.003, M_parent=M_baa)
    kb.cyl("BAA_ChromeMast", 0.056, 0.056, 0.22, 12, "chrome", "plain_metal", (0, 0.34, 0), (0, 0, 0), 0.003, M_parent=M_baa)
    kb.box("BAA_Head", (0.32, 0.20, 0.24), "armor", "armor_pocket", (0, 0.48, 0), (0, 0, 0), 0.014, 1, M_parent=M_baa)
    kb.box("BAA_Brow", (0.34, 0.022, 0.10), "gunmetal", "bolt_flange", (0, 0.59, -0.10), (8, 0, 0), 0.004, 1, M_parent=M_baa)
    _add_optic_lens(kb, "BAA_FLIR", 0.044, (-0.085, 0.48, -0.126), (90, 0, 0), "emit_cyan", M_parent=M_baa)
    _add_optic_lens(kb, "BAA_Laser", 0.032, (0.012, 0.48, -0.126), (90, 0, 0), "emit_amber", M_parent=M_baa)
    _add_optic_lens(kb, "BAA_TV", 0.024, (0.095, 0.48, -0.126), (90, 0, 0), "glass", M_parent=M_baa)
    kb.tube_path("BAA_Umbilical", [
        (-0.46, 1.46, -0.14), (-0.54, 1.24, -0.06), (-0.48, 1.04, 0.04)
    ], 0.012, 8, "gunmetal", "braid_hose")

    # Right Roof Commander Hatch + Top Engine Radiator Bay + Rear Stowage & Whips
    kb.cupola_hatch("CmdCupola", (0.36, 1.03, -0.26))
    kb.louver_bay("TopEngineVent", 0.38, 0.24, 0.048, (0.34, 1.03, 0.18), (90, 0, 0), blades=4, mesh_style=False)
    kb.stowage_rack("LeftStowage", (-0.36, 1.08, 0.16), (90, 0, 0))
    _add_whip_antenna(kb, "Whip_L", (-0.58, 1.04, 0.48), h=0.92)
    _add_whip_antenna(kb, "Whip_R", (0.58, 1.04, 0.48), h=0.68, tilt_x=-10.0)

    # 6. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.28, 0.48, w=0.80, d=0.46)
    _add_gen_dock(kb, "GenDock", 0.58, 0.86, w=0.88, h=0.68)

    kb.add_marker("SOCKET_arm_l", (-0.94, 0.64, 0.02))
    kb.add_marker("SOCKET_arm_r", (0.94, 0.64, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.28, 0.48))
    kb.add_marker("SOCKET_gen",   (0.0,  0.58, 0.86))


# ==============================================================================
# 7. core_fortress — FT-5 / FT-9 Super-Heavy Fortress Core
# ==============================================================================

def build_core_fortress(kb: KitbashScene):
    """FT-5/FT-9 Super-Heavy Fortress Core: ultra-wide hull, 3 standoff glacis slabs, slat cages, twin roof cabs."""
    # 1. Unified HP-C1 Waist Ring + 6 Heavy Waist Gussets + Twin Heavy Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.28)
    for gi in range(4):
        ga = math.tau * gi / 4.0 + math.pi * 0.25
        kb.box(f"WaistGusset_{gi}", (0.064, 0.16, 0.22), "gunmetal", "bolt_flange",
               (math.cos(ga) * 0.44, 0.26, math.sin(ga) * 0.44), (0, -math.degrees(ga) + 90.0, 0), 0.008, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.28, 0.06, -0.32), (sx * 0.42, 0.40, -0.52), 0.026)

    # 2. Ultra-Wide Fortress Chassis + Lower Load Tray + HP-A1 Arm Bulkheads
    kb.box("BellyTray", (1.50, 0.24, 1.60), "dark", "frame_cnc", (0, 0.26, 0.10), (0, 0, 0), 0.020, 1)
    kb.box("InnerHull", (1.72, 1.44, 1.84), "dark", "frame_cnc", (0, 1.00, 0.14), (0, 0, 0), 0.030, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.10, 0.85, 0.0)

    # 3. Sloped 24-deg Main Glacis + 3 Spaced Standoff Composite Hanging Slabs + Lower Chin
    M_gl = g2b_mat((0.0, 1.10, -0.94), (24.0, 0.0, 0.0))
    kb.plate("MainGlacis", trap_2d(1.78, 1.40, 1.26, 0.10), 0.20, "armor_sub", "armor_ribs",
             (0, 0, 0), (0, 0, 0), 0.020, 1, M_parent=M_gl)
    slab_xy = crect_2d(0.49, 1.04, (0.07, 0.07, 0.04, 0.04))
    for i, px in enumerate([-0.53, 0.0, 0.53]):
        kb.plate(f"HangSlab_{i}", slab_xy, 0.14, "armor", "armor_panel",
                 (px, 0.0, -0.22), (0, 0, 0), 0.018, 1, M_parent=M_gl)
        for bi, (ox, oy) in enumerate([(0.0, 0.36), (0.0, -0.36)]):
            kb.cyl(f"StandoffPin_{i}_{bi}", 0.030, 0.030, 0.11, 8, "dark", "plain_metal",
                   (px + ox, oy, -0.10), (90, 0, 0), 0.003, M_parent=M_gl)
            kb.cyl(f"SlabBolt_{i}_{bi}", 0.020, 0.022, 0.022, 6, "chrome", "plain_metal",
                   (px + ox, oy, -0.30), (90, 0, 0), 0.002, M_parent=M_gl)
    kb.box("GlacisAccent", (1.48, 0.068, 0.030), "accent", "plain_metal", (0, 0.58, -0.24), (0, 0, 0), 0.004, 1, M_parent=M_gl)
    kb.box("GlacisHazard", (0.44, 0.055, 0.024), "hazard", "hazard", (0, -0.52, -0.24), (0, 0, 0), 0.003, 1, M_parent=M_gl)

    kb.plate("LowerChin", trap_2d(1.30, 1.74, 0.48, 0.07), 0.18, "armor", "armor_hatch",
             (0, 0.42, -0.92), (-30, 0, 0), 0.018, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.64, 0.62, -1.10), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.38, 0.32, -1.08), (0, 0, 90), scale=1.25)

    # 4. Wide Side Sponsons + Front ERA + Sloped Pauldrons + Rear Anti-RPG Slat Cages + Smoke Pods
    pauldron_xy = trap_2d(1.36, 0.98, 0.28, 0.06)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"SponsonSide_{si}", (1.26, 0.96, 0.090), "armor_sub", "armor_hatch",
                              (sx * 0.96, 0.86, 0.05), (0, sx * -90.0, 0))
        for ei, ey in enumerate([0.72, 1.02]):
            kb.era_block(f"SideERA_{si}_{ei}", (0.32, 0.23, 0.068), "armor",
                         (sx * 1.08, ey, -0.38), (0, sx * -90.0, 0))
        kb.plate(f"ShoulderPauldron_{si}", pauldron_xy, 0.40, "armor", "armor_panel",
                 (sx * 0.94, 1.42, 0.04), (0, 90, sx * -8.0), 0.018, 1)
        kb.box(f"PauldronAccent_{si}", (0.42, 0.19, 0.058), "accent", "plain_metal",
               (sx * 0.94, 1.42, -0.36), (0, 0, sx * -8.0), 0.004, 1)
        kb.grab_rail(f"PauldronGrab_{si}", 0.28, 0.046, (sx * 0.94, 1.59, 0.08), (90, 90, 0), 0.011)
        kb.louver_bay(f"SponsonRearVent_{si}", 0.48, 0.22, 0.052, (sx * 0.92, 0.56, 0.74),
                      (0, 180, 0), blades=4, mesh_style=False)
        _add_slat_cage(kb, f"FortressSlat_{si}", sx * 1.15, 0.86, 0.48, 1.02, h=0.78, n_bars=4)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.66, 1.78, -0.58), (-22, sx * -18.0, 0))
        kb.tube_path(f"HeavyCoolant_{si}", [
            (sx * 0.90, 0.38, 0.56), (sx * 0.96, 0.30, 0.04), (sx * 0.64, 0.28, -0.46)
        ], 0.017, 8, "copper" if si == 0 else "brass", "plain_metal")

    # 5. Twin Superstructure Roof: Armored Driver Cab (Left) + Commander Panoramic Cupola (Right)
    kb.spaced_armor_plate("RoofDeck", (1.64, 1.08, 0.082), "armor", "armor_panel", (0, 1.72, -0.08), (90, 0, 0))
    # Left Front Armored Driver Cab
    M_dr = g2b_mat((-0.44, 1.84, -0.42), (0, 0, 0))
    kb.plate("DriverCab", crect_2d(0.62, 0.25, (0.07, 0.02, 0.02, 0.06)), 0.52, "armor", "armor_pocket",
             (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_dr)
    kb.box("DriverBrow", (0.54, 0.030, 0.115), "gunmetal", "bolt_flange", (0, 0.072, -0.245), (10, 0, 0), 0.005, 1, M_parent=M_dr)
    kb.box("DriverRecess", (0.46, 0.068, 0.026), "bore", "plain_metal", (0, 0.020, -0.256), (0, 0, 0), 0.003, 1, M_parent=M_dr)
    kb.box("DriverGlass", (0.42, 0.052, 0.018), "glass", "plain_metal", (0, 0.020, -0.268), (0, 0, 0), 0.002, 1, M_parent=M_dr)
    kb.grab_rail("DriverGrab", 0.32, 0.038, (0, 0.14, 0.06), (90, 0, 0), 0.009, M_parent=M_dr)

    # Right Heavy Commander Cupola + Panoramic Flank Periscopes + Center Beacon Lens
    kb.cyl("CmdTurretBase", 0.34, 0.38, 0.14, 18, "armor_sub", "gear_collar", (0.42, 1.80, -0.08), (0, 0, 0), 0.009)
    kb.cupola_hatch("CmdCupola", (0.42, 1.87, -0.08))
    for pi, pyaw in enumerate([-75.0, 75.0, 180.0]):
        ar = math.radians(pyaw)
        _add_periscope(kb, f"RearPeri_{pi}", 0.11, 0.064,
                       (0.42 + math.sin(ar) * 0.31, 1.94, -0.08 - math.cos(ar) * 0.31), (0, -pyaw, 0))
    _add_optic_lens(kb, "RoofBeacon", 0.036, (0.0, 1.80, -0.56), (90, 0, 0), "emit_amber")

    # Rear Sloped Engine Deck Vent Bays + Whip Antenna
    for si, sx in enumerate([-0.64, 0.64]):
        kb.louver_bay(f"RearDeckVent_{si}", 0.26, 0.54, 0.050, (sx, 1.76, 0.60), (76, 0, 0),
                      blades=4, mesh_style=(si == 1))
    _add_whip_antenna(kb, "FortressWhip", (-0.75, 1.76, 0.78), h=1.10)

    # 6. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.72, 0.56, w=0.96, d=0.56, tilt_deg=-14.0)
    _add_gen_dock(kb, "GenDock", 0.75, 1.08, w=1.02, h=0.78)

    kb.add_marker("SOCKET_arm_l", (-1.10, 0.85, 0.0))
    kb.add_marker("SOCKET_arm_r", (1.10, 0.85, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  1.72, 0.56))
    kb.add_marker("SOCKET_gen",   (0.0,  0.75, 1.08))


# ==============================================================================
# 8. core_heavy — BW-3 / HV-3 B.o.T-Style Heavy Assault Core
# ==============================================================================

def build_core_heavy(kb: KitbashScene):
    """BW-3/HV-3 Heavy Assault Core: double-layer wedge chest, armored head, shoulder bastions, twin stacks."""
    # 1. Unified HP-C1 Waist Ring (strictly y_bot=-0.005m) + Twin Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.16)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.30, 0.01, -0.24), (sx * 0.44, 0.22, -0.44), 0.022)

    # 2. Broad B.o.T Cast-Steel Hull + Upper Crown + HP-A1 Arm Bulkheads
    kb.box("InnerChest", (1.58, 0.72, 1.38), "dark", "frame_cnc", (0, 0.44, 0.06), (0, 0, 0), 0.026, 1, tile_u=2.0)
    kb.plate("BroadHull", crect_2d(1.96, 0.76, (0.22, 0.22, 0.12, 0.12)), 1.44, "armor_sub", "armor_ribs",
             (0, 0.42, 0.12), (0, 0, 0), 0.024, 1)
    kb.plate("UpperCrown", trap_2d(1.88, 1.32, 0.40, 0.08), 1.24, "armor", "armor_panel",
             (0, 0.96, 0.18), (0, 0, 0), 0.020, 1)
    kb.arm_bulkhead("ArmMount", 1.01, 0.30, 0.0)

    # 3. Double-Layer Wedge Chest Armor + 4 Flank ERA Blocks + Forward Spall Chin (clears waist!)
    kb.plate("ChestPrimary", trap_2d(1.34, 1.70, 0.72, 0.10), 0.16, "armor", "armor_panel",
             (0, 0.42, -0.70), (-12, 0, 0), 0.020, 1)
    kb.plate("ChestSub", trap_2d(0.84, 1.12, 0.44, 0.07), 0.095, "armor_sub", "armor_hatch",
             (0, 0.44, -0.82), (-12, 0, 0), 0.014, 1)
    kb.louver_bay("ChestIntake", 0.46, 0.16, 0.044, (0, 0.28, -0.86), (-12, 0, 0), blades=4, mesh_style=True)
    kb.plate("LowerSpallChin", trap_2d(1.44, 1.02, 0.30, 0.06), 0.14, "armor_sub", "armor_ribs",
             (0, 0.08, -0.68), (26, 0, 0), 0.014, 1)
    kb.box("ChestHazard", (0.42, 0.044, 0.020), "hazard", "hazard", (0, 0.16, -0.82), (26, 0, 0), 0.003, 1)

    for si, sx in enumerate([-1.0, 1.0]):
        kb.era_block(f"ChestERA_T_{si}", (0.24, 0.18, 0.060), "armor_sub", (sx * 0.62, 0.52, -0.78), (-12, 0, 0))
        kb.era_block(f"ChestERA_B_{si}", (0.24, 0.18, 0.060), "armor", (sx * 0.62, 0.30, -0.74), (-12, 0, 0))
        kb.box(f"ChestAccent_{si}", (0.062, 0.48, 0.036), "accent", "plain_metal",
               (sx * 0.80, 0.42, -0.76), (-12, 0, sx * -8.0), 0.004, 1)
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.44, 0.08, -0.80), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.22, 0.04, -0.82), (0, 0, 90), scale=1.1)

    # 4. Massive Twin Shoulder Bastions + Smoke Pods + Side Radiator Bays
    bastion_xy = crect_2d(0.92, 0.34, (0.12, 0.12, 0.02, 0.02))
    for si, sx in enumerate([-1.0, 1.0]):
        M_sb = g2b_mat((sx * 0.95, 0.94, 0.05), (0, 0, sx * -10.0))
        kb.plate(f"ShoulderBastion_{si}", bastion_xy, 0.62, "armor", "armor_panel",
                 (0, 0, 0), (0, 90, 0), 0.018, 1, M_parent=M_sb)
        kb.box(f"BastionAccent_{si}", (0.64, 0.35, 0.060), "accent", "plain_metal",
               (0, 0, -0.30), (0, 0, 0), 0.004, 1, M_parent=M_sb)
        kb.grab_rail(f"BastionGrab_{si}", 0.26, 0.044, (0, 0.19, 0.0), (90, 90, 0), 0.011, M_parent=M_sb)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.14, 0.16, -0.44), (-22, sx * -14.0, 0), M_parent=M_sb)
        kb.louver_bay(f"SideVent_{si}", 0.48, 0.28, 0.054, (sx * 1.02, 0.44, 0.32),
                      (0, sx * -90.0, 0), blades=5, mesh_style=(si == 1))
        kb.tube_path(f"Coolant_{si}", [
            (sx * 0.94, 0.22, 0.48), (sx * 0.98, 0.14, 0.08), (sx * 0.68, 0.12, -0.34)
        ], 0.016, 8, "copper" if si == 0 else "brass", "plain_metal")

    # 5. Recessed Armored Command Head + Dual Thermal Optics
    M_hd = g2b_mat((0.0, 1.00, -0.50), (0, 0, 0))
    kb.plate("CmdHead", trap_2d(0.82, 0.58, 0.32, 0.06), 0.48, "armor", "armor_pocket",
             (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_hd)
    kb.box("HeadBrow", (0.66, 0.034, 0.145), "gunmetal", "bolt_flange", (0, 0.095, -0.24), (8, 0, 0), 0.005, 1, M_parent=M_hd)
    kb.box("HeadRecess", (0.50, 0.062, 0.026), "bore", "plain_metal", (0, 0.045, -0.242), (0, 0, 0), 0.003, 1, M_parent=M_hd)
    kb.box("HeadVisor", (0.46, 0.046, 0.018), "glass", "plain_metal", (0, 0.045, -0.256), (0, 0, 0), 0.002, 1, M_parent=M_hd)
    kb.plate("HeadChin", trap_2d(0.68, 0.48, 0.14, 0.03), 0.10, "armor_sub", "armor_ribs",
             (0, -0.04, -0.25), (-24, 0, 0), 0.010, 1, M_parent=M_hd)
    for si, sx in enumerate([-0.30, 0.30]):
        _add_optic_lens(kb, f"HeadThermal_{si}", 0.032, (sx, -0.055, -0.252), (90, 0, 0), "emit_amber", M_parent=M_hd)

    # 6. Right-Shoulder Finned Armored Searchlight Box (with Glare Hood & Shutter Louvers)
    M_sp = g2b_mat((0.62, 1.24, -0.25), (0, 0, 0))
    kb.box("SpotHousing", (0.28, 0.20, 0.26), "dark", "frame_cnc", (0, 0, 0), (0, 0, 0), 0.012, 1, M_parent=M_sp)
    kb.box("SpotHood", (0.30, 0.022, 0.085), "gunmetal", "bolt_flange", (0, 0.098, -0.125), (10, 0, 0), 0.004, 1, M_parent=M_sp)
    for fi in range(4):
        kb.box(f"SpotFin_{fi}", (0.30, 0.014, 0.20), "gunmetal", "plain_metal",
               (0, -0.06 + fi * 0.04, 0.02), (0, 0, 0), 0.003, 1, M_parent=M_sp)
    _add_optic_lens(kb, "SpotLamp", 0.060, (0, 0, -0.132), (90, 0, 0), "emit_headlight", M_parent=M_sp)
    for li, ly in enumerate([-0.036, 0.0, 0.036]):
        kb.box(f"SpotSlat_{li}", (0.155, 0.012, 0.028), "dark", "plain_metal",
               (0, ly, -0.158), (12, 0, 0), 0.002, 1, M_parent=M_sp)

    # 7. Twin Heavy Rear Industrial Exhaust Stacks (Perforated Shields + Dual Pipes + Rain Flappers)
    for si, sx in enumerate([-1.0, 1.0]):
        M_ex = g2b_mat((sx * 0.58, 1.34, 0.66), (8.0, 0.0, sx * -4.0))
        kb.box(f"ExhShield_{si}", (0.26, 0.68, 0.24), "gunmetal", "vent_mesh",
               (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_ex)
        for pi, px in enumerate([-0.056, 0.056]):
            kb.cyl(f"ExhPipe_{si}_{pi}", 0.044, 0.046, 0.80, 12, "dark", "plain_metal",
                   (px, 0.04, 0), (0, 0, 0), 0.004, M_parent=M_ex)
            kb.barrel_bore(f"ExhBore_{si}_{pi}", 0.045, 0.034, (px, 0.45, 0), depth=0.06, rot_deg=(0, 0, 0), segs=12, M_parent=M_ex)
            kb.box(f"ExhFlap_{si}_{pi}", (0.10, 0.014, 0.11), "gunmetal", "bolt_flange",
                   (px, 0.50, 0.02), (-22, 0, 0), 0.003, 1, M_parent=M_ex)

    # 8. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.06, 0.535, w=0.82, d=0.46, tilt_deg=-10.0)
    _add_gen_dock(kb, "GenDock", 0.36, 0.835, w=0.92, h=0.56)

    kb.add_marker("SOCKET_arm_l", (-1.01, 0.30, 0.0))
    kb.add_marker("SOCKET_arm_r", (1.01, 0.30, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  1.06, 0.535))
    kb.add_marker("SOCKET_gen",   (0.0,  0.12, 0.835))


# ==============================================================================
# 9. core_ka52_alligator — KA-52M Side-by-Side Gunship Assault Core
# ==============================================================================

def build_core_ka52_alligator(kb: KitbashScene):
    """KA-52M Alligator Gunship Core: lofted duckbill AESA nose, side-by-side cockpit + K-37, GOES-451."""
    # 1. Unified HP-C1 Waist Ring + Dual Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.22)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.28), (sx * 0.32, 0.30, -0.42), 0.020)

    # 2. Gunship Armored Fuselage Core + HP-A1 Arm Bulkheads
    kb.box("InnerFuselage", (1.32, 0.86, 1.36), "dark", "frame_cnc", (0, 0.67, 0.08), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("LowerKeel", (1.06, 0.16, 1.18), "armor_dark", "armor_ribs", (0, 0.22, 0.04), (0, 0, 0), 0.014, 1)
    kb.arm_bulkhead("ArmMount", 0.96, 0.68, 0.04)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"WingStub_{si}", (0.26, 0.46, 0.54), "armor_sub", "armor_pocket",
               (sx * 0.76, 0.68, 0.04), (0, 0, 0), 0.016, 1)

    # 3. Signature Multi-Section Lofted "Duckbill" AESA Radome Nose + Dorsal Cowl + Pitot Probes
    base_ring = [
        (0.0, -0.35), (0.45, -0.26), (0.63, -0.05),
        (0.45, 0.26), (-0.45, 0.26), (-0.63, -0.05), (-0.45, -0.26)
    ]
    nose_sections = []
    for gz, sx_f, sy_f, oy in [
        (0.0, 1.00, 1.00, 0.0),
        (-0.34, 0.92, 0.82, -0.04),
        (-0.66, 0.68, 0.52, -0.09),
        (-0.86, 0.34, 0.26, -0.12),
    ]:
        nose_sections.append((gz, [(px * sx_f, py * sy_f + oy) for (px, py) in base_ring]))
    kb.loft("DuckbillRadome", nose_sections, "armor_dark", "armor_panel", (0, 0.64, -0.54), (0, 0, 0), 0.014, 1)
    kb.plate("NoseDorsalCowl", trap_2d(1.18, 0.86, 0.48, 0.06), 0.080, "armor", "armor_hatch",
             (0, 0.82, -0.74), (72, 0, 0), 0.014, 1)
    kb.box("NoseHazard", (0.36, 0.042, 0.020), "hazard", "hazard", (0, 0.74, -1.16), (62, 0, 0), 0.003, 1)

    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"PitotMount_{si}", (0.085, 0.064, 0.145), "gunmetal", "bolt_flange",
               (sx * 0.64, 0.72, -0.58), (0, 0, 0), 0.007, 1)
        kb.cyl(f"PitotNeedle_{si}", 0.008, 0.014, 0.34, 8, "chrome", "plain_metal",
               (sx * 0.65, 0.72, -0.78), (90, 0, 0), 0.002)
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.46, 0.50, -0.94), (0, sx * -14.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.30, 0.30, -0.92), (0, 0, 90), scale=0.95)

    # 4. Side-by-Side Twin-Seat Armored Gunship Cockpit + Flat Windscreens + K-37 Ejection Chutes
    M_ck = g2b_mat((0.0, 1.06, -0.36), (0, 0, 0))
    kb.box("CockpitTub", (1.18, 0.28, 0.58), "armor", "armor_panel", (0, 0, 0.06), (0, 0, 0), 0.018, 1, M_parent=M_ck)
    kb.box("CenterPillar", (0.068, 0.23, 0.13), "gunmetal", "bolt_flange", (0, 0.04, -0.22), (18, 0, 0), 0.006, 1, M_parent=M_ck)
    for si, sx in enumerate([-1.0, 1.0]):
        _add_periscope(kb, f"Windscreen_{si}", 0.43, 0.18, (sx * 0.28, 0.04, -0.22), (18, sx * -3.0, 0), "glass", M_parent=M_ck)
        # Roof K-37 Ejection-Rocket Blast Chute & Hatch Frame
        kb.box(f"K37_Chute_{si}", (0.36, 0.036, 0.34), "gunmetal", "armor_ribs",
               (sx * 0.28, 0.155, 0.06), (0, 0, 0), 0.005, 1, M_parent=M_ck)
        kb.box(f"K37_Hazard_{si}", (0.26, 0.016, 0.040), "hazard", "hazard",
               (sx * 0.28, 0.176, -0.06), (0, 0, 0), 0.002, 1, M_parent=M_ck)
        kb.grab_rail(f"CockpitGrab_{si}", 0.22, 0.036, (sx * 0.58, 0.06, 0.06), (0, sx * -90.0, 0), 0.009, M_parent=M_ck)

    # 5. Under-Chin GOES-451 Octagonal Electro-Optical Ball Turret
    M_goes = g2b_mat((0.22, 0.38, -0.82), (0, 0, 0))
    kb.cyl("GOES_Neck", 0.135, 0.155, 0.12, 8, "gunmetal", "gear_collar", (0, 0.06, 0), (0, 0, 0), 0.006, M_parent=M_goes)
    kb.cyl("GOES_Ball", 0.152, 0.152, 0.16, 8, "armor_sub", "armor_pocket", (0, -0.04, 0), (90, 0, 0), 0.008, M_parent=M_goes)
    kb.box("GOES_Hood", (0.20, 0.022, 0.075), "gunmetal", "bolt_flange", (0, 0.045, -0.095), (10, 0, 0), 0.004, 1, M_parent=M_goes)
    _add_optic_lens(kb, "GOES_FLIR", 0.044, (-0.046, -0.04, -0.090), (90, 0, 0), "emit_cyan", M_parent=M_goes)
    _add_optic_lens(kb, "GOES_Laser", 0.032, (0.048, -0.04, -0.090), (90, 0, 0), "emit_amber", M_parent=M_goes)
    kb.tube_path("GOES_Umbilical", [(0.34, 0.38, -0.76), (0.44, 0.44, -0.64), (0.42, 0.56, -0.52)],
                 0.012, 8, "gunmetal", "braid_hose")

    # 6. Twin Upper Shoulder Turboshaft Engine Nacelles + Intakes + Louvers + Smoke Pods
    for si, sx in enumerate([-1.0, 1.0]):
        M_tb = g2b_mat((sx * 0.64, 1.06, 0.16), (0, 0, 0))
        kb.box(f"TurboPod_{si}", (0.34, 0.26, 0.68), "armor_sub", "armor_hatch", (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_tb)
        kb.cyl(f"TurboIntake_{si}", 0.115, 0.125, 0.14, 16, "dark", "gear_collar",
               (0, 0.01, -0.34), (90, 0, 0), 0.005, hollow_r=0.088, M_parent=M_tb)
        kb.cyl(f"TurboSpinner_{si}", 0.016, 0.056, 0.12, 12, "chrome", "plain_metal",
               (0, 0.01, -0.38), (90, 0, 0), 0.003, M_parent=M_tb)
        kb.cyl(f"TurboNozzle_{si}", 0.095, 0.105, 0.12, 14, "gunmetal", "vent_mesh",
               (0, 0.0, 0.36), (90, 0, 0), 0.004, hollow_r=0.072, M_parent=M_tb)
        kb.louver_bay(f"TurboVent_{si}", 0.28, 0.17, 0.044, (sx * 0.17, 0, 0.12),
                      (0, sx * -90.0, 0), blades=4, mesh_style=False, M_parent=M_tb)
        kb.smoke_pod(f"FlarePod_{si}", (sx * 0.78, 0.88, -0.34), (-16, sx * -20.0, 0))
        kb.tube_path(f"TurboOil_{si}", [
            (sx * 0.64, 0.94, 0.36), (sx * 0.72, 0.74, 0.42), (sx * 0.56, 0.56, 0.50)
        ], 0.013, 8, "copper" if si == 0 else "brass", "plain_metal")

    kb.louver_bay("RearDeckCooler", 0.52, 0.24, 0.050, (0, 1.12, 0.16), (90, 0, 0), blades=4, mesh_style=True)
    _add_whip_antenna(kb, "GunshipWhip_L", (-0.54, 1.20, 0.42), h=0.84)
    _add_whip_antenna(kb, "GunshipWhip_R", (0.54, 1.20, 0.42), h=0.66, tilt_x=-10.0)

    # 7. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.34, 0.50, w=0.82, d=0.48)
    _add_gen_dock(kb, "GenDock", 0.62, 0.90, w=0.90, h=0.70)

    kb.add_marker("SOCKET_arm_l", (-0.96, 0.68, 0.04))
    kb.add_marker("SOCKET_arm_r", (0.96, 0.68, 0.04))
    kb.add_marker("SOCKET_back",  (0.0,  1.34, 0.50))
    kb.add_marker("SOCKET_gen",   (0.0,  0.62, 0.90))


# ==============================================================================
# 10. core_krasukha_ew — 1RL257 Krasukha-4 Electronic Warfare Shelter Core
# ==============================================================================

def build_core_krasukha_ew(kb: KitbashScene):
    """1RL257 Krasukha-4 EW Core: Faraday ribbed shelter, 2x3 waveguide horns, 12-facet dish, 6-way DF."""
    # 1. Unified HP-C1 Waist Ring + Dual Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.24)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.05, -0.30), (sx * 0.34, 0.34, -0.44), 0.022)

    # 2. Heavy Electromagnetic Faraday Shelter Hull + HP-A1 Arm Bulkheads
    kb.box("InnerShelter", (1.52, 1.04, 1.42), "dark", "frame_cnc", (0, 0.76, 0.06), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("LowerSkid", (1.24, 0.16, 1.20), "armor_dark", "armor_ribs", (0, 0.22, 0.04), (0, 0, 0), 0.014, 1)
    kb.arm_bulkhead("ArmMount", 1.10, 0.78, 0.02)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"ShoulderPylon_{si}", (0.30, 0.48, 0.54), "armor_sub", "armor_pocket",
               (sx * 0.88, 0.78, 0.02), (0, 0, 0), 0.016, 1)

    # 3. Corrugated Faraday Shield Front + 2x3 Pyramidal Microwave Jammer Waveguide Horns
    M_far = g2b_mat((0.0, 0.82, -0.68), (0, 0, 0))
    kb.box("FaradayWall", (1.48, 0.92, 0.24), "armor", "armor_panel", (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_far)
    for ri, rx in enumerate([-0.60, -0.40, -0.20, 0.0, 0.20, 0.40, 0.60]):
        kb.box(f"FaradayRib_{ri}", (0.036, 0.84, 0.042), "armor_sub", "armor_ribs",
               (rx, 0, -0.125), (0, 0, 0), 0.005, 1, M_parent=M_far)

    # 2x3 Flared Pyramidal Microwave Waveguide Horns (kb.loft + recessed bore + copper feed ring)
    horn_base = [
        (-0.070, 0.050), (-0.058, 0.060), (0.058, 0.060), (0.070, 0.050),
        (0.070, -0.050), (0.058, -0.060), (-0.058, -0.060), (-0.070, -0.050),
    ]
    horn_mouth = [(px * 1.62, py * 1.52) for (px, py) in horn_base]
    horn_sections = [(0.02, horn_base), (-0.14, horn_mouth)]
    for ri, ry in enumerate([-0.18, 0.16]):
        for ci, cx in enumerate([-0.42, 0.0, 0.42]):
            kb.loft(f"WaveguideHorn_{ri}_{ci}", horn_sections, "gunmetal", "bolt_flange",
                    (cx, ry, -0.14), (0, 0, 0), 0.006, 1, M_parent=M_far)
            kb.box(f"WaveguideBore_{ri}_{ci}", (0.16, 0.115, 0.024), "bore", "plain_metal",
                   (cx, ry, -0.270), (0, 0, 0), 0.003, 1, M_parent=M_far)
            kb.box(f"WaveguideCopper_{ri}_{ci}", (0.175, 0.130, 0.026), "copper", "plain_metal",
                   (cx, ry, -0.242), (0, 0, 0), 0.004, 1, M_parent=M_far)

    _add_periscope(kb, "EW_DriverPeri", 0.30, 0.084, (0, 0.38, -0.13), (4, 0, 0), "glass", M_parent=M_far)
    kb.box("EW_Hazard", (0.56, 0.046, 0.020), "hazard", "hazard", (0, -0.40, -0.135), (0, 0, 0), 0.003, 1, M_parent=M_far)

    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.56, 0.36, -0.82), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.30, 0.24, -0.80), (0, 0, 90), scale=1.08)

    # 4. Flank Copper Waveguide Busbars, Heavy Thermal Louver Bays, Equipment Sponsons & RF Conduits
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"CopperBusbar_{si}", (0.062, 0.78, 0.090), "copper", "armor_ribs",
               (sx * 0.80, 0.82, -0.42), (0, 0, 0), 0.007, 1)
        kb.louver_bay(f"SideThermalBay_{si}", 0.48, 0.32, 0.056, (sx * 0.82, 0.88, 0.28),
                      (0, sx * -90.0, 0), blades=5, mesh_style=(si == 1))
        kb.spaced_armor_plate(f"SideSponson_{si}", (0.84, 0.36, 0.14), "armor_sub", "armor_hatch",
                              (sx * 0.90, 0.48, 0.04), (0, sx * -90.0, 0))
        kb.grab_rail(f"SideGrab_{si}", 0.28, 0.042, (sx * 0.86, 1.16, -0.22), (0, sx * -90.0, 0), 0.010)
        kb.tube_path(f"RF_Conduit_{si}", [
            (sx * 0.78, 1.18, -0.34), (sx * 0.86, 0.96, -0.12), (sx * 0.82, 0.66, 0.18)
        ], 0.015, 8, "gunmetal", "braid_hose")

    # 5. Roof EW Crown: Left 12-Faceted Krasukha Jammer Dish + Right 6-Way ESM Direction Finder
    kb.spaced_armor_plate("RoofDeck", (1.42, 0.88, 0.072), "armor", "armor_panel", (0, 1.28, 0.04), (90, 0, 0))

    # Left Roof: 12-Faceted Krasukha Parabolic Jammer Dish + Brass Feed Horn + Tripod Struts
    M_dish = g2b_mat((-0.42, 1.32, -0.28), (22.0, -18.0, 0.0))
    kb.cyl("DishPedestal", 0.135, 0.160, 0.15, 14, "dark", "gear_collar", (0, 0.075, 0), (0, 0, 0), 0.006, M_parent=M_dish)
    dish_profile = [
        (0.0, -0.050), (0.16, -0.050), (0.32, 0.045),
        (0.32, 0.062), (0.285, 0.062), (0.13, -0.005), (0.0, -0.005),
    ]
    kb.lathe("DishReflector", dish_profile, 12, "armor_sub", "armor_panel",
             (0, 0.22, -0.06), (78, 0, 0), M_parent=M_dish)
    kb.cyl("DishBackplate", 0.24, 0.16, 0.045, 12, "dark", "frame_cnc",
           (0, 0.20, -0.01), (78, 0, 0), 0.004, M_parent=M_dish)
    kb.cyl("DishFeedHorn", 0.056, 0.040, 0.18, 10, "brass", "gear_collar",
           (0, 0.25, -0.17), (78, 0, 0), 0.004, M_parent=M_dish)
    kb.cyl("DishFeedTip", 0.036, 0.036, 0.020, 10, "emit_amber", "plain_metal",
           (0, 0.27, -0.265), (78, 0, 0), 0.002, M_parent=M_dish)
    for si in range(3):
        sa = math.tau * si / 3.0
        kb.tube_path(f"DishStrut_{si}", [
            (math.cos(sa) * 0.26, 0.22 + math.sin(sa) * 0.24, -0.08),
            (0.0, 0.26, -0.22)
        ], 0.009, 6, "gunmetal", "plain_metal", add_clamps=False, M_parent=M_dish)

    # Right Roof: 6-Way ESM Direction-Finder Antenna Crown + Cyan Beacon
    M_esm = g2b_mat((0.44, 1.32, -0.30), (0, 0, 0))
    kb.cyl("ESM_Drum", 0.18, 0.21, 0.24, 12, "armor_sub", "bolt_flange", (0, 0.12, 0), (0, 0, 0), 0.007, M_parent=M_esm)
    kb.cyl("ESM_Cap", 0.14, 0.17, 0.045, 12, "dark", "gear_collar", (0, 0.255, 0), (0, 0, 0), 0.004, M_parent=M_esm)
    kb.cyl("ESM_Beacon", 0.048, 0.054, 0.065, 12, "emit_cyan", "plain_metal", (0, 0.305, 0), (0, 0, 0), 0.003, M_parent=M_esm)
    for di in range(6):
        da = math.tau * di / 6.0
        kb.box(f"ESM_Dipole_{di}", (0.032, 0.19, 0.060), "chrome", "plain_metal",
               (math.cos(da) * 0.195, 0.15, math.sin(da) * 0.195), (0, -math.degrees(da), 0), 0.004, 1, M_parent=M_esm)

    kb.stowage_rack("RearStowage", (0.0, 1.35, 0.14), (90, 0, 0))
    _add_whip_antenna(kb, "EW_Whip_L", (-0.64, 1.30, 0.44), h=0.96)
    _add_whip_antenna(kb, "EW_Whip_R", (0.64, 1.30, 0.44), h=0.80, tilt_x=-8.0)

    # 6. Standard HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.52, 0.54, w=0.84, d=0.50)
    _add_gen_dock(kb, "GenDock", 0.68, 0.94, w=0.92, h=0.72)

    kb.add_marker("SOCKET_arm_l", (-1.10, 0.78, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.10, 0.78, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.52, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.68, 0.94))
