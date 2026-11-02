shader_type spatial;
// 体积云：在云层顶面光栅化，向下光线步进穿过 [cloud_bot, cloud_top] 的三维密度场。
// 每一步向太阳再步进几次求自阴影（Beer-Lambert + powder），云团有真正的厚度、背光面和透光边。
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/menu_common.gdshaderinc"
uniform int steps = 40;
uniform float sigma = 0.045;      // 消光系数（每米，密度 1 时）
uniform float far_fade = 5200.0;  // 远处交给天空盒的云海
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float hg(float c, float g) { float g2 = g * g; return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * c, 1.5)); }

void fragment() {
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 d = normalize(wp - ro);
	if (d.y > -0.003) discard;
	float t0 = (cloud_top - ro.y) / d.y;
	float t1 = (cloud_bot - ro.y) / d.y;
	float len = min(t1 - t0, 900.0);
	float dt = len / float(steps);
	float jit = hash(FRAGCOORD.xy + fract(TIME) * 37.0);
	vec3 L = normalize(sun_dir);
	float mu = dot(d, L);
	float phase = mix(hg(mu, 0.55), hg(mu, -0.2), 0.3) * 4.0 * PI;
	vec3 sky_amb = mix(cloud_shade, vec3(0.55, 0.62, 0.78), 0.35);
	float T = 1.0;
	vec3 col = vec3(0.0);
	float dsum = 0.0;
	float wsum = 0.0;
	for (int i = 0; i < steps; i++) {
		float t = t0 + (float(i) + jit) * dt;
		vec3 p = ro + d * t;
		float cov = cloud_cov(p.xz);
		if (cov < 0.01) continue;
		float dn = cloud_dens(p, cov);
		if (dn < 0.003) continue;
		// 向太阳的光学深度
		float od = 0.0;
		for (int k = 1; k <= 4; k++) {
			vec3 q = p + L * (float(k * k) * 9.0);
			od += cloud_dens(q, cloud_cov(q.xz)) * float(2 * k - 1) * 9.0;
		}
		float Ts = exp(-od * sigma * 0.9);
		float powder = 1.0 - exp(-od * sigma * 2.0 - dn * 1.5);
		float h = clamp((p.y - cloud_bot) / (cloud_top - cloud_bot), 0.0, 1.0);
		vec3 lum = sun_col * cloud_lit * 1.45 * Ts * mix(0.6, 1.0, powder) * phase
		         + sky_amb * mix(0.35, 1.0, h) * 0.7;
		float a = 1.0 - exp(-dn * sigma * dt);
		col += T * a * lum;
		dsum += T * a * t;
		wsum += T * a;
		T *= 1.0 - a;
		if (T < 0.02) break;
	}
	float alpha = 1.0 - T;
	if (alpha < 0.002) discard;
	col /= max(alpha, 1e-4);
	float dist = dsum / max(wsum, 1e-4);
	// 大气透视：随距离褪向地平线霾色（与天空盒同色）
	float af = 1.0 - exp(-dist * 0.00042);
	col = mix(col, mix(haze_col, horizon, 0.5) * 1.05, clamp(af, 0.0, 0.9));
	ALBEDO = col * exposure;
	ALPHA = alpha * (1.0 - smoothstep(far_fade * 0.55, far_fade, t0)) * smoothstep(0.003, 0.02, -d.y);
}
