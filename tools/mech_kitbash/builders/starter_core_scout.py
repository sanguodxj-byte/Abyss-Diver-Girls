"""SC-1 (core_scout) Sculpted Non-Boxy Recon Core — V-Tapered Prow & Sloped Facets (v2.0 Zero-Clip)."""
import math
from mathutils import Vector, Matrix
from kitbash_lib import KitbashScene, C_G2B, C_B2G, g2b_mat, crect_2d, trap_2d


def _oct_ring(w_bot: float, w_mid: float, w_top: float,
              y_bot: float, y_mid_lo: float, y_mid_hi: float, y_top: float):
    """8-point chamfered polygonal cross-section in Godot (gx, gy) for sculpted loft hulls."""
    return [
        (-w_bot * 0.5, y_bot),
        ( w_bot * 0.5, y_bot),
        ( w_mid * 0.5, y_mid_lo),
        ( w_mid * 0.5, y_mid_hi),
        ( w_top * 0.5, y_top),
        (-w_top * 0.5, y_top),
        (-w_mid * 0.5, y_mid_hi),
        (-w_mid * 0.5, y_mid_lo),
    ]


def _face_frame(center_g, normal_out_g, up_hint_g=(0.0, 1.0, 0.0)) -> Matrix:
    """Blender M_parent with Godot local -Z = outward normal, +Y = up, +X = right (det=+1)."""
    n_out = Vector(normal_out_g).normalized()
    z_g = -n_out
    up = Vector(up_hint_g).normalized()
    if abs(up.dot(z_g)) > 0.96:
        up = Vector((0.0, 0.0, -1.0))
    x_g = up.cross(z_g).normalized()
    y_g = z_g.cross(x_g).normalized()
    c = Vector(center_g)
    M_g = Matrix((
        (x_g.x, y_g.x, z_g.x, c.x),
        (x_g.y, y_g.y, z_g.y, c.y),
        (x_g.z, y_g.z, z_g.z, c.z),
        (0.0,   0.0,   0.0,   1.0),
    ))
    return C_G2B @ M_g @ C_B2G


def _quad_frame(p00, p10, p11, p01, ref_inside=(0.0, 0.30, 0.0)):
    """Return (M_face, w, h) flush on arbitrary sloped hull quad (p00=BL, p10=BR, p11=TR, p01=TL)."""
    a, b, c, d = Vector(p00), Vector(p10), Vector(p11), Vector(p01)
    ctr = (a + b + c + d) * 0.25
    u_vec = ((b - a) + (c - d)) * 0.5
    v_vec = ((d - a) + (c - b)) * 0.5
    n = u_vec.cross(v_vec).normalized()
    if n.dot(ctr - Vector(ref_inside)) < 0.0:
        n = -n
    return _face_frame(ctr, n, v_vec), u_vec.length, v_vec.length


def build_core_scout(kb: KitbashScene):
    """SC-1 Recon Core: narrow V-tapered waist, swept faceted stealth prow, canted shoulder cowls, tapered tail."""
    # 1. Unified Compact HP-C1 Slewing Ring + Tight Waist Actuators
    kb.waist_collar_core("HP_C1_Core", y_top=0.12)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.20, 0.022, -0.15), (sx * 0.32, 0.165, -0.26), 0.016)

    # 2. Primary Sculpted Non-Boxy Loft Hull (5 Z-sections: pointed prow -> V-shoulders -> tapered tail)
    # Every wall is beveled & angled (V-waist belly bevel + 24deg upper tumblehome + planform diamond taper!)
    sections = [
        (-0.88, _oct_ring(0.30, 0.46, 0.34, 0.16, 0.21, 0.31, 0.37)),   # Narrow armored recon beak prow
        (-0.52, _oct_ring(0.52, 0.90, 0.66, 0.11, 0.19, 0.40, 0.54)),   # Swept forward cheek flare
        (-0.04, _oct_ring(0.58, 1.12, 0.78, 0.10, 0.21, 0.44, 0.60)),   # Broad muscular shoulders + tight V-waist!
        ( 0.44, _oct_ring(0.50, 0.90, 0.66, 0.11, 0.20, 0.40, 0.53)),   # Stepped dorsal backpack bay & rear taper
        ( 0.71, _oct_ring(0.42, 0.68, 0.52, 0.12, 0.20, 0.36, 0.47)),   # Compact tapered tail transom (flush <= 0.72)
    ]
    kb.loft("SculptedReconHull", sections, "armor_sub", "armor_slab", bevel_w=0.014, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Geared HP-A1 Arm Bulkheads seated on the broad shoulder cheeks
    kb.arm_bulkhead("ArmMount", 0.66, 0.30, 0.0)

    # 3. Sculpted Swept Upper Glacis Armor Hood (flush on forward roof slope z=-0.88..-0.52)
    M_glacis, gw, gh = _quad_frame(
        (-0.17, 0.37, -0.88), ( 0.17, 0.37, -0.88),
        ( 0.33, 0.54, -0.52), (-0.33, 0.54, -0.52),
    )
    kb.plate("UpperGlacisShell", trap_2d(0.42, 0.68, gh * 0.94, 0.05), 0.052, "armor", "armor_slab",
             (0, 0.0, -0.018), (0, 0, 0), 0.012, 1, M_parent=M_glacis)
    kb.plate("GlacisOxideSpine", trap_2d(0.14, 0.22, gh * 0.78, 0.025), 0.024, "armor_oxide", "armor_ribs",
             (0, 0.0, -0.048), (0, 0, 0), 0.005, 1, M_parent=M_glacis)
    kb.decal("GlacisUnit", "unit_08", (0.17, 0.10), (-0.17, 0.02, -0.048), (0, 0, 0), M_parent=M_glacis)
    kb.box("GlacisHazard", (0.14, 0.036, 0.010), "hazard", "hazard", (0.17, -0.06, -0.046), (0, 0, 0), 0.002, 1, M_parent=M_glacis)

    # 4. Swept Angled Nose Cheek Armor Plates (left & right 30deg arrowhead cheeks!)
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_ch, cw, ch = _quad_frame(
                (0.23, 0.21, -0.88), (0.45, 0.19, -0.52),
                (0.45, 0.40, -0.52), (0.23, 0.31, -0.88),
            )
        else:
            M_ch, cw, ch = _quad_frame(
                (-0.45, 0.19, -0.52), (-0.23, 0.21, -0.88),
                (-0.23, 0.31, -0.88), (-0.45, 0.40, -0.52),
            )
        kb.plate(f"NoseCheekPlate_{si}", crect_2d(cw * 0.86, ch * 0.76, (0.04, 0.04, 0.03, 0.03)), 0.044,
                 "armor_sub", "armor_hatch", (0, 0.0, -0.014), (0, 0, 0), 0.010, 1, M_parent=M_ch)
        kb.box(f"CheekIntake_{si}", (cw * 0.42, ch * 0.26, 0.022), "dark", "vent_mesh",
               (0, -ch * 0.04, -0.038), (0, 0, 0), 0.004, 1, M_parent=M_ch)

    # 5. Recessed Armored Panoramic Recon Visor on the Beak Prow + Chin EO/IR Gimbal
    kb.plate("VisorBeakPod", crect_2d(0.46, 0.155, (0.04, 0.04, 0.03, 0.03)), 0.090, "dark", "frame_cnc",
             (0, 0.265, -0.895), (0, 0, 0), 0.008, 1)
    kb.box("VisorRecess", (0.38, 0.088, 0.020), "bore", "plain_metal", (0, 0.265, -0.938), (0, 0, 0), 0.002, 1)
    kb.plate("VisorBrow", trap_2d(0.48, 0.40, 0.036, 0.010), 0.120, "armor", "armor_ribs",
             (0, 0.345, -0.920), (8, 0, 0), 0.006, 1)
    for pi, (px, pw, pip) in enumerate([(-0.12, 0.105, None), (0.0, 0.115, "emit_cyan"), (0.12, 0.105, "emit_amber")]):
        kb.box(f"VisorGlass_{pi}", (pw, 0.064, 0.014), "glass", "plain_metal", (px, 0.265, -0.946), (0, 0, 0), 0.002, 1)
        kb.cyl(f"VisorLens_{pi}", 0.026, 0.028, 0.012, 14, "gunmetal", "plain_metal", (px, 0.265, -0.956), (90, 0, 0), 0.002, hollow_r=0.019)
        if pip:
            kb.cyl(f"VisorPip_{pi}", 0.007, 0.007, 0.010, 10, pip, "plain_metal", (px, 0.265, -0.954), (90, 0, 0), 0.001)
    kb.grab_rail("VisorGuardBar", 0.38, 0.042, (0, 0.215, -0.935), (0, 0, 0), 0.007)

    # Chin EO/IR 3-lens gimbal tucked beneath the sloped lower beak + caged headlights
    kb.eoir_gimbal("ChinEOIR", (0, 0.075, -0.78))
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.24, 0.155, -0.845), (0, sx * -18.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.14, 0.115, -0.805))

    # 6. Broad Canted Shoulder Intake Cowls & Swept Dorsal Armor Ridge (24deg tumblehome!)
    for si, sx in enumerate([-1.0, 1.0]):
        # Upper sloped shoulder tumblehome armor shell (strictly inboard of x=±0.64!)
        M_sh = _face_frame((sx * 0.46, 0.515, -0.18), (sx * 0.60, 0.80, -0.05))
        kb.plate(f"ShoulderCowl_{si}", crect_2d(0.56, 0.24, (0.05, 0.05, 0.03, 0.03)), 0.056,
                 "armor_oxide" if si == 1 else "armor", "armor_panel", (0, 0, -0.016), (0, 0, 0), 0.010, 1, M_parent=M_sh)
        kb.box(f"ShoulderIntake_{si}", (0.14, 0.095, 0.22), "armor_sub", "armor_ribs",
               (sx * 0.45, 0.605, -0.32), (0, sx * -8.0, sx * -22.0), 0.010, 1)
        kb.cyl(f"IntakeOptic_{si}", 0.036, 0.038, 0.022, 14, "gunmetal", "gear_collar",
               (sx * 0.435, 0.605, -0.438), (90, 0, 0), 0.003, hollow_r=0.026)
        kb.cyl(f"IntakeGlass_{si}", 0.025, 0.025, 0.014, 14, "glass", "plain_metal",
               (sx * 0.435, 0.605, -0.436), (90, 0, 0), 0.002)
        kb.smoke_pod(f"SmokeRack_{si}", (sx * 0.43, 0.665, -0.42), (-22, sx * -16.0, 0))

        # Tapered Rear Flank Armor Shell (angled inward from z=+0.08 to z=+0.66 -> ZERO box wall!)
        if sx > 0:
            M_rf, rw, rh = _quad_frame(
                (0.54, 0.21, 0.08), (0.37, 0.20, 0.66),
                (0.37, 0.37, 0.66), (0.54, 0.42, 0.08),
            )
        else:
            M_rf, rw, rh = _quad_frame(
                (-0.37, 0.20, 0.66), (-0.54, 0.21, 0.08),
                (-0.54, 0.42, 0.08), (-0.37, 0.37, 0.66),
            )
        kb.plate(f"RearFlankShell_{si}", crect_2d(rw * 0.78, rh * 0.76, (0.04, 0.04, 0.03, 0.03)), 0.040,
                 "armor" if si == 0 else "armor_sub", "weld_plate", (0.04 * sx, 0.0, -0.012), (0, 0, 0), 0.009, 1, M_parent=M_rf)
        kb.louver_bay(f"RearVent_{si}", rw * 0.36, rh * 0.42, 0.024, (0.07 * sx, 0.0, -0.041), (0, 0, 0),
                      blades=4, mesh_style=(si == 1), M_parent=M_rf)
        kb.decal(f"FlankTri_{si}", "hazard_tri", (0.085, 0.085), (-0.15 * sx, 0.0, -0.0365), (0, 0, 0), M_parent=M_rf)

    # 7. Forward Crown Deck (strictly z <= +0.18 -> clear of back_cargo!) + Stepped HP-B1 Dock
    kb.plate("CrownArmor", crect_2d(0.68, 0.48, (0.09, 0.09, 0.05, 0.05)), 0.044, "armor", "armor_panel",
             (0, 0.610, -0.14), (-90, 0, 0), 0.009, 1)
    kb.cupola_hatch("CmdCupola", (-0.14, 0.634, -0.14))
    kb.recon_mast("ReconMast", (0.20, 0.634, -0.10))

    # Recessed HP-B1 Dorsal Bay (y <= 0.550 so back_cargo at y=0.560 docks flush!)
    kb.box("HP_B1_Bay", (0.64, 0.038, 0.36), "gunmetal", "bolt_flange", (0, 0.530, 0.41), (0, 0, 0), 0.006, 1)

    # Twin angled armored exhaust stacks tucked on tapered tail shoulders
    for si, sx in enumerate([-0.34, 0.34]):
        kb.cyl(f"ExhPipe_{si}", 0.032, 0.036, 0.20, 12, "dark", "plain_metal",
               (sx, 0.45, 0.64), (24, sx * 12.0, 0), 0.004, hollow_r=0.022)
        kb.cyl(f"ExhCollar_{si}", 0.044, 0.044, 0.024, 12, "gunmetal", "bolt_flange",
               (sx, 0.43, 0.63), (24, sx * 12.0, 0), 0.003)

    # Rear HP-G1 recessed bulkhead docking frame (flush z_max = 0.718 -> gen_cell at z=0.725 docks 100% flush!)
    kb.plate("RearGenDock", crect_2d(0.56, 0.32, (0.05, 0.05, 0.04, 0.04)), 0.042, "gunmetal", "bolt_flange",
             (0, 0.26, 0.698), (0, 0, 0), 0.006, 1)
    kb.box("RearHazardBar", (0.38, 0.024, 0.012), "hazard", "hazard", (0, 0.455, 0.688), (0, 0, 0), 0.002, 1)

    # Exact starter sockets (100% drop-in compatible with back_cargo, gen_cell, arm_mg, arm_gatling)
    kb.add_marker("SOCKET_arm_l", (-0.66, 0.30, 0.0))
    kb.add_marker("SOCKET_arm_r", (0.66, 0.30, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  0.56, 0.405))
    kb.add_marker("SOCKET_gen",   (0.0,  0.12, 0.725))
