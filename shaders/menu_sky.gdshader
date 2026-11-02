shader_type sky;
// 主菜单伪天空盒：飞空艇巡航高度的黄昏
//  上半球：天顶→地平线渐变、太阳盘 + 双层光晕、高空卷云（平面投影，随时间漂移）
//  地平线：积云塔剪影（按方位角生成高度，向阳面镶金边）+ 地平线雾带
//  下半球：近处云海（平面投影，云顶受光、云底蓝灰，有缝隙）→ 缝隙里依稀可见的废土地面（河道、城市残骸斑块），被厚重大气雾吞没
render_mode use_debanding;

uniform vec3 zenith : source_color = vec3(0.075, 0.13, 0.25);
uniform vec3 mid_sky : source_color = vec3(0.34, 0.42, 0.55);
uniform vec3 horizon : source_color = vec3(1.0, 0.66, 0.42);
uniform vec3 sun_col : source_color = vec3(1.0, 0.78, 0.5);
uniform vec3 haze_col : source_color = vec3(0.86, 0.6, 0.46);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.86, 0.7);
uniform vec3 cloud_shade : source_color = vec3(0.36, 0.38, 0.5);
uniform vec3 ground_a : source_color = vec3(0.27, 0.24, 0.21);
uniform vec3 ground_b : source_color = vec3(0.13, 0.125, 0.13);
uniform float cloud_cover = 0.56;
uniform float exposure = 0.72;
uniform float drift = 0.012;
// 云下城市：战区地图正交俯拍贴图（360m 一块），按格随机选图 / 旋转 / 镜像铺满地面
uniform sampler2D map0 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D map1 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D map2 : source_color, filter_linear_mipmap, repeat_disable;
uniform float altitude = 260.0;     // 飞空艇离地高度（米）
uniform float tile_m = 360.0;       // 一张地图的边长（米）
uniform float ground_speed = 7.0;   // 地面向船尾流过的速度（米/秒）

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, int oct) {
	float v = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < oct; i++) {
		v += a * vnoise(p);
		p = r * p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// 云海密度（平面坐标）
float sea(vec2 p) {
	float n = fbm(p * 0.9, 6);
	float big = fbm(p * 0.22 + vec2(3.0, 7.0), 3);
	return smoothstep(cloud_cover - 0.08, cloud_cover + 0.18, n * 0.65 + big * 0.55);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 L = normalize(LIGHT0_DIRECTION);
	float sd = max(dot(d, L), 0.0);
	float t = TIME * drift;
	float y = d.y;

	// ---- 天空渐变
	float yy = clamp(y, 0.0, 1.0);
	vec3 col = mix(horizon, mid_sky, smoothstep(0.0, 0.18, yy));
	col = mix(col, zenith, smoothstep(0.12, 0.75, yy));
	// 向阳侧地平线更暖更亮
	float az_sun = pow(max(dot(normalize(vec3(d.x, 0.0, d.z) + 1e-4), normalize(vec3(L.x, 0.0, L.z) + 1e-4)), 0.0), 3.0);
	col += sun_col * az_sun * 0.45 * exp(-yy * 6.0);
	// 光晕
	col += sun_col * (pow(sd, 6.0) * 0.35 + pow(sd, 60.0) * 0.6);

	if (AT_CUBEMAP_PASS) {
		vec3 c2 = y > 0.0 ? col : mix(haze_col * 0.8, cloud_shade, clamp(-y * 3.0, 0.0, 1.0));
		COLOR = c2;
	} else {
		// ---- 高空卷云
		if (y > 0.0) {
			vec2 cp = d.xz / (y + 0.06) * 0.55 + vec2(t * 2.0, t * 0.6);
			vec2 sp = cp * vec2(0.35, 1.6);
			float ci = fbm(sp + fbm(cp * 0.7, 3) * 1.4, 5);
			ci = smoothstep(0.52, 0.85, ci) * smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.55, 0.9, y));
			vec3 cc = mix(cloud_lit * 0.95, sun_col * 1.25, pow(sd, 4.0));
			col = mix(col, cc, ci * 0.55);
			// 太阳盘（被卷云遮淡）
			float disc = smoothstep(0.99955, 0.99975, dot(d, L));
			col += sun_col * disc * 14.0 * (1.0 - ci * 0.7);
		}

		// ---- 下半球：云海 + 地面
		if (y < 0.02) {
			float dn = max(-y, 0.004);
			// 云海平面（相对高度 1）
			vec2 sp = d.xz / dn * 0.9 + vec2(t * 3.5, t * 1.2);
			float dens = sea(sp);
			// 受光：向太阳方向错位采样，差值即"迎光面"
			vec2 toL = normalize(L.xz + 1e-4) * 0.08;
			float dens2 = sea(sp + toL);
			float lit = clamp(0.55 + (dens - dens2) * 2.6, 0.0, 1.0);
			float top = fbm(sp * 3.1, 4);
			vec3 cl = mix(cloud_shade, cloud_lit, lit * 0.75 + top * 0.35);
			cl *= mix(0.55, 1.0, smoothstep(0.0, 0.7, dens));   // 云缘较暗，显出厚度
			cl = mix(cl, sun_col * 1.15, pow(sd, 10.0) * 0.6 * lit);
			// 地面：真实米制坐标
			vec2 gm = d.xz / dn * altitude + vec2(TIME * ground_speed, TIME * ground_speed * 0.3);
			vec2 gp = gm / 2400.0;
			float g1 = fbm(gp * 1.3, 5);
			float g2 = fbm(gp * 7.0, 3);
			vec3 gc = mix(ground_b, ground_a, smoothstep(0.35, 0.7, g1));
			float riv = abs(fbm(gp * 0.9 + 11.0, 4) - 0.5);
			gc = mix(gc, vec3(0.1, 0.12, 0.14), smoothstep(0.015, 0.0, riv) * 0.8);
			gc *= 0.8 + g2 * 0.4;
			// 城市遗迹贴图
			vec2 tg = gm / tile_m;
			vec2 cell = floor(tg);
			vec2 uv = fract(tg);
			float hc = hash(cell + 0.5);
			float hr = hash(cell + 7.3);
			float urban = smoothstep(0.3, 0.45, fbm(tg * 0.23 + 2.0, 3));   // 城区成片出现，郊外是荒野
			if (hr < 0.25) uv = vec2(1.0 - uv.y, uv.x);
			else if (hr < 0.5) uv = 1.0 - uv;
			else if (hr < 0.75) uv = vec2(uv.y, 1.0 - uv.x);
			if (hash(cell + 3.1) < 0.5) uv.x = 1.0 - uv.x;
			uv = mix(vec2(0.03), vec2(0.97), uv);   // 裁掉贴图边框
			vec2 gx = dFdx(tg);
			vec2 gy = dFdy(tg);
			vec3 mc = hc < 0.34 ? textureGrad(map0, uv, gx, gy).rgb : (hc < 0.67 ? textureGrad(map1, uv, gx, gy).rgb : textureGrad(map2, uv, gx, gy).rgb);
			float lum = dot(mc, vec3(0.3, 0.55, 0.15));
			mc = mix(vec3(lum) * vec3(1.02, 0.98, 0.92), mc, 0.45) * 0.85;                               // 降饱和，像高空看下去的灰败城市
			vec2 eb = min(uv, 1.0 - uv);
			float seam = smoothstep(0.0, 0.05, min(eb.x, eb.y));               // 拼缝处过渡回荒野
			gc = mix(gc, mc, urban * mix(0.35, 1.0, seam));
			// 地面大气雾：越靠近地平线越被吞没，整体只"依稀可见"
			float gfog = 1.0 - exp(-1.0 / dn * 0.035);
			vec3 ground = mix(gc, mix(haze_col, vec3(0.45, 0.47, 0.56), 0.55) * 0.7, clamp(0.15 + gfog * 0.62, 0.0, 1.0));
			// 云缝里看地面；云海本身也随距离雾化
			vec3 below = mix(ground, cl, dens);
			float sfog = 1.0 - exp(-1.0 / dn * 0.035);
			below = mix(below, mix(haze_col, horizon, 0.5), clamp(sfog, 0.0, 1.0));
			col = mix(below, col, smoothstep(-0.006, 0.02, y));
		}

		// ---- 地平线积云塔
		float az = atan(d.x, d.z);
		float h = fbm(vec2(az * 3.2 + t * 0.4, 1.7), 5);
		float tower = pow(max(h - 0.38, 0.0), 1.5) * 0.55 + fbm(vec2(az * 14.0, 4.0), 3) * 0.012;
		float yb = y + 0.015;
		if (yb < tower && yb > -0.03) {
			float k = clamp(yb / max(tower, 1e-4), 0.0, 1.0);
			float edge = smoothstep(0.0, 0.018, tower - yb);
			float puff = fbm(vec2(az * 40.0, yb * 60.0), 4);
			vec3 tc = mix(cloud_shade * 1.1, cloud_lit, k * 0.7 + puff * 0.3);
			tc += sun_col * az_sun * (0.35 + (1.0 - edge) * 0.8);
			float far_fog = 0.35;
			tc = mix(tc, haze_col, far_fog);
			col = mix(col, tc, smoothstep(0.0, 1.0, edge + 0.25) * 0.92);
		}
		// 地平线雾带
		col = mix(col, haze_col * 1.05, exp(-abs(y) * 38.0) * 0.55);
	}
	COLOR = col * exposure;
}
