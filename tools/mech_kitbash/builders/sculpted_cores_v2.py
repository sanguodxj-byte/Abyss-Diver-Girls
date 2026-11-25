"""Sculpted Non-Boxy Military Mecha Cores v2.0 — 5 Representative Archetypes (Zero-Clip).

Replaces uniform shipping-container box hulls with true lofted polygonal military mecha silhouettes:
  1. core_assault      — AS-2 Muscular 2-Tier V-Torso Assault Chest (narrow waist + broad angled pectorals + head)
  2. core_m1a2_sepv3   — SEP-V3 Low-Slung Pentagonal Arrowhead Abrams MBT Turret (38deg DU cheeks + bustle)
  3. core_fortress     — FT-5 Double-Beveled Octagonal Tumblehome Armored Citadel (22deg 4-wall inward slope)
  4. core_t90m_proryv  — PRV-90 Ultra-Low Hexagonal Arrowhead Turret (6x V-chevron Relikt ERA + Shtora)
  5. core_fennek_recon — FNK-4 Razor-Chined Stealth Diamond Recon Pod (32deg stealth facets + 3-pane canopy)

All modules comply with MECH_MODELING_STANDARD v1.0 & v1.5 Zero-Clip:
  - Unified HP-C1 slewing collar (r=0.360m, y_bot=-0.005m)
  - Symmetrical HP-A1 geared shoulder bulkheads & exact SOCKET_* markers
  - Analytical surface-frame mounting -> 0/0/0/0 clip_audit & 0 cross-module clashes
"""
import math
from mathutils import Vector, Matrix
from kitbash_lib import KitbashScene, C_G2B, C_B2G, g2b_mat, crect_2d, trap_2d


# ==============================================================================
# ANALYTICAL SCULPTING & SURFACE-MOUNTING HELPERS
# ==============================================================================

def _oct_ring(w_bot: float, w_mid: float, w_top: float,
              y_bot: float, y_mid_lo: float, y_mid_hi: float, y_top: float):
    """8-point chamfered polygonal cross-section in Godot (gx, gy) for non-boxy loft hulls."""
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
    """Right-handed Blender M_parent: Godot local -Z = outward normal, +Y = up, +X = right."""
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


def _quad_frame(p00, p10, p11, p01, ref_inside=(0.0, 0.55, 0.0)):
    """Compute exact (M_face, w, h) on any sloped lofted quad panel (p00=BL, p10=BR, p11=TR, p01=TL)."""
    a, b, c, d = Vector(p00), Vector(p10), Vector(p11), Vector(p01)
    ctr = (a + b + c + d) * 0.25
    u_vec = ((b - a) + (c - d)) * 0.5
    v_vec = ((d - a) + (c - b)) * 0.5
    n = u_vec.cross(v_vec).normalized()
    if n.dot(ctr - Vector(ref_inside)) < 0.0:
        n = -n
    return _face_frame(ctr, n, v_vec), u_vec.length, v_vec.length


def _add_periscope(kb: KitbashScene, prefix: str, w: float, h: float, pos, rot_deg=(0, 0, 0),
                   glass_slot: str = "glass", M_parent=None):
    M = g2b_mat(pos, rot_deg)
    if M_parent is not None:
        M = M_parent @ M
    kb.box(f"{prefix}_hs", (w, h, 0.074), "dark", "frame_cnc", (0, 0, 0.020), (0, 0, 0), 0.006, 1, M_parent=M)
    kb.box(f"{prefix}_br", (w + 0.016, 0.020, 0.096), "gunmetal", "bolt_flange",
           (0, h * 0.5 + 0.006, -0.012), (10, 0, 0), 0.004, 1, M_parent=M)
    kb.box(f"{prefix}_cv", (w * 0.80, h * 0.54, 0.020), "bore", "plain_metal", (0, -0.003, -0.020), (0, 0, 0), 0.002, 1, M_parent=M)
    kb.box(f"{prefix}_gl", (w * 0.72, h * 0.42, 0.014), glass_slot, "plain_metal", (0, -0.003, -0.032), (0, 0, 0), 0.002, 1, M_parent=M)


def _add_arm_trunnion_bridge(kb: KitbashScene, prefix: str, x_inner: float, x_socket: float, y: float, z: float = 0.0):
    """Armored conical/stepped trunnion bridge connecting sculpted tapered flanks out to HP-A1 socket (zero coplanar end-caps)."""
    x_outer = x_socket - 0.095
    span = max(0.06, x_outer - x_inner + 0.04)
    xm = (x_inner - 0.02 + x_outer + 0.02) * 0.5
    for si, sx in enumerate([-1.0, 1.0]):
        kb.cyl(f"{prefix}_arm{si}", 0.20, 0.23, span, 16, "dark", "frame_cnc",
               (sx * xm, y, z), (0, 0, 90), 0.010, u_rep=2.0)
    kb.arm_bulkhead(prefix, x_socket, y, z)


def _add_dorsal_back_pad(kb: KitbashScene, prefix: str, y_socket: float, z_socket: float, w: float = 0.74, d: float = 0.42):
    """Low-profile HP-B1 dorsal docking rail pad strictly <= y_socket - 0.006m (zero backpack clash!)."""
    kb.box(f"{prefix}_pad", (w, 0.036, d), "gunmetal", "bolt_flange", (0, y_socket - 0.026, z_socket), (0, 0, 0), 0.006, 1)
    for ri, rx in enumerate([-w * 0.36, w * 0.36]):
        kb.box(f"{prefix}_rl{ri}", (0.058, 0.020, d * 0.86), "dark", "armor_ribs",
               (rx, y_socket - 0.016, z_socket), (0, 0, 0), 0.004, 1)
    kb.box(f"{prefix}_hz", (w * 0.56, 0.012, 0.036), "hazard", "hazard",
           (0, y_socket - 0.010, z_socket + d * 0.44), (0, 0, 0), 0.002, 1)


def _add_rear_gen_pad(kb: KitbashScene, prefix: str, y_socket: float, z_socket: float, w: float = 0.72, h: float = 0.44):
    """Flush HP-G1 rear generator docking collar strictly <= z_socket - 0.004m (zero generator clash!)."""
    zf = z_socket - 0.026
    kb.plate(f"{prefix}_frm", crect_2d(w, h, (0.06, 0.06, 0.05, 0.05)), 0.042, "gunmetal", "bolt_flange",
             (0, y_socket, zf), (0, 0, 0), 0.006, 1)
    kb.box(f"{prefix}_rec", (w - 0.16, h - 0.14, 0.016), "bore", "plain_metal", (0, y_socket, z_socket - 0.010), (0, 0, 0), 0.002, 1)
    for xi, sx in enumerate([-1.0, 1.0]):
        kb.cyl(f"{prefix}_bus{xi}", 0.018, 0.018, h * 0.48, 8, "copper", "plain_metal",
               (sx * (w * 0.34), y_socket, z_socket - 0.014), (0, 0, 0), 0.002)


def _add_whip_antenna(kb: KitbashScene, prefix: str, pos, h: float = 0.68, tilt_x: float = -8.0):
    M = g2b_mat(pos, (tilt_x, 0, 0))
    kb.cyl(f"{prefix}_bs", 0.022, 0.028, 0.064, 10, "dark", "gear_collar", (0, 0.026, 0), (0, 0, 0), 0.003, M_parent=M)
    kb.cyl(f"{prefix}_sp", 0.015, 0.019, 0.070, 8, "gunmetal", "dust_boot", (0, 0.086, 0), (0, 0, 0), 0.002, M_parent=M)
    kb.cyl(f"{prefix}_rd", 0.004, 0.009, h, 6, "dark", "plain_metal", (0, 0.11 + h * 0.5, 0), (0, 0, 0), 0.001, M_parent=M)


def _add_slat_panel(kb: KitbashScene, prefix: str, M_face: Matrix, w: float, h: float, n_bars: int = 5):
    """Spaced anti-HEAT slat armor bars mounted cleanly on any sloped hull face via M_face."""
    z_bar = -0.056
    for bi in range(n_bars):
        u = -w * 0.44 + w * 0.88 * (bi / max(1, n_bars - 1))
        kb.box(f"{prefix}_vb{bi}", (0.020, h * 0.88, 0.022), "gunmetal", "plain_metal",
               (u, 0, z_bar), (0, 0, 0), 0.003, 1, M_parent=M_face)
    for ri, ry in enumerate([-h * 0.36, h * 0.36]):
        kb.box(f"{prefix}_hr{ri}", (w * 0.94, 0.024, 0.024), "gunmetal", "bolt_flange",
               (0, ry, z_bar), (0, 0, 0), 0.003, 1, M_parent=M_face)
        for si, su in enumerate([-w * 0.38, w * 0.38]):
            kb.box(f"{prefix}_st{ri}_{si}", (0.026, 0.026, 0.068), "dark", "frame_cnc",
                   (su, ry, -0.024), (0, 0, 0), 0.003, 1, M_parent=M_face)


# ==============================================================================
# 1. core_assault — AS-2 Muscular 2-Tier V-Torso Armored Mech Chest
# ==============================================================================

def build_core_assault(kb: KitbashScene):
    """AS-2 Vanguard Assault Core: distinct narrow armored abdomen + broad V-pectoral chest + swept cowls + head."""
    # 1. HP-C1 Slewing Ring + Distinct Tapered Armored Abdomen/Waist (gives athletic V-taper mech silhouette!)
    kb.waist_collar_core("HP_C1_Core", y_top=0.14)
    abd_secs = [
        (-0.40, _oct_ring(0.50, 0.68, 0.64, 0.13, 0.20, 0.34, 0.42)),
        ( 0.02, _oct_ring(0.56, 0.80, 0.86, 0.12, 0.20, 0.36, 0.44)),
        ( 0.42, _oct_ring(0.50, 0.68, 0.68, 0.13, 0.20, 0.34, 0.42)),
    ]
    kb.loft("ArmoredAbdomen", abd_secs, "dark", "frame_cnc", bevel_w=0.012, bevel_seg=1, tile_u=2.0)
    # Central armored belly belt plate + twin abdominal hydraulic pistons bridging waist to pectoral chest
    kb.plate("AbdomenShield", trap_2d(0.42, 0.56, 0.26, 0.04), 0.060, "armor_sub", "armor_ribs",
             (0, 0.27, -0.415), (14, 0, 0), 0.010, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistPiston_{si}", (sx * 0.30, 0.04, -0.18), (sx * 0.46, 0.40, -0.26), 0.022)
        kb.hydraulic(f"WaistPistonR_{si}", (sx * 0.30, 0.04, 0.20), (sx * 0.42, 0.38, 0.28), 0.020)

    # 2. Broad Muscular Upper V-Chest Loft (narrow prow -> broad heroic shoulders -> tapered spine!)
    chest_secs = [
        (-0.88, _oct_ring(0.38, 0.56, 0.42, 0.46, 0.53, 0.67, 0.76)),   # Forward-thrust armored cockpit prow!
        (-0.48, _oct_ring(0.86, 1.38, 1.02, 0.36, 0.48, 0.78, 0.96)),   # Swept V-pectoral chest flare
        ( 0.02, _oct_ring(0.96, 1.50, 1.10, 0.34, 0.48, 0.80, 0.98)),   # Broadest heroic shoulder beam
        ( 0.42, _oct_ring(0.80, 1.16, 0.90, 0.36, 0.48, 0.78, 0.96)),   # Tapered rear back
        ( 0.64, _oct_ring(0.66, 0.90, 0.72, 0.38, 0.48, 0.72, 0.86)),   # Compact rear spine transom (<= 0.65)
    ]
    kb.loft("SculptedVChest", chest_secs, "armor_sub", "armor_slab", bevel_w=0.016, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Armored HP-A1 Trunnions at (±0.82, 0.60, 0.0)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.72, 0.82, 0.60, 0.0)

    # 3. Sculpted Central Cockpit Prow + Split Canted Pectoral Armor Plates (flush on 36deg chest facets!)
    M_prow_top, pw, ph = _quad_frame(
        (-0.21, 0.76, -0.88), ( 0.21, 0.76, -0.88),
        ( 0.51, 0.96, -0.48), (-0.51, 0.96, -0.48),
        ref_inside=(0.0, 0.62, -0.20),
    )
    kb.plate("ChestUpperGlacis", trap_2d(0.46, 0.96, ph * 0.90, 0.05), 0.062, "armor", "armor_slab",
             (0, 0, -0.020), (0, 0, 0), 0.012, 1, M_parent=M_prow_top)
    kb.plate("ChestOxideCrest", trap_2d(0.18, 0.30, ph * 0.76, 0.03), 0.026, "armor_oxide", "armor_ribs",
             (0, 0, -0.054), (0, 0, 0), 0.005, 1, M_parent=M_prow_top)
    kb.decal("ChestUnit", "unit_17", (0.20, 0.12), (-0.23, 0.0, -0.054), (0, 0, 0), M_parent=M_prow_top)

    # Forward cockpit beak armored visor + brow + lower chin guard
    kb.plate("CockpitVisorPod", crect_2d(0.52, 0.19, (0.05, 0.05, 0.04, 0.04)), 0.095, "dark", "frame_cnc",
             (0, 0.60, -0.90), (0, 0, 0), 0.009, 1)
    kb.box("CockpitRecess", (0.42, 0.095, 0.020), "bore", "plain_metal", (0, 0.605, -0.946), (0, 0, 0), 0.002, 1)
    kb.plate("CockpitBrow", trap_2d(0.54, 0.44, 0.042, 0.012), 0.13, "armor", "armor_panel",
             (0, 0.70, -0.925), (10, 0, 0), 0.007, 1)
    for pi, (px, pw2, pip) in enumerate([(-0.135, 0.11, None), (0.0, 0.12, "emit_cyan"), (0.135, 0.11, "emit_amber")]):
        kb.box(f"CockpitGlass_{pi}", (pw2, 0.068, 0.014), "glass", "plain_metal", (px, 0.605, -0.954), (0, 0, 0), 0.002, 1)
        if pip:
            kb.cyl(f"CockpitPip_{pi}", 0.009, 0.009, 0.010, 10, pip, "plain_metal", (px, 0.605, -0.961), (90, 0, 0), 0.001)
    kb.plate("ChestChinPlate", trap_2d(0.36, 0.50, 0.18, 0.03), 0.054, "armor_sub", "armor_pocket",
             (0, 0.445, -0.82), (-24, 0, 0), 0.009, 1)
    kb.box("ChinHazard", (0.30, 0.038, 0.014), "hazard", "hazard", (0, 0.445, -0.854), (-24, 0, 0), 0.002, 1)

    # Split Left & Right 38deg Pectoral Cheek Armor Slabs + Canted ERA Blocks + Headlights
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_pec, cw, ch = _quad_frame(
                (0.28, 0.53, -0.88), (0.69, 0.48, -0.48),
                (0.69, 0.78, -0.48), (0.28, 0.67, -0.88),
                ref_inside=(0.0, 0.62, -0.20),
            )
        else:
            M_pec, cw, ch = _quad_frame(
                (-0.69, 0.48, -0.48), (-0.28, 0.53, -0.88),
                (-0.28, 0.67, -0.88), (-0.69, 0.78, -0.48),
                ref_inside=(0.0, 0.62, -0.20),
            )
        kb.plate(f"PectoralArmor_{si}", crect_2d(cw * 0.88, ch * 0.84, (0.05, 0.05, 0.04, 0.04)), 0.062,
                 "armor", "armor_panel", (0, 0, -0.020), (0, 0, 0), 0.011, 1, M_parent=M_pec)
        kb.era_block(f"PecERA_{si}", (cw * 0.44, ch * 0.48, 0.042), "armor_sub",
                     (sx * 0.02, 0.02, -0.060), (0, 0, 0), M_parent=M_pec)
        kb.headlight_cage(f"ChestLamp_{si}", (sx * 0.38, 0.44, -0.74), (0, sx * -26.0, 0))
        kb.tow_shackle(f"ChestTow_{si}", (sx * 0.22, 0.39, -0.78))

        # Sculpted Swept Shoulder Collar Cowls (high-angle tumblehome pauldrons inboard of x=±0.80!)
        M_col = _face_frame((sx * 0.59, 0.90, -0.14), (sx * 0.58, 0.82, -0.04))
        kb.plate(f"ShoulderCowl_{si}", crect_2d(0.62, 0.30, (0.06, 0.06, 0.04, 0.04)), 0.072,
                 "armor" if si == 0 else "armor_oxide", "armor_slab", (0, 0, -0.024), (0, 0, 0), 0.012, 1, M_parent=M_col)
        kb.box(f"ShoulderVent_{si}", (0.34, 0.14, 0.026), "dark", "vent_mesh",
               (0, 0.0, -0.064), (0, 0, 0), 0.004, 1, M_parent=M_col)
        kb.smoke_pod(f"SmokeBank_{si}", (sx * 0.56, 1.03, -0.44), (-22, sx * -18.0, 0))

        # Tapered Rear Back Flank Armor + Louver Bay (angled inward toward HP-G1!)
        if sx > 0:
            M_rb, rw, rh = _quad_frame(
                (0.75, 0.48, 0.06), (0.45, 0.48, 0.62),
                (0.45, 0.72, 0.62), (0.75, 0.80, 0.06),
                ref_inside=(0.0, 0.62, 0.20),
            )
        else:
            M_rb, rw, rh = _quad_frame(
                (-0.45, 0.48, 0.62), (-0.75, 0.48, 0.06),
                (-0.75, 0.80, 0.06), (-0.45, 0.72, 0.62),
                ref_inside=(0.0, 0.62, 0.20),
            )
        kb.plate(f"RearShoulderPlate_{si}", crect_2d(rw * 0.76, rh * 0.76, (0.04, 0.04, 0.04, 0.04)), 0.046,
                 "armor_sub", "weld_plate", (0.05 * sx, 0, -0.014), (0, 0, 0), 0.009, 1, M_parent=M_rb)
        kb.louver_bay(f"RearCool_{si}", rw * 0.42, rh * 0.44, 0.030, (0.05 * sx, 0, -0.048), (0, 0, 0),
                      blades=4, mesh_style=True, M_parent=M_rb)

    # 4. Integrated Armored Tactical Sensor Head Recessed Between Shoulder Cowls (z=-0.38..-0.02 -> clear of back!)
    head_secs = [
        (-0.38, _oct_ring(0.24, 0.30, 0.22, 0.96, 1.01, 1.11, 1.17)),
        (-0.18, _oct_ring(0.36, 0.44, 0.32, 0.95, 1.02, 1.14, 1.21)),
        ( 0.02, _oct_ring(0.30, 0.36, 0.26, 0.95, 1.01, 1.12, 1.18)),
    ]
    kb.loft("TacticalHead", head_secs, "armor_sub", "armor_pocket", bevel_w=0.010, bevel_seg=1)
    kb.box("HeadVisorSlot", (0.26, 0.062, 0.024), "bore", "plain_metal", (0, 1.075, -0.388), (0, 0, 0), 0.002, 1)
    kb.box("HeadVisorGlass", (0.22, 0.044, 0.014), "glass", "plain_metal", (0, 1.075, -0.398), (0, 0, 0), 0.002, 1)
    kb.cyl("HeadMainOptic", 0.026, 0.028, 0.014, 14, "emit_cyan", "plain_metal", (0, 1.075, -0.405), (90, 0, 0), 0.002)
    kb.box("HeadBrowPlate", (0.34, 0.028, 0.12), "armor", "armor_ribs", (0, 1.155, -0.35), (8, 0, 0), 0.005, 1)
    _add_whip_antenna(kb, "HeadAnt", (0.16, 1.17, -0.06), h=0.58)

    # 5. Flush HP-B1 Dorsal Pad & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 1.00, 0.40, w=0.72, d=0.40)
    _add_rear_gen_pad(kb, "HP_G1", 0.54, 0.66, w=0.68, h=0.44)

    kb.add_marker("SOCKET_arm_l", (-0.82, 0.60, 0.0))
    kb.add_marker("SOCKET_arm_r", ( 0.82, 0.60, 0.0))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.00, 0.40))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.54, 0.66))
    kb.seat_core_low(0.06, new_y_top=0.09)


# ==============================================================================
# 2. core_m1a2_sepv3 — SEP-V3 Low-Slung Pentagonal Arrowhead Abrams MBT Turret
# ==============================================================================

def build_core_m1a2_sepv3(kb: KitbashScene):
    """SEP-V3 Core: authentic low-slung wide pentagonal arrowhead Abrams turret — zero tall shipping-container box!"""
    kb.waist_collar_core("HP_C1_Core", y_top=0.18)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"TurretStab_{si}", (sx * 0.30, 0.03, -0.22), (sx * 0.44, 0.24, -0.34), 0.022)

    # 1. Primary Low-Slung Pentagonal Arrowhead Turret Loft (wide, flat, 38deg swept cheeks, tapered bustle!)
    turret_secs = [
        (-1.24, _oct_ring(0.46, 0.60, 0.48, 0.34, 0.42, 0.60, 0.68)),   # Narrow armored mantlet prow!
        (-0.62, _oct_ring(1.44, 1.88, 1.46, 0.22, 0.36, 0.78, 0.96)),   # Dramatic 38deg Abrams DU cheek flare!
        ( 0.14, _oct_ring(1.52, 1.98, 1.50, 0.20, 0.36, 0.82, 1.01)),   # Broad low-slung turret body
        ( 0.68, _oct_ring(1.16, 1.48, 1.24, 0.26, 0.38, 0.80, 0.99)),   # Tapered rear ammo blowout bustle
        ( 0.94, _oct_ring(0.92, 1.14, 0.98, 0.30, 0.40, 0.76, 0.90)),   # Sloped rear bustle transom (<= 0.95)
    ]
    kb.loft("AbramsArrowheadHull", turret_secs, "armor_sub", "armor_slab", bevel_w=0.016, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Low-profile armored trunnion mounts at (±1.12, 0.58, 0.02)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.94, 1.12, 0.58, 0.02)

    # 2. Iconic Asymmetric 38deg Sloped DU Composite Cheek Armor Slabs (flush on arrowhead nose facets!)
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_ck, cw, ch = _quad_frame(
                (0.30, 0.42, -1.24), (0.94, 0.36, -0.62),
                (0.94, 0.78, -0.62), (0.30, 0.60, -1.24),
                ref_inside=(0.0, 0.56, -0.10),
            )
        else:
            M_ck, cw, ch = _quad_frame(
                (-0.94, 0.36, -0.62), (-0.30, 0.42, -1.24),
                (-0.30, 0.60, -1.24), (-0.94, 0.78, -0.62),
                ref_inside=(0.0, 0.56, -0.10),
            )
        kb.plate(f"DUCheekSlab_{si}", trap_2d(cw * 0.92, cw * 0.82, ch * 0.86, 0.05), 0.082,
                 "armor", "armor_slab", (0, 0.0, -0.028), (0, 0, 0), 0.014, 1, M_parent=M_ck)
        kb.plate(f"DUCheekTrim_{si}", crect_2d(cw * 0.64, ch * 0.44, (0.03, 0.03, 0.03, 0.03)), 0.028,
                 "armor_sub" if si == 0 else "armor_oxide", "weld_plate",
                 (0, 0.02, -0.072), (0, 0, 0), 0.006, 1, M_parent=M_ck)
        # Counterweight tow lugs + armored brow edge along each cheek (proud of DUCheekSlab front at -0.069)
        kb.tow_shackle(f"CheekTow_{si}", (sx * 0.14, -ch * 0.30, -0.090), (0, 0, 90), 0.85, M_parent=M_ck)
        if si == 0:
            kb.decal("AbramsUnit", "unit_08", (0.24, 0.14), (0.04, 0.02, -0.090), (0, 0, 0), M_parent=M_ck)
        # Upper 38deg sloped cheek shoulder bevel (between y_mid_hi and y_top)
        if sx > 0:
            M_cku, uw, uh = _quad_frame(
                (0.30, 0.60, -1.24), (0.94, 0.78, -0.62),
                (0.73, 0.96, -0.62), (0.24, 0.68, -1.24),
                ref_inside=(0.0, 0.56, -0.10),
            )
        else:
            M_cku, uw, uh = _quad_frame(
                (-0.94, 0.78, -0.62), (-0.30, 0.60, -1.24),
                (-0.24, 0.68, -1.24), (-0.73, 0.96, -0.62),
                ref_inside=(0.0, 0.56, -0.10),
            )
        kb.plate(f"CheekShoulderBevel_{si}", crect_2d(uw * 0.80, uh * 0.74, (0.03, 0.03, 0.03, 0.03)), 0.036,
                 "armor_sub", "armor_ribs", (0, 0, -0.010), (0, 0, 0), 0.008, 1, M_parent=M_cku)

    # 3. Central Armored Gun-Mantlet Nose Block + Recessed Auxiliary Coax & Driver Optic Slit
    kb.plate("MantletNose", crect_2d(0.54, 0.24, (0.04, 0.04, 0.04, 0.04)), 0.10, "armor_sub", "armor_pocket",
             (0, 0.51, -1.26), (0, 0, 0), 0.012, 1)
    _add_periscope(kb, "CenterDriverOptic", 0.34, 0.095, (0, 0.55, -1.368), (0, 0, 0))
    kb.box("NoseHazardBar", (0.38, 0.034, 0.014), "hazard", "hazard", (0, 0.415, -1.312), (0, 0, 0), 0.002, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"FrontLight_{si}", (sx * 0.24, 0.34, -1.20), (0, sx * -14.0, 0))

    # 4. Sloped Glacis Roof Deck + Iconic GPS Gunner Doghouse + Commander CITV + Blowout Panels (all forward of z=0.20!)
    M_rf_f, rfw, rfh = _quad_frame(
        (-0.24, 0.68, -1.24), ( 0.24, 0.68, -1.24),
        ( 0.73, 0.96, -0.62), (-0.73, 0.96, -0.62),
        ref_inside=(0.0, 0.52, -0.40),
    )
    kb.plate("FrontRoofGlacis", trap_2d(0.46, 1.32, rfh * 0.90, 0.05), 0.048, "armor", "armor_panel",
             (0, 0, -0.016), (0, 0, 0), 0.010, 1, M_parent=M_rf_f)
    kb.decal("AbramsWarn", "hazard_tri", (0.16, 0.16), (0.0, 0.0, -0.0442), (0, 0, 0), M_parent=M_rf_f)

    # Right-forward GPS Gunner Primary Thermal Sight Doghouse (Abrams signature!)
    kb.plate("GPS_Doghouse", crect_2d(0.30, 0.22, (0.04, 0.04, 0.02, 0.02)), 0.34, "armor_sub", "armor_pocket",
             (0.36, 1.06, -0.44), (0, 0, 0), 0.010, 1)
    kb.box("GPS_ShutterL", (0.085, 0.14, 0.018), "gunmetal", "bolt_flange", (0.28, 1.06, -0.615), (0, 18, 0), 0.003, 1)
    kb.box("GPS_ShutterR", (0.085, 0.14, 0.018), "gunmetal", "bolt_flange", (0.44, 1.06, -0.615), (0, -18, 0), 0.003, 1)
    kb.box("GPS_LensBay", (0.12, 0.11, 0.018), "glass", "plain_metal", (0.36, 1.06, -0.614), (0, 0, 0), 0.002, 1)
    kb.cyl("GPS_Core", 0.024, 0.026, 0.012, 12, "emit_cyan", "plain_metal", (0.36, 1.06, -0.624), (90, 0, 0), 0.001)

    # Left-forward CITV Independent Thermal Viewer Turret + Commander Cupolas (seated cleanly into roof!)
    kb.cyl("CITV_Base", 0.135, 0.155, 0.10, 16, "dark", "gear_collar", (-0.36, 1.00, -0.44), (0, 0, 0), 0.005)
    kb.cyl("CITV_Head", 0.115, 0.125, 0.15, 16, "armor", "armor_panel", (-0.36, 1.12, -0.44), (0, 0, 0), 0.006)
    kb.box("CITV_Window", (0.12, 0.072, 0.024), "glass", "plain_metal", (-0.36, 1.13, -0.558), (0, 0, 0), 0.003, 1)
    kb.cupola_hatch("CmdCupola", (0.24, 1.01, -0.02))
    kb.cupola_hatch("LoaderCupola", (-0.30, 1.01, -0.04))

    # 5. Swept Rear Bustle Cheek TUSK ARAT-2 ERA Skirt Tiles & Bustle Blowout Deck
    for si, sx in enumerate([-1.0, 1.0]):
        kb.smoke_pod(f"AbramsSmoke_{si}", (sx * 0.78, 0.99, -0.52), (-20, sx * -28.0, 0))
        if sx > 0:
            M_bs, bw, bh = _quad_frame(
                (0.99, 0.36, 0.16), (0.74, 0.38, 0.68),
                (0.74, 0.80, 0.68), (0.99, 0.82, 0.16),
                ref_inside=(0.0, 0.56, 0.35),
            )
        else:
            M_bs, bw, bh = _quad_frame(
                (-0.74, 0.38, 0.68), (-0.99, 0.36, 0.16),
                (-0.99, 0.82, 0.16), (-0.74, 0.80, 0.68),
                ref_inside=(0.0, 0.56, 0.35),
            )
        kb.plate(f"BustleBackPlate_{si}", crect_2d(bw * 0.86, bh * 0.82, (0.04, 0.04, 0.04, 0.04)), 0.040,
                 "armor_sub", "armor_ribs", (0, 0, -0.012), (0, 0, 0), 0.008, 1, M_parent=M_bs)
        # 2x2 TUSK ARAT-2 staggered reactive armor tiles hugging the tapered bustle flank
        for ti, tu in enumerate([-bw * 0.20, bw * 0.20]):
            for tj, tv in enumerate([-bh * 0.18, bh * 0.18]):
                kb.era_block(f"ARAT_{si}_{ti}_{tj}", (bw * 0.34, bh * 0.30, 0.042), "armor",
                             (tu, tv, -0.048), (0, 0, 0), M_parent=M_bs)
        _add_whip_antenna(kb, f"BustleAnt_{si}", (sx * 0.44, 0.94, 0.76), h=0.72, tilt_x=-10.0)

    # Flush HP-B1 Bustle Dorsal Dock & HP-G1 Rear Transom Dock
    _add_dorsal_back_pad(kb, "HP_B1", 1.04, 0.48, w=0.80, d=0.44)
    _add_rear_gen_pad(kb, "HP_G1", 0.56, 0.96, w=0.76, h=0.46)

    kb.add_marker("SOCKET_arm_l", (-1.12, 0.58, 0.02))
    kb.add_marker("SOCKET_arm_r", ( 1.12, 0.58, 0.02))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.04, 0.48))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.56, 0.96))
    kb.seat_core_low(0.11, new_y_top=0.11)


# ==============================================================================
# 3. core_fortress — FT-5 Double-Beveled Octagonal Tumblehome Armored Citadel
# ==============================================================================

def build_core_fortress(kb: KitbashScene):
    """FT-5 Fortress Citadel: 22deg 4-sided tumblehome octagonal bastion, sloped siege shield, stepped bridge."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.26)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"CitadelStabF_{si}", (sx * 0.31, 0.07, -0.22), (sx * 0.46, 0.28, -0.34), 0.024)
        kb.hydraulic(f"CitadelStabR_{si}", (sx * 0.31, 0.07,  0.22), (sx * 0.44, 0.28,  0.34), 0.024)

    # 1. Double-Beveled Octagonal Tumblehome Citadel Hull (y_bot >= 0.24 clears legs_hex spider knees!)
    cit_secs = [
        (-1.08, _oct_ring(0.70, 1.02, 0.72, 0.30, 0.46, 0.74, 0.90)),   # Blunt sloped siege prow
        (-0.56, _oct_ring(1.16, 1.92, 1.32, 0.24, 0.46, 0.86, 1.24)),   # Heavy flared tumblehome bastion
        ( 0.16, _oct_ring(1.22, 1.98, 1.36, 0.24, 0.46, 0.88, 1.28)),   # Main fortress core beltline
        ( 0.68, _oct_ring(1.00, 1.50, 1.10, 0.28, 0.46, 0.84, 1.22)),   # Angled rear bastion buttresses
        ( 0.94, _oct_ring(0.84, 1.12, 0.92, 0.30, 0.46, 0.78, 1.08)),   # Sloped rear reactor bulkhead (<= 0.95)
    ]
    kb.loft("FortressOctaCitadel", cit_secs, "armor_sub", "armor_slab", bevel_w=0.018, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Heavy Armored HP-A1 Trunnions at (±1.10, 0.66, 0.0)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.94, 1.10, 0.66, 0.0)

    # 2. Monolithic Sloped Siege Glacis Shield + Recessed Pillbox Bunker Visor Slit
    M_sg, sgw, sgh = _quad_frame(
        (-0.36, 0.90, -1.08), ( 0.36, 0.90, -1.08),
        ( 0.66, 1.24, -0.56), (-0.66, 1.24, -0.56),
        ref_inside=(0.0, 0.66, -0.20),
    )
    kb.plate("SiegeUpperGlacis", trap_2d(0.76, 1.28, sgh * 0.92, 0.06), 0.074, "armor", "armor_slab",
             (0, 0, -0.024), (0, 0, 0), 0.014, 1, M_parent=M_sg)
    for ri, rx in enumerate([-0.26, 0.26]):
        kb.box(f"GlacisRib_{ri}", (0.072, sgh * 0.82, 0.044), "armor_sub", "armor_ribs",
               (rx, 0, -0.070), (0, 0, 0), 0.008, 1, M_parent=M_sg)
    kb.box("GlacisOxideBand", (0.40, 0.14, 0.022), "armor_oxide", "weld_plate",
           (0, 0.04, -0.068), (0, 0, 0), 0.005, 1, M_parent=M_sg)
    kb.decal("FortressUnit", "unit_17", (0.24, 0.14), (0, 0.04, -0.084), (0, 0, 0), M_parent=M_sg)

    # Recessed Heavy Armored Pillbox Visor on the Blunt Prow Face (z = -1.08)
    kb.plate("BunkerProwShield", crect_2d(0.96, 0.32, (0.08, 0.08, 0.06, 0.06)), 0.090, "armor", "armor_panel",
             (0, 0.60, -1.10), (0, 0, 0), 0.014, 1)
    kb.box("BunkerVisorRecess", (0.76, 0.10, 0.024), "bore", "plain_metal", (0, 0.62, -1.142), (0, 0, 0), 0.002, 1)
    kb.plate("BunkerBrowHood", trap_2d(0.94, 0.82, 0.056, 0.015), 0.16, "armor_sub", "armor_ribs",
             (0, 0.72, -1.12), (10, 0, 0), 0.009, 1)
    for bi, bx in enumerate([-0.24, 0.0, 0.24]):
        kb.box(f"BunkerGlass_{bi}", (0.18, 0.068, 0.014), "glass", "plain_metal", (bx, 0.62, -1.150), (0, 0, 0), 0.002, 1)
        if bi == 1:
            kb.cyl("BunkerEye", 0.022, 0.024, 0.012, 12, "emit_amber", "plain_metal", (0, 0.62, -1.158), (90, 0, 0), 0.001)
    for mi, mx in enumerate([-0.12, 0.12]):
        kb.box(f"BunkerMullion_{mi}", (0.040, 0.115, 0.052), "dark", "bolt_flange", (mx, 0.62, -1.152), (0, 0, 0), 0.004, 1)
    # Lower siege ram bumper + heavy shackles + caged floodlights
    kb.plate("LowerRamChin", trap_2d(0.68, 0.94, 0.20, 0.05), 0.084, "armor_sub", "armor_pocket",
             (0, 0.36, -1.04), (-28, 0, 0), 0.012, 1)
    kb.box("RamHazard", (0.64, 0.044, 0.016), "hazard", "hazard", (0, 0.36, -1.088), (-28, 0, 0), 0.002, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"SiegeLamp_{si}", (sx * 0.42, 0.45, -1.12), (0, sx * -16.0, 0))
        kb.tow_shackle(f"SiegeTow_{si}", (sx * 0.28, 0.29, -1.095), (0, 0, 90), 1.05)

    # 3. Canted Octagonal Cheek Buttresses + 22deg Tumblehome Upper Bastion Plates
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_fc, fw, fh = _quad_frame(
                (0.51, 0.46, -1.08), (0.96, 0.46, -0.56),
                (0.96, 0.86, -0.56), (0.51, 0.74, -1.08),
                ref_inside=(0.0, 0.66, -0.10),
            )
            M_tu, tuw, tuh = _quad_frame(
                (0.96, 0.86, -0.56), (0.99, 0.88, 0.16),
                (0.68, 1.28,  0.16), (0.66, 1.24, -0.56),
                ref_inside=(0.0, 0.66, -0.10),
            )
            M_rb, rbw, rbh = _quad_frame(
                (0.99, 0.46, 0.16), (0.75, 0.46, 0.68),
                (0.75, 0.84, 0.68), (0.99, 0.88, 0.16),
                ref_inside=(0.0, 0.66, 0.35),
            )
        else:
            M_fc, fw, fh = _quad_frame(
                (-0.96, 0.46, -0.56), (-0.51, 0.46, -1.08),
                (-0.51, 0.74, -1.08), (-0.96, 0.86, -0.56),
                ref_inside=(0.0, 0.66, -0.10),
            )
            M_tu, tuw, tuh = _quad_frame(
                (-0.99, 0.88,  0.16), (-0.96, 0.86, -0.56),
                (-0.66, 1.24, -0.56), (-0.68, 1.28,  0.16),
                ref_inside=(0.0, 0.66, -0.10),
            )
            M_rb, rbw, rbh = _quad_frame(
                (-0.75, 0.46, 0.68), (-0.99, 0.46, 0.16),
                (-0.99, 0.88, 0.16), (-0.75, 0.84, 0.68),
                ref_inside=(0.0, 0.66, 0.35),
            )
        kb.plate(f"FrontBastionCheek_{si}", crect_2d(fw * 0.86, fh * 0.82, (0.05, 0.05, 0.04, 0.04)), 0.072,
                 "armor", "armor_panel", (0, 0, -0.024), (0, 0, 0), 0.013, 1, M_parent=M_fc)
        kb.era_block(f"BastionERA_{si}", (fw * 0.56, fh * 0.46, 0.046), "armor_sub",
                     (0, 0.02, -0.068), (0, 0, 0), M_parent=M_fc)
        # 22deg Tumblehome upper armor flank (louver proud at -0.064, decal clear beside it!)
        kb.plate(f"TumblehomePlate_{si}", crect_2d(tuw * 0.88, tuh * 0.82, (0.06, 0.06, 0.04, 0.04)), 0.064,
                 "armor_sub" if si == 0 else "armor", "weld_plate", (0, 0, -0.020), (0, 0, 0), 0.012, 1, M_parent=M_tu)
        kb.louver_bay(f"TumbleVent_{si}", tuw * 0.38, tuh * 0.40, 0.030, (-sx * 0.10, 0, -0.063), (0, 0, 0),
                      blades=5, mesh_style=False, M_parent=M_tu)
        kb.decal(f"BastionTri_{si}", "hazard_tri", (0.14, 0.14), (sx * 0.22, 0, -0.0565), (0, 0, 0), M_parent=M_tu)
        # Rear angled cooling buttress (louver proud at -0.058!)
        kb.plate(f"RearButtress_{si}", crect_2d(rbw * 0.84, rbh * 0.80, (0.05, 0.05, 0.04, 0.04)), 0.056,
                 "armor_sub", "armor_ribs", (0, 0, -0.018), (0, 0, 0), 0.011, 1, M_parent=M_rb)
        kb.louver_bay(f"RearRadBay_{si}", rbw * 0.46, rbh * 0.48, 0.030, (0, 0, -0.057), (0, 0, 0),
                      blades=4, mesh_style=True, M_parent=M_rb)
        kb.smoke_pod(f"CitadelSmoke_{si}", (sx * 0.62, 1.28, -0.44), (-22, sx * -20.0, 0))

    # 4. Stepped Forward Conning Command Bridge Cap (strictly z <= +0.12 -> 100% clear of back_vls!)
    bridge_secs = [
        (-0.48, _oct_ring(0.72, 0.84, 0.64, 1.24, 1.28, 1.38, 1.44)),
        (-0.18, _oct_ring(0.92, 1.04, 0.82, 1.25, 1.30, 1.42, 1.48)),
        ( 0.10, _oct_ring(0.84, 0.94, 0.74, 1.25, 1.30, 1.40, 1.46)),
    ]
    kb.loft("CommandBridgeCap", bridge_secs, "armor_sub", "armor_pocket", bevel_w=0.012, bevel_seg=1)
    for pi, px in enumerate([-0.22, 0.0, 0.22]):
        _add_periscope(kb, f"BridgeScope_{pi}", 0.16, 0.078, (px, 1.35, -0.515), (0, 0, 0))
    kb.cupola_hatch("BridgeCupola", (-0.22, 1.48, -0.14))
    _add_whip_antenna(kb, "BridgeAnt", (0.34, 1.46, -0.04), h=0.72)

    # 5. Flush HP-B1 Dorsal Pad & HP-G1 Rear Dock (z=0.98 clears gen_crystal 100%!)
    _add_dorsal_back_pad(kb, "HP_B1", 1.30, 0.46, w=0.84, d=0.46)
    _add_rear_gen_pad(kb, "HP_G1", 0.64, 0.98, w=0.78, h=0.48)

    kb.add_marker("SOCKET_arm_l", (-1.10, 0.66, 0.0))
    kb.add_marker("SOCKET_arm_r", ( 1.10, 0.66, 0.0))
    kb.add_marker("SOCKET_back",  ( 0.0,  1.30, 0.46))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.64, 0.98))
    kb.seat_core_low(0.14, new_y_top=0.12)


# ==============================================================================
# 4. core_t90m_proryv — PRV-90 Ultra-Low Hexagonal Arrowhead Relikt Turret
# ==============================================================================

def build_core_t90m_proryv(kb: KitbashScene):
    """PRV-90 Core: ultra-low hexagonal arrowhead turret wrapped in 6x V-chevron Relikt ERA & twin Shtora lamps."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.16)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"ProryvStab_{si}", (sx * 0.29, 0.03, -0.20), (sx * 0.42, 0.22, -0.32), 0.020)

    # 1. Ultra-Low Hexagonal Arrowhead Turret Loft (razor-sharp 35deg chevron prow + strongly sloped dome roof!)
    t90_secs = [
        (-1.20, _oct_ring(0.32, 0.44, 0.30, 0.34, 0.40, 0.56, 0.64)),   # Sharp arrowhead nose tip!
        (-0.56, _oct_ring(1.44, 1.86, 1.28, 0.20, 0.34, 0.70, 0.90)),   # Wide 35deg V-chevron clamshell cheeks!
        ( 0.10, _oct_ring(1.50, 1.92, 1.32, 0.18, 0.34, 0.74, 0.95)),   # Low-profile welded hexagonal turret
        ( 0.62, _oct_ring(1.08, 1.38, 1.04, 0.24, 0.36, 0.72, 0.92)),   # Tapered rear turret bustle
        ( 0.90, _oct_ring(0.84, 1.04, 0.86, 0.28, 0.38, 0.68, 0.84)),   # Compact rear bustle transom (<= 0.91)
    ]
    kb.loft("ProryvHexTurret", t90_secs, "armor_sub", "armor_slab", bevel_w=0.015, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Low shoulder trunnions at (±1.08, 0.54, 0.02)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.92, 1.08, 0.54, 0.02)

    # 2. Iconic 6-Unit V-Chevron Relikt Clamshell ERA Wedges Wrapping Both 35deg Arrowhead Faces!
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_v, vw, vh = _quad_frame(
                (0.22, 0.40, -1.20), (0.93, 0.34, -0.56),
                (0.93, 0.70, -0.56), (0.22, 0.56, -1.20),
                ref_inside=(0.0, 0.54, -0.10),
            )
            M_vu, vuw, vuh = _quad_frame(
                (0.22, 0.56, -1.20), (0.93, 0.70, -0.56),
                (0.64, 0.90, -0.56), (0.15, 0.64, -1.20),
                ref_inside=(0.0, 0.54, -0.10),
            )
            M_rear, rw, rh = _quad_frame(
                (0.96, 0.34, 0.14), (0.69, 0.36, 0.62),
                (0.69, 0.72, 0.62), (0.96, 0.74, 0.14),
                ref_inside=(0.0, 0.54, 0.35),
            )
        else:
            M_v, vw, vh = _quad_frame(
                (-0.93, 0.34, -0.56), (-0.22, 0.40, -1.20),
                (-0.22, 0.56, -1.20), (-0.93, 0.70, -0.56),
                ref_inside=(0.0, 0.54, -0.10),
            )
            M_vu, vuw, vuh = _quad_frame(
                (-0.93, 0.70, -0.56), (-0.22, 0.56, -1.20),
                (-0.15, 0.64, -1.20), (-0.64, 0.90, -0.56),
                ref_inside=(0.0, 0.54, -0.10),
            )
            M_rear, rw, rh = _quad_frame(
                (-0.69, 0.36, 0.62), (-0.96, 0.34, 0.14),
                (-0.96, 0.74, 0.14), (-0.69, 0.72, 0.62),
                ref_inside=(0.0, 0.54, 0.35),
            )
        # 3 Clamshell Relikt ERA arrowhead blocks along each sweeping cheek (6 total!)
        for ei in range(3):
            u_pos = -vw * 0.31 + vw * 0.31 * ei
            kb.era_block(f"ReliktWedge_{si}_{ei}", (vw * 0.28, vh * 0.78, 0.088),
                         "armor" if ei != 1 else "armor_sub", (u_pos, 0.0, -0.036), (0, 0, 0), M_parent=M_v)
        # Compact sloped upper cheek armor brow strictly outboard of Shtora ruby lamp!
        kb.plate(f"ReliktTopHood_{si}", crect_2d(vuw * 0.56, vuh * 0.56, (0.04, 0.04, 0.03, 0.03)), 0.038,
                 "armor", "armor_slab", (sx * 0.14, 0.0, -0.012), (0, 0, 0), 0.008, 1, M_parent=M_vu)

        # Twin Iconic Shtora Electro-Optical Ruby Jammer Lamps flanking the nose tip (cleanly seated!)
        kb.box(f"ShtoraHousing_{si}", (0.16, 0.14, 0.12), "dark", "frame_cnc",
               (sx * 0.30, 0.72, -0.94), (0, sx * -20.0, 0), 0.008, 1)
        kb.box(f"ShtoraRuby_{si}", (0.115, 0.095, 0.016), "emit_red", "plain_metal",
               (sx * 0.30, 0.72, -1.002), (0, sx * -20.0, 0), 0.002, 1)
        kb.box(f"ShtoraBrow_{si}", (0.18, 0.022, 0.14), "armor_sub", "bolt_flange",
               (sx * 0.30, 0.80, -0.95), (6, sx * -20.0, 0), 0.004, 1)

        # Rear tapered flank anti-HEAT slat armor cage + smoke launcher bank
        kb.plate(f"RearCheekArmor_{si}", crect_2d(rw * 0.82, rh * 0.78, (0.04, 0.04, 0.03, 0.03)), 0.038,
                 "armor_sub", "weld_plate", (0, 0, -0.012), (0, 0, 0), 0.008, 1, M_parent=M_rear)
        _add_slat_panel(kb, f"ProryvSlat_{si}", M_rear, rw * 0.76, rh * 0.68, n_bars=4)
        kb.smoke_pod(f"T90Smoke_{si}", (sx * 0.70, 0.93, -0.46), (-22, sx * -32.0, 0))

    # 3. Central Nose Prow Armor + Recessed Optics + Low-Profile Dome Cupola & Sosna-U Thermal Sight
    kb.plate("ProryvProwCap", crect_2d(0.42, 0.22, (0.04, 0.04, 0.04, 0.04)), 0.088, "armor_sub", "armor_pocket",
             (0, 0.48, -1.21), (0, 0, 0), 0.010, 1)
    _add_periscope(kb, "ProryvDriverScope", 0.26, 0.085, (0, 0.51, -1.258), (0, 0, 0))
    kb.box("ProryvHazard", (0.28, 0.032, 0.012), "hazard", "hazard", (0, 0.395, -1.254), (0, 0, 0), 0.002, 1)
    kb.decal("ProryvUnit", "unit_08", (0.22, 0.12), (0, 0.96, -0.40), (-90, 0, 0))

    # Low cast-style domed commander cupola + Sosna-U panoramic thermal sight (seated cleanly into sloped roof!)
    kb.lathe("CmdDomeCupola", [
        (0.0, 0.92), (0.24, 0.92), (0.23, 0.99), (0.19, 1.05), (0.12, 1.075), (0.0, 1.08)
    ], 16, "armor", "armor_panel", pos=(0.24, 0.0, -0.14))
    kb.cyl("SosnaMast", 0.095, 0.115, 0.18, 12, "armor_sub", "armor_pocket", (-0.28, 0.98, -0.34), (0, 0, 0), 0.006)
    kb.box("SosnaOptic", (0.11, 0.075, 0.022), "glass", "plain_metal", (-0.28, 1.01, -0.445), (0, 0, 0), 0.003, 1)
    kb.cyl("SosnaPip", 0.018, 0.020, 0.010, 10, "emit_cyan", "plain_metal", (-0.28, 1.01, -0.456), (90, 0, 0), 0.001)
    _add_whip_antenna(kb, "ProryvAnt", (-0.42, 0.87, 0.70), h=0.72)

    # 4. Flush HP-B1 Bustle Dock & HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 0.98, 0.44, w=0.76, d=0.42)
    _add_rear_gen_pad(kb, "HP_G1", 0.52, 0.92, w=0.72, h=0.44)

    kb.add_marker("SOCKET_arm_l", (-1.08, 0.54, 0.02))
    kb.add_marker("SOCKET_arm_r", ( 1.08, 0.54, 0.02))
    kb.add_marker("SOCKET_back",  ( 0.0,  0.98, 0.44))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.52, 0.92))
    kb.seat_core_low(0.10, new_y_top=0.10)


# ==============================================================================
# 5. core_fennek_recon — FNK-4 Razor-Chined Stealth Diamond Recon Pod
# ==============================================================================

def build_core_fennek_recon(kb: KitbashScene):
    """FNK-4 Fennek Recon Core: ultra-low razor-chined stealth diamond fuselage + 3-pane anti-laser canopy + BAA mast."""
    kb.waist_collar_core("HP_C1_Core", y_top=0.25)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"StealthStab_{si}", (sx * 0.27, 0.07, -0.18), (sx * 0.36, 0.25, -0.28), 0.018)

    # 1. Razor-Chined Stealth Diamond Loft (y_bot >= 0.24 clears legs_quad knees; stern clears back_missile!)
    fnk_secs = [
        (-1.14, _oct_ring(0.32, 0.48, 0.30, 0.30, 0.36, 0.42, 0.47)),   # Razor chisel stealth nose!
        (-0.54, _oct_ring(0.76, 1.44, 0.80, 0.24, 0.42, 0.54, 0.80)),   # Sharp knife-edge chine + 32deg canopy rake!
        ( 0.10, _oct_ring(0.84, 1.54, 0.92, 0.23, 0.42, 0.56, 0.84)),   # Widest stealth diamond beltline
        ( 0.56, _oct_ring(0.68, 1.06, 0.74, 0.25, 0.42, 0.54, 0.78)),   # Aggressively tapered stealth stern
        ( 0.78, _oct_ring(0.56, 0.84, 0.62, 0.28, 0.42, 0.52, 0.72)),   # Compact stealth tail transom (<= 0.79)
    ]
    kb.loft("StealthDiamondHull", fnk_secs, "armor_sub", "armor_slab", bevel_w=0.014, bevel_seg=1, tile_u=2.0, flat_shade=True)

    # Sleek low-profile HP-A1 Trunnions at (±0.88, 0.48, 0.02)
    _add_arm_trunnion_bridge(kb, "ArmMount", 0.74, 0.88, 0.48, 0.02)

    # 2. 3-Facet Wraparound Anti-Laser Stealth Armored Canopy (flush on nose slope + ±30deg angled cheeks!)
    M_cwin, cww, cwh = _quad_frame(
        (-0.15, 0.47, -1.14), ( 0.15, 0.47, -1.14),
        ( 0.40, 0.80, -0.54), (-0.40, 0.80, -0.54),
        ref_inside=(0.0, 0.46, -0.40),
    )
    kb.plate("CanopyCenterFrame", trap_2d(0.38, 0.78, cwh * 0.88, 0.04), 0.044, "armor", "armor_slab",
             (0, 0, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_cwin)
    kb.plate("CanopyCenterRecess", trap_2d(0.28, 0.58, cwh * 0.56, 0.03), 0.020, "bore", "plain_metal",
             (0, 0.04, -0.032), (0, 0, 0), 0.003, 1, M_parent=M_cwin)
    kb.plate("CanopyCenterGlass", trap_2d(0.24, 0.52, cwh * 0.48, 0.025), 0.014, "glass", "plain_metal",
             (0, 0.04, -0.040), (0, 0, 0), 0.002, 1, M_parent=M_cwin)
    kb.box("CanopyCyanStrip", (0.28, 0.024, 0.010), "emit_cyan", "plain_metal",
           (0, -cwh * 0.26, -0.038), (0, 0, 0), 0.002, 1, M_parent=M_cwin)

    # Left & Right 32deg Stealth Side Canopy Facets + Razor Triangular Intake Cowls + Tapered Stern Louvers
    for si, sx in enumerate([-1.0, 1.0]):
        if sx > 0:
            M_sw, sww, swh = _quad_frame(
                (0.24, 0.42, -1.14), (0.72, 0.54, -0.54),
                (0.40, 0.80, -0.54), (0.15, 0.47, -1.14),
                ref_inside=(0.0, 0.46, -0.40),
            )
            M_fu, fuw, fuh = _quad_frame(
                (0.72, 0.54, -0.54), (0.77, 0.56, 0.10),
                (0.46, 0.84,  0.10), (0.40, 0.80, -0.54),
                ref_inside=(0.0, 0.48, -0.10),
            )
            M_sr, srw, srh = _quad_frame(
                (0.77, 0.56, 0.10), (0.53, 0.54, 0.56),
                (0.37, 0.78, 0.56), (0.46, 0.84, 0.10),
                ref_inside=(0.0, 0.48, 0.30),
            )
        else:
            M_sw, sww, swh = _quad_frame(
                (-0.72, 0.54, -0.54), (-0.24, 0.42, -1.14),
                (-0.15, 0.47, -1.14), (-0.40, 0.80, -0.54),
                ref_inside=(0.0, 0.46, -0.40),
            )
            M_fu, fuw, fuh = _quad_frame(
                (-0.77, 0.56,  0.10), (-0.72, 0.54, -0.54),
                (-0.40, 0.80, -0.54), (-0.46, 0.84,  0.10),
                ref_inside=(0.0, 0.48, -0.10),
            )
            M_sr, srw, srh = _quad_frame(
                (-0.53, 0.54, 0.56), (-0.77, 0.56, 0.10),
                (-0.46, 0.84, 0.10), (-0.37, 0.78, 0.56),
                ref_inside=(0.0, 0.48, 0.30),
            )
        kb.plate(f"StealthCheekFacet_{si}", crect_2d(sww * 0.84, swh * 0.72, (0.04, 0.04, 0.03, 0.03)), 0.038,
                 "armor_sub", "armor_panel", (0, 0, -0.012), (0, 0, 0), 0.007, 1, M_parent=M_sw)
        kb.plate(f"SideCanopyGlass_{si}", crect_2d(sww * 0.52, swh * 0.34, (0.02, 0.02, 0.02, 0.02)), 0.016,
                 "glass", "plain_metal", (0, 0.02, -0.034), (0, 0, 0), 0.002, 1, M_parent=M_sw)

        # Stealth upper flank armor panel + recessed triangular intake louver (proud -0.046!)
        kb.plate(f"StealthFlank_{si}", crect_2d(fuw * 0.86, fuh * 0.80, (0.05, 0.05, 0.03, 0.03)), 0.042,
                 "armor" if si == 0 else "armor_oxide", "armor_slab", (0, 0, -0.014), (0, 0, 0), 0.008, 1, M_parent=M_fu)
        kb.louver_bay(f"StealthIntake_{si}", fuw * 0.44, fuh * 0.34, 0.024, (0, 0, -0.043), (0, 0, 0),
                      blades=4, mesh_style=True, M_parent=M_fu)

        # Tapered stern stealth cooling cowl
        kb.plate(f"SternStealth_{si}", crect_2d(srw * 0.82, srh * 0.78, (0.04, 0.04, 0.03, 0.03)), 0.036,
                 "armor_sub", "armor_ribs", (0, 0, -0.010), (0, 0, 0), 0.007, 1, M_parent=M_sr)
        kb.headlight_cage(f"StealthLight_{si}", (sx * 0.22, 0.36, -1.12), (0, sx * -22.0, 0))

    # Chisel Nose Sensor Chin (mounted via stepped collar strictly non-coplanar with sloped nose belly!)
    kb.cyl("NoseSensorStrut", 0.068, 0.074, 0.055, 12, "dark", "gear_collar", (0, 0.285, -1.03), (0, 0, 0), 0.004)
    kb.eoir_gimbal("FennekNoseSensor", (0, 0.228, -1.03))
    kb.decal("FennekUnit", "unit_08", (0.18, 0.10), (0.18, 0.828, -0.18), (-90, 0, 0))
    # BAA 3-in-1 Recon Mast on forward-left stealth ridge
    kb.cyl("BAA_Pedestal", 0.075, 0.095, 0.14, 12, "dark", "gear_collar", (-0.22, 0.89, -0.16), (0, 0, 0), 0.004)
    kb.cyl("BAA_Pole", 0.038, 0.044, 0.26, 12, "gunmetal", "frame_cnc", (-0.22, 1.08, -0.16), (0, 0, 0), 0.003)
    kb.plate("BAA_SensorHead", crect_2d(0.24, 0.16, (0.04, 0.04, 0.03, 0.03)), 0.18, "armor", "armor_pocket",
             (-0.22, 1.27, -0.16), (0, 0, 0), 0.008, 1)
    for bi, (bx, br, bslot) in enumerate([(-0.055, 0.034, "glass"), (0.048, 0.024, "emit_cyan")]):
        kb.cyl(f"BAA_Ring_{bi}", br + 0.008, br + 0.010, 0.020, 12, "gunmetal", "plain_metal",
               (-0.22 + bx, 1.27, -0.256), (90, 0, 0), 0.002, hollow_r=br * 0.80)
        kb.cyl(f"BAA_Lens_{bi}", br * 0.78, br * 0.78, 0.012, 12, bslot, "plain_metal",
               (-0.22 + bx, 1.27, -0.254), (90, 0, 0), 0.001)
    _add_whip_antenna(kb, "FennekAnt", (0.28, 0.83, -0.06), h=0.72)

    # Flush HP-B1 Dorsal Pad seated cleanly on the low stealth deck + HP-G1 Rear Dock
    _add_dorsal_back_pad(kb, "HP_B1", 0.86, 0.44, w=0.62, d=0.36)
    _add_rear_gen_pad(kb, "HP_G1", 0.46, 0.80, w=0.64, h=0.40)

    kb.add_marker("SOCKET_arm_l", (-0.88, 0.48, 0.02))
    kb.add_marker("SOCKET_arm_r", ( 0.88, 0.48, 0.02))
    kb.add_marker("SOCKET_back",  ( 0.0,  0.86, 0.44))
    kb.add_marker("SOCKET_gen",   ( 0.0,  0.46, 0.80))
    kb.seat_core_low(0.13, new_y_top=0.12)
