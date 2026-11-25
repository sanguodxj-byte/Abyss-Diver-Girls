shader_type spatial;
// 写实虫族甲壳：湿润高光（折入单叶 GGX）、轮廓处深色、腹面浅色、脉络、斑驳、背光透射（纯不透明保留 Early-Z）
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.4, 0.2, 0.15, 1.0);
uniform vec4 belly_tint : source_color = vec4(0.95, 0.78, 0.55, 1.0);
uniform float wet : hint_range(0.0, 1.0) = 0.6;
uniform float veins : hint_range(0.0, 1.0) = 0.4;
uniform float translucency : hint_range(0.0, 1.0) = 0.35;
uniform float detail_scale = 1.0;
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float occ_self_fade = 0.0;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wnrm;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(lnrm);
	vec3 p = lpos * detail_scale;
	vec2 p2 = (an.x >= an.y && an.x >= an.z) ? p.zy : (an.y >= an.z ? p.xz : p.xy);
	float n1 = texture(noise_lo, p2 * 1.6).r;
	float n2 = texture(noise_hi, p2 * 5.0).r;
	float n3 = texture(noise_hi, p2 * 1.4 + vec2(4.0)).r;
	// 脉络：脊状噪声
	float ridge = 1.0 - abs(n3 * 2.0 - 1.0);
	float p_fw = length(fwidth(p));
	float vein = smoothstep(0.86, 0.97, ridge) * veins * clamp(1.0 - p_fw * 5.6, 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 col = base_color.rgb * (0.7 + 0.4 * n1);
	// 斑点
	col = mix(col, col * 0.55, smoothstep(0.64, 0.72, n2) * 0.45);
	// 轮廓暗化（甲壳边缘厚、颜色深）
	col = mix(col, col * 0.3, fres * 0.75);
	// 腹面浅色
	float belly = smoothstep(0.1, -0.7, wnrm.y);
	col = mix(col, base_color.rgb * belly_tint.rgb * 1.3, belly * 0.4);
	// 掠射角甲壳微虹彩光泽
	vec3 irid = mix(base_color.rgb * 1.25, vec3(0.18, 0.38, 0.46), 0.35);
	col = mix(col, irid, fres * (1.0 - fres) * wet * 0.55);
	col = mix(col, col * 0.35 + vec3(0.05, 0.0, 0.0), vein);
	ALBEDO = col;
	METALLIC = 0.0;
	float rough = mix(0.54, 0.12, wet * smoothstep(0.28, 0.74, n1 + n2 * 0.3)) * (1.0 - wet * 0.14);
	vec3 dn = fwidth(NORMAL);
	ROUGHNESS = clamp(sqrt(max(rough * rough + min(2.0 * dot(dn, dn), 0.25), 0.0)), 0.09, 1.0);
	SPECULAR = mix(0.62, 0.92, wet);
	AO = clamp(1.0 - vein * 0.55 - smoothstep(0.62, 0.75, n2) * 0.2, 0.28, 1.0);
	AO_LIGHT_AFFECT = 0.5;
	RIM = 0.38;
	RIM_TINT = 0.72;
	BACKLIGHT = base_color.rgb * translucency;
	vec3 nm = texture(normal_tex, p2 * 2.0).rgb;
	float nfade = clamp(1.0 - p_fw * 6.0, 0.0, 1.0);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nm, (0.24 + vein * 0.45) * nfade);
}
