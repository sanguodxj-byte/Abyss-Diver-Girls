extends "res://scripts/enemies/boss.gd"
## 裂谷铁甲王虫：第六章的重装 Boss。
## 一阶段双柱巨足震地 + 单次冲撞；二阶段连续三次冲撞并叫来改装机甲虫；三阶段背甲裂开、晶核暴露，
## 冲撞结束后的收招就是打晶核的窗口。撞到地形会多一段硬直，那是绕后打背脊的最好时机。

func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 32.0
	summon_cap = 4
	weak_core = float(data.get("weak_core", 2.6))


func roar_id() -> String:
	return "boss_king_roar"


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.5)
		charge_speed = 21.0
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.2)
		# 背甲裂开：晶核暴露，正面伤害倍率生效
		open_core(9.0)
		if raid:
			Audio.play_sfx("boss_king_core", global_position + Vector3(0, 2.0, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.2, 0), {"amount": 26, "life": 1.0, "size": 0.26, "spread": 120.0, "vmin": 4.0, "vmax": 11.0,
				"gravity": Vector3(0, -14, 0), "c0": Color(0.95, 0.75, 0.4, 1.0), "c1": Color(0.6, 0.2, 1.0, 0.0), "grow0": 1.0, "grow1": 0.3})


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid:
		return Vector3.ZERO
	if act != "":
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if atk_cd > 0.0:
		if d > float(data.range) + 1.0:
			return fwd * 0.8
		if d < 4.5:
			return -fwd * 0.4
		return Vector3.ZERO
	atk_cd = float(data.rate) * (0.7 if phase >= 2 else 1.0)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 2:
			0: _start_act([["wind", 1.0], ["charge", 0.9], ["strike", 0.2], ["recover", 1.1]], fwd)
			_: _start_act([["wind", 0.95], ["stomp", 0.35], ["recover", 0.9]], fwd)
	elif phase == 2:
		match pattern_i % 3:
			0: _start_act([["wind", 0.85], ["charge", 0.85], ["strike", 0.18], ["recover", 0.35], ["charge", 0.8], ["strike", 0.18], ["recover", 0.35],
					["charge", 0.75], ["strike", 0.18], ["recover", 1.0]], fwd)
			1: _start_act([["wind", 0.9], ["stomp", 0.35], ["recover", 0.8]], fwd)
			_: _start_act([["wind", 0.8], ["summon", 0.4], ["recover", 0.9]], fwd)
	else:
		match pattern_i % 3:
			0: _start_act([["wind", 0.75], ["stomp", 0.3], ["recover", 0.5], ["stomp", 0.3], ["recover", 0.7]], fwd)
			1: _start_act([["wind", 0.7], ["charge", 0.8], ["strike", 0.18], ["recover", 0.5], ["charge", 0.75], ["strike", 0.18], ["recover", 1.0]], fwd)
			_: _start_act([["wind", 0.75], ["core", 0.5], ["recover", 0.7]], fwd)
	return Vector3.ZERO


func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	match name:
		"stomp":
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 0.5, 0))
			raid.shake = maxf(raid.shake, 0.6)
			_ground_ring(global_position, 4.0, Color(1.0, 0.75, 0.35))
			var r1 := Hazards.ShockRing.new()
			raid.fx.add_child(r1)
			r1.setup(raid, global_position, 11.0 * sc * 0.34, 0.8, float(data.dmg))
			if phase >= 3:
				var r2 := Hazards.ShockRing.new()
				raid.fx.add_child(r2)
				r2.setup(raid, global_position, 16.0 * sc * 0.34, 1.15, float(data.dmg) * 0.7)
		"summon":
			summon("mech_beetle", 2, 7.0)
		"core":
			open_core(6.0)
			Audio.play_sfx("boss_king_core", global_position + Vector3(0, 2.0, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.0, 0), {"amount": 18, "life": 0.8, "size": 0.2, "spread": 120.0, "vmin": 3.0, "vmax": 8.0,
				"gravity": Vector3(0, -12, 0), "c0": Color(1.0, 0.9, 0.6, 0.95), "c1": Color(0.7, 0.3, 1.0, 0.0), "grow0": 1.0, "grow1": 0.3})


## 冲撞结束时的收招：撞上地形就多硬直一段，给玩家绕后的机会
func _tick_act(delta: float) -> void:
	super._tick_act(delta)
	if act == "recover" and get_slide_collision_count() > 0 and act_t > 0.25:
		act_t = maxf(act_t, 1.3)
