"""
Extended 10 High-Precision Mech Generator Powerplant Pack — B.o.T Hard-Surface Military Standard.
Covers all 10 remaining HP-G1 rear powerplant modules (strictly y in [-0.28, +0.42] backpack-safe clearance!):
  1. gen_agt1500_turbine  (AGT-1500 Recuperated Gas Turbine w/ Swirl Filter, Twin-Spool Case & IR Louvers)
  2. gen_homopolar_pulse  (HPG-90 64MJ Homopolar Pulse Capacitor Bank w/ 3x2 HV Cans & Copper Busbars)
  3. gen_hydrothermal_hx  (HTX-12 Supercritical Titanium Shell-and-Tube Heat Exchanger & Twin Expanders)
  4. gen_lfr_lead_bismuth (SVBR-10 Lead-Bismuth Fast Reactor w/ Octagonal Shield, Copper Trace & MHD Pumps)
  5. gen_mhd_plasma_gen   (MHD-40 Supersonic Magnetohydrodynamic Channel w/ Saddle Copper Coils)
  6. gen_mtu_mb873_v12    (MB-873 Twin-Turbo 90-deg V12 Heavy Diesel Pack w/ Top Dual Ring Fans)
  8. gen_pem_fuelcell     (PEM-600 Silent Proton-Exchange Fuel-Cell Stack w/ Tie-Rods & 4 Hydride Tanks)
 10. gen_twin_apu_gtcp    (GTCP-85 Airborne Dual-Redundant Centrifugal Micro-Turbine APU Pack)
"""
import math
from kitbash_lib import KitbashScene, g2b_mat, crect_2d, trap_2d


def _hp_g1(kb: KitbashScene, prefix: str = "HP_G1", w: float = 0.78, h: float = 0.50, y_c: float = 0.01):
    kb.plate(f"{prefix}_pl", crect_2d(w, h, (0.08, 0.08, 0.08, 0.08)), 0.086, "dark", "bolt_flange", (0.0, y_c, 0.047), (0, 0, 0), 0.010, 1)
    kb.box(f"{prefix}_bs", (w - 0.14, h - 0.12, 0.036), "gunmetal", "frame_cnc", (0.0, y_c, 0.096), (0, 0, 0), 0.006, 1)
    hx, hy = w * 0.5 - 0.085, h * 0.5 - 0.075
    for ci, (cx, cy) in enumerate([(-hx, -hy), (hx, -hy), (-hx, hy), (hx, hy)]):
        kb.cyl(f"{prefix}_pn{ci}", 0.026, 0.028, 0.048, 10, "chrome", "plain_metal", (cx, y_c + cy, 0.108), (90, 0, 0), 0.003)
        kb.cyl(f"{prefix}_rg{ci}", 0.038, 0.038, 0.018, 12, "accent", "gear_collar", (cx, y_c + cy, 0.128), (90, 0, 0), 0.002)


# 1. gen_agt1500_turbine — AGT-1500 Recuperated Gas Turbine Powerpack
def build_gen_agt1500_turbine(kb: KitbashScene):
    _hp_g1(kb, "G1")
    # Twin-spool compressor armored housing + top swirl dust-separator intake plenum
    kb.plate("TurbineCasing", crect_2d(0.84, 0.44, (0.08, 0.08, 0.06, 0.06)), 0.34, "armor", "armor_slab", (0, -0.02, 0.26), (0, 0, 0), 0.020, 1)
    kb.box("SwirlIntakeBox", (0.68, 0.12, 0.28), "armor_oxide", "weld_plate", (0, 0.26, 0.24), (0, 0, 0), 0.012, 1)
    kb.louver_bay("TopIntakeMesh", 0.54, 0.20, 0.032, (0, 0.325, 0.24), (-90, 0, 0), blades=5, mesh_style=True)
    # Rear cylindrical plate recuperator drum + anti-IR upward exhaust louver bay
    kb.cyl("RecuperatorDrum", 0.22, 0.22, 0.58, 20, "gunmetal", "armor_ribs", (0, -0.02, 0.50), (0, 0, 90), 0.008, u_rep=2.0)
    kb.bolt_ring("RecupBoltsL", 0.17, 8, 0.010, (-0.292, -0.02, 0.50), (0, 0, 90))
    kb.bolt_ring("RecupBoltsR", 0.17, 8, 0.010, ( 0.292, -0.02, 0.50), (0, 0, -90))
    kb.louver_bay("IRExhaust", 0.52, 0.22, 0.048, (0, 0.02, 0.72), (-16, 180, 0), blades=6, mesh_style=False)
    kb.decal("AGTUnit", "unit_17", (0.18, 0.10), (0.0, 0.26, 0.386), (0, 180, 0))
    kb.decal("AGTSoot", "soot_ring", (0.22, 0.20), (0, 0.02, 0.750), (-16, 180, 0))
    for si, sx in enumerate([-1.0, 1.0]):
        kb.tube_path(f"FuelFeed_{si}", [(sx * 0.34, 0.14, 0.10), (sx * 0.44, 0.08, 0.32), (sx * 0.32, -0.02, 0.50)], 0.020, 8, "copper", "plain_metal", add_clamps=True)
        kb.grab_rail(f"AGTGrab_{si}", 0.22, 0.038, (sx * 0.44, -0.02, 0.26), (0, -sx * 90.0, 0), 0.009)
    kb.box("RearHaz", (0.50, 0.040, 0.018), "hazard", "hazard", (0, -0.22, 0.70), (0, 0, 0), 0.003, 1)
    kb.add_marker("LIGHT_core", (0.0, 0.02, 0.76))


# 2. gen_homopolar_pulse — HPG-90 64MJ Homopolar Pulse Capacitor Station
def build_gen_homopolar_pulse(kb: KitbashScene):
    _hp_g1(kb, "G1")
    # Faraday shielded cabinet + 3x2 HV film capacitor cans + laminated copper busbars + ceramic bushings
    kb.plate("FaradayFrame", crect_2d(0.88, 0.48, (0.07, 0.07, 0.06, 0.06)), 0.44, "armor_sub", "frame_cnc", (0, 0.02, 0.31), (0, 0, 0), 0.018, 1)
    kb.plate("TopShieldCowl", crect_2d(0.78, 0.38, (0.05, 0.05, 0.04, 0.04)), 0.06, "armor", "armor_slab", (0, 0.28, 0.31), (90, 0, 0), 0.012, 1)
    for ix, cx in enumerate([-0.24, 0.0, 0.24]):
        for iy, cy in enumerate([-0.10, 0.12]):
            kb.box(f"CapCan_{ix}_{iy}", (0.19, 0.17, 0.22), "armor_dark", "armor_pocket", (cx, cy, 0.54), (0, 0, 0), 0.010, 1)
            for bi, bx in enumerate([-0.045, 0.045]):
                kb.cyl(f"Bushing_{ix}_{iy}_{bi}", 0.020, 0.024, 0.055, 10, "copper" if bi == 0 else "brass", "gear_collar", (cx + bx, cy, 0.665), (90, 0, 0), 0.003)
    # Transverse heavy laminated copper busbars + glowing pulse discharge indicator
    for by_i, by in enumerate([-0.10, 0.12]):
        kb.box(f"CopperBus_{by_i}", (0.66, 0.032, 0.026), "copper", "plain_metal", (0, by + 0.04, 0.685), (0, 0, 0), 0.003, 1)
    kb.glow_radiator_arc("PulseArc", (0, 0.26, 0.54), (0, 180, 0), r_outer=0.14, r_inner=0.06, depth=0.05, arc_deg=160.0, blades=8, emit_slot="emit_cyan")
    kb.decal("HPGWarn", "caution_chev", (0.24, 0.10), (0, -0.22, 0.535), (0, 180, 0))
    for si, sx in enumerate([-0.45, 0.45]):
        kb.louver_bay(f"SideCool_{si}", 0.28, 0.18, 0.034, (sx, 0.02, 0.32), (0, -math.copysign(90.0, sx), 0), blades=4, mesh_style=True)
    kb.add_marker("LIGHT_core", (0.0, 0.26, 0.62))


# 3. gen_hydrothermal_hx — HTX-12 Supercritical Titanium Shell-and-Tube HX
def build_gen_hydrothermal_hx(kb: KitbashScene):
    _hp_g1(kb, "G1")
    kb.plate("HXCradle", crect_2d(0.84, 0.46, (0.08, 0.08, 0.08, 0.08)), 0.24, "armor_sub", "weld_plate", (0, 0.02, 0.21), (0, 0, 0), 0.016, 1)
    # Upper & lower stacked titanium shell-and-tube pressure barrels + 10-bolt forged blind flanges
    for ti, ty in enumerate([0.14, -0.11]):
        kb.cyl(f"TiShell_{ti}", 0.125, 0.125, 0.64, 20, "gunmetal" if ti == 0 else "armor", "armor_panel", (0, ty, 0.42), (0, 0, 90), 0.008, u_rep=2.0)
        for ei, sx in enumerate([-0.33, 0.33]):
            kb.cyl(f"BlindFlg_{ti}_{ei}", 0.148, 0.148, 0.042, 20, "dark", "bolt_flange", (sx, ty, 0.42), (0, 0, 90), 0.005)
            kb.bolt_ring(f"HXBolts_{ti}_{ei}", 0.115, 10, 0.009, (sx + math.copysign(0.024, sx), ty, 0.42), (0, 0, -math.copysign(90.0, sx)))
    # 4 copper cross-over manifolds + twin turbo-expanders + thermal core sight
    for mi, mx in enumerate([-0.22, -0.08, 0.08, 0.22]):
        kb.cyl(f"CrossPipe_{mi}", 0.022, 0.022, 0.26, 10, "copper", "plain_metal", (mx, 0.015, 0.56), (0, 0, 0), 0.002)
    for si, sx in enumerate([-0.24, 0.24]):
        kb.cyl(f"TurboExp_{si}", 0.085, 0.095, 0.16, 16, "brass", "gear_collar", (sx, 0.29, 0.34), (90, 0, 0), 0.005)
    kb.cyl("SightGlass", 0.048, 0.048, 0.22, 14, "emit_amber", "plain_metal", (0, 0.29, 0.42), (0, 0, 90), 0.003)
    kb.decal("HTXTri", "hazard_tri", (0.14, 0.14), (0, 0.14, 0.548), (0, 180, 0))
    kb.add_marker("LIGHT_core", (0.0, 0.29, 0.52))


# 4. gen_lfr_lead_bismuth — SVBR-10 Lead-Bismuth Liquid-Metal Fast Reactor
def build_gen_lfr_lead_bismuth(kb: KitbashScene):
    _hp_g1(kb, "G1")
    # Octagonal biological radiation carapace + lead-bismuth core drum + 3 copper trace-heating bands + twin MHD pumps
    kb.plate("OctBioShield", crect_2d(0.86, 0.52, (0.16, 0.16, 0.14, 0.14)), 0.36, "armor", "armor_slab", (0, 0.03, 0.28), (0, 0, 0), 0.022, 1)
    kb.cyl("LFRCoreDrum", 0.22, 0.24, 0.32, 20, "armor_oxide", "weld_plate", (0, 0.03, 0.52), (90, 0, 0), 0.010)
    kb.bolt_ring("LFRRearBolts", 0.17, 10, 0.010, (0, 0.03, 0.684), (90, 0, 0))
    for bi, bz in enumerate([0.42, 0.52, 0.62]):
        kb.cyl(f"CopperTrace_{bi}", 0.245, 0.245, 0.026, 20, "copper", "gear_collar", (0, 0.03, bz), (90, 0, 0), 0.003, u_rep=2.0)
    kb.glow_radiator_arc("LFRRad", (0, 0.03, 0.69), (0, 180, 0), r_outer=0.14, r_inner=0.05, depth=0.05, arc_deg=180.0, blades=9, emit_slot="emit_amber")
    for si, sx in enumerate([-0.38, 0.38]):
        kb.cyl(f"MHDPump_{si}", 0.088, 0.088, 0.34, 16, "gunmetal", "frame_cnc", (sx, -0.02, 0.44), (90, 0, 0), 0.006)
        kb.tube_path(f"LM Loop_{si}", [(sx, 0.08, 0.28), (sx * 1.12, 0.16, 0.42), (sx * 0.58, 0.12, 0.56)], 0.022, 8, "copper", "plain_metal", add_clamps=True)
    kb.decal("SVBRUnit", "unit_54", (0.20, 0.14), (0, 0.296, 0.28), (-90, 180, 0))
    kb.add_marker("LIGHT_core", (0.0, 0.03, 0.74))


# 5. gen_mhd_plasma_gen — MHD-40 Supersonic Magnetohydrodynamic Channel
def build_gen_mhd_plasma_gen(kb: KitbashScene):
    _hp_g1(kb, "G1")
    kb.plate("MHDHousing", crect_2d(0.82, 0.44, (0.08, 0.08, 0.06, 0.06)), 0.28, "armor_sub", "armor_panel", (0, 0.02, 0.23), (0, 0, 0), 0.016, 1)
    # Central rectangular supersonic Faraday channel + giant upper & lower copper saddle magnet coils!
    kb.box("FaradayChannel", (0.38, 0.18, 0.56), "dark", "frame_cnc", (0, 0.02, 0.42), (0, 0, 0), 0.012, 1)
    kb.box("PlasmaSlitL", (0.018, 0.06, 0.36), "emit_cyan", "plain_metal", (-0.202, 0.02, 0.46), (0, 0, 0), 0.002, 1)
    kb.box("PlasmaSlitR", (0.018, 0.06, 0.36), "emit_cyan", "plain_metal", ( 0.202, 0.02, 0.46), (0, 0, 0), 0.002, 1)
    for yi, sy in enumerate([-0.15, 0.19]):
        for ci in range(4):
            cz = 0.31 + ci * 0.105
            kb.plate(f"SaddleCoil_{yi}_{ci}", crect_2d(0.50, 0.065, (0.018, 0.018, 0.012, 0.012)), 0.055, "copper", "gear_collar", (0, sy, cz), (90, 0, 0), 0.006, 1)
    # Diverging supersonic diffuser nozzle at rear + HV electrode terminals
    kb.plate("DiffuserNozzle", trap_2d(0.38, 0.52, 0.22, 0.04), 0.14, "gunmetal", "bolt_flange", (0, 0.02, 0.69), (0, 0, 0), 0.010, 1)
    kb.box("NozzleBore", (0.40, 0.12, 0.026), "bore", "plain_metal", (0, 0.02, 0.752), (0, 0, 0), 0.003, 1)
    kb.box("NozzleGlow", (0.32, 0.06, 0.016), "emit_core", "plain_metal", (0, 0.02, 0.775), (0, 0, 0), 0.002, 1)
    for si, sx in enumerate([-0.32, 0.32]):
        kb.cyl(f"ElectrodeBank_{si}", 0.062, 0.062, 0.36, 14, "brass", "armor_ribs", (sx, 0.02, 0.46), (90, 0, 0), 0.005)
        kb.tube_path(f"MHDCable_{si}", [(sx, 0.02, 0.28), (sx * 1.25, 0.14, 0.22), (sx * 0.95, 0.16, 0.10)], 0.020, 8, "rubber", "braid_hose", add_clamps=True)
        kb.louver_bay(f"MHDCool_{si}", 0.22, 0.16, 0.032, (sx * 1.30, 0.02, 0.24), (0, -math.copysign(90.0, sx), 0), blades=4, mesh_style=True)
        kb.grab_rail(f"MHDGrab_{si}", 0.18, 0.036, (sx * 1.15, 0.24, 0.24), (90, 0, 0), 0.009)
    kb.decal("MHDChev", "caution_chev", (0.24, 0.10), (0, 0.29, 0.36), (-90, 180, 0))
    kb.add_marker("LIGHT_core", (0.0, 0.02, 0.77))


# 6. gen_mtu_mb873_v12 — MB-873 Twin-Turbo V12 Heavy Diesel Powerpack
def build_gen_mtu_mb873_v12(kb: KitbashScene):
    _hp_g1(kb, "G1")
    # Quick-swap German MBT diesel powerpack hull + 90-deg V12 ribbed cylinder banks + twin turbochargers + top ring fans
    kb.plate("PackCrankcase", crect_2d(0.88, 0.42, (0.08, 0.08, 0.06, 0.06)), 0.52, "armor", "armor_slab", (0, -0.04, 0.36), (0, 0, 0), 0.020, 1)
    for si, sx in enumerate([-1.0, 1.0]):
        M_vh = g2b_mat((sx * 0.22, 0.16, 0.34), (0, 0, sx * -42.0))
        kb.box(f"V12Bank_{si}", (0.22, 0.16, 0.46), "gunmetal", "armor_ribs", (0, 0, 0), (0, 0, 0), 0.012, 1, M_parent=M_vh)
        for ci in range(6):
            kb.cyl(f"InjCap_{si}_{ci}", 0.018, 0.020, 0.032, 8, "chrome", "plain_metal", (0, 0.09, -0.18 + ci * 0.072), (0, 0, 0), 0.002, M_parent=M_vh)
        # Symmetric exhaust turbocharger snail + copper charge-air intercooler pipe + top ring cooling fan!
        kb.cyl(f"TurboSnail_{si}", 0.095, 0.095, 0.11, 16, "armor_oxide", "gear_collar", (sx * 0.32, 0.10, 0.58), (0, 0, 90), 0.006)
        kb.tube_path(f"Intercooler_{si}", [(sx * 0.32, 0.18, 0.58), (sx * 0.38, 0.26, 0.42), (sx * 0.16, 0.24, 0.24)], 0.024, 8, "copper", "plain_metal", add_clamps=True)
        kb.cyl(f"TopRingFan_{si}", 0.155, 0.165, 0.048, 18, "dark", "vent_mesh", (sx * 0.21, 0.26, 0.38), (0, 0, 0), 0.005, hollow_r=0.125)
        kb.cyl(f"FanHub_{si}", 0.048, 0.052, 0.052, 12, "brass", "plain_metal", (sx * 0.21, 0.26, 0.38), (0, 0, 0), 0.003)
    kb.louver_bay("MB873RearGrille", 0.68, 0.26, 0.045, (0, -0.04, 0.635), (0, 180, 0), blades=6)
    kb.decal("MTUSoot", "soot_ring", (0.24, 0.24), (0.22, -0.04, 0.664), (0, 180, 0))
    kb.decal("MTUUnit", "ord_12", (0.18, 0.14), (-0.22, -0.04, 0.664), (0, 180, 0))
    kb.add_marker("LIGHT_core", (0.0, 0.12, 0.68))




# 8. gen_pem_fuelcell — PEM-600 Silent Hydrogen Fuel-Cell Stack
def build_gen_pem_fuelcell(kb: KitbashScene):
    _hp_g1(kb, "G1")
    # Multi-plate bipolar fuel-cell stack clamped by 4 chrome tie-rods + top copper DC busbar + 4 hydride H2 tanks
    kb.box("EndPlateF", (0.46, 0.36, 0.048), "gunmetal", "bolt_flange", (0, 0.02, 0.16), (0, 0, 0), 0.008, 1)
    kb.box("EndPlateR", (0.46, 0.36, 0.048), "gunmetal", "bolt_flange", (0, 0.02, 0.58), (0, 0, 0), 0.008, 1)
    for pi in range(10):
        pz = 0.20 + pi * 0.038
        kb.box(f"BipolarPlate_{pi}", (0.40, 0.30, 0.024), "dark" if pi % 2 == 0 else "armor_sub", "radiator_fin", (0, 0.02, pz), (0, 0, 0), 0.003, 1)
    for ti, (tx, ty) in enumerate([(-0.20, -0.14), (0.20, -0.14), (-0.20, 0.18), (0.20, 0.18)]):
        kb.cyl(f"StackTieRod_{ti}", 0.014, 0.014, 0.48, 8, "chrome", "plain_metal", (tx, ty, 0.37), (90, 0, 0), 0.002)
    kb.box("TopCopperBus", (0.28, 0.028, 0.42), "copper", "plain_metal", (0, 0.21, 0.37), (0, 0, 0), 0.003, 1)
    # 4 surrounding solid metal-hydride H2 canisters
    for hi, (hx, hy) in enumerate([(-0.36, -0.10), (0.36, -0.10), (-0.36, 0.14), (0.36, 0.14)]):
        kb.cyl(f"HydrideTank_{hi}", 0.095, 0.095, 0.46, 16, "armor", "armor_panel", (hx, hy, 0.37), (90, 0, 0), 0.008)
        kb.cyl(f"TankValve_{hi}", 0.036, 0.042, 0.048, 10, "brass", "gear_collar", (hx, hy, 0.62), (90, 0, 0), 0.003)
        kb.bolt_ring(f"TankBolts_{hi}", 0.068, 6, 0.008, (hx, hy, 0.602), (90, 0, 0))
    for si, sx in enumerate([-1.0, 1.0]):
        kb.tube_path(f"H2Manifold_{si}", [(sx * 0.36, 0.14, 0.62), (sx * 0.28, 0.22, 0.56), (sx * 0.12, 0.22, 0.48)], 0.016, 8, "copper", "plain_metal", add_clamps=True)
        kb.grab_rail(f"PEMGrab_{si}", 0.22, 0.036, (sx * 0.46, 0.02, 0.37), (0, -sx * 90.0, 0), 0.009)
    kb.louver_bay("PEMRearVent", 0.34, 0.18, 0.032, (0, -0.04, 0.61), (0, 180, 0), blades=4, mesh_style=True)
    kb.box("PEMStatusBar", (0.24, 0.036, 0.018), "emit_cyan", "plain_metal", (0, 0.10, 0.612), (0, 0, 0), 0.002, 1)
    kb.decal("PEMUnit", "unit_08", (0.20, 0.14), (0, 0.17, 0.608), (0, 180, 0))
    kb.add_marker("LIGHT_core", (0.0, 0.02, 0.66))




# 10. gen_twin_apu_gtcp — GTCP-85 Airborne Dual-Redundant Micro-Turbine APU
def build_gen_twin_apu_gtcp(kb: KitbashScene):
    _hp_g1(kb, "G1", w=0.72, h=0.44)
    kb.plate("APUCradle", crect_2d(0.80, 0.38, (0.08, 0.08, 0.06, 0.06)), 0.22, "dark", "frame_cnc", (0, 0.01, 0.19), (0, 0, 0), 0.014, 1)
    # Left & right redundant centrifugal micro-gas-turbines + brushless AC generator drums + side intake mesh
    for si, sx in enumerate([-0.23, 0.23]):
        kb.cyl(f"CentrifugalTurb_{si}", 0.135, 0.145, 0.36, 18, "armor", "armor_panel", (sx, 0.0, 0.40), (90, 0, 0), 0.008)
        kb.cyl(f"ACGenDrum_{si}", 0.095, 0.105, 0.16, 16, "gunmetal", "gear_collar", (sx, 0.0, 0.20), (90, 0, 0), 0.005)
        kb.cyl(f"APUTailcone_{si}", 0.072, 0.115, 0.12, 16, "dark", "plain_metal", (sx, 0.0, 0.63), (90, 0, 0), 0.004, hollow_r=0.056)
        kb.cyl(f"APUGlow_{si}", 0.048, 0.048, 0.02, 12, "emit_amber", "plain_metal", (sx, 0.0, 0.60), (90, 0, 0), 0.002)
        kb.louver_bay(f"SideScreen_{si}", 0.22, 0.14, 0.028, (sx + math.copysign(0.145, sx), 0.02, 0.38), (0, -math.copysign(90.0, sx), 0), blades=4, mesh_style=True)
        kb.bolt_ring(f"APUBolts_{si}", 0.11, 8, 0.008, (sx, 0.0, 0.582), (90, 0, 0))
        kb.grab_rail(f"APUGrab_{si}", 0.18, 0.034, (sx, 0.155, 0.40), (90, 0, 0), 0.008)
    # Dorsal Halon fire-suppression bottle + brass discharge manifold
    kb.cyl("HalonBottle", 0.058, 0.058, 0.36, 14, "armor_oxide", "plain_metal", (0, 0.21, 0.38), (0, 0, 90), 0.005)
    kb.cyl("HalonValve", 0.024, 0.024, 0.06, 10, "brass", "plain_metal", (0.20, 0.21, 0.38), (0, 0, 90), 0.002)
    kb.decal("GTCPUnit", "unit_17", (0.18, 0.14), (0, 0.28, 0.38), (-90, 180, 0))
    kb.add_marker("LIGHT_core", (0.0, 0.0, 0.70))
