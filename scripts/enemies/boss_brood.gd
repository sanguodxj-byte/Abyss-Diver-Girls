extends "res://scripts/enemies/boss.gd"
## 赤湖巢母：盘踞菌毯的区域 Boss。
## 一阶段用前肢横扫与晶刺逼人，二阶段开始齐射酸雨并加速孵化，三阶段把三招混在一起。
## 弱点在背部卵囊：绕到她背后（她横扫后转身很慢）打，伤害倍率 2.2。

func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 30.0
	summon_cap = 8


func roar_id() -> String:
	return "boss_brood_roar"


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.6)
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.3)


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid:
		return Vector3.ZERO
	if act != "":
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if atk_cd > 0.0:
		# 出招之间缓慢挪动：远则前进，近了绕圈
		if d > 7.5:
			return fwd * 0.7
		if d < 4.2:
			return -fwd * 0.5
		return fwd.cross(Vector3.UP) * strafe * 0.45
	atk_cd = float(data.rate) * (0.6 if phase >= 2 else 0.85)
	pattern_i += 1
	var opts: Array
	if phase <= 1:
		opts = ["claw", "spike", "claw", "hatch"]
	elif phase == 2:
		opts = ["spike", "rain", "claw", "hatch", "rain"]
	else:
		opts = ["rain", "spike", "hatch", "rain", "claw", "spike"]
	match str(opts[pattern_i % opts.size()]):
		"claw":
			_start_act([["wind", 0.72], ["claw", 0.36], ["recover", 0.85]], fwd)
		"spike":
			_start_act([["wind", 0.95], ["spike", 0.3], ["recover", 0.75]], fwd)
		"rain":
			_start_act([["wind", 1.05], ["rain", 0.4], ["recover", 0.9]], fwd)
		"hatch":
			_start_act([["wind", 0.9], ["hatch", 0.45], ["recover", 0.8]], fwd)
	return Vector3.ZERO


func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	var fwd := act_dir
	match name:
		"claw":
			_slash_fx(fwd)
			_hit_mech(float(data.dmg), 2.4, float(data.range) + 3.0)
			Audio.play_sfx("bug_crystal_bug_attack", global_position + Vector3(0, 1.4, 0))
			raid.shake = maxf(raid.shake, 0.32)
		"spike":
			Audio.play_sfx("hit_chitin", global_position)
			var row := Hazards.SpikeRow.new()
			raid.fx.add_child(row)
			row.setup(raid, global_position + fwd * 2.4 * sc * 0.4, fwd, 6, 2.6 * sc * 0.35, float(data.dmg) * 0.9, 0.14, Color(0.8, 0.42, 1.0))
			if phase >= 3:
				for side: float in [-1.0, 1.0]:
					var r2 := Hazards.SpikeRow.new()
					raid.fx.add_child(r2)
					var dir2: Vector3 = (fwd + fwd.cross(Vector3.UP) * side * 0.7).normalized()
					r2.setup(raid, global_position + dir2 * 2.0, dir2, 5, 2.4, float(data.dmg) * 0.7, 0.16, Color(0.8, 0.42, 1.0))
		"rain":
			Audio.play_sfx("boss_brood_hatch", global_position + Vector3(0, 1.6, 0))
			var m = target
			if m == null or not is_instance_valid(m):
				return
			for i in 6:
				var a := TAU * i / 6.0 + randf_range(-0.2, 0.2)
				var p: Vector3 = m.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 7.5)
				var sh := Hazards.LobShell.new()
				raid.fx.add_child(sh)
				sh.setup(raid, global_position + Vector3(0, 2.4 * sc * 0.4, 0), p, 1.5 + i * 0.08, 3.4, float(data.dmg) * 0.75, Color(0.8, 0.95, 0.35))
			raid.alert_noise(global_position, 34.0)
		"hatch":
			Audio.play_sfx("boss_brood_hatch", global_position + Vector3(0, 1.4, 0))
			var n := 2 if phase <= 2 else 3
			summon("ling" if randf() < 0.7 else "spitter", n, 5.0 * sc * 0.4)
			ART.burst(raid.fx, global_position + Vector3(0, 1.6 * sc * 0.5, 0), {"amount": 16, "life": 0.7, "size": 0.4, "vmin": 2.0, "vmax": 5.0, "spread": 100.0,
				"gravity": Vector3(0, -8.0, 0), "c0": Color(1.0, 0.6, 0.85, 0.9), "c1": Color(0.45, 0.1, 0.3, 0.0), "grow0": 1.0, "grow1": 0.4})

