"""
Batch A — Sci-Fi Mecha-Swarm Vanguard Builders (6 Units, *86 Legion / HZD Faro / SC2 Simulant* Dark-Gunmetal + Violet):
  1. `ling`    : `Ameise`-Type 4-Legged Stealth Blade-Stalker
  2. `spitter` : `Skorpion`-Type 6-Legged Twin-Rail Plasma-Acid Crawler
  3. `beetle`  : `Corruptor`-Type 6-Legged Twin-Horn Plasma-Ram Juggernaut
  4. `mantis`  : `Grauwolf`-Type 4-Legged Twin-Plasma-Scythe Hunter
  5. `bomber`  : `Mecha-Baneling` 4-Legged Volatile Singularity-Core Crawler
  6. `wasp`    : `Eintagsfliege`-Type Swept-Delta Stealth Ion-Turbine Strike Drone
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, trap_2d
from leg_rig_lib import heavy_hyd
from swarm_rig_lib import (
    ngon_2d,
    diamond_2d,
    build_ameise_blade_leg,
    build_lowe_arthropod_leg,
    build_plasma_reaper_scythe,
    build_plasma_shear_pincers,
    build_plasma_core_pod,
)


# ==============================================================================
# 1. ling — `Ameise`-Type 4-Legged Stealth Blade-Stalker (s = 0.68)
# ==============================================================================
def build_ling(kb: KitbashScene):
    by = 0.44
    kb.use_group("Body")

    # Sleek diamond-faceted stealth carapace + swept dorsal cooling fins + V-shaped violet laser visor
    kb.box("SpineCore", (0.34, 0.20, 0.88), "dark", "frame_cnc", (0.0, by, 0.04), (0, 0, 0), 0.010, 1)
    kb.plate("DorsalCarapace", diamond_2d(0.56, 1.02), 0.095, "armor", "armor_slab",
             (0.0, by + 0.12, 0.04), (94.0, 0, 0), 0.012, 1)
    kb.plate("ProwWedge", diamond_2d(0.46, 0.48), 0.085, "armor_sub", "armor_panel",
             (0.0, by + 0.04, -0.44), (62.0, 0, 0), 0.010, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"VisorSlit_{si}", (0.16, 0.026, 0.024), "emit_core", "plain_metal",
               (sx * 0.095, by + 0.05, -0.58), (0, -sx * 24.0, -sx * 10.0), 0.002, 1)
        kb.plate(f"TailFin_{si}", trap_2d(0.08, 0.03, 0.34, 0.01), 0.036, "hazard", "plain_metal",
                 (sx * 0.14, by + 0.18, 0.42), (-32.0, sx * 12.0, 0), 0.004, 1)

    build_plasma_shear_pincers(kb, "LingShear", z_front=-0.52, y_pos=by - 0.04, span_x=0.18, length=0.44, w=0.68)

    hip_y = by - 0.04
    for ri, (hz, yaw_a) in enumerate([(-0.24, -28.0), (0.28, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_ameise_blade_leg(kb, ri * 2 + si, (sx * 0.24, hip_y, hz), sx * yaw_a, sx, 0.56, hip_y, w=0.78)


# ==============================================================================
# 2. spitter — `Skorpion`-Type 6-Legged Twin-Rail Plasma-Acid Crawler (s = 0.95)
# ==============================================================================
def build_spitter(kb: KitbashScene):
    by = 0.50
    kb.use_group("Body")

    kb.box("ThoraxCore", (0.54, 0.26, 1.12), "dark", "frame_cnc", (0.0, by, 0.06), (0, 0, 0), 0.012, 1)
    kb.plate("ThoraxShield", diamond_2d(0.78, 1.18), 0.11, "armor", "armor_slab",
             (0.0, by + 0.16, 0.06), (92.0, 0, 0), 0.014, 1)
    kb.box("OpticVisor", (0.32, 0.036, 0.028), "emit_core", "plain_metal", (0.0, by + 0.06, -0.56), (0, 0, 0), 0.002, 1)

    # Rear plasma gestation / propellant cell (`SacMain`)
    build_plasma_core_pod(kb, "SpitCell", "SacMain", (0.0, by + 0.18, 0.56), r=0.18, length=0.46)

    # Dorsal articulated twin-rail violet plasma cannon (`Gun` + `GunTip` + `GunGlow`)
    g_gun = kb.add_group("Gun", "Gun", pos=(0.0, by + 0.30, -0.06))
    kb.use_group(g_gun)
    kb.box("CannonBreech", (0.34, 0.20, 0.54), "armor_sub", "armor_pocket", (0.0, 0.0, 0.06), (0, 0, 0), 0.010, 1)
    for ri, rx in enumerate([-0.085, 0.085]):
        kb.plate(f"RailShroud_{ri}", trap_2d(0.09, 0.06, 0.96, 0.01), 0.11, "gunmetal", "armor_slab",
                 (rx, 0.0, -0.54), (90, 0, 0), 0.006, 1)
    kb.add_group("Gun/GunTip", "GunTip", pos=(0.0, 0.0, -1.04), parent_key=g_gun)
    g_gl = kb.add_group("Gun/GunGlow", "GunGlow", pos=(0.0, 0.0, -0.56), parent_key=g_gun)
    kb.use_group(g_gl)
    kb.box("AccelGlow", (0.055, 0.048, 0.86), "emit_core", "plain_metal", (0, 0, 0), (0, 0, 0), 0.002, 1)
    kb.use_group("Body")

    hip_y = by - 0.04
    for ri, (hz, yaw_a) in enumerate([(-0.34, -32.0), (0.04, 0.0), (0.42, 34.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_ameise_blade_leg(kb, ri * 2 + si, (sx * 0.32, hip_y, hz), sx * yaw_a, sx, 0.66, hip_y, w=0.86)


# ==============================================================================
# 3. beetle — `Corruptor`-Type 6-Legged Twin-Horn Plasma-Ram Juggernaut (s = 1.45)
# ==============================================================================
def build_beetle(kb: KitbashScene):
    by = 0.58
    kb.use_group("Body")

    # Wide layered stealth-scarab carapace + glowing dorsal heat-sink slits
    kb.box("ScarabCore", (0.88, 0.36, 1.38), "dark", "frame_cnc", (0.0, by, 0.08), (0, 0, 0), 0.016, 1)
    for li in range(3):
        kb.plate(f"ShellSeg_{li}", diamond_2d(1.18 - li * 0.10, 0.66), 0.13,
                 "armor" if li % 2 == 0 else "armor_sub", "armor_slab",
                 (0.0, by + 0.22 + li * 0.03, -0.28 + li * 0.38), (86.0, 0, 0), 0.014, 1)
        kb.box(f"VentGlow_{li}", (0.58 - li * 0.08, 0.028, 0.04), "emit_core", "plain_metal",
               (0.0, by + 0.28 + li * 0.03, -0.06 + li * 0.38), (0, 0, 0), 0.002, 1)

    kb.box("FrontVisor", (0.46, 0.042, 0.032), "emit_core", "plain_metal", (0.0, by + 0.10, -0.66), (0, 0, 0), 0.002, 1)
    build_plasma_core_pod(kb, "BeetleCore", "SacMain", (0.0, by + 0.16, 0.78), r=0.22, length=0.38)

    # Twin-pronged forged-titanium plasma-ramming horns (`Scythe_0`)
    g_rm = kb.add_group("Scythe_0", "Scythe_0", pos=(0.0, by - 0.04, -0.58))
    kb.use_group(g_rm)
    for si, sx in enumerate([-1.0, 1.0]):
        M_h = g2b_mat((sx * 0.24, -0.02, -0.44), (-8.0, -sx * 10.0, 0.0))
        kb.plate(f"RamHorn_{si}", trap_2d(0.20, 0.05, 0.92, 0.02), 0.09, "gunmetal", "armor_slab",
                 (0, 0, 0), (90, 0, 0), 0.010, 1, M_parent=M_h)
        kb.box(f"HornEdge_{si}", (0.028, 0.042, 0.78), "emit_core", "plain_metal",
               (-sx * 0.075, 0.0, -0.04), (0, 0, 0), 0.002, 1, M_parent=M_h)
    kb.use_group("Body")

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.38, -28.0), (0.08, 0.0), (0.54, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_lowe_arthropod_leg(kb, ri * 2 + si, (sx * 0.48, hip_y, hz), sx * yaw_a, sx, 0.78, hip_y, w=1.02)


# ==============================================================================
# 4. mantis — `Grauwolf`-Type 4-Legged Twin-Plasma-Scythe Hunter (s = 1.05)
# ==============================================================================
def build_mantis(kb: KitbashScene):
    by = 0.68
    kb.use_group("Body")

    # Predatory angled stealth thorax + swept wing-cowls (`Wing_0`, `Wing_1`) + twin plasma reaper scythes
    kb.box("HunterCore", (0.46, 0.28, 0.98), "dark", "frame_cnc", (0.0, by, 0.06), (-8.0, 0, 0), 0.012, 1)
    kb.plate("HunterCrest", diamond_2d(0.62, 1.06), 0.11, "armor", "armor_slab",
             (0.0, by + 0.18, 0.04), (82.0, 0, 0), 0.012, 1)
    for li, lx in enumerate([-0.12, 0.0, 0.12]):
        kb.cyl(f"PredLens_{li}", 0.032, 0.032, 0.04, 8, "emit_core", "plain_metal",
               (lx, by + 0.12, -0.46), (90, 0, 0), 0.002)

    for si, sx in enumerate([-1.0, 1.0]):
        g_wg = kb.add_group(f"Wing_{si}", f"Wing_{si}", pos=(sx * 0.28, by + 0.20, 0.02))
        kb.use_group(g_wg)
        M_w = g2b_mat((sx * 0.18, 0.06, 0.16), (-14.0, sx * 22.0, -sx * 28.0))
        kb.plate(f"StealthCowl_{si}", diamond_2d(0.38, 0.88), 0.058, "armor_sub", "armor_panel",
                 (0, 0, 0), (90, 0, 0), 0.010, 1, M_parent=M_w)
        kb.box(f"CowlGlow_{si}", (0.032, 0.024, 0.62), "emit_core", "plain_metal",
               (sx * 0.12, 0.032, 0.0), (0, 0, 0), 0.002, 1, M_parent=M_w)
        kb.use_group("Body")

        build_plasma_reaper_scythe(kb, f"MantisScythe_{si}", f"Scythe_{si}",
                                   (sx * 0.28, by + 0.06, -0.34), sx, w=1.02, blade_len=0.98)

    hip_y = by - 0.08
    for ri, (hz, yaw_a) in enumerate([(-0.22, -26.0), (0.34, 34.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_ameise_blade_leg(kb, ri * 2 + si, (sx * 0.28, hip_y, hz), sx * yaw_a, sx, 0.72, hip_y, w=0.96)


# ==============================================================================
# 5. bomber — `Mecha-Baneling` 4-Legged Volatile Singularity-Core Crawler (s = 0.92)
# ==============================================================================
def build_bomber(kb: KitbashScene):
    by = 0.48
    kb.use_group("Body")

    kb.box("CradleHull", (0.52, 0.22, 0.96), "dark", "frame_cnc", (0.0, by - 0.04, 0.0), (0, 0, 0), 0.012, 1)
    kb.plate("ProwArmor", diamond_2d(0.56, 0.46), 0.09, "armor", "armor_slab",
             (0.0, by + 0.06, -0.44), (58.0, 0, 0), 0.010, 1)
    kb.box("FuseEye", (0.26, 0.036, 0.028), "emit_core", "plain_metal", (0.0, by + 0.08, -0.54), (0, 0, 0), 0.002, 1)

    # Oversized faceted octagonal blazing-violet singularity core caged in dark-titanium ribs (`Sac_0`)
    for ri in range(4):
        ra = math.tau * ri / 4.0 + math.pi / 4.0
        kb.box(f"CoreClamp_{ri}", (0.065, 0.44, 0.085), "gunmetal", "bolt_flange",
               (math.cos(ra) * 0.32, by + 0.28, 0.14 + math.sin(ra) * 0.32),
               (math.sin(ra) * 22.0, 0, -math.cos(ra) * 22.0), 0.005, 1)
    g_sac = kb.add_group("Sac_0", "Sac_0", pos=(0.0, by + 0.28, 0.14))
    kb.use_group(g_sac)
    kb.cyl("VolatileSphere", 0.30, 0.28, 0.46, 8, "emit_core", "plain_metal", (0, 0, 0), (0, 0, 0), 0.016)
    kb.cyl("EquatorBand", 0.33, 0.33, 0.075, 8, "armor_dark", "gear_collar", (0, 0, 0), (0, 0, 0), 0.004, hollow_r=0.26)
    kb.use_group("Body")

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.24, -28.0), (0.32, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_ameise_blade_leg(kb, ri * 2 + si, (sx * 0.28, hip_y, hz), sx * yaw_a, sx, 0.58, hip_y, w=0.82)


# ==============================================================================
# 6. wasp — `Eintagsfliege`-Type Swept-Delta Stealth Ion-Turbine Drone (s = 0.80)
# ==============================================================================
def build_wasp(kb: KitbashScene):
    by = 0.34
    kb.use_group("Body")

    # Ventral dark-titanium talon skids strictly flush at y = 0.000m for crash-ground audit!
    for si, sx in enumerate([-0.24, 0.24]):
        kb.box(f"TalonSkid_{si}", (0.042, 0.040, 0.78), "gunmetal", "plain_metal", (sx, 0.020, 0.02), (0, 0, 0), 0.004, 1)
        kb.box(f"SkidLeg_{si}", (0.040, 0.26, 0.065), "dark", "frame_cnc", (sx * 0.85, 0.16, 0.02), (0, 0, 0), 0.004, 1)

    # Razor-sharp stealth-delta fuselage + violet optical nose + twin shrouded ion-turbines (`Spinner_Y_0/1`)
    kb.plate("DeltaFuselage", diamond_2d(0.56, 1.28), 0.13, "armor", "armor_slab",
             (0.0, by + 0.06, 0.02), (90, 0, 0), 0.012, 1)
    kb.box("NoseVisor", (0.22, 0.032, 0.032), "emit_core", "plain_metal", (0.0, by + 0.06, -0.58), (0, 0, 0), 0.002, 1)

    for si, sx in enumerate([-1.0, 1.0]):
        M_sw = g2b_mat((sx * 0.48, by + 0.06, 0.08), (0.0, -sx * 24.0, -sx * 6.0))
        kb.plate(f"DeltaWing_{si}", trap_2d(0.68, 0.26, 0.54, 0.03), 0.048, "armor_sub", "armor_panel",
                 (0, 0, 0), (90, 0, 0), 0.008, 1, M_parent=M_sw)
        kb.box(f"WingVein_{si}", (0.48, 0.018, 0.028), "emit_core", "plain_metal",
               (0, 0.028, -0.12), (0, 0, 0), 0.002, 1, M_parent=M_sw)
        # Embedded circular shrouded violet ion-turbine rotor (`Spinner_Y_*`)
        tx, tz = sx * 0.52, 0.08
        kb.cyl(f"IonDuct_{si}", 0.20, 0.20, 0.11, 14, "dark", "bolt_flange",
               (tx, by + 0.06, tz), (0, 0, 0), 0.005, hollow_r=0.145)
        kb.cyl(f"IonGlow_{si}", 0.14, 0.14, 0.025, 14, "emit_core", "plain_metal",
               (tx, by + 0.03, tz), (0, 0, 0), 0.002, hollow_r=0.06)
        g_sp = kb.add_group(f"Spinner_Y_{si}", f"Spinner_Y_{si}", pos=(tx, by + 0.07, tz))
        kb.use_group(g_sp)
        for bi in range(6):
            ba = math.tau * bi / 6.0
            kb.box(f"IonBlade_{si}_{bi}", (0.12, 0.012, 0.036), "chrome", "plain_metal",
                   (math.cos(ba) * 0.075, 0, math.sin(ba) * 0.075), (22.0, -math.degrees(ba), 0), 0.002, 1)
        kb.use_group("Body")

    g_gun = kb.add_group("Gun", "Gun", pos=(0.0, by - 0.06, -0.36))
    kb.use_group(g_gun)
    for bi, bx in enumerate([-0.065, 0.065]):
        kb.cyl(f"PulseNeedle_{bi}", 0.020, 0.016, 0.44, 8, "chrome", "plain_metal", (bx, 0, -0.24), (90, 0, 0), 0.002)
    kb.add_group("Gun/GunTip", "GunTip", pos=(0.0, 0.0, -0.48), parent_key=g_gun)
    kb.use_group("Body")
