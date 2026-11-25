shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// 体积感写实烟尘着色器：柔和羽化边缘 + 世界太阳定向散射 + 生命周期游丝侵蚀消散 + 深度软融合。
// cloud_tex 通道约定（线性数据）：
//   R = 多瓣积云高度场（提供柔和立体明暗）
//   G = 域扭曲 FBM 侵蚀噪声（消散时化作空气感游丝）
//   B = 次级细卷云纹理（内部层次与柔光透射）
//   A = 宽羽化云团外廓遮罩（杜绝生硬剪影或方形边界）

global uniform vec3 sun_dir_world;

uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float soft_depth : hint_range(0.0, 5.0) = 1.35;
uniform float sun_strength : hint_range(0.0, 1.5) = 0.78;
uniform vec3 sun_tint : source_color = vec3(0.98, 0.94, 0.88);
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.44, 0.48);
uniform float erosion_softness : hint_range(0.1, 0.9) = 0.56;
uniform float density_boost : hint_range(0.3, 1.8) = 0.88;

varying vec2 v_view_pos;
varying float v_rot;

void vertex() {
	float ang = INSTANCE_CUSTOM.x;
	float ca = cos(ang);
	float sa = sin(ang);

	mat4 mat_world = mat4(
		normalize(INV_VIEW_MATRIX[0]),
		normalize(INV_VIEW_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]),
		MODEL_MATRIX[3]
	);
	mat_world = mat_world * mat4(
		vec4(ca, -sa, 0.0, 0.0),
		vec4(sa,  ca, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);

	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	v_view_pos = vec2(ca * q.x + sa * q.y, -sa * q.x + ca * q.y);
	v_rot = ang;
}

void fragment() {
	vec2 uv = UV;
	vec4 t = texture(cloud_tex, uv);
	float core = t.r;
	float erode_n = t.g;
	float detail = t.b;
	float mask = t.a;

	float r2 = dot(v_view_pos, v_view_pos);
	float life_a = clamp(COLOR.a, 0.0, 1.0);
	if (life_a <= 0.002 || mask <= 0.002 || r2 >= 0.995) {
		discard;
	}

	// 1. 柔和 3D 云团法线（低梯度保持空气绒雾感，避免雕塑粘土感）
	float eps = 0.032;
	float hx = texture(cloud_tex, uv + vec2(eps, 0.0)).r - core;
	float hy = texture(cloud_tex, uv - vec2(0.0, eps)).r - core;
	vec2 grad_local = vec2(-hx, -hy) * 1.75;
	float ca = cos(v_rot);
	float sa = sin(v_rot);
	vec2 grad_view = vec2(ca * grad_local.x + sa * grad_local.y, -sa * grad_local.x + ca * grad_local.y);

	float nz = sqrt(max(0.14, 1.0 - min(r2, 0.86)));
	vec3 n_view = normalize(vec3(v_view_pos * 0.65, nz) + vec3(grad_view, 0.0));
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(n_view, 0.0)).xyz);

	// 2. 世界太阳柔和包络散射 + 冷天光暗部 + 薄边透射银边
	vec3 sun_d = length(sun_dir_world) > 1e-3 ? normalize(sun_dir_world) : normalize(vec3(0.45, 0.62, 0.64));
	float ndl = dot(n_world, sun_d);
	float sun_lit = smoothstep(-0.55, 0.85, ndl);
	float sky_lit = clamp(n_world.y * 0.5 + 0.5, 0.0, 1.0);
	float thin = clamp(1.0 - core * 0.85, 0.0, 1.0);
	float silver_rim = thin * smoothstep(-0.10, 0.90, ndl) * 0.24;
	float crease_ao = mix(0.80, 1.08, clamp(core * 0.45 + detail * 0.55, 0.0, 1.0));

	vec3 lit = mix(shadow_tint * vec3(0.88, 0.94, 1.06), sun_tint * 1.06, clamp(sun_lit * 0.66 + sky_lit * 0.34, 0.0, 1.0));
	lit = lit * crease_ao + sun_tint * silver_rim;
	ALBEDO = COLOR.rgb * mix(vec3(1.0), lit, clamp(sun_strength * 1.15, 0.0, 1.0));

	// 3. 更宽空气羽化 + 有机卷云游丝侵蚀消散（彻底消除离散平灰圆片感）
	float wisp = erode_n * 0.58 + detail * 0.42;
	float soft_shape = pow(mask, 1.65) * mix(0.44, 1.24, wisp);
	float thresh = mix(0.68, 0.04, clamp(life_a * 1.12, 0.0, 1.0));
	float eroded = smoothstep(thresh, thresh + erosion_softness * 1.15, soft_shape + wisp * 0.20);
	float radial_feather = smoothstep(0.98, 0.22, sqrt(r2));
	float alpha = soft_shape * eroded * radial_feather * life_a * density_boost * 0.84;

	// 4. 深度软过渡：无缝融入地面与机甲腿部
	if (soft_depth > 0.001) {
		float raw_depth = texture(depth_tex, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth * 2.0 - 1.0);
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
#endif
		vec4 view_scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view_scene.xyz /= max(abs(view_scene.w), 1e-5) * sign(view_scene.w);
		float depth_diff = VERTEX.z - view_scene.z;
		alpha *= smoothstep(0.0, soft_depth, depth_diff);
	}

	ALPHA = clamp(alpha, 0.0, 0.64);
}
