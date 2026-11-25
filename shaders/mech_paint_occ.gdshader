shader_type spatial;
// 写实工业与机甲 PBR 着色器（遮挡透视专用版，仅在第三人称遮挡穿墙时由 occ_buildings.gd / raid.gd / bug.gd 按需切换）。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx, ensure_correct_normals;
#include "res://shaders/occ_fade.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float metal_base : hint_range(0.0, 1.0) = 0.15;
uniform float rough_base : hint_range(0.0, 1.0) = 0.6;
uniform float wear : hint_range(0.0, 1.0) = 0.5;
uniform float scratches : hint_range(0.0, 1.0) = 0.35;
uniform float dust : hint_range(0.0, 1.0) = 0.3;
uniform float grime : hint_range(0.0, 1.0) = 0.5;
uniform float rust : hint_range(0.0, 1.0) = 0.25;
uniform float panel_scale = 0.0;
uniform float stripes = 0.0;
uniform float detail_scale = 1.0;
uniform int tint_mode = 0;
uniform float takes_damage = 0.0;
uniform float metal_wear : hint_range(0.0, 1.0) = 1.0;
uniform float roof_uv = 0.0;
global uniform float mech_damage;
global uniform float weather_wet;
global uniform float weather_rain;
uniform float occ_exempt = 0.0;
uniform float occ_self_fade = 0.0;
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
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_rough_tex = 0.0;
uniform float rough_tex_strength : hint_range(0.0, 1.0) = 0.65;

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
	vec3 sc = max(c, vec3(0.0));
	return mix(pow((sc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), sc * (1.0 / 12.92), lessThan(sc, vec3(0.04045)));
}

void vertex() {
	vec3 sx = MODEL_MATRIX[0].xyz;
	vec3 sy = MODEL_MATRIX[1].xyz;
	vec3 sz = MODEL_MATRIX[2].xyz;
	vec3 scale = max(vec3(length(sx), length(sy), length(sz)), vec3(1e-3));
	mat3 rot_m = mat3(sx / scale.x, sy / scale.y, sz / scale.z);
	if (tint_mode == 2 && dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.01 && abs(CUSTOM0.w) > 0.5) {
		lpos = vec3(UV.x, UV.y, UV2.x);
		lnrm = normalize(CUSTOM0.xyz);
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		wnrm = normalize(rot_m * NORMAL);
		float flip_s = (CUSTOM0.w < 0.0 || CUSTOM0.w > 1.5) ? -1.0 : 1.0;
		vec4 cq = normalize(CUSTOM1);
		rot_x = rot_m * q_rot(cq, vec3(1.0, 0.0, 0.0));
		rot_y = rot_m * q_rot(cq, vec3(0.0, 1.0, 0.0));
		rot_z = rot_m * (q_rot(cq, vec3(0.0, 0.0, 1.0)) * flip_s);
	} else {
		lpos = VERTEX * scale;
		vec3 n_sc = NORMAL / scale;
		lnrm = length(n_sc) > 1e-4 ? normalize(n_sc) : vec3(0.0, 1.0, 0.0);
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		wnrm = normalize(rot_m * lnrm);
		rot_x = rot_m[0];
		rot_y = rot_m[1];
		rot_z = rot_m[2];
	}
	edge = 1.0 - COLOR.r;
	tint = tint_mode == 1 ? srgb_to_linear(INSTANCE_CUSTOM.rgb) : ((tint_mode == 2 || tint_mode == 3) ? srgb_to_linear(COLOR.gba) : vec3(1.0));
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(max(abs(n), vec3(0.0)), vec3(6.0));
	return w / max(w.x + w.y + w.z, 1e-4);
}

float tri(sampler2D t, vec3 p, vec3 w) {
	float s = 0.0;
	if (w.x > 0.05) s += texture(t, p.zy).r * w.x;
	if (w.y > 0.05) s += texture(t, p.xz).r * w.y;
	if (w.z > 0.05) s += texture(t, p.xy).r * w.z;
	return s;
}

vec2 h22_rip(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 rain_ripple(vec2 p, float t) {
	vec2 slope = vec2(0.0);
	for (int i = 0; i < 2; i++) {
		float sc = i == 0 ? 1.45 : 2.25;
		vec2 gp = p * sc + float(i) * vec2(17.3, 9.1);
		vec2 cell = floor(gp);
		vec2 f = fract(gp) - 0.5;
		vec2 h = h22_rip(cell);
		vec2 dv = f - (h - 0.5) * 0.52;
		float d = length(dv);
		float cyc = fract(t * (0.88 + float(i) * 0.31) + fract(h.x * 7.13 + h.y * 3.71));
		float rad = cyc * 0.44;
		float env = exp(-abs(d - rad) * 34.0) * (1.0 - cyc) * (1.0 - cyc) * smoothstep(0.008, 0.045, d);
		float wv = cos((d - rad) * 68.0) * env;
		slope += (dv / max(d, 1e-3)) * wv;
	}
	return slope * 0.13;
}

void fragment() {
	float occ_fade = 0.0;
	if (occ_self_fade > 0.005) {
		highp vec3 dc_s = INV_VIEW_MATRIX[3].xyz - occ_cam_pos;
		if (dot(dc_s, dc_s) <= 0.25) {
			occ_fade = clamp(occ_self_fade, 0.0, 0.92);
			if (occ_ign(FRAGCOORD.xy) < occ_fade) {
				discard;
			}
		}
	} else if (occ_exempt < 0.5) {
		if (occ_clip_whole_bldg(wpos, INV_VIEW_MATRIX[3].xyz)) {
			discard;
		}
		if (occ_params.x > 0.005) {
			occ_fade = occ_calc_fade(wpos, INV_VIEW_MATRIX[3].xyz, occ_params.x, 0.40);
			if (occ_fade > 0.005 && occ_ign(FRAGCOORD.xy) < clamp(occ_fade * 1.06, 0.0, 1.0)) {
				discard;
			}
		}
	}

	vec3 n_loc = normalize(lnrm);
	vec3 an = abs(n_loc);
	float axis_max = max(an.x, max(an.y, an.z));
	bool single_plane = axis_max > 0.85;
	vec3 w = single_plane ? vec3(0.0) : tri_w(n_loc);
	vec3 p = lpos * detail_scale;
	vec3 cam_diff = wpos - CAMERA_POSITION_WORLD;
	float cam_d2 = dot(cam_diff, cam_diff);
	bool near_det = cam_d2 < 3600.0;

	vec2 uv_x = vec2(p.z, -p.y);
	vec2 uv_y = roof_uv > 0.5 ? vec2(p.z, p.x) : vec2(p.x, p.z);
	vec2 uv_z = vec2(p.x, -p.y);
	bool dom_x = an.x >= an.y && an.x >= an.z;
	bool dom_y = !dom_x && an.y >= an.z;
	vec2 uv_dom = dom_x ? uv_x : (dom_y ? uv_y : uv_z);
	// 静态非金属建筑/砖石/木料沿建筑自身正交轴投影世界坐标：彻底消除重复立柱/墙块的克隆印章，且旋转建筑依然严格横平竖直；
	// 机甲/载具/金属构件保持局部坐标，确保运动与旋转时零纹理滑动。
	bool use_wuv = metal_wear < 0.5 && takes_damage < 0.5;
	vec3 p_tex = use_wuv ? vec3(dot(wpos, rot_x), dot(wpos, rot_y), dot(wpos, rot_z)) * detail_scale : p;
	vec2 tuv_x = vec2(p_tex.z, -p_tex.y);
	vec2 tuv_y = roof_uv > 0.5 ? vec2(p_tex.z, p_tex.x) : vec2(p_tex.x, p_tex.z);
	vec2 tuv_z = vec2(p_tex.x, -p_tex.y);
	vec2 tuv_dom = dom_x ? tuv_x : (dom_y ? tuv_y : tuv_z);

	vec3 p_nlo = p_tex * 0.35 + wpos * 0.02;
	float n_lo = single_plane
		? texture(noise_lo, dom_x ? p_nlo.zy : (dom_y ? p_nlo.xz : p_nlo.xy)).r
		: tri(noise_lo, p_nlo, w);
	float macro_w = texture(noise_lo, wpos.xz * 0.032 + vec2(wpos.y * 0.017 + 1.7, wpos.y * 0.023 + 2.9)).r;
	float n_hi = near_det ? texture(noise_hi, tuv_dom * 2.4).r : mix(n_lo, macro_w, 0.5);
	float n_mid = mix(n_lo, n_hi, 0.42) * 0.80 + macro_w * 0.20;
	float vert = 1.0 - abs(wnrm.y);
	float n_sc = (near_det && ((rust > 0.01 && vert > 0.05) || scratches > 0.01)) ? texture(noise_hi, vec2(tuv_dom.x * 9.5, tuv_dom.y * 1.1)).r : n_hi;

	vec3 base_c = base_color.rgb * tint;
	if (metal_wear > 0.5) {
		vec3 min_m = mix(vec3(0.044, 0.048, 0.056), vec3(0.125, 0.132, 0.146), metal_base);
		min_m = mix(min_m, max(min_m, vec3(0.068, 0.074, 0.088)), takes_damage);
		base_c = max(base_c, min_m);
		base_c = mix(base_c, sqrt(base_c) * 0.58, metal_base * 0.24);
	}
	float arch_var = use_wuv ? (macro_w - 0.5) * 0.30 : 0.0;
	vec3 arch_tone = vec3(1.0 + arch_var * 0.72, 1.0 + arch_var * 0.58, 1.0 + arch_var * 0.38);
	vec3 col = base_c * arch_tone * (0.92 + 0.16 * n_lo) * (0.97 + 0.06 * n_hi) * (0.90 + 0.20 * macro_w);
	float ts = albedo_tex_scale * (use_wuv ? 1.42 : 1.60);
	float tex_luma = 0.7;
	if (use_albedo_tex > 0.5) {
		vec3 at;
		if (single_plane) {
			at = texture(albedo_tex, tuv_dom * ts).rgb;
		} else {
			at = vec3(0.0);
			if (w.x > 0.05) at += texture(albedo_tex, tuv_x * ts).rgb * w.x;
			if (w.y > 0.05) at += texture(albedo_tex, tuv_y * ts).rgb * w.y;
			if (w.z > 0.05) at += texture(albedo_tex, tuv_z * ts).rgb * w.z;
		}
		if (use_wuv) {
			vec2 m_off = vec2(0.37, 0.19);
			float mts = ts * 0.27;
			vec3 at_mac = single_plane
				? texture(albedo_tex, tuv_dom * mts + m_off).rgb
				: (texture(albedo_tex, tuv_x * mts + m_off).rgb * w.x + texture(albedo_tex, tuv_y * mts + m_off).rgb * w.y + texture(albedo_tex, tuv_z * mts + m_off).rgb * w.z);
			at = clamp(vec3(0.48) + (at - vec3(0.48)) * 1.28, vec3(0.05), vec3(1.35));
			tex_luma = dot(mix(at, at_mac, 0.38), vec3(0.333));
			col *= mix(vec3(1.0), at * 1.52, albedo_tex_strength);
			col *= mix(vec3(1.0), clamp(at_mac * 1.48, vec3(0.58), vec3(1.36)), albedo_tex_strength * 0.48);
		} else {
			tex_luma = dot(at, vec3(0.333));
			col *= mix(vec3(1.0), at * 1.48, albedo_tex_strength);
		}
	}
	float met = metal_base;
	float rough = rough_base * (0.93 + 0.12 * n_hi - 0.05 * n_mid + (0.66 - tex_luma) * 0.12 * use_albedo_tex);
	if (use_rough_tex > 0.5 && cam_d2 < 2025.0) {
		float rt;
		if (single_plane) {
			rt = texture(rough_tex, tuv_dom * ts).r;
		} else {
			rt = 0.0;
			if (w.x > 0.05) rt += texture(rough_tex, tuv_x * ts).r * w.x;
			if (w.y > 0.05) rt += texture(rough_tex, tuv_y * ts).r * w.y;
			if (w.z > 0.05) rt += texture(rough_tex, tuv_z * ts).r * w.z;
		}
		float r_mapped = clamp(mix(rough_base, rt, rough_tex_strength), 0.14, 0.98);
		rough = mix(rough, r_mapped, 0.88);
	}

	if (stripes > 0.5) {
		float s = fract((p.x + p.y + p.z) * 2.2);
		float sw = max(fwidth(s), 1e-4);
		float band = min(smoothstep(0.5 - sw, 0.5 + sw, s), 1.0 - smoothstep(1.0 - sw * 1.5, 1.0, s));
		col = mix(vec3(0.06, 0.06, 0.065), vec3(0.86, 0.60, 0.11), band) * (0.84 + 0.24 * n_lo);
	}

	float seam = 0.0;
	float seam_ao = 0.0;
	vec2 seam_n = vec2(0.0);
	if (panel_scale > 0.0 && near_det) {
		float curv_n = length(fwidth(n_loc));
		float flat_gate = smoothstep(0.88, 0.97, axis_max) * (1.0 - smoothstep(0.004, 0.018, curv_n)) * (1.0 - smoothstep(0.02, 0.16, edge));
		if (flat_gate > 0.005) {
			vec2 fw_raw = dom_x ? fwidth(uv_x) : (dom_y ? fwidth(uv_y) : fwidth(uv_z));
			vec2 g = uv_dom * panel_scale + vec2(0.13, 0.31);
			float row_id = floor(g.y);
			g.x += mod(row_id, 2.0) * 0.5;
			vec2 fg = fract(g) - 0.5;
			vec2 f = abs(fg);
			vec2 fw = max(fw_raw * panel_scale, vec2(1e-4));
			vec2 dist = 0.5 - f;
			float lw = 0.0045;
			float lx = 1.0 - smoothstep(lw, lw + fw.x * 1.6, dist.x);
			float ly = 1.0 - smoothstep(lw, lw + fw.y * 1.6, dist.y);
			float cell_h = fract(sin(dot(floor(g), vec2(127.1, 311.7))) * 43758.5453);
			col *= 1.0 + (cell_h - 0.5) * mix(0.04, 0.055, metal_wear) * flat_gate;
			float fade = clamp(1.0 - (max(fw.x, fw.y) - 0.015) * 14.0, 0.0, 1.0) * flat_gate;
			seam = max(lx, ly) * fade;
			float halo_x = 1.0 - smoothstep(lw, lw + 0.036, dist.x);
			float halo_y = 1.0 - smoothstep(lw, lw + 0.036, dist.y);
			seam_ao = max(halo_x, halo_y) * fade * (0.42 + 0.50 * n_lo);
			seam_n = vec2(lx * sign(fg.x), ly * sign(fg.y)) * fade * mix(0.18, 0.28, metal_wear);
			col *= 1.0 - seam * mix(0.18, 0.32, metal_wear) - seam_ao * mix(0.05, 0.09, metal_wear);
			rough = mix(rough, 0.90, seam);
		}
	}

	if (use_wuv && panel_scale <= 0.0 && stripes < 0.5 && single_plane && vert > 0.45) {
		vec2 cg = vec2(tuv_dom.x * 0.42 + mod(floor(tuv_dom.y * 0.80), 2.0) * 0.5, tuv_dom.y * 0.80);
		vec2 cfw = max(fwidth(cg), vec2(1e-4));
		float c_fade = clamp(1.0 - max(cfw.x, cfw.y) * 2.6, 0.0, 1.0) * (1.0 - smoothstep(0.03, 0.18, edge));
		if (c_fade > 0.01) {
			vec2 cfg = fract(cg) - 0.5;
			vec2 cd = 0.5 - abs(cfg);
			float hj = (1.0 - smoothstep(0.008, 0.008 + cfw.y * 1.5, cd.y)) * c_fade;
			float vj = (1.0 - smoothstep(0.006, 0.006 + cfw.x * 1.5, cd.x)) * c_fade * 0.68;
			float ch_h = fract(sin(dot(floor(cg), vec2(91.7, 241.3))) * 43758.5453);
			col *= 1.0 + (ch_h - 0.5) * 0.11 * c_fade;
			float a_seam = max(hj, vj);
			seam = max(seam, a_seam * 0.78);
			seam_ao = max(seam_ao, (1.0 - smoothstep(0.008, 0.042, min(cd.y, cd.x + 0.01))) * c_fade * 0.45);
			seam_n += vec2(vj * sign(cfg.x), hj * sign(cfg.y)) * 0.24;
			col *= 1.0 - a_seam * 0.20;
			rough = mix(rough, 0.93, a_seam * 0.65);
		}
	}

	float low = (1.0 - smoothstep(0.0, use_wuv ? 2.85 : 1.75, wpos.y + (use_wuv ? (n_lo - 0.5) * 0.75 : 0.0))) * (1.0 - smoothstep(0.35, 0.75, abs(wnrm.y)));
	float under = smoothstep(0.25, 0.85, -wnrm.y) * metal_wear;
	col *= mix(vec3(1.0), vec3(0.66, 0.65, 0.62), low * (0.38 + grime * 0.28));
	col *= 1.0 - grime * (0.18 * low * (0.52 + 0.48 * n_lo) + 0.12 * under);
	if (use_wuv) {
		float foot_skirt = (1.0 - smoothstep(0.0, 0.88, wpos.y + (n_lo - 0.5) * 0.38)) * vert;
		col = mix(col, vec3(0.17, 0.165, 0.155), foot_skirt * 0.58);
		seam_ao = max(seam_ao, foot_skirt * 0.55);
		float moss = low * smoothstep(0.36, 0.74, n_lo * 0.62 + macro_w * 0.38) * grime;
		col = mix(col, mix(dust_color.rgb * 0.58, vec3(0.13, 0.16, 0.11), 0.38), moss * 0.45);
		float u_wall = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
		float drip_b = texture(noise_lo, vec2(u_wall * 0.055, wpos.y * 0.012) + vec2(0.31, 0.67)).r;
		float drip_s = texture(noise_lo, vec2(u_wall * 0.21 + (drip_b - 0.5) * 0.16, wpos.y * 0.025) + vec2(0.13, 0.41)).r;
		float drip = smoothstep(0.42, 0.76, drip_s * 0.68 + drip_b * 0.32) * vert * (0.48 + 0.52 * grime);
		float macro_soot = texture(noise_lo, vec2(u_wall * 0.018, wpos.y * 0.022) + vec2(0.53, 0.19)).r;
		col *= mix(0.80, 1.10, macro_soot) * (1.0 - drip * 0.30);
		rough = mix(rough, 0.95, max(drip * 0.60, foot_skirt * 0.75));
	} else {
		col = mix(col, dust_color.rgb * 0.72, grime * low * 0.18 * smoothstep(0.38, 0.72, n_lo));
	}
	float water_band = use_wuv ? (1.0 - smoothstep(0.06, 0.34, wpos.y)) * smoothstep(0.015, 0.055, wpos.y) * (1.0 - smoothstep(0.82, 0.96, wnrm.y)) : 0.0;
	if (water_band > 0.01) {
		col *= mix(1.0, 0.56, water_band);
		rough = mix(rough, 0.22, water_band * 0.82);
	}

	float streak = (rust > 0.01 && vert > 0.05) ? smoothstep(0.54, 0.86, n_sc) * vert * smoothstep(0.34, 0.72, n_lo) : 0.0;
	if (streak > 0.005) {
		vec3 eff_rust = metal_wear > 0.5 ? rust_color.rgb : (base_c * 0.50 + vec3(0.026, 0.022, 0.018));
		col = mix(col, eff_rust, rust * streak * 0.66);
		rough = mix(rough, 0.94, rust * streak * 0.76);
	}
	if (near_det && metal_wear > 0.01 && vert > 0.05 && grime > 0.01) {
		float oil = smoothstep(0.70, 0.94, texture(noise_hi, vec2(uv_dom.x * 7.0, uv_dom.y * 0.65) + 0.5).r) * vert * metal_wear * grime;
		col *= 1.0 - oil * 0.24;
		rough = mix(rough, 0.30, oil * 0.55);
	}

	// 倒角棱边曲率微磨亮：金属/漆面棱边经深色防锈底漆圈过渡至高反光冷轧裸钢（对齐 B.o.T 三层硬边掉漆）
	float edge_gain = mix(0.065, 0.12 + 0.10 * metal_base, metal_wear);
	col *= 1.0 + edge * edge_gain * (1.0 - low * 0.55);
	rough = max(0.15, rough - edge * mix(0.03, 0.16, metal_wear));
	float chipn = n_hi * 0.64 + n_mid * 0.42 + n_lo * 0.34;
	float eff_edge = edge * clamp(wear * 1.55, 0.0, 1.0);
	float chip_mask = eff_edge * smoothstep(0.76 - wear * 0.28, 0.94 - wear * 0.28, chipn);
	float scr = smoothstep(0.86, 0.92, n_sc) * scratches * (1.0 - seam) * smoothstep(0.48, 0.72, n_lo);
	float wm = max(chip_mask, scr);
	float worn = smoothstep(0.36, 0.66, wm) * 0.90;
	float primer = clamp(eff_edge * smoothstep(0.62 - wear * 0.24, 0.80 - wear * 0.24, chipn) - worn, 0.0, 1.0) * 0.72;
	vec3 primer_col = mix(base_c * 0.78, mix(base_c * 0.42, vec3(0.16, 0.10, 0.08), 0.48), metal_wear);
	col = mix(col, primer_col, primer);
	vec3 exposed_metal = mix(base_c * 1.18 + vec3(0.10), bare_metal.rgb, 0.65) * (0.88 + 0.20 * n_hi);
	vec3 exposed_stone = (base_c * 1.12 + vec3(0.020)) * (0.94 + 0.10 * n_hi);
	col = mix(col, mix(exposed_stone, exposed_metal, metal_wear), worn);
	met = mix(met, mix(met, 0.93, metal_wear), worn);
	float worn_rough = mix(0.90, 0.22 + 0.10 * n_hi, metal_wear);
	rough = mix(rough, 0.84, primer);
	rough = mix(rough, worn_rough, worn);
	rough *= 1.0 - eff_edge * 0.18 * metal_wear;

	float dmg = clamp(mech_damage * takes_damage, 0.0, 1.0);
	if (dmg > 0.01) {
		float n_sc2 = texture(noise_lo, uv_dom * 1.3 + vec2(3.1, 7.7)).r;
		float bv = n_sc2 + n_hi * 0.15;
		float heat = smoothstep(0.84 - dmg * 0.32, 0.98 - dmg * 0.32, bv);
		float burn = smoothstep(0.93 - dmg * 0.32, 1.03 - dmg * 0.32, bv);
		col = mix(col, col * vec3(0.55, 0.42, 0.32), heat * 0.8);
		col = mix(col, vec3(0.03, 0.028, 0.025), burn * 0.92);
		rough = mix(rough, 0.95, heat);
		met = mix(met, 0.0, heat);
		float hn = texture(noise_hi, uv_dom * 7.0 + vec2(5.0)).r;
		float hole = smoothstep(0.8 - dmg * 0.06, 0.82 - dmg * 0.06, hn) * step(0.45, n_sc2) * step(0.2, dmg);
		col = mix(col, vec3(0.01), hole);
		rough = mix(rough, 1.0, hole);
	}

	float wet_g = clamp(weather_wet, 0.0, 1.0);
	float up = smoothstep(0.62, 0.96, wnrm.y);
	float d = up * dust * (1.0 - wet_g * 0.84) * smoothstep(0.58, 0.86, n_lo + n_hi * 0.2);
	col = mix(col, dust_color.rgb, d * 0.28);
	rough = mix(rough, 0.84, d * 0.45);
	met = mix(met, met * 0.55, d * 0.45);

	float puddle = 0.0;
	float soak = 0.0;
	float surf_wet = 0.0;
	vec2 rip_n = vec2(0.0);
	if (wet_g > 0.01) {
		float porous = 1.0 - metal_wear;
		float near_ground = smoothstep(1.65, 0.25, wpos.y);
		float flat_up = smoothstep(0.80, 0.95, wnrm.y) * porous;
		float shelter = 1.0 - smoothstep(-0.08, -0.55, wnrm.y);
		float w_up = clamp(wnrm.y, 0.0, 1.0);
		float rain_str = texture(noise_hi, vec2((wpos.x + wpos.z) * 0.82, wpos.y * 0.14)).r;
		float wall_wash = vert * (0.28 + 0.52 * smoothstep(0.36, 0.78, rain_str) * smoothstep(0.28, 0.74, macro_w));
		float splash_band = (1.0 - smoothstep(0.04, 0.85, wpos.y)) * (0.48 + 0.52 * n_lo);
		surf_wet = wet_g * shelter * clamp(max(max(w_up * 0.72, wall_wash * 0.58), splash_band * 0.78), 0.0, 1.0);

		float damp = 0.0;
		float p_deep = 0.0;
		if (flat_up > 0.01 && near_ground > 0.01) {
			float wb1 = texture(noise_lo, wpos.xz * 0.048 + vec2(0.31, 0.73)).r;
			float wb2 = texture(noise_lo, wpos.xz * 0.115 + vec2(4.17, 1.89)).r;
			float rut_bias = stripes > 0.5 ? -0.06 : clamp(0.28 - dot(base_c, vec3(0.333)), -0.04, 0.06) * 0.24;
			float pf_raw = 0.50 + (wb1 - 0.5) * 0.82 + (wb2 - 0.5) * 0.38;
			float pf = pf_raw + rut_bias - seam * 0.06;
			float p_gate = wet_g * flat_up * near_ground;
			puddle = p_gate * smoothstep(0.785, 0.875, pf);
			p_deep = smoothstep(0.825, 0.920, pf);
			soak = p_gate * smoothstep(0.715, 0.825, pf);
			damp = wet_g * flat_up * smoothstep(0.380, 0.640, pf);
			if (puddle > 0.02 && weather_rain > 0.01 && cam_d2 < 900.0) {
				float rip_fade = (1.0 - smoothstep(12.0, 30.0, sqrt(cam_d2))) * clamp(weather_rain, 0.0, 1.0);
				if (rip_fade > 0.015) {
					rip_n = rain_ripple(wpos.xz, TIME) * puddle * rip_fade;
				}
			}
		}
		float total_damp = max(surf_wet, damp * 0.72);
		float wet_any = clamp(max(total_damp, soak), 0.0, 1.0);
		float col_lum = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 wet_chroma = max(mix(vec3(col_lum), col, 1.0 + 0.08 * wet_any), vec3(0.0));
		col = mix(col, wet_chroma, wet_any);
		col *= mix(1.0, mix(0.92, 0.82, porous), total_damp * (1.0 - soak * 0.60));
		col *= mix(1.0, mix(0.90, 0.82, porous), soak);
		vec3 puddle_col = mix(col * 0.80, mix(col * 0.64, vec3(0.018, 0.024, 0.032), 0.28), p_deep);
		col = mix(col, puddle_col, puddle);

		rough = mix(rough, min(rough, mix(0.60, 0.54, porous)), total_damp * 0.42);
		rough = mix(rough, 0.48, soak * 0.52);
		rough = mix(rough, mix(0.34, 0.28, p_deep), puddle);
	}

	float ns = use_albedo_tex > 0.5 ? ts : 1.25;
	float uv_fw = length(fwidth(p_tex)) * ns;
	float nfade = clamp(1.0 - uv_fw * (use_wuv ? 1.25 : 2.10), 0.0, 1.0);
	float n_amt = clamp((normal_strength * (use_wuv ? 1.18 : 1.0) + seam * 0.30 + worn * 0.18) * nfade, 0.0, 1.35) * (1.0 - puddle * 0.90);
	float mac_n_amt = (use_wuv && use_albedo_tex > 0.5) ? clamp(normal_strength * 0.58 * clamp(1.0 - uv_fw * 0.36, 0.0, 1.0), 0.0, 0.85) * (1.0 - puddle * 0.90) : 0.0;
	vec3 w_pert = wnrm;
	if (n_amt > 0.02 || mac_n_amt > 0.02 || seam > 0.005) {
		vec3 dp_loc;
		vec2 m_noff = vec2(0.37, 0.19);
		float mns = ns * 0.27;
		if (single_plane) {
			vec2 td = (n_amt > 0.02 ? (texture(normal_tex, tuv_dom * ns).rg * 2.0 - 1.0) * n_amt : vec2(0.0))
				+ (mac_n_amt > 0.02 ? (texture(normal_tex, tuv_dom * mns + m_noff).rg * 2.0 - 1.0) * mac_n_amt : vec2(0.0))
				+ seam_n * (1.0 - puddle * 0.85);
			dp_loc = dom_x ? vec3(0.0, td.y, td.x) : (dom_y ? (roof_uv > 0.5 ? vec3(-td.y, 0.0, td.x) : vec3(td.x, 0.0, -td.y)) : vec3(td.x, td.y, 0.0));
		} else {
			vec2 tx = ((n_amt > 0.02 && w.x > 0.05) ? (texture(normal_tex, tuv_x * ns).rg * 2.0 - 1.0) * n_amt : vec2(0.0))
				+ ((mac_n_amt > 0.02 && w.x > 0.05) ? (texture(normal_tex, tuv_x * mns + m_noff).rg * 2.0 - 1.0) * mac_n_amt : vec2(0.0))
				+ (w.x > 0.5 ? seam_n * (1.0 - puddle * 0.85) : vec2(0.0));
			vec2 ty = ((n_amt > 0.02 && w.y > 0.05) ? (texture(normal_tex, tuv_y * ns).rg * 2.0 - 1.0) * n_amt : vec2(0.0))
				+ ((mac_n_amt > 0.02 && w.y > 0.05) ? (texture(normal_tex, tuv_y * mns + m_noff).rg * 2.0 - 1.0) * mac_n_amt : vec2(0.0))
				+ (w.y > 0.5 ? seam_n * (1.0 - puddle * 0.85) : vec2(0.0));
			vec2 tz = ((n_amt > 0.02 && w.z > 0.05) ? (texture(normal_tex, tuv_z * ns).rg * 2.0 - 1.0) * n_amt : vec2(0.0))
				+ ((mac_n_amt > 0.02 && w.z > 0.05) ? (texture(normal_tex, tuv_z * mns + m_noff).rg * 2.0 - 1.0) * mac_n_amt : vec2(0.0))
				+ (w.z > 0.5 ? seam_n * (1.0 - puddle * 0.85) : vec2(0.0));
			vec3 p_x = vec3(0.0, tx.y, tx.x);
			vec3 p_y = roof_uv > 0.5 ? vec3(-ty.y, 0.0, ty.x) : vec3(ty.x, 0.0, -ty.y);
			vec3 p_z = vec3(tz.x, tz.y, 0.0);
			dp_loc = p_x * w.x + p_y * w.y + p_z * w.z;
		}
		dp_loc -= n_loc * dot(dp_loc, n_loc);
		mat3 v_rot = mat3(rot_x, rot_y, rot_z);
		vec3 w_sum = wnrm + v_rot * dp_loc;
		w_pert = length(w_sum) > 1e-4 ? normalize(w_sum) : wnrm;
	}
	if (puddle > 0.01) {
		vec3 w_water = normalize(vec3(rip_n.x, 1.0, rip_n.y));
		w_pert = normalize(mix(w_pert, w_water, puddle * 0.92));
	}
	vec3 v_n = (VIEW_MATRIX * vec4(w_pert, 0.0)).xyz;
	NORMAL = length(v_n) > 1e-4 ? normalize(v_n) : NORMAL;

	// 将原漆面清漆与雨湿微光柔和折入单叶 GGX Roughness/Specular，免去每盏灯的双重 Clearcoat BRDF 计算
	float dry_coat = (1.0 - worn * 0.7) * (1.0 - d) * (1.0 - rust * streak) * metal_wear * clamp(0.66 - rough_base, 0.0, 0.45) * 0.34;
	float wet_coat = max(puddle * 0.14, max(soak * 0.04, surf_wet * mix(0.02, 0.06, metal_wear)));
	float coat_hint = max(dry_coat, wet_coat);
	rough *= 1.0 - coat_hint * 0.18;

	ALBEDO = col;
	METALLIC = met;
	vec3 dn = fwidth(NORMAL);
	float var_n = dot(dn, dn) * (1.0 - puddle * 0.82);
	float r2 = max(rough * rough + min(1.2 * var_n, 0.22), 0.0);
	ROUGHNESS = clamp(sqrt(r2), mix(0.10, 0.22, puddle), 1.0);

	float tex_ao = use_albedo_tex > 0.5 ? clamp((0.68 - tex_luma) * (use_wuv ? 0.92 : 0.62), 0.0, use_wuv ? 0.42 : 0.30) : 0.0;
	float base_spec = mix(use_wuv ? 0.30 : 0.48, 0.90, max(worn, metal_base * 0.65) * metal_wear);
	SPECULAR = clamp(mix(base_spec, 0.44, max(puddle * 0.65, soak * 0.22)) + coat_hint * 0.28 + water_band * 0.36, 0.0, 1.0);
	AO = clamp(1.0 - tex_ao * (1.0 - puddle * 0.65) - seam * mix(0.22, 0.36, metal_wear) - seam_ao * mix(0.10, 0.12, metal_wear) - primer * 0.14 - low * grime * 0.20 - under * 0.10, 0.46, 1.0);
	AO_LIGHT_AFFECT = use_wuv ? 0.32 : 0.16;
	if (metal_wear > 0.5) {
		vec3 v_w = normalize(CAMERA_POSITION_WORLD - wpos);
		float ndv_r = clamp(dot(w_pert, v_w), 0.0, 1.0);
		float sky_up = smoothstep(-0.20, 0.72, w_pert.y);
		float rim_f = pow(1.0 - ndv_r, 2.6) * sky_up * (0.34 + 0.66 * edge + 0.32 * metal_base);
		float rim_str = mix(0.020, 0.064, takes_damage);
		EMISSION = vec3(0.68, 0.82, 1.0) * (rim_f * rim_str * (1.0 - rough * 0.45));
	}
}
