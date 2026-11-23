extends RefCounted
## 高精度机甲模块 GLB 运行时加载器（MECH_MODELING_STANDARD v1.0）
##
## 职责：
##   1. 优先从预导入 PackedScene 加载 res://assets/models/mech_modules/<id>.glb（<2ms）；开发期未导入时兜底 GLTFDocument。
##   2. 按 MeshInstance3D 名称后缀 `<Group>__<mat_slot>` 绑定全局共享 2K Trim Sheet (`mech_trim.gdshader`) 与标准光学/自发光材质。
##   3. 左臂 (`arm_l`) 采用无负缩放的网格级 X 镜像 + 三角形绕序翻转并缓存，保证 normal_audit 零误差与切线空间法线 100% 正确。
##   4. 自动将 GLB 内标准 Empty 节点 (`SOCKET_*` / `MUZZLE` / `MARK_SOLE` / `LIGHT_*` / `Leg_*` / `Track_*`) 重建为 kit.gd 标准接口与动画元数据。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

const GLB_DIR := "res://assets/models/mech_modules/"
const TRIM_SHADER_PATH := "res://shaders/mech_trim.gdshader"
const TRIM_A_PATH := "res://assets/textures/mech_trim_a.png"
const TRIM_N_PATH := "res://assets/textures/mech_trim_n.png"
const TRIM_ORM_PATH := "res://assets/textures/mech_trim_orm.png"

static var _packed_cache := {}       ## base_id -> PackedScene
static var _loading := {}            ## path -> true
static var _mat_cache := {}          ## key -> Material
static var _mirror_cache := {}       ## mesh_rid -> ArrayMesh (X-mirrored with flipped winding)
static var _trim_shader: Shader = null
static var _trim_a: Texture2D = null
static var _trim_n: Texture2D = null
static var _trim_orm: Texture2D = null


static func glb_path(base_id: String) -> String:
	return "%s%s.glb" % [GLB_DIR, base_id]


static func has_glb(base_id: String) -> bool:
	if base_id.is_empty():
		return false
	var p := glb_path(base_id)
	return _packed_cache.has(base_id) or ResourceLoader.exists(p)


static func request_glb(base_id: String) -> void:
	if base_id.is_empty() or _packed_cache.has(base_id):
		return
	var p := glb_path(base_id)
	if _loading.has(p) or not ResourceLoader.exists(p):
		return
	var err := ResourceLoader.load_threaded_request(p, "PackedScene")
	if err == OK:
		_loading[p] = true


static func glb_ready(base_id: String) -> bool:
	var p := glb_path(base_id)
	if not _loading.has(p):
		return true
	match ResourceLoader.load_threaded_get_status(p):
		ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(p)
			if res is PackedScene:
				_packed_cache[base_id] = res
			_loading.erase(p)
			return true
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading.erase(p)
			return true
	return false


static func _ensure_trim_assets() -> void:
	if _trim_shader == null:
		_trim_shader = load(TRIM_SHADER_PATH) as Shader
	if _trim_a == null:
		_trim_a = _load_tex_fallback(TRIM_A_PATH)
	if _trim_n == null:
		_trim_n = _load_tex_fallback(TRIM_N_PATH)
	if _trim_orm == null:
		_trim_orm = _load_tex_fallback(TRIM_ORM_PATH)


static func _load_tex_fallback(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var t := load(res_path) as Texture2D
		if t != null:
			return t
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var img := Image.load_from_file(abs_p)
		if img != null:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


static func _trim_mat(col: Color, met: float, rgh: float, wear_v := 0.48, raw_alb := 0.0, takes_dmg := 0.0, n_str := 1.15) -> ShaderMaterial:
	_ensure_trim_assets()
	var key := "tr|%s|%.2f|%.2f|%.2f|%.0f|%.0f|%.2f" % [col.to_html(false), met, rgh, wear_v, raw_alb, takes_dmg, n_str]
	var cached: ShaderMaterial = _mat_cache.get(key)
	if cached != null:
		return cached
	var sm := ShaderMaterial.new()
	sm.shader = _trim_shader
	sm.set_shader_parameter("base_color", col)
	sm.set_shader_parameter("metal_base", met)
	sm.set_shader_parameter("rough_base", rgh)
	sm.set_shader_parameter("wear", wear_v)
	sm.set_shader_parameter("raw_albedo", raw_alb)
	sm.set_shader_parameter("takes_damage", takes_dmg)
	sm.set_shader_parameter("normal_strength", n_str)
	sm.set_shader_parameter("ao_strength", 0.90)
	if _trim_a != null:
		sm.set_shader_parameter("trim_albedo", _trim_a)
	if _trim_n != null:
		sm.set_shader_parameter("trim_normal", _trim_n)
	if _trim_orm != null:
		sm.set_shader_parameter("trim_orm", _trim_orm)
	sm.set_shader_parameter("noise_lo", A.noise_tex("grime_raw"))
	_mat_cache[key] = sm
	return sm


static func _slot_mat(mat_slot: String, ctx: Dictionary) -> Material:
	var c: Color = ctx.get("color", Color(0.42, 0.43, 0.41))
	var info: Dictionary = ctx.get("info", {})
	var gc: Color = info.get("color", Color(0.30, 0.80, 0.95))
	match mat_slot:
		"armor":
			return _trim_mat(c, 0.15, 0.58, 0.44, 0.0, 1.0, 1.15)
		"armor_sub":
			return _trim_mat(c.darkened(0.24), 0.20, 0.56, 0.48, 0.0, 1.0, 1.15)
		"armor_dark":
			return _trim_mat(c.darkened(0.46), 0.28, 0.54, 0.42, 0.0, 1.0, 1.12)
		"dark":
			return _trim_mat(Color(0.11, 0.118, 0.132), 0.54, 0.52, 0.32, 0.0, 0.0, 1.08)
		"gunmetal":
			return _trim_mat(Color(0.19, 0.205, 0.228), 0.68, 0.44, 0.38, 0.0, 0.0, 1.12)
		"chrome":
			return _trim_mat(Color(0.72, 0.75, 0.80), 0.92, 0.22, 0.18, 0.0, 0.0, 0.55)
		"copper":
			return _trim_mat(Color(0.64, 0.36, 0.20), 0.85, 0.32, 0.28, 0.0, 0.0, 0.80)
		"brass":
			return _trim_mat(Color(0.62, 0.48, 0.22), 0.82, 0.34, 0.30, 0.0, 0.0, 0.84)
		"rubber":
			return _trim_mat(Color(0.075, 0.080, 0.088), 0.03, 0.90, 0.10, 0.0, 0.0, 1.20)
		"hazard":
			return _trim_mat(Color.WHITE, 0.08, 0.56, 0.42, 1.0, 0.0, 0.95)
		"accent":
			return _trim_mat(K.ACCENT, 0.14, 0.56, 0.46, 0.0, 0.0, 1.00)
		"bore":
			return K.bore_mat()
		"glass":
			return K.canopy(K.VISOR, 0.28)
		"emit_headlight":
			return A.emit(Color(1.0, 0.94, 0.80), 2.4)
		"emit_amber":
			return A.emit(Color(0.95, 0.70, 0.20), 2.0)
		"emit_cyan":
			return A.emit(Color(0.28, 0.90, 0.72), 2.0)
		"emit_red":
			return A.emit(Color(0.95, 0.24, 0.18), 2.2)
		"emit_core":
			return A.emit(gc, 1.4)
		_:
			return _trim_mat(c, 0.28, 0.46, 0.48, 0.0, 1.0, 1.15)


static func _load_scene_instance(base_id: String) -> Node3D:
	var ps: PackedScene = _packed_cache.get(base_id)
	var p := glb_path(base_id)
	if ps == null and ResourceLoader.exists(p):
		var loaded := load(p)
		if loaded is PackedScene:
			ps = loaded
			_packed_cache[base_id] = ps
	if ps != null:
		return ps.instantiate() as Node3D
	# Dev-only fallback if GLB was just generated before `godot --import`
	var abs_p := ProjectSettings.globalize_path(p)
	if FileAccess.file_exists(abs_p):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(abs_p, st) == OK:
			return doc.generate_scene(st) as Node3D
	return null


## 网格级无负缩放 X 镜像：翻转 X 坐标、法线 X、切线 X 与 handedness w，并反转三角形绕序，确保法线 100% 朝外
static func _mirror_mesh_x(src: Mesh) -> ArrayMesh:
	var rid := src.get_rid()
	var cached: ArrayMesh = _mirror_cache.get(rid)
	if cached != null:
		return cached
	var dst := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		var verts: PackedVector3Array = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
		for i in verts.size():
			var v := verts[i]
			verts[i] = Vector3(-v.x, v.y, v.z)
		arr[Mesh.ARRAY_VERTEX] = verts
		if arr[Mesh.ARRAY_NORMAL] != null:
			var norms: PackedVector3Array = (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
			for i in norms.size():
				var n := norms[i]
				norms[i] = Vector3(-n.x, n.y, n.z)
			arr[Mesh.ARRAY_NORMAL] = norms
		if arr[Mesh.ARRAY_TANGENT] != null:
			var tangs: PackedFloat32Array = (arr[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
			for i in range(0, tangs.size(), 4):
				tangs[i] = -tangs[i]         # tx = -tx
				tangs[i + 3] = -tangs[i + 3] # handedness sign flips under reflection
			arr[Mesh.ARRAY_TANGENT] = tangs
		if arr[Mesh.ARRAY_INDEX] != null:
			var idxs: PackedInt32Array = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
			for i in range(0, idxs.size() - 2, 3):
				var tmp := idxs[i + 1]
				idxs[i + 1] = idxs[i + 2]
				idxs[i + 2] = tmp
			arr[Mesh.ARRAY_INDEX] = idxs
		else:
			# Non-indexed triangles: swap v1/v2 in every attribute array
			var n_v := verts.size()
			for attr_i in arr.size():
				if arr[attr_i] == null or attr_i == Mesh.ARRAY_INDEX:
					continue
				if attr_i == Mesh.ARRAY_TANGENT:
					var ta: PackedFloat32Array = arr[attr_i]
					for i in range(0, n_v - 2, 3):
						for c in 4:
							var k1 := (i + 1) * 4 + c
							var k2 := (i + 2) * 4 + c
							var t := ta[k1]; ta[k1] = ta[k2]; ta[k2] = t
					arr[attr_i] = ta
				else:
					var a = arr[attr_i].duplicate()
					for i in range(0, n_v - 2, 3):
						var t = a[i + 1]; a[i + 1] = a[i + 2]; a[i + 2] = t
					arr[attr_i] = a
		dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mirror_cache[rid] = dst
	return dst


static func _plug_dir_for(slot: String, side: float) -> Vector3:
	match slot:
		"legs": return Vector3.ZERO
		"core": return Vector3.DOWN
		"arm_l", "arm_r": return Vector3(-side, 0.0, 0.0)
		"back": return Vector3(0.0, -1.0, -0.25)
		_: return Vector3.FORWARD


static func _extract_slot_name(mesh_name: String) -> String:
	var idx := mesh_name.rfind("__")
	if idx < 0:
		return "armor"
	var raw := mesh_name.substr(idx + 2)
	var dot := raw.find(".")
	return raw.substr(0, dot) if dot >= 0 else raw


static func build(slot: String, ctx: Dictionary) -> Node3D:
	var base_id: String = str(ctx.get("id", ""))
	var side: float = float(ctx.get("side", 0.0))
	var inst := _load_scene_instance(base_id)
	if inst == null:
		return null

	var root := K.module_root(slot, base_id, _plug_dir_for(slot, side))
	var mirror_x := (slot == "arm_l")

	# Clear PackedScene owner before reparenting so Godot emits zero owner warnings
	for desc in inst.find_children("*", "", true, false):
		desc.owner = null

	# Move all direct children from GLB root into our standard module_root
	var children := inst.get_children()
	for ch in children:
		inst.remove_child(ch)
		root.add_child(ch)
	inst.free()

	var to_free: Array[Node] = []
	var has_muzzle := false
	var lights_on: bool = bool(ctx.get("lights", true))
	var info: Dictionary = ctx.get("info", {})
	var gc: Color = info.get("color", Color(0.30, 0.80, 0.95))

	# Pass 1: Bind materials, mirror arm_l meshes cleanly, process sockets/markers/lights
	for n in root.find_children("*", "", true, false):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var mslot := _extract_slot_name(mi.name)
			if mirror_x and mi.mesh != null:
				mi.mesh = _mirror_mesh_x(mi.mesh)
				mi.position = Vector3(-mi.position.x, mi.position.y, mi.position.z)
				mi.rotation = Vector3(mi.rotation.x, -mi.rotation.y, -mi.rotation.z)
			mi.material_override = _slot_mat(mslot, ctx)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		elif n is Node3D:
			var nd := n as Node3D
			var nm := nd.name
			if nm == "SOCKET_arm_l":
				K.socket(root, "arm_l", nd.position, Vector3.LEFT, -1.0)
				to_free.append(nd)
			elif nm == "SOCKET_arm_r":
				K.socket(root, "arm_r", nd.position, Vector3.RIGHT, 1.0)
				to_free.append(nd)
			elif nm == "SOCKET_back":
				K.socket(root, "back", nd.position, Vector3(0.0, 1.0, 0.25))
				to_free.append(nd)
			elif nm == "SOCKET_gen":
				K.socket(root, "gen", nd.position, Vector3.BACK)
				to_free.append(nd)
			elif nm == "SOCKET_core":
				K.socket(root, "core", nd.position, Vector3.UP)
				to_free.append(nd)
			elif nm == "MUZZLE":
				var mz := Marker3D.new()
				mz.name = "Muzzle"
				var p := nd.position
				mz.position = Vector3(-p.x if mirror_x else p.x, p.y, p.z)
				root.add_child(mz)
				root.set_meta("muzzle", mz)
				has_muzzle = true
				to_free.append(nd)
			elif nm.begins_with("LIGHT_"):
				if lights_on:
					var lp := nd.position
					if mirror_x:
						lp.x = -lp.x
					var lcol := gc if nm == "LIGHT_core" else Color(1.0, 0.94, 0.80)
					K.light(root, lcol, lp, 0.14, 1.4)
				to_free.append(nd)
			elif mirror_x and nm != "Plug":
				nd.position = Vector3(-nd.position.x, nd.position.y, nd.position.z)
				nd.rotation = Vector3(nd.rotation.x, -nd.rotation.y, -nd.rotation.z)

	# Pass 2: Wire articulated leg metadata for biped / quad / hex / tread
	if slot == "legs":
		_wire_legs_meta(root, to_free)

	if (slot == "arm_l" or slot == "arm_r") and not has_muzzle:
		var mz := Marker3D.new()
		mz.name = "Muzzle"
		mz.position = Vector3(side * 0.5, 0.0, -1.5)
		root.add_child(mz)
		root.set_meta("muzzle", mz)

	for f in to_free:
		if is_instance_valid(f):
			if f.get_parent() != null:
				f.get_parent().remove_child(f)
			f.free()

	return root


static func _find_child_prefix(parent: Node3D, prefix: String) -> Node3D:
	if parent == null:
		return null
	for ch in parent.get_children():
		if ch is Node3D:
			var nm := ch.name
			if nm == prefix or nm.begins_with(prefix + "_") or nm.begins_with(prefix + "."):
				return ch as Node3D
	return null


static func _wire_legs_meta(root: Node3D, to_free: Array[Node]) -> void:
	var leg_l := root.get_node_or_null("Leg_L") as Node3D
	var leg_r := root.get_node_or_null("Leg_R") as Node3D
	if leg_l != null and leg_r != null:
		var parts: Array = []
		for leg: Node3D in [leg_l, leg_r]:
			var kj := _find_child_prefix(leg, "Knee")
			var aj := _find_child_prefix(kj, "Ankle")
			var kn := kj.position if kj != null else Vector3(0, -0.78, -0.34)
			var an := kn + (aj.position if aj != null else Vector3(0, -0.52, 0.54))
			var sole_y := -leg.position.y
			var sole_mk := _find_child_prefix(leg, "MARK_SOLE")
			if sole_mk != null:
				sole_y = sole_mk.position.y
				to_free.append(sole_mk)
			if kj != null:
				leg.set_meta("knee", kj)
			if aj != null:
				leg.set_meta("ankle", aj)
			leg.set_meta("KN", kn)
			leg.set_meta("AN", an)
			leg.set_meta("sole", sole_y)
			parts.append(leg)
		root.set_meta("leg_parts", parts)
		root.set_meta("leg_type", "biped")
		return

	var leg0 := root.get_node_or_null("Leg_0") as Node3D
	if leg0 != null:
		var parts: Array = []
		for i in 8:
			var leg := root.get_node_or_null("Leg_%d" % i) as Node3D
			if leg == null:
				break
			var fm := _find_child_prefix(leg, "Femur")
			var kj := _find_child_prefix(fm, "Knee") if fm != null else _find_child_prefix(leg, "Knee")
			var aj := _find_child_prefix(kj, "Ankle")
			var kn := kj.position if kj != null else Vector3(0, 0.44, 0.94)
			var an := kn + (aj.position if aj != null else Vector3(0, -1.79, 0.42))
			if fm != null:
				leg.set_meta("femur", fm)
			if kj != null:
				leg.set_meta("knee", kj)
			if aj != null:
				leg.set_meta("ankle", aj)
			leg.set_meta("KN", kn)
			leg.set_meta("AN", an)
			leg.set_meta("base_yaw", leg.rotation.y)
			parts.append(leg)
		root.set_meta("leg_parts", parts)
		root.set_meta("leg_type", "hex" if parts.size() >= 5 else "quad")
		return

	var tr_l := root.get_node_or_null("Track_L") as Node3D
	var tr_r := root.get_node_or_null("Track_R") as Node3D
	if tr_l != null and tr_r != null:
		root.set_meta("leg_parts", [tr_l, tr_r])
		root.set_meta("leg_type", "tread")
		return

	root.set_meta("leg_parts", [])
	root.set_meta("leg_type", "biped")
