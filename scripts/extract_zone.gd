extends Node3D
## 撤离区：固定撤离点 或 运输机接应点。站在圈内持续读条即可撤离。

const A = preload("res://scripts/art.gd")

var title := Loc.t("撤离点", "Extraction Point")
var radius := 4.5
var need := 8.0
var active := true
var is_transport := false
var pillar: MeshInstance3D
var ring: MeshInstance3D
var label: Label3D
var beacon: OmniLight3D
var color := Color(0.3, 1.0, 0.5)


func set_title(t: String) -> void:
	title = t
	if label != null and is_instance_valid(label):
		label.text = t


func setup(t: String, c: Color, req: float, transport := false) -> void:
	title = t
	color = c
	need = req
	is_transport = transport
	add_to_group("extracts")
	A.ground_vfx(self, A.ring_tex(), Color(c.r, c.g, c.b, 0.48), radius * 2.0, Vector3(0, 0.115, 0), true, 0.44, false, 3)
	ring = A.add(self, A.torus(radius - 0.12, radius, 48), A.emit(c, 2.2), Vector3(0, 0.145, 0), Vector3.ZERO, Vector3(1, 0.15, 1), false)
	# 光柱：自下而上渐隐
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	gt.width = 4
	gt.height = 64
	var pm := StandardMaterial3D.new()
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.albedo_texture = gt
	pm.albedo_color = Color(c.r, c.g, c.b, 0.8)
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pillar = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.95
	cm.bottom_radius = radius * 0.95
	cm.height = 18.0
	cm.radial_segments = 32
	cm.cap_top = false
	cm.cap_bottom = false
	pillar.mesh = cm
	pillar.material_override = pm
	pillar.position.y = 9.0
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pillar)
	A.emitter(self, Vector3(0, 0.3, 0), {"amount": 30, "life": 2.5, "size": 0.15, "box": Vector3(radius * 0.8, 0.1, radius * 0.8), "dir": Vector3.UP, "spread": 5.0,
		"vmin": 1.5, "vmax": 3.5, "gravity": Vector3.ZERO, "c0": Color(c.r, c.g, c.b, 0.9), "c1": Color(c.r, c.g, c.b, 0.0), "grow0": 1.0, "grow1": 0.3})
	if not transport:
		# 重工野战战术应答信标塔：倒角钢筋混凝土锚固基座 + 野战通信配电箱 + 斜撑钢构桅杆 + 防护笼光学信标头
		var bx := radius + 1.15
		var M_CON := A.concrete(Color(0.48, 0.46, 0.43), false)
		var M_ST := A.metal(Color(0.24, 0.25, 0.26))
		var M_DARK := A.metal(Color(0.13, 0.14, 0.15))
		var M_CAB := A.paint(Color(0.32, 0.35, 0.27), 0.35, 0.58, {"wear": 0.48, "rust": 0.45})
		A.add(self, A.bevel_box(Vector3(1.65, 0.28, 1.65), 0.06), M_CON, Vector3(bx, 0.14, 0))
		A.add(self, A.bevel_box(Vector3(1.10, 0.14, 1.10), 0.03), M_DARK, Vector3(bx, 0.33, 0))
		A.add(self, A.bevel_box(Vector3(0.68, 0.86, 0.54), 0.035), M_CAB, Vector3(bx - 0.36, 0.78, 0.34))
		A.add(self, A.bevel_box(Vector3(0.72, 0.05, 0.58), 0.012), M_DARK, Vector3(bx - 0.36, 1.22, 0.34))
		A.add(self, A.cyl(0.09, 4.9, 0.16, 12), M_ST, Vector3(bx, 2.78, 0))
		for ga in [0.0, 120.0, 240.0]:
			var gr := deg_to_rad(ga)
			var gp := Vector3(bx + cos(gr) * 0.46, 0.36, sin(gr) * 0.46)
			var tp := Vector3(bx + cos(gr) * 0.11, 2.25, sin(gr) * 0.11)
			A.add(self, A.tube([gp, tp], 0.032, 6, 2), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		for hy in [1.9, 3.4, 4.7]:
			A.add(self, A.cyl(0.15, 0.08, 0.15, 12), M_DARK, Vector3(bx, hy, 0))
		A.add(self, A.bevel_box(Vector3(0.92, 0.06, 0.06), 0.01), M_ST, Vector3(bx, 4.45, 0))
		for sx in [-0.42, 0.42]:
			A.add(self, A.cyl(0.018, 0.75, 0.012, 8), M_ST, Vector3(bx + sx, 4.82, 0))
		# 顶置防撞钢护笼与高亮度战术光学信标芯
		A.add(self, A.cyl(0.26, 0.10, 0.22, 14), M_DARK, Vector3(bx, 5.22, 0))
		A.add(self, A.cyl(0.17, 0.44, 0.17, 14), A.emit(c, 4.2), Vector3(bx, 5.50, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(self, A.cyl(0.27, 0.07, 0.24, 14), M_DARK, Vector3(bx, 5.76, 0))
		for ca in [0.0, 90.0, 180.0, 270.0]:
			var cr := deg_to_rad(ca)
			A.add(self, A.bevel_box(Vector3(0.03, 0.52, 0.03), 0.005), M_ST, Vector3(bx + cos(cr) * 0.23, 5.50, sin(cr) * 0.23))
	else:
		# 运输艇临时机降区：四角投掷式战术地面频闪信标桩 + 中央金属 H 字机降标线板
		var M_PAD := A.metal(Color(0.16, 0.17, 0.18))
		var M_HAZ := A.hazard()
		var m_stb := A.emit(c, 3.2)
		m_stb.albedo_color = c.darkened(0.4)
		for hx_s in [-1.15, 1.15]:
			A.add(self, A.bevel_box(Vector3(0.36, 0.04, 2.80), 0.01), M_HAZ, Vector3(hx_s, 0.115, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(self, A.bevel_box(Vector3(1.98, 0.036, 0.36), 0.01), M_HAZ, Vector3(0, 0.112, 0), Vector3.ZERO, Vector3.ONE, false)
		for ca in [45.0, 135.0, 225.0, 315.0]:
			var cr := deg_to_rad(ca)
			var pr := radius + 0.35
			var bp := Vector3(cos(cr) * pr, 0, sin(cr) * pr)
			A.add(self, A.cyl(0.34, 0.12, 0.42, 8), M_PAD, bp + Vector3(0, 0.06, 0))
			A.add(self, A.cyl(0.20, 0.28, 0.24, 8), M_HAZ, bp + Vector3(0, 0.24, 0))
			A.add(self, A.cyl(0.13, 0.20, 0.13, 10), m_stb, bp + Vector3(0, 0.46, 0), Vector3.ZERO, Vector3.ONE, false)
			A.add(self, A.cyl(0.18, 0.05, 0.16, 10), M_PAD, bp + Vector3(0, 0.57, 0))
			A.add(self, A.cyl(0.015, 0.85, 0.022, 6), M_PAD, bp + Vector3(cos(cr) * 0.12, 0.72, sin(cr) * 0.12), Vector3.ZERO, Vector3.ONE, false)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 2.0
	l.omni_range = radius * 2.4
	l.position = Vector3(0, 2.0, 0)
	add_child(l)
	beacon = l
	label = Label3D.new()
	label.text = t
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.pixel_size = 0.02
	label.modulate = c.lightened(0.3)
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.position.y = 6.5
	add_child(label)


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if ring:
		ring.rotation.y = t * 0.5
	if beacon:
		beacon.light_energy = 1.6 + sin(t * 3.0) * 0.6


func set_active(on: bool) -> void:
	active = on
	visible = on


func contains(p: Vector3) -> bool:
	var d := p - global_position
	d.y = 0.0
	return active and d.length() <= radius
