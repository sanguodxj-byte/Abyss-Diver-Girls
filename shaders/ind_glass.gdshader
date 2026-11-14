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

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;
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
	vec3 scale = max(vec3(length(sx), length(sy), length(sz)), vec3(1e-4));
	mat3 rot_m = mat3(sx / scale.x, sy / scale.y, sz / scale.z);
	if (CUSTOM0.w > 0.5) {
		lpos = vec3(UV.x, UV.y, UV2.x);
		lnrm = normalize(CUSTOM0.xyz);
		box_half = vec3(max(UV2.y, 0.25), 999.0, max(UV2.y, 0.25));
	} else {
		lpos = VERTEX * scale;
		lnrm = normalize(NORMAL / scale);
		box_half = scale * 0.5;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n_m = normalize(NORMAL);
	vec3 ref_t = abs(n_m.y) > 0.85 ? vec3(1.0, 0.0, 0.0) : normalize(vec3(-n_m.z, 0.0, n_m.x));
	TANGENT = normalize(ref_t - n_m * dot(ref_t, n_m));
	BINORMAL = cross(n_m, TANGENT);
}

void fragment() {
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

	// 菲涅尔冷灰天空反射感 + 污渍哑光压制
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 4.0);
	vec3 sky_tint = vec3(0.24, 0.29, 0.34) * (0.55 + 0.45 * n_lo);
	vec3 glass_col = mix(interior_col, sky_tint, fres * (1.0 - grime * 0.65) * 0.68);
	glass_col = mix(glass_col, vec3(0.24, 0.22, 0.19), grime * 0.48);
	glass_col *= 1.0 - pane_ao * 0.35;

	// 稀疏暖色工业室内工作灯（按窗格组随机亮起，柔和朦胧不刺眼，彻底告别纯色发光块）
	float bay_hash = hash21(floor(cell * vec2(0.5, 1.0)) + floor(wp_g.xz * 0.22 + wp_g.y * 0.31));
	float is_lit = step(1.0 - lit_chance, bay_hash) * (1.0 - frame);
	float lamp_falloff = (0.55 + 0.45 * smoothstep(0.0, 0.7, 1.0 - abs(fg.x) * 1.4)) * (0.65 + 0.35 * n_lo) * (1.0 - grime * 0.45);
	vec3 lit_glow = lit_color.rgb * is_lit * emit_strength * lamp_falloff * mix(1.0, 0.45 + 0.55 * blinds, has_blinds * 0.7);
	glass_col = mix(glass_col, lit_color.rgb * 0.42, is_lit * 0.45 * lamp_falloff);

	vec3 frame_c = frame_color.rgb * (0.82 + 0.30 * n_lo);
	ALBEDO = mix(glass_col, frame_c, frame);
	METALLIC = mix(0.18, 0.58, frame);
	ROUGHNESS = mix(clamp(0.09 + grime * 0.58, 0.08, 0.78), 0.68, frame);
	SPECULAR = mix(0.88, 0.45, frame);
	CLEARCOAT = (1.0 - frame) * (1.0 - grime * 0.75) * 0.82;
	CLEARCOAT_ROUGHNESS = 0.12 + grime * 0.25;
	EMISSION = lit_glow;
	AO = clamp(1.0 - pane_ao * 0.45 - frame * 0.12, 0.35, 1.0);
	AO_LIGHT_AFFECT = 0.55;

	// 窗棂侧面微斜面法线
	vec2 fn = vec2(mx * sign(fg.x), my * sign(fg.y)) * fade * 0.35;
	NORMAL_MAP = vec3(clamp(0.5 + fn.x, 0.1, 0.9), clamp(0.5 + fn.y, 0.1, 0.9), 1.0);
}
