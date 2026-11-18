extends "res://scripts/enemies/boss.gd"
## 重工业浮空要塞母舰首领（sky_carrier · 苍穹铁砧·重工浮空母舰）：
##   - 悬停于战场上空（hover = 5.6m），四具倾转涵道涡扇推进舱实时矢量偏转维持重装舰体巡航；
##   - 舰腹与侧舷挂载 3 座独立火控机炮/火箭炮塔，在移动中持续对地面机甲俯射压制；
##   - 主时间轴交替发动地毯式航弹走廊（salvo）、前甲板机库释放啸翅无人机与爆破投舱（hatch）、下洗电磁震波（stomp）及俯冲排炮（slug）；
##   - 三阶段前机库防爆门洞开，暴露高能电弧炉芯。


const ModularGlb = preload("res://scripts/enemies/boss_modular_glb.gd")

var _downwash_t := 0.0


func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 42.0
	summon_cap = 10
	weak_core = float(data.get("weak_core", 2.9))
	charge_speed = float(data.get("charge_speed", 16.5))
	charge_time = float(data.get("charge_time", 0.62))
	if hover > 0.0:
		_fit_collider(hover + 4.4)


func roar_id() -> String:
	return "boss_queen_roar"


func _physics_tick(delta: float) -> void:
	super._physics_tick(delta)
	if awake and not dying and hp > 0.0:
		_tick_turrets(delta)
		# 四具涡扇在正下方地面持续吹散环形下洗沙尘浪，配合偏置舰影在 2.5D 俯视下直观呈现悬停高度
		_downwash_t -= delta
		if _downwash_t <= 0.0 and raid != null and is_instance_valid(raid.fx):
			_downwash_t = 0.24
			var gp := Vector3(global_position.x, 0.14, global_position.z)
			ART.burst(raid.fx, gp, {"amount": 7, "life": 0.62, "size": 1.25, "tex": ART.dust_tex(), "additive": false, "flat": 0.92,
				"dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": 4.2, "vmax": 8.8, "gravity": Vector3(0, 0.15, 0), "damp": 4.2,
				"c0": Color(0.56, 0.50, 0.40, 0.0), "cmid": Color(0.56, 0.50, 0.40, 0.36), "cmid_pos": 0.20,
				"c1": Color(0.45, 0.40, 0.32, 0.0), "grow0": 0.65, "grow1": 2.0})


func take_damage(dmg: float, from := Vector3.ZERO, ap := 0.0) -> void:
	var has_hp_meta: bool = has_meta("last_hit_pos")
	var hit_p: Vector3 = get_meta("last_hit_pos") if has_hp_meta else Vector3.ZERO
	if has_hp_meta:
		remove_meta("last_hit_pos")
	super.take_damage(dmg, from, ap)
	if has_hp_meta and awake and not dying and hp > 0.0 and guard_t <= 0.0:
		_damage_carrier_turret(hit_p, dmg)


func _damage_carrier_turret(hit_p: Vector3, raw_dmg: float) -> void:
	if not has_meta("turret_mounts"):
		return
	var mounts: Array = get_meta("turret_mounts")
	var best_idx := -1
	var best_d := 6.8
	for i in mounts.size():
		var tur: Dictionary = mounts[i]
		if bool(tur.get("destroyed", false)):
			continue
		var yn: Node3D = tur.get("yaw_node")
		if not is_instance_valid(yn):
			continue
		var d2: float = Vector2(yn.global_position.x - hit_p.x, yn.global_position.z - hit_p.z).length()
		if d2 < best_d:
			best_d = d2
			best_idx = i
	if best_idx < 0:
		return
	var hit_tur: Dictionary = mounts[best_idx]
	if not hit_tur.has("part_hp"):
		hit_tur["part_hp"] = clampf(float(data.hp) * 0.045, 160.0, 900.0)
	var cur_p: float = float(hit_tur["part_hp"]) - raw_dmg
	hit_tur["part_hp"] = cur_p
	if cur_p > 0.0:
		ModularGlb.flash_turret_visual(self, hit_tur)
	else:
		hit_tur["destroyed"] = true
		hit_tur["burst_left"] = 0
		ModularGlb.wreck_turret_visual(self, hit_tur)
		var yn2: Node3D = hit_tur.get("yaw_node")
		var tp: Vector3 = yn2.global_position if is_instance_valid(yn2) else (global_position + Vector3(0.0, hover, 0.0))
		Audio.play_sfx("bug_mech_beetle_death", tp)
		if raid != null and is_instance_valid(raid.fx):
			raid.explode_fx(tp, 4.0, Color(0.28, 0.86, 1.0))
			raid.shake = maxf(raid.shake, 0.48)
		if hp > 1.0:
			hp = maxf(1.0, hp - float(data.hp) * 0.04)
			_check_phase()


func _on_wind() -> void:
	super._on_wind()
	if raid == null:
		return
	match _next_step():
		"slug":
			_telegraph_lane(26.0, float(data.radius) * 1.4, windup_t + 0.56, Color(0.28, 0.86, 1.0))
		"salvo":
			_telegraph_ring(float(data.range) + 2.5, windup_t + 0.58, Color(1.0, 0.50, 0.16))


func _act_enter(name: String) -> void:
	if name == "slug" or name == "salvo":
		step_len = act_t
		_boss_step(name)
		return
	super._act_enter(name)


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.50)
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.25)
		open_core(12.5)
		if raid:
			Audio.play_sfx("boss_queen_core", global_position + Vector3(0, hover, 0))
			ART.burst(raid.fx, global_position + Vector3(0, hover, 0), {"amount": 30, "life": 0.92, "size": 0.34, "spread": 125.0, "vmin": 5.0, "vmax": 13.0,
				"gravity": Vector3(0, -8, 0), "c0": Color(0.28, 0.92, 1.0, 1.0), "c1": Color(0.14, 0.42, 0.95, 0.0), "grow0": 1.0, "grow1": 0.28})


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid or act != "":
		return Vector3.ZERO
	var fwd: Vector3 = to / maxf(d, 0.01)
	if not _in_player_view(d) and d > 22.0:
		return fwd * 0.95
	if atk_cd > 0.0:
		# 空中母舰保持 11m~15m 最佳盘旋轰炸包线，侧向切线机动
		var tang: Vector3 = fwd.cross(Vector3.UP) * strafe * 0.72
		var radial: Vector3 = fwd * clampf((d - 12.5) * 0.22, -0.55, 0.80)
		return (tang + radial).normalized() * 0.85
	atk_cd = float(data.rate) * (0.66 if phase >= 2 else 0.90)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 3:
			0: _start_act([["wind", 0.88], ["salvo", 0.38], ["recover", 0.78]], fwd)
			1: _start_act([["wind", 0.86], ["hatch", 0.42], ["recover", 0.80]], fwd)
			_: _start_act([["wind", 0.88], ["slug", 0.34], ["recover", 0.76]], fwd)
	elif phase == 2:
		match pattern_i % 4:
			0: _start_act([["wind", 0.82], ["salvo", 0.36], ["recover", 0.36], ["slug", 0.32], ["recover", 0.74]], fwd)
			1: _start_act([["wind", 0.80], ["hatch", 0.40], ["recover", 0.72]], fwd)
			2: _start_act([["wind", 0.84], ["stomp", 0.36], ["recover", 0.76]], fwd)
			_: _start_act([["wind", 0.82], ["charge", charge_time], ["strike", 0.24], ["recover", 0.78]], fwd)
	else:
		match pattern_i % 4:
			0: _start_act([["wind", 0.74], ["salvo", 0.34], ["recover", 0.34], ["stomp", 0.32], ["recover", 0.66]], fwd)
			1: _start_act([["wind", 0.72], ["core", 0.48], ["recover", 0.62]], fwd)
			2: _start_act([["wind", 0.74], ["hatch", 0.38], ["slug", 0.32], ["recover", 0.68]], fwd)
			_: _start_act([["wind", 0.76], ["charge", charge_time], ["strike", 0.22], ["salvo", 0.34], ["recover", 0.70]], fwd)
	return Vector3.ZERO


# ================= 3 座舰载对地独立火控炮塔 =================
func _tick_turrets(delta: float) -> void:
	if not has_meta("turret_mounts") or not is_instance_valid(visual):
		return
	var body_node: Node3D = visual.get_node_or_null("Body")
	if body_node == null:
		return
	var mounts: Array = get_meta("turret_mounts")
	var foes: Array = raid.bug_foes() if (raid != null and raid.has_method("bug_foes")) else ([target] if is_instance_valid(target) else [])
	var rate_scale: float = 0.68 if phase >= 3 else (0.82 if phase == 2 else 1.0)

	for i in mounts.size():
		var tur: Dictionary = mounts[i]
		if bool(tur.get("destroyed", false)):
			continue
		var yaw_node: Node3D = tur.get("yaw_node")
		if not is_instance_valid(yaw_node):
			continue
		var recoil_node: Node3D = tur.get("recoil_node")
		if is_instance_valid(recoil_node):
			recoil_node.position.z = move_toward(recoil_node.position.z, 0.0, delta * 1.8)

		# 各炮塔错位分配地面目标
		var foe = null
		var best_d := 40.0
		for f_idx in foes.size():
			var cand = foes[(f_idx + i) % foes.size()]
			if cand == null or not is_instance_valid(cand) or cand.dead:
				continue
			var d2: float = Vector2(cand.global_position.x - yaw_node.global_position.x, cand.global_position.z - yaw_node.global_position.z).length()
			if d2 < best_d:
				best_d = d2
				foe = cand
				if f_idx == 0 and foes.size() > 1:
					break

		var home_yaw: float = float(tur.get("home_yaw", 0.0))
		var arc_half: float = float(tur.get("arc_half", PI))
		var turn_spd: float = float(tur.get("turn_speed", 2.8))
		var can_shoot := false
		var aim_world := Vector3.ZERO

		if foe != null and is_instance_valid(foe):
			var foe_vel: Vector3 = foe.velocity if "velocity" in foe else Vector3.ZERO
			aim_world = foe.global_position + Vector3(foe_vel.x, 0.0, foe_vel.z) * 0.22 + Vector3(0.0, 1.2, 0.0)
			var local_pt: Vector3 = body_node.global_transform.affine_inverse() * aim_world
			var rel: Vector3 = local_pt - yaw_node.position
			if Vector2(rel.x, rel.z).length() > 0.2:
				var want_yaw: float = atan2(-rel.x, -rel.z)
				if arc_half < PI - 0.02:
					var diff: float = wrapf(want_yaw - home_yaw, -PI, PI)
					if absf(diff) <= arc_half + 0.20:
						can_shoot = true
					want_yaw = home_yaw + clampf(diff, -arc_half, arc_half)
				else:
					can_shoot = true
				yaw_node.rotation.y = lerp_angle(yaw_node.rotation.y, want_yaw, clampf(turn_spd * delta, 0.0, 1.0))
				if absf(wrapf(yaw_node.rotation.y - want_yaw, -PI, PI)) > 0.35:
					can_shoot = false
		else:
			yaw_node.rotation.y = lerp_angle(yaw_node.rotation.y, home_yaw, clampf(1.5 * delta, 0.0, 1.0))

		if guard_t > 0.0 or raid == null or not is_instance_valid(raid.fx):
			continue

		var burst_left: int = int(tur.get("burst_left", 0))
		if burst_left > 0:
			var bt: float = float(tur.get("burst_t", 0.0)) - delta
			tur["burst_t"] = bt
			if bt <= 0.0:
				if can_shoot and foe != null and is_instance_valid(foe):
					_fire_turret_burst(tur, aim_world)
				tur["burst_left"] = burst_left - 1
				tur["burst_t"] = 0.11
			continue

		var cd: float = float(tur.get("cd", 1.5)) - delta
		tur["cd"] = cd
		if cd <= 0.0 and can_shoot and foe != null and is_instance_valid(foe):
			var n_fired: int = int(tur.get("shots_n", 0)) + 1
			tur["shots_n"] = n_fired
			if n_fired % 4 == 0:
				var muzzles: Array = tur.get("muzzles", [])
				var mk: Node3D = muzzles[1] if muzzles.size() > 1 else (muzzles[0] if muzzles.size() > 0 else yaw_node)
				if is_instance_valid(mk):
					var lp: Vector3 = foe.global_position + Vector3(randf_range(-2.4, 2.4), 0.0, randf_range(-2.4, 2.4))
					var rk := Hazards.RocketSalvo.new()
					raid.fx.add_child(rk)
					rk.setup(raid, mk.global_position, lp, 0.96, 2.8, float(data.dmg) * 0.52, Color(0.28, 0.86, 1.0))
					Audio.play_sfx("bug_mortar_launch", mk.global_position)
				tur["cd"] = randf_range(1.7, 2.3) * rate_scale
			else:
				tur["burst_left"] = 4 if phase >= 2 else 3
				tur["burst_t"] = 0.01
				tur["cd"] = randf_range(1.15, 1.65) * rate_scale


func _spawn_aerial_slug(muzzle: Vector3, aim_pt: Vector3, speed: float, dmg_val: float, col: Color, tr_len := 10.0, tr_w := 0.42, sh_scale := 1.90) -> void:
	var diff: Vector3 = aim_pt - muzzle
	var dist3: float = maxf(diff.length(), 0.5)
	var dir3: Vector3 = diff / dist3
	var slug := Hazards.KineticSlug.new()
	raid.fx.add_child(slug)
	slug.setup(raid, muzzle, dir3, speed, dmg_val, col, tr_len, tr_w, sh_scale)
	slug.life = clampf(dist3 / maxf(speed, 8.0) + 0.18, 0.32, 1.55)
	Hazards.muzzle_flash(raid.fx, muzzle, dir3, col, sh_scale * 0.70)


func _fire_turret_burst(tur: Dictionary, aim_world: Vector3) -> void:
	if raid == null or not is_instance_valid(raid.fx):
		return
	var yaw_node: Node3D = tur.get("yaw_node")
	var muzzles: Array = tur.get("muzzles", [])
	var mk: Node3D = muzzles[0] if muzzles.size() > 0 else yaw_node
	if not is_instance_valid(mk):
		return
	var mp: Vector3 = mk.global_position
	var pt: Vector3 = aim_world + Vector3(randf_range(-0.65, 0.65), randf_range(-0.15, 0.15), randf_range(-0.65, 0.65))
	_spawn_aerial_slug(mp, pt, 29.0, float(data.dmg) * 0.32, Color(0.24, 0.90, 1.0), 10.0, 0.42, 1.90)
	ART.burst(raid.fx, mp, {"amount": 7, "life": 0.20, "size": 0.20, "vmin": 3.5, "vmax": 8.0, "spread": 32.0,
		"dir": -yaw_node.global_transform.basis.z, "c0": Color(0.55, 0.96, 1.0, 0.96), "c1": Color(0.18, 0.55, 1.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	var recoil_node: Node3D = tur.get("recoil_node")
	if is_instance_valid(recoil_node):
		recoil_node.position.z = 0.20


# ================= 母舰主轴招式 =================
func _boss_step(name: String) -> void:
	if raid == null:
		return
	var col := Color(0.28, 0.86, 1.0)
	var bomb_col := Color(1.0, 0.50, 0.16)
	var ship_pos := global_position + Vector3(0.0, maxf(hover, 4.8), 0.0)
	match name:
		"salvo":
			# 地毯式轰炸走廊：沿目标航向连续投掷高爆航弹与尾翼火箭
			Audio.play_sfx("bug_mortar_launch", ship_pos)
			var m = target
			var center_p: Vector3 = m.global_position if (m != null and is_instance_valid(m)) else (global_position + act_dir * 11.0)
			var bombs := 8 if phase >= 3 else 6
			var right_v: Vector3 = act_dir.cross(Vector3.UP).normalized()
			for i in bombs:
				var along: float = (float(i) - float(bombs - 1) * 0.5) * 2.6
				var lat: float = (-1.8 if i % 2 == 0 else 1.8) + randf_range(-0.7, 0.7)
				var lp: Vector3 = center_p + act_dir * along + right_v * lat
				var rk := Hazards.RocketSalvo.new()
				raid.fx.add_child(rk)
				rk.setup(raid, ship_pos + right_v * (lat * 0.6) - Vector3(0, 1.1, 0), lp, 0.88 + i * 0.07, 3.3, float(data.dmg) * 0.80, bomb_col)
			raid.alert_noise(global_position, 40.0)
		"hatch":
			# 前机库弹射无人机编队：啸翅拦截机 + 二阶段起混编爆浆空投舱
			Audio.play_sfx("boss_brood_hatch", ship_pos)
			var hangar_p: Vector3 = ship_pos + act_dir * 3.2
			ART.burst(raid.fx, hangar_p, {"amount": 20, "life": 0.75, "size": 0.45, "tex": ART.smoke_tex(), "additive": false,
				"spread": 75.0, "vmin": 2.5, "vmax": 7.0, "c0": Color(0.35, 0.75, 0.95, 0.65), "c1": Color(0.2, 0.3, 0.4, 0.0), "grow0": 0.5, "grow1": 1.8})
			summon("wasp", 3 if phase >= 2 else 2, 7.5)
			if phase >= 2:
				summon("bomber", 1, 6.2)
		"slug":
			Audio.play_sfx("bug_ironjaw_attack", ship_pos)
			var muzzle: Vector3 = ship_pos + act_dir * 3.4 - Vector3(0, 0.8, 0)
			var base_aim: Vector3 = target.global_position + Vector3(0, 1.2, 0) if (target != null and is_instance_valid(target)) else (global_position + act_dir * 14.0 + Vector3(0, 1.2, 0))
			for side: float in [-1.5, -0.5, 0.5, 1.5]:
				var pt: Vector3 = base_aim + act_dir.cross(Vector3.UP) * (side * 1.45)
				_spawn_aerial_slug(muzzle, pt, 31.0, float(data.dmg) * 0.74, col, 13.0, 0.54, 2.25)
			raid.shake = maxf(raid.shake, 0.34)
		"stomp":
			# 四具涡扇全推力下洗电磁冲击环
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 1.2, 0))
			raid.shake = maxf(raid.shake, 0.56)
			_ground_burst(5.2, Color(0.35, 0.72, 0.92))
			var r1 := Hazards.ShockRing.new()
			raid.fx.add_child(r1)
			r1.setup(raid, global_position, 15.5, 0.82, float(data.dmg) * 0.82, col)
			if phase >= 3:
				var r2 := Hazards.ShockRing.new()
				raid.fx.add_child(r2)
				r2.setup(raid, global_position, 21.0, 1.15, float(data.dmg) * 0.64, col)
		"core":
			open_core(10.5)
			Audio.play_sfx("boss_queen_core", ship_pos)
			ART.burst(raid.fx, ship_pos, {"amount": 24, "life": 0.88, "size": 0.32, "spread": 120.0, "vmin": 4.0, "vmax": 10.0,
				"gravity": Vector3(0, -6, 0), "c0": col, "c1": Color(0.2, 0.5, 1.0, 0.0), "grow0": 1.0, "grow1": 0.3})
