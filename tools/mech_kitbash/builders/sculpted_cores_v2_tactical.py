"""Sculpted Non-Boxy Military Mecha Cores v2.1 — Tactical, IFV & MBT Group (5 Cores, Zero-Clip).

Replaces legacy rectangular-box hulls with multi-section flat-milled polygonal lofted silhouettes:
  1. core_command         — CMD-1/CM-7 Destroyer Conning-Tower Command Bridge (narrow waist + raked 3-facet bridge + AESA mast)
  2. core_bradley_busk    — M2A4-BK Chisel-Nosed Heavy IFV Wedge (46deg glacis + canted BRAT flanks + BUSK shield + ISU)
  3. core_puma_spz        — SPZ-30 Low-Profile Faceted German Stealth-Wedge IFV (hedgehog glacis + tumblehome AMAP + MUSS)
  4. core_bmpt_terminator — BMPT-72 Twin-Sponson Arrowhead Assault Hull (5x Kontakt-5 chevron + twin AGS-30 sponsons + Ramka)
  5. core_merkava_mk4m    — MRK-4M Knife-Edge Front-Engine Wedge + Arrowhead Turret Crown (4x Trophy APS + ball-chain)

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
    _add_slat_panel,
)


# ==============================================================================
# SHARED TACTICAL & SPECIALIST SUB-ASSEMBLIES (ZERO-CLIP)
# ==============================================================================

def _oct_2d(r: float):
    """Regular 8-sided chamfered octagon outline in local XY plane."""
    a = r * 0.9239
    b = r * 0.3827
    return [
        (a, b), (b, a), (-b, a), (-a, b),
        (-a, -b), (-b, -a), (b, -a), (a, -b),
    ]


def _add_optic_lens(kb: KitbashScene, prefix: str, r: float, pos, rot_deg=(90, 0, 0),
                    lens_slot: str = "emit_cyan", M_parent=None):
    """Multi-ring armored optical bezel with deep bore cavity and recessed objective lens."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.cyl(f"{prefix}_bz", r + 0.010, r + 0.012, 0.028, 12, "gunmetal", "gear_collar",
           (0, 0.004, 0), (0, 0, 0), 0.003, hollow_r=r * 0.84, M_parent=M)
    kb.cyl(f"{prefix}_br", r * 0.82, r * 0.82, 0.010, 10, "bore", "plain_metal",
           (0, 0.010, 0), (0, 0, 0), 0.001, M_parent=M)
    kb.cyl(f"{prefix}_ln", r * 0.76, r * 0.76, 0.010, 12, lens_slot, "plain_metal",
           (0, -0.006, 0), (0, 0, 0), 0.002, M_parent=M)


def _add_citv_sight(kb: KitbashScene, prefix: str, pos, rot_deg=(0, 0, 0),
                    head_slot: str = "armor_sub", lens_slot: str = "emit_cyan", M_parent=None):
    """Panoramic Commander Independent Thermal Viewer (CITV) seated cleanly into hull roof."""
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.cyl(f"{prefix}_ped", 0.120, 0.145, 0.130, 14, "dark", "gear_collar",
           (0, 0.045, 0), (0, 0, 0), 0.005, M_parent=M)
    kb.box(f"{prefix}_hd", (0.23, 0.165, 0.215), head_slot, "armor_pocket",
           (0, 0.175, 0), (0, 0, 0), 0.012, 1, M_parent=M)
    kb.box(f"{prefix}_cv", (0.168, 0.100, 0.024), "bore", "plain_metal",
           (0, 0.175, -0.106), (0, 0, 0), 0.003, 1, M_parent=M)
    _add_optic_lens(kb, f"{prefix}_l0", 0.034, (-0.042, 0.175, -0.118), (90, 0, 0), lens_slot, M_parent=M)
    _add_optic_lens(kb, f"{prefix}_l1", 0.024, (0.044, 0.175, -0.118), (90, 0, 0), "emit_amber", M_parent=M)
    kb.plate(f"{prefix}_cap", trap_2d(0.22, 0.17, 0.036, 0.008), 0.225, "gunmetal", "bolt_flange",
             (0, 0.268, 0), (0, 0, 0), 0.005, 1, M_parent=M)


def _add_exhaust_stack(kb: KitbashScene, prefix: str, pos, rot_deg=(12, 0, 0), h: float = 0.24):
    """Perforated heat-shield exhaust jacket with hollow blackened pipe."""
    M = g2b_mat(pos, rot_deg)
    kb.cyl(f"{prefix}_pipe", 0.036, 0.040, h, 12, "dark", "plain_metal",
           (0, 0.04, 0), (0, 0, 0), 0.003, hollow_r=0.025, M_parent=M)
    kb.cyl(f"{prefix}_shld", 0.052, 0.052, h * 0.68, 12, "gunmetal", "vent_mesh",
           (0, 0.025, 0), (0, 0, 0), 0.003, hollow_r=0.044, M_parent=M, u_rep=2.0)


# ==============================================================================
# 1. core_command — CMD-1 / CM-7 Destroyer Conning-Tower Command Bridge
# ==============================================================================

def build_core_command(kb: KitbashScene):
    """CMD-1/CM-7 Command Core: narrow armored waist, forward-raked 3-facet destroyer bridge, AESA mast & SATCOM."""
    # 1. HP-C1 Waist Collar + Distinct Tapered Armored Pedestal Abdomen (clears all leg knees!)
    kb.waist_collar_core("HP_C1_Core", y_top=0.16)
    abd_secs = [
        (-0.38, _oct_ring(0.46, 0.62, 0.60, 0.14, 0.22, 0.34, 0.42)),
        ( 0.04, _oct_ring(0.52, 0.74, 0.78, 0.14, 0.22, 0.36, 0.44)),
        ( 0.44, _oct_ring(0.46, 0.64, 0.64, 0.14, 0.22, 0.34, 0.42)),
    ]
    kb.loft("CmdPedestalWaist", abd_secs, "dark", "frame_cnc", bevel_w=0.012, bevel_seg=1, tile_u=2.0, flat_shade=True)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"CmdWaistHyd_{si}", (sx * 0.29, 0.04, -0.18), (sx * 0.42, 0.38, -0.28), 0.020)

    # 2. Forward-Raked 3-Facet Naval Conning-Tower Bridge Hull (narrow prow -> flared CIC -> tapered stern!)
    bridge_secs = [
        (-0.88, _oct_ring(0.44, 0.62, 0.50, 0.48, 0.56, 0.90, 1.06)),   # Forward-thrust armored CIC prow!
        (-0.44, _oct_ring(0.84, 1.24, 0.96, 0.36, 0.48, 0.98, 1.20)),   # Flared armored command bridge beam
        ( 0.10, _oct_ring(0.90, 1.32, 1.02, 0.34, 0.48, 1.00, 1.22)),   # Main CIC torso mid-section
        ( 0.48, _oct_ring(0.76, 1.08, 0.86, 0.36, 0.48, 0.96, 1.18)),   # Tapered rear comms spine
        ( 0.72, _oct_ring(0.64, 0.86, 0.70, 0.38, 0.48, 0.88, 1.04)),   # Compact rear transom (<= 0.73)
    ]
    kb.loft("CommandBridgeHull", bridge_secs, "armor_sub", "armor_slab", bevel_w=0.015, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Symmetrical HP-A1 Trunnions at (±0.86, 0.56, 0.0)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.64, 0.86, 0.56, 0.0)

    # 3. Armored Bridge Prow Facet + 3-Pane Panoramic Visor + Chin EO/IR Gimbal
    kb.plate("BridgeProwArmor", crect_2d(0.58, 0.44, (0.06, 0.06, 0.04, 0.04)), 0.072, "armor", "armor_panel",
             (0, 0.74, -0.90), (0, 0, 0), 0.010, 1)
    kb.box("BridgeVisorFrame", (0.52, 0.14, 0.056), "dark", "frame_cnc", (0, 0.82, -0.942), (0, 0, 0), 0.006, 1)
    kb.box("BridgeVisorRec", (0.44, 0.082, 0.018), "bore", "plain_metal", (0, 0.82, -0.968), (0, 0, 0), 0.002, 1)
    kb.plate("BridgeVisorBrow", trap_2d(0.56, 0.46, 0.038, 0.010), 0.13, "gunmetal", "bolt_flange",
             (0, 0.905, -0.94), (10, 0, 0), 0.005, 1)
    for pi, (px, pw) in enumerate([(-0.145, 0.125), (0.0, 0.135), (0.145, 0.125)]):
        kb.box(f"BridgeGlass_{pi}", (pw, 0.062, 0.014), "glass", "plain_metal", (px, 0.82, -0.978), (0, 0, 0), 0.002, 1)
    for mi, mx in enumerate([-0.075, 0.075]):
        kb.box(f"BridgeMullion_{mi}", (0.022, 0.095, 0.036), "dark", "bolt_flange", (mx, 0.82, -0.976), (0, 0, 0), 0.003, 1)
    kb.box("BridgeAccent", (0.42, 0.038, 0.016), "accent", "plain_metal", (0, 0.60, -0.940), (0, 0, 0), 0.003, 1)
    kb.box("BridgeHazard", (0.28, 0.032, 0.014), "hazard", "hazard", (0, 0.53, -0.938), (0, 0, 0), 0.002, 1)
    # Upper raked bridge brow deck + chin EO/IR gimbal cleanly hung on strut below prow!
    M_top_f, tfw, tfh = _quad_frame(
        (-0.25, 1.06, -0.88), ( 0.25, 1.06, -0.88),
        ( 0.48, 1.20, -0.44), (-0.48, 1.20, -0.44),
        ref_inside=(0.0, 0.78, -0.20),
    )
    kb.plate("BridgeBrowDeck", trap_2d(0.48, 0.90, tfh * 0.88, 0.04), 0.044, "armor", "armor_slab",
             (0, 0, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_top_f)
    kb.decal("CmdUnitStencil", "unit_54", (0.22, 0.14), (0.0, 0.0, -0.040), (0, 0, 0), M_parent=M_top_f)
    kb.cyl("CmdChinStrut", 0.052, 0.058, 0.096, 12, "dark", "gear_collar", (0, 0.436, -0.74), (0, 0, 0), 0.004)
    kb.eoir_gimbal("ChinDatalinkEOIR", (0.0, 0.376, -0.74))

    # 4. Canted Front Bridge Cheeks + Sculpted Winged Encrypted Comms Pods + Rear Tapered Flanks
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_fc, fcw, fch = _quad_frame(
                (0.31, 0.56, -0.88), (0.62, 0.48, -0.44),
                (0.62, 0.98, -0.44), (0.31, 0.90, -0.88),
                ref_inside=(0.0, 0.72, -0.20),
            )
            M_rc, rcw, rch = _quad_frame(
                (0.66, 0.48, 0.10), (0.54, 0.48, 0.48),
                (0.54, 0.96, 0.48), (0.66, 1.00, 0.10),
                ref_inside=(0.0, 0.72, 0.25),
            )
        else:
            M_fc, fcw, fch = _quad_frame(
                (-0.62, 0.48, -0.44), (-0.31, 0.56, -0.88),
                (-0.31, 0.90, -0.88), (-0.62, 0.98, -0.44),
                ref_inside=(0.0, 0.72, -0.20),
            )
            M_rc, rcw, rch = _quad_frame(
                (-0.54, 0.48, 0.48), (-0.66, 0.48, 0.10),
                (-0.66, 1.00, 0.10), (-0.54, 0.96, 0.48),
                ref_inside=(0.0, 0.72, 0.25),
            )
        kb.plate(f"BridgeCheekArmor_{si}", crect_2d(fcw * 0.86, fch * 0.84, (0.04, 0.04, 0.04, 0.04)), 0.052,
                 "armor", "armor_panel", (0, 0, -0.016), (0, 0, 0), 0.009, 1, M_parent=M_fc)
        # Side bridge angled armored viewport strip on each canted cheek
        kb.box(f"CheekGlass_{si}", (fcw * 0.48, 0.068, 0.018), "glass", "plain_metal",
               (0, fch * 0.22, -0.046), (0, 0, 0), 0.002, 1, M_parent=M_fc)
        kb.headlight_cage(f"CmdLight_{si}", (sx * 0.40, 0.48, -0.82), (0, sx * -22.0, 0))
        kb.tow_shackle(f"CmdTow_{si}", (sx * 0.24, 0.38, -0.58), (0, 0, 90), 0.95)

        # Swept chamfered upper shoulder Encrypted Comms Wing Pods (strictly inboard of |x|<=0.74, forward of HP-B1!)
        M_cw = _face_frame((sx * 0.56, 1.12, -0.14), (sx * 0.45, 0.89, 0.0))
        kb.plate(f"CommsWingPod_{si}", trap_2d(0.54, 0.42, 0.24, 0.04), 0.16,
                 "armor" if si == 0 else "armor_oxide", "armor_pocket",
                 (0, 0, -0.065), (0, 0, 0), 0.010, 1, M_parent=M_cw)
        kb.box(f"CommsWingAccent_{si}", (0.34, 0.040, 0.016), "accent", "plain_metal",
               (0, 0.0, -0.150), (0, 0, 0), 0.003, 1, M_parent=M_cw)
        kb.smoke_pod(f"CmdSmoke_{si}", (sx * 0.56, 1.24, -0.44), (-22, sx * -20.0, 0))

        # Tapered Rear Cooling Buttress + Louvers (shifted aft of ArmMount trunnion!)
        kb.plate(f"CmdRearPlate_{si}", crect_2d(rcw * 0.82, rch * 0.78, (0.04, 0.04, 0.04, 0.04)), 0.044,
                 "armor_sub", "armor_ribs", (0, 0, -0.012), (0, 0, 0), 0.008, 1, M_parent=M_rc)
        kb.louver_bay(f"CmdRearVent_{si}", rcw * 0.42, rch * 0.38, 0.028, (sx * 0.055, 0.06, -0.046), (0, 0, 0),
                      blades=4, mesh_style=True, M_parent=M_rc)

    # 5. Roof Left Phased-Array AESA Recon Mast + Roof Right SATCOM Radome (strictly forward of z=0.05!)
    kb.cyl("MastBase", 0.090, 0.108, 0.10, 16, "gunmetal", "gear_collar", (-0.28, 1.24, -0.26), (0, 0, 0), 0.005)
    kb.cyl("MastCol", 0.048, 0.056, 0.44, 12, "dark", "frame_cnc", (-0.28, 1.48, -0.26), (0, 0, 0), 0.004)
    M_aesa = g2b_mat((-0.28, 1.76, -0.26), (0, -22, 0))
    kb.plate("AESA_Back", crect_2d(0.52, 0.28, (0.05, 0.05, 0.05, 0.05)), 0.078, "armor_sub", "armor_panel",
             (0, 0, 0), (-10, 0, 0), 0.010, 1, M_parent=M_aesa)
    kb.box("AESA_Face", (0.42, 0.20, 0.018), "armor_dark", "vent_mesh", (0, 0, -0.046), (-10, 0, 0), 0.003, 1, M_parent=M_aesa)
    kb.cyl("MastEO_Neck", 0.038, 0.048, 0.07, 12, "gunmetal", "gear_collar", (0, 0.16, 0), (0, 0, 0), 0.003, M_parent=M_aesa)
    kb.box("MastEO_Head", (0.13, 0.11, 0.13), "dark", "armor_pocket", (0, 0.23, 0), (0, 0, 0), 0.014, 1, M_parent=M_aesa)
    _add_optic_lens(kb, "MastEO_Lens", 0.028, (0, 0.23, -0.068), (90, 0, 0), "emit_cyan", M_parent=M_aesa)

    # Right Roof Low-Profile SATCOM Radome Dish + Dual Spring Whip Antennas
    kb.cyl("SatcomBase", 0.18, 0.21, 0.085, 18, "armor", "bolt_flange", (0.20, 1.24, -0.22), (0, 0, 0), 0.006)
    kb.cyl("SatcomDome", 0.13, 0.165, 0.042, 16, "armor_sub", "armor_hatch", (0.20, 1.298, -0.22), (0, 0, 0), 0.005)
    kb.bolt_ring("SatcomBolts", 0.17, 8, 0.008, (0.20, 1.284, -0.22), (0, 0, 0))
    _add_whip_antenna(kb, "CmdWhip_1", (0.44, 1.20, -0.04), h=0.88, tilt_x=-5.0)
    _add_whip_antenna(kb, "CmdWhip_2", (-0.44, 1.20, -0.04), h=0.68, tilt_x=-8.0)

    # 6. Flush HP-B1 Dorsal Pad & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 1.24, 0.44, w=0.70, d=0.40)
    _add_rear_gen_pad(kb, "HP_G1", 0.52, 0.76, w=0.68, h=0.44)

    kb.add_marker("SOCKET_arm_l", (-0.86, 0.56, 0.0))
    kb.add_marker("SOCKET_arm_r", ( 0.86, 0.56, 0.0))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.24, 0.44))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.52, 0.76))
    kb.seat_core_low(0.07, new_y_top=0.09)


# ==============================================================================
# 2. core_bradley_busk — M2A4-BK Chisel-Nosed Heavy IFV Wedge + BRAT ERA
# ==============================================================================

def build_core_bradley_busk(kb: KitbashScene):
    """M2A4-BK Bradley BUSK Core: 46deg sloped IFV wedge, right intake louver, BRAT ERA, BUSK glass cage & ISU."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.25)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"BuskStab_{si}", (sx * 0.29, 0.05, -0.22), (sx * 0.42, 0.28, -0.36), 0.022)

    # 1. Angular High-Shouldered IFV Wedge Loft (sharp chisel nose -> flared hexagonal flanks -> tapered stern!)
    busk_secs = [
        (-1.14, _oct_ring(0.76, 1.00, 0.78, 0.40, 0.48, 0.62, 0.70)),   # Sharp chisel IFV nose belt!
        (-0.58, _oct_ring(1.20, 1.66, 1.26, 0.25, 0.42, 0.86, 1.12)),   # High 46deg Bradley glacis crest
        ( 0.14, _oct_ring(1.26, 1.72, 1.32, 0.24, 0.42, 0.88, 1.15)),   # Main IFV fighting compartment
        ( 0.64, _oct_ring(1.06, 1.40, 1.10, 0.26, 0.42, 0.86, 1.12)),   # Tapered rear hull
        ( 0.88, _oct_ring(0.88, 1.10, 0.92, 0.30, 0.44, 0.80, 1.00)),   # Rear ramp transom (<= 0.89)
    ]
    kb.loft("BradleyWedgeHull", busk_secs, "armor_sub", "armor_slab", bevel_w=0.016, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Symmetrical HP-A1 Trunnions at (±1.08, 0.64, 0.02)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.84, 1.08, 0.64, 0.02)

    # 2. Iconic 46deg Bradley Upper Glacis: Right Powerpack Intake Louver Bay + Left Dual Tall BRAT ERA
    M_gl, glw, glh = _quad_frame(
        (-0.39, 0.70, -1.14), ( 0.39, 0.70, -1.14),
        ( 0.63, 1.12, -0.58), (-0.63, 1.12, -0.58),
        ref_inside=(0.0, 0.62, -0.20),
    )
    kb.plate("BradleyGlacis", trap_2d(0.76, 1.22, glh * 0.90, 0.05), 0.064, "armor", "armor_slab",
             (0, 0, -0.020), (0, 0, 0), 0.012, 1, M_parent=M_gl)
    kb.louver_bay("GlacisEngineVent", 0.44, glh * 0.56, 0.032, (0.24, 0.02, -0.064), (0, 0, 0),
                  blades=5, mesh_style=False, M_parent=M_gl)
    for ei, ex in enumerate([-0.36, -0.10]):
        kb.era_block(f"UpperBRAT_{ei}", (0.22, glh * 0.54, 0.052), "armor_sub",
                     (ex, 0.02, -0.072), (0, 0, 0), M_parent=M_gl)

    # Front Chisel Nose Belt with 4x BRAT ERA Bricks + Hazard Bar + Headlights + Shackles
    kb.plate("LowerBUSKBelt", crect_2d(0.96, 0.22, (0.04, 0.04, 0.04, 0.04)), 0.072, "armor_sub", "armor_ribs",
             (0, 0.55, -1.16), (0, 0, 0), 0.008, 1)
    for bi, bx in enumerate([-0.34, -0.115, 0.115, 0.34]):
        kb.era_block(f"LowerBRAT_{bi}", (0.20, 0.16, 0.056), "armor" if bi % 2 == 0 else "armor_sub",
                     (bx, 0.55, -1.215), (0, 0, 0))
    kb.box("BuskHazard", (0.48, 0.036, 0.014), "hazard", "hazard", (0, 0.415, -1.155), (-18, 0, 0), 0.002, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"BuskLight_{si}", (sx * 0.56, 0.72, -1.10), (0, sx * -16.0, 0))
        kb.tow_shackle(f"BuskTow_{si}", (sx * 0.32, 0.35, -1.04), (0, 0, 90), 1.0)

    # 3. Canted Forward Cheeks + Angled Tumblehome Flanks Wrapped in BRAT Box ERA + 4-Tube Smoke Banks
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_fc, fcw, fch = _quad_frame(
                (0.50, 0.48, -1.14), (0.83, 0.42, -0.58),
                (0.83, 0.86, -0.58), (0.50, 0.62, -1.14),
                ref_inside=(0.0, 0.64, -0.15),
            )
            M_tu, tuw, tuh = _quad_frame(
                (0.83, 0.86, -0.58), (0.86, 0.88, 0.14),
                (0.66, 1.15,  0.14), (0.63, 1.12, -0.58),
                ref_inside=(0.0, 0.64, -0.10),
            )
            M_rb, rbw, rbh = _quad_frame(
                (0.86, 0.42, 0.14), (0.70, 0.42, 0.64),
                (0.70, 0.86, 0.64), (0.86, 0.88, 0.14),
                ref_inside=(0.0, 0.64, 0.35),
            )
        else:
            M_fc, fcw, fch = _quad_frame(
                (-0.83, 0.42, -0.58), (-0.50, 0.48, -1.14),
                (-0.50, 0.62, -1.14), (-0.83, 0.86, -0.58),
                ref_inside=(0.0, 0.64, -0.15),
            )
            M_tu, tuw, tuh = _quad_frame(
                (-0.86, 0.88,  0.14), (-0.83, 0.86, -0.58),
                (-0.63, 1.12, -0.58), (-0.66, 1.15,  0.14),
                ref_inside=(0.0, 0.64, -0.10),
            )
            M_rb, rbw, rbh = _quad_frame(
                (-0.70, 0.42, 0.64), (-0.86, 0.42, 0.14),
                (-0.86, 0.88, 0.14), (-0.70, 0.86, 0.64),
                ref_inside=(0.0, 0.64, 0.35),
            )
        # Forward cheek BRAT reactive armor pack (2 staggered tiles)
        kb.plate(f"BuskCheekBacking_{si}", crect_2d(fcw * 0.84, fch * 0.78, (0.04, 0.04, 0.03, 0.03)), 0.044,
                 "armor_sub", "armor_panel", (0, 0, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_fc)
        for ei, eu in enumerate([-fcw * 0.20, fcw * 0.20]):
            kb.era_block(f"CheekBRAT_{si}_{ei}", (fcw * 0.34, fch * 0.56, 0.044),
                         "armor" if ei == 0 else "armor_sub", (eu, 0, -0.054), (0, 0, 0), M_parent=M_fc)

        # Tumblehome upper flank armor + 4-tube smoke discharger bank
        kb.plate(f"BuskShoulderSlab_{si}", crect_2d(tuw * 0.86, tuh * 0.78, (0.04, 0.04, 0.03, 0.03)), 0.044,
                 "armor" if si == 0 else "armor_oxide", "weld_plate", (0, 0, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_tu)
        if si == 0:
            kb.decal("BuskUnit", "unit_17", (0.20, 0.12), (0.0, 0.0, -0.040), (0, 0, 0), M_parent=M_tu)
        kb.smoke_pod(f"BuskSmoke_{si}", (sx * 0.66, 1.14, -0.50), (-22, sx * -20.0, 0))

        # Rear tapered flank 2x2 BRAT ERA cassettes (all strictly inboard of x=±0.94!)
        kb.plate(f"RearFlankBack_{si}", crect_2d(rbw * 0.84, rbh * 0.80, (0.04, 0.04, 0.03, 0.03)), 0.038,
                 "armor_sub", "armor_ribs", (0, 0, -0.012), (0, 0, 0), 0.008, 1, M_parent=M_rb)
        for ri, rv in enumerate([-rbh * 0.19, rbh * 0.19]):
            for ci, cu in enumerate([-rbw * 0.20, rbw * 0.20]):
                kb.era_block(f"RearBRAT_{si}_{ri}_{ci}", (rbw * 0.34, rbh * 0.30, 0.042),
                             "armor" if (ri + ci) % 2 == 0 else "armor_sub",
                             (cu, rv, -0.048), (0, 0, 0), M_parent=M_rb)
        _add_whip_antenna(kb, f"BuskAnt_{si}", (sx * 0.52, 1.12, -0.02), h=0.76, tilt_x=-8.0)

    # 4. Left-Roof Driver BUSK Transparent Armored Shield Cage + Right-Roof Bradley ISU FLIR Turret (strictly z <= 0.0!)
    M_drv = g2b_mat((-0.34, 1.12, -0.34), (0, 0, 0))
    kb.plate("DriverRing", crect_2d(0.38, 0.32, (0.04, 0.04, 0.04, 0.04)), 0.14, "armor", "armor_hatch",
             (0, 0.05, 0), (90, 0, 0), 0.010, 1, M_parent=M_drv)
    _add_periscope(kb, "BUSK_PeriC", 0.14, 0.088, ( 0.00, 0.155, -0.14), (0,   0, 0), "glass", M_parent=M_drv)
    _add_periscope(kb, "BUSK_PeriL", 0.13, 0.084, (-0.16, 0.155, -0.11), (0,  40, 0), "glass", M_parent=M_drv)
    _add_periscope(kb, "BUSK_PeriR", 0.13, 0.084, ( 0.16, 0.155, -0.11), (0, -40, 0), "glass", M_parent=M_drv)

    M_isu = g2b_mat((0.34, 1.12, -0.30), (0, 0, 0))
    kb.plate("ISU_Body", crect_2d(0.34, 0.25, (0.04, 0.04, 0.03, 0.03)), 0.30, "armor", "armor_pocket",
             (0, 0.13, 0), (0, 0, 0), 0.012, 1, M_parent=M_isu)
    kb.box("ISU_Hood", (0.36, 0.024, 0.11), "gunmetal", "bolt_flange", (0, 0.265, -0.135), (8, 0, 0), 0.004, 1, M_parent=M_isu)
    kb.box("ISU_Rec", (0.26, 0.15, 0.024), "bore", "plain_metal", (0, 0.13, -0.152), (0, 0, 0), 0.003, 1, M_parent=M_isu)
    _add_optic_lens(kb, "ISU_FLIR", 0.044, (-0.058, 0.13, -0.164), (90, 0, 0), "emit_cyan", M_parent=M_isu)
    _add_optic_lens(kb, "ISU_Day",  0.030, ( 0.060, 0.13, -0.164), (90, 0, 0), "emit_amber", M_parent=M_isu)

    # 5. Stepped Armored Dorsal Bustle Plinth + Flush HP-B1 & HP-G1 (clears back_cargo + gen_diesel 100%!)
    kb.plate("BuskDorsalPlinth", trap_2d(0.92, 0.80, 0.44, 0.04), 0.24, "armor_sub", "armor_ribs",
             (0, 1.24, 0.46), (90, 0, 0), 0.012, 1)
    _add_dorsal_back_pad(kb, "HP_B1", 1.38, 0.46, w=0.78, d=0.42)
    _add_rear_gen_pad(kb, "HP_G1", 0.44, 0.90, w=0.74, h=0.38)

    kb.add_marker("SOCKET_arm_l", (-1.08, 0.64, 0.02))
    kb.add_marker("SOCKET_arm_r", ( 1.08, 0.64, 0.02))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.38, 0.46))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.44, 0.90))
    kb.seat_core_low(0.14, new_y_top=0.12)


# ==============================================================================
# 3. core_puma_spz — SPZ-30 Sleek Narrow Razor-Chined Stealth IFV + Hedgehog + AMAP
# ==============================================================================

def build_core_puma_spz(kb: KitbashScene):
    """SPZ-30 Puma Core: narrow razor-chined long-nosed stealth IFV, 6x rubber hedgehog strips, spaced AMAP slabs, MUSS."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.25)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"PumaStab_{si}", (sx * 0.28, 0.05, -0.20), (sx * 0.38, 0.26, -0.34), 0.020)

    # 1. Sleek Narrow Long-Nosed German Stealth-Wedge Loft (distinctly narrower & sharper than Bradley/MBTs!)
    puma_secs = [
        (-1.30, _oct_ring(0.44, 0.62, 0.46, 0.46, 0.50, 0.55, 0.59)),   # Long razor knife-edge Puma prow!
        (-0.56, _oct_ring(0.96, 1.38, 0.92, 0.24, 0.40, 0.76, 0.98)),   # Narrow sleek 54deg stealth glacis + sharp chine
        ( 0.16, _oct_ring(1.02, 1.44, 0.96, 0.24, 0.40, 0.78, 1.01)),   # Narrow stealth IFV body
        ( 0.64, _oct_ring(0.86, 1.18, 0.84, 0.26, 0.42, 0.76, 0.98)),   # Tapered rear troop bay
        ( 0.88, _oct_ring(0.72, 0.92, 0.72, 0.30, 0.44, 0.72, 0.90)),   # Compact narrow transom (<= 0.89)
    ]
    kb.loft("PumaStealthWedge", puma_secs, "armor_sub", "armor_slab", bevel_w=0.015, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Symmetrical HP-A1 Trunnions at (±1.02, 0.60, 0.02)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.70, 1.02, 0.60, 0.02)

    # 2. Long Razor-Sloped 54deg Upper Glacis with 6 Longitudinal Rubber "Igelpanzerung" Hedgehog Strips
    M_ug, ugw, ugh = _quad_frame(
        (-0.23, 0.59, -1.30), ( 0.23, 0.59, -1.30),
        ( 0.46, 0.98, -0.56), (-0.46, 0.98, -0.56),
        ref_inside=(0.0, 0.54, -0.35),
    )
    kb.plate("PumaUpperGlacis", trap_2d(0.46, 0.90, ugh * 0.90, 0.04), 0.052, "armor", "armor_slab",
             (0, 0, -0.016), (0, 0, 0), 0.010, 1, M_parent=M_ug)
    # 6 anti-top-attack rubber hedgehog mat rails sitting cleanly proud of PumaUpperGlacis!
    for hi, hx in enumerate([-0.30, -0.18, -0.06, 0.06, 0.18, 0.30]):
        strip_len = ugh * (0.52 if abs(hx) > 0.24 else 0.74)
        kb.box(f"HedgehogPad_{hi}", (0.084, strip_len, 0.032), "rubber", "dust_boot",
               (hx, 0.06 if abs(hx) > 0.24 else 0.0, -0.052), (0, 0, 0), 0.004, 1, M_parent=M_ug)
        kb.cyl(f"HedgehogPin_{hi}", 0.008, 0.010, 0.014, 6, "chrome", "plain_metal",
               (hx, (0.06 if abs(hx) > 0.24 else 0.0) + strip_len * 0.36, -0.070), (90, 0, 0), 0.002, M_parent=M_ug)

    # Lower -38deg Glacis Belt + Hazard Bar + Headlights + Tow Shackles
    M_lg, lgw, lgh = _quad_frame(
        (-0.48, 0.24, -0.56), ( 0.48, 0.24, -0.56),
        ( 0.22, 0.46, -1.30), (-0.22, 0.46, -1.30),
        ref_inside=(0.0, 0.54, -0.35),
    )
    kb.plate("PumaLowerGlacis", trap_2d(0.92, 0.44, lgh * 0.84, 0.04), 0.046, "armor_sub", "armor_ribs",
             (0, 0, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_lg)
    kb.box("PumaHazard", (0.28, 0.042, 0.014), "hazard", "hazard", (0, 0.0, -0.040), (0, 0, 0), 0.002, 1, M_parent=M_lg)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"PumaLight_{si}", (sx * 0.31, 0.54, -1.26), (0, sx * -20.0, 0))
        kb.tow_shackle(f"PumaTow_{si}", (sx * 0.22, -0.02, -0.046), (0, 0, 90), 0.95, M_parent=M_lg)

    # 3. Proud Spaced Bolted AMAP Flank Composite Slabs + Steep Tumblehome Shoulders + MUSS Soft-Kill Pods
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_fc, fcw, fch = _quad_frame(
                (0.31, 0.50, -1.30), (0.69, 0.40, -0.56),
                (0.69, 0.76, -0.56), (0.31, 0.55, -1.30),
                ref_inside=(0.0, 0.56, -0.25),
            )
            M_tu, tuw, tuh = _quad_frame(
                (0.69, 0.76, -0.56), (0.72, 0.78, 0.16),
                (0.48, 1.01,  0.16), (0.46, 0.98, -0.56),
                ref_inside=(0.0, 0.56, -0.10),
            )
            M_rb, rbw, rbh = _quad_frame(
                (0.72, 0.40, 0.16), (0.59, 0.42, 0.64),
                (0.59, 0.76, 0.64), (0.72, 0.78, 0.16),
                ref_inside=(0.0, 0.56, 0.35),
            )
        else:
            M_fc, fcw, fch = _quad_frame(
                (-0.69, 0.40, -0.56), (-0.31, 0.50, -1.30),
                (-0.31, 0.55, -1.30), (-0.69, 0.76, -0.56),
                ref_inside=(0.0, 0.56, -0.25),
            )
            M_tu, tuw, tuh = _quad_frame(
                (-0.72, 0.78,  0.16), (-0.69, 0.76, -0.56),
                (-0.46, 0.98, -0.56), (-0.48, 1.01,  0.16),
                ref_inside=(0.0, 0.56, -0.10),
            )
            M_rb, rbw, rbh = _quad_frame(
                (-0.59, 0.42, 0.64), (-0.72, 0.40, 0.16),
                (-0.72, 0.78, 0.16), (-0.59, 0.76, 0.64),
                ref_inside=(0.0, 0.56, 0.35),
            )
        # Forward cheek thick bolted AMAP cassette pair
        kb.plate(f"AMAP_FrontBack_{si}", crect_2d(fcw * 0.84, fch * 0.72, (0.04, 0.04, 0.03, 0.03)), 0.068,
                 "armor", "armor_panel", (0, 0, -0.024), (0, 0, 0), 0.008, 1, M_parent=M_fc)
        for ci, cu in enumerate([-fcw * 0.21, fcw * 0.21]):
            kb.plate(f"AMAP_FrontCass_{si}_{ci}", crect_2d(fcw * 0.35, fch * 0.54, (0.02, 0.02, 0.02, 0.02)), 0.044,
                     "armor_sub", "armor_hatch", (cu, 0, -0.068), (0, 0, 0), 0.006, 1, M_parent=M_fc)
            kb.cyl(f"AMAP_FPin_{si}_{ci}", 0.013, 0.015, 0.018, 6, "chrome", "plain_metal",
                   (cu, 0, -0.092), (90, 0, 0), 0.002, M_parent=M_fc)

        # Steep tumblehome stealth shoulder armor
        kb.plate(f"PumaShoulderPlate_{si}", crect_2d(tuw * 0.86, tuh * 0.76, (0.04, 0.04, 0.03, 0.03)), 0.044,
                 "armor_sub" if si == 1 else "armor", "weld_plate", (0, 0, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_tu)
        if si == 0:
            kb.decal("PumaUnit", "unit_08", (0.20, 0.12), (0, 0, -0.040), (0, 0, 0), M_parent=M_tu)

        # Proud spaced rear AMAP 3-cassette bolted array standing visibly off narrow hull (|x| <= 0.86!)
        kb.plate(f"AMAP_RearBack_{si}", crect_2d(rbw * 0.86, rbh * 0.80, (0.04, 0.04, 0.03, 0.03)), 0.068,
                 "armor", "armor_panel", (0, 0, -0.024), (0, 0, 0), 0.008, 1, M_parent=M_rb)
        for ci, cu in enumerate([-rbw * 0.27, 0.0, rbw * 0.27]):
            kb.plate(f"AMAP_RearCass_{si}_{ci}", crect_2d(rbw * 0.23, rbh * 0.64, (0.02, 0.02, 0.02, 0.02)), 0.042,
                     "armor_sub", "armor_hatch", (cu, 0, -0.066), (0, 0, 0), 0.005, 1, M_parent=M_rb)
            for py in [-0.08, 0.08]:
                kb.cyl(f"AMAP_RPin_{si}_{ci}_{int(py * 100)}", 0.011, 0.013, 0.016, 6, "chrome", "plain_metal",
                       (cu, py, -0.090), (90, 0, 0), 0.002, M_parent=M_rb)

        # Front-corner MUSS soft-kill active protection jammer/warning turret (seated cleanly into narrow ridge!)
        M_ms = g2b_mat((sx * 0.38, 0.97, -0.50), (0.0, sx * -24.0, 0.0))
        kb.cyl(f"MUSSPod_{si}", 0.076, 0.092, 0.15, 12, "gunmetal", "gear_collar",
               (0, 0.06, 0), (0, 0, 0), 0.005, M_parent=M_ms)
        _add_optic_lens(kb, f"MUSSLens_{si}", 0.030, (0, 0.08, -0.100), (90, 0, 0), "emit_cyan", M_parent=M_ms)
        kb.smoke_pod(f"PumaSmoke_{si}", (sx * 0.44, 1.07, -0.22), (-22, sx * -22.0, 0))
        _add_whip_antenna(kb, f"PumaWhip_{si}", (sx * 0.40, 0.99, -0.02), h=0.76, tilt_x=-7.0)

    # 4. Roof Left Panoramic PERI-RTWL CITV + Roof Right 3-Prism Armored Periscope Blister
    _add_citv_sight(kb, "PERI_CITV", (-0.18, 0.99, -0.24), head_slot="armor", lens_slot="emit_cyan")
    kb.plate("PeriBlister_R", crect_2d(0.30, 0.28, (0.04, 0.04, 0.04, 0.04)), 0.12, "armor_sub", "armor_hatch",
             (0.16, 1.02, -0.24), (90, 0, 0), 0.008, 1)
    for pi, (px, pyaw) in enumerate([(0.08, 12.0), (0.16, 0.0), (0.24, -12.0)]):
        _add_periscope(kb, f"PumaRoofPeri_{pi}", 0.084, 0.056, (px, 1.06, -0.39), (4, pyaw, 0), "glass")

    # 5. Flush HP-B1 Dorsal Pad & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 1.04, 0.48, w=0.68, d=0.40)
    _add_rear_gen_pad(kb, "HP_G1", 0.54, 0.90, w=0.68, h=0.44)

    kb.add_marker("SOCKET_arm_l", (-1.02, 0.60, 0.02))
    kb.add_marker("SOCKET_arm_r", ( 1.02, 0.60, 0.02))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.04, 0.48))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.54, 0.90))
    kb.seat_core_low(0.14, new_y_top=0.12)


# ==============================================================================
# 4. core_bmpt_terminator — BMPT-72 Ultra-Low Wide Predator Arrowhead + AGS-30 Sponsons
# ==============================================================================

def build_core_bmpt_terminator(kb: KitbashScene):
    """BMPT-72 Terminator Core: ultra-low wide predator T-72/BMPT arrowhead, bold AGS-30 sponsons, slat cages, Ramka."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.25)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"BmptStab_{si}", (sx * 0.30, 0.05, -0.22), (sx * 0.44, 0.26, -0.34), 0.022)

    # 1. Ultra-Low Wide Predator Arrowhead Hull Loft (razor nose + wide low 1.94m T-72/BMPT stance!)
    bmpt_secs = [
        (-1.24, _oct_ring(0.38, 0.54, 0.40, 0.36, 0.42, 0.54, 0.60)),   # Razor V-chevron prow tip!
        (-0.56, _oct_ring(1.42, 1.90, 1.32, 0.24, 0.38, 0.72, 0.90)),   # Wide low predator shoulders
        ( 0.16, _oct_ring(1.48, 1.96, 1.34, 0.24, 0.38, 0.74, 0.92)),   # Low broad urban combat hull
        ( 0.66, _oct_ring(1.10, 1.44, 1.06, 0.26, 0.40, 0.72, 0.88)),   # Tapered rear engine deck
        ( 0.90, _oct_ring(0.86, 1.08, 0.86, 0.30, 0.42, 0.68, 0.82)),   # Compact rear transom (<= 0.91)
    ]
    kb.loft("BMPTArrowHull", bmpt_secs, "armor_sub", "armor_slab", bevel_w=0.015, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Heavy Symmetrical HP-A1 Trunnions at (±1.14, 0.56, 0.06)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.94, 1.14, 0.56, 0.06)

    # 2. Low Sloped V-Glacis + 3 Central Kontakt-5 ERA + Driver Hood + Periscope
    M_cg, cgw, cgh = _quad_frame(
        (-0.20, 0.60, -1.24), ( 0.20, 0.60, -1.24),
        ( 0.66, 0.90, -0.56), (-0.66, 0.90, -0.56),
        ref_inside=(0.0, 0.54, -0.25),
    )
    kb.plate("BMPTGlacis", trap_2d(0.42, 1.24, cgh * 0.90, 0.05), 0.052, "armor", "armor_slab",
             (0, 0, -0.016), (0, 0, 0), 0.010, 1, M_parent=M_cg)
    for ki, kx in enumerate([-0.24, 0.0, 0.24]):
        kb.era_block(f"Kontakt5C_{ki}", (0.20, cgh * 0.38, 0.054), "armor_sub" if ki == 1 else "armor",
                     (kx, -cgh * 0.12, -0.060), (0, 0, 0), M_parent=M_cg)
    kb.box("DriverHood", (0.32, 0.11, 0.18), "armor_sub", "armor_hatch", (0, 0.84, -0.78), (0, 0, 0), 0.010, 1)
    _add_periscope(kb, "DriverPeri", 0.24, 0.074, (0, 0.85, -0.875), (4, 0, 0))
    kb.plate("BMPTNoseBumper", crect_2d(0.52, 0.18, (0.04, 0.04, 0.04, 0.04)), 0.064, "armor_sub", "armor_ribs",
             (0, 0.48, -1.26), (0, 0, 0), 0.008, 1)
    kb.box("BMPTHazard", (0.34, 0.032, 0.014), "hazard", "hazard", (0, 0.425, -1.295), (0, 0, 0), 0.002, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"BMPTLight_{si}", (sx * 0.24, 0.50, -1.30), (0, sx * -12.0, 0))
        kb.tow_shackle(f"BMPTTow_{si}", (sx * 0.20, 0.36, -1.25), (0, 0, 90), 0.98)

    # 3. Bold Outboard Twin Front-Shoulder AGS-30 30mm Automatic Grenade Sponsons + Snail Drums + Rear Slat Cages
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_fc, fcw, fch = _quad_frame(
                (0.27, 0.42, -1.24), (0.95, 0.38, -0.56),
                (0.95, 0.72, -0.56), (0.27, 0.54, -1.24),
                ref_inside=(0.0, 0.54, -0.15),
            )
            M_rb, rbw, rbh = _quad_frame(
                (0.98, 0.38, 0.16), (0.72, 0.40, 0.66),
                (0.72, 0.72, 0.66), (0.98, 0.74, 0.16),
                ref_inside=(0.0, 0.54, 0.35),
            )
        else:
            M_fc, fcw, fch = _quad_frame(
                (-0.95, 0.38, -0.56), (-0.27, 0.42, -1.24),
                (-0.27, 0.54, -1.24), (-0.95, 0.72, -0.56),
                ref_inside=(0.0, 0.54, -0.15),
            )
            M_rb, rbw, rbh = _quad_frame(
                (-0.72, 0.40, 0.66), (-0.98, 0.38, 0.16),
                (-0.98, 0.74, 0.16), (-0.72, 0.72, 0.66),
                ref_inside=(0.0, 0.54, 0.35),
            )
        kb.plate(f"BMPTCheekPlate_{si}", crect_2d(fcw * 0.84, fch * 0.78, (0.04, 0.04, 0.03, 0.03)), 0.046,
                 "armor", "armor_panel", (0, 0, -0.016), (0, 0, 0), 0.008, 1, M_parent=M_fc)
        kb.era_block(f"Kontakt5Side_{si}", (fcw * 0.52, fch * 0.56, 0.056), "armor_sub",
                     (-sx * 0.06, -0.02, -0.062), (0, 0, 0), M_parent=M_fc)

        # Prominent twin shoulder AGS-30 30mm grenade sponsons perched cleanly on wide predator cheek shelves!
        M_ags = g2b_mat((sx * 0.68, 0.84, -0.68), (0, 0, 0))
        kb.plate(f"AGSHouse_{si}", trap_2d(0.38, 0.28, 0.26, 0.04), 0.46, "armor", "armor_pocket",
                 (0, 0, 0), (0, 0, 0), 0.012, 1, M_parent=M_ags)
        kb.plate(f"AGSMantlet_{si}", trap_2d(0.32, 0.24, 0.19, 0.03), 0.068, "armor_sub", "armor_ribs",
                 (0, 0.0, -0.24), (14, 0, 0), 0.008, 1, M_parent=M_ags)
        kb.cyl(f"AGSShroud_{si}", 0.046, 0.052, 0.22, 14, "dark", "vent_mesh",
               (0, -0.01, -0.34), (90, 0, 0), 0.003, M_parent=M_ags)
        kb.cyl(f"AGSBarrel_{si}", 0.029, 0.031, 0.22, 12, "gunmetal", "plain_metal",
               (0, -0.01, -0.50), (90, 0, 0), 0.003, M_parent=M_ags)
        kb.barrel_bore(f"AGSMuzzle_{si}", 0.032, 0.021, (0, -0.01, -0.615), depth=0.055, rot_deg=(90, 0, 0), segs=12, M_parent=M_ags)
        kb.cyl(f"AGSDrum_{si}", 0.114, 0.114, 0.080, 16, "dark", "armor_hatch",
               (sx * 0.205, -0.01, -0.02), (0, 0, 90), 0.005, M_parent=M_ags)
        kb.bolt_ring(f"AGSDrumBolt_{si}", 0.076, 6, 0.009,
                     (sx * 0.248, -0.01, -0.02), (0, 0, sx * -90.0), M_parent=M_ags)

        # Tapered rear flanks: armor slab + spaced anti-RPG slat armor cage!
        kb.plate(f"BMPTRearArmor_{si}", crect_2d(rbw * 0.84, rbh * 0.78, (0.04, 0.04, 0.03, 0.03)), 0.040,
                 "armor_sub", "weld_plate", (0, 0, -0.012), (0, 0, 0), 0.008, 1, M_parent=M_rb)
        _add_slat_panel(kb, f"BMPTSlat_{si}", M_rb, rbw * 0.78, rbh * 0.68, n_bars=4)
        kb.smoke_pod(f"BMPTSmoke_{si}", (sx * 0.66, 0.94, -0.22), (-22, sx * -26.0, 0))
        _add_whip_antenna(kb, f"BMPTAnt_{si}", (sx * 0.56, 0.90, -0.02), h=0.78, tilt_x=-8.0)

    # 4. Prominent Raised Roof Left Ramka Stabilized Fire-Control Turret + Right Commander Cupola
    M_ramka = g2b_mat((-0.28, 0.90, -0.22), (0, 0, 0))
    kb.cyl("Ramka_Ped", 0.17, 0.20, 0.18, 16, "armor_sub", "gear_collar", (0, 0.07, 0), (0, 0, 0), 0.006, M_parent=M_ramka)
    kb.plate("Ramka_Body", crect_2d(0.34, 0.21, (0.04, 0.04, 0.03, 0.03)), 0.28, "armor", "armor_pocket",
             (0, 0.25, 0), (0, 0, 0), 0.012, 1, M_parent=M_ramka)
    _add_periscope(kb, "Ramka_Eye", 0.19, 0.10, (0, 0.25, -0.155), (0, 0, 0), glass_slot="emit_amber", M_parent=M_ramka)

    kb.cupola_hatch("CmdCupola", (0.30, 0.92, -0.24))
    kb.decal("BMPTUnit", "ord_12", (0.20, 0.12), (0.0, 0.926, -0.44), (-90, 0, 0))

    # 5. Flush HP-B1 Dorsal Pad & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 0.96, 0.48, w=0.80, d=0.44)
    _add_rear_gen_pad(kb, "HP_G1", 0.52, 0.92, w=0.76, h=0.42)

    kb.add_marker("SOCKET_arm_l", (-1.14, 0.56, 0.06))
    kb.add_marker("SOCKET_arm_r", ( 1.14, 0.56, 0.06))
    kb.add_marker("SOCKET_back",  ( 0.0,  0.96, 0.48))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.52, 0.92))
    kb.seat_core_low(0.14, new_y_top=0.12)


# ==============================================================================
# 5. core_merkava_mk4m — MRK-4M Knife-Edge Front-Engine Wedge + Arrowhead Turret
# ==============================================================================

def build_core_merkava_mk4m(kb: KitbashScene):
    """MRK-4M Merkava Mk.4M Core: 60deg knife-edge front-engine prow, flying-saucer arrowhead crown, 4x Trophy APS, ball-chain."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.24)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"MrkStab_{si}", (sx * 0.30, 0.05, -0.22), (sx * 0.44, 0.26, -0.36), 0.022)

    # 1. Lower Tier: Long Knife-Edge Front-Engine Cast Wedge Hull (distinct Israeli front-engine glacis!)
    hull_secs = [
        (-1.28, _oct_ring(0.76, 0.96, 0.78, 0.40, 0.46, 0.52, 0.58)),   # Razor front-engine knife-edge bow!
        (-0.62, _oct_ring(1.36, 1.84, 1.44, 0.24, 0.38, 0.74, 0.88)),   # Long 60deg sloped front-engine deck
        ( 0.16, _oct_ring(1.42, 1.92, 1.50, 0.24, 0.38, 0.78, 0.92)),   # Heavy Merkava hull beam
        ( 0.68, _oct_ring(1.16, 1.52, 1.24, 0.26, 0.40, 0.76, 0.90)),   # Tapered rear hull flanks
        ( 0.94, _oct_ring(0.94, 1.16, 0.98, 0.30, 0.42, 0.72, 0.84)),   # Rear crew door transom (<= 0.95)
    ]
    kb.loft("MerkavaEngineHull", hull_secs, "armor_sub", "armor_slab", bevel_w=0.016, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # 2. Upper Tier: Iconic Low-Slung Swept Arrowhead "Flying-Saucer" Turret Crown (razor 32deg swept cheeks!)
    crown_secs = [
        (-0.96, _oct_ring(0.32, 0.42, 0.28, 0.80, 0.86, 0.98, 1.04)),   # Razor turret mantlet arrowhead tip!
        (-0.46, _oct_ring(1.26, 1.62, 1.16, 0.82, 0.90, 1.06, 1.15)),   # Wide flying-saucer Merkava cheek flare
        ( 0.18, _oct_ring(1.32, 1.68, 1.22, 0.82, 0.92, 1.08, 1.17)),   # Main Trophy-equipped turret crown
        ( 0.66, _oct_ring(1.04, 1.30, 1.02, 0.84, 0.92, 1.06, 1.15)),   # Tapered rear turret bustle
        ( 0.86, _oct_ring(0.84, 1.04, 0.86, 0.86, 0.94, 1.04, 1.12)),   # Compact rear bustle rim (clear of HP-G1)
    ]
    kb.loft("MerkavaArrowCrown", crown_secs, "armor", "armor_slab", bevel_w=0.014, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Symmetrical HP-A1 Trunnions at (±1.14, 0.62, 0.04)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.94, 1.14, 0.62, 0.04)

    # 3. Front-Engine Long Sloped Glacis: Left Powerpack Louver Boss + Right Driver Periscope Blister
    M_gl, glw, glh = _quad_frame(
        (-0.39, 0.58, -1.28), ( 0.39, 0.58, -1.28),
        ( 0.72, 0.88, -0.62), (-0.72, 0.88, -0.62),
        ref_inside=(0.0, 0.52, -0.35),
    )
    kb.plate("FrontEngineGlacis", trap_2d(0.76, 1.36, glh * 0.90, 0.05), 0.052, "armor", "armor_slab",
             (0, 0, -0.016), (0, 0, 0), 0.010, 1, M_parent=M_gl)
    kb.box("EngineDeckBoss", (0.40, glh * 0.36, 0.042), "armor_sub", "armor_ribs",
           (-0.24, -glh * 0.22, -0.048), (0, 0, 0), 0.008, 1, M_parent=M_gl)
    kb.louver_bay("FrontEngineVent", 0.32, glh * 0.26, 0.028, (-0.24, -glh * 0.22, -0.082), (0, 0, 0),
                  blades=4, mesh_style=False, M_parent=M_gl)
    kb.box("MrkGlacisHaz", (0.24, 0.046, 0.014), "hazard", "hazard", (0.28, -glh * 0.28, -0.044), (0, 0, 0), 0.002, 1, M_parent=M_gl)

    # Right driver armored periscope hood on engine deck + central mantlet eye on arrowhead turret tip!
    kb.plate("DriverHood_R", crect_2d(0.32, 0.14, (0.03, 0.03, 0.03, 0.03)), 0.22, "armor_sub", "armor_hatch",
             (0.36, 0.84, -0.86), (0, 0, 0), 0.008, 1)
    _add_periscope(kb, "DriverPeri_R", 0.22, 0.072, (0.36, 0.87, -0.975), (4, 0, 0), "glass")
    kb.plate("MantletTipArmor", crect_2d(0.36, 0.16, (0.04, 0.04, 0.03, 0.03)), 0.068, "dark", "frame_cnc",
             (0, 0.92, -0.98), (0, 0, 0), 0.008, 1)
    _add_periscope(kb, "MantletEye", 0.24, 0.080, (0, 0.92, -1.035), (0, 0, 0), "glass")

    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"MrkLight_{si}", (sx * 0.48, 0.50, -1.24), (0, sx * -16.0, 0))
        kb.tow_shackle(f"MrkTow_{si}", (sx * 0.32, 0.36, -1.16), (0, 0, 90), 1.05)

    # 4. Swept Turret Arrowhead Cheeks + 4-Face Trophy APS Phased-Array Radars + Countermeasure Pods + Ball-Chain Curtains!
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_tc, tcw, tch = _quad_frame(
                (0.21, 0.86, -0.96), (0.81, 0.90, -0.46),
                (0.81, 1.06, -0.46), (0.21, 0.98, -0.96),
                ref_inside=(0.0, 0.94, -0.10),
            )
            M_tr_r, trw, trh = _quad_frame(
                (0.84, 0.92, 0.18), (0.65, 0.92, 0.66),
                (0.65, 1.06, 0.66), (0.84, 1.08, 0.18),
                ref_inside=(0.0, 0.94, 0.35),
            )
            M_hf, hfw, hfh = _quad_frame(
                (0.48, 0.46, -1.28), (0.92, 0.38, -0.62),
                (0.92, 0.74, -0.62), (0.48, 0.52, -1.28),
                ref_inside=(0.0, 0.56, -0.25),
            )
        else:
            M_tc, tcw, tch = _quad_frame(
                (-0.81, 0.90, -0.46), (-0.21, 0.86, -0.96),
                (-0.21, 0.98, -0.96), (-0.81, 1.06, -0.46),
                ref_inside=(0.0, 0.94, -0.10),
            )
            M_tr_r, trw, trh = _quad_frame(
                (-0.65, 0.92, 0.66), (-0.84, 0.92, 0.18),
                (-0.84, 1.08, 0.18), (-0.65, 1.06, 0.66),
                ref_inside=(0.0, 0.94, 0.35),
            )
            M_hf, hfw, hfh = _quad_frame(
                (-0.92, 0.38, -0.62), (-0.48, 0.46, -1.28),
                (-0.48, 0.52, -1.28), (-0.92, 0.74, -0.62),
                ref_inside=(0.0, 0.56, -0.25),
            )
        # Forward turret cheek armor + front Trophy APS phased-array radar panel
        kb.plate(f"ArrowCheekPlate_{si}", crect_2d(tcw * 0.84, tch * 0.82, (0.03, 0.03, 0.03, 0.03)), 0.044,
                 "armor_sub", "armor_panel", (0, 0, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_tc)
        kb.box(f"TrophyFrontBack_{si}", (0.24, 0.18, 0.042), "dark", "frame_cnc",
               (sx * 0.12, 0.0, -0.048), (0, 0, 0), 0.005, 1, M_parent=M_tc)
        kb.plate(f"TrophyFrontFace_{si}", crect_2d(0.20, 0.14, (0.02, 0.02, 0.02, 0.02)), 0.018,
                 "accent", "armor_pocket", (sx * 0.12, 0.0, -0.074), (0, 0, 0), 0.003, 1, M_parent=M_tc)

        # Rear turret flank Trophy APS radar panel (4 Trophy faces total!)
        kb.box(f"TrophyRearBack_{si}", (0.24, 0.16, 0.042), "dark", "frame_cnc",
               (0, 0, -0.020), (0, 0, 0), 0.005, 1, M_parent=M_tr_r)
        kb.plate(f"TrophyRearFace_{si}", crect_2d(0.20, 0.12, (0.02, 0.02, 0.02, 0.02)), 0.018,
                 "accent", "armor_pocket", (0, 0, -0.046), (0, 0, 0), 0.003, 1, M_parent=M_tr_r)

        # Trophy active countermeasure launcher pod on mid-turret crown cheek (|x| <= 0.96 -> clear of arms!)
        kb.box(f"TrophyLnch_{si}", (0.18, 0.18, 0.28), "gunmetal", "armor_pocket",
               (sx * 0.84, 1.04, -0.14), (0, 0, 0), 0.010, 1)
        kb.cyl(f"TrophyDrum_{si}", 0.052, 0.052, 0.22, 12, "dark", "gear_collar",
               (sx * 0.84, 1.14, -0.14), (90, 0, 0), 0.004)

        # Lower front hull cheek modular composite skirt
        kb.plate(f"HullCheekSkirt_{si}", crect_2d(hfw * 0.84, hfh * 0.76, (0.04, 0.04, 0.03, 0.03)), 0.050,
                 "armor", "armor_ribs", (0, 0, -0.016), (0, 0, 0), 0.008, 1, M_parent=M_hf)
        if si == 0:
            kb.decal("MrkUnit", "unit_17", (0.20, 0.12), (0, 0, -0.044), (0, 0, 0), M_parent=M_hf)

        # Signature Merkava anti-RPG rear hanging iron ball-and-chain curtain (seated cleanly on bustle overhang!)
        kb.box(f"ChainBar_{si}", (0.34, 0.046, 0.068), "gunmetal", "bolt_flange",
               (sx * 0.62, 0.88, 0.82), (0, 0, 0), 0.005, 1)
        for ci, cx_off in enumerate([-0.12, -0.04, 0.04, 0.12]):
            cx = sx * 0.62 + cx_off
            kb.cyl(f"ChainRod_{si}_{ci}", 0.011, 0.011, 0.22, 6, "dark", "braid_hose",
                   (cx, 0.76, 0.83), (0, 0, 0), 0.002)
            kb.lathe(f"ChainBall_{si}_{ci}",
                     [(0.0, -0.032), (0.024, -0.020), (0.032, 0.0), (0.024, 0.020), (0.0, 0.032)],
                     8, "gunmetal", "plain_metal", (cx, 0.64, 0.83))

        kb.smoke_pod(f"MrkSmoke_{si}", (sx * 0.62, 1.21, -0.38), (-20, sx * -26.0, 0))
        _add_whip_antenna(kb, f"MrkWhip_{si}", (sx * 0.54, 1.15, -0.02), h=0.80, tilt_x=-8.0)

    # 5. Roof Commander Cupola & Right Panoramic CITV (forward of z=0.05 -> clear of HP-B1!)
    kb.cupola_hatch("CmdCupola_L", (-0.30, 1.16, -0.22))
    _add_citv_sight(kb, "CITV_R", (0.30, 1.14, -0.24), head_slot="armor_sub", lens_slot="emit_cyan")

    # 6. Flush HP-B1 Bustle Pad & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 1.18, 0.50, w=0.80, d=0.44)
    _add_rear_gen_pad(kb, "HP_G1", 0.56, 0.96, w=0.76, h=0.46)

    kb.add_marker("SOCKET_arm_l", (-1.14, 0.62, 0.04))
    kb.add_marker("SOCKET_arm_r", ( 1.14, 0.62, 0.04))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.18, 0.50))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.56, 0.96))
    kb.seat_core_low(0.14, new_y_top=0.12)
