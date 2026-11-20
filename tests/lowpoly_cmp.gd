extends "res://tests/lib/test_base.gd"
## 低面数整改分批前后对比：godot --path . -- --lowpoly_cmp --batch=2 --tag=before|after
## → review/lpcmp_b<batch>_<name>_<tag>.png（前后两次运行，再由脚本左右拼图）
const A = preload("res://scripts/art.gd")
const MV = preload("res://scripts/mech_visual.gd")
const START := "none"
const TIMEOUT := 300.0

var cam: Camera3D
var tag := "after"
var batch := 2
var only := ""


func run() -> void:
	get_window().size = Vector2i(960, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--batch="):
			batch = int(a.substr(8))
		elif a.begins_with("--only="):
			only = a.substr(7)
	_env()
	await call("_batch%d" % batch)
	log_line("DONE")


func _env() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.34, 0.44)
	sky_mat.sky_horizon_color = Color(0.70, 0.60, 0.50)
	sky_mat.ground_bottom_color = Color(0.12, 0.1, 0.1)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 60, 0)
	sun.light_energy = 1.8
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var g := MeshInstance3D.new()
	g.mesh = A.quad(1000, 1000)
	g.material_override = A.ground()
	add_child(g)
	cam = Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	cam.make_current()


func _at(pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	n.rotation_degrees = rot
	return n


func _shoot(name: String, eye: Vector3, at: Vector3, wire := false) -> void:
	if only != "" and not name.begins_with(only):
		return
	cam.position = eye
	cam.look_at(at)
	await wait(0.6)
	var f := "lpcmp_b%d_%s_%s.png" % [batch, name, tag]
	await shot(f)
	log_line("shot " + f)
	if wire:
		var ov: Array = []
		_wire_overlay(self, ov)
		await wait(0.3)
		f = "lpcmp_b%d_%sw_%s.png" % [batch, name, tag]
		await shot(f)
		for o in ov:
			o.queue_free()
		log_line("shot " + f)


## 线框叠加（Compatibility 渲染器不支持 DEBUG_DRAW_WIREFRAME，自建三角形边线）
func _wire_overlay(n: Node, ov: Array) -> void:
	for c in n.get_children():
		_wire_overlay(c, ov)
	if not (n is MeshInstance3D) or n.mesh == null or n.mesh is PlaneMesh or n.has_meta("wire"):
		return
	var mi: MeshInstance3D = n
	if mi.global_position.distance_to(cam.global_position) > 8.0:
		return
	var lm := ImmediateMesh.new()
	lm.surface_begin(Mesh.PRIMITIVE_LINES)
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var tri: PackedInt32Array = idx if idx != null and idx.size() > 0 else PackedInt32Array(range(v.size()))
		for t in range(0, tri.size() - 2, 3):
			for e in [[0, 1], [1, 2], [2, 0]]:
				lm.surface_add_vertex(v[tri[t + e[0]]])
				lm.surface_add_vertex(v[tri[t + e[1]]])
	lm.surface_end()
	var w := MeshInstance3D.new()
	w.mesh = lm
	w.set_meta("wire", true)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.9, 1.0)
	mat.no_depth_test = false
	w.material_override = mat
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(w)
	ov.append(w)


# ---------------- 批次 2：P0-CORE-01~05（cyl / sphere / tube / hose / capsule）
func _batch2() -> void:
	var st := A.paint(Color(0.42, 0.44, 0.40), 0.55, 0.4, {"wear": 0.4})
	var ch := A.chrome()
	var br := A.metal(Color(0.62, 0.48, 0.24))
	# CORE-01 cyl：5 边细杆（r=0.06）、10 边中管（r=0.15）、14 边罐体（r=0.6）、12 边锥形炮口
	var z := 0.0
	var n := _at(Vector3(0, 0, z))
	A.add(n, A.cyl(0.06, 1.6, 0.06, 5), st, Vector3(-1.5, 0.8, 0))
	A.add(n, A.cyl(0.15, 1.2, 0.15, 10), st, Vector3(-0.8, 0.6, 0))
	A.add(n, A.cyl(0.6, 1.3, 0.6, 14), st, Vector3(0.5, 0.65, -0.3))
	A.add(n, A.cyl(0.10, 0.9, 0.22, 12), ch, Vector3(1.6, 0.45, 0.3))
	await _shoot("1_cyl", Vector3(0.0, 3.0, z + 3.9), Vector3(0, 0.6, z), true)
	# CORE-02 sphere：小球 r=0.1（seg 10）、中球 r=0.4（seg 14）、穹顶 r=0.7
	z = 20.0
	n = _at(Vector3(0, 0, z))
	A.add(n, A.sphere(0.10, -1, 10), ch, Vector3(-1.1, 0.45, 0.4))
	A.add(n, A.sphere(0.40, -1, 14), st, Vector3(-0.3, 0.5, 0))
	A.add(n, A.sphere(0.70, 0.7), br, Vector3(1.1, 0.0, -0.3))
	await _shoot("2_sphere", Vector3(0.0, 1.5, z + 3.8), Vector3(0, 0.4, z), true)
	# CORE-03 tube：默认参数的弯管（r=0.05 / r=0.12）
	z = 40.0
	n = _at(Vector3(0, 0, z))
	var pipe := MeshInstance3D.new()
	pipe.mesh = A.tube([Vector3(-1.5, 0.15, 0), Vector3(-0.8, 0.9, 0.2), Vector3(0.0, 0.6, -0.2), Vector3(0.9, 1.1, 0.1), Vector3(1.5, 0.3, 0)], 0.05)
	pipe.material_override = A.rubber()
	n.add_child(pipe)
	var duct := MeshInstance3D.new()
	duct.mesh = A.tube([Vector3(-1.4, 0.2, -0.8), Vector3(-0.4, 0.4, -0.6), Vector3(0.6, 0.2, -0.9), Vector3(1.4, 0.6, -0.7)], 0.12)
	duct.material_override = st
	n.add_child(duct)
	await _shoot("3_tube", Vector3(0.0, 1.7, z + 3.6), Vector3(0, 0.55, z - 0.2), true)
	# CORE-04 hose：下垂软管 + 端接头（安装在两块法兰板之间）
	z = 60.0
	n = _at(Vector3(0, 0, z))
	A.add(n, A.bevel_box(Vector3(0.5, 0.9, 0.5), 0.03), st, Vector3(-1.1, 0.45, 0))
	A.add(n, A.bevel_box(Vector3(0.5, 1.2, 0.5), 0.03), st, Vector3(1.1, 0.6, 0))
	A.hose(n, Vector3(-0.85, 0.75, 0.05), Vector3(0.85, 1.0, 0.05), Vector3(0, -0.45, 0.1), 0.045)
	A.hose(n, Vector3(-0.85, 0.45, -0.1), Vector3(0.85, 0.5, -0.1), Vector3(0, -0.25, 0.05), 0.03)
	await _shoot("4_hose", Vector3(0.2, 1.3, z + 2.6), Vector3(0, 0.6, z), true)
	# CORE-05 capsule：r=0.12 / r=0.3 / r=0.6
	z = 80.0
	n = _at(Vector3(0, 0, z))
	A.add(n, A.capsule(0.12, 1.0), ch, Vector3(-1.1, 0.5, 0.3))
	A.add(n, A.capsule(0.3, 1.2), st, Vector3(-0.2, 0.6, 0))
	A.add(n, A.capsule(0.6, 1.4), br, Vector3(1.2, 0.0, -0.3), Vector3(0, 0, 90))
	await _shoot("5_capsule", Vector3(0.0, 1.5, z + 4.0), Vector3(0, 0.5, z), true)
	# 实机：背部护盾机甲（软管 + 大量圆柱件）
	z = 100.0
	var m: Node3D = MV.build({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_lau61", "arm_r": "arm_mg", "back": "back_shield", "gen": "gen_crystal"}, true)
	add_child(m)
	m.position = Vector3(0, 0, z)
	m.rotation_degrees.y = 150
	await _shoot("6_mech", Vector3(2.2, 3.2, z + 4.6), Vector3(0, 2.0, z))


func _bug(kind: String, pos: Vector3, ry := 168.0) -> Node3D:
	var info: Dictionary = GameData.ENEMIES.get(kind, {})
	var s: Script = load(str(info.get("script", "")))
	if s == null:
		return null
	var b = s.new()
	add_child(b)
	b.kind = kind
	b.data = info
	b.ai = str(info.get("ai", "lancer"))
	b.hover = float(info.get("hover", 0.0))
	b.set_physics_process(false)
	b.set_process(false)
	b._build_visual()
	b.position = pos
	b.rotation_degrees.y = ry
	return b


# ---------------- 批次 3：P0-CORE-06~10（torus / 力场弧幕 / 岩石与树干 / kit 共用件 / 虫类扫掠）
func _batch3() -> void:
	const K = preload("res://scripts/modules/kit.gd")
	var st := A.paint(Color(0.42, 0.44, 0.40), 0.55, 0.4, {"wear": 0.4})
	var br := A.metal(Color(0.62, 0.48, 0.24))
	# CORE-06 torus：管道法兰、细密封圈、大型井口环
	var z := 0.0
	var n := _at(Vector3(0, 0, z))
	A.add(n, A.cyl(0.18, 1.6, 0.18), st, Vector3(-1.0, 0.8, 0))
	A.add(n, A.torus(0.17, 0.26), br, Vector3(-1.0, 0.5, 0))
	A.add(n, A.torus(0.17, 0.24, 18), br, Vector3(-1.0, 1.1, 0))
	A.add(n, A.torus(0.04, 0.10, 16), A.chrome(), Vector3(-0.2, 0.25, 0.6), Vector3(70, 0, 0))
	A.add(n, A.torus(0.85, 1.05, 24), st, Vector3(0.9, 0.11, -0.3))
	await _shoot("1_torus", Vector3(0.0, 2.0, z + 3.7), Vector3(0, 0.5, z), true)
	# CORE-07 reactive_arc：三处调用参数（护盾虫 3×10 / 耗材 4×12 / 玩家 5×14）
	z = 20.0
	var specs := [[0.8, 0.95, 3, 10, Color(1.0, 0.55, 0.25, 0.9), -2.2], [1.0, 1.1, 4, 12, Color(0.5, 1.0, 0.6, 0.9), 0.0], [1.2, 1.25, 5, 14, Color(0.42, 0.78, 1.0, 0.88), 2.6]]
	for sp in specs:
		var mi := MeshInstance3D.new()
		mi.mesh = A.reactive_arc_mesh(sp[0], sp[1], sp[2], sp[3])
		mi.material_override = A.reactive_arc_mat(sp[4])
		mi.position = Vector3(sp[5], 1.3, z)
		add_child(mi)
	await _shoot("2_arc", Vector3(0.0, 2.6, z + 6.2), Vector3(0, 1.2, z), true)
	# CORE-08 树干 + 岩石
	z = 40.0
	for i in 2:
		var t := MeshInstance3D.new()
		t.mesh = A.tree_trunk_mesh(i, i == 1)
		t.material_override = A.paint(Color(0.30, 0.24, 0.18), 0.85, 0.0, {"wear": 0.2})
		t.position = Vector3(-1.5 + i * 1.6, 0, z)
		t.scale = Vector3.ONE * 2.6
		add_child(t)
	var rk := MeshInstance3D.new()
	rk.mesh = A.rock_mesh(3)
	rk.material_override = A.paint(Color(0.45, 0.42, 0.38), 0.9, 0.0, {"wear": 0.1})
	rk.position = Vector3(1.6, 0.4, z + 0.3)
	rk.scale = Vector3.ONE * 0.9
	add_child(rk)
	await _shoot("3_tree_rock", Vector3(0.0, 2.2, z + 5.0), Vector3(0, 1.1, z), true)
	# CORE-09 kit：液压活塞 / 散热孔 / 膛口
	z = 60.0
	n = _at(Vector3(0, 0, z))
	A.add(n, A.bevel_box(Vector3(1.4, 0.8, 0.3), 0.03), st, Vector3(0, 0.6, -0.4))
	K.piston(n, Vector3(-0.9, 0.2, 0.1), Vector3(-0.2, 1.1, 0.1), 0.05)
	K.holes(n, Vector3(0.3, 0.75, -0.24), Vector3.ZERO, 5, 3, 0.09, 0.03)
	A.add(n, A.cyl(0.10, 0.9, 0.10), st, Vector3(0.8, 0.35, 0.3), Vector3(90, 0, 0))
	K.barrel_bore(n, 0.10, 0.07, Vector3(0.8, 0.35, 0.75))
	await _shoot("4_kit", Vector3(0.6, 1.2, z + 2.6), Vector3(0, 0.55, z), true)
	# CORE-10 虫类：螳螂 / 黄蜂（_sweep、_ball）
	z = 80.0
	_bug("mantis", Vector3(-1.4, 0, z), 150.0)
	_bug("wasp", Vector3(1.4, 0, z), 200.0)
	await _shoot("5_bugs", Vector3(0.0, 2.2, z + 5.5), Vector3(0, 1.0, z))


## 读取游戏脚本里 reactive_arc_mesh 调用实际使用的 (blades, segs)，保证前后对比走的是当时的真实参数
func _arc_args(path: String) -> Array:
	var src := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("reactive_arc_mesh\\(.*,\\s*(\\d+),\\s*(\\d+)\\)")
	var m := re.search(src)
	return [int(m.get_string(1)), int(m.get_string(2))] if m else [5, 14]


func _arc(pos: Vector3, r: float, h: float, args: Array, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = A.reactive_arc_mesh(r, h, args[0], args[1])
	var mat := A.reactive_arc_mat(c)
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


# ---------------- 批次 4：P0-SKL-04/05/06/07/09
func _batch4() -> void:
	var sky_dark := ProceduralSkyMaterial.new()
	var z := 0.0
	# SKL-04 玩家护盾
	var m: Node3D = MV.build({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_shield", "gen": "gen_crystal"}, true)
	add_child(m)
	m.position = Vector3(0, 0, z)
	m.rotation_degrees.y = 160
	_arc(Vector3(0, 1.55, z), 1.52, 1.55, _arc_args("res://scripts/mech.gd"), Color(0.42, 0.78, 1.0, 0.88))
	await _shoot("1_shield_player", Vector3(0.0, 2.4, z + 5.4), Vector3(0, 1.4, z), true)
	# SKL-05 耗材冲击壳
	z = 20.0
	_arc(Vector3(0, 1.3, z), 1.2, 1.3, _arc_args("res://scripts/modules/weapon_fx.gd"), Color(0.5, 1.0, 0.55, 0.9))
	await _shoot("2_shield_item", Vector3(0.0, 2.0, z + 4.4), Vector3(0, 1.1, z), true)
	# SKL-06 护盾虫护盾
	z = 40.0
	_bug("shielder", Vector3(0, 0, z), 180.0)
	_arc(Vector3(0, 0.9, z), 1.0, 1.1, _arc_args("res://scripts/enemies/enemy.gd"), Color(1.0, 0.62, 0.3, 0.9))
	await _shoot("3_shield_enemy", Vector3(0.0, 1.8, z + 4.0), Vector3(0, 0.8, z), true)
	# SKL-07 背部护盾发生器（绝缘子 / 探针特写）
	z = 60.0
	var BS = load("res://scripts/modules/back_shield.gd")
	var m2: Node3D = BS.build({"id": "back_shield", "color": Color(0.46, 0.50, 0.42)})
	add_child(m2)
	m2.position = Vector3(0, 0.3, z)
	m2.rotation_degrees.y = 180
	await _shoot("4_back_shield", Vector3(0.9, 1.6, z + 1.5), Vector3(0, 0.95, z - 0.1))
	# SKL-09 近战挥砍刀光
	z = 80.0
	var src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	var newer := src.contains("slash_arc_mesh(")
	var p := Vector3(0, 1.2, z)
	var holder := _at(Vector3.ZERO)
	var dir := Vector3(0, 0, 1)
	var side := dir.cross(Vector3.UP)
	for k in 3:
		var AA: Variant = A
		var mesh: Mesh = AA.slash_arc_mesh(2.2 + k * 0.3, 0.16 - k * 0.03, 0.42) if newer else A.capsule(0.05, 2.2 + k * 0.3)
		var mi: MeshInstance3D = A.add(holder, mesh, A.emit(Color(1.0, 0.95, 0.85), 3.0), p + side * (k - 1) * 0.55 + Vector3(0, 0.2 * k, 0), Vector3.ZERO, Vector3.ONE, false)
		mi.look_at(p + dir * 3.0 + Vector3(0, -0.5, 0), Vector3.UP)
		mi.rotate_object_local(Vector3.FORWARD, PI * 0.5)
	await _shoot("5_slash", Vector3(2.6, 3.0, z + 3.2), Vector3(0, 1.2, z), true)


# ---------------- 批次 5：P0-SKL-10 + P0-MSL-01~04
func _batch5() -> void:
	var R = load("res://scripts/raid.gd").new()
	var z := 0.0
	# MSL-01 导弹 / 火箭 / VLS
	var kinds := ["missile", "rocket", "vls"]
	for i in kinds.size():
		var n := _at(Vector3(-1.1 + i * 1.1, 0.7, z), Vector3(0, 90 + 25, 0))
		n.scale = Vector3.ONE * 2.4
		R._populate_proj_body(n, kinds[i], 0.12)
	await _shoot("1_missile", Vector3(0.0, 1.5, z + 2.6), Vector3(0, 0.7, z), true)
	# MSL-02 酸液 / 燃烧 / 液氮 / 默认炮弹
	z = 20.0
	var k2 := ["spit", "flamer", "cryo", "shell"]
	for i in k2.size():
		var n := _at(Vector3(-1.2 + i * 0.8, 0.7, z), Vector3(0, 90 + 25, 0))
		n.scale = Vector3.ONE * 2.6
		R._populate_proj_body(n, k2[i], 0.12)
	await _shoot("2_canister", Vector3(0.0, 1.4, z + 2.4), Vector3(0, 0.7, z), true)
	# MSL-03 实弹弹丸
	z = 40.0
	var cal := ["apfsds", "sniper", "coil", "cannon", "ac30", "slug", "pellet", "mg"]
	for i in cal.size():
		var n := _at(Vector3(-0.95 + (i % 4) * 0.62, 0.5, z - 0.35 + (i / 4) * 0.55), Vector3(0, 90 + 20, 0))
		n.scale = Vector3.ONE * 2.2
		R._populate_tracer_body(n, cal[i], 0.024, 0.28, Color(1.0, 0.7, 0.3))
	await _shoot("3_tracer", Vector3(0.0, 1.35, z + 2.0), Vector3(0, 0.45, z), true)
	# MSL-04 弹壳 / 弹托瓣 / 破片
	z = 60.0
	var items: Array = [R._casing_mesh(false, false), R._casing_mesh(true, false), R._casing_mesh(false, true), R._sabot_petal_mesh(), R._debris_mesh("metal"), R._debris_mesh("rock"), R._debris_mesh("chitin")]
	for i in items.size():
		var mi := MeshInstance3D.new()
		mi.mesh = items[i]
		mi.position = Vector3(-1.35 + i * 0.45, 0.35, z)
		mi.rotation_degrees = Vector3(20, 35 + i * 20, 10)
		mi.scale = Vector3.ONE * 3.0
		add_child(mi)
	await _shoot("4_casing_debris", Vector3(0.0, 1.3, z + 2.5), Vector3(0, 0.3, z), true)
	# SKL-10 撤离信号弹罐
	z = 80.0
	var src := FileAccess.get_file_as_string("res://scripts/modules/item_flare.gd")
	var zn := _at(Vector3(0, 0, z))
	if src.contains("build_flare_canister"):
		var MMs: Variant = load("res://scripts/modules/munition_models.gd")
		MMs.build_flare_canister(zn, Color(1.0, 0.62, 0.24))
	await _shoot("5_flare", Vector3(0.5, 0.7, z + 1.0), Vector3(0, 0.1, z))
	R.free()


class FakeRaid extends Node3D:
	var fx: Node3D
	var coop = null


# ---------------- 批次 6：P0-MSL-06~10
func _batch6() -> void:
	const HZ = preload("res://scripts/enemies/hazards.gd")
	const WFX = preload("res://scripts/modules/weapon_fx.gd")
	var fr := FakeRaid.new()
	add_child(fr)
	fr.fx = Node3D.new()
	fr.add_child(fr.fx)
	var z := 0.0
	# MSL-06 迫击炮弹
	var ls = HZ.LobShell.new()
	add_child(ls)
	ls.setup(fr, Vector3(0, 1.0, z), Vector3(0, 0, z - 30), 99.0, 3.0, 10.0)
	ls.set_process(false)
	ls.position = Vector3(0, 1.0, z)
	ls.body.rotation_degrees = Vector3(0, 0, -70)
	await _shoot("1_mortar", Vector3(0.3, 1.5, z + 2.1), Vector3(0, 1.0, z), true)
	ls.queue_free()
	# MSL-07 动能穿甲弹
	z = 20.0
	var ks = HZ.KineticSlug.new()
	add_child(ks)
	ks.setup(fr, Vector3(0, 1.0, z), Vector3(1, 0, -0.3), 60.0, 10.0)
	ks.set_process(false)
	ks.set_physics_process(false)
	await _shoot("2_slug", Vector3(0.6, 1.5, z + 2.3), Vector3(0.3, 1.0, z), true)
	# MSL-08 轨道炮/激光箭弹
	z = 40.0
	WFX.beam(fr, Vector3(-0.8, 1.0, z), Vector3(3.0, 1.0, z - 1.0), Color(0.6, 0.8, 1.0), 0.05, 60.0)
	await _shoot("3_beam", Vector3(0.0, 1.4, z + 1.8), Vector3(0.0, 1.0, z), true)
	# MSL-09 背部发射巢 / MSL-10 手臂发射巢（整机特写）
	z = 60.0
	var m: Node3D = MV.build({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_ram116", "arm_r": "arm_lau61", "back": "back_vls", "gen": "gen_crystal"}, true)
	add_child(m)
	m.position = Vector3(0, 0, z)
	m.rotation_degrees.y = 200
	await _shoot("4_launchers_a", Vector3(1.0, 3.6, z + 6.8), Vector3(0, 2.7, z))
	z = 80.0
	var m2: Node3D = MV.build({"core": "core_assault", "legs": "legs_quad", "arm_l": "arm_tos220", "arm_r": "arm_kornet", "back": "back_rocket", "gen": "gen_crystal"}, true)
	add_child(m2)
	m2.position = Vector3(0, 0, z)
	m2.rotation_degrees.y = 160
	await _shoot("5_launchers_b", Vector3(-1.0, 3.6, z + 6.8), Vector3(0, 2.7, z))


# ---------------- 批次 7（返工）：SKL-04/05/06 蜂窝护盾、SKL-07 背部护盾、MSL-08 脱壳箭弹
func _shield(pos: Vector3, r: float, h: float, src_path: String, panels: int, segs: int, c: Color) -> void:
	var AA: Variant = A
	var src := FileAccess.get_file_as_string(src_path)
	var mi := MeshInstance3D.new()
	if src.contains("aegis_shield_mesh("):
		mi.mesh = AA.call("aegis_shield_mesh", r, h, panels, segs)
		mi.material_override = AA.call("aegis_shield_mat", c)
	else:
		var args := _arc_args(src_path)
		mi.mesh = A.reactive_arc_mesh(r, h, args[0], args[1])
		mi.material_override = A.reactive_arc_mat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)


func _batch7() -> void:
	var z := 0.0
	var m: Node3D = MV.build({"core": "core_heavy", "legs": "legs_quad", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_shield", "gen": "gen_crystal"}, true)
	add_child(m)
	m.position = Vector3(0, 0, z)
	m.rotation_degrees.y = 160
	_shield(Vector3(0, 1.55, z), 1.52, 1.55, "res://scripts/mech.gd", 6, 36, Color(0.42, 0.78, 1.0, 0.88))
	await _shoot("1_shield_player", Vector3(0.0, 3.2, z + 7.2), Vector3(0, 1.5, z))
	z = 20.0
	var crate := MeshInstance3D.new()
	crate.mesh = A.bevel_box(Vector3(0.9, 0.9, 0.9), 0.05)
	crate.material_override = A.metal(Color(0.35, 0.36, 0.30))
	crate.position = Vector3(0, 0.45, z)
	add_child(crate)
	_shield(Vector3(0, 1.3, z), 1.52, 1.68, "res://scripts/modules/weapon_fx.gd", 8, 32, Color(0.5, 1.0, 0.55, 0.9))
	await _shoot("2_shield_item", Vector3(0.0, 2.6, z + 6.0), Vector3(0, 1.1, z))
	z = 40.0
	_bug("shielder", Vector3(0, 0, z), 180.0)
	_shield(Vector3(0, 0.9, z), 1.0, 1.1, "res://scripts/enemies/enemy.gd", 5, 28, Color(1.0, 0.62, 0.3, 0.9))
	await _shoot("3_shield_enemy", Vector3(0.0, 2.0, z + 4.6), Vector3(0, 0.8, z))
	z = 60.0
	var BS = load("res://scripts/modules/back_shield.gd")
	var m2: Node3D = BS.build({"id": "back_shield", "color": Color(0.46, 0.50, 0.42)})
	add_child(m2)
	m2.position = Vector3(0, 0.3, z)
	m2.rotation_degrees.y = 200
	await _shoot("4_back_shield", Vector3(1.3, 2.0, z + 2.0), Vector3(0, 1.0, z))
	z = 80.0
	var MMs = load("res://scripts/modules/munition_models.gd")
	var r := 0.05
	var L := 1.2
	var holder := _at(Vector3(0, 1.0, z), Vector3(0, 0, -90))
	if FileAccess.get_file_as_string("res://scripts/modules/munition_models.gd").contains("func build_apfsds_dart"):
		var petals: Array = MMs.call("build_apfsds_dart", holder, r, L)
		for pt in petals:
			var hn: Node3D = pt
			hn.position += hn.basis * Vector3(0, 0.04, -0.07)
			hn.rotate_object_local(Vector3.RIGHT, -0.12)
	else:
		var hz := _at(Vector3(0, 1.0, z), Vector3(0, -90, 0))
		holder.queue_free()
		var m_tung := A.metal(Color(0.22, 0.24, 0.26))
		var m_copper := A.paint(Color(0.84, 0.46, 0.24), 0.88, 0.28, {"panel_scale": 0.0})
		A.add(hz, A.cyl(r * 0.82, L * 0.72, r, 20), m_tung, Vector3(0, 0, L * 0.08), Vector3(90, 0, 0), Vector3.ONE, false)
		A.add(hz, A.cyl(0.005, L * 0.30, r * 0.82, 20), A.chrome(), Vector3(0, 0, -L * 0.42), Vector3(-90, 0, 0), Vector3.ONE, false)
		A.add(hz, A.cyl(r * 1.18, L * 0.07, r * 1.18, 20), m_copper, Vector3(0, 0, -L * 0.05), Vector3(90, 0, 0), Vector3.ONE, false)
		for fi in 2:
			A.add(hz, MMs.fin_pair(Vector3(r * 0.24, r * 2.4, L * 0.22)), m_tung, Vector3(0, 0, L * 0.34), Vector3(0, 0, fi * 90.0), Vector3.ONE, false)
	await _shoot("5_dart", Vector3(0.35, 1.55, z + 2.5), Vector3(0.0, 1.0, z))


# ---------------- 批次 8（返工）：MSL-09/10 发射管口、MSL-03 实弹、CORE-04 软管、CORE-03 管线
func _mod(path: String, id: String, pos: Vector3, ry := 180.0, extra := {}) -> Node3D:
	var S = load(path)
	var ctx := {"id": id, "color": Color(0.30, 0.33, 0.26), "side": 1.0, "slot": "arm_r"}
	ctx.merge(extra, true)
	var n: Node3D = S.build(ctx)
	add_child(n)
	n.position = pos
	n.rotation_degrees.y = ry
	return n


func _batch8() -> void:
	var z := 0.0
	_mod("res://scripts/modules/arm_lau61.gd", "arm_lau61", Vector3(-0.15, 1.2, z), 180.0)
	_mod("res://scripts/modules/arm_ram116.gd", "arm_ram116", Vector3(1.55, 1.2, z), 180.0)
	await _shoot("1_arm_pods", Vector3(0.0, 1.5, z + 4.2), Vector3(0.0, 1.15, z))
	z = 20.0
	_mod("res://scripts/modules/arm_kornet.gd", "arm_kornet", Vector3(-0.05, 1.2, z))
	_mod("res://scripts/modules/arm_tos220.gd", "arm_tos220", Vector3(1.6, 1.2, z))
	await _shoot("2_arm_atgm", Vector3(0.1, 1.5, z + 4.4), Vector3(0.1, 1.2, z))
	z = 40.0
	var br_n := _mod("res://scripts/modules/back_rocket.gd", "back_rocket", Vector3(0, 0.6, z), 180.0, {"slot": "back"})
	br_n.rotation_degrees.x = 0
	await _shoot("3_back_rocket", Vector3(0.4, 1.4, z + 3.0), Vector3(0, 1.0, z))
	z = 60.0
	var R = load("res://scripts/raid.gd").new()
	var cal := ["apfsds", "sniper", "coil", "cannon", "ac30", "slug", "pellet", "mg"]
	for i in cal.size():
		var n := _at(Vector3(-0.42 + (i / 4) * 0.84, 1.42 - (i % 4) * 0.16, z), Vector3(0, 90, 0))
		n.scale = Vector3.ONE * 2.0
		R._populate_tracer_body(n, cal[i], 0.024, 0.28, Color(1.0, 0.7, 0.3))
	await _shoot("4_tracer", Vector3(0.0, 1.2, z + 2.3), Vector3(0, 1.18, z))
	z = 80.0
	var AA: Variant = A
	var has_pipe := FileAccess.get_file_as_string("res://scripts/art.gd").contains("static func pipe(")
	var rig := _at(Vector3(0, 0, z))
	K_plate(rig)
	for k in 3:
		var y := 0.7 + k * 0.32
		A.hose(rig, Vector3(-1.0, y, 0.1), Vector3(-0.1, y + 0.05, 0.1), Vector3(0, -0.12, 0.05), 0.028 + k * 0.008)
	var pts := [Vector3(0.15, 0.6, 0.1), Vector3(0.45, 0.6, 0.1), Vector3(0.55, 0.9, 0.1), Vector3(0.55, 1.2, 0.1), Vector3(0.95, 1.35, 0.1)]
	var mesh: Mesh = AA.call("pipe", pts, 0.04, 14, 10) if has_pipe else A.tube(pts, 0.04, 14, 10)
	A.add(rig, mesh, A.paint(Color(0.80, 0.44, 0.24), 0.9, 0.28, {"panel_scale": 0.0}), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
	var pts2 := [Vector3(0.15, 0.35, 0.25), Vector3(0.6, 0.38, 0.3), Vector3(1.0, 0.5, 0.25)]
	var mesh2: Mesh = AA.call("pipe", pts2, 0.03, 14, 10) if has_pipe else A.tube(pts2, 0.03, 14, 10)
	A.add(rig, mesh2, A.metal(Color(0.5, 0.5, 0.48)), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, true)
	await _shoot("5_hose_pipe", Vector3(0.0, 1.0, z + 2.0), Vector3(0.0, 0.95, z))


func K_plate(rig: Node3D) -> void:
	var w := MeshInstance3D.new()
	w.mesh = A.bevel_box(Vector3(2.4, 1.5, 0.06), 0.02)
	w.material_override = A.metal(Color(0.22, 0.23, 0.22))
	w.position = Vector3(0, 0.95, -0.05)
	rig.add_child(w)


func _probe() -> Node:
	var R = load("res://tests/lib/raid_probe.gd").new()
	R.world = Node3D.new()
	add_child(R.world)
	return R


func _batch9() -> void:
	var R = _probe()
	var EV = load("res://scripts/map_ext/events.gd").new()
	EV.raid = R
	# 1 空投伞 + 空投舱（悬空，取下落中的样子）
	var z := 0.0
	EV._supply_drop(Vector3(0, 0, z))
	var drop: Node3D = EV._falling[0].node
	drop.position = Vector3(0, 0.6, z)
	await _shoot("1_airdrop", Vector3(14.0, 5.0, z + 18.0), Vector3(0, 5.6, z))
	await _shoot("1b_pod", Vector3(2.6, 1.9, z + 4.0), Vector3(0, 1.7, z))
	# 2 求救信标台
	z = 40.0
	var dn := _at(Vector3(0, 0, z))
	if FileAccess.get_file_as_string("res://scripts/map_ext/events.gd").contains("build_distress_beacon"):
		load("res://scripts/modules/field_models.gd").build_distress_beacon(dn, A.paint(Color(0.30, 0.34, 0.28), 0.42, 0.58, {"rust": 0.55, "wear": 0.55}), Color(1.0, 0.18, 0.12))
	else:
		_old_distress(dn)
	await _shoot("2_distress", Vector3(3.2, 2.6, z + 6.0), Vector3(0, 2.1, z))
	# 3 撤离信标塔 + 频闪桩 / 机降区
	z = 80.0
	var ex = load("res://scripts/extract_zone.gd").new()
	add_child(ex)
	ex.position = Vector3(0, 0, z)
	ex.setup("A", Color(0.3, 1.0, 0.5), 8.0, false)
	await _shoot("3_extract", Vector3(11.5, 3.2, z + 7.5), Vector3(5.6, 2.6, z))
	await _shoot("3b_bollard", Vector3(3.9, 1.0, z + 4.4), Vector3(3.3, 0.35, z + 2.9))
	# 4 枯树 + 河滩卵石
	z = 120.0
	R.rng.seed = 7
	for k in 3:
		R._dead_tree(Vector3(-3.0 + k * 3.0, 0, z))
	var AA: Variant = A
	var FMs = load("res://scripts/modules/field_models.gd") if FileAccess.file_exists("res://scripts/modules/field_models.gd") and FileAccess.get_file_as_string("res://scripts/raid.gd").contains("pebble_mesh") else null
	var rr := RandomNumberGenerator.new()
	rr.seed = 3
	var stone_root := _at(Vector3.ZERO)
	var stone_m := A.rock_mat(Color(0.46, 0.42, 0.36)) if FMs else A.concrete(Color(0.46, 0.42, 0.36), false)
	for i in 14:
		var sc := rr.randf_range(0.25, 0.6)
		var pos := Vector3(rr.randf_range(-2.5, 2.5), sc * 0.1, z + 3.0 + rr.randf_range(-0.8, 0.8))
		var mesh: Mesh = FMs.pebble_mesh(i % 3) if FMs else A.sphere(0.5, -1, 8)
		A.add(stone_root, mesh, stone_m, pos, Vector3(rr.randf_range(-20, 20), rr.randf() * 360.0, 0), Vector3(sc * 1.3, sc * 0.5, sc))
	await _shoot("4_tree", Vector3(0.5, 3.0, z + 9.5), Vector3(0, 2.2, z))
	await _shoot("4b_stone", Vector3(0.0, 1.5, z + 6.8), Vector3(0, 0.1, z + 3.0))
	# 5 坦克 / 装甲车残骸
	z = 160.0
	R.rng.seed = 1
	var found_tank := false
	var found_apc := false
	for t in 40:
		var s0: int = R.rng.seed
		var r0: float = R.rng.randf()
		R.rng.seed = s0
		if r0 < 0.55 and not found_tank:
			R._tank_wreck(Vector3(-4.0, 0, z))
			found_tank = true
		elif r0 >= 0.55 and not found_apc:
			R._tank_wreck(Vector3(5.0, 0, z))
			found_apc = true
		else:
			R.rng.seed = s0 + 1
		if found_tank and found_apc:
			break
	R._flush_inst()
	await _shoot("5_tank", Vector3(1.8, 3.0, z + 6.8), Vector3(-4.0, 0.9, z))
	await _shoot("5e_tank", Vector3(1.5, 4.5, z - 6.5), Vector3(-4.0, 0.9, z))
	await _shoot("5f_tank", Vector3(-10.5, 3.0, z + 5.0), Vector3(-4.0, 0.9, z))
	await _shoot("5b_apc", Vector3(10.5, 2.6, z + 5.5), Vector3(5.0, 0.9, z))
	await _shoot("5c_apc", Vector3(9.5, 4.2, z - 6.0), Vector3(5.0, 0.9, z))
	await _shoot("5d_apc", Vector3(0.5, 3.4, z - 3.5), Vector3(5.0, 0.9, z))


## 求救信标台改前外观（events.gd HEAD 版本的造型段落原样复刻）
func _old_distress(n: Node3D) -> void:
	var M_DARK := A.metal(Color(0.16, 0.17, 0.18))
	var M_ST := A.metal(Color(0.38, 0.39, 0.37))
	var M_CASE := A.paint(Color(0.30, 0.34, 0.28), 0.42, 0.58, {"rust": 0.55, "wear": 0.55})
	for lg in 3:
		var la := TAU * float(lg) / 3.0 + 0.2
		A.add(n, A.tube([Vector3(cos(la) * 0.82, 0.04, sin(la) * 0.82), Vector3(cos(la) * 0.18, 1.25, sin(la) * 0.18)], 0.042, 6, 2), M_ST)
		A.add(n, A.bevel_box(Vector3(0.22, 0.08, 0.22), 0.02), M_DARK, Vector3(cos(la) * 0.82, 0.04, sin(la) * 0.82))
	A.add(n, A.bevel_box(Vector3(0.76, 0.52, 0.56), 0.04), M_CASE, Vector3(0, 1.42, 0))
	A.add(n, A.bevel_box(Vector3(0.78, 0.10, 0.58), 0.01), A.hazard(), Vector3(0, 1.24, 0))
	A.add(n, A.bevel_box(Vector3(0.68, 0.05, 0.48), 0.01), A.paint(Color(0.10, 0.16, 0.24), 0.65, 0.28), Vector3(0, 1.52, 0.48), Vector3(34, 0, 0))
	A.add(n, A.cyl(0.055, 1.85, 0.075, 10), M_ST, Vector3(0, 2.55, 0))
	A.add(n, A.cyl(0.16, 0.28, 0.18, 12), M_DARK, Vector3(0, 3.48, 0))
	A.add(n, A.cyl(0.11, 0.22, 0.11, 12), A.emit(Color(1.0, 0.18, 0.12), 3.0), Vector3(0, 3.68, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.torus(0.14, 0.17, 12), M_DARK, Vector3(0, 3.74, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.cyl(0.022, 1.75, 0.035, 6), M_ST, Vector3(0.28, 4.15, 0), Vector3(0, 0, -14))
