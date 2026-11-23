"""
Auto-discovering lazy registry for all MECH_MODELING_STANDARD v1.0 Kitbash builders.
Scans every `*.py` file in `tools/mech_kitbash/builders/` via Python AST (safe outside Blender, zero bpy import)
and registers every top-level `def build_<module_id>(kb)` where <module_id> starts with core_/legs_/arm_/back_/gen_.

Drop-in patch packs from Google AI Studio Build require ZERO edits to this file!
"""
import ast
import importlib
import os

_VALID_PREFIXES = ("core_", "legs_", "arm_", "back_", "gen_")
_BUILDERS_DIR = os.path.dirname(os.path.abspath(__file__))


def discover_builders() -> dict:
    specs = {}
    for fn in sorted(os.listdir(_BUILDERS_DIR)):
        if not fn.endswith(".py") or fn.startswith("_"):
            continue
        fpath = os.path.join(_BUILDERS_DIR, fn)
        mod_stem = os.path.splitext(fn)[0]
        try:
            tree = ast.parse(open(fpath, encoding="utf-8").read(), filename=fpath)
        except SyntaxError as exc:
            print(f"[WARN] Skipping builder file with syntax error: {fn}: {exc}")
            continue
        for node in tree.body:
            if isinstance(node, ast.FunctionDef) and node.name.startswith("build_"):
                mid = node.name[len("build_"):]
                if any(mid.startswith(p) for p in _VALID_PREFIXES):
                    specs[mid] = (f"builders.{mod_stem}", node.name)
    return specs


MODULE_SPECS = discover_builders()


def load_builder(module_id: str):
    mod_name, fn_name = MODULE_SPECS[module_id]
    mod = importlib.import_module(mod_name)
    return getattr(mod, fn_name)
