shader_type sky;
// 战区全向 360 度天空盒着色器：
// 等距柱状球面连续导数采样消除方位角接缝，支持双层视差立体流云、向阳银边散射、
// 360 度远景层峦与工业废墟天际线剪影、沙暴浑浊沙幕及地下深渊生物发光岩穹。
render_mode use_debanding;

uniform sampler2D cloud_pano : filter_linear_mipmap, repeat_enable;
uniform sampler2D horizon_pano : filter_linear_mipmap, repeat_enable;

uniform vec3 sky_top : source_color = vec3(0.45, 0.45, 0.42);
uniform vec3 sky_horizon : source_color = vec3(0.68, 0.64, 0.56);
uniform vec3 sky_ground : source_color = vec3(0.42, 0.40, 0.34);
uniform vec3 sky_bottom : source_color = vec3(0.10, 0.08, 0.09);
uniform vec4 cloud_tint : source_color = vec4(0.95, 0.92, 0.86, 0.56);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.91, 0.78);
uniform vec3 fog_tint : source_color = vec3(0.52, 0.50, 0.44);

uniform float cloud_drift = 0.0026;
uniform float urban_horizon = 0.55;
uniform float ocean_east_mask = 0.0;
uniform float storm_amount = 0.0;
uniform float cavern_mode = 0.0;

vec3 sample_pano(sampler2D tex, vec3 d, float u_shift) {
	float u_raw = atan(d.z, d.x) * 0.159154943 + 0.5 + u_shift;
	float u1 = fract(u_raw);
	float u2 = fract(u_raw + 0.5);
	float v = clamp(acos(clamp(d.y, -1.0, 1.0)) * 0.318309886, 0.0015, 0.9985);
	vec2 dx1 = dFdx(vec2(u1, v));
	vec2 dy1 = dFdy(vec2(u1, v));
	vec2 dx2 = dFdx(vec2(u2, v));
	vec2 dy2 = dFdy(vec2(u2, v));
	bool pick1 = (dot(dx1, dx1) + dot(dy1, dy1)) <= (dot(dx2, dx2) + dot(dy2, dy2));
	return textureGrad(tex, vec2(u1, v), pick1 ? dx1 : dx2, pick1 ? dy1 : dy2).rgb;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 L = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(0.45, 0.62, 0.64));
	float sd = max(dot(d, L), 0.0);
	float y = d.y;

	if (AT_CUBEMAP_PASS) {
		if (cavern_mode > 0.5) {
			vec3 c_up = mix(sky_horizon, sky_top, smoothstep(0.0, 0.75, max(y, 0.0))) * 1.18;
			vec3 c_dn = mix(sky_ground, sky_bottom, smoothstep(0.0, 0.85, max(-y, 0.0))) * 1.05;
			COLOR = mix(c_dn, c_up, smoothstep(-0.08, 0.08, y));
		} else {
			// 废土电影级天光 IBL：适度增强天空半球辐射度点亮玻璃/金属反光，同时压稳地面反弹保持厚重战后阴影体积感
			float yy = clamp(y, 0.0, 1.0);
			vec2 d_xz_c = length(d.xz) > 1e-4 ? normalize(d.xz) : vec2(0.0, 1.0);
			vec2 l_xz_c = length(L.xz) > 1e-4 ? normalize(L.xz) : vec2(0.0, 1.0);
			float az_c = max(dot(d_xz_c, l_xz_c), 0.0);
			vec3 hz_cool = sky_horizon * vec3(0.92, 0.96, 1.04);
			vec3 hz_warm = mix(sky_horizon, sun_tint, 0.34) * 1.08;
			vec3 hz_dir = mix(hz_cool, hz_warm, pow(az_c, 2.0) * (1.0 - storm_amount * 0.65));
			vec3 hz_haze_c = mix(fog_tint, hz_dir, 0.60);
			vec3 up_c = mix(hz_haze_c, mix(hz_dir, sky_top, 0.56), smoothstep(0.0, 0.24, yy));
			up_c = mix(up_c, sky_top * 1.04, smoothstep(0.18, 0.82, yy));
			up_c *= 1.04;
			up_c += sun_tint * (pow(sd, 5.0) * 0.30 + pow(sd, 32.0) * 0.85) * (1.0 - storm_amount * 0.65);
			vec3 bounce_lo = max(sky_ground * 0.62, sky_bottom * 1.15 + sky_ground * 0.24);
			vec3 dn_c = mix(hz_haze_c * 0.94, mix(sky_ground * 0.78, bounce_lo, smoothstep(0.08, 0.78, clamp(-y, 0.0, 1.0))), smoothstep(0.02, 0.22, clamp(-y, 0.0, 1.0)));
			vec3 env_c = mix(dn_c, up_c, smoothstep(-0.05, 0.05, y));
			env_c = mix(env_c, fog_tint * 1.12, storm_amount * 0.50);
			COLOR = min(env_c, vec3(6.5));
		}
	} else if (cavern_mode > 0.5) {
		// 地下深渊封闭岩穹：深邃火山岩穹渐变 + 柔和体积孢子雾带（消除刺眼漂浮紫色细丝虫纹）
		vec3 cl = sample_pano(cloud_pano, d, TIME * cloud_drift * 0.32);
		vec3 cl2 = sample_pano(cloud_pano, normalize(vec3(-d.z, d.y * 0.88, d.x)), -TIME * cloud_drift * 0.22 + 0.37);

		float elev = clamp(y, 0.0, 1.0);
		float pulse = 0.88 + 0.12 * sin(TIME * 0.95 + d.x * 2.5 + d.z * 2.0);

		// 深沉玄武岩穹主基调：低空泛深紫灰地热薄霭，高穹沉入近黑火山岩顶
		vec3 dome_low = mix(fog_tint, sky_horizon, 0.55) * 0.92;
		vec3 dome_mid = mix(sky_top * 0.88, sky_horizon * 0.62, smoothstep(0.18, 0.82, cl.r * 0.55 + cl2.r * 0.45));
		vec3 dome_top = sky_bottom * 0.68;
		vec3 col = mix(dome_low, dome_mid, smoothstep(0.0, 0.34, elev));
		col = mix(col, dome_top, smoothstep(0.28, 0.90, elev));

		// 柔和体积孢子薄霭与远端暗紫生物微光漫射（无硬边亮线）
		float mist_band = smoothstep(0.32, 0.86, cl.g * 0.58 + cl2.g * 0.42);
		float arch_fade = smoothstep(0.02, 0.32, elev) * (1.0 - smoothstep(0.45, 0.92, elev));
		vec3 bio_mist = mix(vec3(0.20, 0.12, 0.36), vec3(0.14, 0.24, 0.42), cl2.b);
		col = mix(col, col + bio_mist * 0.34 * pulse, mist_band * arch_fade * clamp(cloud_tint.a, 0.25, 0.85));

		// 水平面深渊雾气收束，与火山口黑曜岩环壁无痕衔接
		float rim_fog = exp(-abs(y) * 8.0);
		col = mix(col, mix(fog_tint, sky_horizon, 0.42), rim_fog * 0.72);
		if (y < 0.0) {
			col = mix(col, sky_bottom, smoothstep(0.0, 0.58, -y));
		}
		COLOR = col;
	} else {
		// 地表战区 360 度天空盒：方位角向阳暖霞与背光冷蓝灰分级过渡
		float yy = clamp(y, 0.0, 1.0);
		vec2 d_xz = length(d.xz) > 1e-4 ? normalize(d.xz) : vec2(0.0, 1.0);
		vec2 l_xz = length(L.xz) > 1e-4 ? normalize(L.xz) : vec2(0.0, 1.0);
		float az_raw = max(dot(d_xz, l_xz), 0.0);
		float az_sun = pow(az_raw, 2.6);
		float clear_sun = 1.0 - storm_amount * 0.72;
		vec3 hz_away = sky_horizon * vec3(0.91, 0.96, 1.05);
		vec3 hz_sun = mix(sky_horizon, sun_tint, 0.36) * 1.10;
		vec3 hz_base = mix(hz_away, hz_sun, pow(az_raw, 1.8) * clear_sun);
		vec3 mid_col = mix(hz_base, sky_top, 0.54);
		vec3 col = mix(hz_base, mid_col, smoothstep(0.0, 0.20, yy));
		col = mix(col, sky_top, smoothstep(0.14, 0.84, yy));

		// 向阳低空破云辉光与多瓣米氏散射日冕
		col += sun_tint * az_sun * 0.26 * exp(-yy * 5.6) * clear_sun;
		col += sun_tint * (pow(sd, 3.5) * 0.10 + pow(sd, 9.0) * 0.22 + pow(sd, 52.0) * 0.46) * clear_sun;

		// 双层视差流动全景云系 + 向阳偏移采样计算体积自阴影
		float t_u1 = TIME * cloud_drift;
		vec3 cp1 = sample_pano(cloud_pano, d, t_u1);
		vec3 cp2 = sample_pano(cloud_pano, d, -TIME * cloud_drift * 0.42 + 0.37);
		vec3 d_sun = normalize(d + L * 0.046);
		vec3 cp_sun = sample_pano(cloud_pano, d_sun, t_u1);

		float cov_ctrl = clamp(cloud_tint.a, 0.15, 0.95);
		float dens_main = smoothstep(0.58 - cov_ctrl * 0.42, 0.96 - cov_ctrl * 0.22, cp1.r);
		float dens_sun = smoothstep(0.58 - cov_ctrl * 0.42, 0.96 - cov_ctrl * 0.22, cp_sun.r);
		float dens_high = smoothstep(0.62 - cov_ctrl * 0.36, 0.95, cp2.g) * 0.62;
		float cloud_mask = clamp(dens_main + dens_high * (1.0 - dens_main * 0.65), 0.0, 1.0);
		cloud_mask *= smoothstep(-0.015, 0.075, y);

		// 云体体积明暗：向阳密度梯度浮雕 + 厚重石板蓝暗腹 + 破云暖金透射银边
		float sun_grad = clamp(0.52 + (dens_main - dens_sun) * 1.95, 0.0, 1.0);
		float storm_belly = smoothstep(0.60, 0.78, cov_ctrl);
		float relief = clamp(cp1.b * 0.50 + cp2.b * 0.16 + sun_grad * 0.46 - dens_main * (0.20 + storm_belly * 0.12), 0.0, 1.0);
		vec3 c_belly = mix(sky_top * 0.42 + fog_tint * 0.26, cloud_tint.rgb * 0.38, 0.40) * vec3(0.90, 0.95, 1.06);
		vec3 c_lit = mix(cloud_tint.rgb * 1.08, sun_tint * 1.16, 0.26 + az_sun * 0.30);
		vec3 cloud_col = mix(c_belly, c_lit, smoothstep(0.18, 0.82, relief));
		float thin_edge = (1.0 - dens_main * 0.68) * smoothstep(0.04, 0.45, cloud_mask);
		float silver = (pow(sd, 4.5) * 0.48 + pow(sd, 16.0) * 0.62) * thin_edge * clear_sun;
		cloud_col += mix(cloud_tint.rgb, sun_tint, 0.72) * silver;
		// 地平线远处云层融入方向性大气雾色
		vec3 hz_fog = mix(fog_tint, hz_base, 0.38);
		cloud_col = mix(hz_fog, cloud_col, smoothstep(0.01, 0.22, max(y, 0.0)));
		col = mix(col, cloud_col, cloud_mask * clamp(cov_ctrl * 1.18, 0.0, 0.95));

		// 太阳盘（被云层光学厚度与沙暴自然遮蔽）
		if (y > -0.01 && LIGHT0_ENABLED) {
			float sun_vis = (1.0 - cloud_mask * 0.86) * (1.0 - storm_amount * 0.88);
			float disc = smoothstep(0.99945, 0.99982, dot(d, L));
			col += sun_tint * disc * 9.5 * sun_vis;
		}

		// 下半球远地面渐变（与 AT_CUBEMAP_PASS 地平线大气色严格一致，消除远距地表/海水与天空盒接缝）
		vec3 hz_haze = mix(fog_tint, hz_base, 0.56);
		if (y < 0.03) {
			float dn = clamp(-y, 0.0, 1.0);
			vec3 g_col = mix(sky_ground, sky_bottom, smoothstep(0.04, 0.70, dn));
			float g_haze = exp(-dn * 9.5);
			g_col = mix(g_col, hz_haze, clamp(g_haze * 0.94, 0.0, 1.0));
			col = mix(g_col, col, smoothstep(-0.024, 0.022, y));
		}

		// 东湾开阔海面方位角遮罩（+X 为东）：在东湾船坞港/铁锈工业带海面向东淡出静态烘培山脊与工业剪影
		float east_open = smoothstep(-0.15, 0.35, d.x) * clamp(ocean_east_mask, 0.0, 1.0);
		float sil_mask = 1.0 - east_open;

		// 360 度远景山脊与废土工业天际线剪影（脚部随地平线薄霭柔化，避免水平硬线）
		vec3 hz = sample_pano(horizon_pano, d, 0.0);
		float foot_soft = smoothstep(-0.012, 0.018, y);
		float far_ridge = hz.r * sil_mask * foot_soft * (1.0 - smoothstep(0.08, 0.16, y));
		if (far_ridge > 0.002) {
			vec3 ridge_col = mix(sky_ground * 0.56, mix(fog_tint, sky_horizon, 0.55), 0.72);
			ridge_col += sun_tint * az_sun * 0.14 * clear_sun;
			col = mix(col, ridge_col, clamp(far_ridge * 1.12, 0.0, 0.84) * (1.0 - storm_amount * 0.6));
		}
		float ind_sil = hz.g * urban_horizon * sil_mask * foot_soft * (1.0 - smoothstep(0.07, 0.14, y));
		if (ind_sil > 0.002) {
			vec3 ind_col = mix(sky_bottom * 1.35 + sky_ground * 0.35, fog_tint, 0.58);
			col = mix(col, ind_col, clamp(ind_sil * 1.20, 0.0, 0.78) * (1.0 - storm_amount * 0.7));
		}

		// 地平线柔和大气雾带（y ∈ [-0.04, 0.14] 无缝承接 FOG_MODE_DEPTH 空气透视与东湾水天一线）
		float hz_up = exp(-max(y, 0.0) * 14.5) * smoothstep(0.16, 0.0, y);
		float hz_dn = exp(-max(-y, 0.0) * 26.0);
		float hz_band = (y >= 0.0 ? hz_up : hz_dn) * smoothstep(-0.06, -0.01, y);
		col = mix(col, hz_haze, clamp(hz_band * (0.58 + east_open * 0.16), 0.0, 0.84));
		if (storm_amount > 0.001) {
			float dust_wall = smoothstep(0.68, -0.08, y) * storm_amount;
			vec3 storm_col = mix(fog_tint, sky_horizon * 0.92, 0.35 + 0.15 * cp1.g);
			col = mix(col, storm_col, clamp(dust_wall * 0.88, 0.0, 0.92));
		}

		COLOR = col;
	}
}
