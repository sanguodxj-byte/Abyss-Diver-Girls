"""Sculpted Non-Boxy Military Mecha Cores v2.2 — Air-Defense, EW & Siege Engineer Group (5 Distinct Silhouettes, Zero-Clip).

Every single core has a radically unmistakable silhouette from Top-Down, Front 3/4, and Rear 3/4:
  1. core_pantsir_s1    — 96K6-M 2-Tier Stepped AA Turret Tower + Cantilevered Twin AA Launcher Wing Pods
  2. core_patriot_mpq65 — MPQ-65 Front-Tall Backward-Sloping 28deg Phased-Array Radar Monolith Prism
  3. core_krasukha_ew   — 1RL257 Narrow-Waisted 2-Tier Overhanging Faraday EMI Hood + Elevated Heat-Sink Nacelles
  4. core_pionier_dach  — PIO-2A Asymmetric Split-Deck Engineer Hull (Recessed Left Crane Channel + 35t Winch + Dozer)
  5. core_abv_shredder  — M1150-B Ultra-Wide Low Abrams Breacher Arrowhead + Full-Width 10-Tine V-Comb Mine Plow

All modules comply with MECH_MODELING_STANDARD v1.0 & v1.5 Zero-Clip:
  - Unified HP-C1 slewing collar (r=0.360m, y_bot=0.000m)
  - Symmetrical HP-A1 geared shoulder bulkheads & exact SOCKET_* markers
  - Analytical surface-frame mounting -> 0/0/0/0 clip_audit & 0 cross-module clashes
"""
import math
from mathutils import Vector, Matrix
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d
from builders.sculpted_cores_v2 import (
    _oct_ring,
    _face_frame,
    _quad_frame,
    _add_periscope,
    _add_arm_trunnion_bridge,
    _add_dorsal_back_pad,
    _add_rear_gen_pad,
    _add_whip_antenna,
)
from builders.sculpted_cores_v2_tactical import (
    _oct_2d,
    _add_optic_lens,
    _add_citv_sight,
)


def _asym_ring(xl_bot: float, xr_bot: float, xl_mid: float, xr_mid: float,
               xl_top: float, xr_top: float,
               y_bot: float, yl_mid_lo: float, yr_mid_lo: float,
               yl_mid_hi: float, yr_mid_hi: float, yl_top: float, yr_top: float):
    """8-point asymmetric polygonal cross-section in Godot (gx, gy) for split-deck engineer hulls."""
    return [
        (xl_bot, y_bot),
        (xr_bot, y_bot),
        (xr_mid, yr_mid_lo),
        (xr_mid, yr_mid_hi),
        (xr_top, yr_top),
        (xl_top, yl_top),
        (xl_mid, yl_mid_hi),
        (xl_mid, yl_mid_lo),
    ]


# ==============================================================================
# 1. core_pantsir_s1 — 96K6-M 2-Tier Stepped AA Turret Tower + Flanking Pods
# ==============================================================================

def build_core_pantsir_s1(kb: KitbashScene):
    """96K6-M Pantsir-S1 Core: low base deck + narrow stepped central AA radar turret tower + cantilevered wing pods."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.25)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"PantStab_{si}", (sx * 0.29, 0.05, -0.20), (sx * 0.42, 0.26, -0.34), 0.020)

    # 1. Lower Tier: Sleek Low Wide AA Turret Ring Base Deck (y = 0.24..0.72)
    base_secs = [
        (-1.08, _oct_ring(0.70, 0.94, 0.76, 0.34, 0.42, 0.56, 0.64)),   # Armored chin radiator prow
        (-0.54, _oct_ring(1.24, 1.66, 1.38, 0.24, 0.38, 0.62, 0.72)),   # Low armored turret base deck
        ( 0.16, _oct_ring(1.30, 1.72, 1.44, 0.24, 0.38, 0.64, 0.74)),   # Main AA ring deck
        ( 0.64, _oct_ring(1.06, 1.36, 1.16, 0.26, 0.40, 0.64, 0.74)),   # Tapered rear bustle base
        ( 0.88, _oct_ring(0.84, 1.06, 0.90, 0.30, 0.42, 0.62, 0.70)),   # Rear transom (<= 0.89)
    ]
    kb.loft("PantsirBaseDeck", base_secs, "armor_sub", "armor_slab", bevel_w=0.015, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # 2. Upper Tier: Narrow Stepped Central AA Radar Turret Tower (distinct tower silhouette!)
    tower_secs = [
        (-0.84, _oct_ring(0.68, 0.82, 0.64, 0.66, 0.74, 1.04, 1.16)),   # Steep front radar turret face
        (-0.44, _oct_ring(0.92, 1.06, 0.84, 0.68, 0.78, 1.12, 1.24)),   # Central narrow AA fire-control tower
        ( 0.08, _oct_ring(0.94, 1.08, 0.86, 0.68, 0.78, 1.12, 1.24)),   # Main radar tower body
        ( 0.46, _oct_ring(0.84, 0.96, 0.78, 0.68, 0.76, 0.96, 1.04)),   # Stepped-down rear bustle shelf for HP-B1!
        ( 0.76, _oct_ring(0.76, 0.86, 0.72, 0.68, 0.76, 0.94, 1.02)),   # Rear bustle dock deck
    ]
    kb.loft("PantsirRadarTower", tower_secs, "armor", "armor_slab", bevel_w=0.014, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Symmetrical HP-A1 Trunnions at (±1.06, 0.56, 0.02)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.84, 1.06, 0.56, 0.02)

    # 3. Giant 18deg Canted Octagonal 1RS2-1E Millimeter-Wave Fire-Control Radar Mounted Proud on Central Tower Nose!
    M_1rs = g2b_mat((0.0, 0.96, -0.90), (16.0, 0.0, 0.0))
    kb.box("Radar1RS2_Ped", (0.50, 0.44, 0.20), "dark", "frame_cnc", (0, 0.0, 0.12), (0, 0, 0), 0.010, 1, M_parent=M_1rs)
    kb.plate("Radar1RS2_Frame", _oct_2d(0.41), 0.092, "dark", "frame_cnc", (0, 0, 0), (0, 0, 0), 0.012, 1, M_parent=M_1rs)
    kb.plate("Radar1RS2_Dish", _oct_2d(0.345), 0.036, "armor", "armor_pocket", (0, 0, -0.052), (0, 0, 0), 0.006, 1, M_parent=M_1rs)
    for wi in range(5):
        wy = -0.16 + wi * 0.08
        kb.box(f"Radar1RS2_Rib_{wi}", (0.50, 0.016, 0.016), "gunmetal", "armor_ribs",
               (0, wy, -0.074), (0, 0, 0), 0.002, 1, M_parent=M_1rs)
    kb.bolt_ring("Radar1RS2_Bolts", 0.365, 10, 0.008, (0, 0, -0.054), (90, 0, 0), M_parent=M_1rs)
    kb.box("Radar1RS2_Brow", (0.44, 0.030, 0.12), "armor_sub", "bolt_flange",
           (0, 0.395, -0.042), (8, 0, 0), 0.005, 1, M_parent=M_1rs)
    kb.box("Radar1RS2_Haz", (0.28, 0.030, 0.014), "hazard", "hazard",
           (0, -0.38, -0.054), (0, 0, 0), 0.002, 1, M_parent=M_1rs)

    # Lower Armored Chin Radiator Bulkhead (Twin Louvers + Headlights + Tow Shackles)
    kb.plate("ChinRadShield", crect_2d(0.86, 0.22, (0.04, 0.04, 0.04, 0.04)), 0.064, "armor", "armor_ribs",
             (0, 0.49, -1.10), (0, 0, 0), 0.008, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.louver_bay(f"ChinVent_{si}", 0.32, 0.15, 0.032, (sx * 0.22, 0.49, -1.152), (0, 0, 0), blades=4, mesh_style=False)
        kb.headlight_cage(f"PantLight_{si}", (sx * 0.46, 0.56, -1.04), (0, sx * -18.0, 0))
        kb.tow_shackle(f"PantTow_{si}", (sx * 0.26, 0.35, -1.14), (0, 0, 90), 0.96)

    # 4. Iconic Cantilevered Twin Outboard AA Missile-Bus Wing Pods Flanking the Central Tower (strictly |x| <= 0.92!)
    for si, sx in enumerate([-1.0, 1.0]):
        # Heavy lateral support pylon bridging central tower out to AA wing pod
        kb.box(f"AAPodPylon_{si}", (0.26, 0.22, 0.34), "dark", "frame_cnc",
               (sx * 0.58, 0.88, -0.10), (0, 0, 0), 0.010, 1)
        M_pod = g2b_mat((sx * 0.74, 0.94, -0.10), (14.0, 0.0, 0.0))
        kb.plate(f"AAPodHousing_{si}", crect_2d(0.24, 0.32, (0.04, 0.04, 0.04, 0.04)), 0.64,
                 "armor_sub" if si == 1 else "armor_oxide", "armor_pocket",
                 (0, 0, 0), (0, 0, 0), 0.010, 1, M_parent=M_pod)
        for ti, ty in enumerate([-0.08, 0.08]):
            kb.cyl(f"AARackTube_{si}_{ti}", 0.046, 0.048, 0.72, 12, "dark", "armor_ribs",
                   (sx * 0.06, ty, -0.02), (90, 0, 0), 0.004, hollow_r=0.034, M_parent=M_pod)
            kb.cyl(f"AARackRim_{si}_{ti}", 0.052, 0.052, 0.024, 12, "brass", "gear_collar",
                   (sx * 0.06, ty, -0.375), (90, 0, 0), 0.002, hollow_r=0.038, M_parent=M_pod)
        # Curved copper RF waveguide feeding central tower
        kb.tube_path(f"RFCopper_{si}",
                     [(sx * 0.50, 0.84, -0.38), (sx * 0.66, 0.78, 0.08), (sx * 0.54, 0.76, 0.38)],
                     0.018, 8, "copper", "plain_metal", add_clamps=True)
        _add_whip_antenna(kb, f"PantWhip_{si}", (sx * 0.36, 1.22, -0.02), h=0.76, tilt_x=-7.0)

    # 5. Tower Roof Left 10ES1 EO/IR Pillar + Tower Roof Right 2RL80 Acquisition Radar Bar (high & proud!)
    M_eo = g2b_mat((-0.24, 1.255, -0.30), (0.0, 0.0, 0.0))
    kb.cyl("Optic10ES1_Ped", 0.115, 0.138, 0.14, 14, "dark", "gear_collar", (0, 0.065, 0), (0, 0, 0), 0.005, M_parent=M_eo)
    kb.plate("Optic10ES1_Head", crect_2d(0.24, 0.20, (0.03, 0.03, 0.03, 0.03)), 0.22, "armor", "armor_pocket",
             (0, 0.22, 0), (0, 0, 0), 0.010, 1, M_parent=M_eo)
    _add_optic_lens(kb, "Optic10ES1_Main", 0.054, (0, 0.22, -0.115), (90, 0, 0), "emit_cyan", M_parent=M_eo)
    kb.box("Optic10ES1_Hood", (0.26, 0.022, 0.13), "gunmetal", "bolt_flange", (0, 0.33, -0.04), (6, 0, 0), 0.004, 1, M_parent=M_eo)

    M_sr = g2b_mat((0.24, 1.23, -0.26), (0.0, -18.0, 0.0))
    kb.cyl("Search2RL80_Ped", 0.108, 0.132, 0.14, 14, "gunmetal", "gear_collar", (0, 0.065, 0), (0, 0, 0), 0.005, M_parent=M_sr)
    kb.plate("Search2RL80_Bar", crect_2d(0.46, 0.21, (0.04, 0.04, 0.04, 0.04)), 0.105, "armor_sub", "armor_panel",
             (0, 0.215, 0), (10, 0, 0), 0.010, 1, M_parent=M_sr)
    kb.plate("Search2RL80_Face", crect_2d(0.38, 0.15, (0.02, 0.02, 0.02, 0.02)), 0.026, "accent", "armor_ribs",
             (0, 0.215, -0.062), (10, 0, 0), 0.004, 1, M_parent=M_sr)
    for ii, ix in enumerate([-0.14, 0.14]):
        kb.cyl(f"Search2RL80_Post_{ii}", 0.010, 0.012, 0.055, 8, "brass", "plain_metal",
               (ix, 0.33, -0.012), (0, 0, 0), 0.001, M_parent=M_sr)
    kb.cyl("Search2RL80_IFF", 0.012, 0.012, 0.40, 8, "brass", "plain_metal", (0, 0.355, -0.012), (0, 0, 90), 0.002, M_parent=M_sr)

    # 6. Flush HP-B1 Stepped Rear Bustle Pad & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 1.06, 0.56, w=0.72, d=0.40)
    _add_rear_gen_pad(kb, "HP_G1", 0.52, 0.90, w=0.72, h=0.42)

    kb.add_marker("SOCKET_arm_l", (-1.06, 0.56, 0.02))
    kb.add_marker("SOCKET_arm_r", ( 1.06, 0.56, 0.02))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.06, 0.56))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.52, 0.90))
    kb.seat_core_low(0.14, new_y_top=0.12)


# ==============================================================================
# 2. core_patriot_mpq65 — MPQ-65 Front-Tall Backward-Sloping Radar Monolith Prism
# ==============================================================================

def build_core_patriot_mpq65(kb: KitbashScene):
    """MPQ-65 Patriot Core: tall 28deg raked phased-array monolith crest sloping down to low rear cooler deck."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.25)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"PatStab_{si}", (sx * 0.29, 0.05, -0.22), (sx * 0.42, 0.28, -0.36), 0.022)

    # 1. Monumental Front-Tall Backward-Sloping Radar Prism Loft (high 1.44m front radar crest -> low 0.96m rear deck!)
    pat_secs = [
        (-1.14, _oct_ring(0.92, 1.18, 1.00, 0.34, 0.42, 0.52, 0.58)),   # Wide radar lower lip
        (-0.52, _oct_ring(1.24, 1.66, 1.32, 0.24, 0.40, 1.18, 1.44)),   # HUGE 28deg towering radar monolith crest!
        ( 0.06, _oct_ring(1.28, 1.70, 1.24, 0.24, 0.40, 1.04, 1.24)),   # Dramatic downward slope behind radar!
        ( 0.62, _oct_ring(1.08, 1.40, 1.06, 0.26, 0.42, 0.84, 0.98)),   # Low stepped rear machinery deck
        ( 0.90, _oct_ring(0.88, 1.08, 0.88, 0.30, 0.44, 0.78, 0.90)),   # Compact rear transom (<= 0.91)
    ]
    kb.loft("PatriotRadarPrism", pat_secs, "armor_sub", "armor_slab", bevel_w=0.016, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Symmetrical HP-A1 Trunnions at (±1.10, 0.62, 0.04)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.84, 1.10, 0.62, 0.04)

    # 2. Giant Towering 28deg AN/MPQ-65 Phased-Array Radar Bulkhead Dominating the Front Silhouette!
    M_mpq, mw, mh = _quad_frame(
        (-0.50, 0.58, -1.14), ( 0.50, 0.58, -1.14),
        ( 0.66, 1.44, -0.52), (-0.66, 1.44, -0.52),
        ref_inside=(0.0, 0.66, -0.25),
    )
    kb.plate("MPQ65_Slab", trap_2d(1.06, 1.36, mh * 0.94, 0.05), 0.076, "armor", "armor_slab",
             (0, 0, -0.024), (0, 0, 0), 0.012, 1, M_parent=M_mpq)
    # Giant main left-offset octagonal C-band phased-array dish + 12-bolt collar + 5 waveguide ribs
    kb.plate("MPQ65_MainBezel", _oct_2d(0.36), 0.048, "dark", "frame_cnc",
             (-0.15, 0.08, -0.072), (0, 0, 0), 0.008, 1, M_parent=M_mpq)
    kb.plate("MPQ65_MainFace", _oct_2d(0.305), 0.024, "gunmetal", "vent_mesh",
             (-0.15, 0.08, -0.098), (0, 0, 0), 0.004, 1, M_parent=M_mpq)
    kb.bolt_ring("MPQ65_MainBolts", 0.330, 12, 0.008, (-0.15, 0.08, -0.080), (90, 0, 0), M_parent=M_mpq)
    for ri in range(5):
        ry = -0.14 + ri * 0.07
        kb.box(f"MPQ65_Slot_{ri}", (0.42, 0.015, 0.015), "dark", "armor_ribs",
               (-0.15, 0.08 + ry, -0.114), (0, 0, 0), 0.002, 1, M_parent=M_mpq)
    # Upper-right TVM octagonal guidance array
    kb.plate("MPQ65_SubBezel", _oct_2d(0.165), 0.040, "dark", "frame_cnc",
             (0.36, 0.22, -0.070), (0, 0, 0), 0.006, 1, M_parent=M_mpq)
    kb.plate("MPQ65_SubFace", _oct_2d(0.130), 0.020, "armor_sub", "vent_mesh",
             (0.36, 0.22, -0.092), (0, 0, 0), 0.003, 1, M_parent=M_mpq)
    # Mid-right ECCM accent array + lower full-width IFF horizontal dipole interrogator bar
    kb.plate("MPQ65_ECCM", crect_2d(0.34, 0.12, (0.02, 0.02, 0.02, 0.02)), 0.034, "accent", "armor_pocket",
             (0.34, -0.06, -0.070), (0, 0, 0), 0.004, 1, M_parent=M_mpq)
    kb.box("MPQ65_IFFBar", (0.98, 0.092, 0.046), "armor_sub", "armor_ribs",
           (0, -0.34, -0.072), (0, 0, 0), 0.006, 1, M_parent=M_mpq)
    for di in range(6):
        dx = -0.375 + di * 0.15
        kb.box(f"MPQ65_Dip_{di}", (0.09, 0.026, 0.018), "gunmetal", "bolt_flange",
               (dx, -0.34, -0.100), (0, 0, 0), 0.002, 1, M_parent=M_mpq)
    kb.box("MPQ65_TopHood", (1.24, 0.038, 0.18), "gunmetal", "bolt_flange",
           (0, mh * 0.46, -0.088), (10, 0, 0), 0.005, 1, M_parent=M_mpq)
    kb.box("MPQ65_Hazard", (0.44, 0.036, 0.014), "hazard", "hazard", (0, 0.45, -1.148), (0, 0, 0), 0.002, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"PatLight_{si}", (sx * 0.50, 0.48, -1.16), (0, sx * -14.0, 0))
        kb.tow_shackle(f"PatTow_{si}", (sx * 0.34, 0.36, -1.19), (0, 0, 90), 1.02)

    # 3. Canted Flanks: Copper-Coiled Liquid Pump Drums + Rear Liquid-Cooled Radiator Louver Sponsons
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_fc, fcw, fch = _quad_frame(
                (0.59, 0.42, -1.14), (0.83, 0.40, -0.52),
                (0.83, 1.18, -0.52), (0.59, 0.52, -1.14),
                ref_inside=(0.0, 0.66, -0.20),
            )
            M_rb, rbw, rbh = _quad_frame(
                (0.85, 0.40, 0.06), (0.70, 0.42, 0.62),
                (0.70, 0.84, 0.62), (0.85, 1.04, 0.06),
                ref_inside=(0.0, 0.64, 0.35),
            )
        else:
            M_fc, fcw, fch = _quad_frame(
                (-0.83, 0.40, -0.52), (-0.59, 0.42, -1.14),
                (-0.59, 0.52, -1.14), (-0.83, 1.18, -0.52),
                ref_inside=(0.0, 0.66, -0.20),
            )
            M_rb, rbw, rbh = _quad_frame(
                (-0.70, 0.42, 0.62), (-0.85, 0.40, 0.06),
                (-0.85, 1.04, 0.06), (-0.70, 0.84, 0.62),
                ref_inside=(0.0, 0.64, 0.35),
            )
        kb.plate(f"PatCheekArmor_{si}", crect_2d(fcw * 0.82, fch * 0.72, (0.04, 0.04, 0.03, 0.03)), 0.044,
                 "armor_sub", "armor_panel", (0, -0.04, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_fc)
        kb.cyl(f"PumpDrum_{si}", 0.115, 0.125, 0.095, 14, "dark", "gear_collar",
               (0, -0.06, -0.056), (90, 0, 0), 0.005, M_parent=M_fc)
        kb.cyl(f"PumpCoil_{si}", 0.102, 0.102, 0.046, 14, "copper", "plain_metal",
               (0, -0.06, -0.106), (90, 0, 0), 0.004, hollow_r=0.068, M_parent=M_fc)

        kb.plate(f"LiqCoolerBox_{si}", crect_2d(rbw * 0.56, rbh * 0.72, (0.04, 0.04, 0.04, 0.04)), 0.064,
                 "armor_sub", "armor_hatch", (sx * 0.11, -0.02, -0.020), (0, 0, 0), 0.010, 1, M_parent=M_rb)
        kb.louver_bay(f"CoolerVent_{si}", rbw * 0.36, rbh * 0.44, 0.030, (sx * 0.11, -0.02, -0.062), (0, 0, 0),
                      blades=4, mesh_style=False, M_parent=M_rb)
        kb.tube_path(f"PatCoolPipe_{si}",
                     [(sx * 0.76, 1.04, -0.44), (sx * 0.87, 0.96, -0.04), (sx * 0.78, 0.86, 0.34)],
                     0.018, 8, "copper", "plain_metal", add_clamps=True)
        _add_whip_antenna(kb, f"PatWhip_{si}", (sx * 0.52, 1.24, -0.08), h=0.76, tilt_x=-8.0)

    # 4. Rear-Sloping Top Deck Behind Tall Crest: SATCOM Mast + Pedestal-Seated Cupola (clear of HP-B1!)
    kb.recon_mast("SatcomMast", (0.36, 1.28, -0.22))
    kb.cyl("PatCupolaPed", 0.22, 0.24, 0.14, 16, "dark", "gear_collar", (-0.34, 1.32, -0.30), (0, 0, 0), 0.005)
    kb.cupola_hatch("CmdCupola_L", (-0.34, 1.385, -0.30))

    # 5. Flush Low-Set Rear HP-B1 Pad & HP-G1 Dock (sits cleanly tucked behind the tall radar monolith!)
    _add_dorsal_back_pad(kb, "HP_B1", 1.06, 0.52, w=0.76, d=0.42)
    _add_rear_gen_pad(kb, "HP_G1", 0.54, 0.92, w=0.74, h=0.44)

    kb.add_marker("SOCKET_arm_l", (-1.10, 0.62, 0.04))
    kb.add_marker("SOCKET_arm_r", ( 1.10, 0.62, 0.04))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.06, 0.52))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.54, 0.92))
    kb.seat_core_low(0.14, new_y_top=0.12)


# ==============================================================================
# 3. core_krasukha_ew — 1RL257 Narrow-Waisted 2-Tier Overhanging Faraday EW Hood
# ==============================================================================

def build_core_krasukha_ew(kb: KitbashScene):
    """1RL257 Krasukha-4 EW Core: narrow lower chassis + overhanging Faraday EMI emitter brow + dish & 6-way ESM."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.24)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"EWStab_{si}", (sx * 0.28, 0.05, -0.20), (sx * 0.38, 0.26, -0.32), 0.020)

    # 1. Lower Tier: Narrow Armored EW Equipment Chassis (clean 20mm weld seat under overhanging EMI hood!)
    base_secs = [
        (-0.92, _oct_ring(0.76, 0.96, 0.88, 0.30, 0.38, 0.52, 0.58)),
        (-0.46, _oct_ring(1.06, 1.38, 1.24, 0.24, 0.36, 0.54, 0.60)),
        ( 0.16, _oct_ring(1.10, 1.44, 1.28, 0.24, 0.36, 0.54, 0.60)),
        ( 0.64, _oct_ring(0.96, 1.26, 1.10, 0.26, 0.38, 0.56, 0.64)),
        ( 0.88, _oct_ring(0.82, 1.04, 0.88, 0.30, 0.42, 0.60, 0.68)),
    ]
    kb.loft("KrasukhaLowerChassis", base_secs, "dark", "frame_cnc", bevel_w=0.014, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # 2. Upper Tier: Forward-Projecting Overhanging Faraday EMI Shelter Hood (distinctive forward cantilever!)
    hood_secs = [
        (-1.14, _oct_ring(1.12, 1.28, 1.02, 0.58, 0.66, 0.96, 1.08)),   # Forward-cantilevered EMI horn brow!
        (-0.56, _oct_ring(1.32, 1.68, 1.22, 0.58, 0.68, 1.04, 1.18)),   # Wide armored Faraday shelter crown
        ( 0.14, _oct_ring(1.26, 1.56, 1.16, 0.58, 0.70, 1.02, 1.16)),   # Tapered rear RF amp bay
        ( 0.56, _oct_ring(1.00, 1.22, 0.98, 0.62, 0.72, 0.96, 1.06)),   # Stepped rear cooling spine
        ( 0.82, _oct_ring(0.86, 1.00, 0.84, 0.66, 0.74, 0.92, 1.00)),   # Rear bulkhead
    ]
    kb.loft("KrasukhaFaradayHood", hood_secs, "armor_sub", "armor_slab", bevel_w=0.016, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Symmetrical HP-A1 Trunnions at (±1.06, 0.58, 0.02)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.72, 1.06, 0.58, 0.02)

    # 3. Corrugated Faraday Front Shield + 2x3 Flared Pyramidal Microwave Jammer Waveguide Horns!
    M_far = g2b_mat((0.0, 0.79, -1.16), (0.0, 0.0, 0.0))
    kb.plate("FaradayWall", crect_2d(1.16, 0.48, (0.05, 0.05, 0.05, 0.05)), 0.068, "armor", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.010, 1, M_parent=M_far)
    for ri, rx in enumerate([-0.50, -0.17, 0.17, 0.50]):
        kb.box(f"FaradayRib_{ri}", (0.028, 0.42, 0.026), "armor_sub", "armor_ribs",
               (rx, 0, -0.042), (0, 0, 0), 0.004, 1, M_parent=M_far)

    horn_base = [
        (-0.058, 0.040), (-0.046, 0.048), (0.046, 0.048), (0.058, 0.040),
        (0.058, -0.040), (0.046, -0.048), (-0.046, -0.048), (-0.058, -0.040),
    ]
    horn_mouth = [(px * 1.58, py * 1.48) for (px, py) in horn_base]
    horn_sections = [(0.01, horn_base), (-0.12, horn_mouth)]
    for ri, ry in enumerate([-0.105, 0.105]):
        for ci, cx in enumerate([-0.34, 0.0, 0.34]):
            kb.loft(f"WaveguideHorn_{ri}_{ci}", horn_sections, "gunmetal", "bolt_flange",
                    (cx, ry, -0.040), (0, 0, 0), 0.005, 1, flat_shade=True, M_parent=M_far)
            kb.box(f"WaveguideCopper_{ri}_{ci}", (0.132, 0.096, 0.020), "copper", "plain_metal",
                   (cx, ry, -0.134), (0, 0, 0), 0.003, 1, M_parent=M_far)
            kb.box(f"WaveguideBore_{ri}_{ci}", (0.110, 0.076, 0.018), "bore", "plain_metal",
                   (cx, ry, -0.154), (0, 0, 0), 0.002, 1, M_parent=M_far)

    kb.box("EW_BrowOverhang", (1.20, 0.036, 0.16), "armor_sub", "bolt_flange", (0, 0.255, -0.065), (8, 0, 0), 0.005, 1, M_parent=M_far)
    kb.box("EW_Hazard", (0.48, 0.034, 0.014), "hazard", "hazard", (0, 0.45, -0.926), (0, 0, 0), 0.002, 1)
    _add_periscope(kb, "EW_DriverPeri", 0.26, 0.076, (0, 1.12, -1.04), (4, 0, 0), "glass")
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"EWLight_{si}", (sx * 0.44, 0.44, -0.95), (0, sx * -18.0, 0))
        kb.tow_shackle(f"EWTow_{si}", (sx * 0.28, 0.35, -0.954), (0, 0, 90), 0.96)

    # 4. Flank Copper RF Busbars + Cantilevered Rear Thermal Heat-Sink Nacelles
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"CopperBusbar_{si}", (0.068, 0.44, 0.068), "copper", "armor_ribs",
               (sx * 0.78, 0.86, -0.78), (0, sx * -26.0, 0), 0.006, 1)
        # Sculpted elevated rear-flank thermal heat-exchanger pod flanking HP-B1!
        kb.plate(f"EWThermalPod_{si}", crect_2d(0.46, 0.34, (0.05, 0.05, 0.04, 0.04)), 0.18,
                 "armor_sub", "armor_hatch", (sx * 0.70, 0.88, 0.40), (0, sx * -74.0, 0), 0.010, 1)
        kb.louver_bay(f"SideThermalBay_{si}", 0.34, 0.22, 0.030, (sx * 0.79, 0.88, 0.42),
                      (0, sx * -74.0, 0), blades=4, mesh_style=(si == 1))
        kb.tube_path(f"EWConduit_{si}",
                     [(sx * 0.64, 1.08, -0.44), (sx * 0.74, 1.02, -0.06), (sx * 0.68, 0.96, 0.28)],
                     0.015, 8, "gunmetal", "braid_hose", add_clamps=True)
        _add_whip_antenna(kb, f"EW_Whip_{si}", (sx * 0.50, 1.14, -0.02), h=0.88 if si == 0 else 0.74, tilt_x=-7.0)

    # 5. Roof EW Crown: Left 12-Faceted Krasukha Parabolic Jammer Dish + Right 6-Way ESM DF Crown
    M_dish = g2b_mat((-0.32, 1.15, -0.30), (18.0, -18.0, 0.0))
    kb.cyl("DishPedestal", 0.115, 0.140, 0.15, 14, "dark", "gear_collar", (0, 0.055, 0), (0, 0, 0), 0.005, M_parent=M_dish)
    dish_profile = [
        (0.0, -0.044), (0.14, -0.044), (0.28, 0.040),
        (0.28, 0.056), (0.248, 0.056), (0.115, -0.004), (0.0, -0.004),
    ]
    kb.lathe("DishReflector", dish_profile, 12, "armor_sub", "armor_panel",
             (0, 0.21, -0.05), (78, 0, 0), M_parent=M_dish)
    kb.cyl("DishBackplate", 0.20, 0.14, 0.040, 12, "dark", "frame_cnc",
           (0, 0.19, -0.008), (78, 0, 0), 0.004, M_parent=M_dish)
    kb.cyl("DishFeedHorn", 0.048, 0.036, 0.16, 10, "brass", "gear_collar",
           (0, 0.24, -0.15), (78, 0, 0), 0.004, M_parent=M_dish)
    kb.cyl("DishFeedTip", 0.032, 0.032, 0.018, 10, "emit_amber", "plain_metal",
           (0, 0.26, -0.235), (78, 0, 0), 0.002, M_parent=M_dish)
    for si in range(3):
        sa = math.tau * si / 3.0
        kb.tube_path(f"DishStrut_{si}", [
            (math.cos(sa) * 0.22, 0.21 + math.sin(sa) * 0.20, -0.07),
            (0.0, 0.25, -0.19)
        ], 0.008, 6, "gunmetal", "plain_metal", add_clamps=False, M_parent=M_dish)

    M_esm = g2b_mat((0.34, 1.15, -0.30), (0, 0, 0))
    kb.cyl("ESM_Drum", 0.155, 0.180, 0.23, 12, "armor_sub", "bolt_flange", (0, 0.095, 0), (0, 0, 0), 0.006, M_parent=M_esm)
    kb.cyl("ESM_Cap", 0.12, 0.145, 0.040, 12, "dark", "gear_collar", (0, 0.225, 0), (0, 0, 0), 0.004, M_parent=M_esm)
    kb.cyl("ESM_Beacon", 0.044, 0.048, 0.056, 12, "emit_cyan", "plain_metal", (0, 0.270, 0), (0, 0, 0), 0.003, M_parent=M_esm)
    for di in range(6):
        da = math.tau * di / 6.0
        kb.box(f"ESM_Dipole_{di}", (0.028, 0.16, 0.052), "chrome", "plain_metal",
               (math.cos(da) * 0.168, 0.13, math.sin(da) * 0.168), (0, -math.degrees(da), 0), 0.004, 1, M_parent=M_esm)

    # 6. Flush HP-B1 Rear Stepped Pad & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 1.12, 0.50, w=0.72, d=0.40)
    _add_rear_gen_pad(kb, "HP_G1", 0.54, 0.90, w=0.72, h=0.44)

    kb.add_marker("SOCKET_arm_l", (-1.06, 0.58, 0.02))
    kb.add_marker("SOCKET_arm_r", ( 1.06, 0.58, 0.02))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.12, 0.50))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.54, 0.90))
    kb.seat_core_low(0.14, new_y_top=0.12)


# ==============================================================================
# 4. core_pionier_dach — PIO-2A Asymmetric Split-Deck Recovery & Crane Core
# ==============================================================================

def build_core_pionier_dach(kb: KitbashScene):
    """PIO-2A Pionierpanzer Dachs Core: asymmetric split-deck hull (low left crane channel, raised right deck), 35t winch."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.25)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"PioStab_{si}", (sx * 0.29, 0.05, -0.22), (sx * 0.42, 0.26, -0.36), 0.022)

    # 1. Truly ASYMMETRIC Split-Deck Heavy Recovery Hull (left shoulder low for recessed yellow crane boom; right deck tall!)
    pio_secs = [
        (-1.14, _asym_ring(-0.46, 0.46, -0.58, 0.58, -0.44, 0.44, 0.34, 0.44, 0.44, 0.62, 0.70, 0.70, 0.80)),
        (-0.56, _asym_ring(-0.62, 0.64, -0.84, 0.88, -0.62, 0.68, 0.24, 0.40, 0.40, 0.78, 0.96, 0.92, 1.22)),
        ( 0.16, _asym_ring(-0.64, 0.68, -0.86, 0.92, -0.64, 0.70, 0.24, 0.40, 0.40, 0.80, 0.98, 0.96, 1.24)),
        ( 0.66, _asym_ring(-0.54, 0.56, -0.70, 0.74, -0.54, 0.58, 0.26, 0.42, 0.42, 0.82, 0.92, 0.98, 1.12)),
        ( 0.90, _asym_ring(-0.44, 0.44, -0.54, 0.56, -0.44, 0.46, 0.30, 0.44, 0.44, 0.78, 0.84, 0.92, 1.00)),
    ]
    kb.loft("PionierAsymHull", pio_secs, "armor_sub", "armor_slab", bevel_w=0.016, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Symmetrical HP-A1 Trunnions at (±1.10, 0.62, 0.04)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.86, 1.10, 0.62, 0.04)

    # 2. Sloped Asymmetric Front Glacis + 35-Ton Bow Copper Cable Winch Fairlead + Wide Engineering Dozer Blade
    M_gl, glw, glh = _quad_frame(
        (-0.44, 0.70, -1.14), ( 0.44, 0.80, -1.14),
        ( 0.68, 1.22, -0.56), (-0.62, 0.92, -0.56),
        ref_inside=(0.0, 0.62, -0.25),
    )
    kb.plate("PionierGlacis", trap_2d(0.84, 1.22, glh * 0.84, 0.05), 0.050, "armor", "armor_slab",
             (0, 0, -0.016), (0, 0, 0), 0.010, 1, M_parent=M_gl)
    kb.decal("PioCGStencil", "lift_cg", (0.20, 0.14), (0.24, 0.02, -0.0465), (0, 0, 0), M_parent=M_gl)

    # Signature 35-Ton Recessed Bow Recovery Winch Fairlead
    M_wn = g2b_mat((0.0, 0.56, -1.16), (0.0, 0.0, 0.0))
    kb.plate("WinchHouse", crect_2d(0.68, 0.24, (0.04, 0.04, 0.04, 0.04)), 0.16, "dark", "frame_cnc",
             (0, 0, 0.02), (0, 0, 0), 0.010, 1, M_parent=M_wn)
    kb.cyl("WinchDrum", 0.080, 0.080, 0.44, 14, "copper", "braid_hose",
           (0, 0, -0.05), (0, 0, 90), 0.004, u_rep=3.0, M_parent=M_wn)
    for ri, rx in enumerate([-0.22, 0.22]):
        kb.cyl(f"WinchRoller_{ri}", 0.028, 0.028, 0.20, 10, "chrome", "plain_metal",
               (rx, 0, -0.105), (0, 0, 0), 0.003, M_parent=M_wn)
        kb.cyl(f"WinchCap_{ri}", 0.038, 0.038, 0.022, 8, "brass", "gear_collar",
               (rx, 0.105, -0.105), (0, 0, 0), 0.002, M_parent=M_wn)
    kb.cyl("WinchHookRing", 0.070, 0.070, 0.032, 14, "accent", "plain_metal",
           (0, -0.01, -0.145), (0, 0, 90), 0.004, hollow_r=0.038, M_parent=M_wn)

    # Bold Wide Engineering Push-Blade / Dozer Lip with Hazard Edge + Twin Hydraulic Braces
    kb.plate("DozerBladeLip", trap_2d(1.36, 1.18, 0.22, 0.04), 0.072, "armor_sub", "armor_ribs",
             (0, 0.30, -1.26), (20, 0, 0), 0.010, 1)
    kb.box("DozerEdge", (1.34, 0.044, 0.032), "hazard", "hazard", (0, 0.22, -1.32), (20, 0, 0), 0.003, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"DozerBrace_{si}", (sx * 0.44, 0.34, -0.96), (sx * 0.48, 0.31, -1.23), 0.022)
        kb.headlight_cage(f"PioLight_{si}", (sx * 0.48, 0.66, -1.16), (0, sx * -14.0, 0))
        kb.tow_shackle(f"PioTow_{si}", (sx * 0.48, 0.44, -1.16), (0, 0, 90), 1.08)

    # 3. Recessed Left-Shoulder Telescopic Box-Girder Engineering Crane Boom (seated right into the lowered left deck!)
    M_cr = g2b_mat((-0.44, 1.02, -0.34), (0.0, 0.0, 0.0))
    kb.box("CranePivotBase", (0.26, 0.20, 0.26), "dark", "frame_cnc", (0, 0.0, 0.38), (0, 0, 0), 0.010, 1, M_parent=M_cr)
    kb.box("CraneBoomOuter", (0.24, 0.21, 0.88), "accent", "armor_ribs", (0, 0.12, -0.08), (0, 0, 0), 0.012, 1, M_parent=M_cr)
    kb.box("CraneBoomInner", (0.17, 0.15, 0.36), "gunmetal", "bolt_flange", (0, 0.12, -0.56), (0, 0, 0), 0.008, 1, M_parent=M_cr)
    kb.cyl("CranePulley", 0.082, 0.082, 0.135, 14, "dark", "gear_collar", (0, 0.10, -0.74), (0, 0, 90), 0.004, M_parent=M_cr)
    kb.cyl("CraneAxle", 0.028, 0.028, 0.195, 10, "chrome", "plain_metal", (0, 0.10, -0.74), (0, 0, 90), 0.003, M_parent=M_cr)
    kb.box("CraneHazard", (0.262, 0.048, 0.13), "hazard", "hazard", (0, 0.12, -0.38), (0, 0, 0), 0.003, 1, M_parent=M_cr)
    kb.hydraulic("CraneElevCyl", (-0.44, 0.96, -0.02), (-0.44, 1.12, -0.60), 0.028)
    kb.box("CraneRestCradle", (0.26, 0.28, 0.15), "dark", "frame_cnc", (-0.44, 0.98, -0.82), (0, 0, 0), 0.008, 1)

    # 4. Flanks: Right-Flank Twin Oxy-Acetylene Cutting Gas Cylinder Cage + Left Rear Radiator
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_rb, rbw, rbh = _quad_frame(
                (0.92, 0.40, 0.16), (0.74, 0.42, 0.66),
                (0.74, 0.92, 0.66), (0.92, 0.98, 0.16),
                ref_inside=(0.0, 0.64, 0.35),
            )
            kb.plate("PioRightLocker", crect_2d(rbw * 0.84, rbh * 0.80, (0.04, 0.04, 0.03, 0.03)), 0.056,
                     "armor_sub", "armor_hatch", (0, 0, -0.018), (0, 0, 0), 0.008, 1, M_parent=M_rb)
            kb.box("OxyRackBase", (0.38, 0.08, 0.14), "dark", "frame_cnc", (0, -0.14, -0.075), (0, 0, 0), 0.006, 1, M_parent=M_rb)
            kb.box("OxyRackStrap", (0.38, 0.032, 0.15), "gunmetal", "bolt_flange", (0, 0.06, -0.082), (0, 0, 0), 0.003, 1, M_parent=M_rb)
            for ti, tu in enumerate([-0.10, 0.10]):
                kb.cyl(f"OxyTank_{ti}", 0.060, 0.060, 0.36, 14, "gunmetal" if ti == 0 else "armor_oxide", "plain_metal",
                       (tu, 0.02, -0.105), (0, 0, 0), 0.008, M_parent=M_rb)
                kb.cyl(f"OxyValve_{ti}", 0.026, 0.050, 0.070, 10, "brass", "gear_collar",
                       (tu, 0.22, -0.105), (0, 0, 0), 0.003, M_parent=M_rb)
        else:
            M_rb, rbw, rbh = _quad_frame(
                (-0.70, 0.42, 0.66), (-0.86, 0.40, 0.16),
                (-0.86, 0.80, 0.16), (-0.70, 0.82, 0.66),
                ref_inside=(0.0, 0.64, 0.35),
            )
            kb.plate("PioLeftLocker", crect_2d(rbw * 0.84, rbh * 0.78, (0.04, 0.04, 0.03, 0.03)), 0.052,
                     "armor_sub", "armor_hatch", (0, 0, -0.016), (0, 0, 0), 0.008, 1, M_parent=M_rb)
            kb.louver_bay("PioLeftRad", rbw * 0.52, rbh * 0.48, 0.030, (0, 0, -0.058), (0, 0, 0),
                          blades=4, mesh_style=False, M_parent=M_rb)

    # 5. Raised Right-Deck Commander Cupola (pedestal-seated cleanly into sloped split deck!) & Whip
    kb.cyl("PioCupolaPed", 0.22, 0.24, 0.14, 16, "dark", "gear_collar", (0.32, 1.14, -0.26), (0, 0, 0), 0.005)
    kb.cupola_hatch("CmdCupola_R", (0.32, 1.205, -0.26))
    _add_whip_antenna(kb, "PioWhip_R", (0.56, 1.20, -0.02), h=0.82, tilt_x=-7.0)

    # 6. Level Rear Dorsal Pad Seated Cleanly Across Split Rear Deck + HP-G1 Dock
    kb.box("PioBackLeveler", (0.76, 0.10, 0.42), "dark", "frame_cnc", (0.0, 1.11, 0.50), (0, 0, 0), 0.008, 1)
    _add_dorsal_back_pad(kb, "HP_B1", 1.19, 0.50, w=0.76, d=0.42)
    _add_rear_gen_pad(kb, "HP_G1", 0.56, 0.92, w=0.74, h=0.46)

    kb.add_marker("SOCKET_arm_l", (-1.10, 0.62, 0.04))
    kb.add_marker("SOCKET_arm_r", ( 1.10, 0.62, 0.04))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.19, 0.50))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.56, 0.92))
    kb.seat_core_low(0.14, new_y_top=0.12)


# ==============================================================================
# 5. core_abv_shredder — M1150-B Ultra-Wide Low Breacher + Giant 10-Tine V-Plow
# ==============================================================================

def build_core_abv_shredder(kb: KitbashScene):
    """M1150-B Assault Breacher Core: ultra-wide low Abrams breacher arrowhead, 6x ERA, massive 10-tine V-mine plow."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.25)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"AbvStab_{si}", (sx * 0.30, 0.05, -0.22), (sx * 0.44, 0.26, -0.36), 0.022)

    # 1. Brutal Wide Low Abrams-Derived Arrowhead Breacher Loft (w_mid=1.96m, razor-swept cheeks, low 1.00m roof!)
    abv_secs = [
        (-1.18, _oct_ring(0.56, 0.78, 0.58, 0.36, 0.42, 0.58, 0.66)),   # Heavy plow-yoke breacher nose!
        (-0.56, _oct_ring(1.44, 1.94, 1.38, 0.24, 0.38, 0.78, 0.98)),   # Massive wide 38deg arrowhead shoulders
        ( 0.16, _oct_ring(1.48, 1.98, 1.40, 0.24, 0.38, 0.80, 1.01)),   # Broad low heavy breacher hull
        ( 0.66, _oct_ring(1.12, 1.46, 1.12, 0.26, 0.40, 0.78, 0.98)),   # Tapered rear bustle
        ( 0.92, _oct_ring(0.90, 1.12, 0.90, 0.30, 0.42, 0.74, 0.90)),   # Compact rear transom (<= 0.93)
    ]
    kb.loft("ABVBreacherHull", abv_secs, "armor_sub", "armor_slab", bevel_w=0.016, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Heavy Symmetrical HP-A1 Trunnions at (±1.16, 0.58, 0.04)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.96, 1.16, 0.58, 0.04)

    # 2. Sloped 36deg Breacher Glacis Armed with 6 Heavy ERA Wedges (2x3)
    M_gl, glw, glh = _quad_frame(
        (-0.29, 0.66, -1.18), ( 0.29, 0.66, -1.18),
        ( 0.69, 0.98, -0.56), (-0.69, 0.98, -0.56),
        ref_inside=(0.0, 0.58, -0.25),
    )
    kb.plate("ABVGlacis", trap_2d(0.60, 1.32, glh * 0.90, 0.05), 0.056, "armor", "armor_slab",
             (0, 0, -0.018), (0, 0, 0), 0.012, 1, M_parent=M_gl)
    for ri, rv in enumerate([-glh * 0.18, glh * 0.18]):
        x_span = 0.22 if ri == 0 else 0.32
        for ci, cu in enumerate([-x_span, 0.0, x_span]):
            kb.era_block(f"GlacisERA_{ri}_{ci}", (0.19 if ri == 0 else 0.27, glh * 0.28, 0.056),
                         "armor_sub" if (ri + ci) % 2 == 0 else "armor",
                         (cu, rv, -0.066), (0, 0, 0), M_parent=M_gl)

    # 3. MASSIVE Oversized Full-Width Protruding Hydraulic V-Shaped Comb Mine-Breaching Plow (10 Tines Total!)
    kb.plate("PlowCenterYoke", crect_2d(0.50, 0.26, (0.04, 0.04, 0.04, 0.04)), 0.28, "dark", "frame_cnc",
             (0, 0.48, -1.28), (0, 0, 0), 0.010, 1)
    kb.box("PlowYokeHazard", (0.42, 0.048, 0.016), "hazard", "hazard", (0, 0.55, -1.426), (0, 0, 0), 0.002, 1)
    plow_wing_xy = trap_2d(0.84, 0.72, 0.32, 0.04)
    for si, sx in enumerate([-1.0, 1.0]):
        M_pw = g2b_mat((sx * 0.46, 0.46, -1.38), (14.0, sx * -28.0, 0.0))
        kb.plate(f"PlowWing_{si}", plow_wing_xy, 0.074, "gunmetal", "armor_ribs",
                 (0, 0, 0), (0, 0, 0), 0.010, 1, M_parent=M_pw)
        kb.box(f"PlowRib_{si}", (0.68, 0.042, 0.038), "dark", "bolt_flange",
               (0, 0.10, -0.052), (0, 0, 0), 0.005, 1, M_parent=M_pw)
        for ti, tx in enumerate([-0.30, -0.15, 0.0, 0.15, 0.30]):
            kb.box(f"PlowTine_{si}_{ti}", (0.044, 0.17, 0.084), "accent", "plain_metal",
                   (tx, -0.16, -0.054), (22, 0, 0), 0.005, 1, M_parent=M_pw)
        kb.hydraulic(f"PlowLiftHyd_{si}", (sx * 0.48, 0.70, -1.04), (sx * 0.46, 0.52, -1.36), 0.028)
        kb.headlight_cage(f"AbvLight_{si}", (sx * 0.62, 0.64, -1.04), (0, sx * -22.0, 0))
        kb.tow_shackle(f"AbvTow_{si}", (sx * 0.26, 0.34, -1.16), (0, 0, 90), 1.08)

    # 4. Swept Breacher Cheeks + Twin 4-Tube (8 Total) Lane-Marking System (LMS) Brass Launcher Pods
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_fc, fcw, fch = _quad_frame(
                (0.39, 0.42, -1.18), (0.97, 0.38, -0.56),
                (0.97, 0.78, -0.56), (0.39, 0.58, -1.18),
                ref_inside=(0.0, 0.58, -0.20),
            )
            M_rb, rbw, rbh = _quad_frame(
                (0.99, 0.38, 0.16), (0.73, 0.40, 0.66),
                (0.73, 0.78, 0.66), (0.99, 0.80, 0.16),
                ref_inside=(0.0, 0.58, 0.35),
            )
        else:
            M_fc, fcw, fch = _quad_frame(
                (-0.97, 0.38, -0.56), (-0.39, 0.42, -1.18),
                (-0.39, 0.58, -1.18), (-0.97, 0.78, -0.56),
                ref_inside=(0.0, 0.58, -0.20),
            )
            M_rb, rbw, rbh = _quad_frame(
                (-0.73, 0.40, 0.66), (-0.99, 0.38, 0.16),
                (-0.99, 0.80, 0.16), (-0.73, 0.78, 0.66),
                ref_inside=(0.0, 0.58, 0.35),
            )
        kb.plate(f"AbvCheekSlab_{si}", crect_2d(fcw * 0.86, fch * 0.80, (0.04, 0.04, 0.03, 0.03)), 0.056,
                 "armor", "armor_panel", (0, 0, -0.018), (0, 0, 0), 0.010, 1, M_parent=M_fc)
        if si == 0:
            kb.decal("AbvUnit", "ord_12", (0.22, 0.12), (0, 0, -0.050), (0, 0, 0), M_parent=M_fc)

        kb.plate(f"LMSPodBody_{si}", crect_2d(rbw * 0.82, rbh * 0.72, (0.04, 0.04, 0.03, 0.03)), 0.088,
                 "armor_sub", "armor_hatch", (0, -0.02, -0.032), (0, 0, 0), 0.010, 1, M_parent=M_rb)
        for ti, tu in enumerate([-rbw * 0.27, -rbw * 0.09, rbw * 0.09, rbw * 0.27]):
            kb.cyl(f"LMSTube_{si}_{ti}", 0.028, 0.028, 0.13, 10, "brass", "gear_collar",
                   (tu, rbh * 0.34, -0.052), (16, 0, 0), 0.003, hollow_r=0.019, M_parent=M_rb)
        kb.smoke_pod(f"AbvSmoke_{si}", (sx * 0.68, 1.00, -0.44), (-22, sx * -26.0, 0))
        _add_whip_antenna(kb, f"AbvWhip_{si}", (sx * 0.56, 0.99, -0.02), h=0.80, tilt_x=-8.0)

    # 5. Roof Left Commander Cupola + Roof Right Panoramic CITV Dual-Optic Turret
    kb.cupola_hatch("CmdCupola_L", (-0.34, 1.00, -0.26))
    _add_citv_sight(kb, "CITV_R", (0.34, 0.98, -0.26), head_slot="armor_sub", lens_slot="emit_cyan")

    # 6. Flush HP-B1 Dorsal Pad & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 1.04, 0.50, w=0.80, d=0.44)
    _add_rear_gen_pad(kb, "HP_G1", 0.54, 0.94, w=0.76, h=0.44)

    kb.add_marker("SOCKET_arm_l", (-1.16, 0.58, 0.04))
    kb.add_marker("SOCKET_arm_r", ( 1.16, 0.58, 0.04))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.04, 0.50))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.54, 0.94))
    kb.seat_core_low(0.14, new_y_top=0.12)
