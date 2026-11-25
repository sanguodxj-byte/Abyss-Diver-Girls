"""
Batch C — Sci-Fi Mecha-Swarm Heavy Legion Constructs (6 Units, *86 Legion / HZD Faro / SC2 Simulant* Dark-Gunmetal + Violet):
  13. `aegis`    : 4-Legged Phalanx 3-Panel Stealth Energy-Shield Bearer
  14. `lancer`   : 4-Legged High-Stance Twin-Rail Violet Hyper-Railgun Stalker
  15. `overseer` : 6-Legged `Morpho`-Relay AWACS Command Construct
  16. `ripper`   : 6-Legged Twin-Circular-Plasma-Saw Harvester
  17. `brood`    : 8-Legged `Swarm-Host` Drone-Matrix Land Mothership
  18. `colossus` : 6-Legged `Dinosauria / Khopesh` Dual-Singularity Siege Dreadnought
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d
from leg_rig_lib import heavy_hyd
from swarm_rig_lib import (
    diamond_2d,
    build_ameise_blade_leg,
    build_lowe_arthropod_leg,
    build_deathbringer_pillar_leg,
    build_plasma_reaper_scythe,
    build_plasma_saw_boom,
    build_plasma_core_pod,
)


# ==============================================================================
# 13. aegis — 4-Legged Phalanx 3-Panel Stealth Energy-Shield Bearer (s = 1.50)
# ==============================================================================
def build_aegis(kb: KitbashScene):
    by = 0.64
    kb.use_group("Body")

    kb.box("BastionCore", (0.96, 0.40, 1.12), "dark", "frame_cnc", (0.0, by, 0.18), (0, 0, 0), 0.016, 1)
    kb.plate("BastionShell", diamond_2d(1.12, 1.24), 0.14, "armor", "armor_slab",
             (0.0, by + 0.24, 0.18), (90, 0, 0), 0.014, 1)
    build_plasma_core_pod(kb, "AegisCore", "SacMain", (0.0, by + 0.18, 0.80), r=0.20, length=0.36)

    # 3-Panel Interlocking Stealth-Faceted Dark-Gunmetal + Violet Energy-Vein Tower Shield (`Plate_0/1` + Body)
    sh_y = by + 0.24
    sh_z = -0.48
    for k in range(3):
        sx_p = float(k - 1)
        ang_y = (1 - k) * -22.0
        px = sx_p * 0.46
        pz = sh_z + abs(sx_p) * 0.16
        if k == 1:
            kb.use_group("Body")
            M_pn = g2b_mat((0.0, sh_y, pz), (-8.0, 0.0, 0.0))
            grp = "Body"
        else:
            p_idx = 0 if k == 0 else 1
            grp = kb.add_group(f"Plate_{p_idx}", f"Plate_{p_idx}", pos=(px, sh_y, pz), rot_deg=(-8.0, ang_y, 0.0))
            kb.use_group(grp)
            M_pn = None

        kb.plate(f"PhalanxSlab_{k}", diamond_2d(0.50, 1.66), 0.12,
                 "armor" if k == 1 else "armor_sub", "armor_slab",
                 (0, -0.02, 0.0), (0, 0, 0), 0.016, 1, M_parent=M_pn, group=grp)
        kb.box(f"ShieldSeam_{k}", (0.042, 1.18, 0.032), "emit_core", "plain_metal",
               (0, -0.02, -0.068), (0, 0, 0), 0.002, 1, M_parent=M_pn, group=grp)
        kb.plate(f"ShieldFang_{k}", trap_2d(0.42, 0.24, 0.24, 0.02), 0.068, "chrome", "plain_metal",
                 (0, -0.74, -0.06), (24.0, 0, 0), 0.006, 1, M_parent=M_pn, group=grp)
        if k == 1:
            kb.box("VisorBrow", (0.36, 0.048, 0.09), "gunmetal", "plain_metal",
                   (0, 0.56, -0.08), (14, 0, 0), 0.004, 1, M_parent=M_pn, group=grp)
            kb.box("VisorGlow", (0.28, 0.042, 0.028), "emit_core", "plain_metal",
                   (0, 0.50, -0.072), (0, 0, 0), 0.002, 1, M_parent=M_pn, group=grp)

    kb.use_group("Body")
    for si, sx in enumerate([-1.0, 1.0]):
        heavy_hyd(kb, f"PhalanxBrace_{si}", (sx * 0.34, by + 0.08, -0.02), (sx * 0.36, by + 0.28, -0.40), r=0.038, segs=10)
        build_plasma_reaper_scythe(kb, f"AegisBlade_{si}", f"Scythe_{si}",
                                   (sx * 0.56, by + 0.06, -0.18), sx, w=0.88, blade_len=0.78)

    hip_y = by - 0.08
    for ri, (hz, yaw_a) in enumerate([(-0.04, -24.0), (0.50, 36.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_deathbringer_pillar_leg(kb, ri * 2 + si, (sx * 0.50, hip_y, hz), sx * yaw_a, sx, 0.70, hip_y, w=1.02)


# ==============================================================================
# 14. lancer — 4-Legged High-Stance Twin-Rail Violet Hyper-Railgun Stalker (s = 1.00)
# ==============================================================================
def build_lancer(kb: KitbashScene):
    by = 0.98
    kb.use_group("Body")

    kb.box("StalkerReceiver", (0.52, 0.32, 0.96), "dark", "frame_cnc", (0.0, by, 0.04), (0, 0, 0), 0.014, 1)
    kb.plate("StalkerShell", diamond_2d(0.72, 1.14), 0.11, "armor", "armor_slab",
             (0.0, by + 0.20, 0.04), (90, 0, 0), 0.014, 1)
    kb.cyl("SniperLens", 0.075, 0.085, 0.12, 8, "emit_core", "plain_metal", (0.0, by + 0.14, -0.48), (90, 0, 0), 0.003)
    build_plasma_core_pod(kb, "RailCap", "SacMain", (0.0, by + 0.18, 0.64), r=0.18, length=0.42)

    # Underslung 2.2m Twin-Rail Glowing-Violet Hyper-Velocity Railgun (`Gun` + `GunTip` + `GunGlow`)
    g_gun = kb.add_group("Gun", "Gun", pos=(0.0, by - 0.20, -0.08))
    kb.use_group(g_gun)
    kb.box("RailHousing", (0.30, 0.24, 0.74), "gunmetal", "frame_cnc", (0.0, 0.0, 0.10), (0, 0, 0), 0.012, 1)
    for ri, ry in enumerate([-0.058, 0.058]):
        kb.plate(f"HyperRail_{ri}", trap_2d(0.11, 0.06, 1.76, 0.01), 0.042, "chrome", "plain_metal",
                 (0.0, ry, -1.06), (90, 0, 0), 0.004, 1)
    for yi in range(6):
        kb.box(f"IndYoke_{yi}", (0.17, 0.17, 0.068), "copper", "gear_collar", (0.0, 0.0, -0.34 - yi * 0.26), (0, 0, 0), 0.004, 1)
    kb.add_group("Gun/GunTip", "GunTip", pos=(0.0, 0.0, -1.96), parent_key=g_gun)
    g_gl = kb.add_group("Gun/GunGlow", "GunGlow", pos=(0.0, 0.0, -1.06), parent_key=g_gun)
    kb.use_group(g_gl)
    kb.box("RailPlasma", (0.042, 0.048, 1.62), "emit_core", "plain_metal", (0, 0, 0), (0, 0, 0), 0.002, 1)
    kb.use_group("Body")

    hip_y = by - 0.08
    for ri, (hz, yaw_a) in enumerate([(-0.26, -28.0), (0.34, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_ameise_blade_leg(kb, ri * 2 + si, (sx * 0.30, hip_y, hz), sx * yaw_a, sx, 0.88, hip_y, w=1.05)


# ==============================================================================
# 15. overseer — 6-Legged `Morpho`-Relay AWACS Command Construct (s = 1.12)
# ==============================================================================
def build_overseer(kb: KitbashScene):
    by = 0.62
    kb.use_group("Body")

    kb.box("RelayHull", (0.72, 0.32, 1.24), "dark", "frame_cnc", (0.0, by, 0.04), (0, 0, 0), 0.014, 1)
    kb.plate("RelayDeck", diamond_2d(0.98, 1.38), 0.12, "armor", "armor_slab",
             (0.0, by + 0.20, 0.04), (90, 0, 0), 0.014, 1)
    kb.box("CommandVisor", (0.42, 0.042, 0.030), "emit_core", "plain_metal", (0.0, by + 0.10, -0.62), (0, 0, 0), 0.002, 1)

    # Rotating swept stealth command scanner bar (`Spinner_Y_0`)
    kb.cyl("ScanMast", 0.14, 0.18, 0.22, 8, "gunmetal", "gear_collar", (0.0, by + 0.34, 0.08), (0, 0, 0), 0.004)
    g_sp = kb.add_group("Spinner_Y_0", "Spinner_Y_0", pos=(0.0, by + 0.46, 0.08))
    kb.use_group(g_sp)
    kb.plate("ScannerWing", diamond_2d(1.36, 0.28), 0.10, "armor_sub", "armor_panel",
             (0.0, 0.06, 0.0), (90, 0, 0), 0.010, 1)
    kb.box("ScannerGlow", (1.12, 0.045, 0.032), "emit_core", "plain_metal", (0.0, 0.06, -0.10), (0, 0, 0), 0.002, 1)
    kb.use_group("Body")

    g_gun = kb.add_group("Gun", "Gun", pos=(0.0, by - 0.06, -0.58))
    kb.use_group(g_gun)
    for bi, bx in enumerate([-0.08, 0.08]):
        kb.cyl(f"CmdPulse_{bi}", 0.026, 0.022, 0.48, 8, "chrome", "plain_metal", (bx, 0, -0.28), (90, 0, 0), 0.002)
    kb.add_group("Gun/GunTip", "GunTip", pos=(0.0, 0.0, -0.54), parent_key=g_gun)
    g_gl = kb.add_group("Gun/GunGlow", "GunGlow", pos=(0.0, 0.06, -0.18), parent_key=g_gun)
    kb.use_group(g_gl)
    kb.box("CmdGlow", (0.12, 0.024, 0.08), "emit_core", "plain_metal", (0, 0, 0), (0, 0, 0), 0.002, 1)
    kb.use_group("Body")

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.36, -28.0), (0.04, 0.0), (0.44, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_ameise_blade_leg(kb, ri * 2 + si, (sx * 0.40, hip_y, hz), sx * yaw_a, sx, 0.72, hip_y, w=0.92)


# ==============================================================================
# 16. ripper — 6-Legged Twin-Circular-Plasma-Saw Harvester (s = 1.02)
# ==============================================================================
def build_ripper(kb: KitbashScene):
    by = 0.56
    kb.use_group("Body")

    kb.box("RipperCore", (0.64, 0.28, 1.18), "dark", "frame_cnc", (0.0, by, 0.06), (0, 0, 0), 0.012, 1)
    kb.plate("RipperShell", diamond_2d(0.88, 1.32), 0.12, "armor", "armor_slab",
             (0.0, by + 0.18, 0.06), (90, 0, 0), 0.012, 1)
    kb.box("RipperVisor", (0.36, 0.038, 0.030), "emit_core", "plain_metal", (0.0, by + 0.08, -0.58), (0, 0, 0), 0.002, 1)

    for si, sx in enumerate([-1.0, 1.0]):
        build_plasma_saw_boom(kb, f"RipSaw_{si}", boom_idx=si, spin_idx=si,
                              pos=(sx * 0.36, by + 0.08, -0.44), side=sx, boom_len=0.78, saw_r=0.36)

    hip_y = by - 0.06
    for ri, (hz, yaw_a) in enumerate([(-0.34, -28.0), (0.06, 0.0), (0.46, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_ameise_blade_leg(kb, ri * 2 + si, (sx * 0.36, hip_y, hz), sx * yaw_a, sx, 0.68, hip_y, w=0.90)


# ==============================================================================
# 17. brood — 8-Legged `Swarm-Host` Drone-Matrix Land Mothership (s = 1.65)
# ==============================================================================
def build_brood(kb: KitbashScene):
    by = 0.68
    kb.use_group("Body")

    kb.box("MothershipCore", (1.16, 0.42, 2.08), "dark", "frame_cnc", (0.0, by, 0.08), (0, 0, 0), 0.018, 1)
    kb.plate("MothershipCarapace", diamond_2d(1.56, 2.32), 0.16, "armor", "armor_slab",
             (0.0, by + 0.26, 0.08), (90, 0, 0), 0.016, 1)
    kb.box("BowVisor", (0.52, 0.048, 0.032), "emit_core", "plain_metal", (0.0, by + 0.16, -0.98), (0, 0, 0), 0.002, 1)

    # Hinged dorsal drone-incubation bay wings (`Plate_0`, `Plate_1`) + blazing violet gestation cells (`Sac_0/1`)
    for si, sx in enumerate([-1.0, 1.0]):
        g_pl = kb.add_group(f"Plate_{si}", f"Plate_{si}", pos=(sx * 0.42, by + 0.34, 0.16))
        kb.use_group(g_pl)
        kb.plate(f"IncubBayDoor_{si}", diamond_2d(0.46, 1.32), 0.068, "armor_sub", "armor_panel",
                 (-sx * 0.18, 0.04, 0.0), (90, 0, -sx * 8.0), 0.010, 1)
        build_plasma_core_pod(kb, f"GestationCell_{si}", f"Sac_{si}", (sx * 0.24, by + 0.30, 0.28), r=0.20, length=0.84)
    kb.use_group("Body")

    g_gun = kb.add_group("Gun", "Gun", pos=(0.0, by - 0.04, -0.96))
    kb.use_group(g_gun)
    for bi, bx in enumerate([-0.12, 0.12]):
        kb.cyl(f"HostGun_{bi}", 0.036, 0.030, 0.62, 10, "chrome", "plain_metal", (bx, 0, -0.36), (90, 0, 0), 0.003)
    kb.add_group("Gun/GunTip", "GunTip", pos=(0.0, 0.0, -0.70), parent_key=g_gun)
    g_gl = kb.add_group("Gun/GunGlow", "GunGlow", pos=(0.0, 0.08, -0.22), parent_key=g_gun)
    kb.use_group(g_gl)
    kb.box("HostGlow", (0.16, 0.028, 0.10), "emit_core", "plain_metal", (0, 0, 0), (0, 0, 0), 0.002, 1)
    kb.use_group("Body")

    hip_y = by - 0.08
    for ri, (hz, yaw_a) in enumerate([(-0.62, -32.0), (-0.16, -10.0), (0.30, 12.0), (0.76, 34.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_lowe_arthropod_leg(kb, ri * 2 + si, (sx * 0.58, hip_y, hz), sx * yaw_a, sx, 0.88, hip_y, w=1.04)


# ==============================================================================
# 18. colossus — 6-Legged `Dinosauria / Khopesh` Dual-Singularity Dreadnought (s = 1.95)
# ==============================================================================
def build_colossus(kb: KitbashScene):
    by = 0.78
    kb.use_group("Body")

    kb.box("DreadHull", (1.36, 0.52, 2.16), "dark", "frame_cnc", (0.0, by, 0.08), (0, 0, 0), 0.020, 1)
    kb.plate("DreadCarapace", diamond_2d(1.78, 2.42), 0.20, "armor", "armor_slab",
             (0.0, by + 0.34, 0.08), (90, 0, 0), 0.018, 1)
    kb.plate("UpperCitadel", diamond_2d(1.16, 1.38), 0.24, "armor_sub", "armor_panel",
             (0.0, by + 0.54, 0.16), (90, 0, 0), 0.016, 1)
    kb.box("DreadVisor", (0.64, 0.056, 0.036), "emit_core", "plain_metal", (0.0, by + 0.26, -1.04), (0, 0, 0), 0.002, 1)

    # Twin dorsal singularity reactor pylons + blazing central plasma nexus (`SacMain`)
    for si, sx in enumerate([-0.36, 0.36]):
        kb.plate(f"ReactorSpire_{si}", trap_2d(0.32, 0.18, 0.72, 0.03), 0.36, "gunmetal", "radiator_fin",
                 (sx, by + 0.96, 0.42), (12.0, 0, -math.copysign(8.0, sx)), 0.012, 1)
    g_sac = kb.add_group("SacMain", "SacMain", pos=(0.0, by + 0.90, 0.42))
    kb.use_group(g_sac)
    kb.cyl("NexusSphere", 0.24, 0.24, 0.42, 8, "emit_core", "plain_metal", (0, 0, 0), (0, 0, 0), 0.010)
    kb.use_group("Body")

    for si, sx in enumerate([-1.0, 1.0]):
        build_plasma_reaper_scythe(kb, f"ColossusCleaver_{si}", f"Scythe_{si}",
                                   (sx * 0.72, by + 0.08, -0.78), sx, w=1.22, blade_len=1.18)

    g_gun = kb.add_group("Gun", "Gun", pos=(0.0, by + 0.56, -0.56))
    kb.use_group(g_gun)
    kb.box("TurretCowl", (0.72, 0.28, 0.62), "armor", "armor_pocket", (0, 0, 0), (0, 0, 0), 0.014, 1)
    for bi, bx in enumerate([-0.20, 0.20]):
        kb.plate(f"DreadRail_{bi}", trap_2d(0.14, 0.09, 1.16, 0.02), 0.14, "gunmetal", "armor_slab",
                 (bx, 0, -0.76), (90, 0, 0), 0.008, 1)
        kb.box(f"DreadSlot_{bi}", (0.036, 0.048, 0.92), "emit_core", "plain_metal", (bx, 0, -0.76), (0, 0, 0), 0.002, 1)
    kb.add_group("Gun/GunTip", "GunTip", pos=(0.0, 0.0, -1.36), parent_key=g_gun)
    g_gl = kb.add_group("Gun/GunGlow", "GunGlow", pos=(0.0, 0.14, -0.34), parent_key=g_gun)
    kb.use_group(g_gl)
    kb.box("DreadGlow", (0.28, 0.036, 0.14), "emit_core", "plain_metal", (0, 0, 0), (0, 0, 0), 0.002, 1)
    kb.use_group("Body")

    hip_y = by - 0.10
    for ri, (hz, yaw_a) in enumerate([(-0.56, -28.0), (0.08, 0.0), (0.72, 32.0)]):
        for si, sx in enumerate([-1.0, 1.0]):
            build_deathbringer_pillar_leg(kb, ri * 2 + si, (sx * 0.68, hip_y, hz), sx * yaw_a, sx, 0.92, hip_y, w=1.22)
