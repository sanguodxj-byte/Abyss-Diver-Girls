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
	// 轻量 Mipmap 覆盖率补偿，防止低画质远景树冠稀疏碎裂
	float uv_fw = max(fwidth(UV.x), fwidth(UV.y));
	float mip_boost = clamp(uv_fw * 2.8, 0.0, 0.22);
	ALPHA = tx.a;
	ALPHA_SCISSOR_THRESHOLD = max(0.11, alpha_cut - mip_boost);
	float is_tree = 1.0 - smoothstep(0.35, 0.72, up_normal_blend);
	float low_fol = smoothstep(0.50, 0.85, up_normal_blend);
	vec3 tint = mix(tint_a.rgb, tint_b.rgb, clamp(v_tree_h * 0.60 + v_var * 0.26 + v_height * 0.16 * is_tree, 0.0, 1.0));
	float ao_src = mix(v_ao * 0.74 + v_height * 0.26, v_ao, low_fol);
	float ao_t = mix(smoothstep(0.20, 0.95, ao_src), smoothstep(0.05, 0.85, v_ao), up_normal_blend);
	vec3 tx_rgb = max(tx.rgb, vec3(0.042, 0.044, 0.032) * low_fol);
	vec3 low_shade = mix(vec3(0.66, 0.74, 0.69), vec3(0.94, 0.92, 0.85), low_fol);
	vec3 hi_shade = mix(vec3(1.20, 1.16, 0.99), vec3(1.16, 1.13, 1.00), low_fol);
	vec3 shade_mul = mix(low_shade, hi_shade, ao_t);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (up_normal_blend > 0.01) {
		vec3 v_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, v_up, up_normal_blend));
	}
	vec3 col = clamp(tx_rgb * tint * shade_mul * albedo_gain, vec3(0.0), vec3(0.96));
	ALBEDO = occ_fade > 0.01 ? occ_soft_mist(col, occ_fade) : col;
	ROUGHNESS = clamp(rough_val, 0.42, 0.96);
	SPECULAR = 0.14;
	METALLIC = 0.0;
	BACKLIGHT = col * vec3(0.82, 0.90, 0.44) * backlight_str * 0.92;
	AO = clamp(mix(mix(0.64, 0.94, up_normal_blend), 1.0, v_ao), 0.62, 1.0);
	AO_LIGHT_AFFECT = mix(0.26, 0.06, up_normal_blend);
}

void light() {
	// 4 指令半球包裹漫反射 + 逆光透射，彻底消除低画质/移动端树冠背光死黑
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp(ndl * 0.56 + 0.44, 0.0, 1.0);
	float sh = LIGHT_IS_DIRECTIONAL ? mix(0.58, 1.0, ATTENUATION) : ATTENUATION;
	float trans = clamp(dot(-NORMAL, LIGHT) * 0.50 + 0.50, 0.0, 1.0) * 0.44;
	DIFFUSE_LIGHT += (ALBEDO * wrap * sh + BACKLIGHT * trans * sh) * LIGHT_COLOR * 0.44;
}
