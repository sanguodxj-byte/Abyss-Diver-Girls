shader_type spatial;
// 云下城市楼体：按真实尺寸算楼层与窗格（层高 3.3m、窗距 2.8m），玻璃反天光、部分窗洞烧空；
// 屋顶有女儿墙边、污渍；残楼窗洞全黑；远处窗格按像素尺寸平均掉，避免摩尔纹。
render_mode unshaded, shadows_disabled, fog_disabled;
#include "res://shaders/menu_common.gdshaderinc"
uniform float ground_y = -260.0;
varying vec3 wp;
varying vec3 wn;
varying vec3 ln;
varying vec3 lp;
varying vec3 bsz;
varying vec4 cus;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ln = NORMAL;
	bsz = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * bsz;
	cus = INSTANCE_CUSTOM;
}
void fragment() {
	vec3 L = normalize(sun_dir);
	float ndl = max(dot(wn, L), 0.0);
	float hgt = wp.y - ground_y;
	float side = step(abs(ln.y), 0.5);
	float u = abs(ln.x) > 0.5 ? lp.z : lp.x;
	float fn = fbm(vec2(u * 0.25 + wp.x * 0.01, hgt * 0.3), 3);
	vec3 c = cus.rgb * (0.78 + fn * 0.4);
	vec3 sky_amb = mix(vec3(0.34, 0.36, 0.44), vec3(0.55, 0.42, 0.34), clamp(wn.y, 0.0, 1.0));
	vec3 lit = sky_amb * 0.6 + sun_col * ndl * 1.55;
	if (side < 0.5) {
		// 屋顶：女儿墙一圈略亮，中间沥青防水层偏暗
		vec2 e = bsz.xz * 0.5 - abs(lp.xz);
		float rim = 1.0 - smoothstep(0.35, 0.7, min(e.x, e.y));
		c = mix(c * vec3(0.62, 0.6, 0.58) * (0.8 + fn * 0.4), c * 1.05, rim);
		lit = sky_amb * 0.8 + sun_col * L.y * 1.5;
	} else if (cus.a > 0.25) {
		// 立面窗格
		float fl = hgt / 3.3;
		float co = u / 2.8;
		vec2 fw = fwidth(vec2(co, fl));
		float fade = smoothstep(0.35, 0.9, max(fw.x, fw.y));   // 远处窗格小于 ~2 像素时平均
		vec2 cell = floor(vec2(co, fl));
		vec2 f = fract(vec2(co, fl));
		float win = smoothstep(0.18, 0.24, f.x) * (1.0 - smoothstep(0.76, 0.82, f.x))
		          * smoothstep(0.3, 0.36, f.y) * (1.0 - smoothstep(0.86, 0.92, f.y));
		win *= step(1.0, fl);                                   // 首层是店面，不画窗
		float rnd = hash(cell + vec2(floor(lp.x * 0.07 + 31.0), floor(wp.z * 0.013)) + cus.r * 17.0);
		// 玻璃：天光反射，迎光面偶尔有太阳反光；烧空的窗洞是黑的
		vec3 glass = mix(vec3(0.07, 0.08, 0.1), vec3(0.3, 0.33, 0.4), 0.25 + 0.35 * rnd) / max(lit, vec3(0.2));
		glass += sun_col * pow(ndl, 3.0) * step(0.93, rnd) * 0.6 / max(lit, vec3(0.2));
		float broken = step(rnd, cus.a < 0.75 ? 1.1 : 0.22);
		vec3 hole = vec3(0.025) / max(lit, vec3(0.2));
		vec3 wc = mix(glass, hole, broken);
		float band = smoothstep(0.0, 0.08, f.y) * (1.0 - smoothstep(0.92, 1.0, f.y));
		vec3 fac = c * mix(0.82, 1.0, band);                    // 楼板线
		vec3 detail = mix(fac, wc, win);
		vec3 avg = mix(fac, mix(glass, hole, cus.a < 0.75 ? 1.0 : 0.22), 0.3);
		c = mix(detail, avg, fade);
	}
	c *= lit;
	c *= mix(0.5, 1.0, clamp(hgt / 9.0, 0.0, 1.0));             // 街谷底部受遮挡
	float sh = menu_cloud_shadow(wp, CAMERA_POSITION_WORLD);
	c *= 1.0 - sh * 0.6;
	vec3 d = normalize(wp - CAMERA_POSITION_WORLD);
	ALBEDO = menu_fog(c, d) * exposure;
}
