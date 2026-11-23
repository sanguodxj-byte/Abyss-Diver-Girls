"""Batch 02b Heavy & Specialty Cores — Production Kitbash Builders (MECH_MODELING_STANDARD v1.0).

Contains all 10 high-precision heavy & specialty core torso modules for batch_02b_cores_heavy:
  1. core_m1a2_sepv3     (SEP-V3 M1A2 Abrams Composite Wedge Core)
  2. core_merkava_mk4m   (MRK-4M Merkava Mk.4M Trophy APS & Ball-Chain Core)
  3. core_mi24_hind      (MI-24P Hind Tandem Stepped Gunship Core)
  4. core_pantsir_s1     (96K6-M Pantsir-S1 Dual Phased-Array AA Core)
  5. core_patriot_mpq65  (MPQ-65 Patriot Inclined Phased-Array Core)
  6. core_pionier_dach   (PIO-2A Pionierpanzer Dachs Recovery & Crane Core)
  7. core_puma_spz       (SPZ-30 Puma Hedgehog & AMAP Composite Core)
  8. core_std            (MK-II Standard Multi-Faceted Tactical Core)
  9. core_t90m_proryv    (PRV-90 T-90M Proryv Relikt Wedge & Slat-Cage Core)
 10. core_trieste_bathy  (DSV-11K Trieste Abyssal Forged Bathysphere Core)

Compliance:
  - Unified HP-C1 waist collar (r=0.360m, y_bot=-0.005m) via kb.waist_collar_core(...)
  - Symmetrical HP-A1 shoulder bulkheads via kb.arm_bulkhead(...)
  - Exact SOCKET_arm_l / SOCKET_arm_r / SOCKET_back / SOCKET_gen from manifest.json
  - Whitelisted mat_slot & band_key only; 220-320 industrial parts; 14,000-21,000 tris budget
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
    kb.box(f"{prefix}_hs", (w, h, 0.082), "dark", "frame_cnc", (0, 0, 0.024), (0, 0, 0), 0.007, 1, M_parent=M)
    kb.box(f"{prefix}_br", (w + 0.018, 0.022, 0.112), "gunmetal", "bolt_flange",
           (0, h * 0.5 + 0.008, -0.014), (10, 0, 0), 0.004, 1, M_parent=M)
    kb.box(f"{prefix}_cv", (w * 0.82, h * 0.56, 0.024), "bore", "plain_metal",
           (0, -0.004, -0.022), (0, 0, 0), 0.003, 1, M_parent=M)
    kb.box(f"{prefix}_gl", (w * 0.74, h * 0.44, 0.016), glass_slot, "plain_metal",
           (0, -0.004, -0.036), (0, 0, 0), 0.002, 1, M_parent=M)


def _add_armored_eye(kb: KitbashScene, prefix: str, w: float, h: float, pos, rot_deg=(0, 0, 0),
                     glass_slot: str = "glass", M_parent=None):
    """Heavy MBT central mantlet armored optical slit with brow guard, bolts, and bore recess."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.box(f"{prefix}_hs", (w, h, 0.115), "dark", "frame_cnc", (0, 0, 0), (0, 0, 0), 0.008, 1, M_parent=M)
    kb.box(f"{prefix}_br", (w + 0.022, 0.026, 0.110), "gunmetal", "bolt_flange",
           (0, h * 0.5 + 0.006, -0.030), (12, 0, 0), 0.005, 1, M_parent=M)
    kb.box(f"{prefix}_sl", (w + 0.012, 0.020, 0.088), "gunmetal", "bolt_flange",
           (0, -h * 0.5 - 0.004, -0.022), (-8, 0, 0), 0.004, 1, M_parent=M)
    kb.box(f"{prefix}_cv", (w * 0.80, h * 0.52, 0.024), "bore", "plain_metal",
           (0, -0.004, -0.056), (0, 0, 0), 0.003, 1, M_parent=M)
    kb.box(f"{prefix}_gl", (w * 0.66, h * 0.28, 0.016), glass_slot, "plain_metal",
           (0, -0.004, -0.072), (0, 0, 0), 0.002, 1, M_parent=M)
    for bi, bx in enumerate([-w * 0.36, w * 0.36]):
        kb.cyl(f"{prefix}_bt{bi}", 0.008, 0.010, 0.014, 6, "chrome", "plain_metal",
               (bx, h * 0.5 + 0.020, -0.042), (12, 0, 0), 0.002, M_parent=M)


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
    """HP-B1 dorsal backpack twin guide-rail dock with clamp flanges and hazard warning band."""
    M = g2b_mat((0.0, y_back, z_back), (tilt_deg, 0.0, 0.0))
    kb.box(f"{prefix}_base", (w, 0.075, d), "dark", "frame_cnc", (0, -0.045, 0), (0, 0, 0), 0.010, 1, M_parent=M)
    kb.box(f"{prefix}_deck", (w - 0.06, 0.038, d - 0.06), "gunmetal", "bolt_flange",
           (0, -0.006, 0), (0, 0, 0), 0.006, 1, M_parent=M)
    for ri, rx in enumerate([-w * 0.34, w * 0.34]):
        kb.box(f"{prefix}_rl{ri}", (0.068, 0.048, d * 0.84), "armor_sub", "armor_ribs",
               (rx, 0.012, 0), (0, 0, 0), 0.007, 1, M_parent=M)
        kb.cyl(f"{prefix}_bt{ri}", 0.011, 0.013, 0.016, 6, "chrome", "plain_metal",
               (rx, 0.042, -d * 0.28), (0, 0, 0), 0.002, M_parent=M)
    kb.box(f"{prefix}_hz", (w * 0.62, 0.018, 0.042), "hazard", "hazard",
           (0, 0.016, d * 0.44), (0, 0, 0), 0.003, 1, M_parent=M)


def _add_gen_dock(kb: KitbashScene, prefix: str, y_gen: float, z_gen: float,
                  w: float = 0.92, h: float = 0.70):
    """HP-G1 rear generator docking frame with bolt rails, recessed bore bay, and power busbars."""
    z_f = z_gen - 0.045
    kb.box(f"{prefix}_bay", (w - 0.06, h - 0.06, 0.055), "dark", "frame_cnc",
           (0, y_gen, z_f - 0.035), (0, 0, 0), 0.008, 1)
    kb.box(f"{prefix}_rec", (w - 0.16, h - 0.16, 0.024), "bore", "plain_metal",
           (0, y_gen, z_f - 0.008), (0, 0, 0), 0.003, 1)
    for yi, sy in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_hr{yi}", (w, 0.068, 0.088), "gunmetal", "bolt_flange",
               (0, y_gen + sy * (h * 0.5 - 0.025), z_f), (0, 0, 0), 0.008, 1)
    for xi, sx in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_vr{xi}", (0.068, h - 0.06, 0.088), "gunmetal", "bolt_flange",
               (sx * (w * 0.5 - 0.034), y_gen, z_f), (0, 0, 0), 0.008, 1)
        kb.cyl(f"{prefix}_bus{xi}", 0.022, 0.022, h * 0.52, 8, "copper", "plain_metal",
               (sx * (w * 0.34), y_gen, z_f - 0.004), (0, 0, 0), 0.003)
        kb.cyl(f"{prefix}_val{xi}", 0.028, 0.028, 0.034, 8, "brass", "gear_collar",
               (sx * (w * 0.34), y_gen + h * 0.18, z_f + 0.004), (0, 0, 0), 0.003)
    kb.box(f"{prefix}_hz", (w * 0.56, 0.034, 0.018), "hazard", "hazard",
           (0, y_gen - h * 0.5 - 0.015, z_f + 0.038), (0, 0, 0), 0.003, 1)


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
# 1. core_m1a2_sepv3 — SEP-V3 M1A2 Abrams Composite Wedge Core
# ==============================================================================

def build_core_m1a2_sepv3(kb: KitbashScene):
    """SEP-V3 M1A2 Abrams Core: asymmetric DU composite cheeks, front tow lugs, TUSK ARAT-2 ERA, blow-off panels."""
    # 1. Unified HP-C1 Waist Collar + Dual Front Hydraulics + Structural Collar Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.22)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.22, r=0.42, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.24, 0.04, -0.34), (sx * 0.34, 0.36, -0.50), 0.024)

    # 2. Recessed Dark CNC Inner Chassis + Symmetrical HP-A1 Arm Bulkheads + Rear Docks
    kb.box("InnerHull", (1.56, 1.02, 1.40), "dark", "frame_cnc", (0, 0.77, 0.08), (0, 0, 0), 0.026, 1, tile_u=2.0)
    kb.box("MainArmoredTub", (1.62, 0.92, 1.32), "armor", "armor_panel", (0, 0.79, 0.08), (0, 0, 0), 0.028, 1, tile_u=2.0)
    for yi, sy in enumerate([0.30, 1.24]):
        kb.box(f"SpineRail_{yi}", (1.70, 0.068, 1.26), "gunmetal", "armor_ribs", (0, sy, 0.08), (0, 0, 0), 0.008, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.14, 0.82, 0.02)
    _add_back_dock(kb, "BackDock", 1.56, 0.54, w=0.86, d=0.52)
    _add_gen_dock(kb, "GenDock", 0.72, 0.96, w=0.92, h=0.72)

    # 3. Signature Asymmetric Steep-Angled M1A2 DU Composite Cheek Armor + Front Counterweight Tow Lugs
    cheek_specs = [
        ("L", -1.0, -0.46, 0.94, -0.68, (16.0, 18.0, 0.0), 0.74, 0.62, -0.18),
        ("R",  1.0,  0.46, 0.94, -0.68, (16.0, -18.0, 0.0), 0.82, 0.62,  0.18),
    ]
    for tag, sx, cx, cy, cz, crot, cw, ch, lug_x in cheek_specs:
        M_ck = g2b_mat((cx, cy, cz), crot)
        kb.plate(f"CheekMain_{tag}", trap_2d(cw, cw * 0.84, ch, 0.075), 0.24, "armor", "armor_panel",
                 (0, 0, 0), (0, 0, 0), 0.024, 1, M_parent=M_ck)
        kb.plate(f"CheekSub_{tag}", trap_2d(cw * 0.86, cw * 0.74, ch * 0.74, 0.055), 0.090, "armor_sub", "armor_hatch",
                 (0, -0.02, -0.140), (0, 0, 0), 0.014, 1, M_parent=M_ck)
        # Top cheek hex bolt row
        for bi, bx in enumerate([-0.18, 0.0, 0.18]):
            kb.cyl(f"CheekBolt_{tag}_{bi}", 0.011, 0.013, 0.016, 6, "chrome", "plain_metal",
                   (bx, 0.155, -0.188), (90, 0, 0), 0.002, M_parent=M_ck)
        # Signature M1A2 SEP-v3 front counterweight / towing lug bracket + chrome cross-pin
        kb.box(f"TowLug_{tag}", (0.16, 0.14, 0.14), "gunmetal", "bolt_flange",
               (lug_x, -0.18, -0.185), (0, 0, 0), 0.010, 1, M_parent=M_ck)
        kb.cyl(f"TowPin_{tag}", 0.032, 0.032, 0.20, 10, "chrome", "plain_metal",
               (lug_x, -0.18, -0.228), (0, 0, 90), 0.004, M_parent=M_ck)

    # Central Mantlet Armored Eye + Sloped Upper/Lower Glacis + Driver Periscope + Headlights
    kb.box("MantletCore", (0.42, 0.48, 0.32), "dark", "frame_cnc", (0, 0.92, -0.74), (0, 0, 0), 0.018, 1)
    _add_armored_eye(kb, "MantletEye", 0.24, 0.155, (0, 0.96, -0.90), (0, 0, 0), "glass")
    kb.plate("UpperGlacis", trap_2d(1.52, 1.32, 0.60, 0.08), 0.14, "armor", "armor_panel",
             (0, 0.56, -0.74), (-58, 0, 0), 0.020, 1)
    kb.plate("LowerGlacis", trap_2d(1.42, 1.24, 0.34, 0.06), 0.14, "armor_sub", "armor_ribs",
             (0, 0.36, -0.82), (32, 0, 0), 0.018, 1)
    _add_periscope(kb, "DriverPeri", 0.26, 0.078, (0, 0.72, -0.85), (8, 0, 0), "glass")
    kb.box("GlacisHazard", (0.28, 0.022, 0.064), "hazard", "hazard", (0, 0.42, -0.90), (32, 0, 0), 0.003, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.62, 0.56, -0.88), (0, sx * -8.0, 0))
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.40, 0.26, -0.86), scale=1.15)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.68, 1.18, -0.56), (-20, sx * -16.0, 0))

    # 4. Dual Side TUSK ARAT-2 Reactive Armor Skirts (2x4 ERA Tiles per Side) + Upper Turret Overhangs
    for si, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"SkirtBack_{si}", crect_2d(1.08, 0.40, (0.05, 0.05, 0.05, 0.05)), 0.052, "armor_sub", "armor_ribs",
                 (sx * 1.04, 0.52, -0.08), (0, 90, 0), 0.010, 1)
        rot_y = 90.0 if sx < 0 else -90.0
        for row_i, ey in enumerate([0.43, 0.61]):
            for col_i, ez in enumerate([-0.40, -0.08, 0.24]):
                ms = "armor" if (row_i + col_i) % 2 == 0 else "armor_sub"
                kb.era_block(f"ARAT_{si}_{row_i}_{col_i}", (0.305, 0.155, 0.044), ms,
                             (sx * 1.085, ey, ez), (0, rot_y, 0))
        # Upper angled Abrams turret cheek side overhang + grab rail + hydraulic jumper hose
        kb.plate(f"TurretSide_{si}", trap_2d(1.16, 0.96, 0.26, 0.05), 0.26, "armor", "armor_hatch",
                 (sx * 0.82, 1.24, -0.02), (0, 90, sx * -10.0), 0.018, 1)
        kb.grab_rail(f"TurretGrab_{si}", 0.28, 0.045, (sx * 0.86, 1.40, -0.28), (-90, 90, 0), 0.012)
        kb.tube_path(f"SideHyd_{si}",
                     [(sx * 0.82, 0.96, 0.34), (sx * 0.86, 0.72, 0.54), (sx * 0.62, 0.64, 0.76)],
                     0.013, 8, "gunmetal", "braid_hose", add_clamps=True)

    # 5. Roof Deck: Commander Cupola, CITV Sight, Twin Bustle Blow-Off Panels, Crosswind Mast & Exhausts
    kb.cupola_hatch("CmdCupola", (0.46, 1.32, -0.34))
    _add_citv_sight(kb, "CITV_L", (-0.46, 1.32, -0.36), head_slot="armor_sub", lens_slot="emit_cyan")
    # Twin ammunition bustle blow-off panels flush-mounted with corner bolts
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"BlowOff_{si}", (0.30, 0.44, 0.052), "armor_sub", "armor_hatch",
                              (sx * 0.56, 1.35, 0.42), (-90, 0, 0), standoffs=False, bolts=True)
        _add_exhaust_stack(kb, f"Exh_{si}", (sx * 0.60, 1.34, 0.72), (16, 0, 0), 0.24)
    # Crosswind meteorological sensor mast + whip antenna + roof radiator louver
    kb.cyl("XWindPole", 0.022, 0.030, 0.34, 10, "gunmetal", "plain_metal", (-0.74, 1.48, 0.06), (0, 0, 0), 0.003)
    kb.box("XWindHead", (0.12, 0.052, 0.052), "brass", "bolt_flange", (-0.74, 1.66, 0.06), (0, 0, 0), 0.006, 1)
    _add_whip_antenna(kb, "RadioWhip", (0.74, 1.32, 0.16), h=0.92, tilt_x=-7.0)
    kb.louver_bay("RearDeckVent", 0.64, 0.24, 0.055, (0, 1.34, 0.06), (-90, 0, 0), blades=5, mesh_style=False)
    kb.tube_path("CoolantCopper",
                 [(-0.78, 0.44, 0.46), (-0.72, 0.32, 0.72), (-0.44, 0.38, 0.86)],
                 0.015, 8, "copper", "plain_metal", add_clamps=True)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-1.14, 0.82, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.14, 0.82, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.56, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.72, 0.96))


# ==============================================================================
# 2. core_merkava_mk4m — MRK-4M Merkava Mk.4M Trophy APS & Ball-Chain Core
# ==============================================================================

def build_core_merkava_mk4m(kb: KitbashScene):
    """MRK-4M Merkava Mk.4M Core: front-engine knife-edge glacis, arrowhead turret, 4x Trophy APS, ball-chain curtains."""
    # 1. Unified HP-C1 Waist Collar + Dual Hydraulics + Structural Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.22)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.22, r=0.43, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.24, 0.04, -0.34), (sx * 0.36, 0.36, -0.52), 0.024)

    # 2. Recessed CNC Inner Tub + Symmetrical HP-A1 Arm Bulkheads + Rear Docks
    kb.box("InnerHull", (1.58, 1.02, 1.44), "dark", "frame_cnc", (0, 0.78, 0.08), (0, 0, 0), 0.026, 1, tile_u=2.0)
    kb.box("MainArmoredHull", (1.64, 0.94, 1.36), "armor", "armor_panel", (0, 0.80, 0.08), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.16, 0.84, 0.04)
    _add_back_dock(kb, "BackDock", 1.58, 0.56, w=0.86, d=0.52)
    _add_gen_dock(kb, "GenDock", 0.72, 0.98, w=0.92, h=0.72)

    # 3. Signature Front-Engine Long Knife-Edge Cast Wedge Glacis (Left Louver Boss + Right Driver Blister)
    M_gl = g2b_mat((0.0, 0.64, -0.82), (66.0, 0.0, 0.0))
    kb.plate("FrontEngineGlacis", trap_2d(1.56, 1.20, 0.78, 0.085), 0.16, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.022, 1, M_parent=M_gl)
    kb.box("EngineDeckBoss", (0.64, 0.48, 0.095), "armor_sub", "armor_ribs",
           (-0.34, -0.04, -0.10), (0, 0, 0), 0.014, 1, M_parent=M_gl)
    kb.louver_bay("FrontEngineVent", 0.52, 0.38, 0.055, (-0.34, -0.04, -0.150), (0, 0, 0), blades=6,
                  mesh_style=False, M_parent=M_gl)
    kb.box("GlacisHazard", (0.26, 0.060, 0.020), "hazard", "hazard",
           (0.38, -0.26, -0.095), (0, 0, 0), 0.003, 1, M_parent=M_gl)
    # Right driver armored periscope drum + twin bow headlights & tow shackles
    kb.box("DriverHood_R", (0.42, 0.21, 0.34), "armor_sub", "armor_hatch", (0.44, 0.88, -0.68), (0, 0, 0), 0.016, 1)
    _add_periscope(kb, "DriverPeri_R", 0.30, 0.082, (0.44, 0.94, -0.84), (6, 0, 0), "glass")
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.60, 0.48, -1.02), (0, sx * -10.0, 0))
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.38, 0.30, -0.96), scale=1.15)

    # 4. Signature Merkava Arrowhead Wedge Turret + Central Mantlet Eye
    kb.plate("ArrowTurretRoof", trap_2d(1.70, 1.32, 1.34, 0.14), 0.32, "armor", "armor_panel",
             (0, 1.18, 0.02), (90, 0, 0), 0.026, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        M_aw = g2b_mat((sx * 0.44, 1.05, -0.68), (22.0, sx * -22.0, 0.0))
        kb.plate(f"ArrowCheek_{si}", trap_2d(0.68, 0.52, 0.34, 0.055), 0.22, "armor_sub", "armor_hatch",
                 (0, 0, 0), (0, 0, 0), 0.018, 1, M_parent=M_aw)
        kb.grab_rail(f"CheekGrab_{si}", 0.26, 0.042, (0, 0.19, 0.02), (-90, 0, 0), 0.011, M_parent=M_aw)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.64, 1.32, -0.44), (-18, sx * -18.0, 0))
    kb.box("MantletCore", (0.36, 0.28, 0.22), "dark", "frame_cnc", (0, 1.05, -0.70), (0, 0, 0), 0.014, 1)
    _add_armored_eye(kb, "MantletEye", 0.22, 0.14, (0, 1.05, -0.81), (0, 0, 0), "glass")

    # 5. Four-Face Trophy APS Phased-Array Radars + Twin Countermeasure Launchers + Ball-Chain Curtains
    for si, sx in enumerate([-1.0, 1.0]):
        # Front & Rear canted Trophy APS radar panels per flank (4 faces total)
        for ri, (rz, ryaw) in enumerate([(-0.48, sx * -38.0), (0.24, sx * -142.0)]):
            M_tr = g2b_mat((sx * 0.88, 1.22, rz), (0.0, ryaw, sx * -12.0))
            kb.box(f"TrophyBack_{si}_{ri}", (0.28, 0.24, 0.072), "dark", "frame_cnc",
                   (0, 0, 0), (0, 0, 0), 0.008, 1, M_parent=M_tr)
            kb.plate(f"TrophyFace_{si}_{ri}", crect_2d(0.23, 0.19, (0.03, 0.03, 0.03, 0.03)), 0.028,
                     "accent", "armor_pocket", (0, 0, -0.040), (0, 0, 0), 0.004, 1, M_parent=M_tr)
            for bi, (bx, by) in enumerate([(-0.09, -0.07), (0.09, -0.07), (0.09, 0.07), (-0.09, 0.07)]):
                kb.cyl(f"TrBolt_{si}_{ri}_{bi}", 0.007, 0.008, 0.012, 6, "chrome", "plain_metal",
                       (bx, by, -0.056), (90, 0, 0), 0.002, M_parent=M_tr)
        # Trophy active countermeasure launcher pod (between front & rear radars)
        kb.box(f"TrophyLnch_{si}", (0.22, 0.22, 0.30), "gunmetal", "armor_pocket",
               (sx * 0.90, 1.22, -0.12), (0, 0, 0), 0.012, 1)
        kb.plate(f"TrophyShield_{si}", crect_2d(0.18, 0.18, (0.02, 0.02, 0.02, 0.02)), 0.042, "armor_sub", "armor_ribs",
                 (sx * 1.00, 1.22, -0.12), (0, 90, 0), 0.006, 1)
        kb.cyl(f"TrophyDrum_{si}", 0.062, 0.062, 0.24, 12, "dark", "gear_collar",
               (sx * 0.90, 1.33, -0.12), (90, 0, 0), 0.004)
        # Signature Merkava anti-RPG rear hanging ball-and-chain curtain (5 chains per flank)
        kb.box(f"ChainBar_{si}", (0.42, 0.052, 0.082), "gunmetal", "bolt_flange",
               (sx * 0.76, 1.06, 0.74), (0, 0, 0), 0.006, 1)
        for ci, cx_off in enumerate([-0.16, -0.08, 0.0, 0.08, 0.16]):
            cx = sx * 0.76 + cx_off
            kb.cyl(f"ChainRod_{si}_{ci}", 0.012, 0.012, 0.26, 6, "dark", "braid_hose",
                   (cx, 0.91, 0.75), (0, 0, 0), 0.002)
            kb.lathe(f"ChainBall_{si}_{ci}",
                     [(0.0, -0.038), (0.028, -0.024), (0.036, 0.0), (0.028, 0.024), (0.0, 0.038)],
                     8, "gunmetal", "plain_metal", (cx, 0.75, 0.75))
        # Modular side composite armor skirts + spaced standoffs + copper hydraulic lines
        kb.spaced_armor_plate(f"SideSkirt_{si}", (1.24, 0.38, 0.082), "armor_sub", "armor_panel",
                              (sx * 1.04, 0.50, -0.06), (0, sx * 90.0, 0), standoffs=True, bolts=True)
        kb.tube_path(f"TrophyCable_{si}",
                     [(sx * 0.86, 1.14, 0.12), (sx * 0.90, 0.92, 0.36), (sx * 0.72, 0.76, 0.64)],
                     0.013, 8, "copper", "plain_metal", add_clamps=True)

    # 6. Roof Commander Cupola, Right Panoramic CITV, Bustle Stowage & Whip Antennas
    kb.cupola_hatch("CmdCupola_L", (-0.44, 1.34, -0.32))
    _add_citv_sight(kb, "CITV_R", (0.44, 1.34, -0.34), head_slot="armor_sub", lens_slot="emit_cyan")
    kb.stowage_rack("RearBustleRack", (0.0, 1.30, 0.72), (0, 180, 0))
    _add_whip_antenna(kb, "Whip_L", (-0.64, 1.34, 0.36), h=0.92, tilt_x=-8.0)
    _add_whip_antenna(kb, "Whip_R", (0.64, 1.34, 0.36), h=0.84, tilt_x=-6.0)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-1.16, 0.84, 0.04))
    kb.add_marker("SOCKET_arm_r", (1.16, 0.84, 0.04))
    kb.add_marker("SOCKET_back",  (0.0,  1.58, 0.56))
    kb.add_marker("SOCKET_gen",   (0.0,  0.72, 0.98))


# ==============================================================================
# 3. core_mi24_hind — MI-24P Hind Tandem Stepped Gunship Core
# ==============================================================================

def build_core_mi24_hind(kb: KitbashScene):
    """MI-24P Hind Gunship Core: tandem stepped dual-bubble armored cockpits, twin TV3-117 intakes, EVU IR mixers."""
    # 1. Unified HP-C1 Waist Collar + Dual Hydraulics + Collar Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.20)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.20, r=0.40, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.34), (sx * 0.32, 0.34, -0.48), 0.022)

    # 2. Narrow Armored Gunship Fuselage Core + Symmetrical HP-A1 Arm Bulkheads + Rear Docks
    kb.box("InnerFuselage", (1.28, 0.94, 1.40), "dark", "frame_cnc", (0, 0.71, 0.08), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("MainFuselage", (1.34, 0.88, 1.34), "armor", "armor_panel", (0, 0.72, 0.08), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 0.98, 0.72, 0.04)
    _add_back_dock(kb, "BackDock", 1.42, 0.54, w=0.84, d=0.50)
    _add_gen_dock(kb, "GenDock", 0.64, 0.92, w=0.88, h=0.68)

    # 3. Lower Forward Gunner Bubble Cockpit (Faceted Flat Armored Glass + Chin EO/IR + Right GSh-30-2K Cannon)
    M_gn = g2b_mat((0.0, 0.68, -0.78), (0.0, 0.0, 0.0))
    kb.box("GunnerTub", (0.86, 0.42, 0.58), "armor", "armor_hatch", (0, -0.06, 0), (0, 0, 0), 0.020, 1, M_parent=M_gn)
    kb.spaced_armor_plate("GunnerChinPlate", (0.78, 0.22, 0.060), "armor_sub", "armor_ribs",
                          (0, -0.18, -0.30), (26, 0, 0), standoffs=True, bolts=True, M_parent=M_gn)
    # Multi-pane flat armored gunner windshield with mullions, brow & wiper bar
    M_gw = M_gn @ g2b_mat((0.0, 0.19, -0.18), (18.0, 0.0, 0.0))
    kb.box("GunnerWinFrame", (0.54, 0.22, 0.088), "dark", "frame_cnc", (0, 0, 0.022), (0, 0, 0), 0.008, 1, M_parent=M_gw)
    kb.box("GunnerWinBrow", (0.58, 0.028, 0.125), "gunmetal", "bolt_flange", (0, 0.115, -0.018), (10, 0, 0), 0.005, 1, M_parent=M_gw)
    kb.box("GunnerWinRecess", (0.46, 0.145, 0.024), "bore", "plain_metal", (0, -0.004, -0.022), (0, 0, 0), 0.003, 1, M_parent=M_gw)
    for pi, px in enumerate([-0.115, 0.115]):
        kb.box(f"GunnerGlass_{pi}", (0.20, 0.115, 0.016), "glass", "plain_metal", (px, -0.004, -0.036), (0, 0, 0), 0.002, 1, M_parent=M_gw)
    kb.box("GunnerMullion", (0.024, 0.165, 0.056), "dark", "bolt_flange", (0, -0.004, -0.038), (0, 0, 0), 0.003, 1, M_parent=M_gw)
    # Angled side bubble-canopy armored frames + side windows
    for si, sx in enumerate([-1.0, 1.0]):
        M_sb = M_gn @ g2b_mat((sx * 0.40, 0.16, -0.02), (0.0, sx * 82.0, sx * -14.0))
        kb.plate(f"GunnerSideFrame_{si}", trap_2d(0.40, 0.30, 0.22, 0.035), 0.060, "armor_sub", "armor_panel",
                 (0, 0, 0), (0, 0, 0), 0.010, 1, M_parent=M_sb)
        kb.box(f"GunnerSideGlass_{si}", (0.24, 0.11, 0.018), "glass", "plain_metal",
               (0, 0.01, -0.032), (0, 0, 0), 0.003, 1, M_parent=M_sb)
    # Chin left Raduga-Sh targeting blister & EO/IR gimbal + Pitot air-data boom
    kb.eoir_gimbal("ChinRaduga", (-0.22, 0.40, -0.96))
    kb.cyl("PitotBoom", 0.007, 0.012, 0.34, 8, "chrome", "plain_metal", (-0.36, 0.72, -1.10), (90, 0, 0), 0.002)
    # Right side fixed GSh-30-2K twin-barrel 30mm fuselage cannon fairing with true hollow bores
    kb.box("GSh30Fairing", (0.20, 0.20, 0.48), "gunmetal", "armor_ribs", (0.45, 0.56, -0.84), (0, 0, 0), 0.012, 1)
    for bi, by in enumerate([0.52, 0.60]):
        kb.cyl(f"GSh30Tube_{bi}", 0.026, 0.028, 0.30, 10, "dark", "plain_metal",
               (0.46, by, -1.14), (90, 0, 0), 0.003)
        kb.barrel_bore(f"GSh30Bore_{bi}", 0.028, 0.018, (0.46, by, -1.30), depth=0.065, rot_deg=(90, 0, 0), segs=12)

    # 4. Upper Rear Pilot Stepped Bubble Cockpit (Elevated Canopy + Armored Coaming + Overhead Spine)
    M_pl = g2b_mat((0.0, 1.08, -0.42), (0.0, 0.0, 0.0))
    kb.box("PilotCanopyBase", (0.90, 0.30, 0.58), "armor", "armor_panel", (0, 0, 0.04), (0, 0, 0), 0.020, 1, M_parent=M_pl)
    M_pw = M_pl @ g2b_mat((0.0, 0.06, -0.23), (20.0, 0.0, 0.0))
    kb.box("PilotWinFrame", (0.58, 0.21, 0.088), "dark", "frame_cnc", (0, 0, 0.022), (0, 0, 0), 0.008, 1, M_parent=M_pw)
    kb.box("PilotWinBrow", (0.62, 0.028, 0.125), "gunmetal", "bolt_flange", (0, 0.110, -0.018), (10, 0, 0), 0.005, 1, M_parent=M_pw)
    kb.box("PilotWinRecess", (0.50, 0.135, 0.024), "bore", "plain_metal", (0, -0.004, -0.022), (0, 0, 0), 0.003, 1, M_parent=M_pw)
    for pi, px in enumerate([-0.125, 0.125]):
        kb.box(f"PilotGlass_{pi}", (0.215, 0.105, 0.016), "glass", "plain_metal", (px, -0.004, -0.036), (0, 0, 0), 0.002, 1, M_parent=M_pw)
    kb.box("PilotMullion", (0.024, 0.155, 0.056), "dark", "bolt_flange", (0, -0.004, -0.038), (0, 0, 0), 0.003, 1, M_parent=M_pw)
    kb.grab_rail("PilotRoofGrab", 0.34, 0.042, (0, 0.17, 0.06), (-90, 0, 0), 0.011, M_parent=M_pl)
    kb.box("CockpitHazard", (0.24, 0.020, 0.048), "hazard", "hazard", (0, -0.14, -0.25), (0, 0, 0), 0.003, 1, M_parent=M_pl)

    # 5. Twin Roof TV3-117 Dust-Separator Turboshaft Intakes + Side Box-Type EVU IR-Suppressor Mixers
    for si, sx in enumerate([-1.0, 1.0]):
        # TV3-117 intake nacelle + gunmetal lip + iconic chrome hemispherical dust-separator dome
        kb.cyl(f"TV3117Pod_{si}", 0.155, 0.155, 0.50, 16, "armor_sub", "armor_panel",
               (sx * 0.46, 1.22, 0.04), (90, 0, 0), 0.008)
        kb.cyl(f"TV3117Lip_{si}", 0.135, 0.155, 0.12, 16, "gunmetal", "gear_collar",
               (sx * 0.46, 1.22, -0.24), (90, 0, 0), 0.005, hollow_r=0.108)
        kb.lathe(f"TV3117Dome_{si}",
                 [(0.105, -0.04), (0.112, 0.0), (0.095, 0.04), (0.055, 0.075), (0.0, 0.092)],
                 14, "chrome", "plain_metal", (sx * 0.46, 1.22, -0.29), (90, 0, 0))
        kb.bolt_ring(f"TV3117Bolts_{si}", 0.145, 8, 0.009, (sx * 0.46, 1.22, -0.18), (90, 0, 0))
        # Side box-type EVU IR-suppressor exhaust mixer with louver baffle + perforated shield
        kb.box(f"EVUMixer_{si}", (0.26, 0.29, 0.50), "dark", "frame_cnc",
               (sx * 0.74, 1.06, 0.16), (0, 0, 0), 0.014, 1)
        kb.louver_bay(f"EVUVent_{si}", 0.30, 0.22, 0.050, (sx * 0.87, 1.06, 0.16), (0, sx * 90.0, 0),
                      blades=5, mesh_style=(si == 1))
        # Lower flank avionics spaced armor + copper/braided oil lines + landing lights
        kb.spaced_armor_plate(f"FlankBay_{si}", (0.86, 0.38, 0.068), "armor_sub", "armor_hatch",
                              (sx * 0.72, 0.48, 0.18), (0, sx * 90.0, 0), standoffs=True, bolts=True)
        kb.headlight_cage(f"LandingLight_{si}", (sx * 0.52, 0.46, -0.78), (10, sx * -12.0, 0))
        kb.tow_shackle(f"TieDown_{si}", (sx * 0.34, 0.28, -0.82), scale=1.0)
        kb.tube_path(f"OilLine_{si}",
                     [(sx * 0.56, 1.12, 0.28), (sx * 0.68, 0.90, 0.48), (sx * 0.54, 0.68, 0.68)],
                     0.014, 8, "copper" if si == 0 else "gunmetal", "plain_metal" if si == 0 else "braid_hose")

    # 6. Overhead Main Rotor Mast Fairing Hub + Dorsal Radiator + Antennas
    kb.cyl("RotorHubBase", 0.22, 0.26, 0.16, 14, "dark", "gear_collar", (0, 1.26, 0.08), (0, 0, 0), 0.008)
    kb.bolt_ring("RotorHubBolts", 0.20, 10, 0.010, (0, 1.345, 0.08), (0, 0, 0))
    kb.louver_bay("TopAvionicsVent", 0.46, 0.24, 0.050, (0, 1.22, 0.32), (-90, 0, 0), blades=5, mesh_style=True)
    kb.stowage_rack("SideAmmoRack", (-0.75, 0.54, 0.44), (0, -90, 0))
    _add_whip_antenna(kb, "IffWhip_L", (-0.54, 1.22, 0.34), h=0.88, tilt_x=-8.0)
    _add_whip_antenna(kb, "IffWhip_R", (0.54, 1.22, 0.34), h=0.78, tilt_x=-6.0)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-0.98, 0.72, 0.04))
    kb.add_marker("SOCKET_arm_r", (0.98, 0.72, 0.04))
    kb.add_marker("SOCKET_back",  (0.0,  1.42, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.64, 0.92))


# ==============================================================================
# 4. core_pantsir_s1 — 96K6-M Pantsir-S1 Dual Phased-Array AA Core
# ==============================================================================

def build_core_pantsir_s1(kb: KitbashScene):
    """96K6-M Pantsir-S1 Core: canted octagonal 1RS2-1E tracking radar, 10ES1 EO pillar, 2RL80 search array, RF pipes."""
    # 1. Unified HP-C1 Waist Collar + Dual Hydraulics + Collar Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.20)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.20, r=0.41, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.34), (sx * 0.34, 0.34, -0.48), 0.023)

    # 2. Recessed CNC Inner Chassis + Symmetrical HP-A1 Bulkheads + Rear Docks
    kb.box("InnerHull", (1.46, 1.00, 1.38), "dark", "frame_cnc", (0, 0.75, 0.06), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("MainArmoredHull", (1.52, 0.96, 1.34), "armor", "armor_panel", (0, 0.76, 0.06), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.08, 0.78, 0.02)
    _add_back_dock(kb, "BackDock", 1.50, 0.52, w=0.84, d=0.52)
    _add_gen_dock(kb, "GenDock", 0.68, 0.92, w=0.90, h=0.70)

    # 3. Signature Chest-Mounted 18-deg Octagonal 1RS2-1E Millimeter-Wave Fire-Control Radar
    M_1rs = g2b_mat((0.0, 0.88, -0.70), (18.0, 0.0, 0.0))
    kb.plate("Radar1RS2_Frame", _oct_2d(0.49), 0.125, "dark", "frame_cnc",
             (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_1rs)
    kb.plate("Radar1RS2_Dish", _oct_2d(0.415), 0.048, "armor_sub", "armor_pocket",
             (0, 0, -0.062), (0, 0, 0), 0.008, 1, M_parent=M_1rs)
    for wi in range(7):
        wy = -0.255 + wi * 0.085
        kb.box(f"Radar1RS2_Rib_{wi}", (0.62, 0.018, 0.022), "gunmetal", "armor_ribs",
               (0, wy, -0.090), (0, 0, 0), 0.003, 1, M_parent=M_1rs)
    kb.bolt_ring("Radar1RS2_Bolts", 0.44, 12, 0.010, (0, 0, -0.064), (90, 0, 0), M_parent=M_1rs)
    kb.box("Radar1RS2_Brow", (0.56, 0.036, 0.16), "armor", "bolt_flange",
           (0, 0.47, -0.05), (8, 0, 0), 0.006, 1, M_parent=M_1rs)
    kb.box("Radar1RS2_Haz", (0.30, 0.036, 0.020), "hazard", "hazard",
           (0, -0.45, -0.068), (0, 0, 0), 0.003, 1, M_parent=M_1rs)
    # Radar elevation hydraulic braces
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"RadarStrut_{si}", (sx * 0.46, 0.72, -0.58), (sx * 0.42, 0.94, -0.68), 0.018)

    # 4. Lower Armored Chin Radiator Bulkhead (Twin Symmetrical Louver Bays + Caged Headlights)
    kb.box("LowerChinHull", (1.44, 0.36, 0.24), "armor", "armor_ribs", (0, 0.44, -0.68), (0, 0, 0), 0.018, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.louver_bay(f"ChinVent_{si}", 0.38, 0.24, 0.052, (sx * 0.46, 0.44, -0.805), (0, 0, 0), blades=4, mesh_style=False)
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.64, 0.64, -0.74), (0, sx * -10.0, 0))
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.24, 0.28, -0.78), scale=1.05)

    # 5. Roof Left 10ES1 EO/IR Tracking Pillar + Roof Right 2RL80 Acquisition Radar Bar
    # Left 10ES1 IR/EO optical tracking turret
    M_eo = g2b_mat((-0.42, 1.27, -0.34), (0.0, 0.0, 0.0))
    kb.cyl("Optic10ES1_Ped", 0.145, 0.175, 0.18, 14, "dark", "gear_collar", (0, 0.085, 0), (0, 0, 0), 0.006, M_parent=M_eo)
    kb.bolt_ring("Optic10ES1_Bolts", 0.155, 8, 0.009, (0, 0.015, 0), (0, 0, 0), M_parent=M_eo)
    kb.box("Optic10ES1_Head", (0.28, 0.23, 0.26), "armor", "armor_pocket", (0, 0.25, 0), (0, 0, 0), 0.014, 1, M_parent=M_eo)
    _add_optic_lens(kb, "Optic10ES1_Main", 0.064, (0, 0.25, -0.132), (90, 0, 0), "emit_cyan", M_parent=M_eo)
    kb.box("Optic10ES1_Hood", (0.30, 0.026, 0.16), "gunmetal", "bolt_flange", (0, 0.375, -0.05), (6, 0, 0), 0.004, 1, M_parent=M_eo)

    # Right 2RL80 dual-face S-band acquisition radar bar
    M_sr = g2b_mat((0.42, 1.27, -0.32), (0.0, -16.0, 0.0))
    kb.cyl("Search2RL80_Ped", 0.13, 0.155, 0.14, 14, "gunmetal", "gear_collar", (0, 0.07, 0), (0, 0, 0), 0.005, M_parent=M_sr)
    kb.box("Search2RL80_Bar", (0.50, 0.25, 0.13), "armor_sub", "armor_panel", (0, 0.23, 0), (10, 0, 0), 0.012, 1, M_parent=M_sr)
    kb.plate("Search2RL80_Face", crect_2d(0.42, 0.18, (0.025, 0.025, 0.025, 0.025)), 0.032, "accent", "armor_ribs",
             (0, 0.23, -0.072), (10, 0, 0), 0.005, 1, M_parent=M_sr)
    kb.cyl("Search2RL80_IFF", 0.012, 0.012, 0.44, 8, "brass", "plain_metal", (0, 0.38, -0.02), (0, 0, 90), 0.002, M_parent=M_sr)

    # 6. Flank Avionics / Missile-Guidance Cheek Pods + Copper Waveguide Conduits + Side Louvers
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"FlankPod_{si}", (0.94, 0.58, 0.16), "armor_sub", "armor_pocket",
                              (sx * 0.86, 0.80, 0.04), (0, sx * 90.0, 0), standoffs=True, bolts=True)
        # Compact twin AA missile rack rail canisters tucked behind shoulder
        for ti, ty in enumerate([1.06, 0.90]):
            kb.cyl(f"AARackTube_{si}_{ti}", 0.046, 0.048, 0.56, 12, "dark", "armor_ribs",
                   (sx * 0.96, ty, 0.24), (90, 0, 0), 0.004, hollow_r=0.034)
        # Signature curved copper RF waveguide / coolant conduit with brass compression fittings
        kb.tube_path(f"RFCopper_{si}",
                     [(sx * 0.78, 1.08, -0.28), (sx * 0.86, 0.86, 0.0), (sx * 0.78, 0.62, 0.28)],
                     0.020, 8, "copper", "plain_metal", add_clamps=True)
        for fi, (fy, fz) in enumerate([(1.08, -0.28), (0.62, 0.28)]):
            kb.cyl(f"RFFit_{si}_{fi}", 0.030, 0.032, 0.042, 6, "brass", "gear_collar",
                   (sx * 0.78, fy, fz), (0, 0, 90), 0.003)
        kb.grab_rail(f"FlankGrab_{si}", 0.26, 0.040, (sx * 0.95, 0.52, -0.22), (0, sx * 90.0, 0), 0.011)
        _add_exhaust_stack(kb, f"Exh_{si}", (sx * 0.56, 1.32, 0.68), (12, 0, 0), 0.24)

    kb.louver_bay("TopCoolingBay", 0.64, 0.26, 0.055, (0, 1.28, 0.08), (-90, 0, 0), blades=5, mesh_style=True)
    _add_whip_antenna(kb, "DataLinkWhip", (-0.64, 1.26, 0.24), h=0.96, tilt_x=-7.0)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-1.08, 0.78, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.08, 0.78, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.50, 0.52))
    kb.add_marker("SOCKET_gen",   (0.0,  0.68, 0.92))


# ==============================================================================
# 5. core_patriot_mpq65 — MPQ-65 Patriot Inclined Phased-Array Core
# ==============================================================================

def build_core_patriot_mpq65(kb: KitbashScene):
    """MPQ-65 Patriot Core: full-chest 26-deg AN/MPQ-65 phased-array bulkhead, main/TVM/IFF arrays, twin liquid coolers."""
    # 1. Unified HP-C1 Waist Collar + Dual Hydraulics + Structural Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.22)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.22, r=0.42, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.34), (sx * 0.34, 0.36, -0.50), 0.024)

    # 2. Recessed CNC Inner Chassis + Symmetrical HP-A1 Bulkheads + Rear Docks
    kb.box("InnerHull", (1.54, 1.04, 1.42), "dark", "frame_cnc", (0, 0.77, 0.06), (0, 0, 0), 0.026, 1, tile_u=2.0)
    kb.box("MainArmoredHull", (1.58, 1.02, 1.38), "armor", "armor_panel", (0, 0.78, 0.06), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.12, 0.80, 0.04)
    _add_back_dock(kb, "BackDock", 1.54, 0.54, w=0.86, d=0.52)
    _add_gen_dock(kb, "GenDock", 0.70, 0.94, w=0.92, h=0.72)

    # 3. Signature Full-Chest 26-deg Inclined AN/MPQ-65 Phased-Array Radar Armor Bulkhead
    M_mpq = g2b_mat((0.0, 0.84, -0.72), (26.0, 0.0, 0.0))
    kb.box("MPQ65_Slab", (1.52, 1.04, 0.22), "armor", "armor_panel", (0, 0, 0.04), (0, 0, 0), 0.022, 1, M_parent=M_mpq)
    # Main left-offset octagonal C-band phased-array dish + waveguide ribs + 12-bolt collar
    kb.plate("MPQ65_MainBezel", _oct_2d(0.45), 0.060, "dark", "frame_cnc",
             (-0.16, 0.08, -0.088), (0, 0, 0), 0.010, 1, M_parent=M_mpq)
    kb.plate("MPQ65_MainFace", _oct_2d(0.39), 0.032, "gunmetal", "vent_mesh",
             (-0.16, 0.08, -0.118), (0, 0, 0), 0.006, 1, M_parent=M_mpq)
    kb.bolt_ring("MPQ65_MainBolts", 0.415, 12, 0.009, (-0.16, 0.08, -0.095), (90, 0, 0), M_parent=M_mpq)
    for ri in range(5):
        ry = -0.16 + ri * 0.08
        kb.box(f"MPQ65_Slot_{ri}", (0.50, 0.016, 0.018), "dark", "armor_ribs",
               (-0.16, 0.08 + ry, -0.136), (0, 0, 0), 0.003, 1, M_parent=M_mpq)
    # Secondary upper-right TVM guidance octagonal array
    kb.plate("MPQ65_SubBezel", _oct_2d(0.205), 0.052, "dark", "frame_cnc",
             (0.44, 0.18, -0.086), (0, 0, 0), 0.008, 1, M_parent=M_mpq)
    kb.plate("MPQ65_SubFace", _oct_2d(0.162), 0.026, "armor_sub", "vent_mesh",
             (0.44, 0.18, -0.112), (0, 0, 0), 0.004, 1, M_parent=M_mpq)
    # Lower-right ECCM / sidelobe canceller accent array
    kb.spaced_armor_plate("MPQ65_ECCM", (0.44, 0.15, 0.052), "accent", "armor_pocket",
                          (0.42, -0.14, -0.090), (0, 0, 0), standoffs=False, bolts=True, M_parent=M_mpq)
    # Full-width lower IFF horizontal interrogator bar + recessed dipole bars
    kb.box("MPQ65_IFFBar", (1.30, 0.115, 0.058), "armor_sub", "armor_ribs",
           (0, -0.38, -0.088), (0, 0, 0), 0.008, 1, M_parent=M_mpq)
    for di in range(6):
        dx = -0.50 + di * 0.20
        kb.box(f"MPQ65_Dip_{di}", (0.12, 0.032, 0.022), "gunmetal", "bolt_flange",
               (dx, -0.38, -0.122), (0, 0, 0), 0.003, 1, M_parent=M_mpq)
    # Upper-right armored optical eye + top rain-shield hood + hazard strip
    _add_armored_eye(kb, "MPQ65_Eye", 0.16, 0.105, (0.46, 0.38, -0.092), (0, 0, 0), "glass", M_parent=M_mpq)
    kb.box("MPQ65_TopHood", (1.50, 0.042, 0.18), "gunmetal", "bolt_flange",
           (0, 0.52, -0.08), (8, 0, 0), 0.006, 1, M_parent=M_mpq)
    kb.box("MPQ65_Hazard", (0.36, 0.036, 0.018), "hazard", "hazard",
           (-0.44, -0.47, -0.092), (0, 0, 0), 0.003, 1, M_parent=M_mpq)
    # Twin rear hydraulic elevation jacks bracing the 26-deg radar slab to the hull
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"ArrayJack_{si}", (sx * 0.56, 0.42, -0.56), (sx * 0.58, 0.72, -0.82), 0.022)
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.44, 0.28, -0.84), scale=1.10)
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.66, 0.42, -0.86), (0, sx * -10.0, 0))

    # 4. Twin Flank Liquid-Cooled Heat-Exchanger Units + Copper Coolant Pump Drums & Braided Hoses
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"LiqCooler_{si}", (0.25, 0.68, 0.64), "armor_sub", "armor_hatch",
               (sx * 0.92, 0.84, 0.28), (0, 0, 0), 0.018, 1)
        kb.louver_bay(f"CoolerVent_{si}", 0.50, 0.54, 0.055, (sx * 1.045, 0.84, 0.28), (0, sx * 90.0, 0),
                      blades=6, mesh_style=False)
        # Lower cylindrical coolant pump drum + machined copper cooling ring + braided transfer pipes
        kb.cyl(f"PumpDrum_{si}", 0.16, 0.16, 0.12, 14, "dark", "gear_collar",
               (sx * 0.82, 0.44, -0.36), (0, 0, 90), 0.006)
        kb.cyl(f"PumpCoil_{si}", 0.145, 0.145, 0.058, 14, "copper", "plain_metal",
               (sx * 0.89, 0.44, -0.36), (0, 0, 90), 0.004, hollow_r=0.095)
        kb.tube_path(f"CoolantPipe_{si}",
                     [(sx * 0.88, 0.44, -0.26), (sx * 0.94, 0.52, -0.02), (sx * 0.92, 0.62, 0.18)],
                     0.018, 8, "copper", "plain_metal", add_clamps=True)
        kb.tube_path(f"ReturnHose_{si}",
                     [(sx * 0.84, 0.36, -0.24), (sx * 0.88, 0.38, 0.10), (sx * 0.72, 0.46, 0.56)],
                     0.014, 8, "gunmetal", "braid_hose", add_clamps=True)

    # 5. Roof Commander Cupola, Heavy Maintenance Grab Rail, SATCOM Recon Mast & Exhausts
    kb.cupola_hatch("CmdCupola_L", (-0.44, 1.31, -0.26))
    kb.grab_rail("RoofGrab_R", 0.34, 0.052, (0.44, 1.33, -0.26), (-90, 0, 0), 0.014)
    kb.recon_mast("SatcomMast", (0.46, 1.31, 0.12))
    kb.louver_bay("TopHeatBay", 0.58, 0.24, 0.052, (-0.12, 1.31, 0.14), (-90, 0, 0), blades=5, mesh_style=True)
    for si, sx in enumerate([-1.0, 1.0]):
        _add_exhaust_stack(kb, f"Exh_{si}", (sx * 0.58, 1.32, 0.68), (12, 0, 0), 0.24)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-1.12, 0.80, 0.04))
    kb.add_marker("SOCKET_arm_r", (1.12, 0.80, 0.04))
    kb.add_marker("SOCKET_back",  (0.0,  1.54, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.70, 0.94))


# ==============================================================================
# 6. core_pionier_dach — PIO-2A Pionierpanzer Dachs Recovery & Crane Core
# ==============================================================================

def build_core_pionier_dach(kb: KitbashScene):
    """PIO-2A Pionierpanzer Dachs Core: 35t bow winch fairlead, stowed telescopic crane boom, dozer lip, oxy-cutting rack."""
    # 1. Unified HP-C1 Waist Collar + Dual Hydraulics + Collar Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.22)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.22, r=0.42, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.34), (sx * 0.34, 0.36, -0.50), 0.024)

    # 2. Recessed CNC Inner Chassis + Symmetrical HP-A1 Bulkheads + Rear Docks
    kb.box("InnerHull", (1.52, 1.02, 1.42), "dark", "frame_cnc", (0, 0.76, 0.06), (0, 0, 0), 0.026, 1, tile_u=2.0)
    kb.box("MainArmoredHull", (1.58, 1.00, 1.38), "armor", "armor_panel", (0, 0.77, 0.06), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.12, 0.78, 0.02)
    _add_back_dock(kb, "BackDock", 1.52, 0.54, w=0.86, d=0.52)
    _add_gen_dock(kb, "GenDock", 0.70, 0.94, w=0.92, h=0.70)

    # 3. Pionier 34-deg Armored Glacis + Heavy 35-Ton Copper Cable Winch Fairlead + Engineering Dozer Lip
    kb.plate("PionierGlacis", trap_2d(1.50, 1.30, 0.64, 0.08), 0.15, "armor", "armor_panel",
             (0, 0.84, -0.68), (34, 0, 0), 0.022, 1)
    kb.grab_rail("GlacisGrab", 0.34, 0.044, (0.34, 1.02, -0.76), (34, 0, 0), 0.011)
    # Signature 35-ton recessed bow recovery winch fairlead with copper drum, chrome vertical rollers & accent hook
    M_wn = g2b_mat((0.0, 0.50, -0.84), (0.0, 0.0, 0.0))
    kb.box("WinchHouse", (0.70, 0.28, 0.25), "dark", "frame_cnc", (0, 0, 0), (0, 0, 0), 0.016, 1, M_parent=M_wn)
    kb.cyl("WinchDrum", 0.092, 0.092, 0.48, 14, "copper", "braid_hose",
           (0, 0, -0.04), (0, 0, 90), 0.005, u_rep=3.0, M_parent=M_wn)
    for ri, rx in enumerate([-0.24, 0.24]):
        kb.cyl(f"WinchRoller_{ri}", 0.032, 0.032, 0.23, 10, "chrome", "plain_metal",
               (rx, 0, -0.125), (0, 0, 0), 0.003, M_parent=M_wn)
        kb.cyl(f"WinchCap_{ri}", 0.044, 0.044, 0.026, 8, "brass", "gear_collar",
               (rx, 0.125, -0.125), (0, 0, 0), 0.002, M_parent=M_wn)
    kb.cyl("WinchHookRing", 0.078, 0.078, 0.036, 14, "accent", "plain_metal",
           (0, -0.02, -0.165), (0, 0, 90), 0.005, hollow_r=0.042, M_parent=M_wn)
    # Compact stowed lower engineering push-blade / dozer bumper bar with hazard trim & hydraulic struts
    kb.plate("DozerBladeLip", trap_2d(1.38, 1.22, 0.22, 0.045), 0.085, "armor_sub", "armor_ribs",
             (0, 0.24, -0.88), (22, 0, 0), 0.012, 1)
    kb.box("DozerEdge", (1.40, 0.046, 0.042), "hazard", "hazard", (0, 0.16, -0.94), (22, 0, 0), 0.004, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"DozerBrace_{si}", (sx * 0.44, 0.26, -0.62), (sx * 0.50, 0.24, -0.84), 0.020)
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.54, 0.72, -0.84), (0, sx * -8.0, 0))
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.56, 0.36, -0.86), scale=1.15)

    # 4. Left-Roof Stowed Telescopic Box-Girder Engineering Crane Boom + Heavy Hydraulic Piston + Travel Lock
    M_cr = g2b_mat((-0.54, 1.32, -0.12), (0.0, 0.0, 0.0))
    kb.box("CranePivotBase", (0.28, 0.18, 0.26), "dark", "frame_cnc", (0, -0.02, 0.34), (0, 0, 0), 0.012, 1, M_parent=M_cr)
    kb.box("CraneBoomOuter", (0.24, 0.20, 0.94), "accent", "armor_ribs", (0, 0.08, -0.18), (0, 0, 0), 0.014, 1, M_parent=M_cr)
    kb.box("CraneBoomInner", (0.18, 0.15, 0.38), "gunmetal", "bolt_flange", (0, 0.08, -0.68), (0, 0, 0), 0.010, 1, M_parent=M_cr)
    kb.cyl("CranePulley", 0.086, 0.086, 0.145, 14, "dark", "gear_collar", (0, 0.06, -0.87), (0, 0, 90), 0.005, M_parent=M_cr)
    kb.cyl("CraneAxle", 0.032, 0.032, 0.21, 10, "chrome", "plain_metal", (0, 0.06, -0.87), (0, 0, 90), 0.003, M_parent=M_cr)
    kb.box("CraneHazard", (0.25, 0.044, 0.14), "hazard", "hazard", (0, 0.08, -0.58), (0, 0, 0), 0.003, 1, M_parent=M_cr)
    kb.hydraulic("CraneElevCyl", (-0.54, 1.24, 0.16), (-0.54, 1.36, -0.44), 0.030)
    kb.box("CraneRestCradle", (0.24, 0.28, 0.16), "dark", "frame_cnc", (-0.54, 1.22, -0.54), (0, 0, 0), 0.010, 1)
    kb.tube_path("CraneHydHose",
                 [(-0.40, 1.28, 0.28), (-0.38, 1.36, -0.06), (-0.42, 1.34, -0.36)],
                 0.014, 8, "gunmetal", "braid_hose", add_clamps=True)

    # 5. Right-Flank Twin Oxy-Acetylene Cutting Gas Cylinder Cage + Dual Side Tool Lockers
    M_ox = g2b_mat((0.88, 0.96, 0.24), (0.0, 0.0, 0.0))
    kb.box("OxyRackBase", (0.25, 0.14, 0.56), "dark", "frame_cnc", (0, -0.14, 0), (0, 0, 0), 0.010, 1, M_parent=M_ox)
    kb.box("OxyRackStrap", (0.26, 0.036, 0.56), "gunmetal", "bolt_flange", (0, 0.12, 0), (0, 0, 0), 0.004, 1, M_parent=M_ox)
    for ti, tz in enumerate([-0.14, 0.14]):
        kb.cyl(f"OxyTank_{ti}", 0.078, 0.078, 0.44, 14, "gunmetal" if ti == 0 else "armor_sub", "plain_metal",
               (0.02, 0.08, tz), (0, 0, 0), 0.010, M_parent=M_ox)
        kb.cyl(f"OxyValve_{ti}", 0.034, 0.064, 0.085, 10, "brass", "gear_collar",
               (0.02, 0.33, tz), (0, 0, 0), 0.004, M_parent=M_ox)
    kb.tube_path("OxyTorchHose",
                 [(0.90, 1.28, 0.10), (0.94, 1.12, 0.24), (0.86, 0.86, 0.48)],
                 0.012, 8, "copper", "plain_metal", add_clamps=True)
    # Left & Right lower armored tool stowage boxes + left field stowage rack
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"ToolBox_{si}", (0.96, 0.38, 0.22), "armor_sub", "armor_hatch",
                              (sx * 0.90, 0.50, -0.04), (0, sx * 90.0, 0), standoffs=False, bolts=True)
        _add_exhaust_stack(kb, f"Exh_{si}", (sx * 0.58, 1.32, 0.68), (12, 0, 0), 0.24)
    kb.stowage_rack("LeftToolRack", (-0.94, 0.96, 0.28), (0, -90, 0))

    # 6. Right-Roof Commander Cupola + Dorsal Radiator Louver + Whip Antenna
    kb.cupola_hatch("CmdCupola_R", (0.44, 1.29, -0.34))
    kb.louver_bay("TopEngineVent", 0.56, 0.26, 0.055, (0.04, 1.29, 0.14), (-90, 0, 0), blades=5, mesh_style=False)
    _add_whip_antenna(kb, "EngWhip", (0.68, 1.28, 0.22), h=0.90, tilt_x=-6.0)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-1.12, 0.78, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.12, 0.78, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.52, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.70, 0.94))


# ==============================================================================
# 7. core_puma_spz — SPZ-30 Puma Hedgehog & AMAP Composite Core
# ==============================================================================

def build_core_puma_spz(kb: KitbashScene):
    """SPZ-30 Puma Core: rubber hedgehog top-attack strips, bolted AMAP spaced flank cassettes, MUSS warning pods."""
    # 1. Unified HP-C1 Waist Collar + Dual Hydraulics + Structural Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.20)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.20, r=0.41, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.34), (sx * 0.34, 0.34, -0.48), 0.023)

    # 2. Recessed CNC Inner Chassis + Symmetrical HP-A1 Bulkheads + Rear Docks
    kb.box("InnerHull", (1.46, 0.96, 1.40), "dark", "frame_cnc", (0, 0.73, 0.06), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("MainArmoredHull", (1.52, 0.94, 1.36), "armor", "armor_panel", (0, 0.74, 0.06), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.08, 0.76, 0.02)
    _add_back_dock(kb, "BackDock", 1.46, 0.52, w=0.84, d=0.52)
    _add_gen_dock(kb, "GenDock", 0.68, 0.92, w=0.90, h=0.68)

    # 3. German Level-C Heavy IFV Wedge Glacis + 6 Rubber "Igelpanzerung" Hedgehog Anti-Top-Attack Strips
    kb.plate("UpperGlacis", trap_2d(1.52, 1.32, 0.58, 0.07), 0.14, "armor", "armor_panel",
             (0, 0.88, -0.68), (52, 0, 0), 0.022, 1)
    kb.plate("LowerGlacis", trap_2d(1.44, 1.24, 0.46, 0.06), 0.14, "armor_sub", "armor_ribs",
             (0, 0.46, -0.78), (-38, 0, 0), 0.020, 1)
    # 6 longitudinal rubber hedgehog spike-mat rails along upper glacis
    for hi, hx in enumerate([-0.50, -0.30, -0.10, 0.10, 0.30, 0.50]):
        kb.box(f"HedgehogPad_{hi}", (0.125, 0.044, 0.36), "rubber", "dust_boot",
               (hx, 0.99, -0.58), (-38, 0, 0), 0.006, 1)
        kb.cyl(f"HedgehogBolt_{hi}", 0.009, 0.011, 0.014, 6, "chrome", "plain_metal",
               (hx, 1.09, -0.46), (-38, 0, 0), 0.002)
    kb.box("GlacisHazard", (0.28, 0.020, 0.056), "hazard", "hazard", (0, 0.42, -0.87), (-38, 0, 0), 0.003, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.58, 0.62, -0.84), (0, sx * -10.0, 0))
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.38, 0.30, -0.82), scale=1.10)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.68, 1.18, -0.14), (-22, sx * -18.0, 0))

    # 4. Signature Ultra-Thick Bolted AMAP Modular Composite Spaced Flank Cassettes (4x per Side)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"AMAPBase_{si}", (0.22, 0.44, 1.28), "armor", "armor_panel",
               (sx * 0.92, 0.54, -0.04), (0, 0, 0), 0.020, 1)
        # Standoff air-gap mounting brackets welding AMAP box to main hull
        for bi, bz in enumerate([-0.46, 0.0, 0.46]):
            kb.box(f"AMAPBrk_{si}_{bi}", (0.12, 0.14, 0.08), "dark", "frame_cnc",
                   (sx * 0.78, 0.54, bz), (0, 0, 0), 0.006, 1)
        # 4 bolted AMAP composite cassettes per side with paired chrome locking pins
        for ci, cz in enumerate([-0.45, -0.15, 0.15, 0.45]):
            kb.plate(f"AMAPTile_{si}_{ci}", crect_2d(0.25, 0.36, (0.022, 0.022, 0.022, 0.022)),
                     0.044, "armor_sub", "armor_hatch", (sx * 1.03, 0.54, cz), (0, 90, 0), 0.008, 1)
            for py in [-0.12, 0.12]:
                kb.cyl(f"AMAPBolt_{si}_{ci}_{int(py * 100)}", 0.015, 0.017, 0.028, 6, "chrome", "plain_metal",
                       (sx * 1.06, 0.54 + py, cz), (0, 0, 90), 0.002)
        # Front-corner MUSS soft-kill active protection jammer/warning turret
        M_ms = g2b_mat((sx * 0.66, 1.21, -0.44), (0.0, sx * -24.0, 0.0))
        kb.cyl(f"MUSSPod_{si}", 0.095, 0.112, 0.15, 12, "gunmetal", "gear_collar",
               (0, 0.06, 0), (0, 0, 0), 0.005, M_parent=M_ms)
        _add_optic_lens(kb, f"MUSSLens_{si}", 0.036, (0, 0.07, -0.098), (90, 0, 0), "emit_cyan", M_parent=M_ms)
        kb.grab_rail(f"FlankGrab_{si}", 0.26, 0.042, (sx * 0.80, 1.06, 0.18), (0, sx * 90.0, 0), 0.011)
        kb.tube_path(f"HydHose_{si}",
                     [(sx * 0.82, 0.84, 0.36), (sx * 0.86, 0.68, 0.54), (sx * 0.64, 0.60, 0.72)],
                     0.013, 8, "gunmetal" if si == 1 else "copper", "braid_hose" if si == 1 else "plain_metal")

    # 5. Roof: Left Panoramic PERI-RTWL CITV, Right 3-Prism Periscope Blister, Top Radiator & Exhausts
    _add_citv_sight(kb, "PERI_CITV", (-0.34, 1.23, -0.34), head_slot="armor", lens_slot="emit_cyan")
    kb.box("PeriBlister_R", (0.46, 0.16, 0.36), "armor_sub", "armor_hatch", (0.38, 1.24, -0.36), (0, 0, 0), 0.014, 1)
    for pi, (px, pyaw) in enumerate([(0.26, 11.0), (0.38, 0.0), (0.50, -11.0)]):
        _add_periscope(kb, f"RoofPeri_{pi}", 0.10, 0.060, (px, 1.29, -0.53), (4, pyaw, 0), "glass")
    kb.louver_bay("TopCoolingBay", 0.62, 0.28, 0.055, (0, 1.24, 0.10), (-90, 0, 0), blades=5, mesh_style=False)
    for si, sx in enumerate([-1.0, 1.0]):
        _add_exhaust_stack(kb, f"Exh_{si}", (sx * 0.54, 1.28, 0.64), (12, 0, 0), 0.22)
    _add_whip_antenna(kb, "Whip_L", (-0.64, 1.24, 0.22), h=0.88, tilt_x=-7.0)
    _add_whip_antenna(kb, "Whip_R", (0.64, 1.24, 0.22), h=0.82, tilt_x=-6.0)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-1.08, 0.76, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.08, 0.76, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.46, 0.52))
    kb.add_marker("SOCKET_gen",   (0.0,  0.68, 0.92))


# ==============================================================================
# 8. core_std — MK-II Standard Multi-Faceted Tactical Core
# ==============================================================================

def build_core_std(kb: KitbashScene):
    """MK-II Standard Core: B.o.T multi-faceted chest armor, twin wing ERA, right-offset tri-optic sensor head."""
    # 1. Unified HP-C1 Waist Collar (r=0.360m, y_bot=-0.005m) + Dual Waist Hydraulics + Collar Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.14)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.135, r=0.35, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.30, 0.015, -0.22), (sx * 0.40, 0.22, -0.36), 0.020)

    # 2. Compact MK-II Recessed CNC Frame + Chamfered Outer Torso Shell + Symmetrical HP-A1 Bulkheads
    kb.box("InnerCoreFrame", (1.24, 0.68, 1.04), "dark", "frame_cnc", (0, 0.36, 0.08), (0, 0, 0), 0.022, 1, tile_u=2.0)
    kb.plate("MainTorsoShell", crect_2d(1.48, 0.64, (0.16, 0.16, 0.09, 0.09)), 1.08, "armor_sub", "armor_panel",
             (0, 0.39, 0.10), (0, 0, 0), 0.026, 1)
    kb.arm_bulkhead("ArmMount", 0.78, 0.30, 0.0)
    _add_back_dock(kb, "BackDock", 0.68, 0.36, w=0.72, d=0.40)
    _add_gen_dock(kb, "GenDock", 0.12, 0.66, w=0.72, h=0.28)

    # 3. Multi-Faceted Central Chest Plate + Bolted Sub-Plate + Slotted Intake + Chin Glacis (strictly y >= 0.01)
    M_ch = g2b_mat((0.0, 0.36, -0.55), (-10.0, 0.0, 0.0))
    kb.plate("ChestCenterMain", crect_2d(0.76, 0.60, (0.14, 0.14, 0.18, 0.18)), 0.14, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.022, 1, M_parent=M_ch)
    kb.plate("ChestSubPlate", crect_2d(0.48, 0.25, (0.06, 0.06, 0.09, 0.09)), 0.060, "armor_sub", "armor_hatch",
             (0, -0.11, -0.075), (0, 0, 0), 0.010, 1, M_parent=M_ch)
    kb.louver_bay("ChestIntake", 0.34, 0.12, 0.036, (0, -0.14, -0.108), (0, 0, 0), blades=3, mesh_style=False, M_parent=M_ch)
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
        kb.era_block(f"WingERA_T_{si}", (0.22, 0.155, 0.052), "armor_sub", (0, 0.09, -0.068), (0, 0, 0), M_parent=M_wg)
        kb.era_block(f"WingERA_B_{si}", (0.22, 0.155, 0.052), "armor_sub", (0, -0.10, -0.068), (0, 0, 0), M_parent=M_wg)
        kb.box(f"WingAccent_{si}", (0.052, 0.38, 0.125), "accent", "plain_metal",
               (sx * 0.18, 0.0, 0.0), (0, 0, 0), 0.005, 1, M_parent=M_wg)
        # Raised canted shoulder armor cowl with accent stripe + maintenance grab rail
        M_sh = g2b_mat((sx * 0.70, 0.72, 0.02), (0.0, 0.0, -sx * 14.0))
        kb.plate(f"ShoulderCowl_{si}", trap_2d(0.62, 0.42, 0.21, 0.045), 0.88, "armor", "armor_hatch",
                 (0, 0, 0), (0, 90, 0), 0.020, 1, M_parent=M_sh)
        kb.box(f"ShoulderStripe_{si}", (0.058, 0.22, 0.90), "accent", "plain_metal",
               (0, 0.0, 0), (0, 0, 0), 0.004, 1, M_parent=M_sh)
        kb.grab_rail(f"ShoulderGrab_{si}", 0.22, 0.040, (0, 0.115, -0.22), (-90, 0, 0), 0.010, M_parent=M_sh)
        # Side exhaust louver bay + lower caged headlights + tow shackles + copper/braided pipes
        kb.louver_bay(f"SideVent_{si}", 0.38, 0.23, 0.050, (sx * 0.77, 0.29, 0.28), (0, sx * 90.0, 0),
                      blades=5, mesh_style=(si == 1))
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.28, 0.085, -0.61), (0, sx * -8.0, 0))
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.43, 0.06, -0.56), scale=0.95)
        kb.tube_path(f"FlankLine_{si}",
                     [(sx * 0.72, 0.18, 0.16), (sx * 0.74, 0.12, 0.42), (sx * 0.48, 0.12, 0.60)],
                     0.013, 8, "copper" if si == 0 else "gunmetal", "plain_metal" if si == 0 else "braid_hose")

    # 5. Signature Right-Offset Tri-Optic Composite Sensor Head + Left Hatch + Dorsal Radiator + Whip Antenna
    M_hd = g2b_mat((0.22, 0.86, -0.26), (0.0, 0.0, 0.0))
    kb.cyl("HeadNeck", 0.155, 0.175, 0.12, 14, "dark", "gear_collar", (0, -0.14, 0.04), (0, 0, 0), 0.005, M_parent=M_hd)
    kb.bolt_ring("HeadNeckBolts", 0.16, 8, 0.008, (0, -0.10, 0.04), (0, 0, 0), M_parent=M_hd)
    kb.plate("HeadArmor", crect_2d(0.46, 0.31, (0.10, 0.04, 0.02, 0.08)), 0.52, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.020, 1, M_parent=M_hd)
    kb.box("HeadBrow", (0.48, 0.032, 0.145), "gunmetal", "bolt_flange", (0, 0.125, -0.23), (8, 0, 0), 0.005, 1, M_parent=M_hd)
    kb.plate("HeadChin", trap_2d(0.42, 0.32, 0.12, 0.02), 0.10, "armor_sub", "armor_ribs",
             (0, -0.02, -0.27), (-28, 0, 0), 0.012, 1, M_parent=M_hd)
    kb.box("HeadVisorRecess", (0.36, 0.056, 0.022), "bore", "plain_metal", (0, 0.072, -0.256), (0, 0, 0), 0.003, 1, M_parent=M_hd)
    kb.box("HeadVisorGlass", (0.34, 0.044, 0.018), "glass", "plain_metal", (0, 0.072, -0.266), (0, 0, 0), 0.003, 1, M_parent=M_hd)
    kb.cyl("HeadTrunnion", 0.062, 0.062, 0.54, 12, "gunmetal", "gear_collar", (0, 0.0, 0.04), (0, 0, 90), 0.004, M_parent=M_hd)
    for oi, (ox, orad) in enumerate([(-0.11, 0.024), (0.0, 0.036), (0.11, 0.024)]):
        _add_optic_lens(kb, f"TriOptic_{oi}", orad, (ox, -0.065, -0.268), (90, 0, 0),
                        "emit_amber" if oi != 1 else "emit_cyan", M_parent=M_hd)

    # Left roof circular hatch + forward periscope + dorsal radiator + whip antenna + exhausts
    kb.cupola_hatch("LeftCmdHatch", (-0.24, 0.72, -0.10))
    _add_periscope(kb, "LeftFrontPeri", 0.14, 0.068, (-0.24, 0.78, -0.28), (0, 0, 0), "glass")
    kb.louver_bay("DorsalVent", 0.64, 0.26, 0.052, (0, 0.72, 0.26), (-90, 0, 0), blades=6, mesh_style=False)
    _add_whip_antenna(kb, "CommWhip", (-0.52, 0.74, 0.44), h=0.96, tilt_x=-5.0)
    kb.stowage_rack("RightRearStow", (0.76, 0.48, 0.34), (0, 90, 0))
    for si, sx in enumerate([-1.0, 1.0]):
        _add_exhaust_stack(kb, f"Exh_{si}", (sx * 0.46, 0.72, 0.56), (14, 0, 0), 0.20)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-0.78, 0.30, 0.0))
    kb.add_marker("SOCKET_arm_r", (0.78, 0.30, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  0.68, 0.36))
    kb.add_marker("SOCKET_gen",   (0.0,  0.12, 0.66))


# ==============================================================================
# 9. core_t90m_proryv — PRV-90 T-90M Proryv Relikt Wedge & Slat-Cage Core
# ==============================================================================

def build_core_t90m_proryv(kb: KitbashScene):
    """PRV-90 T-90M Proryv Core: low octagonal saucer turret, 6x Relikt clamshell wedges, Shtora ruby eyes, slat cages."""
    # 1. Unified HP-C1 Waist Collar + Dual Hydraulics + Collar Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.20)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.20, r=0.41, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.34), (sx * 0.34, 0.34, -0.48), 0.023)

    # 2. Recessed CNC Inner Chassis + Symmetrical HP-A1 Bulkheads + Rear Docks
    kb.box("InnerHull", (1.54, 0.94, 1.40), "dark", "frame_cnc", (0, 0.71, 0.06), (0, 0, 0), 0.024, 1, tile_u=2.0)
    kb.box("MainArmoredHull", (1.58, 0.90, 1.36), "armor", "armor_panel", (0, 0.72, 0.06), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.10, 0.76, 0.02)
    _add_back_dock(kb, "BackDock", 1.44, 0.52, w=0.84, d=0.52)
    _add_gen_dock(kb, "GenDock", 0.66, 0.94, w=0.90, h=0.68)

    # 3. Signature Low-Profile Russian Octagonal Welded "Flying Saucer" Turret + 6 Clamshell Relikt ERA Wedges
    kb.plate("SaucerTurret", crect_2d(1.74, 1.36, (0.34, 0.34, 0.26, 0.26)), 0.34, "armor", "armor_panel",
             (0, 1.04, -0.04), (90, 0, 0), 0.026, 1)
    wedge_arc = [
        (0.24, -0.82, 16.0),
        (0.49, -0.66, 33.0),
        (0.74, -0.50, 50.0),
    ]
    for si, sx in enumerate([-1.0, 1.0]):
        for wi, (wx, wz, wyaw) in enumerate(wedge_arc):
            M_rw = g2b_mat((sx * wx, 1.04, wz), (0.0, -sx * wyaw, 0.0))
            kb.plate(f"ReliktTop_{si}_{wi}", trap_2d(0.25, 0.21, 0.23, 0.02), 0.090, "armor_sub", "armor_hatch",
                     (0, 0.072, -0.022), (-34, 0, 0), 0.012, 1, M_parent=M_rw)
            kb.plate(f"ReliktBot_{si}_{wi}", trap_2d(0.25, 0.21, 0.21, 0.02), 0.090, "armor", "armor_panel",
                     (0, -0.072, -0.022), (34, 0, 0), 0.012, 1, M_parent=M_rw)
            kb.box(f"ReliktCore_{si}_{wi}", (0.24, 0.22, 0.10), "dark", "frame_cnc",
                   (0, 0, 0.052), (0, 0, 0), 0.008, 1, M_parent=M_rw)
        # Signature Twin Ruby-Red Shtora-1 Electro-Optical Dazzler "Eyes"
        M_sh = g2b_mat((sx * 0.34, 1.08, -0.82), (0.0, -sx * 8.0, 0.0))
        kb.box(f"ShtoraBox_{si}", (0.21, 0.19, 0.165), "dark", "frame_cnc", (0, 0, 0), (0, 0, 0), 0.010, 1, M_parent=M_sh)
        _add_optic_lens(kb, f"ShtoraEye_{si}", 0.062, (0, 0, -0.084), (90, 0, 0), "emit_red", M_parent=M_sh)
        kb.box(f"ShtoraHood_{si}", (0.22, 0.022, 0.12), "gunmetal", "bolt_flange", (0, 0.10, -0.05), (8, 0, 0), 0.004, 1, M_parent=M_sh)

    # 4. Sloped Relikt Bow Glacis (3 Heavy Bow ERA Blocks + Wave Breaker + Driver Periscope)
    M_gl = g2b_mat((0.0, 0.56, -0.74), (58.0, 0.0, 0.0))
    kb.plate("ReliktGlacis", trap_2d(1.48, 1.28, 0.58, 0.075), 0.13, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.020, 1, M_parent=M_gl)
    kb.box("SplashVane", (1.20, 0.048, 0.062), "gunmetal", "armor_ribs",
           (0, 0.125, -0.082), (0, 0, 0), 0.006, 1, M_parent=M_gl)
    for bi, bx in enumerate([-0.36, 0.0, 0.36]):
        kb.era_block(f"BowRelikt_{bi}", (0.31, 0.25, 0.048), "armor_sub" if bi == 1 else "armor",
                     (bx, -0.065, -0.085), (0, 0, 0), M_parent=M_gl)
    kb.box("DriverBlister", (0.32, 0.14, 0.22), "armor_sub", "armor_hatch", (0, 0.72, -0.68), (0, 0, 0), 0.012, 1)
    _add_periscope(kb, "DriverPeri", 0.24, 0.072, (0, 0.75, -0.78), (6, 0, 0), "glass")
    kb.box("BowHazard", (0.28, 0.022, 0.050), "hazard", "hazard", (0, 0.34, -0.88), (30, 0, 0), 0.003, 1)

    # 5. Flank ERA Side-Skirts + Rear Anti-HEAT Steel Slat-Armor Cages + Smoke Pods + Headlights
    for si, sx in enumerate([-1.0, 1.0]):
        rot_y = 90.0 if sx < 0 else -90.0
        kb.plate(f"SideSkirtBack_{si}", crect_2d(0.82, 0.28, (0.04, 0.04, 0.04, 0.04)), 0.050, "armor_sub", "armor_ribs",
                 (sx * 1.00, 0.48, -0.22), (0, 90, 0), 0.010, 1)
        for ei, ez in enumerate([-0.40, -0.04]):
            kb.era_block(f"SideERA_{si}_{ei}", (0.34, 0.22, 0.044), "armor" if ei % 2 == 0 else "armor_sub",
                         (sx * 1.04, 0.48, ez), (0, rot_y, 0))
        # Signature rear flank anti-HEAT slat cage welded via standoffs
        _add_slat_cage(kb, f"SlatCage_{si}", sx * 1.05, 0.62, 0.20, 0.68, 0.48, n_bars=4)
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.60, 0.56, -0.84), (0, sx * -10.0, 0))
        kb.tow_shackle(f"BowShackle_{si}", (sx * 0.40, 0.30, -0.86), scale=1.10)
        kb.smoke_pod(f"SmokePod_{si}", (sx * 0.74, 1.18, -0.24), (-22, sx * -24.0, 0))
        kb.tube_path(f"SideFuelPipe_{si}",
                     [(sx * 0.80, 0.84, 0.16), (sx * 0.86, 0.72, 0.44), (sx * 0.66, 0.64, 0.72)],
                     0.014, 8, "copper" if si == 0 else "gunmetal", "plain_metal" if si == 0 else "braid_hose")

    # 6. Roof: Left Panoramic PK PAN CITV, Right Commander Cupola, Bustle Radiator & Whip Antenna
    _add_citv_sight(kb, "PKPAN_CITV", (-0.42, 1.21, -0.38), head_slot="armor_sub", lens_slot="emit_cyan")
    kb.cupola_hatch("CmdCupola_R", (0.44, 1.21, -0.34))
    kb.louver_bay("TopRadiator", 0.62, 0.24, 0.052, (0, 1.21, 0.12), (-90, 0, 0), blades=5, mesh_style=False)
    for si, sx in enumerate([-1.0, 1.0]):
        _add_exhaust_stack(kb, f"Exh_{si}", (sx * 0.54, 1.24, 0.64), (14, 0, 0), 0.22)
    _add_whip_antenna(kb, "CommWhip", (-0.68, 1.21, 0.16), h=0.94, tilt_x=-8.0)

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-1.10, 0.76, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.10, 0.76, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.44, 0.52))
    kb.add_marker("SOCKET_gen",   (0.0,  0.66, 0.94))


# ==============================================================================
# 10. core_trieste_bathy — DSV-11K Trieste Abyssal Forged Bathysphere Core
# ==============================================================================

def build_core_trieste_bathy(kb: KitbashScene):
    """DSV-11K Trieste Abyssal Core: 16-facet maraging pressure hull, 16-bolt flange, conical viewport, 4x floodlights."""
    # 1. Unified HP-C1 Waist Collar + Dual Hydraulics + Structural Gussets
    kb.waist_collar_core("HP_C1_Core", y_top=0.22)
    _add_waist_gussets(kb, "WaistGuss", y_collar=0.22, r=0.42, n=6)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.22, 0.04, -0.34), (sx * 0.34, 0.36, -0.50), 0.024)

    # 2. Recessed CNC Inner Cradle + Symmetrical HP-A1 Bulkheads + Rear Docks
    kb.box("InnerHullCradle", (1.52, 1.00, 1.42), "dark", "frame_cnc", (0, 0.76, 0.06), (0, 0, 0), 0.026, 1, tile_u=2.0)
    kb.box("MainBallastHull", (1.56, 0.96, 1.34), "armor", "armor_panel", (0, 0.77, 0.08), (0, 0, 0), 0.028, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 1.12, 0.80, 0.02)
    _add_back_dock(kb, "BackDock", 1.52, 0.54, w=0.86, d=0.52)
    _add_gen_dock(kb, "GenDock", 0.70, 0.94, w=0.92, h=0.70)

    # 3. Signature 16-Facet Forged Maraging-Steel Bathysphere Pressure Hull + 16-Bolt Central Mating Flange
    kb.lathe("PressureSphereHull",
             [(0.48, -0.58), (0.58, -0.44), (0.59, -0.10), (0.59, 0.10), (0.58, 0.44), (0.48, 0.58)],
             16, "armor", "armor_panel", (0, 0.84, -0.22), (90, 0, 0))
    kb.cyl("CentralMatingFlange", 0.645, 0.645, 0.125, 16, "gunmetal", "gear_collar",
           (0, 0.84, -0.26), (90, 0, 0), 0.008)
    kb.bolt_ring("MainFlangeBolts", 0.610, 16, 0.015, (0, 0.84, -0.326), (90, 0, 0))
    kb.cyl("RearRibRing", 0.615, 0.615, 0.068, 16, "dark", "bolt_flange",
           (0, 0.84, 0.14), (90, 0, 0), 0.006)

    # 4. Ultra-Thick Frusto-Conical Abyssal Acrylic Viewport + 12-Bolt Pressure Ring + Cross-Bar Guard
    M_vp = g2b_mat((0.0, 0.84, -0.80), (0.0, 0.0, 0.0))
    kb.cyl("ViewportCone", 0.28, 0.46, 0.22, 16, "dark", "gear_collar",
           (0, 0, -0.06), (90, 0, 0), 0.008, M_parent=M_vp)
    kb.bolt_ring("ViewportBolts", 0.36, 12, 0.014, (0, 0, -0.08), (90, 0, 0), M_parent=M_vp)
    kb.cyl("ViewportBezel", 0.225, 0.240, 0.072, 16, "gunmetal", "bolt_flange",
           (0, 0, -0.165), (90, 0, 0), 0.005, hollow_r=0.162, M_parent=M_vp)
    kb.cyl("ViewportBore", 0.162, 0.162, 0.020, 14, "bore", "plain_metal",
           (0, 0, -0.155), (90, 0, 0), 0.002, M_parent=M_vp)
    kb.cyl("ViewportAcrylic", 0.148, 0.156, 0.032, 16, "glass", "plain_metal",
           (0, 0, -0.175), (90, 0, 0), 0.005, M_parent=M_vp)
    kb.cyl("ViewportGlowCore", 0.095, 0.095, 0.014, 14, "emit_cyan", "plain_metal",
           (0, 0, -0.168), (90, 0, 0), 0.002, M_parent=M_vp)
    # Heavy welded steel cross-bar pressure guard protecting acrylic cone
    kb.box("ViewportBarH", (0.37, 0.028, 0.032), "gunmetal", "plain_metal", (0, 0, -0.205), (0, 0, 0), 0.004, 1, M_parent=M_vp)
    kb.box("ViewportBarV", (0.028, 0.37, 0.032), "gunmetal", "plain_metal", (0, 0, -0.205), (0, 0, 0), 0.004, 1, M_parent=M_vp)
    kb.box("DepthHazard", (0.28, 0.036, 0.020), "hazard", "hazard", (0, -0.40, 0.02), (0, 0, 0), 0.003, 1, M_parent=M_vp)

    # 5. Quad Deep-Sea Pressure-Rated Floodlights (2x2 Matrix around Viewport)
    for fi, (fx, fy) in enumerate([(-0.46, 0.54), (-0.46, 1.14), (0.46, 0.54), (0.46, 1.14)]):
        kb.cyl(f"FloodCan_{fi}", 0.075, 0.086, 0.19, 14, "gunmetal", "gear_collar",
               (fx, fy, -0.74), (90, 0, 0), 0.005)
        kb.box(f"FloodBrk_{fi}", (0.048, 0.064, 0.12), "dark", "frame_cnc",
               (fx * 0.88, fy, -0.68), (0, 0, 0), 0.005, 1)
        _add_optic_lens(kb, f"FloodLens_{fi}", 0.056, (fx, fy, -0.838), (90, 0, 0), "emit_headlight")

    # 6. Twin Side Syntactic-Foam Solid Buoyancy Armor Blocks + Drop-Weight Ballast Cylinders + Copper Pressure Lines
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"BuoyancyFoam_{si}", (1.16, 0.54, 0.22), "armor_sub", "armor_pocket",
                              (sx * 0.90, 0.92, 0.02), (0, sx * 90.0, 0), standoffs=False, bolts=True)
        kb.box(f"BuoyancyStripe_{si}", (0.26, 0.11, 0.98), "accent", "plain_metal",
               (sx * 0.92, 1.06, 0.02), (0, 0, 0), 0.006, 1)
        # Drop-weight vertical ballast cylinder + copper high-pressure hydraulic ballast pipe with brass hex fittings
        kb.cyl(f"BallastCyl_{si}", 0.13, 0.095, 0.36, 14, "dark", "armor_ribs",
               (sx * 0.88, 0.46, -0.22), (0, 0, 0), 0.008)
        kb.cyl(f"BallastFitA_{si}", 0.032, 0.032, 0.042, 6, "brass", "gear_collar",
               (sx * 0.88, 0.65, -0.22), (0, 0, 0), 0.003)
        kb.tube_path(f"BallastPipe_{si}",
                     [(sx * 0.88, 0.66, -0.22), (sx * 0.90, 0.77, -0.14), (sx * 0.72, 0.82, -0.06)],
                     0.022, 8, "copper", "plain_metal", add_clamps=True)
        kb.tube_path(f"RearTrimHose_{si}",
                     [(sx * 0.86, 0.54, 0.12), (sx * 0.88, 0.50, 0.44), (sx * 0.64, 0.56, 0.72)],
                     0.014, 8, "gunmetal", "braid_hose", add_clamps=True)
        kb.tow_shackle(f"RecoveryEye_{si}", (sx * 0.38, 0.28, -0.78), scale=1.15)
        kb.grab_rail(f"DiverGrab_{si}", 0.28, 0.044, (sx * 0.98, 0.72, 0.28), (0, sx * 90.0, 0), 0.012)

    # 7. Roof Left Bolted Submarine Conning Hatch + Right Brass Sonar Acoustic Transducer + Wet-Bay Louver
    kb.cupola_hatch("ConningHatch_L", (-0.42, 1.29, -0.28))
    M_sn = g2b_mat((0.42, 1.29, -0.28), (0.0, 0.0, 0.0))
    kb.cyl("SonarTrans_Body", 0.14, 0.165, 0.24, 14, "brass", "gear_collar", (0, 0.10, 0), (0, 0, 0), 0.006, M_parent=M_sn)
    kb.cyl("SonarTrans_Cap", 0.16, 0.16, 0.065, 14, "dark", "bolt_flange", (0, 0.23, 0), (0, 0, 0), 0.005, M_parent=M_sn)
    kb.bolt_ring("SonarTrans_Bolts", 0.145, 8, 0.009, (0, 0.266, 0), (0, 0, 0), M_parent=M_sn)
    kb.louver_bay("WetBayVent", 0.58, 0.24, 0.052, (0, 1.29, 0.16), (-90, 0, 0), blades=5, mesh_style=True)
    _add_whip_antenna(kb, "HydroBeacon", (0.64, 1.28, 0.20), h=0.86, tilt_x=-5.0)
    kb.stowage_rack("DiveGearRack", (-0.64, 1.28, 0.28), (0, -90, 0))

    # Exact manifest.json Socket Markers
    kb.add_marker("SOCKET_arm_l", (-1.12, 0.80, 0.02))
    kb.add_marker("SOCKET_arm_r", (1.12, 0.80, 0.02))
    kb.add_marker("SOCKET_back",  (0.0,  1.52, 0.54))
    kb.add_marker("SOCKET_gen",   (0.0,  0.70, 0.94))
