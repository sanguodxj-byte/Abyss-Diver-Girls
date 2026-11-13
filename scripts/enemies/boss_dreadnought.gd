extends "res://scripts/enemies/boss.gd"
## 地标重装攻坚型首领（溢洪闸枢巨鳌 spillway_leviathan / 转炉熔渣无畏舰 foundry_dreadnought / 斗轮裂岩泰坦 excavator_titan）：
##   - 重型装甲压迫推进：液压巨钳/斗轮横扫（claw）+ 尾翼爆破火箭重炮弹幕（salvo）+ 高速钨芯穿甲排炮（slug）+ 裂地岩刺与双环震地；
##   - 三阶段开启重型防爆胸扉暴露反应炉核心。

func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 35.0
	summon_cap = 8
	weak_core = float(data.get("weak_core", 2.7))
	charge_speed = float(data.get("charge_speed", 15.5))
	charge_time = float(data.get("charge_time", 0.62))


func roar_id() -> String:
	return "boss_brood_roar" if kind == "spillway_leviathan" else "boss_king_roar"


func _on_wind() -> void:
	super._on_wind()
	if raid == null:
		return
	match _next_step():
		"slug":
			_telegraph_lane(22.0, float(data.radius) * 1.55, windup_t + 0.58, Color(1.0, 0.56, 0.18))
		"salvo":
			_telegraph_ring(float(data.range) + 2.6, windup_t + 0.58, Color(1.0, 0.45, 0.16))


func _act_enter(name: String) -> void:
	if name == "slug" or name == "salvo":
		step_len = act_t
		_boss_step(name)
		return
	super._act_enter(name)


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.52)
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.25)
		open_core(11.5)
		if raid:
			Audio.play_sfx("boss_king_core", global_position + Vector3(0, 2.3, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.3, 0), {"amount": 26, "life": 0.92, "size": 0.25, "spread": 120.0, "vmin": 4.0, "vmax": 10.0,
				"gravity": Vector3(0, -12, 0), "c0": Color(1.0, 0.58, 0.18, 1.0), "c1": Color(0.85, 0.25, 0.08, 0.0), "grow0": 1.0, "grow1": 0.28})


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid or act != "":
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if not _in_player_view(d):
		return fwd * 0.88
	if atk_cd > 0.0:
		if d > float(data.range) + 2.8:
			return fwd * 0.76
		if d < 4.4:
			return -fwd * 0.28
		return fwd.cross(Vector3.UP) * strafe * 0.42
	atk_cd = float(data.rate) * (0.66 if phase >= 2 else 0.90)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 3:
			0: _start_act([["wind", 0.92], ["claw", 0.34], ["recover", 0.78]], fwd)
			1: _start_act([["wind", 0.95], ["salvo", 0.38], ["recover", 0.82]], fwd)
			_: _start_act([["wind", 0.90], ["stomp", 0.35], ["recover", 0.80]], fwd)
	elif phase == 2:
		match pattern_i % 4:
			0: _start_act([["wind", 0.84], ["charge", charge_time], ["strike", 0.24], ["stomp", 0.32], ["recover", 0.82]], fwd)
			1: _start_act([["wind", 0.86], ["slug", 0.32], ["recover", 0.40], ["spike", 0.30], ["recover", 0.76]], fwd)
			2: _start_act([["wind", 0.82], ["summon", 0.38], ["recover", 0.72]], fwd)
			_: _start_act([["wind", 0.88], ["salvo", 0.38], ["recover", 0.78]], fwd)
	else:
		match pattern_i % 4:
			0: _start_act([["wind", 0.76], ["salvo", 0.36], ["recover", 0.36], ["stomp", 0.30], ["recover", 0.68]], fwd)
			1: _start_act([["wind", 0.72], ["core", 0.48], ["recover", 0.62]], fwd)
			2: _start_act([["wind", 0.74], ["charge", charge_time], ["strike", 0.22], ["slug", 0.30], ["recover", 0.70]], fwd)
			_: _start_act([["wind", 0.76], ["summon", 0.36], ["spike", 0.30], ["recover", 0.72]], fwd)
	return Vector3.ZERO


func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	var col := Color(1.0, 0.48, 0.14)
	if kind == "spillway_leviathan":
		col = Color(0.26, 0.82, 0.92)
	elif kind == "excavator_titan":
		col = Color(0.96, 0.66, 0.18)
	elif kind == "drydock_behemoth":
		col = Color(0.28, 0.78, 0.96)
	match name:
		"claw":
			_slash_fx(act_dir)
			_hit_mech(float(data.dmg), 2.8, float(data.range) + 3.2)
			raid.shake = maxf(raid.shake, 0.42)
		"slug":
			Audio.play_sfx("bug_ironjaw_attack", global_position + Vector3(0, 1.8, 0))
			var muzzle := global_position + Vector3(0, 1.75 * sc * 0.45, 0) + act_dir * 2.0
			for side: float in [-1.0, 0.0, 1.0]:
				var dir := act_dir.rotated(Vector3.UP, side * 0.16).normalized()
				var slug := Hazards.KineticSlug.new()
				raid.fx.add_child(slug)
				slug.setup(raid, muzzle + dir * 0.4, dir, 28.0, float(data.dmg) * 0.86, col)
			raid.shake = maxf(raid.shake, 0.30)
		"salvo":
			Audio.play_sfx("bug_mortar_launch", global_position + Vector3(0, 2.2, 0))
			var m = target
			if m == null or not is_instance_valid(m):
				return
			var shots := 7 if phase >= 3 else 5
			for i in shots:
				var a := TAU * float(i) / float(shots) + randf_range(-0.18, 0.18)
				var lp: Vector3 = m.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.6, 7.8)
				var rk := Hazards.RocketSalvo.new()
				raid.fx.add_child(rk)
				rk.setup(raid, global_position + Vector3(0, 2.4 * sc * 0.40, 0), lp, 1.05 + i * 0.07, 3.4, float(data.dmg) * 0.80, col)
			raid.alert_noise(global_position, 36.0)
		"spike":
			Audio.play_sfx("hit_chitin", global_position)
			var base: Vector3 = global_position + Vector3(0, 0.2, 0)
			var fans := 3 if phase >= 2 else 2
			for k in fans:
				var ang: float = (float(k) - float(fans - 1) * 0.5) * 0.48
				var dir: Vector3 = act_dir.rotated(Vector3.UP, ang).normalized()
				var row := Hazards.SpikeRow.new()
				raid.fx.add_child(row)
				row.setup(raid, base + dir * 2.4, dir, 6, 2.6, float(data.dmg) * 0.82, 0.13, col)
		"stomp":
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 0.5, 0))
			raid.shake = maxf(raid.shake, 0.58)
			_ground_ring(global_position, 4.5, col)
			var r1 := Hazards.ShockRing.new()
			raid.fx.add_child(r1)
			r1.setup(raid, global_position, 11.8 * sc * 0.34, 0.82, float(data.dmg) * 0.85, col)
			if phase >= 3:
				var r2 := Hazards.ShockRing.new()
				raid.fx.add_child(r2)
				r2.setup(raid, global_position, 16.5 * sc * 0.34, 1.15, float(data.dmg) * 0.65, col)
		"summon":
			var gk := "shielder"
			if kind == "foundry_dreadnought":
				gk = "mortar"
			elif kind == "excavator_titan":
				gk = "ironjaw"
			elif kind == "drydock_behemoth":
				gk = "mantis"
			summon(gk, 2, 7.0)
		"core":
			open_core(9.8)
			Audio.play_sfx("boss_king_core", global_position + Vector3(0, 2.3, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 2.3, 0), {"amount": 22, "life": 0.88, "size": 0.24, "spread": 120.0, "vmin": 3.5, "vmax": 9.0,
				"gravity": Vector3(0, -10, 0), "c0": col, "c1": Color(1.0, 0.88, 0.55, 0.0), "grow0": 1.0, "grow1": 0.3})
