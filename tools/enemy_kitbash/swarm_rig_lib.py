"""
Sci-Fi Mecha-Swarm Articulated Limb & Plasma Weapon Library (`d:\\123\\qianyuanshaonv\\tools\\enemy_kitbash\\swarm_rig_lib.py`).
Inspired by *86 -Eighty Six-* Legion (`Ameise`, `Lowe`, `Dinosauria`), *Horizon Zero Dawn* Faro Plague (`Corruptor`, `Deathbringer`),
and *StarCraft II* Simulant Mecha-Swarm.
  - 100% razor-sharp stealth-faceted dark gunmetal/charcoal armor + silver hydraulic pistons + glowing neon-violet plasma conduits!
  - Strictly ZERO organic chitin/flesh, ZERO humanoid legs/torsos, ZERO civilian wheels/cabs, and all ground talons flush at y = 0.000m!
"""
import math
import bmesh
from mathutils import Vector, Matrix
from kitbash_lib import KitbashScene, g2b_mat, g2b_bone_mat, crect_2d, trap_2d
from leg_rig_lib import heavy_hyd, heavy_drum, _add_prism_local


def ngon_2d(n: int, rx: float, ry: float, phase: float = 0.0):
    return [(math.cos(phase + math.tau * i / n) * rx, math.sin(phase + math.tau * i / n) * ry) for i in range(n)]


def diamond_2d(w: float, h: float, waist_y: float = 0.12):
    """Predatory stealth-fighter faceted 6-point diamond armor plate in Godot XY."""
    hw, hh = w * 0.5, h * 0.5
    return [
        (0.0, hh),
        (hw, waist_y * hh),
        (hw * 0.72, -hh * 0.82),
        (0.0, -hh),
        (-hw * 0.72, -hh * 0.82),
        (-hw, waist_y * hh),
    ]


# ==============================================================================
# 1. `Ameise` / `Mecha-Zergling` Sleek Faceted Blade-Strut Limb (Flush at y = 0.000m)
# ==============================================================================
def build_ameise_blade_leg(kb: KitbashScene, idx: int, pos, yaw_deg: float, side: float,
                           reach: float, hip_y: float, w: float = 1.0):
    """Fast reverse-cambered stealth-faceted mechanical stalker leg (`Hip_<idx>` -> `Knee`), talon flush at y = 0.000m."""
    g_hip = kb.add_group(f"Hip_{idx}", f"Hip_{idx}", pos=pos, rot_deg=(0.0, yaw_deg, 0.0))
    kb.use_group(g_hip)

    kn = Vector((side * reach * 0.58, 0.24 * w, 0.0))
    ft_y = -hip_y

    # Faceted shoulder servo + violet energy ring
    heavy_drum(kb, f"AL{idx}_HipDr", (0, 0, 0), 0.105 * w, 0.19 * w, segs=12)
    kb.cyl(f"AL{idx}_HipGlow", 0.112 * w, 0.112 * w, 0.022 * w, 12, "emit_core", "plain_metal",
           (side * 0.06 * w, 0, 0), (0, 0, 90), 0.002)

    M_fm = g2b_bone_mat((0, 0, 0), kn)
    l1 = max(0.16, kn.length - 0.06 * w)
    kb.box(f"AL{idx}_FmFrame", (0.11 * w, l1, 0.14 * w), "dark", "frame_cnc",
           (0, -0.5 * kn.length, 0), (0, 0, 0), 0.008, 1, M_parent=M_fm)
    kb.plate(f"AL{idx}_FmArmor", diamond_2d(0.20 * w, l1 * 1.04), 0.058 * w, "armor", "armor_slab",
             (0, -0.5 * kn.length, 0.08 * w), (0, 0, 0), 0.010, 1, M_parent=M_fm)
    heavy_hyd(kb, f"AL{idx}_FmHyd", (side * 0.03 * w, -0.09 * w, 0.0),
              (kn.x - side * 0.05 * w, kn.y - 0.08 * w, 0.0), r=0.020 * w, segs=8)

    # Knee group -> tapered angular blade-shin + 2-prong forged-titanium ground talon at y = -drop
    g_kn = kb.add_group(f"Hip_{idx}/Knee", "Knee", pos=(kn.x, kn.y, kn.z), parent_key=g_hip)
    kb.use_group(g_kn)
    heavy_drum(kb, f"AL{idx}_KnDr", (0, 0, 0), 0.092 * w, 0.17 * w, segs=12)
    kb.cyl(f"AL{idx}_KnGlow", 0.098 * w, 0.098 * w, 0.020 * w, 12, "emit_core", "plain_metal",
           (side * 0.05 * w, 0, 0), (0, 0, 90), 0.002)

    # Swept stealth knee-fin crest
    M_crest = g2b_mat((side * 0.08 * w, 0.08 * w, 0.0), (0.0, side * 90.0, -side * 22.0))
    kb.plate(f"AL{idx}_KnCrest", diamond_2d(0.18 * w, 0.30 * w), 0.048 * w, "armor_sub", "armor_panel",
             (0, 0, 0), (0, 0, 0), 0.008, 1, M_parent=M_crest)

    drop = kn.y - ft_y
    ft_rel = Vector((side * reach * 0.42, -drop + 0.035 * w, -0.02 * w))
    M_sh = g2b_bone_mat((0, 0, 0), ft_rel)
    l2 = max(0.18, ft_rel.length - 0.06 * w)
    kb.box(f"AL{idx}_ShCore", (0.095 * w, l2, 0.13 * w), "gunmetal", "frame_cnc",
           (0, -0.5 * ft_rel.length, 0), (0, 0, 0), 0.007, 1, M_parent=M_sh)
    kb.plate(f"AL{idx}_ShBlade", trap_2d(0.08 * w, 0.19 * w, l2 * 1.02, 0.02 * w), 0.055 * w, "armor", "armor_slab",
             (side * 0.04 * w, -0.48 * ft_rel.length, 0.05 * w), (0, side * 90.0, 0), 0.009, 1, M_parent=M_sh)
    kb.box(f"AL{idx}_ShVein", (0.018 * w, l2 * 0.68, 0.022 * w), "emit_amber", "plain_metal",
           (side * 0.072 * w, -0.46 * ft_rel.length, 0.05 * w), (0, 0, 0), 0.002, 1, M_parent=M_sh)
    heavy_hyd(kb, f"AL{idx}_ShHyd", (-side * 0.03 * w, -0.06 * w, 0.0),
              (ft_rel.x * 0.72, ft_rel.y * 0.72, ft_rel.z), r=0.018 * w, segs=8)

    # Angular 2-prong tungsten talon pad strictly flush at y = -drop (world y = 0.000m!)
    ty_pad = -drop + 0.024 * w
    kb.box(f"AL{idx}_AnkHub", (0.13 * w, 0.048 * w, 0.16 * w), "dark", "bolt_flange",
           (ft_rel.x, ty_pad, ft_rel.z), (0, 0, 0), 0.005, 1)
    for ti, tz in enumerate([-0.06 * w, 0.06 * w]):
        kb.plate(f"AL{idx}_Talon_{ti}", trap_2d(0.065 * w, 0.035 * w, 0.18 * w, 0.01), 0.040 * w,
                 "chrome", "plain_metal", (ft_rel.x + side * 0.06 * w, -drop + 0.020 * w, ft_rel.z + tz),
                 (90, 0, 0), 0.004, 1)
    kb.use_group("Body")


# ==============================================================================
# 2. `Lowe` / `Corruptor` Heavy Armored Arthropod Limb (Flush at y = 0.000m)
# ==============================================================================
def build_lowe_arthropod_leg(kb: KitbashScene, idx: int, pos, yaw_deg: float, side: float,
                             reach: float, hip_y: float, w: float = 1.0):
    """86-Legion `Lowe` heavy multi-segmented stealth armor arthropod leg, flush at y = 0.000m."""
    g_hip = kb.add_group(f"Hip_{idx}", f"Hip_{idx}", pos=pos, rot_deg=(0.0, yaw_deg, 0.0))
    kb.use_group(g_hip)

    kn = Vector((side * reach * 0.62, 0.30 * w, 0.0))
    ft_y = -hip_y

    heavy_drum(kb, f"LW{idx}_Coxa", (0, 0, 0), 0.135 * w, 0.25 * w, segs=14, n_bolts=4)
    M_fm = g2b_bone_mat((0, 0, 0), kn)
    l1 = max(0.20, kn.length - 0.08 * w)
    kb.box(f"LW{idx}_FmCore", (0.17 * w, l1, 0.20 * w), "dark", "frame_cnc",
           (0, -0.5 * kn.length, 0), (0, 0, 0), 0.010, 1, M_parent=M_fm)
    kb.plate(f"LW{idx}_FmCarapace", diamond_2d(0.28 * w, l1 * 1.04), 0.082 * w, "armor", "armor_slab",
             (0, -0.5 * kn.length, 0.11 * w), (0, 0, 0), 0.012, 1, M_parent=M_fm)
    kb.box(f"LW{idx}_FmTrim", (0.045 * w, l1 * 0.66, 0.025 * w), "hazard", "plain_metal",
           (0, -0.5 * kn.length, 0.155 * w), (0, 0, 0), 0.003, 1, M_parent=M_fm)
    heavy_hyd(kb, f"LW{idx}_FmRam", (side * 0.05 * w, -0.11 * w, 0.0),
              (kn.x - side * 0.06 * w, kn.y - 0.09 * w, 0.0), r=0.028 * w, segs=8)

    g_kn = kb.add_group(f"Hip_{idx}/Knee", "Knee", pos=(kn.x, kn.y, kn.z), parent_key=g_hip)
    kb.use_group(g_kn)
    heavy_drum(kb, f"LW{idx}_KnDr", (0, 0, 0), 0.12 * w, 0.24 * w, segs=12, n_bolts=4)

    # Sharp overhanging stealth knee-shield with glowing purple conduit slit
    M_ksh = g2b_mat((side * 0.12 * w, 0.06 * w, 0.0), (0.0, side * 90.0, -side * 18.0))
    kb.plate(f"LW{idx}_KnShield", trap_2d(0.26 * w, 0.16 * w, 0.36 * w, 0.03 * w), 0.072 * w,
             "armor_sub", "armor_panel", (0, 0, 0), (0, 0, 0), 0.010, 1, M_parent=M_ksh)
    kb.box(f"LW{idx}_KnGlow", (0.14 * w, 0.024 * w, 0.020 * w), "emit_core", "plain_metal",
           (0, 0.06 * w, 0.038 * w), (0, 0, 0), 0.002, 1, M_parent=M_ksh)

    drop = kn.y - ft_y
    ft_rel = Vector((side * reach * 0.38, -drop + 0.048 * w, 0.0))
    M_tb = g2b_bone_mat((0, 0, 0), ft_rel)
    l2 = max(0.22, ft_rel.length - 0.08 * w)
    kb.box(f"LW{idx}_TbCore", (0.15 * w, l2, 0.19 * w), "dark", "frame_cnc",
           (0, -0.5 * ft_rel.length, 0), (0, 0, 0), 0.010, 1, M_parent=M_tb)
    kb.plate(f"LW{idx}_TbPlate", diamond_2d(0.26 * w, l2 * 0.96), 0.075 * w, "armor", "armor_slab",
             (side * 0.06 * w, -0.48 * ft_rel.length, 0.04 * w), (0, side * 90.0, 0), 0.012, 1, M_parent=M_tb)
    kb.box(f"LW{idx}_TbVein", (0.022 * w, l2 * 0.62, 0.026 * w), "emit_amber", "plain_metal",
           (side * 0.102 * w, -0.48 * ft_rel.length, 0.04 * w), (0, 0, 0), 0.002, 1, M_parent=M_tb)
    heavy_hyd(kb, f"LW{idx}_TbHyd", (-side * 0.04 * w, -0.08 * w, 0.0),
              (ft_rel.x * 0.78, ft_rel.y * 0.76, 0.0), r=0.024 * w, segs=8)

    # 3-prong angular ground-anchor talon foot flush at y = -drop!
    kb.plate(f"LW{idx}_FootBase", ngon_2d(6, 0.16 * w, 0.18 * w), 0.052 * w, "gunmetal", "bolt_flange",
             (ft_rel.x, -drop + 0.026 * w, 0.0), (90, 0, 0), 0.006, 1)
    for ca_deg in [-42.0, 0.0, 42.0]:
        cr = math.radians(ca_deg)
        cx = ft_rel.x + math.cos(cr) * side * 0.16 * w
        cz = math.sin(cr) * 0.16 * w
        kb.box(f"LW{idx}_Claw_{int(ca_deg+50)}", (0.11 * w, 0.040 * w, 0.056 * w), "chrome", "plain_metal",
               (cx, -drop + 0.020 * w, cz), (0, -side * ca_deg, 0), 0.004, 1)
    kb.use_group("Body")


# ==============================================================================
# 3. `Deathbringer` Heavy Multi-Axial Stabilizer Pillar Leg (Flush at y = 0.000m)
# ==============================================================================
def build_deathbringer_pillar_leg(kb: KitbashScene, idx: int, pos, yaw_deg: float, side: float,
                                  reach: float, hip_y: float, w: float = 1.0):
    """Horizon `Khopesh Deathbringer` heavy telescoping hydraulic stabilizer pillar leg flush at y = 0.000m."""
    g_hip = kb.add_group(f"Hip_{idx}", f"Hip_{idx}", pos=pos, rot_deg=(0.0, yaw_deg, 0.0))
    kb.use_group(g_hip)

    kn = Vector((side * reach * 0.74, 0.20 * w, 0.0))
    ft_y = -hip_y

    heavy_drum(kb, f"DB{idx}_HipDr", (0, 0, 0), 0.16 * w, 0.30 * w, segs=14, n_bolts=6)
    M_fm = g2b_bone_mat((0, 0, 0), kn)
    l1 = max(0.18, kn.length - 0.08 * w)
    kb.box(f"DB{idx}_Outrigger", (0.22 * w, l1, 0.26 * w), "dark", "frame_cnc",
           (0, -0.5 * kn.length, 0), (0, 0, 0), 0.012, 1, M_parent=M_fm)
    kb.plate(f"DB{idx}_OutArmor", trap_2d(0.28 * w, 0.32 * w, l1 * 0.92, 0.04 * w), 0.085 * w,
             "armor", "armor_slab", (0, -0.5 * kn.length, 0.14 * w), (0, 0, 0), 0.012, 1, M_parent=M_fm)
    heavy_hyd(kb, f"DB{idx}_OutRam", (side * 0.06 * w, -0.12 * w, 0.0),
              (kn.x - side * 0.08 * w, kn.y - 0.08 * w, 0.0), r=0.036 * w, segs=8)

    g_kn = kb.add_group(f"Hip_{idx}/Knee", "Knee", pos=(kn.x, kn.y, kn.z), parent_key=g_hip)
    kb.use_group(g_kn)
    heavy_drum(kb, f"DB{idx}_KnDr", (0, 0, 0), 0.14 * w, 0.28 * w, segs=14, n_bolts=6)

    drop = kn.y - ft_y
    ft_x = side * reach * 0.24
    h_up = drop * 0.56
    kb.plate(f"DB{idx}_HexShroud", ngon_2d(6, 0.16 * w, 0.17 * w), h_up, "armor", "armor_pocket",
             (ft_x * 0.65, -0.5 * h_up, 0.0), (90, 0, 0), 0.012, 1)
    kb.box(f"DB{idx}_HeatSlit", (0.022 * w, h_up * 0.58, 0.048 * w), "emit_core", "plain_metal",
           (ft_x * 0.65 + side * 0.155 * w, -0.46 * h_up, 0.0), (0, 0, 0), 0.002, 1)
    kb.cyl(f"DB{idx}_Collar", 0.125 * w, 0.130 * w, 0.052 * w, 14, "copper", "gear_collar",
           (ft_x * 0.85, -h_up - 0.024 * w, 0.0), (0, 0, 0), 0.004)
    ram_h = max(0.08, drop - h_up - 0.06 * w)
    kb.cyl(f"DB{idx}_Piston", 0.086 * w, 0.086 * w, ram_h, 14, "chrome", "plain_metal",
           (ft_x, -h_up - 0.5 * ram_h - 0.02 * w, 0.0), (0, 0, 0), 0.003)

    # Heavy octagonal Deathbringer stabilizer stomp pad + 4 perimeter tungsten talons flush at y = -drop
    kb.plate(f"DB{idx}_StompPad", ngon_2d(8, 0.24 * w, 0.24 * w, math.pi / 8.0), 0.064 * w,
             "armor_sub", "bolt_flange", (ft_x, -drop + 0.032 * w, 0.0), (90, 0, 0), 0.008, 1)
    for ti in range(4):
        ta = math.tau * ti / 4.0 + math.pi / 4.0
        kb.box(f"DB{idx}_Spur_{ti}", (0.09 * w, 0.042 * w, 0.065 * w), "chrome", "plain_metal",
               (ft_x + math.cos(ta) * 0.23 * w, -drop + 0.021 * w, math.sin(ta) * 0.23 * w),
               (0, -math.degrees(ta), 0), 0.004, 1)
    kb.use_group("Body")


# ==============================================================================
# 4. Mecha-Swarm Plasma Weapons, Blades, Augers & Reactor Cells
# ==============================================================================
def build_plasma_reaper_scythe(kb: KitbashScene, pfx: str, grp_name: str, pos, side: float,
                               w: float = 1.0, blade_len: float = 0.92):
    """Simulant / Grauwolf articulated strike-scythe with glowing neon-violet plasma cutting edge (`Scythe_*`)."""
    g_sc = kb.add_group(grp_name, grp_name, pos=pos)
    kb.use_group(g_sc)

    heavy_drum(kb, f"{pfx}_Shld", (0, 0, 0), 0.11 * w, 0.20 * w, segs=12)
    el = Vector((side * 0.16 * w, 0.14 * w, -0.44 * w))
    M_bm = g2b_bone_mat((0, 0, 0), el)
    kb.box(f"{pfx}_UpperArm", (0.12 * w, el.length * 0.90, 0.16 * w), "armor_sub", "frame_cnc",
           (0, -0.5 * el.length, 0), (0, 0, 0), 0.008, 1, M_parent=M_bm)
    heavy_hyd(kb, f"{pfx}_Hyd", (0, -0.10 * w, 0), (el.x, el.y - 0.08 * w, el.z + 0.04 * w), r=0.022 * w, segs=8)
    heavy_drum(kb, f"{pfx}_Elbow", (el.x, el.y, el.z), 0.095 * w, 0.18 * w, segs=12)

    # Swept multi-faceted forged-titanium cleaver blade + glowing purple plasma edge!
    M_bl = g2b_mat((el.x + side * 0.03 * w, el.y - 0.18 * w, el.z - blade_len * 0.44),
                   (32.0, -side * 8.0, 0.0))
    b_poly = [
        (-0.02 * w, blade_len * 0.50),
        (0.11 * w, blade_len * 0.24),
        (0.14 * w, -blade_len * 0.18),
        (0.02 * w, -blade_len * 0.52),
        (-0.06 * w, -blade_len * 0.10),
    ]
    M_bl_rot = M_bl @ g2b_mat((0, 0, 0), (0, 90.0, 0))
    kb.plate(f"{pfx}_Spine", b_poly, 0.056 * w, "gunmetal", "armor_slab",
             (0, 0, 0), (0, 0, 0), 0.008, 1, M_parent=M_bl_rot)
    edge_poly = [
        (0.09 * w, blade_len * 0.26),
        (0.165 * w, blade_len * 0.04),
        (0.175 * w, -blade_len * 0.22),
        (0.03 * w, -blade_len * 0.54),
        (0.12 * w, -blade_len * 0.16),
    ]
    kb.plate(f"{pfx}_PlasmaEdge", edge_poly, 0.022 * w, "emit_core", "plain_metal",
             (0, 0, 0), (0, 0, 0), 0.002, 1, M_parent=M_bl_rot)
    kb.use_group("Body")


def build_plasma_shear_pincers(kb: KitbashScene, pfx: str, z_front: float, y_pos: float,
                               span_x: float = 0.36, length: float = 0.68, w: float = 1.0):
    """Twin angular stealth-titanium plasma-cutter pincer blades (`Jaw_0`, `Jaw_1`)."""
    for si, sx in enumerate([-1.0, 1.0]):
        g_jw = kb.add_group(f"Jaw_{si}", f"Jaw_{si}", pos=(sx * span_x, y_pos, z_front))
        kb.use_group(g_jw)
        heavy_drum(kb, f"{pfx}_Piv_{si}", (0, 0, 0), 0.095 * w, 0.16 * w, segs=12)
        M_p = g2b_mat((-sx * 0.12 * w, -0.02 * w, -length * 0.46), (0.0, sx * 18.0, 0.0))
        kb.plate(f"{pfx}_Outer_{si}", trap_2d(0.20 * w, 0.07 * w, length, 0.02 * w), 0.078 * w,
                 "armor", "armor_slab", (0, 0, 0), (90, 0, 0), 0.010, 1, M_parent=M_p)
        kb.box(f"{pfx}_InnerGlow_{si}", (0.028 * w, 0.036 * w, length * 0.82), "emit_core", "plain_metal",
               (-sx * 0.075 * w, 0.0, -0.02 * w), (0, sx * 6.0, 0), 0.002, 1, M_parent=M_p)
    kb.use_group("Body")


def build_plasma_saw_boom(kb: KitbashScene, pfx: str, boom_idx: int, spin_idx: int,
                          pos, side: float, boom_len: float = 0.76, saw_r: float = 0.36):
    """Sleek gunmetal actuator arm spinning a 20-tooth violet-plasma circular rip-saw (`Scythe_*` + `Spinner_X_*`)."""
    g_bm = kb.add_group(f"Scythe_{boom_idx}", f"Scythe_{boom_idx}", pos=pos)
    kb.use_group(g_bm)
    heavy_drum(kb, f"{pfx}_Trun", (0, 0, 0), 0.105, 0.18, segs=12)
    kb.box(f"{pfx}_Boom", (0.11, 0.14, boom_len), "armor", "frame_cnc",
           (0.0, -0.03, -boom_len * 0.48), (8.0, 0, 0), 0.008, 1)
    heavy_hyd(kb, f"{pfx}_Hyd", (0.0, 0.14, -0.05), (0.0, 0.03, -boom_len * 0.72), r=0.022, segs=8)
    kb.cyl(f"{pfx}_Shroud", saw_r * 1.06, saw_r * 1.06, 0.068, 16, "armor_sub", "armor_panel",
           (side * 0.06, 0.06, -boom_len * 0.88), (0, 0, 90), 0.005, hollow_r=saw_r * 0.72)

    g_sp = kb.add_group(f"Scythe_{boom_idx}/Spinner_X_{spin_idx}", f"Spinner_X_{spin_idx}",
                        pos=(side * 0.08, -0.08, -boom_len * 0.96), parent_key=g_bm)
    kb.use_group(g_sp)
    kb.cyl(f"{pfx}_Disc", saw_r * 0.86, saw_r * 0.86, 0.026, 20, "dark", "bolt_flange",
           (0, 0, 0), (0, 0, 90), 0.003)
    kb.cyl(f"{pfx}_GlowRing", saw_r * 0.90, saw_r * 0.90, 0.014, 20, "emit_core", "plain_metal",
           (0, 0, 0), (0, 0, 90), 0.002, hollow_r=saw_r * 0.74)
    bm_t = bmesh.new()
    for ti in range(20):
        ta = math.tau * ti / 20.0
        ty, tz = math.cos(ta) * (saw_r * 0.88), math.sin(ta) * (saw_r * 0.88)
        M_t = g2b_mat((0.0, ty, tz), (-math.degrees(ta) + 16.0, 0.0, 0.0))
        _add_prism_local(bm_t, M_t, -0.015, 0.015, -0.005, saw_r * 0.17, 0.062, 0.018, cap_bottom=False)
    kb._finalize(f"{pfx}_SawTeeth", bm_t, "chrome", "plain_metal", Matrix.Identity(4), 0.002, 1)
    kb.use_group("Body")


def build_plasma_auger_head(kb: KitbashScene, pfx: str, group_name: str, pos,
                            r_base: float = 0.50, length: float = 0.94):
    """Conical 4-blade glowing-violet plasma subterranean tunneling auger (`Spinner_Z_0`, `rot_x = -90.0`)."""
    g_sp = kb.add_group(group_name, group_name, pos=pos)
    kb.use_group(g_sp)
    M_dr = g2b_mat((0, 0, 0), (-90.0, 0.0, 0.0))
    L = length
    kb.lathe(f"{pfx}_Cone", [
        (0.0, 0.0), (r_base, 0.0), (r_base, L * 0.16),
        (r_base * 0.82, L * 0.24), (r_base * 0.62, L * 0.54),
        (r_base * 0.34, L * 0.80), (0.0, L),
    ], 18, "dark", "weld_plate", u_rep=2.0, M_parent=M_dr)
    kb.cyl(f"{pfx}_GlowCollar", r_base * 1.03, r_base * 1.03, L * 0.08, 18, "emit_core", "plain_metal",
           (0, L * 0.10, 0), (0, 0, 0), 0.003, M_parent=M_dr)
    kb.cyl(f"{pfx}_Tip", 0.012, r_base * 0.22, L * 0.24, 12, "chrome", "plain_metal",
           (0, L * 0.90, 0), (0, 0, 0), 0.003, M_parent=M_dr)

    for ai in range(4):
        base_a = math.tau * ai / 4.0
        for sk in range(3):
            zf = 0.22 + sk * 0.24
            rr = r_base * (0.86 - sk * 0.22)
            a = base_a + sk * 0.42
            cx, cy, cz = math.cos(a) * rr, math.sin(a) * rr, -L * zf
            M_c = g2b_mat((cx, cy, cz), (0.0, 0.0, math.degrees(a)))
            kb.box(f"{pfx}_Blade_{ai}_{sk}", (0.16 * r_base, 0.055 * r_base * 2, 0.22 * L),
                   "chrome", "plain_metal", (0.04 * r_base, 0, 0), (0, 26, 0), 0.004, 1, M_parent=M_c)
            kb.box(f"{pfx}_Arc_{ai}_{sk}", (0.04 * r_base, 0.032 * r_base * 2, 0.18 * L),
                   "emit_core", "plain_metal", (0.11 * r_base, 0, 0), (0, 26, 0), 0.002, 1, M_parent=M_c)
    kb.use_group("Body")


def build_violet_phase_crystal(kb: KitbashScene, pfx: str, crys_grp_name: str,
                               pos, rot_deg=(0.0, 0.0, 0.0), h: float = 0.50, r: float = 0.082):
    """Faceted hexagonal glowing-violet phase-prism emitter locked in dark-titanium claws (`Crystal_*`)."""
    kb.use_group("Body")
    M_b = g2b_mat(pos, rot_deg)
    kb.cyl(f"{pfx}_Socket", r * 1.35, r * 1.45, h * 0.18, 6, "dark", "bolt_flange",
           (0, h * 0.09, 0), (0, 0, 0), 0.004, M_parent=M_b)
    for ci in range(3):
        ca = math.tau * ci / 3.0
        kb.box(f"{pfx}_Claw_{ci}", (r * 0.34, h * 0.46, r * 0.36), "gunmetal", "plain_metal",
               (math.cos(ca) * r * 1.04, h * 0.28, math.sin(ca) * r * 1.04),
               (-8.0, -math.degrees(ca), 0.0), 0.003, 1, M_parent=M_b)

    g_cr = kb.add_group(crys_grp_name, crys_grp_name, pos=pos, rot_deg=rot_deg)
    kb.use_group(g_cr)
    kb.cyl(f"{pfx}_Shaft", r * 0.86, r * 0.94, h * 0.68, 6, "emit_core", "plain_metal",
           (0, h * 0.44, 0), (0, 0, 0), 0.003)
    kb.cyl(f"{pfx}_Apex", 0.008, r * 0.86, h * 0.24, 6, "emit_core", "plain_metal",
           (0, h * 0.90, 0), (0, 0, 0), 0.002)
    kb.use_group("Body")


def build_plasma_core_pod(kb: KitbashScene, pfx: str, sac_grp_name: str,
                          pos, r: float = 0.22, length: float = 0.54):
    """Armored octagonal dark-gunmetal plasma incubation / capacitor cell with blazing violet core (`Sac_*`)."""
    kb.use_group("Body")
    M_b = g2b_mat(pos, (0, 0, 0))
    for ri, rz in enumerate([-length * 0.36, length * 0.36]):
        kb.cyl(f"{pfx}_Rib_{ri}", r * 1.15, r * 1.15, 0.048, 8, "gunmetal", "bolt_flange",
               (0, 0, rz), (90, 0, 0), 0.004, hollow_r=r * 0.96, M_parent=M_b)

    g_sac = kb.add_group(sac_grp_name, sac_grp_name, pos=pos)
    kb.use_group(g_sac)
    kb.cyl(f"{pfx}_CoreCell", r * 0.96, r * 0.92, length * 0.92, 8, "emit_core", "plain_metal",
           (0, 0, 0), (90, 0, 0), 0.006)
    kb.box(f"{pfx}_SpineCap", (r * 0.62, r * 0.28, length * 0.84), "armor_dark", "armor_panel",
           (0, r * 0.88, 0), (0, 0, 0), 0.005, 1)
    kb.use_group("Body")
