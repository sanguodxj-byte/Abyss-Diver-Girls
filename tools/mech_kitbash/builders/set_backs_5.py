"""Set of 5 Production-Grade Mech Backpacks — Zero-Clip Rich Mechanical Standard (v1.5).

Contains 5 high-precision dorsal backpack modules:
  1. back_rack     (RK-4 Tactical Cargo Rack)
  2. back_shield   (SH-3 Medium Field Shield Generator)
  3. back_missile  (MS-6 6-Cell Armored Missile Pod)
  4. back_vls      (VLS-12 Naval Mk41-Style Vertical Launch Monolith)
  5. back_rocket   (RP-7 Dual 7-Tube Unguided Rocket Pods)

Clearance Envelope (strictly enforced for zero assembly clash across all 21 cores):
  - HP-B1 base sits cleanly at y = 0.00..0.06 (ZERO geometry below y = 0.00)
  - Width |x| <= 0.78, depth z in [-0.28, +0.46]
  - Lower clearance (y < 0.14): z <= +0.34, straddling core dorsal guide rails
  - Budgets: 3,500 <= tris <= 13,000, size <= 800 KB
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


# ==============================================================================
# SHARED HP-B1 DORSAL MOUNT & HARD-SURFACE SUB-ASSEMBLIES
# ==============================================================================

def _hp_b1_mount(kb: KitbashScene, prefix: str = "HP_B1", bridge_w: float = 0.78,
                 bridge_d: float = 0.34, z_center: float = 0.03):
    """Unified HP-B1 dual-rail dorsal saddle mount (y in [0.004, 0.112], straddles core guide rails cleanly)."""
    # Central locking shoe between core rails (x in [-0.17, +0.17], y in [0.004, 0.058])
    kb.box(f"{prefix}_shoe", (0.34, 0.054, bridge_d - 0.04), "dark", "frame_cnc",
           (0.0, 0.031, z_center), (0, 0, 0), 0.007, 1)
    # Outboard twin guide-rail clamp jaws straddling core rails at |x| in [0.335, 0.405]
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"{prefix}_jaw{si}", (0.066, 0.056, bridge_d - 0.06), "gunmetal", "bolt_flange",
               (sx * 0.370, 0.034, z_center), (0, 0, 0), 0.006, 1)
        for bi, bz in enumerate([z_center - 0.085, z_center + 0.085]):
            kb.cyl(f"{prefix}_jb{si}_{bi}", 0.011, 0.013, 0.018, 6, "chrome", "plain_metal",
                   (sx * 0.408, 0.034, bz), (0, 0, 90), 0.002)
    # Main upper mounting bridge plate spanning both jaws & central shoe (y in [0.052, 0.106])
    kb.box(f"{prefix}_brg", (bridge_w, 0.054, bridge_d), "dark", "bolt_flange",
           (0.0, 0.079, z_center), (0, 0, 0), 0.008, 1)
    # Front brass power/data umbilical plug + rear amber lock indicator bar
    kb.cyl(f"{prefix}_plug", 0.024, 0.028, 0.032, 10, "brass", "gear_collar",
           (0.0, 0.078, z_center - bridge_d * 0.5 - 0.010), (90, 0, 0), 0.003)
    kb.box(f"{prefix}_lock", (0.28, 0.024, 0.018), "accent", "plain_metal",
           (0.0, 0.080, z_center + bridge_d * 0.5 + 0.006), (0, 0, 0), 0.003, 1)


def _add_hex_bolt_row(kb: KitbashScene, prefix: str, pts, rot_deg=(0, 0, 0),
                      r: float = 0.010, h: float = 0.014, M_parent=None):
    for i, p in enumerate(pts):
        kb.cyl(f"{prefix}_b{i}", r, r * 1.15, h, 6, "chrome", "plain_metal",
               p, rot_deg, 0.002, M_parent=M_parent)


def _top_grab_rail(kb: KitbashScene, prefix: str, w: float, d: float, pos, yaw_deg: float = 0.0,
                   r: float = 0.009, M_parent=None):
    """Grab rail protruding strictly UPWARD (+Y in parent space) at any horizontal yaw_deg."""
    M = g2b_mat(pos, (0.0, yaw_deg, 0.0)) @ g2b_mat((0.0, 0.0, 0.0), (90.0, 0.0, 0.0))
    if M_parent is not None:
        M = M_parent @ M
    kb.grab_rail(prefix, w, d, (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), r, M_parent=M)


# ==============================================================================
# 1. back_rack — RK-4 Welded Tubular Tactical Cargo Rack
# ==============================================================================

def build_back_rack(kb: KitbashScene):
    """RK-4 Cargo Rack: welded tubular roll-cage, slotted deck, ammo crate, dual horizontal fuel drums, canvas roll & ratchet straps."""
    # 1. Unified HP-B1 Base + Twin Stabilizer Struts + Raised Slotted Cargo Deck (clears all core exhausts & whips!)
    _hp_b1_mount(kb, "HP_B1", bridge_w=0.78, bridge_d=0.34, z_center=0.05)
    kb.box("RackPedestal", (0.64, 0.048, 0.30), "dark", "frame_cnc", (0.0, 0.126, 0.06), (0, 0, 0), 0.007, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"RackStrut_{si}", (sx * 0.30, 0.088, 0.06), (sx * 0.44, 0.165, 0.07), 0.017)

    # Slotted CNC cargo deck plate sitting cleanly at y = 0.146..0.198, x in [-0.53, +0.53], z in [-0.15, +0.34]
    zc = 0.095
    kb.box("CargoDeck", (1.06, 0.052, 0.49), "dark", "frame_cnc", (0.0, 0.172, zc), (0, 0, 0), 0.009, 1, tile_u=2.0)
    kb.box("DeckEdgeTrim", (1.08, 0.030, 0.506), "gunmetal", "bolt_flange", (0.0, 0.166, zc), (0, 0, 0), 0.005, 1)
    # 7 proud deck floor slats
    for i, ix in enumerate([-0.42, -0.28, -0.14, 0.0, 0.14, 0.28, 0.42]):
        kb.box(f"DeckSlat_{i}", (0.056, 0.018, 0.44), "gunmetal", "armor_ribs", (ix, 0.204, zc), (0, 0, 0), 0.003, 1)
    # Proud rear hazard edge bumper strip (y >= 0.165, z <= 0.365)
    kb.box("DeckHazardRear", (0.98, 0.030, 0.018), "hazard", "hazard", (0.0, 0.180, zc + 0.256), (0, 0, 0), 0.003, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.grab_rail(f"DeckGrab_{si}", 0.22, 0.038, (sx * 0.535, 0.176, zc), (0, -sx * 90.0, 0), 0.009)

    # 2. Welded Tubular Steel Cargo Roll-Cage Frame + Gussets + Corner Collars
    post_xs = [-0.495, 0.495]
    post_zs = [zc - 0.215, zc + 0.215]
    for xi, px in enumerate(post_xs):
        for zi, pz in enumerate(post_zs):
            kb.cyl(f"CagePost_{xi}_{zi}", 0.023, 0.023, 0.53, 10, "gunmetal", "plain_metal",
                   (px, 0.460, pz), (0, 0, 0), 0.003)
            kb.cyl(f"CageBaseCol_{xi}_{zi}", 0.032, 0.034, 0.038, 10, "dark", "bolt_flange",
                   (px, 0.212, pz), (0, 0, 0), 0.003)
            kb.cyl(f"CageTopCol_{xi}_{zi}", 0.030, 0.030, 0.036, 10, "dark", "gear_collar",
                   (px, 0.715, pz), (0, 0, 0), 0.003)
            gx = px - math.copysign(0.044, px)
            kb.box(f"CageGusset_{xi}_{zi}", (0.070, 0.070, 0.018), "gunmetal", "plain_metal",
                   (gx, 0.232, pz), (0, 0, 0), 0.003, 1)
        kb.cyl(f"CageSideTop_{xi}", 0.021, 0.021, 0.46, 10, "gunmetal", "plain_metal",
               (px, 0.715, zc), (90, 0, 0), 0.003)
        kb.cyl(f"CageSideMid_{xi}", 0.017, 0.017, 0.45, 8, "dark", "plain_metal",
               (px, 0.465, zc), (90, 0, 0), 0.002)
    for zi, pz in enumerate(post_zs):
        kb.cyl(f"CageCrossTop_{zi}", 0.022, 0.022, 1.02, 10, "gunmetal", "plain_metal",
               (0.0, 0.715, pz), (0, 0, 90), 0.003)
    kb.cyl("CageRearMid", 0.017, 0.017, 1.01, 8, "dark", "plain_metal",
           (0.0, 0.465, post_zs[1]), (0, 0, 90), 0.002)

    # 3. Left Cargo: Strapped Military Olive 30mm Ammo Crate + Corner Guards + Latches
    cx = -0.235
    kb.box("AmmoCrateBody", (0.41, 0.34, 0.38), "armor", "armor_panel", (cx, 0.380, zc), (0, 0, 0), 0.012, 1)
    kb.box("AmmoCrateLid", (0.435, 0.056, 0.402), "armor_sub", "armor_hatch", (cx, 0.573, zc), (0, 0, 0), 0.010, 1)
    for ri, rz in enumerate([zc - 0.125, zc + 0.125]):
        kb.box(f"CrateRib_{ri}", (0.424, 0.32, 0.030), "gunmetal", "armor_ribs", (cx, 0.380, rz), (0, 0, 0), 0.004, 1)
    for ci, (ox, oz) in enumerate([(-0.20, -0.18), (0.20, -0.18), (-0.20, 0.18), (0.20, 0.18)]):
        kb.box(f"CrateCnr_{ci}", (0.048, 0.060, 0.048), "dark", "bolt_flange", (cx + ox, 0.581, zc + oz), (0, 0, 0), 0.005, 1)
        kb.cyl(f"CrateBolt_{ci}", 0.008, 0.010, 0.012, 6, "chrome", "plain_metal", (cx + ox, 0.616, zc + oz), (0, 0, 0), 0.002)
    for li, lx in enumerate([-0.34, -0.13]):
        kb.box(f"CrateClasp_{li}", (0.034, 0.084, 0.022), "chrome", "plain_metal", (lx, 0.525, zc + 0.202), (0, 0, 0), 0.003, 1)
        kb.box(f"CrateClaspBase_{li}", (0.042, 0.028, 0.016), "dark", "plain_metal", (lx, 0.480, zc + 0.198), (0, 0, 0), 0.002, 1)
    kb.grab_rail("CrateHandle", 0.15, 0.030, (cx - 0.204, 0.385, zc), (0, 90, 0), 0.008)
    kb.box("CrateAccent", (0.29, 0.040, 0.014), "accent", "plain_metal", (cx, 0.385, zc + 0.196), (0, 0, 0), 0.002, 1)

    # 4. Right Cargo: Dual Horizontal Pressurized Fuel Drums + Cradle Saddles + Clamp Straps + Brass Valves
    dx_c = 0.230
    for di, dz in enumerate([zc - 0.105, zc + 0.105]):
        for si, sx in enumerate([dx_c - 0.115, dx_c + 0.115]):
            kb.box(f"DrumSaddle_{di}_{si}", (0.040, 0.064, 0.17), "dark", "frame_cnc",
                   (sx, 0.236, dz), (0, 0, 0), 0.005, 1)
        dmat = "armor_sub" if di == 0 else "armor_dark"
        kb.cyl(f"FuelDrum_{di}", 0.098, 0.098, 0.39, 18, dmat, "armor_ribs",
               (dx_c, 0.328, dz), (0, 0, 90), 0.008)
        for ei, ex in enumerate([dx_c - 0.192, dx_c + 0.192]):
            kb.cyl(f"DrumChime_{di}_{ei}", 0.104, 0.104, 0.018, 18, "gunmetal", "bolt_flange",
                   (ex, 0.328, dz), (0, 0, 90), 0.003)
        for ci, cx_b in enumerate([dx_c - 0.115, dx_c + 0.115]):
            kb.cyl(f"DrumClamp_{di}_{ci}", 0.107, 0.107, 0.026, 18, "dark", "gear_collar",
                   (cx_b, 0.328, dz), (0, 0, 90), 0.003)
            kb.box(f"DrumClampLug_{di}_{ci}", (0.030, 0.038, 0.024), "chrome", "plain_metal",
                   (cx_b, 0.328, dz + 0.108 if di == 1 else dz - 0.108), (0, 0, 0), 0.003, 1)
        kb.cyl(f"DrumBung_{di}", 0.021, 0.023, 0.030, 10, "brass", "gear_collar",
               (dx_c + 0.208, 0.360, dz), (0, 0, 90), 0.003)
        kb.cyl(f"DrumVent_{di}", 0.011, 0.013, 0.026, 8, "copper", "plain_metal",
               (dx_c + 0.206, 0.292, dz), (0, 0, 90), 0.002)

    # 5. Top Right Cargo: Waterproof Rolled Tactical Canvas Roll + Dark Cinch Straps + Brass Buckles
    kb.cyl("CanvasRoll", 0.100, 0.100, 0.39, 18, "rubber", "dust_boot",
           (dx_c, 0.515, zc), (0, 0, 90), 0.010, u_rep=2.0)
    kb.cyl("CanvasCore", 0.068, 0.068, 0.404, 14, "armor_sub", "plain_metal",
           (dx_c, 0.515, zc), (0, 0, 90), 0.004)
    for ti, tx in enumerate([dx_c - 0.115, dx_c + 0.115]):
        kb.cyl(f"CanvasStrap_{ti}", 0.108, 0.108, 0.028, 18, "dark", "plain_metal",
               (tx, 0.515, zc), (0, 0, 90), 0.003)
        kb.box(f"CanvasBuckle_{ti}", (0.036, 0.024, 0.018), "brass", "plain_metal",
               (tx, 0.580, zc + 0.082), (-35, 0, 0), 0.003, 1)

    # 6. Accent/Orange Ratchet Tie-Down Straps + Forged Steel Ratchet Tensioners + Rear Coiled Cable
    strap_xs = [-0.34, -0.13, 0.23]
    for si, sx in enumerate(strap_xs):
        top_y = 0.610 if sx < 0.0 else 0.625
        kb.box(f"RatchetTop_{si}", (0.038, 0.016, 0.47), "accent", "braid_hose",
               (sx, top_y, zc), (0, 0, 0), 0.003, 1)
        kb.box(f"RatchetFront_{si}", (0.038, top_y - 0.186, 0.016), "accent", "braid_hose",
               (sx, (top_y + 0.186) * 0.5, zc - 0.230), (0, 0, 0), 0.003, 1)
        kb.box(f"RatchetRear_{si}", (0.038, top_y - 0.186, 0.016), "accent", "braid_hose",
               (sx, (top_y + 0.186) * 0.5, zc + 0.230), (0, 0, 0), 0.003, 1)
        kb.box(f"RatchetBody_{si}", (0.068, 0.088, 0.040), "gunmetal", "bolt_flange",
               (sx, 0.365, zc + 0.246), (0, 0, 0), 0.006, 1)
        kb.cyl(f"RatchetSpool_{si}", 0.017, 0.017, 0.084, 10, "brass", "gear_collar",
               (sx, 0.365, zc + 0.262), (0, 0, 90), 0.002)
        kb.box(f"RatchetLever_{si}", (0.018, 0.070, 0.016), "chrome", "plain_metal",
               (sx + 0.026, 0.320, zc + 0.266), (-16, 0, 0), 0.003, 1)

    # Rear tow shackle & spare steel cable loop mounted cleanly on rear cage bar
    kb.tow_shackle("RearTowShackle", (0.0, 0.465, zc + 0.258), (0, 90, 0), scale=0.92)
    kb.cyl("SpareCableLoop", 0.105, 0.105, 0.022, 18, "gunmetal", "braid_hose",
           (0.0, 0.380, zc + 0.242), (90, 0, 0), 0.004, hollow_r=0.078)


# ==============================================================================
# 2. back_shield — SH-3 Medium Field Shield Generator
# ==============================================================================

def build_back_shield(kb: KitbashScene):
    """SH-3 Field Shield: armored central pylon, dual angled deployable emitter wings, recessed emit_cyan strips, copper busbars, dorsal cooling & hydraulic tilt struts."""
    # 1. Unified HP-B1 Base + Heavy Central Armored Capacitor Housing
    _hp_b1_mount(kb, "HP_B1", bridge_w=0.76, bridge_d=0.34, z_center=0.03)

    # Central armored housing (y in [0.10, 0.54], x in [-0.30, +0.30], z in [-0.18, +0.28])
    kb.plate("CoreHousing", crect_2d(0.46, 0.44, (0.08, 0.08, 0.04, 0.04)), 0.60, "armor", "armor_panel",
             (0.0, 0.32, 0.05), (0, 90, 0), 0.014, 1)
    kb.box("CoreCap", (0.58, 0.056, 0.42), "armor_sub", "armor_hatch", (0.0, 0.545, 0.05), (0, 0, 0), 0.010, 1)
    # Front spaced armored breaker plate + proud accent chevron bar
    kb.spaced_armor_plate("FrontCapacitorDoor", (0.44, 0.28, 0.032), "armor_sub", "armor_pocket",
                          (0.0, 0.33, -0.188), (0, 0, 0))
    kb.box("FrontAccentBand", (0.46, 0.036, 0.016), "accent", "plain_metal", (0.0, 0.495, -0.185), (0, 0, 0), 0.003, 1)
    kb.box("FrontHazardTag", (0.22, 0.034, 0.014), "hazard", "hazard", (0.0, 0.165, -0.186), (0, 0, 0), 0.002, 1)

    # Rear Dorsal Cooling Louver Bay (facing +Z rearward) + Top Louver Bay strictly clear of PylonSpine
    kb.louver_bay("RearCoolLouver", 0.42, 0.26, 0.046, (0.0, 0.32, 0.295), (0, 180, 0), blades=5, mesh_style=False)
    kb.louver_bay("TopCoolLouver", 0.34, 0.115, 0.036, (0.0, 0.580, -0.075), (90, 0, 0), blades=4, mesh_style=True)

    # 2. Central Armored Field Emitter Pylon + 3 Stacked Copper Coils + HV Bushings + Top Crown
    kb.box("PylonSpine", (0.24, 0.38, 0.22), "dark", "frame_cnc", (0.0, 0.72, 0.12), (0, 0, 0), 0.012, 1)
    kb.box("PylonRearArmor", (0.28, 0.30, 0.065), "armor_sub", "armor_ribs", (0.0, 0.72, 0.235), (0, 0, 0), 0.008, 1)
    # 3 stacked solid copper induction field coils clamped cleanly to PylonSpine exterior (4mm seat -> 0 buried!)
    for ci in range(3):
        cy = 0.625 + ci * 0.068
        kb.cyl(f"FieldCoil_{ci}", 0.168, 0.168, 0.034, 22, "copper", "gear_collar",
               (0.0, cy, 0.12), (0, 0, 0), 0.004, hollow_r=0.132, u_rep=2.0)
        for bi, (bx, bz, sx_c, sz_c) in enumerate([
            (-0.138, 0.12, 0.044, 0.044), (0.138, 0.12, 0.044, 0.044),
            (0.0, -0.012, 0.044, 0.052), (0.0, 0.252, 0.044, 0.052),
        ]):
            kb.box(f"CoilBracket_{ci}_{bi}", (sx_c, 0.042, sz_c), "gunmetal", "bolt_flange",
                   (bx, cy, bz), (0, 0, 0), 0.004, 1)

    # Top central phased-array emitter cap + recessed emit_cyan slit + brass lightning probe
    kb.plate("TopEmitterCap", crect_2d(0.34, 0.16, (0.05, 0.05, 0.03, 0.03)), 0.24, "armor", "armor_pocket",
             (0.0, 0.90, 0.11), (0, 0, 0), 0.010, 1)
    kb.box("TopEmitterBore", (0.24, 0.072, 0.022), "bore", "plain_metal", (0.0, 0.90, -0.010), (0, 0, 0), 0.003, 1)
    kb.box("TopEmitterGlow", (0.20, 0.026, 0.014), "emit_cyan", "plain_metal", (0.0, 0.90, -0.020), (0, 0, 0), 0.002, 1)
    kb.cyl("FieldProbeBase", 0.026, 0.034, 0.048, 12, "brass", "gear_collar", (0.0, 0.995, 0.11), (0, 0, 0), 0.003)
    kb.cyl("FieldProbeTip", 0.008, 0.014, 0.10, 10, "chrome", "plain_metal", (0.0, 1.055, 0.11), (0, 0, 0), 0.002)

    # Twin Top HV Pulse Capacitors + Stepped Ceramic/Brass Insulators + Copper Busbars
    for si, sx in enumerate([-1.0, 1.0]):
        bx = sx * 0.23
        kb.cyl(f"CapBank_{si}", 0.052, 0.054, 0.13, 14, "gunmetal", "armor_ribs", (bx, 0.625, -0.06), (0, 0, 0), 0.005)
        kb.cyl(f"CapCollar_{si}", 0.058, 0.058, 0.020, 14, "chrome", "plain_metal", (bx, 0.692, -0.06), (0, 0, 0), 0.002)
        kb.cyl(f"CapInsul_{si}", 0.024, 0.032, 0.075, 12, "brass", "dust_boot", (bx, 0.735, -0.06), (0, 0, 0), 0.003)
        kb.cyl(f"CapTerm_{si}", 0.016, 0.016, 0.024, 10, "copper", "plain_metal", (bx, 0.782, -0.06), (0, 0, 0), 0.002)
        # Solid copper busbar + braided HV feed routing cleanly into pylon coil clamps
        kb.tube_path(f"HV_Bus_{si}", [
            (bx, 0.775, -0.06), (sx * 0.21, 0.785, 0.04), (sx * 0.13, 0.760, 0.11)
        ], 0.014, 8, "copper", "plain_metal", add_clamps=True, clamp_mat="gunmetal")

    # 3. Dual Angled Deployable Ballistic / Field Emitter Wings + Hinge Drums + Hydraulic Tilt Struts
    for si, sx in enumerate([-1.0, 1.0]):
        # Heavy side pivot shoulder bracket + hinge actuator drum
        kb.box(f"WingBracket_{si}", (0.12, 0.18, 0.20), "dark", "frame_cnc",
               (sx * 0.33, 0.42, 0.07), (0, 0, 0), 0.009, 1)
        kb.cyl(f"WingHinge_{si}", 0.062, 0.062, 0.24, 14, "gunmetal", "gear_collar",
               (sx * 0.385, 0.42, 0.07), (90, 0, 0), 0.005)
        kb.cyl(f"WingHingePin_{si}", 0.028, 0.028, 0.275, 10, "chrome", "plain_metal",
               (sx * 0.385, 0.42, 0.07), (90, 0, 0), 0.003)
        # Hydraulic tilt strut connecting lower central housing to wing lower-rear lug
        kb.hydraulic(f"WingTiltHyd_{si}", (sx * 0.28, 0.18, 0.11), (sx * 0.54, 0.34, 0.17), 0.019)
        # Copper power umbilical flex hose from central housing into wing emitter core
        kb.tube_path(f"WingPowerHose_{si}", [
            (sx * 0.28, 0.46, 0.17), (sx * 0.39, 0.48, 0.22), (sx * 0.51, 0.48, 0.16)
        ], 0.015, 8, "copper", "braid_hose")

        # Wing local frame: angled outward (yaw = -sx * 22 deg, splay roll = -sx * 10 deg)
        # Max |x| check: center 0.55 + half-w 0.19 * cos(22) = 0.726 <= 0.78; z in [-0.14, +0.34]
        M_w = g2b_mat((sx * 0.555, 0.50, 0.11), (0.0, -sx * 22.0, -sx * 10.0))
        # Main chamfered ballistic emitter wing body
        kb.plate(f"WingMain_{si}", crect_2d(0.36, 0.58, (0.07, 0.07, 0.07, 0.07)), 0.088, "armor", "armor_panel",
                 (0.0, 0.0, 0.0), (0, 0, 0), 0.012, 1, M_parent=M_w)
        # Rear armored rib backing + side hinge mating collar
        kb.box(f"WingRearRib_{si}", (0.28, 0.46, 0.036), "armor_sub", "armor_ribs",
               (0.0, 0.0, 0.056), (0, 0, 0), 0.006, 1, M_parent=M_w)
        kb.box(f"WingHingeLug_{si}", (0.14, 0.14, 0.072), "dark", "bolt_flange",
               (-sx * 0.16, -0.08, 0.02), (0, 0, 0), 0.006, 1, M_parent=M_w)
        # Front recessed dark bore emitter channel + twin crisp emit_cyan field emitter strips
        kb.plate(f"WingEmitRecess_{si}", crect_2d(0.26, 0.46, (0.04, 0.04, 0.04, 0.04)), 0.022, "bore", "plain_metal",
                 (0.0, 0.0, -0.046), (0, 0, 0), 0.003, 1, M_parent=M_w)
        for ei, ex in enumerate([-0.058, 0.058]):
            kb.box(f"WingEmitStrip_{si}_{ei}", (0.024, 0.38, 0.014), "emit_cyan", "plain_metal",
                   (ex, 0.0, -0.058), (0, 0, 0), 0.002, 1, M_parent=M_w)
        # 3 Horizontal copper busbar emitter waveguides spanning across the bore face
        for bi, by in enumerate([-0.14, 0.0, 0.14]):
            kb.box(f"WingCopperBar_{si}_{bi}", (0.24, 0.026, 0.018), "copper", "plain_metal",
                   (0.0, by, -0.064), (0, 0, 0), 0.003, 1, M_parent=M_w)
        # Top & bottom steel brush-guard rails + upper hazard trim + outer bolt accents
        kb.grab_rail(f"WingGuardTop_{si}", 0.24, 0.038, (0.0, 0.22, -0.044), (0, 0, 0), 0.008, M_parent=M_w)
        kb.grab_rail(f"WingGuardBot_{si}", 0.24, 0.038, (0.0, -0.22, -0.044), (0, 0, 0), 0.008, M_parent=M_w)
        kb.box(f"WingHazard_{si}", (0.18, 0.030, 0.014), "hazard", "hazard",
               (0.0, 0.255, 0.072), (0, 0, 0), 0.002, 1, M_parent=M_w)
        # Rear copper heat-sink fins
        for fi, fy in enumerate([-0.15, -0.05, 0.05, 0.15]):
            kb.box(f"WingFin_{si}_{fi}", (0.22, 0.018, 0.036), "gunmetal", "plain_metal",
                   (0.0, fy, 0.082), (0, 0, 0), 0.003, 1, M_parent=M_w)


# ==============================================================================
# 3. back_missile — MS-6 Armored 6-Cell Missile Launcher Pod
# ==============================================================================

def build_back_missile(kb: KitbashScene):
    """MS-6 Missile Pod: armored tilt cradle, twin hydraulic elevation rams, 6-cell boxy beveled pod with 6 recessed bores + visible warhead tips, rear blast exhaust louver."""
    # 1. Unified HP-B1 Base + Fire-Control Junction Box + Heavy Tilt Cradle Yoke
    _hp_b1_mount(kb, "HP_B1", bridge_w=0.82, bridge_d=0.34, z_center=0.04)

    # Transverse armored cradle base beam (y in [0.102, 0.186], width 1.04, z in [-0.12, +0.20])
    kb.box("CradleBeam", (1.04, 0.084, 0.32), "dark", "frame_cnc", (0.0, 0.144, 0.04), (0, 0, 0), 0.011, 1)
    kb.box("FireCtrlBox", (0.34, 0.14, 0.24), "armor_sub", "armor_pocket", (0.0, 0.22, 0.09), (0, 0, 0), 0.010, 1)
    kb.box("CradleHazard", (0.30, 0.034, 0.016), "hazard", "hazard", (0.0, 0.21, 0.214), (0, 0, 0), 0.002, 1)

    # Twin Heavy Side Trunnion Yoke Stanchions + Geared Trunnion Drums + Twin Hydraulic Elevation Rams
    for si, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"YokeArm_{si}", trap_2d(0.28, 0.20, 0.38, 0.03), 0.095, "gunmetal", "bolt_flange",
                 (sx * 0.475, 0.34, 0.08), (0, 90, 0), 0.010, 1)
        kb.cyl(f"TrunnionDrum_{si}", 0.088, 0.088, 0.16, 16, "dark", "gear_collar",
               (sx * 0.475, 0.48, 0.09), (0, 0, 90), 0.006, u_rep=2.0)
        kb.cyl(f"TrunnionAxle_{si}", 0.046, 0.046, 0.20, 12, "chrome", "plain_metal",
               (sx * 0.475, 0.48, 0.09), (0, 0, 90), 0.004)
        kb.bolt_ring(f"TrunnionBolts_{si}", 0.068, 6, 0.009, (sx * 0.562, 0.48, 0.09), (0, 0, 90))
        # Twin hydraulic elevation rams: lower front cradle clevis -> pod lower front lug
        kb.hydraulic(f"ElevRam_{si}", (sx * 0.30, 0.165, -0.07), (sx * 0.30, 0.37, -0.10), 0.021)
        # Braided fire-control umbilical cable from FireCtrlBox into pod flank
        kb.tube_path(f"FireCable_{si}", [
            (sx * 0.15, 0.23, 0.18), (sx * 0.34, 0.27, 0.24), (sx * 0.42, 0.44, 0.20)
        ], 0.014, 8, "gunmetal", "braid_hose")

    # Left-side compact target-acquisition telemetry pod mounted cleanly on left trunnion yoke (asymmetric detail)
    kb.box("TargetPod", (0.115, 0.135, 0.185), "armor_sub", "armor_pocket", (-0.59, 0.48, 0.06), (0, 0, 0), 0.010, 1)
    kb.cyl("TargetBezel", 0.036, 0.038, 0.024, 14, "gunmetal", "gear_collar", (-0.59, 0.49, -0.036), (90, 0, 0), 0.003, hollow_r=0.026)
    kb.cyl("TargetLens", 0.025, 0.025, 0.014, 14, "glass", "plain_metal", (-0.59, 0.49, -0.035), (90, 0, 0), 0.002)
    kb.cyl("TargetPip", 0.008, 0.008, 0.016, 8, "emit_amber", "plain_metal", (-0.59, 0.49, -0.037), (90, 0, 0), 0.001)

    # 2. Tilted 6-Cell Armored Missile Launcher Pod (pitched +14 deg upward on -Z front!)
    # Check bounds: center (0, 0.54, 0.09), pod L=0.56, H=0.44, W=0.82 -> z in [-0.24, +0.42], y in [0.27, 0.82], |x| <= 0.45
    M_pod = g2b_mat((0.0, 0.54, 0.09), (14.0, 0.0, 0.0))

    # Main beveled armored shroud casing (extruded chamfered rectangle along X)
    kb.plate("PodShroud", crect_2d(0.56, 0.44, (0.06, 0.05, 0.04, 0.04)), 0.80, "armor", "armor_panel",
             (0.0, 0.0, 0.0), (0, 90, 0), 0.015, 1, M_parent=M_pod)
    # Top ribbed blast hood + front armored overhanging rain-brow + top lifting grab rails
    kb.box("PodRoofHood", (0.76, 0.042, 0.48), "armor_sub", "armor_ribs", (0.0, 0.228, 0.01), (0, 0, 0), 0.008, 1, M_parent=M_pod)
    kb.box("PodFrontBrow", (0.82, 0.036, 0.10), "gunmetal", "bolt_flange", (0.0, 0.225, -0.265), (-8, 0, 0), 0.006, 1, M_parent=M_pod)
    for gi, gx in enumerate([-0.24, 0.24]):
        _top_grab_rail(kb, f"PodTopGrab_{gi}", 0.22, 0.038, (gx, 0.247, 0.02), yaw_deg=90.0, r=0.009, M_parent=M_pod)

    # Left & right spaced side armor cheek plates + trunnion pivot bosses + proud accent stripes
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"PodSideArmor_{si}", (0.036, 0.32, 0.44), "armor_sub", "armor_hatch",
               (sx * 0.412, -0.01, 0.02), (0, 0, 0), 0.007, 1, M_parent=M_pod)
        kb.box(f"PodSideAccent_{si}", (0.016, 0.042, 0.36), "accent", "plain_metal",
               (sx * 0.432, 0.105, 0.02), (0, 0, 0), 0.003, 1, M_parent=M_pod)
        # Lower elevation ram anchor lug cleanly proud of hydraulic clevis (zero Z-fighting!)
        kb.box(f"PodRamLug_{si}", (0.082, 0.068, 0.105), "dark", "bolt_flange",
               (sx * 0.30, -0.238, -0.145), (0, 0, 0), 0.006, 1, M_parent=M_pod)

    # 3. Front Armored Faceplate + 6 Recessed Circular Missile Tube Bores (3x2) with Visible Red/Accent Warhead Tips
    kb.box("PodFrontPlate", (0.76, 0.40, 0.042), "gunmetal", "bolt_flange",
           (0.0, 0.0, -0.278), (0, 0, 0), 0.008, 1, M_parent=M_pod)
    for col in range(3):
        for row in range(2):
            mx = -0.23 + col * 0.23
            my = 0.095 - row * 0.19
            # Machined hollow missile launch tube bezel extending forward (-Z)
            kb.cyl(f"TubeLip_{col}_{row}", 0.084, 0.086, 0.068, 16, "dark", "plain_metal",
                   (mx, my, -0.298), (-90, 0, 0), 0.004, hollow_r=0.069, M_parent=M_pod)
            kb.cyl(f"TubeCollar_{col}_{row}", 0.090, 0.090, 0.018, 16, "gunmetal", "gear_collar",
                   (mx, my, -0.285), (-90, 0, 0), 0.002, hollow_r=0.078, M_parent=M_pod)
            # Deep black recessed bore backplate inside the hollow tube
            kb.cyl(f"TubeBore_{col}_{row}", 0.068, 0.068, 0.022, 12, "bore", "plain_metal",
                   (mx, my, -0.276), (-90, 0, 0), 0.001, M_parent=M_pod)
            # Visible tactical missile warhead seated cleanly on bore backplate (tip flush with muzzle)
            kb.cyl(f"MissileBody_{col}_{row}", 0.048, 0.052, 0.036, 14, "armor_dark", "plain_metal",
                   (mx, my, -0.298), (-90, 0, 0), 0.003, M_parent=M_pod)
            kb.cyl(f"MissileBand_{col}_{row}", 0.049, 0.049, 0.012, 14, "accent", "plain_metal",
                   (mx, my, -0.312), (-90, 0, 0), 0.002, M_parent=M_pod)
            # Tapered crimson/red warhead seeker nosecone (lathe along local +Y -> Godot -Z via (-90, 0, 0))
            kb.lathe(f"MissileTip_{col}_{row}", [
                (0.0, 0.0), (0.044, 0.0), (0.040, 0.014), (0.024, 0.028), (0.008, 0.034), (0.0, 0.036)
            ], 12, "emit_red", "plain_metal", (mx, my, -0.316), (-90, 0, 0), M_parent=M_pod)

    # 4. Rear Blast Exhaust Shroud & Louver Grill + Corner Blast Latches (4mm clean seat -> 0 Z-fight, 0 burial!)
    kb.box("PodRearFrame", (0.74, 0.38, 0.036), "dark", "frame_cnc",
           (0.0, 0.0, 0.274), (0, 0, 0), 0.007, 1, M_parent=M_pod)
    kb.louver_bay("RearBlastLouver", 0.60, 0.26, 0.036, (0.0, 0.0, 0.306), (0, 180, 0),
                  blades=5, mesh_style=False, M_parent=M_pod)
    kb.box("RearBlastHazard", (0.58, 0.030, 0.014), "hazard", "hazard",
           (0.0, -0.175, 0.298), (0, 0, 0), 0.002, 1, M_parent=M_pod)


# ==============================================================================
# 4. back_vls — VLS-12 Naval Mk41-Style 12-Cell Vertical Launch Monolith
# ==============================================================================

def build_back_vls(kb: KitbashScene):
    """VLS-12 Monolith: 4x3 beveled individual top hatch lids with hinge pins & hazard surround, central flame-duct exhaust chimney, side ammo-loading grab rails & inspection hatches."""
    # 1. Unified HP-B1 Base + Compact Raised Lower Pedestal (clears core_command exhausts/whips & core_heavy ExhShield!)
    _hp_b1_mount(kb, "HP_B1", bridge_w=0.78, bridge_d=0.34, z_center=0.05)
    kb.box("LowerPedestal", (0.76, 0.068, 0.36), "dark", "frame_cnc", (0.0, 0.132, 0.08), (0, 0, 0), 0.010, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"PedGusset_{si}", (0.14, 0.072, 0.30), "gunmetal", "bolt_flange",
               (sx * 0.42, 0.155, 0.10), (0, 0, sx * -20.0), 0.007, 1)

    # 2. Main Armored Naval Mk41 Monolith Box (y in [0.165, 0.675], x in [-0.585, +0.585], z in [-0.155, +0.415])
    zc = 0.130
    kb.box("VLS_Monolith", (1.17, 0.51, 0.57), "armor", "armor_panel", (0.0, 0.420, zc), (0, 0, 0), 0.016, 1, tile_u=2.0)

    # Front Sloped Deflector Brow + Central Fire-Control Umbilical Spine + Left/Right Blast Ribs
    kb.plate("FrontBrow", trap_2d(1.14, 1.06, 0.14, 0.03), 0.050, "gunmetal", "bolt_flange",
             (0.0, 0.595, zc - 0.285), (-18, 0, 0), 0.008, 1)
    kb.box("FrontSpine", (0.16, 0.44, 0.044), "dark", "frame_cnc", (0.0, 0.39, zc - 0.288), (0, 0, 0), 0.008, 1)
    kb.cyl("FrontUmbilicalPlug", 0.026, 0.030, 0.030, 10, "brass", "gear_collar", (0.0, 0.30, zc - 0.314), (90, 0, 0), 0.003)
    kb.tube_path("FrontUmbilicalHose", [
        (0.0, 0.29, zc - 0.312), (0.11, 0.20, zc - 0.295), (0.14, 0.12, -0.09)
    ], 0.014, 8, "gunmetal", "braid_hose")
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"FrontPanel_{si}", (0.40, 0.34, 0.026), "armor_sub", "armor_hatch",
               (sx * 0.33, 0.37, zc - 0.290), (0, 0, 0), 0.006, 1)
        for ri in range(3):
            kb.box(f"FrontRib_{si}_{ri}", (0.34, 0.024, 0.020), "gunmetal", "armor_ribs",
                   (sx * 0.33, 0.26 + ri * 0.11, zc - 0.306), (0, 0, 0), 0.003, 1)

    # Left & Right Side Inspection Hatches + Anti-Blast Vertical Ribs + Side Ammo-Loading Grab Rails (max |x| <= 0.65!)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"SideInspHatch_{si}", (0.38, 0.30, 0.030), "armor_sub", "armor_hatch",
                              (sx * 0.602, 0.39, zc), (0, -sx * 90.0, 0))
        for ri, rz in enumerate([zc - 0.21, zc - 0.07, zc + 0.07, zc + 0.21]):
            kb.box(f"SideBlastRib_{si}_{ri}", (0.034, 0.44, 0.034), "gunmetal", "bolt_flange",
                   (sx * 0.598, 0.42, rz), (0, 0, 0), 0.005, 1)
        kb.grab_rail(f"SideLoadGrabTop_{si}", 0.30, 0.040, (sx * 0.596, 0.60, zc), (0, -sx * 90.0, 0), 0.009)
        kb.grab_rail(f"SideLoadGrabBot_{si}", 0.24, 0.038, (sx * 0.596, 0.22, zc), (0, -sx * 90.0, 0), 0.009)
        kb.box(f"SideAccent_{si}", (0.015, 0.036, 0.42), "accent", "plain_metal",
               (sx * 0.600, 0.638, zc), (0, 0, 0), 0.002, 1)

    # Rear Hot-Launch Plenum Exhaust Louvers + Rear Service Panel
    for si, sx in enumerate([-1.0, 1.0]):
        kb.louver_bay(f"RearExhaustBay_{si}", 0.34, 0.30, 0.038, (sx * 0.33, 0.42, zc + 0.296),
                      (0, 180, 0), blades=5, mesh_style=False)
    kb.box("RearCenterPanel", (0.20, 0.34, 0.030), "dark", "armor_pocket", (0.0, 0.42, zc + 0.292), (0, 0, 0), 0.006, 1)
    kb.box("RearHazardBar", (1.06, 0.038, 0.018), "hazard", "hazard", (0.0, 0.205, zc + 0.292), (0, 0, 0), 0.003, 1)

    # 3. Top Deck Coaming + Hazard Blast Surround + Central Flame-Duct Exhaust Chimney
    kb.box("TopCoaming", (1.21, 0.048, 0.61), "gunmetal", "bolt_flange", (0.0, 0.688, zc), (0, 0, 0), 0.009, 1)
    kb.box("TopHazardFront", (1.12, 0.028, 0.020), "hazard", "hazard", (0.0, 0.692, zc - 0.308), (0, 0, 0), 0.003, 1)
    kb.box("TopHazardRear", (1.12, 0.028, 0.020), "hazard", "hazard", (0.0, 0.692, zc + 0.308), (0, 0, 0), 0.003, 1)

    # Central Flame-Duct Exhaust Chimney (splitting left 2x3 and right 2x3 launch banks, authentic Mk41 plenum!)
    kb.box("FlameChimneyBase", (0.145, 0.072, 0.55), "dark", "frame_cnc", (0.0, 0.738, zc), (0, 0, 0), 0.007, 1)
    kb.box("FlameChimneyBore", (0.10, 0.018, 0.48), "bore", "plain_metal", (0.0, 0.776, zc), (0, 0, 0), 0.002, 1)
    for bi, bz in enumerate([zc - 0.19, zc - 0.06, zc + 0.06, zc + 0.19]):
        kb.box(f"ChimneyBaffle_{bi}", (0.105, 0.036, 0.014), "gunmetal", "plain_metal",
               (0.0, 0.776, bz), (28, 0, 0), 0.002, 1)
    for pi, (px, pz) in enumerate([(-0.060, zc - 0.24), (0.060, zc - 0.24), (-0.060, zc + 0.24), (0.060, zc + 0.24)]):
        kb.box(f"ChimneyPost_{pi}", (0.020, 0.056, 0.020), "gunmetal", "plain_metal",
               (px, 0.790, pz), (0, 0, 0), 0.002, 1)
    kb.box("FlameChimneyHood", (0.160, 0.022, 0.53), "armor_sub", "armor_ribs", (0.0, 0.818, zc), (0, 0, 0), 0.005, 1)

    # 4. 4x3 Grid of 12 Beveled Individual VLS Hatch Lids + Chrome Hinge Pins & Cell Rims
    cell_xs = [-0.455, -0.215, 0.215, 0.455]
    cell_zs = [zc - 0.190, zc, zc + 0.190]
    for ci, cx in enumerate(cell_xs):
        for ri, cz in enumerate(cell_zs):
            kb.box(f"CellRim_{ci}_{ri}", (0.216, 0.022, 0.172), "dark", "plain_metal",
                   (cx, 0.718, cz), (0, 0, 0), 0.004, 1)
            kb.box(f"HatchLid_{ci}_{ri}", (0.192, 0.028, 0.146), "armor_sub", "armor_hatch",
                   (cx, 0.740, cz), (0, 0, 0), 0.006, 1)
            kb.box(f"HatchBoss_{ci}_{ri}", (0.125, 0.014, 0.085), "gunmetal", "armor_ribs",
                   (cx, 0.758, cz), (0, 0, 0), 0.003, 1)
            kb.cyl(f"HingePin_{ci}_{ri}", 0.010, 0.010, 0.155, 6, "chrome", "plain_metal",
                   (cx, 0.742, cz + 0.078), (0, 0, 90), 0.002)
            for ki, kx in enumerate([-0.056, 0.056]):
                kb.box(f"HingeKnk_{ci}_{ri}_{ki}", (0.024, 0.026, 0.026), "gunmetal", "plain_metal",
                       (cx + kx, 0.738, cz + 0.076), (0, 0, 0), 0.003, 1)
            kb.box(f"HatchLatch_{ci}_{ri}", (0.040, 0.018, 0.018), "accent", "plain_metal",
                   (cx, 0.746, cz - 0.074), (0, 0, 0), 0.002, 1)


# ==============================================================================
# 5. back_rocket — RP-7 Dual 7-Tube Unguided Rocket Pods
# ==============================================================================

def build_back_rocket(kb: KitbashScene):
    """RP-7 Rocket Pods: dual armored cylindrical/hexagonal 7-tube honeycomb rocket pods on central elevation gimbal yoke with hydraulic rams, rear blast shields & wire-mesh vents."""
    # 1. Unified HP-B1 Base + Central Gimbal Turret Pedestal & Ballistic Sensor
    _hp_b1_mount(kb, "HP_B1", bridge_w=0.80, bridge_d=0.34, z_center=0.04)

    kb.cyl("GimbalBaseRing", 0.185, 0.205, 0.075, 20, "dark", "gear_collar", (0.0, 0.135, 0.06), (0, 0, 0), 0.006, u_rep=2.0)
    kb.box("GimbalBody", (0.36, 0.30, 0.32), "armor_sub", "armor_pocket", (0.0, 0.305, 0.07), (0, 0, 0), 0.014, 1)
    kb.box("GimbalRearHatch", (0.26, 0.20, 0.032), "gunmetal", "armor_hatch", (0.0, 0.30, 0.236), (0, 0, 0), 0.005, 1)
    kb.box("GimbalHazard", (0.24, 0.032, 0.014), "hazard", "hazard", (0.0, 0.19, 0.238), (0, 0, 0), 0.002, 1)

    # Top compact ballistic inclinometer / fire-control sensor turret
    kb.cyl("SensorBase", 0.072, 0.082, 0.048, 14, "gunmetal", "bolt_flange", (0.0, 0.475, 0.06), (0, 0, 0), 0.004)
    kb.box("SensorHead", (0.14, 0.095, 0.125), "armor", "armor_pocket", (0.0, 0.535, 0.05), (0, 0, 0), 0.009, 1)
    kb.cyl("SensorBezel", 0.032, 0.034, 0.022, 12, "gunmetal", "plain_metal", (0.0, 0.535, -0.016), (90, 0, 0), 0.002, hollow_r=0.023)
    kb.cyl("SensorLens", 0.022, 0.022, 0.014, 12, "glass", "plain_metal", (0.0, 0.535, -0.014), (90, 0, 0), 0.002)
    kb.cyl("SensorPip", 0.007, 0.007, 0.016, 8, "emit_cyan", "plain_metal", (0.0, 0.535, -0.017), (90, 0, 0), 0.001)

    # Horizontal Elevation Cross-Axle Shaft + Trunnion Flanges + Outriggers (stepped cleanly clear of GimbalBaseRing!)
    kb.cyl("ElevAxle", 0.064, 0.064, 0.86, 16, "dark", "frame_cnc", (0.0, 0.42, 0.08), (0, 0, 90), 0.006)
    kb.box("LowerRamBar", (0.68, 0.052, 0.11), "dark", "bolt_flange", (0.0, 0.130, 0.19), (0, 0, 0), 0.007, 1)

    # 2. Left & Right Heavy Cylindrical/Hexagonal Armored 7-Tube Rocket Pods
    # Pod center x = ±0.505, r_outer = 0.225 -> |x| <= 0.745 <= 0.78!
    # Pod length 0.58, tilted +10 deg up at front -> z in [-0.24, +0.42], y in [0.18, 0.78]
    for si, sx in enumerate([-1.0, 1.0]):
        # Trunnion collar & bolted bearing ring on axle
        kb.cyl(f"AxleFlange_{si}", 0.095, 0.095, 0.075, 16, "gunmetal", "gear_collar",
               (sx * 0.23, 0.42, 0.08), (0, 0, 90), 0.005, u_rep=2.0)
        kb.bolt_ring(f"AxleBolts_{si}", 0.074, 6, 0.009, (sx * 0.272, 0.42, 0.08), (0, 0, 90))
        # Hydraulic elevation ram + braided ignition umbilical hose
        kb.hydraulic(f"PodHyd_{si}", (sx * 0.28, 0.145, 0.19), (sx * 0.45, 0.295, 0.23), 0.020)
        kb.tube_path(f"IgniteHose_{si}", [
            (sx * 0.16, 0.26, 0.21), (sx * 0.30, 0.28, 0.28), (sx * 0.42, 0.38, 0.22)
        ], 0.013, 8, "copper" if si == 0 else "gunmetal", "braid_hose")

        M_p = g2b_mat((sx * 0.505, 0.465, 0.09), (10.0, 0.0, 0.0))

        # Main heavy 12-sided / cylindrical armored rocket pod shell (axis along Z)
        kb.cyl(f"PodShell_{si}", 0.218, 0.218, 0.56, 12, "armor", "armor_panel",
               (0.0, 0.0, 0.0), (90, 0, 0), 0.012, u_rep=2.0, M_parent=M_p)
        # Inner trunnion saddle lug clamping pod to elevation axle
        kb.box(f"PodAxleSaddle_{si}", (0.14, 0.15, 0.18), "dark", "frame_cnc",
               (-sx * 0.19, -0.04, -0.01), (0, 0, 0), 0.009, 1, M_parent=M_p)
        # Lower rear hydraulic anchor lug
        kb.box(f"PodHydLug_{si}", (0.068, 0.062, 0.088), "dark", "bolt_flange",
               (-sx * 0.05, -0.21, 0.12), (0, 0, 0), 0.006, 1, M_parent=M_p)

        # 3 Heavy Machined Reinforcing Collar Bands + Top Spine Rib + Grab Handle
        for bi, bz in enumerate([-0.21, 0.0, 0.21]):
            kb.cyl(f"PodBand_{si}_{bi}", 0.232, 0.232, 0.036, 12, "gunmetal", "gear_collar",
                   (0.0, 0.0, bz), (90, 0, 0), 0.004, u_rep=2.0, M_parent=M_p)
        kb.box(f"PodTopSpine_{si}", (0.12, 0.046, 0.52), "armor_sub", "armor_ribs",
               (0.0, 0.218, 0.0), (0, 0, 0), 0.007, 1, M_parent=M_p)
        _top_grab_rail(kb, f"PodGrab_{si}", 0.22, 0.036, (0.0, 0.240, 0.0), yaw_deg=90.0, r=0.008, M_parent=M_p)

        # Outboard Armored Cheek Shield + Wire-Mesh Exhaust Vent Panel + Accent Stripe
        kb.box(f"PodCheekArmor_{si}", (0.034, 0.18, 0.42), "armor_sub", "armor_hatch",
               (sx * 0.220, 0.0, -0.01), (0, 0, 0), 0.007, 1, M_parent=M_p)
        kb.box(f"PodCheekAccent_{si}", (0.014, 0.034, 0.34), "accent", "plain_metal",
               (sx * 0.238, 0.055, -0.01), (0, 0, 0), 0.002, 1, M_parent=M_p)
        # Side wire-mesh exhaust bleed vent housing seated proudly on upper-outboard pod flank (zero burial!)
        M_sv = M_p @ g2b_mat((sx * 0.162, 0.162, 0.08), (0.0, 0.0, -sx * 45.0))
        kb.box(f"PodVentPad_{si}", (0.095, 0.030, 0.21), "gunmetal", "bolt_flange",
               (0.0, 0.0, 0.0), (0, 0, 0), 0.004, 1, M_parent=M_sv)
        kb.box(f"PodVentMesh_{si}", (0.074, 0.014, 0.175), "dark", "vent_mesh",
               (0.0, 0.018, 0.0), (0, 0, 0), 0.002, 1, M_parent=M_sv)

        # Front Perforated Honeycomb Rocket Face (7 recessed tubes: 1 center + 6 hex ring!)
        kb.cyl(f"PodMuzzleShroud_{si}", 0.228, 0.228, 0.068, 12, "gunmetal", "plain_metal",
               (0.0, 0.0, -0.285), (-90, 0, 0), 0.005, hollow_r=0.194, M_parent=M_p)
        kb.cyl(f"PodHoneycombPlate_{si}", 0.196, 0.196, 0.032, 12, "dark", "plain_metal",
               (0.0, 0.0, -0.270), (-90, 0, 0), 0.003, M_parent=M_p)
        tube_offsets = [(0.0, 0.0)] + [
            (math.cos(math.tau * k / 6.0) * 0.114, math.sin(math.tau * k / 6.0) * 0.114)
            for k in range(6)
        ]
        for ti, (tx, ty) in enumerate(tube_offsets):
            # Machined hollow rocket launch tube lip
            kb.cyl(f"RktTube_{si}_{ti}", 0.049, 0.050, 0.052, 10, "gunmetal", "plain_metal",
                   (tx, ty, -0.288), (-90, 0, 0), 0.003, hollow_r=0.039, M_parent=M_p)
            # Deep black recessed bore interior
            kb.cyl(f"RktBore_{si}_{ti}", 0.038, 0.038, 0.018, 8, "bore", "plain_metal",
                   (tx, ty, -0.274), (-90, 0, 0), 0.001, M_parent=M_p)
            # Recessed rocket warhead nosecone seated cleanly on bore backplate
            kb.lathe(f"RktTip_{si}_{ti}", [
                (0.0, 0.0), (0.030, 0.0), (0.026, 0.014), (0.010, 0.028), (0.0, 0.032)
            ], 8, "brass" if ti == 0 else "accent", "plain_metal",
                (tx, ty, -0.282), (-90, 0, 0), M_parent=M_p)

        # Rear Blast Shield Cone + Wire-Mesh Blast Diffuser Panel + Cross Baffles + Lower Apron Shield
        kb.cyl(f"PodRearShroud_{si}", 0.226, 0.214, 0.065, 12, "gunmetal", "bolt_flange",
               (0.0, 0.0, 0.285), (90, 0, 0), 0.005, hollow_r=0.186, M_parent=M_p)
        kb.cyl(f"PodRearMesh_{si}", 0.188, 0.188, 0.026, 12, "dark", "vent_mesh",
               (0.0, 0.0, 0.272), (90, 0, 0), 0.003, M_parent=M_p)
        # Crossed steel blast diffuser baffles across rear mesh face
        kb.box(f"RearBaffleH_{si}", (0.37, 0.024, 0.024), "gunmetal", "plain_metal",
               (0.0, 0.0, 0.292), (0, 0, 0), 0.003, 1, M_parent=M_p)
        kb.box(f"RearBaffleV_{si}", (0.024, 0.37, 0.024), "gunmetal", "plain_metal",
               (0.0, 0.0, 0.292), (0, 0, 0), 0.003, 1, M_parent=M_p)
        # Angled lower rear blast-deflector apron shield
        kb.box(f"RearApron_{si}", (0.28, 0.026, 0.12), "armor_sub", "armor_ribs",
               (0.0, -0.218, 0.275), (-22, 0, 0), 0.005, 1, M_parent=M_p)
