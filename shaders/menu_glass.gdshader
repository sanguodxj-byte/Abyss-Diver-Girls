shader_type spatial;
// 观景窗玻璃（贴窗视角也要"看得出是玻璃"）：
//  · 积灰 / 指纹污渍 / 雨痕 / 细划痕 —— 迎着太阳时被照亮（前向散射），背光处只是淡淡一层
//  · 水珠：小圆珠，亮边 + 暗心，模拟折射
//  · 轻微青灰色调 + 菲涅尔反光 + 舱内暖光的淡反射
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx, unshaded;

uniform vec2 pane_size = vec2(1.3, 2.5);
uniform vec3 tint : source_color = vec3(0.78, 0.86, 0.9);
uniform vec3 sun_dir = vec3(0.45, 0.22, -0.87);
uniform vec3 sun_col : source_color = vec3(1.0, 0.8, 0.55);
uniform float seed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

// 水珠：返回 x=覆盖, y=亮边
vec2 drops(vec2 p, float sc) {
	vec2 g = p * sc;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id + seed);
	if (h < 0.86) return vec2(0.0);
	vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
	float r = mix(0.06, 0.16, hash(id + 1.3));
	float d = length((f - o * 0.5) * vec2(1.0, 0.85));
	float cov = 1.0 - smoothstep(r * 0.85, r, d);
	float rim = smoothstep(r * 0.55, r * 0.95, d) * cov;
	return vec2(cov, rim);
}

void fragment() {
	vec2 p = UV * pane_size;
	vec2 e = min(p, pane_size - p);
	float edge = min(e.x, e.y);
	// 积灰：边缘重，底部重，中间是一层不均匀的薄雾
	float film = fbm(p * 2.2 + seed) * 0.6 + fbm(p * 9.0 + seed * 2.0) * 0.4;
	float dust = (1.0 - smoothstep(0.0, 0.16, edge)) * 0.8;
	dust += (1.0 - smoothstep(0.0, 0.7, p.y)) * 0.35;          // UV.y=0 在上方? 两端都加一点
	dust += (1.0 - smoothstep(0.0, 0.5, pane_size.y - p.y)) * 0.45;
	dust += smoothstep(0.45, 0.8, film) * 0.45;
	// 擦拭过的弧形痕迹（清洁时留下的扇形）
	vec2 wc = vec2(pane_size.x * 0.5, pane_size.y * 1.15);
	float arc = abs(fract(length(p - wc) * 2.6 + fbm(p * 3.0) * 0.3) - 0.5);
	dust += smoothstep(0.08, 0.0, arc) * 0.18 * smoothstep(0.3, 0.7, film);
	// 竖向雨痕
	float streak = smoothstep(0.78, 0.95, vnoise(vec2(p.x * 34.0 + seed * 7.0, p.y * 0.9))) * smoothstep(0.3, 0.8, fbm(vec2(p.x * 18.0, p.y * 2.5 + seed)));
	// 划痕
	float scr = smoothstep(0.988, 1.0, vnoise(vec2((p.x + p.y * 0.55) * 110.0, (p.y - p.x * 0.3) * 1.5) + seed));
	vec2 dr = drops(p, 11.0) * 0.6 + drops(p + 0.37, 23.0) * 0.45;
	dr *= smoothstep(0.35, 0.65, fbm(p * 1.4 + seed * 5.0));   // 水珠成片分布，不均匀
	float d = clamp(dust * 0.55 + streak * 0.35 + scr * 0.5, 0.0, 1.0);
	// 视线方向（世界）——迎着太阳时污渍发亮
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	float fwd = max(dot(vw, normalize(sun_dir)), 0.0);
	float scatter = pow(fwd, 6.0) * 2.2 + pow(fwd, 1.5) * 0.35 + 0.12;
	vec3 lit = sun_col * scatter;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	vec3 col = tint * 0.35;
	col = mix(col, vec3(0.7, 0.62, 0.52) * lit, d);
	col += vec3(1.0, 0.75, 0.5) * dr.y * (0.12 + scatter * 0.4);   // 水珠亮边
	col = mix(col, vec3(0.08, 0.07, 0.07), dr.x * 0.25 - dr.y * 0.1);
	// 舱内暖光的淡反射（自下而上渐弱）
	col += vec3(0.9, 0.55, 0.25) * 0.06 * (1.0 - UV.y);
	ALBEDO = col;
	ALPHA = clamp(0.07 + d * 0.55 + dr.x * 0.22 + fres * 0.25, 0.0, 0.9);
}
