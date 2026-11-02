extends RefCounted
## 程序化美术库：倒角网格、PBR 材质（三平面映射 + 噪声细节）、粒子、贴图。
## 所有资源按参数缓存，避免重复创建。

static var _mesh_cache := {}
static var _mat_cache := {}
static var _tex_cache := {}


# ======================================================================
# 网格
# ======================================================================
static var _vc := Color(1, 1, 1)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	st.set_color(_vc)
	var n := (b - a).cross(c - a)
	# Godot 以顺时针为正面：叉积朝内时才是朝外的正面
	if n.dot((a + b + c) / 3.0 - center) > 0.0:
		var t := b
		b = c
		c = t
	# 盒式投影 UV（供生成切线，法线贴图才有正确的切线空间）
	var o := -(b - a).cross(c - a)
	var ao := o.abs()
	for v in [a, b, c]:
		var uv: Vector2
		if ao.x >= ao.y and ao.x >= ao.z:
			uv = Vector2(v.z * signf(o.x), -v.y)
		elif ao.y >= ao.z:
			uv = Vector2(v.x, v.z * signf(o.y))
		else:
			uv = Vector2(-v.x * signf(o.z), -v.y)
		st.set_uv(uv)
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, center: Vector3) -> void:
	_tri(st, a, b, c, center)
	_tri(st, a, c, d, center)


## 倒角方块。bevel = 倒角宽度；taper = 顶面相对底面的缩放（<1 为梯形）。
static func bevel_box(size: Vector3, bevel := 0.06, taper := 1.0) -> ArrayMesh:
	var key := "bb%s|%.3f|%.3f" % [size, bevel, taper]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var h := size * 0.5
	var b: float = min(bevel, min(h.x, min(h.y, h.z)) * 0.9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var P := func(sx: float, sy: float, sz: float, ix: float, iy: float, iz: float) -> Vector3:
		# ix/iy/iz：该轴是否内缩 b（1 = 内缩）
		var v := Vector3(sx * (h.x - b * ix), sy * (h.y - b * iy), sz * (h.z - b * iz))
		if sy > 0.0:
			v.x *= taper
			v.z *= taper
		return v
	var C := Vector3.ZERO
	var S := [-1.0, 1.0]
	# 6 个面（顶点色白），棱与角（顶点色 R=0，供着色器做掉漆）
	_vc = Color(1, 1, 1)
	for s in S:
		_quad(st, P.call(s, -1, -1, 0, 1, 1), P.call(s, 1, -1, 0, 1, 1), P.call(s, 1, 1, 0, 1, 1), P.call(s, -1, 1, 0, 1, 1), C)
		_quad(st, P.call(-1, s, -1, 1, 0, 1), P.call(1, s, -1, 1, 0, 1), P.call(1, s, 1, 1, 0, 1), P.call(-1, s, 1, 1, 0, 1), C)
		_quad(st, P.call(-1, -1, s, 1, 1, 0), P.call(1, -1, s, 1, 1, 0), P.call(1, 1, s, 1, 1, 0), P.call(-1, 1, s, 1, 1, 0), C)
	# 12 条棱
	_vc = Color(0, 1, 1)
	for s1 in S:
		for s2 in S:
			# 平行 Z 轴的棱（X、Y 两面之间）
			_quad(st, P.call(s1, s2, -1, 0, 1, 1), P.call(s1, s2, 1, 0, 1, 1), P.call(s1, s2, 1, 1, 0, 1), P.call(s1, s2, -1, 1, 0, 1), C)
			# 平行 X 轴的棱（Y、Z 之间）
			_quad(st, P.call(-1, s1, s2, 1, 0, 1), P.call(1, s1, s2, 1, 0, 1), P.call(1, s1, s2, 1, 1, 0), P.call(-1, s1, s2, 1, 1, 0), C)
			# 平行 Y 轴的棱（X、Z 之间）
			_quad(st, P.call(s1, -1, s2, 0, 1, 1), P.call(s1, 1, s2, 0, 1, 1), P.call(s1, 1, s2, 1, 1, 0), P.call(s1, -1, s2, 1, 1, 0), C)
	# 8 个角
	for sx in S:
		for sy in S:
			for sz in S:
				_tri(st, P.call(sx, sy, sz, 0, 1, 1), P.call(sx, sy, sz, 1, 0, 1), P.call(sx, sy, sz, 1, 1, 0), C)
	_vc = Color(1, 1, 1)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func cyl(r: float, hgt: float, r2 := -1.0, seg := 16) -> CylinderMesh:
	var key := "cy%.3f|%.3f|%.3f|%d" % [r, hgt, r2, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0 else r2
	c.height = hgt
	c.radial_segments = seg
	c.rings = 1
	_mesh_cache[key] = c
	return c


static func sphere(r: float, hgt := -1.0, seg := 16) -> SphereMesh:
	var key := "sp%.3f|%.3f|%d" % [r, hgt, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if hgt < 0 else hgt
	s.radial_segments = seg
	s.rings = max(4, seg / 2)
	_mesh_cache[key] = s
	return s


static func capsule(r: float, hgt: float) -> CapsuleMesh:
	var key := "ca%.3f|%.3f" % [r, hgt]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = hgt
	c.radial_segments = 12
	c.rings = 4
	_mesh_cache[key] = c
	return c


static func torus(inner: float, outer: float, seg := 32) -> TorusMesh:
	var key := "to%.3f|%.3f|%d" % [inner, outer, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = seg
	t.ring_segments = 8
	_mesh_cache[key] = t
	return t


static func quad(w: float, d: float) -> PlaneMesh:
	var key := "pl%.3f|%.3f" % [w, d]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var p := PlaneMesh.new()
	p.size = Vector2(w, d)
	_mesh_cache[key] = p
	return p


# ======================================================================
# 贴图
# ======================================================================
static func noise_tex(kind := "grime", size := 256) -> Texture2D:
	var key := "n_%s_%d" % [kind, size]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := FastNoiseLite.new()
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	match kind:
		"grime":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.012
			n.fractal_octaves = 5
			var g := Gradient.new()
			g.set_color(0, Color(0.62, 0.6, 0.58))
			g.set_color(1, Color(1, 1, 1))
			t.color_ramp = g
		"grime_raw":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.012
			n.fractal_octaves = 5
		"hi_raw":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.045
			n.fractal_octaves = 4
			n.fractal_gain = 0.6
		"rough":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.03
			n.fractal_octaves = 4
			var g := Gradient.new()
			g.set_color(0, Color(0.75, 0.75, 0.75))
			g.set_color(1, Color(1, 1, 1))
			t.color_ramp = g
		"normal":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.05
			n.fractal_octaves = 3
			t.as_normal_map = true
			t.bump_strength = 4.0
		"ground":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.008
			n.fractal_octaves = 6
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.45, 0.6, 1.0])
			g.colors = PackedColorArray([Color(0.55, 0.5, 0.45), Color(0.8, 0.74, 0.64), Color(0.9, 0.84, 0.72), Color(1.0, 0.95, 0.85)])
			t.color_ramp = g
		"ground_n":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.04
			n.fractal_octaves = 5
			t.as_normal_map = true
			t.bump_strength = 8.0
		"creep":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.03
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.03, 0.09, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1), Color(0.75, 0.75, 0.75), Color(0.0, 0.0, 0.0), Color(0, 0, 0)])
			t.color_ramp = g
		"concrete":
			n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
			n.frequency = 0.05
			n.fractal_octaves = 5
			var g := Gradient.new()
			g.set_color(0, Color(0.7, 0.68, 0.66))
			g.set_color(1, Color(1, 1, 1))
			t.color_ramp = g
	_tex_cache[key] = t
	return t


## 黄黑警示条纹
static func hazard_tex() -> Texture2D:
	if _tex_cache.has("hazard"):
		return _tex_cache["hazard"]
	# 256px + 边缘抗锯齿 + mipmap，远看不再闪
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var u := fmod(float(x + y) / 64.0, 2.0)
			var on := u < 1.0
			var k := 0.5 + (0.5 if on else -0.5) * clampf(minf(u if on else u - 1.0, (1.0 - u) if on else (2.0 - u)) * 64.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.08, 0.08, 0.08).lerp(Color(0.95, 0.68, 0.1), k))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["hazard"] = t
	return t


## 柔和圆点（粒子用）
static func soft_dot() -> Texture2D:
	if _tex_cache.has("dot"):
		return _tex_cache["dot"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_tex_cache["dot"] = t
	return t


## 烟雾团
static func smoke_tex() -> Texture2D:
	if _tex_cache.has("smoke"):
		return _tex_cache["smoke"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32).length() / 32.0
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = a * a * (0.6 + 0.4 * n.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(1, 1, 1, clamp(a, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["smoke"] = t
	return t


## 地面光圈/阴影斑
static func ring_tex() -> Texture2D:
	if _tex_cache.has("ring"):
		return _tex_cache["ring"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.78, 0.86, 0.92, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.14), Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	_tex_cache["ring"] = t
	return t


## 柔和烟团贴图（白色、极软边，用于大团飘烟）
static func cloud_tex() -> Texture2D:
	if _tex_cache.has("cloud"):
		return _tex_cache["cloud"]
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 7
	nz.frequency = 0.035
	nz.fractal_octaves = 4
	for y in 128:
		for x in 128:
			var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
			var fall: float = clamp(1.0 - d, 0.0, 1.0)
			fall = fall * fall * (3.0 - 2.0 * fall)
			var n: float = nz.get_noise_2d(x, y) * 0.5 + 0.5
			img.set_pixel(x, y, Color(1, 1, 1, clamp(fall * (0.35 + n * 0.9), 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_tex_cache["cloud"] = t
	return t


static func blob_tex() -> Texture2D:
	if _tex_cache.has("blob"):
		return _tex_cache["blob"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_tex_cache["blob"] = t
	return t


# ======================================================================
# 材质
# ======================================================================
## 写实涂装（自定义着色器）：边缘掉漆、面板接缝、积灰、锈迹、底部泥污。
static var _paint_shader: Shader
static func paint(c: Color, metal := 0.15, rough := 0.62, opts := {}) -> ShaderMaterial:
	var key := "paint%s|%.2f|%.2f|%s" % [c.to_html(), metal, rough, str(opts)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _paint_shader == null:
		_paint_shader = load("res://shaders/mech_paint.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _paint_shader
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("metal_base", metal)
	m.set_shader_parameter("rough_base", rough)
	m.set_shader_parameter("noise_lo", noise_tex("grime_raw"))
	m.set_shader_parameter("noise_hi", noise_tex("hi_raw"))
	m.set_shader_parameter("normal_tex", noise_tex("normal"))
	if not opts.has("panel_scale"):
		m.set_shader_parameter("panel_scale", 0.0)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	_mat_cache[key] = m
	return m


static func metal(c := Color(0.18, 0.19, 0.21)) -> ShaderMaterial:
	return paint(c, 0.6, 0.55, {"wear": 0.3, "panel_scale": 0.0, "dust": 0.15, "rust": 0.05, "scratches": 0.2, "bare_metal": c.lightened(0.5)})


static func chrome() -> ShaderMaterial:
	return paint(Color(0.62, 0.63, 0.64), 0.85, 0.34, {"wear": 0.0, "panel_scale": 0.0, "dust": 0.15, "rust": 0.0, "scratches": 0.2, "grime": 0.2})


static func rubber() -> ShaderMaterial:
	return paint(Color(0.06, 0.06, 0.065), 0.0, 0.9, {"wear": 0.0, "panel_scale": 0.0, "scratches": 0.0, "rust": 0.0, "dust": 0.6})


static func emit(c: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "emit%s|%.2f" % [c.to_html(), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	_mat_cache[key] = m
	return m


static func hazard() -> ShaderMaterial:
	return paint(Color(1, 1, 1), 0.1, 0.6, {"stripes": 1.0, "panel_scale": 0.0, "wear": 0.8})


static func glass(c: Color) -> StandardMaterial3D:
	var key := "glass%s" % c.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.6)
	m.metallic = 0.3
	m.roughness = 0.1
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	_mat_cache[key] = m
	return m


## 混凝土：真实纹理 + 模板接缝 + 棱角破损 + 雨水污渍流痕 + 底部泥污
static func concrete(c: Color, seams := true) -> ShaderMaterial:
	return paint(c, 0.0, 0.93, {
		"use_albedo_tex": 1.0, "albedo_tex": noise_tex("concrete"), "albedo_tex_scale": 0.18,
		"wear": 0.45, "bare_metal": c.lightened(0.25), "scratches": 0.0,
		"rust": 0.55, "rust_color": Color(0.16, 0.14, 0.12), "grime": 0.85, "dust": 0.2, "dust_color": Color(0.42, 0.38, 0.33),
		"panel_scale": 0.33 if seams else 0.0, "detail_scale": 0.6,
	})


## 虫族甲壳：低粗糙度、湿润高光。
static var _chitin_shader: Shader
static func chitin(c: Color, opts := {}) -> ShaderMaterial:
	var key := "chitin%s%s" % [c.to_html(), str(opts)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _chitin_shader == null:
		_chitin_shader = load("res://shaders/bug_chitin.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _chitin_shader
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("noise_lo", noise_tex("grime_raw"))
	m.set_shader_parameter("noise_hi", noise_tex("hi_raw"))
	m.set_shader_parameter("normal_tex", noise_tex("normal"))
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	_mat_cache[key] = m
	return m


## 写实虫族材质：离线手绘贴图（tools/gen_bug_textures.py 生成），按网格自身 UV 贴附。
## part: "shell" 甲壳 / "leg" 腿节 / "eye" 复眼 / "membrane" 节间膜 / "sac" 酸囊 / "claw" 颚爪
const BUG_TEX_DIR := "res://assets/textures/bugs/"
static func _bug_tex(file: String) -> Texture2D:
	var key := "bugtex_" + file
	if _mat_cache.has(key):
		return _mat_cache[key]
	var t: Texture2D = null
	var path := BUG_TEX_DIR + file
	if ResourceLoader.exists(path):
		t = load(path)
	else:  # 未经编辑器导入时（纯命令行运行）直接读 PNG
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_mat_cache[key] = t
	return t


static func bug_mat(kind: String, part := "shell", tint := Color.WHITE, uv_scale := Vector2.ONE) -> StandardMaterial3D:
	var key := "bugmat_%s_%s_%s_%s" % [kind, part, tint.to_html(), str(uv_scale)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.normal_enabled = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	match part:
		"shell":
			m.albedo_texture = _bug_tex("chitin_%s.png" % kind)
			m.normal_texture = _bug_tex("chitin_n.png")
			m.normal_scale = 1.0
			m.roughness_texture = _bug_tex("chitin_r.png")
			m.roughness = 1.0
			m.clearcoat_enabled = true
			m.clearcoat = 0.55
			m.clearcoat_roughness = 0.25
			m.rim_enabled = true
			m.rim = 0.12
			m.rim_tint = 0.6
		"leg":
			m.albedo_texture = _bug_tex("leg_%s.png" % kind)
			m.normal_texture = _bug_tex("leg_n.png")
			m.roughness_texture = _bug_tex("leg_r.png")
			m.roughness = 1.0
			m.clearcoat_enabled = true
			m.clearcoat = 0.3
			m.clearcoat_roughness = 0.35
		"eye":
			m.albedo_texture = _bug_tex("eye_a.png")
			m.normal_texture = _bug_tex("eye_n.png")
			m.normal_scale = 0.8
			m.roughness = 0.12
			m.metallic_specular = 0.8
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.05
		"membrane":
			m.albedo_texture = _bug_tex("membrane_a.png")
			m.normal_texture = _bug_tex("membrane_n.png")
			m.roughness = 0.4
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.4
		"sac":
			m.albedo_texture = _bug_tex("sac_a.png")
			m.normal_texture = _bug_tex("membrane_n.png")
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = Color(0.35, 0.6, 0.1)
			m.emission_energy_multiplier = 0.3
			m.emission_texture = _bug_tex("sac_e.png")
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.1
			m.clearcoat_roughness = 0.15
		"claw":
			m.albedo_texture = _bug_tex("claw_a.png")
			m.normal_texture = _bug_tex("leg_n.png")
			m.normal_scale = 0.5
			m.roughness = 0.3
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
	_mat_cache[key] = m
	return m


## 虫族菌毯：带发光脉络的地表贴片。
static func creep() -> StandardMaterial3D:
	if _mat_cache.has("creep"):
		return _mat_cache["creep"]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.11, 0.08, 0.06, 0.82)
	m.albedo_texture = noise_tex("grime")
	m.emission_enabled = true
	m.emission = Color(0.45, 0.2, 0.06)
	m.emission_energy_multiplier = 0.06
	m.emission_texture = noise_tex("creep")
	m.roughness = 0.35
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	_mat_cache["creep"] = m
	return m


static func ground() -> ShaderMaterial:
	# 废土地表着色器：世界坐标采样，混合 干土 / 深色湿土 / 龟裂泥地 / 枯草斑 / 碎石点，自带法线起伏
	if _mat_cache.has("ground"):
		return _mat_cache["ground"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 dirt_a : source_color = vec3(0.47, 0.42, 0.33);
uniform vec3 dirt_b : source_color = vec3(0.33, 0.28, 0.21);
uniform vec3 mud : source_color = vec3(0.27, 0.23, 0.18);
uniform vec3 grass : source_color = vec3(0.31, 0.33, 0.19);
uniform vec3 grass2 : source_color = vec3(0.42, 0.4, 0.25);
uniform sampler2D zone_tex : filter_linear, repeat_disable;
uniform float zone_half = 180.0;
uniform float zone_on = 0.0;
varying vec3 wp;
vec2 h2(vec2 p){ p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
// 龟裂纹：Voronoi 边缘距离
float cracks(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++){
		vec2 g = vec2(float(x), float(y));
		vec2 o = h2(i + g);
		float d = length(g + o - f);
		if (d < d1){ d2 = d1; d1 = d; } else if (d < d2){ d2 = d; }
	}
	return d2 - d1;
}
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz;
	float low = texture(n_low, p * 0.006).r;
	float mid = texture(n_low, p * 0.023 + 0.37).r;
	float hi = texture(n_hi, p * 0.11).r;
	float hi2 = texture(n_hi, p * 0.55 + 0.2).r;
	vec3 col = mix(dirt_b, dirt_a, smoothstep(0.3, 0.7, low + (hi - 0.5) * 0.35));
	// 深色湿土 / 泥地区域 + 龟裂
	float mudm = smoothstep(0.56, 0.74, mid + (hi - 0.5) * 0.15);
	float cr = cracks(p * 0.9 + (hi - 0.5) * 0.6);
	float crack_line = 1.0 - smoothstep(0.02, 0.09, cr);
	col = mix(col, mud * (0.9 + hi * 0.25), mudm);
	col *= 1.0 - crack_line * mudm * 0.55;
	// 枯草斑：中频噪声阈值 + 高频碎点
	float gm = smoothstep(0.45, 0.72, 1.0 - mid + (low - 0.5) * 0.4 + (hi - 0.5) * 0.2) * (1.0 - mudm);
	vec3 gcol = mix(grass, grass2, hi2);
	col = mix(col, gcol, gm * 0.8 * smoothstep(0.2, 0.7, hi2 + 0.1));
	// 碎石点
	float grav = smoothstep(0.74, 0.8, hi2) * (1.0 - gm);
	col = mix(col, vec3(0.62, 0.58, 0.52), grav * 0.35);
	col *= (0.86 + hi * 0.24) * mix(0.82, 1.05, low);
	// 分区地表：R 铺装 / G 草地 / B 耕地 / A 工业碎石
	vec4 zt = texture(zone_tex, (p + zone_half) / (zone_half * 2.0)) * zone_on;
	vec2 tf = abs(fract(p / vec2(2.4, 1.2)) - 0.5);
	float seam = smoothstep(0.46, 0.5, max(tf.x, tf.y));
	vec3 pave = vec3(0.44, 0.43, 0.41) * (0.86 + hi * 0.22) * mix(0.8, 1.05, low);
	pave *= 1.0 - seam * 0.4;
	pave = mix(pave, vec3(0.25, 0.24, 0.22), smoothstep(0.6, 0.8, mid) * 0.55);
	pave *= 1.0 - crack_line * 0.4;
	float pm = smoothstep(0.25, 0.75, zt.r + (hi - 0.5) * 0.45);
	col = mix(col, pave, pm);
	vec3 gr = mix(vec3(0.22, 0.27, 0.13), vec3(0.37, 0.38, 0.2), hi2) * (0.82 + low * 0.35);
	float gmm = smoothstep(0.25, 0.8, zt.g + (mid - 0.5) * 0.6 + (hi - 0.5) * 0.3);
	col = mix(col, gr, gmm);
	float furrow = 0.5 + 0.5 * sin(p.y * 2.856 + (low - 0.5) * 1.5);
	vec3 soil = mix(vec3(0.17, 0.13, 0.1), vec3(0.38, 0.31, 0.21), smoothstep(0.2, 0.8, furrow)) * (0.85 + hi * 0.3);
	float smm = smoothstep(0.3, 0.8, zt.b + (hi - 0.5) * 0.3);
	col = mix(col, soil, smm);
	vec3 grv = vec3(0.38, 0.37, 0.35) * (0.68 + hi2 * 0.55);
	grv = mix(grv, vec3(0.09, 0.09, 0.09), smoothstep(0.62, 0.72, mid) * 0.75);
	float am = smoothstep(0.25, 0.8, zt.a + (hi - 0.5) * 0.4);
	col = mix(col, grv, am);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, mudm);
	vec3 n1 = texture(n_nrm, p * 0.09).rgb;
	vec3 n2 = texture(n_nrm, p * 0.4 + 0.5).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5) * 2.0 - 1.0 + vec3(0.0, 0.0, 1.5)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2 + mudm * crack_line * 2.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("n_low", noise_tex("grime_raw", 512))
	m.set_shader_parameter("n_hi", noise_tex("hi_raw", 512))
	m.set_shader_parameter("n_nrm", noise_tex("ground_n", 512))
	m.set_meta("no_outline", true)
	_mat_cache["ground"] = m
	return m


## 叠加用的贴地材质（光圈、阴影斑等），不受光。
static func decal_mat(tex: Texture2D, c: Color, additive := false) -> StandardMaterial3D:
	var key := "decal%s%s%s" % [tex.get_instance_id(), c.to_html(), additive]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.render_priority = -1
	_mat_cache[key] = m
	return m


static func particle_mat(tex: Texture2D, additive := true) -> StandardMaterial3D:
	var key := "pm%s%s" % [tex.get_instance_id(), additive]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


## 受击闪白叠加层
static func flash_overlay() -> StandardMaterial3D:
	if _mat_cache.has("flash"):
		return _mat_cache["flash"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_cache["flash"] = m
	return m


# ======================================================================
# 组装辅助
# ======================================================================
static func add(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## 贴地平面（光圈、阴影斑、血迹）
static func ground_decal(parent: Node3D, tex: Texture2D, c: Color, size: float, pos: Vector3, additive := false) -> MeshInstance3D:
	var mi := add(parent, quad(size, size), decal_mat(tex, c, additive), pos, Vector3.ZERO, Vector3.ONE, false)
	return mi


## 一次性爆发粒子，播完自动销毁。
static func burst(parent: Node, pos: Vector3, opts: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = opts.get("explosive", 0.95)
	p.amount = opts.get("amount", 16)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.lifetime = opts.get("life", 0.5)
	p.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * opts.get("size", 0.3)
	qm.material = particle_mat(opts.get("tex", soft_dot()), opts.get("additive", true))
	p.mesh = qm
	p.direction = opts.get("dir", Vector3.UP)
	p.spread = opts.get("spread", 180.0)
	p.initial_velocity_min = opts.get("vmin", 3.0)
	p.initial_velocity_max = opts.get("vmax", 8.0)
	p.gravity = opts.get("gravity", Vector3(0, -12, 0))
	p.damping_min = opts.get("damp", 2.0)
	p.damping_max = opts.get("damp", 2.0)
	p.scale_amount_min = opts.get("smin", 0.6)
	p.scale_amount_max = opts.get("smax", 1.2)
	var curve := Curve.new()
	curve.add_point(Vector2(0, opts.get("grow0", 1.0)))
	curve.add_point(Vector2(1, opts.get("grow1", 0.0)))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	var c0: Color = opts.get("c0", Color(1, 0.8, 0.4))
	var c1: Color = opts.get("c1", Color(c0.r, c0.g * 0.4, 0.0, 0.0))
	g.set_color(0, c0)
	g.set_color(1, c1)
	p.color_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = opts.get("radius", 0.1)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## 持续粒子（火焰、烟柱、尘埃）
static func emitter(parent: Node3D, pos: Vector3, opts: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = opts.get("amount", 24)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.lifetime = opts.get("life", 1.0)
	p.local_coords = opts.get("local", false)
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * opts.get("size", 0.5)
	qm.material = particle_mat(opts.get("tex", soft_dot()), opts.get("additive", true))
	p.mesh = qm
	p.direction = opts.get("dir", Vector3.UP)
	p.spread = opts.get("spread", 15.0)
	p.initial_velocity_min = opts.get("vmin", 1.0)
	p.initial_velocity_max = opts.get("vmax", 2.0)
	p.gravity = opts.get("gravity", Vector3(0, 1, 0))
	p.scale_amount_min = opts.get("smin", 0.6)
	p.scale_amount_max = opts.get("smax", 1.2)
	var curve := Curve.new()
	curve.add_point(Vector2(0, opts.get("grow0", 0.5)))
	curve.add_point(Vector2(1, opts.get("grow1", 1.0)))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, opts.get("c0", Color(1, 0.7, 0.3)))
	g.set_color(1, opts.get("c1", Color(0.3, 0.1, 0.0, 0.0)))
	if opts.has("cmid"):
		g.add_point(0.3, opts.cmid)
	p.color_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE if not opts.has("box") else CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_sphere_radius = opts.get("radius", 0.2)
	if opts.has("box"):
		p.emission_box_extents = opts.box
	parent.add_child(p)
	p.position = pos
	return p


# ======================================================================
# 写实细节件（greebles）
# ======================================================================
## 沿 Catmull-Rom 曲线生成管子（液压软管、线缆）
## 多边形装甲板：凸多边形轮廓（XY 平面）沿 Z 挤出 thick，四周倒角 bevel。
## 用于 B.o.T 式的多面切角装甲。棱的顶点色 R=0，供涂装着色器做边缘掉漆。
static func prism(outline: PackedVector2Array, thick: float, bevel := 0.03) -> ArrayMesh:
	var key := "pr%s|%.3f|%.3f" % [outline, thick, bevel]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var n := outline.size()
	# 统一为顺时针（y 向上），镜像出来的逆时针轮廓自动翻转，保证法线朝外
	var area := 0.0
	for i in n:
		var a2 := outline[i]
		var b2 := outline[(i + 1) % n]
		area += a2.x * b2.y - b2.x * a2.y
	if area > 0.0:
		outline = outline.duplicate()
		outline.reverse()
	var cen := Vector2.ZERO
	for q in outline:
		cen += q
	cen /= n
	var b: float = min(bevel, thick * 0.45)
	# 内缩轮廓（沿各顶点角平分线收 b）
	var inset := PackedVector2Array()
	for i in n:
		var p0 := outline[(i - 1 + n) % n]
		var p1 := outline[i]
		var p2 := outline[(i + 1) % n]
		var d1 := (p1 - p0).normalized()
		var d2 := (p2 - p1).normalized()
		var n1 := Vector2(d1.y, -d1.x)
		var n2 := Vector2(d2.y, -d2.x)
		if n1.dot(cen - p1) < 0.0:
			n1 = -n1
			n2 = -n2
		var bis := (n1 + n2).normalized()
		var k: float = b / max(0.3, bis.dot(n1))
		inset.append(p1 + bis * k)
	var h := thick * 0.5
	var C := Vector3(cen.x, cen.y, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_vc = Color(1, 1, 1)
	for i in range(1, n - 1):
		_tri(st, Vector3(inset[0].x, inset[0].y, -h), Vector3(inset[i].x, inset[i].y, -h), Vector3(inset[i + 1].x, inset[i + 1].y, -h), C)
		_tri(st, Vector3(inset[0].x, inset[0].y, h), Vector3(inset[i].x, inset[i].y, h), Vector3(inset[i + 1].x, inset[i + 1].y, h), C)
	for i in n:
		var j := (i + 1) % n
		var oi := outline[i]
		var oj := outline[j]
		var ii := inset[i]
		var ij := inset[j]
		_vc = Color(0, 1, 1)
		_quad(st, Vector3(ii.x, ii.y, -h), Vector3(ij.x, ij.y, -h), Vector3(oj.x, oj.y, -h + b), Vector3(oi.x, oi.y, -h + b), C)
		_quad(st, Vector3(ii.x, ii.y, h), Vector3(ij.x, ij.y, h), Vector3(oj.x, oj.y, h - b), Vector3(oi.x, oi.y, h - b), C)
		_vc = Color(1, 1, 1)
		_quad(st, Vector3(oi.x, oi.y, -h + b), Vector3(oj.x, oj.y, -h + b), Vector3(oj.x, oj.y, h - b), Vector3(oi.x, oi.y, h - b), C)
	_vc = Color(1, 1, 1)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func tube(pts: Array, r: float, seg := 7, sub := 6) -> ArrayMesh:
	var path: Array = []
	for i in pts.size() - 1:
		var p0: Vector3 = pts[max(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[min(i + 2, pts.size() - 1)]
		for k in sub:
			var t := float(k) / sub
			var t2 := t * t
			var t3 := t2 * t
			path.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	path.append(pts[pts.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP
	var rings: Array = []
	for i in path.size():
		var tng: Vector3 = (path[min(i + 1, path.size() - 1)] - path[max(i - 1, 0)]).normalized()
		if abs(tng.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var nx := tng.cross(up).normalized()
		var ny := nx.cross(tng).normalized()
		up = ny
		var ring: Array = []
		for j in seg:
			var a := TAU * j / seg
			ring.append([path[i] + (nx * cos(a) + ny * sin(a)) * r, (nx * cos(a) + ny * sin(a))])
		rings.append(ring)
	for i in rings.size() - 1:
		for j in seg:
			var j2 := (j + 1) % seg
			var a = rings[i][j]
			var b = rings[i][j2]
			var c = rings[i + 1][j2]
			var d = rings[i + 1][j]
			for k in [[a, j, i], [c, j + 1, i + 1], [d, j, i + 1], [a, j, i], [b, j + 1, i], [c, j + 1, i + 1]]:
				st.set_normal(k[0][1])
				st.set_uv(Vector2(float(k[1]) / seg, float(k[2]) * 0.15))
				st.add_vertex(k[0][0])
	st.generate_tangents()
	return st.commit()


## 两点之间带下垂的软管
static func hose(parent: Node3D, a: Vector3, b: Vector3, sag: Vector3, r := 0.035, m: Material = null) -> MeshInstance3D:
	var mid := (a + b) * 0.5 + sag
	var pts := [a, a.lerp(mid, 0.6) + sag * 0.3, mid, b.lerp(mid, 0.6) + sag * 0.3, b]
	var mi := MeshInstance3D.new()
	mi.mesh = tube(pts, r)
	mi.material_override = m if m else rubber()
	parent.add_child(mi)
	A_end_caps(parent, a, b, r)
	return mi


static func A_end_caps(parent: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	for p in [a, b]:
		add(parent, sphere(r * 1.5, -1, 8), metal(Color(0.5, 0.48, 0.42)), p, Vector3.ZERO, Vector3.ONE, false)


## 一排铆钉。normal_rot：让铆钉圆柱轴朝外的旋转（度）
static func rivets(parent: Node3D, from: Vector3, to: Vector3, n: int, r := 0.022, normal_rot := Vector3(90, 0, 0)) -> void:
	var m := metal(Color(0.35, 0.35, 0.36))
	var mesh := cyl(r, r * 1.2, r * 1.3, 6)
	for i in n:
		var t: float = float(i) / max(1, n - 1)
		add(parent, mesh, m, from.lerp(to, t), normal_rot, Vector3.ONE, false)


## 散热格栅：深色凹槽 + 若干横向叶片。size 的 z 为厚度方向（朝外 = -Z）
static func vent(parent: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO, slats := 5) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	parent.add_child(n)
	add(n, bevel_box(size, 0.015), paint(Color(0.04, 0.04, 0.045), 0.3, 0.8, {"panel_scale": 0.0, "wear": 0.0}), Vector3.ZERO)
	var fr := metal(Color(0.22, 0.22, 0.24))
	for i in slats:
		var y := -size.y * 0.5 + (i + 0.5) * size.y / slats
		add(n, bevel_box(Vector3(size.x * 0.94, size.y / slats * 0.35, size.z * 0.6), 0.008), fr, Vector3(0, y, -size.z * 0.35), Vector3(-30, 0, 0), Vector3.ONE, false)
	return n


## 喷涂字样
static func stencil(parent: Node3D, text: String, pos: Vector3, rot: Vector3, px := 0.004, c := Color(0.92, 0.9, 0.85, 0.85), fs := 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = fs
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = rot
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	parent.add_child(l)
	return l


## 传感器镜头；energy < 0.5 时为不发光的光学镀膜镜片
static func lens(parent: Node3D, pos: Vector3, rot: Vector3, r: float, c := Color(1.0, 0.25, 0.15), energy := 3.0) -> void:
	add(parent, cyl(r * 1.35, r * 0.8, r * 1.45, 12), metal(Color(0.12, 0.12, 0.13)), pos, rot)
	var off := Basis.from_euler(rot * PI / 180.0) * Vector3(0, r * 0.42, 0)
	var mat: Material
	if energy < 0.5:
		var g := StandardMaterial3D.new()
		g.albedo_color = c.darkened(0.15)
		g.metallic = 0.55
		g.roughness = 0.16
		mat = g
	else:
		mat = emit(c, energy)
	add(parent, sphere(r, r * 0.9, 12), mat, pos + off, rot, Vector3.ONE, false)



## 打捞团队徽：圆环 + 三爪抓钩（程序化 SDF 绘制，带做旧斑驳）
static var _emblem: ImageTexture
static func emblem_tex() -> ImageTexture:
	if _emblem:
		return _emblem
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.08
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
			var r := p.length()
			var a := 0.0
			if r > 0.78 and r < 0.95:
				a = 1.0
			# 三爪：从中心向下三条放射线 + 上方横杆
			var ang := atan2(p.y, p.x)
			for k in 3:
				var dir := deg_to_rad(60.0 + k * 30.0)
				var d := absf(sin(ang - dir)) * r
				if d < 0.07 and r < 0.68 and cos(ang - dir) > 0.0:
					a = 1.0
			if absf(p.y + 0.35) < 0.07 and absf(p.x) < 0.45:
				a = 1.0
			if absf(p.x) < 0.07 and p.y < -0.35 and p.y > -0.66:
				a = 1.0
			var worn := nz.get_noise_2d(x, y) * 0.5 + 0.5
			a *= smoothstep(0.25, 0.45, worn)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_emblem = ImageTexture.create_from_image(img)
	return _emblem


static func emblem(parent: Node3D, pos: Vector3, rot: Vector3, size := 0.3, c := Color(0.95, 0.62, 0.18, 0.9)) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = emblem_tex()
	s.pixel_size = size / 128.0
	s.modulate = c
	s.shaded = true
	s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	s.position = pos
	s.rotation_degrees = rot
	parent.add_child(s)
	return s
