extends "res://scripts/enemies/boss.gd"
## 熔渣巨炮皇虫 / 赤湖棱镜主宰：重装远程火力压制与领域震荡型 Boss。
## 一阶段曲射弹幕（酸浆炮 / 棱镜光弹）与震荡环、晶刺交替封路；
## 二阶段呼唤护卫虫群并加密弹幕；三阶段散热甲板 / 棱镜护门全开暴露核心，释放双层震荡波与饱和轰炸。

func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 34.0
	summon_cap = 7
	weak_core = float(data.get("weak_core", 2.8))


func roar_id() -> String:
	return "boss_queen_roar" if kind == "prism_archon" else "boss_king_roar"


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.5)
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.25)
		open_core(11.0)
		if raid:
			Audio.play_sfx("boss_queen_core" if kind == "prism_archon" else "boss_king_core", global_position + Vector3(0, 2.2, 0))
			var c0 := Color(0.82, 0.45, 1.0, 1.0) if kind == "prism_archon" else Color(1.0, 0.65, 0.2, 1.0)
			ART.burst(raid.fx, global_position + Vector3(0, 2.2, 0), {"amount": 26, "life": 0.95, "size": 0.25, "spread": 120.0, "vmin": 4.0, "vmax": 10.0,
				"gravity": Vector3(0, -12, 0), "c0": c0, "c1": Color(0.4, 0.15, 0.8, 0.0), "grow0": 1.0, "grow1": 0.3})


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid:
		return Vector3.ZERO
	if act != "":
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if not _in_player_view(d):
		return fwd * 0.85
	if atk_cd > 0.0:
		if d > 9.5:
			return fwd * 0.65
		if d < 5.0:
			return -fwd * 0.4
		return fwd.cross(Vector3.UP) * strafe * 0.4
	atk_cd = float(data.rate) * (0.65 if phase >= 2 else 0.9)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 3:
			0: _start_act([["wind", 0.95], ["rain", 0.38], ["recover", 0.8]], fwd)
			1: _start_act([["wind", 0.88], ["spike", 0.32], ["recover", 0.75]], fwd)
			_: _start_act([["wind", 0.9], ["stomp", 0.35], ["recover", 0.8]], fwd)
	elif phase == 2:
		match pattern_i % 4:
			0: _start_act([["wind", 0.9], ["rain", 0.38], ["recover", 0.45], ["stomp", 0.32], ["recover", 0.8]], fwd)
			1: _start_act([["wind", 0.85], ["spike", 0.3], ["recover", 0.4], ["spike", 0.3], ["recover", 0.75]], fwd)
			2: _start_act([["wind", 0.82], ["summon", 0.4], ["recover", 0.75]], fwd)
			_: _start_act([["wind", 0.88], ["rain", 0.4], ["recover", 0.8]], fwd)
	else:
		match pattern_i % 4:
			0: _start_act([["wind", 0.78], ["rain", 0.36], ["recover", 0.45], ["rain", 0.36], ["recover", 0.75]], fwd)
			1: _start_act([["wind", 0.75], ["stomp", 0.3], ["recover", 0.35], ["spike", 0.3], ["recover", 0.65]], fwd)
			2: _start_act([["wind", 0.7], ["core", 0.48], ["recover", 0.65]], fwd)
			_: _start_act([["wind", 0.75], ["summon", 0.38], ["stomp", 0.32], ["recover", 0.75]], fwd)
	return Vector3.ZERO


func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	var is_prism := kind == "prism_archon"
	var col := Color(0.76, 0.42, 1.0) if is_prism else Color(1.0, 0.56, 0.16)
	match name:
		"rain":
			Audio.play_sfx("bug_mortar_launch", global_position + Vector3(0, 2.0, 0))
			var m = target
			if m == null or not is_instance_valid(m):
				return
			var shots := 8 if phase >= 3 else 6
			for i in shots:
				var a := TAU * i / float(shots) + randf_range(-0.18, 0.18)
				var p: Vector3 = m.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.2, 8.2)
				var sh := Hazards.LobShell.new()
				raid.fx.add_child(sh)
				sh.setup(raid, global_position + Vector3(0, 2.4 * sc * 0.38, 0), p, 1.35 + i * 0.07, 3.6, float(data.dmg) * 0.75, col)
			raid.alert_noise(global_position, 36.0)
		"spike":
			Audio.play_sfx("hit_chitin", global_position)
			var base: Vector3 = global_position + Vector3(0, 0.2, 0)
			var fans := 3 if phase >= 2 else 2
			for k in fans:
				var ang: float = (float(k) - float(fans - 1) * 0.5) * 0.52
				var dir: Vector3 = act_dir.rotated(Vector3.UP, ang).normalized()
				var row := Hazards.SpikeRow.new()
				raid.fx.add_child(row)
				row.setup(raid, base + dir * 2.4, dir, 6, 2.6, float(data.dmg) * 0.82, 0.13, col)
		"stomp":
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 0.5, 0))
			raid.shake = maxf(raid.shake, 0.55)
			_ground_ring(global_position, 4.2, col)
			var r1 := Hazards.ShockRing.new()
			raid.fx.add_child(r1)
			r1.setup(raid, global_position, 11.5 * sc * 0.33, 0.8, float(data.dmg) * 0.85, col)
			if phase >= 3:
				var r2 := Hazards.ShockRing.new()
				raid.fx.add_child(r2)
				r2.setup(raid, global_position, 16.5 * sc * 0.33, 1.15, float(data.dmg) * 0.65, col)
		"summon":
			summon("crystal_bug" if is_prism else "mortar", 2, 6.8)
		"core":
			open_core(9.5)
			Audio.play_sfx("boss_queen_core" if is_prism else "boss_king_core", global_position + Vector3(0, 2.2, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.2, 0), {"amount": 22, "life": 0.85, "size": 0.24, "spread": 120.0, "vmin": 3.5, "vmax": 9.0,
				"gravity": Vector3(0, -10, 0), "c0": col, "c1": Color(1.0, 0.9, 0.6, 0.0), "grow0": 1.0, "grow1": 0.3})
