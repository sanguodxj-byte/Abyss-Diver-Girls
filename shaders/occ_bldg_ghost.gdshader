shader_type spatial;
// 整栋遮挡建筑平滑虚化 Pass 2：依托 Pass 1 写入的最外层深度做单层均匀半透明混合（零噪点、零重影、Forward+/Mobile 一致）。
// 使用克制的伪光照（unshaded 柔光半球 + 轻微太阳方向立体感 + 建筑轮廓菲涅尔勾边），避免正午强日照屋顶在半透明混合时发白抢戏、压过阴影中的实心机甲。
render_mode blend_mix, depth_draw_never, depth_test_default, cull_back, unshaded;

#include "res://shaders/occ_fade.gdshaderinc"

global uniform vec3 sun_dir_world;

uniform vec4 base_color : source_color = vec4(0.50, 0.49, 0.46, 1.0);
uniform int tint_mode = 0; // 0: 仅 base_color；1: 乘顶点色 COLOR.gba（chunk/prefab 涂装）；2: 乘顶点色 COLOR.rgb（StandardMaterial3D）
uniform float ghost_alpha : hint_range(0.0, 1.0) = 0.18;
uniform float rim_boost : hint_range(0.0, 0.5) = 0.22;

varying highp vec3 v_wpos;
varying vec3 v_wnrm;
varying vec3 v_tint;

vec3 occ_srgb_to_lin(vec3 c) {
	vec3 sc = max(c, vec3(0.0));
	return mix(pow((sc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), sc * (1.0 / 12.92), lessThan(sc, vec3(0.04045)));
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (tint_mode == 1) {
		v_tint = occ_srgb_to_lin(COLOR.gba);
	} else if (tint_mode == 2) {
		v_tint = COLOR.rgb;
	} else {
		v_tint = vec3(1.0);
	}
}

void fragment() {
	vec3 col = base_color.rgb * v_tint;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 soft_col = mix(col, vec3(lum) * vec3(0.92, 0.96, 1.02), 0.42);
	// 柔和低反差立体明暗：既保留楼体各立面/屋顶/设备的体积层次，又防止向阳屋顶过亮遮挡阴影里的玩家机甲
	vec3 sun_d = length(sun_dir_world) > 1e-3 ? normalize(sun_dir_world) : normalize(vec3(0.45, 0.62, 0.64));
	vec3 wn = normalize(v_wnrm);
	float sun_wrap = clamp(dot(wn, sun_d) * 0.42 + 0.58, 0.0, 1.0);
	float hemi = mix(0.68, 1.0, wn.y * 0.5 + 0.5);
	float shade = clamp(mix(0.32, 0.72, sun_wrap * hemi), 0.28, 0.74);

	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.4);
	ALBEDO = soft_col * shade + vec3(0.28, 0.33, 0.38) * fres * rim_boost;

	// 正对玩家机甲的视线核心处再平滑减淡（纯 Alpha 渐变，零颗粒），确保机甲与武器轮廓清晰醒目
	float a = ghost_alpha;
	if (ghost_alpha < 0.85) {
		float core_clear = occ_calc_fade(v_wpos, INV_VIEW_MATRIX[3].xyz, 1.0, 0.20);
		a = mix(ghost_alpha, ghost_alpha * 0.42, core_clear);
	}
	float base_h = smoothstep(0.18, 0.52, v_wpos.y);
	float fade_vis = smoothstep(0.02, 0.14, ghost_alpha);
	ALPHA = clamp((a + fres * rim_boost * 0.32 * fade_vis) * base_h, 0.0, 1.0);
}
