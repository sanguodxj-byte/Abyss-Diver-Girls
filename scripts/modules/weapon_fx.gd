extends RefCounted
## 新武器的共通表现件：光束、折线电弧、冲击环、地面标记、碎屑与瞬时点光。
## 全部挂在 raid.fx 下并自行释放，不进入物理层，也不参与碰撞。

const A = preload("res://scripts/art.gd")

const SHELL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float power = 1.0;
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float grid = smoothstep(0.002, 0.0, abs(fract(UV.y * 24.0) - 0.5) - 0.46);
	ALBEDO = col.rgb * (f * 1.4 + 0.06 + grid * 0.25) * power;
}
"""


## 双层光束：白热内芯 + 有色外层，沿局部 Z 收缩淡出
static func beam(raid, a: Vector3, b: Vector3, c: Color, w: float, life := 0.18) -> void:
	var span := a.distance_to(b)
	if span < 0.05:
		return
	var n := Node3D.new()
	raid.fx.add_child(n)
	n.global_position = (a + b) * 0.5
	n.look_at(b, Vector3.UP if abs((b - a).normalized().y) < 0.95 else Vector3.FORWARD)
	A.add(n, A.cyl(w, span, w, 8), A.emit(Color(1, 1, 1), 10.0), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	A.add(n, A.cyl(w * 3.4, span, w * 3.4, 10), A.emit(c, 3.2), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(0.1, 0.1, 1.0), life).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


## 折线电弧：两到三股随机折线，适合链式闪电
static func bolt(raid, a: Vector3, b: Vector3, c: Color, life := 0.14, w := 0.05) -> void:
	var d := b - a
	var span := d.length()
	if span < 0.2:
		return
	var n := Node3D.new()
	raid.fx.add_child(n)
	n.global_position = a
	var fwd := d.normalized()
	var up := Vector3.UP if abs(fwd.y) < 0.95 else Vector3.FORWARD
	var s1 := fwd.cross(up).normalized()
	var s2 := fwd.cross(s1).normalized()
	for strand in 3:
		var pts: Array = []
		var segs: int = maxi(3, int(span / 0.7) + 2)
		for i in segs + 1:
			var t := float(i) / segs
			var p: Vector3 = d * t
			if i > 0 and i < segs:
				var amp := sin(t * PI) * minf(0.5, span * 0.07)
				p += s1 * randf_range(-amp, amp) + s2 * randf_range(-amp, amp)
			pts.append(p)
		var r := w * (1.0 if strand == 0 else 0.45)
		A.add(n, A.tube(pts, r, 5, 4), A.emit(Color(1, 1, 1) if strand == 0 else c, 9.0 if strand == 0 else 2.6), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.55, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


## 冲击环：贴地的圆环由小撑开
static func ring(raid, p: Vector3, c: Color, radius: float, life := 0.4) -> void:
	var n := A.add(raid.fx, A.torus(radius * 0.86, radius, 40), A.emit(c, 4.0), p + Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(0.25, 0.12, 0.25), false)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(1, 0.3, 1), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(n.queue_free)


## 落点标记：地面上的加色圆环，随飞行时间收缩
static func marker(raid, p: Vector3, c: Color, radius: float, life: float) -> Node3D:
	var n := Node3D.new()
	raid.fx.add_child(n)
	n.global_position = p + Vector3(0, 0.06, 0)
	var mi := A.add(n, A.quad(radius * 2.0, radius * 2.0), A.decal_mat(A.ring_tex(), Color(c.r, c.g, c.b, 0.85), true), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	mi.rotation.x = 0.0
	mi.set_meta("ring", true)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 1.0, life * 0.75)
	tw.tween_property(n, "scale", Vector3.ONE * 0.4, life * 0.25).set_ease(Tween.EASE_IN)
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


## 能量护罩 / 力场：菲涅尔边缘发光的球壳，撑开后收缩消失
static func shell(parent: Node3D, c: Color, radius: float, dur: float, y := 1.6) -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = SHELL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("col", c)
	var mi := MeshInstance3D.new()
	mi.mesh = A.sphere(radius)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = y
	parent.add_child(mi)
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.01, dur - 0.36))
	tw.tween_property(mi, "scale", Vector3.ONE * 0.02, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi
