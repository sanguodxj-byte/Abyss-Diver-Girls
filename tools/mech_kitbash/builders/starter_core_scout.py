"""SC-1 (core_scout) High-Precision Recon Core — Production Standard (MECH_MODELING_STANDARD v1.0)."""
import math
from kitbash_lib import KitbashScene


def build_core_scout(kb: KitbashScene):
    # 1. Unified HP-C1 (r=0.360m, y_bot=-0.005m) Geared Slewing Ring + Dust-Boot Waist Actuators
    kb.waist_collar_core("HP_C1_Core", y_top=0.14)
    for si, sx in enumerate([-1.0, 1.0]):
        kb.hydraulic(f"WaistAct_{si}", (sx * 0.31, 0.005, -0.20), (sx * 0.39, 0.185, -0.32), 0.020)

    # 2. Recessed Dark CNC Inner Chassis Skeleton + Spine Rails + Geared HP-A1 Arm Bulkheads
    kb.box("InnerCoreTub", (1.02, 0.50, 1.00), "dark", "frame_cnc", (0, 0.31, 0.14), (0, 0, 0), 0.020, 1, tile_u=2.0)
    for yi, sy in enumerate([0.075, 0.565]):
        kb.box(f"SpineRail_{yi}", (1.16, 0.055, 0.94), "dark", "armor_ribs", (0, sy, 0.14), (0, 0, 0), 0.008, 1, tile_u=2.0)
    kb.arm_bulkhead("ArmMount", 0.66, 0.30, 0.0)

    # 3. Multi-Layer Spaced Stealth Nose (4 bolted shells over dark optical core)
    kb.box("NoseInnerBulkhead", (0.76, 0.42, 0.42), "dark", "frame_cnc", (0, 0.28, -0.58), (0, 0, 0), 0.018, 1)

    # 3a. Upper Glacis Armor Hood (sloped down-forward + crest + hazard badge + grab bar)
    kb.spaced_armor_plate("UpperGlacis", (0.86, 0.44, 0.068), "armor", "armor_panel", (0, 0.485, -0.62), (62, 0, 0))
    kb.box("GlacisCrest", (0.24, 0.036, 0.36), "armor_sub", "armor_ribs", (0, 0.525, -0.61), (-28, 0, 0), 0.008, 1)
    kb.box("GlacisHazard", (0.18, 0.016, 0.056), "hazard", "hazard", (-0.27, 0.495, -0.66), (-28, 0, 0), 0.003, 1)
    kb.grab_rail("NoseHoodGrab", 0.24, 0.036, (0.20, 0.555, -0.52), (62, 0, 0), 0.010)

    # 3b. Left & Right Wrapped Cheek Armor Plates + Corner Bumper Brackets
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"NoseCheek_{si}", (0.36, 0.28, 0.064), "armor_sub", "armor_hatch",
                              (sx * 0.415, 0.275, -0.635), (0, sx * -34.0, sx * 8.0))
        kb.box(f"CheekGusset_{si}", (0.062, 0.16, 0.14), "gunmetal", "bolt_flange",
               (sx * 0.355, 0.275, -0.775), (0, sx * -18.0, 0), 0.008, 1)

    # 3c. Heavy Multi-Layer Armored Cockpit Visor (deep recess + 3 emerald glass prisms + brush guard)
    kb.box("VisorHousing", (0.66, 0.175, 0.14), "dark", "frame_cnc", (0, 0.275, -0.755), (0, 0, 0), 0.012, 1)
    kb.box("VisorRecess", (0.58, 0.105, 0.03), "bore", "plain_metal", (0, 0.275, -0.805), (0, 0, 0), 0.003, 1)
    kb.box("VisorBrowArmor", (0.70, 0.044, 0.165), "armor", "armor_ribs", (0, 0.365, -0.820), (12, 0, 0), 0.009, 1)
    for gi, gx in enumerate([-0.26, -0.09, 0.09, 0.26]):
        kb.box(f"BrowGusset_{gi}", (0.024, 0.045, 0.095), "gunmetal", "plain_metal", (gx, 0.335, -0.840), (0, 0, 0), 0.004, 1)
        kb.cyl(f"BrowBolt_{gi}", 0.009, 0.011, 0.014, 6, "chrome", "plain_metal", (gx, 0.388, -0.835), (12, 0, 0), 0.002)
    kb.box("VisorSillArmor", (0.64, 0.032, 0.115), "gunmetal", "bolt_flange", (0, 0.188, -0.818), (-10, 0, 0), 0.006, 1)
    for pi, (px, pw) in enumerate([(-0.185, 0.155), (0.0, 0.175), (0.185, 0.155)]):
        kb.box(f"VisorGlass_{pi}", (pw, 0.078, 0.022), "glass", "plain_metal", (px, 0.275, -0.832), (0, 0, 0), 0.003, 1)
    for mi, mx in enumerate([-0.10, 0.10]):
        kb.box(f"VisorMullion_{mi}", (0.026, 0.135, 0.068), "dark", "bolt_flange", (mx, 0.275, -0.838), (0, 0, 0), 0.004, 1)
        kb.cyl(f"MullionPin_{mi}", 0.008, 0.010, 0.014, 6, "chrome", "plain_metal", (mx, 0.275, -0.874), (90, 0, 0), 0.002)
    kb.grab_rail("VisorGuardBar", 0.64, 0.055, (0, 0.225, -0.84), (0, 0, 0), 0.008)

    # 3d. Lower Chin Bumper + Caged Headlights + Tow Shackles + Apache 3-Optic EO/IR Gimbal
    kb.spaced_armor_plate("LowerChinPlate", (0.74, 0.165, 0.068), "armor_sub", "armor_ribs", (0, 0.105, -0.74), (24, 0, 0))
    for si, sx in enumerate([-1.0, 1.0]):
        kb.headlight_cage(f"Headlight_{si}", (sx * 0.33, 0.105, -0.775), (0, sx * -10.0, 0))
        kb.tow_shackle(f"TowShackle_{si}", (sx * 0.20, 0.035, -0.785))
    kb.eoir_gimbal("ChinEOIR", (0, -0.015, -0.705))
    kb.tube_path("EOIR_Cable", [(0.11, -0.015, -0.68), (0.17, 0.01, -0.62), (0.14, 0.07, -0.55)], 0.011, 8, "gunmetal", "braid_hose")

    # 4. Upper Roof Deck, Radiator Bay, Exhaust Stacks, Commander Cupola & AESA Recon Mast
    kb.spaced_armor_plate("RoofDeckMain", (1.06, 0.62, 0.075), "armor", "armor_panel", (0, 0.655, -0.02), (-90, 0, 0))
    kb.louver_bay("TopRadiatorBay", 0.56, 0.28, 0.065, (0, 0.655, 0.44), (-90, 0, 0), blades=5, mesh_style=False)
    for si, sx in enumerate([-0.38, 0.38]):
        kb.cyl(f"ExhPipe_{si}", 0.042, 0.046, 0.26, 14, "dark", "plain_metal", (sx, 0.72, 0.58), (12, 0, 0), 0.004, hollow_r=0.031)
        kb.cyl(f"ExhJacket_{si}", 0.060, 0.060, 0.18, 16, "gunmetal", "vent_mesh", (sx, 0.71, 0.58), (12, 0, 0), 0.004, hollow_r=0.052, u_rep=2.0)
    kb.cupola_hatch("CmdCupola", (-0.16, 0.685, 0.02))
    kb.recon_mast("ReconMast", (0.28, 0.685, 0.18))

    # 5. High-Density Asymmetric Flanks: Spaced Armor, Shoulder Sensor Pods + Smoke Racks, Pipes, Stowage
    for si, sx in enumerate([-1.0, 1.0]):
        kb.spaced_armor_plate(f"SideArmor_{si}", (0.76, 0.44, 0.072), "armor", "armor_panel" if si == 0 else "armor_hatch",
                              (sx * 0.60, 0.30, 0.26), (0, sx * 90.0, sx * 4.0))
        kb.box(f"ShoulderCowl_{si}", (0.22, 0.14, 0.68), "armor_sub", "armor_ribs", (sx * 0.56, 0.56, 0.22), (0, 0, sx * -24.0), 0.011, 1)
        kb.spaced_armor_plate(f"PodBox_{si}", (0.21, 0.18, 0.48), "armor_sub", "armor_pocket",
                              (sx * 0.56, 0.65, -0.18), (0, 0, 0), standoffs=False, bolts=False)
        kb.cyl(f"PodBezel_{si}", 0.056, 0.058, 0.032, 16, "gunmetal", "gear_collar", (sx * 0.56, 0.65, -0.425), (90, 0, 0), 0.004, hollow_r=0.044)
        kb.cyl(f"PodOptic_{si}", 0.042, 0.042, 0.018, 16, "emit_amber", "plain_metal", (sx * 0.56, 0.65, -0.420), (90, 0, 0), 0.003)
        kb.box(f"PodHood_{si}", (0.23, 0.026, 0.24), "gunmetal", "bolt_flange", (sx * 0.56, 0.745, -0.28), (6, 0, 0), 0.005, 1)
        kb.smoke_pod(f"SmokeRack_{si}", (sx * 0.50, 0.71, -0.45), (-24, sx * -14.0, 0))

    # Left Flank: Intake Louver Bay + Copper/Brass Coolant Lines + Grab Rail
    kb.louver_bay("LeftIntakeBay", 0.34, 0.19, 0.055, (-0.65, 0.24, 0.36), (0, -90, 0), blades=5, mesh_style=False)
    kb.tube_path("LeftCoolant1", [(-0.62, 0.14, 0.28), (-0.64, 0.08, 0.12), (-0.42, 0.06, 0.05)], 0.016, 8, "copper", "plain_metal")
    kb.tube_path("LeftCoolant2", [(-0.62, 0.10, 0.32), (-0.63, 0.04, 0.15), (-0.42, 0.03, 0.08)], 0.014, 8, "brass", "plain_metal")
    kb.grab_rail("LeftSideGrab", 0.24, 0.040, (-0.655, 0.43, 0.22), (0, 90, 0), 0.011)

    # Right Flank: Perforated Heat-Shield + Field Stowage Rack + Braided Hydraulic Bundle
    kb.louver_bay("RightExhaustBay", 0.30, 0.17, 0.050, (0.65, 0.40, 0.38), (0, 90, 0), blades=4, mesh_style=True)
    kb.stowage_rack("RightStowage", (0.675, 0.19, 0.32), (0, -90, 0))
    for hi, hoff in enumerate([-0.020, 0.0, 0.020]):
        kb.tube_path(f"RightHose_{hi}",
                     [(0.58, 0.12 + hoff, 0.14), (0.62, 0.08 + hoff, -0.05), (0.56, 0.09 + hoff, -0.26), (0.38, 0.08 + hoff, -0.32)],
                     0.010, 8, "gunmetal", "braid_hose", add_clamps=(hi == 1))

    # Standard Socket Markers (matching core_scout.gd exact positions!)
    kb.add_marker("SOCKET_arm_l", (-0.66, 0.30, 0.0))
    kb.add_marker("SOCKET_arm_r", (0.66, 0.30, 0.0))
    kb.add_marker("SOCKET_back",  (0.0,  0.56, 0.405))
    kb.add_marker("SOCKET_gen",   (0.0,  0.12, 0.725))
