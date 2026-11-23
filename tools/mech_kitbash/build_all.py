"""
Batch CLI runner for MECH_MODELING_STANDARD v1.0 Kitbash GLB generation + automated compliance audit.

Usage (from normal Python):
  python tools/mech_kitbash/build_all.py --batch starter
  python tools/mech_kitbash/build_all.py --module core_scout legs_biped
  python tools/mech_kitbash/build_all.py --category core
  python tools/mech_kitbash/build_all.py --all --jobs 4
  python tools/mech_kitbash/build_all.py --audit-only
"""
import argparse
import concurrent.futures
import os
import subprocess
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from specs import BLENDER_EXE, OUT_GLB_DIR, BATCH_STARTER, category_of
from audit_glb import audit_one


def _run_blender_worker(module_ids: list) -> tuple:
    worker = os.path.join(SCRIPT_DIR, "_blender_worker.py")
    cmd = [BLENDER_EXE, "--background", "--factory-startup", "--python", worker, "--"] + module_ids
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout, proc.stderr


def main():
    ap = argparse.ArgumentParser(description="Build & audit high-precision mech module GLBs.")
    ap.add_argument("--module", nargs="+", help="Specific module IDs to build")
    ap.add_argument("--batch", choices=["starter"], help="Predefined batch")
    ap.add_argument("--category", choices=["core", "legs", "arm", "back", "gen"], help="Build all registered modules in category")
    ap.add_argument("--all", action="store_true", help="Build all registered modules")
    ap.add_argument("--jobs", type=int, default=4, help="Parallel Blender worker processes")
    ap.add_argument("--audit-only", action="store_true", help="Skip Blender build and only audit existing GLBs")
    args = ap.parse_args()

    from builders import MODULE_SPECS

    if args.audit_only:
        ids = args.module or sorted(os.path.splitext(fn)[0] for fn in os.listdir(OUT_GLB_DIR) if fn.endswith(".glb"))
    else:
        if args.module:
            ids = args.module
        elif args.batch == "starter":
            ids = list(BATCH_STARTER)
        elif args.category:
            ids = sorted(k for k in MODULE_SPECS if category_of(k) == args.category)
        elif args.all:
            ids = sorted(MODULE_SPECS.keys())
        else:
            ap.print_help()
            sys.exit(0)

        missing = [m for m in ids if m not in MODULE_SPECS]
        if missing:
            print(f"[ERROR] Unregistered module builders: {missing}")
            sys.exit(1)

        t0 = time.perf_counter()
        os.makedirs(OUT_GLB_DIR, exist_ok=True)
        n_jobs = max(1, min(args.jobs, len(ids)))
        chunks = [ids[i::n_jobs] for i in range(n_jobs)]
        print(f"[BUILD] Building {len(ids)} module(s) across {n_jobs} Blender worker(s)...")

        had_err = False
        with concurrent.futures.ThreadPoolExecutor(max_workers=n_jobs) as ex:
            futs = [ex.submit(_run_blender_worker, ch) for ch in chunks if ch]
            for fut in concurrent.futures.as_completed(futs):
                rc, out, err = fut.result()
                for line in out.splitlines():
                    if line.startswith("[KITBASH]") or line.startswith("[ERR"):
                        print(line)
                if rc != 0:
                    had_err = True
                    print("[BLENDER STDERR]", err[-1500:])
        print(f"[BUILD] Blender stage finished in {time.perf_counter() - t0:.2f}s")
        if had_err:
            sys.exit(1)

    # Always run automated standard audit on built targets
    failed = 0
    print(f"\n{'MODULE':<26} {'CAT':<5} {'TRIS':>7} {'MESH':>5} {'SIZE_KB':>8}  AUDIT")
    print("-" * 72)
    for mid in ids:
        res = audit_one(mid)
        status = "PASS" if res["ok"] else "FAIL"
        if not res["ok"]:
            failed += 1
        print(f"{mid:<26} {res.get('cat','?'):<5} {res['tris']:>7} {res.get('meshes',0):>5} {res['kb']:>8.1f}  {status}")
        for w in res["warnings"]:
            print(f"   [WARN] {w}")
        for e in res["errors"]:
            print(f"   [ERR ] {e}")
    print("-" * 72)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
