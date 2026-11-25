shader_type spatial;
// 山脚冲积扇碎石过渡裙边着色器 V4：
// 与 mountain_terrain / obsidian_terrain 共享全局世界坐标 (wp.xz + world_offset)，
// 随冲沟方向拉出自然不规则长短的碎石冲积扇，通过高度图溶解无缝融入任意地表。
render_mode blend_mix, depth_draw_never, diffuse_burley, specular_schlick_ggx;

uniform sampler2D scree_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_r : filter_linear_mipmap_anisotropic, repeat_enable; // R=rough, G=cavity AO, B=height
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;

uniform vec2 world_offset = vec2(0.0, 0.0);
uniform vec3 scree_tint : source_color = vec3(0.85, 0.75, 0.61);
uniform float normal_str = 0.82;
global uniform float weather_wet;

varying highp vec3 wp;
varying vec3 wn;
varying vec4 vcol; // r=凹腔AO, a=总遮罩

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR;
}

void fragment() {
	float base_m = clamp(vcol.a, 0.0, 1.0);
	if (base_m <= 0.004) {
		discard;
	}

	vec2 gxz = wp.xz + world_offset;
	float dist_cam = length(CAMERA_POSITION_WORLD - wp);
	float dist_fade = smoothstep(340.0, 230.0, dist_cam);
	if (dist_fade <= 0.005) {
		discard;
	}
	float lod_far = smoothstep(90.0, 280.0, dist_cam);

	float n_mac = texture(n_low, gxz * 0.0085).r;
	float n_mid = texture(n_low, gxz * 0.029 + vec2(0.41, 0.23)).r;
	float scale_mix = smoothstep(0.28, 0.72, n_mac * 0.65 + n_mid * 0.35);

	vec2 suv1 = gxz * 0.140;
	vec2 suv2 = gxz * 0.058 + vec2(0.43, 0.29);
	vec3 sa = mix(texture(scree_a, suv1).rgb, texture(scree_a, suv2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.28, 0.0, 0.85));
	vec3 sr = mix(texture(scree_r, suv1).rgb, texture(scree_r, suv2).rgb, clamp(scale_mix * 0.42 + lod_far * 0.28, 0.0, 0.85));
	vec2 sn = (texture(scree_n, suv1).rg * 2.0 - 1.0) * mix(0.70, 0.34, lod_far) + (texture(scree_n, suv2).rg * 2.0 - 1.0) * 0.36;

	// 高度图驱动冲积扇碎石溶解：外沿自然散落碎石颗粒，中心交界带完全实体盖住 y=0 硬线，远距 230..340m 平滑淡出避免硬接缝
	float pebble_h = clamp(sr.b * 0.70 + n_mid * 0.30, 0.0, 1.0);
	float edge_noise = (n_mid - 0.5) * 0.34 + (pebble_h - 0.48) * 0.44;
	float alpha = smoothstep(0.05, 0.76, base_m + edge_noise * (1.0 - smoothstep(0.74, 0.95, base_m))) * dist_fade;
	if (alpha <= 0.01) {
		discard;
	}

	vec3 col = sa * scree_tint * mix(0.90, 1.10, n_mid);
	float ao_v = clamp(vcol.r, 0.56, 1.0);
	col *= mix(0.76, 1.0, ao_v);

	vec3 N = normalize(wn);
	vec3 n_pert = vec3(sn.x, 0.0, sn.y) * normal_str * alpha;
	n_pert -= N * dot(n_pert, N);
	vec3 w_nrm = normalize(N + n_pert);

	float wet = clamp(weather_wet, 0.0, 1.0);
	col *= mix(1.0, 0.76, wet * 0.85);

	NORMAL = normalize((VIEW_MATRIX * vec4(w_nrm, 0.0)).xyz);
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = clamp(sr.r - wet * 0.12, mix(0.45, 0.66, wet), 0.97);
	SPECULAR = mix(0.25, 0.32, wet * 0.65);
	AO = clamp(ao_v * mix(0.60, 1.0, sr.g), 0.38, 1.0);
	AO_LIGHT_AFFECT = 0.45;
}
