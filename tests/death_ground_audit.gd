extends "res://tests/lib/test_base.gd"
## 死亡动画与零浮空几何回归审计：
##   1. 覆盖全部 4 类机甲底盘（双足 / 四足 / 六足 / 履带）、跳跃半空机甲与流浪者 NPC 机甲，
##      审计坍塌底盘及全部 5 个解体抛射模块（core / arm_l / arm_r / back / gen）的真实世界最低点贴地误差；
##   2. 覆盖常规地面虫族、潜地虫、飞行悬停啸翅虫（wasp）及三类首领（程序化王虫、骨骼泰坦、六足要塞与浮空母舰），
##      在平地、高台与 15° 斜坡碰撞体上验证残骸 100% 落回真实地面（零半空悬浮、零深埋地底）。
## 运行：godot --headless --path . -- --death_ground_audit

const START := "none"
const TIMEOUT := 120.0

const DA = preload("res://scripts/death_anim.gd")
const Mech = preload("res://scripts/mech.gd")
const NpcMech = preload("res://scripts/factions/npc_mech.gd")
const Bug = preload("res://scripts/bug.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")


class AuditRaid extends Node3D:
	var fx: Node3D
	var world: Node3D
	var mech = null
	var coop = null
	var hud = null
	var rng := RandomNumberGenerator.new()
	var shake := 0.0
	var kills := 0
	var _corpses: Array = []

	func _init() -> void:
		rng.seed = 20261124
		fx = Node3D.new()
		fx.name = "FX"
		add_child(fx)
		world = Node3D.new()
		world.name = "World"
		add_child(world)

	func spark(_p: Vector3, _c: Color, _n := 8) -> void:
		pass

	func explode_fx(_p: Vector3, _r := 4.0, _c := Color(1.0, 0.55, 0.2)) -> void:
		pass

	func on_bug_killed(_b) -> void:
		kills += 1

	func _register_corpse(_b) -> void:
		pass

	func dry_spot(p: Vector3, _r := 1.0) -> Vector3:
		return p

	func _blocked(_p: Vector3, _r := 1.0, _water := false) -> bool:
		return false

	func _place_box(_kind: String, _pos: Vector3, _items: Array = []):
		return null


func _make_slab(parent: Node3D, pos: Vector3, size: Vector3, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


func run() -> void:
	var raid := AuditRaid.new()
	add_child(raid)

	# 构建三类物理地形区：主平地（顶面 y = 0.0）、高台（顶面 y = 3.2）、14° 斜坡
	_make_slab(raid.world, Vector3(0.0, -1.0, 0.0), Vector3(420.0, 2.0, 420.0))
	_make_slab(raid.world, Vector3(-90.0, 1.6, 0.0), Vector3(70.0, 3.2, 120.0))
	_make_slab(raid.world, Vector3(90.0, 1.8, 0.0), Vector3(70.0, 2.0, 140.0), Vector3(0.0, 0.0, 14.0))

	await frames(3)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# ---------------- 1. 机甲四类底盘 + 半空坠落 + 流浪者 NPC 解体贴地审计 ----------------
	var mech_cases := [
		{"tag": "biped_flat", "pos": Vector3(-24.0, 0.0, -36.0), "air": 0.0, "npc": false,
			"lo": {"core": "core_assault", "legs": "legs_biped_assault", "arm_l": "arm_gatling", "arm_r": "arm_rh120", "back": "back_rocket", "gen": "gen_diesel"}},
		{"tag": "quad_mesa_air", "pos": Vector3(-90.0, 3.2, -32.0), "air": 3.4, "npc": false,
			"lo": {"core": "core_heavy", "legs": "legs_quad_crab", "arm_l": "arm_ac30", "arm_r": "arm_rail", "back": "back_missile", "gen": "gen_turbine"}},
		{"tag": "hex_slope", "pos": Vector3(88.0, 4.5, 0.0), "air": 0.0, "npc": false,
			"lo": {"core": "core_fortress", "legs": "legs_hex_beetle", "arm_l": "arm_cannon", "arm_r": "arm_bofors40", "back": "back_vls", "gen": "gen_reactor"}},
		{"tag": "tread_flat", "pos": Vector3(24.0, 0.0, -36.0), "air": 0.0, "npc": false,
			"lo": {"core": "core_m1a2_sepv3", "legs": "legs_tread_heavy", "arm_l": "arm_gau8", "arm_r": "arm_tow2b", "back": "back_shield", "gen": "gen_agt1500_turbine"}},
		{"tag": "rover_npc_air", "pos": Vector3(-90.0, 3.2, 28.0), "air": 2.6, "npc": true,
			"lo": {"core": "core_std", "legs": "legs_biped", "arm_l": "arm_hmg", "arm_r": "arm_shotgun", "back": "back_rack", "gen": "gen_cell"}},
	]

	var mechs: Array = []
	var mech_mod_refs: Array = []
	for mc in mech_cases:
		var m
		if bool(mc.npc):
			m = NpcMech.new()
			m.raid = raid
			raid.world.add_child(m)
			m.setup_npc(mc.lo, "rover", 2)
		else:
			m = Mech.new()
			m.raid = raid
			raid.world.add_child(m)
			m.setup(mc.lo, [])
		m.set_physics_process(false)
		var g_base := DA.sample_ground(m, mc.pos, 8.0, 32.0)
		m.global_position = Vector3(mc.pos.x, float(g_base.y) + float(mc.air), mc.pos.z)
		m._vis_sync()
		if float(mc.air) > 0.0:
			m.visual.position.y = 0.85
		var mods_dict: Dictionary = m.visual.get_meta("modules", {})
		var slot_map := {}
		for slot: String in ["core", "arm_l", "arm_r", "back", "gen"]:
			if mods_dict.has(slot) and is_instance_valid(mods_dict[slot]):
				slot_map[slot] = mods_dict[slot]
		mechs.append({"tag": mc.tag, "node": m})
		mech_mod_refs.append({"tag": mc.tag, "slots": slot_map})

	# ---------------- 2. 全系地面/潜地/飞行虫族与三类巨型首领坍塌贴地审计 ----------------
	var bug_cases := [
		{"kind": "ling", "pos": Vector3(-36.0, 0.0, 16.0)},
		{"kind": "spitter", "pos": Vector3(-24.0, 0.0, 16.0)},
		{"kind": "beetle", "pos": Vector3(-12.0, 0.0, 16.0)},
		{"kind": "mantis", "pos": Vector3(0.0, 0.0, 16.0)},
		{"kind": "crystal_bug", "pos": Vector3(12.0, 0.0, 16.0)},
		{"kind": "burrower", "pos": Vector3(24.0, 0.0, 16.0), "burrow": true},
		{"kind": "wasp", "pos": Vector3(-86.0, 3.2, -4.0), "fly_y": 2.6},
		{"kind": "mortar", "pos": Vector3(86.0, 4.5, -26.0)},
		{"kind": "aegis", "pos": Vector3(92.0, 4.5, 26.0)},
		{"kind": "overseer", "pos": Vector3(36.0, 0.0, 16.0), "fly_y": 1.8},
		{"kind": "colossus", "pos": Vector3(-30.0, 0.0, 36.0)},
		{"kind": "king_beetle", "pos": Vector3(0.0, 0.0, 42.0)},
		{"kind": "excavator_titan", "pos": Vector3(34.0, 0.0, 42.0)},
		{"kind": "citadel_behemoth", "pos": Vector3(-28.0, 0.0, 82.0)},
		{"kind": "sky_carrier", "pos": Vector3(32.0, 0.0, 82.0), "fly_y": 5.8},
	]

	var bugs: Array = []
	for bc in bug_cases:
		var k := str(bc.kind)
		var ed: Dictionary = GameData.ENEMIES.get(k, Bug.KINDS.get(k, {}))
		var scr_path := str(ed.get("script", ""))
		var b = load(scr_path).new() if scr_path != "" else Bug.new()
		b.setup(k, raid, null)
		raid.world.add_child(b)
		b.set_physics_process(false)
		var g_b := DA.sample_ground(b, bc.pos, 8.0, 32.0)
		b.global_position = Vector3(bc.pos.x, float(g_b.y), bc.pos.z)
		b._vis_sync()
		if bc.get("fly_y", 0.0) > 0.0:
			b.visual.position.y = float(bc.fly_y)
		if bc.get("burrow", false):
			b.set("underground", true)
			b.visual.visible = false
		bugs.append({"kind": k, "node": b})

	await frames(2)

	# 触发全部机甲与虫族/首领死亡动画
	for mc in mechs:
		var m = mc.node
		if m.has_method("die"):
			m.die("audit")
	for bc in bugs:
		bc.node._die()

	# 等待全部解体抛物线、弹跳滑行与骨骼死亡剪辑彻底静止（excavator_titan dead ~2.4s）
	await wait_real(2.85)
	await frames(2)

	var failures: Array[String] = []
	var checked_count := 0

	for i in mechs.size():
		var tag: String = mechs[i].tag
		var m = mechs[i].node
		var gm := DA.sample_ground(raid, m.global_position, 6.0, 40.0)
		var gy_m: float = float(gm.y)
		var gap_m: float = DA.lowest_slope_clearance(m.visual, Vector3(m.global_position.x, gy_m, m.global_position.z), gm.normal)
		checked_count += 1
		log_line("mech_chassis %-16s gy=%6.3f slope_clr=%+6.3f" % [tag, gy_m, gap_m])
		if absf(gap_m) > 0.095:
			failures.append("机甲底盘 %s 贴地超差 gap=%.3fm" % [tag, gap_m])

		var slots: Dictionary = mech_mod_refs[i].slots
		for slot: String in slots.keys():
			var mod_n: Node3D = slots[slot]
			if not is_instance_valid(mod_n):
				failures.append("机甲模块 %s/%s 丢失" % [tag, slot])
				continue
			var gs := DA.sample_ground(raid, mod_n.global_position, 6.0, 40.0)
			var gy_s: float = float(gs.y)
			var gap_s: float = DA.lowest_slope_clearance(mod_n, Vector3(mod_n.global_position.x, gy_s, mod_n.global_position.z), gs.normal)
			checked_count += 1
			log_line("  mod %-16s %-6s gy=%6.3f slope_clr=%+6.3f" % [tag, slot, gy_s, gap_s])
			if absf(gap_s) > 0.095:
				failures.append("散落模块 %s/%s 浮空或深埋 gap=%.3fm" % [tag, slot, gap_s])

	for bc in bugs:
		var k: String = bc.kind
		var b = bc.node
		if not is_instance_valid(b) or not is_instance_valid(b.visual):
			failures.append("虫族/首领 %s 残骸节点异常销毁" % k)
			continue
		if not b.visual.visible:
			failures.append("虫族/首领 %s 残骸不可见" % k)
		var gb := DA.sample_ground(raid, b.global_position, 8.0, 48.0)
		var gy_b: float = float(gb.y)
		var gap_b: float = DA.lowest_slope_clearance(b.visual, Vector3(b.global_position.x, gy_b, b.global_position.z), gb.normal)
		checked_count += 1
		log_line("enemy_corpse %-18s gy=%6.3f slope_clr=%+6.3f" % [k, gy_b, gap_b])
		var tol := 0.11 if k in ["citadel_behemoth", "sky_carrier", "excavator_titan"] else 0.095
		if absf(gap_b) > tol:
			failures.append("虫族/首领 %s 浮空或深埋 gap=%.3fm (tol=%.3fm)" % [k, gap_b, tol])

	log_line("total audited bodies & modules = %d, failures = %d" % [checked_count, failures.size()])
	raid.queue_free()
	await frames(2)
	if not check(failures.is_empty(), "死亡零浮空审计未通过：" + "；".join(failures)):
		return
