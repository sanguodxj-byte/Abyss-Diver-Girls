"""
Authoritative engineering specs & compliance budgets for MECH_MODELING_STANDARD v1.0.
Shared between Blender Kitbash builders, batch runner, and GLB compliance auditor.
"""
import os

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_GLB_DIR = os.path.join(REPO_ROOT, "assets", "models", "mech_modules")
BLENDER_EXE = os.environ.get("BLENDER_EXE", r"D:\123\blender\blender.exe")
GODOT_EXE = os.environ.get("GODOT_EXE", r"D:\123\tmp\godot472\Godot_v4.7.2-stable_win64_console.exe")

# Unified interface geometry constants (meters, Godot coords: -Z front, +Y up, +X right)
HP_C1_RADIUS = 0.285          # Compact low-profile waist mating seam radius (legs <-> core)
HP_C1_LEGS_GAP = 0.010        # Tight clearance between legs collar top and SOCKET_core.y
HP_C1_CORE_Y_BOT = 0.000      # Standard core bottom skirt Y (relative to HP-C1 origin)

# Production Tier budgets per category (MECH_MODELING_STANDARD v1.0 Section 2.2)
CATEGORY_BUDGETS = {
    "core": {"min_tris": 6000,  "max_tris": 24000, "max_kb": 1250.0, "req_nodes": ["SOCKET_arm_l", "SOCKET_arm_r", "SOCKET_back", "SOCKET_gen"]},
    "legs": {"min_tris": 8000,  "max_tris": 28000, "max_kb": 1450.0, "req_nodes": ["SOCKET_core"]},
    "arm":  {"min_tris": 4000,  "max_tris": 15000, "max_kb": 900.0,  "req_nodes": ["MUZZLE"]},
    "back": {"min_tris": 3500,  "max_tris": 13000, "max_kb": 800.0,  "req_nodes": []},
    "gen":  {"min_tris": 3500,  "max_tris": 13000, "max_kb": 800.0,  "req_nodes": []},
}

# 20 canonical material slot suffixes (mapped to shared mech_trim / decal / canopy / bore / emit in mech_glb.gd)
VALID_MAT_SLOTS = {
    "armor",
    "armor_sub",
    "armor_dark",
    "armor_oxide",
    "dark",
    "gunmetal",
    "chrome",
    "copper",
    "brass",
    "rubber",
    "hazard",
    "accent",
    "decal",
    "bore",
    "glass",
    "emit_headlight",
    "emit_amber",
    "emit_green",
    "emit_cyan",
    "emit_red",
    "emit_core",
}

# Shared 2K Trim Sheet UV Bands in top-down image coords (u0, v0, u1, v1)
TRIM_BANDS = {
    "armor_panel":  (0.010, 0.008, 0.490, 0.114),
    "armor_hatch":  (0.010, 0.126, 0.490, 0.232),
    "armor_slab":   (0.508, 0.012, 0.992, 0.112),
    "weld_plate":   (0.512, 0.130, 0.988, 0.226),
    "armor_ribs":   (0.010, 0.244, 0.990, 0.336),
    "armor_pocket": (0.008, 0.342, 0.492, 0.412),
    "vent_louver":  (0.016, 0.428, 0.484, 0.570),
    "vent_mesh":    (0.516, 0.428, 0.984, 0.570),
    "dust_boot":    (0.010, 0.586, 0.330, 0.712),
    "braid_hose":   (0.350, 0.586, 0.670, 0.712),
    "gear_collar":  (0.686, 0.586, 0.994, 0.712),
    "hazard":       (0.010, 0.730, 0.490, 0.828),
    "bolt_flange":  (0.514, 0.736, 0.986, 0.822),
    "frame_cnc":    (0.008, 0.848, 0.658, 0.990),
    "radiator_fin": (0.672, 0.850, 0.992, 0.988),
    "plain_metal":  (0.540, 0.742, 0.610, 0.766),
}

# Shared 1024x512 Tactical Stencil & Marking Atlas cells (top-down image coords u0, v0, u1, v1)
DECAL_CELLS = {
    "unit_17":      (0.010, 0.020, 0.240, 0.480),
    "unit_54":      (0.260, 0.020, 0.490, 0.480),
    "unit_08":      (0.510, 0.020, 0.740, 0.480),
    "ord_12":       (0.760, 0.020, 0.990, 0.480),
    "hazard_tri":   (0.010, 0.520, 0.240, 0.980),
    "caution_chev": (0.260, 0.520, 0.490, 0.980),
    "lift_cg":      (0.510, 0.520, 0.740, 0.980),
    "soot_ring":    (0.760, 0.520, 0.990, 0.980),
}

# Starter BAY 03 5-piece batch (covers all 5 slot categories for full end-to-end validation)
BATCH_STARTER = [
    "core_scout",
    "legs_biped",
    "arm_gatling",
    "back_cargo",
    "gen_cell",
]

def category_of(module_id: str) -> str:
    for cat in ("core", "legs", "arm", "back", "gen"):
        if module_id.startswith(cat + "_"):
            return cat
    raise ValueError(f"Unknown module category for id: {module_id}")
