extends Node
## 战区天气与时段：读取 raid.MAP.weather 的 preset，改 WorldEnvironment 的天空、雾、平行光与地表色调，
## 并在镜头附近挂一层雨、沙尘、孢子或水汽粒子。这里只做视觉氛围，不改任何玩法数值。
## 沙暴按周期收紧能见度，切换时用 Events.emit_custom("sandstorm", {"active": bool}) 广播。

const A = preload("res://scripts/art.gd")
const VistaScript = preload("res://scripts/vista.gd")

## 每个预设写全所有会被改动的量，避免共享材质沿用其他战区的颜色（对标《B.o.T》UE4 军工写实日照：高穿透日光金属高光 × 饱满天光漫射暗部零死黑 × 自然晒白地表与远景空气透视）
## 深度雾 (FOG_MODE_DEPTH)：近距 34m 内 100% 锐利 + 中远距自然空气透视分层 + 地平线无痕融入天空。
const PRESETS := {
	"clear": {
		"sky_top": Color(0.22, 0.34, 0.52), "sky_horizon": Color(0.56, 0.60, 0.65), "sky_ground": Color(0.36, 0.36, 0.35), "sky_bottom": Color(0.18, 0.20, 0.24), "cloud_tint": Color(0.76, 0.79, 0.83, 0.68),
		"ambient": 0.60, "sun_color": Color(1.00, 0.94, 0.85), "sun_energy": 1.92, "sun_rot": Vector3(-38, 48, 0), "sun_angular": 0.62,
		"fill_color": Color(0.58, 0.70, 0.86), "fill_energy": 0.42,
		"fog_color": Color(0.52, 0.56, 0.61), "fog_density": 0.0012, "fog_depth_begin": 38.0, "fog_depth_end": 490.0, "fog_depth_curve": 1.44, "fog_depth_density": 0.56,
		"fog_aerial": 0.78, "fog_sun_scatter": 0.18, "fog_height": 2.2, "fog_height_density": 0.010, "fog_sky_affect": 0.12, "fog_vol": 0.0, "exposure": 0.86, "saturation": 0.98,
		"dirt_a": Color(0.40, 0.38, 0.34), "dirt_b": Color(0.31, 0.29, 0.26), "mud": Color(0.24, 0.23, 0.21), "grass": Color(0.24, 0.29, 0.20), "grass2": Color(0.31, 0.33, 0.23),
	},
	"rain": {
		"sky_top": Color(0.20, 0.27, 0.36), "sky_horizon": Color(0.45, 0.50, 0.56), "sky_ground": Color(0.29, 0.32, 0.36), "sky_bottom": Color(0.15, 0.17, 0.21), "cloud_tint": Color(0.66, 0.71, 0.76, 0.84),
		"ambient": 0.62, "sun_color": Color(0.86, 0.91, 0.98), "sun_energy": 1.40, "sun_rot": Vector3(-40, 52, 0), "sun_angular": 1.10,
		"fill_color": Color(0.56, 0.68, 0.82), "fill_energy": 0.40,
		"fog_color": Color(0.43, 0.48, 0.54), "fog_density": 0.0016, "fog_depth_begin": 30.0, "fog_depth_end": 400.0, "fog_depth_curve": 1.38, "fog_depth_density": 0.64,
		"fog_aerial": 0.76, "fog_sun_scatter": 0.12, "fog_height": 2.6, "fog_height_density": 0.014, "fog_sky_affect": 0.15, "fog_vol": 0.0, "exposure": 0.84, "saturation": 0.96,
		"dirt_a": Color(0.34, 0.33, 0.30), "dirt_b": Color(0.26, 0.25, 0.23), "mud": Color(0.20, 0.20, 0.19), "grass": Color(0.22, 0.27, 0.19), "grass2": Color(0.28, 0.30, 0.22),
	},
	"dusk_gloom": {
		"sky_top": Color(0.20, 0.28, 0.42), "sky_horizon": Color(0.62, 0.51, 0.41), "sky_ground": Color(0.35, 0.32, 0.30), "sky_bottom": Color(0.16, 0.18, 0.22), "cloud_tint": Color(0.74, 0.65, 0.56, 0.70),
		"ambient": 0.58, "sun_color": Color(1.00, 0.85, 0.66), "sun_energy": 1.85, "sun_rot": Vector3(-30, 58, 0), "sun_angular": 0.72,
		"fill_color": Color(0.55, 0.67, 0.84), "fill_energy": 0.42,
		"fog_color": Color(0.50, 0.46, 0.43), "fog_density": 0.0014, "fog_depth_begin": 34.0, "fog_depth_end": 450.0, "fog_depth_curve": 1.40, "fog_depth_density": 0.58,
		"fog_aerial": 0.76, "fog_sun_scatter": 0.20, "fog_height": 2.4, "fog_height_density": 0.012, "fog_sky_affect": 0.14, "fog_vol": 0.0, "exposure": 0.86, "saturation": 0.98,
		"dirt_a": Color(0.38, 0.35, 0.31), "dirt_b": Color(0.30, 0.27, 0.24), "mud": Color(0.23, 0.21, 0.19), "grass": Color(0.24, 0.27, 0.19), "grass2": Color(0.30, 0.30, 0.22),
	},
	"sandstorm": {
		"sky_top": Color(0.34, 0.36, 0.40), "sky_horizon": Color(0.64, 0.57, 0.48), "sky_ground": Color(0.42, 0.37, 0.31), "sky_bottom": Color(0.20, 0.18, 0.17), "cloud_tint": Color(0.74, 0.68, 0.58, 0.72),
		"ambient": 0.60, "sun_color": Color(1.00, 0.89, 0.74), "sun_energy": 1.88, "sun_rot": Vector3(-36, 56, 0), "sun_angular": 0.90,
		"fill_color": Color(0.60, 0.64, 0.72), "fill_energy": 0.42,
		"fog_color": Color(0.56, 0.51, 0.43), "fog_density": 0.0018, "fog_depth_begin": 30.0, "fog_depth_end": 400.0, "fog_depth_curve": 1.38, "fog_depth_density": 0.64,
		"fog_aerial": 0.72, "fog_sun_scatter": 0.20, "fog_height": 3.0, "fog_height_density": 0.014, "fog_sky_affect": 0.16, "fog_vol": 0.0, "exposure": 0.85, "saturation": 0.97,
		"dirt_a": Color(0.44, 0.39, 0.33), "dirt_b": Color(0.35, 0.31, 0.26), "mud": Color(0.26, 0.23, 0.20), "grass": Color(0.27, 0.28, 0.20), "grass2": Color(0.33, 0.31, 0.23),
	},
	"lake_mist": {
		"sky_top": Color(0.21, 0.31, 0.44), "sky_horizon": Color(0.54, 0.57, 0.61), "sky_ground": Color(0.34, 0.35, 0.37), "sky_bottom": Color(0.17, 0.19, 0.22), "cloud_tint": Color(0.72, 0.73, 0.76, 0.72),
		"ambient": 0.60, "sun_color": Color(0.96, 0.91, 0.83), "sun_energy": 1.85, "sun_rot": Vector3(-36, -52, 0), "sun_angular": 0.85,
		"fill_color": Color(0.56, 0.67, 0.80), "fill_energy": 0.42,
		"fog_color": Color(0.50, 0.53, 0.57), "fog_density": 0.0016, "fog_depth_begin": 32.0, "fog_depth_end": 420.0, "fog_depth_curve": 1.38, "fog_depth_density": 0.62,
		"fog_aerial": 0.76, "fog_sun_scatter": 0.18, "fog_height": 2.8, "fog_height_density": 0.014, "fog_sky_affect": 0.15, "fog_vol": 0.0, "exposure": 0.85, "saturation": 0.97,
		"dirt_a": Color(0.37, 0.36, 0.33), "dirt_b": Color(0.29, 0.28, 0.26), "mud": Color(0.22, 0.21, 0.20), "grass": Color(0.23, 0.28, 0.20), "grass2": Color(0.29, 0.31, 0.23),
	},
	"canyon_noon": {
		"sky_top": Color(0.24, 0.36, 0.54), "sky_horizon": Color(0.62, 0.59, 0.53), "sky_ground": Color(0.42, 0.37, 0.32), "sky_bottom": Color(0.20, 0.19, 0.18), "cloud_tint": Color(0.78, 0.75, 0.70, 0.58),
		"ambient": 0.58, "sun_color": Color(1.00, 0.93, 0.83), "sun_energy": 2.00, "sun_rot": Vector3(-40, -48, 0), "sun_angular": 0.60,
		"fill_color": Color(0.57, 0.68, 0.84), "fill_energy": 0.42,
		"fog_color": Color(0.55, 0.52, 0.47), "fog_density": 0.0012, "fog_depth_begin": 38.0, "fog_depth_end": 490.0, "fog_depth_curve": 1.44, "fog_depth_density": 0.54,
		"fog_aerial": 0.78, "fog_sun_scatter": 0.18, "fog_height": 2.0, "fog_height_density": 0.010, "fog_sky_affect": 0.11, "fog_vol": 0.0, "exposure": 0.86, "saturation": 0.98,
		"dirt_a": Color(0.43, 0.39, 0.33), "dirt_b": Color(0.34, 0.30, 0.25), "mud": Color(0.25, 0.22, 0.19), "grass": Color(0.26, 0.28, 0.20), "grass2": Color(0.33, 0.32, 0.24),
	},
	"spore_abyss": {
		"sky_top": Color(0.11, 0.10, 0.21), "sky_horizon": Color(0.24, 0.20, 0.36), "sky_ground": Color(0.15, 0.13, 0.23), "sky_bottom": Color(0.06, 0.06, 0.10), "cloud_tint": Color(0.36, 0.31, 0.48, 0.60),
		"ambient": 0.56, "sun_color": Color(0.78, 0.72, 0.96), "sun_energy": 1.55, "sun_rot": Vector3(-35, 52, 0), "sun_angular": 1.20,
		"fill_color": Color(0.46, 0.52, 0.78), "fill_energy": 0.36,
		"fog_color": Color(0.20, 0.16, 0.30), "fog_density": 0.0032, "fog_depth_begin": 26.0, "fog_depth_end": 340.0, "fog_depth_curve": 1.42, "fog_depth_density": 0.80,
		"fog_aerial": 0.24, "fog_sun_scatter": 0.08, "fog_height": 2.0, "fog_height_density": 0.015, "fog_sky_affect": 0.20, "fog_vol": 0.0, "exposure": 0.86, "saturation": 0.98,
		"dirt_a": Color(0.25, 0.22, 0.30), "dirt_b": Color(0.18, 0.16, 0.22), "mud": Color(0.13, 0.12, 0.17), "grass": Color(0.16, 0.13, 0.23), "grass2": Color(0.22, 0.18, 0.28),
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
var _depth_begin_now := 30.0
var _depth_begin_want := 30.0
var _depth_end_now := 560.0
var _depth_end_want := 560.0
var _depth_curve_now := 1.58
var _depth_curve_want := 1.58
var _aerial_now := 0.66
var _aerial_want := 0.66
var _sky_affect_now := 0.16
var _sky_affect_want := 0.16
var _spore_light: OmniLight3D


func setup(r) -> void:
	raid = r
	var w: Dictionary = r.MAP.get("weather", {})
	preset = str(w.get("preset", "clear"))
	var preset_src: Dictionary = PRESETS.get(preset, PRESETS.clear)
	var base_legacy_fog := float(preset_src.get("fog_density", 0.0015))
	_base = preset_src.duplicate()
	for k in w:
		if k != "preset":
			_base[k] = w[k]
	# 兼容战区配置里沿用的旧版指数雾 fog_density（< 0.05，例如东湾 0.0016）：换算为深度雾终点缩放，避免把深度雾上限写成 0.0016
	if w.has("fog_density") and not w.has("fog_depth_end"):
		var ov_fog := float(w["fog_density"])
		if ov_fog > 1e-6 and ov_fog < 0.05:
			var ratio := clampf(base_legacy_fog / ov_fog, 0.72, 1.28)
			_base["fog_depth_end"] = float(preset_src.get("fog_depth_end", 640.0)) * ratio
		elif ov_fog >= 0.05 and not w.has("fog_depth_density"):
			_base["fog_depth_density"] = clampf(ov_fog, 0.0, 1.0)
	_find()
	_apply()
	_build_particles()
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
	var mob_far_cap := 570.0 if A.is_mobile_perf() else 1200.0
	var d_begin := float(_base.get("fog_depth_begin", 36.0))
	var d_end := minf(float(_base.get("fog_depth_end", 680.0)), mob_far_cap)
	var d_curve := float(_base.get("fog_depth_curve", 1.62))
	var d_dens := clampf(float(_base.get("fog_depth_density", 0.96)), 0.0, 1.0)
	var d_aerial := clampf(float(_base.get("fog_aerial", 0.72)), 0.0, 1.0)
	var d_scatter := clampf(float(_base.get("fog_sun_scatter", 0.20)), 0.0, 1.0)
	var d_height := float(_base.get("fog_height", 2.2))
	var d_hdens := float(_base.get("fog_height_density", 0.016))
	var d_sky_aff := clampf(float(_base.get("fog_sky_affect", 0.12)), 0.0, 1.0)
	if env:
		var fill_comp := float(_base.get("fill_energy", 0.24)) * 0.45 if fill == null else 0.0
		env.ambient_light_energy = float(_base.ambient) * (1.15 if preset == "spore_abyss" else 1.0) + fill_comp
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = _base.fog_color
		env.fog_density = d_dens
		env.fog_depth_begin = d_begin
		env.fog_depth_end = d_end
		env.fog_depth_curve = d_curve
		env.fog_aerial_perspective = d_aerial
		env.fog_sun_scatter = d_scatter
		env.fog_height = d_height
		env.fog_height_density = d_hdens
		env.volumetric_fog_enabled = false
		env.volumetric_fog_density = float(_base.fog_vol)
		env.volumetric_fog_albedo = _base.fog_color.lightened(0.20)
		env.tonemap_exposure = float(_base.exposure)
		env.adjustment_saturation = clampf(float(_base.saturation), 0.80, 1.12)
		env.background_mode = Environment.BG_SKY
		env.fog_sky_affect = d_sky_aff
	_fog_now = d_dens
	_fog_want = d_dens
	_depth_begin_now = d_begin
	_depth_begin_want = d_begin
	_depth_end_now = d_end
	_depth_end_want = d_end
	_depth_curve_now = d_curve
	_depth_curve_want = d_curve
	_aerial_now = d_aerial
	_aerial_want = d_aerial
	_sky_affect_now = d_sky_aff
	_sky_affect_want = d_sky_aff
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
		var mid := str(raid.map_id) if raid != null else ""
		var urban_w := 0.72 if mid in ["greyport", "ironbelt", "bayport"] else 0.16
		sm.set_shader_parameter("urban_horizon", urban_w)
		var ocean_east := 1.0 if mid in ["bayport", "ironbelt"] else 0.0
		sm.set_shader_parameter("ocean_east_mask", ocean_east)
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
		sun.light_energy = float(_base.sun_energy)
		sun.rotation_degrees = _base.sun_rot
		var ang_base := float(_base.get("sun_angular", 0.75))
		sun.light_angular_distance = ang_base * (0.72 if GameData.quality == 0 else 1.0)
		RenderingServer.global_shader_parameter_set("sun_dir_world", sun.transform.basis.z.normalized())
	if fill:
		fill.light_color = _base.fill_color
		fill.light_energy = float(_base.fill_energy)
		var srot: Vector3 = _base.sun_rot
		fill.rotation_degrees = Vector3(-32.0, srot.y + 180.0, 0.0)
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
	# 纯干燥/无水面地貌关闭全屏 SSR 光线步进（节省整屏 GPU 反射开销，湿润/河港战区保留 SSR）
	if env and preset in ["sandstorm", "canyon_noon", "spore_abyss"]:
		env.ssr_enabled = false
	# 同步三层远景 HLOD 大气透视雾化色，让 150~760m 远景楼群与林海平滑融入当前战区地平线雾气
	var vista_haze_c: Color = (_base.sky_horizon as Color).lerp(_base.fog_color as Color, 0.52)
	var vista_haze_str := clampf(d_dens * 0.94, 0.46, 0.80)
	if preset == "sandstorm":
		vista_haze_str = 0.86
	elif preset == "lake_mist" or preset == "rain":
		vista_haze_str = 0.74
	VistaScript.set_haze(vista_haze_c, maxf(135.0, d_begin * 3.2), maxf(560.0, d_end * 1.35), vista_haze_str)
	# 植被随战区生态色调微调，消除裂谷/荒原沙地上的冷黑点反差（适配新版 1024px 高密枝叶贴图）
	var far_gcol: Color = (_base.dirt_a as Color) if preset in ["canyon_noon", "sandstorm", "spore_abyss"] else (_base.dirt_a as Color).lerp(_base.grass as Color, 0.28)
	var sh_m: ShaderMaterial = A.foliage_mat("shrub")
	if sh_m:
		sh_m.set_shader_parameter("far_ground_col", far_gcol)
		match preset:
			"canyon_noon", "sandstorm":
				sh_m.set_shader_parameter("tint_a", Color(0.84, 0.84, 0.80))
				sh_m.set_shader_parameter("tint_b", Color(0.92, 0.88, 0.78))
				sh_m.set_shader_parameter("albedo_gain", 1.38)
			"dusk_gloom":
				sh_m.set_shader_parameter("tint_a", Color(0.80, 0.82, 0.78))
				sh_m.set_shader_parameter("tint_b", Color(0.90, 0.86, 0.76))
				sh_m.set_shader_parameter("albedo_gain", 1.36)
			"spore_abyss":
				sh_m.set_shader_parameter("tint_a", Color(0.76, 0.74, 0.96))
				sh_m.set_shader_parameter("tint_b", Color(0.88, 0.84, 1.04))
				sh_m.set_shader_parameter("albedo_gain", 1.54)
			_:
				sh_m.set_shader_parameter("tint_a", Color(0.80, 0.84, 0.80))
				sh_m.set_shader_parameter("tint_b", Color(0.90, 0.88, 0.78))
				sh_m.set_shader_parameter("albedo_gain", 1.38)
	var gr_m: ShaderMaterial = A.foliage_mat("grass")
	if gr_m:
		gr_m.set_shader_parameter("far_ground_col", far_gcol)
		match preset:
			"canyon_noon", "sandstorm":
				gr_m.set_shader_parameter("tint_a", Color(0.82, 0.84, 0.84))
				gr_m.set_shader_parameter("tint_b", Color(0.90, 0.86, 0.80))
				gr_m.set_shader_parameter("albedo_gain", 2.08)
			"dusk_gloom":
				gr_m.set_shader_parameter("tint_a", Color(0.80, 0.82, 0.80))
				gr_m.set_shader_parameter("tint_b", Color(0.88, 0.84, 0.78))
				gr_m.set_shader_parameter("albedo_gain", 2.05)
			"spore_abyss":
				gr_m.set_shader_parameter("tint_a", Color(0.80, 0.78, 1.00))
				gr_m.set_shader_parameter("tint_b", Color(0.92, 0.88, 1.08))
				gr_m.set_shader_parameter("albedo_gain", 2.25)
			_:
				gr_m.set_shader_parameter("tint_a", Color(0.76, 0.82, 0.78))
				gr_m.set_shader_parameter("tint_b", Color(0.86, 0.88, 0.78))
				gr_m.set_shader_parameter("albedo_gain", 2.08)


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
		var d_mul := 0.45 if GameData.quality == 0 else (0.72 if GameData.quality == 1 else 1.0)
		p.amount = maxi(8, int(round(float(base_amt) * d_mul)))
	p.lifetime = float(opts.get("life", 2.0))
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex: Texture2D = opts.get("tex", A.soft_dot())
	var additive: bool = bool(opts.get("additive", true))
	var prox: float = float(opts.get("prox_fade", -1.0))
	var qm := QuadMesh.new()
	qm.size = opts.get("size", Vector2(0.06, 0.06))
	if bool(opts.get("no_prox_fade", false)):
		var pm := StandardMaterial3D.new()
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.vertex_color_use_as_albedo = true
		pm.albedo_texture = tex
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		pm.billboard_keep_scale = true
		pm.proximity_fade_enabled = false
		if additive:
			pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pm.cull_mode = BaseMaterial3D.CULL_DISABLED
		qm.material = pm
	else:
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
		"align_y": true, "no_prox_fade": true, "c0": Color(0.76, 0.84, 0.92, 0.30), "c1": Color(0.65, 0.76, 0.88, 0.05)})
	_emit("rain_splash", {"amount": 460, "life": 0.24, "size": Vector2(0.08, 0.18), "dir": Vector3.UP, "spread": 32.0,
		"vmin": 1.4, "vmax": 2.6, "gravity": Vector3(0, -14.0, 0), "box": Vector3(28, 0.15, 24), "additive": false,
		"align_y": true, "no_prox_fade": true, "ground_fx": true, "c0": Color(0.80, 0.88, 0.96, 0.54), "c1": Color(0.68, 0.78, 0.88, 0.0)})


func _sand() -> void:
	_emit("sand", {"amount": 1200, "life": 2.8, "size": Vector2(0.05, 0.22), "dir": Vector3(1.0, -0.10, 0.35), "spread": 18.0,
		"vmin": 18.0, "vmax": 28.0, "gravity": Vector3(1.2, -0.4, 0.5), "box": Vector3(38, 14, 32), "additive": false,
		"align_y": true, "no_prox_fade": true, "c0": Color(0.72, 0.62, 0.45, 0.38), "c1": Color(0.65, 0.56, 0.40, 0.06)})
	_emit("sand_gust", {"amount": 45, "life": 4.2, "size": Vector2(4.6, 2.6), "tex": A.dust_tex(), "dir": Vector3(1.0, -0.02, 0.35), "spread": 16.0,
		"vmin": 7.5, "vmax": 12.5, "gravity": Vector3(0.4, 0.0, 0.15), "box": Vector3(36, 4.0, 30), "additive": false,
		"prox_fade": 0.90, "c0": Color(0.70, 0.58, 0.40, 0.0), "cmid": Color(0.66, 0.55, 0.38, 0.13), "c1": Color(0.62, 0.52, 0.36, 0.0)})


func _dust_lite() -> void:
	_emit("dust", {"amount": 420, "life": 4.6, "size": Vector2(0.06, 0.06), "dir": Vector3(1.0, -0.05, 0.2), "spread": 28.0,
		"vmin": 2.2, "vmax": 5.2, "gravity": Vector3(0.3, -0.1, 0.2), "box": Vector3(36, 12, 30), "additive": false,
		"no_prox_fade": true, "c0": Color(0.66, 0.6, 0.48, 0.20), "c1": Color(0.6, 0.55, 0.44, 0.02)})


func _mist(scale := 1.0) -> void:
	_emit("mist", {"amount": int(62 * scale), "life": 9.0, "size": Vector2(8.5, 5.5), "dir": Vector3(1.0, 0.02, 0.25), "spread": 36.0,
		"vmin": 0.35, "vmax": 0.95, "gravity": Vector3(0.05, 0.02, 0.05), "box": Vector3(38, 4.5, 34), "additive": false,
		"prox_fade": 1.25, "c0": Color(0.52, 0.49, 0.47, 0.0), "cmid": Color(0.52, 0.49, 0.47, 0.058), "c1": Color(0.48, 0.46, 0.45, 0.0), "tex": A.smoke_tex()})


func _spores() -> void:
	_emit("spore", {"amount": 900, "life": 8.0, "size": Vector2(0.16, 0.16), "dir": Vector3(0.1, 1.0, 0.05), "spread": 90.0,
		"vmin": 0.2, "vmax": 0.8, "gravity": Vector3(0.02, 0.06, 0.02), "box": Vector3(34, 10, 30), "additive": true,
		"no_prox_fade": true, "c0": Color(0.7, 0.42, 1.0, 0.55), "c1": Color(0.25, 0.1, 0.45, 0.0)})


func _process(delta: float) -> void:
	if raid == null or not is_instance_valid(raid) or raid.camera == null:
		return
	var cam: Camera3D = raid.camera
	var focus := cam.global_position + Vector3(0, -16.0, -12.0)
	var ground_focus := Vector3(cam.global_position.x, 0.12, cam.global_position.z - 8.0)
	if (raid.has_method("is_free_look_view") and raid.is_free_look_view()) or (raid.has_method("is_first_person") and raid.is_first_person()):
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
		var mob_far_cap := 570.0 if A.is_mobile_perf() else 1200.0
		if _storm:
			if _cycle > 24.0:
				_storm = false
				_cycle = 0.0
				Events.emit_custom("sandstorm", {"active": false, "map": raid.map_id})
		elif _cycle > 40.0:
			_storm = true
			_cycle = 0.0
			Events.emit_custom("sandstorm", {"active": true, "map": raid.map_id})
		if _storm:
			_depth_begin_want = 12.0
			_depth_end_want = 145.0
			_depth_curve_want = 1.38
			_fog_want = 0.985
			_aerial_want = 0.28
			_sky_affect_want = 0.42
		else:
			_depth_begin_want = float(_base.get("fog_depth_begin", 30.0))
			_depth_end_want = minf(float(_base.get("fog_depth_end", 560.0)), mob_far_cap)
			_depth_curve_want = float(_base.get("fog_depth_curve", 1.58))
			_fog_want = clampf(float(_base.get("fog_depth_density", 0.97)), 0.0, 1.0)
			_aerial_want = clampf(float(_base.get("fog_aerial", 0.66)), 0.0, 1.0)
			_sky_affect_want = clampf(float(_base.get("fog_sky_affect", 0.16)), 0.0, 1.0)
		var storm_target := 0.92 if _storm else 0.22
		if absf(_storm_vis - storm_target) > 1e-4:
			_storm_vis = lerpf(_storm_vis, storm_target, clampf(delta * 0.8, 0.0, 1.0))
			if absf(_storm_vis - storm_target) <= 1e-4:
				_storm_vis = storm_target
			if sky_mat is ShaderMaterial:
				(sky_mat as ShaderMaterial).set_shader_parameter("storm_amount", _storm_vis)
	# 深度雾参数平滑过渡，仅数值变化时写入 env，避免静止天气每帧触发 Environment 状态脏标记
	var k_lerp := clampf(delta * 0.8, 0.0, 1.0)
	if absf(_fog_now - _fog_want) > 1e-5:
		_fog_now = _fog_want if absf(_fog_now - _fog_want) <= 1e-4 else lerpf(_fog_now, _fog_want, k_lerp)
		if env:
			env.fog_density = _fog_now
	if absf(_depth_begin_now - _depth_begin_want) > 0.02:
		_depth_begin_now = _depth_begin_want if absf(_depth_begin_now - _depth_begin_want) <= 0.05 else lerpf(_depth_begin_now, _depth_begin_want, k_lerp)
		if env:
			env.fog_depth_begin = _depth_begin_now
	if absf(_depth_end_now - _depth_end_want) > 0.1:
		_depth_end_now = _depth_end_want if absf(_depth_end_now - _depth_end_want) <= 0.25 else lerpf(_depth_end_now, _depth_end_want, k_lerp)
		if env:
			env.fog_depth_end = _depth_end_now
	if absf(_depth_curve_now - _depth_curve_want) > 1e-4:
		_depth_curve_now = _depth_curve_want if absf(_depth_curve_now - _depth_curve_want) <= 1e-3 else lerpf(_depth_curve_now, _depth_curve_want, k_lerp)
		if env:
			env.fog_depth_curve = _depth_curve_now
	if absf(_aerial_now - _aerial_want) > 1e-4:
		_aerial_now = _aerial_want if absf(_aerial_now - _aerial_want) <= 1e-3 else lerpf(_aerial_now, _aerial_want, k_lerp)
		if env:
			env.fog_aerial_perspective = _aerial_now
	if absf(_sky_affect_now - _sky_affect_want) > 1e-4:
		_sky_affect_now = _sky_affect_want if absf(_sky_affect_now - _sky_affect_want) <= 1e-3 else lerpf(_sky_affect_now, _sky_affect_want, k_lerp)
		if env:
			env.fog_sky_affect = _sky_affect_now
	if env and env.volumetric_fog_enabled:
		env.volumetric_fog_enabled = false

## 地表材质与全局天气参数都是跨场景共享的：行动结束还原默认值，避免机库与主菜单残留湿润状态。
func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("weather_wet", 0.0)
	RenderingServer.global_shader_parameter_set("weather_rain", 0.0)
	var d: Dictionary = PRESETS.clear
	var reset_fcol: Color = (d.dirt_a as Color).lerp(d.grass as Color, 0.28)
	var sh_m: ShaderMaterial = A.foliage_mat("shrub")
	if sh_m:
		sh_m.set_shader_parameter("far_ground_col", reset_fcol)
	var gr_m: ShaderMaterial = A.foliage_mat("grass")
	if gr_m:
		gr_m.set_shader_parameter("far_ground_col", reset_fcol)
	var gm: ShaderMaterial = A.ground()
	if gm == null:
		return
	gm.set_shader_parameter("dirt_a", d.dirt_a)
	gm.set_shader_parameter("dirt_b", d.dirt_b)
	gm.set_shader_parameter("mud", d.mud)
	gm.set_shader_parameter("grass", d.grass)
	gm.set_shader_parameter("grass2", d.grass2)
	gm.set_shader_parameter("wet_amt", 0.0)
	gm.set_shader_parameter("zone_on", 0.0)
	gm.set_shader_parameter("sector_on", 0.0)
