shader_type spatial;
// 写实扫描级火山黑曜岩（Real Icelandic Obsidian & Fractured Basalt）着色器 V3：
// 直接采用 1024x1024 照片级玄武黑曜岩贴图（mtn_obsidian_a/n/r）：
// - R=精准物理粗糙度（真实贝壳状玻璃断口 0.26~0.38 vs 粗糙玄武岩棱/火山灰缝 0.72~0.88）；
// - G=岩缝腔体 AO；B=真实贝壳状玻璃断口掩码（仅在照片里真正光滑的玻璃断口处施加柔和玻璃光泽与冷釉高光）；
// 彻底杜绝塑料袋反光、程序 Voronoi 假块与平铺接缝。
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D obs_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D obs_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D obs_r : filter_linear_mipmap_anisotropic, repeat_enable; // R=rough, G=cavity AO, B=glass scar mask
uniform sampler2D scree_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;

uniform vec3 rock_tint : source_color = vec3(0.94, 0.96, 1.06);
uniform vec3 foot_col : source_color = vec3(0.145, 0.128, 0.190);
uniform vec3 sheen_col : source_color = vec3(0.32, 0.42, 0.66);
uniform float normal_str = 0.88;
global uniform float weather_wet;

varying highp vec3 wp;
varying vec3 wn;
varying vec4 vcol;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR;
}

void fragment() {
	vec3 N = normalize(wn);
	vec3 an = abs(N);
	vec3 w = pow(an, vec3(6.0));
	w /= max(w.x + w.y + w.z, 1e-4);
	float sx = N.x >= 0.0 ? 1.0 : -1.0;
	float sy_sgn = N.y >= 0.0 ? 1.0 : -1.0;
	float sz = N.z >= 0.0 ? 1.0 : -1.0;

	float n_mac = texture(n_low, wp.xz * 0.010).r;
	float n_mid = texture(n_low, wp.xz * 0.034 + vec2(0.31, 0.57)).r;
	float scale_mix = smoothstep(0.28, 0.72, n_mac * 0.65 + n_mid * 0.35);

	// 柱状黑曜岩壁双尺度世界空间三平面采样（大尺度 18m 真实贝壳玻璃断口 + 38m 巨型玄武岩柱，杜绝细碎高光噪点）
	float sc_det = 0.056;
	float sc_mac = 0.026;
	vec3 o_alb = vec3(0.0);
	vec3 o_rm = vec3(0.0);
	vec3 o_npert = vec3(0.0);

	if (w.x > 0.03) {
		vec2 p = vec2(wp.z, wp.y * 0.92);
		vec2 u1 = p * sc_det;
		vec2 u2 = p * sc_mac + vec2(0.37, 0.59);
		o_alb += mix(texture(obs_a, u1).rgb, texture(obs_a, u2).rgb, scale_mix * 0.42) * w.x;
		o_rm += mix(texture(obs_r, u1).rgb, texture(obs_r, u2).rgb, scale_mix * 0.42) * w.x;
		vec2 n1 = texture(obs_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(obs_n, u2).rg * 2.0 - 1.0;
		vec2 tn = n1 * 0.74 + n2 * 0.44;
		o_npert += vec3(0.0, tn.y * sx, tn.x * sx) * w.x;
	}
	if (w.y > 0.03) {
		vec2 p = wp.xz;
		vec2 u1 = p * sc_det;
		vec2 u2 = p * sc_mac + vec2(0.19, 0.71);
		o_alb += mix(texture(obs_a, u1).rgb, texture(obs_a, u2).rgb, scale_mix * 0.42) * w.y;
		o_rm += mix(texture(obs_r, u1).rgb, texture(obs_r, u2).rgb, scale_mix * 0.42) * w.y;
		vec2 n1 = texture(obs_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(obs_n, u2).rg * 2.0 - 1.0;
		vec2 tn = n1 * 0.68 + n2 * 0.40;
		o_npert += vec3(tn.x * sy_sgn, 0.0, tn.y * sy_sgn) * w.y;
	}
	if (w.z > 0.03) {
		vec2 p = vec2(wp.x, wp.y * 0.92);
		vec2 u1 = p * sc_det;
		vec2 u2 = p * sc_mac + vec2(0.61, 0.27);
		o_alb += mix(texture(obs_a, u1).rgb, texture(obs_a, u2).rgb, scale_mix * 0.42) * w.z;
		o_rm += mix(texture(obs_r, u1).rgb, texture(obs_r, u2).rgb, scale_mix * 0.42) * w.z;
		vec2 n1 = texture(obs_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(obs_n, u2).rg * 2.0 - 1.0;
		vec2 tn = n1 * 0.74 + n2 * 0.44;
		o_npert += vec3(tn.x * sz, tn.y * sz, 0.0) * w.z;
	}

	float slope_up = clamp(N.y, 0.0, 1.0);
	float ridge_hi = clamp(vcol.g, 0.0, 1.0);
	float rough_tex = o_rm.r;
	float cav_ao = o_rm.g;
	float glass_m = o_rm.b;

	// 真实黑曜玄武岩配色（保留照片本身漆黑玻璃与冷灰岩棱层次，略微沉稳压暗）
	vec3 col = o_alb * rock_tint * mix(0.84, 1.06, n_mac * 0.6 + n_mid * 0.4);
	// 仅在真正平顶平台与极矮坡脚混入暗色碎矿渣，绝不覆盖峭壁黑曜岩
	float ash_top = smoothstep(0.84, 0.96, slope_up + (n_mid - 0.5) * 0.08 - ridge_hi * 0.15) * 0.55;
	float foot_w = (1.0 - smoothstep(0.06, 1.55, wp.y + (n_mid - 0.5) * 0.50)) * smoothstep(0.32, 0.78, slope_up);
	float dust_m = clamp(ash_top + foot_w * 0.90, 0.0, 1.0);

	vec3 n_pert = o_npert;
	float rough = rough_tex;
	if (dust_m > 0.02) {
		vec2 suv = wp.xz * 0.15;
		vec3 sa = texture(scree_a, suv).rgb * vec3(0.24, 0.22, 0.30);
		vec2 sn = texture(scree_n, suv).rg * 2.0 - 1.0;
		vec3 c_d = mix(sa, foot_col * mix(0.88, 1.10, n_mac), foot_w);
		col = mix(col, c_d, dust_m);
		n_pert = mix(n_pert, vec3(sn.x, 0.0, sn.y) * 0.7, dust_m * 0.75);
		rough = mix(rough, 0.88, dust_m);
		glass_m *= (1.0 - dust_m);
	}

	n_pert -= N * dot(n_pert, N);
	vec3 w_nrm = normalize(N + n_pert * normal_str * (1.0 - foot_w * 0.5));

	// 极克制的真实黑曜玻璃掠射冷晕（只作用于照片里真实的贝壳状玻璃断口处，绝不整面涂塑料膜！）
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	float fres = pow(1.0 - clamp(dot(w_nrm, V), 0.0, 1.0), 3.6);
	float ao_v = clamp(vcol.r, 0.50, 1.0);
	col *= mix(0.68, 1.0, ao_v);

	float wet = clamp(weather_wet, 0.0, 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(w_nrm, 0.0)).xyz);
	ALBEDO = col;
	METALLIC = glass_m * 0.12;
	ROUGHNESS = clamp(rough + 0.05 - wet * 0.10, 0.30, 0.95);
	SPECULAR = mix(0.36, 0.68, glass_m);
	// 仅真实的贝壳状玻璃断口带克制丝滑釉质高光，绝不出现细碎塑料反光
	CLEARCOAT = glass_m * 0.24;
	CLEARCOAT_ROUGHNESS = 0.24;
	EMISSION = sheen_col * fres * glass_m * 0.055 * ao_v;
	AO = clamp(ao_v * mix(0.42, 1.0, cav_ao), 0.26, 1.0);
	AO_LIGHT_AFFECT = 0.48;
}
