shader_type spatial;
// 写实工业与机甲 PBR 着色器：支持独立网格 (tint_mode 0)、MultiMesh (tint_mode 1) 与静态分块合并网格 (tint_mode 2)。
// 通过对象局部米制坐标 (lpos/lnrm) 做三平面贴图与法线映射，任意旋转或合并后的建筑墙板、钢梁、屋面纹理均严格对齐不扭曲。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, ensure_correct_normals;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float metal_base : hint_range(0.0, 1.0) = 0.15;
uniform float rough_base : hint_range(0.0, 1.0) = 0.6;
uniform float wear : hint_range(0.0, 1.0) = 0.5;       // 边缘掉漆强度
uniform float scratches : hint_range(0.0, 1.0) = 0.35; // 面上划痕
uniform float dust : hint_range(0.0, 1.0) = 0.3;       // 朝上表面积灰
uniform float grime : hint_range(0.0, 1.0) = 0.5;      // 底部泥污 / 缝隙暗化
uniform float rust : hint_range(0.0, 1.0) = 0.25;      // 锈迹流痕
uniform float panel_scale = 0.0;                        // 平面大墙体拼板接缝密度（0 关闭）
uniform float stripes = 0.0;                            // 1 = 黄黑警示条纹
uniform float detail_scale = 1.0;
uniform int tint_mode = 0;                              // 0 直接底色；1 乘 MultiMesh INSTANCE_CUSTOM；2 乘静态合批网格顶点色 gba（含 CUSTOM0/1）；3 乘合并网格顶点色 gba（无 CUSTOM0/1）
uniform float takes_damage = 0.0;                       // 1 = 随机甲受损程度出现烧蚀/弹痕
uniform float metal_wear : hint_range(0.0, 1.0) = 1.0;  // 1 = 金属底材（掉漆露钢）；0 = 混凝土/砖石
uniform float roof_uv = 0.0;                            // 1 = 朝上斜面按 (z, x) 投影，令屋面锁边顺坡向排布
global uniform float mech_damage;
global uniform float weather_wet;
global uniform float weather_rain;
#include "res://shaders/occ_fade.gdshaderinc"
uniform float occ_exempt = 0.0;
uniform float occ_self_fade = 0.0;
uniform vec4 bare_metal : source_color = vec4(0.66, 0.67, 0.69, 1.0);
uniform vec4 dust_color : source_color = vec4(0.48, 0.43, 0.36, 1.0);
uniform vec4 rust_color : source_color = vec4(0.32, 0.16, 0.08, 1.0);
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_albedo_tex = 0.0;
uniform float albedo_tex_scale = 0.24;
uniform float albedo_tex_strength : hint_range(0.0, 1.0) = 0.78;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.55;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;
varying vec3 wnrm;
varying vec3 rot_x;
varying vec3 rot_y;
varying vec3 rot_z;
varying float edge;
varying vec3 tint;

vec3 q_rot(vec4 q, vec3 v) {
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

vec3 srgb_to_linear(vec3 c) {
	vec3 sc = max(c, vec3(0.0));
	return mix(pow((sc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), sc * (1.0 / 12.92), lessThan(sc, vec3(0.04045)));
}

void vertex() {
	vec3 sx = MODEL_MATRIX[0].xyz;
	vec3 sy = MODEL_MATRIX[1].xyz;
	vec3 sz = MODEL_MATRIX[2].xyz;
	vec3 scale = max(vec3(length(sx), length(sy), length(sz)), vec3(1e-3));
	mat3 rot_m = mat3(sx / scale.x, sy / scale.y, sz / scale.z);
	if (tint_mode == 2 && dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.01 && CUSTOM0.w > 0.5) {
		// 静态分块合并网格：从 UV/UV2/CUSTOM0 读取对象局部米制坐标与法线，从 CUSTOM1 读取局部旋转四元数
		lpos = vec3(UV.x, UV.y, UV2.x);
		lnrm = normalize(CUSTOM0.xyz);
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		wnrm = normalize(rot_m * NORMAL);
		float flip_s = CUSTOM0.w > 1.5 ? -1.0 : 1.0;
		rot_x = rot_m * q_rot(CUSTOM1, vec3(1.0, 0.0, 0.0));
		rot_y = rot_m * q_rot(CUSTOM1, vec3(0.0, 1.0, 0.0));
		rot_z = rot_m * (q_rot(CUSTOM1, vec3(0.0, 0.0, 1.0)) * flip_s);
	} else {
		lpos = VERTEX * scale;
		vec3 n_sc = NORMAL / scale;
		lnrm = length(n_sc) > 1e-4 ? normalize(n_sc) : vec3(0.0, 1.0, 0.0);
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		wnrm = normalize(rot_m * lnrm);
		rot_x = rot_m[0];
		rot_y = rot_m[1];
		rot_z = rot_m[2];
	}
	edge = 1.0 - COLOR.r;
	tint = tint_mode == 1 ? srgb_to_linear(INSTANCE_CUSTOM.rgb) : ((tint_mode == 2 || tint_mode == 3) ? srgb_to_linear(COLOR.gba) : vec3(1.0));
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(max(abs(n), vec3(0.0)), vec3(6.0));
	return w / max(w.x + w.y + w.z, 1e-4);
}

float tri(sampler2D t, vec3 p, vec3 w) {
	float s = 0.0;
	if (w.x > 0.035) s += texture(t, p.zy).r * w.x;
	if (w.y > 0.035) s += texture(t, p.xz).r * w.y;
	if (w.z > 0.035) s += texture(t, p.xy).r * w.z;
	return s;
}

vec2 h22_rip(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 rain_ripple(vec2 p, float t) {
	vec2 slope = vec2(0.0);
	for (int i = 0; i < 2; i++) {
		float sc = i == 0 ? 1.45 : 2.25;
		vec2 gp = p * sc + float(i) * vec2(17.3, 9.1);
		vec2 cell = floor(gp);
		vec2 f = fract(gp) - 0.5;
		vec2 h = h22_rip(cell);
		vec2 dv = f - (h - 0.5) * 0.52;
		float d = length(dv);
		float cyc = fract(t * (0.88 + float(i) * 0.31) + fract(h.x * 7.13 + h.y * 3.71));
		float rad = cyc * 0.44;
		float env = exp(-abs(d - rad) * 34.0) * (1.0 - cyc) * (1.0 - cyc) * smoothstep(0.008, 0.045, d);
		float wv = cos((d - rad) * 68.0) * env;
		slope += (dv / max(d, 1e-3)) * wv;
	}
	return slope * 0.13;
}

void fragment() {
	float occ_fade = 0.0;
	if (occ_self_fade > 0.005) {
		highp vec3 dc_s = INV_VIEW_MATRIX[3].xyz - occ_cam_pos;
		if (dot(dc_s, dc_s) <= 0.25) {
			occ_fade = clamp(occ_self_fade, 0.0, 0.92);
			if (occ_ign(FRAGCOORD.xy) < occ_fade) {
				discard;
			}
		}
	} else if (occ_exempt < 0.5) {
		if (occ_clip_whole_bldg(wpos, INV_VIEW_MATRIX[3].xyz)) {
			discard;
		}
		if (occ_params.x > 0.005) {
			occ_fade = occ_calc_fade(wpos, INV_VIEW_MATRIX[3].xyz, occ_params.x, 0.40);
			if (occ_fade > 0.005 && occ_ign(FRAGCOORD.xy) < clamp(occ_fade * 1.06, 0.0, 1.0)) {
				discard;
			}
		}
	}
	vec3 n_loc = normalize(lnrm);
	vec3 w = tri_w(n_loc);
	vec3 p = lpos * detail_scale;
	float n_lo = tri(noise_lo, p * 0.35 + wpos * 0.02, w);
	float macro_w = texture(noise_lo, wpos.xz * 0.032 + vec2(wpos.y * 0.017 + 1.7, wpos.y * 0.023 + 2.9)).r;
	float n_mid = tri(noise_lo, p * 1.05 + vec3(0.41, 0.17, 0.73), w);
	float n_hi = tri(noise_hi, p * 2.4, w);
	float vert = 1.0 - abs(wnrm.y);
	float n_sc = ((rust > 0.01 && vert > 0.05) || scratches > 0.01) ? tri(noise_hi, p * vec3(9.5, 1.1, 9.5), w) : 0.5;

	// 墙面立面令 -p.y 对应贴图 +v（向下），保证砖缝阴影、波纹板搭接锈水与混凝土孔流痕均严格顺重力朝下
	vec2 uv_x = vec2(p.z, -p.y);
	vec2 uv_y = roof_uv > 0.5 ? vec2(p.z, p.x) : vec2(p.x, p.z);
	vec2 uv_z = vec2(p.x, -p.y);

	// 轧制钢板与重工漆面的低频温润色阶 + 世界空间宏观风化（抑制高频噪点，突出精工大块面质感）
	vec3 base_c = base_color.rgb * tint;
	if (metal_wear > 0.5) {
		vec3 min_m = mix(vec3(0.042, 0.045, 0.052), vec3(0.135, 0.142, 0.155), metal_base);
		base_c = max(base_c, min_m);
		base_c = mix(base_c, sqrt(base_c) * 0.62, metal_base * 0.40);
	}
	vec3 col = base_c * (0.97 + 0.06 * n_lo) * (0.985 + 0.03 * n_hi) * (0.96 + 0.08 * macro_w);
	float tex_luma = 0.7;
		if (use_albedo_tex > 0.5) {
			float ts = albedo_tex_scale * 1.6;
			vec3 at = vec3(0.0);
			if (w.x > 0.035) at += texture(albedo_tex, uv_x * ts).rgb * w.x;
			if (w.y > 0.035) at += texture(albedo_tex, uv_y * ts).rgb * w.y;
			if (w.z > 0.035) at += texture(albedo_tex, uv_z * ts).rgb * w.z;
			tex_luma = dot(at, vec3(0.333));
			// 中性校准：柔和融入贴图微结构，避免远距高频噪点与发脏
			col *= mix(vec3(1.0), at * 1.48, albedo_tex_strength);
		}
	float met = metal_base;
	float rough = rough_base * (0.93 + 0.12 * n_hi - 0.05 * n_mid + (0.66 - tex_luma) * 0.10 * use_albedo_tex);

	// 警示条纹（带做旧磨蚀感）
	if (stripes > 0.5) {
		float s = fract((p.x + p.y + p.z) * 2.2);
		float sw = max(fwidth(s), 1e-4);
		float band = min(smoothstep(0.5 - sw, 0.5 + sw, s), 1.0 - smoothstep(1.0 - sw * 1.5, 1.0, s));
		col = mix(vec3(0.06, 0.06, 0.065), vec3(0.86, 0.60, 0.11), band) * (0.84 + 0.24 * n_lo);
	}

	// 大尺度平直墙板接缝：仅在低曲率正交平面内生效，曲面、圆管与 45 度倒角棱自动平滑归零
	float seam = 0.0;
	float seam_ao = 0.0;
	vec2 seam_n = vec2(0.0);
	if (panel_scale > 0.0) {
		vec3 an_p = abs(n_loc);
		float axis_max = max(an_p.x, max(an_p.y, an_p.z));
		float curv_n = length(fwidth(n_loc));
		float flat_gate = smoothstep(0.88, 0.97, axis_max) * (1.0 - smoothstep(0.004, 0.018, curv_n)) * (1.0 - smoothstep(0.02, 0.16, edge));
		if (flat_gate > 0.005) {
			bool px = an_p.x >= an_p.y && an_p.x >= an_p.z;
			bool py = !px && an_p.y >= an_p.z;
			vec2 uv = px ? uv_x : (py ? uv_y : uv_z);
			vec2 fw_raw = px ? fwidth(uv_x) : (py ? fwidth(uv_y) : fwidth(uv_z));
			vec2 g = uv * panel_scale + vec2(0.13, 0.31);
			float row_id = floor(g.y);
			g.x += mod(row_id, 2.0) * 0.5;
			vec2 fg = fract(g) - 0.5;
			vec2 f = abs(fg);
			vec2 fw = max(fw_raw * panel_scale, vec2(1e-4));
			vec2 dist = 0.5 - f;
			float lw = 0.0045;
			float lx = 1.0 - smoothstep(lw, lw + fw.x * 1.6, dist.x);
			float ly = 1.0 - smoothstep(lw, lw + fw.y * 1.6, dist.y);
			float cell_h = fract(sin(dot(floor(g), vec2(127.1, 311.7))) * 43758.5453);
			float panel_tone = (cell_h - 0.5) * mix(0.04, 0.055, metal_wear) * flat_gate;
			col *= 1.0 + panel_tone;
			float fade = clamp(1.0 - (max(fw.x, fw.y) - 0.015) * 14.0, 0.0, 1.0) * flat_gate;
			seam = max(lx, ly) * fade;
			float halo_x = 1.0 - smoothstep(lw, lw + 0.036, dist.x);
			float halo_y = 1.0 - smoothstep(lw, lw + 0.036, dist.y);
			seam_ao = max(halo_x, halo_y) * fade * (0.42 + 0.50 * n_lo);
			seam_n = vec2(lx * sign(fg.x), ly * sign(fg.y)) * fade * mix(0.18, 0.28, metal_wear);
			float seam_dark = mix(0.18, 0.32, metal_wear);
			float halo_dark = mix(0.05, 0.09, metal_wear);
			col *= 1.0 - seam * seam_dark - seam_ao * halo_dark;
			rough = mix(rough, 0.90, seam);
		}
	}

	// 墙脚潮湿烟灰接地污渍与底盘油泥（写实废土厚重感，彻底摆脱干净塑料块）
	float low = (1.0 - smoothstep(0.0, 1.85, wpos.y)) * (1.0 - smoothstep(0.35, 0.75, abs(wnrm.y)));
	float under = smoothstep(0.25, 0.85, -wnrm.y) * metal_wear;
	col *= mix(vec3(1.0), vec3(0.60, 0.59, 0.57), low * (0.38 + grime * 0.24));
	col *= 1.0 - grime * (0.24 * low * (0.55 + 0.45 * n_lo) + 0.16 * under);
	col = mix(col, dust_color.rgb * 0.62, grime * low * 0.24 * smoothstep(0.38, 0.72, n_lo));

	// 锈迹、雨水烟熏垂向流痕与机械油渍（突出末世废土岁月侵蚀与重工沧桑）
	float streak = (rust > 0.01 && vert > 0.05) ? smoothstep(0.54, 0.86, n_sc) * vert * smoothstep(0.34, 0.72, n_lo) : 0.0;
	if (streak > 0.005) {
		vec3 eff_rust = metal_wear > 0.5 ? rust_color.rgb : (base_c * 0.50 + vec3(0.026, 0.022, 0.018));
		col = mix(col, eff_rust, rust * streak * 0.66);
		rough = mix(rough, 0.94, rust * streak * 0.76);
	}
	if (metal_wear > 0.01 && vert > 0.05 && grime > 0.01) {
		float oil = smoothstep(0.70, 0.94, tri(noise_hi, p * vec3(7.0, 0.65, 7.0) + 0.5, w)) * vert * metal_wear * grime;
		col *= 1.0 - oil * 0.24;
		rough = mix(rough, 0.30, oil * 0.55);
	}

	// 战损刮擦与金属倒角掉漆露底（非卡通描边：仅在金属边缘与磨损处露出真实冷钢反光）
	col *= 1.0 + edge * 0.045 * (1.0 - low * 0.65);
	rough = max(0.18, rough - edge * 0.09);
	float chipn = n_hi * 0.62 + n_mid * 0.42 + n_lo * 0.36;
	float eff_edge = edge * clamp(wear * 1.45, 0.0, 1.0);
	float chip_mask = eff_edge * smoothstep(0.84 - wear * 0.24, 1.02 - wear * 0.24, chipn);
	float scr = smoothstep(0.87, 0.92, n_sc) * scratches * (1.0 - seam) * smoothstep(0.50, 0.74, n_lo);
	float wm = max(chip_mask, scr);
	float worn = smoothstep(0.42, 0.74, wm) * 0.72;
	float primer = clamp(eff_edge * smoothstep(0.74 - wear * 0.20, 0.90 - wear * 0.20, chipn) - worn, 0.0, 1.0) * 0.48;
	vec3 primer_col = base_c * mix(0.76, 0.64, metal_wear);
	col = mix(col, primer_col, primer);
	vec3 exposed_metal = (base_c * 1.18 + vec3(0.055, 0.058, 0.062)) * (0.90 + 0.14 * n_hi);
	vec3 exposed_stone = (base_c * 1.08 + vec3(0.016)) * (0.94 + 0.10 * n_hi);
	col = mix(col, mix(exposed_stone, exposed_metal, metal_wear), worn);
	met = mix(met, mix(met, 0.88, metal_wear), worn);
	float worn_rough = mix(0.90, 0.24 + 0.12 * n_hi, metal_wear);
	rough = mix(rough, 0.78, primer);
	rough = mix(rough, worn_rough, worn);
	rough *= 1.0 - eff_edge * 0.16 * metal_wear;

	// 战损：烧蚀焦黑 + 更多掉漆
	float dmg = clamp(mech_damage * takes_damage, 0.0, 1.0);
	if (dmg > 0.01) {
		float n_sc2 = tri(noise_lo, p * 1.3 + vec3(3.1, 7.7, 1.3), w);
		float bv = n_sc2 + n_hi * 0.15;
		float heat = smoothstep(0.84 - dmg * 0.32, 0.98 - dmg * 0.32, bv);
		float burn = smoothstep(0.93 - dmg * 0.32, 1.03 - dmg * 0.32, bv);
		col = mix(col, col * vec3(0.55, 0.42, 0.32), heat * 0.8);
		col = mix(col, vec3(0.03, 0.028, 0.025), burn * 0.92);
		rough = mix(rough, 0.95, heat);
		met = mix(met, 0.0, heat);
		float hn = tri(noise_hi, p * 7.0 + vec3(5.0), w);
		float hole = smoothstep(0.8 - dmg * 0.06, 0.82 - dmg * 0.06, hn) * step(0.45, n_sc2) * step(0.2, dmg);
		col = mix(col, vec3(0.01), hole);
		rough = mix(rough, 1.0, hole);
	}

	// 积灰：朝上的面仅轻微留灰，雨雾湿润时压制浮尘避免画面发粉
	float wet_g = clamp(weather_wet, 0.0, 1.0);
	float up = smoothstep(0.62, 0.96, wnrm.y);
	float d = up * dust * (1.0 - wet_g * 0.84) * smoothstep(0.58, 0.86, n_lo + n_hi * 0.2);
	col = mix(col, dust_color.rgb, d * 0.28);
	rough = mix(rough, 0.84, d * 0.45);
	met = mix(met, met * 0.55, d * 0.45);

	// 湿润与积水四阶过渡：局部低洼暗色积水、浸润深色水际边缘、潮湿微光晕圈与立面重力雨痕
	// （收紧积水覆盖率并压暗水底漫反射，避免低画质/关闭 SSR 时大片路面退化成灰白塑料斑）
	float puddle = 0.0;
	float soak = 0.0;
	float surf_wet = 0.0;
	vec2 rip_n = vec2(0.0);
	if (wet_g > 0.01) {
		float porous = 1.0 - metal_wear;
		float near_ground = smoothstep(1.65, 0.25, wpos.y);
		float flat_up = smoothstep(0.80, 0.95, wnrm.y) * porous;
		float shelter = 1.0 - smoothstep(-0.08, -0.55, wnrm.y);
		float w_up = clamp(wnrm.y, 0.0, 1.0);
		float rain_str = texture(noise_hi, vec2((wpos.x + wpos.z) * 0.82, wpos.y * 0.14)).r;
		float wall_wash = vert * (0.28 + 0.52 * smoothstep(0.36, 0.78, rain_str) * smoothstep(0.28, 0.74, macro_w));
		float splash_band = (1.0 - smoothstep(0.04, 0.85, wpos.y)) * (0.48 + 0.52 * n_lo);
		surf_wet = wet_g * shelter * clamp(max(max(w_up * 0.72, wall_wash * 0.58), splash_band * 0.78), 0.0, 1.0);

		float damp = 0.0;
		float p_deep = 0.0;
		if (flat_up > 0.01 && near_ground > 0.01) {
			float wb1 = texture(noise_lo, wpos.xz * 0.022 + vec2(0.31, 0.73)).r;
			float wb2 = texture(noise_lo, wpos.xz * 0.055 + vec2(4.17, 1.89)).r;
			float rut_bias = stripes > 0.5 ? -0.06 : clamp(0.28 - dot(base_c, vec3(0.333)), -0.04, 0.06) * 0.30;
			float pf_raw = 0.50 + (wb1 - 0.5) * 0.88 + (wb2 - 0.5) * 0.36;
			float pf = pf_raw + rut_bias - seam * 0.06;
			float p_gate = wet_g * flat_up * near_ground;
			puddle = p_gate * smoothstep(0.745, 0.835, pf);
			p_deep = smoothstep(0.790, 0.895, pf);
			soak = p_gate * smoothstep(0.675, 0.785, pf);
			damp = wet_g * flat_up * smoothstep(0.360, 0.620, pf);
			if (puddle > 0.02 && weather_rain > 0.01) {
				float cam_d = length(wpos - INV_VIEW_MATRIX[3].xyz);
				float rip_fade = (1.0 - smoothstep(14.0, 44.0, cam_d)) * clamp(weather_rain, 0.0, 1.0);
				if (rip_fade > 0.015) {
					rip_n = rain_ripple(wpos.xz, TIME) * puddle * rip_fade;
				}
			}
		}
		float total_damp = max(surf_wet, damp * 0.78);
		float wet_any = clamp(max(total_damp, soak), 0.0, 1.0);
		float col_lum = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 wet_chroma = max(mix(vec3(col_lum), col, 1.0 + 0.08 * wet_any), vec3(0.0));
		col = mix(col, wet_chroma, wet_any);
		// 雨天路面均匀深沉湿润（收敛水际花斑与刺眼高光白边，让沥青/人行道干净统一）
		col *= mix(1.0, mix(0.92, 0.84, porous), total_damp * (1.0 - soak * 0.60));
		col *= mix(1.0, mix(0.90, 0.84, porous), soak);
		vec3 puddle_col = mix(col * 0.78, mix(col * 0.60, vec3(0.018, 0.024, 0.032), 0.32), p_deep);
		col = mix(col, puddle_col, puddle);

		// 抑制金属波纹屋顶的雨湿镜面拉低，同时让湿润沥青/水泥呈现平滑克制的雨水光泽
		rough = mix(rough, min(rough, mix(0.56, 0.48, porous)), total_damp * 0.48);
		rough = mix(rough, 0.34, soak * 0.62);
		rough = mix(rough, mix(0.20, 0.14, p_deep), puddle);
	}

		// 连续三平面法线扰动（在视图空间直接合成 NORMAL，消除合批圆柱/斜坡切线阶跃摩尔伪影）
		float ns = use_albedo_tex > 0.5 ? (albedo_tex_scale * 1.6) : 1.25;
		float uv_fw = max(length(fwidth(uv_x * ns)) * w.x, max(length(fwidth(uv_y * ns)) * w.y, length(fwidth(uv_z * ns)) * w.z));
		float nfade = clamp(1.0 - uv_fw * 2.15, 0.0, 1.0);
		float n_amt = clamp((normal_strength + seam * 0.30 + worn * 0.16) * nfade, 0.0, 1.05) * (1.0 - puddle * 0.90);
		vec3 w_pert = wnrm;
		if (n_amt > 0.005 || seam > 0.005) {
			vec3 nm_x = (n_amt > 0.005 && w.x > 0.035) ? (texture(normal_tex, uv_x * ns).rgb * 2.0 - 1.0) : vec3(0.0);
			vec3 nm_y = (n_amt > 0.005 && w.y > 0.035) ? (texture(normal_tex, uv_y * ns).rgb * 2.0 - 1.0) : vec3(0.0);
			vec3 nm_z = (n_amt > 0.005 && w.z > 0.035) ? (texture(normal_tex, uv_z * ns).rgb * 2.0 - 1.0) : vec3(0.0);
			vec2 tx = nm_x.xy * n_amt + (w.x > 0.5 ? seam_n * (1.0 - puddle * 0.85) : vec2(0.0));
			vec2 ty = nm_y.xy * n_amt + (w.y > 0.5 ? seam_n * (1.0 - puddle * 0.85) : vec2(0.0));
			vec2 tz = nm_z.xy * n_amt + (w.z > 0.5 ? seam_n * (1.0 - puddle * 0.85) : vec2(0.0));
			vec3 p_x = vec3(0.0, tx.y, tx.x);
			vec3 p_y = roof_uv > 0.5 ? vec3(-ty.y, 0.0, ty.x) : vec3(ty.x, 0.0, -ty.y);
			vec3 p_z = vec3(tz.x, tz.y, 0.0);
			vec3 dp_loc = p_x * w.x + p_y * w.y + p_z * w.z;
			dp_loc -= n_loc * dot(dp_loc, n_loc);
			mat3 v_rot = mat3(rot_x, rot_y, rot_z);
			vec3 w_sum = wnrm + v_rot * dp_loc;
			w_pert = length(w_sum) > 1e-4 ? normalize(w_sum) : wnrm;
		}
		if (puddle > 0.01) {
			vec3 w_water = normalize(vec3(rip_n.x, 1.0, rip_n.y));
			w_pert = normalize(mix(w_pert, w_water, puddle * 0.92));
		}
		vec3 v_n = (VIEW_MATRIX * vec4(w_pert, 0.0)).xyz;
		NORMAL = length(v_n) > 1e-4 ? normalize(v_n) : NORMAL;

		ALBEDO = col;
		METALLIC = met;
		vec3 dn = fwidth(NORMAL);
		float var_n = dot(dn, dn) * (1.0 - puddle * 0.82);
		float r2 = max(rough * rough + min(1.2 * var_n, 0.22), 0.0);
		ROUGHNESS = clamp(sqrt(r2), mix(0.10, 0.085, puddle), 1.0);

	float tex_ao = use_albedo_tex > 0.5 ? clamp((0.62 - tex_luma) * 0.48, 0.0, 0.22) : 0.0;
	float base_spec = mix(0.50, 0.86, max(worn, metal_base * 0.6) * metal_wear);
	SPECULAR = mix(base_spec, 0.56, max(puddle * 0.85, soak * 0.30));
	AO = clamp(1.0 - tex_ao * (1.0 - puddle * 0.65) - seam * mix(0.16, 0.44, metal_wear) - seam_ao * mix(0.06, 0.16, metal_wear) - primer * 0.18 - low * grime * 0.28 - under * 0.15, 0.40, 1.0);
	AO_LIGHT_AFFECT = 0.42;
	float dry_coat = (1.0 - worn * 0.7) * (1.0 - d) * (1.0 - rust * streak) * metal_wear * clamp(0.66 - rough_base, 0.0, 0.45) * 0.34;
	float wet_coat = max(puddle * 0.28, max(soak * 0.10, surf_wet * mix(0.04, 0.09, metal_wear)));
	CLEARCOAT = max(dry_coat, wet_coat);
	CLEARCOAT_ROUGHNESS = mix(clamp(0.34 + min(1.5 * var_n, 0.28), 0.24, 1.0), mix(0.28, 0.16, puddle), clamp(puddle * 1.15 + soak * 0.35, 0.0, 1.0));
	if (occ_fade > 0.01) {
		ALBEDO = occ_soft_mist(ALBEDO, occ_fade);
		ROUGHNESS = mix(ROUGHNESS, 0.96, occ_fade * 0.65);
		SPECULAR *= 1.0 - occ_fade * 0.72;
		CLEARCOAT *= 1.0 - occ_fade * 0.85;
	}
}
