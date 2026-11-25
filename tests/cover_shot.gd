extends "res://tests/lib/test_base.gd"
## 游戏封面 4K 超采样实机摄影棚（3840x2160 原生渲染 -> 2560x1440 Lanczos 降采样）：
## 彻底重构画质与资产精度：
## 1) 天空：纯数学解析 8 阶 FBM 体积积云与卷云光线步进天空着色器（4K 无限分辨率，零贴图拉伸马赛克）；
## 2) 光影：侧前黄金时刻斜射光（108° 掠射角），完整激发出崖壁、碎石、轧制钢板与 2K GLB 烘焙法线的立体微起伏与锐利投影；
## 3) 地貌：高密度雕刻峡谷断崖瞭望岩台 + 全 1024px 扫描级三平面多尺度 PBR 地表着色器（彻底淘汰模糊 512px 泥地贴图与矩形板片）；
## 4) 建模：全系换装高精旗舰模块（SEP-V3 复合楔甲 + VK-5 正关节重甲突击腿 + GAU-8 复仇者七管机炮 + M82-35 巴雷特反器材炮 + AGT1500 燃气轮机）并注入 1K 轧制钢板 PBR 法线/粗糙度；
##    荒野远近景接入 50MB 2K PBR 掘进泰坦巨骸 (excavator_titan.glb)、六足要塞断足 (citadel_leg.glb)、坠毁四发倾转运输机 (veh_transport_vtol)、战损主战坦克、穹顶钢构遗骸与风蚀层岩群峰（全面剔除低模枯树与方盒公寓楼）。

const START := "none"
const TIMEOUT := 240.0

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const MV = preload("res://scripts/mech_visual.gd")
const BossGlb = preload("res://scripts/enemies/boss_glb.gd")
const AlbatrossAirship = preload("res://scripts/airship/airship_albatross.gd")
const MountainTerrain = preload("res://scripts/mountain_terrain.gd")

const TankWreck = preload("res://scripts/buildings/veh_mbt_tank_wreck.gd")
const TransportVTOL = preload("res://scripts/buildings/veh_transport_vtol.gd")
const FuelTanker = preload("res://scripts/buildings/veh_fuel_tanker.gd")
const DragonTeethPipe = preload("res://scripts/buildings/ter_dragon_teeth_pipe.gd")
const CentralTerminus = preload("res://scripts/models/bld_central_terminus.gd")
const WindTurbine = preload("res://scripts/models/lm_wind_turbine.gd")
const RadioMast = preload("res://scripts/models/lm_radio_mast.gd")
const GantryRail = preload("res://scripts/buildings/poi_gantry_rail.gd")

var _n_macro := FastNoiseLite.new()
var _n_mid := FastNoiseLite.new()
var _n_micro := FastNoiseLite.new()


func _init_noise() -> void:
	_n_macro.seed = 20261121
	_n_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_macro.frequency = 0.012
	_n_macro.fractal_octaves = 4

	_n_mid.seed = 77319
	_n_mid.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_mid.frequency = 0.065
	_n_mid.fractal_octaves = 3

	_n_micro.seed = 41903
	_n_micro.noise_type = FastNoiseLite.TYPE_CELLULAR
	_n_micro.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	_n_micro.frequency = 0.24


## 峡谷废道中心线
func _road_center_x(z: float) -> float:
	var u: float = clampf((14.0 - z) / 260.0, 0.0, 1.8)
	return -4.8 - u * 22.0 + sin(z * 0.022 + 0.4) * 5.6


## 岩石权重（0=砂砾谷底，1=裸露基岩断崖台面）
func _rock_mask(x: float, z: float) -> float:
	# 右侧前景至中景：天然层理基岩瞭望断崖台（玩家机甲伫立于崖顶）
	var d_prom: float = Vector2((x - 3.2) * 0.72, (z - 0.5) * 0.85).length()
	var prom: float = smoothstep(7.2, 2.6, d_prom)
	# 左侧前景压框岩台
	var d_left: float = Vector2((x + 6.5) * 0.75, (z - 9.2) * 0.9).length()
	var l_ledge: float = smoothstep(5.8, 2.2, d_left)
	# 两侧峡谷坡脚岩石露头
	var valley_x: float = x - _road_center_x(z) * 0.55
	var flank_r: float = smoothstep(28.0, 62.0, absf(valley_x))
	return clampf(maxf(maxf(prom, l_ledge), flank_r), 0.0, 1.0)


## 公路沥青权重（噪声自然风蚀边缘，无缝融进地表着色器，绝无生硬几何切边）
func _road_mask(_x: float, _z: float) -> float:
	return 0.0


## 高精度峡谷荒原高程场
func _terrain_h(x: float, z: float) -> float:
	var mac: float = _n_macro.get_noise_2d(x, z) * 1.15
	var mid: float = _n_mid.get_noise_2d(x, z) * 0.22
	var mic: float = (0.5 - _n_micro.get_noise_2d(x, z)) * 0.09
	var h: float = mac + mid + mic

	# 峡谷两侧自然抬升
	var valley_x: float = x - _road_center_x(z) * 0.55
	var dist_z: float = maxf(0.0, -z - 22.0)
	h += smoothstep(30.0, 155.0, absf(valley_x)) * smoothstep(0.0, 140.0, dist_z) * 7.5

	# 公路微平路基与车辙凹槽
	var rm: float = _road_mask(x, z)
	if rm > 0.01:
		var rx: float = _road_center_x(z)
		var road_h: float = _n_macro.get_noise_2d(rx, z) * 0.52 - 0.18
		h = lerpf(h, road_h, rm * 0.90)

	# 玩家机甲立足的低矮风蚀基岩露头（微高于荒原约 0.48m，既稳固承托双足又不遮挡轻微俯视下的辽阔后景荒原！）
	var dx_p: float = x - 1.95
	var dz_p: float = z - 2.60
	var r_prom: float = sqrt(dx_p * dx_p * 0.72 + dz_p * dz_p * 0.85) + _n_mid.get_noise_2d(x * 1.3, z * 1.3) * 0.32
	var rock_pad: float = smoothstep(4.6, 1.8, r_prom) * 0.46
	h += rock_pad
	var flat_top: float = smoothstep(2.1, 0.75, Vector2(dx_p, dz_p).length())
	h = lerpf(h, 0.48, flat_top * 0.90)

	# 左前微起伏砾石坡
	var d_fg_l: float = Vector2((x + 6.2) * 0.78, (z - 9.2) * 0.95).length()
	h += smoothstep(4.2, 1.5, d_fg_l) * 0.24

	# 左中景巨兽残骸陨坑（半埋掘进泰坦巨骸）
	var d_titan: float = Vector2((x + 12.2) * 0.75, (z + 20.5) * 0.85).length()
	h += -0.88 * exp(- (d_titan * d_titan) / 26.0) + 0.30 * exp(- pow(d_titan - 6.8, 2.0) / 5.5)

	# 中景主战坦克弹坑
	var d_tank: float = Vector2(x + 1.8, z + 32.5).length()
	h += -0.52 * exp(- (d_tank * d_tank) / 11.5)
	return h


func _terrain_normal(x: float, z: float, eps := 0.25) -> Vector3:
	var hx: float = _terrain_h(x + eps, z) - _terrain_h(x - eps, z)
	var hz: float = _terrain_h(x, z + eps) - _terrain_h(x, z - eps)
	return Vector3(-hx, 2.0 * eps, -hz).normalized()


## 4K 无限分辨率解析体积云与暮色大气天空着色器（彻底告别低清全景贴图拉伸噪斑！）
func _make_procedural_sky_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type sky;
render_mode use_debanding;

uniform vec3 zenith_col : source_color = vec3(0.035, 0.065, 0.130);
uniform vec3 mid_sky_col : source_color = vec3(0.11, 0.15, 0.24);
uniform vec3 horizon_warm : source_color = vec3(0.96, 0.42, 0.16);
uniform vec3 horizon_cool : source_color = vec3(0.19, 0.23, 0.33);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.62, 0.28);
uniform vec3 ground_fog : source_color = vec3(0.20, 0.18, 0.20);

// 高精度无轴向零面退化三维哈希（彻底消除天空斜向条带伪影！）
float hash3(highp vec3 p) {
	highp vec3 q = p + vec3(37.17, 61.73, 19.41);
	q = fract(q * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yxz + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vnoise3(highp vec3 p) {
	highp vec3 i = floor(p);
	highp vec3 f = fract(p);
	highp vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
		u.z
	);
}

float fbm_cloud(highp vec3 p, int oct) {
	float v = 0.0;
	float a = 0.52;
	mat3 rot = mat3(
		vec3(0.80, 0.14, 0.58),
		vec3(-0.22, 0.95, 0.21),
		vec3(-0.56, -0.29, 0.78)
	);
	for (int i = 0; i < oct; i++) {
		v += a * vnoise3(p);
		p = rot * p * 2.07 + vec3(13.7, 7.3, 19.1);
		a *= 0.49;
	}
	return v;
}

float cloud_density(highp vec3 p) {
	highp vec3 warp = vec3(
		vnoise3(p * 0.42 + vec3(2.1, 5.4, 1.3)),
		vnoise3(p * 0.42 + vec3(8.7, 1.9, 6.2)),
		vnoise3(p * 0.42 + vec3(4.3, 9.1, 3.7))
	) - 0.5;
	float base = fbm_cloud(p + warp * 0.85, 7);
	float billow = 1.0 - abs(vnoise3(p * 1.9 + warp * 1.2) * 2.0 - 1.0);
	float d = base * 0.84 + billow * 0.25;
	return smoothstep(0.39, 0.73, d);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 L = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(-0.84, 0.30, 0.45));
	float sd = max(dot(d, L), 0.0);
	float y = d.y;
	float yy = clamp(y, 0.0, 1.0);

	vec2 d_xz = length(d.xz) > 1e-4 ? normalize(d.xz) : vec2(0.0, -1.0);
	vec2 l_xz = length(L.xz) > 1e-4 ? normalize(L.xz) : vec2(-1.0, 0.0);
	float az = clamp(dot(d_xz, l_xz) * 0.5 + 0.5, 0.0, 1.0);

	vec3 hz = mix(horizon_cool, horizon_warm, pow(az, 1.65));
	vec3 sky_c = mix(hz, mid_sky_col, smoothstep(0.0, 0.24, yy));
	sky_c = mix(sky_c, zenith_col, smoothstep(0.16, 0.82, yy));
	sky_c += sun_tint * (pow(sd, 5.0) * 0.22 + pow(sd, 28.0) * 0.35) * exp(-yy * 2.2);

	if (AT_CUBEMAP_PASS) {
		vec3 dn = mix(ground_fog, ground_fog * 0.38, smoothstep(0.0, 0.65, clamp(-y, 0.0, 1.0)));
		COLOR = mix(dn, sky_c, smoothstep(-0.06, 0.06, y));
	} else {
		if (y > 0.004) {
			// 第一层：高空纤细卷云丝缕 (Cirrus)
			vec2 uv_hi = d.xz / (y + 0.14) * 0.55 + vec2(3.4, -1.8);
			float cir = fbm_cloud(vec3(uv_hi.x * 1.4, 2.2, uv_hi.y * 0.55), 5);
			float cir_m = smoothstep(0.56, 0.84, cir) * smoothstep(0.01, 0.22, y) * 0.42;
			vec3 cir_col = mix(vec3(0.58, 0.62, 0.70), sun_tint * 1.12, pow(az, 1.4) * 0.75);
			sky_c = mix(sky_c, cir_col, cir_m);

			// 第二层：三维体积积云层光线步进（7 步密度积分 + 向阳自阴影 Beer-Lambert）
			float h_bot = 1.0;
			float h_top = 1.62;
			float r_curve = y + 0.085;
			float t0 = h_bot / r_curve;
			float t1 = h_top / r_curve;
			float dt = (t1 - t0) / 7.0;
			float T = 1.0;
			vec3 cl_acc = vec3(0.0);

			for (int i = 0; i < 7; i++) {
				float t_s = t0 + (float(i) + 0.5) * dt;
				vec3 p = vec3(d.x * t_s * 0.42 + 4.1, float(i) * 0.22, d.z * t_s * 0.42 - 2.7);
				float dens = cloud_density(p);
				if (dens > 0.008) {
					float h_frac = float(i) / 6.0;
					float d_sun1 = cloud_density(p + L * 0.24);
					float d_sun2 = cloud_density(p + L * 0.58);
					float od = (d_sun1 * 0.9 + d_sun2 * 1.3);
					float trans_sun = exp(-od * 2.15);
					float powder = 1.0 - exp(-dens * 2.8);
					vec3 shade_c = mix(vec3(0.14, 0.17, 0.23), vec3(0.28, 0.31, 0.38), h_frac);
					vec3 lit_c = mix(vec3(0.92, 0.78, 0.66), sun_tint * 1.32, pow(az, 1.2));
					float phase = 0.55 + 0.85 * pow(sd, 4.0);
					vec3 sample_c = mix(shade_c, lit_c * phase, clamp(trans_sun * (0.65 + 0.45 * powder), 0.0, 1.15));
					float a = 1.0 - exp(-dens * dt * 3.1);
					cl_acc += T * a * sample_c;
					T *= (1.0 - a);
					if (T < 0.04) break;
				}
			}
			float dist_fade = smoothstep(0.006, 0.13, y);
			vec3 cloud_final = mix(hz * 0.88, cl_acc / max(1.0 - T, 1e-4), dist_fade);
			sky_c = mix(sky_c, cloud_final, (1.0 - T) * smoothstep(0.004, 0.055, y));
		}

		// 地平线大气尘霭柔和收束
		float hz_haze = exp(-abs(y) * 19.0);
		sky_c = mix(sky_c, mix(ground_fog, hz, 0.52), hz_haze * 0.56);
		if (y < 0.0) {
			vec3 dn_c = mix(ground_fog, vec3(0.06, 0.055, 0.06), smoothstep(0.0, 0.45, -y));
			sky_c = mix(dn_c, sky_c, smoothstep(-0.015, 0.005, y));
		}
		COLOR = sky_c;
	}
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	return sm


## 全 1024px 多尺度扫描级三平面 PBR 峡谷地表着色器（砂砾戈壁 + 层理裸岩 + 风蚀龟裂沥青，近景微距零糊感！）
func _make_terrain_shader_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D scree_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_r : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D cliff_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_r : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D asph_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_r : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying highp vec3 v_wp;
varying vec3 v_wn;
varying vec4 v_mask; // r = rock_mask, g = road_mask, b = road_line, a = ao

vec2 rot2(vec2 p) { return vec2(p.x * 0.80 - p.y * 0.60, p.x * 0.60 + p.y * 0.80); }

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_mask = COLOR;
}

void fragment() {
	vec3 N = normalize(v_wn);
	float slope_rock = smoothstep(0.86, 0.58, N.y);
	float rock_w = clamp(max(v_mask.r * (0.45 + 0.55 * slope_rock + 0.35 * smoothstep(0.6, 1.4, v_wp.y)), slope_rock), 0.0, 1.0);
	float road_w = clamp(v_mask.g * (1.0 - rock_w * 0.85), 0.0, 1.0);

	float n_mac = texture(noise_tex, v_wp.xz * 0.014).r;
	float n_mid = texture(noise_tex, v_wp.xz * 0.075 + vec2(0.31, 0.57)).r;

	// 1) 戈壁碎石砂砾层（双角反平铺 + 近景高频微颗粒层 1.25x，距镜头 2m 依然颗粒分明！）
	vec2 uv_s1 = v_wp.xz * 0.34;
	vec2 uv_s2 = rot2(v_wp.xz * 0.13 + vec2(4.7, 9.1));
	vec2 uv_micro = rot2(v_wp.xz * 1.28);
	float mix_s = smoothstep(0.28, 0.72, n_mac);
	vec3 s_alb = mix(texture(scree_a, uv_s1).rgb, texture(scree_a, uv_s2).rgb, mix_s);
	vec3 s_mic = texture(scree_a, uv_micro).rgb;
	float dist = length(CAMERA_POSITION_WORLD - v_wp);
	float near_w = 1.0 - smoothstep(4.0, 32.0, dist);
	s_alb = mix(s_alb, s_alb * (0.72 + 0.56 * s_mic), near_w * 0.65);
	s_alb *= mix(vec3(0.68, 0.58, 0.48), vec3(0.92, 0.80, 0.66), smoothstep(0.2, 0.8, n_mid));

	vec3 s_rm = mix(texture(scree_r, uv_s1).rgb, texture(scree_r, uv_s2).rgb, mix_s);
	vec2 sn1 = texture(scree_n, uv_s1).rg * 2.0 - 1.0;
	vec2 sn2 = texture(scree_n, uv_micro).rg * 2.0 - 1.0;
	vec2 sn = sn1 * 0.85 + sn2 * near_w * 0.55;

	// 2) 三平面层理基岩断崖层（1024px cliff_a/n/r）
	vec3 an = pow(abs(N), vec3(5.0));
	an /= max(an.x + an.y + an.z, 1e-4);
	vec3 r_alb = texture(cliff_a, v_wp.zy * 0.22).rgb * an.x
	           + texture(cliff_a, v_wp.xz * 0.22).rgb * an.y
	           + texture(cliff_a, v_wp.xy * 0.22).rgb * an.z;
	r_alb *= mix(vec3(0.66, 0.56, 0.47), vec3(0.88, 0.76, 0.63), smoothstep(0.25, 0.75, fract(v_wp.y * 0.42 + n_mid * 0.35)));
	vec3 r_rm = texture(cliff_r, v_wp.zy * 0.22).rgb * an.x
	          + texture(cliff_r, v_wp.xz * 0.22).rgb * an.y
	          + texture(cliff_r, v_wp.xy * 0.22).rgb * an.z;
	vec2 rn_xz = (texture(cliff_n, v_wp.xz * 0.22).rg * 2.0 - 1.0) * 1.05;

	// 3) 风蚀龟裂暗灰沥青路面层（1024px asphalt_a/n/r，无缝融进砂砾）
	vec2 uv_a = v_wp.xz * 0.38;
	vec3 a_alb = texture(asph_a, uv_a).rgb * vec3(0.46, 0.46, 0.49);
	// 褪色斑驳黄标线直接融合在沥青纹理中，随风沙磨损断续
	float line_wear = smoothstep(0.38, 0.72, n_mid * 0.7 + s_mic.r * 0.3);
	a_alb = mix(a_alb, vec3(0.52, 0.40, 0.20), v_mask.b * line_wear * 0.72);
	vec3 a_rm = texture(asph_r, uv_a).rgb;
	vec2 an_uv = (texture(asph_n, uv_a).rg * 2.0 - 1.0) * 0.85;

	vec3 alb = mix(s_alb, a_alb, road_w);
	alb = mix(alb, r_alb, rock_w);

	vec3 rm = mix(s_rm, a_rm, road_w);
	rm = mix(rm, r_rm, rock_w);

	vec2 n_pert = mix(sn, an_uv, road_w);
	n_pert = mix(n_pert, rn_xz, rock_w);

	vec3 wn_final = normalize(N + vec3(n_pert.x, 0.0, n_pert.y) * 0.92);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn_final, 0.0)).xyz);
	ALBEDO = alb * v_mask.a;
	ROUGHNESS = clamp(mix(0.88, rm.r, 0.65), 0.38, 0.98);
	METALLIC = 0.0;
	AO = clamp(rm.g * v_mask.a, 0.25, 1.0);
	AO_LIGHT_AFFECT = 0.45;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("scree_a", A.world_tex("mtn_scree_a.png"))
	sm.set_shader_parameter("scree_n", A.world_tex("mtn_scree_n.png"))
	sm.set_shader_parameter("scree_r", A.world_tex("mtn_scree_r.png"))
	sm.set_shader_parameter("cliff_a", A.world_tex("mtn_cliff_a.png"))
	sm.set_shader_parameter("cliff_n", A.world_tex("mtn_cliff_n.png"))
	sm.set_shader_parameter("cliff_r", A.world_tex("mtn_cliff_r.png"))
	sm.set_shader_parameter("asph_a", A.world_tex("asphalt_a.png"))
	sm.set_shader_parameter("asph_n", A.world_tex("asphalt_n.png"))
	sm.set_shader_parameter("asph_r", A.world_tex("asphalt_r.png"))
	sm.set_shader_parameter("noise_tex", A.noise_tex("grime_raw", 512))
	return sm


func _terrain_vcol(x: float, z: float) -> Color:
	var rk: float = _rock_mask(x, z)
	var rd: float = _road_mask(x, z)
	var rx: float = _road_center_x(z)
	var dash: float = 1.0 if (fposmod(absf(z), 7.5) < 2.6 and absf(x - rx) < 0.11 and rd > 0.75) else 0.0
	return Color(rk, rd, dash, 1.0)


func _build_wasteland_terrain(parent: Node3D) -> void:
	var t_mat: ShaderMaterial = _make_terrain_shader_mat()

	# 1) 近景超高精度网格（0.45m 步长，刻画瞭望岩台棱线、陨坑与车辙起伏）
	var st_near := SurfaceTool.new()
	st_near.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_x0 := -28.0; var n_x1 := 24.0
	var n_z0 := -46.0; var n_z1 := 18.0
	var step_n := 0.45
	var c_nx := int((n_x1 - n_x0) / step_n)
	var c_nz := int((n_z1 - n_z0) / step_n)
	for iz in c_nz:
		var z0: float = n_z0 + float(iz) * step_n
		var z1: float = z0 + step_n
		for ix in c_nx:
			var x0: float = n_x0 + float(ix) * step_n
			var x1: float = x0 + step_n
			var p00 := Vector3(x0, _terrain_h(x0, z0), z0)
			var p10 := Vector3(x1, _terrain_h(x1, z0), z0)
			var p01 := Vector3(x0, _terrain_h(x0, z1), z1)
			var p11 := Vector3(x1, _terrain_h(x1, z1), z1)
			var c00 := _terrain_vcol(x0, z0)
			var c10 := _terrain_vcol(x1, z0)
			var c01 := _terrain_vcol(x0, z1)
			var c11 := _terrain_vcol(x1, z1)
			st_near.set_color(c00); st_near.set_normal(_terrain_normal(x0, z0, 0.22)); st_near.add_vertex(p00)
			st_near.set_color(c10); st_near.set_normal(_terrain_normal(x1, z0, 0.22)); st_near.add_vertex(p10)
			st_near.set_color(c11); st_near.set_normal(_terrain_normal(x1, z1, 0.22)); st_near.add_vertex(p11)
			st_near.set_color(c00); st_near.set_normal(_terrain_normal(x0, z0, 0.22)); st_near.add_vertex(p00)
			st_near.set_color(c11); st_near.set_normal(_terrain_normal(x1, z1, 0.22)); st_near.add_vertex(p11)
			st_near.set_color(c01); st_near.set_normal(_terrain_normal(x0, z1, 0.22)); st_near.add_vertex(p01)
	var mi_near := MeshInstance3D.new()
	mi_near.mesh = st_near.commit()
	mi_near.material_override = t_mat
	parent.add_child(mi_near)

	# 2) 中远景荒原网格（2.5m 步长，延伸至 -180m）
	var st_mid := SurfaceTool.new()
	st_mid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m_x0 := -140.0; var m_x1 := 140.0
	var m_z0 := -195.0; var m_z1 := 30.0
	var step_m := 2.5
	var c_mx := int((m_x1 - m_x0) / step_m)
	var c_mz := int((m_z1 - m_z0) / step_m)
	for iz in c_mz:
		var z0: float = m_z0 + float(iz) * step_m
		var z1: float = z0 + step_m
		for ix in c_mx:
			var x0: float = m_x0 + float(ix) * step_m
			var x1: float = x0 + step_m
			if x0 >= n_x0 + 1.5 and x1 <= n_x1 - 1.5 and z0 >= n_z0 + 1.5 and z1 <= n_z1 - 1.5:
				continue
			var p00 := Vector3(x0, _terrain_h(x0, z0) - 0.03, z0)
			var p10 := Vector3(x1, _terrain_h(x1, z0) - 0.03, z0)
			var p01 := Vector3(x0, _terrain_h(x0, z1) - 0.03, z1)
			var p11 := Vector3(x1, _terrain_h(x1, z1) - 0.03, z1)
			var c00 := _terrain_vcol(x0, z0)
			var c10 := _terrain_vcol(x1, z0)
			var c01 := _terrain_vcol(x0, z1)
			var c11 := _terrain_vcol(x1, z1)
			st_mid.set_color(c00); st_mid.set_normal(_terrain_normal(x0, z0, 0.8)); st_mid.add_vertex(p00)
			st_mid.set_color(c10); st_mid.set_normal(_terrain_normal(x1, z0, 0.8)); st_mid.add_vertex(p10)
			st_mid.set_color(c11); st_mid.set_normal(_terrain_normal(x1, z1, 0.8)); st_mid.add_vertex(p11)
			st_mid.set_color(c00); st_mid.set_normal(_terrain_normal(x0, z0, 0.8)); st_mid.add_vertex(p00)
			st_mid.set_color(c11); st_mid.set_normal(_terrain_normal(x1, z1, 0.8)); st_mid.add_vertex(p11)
			st_mid.set_color(c01); st_mid.set_normal(_terrain_normal(x0, z1, 0.8)); st_mid.add_vertex(p01)
	var mi_mid := MeshInstance3D.new()
	mi_mid.mesh = st_mid.commit()
	mi_mid.material_override = t_mat
	parent.add_child(mi_mid)

	# 3) 地平线远景底盘（10m 步长，覆盖至 -620m）
	var st_far := SurfaceTool.new()
	st_far.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f_x0 := -560.0; var f_x1 := 560.0
	var f_z0 := -620.0; var f_z1 := 40.0
	var step_f := 10.0
	var c_fx := int((f_x1 - f_x0) / step_f)
	var c_fz := int((f_z1 - f_z0) / step_f)
	for iz in c_fz:
		var z0: float = f_z0 + float(iz) * step_f
		var z1: float = z0 + step_f
		for ix in c_fx:
			var x0: float = f_x0 + float(ix) * step_f
			var x1: float = x0 + step_f
			if x0 >= m_x0 + 6.0 and x1 <= m_x1 - 6.0 and z0 >= m_z0 + 6.0 and z1 <= m_z1 - 6.0:
				continue
			var p00 := Vector3(x0, _terrain_h(x0, z0) - 0.08, z0)
			var p10 := Vector3(x1, _terrain_h(x1, z0) - 0.08, z0)
			var p01 := Vector3(x0, _terrain_h(x0, z1) - 0.08, z1)
			var p11 := Vector3(x1, _terrain_h(x1, z1) - 0.08, z1)
			st_far.set_color(Color(0.6, 0.0, 0.0, 1.0)); st_far.set_normal(Vector3.UP); st_far.add_vertex(p00)
			st_far.set_color(Color(0.6, 0.0, 0.0, 1.0)); st_far.set_normal(Vector3.UP); st_far.add_vertex(p10)
			st_far.set_color(Color(0.6, 0.0, 0.0, 1.0)); st_far.set_normal(Vector3.UP); st_far.add_vertex(p11)
			st_far.set_color(Color(0.6, 0.0, 0.0, 1.0)); st_far.set_normal(Vector3.UP); st_far.add_vertex(p00)
			st_far.set_color(Color(0.6, 0.0, 0.0, 1.0)); st_far.set_normal(Vector3.UP); st_far.add_vertex(p11)
			st_far.set_color(Color(0.6, 0.0, 0.0, 1.0)); st_far.set_normal(Vector3.UP); st_far.add_vertex(p01)
	var mi_far := MeshInstance3D.new()
	mi_far.mesh = st_far.commit()
	mi_far.material_override = t_mat
	parent.add_child(mi_far)


## 为程序化装甲与混凝土实体注入 1024x1024 扫描级轧制钢板 / 混凝土 PBR 法线与粗糙度贴图！
var _upgraded_mats := {}

func _upgrade_pbr_materials(root: Node, panel_sc := 1.4) -> void:
	var steel_a: Texture2D = A.world_tex("steel_plate_a.png")
	var steel_n: Texture2D = A.world_tex("steel_plate_n.png")
	var steel_r: Texture2D = A.world_tex("steel_plate_r.png")
	var conc_a: Texture2D = A.world_tex("concrete_a.png")
	var conc_n: Texture2D = A.world_tex("concrete_n.png")
	var conc_r: Texture2D = A.world_tex("concrete_r.png")

	var nodes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	for n in nodes:
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var m: Material = mi.material_override
		if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			m = mi.mesh.surface_get_material(0)
		if not (m is ShaderMaterial):
			continue
		var sm := m as ShaderMaterial
		if sm.shader == null or not sm.shader.resource_path.contains("mech_paint"):
			continue
		var key: String = "%d|%.2f" % [sm.get_instance_id(), panel_sc]
		if _upgraded_mats.has(key):
			mi.material_override = _upgraded_mats[key]
			continue
		var dup: ShaderMaterial = sm.duplicate() as ShaderMaterial
		var mw_v: Variant = dup.get_shader_parameter("metal_wear")
		var mw: float = float(mw_v) if mw_v != null else 1.0
		if mw > 0.45:
			dup.set_shader_parameter("use_albedo_tex", 1.0)
			dup.set_shader_parameter("albedo_tex", steel_a)
			dup.set_shader_parameter("albedo_tex_scale", 0.72)
			dup.set_shader_parameter("albedo_tex_strength", 0.36)
			dup.set_shader_parameter("normal_tex", steel_n)
			dup.set_shader_parameter("normal_strength", 0.62)
			dup.set_shader_parameter("use_rough_tex", 1.0)
			dup.set_shader_parameter("rough_tex", steel_r)
			dup.set_shader_parameter("rough_tex_strength", 0.74)
			if panel_sc > 0.0:
				dup.set_shader_parameter("panel_scale", panel_sc)
		else:
			dup.set_shader_parameter("use_albedo_tex", 1.0)
			dup.set_shader_parameter("albedo_tex", conc_a)
			dup.set_shader_parameter("albedo_tex_scale", 0.28)
			dup.set_shader_parameter("albedo_tex_strength", 0.78)
			dup.set_shader_parameter("normal_tex", conc_n)
			dup.set_shader_parameter("normal_strength", 0.82)
			dup.set_shader_parameter("use_rough_tex", 1.0)
			dup.set_shader_parameter("rough_tex", conc_r)
			dup.set_shader_parameter("rough_tex_strength", 0.76)
		_upgraded_mats[key] = dup
		mi.material_override = dup


## 加载高面数 2K 烘焙 PBR GLB 战争巨兽残骸（掘进泰坦倒毙巨骸 / 六足要塞断腿残骸）
func _spawn_glb_wreck(parent: Node3D, glb_path: String, target_len: float, pos: Vector3, rot_deg: Vector3, anim_name := "") -> Node3D:
	if not ResourceLoader.exists(glb_path):
		return null
	var ps: PackedScene = load(glb_path) as PackedScene
	if ps == null:
		return null
	var inst: Node = ps.instantiate()
	if inst == null:
		return null
	var wrap := Node3D.new()
	wrap.position = pos
	wrap.rotation_degrees = rot_deg
	parent.add_child(wrap)
	wrap.add_child(inst)

	# 修正法线并开启完整高精实时阴影投射！
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.mesh is ArrayMesh:
			mi.mesh = BossGlb._get_sanitized_mesh(mi.mesh as ArrayMesh)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	if anim_name != "":
		var ap: AnimationPlayer = BossGlb._find_anim_player(inst)
		if ap != null and ap.has_animation(anim_name):
			var anim: Animation = ap.get_animation(anim_name)
			ap.play(anim_name)
			ap.advance(maxf(0.0, anim.length - 0.05))

	var aabb: AABB = BossGlb._compute_bounds(inst)
	var max_dim: float = maxf(maxf(aabb.size.x, aabb.size.y), maxf(aabb.size.z, 0.01))
	var sc: float = target_len / max_dim
	if inst is Node3D:
		(inst as Node3D).scale = Vector3.ONE * sc
	return wrap


## 雕刻向阳受光峡谷岩壁山脉（使用 1024px mtn_cliff_a/n/r 扫描岩石着色器，迎着侧前斜阳展现极致岩层裂缝！）
func _build_canyon_massif(parent: Node3D, mat: Material, center: Vector3, length_x: float, depth_z: float, max_h: float, yaw_deg: float, seed_ofs: int, mesa_flat := 0.74) -> void:
	var n_macro := FastNoiseLite.new()
	n_macro.seed = 13370 + seed_ofs * 409
	n_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_macro.frequency = 0.0058
	n_macro.fractal_octaves = 3

	var n_spur := FastNoiseLite.new()
	n_spur.seed = 29101 + seed_ofs * 271
	n_spur.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_spur.frequency = 0.021
	n_spur.fractal_octaves = 4

	var n_warp := FastNoiseLite.new()
	n_warp.seed = 8812 + seed_ofs * 113
	n_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_warp.frequency = 0.009

	var cols := 128
	var rows := 60
	var h_grid := PackedFloat32Array()
	h_grid.resize((cols + 1) * (rows + 1))

	for rz in (rows + 1):
		var vz: float = float(rz) / float(rows) * 2.0 - 1.0
		for cx in (cols + 1):
			var ux: float = float(cx) / float(cols) * 2.0 - 1.0
			var lx: float = ux * length_x * 0.5
			var lz: float = vz * depth_z * 0.5
			var wx: float = lx + n_warp.get_noise_2d(lx, lz) * 15.0
			var wz: float = lz + n_warp.get_noise_2d(lx + 97.0, lz - 61.0) * 15.0

			var spine_z: float = n_macro.get_noise_2d(lx * 0.55, 19.0) * depth_z * 0.20
			var d_norm: float = clampf(1.0 - absf(lz - spine_z) / (depth_z * 0.48), 0.0, 1.0)
			var end_taper: float = smoothstep(1.0, 0.38, absf(ux))
			var d_in: float = d_norm * end_taper * 44.0
			if d_in <= 0.2:
				h_grid[rz * (cols + 1) + cx] = -1.5
				continue

			var apron: float = smoothstep(0.0, 14.5, d_in)
			var core_h: float = pow(clampf(d_in / 33.0, 0.0, 1.28), 0.75)
			var slope_prof: float = pow(apron, 1.45) * (0.24 + 0.76 * core_h)
			var mac: float = 0.64 + 0.48 * (n_macro.get_noise_2d(wx * 0.9, wz * 0.7) * 0.5 + 0.5)
			var spur: float = n_spur.get_noise_2d(wx, wz) * 0.5 + 0.5
			var gully: float = pow(clampf(1.0 - spur * 1.15, 0.0, 1.0), 1.45)

			var e: float = max_h * slope_prof * mac
			var cap: float = max_h * mesa_flat * (0.85 + 0.24 * n_macro.get_noise_2d(wx * 1.4 + 50.0, 0.0))
			if e > cap:
				e = cap + (e - cap) * 0.16

			# 强放射岩肋与深冲沟（在侧向阳光下投出锐利山体自阴影！）
			e += (spur - 0.44) * 5.8 * smoothstep(2.5, 17.0, d_in)
			e -= gully * 5.2 * smoothstep(1.8, 15.0, d_in)

			if e > 2.2:
				var strata_h := 4.4
				var dip: float = lx * 0.026 + lz * 0.018
				var sc: float = (e + dip) / strata_h
				var sfl: float = floorf(sc)
				var sfr: float = sc - sfl
				var terraced: float = (sfl + smoothstep(0.0, 0.32, sfr) * 0.82 + sfr * 0.18) * strata_h - dip
				e = lerpf(e, terraced, 0.52 * smoothstep(2.2, 7.5, e) * (1.0 - gully * 0.45))

			h_grid[rz * (cols + 1) + cx] = e - 0.8

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dx: float = length_x / float(cols)
	var dz: float = depth_z / float(rows)

	var get_v := func(cx: int, rz: int) -> Vector3:
		var ux: float = float(cx) / float(cols) * 2.0 - 1.0
		var vz: float = float(rz) / float(rows) * 2.0 - 1.0
		return Vector3(ux * length_x * 0.5, h_grid[rz * (cols + 1) + cx], vz * depth_z * 0.5)

	var get_n := func(cx: int, rz: int) -> Vector3:
		var c0: int = maxi(cx - 1, 0); var c1: int = mini(cx + 1, cols)
		var r0: int = maxi(rz - 1, 0); var r1: int = mini(rz + 1, rows)
		var hx: float = h_grid[rz * (cols + 1) + c1] - h_grid[rz * (cols + 1) + c0]
		var hz: float = h_grid[r1 * (cols + 1) + cx] - h_grid[r0 * (cols + 1) + cx]
		return Vector3(-hx / maxf(float(c1 - c0) * dx, 0.1), 1.0, -hz / maxf(float(r1 - r0) * dz, 0.1)).normalized()

	var get_col := func(cx: int, rz: int, nrm: Vector3) -> Color:
		var h: float = maxf(0.0, h_grid[rz * (cols + 1) + cx])
		var nh: float = clampf(h / maxf(max_h, 1.0), 0.0, 1.0)
		var scree: float = clampf((nrm.y - 0.56) * 2.6, 0.0, 1.0) * (1.0 - nh * 0.52)
		var ridge_exp: float = clampf(nh * 1.15, 0.0, 1.0)
		var ao: float = clampf(0.48 + nh * 0.52, 0.32, 1.0)
		return Color(ao, ridge_exp, scree, nh)

	for rz in rows:
		for cx in cols:
			var p00: Vector3 = get_v.call(cx, rz)
			var p10: Vector3 = get_v.call(cx + 1, rz)
			var p01: Vector3 = get_v.call(cx, rz + 1)
			var p11: Vector3 = get_v.call(cx + 1, rz + 1)
			if p00.y < -1.1 and p10.y < -1.1 and p01.y < -1.1 and p11.y < -1.1:
				continue
			var n00: Vector3 = get_n.call(cx, rz)
			var n10: Vector3 = get_n.call(cx + 1, rz)
			var n01: Vector3 = get_n.call(cx, rz + 1)
			var n11: Vector3 = get_n.call(cx + 1, rz + 1)
			st.set_color(get_col.call(cx, rz, n00)); st.set_normal(n00); st.set_uv(Vector2(p00.x, p00.z)); st.add_vertex(p00)
			st.set_color(get_col.call(cx + 1, rz, n10)); st.set_normal(n10); st.set_uv(Vector2(p10.x, p10.z)); st.add_vertex(p10)
			st.set_color(get_col.call(cx + 1, rz + 1, n11)); st.set_normal(n11); st.set_uv(Vector2(p11.x, p11.z)); st.add_vertex(p11)
			st.set_color(get_col.call(cx, rz, n00)); st.set_normal(n00); st.set_uv(Vector2(p00.x, p00.z)); st.add_vertex(p00)
			st.set_color(get_col.call(cx + 1, rz + 1, n11)); st.set_normal(n11); st.set_uv(Vector2(p11.x, p11.z)); st.add_vertex(p11)
			st.set_color(get_col.call(cx, rz + 1, n01)); st.set_normal(n01); st.set_uv(Vector2(p01.x, p01.z)); st.add_vertex(p01)

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = center
	mi.rotation_degrees.y = yaw_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


## 雕刻真实棱角风蚀峡谷巨石网格（三平面 1K 岩石 PBR 贴图，替代原先低分段塑料圆石）
func _make_cliff_boulder_mat() -> ShaderMaterial:
	var prof: Dictionary = MountainTerrain._profile("canyon", true)
	prof["rock_tint"] = Color(0.84, 0.72, 0.60)
	prof["strata_tint"] = Color(0.64, 0.53, 0.43)
	prof["scree_tint"] = Color(0.72, 0.62, 0.51)
	prof["moss_amt"] = 0.0
	prof["normal_str"] = 1.18
	return MountainTerrain._make_mat(prof, true, Vector2(17.0, 29.0))


## 远谷轻薄深度软融合风沙雾纱（使用纯数学噪声，绝无低清贴图块）
func _build_valley_haze_veils(parent: Node3D) -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 dust_warm : source_color = vec3(0.72, 0.56, 0.42);
uniform vec3 dust_cool : source_color = vec3(0.36, 0.38, 0.43);
uniform float opacity = 0.28;
uniform float seed = 0.0;

float h2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), u.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), u.x), u.y);
}
float fbm2(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * vn(p); p = p * 2.05 + vec2(7.1, 3.3); a *= 0.5; }
	return v;
}
void fragment() {
	vec2 uv = UV;
	float v_mask = smoothstep(0.0, 0.30, uv.y) * smoothstep(1.0, 0.38, uv.y);
	float h_mask = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
	float n = fbm2(uv * vec2(5.5, 2.2) + vec2(seed * 3.7, seed * 1.9));
	float dens = (0.45 + 0.55 * n) * v_mask * h_mask;

	float raw_d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_d, 1.0);
	float scene_z = -upos.z / max(upos.w, 1e-5);
	float frag_z = -VERTEX.z;
	float soft_depth = clamp((scene_z - frag_z) / 18.0, 0.0, 1.0);

	ALBEDO = mix(dust_cool, dust_warm, smoothstep(0.85, 0.15, uv.x) * 0.72);
	ALPHA = dens * soft_depth * opacity;
}
"""
	var layers := [
		[Vector3(-4.0, 9.5, -105.0), Vector2(360.0, 26.0), 0.26, 1.0],
		[Vector3(-8.0, 15.0, -195.0), Vector2(520.0, 40.0), 0.36, 2.0],
		[Vector3(0.0, 22.0, -310.0), Vector2(700.0, 54.0), 0.40, 3.0],
	]
	for sp: Array in layers:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("opacity", float(sp[2]))
		m.set_shader_parameter("seed", float(sp[3]))
		var qm := QuadMesh.new()
		qm.size = sp[1] as Vector2
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.material_override = m
		mi.position = sp[0] as Vector3
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## 解析程序化硝烟柱（无低分贴图锯齿）
func _build_smoke_plume(parent: Node3D, base_pos: Vector3, height: float, wind_drift: Vector3, puffs: int, base_scale: float, alpha_base: float, ember_glow := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(base_pos.x * 131.0 + base_pos.z * 73.0)) + 19
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D smoke_tex : filter_linear_mipmap;
uniform vec4 col : source_color = vec4(0.10, 0.095, 0.095, 0.34);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec4 t = texture(smoke_tex, UV);
	ALBEDO = col.rgb;
	ALPHA = t.a * col.a;
}
"""
	for i in puffs:
		var u: float = float(i) / float(maxi(puffs - 1, 1))
		var pos: Vector3 = base_pos + Vector3(0.0, pow(u, 0.78) * height, 0.0) + wind_drift * pow(u, 1.25)
		pos += Vector3(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.14, 0.14), rng.randf_range(-0.28, 0.28)) * (0.7 + u * 2.0)
		var sz: float = base_scale * lerpf(0.62, 2.55, pow(u, 0.85))
		var a: float = alpha_base * sin(clampf(u * 1.10 + 0.10, 0.0, 1.0) * PI) * (1.0 - u * 0.55)
		var c_rgb: Color = Color(0.08, 0.08, 0.085).lerp(Color(0.24, 0.23, 0.24), u * 0.72)
		if ember_glow and i <= 2:
			c_rgb = Color(0.62, 0.26, 0.09).lerp(c_rgb, float(i) / 3.0)
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("smoke_tex", A.smoke_tex())
		m.set_shader_parameter("col", Color(c_rgb.r, c_rgb.g, c_rgb.b, a))
		var qm := QuadMesh.new()
		qm.size = Vector2(sz, sz)
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.material_override = m
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

	if ember_glow:
		var fire_l := OmniLight3D.new()
		fire_l.light_color = Color(1.0, 0.44, 0.14)
		fire_l.light_energy = 2.0
		fire_l.omni_range = 6.5
		fire_l.shadow_enabled = false
		fire_l.position = base_pos + Vector3(0, 0.65, 0)
		parent.add_child(fire_l)


func _hide_aprons(node: Node3D) -> void:
	for nm in ["GroundedApron", "Apron"]:
		var ap: Node = node.find_child(nm, true, false)
		if ap is Node3D:
			(ap as Node3D).visible = false


func _place_prop(parent: Node3D, node: Node3D, x: float, z: float, rot_deg: Vector3, sink := 0.08, sc := Vector3.ONE, pbr_upgrade := true) -> Node3D:
	_hide_aprons(node)
	if pbr_upgrade:
		_upgrade_pbr_materials(node, 1.1)
	parent.add_child(node)
	node.position = Vector3(x, _terrain_h(x, z) - sink, z)
	node.rotation_degrees = rot_deg
	node.scale = Vector3(node.scale.x * sc.x, node.scale.y * sc.y, node.scale.z * sc.z)
	return node


func _pose_biped_leg(leg: Node3D, dz: float, dy: float, hip_splay_deg: float, foot_yaw_deg: float, foot_pitch_deg := 0.0) -> void:
	var kj: Node3D = leg.get_meta("knee")
	var aj: Node3D = leg.get_meta("ankle")
	var KN: Vector3 = leg.get_meta("KN")
	var AN: Vector3 = leg.get_meta("AN")
	var T := Vector2(AN.z + dz, AN.y + dy)
	var L1: float = Vector2(KN.z, KN.y).length()
	var L2: float = Vector2(AN.z - KN.z, AN.y - KN.y).length()
	var d: float = clampf(T.length(), absf(L1 - L2) + 0.01, L1 + L2 - 0.002)
	var th: float = atan2(T.y, T.x)
	var alpha: float = acos(clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0))
	var th0: float = atan2(AN.y, AN.z)
	var p1_0: float = atan2(KN.y, KN.z)
	var sgn: float = 1.0 if wrapf(p1_0 - th0, -PI, PI) > 0.0 else -1.0
	var p1: float = th + sgn * alpha
	var kp := Vector2(cos(p1), sin(p1)) * L1
	var p2: float = atan2(T.y - kp.y, T.x - kp.x)
	var p2_0: float = atan2(AN.y - KN.y, AN.z - KN.z)
	var r_hip: float = p1_0 - p1
	var r_knee: float = p2_0 - p2 - r_hip
	leg.rotation = Vector3(r_hip, deg_to_rad(foot_yaw_deg), deg_to_rad(hip_splay_deg))
	kj.rotation.x = r_knee
	aj.rotation = Vector3(-(r_hip + r_knee) + deg_to_rad(foot_pitch_deg), 0.0, -deg_to_rad(hip_splay_deg))


func _refresh_hero_refs(m: Dictionary) -> void:
	var mech: Node3D = m["root"]
	m["torso"] = mech.get_meta("torso")
	m["legs"] = mech.get_meta("legs")
	m["leg_parts"] = mech.get_meta("leg_parts")
	m["leg_type"] = str(mech.get_meta("leg_type", "biped"))
	var mods: Dictionary = mech.get_meta("modules")
	m["arm_l"] = mods.get("arm_l")
	m["arm_r"] = mods.get("arm_r")


func _build_hero_mech(parent: Node3D, lo: Dictionary, boulder_mat: Material) -> Dictionary:
	# 100% 保留机甲原生 mech_paint 分色涂装、黑钢骨架、镀铬液压杆与琥珀黄警示条（绝不乱盖钢板脏斑贴图！）
	var mech: Node3D = MV.build(lo, true, false)
	mech.name = "HeroPlayerMech"
	parent.add_child(mech)

	var mx := 1.95
	var mz := 2.60
	var base_y: float = _terrain_h(mx, mz)
	# 在脚下补两块扁平 1K 扫描贴图砂岩层板，让战靴稳固咬合在荒原裸岩上
	A.add(parent, A.rock_mesh(3, 36), boulder_mat, Vector3(mx - 0.66, base_y - 0.07, mz - 0.14), Vector3(1, 32, -2), Vector3(1.38, 0.22, 1.12))
	A.add(parent, A.rock_mesh(5, 36), boulder_mat, Vector3(mx + 0.68, base_y - 0.09, mz + 0.22), Vector3(-1, -26, 2), Vector3(1.22, 0.20, 1.02))

	mech.position = Vector3(mx, base_y - 0.012, mz)
	A.ground_decal(parent, A.blob_tex(), Color(0.02, 0.02, 0.025, 0.72), 4.8, Vector3(mx, base_y + 0.035, mz))

	# 清透天光轮廓补光，清晰还原右侧暗面机炮细节、黑钢内构与琥珀警示条对比度
	var cool_fill := OmniLight3D.new()
	cool_fill.light_color = Color(0.68, 0.78, 0.95)
	cool_fill.light_energy = 1.38
	cool_fill.omni_range = 10.5
	cool_fill.shadow_enabled = false
	cool_fill.position = Vector3(mx + 3.2, base_y + 2.8, mz + 4.2)
	parent.add_child(cool_fill)

	var res := {
		"root": mech,
		"base_y": base_y,
	}
	_refresh_hero_refs(res)
	return res


func _apply_mech_pose(
	m: Dictionary,
	legs_yaw_deg: float,
	torso_yaw_deg: float,
	torso_pitch_deg := 0.0,
	arm_pitch_deg := 0.0
) -> void:
	var mech: Node3D = m["root"]
	var torso: Node3D = m["torso"]
	var legs: Node3D = m["legs"]
	var arm_l: Node3D = m["arm_l"]
	var arm_r: Node3D = m["arm_r"]

	# 100% 保持底盘工程原厂挺拔姿态（与整备舱 hub.gd 一致，绝不用外部 IK 扭曲反关节胯腿！）
	mech.rotation_degrees = Vector3.ZERO
	legs.rotation_degrees = Vector3(0.0, legs_yaw_deg, 0.0)
	torso.position.y = float(mech.get_meta("torso_base_y"))
	torso.rotation_degrees = Vector3(torso_pitch_deg, torso_yaw_deg, 0.0)

	if arm_l != null:
		arm_l.rotation_degrees = Vector3(arm_pitch_deg, 0.0, 0.0)
	if arm_r != null:
		arm_r.rotation_degrees = Vector3(arm_pitch_deg, 0.0, 0.0)


func _save_covers(raw_4k: Image, out_dir: String, prefix: String, save_4k := false) -> Image:
	if save_4k:
		raw_4k.save_png(out_dir.path_join(prefix + "_clean_4k.png"))

	# Lanczos 超采样缩放至 2560x1440（1.5x SSAA + 4x MSAA 极致锐度，零锯齿零糊边！）
	var clean_2k: Image = raw_4k.duplicate() as Image
	clean_2k.resize(2560, 1440, Image.INTERPOLATE_LANCZOS)
	clean_2k.save_png(out_dir.path_join(prefix + "_clean.png"))

	# 合成带《潜渊少女》官方金属标题版
	var img: Image = clean_2k.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()

	for py in h:
		var vy: float = (float(py) / float(h) - 0.5) * 2.0
		for px in w:
			var vx: float = (float(px) / float(w) - 0.5) * 2.0
			var r2: float = vx * vx * 0.72 + vy * vy * 0.95
			var vig: float = clampf(1.0 - smoothstep(0.62, 1.90, r2) * 0.26, 0.74, 1.0)
			if vig < 0.999:
				var c: Color = img.get_pixel(px, py)
				img.set_pixel(px, py, Color(c.r * vig, c.g * vig, c.b * vig, 1.0))

	var logo_tex: Texture2D = load("res://assets/title_zh.png")
	if logo_tex != null:
		var logo_img: Image = logo_tex.get_image()
		if logo_img != null:
			if logo_img.is_compressed():
				logo_img.decompress()
			logo_img.convert(Image.FORMAT_RGBA8)
			var target_w: int = int(float(w) * 0.34)
			var target_h: int = int(float(logo_img.get_height()) * (float(target_w) / float(logo_img.get_width())))
			logo_img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)

			var lx: int = int(float(w) * 0.048)
			var ly: int = h - target_h - int(float(h) * 0.064)
			# 柔和暖金暮霭背光晕 + 沉稳投影衬底，让深色拉丝钢字面在暗部岩层上依然层次分明
			var pad_x: int = int(float(target_w) * 0.08)
			var pad_y: int = int(float(target_h) * 0.22)
			for py in range(-pad_y, target_h + pad_y):
				var dy: int = ly + py
				if dy < 0 or dy >= h:
					continue
				var ny: float = (float(py) - float(target_h) * 0.48) / (float(target_h) * 0.68)
				for px in range(-pad_x, target_w + pad_x):
					var dx: int = lx + px
					if dx < 0 or dx >= w:
						continue
					var nx: float = (float(px) - float(target_w) * 0.50) / (float(target_w) * 0.56)
					var d2: float = nx * nx + ny * ny
					if d2 < 1.0:
						var halo: float = pow(1.0 - d2, 2.2) * 0.20
						var dst0: Color = img.get_pixel(dx, dy)
						img.set_pixel(dx, dy, Color(
							clampf(lerpf(dst0.r, 0.58, halo), 0.0, 1.0),
							clampf(lerpf(dst0.g, 0.42, halo), 0.0, 1.0),
							clampf(lerpf(dst0.b, 0.28, halo), 0.0, 1.0),
							1.0
						))

			var shadow_ofs: int = int(float(w) * 0.0035)
			for py in target_h:
				var dy: int = ly + py + shadow_ofs
				if dy < 0 or dy >= h:
					continue
				for px in target_w:
					var dx: int = lx + px + shadow_ofs
					if dx < 0 or dx >= w:
						continue
					var a: float = logo_img.get_pixel(px, py).a
					if a > 0.01:
						var dst: Color = img.get_pixel(dx, dy)
						var sa: float = a * 0.72
						img.set_pixel(dx, dy, Color(dst.r * (1.0 - sa), dst.g * (1.0 - sa), dst.b * (1.0 - sa), 1.0))

			# 提亮拉丝枪钢字面受光质感，匹配夕照暖金高光
			for py in target_h:
				for px in target_w:
					var lc: Color = logo_img.get_pixel(px, py)
					if lc.a > 0.005:
						logo_img.set_pixel(px, py, Color(
							clampf(lc.r * 1.24 + 0.03, 0.0, 1.0),
							clampf(lc.g * 1.20 + 0.02, 0.0, 1.0),
							clampf(lc.b * 1.14 + 0.01, 0.0, 1.0),
							lc.a
						))
			img.blend_rect(logo_img, Rect2i(0, 0, target_w, target_h), Vector2i(lx, ly))

	img.save_png(out_dir.path_join(prefix + ".png"))
	return img


func run() -> void:
	_init_noise()
	for ch in main.get_children():
		if ch is CanvasLayer:
			ch.visible = false

	GameData.quality = 2
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.global_shader_parameter_set("occ_params", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("mech_damage", 0.0)
	RenderingServer.global_shader_parameter_set("weather_wet", 0.05)
	RenderingServer.global_shader_parameter_set("weather_rain", 0.0)

	# 原生 4K (3840x2160) + MSAA 4x，关闭模糊边缘的 FXAA！
	var sv := SubViewport.new()
	sv.size = Vector2i(3840, 2160)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_4X
	sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	sv.use_taa = false
	sv.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	add_child(sv)

	var stage := Node3D.new()
	stage.name = "CoverStage4K"
	sv.add_child(stage)

	# ================================================================
	# 1. 4K 解析体积云天空与侧前掠射黄金夕照（彻底唤醒岩石、钢板与 2K GLB 的微表面法线！）
	# ================================================================
	var sky := Sky.new()
	sky.sky_material = _make_procedural_sky_mat()
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.24, 0.34, 0.52)
	env.ambient_light_energy = 0.54
	env.ambient_light_sky_contribution = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 8.0
	env.ssao_enabled = true
	env.ssao_radius = 1.25
	env.ssao_intensity = 2.45
	env.ssao_power = 1.50
	env.ssao_detail = 0.85
	env.ssao_sharpness = 0.92
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.65
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.42
	env.glow_strength = 0.88
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.15)
	env.set_glow_level(1, 0.68)
	env.set_glow_level(2, 0.52)
	env.set_glow_level(3, 0.30)
	# 冷暖分明的暮色远景空气透视（废原沉入冷蓝暮影，远山与母舰沐浴残阳金辉）
	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.34, 0.40)
	env.fog_density = 0.00032
	env.fog_aerial_perspective = 0.34
	env.fog_sun_scatter = 0.14
	env.fog_height = 3.5
	env.fog_height_density = 0.042
	env.fog_sky_affect = 0.08
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.09
	env.adjustment_saturation = 1.05

	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)

	# 统一全局物理夕阳光场（机甲、地面、岩石、残骸、飞艇 100% 共用同一套太阳阴影、天空漫反射与环境探针，彻底杜绝“假抠图贴层感”！）
	var sun_sky_dir: Vector3 = Vector3(-0.80, 0.28, 0.53).normalized()
	var sun := DirectionalLight3D.new()
	sun.name = "CrossRakingSun"
	sun.light_color = Color(1.0, 0.78, 0.54)
	sun.light_energy = 2.65
	sun.light_angular_distance = 0.42
	sun.shadow_enabled = true
	sun.shadow_bias = 0.022
	sun.shadow_normal_bias = 1.05
	sun.shadow_blur = 1.10
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.055
	sun.directional_shadow_split_2 = 0.17
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 580.0
	stage.add_child(sun)
	sun.basis = Basis.looking_at(-sun_sky_dir, Vector3.UP)
	RenderingServer.global_shader_parameter_set("sun_dir_world", sun.transform.basis.z.normalized())

	# 全场统一的右侧冷蓝天光漫反射补光（地面与机甲暗部同受此光，明暗冷暖完全一致）
	var sky_fill := DirectionalLight3D.new()
	sky_fill.light_color = Color(0.48, 0.62, 0.86)
	sky_fill.light_energy = 0.46
	sky_fill.shadow_enabled = false
	stage.add_child(sky_fill)
	sky_fill.basis = Basis.looking_at(Vector3(-0.68, -0.35, -0.64).normalized(), Vector3.UP)

	# ================================================================
	# 2. 1024px 三平面 PBR 峡谷荒原地形 + 受光层岩断崖群峰
	# ================================================================
	_build_wasteland_terrain(stage)

	var mtn_prof: Dictionary = MountainTerrain._profile("canyon", true)
	mtn_prof["rock_tint"] = Color(0.92, 0.78, 0.64)
	mtn_prof["strata_tint"] = Color(0.68, 0.56, 0.46)
	mtn_prof["scree_tint"] = Color(0.76, 0.65, 0.53)
	mtn_prof["moss_amt"] = 0.04
	mtn_prof["normal_str"] = 1.18
	var mtn_mat: ShaderMaterial = MountainTerrain._make_mat(mtn_prof, true, Vector2.ZERO)

	# 峡谷两侧雄浑层岩峭壁（迎着左前侧阳，展现 1024px 扫描岩石纹理与锋利阴影！）
	_build_canyon_massif(stage, mtn_mat, Vector3(-128.0, 0.0, -165.0), 195.0, 110.0, 38.0, 22.0, 1, 0.72)
	_build_canyon_massif(stage, mtn_mat, Vector3(148.0, 0.0, -225.0), 235.0, 125.0, 36.0, -24.0, 2, 0.74)
	_build_canyon_massif(stage, mtn_mat, Vector3(-225.0, 0.0, -375.0), 360.0, 150.0, 66.0, 12.0, 3, 0.76)
	_build_canyon_massif(stage, mtn_mat, Vector3(175.0, 0.0, -405.0), 380.0, 155.0, 60.0, -12.0, 4, 0.75)
	_build_canyon_massif(stage, mtn_mat, Vector3(-18.0, 0.0, -475.0), 340.0, 130.0, 32.0, 4.0, 5, 0.68)

	_build_valley_haze_veils(stage)

	# ================================================================
	# 3. 远处高空（约 455m 外、海拔 122m）：87.2m 潜渊·信天翁号母舰
	# ================================================================
	var airship: Node3D = AlbatrossAirship.build_integrated({
		"batch_static": false,
		"include_obs2_lights": true,
		"include_bay03_lights": false,
		"obs2_fit_airship": true,
		"bay03_fit_airship": true,
	})
	AlbatrossAirship.set_cutaway_mode(airship, "full_exterior")
	AlbatrossAirship.spin_propellers(airship, 0.42, 10.0)
	for sk_name in ["LandingSkid_1", "LandingSkid_2", "LandingSkid_3", "LandingSkid_4"]:
		var sk: Node = airship.find_child(sk_name, true, false)
		if sk is Node3D:
			(sk as Node3D).position.y += 0.62
	_upgrade_pbr_materials(airship, 1.4)
	stage.add_child(airship)

	var ship_pos := Vector3(-86.0, 74.0, -435.0)
	airship.position = ship_pos
	airship.rotation_degrees = Vector3(2.4, -28.0, -3.2)

	var nav_amber: Material = A.emit(Color(1.0, 0.72, 0.30), 4.8)
	for px_w in [-14.0, -5.5, 2.5, 11.5, 16.8, 22.8]:
		A.add(airship, A.bevel_box(Vector3(1.25, 0.52, 0.16), 0.02), nav_amber, Vector3(px_w, 6.6, 7.18), Vector3.ZERO, Vector3.ONE, false)

	# ================================================================
	# 4. 荒野超精叙事残骸（50MB 2K PBR GLB 巨兽残骸 + 80KB 坠毁运输机 + 1K 钢板精修坦克与重工遗迹）
	# ================================================================
	var boulder_mat: ShaderMaterial = _make_cliff_boulder_mat()

	# [左中景无遮挡视觉焦点] 2K PBR 掘进泰坦重工巨兽残骸（excavator_titan.glb 倒毙姿态，完整展现巨爪与轮机装甲！）
	var titan_x := -12.4
	var titan_z := -20.5
	_spawn_glb_wreck(
		stage,
		"res://assets/models/boss/excavator_titan.glb",
		11.2,
		Vector3(titan_x, _terrain_h(titan_x, titan_z) - 0.52, titan_z),
		Vector3(6.0, 124.0, -8.0),
		"dead"
	)
	A.ground_decal(stage, A.blob_tex(), Color(0.02, 0.02, 0.022, 0.62), 12.0, Vector3(titan_x, _terrain_h(titan_x, titan_z) + 0.06, titan_z))
	_build_smoke_plume(stage, Vector3(titan_x - 0.6, _terrain_h(titan_x, titan_z) + 1.6, titan_z - 0.5), 7.8, Vector3(10.5, 0.0, -4.5), 15, 1.45, 0.22, true)

	# [中景开阔荒原弹坑] 战损主战坦克残骸（移至中轴偏左纵深处，不再遮挡泰坦巨兽，串联左右纵深！）
	var tank_x := -2.6
	var tank_z := -30.5
	_place_prop(stage, TankWreck.build(), tank_x, tank_z, Vector3(-6.0, -34.0, 10.0), 0.30)
	A.ground_decal(stage, A.blob_tex(), Color(0.02, 0.02, 0.022, 0.58), 6.5, Vector3(tank_x, _terrain_h(tank_x, tank_z) + 0.05, tank_z))

	# [中远景峡谷河床] 坠毁倾转四发重型运输机 + 左右两侧六足要塞断腿残骸（丰富轻微俯视下的两侧荒原纵深！）
	_place_prop(stage, TransportVTOL.build(), -4.2, -60.0, Vector3(-9.0, -42.0, 15.0), 0.65)
	_spawn_glb_wreck(
		stage,
		"res://assets/models/boss/citadel_leg.glb",
		7.2,
		Vector3(-21.5, _terrain_h(-21.5, -44.0) - 0.85, -44.0),
		Vector3(58.0, 32.0, -18.0)
	)
	_spawn_glb_wreck(
		stage,
		"res://assets/models/boss/citadel_leg.glb",
		6.8,
		Vector3(10.8, _terrain_h(10.8, -46.0) - 0.80, -46.0),
		Vector3(62.0, -44.0, 20.0)
	)

	# [左翼反坦防线与远景废弃油罐车]
	_place_prop(stage, DragonTeethPipe.build(), -24.5, -34.0, Vector3(1.5, 28.0, -2.0), 0.24)
	_place_prop(stage, FuelTanker.build(), -18.5, -98.0, Vector3(-2.0, 24.0, 4.0), 0.18)

	# [远景错落重工废墟剪影——彻底拉开横向间距，杜绝剪影叠罗汉！]
	_place_prop(stage, CentralTerminus.build(), -6.0, -265.0, Vector3(-7.0, 22.0, 13.0), 2.8, Vector3(2.1, 2.1, 2.1))
	_place_prop(stage, WindTurbine.build(), 18.0, -156.0, Vector3(0.0, -32.0, 3.5), 0.25, Vector3(1.16, 1.18, 1.16))
	_place_prop(stage, RadioMast.build(), -52.0, -142.0, Vector3(4.0, 26.0, -5.8), 0.25, Vector3(1.08, 1.08, 1.08))

	# ================================================================
	# 5. 1K 扫描贴图风蚀乱石群与近景岩缝针茅干草簇（消灭中景孤立黑草斑点！）
	# ================================================================
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261121

	# 左下与右下近景低矮边缘砾石群（使用 1024px mtn_cliff_a/n/r 三平面着色器！）
	A.add(stage, A.rock_mesh(1, 36), boulder_mat, Vector3(-6.4, _terrain_h(-6.4, 9.4) - 0.42, 9.4), Vector3(6, 28, -8), Vector3(1.85, 0.44, 1.38))
	A.add(stage, A.rock_mesh(4, 36), boulder_mat, Vector3(-4.5, _terrain_h(-4.5, 8.2) - 0.26, 8.2), Vector3(-5, 74, 6), Vector3(1.10, 0.38, 0.92))
	A.add(stage, A.rock_mesh(2, 36), boulder_mat, Vector3(5.8, _terrain_h(5.8, 8.2) - 0.22, 8.2), Vector3(-8, -38, 6), Vector3(1.45, 0.36, 1.10))

	# 沿荒原露头坡脚、弹坑与中景戈壁簇化排布高细分天然层理砾石块
	var rock_anchors: Array[Vector2] = []
	for i in 290:
		var rx: float = rng.randf_range(-38.0, 36.0)
		var rz: float = rng.randf_range(-74.0, 10.6)
		if Vector2(rx + 1.75, rz - 13.8).length() < 3.8:
			continue
		if Vector2(rx - 1.95, rz - 2.60).length() < 2.25:
			continue
		if Vector2(rx + 12.4, rz + 20.5).length() < 4.5:
			continue
		if _road_mask(rx, rz) > 0.45 and rng.randf() > 0.12:
			continue
		var ry: float = _terrain_h(rx, rz) - 0.05
		var r_sc: float = rng.randf_range(0.18, 0.82)
		A.add(stage, A.rock_mesh(i % 8, 28), boulder_mat,
			Vector3(rx, ry, rz),
			Vector3(rng.randf_range(-18, 18), rng.randf_range(0, 360), rng.randf_range(-18, 18)),
			Vector3(r_sc * rng.randf_range(0.95, 1.48), r_sc * rng.randf_range(0.38, 0.74), r_sc * rng.randf_range(0.85, 1.35)),
			r_sc > 0.30)
		if rz > -24.0 and r_sc > 0.32:
			rock_anchors.append(Vector2(rx, rz))

	# 依附近景岩缝生长的枯黄针茅干草丛（仅限近中景岩块周边，不向远方沙地撒孤立黑点！）
	var grass_mesh: ArrayMesh = A.grass_clump_mesh()
	var grass_mat: ShaderMaterial = A.foliage_mat("grass").duplicate() as ShaderMaterial
	grass_mat.set_shader_parameter("tint_a", Color(0.62, 0.53, 0.36))
	grass_mat.set_shader_parameter("tint_b", Color(0.86, 0.73, 0.48))
	grass_mat.set_shader_parameter("backlight_str", 0.48)
	grass_mat.set_shader_parameter("sway_amp", 0.0)

	var grass_mm := MultiMesh.new()
	grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	grass_mm.mesh = grass_mesh
	var grass_xfs: Array[Transform3D] = []
	for anchor in rock_anchors:
		var tuft_n: int = rng.randi_range(2, 4)
		for k in tuft_n:
			var ang: float = rng.randf() * TAU
			var rad: float = rng.randf_range(0.35, 1.15)
			var gx: float = anchor.x + cos(ang) * rad
			var gz: float = anchor.y + sin(ang) * rad
			if Vector2(gx + 1.75, gz - 13.8).length() < 3.4:
				continue
			if Vector2(gx - 1.95, gz - 2.60).length() < 2.2:
				continue
			var gy: float = _terrain_h(gx, gz) - 0.03
			var g_sc: float = rng.randf_range(0.34, 0.68)
			var g_bs := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-7, 7)), rng.randf() * TAU, deg_to_rad(rng.randf_range(-7, 7)))).scaled(Vector3(g_sc * 1.10, g_sc * rng.randf_range(0.60, 0.92), g_sc * 1.10))
			grass_xfs.append(Transform3D(g_bs, Vector3(gx, gy, gz)))

	grass_mm.instance_count = grass_xfs.size()
	for i in grass_xfs.size():
		grass_mm.set_instance_transform(i, grass_xfs[i])
	var grass_mmi := MultiMeshInstance3D.new()
	grass_mmi.multimesh = grass_mm
	grass_mmi.material_override = grass_mat
	grass_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(grass_mmi)

	# ================================================================
	# 6. 零假灯、真实场景反射探针与双足踏地压陷接触阴影（与大地光影 100% 物理融合！）
	# ================================================================
	var mx := 1.95
	var mz := 2.60
	var base_y: float = _terrain_h(mx, mz)

	# 机体底盘大范围环境遮蔽 + 左右双足紧贴砾石地面的深色接地阴影 + 脚前自然碎石遮挡
	A.ground_decal(stage, A.blob_tex(), Color(0.02, 0.018, 0.016, 0.52), 4.2, Vector3(mx, base_y + 0.03, mz))
	A.ground_decal(stage, A.blob_tex(), Color(0.015, 0.014, 0.012, 0.82), 1.55, Vector3(mx - 0.58, base_y + 0.035, mz + 0.24))
	A.ground_decal(stage, A.blob_tex(), Color(0.015, 0.014, 0.012, 0.82), 1.55, Vector3(mx + 0.58, base_y + 0.035, mz - 0.20))
	A.add(stage, A.rock_mesh(6, 28), boulder_mat, Vector3(mx - 0.92, _terrain_h(mx - 0.92, mz + 0.95) - 0.04, mz + 0.95), Vector3(8, 42, -5), Vector3(0.38, 0.18, 0.30))
	A.add(stage, A.rock_mesh(7, 28), boulder_mat, Vector3(mx + 0.88, _terrain_h(mx + 0.88, mz + 0.78) - 0.04, mz + 0.78), Vector3(-6, 128, 7), Vector3(0.34, 0.16, 0.28))

	# 真实采样当前荒原与夕阳天空的全局反射探针（无任何人工棚拍灯！）
	var rp := ReflectionProbe.new()
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.box_projection = false
	rp.size = Vector3(60.0, 28.0, 60.0)
	rp.position = Vector3(mx, base_y + 3.0, mz)
	rp.intensity = 0.52
	rp.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	stage.add_child(rp)

	# ================================================================
	# 7. 轻微俯视中长焦机位与三套全肩甲零穿模封面出片
	# ================================================================
	var cam := Camera3D.new()
	cam.near = 0.25
	cam.far = 2400.0
	var cam_attr := CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 320.0
	cam_attr.dof_blur_far_transition = 360.0
	cam_attr.dof_blur_amount = 0.006
	cam_attr.dof_blur_near_enabled = false
	cam.attributes = cam_attr
	stage.add_child(cam)
	cam.make_current()

	cam.fov = 39.0
	cam.global_position = Vector3(-1.85, 5.05, 14.8)
	cam.look_at(Vector3(-0.32, 2.38, -20.0), Vector3.UP)

	var out_dir: String = ProjectSettings.globalize_path("res://review")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var sets := [
		{
			"prefix": "cover_ed1_rocket_biped",
			"legs_yaw": 154.0,
			"torso_yaw": 160.0,
			"loadout": {
				"core": "core_std",
				"legs": "legs_biped",
				"arm_l": "arm_ac30",
				"arm_r": "arm_gatling",
				"back": "back_rocket",
				"gen": "gen_turbine",
			},
		},
		{
			"prefix": "cover_ed2_mk2_shield",
			"legs_yaw": 156.0,
			"torso_yaw": 161.5,
			"loadout": {
				"core": "core_std",
				"legs": "legs_biped",
				"arm_l": "arm_hmg",
				"arm_r": "arm_slug",
				"back": "back_shield",
				"gen": "gen_diesel",
			},
		},
		{
			"prefix": "cover_ed3_fortress_titan",
			"legs_yaw": 154.0,
			"torso_yaw": 160.0,
			"loadout": {
				"core": "core_fortress",
				"legs": "legs_titan",
				"arm_l": "arm_ac30",
				"arm_r": "arm_cannon",
				"back": "back_vls",
				"gen": "gen_turbine",
			},
		},
	]

	await frames(18)

	for idx in sets.size():
		var spec: Dictionary = sets[idx]
		var lo: Dictionary = spec["loadout"]
		# 关闭机甲胸口自带点光源（with_lights=false），完全融入荒原自然日光与接地阴影
		var mech_node: Node3D = MV.build(lo, false, false)
		mech_node.name = "HeroMech_%d" % idx
		stage.add_child(mech_node)
		mech_node.position = Vector3(mx, base_y - 0.032, mz)

		var hero := {"root": mech_node, "base_y": base_y}
		_refresh_hero_refs(hero)
		_apply_mech_pose(hero, float(spec["legs_yaw"]), float(spec["torso_yaw"]), 0.0, 0.0)

		await frames(6)
		await RenderingServer.frame_post_draw
		var raw_img: Image = sv.get_texture().get_image()
		var pfx: String = str(spec["prefix"])
		_save_covers(raw_img, out_dir, pfx, false)
		if idx == 0:
			_save_covers(raw_img, out_dir, "cover", true)
		log_line("已保存 4K/2K 统一自然光封面 [%d/3]: %s.png" % [idx + 1, pfx])

		mech_node.queue_free()
		await frames(2)
