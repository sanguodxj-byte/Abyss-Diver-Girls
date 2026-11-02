extends Node
## 画面风格切换：写实 / 三渲二。
## 三渲二 = 材质改卡通漫反射+卡通高光（色阶光照） + 全屏深度描边 + 更鲜明的调色。
## 挂在场景根下；开启后新生成的模型（虫子、弹壳、掉落物）也会自动转成卡通材质。

const HULL := """
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;
uniform vec4 line_color : source_color = vec4(0.07, 0.06, 0.08, 1.0);
uniform float width = 0.0022;
void vertex() {
	// 视空间外扩，按距离缩放，保证屏幕上线宽恒定
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vp.xyz += n * width * clamp(-vp.z, 2.0, 140.0);
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() {
	ALBEDO = line_color.rgb;
}
"""
static var _hull_mat: ShaderMaterial

const OUTLINE := """
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.06, 0.05, 0.07, 1.0);
uniform float thickness = 1.3;
uniform float sensitivity = 0.06;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin(vec2 uv, mat4 inv_proj) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(0.0, 0.0, 0.5);  // 兼容渲染器不支持深度纹理，描边仅在 Forward+ 下生效
#else
	float d = texture(depth_tex, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float c = lin(SCREEN_UV, INV_PROJECTION_MATRIX);
	float l = lin(SCREEN_UV + vec2(-px.x, 0.0), INV_PROJECTION_MATRIX);
	float r = lin(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float u = lin(SCREEN_UV + vec2(0.0, -px.y), INV_PROJECTION_MATRIX);
	float d = lin(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	// 二阶差分：只在轮廓/折角处出线，斜坡地面不出线
	float e = abs(l + r - 2.0 * c) + abs(u + d - 2.0 * c);
	float edge = smoothstep(sensitivity * c * 0.5, sensitivity * c, e);
	edge *= 1.0 - smoothstep(120.0, 260.0, c);  // 远景淡出，避免满屏噪线
	if (c > 2000.0) { edge = 0.0; }
	ALBEDO = line_color.rgb;
	ALPHA = edge * line_color.a;
}
"""

var enabled := false
var env: Environment
var outline: MeshInstance3D
var _env_orig := {}
var _scope: Node


static func attach(scope: Node, environment: Environment, cam: Camera3D, on: bool) -> Node:
	var t = (load("res://scripts/toon.gd") as GDScript).new()
	t.name = "ToonStyle"
	t.env = environment
	t._scope = scope
	scope.add_child(t)
	t._make_outline(cam)
	t.set_enabled(on or OS.has_environment("SC_TOON"))
	return t


func _make_outline(cam: Camera3D) -> void:
	outline = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.flip_faces = true
	outline.mesh = q
	outline.extra_cull_margin = 16384.0
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = OUTLINE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = 100
	outline.material_override = m
	outline.position = Vector3(0, 0, -1)
	cam.add_child(outline)


func set_enabled(on: bool) -> void:
	enabled = on
	outline.visible = false  # 深度描边保留备用；默认用外扩描边（所有渲染器一致）
	_style_env(on)
	_convert(_scope, on)
	var tree := get_tree()
	if tree:
		if on and not tree.node_added.is_connected(_on_added):
			tree.node_added.connect(_on_added)
		elif not on and tree.node_added.is_connected(_on_added):
			tree.node_added.disconnect(_on_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_added):
		get_tree().node_added.disconnect(_on_added)


func _on_added(n: Node) -> void:
	if n is GeometryInstance3D and _scope.is_ancestor_of(n):
		_convert_one.call_deferred(n, true)


const ENV_KEYS := ["tonemap_mode", "tonemap_exposure", "adjustment_saturation", "adjustment_contrast",
	"ssao_intensity", "ssil_enabled", "volumetric_fog_density", "fog_density", "glow_intensity", "ambient_light_energy"]


func _style_env(on: bool) -> void:
	if env == null:
		return
	if _env_orig.is_empty():
		for k in ENV_KEYS:
			_env_orig[k] = env.get(k)
	if not on:
		for k in ENV_KEYS:
			env.set(k, _env_orig[k])
		return
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(_env_orig["tonemap_exposure"]) * 1.05
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	env.ssao_intensity = float(_env_orig["ssao_intensity"]) * 0.4
	env.ssil_enabled = false
	env.volumetric_fog_density = float(_env_orig["volumetric_fog_density"]) * 0.5
	env.fog_density = float(_env_orig["fog_density"]) * 0.6
	env.glow_intensity = float(_env_orig["glow_intensity"]) * 1.2
	env.ambient_light_energy = float(_env_orig["ambient_light_energy"]) * 1.25  # 卡通暗部更亮更平


func _convert(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		_convert_one(n, on)
	for c in n.get_children():
		_convert(c, on)


func _convert_one(g: Node, on: bool) -> void:
	if not is_instance_valid(g) or g == outline:
		return
	var gi := g as GeometryInstance3D
	_mat(gi.material_override, on)
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		var mi := gi as MeshInstance3D
		mesh = mi.mesh
		for i in mi.get_surface_override_material_count():
			_mat(mi.get_surface_override_material(i), on)
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	elif gi is CPUParticles3D:
		mesh = (gi as CPUParticles3D).mesh
	if mesh:
		for i in mesh.get_surface_count():
			_mat(mesh.surface_get_material(i), on)


static var _toon_shaders := {}  # 原 Shader -> 卡通版 Shader


static func _toon_shader(src: Shader) -> Shader:
	if _toon_shaders.has(src):
		return _toon_shaders[src]
	var code := src.code
	var out: Shader = null
	if code.find("shader_type spatial") >= 0 and code.find("unshaded") < 0:
		var re := RegEx.new()
		re.compile("render_mode([^;]*);")
		var m := re.search(code)
		if m:
			var modes := []
			for tok in m.get_string(1).split(","):
				var t := tok.strip_edges()
				if t != "" and not t.begins_with("diffuse_") and not t.begins_with("specular_"):
					modes.append(t)
			modes.append("diffuse_toon")
			modes.append("specular_toon")
			code = code.replace(m.get_string(), "render_mode " + ", ".join(modes) + ";")
		else:
			code = code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode diffuse_toon, specular_toon;")
		out = Shader.new()
		out.code = code
	_toon_shaders[src] = out
	return out


func _hull() -> ShaderMaterial:
	if _hull_mat == null:
		var sh := Shader.new()
		sh.code = HULL
		_hull_mat = ShaderMaterial.new()
		_hull_mat.shader = sh
	return _hull_mat


func _mat(m: Material, on: bool) -> void:
	if m is ShaderMaterial and (m as ShaderMaterial).shader and ((m as ShaderMaterial).shader.code.find("ALPHA") >= 0 or (m as ShaderMaterial).shader.code.find("unshaded") >= 0 or (m as ShaderMaterial).shader.code.find("blend_add") >= 0):
		pass
	elif m and not m.get_meta("no_outline", false) and not (m is BaseMaterial3D and ((m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (m as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)):
		if on and m.next_pass == null:
			m.next_pass = _hull()
		elif not on and m.next_pass == _hull_mat:
			m.next_pass = null
	var sm := m as ShaderMaterial
	if sm and sm.shader:
		if on and not sm.has_meta("orig_shader"):
			var ts := _toon_shader(sm.shader)
			if ts:
				sm.set_meta("orig_shader", sm.shader)
				sm.shader = ts
		elif not on and sm.has_meta("orig_shader"):
			sm.shader = sm.get_meta("orig_shader")
			sm.remove_meta("orig_shader")
		return
	var b := m as BaseMaterial3D
	if b == null or b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	b.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON if on else BaseMaterial3D.DIFFUSE_BURLEY
	b.specular_mode = BaseMaterial3D.SPECULAR_TOON if on else BaseMaterial3D.SPECULAR_SCHLICK_GGX
