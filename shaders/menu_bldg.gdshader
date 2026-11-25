shader_type spatial;
// 云下城市楼体：按真实尺寸算楼层与窗格（层高 3.3m、窗距 2.8m），玻璃反天光、部分窗洞烧空；
// 屋顶有女儿墙边、污渍；残楼窗洞全黑；抗锯齿盒滤波 + 远景平滑退火，根除亚像素闪烁。
render_mode unshaded, shadows_disabled, fog_disabled;
#include "res://shaders/menu_common.gdshaderinc"
uniform float ground_y = -260.0;
varying highp vec3 wp;
varying vec3 wn;
varying vec3 ln;
varying highp vec3 lp;
varying vec3 bsz;
varying vec4 cus;
varying highp vec2 bldg_seed;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	ln = NORMAL;
	bsz = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * bsz;
	cus = INSTANCE_CUSTOM;
	bldg_seed = vec2(MODEL_MATRIX[3].x * 0.031 + cus.r * 11.3, MODEL_MATRIX[3].z * 0.037 + cus.g * 17.1);
}

void fragment() {
	vec3 L = normalize(sun_dir);
	float ndl = max(dot(wn, L), 0.0);
	float hgt = wp.y - ground_y;
	float side = step(abs(ln.y), 0.5);
	float u = side > 0.5 ? dot(lp.xz, vec2(-ln.z, ln.x)) : lp.x;
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
		float max_fw = max(fw.x, fw.y);
		// 窗格在屏幕上小于约 6~8 像素时平滑退火至立面整体平均色，彻底消除亚像素摩尔纹与高频闪烁
		float fade = smoothstep(0.06, 0.22, max_fw);
		vec2 cell = floor(vec2(co, fl));
		vec2 f = fract(vec2(co, fl));

		// 盒式自适应滤波抗锯齿边界（防边缘硬跳变走样）
		vec2 aaw = clamp(fw * 1.5, vec2(0.02), vec2(0.28));
		float win_x = smoothstep(0.20 - aaw.x, 0.20 + aaw.x, f.x) * (1.0 - smoothstep(0.80 - aaw.x, 0.80 + aaw.x, f.x));
		float win_y = smoothstep(0.28 - aaw.y, 0.28 + aaw.y, f.y) * (1.0 - smoothstep(0.88 - aaw.y, 0.88 + aaw.y, f.y));
		float win = win_x * win_y * step(1.0, fl);

		// 每栋楼每个窗户网格拥有空间稳定的随机数，不随片元坐标浮动
		float rnd = hash(cell + bldg_seed);
		vec3 glass = mix(vec3(0.07, 0.08, 0.1), vec3(0.26, 0.28, 0.35), 0.25 + 0.35 * rnd) / max(lit, vec3(0.2));
		// 柔和高光反光，且随远景渐变自然衰减，避免单像素火花闪烁
		float glint = pow(ndl, 3.0) * smoothstep(0.88, 0.98, rnd) * 0.25 * (1.0 - fade);
		glass += sun_col * glint / max(lit, vec3(0.2));

		float broken = step(rnd, cus.a < 0.75 ? 1.0 : 0.22);
		vec3 hole = vec3(0.025) / max(lit, vec3(0.2));
		vec3 wc = mix(glass, hole, broken);

		float band_w = clamp(fw.y * 1.5, 0.02, 0.2);
		float band = smoothstep(0.04 - band_w, 0.04 + band_w, f.y) * (1.0 - smoothstep(0.96 - band_w, 0.96 + band_w, f.y));
		vec3 fac = c * mix(0.85, 1.0, band);

		vec3 detail = mix(fac, wc, win);
		// 远景统计期望平均色：平滑连续，无任何点阵跳变
		vec3 mean_win = mix(vec3(0.16, 0.18, 0.22) / max(lit, vec3(0.2)), hole, cus.a < 0.75 ? 1.0 : 0.22);
		vec3 avg = mix(fac, mean_win, 0.32);
		c = mix(detail, avg, fade);
	}
	c *= lit;
	c *= mix(0.5, 1.0, clamp(hgt / 9.0, 0.0, 1.0));             // 街谷底部受遮挡
	float sh = menu_cloud_shadow(wp, CAMERA_POSITION_WORLD);
	c *= 1.0 - sh * 0.6;
	vec3 d = normalize(wp - CAMERA_POSITION_WORLD);
	ALBEDO = menu_fog(c, d) * exposure;
}
