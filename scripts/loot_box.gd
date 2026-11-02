extends StaticBody3D
## 可搜索容器。打开时逐件“摸”出物品（塔科夫式搜索延迟）。
## 外观与废墟同一套材质：褪色漆面、锈蚀、沙尘、半埋进沙土，周围有碎石。
## 不再有地面光圈和状态灯——只有机甲靠近时才出现一圈细微的橙色描边提示。

const A = preload("res://scripts/art.gd")

const STYLE := {
	"supply": {"size": Vector3(1.5, 0.95, 1.1)},
	"tool": {"size": Vector3(1.3, 0.8, 0.75)},
	"military": {"size": Vector3(1.9, 0.9, 1.0)},
	"safe": {"size": Vector3(1.0, 1.25, 1.0)},
	"bug": {"size": Vector3(1.6, 0.6, 1.6)},
	"nest": {"size": Vector3(1.6, 0.6, 1.6)},
}

var kind := "supply"
var title := ""
var items: Array = []
var revealed := 0
var reveal_t := 0.0
var near := false
var _meshes: Array = []
var _rng := RandomNumberGenerator.new()
static var _hl_mat: ShaderMaterial


## 环境同款的做旧漆面
static func _worn(c: Color, metal := 0.1, rust := 0.25) -> ShaderMaterial:
	return A.paint(c, metal, 0.82, {"wear": 0.65, "dust": 0.55, "dust_color": Color(0.45, 0.4, 0.33), "grime": 0.75,
		"rust": rust, "rust_color": Color(0.27, 0.15, 0.08), "scratches": 0.35, "bare_metal": c.lightened(0.35), "panel_scale": 0.0})


func _m(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, hl := true) -> MeshInstance3D:
	var mi := A.add(self, mesh, mat, pos, rot, scl)
	if hl:
		_meshes.append(mi)
	return mi


func setup(k: String, loot: Array) -> void:
	kind = k
	title = GameData.LOOT_TABLES[k].name
	items = loot
	add_to_group("lootboxes")
	_rng.seed = hash(str(position) + k)
	var sz: Vector3 = STYLE[k].size
	var sink := 0.12   # 半埋进沙土
	if k == "bug" or k == "nest":
		collision_layer = 0
		collision_mask = 0
		_build_wreck(sz)
	else:
		collision_layer = 1
		collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sz
		cs.shape = sh
		cs.position.y = sz.y * 0.5 - sink
		add_child(cs)
		A.ground_decal(self, A.blob_tex(), Color(1, 1, 1, 0.55), max(sz.x, sz.z) * 1.6, Vector3(0, 0.02, 0))
		match k:
			"supply": _build_supply(sz, sink)
			"tool": _build_tool(sz, sink)
			"military": _build_military(sz, sink)
			"safe": _build_safe(sz, sink)
		_sand_and_rubble(sz)


## 底部堆沙 + 散落碎石（沙土用地面同款材质，自然衔接）
func _sand_and_rubble(sz: Vector3) -> void:
	var G := A.ground()
	for i in 3:
		var a := _rng.randf() * TAU
		var r: float = _rng.randf_range(0.35, 0.6) * max(sz.x, sz.z)
		_m(A.sphere(1.0, -1, 12), G, Vector3(cos(a) * sz.x * 0.45, -0.02, sin(a) * sz.z * 0.45), Vector3.ZERO, Vector3(r, 0.16 + _rng.randf() * 0.1, r * 0.8), false)
	var C := A.concrete(Color(0.56, 0.53, 0.48), false)
	for i in 5:
		var a := _rng.randf() * TAU
		var d: float = _rng.randf_range(0.7, 1.2) * max(sz.x, sz.z) * 0.6
		var s := _rng.randf_range(0.08, 0.2)
		_m(A.bevel_box(Vector3(s * 1.4, s, s * 1.1), s * 0.25), C, Vector3(cos(a) * d, s * 0.35, sin(a) * d), Vector3(_rng.randf() * 40, _rng.randf() * 360, _rng.randf() * 40), Vector3.ONE, false)


## 补给箱：两只叠放的褪色塑料周转箱 + 盖在上面的旧防水布 + 捆扎带
func _build_supply(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.42, 0.41, 0.34), 0.0, 0.1)
	var M2 := _worn(Color(0.36, 0.33, 0.27), 0.0, 0.1)
	var h1 := sz.y * 0.55
	_m(A.bevel_box(Vector3(sz.x, h1, sz.z), 0.06), M, Vector3(0, h1 * 0.5 - sink, 0))
	for sx in [-1.0, 1.0]:
		_m(A.bevel_box(Vector3(0.05, h1 * 0.5, sz.z * 0.7), 0.01), M2, Vector3(sx * sz.x * 0.5, h1 * 0.55 - sink, 0))
	var h2 := sz.y * 0.42
	_m(A.bevel_box(Vector3(sz.x * 0.72, h2, sz.z * 0.85), 0.05), M2, Vector3(-sz.x * 0.1, h1 + h2 * 0.5 - sink, 0.04), Vector3(0, 8, 0))
	# 防水布：两片倾斜薄板搭在箱角
	var T := _worn(Color(0.33, 0.31, 0.25), 0.0, 0.0)
	_m(A.bevel_box(Vector3(sz.x * 0.8, 0.03, sz.z * 0.95), 0.01), T, Vector3(-sz.x * 0.08, h1 + h2 - sink + 0.02, 0.0), Vector3(0, 8, -4))
	_m(A.bevel_box(Vector3(0.03, h2 * 1.4, sz.z * 0.9), 0.01), T, Vector3(sz.x * 0.28, h1 + h2 * 0.35 - sink, 0.0), Vector3(0, 8, -12))
	var S := _worn(Color(0.2, 0.19, 0.17), 0.3, 0.3)
	for sx in [-0.3, 0.25]:
		_m(A.bevel_box(Vector3(0.05, sz.y + 0.02, sz.z + 0.03), 0.005), S, Vector3(sx * sz.x, sz.y * 0.5 - sink, 0))
	A.stencil(self, "RATION 04", Vector3(0, h1 * 0.5 - sink, -sz.z * 0.5 - 0.005), Vector3(0, 180, 0), 0.0035, Color(0.75, 0.72, 0.62, 0.5))


## 工具箱：倾倒的锈蚀钢制工具柜，抽屉半开
func _build_tool(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.38, 0.27, 0.18), 0.45, 0.7)
	var MD := _worn(Color(0.16, 0.16, 0.16), 0.6, 0.5)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(0, 0, -6)
	var b := A.add(body, A.bevel_box(sz, 0.04), M, Vector3(0, sz.y * 0.5 - sink, 0))
	_meshes.append(b)
	for i in 3:
		var y := sz.y * (0.22 + i * 0.26) - sink
		var out := 0.12 if i == 1 else 0.0
		_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.9, sz.y * 0.2, 0.05), 0.01), M, Vector3(0, y, -sz.z * 0.5 - 0.02 - out)))
		_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x * 0.3, 0.035, 0.04), 0.008), MD, Vector3(0, y + 0.02, -sz.z * 0.5 - 0.06 - out)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.04, 0.05, sz.z + 0.04), 0.01), MD, Vector3(0, sz.y - sink, 0)))
	# 散落的扳手
	_m(A.bevel_box(Vector3(0.42, 0.03, 0.05), 0.01), MD, Vector3(sz.x * 0.75, 0.02, -sz.z * 0.4), Vector3(0, 35, 0), Vector3.ONE, false)


## 军用储物箱：褪色橄榄色弹药箱，漆面剥落、锁扣生锈，斜插进沙里
func _build_military(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.3, 0.32, 0.24), 0.15, 0.35)
	var MD := _worn(Color(0.15, 0.15, 0.14), 0.6, 0.55)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(4, 0, 3)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.07), M, Vector3(0, sz.y * 0.5 - sink - 0.05, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x + 0.03, 0.1, sz.z + 0.03), 0.02), MD, Vector3(0, sz.y * 0.72 - sink - 0.05, 0)))
	for sx in [-0.6, 0.0, 0.6]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.13, 0.16, 0.05), 0.015), MD, Vector3(sx, sz.y * 0.72 - sink - 0.05, -sz.z * 0.5 - 0.03)))
	for sx in [-1.0, 1.0]:
		_meshes.append(A.add(body, A.bevel_box(Vector3(0.07, 0.24, 0.42), 0.015), MD, Vector3(sx * (sz.x * 0.5 + 0.035), sz.y * 0.45 - sink - 0.05, 0)))
	# 磨损的暗黄色警示条（低饱和，和环境一个色调）
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.3, 0.012, sz.z * 0.98), 0.003), _worn(Color(0.55, 0.45, 0.2), 0.0, 0.2), Vector3(sz.x * 0.32, sz.y - sink - 0.045, 0)))
	A.stencil(body, "AMMO 7.62  LOT-117", Vector3(-0.1, sz.y * 0.42 - sink - 0.05, -sz.z * 0.5 - 0.005), Vector3(0, 180, 0), 0.0032, Color(0.78, 0.76, 0.66, 0.45))


## 保险柜：旧式重型保险柜侧倒在碎混凝土里，门缝锈死
func _build_safe(sz: Vector3, sink: float) -> void:
	var M := _worn(Color(0.26, 0.27, 0.27), 0.55, 0.65)
	var MB := _worn(Color(0.5, 0.44, 0.3), 0.7, 0.4)
	var body := Node3D.new()
	add_child(body)
	body.rotation_degrees = Vector3(-8, 0, 5)
	_meshes.append(A.add(body, A.bevel_box(sz, 0.06), M, Vector3(0, sz.y * 0.5 - sink - 0.08, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(sz.x - 0.16, sz.y - 0.18, 0.05), 0.02), M, Vector3(0, sz.y * 0.5 - sink - 0.08, -sz.z * 0.5 - 0.02)))
	_meshes.append(A.add(body, A.cyl(0.12, 0.05, 0.12, 16), MB, Vector3(0.14, sz.y * 0.55 - sink - 0.08, -sz.z * 0.5 - 0.06), Vector3(90, 0, 0)))
	_meshes.append(A.add(body, A.bevel_box(Vector3(0.05, 0.26, 0.05), 0.01), MB, Vector3(-0.24, sz.y * 0.5 - sink - 0.08, -sz.z * 0.5 - 0.06)))
	var C := A.concrete(Color(0.58, 0.55, 0.5), false)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		_m(A.bevel_box(Vector3(0.5, 0.22, 0.4), 0.06), C, Vector3(cos(a) * 0.75, 0.08, sin(a) * 0.75), Vector3(_rng.randf() * 20, _rng.randf() * 360, _rng.randf() * 25), Vector3.ONE, false)


## 机械虫残骸：扭曲的暗灰装甲板 + 断裂的腿节 + 熄灭的紫色光条
func _build_wreck(sz: Vector3) -> void:
	var G := _worn(Color(0.17, 0.17, 0.19), 0.6, 0.25)
	var G2 := _worn(Color(0.26, 0.25, 0.28), 0.5, 0.2)
	var dead := _worn(Color(0.22, 0.15, 0.27), 0.2, 0.0)
	A.ground_decal(self, A.blob_tex(), Color(0.04, 0.04, 0.05, 0.8), sz.x * 1.8, Vector3(0, 0.025, 0))
	_m(A.bevel_box(Vector3(sz.x * 0.7, 0.3, sz.z * 0.55), 0.06, 0.8), G, Vector3(0, 0.12, 0), Vector3(6, _rng.randf() * 360, -10))
	for i in 4:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(0.3, 0.75) * sz.x
		_m(A.bevel_box(Vector3(_rng.randf_range(0.3, 0.6), 0.06, _rng.randf_range(0.25, 0.5)), 0.02), G2 if i % 2 else G,
			Vector3(cos(a) * d, 0.05 + _rng.randf() * 0.1, sin(a) * d), Vector3(_rng.randf_range(-30, 30), _rng.randf() * 360, _rng.randf_range(-30, 30)))
	for i in 2:
		var a := _rng.randf() * TAU
		_m(A.bevel_box(Vector3(0.12, 0.12, 0.8), 0.02), G, Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6), Vector3(_rng.randf_range(-15, 15), rad_to_deg(-a), 12))
	_m(A.bevel_box(Vector3(0.5, 0.02, 0.05), 0.005), dead, Vector3(0, 0.29, -0.1), Vector3(6, _rng.randf() * 360, -10))


## 靠近提示：细边橙色描边呼吸（玩家色），搜空后不再提示
func set_near(on: bool) -> void:
	on = on and not items.is_empty()
	if on == near:
		return
	near = on
	if _hl_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float p = 0.55 + 0.45 * sin(TIME * 4.0);
	ALBEDO = vec3(1.0, 0.62, 0.12) * f * p * 1.4;
}"""
		_hl_mat = ShaderMaterial.new()
		_hl_mat.shader = sh
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _hl_mat if on else null


func refresh_glow() -> void:
	if items.is_empty():
		set_near(false)
