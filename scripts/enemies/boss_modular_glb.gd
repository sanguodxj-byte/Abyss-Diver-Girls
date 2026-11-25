extends RefCounted
## 科幻机械虫群超巨型首领组装与关节驱动器（统一暗黑枪钢 + 紫罗兰电浆配色）：
##   1) citadel_behemoth（Horus 级超重型六足机械母巢要塞，全高 ~16.5m，宽逾 28m）：
##      组装 citadel_behemoth_hull + 6 条独立铰接 `boss_legion_leg` 巨型节肢 + 1 座中置主电浆轨道炮塔 + 6 座舷侧副炮塔；
##   2) sky_carrier（Eclipse 级隐身飞翼机械虫空天母舰，全长 ~15m）：
##      组装 sky_carrier_hull + 4 具倾转矢量紫核离子推进舱 `boss_vtol_thruster` + 3 座舰载电浆轨道炮塔 `boss_plasma_turret`。

const ART = preload("res://scripts/art.gd")
const BossGlb = preload("res://scripts/enemies/boss_glb.gd")
const EnemyGlb = preload("res://scripts/enemies/enemy_glb.gd")
const DA = preload("res://scripts/death_anim.gd")

const VIOLET_CORE := Color(0.84, 0.36, 1.00)

const GLB_PATHS := {
	"citadel_behemoth_hull": "res://assets/models/boss/citadel_behemoth_hull.glb",
	"sky_carrier_hull": "res://assets/models/boss/sky_carrier_hull.glb",
	"boss_legion_leg": "res://assets/models/boss/boss_legion_leg.glb",
	"boss_plasma_turret": "res://assets/models/boss/boss_plasma_turret.glb",
	"boss_vtol_thruster": "res://assets/models/boss/boss_vtol_thruster.glb",
}

static var _packed_cache := {}
static var _mat_cache := {}


static func _prepare_mat(src: Material) -> Material:
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


static func _spawn_glb(h, parent: Node3D, key: String, u_scale: float, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, xz_thick_mult := 1.0) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = key.to_pascal_case()
	wrap.position = pos
	wrap.rotation_degrees = rot_deg
	var sy := maxf(u_scale, 0.001)
	var sxz := maxf(u_scale * xz_thick_mult, 0.001)
	wrap.scale = Vector3(sxz, sy, sxz)
	parent.add_child(wrap)

	var path: String = str(GLB_PATHS.get(key, ""))
	var ps: PackedScene = _packed_cache.get(path)
	if ps == null and path != "" and ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is PackedScene:
			ps = loaded
			_packed_cache[path] = ps
	var inst: Node = ps.instantiate() if ps != null else null
	if inst == null and path != "":
		var abs_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(abs_p, st) == OK:
				inst = doc.generate_scene(st)
	if inst != null:
		wrap.add_child(inst)
		var mob_perf: bool = ART.is_mobile_perf()
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			if mi.mesh is ArrayMesh:
				mi.mesh = BossGlb._get_sanitized_mesh(mi.mesh as ArrayMesh)
			if mi.material_override == null:
				var active_m := mi.get_active_material(0)
				if active_m != null:
					mi.material_override = _prepare_mat(active_m)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if mob_perf:
				mi.visibility_range_end = 155.0
				mi.visibility_range_end_margin = 6.0
			h.parts.append(mi)
	return wrap


static func _attach_kit_core_doors(h, parent: Node3D, pos: Vector3, sc: float, armor_col: Color) -> void:
	var vault := EnemyGlb.spawn_boss_kit(h, parent, "kit_boss_core_vault", armor_col, VIOLET_CORE, Vector3.ONE * sc, pos)
	for n in vault.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if str(mi.name).contains("__emit_"):
			mi.material_override = ART.emit(VIOLET_CORE, 1.35).duplicate()
			h.core_mi = mi
			break
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.name = "CoreDoorR" if sx > 0.0 else "CoreDoorL"
		pl.position = pos + Vector3(sx * 0.25 * sc, 0.0, -0.10 * sc)
		pl.set_meta("side", sx)
		parent.add_child(pl)
		var did := "kit_boss_core_door_r" if sx > 0.0 else "kit_boss_core_door_l"
		EnemyGlb.spawn_boss_kit(h, pl, did, armor_col, VIOLET_CORE, Vector3.ONE * sc)
		h.plates.append(pl)


# ==============================================================================
# 1. Horus 级超重型六足机械母巢要塞（citadel_behemoth，s = 5.6）
# ==============================================================================
static func build_citadel_behemoth(h, body: Node3D, s: float) -> void:
	var armor_col := Color(0.14, 0.15, 0.19)
	var m_dark: Material = ART.metal(Color(0.11, 0.12, 0.15))
	var m_chrome: Material = ART.metal(Color(0.68, 0.70, 0.78))
	var m_violet: Material = ART.paint(Color(0.32, 0.16, 0.54), 0.84, 0.28, {"panel_scale": 0.0})

	var fem_s: float = 0.82 * s
	var tib_s: float = 0.84 * s
	var fem_elev_rad := deg_to_rad(12.0)
	var tib_splay_rad := 0.10
	var fem_span: float = 0.64 * fem_s
	var fem_dy: float = 0.34 * fem_s
	var tib_drop: float = (1.504 * tib_s) * cos(tib_splay_rad)
	var hip_y: float = tib_drop - fem_dy

	var legs_root := Node3D.new()
	legs_root.name = "HexapodLegs"
	body.add_child(legs_root)

	var leg_specs := [
		[1.56, -1.04, -30.0, 0],
		[1.76, 0.02, 0.0, 1],
		[1.56, 1.06, 30.0, 2],
	]
	var mod_legs: Array = []
	for spec in leg_specs:
		var lx_k: float = float(spec[0])
		var lz_k: float = float(spec[1])
		var yaw_deg: float = float(spec[2])
		var row_i: int = int(spec[3])
		for sx: float in [-1.0, 1.0]:
			var hip_yaw := Node3D.new()
			hip_yaw.name = "Hip_%d_%s" % [row_i, "R" if sx > 0.0 else "L"]
			hip_yaw.position = Vector3(sx * lx_k * s, hip_y, lz_k * s)
			var base_yaw: float = deg_to_rad(sx * yaw_deg)
			hip_yaw.rotation.y = base_yaw
			legs_root.add_child(hip_yaw)

			var brace_anchor := Vector3(-sx * 0.24 * s, -0.42 * s, 0.0)
			var fem_lift := Node3D.new()
			fem_lift.name = "FemurLift"
			hip_yaw.add_child(fem_lift)

			var fem_id := "kit_boss_femur_r" if sx > 0.0 else "kit_boss_femur_l"
			EnemyGlb.spawn_boss_kit(h, fem_lift, fem_id, armor_col, VIOLET_CORE, Vector3.ONE * fem_s)

			var knee := Node3D.new()
			knee.name = "KneeJoint"
			knee.position = Vector3(sx * fem_span, fem_dy, 0.0)
			var base_knee_z: float = -sx * tib_splay_rad
			knee.rotation.z = base_knee_z
			fem_lift.add_child(knee)

			var tib_yaw: float = 180.0 if sx > 0.0 else 0.0
			_spawn_glb(h, knee, "boss_legion_leg", tib_s, Vector3(0.0, 0.08 * tib_s, 0.0), Vector3(0.0, tib_yaw, 0.0), 1.55)

			var sole_y: float = -1.504 * tib_s
			var foot_pad := Marker3D.new()
			foot_pad.position = Vector3(0.0, sole_y, 0.0)
			knee.add_child(foot_pad)

			var knee_lug := Marker3D.new()
			knee_lug.position = Vector3(sx * fem_span * 0.85, fem_dy - 0.18 * s, 0.0)
			fem_lift.add_child(knee_lug)

			var rams: Array = []
			for rz: float in [-0.15, 0.15]:
				var barrel := Node3D.new()
				barrel.position = brace_anchor + Vector3(0.0, 0.0, rz * s)
				hip_yaw.add_child(barrel)
				var b_mi := MeshInstance3D.new()
				b_mi.mesh = ART.cyl(0.085 * s, 0.68 * s, 0.095 * s, 12)
				b_mi.material_override = m_dark
				b_mi.position = Vector3(0.0, 0.0, -0.34 * s)
				b_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				b_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				barrel.add_child(b_mi)
				h.parts.append(b_mi)

				var c_mi := MeshInstance3D.new()
				c_mi.mesh = ART.cyl(0.105 * s, 0.07 * s, 0.105 * s, 12)
				c_mi.material_override = m_violet
				c_mi.position = Vector3(0.0, 0.0, -0.66 * s)
				c_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				c_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				barrel.add_child(c_mi)
				h.parts.append(c_mi)

				var rod := Node3D.new()
				rod.position = knee_lug.position + Vector3(0.0, 0.0, rz * s)
				hip_yaw.add_child(rod)
				var r_mi := MeshInstance3D.new()
				r_mi.mesh = ART.cyl(0.062 * s, 0.74 * s, 0.062 * s, 12)
				r_mi.material_override = m_chrome
				r_mi.position = Vector3(0.0, 0.0, -0.37 * s)
				r_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				r_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				rod.add_child(r_mi)
				h.parts.append(r_mi)
				rams.append({"barrel": barrel, "rod": rod, "z_off": rz * s})
			_sync_leg_rams(hip_yaw, knee_lug, brace_anchor, rams)

			var is_group_a: bool = (row_i % 2 == 0 and sx < 0.0) or (row_i % 2 == 1 and sx > 0.0)
			mod_legs.append({
				"hip": hip_yaw,
				"lift": fem_lift,
				"knee": knee,
				"foot_pad": foot_pad,
				"was_lifted": false,
				"knee_lug": knee_lug,
				"brace_anchor": brace_anchor,
				"rams": rams,
				"side": sx,
				"base_yaw": base_yaw,
				"base_splay": 0.0,
				"base_knee_z": base_knee_z,
				"phase": 0.0 if is_group_a else PI,
			})

	var belly_ao := ART.ground_vfx(h, ART.blob_tex(), Color(0.02, 0.015, 0.035, 0.90), 5.4 * s, Vector3(0.0, 0.036, 0.0), false, 0.42, false, 1)
	belly_ao.set_meta("no_flash", true)

	var hull_deck := Node3D.new()
	hull_deck.name = "HullDeck"
	var hull_base_y: float = 1.18 * s
	hull_deck.position = Vector3(0.0, hull_base_y, 0.0)
	body.add_child(hull_deck)

	EnemyGlb.spawn_boss_kit(h, hull_deck, "kit_boss_chassis", armor_col, VIOLET_CORE,
		Vector3(2.25, 1.35, 1.85) * s, Vector3(0.0, -0.26 * s, 0.0))

	# 超宽多翼 Horus 级母巢主甲壳
	_spawn_glb(h, hull_deck, "citadel_behemoth_hull", 1.72 * s, Vector3(0.0, 0.06 * s, 0.0), Vector3(0.0, -90.0, 0.0))
	_spawn_glb(h, hull_deck, "citadel_behemoth_hull", 1.10 * s, Vector3(-1.26 * s, -0.06 * s, 0.08 * s), Vector3(0.0, -90.0, 0.0))
	_spawn_glb(h, hull_deck, "citadel_behemoth_hull", 1.10 * s, Vector3(1.26 * s, -0.06 * s, 0.08 * s), Vector3(0.0, -90.0, 0.0))

	_attach_kit_core_doors(h, hull_deck, Vector3(0.0, -0.10 * s, -1.68 * s), 0.92 * s, armor_col)

	var turret_mounts: Array = []
	var main_yaw := Node3D.new()
	main_yaw.name = "MainTurretYaw"
	main_yaw.position = Vector3(0.0, 0.58 * s, 0.06 * s)
	hull_deck.add_child(main_yaw)

	var main_recoil := Node3D.new()
	main_recoil.name = "MainRecoil"
	main_yaw.add_child(main_recoil)

	var ms: float = 1.08 * s
	_spawn_glb(h, main_recoil, "boss_plasma_turret", ms, Vector3.ZERO, Vector3(0.0, -90.0, 0.0))

	var cr := EnemyGlb.spawn_boss_kit(h, main_recoil, "kit_boss_phase_crown", armor_col, VIOLET_CORE,
		Vector3.ONE * (0.68 * s), Vector3(0.0, 0.48 * ms, 0.18 * ms))
	h.spinners.append([cr, Vector3.UP, 1.6, 5.2])

	var muz_l := Marker3D.new()
	muz_l.name = "MuzzleL"
	muz_l.position = Vector3(-0.16 * ms, 0.24 * ms, -0.92 * ms)
	main_recoil.add_child(muz_l)
	var muz_r := Marker3D.new()
	muz_r.name = "MuzzleR"
	muz_r.position = Vector3(0.16 * ms, 0.24 * ms, -0.92 * ms)
	main_recoil.add_child(muz_r)

	turret_mounts.append({
		"role": "main",
		"yaw_node": main_yaw,
		"recoil_node": main_recoil,
		"muzzles": [muz_l, muz_r],
		"home_yaw": 0.0,
		"arc_half": PI,
		"turn_speed": 1.70,
		"cd": 1.6,
		"wind_rem": 0.0,
	})

	var ss: float = 0.50 * s
	var sub_defs := [
		[Vector3(-0.84, 0.34, -0.96), 0.38, 2.15, 0.70],
		[Vector3(0.84, 0.34, -0.96), -0.38, 2.15, 1.05],
		[Vector3(-1.62, 0.32, 0.08), 1.35, 2.25, 1.40],
		[Vector3(1.62, 0.32, 0.08), -1.35, 2.25, 1.75],
		[Vector3(-0.86, 0.34, 1.04), PI - 0.42, 2.15, 2.10],
		[Vector3(0.86, 0.34, 1.04), -PI + 0.42, 2.15, 2.45],
	]
	for idx in sub_defs.size():
		var sd: Array = sub_defs[idx]
		var rel_p: Vector3 = (sd[0] as Vector3) * s
		var h_yaw: float = float(sd[1])
		var arc_h: float = float(sd[2])
		var init_cd: float = float(sd[3])

		var syaw := Node3D.new()
		syaw.name = "SubTurretYaw_%d" % idx
		syaw.position = rel_p
		syaw.rotation.y = h_yaw
		hull_deck.add_child(syaw)

		var srecoil := Node3D.new()
		srecoil.name = "SubRecoil"
		syaw.add_child(srecoil)
		_spawn_glb(h, srecoil, "boss_plasma_turret", ss, Vector3.ZERO, Vector3(0.0, -90.0, 0.0))

		var m_gun := Marker3D.new()
		m_gun.name = "MuzzleGun"
		m_gun.position = Vector3(-0.16 * ss, 0.24 * ss, -0.92 * ss)
		srecoil.add_child(m_gun)
		var m_pod := Marker3D.new()
		m_pod.name = "MuzzlePod"
		m_pod.position = Vector3(0.16 * ss, 0.24 * ss, -0.92 * ss)
		srecoil.add_child(m_pod)

		turret_mounts.append({
			"role": "sub",
			"yaw_node": syaw,
			"recoil_node": srecoil,
			"muzzles": [m_gun, m_pod],
			"home_yaw": h_yaw,
			"arc_half": arc_h,
			"turn_speed": 2.75,
			"cd": init_cd,
			"burst_left": 0,
			"burst_t": 0.0,
			"shots_n": idx,
		})

	h.set_meta("turret_mounts", turret_mounts)
	h.set_meta("modular_glb", {
		"type": "citadel",
		"hull_deck": hull_deck,
		"hull_base_y": hull_base_y,
		"legs": mod_legs,
		"awaken_t": 0.0,
	})


# ==============================================================================
# 2. Eclipse 级隐身飞翼机械虫空天母舰（sky_carrier，s = 3.8，hover = 5.6）
# ==============================================================================
static func build_sky_carrier(h, body: Node3D, s: float) -> void:
	var armor_col := Color(0.14, 0.15, 0.20)
	var m_jet: Material = ART.emit(VIOLET_CORE, 2.5)

	var ship_rig := Node3D.new()
	ship_rig.name = "CarrierRig"
	body.add_child(ship_rig)

	var hs: float = 1.96 * s
	_spawn_glb(h, ship_rig, "sky_carrier_hull", hs, Vector3.ZERO, Vector3(0.0, -90.0, 0.0))

	var ts: float = 0.78 * s
	var thrusters: Array = []
	var pylon_z_list := [-0.88, 0.78]
	for z_i in pylon_z_list.size():
		var pz: float = float(pylon_z_list[z_i]) * s
		for sx: float in [-1.0, 1.0]:
			var pod := Node3D.new()
			pod.name = "ThrusterPod_%d_%s" % [z_i, "R" if sx > 0.0 else "L"]
			pod.position = Vector3(sx * 1.32 * s, -0.10 * s, pz)
			ship_rig.add_child(pod)

			_spawn_glb(h, pod, "boss_vtol_thruster", ts, Vector3.ZERO, Vector3(0.0, 0.0, -90.0))

			var flame := MeshInstance3D.new()
			flame.mesh = ART.cyl(0.04 * ts, 0.46 * ts, 0.20 * ts, 12)
			flame.material_override = m_jet
			flame.position = Vector3(0.0, -0.52 * ts, 0.0)
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flame.set_meta("no_flash", true)
			flame.set_meta("no_ground_bounds", true)
			pod.add_child(flame)
			h.parts.append(flame)

			thrusters.append({
				"pod": pod,
				"flame": flame,
				"side": sx,
				"is_front": z_i == 0,
			})

	_attach_kit_core_doors(h, ship_rig, Vector3(0.0, -0.14 * s, -1.74 * s), 0.78 * s, armor_col)

	var ss: float = 0.46 * s
	var turret_mounts: Array = []
	var carrier_turrets := [
		[Vector3(-0.64, -0.44, -0.92), 0.32, 2.25, 0.90],
		[Vector3(0.64, -0.44, -0.92), -0.32, 2.25, 1.45],
		[Vector3(0.0, 0.36, -0.68), 0.0, PI, 2.00],
	]
	for idx in carrier_turrets.size():
		var td: Array = carrier_turrets[idx]
		var rel_p: Vector3 = (td[0] as Vector3) * s
		var h_yaw: float = float(td[1])
		var arc_h: float = float(td[2])
		var init_cd: float = float(td[3])

		var tyaw := Node3D.new()
		tyaw.name = "CarrierTurretYaw_%d" % idx
		tyaw.position = rel_p
		tyaw.rotation.y = h_yaw
		ship_rig.add_child(tyaw)

		var trecoil := Node3D.new()
		trecoil.name = "CarrierTurretRecoil"
		tyaw.add_child(trecoil)
		var flip_z := 180.0 if idx < 2 else 0.0
		_spawn_glb(h, trecoil, "boss_plasma_turret", ss, Vector3.ZERO, Vector3(0.0, -90.0, flip_z))

		var m_gun := Marker3D.new()
		m_gun.name = "MuzzleGun"
		m_gun.position = Vector3(-0.16 * ss, (0.24 if idx >= 2 else -0.24) * ss, -0.92 * ss)
		trecoil.add_child(m_gun)
		var m_pod := Marker3D.new()
		m_pod.name = "MuzzlePod"
		m_pod.position = Vector3(0.16 * ss, (0.24 if idx >= 2 else -0.24) * ss, -0.92 * ss)
		trecoil.add_child(m_pod)

		turret_mounts.append({
			"role": "sub",
			"yaw_node": tyaw,
			"recoil_node": trecoil,
			"muzzles": [m_gun, m_pod],
			"home_yaw": h_yaw,
			"arc_half": arc_h,
			"turn_speed": 2.85,
			"cd": init_cd,
			"burst_left": 0,
			"burst_t": 0.0,
			"shots_n": idx,
		})

	var sun_shadow := Node3D.new()
	sun_shadow.name = "CarrierSunShadow"
	sun_shadow.position = Vector3(3.8, 0.038, 3.0)
	h.add_child(sun_shadow)
	var sh_decal := ART.ground_vfx(sun_shadow, ART.blob_tex(), Color(0.015, 0.012, 0.028, 0.88), 4.5 * s, Vector3.ZERO, false, 0.40, false, 1)
	sh_decal.scale = Vector3(0.78, 1.0, 1.32)
	sh_decal.set_meta("no_flash", true)

	h.set_meta("turret_mounts", turret_mounts)
	h.set_meta("modular_glb", {
		"type": "carrier",
		"ship_rig": ship_rig,
		"thrusters": thrusters,
		"sun_shadow": sun_shadow,
		"awaken_t": 0.0,
	})


static func _info(h):
	return h.get_meta("modular_glb") if (h != null and is_instance_valid(h) and h.has_meta("modular_glb")) else null


static func _sync_leg_rams(hip: Node3D, knee_lug: Node3D, brace_anchor: Vector3, rams: Array) -> void:
	var lift_p: Node3D = knee_lug.get_parent() as Node3D
	if lift_p == null or not is_instance_valid(hip):
		return
	var lug_in_hip: Vector3 = lift_p.transform * knee_lug.position
	for rm in rams:
		var barrel: Node3D = rm.get("barrel")
		var rod: Node3D = rm.get("rod")
		var z_off: float = float(rm.get("z_off", 0.0))
		if not is_instance_valid(barrel) or not is_instance_valid(rod):
			continue
		var p_a: Vector3 = brace_anchor + Vector3(0.0, 0.0, z_off)
		var p_b: Vector3 = lug_in_hip + Vector3(0.0, 0.0, z_off)
		var dir_ab: Vector3 = p_b - p_a
		var dist: float = dir_ab.length()
		if dist < 0.05:
			continue
		var d_norm: Vector3 = dir_ab / dist
		barrel.transform = Transform3D(Basis.looking_at(d_norm, Vector3.UP), p_a)
		rod.transform = Transform3D(Basis.looking_at(-d_norm, Vector3.UP), p_b)


static func on_awaken(h) -> void:
	var info = _info(h)
	if info != null:
		info["awaken_t"] = 1.6


static func on_cancel_act(h) -> void:
	if h != null and is_instance_valid(h):
		h.hit_v += Vector3(-0.7, 0.0, 0.0)


static func animate(h, delta: float, mv: float) -> void:
	var info = _info(h)
	if info == null:
		return
	var mtype := str(info.get("type", ""))
	h.move_amt = move_toward(h.move_amt, clampf(mv, 0.0, 1.0), delta * 5.0)
	var sc: float = float(h.data.get("scale", 4.0))
	h.hit_v += (-h.hit_tilt * 150.0 - h.hit_v * 12.5) * delta
	h.hit_tilt += h.hit_v * delta
	info["awaken_t"] = maxf(0.0, float(info.get("awaken_t", 0.0)) - delta)

	for sp in h.spinners:
		if sp is Array and sp.size() >= 4 and is_instance_valid(sp[0]):
			var active_spin: bool = h.act != "" and h.act != "recover"
			var w: float = float(sp[3]) if active_spin else float(sp[2])
			(sp[0] as Node3D).rotate_object_local(sp[1], w * delta)

	for pl in h.plates:
		if is_instance_valid(pl):
			var sd: float = float(pl.get_meta("side", 1.0))
			pl.rotation.z = lerp(pl.rotation.z, 0.0, clampf(10.0 * delta, 0.0, 1.0))
			pl.rotation.y = lerp(pl.rotation.y, sd * h.core_vis * 0.85, clampf(10.0 * delta, 0.0, 1.0))

	if h.core_mi and is_instance_valid(h.core_mi) and h.core_mi.material_override is StandardMaterial3D:
		var em: StandardMaterial3D = h.core_mi.material_override
		var e0: float = 0.85 + sin(h.anim_t * 3.2) * 0.22 + (h.focus * 2.4 if h.act == "wind" else 0.0)
		em.emission_energy_multiplier = lerp(em.emission_energy_multiplier, e0, clampf(8.0 * delta, 0.0, 1.0))

	if mtype == "citadel":
		_animate_citadel(h, info, delta, sc)
	elif mtype == "carrier":
		_animate_carrier(h, info, delta, sc)


static func _animate_citadel(h, info: Dictionary, delta: float, sc: float) -> void:
	var cad := 4.4 if h.act != "charge" else 7.2
	h.anim_t += delta * (0.25 + h.move_amt * 1.15)
	var amt: float = h.move_amt
	var k := clampf(12.0 * delta, 0.0, 1.0)

	var legs_arr: Array = info.get("legs", [])
	for ld in legs_arr:
		var hip: Node3D = ld.get("hip")
		var lift: Node3D = ld.get("lift")
		var knee: Node3D = ld.get("knee")
		if not is_instance_valid(hip) or not is_instance_valid(lift):
			continue
		var sx: float = float(ld.get("side", 1.0))
		var base_yaw: float = float(ld.get("base_yaw", 0.0))
		var base_splay: float = float(ld.get("base_splay", 0.0))
		var base_knee_z: float = float(ld.get("base_knee_z", 0.0))
		var ph: float = h.anim_t * cad + float(ld.get("phase", 0.0))
		var s_ph := sin(ph)
		var c_ph := cos(ph)

		var want_yaw: float = base_yaw - s_ph * 0.22 * amt * sx
		var lift_ang: float = maxf(0.0, c_ph) * 0.22 * amt * (-sx)
		if h.act == "wind" and h._next_step() == "stomp":
			lift_ang += 0.20 * (-sx) * h.focus
		elif h.act == "stomp":
			lift_ang -= 0.10 * (-sx)
		hip.rotation.y = lerp_angle(hip.rotation.y, want_yaw, k)
		lift.rotation.z = lerp(lift.rotation.z, base_splay + lift_ang, k)
		if is_instance_valid(knee):
			knee.rotation.z = lerp(knee.rotation.z, base_knee_z - lift_ang * 0.85, k)
		var knee_lug: Node3D = ld.get("knee_lug")
		var rams: Array = ld.get("rams", [])
		if is_instance_valid(knee_lug) and not rams.is_empty():
			_sync_leg_rams(hip, knee_lug, ld.get("brace_anchor", Vector3.ZERO), rams)
		var lifted_now: bool = h.awake and amt > 0.12 and c_ph > 0.18
		if bool(ld.get("was_lifted", false)) and not lifted_now and h.raid != null and is_instance_valid(h.raid.fx):
			var fp: Node3D = ld.get("foot_pad")
			if is_instance_valid(fp):
				var gp := Vector3(fp.global_position.x, 0.16, fp.global_position.z)
				ART.burst(h.raid.fx, gp, {"amount": 10, "life": 0.68, "size": 1.35, "tex": ART.dust_tex(), "additive": false, "flat": 0.88,
					"dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": 2.4, "vmax": 5.8, "gravity": Vector3(0, 0.3, 0), "damp": 5.0,
					"c0": Color(0.58, 0.50, 0.38, 0.0), "cmid": Color(0.58, 0.50, 0.38, 0.46), "cmid_pos": 0.18,
					"c1": Color(0.46, 0.40, 0.32, 0.0), "grow0": 0.55, "grow1": 1.85})
				h.raid.shake = maxf(h.raid.shake, 0.12)
		ld["was_lifted"] = lifted_now

	var hull_deck: Node3D = info.get("hull_deck")
	var base_y: float = float(info.get("hull_base_y", 1.18 * sc))
	if is_instance_valid(hull_deck):
		var dy := sin(h.anim_t * cad * 2.0) * 0.040 * amt * sc
		var pitch := 0.0
		var roll := sin(h.anim_t * cad) * 0.018 * amt
		if not h.awake:
			dy -= 0.18 * sc
		elif float(info.get("awaken_t", 0.0)) > 0.0:
			pitch = -0.10
			dy += 0.06 * sc
		elif h.act == "wind":
			var nxt: String = h._next_step()
			if nxt == "stomp":
				dy += 0.22 * sc * h.focus
				pitch = -0.12 * h.focus
			elif nxt == "charge":
				dy -= 0.10 * sc * h.focus
				pitch = 0.10 * h.focus
			else:
				pitch = -0.06 * h.focus
		elif h.act == "stomp":
			dy -= 0.24 * sc
			pitch = 0.12
		elif h.act == "charge":
			pitch = 0.08
		hull_deck.position.y = lerp(hull_deck.position.y, base_y + dy, clampf(9.0 * delta, 0.0, 1.0))
		hull_deck.rotation.x = lerp(hull_deck.rotation.x, pitch, clampf(8.0 * delta, 0.0, 1.0)) + clampf(h.hit_tilt.x * 0.18, -0.12, 0.12)
		hull_deck.rotation.z = lerp(hull_deck.rotation.z, roll, clampf(8.0 * delta, 0.0, 1.0)) + clampf(h.hit_tilt.z * 0.18, -0.12, 0.12)

	if is_instance_valid(h.visual):
		h.visual.position.y = 0.0
		h.visual.rotation.x = 0.0


static func _animate_carrier(h, info: Dictionary, delta: float, _sc: float) -> void:
	h.anim_t += delta * (0.55 + h.move_amt * 0.85)
	var ship_rig: Node3D = info.get("ship_rig")
	var hover_h: float = maxf(float(h.hover), 5.2)

	if is_instance_valid(h.visual):
		var sun_sh: Node3D = info.get("sun_shadow")
		if is_instance_valid(sun_sh):
			sun_sh.rotation.y = h.visual.rotation.y
			sun_sh.visible = not h.dying
		var want_y: float = hover_h + sin(h.anim_t * 1.55) * 0.28
		if not h.awake:
			want_y = hover_h - 0.8
		elif h.act == "wind" and h._next_step() == "stomp":
			want_y = hover_h + 0.85 * h.focus
		elif h.act == "stomp":
			want_y = hover_h - 1.15
		elif h.act == "charge":
			want_y = hover_h - 0.95
		h.visual.position.y = lerp(h.visual.position.y, want_y, clampf(5.5 * delta, 0.0, 1.0))

	if is_instance_valid(ship_rig):
		var local_vel := Vector3.ZERO
		if is_instance_valid(h.visual):
			local_vel = h.visual.global_transform.basis.inverse() * h.velocity
		var fwd_spd: float = clampf(-local_vel.z / maxf(float(h.data.get("speed", 4.2)), 1.0), -1.2, 1.6)
		var side_spd: float = clampf(local_vel.x / maxf(float(h.data.get("speed", 4.2)), 1.0), -1.2, 1.2)
		var want_pitch: float = -0.07 * fwd_spd + sin(h.anim_t * 1.2) * 0.025
		var want_roll: float = -0.11 * side_spd + cos(h.anim_t * 1.1) * 0.03
		if h.act == "wind" and h._next_step() == "slug":
			want_pitch = -0.16 * h.focus
		elif h.act == "charge":
			want_pitch = -0.18
		ship_rig.rotation.x = lerp(ship_rig.rotation.x, want_pitch, clampf(6.5 * delta, 0.0, 1.0)) + clampf(h.hit_tilt.x * 0.20, -0.14, 0.14)
		ship_rig.rotation.z = lerp(ship_rig.rotation.z, want_roll, clampf(6.5 * delta, 0.0, 1.0)) + clampf(h.hit_tilt.z * 0.20, -0.14, 0.14)

		var thrusters: Array = info.get("thrusters", [])
		for td in thrusters:
			var pod: Node3D = td.get("pod")
			var flame: MeshInstance3D = td.get("flame")
			var sd: float = float(td.get("side", 1.0))
			if is_instance_valid(pod):
				var tilt_x: float = clampf(fwd_spd * 0.34, -0.35, 0.48) + sin(h.anim_t * 2.3 + sd) * 0.04
				if h.act == "charge":
					tilt_x = 0.55
				elif h.act == "stomp":
					tilt_x = -0.12
				pod.rotation.x = lerp(pod.rotation.x, tilt_x, clampf(8.0 * delta, 0.0, 1.0))
			if is_instance_valid(flame):
				var pulse: float = 0.92 + sin(h.anim_t * 19.0 + sd * 1.7) * 0.18 + h.move_amt * 0.28
				if h.act in ["charge", "stomp"]:
					pulse += 0.45
				flame.scale = Vector3(1.0, pulse, 1.0)


static func flash_turret_visual(h, tur: Dictionary) -> void:
	if h == null or not is_instance_valid(h) or bool(tur.get("destroyed", false)):
		return
	var rec: Node3D = tur.get("recoil_node")
	if not is_instance_valid(rec):
		return
	var now_t: float = float(Time.get_ticks_msec()) * 0.001
	if now_t - float(tur.get("last_flash_s", -9.0)) < 0.16:
		return
	tur["last_flash_s"] = now_t
	var ov: Material = ART.hit_flash_overlay(0.55)
	for n in rec.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null:
			mi.material_overlay = ov
	var tw: Tween = (h as Node).create_tween()
	tw.tween_interval(0.065)
	tw.tween_callback(func():
		if not is_instance_valid(rec):
			return
		for n in rec.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi != null:
				mi.material_overlay = null)


static func wreck_turret_visual(_h, tur: Dictionary) -> void:
	var rec: Node3D = tur.get("recoil_node")
	if not is_instance_valid(rec):
		return
	rec.rotation_degrees = Vector3(24.0, randf_range(-18.0, 18.0), randf_range(-20.0, 20.0))
	var charred: Material = ART.paint(Color(0.06, 0.06, 0.08), 0.42, 0.86, {"rust": 0.25, "wear": 0.65})
	for n in rec.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null:
			mi.material_overlay = null
			mi.material_override = charred
	ART.emitter(rec, Vector3(0.0, 0.55, 0.0), {"amount": 14, "life": 1.35, "size": 0.52, "tex": ART.smoke_tex(), "additive": false,
		"spread": 32.0, "vmin": 0.8, "vmax": 2.2, "gravity": Vector3(0.0, 2.4, 0.0), "damp": 1.6,
		"c0": Color(0.10, 0.08, 0.14, 0.0), "cmid": Color(0.12, 0.09, 0.16, 0.68), "cmid_pos": 0.18,
		"c1": Color(0.10, 0.10, 0.13, 0.0), "grow0": 0.55, "grow1": 2.2})


static func on_die(h, body: Node3D) -> bool:
	var info = _info(h)
	if info == null:
		return false
	var mtype := str(info.get("type", ""))
	var sc: float = float(h.data.get("scale", 4.0))
	var side := 1.0 if randf() < 0.5 else -1.0
	var tw: Tween = (h as Node).create_tween().set_parallel(true)

	var start_pos: Vector3 = h.global_position
	var fx_root: Node = h.raid.fx if (h.raid != null and is_instance_valid(h.raid.fx)) else null

	if h.has_meta("turret_mounts"):
		var mounts: Array = h.get_meta("turret_mounts")
		for idx in mounts.size():
			var tur: Dictionary = mounts[idx]
			var rec: Node3D = tur.get("recoil_node")
			if is_instance_valid(rec):
				tw.tween_property(rec, "rotation:x", 0.28, 0.95).set_delay(float(idx) * 0.08)
			if idx < 4:
				var cook_delay := 0.16 + float(idx) * 0.26
				tw.tween_callback(func() -> void:
					if not is_instance_valid(h):
						return
					wreck_turret_visual(h, tur)
					if is_instance_valid(rec) and h.raid != null and h.raid.has_method("explode_fx"):
						h.raid.explode_fx(rec.global_position + Vector3(0.0, 0.5, 0.0), 3.6, Color(0.82, 0.34, 1.0))
						h.raid.shake = maxf(h.raid.shake, 0.45)
				).set_delay(cook_delay)

	if mtype == "citadel":
		var g_info := DA.sample_ground(h, start_pos, 6.5, 64.0)
		var gy: float = float(g_info.get("y", start_pos.y))
		var gnrm: Vector3 = g_info.get("normal", Vector3.UP)
		var end_pos := Vector3(start_pos.x, gy, start_pos.z)
		var hull_deck: Node3D = info.get("hull_deck")
		var legs_arr: Array = info.get("legs", [])

		var start_vis_pos: Vector3 = h.visual.position
		var start_vis_rot: Vector3 = h.visual.rotation
		var end_vis_rot: Vector3 = DA.slope_basis(gnrm, start_vis_rot.y, 0.0, 0.0, 0.78).get_euler()
		var start_body_pos: Vector3 = body.position
		var start_deck_pos: Vector3 = hull_deck.position if is_instance_valid(hull_deck) else Vector3.ZERO
		var start_deck_rot: Vector3 = hull_deck.rotation if is_instance_valid(hull_deck) else Vector3.ZERO
		var end_deck_pos := Vector3(0.0, 0.58 * sc, 0.0)
		var end_deck_rot := Vector3(randf_range(0.03, 0.06), 0.0, side * randf_range(0.025, 0.05))

		var leg_states: Array = []
		for ld in legs_arr:
			var hip: Node3D = ld.get("hip")
			var lift: Node3D = ld.get("lift")
			var knee: Node3D = ld.get("knee")
			if not is_instance_valid(hip) or not is_instance_valid(lift):
				continue
			var sx: float = float(ld.get("side", 1.0))
			var b_yaw: float = float(ld.get("base_yaw", hip.rotation.y))
			var b_knee: float = float(ld.get("base_knee_z", knee.rotation.z if is_instance_valid(knee) else 0.0))
			var end_lift_z: float = sx * randf_range(0.24, 0.30)
			var end_knee_z: float = b_knee + sx * randf_range(0.08, 0.14)
			var end_hip_y: float = b_yaw + randf_range(-0.14, 0.14)
			leg_states.append([ld, hip.rotation.y, end_hip_y, lift.rotation.z, end_lift_z, knee.rotation.z if is_instance_valid(knee) else 0.0, end_knee_z])

		h.global_position = end_pos
		h._vis_sync()
		h.visual.position = Vector3.ZERO
		h.visual.rotation = end_vis_rot
		body.position = Vector3.ZERO
		if is_instance_valid(hull_deck):
			hull_deck.position = end_deck_pos
			hull_deck.rotation = end_deck_rot
		for st in leg_states:
			var ld: Dictionary = st[0]
			var hip: Node3D = ld.get("hip")
			var lift: Node3D = ld.get("lift")
			var knee: Node3D = ld.get("knee")
			hip.rotation.y = float(st[2])
			lift.rotation.z = float(st[4])
			if is_instance_valid(knee):
				knee.rotation.z = float(st[6])
			var kl: Node3D = ld.get("knee_lug")
			var rms: Array = ld.get("rams", [])
			if is_instance_valid(kl) and not rms.is_empty():
				_sync_leg_rams(hip, kl, ld.get("brace_anchor", Vector3.ZERO), rms)

		var min_clr: float = DA.lowest_slope_clearance(h.visual, end_pos, gnrm)
		var up_cos: float = maxf(h.visual.global_transform.basis.y.y, 0.5)
		var target_body_y := (-0.04 - min_clr) / up_cos

		h.global_position = start_pos
		h._vis_sync()
		h.visual.position = start_vis_pos
		h.visual.rotation = start_vis_rot
		body.position = start_body_pos
		if is_instance_valid(hull_deck):
			hull_deck.position = start_deck_pos
			hull_deck.rotation = start_deck_rot
		for st in leg_states:
			var ld: Dictionary = st[0]
			var hip: Node3D = ld.get("hip")
			var lift: Node3D = ld.get("lift")
			var knee: Node3D = ld.get("knee")
			hip.rotation.y = float(st[1])
			lift.rotation.z = float(st[3])
			if is_instance_valid(knee):
				knee.rotation.z = float(st[5])
			var kl: Node3D = ld.get("knee_lug")
			var rms: Array = ld.get("rams", [])
			if is_instance_valid(kl) and not rms.is_empty():
				_sync_leg_rams(hip, kl, ld.get("brace_anchor", Vector3.ZERO), rms)

		var total_c := 1.75
		var hit_u := 0.70
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(h) or not is_instance_valid(h.visual) or not is_instance_valid(body):
				return
			var km := clampf(u / hit_u, 0.0, 1.0)
			var km2 := km * km
			h.global_position = start_pos.lerp(end_pos, km)
			h.visual.position = start_vis_pos.lerp(Vector3.ZERO, km)
			h.visual.rotation = Vector3(
				lerp_angle(start_vis_rot.x, end_vis_rot.x, km),
				lerp_angle(start_vis_rot.y, end_vis_rot.y, km),
				lerp_angle(start_vis_rot.z, end_vis_rot.z, km)
			)
			var bounce := 0.0
			if u > hit_u:
				var kb := (u - hit_u) / (1.0 - hit_u)
				bounce = sin(kb * PI) * (1.0 - kb * 0.6) * 0.045 * sc
			body.position = Vector3(lerpf(start_body_pos.x, 0.0, km), lerpf(start_body_pos.y, target_body_y, km2) + bounce, lerpf(start_body_pos.z, 0.0, km))
			if is_instance_valid(hull_deck):
				hull_deck.position = start_deck_pos.lerp(end_deck_pos, km2) + Vector3(0.0, bounce * 0.6, 0.0)
				hull_deck.rotation = Vector3(
					lerp_angle(start_deck_rot.x, end_deck_rot.x, km),
					lerp_angle(start_deck_rot.y, end_deck_rot.y, km),
					lerp_angle(start_deck_rot.z, end_deck_rot.z, km)
				)
			for st in leg_states:
				var ld: Dictionary = st[0]
				var hip: Node3D = ld.get("hip")
				var lift: Node3D = ld.get("lift")
				var knee: Node3D = ld.get("knee")
				if not is_instance_valid(hip) or not is_instance_valid(lift):
					continue
				var kl_u := 1.0 - (1.0 - km) * (1.0 - km)
				hip.rotation.y = lerp_angle(float(st[1]), float(st[2]), kl_u)
				lift.rotation.z = lerpf(float(st[3]), float(st[4]), km2)
				if is_instance_valid(knee):
					knee.rotation.z = lerpf(float(st[5]), float(st[6]), km2)
				var kl: Node3D = ld.get("knee_lug")
				var rms: Array = ld.get("rams", [])
				if is_instance_valid(kl) and not rms.is_empty():
					_sync_leg_rams(hip, kl, ld.get("brace_anchor", Vector3.ZERO), rms)
			h._vis_sync()
		, 0.0, 1.0, total_c)

		tw.tween_callback(func() -> void:
			if not is_instance_valid(h):
				return
			if h.raid != null and h.raid.has_method("explode_fx"):
				h.raid.explode_fx(end_pos + Vector3(0.0, 1.2 * sc, 0.0), 7.5, Color(0.84, 0.34, 1.0))
				h.raid.shake = maxf(h.raid.shake, 0.90)
			if is_instance_valid(fx_root):
				ART.burst(fx_root, end_pos + Vector3(0.0, 0.22, 0.0), {"amount": 36, "life": 1.15, "size": 2.2 * sc, "tex": ART.dust_tex(), "additive": false, "flat": 0.90,
					"dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": 4.5, "vmax": 14.0, "gravity": Vector3(0, 0.35, 0), "damp": 3.8,
					"c0": Color(0.58, 0.50, 0.38, 0.0), "cmid": Color(0.56, 0.48, 0.36, 0.62), "cmid_pos": 0.18,
					"c1": Color(0.44, 0.38, 0.30, 0.0), "grow0": 0.55, "grow1": 2.3})
		).set_delay(total_c * hit_u)

	elif mtype == "carrier":
		var sun_sh: Node3D = info.get("sun_shadow")
		if is_instance_valid(sun_sh):
			sun_sh.visible = false
		var ship_rig: Node3D = info.get("ship_rig")
		var thrusters: Array = info.get("thrusters", [])

		var fwd: Vector3 = -(h.visual as Node3D).global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
		var right_v := Vector3(-fwd.z, 0.0, fwd.x)
		var crash_xz := DA.clamp_scatter_xz(h, start_pos, start_pos + fwd * 4.2 + right_v * (side * 1.4), 4.2)
		var g_end := DA.sample_ground(h, crash_xz, 8.5, 72.0)
		var gy: float = float(g_end.get("y", start_pos.y))
		var gnrm: Vector3 = g_end.get("normal", Vector3.UP)
		var end_pos := Vector3(crash_xz.x, gy, crash_xz.z)

		var start_vis_pos: Vector3 = h.visual.position
		var start_vis_rot: Vector3 = h.visual.rotation
		var end_vis_rot: Vector3 = DA.slope_basis(gnrm, start_vis_rot.y + side * 0.42, 0.0, 0.0, 0.84).get_euler()
		var start_rig_rot: Vector3 = ship_rig.rotation if is_instance_valid(ship_rig) else Vector3.ZERO
		var end_rig_rot := Vector3(randf_range(0.04, 0.09), 0.0, side * randf_range(0.04, 0.08))

		var pod_tracks: Array = []
		for td in thrusters:
			var pod: Node3D = td.get("pod")
			var flame: MeshInstance3D = td.get("flame")
			if is_instance_valid(pod):
				pod_tracks.append([pod, pod.rotation.x, (1.0 if randf() < 0.7 else -1.0) * randf_range(1.18, 1.42)])
			if is_instance_valid(flame):
				tw.tween_property(flame, "scale", Vector3.ZERO, 0.42)

		h.global_position = end_pos
		h._vis_sync()
		h.visual.position = Vector3.ZERO
		h.visual.rotation = end_vis_rot
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		if is_instance_valid(ship_rig):
			ship_rig.rotation = end_rig_rot
		for pt in pod_tracks:
			(pt[0] as Node3D).rotation.x = float(pt[2])

		var min_clr_c: float = DA.lowest_slope_clearance(h.visual, end_pos, gnrm)
		var target_vis_y := -0.045 - min_clr_c

		h.global_position = start_pos
		h._vis_sync()
		h.visual.position = start_vis_pos
		h.visual.rotation = start_vis_rot
		if is_instance_valid(ship_rig):
			ship_rig.rotation = start_rig_rot
		for pt in pod_tracks:
			(pt[0] as Node3D).rotation.x = float(pt[1])

		var total_k := 1.70
		var hit_u := 0.70
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(h) or not is_instance_valid(h.visual):
				return
			if u <= hit_u:
				var k := u / hit_u
				var k_fall := k * k
				var k_xz := 1.0 - (1.0 - k) * (1.0 - k)
				h.global_position = Vector3(lerpf(start_pos.x, end_pos.x, k_xz), lerpf(start_pos.y, end_pos.y, k_fall), lerpf(start_pos.z, end_pos.z, k_xz))
				h.visual.position = Vector3(lerpf(start_vis_pos.x, 0.0, k), lerpf(start_vis_pos.y, target_vis_y, k_fall), lerpf(start_vis_pos.z, 0.0, k))
				h.visual.rotation = Vector3(
					lerp_angle(start_vis_rot.x, end_vis_rot.x, k) + sin(k * PI) * 0.24,
					lerp_angle(start_vis_rot.y, end_vis_rot.y, k),
					lerp_angle(start_vis_rot.z, end_vis_rot.z, k)
				)
				if is_instance_valid(ship_rig):
					ship_rig.rotation = Vector3(
						lerp_angle(start_rig_rot.x, end_rig_rot.x, k),
						lerp_angle(start_rig_rot.y, end_rig_rot.y, k),
						lerp_angle(start_rig_rot.z, end_rig_rot.z, k)
					)
				for pt in pod_tracks:
					var pd: Node3D = pt[0]
					if is_instance_valid(pd):
						pd.rotation.x = lerpf(float(pt[1]), float(pt[2]), k)
			else:
				var kb := (u - hit_u) / (1.0 - hit_u)
				var bounce := sin(kb * PI) * (1.0 - kb * 0.55) * 0.075 * sc
				h.global_position = end_pos
				h.visual.position = Vector3(0.0, target_vis_y + bounce, 0.0)
				h.visual.rotation = end_vis_rot
				if is_instance_valid(ship_rig):
					ship_rig.rotation = end_rig_rot + Vector3(-bounce * 0.18, 0.0, side * bounce * 0.24)
			h._vis_sync()
		, 0.0, 1.0, total_k)

		tw.tween_callback(func() -> void:
			if not is_instance_valid(h):
				return
			if h.raid != null and h.raid.has_method("explode_fx"):
				h.raid.explode_fx(end_pos + Vector3(0.0, 1.0 * sc, 0.0), 8.2, Color(0.84, 0.34, 1.0))
				h.raid.shake = maxf(h.raid.shake, 0.98)
			if is_instance_valid(fx_root):
				ART.burst(fx_root, end_pos + Vector3(0.0, 0.22, 0.0), {"amount": 38, "life": 1.2, "size": 2.1 * sc, "tex": ART.dust_tex(), "additive": false, "flat": 0.90,
					"dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": 5.0, "vmax": 15.0, "gravity": Vector3(0, 0.35, 0), "damp": 3.6,
					"c0": Color(0.58, 0.50, 0.38, 0.0), "cmid": Color(0.56, 0.48, 0.36, 0.65), "cmid_pos": 0.18,
					"c1": Color(0.44, 0.38, 0.30, 0.0), "grow0": 0.55, "grow1": 2.35})
		).set_delay(total_k * hit_u)

	DA.power_down_wreck(body, tw, 1.55, 0.58)
	if h.core_mi and is_instance_valid(h.core_mi):
		tw.tween_property(h.core_mi, "scale", Vector3.ZERO, 1.5)

	var fin_tw: Tween = (h as Node).create_tween()
	fin_tw.tween_interval(1.9)
	fin_tw.tween_callback(func():
		if not is_instance_valid(h):
			return
		for m in h.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D and not (m.mesh is PlaneMesh):
				m.visibility_range_end = 110.0
				m.visibility_range_end_margin = 6.0
		h._finalize_corpse())
	return true
