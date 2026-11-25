"""
Parallel Blender 5.1 Batch Exporter for All 18 Sci-Fi Mecha-Swarm Regular Enemies (`assets/models/enemies/*.glb`)
and All 16 Sci-Fi Mecha-Swarm Boss Hardware Sub-Assemblies (`assets/models/boss/kit_boss_*.glb`).
"""
import os
import sys
import json
import time
import argparse
import subprocess
from concurrent.futures import ProcessPoolExecutor, as_completed

BLENDER_EXE = r"D:\123\blender\blender.exe"
THIS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(THIS_DIR, "..", ".."))
ENEMY_OUT_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "enemies")
BOSS_OUT_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "boss")

ENEMY_IDS = [
    "ling", "spitter", "beetle", "mantis", "bomber", "wasp",
    "crystal_bug", "burrower", "mech_beetle", "shielder", "mortar", "ironjaw",
    "aegis", "lancer", "overseer", "ripper", "brood", "colossus",
]

BOSS_KIT_IDS = [
    "kit_boss_chassis",
    "kit_boss_femur_r",
    "kit_boss_femur_l",
    "kit_boss_talon_foot",
    "kit_boss_arm_boom_r",
    "kit_boss_arm_boom_l",
    "kit_boss_core_vault",
    "kit_boss_core_door_r",
    "kit_boss_core_door_l",
    "kit_boss_plasma_pod",
    "kit_boss_plasma_jaw_r",
    "kit_boss_plasma_jaw_l",
    "kit_boss_plasma_saw",
    "kit_boss_plasma_auger",
    "kit_boss_pulse_gatling",
    "kit_boss_phase_crown",
]


def _worker_entry():
    idx = sys.argv.index("--worker")
    items = sys.argv[idx + 1].split(",")
    if THIS_DIR not in sys.path:
        sys.path.insert(0, THIS_DIR)
    mech_kb = os.path.abspath(os.path.join(THIS_DIR, "..", "mech_kitbash"))
    if mech_kb not in sys.path:
        sys.path.insert(0, mech_kb)

    from kitbash_lib import KitbashScene
    import builders_swarm as bs
    import builders_tactical as bt
    import builders_heavy as bh
    import boss_kit_builders as bk

    registry = {}
    for mod in (bs, bt, bh, bk):
        for attr in dir(mod):
            if attr.startswith("build_"):
                registry[attr[len("build_"):]] = getattr(mod, attr)

    results = []
    for item_id in items:
        fn = registry[item_id]
        is_boss_kit = item_id.startswith("kit_boss_")
        out_dir = BOSS_OUT_DIR if is_boss_kit else ENEMY_OUT_DIR
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, f"{item_id}.glb")
        ao_dist = 0.55 if item_id in ("brood", "colossus") else 0.42
        kb = KitbashScene(item_id, ao_rays=20, ao_dist=ao_dist)
        fn(kb)
        st = kb.export_glb(out_path)
        st["name"] = item_id
        results.append(st)
    print("WORKER_JSON:" + json.dumps(results))


def _run_chunk(chunk: list) -> list:
    cmd = [
        BLENDER_EXE, "--background", "--factory-startup",
        "--python", os.path.abspath(__file__),
        "--", "--worker", ",".join(chunk),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError(f"Blender failed on {chunk}:\n{proc.stdout[-1500:]}\n{proc.stderr[-1500:]}")
    for line in proc.stdout.splitlines():
        if line.startswith("WORKER_JSON:"):
            return json.loads(line[len("WORKER_JSON:"):])
    raise RuntimeError(f"Missing WORKER_JSON on {chunk}:\n{proc.stdout[-1200:]}")


def main():
    if "--worker" in sys.argv:
        _worker_entry()
        return

    ap = argparse.ArgumentParser()
    ap.add_argument("--only", type=str, default="")
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()

    all_ids = ENEMY_IDS + BOSS_KIT_IDS
    if args.only:
        want = [x.strip() for x in args.only.split(",") if x.strip()]
        targets = [x for x in all_ids if x in want]
    else:
        targets = all_ids

    n_workers = min(args.workers, max(1, len(targets)))
    chunks = [targets[i::n_workers] for i in range(n_workers)]
    t0 = time.time()
    print(f"Building {len(targets)} Mecha-Swarm GLB models across {len(chunks)} Blender 5.1 workers...")
    all_res = []
    with ProcessPoolExecutor(max_workers=n_workers) as ex:
        futs = {ex.submit(_run_chunk, ch): ch for ch in chunks}
        for f in as_completed(futs):
            res = f.result()
            for r in res:
                print(f"  [OK] {r['name']:24s} | tris={r['tris']:6d} | meshes={r['meshes']:2d} | {r['kb']:6.1f} KB | {r.get('time_s', 0.0):.1f}s")
                all_res.append(r)

    dt = time.time() - t0
    print(f"\nCompleted {len(all_res)} Mecha-Swarm GLBs in {dt:.1f}s!")
    reg = [r["tris"] for r in all_res if not r["name"].startswith("kit_boss_")]
    if reg:
        print(f"Regular Enemies ({len(reg)}): min={min(reg)} tris, avg={sum(reg)//len(reg)} tris, max={max(reg)} tris")


if __name__ == "__main__":
    main()
