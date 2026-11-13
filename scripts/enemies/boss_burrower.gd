extends "res://scripts/enemies/boss.gd"
## 荒原噬沙钻皇 / 深渊先驱魔像：重型掘进冲撞、地裂喷发与深渊震波型 Boss。
## 一阶段螺旋钻进冲撞与地裂岩刺；二阶段冲撞接震地冲击环、抛射碎岩/深渊陨星并呼唤虫群；
## 三阶段散热甲片/胸骨裂开暴露核心，连续发动多方向地裂与双层毁灭震波。

func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 34.0
	summon_cap = 8
	weak_core = float(data.get("weak_core", 2.8))
	charge_speed = float(data.get("charge_speed", 20.0))
	charge_time = float(data.get("charge_time", 0.65))


func roar_id() -> String:
	return "boss_queen_roar" if kind == "abyss_harbinger" else "boss_king_roar"


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.5)
		charge_speed = 23.0
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.22)
		charge_speed = 26.0
		open_core(11.0)
		if raid:
			Audio.play_sfx("boss_queen_core" if kind == "abyss_harbinger" else "boss_king_core", global_position + Vector3(0, 2.2, 0))
			var c0 := Color(0.85, 0.32, 1.0, 1.0) if kind == "abyss_harbinger" else Color(1.0, 0.72, 0.24, 1.0)
			ART.burst(raid.fx, global_position + Vector3(0, 2.2, 0), {"amount": 26, "life": 0.95, "size": 0.25, "spread": 120.0, "vmin": 4.0, "vmax": 10.5,
				"gravity": Vector3(0, -12, 0), "c0": c0, "c1": Color(0.45, 0.15, 0.75, 0.0), "grow0": 1.0, "grow1": 0.3})


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid:
		return Vector3.ZERO
	if act != "":
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if not _in_player_view(d):
		return fwd * 0.85
	if atk_cd > 0.0:
		if d > 7.5:
			return fwd * 0.78
		if d < 4.2:
			return -fwd * 0.4
		return fwd.cross(Vector3.UP) * strafe * 0.45
	atk_cd = float(data.rate) * (0.65 if phase >= 2 else 0.9)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 3:
			0: _start_act([["wind", 0.88], ["charge", 0.65], ["strike", 0.22], ["recover", 0.85]], fwd)
			1: _start_act([["wind", 0.85], ["spike", 0.32], ["recover", 0.78]], fwd)
			_: _start_act([["wind", 0.9], ["stomp", 0.35], ["recover", 0.82]], fwd)
	elif phase == 2:
		match pattern_i % 4:
			0: _start_act([["wind", 0.8], ["charge", 0.6], ["strike", 0.2], ["stomp", 0.32], ["recover", 0.85]], fwd)
			1: _start_act([["wind", 0.85], ["rain", 0.38], ["recover", 0.78]], fwd)
			2: _start_act([["wind", 0.8], ["spike", 0.3], ["recover", 0.4], ["spike", 0.3], ["recover", 0.75]], fwd)
			_: _start_act([["wind", 0.8], ["summon", 0.4], ["recover", 0.75]], fwd)
	else:
		match pattern_i % 4:
			0: _start_act([["wind", 0.72], ["charge", 0.55], ["strike", 0.18], ["recover", 0.32], ["charge", 0.55], ["strike", 0.18], ["stomp", 0.3], ["recover", 0.8]], fwd)
			1: _start_act([["wind", 0.75], ["rain", 0.36], ["spike", 0.3], ["recover", 0.7]], fwd)
			2: _start_act([["wind", 0.68], ["core", 0.48], ["recover", 0.65]], fwd)
			_: _start_act([["wind", 0.72], ["summon", 0.38], ["stomp", 0.3], ["recover", 0.75]], fwd)
	return Vector3.ZERO


func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	var is_abyss := kind == "abyss_harbinger"
	var col := Color(0.84, 0.32, 1.0) if is_abyss else Color(1.0, 0.68, 0.22)
	match name:
		"spike":
			Audio.play_sfx("bug_burrower_erupt", global_position)
			var base: Vector3 = global_position + Vector3(0, 0.2, 0)
			var row := Hazards.SpikeRow.new()
			raid.fx.add_child(row)
			row.setup(raid, base + act_dir * 2.4, act_dir, 7, 2.6, float(data.dmg) * 0.88, 0.12, col)
			for side: float in [-1.0, 1.0]:
				var dir2: Vector3 = (act_dir + act_dir.cross(Vector3.UP) * side * 0.65).normalized()
				var r2 := Hazards.SpikeRow.new()
				raid.fx.add_child(r2)
				r2.setup(raid, base + dir2 * 2.0, dir2, 5, 2.4, float(data.dmg) * 0.68, 0.14, col)
		"stomp":
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 0.5, 0))
			raid.shake = maxf(raid.shake, 0.58)
			_ground_ring(global_position, 4.4, col)
			var r1 := Hazards.ShockRing.new()
			raid.fx.add_child(r1)
			r1.setup(raid, global_position, 11.5 * sc * 0.33, 0.8, float(data.dmg) * 0.88, col)
			if phase >= 3:
				var r2 := Hazards.ShockRing.new()
				raid.fx.add_child(r2)
				r2.setup(raid, global_position, 16.5 * sc * 0.33, 1.12, float(data.dmg) * 0.68, col)
		"rain":
			Audio.play_sfx("boss_brood_hatch", global_position + Vector3(0, 2.0, 0))
			var m = target
			if m == null or not is_instance_valid(m):
				return
			var shots := 7 if phase >= 3 else 5
			for i in shots:
				var a := TAU * i / float(shots) + randf_range(-0.2, 0.2)
				var p: Vector3 = m.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.2, 7.8)
				var sh := Hazards.LobShell.new()
				raid.fx.add_child(sh)
				sh.setup(raid, global_position + Vector3(0, 2.2 * sc * 0.35, 0), p, 1.4 + i * 0.08, 3.5, float(data.dmg) * 0.72, col)
		"summon":
			summon("wasp" if is_abyss else "burrower", 3, 6.5)
		"core":
			open_core(9.5)
			Audio.play_sfx("boss_queen_core" if is_abyss else "boss_king_core", global_position + Vector3(0, 2.2, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.2, 0), {"amount": 22, "life": 0.85, "size": 0.24, "spread": 120.0, "vmin": 3.5, "vmax": 9.0,
				"gravity": Vector3(0, -10, 0), "c0": col, "c1": Color(1.0, 0.9, 0.6, 0.0), "grow0": 1.0, "grow1": 0.3})
