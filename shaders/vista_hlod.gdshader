shader_type spatial;
// 三层远景不透明 HLOD 统合着色器（零贴图采样、零 Alpha 裁切、纯 Early-Z）：
// - UV.x: 0.0 = 城区建筑（多风格立面 + 逐窗随机玻璃/空洞/封板变化 + 底层基座/女儿墙压顶 + 纵向雨渍风化）
//         0.5 = 工业设施/巨构地标（波纹金属肋条 + 结构横梁 + 锈蚀烟垢分层）
//         1.0 = 远景乔木林冠（三阶多尺度团簇斑驳 + 深冠内影 + 柔和背光，与近景写实林木无色差衔接）
// - UV.y: 0..1 归一化高度；COLOR.rgb: sRGB 底色；COLOR.a: 逐建筑/逐树确定性色差种子
// - 全距离高空大气透视雾化（与战区 sky_horizon / fog_light_color 实时同步），消除远景纸盒贴片生硬轮廓
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

global uniform float weather_wet;

uniform vec3 horizon_haze_col : source_color = vec3(0.56, 0.58, 0.55);
uniform float haze_start = 155.0;
uniform float haze_end = 740.0;
uniform float haze_strength : hint_range(0.0, 0.95) = 0.68;

varying vec3 v_col;
varying float v_seed;
varying vec2 v_uv;
varying vec3 v_wpos;
varying vec3 v_wnrm;

vec3 srgb_to_linear(vec3 c) {
	vec3 sc = max(c, vec3(0.0));
	return mix(pow((sc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), sc * (1.0 / 12.92), lessThan(sc, vec3(0.04045)));
}

float hash21(vec2 p) {
	vec2 q = fract(p * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

void vertex() {
	v_col = srgb_to_linear(COLOR.rgb);
	v_seed = COLOR.a;
	v_uv = UV;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 N = normalize(v_wnrm);
	float up_n = clamp(N.y, 0.0, 1.0);
	float h_frac = clamp(v_uv.y, 0.0, 1.0);
	float dist_cam = length(v_wpos - INV_VIEW_MATRIX[3].xyz);

	float is_tree = smoothstep(0.75, 0.95, v_uv.x);
	float is_ind = smoothstep(0.25, 0.45, v_uv.x) * (1.0 - is_tree);
	float is_bldg = 1.0 - smoothstep(0.25, 0.45, v_uv.x);

	float is_wall = 1.0 - smoothstep(0.35, 0.68, up_n);
	float is_roof = smoothstep(0.55, 0.85, up_n);
	float struct_m = 1.0 - is_tree;

	// 逐栋/逐树自然材质色温与明度差异，并微压过度饱和，融入 B.o.T 战区冷灰大气
	vec3 bldg_var = mix(vec3(0.84, 0.86, 0.89), vec3(1.04, 1.00, 0.94), v_seed);
	vec3 tree_var = mix(vec3(0.84, 0.92, 0.84), vec3(1.06, 0.98, 0.82), v_seed);
	vec3 col = v_col * mix(bldg_var, tree_var, is_tree);

	// 压暗浅色远景灰白体块，防止远景方块比近景更亮、更像玩具积木
	float b_lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, mix(vec3(b_lum), col, 0.78) * 0.86, is_bldg * 0.62);

	// 建筑与工业设施整体体量光影：深接地暗影 + 屋檐纵向雨渍流痕 + 墙面微混凝土颗粒
	float wall_u = abs(N.x) > abs(N.z) ? v_wpos.z : v_wpos.x;
	float fw_u = fwidth(wall_u);
	float fw_y = fwidth(v_wpos.y);
	float aa_wall = smoothstep(3.2, 0.35, max(fw_u, fw_y));

	float base_ao = mix(0.52, 1.0, smoothstep(0.0, 3.8, v_wpos.y));
	float h_grad = mix(0.84, 1.06, h_frac);
	// 混凝土/砖墙低频风化斑驳与从女儿墙垂落的雨渍烟垢
	float patina = 0.5 + 0.5 * sin(wall_u * 0.27 + v_seed * 12.0) * cos(v_wpos.y * 0.21 - v_seed * 7.0);
	float streak = 0.5 + 0.5 * sin(wall_u * 1.15 + v_seed * 23.0 + sin(wall_u * 0.37) * 2.0);
	float top_grime = smoothstep(0.55, 1.0, h_frac) * smoothstep(0.35, 0.90, streak) * 0.22;
	float bot_grime = (1.0 - smoothstep(0.0, 5.0, v_wpos.y)) * (0.16 + 0.12 * patina);
	float wall_tex = mix(1.0, (0.90 + 0.16 * patina - top_grime - bot_grime), is_wall * struct_m * (0.45 + 0.55 * aa_wall));

	col *= mix(1.0, base_ao * h_grad * wall_tex, struct_m);

	// 建筑平屋面深油毡碎石压暗 + 顶部女儿墙深色压顶线
	float parapet_band = smoothstep(0.92, 0.97, h_frac) * is_wall * is_bldg;
	col *= mix(1.0, 0.62, parapet_band);
	col *= mix(1.0, 0.54 + 0.08 * patina, is_roof * (is_bldg + is_ind * 0.72));

	// 城区建筑多风格抗锯齿立面系统（底层基座 + 三种立面风格 + 逐窗随机状态：反光玻璃/暗洞/封板/微弱应急灯）
	float win_m = 0.0;
	float glass_spec_m = 0.0;
	vec3 win_emit = vec3(0.0);
	if (is_bldg > 0.05 && is_wall > 0.05) {
		float aa_y = smoothstep(2.6, 0.26, fw_y);
		float aa_u = smoothstep(2.2, 0.22, fw_u);

		// 底层商铺/混凝土基座与腰线
		float plinth = 1.0 - smoothstep(3.2, 4.1, v_wpos.y);
		float belt = smoothstep(3.4, 3.8, v_wpos.y) * (1.0 - smoothstep(4.0, 4.4, v_wpos.y));
		col *= mix(1.0, 0.72, plinth * 0.70);
		col *= mix(1.0, 0.76, belt * aa_y);

		// 3 种建筑立面风格由 v_seed 决定：0=幕墙条窗写字楼, 1=老式住宅打孔窗+窗台阴影, 2=粗野派竖向混凝土肋条楼
		float style = v_seed;
		float floor_freq = style < 0.34 ? 0.305 : (style < 0.70 ? 0.335 : 0.285);
		float bay_freq = style < 0.34 ? 0.48 : (style < 0.70 ? 0.38 : 0.44);

		float floor_coord = v_wpos.y * floor_freq + v_seed * 0.31;
		float bay_coord = wall_u * bay_freq + v_seed * 2.17;
		float fy = fract(floor_coord);
		float fx = fract(bay_coord);
		vec2 cell_id = vec2(floor(bay_coord), floor(floor_coord));
		float wh = hash21(cell_id + vec2(v_seed * 37.0, abs(N.x) * 11.0));

		float row_lo = style < 0.34 ? 0.16 : 0.24;
		float row_hi = style < 0.34 ? 0.80 : 0.76;
		float col_lo = style < 0.34 ? 0.06 : (style < 0.70 ? 0.18 : 0.22);
		float col_hi = style < 0.34 ? 0.94 : (style < 0.70 ? 0.82 : 0.78);

		float row_band = smoothstep(row_lo, row_lo + 0.10, fy) * (1.0 - smoothstep(row_hi - 0.10, row_hi, fy));
		float col_bay = smoothstep(col_lo, col_lo + 0.10, fx) * (1.0 - smoothstep(col_hi - 0.10, col_hi, fx));
		// 楼层板与窗台微阴影（即使在极远距仍保留真实建筑水平/竖向肌理）
		float slab_line = (1.0 - smoothstep(0.0, 0.14, fy)) * 0.22 * aa_y;
		float pilaster = style >= 0.70 ? (1.0 - smoothstep(0.0, 0.18, min(fx, 1.0 - fx))) * 0.22 * aa_u : 0.0;
		col *= (1.0 - slab_line - pilaster);

		float height_gate = smoothstep(3.6, 4.6, v_wpos.y) * smoothstep(0.95, 0.86, h_frac);
		float far_band_mix = style < 0.34 ? 0.72 : 0.50;
		win_m = row_band * mix(far_band_mix, col_bay, aa_u) * mix(0.42, 1.0, aa_y) * is_wall * is_bldg * height_gate;

		// 逐窗真实状态：反光灰蓝幕墙 / 战损破空黑洞 / 木板封窗 / 极少量暗淡室内残光
		vec3 glass_refl = mix(vec3(0.045, 0.058, 0.072), horizon_haze_col * 0.36, 0.38 + 0.22 * up_n);
		vec3 cavity_dark = vec3(0.014, 0.016, 0.018);
		vec3 boarded_col = col * vec3(0.72, 0.66, 0.56);

		vec3 pane_col = glass_refl;
		float is_glass = 1.0;
		if (wh < 0.26) {
			pane_col = cavity_dark;
			is_glass = 0.05;
		} else if (wh < 0.40) {
			pane_col = boarded_col;
			is_glass = 0.10;
		} else {
			pane_col = glass_refl * mix(0.78, 1.25, fract(wh * 9.7));
		}
		// 极远距自动向统一暗玻璃均质化（高阈值平滑过渡，杜绝 180~260m 建筑表面细碎黑点杂讯）
		float aa_cell = smoothstep(0.85, 0.16, max(fw_u, fw_y));
		vec3 far_avg_glass = mix(cavity_dark, glass_refl, 0.72);
		pane_col = mix(far_avg_glass, pane_col, aa_cell);
		glass_spec_m = win_m * mix(0.68, is_glass, aa_cell);
		col = mix(col, pane_col, win_m * 0.86);

		// 极稀疏废墟应急微光（约 3.2% 窗格），赋予远景城市纵深生机而不喧宾夺主
		if (wh > 0.968 && aa_cell > 0.25) {
			vec3 lamp = wh > 0.986 ? vec3(0.26, 0.34, 0.38) : vec3(0.42, 0.28, 0.14);
			win_emit = lamp * win_m * aa_cell * 0.30;
		}
	}

	// 工业巨构与厂房：竖向波纹彩钢瓦 + 水平结构加强肋 + 下缘铁锈烟垢氧化带
	if (is_ind > 0.05 && is_wall > 0.05) {
		float aa_iy = smoothstep(2.8, 0.35, fw_y);
		float aa_iu = smoothstep(2.2, 0.30, fw_u);
		float rib_h = 0.91 + 0.09 * sin(v_wpos.y * 1.48 + v_seed * 6.283);
		float flute_v = 0.94 + 0.06 * sin(wall_u * 3.4 + v_seed * 9.0);
		col *= mix(1.0, rib_h, is_ind * is_wall * aa_iy);
		col *= mix(1.0, flute_v, is_ind * is_wall * aa_iu);
		float rust_band = (1.0 - smoothstep(0.05, 0.55, h_frac)) * smoothstep(0.35, 0.85, patina);
		col = mix(col, col * vec3(1.12, 0.78, 0.58) * 0.78, rust_band * is_ind * 0.45);
	}

	// 远景树冠体积明暗 + 三阶多尺度叶团雕塑感（对齐近景 foliage.gdshader 深沉森林明度，杜绝亮绿/亮橙气球断层）
	vec3 leaf_n_pert = vec3(0.0);
	if (is_tree > 0.05) {
		float cl1 = sin(v_wpos.x * 1.05 + v_wpos.y * 0.92 + v_seed * 4.1) * cos(v_wpos.z * 0.98 - v_wpos.y * 0.85);
		float cl2 = sin(v_wpos.x * 2.55 - v_wpos.z * 2.35 + v_seed * 6.28) * cos(v_wpos.y * 2.40 + v_wpos.x * 1.35);
		float cl3 = sin(v_wpos.x * 5.6 + v_wpos.z * 5.1) * cos(v_wpos.y * 5.3 - v_wpos.x * 3.1);
		float dapple = clamp(0.5 + cl1 * 0.30 + cl2 * 0.25 + cl3 * 0.16, 0.0, 1.0);
		float sun_crown = clamp(h_frac * 0.50 + clamp(N.y * 0.5 + 0.5, 0.0, 1.0) * 0.30 + dapple * 0.32, 0.0, 1.0);
		vec3 shadow_tint = col * vec3(0.28, 0.34, 0.36);
		vec3 lit_tint = col * vec3(0.96, 0.98, 0.82);
		vec3 tree_shaded = mix(shadow_tint, lit_tint, smoothstep(0.18, 0.86, sun_crown));
		tree_shaded *= mix(0.72, 1.08, dapple);
		col = mix(col, tree_shaded, is_tree);
		leaf_n_pert = vec3(cl1 * 0.85 + cl3 * 0.42, cl2 * 0.65, -cl2 * 0.85 + cl3 * 0.42) * (0.64 * is_tree);
	}

	// 同步雨天湿润微暗
	float wet = clamp(weather_wet, 0.0, 1.0);
	col *= mix(1.0, 0.85, wet * struct_m * 0.72);

	// 高空大气透视雾化（随距离柔和退饱和并向地平线天雾色融合，高层建筑顶部略保留清晰剪影）
	float dist_haze = smoothstep(haze_start, haze_end, dist_cam);
	float h_atten = mix(1.0, 0.64, smoothstep(6.0, 46.0, v_wpos.y));
	float haze_amt = clamp(dist_haze * h_atten * haze_strength, 0.0, 0.86);
	float lum_h = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, mix(vec3(lum_h), col, 0.55), haze_amt * 0.55);
	col = mix(col, horizon_haze_col * 0.88, haze_amt * 0.78);

	vec3 wn_out = normalize(mix(N, normalize(mix(N, vec3(0.0, 1.0, 0.0), 0.36) + leaf_n_pert), is_tree));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn_out, 0.0)).xyz);
	ALBEDO = col;
	float rough_base = mix(mix(0.86, 0.66, is_ind), 0.92, is_tree);
	ROUGHNESS = mix(mix(rough_base, 0.30, glass_spec_m * 0.80), 0.94, haze_amt * 0.65);
	METALLIC = is_ind * 0.24 * (1.0 - haze_amt * 0.7);
	SPECULAR = mix(mix(0.22, 0.34, is_ind), 0.08, is_tree);
	SPECULAR = mix(SPECULAR, 0.55, glass_spec_m * 0.65) * (1.0 - haze_amt * 0.72);
	BACKLIGHT = col * vec3(0.80, 0.84, 0.46) * (0.24 * is_tree) * (1.0 - haze_amt * 0.65);
	// 柔和大气前向散射底光 + 建筑极稀应急残光（彻底杜绝远景死黑剪影贴片）
	EMISSION = horizon_haze_col * (haze_amt * 0.20) + win_emit * (1.0 - haze_amt * 0.85);
}
