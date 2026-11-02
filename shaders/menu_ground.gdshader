shader_type spatial;
// 云下城市地面：每 360m 一格，按数据贴图选战区地图俯拍图（旋转 / 镜像），非城区格是荒野
render_mode unshaded, shadows_disabled, fog_disabled;
#include "res://shaders/menu_common.gdshaderinc"
uniform sampler2D map0 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D map1 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D map2 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D cells : filter_nearest, repeat_disable;   // r=地图 g=旋转 b=镜像 a=城区
uniform float offset_x = 0.0;
uniform int period = 16;
uniform int row0 = -10;
uniform int rows = 11;
uniform vec3 ground_a : source_color = vec3(0.27, 0.24, 0.21);
uniform vec3 ground_b : source_color = vec3(0.13, 0.125, 0.13);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec2 rot1i(vec2 q) { return vec2(-q.y, q.x); }   // 与 menu_city.gd 的 _rot1 互逆
void fragment() {
	vec2 g = wp.xz - vec2(offset_x, 0.0);
	vec2 gp = g / 2400.0;
	float g1 = fbm(gp * 1.3, 5);
	float g2 = fbm(gp * 7.0, 3);
	vec3 gc = mix(ground_b, ground_a, smoothstep(0.35, 0.7, g1));
	gc *= 0.8 + g2 * 0.4;
	vec2 cell = floor(g / 360.0 + 0.5);
	vec2 q = g - cell * 360.0;
	int ci = int(mod(cell.x, float(period)));
	int cj = int(cell.y) - row0;
	if (cj >= 0 && cj < rows) {
		vec4 cd = texelFetch(cells, ivec2(ci, cj), 0);
		if (cd.a > 0.5) {
			int k = int(round(cd.g * 3.0));
			vec2 s = q;
			for (int i = 0; i < 3; i++) { if (i < k) s = rot1i(s); }
			if (cd.b > 0.5) s.x = -s.x;
			vec2 uv = (s + 180.0) / 360.0;
			vec2 gx = dFdx(g) / 360.0;
			vec2 gy = dFdy(g) / 360.0;
			int m = int(round(cd.r * 2.0));
			vec3 mc = m == 0 ? textureGrad(map0, uv, gx, gy).rgb : (m == 1 ? textureGrad(map1, uv, gx, gy).rgb : textureGrad(map2, uv, gx, gy).rgb);
			mc *= 0.8 + fbm(g * 0.35, 3) * 0.4;           // 路面 / 地块细碎污渍
			vec2 eb = 180.0 - abs(q);
			float seam = smoothstep(0.0, 14.0, min(eb.x, eb.y));
			gc = mix(gc, mc, mix(0.4, 1.0, seam));
		}
	}
	// 大片焦痕 / 污渍，打破拼图感
	float burn = fbm(g / 260.0 + 5.0, 4);
	gc *= mix(0.62, 1.08, smoothstep(0.25, 0.75, burn));
	// 逆光：地面整体偏暗，阳光方向一侧略亮
	gc *= 1.0;
	float sh = menu_cloud_shadow(wp, CAMERA_POSITION_WORLD);
	gc *= 1.0 - sh * 0.62;
	vec3 d = normalize(wp - CAMERA_POSITION_WORLD);
	ALBEDO = menu_fog(gc, d) * exposure;
}
