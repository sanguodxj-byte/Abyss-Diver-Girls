"""Set of 5 Production-Grade Mech Generators — Zero-Clip Rich Mechanical Standard (v1.5).

Contains 5 high-precision rear powerplant modules:
  1. gen_reactor   (RT-1 Prototype Medium Fission/Plasma Reactor)
  2. gen_diesel    (DS-6 Industrial V-Block Diesel Generator)
  3. gen_turbine   (TB-5 Compact Armored Gas-Turbine Unit)
  4. gen_crystal   (CR-8 Prototype Abyssal Crystal Reactor)
  5. gen_hfc       (HFC-3 Twin-Tank Hydrogen Fuel-Cell Stack)

Clearance Envelope (strictly enforced for zero assembly clash across all 21 cores & backpacks):
  - HP-G1 front mount collar sits cleanly at z = 0.00 (z >= -0.004, ZERO forward protrusion)
  - CRITICAL HEIGHT CAP: y in [-0.28, +0.42] (clears back_* on core_scout dy=0.44 & core_assault dy=0.51!)
  - Width |x| <= 0.56, rearward depth z in [0.00, +0.76]
  - Budgets: 3,500 <= tris <= 13,000, size <= 800 KB
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


# ==============================================================================
# SHARED HP-G1 REAR POWER-BAY MOUNT BULKHEAD
# ==============================================================================

def _hp_g1_mount(kb: KitbashScene, prefix: str = "HP_G1", w: float = 0.76, h: float = 0.50, y_c: float = 0.01):
    """Unified HP-G1 front bulkhead collar strictly within z >= +0.003 and y in [-0.26, +0.28]."""
    # Main chamfered steel mating plate (z in [0.004, 0.092])
    kb.plate(f"{prefix}_plate", crect_2d(w, h, (0.08, 0.08, 0.08, 0.08)), 0.088, "dark", "bolt_flange",
             (0.0, y_c, 0.048), (0, 0, 0), 0.011, 1)
    # Recessed inner alignment boss ring on rear face
    kb.box(f"{prefix}_boss", (w - 0.14, h - 0.12, 0.036), "gunmetal", "frame_cnc",
           (0.0, y_c, 0.098), (0, 0, 0), 0.007, 1)
    # 4 corner heavy chrome docking lock pins + amber gear collars
    hx, hy = w * 0.5 - 0.085, h * 0.5 - 0.075
    for ci, (cx, cy) in enumerate([(-hx, -hy), (hx, -hy), (-hx, hy), (hx, hy)]):
        kb.cyl(f"{prefix}_pin{ci}", 0.026, 0.028, 0.048, 10, "chrome", "plain_metal",
               (cx, y_c + cy, 0.108), (90, 0, 0), 0.003)
        kb.cyl(f"{prefix}_rng{ci}", 0.038, 0.038, 0.018, 12, "accent", "gear_collar",
               (cx, y_c + cy, 0.130), (90, 0, 0), 0.003)


# ==============================================================================
# 1. gen_reactor — RT-1 Prototype Medium Fission / Plasma Reactor
# ==============================================================================

def build_gen_reactor(kb: KitbashScene):
    """RT-1 Reactor: armored turbine/fission casing, recessed emit_core plasma sight tube inside protective cage ribs, twin copper coolant manifolds, rear louvered radiator + LIGHT_core."""
    # 1. Unified HP-G1 Bulkhead Collar (y in [-0.24, +0.26], z in [0.004, 0.092])
    _hp_g1_mount(kb, "HP_G1", w=0.76, h=0.50, y_c=0.01)

    # 2. Heavy Armored Cylindrical Fission / Containment Casing + Cradle Cheeks
    # Vessel center (0, 0.02, 0.31), r=0.235, L=0.44 -> y in [-0.215, +0.255], z in [0.09, 0.53]
    kb.cyl("ReactorVessel", 0.235, 0.235, 0.44, 24, "armor", "armor_panel",
           (0.0, 0.02, 0.31), (90, 0, 0), 0.010, u_rep=2.0)
    # Heavy bolted front & rear pressure containment flanges
    kb.cyl("VesselFlangeF", 0.260, 0.260, 0.048, 24, "dark", "bolt_flange",
           (0.0, 0.02, 0.12), (90, 0, 0), 0.005, u_rep=2.0)
    kb.cyl("VesselFlangeR", 0.262, 0.262, 0.052, 24, "gunmetal", "bolt_flange",
           (0.0, 0.02, 0.50), (90, 0, 0), 0.005, u_rep=2.0)
    kb.cyl("VesselWaistBand", 0.252, 0.252, 0.036, 24, "dark", "gear_collar",
           (0.0, 0.02, 0.31), (90, 0, 0), 0.004, u_rep=2.0)
    kb.bolt_ring("VesselRearBolts", 0.235, 10, 0.011, (0.0, 0.02, 0.532), (90, 0, 0))

    # 8 Radial forged heat-exchange cooling fins on lower & side arcs (leaving dorsal slot clear for plasma tube!)
    for fi, ang_deg in enumerate([-150, -120, -90, -60, -30, 180, 0, 150]):
        a = math.radians(ang_deg)
        fx = math.cos(a) * 0.255
        fy = 0.02 + math.sin(a) * 0.255
        if fy < -0.22:
            continue
        kb.box(f"CoolFin_{fi}", (0.020, 0.072, 0.34), "gunmetal", "plain_metal",
               (fx, fy, 0.31), (0, 0, ang_deg + 90.0), 0.003, 1)

    # Left & right lead-shielded cradle cheek plates + side grab handles
    for si, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"CradleCheek_{si}", trap_2d(0.36, 0.26, 0.44, 0.04), 0.056, "armor_sub", "armor_pocket",
                 (sx * 0.295, 0.01, 0.28), (0, 90, 0), 0.010, 1)
        kb.grab_rail(f"ReactorGrab_{si}", 0.22, 0.038, (sx * 0.320, 0.12, 0.28), (0, -sx * 90.0, 0), 0.009)

    # 3. Recessed Glowing emit_core Plasma Sight Tube Inside Protective Armored Cage Ribs (y <= 0.395!)
    # Dorsal armored trough base seated cleanly on vessel crown (y = 0.23..0.285)
    kb.box("SightTrough", (0.20, 0.056, 0.36), "dark", "frame_cnc", (0.0, 0.262, 0.31), (0, 0, 0), 0.007, 1)
    kb.box("SightBoreBed", (0.11, 0.016, 0.30), "bore", "plain_metal", (0.0, 0.292, 0.31), (0, 0, 0), 0.002, 1)
    # Front & rear brass containment collars holding the sight tube (pedestals wider along Z -> 0 Z-fight!)
    for ei, ez in enumerate([0.148, 0.472]):
        kb.cyl(f"SightCollar_{ei}", 0.062, 0.066, 0.040, 14, "brass", "gear_collar",
               (0.0, 0.320, ez), (90, 0, 0), 0.004)
        kb.box(f"SightPedestal_{ei}", (0.14, 0.075, 0.058), "gunmetal", "bolt_flange",
               (0.0, 0.285, ez), (0, 0, 0), 0.005, 1)
    # Glowing cylindrical plasma sight tube (r=0.040, L=0.31, tips seat 7mm into brass collars -> 0 floating, 0 buried!)
    kb.cyl("PlasmaSightTube", 0.040, 0.040, 0.31, 16, "emit_core", "plain_metal",
           (0.0, 0.320, 0.31), (90, 0, 0), 0.003)
    # 4 Protective armored steel cage ribs arching cleanly over the plasma sight tube (max_y = 0.396 <= 0.42!)
    for ri, rz in enumerate([0.205, 0.275, 0.345, 0.415]):
        for side_i, sx in enumerate([-0.088, 0.088]):
            kb.box(f"CageRibPost_{ri}_{side_i}", (0.022, 0.115, 0.022), "gunmetal", "plain_metal",
                   (sx, 0.325, rz), (0, 0, 0), 0.003, 1)
        kb.box(f"CageRibTop_{ri}", (0.198, 0.020, 0.024), "gunmetal", "armor_ribs",
               (0.0, 0.382, rz), (0, 0, 0), 0.003, 1)
    # Twin longitudinal protective cage rails connecting all 4 ribs
    for si, sx in enumerate([-0.088, 0.088]):
        kb.box(f"CageRail_{si}", (0.018, 0.020, 0.34), "dark", "plain_metal",
               (sx, 0.378, 0.31), (0, 0, 0), 0.002, 1)
    # Top-front brass pressure relief valve & amber pressure cap seated directly into ReactorVessel shoulder!
    kb.cyl("ReliefValve", 0.026, 0.032, 0.068, 10, "brass", "gear_collar", (0.165, 0.215, 0.18), (0, 0, 0), 0.003)
    kb.cyl("ReliefCap", 0.036, 0.036, 0.018, 10, "accent", "plain_metal", (0.165, 0.254, 0.18), (0, 0, 0), 0.002)

    # 4. Twin Copper Coolant Manifolds + Lower Circulation Pumps + Brass Valve Fittings
    for si, sx in enumerate([-1.0, 1.0]):
        # Lower coolant pump cylinder seated against cradle cheek (flange stepped 15mm inboard of rear cap -> 0 Z-fight!)
        kb.cyl(f"CoolPump_{si}", 0.056, 0.056, 0.22, 14, "dark", "armor_ribs",
               (sx * 0.355, -0.125, 0.29), (90, 0, 0), 0.005)
        kb.cyl(f"CoolPumpFl_{si}", 0.066, 0.066, 0.024, 14, "brass", "gear_collar",
               (sx * 0.355, -0.125, 0.372), (90, 0, 0), 0.003)
        # Upper copper return manifold pipe: G1 bulkhead -> flank -> rear radiator manifold
        kb.tube_path(f"CopperManifoldTop_{si}", [
            (sx * 0.30, 0.17, 0.07), (sx * 0.38, 0.16, 0.31), (sx * 0.28, 0.15, 0.56)
        ], 0.021, 8, "copper", "plain_metal", add_clamps=True, clamp_mat="gunmetal")
        # Lower copper feed manifold pipe: pump -> rear radiator lower tank
        kb.tube_path(f"CopperManifoldBot_{si}", [
            (sx * 0.355, -0.125, 0.39), (sx * 0.36, -0.15, 0.50), (sx * 0.26, -0.13, 0.58)
        ], 0.019, 8, "copper", "braid_hose", add_clamps=True, clamp_mat="brass")
        # Front pump suction stub into HP-G1 bulkhead
        kb.tube_path(f"PumpSuction_{si}", [
            (sx * 0.355, -0.125, 0.19), (sx * 0.32, -0.14, 0.12), (sx * 0.26, -0.13, 0.07)
        ], 0.018, 8, "gunmetal", "braid_hose")

    # 5. Rear Armored Louvered Radiator Shroud + Recessed Cherenkov Rear Core Port
    kb.box("RearRadHousing", (0.58, 0.44, 0.14), "armor_sub", "armor_hatch",
           (0.0, 0.01, 0.585), (0, 0, 0), 0.012, 1)
    # Lower wide rear louvered radiator bay
    kb.louver_bay("RearRadiatorBot", 0.48, 0.135, 0.042, (0.0, -0.115, 0.668), (0, 180, 0), blades=4, mesh_style=False)
    # Left & right upper vertical wire-mesh heat exhaust louvers flanking the central core sight port
    for si, sx in enumerate([-0.20, 0.20]):
        kb.louver_bay(f"RearRadiatorSide_{si}", 0.12, 0.16, 0.038, (sx, 0.105, 0.666), (0, 180, 0), blades=3, mesh_style=True)
    # Central rear armored radiation sight port (recessed emit_core + protective steel X-guard)
    kb.cyl("RearPortCollar", 0.088, 0.094, 0.044, 16, "dark", "bolt_flange",
           (0.0, 0.105, 0.668), (90, 0, 0), 0.004, hollow_r=0.064)
    kb.cyl("RearPortBore", 0.062, 0.062, 0.016, 14, "bore", "plain_metal",
           (0.0, 0.105, 0.660), (90, 0, 0), 0.002)
    kb.cyl("RearPortGlow", 0.054, 0.054, 0.014, 14, "emit_core", "plain_metal",
           (0.0, 0.105, 0.674), (90, 0, 0), 0.002)
    for gi, rz in enumerate([0.0, 90.0]):
        kb.box(f"RearPortBar_{gi}", (0.145, 0.014, 0.014), "gunmetal", "plain_metal",
               (0.0, 0.105, 0.692), (0, 0, rz), 0.002, 1)
    # Top rear hazard radiation strip
    kb.box("RearHazardStrip", (0.48, 0.032, 0.016), "hazard", "hazard", (0.0, 0.228, 0.658), (0, 0, 0), 0.002, 1)

    kb.add_marker("LIGHT_core", (0.0, 0.12, 0.72))


# ==============================================================================
# 2. gen_diesel — DS-6 Industrial V-Block Diesel Generator
# ==============================================================================

def build_gen_diesel(kb: KitbashScene):
    """DS-6 Diesel: industrial V-block armored diesel engine, twin upright-angled perforated mufflers (y <= 0.42!) with plain_metal bore tips, cylindrical air cleaner, radiator grille, fuel lines & brass fittings."""
    # 1. Unified HP-G1 Bulkhead Collar
    _hp_g1_mount(kb, "HP_G1", w=0.78, h=0.50, y_c=0.00)

    # 2. Industrial Cast-Iron V-Block Engine Sump + Twin Angled V-Cylinder Head Banks
    kb.box("CrankcaseBlock", (0.50, 0.24, 0.44), "dark", "frame_cnc", (0.0, -0.10, 0.30), (0, 0, 0), 0.014, 1)
    for ri, rz in enumerate([0.16, 0.25, 0.34, 0.43]):
        kb.box(f"BlockRib_{ri}", (0.525, 0.18, 0.022), "gunmetal", "armor_ribs", (0.0, -0.11, rz), (0, 0, 0), 0.004, 1)
    # Underslung heavy brushless alternator drum (bottom y = -0.175 - 0.078 = -0.253 >= -0.28!)
    kb.cyl("AlternatorDrum", 0.078, 0.078, 0.30, 14, "gunmetal", "armor_ribs",
           (0.0, -0.175, 0.33), (90, 0, 0), 0.005)
    kb.cyl("AlternatorCap", 0.084, 0.084, 0.026, 14, "dark", "gear_collar",
           (0.0, -0.175, 0.475), (90, 0, 0), 0.003)

    # Left & Right Sloped V-Block Cylinder Banks (rolled outward ±26 deg)
    for si, sx in enumerate([-1.0, 1.0]):
        M_bk = g2b_mat((sx * 0.185, 0.075, 0.295), (0.0, 0.0, -sx * 26.0))
        kb.box(f"VBankBlock_{si}", (0.21, 0.19, 0.40), "armor_dark", "armor_pocket",
               (0.0, 0.0, 0.0), (0, 0, 0), 0.011, 1, M_parent=M_bk)
        kb.box(f"VBankValveCover_{si}", (0.18, 0.062, 0.37), "armor", "armor_hatch",
               (0.0, 0.115, 0.0), (0, 0, 0), 0.009, 1, M_parent=M_bk)
        # 4 cooling ribs & head bolts along each valve cover
        for ci, cz in enumerate([-0.13, -0.045, 0.045, 0.13]):
            kb.box(f"ValveRib_{si}_{ci}", (0.16, 0.016, 0.024), "gunmetal", "plain_metal",
                   (0.0, 0.150, cz), (0, 0, 0), 0.003, 1, M_parent=M_bk)
            # Exhaust port stub emerging laterally from each cylinder bank
            kb.cyl(f"ExhStub_{si}_{ci}", 0.024, 0.024, 0.11, 8, "dark", "plain_metal",
                   (sx * 0.13, 0.01, cz), (0, 0, 90), 0.003, M_parent=M_bk)
        # Heavy longitudinal cast exhaust manifold log collecting the 4 cylinder stubs
        kb.cyl(f"ExhManifold_{si}", 0.036, 0.036, 0.36, 12, "dark", "plain_metal",
               (sx * 0.185, 0.01, 0.0), (90, 0, 0), 0.004, M_parent=M_bk)
    # Brass oil filler cap on left valve bank
    kb.cyl("OilFillerCap", 0.026, 0.028, 0.030, 10, "brass", "gear_collar", (-0.23, 0.22, 0.18), (0, 0, 26), 0.003)

    # 3. Central Valley Turbocharger + Cylindrical Air Cleaner Canister (top y <= 0.395!)
    kb.box("IntakeValley", (0.20, 0.12, 0.38), "gunmetal", "frame_cnc", (0.0, 0.12, 0.29), (0, 0, 0), 0.008, 1)
    kb.cyl("TurboScroll", 0.068, 0.068, 0.11, 14, "gunmetal", "gear_collar", (0.0, 0.21, 0.42), (0, 0, 90), 0.005)
    # Prominent Horizontal Cylindrical Donaldson-Style Air Cleaner Canister on upper deck (top y = 0.378 <= 0.42!)
    kb.cyl("AirCleanerDrum", 0.078, 0.078, 0.30, 18, "armor_sub", "armor_ribs",
           (0.0, 0.295, 0.24), (0, 0, 90), 0.007)
    kb.cyl("AirCleanerPre", 0.088, 0.088, 0.056, 18, "dark", "vent_mesh",
           (-0.145, 0.295, 0.24), (0, 0, 90), 0.004, u_rep=2.0)
    kb.cyl("AirCleanerEnd", 0.082, 0.072, 0.028, 16, "gunmetal", "bolt_flange",
           (0.155, 0.295, 0.24), (0, 0, 90), 0.003)
    for si, sx in enumerate([-0.08, 0.08]):
        kb.cyl(f"AirStrap_{si}", 0.084, 0.084, 0.022, 16, "dark", "plain_metal",
               (sx, 0.295, 0.24), (0, 0, 90), 0.002)
        kb.box(f"AirMount_{si}", (0.028, 0.075, 0.044), "gunmetal", "plain_metal",
               (sx, 0.215, 0.24), (0, 0, 0), 0.003, 1)
    kb.tube_path("AirIntakeDuct", [
        (0.0, 0.28, 0.29), (0.0, 0.26, 0.37), (0.0, 0.21, 0.42)
    ], 0.030, 10, "rubber", "dust_boot")

    # 4. Twin Upright-Angled Perforated Exhaust Mufflers (STRICTLY max_y <= 0.415!) with smooth plain_metal bore tips
    for si, sx in enumerate([-1.0, 1.0]):
        # Collector pipe routing from V-bank exhaust manifold outward to upright muffler base
        kb.tube_path(f"ExhCrossover_{si}", [
            (sx * 0.32, 0.04, 0.36), (sx * 0.39, 0.04, 0.36), (sx * 0.42, 0.09, 0.35)
        ], 0.032, 10, "dark", "plain_metal")
        # Upright-angled muffler assembly (center y=0.225, tilt 16 deg back, -8 deg out -> top y ~ 0.402 <= 0.42!)
        M_ex = g2b_mat((sx * 0.425, 0.215, 0.345), (16.0, 0.0, -sx * 8.0))
        # Inner heat-blued exhaust core pipe
        kb.cyl(f"MufflerCore_{si}", 0.042, 0.044, 0.32, 14, "dark", "plain_metal",
               (0.0, 0.0, 0.0), (0, 0, 0), 0.004, M_parent=M_ex)
        # Outer perforated heat-shield jacket (vent_mesh) + twin clamping collars + standoffs
        kb.cyl(f"MufflerShield_{si}", 0.062, 0.062, 0.22, 16, "gunmetal", "vent_mesh",
               (0.0, -0.015, 0.0), (0, 0, 0), 0.004, hollow_r=0.052, u_rep=2.0, M_parent=M_ex)
        for ci, cy in enumerate([-0.115, 0.088]):
            kb.cyl(f"MufflerClamp_{si}_{ci}", 0.066, 0.066, 0.022, 16, "dark", "gear_collar",
                   (0.0, cy, 0.0), (0, 0, 0), 0.003, M_parent=M_ex)
        # Structural anchor strap into cylinder bank so muffler stack is rock-solid
        kb.box(f"MufflerBrace_{si}", (0.14, 0.032, 0.042), "gunmetal", "bolt_flange",
               (-sx * 0.075, -0.075, 0.0), (0, 0, 0), 0.004, 1, M_parent=M_ex)
        # Smooth machined plain_metal open bore tip (local +Y = upward along muffler axis!)
        kb.barrel_bore(f"MufflerTip_{si}", 0.045, 0.034, (0.0, 0.155, 0.0), depth=0.052, rot_deg=(0, 0, 0), segs=14, M_parent=M_ex)

    # 5. Rear Armored Radiator Grille + Fan Guard Shroud + Top Hazard Strip
    kb.box("RadiatorFrame", (0.64, 0.46, 0.14), "armor", "armor_panel", (0.0, 0.01, 0.58), (0, 0, 0), 0.013, 1)
    kb.louver_bay("RadiatorGrille", 0.52, 0.34, 0.040, (0.0, 0.01, 0.662), (0, 180, 0), blades=6, mesh_style=False)
    # Circular fan shroud ring + central hub & 6 angled blades seated cleanly on rear grille face
    kb.cyl("FanShroudRing", 0.155, 0.165, 0.032, 20, "gunmetal", "gear_collar",
           (0.0, 0.01, 0.678), (90, 0, 0), 0.004, hollow_r=0.132, u_rep=2.0)
    kb.cyl("FanHub", 0.042, 0.046, 0.026, 12, "dark", "plain_metal", (0.0, 0.01, 0.678), (90, 0, 0), 0.003)
    for bi in range(6):
        ang = bi * 60.0
        M_bl = g2b_mat((0.0, 0.01, 0.676), (0.0, 0.0, ang))
        kb.box(f"FanBlade_{bi}", (0.024, 0.115, 0.008), "dark", "plain_metal",
               (0.0, 0.068, 0.0), (0, 22, 0), 0.002, 1, M_parent=M_bl)
    kb.box("RadHazardTop", (0.52, 0.030, 0.016), "hazard", "hazard", (0.0, 0.228, 0.654), (0, 0, 0), 0.002, 1)

    # 6. Dual Spin-On Diesel Fuel Filters + Brass Pressure Fittings & Braided Fuel Lines
    kb.box("FilterHead", (0.085, 0.044, 0.20), "gunmetal", "bolt_flange", (-0.31, -0.02, 0.39), (0, 0, 0), 0.005, 1)
    for fi, fz in enumerate([0.34, 0.44]):
        kb.cyl(f"FuelFilter_{fi}", 0.036, 0.036, 0.115, 12, "accent", "plain_metal",
               (-0.32, -0.095, fz), (0, 0, 0), 0.004)
        kb.cyl(f"FuelFilterRim_{fi}", 0.040, 0.040, 0.016, 12, "dark", "gear_collar",
               (-0.32, -0.042, fz), (0, 0, 0), 0.002)
    # Brass pressure gauge + hex union fittings mounted on rear face of FilterHead (completely clear of ExhManifold!)
    kb.cyl("OilPressGauge", 0.024, 0.026, 0.024, 12, "brass", "gear_collar", (-0.31, -0.02, 0.500), (90, 0, 0), 0.002)
    kb.cyl("OilPressGlass", 0.018, 0.018, 0.008, 12, "glass", "plain_metal", (-0.31, -0.02, 0.514), (90, 0, 0), 0.001)
    # Twin copper/braided diesel fuel feed & return lines
    kb.tube_path("FuelLineIn", [
        (-0.31, -0.02, 0.30), (-0.35, -0.06, 0.18), (-0.28, -0.08, 0.08)
    ], 0.014, 8, "copper", "plain_metal", add_clamps=True, clamp_mat="brass")
    kb.tube_path("FuelLineOut", [
        (-0.30, 0.00, 0.45), (-0.26, 0.10, 0.47), (-0.15, 0.14, 0.44)
    ], 0.013, 8, "gunmetal", "braid_hose")
    kb.tube_path("CoolantHoseR", [
        (0.28, -0.10, 0.08), (0.33, -0.14, 0.34), (0.28, -0.10, 0.54)
    ], 0.018, 8, "rubber", "braid_hose", add_clamps=True, clamp_mat="brass")


# ==============================================================================
# 3. gen_turbine — TB-5 Compact Armored Gas-Turbine Unit
# ==============================================================================

def build_gen_turbine(kb: KitbashScene):
    """TB-5 Turbine: compact armored gas-turbine housing, central dorsal intake shroud, large rear stepped jet exhaust nozzle with vent_mesh heat shield, underslung auxiliary alternator & braided fuel hoses."""
    # 1. Unified HP-G1 Bulkhead Collar + Reduction Gearbox Housing
    _hp_g1_mount(kb, "HP_G1", w=0.78, h=0.50, y_c=0.01)

    # Heavy cast accessory reduction gearbox stepped cleanly aft of HP_G1_boss & inboard of all 4 corner lock pins!
    kb.box("GearboxBody", (0.52, 0.38, 0.18), "dark", "frame_cnc", (0.0, 0.02, 0.190), (0, 0, 0), 0.016, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"GearboxCheek_{si}", crect_2d(0.18, 0.38, (0.04, 0.04, 0.04, 0.04)), 0.052, "armor", "armor_panel",
                 (sx * 0.278, 0.02, 0.215), (0, 90, 0), 0.009, 1)
        kb.grab_rail(f"TurbineGrab_{si}", 0.15, 0.036, (sx * 0.300, 0.08, 0.215), (0, -sx * 90.0, 0), 0.009)

    # 2. Compact Axial Gas-Turbine Core Casing + Multi-Bolt Flange Rings + Fuel Injector Ring
    # Tapered turbine casing (z in [0.24, 0.56], r_front=0.235 -> r_rear=0.205, center y=0.03)
    kb.cyl("TurbineCasing", 0.205, 0.238, 0.33, 24, "armor_sub", "armor_ribs",
           (0.0, 0.03, 0.40), (90, 0, 0), 0.008, u_rep=2.0)
    # 3 Split-flange bolted compressor/combustor rings
    for fi, (fz, fr) in enumerate([(0.29, 0.252), (0.41, 0.238), (0.53, 0.224)]):
        kb.cyl(f"TurbFlange_{fi}", fr, fr, 0.036, 24, "dark", "bolt_flange",
               (0.0, 0.03, fz), (90, 0, 0), 0.004, u_rep=2.0)
        kb.bolt_ring(f"TurbBolts_{fi}", fr - 0.015, 10, 0.009, (0.0, 0.03, fz + 0.020), (90, 0, 0))
    # Brass annular fuel-manifold ring + 6 radial combustor igniter bosses around turbine waist
    kb.cyl("FuelRing", 0.246, 0.246, 0.022, 24, "brass", "gear_collar",
           (0.0, 0.03, 0.455), (90, 0, 0), 0.003, hollow_r=0.214, u_rep=2.0)
    for ii in range(6):
        ang = math.tau * ii / 6.0 + 0.52
        ix = math.cos(ang) * 0.225
        iy = 0.03 + math.sin(ang) * 0.225
        if iy < -0.18 or iy > 0.24:
            continue
        kb.cyl(f"IgniterBoss_{ii}", 0.028, 0.032, 0.095, 10, "gunmetal", "plain_metal",
               (ix, iy, 0.455), (90, 0, 0), 0.003)
        kb.cyl(f"IgniterTip_{ii}", 0.016, 0.018, 0.034, 8, "copper", "plain_metal",
               (ix, iy, 0.506), (90, 0, 0), 0.002)

    # 3. Central Dorsal Armored Intake Shroud (strictly y <= 0.405 <= 0.42!)
    kb.plate("IntakeShroud", crect_2d(0.46, 0.145, (0.04, 0.04, 0.02, 0.02)), 0.34, "armor", "armor_pocket",
             (0.0, 0.295, 0.295), (0, 0, 0), 0.011, 1)
    # Forward-facing recessed FOD intake louver bay (seated proudly 5mm into front face z=0.125 -> 0 Z-fight!)
    kb.louver_bay("IntakeVaneBay", 0.36, 0.088, 0.034, (0.0, 0.295, 0.106), (0, 0, 0), blades=4, mesh_style=False)
    # Side intake bleed mesh grilles on shroud cheeks
    for si, sx in enumerate([-1.0, 1.0]):
        kb.box(f"IntakeSideVent_{si}", (0.018, 0.076, 0.22), "dark", "vent_mesh",
               (sx * 0.234, 0.295, 0.31), (0, 0, 0), 0.003, 1)
    kb.grab_rail("IntakeRoofGrab", 0.26, 0.030, (0.0, 0.366, 0.31), (90, 0, 0), 0.008)
    kb.box("IntakeAccent", (0.38, 0.024, 0.016), "accent", "plain_metal", (0.0, 0.352, 0.468), (0, 0, 0), 0.002, 1)

    # 4. Large Rear Stepped Jet Exhaust Nozzle + Perforated Heat Shield (vent_mesh)
    # Center (0, 0.03, 0.55..0.745), outer heat shield r=0.228, stepped nozzle tapers to r=0.172
    # Perforated cylindrical heat shield jacket anchored by 4 standoffs + front/rear clamping rings
    kb.cyl("NozzleHeatShield", 0.228, 0.232, 0.165, 22, "gunmetal", "vent_mesh",
           (0.0, 0.03, 0.620), (90, 0, 0), 0.004, hollow_r=0.212, u_rep=2.0)
    for ri, rz in enumerate([0.545, 0.695]):
        kb.cyl(f"ShieldClamp_{ri}", 0.236, 0.236, 0.022, 22, "dark", "gear_collar",
               (0.0, 0.03, rz), (90, 0, 0), 0.003, hollow_r=0.200, u_rep=2.0)
    for si in range(4):
        ang = math.tau * si / 4.0 + math.pi / 4.0
        kb.box(f"ShieldStandoff_{si}", (0.024, 0.042, 0.14), "dark", "plain_metal",
               (math.cos(ang) * 0.202, 0.03 + math.sin(ang) * 0.202, 0.61), (0, 0, math.degrees(ang) + 90.0), 0.003, 1)

    # Stepped convergent-divergent hollow jet exhaust nozzle (lathe along local +Y -> Godot +Z via (90, 0, 0))
    nozzle_prof = [
        (0.145, 0.00), (0.202, 0.00), (0.202, 0.055),
        (0.192, 0.062), (0.192, 0.125),
        (0.176, 0.134), (0.166, 0.195),
        (0.142, 0.195), (0.136, 0.188),
        (0.148, 0.045), (0.145, 0.00),
    ]
    kb.lathe("JetExhaustNozzle", nozzle_prof, 24, "gunmetal", "plain_metal",
             (0.0, 0.03, 0.545), (90, 0, 0), u_rep=2.0)
    # 10 Variable-area stepped nozzle feather petals around rear exit cone
    for pi in range(10):
        ang = math.tau * pi / 10.0
        px = math.cos(ang) * 0.178
        py = 0.03 + math.sin(ang) * 0.178
        M_pt = g2b_mat((px, py, 0.695), (0.0, 0.0, math.degrees(ang) + 90.0))
        kb.box(f"NozzlePetal_{pi}", (0.068, 0.016, 0.088), "dark", "armor_ribs",
               (0.0, 0.0, 0.0), (-9, 0, 0), 0.003, 1, M_parent=M_pt)
    # Deep pitch-black internal turbine exhaust cone + flameholder ring inside the nozzle
    kb.cyl("NozzleBoreBack", 0.144, 0.144, 0.032, 16, "bore", "plain_metal",
           (0.0, 0.03, 0.575), (90, 0, 0), 0.002)
    kb.lathe("TurbineTailCone", [
        (0.0, 0.0), (0.068, 0.0), (0.052, 0.055), (0.018, 0.105), (0.0, 0.115)
    ], 14, "dark", "plain_metal", (0.0, 0.03, 0.585), (90, 0, 0))
    kb.cyl("FlameholderRing", 0.112, 0.112, 0.016, 16, "copper", "gear_collar",
           (0.0, 0.03, 0.620), (90, 0, 0), 0.002, hollow_r=0.092)
    # 4 Radial afterburner spray-bar struts physically anchoring FlameholderRing to tail cone & nozzle wall!
    for si in range(4):
        ang = math.tau * si / 4.0
        kb.box(f"FlameStrut_{si}", (0.118, 0.014, 0.016), "gunmetal", "plain_metal",
               (math.cos(ang) * 0.095, 0.03 + math.sin(ang) * 0.095, 0.620),
               (0, 0, math.degrees(ang)), 0.002, 1)
    # Top rear jet-blast hazard plate
    kb.box("JetBlastHazard", (0.22, 0.022, 0.036), "hazard", "hazard", (0.0, 0.262, 0.620), (0, 0, 0), 0.002, 1)

    # 5. Underslung Auxiliary Alternator + Fuel Governor Control Box + Braided Fuel Hoses
    # Bottom check: y = -0.185, r = 0.078 -> min_y = -0.263 >= -0.28!
    kb.cyl("AuxAlternator", 0.078, 0.078, 0.30, 16, "dark", "armor_ribs",
           (0.0, -0.185, 0.34), (90, 0, 0), 0.005)
    kb.cyl("AuxAltRearCap", 0.084, 0.074, 0.032, 16, "gunmetal", "vent_mesh",
           (0.0, -0.185, 0.495), (90, 0, 0), 0.003)
    for si, sz in enumerate([0.26, 0.42]):
        kb.box(f"AuxAltStrut_{si}", (0.14, 0.095, 0.038), "gunmetal", "bolt_flange",
               (0.0, -0.135, sz), (0, 0, 0), 0.004, 1)

    # Right-flank fuel metering governor box + brass regulator valve
    kb.box("FuelGovBox", (0.11, 0.14, 0.19), "armor_sub", "armor_hatch", (0.285, -0.09, 0.34), (0, 0, 0), 0.008, 1)
    kb.cyl("FuelGovValve", 0.026, 0.028, 0.042, 10, "brass", "gear_collar", (0.345, -0.06, 0.34), (0, 0, 90), 0.003)

    # Braided fuel & lube hoses connecting gearbox, alternator, governor, and fuel ring
    kb.tube_path("BraidedFuel_R", [
        (0.285, -0.02, 0.36), (0.33, 0.04, 0.42), (0.23, 0.04, 0.455)
    ], 0.015, 8, "copper", "braid_hose", add_clamps=True, clamp_mat="brass")
    kb.tube_path("BraidedLube_R", [
        (0.07, -0.185, 0.30), (0.22, -0.17, 0.22), (0.24, -0.10, 0.14)
    ], 0.017, 8, "gunmetal", "braid_hose", add_clamps=True, clamp_mat="gunmetal")
    kb.tube_path("BraidedFuel_L", [
        (-0.24, -0.12, 0.14), (-0.31, -0.08, 0.32), (-0.23, 0.03, 0.455)
    ], 0.016, 8, "gunmetal", "braid_hose", add_clamps=True, clamp_mat="brass")


# ==============================================================================
# 4. gen_crystal — CR-8 Prototype Abyssal Crystal Reactor
# ==============================================================================

def build_gen_crystal(kb: KitbashScene):
    """CR-8 Crystal Reactor: heavy hex/octagonal containment cage frame, faceted abyssal emit_core crystal clamped top & bottom (0 floating!), 3 magnetically clamped copper suppression coils + LIGHT_core."""
    # 1. Unified HP-G1 Bulkhead Collar + Forward Structural Neck Truss
    _hp_g1_mount(kb, "HP_G1", w=0.76, h=0.50, y_c=0.04)

    zc = 0.38
    yc = 0.06
    # Forward connecting bulkhead spine bridging HP-G1 plate cleanly to upper & lower octagonal caps
    for si, sy in enumerate([-0.195, 0.315]):
        kb.box(f"CageNeck_{si}", (0.48, 0.064, 0.14), "dark", "frame_cnc",
               (0.0, sy, 0.13), (0, 0, 0), 0.008, 1)

    # 2. Heavy Octagonal Armored Containment Cage End Caps (y in [-0.255, +0.375], z in [0.11, 0.65])
    oct_xy = crect_2d(0.60, 0.54, (0.14, 0.14, 0.14, 0.14))
    for si, sy in enumerate([-0.215, 0.335]):
        sgn = -1.0 if si == 0 else 1.0
        kb.plate(f"OctCap_{si}", oct_xy, 0.068, "armor", "armor_panel",
                 (0.0, sy, zc), (90, 0, 0), 0.011, 1)
        # Inner stepped octagonal emitter flange plate + 8 hex perimeter bolts
        kb.cyl(f"OctFlange_{si}", 0.225, 0.238, 0.042, 8, "gunmetal", "bolt_flange",
               (0.0, sy - sgn * 0.044, zc), (0, 22.5, 0), 0.005)
        kb.bolt_ring(f"OctBolts_{si}", 0.205, 8, 0.009, (0.0, sy + sgn * 0.038, zc), (0, 0, 0))
    # Top-rear HAZMAT warning badge & amber interlock bar (strictly y <= 0.385!)
    kb.box("HazmatHazard", (0.30, 0.036, 0.018), "hazard", "hazard", (0.0, 0.335, 0.658), (0, 0, 0), 0.003, 1)
    kb.box("InterlockAccent", (0.28, 0.032, 0.018), "accent", "plain_metal", (0.0, -0.215, 0.658), (0, 0, 0), 0.003, 1)

    # Left & Right Armored Containment Cheek Shields + Vertical Side Grab Rails
    for si, sx in enumerate([-1.0, 1.0]):
        kb.plate(f"SideBlastShield_{si}", crect_2d(0.28, 0.48, (0.05, 0.05, 0.05, 0.05)), 0.046, "armor_sub", "armor_pocket",
                 (sx * 0.325, yc, 0.24), (0, 90, 0), 0.009, 1)
        kb.grab_rail(f"CageGrab_{si}", 0.22, 0.038, (sx * 0.346, yc, 0.24), (0, -sx * 90.0, 90), 0.009)

    # 3. 6 Hexagonal Containment Cage Columns / Hydraulic Damper Struts (r = 0.252 around (0, yc, zc))
    hex_r = 0.252
    for hi in range(6):
        ang = math.tau * hi / 6.0 + math.pi / 6.0
        hx = math.cos(ang) * hex_r
        hz = zc + math.sin(ang) * hex_r
        # Outer forged cage stanchion column + chrome damper sleeve + twin brass collars
        kb.cyl(f"CageCol_{hi}", 0.025, 0.025, 0.51, 10, "dark", "frame_cnc",
               (hx, yc, hz), (0, 0, 0), 0.004)
        kb.cyl(f"CageRod_{hi}", 0.016, 0.016, 0.53, 8, "chrome", "plain_metal",
               (hx, yc, hz), (0, 0, 0), 0.002)
        for ci, cy in enumerate([yc - 0.175, yc + 0.175]):
            kb.cyl(f"CageCollar_{hi}_{ci}", 0.034, 0.034, 0.034, 10, "brass", "gear_collar",
                   (hx, cy, hz), (0, 0, 0), 0.003)

    # 4. 3 Stacked Magnetic Suppression Copper Coils (physically clamped to all 6 hex columns -> 0 floating!)
    coil_ys = [yc - 0.115, yc, yc + 0.115]
    for ci, cy in enumerate(coil_ys):
        kb.cyl(f"SuppCoil_{ci}", 0.222, 0.222, 0.032, 24, "copper", "gear_collar",
               (0.0, cy, zc), (0, 0, 0), 0.004, hollow_r=0.184, u_rep=3.0)
        # 6 radial insulator clamp brackets bridging each coil cleanly into the 6 hex columns!
        for hi in range(6):
            ang = math.tau * hi / 6.0 + math.pi / 6.0
            bx = math.cos(ang) * 0.232
            bz = zc + math.sin(ang) * 0.232
            kb.box(f"CoilMount_{ci}_{hi}", (0.056, 0.040, 0.034), "gunmetal", "bolt_flange",
                   (bx, cy, bz), (0, -math.degrees(ang), 0), 0.003, 1)

    # 5. Top & Bottom Physical Electrode Clamps + Faceted Abyssal Crystal Core (ZERO FLOATING & ZERO BURIED!)
    for si, sgn in enumerate([-1.0, 1.0]):
        cy_base = yc + sgn * 0.205
        # Central tapered electrode chuck seated firmly into octagonal end-cap flange
        kb.cyl(f"CrystalChuck_{si}", 0.044 if sgn > 0 else 0.068, 0.068 if sgn > 0 else 0.044,
               0.072, 12, "dark", "gear_collar", (0.0, cy_base, zc), (0, 0, 0), 0.004)
        kb.cyl(f"CrystalBrassRing_{si}", 0.060, 0.060, 0.022, 12, "brass", "plain_metal",
               (0.0, yc + sgn * 0.192, zc), (0, 0, 0), 0.002)
        # 3 angled mechanical gripping prongs physically hugging the faceted crystal core!
        for pi in range(3):
            ang = math.tau * pi / 3.0 + (0.0 if sgn > 0 else math.pi / 3.0)
            px = math.cos(ang) * 0.062
            pz = zc + math.sin(ang) * 0.062
            M_pr = g2b_mat((px, yc + sgn * 0.160, pz), (0.0, -math.degrees(ang), 0.0))
            kb.box(f"CrystalProng_{si}_{pi}", (0.022, 0.088, 0.024), "gunmetal", "plain_metal",
                   (0.0, 0.0, 0.0), (0, 0, sgn * 24.0), 0.003, 1, M_parent=M_pr)

    # Main central doubly-terminated 6-sided faceted abyssal crystal core (y in [yc - 0.180, yc + 0.180])
    # Tips seat cleanly ~7mm into top/bottom chucks (well below 14mm burial threshold & <15% verts -> 0 buried, 0 floating!)
    crystal_prof = [
        (0.0, -0.180), (0.036, -0.145), (0.082, -0.062),
        (0.102, 0.008), (0.078, 0.080), (0.036, 0.148), (0.0, 0.180)
    ]
    kb.lathe("AbyssalCrystalCore", crystal_prof, 6, "emit_core", "plain_metal",
             (0.0, yc, zc), (0, 18, 0))
    # Two secondary angled faceted crystal offshoots budding cleanly from outer facet walls (<10mm seat -> 0 buried, 0 floating!)
    shard_prof = [
        (0.0, 0.0), (0.028, 0.010), (0.036, 0.044), (0.018, 0.084), (0.0, 0.102)
    ]
    kb.lathe("CrystalShard_L", shard_prof, 6, "emit_core", "plain_metal",
             (-0.078, yc - 0.012, zc + 0.022), (16, 15, 42))
    kb.lathe("CrystalShard_R", shard_prof, 6, "emit_core", "plain_metal",
             (0.076, yc - 0.024, zc - 0.024), (-14, -20, -40))

    # 6. HV Energy Extraction Bus Cables & Rear Stabilizer Bar
    for si, sx in enumerate([-1.0, 1.0]):
        kb.tube_path(f"CrystalBusBot_{si}", [
            (sx * 0.21, yc - 0.115, zc - 0.10), (sx * 0.29, yc - 0.16, 0.19), (sx * 0.25, yc - 0.14, 0.08)
        ], 0.018, 8, "copper", "braid_hose", add_clamps=True, clamp_mat="brass")
        kb.tube_path(f"CrystalBusTop_{si}", [
            (sx * 0.21, yc + 0.115, zc - 0.10), (sx * 0.28, yc + 0.16, 0.19), (sx * 0.24, yc + 0.14, 0.08)
        ], 0.015, 8, "gunmetal", "braid_hose", add_clamps=True, clamp_mat="gunmetal")

    kb.add_marker("LIGHT_core", (0.0, yc, 0.68))


# ==============================================================================
# 5. gen_hfc — HFC-3 Twin-Tank Hydrogen Fuel-Cell Stack
# ==============================================================================

def build_gen_hfc(kb: KitbashScene):
    """HFC-3 Hydrogen Fuel Cell: twin horizontal high-pressure cylindrical H2 tanks with dark clamp bands & brass pressure valves, stacked fuel-cell plate array with tie-rods & end plates, coolant piping & recessed amber/cyan status LEDs."""
    # 1. Unified HP-G1 Bulkhead Collar + Side Protective Cheek Plates & Frame Spine
    _hp_g1_mount(kb, "HP_G1", w=0.78, h=0.50, y_c=0.02)

    kb.box("FrameSpine", (0.68, 0.46, 0.056), "dark", "frame_cnc", (0.0, 0.02, 0.10), (0, 0, 0), 0.008, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        # Protective side armor ear plates bridging front bulkhead cleanly to fuel-cell front compression plate
        kb.plate(f"SideGuard_{si}", crect_2d(0.32, 0.48, (0.05, 0.06, 0.06, 0.05)), 0.044, "armor_sub", "armor_panel",
                 (sx * 0.365, 0.02, 0.24), (0, 90, 0), 0.008, 1)
        kb.grab_rail(f"HFCGrab_{si}", 0.20, 0.036, (sx * 0.386, 0.02, 0.24), (0, -sx * 90.0, 90), 0.009)

    # 2. Twin Horizontal High-Pressure 700-Bar Cylindrical Hydrogen Tanks (y = -0.105 and y = +0.155, z = 0.215)
    # Check bounds: y in [-0.217, +0.267], x in [-0.41, +0.43] (with valves)
    tank_ys = [-0.105, 0.155]
    dome_prof = [
        (0.0, 0.0), (0.108, 0.0), (0.104, 0.022), (0.088, 0.044),
        (0.058, 0.060), (0.028, 0.068), (0.0, 0.070)
    ]
    for ti, ty in enumerate(tank_ys):
        # Main carbon-fiber wrapped horizontal H2 pressure cylinder (axis along X)
        kb.cyl(f"H2Tank_{ti}", 0.110, 0.110, 0.40, 20, "armor_dark", "braid_hose",
               (0.0, ty, 0.215), (0, 0, 90), 0.006, u_rep=2.0)
        # Left & right domed aluminum boss end-caps
        kb.lathe(f"H2DomeL_{ti}", dome_prof, 18, "armor_sub", "plain_metal",
                 (-0.196, ty, 0.215), (0, 0, 90))
        kb.lathe(f"H2DomeR_{ti}", dome_prof, 18, "armor_sub", "plain_metal",
                 (0.196, ty, 0.215), (0, 0, -90))
        # Twin dark clamp bands + rigid saddle brackets anchoring each tank to FrameSpine & FrontEndPlate
        for ci, cx in enumerate([-0.135, 0.135]):
            kb.cyl(f"TankBand_{ti}_{ci}", 0.118, 0.118, 0.036, 20, "dark", "bolt_flange",
                   (cx, ty, 0.215), (0, 0, 90), 0.003)
            kb.box(f"TankSaddle_{ti}_{ci}", (0.046, 0.056, 0.155), "gunmetal", "frame_cnc",
                   (cx, ty, 0.145), (0, 0, 0), 0.005, 1)
        # Right-end heavy brass pressure shutoff valve assembly + Bourdon pressure gauge
        kb.cyl(f"BrassValve_{ti}", 0.028, 0.032, 0.078, 10, "brass", "gear_collar",
               (0.295, ty, 0.215), (0, 0, 90), 0.003)
        kb.cyl(f"ValveWheel_{ti}", 0.024, 0.024, 0.014, 10, "accent", "gear_collar",
               (0.305, ty + 0.036, 0.215), (0, 0, 0), 0.002)
        kb.cyl(f"PressGauge_{ti}", 0.024, 0.026, 0.020, 12, "chrome", "plain_metal",
               (0.305, ty, 0.256), (90, 0, 0), 0.002)
        kb.cyl(f"PressFace_{ti}", 0.018, 0.018, 0.008, 12, "glass", "plain_metal",
               (0.305, ty, 0.268), (90, 0, 0), 0.001)
        # Left-end brass pressure-relief rupture boss
        kb.cyl(f"ReliefBoss_{ti}", 0.022, 0.026, 0.052, 8, "brass", "plain_metal",
               (-0.282, ty, 0.215), (0, 0, 90), 0.002)
        # Stainless H2 feed manifold pipe from right brass valve into fuel-cell stack front plate
        kb.tube_path(f"H2FeedPipe_{ti}", [
            (0.325, ty, 0.215), (0.375, ty * 0.85, 0.30), (0.25, ty * 0.72, 0.38)
        ], 0.014, 8, "chrome", "plain_metal", add_clamps=True, clamp_mat="brass")

    # 3. Stacked Proton-Exchange Fuel-Cell Plate Array + Compression End Plates + 6 Chrome Tie-Rods
    # Stack sits z in [0.355, 0.680], y in [-0.205, +0.245], x in [-0.285, +0.285]
    # Rigid lower & upper bridge rails anchoring stack front end plate to SideGuard & FrameSpine
    for si, sx in enumerate([-0.305, 0.305]):
        kb.box(f"StackAnchor_{si}", (0.11, 0.36, 0.085), "dark", "frame_cnc",
               (sx, 0.02, 0.365), (0, 0, 0), 0.007, 1)
    # Heavy beveled front & rear armored compression end plates
    kb.box("StackEndFront", (0.56, 0.44, 0.048), "armor", "armor_panel", (0.0, 0.02, 0.382), (0, 0, 0), 0.010, 1)
    kb.box("StackEndRear", (0.56, 0.44, 0.048), "armor", "armor_panel", (0.0, 0.02, 0.654), (0, 0, 0), 0.010, 1)

    # 11 Alternating Bipolar Fuel-Cell Plates (overlapped 2mm sequentially so continuous rigid stack, 0 floating!)
    # z spans 0.410..0.626 in 0.0216m steps (11 plates + 10 spacer membranes)
    for pi in range(11):
        pz = 0.410 + pi * 0.0216
        kb.box(f"CellPlate_{pi}", (0.48, 0.37, 0.013), "gunmetal", "plain_metal",
               (0.0, 0.02, pz), (0, 0, 0), 0.002, 1)
        if pi < 10:
            kb.box(f"CellMembrane_{pi}", (0.45, 0.34, 0.014), "dark", "armor_ribs",
                   (0.0, 0.02, pz + 0.0108), (0, 0, 0), 0.002, 1)
    # Bridge first & last plate cleanly into front & rear compression end plates
    kb.box("StackCoreFront", (0.44, 0.33, 0.024), "dark", "plain_metal", (0.0, 0.02, 0.398), (0, 0, 0), 0.002, 1)
    kb.box("StackCoreRear", (0.44, 0.33, 0.024), "dark", "plain_metal", (0.0, 0.02, 0.638), (0, 0, 0), 0.002, 1)

    # 6 High-Tensile Chrome Tie-Rods + Brass Spring Washers + Hex Tension Nuts
    for xi, rx in enumerate([-0.242, 0.242]):
        for yi, ry in enumerate([-0.165, 0.02, 0.205]):
            kb.cyl(f"TieRod_{xi}_{yi}", 0.012, 0.012, 0.335, 8, "chrome", "plain_metal",
                   (rx, ry, 0.522), (90, 0, 0), 0.002)
            kb.cyl(f"TieWasher_{xi}_{yi}", 0.022, 0.022, 0.010, 10, "brass", "plain_metal",
                   (rx, ry, 0.682), (90, 0, 0), 0.002)
            kb.cyl(f"TieNut_{xi}_{yi}", 0.020, 0.021, 0.018, 6, "gunmetal", "plain_metal",
                   (rx, ry, 0.694), (90, 0, 0), 0.002)

    # Top Solid Copper Current-Collector Busbar + Stepped Accent Protective Hood (top y = 0.305 <= 0.42!)
    kb.box("CopperCollector", (0.34, 0.026, 0.25), "copper", "plain_metal", (0.0, 0.248, 0.518), (0, 0, 0), 0.004, 1)
    kb.box("CollectorHood", (0.42, 0.036, 0.28), "accent", "armor_ribs", (0.0, 0.280, 0.518), (0, 0, 0), 0.006, 1)
    kb.box("RearHazardTag", (0.38, 0.030, 0.016), "hazard", "hazard", (0.0, 0.215, 0.682), (0, 0, 0), 0.002, 1)

    # 4. Coolant Piping, Rear Vapor Condenser Drain Nozzle & Recessed Amber/Cyan Status LEDs
    for si, sx in enumerate([-1.0, 1.0]):
        kb.tube_path(f"CoolantLoop_{si}", [
            (sx * 0.22, -0.16, 0.65), (sx * 0.31, -0.225, 0.42), (sx * 0.29, -0.19, 0.09)
        ], 0.018, 8, "copper" if si == 0 else "gunmetal", "braid_hose", add_clamps=True, clamp_mat="gunmetal")

    # Rear vapor condenser exhaust nozzle (lower left of rear compression plate)
    kb.cyl("CondenserPipe", 0.042, 0.045, 0.046, 14, "gunmetal", "gear_collar",
           (-0.14, -0.095, 0.692), (90, 0, 0), 0.004)
    kb.barrel_bore("CondenserNozzle", 0.038, 0.027, (-0.14, -0.095, 0.718), depth=0.040, rot_deg=(90, 0, 0), segs=12)

    # Rear Armored Diagnostic Status Panel + Recessed Amber & Cyan Status LEDs (proud of bore floor, 0 burial!)
    kb.box("DiagBezel", (0.19, 0.115, 0.032), "dark", "frame_cnc", (0.11, 0.045, 0.686), (0, 0, 0), 0.005, 1)
    kb.box("DiagBore", (0.145, 0.072, 0.014), "bore", "plain_metal", (0.11, 0.045, 0.700), (0, 0, 0), 0.002, 1)
    # 3 Recessed Cyan active-stack LED segments + 2 Recessed Amber H2-pressure LED segments
    for li in range(3):
        kb.box(f"LedCyan_{li}", (0.024, 0.018, 0.010), "emit_cyan", "plain_metal",
               (0.068 + li * 0.038, 0.062, 0.708), (0, 0, 0), 0.002, 1)
    for li in range(2):
        kb.box(f"LedAmber_{li}", (0.044, 0.016, 0.010), "emit_amber", "plain_metal",
               (0.080 + li * 0.056, 0.028, 0.708), (0, 0, 0), 0.002, 1)
    # Small lower louvered purge vent on rear compression plate
    kb.louver_bay("RearPurgeVent", 0.14, 0.085, 0.028, (0.11, -0.095, 0.688), (0, 180, 0), blades=3, mesh_style=True)
