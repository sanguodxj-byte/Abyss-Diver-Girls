"""
Automated Compliance Auditor for MECH_MODELING_STANDARD v1.0.
Parses exported .glb headers directly in Python (<10ms per file) and enforces:
  1. Zero embedded images/textures (shared 2K Trim Sheet bound in Godot)
  2. Every primitive has POSITION, NORMAL, TANGENT, TEXCOORD_0, COLOR_0
  3. Zero negative scale on any node (guarantees normal_audit zero errors)
  4. Valid canonical material slot naming (`<Group>__<mat_slot>`)
  5. Category polycount & file-size budgets
  6. Mandatory socket/muzzle/articulation nodes (`SOCKET_*`, `MUZZLE`, `Leg_*`/`Track_*`)
"""
import json
import os
import struct
import sys

from specs import CATEGORY_BUDGETS, VALID_MAT_SLOTS, OUT_GLB_DIR, category_of


def parse_glb_json(glb_path: str) -> dict:
    with open(glb_path, "rb") as f:
        magic, version, length = struct.unpack("<4sII", f.read(12))
        if magic != b"glTF":
            raise ValueError(f"Not a valid GLB file: {glb_path}")
        chunk_len, chunk_type = struct.unpack("<I4s", f.read(8))
        if chunk_type != b"JSON":
            raise ValueError(f"Missing JSON chunk in GLB: {glb_path}")
        raw = f.read(chunk_len)
    return json.loads(raw.decode("utf-8"))


def audit_one(module_id: str, glb_path: str = None) -> dict:
    if glb_path is None:
        glb_path = os.path.join(OUT_GLB_DIR, f"{module_id}.glb")
    errors = []
    warnings = []
    if not os.path.exists(glb_path):
        return {"id": module_id, "ok": False, "errors": [f"Missing GLB: {glb_path}"], "warnings": [], "tris": 0, "kb": 0.0}

    cat = category_of(module_id)
    budget = CATEGORY_BUDGETS[cat]
    kb = os.path.getsize(glb_path) / 1024.0
    gltf = parse_glb_json(glb_path)

    # 1. Zero embedded textures/images
    imgs = gltf.get("images", [])
    texs = gltf.get("textures", [])
    if imgs or texs:
        errors.append(f"Embedded textures forbidden (images={len(imgs)}, textures={len(texs)})")

    # 2. Nodes: check negative scale & collect node names
    nodes = gltf.get("nodes", [])
    node_names = set()
    for nd in nodes:
        nm = nd.get("name", "")
        node_names.add(nm)
        sc = nd.get("scale", [1.0, 1.0, 1.0])
        if any(s < 0.0 for s in sc):
            errors.append(f"Negative scale on node '{nm}': {sc}")

    # 3. Required sockets / markers
    for req in budget["req_nodes"]:
        if req not in node_names:
            errors.append(f"Missing required marker node '{req}'")

    if cat == "legs":
        has_biped = "Leg_L" in node_names and "Leg_R" in node_names
        has_multi = "Leg_0" in node_names
        has_tread = "Track_L" in node_names and "Track_R" in node_names
        if not (has_biped or has_multi or has_tread):
            errors.append("Legs module missing articulated Leg_L/Leg_R, Leg_0.., or Track_L/Track_R nodes")

    # 4. Meshes: attributes, polycount, single-surface & canonical `<Group>__<slot>` naming
    accessors = gltf.get("accessors", [])
    meshes = gltf.get("meshes", [])
    total_tris = 0
    mesh_count = len(meshes)
    req_attrs = ("POSITION", "NORMAL", "TANGENT", "TEXCOORD_0", "COLOR_0")

    for mi, m in enumerate(meshes):
        mname = m.get("name", f"mesh_{mi}")
        if "__" not in mname:
            errors.append(f"Mesh '{mname}' violates '<Group>__<mat_slot>' naming standard")
        else:
            slot = mname.split("__")[-1]
            # Blender may append .001 if duplicate names occurred across groups; strip numeric suffix when checking
            base_slot = slot.split(".")[0]
            if base_slot not in VALID_MAT_SLOTS:
                errors.append(f"Mesh '{mname}' uses unknown mat_slot '{slot}'")

        prims = m.get("primitives", [])
        if len(prims) != 1:
            errors.append(f"Mesh '{mname}' has {len(prims)} surfaces (standard requires 1 surface per mesh for material_override)")

        for pi, pr in enumerate(prims):
            attrs = pr.get("attributes", {})
            missing = [a for a in req_attrs if a not in attrs]
            if missing:
                errors.append(f"Mesh '{mname}' prim[{pi}] missing vertex attributes: {missing}")
            if "indices" in pr:
                idx_acc = accessors[pr["indices"]]
                total_tris += int(idx_acc["count"]) // 3
            elif "POSITION" in attrs:
                pos_acc = accessors[attrs["POSITION"]]
                total_tris += int(pos_acc["count"]) // 3

    # 5. Polycount & file-size budgets
    if total_tris < budget["min_tris"]:
        warnings.append(f"Low polycount {total_tris} < min {budget['min_tris']} (verify detail density)")
    if total_tris > budget["max_tris"]:
        errors.append(f"Polycount {total_tris} exceeds category max {budget['max_tris']}")
    if kb > budget["max_kb"]:
        errors.append(f"File size {kb:.1f} KB exceeds category max {budget['max_kb']:.1f} KB")

    return {
        "id": module_id,
        "cat": cat,
        "ok": len(errors) == 0,
        "tris": total_tris,
        "meshes": mesh_count,
        "kb": round(kb, 1),
        "errors": errors,
        "warnings": warnings,
    }


def main():
    if len(sys.argv) > 1:
        ids = sys.argv[1:]
    else:
        if not os.path.isdir(OUT_GLB_DIR):
            print("[AUDIT] No GLB directory found:", OUT_GLB_DIR)
            sys.exit(1)
        ids = sorted(os.path.splitext(fn)[0] for fn in os.listdir(OUT_GLB_DIR) if fn.endswith(".glb"))

    if not ids:
        print("[AUDIT] No GLBs to audit.")
        sys.exit(0)

    failed = 0
    total_tris = 0
    total_kb = 0.0
    print(f"{'MODULE':<26} {'CAT':<5} {'TRIS':>7} {'MESH':>5} {'SIZE_KB':>8}  STATUS")
    print("-" * 72)
    for mid in ids:
        res = audit_one(mid)
        total_tris += res["tris"]
        total_kb += res["kb"]
        status = "PASS" if res["ok"] else "FAIL"
        if not res["ok"]:
            failed += 1
        print(f"{mid:<26} {res.get('cat','?'):<5} {res['tris']:>7} {res.get('meshes',0):>5} {res['kb']:>8.1f}  {status}")
        for w in res["warnings"]:
            print(f"   [WARN] {w}")
        for e in res["errors"]:
            print(f"   [ERR ] {e}")
    print("-" * 72)
    print(f"Audited {len(ids)} GLBs: {len(ids) - failed} PASS, {failed} FAIL | total={total_tris:,} tris, {total_kb/1024.0:.2f} MB")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
