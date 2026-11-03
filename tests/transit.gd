extends "res://tests/lib/test_base.gd"
## 战区互通：从灰港市东侧转场口穿到铁锈工业带，校验货舱货物、出击携带物、结构、弹药、局内时间、击杀数与随行队友都被带了过去，
## （击杀数只校验不减少：转场后队友可能立刻打死附近的虫）机甲出现在新战区的西侧边缘，新战区有通回灰港的转场口，撤离点照常生成。godot --headless --path . -- --transit

const TIMEOUT := 200.0
const WorldLink = preload("res://scripts/world_link.gd")
const Factions = preload("res://scripts/factions/factions.gd")


func run() -> void:
	WorldLink.force_open = true
	Factions.rovers_enabled = false
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}]
	GameData.map_id = "greyport"
	GameData.cargo = ["fuel_cell"]
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	if not check(raid.map_id == "greyport", "出击战区不是灰港市：%s" % raid.map_id):
		return
	var link = raid.world_link
	if not check(link != null and link.gates.has("E") and link.gates.has("N") and link.gates.has("S"), "灰港市的转场口不全：%s" % [link.gates.keys() if link else []]):
		return
	if not check(await until(func(): return raid.factions.allies.size() == 1, 5.0), "注入的战斗队友没有生成"):
		return
	var ally = raid.factions.allies[0]
	ally.hp = ally.max_hp * 0.6
	var m = raid.mech
	m.cargo.append_array(["circuit", "bolts", "hdd"])
	m.hp = m.max_hp * 0.77
	m.ammo["arm_l"] = 3
	m.parts["arm_r"] = 0.5
	raid.kills = 7
	var cargo0: Array = m.cargo.duplicate()
	var start0: Array = raid.start_cargo.duplicate()
	var hp0: float = m.hp
	var t0: float = raid.time
	var ally_hp0: float = ally.hp
	log_line("greyport gates=%s cargo=%s hp=%.1f time=%.1f" % [link.gates.keys(), cargo0, hp0, t0])
	# 走进东侧转场口
	var g: Dictionary = link.gates["E"]
	var p: Vector3 = link._edge_point("E", float(g.along), 4.0)
	m.shield_time = 999.0   # 转场口附近可能有虫：护盾挡掉伤害，好校验结构原样带过去
	m.global_position = Vector3(p.x, 0.3, p.z)
	m.velocity = Vector3.ZERO
	if not check(link.gate_at(m.global_position) == "E", "放进转场口后没有被识别"):
		return
	var rid: int = raid.get_instance_id()
	# 等转场时队友可能在转场口附近和虫交火掉血：以转场前最后一帧的结构为准
	var last_hp := [ally_hp0]
	var aw: WeakRef = weakref(ally)
	var ok: bool = await until(func():
		var a = aw.get_ref()
		if a != null and not a.is_queued_for_deletion():
			last_hp[0] = a.hp
		return is_instance_valid(main.raid) and main.raid.get_instance_id() != rid and main.raid.map_id == "ironbelt" and main.raid.mech != null, 20.0)
	ally_hp0 = last_hp[0]
	if not check(ok, "停在转场口里没有转到铁锈工业带"):
		return
	var nr = main.raid
	await frames(5)
	var nm = nr.mech
	log_line("ironbelt cargo=%s hp=%.1f ammo=%s time=%.1f pos=%s allies=%d" % [nm.cargo, nm.hp, nm.ammo, nr.time, nm.global_position, nr.factions.allies.size()])
	if not check(nm.cargo == cargo0, "货舱货物没有保留：%s → %s" % [cargo0, nm.cargo]):
		return
	if not check(nr.start_cargo == start0, "出击携带物（结算用）没有保留"):
		return
	if not check(absf(nm.hp - hp0) < 0.5, "机甲结构没有保留：%.1f → %.1f" % [hp0, nm.hp]):
		return
	if not check(int(nm.ammo.arm_l) == 3 and absf(float(nm.parts.arm_r) - 0.5) < 0.01, "弹药或部件完好度没有保留：%s %s" % [nm.ammo, nm.parts]):
		return
	if not check(nr.time >= t0 and nr.kills >= 7, "局内时间或击杀数没有保留：%.1f / %d" % [nr.time, nr.kills]):
		return
	if not check(nm.global_position.x < -nr.HALF + 30.0, "没有从新战区的西侧进入：%s" % nm.global_position):
		return
	if not check(not nr.dropping and not nm.input_locked, "转场后机甲没有恢复操作"):
		return
	if not check(nr.world_link.gates.has("W") and nr.world_link.gates.W.to == "greyport", "铁锈工业带没有通回灰港市的转场口"):
		return
	if not check(nr.extracts.size() == 2, "新战区没有生成撤离点"):
		return
	if not check(nr.visited_maps == ["greyport", "ironbelt"], "到访战区记录不对：%s" % [nr.visited_maps]):
		return
	if not check(await until(func(): return nr.factions.allies.size() == 1, 3.0), "随行队友没有跟着转场"):
		return
	var na = nr.factions.allies[0]
	if not check(na.pilot == "rei" and na.tier == 2 and absf(na.hp - ally_hp0) < 2.0, "队友状态没有保留：%s T%d hp=%.1f" % [na.pilot, na.tier, na.hp]):
		return
	if not check(not is_instance_id_valid(rid) or (instance_from_id(rid) as Node).is_queued_for_deletion(), "旧战区没有释放"):
		return
	# 撤离仍要去撤离点：站在新战区的撤离点里读条才能结束
	var res := {}
	nr.raid_ended.connect(func(r): res.merge(r))
	var ez = nr.extracts[0]
	nm.global_position = ez.global_position + Vector3(0, 0.3, 0)
	nm.shield_time = 999.0
	Engine.time_scale = 4.0
	ok = await until(func(): return not res.is_empty(), 30.0)
	Engine.time_scale = 1.0
	if not check(ok and bool(res.get("success", false)), "在新战区的撤离点撤离失败"):
		return
	if not check(res.cargo == cargo0 and res.map_id == "ironbelt", "撤离结算里的货物 / 战区不对：%s %s" % [res.cargo, res.map_id]):
		return
	log_line("extracted from %s with %s" % [res.map_id, res.cargo])
	Factions.test_ally_squad = null
	Factions.rovers_enabled = true
	WorldLink.force_open = false
