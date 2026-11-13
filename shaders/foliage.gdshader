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

varying float v_ao;
varying float v_var;
varying vec3 v_wpos;

void vertex() {
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 枝梢/草尖随微风轻摆（UV.y = 1 为根部固定，UV.y = 0 为梢部摆动）
	float flex = clamp(1.0 - UV.y, 0.0, 1.0);
	float ph = world_origin.x * 0.37 + world_origin.z * 0.29 + VERTEX.y * 1.1;
	float gust = sin(TIME * 1.65 + ph) * 0.65 + cos(TIME * 2.9 + ph * 1.7) * 0.35;
	VERTEX.x += gust * sway_amp * flex * flex;
	VERTEX.z += cos(TIME * 1.35 + ph * 1.3) * sway_amp * 0.65 * flex * flex;

	v_ao = clamp(COLOR.r, 0.25, 1.0);
	v_var = COLOR.g;
	v_wpos = wp;
}

void fragment() {
	vec4 tx = texture(albedo_tex, UV);
	// 远景大仰角/俯拍时随导数自动降低裁切阈值，杜绝树冠远看稀疏发虚
	float uv_fw = max(fwidth(UV.x), fwidth(UV.y));
	float mip_boost = clamp(uv_fw * 2.8, 0.0, 0.22);
	ALPHA = tx.a;
	ALPHA_SCISSOR_THRESHOLD = max(0.11, alpha_cut - mip_boost);

	// 株间与冠层高低自然色阶过渡（深橄榄绿 <-> 微暖荒原黄绿）
	float tree_h = fract(sin(dot(floor(v_wpos.xz * 0.22), vec2(127.1, 311.7))) * 43758.5453);
	float mix_t = clamp(tree_h * 0.65 + v_var * 0.35, 0.0, 1.0);
	vec3 tint = mix(tint_a.rgb, tint_b.rgb, mix_t);
	// 树冠外层受光略暖亮，内芯保留适度阴翳，杜绝树冠过暗发黑
	vec3 shade_mul = mix(vec3(0.66, 0.72, 0.65), vec3(1.16, 1.14, 1.08), smoothstep(0.22, 0.96, v_ao));
	vec3 col = tx.rgb * tint * shade_mul;

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough_val - (1.0 - UV.y) * 0.08, 0.35, 0.96);
	SPECULAR = 0.24;
	METALLIC = 0.0;
	BACKLIGHT = col * vec3(0.62, 0.66, 0.34) * backlight_str * smoothstep(0.25, 1.0, v_ao);
	AO = clamp(mix(0.48, 1.0, v_ao), 0.45, 1.0);
	AO_LIGHT_AFFECT = 0.48;

	if (use_normal > 0.5) {
		vec3 nm = texture(normal_tex, UV).rgb;
		if (!FRONT_FACING) {
			nm.x = 1.0 - nm.x;
		}
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nm, clamp(1.0 - uv_fw * 4.0, 0.0, 0.75));
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp(ndl * 0.55 + 0.45, 0.0, 1.0);
	float shadow_fac = LIGHT_IS_DIRECTIONAL ? mix(0.54, 1.0, ATTENUATION) : ATTENUATION;
	float trans = clamp(dot(-NORMAL, LIGHT) * 0.55 + 0.45, 0.0, 1.0) * 0.40;
	float atten_trans = LIGHT_IS_DIRECTIONAL ? mix(0.35, 1.0, ATTENUATION) : ATTENUATION;
	DIFFUSE_LIGHT += (ALBEDO * wrap * shadow_fac + BACKLIGHT * trans * atten_trans) * LIGHT_COLOR * 0.32;
}
