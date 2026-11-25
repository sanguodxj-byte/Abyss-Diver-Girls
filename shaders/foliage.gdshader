shader_type spatial;
// 写实废土林木、灌木与野草双面裁切着色器：
// 自适应 Mipmap 覆盖率抗稀疏阈值 + 树冠体积法线与内芯 AO + 逆光叶片半透光 + 自然株间色差与微风摆动。
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float use_normal = 1.0;
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
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 枝梢/草尖随微风轻摆 + 叶片高频微颤（UV.y = 1 为根部固定，UV.y = 0 为梢部摆动）
	float flex = clamp(1.0 - UV.y, 0.0, 1.0);
	float flex2 = flex * flex;
	float ph = world_origin.x * 0.37 + world_origin.z * 0.29 + VERTEX.y * 1.1;
	float gust = sin(TIME * 1.55 + ph) * 0.65 + cos(TIME * 2.75 + ph * 1.7) * 0.35;
	float flutter = sin(TIME * 4.1 + wp.x * 2.1 + wp.z * 2.5) * 0.16;
	VERTEX.x += (gust + flutter) * sway_amp * flex2;
	VERTEX.z += (cos(TIME * 1.30 + ph * 1.3) * 0.65 - flutter * 0.7) * sway_amp * flex2;
	VERTEX.y += sin(TIME * 2.4 + ph * 1.5) * sway_amp * 0.18 * flex2;

	v_ao = clamp(COLOR.r, 0.24, 1.0);
	v_var = COLOR.g;
	v_height = clamp(COLOR.b, 0.0, 1.0);
	// 按单株实例原点哈希色差，消除旧版世界网格接缝切穿单棵树冠的问题
	v_tree_h = fract(sin(dot(world_origin.xz, vec2(127.1, 311.7))) * 43758.5453);
	v_wpos = wp;
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
	// 乔木随导数补偿裁切防秃顶；荒原矮灌木与草簇限制补偿并在远端柔和收缩，彻底消除 60–112m 暗黑胡椒点锯齿
	float uv_fw = max(fwidth(UV.x), fwidth(UV.y));
	float mip_boost = clamp(uv_fw * mix(3.2, 1.15, low_fol), 0.0, mix(0.22, 0.06, low_fol));
	float low_fade_cut = far_low * low_fol * 0.16;
	ALPHA = tx.a;
	ALPHA_SCISSOR_THRESHOLD = clamp(alpha_cut - mip_boost + low_fade_cut, 0.10, 0.62);

	// 单株自然色差 + 世界空间大尺度微生态明暗 + 冠层由内下到顶梢的柔和日照暖度渐变
	float world_patch = 0.5 + 0.5 * sin(v_wpos.x * 0.065 + v_wpos.z * 0.052) * cos(v_wpos.z * 0.071 - v_wpos.x * 0.041);
	float mix_t = clamp(v_tree_h * 0.54 + v_var * 0.24 + world_patch * 0.12 + v_height * 0.14 * is_tree, 0.0, 1.0);
	vec3 tint = mix(tint_a.rgb, tint_b.rgb, mix_t);

	// 树冠体积明暗塑形：内腔保留通透深冷绿阴影，逆光绝不死黑，外缘柔和受光（告别黑炭与荧光绿两极端）
	float ao_src = mix(v_ao * 0.72 + v_height * 0.28, v_ao, low_fol);
	float ao_t = mix(smoothstep(0.14, 0.94, ao_src), smoothstep(0.05, 0.85, v_ao), up_normal_blend);
	ao_t = mix(ao_t, max(ao_t, mix(0.74, 0.84, low_fol)), far_fol * mix(0.42, 0.68, low_fol));
	vec3 tx_rgb = max(tx.rgb, vec3(0.042, 0.044, 0.032) * low_fol);
	vec3 low_shade = mix(vec3(0.72, 0.78, 0.74), vec3(0.94, 0.92, 0.86), low_fol);
	vec3 hi_shade = mix(vec3(1.16, 1.14, 0.98), vec3(1.14, 1.12, 0.98), low_fol);
	vec3 shade_mul = mix(low_shade, hi_shade, ao_t);
	vec3 col = clamp(tx_rgb * tint * shade_mul * albedo_gain, vec3(0.0), vec3(0.90));
	// B.o.T 去饱和战区写实收敛（抑制局部亮绿尖峰同时保留林木生机）
	float lum_c = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum_c), col, mix(0.84, 0.90, low_fol));
	// 远距矮灌木/野草向战区地表基色柔和过渡，融入沙地/荒原远景
	col = mix(col, far_ground_col, far_fol * low_fol * 0.44);

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (up_normal_blend > 0.01) {
		vec3 v_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, v_up, up_normal_blend));
	}

	ALBEDO = occ_fade > 0.01 ? occ_soft_mist(col, occ_fade) : col;
	ROUGHNESS = clamp(rough_val - (1.0 - UV.y) * 0.06 - v_height * 0.04 * is_tree, 0.56, 0.96);
	SPECULAR = mix(0.07, 0.11, is_tree);
	METALLIC = 0.0;
	BACKLIGHT = col * vec3(0.88, 0.92, 0.48) * backlight_str * smoothstep(0.08, 0.92, ao_src);
	float ao_base = clamp(mix(mix(0.68, 0.94, up_normal_blend), 1.0, v_ao), 0.66, 1.0);
	AO = mix(ao_base, 1.0, far_fol * mix(0.42, 0.68, low_fol));
	AO_LIGHT_AFFECT = mix(0.26, 0.06, up_normal_blend);

	if (use_normal > 0.5) {
		vec3 nm = texture(normal_tex, UV).rgb;
		if (!FRONT_FACING) {
			nm.x = 1.0 - nm.x;
		}
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nm, clamp(1.0 - uv_fw * 3.2, 0.16, 0.84));
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp(ndl * 0.54 + 0.46, 0.0, 1.0);
	float shadow_fac = LIGHT_IS_DIRECTIONAL ? mix(0.66, 1.0, ATTENUATION) : ATTENUATION;
	float back_wrap = clamp(dot(-NORMAL, LIGHT) * 0.50 + 0.50, 0.0, 1.0);
	float view_sss = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 2.4);
	float trans = back_wrap * 0.52 + view_sss * 0.62;
	float atten_trans = LIGHT_IS_DIRECTIONAL ? mix(0.62, 1.0, ATTENUATION) : ATTENUATION;
	DIFFUSE_LIGHT += (ALBEDO * wrap * shadow_fac + BACKLIGHT * trans * atten_trans) * LIGHT_COLOR * 0.48;
	// 叶片角质层微妙电解质蜡感反光（F0≈0.025 + 叶片色染色 + 软上限，彻底杜绝过曝泛白雪块）
	vec3 h_vec = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, h_vec), 0.0);
	float spec_exp = mix(40.0, 12.0, ROUGHNESS);
	float spec_lobe = pow(ndh, spec_exp) * (1.0 - ROUGHNESS * 0.78) * smoothstep(0.05, 0.55, ndl);
	vec3 leaf_sheen = mix(vec3(0.95, 0.98, 0.90), ALBEDO * 1.65 + vec3(0.08), 0.55);
	SPECULAR_LIGHT += min(LIGHT_COLOR * leaf_sheen * spec_lobe * SPECULAR_AMOUNT * ATTENUATION * 0.028, vec3(0.10));
}
