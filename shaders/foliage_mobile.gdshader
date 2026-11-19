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
uniform float albedo_gain : hint_range(0.4, 3.5) = 1.0;
uniform float up_normal_blend : hint_range(0.0, 0.9) = 0.0;

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
	// 轻量 Mipmap 覆盖率补偿，防止低画质远景树冠稀疏碎裂
	float uv_fw = max(fwidth(UV.x), fwidth(UV.y));
	float mip_boost = clamp(uv_fw * 2.4, 0.0, 0.20);
	ALPHA = tx.a;
	ALPHA_SCISSOR_THRESHOLD = max(0.12, alpha_cut - mip_boost);
	float tree_h = fract(sin(dot(floor(v_wpos.xz * 0.22), vec2(127.1, 311.7))) * 43758.5453);
	vec3 tint = mix(tint_a.rgb, tint_b.rgb, clamp(tree_h * 0.65 + v_var * 0.35, 0.0, 1.0));
	float ao_t = mix(smoothstep(0.20, 0.94, v_ao), smoothstep(0.05, 0.85, v_ao), up_normal_blend);
	vec3 shade_mul = mix(vec3(0.66, 0.70, 0.70), vec3(1.12, 1.08, 0.94), ao_t);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (up_normal_blend > 0.01) {
		vec3 v_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, v_up, up_normal_blend));
	}
	vec3 col = clamp(tx.rgb * tint * shade_mul * albedo_gain, vec3(0.0), vec3(0.96));
	ALBEDO = col;
	ROUGHNESS = clamp(rough_val, 0.42, 0.96);
	SPECULAR = 0.12;
	METALLIC = 0.0;
	BACKLIGHT = col * vec3(0.65, 0.70, 0.38) * backlight_str * 0.85;
	AO = clamp(mix(mix(0.62, 0.80, up_normal_blend), 1.0, v_ao), 0.60, 1.0);
	AO_LIGHT_AFFECT = mix(0.38, 0.18, up_normal_blend);
}

void light() {
	// 4 指令半球包裹漫反射 + 逆光透射，彻底消除低画质/移动端树冠背光死黑
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp(ndl * 0.58 + 0.42, 0.0, 1.0);
	float sh = LIGHT_IS_DIRECTIONAL ? mix(0.56, 1.0, ATTENUATION) : ATTENUATION;
	float trans = clamp(dot(-NORMAL, LIGHT) * 0.50 + 0.50, 0.0, 1.0) * 0.36;
	DIFFUSE_LIGHT += (ALBEDO * wrap * sh + BACKLIGHT * trans * sh) * LIGHT_COLOR * 0.35;
}
