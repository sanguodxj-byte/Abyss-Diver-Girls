extends RefCounted
## Meshy AI 骨骼动作 GLB Boss 适配器：按种类加载并缓存带 PBR 贴图与动作剪辑的 .glb 场景，
## 自动修正蒙皮网格临界倒置法线、统一缩放与贴地对齐，并将状态机映射到 9 条骨骼动画轨道。

const ART = preload("res://scripts/art.gd")
const DA = preload("res://scripts/death_anim.gd")

const MODELS := {
	"excavator_titan": {
		"path": "res://assets/models/boss/excavator_titan.glb",
		"height_mult": 2.25,
		"yaw_deg": 180.0,
		"core_pos": Vector3(0.0, 1.18, 0.115),
		"core_color": Color(0.28, 0.88, 1.0),
	},
}

const LOOP_CLIPS := ["idle", "walk", "charge"]
const ONCE_CLIPS := ["claw", "shoot", "stomp", "roar", "hit", "dead"]

static var _scene_cache := {}
static var _sanitized_meshes := {}


static func build(h, body: Node3D, kind: String, s: float) -> bool:
	var cfg: Dictionary = MODELS.get(kind, {})
	if cfg.is_empty():
		return false
	var path := str(cfg.get("path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return false
	var ps: PackedScene = _scene_cache.get(path)
	if ps == null:
		ps = load(path) as PackedScene
		if ps == null:
			return false
		_scene_cache[path] = ps
	var inst := ps.instantiate()
	if inst == null:
		return false

	var root := Node3D.new()
	root.name = "ModelRoot"
	body.add_child(root)
	root.add_child(inst)

	var aabb := _compute_bounds(inst)
	var u_scale: float = (float(cfg.get("height_mult", 2.2)) * s) / maxf(aabb.size.y, 0.01)
	root.scale = Vector3.ONE * u_scale
	root.rotation.y = deg_to_rad(float(cfg.get("yaw_deg", 180.0)))
	root.position = Vector3(0.0, -aabb.position.y * u_scale, 0.0)

	var mob_perf := ART.is_mobile_perf()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.mesh is ArrayMesh:
			mi.mesh = _get_sanitized_mesh(mi.mesh as ArrayMesh)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mob_perf:
			mi.visibility_range_end = 135.0
			mi.visibility_range_end_margin = 5.0
		h.parts.append(mi)

	# 胸口核心发光优先挂在骨骼 Spine01 的 BoneAttachment3D 上随躯干运动与倒地，避免静态悬空
	h.core_mi = _attach_chest_core(inst, body, cfg, s)

	var ap := _find_anim_player(inst)
	if ap != null:
		_configure_loops(ap)
		if ap.has_animation("idle"):
			ap.play("idle")
			ap.advance(0.0)

	h.set_meta("glb_rig", {
		"ap": ap,
		"cur": "idle",
		"awaken_t": 0.0,
		"hit_t": 0.0,
		"root": root,
	})
	return true


static func _rel_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _attach_chest_core(inst: Node, body: Node3D, cfg: Dictionary, s: float) -> MeshInstance3D:
	var core_mount := Node3D.new()
	core_mount.name = "CoreMount"
	var core := MeshInstance3D.new()
	core.name = "CoreGlow"
	core.material_override = ART.emit(cfg.get("core_color", Color(0.28, 0.88, 1.0)), 0.40)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.set_meta("no_flash", true)
	var skel: Skeleton3D = null
	for n in inst.find_children("*", "Skeleton3D", true, false):
		if n is Skeleton3D:
			skel = n as Skeleton3D
			break
	var bone_name := "Spine01"
	if skel != null and skel.find_bone(bone_name) < 0:
		bone_name = "Spine"
	if skel != null and inst is Node3D and skel.find_bone(bone_name) >= 0:
		var bi := skel.find_bone(bone_name)
		var rest_in_inst := _rel_to(skel, inst as Node3D) * skel.get_bone_global_rest(bi)
		var attach := BoneAttachment3D.new()
		attach.name = "ChestCoreAttach"
		attach.bone_name = bone_name
		skel.add_child(attach)
		var target_in_inst: Vector3 = cfg.get("core_pos", Vector3(0.0, 1.18, 0.115))
		core_mount.transform = rest_in_inst.affine_inverse() * Transform3D(Basis.IDENTITY, target_in_inst)
		attach.add_child(core_mount)
		core.mesh = ART.sphere(0.042, 0.088, 14)
		core.scale = Vector3(0.85, 1.0, 0.72)
	else:
		core_mount.position = Vector3(0.0, 1.24, -0.38) * s
		body.add_child(core_mount)
		core.mesh = ART.sphere(0.11 * s, 0.20 * s, 14)
	core_mount.add_child(core)
	return core


static func _compute_bounds(inst: Node) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# 蒙皮网格的 get_aabb() 已是米制包围盒（Armature 0.01 缩放与 Skin 100x 逆绑定矩阵互抵）
		var ab := mi.get_aabb()
		if mi.skin == null and inst is Node3D:
			var rel := (inst as Node3D).global_transform.affine_inverse() * mi.global_transform
			ab = rel * ab
		if not has_bounds:
			combined = ab
			has_bounds = true
		else:
			combined = combined.merge(ab)
	if not has_bounds:
		return AABB(Vector3(-0.7, 0.0, -0.5), Vector3(1.4, 1.8, 1.0))
	return combined


static func _find_anim_player(root: Node) -> AnimationPlayer:
	for n in root.find_children("*", "AnimationPlayer", true, false):
		if n is AnimationPlayer:
			return n as AnimationPlayer
	return null


static func _configure_loops(ap: AnimationPlayer) -> void:
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib == null:
			continue
		var dup := lib.duplicate(true) as AnimationLibrary
		if dup == null:
			continue
		for clip in LOOP_CLIPS:
			if dup.has_animation(clip):
				dup.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		for clip in ONCE_CLIPS:
			if dup.has_animation(clip):
				dup.get_animation(clip).loop_mode = Animation.LOOP_NONE
		ap.remove_animation_library(lib_name)
		ap.add_animation_library(lib_name, dup)


static func _get_sanitized_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var key := mesh.get_instance_id()
	if _sanitized_meshes.has(key):
		return _sanitized_meshes[key]
	var clean := _sanitize_mesh_normals(mesh)
	_sanitized_meshes[key] = clean
	return clean


## 校验并拆点修正极少数临界翻面三角形法线，确保 normal_audit 零误差且保留全部蒙皮与 PBR 属性
static func _sanitize_mesh_normals(mesh: ArrayMesh) -> ArrayMesh:
	var needs_fix := false
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if norms.size() != verts.size():
			needs_fix = true
			break
		var tris := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		for t in tris:
			var i0 := t * 3
			var ia := idx[i0] if idx.size() > 0 else i0
			var ib := idx[i0 + 1] if idx.size() > 0 else i0 + 1
			var ic := idx[i0 + 2] if idx.size() > 0 else i0 + 2
			var gn := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
			if gn.length_squared() < 1e-12:
				continue
			var front := -gn.normalized()
			if norms[ia].dot(front) < 0.03 or norms[ib].dot(front) < 0.03 or norms[ic].dot(front) < 0.03:
				needs_fix = true
				break
		if needs_fix:
			break
	if not needs_fix:
		return mesh

	var clean := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vcount := verts.size()
		if norms.size() != vcount:
			norms = PackedVector3Array()
			norms.resize(vcount)
			norms.fill(Vector3.UP)
		var strides := {}
		for ai in Mesh.ARRAY_MAX:
			if ai == Mesh.ARRAY_INDEX or arr[ai] == null:
				continue
			var sz: int = arr[ai].size()
			if sz > 0 and vcount > 0:
				strides[ai] = maxi(1, sz / vcount)
		var tris := idx.size() / 3 if idx.size() > 0 else vcount / 3
		for t in tris:
			var i0 := t * 3
			var ia := idx[i0] if idx.size() > 0 else i0
			var ib := idx[i0 + 1] if idx.size() > 0 else i0 + 1
			var ic := idx[i0 + 2] if idx.size() > 0 else i0 + 2
			var gn := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
			if gn.length_squared() < 1e-12:
				continue
			var front := -gn.normalized()
			var corners := [ia, ib, ic]
			for c_i in 3:
				var vi: int = corners[c_i]
				if norms[vi].dot(front) < 0.03:
					if idx.size() > 0:
						var new_vi := verts.size()
						verts.append(verts[vi])
						norms.append(front)
						for ai in strides:
							if ai == Mesh.ARRAY_VERTEX or ai == Mesh.ARRAY_NORMAL:
								continue
							var st: int = int(strides[ai])
							var src = arr[ai]
							for k in st:
								src.append(src[vi * st + k])
						idx[i0 + c_i] = new_vi
					else:
						norms[vi] = front
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		if idx.size() > 0:
			arr[Mesh.ARRAY_INDEX] = idx
		clean.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := mesh.surface_get_material(s)
		if mat != null:
			clean.surface_set_material(s, mat)
		var sname := mesh.surface_get_name(s)
		if sname != "":
			clean.surface_set_name(s, sname)
	return clean


static func _rig(h):
	return h.get_meta("glb_rig") if h != null and is_instance_valid(h) and h.has_meta("glb_rig") else null


static func on_awaken(h) -> void:
	var rig = _rig(h)
	if rig == null:
		return
	rig["awaken_t"] = 1.8
	var ap: AnimationPlayer = rig.get("ap")
	if is_instance_valid(ap) and ap.has_animation("roar"):
		rig["cur"] = "roar"
		ap.speed_scale = 1.0
		ap.play("roar", 0.15)


static func on_cancel_act(h) -> void:
	var rig = _rig(h)
	if rig == null:
		return
	rig["hit_t"] = 0.55
	var ap: AnimationPlayer = rig.get("ap")
	if is_instance_valid(ap) and ap.has_animation("hit"):
		rig["cur"] = "hit"
		ap.speed_scale = 1.15
		ap.play("hit", 0.10)


static func animate(h, delta: float, mv: float) -> void:
	var rig = _rig(h)
	if rig == null:
		return
	h.move_amt = move_toward(h.move_amt, clampf(mv, 0.0, 1.0), delta * 6.0)
	h.anim_t += delta * (0.3 + h.move_amt)
	h.hit_v += (-h.hit_tilt * 160.0 - h.hit_v * 13.0) * delta
	h.hit_tilt += h.hit_v * delta

	var body: Node3D = h.visual.get_node_or_null("Body") if is_instance_valid(h.visual) else null
	if body != null:
		body.position = Vector3.ZERO
		body.rotation.x = clampf(h.hit_tilt.x * 0.25, -0.18, 0.18)
		body.rotation.z = clampf(h.hit_tilt.z * 0.25, -0.18, 0.18)
	if is_instance_valid(h.visual):
		h.visual.position.y = 0.0
		h.visual.rotation.x = lerp(h.visual.rotation.x, 0.0, clampf(8.0 * delta, 0.0, 1.0))

	rig["awaken_t"] = maxf(0.0, float(rig.get("awaken_t", 0.0)) - delta)
	rig["hit_t"] = maxf(0.0, float(rig.get("hit_t", 0.0)) - delta)

	var clip := "idle"
	var blend := 0.25
	var spd := 1.0
	if h.dying:
		clip = "dead"
		blend = 0.15
		spd = 1.0
	elif float(rig["awaken_t"]) > 0.0 or h.act in ["summon", "core", "roar"]:
		clip = "roar"
		blend = 0.18
		spd = 1.0
	elif h.act == "charge":
		clip = "charge"
		blend = 0.12
		spd = 1.35
	elif h.act == "wind":
		var nxt: String = h._next_step()
		blend = 0.15
		if nxt in ["claw", "strike"]:
			clip = "claw"
			spd = 0.65
		elif nxt in ["stomp", "spike"]:
			clip = "stomp"
			spd = 0.70
		elif nxt in ["salvo", "slug"]:
			clip = "shoot"
			spd = 0.85
		elif nxt in ["summon", "core", "roar"]:
			clip = "roar"
			spd = 0.85
		else:
			clip = "roar"
			spd = 1.1
	elif h.act in ["claw", "strike"]:
		clip = "claw"
		blend = 0.08
		spd = 1.45
	elif h.act in ["stomp", "spike"]:
		clip = "stomp"
		blend = 0.08
		spd = 1.35
	elif h.act in ["salvo", "slug"]:
		clip = "shoot"
		blend = 0.12
		spd = 1.25
	elif float(rig["hit_t"]) > 0.0:
		clip = "hit"
		blend = 0.10
		spd = 1.15
	elif h.awake and h.move_amt >= 0.08 and h.act == "":
		clip = "walk"
		blend = 0.22
		spd = clampf(0.75 + h.move_amt * 0.65, 0.75, 1.4)
	else:
		clip = "idle"
		blend = 0.25
		spd = 0.55 if not h.awake else 1.0

	var ap: AnimationPlayer = rig.get("ap")
	if is_instance_valid(ap):
		if not ap.has_animation(clip) and ap.has_animation("idle"):
			clip = "idle"
		if ap.has_animation(clip):
			if str(rig.get("cur", "")) != clip:
				rig["cur"] = clip
				ap.speed_scale = spd
				ap.play(clip, blend)
			else:
				ap.speed_scale = spd

	# 复位核心亮度，避免 boss.gd 每帧叠加 core_vis * 2.8 无限累加
	if h.core_mi and is_instance_valid(h.core_mi) and h.core_mi.material_override is StandardMaterial3D:
		var em: StandardMaterial3D = h.core_mi.material_override
		var e0: float = 0.45 + sin(h.anim_t * 3.2) * 0.15 + (h.focus * 1.8 if h.act == "wind" else 0.0)
		em.emission_energy_multiplier = lerp(em.emission_energy_multiplier, e0, clampf(8.0 * delta, 0.0, 1.0))


static func on_die(h, body: Node3D) -> bool:
	var rig = _rig(h)
	if rig == null:
		return false
	var start_pos: Vector3 = h.global_position
	var g_info := DA.sample_ground(h, start_pos, 5.5, 60.0)
	var gy: float = float(g_info.get("y", start_pos.y))
	var end_pos := Vector3(start_pos.x, gy, start_pos.z)
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	if is_instance_valid(h.visual):
		h.visual.position = Vector3.ZERO
	rig["cur"] = "dead"
	var ap: AnimationPlayer = rig.get("ap")
	var root: Node3D = rig.get("root")
	var dead_len := 2.6
	if is_instance_valid(ap) and ap.has_animation("dead"):
		dead_len = maxf(ap.get_animation("dead").length, 0.5)
		ap.speed_scale = 1.0
		ap.play("dead", 0.12)
	var tw: Tween = (h as Node).create_tween().set_parallel(true)
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(h):
			return
		h.global_position = start_pos.lerp(end_pos, u * u)
		h._vis_sync()
	, 0.0, 1.0, 0.55)
	DA.power_down_wreck(h.visual, tw, 1.5, 0.62)
	if h.core_mi and is_instance_valid(h.core_mi):
		tw.tween_property(h.core_mi, "scale", Vector3.ZERO, 1.5)
	if h.raid != null and is_instance_valid(h.raid.fx):
		var fx_root: Node = h.raid.fx
		var sc := maxf(float(h.data.get("scale", 2.9)), 1.5)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(fx_root):
				return
			var gp := end_pos + Vector3(0.0, 0.15, 0.0)
			if h.raid != null and h.raid.has_method("explode_fx"):
				h.raid.explode_fx(gp + Vector3(0.0, 0.8 * sc, 0.0), 4.8, Color(1.0, 0.54, 0.18))
				h.raid.shake = maxf(h.raid.shake, 0.75)
			ART.burst(fx_root, gp, {"amount": 28, "life": 1.0, "size": 1.45 * sc, "tex": ART.dust_tex(), "additive": false, "flat": 0.88,
				"dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": 3.2, "vmax": 9.0, "gravity": Vector3(0, 0.3, 0), "damp": 4.2,
				"c0": Color(0.58, 0.50, 0.38, 0.0), "cmid": Color(0.56, 0.48, 0.36, 0.58), "cmid_pos": 0.18,
				"c1": Color(0.44, 0.38, 0.30, 0.0), "grow0": 0.55, "grow1": 2.2})
		).set_delay(minf(dead_len * 0.58, 1.35))
	var finish_t := maxf(dead_len, 2.2)
	var fin_tw: Tween = (h as Node).create_tween()
	fin_tw.tween_interval(finish_t)
	fin_tw.tween_callback(func():
		if not is_instance_valid(h):
			return
		h.global_position = end_pos
		h._vis_sync()
		if is_instance_valid(ap):
			ap.advance(0.0)
			ap.active = false
		if is_instance_valid(root) and is_instance_valid(h.visual):
			var min_wy: float = DA.lowest_world_y(h.visual)
			if min_wy < 1e8:
				root.position.y += (gy - 0.03 - min_wy)
		for m in h.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D and not (m.mesh is PlaneMesh):
				m.visibility_range_end = 90.0
				m.visibility_range_end_margin = 5.0
		h._finalize_corpse())
	return true
