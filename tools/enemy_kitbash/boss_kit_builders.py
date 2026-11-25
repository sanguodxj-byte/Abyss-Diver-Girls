"""
Sci-Fi Mecha-Swarm Boss Articulated Hardware Kit Builders (`assets/models/boss/kit_boss_*.glb`).
100% Unified *86 Legion / HZD Faro / SC2 Simulant* Dark-Gunmetal + Neon-Violet Design Language!
"""
import math
import bmesh
from mathutils import Vector, Matrix
from kitbash_lib import KitbashScene, g2b_mat, g2b_bone_mat, crect_2d, trap_2d
from leg_rig_lib import heavy_hyd, heavy_drum, _add_prism_local
from swarm_rig_lib import (
    ngon_2d,
    diamond_2d,
    build_plasma_auger_head,
    build_violet_phase_crystal,
)


def build_kit_boss_chassis(kb: KitbashScene):
    """Faceted octagonal stealth under-carapace chassis linking Boss hull to articulated Legion legs."""
    kb.use_group("Body")
    kb.plate("OctChassis", ngon_2d(8, 0.72, 0.92, math.pi / 8.0), 0.24, "dark", "frame_cnc",
             (0, 0, 0), (90, 0, 0), 0.016, 1)
    for zi, zz in enumerate([-0.52, 0.0, 0.52]):
        kb.box(f"OutriggerRib_{zi}", (1.56, 0.18, 0.24), "gunmetal", "bolt_flange", (0, 0.02, zz), (0, 0, 0), 0.010, 1)
    kb.box("BellyVein", (0.14, 0.04, 1.36), "emit_core", "plain_metal", (0, -0.125, 0), (0, 0, 0), 0.002, 1)


def _build_femur_side(kb: KitbashScene, side: float):
    """86-Lowe style stealth-faceted upper femur & silver hydraulic cylinder (0,0,0 -> side*0.64, +0.34, 0)."""
    kb.use_group("Body")
    kn = Vector((side * 0.64, 0.34, 0.0))
    heavy_drum(kb, "HipDrum", (0, 0, 0), 0.18, 0.34, segs=14, n_bolts=6)
    kb.cyl("HipGlow", 0.188, 0.188, 0.032, 14, "emit_core", "plain_metal", (side * 0.12, 0, 0), (0, 0, 90), 0.002)
    M_fm = g2b_bone_mat((0, 0, 0), kn)
    l1 = kn.length - 0.10
    kb.box("FemCore", (0.24, l1, 0.28), "dark", "frame_cnc", (0, -0.5 * kn.length, 0), (0, 0, 0), 0.012, 1, M_parent=M_fm)
    kb.plate("FemArmor", diamond_2d(0.38, l1 * 1.04), 0.10, "armor", "armor_slab",
             (0, -0.5 * kn.length, 0.15), (0, 0, 0), 0.014, 1, M_parent=M_fm)
    kb.box("FemVein", (0.045, l1 * 0.68, 0.028), "emit_core", "plain_metal",
           (0, -0.5 * kn.length, 0.205), (0, 0, 0), 0.002, 1, M_parent=M_fm)
    heavy_hyd(kb, "FemHyd", (side * 0.06, -0.14, 0.0), (kn.x - side * 0.08, kn.y - 0.10, 0.0), r=0.040, segs=10)
    heavy_drum(kb, "KneeDrum", (kn.x, kn.y, kn.z), 0.16, 0.32, segs=14, n_bolts=6)


def build_kit_boss_femur_r(kb: KitbashScene):
    _build_femur_side(kb, 1.0)


def build_kit_boss_femur_l(kb: KitbashScene):
    _build_femur_side(kb, -1.0)


def build_kit_boss_talon_foot(kb: KitbashScene):
    """Angular 3-prong forged-titanium ground-anchor talon pad strictly flush at y = 0.000m!"""
    kb.use_group("Body")
    kb.plate("TalonHub", ngon_2d(6, 0.30, 0.32), 0.08, "gunmetal", "bolt_flange",
             (0, 0.040, 0), (90, 0, 0), 0.008, 1)
    for ti in range(4):
        ta = math.tau * ti / 4.0 + math.pi / 4.0
        kb.plate(f"TalonSpur_{ti}", trap_2d(0.14, 0.06, 0.28, 0.01), 0.056, "chrome", "plain_metal",
                 (math.cos(ta) * 0.30, 0.028, math.sin(ta) * 0.30),
                 (90, -math.degrees(ta) + 90.0, 0), 0.005, 1)


def _build_arm_boom_side(kb: KitbashScene, side: float):
    kb.use_group("Body")
    el = Vector((side * 0.22, -0.06, -0.46))
    heavy_drum(kb, "ShldDrum", (0, 0, 0), 0.15, 0.26, segs=12)
    M_bm = g2b_bone_mat((0, 0, 0), el)
    kb.box("ArmBeam", (0.18, el.length * 0.90, 0.22), "armor", "frame_cnc",
           (0, -0.5 * el.length, 0), (0, 0, 0), 0.010, 1, M_parent=M_bm)
    heavy_hyd(kb, "ArmHyd", (0, 0.14, -0.04), (el.x, el.y + 0.10, el.z + 0.06), r=0.032, segs=8)
    heavy_drum(kb, "WristDrum", (el.x, el.y, el.z), 0.13, 0.22, segs=12)


def build_kit_boss_arm_boom_r(kb: KitbashScene):
    _build_arm_boom_side(kb, 1.0)


def build_kit_boss_arm_boom_l(kb: KitbashScene):
    _build_arm_boom_side(kb, -1.0)


def build_kit_boss_core_vault(kb: KitbashScene):
    """Hexagonal stealth blast-vault housing a blazing neon-violet reactor crystal (`CoreGlow`)."""
    kb.use_group("Body")
    kb.plate("VaultHex", ngon_2d(6, 0.44, 0.34), 0.26, "dark", "bolt_flange", (0, 0, 0.06), (0, 0, 0), 0.014, 1)
    g_cg = kb.add_group("CoreGlow", "CoreGlow", pos=(0.0, 0.0, -0.05))
    kb.use_group(g_cg)
    kb.cyl("VioletHeart", 0.20, 0.20, 0.16, 6, "emit_core", "plain_metal", (0, 0, 0), (90, 0, 0), 0.004)


def _build_core_door_side(kb: KitbashScene, side: float):
    kb.use_group("Body")
    ox = -side * 0.18
    kb.plate("HexDoor", diamond_2d(0.38, 0.52), 0.085, "armor", "armor_slab", (ox, 0, 0), (0, 0, 0), 0.010, 1)
    kb.box("DoorVein", (0.036, 0.36, 0.028), "emit_core", "plain_metal", (ox + side * 0.10, 0, -0.046), (0, 0, 0), 0.002, 1)


def build_kit_boss_core_door_r(kb: KitbashScene):
    _build_core_door_side(kb, 1.0)


def build_kit_boss_core_door_l(kb: KitbashScene):
    _build_core_door_side(kb, -1.0)


def build_kit_boss_plasma_pod(kb: KitbashScene):
    """Dorsal faceted dark-titanium plasma incubation/capacitor pod (`Sac_*`)."""
    kb.use_group("Body")
    kb.cyl("PodSocket", 0.24, 0.28, 0.10, 8, "dark", "bolt_flange", (0, 0.05, 0), (0, 0, 0), 0.005)
    kb.cyl("PlasmaCell", 0.20, 0.18, 0.44, 8, "emit_core", "plain_metal", (0, 0.28, 0), (0, 0, 0), 0.008)
    for bi in range(4):
        ba = math.tau * bi / 4.0 + math.pi / 4.0
        kb.box(f"PodRib_{bi}", (0.042, 0.48, 0.048), "gunmetal", "armor_panel",
               (math.cos(ba) * 0.21, 0.28, math.sin(ba) * 0.21), (0, -math.degrees(ba), 0), 0.004, 1)
    kb.plate("PodCrown", ngon_2d(8, 0.20, 0.20), 0.06, "armor_sub", "armor_slab", (0, 0.52, 0), (90, 0, 0), 0.006, 1)


def _build_plasma_jaw_side(kb: KitbashScene, side: float):
    kb.use_group("Body")
    heavy_drum(kb, "JawPivot", (0, 0, 0), 0.12, 0.20, segs=12)
    M_j = g2b_mat((-side * 0.14, -0.02, -0.44), (0.0, side * 18.0, 0.0))
    kb.plate("JawBlade", trap_2d(0.24, 0.08, 0.88, 0.02), 0.095, "armor", "armor_slab",
             (0, 0, 0), (90, 0, 0), 0.012, 1, M_parent=M_j)
    kb.box("JawPlasma", (0.032, 0.042, 0.74), "emit_core", "plain_metal",
           (-side * 0.09, 0.0, -0.02), (0, side * 6.0, 0), 0.002, 1, M_parent=M_j)


def build_kit_boss_plasma_jaw_r(kb: KitbashScene):
    _build_plasma_jaw_side(kb, 1.0)


def build_kit_boss_plasma_jaw_l(kb: KitbashScene):
    _build_plasma_jaw_side(kb, -1.0)


def build_kit_boss_plasma_saw(kb: KitbashScene):
    """Giant 22-tooth dark-titanium & glowing-violet circular plasma rip-saw (`Spinner_X_0`)."""
    kb.use_group("Body")
    kb.cyl("SawGuard", 0.62, 0.62, 0.10, 16, "armor_sub", "armor_panel", (0, 0.08, 0.08), (0, 0, 90), 0.006, hollow_r=0.44)
    g_sp = kb.add_group("Spinner_X_0", "Spinner_X_0", pos=(0.0, 0.0, 0.0))
    kb.use_group(g_sp)
    kb.cyl("SawDisc", 0.54, 0.54, 0.036, 22, "dark", "bolt_flange", (0, 0, 0), (0, 0, 90), 0.004)
    kb.cyl("SawGlow", 0.56, 0.56, 0.018, 22, "emit_core", "plain_metal", (0, 0, 0), (0, 0, 90), 0.002, hollow_r=0.42)
    bm_t = bmesh.new()
    for ti in range(22):
        ta = math.tau * ti / 22.0
        ty, tz = math.cos(ta) * 0.55, math.sin(ta) * 0.55
        M_t = g2b_mat((0.0, ty, tz), (-math.degrees(ta) + 16.0, 0.0, 0.0))
        _add_prism_local(bm_t, M_t, -0.022, 0.022, -0.006, 0.095, 0.082, 0.024, cap_bottom=False)
    kb._finalize("SawTeeth", bm_t, "chrome", "plain_metal", Matrix.Identity(4), 0.002, 1)


def build_kit_boss_plasma_auger(kb: KitbashScene):
    """Full-section Boss conical violet-plasma tunneling auger (`Spinner_Z_0`)."""
    build_plasma_auger_head(kb, "BossAuger", "Spinner_Z_0", (0.0, 0.0, 0.0), r_base=0.56, length=1.02)


def build_kit_boss_pulse_gatling(kb: KitbashScene):
    """Sleek stealth-shrouded 6-barrel rotary purple pulse-cannon pod (`Spinner_Z_0`)."""
    kb.use_group("Body")
    kb.plate("GatShroud", diamond_2d(0.42, 0.68), 0.32, "armor", "armor_pocket", (0, 0, 0.10), (90, 0, 0), 0.014, 1)
    kb.box("GatVein", (0.40, 0.036, 0.34), "emit_core", "plain_metal", (0, 0.04, 0.12), (0, 0, 0), 0.002, 1)
    g_sp = kb.add_group("Spinner_Z_0", "Spinner_Z_0", pos=(0.0, 0.0, -0.18))
    kb.use_group(g_sp)
    kb.cyl("RotorHub", 0.13, 0.13, 0.14, 12, "gunmetal", "gear_collar", (0, 0, -0.04), (90, 0, 0), 0.004)
    for bi in range(6):
        ba = math.tau * bi / 6.0
        bx, by_b = math.cos(ba) * 0.082, math.sin(ba) * 0.082
        kb.cyl(f"PulseBrl_{bi}", 0.026, 0.028, 0.72, 10, "chrome", "plain_metal", (bx, by_b, -0.38), (90, 0, 0), 0.002)


def build_kit_boss_phase_crown(kb: KitbashScene):
    """Octagonal dark-titanium & glowing-violet phase-crystal emitter ring (`Crystal_0..5`)."""
    kb.use_group("Body")
    kb.plate("CrownRing", ngon_2d(8, 0.56, 0.56, math.pi / 8.0), 0.10, "gunmetal", "bolt_flange",
             (0, 0.06, 0), (90, 0, 0), 0.010, 1)
    kb.cyl("CrownGlow", 0.57, 0.57, 0.028, 8, "emit_core", "plain_metal", (0, 0.06, 0), (0, 0, 0), 0.002, hollow_r=0.42)
    for ki in range(6):
        ka = math.tau * ki / 6.0
        build_violet_phase_crystal(kb, f"CrownCrys_{ki}", f"Crystal_{ki}",
                                   (math.cos(ka) * 0.46, 0.10, math.sin(ka) * 0.46),
                                   (0, -math.degrees(ka), -10.0), h=0.46, r=0.076)
