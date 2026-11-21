shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_front, depth_test_disabled, shadows_disabled;

// 真正 3D 体积光线步进（Volumetric Raymarching）落地尘浪着色器：
// - 采用 Schneider 体积云减法侵蚀模型（remap(shape, erode, 1)），在连续 3D 环形密度流内雕出蓬松翻涌的立体尘瓣
// - 双步 Beer-Lambert 太阳自阴影 + 粉末散射（Powder Effect），受光脊部温暖立体、背光腹部厚重沉实
// - DEPTH_TEXTURE 精确截断在地面与机甲腿部表面，天然包裹机甲、零贴片感、零多边形尖刺

global uniform vec3 sun_dir_world;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap, repeat_disable;
uniform vec3 box_half = vec3(10.0, 2.2, 10.0);
uniform vec3 dust_lit : source_color = vec3(0.50, 0.48, 0.43);
uniform vec3 dust_shadow : source_color = vec3(0.15, 0.14, 0.13);
uniform vec3 hot_color : source_color = vec3(1.0, 0.56, 0.18);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float radius_start : hint_range(0.2, 6.0) = 0.85;
uniform float radius_end : hint_range(1.5, 14.0) = 6.8;
uniform float max_height : hint_range(0.4, 4.0) = 2.10;
uniform float tube_width : hint_range(0.5, 5.0) = 1.75;
uniform float density_scale : hint_range(0.2, 6.0) = 3.20;
uniform float hot_strength : hint_range(0.0, 2.5) = 0.85;
uniform float seed_off = 0.0;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

// 3 倍频高动态范围 3D 蓬松云噪声（用于雕出清晰的立体尘团与沟壑）
float fbm3_vol(vec3 p) {
	float v = 0.0;
	float a = 0.56;
	float norm = 0.0;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise3(p);
		norm += a;
		p = p * 2.09 + vec3(13.7, 9.3, 17.9);
		a *= 0.48;
	}
	return smoothstep(0.22, 0.78, v / norm);
}

float fbm3_fast(vec3 p) {
	float n = vnoise3(p) * 0.65 + vnoise3(p * 2.08 + vec3(7.1, 11.3, 5.9)) * 0.35;
	return smoothstep(0.22, 0.78, n);
}

float ign(vec2 frag_xy) {
	return fract(52.9829189 * fract(dot(frag_xy, vec2(0.06711056, 0.00583715))));
}

float eval_density(vec3 lp, float p, bool fast) {
	float h = lp.y + box_half.y;
	if (h < 0.0 || h > box_half.y * 2.0) {
		return 0.0;
	}
	float r = length(lp.xz);
	float ease = 1.0 - pow(1.0 - p, 2.5);
	float r_ring = mix(radius_start, radius_end, ease);
	float w_r = tube_width * mix(0.65, 1.55, ease);
	float h_env = sin(clamp(p * 1.15, 0.0, 1.0) * 3.14159265) * 0.46 + (1.0 - p * 0.22) * 0.54;
	float cur_h = max_height * clamp(h_env, 0.36, 1.06);

	if (abs(r - r_ring) > w_r * 2.3 || h > cur_h * 1.9) {
		return 0.0;
	}

	vec2 dir = (r > 1e-4) ? (lp.xz / r) : vec2(1.0, 0.0);

	// 周向不规则喷涌云瓣（让四周扩散距离与高度自然参差不齐）
	float lobe_n = vnoise3(vec3(dir.x * 2.6 + seed_off, p * 0.65 + 2.1, dir.y * 2.6 - seed_off));
	float r_local_ring = r_ring + (lobe_n - 0.5) * w_r * 1.25;
	float h_local = cur_h * (0.78 + 0.48 * lobe_n);

	float dr = (r - r_local_ring) / w_r;
	float y_spine = h_local * 0.42 * smoothstep(-1.10, 0.55, dr);
	float dy = (h - y_spine) / max(h_local * 0.56, 0.22);
	float torus = exp(-(dr * dr * 1.35 + dy * dy * 1.60));

	// 早期贴地内圈尘垫
	float inner_wake = exp(-pow((r - r_ring * 0.58) / (w_r * 1.10), 2.0))
		* exp(-h * 2.3) * 0.42 * (1.0 - smoothstep(0.08, 0.62, p));
	float base_shape = max(torus, inner_wake);

	float box_fade = smoothstep(box_half.y * 2.0, box_half.y * 1.40, h)
		* smoothstep(box_half.x, box_half.x * 0.78, r);
	base_shape *= box_fade;
	if (base_shape < 0.02) {
		return 0.0;
	}

	// 3D 平流卷涌云场 + 域扭曲细节（沿径向翻卷推进）
	vec3 adv_pos = vec3(lp.x, h * 1.10, lp.z) * 0.76
		- vec3(dir.x, 0.30, dir.y) * (p * 2.6)
		+ vec3(seed_off, 0.0, -seed_off * 0.7);
	float cloud = fast ? fbm3_fast(adv_pos) : fbm3_vol(adv_pos);
	float detail = fast ? cloud : fbm3_fast(adv_pos * 2.15 + vec3(cloud * 1.35, -cloud * 0.75, cloud * 1.15));
	float n_carve = clamp(cloud * 0.62 + detail * 0.38, 0.0, 1.0);

	// Schneider 体积云减法雕刻：直接用 3D 噪声挖出真实蓬松尘瓣与镂空涡谷，绝不糊成均匀薄雾
	float fade_in = smoothstep(0.0, 0.07, p);
	float life_rem = 1.0 - smoothstep(0.14, 1.0, p);
	float carve_amt = mix(0.92, 0.52, pow(life_rem, 0.85));
	float d = clamp((base_shape - (1.0 - n_carve) * carve_amt) / max(1.0 - carve_amt * 0.65, 0.25), 0.0, 1.0);
	d = smoothstep(0.0, 0.82, d);

	return d * fade_in * pow(life_rem, 0.68);
}

void fragment() {
	if (progress <= 0.002 || progress >= 0.998) {
		discard;
	}

	mat4 inv_model = inverse(MODEL_MATRIX);
	vec3 ro = (inv_model * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 frag_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 frag_l = (inv_model * vec4(frag_w, 1.0)).xyz;
	vec3 rd = normalize(frag_l - ro);

	vec3 safe_rd = vec3(
		rd.x >= 0.0 ? max(rd.x, 1e-5) : min(rd.x, -1e-5),
		rd.y >= 0.0 ? max(rd.y, 1e-5) : min(rd.y, -1e-5),
		rd.z >= 0.0 ? max(rd.z, 1e-5) : min(rd.z, -1e-5)
	);
	vec3 t0s = (-box_half - ro) / safe_rd;
	vec3 t1s = (box_half - ro) / safe_rd;
	vec3 tmin = min(t0s, t1s);
	vec3 tmax = max(t0s, t1s);
	float t_enter = max(max(tmin.x, max(tmin.y, tmin.z)), 0.0);
	float t_exit = min(tmax.x, min(tmax.y, tmax.z));

	float raw_depth = texture(depth_tex, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth * 2.0 - 1.0);
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
#endif
	vec4 view_scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_scene.xyz /= max(abs(view_scene.w), 1e-5) * sign(view_scene.w);
	float t_scene = length(view_scene.xyz);

	t_exit = min(t_exit, t_scene);
	if (t_exit <= t_enter + 0.02) {
		discard;
	}

	vec3 sun_d = length(sun_dir_world) > 1e-3 ? normalize(sun_dir_world) : normalize(vec3(0.45, 0.62, 0.64));
	vec3 sun_l = normalize((inv_model * vec4(sun_d, 0.0)).xyz);

	const int STEPS = 18;
	float march_len = t_exit - t_enter;
	float step_len = march_len / float(STEPS);
	float jitter = ign(FRAGCOORD.xy);

	vec3 accum_col = vec3(0.0);
	float transmittance = 1.0;
	float hot_env = (1.0 - smoothstep(0.0, 0.28, progress)) * hot_strength;

	for (int i = 0; i < STEPS; i++) {
		float t = t_enter + (float(i) + jitter) * step_len;
		vec3 pos = ro + rd * t;
		float d = eval_density(pos, progress, false);
		if (d > 0.004) {
			float h = pos.y + box_half.y;
			// 双步太阳方向自阴影 + Beer-Lambert 透射（形成鲜明立体云团受光面与沉稳背光底影）
			float d_sun1 = eval_density(pos + sun_l * 0.52, progress, true);
			float d_sun2 = eval_density(pos + sun_l * 1.25, progress, true);
			float od_sun = d_sun1 * 0.55 + d_sun2 * 0.75;
			float beer = exp(-od_sun * 4.2);
			// 粉末散射近似：避免云团核心过暗发死，同时强化外缘立体层次
			float powder = 0.72 + 0.28 * (1.0 - exp(-d * 3.0));
			float sky_lift = smoothstep(0.0, max(max_height * 0.95, 0.5), h);
			float lit_k = clamp(beer * powder * 0.76 + sky_lift * 0.24, 0.0, 1.0);

			vec3 scatter = mix(dust_shadow, dust_lit, lit_k);
			if (hot_env > 0.01) {
				float r_c = length(pos.xz);
				float hot_k = exp(-r_c * r_c * 0.16) * exp(-h * 0.85) * hot_env;
				scatter += hot_color * hot_k;
			}

			float edge_soft = clamp((t_exit - t) / 0.30, 0.0, 1.0);
			float step_a = (1.0 - exp(-d * step_len * density_scale)) * edge_soft;
			accum_col += transmittance * scatter * step_a;
			transmittance *= (1.0 - step_a);
			if (transmittance < 0.025) {
				break;
			}
		}
	}

	float final_a = clamp(1.0 - transmittance, 0.0, 0.90);
	if (final_a <= 0.004) {
		discard;
	}

	ALBEDO = accum_col / final_a;
	ALPHA = final_a;
}
