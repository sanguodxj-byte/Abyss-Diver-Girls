extends Node
## 战区天气与时段：读取 raid.MAP.weather 的 preset，改 WorldEnvironment 的天空、雾、平行光与地表色调，
## 并在镜头附近挂一层雨、沙尘、孢子或水汽粒子。这里只做视觉氛围，不改任何玩法数值。
## 沙暴按周期收紧能见度，切换时用 Events.emit_custom("sandstorm", {"active": bool}) 广播。

const A = preload("res://scripts/art.gd")

## 每个预设写全所有会被改动的量，避免共享材质沿用其他战区的颜色
const PRESETS := {
	"clear": {
		"sky_top": Color(0.45, 0.45, 0.42), "sky_horizon": Color(0.68, 0.64, 0.56), "sky_ground": Color(0.42, 0.4, 0.34), "sky_bottom": Color(0.1, 0.08, 0.09),
		"ambient": 1.0, "sun_color": Color(1.0, 0.9, 0.76), "sun_energy": 1.9, "sun_rot": Vector3(-42, 35, 0),
		"fill_color": Color(0.6, 0.62, 0.66), "fill_energy": 0.45,
		"fog_color": Color(0.52, 0.5, 0.44), "fog_density": 0.004, "fog_vol": 0.008, "exposure": 1.0, "saturation": 0.8,
		"dirt_a": Color(0.47, 0.42, 0.33), "dirt_b": Color(0.33, 0.28, 0.21), "mud": Color(0.27, 0.23, 0.18), "grass": Color(0.31, 0.33, 0.19), "grass2": Color(0.42, 0.4, 0.25),
	},
	"rain": {
		"sky_top": Color(0.3, 0.34, 0.38), "sky_horizon": Color(0.52, 0.55, 0.55), "sky_ground": Color(0.36, 0.38, 0.38), "sky_bottom": Color(0.07, 0.08, 0.09),
		"ambient": 0.95, "sun_color": Color(0.82, 0.87, 0.94), "sun_energy": 1.35, "sun_rot": Vector3(-58, 20, 0),
		"fill_color": Color(0.6, 0.68, 0.76), "fill_energy": 0.5,
		"fog_color": Color(0.55, 0.6, 0.65), "fog_density": 0.0065, "fog_vol": 0.01, "exposure": 1.03, "saturation": 0.68,
		"dirt_a": Color(0.4, 0.39, 0.37), "dirt_b": Color(0.28, 0.28, 0.27), "mud": Color(0.21, 0.21, 0.21), "grass": Color(0.25, 0.29, 0.19), "grass2": Color(0.33, 0.35, 0.25),
	},
	"dusk_gloom": {
		"sky_top": Color(0.34, 0.28, 0.3), "sky_horizon": Color(0.78, 0.55, 0.36), "sky_ground": Color(0.36, 0.3, 0.26), "sky_bottom": Color(0.08, 0.06, 0.07),
		"ambient": 0.9, "sun_color": Color(1.0, 0.72, 0.48), "sun_energy": 1.9, "sun_rot": Vector3(-24, 78, 0),
		"fill_color": Color(0.4, 0.5, 0.66), "fill_energy": 0.55,
		"fog_color": Color(0.52, 0.44, 0.38), "fog_density": 0.006, "fog_vol": 0.01, "exposure": 1.03, "saturation": 0.78,
		"dirt_a": Color(0.44, 0.38, 0.3), "dirt_b": Color(0.3, 0.26, 0.21), "mud": Color(0.24, 0.2, 0.17), "grass": Color(0.29, 0.28, 0.18), "grass2": Color(0.4, 0.35, 0.22),
	},
	"sandstorm": {
		"sky_top": Color(0.48, 0.42, 0.32), "sky_horizon": Color(0.72, 0.62, 0.46), "sky_ground": Color(0.5, 0.43, 0.32), "sky_bottom": Color(0.14, 0.11, 0.09),
		"ambient": 1.05, "sun_color": Color(1.0, 0.86, 0.62), "sun_energy": 2.1, "sun_rot": Vector3(-52, 120, 0),
		"fill_color": Color(0.62, 0.55, 0.44), "fill_energy": 0.4,
		"fog_color": Color(0.66, 0.56, 0.4), "fog_density": 0.006, "fog_vol": 0.012, "exposure": 1.02, "saturation": 0.7,
		"dirt_a": Color(0.52, 0.45, 0.32), "dirt_b": Color(0.4, 0.34, 0.24), "mud": Color(0.32, 0.27, 0.2), "grass": Color(0.34, 0.33, 0.18), "grass2": Color(0.46, 0.41, 0.24),
	},
	"lake_mist": {
		"sky_top": Color(0.3, 0.26, 0.36), "sky_horizon": Color(0.62, 0.42, 0.42), "sky_ground": Color(0.34, 0.26, 0.3), "sky_bottom": Color(0.08, 0.05, 0.08),
		"ambient": 0.88, "sun_color": Color(0.95, 0.68, 0.6), "sun_energy": 1.7, "sun_rot": Vector3(-18, -40, 0),
		"fill_color": Color(0.45, 0.55, 0.72), "fill_energy": 0.6,
		"fog_color": Color(0.55, 0.47, 0.5), "fog_density": 0.007, "fog_vol": 0.012, "exposure": 1.02, "saturation": 0.76,
		"dirt_a": Color(0.36, 0.31, 0.27), "dirt_b": Color(0.24, 0.2, 0.19), "mud": Color(0.2, 0.16, 0.17), "grass": Color(0.22, 0.26, 0.17), "grass2": Color(0.3, 0.31, 0.22),
	},
	"canyon_noon": {
		"sky_top": Color(0.36, 0.44, 0.52), "sky_horizon": Color(0.74, 0.68, 0.56), "sky_ground": Color(0.46, 0.4, 0.32), "sky_bottom": Color(0.1, 0.09, 0.08),
		"ambient": 0.92, "sun_color": Color(1.0, 0.94, 0.8), "sun_energy": 2.4, "sun_rot": Vector3(-70, -20, 0),
		"fill_color": Color(0.55, 0.62, 0.72), "fill_energy": 0.35,
		"fog_color": Color(0.6, 0.55, 0.46), "fog_density": 0.003, "fog_vol": 0.006, "exposure": 0.98, "saturation": 0.74,
		"dirt_a": Color(0.5, 0.42, 0.32), "dirt_b": Color(0.34, 0.29, 0.22), "mud": Color(0.28, 0.23, 0.18), "grass": Color(0.32, 0.3, 0.17), "grass2": Color(0.44, 0.38, 0.22),
	},
	"spore_abyss": {
		"sky_top": Color(0.06, 0.04, 0.1), "sky_horizon": Color(0.16, 0.1, 0.22), "sky_ground": Color(0.08, 0.05, 0.12), "sky_bottom": Color(0.02, 0.015, 0.03),
		"ambient": 0.62, "sun_color": Color(0.6, 0.5, 0.9), "sun_energy": 0.55, "sun_rot": Vector3(-62, 10, 0),
		"fill_color": Color(0.45, 0.38, 0.8), "fill_energy": 0.55,
		"fog_color": Color(0.16, 0.1, 0.24), "fog_density": 0.012, "fog_vol": 0.02, "exposure": 1.15, "saturation": 0.95,
		"dirt_a": Color(0.26, 0.21, 0.32), "dirt_b": Color(0.16, 0.12, 0.2), "mud": Color(0.13, 0.09, 0.18), "grass": Color(0.18, 0.1, 0.24), "grass2": Color(0.26, 0.15, 0.32),
	},
}

var raid
var preset := "clear"
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var emitters: Array = []
var _base := {}
var _storm := false
var _cycle := 0.0
var _fog_now := 0.0
var _fog_want := 0.0
var _spore_light: OmniLight3D


func setup(r) -> void:
	raid = r
	var w: Dictionary = r.MAP.get("weather", {})
	preset = str(w.get("preset", "clear"))
	_base = PRESETS.get(preset, PRESETS.clear).duplicate()
	for k in w:
		if k != "preset":
			_base[k] = w[k]
	_find()
	_apply()
	_build_particles()
	_fog_now = float(_base.fog_density)
	_fog_want = _fog_now
	set_meta("preset", preset)
	Events.emit_custom("weather_changed", {"preset": preset, "map": r.map_id})


func _find() -> void:
	for c in raid.get_children():
		if c is WorldEnvironment:
			env = c.environment
		elif c is DirectionalLight3D and not c.shadow_enabled:
			fill = c
		elif c is DirectionalLight3D and sun == null:
			sun = c
	if env and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		sky_mat = env.sky.sky_material


func _apply() -> void:
	if env:
		env.ambient_light_energy = float(_base.ambient)
		env.fog_light_color = _base.fog_color
		env.fog_density = float(_base.fog_density)
		env.volumetric_fog_density = float(_base.fog_vol)
		env.volumetric_fog_albedo = _base.fog_color.lightened(0.25)
		env.tonemap_exposure = float(_base.exposure)
		env.adjustment_saturation = float(_base.saturation)
		if preset == "spore_abyss":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.015, 0.01, 0.025)
			env.fog_sky_affect = 0.0
	if sky_mat:
		sky_mat.sky_top_color = _base.sky_top
		sky_mat.sky_horizon_color = _base.sky_horizon
		sky_mat.ground_horizon_color = _base.sky_ground
		sky_mat.ground_bottom_color = _base.sky_bottom
	if sun:
		sun.light_color = _base.sun_color
		sun.light_energy = float(_base.sun_energy)
		sun.rotation_degrees = _base.sun_rot
	if fill:
		fill.light_color = _base.fill_color
		fill.light_energy = float(_base.fill_energy)
	var gm: ShaderMaterial = A.ground()
	if gm:
		gm.set_shader_parameter("dirt_a", _base.dirt_a)
		gm.set_shader_parameter("dirt_b", _base.dirt_b)
		gm.set_shader_parameter("mud", _base.mud)
		gm.set_shader_parameter("grass", _base.grass)
		gm.set_shader_parameter("grass2", _base.grass2)


func _build_particles() -> void:
	match preset:
		"rain": _rain()
		"sandstorm": _sand()
		"lake_mist": _mist()
		"spore_abyss": _spores()
		"dusk_gloom": _mist(0.45)
		"canyon_noon": _dust_lite()
	if preset == "spore_abyss":
		_spore_light = OmniLight3D.new()
		_spore_light.light_color = Color(0.55, 0.3, 0.9)
		_spore_light.light_energy = 4.0
		_spore_light.omni_range = 34.0
		add_child(_spore_light)
	# 雨天在地面上留一层水洼
	if preset == "rain":
		for i in 70:
			var q = Vector3(raid.rng.randf_range(-170, 170), 0.025, raid.rng.randf_range(-170, 170))
			A.ground_decal(raid.world, A.cloud_tex(), Color(0.06, 0.08, 0.1, raid.rng.randf_range(0.2, 0.42)), raid.rng.randf_range(1.6, 4.6), q)


func _emit(kind: String, opts: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(opts.get("amount", 200))
	p.lifetime = float(opts.get("life", 2.0))
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var qm := QuadMesh.new()
	qm.size = opts.get("size", Vector2(0.06, 0.06))
	qm.material = A.particle_mat(opts.get("tex", A.soft_dot()), bool(opts.get("additive", true)))
	p.mesh = qm
	p.direction = opts.get("dir", Vector3.DOWN)
	p.spread = float(opts.get("spread", 10.0))
	p.initial_velocity_min = float(opts.get("vmin", 4.0))
	p.initial_velocity_max = float(opts.get("vmax", 8.0))
	p.gravity = opts.get("gravity", Vector3.ZERO)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX if opts.has("box") else CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_box_extents = opts.get("box", Vector3.ONE * 20.0)
	p.emission_sphere_radius = float(opts.get("radius", 24.0))
	var g := Gradient.new()
	g.set_color(0, opts.get("c0", Color(1, 1, 1, 0.5)))
	g.set_color(1, opts.get("c1", Color(1, 1, 1, 0.0)))
	p.color_ramp = g
	add_child(p)
	emitters.append(p)
	return p


func _rain() -> void:
	_emit("rain", {"amount": 2400, "life": 1.3, "size": Vector2(0.03, 0.9), "dir": Vector3(0.28, -1.0, 0.12), "spread": 4.0,
		"vmin": 30.0, "vmax": 38.0, "gravity": Vector3(0.6, -6.0, 0.3), "box": Vector3(34, 16, 30), "additive": false,
		"c0": Color(0.72, 0.8, 0.88, 0.42), "c1": Color(0.6, 0.72, 0.85, 0.06)})


func _sand() -> void:
	_emit("sand", {"amount": 1500, "life": 3.2, "size": Vector2(0.09, 0.09), "dir": Vector3(1.0, -0.12, 0.35), "spread": 22.0,
		"vmin": 16.0, "vmax": 26.0, "gravity": Vector3(1.2, -0.4, 0.5), "box": Vector3(38, 14, 32), "additive": false,
		"c0": Color(0.62, 0.54, 0.4, 0.42), "c1": Color(0.6, 0.52, 0.38, 0.1)})


func _dust_lite() -> void:
	_emit("dust", {"amount": 500, "life": 5.0, "size": Vector2(0.07, 0.07), "dir": Vector3(1.0, -0.05, 0.2), "spread": 30.0,
		"vmin": 2.0, "vmax": 5.0, "gravity": Vector3(0.3, -0.1, 0.2), "box": Vector3(36, 12, 30), "additive": false,
		"c0": Color(0.66, 0.6, 0.48, 0.22), "c1": Color(0.6, 0.55, 0.44, 0.03)})


func _mist(scale := 1.0) -> void:
	_emit("mist", {"amount": int(160 * scale), "life": 9.0, "size": Vector2(9.0, 6.0), "dir": Vector3(1.0, 0.02, 0.25), "spread": 40.0,
		"vmin": 0.3, "vmax": 0.9, "gravity": Vector3(0.05, 0.02, 0.05), "box": Vector3(38, 5, 34), "additive": false,
		"c0": Color(0.62, 0.58, 0.56, 0.10), "c1": Color(0.58, 0.54, 0.54, 0.0), "tex": A.cloud_tex()})


func _spores() -> void:
	_emit("spore", {"amount": 900, "life": 8.0, "size": Vector2(0.16, 0.16), "dir": Vector3(0.1, 1.0, 0.05), "spread": 90.0,
		"vmin": 0.2, "vmax": 0.8, "gravity": Vector3(0.02, 0.06, 0.02), "box": Vector3(34, 10, 30), "additive": true,
		"c0": Color(0.7, 0.42, 1.0, 0.55), "c1": Color(0.25, 0.1, 0.45, 0.0)})


func _process(delta: float) -> void:
	if raid == null or not is_instance_valid(raid) or raid.camera == null:
		return
	var cam: Camera3D = raid.camera
	var focus := cam.global_position + Vector3(0, -12.0, -16.0)
	for e in emitters:
		if is_instance_valid(e):
			e.global_position = focus
	if _spore_light:
		var mp: Vector3 = raid.mech.global_position if raid.mech else focus
		_spore_light.global_position = mp + Vector3(0, 7.0, 0)
	if preset == "sandstorm":
		_cycle += delta
		var want := 0.006
		if _storm:
			want = 0.032
			if _cycle > 24.0:
				_storm = false
				_cycle = 0.0
				Events.emit_custom("sandstorm", {"active": false, "map": raid.map_id})
		elif _cycle > 40.0:
			_storm = true
			_cycle = 0.0
			Events.emit_custom("sandstorm", {"active": true, "map": raid.map_id})
		_fog_want = want
	# 雾密度平滑过渡，沙暴起落不会突然糊住画面
	_fog_now = lerpf(_fog_now, _fog_want, clampf(delta * 0.8, 0.0, 1.0))
	if env:
		env.fog_density = _fog_now
		env.volumetric_fog_density = _fog_now * 1.6

## 地表材质是全局共享的：行动结束把色调还原成默认值，机库与主菜单的地面不会带着上一局的颜色。
func _exit_tree() -> void:
	var gm: ShaderMaterial = A.ground()
	if gm == null:
		return
	var d: Dictionary = PRESETS.clear
	gm.set_shader_parameter("dirt_a", d.dirt_a)
	gm.set_shader_parameter("dirt_b", d.dirt_b)
	gm.set_shader_parameter("mud", d.mud)
	gm.set_shader_parameter("grass", d.grass)
	gm.set_shader_parameter("grass2", d.grass2)
