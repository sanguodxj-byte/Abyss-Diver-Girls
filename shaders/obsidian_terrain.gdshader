shader_type spatial;
// 写实扫描级火山黑曜岩（Real Icelandic Obsidian & Fractured Basalt）着色器 V4：
// - 近景保留 1024px 真实贝壳状玻璃断口与柱状玄武岩肌理；
// - 远景/高空鸟瞰自动引入距离法线 LOD 柔化（彻底消除远景细碎白反光噪点）+ 高处黑曜岩脊冷灰蓝轮廓层次，
//   确保大俯视与实战近景下火山口环壁体块均清晰震撼。
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D obs_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D obs_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D obs_r : filter_linear_mipmap_anisotropic, repeat_enable; // R=rough, G=cavity AO, B=glass scar mask
uniform sampler2D scree_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;

uniform vec2 world_offset = vec2(0.0, 0.0);
uniform vec3 rock_tint : source_color = vec3(1.06, 1.08, 1.22);
uniform vec3 scree_tint : source_color = vec3(0.23, 0.21, 0.30);
uniform vec3 sheen_col : source_color = vec3(0.34, 0.44, 0.68);
uniform vec3 ridge_rim_col : source_color = vec3(0.24, 0.28, 0.46);
uniform float normal_str = 0.86;
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

	vec2 gxz = wp.xz + world_offset;
	float dist_cam = length(CAMERA_POSITION_WORLD - wp);
	float lod_far = smoothstep(65.0, 210.0, dist_cam);

	float n_mac = texture(n_low, gxz * 0.0095).r;
	float n_mid = texture(n_low, gxz * 0.032 + vec2(0.31, 0.57)).r;
	float scale_mix = smoothstep(0.28, 0.72, n_mac * 0.65 + n_mid * 0.35);

	float sc_det = 0.056;
	float sc_mac = 0.025;
	vec3 o_alb = vec3(0.0);
	vec3 o_rm = vec3(0.0);
	vec3 o_npert = vec3(0.0);

	if (w.x > 0.03) {
		vec2 p = vec2(gxz.y, wp.y * 0.92);
		vec2 u1 = p * sc_det;
		vec2 u2 = p * sc_mac + vec2(0.37, 0.59);
		o_alb += mix(texture(obs_a, u1).rgb, texture(obs_a, u2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.35, 0.0, 0.88)) * w.x;
		o_rm += mix(texture(obs_r, u1).rgb, texture(obs_r, u2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.35, 0.0, 0.88)) * w.x;
		vec2 n1 = texture(obs_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(obs_n, u2).rg * 2.0 - 1.0;
		vec2 tn = n1 * mix(0.72, 0.22, lod_far) + n2 * mix(0.44, 0.36, lod_far);
		o_npert += vec3(0.0, tn.y * sx, tn.x * sx) * w.x;
	}
	if (w.y > 0.03) {
		vec2 p = gxz;
		vec2 u1 = p * sc_det;
		vec2 u2 = p * sc_mac + vec2(0.19, 0.71);
		o_alb += mix(texture(obs_a, u1).rgb, texture(obs_a, u2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.35, 0.0, 0.88)) * w.y;
		o_rm += mix(texture(obs_r, u1).rgb, texture(obs_r, u2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.35, 0.0, 0.88)) * w.y;
		vec2 n1 = texture(obs_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(obs_n, u2).rg * 2.0 - 1.0;
		vec2 tn = n1 * mix(0.66, 0.20, lod_far) + n2 * mix(0.40, 0.32, lod_far);
		o_npert += vec3(tn.x * sy_sgn, 0.0, tn.y * sy_sgn) * w.y;
	}
	if (w.z > 0.03) {
		vec2 p = vec2(gxz.x, wp.y * 0.92);
		vec2 u1 = p * sc_det;
		vec2 u2 = p * sc_mac + vec2(0.61, 0.27);
		o_alb += mix(texture(obs_a, u1).rgb, texture(obs_a, u2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.35, 0.0, 0.88)) * w.z;
		o_rm += mix(texture(obs_r, u1).rgb, texture(obs_r, u2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.35, 0.0, 0.88)) * w.z;
		vec2 n1 = texture(obs_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(obs_n, u2).rg * 2.0 - 1.0;
		vec2 tn = n1 * mix(0.72, 0.22, lod_far) + n2 * mix(0.44, 0.36, lod_far);
		o_npert += vec3(tn.x * sz, tn.y * sz, 0.0) * w.z;
	}

	float slope_up = clamp(N.y, 0.0, 1.0);
	float ridge_hi = clamp(vcol.g, 0.0, 1.0);
	float rough_tex = o_rm.r;
	float cav_ao = o_rm.g;
	float glass_m = o_rm.b;

	vec3 col = o_alb * rock_tint * mix(0.84, 1.08, n_mac * 0.6 + n_mid * 0.4);
	// 高处黑曜岩山脊与岩台棱线微提冷钢蓝灰（高空俯视也能清晰看出火山口梯级与主脊轮廓）
	float crest_elev = smoothstep(7.0, 28.0, wp.y) * ridge_hi;
	col += ridge_rim_col * crest_elev * 0.14;

	float ash_top = smoothstep(0.84, 0.96, slope_up + (n_mid - 0.5) * 0.08 - ridge_hi * 0.15) * 0.48;
	float foot_scree = 1.0 - smoothstep(0.20, 2.35, wp.y + (n_mid - 0.5) * 0.60);
	float dust_m = clamp(max(ash_top, foot_scree), 0.0, 1.0);

	vec3 n_pert = o_npert;
	float rough = rough_tex;
	if (dust_m > 0.02) {
		vec2 suv1 = gxz * 0.140;
		vec2 suv2 = gxz * 0.058 + vec2(0.43, 0.29);
		vec3 sa = mix(texture(scree_a, suv1).rgb, texture(scree_a, suv2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.28, 0.0, 0.85));
		vec2 sn = (texture(scree_n, suv1).rg * 2.0 - 1.0) * mix(0.70, 0.34, lod_far) + (texture(scree_n, suv2).rg * 2.0 - 1.0) * 0.36;
		vec3 c_d = sa * scree_tint * mix(0.90, 1.10, n_mid);
		col = mix(col, c_d, dust_m);
		n_pert = mix(n_pert, vec3(sn.x, 0.0, sn.y), dust_m * 0.82);
		rough = mix(rough, 0.86, dust_m);
		glass_m *= (1.0 - dust_m);
	}

	float foot_flat = 1.0 - smoothstep(0.0, 1.10, wp.y);
	vec3 N_base = normalize(mix(N, vec3(0.0, 1.0, 0.0), foot_flat * 0.72));
	n_pert -= N_base * dot(n_pert, N_base);
	float eff_nstr = normal_str * mix(1.0, 0.52, lod_far) * mix(1.0, 0.72, foot_flat);
	vec3 w_nrm = normalize(N_base + n_pert * eff_nstr);

	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	float fres = pow(1.0 - clamp(dot(w_nrm, V), 0.0, 1.0), 3.4);
	float ao_v = clamp(vcol.r, 0.50, 1.0);
	col *= mix(0.70, 1.0, ao_v);

	float wet = clamp(weather_wet, 0.0, 1.0);
	// 远距柔和略升粗糙度，彻底消除大俯视下细碎白点，近景保留真实黑曜玻璃丝滑镜光
	float eff_rough = clamp(rough + 0.05 + lod_far * 0.14 - wet * 0.10, 0.30, 0.95);
	NORMAL = normalize((VIEW_MATRIX * vec4(w_nrm, 0.0)).xyz);
	ALBEDO = col;
	METALLIC = glass_m * mix(0.12, 0.04, lod_far);
	ROUGHNESS = eff_rough;
	SPECULAR = mix(0.36, mix(0.68, 0.46, lod_far), glass_m);
	CLEARCOAT = glass_m * mix(0.24, 0.06, lod_far);
	CLEARCOAT_ROUGHNESS = mix(0.24, 0.42, lod_far);
	EMISSION = (sheen_col * fres * glass_m * 0.055 + ridge_rim_col * crest_elev * fres * 0.10) * ao_v;
	AO = clamp(ao_v * mix(0.45, 1.0, cav_ao), 0.28, 1.0);
	AO_LIGHT_AFFECT = 0.48;
}
