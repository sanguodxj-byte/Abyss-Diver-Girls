shader_type spatial;
// 写实重工业建筑窗格与采光天窗着色器（纯不透明默认版：无 discard，保留 Early-Z 与纯深度阴影）。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx, ensure_correct_normals;

uniform vec4 glass_tint : source_color = vec4(0.11, 0.14, 0.17, 1.0);
uniform vec4 frame_color : source_color = vec4(0.14, 0.145, 0.15, 1.0);
uniform vec4 lit_color : source_color = vec4(0.92, 0.68, 0.36, 1.0);
uniform float mullion_u = 1.05;
uniform float mullion_v = 1.25;
uniform float frame_width = 0.045;
uniform float lit_chance : hint_range(0.0, 1.0) = 0.12;
uniform float emit_strength : hint_range(0.0, 3.0) = 0.45;
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.42;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
global uniform float weather_wet;
global uniform vec3 sun_dir_world;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;
varying vec3 wnrm;
varying vec3 box_half;
varying flat vec2 inst_seed;

vec3 q_rot(vec4 q, vec3 v) {
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 inst_orig;
	if (dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.01 && abs(CUSTOM0.w) > 0.5) {
		lpos = vec3(UV.x, UV.y, UV2.x);
		lnrm = normalize(CUSTOM0.xyz);
		box_half = vec3(max(UV2.y, 0.25), 999.0, max(UV2.y, 0.25));
		float flip_s = (CUSTOM0.w < 0.0 || CUSTOM0.w > 1.5) ? -1.0 : 1.0;
		vec3 local_rot_p = q_rot(normalize(CUSTOM1), vec3(lpos.x, lpos.y, lpos.z * flip_s));
		inst_orig = (MODEL_MATRIX * vec4(VERTEX - local_rot_p, 1.0)).xyz;
		wnrm = normalize(rot_m * NORMAL);
	} else {
		lpos = VERTEX * scale;
		lnrm = normalize(NORMAL / scale);
		box_half = scale * 0.5;
		inst_orig = MODEL_MATRIX[3].xyz;
		wnrm = normalize(rot_m * lnrm);
	}
	vec3 orig_q = floor(inst_orig * 0.25 + vec3(0.173, 0.131, 0.197));
	inst_seed = orig_q.xz * 0.37 + vec2(orig_q.y * 1.73, orig_q.y * 2.91);
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
	float sub_y = abs(fract(g.y * 2.0) - 0.5) * (pitch.y * 0.5);
	float m_sub = (1.0 - smoothstep(frame_width * 0.48, frame_width * 0.48 + fw * 1.5, sub_y)) * 0.85;
	float fade = clamp(1.0 - fw * 5.5, 0.15, 1.0);
	float frame = clamp(max(max(mx, my), m_sub) * fade, 0.0, 1.0);
	float pane_ao = (1.0 - smoothstep(frame_width, frame_width + 0.08, min(dist_m.x, dist_m.y))) * (1.0 - frame);

	vec3 wp_g = wpos + vec3(0.0173, 0.0131, 0.0197);
	float n_lo = texture(noise_tex, p2 * 0.18 + inst_seed * 0.17).r;
	float n_streak = texture(noise_tex, vec2(p2.x * 1.6, p2.y * 0.22) + wpos.xz * 0.05).r;
	float grime = clamp((pane_ao * 0.65 + (1.0 - n_lo) * 0.45 + smoothstep(0.55, 0.88, n_streak) * 0.35) * dirt_amount, 0.0, 0.85);

	vec3 eye_dir = normalize(wpos - INV_VIEW_MATRIX[3].xyz);
	vec3 w_nrm = normalize(wnrm);
	// 真 3D 射线投射伪室内视差空间（Interior Mapping：真实透视天花板灯带、楼板、侧隔墙与百叶窗/战损碎窗）
	vec3 r_tan = abs(w_nrm.y) > 0.85 ? vec3(1.0, 0.0, 0.0) : normalize(vec3(-w_nrm.z, 0.0, w_nrm.x));
	vec3 r_bin = normalize(cross(r_tan, w_nrm));
	float rd_u = dot(eye_dir, r_tan);
	float rd_v = dot(eye_dir, r_bin);
	float rd_d = max(-dot(eye_dir, w_nrm), 0.10);
	vec2 rm_dim = vec2(3.35, 3.08);
	float rm_depth = 2.85;
	vec2 rm_g = vec2(p2.x / rm_dim.x, wpos.y / rm_dim.y);
	vec2 rm_id = floor(rm_g);
	vec2 rm_uv = fract(rm_g) - 0.5;
	float room_hash = hash21(rm_id + inst_seed);
	float pane_hash = hash21(cell + inst_seed * 1.71);

	float tx = ((rd_u >= 0.0 ? 0.5 : -0.5) - rm_uv.x) * rm_dim.x / (abs(rd_u) > 1e-4 ? rd_u : (rd_u >= 0.0 ? 1e-4 : -1e-4));
	float ty = ((rd_v >= 0.0 ? 0.5 : -0.5) - rm_uv.y) * rm_dim.y / (abs(rd_v) > 1e-4 ? rd_v : (rd_v >= 0.0 ? 1e-4 : -1e-4));
	float tz = rm_depth / rd_d;
	float t_hit = min(min(max(tx, 0.0), max(ty, 0.0)), tz);
	vec3 hp = vec3(rm_uv.x * rm_dim.x + rd_u * t_hit, rm_uv.y * rm_dim.y + rd_v * t_hit, rd_d * t_hit);
	float hit_ceil = step(ty, min(tx, tz)) * step(0.0, rd_v);
	float hit_floor = step(ty, min(tx, tz)) * (1.0 - step(0.0, rd_v));
	float hit_side = step(tx, min(ty, tz));
	float depth_ao = exp(-hp.z * 0.58);

	vec3 wall_tone = mix(vec3(0.09, 0.10, 0.11), vec3(0.16, 0.15, 0.13), fract(room_hash * 5.3));
	vec3 room_surf = wall_tone * (hit_side > 0.5 ? 0.72 : (hit_ceil > 0.5 ? 0.88 : (hit_floor > 0.5 ? 0.44 : 0.58)));
	// 天花板格栅与日光灯带 / 后墙办公隔断阴影
	float ceil_grid = hit_ceil * (0.85 + 0.15 * cos(hp.x * 5.2) * cos(hp.z * 5.2));
	float ceil_strip = hit_ceil * smoothstep(0.22, 0.04, abs(hp.x)) * smoothstep(2.4, 0.5, hp.z);
	float back_clutter = (1.0 - hit_ceil - hit_floor) * step(hp.y, -0.35 + 0.45 * fract(room_hash * 9.1)) * 0.48;
	room_surf *= (1.0 - back_clutter) * mix(1.0, ceil_grid, hit_ceil) * depth_ao;

	// 玻璃前表面半拉百叶窗（约 34% 窗格）与战损碎裂黑洞窗格（约 12% 窗格无反光）
	float blind_drop = 0.25 + 0.55 * fract(room_hash * 7.3);
	float in_blind = step(0.64, room_hash) * step(1.0 - blind_drop, fract(g.y));
	float blind_slat = 0.55 + 0.45 * sin(wpos.y * 34.0);
	vec3 blind_col = mix(vec3(0.14, 0.14, 0.13), vec3(0.22, 0.21, 0.19), fract(room_hash * 3.7)) * blind_slat * 0.52;
	vec3 interior_col = mix(room_surf, blind_col, in_blind * 0.88);
	float broken_pane = step(0.88, pane_hash) * (1.0 - frame) * step(abs(w_nrm.y), 0.35);
	float shard_edge = smoothstep(0.16, 0.34, min(dist_m.x, dist_m.y) + (n_lo - 0.5) * 0.18);
	float hole_mask = broken_pane * shard_edge;
	interior_col = mix(interior_col, room_surf * 0.28, hole_mask);

	float wet_g = clamp(weather_wet, 0.0, 1.0);
	float rain_riv = wet_g > 0.01 ? wet_g * smoothstep(0.56, 0.86, texture(noise_tex, vec2(p2.x * 3.1, p2.y * 0.28) + wp_g.xz * 0.07).r) * (1.0 - frame) : 0.0;
	float eff_grime = grime * (1.0 - wet_g * 0.35);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = 0.08 + 0.84 * pow(1.0 - ndv, 3.4);
	vec3 refl = reflect(eye_dir, normalize(w_nrm + vec3(0.0, rain_riv * 0.06, 0.0)));
	vec3 sun_d = length(sun_dir_world) > 1e-3 ? normalize(sun_dir_world) : normalize(vec3(0.45, 0.62, 0.64));
	float r_sun = max(dot(refl, sun_d), 0.0);
	vec3 refl_up = mix(vec3(0.36, 0.43, 0.50), vec3(0.16, 0.24, 0.34), smoothstep(0.0, 0.65, max(refl.y, 0.0)));
	refl_up += vec3(0.95, 0.86, 0.72) * (pow(r_sun, 6.0) * 0.24 + pow(r_sun, 30.0) * 0.56);
	vec3 refl_dn = vec3(0.08, 0.10, 0.12) * (0.85 + 0.35 * wet_g);
	float diag_sky = texture(noise_tex, vec2((p2.x + p2.y * 0.72) * 0.18, (p2.y - p2.x * 0.35) * 0.10) + inst_seed * 0.23).r;
	float topdown_sky = smoothstep(-0.88, -0.22, refl.y) * (0.24 + 0.34 * diag_sky) * (1.0 - abs(w_nrm.y));
	float sky_vis = max(smoothstep(-0.14, 0.10 + (n_lo - 0.5) * 0.08, refl.y), topdown_sky);
	vec3 sky_tint = mix(refl_dn, refl_up, sky_vis) * (0.70 + 0.30 * n_lo);
	float refl_w = clamp((0.12 + fres * 0.74) * (1.0 - eff_grime * 0.45) * (1.0 - hole_mask), 0.0, 0.86);
	vec3 glass_col = mix(interior_col, sky_tint, refl_w);
	glass_col = mix(glass_col, vec3(0.18, 0.18, 0.17), eff_grime * 0.28 * (1.0 - hole_mask));
	glass_col *= 1.0 - pane_ao * 0.30;

	float eff_lit_chance = clamp(lit_chance, 0.08, 0.24);
	float is_lit = step(1.0 - eff_lit_chance, room_hash) * (1.0 - frame) * (1.0 - hole_mask);
	float lamp_falloff = (0.38 + 0.62 * depth_ao + ceil_strip * 0.85) * (1.0 - eff_grime * 0.38) * mix(1.0, 0.42 * blind_slat, in_blind);
	vec3 room_c = mix(lit_color.rgb, vec3(0.58, 0.74, 0.86), step(0.88, room_hash));
	vec3 lit_glow = room_c * is_lit * max(emit_strength, 0.32) * lamp_falloff * 0.72;
	glass_col = mix(glass_col, room_c * (0.34 + ceil_strip * 0.35), is_lit * 0.46 * clamp(lamp_falloff, 0.0, 1.0));

	vec3 frame_c = frame_color.rgb * (0.86 + 0.26 * n_lo) * (1.0 - wet_g * 0.08);
	ALBEDO = mix(glass_col, frame_c, frame);
	METALLIC = mix(0.18 * (1.0 - hole_mask), 0.58, frame);
	float pane_rough = mix(clamp(0.06 + eff_grime * 0.42 - rain_riv * 0.16 - wet_g * 0.03, 0.04, 0.66), 0.95, hole_mask);
	ROUGHNESS = mix(pane_rough, mix(0.64, 0.40, wet_g), frame);
	SPECULAR = mix(0.92 * (1.0 - hole_mask * 0.90), 0.50, frame);
	EMISSION = lit_glow;
	AO = clamp(1.0 - pane_ao * 0.32 - frame * 0.08, 0.58, 1.0);
	AO_LIGHT_AFFECT = 0.18;

	float riv_dx = rain_riv > 0.01 ? (texture(noise_tex, vec2(p2.x * 3.1 + 0.02, p2.y * 0.28) + wp_g.xz * 0.07).r - 0.5) * rain_riv * 0.22 : 0.0;
	vec2 fn = vec2(mx * sign(fg.x) * 0.35 + riv_dx, my * sign(fg.y) * 0.35) * fade;
	NORMAL_MAP = vec3(clamp(0.5 + fn.x, 0.1, 0.9), clamp(0.5 + fn.y, 0.1, 0.9), 1.0);
}
