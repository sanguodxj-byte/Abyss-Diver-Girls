extends RefCounted
## 敌人留在世界里的持续危险物：酸液池、抛射酸壳、震地冲击环、晶刺地带与预警圈。
## 全部挂在 raid.fx 下，自己计时、自己收尾；伤害走 mech.take_damage / raid.explode，
## 护盾挡下、能量耗尽这些判定都由机甲自己处理。

const A = preload("res://scripts/art.gd")

## 地面预警圈：贴地圆环从内向外亮起，到时自动消失。Boss 与炮击的落点在伤害前先亮这一圈。
class Mark extends Node3D:
	var life := 1.0
	var t := 0.0
	var ring: MeshInstance3D

	func setup(raid, pos: Vector3, radius: float, dur: float, c := Color(1.0, 0.55, 0.2)) -> void:
		if raid != null and raid.get("coop") != null: raid.coop.emit_effect("hazard", ["mark"] + [pos, radius, dur, c])
		life = maxf(dur, 0.05)
		position = Vector3(pos.x, 0.05, pos.z)
		ring = A.ground_decal(self, A.ring_tex(), Color(c.r, c.g, c.b, 0.85), radius * 2.2, Vector3.ZERO, true)
		A.ground_decal(self, A.blob_tex(), Color(c.r, c.g, c.b, 0.22), radius * 2.0, Vector3(0, -0.01, 0), true)

	func _process(delta: float) -> void:
		t += delta
		var u: float = clampf(t / life, 0.0, 1.0)
		scale = Vector3.ONE * lerpf(1.45, 1.0, u)
		var mat := ring.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = lerpf(0.85, 0.2, u)
		if t >= life:
			queue_free()


## 酸液池：落地后持续一段时间，每隔半秒对站在里面的机甲造成伤害；会顺带把周围虫群也腐蚀一点。
class AcidPool extends Node3D:
	var raid
	var radius := 4.0
	var dps := 7.0
	var life := 8.0
	var t := 0.0
	var tick := 0.0
	var decal: MeshInstance3D

	func setup(r, pos: Vector3, rad: float, dur: float, dmgps: float, c := Color(0.45, 0.85, 0.12)) -> void:
		if r != null and r.get("coop") != null: r.coop.emit_effect("hazard", ["pool"] + [pos, rad, dur, dmgps, c])
		raid = r
		radius = rad
		life = dur
		dps = dmgps
		position = Vector3(pos.x, 0.03, pos.z)
		decal = A.ground_decal(self, A.blob_tex(), Color(c.r, c.g, c.b, 0.62), radius * 2.0, Vector3.ZERO, false)
		A.ground_decal(self, A.ring_tex(), Color(c.r, c.g, c.b, 0.35), radius * 2.4, Vector3(0, 0.01, 0), true)
		A.emitter(self, Vector3(0, 0.1, 0), {"amount": 16, "life": 1.4, "size": 0.55, "spread": 40.0, "vmin": 0.3, "vmax": 1.2,
			"gravity": Vector3(0, 0.9, 0), "damp": 1.5, "c0": Color(c.r, c.g, c.b, 0.5), "c1": Color(c.r * 0.4, c.g * 0.5, 0.0, 0.0), "grow0": 0.6, "grow1": 0.2})
		Audio.play_sfx("hit_spit", global_position + Vector3(0, 0.3, 0))

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			var tw := create_tween()
			tw.tween_property(decal, "transparency", 1.0, 0.6)
			tw.tween_callback(queue_free)
			set_process(false)
			return
		tick -= delta
		if tick > 0.0 or raid == null or not is_instance_valid(raid.mech):
			return
		tick = 0.5
		if Net.is_client(): return
		for m in raid.player_mechs():
			if not m.dead and Vector2(m.global_position.x - global_position.x, m.global_position.z - global_position.z).length() < radius:
				m.take_damage(dps * 0.5)
				A.burst(raid.fx, m.global_position + Vector3(0, 0.4, 0), {"amount": 4, "life": 0.3, "size": 0.3, "spread": 70.0, "vmin": 1.0, "vmax": 2.5,
					"gravity": Vector3(0, 3.0, 0), "c0": Color(0.6, 0.95, 0.25, 0.8), "c1": Color(0.2, 0.4, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})


## 抛射酸壳：按抛物线飞向落点，落点有预警圈；落地时同时伤到机甲与虫群。
class LobShell extends Node3D:
	var raid
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var flight := 1.4
	var radius := 3.6
	var dmg := 24.0
	var arc := 9.0
	var color := Color(0.6, 1.0, 0.2)
	var t := 0.0
	var mark
	var body: Node3D

	func setup(r, start: Vector3, landing: Vector3, dur: float, rad: float, damage: float, c := Color(0.6, 1.0, 0.2)) -> void:
		if r != null and r.get("coop") != null: r.coop.emit_effect("hazard", ["shell"] + [start, landing, dur, rad, damage, c])
		raid = r
		from = start
		to = Vector3(landing.x, 0.0, landing.z)
		flight = maxf(dur, 0.3)
		radius = rad
		dmg = damage
		color = c
		position = start
		arc = clampf(from.distance_to(to) * 0.28, 4.0, 14.0)
		body = Node3D.new()
		add_child(body)
		var m_shell := A.metal(Color(0.22, 0.25, 0.26))
		var m_rust := A.paint(Color(0.36, 0.24, 0.16), 0.48, 0.58, {"rust": 0.65})
		var m_haz := A.hazard()
		var m_band := A.paint(c.darkened(0.30), 0.38, 0.48, {"rust": 0.35, "wear": 0.3})
		var m_brass := A.paint(Color(0.86, 0.65, 0.22), 0.88, 0.28, {"panel_scale": 0.0, "wear": 0.15})
		# 重工业高抛迫击炮实体钢壳炮弹：锻钢弹体 + 收分装药风帽 + 车削黄铜碰炸引信 + 涂装识别环 + 黄黑高危环 + 尾管与四片安定钢翼
		A.add(body, A.cyl(0.18, 0.58, 0.20, 12), m_shell, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.065, 0.24, 0.18, 12), m_rust, Vector3(0, 0.39, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.022, 0.10, 0.065, 10), m_brass, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.206, 0.08, 0.206, 12), m_haz, Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.204, 0.14, 0.204, 12), m_band, Vector3(0, -0.03, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.085, 0.20, 0.13, 10), m_shell, Vector3(0, -0.36, 0), Vector3.ZERO, Vector3.ONE, false)
		for i in 4:
			var a := TAU * float(i) / 4.0
			A.add(body, A.bevel_box(Vector3(0.032, 0.24, 0.18), 0.006), m_shell, Vector3(sin(a) * 0.17, -0.34, cos(a) * 0.17), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
		A.emitter(self, Vector3.ZERO, {"amount": 14, "life": 0.55, "size": 0.42, "tex": A.smoke_tex(), "additive": false, "spread": 55.0, "vmin": 0.15, "vmax": 0.55, "gravity": Vector3(0, 0.6, 0),
			"c0": Color(0.26, 0.28, 0.24, 0.58), "c1": Color(0.18, 0.19, 0.17, 0.0), "grow0": 0.65, "grow1": 1.85})
		mark = Mark.new()
		raid.fx.add_child(mark)
		mark.setup(raid, to, radius, flight, color)

	func _process(delta: float) -> void:
		if raid == null or not is_instance_valid(raid.fx):
			queue_free()
			return
		t += delta
		var u: float = clampf(t / flight, 0.0, 1.0)
		position = from.lerp(to, u) + Vector3(0, sin(u * PI) * arc, 0)
		if body != null and is_instance_valid(body):
			var tang := ((to - from) + Vector3(0, cos(u * PI) * PI * arc, 0)).normalized()
			if tang.length_squared() > 0.01:
				var ref := Vector3.UP if absf(tang.y) < 0.94 else Vector3.RIGHT
				var bx := tang.cross(ref).normalized()
				var bz := bx.cross(tang).normalized()
				body.basis = Basis(bx, tang, bz) * Basis(Vector3.UP, t * 14.0)
		if u >= 1.0:
			_land()

	func _land() -> void:
		var c := color
		A.burst(raid.fx, to + Vector3(0, 0.5, 0), {"amount": 14, "life": 0.5, "size": radius * 0.7, "vmin": radius, "vmax": radius * 2.0, "spread": 70.0,
			"gravity": Vector3(0, 4.0, 0), "damp": 5.0, "c0": Color(c.r, c.g, c.b, 0.9), "c1": Color(c.r * 0.3, c.g * 0.35, 0.0, 0.0), "grow0": 0.7, "grow1": 1.5})
		A.burst(raid.fx, to + Vector3(0, 0.4, 0), {"amount": 8, "life": 1.2, "size": radius * 0.6, "tex": A.smoke_tex(), "additive": false, "vmin": 1.0, "vmax": 3.0,
			"gravity": Vector3(0, 2.0, 0), "damp": 3.0, "c0": Color(0.16, 0.22, 0.1, 0.7), "c1": Color(0.2, 0.24, 0.14, 0.0), "grow0": 0.5, "grow1": 1.8})
		Audio.play_sfx("bug_mortar_attack", to + Vector3(0, 0.5, 0))
		raid.shake = max(raid.shake, 0.22)
		if Net.is_client():
			queue_free()
			return
		for b in raid.get_tree().get_nodes_in_group("bugs"):
			if is_instance_valid(b) and b.global_position.distance_to(to) < radius:
				b.take_damage(dmg)
		for m in raid.player_mechs():
			if not m.dead and Vector2(m.global_position.x - to.x, m.global_position.z - to.z).length() < radius + 0.6:
				m.take_damage(dmg)
		var pool := AcidPool.new()
		raid.fx.add_child(pool)
		pool.setup(raid, to, radius * 0.8, 6.0, 6.0, color)
		queue_free()


## 震地冲击环：从原点向外扩到 radius，环锋扫过机甲时造成一次伤害。
class ShockRing extends Node3D:
	var raid
	var radius := 9.0
	var widen := 0.75
	var dmg := 26.0
	var color := Color(1.0, 0.72, 0.3)
	var t := 0.0
	var hits := {}

	func setup(r, pos: Vector3, rad: float, dur: float, damage: float, c := Color(1.0, 0.72, 0.3)) -> void:
		if r != null and r.get("coop") != null: r.coop.emit_effect("hazard", ["ring"] + [pos, rad, dur, damage, c])
		raid = r
		position = Vector3(pos.x, 0.06, pos.z)
		radius = rad
		widen = maxf(dur, 0.15)
		dmg = damage
		color = c
		var ring := A.ground_decal(self, A.ring_tex(), Color(c.r, c.g, c.b, 0.9), 2.0, Vector3.ZERO, true)
		ring.set_meta("grow", true)
		A.burst(raid.fx, pos + Vector3(0, 0.4, 0), {"amount": 20, "life": 0.6, "size": 0.5, "dir": Vector3.UP, "spread": 88.0, "vmin": 5.0, "vmax": 11.0,
			"gravity": Vector3(0, 6.0, 0), "damp": 4.0, "c0": Color(0.85, 0.78, 0.62, 0.8), "c1": Color(0.6, 0.5, 0.4, 0.0), "grow0": 1.0, "grow1": 0.4, "tex": A.smoke_tex(), "additive": false})

	func _process(delta: float) -> void:
		if raid == null or not is_instance_valid(raid.mech):
			queue_free()
			return
		t += delta
		var u: float = clampf(t / widen, 0.0, 1.0)
		var rad: float = radius * ease(u, 0.55)
		scale = Vector3.ONE * maxf(rad, 0.01)
		if not Net.is_client():
			for m in raid.player_mechs():
				var d: float = Vector2(m.global_position.x - global_position.x, m.global_position.z - global_position.z).length()
				if not m.dead and not hits.has(m.get_instance_id()) and absf(d - rad) < 1.4:
					hits[m.get_instance_id()] = true
					m.take_damage(dmg)
		if u >= 1.0:
			queue_free()


## 晶刺地带：沿一条线依次从地里刺出晶体，每个点先亮预警再出手。
class SpikeRow extends Node3D:
	var raid
	var from := Vector3.ZERO
	var dir := Vector3.FORWARD
	var count := 5
	var gap := 3.2
	var dmg := 22.0
	var color := Color(0.75, 0.35, 1.0)
	var delay := 0.12
	var t := 0.0
	var done := 0

	func setup(r, start: Vector3, direction: Vector3, n: int, spacing: float, damage: float, lead: float, c := Color(0.75, 0.35, 1.0)) -> void:
		if r != null and r.get("coop") != null: r.coop.emit_effect("hazard", ["spikes"] + [start, direction, n, spacing, damage, lead, c])
		raid = r
		from = Vector3(start.x, 0.0, start.z)
		dir = Vector3(direction.x, 0.0, direction.z).normalized()
		count = n
		gap = spacing
		dmg = damage
		delay = maxf(lead, 0.02)
		color = c
		for i in count:
			var p: Vector3 = from + dir * gap * i
			var mk := Mark.new()
			raid.fx.add_child(mk)
			mk.setup(raid, p, 1.5, delay * (i + 1) + 0.05, color)

	func _process(delta: float) -> void:
		t += delta
		while done < count and t >= delay * (done + 1):
			_thrust(done)
			done += 1
		if done >= count and t >= delay * count + 0.6:
			var tw := create_tween()
			tw.tween_interval(0.6)
			tw.tween_callback(queue_free)
			set_process(false)

	func _thrust(i: int) -> void:
		var p: Vector3 = from + dir * gap * i
		var h := 2.6 + float(i % 2) * 0.6
		var spk := Node3D.new()
		spk.position = p
		spk.rotation_degrees = Vector3(randf_range(-8, 8), randf() * 60.0, randf_range(-8, 8))
		spk.scale.y = 0.1
		add_child(spk)
		var m_jkt := A.metal(Color(0.24, 0.26, 0.29))
		var m_tip := A.emit(color, 1.5)
		m_tip.albedo_color = color.darkened(0.62)
		m_tip.roughness = 0.28
		A.add(spk, A.cyl(0.30, h * 0.54, 0.44, 6), m_jkt, Vector3(0, h * 0.27, 0))
		A.add(spk, A.cyl(0.04, h * 0.52, 0.28, 6), m_tip, Vector3(0, h * 0.74, 0))
		var tw := create_tween()
		tw.tween_property(spk, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		A.burst(raid.fx, p + Vector3(0, 0.2, 0), {"amount": 8, "life": 0.5, "size": 0.12, "vmin": 3.0, "vmax": 7.0, "gravity": Vector3(0, -16, 0),
			"c0": Color(color.r, color.g, color.b, 0.9), "c1": Color(0.2, 0.05, 0.3, 0.0), "grow0": 1.0, "grow1": 0.3})
		Audio.play_sfx("hit_chitin", p + Vector3(0, 0.6, 0))
		if not Net.is_client():
			for mech in raid.player_mechs():
				if not mech.dead and Vector2(mech.global_position.x - p.x, mech.global_position.z - p.z).length() < 1.7:
					mech.take_damage(dmg)


## 攻击前摇的地面预告：把「接下来哪一片会挨打」直接画在地上。
## 冲锋类是一条从脚下沿冲刺方向铺开的窄带，末端一圈落点环；范围类是一圈按半径铺开的环带，内圈随时间收拢。
## 前摇期间亮度脉动，出手后淡出；全部贴地、无碰撞，只做读秒提示。
class Telegraph extends Node3D:
	var life := 1.0
	var t := 0.0
	var mats: Array = []
	var inner: MeshInstance3D

	func setup_ring(raid, center: Vector3, radius: float, dur: float, c := Color(1.0, 0.55, 0.2)) -> void:
		if raid != null and raid.get("coop") != null: raid.coop.emit_effect("hazard", ["telegraph_ring"] + [center, radius, dur, c])
		life = maxf(dur, 0.1)
		position = Vector3(center.x, 0.05, center.z)
		# 大范围脉冲（支援、干扰）把填充压淡，避免整块屏幕被染色；边缘环保持亮度
		var fa: float = 0.34 if radius <= 8.0 else 0.2
		var fill := A.ground_decal(self, A.soft_dot(), Color(c.r * 0.85, c.g * 0.7, c.b * 0.55, fa), radius * 2.0, Vector3.ZERO, false)
		_reg(fill, fa)
		var glow := A.ground_decal(self, A.soft_dot(), Color(c.r, c.g, c.b, fa * 0.4), radius * 1.86, Vector3(0, 0.002, 0), true)
		_reg(glow, fa * 0.4)
		var edge := A.ground_decal(self, A.ring_tex(), Color(c.r, c.g, c.b, 0.85), radius * 2.25, Vector3(0, 0.005, 0), true)
		_reg(edge, 0.85)
		inner = A.ground_decal(self, A.ring_tex(), Color(c.r, c.g, c.b, 0.5), radius * 2.25, Vector3(0, 0.01, 0), true)
		_reg(inner, 0.5)

	func setup_lane(raid, from: Vector3, dir: Vector3, width: float, length: float, dur: float, c := Color(1.0, 0.5, 0.18)) -> void:
		if raid != null and raid.get("coop") != null: raid.coop.emit_effect("hazard", ["telegraph_lane"] + [from, dir, width, length, dur, c])
		life = maxf(dur, 0.1)
		var d := Vector3(dir.x, 0.0, dir.z)
		if d.length() < 0.01:
			d = Vector3.FORWARD
		d = d.normalized()
		position = Vector3(from.x, 0.05, from.z)
		rotation.y = atan2(-d.x, -d.z)
		var fill := A.add(self, A.quad(width, length), A.decal_mat(A.soft_dot(), Color(c.r * 0.85, c.g * 0.68, c.b * 0.5, 0.36), false),
			Vector3(0, 0, -length * 0.5), Vector3.ZERO, Vector3.ONE, false)
		_reg(fill, 0.36)
		var glow := A.add(self, A.quad(width * 0.92, length), A.decal_mat(A.soft_dot(), Color(c.r, c.g, c.b, 0.14), true),
			Vector3(0, 0.002, -length * 0.5), Vector3.ZERO, Vector3.ONE, false)
		_reg(glow, 0.14)
		for sx: float in [-1.0, 1.0]:
			var edge := A.add(self, A.quad(maxf(width * 0.06, 0.1), length), A.decal_mat(A.soft_dot(), Color(c.r, c.g, c.b, 0.8), true),
				Vector3(sx * width * 0.5, 0.006, -length * 0.5), Vector3.ZERO, Vector3.ONE, false)
			_reg(edge, 0.8)
		var end := A.ground_decal(self, A.ring_tex(), Color(c.r, c.g, c.b, 0.85), width * 1.5, Vector3(0, 0.008, -length), true)
		_reg(end, 0.85)
		for k in 3:
			var bar := A.add(self, A.quad(width * 0.55, maxf(width * 0.05, 0.08)), A.decal_mat(A.soft_dot(), Color(c.r, c.g, c.b, 0.5), true),
				Vector3(0, 0.007, -length * (0.25 + k * 0.25)), Vector3.ZERO, Vector3.ONE, false)
			_reg(bar, 0.5)

	func _reg(mi: MeshInstance3D, alpha: float) -> void:
		var m: StandardMaterial3D = mi.material_override.duplicate()
		m.albedo_color.a = alpha
		mi.material_override = m
		mats.append([m, alpha])

	func _process(delta: float) -> void:
		t += delta
		var u: float = clampf(t / life, 0.0, 1.0)
		var pulse: float = 0.62 + 0.38 * sin(t * 13.0)
		var fade: float = 1.0 - smoothstep(0.82, 1.0, u)
		for e in mats:
			var m: StandardMaterial3D = e[0]
			m.albedo_color.a = float(e[1]) * pulse * fade
		if inner and is_instance_valid(inner):
			var k: float = lerpf(1.0, 0.22, u)
			inner.scale = Vector3.ONE * k
		if t >= life:
			queue_free()


## 扬尘：钻地虫在地下的轨迹提示，一路留下淡尘与细碎土块
static func dust_trail(raid, pos: Vector3, c := Color(0.62, 0.55, 0.44)) -> void:
	if raid == null or not is_instance_valid(raid.fx):
		return
	A.burst(raid.fx, pos + Vector3(0, 0.15, 0), {"amount": 5, "life": 0.8, "size": 1.5, "tex": A.smoke_tex(), "additive": false, "spread": 70.0,
		"vmin": 0.6, "vmax": 1.6, "gravity": Vector3(0, 1.4, 0), "damp": 2.0, "c0": Color(c.r, c.g, c.b, 0.55), "c1": Color(c.r, c.g, c.b, 0.0),
		"grow0": 0.5, "grow1": 1.6})
	A.burst(raid.fx, pos + Vector3(0, 0.2, 0), {"amount": 4, "life": 0.4, "size": 0.1, "additive": false, "vmin": 2.0, "vmax": 5.0, "gravity": Vector3(0, -18, 0),
		"c0": Color(0.4, 0.35, 0.28), "c1": Color(0.35, 0.3, 0.24, 0.7), "grow0": 1.0, "grow1": 1.0})


## 军工高爆尾翼火箭弹（实体弹头）：低伸弹道高速砸向预警落点，锻钢战斗部 + 车削黄铜碰炸引信 + 十字安定钢尾翼 + 推进黑烟尾迹
class RocketSalvo extends Node3D:
	var raid
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var flight := 0.95
	var radius := 3.2
	var dmg := 26.0
	var arc := 4.8
	var color := Color(1.0, 0.52, 0.18)
	var t := 0.0
	var body: Node3D

	func setup(r, start: Vector3, landing: Vector3, dur: float, rad: float, damage: float, c := Color(1.0, 0.52, 0.18)) -> void:
		raid = r
		from = start
		to = Vector3(landing.x, 0.0, landing.z)
		flight = maxf(dur, 0.28)
		radius = rad
		dmg = damage
		color = c
		position = start
		arc = clampf(from.distance_to(to) * 0.18, 2.6, 8.5)
		body = Node3D.new()
		add_child(body)
		var m_st := A.metal(Color(0.20, 0.22, 0.24))
		var m_olive := A.paint(Color(0.28, 0.31, 0.24), 0.45, 0.52, {"rust": 0.42, "wear": 0.35})
		var m_haz := A.hazard()
		var m_brass := A.paint(Color(0.86, 0.66, 0.22), 0.88, 0.26, {"panel_scale": 0.0})
		var m_flame := A.emit(Color(1.0, 0.55, 0.16), 2.1)
		A.add(body, A.cyl(0.11, 0.72, 0.12, 12), m_olive, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.035, 0.28, 0.11, 12), m_st, Vector3(0, 0.50, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.016, 0.09, 0.035, 10), m_brass, Vector3(0, 0.68, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.125, 0.08, 0.125, 12), m_haz, Vector3(0, 0.20, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.09, 0.14, 0.065, 10), m_st, Vector3(0, -0.42, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.055, 0.10, 0.025, 8), m_flame, Vector3(0, -0.52, 0), Vector3.ZERO, Vector3.ONE, false)
		for i in 4:
			var a := TAU * float(i) / 4.0
			A.add(body, A.bevel_box(Vector3(0.026, 0.24, 0.16), 0.005), m_st, Vector3(sin(a) * 0.13, -0.32, cos(a) * 0.13), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
		A.emitter(self, Vector3.ZERO, {"amount": 16, "life": 0.48, "size": 0.36, "tex": A.smoke_tex(), "additive": false, "spread": 40.0, "vmin": 0.2, "vmax": 0.7,
			"gravity": Vector3(0, 0.8, 0), "c0": Color(0.32, 0.30, 0.28, 0.65), "c1": Color(0.16, 0.16, 0.16, 0.0), "grow0": 0.55, "grow1": 1.9})
		var mark := Mark.new()
		raid.fx.add_child(mark)
		mark.setup(raid, to, radius, flight, color)

	func _process(delta: float) -> void:
		if raid == null or not is_instance_valid(raid.fx):
			queue_free()
			return
		t += delta
		var u: float = clampf(t / flight, 0.0, 1.0)
		position = from.lerp(to, u) + Vector3(0, sin(u * PI) * arc, 0)
		if body != null and is_instance_valid(body):
			var tang := ((to - from) + Vector3(0, cos(u * PI) * PI * arc, 0)).normalized()
			if tang.length_squared() > 0.01:
				var ref := Vector3.UP if absf(tang.y) < 0.94 else Vector3.RIGHT
				var bx := tang.cross(ref).normalized()
				var bz := bx.cross(tang).normalized()
				body.basis = Basis(bx, tang, bz) * Basis(Vector3.UP, t * 20.0)
		if u >= 1.0:
			_detonate()

	func _detonate() -> void:
		A.burst(raid.fx, to + Vector3(0, 0.45, 0), {"amount": 18, "life": 0.42, "size": 0.22, "vmin": 5.0, "vmax": 14.0, "spread": 110.0,
			"gravity": Vector3(0, -16.0, 0), "c0": Color(1.0, 0.76, 0.32, 0.98), "c1": Color(0.95, 0.32, 0.08, 0.0), "grow0": 1.0, "grow1": 0.25})
		A.burst(raid.fx, to + Vector3(0, 0.4, 0), {"amount": 10, "life": 1.05, "size": radius * 0.55, "tex": A.smoke_tex(), "additive": false, "vmin": 1.2, "vmax": 3.6,
			"gravity": Vector3(0, 2.2, 0), "damp": 2.8, "c0": Color(0.22, 0.20, 0.18, 0.78), "c1": Color(0.14, 0.14, 0.14, 0.0), "grow0": 0.55, "grow1": 1.9})
		Audio.play_sfx("bug_mortar_attack", to + Vector3(0, 0.5, 0))
		raid.shake = maxf(raid.shake, 0.28)
		if not Net.is_client():
			for m in raid.player_mechs():
				if not m.dead and Vector2(m.global_position.x - to.x, m.global_position.z - to.z).length() < radius + 0.55:
					m.take_damage(dmg)
		queue_free()


## 平射重型钨芯穿甲弹（APFSDS / 电磁钢芯实弹）：沿直射弹道高速破空飞行，带弹托环、曳光底火与火药烟迹（绝非纯光束）
class KineticSlug extends Node3D:
	var raid
	var vel := Vector3.ZERO
	var dmg := 28.0
	var radius := 1.05
	var life := 1.15
	var t := 0.0

	func setup(r, start: Vector3, dir: Vector3, speed: float, damage: float, c := Color(1.0, 0.68, 0.24)) -> void:
		raid = r
		var d := Vector3(dir.x, 0.0, dir.z)
		d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
		vel = d * speed
		dmg = damage
		life = clampf(28.0 / maxf(speed, 8.0), 0.45, 1.4)
		position = start
		rotation.y = atan2(-d.x, -d.z)
		var body := Node3D.new()
		add_child(body)
		body.rotation_degrees.x = -90.0
		var m_tung := A.metal(Color(0.24, 0.26, 0.29))
		var m_brass := A.paint(Color(0.86, 0.65, 0.22), 0.90, 0.24, {"panel_scale": 0.0})
		var m_tracer := A.emit(c, 2.2)
		# 钨合金长杆穿甲弹芯 + 黄铜定心弹带 + 十字尾翼 + 尾部实体曳光药柱
		A.add(body, A.cyl(0.065, 0.78, 0.082, 10), m_tung, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.012, 0.28, 0.065, 10), m_tung, Vector3(0, 0.52, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.105, 0.09, 0.105, 10), m_brass, Vector3(0, 0.10, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(body, A.cyl(0.052, 0.08, 0.042, 8), m_tracer, Vector3(0, -0.42, 0), Vector3.ZERO, Vector3.ONE, false)
		for i in 4:
			var a := TAU * float(i) / 4.0
			A.add(body, A.bevel_box(Vector3(0.020, 0.20, 0.13), 0.004), m_tung, Vector3(sin(a) * 0.09, -0.30, cos(a) * 0.09), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
		A.emitter(self, Vector3.ZERO, {"amount": 10, "life": 0.28, "size": 0.24, "tex": A.smoke_tex(), "additive": false, "spread": 25.0, "vmin": 0.1, "vmax": 0.4,
			"gravity": Vector3(0, 0.4, 0), "c0": Color(0.38, 0.36, 0.32, 0.52), "c1": Color(0.18, 0.18, 0.18, 0.0), "grow0": 0.5, "grow1": 1.6})

	func _process(delta: float) -> void:
		if raid == null or not is_instance_valid(raid.fx):
			queue_free()
			return
		t += delta
		position += vel * delta
		if not Net.is_client():
			for m in raid.player_mechs():
				if not m.dead and Vector2(m.global_position.x - position.x, m.global_position.z - position.z).length() < radius + 0.65:
					m.take_damage(dmg)
					_impact()
					return
		if raid._blocked(Vector3(position.x, 0.0, position.z), 0.45, false) or t >= life:
			_impact()

	func _impact() -> void:
		if raid != null and is_instance_valid(raid.fx):
			A.burst(raid.fx, position, {"amount": 12, "life": 0.32, "size": 0.16, "vmin": 4.0, "vmax": 10.0, "spread": 95.0,
				"gravity": Vector3(0, -14.0, 0), "c0": Color(1.0, 0.85, 0.45, 0.95), "c1": Color(1.0, 0.4, 0.1, 0.0), "grow0": 1.0, "grow1": 0.2})
		queue_free()

