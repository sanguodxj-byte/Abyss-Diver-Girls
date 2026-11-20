shader_type spatial;
// 写实重工业建筑窗格与采光天窗着色器：
// 带暗钢窗框与十字窗棂立体凹凸、灰尘雨痕斑驳、室内纵深梁架剪影、天空菲涅尔高光反射，以及克制的暖钠灯/工作灯内透。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, ensure_correct_normals;

uniform vec4 glass_tint : source_color = vec4(0.11, 0.14, 0.17, 1.0);
uniform vec4 frame_color : source_color = vec4(0.14, 0.145, 0.15, 1.0);
uniform vec4 lit_color : source_color = vec4(0.92, 0.68, 0.36, 1.0);
uniform float mullion_u = 1.05;     // 横向分格间距（米）
uniform float mullion_v = 1.25;     // 竖向分格间距（米）
uniform float frame_width = 0.045;  // 钢窗棂半宽（米）
uniform float lit_chance : hint_range(0.0, 1.0) = 0.12;
uniform float emit_strength : hint_range(0.0, 3.0) = 0.45;
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.42;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
global uniform float weather_wet;
global uniform vec3 sun_dir_world;
#include "res://shaders/occ_fade.gdshaderinc"

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;
varying vec3 wnrm;
varying vec3 box_half;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	vec3 sx = MODEL_MATRIX[0].xyz;
	vec3 sy = MODEL_MATRIX[1].xyz;
	vec3 sz = MODEL_MATRIX[2].xyz;
	vec3 scale = max(vec3(length(sx), length(sy), length(sz)), vec3(1e-3));
	mat3 rot_m = mat3(sx / scale.x, sy / scale.y, sz / scale.z);
	if (dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.01 && CUSTOM0.w > 0.5) {
		lpos = vec3(UV.x, UV.y, UV2.x);
		lnrm = normalize(CUSTOM0.xyz);
		box_half = vec3(max(UV2.y, 0.25), 999.0, max(UV2.y, 0.25));
	} else {
		lpos = VERTEX * scale;
		lnrm = normalize(NORMAL / scale);
		box_half = scale * 0.5;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(rot_m * lnrm);
	vec3 n_m = normalize(NORMAL);
	vec3 ref_t = abs(n_m.y) > 0.85 ? vec3(1.0, 0.0, 0.0) : normalize(vec3(-n_m.z, 0.0, n_m.x));
	TANGENT = normalize(ref_t - n_m * dot(ref_t, n_m));
	BINORMAL = cross(n_m, TANGENT);
}

void fragment() {
	float occ_fade = 0.0;
	if (occ_clip_whole_bldg(wpos, INV_VIEW_MATRIX[3].xyz)) {
		discard;
	}
	if (occ_params.x > 0.005) {
		occ_fade = occ_calc_fade(wpos, INV_VIEW_MATRIX[3].xyz, occ_params.x, 0.40);
		if (occ_fade > 0.005 && occ_ign(FRAGCOORD.xy) < clamp(occ_fade * 1.06, 0.0, 1.0)) {
			discard;
		}
	}
	vec3 an = abs(normalize(lnrm));
	vec2 p2;
	vec2 b_ext;
	if (an.x >= an.y && an.x >= an.z) {
		p2 = vec2(lpos.z, lpos.y);
		b_ext = vec2(box_half.z, box_half.y);
	} else if (an.y >= an.z) {
		p2 = vec2(lpos.x, lpos.z);
		b_ext = vec2(box_half.x, box_half.z);
	} else {
		p2 = vec2(lpos.x, lpos.y);
		b_ext = vec2(box_half.x, box_half.y);
	}

	// 钢制外窗框（当使用未合并网格时精确贴合窗洞外沿）+ 内部周期钢窗棂分格
	vec2 pitch = max(vec2(mullion_u, mullion_v), vec2(0.25));
	vec2 g = p2 / pitch + vec2(0.5);
	vec2 cell = floor(g);
	vec2 fg = fract(g) - 0.5;
	vec2 dist_m = (0.5 - abs(fg)) * pitch;
	if (b_ext.y < 500.0) {
		vec2 dist_outer = max(b_ext - abs(p2), vec2(0.0));
		dist_m = min(dist_m, dist_outer * 0.85);
	}

	float fw = max(length(fwidth(p2)), 1e-4);
	float mx = 1.0 - smoothstep(frame_width, frame_width + fw * 1.5, dist_m.x);
	float my = 1.0 - smoothstep(frame_width, frame_width + fw * 1.5, dist_m.y);
	// 细横撑压条（工业钢窗特有的双层水平副格）
	float sub_y = abs(fract(g.y * 2.0) - 0.5) * (pitch.y * 0.5);
	float m_sub = (1.0 - smoothstep(frame_width * 0.48, frame_width * 0.48 + fw * 1.5, sub_y)) * 0.85;
	float fade = clamp(1.0 - fw * 5.5, 0.15, 1.0);
	float frame = clamp(max(max(mx, my), m_sub) * fade, 0.0, 1.0);
	float pane_ao = (1.0 - smoothstep(frame_width, frame_width + 0.08, min(dist_m.x, dist_m.y))) * (1.0 - frame);

	// 污垢、雨水流痕与灰尘边角积聚（偏置世界格点坐标，避免落在整米边界的窗面产生栅格闪烁）
	vec3 wp_g = wpos + vec3(0.0173, 0.0131, 0.0197);
	float n_lo = texture(noise_tex, p2 * 0.18 + floor(wp_g.xz * 0.25) * 0.17).r;
	float n_streak = texture(noise_tex, vec2(p2.x * 1.6, p2.y * 0.22) + wpos.xz * 0.05).r;
	float grime = clamp((pane_ao * 0.65 + (1.0 - n_lo) * 0.45 + smoothstep(0.55, 0.88, n_streak) * 0.35) * dirt_amount, 0.0, 0.85);

	// 视差伪室内结构层（混凝土楼板暗影、钢桁架斜撑与工业百叶剪影）
	vec3 v_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec2 para = p2 - v_world.xz * 0.38 - vec2(0.0, v_world.y * 0.28);
	float room_hash = hash21(cell + floor(wp_g.xz * 0.5 + wp_g.y * 0.37));
	float blinds = smoothstep(0.35, 0.65, sin(para.y * 26.0 + room_hash * 6.0) * 0.5 + 0.5);
	float has_blinds = step(0.58, room_hash) * (1.0 - smoothstep(0.0, 0.5, fract(g.y) - 0.35 - fract(room_hash * 7.3) * 0.4));
	float interior_beam = smoothstep(0.38, 0.48, abs(fract(para.x * 0.42 + para.y * 0.18) - 0.5));
	vec3 interior_col = glass_tint.rgb * (0.42 + 0.32 * interior_beam) * mix(1.0, 0.65 + 0.35 * blinds, has_blinds * 0.6);

	// 方向性天际/地面反射与雨天玻璃水痕
	float wet_g = clamp(weather_wet, 0.0, 1.0);
	float rain_riv = wet_g * smoothstep(0.56, 0.86, texture(noise_tex, vec2(p2.x * 3.1, p2.y * 0.28) + wp_g.xz * 0.07).r) * (1.0 - frame);
	float eff_grime = grime * (1.0 - wet_g * 0.35);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = 0.06 + 0.94 * pow(1.0 - ndv, 4.0);
	vec3 eye_dir = normalize(wpos - INV_VIEW_MATRIX[3].xyz);
	vec3 w_nrm = normalize(wnrm);
	vec3 refl = reflect(eye_dir, normalize(w_nrm + vec3(0.0, rain_riv * 0.06, 0.0)));
	vec3 sun_d = length(sun_dir_world) > 1e-3 ? normalize(sun_dir_world) : normalize(vec3(0.45, 0.62, 0.64));
	float r_sun = max(dot(refl, sun_d), 0.0);
	vec3 refl_up = mix(vec3(0.36, 0.41, 0.46), vec3(0.18, 0.24, 0.31), smoothstep(0.0, 0.68, max(refl.y, 0.0)));
	refl_up += vec3(0.88, 0.78, 0.64) * (pow(r_sun, 5.0) * 0.24 + pow(r_sun, 28.0) * 0.42);
	vec3 refl_dn = vec3(0.07, 0.08, 0.095) * (0.75 + 0.50 * wet_g);
	float sky_vis = smoothstep(-0.06, 0.14 + (n_lo - 0.5) * 0.10, refl.y);
	vec3 sky_tint = mix(refl_dn, refl_up, sky_vis) * (0.68 + 0.32 * n_lo);
	vec3 glass_col = mix(interior_col, sky_tint, clamp(fres * (1.0 - eff_grime * 0.58) * (0.76 + wet_g * 0.18), 0.0, 0.92));
	glass_col = mix(glass_col, vec3(0.24, 0.22, 0.19), eff_grime * 0.44);
	glass_col *= 1.0 - pane_ao * 0.35;

	// 稀疏暖色工业室内工作灯（按窗格组随机亮起，柔和朦胧不刺眼，彻底告别纯色发光块）
	float bay_hash = hash21(floor(cell * vec2(0.5, 1.0)) + floor(wp_g.xz * 0.22 + wp_g.y * 0.31));
	float is_lit = step(1.0 - lit_chance, bay_hash) * (1.0 - frame);
	float lamp_falloff = (0.55 + 0.45 * smoothstep(0.0, 0.7, 1.0 - abs(fg.x) * 1.4)) * (0.65 + 0.35 * n_lo) * (1.0 - eff_grime * 0.42);
	vec3 lit_glow = lit_color.rgb * is_lit * emit_strength * lamp_falloff * mix(1.0, 0.45 + 0.55 * blinds, has_blinds * 0.7);
	glass_col = mix(glass_col, lit_color.rgb * 0.42, is_lit * 0.45 * lamp_falloff);

	vec3 frame_c = frame_color.rgb * (0.82 + 0.30 * n_lo) * (1.0 - wet_g * 0.12);
	ALBEDO = mix(glass_col, frame_c, frame);
	METALLIC = mix(0.18, 0.58, frame);
	float pane_rough = clamp(0.07 + eff_grime * 0.54 - rain_riv * 0.18 - wet_g * 0.03, 0.045, 0.76);
	ROUGHNESS = mix(pane_rough, mix(0.68, 0.42, wet_g), frame);
	SPECULAR = mix(0.90, 0.48, frame);
	CLEARCOAT = (1.0 - frame) * clamp((1.0 - eff_grime * 0.70) * 0.84 + rain_riv * 0.25, 0.0, 1.0);
	CLEARCOAT_ROUGHNESS = clamp(0.10 + eff_grime * 0.22 - rain_riv * 0.06, 0.04, 0.45);
	EMISSION = lit_glow;
	AO = clamp(1.0 - pane_ao * 0.45 - frame * 0.12, 0.35, 1.0);
	AO_LIGHT_AFFECT = 0.55;

	// 窗棂侧面微斜面法线 + 玻璃雨道横向微折光
	float riv_dx = (texture(noise_tex, vec2(p2.x * 3.1 + 0.02, p2.y * 0.28) + wp_g.xz * 0.07).r - 0.5) * rain_riv * 0.22;
	vec2 fn = vec2(mx * sign(fg.x) * 0.35 + riv_dx, my * sign(fg.y) * 0.35) * fade;
	NORMAL_MAP = vec3(clamp(0.5 + fn.x, 0.1, 0.9), clamp(0.5 + fn.y, 0.1, 0.9), 1.0);
	if (occ_fade > 0.01) {
		ALBEDO = occ_soft_mist(ALBEDO, occ_fade);
		EMISSION *= 1.0 - occ_fade * 0.85;
		CLEARCOAT *= 1.0 - occ_fade * 0.85;
		SPECULAR *= 1.0 - occ_fade * 0.72;
	}
}
