extends "res://scripts/enemies/boss.gd"
## 地标战术火力型首领（中央总站巡道铁卫 terminus_warden / 洲际井群弹道猎犬 silo_warhead / 地热磁暴主宰 core_overlord）：
##   - 全程采用重工业实体弹道：平射高速钨芯穿甲弹扇幕（slug）+ 尾翼高爆火箭齐射（salvo）+ 排障铲冲撞 / 震地波；
##   - 二阶段提高机动与齐射密度并呼叫战术护卫；三阶段装甲散热门全开暴露高倍率反应堆晶核。

func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 35.0
	summon_cap = 8
	weak_core = float(data.get("weak_core", 2.7))
	charge_speed = float(data.get("charge_speed", 16.5))
	charge_time = float(data.get("charge_time", 0.58))


func roar_id() -> String:
	if kind == "core_overlord":
		return "boss_queen_roar"
	return "boss_king_roar"


func _on_wind() -> void:
	super._on_wind()
	if raid == null:
		return
	match _next_step():
		"slug":
			_telegraph_lane(24.0, float(data.radius) * 1.45, windup_t + 0.55, Color(1.0, 0.64, 0.22))
		"salvo":
			_telegraph_ring(float(data.range) + 2.4, windup_t + 0.55, Color(1.0, 0.48, 0.18))


func _act_enter(name: String) -> void:
	if name == "slug" or name == "salvo":
		step_len = act_t
		_boss_step(name)
		return
	super._act_enter(name)


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.5)
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.25)
		open_core(11.5)
		if raid:
			Audio.play_sfx("boss_queen_core" if kind == "core_overlord" else "boss_king_core", global_position + Vector3(0, 2.2, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.2, 0), {"amount": 24, "life": 0.9, "size": 0.24, "spread": 120.0, "vmin": 4.0, "vmax": 9.5,
				"gravity": Vector3(0, -12, 0), "c0": Color(1.0, 0.68, 0.24, 1.0), "c1": Color(0.9, 0.28, 0.1, 0.0), "grow0": 1.0, "grow1": 0.28})


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid or act != "":
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if not _in_player_view(d):
		return fwd * 0.88
	if atk_cd > 0.0:
		if d > 11.0:
			return fwd * 0.72
		if d < 5.5:
			return -fwd * 0.38
		return fwd.cross(Vector3.UP) * strafe * 0.52
	atk_cd = float(data.rate) * (0.64 if phase >= 2 else 0.88)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 3:
			0: _start_act([["wind", 0.88], ["slug", 0.34], ["recover", 0.75]], fwd)
			1: _start_act([["wind", 0.92], ["salvo", 0.38], ["recover", 0.80]], fwd)
			_: _start_act([["wind", 0.85], ["charge", charge_time], ["strike", 0.22], ["recover", 0.85]], fwd)
	elif phase == 2:
		match pattern_i % 4:
			0: _start_act([["wind", 0.82], ["slug", 0.30], ["recover", 0.38], ["slug", 0.30], ["recover", 0.72]], fwd)
			1: _start_act([["wind", 0.88], ["salvo", 0.38], ["recover", 0.42], ["stomp", 0.32], ["recover", 0.78]], fwd)
			2: _start_act([["wind", 0.80], ["summon", 0.38], ["recover", 0.70]], fwd)
			_: _start_act([["wind", 0.78], ["charge", charge_time], ["strike", 0.22], ["recover", 0.80]], fwd)
	else:
		match pattern_i % 4:
			0: _start_act([["wind", 0.74], ["salvo", 0.35], ["recover", 0.38], ["slug", 0.30], ["recover", 0.68]], fwd)
			1: _start_act([["wind", 0.70], ["core", 0.46], ["recover", 0.62]], fwd)
			2: _start_act([["wind", 0.72], ["slug", 0.28], ["recover", 0.32], ["stomp", 0.30], ["recover", 0.65]], fwd)
			_: _start_act([["wind", 0.75], ["summon", 0.36], ["salvo", 0.36], ["recover", 0.72]], fwd)
	return Vector3.ZERO


func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	var col := Color(1.0, 0.56, 0.18)
	if kind == "terminus_warden":
		col = Color(0.32, 0.86, 0.95)
	elif kind == "core_overlord":
		col = Color(1.0, 0.44, 0.16)
	match name:
		"slug":
			Audio.play_sfx("bug_ironjaw_attack", global_position + Vector3(0, 1.8, 0))
			var muzzle := global_position + Vector3(0, 1.65 * sc * 0.45, 0) + act_dir * 1.8
			ART.burst(raid.fx, muzzle, {"amount": 10, "life": 0.28, "size": 0.42, "tex": ART.smoke_tex(), "additive": false,
				"spread": 45.0, "vmin": 1.5, "vmax": 4.5, "c0": Color(0.35, 0.33, 0.30, 0.72), "c1": Color(0.18, 0.18, 0.18, 0.0), "grow0": 0.5, "grow1": 1.7})
			var cnt := 5 if phase >= 3 else (3 if phase == 2 else 3)
			var spread := 0.15 if phase <= 2 else 0.13
			for i in cnt:
				var ang := (float(i) - float(cnt - 1) * 0.5) * spread
				var dir := act_dir.rotated(Vector3.UP, ang).normalized()
				var slug := Hazards.KineticSlug.new()
				raid.fx.add_child(slug)
				slug.setup(raid, muzzle + dir * 0.4, dir, 31.0 if phase >= 2 else 27.0, float(data.dmg) * 0.84, col)
			raid.shake = maxf(raid.shake, 0.26)
			raid.alert_noise(global_position, 34.0)
		"salvo":
			Audio.play_sfx("bug_mortar_launch", global_position + Vector3(0, 2.2, 0))
			var m = target
			if m == null or not is_instance_valid(m):
				return
			var n_rk := 8 if phase >= 3 else (6 if phase == 2 else 5)
			for i in n_rk:
				var a := TAU * float(i) / float(n_rk) + randf_range(-0.16, 0.16)
				var r_off := randf_range(1.8, 7.6) if i > 0 else randf_range(0.6, 2.2)
				var lp: Vector3 = m.global_position + Vector3(cos(a), 0, sin(a)) * r_off
				var rk := Hazards.RocketSalvo.new()
				raid.fx.add_child(rk)
				rk.setup(raid, global_position + Vector3(0, 2.5 * sc * 0.42, 0), lp, 0.92 + i * 0.06, 3.1, float(data.dmg) * 0.78, col)
			raid.alert_noise(global_position, 36.0)
		"stomp":
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 0.5, 0))
			raid.shake = maxf(raid.shake, 0.50)
			_ground_ring(global_position, 4.2, col)
			var r1 := Hazards.ShockRing.new()
			raid.fx.add_child(r1)
			r1.setup(raid, global_position, 11.2 * sc * 0.34, 0.82, float(data.dmg) * 0.82, col)
		"summon":
			var gk := "mech_beetle"
			if kind == "silo_warhead":
				gk = "lancer"
			elif kind == "core_overlord":
				gk = "aegis"
			summon(gk, 2, 6.8)
		"core":
			open_core(9.5)
			Audio.play_sfx("boss_queen_core" if kind == "core_overlord" else "boss_king_core", global_position + Vector3(0, 2.2, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.2, 0), {"amount": 20, "life": 0.85, "size": 0.24, "spread": 120.0, "vmin": 3.5, "vmax": 8.5,
				"gravity": Vector3(0, -10, 0), "c0": col, "c1": Color(1.0, 0.85, 0.5, 0.0), "grow0": 1.0, "grow1": 0.3})
