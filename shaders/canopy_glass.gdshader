shader_type spatial;
// 写实建筑玻璃与机甲光学观瞄镜着色器（纯不透明默认版，保留硬件 Early-Z）。
// - 低自发光（emit_energy <= 0.14）：建筑窗玻璃——柔和室内纵深渐变、百叶微韵律、零硬切块的自然微暖内透、菲涅尔天光反射与克制尘垢。
// - 高自发光（emit_energy > 0.14）：机甲光学镜/灯罩——双色镀膜菲涅尔冷光 + 锐利光学高光 + 受控辉光。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx, ensure_correct_normals;

uniform vec4 tint_color : source_color = vec4(0.18, 0.26, 0.24, 1.0);
uniform float emit_energy : hint_range(0.0, 4.0) = 0.08;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float occ_exempt = 0.0;
uniform float occ_self_fade = 0.0;
global uniform float weather_wet;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 sx = MODEL_MATRIX[0].xyz;
	vec3 sy = MODEL_MATRIX[1].xyz;
	vec3 sz = MODEL_MATRIX[2].xyz;
	vec3 sc = max(vec3(length(sx), length(sy), length(sz)), vec3(1e-3));
	mat3 rm = mat3(sx / sc.x, sy / sc.y, sz / sc.z);
	wnrm = normalize(rm * NORMAL);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 v_world = normalize(CAMERA_POSITION_WORLD - wpos);
	float ndv = clamp(dot(n, v_world), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	vec3 an = abs(n);
	vec2 wuv = an.x >= an.z ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);

	float dirt_lo = texture(noise_tex, wuv * 0.28 + vec2(0.17, 0.31)).r;
	float dirt_hi = texture(noise_tex, vec2(wuv.x * 1.45, wuv.y * 0.38) + vec2(0.61, 0.13)).r;
	float grime = smoothstep(0.46, 0.88, dirt_lo * 0.58 + dirt_hi * 0.42);

	if (emit_energy <= 0.14) {
		// 真 3D 射线盒子伪室内视差（天花板格栅/灯带、侧隔墙、室内纵深暗腔与半拉百叶窗）
		vec3 eye_dir = -v_world;
		vec3 r_tan = abs(n.y) > 0.85 ? vec3(1.0, 0.0, 0.0) : normalize(vec3(-n.z, 0.0, n.x));
		vec3 r_bin = normalize(cross(r_tan, n));
		float rd_u = dot(eye_dir, r_tan);
		float rd_v = dot(eye_dir, r_bin);
		float rd_d = max(-dot(eye_dir, n), 0.10);
		vec2 rm_dim = vec2(3.20, 3.02);
		float rm_depth = 2.70;
		vec2 rm_g = vec2(wuv.x / rm_dim.x, wpos.y / rm_dim.y);
		vec2 rm_id = floor(rm_g);
		vec2 rm_uv = fract(rm_g) - 0.5;
		float r_hash = fract(sin(dot(rm_id, vec2(127.1, 311.7))) * 43758.5453);
		float r_hash2 = fract(sin(dot(rm_id, vec2(269.5, 183.3))) * 43758.5453);

		float tx = ((rd_u >= 0.0 ? 0.5 : -0.5) - rm_uv.x) * rm_dim.x / (abs(rd_u) > 1e-4 ? rd_u : (rd_u >= 0.0 ? 1e-4 : -1e-4));
		float ty = ((rd_v >= 0.0 ? 0.5 : -0.5) - rm_uv.y) * rm_dim.y / (abs(rd_v) > 1e-4 ? rd_v : (rd_v >= 0.0 ? 1e-4 : -1e-4));
		float tz = rm_depth / rd_d;
		float t_hit = min(min(max(tx, 0.0), max(ty, 0.0)), tz);
		vec3 hp = vec3(rm_uv.x * rm_dim.x + rd_u * t_hit, rm_uv.y * rm_dim.y + rd_v * t_hit, rd_d * t_hit);
		float hit_ceil = step(ty, min(tx, tz)) * step(0.0, rd_v);
		float hit_side = step(tx, min(ty, tz));
		float depth_ao = exp(-hp.z * 0.60);

		vec3 deep_room = mix(vec3(0.065, 0.075, 0.088), vec3(0.145, 0.140, 0.128), r_hash);
		deep_room *= (hit_side > 0.5 ? 0.70 : (hit_ceil > 0.5 ? 0.90 : 0.52)) * depth_ao;
		float ceil_strip = hit_ceil * smoothstep(0.20, 0.03, abs(hp.x)) * smoothstep(2.3, 0.4, hp.z);
		float blinds = step(0.62, r_hash2) * step(0.45 + 0.35 * r_hash, fract(rm_g.y));
		float slat = 0.56 + 0.44 * sin(wpos.y * 34.0);
		deep_room = mix(deep_room, vec3(0.16, 0.16, 0.15) * slat * 0.54, blinds * 0.85);

		float is_lit = step(0.80, r_hash) * (1.0 - blinds * 0.55);
		vec3 room_lamp = mix(vec3(0.90, 0.66, 0.38), vec3(0.58, 0.76, 0.90), step(0.72, r_hash2));
		vec3 warm_emit = room_lamp * is_lit * (0.20 + 0.24 * depth_ao + ceil_strip * 0.45);
		deep_room += room_lamp * is_lit * (0.16 * depth_ao + ceil_strip * 0.28);

		vec3 refl_dir = reflect(-v_world, n);
		float diag_glint = texture(noise_tex, vec2((wuv.x + wuv.y * 0.82) * 0.22, (wuv.y - wuv.x * 0.42) * 0.11) + vec2(0.11, 0.37)).r;
		float glint_band = smoothstep(0.48, 0.86, diag_glint);
		float sky_t = clamp(max(refl_dir.y * 1.10 + 0.26, (1.0 - ndv) * 0.38 + glint_band * 0.42), 0.0, 1.0);
		vec3 sky_refl = mix(vec3(0.05, 0.07, 0.095), vec3(0.24, 0.33, 0.42), smoothstep(0.18, 0.88, sky_t));
		sky_refl += vec3(0.12, 0.15, 0.20) * glint_band * (0.40 + 0.60 * fres);
		vec3 col = mix(deep_room, sky_refl, clamp(0.14 + fres * 0.56, 0.0, 0.72) * (1.0 - grime * 0.38));
		col = mix(col, vec3(0.12, 0.12, 0.115), grime * 0.22);

		float wet_g = clamp(weather_wet, 0.0, 1.0);
		ALBEDO = col;
		METALLIC = mix(0.20, 0.05, grime);
		ROUGHNESS = clamp(mix(0.07, 0.34, grime) * (1.0 - wet_g * 0.35), 0.05, 0.48);
		SPECULAR = 0.90;
		EMISSION = warm_emit * (1.0 - grime * 0.32) + tint_color.rgb * (emit_energy * 0.28);
	} else {
		vec3 optic_coat = mix(tint_color.rgb, vec3(0.45, 0.78, 0.85), fres * 0.45);
		ALBEDO = mix(vec3(0.03, 0.045, 0.055), optic_coat * 0.35, fres * 0.65);
		METALLIC = 0.78;
		ROUGHNESS = clamp(0.06 + grime * 0.09, 0.04, 0.22);
		SPECULAR = 0.95;
		EMISSION = tint_color.rgb * (emit_energy * (0.82 + 0.28 * (1.0 - fres)));
	}
}
