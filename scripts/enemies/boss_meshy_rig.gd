extends RefCounted
## 科幻机械虫群（86 Legion / HZD Faro / SC2 Simulant 风格）全首领 2K PBR + Kitbash 模块化组装器
## 统一阵营配色：100% 冷锻暗黑枪钢（Charcoal-Black / Dark Gunmetal Titanium）+ 紫罗兰电浆辉光（Neon Violet）！
## 覆盖除 citadel_behemoth / sky_carrier 外的全部 19 只首领（含 excavator_titan）。

const ART = preload("res://scripts/art.gd")
const BossGlb = preload("res://scripts/enemies/boss_glb.gd")
const EnemyGlb = preload("res://scripts/enemies/enemy_glb.gd")

const VIOLET_CORE := Color(0.84, 0.36, 1.00)

static var _packed_cache := {}
static var _mat_cache := {}

const CONFIGS := {
	"broodmother": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.56, 1.48, 1.56), "by": 1.08,
		"leg_n": 4, "leg_x": 0.62, "leg_z0": -0.60, "leg_dz": 0.40, "leg_reach": 1.26, "leg_th": 1.04,
		"arms": "reaper_blades", "pods": 3, "core_pos": Vector3(0.0, -0.06, -1.08),
	},
	"grey_brood": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.56, 1.46, 1.56), "by": 1.06,
		"leg_n": 3, "leg_x": 0.60, "leg_z0": -0.52, "leg_dz": 0.52, "leg_reach": 1.24, "leg_th": 1.04,
		"arms": "plasma_jaws", "pods": 3, "core_pos": Vector3(0.0, -0.06, -1.10),
	},
	"dust_matriarch": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.58, 1.48, 1.58), "by": 1.08,
		"leg_n": 4, "leg_x": 0.64, "leg_z0": -0.60, "leg_dz": 0.40, "leg_reach": 1.26, "leg_th": 1.06,
		"arms": "plasma_jaws", "pods": 3, "core_pos": Vector3(0.0, -0.06, -1.12),
	},
	"king_beetle": {
		"hull_yaw": 180.0, "hull_sc": Vector3(1.64, 1.50, 1.64), "by": 1.10,
		"leg_n": 3, "leg_x": 0.66, "leg_z0": -0.54, "leg_dz": 0.54, "leg_reach": 1.20, "leg_th": 1.14,
		"arms": "reaper_blades", "pods": 2, "core_pos": Vector3(0.0, 0.02, -1.16),
	},
	"iron_warden": {
		"hull_yaw": 180.0, "hull_sc": Vector3(1.56, 1.50, 1.56), "by": 1.10,
		"leg_n": 3, "leg_x": 0.66, "leg_z0": -0.52, "leg_dz": 0.52, "leg_reach": 1.18, "leg_th": 1.14,
		"arms": "blades_turret", "pods": 2, "core_pos": Vector3(0.0, 0.02, -1.12),
	},
	"abyss_queen": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.58, 1.48, 1.58), "by": 1.20,
		"leg_n": 4, "leg_x": 0.60, "leg_z0": -0.54, "leg_dz": 0.36, "leg_reach": 1.30, "leg_th": 1.08,
		"arms": "queen_blades", "pods": 3, "core_pos": Vector3(0.0, 0.02, -1.04),
	},
	"harbor_reaper": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.54, 1.46, 1.54), "by": 1.20,
		"leg_n": 3, "leg_x": 0.54, "leg_z0": -0.46, "leg_dz": 0.46, "leg_reach": 1.28, "leg_th": 1.04,
		"arms": "quad_blades", "pods": 2, "core_pos": Vector3(0.0, 0.04, -1.06),
	},
	"slag_colossus": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.62, 1.50, 1.62), "by": 1.10,
		"leg_n": 4, "leg_x": 0.66, "leg_z0": -0.60, "leg_dz": 0.40, "leg_reach": 1.20, "leg_th": 1.08,
		"arms": "artillery", "pods": 2, "core_pos": Vector3(0.0, -0.02, -1.14),
	},
	"dune_devourer": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.56, 1.48, 1.56), "by": 1.06,
		"leg_n": 3, "leg_x": 0.62, "leg_z0": -0.50, "leg_dz": 0.50, "leg_reach": 1.16, "leg_th": 1.04,
		"arms": "auger_drill", "pods": 2, "core_pos": Vector3(0.0, 0.22, -1.02),
	},
	"prism_archon": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.50, 1.48, 1.50), "by": 1.16,
		"leg_n": 4, "leg_x": 0.62, "leg_z0": -0.54, "leg_dz": 0.36, "leg_reach": 1.26, "leg_th": 1.04,
		"arms": "phase_prism", "pods": 2, "core_pos": Vector3(0.0, 0.02, -1.06),
	},
	"gorge_tyrant": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.58, 1.48, 1.58), "by": 1.10,
		"leg_n": 3, "leg_x": 0.64, "leg_z0": -0.52, "leg_dz": 0.52, "leg_reach": 1.20, "leg_th": 1.12,
		"arms": "plasma_saws", "pods": 2, "core_pos": Vector3(0.0, 0.0, -1.14),
	},
	"abyss_harbinger": {
		"hull_yaw": 90.0, "hull_sc": Vector3(1.54, 1.48, 1.54), "by": 1.18,
		"leg_n": 3, "leg_x": 0.62, "leg_z0": -0.50, "leg_dz": 0.50, "leg_reach": 1.24, "leg_th": 1.10,
		"arms": "harbinger", "pods": 2, "core_pos": Vector3(0.0, 0.02, -1.08),
	},
	"terminus_warden": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.62, 1.48, 1.62), "by": 1.08,
		"leg_n": 3, "leg_x": 0.60, "leg_z0": -0.48, "leg_dz": 0.48, "leg_reach": 1.20, "leg_th": 1.10,
		"arms": "warden_guns", "pods": 2, "core_pos": Vector3(0.0, -0.02, -1.14),
	},
	"foundry_dreadnought": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.60, 1.50, 1.60), "by": 1.12,
		"leg_n": 4, "leg_x": 0.66, "leg_z0": -0.60, "leg_dz": 0.40, "leg_reach": 1.20, "leg_th": 1.10,
		"arms": "blades_turret", "pods": 2, "core_pos": Vector3(0.0, 0.02, -1.16),
	},
	"silo_warhead": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.60, 1.48, 1.60), "by": 1.08,
		"leg_n": 3, "leg_x": 0.60, "leg_z0": -0.48, "leg_dz": 0.48, "leg_reach": 1.20, "leg_th": 1.08,
		"arms": "warden_guns", "pods": 2, "core_pos": Vector3(0.0, -0.02, -1.14),
	},
	"spillway_leviathan": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.60, 1.48, 1.60), "by": 1.10,
		"leg_n": 3, "leg_x": 0.62, "leg_z0": -0.50, "leg_dz": 0.50, "leg_reach": 1.22, "leg_th": 1.10,
		"arms": "reaper_blades", "pods": 2, "core_pos": Vector3(0.0, 0.0, -1.14),
	},
	"excavator_titan": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.62, 1.50, 1.62), "by": 1.12,
		"leg_n": 4, "leg_x": 0.66, "leg_z0": -0.60, "leg_dz": 0.40, "leg_reach": 1.22, "leg_th": 1.12,
		"arms": "plasma_saws", "pods": 2, "core_pos": Vector3(0.0, 0.02, -1.16),
	},
	"core_overlord": {
		"hull_yaw": 180.0, "hull_sc": Vector3(1.58, 1.50, 1.58), "by": 1.16,
		"leg_n": 3, "leg_x": 0.64, "leg_z0": -0.52, "leg_dz": 0.52, "leg_reach": 1.26, "leg_th": 1.10,
		"arms": "overlord", "pods": 2, "core_pos": Vector3(0.0, 0.02, -1.12),
	},
	"drydock_behemoth": {
		"hull_yaw": -90.0, "hull_sc": Vector3(1.66, 1.50, 1.66), "by": 1.12,
		"leg_n": 4, "leg_x": 0.66, "leg_z0": -0.60, "leg_dz": 0.40, "leg_reach": 1.22, "leg_th": 1.12,
		"arms": "blades_turret", "pods": 2, "core_pos": Vector3(0.0, 0.0, -1.18),
	},
}


static func supports(kind: String) -> bool:
	return CONFIGS.has(kind)


static func _prepare_glb_mat(src: Material) -> Material:
	if src == null:
		return null
	var mid := src.get_instance_id()
	if _mat_cache.has(mid):
		return _mat_cache[mid]
	if src is StandardMaterial3D:
		var sm := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
		sm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if ART.is_mobile_perf() else BaseMaterial3D.DIFFUSE_BURLEY
		sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if ART.is_mobile_perf() else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.albedo_color = Color(0.92, 0.92, 0.98)
		if sm.normal_enabled:
			sm.normal_scale = 1.30
		_mat_cache[mid] = sm
		return sm
	_mat_cache[mid] = src
	return src


static func spawn_meshy_glb(h, parent: Node3D, model_id: String, sc_vec: Vector3, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = model_id.to_pascal_case()
	wrap.position = pos
	wrap.rotation_degrees = rot_deg
	wrap.scale = Vector3(maxf(sc_vec.x, 0.001), maxf(sc_vec.y, 0.001), maxf(sc_vec.z, 0.001))
	parent.add_child(wrap)

	var path := "res://assets/models/boss/%s.glb" % model_id
	var ps: PackedScene = _packed_cache.get(path)
	if ps == null and ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is PackedScene:
			ps = loaded
			_packed_cache[path] = ps
	var inst: Node = ps.instantiate() if ps != null else null
	if inst == null:
		var abs_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(abs_p, st) == OK:
				inst = doc.generate_scene(st)
	if inst != null:
		wrap.add_child(inst)
		var mob_perf := ART.is_mobile_perf()
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			if mi.mesh is ArrayMesh:
				mi.mesh = BossGlb._get_sanitized_mesh(mi.mesh as ArrayMesh)
			if mi.material_override == null:
				var active_m := mi.get_active_material(0)
				if active_m != null:
					mi.material_override = _prepare_glb_mat(active_m)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if mob_perf:
				mi.visibility_range_end = 155.0
				mi.visibility_range_end_margin = 6.0
			h.parts.append(mi)
	return wrap


static func _bind_kit_nodes(h, kit_root: Node3D, reg_crystals := false) -> void:
	for n in kit_root.find_children("*", "Node3D", true, false):
		var nd := n as Node3D
		if nd == null or (nd is MeshInstance3D):
			continue
		var nm := str(nd.name)
		if nm.begins_with("Spinner_X"):
			h.spinners.append([nd, Vector3.RIGHT, 3.5, 24.0])
		elif nm.begins_with("Spinner_Y"):
			h.spinners.append([nd, Vector3.UP, 2.0, 7.5])
		elif nm.begins_with("Spinner_Z"):
			h.spinners.append([nd, Vector3.BACK, 3.0, 20.0])
		elif reg_crystals and nm.begins_with("Crystal_"):
			nd.set_meta("base_scale", nd.scale)
			h.crystals.append(nd)


static func build(h, body: Node3D, kind: String, s: float) -> bool:
	if not CONFIGS.has(kind):
		return false
	var cfg: Dictionary = CONFIGS[kind]
	h.set_meta("meshy_boss", true)
	h.set_meta("hd_glb", true)

	var by: float = float(cfg.get("by", 1.10)) * s
	var armor_col := Color(0.15, 0.16, 0.20)

	var belly_ao := ART.ground_vfx(h, ART.blob_tex(), Color(0.02, 0.015, 0.035, 0.88), 3.6 * s, Vector3(0.0, 0.035, 0.0), false, 0.40, false, 1)
	belly_ao.set_meta("no_flash", true)

	# 1. 无损 2K PBR Meshy 机械虫主躯壳 + 八角隐身腹底承力架
	var hull_sc: Vector3 = cfg["hull_sc"] * s
	var hull_yaw: float = float(cfg.get("hull_yaw", -90.0))
	var hull_root := Node3D.new()
	hull_root.name = "SwarmHull"
	hull_root.position = Vector3(0.0, by, 0.0)
	body.add_child(hull_root)
	spawn_meshy_glb(h, hull_root, "%s_hull" % kind, hull_sc, Vector3.ZERO, Vector3(0.0, hull_yaw, 0.0))

	var leg_n: int = int(cfg.get("leg_n", 3))
	var leg_x: float = float(cfg.get("leg_x", 0.62))
	var leg_z0: float = float(cfg.get("leg_z0", -0.52))
	var leg_dz: float = float(cfg.get("leg_dz", 0.52))
	var span_z: float = maxf(float(leg_n - 1) * leg_dz + 0.36, 0.90)
	EnemyGlb.spawn_boss_kit(h, body, "kit_boss_chassis", armor_col, VIOLET_CORE,
		Vector3(leg_x * 1.55, 1.0, span_z * 0.88) * s, Vector3(0.0, by - 0.26 * s, 0.0))

	# 2. 多关节 86-Legion / Deathbringer 风格暗黑枪钢机械节肢（`boss_legion_leg.glb` + `kit_boss_femur` + `kit_boss_talon_foot`）
	var leg_reach := float(cfg.get("leg_reach", 1.22))
	var leg_th := float(cfg.get("leg_th", 1.08))
	var hip_y := by - 0.22 * s
	var shin_out_yaw_r := float(cfg.get("leg_yaw_r", 180.0))
	for i in leg_n:
		var lz := (leg_z0 + float(i) * leg_dz) * s
		var yaw_spread := lerpf(-28.0, 28.0, float(i) / maxf(float(leg_n - 1), 1.0)) if leg_n > 1 else 0.0
		for sx: float in [-1.0, 1.0]:
			var ph: float = float(i % 2) * PI + (PI if sx > 0.0 else 0.0)
			_add_legion_limb(h, body, Vector3(sx * leg_x * s, hip_y, lz), sx * yaw_spread, sx, s, hip_y, ph,
				leg_reach, leg_th, shin_out_yaw_r, armor_col)

	# 3. 六角隐身双开电浆反应核舱门（`kit_boss_core_vault` + `kit_boss_core_door_l/r`）
	var cpos_rel: Vector3 = cfg.get("core_pos", Vector3(0.0, 0.0, -1.12)) * s
	_add_core_doors_glb(h, body, Vector3(0.0, by - 0.10 * s, 0.0) + cpos_rel * 0.88, s * 0.80, armor_col)

	# 4. 背脊暗紫电浆电容/孵化仓弱点组（`kit_boss_plasma_pod`）
	var pod_cnt: int = int(cfg.get("pods", 2))
	for pi in pod_cnt:
		var u_p := float(pi) - float(pod_cnt - 1) * 0.5
		var ppos := Vector3(u_p * 0.34 * s, by + 0.06 * s, (0.72 + absf(u_p) * 0.06) * s)
		var pod := EnemyGlb.spawn_boss_kit(h, body, "kit_boss_plasma_pod", armor_col, VIOLET_CORE, Vector3(0.68, 0.50, 0.68) * s, ppos)
		var pod_inner: Node3D = (pod.get_child(0) as Node3D) if pod.get_child_count() > 0 else pod
		h.sacs.append(pod_inner)
		if h.sac == null:
			for n in pod.find_children("*", "MeshInstance3D", true, false):
				h.sac = n as MeshInstance3D
				break

	# 5. 专属灰黑紫机械虫武装总成
	_build_swarm_weapons(h, body, str(cfg.get("arms", "reaper_blades")), by, s, armor_col)
	return true


static func _add_legion_limb(h, body: Node3D, hip_pos: Vector3, yaw_deg: float, sx: float, s: float,
		by_h: float, phase: float, reach: float, th: float, shin_yaw_r: float, armor_col: Color) -> void:
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	body.add_child(hip)

	var fem_sc := 0.90 * reach * s
	var fem_id := "kit_boss_femur_r" if sx > 0.0 else "kit_boss_femur_l"
	EnemyGlb.spawn_boss_kit(h, hip, fem_id, armor_col, VIOLET_CORE, Vector3(fem_sc, fem_sc * th, fem_sc * th))

	var knee := Vector3(sx * 0.64 * fem_sc, 0.34 * fem_sc * th, 0.0)
	var foot := Vector3(sx * 1.04 * reach * s, -by_h, 0.0)
	var kj := Node3D.new()
	kj.name = "Knee"
	kj.position = knee
	hip.add_child(kj)

	var foot_rel := foot - knee
	var drop_h := maxf(-foot_rel.y, 0.42 * s)
	var tilt_rad := deg_to_rad(11.0)
	var shin_sc := (drop_h + 0.06 * s) / (1.584 * cos(tilt_rad))
	var shin_yaw := shin_yaw_r if sx > 0.0 else (shin_yaw_r + 180.0)
	spawn_meshy_glb(h, kj, "boss_legion_leg", Vector3(shin_sc * th, shin_sc, shin_sc * th),
		Vector3(0.0, 0.06 * s, 0.0), Vector3(0.0, shin_yaw, -sx * 11.0))

	hip.set_meta("knee", kj)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	h.legs.append(hip)


static func _add_core_doors_glb(h, body: Node3D, pos: Vector3, s: float, armor_col: Color) -> void:
	var vault := EnemyGlb.spawn_boss_kit(h, body, "kit_boss_core_vault", armor_col, VIOLET_CORE, Vector3.ONE * s, pos)
	for n in vault.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if str(mi.name).contains("__emit_"):
			mi.material_override = ART.emit(VIOLET_CORE, 1.55).duplicate()
			h.core_mi = mi
			break
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.name = "CoreDoorR" if sx > 0.0 else "CoreDoorL"
		pl.position = pos + Vector3(sx * 0.25 * s, 0.0, -0.10 * s)
		pl.set_meta("side", sx)
		body.add_child(pl)
		var door_id := "kit_boss_core_door_r" if sx > 0.0 else "kit_boss_core_door_l"
		EnemyGlb.spawn_boss_kit(h, pl, door_id, armor_col, VIOLET_CORE, Vector3.ONE * s)
		h.plates.append(pl)


static func _spawn_reaper_blade_arm(h, body: Node3D, pos: Vector3, sx: float, s: float, sc_mult: float,
		armor_col: Color, blade_base_yaw := -90.0) -> Node3D:
	var arm := Node3D.new()
	arm.position = pos
	arm.rotation_degrees = Vector3(0.0, sx * 14.0, 0.0)
	body.add_child(arm)

	var bm_s := s * sc_mult
	var boom_id := "kit_boss_arm_boom_r" if sx > 0.0 else "kit_boss_arm_boom_l"
	EnemyGlb.spawn_boss_kit(h, arm, boom_id, armor_col, VIOLET_CORE, Vector3.ONE * bm_s)

	var el := Vector3(sx * 0.22, -0.06, -0.46) * bm_s
	var bl_pos := el + Vector3(sx * 0.04, -0.06, -0.44) * bm_s
	spawn_meshy_glb(h, arm, "boss_reaper_blade", Vector3.ONE * (0.76 * bm_s), bl_pos, Vector3(0.0, blade_base_yaw + sx * 10.0, 0.0))
	h.scythes.append(arm)
	return arm


static func _spawn_plasma_jaws(h, body: Node3D, pos: Vector3, s: float, armor_col: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		var j := Node3D.new()
		j.position = pos + Vector3(sx * 0.38 * s, 0.0, 0.0)
		body.add_child(j)
		var jid := "kit_boss_plasma_jaw_r" if sx > 0.0 else "kit_boss_plasma_jaw_l"
		EnemyGlb.spawn_boss_kit(h, j, jid, armor_col, VIOLET_CORE, Vector3.ONE * s)
		h.jaws.append(j)


static func _spawn_pulse_gatlings(h, body: Node3D, by: float, s: float, armor_col: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		var pod := EnemyGlb.spawn_boss_kit(h, body, "kit_boss_pulse_gatling", armor_col, VIOLET_CORE,
			Vector3.ONE * (0.96 * s), Vector3(sx * 0.64 * s, by + 0.36 * s, -0.28 * s))
		_bind_kit_nodes(h, pod)


static func _spawn_phase_crown(h, body: Node3D, pos: Vector3, s: float, armor_col: Color, reg_crys := false) -> void:
	var cr := EnemyGlb.spawn_boss_kit(h, body, "kit_boss_phase_crown", armor_col, VIOLET_CORE, Vector3.ONE * s, pos)
	_bind_kit_nodes(h, cr, reg_crys)
	h.crown = cr
	h.spinners.append([cr, Vector3.UP, 1.2, 4.8])


static func _spawn_plasma_turret(h, body: Node3D, pos: Vector3, sc_mult: float, s: float, base_yaw := -90.0) -> void:
	var tur := spawn_meshy_glb(h, body, "boss_plasma_turret", Vector3.ONE * (sc_mult * s), pos, Vector3(0.0, base_yaw, 0.0))
	h.turret = tur


static func _build_swarm_weapons(h, body: Node3D, mode: String, by: float, s: float, armor_col: Color) -> void:
	match mode:
		"plasma_jaws":
			_spawn_plasma_jaws(h, body, Vector3(0.0, by - 0.14 * s, -0.98 * s), s, armor_col)
		"reaper_blades":
			for sx: float in [-1.0, 1.0]:
				_spawn_reaper_blade_arm(h, body, Vector3(sx * 0.68 * s, by + 0.04 * s, -0.50 * s), sx, s, 1.04, armor_col)
		"queen_blades":
			for sx: float in [-1.0, 1.0]:
				_spawn_reaper_blade_arm(h, body, Vector3(sx * 0.66 * s, by + 0.10 * s, -0.46 * s), sx, s, 1.08, armor_col)
			_spawn_phase_crown(h, body, Vector3(0.0, by + 0.68 * s, 0.0), 0.94 * s, armor_col, true)
		"quad_blades":
			for row in 2:
				for sx: float in [-1.0, 1.0]:
					_spawn_reaper_blade_arm(h, body,
						Vector3(sx * (0.58 + row * 0.12) * s, by + (0.22 - row * 0.26) * s, (-0.38 + row * 0.16) * s),
						sx, s, 0.96 - row * 0.10, armor_col)
		"artillery":
			_spawn_plasma_turret(h, body, Vector3(0.0, by + 0.56 * s, 0.08 * s), 0.76, s)
			_spawn_plasma_jaws(h, body, Vector3(0.0, by - 0.14 * s, -1.00 * s), s * 0.92, armor_col)
		"auger_drill":
			var dr := EnemyGlb.spawn_boss_kit(h, body, "kit_boss_plasma_auger", armor_col, VIOLET_CORE,
				Vector3.ONE * (1.16 * s), Vector3(0.0, by - 0.02 * s, -1.06 * s))
			_bind_kit_nodes(h, dr)
			_spawn_plasma_jaws(h, body, Vector3(0.0, by - 0.16 * s, -0.94 * s), s * 0.88, armor_col)
		"phase_prism":
			_spawn_phase_crown(h, body, Vector3(0.0, by + 0.72 * s, 0.0), 1.02 * s, armor_col, true)
			_spawn_plasma_jaws(h, body, Vector3(0.0, by - 0.14 * s, -0.96 * s), s * 0.90, armor_col)
		"plasma_saws":
			for sx: float in [-1.0, 1.0]:
				var arm := Node3D.new()
				arm.position = Vector3(sx * 0.68 * s, by + 0.06 * s, -0.46 * s)
				body.add_child(arm)
				var boom_id := "kit_boss_arm_boom_r" if sx > 0.0 else "kit_boss_arm_boom_l"
				EnemyGlb.spawn_boss_kit(h, arm, boom_id, armor_col, VIOLET_CORE, Vector3.ONE * (1.10 * s))
				var wr := Vector3(sx * 0.24, -0.10, -0.58) * s
				var saw := EnemyGlb.spawn_boss_kit(h, arm, "kit_boss_plasma_saw", armor_col, VIOLET_CORE, Vector3.ONE * (1.02 * s), wr)
				_bind_kit_nodes(h, saw)
				h.scythes.append(arm)
		"harbinger":
			for sx: float in [-1.0, 1.0]:
				_spawn_reaper_blade_arm(h, body, Vector3(sx * 0.64 * s, by + 0.10 * s, -0.44 * s), sx, s, 1.02, armor_col)
			_spawn_phase_crown(h, body, Vector3(0.0, by + 0.70 * s, 0.04 * s), 0.96 * s, armor_col, false)
		"warden_guns":
			_spawn_pulse_gatlings(h, body, by, s, armor_col)
			_spawn_plasma_jaws(h, body, Vector3(0.0, by - 0.16 * s, -1.00 * s), s * 0.92, armor_col)
		"blades_turret":
			for sx: float in [-1.0, 1.0]:
				_spawn_reaper_blade_arm(h, body, Vector3(sx * 0.68 * s, by + 0.04 * s, -0.50 * s), sx, s, 1.04, armor_col)
			_spawn_plasma_turret(h, body, Vector3(0.0, by + 0.56 * s, -0.04 * s), 0.74, s)
		"overlord":
			_spawn_phase_crown(h, body, Vector3(0.0, by + 0.68 * s, 0.04 * s), 0.98 * s, armor_col, false)
			_spawn_pulse_gatlings(h, body, by, s, armor_col)
			for sx: float in [-1.0, 1.0]:
				_spawn_reaper_blade_arm(h, body, Vector3(sx * 0.66 * s, by + 0.06 * s, -0.48 * s), sx, s, 0.98, armor_col)
