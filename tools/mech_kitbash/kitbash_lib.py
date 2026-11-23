"""
Production Industrial Hard-Surface Kitbash Library for Blender 5.1.2 (MECH_MODELING_STANDARD v1.0).
Features:
  - Godot-native coordinate helpers (-Z front, +Y up, +X right) -> Blender (+Y back, +Z up)
  - Hierarchical Rigid Groups (supports static cores/arms/backs/gens AND articulated biped/quad/hex/tread legs!)
  - Automatic 2K Trim Sheet UV band projection (planar box & cylindrical)
  - Production-grade 1-seg chamfer Bevel + Face-Weighted Normals + outward winding enforcement
  - Full-assembly 24-ray BVHTree raytraced Vertex AO (COLOR.g) + Convex Edge Wear (COLOR.r)
  - Per-(group, mat_slot) mesh merging + Triangulation with preserved custom normals -> exact MikkTSpace TANGENT
  - Zero embedded textures, positive-only scales, standard Empty sockets/markers export
"""
import math
import os
import time
import bpy
import bmesh
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

from specs import TRIM_BANDS, VALID_MAT_SLOTS, HP_C1_RADIUS, HP_C1_CORE_Y_BOT

C_G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_B2G = C_G2B.transposed()

MAT_PREVIEW_COLORS = {
    "armor":          (0.46, 0.45, 0.40, 1.0),
    "armor_sub":      (0.35, 0.34, 0.30, 1.0),
    "armor_dark":     (0.24, 0.25, 0.26, 1.0),
    "dark":           (0.14, 0.145, 0.16, 1.0),
    "gunmetal":       (0.23, 0.24, 0.26, 1.0),
    "chrome":         (0.78, 0.80, 0.84, 1.0),
    "copper":         (0.64, 0.36, 0.21, 1.0),
    "brass":          (0.60, 0.48, 0.23, 1.0),
    "rubber":         (0.085, 0.09, 0.095, 1.0),
    "hazard":         (0.95, 0.95, 0.95, 1.0),
    "accent":         (0.64, 0.52, 0.19, 1.0),
    "bore":           (0.015, 0.015, 0.018, 1.0),
    "glass":          (0.18, 0.42, 0.38, 1.0),
    "emit_headlight": (1.0, 0.94, 0.80, 1.0),
    "emit_amber":     (0.95, 0.70, 0.20, 1.0),
    "emit_cyan":      (0.25, 0.85, 0.68, 1.0),
    "emit_red":       (0.92, 0.22, 0.18, 1.0),
    "emit_core":      (0.30, 0.80, 0.95, 1.0),
}


def g2b(x, y, z) -> Vector:
    return Vector((x, -z, y))


def g2b_mat(pos=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0)) -> Matrix:
    rx, ry, rz = [math.radians(a) for a in rot_deg]
    R_g = Euler((rx, ry, rz), "YXZ").to_matrix().to_4x4()
    return C_G2B @ (Matrix.Translation(Vector(pos)) @ R_g) @ C_B2G


def g2b_bone_mat(a, b) -> Matrix:
    """Equivalent to kit.gd K.bone(a, b): origin at a, local -Y points along (b - a), +X right."""
    va, vb = Vector(a), Vector(b)
    y = (va - vb).normalized()
    x = Vector((1.0, 0.0, 0.0))
    if abs(y.dot(x)) > 0.98:
        x = Vector((0.0, 0.0, 1.0))
    z = x.cross(y).normalized()
    x = y.cross(z).normalized()
    M_g = Matrix((
        (x.x, y.x, z.x, va.x),
        (x.y, y.y, z.y, va.y),
        (x.z, y.z, z.z, va.z),
        (0.0, 0.0, 0.0, 1.0),
    ))
    return C_G2B @ M_g @ C_B2G


def crect_2d(w: float, h: float, cuts=(0.0, 0.0, 0.0, 0.0)):
    """Chamfered rectangle 2D polygon in Godot XY plane: cuts=[TL, TR, BR, BL]."""
    x, y = w * 0.5, h * 0.5
    corners = [(-x, y), (x, y), (x, -y), (-x, -y)]
    out = []
    for i in range(4):
        cc = float(cuts[i])
        px, py = corners[i]
        if cc <= 1e-5:
            out.append((px, py))
            continue
        p0 = Vector(corners[(i + 3) % 4])
        p1 = Vector((px, py))
        p2 = Vector(corners[(i + 1) % 4])
        a = p1 + (p0 - p1).normalized() * cc
        b = p1 + (p2 - p1).normalized() * cc
        out.append((a.x, a.y))
        out.append((b.x, b.y))
    return out


def trap_2d(wb: float, wt: float, h: float, cut: float = 0.0):
    """Trapezoid 2D polygon in Godot XY plane: bottom width wb, top width wt, height h."""
    corners = [(-wt * 0.5, h * 0.5), (wt * 0.5, h * 0.5), (wb * 0.5, -h * 0.5), (-wb * 0.5, -h * 0.5)]
    if cut <= 1e-5:
        return corners
    out = []
    for i in range(4):
        p0 = Vector(corners[(i + 3) % 4])
        p1 = Vector(corners[i])
        p2 = Vector(corners[(i + 1) % 4])
        a = p1 + (p0 - p1).normalized() * cut
        b = p1 + (p2 - p1).normalized() * cut
        out.append((a.x, a.y))
        out.append((b.x, b.y))
    return out


def _assign_box_uv(bm, band_key, tile_u=1.0, tile_v=1.0):
    u0, v0, u1, v1 = TRIM_BANDS[band_key]
    du, dv = u1 - u0, v1 - v0
    uv_layer = bm.loops.layers.uv.verify()
    if not bm.verts:
        return
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    min_v = Vector((min(xs), min(ys), min(zs)))
    span = Vector((max(max(xs) - min(xs), 1e-4), max(max(ys) - min(ys), 1e-4), max(max(zs) - min(zs), 1e-4)))
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            p = loop.vert.co - min_v
            if az >= ax and az >= ay:
                nu = (p.x / span.x) * tile_u
                nv = (p.y / span.y) * tile_v
            elif ay >= ax:
                nu = (p.x / span.x) * tile_u
                nv = 1.0 - (p.z / span.z) * tile_v
            else:
                nu = (p.y / span.y) * tile_u
                nv = 1.0 - (p.z / span.z) * tile_v
            nu = max(0.0, min(1.0, nu))
            nv = max(0.0, min(1.0, nv))
            loop[uv_layer].uv = (u0 + nu * du, 1.0 - (v0 + nv * dv))


def _assign_cyl_uv(bm, band_key, u_repeats=1.0):
    u0, v0, u1, v1 = TRIM_BANDS[band_key]
    du, dv = u1 - u0, v1 - v0
    uv_layer = bm.loops.layers.uv.verify()
    zs = [v.co.z for v in bm.verts]
    zmin, zspan = min(zs), max(max(zs) - min(zs), 1e-4)
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            ang = (math.atan2(co.y, co.x) / math.tau) % 1.0
            nu = (ang * u_repeats) % 1.0
            nv = max(0.0, min(1.0, 1.0 - (co.z - zmin) / zspan))
            loop[uv_layer].uv = (u0 + nu * du, 1.0 - (v0 + nv * dv))


class KitbashScene:
    """
    Clean per-module Blender scene context supporting hierarchical rigid groups,
    reusable Kitbash hardware assemblies, full-scene 24-ray BVH AO, and standard GLB export.
    """

    def __init__(self, module_id: str, ao_rays: int = 24, ao_dist: float = 0.45):
        self.module_id = module_id
        self.ao_rays = ao_rays
        self.ao_dist = ao_dist
        self.t0 = time.perf_counter()

        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.scene = bpy.context.scene
        self.col = self.scene.collection

        # Material registry (preview colors only; Godot replaces with shared mech_trim shaders)
        self.mats = {}
        for slot, rgba in MAT_PREVIEW_COLORS.items():
            m = bpy.data.materials.new(name=slot)
            m.use_nodes = True
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Base Color"].default_value = rgba
            self.mats[slot] = m

        # Hierarchical rigid groups: group_key -> {"empty": obj|None, "M_world": Matrix, "parts": [(obj, mat_slot)], "leaf": str}
        self.groups = {
            "Body": {"empty": None, "M_world": Matrix.Identity(4), "parts": [], "leaf": "Body"},
        }
        self.active_group = "Body"
        self.empties = []
        self._part_seq = 0

    def add_group(self, group_key: str, leaf_name: str, pos=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0), parent_key: str = ""):
        """Create an articulated pivot group (e.g. Leg_L, Leg_L/Knee, Leg_L/Knee/Ankle) in parent Godot space."""
        M_local = g2b_mat(pos, rot_deg)
        emp = bpy.data.objects.new(leaf_name, None)
        emp.empty_display_size = 0.10
        self.col.objects.link(emp)
        if parent_key and parent_key in self.groups and self.groups[parent_key]["empty"] is not None:
            pinfo = self.groups[parent_key]
            emp.parent = pinfo["empty"]
            emp.matrix_local = M_local
            M_world = pinfo["M_world"] @ M_local
        else:
            emp.matrix_world = M_local
            M_world = M_local
        self.groups[group_key] = {"empty": emp, "M_world": M_world, "parts": [], "leaf": leaf_name}
        self.empties.append(emp)
        return group_key

    def use_group(self, group_key: str):
        assert group_key in self.groups, f"Unknown group: {group_key}"
        self.active_group = group_key

    def add_marker(self, name: str, pos=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0), parent_key: str = ""):
        """Add an Empty Socket/Muzzle/Sole marker (in parent group's Godot space, or root if parent_key=='')."""
        emp = bpy.data.objects.new(name, None)
        emp.empty_display_size = 0.08
        self.col.objects.link(emp)
        M_local = g2b_mat(pos, rot_deg)
        if parent_key and parent_key in self.groups and self.groups[parent_key]["empty"] is not None:
            emp.parent = self.groups[parent_key]["empty"]
            emp.matrix_local = M_local
        else:
            emp.matrix_world = M_local
        self.empties.append(emp)
        return emp

    def _next_name(self, prefix: str) -> str:
        self._part_seq += 1
        return f"{prefix}_{self._part_seq}"

    def _finalize(self, name, bm, mat_slot, band_key, M_local_in_group,
                  bevel_w=0.0, bevel_seg=1, cyl_uv=False, u_rep=1.0, tile_u=1.0, tile_v=1.0, group=None):
        assert mat_slot in VALID_MAT_SLOTS, f"Invalid mat_slot: {mat_slot}"
        gkey = group or self.active_group
        ginfo = self.groups[gkey]

        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        if bm.calc_volume(signed=True) < 0.0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        if cyl_uv:
            _assign_cyl_uv(bm, band_key, u_rep)
        else:
            _assign_box_uv(bm, band_key, tile_u, tile_v)

        mesh = bpy.data.meshes.new(self._next_name(name))
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(mesh.name, mesh)
        self.col.objects.link(obj)
        obj.matrix_world = ginfo["M_world"] @ M_local_in_group
        obj.data.materials.append(self.mats[mat_slot])
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))

        if bevel_w > 0.0:
            mb = obj.modifiers.new("Bevel", "BEVEL")
            mb.width = bevel_w
            mb.segments = bevel_seg
            mb.profile = 0.55
            mb.limit_method = "ANGLE"
            mb.angle_limit = math.radians(28.0)
            mb.use_clamp_overlap = True
        mw = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        mw.mode = "FACE_AREA"
        mw.weight = 50
        mw.keep_sharp = True

        ginfo["parts"].append((obj, mat_slot))
        return obj

    # --------------------------------------------------------------------------
    # PRIMITIVES (Production Standard: default bevel_seg=1, crisp 45° chamfers)
    # --------------------------------------------------------------------------
    def box(self, name, size, mat_slot, band_key, pos=(0, 0, 0), rot_deg=(0, 0, 0),
            bevel_w=0.012, bevel_seg=1, M_parent=None, tile_u=1.0, tile_v=1.0, group=None):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(size[0], size[2], size[1]), verts=bm.verts)
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        return self._finalize(name, bm, mat_slot, band_key, M, bevel_w, bevel_seg, False, 1.0, tile_u, tile_v, group)

    def plate(self, name, outline_xy, thick, mat_slot, band_key, pos=(0, 0, 0), rot_deg=(0, 0, 0),
              bevel_w=0.012, bevel_seg=1, M_parent=None, tile_u=1.0, tile_v=1.0, group=None):
        """Extrude a 2D Godot XY polygon along local Z by `thick` (centered at z=0), beveled cleanly."""
        hz = thick * 0.5
        bm = bmesh.new()
        v_front = [bm.verts.new((px, hz, py)) for (px, py) in outline_xy]   # Godot z = -hz -> Blender y = +hz
        v_back = [bm.verts.new((px, -hz, py)) for (px, py) in outline_xy]   # Godot z = +hz -> Blender y = -hz
        n = len(outline_xy)
        bm.faces.new(v_front)
        bm.faces.new(list(reversed(v_back)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((v_front[i], v_back[i], v_back[j], v_front[j]))
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        return self._finalize(name, bm, mat_slot, band_key, M, bevel_w, bevel_seg, False, 1.0, tile_u, tile_v, group)

    def loft(self, name, sections, mat_slot, band_key, pos=(0, 0, 0), rot_deg=(0, 0, 0),
             bevel_w=0.010, bevel_seg=1, M_parent=None, tile_u=1.0, tile_v=1.0, group=None):
        bm = bmesh.new()
        rings = [[bm.verts.new((gx, -gz, gy)) for (gx, gy) in pts] for gz, pts in sections]
        n = len(rings[0])
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
        for k in range(len(rings) - 1):
            r0, r1 = rings[k], rings[k + 1]
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((r0[i], r1[i], r1[j], r0[j]))
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        return self._finalize(name, bm, mat_slot, band_key, M, bevel_w, bevel_seg, False, 1.0, tile_u, tile_v, group)

    def lathe(self, name, prof_rz, segs, mat_slot, band_key, pos=(0, 0, 0), rot_deg=(0, 0, 0),
              M_parent=None, u_rep=1.0, group=None):
        bm = bmesh.new()
        rings = []
        for r, gy in prof_rz:
            if r <= 1e-5:
                rings.append([bm.verts.new((0.0, 0.0, gy))])
            else:
                rings.append([bm.verts.new((math.cos(math.tau * i / segs) * r,
                                            math.sin(math.tau * i / segs) * r, gy)) for i in range(segs)])
        for k in range(len(rings) - 1):
            r0, r1 = rings[k], rings[k + 1]
            if len(r0) == 1 and len(r1) > 1:
                for i in range(segs):
                    bm.faces.new((r0[0], r1[(i + 1) % segs], r1[i]))
            elif len(r0) > 1 and len(r1) == 1:
                for i in range(segs):
                    bm.faces.new((r0[i], r0[(i + 1) % segs], r1[0]))
            elif len(r0) > 1 and len(r1) > 1:
                for i in range(segs):
                    j = (i + 1) % segs
                    bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        return self._finalize(name, bm, mat_slot, band_key, M, 0.0, 1, True, u_rep, 1.0, 1.0, group)

    def cyl(self, name, r_top, r_bot, h, segs, mat_slot, band_key, pos=(0, 0, 0), rot_deg=(0, 0, 0),
            chamf=0.005, hollow_r=0.0, M_parent=None, u_rep=1.0, group=None):
        hh = h * 0.5
        c = min(chamf, h * 0.22, min(r_top, r_bot) * 0.35)
        if hollow_r > 0.001:
            prof = [
                (hollow_r, -hh), (r_bot - c, -hh), (r_bot, -hh + c),
                (r_top, hh - c), (r_top - c, hh),
                (hollow_r + c * 0.35, hh), (hollow_r, hh - c * 0.35), (hollow_r, -hh),
            ]
        else:
            prof = [
                (0.0, -hh), (r_bot - c, -hh), (r_bot, -hh + c),
                (r_top, hh - c), (r_top - c, hh), (0.0, hh),
            ]
        return self.lathe(name, prof, segs, mat_slot, band_key, pos, rot_deg, M_parent, u_rep, group)

    def tube_path(self, name, pts_godot, r, segs=8, mat_slot="gunmetal", band_key="braid_hose",
                  add_clamps=True, clamp_mat="gunmetal", M_parent=None, group=None):
        """Smooth Catmull-Rom hydraulic hose / copper pipe sweep with optional P-clamps."""
        pts = [Vector(p) for p in pts_godot]
        dense = []
        sub = 5
        for i in range(len(pts) - 1):
            p0 = pts[max(0, i - 1)]
            p1 = pts[i]
            p2 = pts[i + 1]
            p3 = pts[min(len(pts) - 1, i + 2)]
            for s in range(sub if i < len(pts) - 2 else sub + 1):
                t = s / sub
                t2, t3 = t * t, t * t * t
                p = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
                dense.append(g2b(p.x, p.y, p.z))

        bm = bmesh.new()
        uv_layer = bm.loops.layers.uv.verify()
        u0, v0, u1, v1 = TRIM_BANDS[band_key]
        du, dv = u1 - u0, v1 - v0
        rings = []
        for k, pt in enumerate(dense):
            tang = (dense[min(k + 1, len(dense) - 1)] - dense[max(k - 1, 0)]).normalized()
            ref = Vector((0, 0, 1)) if abs(tang.z) < 0.9 else Vector((1, 0, 0))
            bx = tang.cross(ref).normalized()
            by = tang.cross(bx).normalized()
            rings.append([bm.verts.new(pt + (bx * math.cos(math.tau * i / segs) + by * math.sin(math.tau * i / segs)) * r)
                          for i in range(segs)])
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
        for k in range(len(rings) - 1):
            r0, r1 = rings[k], rings[k + 1]
            nv0, nv1 = k / max(1, len(rings) - 1), (k + 1) / max(1, len(rings) - 1)
            for i in range(segs):
                j = (i + 1) % segs
                f = bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
                nu0, nu1 = i / segs, (i + 1) / segs
                for lp, (su, sv) in zip(f.loops, [(nu0, nv0), (nu1, nv0), (nu1, nv1), (nu0, nv1)]):
                    lp[uv_layer].uv = (u0 + su * du, 1.0 - (v0 + sv * dv))

        M = M_parent if M_parent is not None else Matrix.Identity(4)
        self._finalize(name, bm, mat_slot, band_key, M, 0.0, 1, False, 1.0, 1.0, 1.0, group)

        if add_clamps and len(pts) >= 3:
            for ci in range(1, len(pts) - 1):
                p = pts[ci]
                self.box(f"{name}_cl{ci}", (r * 3.1, r * 2.6, r * 3.1), clamp_mat, "bolt_flange",
                         (p.x, p.y, p.z), (0, 0, 0), 0.003, 1, M_parent=M_parent, group=group)

    # --------------------------------------------------------------------------
    # REUSABLE INDUSTRIAL HARD-SURFACE KITBASH ASSEMBLIES (24+ ASSEMBLIES)
    # --------------------------------------------------------------------------
    def spaced_armor_plate(self, prefix, size, mat_slot, band_key, pos, rot_deg=(0, 0, 0),
                           standoffs=True, bolts=True, M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        sx, sy, sz = size
        if standoffs:
            self.box(f"{prefix}_sub", (sx * 0.88, sy * 0.86, sz * 0.65), "dark", "frame_cnc",
                     (0, 0, sz * 0.42), (0, 0, 0), 0.007, 1, M_parent=M, group=group)
        self.box(f"{prefix}_out", (sx, sy, sz), mat_slot, band_key,
                 (0, 0, 0), (0, 0, 0), min(0.015, sz * 0.26), 1, M_parent=M, group=group)
        if standoffs and bolts:
            bx, by = sx * 0.40, sy * 0.36
            for bi, (ox, oy) in enumerate([(-bx, -by), (bx, -by), (bx, by), (-bx, by)]):
                self.cyl(f"{prefix}_b{bi}", 0.010, 0.012, 0.016, 6, "chrome", "plain_metal",
                         (ox, oy, -sz * 0.5 - 0.003), (90, 0, 0), 0.002, M_parent=M, group=group)

    def hydraulic(self, prefix, p_from, p_to, r=0.022, M_parent=None, group=None):
        a, b = Vector(p_from), Vector(p_to)
        mid = (a + b) * 0.5
        d = b - a
        L = max(d.length, 0.02)
        up_g = d.normalized()
        ref = Vector((0, 0, 1)) if abs(up_g.z) < 0.9 else Vector((1, 0, 0))
        xg = up_g.cross(ref).normalized()
        zg = xg.cross(up_g).normalized()
        M = C_G2B @ Matrix((
            (xg.x, up_g.x, zg.x, mid.x),
            (xg.y, up_g.y, zg.y, mid.y),
            (xg.z, up_g.z, zg.z, mid.z),
            (0.0, 0.0, 0.0, 1.0),
        )) @ C_B2G
        if M_parent is not None:
            M = M_parent @ M
        self.cyl(f"{prefix}_cyl", r * 1.75, r * 1.75, L * 0.46, 12, "gunmetal", "plain_metal", (0, -L * 0.21, 0), (0, 0, 0), 0.004, M_parent=M, group=group)
        self.cyl(f"{prefix}_boot", r * 1.92, r * 1.85, L * 0.22, 12, "rubber", "dust_boot", (0, L * 0.08, 0), (0, 0, 0), 0.003, M_parent=M, u_rep=2.0, group=group)
        self.cyl(f"{prefix}_seal", r * 2.05, r * 2.05, 0.026, 12, "brass", "gear_collar", (0, -L * 0.01, 0), (0, 0, 0), 0.003, M_parent=M, group=group)
        self.cyl(f"{prefix}_rod", r * 0.92, r * 0.92, L * 0.90, 10, "chrome", "plain_metal", (0, 0.0, 0), (0, 0, 0), 0.002, M_parent=M, group=group)
        for si, e in enumerate([-1.0, 1.0]):
            self.box(f"{prefix}_cl{si}", (r * 3.1, r * 2.5, r * 2.5), "dark", "bolt_flange", (0, e * L * 0.48, 0), (0, 0, 0), 0.004, 1, M_parent=M, group=group)
            self.cyl(f"{prefix}_pn{si}", r * 0.65, r * 0.65, r * 3.5, 8, "chrome", "plain_metal", (0, e * L * 0.48, 0), (0, 0, 90), 0.002, M_parent=M, group=group)

    def actuator_drum(self, prefix, pos, r, w, M_parent=None, group=None):
        """Heavy joint drum along X axis: ribbed housing + twin flanges + chrome axle cap + 8 bolts."""
        M = g2b_mat(pos, (0, 0, 0))
        if M_parent is not None:
            M = M_parent @ M
        segs = 18 if r >= 0.16 else 14
        self.cyl(f"{prefix}_body", r, r, w, segs, "dark", "frame_cnc", (0, 0, 0), (0, 0, 90), 0.008, M_parent=M, group=group)
        self.cyl(f"{prefix}_rib", r * 1.06, r * 1.06, w * 0.34, segs, "gunmetal", "gear_collar", (0, 0, 0), (0, 0, 90), 0.005, M_parent=M, u_rep=2.0, group=group)
        for si, sx in enumerate([-1.0, 1.0]):
            self.cyl(f"{prefix}_fl{si}", r * 1.10, r * 1.10, w * 0.14, segs, "gunmetal", "bolt_flange", (sx * w * 0.47, 0, 0), (0, 0, 90), 0.005, M_parent=M, u_rep=2.0, group=group)
            self.cyl(f"{prefix}_ax{si}", r * 0.46, r * 0.42, w * 0.14, 12, "chrome", "plain_metal", (sx * (w * 0.50 + 0.025), 0, 0), (0, 0, 90), 0.004, M_parent=M, group=group)
            for bi in range(8):
                a = math.tau * bi / 8.0
                self.cyl(f"{prefix}_b{si}_{bi}", 0.013, 0.015, 0.024, 6, "chrome", "plain_metal",
                         (sx * (w * 0.52 + 0.012), math.cos(a) * r * 0.78, math.sin(a) * r * 0.78), (0, 0, 90), 0.002, M_parent=M, group=group)

    def bolt_ring(self, prefix, r, n_bolts, bolt_r=0.012, pos=(0, 0, 0), rot_deg=(90, 0, 0), M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        for i in range(n_bolts):
            a = math.tau * i / n_bolts
            self.cyl(f"{prefix}_b{i}", bolt_r, bolt_r * 1.15, bolt_r * 1.5, 6, "chrome", "plain_metal",
                     (math.cos(a) * r, 0.0, math.sin(a) * r), (0, 0, 0), 0.002, M_parent=M, group=group)

    def grab_rail(self, prefix, w, d, pos, rot_deg=(0, 0, 0), r=0.011, M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        self.cyl(f"{prefix}_bar", r, r, w, 8, "gunmetal", "plain_metal", (0, 0, -d), (0, 0, 90), 0.002, M_parent=M, group=group)
        for i, sx in enumerate([-w * 0.5 + r, w * 0.5 - r]):
            self.cyl(f"{prefix}_l{i}", r, r, d, 8, "gunmetal", "plain_metal", (sx, 0, -d * 0.5), (90, 0, 0), 0.002, M_parent=M, group=group)
            self.cyl(f"{prefix}_f{i}", r * 1.75, r * 1.75, 0.014, 6, "dark", "plain_metal", (sx, 0, -0.007), (90, 0, 0), 0.002, M_parent=M, group=group)

    def louver_bay(self, prefix, w, h, d, pos, rot_deg=(0, 0, 0), blades=5, mesh_style=False, M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        ft = 0.024
        self.box(f"{prefix}_ft", (w + ft * 2, ft, d), "gunmetal", "bolt_flange", (0, h * 0.5 + ft * 0.5, 0), (0, 0, 0), 0.004, 1, M_parent=M, group=group)
        self.box(f"{prefix}_fb", (w + ft * 2, ft, d), "gunmetal", "bolt_flange", (0, -h * 0.5 - ft * 0.5, 0), (0, 0, 0), 0.004, 1, M_parent=M, group=group)
        self.box(f"{prefix}_fl", (ft, h, d), "gunmetal", "bolt_flange", (-w * 0.5 - ft * 0.5, 0, 0), (0, 0, 0), 0.004, 1, M_parent=M, group=group)
        self.box(f"{prefix}_fr", (ft, h, d), "gunmetal", "bolt_flange", (w * 0.5 + ft * 0.5, 0, 0), (0, 0, 0), 0.004, 1, M_parent=M, group=group)
        bkey = "vent_mesh" if mesh_style else "vent_louver"
        self.box(f"{prefix}_core", (w, h, 0.016), "dark", bkey, (0, 0, d * 0.30), (0, 0, 0), 0.002, 1, M_parent=M, group=group)
        if not mesh_style:
            for i in range(blades):
                by = -h * 0.40 + (h * 0.80) * i / max(1, blades - 1)
                self.box(f"{prefix}_sl{i}", (w * 0.96, 0.010, d * 0.72), "gunmetal", "plain_metal", (0, by, 0), (-34, 0, 0), 0.002, 1, M_parent=M, group=group)
        else:
            for si, sx in enumerate([-w * 0.26, 0.0, w * 0.26]):
                self.box(f"{prefix}_rb{si}", (0.014, h * 0.96, d * 0.55), "gunmetal", "plain_metal", (sx, 0, -d * 0.10), (0, 0, 0), 0.003, 1, M_parent=M, group=group)
        for bi, (bx, by) in enumerate([(-w * 0.44, h * 0.5 + ft * 0.5), (w * 0.44, h * 0.5 + ft * 0.5),
                                       (-w * 0.44, -h * 0.5 - ft * 0.5), (w * 0.44, -h * 0.5 - ft * 0.5)]):
            self.cyl(f"{prefix}_bt{bi}", 0.009, 0.011, 0.014, 6, "chrome", "plain_metal", (bx, by, -d * 0.5 - 0.002), (90, 0, 0), 0.002, M_parent=M, group=group)

    def headlight_cage(self, prefix, pos, rot_deg=(0, 0, 0), M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        self.box(f"{prefix}_hs", (0.165, 0.095, 0.09), "dark", "frame_cnc", (0, 0, 0), (0, 0, 0), 0.009, 1, M_parent=M, group=group)
        self.box(f"{prefix}_rec", (0.135, 0.068, 0.024), "bore", "plain_metal", (0, 0, -0.036), (0, 0, 0), 0.003, 1, M_parent=M, group=group)
        self.cyl(f"{prefix}_l1", 0.027, 0.027, 0.022, 14, "emit_headlight", "plain_metal", (-0.024, 0, -0.044), (90, 0, 0), 0.003, M_parent=M, group=group)
        self.cyl(f"{prefix}_l2", 0.015, 0.015, 0.020, 12, "emit_amber", "plain_metal", (0.036, 0, -0.043), (90, 0, 0), 0.002, M_parent=M, group=group)
        for yi, sy in enumerate([-0.042, 0.042]):
            self.cyl(f"{prefix}_gh{yi}", 0.007, 0.007, 0.175, 6, "gunmetal", "plain_metal", (0, sy, -0.066), (0, 0, 90), 0.002, M_parent=M, group=group)
        for xi, sx in enumerate([-0.075, 0.0, 0.075]):
            self.cyl(f"{prefix}_gv{xi}", 0.007, 0.007, 0.090, 6, "gunmetal", "plain_metal", (sx, 0, -0.066), (0, 0, 0), 0.002, M_parent=M, group=group)
            if xi != 1:
                self.cyl(f"{prefix}_gs{xi}", 0.007, 0.007, 0.052, 6, "gunmetal", "plain_metal", (sx, 0.042, -0.040), (90, 0, 0), 0.002, M_parent=M, group=group)
                self.cyl(f"{prefix}_gb{xi}", 0.007, 0.007, 0.052, 6, "gunmetal", "plain_metal", (sx, -0.042, -0.040), (90, 0, 0), 0.002, M_parent=M, group=group)

    def eoir_gimbal(self, prefix, pos, M_parent=None, group=None):
        M = g2b_mat(pos, (0, 0, 0))
        if M_parent is not None:
            M = M_parent @ M
        self.cyl(f"{prefix}_base", 0.115, 0.130, 0.055, 20, "gunmetal", "gear_collar", (0, 0.075, 0), (0, 0, 0), 0.006, M_parent=M, u_rep=2.0, group=group)
        for si, sx in enumerate([-0.115, 0.115]):
            self.box(f"{prefix}_yk{si}", (0.032, 0.115, 0.075), "dark", "bolt_flange", (sx, 0.01, 0), (0, 0, 0), 0.006, 1, M_parent=M, group=group)
            self.cyl(f"{prefix}_cp{si}", 0.032, 0.032, 0.022, 12, "brass", "plain_metal", (sx + math.copysign(0.018, sx), -0.025, 0), (0, 0, 90), 0.003, M_parent=M, group=group)
        self.box(f"{prefix}_hd", (0.195, 0.135, 0.155), "armor_dark", "armor_pocket", (0, -0.025, -0.01), (0, 0, 0), 0.020, 1, M_parent=M, group=group)
        self.box(f"{prefix}_hood", (0.190, 0.018, 0.065), "gunmetal", "plain_metal", (0, 0.036, -0.092), (10, 0, 0), 0.004, 1, M_parent=M, group=group)
        for onm, ox, oy, orad, omat in [("flir", -0.044, -0.022, 0.038, "emit_cyan"),
                                        ("las",   0.044, -0.010, 0.025, "emit_amber"),
                                        ("tv",    0.044, -0.052, 0.017, "glass")]:
            self.cyl(f"{prefix}_bz_{onm}", orad + 0.009, orad + 0.011, 0.024, 14, "gunmetal", "gear_collar", (ox, oy, -0.088), (90, 0, 0), 0.003, hollow_r=orad * 0.85, M_parent=M, group=group)
            self.cyl(f"{prefix}_ln_{onm}", orad * 0.84, orad * 0.84, 0.016, 14, omat, "plain_metal", (ox, oy, -0.084), (90, 0, 0), 0.002, M_parent=M, group=group)

    def smoke_pod(self, prefix, pos, rot_deg, M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        self.box(f"{prefix}_brk", (0.20, 0.045, 0.085), "gunmetal", "bolt_flange", (0, -0.035, 0.03), (0, 0, 0), 0.005, 1, M_parent=M, group=group)
        for k in range(3):
            tx = (k - 1) * 0.066
            ty = 0.015 if k == 1 else -0.005
            self.cyl(f"{prefix}_t{k}", 0.031, 0.030, 0.185, 14, "dark", "plain_metal", (tx, ty, 0), (90, 0, 0), 0.004, hollow_r=0.022, M_parent=M, group=group)
            self.cyl(f"{prefix}_b{k}", 0.021, 0.021, 0.055, 10, "bore", "plain_metal", (tx, ty, 0.02), (90, 0, 0), 0.002, M_parent=M, group=group)
            self.cyl(f"{prefix}_c{k}", 0.034, 0.034, 0.022, 14, "brass", "gear_collar", (tx, ty, 0.085), (90, 0, 0), 0.003, M_parent=M, group=group)

    def cupola_hatch(self, prefix, pos, M_parent=None, group=None):
        M = g2b_mat(pos, (0, 0, 0))
        if M_parent is not None:
            M = M_parent @ M
        self.cyl(f"{prefix}_ring", 0.225, 0.245, 0.055, 24, "armor_sub", "bolt_flange", (0, 0.025, 0), (0, 0, 0), 0.007, hollow_r=0.175, M_parent=M, u_rep=2.0, group=group)
        self.cyl(f"{prefix}_lid", 0.172, 0.176, 0.032, 20, "armor", "armor_hatch", (0, 0.038, 0), (0, 0, 0), 0.005, M_parent=M, group=group)
        self.bolt_ring(f"{prefix}_blt", 0.205, 10, 0.009, (0, 0.055, 0), (0, 0, 0), M_parent=M, group=group)
        for hi, hx in enumerate([-0.055, 0.055]):
            self.box(f"{prefix}_hg{hi}", (0.036, 0.032, 0.055), "gunmetal", "plain_metal", (hx, 0.048, 0.185), (0, 0, 0), 0.005, 1, M_parent=M, group=group)
        self.cyl(f"{prefix}_hp", 0.012, 0.012, 0.16, 10, "chrome", "plain_metal", (0, 0.052, 0.195), (0, 0, 90), 0.002, M_parent=M, group=group)
        for pi, (px, pz, pyaw) in enumerate([(0.0, -0.145, 0.0), (-0.115, -0.095, 36.0), (0.115, -0.095, -36.0)]):
            mp = M @ g2b_mat((px, 0.072, pz), (0, pyaw, 0))
            self.box(f"{prefix}_ph{pi}", (0.105, 0.058, 0.072), "dark", "frame_cnc", (0, 0, 0), (0, 0, 0), 0.006, 1, M_parent=mp, group=group)
            self.box(f"{prefix}_pb{pi}", (0.112, 0.014, 0.088), "gunmetal", "plain_metal", (0, 0.028, -0.008), (8, 0, 0), 0.003, 1, M_parent=mp, group=group)
            self.box(f"{prefix}_pg{pi}", (0.082, 0.026, 0.014), "glass", "plain_metal", (0, 0.0, -0.036), (0, 0, 0), 0.002, 1, M_parent=mp, group=group)
        self.grab_rail(f"{prefix}_hdl", 0.14, 0.028, (0, 0.056, 0.06), (-90, 0, 0), 0.009, M_parent=M, group=group)

    def recon_mast(self, prefix, pos, M_parent=None, group=None):
        M = g2b_mat(pos, (0, 0, 0))
        if M_parent is not None:
            M = M_parent @ M
        self.cyl(f"{prefix}_srv", 0.068, 0.078, 0.065, 16, "gunmetal", "gear_collar", (0, 0.032, 0), (0, 0, 0), 0.005, M_parent=M, group=group)
        self.box(f"{prefix}_arm", (0.055, 0.145, 0.055), "dark", "frame_cnc", (0, 0.11, 0.01), (14, 0, 0), 0.006, 1, M_parent=M, group=group)
        self.box(f"{prefix}_rad", (0.20, 0.135, 0.068), "armor_sub", "armor_panel", (0, 0.21, 0.02), (-8, -18, 0), 0.009, 1, M_parent=M, group=group)
        self.box(f"{prefix}_rdf", (0.165, 0.105, 0.014), "armor_dark", "vent_mesh", (0, 0.21, -0.018), (-8, -18, 0), 0.003, 1, M_parent=M, group=group)
        self.cyl(f"{prefix}_ab1", 0.028, 0.036, 0.075, 12, "brass", "dust_boot", (0.11, 0.04, 0.10), (0, 0, 0), 0.004, M_parent=M, group=group)
        self.cyl(f"{prefix}_aw1", 0.005, 0.010, 0.96, 8, "dark", "plain_metal", (0.11, 0.53, 0.10), (-6, 0, 0), 0.002, M_parent=M, group=group)
        self.cyl(f"{prefix}_ab2", 0.022, 0.028, 0.055, 12, "brass", "dust_boot", (0.16, 0.03, 0.16), (0, 0, 0), 0.003, M_parent=M, group=group)
        self.cyl(f"{prefix}_aw2", 0.004, 0.008, 0.60, 8, "dark", "plain_metal", (0.16, 0.34, 0.16), (-12, 0, -6), 0.002, M_parent=M, group=group)

    def stowage_rack(self, prefix, pos, rot_deg=(0, 0, 0), M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        self.box(f"{prefix}_tr", (0.34, 0.028, 0.16), "gunmetal", "vent_mesh", (0, -0.07, 0), (0, 0, 0), 0.005, 1, M_parent=M, group=group)
        self.grab_rail(f"{prefix}_rl", 0.32, 0.14, (0, 0.04, 0.06), (0, 0, 0), 0.009, M_parent=M, group=group)
        self.box(f"{prefix}_cn", (0.28, 0.145, 0.125), "armor_sub", "armor_hatch", (0, 0.015, 0), (0, 0, 0), 0.010, 1, M_parent=M, group=group)
        for si, sx in enumerate([-0.085, 0.085]):
            self.box(f"{prefix}_st{si}", (0.026, 0.155, 0.134), "rubber", "plain_metal", (sx, 0.015, 0), (0, 0, 0), 0.003, 1, M_parent=M, group=group)
            self.box(f"{prefix}_bk{si}", (0.032, 0.028, 0.024), "brass", "plain_metal", (sx, 0.035, -0.068), (0, 0, 0), 0.003, 1, M_parent=M, group=group)
        self.box(f"{prefix}_hz", (0.32, 0.036, 0.018), "hazard", "hazard", (0, -0.085, -0.072), (0, 0, 0), 0.003, 1, M_parent=M, group=group)

    def waist_collar_core(self, prefix="HP_C1_Core", y_top=0.14, group=None):
        """Standardized unified HP-C1 core bottom slewing ring (r_bot=0.360m, y_bot=-0.005m)."""
        r = HP_C1_RADIUS
        yb = HP_C1_CORE_Y_BOT
        self.lathe(f"{prefix}_base", [
            (0.0, yb), (r - 0.006, yb), (r, yb + 0.008), (r, 0.032),
            (r + 0.010, 0.038), (r + 0.010, 0.056), (r - 0.012, 0.064), (r - 0.012, y_top), (0.0, y_top)
        ], 28, "dark", "bolt_flange", u_rep=3.0, group=group)
        self.cyl(f"{prefix}_gear", r + 0.016, r + 0.016, 0.026, 28, "gunmetal", "gear_collar", (0, 0.046, 0), (0, 0, 0), 0.004, u_rep=3.0, group=group)
        for wi in range(6):
            wa = math.tau * wi / 6.0 + math.pi / 6.0
            self.box(f"{prefix}_lug{wi}", (0.115, 0.072, 0.048), "armor_sub" if wi % 2 == 0 else "gunmetal", "armor_pocket",
                     (math.cos(wa) * (r - 0.004), 0.038, math.sin(wa) * (r - 0.004)), (0, -math.degrees(wa) + 90.0, 0), 0.007, 1, group=group)
        for bi in range(12):
            ba = math.tau * bi / 12.0
            self.cyl(f"{prefix}_blt{bi}", 0.009, 0.011, 0.020, 6, "chrome", "plain_metal",
                     (math.cos(ba) * (r + 0.004), 0.090, math.sin(ba) * (r + 0.004)), (0, -math.degrees(ba), 90), 0.002, group=group)

    def waist_collar_legs(self, prefix, socket_y, ped_bot_y, group=None):
        """Standardized unified HP-C1 legs waist pedestal + gear ring strictly clearing socket_y - 0.015m."""
        r = HP_C1_RADIUS
        top_y = socket_y - 0.018
        col_h = max(0.08, top_y - ped_bot_y - 0.085)
        self.cyl(f"{prefix}_col", r * 0.78, r * 0.84, col_h, 24, "dark", "frame_cnc",
                 (0, ped_bot_y + col_h * 0.5, 0), (0, 0, 0), 0.008, u_rep=2.0, group=group)
        ring_y = top_y - 0.044
        self.cyl(f"{prefix}_ring", r * 0.88, r, 0.088, 28, "dark", "bolt_flange",
                 (0, ring_y, 0), (0, 0, 0), 0.008, u_rep=3.0, group=group)
        self.cyl(f"{prefix}_gear", r + 0.008, r + 0.008, 0.024, 28, "gunmetal", "gear_collar",
                 (0, ring_y - 0.010, 0), (0, 0, 0), 0.003, u_rep=3.0, group=group)
        self.bolt_ring(f"{prefix}_blt", r * 0.84, 12, 0.010, (0, top_y - 0.002, 0), (0, 0, 0), group=group)

    def arm_bulkhead(self, prefix, x_abs, y, z=0.0, group=None):
        """Symmetrical left/right HP-A1 armored slewing shoulder bulkheads on core."""
        for si, sx in enumerate([-1.0, 1.0]):
            self.cyl(f"{prefix}_bh{si}", 0.235, 0.255, 0.100, 24, "dark", "gear_collar", (sx * (x_abs - 0.06), y, z), (0, 0, 90), 0.009, u_rep=2.0, group=group)
            self.cyl(f"{prefix}_fl{si}", 0.195, 0.195, 0.038, 24, "gunmetal", "bolt_flange", (sx * (x_abs - 0.012), y, z), (0, 0, 90), 0.005, u_rep=2.0, group=group)
            for bi in range(8):
                ba = math.tau * bi / 8.0
                self.cyl(f"{prefix}_bt{si}_{bi}", 0.010, 0.012, 0.016, 6, "chrome", "plain_metal",
                         (sx * (x_abs - 0.005), y + math.cos(ba) * 0.215, z + math.sin(ba) * 0.215), (0, 0, 90), 0.002, group=group)

    def a1_shoulder_mount(self, prefix="A1Mount", heavy=False, group=None):
        """
        Standard HP-A1 weapon arm adapter (canonical RIGHT arm, side=+1.0, root origin = plug mating face).
        Body origin is at x = +0.25m, yoke pivot at x = +0.37m (matching kit.gd a1_mount + heavy_gussets!).
        """
        # Flange at x = 0.065 (seam at x = 0.0)
        self.box(f"{prefix}_flg", (0.11, 0.44, 0.44), "gunmetal", "bolt_flange", (0.065, 0, 0), (0, 0, 0), 0.014, 1, group=group)
        for ci, (cy, cz) in enumerate([(-0.16, -0.16), (0.16, -0.16), (-0.16, 0.16), (0.16, 0.16)]):
            self.cyl(f"{prefix}_fb{ci}", 0.022, 0.025, 0.032, 6, "chrome", "plain_metal", (0.130, cy, cz), (0, 0, 90), 0.003, group=group)
        # Slewing bearing race (outer + chrome track + geared inner)
        self.cyl(f"{prefix}_brg0", 0.22, 0.22, 0.10, 22, "dark", "gear_collar", (0.16, 0, 0), (0, 0, 90), 0.007, u_rep=2.0, group=group)
        self.cyl(f"{prefix}_race", 0.226, 0.226, 0.020, 22, "chrome", "plain_metal", (0.20, 0, 0), (0, 0, 90), 0.003, group=group)
        self.cyl(f"{prefix}_brg1", 0.19, 0.19, 0.10, 20, "gunmetal", "bolt_flange", (0.24, 0, 0), (0, 0, 90), 0.006, u_rep=2.0, group=group)
        # Pitch yoke + vertical pivot pin + upper pauldron mast
        self.box(f"{prefix}_yk", (0.32, 0.26, 0.34), "armor", "armor_pocket", (0.37, 0, 0), (0, 0, 0), 0.016, 1, group=group)
        self.box(f"{prefix}_mst", (0.26, 0.34, 0.30), "dark", "frame_cnc", (0.41, 0.26, 0.02), (0, 0, -8.0), 0.014, 1, group=group)
        for syi, sy in enumerate([-1.0, 1.0]):
            self.box(f"{prefix}_ykf{syi}", (0.36, 0.06, 0.36), "armor_sub", "armor_ribs", (0.41, sy * 0.20, 0), (0, 0, 0), 0.010, 1, group=group)
            self.cyl(f"{prefix}_ypc{syi}", 0.09, 0.09, 0.032, 14, "chrome", "plain_metal", (0.38, sy * 0.245, 0), (0, 0, 0), 0.004, group=group)
        self.cyl(f"{prefix}_ypin", 0.08, 0.08, 0.50, 14, "dark", "plain_metal", (0.38, 0, 0), (0, 0, 0), 0.006, group=group)
        if heavy:
            self.box(f"{prefix}_hflg", (0.055, 0.50, 0.50), "gunmetal", "bolt_flange", (0.09, 0, 0), (0, 0, 0), 0.012, 1, group=group)
            self.box(f"{prefix}_hmst", (0.34, 0.44, 0.36), "dark", "frame_cnc", (0.49, 0.38, 0.04), (0, 0, -10.0), 0.014, 1, group=group)
            for bi in range(8):
                a = math.tau * bi / 8.0
                self.cyl(f"{prefix}_hb{bi}", 0.018, 0.020, 0.028, 6, "chrome", "plain_metal", (0.17, math.sin(a) * 0.21, math.cos(a) * 0.21), (0, 0, 90), 0.002, group=group)
            for syi, sy in enumerate([-1.0, 1.0]):
                for szi, sz in enumerate([-0.13, 0.13]):
                    self.box(f"{prefix}_hg{syi}_{szi}", (0.30, 0.080, 0.040), "armor_sub", "armor_ribs",
                             (0.26, sy * 0.215, sz), (0, 0, sy * -22.0), 0.008, 1, group=group)

    def barrel_bore(self, prefix, r_outer, r_inner, pos, depth=0.07, rot_deg=(90, 0, 0), segs=16, M_parent=None, group=None):
        """Machined hollow muzzle crown + deep recessed black bore interior (local +Y = Godot -Z forward)."""
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        # Hollow muzzle collar extending forward cleanly beyond the solid barrel end
        self.cyl(f"{prefix}_crn", r_outer * 1.05, r_outer * 1.05, depth * 0.90, segs, "gunmetal", "gear_collar",
                 (0, depth * 0.25, 0), (0, 0, 0), 0.003, hollow_r=r_inner, M_parent=M, group=group)
        # Pitch-black deep bore backplate recessed inside the hollow crown
        self.cyl(f"{prefix}_br", r_inner * 0.99, r_inner * 0.99, depth * 0.30, max(10, segs - 4), "bore", "plain_metal",
                 (0, -depth * 0.05, 0), (0, 0, 0), 0.001, M_parent=M, group=group)

    def era_block(self, prefix, size, mat_slot, pos, rot_deg=(0, 0, 0), M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        sx, sy, sz = size
        self.box(f"{prefix}_box", size, mat_slot, "armor_panel", (0, 0, 0), (0, 0, 0), min(0.014, sz * 0.28), 1, M_parent=M, group=group)
        bx, by = sx * 0.5 - 0.030, sy * 0.5 - 0.030
        for bi, (ox, oy) in enumerate([(-bx, -by), (bx, -by), (bx, by), (-bx, by)]):
            self.cyl(f"{prefix}_b{bi}", 0.011, 0.013, 0.016, 6, "chrome", "plain_metal", (ox, oy, -sz * 0.5 - 0.003), (90, 0, 0), 0.002, M_parent=M, group=group)

    def tow_shackle(self, prefix, pos, rot_deg=(0, 0, 90), scale=1.0, M_parent=None, group=None):
        M = g2b_mat(pos, rot_deg)
        if M_parent is not None:
            M = M_parent @ M
        self.cyl(f"{prefix}_ring", 0.042 * scale, 0.042 * scale, 0.022 * scale, 14, "gunmetal", "plain_metal",
                 (0, 0, 0), (0, 0, 0), 0.004 * scale, hollow_r=0.022 * scale, M_parent=M, group=group)
        self.cyl(f"{prefix}_pin", 0.012 * scale, 0.012 * scale, 0.046 * scale, 8, "chrome", "plain_metal",
                 (0, 0, 0.022 * scale), (0, 0, 0), 0.002 * scale, M_parent=M, group=group)

    # --------------------------------------------------------------------------
    # BAKE 24-RAY BVH VERTEX AO + CONVEX EDGE WEAR & EXPORT STANDARD GLB
    # --------------------------------------------------------------------------
    def export_glb(self, out_path: str) -> dict:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        t_mod = time.perf_counter()

        all_part_objs = []
        for ginfo in self.groups.values():
            for obj, _ in ginfo["parts"]:
                all_part_objs.append(obj)

        # 1. Apply Bevel & WeightedNormal modifiers
        depsgraph = bpy.context.evaluated_depsgraph_get()
        for obj in all_part_objs:
            if obj.modifiers:
                ev = obj.evaluated_get(depsgraph)
                nm = bpy.data.meshes.new_from_object(ev)
                om = obj.data
                obj.modifiers.clear()
                obj.data = nm
                bpy.data.meshes.remove(om)

        # 2. Build full-module world-space BVHTree (so articulated legs & pelvis cast true cross-AO!)
        bvh_verts, bvh_polys = [], []
        v_off = 0
        for obj in all_part_objs:
            m = obj.data
            mw = obj.matrix_world
            m.calc_loop_triangles()
            for v in m.vertices:
                bvh_verts.append(mw @ v.co)
            for tri in m.loop_triangles:
                bvh_polys.append((tri.vertices[0] + v_off, tri.vertices[1] + v_off, tri.vertices[2] + v_off))
            v_off += len(m.vertices)
        bvh = BVHTree.FromPolygons(bvh_verts, bvh_polys)

        # Cosine-weighted Fibonacci hemisphere ray directions
        n_rays = self.ao_rays
        hemi_dirs = []
        golden = math.pi * (3.0 - math.sqrt(5.0))
        for i in range(n_rays):
            u = (i + 0.5) / n_rays
            r_xy = math.sqrt(u)
            z = math.sqrt(max(0.0, 1.0 - u))
            th = golden * i
            hemi_dirs.append(Vector((r_xy * math.cos(th), r_xy * math.sin(th), z)))

        # 3. Bake Convex Edge (R = 1 - edge) + 24-ray Raytraced AO (G) per loop corner
        t_ao = time.perf_counter()
        ao_dist = self.ao_dist
        for obj in all_part_objs:
            m = obj.data
            mw = obj.matrix_world
            mn3 = mw.to_3x3().inverted_safe().transposed()

            bm = bmesh.new()
            bm.from_mesh(m)
            bm.verts.ensure_lookup_table()
            vconv = [0.0] * len(bm.verts)
            for v in bm.verts:
                mc = 0.0
                for e in v.link_edges:
                    if len(e.link_faces) == 2:
                        f0, f1 = e.link_faces[0], e.link_faces[1]
                        ang = f0.normal.angle(f1.normal, 0.0)
                        if ang > 0.26:
                            if (f1.calc_center_median() - f0.calc_center_median()).dot(f0.normal) < -1e-5:
                                cv = min(1.0, max(0.0, (ang - 0.30) / 0.55))
                                if cv > mc:
                                    mc = cv
                vconv[v.index] = mc
            bm.free()

            cnorms = m.corner_normals
            ca = m.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
            ao_cache = {}
            for poly in m.polygons:
                for li in poly.loop_indices:
                    vi = m.loops[li].vertex_index
                    ln = cnorms[li].vector
                    qk = (vi, int(round(ln.x * 8)), int(round(ln.y * 8)), int(round(ln.z * 8)))
                    ao_val = ao_cache.get(qk)
                    if ao_val is None:
                        wpos = mw @ m.vertices[vi].co
                        wnrm = (mn3 @ ln).normalized()
                        if wnrm.length_squared < 1e-6:
                            ao_val = 1.0
                        else:
                            ref = Vector((0, 0, 1)) if abs(wnrm.z) < 0.9 else Vector((1, 0, 0))
                            tx = wnrm.cross(ref).normalized()
                            ty = wnrm.cross(tx)
                            orig = wpos + wnrm * 0.006
                            occ = 0.0
                            for hd in hemi_dirs:
                                rdir = tx * hd.x + ty * hd.y + wnrm * hd.z
                                hl, _, _, hdist = bvh.ray_cast(orig, rdir, ao_dist)
                                if hl is not None and hdist > 0.002:
                                    occ += (1.0 - hdist / ao_dist) ** 0.90
                            ao_val = max(0.22, 1.0 - (occ / n_rays) * 1.05)
                        ao_cache[qk] = ao_val
                    ca.data[li].color = (max(0.0, min(1.0, 1.0 - vconv[vi] * 0.90)), ao_val, 1.0, 1.0)
            m.color_attributes.active_color = ca

        t_ao_end = time.perf_counter()

        # 4. Merge meshes strictly per (group, mat_slot) -> single-surface MeshInstance3D `<Group>__<slot>`
        total_tris = 0
        merged_count = 0
        for gkey, ginfo in self.groups.items():
            by_mat = {}
            for obj, slot in ginfo["parts"]:
                by_mat.setdefault(slot, []).append(obj)
            emp = ginfo["empty"]
            M_inv = ginfo["M_world"].inverted()

            for slot, objs in by_mat.items():
                bpy.ops.object.select_all(action="DESELECT")
                for o in objs:
                    o.select_set(True)
                bpy.context.view_layer.objects.active = objs[0]
                if len(objs) > 1:
                    bpy.ops.object.join()
                merged = bpy.context.active_object
                g_tag = gkey.replace("/", "_")
                merged.name = f"{g_tag}__{slot}"
                merged.data.name = f"{g_tag}__{slot}"

                # Bake geometry into the group's exact local coordinate space so scale=(1,1,1), rot=(0,0,0), loc=(0,0,0)
                M_rel = M_inv @ merged.matrix_world
                merged.data.transform(M_rel)
                merged.matrix_world = ginfo["M_world"]
                if emp is not None:
                    merged.parent = emp
                    merged.matrix_local = Matrix.Identity(4)
                else:
                    merged.matrix_world = Matrix.Identity(4)

                # Keep exactly 1 clean material slot matching `slot`
                merged.data.materials.clear()
                merged.data.materials.append(self.mats[slot])

                # Triangulate keeping custom weighted normals so Blender exports exact MikkTSpace TANGENT!
                mtri = merged.modifiers.new("Tri", "TRIANGULATE")
                mtri.keep_custom_normals = True
                with bpy.context.temp_override(object=merged, active_object=merged):
                    bpy.ops.object.modifier_apply(modifier=mtri.name)

                merged.data.calc_loop_triangles()
                total_tris += len(merged.data.loop_triangles)
                merged_count += 1

        # 5. Export clean zero-texture glTF Binary (.glb)
        bpy.ops.export_scene.gltf(
            filepath=out_path,
            export_format="GLB",
            export_yup=True,
            export_normals=True,
            export_tangents=True,
            export_texcoords=True,
            export_materials="EXPORT",
            export_vertex_color="ACTIVE",
            export_attributes=True,
            export_draco_mesh_compression_enable=False,
        )

        t_end = time.perf_counter()
        kb = os.path.getsize(out_path) / 1024.0
        stats = {
            "id": self.module_id,
            "parts": len(all_part_objs),
            "meshes": merged_count,
            "tris": total_tris,
            "kb": round(kb, 1),
            "geom_s": round(t_mod - self.t0, 2),
            "ao_s": round(t_ao_end - t_ao, 2),
            "total_s": round(t_end - self.t0, 2),
        }
        print(f"[KITBASH] {self.module_id}: parts={stats['parts']}, meshes={stats['meshes']}, "
              f"tris={stats['tris']}, size={stats['kb']} KB, geom={stats['geom_s']}s, ao={stats['ao_s']}s, total={stats['total_s']}s")
        return stats
