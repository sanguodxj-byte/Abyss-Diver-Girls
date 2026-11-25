shader_type spatial;
// 《B.o.T》硬派军工写实 2K Trim Sheet v2 着色器（MECH_MODELING_STANDARD + BOT_VISUAL_STANDARD）
// 核心物理特性：
//   1. 电介质消光防化烤漆 (CARC, metallic ~0.03) vs 裸露均质冷轧钢导体 (metallic ~0.94) 严格物理分离；
//   2. 窄带三层硬边掉漆：军用面漆 → 暗红褐/锌黄防锈底漆圈 (Primer) → 高光冷钢棱线；
//   3. 四通道离线烘焙顶点数据驱动：R=(1-凸边曲率)、G=24-ray 光追 AO、B=解剖垂向与悬挑梯度、A=独立装甲板随机色差哈希；
//   4. 双尺度法线：2K Trim 切线空间法线 + 距离自适应消隐的 512px 铸钢砂眼/橘皮微表面法线 + Toksvig 抗高光闪烁；
//   5. 战区底盘泥沙积垢带与受 AO 遮蔽约束的自然天光折边反射。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx, ensure_correct_normals;

uniform vec4 base_color : source_color = vec4(0.45, 0.45, 0.42, 1.0);
uniform float metal_base : hint_range(0.0, 1.0) = 0.04;
uniform float rough_base : hint_range(0.0, 1.0) = 0.60;
uniform float wear : hint_range(0.0, 1.0) = 0.52;
uniform float rust : hint_range(0.0, 1.0) = 0.14;
uniform float grime : hint_range(0.0, 1.0) = 0.42;
uniform float dust : hint_range(0.0, 1.0) = 0.24;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.18;
uniform float detail_normal_scale : hint_range(1.0, 24.0) = 8.5;
uniform float detail_normal_str : hint_range(0.0, 1.5) = 0.44;
uniform float ao_strength : hint_range(0.0, 1.5) = 0.96;
uniform float raw_albedo : hint_range(0.0, 1.0) = 0.0;
uniform float takes_damage : hint_range(0.0, 1.0) = 0.0;
uniform float occ_exempt = 0.0;
uniform float occ_self_fade = 0.0;

uniform vec4 bare_metal : source_color = vec4(0.52, 0.55, 0.59, 1.0);
uniform vec4 primer_tint : source_color = vec4(0.22, 0.16, 0.13, 1.0);
uniform vec4 rust_color : source_color = vec4(0.34, 0.16, 0.08, 1.0);
uniform vec4 dust_color : source_color = vec4(0.56, 0.50, 0.41, 1.0);

uniform int camo_mode = 0;
uniform vec4 camo_col_b : source_color = vec4(0.28, 0.30, 0.24, 1.0);
uniform vec4 camo_col_c : source_color = vec4(0.16, 0.17, 0.16, 1.0);
uniform float camo_scale : hint_range(0.2, 6.0) = 1.35;

global uniform float mech_damage;
global uniform float weather_wet;
global uniform float weather_rain;

uniform sampler2D trim_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 lpos;
varying vec3 lnrm;
varying vec3 rot_x;
varying vec3 rot_y;
varying vec3 rot_z;
varying float v_edge;
varying float v_ao;
varying float v_grad;
varying float v_hash;

void vertex() {
	vec3 sx = MODEL_MATRIX[0].xyz;
	vec3 sy = MODEL_MATRIX[1].xyz;
	vec3 sz = MODEL_MATRIX[2].xyz;
	vec3 sc = max(vec3(length(sx), length(sy), length(sz)), vec3(1e-3));
	mat3 rot_m = mat3(sx / sc.x, sy / sc.y, sz / sc.z);
	rot_x = rot_m[0];
	rot_y = rot_m[1];
	rot_z = rot_m[2];
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lnrm = length(NORMAL) > 1e-4 ? normalize(NORMAL) : vec3(0.0, 1.0, 0.0);
	wnrm = normalize(rot_m * (NORMAL / sc));
	lpos = VERTEX * sc;
	v_edge = clamp(1.0 - COLOR.r, 0.0, 1.0);
	v_ao = clamp(COLOR.g, 0.08, 1.0);
	v_grad = COLOR.b;
	v_hash = COLOR.a;
}

void fragment() {
	vec3 ta = texture(trim_albedo, UV).rgb;
	vec3 orm = texture(trim_orm, UV).rgb;
	float t_ao = orm.r;
	float t_rough = orm.g;
	float t_chip = orm.b;

	// 1. 独立子装甲板色温/明度微差（兼容旧 GLB COLOR.a=1.0 时回退中性 0.5）
	float ph = (v_hash > 0.996) ? 0.5 : v_hash;
	float plate_var = (ph - 0.5) * 2.0; // [-1..1]
	float is_dielectric = 1.0 - smoothstep(0.35, 0.65, metal_base);

	// 2. 多尺度防克隆硝烟/油渍斑驳（复刻 B.o.T 大装甲面云雾状做旧肌理）
	float n_macro = texture(noise_lo, lpos.xy * 0.34 + lpos.zz * 0.27 + vec2(ph * 1.7, ph * 3.1)).r;
	float n_lo = texture(noise_lo, lpos.xz * 0.88 + lpos.yy * 0.62 + vec2(0.19, 0.47)).r;
	float n_hi = texture(noise_lo, lpos.xy * 2.85 + lpos.yz * 2.15 + vec2(0.37, 0.61)).r;
	float mottle = n_macro * 0.58 + n_lo * 0.42;

	vec3 bc = base_color.rgb;
	if (camo_mode > 0 && is_dielectric > 0.5 && raw_albedo < 0.5) {
		vec3 cp = lpos * camo_scale;
		if (camo_mode == 1) {
			vec3 tw = pow(abs(normalize(lnrm)), vec3(4.0));
			tw /= max(tw.x + tw.y + tw.z, 1e-4);
			vec2 ux = cp.zy * 0.44;
			vec2 uy = cp.xz * 0.44;
			vec2 uz = cp.xy * 0.44;
			float wp = texture(noise_lo, ux * 0.62 + vec2(0.13, 0.41)).r * tw.x
				+ texture(noise_lo, uy * 0.62 + vec2(0.29, 0.17)).r * tw.y
				+ texture(noise_lo, uz * 0.62 + vec2(0.53, 0.31)).r * tw.z;
			float dv = (wp - 0.5) * 0.36;
			float c1 = texture(noise_lo, ux + dv).r * tw.x
				+ texture(noise_lo, uy + dv).r * tw.y
				+ texture(noise_lo, uz + dv).r * tw.z;
			float c2 = texture(noise_lo, ux * 1.48 + vec2(0.61, 0.23) - dv * 0.8).r * tw.x
				+ texture(noise_lo, uy * 1.48 + vec2(0.37, 0.71) - dv * 0.8).r * tw.y
				+ texture(noise_lo, uz * 1.48 + vec2(0.83, 0.47) - dv * 0.8).r * tw.z;
			bc = mix(bc, camo_col_b.rgb, smoothstep(0.47, 0.51, c1));
			bc = mix(bc, camo_col_c.rgb, smoothstep(0.57, 0.61, c2) * (1.0 - 0.30 * step(0.54, c1)));
		} else if (camo_mode == 2) {
			vec3 sp = cp * 1.48;
			vec3 uvw = vec3(
				dot(sp, vec3(0.80, 0.35, 0.49)),
				dot(sp, vec3(-0.52, 0.71, 0.47)),
				dot(sp, vec3(0.29, -0.59, 0.75))
			);
			vec3 cid = floor(uvw);
			vec3 fuv = fract(uvw);
			float hc = fract(sin(dot(cid, vec3(19.19, 73.41, 41.77))) * 43758.5453);
			float split = (hc > 0.5) ? (fuv.x + fuv.y - 1.0) : (fuv.x - fuv.y);
			float side = smoothstep(-0.015, 0.015, split);
			float h0 = fract(hc * 13.37);
			float h1 = fract(hc * 29.71 + 0.37);
			vec3 cs0 = (h0 > 0.60) ? camo_col_b.rgb : ((h0 < 0.25) ? camo_col_c.rgb : bc);
			vec3 cs1 = (h1 > 0.60) ? camo_col_b.rgb : ((h1 < 0.25) ? camo_col_c.rgb : bc);
			bc = mix(cs0, cs1, side);
		} else {
			float sc_t = (cp.z * 1.18 + cp.y * 0.82 + cp.x * 0.44) * 2.55 + (n_macro - 0.5) * 2.35 + (n_lo - 0.5) * 0.90;
			float sw = sin(sc_t * 3.14159265);
			float sw2 = sin(sc_t * 1.5707963 + 1.15 + (n_lo - 0.5) * 1.35);
			bc = mix(bc, camo_col_b.rgb, smoothstep(0.16, 0.26, sw));
			bc = mix(bc, camo_col_c.rgb, smoothstep(0.52, 0.62, -sw) * smoothstep(-0.18, 0.18, sw2));
		}
	}
	vec3 min_m = mix(vec3(0.032, 0.035, 0.040), vec3(0.095, 0.102, 0.115), metal_base);
	bc = max(bc, min_m);
	// 拼焊板片批次色差：军工烤漆呈现轻微冷暖与明度跳变
	bc *= vec3(1.0 + plate_var * 0.065, 1.0 + plate_var * 0.052, 1.0 + plate_var * 0.035);

	// Trim 中性灰度基准 ~0.75，乘 1.34 还原真实明亮受光漆面，不再压暗底色
	vec3 tinted = bc * (ta * 1.34);
	vec3 haz_col = pow(max(ta, vec3(0.0)), vec3(1.08)) * vec3(1.14, 1.06, 0.86);
	vec3 col = mix(tinted, haz_col, raw_albedo);
	col *= 0.91 + 0.18 * mottle;

	// 解剖垂向体积明暗梯度（旧 GLB COLOR.b=1.0 时由局部高度与法线朝向平滑拟合）
	float anat_grad = (v_grad > 0.996) ? clamp(0.54 + 0.26 * wnrm.y + clamp(lpos.y * 0.18, -0.18, 0.24), 0.15, 1.0) : clamp(v_grad, 0.12, 1.0);
	col *= mix(0.80, 1.06, anat_grad);

	// 3. 诚实 PBR 基础金属度与粗糙度：漆面保持纯电介质，裸金属槽保持真金属导体
	float met = clamp(metal_base + t_chip * mix(0.0, 0.22, smoothstep(0.45, 0.80, metal_base)) * (1.0 - raw_albedo), 0.0, 0.98);
	float rough = clamp(
		mix(rough_base, t_rough, 0.46)
		+ (mottle - 0.5) * 0.14
		+ plate_var * 0.045
		+ (0.5 - n_hi) * 0.06,
		0.14, 0.96
	);

	// 4. 缝隙积垢与螺栓油渍压暗（24-ray 顶点 AO × Trim 凹槽 AO）
	float cav = clamp(1.0 - v_ao * t_ao, 0.0, 1.0);
	float grime_m = cav * grime;
	col *= 1.0 - grime_m * 0.54;
	rough = mix(rough, 0.92, grime_m * 0.58);
	met *= 1.0 - clamp(grime_m * 0.45, 0.0, 0.65);

	// 5. 垂向流锈与关节渗油条纹
	float vert = 1.0 - abs(wnrm.y);
	float n_streak = texture(noise_lo, vec2((lpos.x + lpos.z) * 2.2, lpos.y * 0.42)).r;
	if (rust > 0.01 && raw_albedo < 0.5) {
		float r_mask = smoothstep(0.50, 0.82, mottle * 0.48 + n_streak * 0.52 + cav * 0.30) * (0.40 + 0.60 * vert) * rust;
		col = mix(col, rust_color.rgb, r_mask * 0.72);
		rough = mix(rough, 0.93, r_mask * 0.78);
		met *= 1.0 - r_mask * 0.75;
	}
	float oil_leak = smoothstep(0.66, 0.92, n_streak) * vert * cav * grime;
	col *= 1.0 - oil_leak * 0.28;
	rough = mix(rough, 0.28, oil_leak * 0.52);

	// 6. B.o.T 核心质感：三层窄带硬边掉漆（屏幕空间法线导数门控，100% 杜绝 1-seg 倒角顶点向大平面渗漏斑块！）
	float curv_gate = smoothstep(0.006, 0.038, length(fwidth(normalize(wnrm))));
	float edge_sharp = pow(clamp(v_edge, 0.0, 1.0), 1.25) * curv_gate;
	float wear_noise = 0.52 + 0.58 * n_hi + 0.18 * (n_lo - 0.5);
	float geom_wear = edge_sharp * (0.55 + 0.72 * wear) * wear_noise;
	float trim_wear = pow(t_chip, 1.45) * wear * (0.42 + 0.48 * n_hi) * mix(0.50, 1.0, edge_sharp);
	float wear_sig = max(geom_wear, trim_wear) * (1.0 - raw_albedo * 0.65);

	// 第二层：掉漆外围窄边防锈底漆圈（克制过渡，绝不污染大面装甲）
	float primer_m = smoothstep(0.46, 0.58, wear_sig) * (1.0 - smoothstep(0.60, 0.72, wear_sig)) * is_dielectric;
	vec3 p_col = mix(bc * 0.58, primer_tint.rgb, 0.42);
	col = mix(col, p_col, primer_m * 0.52);
	rough = mix(rough, 0.82, primer_m * 0.55);
	met = mix(met, 0.04, primer_m * 0.60);

	// 第三层：外凸倒角刮擦露出的冷轧枪钢导体（金属度 ~0.88 + 粗糙度 ~0.28，拉出克制锐利的军工金属折边）
	float steel_m = smoothstep(0.58, 0.78, wear_sig);
	vec3 raw_steel = bare_metal.rgb * (0.88 + 0.18 * n_hi);
	col = mix(col, raw_steel, steel_m * mix(0.76, 0.42, metal_base));
	met = mix(met, 0.88, steel_m * 0.86);
	rough = mix(rough, 0.27 + 0.08 * n_hi, steel_m * 0.82);
	// 未掉漆的倒角折面保留微弱受光提亮（复刻 B.o.T 清晰硬表面体块折边）
	col *= 1.0 + edge_sharp * (0.08 + 0.05 * metal_base) * (1.0 - grime_m * 0.5);

	// 7. 全局机甲战损（热烧灼 + 碳化弹坑）
	float dmg = clamp(mech_damage * takes_damage, 0.0, 1.0);
	if (dmg > 0.01) {
		float bv = n_lo + n_hi * 0.24;
		float heat = smoothstep(0.84 - dmg * 0.32, 0.98 - dmg * 0.32, bv);
		float burn = smoothstep(0.93 - dmg * 0.32, 1.03 - dmg * 0.32, bv);
		col = mix(col, col * vec3(0.55, 0.42, 0.32), heat * 0.80);
		col = mix(col, vec3(0.03, 0.028, 0.025), burn * 0.92);
		rough = mix(rough, 0.95, heat);
		met = mix(met, 0.0, heat);
	}

	// 8. 顶部落尘 + 足底/小腿战场风沙泥垢袜套（把 40 吨机甲焊入地面）+ 全局雨湿
	float wet_g = clamp(weather_wet, 0.0, 1.0);
	float up = smoothstep(0.52, 0.94, wnrm.y);
	float top_dust = up * dust * (1.0 - wet_g * 0.82) * smoothstep(0.42, 0.82, mottle);
	float foot_mud = (1.0 - smoothstep(0.08, 1.35, wpos.y)) * dust * (0.55 + 0.45 * smoothstep(0.32, 0.76, n_lo));
	float dust_all = clamp(max(top_dust * 0.52, foot_mud * 0.78), 0.0, 0.85);
	vec3 eff_dust = mix(dust_color.rgb, dust_color.rgb * 0.58, wet_g);
	col = mix(col, eff_dust, dust_all * 0.58);
	rough = mix(rough, mix(0.88, 0.36, wet_g), dust_all * 0.68);
	met *= 1.0 - dust_all * 0.65;

	if (wet_g > 0.01) {
		float wet_f = wet_g * clamp(up * 0.75 + vert * 0.45, 0.0, 1.0);
		col *= mix(1.0, 0.86, wet_f);
		rough = mix(rough, min(rough, 0.24), wet_f * 0.60);
	}

	// 9. 近景 512px 铸钢砂眼 / 军漆橘皮微表面法线（按屏幕导数 18m 外平滑归零，零噪点闪烁）
	vec3 n_loc = normalize(lnrm);
	vec3 an = abs(n_loc);
	vec3 dp = lpos * detail_normal_scale;
	float det_fw = length(fwidth(dp));
	float det_fade = clamp(1.0 - det_fw * 1.65, 0.0, 1.0) * (1.0 - raw_albedo * 0.5);
	if (det_fade > 0.02 && detail_normal_str > 0.01) {
		vec2 duv = (an.x >= an.y && an.x >= an.z) ? dp.zy : ((an.y >= an.z) ? dp.xz : dp.xy);
		vec2 dn2 = (texture(detail_normal, duv).rg * 2.0 - 1.0) * (detail_normal_str * det_fade * mix(0.85, 1.25, steel_m));
		vec3 dp_loc = (an.x >= an.y && an.x >= an.z) ? vec3(0.0, dn2.y, dn2.x) : ((an.y >= an.z) ? vec3(dn2.x, 0.0, -dn2.y) : vec3(dn2.x, dn2.y, 0.0));
		dp_loc -= n_loc * dot(dp_loc, n_loc);
		mat3 v_rot = mat3(rot_x, rot_y, rot_z);
		vec3 w_pert = normalize(wnrm + v_rot * dp_loc);
		vec3 v_n = (VIEW_MATRIX * vec4(w_pert, 0.0)).xyz;
		if (length(v_n) > 1e-4) {
			NORMAL = normalize(v_n);
		}
	}

	// 10. Toksvig 几何与贴图法线方差高光抗锯齿（消除运动镜头下硬棱白点跳动）
	vec3 dn_v = fwidth(NORMAL);
	vec2 dn_t = fwidth(texture(trim_normal, UV).rg * 2.0 - 1.0) * normal_strength;
	float var_n = dot(dn_v, dn_v) + dot(dn_t, dn_t) * 0.35;
	float rough_aa = sqrt(clamp(rough * rough + min(1.15 * var_n, 0.20), 0.02, 1.0));

	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = clamp(rough_aa, 0.14, 0.97);
	SPECULAR = clamp(mix(0.46, 0.88, max(steel_m, smoothstep(0.3, 0.9, met))) + wet_g * 0.12, 0.0, 1.0);
	NORMAL_MAP = texture(trim_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (1.0 - wet_g * 0.14);

	float combined_ao = clamp(mix(1.0, v_ao * t_ao, ao_strength), 0.12, 1.0);
	AO = combined_ao;
	AO_LIGHT_AFFECT = 0.50;

	// 11. 受 AO 严格遮蔽的自然天光边缘轮廓补光（内腔死角绝不泛假蓝光）
	vec3 v_w = normalize(CAMERA_POSITION_WORLD - wpos);
	float ndv = clamp(dot(wnrm, v_w), 0.0, 1.0);
	float sky_up = smoothstep(-0.15, 0.78, wnrm.y);
	float rim_f = pow(1.0 - ndv, 3.0) * sky_up * combined_ao * (0.20 + 0.55 * v_edge + 0.25 * met);
	float rim_str = mix(0.012, 0.032, takes_damage);
	EMISSION = vec3(0.76, 0.84, 0.94) * (rim_f * rim_str * (1.0 - rough * 0.55));
}
