extends RefCounted
## 敌人留在世界里的持续危险物：酸液池、抛射酸壳、震地冲击环、晶刺地带与预警圈。
## 全部挂在 raid.fx 下，自己计时、自己收尾；伤害走 mech.take_damage / raid.explode，
## 护盾挡下、能量耗尽这些判定都由机甲自己处理。

const A = preload("res://scripts/art.gd")
const DM = preload("res://scripts/modules/device_models.gd")
const MM = preload("res://scripts/modules/munition_models.gd")
class BodyCache extends RefCounted:
	static var _body_scenes := {}


	static func _body_scene(kind: String, color: Color) -> PackedScene:
		var key := var_to_bytes([kind, color if kind != "rocket" else Color.WHITE])
		if _body_scenes.has(key): return _body_scenes[key]
		var body := Node3D.new()
		match kind:
			"lob": MM.build_lob_shell(body, color)
			"slug": MM.build_kinetic_slug(body, A.emit(color.lightened(0.28), 3.2))
			"rocket": DM.build_salvo_rocket(body)
		for node in body.find_children("*", "", true, false): node.owner = body
		var packed := PackedScene.new()
		var error := packed.pack(body)
		body.free()
		if error != OK:
			push_error("Cannot pack hazard body: %s" % kind)
			return null
		_body_scenes[key] = packed
		return packed


	static func warm_visuals() -> void:
		_body_scene("rocket", Color.WHITE)
		for c: Color in [Color(0.66, 0.95, 0.3), Color(0.6, 1.0, 0.2), Color(0.78, 0.5, 1.0), Color(0.8, 0.95, 0.35),
			Color(1.0, 0.56, 0.16), Color(0.76, 0.42, 1.0), Color(0.84, 0.32, 1.0), Color(1.0, 0.68, 0.22)]:
			_body_scene("lob", c)
		for c: Color in [Color(1.0, 0.48, 0.14), Color(0.26, 0.82, 0.92), Color(0.96, 0.66, 0.18), Color(0.28, 0.78, 0.96),
			Color(1.0, 0.56, 0.18), Color(0.32, 0.86, 0.95), Color(1.0, 0.44, 0.16), Color(1.0, 0.68, 0.24),
			Color(1.0, 0.20, 0.08), Color(1.0, 0.34, 0.09), Color(1.0, 0.54, 0.16), Color(0.28, 0.86, 1.0)]:
			_body_scene("slug", c)
		A.tactical_ring_mat(Color.WHITE)
		A.tactical_lane_mat(Color.WHITE)
		for i in 3: A.slash_arc_mesh(2.2 + i * 0.3, 0.16 - i * 0.03, 0.42)


static func warm_visuals() -> void:
	BodyCache.warm_visuals()

## 地面预警圈：贴地圆环从内向外亮起，到时自动消失。Boss 与炮击的落点在伤害前先亮这一圈。
class Mark extends Node3D:
	var life := 1.0
	var t := 0.0
	var ring: MeshInstance3D
	var _col := Color(1.0, 0.55, 0.2)

	func setup(raid, pos: Vector3, radius: float, dur: float, c := Color(1.0, 0.55, 0.2)) -> void:
		if raid != null and raid.get("coop") != null: raid.coop.emit_effect("hazard", ["mark"] + [pos, radius, dur, c])
		life = maxf(dur, 0.05)
		_col = c
		position = Vector3(pos.x, 0.05, pos.z)
		ring = A.add(self, A.quad(radius * 2.15, radius * 2.15), A.tactical_ring_mat(Color(c.r, c.g, c.b, 0.92), 0.22, 24.0, 0.44, 4), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)

	func _process(delta: float) -> void:
		t += delta
		var u: float = clampf(t / life, 0.0, 1.0)
		var mat := ring.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("progress", u)
			mat.set_shader_parameter("alpha_mul", 1.0 - smoothstep(0.86, 1.0, u))
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
	var ring_decal: MeshInstance3D
	var _pool_col := Color(0.45, 0.85, 0.12)

	func setup(r, pos: Vector3, rad: float, dur: float, dmgps: float, c := Color(0.45, 0.85, 0.12)) -> void:
		if r != null and r.get("coop") != null: r.coop.emit_effect("hazard", ["pool"] + [pos, rad, dur, dmgps, c])
		raid = r
		radius = rad
		life = dur
		dps = dmgps
		_pool_col = c
		position = Vector3(pos.x, 0.03, pos.z)
		decal = A.add(self, A.quad(radius * 2.35, radius * 2.35), A.acid_pool_mat(Color(c.r, c.g, c.b, 0.88), randf(), 0.44, 2), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		ring_decal = null
		A.emitter(self, Vector3(0, 0.14, 0), {"amount": 12, "life": 1.35, "size": 0.48, "tex": A.smoke_tex(), "additive": false, "spread": 40.0, "vmin": 0.25, "vmax": 0.95,
			"gravity": Vector3(0, 0.75, 0), "damp": 1.8, "c0": Color(c.r, c.g, c.b, 0.0), "cmid": Color(c.r, c.g, c.b, 0.34), "cmid_pos": 0.22,
			"c1": Color(c.r * 0.4, c.g * 0.5, 0.0, 0.0), "grow0": 0.5, "grow1": 1.25, "soft_depth": 0.24})
		Audio.play_sfx("hit_spit", global_position + Vector3(0, 0.3, 0))

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			var tw := create_tween()
			if decal and is_instance_valid(decal) and decal.material_override is ShaderMaterial:
				tw.tween_property(decal.material_override, "shader_parameter/alpha_mul", 0.0, 0.6)
			tw.finished.connect(queue_free)
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
		# 重工业高抛迫击炮弹（低面数整改 P0-MSL-06）：泪滴车削弹体 + 引信 + 识别/高危环 + 闭气环 + 导气孔尾管 + 后掠尾翼
		body.add_child(BodyCache._body_scene("lob", c).instantiate())
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
		A.burst(raid.fx, to + Vector3(0, 0.45, 0), {"amount": 12, "life": 0.45, "size": radius * 0.55, "vmin": radius, "vmax": radius * 1.9, "spread": 70.0,
			"gravity": Vector3(0, 3.6, 0), "damp": 5.0, "c0": Color(c.r, c.g, c.b, 0.9), "c1": Color(c.r * 0.3, c.g * 0.35, 0.0, 0.0), "grow0": 0.65, "grow1": 1.35})
		A.burst(raid.fx, to + Vector3(0, 0.38, 0), {"amount": 8, "life": 1.15, "size": radius * 0.52, "tex": A.smoke_tex(), "additive": false, "vmin": 1.0, "vmax": 2.8,
			"gravity": Vector3(0, 1.8, 0), "damp": 3.0, "c0": Color(0.18, 0.24, 0.12, 0.0), "cmid": Color(0.18, 0.24, 0.12, 0.52), "cmid_pos": 0.18, "c1": Color(0.2, 0.24, 0.14, 0.0), "grow0": 0.45, "grow1": 1.65, "soft_depth": 0.26})
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
		var ring := A.ground_vfx(self, A.shockwave_tex(), Color(c.r, c.g, c.b, 0.72), 2.0, Vector3.ZERO, false, 0.44, false, 4)
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
		# 多棱破甲地刺簇：碎石隆起基座 + 车削甲壳主刺 / 两根副刺 + 切削刃 + 熔芯
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(p) ^ i
		DM.build_spike(spk, h, color, rng)
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
		var fa: float = 0.28 if radius <= 8.0 else 0.17
		var ticks: float = 28.0 if radius > 6.0 else 18.0
		var m := A.tactical_ring_mat(Color(c.r, c.g, c.b, 0.94), fa, ticks, 0.44, 3)
		A.add(self, A.quad(radius * 2.15, radius * 2.15), m, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		mats.append(m)

	func setup_lane(raid, from: Vector3, dir: Vector3, width: float, length: float, dur: float, c := Color(1.0, 0.5, 0.18)) -> void:
		if raid != null and raid.get("coop") != null: raid.coop.emit_effect("hazard", ["telegraph_lane"] + [from, dir, width, length, dur, c])
		life = maxf(dur, 0.1)
		var d := Vector3(dir.x, 0.0, dir.z)
		if d.length() < 0.01:
			d = Vector3.FORWARD
		d = d.normalized()
		position = Vector3(from.x, 0.05, from.z)
		rotation.y = atan2(-d.x, -d.z)
		var lm := A.tactical_lane_mat(Color(c.r, c.g, c.b, 0.86), length / maxf(width, 0.1), -1.0, 0.44, 3)
		A.add(self, A.quad(width, length), lm, Vector3(0, 0, -length * 0.5), Vector3.ZERO, Vector3.ONE, false)
		mats.append(lm)

	func _process(delta: float) -> void:
		t += delta
		var u: float = clampf(t / life, 0.0, 1.0)
		var pulse: float = 0.80 + 0.20 * sin(t * 11.0)
		var fade: float = 1.0 - smoothstep(0.84, 1.0, u)
		for m: ShaderMaterial in mats:
			m.set_shader_parameter("progress", u)
			m.set_shader_parameter("alpha_mul", pulse * fade)
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
		# 高精火箭弹：卵形整流罩 + 级间法兰 + 后掠翼型尾翼 / 鸭翼 + 拉瓦尔喷管
		body.add_child(BodyCache._body_scene("rocket", c).instantiate())
		# 火箭弹长尾曳光焰带（沿弹体 -Y 尾部拖出高可视度推进火舌）
		var rk_rib := PlaneMesh.new()
		rk_rib.size = Vector2(0.34, 3.6)
		var rk_mat := KineticSlug.tracer_mat(Color(1.0, 0.56, 0.16))
		var rt1 := MeshInstance3D.new()
		rt1.mesh = rk_rib
		rt1.material_override = rk_mat
		rt1.position = Vector3(0.0, -2.25, 0.0)
		rt1.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		rt1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(rt1)
		var rt2 := MeshInstance3D.new()
		rt2.mesh = rk_rib
		rt2.material_override = rk_mat
		rt2.position = Vector3(0.0, -2.25, 0.0)
		rt2.rotation_degrees = Vector3(90.0, 90.0, 0.0)
		rt2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(rt2)
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
		var dt: Color = raid.ground_dust_tint() if raid != null and raid.has_method("ground_dust_tint") else Color(0.72, 0.66, 0.56, 1.0)
		A.burst(raid.fx, to + Vector3(0, 0.45, 0), {"amount": 18, "life": 0.42, "size": 0.22, "vmin": 5.0, "vmax": 14.0, "spread": 110.0,
			"gravity": Vector3(0, -16.0, 0), "c0": Color(1.0, 0.76, 0.32, 0.98), "c1": Color(0.95, 0.32, 0.08, 0.0), "grow0": 1.0, "grow1": 0.25})
		A.burst(raid.fx, to + Vector3(0, 0.4, 0), {"amount": 10, "life": 1.05, "size": radius * 0.52, "tex": A.smoke_tex(), "additive": false, "vmin": 1.2, "vmax": 3.4,
			"gravity": Vector3(0, 2.0, 0), "damp": 2.8, "c0": Color(0.20, 0.18, 0.17, 0.0), "cmid": Color(0.20, 0.18, 0.17, 0.56), "cmid_pos": 0.18,
			"c1": Color(0.18, 0.16, 0.15, 0.0), "grow0": 0.45, "grow1": 1.75, "soft_depth": 0.30})
		A.burst(raid.fx, to + Vector3(0, 0.22, 0), {"amount": 10, "life": 0.80, "size": radius * 0.55, "tex": A.dust_tex(), "additive": false, "flat": 0.90,
			"dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": radius * 1.4, "vmax": radius * 2.6, "gravity": Vector3(0, 0.2, 0), "damp": 6.0,
			"c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.42), "cmid_pos": 0.18, "c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0), "grow0": 0.45, "grow1": 1.65, "soft_depth": 0.22})
		var scorch := A.ground_vfx(raid.fx, A.scorch_tex(), Color(0.95, 0.92, 0.88, 0.78), radius * 2.0, Vector3(to.x, 0.093, to.z), false, 0.44, true, 2)
		scorch.rotation.y = randf() * TAU
		var stw := scorch.create_tween()
		stw.tween_interval(5.0)
		stw.tween_property(scorch.material_override, "shader_parameter/col", Color(0.95, 0.92, 0.88, 0.0), 2.5)
		stw.tween_callback(scorch.queue_free)
		Audio.play_sfx("bug_mortar_attack", to + Vector3(0, 0.5, 0))
		raid.shake = maxf(raid.shake, 0.28)
		if not Net.is_client():
			for m in raid.player_mechs():
				if not m.dead and Vector2(m.global_position.x - to.x, m.global_position.z - to.z).length() < radius + 0.55:
					m.take_damage(dmg)
		queue_free()


## 炮口制退器炽热火舌闪光：每次炮塔击发时在膛口生成短暂十字火舌与硝烟，清晰标示开火炮位
static func muzzle_flash(fx_parent: Node, pos: Vector3, dir: Vector3, c: Color, scale_k := 1.0) -> void:
	if fx_parent == null or not is_instance_valid(fx_parent):
		return
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var up_v := Vector3.UP if absf(d.y) < 0.96 else Vector3.RIGHT
	var flash := Node3D.new()
	fx_parent.add_child(flash)
	flash.global_transform = Transform3D(Basis.looking_at(d, up_v), pos)
	var fl_len: float = 1.85 * scale_k
	var fl_w: float = 0.56 * scale_k
	var pm := PlaneMesh.new()
	pm.size = Vector2(fl_w, fl_len)
	var mat := KineticSlug.tracer_mat(c)
	for rot_z: float in [0.0, 90.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mat
		mi.position = Vector3(0.0, 0.0, -fl_len * 0.48)
		mi.rotation_degrees = Vector3(0.0, 180.0, rot_z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.add_child(mi)
	var tw: Tween = flash.create_tween()
	tw.tween_property(flash, "scale", Vector3(0.25, 0.25, 1.35), 0.11)
	tw.tween_callback(flash.queue_free)


## 平射重型钨芯穿甲弹（APFSDS / 电磁钢芯实弹）：支持三维俯仰直射弹道，配备大口径实体金属弹头 + 高对比双交叉长曳光尾迹带
class KineticSlug extends Node3D:
	const SLUG_TRACER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
void fragment() {
	float tc = clamp(UV.y, 0.0, 1.0);
	float half_w = mix(1.0, 0.12, pow(clamp(tc, 1e-4, 1.0), 0.72));
	float rn = clamp(abs(UV.x - 0.5) * 2.0, 0.0, 2.0) / max(half_w, 0.01);
	if (rn > 1.0 || tc > 0.995) discard;
	float core_w = smoothstep(0.58, 0.05, rn);
	float body_w = smoothstep(0.95, 0.30, rn);
	float len_fade = pow(clamp(1.0 - tc, 1e-4, 1.0), 0.95);
	float tip_hot = smoothstep(0.38, 0.0, tc);
	vec3 hot_core = col.rgb * 2.8 + vec3(1.25) * mix(0.45, 1.0, tip_hot);
	vec3 mid_col = col.rgb * mix(2.4, 1.15, tc);
	vec3 c_out = mix(mid_col * 0.45, hot_core, core_w);
	float alpha_out = clamp(len_fade * mix(0.35, 1.0, body_w), 0.0, 1.0);
	ALBEDO = c_out * alpha_out;
	ALPHA = alpha_out;
}
"""
	static var _slug_tracer_mats := {}

	static func tracer_mat(c: Color) -> ShaderMaterial:
		var k := c.to_html()
		if not _slug_tracer_mats.has(k):
			var sh := Shader.new()
			sh.code = SLUG_TRACER_SHADER
			var sm := ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("col", c)
			_slug_tracer_mats[k] = sm
		return _slug_tracer_mats[k]

	var raid
	var vel := Vector3.ZERO
	var dmg := 28.0
	var radius := 1.05
	var life := 1.15
	var t := 0.0
	var traveled := 0.0
	var tail_node: Node3D
	var tail_len := 8.5
	var tail_offset := 0.45
	var tracer_col := Color(1.0, 0.68, 0.24)

	func setup(r, start: Vector3, dir: Vector3, speed: float, damage: float, c := Color(1.0, 0.68, 0.24), p_tracer_len := 8.5, p_tracer_w := 0.36, shell_scale := 1.45) -> void:
		raid = r
		tracer_col = c
		var d := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		vel = d * speed
		dmg = damage
		tail_len = maxf(p_tracer_len, 1.5)
		life = clampf(34.0 / maxf(speed, 8.0), 0.45, 1.55)
		var up_v := Vector3.UP if absf(d.y) < 0.96 else Vector3.RIGHT
		transform = Transform3D(Basis.looking_at(d, up_v), start)

		var body := Node3D.new()
		add_child(body)
		body.rotation_degrees.x = -90.0
		body.scale = Vector3.ONE * shell_scale
		# 放大高可视度钨合金穿甲弹芯 + 炽热发光弹头风帽与曳光药柱
		body.add_child(BodyCache._body_scene("slug", c).instantiate())

		# 双交叉高亮度长曳光尾迹（沿 +Z 弹尾随飞行距离动态拉长至 tail_len，任意俯视/平视角度均清晰醒目）
		tail_offset = 0.42 * shell_scale
		tail_node = Node3D.new()
		tail_node.visible = false
		tail_node.position = Vector3(0.0, 0.0, tail_offset)
		tail_node.scale = Vector3(1.0, 1.0, 0.01)
		add_child(tail_node)
		var rib := PlaneMesh.new()
		rib.size = Vector2(maxf(p_tracer_w, 0.12), 1.0)
		var rmat := tracer_mat(c)
		for rot_z: float in [0.0, 90.0]:
			var tm := MeshInstance3D.new()
			tm.mesh = rib
			tm.material_override = rmat
			tm.rotation_degrees = Vector3(0.0, 0.0, rot_z)
			tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tail_node.add_child(tm)

		A.emitter(self, Vector3.ZERO, {"amount": 10, "life": 0.28, "size": 0.26 * shell_scale * 0.7, "tex": A.smoke_tex(), "additive": false, "spread": 18.0, "vmin": 0.1, "vmax": 0.35,
			"gravity": Vector3(0, 0.4, 0), "c0": Color(0.32, 0.30, 0.28, 0.48), "c1": Color(0.16, 0.15, 0.14, 0.0), "grow0": 0.45, "grow1": 1.45})

	func _process(delta: float) -> void:
		if raid == null or not is_instance_valid(raid.fx):
			queue_free()
			return
		t += delta
		var step_v: Vector3 = vel * delta
		position += step_v
		traveled += step_v.length()
		if tail_node != null and is_instance_valid(tail_node):
			var cur_l: float = clampf(traveled, 0.0, tail_len)
			tail_node.visible = cur_l > 0.05
			tail_node.scale.z = maxf(cur_l, 0.02)
			tail_node.position.z = tail_offset + cur_l * 0.5
		if not Net.is_client():
			for m in raid.player_mechs():
				if not m.dead and position.y <= m.global_position.y + 4.2 and position.y >= m.global_position.y - 1.2:
					if Vector2(m.global_position.x - position.x, m.global_position.z - position.z).length() < radius + 0.65:
						m.take_damage(dmg)
						_impact()
						return
		if position.y <= 0.10 or raid._blocked(Vector3(position.x, 0.0, position.z), 0.45, false) or t >= life:
			_impact()

	func _impact() -> void:
		if raid != null and is_instance_valid(raid.fx):
			var hit_p := Vector3(position.x, maxf(position.y, 0.15), position.z)
			A.burst(raid.fx, hit_p, {"amount": 16, "life": 0.36, "size": 0.24, "vmin": 5.0, "vmax": 13.0, "spread": 105.0,
				"gravity": Vector3(0, -14.0, 0), "c0": tracer_col.lightened(0.35), "c1": Color(tracer_col.r, tracer_col.g * 0.4, 0.08, 0.0), "grow0": 1.1, "grow1": 0.2})
		queue_free()

