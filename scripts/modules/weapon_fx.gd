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
	var m_tung := A.metal(Color(0.22, 0.24, 0.26))
	var m_tip := A.chrome()
	var m_copper := A.paint(Color(0.84, 0.46, 0.24), 0.88, 0.28, {"panel_scale": 0.0})
	A.add(dart, A.cyl(r * 0.82, L * 0.72, r, 10), m_tung, Vector3(0, 0, L * 0.08), Vector3(90, 0, 0), Vector3.ONE, false)
	A.add(dart, A.cyl(0.005, L * 0.30, r * 0.82, 10), m_tip, Vector3(0, 0, -L * 0.42), Vector3(-90, 0, 0), Vector3.ONE, false)
	A.add(dart, A.cyl(r * 1.18, L * 0.07, r * 1.18, 10), m_copper, Vector3(0, 0, -L * 0.05), Vector3(90, 0, 0), Vector3.ONE, false)
	for fi in 4:
		A.add(dart, A.bevel_box(Vector3(r * 0.24, r * 2.4, L * 0.22), 0.002), m_tung, Vector3(0, 0, L * 0.34), Vector3(0, 0, fi * 90.0), Vector3.ONE, false)
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


## 冲击环：贴地的双层立体激波环由小撑开
static func ring(raid, p: Vector3, c: Color, radius: float, life := 0.4) -> void:
	var root := Node3D.new()
	raid.fx.add_child(root)
	root.global_position = p + Vector3(0, 0.12, 0)
	root.scale = Vector3(0.22, 0.12, 0.22)
	A.add(root, A.torus(radius * 0.86, radius, 40), A.emit(c, 4.8), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(root, A.torus(radius * 0.68, radius * 0.76, 32), A.emit(c.lightened(0.4), 3.0), Vector3(0, 0.06, 0), Vector3.ZERO, Vector3.ONE, false)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(1, 0.32, 1), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(root.queue_free)


## 落点标记：地面上的加色圆环，随飞行时间收缩
static func marker(raid, p: Vector3, c: Color, radius: float, life: float) -> Node3D:
	var n := Node3D.new()
	raid.fx.add_child(n)
	n.global_position = p + Vector3(0, 0.124, 0)
	var mi := A.add(n, A.quad(radius * 2.0, radius * 2.0), A.ground_vfx_mat(A.ring_tex(), Color(c.r, c.g, c.b, 0.85), true, 0.44, false, 4), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
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
