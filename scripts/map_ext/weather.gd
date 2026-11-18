extends Node
## 战区天气与时段：读取 raid.MAP.weather 的 preset，改 WorldEnvironment 的天空、雾、平行光与地表色调，
## 并在镜头附近挂一层雨、沙尘、孢子或水汽粒子。这里只做视觉氛围，不改任何玩法数值。
## 沙暴按周期收紧能见度，切换时用 Events.emit_custom("sandstorm", {"active": bool}) 广播。

const A = preload("res://scripts/art.gd")

## 每个预设写全所有会被改动的量，避免共享材质沿用其他战区的颜色
const PRESETS := {
	"clear": {
		"sky_top": Color(0.45, 0.45, 0.42), "sky_horizon": Color(0.68, 0.64, 0.56), "sky_ground": Color(0.42, 0.4, 0.34), "sky_bottom": Color(0.1, 0.08, 0.09), "cloud_tint": Color(0.95, 0.92, 0.86, 0.56),
		"ambient": 0.42, "sun_color": Color(1.0, 0.91, 0.78), "sun_energy": 2.55, "sun_rot": Vector3(-37, 52, 0),
		"fill_color": Color(0.50, 0.62, 0.78), "fill_energy": 0.15,
		"fog_color": Color(0.52, 0.5, 0.44), "fog_density": 0.0009, "fog_vol": 0.0, "exposure": 1.0, "saturation": 0.90,
		"dirt_a": Color(0.47, 0.42, 0.33), "dirt_b": Color(0.33, 0.28, 0.21), "mud": Color(0.27, 0.23, 0.18), "grass": Color(0.31, 0.33, 0.19), "grass2": Color(0.42, 0.4, 0.25),
	},
	"rain": {
		"sky_top": Color(0.3, 0.34, 0.38), "sky_horizon": Color(0.52, 0.55, 0.55), "sky_ground": Color(0.36, 0.38, 0.38), "sky_bottom": Color(0.07, 0.08, 0.09), "cloud_tint": Color(0.68, 0.72, 0.76, 0.74),
		"ambient": 0.44, "sun_color": Color(0.86, 0.9, 0.96), "sun_energy": 2.15, "sun_rot": Vector3(-36, 58, 0),
		"fill_color": Color(0.50, 0.62, 0.78), "fill_energy": 0.18,
		"fog_color": Color(0.52, 0.57, 0.62), "fog_density": 0.0013, "fog_vol": 0.0, "exposure": 1.02, "saturation": 0.84,
		"dirt_a": Color(0.4, 0.39, 0.37), "dirt_b": Color(0.28, 0.28, 0.27), "mud": Color(0.21, 0.21, 0.21), "grass": Color(0.25, 0.29, 0.19), "grass2": Color(0.33, 0.35, 0.25),
	},
	"dusk_gloom": {
		"sky_top": Color(0.34, 0.28, 0.3), "sky_horizon": Color(0.78, 0.55, 0.36), "sky_ground": Color(0.36, 0.3, 0.26), "sky_bottom": Color(0.08, 0.06, 0.07), "cloud_tint": Color(0.96, 0.72, 0.52, 0.62),
		"ambient": 0.40, "sun_color": Color(1.0, 0.74, 0.5), "sun_energy": 2.50, "sun_rot": Vector3(-31, 66, 0),
		"fill_color": Color(0.38, 0.50, 0.70), "fill_energy": 0.16,
		"fog_color": Color(0.52, 0.44, 0.38), "fog_density": 0.0012, "fog_vol": 0.0, "exposure": 1.02, "saturation": 0.88,
		"dirt_a": Color(0.44, 0.38, 0.3), "dirt_b": Color(0.3, 0.26, 0.21), "mud": Color(0.24, 0.2, 0.17), "grass": Color(0.29, 0.28, 0.18), "grass2": Color(0.4, 0.35, 0.22),
	},
	"sandstorm": {
		"sky_top": Color(0.48, 0.42, 0.32), "sky_horizon": Color(0.72, 0.62, 0.46), "sky_ground": Color(0.5, 0.43, 0.32), "sky_bottom": Color(0.14, 0.11, 0.09), "cloud_tint": Color(0.88, 0.76, 0.56, 0.64),
		"ambient": 0.46, "sun_color": Color(1.0, 0.86, 0.62), "sun_energy": 2.55, "sun_rot": Vector3(-37, 62, 0),
		"fill_color": Color(0.56, 0.54, 0.48), "fill_energy": 0.16,
		"fog_color": Color(0.66, 0.56, 0.4), "fog_density": 0.0016, "fog_vol": 0.0, "exposure": 1.0, "saturation": 0.84,
		"dirt_a": Color(0.52, 0.45, 0.32), "dirt_b": Color(0.4, 0.34, 0.24), "mud": Color(0.32, 0.27, 0.2), "grass": Color(0.34, 0.33, 0.18), "grass2": Color(0.46, 0.41, 0.24),
	},
	"lake_mist": {
		"sky_top": Color(0.3, 0.26, 0.36), "sky_horizon": Color(0.62, 0.42, 0.42), "sky_ground": Color(0.34, 0.26, 0.3), "sky_bottom": Color(0.08, 0.05, 0.08), "cloud_tint": Color(0.84, 0.68, 0.70, 0.66),
		"ambient": 0.43, "sun_color": Color(0.95, 0.72, 0.62), "sun_energy": 2.30, "sun_rot": Vector3(-32, -55, 0),
		"fill_color": Color(0.42, 0.55, 0.76), "fill_energy": 0.18,
		"fog_color": Color(0.55, 0.47, 0.5), "fog_density": 0.0015, "fog_vol": 0.0, "exposure": 1.01, "saturation": 0.86,
		"dirt_a": Color(0.36, 0.31, 0.27), "dirt_b": Color(0.24, 0.2, 0.19), "mud": Color(0.2, 0.16, 0.17), "grass": Color(0.22, 0.26, 0.17), "grass2": Color(0.3, 0.31, 0.22),
	},
	"canyon_noon": {
		"sky_top": Color(0.36, 0.44, 0.52), "sky_horizon": Color(0.74, 0.68, 0.56), "sky_ground": Color(0.46, 0.4, 0.32), "sky_bottom": Color(0.1, 0.09, 0.08), "cloud_tint": Color(0.96, 0.94, 0.88, 0.50),
		"ambient": 0.40, "sun_color": Color(1.0, 0.94, 0.8), "sun_energy": 2.75, "sun_rot": Vector3(-40, -52, 0),
		"fill_color": Color(0.48, 0.60, 0.76), "fill_energy": 0.14,
		"fog_color": Color(0.6, 0.55, 0.46), "fog_density": 0.0009, "fog_vol": 0.0, "exposure": 0.98, "saturation": 0.88,
		"dirt_a": Color(0.5, 0.42, 0.32), "dirt_b": Color(0.34, 0.29, 0.22), "mud": Color(0.28, 0.23, 0.18), "grass": Color(0.32, 0.3, 0.17), "grass2": Color(0.44, 0.38, 0.22),
	},
	"spore_abyss": {
		"sky_top": Color(0.11, 0.08, 0.18), "sky_horizon": Color(0.24, 0.16, 0.34), "sky_ground": Color(0.12, 0.08, 0.18), "sky_bottom": Color(0.03, 0.02, 0.05), "cloud_tint": Color(0.32, 0.24, 0.45, 0.48),
		"ambient": 0.48, "sun_color": Color(0.74, 0.62, 0.96), "sun_energy": 1.45, "sun_rot": Vector3(-38, 52, 0),
		"fill_color": Color(0.46, 0.44, 0.86), "fill_energy": 0.22,
		"fog_color": Color(0.20, 0.14, 0.30), "fog_density": 0.0032, "fog_vol": 0.0, "exposure": 1.14, "saturation": 0.96,
		"dirt_a": Color(0.26, 0.21, 0.32), "dirt_b": Color(0.16, 0.12, 0.2), "mud": Color(0.13, 0.09, 0.18), "grass": Color(0.18, 0.1, 0.24), "grass2": Color(0.26, 0.15, 0.32),
	},
}

var raid
var preset := "clear"
var env: Environment
var sky_mat: Material
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var emitters: Array = []
var _base := {}
var _storm := false
var _storm_vis := 0.0
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
	if env and env.sky and env.sky.sky_material != null:
		sky_mat = env.sky.sky_material


func _apply() -> void:
	if env:
		env.ambient_light_energy = float(_base.ambient) * (1.28 if preset == "spore_abyss" else 1.04)
		env.fog_light_color = _base.fog_color
		env.fog_density = float(_base.fog_density) * 0.85
		if preset == "spore_abyss":
			env.fog_aerial_perspective = 0.0
			env.fog_sun_scatter = 0.05
			env.fog_height = 2.0
			env.fog_height_density = 0.025
		elif preset == "rain":
			env.fog_aerial_perspective = 0.52
			env.fog_sun_scatter = 0.22
			env.fog_height = 3.2
			env.fog_height_density = 0.075
		elif preset == "lake_mist":
			env.fog_aerial_perspective = 0.48
			env.fog_sun_scatter = 0.26
			env.fog_height = 4.0
			env.fog_height_density = 0.095
		elif preset == "dusk_gloom":
			env.fog_aerial_perspective = 0.45
			env.fog_sun_scatter = 0.30
			env.fog_height = 2.8
			env.fog_height_density = 0.065
		elif preset == "sandstorm":
			env.fog_aerial_perspective = 0.22
			env.fog_sun_scatter = 0.28
			env.fog_height = 5.5
			env.fog_height_density = 0.050
		else:
			env.fog_aerial_perspective = 0.38
			env.fog_sun_scatter = 0.16
			env.fog_height = 2.0
			env.fog_height_density = 0.040
		env.volumetric_fog_density = float(_base.fog_vol)
		env.volumetric_fog_albedo = _base.fog_color.lightened(0.25)
		env.tonemap_exposure = float(_base.exposure) * 1.04
		env.adjustment_saturation = clampf(float(_base.saturation) + 0.08, 0.90, 1.04)
		env.background_mode = Environment.BG_SKY
		env.fog_sky_affect = 0.65 if preset == "spore_abyss" else 0.34
	var ct: Color = _base.get("cloud_tint", Color(0.92, 0.90, 0.86, 0.58))
	if sky_mat is ShaderMaterial:
		var sm := sky_mat as ShaderMaterial
		sm.set_shader_parameter("sky_top", _base.sky_top)
		sm.set_shader_parameter("sky_horizon", _base.sky_horizon)
		sm.set_shader_parameter("sky_ground", _base.sky_ground)
		sm.set_shader_parameter("sky_bottom", _base.sky_bottom)
		sm.set_shader_parameter("cloud_tint", ct)
		sm.set_shader_parameter("sun_tint", _base.sun_color)
		sm.set_shader_parameter("fog_tint", _base.fog_color)
		sm.set_shader_parameter("cavern_mode", 1.0 if preset == "spore_abyss" else 0.0)
		var urban_w := 0.72 if (raid != null and str(raid.map_id) in ["greyport", "ironbelt", "bayport"]) else 0.16
		sm.set_shader_parameter("urban_horizon", urban_w)
		var drift_spd := 0.0055 if preset == "sandstorm" else (0.0036 if preset == "rain" else 0.0022)
		sm.set_shader_parameter("cloud_drift", drift_spd)
		_storm_vis = 0.22 if preset == "sandstorm" else 0.0
		sm.set_shader_parameter("storm_amount", _storm_vis)
	elif sky_mat is ProceduralSkyMaterial:
		var pm := sky_mat as ProceduralSkyMaterial
		pm.sky_top_color = _base.sky_top
		pm.sky_horizon_color = _base.sky_horizon
		pm.ground_horizon_color = _base.sky_ground
		pm.ground_bottom_color = _base.sky_bottom
		pm.sky_cover_modulate = ct
	if sun:
		sun.light_color = _base.sun_color
		sun.light_energy = float(_base.sun_energy) * 1.05
		sun.rotation_degrees = _base.sun_rot
		RenderingServer.global_shader_parameter_set("sun_dir_world", sun.transform.basis.z.normalized())
	if fill:
		fill.light_color = _base.fill_color
		fill.light_energy = maxf(float(_base.fill_energy) * 1.45, 0.22)
	var wet_v := 1.0 if preset == "rain" else (0.42 if preset == "lake_mist" else (0.18 if preset == "dusk_gloom" else 0.0))
	var rain_v := 1.0 if preset == "rain" else 0.0
	RenderingServer.global_shader_parameter_set("weather_wet", wet_v)
	RenderingServer.global_shader_parameter_set("weather_rain", rain_v)
	var gm: ShaderMaterial = A.ground()
	if gm:
		gm.set_shader_parameter("dirt_a", _base.dirt_a)
		gm.set_shader_parameter("dirt_b", _base.dirt_b)
		gm.set_shader_parameter("mud", _base.mud)
		gm.set_shader_parameter("grass", _base.grass)
		gm.set_shader_parameter("grass2", _base.grass2)
		gm.set_shader_parameter("wet_amt", wet_v)


func _build_particles() -> void:
	match preset:
		"rain": _rain()
		"sandstorm": _sand()
		"lake_mist": _mist()
		"spore_abyss": _spores()
		"dusk_gloom": _mist(0.45)
		"canyon_noon": _dust_lite()
	if preset == "spore_abyss" and (not A.is_mobile_perf() or GameData.quality >= 1):
		_spore_light = OmniLight3D.new()
		_spore_light.light_color = Color(0.55, 0.3, 0.9)
		_spore_light.light_energy = 4.0
		_spore_light.omni_range = 34.0
		add_child(_spore_light)


func _emit(kind: String, opts: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var base_amt := int(opts.get("amount", 200))
	if A.is_mobile_perf():
		var m_mul := 0.16 if GameData.quality == 0 else (0.26 if GameData.quality == 1 else 0.38)
		p.amount = maxi(8, int(round(float(base_amt) * m_mul)))
	else:
		p.amount = base_amt
	p.lifetime = float(opts.get("life", 2.0))
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex: Texture2D = opts.get("tex", A.soft_dot())
	var additive: bool = bool(opts.get("additive", true))
	var prox: float = float(opts.get("prox_fade", -1.0))
	var qm := QuadMesh.new()
	qm.size = opts.get("size", Vector2(0.06, 0.06))
	qm.material = A.particle_mat(tex, additive, prox)
	p.mesh = qm
	if bool(opts.get("align_y", false)):
		p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	elif A._is_cloud_tex(tex):
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -18.0
		p.angular_velocity_max = 18.0
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
	if opts.has("cmid"):
		g.add_point(float(opts.get("cmid_pos", 0.3)), opts.cmid)
	p.color_ramp = g
	if bool(opts.get("ground_fx", false)):
		p.set_meta("ground_fx", true)
	add_child(p)
	emitters.append(p)
	return p


func _rain() -> void:
	_emit("rain", {"amount": 1200, "life": 1.15, "size": Vector2(0.016, 0.88), "dir": Vector3(0.24, -1.0, 0.1), "spread": 2.5,
		"vmin": 34.0, "vmax": 42.0, "gravity": Vector3(0.6, -6.0, 0.3), "box": Vector3(34, 16, 30), "additive": false,
		"align_y": true, "prox_fade": 1.45, "c0": Color(0.76, 0.84, 0.92, 0.30), "c1": Color(0.65, 0.76, 0.88, 0.05)})
	_emit("rain_splash", {"amount": 460, "life": 0.24, "size": Vector2(0.08, 0.18), "dir": Vector3.UP, "spread": 32.0,
		"vmin": 1.4, "vmax": 2.6, "gravity": Vector3(0, -14.0, 0), "box": Vector3(28, 0.15, 24), "additive": false,
		"align_y": true, "prox_fade": 0.04, "ground_fx": true, "c0": Color(0.80, 0.88, 0.96, 0.54), "c1": Color(0.68, 0.78, 0.88, 0.0)})


func _sand() -> void:
	_emit("sand", {"amount": 1200, "life": 2.8, "size": Vector2(0.05, 0.22), "dir": Vector3(1.0, -0.10, 0.35), "spread": 18.0,
		"vmin": 18.0, "vmax": 28.0, "gravity": Vector3(1.2, -0.4, 0.5), "box": Vector3(38, 14, 32), "additive": false,
		"align_y": true, "prox_fade": 0.10, "c0": Color(0.72, 0.62, 0.45, 0.38), "c1": Color(0.65, 0.56, 0.40, 0.06)})
	_emit("sand_gust", {"amount": 100, "life": 4.2, "size": Vector2(4.6, 2.6), "tex": A.dust_tex(), "dir": Vector3(1.0, -0.02, 0.35), "spread": 16.0,
		"vmin": 7.5, "vmax": 12.5, "gravity": Vector3(0.4, 0.0, 0.15), "box": Vector3(36, 4.0, 30), "additive": false,
		"prox_fade": 0.90, "c0": Color(0.70, 0.58, 0.40, 0.0), "cmid": Color(0.66, 0.55, 0.38, 0.11), "c1": Color(0.62, 0.52, 0.36, 0.0)})


func _dust_lite() -> void:
	_emit("dust", {"amount": 420, "life": 4.6, "size": Vector2(0.06, 0.06), "dir": Vector3(1.0, -0.05, 0.2), "spread": 28.0,
		"vmin": 2.2, "vmax": 5.2, "gravity": Vector3(0.3, -0.1, 0.2), "box": Vector3(36, 12, 30), "additive": false,
		"c0": Color(0.66, 0.6, 0.48, 0.20), "c1": Color(0.6, 0.55, 0.44, 0.02)})


func _mist(scale := 1.0) -> void:
	_emit("mist", {"amount": int(140 * scale), "life": 9.0, "size": Vector2(8.5, 5.5), "dir": Vector3(1.0, 0.02, 0.25), "spread": 36.0,
		"vmin": 0.35, "vmax": 0.95, "gravity": Vector3(0.05, 0.02, 0.05), "box": Vector3(38, 4.5, 34), "additive": false,
		"prox_fade": 1.25, "c0": Color(0.62, 0.58, 0.56, 0.0), "cmid": Color(0.62, 0.58, 0.56, 0.075), "c1": Color(0.58, 0.54, 0.54, 0.0), "tex": A.cloud_tex()})


func _spores() -> void:
	_emit("spore", {"amount": 900, "life": 8.0, "size": Vector2(0.16, 0.16), "dir": Vector3(0.1, 1.0, 0.05), "spread": 90.0,
		"vmin": 0.2, "vmax": 0.8, "gravity": Vector3(0.02, 0.06, 0.02), "box": Vector3(34, 10, 30), "additive": true,
		"c0": Color(0.7, 0.42, 1.0, 0.55), "c1": Color(0.25, 0.1, 0.45, 0.0)})


func _process(delta: float) -> void:
	if raid == null or not is_instance_valid(raid) or raid.camera == null:
		return
	var cam: Camera3D = raid.camera
	var focus := cam.global_position + Vector3(0, -16.0, -12.0)
	var ground_focus := Vector3(cam.global_position.x, 0.12, cam.global_position.z - 8.0)
	if raid.has_method("is_first_person") and raid.is_first_person():
		var f_xz: Vector3 = raid.fp_forward_xz()
		var bp: Vector3 = raid.mech.global_position if raid.mech != null else cam.global_position
		focus = bp + f_xz * 12.0 + Vector3(0.0, 6.5, 0.0)
		ground_focus = Vector3(bp.x + f_xz.x * 10.0, bp.y + 0.12, bp.z + f_xz.z * 10.0)
	for e in emitters:
		if is_instance_valid(e):
			e.global_position = ground_focus if e.has_meta("ground_fx") else focus
	if _spore_light:
		var mp: Vector3 = raid.mech.global_position if raid.mech else focus
		_spore_light.global_position = mp + Vector3(0, 7.0, 0)
	if preset == "sandstorm":
		_cycle += delta
		var want := 0.0022
		if _storm:
			want = 0.016
			if _cycle > 24.0:
				_storm = false
				_cycle = 0.0
				Events.emit_custom("sandstorm", {"active": false, "map": raid.map_id})
		elif _cycle > 40.0:
			_storm = true
			_cycle = 0.0
			Events.emit_custom("sandstorm", {"active": true, "map": raid.map_id})
		_fog_want = want
		var storm_target := 0.92 if _storm else 0.22
		_storm_vis = lerpf(_storm_vis, storm_target, clampf(delta * 0.8, 0.0, 1.0))
		if sky_mat is ShaderMaterial:
			(sky_mat as ShaderMaterial).set_shader_parameter("storm_amount", _storm_vis)
	# 雾密度平滑过渡，沙暴起落不会突然糊住画面
	_fog_now = lerpf(_fog_now, _fog_want, clampf(delta * 0.8, 0.0, 1.0))
	if env:
		env.fog_density = _fog_now
		env.volumetric_fog_enabled = false

## 地表材质与全局天气参数都是跨场景共享的：行动结束还原默认值，避免机库与主菜单残留湿润状态。
func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("weather_wet", 0.0)
	RenderingServer.global_shader_parameter_set("weather_rain", 0.0)
	var gm: ShaderMaterial = A.ground()
	if gm == null:
		return
	var d: Dictionary = PRESETS.clear
	gm.set_shader_parameter("dirt_a", d.dirt_a)
	gm.set_shader_parameter("dirt_b", d.dirt_b)
	gm.set_shader_parameter("mud", d.mud)
	gm.set_shader_parameter("grass", d.grass)
	gm.set_shader_parameter("grass2", d.grass2)
	gm.set_shader_parameter("wet_amt", 0.0)
	gm.set_shader_parameter("zone_on", 0.0)
	gm.set_shader_parameter("sector_on", 0.0)
