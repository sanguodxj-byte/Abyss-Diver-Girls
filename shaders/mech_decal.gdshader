shader_type spatial;
// B.o.T 军工战术喷字、警示标识与排气烟熏贴花着色器（视线无视差深度前拉，远近景零深度闪烁）
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D decal_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.94);
uniform float rough_base : hint_range(0.0, 1.0) = 0.68;
uniform float pull_bias : hint_range(0.0, 0.02) = 0.0032;
uniform float takes_damage : hint_range(0.0, 1.0) = 1.0;

global uniform float mech_damage;
global uniform float weather_wet;

varying vec3 wpos;

void vertex() {
	vec3 world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wpos = world_p;
	vec3 to_cam = CAMERA_POSITION_WORLD - world_p;
	float cam_d = length(to_cam);
	vec3 cam_dir_w = to_cam / max(cam_d, 0.001);
	// 视线方向世界空间前拉（屏幕投影零视差偏移，彻底根除 5m 机库至 60m 战区俯视角的深度精度闪烁）
	float ray_pull_w = clamp(0.0018 + cam_d * 0.00032, 0.0018, 0.018);
	vec3 local_ray = vec3(
		dot(MODEL_MATRIX[0].xyz, cam_dir_w) / max(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz), 1e-6),
		dot(MODEL_MATRIX[1].xyz, cam_dir_w) / max(dot(MODEL_MATRIX[1].xyz, MODEL_MATRIX[1].xyz), 1e-6),
		dot(MODEL_MATRIX[2].xyz, cam_dir_w) / max(dot(MODEL_MATRIX[2].xyz, MODEL_MATRIX[2].xyz), 1e-6)
	);
	VERTEX += NORMAL * pull_bias + local_ray * ray_pull_w;
}

void fragment() {
	vec4 tex = texture(decal_tex, UV);
	float a = tex.a * tint_color.a;
	if (a < 0.02) {
		discard;
	}
	vec3 col = tex.rgb * tint_color.rgb;
	float dmg = clamp(mech_damage * takes_damage, 0.0, 1.0);
	if (dmg > 0.01) {
		col *= mix(1.0, 0.35, dmg * 0.75);
	}
	float wet = clamp(weather_wet, 0.0, 1.0);
	col *= mix(1.0, 0.88, wet * 0.65);

	ALBEDO = col;
	ALPHA = a;
	METALLIC = 0.02;
	ROUGHNESS = mix(rough_base, 0.32, wet * 0.55);
	SPECULAR = 0.38;
}
