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
		"lighthouse": _prefab_landmark(raid, p, rot, "poi_abyss_lighthouse_remake", Vector3(14.0, 16.8, 12.0), Vector3(10.8, 14.0, 9.6), Vector3(14.4, 1.0, 12.4))
		"airship_mast": _prefab_landmark(raid, p, rot, "poi_airship_mooring_mast_remake", Vector3(16.0, 17.2, 14.0), Vector3(9.0, 15.0, 9.0), Vector3(16.0, 1.0, 14.0), true)
		"coastal_battery": _prefab_landmark(raid, p, rot, "poi_coastal_artillery_remake", Vector3(18.0, 10.6, 15.0), Vector3(14.6, 8.8, 11.8), Vector3(18.2, 1.0, 15.2))
		"cooling_tower": _prefab_landmark(raid, p, rot, "bldg_cooling_tower_unit_remake", Vector3(17.6, 16.4, 16.0), Vector3(13.2, 15.0, 13.2), Vector3(17.8, 1.0, 16.2), true)
		"drawbridge_gate": _prefab_landmark(raid, p, rot, "bldg_drawbridge_gatehouse_remake", Vector3(20.6, 13.0, 12.6), Vector3(17.2, 10.5, 9.8), Vector3(20.8, 1.0, 12.8))
		"observatory_dome": _prefab_landmark(raid, p, rot, "poi_astronomical_observatory_remake", Vector3(16.8, 13.8, 13.4), Vector3(13.0, 11.5, 10.6), Vector3(17.0, 1.0, 13.6))
		"biodome": _prefab_landmark(raid, p, rot, "poi_hydroponic_biodome_remake", Vector3(18.6, 11.4, 14.4), Vector3(14.4, 9.5, 11.2), Vector3(18.8, 1.0, 14.6))
		"radar_tower": _prefab_landmark(raid, p, rot, "poi_radar_array_tower_remake", Vector3(14.6, 15.4, 12.4), Vector3(10.6, 13.0, 9.6), Vector3(14.8, 1.0, 12.6))
		"geothermal_well": _prefab_landmark(raid, p, rot, "poi_geothermal_wellhead_remake", Vector3(17.6, 15.6, 13.0), Vector3(13.4, 13.5, 10.2), Vector3(17.8, 1.0, 13.2))
		"helipad_pad": _prefab_landmark(raid, p, rot, "b6_helipad", Vector3(11.8, 6.2, 8.6), Vector3(6.2, 4.8, 5.4), Vector3(12.0, 1.0, 8.8))
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
		"lighthouse":
			add_lm.call(Vector3(8.2, 0, 4.2), "tech", 96)
			add_lm.call(Vector3(-8.2, 0, 3.8), "supply", 94)
		"airship_mast":
			add_lm.call(Vector3(9.0, 0, 4.4), "military", 96)
			add_lm.call(Vector3(-8.8, 0, 4.0), "tech", 95)
		"coastal_battery":
			add_lm.call(Vector3(10.2, 0, 4.8), "weapon", 97)
			add_lm.call(Vector3(-10.2, 0, 4.4), "ammo", 95)
		"cooling_tower":
			add_lm.call(Vector3(9.8, 0, 4.8), "tool", 96)
			add_lm.call(Vector3(-9.8, 0, 4.2), "tech", 94)
		"drawbridge_gate":
			add_lm.call(Vector3(11.2, 0, 4.6), "military", 96)
			add_lm.call(Vector3(-11.2, 0, -4.4), "tool", 93)
		"observatory_dome":
			add_lm.call(Vector3(9.4, 0, 4.2), "tech", 97)
			add_lm.call(Vector3(-9.2, 0, 4.0), "safe", 95)
		"biodome":
			add_lm.call(Vector3(10.4, 0, 4.6), "med", 97)
			add_lm.call(Vector3(-10.2, 0, 4.2), "supply", 95)
		"radar_tower":
			add_lm.call(Vector3(8.4, 0, 4.2), "tech", 97)
			add_lm.call(Vector3(-8.2, 0, 3.8), "military", 94)
		"geothermal_well":
			add_lm.call(Vector3(9.8, 0, 4.4), "tech", 97)
			add_lm.call(Vector3(-9.6, 0, 4.2), "cache", 95)
		"helipad_pad":
			add_lm.call(Vector3(7.2, 0, 3.6), "military", 96)
			add_lm.call(Vector3(-7.0, 0, 3.2), "med", 94)


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


## 通用预制件地标放置器（直接走 raid.world -> _imesh -> 48m 分块合批与 MultiMesh）
static func _prefab_landmark(
	raid,
	p: Vector3,
	rot: float,
	prefab_id: String,
	sz: Vector3,
	col_sz: Vector3,
	block_sz: Vector3,
	cyl := false
) -> void:
	PrefabLib.place_at_ground(raid, raid.world, prefab_id, p + Vector3(0.0, -0.04, 0.0), rot, sz, false, null, false)
	K.blocker(raid, p, col_sz, rot, cyl)
	var fp := block_sz
	if not cyl and absf(fmod(absf(rot), 180.0) - 90.0) < 45.0:
		fp = Vector3(block_sz.z, block_sz.y, block_sz.x)
	raid.blocks.append(raid._rect_for(p, Vector3(fp.x, 1.0, fp.z)))


## 灰港广播塔：塔顶折弯的战损格构通讯铁塔 + 坠落微波锅 + 受损机房（lm_radio_mast 精修巨构）
static func _radio_mast(raid, p: Vector3, rot: float) -> void:
	var sz := Vector3(12.0, 21.8, 12.0)
	PrefabLib.place_at_ground(raid, raid.world, "lm_radio_mast", p + Vector3(0.0, -0.04, 0.0), rot, sz, false, null, false)
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


## 铁锈龙门吊：按港区/工业带自动匹配 Wave6 港口集装箱龙门吊、Wave4 干船坞重型门座吊或轨道龙门吊
static func _gantry(raid, p: Vector3, rot: float) -> void:
	var h := absi(hash("%s|%d|%d" % [raid.map_id, roundi(p.x), roundi(p.z)]))
	var pick := 0 if raid.map_id == "bayport" else (1 if (h % 3 == 0) else 2)
	if pick == 0:
		_prefab_landmark(raid, p, rot, "bldg_dockside_gantry_remake", Vector3(21.0, 15.2, 13.6), Vector3(17.4, 13.5, 10.6), Vector3(21.4, 1.0, 14.0))
		return
	if pick == 1:
		_prefab_landmark(raid, p, rot, "poi_drydock_crane_remake", Vector3(20.2, 16.4, 15.6), Vector3(16.6, 14.0, 12.4), Vector3(20.6, 1.0, 16.0))
		return
	var sz := Vector3(19.8, 15.2, 13.0)
	PrefabLib.place_at_ground(raid, raid.world, "poi_gantry_rail", p + Vector3(0.0, -0.05, 0.0), rot, sz, false, null, false)
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
		PrefabLib.place_at_ground(raid, raid.world, "lm_wind_turbine", q + Vector3(0.0, -0.04, 0.0), rot + float(i - 1) * 18.0, sz, false, null, false)
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


## 农场筒仓与粮仓提升塔：优先接入 Wave6 联体混凝土断仓粮仓与提升塔 / Batch6 残破筒仓变体
static func _silo(raid, p: Vector3, rot: float) -> void:
	var h := absi(hash("%s|%d|%d" % [raid.map_id, roundi(p.x), roundi(p.z)]))
	var pick := 0 if raid.map_id == "dustfield" else (1 if (h % 2 == 0) else 2)
	if pick == 0:
		_prefab_landmark(raid, p, rot, "bldg_grain_silo_elevator_remake", Vector3(18.0, 15.6, 12.6), Vector3(14.8, 14.0, 9.8), Vector3(18.4, 1.0, 13.0))
		return
	if pick == 1:
		_prefab_landmark(raid, p, rot, "bldg_grain_silo", Vector3(14.2, 11.5, 9.6), Vector3(11.6, 10.2, 7.6), Vector3(14.6, 1.0, 10.0))
		return
	var sz := Vector3(16.8, 12.6, 11.2)
	PrefabLib.place_at_ground(raid, raid.world, "poi_silo_radar", p + Vector3(0.0, -0.05, 0.0), rot, sz, false, null, false)
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
	var WOOD := A.wood_mat(Color(0.38, 0.30, 0.22))
	var OLD_WOOD := A.wood_mat(Color(0.29, 0.24, 0.18))
	var planks := [4.93, 4.88, 4.96]
	for k in 44:
		A.add(n, A.bevel_box(Vector3(planks[k % 3], 0.14, 0.477), 0.022), WOOD if k % 7 < 4 else OLD_WOOD,
			Vector3(float(k % 3 - 1) * 0.024, 0.17, -10.75 + k * 0.5), Vector3(0, 0, float(k % 5 - 2) * 0.24), Vector3.ONE, false)
	for sx in [-2.3, 2.3]:
		for k in 4:
			A.add(n, A.bevel_box(Vector3(0.28, 0.21, 5.49), 0.03), OLD_WOOD, Vector3(sx * 0.83, 0.025, -8.25 + k * 5.5))
		K.railing(raid, p + Vector3(sx, 0, 0).rotated(Vector3.UP, deg_to_rad(rot)), 22.0, rot + 90.0, 1.0)
		for k in 4:
			A.add(n, A.cyl(0.18, 2.6, 0.18, 16), OLD_WOOD, Vector3(sx, -1.0, -8.0 + k * 5.4))
	# 观景亭：四柱 + 破顶（基座落地，立柱与坡顶紧密衔接）
	var pav := Vector3(0, 0, -9.0)
	A.add(n, A.bevel_box(Vector3(5.4, 0.26, 5.4), 0.05), A.concrete(Color(0.4, 0.38, 0.34), false), pav + Vector3(0, 0.13, 0))
	for sx in [-2.0, 2.0]:
		for sz in [-2.0, 2.0]:
			A.add(n, A.cyl(0.14, 2.8, 0.14, 16), WOOD, pav + Vector3(sx, 1.62, sz))
			K.blocker(raid, p + (pav + Vector3(sx, 0, sz)).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(0.3, 3.0, 0.3), 0.0, true)
	var roof := A.roof_mat(Color(0.36, 0.29, 0.24), 0.78, true)
	for sx in [-1, 1]:
		for k in 5:
			var z := -2.08 + k * 1.04
			A.add(n, A.bevel_box(Vector3(3.46, 0.19, 0.15), 0.025), WOOD,
				pav + Vector3(sx * 1.47, 3.82, z), Vector3(0, 0, -sx * 28.0))
			if sx < 0 or k < 2:
				A.add(n, A.bevel_box(Vector3(3.44, 0.14, 1.025), 0.025), roof,
					pav + Vector3(sx * 1.46, 3.97, z + 0.05), Vector3(0, 0, -sx * 28.0))
	A.add(n, A.bevel_box(Vector3(0.19, 0.20, 5.05), 0.04), OLD_WOOD, pav + Vector3(0, 4.72, 0))
	K.bench(raid, p + pav.rotated(Vector3.UP, deg_to_rad(rot)) + Vector3(0, 0.2, 1.6).rotated(Vector3.UP, deg_to_rad(rot)), rot)
	K.lamp(raid, p + Vector3(0, 0, -7.0).rotated(Vector3.UP, deg_to_rad(rot)), Color(1.0, 0.75, 0.45))


## 环湖装甲瞭望哨塔：炮击战损装甲哨塔 + 折斜雷达 + 钢梯与防爆基座（lm_observation_tower 精修巨构）
static func _observation_tower(raid, p: Vector3, rot: float) -> void:
	var sz := Vector3(8.2, 15.4, 8.2)
	PrefabLib.place_at_ground(raid, raid.world, "lm_observation_tower", p + Vector3(0.0, -0.04, 0.0), rot, sz, false, null, false)
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


## 矿场筒仓：三只高精度高筒仓 + 锥顶集尘塔 + 仓顶贯通皮带廊 + 钢桁架斜皮带廊 + 混凝土基座装车破碎站
static func _ore_silos(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var M_CAP := A.paint(Color(0.42, 0.4, 0.36), 0.4, 0.6, {"rust": 0.6, "grime": 0.65})
	var M_ST := A.metal(STEEL)
	var M_DARK := A.metal(Color(0.16, 0.17, 0.18))
	var M_CONC := A.concrete(Color(0.36, 0.34, 0.31), false)
	var M_ROOF := A.tar_roof(Color(0.21, 0.215, 0.225), 0.32)
	var M_SLOPE_ROOF := A.roof_mat(Color(0.26, 0.27, 0.28), 0.56, true)
	var M_HAZ := A.hazard()
	var M_CLAD_TOP := A.corrugated(Color(0.40, 0.38, 0.34), 0.58, 0.28)
	var M_CLAD_CONV := A.corrugated(Color(0.33, 0.31, 0.28), 0.72, 0.28)
	var M_CLAD_SHED := A.corrugated(Color(0.38, 0.34, 0.28), 0.65, 0.28)
	for i in 3:
		var q := Vector3(-7.0 + i * 7.0, 0, 0)
		K.tower(raid, p + q.rotated(Vector3.UP, deg_to_rad(rot)), 2.8, 14.0, 2.8, Color(0.46, 0.44, 0.4))
		A.add(n, A.cyl(0.95, 2.2, 2.95, 40), M_CAP, q + Vector3(0, 15.1, 0))
		A.add(n, A.cyl(0.75, 1.4, 0.82, 28), M_ST, q + Vector3(0, 16.8, 0))
		A.add(n, A.torus(0.76, 0.9, 28), M_ST, q + Vector3(0, 17.4, 0), Vector3.ZERO, Vector3(1, 0.5, 1), false)
	# 贯通三座筒仓顶部的封闭配矿廊桥（暗色压顶盖板 + 钢桁肋，彻底消除顶面拉伸条纹）
	A.add(n, A.bevel_box(Vector3(16.2, 1.24, 1.76), 0.04), M_CLAD_TOP, Vector3(0, 16.56, 0))
	A.add(n, A.bevel_box(Vector3(16.56, 0.18, 2.08), 0.03), M_ROOF, Vector3(0, 17.26, 0))
	A.add(n, A.bevel_box(Vector3(16.52, 0.16, 1.92), 0.02), M_DARK, Vector3(0, 15.92, 0))
	for gx: float in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		A.add(n, A.bevel_box(Vector3(0.22, 1.42, 1.98), 0.02), M_ST, Vector3(gx, 16.6, 0), Vector3.ZERO, Vector3.ONE, false)
	# 顺坡下接装车站的 42° 钢桁架斜皮带廊（独立屋面盖板 + 钢箱底梁 + 7 道环抱钢肋 + 侧向检修走道护栏）
	var conv := Node3D.new()
	n.add_child(conv)
	conv.position = Vector3(0.0, 9.0, 7.6)
	conv.rotation_degrees = Vector3(42.0, 0.0, 0.0)
	A.add(conv, A.bevel_box(Vector3(2.56, 0.92, 19.6), 0.04), M_CLAD_CONV, Vector3.ZERO)
	A.add(conv, A.bevel_box(Vector3(2.92, 0.14, 19.8), 0.03), M_SLOPE_ROOF, Vector3(0.0, 0.50, 0.0))
	A.add(conv, A.bevel_box(Vector3(2.74, 0.22, 19.7), 0.02), M_DARK, Vector3(0.0, -0.52, 0.0))
	for rx_s: float in [-1.32, 1.32]:
		A.add(conv, A.bevel_box(Vector3(0.14, 0.16, 19.8), 0.01), M_ST, Vector3(rx_s, 0.42, 0.0), Vector3.ZERO, Vector3.ONE, false)
	for ri in 7:
		var rz := -8.4 + float(ri) * 2.8
		A.add(conv, A.bevel_box(Vector3(2.86, 1.12, 0.18), 0.02), M_ST, Vector3(0.0, 0.0, rz), Vector3.ZERO, Vector3.ONE, false)
	# 侧向检修走道与护栏
	A.add(conv, A.bevel_box(Vector3(0.64, 0.10, 18.8), 0.01), M_DARK, Vector3(1.62, -0.44, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(conv, A.bevel_box(Vector3(0.06, 0.08, 18.8), 0.01), M_ST, Vector3(1.92, 0.34, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(conv, A.bevel_box(Vector3(0.06, 0.06, 18.8), 0.01), M_ST, Vector3(1.92, -0.04, 0.0), Vector3.ZERO, Vector3.ONE, false)
	for pi in 8:
		var pz_r := -8.4 + float(pi) * 2.4
		A.add(conv, A.bevel_box(Vector3(0.06, 0.84, 0.06), 0.01), M_ST, Vector3(1.92, -0.04, pz_r), Vector3.ZERO, Vector3.ONE, false)
	# 双跨钢架支腿（混凝土杯口基础墩 + H型钢柱 + 横系梁与交叉斜撑）
	for tz: Array in [[6.4, 9.8], [11.2, 5.4]]:
		var lz: float = float(tz[0])
		var lh: float = float(tz[1])
		for sx: float in [-1.2, 1.2]:
			A.add(n, A.bevel_box(Vector3(0.76, 0.44, 0.76), 0.03), M_CONC, Vector3(sx, 0.22, lz))
			A.add(n, A.bevel_box(Vector3(0.30, lh, 0.30), 0.02), M_ST, Vector3(sx, lh * 0.5, lz))
		A.add(n, A.bevel_box(Vector3(2.8, 0.28, 0.30), 0.02), M_ST, Vector3(0.0, lh - 0.16, lz))
		A.add(n, A.bevel_box(Vector3(2.4, 0.18, 0.18), 0.01), M_DARK, Vector3(0.0, lh * 0.52, lz), Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(2.6, 0.12, 0.12), 0.01), M_DARK, Vector3(0.0, lh * 0.74, lz), Vector3(0.0, 0.0, 28.0), Vector3.ONE, false)
		A.add(n, A.bevel_box(Vector3(2.6, 0.12, 0.12), 0.01), M_DARK, Vector3(0.0, lh * 0.74, lz), Vector3(0.0, 0.0, -28.0), Vector3.ONE, false)
	# 底部装车破碎转运站：混凝土基座 + 压型钢板墙身 + 四角钢柱 + 沥青卷材平屋顶压檐 + 屋顶除尘风箱 + 内凹装车料斗门洞
	var shed_c := Vector3(0.0, 0.0, 14.6)
	A.add(n, A.bevel_box(Vector3(5.05, 0.34, 4.65), 0.04), M_CONC, shed_c + Vector3(0.0, 0.17, 0.0))
	A.add(n, A.bevel_box(Vector3(4.48, 2.86, 4.08), 0.05), M_CLAD_SHED, shed_c + Vector3(0.0, 1.72, 0.0))
	for cx_s: float in [-2.24, 2.24]:
		for cz_s: float in [-2.04, 2.04]:
			A.add(n, A.bevel_box(Vector3(0.28, 3.04, 0.28), 0.02), M_ST, shed_c + Vector3(cx_s, 1.78, cz_s))
	A.add(n, A.bevel_box(Vector3(4.66, 0.16, 4.26), 0.02), M_DARK, shed_c + Vector3(0.0, 1.72, 0.0), Vector3.ZERO, Vector3.ONE, false)
	# 暗色沥青卷材屋面 + 钢包边女儿墙檐口 + 除尘风机与排风烟囱（彻底消灭俯视角屋顶条纹拉伸）
	A.add(n, A.bevel_box(Vector3(4.92, 0.24, 4.52), 0.04), M_ROOF, shed_c + Vector3(0.0, 3.24, 0.0))
	A.add(n, A.bevel_box(Vector3(5.02, 0.10, 4.62), 0.02), M_DARK, shed_c + Vector3(0.0, 3.36, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(1.55, 0.72, 1.35), 0.03), M_ST, shed_c + Vector3(-0.95, 3.74, 0.45))
	A.add(n, A.cyl(0.28, 1.25, 0.32, 14), M_DARK, shed_c + Vector3(-1.15, 4.48, 0.45))
	A.add(n, A.bevel_box(Vector3(1.05, 0.20, 0.95), 0.02), M_DARK, shed_c + Vector3(1.15, 3.48, 0.65), Vector3.ZERO, Vector3.ONE, false)
	# 正面内凹装车料斗口 + 警示防撞过梁 + 两侧工业散热百叶格栅
	A.add(n, A.bevel_box(Vector3(2.45, 2.18, 0.22), 0.02), M_DARK, shed_c + Vector3(0.0, 1.38, 2.04), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(2.86, 0.28, 0.26), 0.02), M_HAZ, shed_c + Vector3(0.0, 2.54, 2.10), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(2.10, 0.56, 0.58), 0.03), M_ST, shed_c + Vector3(0.0, 2.02, 2.18), Vector3(24.0, 0.0, 0.0), Vector3.ONE, false)
	for sx_v: float in [-1.0, 1.0]:
		A.add(n, A.bevel_box(Vector3(0.14, 0.92, 1.68), 0.02), M_DARK, shed_c + Vector3(sx_v * 2.26, 2.12, 0.2), Vector3.ZERO, Vector3.ONE, false)
		for lv in 4:
			A.add(n, A.bevel_box(Vector3(0.18, 0.08, 1.54), 0.01), M_ST, shed_c + Vector3(sx_v * 2.29, 1.80 + float(lv) * 0.22, 0.2), Vector3(0.0, 0.0, sx_v * 18.0), Vector3.ONE, false)
	raid.blocks.append(raid._rect_for(p + Vector3(0, 0, 14.6).rotated(Vector3.UP, deg_to_rad(rot)), Vector3(5.0, 1, 4.6)))
	raid.blocks.append(raid._rect_for(p, Vector3(20.0, 1, 6.0)))


## 悬崖索桥：两座石砌锚塔之间垂着一条木板吊桥，中间缺了几块板
static func _rope_bridge(raid, p: Vector3, rot: float) -> void:
	var dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(rot))
	var a := p - dir * 16.0
	var b := p + dir * 16.0
	var wood := A.wood_mat(Color(0.40, 0.33, 0.24))
	var old_wood := A.wood_mat(Color(0.30, 0.24, 0.18))
	var steel := A.metal(Color(0.30, 0.28, 0.26))
	var pier := A.concrete(Color(0.42, 0.40, 0.36), true)
	var pier_base := A.concrete(Color(0.36, 0.34, 0.31), false)
	for q in [a, b]:
		A.add(raid.world, A.bevel_box(Vector3(3.6, 1.15, 3.6), 0.12, 0.92), pier_base, q + Vector3(0, 0.575, 0), Vector3(0, rot, 0))
		A.add(raid.world, A.bevel_box(Vector3(3.28, 4.76, 3.24), 0.17, 0.89), pier, q + Vector3(0, 3.42, 0), Vector3(0, rot, 0))
		A.add(raid.world, A.bevel_box(Vector3(3.82, 0.28, 3.72), 0.055), steel, q + Vector3(0, 5.85, 0), Vector3(0, rot, 0))
		K.blocker(raid, q, Vector3(3.6, 6.0, 3.6), rot)
		raid.blocks.append(raid._rect_for(q, Vector3(3.8, 1, 3.8)))
	var side := dir.cross(Vector3.UP)
	for off: float in [-0.96, 0.96]:
		for q in [a, b]:
			A.add(raid.world, A.bevel_box(Vector3(0.21, 0.94, 0.21), 0.04), steel,
				q + side * off + Vector3(0, 6.37, 0), Vector3(0, rot, 0))
		K.cable(raid, a + side * off + Vector3(0, 6.82, 0), b + side * off + Vector3(0, 6.82, 0), 2.1, 0.050)
		K.cable(raid, a + side * off + Vector3(0, 5.50, 0), b + side * off + Vector3(0, 5.50, 0), 2.4, 0.042)
		for k in range(1, 12):
			var t := float(k) / 12.0
			var q := a.lerp(b, t) + side * off
			var deck_y := q.y + 5.4 - sin(t * PI) * 2.4
			A.add(raid.world, A.cyl(0.030, 1.66, 0.030, 12), steel, Vector3(q.x, deck_y + 0.79, q.z), Vector3.ZERO, Vector3.ONE, false)
	for k in range(2, 59):
		if k in [11, 29, 30, 47]:
			continue
		var t := float(k) / 60.0
		var q := a.lerp(b, t)
		q.y = 5.4 - sin(t * PI) * 2.4
		var pitch := -rad_to_deg(atan(2.4 * PI / 32.0 * cos(t * PI)))
		A.add(raid.world, A.bevel_box(Vector3(2.02, 0.13, 0.50), 0.027), wood if k % 5 < 3 else old_wood,
			q, Vector3(pitch, rot, float(k % 5 - 2) * 1.8), Vector3.ONE, false)


## 深渊高压结晶矿脉露头与地质激光测绘阵（lm_crystal_survey_rig 精修巨构）
static func _crystal_cluster(raid, p: Vector3, rot: float) -> void:
	var rad_r := deg_to_rad(rot)
	A.ground_decal(raid.world, A.cloud_tex(), Color(0.08, 0.06, 0.11, 0.65), 14.5, p + Vector3(0, 0.03, 0))
	A.ground_decal(raid.world, A.cloud_tex(), Color(0.08, 0.56, 0.66, 0.26), 9.2, p + Vector3(-0.6, 0.04, -0.3).rotated(Vector3.UP, rad_r))
	var sz := Vector3(9.6, 6.2, 8.7)
	PrefabLib.place_at_ground(raid, raid.world, "lm_crystal_survey_rig", p + Vector3(0.0, -0.04, 0.0), rot, sz, false, null, false)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.24, 0.90, 0.98)
	glow.light_energy = 2.6
	glow.omni_range = 17.5
	glow.omni_attenuation = 1.5
	glow.position = p + Vector3(-0.78, 2.75, -0.45).rotated(Vector3.UP, rad_r)
	raid.world.add_child(glow)
	K.blocker(raid, p, Vector3(4.2, 5.5, 4.2), 0.0, true)
	raid.blocks.append(raid._rect_for(p, Vector3(9.6, 1.0, 8.8)))


## 深渊封印井环门与地热钻井塔台（Wave5 重制 poi_abyss_gate_rig -> bldg_abyss_gate_rig_remake）
static func _drill_derrick(raid, p: Vector3, rot: float) -> void:
	var sz := Vector3(16.0, 13.4, 16.0)
	PrefabLib.place_at_ground(raid, raid.world, "poi_abyss_gate_rig", p + Vector3(0.0, -0.05, 0.0), rot, sz, false, null, false)
	var rad_r := deg_to_rad(rot)
	K.blocker(raid, p, Vector3(7.6, 13.0, 7.6), 0.0, true)
	var mb := p + Vector3(-4.65, 0.0, -4.65).rotated(Vector3.UP, rad_r)
	K.blocker(raid, mb, Vector3(3.4, 3.2, 2.8), rot)
	raid.blocks.append(raid._rect_for(p, Vector3(14.6, 1.0, 14.6)))


## 干涸冷却渠：分段导流槽、锈蚀供回管与中段检修道口。
static func _coolant_channel(raid, p: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.name = "CoolingCanal"
	raid.world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	var wall := A.concrete(Color(0.43, 0.40, 0.36), true)
	var ribs := A.concrete(Color(0.30, 0.28, 0.26), false)
	var pipe := A.paint(Color(0.32, 0.24, 0.20), 0.53, 0.62, {"rust": 0.72, "wear": 0.48})
	var steel := A.metal(Color(0.24, 0.26, 0.27))
	var bed := A.rock_mat(Color(0.31, 0.26, 0.23))
	var silt := A.gravel_mat(Color(0.20, 0.25, 0.22))
	for sx in [-3.4, 3.4]:
		var inner: float = sx - signf(sx) * 0.43
		for seg in [[-15.0, 30.0], [24.0, 12.0]]:
			var cz: float = seg[0]
			var lz: float = seg[1]
			var wp := p + Vector3(sx, 0, cz).rotated(Vector3.UP, deg_to_rad(rot))
			K.blocker(raid, wp, Vector3(0.8, 2.4, lz), rot)
			raid.blocks.append(raid._rect_for(wp, Vector3(0.9, 1, lz)))
			var cells := int(lz / 6.0)
			for i in cells:
				var z := cz - lz * 0.5 + 3.0 + i * 6.0
				A.add(n, A.bevel_box(Vector3(0.74, 2.28, 5.95), 0.11, 0.89), wall, Vector3(sx, 1.14, z))
				A.add(n, A.bevel_box(Vector3(0.81, 0.18, 5.93), 0.045), ribs, Vector3(sx, 2.30, z))
				A.add(n, A.bevel_box(Vector3(0.72, 2.26, 0.57), 0.07, 0.83), ribs, Vector3(sx, 1.13, z - 2.65))
				A.add(n, A.cyl(0.18, 5.92, 0.18, 24), pipe, Vector3(inner, 1.79, z), Vector3(90, 0, 0), Vector3.ONE, false)
				A.add(n, A.cyl(0.26, 0.21, 0.26, 24), steel, Vector3(inner, 1.79, z - 2.87), Vector3(90, 0, 0), Vector3.ONE, false)
				A.add(n, A.bevel_box(Vector3(0.48, 0.16, 0.34), 0.035), steel, Vector3(sx, 1.54, z), Vector3.ZERO, Vector3.ONE, false)
	# 裂开的混凝土衬砌包住深色沉积槽。中心道口保持低矮，可沿原路线横穿。
	for i in 12:
		var z := -27.5 + i * 5.0
		A.add(n, A.bevel_box(Vector3(2.55, 0.07, 4.99), 0.025), silt, Vector3(0, 0.045, z), Vector3.ZERO, Vector3.ONE, false)
		for sx in [-2.17, 2.17]:
			A.add(n, A.bevel_box(Vector3(1.7, 0.18, 4.91), 0.06, 0.94), wall if i % 3 == 0 else bed, Vector3(sx, 0.105, z), Vector3.ZERO, Vector3.ONE, false)
		if i in [1, 4, 9, 11]:
			for k in 8:
				A.add(n, A.bevel_box(Vector3(2.48, 0.08, 0.09), 0.025), steel, Vector3(0, 0.105, z - 0.68 + k * 0.19), Vector3.ZERO, Vector3.ONE, false)
	for i in 5:
		A.add(n, A.bevel_box(Vector3(7.34, 0.15, 0.57), 0.045), steel, Vector3(0, 0.22, 7.8 + i * 0.61))
	for z in [7.45, 10.59]:
		A.add(n, A.bevel_box(Vector3(7.42, 0.12, 0.18), 0.025), A.hazard(), Vector3(0, 0.25, z), Vector3.ZERO, Vector3.ONE, false)
	# 保留原有随机采样顺序，散放掀起的盖板与泥沙碎块。
	for i in 6:
		var zc := -26.0 + i * 10.0
		var rx: float = raid.rng.randf_range(-1.2, 1.2)
		var rot_v := Vector3(raid.rng.randf_range(-16, 16), raid.rng.randf_range(-6, 6), raid.rng.randf_range(-18, 18))
		if zc < -2.0 or zc > 20.0:
			A.add(n, A.rock_mesh(i + 2), bed, Vector3(rx * 1.8, 0.16, zc), rot_v, Vector3(0.88, 0.33, 0.53))
	for i in 5:
		var zb := -24.0 + i * 12.0
		var rot_b := Vector3(0, raid.rng.randf_range(-8, 8), raid.rng.randf_range(-30, 30))
		if zb < -2.0 or zb > 20.0:
			A.add(n, A.bevel_box(Vector3(0.96, 0.10, 1.54), 0.035), pipe, Vector3(1.26, 0.26, zb), rot_b)


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
