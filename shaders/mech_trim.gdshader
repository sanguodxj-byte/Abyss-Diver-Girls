shader_type spatial;
// 高精度机甲共享 2K Trim Sheet 硬表面 PBR 着色器（标准规范 MECH_MODELING_STANDARD v1.0）
// 兼容：动态阵营涂装、24-ray 烘焙顶点 AO (COLOR.g)、凸边金属磨损 (1-COLOR.r)、战损烧灼、雨湿高光、天光轮廓光。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx, ensure_correct_normals;

uniform vec4 base_color : source_color = vec4(0.45, 0.45, 0.42, 1.0);
uniform float metal_base : hint_range(0.0, 1.0) = 0.28;
uniform float rough_base : hint_range(0.0, 1.0) = 0.48;
uniform float wear : hint_range(0.0, 1.0) = 0.48;
uniform float rust : hint_range(0.0, 1.0) = 0.12;
uniform float grime : hint_range(0.0, 1.0) = 0.34;
uniform float dust : hint_range(0.0, 1.0) = 0.16;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.15;
uniform float ao_strength : hint_range(0.0, 1.5) = 0.90;
uniform float raw_albedo : hint_range(0.0, 1.0) = 0.0;
uniform float takes_damage : hint_range(0.0, 1.0) = 0.0;
uniform float occ_exempt = 0.0;
uniform float occ_self_fade = 0.0;

uniform vec4 bare_metal : source_color = vec4(0.70, 0.72, 0.75, 1.0);
uniform vec4 rust_color : source_color = vec4(0.32, 0.15, 0.07, 1.0);
uniform vec4 dust_color : source_color = vec4(0.46, 0.41, 0.34, 1.0);

global uniform float mech_damage;
global uniform float weather_wet;
global uniform float weather_rain;

uniform sampler2D trim_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 lpos;
varying float v_edge;
varying float v_ao;

void vertex() {
	vec3 sx = MODEL_MATRIX[0].xyz;
	vec3 sy = MODEL_MATRIX[1].xyz;
	vec3 sz = MODEL_MATRIX[2].xyz;
	vec3 sc = max(vec3(length(sx), length(sy), length(sz)), vec3(1e-3));
	mat3 rot_m = mat3(sx / sc.x, sy / sc.y, sz / sc.z);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(rot_m * (NORMAL / sc));
	lpos = VERTEX;
	v_edge = clamp(1.0 - COLOR.r, 0.0, 1.0);
	v_ao = clamp(COLOR.g, 0.10, 1.0);
}

void fragment() {
	vec3 ta = texture(trim_albedo, UV).rgb;
	vec3 orm = texture(trim_orm, UV).rgb;
	float t_ao = orm.r;
	float t_rough = orm.g;
	float t_met_boost = orm.b;

	// 中性灰度 Trim Albedo × 动态模块色；警示条槽（raw_albedo=1.0）保留高对比黄黑警示色
	vec3 bc = base_color.rgb;
	vec3 min_m = mix(vec3(0.036, 0.040, 0.046), vec3(0.085, 0.092, 0.104), metal_base);
	bc = max(bc, min_m);
	vec3 tinted = bc * (ta * 1.38);
	vec3 haz_col = pow(max(ta, vec3(0.0)), vec3(1.15)) * vec3(1.12, 1.06, 0.88);
	vec3 col = mix(tinted, haz_col, raw_albedo);

	// 局部微尺度噪声（提供防克隆色差、锈迹与战损纹理）
	float n_lo = texture(noise_lo, lpos.xy * 0.65 + lpos.zz * 0.42).r;
	float n_hi = texture(noise_lo, lpos.xz * 2.35 + lpos.yy * 1.85 + vec2(0.37, 0.61)).r;
	col *= 0.94 + 0.12 * n_lo;

	// 压实军用烤漆质感：避免把哑光漆面装甲推成亮银镀铬，仅让高金属槽与细微擦伤显露金属度
	float met = clamp(metal_base + t_met_boost * mix(0.14, 0.28, metal_base) * (1.0 - raw_albedo), 0.0, 0.96);
	float rough = clamp(mix(rough_base, max(t_rough, 0.34), 0.52) + (n_hi - 0.5) * 0.08, 0.16, 0.96);

	// 缝隙污垢压暗（凹处由 24-ray 顶点 AO + Trim AO 联合驱动）
	float cav = clamp(1.0 - v_ao * t_ao, 0.0, 1.0);
	col *= 1.0 - cav * grime * 0.46;
	rough = mix(rough, 0.92, cav * grime * 0.52);

	// 锈蚀（默认轻微军工做旧；流浪者 NPC 阵营由 npc_mech.gd 提升 rust 形成高风化铁锈感）
	float vert = 1.0 - abs(wnrm.y);
	if (rust > 0.01 && raw_albedo < 0.5) {
		float r_mask = smoothstep(0.46, 0.80, n_lo * 0.60 + n_hi * 0.40 + cav * 0.35) * (0.45 + 0.55 * vert) * rust;
		col = mix(col, rust_color.rgb, r_mask * 0.68);
		rough = mix(rough, 0.92, r_mask * 0.75);
		met *= 1.0 - r_mask * 0.65;
	}

	// 凸边金属磨损：克制局部掉漆，仅在最锐利倒角棱线处微露冷钢高光（严禁整块装甲变银白）
	float edge_mask = clamp(v_edge * (0.42 + 0.68 * wear) * (0.55 + 0.65 * n_hi), 0.0, 1.0);
	float chip = smoothstep(0.56, 0.88, edge_mask) * (1.0 - raw_albedo * 0.70);
	vec3 exposed = mix(bc * 1.25 + vec3(0.08, 0.085, 0.095), bare_metal.rgb * 0.72, 0.45) * (0.90 + 0.16 * n_hi);
	col = mix(col, exposed, chip * 0.52);
	met = mix(met, 0.78, chip * 0.48);
	rough = mix(rough, 0.30, chip * 0.50);
	col *= 1.0 + v_edge * (0.06 + 0.08 * metal_base);

	// 全局机甲战损（血量下降时自动浮现热烧灼 + 碳化弹痕）
	float dmg = clamp(mech_damage * takes_damage, 0.0, 1.0);
	if (dmg > 0.01) {
		float bv = n_lo + n_hi * 0.22;
		float heat = smoothstep(0.84 - dmg * 0.32, 0.98 - dmg * 0.32, bv);
		float burn = smoothstep(0.93 - dmg * 0.32, 1.03 - dmg * 0.32, bv);
		col = mix(col, col * vec3(0.55, 0.42, 0.32), heat * 0.80);
		col = mix(col, vec3(0.03, 0.028, 0.025), burn * 0.92);
		rough = mix(rough, 0.95, heat);
		met = mix(met, 0.0, heat);
	}

	// 顶部落尘与全局天气雨湿
	float wet_g = clamp(weather_wet, 0.0, 1.0);
	float up = smoothstep(0.58, 0.95, wnrm.y);
	float d = up * dust * (1.0 - wet_g * 0.82) * smoothstep(0.52, 0.84, n_lo);
	col = mix(col, dust_color.rgb, d * 0.26);
	rough = mix(rough, 0.84, d * 0.42);
	if (wet_g > 0.01) {
		float wet_f = wet_g * clamp(up * 0.75 + vert * 0.45, 0.0, 1.0);
		col *= mix(1.0, 0.88, wet_f);
		rough = mix(rough, min(rough, 0.26), wet_f * 0.58);
	}

	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = clamp(rough, 0.16, 0.98);
	SPECULAR = clamp(mix(0.42, 0.70, max(chip * 0.6, metal_base * 0.65)) + wet_g * 0.14, 0.0, 1.0);
	NORMAL_MAP = texture(trim_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (1.0 - wet_g * 0.15);

	float combined_ao = clamp(mix(1.0, v_ao * t_ao, ao_strength), 0.16, 1.0);
	AO = combined_ao;
	AO_LIGHT_AFFECT = 0.38;

	// 克制天光轮廓高光：确保俯视角暗部中机甲棱边与轮廓依然清晰
	vec3 v_w = normalize(CAMERA_POSITION_WORLD - wpos);
	float ndv = clamp(dot(wnrm, v_w), 0.0, 1.0);
	float sky_up = smoothstep(-0.20, 0.72, wnrm.y);
	float rim_f = pow(1.0 - ndv, 2.8) * sky_up * (0.28 + 0.52 * v_edge + 0.22 * metal_base);
	float rim_str = mix(0.018, 0.052, takes_damage);
	EMISSION = vec3(0.68, 0.82, 1.0) * (rim_f * rim_str * (1.0 - rough * 0.45));
}
