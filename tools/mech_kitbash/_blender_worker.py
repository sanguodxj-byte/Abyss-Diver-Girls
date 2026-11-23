"""Headless Blender worker invoked by build_all.py."""
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from specs import OUT_GLB_DIR
from kitbash_lib import KitbashScene
from builders import MODULE_SPECS, load_builder


def main():
    argv = sys.argv
    ids = argv[argv.index("--") + 1:] if "--" in argv else []
    for mid in ids:
        if mid not in MODULE_SPECS:
            print(f"[ERR] No builder registered for '{mid}'")
            sys.exit(1)
        kb = KitbashScene(mid)
        load_builder(mid)(kb)
        out_path = os.path.join(OUT_GLB_DIR, f"{mid}.glb")
        kb.export_glb(out_path)


if __name__ == "__main__":
    main()
