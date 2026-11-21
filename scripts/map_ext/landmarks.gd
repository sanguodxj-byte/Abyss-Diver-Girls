extends RefCounted
## 战区地标：读取当前战区条目里的 landmarks（[{"type", "x", "z", "rot", "water"}]），
## 在遗迹与街区建完之后、撤离点与虫群生成之前摆放，占地登记进 raid.blocks（撤离点与后续布景会避让）。
## 地标只提供体量与剪影，不刷怪、不放战利品；"water": true 的条目允许压在水面上（断桥、栈桥）。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")
const WC = preload("res://scripts/world_city.gd")
const BossLM = preload("res://scripts/map_ext/landmarks_boss.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")

const STEEL := Color(0.32, 0.32, 0.3)
const CONCRETE := Color(0.48, 0.46, 0.42)


static func build(raid, _drop: Vector3) -> void:
	_clear_aprons(raid)
	var made: Array = []
	for e in raid.MAP.get("landmarks", []):
		var t := str(e.get("type", ""))
		var ls: Vector2 = WC.landmark_spot(raid.map_id, e)   # 已避开遗迹院落的确定性落位点
		var p := Vector3(ls.x, 0, ls.y)
		var rot := float(e.get("rot", 0))
		var clear := float(e.get("clear", 7.0))
		if not bool(e.get("water", false)) and raid._blocked(p, clear, false):
			p = _nudge(raid, p, clear)
		if p.x == INF:
			continue
		_build_one(raid, t, p, rot)
		var item := {"type": t, "x": p.x, "z": p.z, "rot": rot}
		if BossLM.is_boss_landmark(t):
			var ap := BossLM.arena_pos(t, p, rot)
			item["arena_x"] = ap.x
			item["arena_z"] = ap.z
		made.append(item)
	raid.set_meta("ext_landmarks", made)


## 被既有楼体占住时向外找空地，找不到就跳过（不硬塞，避免和街区叠在一起）
static func _nudge(raid, p: Vector3, clear: float) -> Vector3:
	for relax in [1.0, 0.62, 0.38]:
		var c: float = clear * float(relax)
		var best := Vector3(INF, 0, 0)
		var bd := INF
		for dz in range(-52, 53, 4):
			for dx in range(-52, 53, 4):
				var d := float(dx * dx + dz * dz)
				if d >= bd:
					continue
				var q := p + Vector3(dx, 0, dz)
				if absf(q.x) > 166.0 or absf(q.z) > 166.0 or not raid.in_bounds_xz(Vector2(q.x, q.z), 8.0):
					continue
				if not raid._blocked(q, c, false):
					bd = d
					best = q
		if best.x != INF:
			return best
	return Vector3(INF, 0, 0)


static func _build_one(raid, t: String, p: Vector3, rot: float) -> void:
	if BossLM.build(raid, t, p, rot):
		return
	match t:
		"broken_bridge": _broken_bridge(raid, p, rot)
		"radio_mast": _radio_mast(raid, p, rot)
		"elevated_road": _elevated_road(raid, p, rot)
		"gantry": _gantry(raid, p, rot)
		"blast_furnace": _blast_furnace(raid, p, rot)
		"gas_holder": _gas_holder(raid, p, rot)
		"windmill": _windmill(raid, p, rot)
		"pylon_row": _pylon_row(raid, p, rot)
		"silo": _silo(raid, p, rot)
		"boardwalk": _boardwalk(raid, p, rot)
		"observation_tower": _observation_tower(raid, p, rot)
		"cable_tower": _cable_tower(raid, p, rot)
		"ore_silos": _ore_silos(raid, p, rot)
		"rope_bridge": _rope_bridge(raid, p, rot)
		"crystal_cluster": _crystal_cluster(raid, p, rot)
		"drill_derrick": _drill_derrick(raid, p, rot)
		"coolant_channel": _coolant_channel(raid, p, rot)
	_register_landmark_loot(raid, t, p, rot)


## 为每座地标建筑按功能在出入口/检修平台/桥头登记严格匹配的固定物资箱锚点（正面朝外）
static func _register_landmark_loot(raid, t: String, p: Vector3, rot: float) -> void:
	if not raid.has_method("register_loot_anchor"):
		return
	var rad := deg_to_rad(rot)
	var lm_tag := "landmark:" + t
	var add_lm := func(off: Vector3, kind: String, prio: int, custom_out := Vector3.ZERO) -> void:
		var wp := p + off.rotated(Vector3.UP, rad)
		var base_out := custom_out if custom_out.length_squared() > 0.01 else Vector3(off.x, 0.0, off.z)
		var out_v := base_out.normalized().rotated(Vector3.UP, rad)
		var yaw: float = raid._face_outward_yaw(out_v) if raid.has_method("_face_outward_yaw") else rot
		raid.register_loot_anchor(wp, yaw, kind, prio, lm_tag, out_v)
	match t:
		"broken_bridge":
			add_lm.call(Vector3(-18.5, 0, 2.4), "ammo", 96, Vector3(-1, 0, 0))
			add_lm.call(Vector3(18.5, 0, -2.4), "car_wreck", 94, Vector3(0, 0, -1))
		"radio_mast":
			add_lm.call(Vector3(5.6, 0, 3.6), "tech", 96)
			add_lm.call(Vector3(-5.6, 0, 3.2), "safe", 95)
		"elevated_road":
			add_lm.call(Vector3(6.4, 0, 4.2), "military", 96, Vector3(0, 0, 1))
			add_lm.call(Vector3(-6.4, 0, -4.2), "car_wreck", 93, Vector3(0, 0, -1))
		"gantry":
			add_lm.call(Vector3(8.6, 0, 4.6), "container", 96, Vector3(0, 0, 1))
			add_lm.call(Vector3(-8.6, 0, -4.2), "tool", 93, Vector3(0, 0, -1))
		"blast_furnace":
			add_lm.call(Vector3(8.8, 0, 4.8), "tool", 97)
			add_lm.call(Vector3(-8.8, 0, 4.2), "tech", 95)
		"gas_holder":
			add_lm.call(Vector3(8.2, 0, 3.8), "tool", 95)
		"windmill":
			add_lm.call(Vector3(6.2, 0, 4.0), "supply", 95)
			add_lm.call(Vector3(-6.2, 0, 3.6), "tool", 92)
		"pylon_row":
			add_lm.call(Vector3(4.6, 0, 2.8), "tech", 92)
		"silo":
			add_lm.call(Vector3(7.8, 0, 4.4), "supply", 95)
			add_lm.call(Vector3(-7.6, 0, 3.8), "tool", 92)
		"boardwalk":
			add_lm.call(Vector3(-12.5, 0, 2.8), "supply", 95)
			add_lm.call(Vector3(12.5, 0, -2.8), "cache", 92)
		"observation_tower":
			add_lm.call(Vector3(5.8, 0, 3.4), "tech", 96)
			add_lm.call(Vector3(-5.8, 0, 3.0), "safe", 95)
		"cable_tower":
			add_lm.call(Vector3(6.2, 0, 3.8), "tool", 95)
			add_lm.call(Vector3(-6.0, 0, 3.4), "supply", 92)
		"ore_silos":
			add_lm.call(Vector3(8.4, 0, 4.8), "tool", 96)
			add_lm.call(Vector3(-8.2, 0, 4.4), "cache", 94)
		"rope_bridge":
			add_lm.call(Vector3(-7.8, 0, 2.4), "cache", 93)
		"crystal_cluster":
			add_lm.call(Vector3(7.4, 0, 2.8), "cache", 97)
			add_lm.call(Vector3(-7.4, 0, -2.6), "safe", 95)
		"drill_derrick":
			add_lm.call(Vector3(9.2, 0, 4.6), "tech", 97)
			add_lm.call(Vector3(-9.0, 0, 4.8), "tool", 95)
		"coolant_channel":
			add_lm.call(Vector3(6.2, 0, 9.0), "tech", 96)
			add_lm.call(Vector3(-6.2, 0, 9.0), "cache", 95)


## 灰港断桥：两截错位的桥面悬在河上（T型盖梁桥墩 + 桥底钢箱梁 + 柏油标线桥面 + 防撞护墙），中段整跨塌进水里
static func _broken_bridge(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.concrete(Color(0.44, 0.43, 0.4), true)
	var M_DARK := A.concrete(Color(0.35, 0.34, 0.32), false)
	var M_ASPH := A.asphalt(Color(0.19, 0.195, 0.205))
	var M_GIRDER := A.paint(Color(0.26, 0.24, 0.22), 0.62, 0.58, {"rust": 0.82, "wear": 0.6})
	var R := A.paint(Color(0.35, 0.2, 0.12), 0.5, 0.7, {"rust": 0.9, "wear": 0.6})
	var rad_rot := deg_to_rad(rot)
	for sgn in [-1.0, 1.0]:
		var deck := Node3D.new()
		n.add_child(deck)
		deck.position = Vector3(sgn * 10.0, 5.2, 0)
		deck.rotation_degrees = Vector3(0, 0, sgn * 3.0)
		A.add(deck, A.bevel_box(Vector3(11.0, 0.72, 9.0), 0.08), M, Vector3.ZERO)
		A.add(deck, A.bevel_box(Vector3(10.9, 0.08, 8.1), 0.02), M_ASPH, Vector3(0, 0.38, 0), Vector3.ZERO, Vector3.ONE, false)
		for ld in 3:
			A.add(deck, A.bevel_box(Vector3(1.8, 0.02, 0.16), 0.004), A.paint(Color(0.68, 0.66, 0.56), 0.0, 0.9, {"wear": 0.82}), Vector3(-3.6 + ld * 3.6, 0.43, 0), Vector3.ZERO, Vector3.ONE, false)
		for gz in [-2.8, 2.8]:
			A.add(deck, A.bevel_box(Vector3(11.2, 0.58, 0.46), 0.03), M_GIRDER, Vector3(0, -0.62, gz))
		for pz in [-4.35, 4.35]:
			A.add(deck, A.bevel_box(Vector3(10.94, 0.66, 0.32), 0.04), A.concrete(Color(0.5, 0.49, 0.45), false), Vector3(0, 0.64, pz))
			A.add(deck, A.bevel_box(Vector3(10.8, 0.07, 0.09), 0.01), A.metal(STEEL), Vector3(0, 1.08, pz), Vector3.ZERO, Vector3.ONE, false)
		# T型盖梁桥墩与承台
		A.add(n, A.bevel_box(Vector3(3.6, 0.65, 4.2), 0.08), M_DARK, Vector3(sgn * 8.0, 0.32, 0))
		A.add(n, A.bevel_box(Vector3(2.8, 4.2, 3.2), 0.1), A.concrete(Color(0.4, 0.39, 0.36), false), Vector3(sgn * 8.0, 2.35, 0))
		A.add(n, A.bevel_box(Vector3(3.2, 0.85, 8.4), 0.08), M_DARK, Vector3(sgn * 8.0, 4.45, 0))
		K.blocker(raid, p + Vector3(sgn * 8.0, 0, 0).rotated(Vector3.UP, rad_rot), Vector3(3.0, 6.0, 3.4), rot)
		# 断口扭曲钢筋簇
		for i in 7:
			A.add(n, A.cyl(0.045, 2.8 + (i % 2) * 0.8, 0.045, 8), R, Vector3(sgn * (4.1 + (i % 3) * 0.28), 5.15 + (i % 2) * 0.22, -3.4 + i * 1.12), Vector3((i - 3) * 6.0, 0, sgn * (66 + (i % 3) * 8.0)))
		# 桥面残存的高杆路灯
		A.add(n, A.cyl(0.08, 5.0, 0.11, 12), A.metal(STEEL), Vector3(sgn * 14.0, 7.8, 4.0))
		A.add(n, A.bevel_box(Vector3(1.1, 0.14, 0.32), 0.02), A.metal(STEEL), Vector3(sgn * 14.4, 10.2, 4.0))
		raid.blocks.append(raid._rect_for(p + Vector3(sgn * 10.0, 0, 0).rotated(Vector3.UP, rad_rot), Vector3(11.0, 1, 9.0)))
	# 塌在水里的中跨与钢箱梁残段
	A.add(n, A.bevel_box(Vector3(10.0, 0.62, 7.2), 0.06), M, Vector3(0.0, 0.45, 0.6), Vector3(4, 12, 2))
	A.add(n, A.bevel_box(Vector3(9.6, 0.45, 0.42), 0.03), M_GIRDER, Vector3(0.2, 0.82, -1.8), Vector3(4, 12, 8))
	# 桥上的废车与断护栏立柱
	raid._wreck_car(p + Vector3(-13.0, 5.6, 1.0).rotated(Vector3.UP, rad_rot))
	raid._wreck_car(p + Vector3(11.0, 5.6, -1.6).rotated(Vector3.UP, rad_rot))
	for sgn in [-1.0, 1.0]:
		for i in 4:
			A.add(n, A.bevel_box(Vector3(0.18, 0.95, 0.42), 0.03), A.metal(STEEL), Vector3(sgn * 12.6, 6.25, -3.2 + i * 2.2), Vector3(0, 0, sgn * -6))


## 灰港广播塔：塔顶折弯的战损格构通讯铁塔 + 坠落微波锅 + 受损机房（lm_radio_mast 精修巨构）
static func _radio_mast(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var sz := Vector3(12.0, 21.8, 12.0)
	PrefabLib.place_at_ground(raid, n, "lm_radio_mast", Vector3(0.0, -0.04, 0.0), 0.0, sz, false, null, false)
	K.blocker(raid, p, Vector3(4.8, 18.0, 4.8), rot)
	raid.blocks.append(raid._rect_for(p, Vector3(11.6, 1.0, 11.6)))


## 高架路残段：T型盖梁独柱墩上的断头高架（预制箱梁 + 柏油路面标线 + 双侧防撞墙），端头钢筋散开
static func _elevated_road(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.concrete(Color(0.42, 0.41, 0.38), true)
	var M_DARK := A.concrete(Color(0.35, 0.34, 0.31), false)
	var M_ASPH := A.asphalt(Color(0.18, 0.185, 0.195))
	var M_GIRDER := A.paint(Color(0.28, 0.27, 0.25), 0.58, 0.58, {"rust": 0.72, "wear": 0.55})
	for i in 3:
		var x := -12.0 + i * 12.0
		var span := Node3D.new()
		n.add_child(span)
		span.position = Vector3(x, 7.4, 0)
		var w_sp := 11.0 if i == 2 else 11.6
		if i == 2:
			span.rotation_degrees = Vector3(0, 0, -7)
		A.add(span, A.bevel_box(Vector3(w_sp, 0.82, 10.0), 0.08), M, Vector3.ZERO)
		A.add(span, A.bevel_box(Vector3(w_sp - 0.1, 0.08, 9.1), 0.02), M_ASPH, Vector3(0, 0.43, 0), Vector3.ZERO, Vector3.ONE, false)
		for ld in 3:
			A.add(span, A.bevel_box(Vector3(2.0, 0.02, 0.16), 0.004), A.paint(Color(0.68, 0.65, 0.54), 0.0, 0.9, {"wear": 0.8}), Vector3(-3.8 + ld * 3.8, 0.48, 0), Vector3.ZERO, Vector3.ONE, false)
		for gz in [-3.1, 3.1]:
			A.add(span, A.bevel_box(Vector3(w_sp - 0.08, 0.62, 0.48), 0.03), M_GIRDER, Vector3(0, -0.68, gz))
		for pz in [-4.8, 4.8]:
			if i == 2 and pz < 0.0:
				continue
			A.add(span, A.bevel_box(Vector3(w_sp - 0.06, 0.72, 0.34), 0.04), A.concrete(Color(0.48, 0.47, 0.43), false), Vector3(0, 0.70, pz))
		A.add(n, A.bevel_box(Vector3(2.8, 0.55, 3.2), 0.06), M_DARK, Vector3(x, 0.28, 0))
		A.add(n, A.bevel_box(Vector3(2.0, 5.8, 2.4), 0.1), A.concrete(Color(0.4, 0.39, 0.36), false), Vector3(x, 3.15, 0))
		A.add(n, A.bevel_box(Vector3(2.5, 0.95, 9.2), 0.08), M_DARK, Vector3(x, 6.35, 0))
		K.blocker(raid, p + Vector3(x, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(2.0, 7.0, 2.4), rot)
		raid.blocks.append(raid._rect_for(p + Vector3(x, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(11.8, 1, 10.4)))
	for i in 8:
		A.add(n, A.cyl(0.05, 2.8, 0.05, 8), A.paint(Color(0.35, 0.2, 0.12), 0.5, 0.7, {"rust": 0.9}), Vector3(18.4, 6.8 + (i % 2) * 0.28, -4.2 + i * 1.2), Vector3((i - 4) * 5.0, 0, -58 - (i % 3) * 6.0))
	raid._wreck_car(p + Vector3(-9.0, 8.0, 0.6).rotated(Vector3.UP, deg_to_rad(rot)))


## 铁锈龙门吊：轨道上的重型双梁门式起重机与编组站信号灯桥（B6-29 poi_gantry_rail 精修巨构）
static func _gantry(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var sz := Vector3(19.8, 15.2, 13.0)
	PrefabLib.place_at_ground(raid, n, "poi_gantry_rail", Vector3(0, -0.05, 0), 0.0, sz, false, null, true)
	var rad_r := deg_to_rad(rot)
	var sx_leg := 6.15 * (sz.x / 15.8)
	var z_crane := 1.25 * (sz.z / 10.2)
	for sx in [-sx_leg, sx_leg]:
		var wp := p + Vector3(sx, 0.0, z_crane).rotated(Vector3.UP, rad_r)
		K.blocker(raid, wp, Vector3(1.6, 13.0, 4.4), rot)
		raid.blocks.append(raid._rect_for(wp, Vector3(2.8, 1.0, 4.8)))
	var c_wp := p + Vector3(0.0, 0.0, z_crane).rotated(Vector3.UP, rad_r)
	K.blocker(raid, c_wp, Vector3(2.8, 2.8, 6.2), rot)
	raid.blocks.append(raid._rect_for(p, Vector3(20.4, 1.0, 12.6)))


## 一号钢厂高炉：高面数粗筒炉身 + 炉腹收口 + 环形热风围管 + 三层环形检修平台与立柱框架 + 上料斜桥
static func _blast_furnace(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.paint(Color(0.4, 0.3, 0.24), 0.5, 0.6, {"rust": 0.9, "wear": 0.5, "dust": 0.4, "panel_scale": 1.0})
	var M2 := A.paint(Color(0.34, 0.26, 0.21), 0.5, 0.6, {"rust": 0.9, "wear": 0.5, "dust": 0.4})
	var M_ST := A.metal(STEEL)
	# 圆形阶梯炉基 + 42 段高炉筒身
	A.add(n, A.cyl(6.2, 1.4, 6.5, 42), A.concrete(Color(0.34, 0.32, 0.29), false), Vector3(0, 0.7, 0))
	A.add(n, A.cyl(5.0, 6.0, 5.6, 42), M, Vector3(0, 3.6, 0))
	A.add(n, A.cyl(3.6, 10.0, 5.0, 42), M, Vector3(0, 11.4, 0))
	A.add(n, A.cyl(2.4, 3.2, 3.6, 38), M2, Vector3(0, 17.8, 0))
	A.add(n, A.cyl(1.3, 2.2, 2.2, 32), A.metal(Color(0.3, 0.29, 0.27)), Vector3(0, 20.2, 0))
	# 炉腰粗壮热风围管 + 8 根外围框架立柱 + 三层环形检修走道平台
	A.add(n, A.torus(5.3, 5.95, 42), M2, Vector3(0, 4.2, 0))
	for k in 8:
		var a := TAU * k / 8.0
		A.add(n, A.cyl(0.22, 17.5, 0.26, 16), M_ST, Vector3(cos(a) * 5.4, 9.0, sin(a) * 5.4))
	for idx in 3:
		var y: float = [6.4, 12.2, 16.6][idx]
		var r_plat: float = [5.4, 4.7, 3.9][idx]
		A.add(n, A.cyl(r_plat + 0.5, 0.16, r_plat + 0.5, 42), M_ST, Vector3(0, y, 0))
		A.add(n, A.torus(r_plat + 0.38, r_plat + 0.52, 42), M_ST, Vector3(0, y + 0.65, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	K.pipe(raid, p + Vector3(4.0, 6.0, 0).rotated(Vector3.UP, deg_to_rad(rot)), p + Vector3(18.0, 1.0, 6.0).rotated(Vector3.UP, deg_to_rad(rot)), 0.42)
	# 斜桥（内端接入高炉炉身，外端落地）
	A.add(n, A.bevel_box(Vector3(3.0, 0.4, 18.0), 0.05), A.paint(Color(0.36, 0.33, 0.28), 0.5, 0.6, {"rust": 0.8}), Vector3(4.5, 5.3, 5.5), Vector3(36, 38, 0))
	# 炉顶烟与矿渣堆
	A.emitter(raid.world, p + Vector3(0, 21.5, 0), {"amount": 10, "life": 7.0, "size": 3.4, "tex": A.smoke_tex(), "additive": false, "spread": 16.0,
		"vmin": 0.8, "vmax": 1.6, "gravity": Vector3(0.5, 0.7, 0.2), "c0": Color(0.16, 0.13, 0.11, 0.4), "c1": Color(0.3, 0.28, 0.25, 0.0), "grow0": 0.7, "grow1": 3.0})
	for i in 4:
		var a := TAU * i / 4.0 + 0.6
		A.add(n, A.cyl(0.4, 1.6, 3.0, 24), A.concrete(Color(0.2, 0.18, 0.16), false), Vector3(cos(a) * 9.0, 0.8, sin(a) * 9.0))
	K.blocker(raid, p, Vector3(10.6, 20.0, 10.6), 0.0, true)
	raid.blocks.append(raid._rect_for(p, Vector3(11.0, 1, 11.0)))


## 煤气罐区：高细分球形储气罐架在八柱环形钢架上，带经纬向加强箍、顶部放散阀台与地面阀门站
static func _gas_holder(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_ST := A.metal(STEEL)
	var M_RING := A.metal(Color(0.34, 0.33, 0.3))
	# 圆形混凝土地坪圈梁 + 8 根外圈承重钢柱
	A.add(n, A.cyl(5.8, 0.3, 6.0, 42), A.concrete(Color(0.38, 0.37, 0.34), false), Vector3(0, 0.15, 0))
	for k in 8:
		var a := TAU * k / 8.0
		A.add(n, A.cyl(0.22, 9.6, 0.26, 18), M_ST, Vector3(cos(a) * 5.2, 4.8, sin(a) * 5.2))
	# 42 段高细分球罐主体 + 纬向环形检修走道 + 经向焊缝肋环 + 罐顶安全阀冠
	A.add(n, A.sphere(5.6, -1, 42), A.paint(Color(0.52, 0.5, 0.44), 0.5, 0.55, {"rust": 0.7, "wear": 0.5, "dust": 0.5, "panel_scale": 1.6}), Vector3(0, 10.0, 0))
	for y_info in [[6.2, 4.4, 4.8], [10.0, 5.5, 5.95], [13.8, 4.4, 4.8]]:
		A.add(n, A.torus(y_info[1], y_info[2], 42), M_RING, Vector3(0, y_info[0], 0), Vector3.ZERO, Vector3(1, 0.45, 1))
	for k in 2:
		A.add(n, A.torus(5.52, 5.68, 40), M_RING, Vector3(0, 10.0, 0), Vector3(90, k * 90.0, 0), Vector3(1, 1, 0.35), false)
	A.add(n, A.cyl(1.4, 0.4, 1.5, 32), M_ST, Vector3(0, 15.6, 0))
	A.add(n, A.torus(1.35, 1.46, 32), M_ST, Vector3(0, 16.2, 0), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	K.pipe(raid, p + Vector3(4.0, 1.0, 0).rotated(Vector3.UP, deg_to_rad(rot)), p + Vector3(20.0, 1.0, 5.0).rotated(Vector3.UP, deg_to_rad(rot)), 0.34)
	K.pipe(raid, p + Vector3(0, 5.0, 4.6).rotated(Vector3.UP, deg_to_rad(rot)), p + Vector3(0, 0.4, 12.0).rotated(Vector3.UP, deg_to_rad(rot)), 0.28)
	A.add(n, A.cyl(0.65, 1.3, 0.72, 28), A.paint(Color(0.36, 0.32, 0.24), 0.5, 0.6, {"rust": 0.8}), Vector3(0, 0.65, 11.4))
	A.add(n, A.torus(0.9, 1.1, 28), A.metal(Color(0.55, 0.4, 0.15)), Vector3(0, 1.35, 11.4))
	K.blocker(raid, p, Vector3(9.6, 16.0, 9.6), 0.0, true)
	raid.blocks.append(raid._rect_for(p, Vector3(9.0, 1, 9.0)))


## 平原风车阵：三座战损风力发电机残塔排成一列（lm_wind_turbine 精修巨构：断翼坠落、焦灼机舱与塔基变电站）
static func _windmill(raid, p: Vector3, rot: float) -> void:
	var base := p
	var sz := Vector3(12.2, 18.8, 7.7)
	for i in 3:
		var q := base + Vector3(-15.0 + i * 15.0, 0, 0).rotated(Vector3.UP, deg_to_rad(rot))
		var n := Node3D.new()
		raid.world.add_child(n)
		n.position = q
		n.rotation_degrees.y = rot + float(i - 1) * 18.0
		PrefabLib.place_at_ground(raid, n, "lm_wind_turbine", Vector3(0.0, -0.04, 0.0), 0.0, sz, false, null, false)
		K.blocker(raid, q, Vector3(2.6, 17.0, 2.6), 0.0, true)
		raid.blocks.append(raid._rect_for(q, Vector3(5.6, 1.0, 5.6)))


## 高压电塔列：四座格构塔拉着一路垂下的导线
static func _pylon_row(raid, p: Vector3, rot: float) -> void:
	var prev := Vector3.ZERO
	for i in 4:
		var q := p + Vector3(-15.0 + i * 10.0, 0, 0).rotated(Vector3.UP, deg_to_rad(rot))
		K.lattice(raid, q, 12.0, 2.0)
		if i > 0:
			for off in [-0.9, 0.9]:
				K.cable(raid, prev + Vector3(0, 11.0, off).rotated(Vector3.UP, deg_to_rad(rot)), q + Vector3(0, 11.0, off).rotated(Vector3.UP, deg_to_rad(rot)), 1.6, 0.035)
		prev = q


## 农场筒仓与防空雷达台站：双联波纹钢筒仓 + 刮板连廊提升机 + 相控阵雷达地堡（B6-28 poi_silo_radar）
static func _silo(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var sz := Vector3(16.8, 12.6, 11.2)
	PrefabLib.place_at_ground(raid, n, "poi_silo_radar", Vector3(0, -0.05, 0), 0.0, sz, false, null, true)
	var rad_r := deg_to_rad(rot)
	var sx_sc := sz.x / 14.4
	var sz_sc := sz.z / 9.6
	for sx_s in [-4.55 * sx_sc, -0.85 * sx_sc]:
		var sp := p + Vector3(sx_s, 0.0, 0.25 * sz_sc).rotated(Vector3.UP, rad_r)
		K.blocker(raid, sp, Vector3(3.8, 10.5, 3.8), 0.0, true)
	var bp := p + Vector3(4.45 * sx_sc, 0.0, -0.25 * sz_sc).rotated(Vector3.UP, rad_r)
	K.blocker(raid, bp, Vector3(5.2, 5.2, 6.4), rot)
	raid.blocks.append(raid._rect_for(p, Vector3(16.8, 1.0, 10.8)))


## 赤湖观景栈桥：木栈道伸进湖里，尽头一座塌了半边的观景亭
static func _boardwalk(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var WOOD := A.paint(Color(0.32, 0.26, 0.19), 0.0, 0.9, {"wear": 0.7, "dust": 0.5, "panel_scale": 0.6})
	A.add(n, A.bevel_box(Vector3(5.0, 0.24, 22.0), 0.05), WOOD, Vector3(0, 0.12, 0))
	for k in 11:
		A.add(n, A.bevel_box(Vector3(4.9, 0.03, 0.14), 0.01), A.paint(Color(0.24, 0.2, 0.15), 0.0, 0.9, {"wear": 0.8}), Vector3(0, 0.25, -10.0 + k * 2.0))
	for sx in [-2.3, 2.3]:
		K.railing(raid, p + Vector3(sx, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), 22.0, rot + 90.0, 1.0)
		for k in 4:
			A.add(n, A.cyl(0.18, 2.6, 0.18, 16), A.paint(Color(0.26, 0.21, 0.15), 0.0, 0.9), Vector3(sx, -1.0, -8.0 + k * 5.4))
	# 观景亭：四柱 + 破顶（基座落地，立柱与坡顶紧密衔接）
	var pav := Vector3(0, 0, -9.0)
	A.add(n, A.bevel_box(Vector3(5.4, 0.26, 5.4), 0.05), A.concrete(Color(0.4, 0.38, 0.34), false), pav + Vector3(0, 0.13, 0))
	for sx in [-2.0, 2.0]:
		for sz in [-2.0, 2.0]:
			A.add(n, A.cyl(0.14, 2.8, 0.14, 16), A.paint(Color(0.3, 0.24, 0.18), 0.0, 0.9), pav + Vector3(sx, 1.62, sz))
			K.blocker(raid, p + (pav + Vector3(sx, 0, sz)).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(0.3, 3.0, 0.3), 0.0, true)
	A.add(n, A.prism(PackedVector2Array([Vector2(-3.0, 0), Vector2(0, 1.8), Vector2(3.0, 0)]), 5.0, 0.06), A.paint(Color(0.3, 0.24, 0.17), 0.1, 0.85, {"wear": 0.6}), pav + Vector3(0, 2.98, 0), Vector3(2, 6, 0))
	K.bench(raid, p + pav.rotated(Vector3.UP, deg_to_rad(rot)) + Vector3(0, 0.2, 1.6).rotated(Vector3.UP, deg_to_rad(rot)), rot)
	K.lamp(raid, p + Vector3(0, 0, -7.0).rotated(Vector3.UP, deg_to_rad(rot)), Color(1.0, 0.75, 0.45))


## 环湖装甲瞭望哨塔：炮击战损装甲哨塔 + 折斜雷达 + 钢梯与防爆基座（lm_observation_tower 精修巨构）
static func _observation_tower(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var sz := Vector3(8.2, 15.4, 8.2)
	PrefabLib.place_at_ground(raid, n, "lm_observation_tower", Vector3(0.0, -0.04, 0.0), 0.0, sz, false, null, false)
	K.blocker(raid, p, Vector3(6.4, 12.0, 6.4), rot)
	raid.blocks.append(raid._rect_for(p, Vector3(8.4, 1.0, 8.4)))


## 峡谷缆车塔：两座塔架隔谷对望，承载索上挂着走行滑轮架、弯臂吊杆与工业货运缆车厢
static func _cable_tower(raid, p: Vector3, rot: float) -> void:
	var dir := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(rot))
	var a := p - dir * 15.0
	var b := p + dir * 15.0
	var M_ST := A.metal(STEEL)
	var M_DARK := A.metal(Color(0.16, 0.17, 0.18))
	K.lattice(raid, a, 16.0, 3.0)
	K.lattice(raid, b, 16.0, 3.0)
	for tw in [a, b]:
		A.add(raid.world, A.bevel_box(Vector3(1.2, 0.55, 4.2), 0.05), M_ST, tw + Vector3(0, 16.3, 0), Vector3(0, rot, 0))
		for off_s in [-1.2, 1.2]:
			var s_pos: Vector3 = tw + dir.cross(Vector3.UP) * off_s + Vector3(0, 16.3, 0)
			A.add(raid.world, A.cyl(0.38, 0.16, 0.38, 18), M_DARK, s_pos, Vector3(0, rot + 90.0, 90.0))
	var side := dir.cross(Vector3.UP)
	for off in [-1.2, 1.2]:
		K.cable(raid, a + side * off + Vector3(0, 16.2, 0), b + side * off + Vector3(0, 16.2, 0), 2.2, 0.045)
	var cab_n := Node3D.new()
	raid.world.add_child(cab_n)
	cab_n.position = p + side * -1.2 + Vector3(0, 10.2, 0)
	cab_n.rotation_degrees = Vector3(3, rot, -2)
	var M_CAB := A.paint(Color(0.52, 0.40, 0.18), 0.42, 0.58, {"wear": 0.65, "rust": 0.62, "panel_scale": 0.9})
	# 顶部双轮走行小车 + 弯臂C型钢吊架 + 工业缆车轿厢（环绕观察窗格 + 橡胶防撞腰带）
	A.add(cab_n, A.bevel_box(Vector3(2.1, 0.32, 0.36), 0.04), M_DARK, Vector3(0, 3.80, 0))
	for wx_c in [-0.68, 0.68]:
		A.add(cab_n, A.cyl(0.28, 0.14, 0.28, 16), M_ST, Vector3(wx_c, 3.85, 0), Vector3(90, 0, 0))
	A.add(cab_n, A.tube([Vector3(0, 3.72, 0), Vector3(0, 3.15, 0.85), Vector3(0, 1.95, 0.85), Vector3(0, 1.32, 0)], 0.09, 8, 3), M_ST, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(cab_n, A.bevel_box(Vector3(3.2, 2.35, 2.15), 0.16, 0.90), M_CAB, Vector3.ZERO)
	A.add(cab_n, A.bevel_box(Vector3(3.28, 0.18, 2.24), 0.03), A.rubber(), Vector3(0, -0.58, 0))
	A.add(cab_n, A.bevel_box(Vector3(3.26, 0.20, 2.22), 0.02), A.hazard(), Vector3(0, -0.82, 0))
	A.add(cab_n, A.bevel_box(Vector3(2.75, 0.88, 2.20), 0.03), A.glass(Color(0.22, 0.36, 0.40)), Vector3(0, 0.32, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(cab_n, A.bevel_box(Vector3(3.24, 0.88, 1.65), 0.03), A.glass(Color(0.22, 0.36, 0.40)), Vector3(0, 0.32, 0), Vector3.ZERO, Vector3.ONE, false)
	for mx_c in [-0.92, 0.0, 0.92]:
		A.add(cab_n, A.bevel_box(Vector3(0.08, 0.94, 2.22), 0.01), M_DARK, Vector3(mx_c, 0.32, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(cab_n, A.bevel_box(Vector3(1.1, 0.24, 0.9), 0.03), M_DARK, Vector3(0, 1.28, 0))


## 矿场筒仓：三只高精度高筒仓 + 锥顶集尘塔 + 仓顶贯通皮带廊 + 斜皮带廊 + 装车口
static func _ore_silos(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CAP := A.paint(Color(0.42, 0.4, 0.36), 0.4, 0.6, {"rust": 0.6})
	var M_ST := A.metal(STEEL)
	for i in 3:
		var q := Vector3(-7.0 + i * 7.0, 0, 0)
		K.tower(raid, p + q.rotated(Vector3.UP, deg_to_rad(rot)), 2.8, 14.0, 2.8, Color(0.46, 0.44, 0.4))
		A.add(n, A.cyl(0.95, 2.2, 2.95, 40), M_CAP, q + Vector3(0, 15.1, 0))
		A.add(n, A.cyl(0.75, 1.4, 0.82, 28), M_ST, q + Vector3(0, 16.8, 0))
		A.add(n, A.torus(0.76, 0.9, 28), M_ST, q + Vector3(0, 17.4, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	# 贯通三座筒仓顶部的封闭配矿廊桥
	A.add(n, A.bevel_box(Vector3(16.2, 1.3, 1.8), 0.05), A.corrugated(Color(0.42, 0.40, 0.36), 0.58, 0.32), Vector3(0, 16.6, 0))
	A.add(n, A.bevel_box(Vector3(3.0, 0.5, 18.0), 0.06), A.corrugated(Color(0.34, 0.32, 0.29), 0.72, 0.32), Vector3(0.0, 8.0, 9.0), Vector3(-26, 0, 0))
	A.add(n, A.bevel_box(Vector3(4.6, 3.0, 4.0), 0.08), A.corrugated(Color(0.40, 0.36, 0.28), 0.65, 0.32), Vector3(0, 1.5, 5.0))
	raid.blocks.append(raid._rect_for(p + Vector3(0, 0, 5.0).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(5.0, 1, 4.4)))
	raid.blocks.append(raid._rect_for(p, Vector3(20.0, 1, 6.0)))


## 悬崖索桥：两座石砌锚塔之间垂着一条木板吊桥，中间缺了几块板
static func _rope_bridge(raid, p: Vector3, rot: float) -> void:
	var dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(rot))
	var a := p - dir * 16.0
	var b := p + dir * 16.0
	for q in [a, b]:
		A.add(raid.world, A.bevel_box(Vector3(3.6, 6.0, 3.6), 0.12), A.concrete(Color(0.42, 0.4, 0.36), true), q + Vector3(0, 3.0, 0))
		K.blocker(raid, q, Vector3(3.6, 6.0, 3.6), rot)
		raid.blocks.append(raid._rect_for(q, Vector3(3.8, 1, 3.8)))
	var side := dir.cross(Vector3.UP)
	for off in [-1.4, 1.4]:
		K.cable(raid, a + side * off + Vector3(0, 6.0, 0), b + side * off + Vector3(0, 6.0, 0), 2.0, 0.05)
	for k in 13:
		var t := float(k) / 12.0
		var q := a.lerp(b, t)
		q.y = 5.4 - sin(t * PI) * 2.4
		if k == 6:
			continue
		A.add(raid.world, A.bevel_box(Vector3(1.4, 0.12, 2.4), 0.03), A.paint(Color(0.34, 0.27, 0.19), 0.0, 0.9, {"wear": 0.8, "dust": 0.5}), q, Vector3(0, rot, 8.0 * (-1.0 if k % 2 == 0 else 1.0)))


## 深渊高压结晶矿脉露头与地质激光测绘阵（lm_crystal_survey_rig 精修巨构）
static func _crystal_cluster(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	A.ground_decal(raid.world, A.cloud_tex(), Color(0.09, 0.07, 0.11, 0.62), 14.0, p + Vector3(0, 0.03, 0))
	var sz := Vector3(9.6, 6.2, 8.7)
	PrefabLib.place_at_ground(raid, n, "lm_crystal_survey_rig", Vector3(0.0, -0.04, 0.0), 0.0, sz, false, null, false)
	K.blocker(raid, p, Vector3(4.2, 5.5, 4.2), 0.0, true)
	raid.blocks.append(raid._rect_for(p, Vector3(9.6, 1.0, 8.8)))


## 深渊封印井环门与地热钻井塔台（B6-30 poi_abyss_gate_rig 精修巨构）
static func _drill_derrick(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var sz := Vector3(16.0, 14.8, 16.0)
	PrefabLib.place_at_ground(raid, n, "poi_abyss_gate_rig", Vector3(0, -0.05, 0), 0.0, sz, false, null, true)
	var rad_r := deg_to_rad(rot)
	K.blocker(raid, p, Vector3(7.6, 14.0, 7.6), 0.0, true)
	var mb := p + Vector3(-4.65, 0.0, -4.65).rotated(Vector3.UP, rad_r)
	K.blocker(raid, mb, Vector3(3.4, 3.2, 2.8), rot)
	raid.blocks.append(raid._rect_for(p, Vector3(14.6, 1.0, 14.6)))


## 干涸冷却渠：一条 60 米长的混凝土渠槽横切过场地，渠底开裂、盖板翻倒
static func _coolant_channel(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M := A.concrete(Color(0.34, 0.33, 0.31), true)
	for sx in [-3.4, 3.4]:
		for seg in [[-15.0, 30.0], [24.0, 12.0]]:
			var cz: float = seg[0]
			var lz: float = seg[1]
			var wp := p + Vector3(sx, 0, cz).rotated(Vector3.UP, deg_to_rad(rot))
			A.add(n, A.bevel_box(Vector3(0.8, 2.4, lz), 0.08), M, Vector3(sx, 1.2, cz))
			K.blocker(raid, wp, Vector3(0.8, 2.4, lz), rot)
			raid.blocks.append(raid._rect_for(wp, Vector3(0.9, 1, lz)))
	A.add(n, A.bevel_box(Vector3(6.0, 0.26, 59.8), 0.05), A.concrete(Color(0.28, 0.27, 0.25), false), Vector3(0, 0.14, 0))
	A.add(n, A.bevel_box(Vector3(7.4, 0.22, 17.8), 0.05), A.concrete(Color(0.32, 0.31, 0.29), false), Vector3(0, 0.19, 9.0))
	for i in 6:
		var zc := -26.0 + i * 10.0
		var rx: float = raid.rng.randf_range(-1.2, 1.2)
		var rot_v := Vector3(raid.rng.randf_range(-16, 16), raid.rng.randf_range(-6, 6), raid.rng.randf_range(-18, 18))
		if zc < -2.0 or zc > 20.0:
			A.add(n, A.bevel_box(Vector3(6.6, 0.2, 6.0), 0.04), A.concrete(Color(0.3, 0.29, 0.27), false), Vector3(rx, 0.62, zc), rot_v)
	for i in 5:
		var zb := -24.0 + i * 12.0
		var rot_b := Vector3(0, raid.rng.randf_range(-8, 8), raid.rng.randf_range(-30, 30))
		if zb < -2.0 or zb > 20.0:
			A.add(n, A.bevel_box(Vector3(1.0, 1.6, 0.14), 0.02), A.paint(Color(0.3, 0.29, 0.26), 0.5, 0.6, {"rust": 0.7}), Vector3(0, 0.75, zb), rot_b)


## 程序化街区会在遗迹所在的整块街区里随机盖房，偶尔压进院落。
## 这里在自己摆地标之前，把落在新增遗迹院内的外来静态体清掉，保证院子与门口留得出来；
## 只动 StaticBody3D，容器与虫巢按组跳过，地面大盒体按尺寸跳过。
static func _clear_aprons(raid) -> void:
	var centers: Array = []
	for i in raid.poi_centers.size():
		if GameData.POIS.get(str(raid.poi_ids[i]), {}).has("script"):
			centers.append(raid.poi_centers[i])
	if centers.is_empty():
		return
	var trash: Array = []
	for ch in raid.world.get_children():
		if not (ch is StaticBody3D):
			continue
		if ch.has_meta("poi_built") or ch.has_meta("water_bank") or ch.is_in_group("lootboxes") or ch.is_in_group("nests") or ch.is_in_group("bugs"):
			continue
		if _huge_body(ch):
			continue
		var p: Vector3 = ch.global_position
		for c: Vector3 in centers:
			if Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z)) < 16.0:
				trash.append(ch)
				break
	for t in trash:
		t.free()


static func _huge_body(body: Node) -> bool:
	for ch in body.get_children():
		if ch is CollisionShape3D and ch.shape is BoxShape3D:
			var s: Vector3 = ch.shape.size
			if s.x > 50.0 or s.z > 50.0:
				return true
		elif ch is CollisionShape3D and ch.shape is CylinderShape3D and ch.shape.radius > 20.0:
			return true
	return false
