extends "res://scripts/enemies/boss.gd"
## 猎潮镰王 / 碎岩暴君：高机动多臂斩击与回旋锯压制型 Boss。
## 一阶段高速突进斩击与交叉刃波；二阶段二连冲刺斩、震地回旋斩并呼唤镰爪/链锯虫群；
## 三阶段胸腔护板裂开暴露过载核心，三向裂地刃波与狂暴连斩交替出手。

func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 32.0
	summon_cap = 6
	weak_core = float(data.get("weak_core", 2.6))
	charge_speed = float(data.get("charge_speed", 22.0))
	charge_time = float(data.get("charge_time", 0.55))


func roar_id() -> String:
	return "boss_king_roar"


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.45)
		charge_speed = 25.0
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.2)
		charge_speed = 28.0
		open_core(10.0)
		if raid:
			Audio.play_sfx("boss_king_core", global_position + Vector3(0, 2.0, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.0, 0), {"amount": 24, "life": 0.9, "size": 0.24, "spread": 120.0, "vmin": 4.0, "vmax": 10.0,
				"gravity": Vector3(0, -12, 0), "c0": Color(1.0, 0.45, 0.25, 1.0), "c1": Color(0.25, 0.85, 1.0, 0.0), "grow0": 1.0, "grow1": 0.3})


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid:
		return Vector3.ZERO
	if act != "":
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if not _in_player_view(d):
		return fwd * 0.85
	if atk_cd > 0.0:
		if d > 7.0:
			return fwd * 0.85
		if d < 3.8:
			return -fwd * 0.45
		return fwd.cross(Vector3.UP) * strafe * 0.6
	atk_cd = float(data.rate) * (0.62 if phase >= 2 else 0.88)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 3:
			0: _start_act([["wind", 0.78], ["charge", 0.55], ["strike", 0.22], ["recover", 0.8]], fwd)
			1: _start_act([["wind", 0.72], ["claw", 0.32], ["recover", 0.75]], fwd)
			_: _start_act([["wind", 0.85], ["spike", 0.3], ["recover", 0.75]], fwd)
	elif phase == 2:
		match pattern_i % 4:
			0: _start_act([["wind", 0.72], ["charge", 0.52], ["strike", 0.2], ["recover", 0.3], ["charge", 0.5], ["strike", 0.2], ["recover", 0.85]], fwd)
			1: _start_act([["wind", 0.75], ["claw", 0.28], ["spike", 0.28], ["recover", 0.75]], fwd)
			2: _start_act([["wind", 0.82], ["stomp", 0.32], ["recover", 0.75]], fwd)
			_: _start_act([["wind", 0.78], ["summon", 0.38], ["recover", 0.75]], fwd)
	else:
		match pattern_i % 4:
			0: _start_act([["wind", 0.65], ["charge", 0.48], ["strike", 0.18], ["recover", 0.28], ["claw", 0.28], ["recover", 0.7]], fwd)
			1: _start_act([["wind", 0.7], ["spike", 0.28], ["recover", 0.35], ["stomp", 0.3], ["recover", 0.65]], fwd)
			2: _start_act([["wind", 0.68], ["core", 0.45], ["recover", 0.65]], fwd)
			_: _start_act([["wind", 0.7], ["summon", 0.35], ["claw", 0.3], ["recover", 0.7]], fwd)
	return Vector3.ZERO


func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	var fwd := act_dir
	match name:
		"claw":
			_slash_fx(fwd)
			_hit_mech(float(data.dmg), 2.8, float(data.range) + 3.2)
			Audio.play_sfx("bug_mantis_attack", global_position + Vector3(0, 1.5, 0))
			raid.shake = maxf(raid.shake, 0.38)
		"spike":
			Audio.play_sfx("bug_mantis_attack", global_position)
			var col := Color(0.28, 0.92, 1.0) if kind == "harbor_reaper" else Color(1.0, 0.52, 0.18)
			var row := Hazards.SpikeRow.new()
			raid.fx.add_child(row)
			row.setup(raid, global_position + fwd * 2.2, fwd, 6, 2.5, float(data.dmg) * 0.88, 0.12, col)
			for side: float in [-1.0, 1.0]:
				var r2 := Hazards.SpikeRow.new()
				raid.fx.add_child(r2)
				var dir2: Vector3 = (fwd + fwd.cross(Vector3.UP) * side * (0.55 if phase >= 3 else 0.38)).normalized()
				r2.setup(raid, global_position + dir2 * 2.0, dir2, 5, 2.3, float(data.dmg) * 0.68, 0.14, col)
		"stomp":
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 0.5, 0))
			raid.shake = maxf(raid.shake, 0.52)
			var col2 := Color(0.3, 0.9, 1.0) if kind == "harbor_reaper" else Color(1.0, 0.6, 0.2)
			_ground_ring(global_position, 3.8, col2)
			var r1 := Hazards.ShockRing.new()
			raid.fx.add_child(r1)
			r1.setup(raid, global_position, 10.5 * sc * 0.34, 0.75, float(data.dmg) * 0.9, col2)
		"summon":
			var sub_kind := "mantis" if kind == "harbor_reaper" else "ripper"
			summon(sub_kind, 2 if phase <= 2 else 3, 6.0)
		"core":
			open_core(8.0)
			Audio.play_sfx("boss_king_core", global_position + Vector3(0, 2.0, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.0, 0), {"amount": 20, "life": 0.8, "size": 0.22, "spread": 120.0, "vmin": 3.5, "vmax": 8.5,
				"gravity": Vector3(0, -12, 0), "c0": Color(1.0, 0.85, 0.5, 0.95), "c1": Color(0.25, 0.85, 1.0, 0.0), "grow0": 1.0, "grow1": 0.3})
