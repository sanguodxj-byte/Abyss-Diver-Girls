extends "res://scripts/enemies/boss.gd"
## 深渊母皇：终章三阶段巨型 Boss。
## 一阶段晶刺地裂与尾刺横扫，二阶段酸雨齐射并放出啸翅虫，三阶段胸口晶核完全暴露、全部招式加速。
## 弱点：背面始终是 1.8 倍；三阶段晶核暴露时正面 3.0 倍，但暴露窗口会随阶段结束慢慢合拢。

func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 36.0
	summon_cap = 10
	weak_core = float(data.get("weak_core", 3.0))


func roar_id() -> String:
	return "boss_queen_roar"


func _on_phase(p: int) -> void:
	Audio.play_sfx("boss_queen_wail", global_position + Vector3(0, 2.5, 0))
	if p == 2:
		atk_cd = minf(atk_cd, 0.6)
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.25)
		open_core(12.0)
		Audio.play_sfx("boss_queen_core", global_position + Vector3(0, 2.5, 0))


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid:
		return Vector3.ZERO
	if act != "":
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if atk_cd > 0.0:
		if d > float(data.range) + 2.0:
			return fwd * 0.55
		if d < 5.0:
			return -fwd * 0.35
		return fwd.cross(Vector3.UP) * strafe * 0.3
	atk_cd = float(data.rate) * (0.6 if phase >= 2 else 0.9)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 3:
			0: _start_act([["wind", 1.0], ["spike", 0.32], ["recover", 0.8]], fwd)
			1: _start_act([["wind", 0.85], ["claw", 0.35], ["recover", 0.75]], fwd)
			_: _start_act([["wind", 0.9], ["stomp", 0.35], ["recover", 0.8]], fwd)
	elif phase == 2:
		match pattern_i % 4:
			0: _start_act([["wind", 1.05], ["rain", 0.4], ["recover", 0.85]], fwd)
			1: _start_act([["wind", 0.95], ["spike", 0.3], ["recover", 0.6], ["spike", 0.3], ["recover", 0.75]], fwd)
			2: _start_act([["wind", 0.85], ["summon", 0.4], ["recover", 0.7]], fwd)
			_: _start_act([["wind", 0.8], ["charge", 0.6], ["strike", 0.2], ["recover", 0.9]], fwd)
	else:
		match pattern_i % 4:
			0: _start_act([["wind", 0.8], ["rain", 0.4], ["recover", 0.6], ["spike", 0.3], ["recover", 0.7]], fwd)
			1: _start_act([["wind", 0.75], ["stomp", 0.3], ["recover", 0.35], ["stomp", 0.3], ["recover", 0.6]], fwd)
			2: _start_act([["wind", 0.7], ["core", 0.5], ["recover", 0.6]], fwd)
			_: _start_act([["wind", 0.75], ["summon", 0.4], ["rain", 0.4], ["recover", 0.8]], fwd)
	return Vector3.ZERO


func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	match name:
		"claw":
			_slash_fx(act_dir)
			_hit_mech(float(data.dmg), 2.6, float(data.range) + 3.0)
			raid.shake = maxf(raid.shake, 0.35)
		"spike":
			Audio.play_sfx("hit_chitin", global_position)
			var base: Vector3 = global_position + Vector3(0, 0.2, 0)
			var n := 7 if phase >= 3 else 6
			var row := Hazards.SpikeRow.new()
			raid.fx.add_child(row)
			row.setup(raid, base + act_dir * 2.6, act_dir, n, 2.8, float(data.dmg) * 0.85, 0.13, Color(0.78, 0.4, 1.0))
			if phase >= 2:
				for side: float in [-1.0, 1.0]:
					var dir2: Vector3 = (act_dir + act_dir.cross(Vector3.UP) * side * 0.85).normalized()
					var r2 := Hazards.SpikeRow.new()
					raid.fx.add_child(r2)
					r2.setup(raid, base + dir2 * 2.0, dir2, n - 2, 2.6, float(data.dmg) * 0.6, 0.15, Color(0.7, 0.35, 1.0))
		"stomp":
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 0.5, 0))
			raid.shake = maxf(raid.shake, 0.5)
			_ground_ring(global_position, 4.5, Color(0.85, 0.55, 1.0))
			var r := Hazards.ShockRing.new()
			raid.fx.add_child(r)
			r.setup(raid, global_position, 12.0 * sc * 0.32, 0.85, float(data.dmg) * 0.8, Color(0.85, 0.55, 1.0))
		"rain":
			Audio.play_sfx("boss_brood_hatch", global_position + Vector3(0, 2.0, 0))
			var m = target
			if m == null or not is_instance_valid(m):
				return
			var shots := 8 if phase >= 3 else 6
			for i in shots:
				var a := TAU * i / float(shots) + randf_range(-0.15, 0.15)
				var p: Vector3 = m.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 8.5)
				var sh := Hazards.LobShell.new()
				raid.fx.add_child(sh)
				sh.setup(raid, global_position + Vector3(0, 2.2 * sc * 0.32, 0), p, 1.45 + i * 0.07, 3.6, float(data.dmg) * 0.7, Color(0.78, 0.5, 1.0))
			raid.alert_noise(global_position, 36.0)
		"summon":
			summon("wasp" if phase == 2 else "ling", 3, 6.5)
		"core":
			open_core(10.0)
			Audio.play_sfx("boss_queen_core", global_position + Vector3(0, 2.5, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.2, 0), {"amount": 22, "life": 0.9, "size": 0.24, "spread": 120.0, "vmin": 3.0, "vmax": 9.0,
				"gravity": Vector3(0, -10, 0), "c0": Color(1.0, 0.92, 0.7, 1.0), "c1": Color(0.7, 0.25, 1.0, 0.0), "grow0": 1.0, "grow1": 0.3})
