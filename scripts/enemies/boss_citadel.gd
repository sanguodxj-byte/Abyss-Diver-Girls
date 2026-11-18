extends "res://scripts/enemies/boss.gd"
## 超重型六足陆地巡洋舰首领（citadel_behemoth · 六足要塞·陆地巡洋舰）：
##   - 体型为主角机甲 4.5 倍以上（总高约 12.8m），由六条重型双缸液压巨足驱动三角交替步态；
##   - 舰体搭载 5 座独立火控炮台（1 座顶置双联攻城主炮 + 4 座四角旋转副炮塔），可同时独立索敌、转向预判、交替倾泻钨芯机炮与尾翼火箭；
##   - 三阶段前甲防爆闸门向两侧开启，暴露内凹反应堆晶核。

const ModularGlb = preload("res://scripts/enemies/boss_modular_glb.gd")

var _turret_ready := false


func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	activation = 42.0
	summon_cap = 8
	weak_core = float(data.get("weak_core", 2.8))
	charge_speed = float(data.get("charge_speed", 13.5))
	charge_time = float(data.get("charge_time", 0.68))
	_fit_giant_collider(17.6)


func _fit_giant_collider(h_val: float) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			var sh := CylinderShape3D.new()
			sh.radius = float(data.radius)
			sh.height = h_val
			c.shape = sh
			c.position.y = h_val * 0.5


func roar_id() -> String:
	return "boss_king_roar"


func _physics_tick(delta: float) -> void:
	super._physics_tick(delta)
	if awake and not dying and hp > 0.0:
		_tick_turrets(delta)


func take_damage(dmg: float, from := Vector3.ZERO, ap := 0.0) -> void:
	var has_hp_meta: bool = has_meta("last_hit_pos")
	var hit_p: Vector3 = get_meta("last_hit_pos") if has_hp_meta else Vector3.ZERO
	if has_hp_meta:
		remove_meta("last_hit_pos")
	super.take_damage(dmg, from, ap)
	if has_hp_meta and awake and not dying and hp > 0.0 and guard_t <= 0.0:
		_damage_sub_turret_at(hit_p, dmg)


func _damage_sub_turret_at(hit_p: Vector3, raw_dmg: float) -> void:
	if not has_meta("turret_mounts"):
		return
	var mounts: Array = get_meta("turret_mounts")
	var best_idx := -1
	var best_d := 7.2
	for i in mounts.size():
		var tur: Dictionary = mounts[i]
		if str(tur.get("role", "")) != "sub" or bool(tur.get("destroyed", false)):
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
		hit_tur["part_hp"] = clampf(float(data.hp) * 0.042, 180.0, 950.0)
	var cur_p: float = float(hit_tur["part_hp"]) - raw_dmg
	hit_tur["part_hp"] = cur_p
	if cur_p > 0.0:
		ModularGlb.flash_turret_visual(self, hit_tur)
	else:
		_destroy_sub_turret(hit_tur)


func _destroy_sub_turret(tur: Dictionary) -> void:
	tur["destroyed"] = true
	tur["burst_left"] = 0
	ModularGlb.wreck_turret_visual(self, tur)
	var yn: Node3D = tur.get("yaw_node")
	var tp: Vector3 = yn.global_position + Vector3(0.0, 1.2, 0.0) if is_instance_valid(yn) else (global_position + Vector3(0.0, 8.0, 0.0))
	Audio.play_sfx("bug_mech_beetle_death", tp)
	if raid != null and is_instance_valid(raid.fx):
		raid.explode_fx(tp, 4.4, Color(1.0, 0.45, 0.12))
		ART.burst(raid.fx, tp, {"amount": 24, "life": 0.72, "size": 0.28, "spread": 135.0, "vmin": 6.0, "vmax": 16.0,
			"gravity": Vector3(0.0, -16.0, 0.0), "c0": Color(1.0, 0.85, 0.35, 1.0), "c1": Color(0.95, 0.25, 0.05, 0.0), "grow0": 1.1, "grow1": 0.2})
		raid.shake = maxf(raid.shake, 0.54)
	if hp > 1.0:
		hp = maxf(1.0, hp - float(data.hp) * 0.035)
		_check_phase()


func _on_wind() -> void:
	super._on_wind()
	if raid == null:
		return
	match _next_step():
		"slug":
			_telegraph_lane(28.0, float(data.radius) * 1.45, windup_t + 0.58, Color(1.0, 0.56, 0.18))
		"salvo":
			_telegraph_ring(float(data.range) + 4.2, windup_t + 0.60, Color(1.0, 0.44, 0.16))


func _act_enter(name: String) -> void:
	if name == "slug" or name == "salvo":
		step_len = act_t
		_boss_step(name)
		return
	super._act_enter(name)


func _on_phase(p: int) -> void:
	if p == 2:
		atk_cd = minf(atk_cd, 0.55)
	elif p >= 3:
		atk_cd = minf(atk_cd, 0.28)
		open_core(12.5)
		if raid:
			Audio.play_sfx("boss_king_core", global_position + Vector3(0, 4.2, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 4.2, 0), {"amount": 32, "life": 0.95, "size": 0.38, "spread": 120.0, "vmin": 5.0, "vmax": 13.0,
				"gravity": Vector3(0, -12, 0), "c0": Color(0.32, 0.92, 1.0, 1.0), "c1": Color(0.15, 0.45, 0.95, 0.0), "grow0": 1.0, "grow1": 0.3})


func _think(_delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	if not valid or act != "":
		return Vector3.ZERO
	var fwd: Vector3 = to / maxf(d, 0.01)
	if not _in_player_view(d) and d > 24.0:
		return fwd * 0.90
	if atk_cd > 0.0:
		if d > float(data.range) + 1.5:
			return fwd * 0.80
		if d < 7.2:
			return -fwd * 0.25
		return fwd.cross(Vector3.UP) * strafe * 0.36
	atk_cd = float(data.rate) * (0.68 if phase >= 2 else 0.92)
	pattern_i += 1
	if phase <= 1:
		match pattern_i % 3:
			0: _start_act([["wind", 0.92], ["stomp", 0.38], ["recover", 0.82]], fwd)
			1: _start_act([["wind", 0.94], ["salvo", 0.40], ["recover", 0.84]], fwd)
			_: _start_act([["wind", 0.90], ["slug", 0.36], ["recover", 0.80]], fwd)
	elif phase == 2:
		match pattern_i % 4:
			0: _start_act([["wind", 0.86], ["charge", charge_time], ["strike", 0.26], ["stomp", 0.34], ["recover", 0.84]], fwd)
			1: _start_act([["wind", 0.86], ["slug", 0.34], ["recover", 0.38], ["spike", 0.32], ["recover", 0.76]], fwd)
			2: _start_act([["wind", 0.84], ["summon", 0.40], ["recover", 0.74]], fwd)
			_: _start_act([["wind", 0.88], ["salvo", 0.38], ["recover", 0.78]], fwd)
	else:
		match pattern_i % 4:
			0: _start_act([["wind", 0.76], ["salvo", 0.36], ["recover", 0.36], ["stomp", 0.32], ["recover", 0.68]], fwd)
			1: _start_act([["wind", 0.74], ["core", 0.48], ["recover", 0.64]], fwd)
			2: _start_act([["wind", 0.76], ["charge", charge_time], ["strike", 0.24], ["slug", 0.32], ["recover", 0.70]], fwd)
			_: _start_act([["wind", 0.76], ["summon", 0.36], ["spike", 0.32], ["recover", 0.72]], fwd)
	return Vector3.ZERO


# ================= 5 座独立火控炮台系统 =================
func _pick_turret_target(tur: Dictionary, body_node: Node3D):
	if raid == null:
		return target
	var foes: Array = raid.bug_foes() if raid.has_method("bug_foes") else ([raid.mech] if is_instance_valid(raid.mech) else [])
	var yaw_node: Node3D = tur.get("yaw_node")
	if not is_instance_valid(yaw_node):
		return null
	var origin: Vector3 = yaw_node.global_position
	var home_yaw: float = float(tur.get("home_yaw", 0.0))
	var arc_half: float = float(tur.get("arc_half", PI))
	var home_dir_world: Vector3 = (-body_node.global_transform.basis.z).rotated(Vector3.UP, home_yaw).normalized()

	var best = null
	var best_score := 99999.0
	for f in foes:
		if f == null or not is_instance_valid(f) or f.dead:
			continue
		var v: Vector3 = f.global_position - origin
		var dist2d: float = Vector2(v.x, v.z).length()
		if dist2d > 54.0 or dist2d < 1.2:
			continue
		var dir2d: Vector3 = Vector3(v.x, 0.0, v.z).normalized()
		var ang: float = acos(clampf(home_dir_world.dot(dir2d), -1.0, 1.0))
		# 超出射界的副炮优先选射界内目标；主炮 360° 全向索敌
		var penalty: float = 0.0 if ang <= arc_half else (ang - arc_half) * 32.0
		var score: float = dist2d + penalty
		if score < best_score:
			best_score = score
			best = f
	return best


func _tick_turrets(delta: float) -> void:
	if not has_meta("turret_mounts") or not is_instance_valid(visual):
		return
	var body_node: Node3D = visual.get_node_or_null("Body")
	if body_node == null:
		return
	var mounts: Array = get_meta("turret_mounts")
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

		var foe = _pick_turret_target(tur, body_node)
		var home_yaw: float = float(tur.get("home_yaw", 0.0))
		var arc_half: float = float(tur.get("arc_half", PI))
		var turn_spd: float = float(tur.get("turn_speed", 2.4))
		var can_shoot := false
		var aim_world := Vector3.ZERO

		if foe != null and is_instance_valid(foe):
			var foe_vel: Vector3 = foe.velocity if "velocity" in foe else Vector3.ZERO
			aim_world = foe.global_position + Vector3(foe_vel.x, 0.0, foe_vel.z) * 0.24 + Vector3(0.0, 1.25, 0.0)
			var local_pt: Vector3 = body_node.global_transform.affine_inverse() * aim_world
			var rel: Vector3 = local_pt - yaw_node.position
			if Vector2(rel.x, rel.z).length() > 0.2:
				var want_yaw: float = atan2(-rel.x, -rel.z)
				if arc_half < PI - 0.02:
					var diff: float = wrapf(want_yaw - home_yaw, -PI, PI)
					if absf(diff) <= arc_half + 0.18:
						can_shoot = true
					want_yaw = home_yaw + clampf(diff, -arc_half, arc_half)
				else:
					can_shoot = true
				yaw_node.rotation.y = lerp_angle(yaw_node.rotation.y, want_yaw, clampf(turn_spd * delta, 0.0, 1.0))
				var align_err: float = absf(wrapf(yaw_node.rotation.y - want_yaw, -PI, PI))
				if align_err > 0.32:
					can_shoot = false
		else:
			yaw_node.rotation.y = lerp_angle(yaw_node.rotation.y, home_yaw, clampf(1.5 * delta, 0.0, 1.0))

		if guard_t > 0.0 or raid == null or not is_instance_valid(raid.fx):
			continue

		var role := str(tur.get("role", "sub"))
		if role == "main":
			var wind_rem: float = float(tur.get("wind_rem", 0.0))
			if wind_rem > 0.0:
				wind_rem -= delta
				tur["wind_rem"] = wind_rem
				if wind_rem <= 0.0 and foe != null and is_instance_valid(foe):
					_fire_main_turret(tur, aim_world)
					tur["cd"] = randf_range(2.6, 3.3) * rate_scale
				continue
			var cd: float = float(tur.get("cd", 2.0)) - delta
			tur["cd"] = cd
			if cd <= 0.0 and can_shoot:
				tur["wind_rem"] = 0.52
				var barrel_fwd: Vector3 = -yaw_node.global_transform.basis.z
				barrel_fwd.y = 0.0
				if barrel_fwd.length() > 0.01:
					var tg := Hazards.Telegraph.new()
					raid.fx.add_child(tg)
					tg.setup_lane(raid, Vector3(yaw_node.global_position.x, 0.0, yaw_node.global_position.z), barrel_fwd.normalized(), 2.4, 34.0, 0.56, Color(1.0, 0.46, 0.14))
				Audio.play_sfx("bug_mech_beetle_windup", yaw_node.global_position)
		else:
			var burst_left: int = int(tur.get("burst_left", 0))
			if burst_left > 0:
				var bt: float = float(tur.get("burst_t", 0.0)) - delta
				tur["burst_t"] = bt
				if bt <= 0.0:
					if can_shoot and foe != null and is_instance_valid(foe):
						_fire_sub_autocannon(tur, aim_world)
					tur["burst_left"] = burst_left - 1
					tur["burst_t"] = 0.11
				continue
			var scd: float = float(tur.get("cd", 1.4)) - delta
			tur["cd"] = scd
			if scd <= 0.0 and can_shoot and foe != null and is_instance_valid(foe):
				var shots_fired: int = int(tur.get("shots_n", 0)) + 1
				tur["shots_n"] = shots_fired
				if shots_fired % 4 == 0:
					_fire_sub_rocket(tur, foe.global_position)
					tur["cd"] = randf_range(1.6, 2.2) * rate_scale
				else:
					tur["burst_left"] = 4 if phase >= 2 else 3
					tur["burst_t"] = 0.01
					tur["cd"] = randf_range(1.05, 1.55) * rate_scale


func _spawn_aimed_slug(muzzle: Vector3, aim_pt: Vector3, speed: float, dmg_val: float, col: Color, tr_len := 10.5, tr_w := 0.44, sh_scale := 1.95) -> void:
	var diff: Vector3 = aim_pt - muzzle
	var dist3: float = maxf(diff.length(), 0.5)
	var dir3: Vector3 = diff / dist3
	var slug := Hazards.KineticSlug.new()
	raid.fx.add_child(slug)
	slug.setup(raid, muzzle, dir3, speed, dmg_val, col, tr_len, tr_w, sh_scale)
	slug.life = clampf(dist3 / maxf(speed, 8.0) + 0.18, 0.32, 1.60)
	Hazards.muzzle_flash(raid.fx, muzzle, dir3, col, sh_scale * 0.72)


func _fire_main_turret(tur: Dictionary, aim_world: Vector3) -> void:
	if raid == null or not is_instance_valid(raid.fx):
		return
	var yaw_node: Node3D = tur.get("yaw_node")
	var muzzles: Array = tur.get("muzzles", [])
	# 采用深绯红高对比曳光弹色，与土黄色沙漠背景彻底拉开色相层次
	var col := Color(1.0, 0.20, 0.08)
	Audio.play_sfx("bug_ironjaw_attack", yaw_node.global_position)
	for m in muzzles:
		var mk := m as Node3D
		if not is_instance_valid(mk):
			continue
		var mp: Vector3 = mk.global_position
		_spawn_aimed_slug(mp, aim_world, 34.0, float(data.dmg) * 0.68, col, 15.5, 0.68, 2.75)
		ART.burst(raid.fx, mp, {"amount": 14, "life": 0.34, "size": 0.36, "vmin": 5.0, "vmax": 13.0, "spread": 42.0,
			"dir": -yaw_node.global_transform.basis.z, "c0": Color(1.0, 0.62, 0.28, 0.98), "c1": Color(0.95, 0.16, 0.05, 0.0), "grow0": 1.1, "grow1": 0.25})
	var recoil_node: Node3D = tur.get("recoil_node")
	if is_instance_valid(recoil_node):
		recoil_node.position.z = 0.52
	raid.shake = maxf(raid.shake, 0.36)


func _fire_sub_autocannon(tur: Dictionary, aim_world: Vector3) -> void:
	if raid == null or not is_instance_valid(raid.fx):
		return
	var yaw_node: Node3D = tur.get("yaw_node")
	var muzzles: Array = tur.get("muzzles", [])
	var mk: Node3D = muzzles[0] if muzzles.size() > 0 else yaw_node
	if not is_instance_valid(mk):
		return
	var mp: Vector3 = mk.global_position
	var spread_pt: Vector3 = aim_world + Vector3(randf_range(-0.75, 0.75), randf_range(-0.2, 0.2), randf_range(-0.75, 0.75))
	_spawn_aimed_slug(mp, spread_pt, 29.0, float(data.dmg) * 0.30, Color(1.0, 0.34, 0.09), 10.5, 0.44, 1.95)
	ART.burst(raid.fx, mp, {"amount": 7, "life": 0.22, "size": 0.22, "vmin": 3.5, "vmax": 8.5, "spread": 35.0,
		"dir": -yaw_node.global_transform.basis.z, "c0": Color(1.0, 0.90, 0.50, 0.96), "c1": Color(1.0, 0.45, 0.12, 0.0), "grow0": 1.0, "grow1": 0.2})
	var recoil_node: Node3D = tur.get("recoil_node")
	if is_instance_valid(recoil_node):
		recoil_node.position.z = 0.22


func _fire_sub_rocket(tur: Dictionary, target_ground: Vector3) -> void:
	if raid == null or not is_instance_valid(raid.fx):
		return
	var yaw_node: Node3D = tur.get("yaw_node")
	var muzzles: Array = tur.get("muzzles", [])
	var mk: Node3D = muzzles[1] if muzzles.size() > 1 else (muzzles[0] if muzzles.size() > 0 else yaw_node)
	if not is_instance_valid(mk):
		return
	var mp: Vector3 = mk.global_position
	var lp: Vector3 = target_ground + Vector3(randf_range(-2.2, 2.2), 0.0, randf_range(-2.2, 2.2))
	var rk := Hazards.RocketSalvo.new()
	raid.fx.add_child(rk)
	rk.setup(raid, mp, lp, 1.02, 2.9, float(data.dmg) * 0.50, Color(1.0, 0.48, 0.16))
	Audio.play_sfx("bug_mortar_launch", mp)
	var recoil_node: Node3D = tur.get("recoil_node")
	if is_instance_valid(recoil_node):
		recoil_node.position.z = 0.24


# ================= 船体主轴招式 =================
func _boss_step(name: String) -> void:
	if raid == null:
		return
	var sc := float(data.scale)
	var col := Color(1.0, 0.54, 0.16)
	match name:
		"slug":
			Audio.play_sfx("bug_ironjaw_attack", global_position + Vector3(0, 4.5, 0))
			var muzzle := global_position + Vector3(0, 5.2, 0) + act_dir * 6.2
			var base_aim: Vector3 = target.global_position + Vector3(0, 1.2, 0) if (target != null and is_instance_valid(target)) else (global_position + act_dir * 18.0 + Vector3(0, 1.2, 0))
			for side: float in [-1.0, 0.0, 1.0]:
				var pt: Vector3 = base_aim + act_dir.cross(Vector3.UP) * (side * 2.4)
				_spawn_aimed_slug(muzzle, pt, 31.0, float(data.dmg) * 0.80, col, 13.5, 0.56, 2.35)
			raid.shake = maxf(raid.shake, 0.40)
		"salvo":
			Audio.play_sfx("bug_mortar_launch", global_position + Vector3(0, 6.0, 0))
			var m = target
			if m == null or not is_instance_valid(m):
				return
			var shots := 8 if phase >= 3 else 6
			for i in shots:
				var a := TAU * float(i) / float(shots) + randf_range(-0.16, 0.16)
				var lp: Vector3 = m.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.2, 8.8)
				var rk := Hazards.RocketSalvo.new()
				raid.fx.add_child(rk)
				rk.setup(raid, global_position + Vector3(cos(a) * 3.2, 7.6, sin(a) * 3.2), lp, 1.08 + i * 0.06, 3.5, float(data.dmg) * 0.78, col)
			raid.alert_noise(global_position, 42.0)
		"spike":
			Audio.play_sfx("hit_chitin", global_position)
			var base: Vector3 = global_position + Vector3(0, 0.2, 0)
			var fans := 3 if phase >= 2 else 2
			for k in fans:
				var ang: float = (float(k) - float(fans - 1) * 0.5) * 0.44
				var dir: Vector3 = act_dir.rotated(Vector3.UP, ang).normalized()
				var row := Hazards.SpikeRow.new()
				raid.fx.add_child(row)
				row.setup(raid, base + dir * 4.2, dir, 7, 2.8, float(data.dmg) * 0.80, 0.12, col)
		"stomp":
			Audio.play_sfx("boss_king_stomp", global_position + Vector3(0, 0.8, 0))
			raid.shake = maxf(raid.shake, 0.76)
			_ground_burst(8.5, Color(0.76, 0.66, 0.52))
			var r1 := Hazards.ShockRing.new()
			raid.fx.add_child(r1)
			r1.setup(raid, global_position, 22.5, 0.92, float(data.dmg) * 0.85, col)
			if phase >= 2:
				var r2 := Hazards.ShockRing.new()
				raid.fx.add_child(r2)
				r2.setup(raid, global_position, 29.5, 1.28, float(data.dmg) * 0.65, col)
		"summon":
			summon("mech_beetle", 2, 9.0)
			if phase >= 3:
				summon("shielder", 1, 8.5)
		"core":
			open_core(10.5)
			Audio.play_sfx("boss_king_core", global_position + Vector3(0, 4.2, 0))
			ART.burst(raid.fx, global_position + Vector3(0, 4.2, 0), {"amount": 26, "life": 0.90, "size": 0.34, "spread": 120.0, "vmin": 4.0, "vmax": 11.0,
				"gravity": Vector3(0, -10, 0), "c0": Color(0.32, 0.92, 1.0, 1.0), "c1": Color(0.20, 0.55, 1.0, 0.0), "grow0": 1.0, "grow1": 0.3})
