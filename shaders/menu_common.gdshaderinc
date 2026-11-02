// 主菜单天空 / 云海 / 云下城市共用的噪声与雾（与 menu_sky.gdshader 完全一致，保证 3D 云层、地面与天空盒无缝衔接）
uniform vec3 sun_col : source_color = vec3(1.0, 0.78, 0.5);
uniform vec3 haze_col : source_color = vec3(0.86, 0.6, 0.46);
uniform vec3 horizon : source_color = vec3(1.0, 0.66, 0.42);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.86, 0.7);
uniform vec3 cloud_shade : source_color = vec3(0.36, 0.38, 0.5);
uniform float cloud_cover = 0.56;
uniform float exposure = 0.72;
uniform float drift = 0.012;
uniform vec3 sun_dir = vec3(0.43, 0.21, -0.87);
uniform float cloud_y = -80.0;   // 3D 云海层高度（世界 y）

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


// 与天空盒相同的大气雾：d 为视线方向
vec3 menu_fog(vec3 c, vec3 d) {
	float dn = max(-d.y, 0.004);
	float gfog = 1.0 - exp(-1.0 / dn * 0.035);
	c = mix(c, mix(haze_col, vec3(0.45, 0.47, 0.56), 0.55) * 0.7, clamp(0.08 + gfog * 0.62, 0.0, 1.0));
	float sfog = 1.0 - exp(-1.0 / dn * 0.035);
	return mix(c, mix(haze_col, horizon, 0.5), clamp(sfog, 0.0, 1.0));
}

// ---- 体积云（真正的三维密度场，menu_cloudsea 光线步进 + 地面云影共用） ----
uniform float cloud_top = -50.0;     // 云层顶（世界 y）
uniform float cloud_bot = -150.0;    // 云层底
uniform vec2 cloud_wind = vec2(-5.0, 1.2);  // 云随风漂移（米/秒），与地面流向一致

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), u.x), mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), u.x), u.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), u.x), mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), u.x), u.y), u.z);
}
// 覆盖率（水平）：决定哪里有云团、云团多高
float cloud_cov(vec2 xz) {
	vec2 q = xz - cloud_wind * TIME;
	float n = fbm(q * 0.0021, 4) * 0.7 + fbm(q * 0.00055 + vec2(3.0, 7.0), 2) * 0.55;
	return smoothstep(cloud_cover - 0.06, cloud_cover + 0.22, n);
}
// 三维密度：底部平、顶部翻滚，用三维噪声侵蚀边缘
float cloud_dens(vec3 p, float cov) {
	float h = (p.y - cloud_bot) / (cloud_top - cloud_bot);
	if (h < 0.0 || h > 1.0 || cov < 0.01) return 0.0;
	float top = mix(0.35, 1.0, cov);
	float shape = smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(top - 0.32, top, h));
	vec3 q = p - vec3(cloud_wind.x, 0.0, cloud_wind.y) * TIME * 1.3;
	float det = vnoise3(q * 0.018) * 0.6 + vnoise3(q * 0.047 + 11.0) * 0.28 + vnoise3(q * 0.11 + 5.0) * 0.12;
	return clamp(cov * shape * 1.6 - det * (0.62 + 0.45 * h) , 0.0, 1.0);
}

// 云影：沿太阳方向把地面点投到云层中部，按同一覆盖率取值
float menu_cloud_shadow(vec3 wp, vec3 cam) {
	vec3 L = normalize(sun_dir);
	float ym = mix(cloud_bot, cloud_top, 0.4);
	vec3 pc = wp + L * ((ym - wp.y) / max(L.y, 0.05));
	return cloud_cov(pc.xz);
}
