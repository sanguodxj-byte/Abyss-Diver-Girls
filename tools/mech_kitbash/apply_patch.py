"""
One-click local Patch-Pack Importer, Validator, Blender Builder & Godot Integrator
for patches downloaded from Google AI Studio Build.

Usage:
  python tools/mech_kitbash/apply_patch.py path/to/ai_studio_patch.zip
  python tools/mech_kitbash/apply_patch.py path/to/unpacked_patch_folder --jobs 4
  python tools/mech_kitbash/apply_patch.py path/to/patch.zip --no-godot   # skip Godot import/bake for fast preview
"""
import argparse
import ast
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from specs import REPO_ROOT, GODOT_EXE, VALID_MAT_SLOTS, TRIM_BANDS

BUILDERS_DIR = os.path.join(SCRIPT_DIR, "builders")
VALID_PREFIXES = ("core_", "legs_", "arm_", "back_", "gen_")


def inspect_builder_py(fpath: str) -> tuple:
    """Parse Python AST safely: returns (module_ids, errors, warnings)."""
    errors, warnings, mids = [], [], []
    try:
        src = open(fpath, encoding="utf-8").read()
        tree = ast.parse(src, filename=fpath)
    except Exception as exc:
        return [], [f"Syntax/encoding error in {os.path.basename(fpath)}: {exc}"], []

    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name.startswith("build_"):
            mid = node.name[len("build_"):]
            if any(mid.startswith(p) for p in VALID_PREFIXES):
                mids.append(mid)

    # Light static sanity checks for forbidden imports / obvious typos
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            names = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""]
            for nm in names:
                if nm in ("subprocess", "shutil", "socket", "urllib", "http", "requests"):
                    errors.append(f"Forbidden import '{nm}' in {os.path.basename(fpath)}")
        # Check literal mat_slot & band_key on kb.* calls using exact positional arg indices
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            fn = node.func.attr
            idx_map = {
                "box": (2, 3),
                "loft": (2, 3),
                "spaced_armor_plate": (2, 3),
                "plate": (3, 4),
                "lathe": (3, 4),
                "cyl": (5, 6),
            }
            if fn in idx_map:
                mi, bi = idx_map[fn]
                if len(node.args) > mi:
                    am = node.args[mi]
                    if isinstance(am, ast.Constant) and isinstance(am.value, str) and am.value not in VALID_MAT_SLOTS:
                        errors.append(f"{os.path.basename(fpath)}:{node.lineno} unknown mat_slot '{am.value}'")
                if len(node.args) > bi:
                    ab = node.args[bi]
                    if isinstance(ab, ast.Constant) and isinstance(ab.value, str) and ab.value not in TRIM_BANDS:
                        errors.append(f"{os.path.basename(fpath)}:{node.lineno} unknown trim band '{ab.value}'")

    if not mids:
        warnings.append(f"{os.path.basename(fpath)} contains no `def build_<module_id>(kb)` functions (ignored)")
    return mids, errors, warnings


def collect_candidate_files(src_path: str, tmp_dir: str) -> list:
    files = []
    if os.path.isfile(src_path) and zipfile.is_zipfile(src_path):
        with zipfile.ZipFile(src_path, "r") as zf:
            for info in zf.infolist():
                if info.is_dir():
                    continue
                norm = info.filename.replace("\\", "/")
                if norm.endswith(".py") and not os.path.basename(norm).startswith("_"):
                    # Only accept files under builders/ OR bare builder *.py at zip root / patch subfolder
                    base = os.path.basename(norm)
                    if base in ("kitbash_lib.py", "specs.py", "build_all.py", "audit_glb.py", "apply_patch.py", "trim_sheet.py"):
                        continue
                    dst = os.path.join(tmp_dir, base)
                    with zf.open(info) as src_f, open(dst, "wb") as out_f:
                        shutil.copyfileobj(src_f, out_f)
                    files.append(dst)
    elif os.path.isdir(src_path):
        for root, _, fns in os.walk(src_path):
            for fn in sorted(fns):
                if fn.endswith(".py") and not fn.startswith("_"):
                    if fn in ("kitbash_lib.py", "specs.py", "build_all.py", "audit_glb.py", "apply_patch.py", "trim_sheet.py"):
                        continue
                    files.append(os.path.join(root, fn))
    elif os.path.isfile(src_path) and src_path.endswith(".py"):
        files.append(src_path)
    else:
        raise ValueError(f"Unsupported patch input: {src_path} (expected .zip, folder, or .py)")
    return files


def run_step(cmd: list, label: str) -> int:
    print(f"\n[PATCH] >>> {label}")
    proc = subprocess.run(cmd)
    if proc.returncode != 0:
        print(f"[PATCH] FAILED ({proc.returncode}): {label}")
    return proc.returncode


def main():
    ap = argparse.ArgumentParser(description="Apply & verify a mech Kitbash patch pack from Google AI Studio Build.")
    ap.add_argument("patch_path", help="Path to downloaded .zip, directory, or .py builder file")
    ap.add_argument("--jobs", type=int, default=4, help="Parallel Blender workers")
    ap.add_argument("--dry-run", action="store_true", help="Only validate AST & list modules without installing")
    ap.add_argument("--no-godot", action="store_true", help="Skip Godot --import & NPC visual cache bake/test")
    args = ap.parse_args()

    tmp_dir = tempfile.mkdtemp(prefix="mech_patch_")
    try:
        candidates = collect_candidate_files(args.patch_path, tmp_dir)
        if not candidates:
            print("[PATCH] No candidate builder .py files found in:", args.patch_path)
            sys.exit(1)

        valid_files = []
        all_mids = []
        all_errors = []
        for fpath in candidates:
            mids, errs, warns = inspect_builder_py(fpath)
            for w in warns:
                print("  [WARN]", w)
            for e in errs:
                print("  [ERR ]", e)
            all_errors.extend(errs)
            if mids and not errs:
                valid_files.append((fpath, mids))
                all_mids.extend(mids)

        if all_errors:
            print(f"\n[PATCH] Aborted: {len(all_errors)} static validation error(s) found. Zero files installed.")
            sys.exit(1)
        if not valid_files:
            print("[PATCH] No valid `def build_<module_id>(kb)` builders found.")
            sys.exit(1)

        print(f"[PATCH] Validated {len(valid_files)} file(s) -> {len(all_mids)} module(s): {', '.join(all_mids)}")
        if args.dry_run:
            print("[PATCH] Dry-run PASS.")
            sys.exit(0)

        os.makedirs(BUILDERS_DIR, exist_ok=True)
        for fpath, _ in valid_files:
            dst = os.path.join(BUILDERS_DIR, os.path.basename(fpath))
            shutil.copy2(fpath, dst)
            print(f"  Installed -> tools/mech_kitbash/builders/{os.path.basename(fpath)}")

        # 1. Build & Audit GLBs in Blender 5.1.2
        rc = run_step(
            [sys.executable, os.path.join(SCRIPT_DIR, "build_all.py"), "--module"] + all_mids + ["--jobs", str(args.jobs)],
            f"Blender Kitbash Build + MECH_MODELING_STANDARD Audit ({len(all_mids)} modules)",
        )
        if rc != 0:
            sys.exit(rc)

        # 2. Refresh manifest progress
        run_step([sys.executable, os.path.join(SCRIPT_DIR, "gen_manifest_md.py")], "Update 101-module Manifest Progress")

        # 3. Godot import + NPC visual cache bake & verification
        if not args.no_godot:
            for label, extra in [
                ("Godot --import (pre-import new GLBs)", ["--import"]),
                ("Godot --npc_visual_bake", ["--", "--npc_visual_bake"]),
                ("Godot --npc_visual_cache_test", ["--", "--npc_visual_cache_test"]),
            ]:
                rc = run_step([GODOT_EXE, "--headless", "--path", REPO_ROOT] + extra, label)
                if rc != 0:
                    sys.exit(rc)

        print(f"\n[PATCH] SUCCESS! Applied, audited & integrated {len(all_mids)} module(s).")
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
