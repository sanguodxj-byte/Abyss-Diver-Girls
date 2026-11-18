shader_type spatial;
// 移动端专用轻量植被双面裁切着色器：无额外法线采样、无自定义光照与背光透射开销。
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float use_normal = 0.0;
uniform vec4 tint_a : source_color = vec4(0.86, 0.90, 0.80, 1.0);
uniform vec4 tint_b : source_color = vec4(1.06, 0.96, 0.78, 1.0);
uniform float rough_val : hint_range(0.2, 1.0) = 0.78;
uniform float alpha_cut : hint_range(0.08, 0.65) = 0.34;
uniform float sway_amp : hint_range(0.0, 0.25) = 0.045;
uniform float backlight_str : hint_range(0.0, 1.0) = 0.36;

varying float v_ao;
varying float v_var;
varying vec3 v_wpos;

void vertex() {
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float flex = clamp(1.0 - UV.y, 0.0, 1.0);
	float ph = world_origin.x * 0.37 + world_origin.z * 0.29;
	VERTEX.x += sin(TIME * 1.65 + ph) * sway_amp * flex * flex;
	v_ao = clamp(COLOR.r, 0.25, 1.0);
	v_var = COLOR.g;
}

void fragment() {
	vec4 tx = texture(albedo_tex, UV);
	ALPHA = tx.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	float tree_h = fract(sin(dot(floor(v_wpos.xz * 0.22), vec2(127.1, 311.7))) * 43758.5453);
	vec3 tint = mix(tint_a.rgb, tint_b.rgb, clamp(tree_h * 0.65 + v_var * 0.35, 0.0, 1.0));
	vec3 shade_mul = mix(vec3(0.68, 0.74, 0.66), vec3(1.14, 1.12, 1.06), smoothstep(0.22, 0.96, v_ao));
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = tx.rgb * tint * shade_mul;
	ROUGHNESS = clamp(rough_val, 0.40, 0.96);
	SPECULAR = 0.0;
	METALLIC = 0.0;
}
