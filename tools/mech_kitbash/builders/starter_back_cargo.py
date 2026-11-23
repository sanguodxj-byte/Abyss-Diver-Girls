"""CG-10 (back_cargo) High-Precision Tactical Field Cargo Rack — MECH_MODELING_STANDARD v1.0."""
from kitbash_lib import KitbashScene, crect_2d


def build_back_cargo(kb: KitbashScene):
    # Origin (0,0,0) = HP-B1 dual-rail mating face (+Y up, +Z back)
    # 1. Heavy Dual-Rail Mount Base + CNC Cargo Deck + Angled Hydraulic Struts
    kb.box("B1MountClamp", (0.86, 0.18, 0.48), "dark", "frame_cnc", (0, 0.02, 0.09), (0, 0, 0), 0.014, 1)
    kb.box("CargoDeck", (1.24, 0.095, 1.02), "dark", "armor_pocket", (0, 0.08, 0.32), (0, 0, 0), 0.014, 1, tile_u=2.0)
    kb.box("DeckHazardRear", (1.16, 0.055, 0.025), "hazard", "hazard", (0, 0.08, 0.835), (0, 0, 0), 0.004, 1)
    for si, sx in enumerate([-0.46, 0.46]):
        kb.hydraulic(f"RackStrut_{si}", (sx, -0.10, 0.08), (sx, 0.06, 0.68), 0.022)
    # Welded tubular roll-cage uprights + crossbar + side grab handles
    for si, sx in enumerate([-0.59, 0.59]):
        kb.box(f"RearPost_{si}", (0.068, 0.58, 0.068), "gunmetal", "bolt_flange", (sx, 0.37, 0.80), (0, 0, 0), 0.009, 1)
        kb.box(f"FrontPost_{si}", (0.055, 0.34, 0.055), "dark", "plain_metal", (sx, 0.24, 0.06), (0, 0, 0), 0.008, 1)
        kb.box(f"SideRail_{si}", (0.045, 0.045, 0.74), "gunmetal", "plain_metal", (sx, 0.36, 0.43), (0, 0, 0), 0.007, 1)
        kb.grab_rail(f"SideGrab_{si}", 0.22, 0.044, (sx + (0.035 if sx > 0 else -0.035), 0.11, 0.36), (0, -90 if sx > 0 else 90, 0), 0.010)
    kb.box("TopCrossbar", (1.24, 0.062, 0.062), "gunmetal", "bolt_flange", (0, 0.64, 0.80), (0, 0, 0), 0.009, 1)

    # 2. Heavy Armored Field Transport Chest (multi-ribbed shell + lid + corner guards + latches)
    kb.plate("MainChest", crect_2d(0.80, 0.48, (0.06, 0.06, 0.06, 0.06)), 1.06, "armor", "armor_panel",
             (0, 0.37, 0.35), (0, 90, 0), 0.016, 1)
    kb.box("ChestLid", (1.09, 0.075, 0.83), "armor_sub", "armor_hatch", (0, 0.555, 0.35), (0, 0, 0), 0.012, 1)
    for ri, rx in enumerate([-0.36, -0.12, 0.12, 0.36]):
        kb.box(f"ChestRib_{ri}", (0.038, 0.36, 0.822), "armor_sub", "armor_ribs", (rx, 0.34, 0.35), (0, 0, 0), 0.006, 1)
    # 4 heavy forged lifting corner bumpers with bolts
    for ci, (cx, cz) in enumerate([(-0.52, -0.04), (0.52, -0.04), (-0.52, 0.74), (0.52, 0.74)]):
        kb.box(f"CornerGuard_{ci}", (0.10, 0.10, 0.10), "dark", "bolt_flange", (cx, 0.585, cz), (0, 0, 0), 0.010, 1)
        kb.cyl(f"CornerBolt_{ci}", 0.012, 0.014, 0.016, 6, "chrome", "plain_metal", (cx, 0.640, cz), (0, 0, 0), 0.002)
    # Tactical amber identification band + rear recessed maintenance hatch plate
    kb.box("ChestAccent", (1.08, 0.048, 0.56), "accent", "plain_metal", (0, 0.49, 0.35), (0, 0, 0), 0.004, 1)
    kb.spaced_armor_plate("RearSpecPlate", (0.48, 0.24, 0.032), "armor_sub", "armor_hatch", (0, 0.33, 0.765), (0, 180, 0))

    # 3. Top Auxiliary Munitions Case + Waterproof Tactical Field Pack
    kb.plate("TopAmmoBox", crect_2d(0.46, 0.22, (0.04, 0.04, 0.02, 0.02)), 0.60, "armor_sub", "armor_panel",
             (0.20, 0.71, 0.39), (0, 95, 0), 0.012, 1)
    for li, lx in enumerate([0.04, 0.36]):
        kb.box(f"AmmoClasp_{li}", (0.042, 0.092, 0.028), "chrome", "plain_metal", (lx, 0.71, 0.628), (0, 0, 0), 0.004, 1)
    kb.grab_rail("AmmoHandle", 0.18, 0.032, (0.20, 0.83, 0.39), (-90, 0, 0), 0.009)
    # Rolled waterproof tactical tarp / spare fuel canister on left roof
    kb.cyl("TarpRoll", 0.115, 0.115, 0.42, 16, "rubber", "dust_boot", (-0.32, 0.70, 0.42), (0, 12, 90), 0.010, u_rep=2.0)
    for ti, tx in enumerate([-0.42, -0.22]):
        kb.cyl(f"TarpStrap_{ti}", 0.122, 0.122, 0.028, 16, "dark", "plain_metal", (tx, 0.70, 0.42), (0, 12, 90), 0.003)

    # 4. Twin Heavy Webbing Straps + Forged Steel Ratchet Binders & Brass Tension Spools
    for si, sx in enumerate([-0.30, 0.30]):
        kb.box(f"WebStrap_{si}", (0.058, 0.54, 0.855), "rubber", "braid_hose", (sx, 0.37, 0.35), (0, 0, 0), 0.005, 1)
        kb.box(f"RatchetBody_{si}", (0.095, 0.115, 0.056), "gunmetal", "bolt_flange", (sx, 0.42, 0.788), (0, 0, 0), 0.008, 1)
        kb.cyl(f"RatchetSpool_{si}", 0.024, 0.024, 0.115, 10, "brass", "gear_collar", (sx, 0.42, 0.808), (0, 0, 90), 0.003)
        kb.box(f"RatchetLever_{si}", (0.026, 0.095, 0.022), "chrome", "plain_metal", (sx + 0.042, 0.37, 0.815), (-18, 0, 0), 0.003, 1)
