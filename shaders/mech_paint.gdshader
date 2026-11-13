shader_type spatial;
// 写实工业与机甲 PBR 着色器：支持独立网格 (tint_mode 0)、MultiMesh (tint_mode 1) 与静态分块合并网格 (tint_mode 2)。
// 通过对象局部米制坐标 (lpos/lnrm) 做三平面贴图与法线映射，任意旋转或合并后的建筑墙板、钢梁、屋面纹理均严格对齐不扭曲。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, ensure_correct_normals;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float metal_base : hint_range(0.0, 1.0) = 0.15;
uniform float rough_base : hint_range(0.0, 1.0) = 0.6;
uniform float wear : hint_range(0.0, 1.0) = 0.5;       // 边缘掉漆强度
uniform float scratches : hint_range(0.0, 1.0) = 0.35; // 面上划痕
uniform float dust : hint_range(0.0, 1.0) = 0.3;       // 朝上表面积灰
uniform float grime : hint_range(0.0, 1.0) = 0.5;      // 底部泥污 / 缝隙暗化
uniform float rust : hint_range(0.0, 1.0) = 0.25;      // 锈迹流痕
uniform float panel_scale = 1.6;                        // 面板接缝密度（0 关闭）
uniform float stripes = 0.0;                            // 1 = 黄黑警示条纹
uniform float detail_scale = 1.0;
uniform int tint_mode = 0;                              // 0 直接底色；1 乘 MultiMesh INSTANCE_CUSTOM；2 乘合并网格顶点色 gba
uniform float takes_damage = 0.0;                       // 1 = 随机甲受损程度出现烧蚀/弹痕
uniform float metal_wear : hint_range(0.0, 1.0) = 1.0;  // 1 = 金属底材（掉漆露钢）；0 = 混凝土/砖石
uniform float roof_uv = 0.0;                            // 1 = 朝上斜面按 (z, x) 投影，令屋面锁边顺坡向排布
global uniform float mech_damage;
uniform vec4 bare_metal : source_color = vec4(0.66, 0.67, 0.69, 1.0);
uniform vec4 dust_color : source_color = vec4(0.48, 0.43, 0.36, 1.0);
uniform vec4 rust_color : source_color = vec4(0.32, 0.16, 0.08, 1.0);
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_albedo_tex = 0.0;
uniform float albedo_tex_scale = 0.24;
uniform float albedo_tex_strength : hint_range(0.0, 1.0) = 0.78;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.55;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;
varying vec3 wnrm;
varying vec3 rot_x;
varying vec3 rot_y;
varying vec3 rot_z;
varying float edge;
varying vec3 tint;

vec3 q_rot(vec4 q, vec3 v) {
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 sx = MODEL_MATRIX[0].xyz;
	vec3 sy = MODEL_MATRIX[1].xyz;
	vec3 sz = MODEL_MATRIX[2].xyz;
	vec3 scale = max(vec3(length(sx), length(sy), length(sz)), vec3(1e-4));
	mat3 rot_m = mat3(sx / scale.x, sy / scale.y, sz / scale.z);
	if (tint_mode == 2 && CUSTOM0.w > 0.5) {
		// 静态分块合并网格：从 UV/UV2/CUSTOM0 读取对象局部米制坐标与法线，从 CUSTOM1 读取局部旋转四元数
		lpos = vec3(UV.x, UV.y, UV2.x);
		lnrm = normalize(CUSTOM0.xyz);
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		wnrm = normalize(rot_m * NORMAL);
		float flip_s = CUSTOM0.w > 1.5 ? -1.0 : 1.0;
		rot_x = rot_m * q_rot(CUSTOM1, vec3(1.0, 0.0, 0.0));
		rot_y = rot_m * q_rot(CUSTOM1, vec3(0.0, 1.0, 0.0));
		rot_z = rot_m * (q_rot(CUSTOM1, vec3(0.0, 0.0, 1.0)) * flip_s);
	} else {
		lpos = VERTEX * scale;
		lnrm = normalize(NORMAL / scale);
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		wnrm = normalize(rot_m * lnrm);
		rot_x = rot_m[0];
		rot_y = rot_m[1];
		rot_z = rot_m[2];
	}
	edge = 1.0 - COLOR.r;
	tint = tint_mode == 1 ? srgb_to_linear(INSTANCE_CUSTOM.rgb) : (tint_mode == 2 ? srgb_to_linear(COLOR.gba) : vec3(1.0));
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(6.0));
	return w / (w.x + w.y + w.z + 1e-5);
}

float tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy).r * w.x + texture(t, p.xz).r * w.y + texture(t, p.xy).r * w.z;
}

void fragment() {
	vec3 n_loc = normalize(lnrm);
	vec3 w = tri_w(n_loc);
	vec3 p = lpos * detail_scale;
	float n_lo = tri(noise_lo, p * 0.35 + wpos * 0.02, w);
	float macro_w = tri(noise_lo, wpos * 0.032 + vec3(1.7, 0.4, 2.9), w);
	float n_mid = tri(noise_lo, p * 1.05 + vec3(0.41, 0.17, 0.73), w);
	float n_hi = tri(noise_hi, p * 2.4, w);
	float n_sc = tri(noise_hi, p * vec3(9.5, 1.1, 9.5), w);

	// 墙面立面令 -p.y 对应贴图 +v（向下），保证砖缝阴影、波纹板搭接锈水与混凝土孔流痕均严格顺重力朝下
	vec2 uv_x = vec2(p.z, -p.y);
	vec2 uv_y = roof_uv > 0.5 ? vec2(p.z, p.x) : vec2(p.x, p.z);
	vec2 uv_z = vec2(p.x, -p.y);

	// 轧制钢板与重工漆面的微妙色阶斑驳 + 世界空间宏观风化打破重复感
	vec3 col = base_color.rgb * tint * (0.91 + 0.15 * n_lo) * (0.94 + 0.10 * n_hi) * (0.91 + 0.18 * macro_w);
	float tex_luma = 0.7;
	if (use_albedo_tex > 0.5) {
		float ts = albedo_tex_scale * 1.8;
		vec3 at = texture(albedo_tex, uv_x * ts).rgb * w.x
				+ texture(albedo_tex, uv_y * ts).rgb * w.y
				+ texture(albedo_tex, uv_z * ts).rgb * w.z;
		tex_luma = dot(at, vec3(0.333));
		// 中性校准：贴图 sRGB 均值约 0.82（线性约 0.64），乘 1.52 使平均亮度严格保持 1.0 不发黑不发白
		col *= mix(vec3(1.0), at * 1.52, albedo_tex_strength);
	}
	float met = metal_base;
	float rough = rough_base * (0.86 + 0.24 * n_hi - 0.08 * n_mid + (0.65 - tex_luma) * 0.16 * use_albedo_tex);

	// 警示条纹（带做旧磨蚀感）
	if (stripes > 0.5) {
		float s = fract((p.x + p.y + p.z) * 2.2);
		float sw = max(fwidth(s), 1e-4);
		float band = min(smoothstep(0.5 - sw, 0.5 + sw, s), 1.0 - smoothstep(1.0 - sw * 1.5, 1.0, s));
		col = mix(vec3(0.06, 0.06, 0.065), vec3(0.86, 0.60, 0.11), band) * (0.84 + 0.24 * n_lo);
	}

	// 错缝装甲板 / 预制墙板接缝：沿主投影平面生成错位工业拼板线 + 接缝藏污暗化
	float seam = 0.0;
	float seam_ao = 0.0;
	vec2 seam_n = vec2(0.0);
	if (panel_scale > 0.0) {
		vec2 uv = w.x > 0.5 ? uv_x : (w.y > 0.5 ? uv_y : uv_z);
		vec2 g = uv * panel_scale + vec2(0.13, 0.31);
		float row_id = floor(g.y);
		g.x += mod(row_id, 2.0) * 0.37;
		vec2 fg = fract(g) - 0.5;
		vec2 f = abs(fg);
		vec2 fw = max(fwidth(g), vec2(1e-4));
		vec2 dist = 0.5 - f;
		float lw = 0.0055;
		float lx = 1.0 - smoothstep(lw, lw + fw.x * 1.5, dist.x);
		float ly = 1.0 - smoothstep(lw, lw + fw.y * 1.5, dist.y);
		float cell_h = fract(sin(dot(floor(g), vec2(127.1, 311.7))) * 43758.5453);
		lx *= step(0.26, cell_h);
		// 微妙单块面板明暗差，打破大面积平面单调感
		float panel_tone = (cell_h - 0.5) * mix(0.055, 0.075, metal_wear);
		col *= 1.0 + panel_tone;
		float fade = clamp(1.0 - (max(fw.x, fw.y) - 0.015) * 14.0, 0.0, 1.0);
		seam = max(lx, ly) * fade;
		float halo_x = (1.0 - smoothstep(lw, lw + 0.048, dist.x)) * step(0.26, cell_h);
		float halo_y = 1.0 - smoothstep(lw, lw + 0.048, dist.y);
		seam_ao = max(halo_x, halo_y) * fade * (0.45 + 0.55 * n_lo);
		seam_n = vec2(lx * sign(fg.x), ly * sign(fg.y)) * fade * mix(0.22, 0.36, metal_wear);
		// 非金属(混凝土/岩面)保持柔和模板缝而不出现生硬黑线网格
		float seam_dark = mix(0.22, 0.68, metal_wear);
		float halo_dark = mix(0.06, 0.15, metal_wear);
		col *= 1.0 - seam * seam_dark - seam_ao * halo_dark;
		rough = mix(rough, 0.92, seam);
	}

	// 缝隙/底部接地暗化与下表面机械油泥
	float low = (1.0 - smoothstep(0.0, 2.1, wpos.y)) * (1.0 - smoothstep(0.35, 0.75, abs(wnrm.y)));
	float under = smoothstep(0.25, 0.85, -wnrm.y) * metal_wear;
	col *= 1.0 - grime * (0.38 * low * (0.6 + 0.6 * n_lo) + 0.22 * under);
	col = mix(col, dust_color.rgb * 0.64, grime * low * 0.36 * smoothstep(0.4, 0.7, n_lo));

	// 锈迹与雨水污渍垂向流痕
	float vert = 1.0 - abs(wnrm.y);
	float streak = smoothstep(0.54, 0.86, n_sc) * vert * smoothstep(0.34, 0.68, n_lo);
	col = mix(col, rust_color.rgb, rust * streak * 0.78);
	rough = mix(rough, 0.94, rust * streak);
	float oil = smoothstep(0.72, 0.94, tri(noise_hi, p * vec3(7.0, 0.65, 7.0) + 0.5, w)) * vert * metal_wear * grime;
	col *= 1.0 - oil * 0.28;
	rough = mix(rough, 0.36, oil * 0.55);

	// 三层真实边缘磨损：漆面摩擦抛光 → 深色防锈底漆 → 破碎裸钢/粗骨料
	float chipn = n_hi * 0.72 + n_mid * 0.42 + n_lo * 0.28;
	float chip_mask = edge * smoothstep(0.92 - wear * 0.38, 1.02 - wear * 0.38, chipn);
	float scr = smoothstep(0.855, 0.895, n_sc) * scratches * (1.0 - seam) * smoothstep(0.48, 0.72, n_lo);
	float wm = max(chip_mask, scr);
	float worn = smoothstep(0.42, 0.72, wm);
	float primer = clamp(edge * smoothstep(0.78 - wear * 0.36, 0.91 - wear * 0.36, chipn) - worn, 0.0, 1.0);
	vec3 primer_col = mix(col * 0.52, vec3(0.14, 0.12, 0.11), 0.65 * metal_wear + 0.25);
	col = mix(col, primer_col, primer * 0.78);
	vec3 exposed_metal = bare_metal.rgb * (0.78 + 0.34 * n_hi);
	vec3 exposed_stone = bare_metal.rgb * (0.88 + 0.22 * n_hi);
	col = mix(col, mix(exposed_stone, exposed_metal, metal_wear), worn);
	met = mix(met, mix(met, 0.92, metal_wear), worn);
	float worn_rough = mix(0.94, 0.25 + 0.18 * n_hi, metal_wear);
	rough = mix(rough, 0.82, primer * 0.5);
	rough = mix(rough, worn_rough, worn);
	rough *= 1.0 - edge * 0.14 * metal_wear;

	// 战损：烧蚀焦黑 + 更多掉漆
	float dmg = clamp(mech_damage * takes_damage, 0.0, 1.0);
	if (dmg > 0.01) {
		float n_sc2 = tri(noise_lo, p * 1.3 + vec3(3.1, 7.7, 1.3), w);
		float bv = n_sc2 + n_hi * 0.15;
		float heat = smoothstep(0.84 - dmg * 0.32, 0.98 - dmg * 0.32, bv);
		float burn = smoothstep(0.93 - dmg * 0.32, 1.03 - dmg * 0.32, bv);
		col = mix(col, col * vec3(0.55, 0.42, 0.32), heat * 0.8);
		col = mix(col, vec3(0.03, 0.028, 0.025), burn * 0.92);
		rough = mix(rough, 0.95, heat);
		met = mix(met, 0.0, heat);
		float hn = tri(noise_hi, p * 7.0 + vec3(5.0), w);
		float hole = smoothstep(0.8 - dmg * 0.06, 0.82 - dmg * 0.06, hn) * step(0.45, n_sc2) * step(0.2, dmg);
		col = mix(col, vec3(0.01), hole);
		rough = mix(rough, 1.0, hole);
	}

	// 积灰：朝上的面仅轻微留灰，保留金属与屋面颜色对比
	float up = smoothstep(0.62, 0.96, wnrm.y);
	float d = up * dust * smoothstep(0.58, 0.86, n_lo + n_hi * 0.2);
	col = mix(col, dust_color.rgb, d * 0.28);
	rough = mix(rough, 0.84, d * 0.45);
	met = mix(met, met * 0.55, d * 0.45);

	// 连续三平面法线扰动（在视图空间直接合成 NORMAL，消除合批圆柱/斜坡切线阶跃摩尔伪影）
	float ns = use_albedo_tex > 0.5 ? (albedo_tex_scale * 1.8) : 1.35;
	vec3 nm_x = texture(normal_tex, uv_x * ns).rgb * 2.0 - 1.0;
	vec3 nm_y = texture(normal_tex, uv_y * ns).rgb * 2.0 - 1.0;
	vec3 nm_z = texture(normal_tex, uv_z * ns).rgb * 2.0 - 1.0;
	float uv_fw = max(length(fwidth(uv_x * ns)) * w.x, max(length(fwidth(uv_y * ns)) * w.y, length(fwidth(uv_z * ns)) * w.z));
	float nfade = clamp(1.0 - uv_fw * 1.75, 0.0, 1.0);
	float n_amt = clamp((normal_strength + seam * 0.35 + worn * 0.20) * nfade, 0.0, 1.25);
	vec2 tx = nm_x.xy * n_amt + (w.x > 0.5 ? seam_n : vec2(0.0));
	vec2 ty = nm_y.xy * n_amt + (w.y > 0.5 ? seam_n : vec2(0.0));
	vec2 tz = nm_z.xy * n_amt + (w.z > 0.5 ? seam_n : vec2(0.0));
	vec3 p_x = vec3(0.0, tx.y, tx.x);
	vec3 p_y = roof_uv > 0.5 ? vec3(-ty.y, 0.0, ty.x) : vec3(ty.x, 0.0, -ty.y);
	vec3 p_z = vec3(tz.x, tz.y, 0.0);
	vec3 dp_loc = p_x * w.x + p_y * w.y + p_z * w.z;
	dp_loc -= n_loc * dot(dp_loc, n_loc);
	mat3 v_rot = mat3(rot_x, rot_y, rot_z);
	vec3 w_pert = normalize(wnrm + v_rot * dp_loc);
	NORMAL = normalize((VIEW_MATRIX * vec4(w_pert, 0.0)).xyz);

	ALBEDO = col;
	METALLIC = met;
	vec3 dn = fwidth(NORMAL);
	float var_n = dot(dn, dn);
	float r2 = rough * rough + min(1.2 * var_n, 0.22);
	ROUGHNESS = clamp(sqrt(r2), 0.08, 1.0);

	float tex_ao = use_albedo_tex > 0.5 ? clamp((0.62 - tex_luma) * 0.65, 0.0, 0.32) : 0.0;
	SPECULAR = mix(0.50, 0.88, worn * metal_wear);
	AO = clamp(1.0 - tex_ao - seam * mix(0.18, 0.58, metal_wear) - seam_ao * mix(0.08, 0.22, metal_wear) - primer * 0.28 - low * grime * 0.35 - under * 0.18, 0.22, 1.0);
	AO_LIGHT_AFFECT = 0.62;
	CLEARCOAT = (1.0 - worn) * (1.0 - d) * (1.0 - rust * streak) * metal_wear * clamp(0.72 - rough_base, 0.0, 0.5) * 0.38;
	CLEARCOAT_ROUGHNESS = clamp(0.26 + min(1.5 * var_n, 0.3), 0.12, 1.0);
}
