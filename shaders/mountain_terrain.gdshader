shader_type spatial;
// 写实扫描级山体地形着色器 V3：
// 采用 1024x1024 无缝写实岩壁与碎石 PBR 贴图（Albedo + 多尺度 Normal + Roughness/AO/Height）
// 双尺度世界空间三平面去重采样 + 基于高度图的崖壁/碎石自然嵌合 + 温和地质色相微调 + 坡脚无缝融地。
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D cliff_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_r : filter_linear_mipmap_anisotropic, repeat_enable; // R=rough, G=cavity AO, B=height
uniform sampler2D scree_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_r : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;

// 色偏校准乘数（以中性灰棕崖岩均值 ~0.46 为基准，温和映射各战区地质色调，保留照片原貌层次）
uniform vec3 rock_tint : source_color = vec3(1.06, 0.92, 0.78);
uniform vec3 strata_tint : source_color = vec3(0.86, 0.76, 0.66);
uniform vec3 scree_tint : source_color = vec3(0.95, 0.84, 0.70);
uniform vec3 moss_col : source_color = vec3(0.27, 0.30, 0.18);
uniform vec3 foot_col : source_color = vec3(0.37, 0.32, 0.24);
uniform float moss_amt = 0.14;
uniform float strata_freq = 0.55;
uniform vec2 dip_vec = vec2(0.032, 0.020);
uniform float normal_str = 1.05;
global uniform float weather_wet;

varying highp vec3 wp;
varying vec3 wn;
varying vec4 vcol; // r=凹腔AO, g=山脊暴露, b=崩积碎石带, a=归一化高度

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

	// 低频宏观噪声：仅用于双尺度去重混合与自然色温起伏，绝不产生假条纹或脏斑
	float n_mac = texture(n_low, wp.xz * 0.009).r;
	float n_mid = texture(n_low, wp.xz * 0.031 + vec2(0.41, 0.23)).r;
	// 双尺度混合权：细尺（~11m 真实崖块）与大尺（~26m 宏观岩体）自然交叉消除平铺重复感
	float scale_mix = smoothstep(0.28, 0.72, n_mac * 0.65 + n_mid * 0.35);
	float sc_det = 0.088;
	float sc_mac = 0.039;

	vec3 c_alb = vec3(0.0);
	vec3 c_rm = vec3(0.0);
	vec3 c_npert = vec3(0.0);

	if (w.x > 0.03) {
		vec2 p = vec2(wp.z, wp.y);
		vec2 u1 = p * sc_det;
		vec2 u2 = p * sc_mac + vec2(0.37, 0.59);
		vec3 a1 = texture(cliff_a, u1).rgb;
		vec3 a2 = texture(cliff_a, u2).rgb;
		vec3 r1 = texture(cliff_r, u1).rgb;
		vec3 r2 = texture(cliff_r, u2).rgb;
		vec2 n1 = texture(cliff_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(cliff_n, u2).rg * 2.0 - 1.0;
		c_alb += mix(a1, a2, scale_mix * 0.48) * w.x;
		c_rm += mix(r1, r2, scale_mix * 0.45) * w.x;
		vec2 tn = n1 * 0.72 + n2 * 0.48;
		c_npert += vec3(0.0, tn.y * sx, tn.x * sx) * w.x;
	}
	if (w.y > 0.03) {
		vec2 p = wp.xz;
		vec2 u1 = p * (sc_det * 0.92);
		vec2 u2 = p * (sc_mac * 0.92) + vec2(0.19, 0.71);
		vec3 a1 = texture(cliff_a, u1).rgb;
		vec3 a2 = texture(cliff_a, u2).rgb;
		vec3 r1 = texture(cliff_r, u1).rgb;
		vec3 r2 = texture(cliff_r, u2).rgb;
		vec2 n1 = texture(cliff_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(cliff_n, u2).rg * 2.0 - 1.0;
		c_alb += mix(a1, a2, scale_mix * 0.48) * w.y;
		c_rm += mix(r1, r2, scale_mix * 0.45) * w.y;
		vec2 tn = n1 * 0.68 + n2 * 0.44;
		c_npert += vec3(tn.x * sy_sgn, 0.0, tn.y * sy_sgn) * w.y;
	}
	if (w.z > 0.03) {
		vec2 p = vec2(wp.x, wp.y);
		vec2 u1 = p * sc_det;
		vec2 u2 = p * sc_mac + vec2(0.61, 0.27);
		vec3 a1 = texture(cliff_a, u1).rgb;
		vec3 a2 = texture(cliff_a, u2).rgb;
		vec3 r1 = texture(cliff_r, u1).rgb;
		vec3 r2 = texture(cliff_r, u2).rgb;
		vec2 n1 = texture(cliff_n, u1).rg * 2.0 - 1.0;
		vec2 n2 = texture(cliff_n, u2).rg * 2.0 - 1.0;
		c_alb += mix(a1, a2, scale_mix * 0.48) * w.z;
		c_rm += mix(r1, r2, scale_mix * 0.45) * w.z;
		vec2 tn = n1 * 0.72 + n2 * 0.48;
		c_npert += vec3(tn.x * sz, tn.y * sz, 0.0) * w.z;
	}

	// 极柔和的自然岩层色温微移（避免单调，不画假条带）
	float band = 0.5 + 0.5 * sin(wp.y * strata_freq + dot(wp.xz, dip_vec) + (n_mac - 0.5) * 3.0);
	vec3 rock_col = c_alb * mix(strata_tint, rock_tint, smoothstep(0.2, 0.8, band));
	rock_col *= mix(0.90, 1.08, n_mac * 0.6 + n_mid * 0.4);
	// 迎风山脊极轻微日晒泛浅
	float ridge_hi = clamp(vcol.g, 0.0, 1.0);
	rock_col *= 1.0 + ridge_hi * 0.08;

	// ---- 2. 崩积碎石与平顶风化层（基于高度图自然填充岩石凹缝，尖岩棱自然穿透）
	float slope_up = clamp(N.y, 0.0, 1.0);
	float scree_raw = clamp(
		smoothstep(0.70, 0.90, slope_up + (n_mid - 0.5) * 0.08) * 0.85
		+ vcol.b * smoothstep(0.46, 0.80, slope_up) * 0.62
		- ridge_hi * 0.42,
		0.0, 1.0
	);
	float foot_w = (1.0 - smoothstep(0.05, 1.45, wp.y + (n_mid - 0.5) * 0.45)) * smoothstep(0.32, 0.78, slope_up);

	vec3 col = rock_col;
	vec3 n_pert = c_npert;
	float rough = c_rm.r;
	float cav_ao = c_rm.g;

	if (scree_raw > 0.02 || foot_w > 0.02) {
		vec2 suv1 = wp.xz * 0.145;
		vec2 suv2 = wp.xz * 0.062 + vec2(0.43, 0.29);
		vec3 sa = mix(texture(scree_a, suv1).rgb, texture(scree_a, suv2).rgb, scale_mix * 0.42);
		vec3 sr = mix(texture(scree_r, suv1).rgb, texture(scree_r, suv2).rgb, scale_mix * 0.42);
		vec2 sn = (texture(scree_n, suv1).rg * 2.0 - 1.0) * 0.72 + (texture(scree_n, suv2).rg * 2.0 - 1.0) * 0.35;

		// 高度图权重混合：碎石先铺进低洼岩缝，凸出的硬岩棱保持裸露
		float h_diff = (sr.b + scree_raw * 1.15) - (c_rm.b + (1.0 - scree_raw) * 0.95);
		float scree_m = smoothstep(-0.18, 0.22, h_diff) * scree_raw;

		vec3 s_col = sa * scree_tint * mix(0.90, 1.10, n_mid);
		// 平顶极稀疏干苔/草皮微染
		float moss_m = moss_amt * smoothstep(0.84, 0.95, slope_up) * smoothstep(0.42, 0.78, n_mac * 0.65 + n_mid * 0.35) * smoothstep(0.8, 3.5, wp.y);
		s_col = mix(s_col, moss_col * mix(0.78, 1.22, sa.r), moss_m);

		col = mix(col, s_col, scree_m);
		n_pert = mix(n_pert, vec3(sn.x, 0.0, sn.y), scree_m * 0.82);
		rough = mix(rough, sr.r, scree_m);
		cav_ao = mix(cav_ao, sr.g, scree_m);
	}

	// ---- 3. 坡脚无缝融地（过渡到战区地表基色）
	vec3 c_foot = foot_col * mix(0.90, 1.08, n_mac * 0.55 + n_mid * 0.45);
	col = mix(col, c_foot, foot_w * 0.88);
	n_pert *= (1.0 - foot_w * 0.55);

	// 切平面法线投影，确保光照自然饱满不发糊
	n_pert -= N * dot(n_pert, N);
	vec3 w_nrm = normalize(N + n_pert * normal_str);

	float ao_v = clamp(vcol.r, 0.54, 1.0);
	col *= mix(0.72, 1.0, ao_v);

	float wet = clamp(weather_wet, 0.0, 1.0);
	col *= mix(1.0, 0.78, wet * (0.45 + 0.55 * slope_up));

	NORMAL = normalize((VIEW_MATRIX * vec4(w_nrm, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = clamp(rough - wet * (0.28 + 0.18 * slope_up), 0.32, 0.97);
	SPECULAR = mix(0.28, 0.48, wet * 0.75 + (1.0 - slope_up) * 0.12);
	AO = clamp(ao_v * mix(0.55, 1.0, cav_ao), 0.32, 1.0);
	AO_LIGHT_AFFECT = 0.45;
}
