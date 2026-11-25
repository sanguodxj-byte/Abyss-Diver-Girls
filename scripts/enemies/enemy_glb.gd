extends RefCounted
## 机械虫群（Legion / Faro / Simulant 风格）高精度 GLB 运行时加载器
## 统一阵营配色铁律：100% 冷锻暗黑枪钢（Charcoal-Black / Dark Gunmetal Titanium）+ 紫罗兰电浆辉光（Neon Violet）！

const A = preload("res://scripts/art.gd")
const MechGlb = preload("res://scripts/modules/mech_glb.gd")
const BossGlb = preload("res://scripts/enemies/boss_glb.gd")

const ENEMY_GLB_DIR := "res://assets/models/enemies/"
const BOSS_GLB_DIR := "res://assets/models/boss/"

const SWARM_GLOW := Color(0.74, 0.26, 1.00)
const SWARM_CORE_GLOW := Color(0.86, 0.42, 1.00)

static var _packed_cache := {}
static var _swarm_mat_cache := {}


static func _load_glb_scene(res_path: String) -> Node3D:
	var ps: PackedScene = _packed_cache.get(res_path)
	if ps == null and ResourceLoader.exists(res_path):
		var loaded := load(res_path)
		if loaded is PackedScene:
			ps = loaded
			_packed_cache[res_path] = ps
	if ps != null:
		return ps.instantiate() as Node3D
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(abs_p, st) == OK:
			return doc.generate_scene(st) as Node3D
	return null


static func has_enemy_glb(kind: String) -> bool:
	var p := "%s%s.glb" % [ENEMY_GLB_DIR, kind]
	if _packed_cache.has(p) or ResourceLoader.exists(p):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(p))


static func _swarm_slot_mat(slot: String, armor_tint: Color) -> Material:
	var key := "%s|%s" % [slot, armor_tint.to_html(false)]
	if _swarm_mat_cache.has(key):
		return _swarm_mat_cache[key]
	var m: Material = null
	match slot:
		"armor":
			m = MechGlb._trim_mat(armor_tint, 0.80, 0.35, 0.48, 0.0, 0.0, 1.24, 0.46)
		"armor_sub":
			m = MechGlb._trim_mat(armor_tint.lightened(0.12), 0.84, 0.31, 0.52, 0.0, 0.0, 1.22, 0.44)
		"armor_dark", "dark":
			m = MechGlb._trim_mat(Color(0.075, 0.080, 0.105), 0.68, 0.44, 0.34, 0.0, 0.0, 1.18, 0.40)
		"gunmetal":
			m = MechGlb._trim_mat(Color(0.27, 0.29, 0.35), 0.90, 0.28, 0.44, 0.0, 0.0, 1.20, 0.42)
		"chrome":
			m = MechGlb._trim_mat(Color(0.60, 0.63, 0.72), 0.95, 0.18, 0.22, 0.0, 0.0, 1.05, 0.28)
		"armor_oxide", "accent", "hazard":
			# 阳极氧化暗紫钛合金饰板（彻底杜绝黄黑工程条与铁锈红）
			m = MechGlb._trim_mat(Color(0.27, 0.13, 0.45), 0.78, 0.30, 0.46, 0.0, 0.0, 1.20, 0.40)
		"copper", "brass":
			# 紫罗兰超导励磁线圈金属
			m = MechGlb._trim_mat(Color(0.38, 0.19, 0.62), 0.86, 0.25, 0.32, 0.0, 0.0, 1.15, 0.35)
		"rubber":
			m = MechGlb._trim_mat(Color(0.055, 0.058, 0.075), 0.16, 0.76, 0.14, 0.0, 0.0, 1.10, 0.35)
		"bore":
			m = A.paint(Color(0.02, 0.02, 0.03), 0.20, 0.92, {"panel_scale": 0.0})
		"glass":
			m = A.emit(SWARM_CORE_GLOW, 1.45)
		"decal":
			m = MechGlb._trim_mat(Color(0.34, 0.17, 0.56), 0.80, 0.28, 0.20, 0.0)
		"emit_core":
			m = A.emit(SWARM_CORE_GLOW, 1.85)
		_:
			if slot.begins_with("emit_"):
				m = A.emit(SWARM_GLOW, 1.55)
			else:
				m = MechGlb._trim_mat(armor_tint, 0.80, 0.35, 0.48, 0.0, 0.0, 1.24, 0.46)
	_swarm_mat_cache[key] = m
	return m


static func _unit_armor_tint(kind: String) -> Color:
	# 全员严格统一在冷调金属灰黑（#1F222A ~ #2A2E38）区间内微调明度层次，绝不偏离灰黑紫体系
	match kind:
		"ling", "mantis", "ripper":
			return Color(0.15, 0.16, 0.20)
		"spitter", "mortar", "lancer":
			return Color(0.18, 0.19, 0.24)
		"beetle", "ironjaw", "colossus":
			return Color(0.13, 0.14, 0.18)
		"crystal_bug", "prism_archon", "shielder", "overseer":
			return Color(0.17, 0.17, 0.23)
		_:
			return Color(0.16, 0.17, 0.21)


static func _apply_swarm_materials(b, root: Node3D, armor_col: Color) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.mesh is ArrayMesh:
			mi.mesh = BossGlb._get_sanitized_mesh(mi.mesh as ArrayMesh)
		var nm := str(mi.name)
		var slot := "armor"
		var sep := nm.find("__")
		if sep >= 0:
			slot = nm.substr(sep + 2)
			var tail_dot := slot.find(".")
			if tail_dot >= 0:
				slot = slot.substr(0, tail_dot)
		var p_node := mi.get_parent()
		var in_gun_glow := p_node != null and str(p_node.name).begins_with("GunGlow")
		if in_gun_glow:
			var gmat := StandardMaterial3D.new()
			gmat.albedo_color = Color(0.03, 0.02, 0.05)
			gmat.roughness = 0.32
			gmat.metallic = 0.35
			gmat.emission_enabled = true
			gmat.emission = SWARM_CORE_GLOW
			gmat.emission_energy_multiplier = 0.0
			mi.material_override = gmat
			mi.set_meta("no_flash", true)
		elif slot == "decal":
			# 隐藏人类军用战术编号贴花，保持纯粹异星/自律机械军团折面装甲
			mi.visible = false
			mi.set_meta("no_flash", true)
			mi.set_meta("no_ground_bounds", true)
		else:
			mi.material_override = _swarm_slot_mat(slot, armor_col)
			if slot.begins_with("emit_") or slot == "glass":
				mi.set_meta("no_flash", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.parts.append(mi)


static func spawn_boss_kit(h, parent: Node3D, kit_id: String, armor_col := Color(0.15, 0.16, 0.20), _glow_col := SWARM_GLOW,
		sc_vec := Vector3.ONE, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> Node3D:
	var res_path := "%s%s.glb" % [BOSS_GLB_DIR, kit_id]
	var inst := _load_glb_scene(res_path)
	var wrap := Node3D.new()
	wrap.name = kit_id.to_pascal_case()
	wrap.position = pos
	wrap.rotation_degrees = rot_deg
	wrap.scale = Vector3(maxf(sc_vec.x, 0.001), maxf(sc_vec.y, 0.001), maxf(sc_vec.z, 0.001))
	parent.add_child(wrap)
	if inst != null:
		wrap.add_child(inst)
		_apply_swarm_materials(h, inst, armor_col)
	return wrap


static func _first_mesh_in(root: Node, prefer_emit := false) -> MeshInstance3D:
	var fallback: MeshInstance3D = null
	for ch in root.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			if fallback == null:
				fallback = mi
			if prefer_emit and str(mi.name).contains("__emit_"):
				return mi
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi2 := n as MeshInstance3D
		if fallback == null:
			fallback = mi2
		if prefer_emit and str(mi2.name).contains("__emit_"):
			return mi2
	return fallback


static func _idx_suffix(nm: String) -> int:
	var us := nm.rfind("_")
	if us >= 0 and us + 1 < nm.length():
		var sub := nm.substr(us + 1)
		if sub.is_valid_int():
			return sub.to_int()
	return 0


static func build(b, body: Node3D, kind: String, s: float) -> bool:
	var res_path := "%s%s.glb" % [ENEMY_GLB_DIR, kind]
	var inst := _load_glb_scene(res_path)
	if inst == null:
		return false

	b.set_meta("hd_glb", true)
	inst.name = "HDModel"
	inst.scale = Vector3.ONE * maxf(s, 0.01)
	body.add_child(inst)

	_apply_swarm_materials(b, inst, _unit_armor_tint(kind))

	var hip_nodes: Array = []
	var jaw_nodes: Array = []
	var scythe_nodes: Array = []
	var wing_nodes: Array = []
	var plate_nodes: Array = []
	var crystal_nodes: Array = []
	var sac_nodes: Array = []

	var all_nodes: Array[Node] = []
	for ch in inst.get_children():
		all_nodes.append(ch)
	for ch in inst.find_children("*", "Node3D", true, false):
		if not all_nodes.has(ch):
			all_nodes.append(ch)

	for raw in all_nodes:
		if not (raw is Node3D) or (raw is MeshInstance3D):
			continue
		var nd := raw as Node3D
		var nm := str(nd.name)
		if nm.begins_with("Hip_"):
			hip_nodes.append(nd)
		elif nm.begins_with("Jaw_"):
			jaw_nodes.append(nd)
		elif nm.begins_with("Scythe_"):
			scythe_nodes.append(nd)
		elif nm.begins_with("Wing_"):
			wing_nodes.append(nd)
		elif nm.begins_with("Plate_"):
			plate_nodes.append(nd)
		elif nm.begins_with("Crystal_"):
			crystal_nodes.append(nd)
		elif nm.begins_with("Sac_"):
			sac_nodes.append(nd)
		elif nm == "SacMain":
			var smi := _first_mesh_in(nd, true)
			if smi != null:
				b.sac = smi
		elif nm == "CoreGlow":
			var cmi := _first_mesh_in(nd, true)
			if cmi != null and ("core_mi" in b):
				b.core_mi = cmi
		elif nm == "Crown":
			if "crown" in b:
				b.crown = nd
		elif nm == "Abdomen":
			if "abdomen" in b:
				b.abdomen = nd
		elif nm == "Turret":
			if "turret" in b:
				b.turret = nd
		elif nm == "Gun":
			b.gun = nd
		elif nm == "GunTip":
			b.gun_tip = nd
		elif nm == "GunGlow":
			var gmi := _first_mesh_in(nd, true)
			if gmi != null:
				b.gun_glow = gmi
		elif nm.begins_with("Spinner_Z"):
			b.spinners.append([nd, Vector3.BACK, 2.8, 18.0])
		elif nm.begins_with("Spinner_Y"):
			b.spinners.append([nd, Vector3.UP, 2.2, 7.5])
		elif nm.begins_with("Spinner_X"):
			b.spinners.append([nd, Vector3.RIGHT, 3.2, 22.0])
		elif nm.begins_with("Wheel_X"):
			var whls: Array = b.get_meta("hd_wheels") if b.has_meta("hd_wheels") else []
			whls.append(nd)
			b.set_meta("hd_wheels", whls)

	var by_idx := func(a: Node3D, c: Node3D) -> bool:
		return _idx_suffix(str(a.name)) < _idx_suffix(str(c.name))

	hip_nodes.sort_custom(by_idx)
	for i in hip_nodes.size():
		var hip: Node3D = hip_nodes[i]
		var idx := _idx_suffix(str(hip.name))
		var row_i := idx / 2
		var sx := -1.0 if hip.position.x < 0.0 else 1.0
		var ph := float(row_i % 2) * PI + (PI if sx > 0.0 else 0.0)
		var kj := hip.get_node_or_null("Knee") as Node3D
		if kj != null:
			hip.set_meta("knee", kj)
		hip.set_meta("side", sx)
		hip.set_meta("phase", ph)
		hip.set_meta("base_y", hip.rotation.y)
		b.legs.append(hip)

	jaw_nodes.sort_custom(by_idx)
	for j in jaw_nodes:
		b.jaws.append(j)

	scythe_nodes.sort_custom(by_idx)
	for sc in scythe_nodes:
		b.scythes.append(sc)

	wing_nodes.sort_custom(by_idx)
	if b.get("wings") is Array:
		for w in wing_nodes:
			var wsx := -1.0 if (w as Node3D).position.x < 0.0 else 1.0
			(w as Node3D).set_meta("side", wsx)
			b.wings.append(w)

	plate_nodes.sort_custom(by_idx)
	if b.get("plates") is Array:
		for pl in plate_nodes:
			var psx := -1.0 if (pl as Node3D).position.x < 0.0 else 1.0
			(pl as Node3D).set_meta("side", psx)
			b.plates.append(pl)

	crystal_nodes.sort_custom(by_idx)
	if b.get("crystals") is Array:
		for cr in crystal_nodes:
			(cr as Node3D).set_meta("base_scale", (cr as Node3D).scale)
			b.crystals.append(cr)

	sac_nodes.sort_custom(by_idx)
	if b.get("sacs") is Array:
		for sc_n in sac_nodes:
			b.sacs.append(sc_n)
			if b.sac == null:
				var first_m := _first_mesh_in(sc_n, false)
				if first_m != null:
					b.sac = first_m

	return true
