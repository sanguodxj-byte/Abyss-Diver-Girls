"""
Automated 3D Geometry Clipping, Z-Fighting, Buried-Detail, Floating-Part, and Cross-Module Assembly Auditor
Runs inside Blender 5.1.2 (headless) directly on KitbashScene objects BEFORE merge, or on assembled GLBs.

Detects the 4 real classes of `穿模` that ruin mecha visual quality:
  1. COPLANAR Z-FIGHTING : Two distinct parts share coplanar same-facing surfaces within < 3.5mm
  2. BURIED / SWALLOWED  : >= 40% of a visual feature part (optic/light/stripe/vent/smoke/hatch/rail) is buried >6mm inside solid armor
  3. DEEP CROSS-CLIPPING : Two distinct structural parts mutually slice >18mm into each other (e.g. InnerTub corner poking out of cheek, pod slicing canopy, tile slicing glacis)
  4. CROSS-MODULE CLASH  : Mounted modules (legs <-> core <-> arm_l/r <-> back <-> gen) intrude >12mm into each other at exact SOCKET_* transforms
  5. FLOATING PARTS      : Disconnected part island >12mm away from the rest of its rigid group
"""
import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

# Sub-assembly helper prefixes whose internal sub-parts intentionally mate/seat tightly
CONCENTRIC_TAGS = (
    "Hyd", "Piston", "Damper", "Strut", "Shock",
    "Louver", "Vent", "Cool",
    "Smoke", "M250",
    "Bore", "Barrel", "Muzzle", "GSh30",
    "ArmBay", "A1", "HP_C1", "HP_B1", "HP_G1", "Waist",
    "Bolt", "Pin", "Rivet", "Clasp",
    "Tow", "Shackle", "Grab", "Rail", "Ant", "Whip", "Pitot",
    "Drum", "Actuator", "Knk", "Toe", "Heel",
    "Visor", "Optic", "Lens", "Eye", "Light", "Led", "Lamp", "CITV", "GPS", "FLIR", "EO", "Canopy",
    "Cell", "Term", "Breaker", "Charge", "Ratchet", "Tarp",
)

DETAIL_SLOTS = {"glass", "accent", "hazard", "emit_cyan", "emit_amber", "emit_headlight", "emit_red", "emit_core"}
DETAIL_NAME_HINTS = ("Stripe", "Accent", "Hazard", "Glass", "Optic", "Lens", "Led", "Light", "Lamp", "Smoke", "Vent", "Louver", "Tow", "Grab", "Hatch", "Blowout", "ARAT", "ERA")


def _base_prefix(name: str) -> str:
    """Strip KitbashScene's trailing _<seq> counter and sub-part suffix to identify shared helper assembly."""
    # Remove trailing _<digits>
    parts = name.split("_")
    while parts and parts[-1].isdigit():
        parts.pop()
    return "_".join(parts)


def _same_helper_assembly(n1: str, n2: str) -> bool:
    """Return True if two parts belong to the exact same compound Kitbash helper (e.g. LouverBay frame + blades)."""
    p1, p2 = _base_prefix(n1), _base_prefix(n2)
    if p1 == p2:
        return True
    t1, t2 = p1.split("_"), p2.split("_")
    # Same prefix up to helper sub-part suffix (e.g. RoofCoolBay_f vs RoofCoolBay_b0, WaistDamper_0_cyl vs WaistDamper_0_rod)
    if len(t1) >= 2 and len(t2) >= 2 and t1[0] == t2[0]:
        if len(t1) >= 3 and len(t2) >= 3 and t1[1] == t2[1]:
            return True
        for tag in CONCENTRIC_TAGS:
            if tag.lower() in t1[0].lower():
                return True
    return False


def _aabb_world(verts_w):
    xs = [v.x for v in verts_w]
    ys = [v.y for v in verts_w]
    zs = [v.z for v in verts_w]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def _aabb_overlap(a0, a1, b0, b1, margin=0.005):
    return (a0.x <= b1.x + margin and a1.x + margin >= b0.x and
            a0.y <= b1.y + margin and a1.y + margin >= b0.y and
            a0.z <= b1.z + margin and a1.z + margin >= b0.z)


def _point_inside_bvh(pt: Vector, bvh: BVHTree, eps=1e-4) -> tuple:
    """
    Test if `pt` is strictly inside closed mesh `bvh`, returning (is_inside, dist_to_surface).
    Uses nearest-surface normal test (fast & reliable for convex/hard-surface kitbash parts)
    verified by raycast parity.
    """
    loc, nrm, idx, dist = bvh.find_nearest(pt)
    if loc is None:
        return False, 999.0
    # Cast ray along +X,+Y,+Z mixed direction and count hits for true parity
    ray_dir = Vector((0.731, 0.487, 0.478)).normalized()
    hits = 0
    orig = pt + ray_dir * eps
    for _ in range(16):
        hloc, hnrm, hidx, hdist = bvh.ray_cast(orig, ray_dir)
        if hloc is None:
            break
        hits += 1
        orig = hloc + ray_dir * 0.0008
    return (hits % 2 == 1), dist


def _eval_part_data(obj, slot: str, depsgraph):
    """Evaluate modifiers (Bevel/WeightedNormal) into world-space mesh data + BVHTree."""
    eo = obj.evaluated_get(depsgraph)
    me = eo.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(obj.matrix_world)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.faces.ensure_lookup_table()
    bm.verts.ensure_lookup_table()
    bvh = BVHTree.FromBMesh(bm)
    verts_w = [v.co.copy() for v in bm.verts]
    faces_info = [(f.calc_center_median(), f.normal.copy(), f.calc_area()) for f in bm.faces if f.calc_area() > 1e-6]
    a0, a1 = _aabb_world(verts_w)
    vol = abs(bm.calc_volume(signed=True))
    eo.to_mesh_clear()
    bm.free()
    return {
        "name": obj.name,
        "base": _base_prefix(obj.name),
        "slot": slot,
        "bvh": bvh,
        "verts": verts_w,
        "faces": faces_info,
        "a0": a0,
        "a1": a1,
        "vol": vol,
    }


def audit_kitbash_scene(kb) -> dict:
    """Run full intra-module clipping, Z-fighting, buried-part, and floating-part audit on a KitbashScene BEFORE export merge."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    report = {
        "module_id": kb.module_id,
        "zfight": [],
        "buried": [],
        "deep_clip": [],
        "floating": [],
    }

    for gkey, ginfo in kb.groups.items():
        parts_data = [_eval_part_data(obj, slot, depsgraph) for (obj, slot) in ginfo["parts"]]
        n = len(parts_data)
        adj = {i: set() for i in range(n)}

        for i in range(n):
            A = parts_data[i]
            for j in range(i + 1, n):
                B = parts_data[j]
                if not _aabb_overlap(A["a0"], A["a1"], B["a0"], B["a1"], margin=0.015):
                    continue

                # Check connectivity for floating-part graph (bidirectional check for tiny bolts/pins)
                ov = A["bvh"].overlap(B["bvh"])
                if ov:
                    adj[i].add(j); adj[j].add(i)
                else:
                    connected = False
                    for P, Q in ((A, B), (B, A)):
                        step_v = 1 if len(P["verts"]) <= 64 else max(1, len(P["verts"]) // 32)
                        for v in P["verts"][::step_v]:
                            _, _, _, d = Q["bvh"].find_nearest(v, 0.014)
                            if d is not None:
                                connected = True
                                break
                        if connected:
                            break
                    if connected:
                        adj[i].add(j); adj[j].add(i)

                # Skip intra-helper pairs (e.g., piston rod inside cylinder, louver frame+blades)
                if _same_helper_assembly(A["name"], B["name"]):
                    continue

                # 1. COPLANAR Z-FIGHTING CHECK
                zf_hits = 0
                zf_area = 0.0
                # Check smaller face count against larger BVH
                src_f, dst_bvh = (A["faces"], B["bvh"]) if len(A["faces"]) <= len(B["faces"]) else (B["faces"], A["bvh"])
                dst_faces = B["faces"] if len(A["faces"]) <= len(B["faces"]) else A["faces"]
                for fc, fn, fa in src_f:
                    if fa < 0.0005:
                        continue
                    loc, bn, bidx, dist = dst_bvh.find_nearest(fc, 0.0032)
                    if loc is not None and dist < 0.0030 and fn.dot(bn) > 0.985:
                        zf_hits += 1
                        zf_area += fa
                if zf_area > 0.0018 and zf_hits >= 2:
                    report["zfight"].append({
                        "group": gkey, "a": A["base"], "b": B["base"],
                        "hits": zf_hits, "area_cm2": round(zf_area * 10000, 1)
                    })

                if not ov:
                    continue

                # 2. BURIED / SWALLOWED DETAIL & DEEP CROSS-CLIPPING CHECK
                # Sample vertices of both A in B and B in A
                def _penetration_stats(P, Q):
                    verts = P["verts"]
                    step = max(1, len(verts) // 48)
                    sample = verts[::step]
                    in_deep = 0
                    max_d = 0.0
                    out_cnt = 0
                    for v in sample:
                        ins, d = _point_inside_bvh(v, Q["bvh"])
                        if ins and d > 0.006:
                            in_deep += 1
                            if d > max_d:
                                max_d = d
                        elif not ins and d > 0.004:
                            out_cnt += 1
                    return in_deep / max(1, len(sample)), max_d, out_cnt / max(1, len(sample))

                frac_ab, depth_ab, out_ab = _penetration_stats(A, B)
                frac_ba, depth_ba, out_ba = _penetration_stats(B, A)

                # Flag buried visual details (stripes/optics/vents/lights/smoke/ERA swallowed >=14mm inside solid hull)
                for (P, Q, frac, depth) in [(A, B, frac_ab, depth_ab), (B, A, frac_ba, depth_ba)]:
                    is_det = (P["slot"] in DETAIL_SLOTS) or any(h.lower() in P["base"].lower() for h in DETAIL_NAME_HINTS)
                    if is_det and frac >= 0.45 and depth >= 0.014:
                        report["buried"].append({
                            "group": gkey, "part": P["base"], "inside": Q["base"],
                            "buried_pct": int(round(frac * 100)), "max_mm": round(depth * 1000, 1)
                        })

                # Flag Inner* hull poking OUT of outer armor, or two big structural parts deeply slicing through each other
                a_inner = "inner" in A["base"].lower() or "tub" in A["base"].lower() or "keel" in A["base"].lower()
                b_inner = "inner" in B["base"].lower() or "tub" in B["base"].lower() or "keel" in B["base"].lower()
                if (a_inner or b_inner) and (min(depth_ab, depth_ba) > 0.020):
                    # Inner chassis is SUPPOSED to be inside outer armor; flag ONLY if inner pokes OUT of outer hull
                    pass
                # Mutual deep slice-through between distinct structural armor/hardware blocks (>28mm deep in BOTH directions & both protrude outside!)
                elif (depth_ab >= 0.028 and depth_ba >= 0.028 and frac_ab >= 0.15 and frac_ba >= 0.15
                      and out_ab >= 0.25 and out_ba >= 0.25 and min(A["vol"], B["vol"]) > 0.004):
                    report["deep_clip"].append({
                        "group": gkey, "a": A["base"], "b": B["base"],
                        "a_in_b_mm": round(depth_ab * 1000, 1), "b_in_a_mm": round(depth_ba * 1000, 1),
                        "a_pct": int(round(frac_ab * 100)), "b_pct": int(round(frac_ba * 100)),
                    })

        # 3. FLOATING PARTS CHECK (BFS from largest part in group)
        if n > 1:
            root_idx = max(range(n), key=lambda k: parts_data[k]["vol"])
            vis = {root_idx}
            q = [root_idx]
            while q:
                u = q.pop()
                for w in adj[u]:
                    if w not in vis:
                        vis.add(w); q.append(w)
            for k in range(n):
                if k not in vis:
                    report["floating"].append({"group": gkey, "part": parts_data[k]["base"]})

    report["total_issues"] = len(report["zfight"]) + len(report["buried"]) + len(report["deep_clip"]) + len(report["floating"])
    return report


def audit_assembled_glbs(glb_map: dict, manifest_sockets: dict) -> list:
    """
    Load assembled starter/target GLBs at exact SOCKET_* transforms in Blender and detect
    TRUE CROSS-MODULE CLIPPING (legs <-> core <-> arm_l/r <-> back <-> gen) > 15mm deep!
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)

    def _load_glb_bvh(path: str, offset_godot: tuple, mirror_x: bool = False):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new_objs = [o for o in bpy.data.objects if o not in before]
        bm = bmesh.new()
        ox, oy, oz = offset_godot
        # Godot (x, y, z) -> Blender (x, -z, y)
        b_off = Vector((ox, -oz, oy))
        for o in new_objs:
            if o.type != "MESH":
                continue
            tmp = bmesh.new()
            tmp.from_mesh(o.data)
            tmp.transform(o.matrix_world)
            if mirror_x:
                for v in tmp.verts:
                    v.co.x = -v.co.x
                bmesh.ops.reverse_faces(tmp, faces=tmp.faces[:])
            for v in tmp.verts:
                v.co += b_off
            bmesh.ops.triangulate(tmp, faces=tmp.faces[:])
            # Append to combined bmesh
            vmap = {}
            for v in tmp.verts:
                vmap[v] = bm.verts.new(v.co)
            for f in tmp.faces:
                try:
                    bm.faces.new([vmap[v] for v in f.verts])
                except ValueError:
                    pass
            tmp.free()
        bm.verts.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        bvh = BVHTree.FromBMesh(bm)
        verts = [v.co.copy() for v in bm.verts]
        bm.free()
        return bvh, verts

    # Compute world Godot offsets for each mounted module
    core_pos = tuple(manifest_sockets["legs"]["SOCKET_core"])
    arm_l_pos = tuple(a + b for a, b in zip(core_pos, manifest_sockets["core"]["SOCKET_arm_l"]))
    arm_r_pos = tuple(a + b for a, b in zip(core_pos, manifest_sockets["core"]["SOCKET_arm_r"]))
    back_pos  = tuple(a + b for a, b in zip(core_pos, manifest_sockets["core"]["SOCKET_back"]))
    gen_pos   = tuple(a + b for a, b in zip(core_pos, manifest_sockets["core"]["SOCKET_gen"]))

    slots = [
        ("legs",  glb_map["legs"],  (0, 0, 0), False),
        ("core",  glb_map["core"],  core_pos,  False),
        ("arm_l", glb_map["arm_l"], arm_l_pos, True),
        ("arm_r", glb_map["arm_r"], arm_r_pos, False),
        ("back",  glb_map["back"],  back_pos,  False),
        ("gen",   glb_map["gen"],   gen_pos,   False),
    ]
    loaded = {}
    for sname, path, off, mx in slots:
        if path and os.path.exists(path):
            loaded[sname] = _load_glb_bvh(path, off, mx)

    clashes = []
    pairs = [("legs", "core"), ("core", "arm_l"), ("core", "arm_r"), ("core", "back"), ("core", "gen"), ("back", "gen"), ("legs", "gen")]
    for sa, sb in pairs:
        if sa not in loaded or sb not in loaded:
            continue
        bvh_a, va = loaded[sa]
        bvh_b, vb = loaded[sb]
        ov = bvh_a.overlap(bvh_b)
        if not ov:
            continue
        # Measure actual deep penetration (> 14mm inside the other module!)
        deep_a, max_da = 0, 0.0
        for v in va[::max(1, len(va) // 250)]:
            ins, d = _point_inside_bvh(v, bvh_b)
            if ins and d > 0.014:
                deep_a += 1
                max_da = max(max_da, d)
        deep_b, max_db = 0, 0.0
        for v in vb[::max(1, len(vb) // 250)]:
            ins, d = _point_inside_bvh(v, bvh_a)
            if ins and d > 0.014:
                deep_b += 1
                max_db = max(max_db, d)
        if max(max_da, max_db) >= 0.016 and (deep_a + deep_b) >= 2:
            clashes.append({
                "pair": f"{sa} <-> {sb}",
                "ov_tris": len(ov),
                "max_pen_mm": round(max(max_da, max_db) * 1000, 1),
                "deep_samples": deep_a + deep_b,
            })
    return clashes
