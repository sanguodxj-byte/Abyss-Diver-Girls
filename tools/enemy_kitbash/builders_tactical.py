"""
Batch B — Sci-Fi Mecha-Swarm Tactical Specialist Builders (6 Units, *86 Legion / HZD Faro / SC2 Simulant* Dark-Gunmetal + Violet):
  7.  `crystal_bug` : 6-Legged Phase-Refractor Prism Scarab
  8.  `burrower`    : 6-Legged Subterranean Plasma-Auger Wyrm
  9.  `mech_beetle` : 6-Legged `Rabe`-Type Stealth EW Interference Walker
  10. `shielder`    : 4-Legged Toroidal Phase-Barrier Conduit Walker
  11. `mortar`      : 4-Legged `Deathbringer`-Style Quad-Cell Plasma-Mortar Walker
  12. `ironjaw`     : 6-Legged `Mecha-Ultralisk` Twin-Cleaver Shredder Juggernaut
"""
import math
import bmesh
from mathutils import Matrix
from kitbash_lib import KitbashScene, g2b_mat, trap_2d
from leg_rig_lib import _add_prism_local
from swarm_rig_lib import (
    ngon_2d,
    diamond_2d,
    build_ameise_blade_leg,
    build_lowe_arthropod_leg,
    build_deathbringer_pillar_leg,
    build_plasma_shear_pincers,
    build_plasma_auger_head,
    build_violet_phase_crystal,
    build_plasma_core_pod,
)


# ==============================================================================
# 7. crystal_bug — 6-Legged Phase-Refractor Prism Scarab (s = 1.35)
# ==============================================================================
def build_crystal_bug(kb: KitbashScene):
    by = 0.56
    kb.use_group("Body")

    kb.plate("PrismCarapace", ngon_2d(8, 0.62, 0.82, math.pi / 8.0), 0.34, "dark", "frame_cnc",
             (0.0, by + 0.04, 0.06), (90, 0, 0), 0.016, 1)
    kb.plate("TopShell", diamond_2d(1.12, 1.48), 0.12, "armor", "armor_slab",
             (0.0, by + 0.24, 0.06), (90, 0, 0), 0.014, 1)
    kb.plate("DeflectorProw", ngon_2d(6, 0.56, 0.36), 0.11, "armor_sub", "weld_plate",
             (0.0, by + 0.10, -0.74), (32.0, 0, 0), 0.014, 1)
    kb.cyl("ProwLens", 0.14, 0.14, 0.04, 6, "emit_core", "plain_metal",
           (0.0, by + 0.10, -0.79), (122.0, 0, 0), 0.003)

    # 8 Angled Hexagonal Glowing-Violet Phase Crystals (`Crystal_0..7`)
    for ci in range(8):
        ang = math.tau * ci / 8.0 + 0.25
        rx, rz = math.cos(ang) * 0.32, 0.10 + math.sin(ang) * 0.38
        build_violet_phase_crystal(kb, f"PhaseCrys_{ci}", f"Crystal_{ci}",
                                   (rx, by + 0.26, rz),
                                   (math.sin(ang) * 16.0, 0.0, -math.cos(ang) * 16.0),
                                   h=0.54 if ci % 2 == 0 else 0.42, r=0.078)

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.36, -28.0), (0.08, 0.0), (0.52, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_lowe_arthropod_leg(kb, ri * 2 + si, (sx * 0.48, hip_y, hz), sx * yaw_a, sx, 0.76, hip_y, w=0.98)


# ==============================================================================
# 8. burrower — 6-Legged Subterranean Plasma-Auger Wyrm (s = 1.05)
# ==============================================================================
def build_burrower(kb: KitbashScene):
    by = 0.54
    kb.use_group("Body")

    # Segmented octagonal tunneling hull + glowing purple dorsal spines + conical plasma auger (`Spinner_Z_0`)
    for si in range(3):
        sc_k = 1.0 - si * 0.10
        kb.plate(f"WyrmSeg_{si}", ngon_2d(8, 0.44 * sc_k, 0.42 * sc_k, math.pi / 8.0), 0.40,
                 "armor" if si % 2 == 0 else "armor_sub", "armor_slab",
                 (0.0, by + 0.06, -0.22 + si * 0.42), (0, 0, 0), 0.012, 1)
        kb.cyl(f"SegSeam_{si}", 0.43 * sc_k, 0.43 * sc_k, 0.032, 8, "emit_core", "plain_metal",
               (0.0, by + 0.06, -0.02 + si * 0.42), (90, 0, 0), 0.002)

    build_plasma_auger_head(kb, "WyrmAuger", "Spinner_Z_0", (0.0, by + 0.06, -0.44), r_base=0.44, length=0.82)

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.24, -26.0), (0.16, 4.0), (0.56, 34.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_lowe_arthropod_leg(kb, ri * 2 + si, (sx * 0.40, hip_y, hz), sx * yaw_a, sx, 0.68, hip_y, w=0.90)


# ==============================================================================
# 9. mech_beetle — 6-Legged `Rabe`-Type Stealth EW Interference Walker (s = 1.32)
# ==============================================================================
def build_mech_beetle(kb: KitbashScene):
    by = 0.56
    kb.use_group("Body")

    kb.box("EWCore", (0.78, 0.30, 1.32), "dark", "frame_cnc", (0.0, by, 0.04), (0, 0, 0), 0.014, 1)
    kb.plate("EWCarapace", diamond_2d(1.08, 1.46), 0.13, "armor", "armor_slab",
             (0.0, by + 0.20, 0.04), (90, 0, 0), 0.014, 1)
    kb.box("ScannerSlit", (0.44, 0.038, 0.030), "emit_core", "plain_metal", (0.0, by + 0.08, -0.66), (0, 0, 0), 0.002, 1)

    # Rotating faceted stealth EW dish & violet interference emitter bar (`Spinner_Y_0`)
    kb.cyl("DishHub", 0.22, 0.26, 0.14, 8, "gunmetal", "gear_collar", (0.0, by + 0.32, 0.06), (0, 0, 0), 0.005)
    g_sp = kb.add_group("Spinner_Y_0", "Spinner_Y_0", pos=(0.0, by + 0.40, 0.06))
    kb.use_group(g_sp)
    kb.plate("StealthDome", ngon_2d(8, 0.52, 0.52, math.pi / 8.0), 0.12, "armor_sub", "armor_panel",
             (0.0, 0.06, 0.0), (90, 0, 0), 0.012, 1)
    kb.cyl("DomeGlow", 0.53, 0.53, 0.026, 8, "emit_core", "plain_metal",
           (0.0, 0.06, 0.0), (0, 0, 0), 0.002, hollow_r=0.44)
    kb.box("JammerWing", (1.08, 0.10, 0.14), "dark", "bolt_flange", (0.0, 0.16, 0.0), (0, 0, 0), 0.006, 1)
    kb.box("JammerSlit", (0.92, 0.045, 0.028), "emit_core", "plain_metal", (0.0, 0.16, -0.072), (0, 0, 0), 0.002, 1)
    kb.use_group("Body")

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.38, -28.0), (0.06, 0.0), (0.50, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_lowe_arthropod_leg(kb, ri * 2 + si, (sx * 0.46, hip_y, hz), sx * yaw_a, sx, 0.74, hip_y, w=0.96)


# ==============================================================================
# 10. shielder — 4-Legged Toroidal Phase-Barrier Conduit Walker (s = 0.95)
# ==============================================================================
def build_shielder(kb: KitbashScene):
    by = 0.56
    kb.use_group("Body")

    kb.plate("ConduitHull", ngon_2d(8, 0.46, 0.56, math.pi / 8.0), 0.26, "dark", "frame_cnc",
             (0.0, by, 0.0), (90, 0, 0), 0.012, 1)
    kb.plate("ConduitShell", diamond_2d(0.76, 0.98), 0.10, "armor", "armor_slab",
             (0.0, by + 0.16, 0.0), (90, 0, 0), 0.012, 1)
    kb.cyl("FrontEye", 0.11, 0.11, 0.04, 8, "emit_core", "plain_metal", (0.0, by + 0.04, -0.52), (90, 0, 0), 0.002)

    g_cr = kb.add_group("Crown", "Crown", pos=(0.0, by + 0.22, 0.0))
    kb.use_group(g_cr)
    g_sp = kb.add_group("Crown/Spinner_Y_0", "Spinner_Y_0", pos=(0.0, 0.18, 0.0), parent_key=g_cr)
    kb.use_group(g_sp)
    kb.cyl("PhaseRing", 0.42, 0.42, 0.09, 8, "gunmetal", "bolt_flange", (0, 0.04, 0), (0, 0, 0), 0.006, hollow_r=0.28)
    kb.cyl("VioletCore", 0.12, 0.10, 0.34, 8, "emit_core", "plain_metal", (0, 0.10, 0), (0, 0, 0), 0.003)
    for pi in range(4):
        pa = math.tau * pi / 4.0
        kb.box(f"Prong_{pi}", (0.075, 0.22, 0.10), "armor_sub", "armor_panel",
               (math.cos(pa) * 0.36, 0.10, math.sin(pa) * 0.36), (-14.0, -math.degrees(pa), 0), 0.004, 1)
    kb.use_group("Body")

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.26, -30.0), (0.28, 30.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_ameise_blade_leg(kb, ri * 2 + si, (sx * 0.32, hip_y, hz), sx * yaw_a, sx, 0.66, hip_y, w=0.88)


# ==============================================================================
# 11. mortar — 4-Legged `Deathbringer`-Style Quad-Cell Plasma-Mortar Walker (s = 1.08)
# ==============================================================================
def build_mortar(kb: KitbashScene):
    by = 0.58
    kb.use_group("Body")

    kb.box("SiegeBase", (0.76, 0.30, 1.18), "dark", "frame_cnc", (0.0, by, 0.04), (0, 0, 0), 0.014, 1)
    kb.plate("FrontShield", diamond_2d(0.84, 0.56), 0.11, "armor", "armor_slab",
             (0.0, by + 0.10, -0.56), (48.0, 0, 0), 0.012, 1)
    kb.box("TargetSlit", (0.34, 0.036, 0.028), "emit_core", "plain_metal", (0.0, by + 0.12, -0.64), (0, 0, 0), 0.002, 1)

    # Elevating stealth-armored quad plasma-mortar pod (`Abdomen` + `GunTip`)
    g_ab = kb.add_group("Abdomen", "Abdomen", pos=(0.0, by + 0.22, 0.18))
    kb.use_group(g_ab)
    kb.box("LauncherPod", (0.62, 0.38, 0.72), "armor_sub", "armor_pocket", (0.0, 0.14, -0.18), (36.0, 0, 0), 0.014, 1)
    M_cr = g2b_mat((0.0, 0.14, -0.18), (36.0, 0, 0))
    for ti, (tx, ty) in enumerate([(-0.14, -0.08), (0.14, -0.08), (-0.14, 0.10), (0.14, 0.10)]):
        kb.cyl(f"PlasmaTube_{ti}", 0.092, 0.098, 0.68, 8, "gunmetal", "plain_metal",
               (tx, ty, -0.34), (90, 0, 0), 0.005, M_parent=M_cr)
        kb.cyl(f"TubeGlow_{ti}", 0.068, 0.068, 0.04, 8, "emit_core", "plain_metal",
               (tx, ty, -0.67), (90, 0, 0), 0.002, M_parent=M_cr)
    kb.add_group("Abdomen/GunTip", "GunTip", pos=(0.0, 0.58, -0.62), parent_key=g_ab)
    kb.use_group("Body")

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.32, -28.0), (0.38, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_deathbringer_pillar_leg(kb, ri * 2 + si, (sx * 0.42, hip_y, hz), sx * yaw_a, sx, 0.64, hip_y, w=0.94)


# ==============================================================================
# 12. ironjaw — 6-Legged `Mecha-Ultralisk` Twin-Cleaver Shredder Juggernaut (s = 1.55)
# ==============================================================================
def build_ironjaw(kb: KitbashScene):
    by = 0.64
    kb.use_group("Body")

    kb.box("JuggernautCore", (0.96, 0.42, 1.48), "dark", "frame_cnc", (0.0, by, 0.10), (0, 0, 0), 0.018, 1)
    kb.plate("JuggernautBack", diamond_2d(1.28, 1.62), 0.16, "armor", "armor_slab",
             (0.0, by + 0.26, 0.10), (90, 0, 0), 0.016, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"ShoulderCowl_{si}", trap_2d(0.76, 0.48, 0.46, 0.04), 0.09, "armor_sub", "armor_panel",
                 (sx * 0.56, by + 0.16, -0.22), (0, -sx * 78.0, -sx * 16.0), 0.012, 1)
    kb.box("RageVisor", (0.52, 0.048, 0.032), "emit_core", "plain_metal", (0.0, by + 0.18, -0.68), (0, 0, 0), 0.002, 1)
    build_plasma_core_pod(kb, "JawReactor", "SacMain", (0.0, by + 0.22, 0.88), r=0.24, length=0.42)

    # Twin oversized plasma-edge shear mandibles (`Jaw_0`, `Jaw_1`) + throat rotary plasma grinder (`Spinner_X_0`)
    build_plasma_shear_pincers(kb, "UltraJaw", z_front=-0.66, y_pos=by - 0.04, span_x=0.44, length=0.92, w=1.28)

    g_dr = kb.add_group("Spinner_X_0", "Spinner_X_0", pos=(0.0, by - 0.04, -0.68))
    kb.use_group(g_dr)
    kb.cyl("ThroatDrum", 0.20, 0.20, 0.68, 14, "gunmetal", "gear_collar", (0, 0, 0), (0, 0, 90), 0.005)
    kb.cyl("ThroatGlow", 0.205, 0.205, 0.16, 14, "emit_core", "plain_metal", (0, 0, 0), (0, 0, 90), 0.002)
    bm_t = bmesh.new()
    for rx in [-0.24, 0.0, 0.24]:
        for ti in range(8):
            ta = math.tau * ti / 8.0 + rx
            ty, tz = math.cos(ta) * 0.195, math.sin(ta) * 0.195
            M_t = g2b_mat((rx, ty, tz), (-math.degrees(ta), 0.0, 0.0))
            _add_prism_local(bm_t, M_t, -0.024, 0.024, -0.005, 0.075, 0.065, 0.020, cap_bottom=False)
    kb._finalize("GrinderTeeth", bm_t, "chrome", "plain_metal", Matrix.Identity(4), 0.002, 1)
    kb.use_group("Body")

    hip_y = by - 0.08
    for ri, (hz, yaw_a) in enumerate([(-0.38, -28.0), (0.10, 0.0), (0.58, 34.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_lowe_arthropod_leg(kb, ri * 2 + si, (sx * 0.52, hip_y, hz), sx * yaw_a, sx, 0.84, hip_y, w=1.08)
