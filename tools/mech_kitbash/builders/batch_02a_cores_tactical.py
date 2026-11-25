"""Batch 02a Tactical Cores — Production Kitbash Builders (MECH_MODELING_STANDARD v1.0).

Retains `core_heavy` (HV-3 B.o.T Heavy Assault Core).
All other cores in this batch have been migrated to sculpted non-boxy v2 builders
in `sculpted_cores_v2.py`, `sculpted_cores_v2_tactical.py`, and `sculpted_cores_v2_specialist.py`.
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
    kb.cyl(f"{prefix}_bz", r + 0.010, r + 0.012, 0.032, 12, "gunmetal", "gear_collar",
           (0, 0.006, 0), (0, 0, 0), 0.003, hollow_r=r * 0.84, M_parent=M)
    kb.cyl(f"{prefix}_br", r * 0.83, r * 0.83, 0.010, 10, "bore", "plain_metal",
           (0, 0.014, 0), (0, 0, 0), 0.001, M_parent=M)
    kb.cyl(f"{prefix}_ln", r * 0.78, r * 0.78, 0.010, 12, lens_slot, "plain_metal",
           (0, -0.004, 0), (0, 0, 0), 0.002, M_parent=M)


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
    kb.box(f"{prefix}_bay", (w - 0.08, h - 0.08, 0.050), "dark", "frame_cnc",
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
# 8. core_heavy — BW-3 / HV-3 B.o.T-Style Heavy Assault Core
# ==============================================================================

def build_core_heavy(kb: KitbashScene):
    """BW-3/HV-3 Heavy Assault Core: double-layer wedge chest, armored head, shoulder bastions, twin stacks."""
    # 1. Unified Compact HP-C1 Waist Ring + Twin Waist Hydraulics
    kb.waist_collar_core("HP_C1_Core", y_top=0.12)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.20, 0.020, -0.16), (sx * 0.42, 0.22, -0.44), 0.020)

    # 2. Broad B.o.T Cast-Steel Hull (rear <= 0.78m clearing HP-G1 at 0.835m) + Stepped Crown & Rear HP-B1 Bay
    kb.box("InnerChest", (1.44, 0.60, 1.20), "dark", "frame_cnc", (0, 0.44, 0.08), (0, 0, 0), 0.022, 1, tile_u=2.0)
    kb.plate("BroadHull", crect_2d(1.94, 0.76, (0.22, 0.22, 0.12, 0.12)), 1.34, "armor_sub", "armor_ribs",
             (0, 0.42, 0.07), (0, 0, 0), 0.024, 1)
    kb.plate("UpperCrown", trap_2d(1.76, 1.28, 0.38, 0.08), 0.72, "armor", "armor_panel",
             (0, 0.96, -0.14), (0, 0, 0), 0.020, 1)
    kb.box("RearBackBay", (1.40, 0.27, 0.56), "armor_sub", "armor_hatch",
           (0, 0.895, 0.50), (0, 0, 0), 0.016, 1)
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
        kb.era_block(f"ChestERA_T_{si}", (0.24, 0.18, 0.060), "armor_sub", (sx * 0.62, 0.52, -0.842), (-12, 0, 0))
        kb.era_block(f"ChestERA_B_{si}", (0.24, 0.18, 0.060), "armor", (sx * 0.62, 0.30, -0.798), (-12, 0, 0))
        kb.box(f"ChestAccent_{si}", (0.062, 0.48, 0.036), "accent", "plain_metal",
               (sx * 0.80, 0.42, -0.79), (-12, 0, sx * -8.0), 0.004, 1)
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.44, 0.08, -0.80), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.22, 0.04, -0.82), (0, 0, 90), scale=1.1)

    # 4. Massive Twin Shoulder Bastions (strictly |x| <= 1.00m clearing HP-A1 arms!) + Smoke Pods + Side Vents
    bastion_xy = crect_2d(0.86, 0.34, (0.12, 0.12, 0.02, 0.02))
    for si, sx in enumerate([-1.0, 1.0]):
        M_sb = g2b_mat((sx * 0.77, 0.98, 0.02), (0, 0, sx * -8.0))
        kb.plate(f"ShoulderBastion_{si}", bastion_xy, 0.42, "armor", "armor_panel",
                 (0, 0, 0), (0, 90, 0), 0.018, 1, M_parent=M_sb)
        kb.box(f"BastionAccent_{si}", (0.44, 0.35, 0.056), "accent", "plain_metal",
               (0, 0, -0.28), (0, 0, 0), 0.004, 1, M_parent=M_sb)
        kb.grab_rail(f"BastionGrab_{si}", 0.22, 0.044, (0, 0.172, 0.0), (90, 0, 0), 0.011, M_parent=M_sb)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.08, 0.16, -0.40), (-22, sx * -14.0, 0), M_parent=M_sb)
        kb.louver_bay(f"SideVent_{si}", 0.40, 0.26, 0.036, (sx * 0.992, 0.44, 0.46),
                      (0, sx * -90.0, 0), blades=5, mesh_style=(si == 1))
        kb.tube_path(f"Coolant_{si}", [
            (sx * 0.90, 0.22, 0.46), (sx * 0.92, 0.14, 0.08), (sx * 0.68, 0.12, -0.34)
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
    _add_optic_lens(kb, "SpotLamp", 0.060, (0, 0, -0.144), (90, 0, 0), "emit_headlight", M_parent=M_sp)
    for li, ly in enumerate([-0.036, 0.0, 0.036]):
        kb.box(f"SpotSlat_{li}", (0.155, 0.012, 0.028), "dark", "plain_metal",
               (0, ly, -0.166), (12, 0, 0), 0.002, 1, M_parent=M_sp)

    # 7. Twin Heavy Rear Industrial Exhaust Stacks (flanking RearBackBay so HP-B1 clears!)
    for si, sx in enumerate([-1.0, 1.0]):
        M_ex = g2b_mat((sx * 0.80, 1.22, 0.66), (8.0, 0.0, sx * -4.0))
        kb.box(f"ExhBracket_{si}", (0.22, 0.14, 0.20), "dark", "frame_cnc",
               (-sx * 0.12, -0.22, 0.0), (0, 0, 0), 0.008, 1, M_parent=M_ex)
        kb.box(f"ExhShield_{si}", (0.24, 0.62, 0.22), "gunmetal", "vent_mesh",
               (0, 0, 0), (0, 0, 0), 0.014, 1, M_parent=M_ex)
        for pi, px in enumerate([-0.052, 0.052]):
            kb.cyl(f"ExhPipe_{si}_{pi}", 0.042, 0.044, 0.74, 12, "dark", "plain_metal",
                   (px, 0.04, 0), (0, 0, 0), 0.004, M_parent=M_ex)
            kb.barrel_bore(f"ExhBore_{si}_{pi}", 0.043, 0.032, (px, 0.42, 0), depth=0.06, rot_deg=(0, 0, 0), segs=12, M_parent=M_ex)
            kb.box(f"ExhFlap_{si}_{pi}", (0.095, 0.014, 0.10), "gunmetal", "bolt_flange",
                   (px, 0.46, 0.02), (-22, 0, 0), 0.003, 1, M_parent=M_ex)

    # 8. Standard Flat HP-B1 Back Dock, HP-G1 Power Dock & Exact Manifest Sockets
    _add_back_dock(kb, "BackDock", 1.06, 0.535, w=0.82, d=0.46, tilt_deg=0.0)
    _add_gen_dock(kb, "GenDock", 0.36, 0.835, w=0.92, h=0.56)

    kb.add_marker("SOCKET_arm_l", (-1.01, 0.30, 0.0))
    kb.add_marker("SOCKET_arm_r", (1.01, 0.30, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  1.06, 0.535))
    kb.add_marker("SOCKET_gen",   (0.0,  0.12, 0.835))
