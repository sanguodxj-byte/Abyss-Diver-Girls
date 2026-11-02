extends Node3D
## 撤离区：固定撤离点 或 运输机接应点。站在圈内持续读条即可撤离。

const A = preload("res://scripts/art.gd")

var title := "撤离点"
var radius := 4.5
var need := 8.0
var active := true
var is_transport := false
var pillar: MeshInstance3D
var ring: MeshInstance3D
var label: Label3D
var beacon: OmniLight3D
var color := Color(0.3, 1.0, 0.5)


func setup(t: String, c: Color, req: float, transport := false) -> void:
	title = t
	color = c
	need = req
	is_transport = transport
	add_to_group("extracts")
	A.ground_decal(self, A.ring_tex(), Color(c.r, c.g, c.b, 0.9), radius * 2.0, Vector3(0, 0.05, 0), true)
	ring = A.add(self, A.torus(radius - 0.12, radius, 48), A.emit(c, 3.0), Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1, 0.15, 1), false)
	# 光柱：自下而上渐隐
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
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
		# 信号塔：桅杆 + 旋转信标
		A.add(self, A.bevel_box(Vector3(1.2, 0.3, 1.2), 0.06), A.concrete(Color(0.5, 0.5, 0.5)), Vector3(radius + 1.0, 0.15, 0))
		A.add(self, A.cyl(0.1, 5.0, 0.16, 8), A.metal(Color(0.3, 0.3, 0.32)), Vector3(radius + 1.0, 2.6, 0))
		A.add(self, A.bevel_box(Vector3(0.4, 0.4, 0.4), 0.06), A.emit(c, 5.0), Vector3(radius + 1.0, 5.2, 0), Vector3.ZERO, Vector3.ONE, false)
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
