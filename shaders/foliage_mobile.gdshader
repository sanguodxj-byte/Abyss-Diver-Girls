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
uniform float albedo_gain : hint_range(0.4, 5.0) = 1.0;
uniform float up_normal_blend : hint_range(0.0, 0.9) = 0.0;
uniform vec3 far_ground_col : source_color = vec3(0.35, 0.31, 0.25);
#include "res://shaders/occ_fade.gdshaderinc"

varying float v_ao;
varying float v_var;
varying float v_height;
varying float v_tree_h;
varying vec3 v_wpos;

void vertex() {
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float flex = clamp(1.0 - UV.y, 0.0, 1.0);
	float ph = world_origin.x * 0.37 + world_origin.z * 0.29;
	VERTEX.x += sin(TIME * 1.65 + ph) * sway_amp * flex * flex;
	v_ao = clamp(COLOR.r, 0.24, 1.0);
	v_var = COLOR.g;
	v_height = clamp(COLOR.b, 0.0, 1.0);
	v_tree_h = fract(sin(dot(world_origin.xz, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float occ_fade = 0.0;
	if (occ_params.w > 0.005) {
		occ_fade = occ_calc_fade(v_wpos, INV_VIEW_MATRIX[3].xyz, occ_params.w, 0.85);
		if (occ_fade > 0.005 && occ_ign(FRAGCOORD.xy) < clamp(occ_fade * 1.06, 0.0, 1.0)) {
			discard;
		}
	}
	vec4 tx = texture(albedo_tex, UV);
	float dist_cam = length(v_wpos - INV_VIEW_MATRIX[3].xyz);
	float far_fol = smoothstep(45.0, 95.0, dist_cam);
	float far_low = smoothstep(52.0, 102.0, dist_cam);
	float is_tree = 1.0 - smoothstep(0.35, 0.72, up_normal_blend);
	float low_fol = smoothstep(0.50, 0.85, up_normal_blend);
	// 轻量 Mipmap 覆盖率补偿 + 远距矮草/灌木柔和淡化，防止低画质远景树冠碎裂或地面暗黑胡椒点
	float uv_fw = max(fwidth(UV.x), fwidth(UV.y));
	float mip_boost = clamp(uv_fw * mix(2.8, 1.05, low_fol), 0.0, mix(0.22, 0.06, low_fol));
	float low_fade_cut = far_low * low_fol * 0.16;
	ALPHA = tx.a;
	ALPHA_SCISSOR_THRESHOLD = clamp(alpha_cut - mip_boost + low_fade_cut, 0.11, 0.62);
	vec3 tint = mix(tint_a.rgb, tint_b.rgb, clamp(v_tree_h * 0.60 + v_var * 0.26 + v_height * 0.16 * is_tree, 0.0, 1.0));
	float ao_src = mix(v_ao * 0.72 + v_height * 0.28, v_ao, low_fol);
	float ao_t = mix(smoothstep(0.16, 0.94, ao_src), smoothstep(0.05, 0.85, v_ao), up_normal_blend);
	ao_t = mix(ao_t, max(ao_t, mix(0.68, 0.82, low_fol)), far_fol * mix(0.42, 0.68, low_fol));
	vec3 tx_rgb = max(tx.rgb, vec3(0.042, 0.044, 0.032) * low_fol);
	vec3 low_shade = mix(vec3(0.72, 0.78, 0.74), vec3(0.94, 0.92, 0.86), low_fol);
	vec3 hi_shade = mix(vec3(1.16, 1.14, 0.98), vec3(1.14, 1.12, 0.98), low_fol);
	vec3 shade_mul = mix(low_shade, hi_shade, ao_t);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (up_normal_blend > 0.01) {
		vec3 v_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, v_up, up_normal_blend));
	}
	vec3 col = clamp(tx_rgb * tint * shade_mul * albedo_gain, vec3(0.0), vec3(0.90));
	float lum_c = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum_c), col, mix(0.84, 0.90, low_fol));
	col = mix(col, far_ground_col, far_fol * low_fol * 0.44);
	ALBEDO = occ_fade > 0.01 ? occ_soft_mist(col, occ_fade) : col;
	ROUGHNESS = clamp(rough_val, 0.52, 0.96);
	SPECULAR = 0.11;
	METALLIC = 0.0;
	BACKLIGHT = col * vec3(0.88, 0.92, 0.48) * backlight_str * 0.92;
	float ao_base = clamp(mix(mix(0.68, 0.94, up_normal_blend), 1.0, v_ao), 0.66, 1.0);
	AO = mix(ao_base, 1.0, far_fol * mix(0.42, 0.68, low_fol));
	AO_LIGHT_AFFECT = mix(0.26, 0.06, up_normal_blend);
}

void light() {
	// 4 指令半球包裹漫反射 + 逆光透射，彻底消除低画质/移动端树冠背光死黑
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp(ndl * 0.54 + 0.46, 0.0, 1.0);
	float sh = LIGHT_IS_DIRECTIONAL ? mix(0.66, 1.0, ATTENUATION) : ATTENUATION;
	float trans = clamp(dot(-NORMAL, LIGHT) * 0.50 + 0.50, 0.0, 1.0) * 0.54;
	DIFFUSE_LIGHT += (ALBEDO * wrap * sh + BACKLIGHT * trans * sh) * LIGHT_COLOR * 0.48;
}
