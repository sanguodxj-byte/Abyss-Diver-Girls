shader_type spatial;
// 写实虫族甲壳：湿润清漆高光、轮廓处深色、腹面浅色、脉络、斑驳、背光透射
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.4, 0.2, 0.15, 1.0);
uniform vec4 belly_tint : source_color = vec4(0.95, 0.78, 0.55, 1.0);
uniform float wet : hint_range(0.0, 1.0) = 0.6;
uniform float veins : hint_range(0.0, 1.0) = 0.4;
uniform float translucency : hint_range(0.0, 1.0) = 0.35;
uniform float detail_scale = 1.0;
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wnrm;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z + 1e-5);
}

float tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy).r * w.x + texture(t, p.xz).r * w.y + texture(t, p.xy).r * w.z;
}

void fragment() {
	vec3 w = tri_w(lnrm);
	vec3 p = lpos * detail_scale;
	float n1 = tri(noise_lo, p * 1.6, w);
	float n2 = tri(noise_hi, p * 5.0, w);
	float n3 = tri(noise_hi, p * 1.4 + vec3(4.0), w);
	// 脉络：脊状噪声
	float ridge = 1.0 - abs(n3 * 2.0 - 1.0);
	float vein = smoothstep(0.86, 0.97, ridge) * veins * clamp(1.0 - length(fwidth(p * 1.4)) * 4.0, 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 col = base_color.rgb * (0.7 + 0.4 * n1);
	// 斑点
	col = mix(col, col * 0.55, smoothstep(0.64, 0.72, n2) * 0.45);
	// 轮廓暗化（甲壳边缘厚、颜色深）
	col = mix(col, col * 0.3, fres * 0.75);
	// 腹面浅色
	float belly = smoothstep(0.1, -0.7, wnrm.y);
	col = mix(col, base_color.rgb * belly_tint.rgb * 1.3, belly * 0.4);
	col = mix(col, col * 0.35 + vec3(0.05, 0.0, 0.0), vein);
	ALBEDO = col;
	METALLIC = 0.0;
	float rough = mix(0.55, 0.14, wet * smoothstep(0.3, 0.75, n1 + n2 * 0.3));
	vec3 dn = fwidth(NORMAL);
	ROUGHNESS = clamp(sqrt(rough * rough + min(2.0 * dot(dn, dn), 0.25)), 0.1, 1.0);
	SPECULAR = 0.6;
	CLEARCOAT = wet;
	CLEARCOAT_ROUGHNESS = clamp(0.18 + min(2.0 * dot(dn, dn), 0.3), 0.0, 1.0);
	RIM = 0.35;
	RIM_TINT = 0.7;
	BACKLIGHT = base_color.rgb * translucency;
	vec3 nm = texture(normal_tex, (w.x > 0.5 ? p.zy : (w.y > 0.5 ? p.xz : p.xy)) * 2.0).rgb;
	float nfade = clamp(1.0 - length(fwidth(p * 2.0)) * 3.0, 0.0, 1.0);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nm, (0.2 + vein * 0.4) * nfade);
}
