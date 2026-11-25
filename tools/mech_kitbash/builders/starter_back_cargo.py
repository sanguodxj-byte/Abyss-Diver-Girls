"""CG-10 (back_cargo) High-Precision Tactical Field Cargo Rack — MECH_MODELING_STANDARD v1.0."""
from kitbash_lib import KitbashScene, crect_2d


def build_back_cargo(kb: KitbashScene):
    # Origin (0,0,0) = HP-B1 dual-rail mating face (+Y up, +Z back)
    # 1. Heavy Dual-Rail Mount Base + CNC Cargo Deck + Angled Hydraulic Struts (strictly y>=0.00 so 0 clash with core!)
    kb.box("B1MountClamp", (0.82, 0.08, 0.44), "dark", "frame_cnc", (0, 0.04, 0.09), (0, 0, 0), 0.010, 1)
    kb.box("CargoDeck", (1.24, 0.085, 0.96), "dark", "armor_pocket", (0, 0.105, 0.34), (0, 0, 0), 0.012, 1, tile_u=2.0)
    kb.box("DeckHazardRear", (1.16, 0.052, 0.024), "hazard", "hazard", (0, 0.105, 0.825), (0, 0, 0), 0.004, 1)
    for si, sx in enumerate([-0.46, 0.46]):
        kb.hydraulic(f"RackStrut_{si}", (sx, 0.01, 0.22), (sx, 0.085, 0.68), 0.020)
    # Welded tubular roll-cage uprights + crossbar + cleanly seated side grab handles (x=±0.618 seats directly into deck!)
    for si, sx in enumerate([-0.59, 0.59]):
        kb.box(f"RearPost_{si}", (0.068, 0.56, 0.068), "gunmetal", "bolt_flange", (sx, 0.39, 0.79), (0, 0, 0), 0.009, 1)
        kb.box(f"FrontPost_{si}", (0.055, 0.34, 0.055), "dark", "plain_metal", (sx, 0.28, 0.06), (0, 0, 0), 0.008, 1)
        kb.box(f"SideRail_{si}", (0.044, 0.044, 0.67), "gunmetal", "plain_metal", (sx, 0.39, 0.425), (0, 0, 0), 0.007, 1)
        kb.grab_rail(f"SideGrab_{si}", 0.22, 0.042, (sx + (0.026 if sx > 0 else -0.026), 0.115, 0.36), (0, -90 if sx > 0 else 90, 0), 0.010)
    kb.box("TopCrossbar", (1.24, 0.062, 0.062), "gunmetal", "bolt_flange", (0, 0.65, 0.79), (0, 0, 0), 0.009, 1)

    # 2. Heavy Armored Field Transport Chest (multi-ribbed shell + lid + corner guards + ZERO Z-fighting on RearSpecPlate!)
    kb.plate("MainChest", crect_2d(0.76, 0.48, (0.06, 0.06, 0.06, 0.06)), 1.06, "armor", "armor_panel",
             (0, 0.38, 0.37), (0, 90, 0), 0.014, 1)
    kb.box("ChestLid", (1.09, 0.072, 0.79), "armor_sub", "armor_hatch", (0, 0.565, 0.37), (0, 0, 0), 0.012, 1)
    for ri, rx in enumerate([-0.36, -0.12, 0.12, 0.36]):
        kb.box(f"ChestRib_{ri}", (0.036, 0.34, 0.778), "armor_sub", "armor_ribs", (rx, 0.35, 0.37), (0, 0, 0), 0.006, 1)
    # 4 heavy forged lifting corner bumpers with bolts
    for ci, (cx, cz) in enumerate([(-0.52, -0.01), (0.52, -0.01), (-0.52, 0.75), (0.52, 0.75)]):
        kb.box(f"CornerGuard_{ci}", (0.10, 0.10, 0.10), "dark", "bolt_flange", (cx, 0.595, cz), (0, 0, 0), 0.010, 1)
        kb.cyl(f"CornerBolt_{ci}", 0.012, 0.014, 0.016, 6, "chrome", "plain_metal", (cx, 0.650, cz), (0, 0, 0), 0.002)
    # Tactical amber identification band + rear recessed maintenance hatch plate strictly proud of ChestRib (z=0.778 -> 0 Z-fight!)
    kb.box("ChestAccent", (1.08, 0.048, 0.54), "accent", "plain_metal", (0, 0.50, 0.37), (0, 0, 0), 0.004, 1)
    kb.spaced_armor_plate("RearSpecPlate", (0.46, 0.22, 0.028), "armor_sub", "armor_hatch", (0, 0.34, 0.776), (0, 180, 0))

    # 3. Top Auxiliary Munitions Case + Waterproof Tactical Field Pack
    kb.plate("TopAmmoBox", crect_2d(0.44, 0.22, (0.04, 0.04, 0.02, 0.02)), 0.60, "armor_sub", "armor_panel",
             (0.20, 0.71, 0.40), (0, 95, 0), 0.012, 1)
    for li, lx in enumerate([0.04, 0.36]):
        kb.box(f"AmmoClasp_{li}", (0.042, 0.092, 0.028), "chrome", "plain_metal", (lx, 0.71, 0.625), (0, 0, 0), 0.004, 1)
    kb.grab_rail("AmmoHandle", 0.18, 0.032, (0.20, 0.822, 0.40), (-90, 0, 0), 0.009)
    # Rolled waterproof tactical tarp / spare fuel canister on left roof
    kb.cyl("TarpRoll", 0.115, 0.115, 0.42, 16, "rubber", "dust_boot", (-0.32, 0.71, 0.43), (0, 12, 90), 0.010, u_rep=2.0)
    for ti, tx in enumerate([-0.42, -0.22]):
        kb.cyl(f"TarpStrap_{ti}", 0.122, 0.122, 0.028, 16, "dark", "plain_metal", (tx, 0.71, 0.43), (0, 12, 90), 0.003)

    # 4. Twin Heavy Webbing Straps + Forged Steel Ratchet Binders & Brass Tension Spools
    for si, sx in enumerate([-0.30, 0.30]):
        kb.box(f"WebStrap_{si}", (0.056, 0.54, 0.812), "rubber", "braid_hose", (sx, 0.38, 0.37), (0, 0, 0), 0.005, 1)
        kb.box(f"RatchetBody_{si}", (0.092, 0.110, 0.052), "gunmetal", "bolt_flange", (sx, 0.43, 0.785), (0, 0, 0), 0.008, 1)
        kb.cyl(f"RatchetSpool_{si}", 0.022, 0.022, 0.112, 10, "brass", "gear_collar", (sx, 0.43, 0.805), (0, 0, 90), 0.003)
        kb.box(f"RatchetLever_{si}", (0.024, 0.090, 0.020), "chrome", "plain_metal", (sx + 0.040, 0.38, 0.812), (-18, 0, 0), 0.003, 1)
