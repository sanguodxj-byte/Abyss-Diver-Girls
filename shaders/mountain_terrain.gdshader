shader_type spatial;
// 写实扫描级固定世界连续山体着色器 V4：
// - 全程基于全局世界坐标 (wp.xz + world_offset) 采样，跨战区边界岩层/碎石 100% 无缝对齐；
// - 双尺度三平面去重采样 + 远距法线 LOD 柔化（近看锐利颗粒、高空鸟瞰零噪点）；
// - 基于高度图的崖壁/崩积碎石嵌合 + 坡脚无缝汇入冲积扇碎石裙边。
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D cliff_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_r : filter_linear_mipmap_anisotropic, repeat_enable; // R=rough, G=cavity AO, B=height
uniform sampler2D scree_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_r : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;

uniform vec2 world_offset = vec2(0.0, 0.0);
uniform vec3 rock_tint : source_color = vec3(1.04, 0.89, 0.73);
uniform vec3 strata_tint : source_color = vec3(0.83, 0.70, 0.58);
uniform vec3 scree_tint : source_color = vec3(0.85, 0.75, 0.61);
uniform vec3 moss_col : source_color = vec3(0.27, 0.30, 0.18);
uniform float moss_amt = 0.14;
uniform float strata_freq = 0.48;
uniform vec2 dip_vec = vec2(0.028, 0.018);
uniform float normal_str = 1.06;
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
	// 限制三平面最多采样 2 个主轴（忽略 <0.15 弱轴，极端三轴均分时剔除最弱轴）
	if (w.x <= w.y && w.x <= w.z) {
		w.x = 0.0;
	} else if (w.y <= w.z) {
		w.y = 0.0;
	} else {
		w.z = 0.0;
	}
	w = mix(vec3(0.0), w, greaterThan(w, vec3(0.15)));
	w /= max(w.x + w.y + w.z, 1e-4);
	float sx = N.x >= 0.0 ? 1.0 : -1.0;
	float sy_sgn = N.y >= 0.0 ? 1.0 : -1.0;
	float sz = N.z >= 0.0 ? 1.0 : -1.0;

	// 全局固定世界坐标（跨战区无缝对齐）
	vec2 gxz = wp.xz + world_offset;
	float dist_cam = length(CAMERA_POSITION_WORLD - wp);
	float lod_far = smoothstep(65.0, 240.0, dist_cam);
	bool skip_r = dist_cam > 180.0;

	float n_mac = texture(n_low, gxz * 0.0085).r;
	float n_mid = texture(n_low, gxz * 0.029 + vec2(0.41, 0.23)).r;
	float n_crag = texture(n_low, gxz * 0.072 + vec2(0.17, 0.63)).r;
	float scale_mix = smoothstep(0.28, 0.72, n_mac * 0.65 + n_mid * 0.35);
	float sc_det = 0.085;
	float sc_mac = 0.034;

	vec3 c_alb = vec3(0.0);
	vec3 c_rm = skip_r ? vec3(0.84, 0.74, 0.50) : vec3(0.0);
	vec3 c_npert = vec3(0.0);

	float smix_a = clamp(scale_mix * 0.48 + lod_far * 0.26, 0.0, 0.82);
	float smix_r = clamp(scale_mix * 0.45 + lod_far * 0.24, 0.0, 0.82);
	bool far_only = lod_far > 0.86;
	float n1_w = mix(0.76, 0.42, lod_far);
	float n1_wy = mix(0.70, 0.38, lod_far);

	if (w.x > 0.15) {
		vec2 p = vec2(gxz.y, wp.y);
		vec2 u2 = p * sc_mac + vec2(0.37, 0.59);
		if (far_only) {
			c_alb += texture(cliff_a, u2).rgb * w.x;
			if (!skip_r) c_rm += texture(cliff_r, u2).rgb * w.x;
			vec2 tn = (texture(cliff_n, u2).rg * 2.0 - 1.0) * 0.88;
			c_npert += vec3(0.0, tn.y * sx, tn.x * sx) * w.x;
		} else {
			vec2 u1 = p * sc_det;
			c_alb += mix(texture(cliff_a, u1).rgb, texture(cliff_a, u2).rgb, smix_a) * w.x;
			if (!skip_r) c_rm += mix(texture(cliff_r, u1).rgb, texture(cliff_r, u2).rgb, smix_r) * w.x;
			vec2 n1 = texture(cliff_n, u1).rg * 2.0 - 1.0;
			vec2 n2 = texture(cliff_n, u2).rg * 2.0 - 1.0;
			vec2 tn = n1 * n1_w + n2 * 0.62;
			c_npert += vec3(0.0, tn.y * sx, tn.x * sx) * w.x;
		}
	}
	if (w.y > 0.15) {
		vec2 p = gxz;
		vec2 u2 = p * (sc_mac * 0.90) + vec2(0.19, 0.71);
		if (far_only) {
			c_alb += texture(cliff_a, u2).rgb * w.y;
			if (!skip_r) c_rm += texture(cliff_r, u2).rgb * w.y;
			vec2 tn = (texture(cliff_n, u2).rg * 2.0 - 1.0) * 0.80;
			c_npert += vec3(tn.x * sy_sgn, 0.0, tn.y * sy_sgn) * w.y;
		} else {
			vec2 u1 = p * (sc_det * 0.90);
			c_alb += mix(texture(cliff_a, u1).rgb, texture(cliff_a, u2).rgb, smix_a) * w.y;
			if (!skip_r) c_rm += mix(texture(cliff_r, u1).rgb, texture(cliff_r, u2).rgb, smix_r) * w.y;
			vec2 n1 = texture(cliff_n, u1).rg * 2.0 - 1.0;
			vec2 n2 = texture(cliff_n, u2).rg * 2.0 - 1.0;
			vec2 tn = n1 * n1_wy + n2 * 0.56;
			c_npert += vec3(tn.x * sy_sgn, 0.0, tn.y * sy_sgn) * w.y;
		}
	}
	if (w.z > 0.15) {
		vec2 p = vec2(gxz.x, wp.y);
		vec2 u2 = p * sc_mac + vec2(0.61, 0.27);
		if (far_only) {
			c_alb += texture(cliff_a, u2).rgb * w.z;
			if (!skip_r) c_rm += texture(cliff_r, u2).rgb * w.z;
			vec2 tn = (texture(cliff_n, u2).rg * 2.0 - 1.0) * 0.88;
			c_npert += vec3(tn.x * sz, tn.y * sz, 0.0) * w.z;
		} else {
			vec2 u1 = p * sc_det;
			c_alb += mix(texture(cliff_a, u1).rgb, texture(cliff_a, u2).rgb, smix_a) * w.z;
			if (!skip_r) c_rm += mix(texture(cliff_r, u1).rgb, texture(cliff_r, u2).rgb, smix_r) * w.z;
			vec2 n1 = texture(cliff_n, u1).rg * 2.0 - 1.0;
			vec2 n2 = texture(cliff_n, u2).rg * 2.0 - 1.0;
			vec2 tn = n1 * n1_w + n2 * 0.62;
			c_npert += vec3(tn.x * sz, tn.y * sz, 0.0) * w.z;
		}
	}

	// 双阶沉积岩层理 + 陡壁竖向节理裂隙（保证 200~600m 远山依然有硬朗岩石折面与层理对比）
	float strata_phase = wp.y * strata_freq + dot(gxz, dip_vec) + (n_mac - 0.5) * 3.2;
	float band_main = 0.5 + 0.5 * sin(strata_phase);
	float band_sub = 0.5 + 0.5 * sin(strata_phase * 2.65 + (n_mid - 0.5) * 2.1);
	float band = clamp(band_main * 0.72 + band_sub * 0.28, 0.0, 1.0);
	float cliff_steep = clamp(1.0 - N.y, 0.0, 1.0);
	float cleft = smoothstep(0.62, 0.88, abs(n_crag * 2.0 - 1.0)) * cliff_steep;
	vec3 rock_col = c_alb * mix(strata_tint, rock_tint, smoothstep(0.18, 0.78, band));
	rock_col *= mix(0.82, 1.14, n_mac * 0.58 + n_mid * 0.42);
	rock_col *= 1.0 - cleft * 0.28;
	float ridge_hi = clamp(vcol.g, 0.0, 1.0);
	rock_col *= 1.0 + ridge_hi * 0.22;
	// 岩层台阶与竖向节理法线增强（远景山脊不再像平滑灰泥）
	float ledge_n = cos(strata_phase) * strata_freq * 0.42 * cliff_steep;
	float cleft_nx = (texture(n_low, (gxz + vec2(2.2, 0.0)) * 0.072 + vec2(0.17, 0.63)).r - n_crag) * 2.4 * cliff_steep;
	float cleft_nz = (texture(n_low, (gxz + vec2(0.0, 2.2)) * 0.072 + vec2(0.17, 0.63)).r - n_crag) * 2.4 * cliff_steep;
	c_npert += vec3(cleft_nx, ledge_n, cleft_nz);

	// ---- 2. 崩积碎石与冲沟碎石坡（坡脚 0~2.2m 与冲积扇裙边像素级无缝统一）
	float slope_up = clamp(N.y, 0.0, 1.0);
	float foot_scree = 1.0 - smoothstep(0.20, 2.25, wp.y + (n_mid - 0.5) * 0.65);
	float scree_raw = clamp(
		max(
			smoothstep(0.68, 0.88, slope_up + (n_mid - 0.5) * 0.08) * 0.85
			+ vcol.b * smoothstep(0.44, 0.78, slope_up) * 0.68
			- ridge_hi * 0.46,
			foot_scree
		),
		0.0, 1.0
	);

	vec3 col = rock_col;
	vec3 n_pert = c_npert;
	float rough = c_rm.r;
	float cav_ao = c_rm.g * (1.0 - cleft * 0.32);

	if (scree_raw > 0.02) {
		vec2 suv2 = gxz * 0.058 + vec2(0.43, 0.29);
		vec3 sa;
		vec3 sr = vec3(0.88, 0.80, 0.50);
		vec2 sn;
		if (far_only) {
			sa = texture(scree_a, suv2).rgb;
			if (!skip_r) sr = texture(scree_r, suv2).rgb;
			sn = (texture(scree_n, suv2).rg * 2.0 - 1.0) * 0.72;
		} else {
			vec2 suv1 = gxz * 0.140;
			float sc_m = clamp(scale_mix * 0.42 + lod_far * 0.26, 0.0, 0.82);
			sa = mix(texture(scree_a, suv1).rgb, texture(scree_a, suv2).rgb, sc_m);
			if (!skip_r) sr = mix(texture(scree_r, suv1).rgb, texture(scree_r, suv2).rgb, sc_m);
			sn = (texture(scree_n, suv1).rg * 2.0 - 1.0) * mix(0.72, 0.38, lod_far) + (texture(scree_n, suv2).rg * 2.0 - 1.0) * 0.42;
		}

		float h_diff = (sr.b + scree_raw * 1.15) - (c_rm.b + (1.0 - scree_raw) * 0.95);
		float scree_m = max(smoothstep(-0.18, 0.22, h_diff) * scree_raw, smoothstep(0.62, 0.94, foot_scree));

		vec3 s_col = sa * scree_tint * mix(0.86, 1.12, n_mid);
		float moss_m = moss_amt * smoothstep(0.68, 0.92, slope_up) * smoothstep(0.36, 0.76, n_mac * 0.60 + n_mid * 0.40) * smoothstep(1.1, 3.6, wp.y) * (1.0 - smoothstep(13.5, 22.0, wp.y));
		s_col = mix(s_col, moss_col * mix(0.76, 1.24, sa.r), moss_m);

		col = mix(col, s_col, scree_m);
		n_pert = mix(n_pert, vec3(sn.x, 0.0, sn.y), scree_m * 0.85);
		rough = mix(rough, sr.r, scree_m);
		cav_ao = mix(cav_ao, sr.g, scree_m);
	}

	// 陡缓过渡台地植被苔藓斑块，衔接山麓针阔混交林色阶
	float ledge_moss = moss_amt * 0.68 * smoothstep(0.58, 0.84, slope_up) * smoothstep(0.46, 0.80, n_mac * 0.55 + n_crag * 0.45) * smoothstep(1.6, 4.5, wp.y) * (1.0 - smoothstep(15.0, 23.0, wp.y));
	col = mix(col, moss_col * mix(0.82, 1.16, n_mid), ledge_moss * (1.0 - ridge_hi * 0.65));

	// ---- 3. 坡脚法线平滑归平，与地面/冲积扇碎石裙边接缝零光照折痕
	float foot_flat = 1.0 - smoothstep(0.0, 1.10, wp.y);
	vec3 N_base = normalize(mix(N, vec3(0.0, 1.0, 0.0), foot_flat * 0.72));
	n_pert -= N_base * dot(n_pert, N_base);
	vec3 w_nrm = normalize(N_base + n_pert * normal_str * mix(1.0, 0.72, foot_flat));

	float ao_v = clamp(vcol.r, 0.38, 1.0);
	col *= mix(0.48, 1.05, ao_v);

	float wet = clamp(weather_wet, 0.0, 1.0);
	col *= mix(1.0, 0.76, wet * (0.45 + 0.55 * slope_up));

	NORMAL = normalize((VIEW_MATRIX * vec4(w_nrm, 0.0)).xyz);
	ALBEDO = col;
	float wet_r_drop = wet * (0.09 + 0.05 * slope_up);
	ROUGHNESS = clamp(rough - wet_r_drop, mix(0.42, 0.64, wet), 0.97);
	SPECULAR = mix(0.26, 0.34, wet * 0.65 + (1.0 - slope_up) * 0.10);
	AO = clamp(ao_v * mix(0.55, 1.0, cav_ao), 0.32, 1.0);
	AO_LIGHT_AFFECT = 0.45;
}
