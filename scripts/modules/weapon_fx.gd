extends RefCounted
## 新武器的共通表现件：光束、折线电弧、冲击环、地面标记、碎屑与瞬时点光。
## 全部挂在 raid.fx 下并自行释放，不进入物理层，也不参与碰撞。

const A = preload("res://scripts/art.gd")
const MM = preload("res://scripts/modules/munition_models.gd")


## 重工业实体长杆穿甲箭弹高速掠过表现（取代旧版双层发光光束）
static func beam(raid, a: Vector3, b: Vector3, _c: Color, w: float, life := 0.18) -> void:
	var span := a.distance_to(b)
	if span < 0.05:
		return
	var dart := Node3D.new()
	raid.fx.add_child(dart)
	dart.global_position = a
	var fwd := (b - a) / span
	dart.look_at(b, Vector3.UP if abs(fwd.y) < 0.95 else Vector3.FORWARD)
	var r := clampf(w * 0.85, 0.024, 0.055)
	var L := clampf(r * 24.0, 0.65, 1.35)
	var body := Node3D.new()
	dart.add_child(body)
	body.rotation_degrees = Vector3(-90, 0, 0)
	var petals: Array = MM.build_apfsds_dart(body, r, L)
	# 出膛脱壳：三瓣弹托脱离箭体，向外翻滚散开后消失
	for pt in petals:
		var holder: Node3D = pt
		var gt := holder.global_transform
		holder.get_parent().remove_child(holder)
		raid.fx.add_child(holder)
		holder.global_transform = gt
		var out_dir: Vector3 = (gt.basis * Vector3(0, 0, -1)).normalized()
		var ptw := holder.create_tween()
		ptw.tween_property(holder, "global_position", gt.origin + out_dir * 0.9 - fwd * 0.6 + Vector3(0, -0.25, 0), 0.32).set_ease(Tween.EASE_OUT)
		ptw.parallel().tween_property(holder, "rotation", holder.rotation + Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0), randf_range(-2.0, 2.0)), 0.32)
		ptw.tween_callback(holder.queue_free)
	A.burst(raid.fx, a + fwd * minf(1.2, span * 0.35), {"amount": 4, "life": 0.42, "size": 0.45, "tex": A.smoke_tex(), "additive": false,
		"dir": fwd, "spread": 18.0, "vmin": 1.2, "vmax": 3.5, "gravity": Vector3(0, 0.5, 0), "damp": 3.0,
		"c0": Color(0.72, 0.70, 0.66, 0.42), "c1": Color(0.50, 0.48, 0.45, 0.0), "grow0": 0.5, "grow1": 1.7})
	var dur := clampf(span / 120.0, 0.04, maxf(life, 0.08))
	var tw := dart.create_tween()
	tw.tween_property(dart, "global_position", b, dur)
	tw.tween_callback(dart.queue_free)


## 重工业电磁钢针齐射表现（取代旧版折线电弧闪电）
static func bolt(raid, a: Vector3, b: Vector3, c: Color, life := 0.14, w := 0.05) -> void:
	beam(raid, a, b, c, w * 0.75, life)


## 冲击环：贴地有机冲击波扩散 + 微量扬尘（取代立体圆环）
static func ring(raid, p: Vector3, c: Color, radius: float, life := 0.4) -> void:
	var wave := A.ground_vfx(raid.fx, A.shockwave_tex(), Color(c.r, c.g, c.b, clampf(c.a * 0.72, 0.22, 0.72)), radius * 2.1, Vector3(p.x, 0.09, p.z), false, 0.44, true, 4)
	wave.scale = Vector3.ONE * 0.22
	var tw := wave.create_tween()
	tw.tween_property(wave, "scale", Vector3.ONE * 1.06, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(wave.material_override, "shader_parameter/col", Color(c.r, c.g, c.b, 0.0), life)
	tw.tween_callback(wave.queue_free)
	if radius >= 1.5:
		A.burst(raid.fx, p + Vector3(0, 0.25, 0), {"amount": clampi(int(radius * 3.0), 6, 16), "life": life * 1.15, "size": clampf(radius * 0.26, 0.35, 1.0),
			"tex": A.smoke_tex(), "additive": false, "spread": 85.0, "vmin": radius * 0.9, "vmax": radius * 1.8, "gravity": Vector3(0, 0.4, 0), "damp": 3.4,
			"c0": Color(c.r * 0.45 + 0.25, c.g * 0.45 + 0.24, c.b * 0.45 + 0.22, 0.32), "c1": Color(0.28, 0.26, 0.24, 0.0), "grow0": 0.45, "grow1": 1.6})


## 落点标记：地面战术破损角标（取代实心圆环）
static func marker(raid, p: Vector3, c: Color, radius: float, life: float) -> Node3D:
	var n := Node3D.new()
	raid.fx.add_child(n)
	n.global_position = p + Vector3(0, 0.124, 0)
	var mi := A.add(n, A.quad(radius * 2.0, radius * 2.0), A.extract_pad_mat(Color(c.r, c.g, c.b, 0.76), 0.44, 4), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	mi.rotation.x = 0.0
	mi.set_meta("ring", true)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 1.0, life * 0.75)
	tw.tween_property(n, "scale", Vector3.ONE * 0.45, life * 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)
	return n


## 碎屑：钻头、迫击炮落点的岩石与金属屑
static func chips(raid, p: Vector3, n := 14, c := Color(0.42, 0.4, 0.37), dir := Vector3.UP) -> void:
	A.burst(raid.fx, p, {"amount": n, "life": 0.6, "size": 0.1, "additive": false, "dir": dir, "spread": 70.0, "vmin": 3.0, "vmax": 8.0,
		"gravity": Vector3(0, -20, 0), "damp": 0.8, "c0": c, "c1": Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, 0.0), "grow0": 1.0, "grow1": 0.6})


## 瞬时点光（跟随位置，寿命结束自动释放）
static func light(raid, p: Vector3, c: Color, energy := 3.0, rng := 5.0, dur := 0.12) -> void:
	if raid.has_method("_flash_light"):
		raid._flash_light(p, c, energy, rng, dur)
		return
	var l := OmniLight3D.new()
	l.light_volumetric_fog_energy = 0.0
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	raid.fx.add_child(l)
	l.global_position = p
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


## 反应力场弧片：局部开放电离偏导弧片 + 脉冲激涌，避免塑料整球
static func shell(parent: Node3D, c: Color, radius: float, dur: float, y := 1.6) -> MeshInstance3D:
	var mat := A.aegis_shield_mat(Color(c.r, c.g, c.b, 0.88))
	mat.set_shader_parameter("surge", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = A.aegis_shield_mesh(clampf(radius * 0.76, 0.9, 2.2), clampf(radius * 0.84, 1.0, 2.3), 8, 32)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = y
	parent.add_child(mi)
	mi.scale = Vector3.ONE * 0.55
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "shader_parameter/surge", 0.15, 0.25)
	tw.tween_interval(maxf(0.01, dur - 0.36))
	tw.tween_property(mat, "shader_parameter/fade", 0.0, 0.22)
	tw.tween_callback(mi.queue_free)
	return mi
