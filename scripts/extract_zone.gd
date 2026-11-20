extends Node3D
## 撤离区：固定撤离点 或 运输机接应点。站在圈内持续读条即可撤离。

const A = preload("res://scripts/art.gd")
const FM = preload("res://scripts/modules/field_models.gd")

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
var _pad_mat: ShaderMaterial
var _strobes: Array = []


func set_title(t: String) -> void:
	title = t
	if label != null and is_instance_valid(label):
		label.text = t


func _add_strobe_bollard(bp: Vector3, ang_rad: float, c: Color, _m_dark: Material, _m_st: Material) -> void:
	_strobes.append(FM.build_strobe_bollard(self, bp, ang_rad, c))


func _add_signal_smoke(sp: Vector3, c: Color, m_st: Material, m_dark: Material) -> void:
	FM.build_smoke_can(self, sp + Vector3(0, 0.10, 0), Vector3(12.0, -28.0, 74.0), A.paint(Color(0.28, 0.31, 0.26), 0.3, 0.7))
	A.ground_vfx(self, A.grime_stain_tex(), Color(0.08, 0.08, 0.07, 0.45), 1.35, Vector3(sp.x, 0.075, sp.z), false, 0.44, false, 1)
	var sc := Color(c.r * 0.45 + 0.24, c.g * 0.48 + 0.26, c.b * 0.42 + 0.22, 0.26)
	A.emitter(self, sp + Vector3(0.08, 0.26, 0.04), {
		"tex": A.smoke_tex(), "additive": false, "soft_depth": 0.45,
		"amount": 16, "life": 3.4, "size": 0.85,
		"dir": Vector3(0.42, 0.88, 0.20).normalized(), "spread": 20.0,
		"vmin": 0.7, "vmax": 1.5, "gravity": Vector3(0.14, 0.22, 0.06), "damp": 0.38,
		"c0": sc, "c1": Color(sc.r * 0.65, sc.g * 0.65, sc.b * 0.65, 0.0),
		"grow0": 0.32, "grow1": 2.4, "radius": 0.14
	})


func setup(t: String, c: Color, req: float, transport := false) -> void:
	title = t
	color = c
	need = req
	is_transport = transport
	add_to_group("extracts")
	_strobes.clear()
	_pad_mat = A.extract_pad_mat(Color(c.r * 0.82, c.g * 0.82, c.b * 0.82, 0.72), 0.44, 2)
	A.add(self, A.quad(radius * 2.04, radius * 2.04), _pad_mat, Vector3(0, 0.085, 0), Vector3.ZERO, Vector3.ONE, false)
	var M_ST := A.metal(Color(0.24, 0.25, 0.26))
	var M_DARK := A.metal(Color(0.13, 0.14, 0.15))
	if not transport:
		# 重工野战战术应答信标塔：倒角钢筋混凝土锚固基座 + 野战通信配电箱 + 斜撑钢构桅杆 + 防护笼光学信标头
		var bx := radius + 1.15
		var M_CON := A.concrete(Color(0.48, 0.46, 0.43), false)
		var M_CAB := A.paint(Color(0.32, 0.35, 0.27), 0.35, 0.58, {"wear": 0.48, "rust": 0.45})
		var tw := FM.build_extract_tower(self, Vector3(bx, 0, 0), c, M_CON, M_CAB)
		_strobes.append(tw.lamp_mat)
		for ba in [38.0, 142.0, 218.0, 322.0]:
			var br := deg_to_rad(ba)
			_add_strobe_bollard(Vector3(cos(br) * (radius + 0.16), 0.0, sin(br) * (radius + 0.16)), br, c, M_DARK, M_ST)
		_add_signal_smoke(Vector3(bx - 1.35, 0.0, -0.95), c, M_ST, M_DARK)
	else:
		# 运输艇临时机降区：四角投掷式战术地面频闪信标桩 + 中央金属 H 字机降标线板 + 发烟罐
		var M_HAZ := A.hazard()
		for hx_s in [-1.15, 1.15]:
			A.add(self, A.bevel_box(Vector3(0.36, 0.04, 2.80), 0.01), M_HAZ, Vector3(hx_s, 0.115, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(self, A.bevel_box(Vector3(1.98, 0.036, 0.36), 0.01), M_HAZ, Vector3(0, 0.112, 0), Vector3.ZERO, Vector3.ONE, false)
		for ca in [45.0, 135.0, 225.0, 315.0]:
			var cr := deg_to_rad(ca)
			var pr := radius + 0.35
			var bp := Vector3(cos(cr) * pr, 0, sin(cr) * pr)
			_strobes.append(FM.build_strobe_bollard(self, bp, cr, c, 1.35))
		_add_signal_smoke(Vector3(-radius * 0.68, 0.0, radius * 0.62), c, M_ST, M_DARK)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 1.25
	l.omni_range = radius * 2.0
	l.position = Vector3(0, 2.0, 0)
	add_child(l)
	beacon = l
	# 撤离区不在地图中悬挂 3D 漂浮文字，进入区域时由顶部横幅与撤离进度条提示
	label = null


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _strobes.size():
		var m := _strobes[i] as StandardMaterial3D
		if m != null:
			var pulse := pow(maxf(0.0, sin(t * 4.2 + float(i) * 0.55)), 6.0)
			m.emission_energy_multiplier = 0.45 + 2.55 * pulse
	if _pad_mat != null:
		_pad_mat.set_shader_parameter("active_pulse", 1.0 if active else 0.0)
	if beacon:
		beacon.light_energy = 1.05 + sin(t * 2.6) * 0.30


func set_active(on: bool) -> void:
	active = on
	visible = on


func contains(p: Vector3) -> bool:
	var d := p - global_position
	d.y = 0.0
	return active and d.length() <= radius
