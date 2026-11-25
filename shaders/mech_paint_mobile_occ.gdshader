shader_type spatial;
// 移动端专用轻量写实工业与机甲 PBR 着色器（遮挡穿墙按需版）。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

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
#include "res://shaders/occ_fade.gdshaderinc"
uniform float occ_exempt = 0.0;
uniform float occ_self_fade = 0.0;
uniform vec4 bare_metal : source_color = vec4(0.66, 0.67, 0.69, 1.0);
uniform vec4 dust_color : source_color = vec4(0.48, 0.43, 0.36, 1.0);
uniform vec4 rust_color : source_color = vec4(0.32, 0.16, 0.08, 1.0);
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_albedo_tex = 0.0;
uniform float albedo_tex_scale = 0.24;
uniform float albedo_tex_strength : hint_range(0.0, 1.0) = 0.78;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.55;
uniform sampler2D rough_tex : filter_linear_mipmap, repeat_enable;
uniform float use_rough_tex = 0.0;
uniform float rough_tex_strength : hint_range(0.0, 1.0) = 0.65;

varying highp vec3 lpos;
varying vec3 lnrm;
varying highp vec3 wpos;
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
	highp vec3 p = lpos * detail_scale;

	bool dom_x = an.x >= an.y && an.x >= an.z;
	bool dom_y = !dom_x && an.y >= an.z;
	bool use_wuv = metal_wear < 0.5 && takes_damage < 0.5;
	highp vec3 p_tex = use_wuv ? vec3(dot(wpos, rot_x), dot(wpos, rot_y), dot(wpos, rot_z)) * detail_scale : p;
	highp vec2 uv_p = dom_x ? vec2(p_tex.z, -p_tex.y) : (dom_y ? (roof_uv > 0.5 ? vec2(p_tex.z, p_tex.x) : vec2(p_tex.x, p_tex.z)) : vec2(p_tex.x, -p_tex.y));

	float n_lo = texture(noise_lo, uv_p * 0.42 + wpos.xz * 0.015).r;
	float n_hi = texture(noise_hi, uv_p * 2.1).r;

	vec3 base_c = base_color.rgb * tint;
	if (metal_wear > 0.5) {
		vec3 min_m = mix(vec3(0.036, 0.039, 0.045), vec3(0.115, 0.122, 0.135), metal_base);
		base_c = max(base_c, min_m);
		base_c = mix(base_c, sqrt(base_c) * 0.58, metal_base * 0.22);
	}
	vec3 col = base_c * (0.97 + 0.06 * n_lo) * (0.985 + 0.03 * n_hi);
	float tex_luma = 0.7;
	if (use_albedo_tex > 0.5) {
		float ts = albedo_tex_scale * 1.6;
		vec3 at = texture(albedo_tex, uv_p * ts).rgb;
		tex_luma = dot(at, vec3(0.333));
		col *= mix(vec3(1.0), at * 1.48, albedo_tex_strength);
	}
	float met = metal_base;
	float rough = rough_base * (0.93 + 0.12 * n_hi + (0.66 - tex_luma) * 0.10 * use_albedo_tex);
	if (use_rough_tex > 0.5) {
		float rt = texture(rough_tex, uv_p * (albedo_tex_scale * 1.6)).r;
		rough = mix(rough, clamp(mix(rough_base, rt, rough_tex_strength), 0.16, 0.98), 0.82);
	}

	if (stripes > 0.5) {
		float s = fract((p.x + p.y + p.z) * 2.2);
		float band = smoothstep(0.46, 0.52, s) * (1.0 - smoothstep(0.94, 0.99, s));
		col = mix(vec3(0.06, 0.06, 0.065), vec3(0.86, 0.60, 0.11), band) * (0.86 + 0.22 * n_lo);
	}

	float seam = 0.0;
	if (panel_scale > 0.0) {
		float flat_gate = smoothstep(0.88, 0.97, max(an.x, max(an.y, an.z))) * (1.0 - smoothstep(0.02, 0.16, edge));
		if (flat_gate > 0.01) {
			highp vec2 g = uv_p * panel_scale + vec2(0.13, 0.31);
			g.x += mod(floor(g.y), 2.0) * 0.5;
			highp vec2 dist = 0.5 - abs(fract(g) - 0.5);
			vec2 fw = max(fwidth(uv_p) * panel_scale, vec2(1e-4));
			float fade = clamp(1.0 - (max(fw.x, fw.y) - 0.016) * 14.0, 0.0, 1.0) * flat_gate;
			float lw = 0.0055;
			float lx = 1.0 - smoothstep(lw, lw + fw.x * 1.6, dist.x);
			float ly = 1.0 - smoothstep(lw, lw + fw.y * 1.6, dist.y);
			highp float cell_h = fract(sin(dot(floor(g), vec2(127.1, 311.7))) * 43758.5453);
			col *= 1.0 + (cell_h - 0.5) * mix(0.04, 0.055, metal_wear) * flat_gate;
			seam = max(lx, ly) * fade;
			col *= 1.0 - seam * mix(0.18, 0.32, metal_wear);
			rough = mix(rough, 0.90, seam);
		}
	}

	float low = (1.0 - smoothstep(0.0, 1.85, wpos.y)) * (1.0 - smoothstep(0.35, 0.75, abs(wnrm.y)));
	float under = smoothstep(0.25, 0.85, -wnrm.y) * metal_wear;
	col *= mix(vec3(1.0), vec3(0.60, 0.59, 0.57), low * (0.38 + grime * 0.24));
	col *= 1.0 - grime * (0.24 * low * (0.55 + 0.45 * n_lo) + 0.16 * under);

	float vert = 1.0 - abs(wnrm.y);
	float streak = smoothstep(0.54, 0.86, n_hi) * vert * smoothstep(0.34, 0.72, n_lo);
	vec3 eff_rust = metal_wear > 0.5 ? rust_color.rgb : (base_c * 0.50 + vec3(0.026, 0.022, 0.018));
	col = mix(col, eff_rust, rust * streak * 0.64);
	rough = mix(rough, 0.94, rust * streak * 0.76);

	col *= 1.0 + edge * 0.045 * (1.0 - low * 0.65);
	rough = max(0.20, rough - edge * 0.08);
	float chipn = n_hi * 0.62 + n_lo * 0.56;
	float eff_edge = edge * clamp(wear * 1.45, 0.0, 1.0);
	float worn = smoothstep(0.42, 0.74, eff_edge * smoothstep(0.84 - wear * 0.24, 1.02 - wear * 0.24, chipn)) * 0.68;
	vec3 exposed_col = mix((base_c * 1.08 + vec3(0.016)) * 0.94, (base_c * 1.18 + vec3(0.055, 0.058, 0.062)) * (0.90 + 0.14 * n_hi), metal_wear);
	col = mix(col, exposed_col, worn);
	met = mix(met, mix(met, 0.88, metal_wear), worn);
	rough = mix(rough, mix(0.90, 0.24 + 0.12 * n_hi, metal_wear), worn);

	float dmg = clamp(mech_damage * takes_damage, 0.0, 1.0);
	if (dmg > 0.01) {
		float bv = n_lo + n_hi * 0.2;
		float heat = smoothstep(0.84 - dmg * 0.32, 0.98 - dmg * 0.32, bv);
		float burn = smoothstep(0.93 - dmg * 0.32, 1.03 - dmg * 0.32, bv);
		col = mix(col, col * vec3(0.55, 0.42, 0.32), heat * 0.8);
		col = mix(col, vec3(0.03, 0.028, 0.025), burn * 0.92);
		rough = mix(rough, 0.95, heat);
		met = mix(met, 0.0, heat);
	}

	float wet_g = clamp(weather_wet, 0.0, 1.0);
	float up = smoothstep(0.62, 0.96, wnrm.y);
	float d = up * dust * (1.0 - wet_g * 0.82) * smoothstep(0.58, 0.86, n_lo + n_hi * 0.2);
	col = mix(col, dust_color.rgb, d * 0.28);
	rough = mix(rough, 0.84, d * 0.45);

	float puddle_m = 0.0;
	if (wet_g > 0.01) {
		float porous = 1.0 - metal_wear;
		float near_g = smoothstep(1.65, 0.25, wpos.y);
		float flat_up = smoothstep(0.80, 0.95, wnrm.y) * porous;
		float wb = texture(noise_lo, wpos.xz * 0.026 + vec2(0.31, 0.73)).r;
		float pf = 0.50 + (wb - 0.5) * 1.12 + (n_lo - 0.5) * 0.22;
		puddle_m = wet_g * flat_up * near_g * smoothstep(0.71, 0.80, pf);
		float soak_m = wet_g * max(flat_up * near_g * smoothstep(0.62, 0.74, pf), clamp(wnrm.y, 0.0, 1.0) * 0.24);
		col *= mix(1.0, mix(0.94, 0.84, porous), soak_m);
		col = mix(col, col * 0.68 + vec3(0.024, 0.032, 0.044), puddle_m * 0.62);
		rough = mix(rough, min(rough, mix(0.56, 0.48, porous)), soak_m * 0.45);
		rough = mix(rough, 0.18, puddle_m);
	}

	if (normal_strength > 0.05) {
		float ns = use_albedo_tex > 0.5 ? (albedo_tex_scale * 1.6) : 1.25;
		float uv_fw = length(fwidth(uv_p * ns));
		float nfade = clamp(1.0 - uv_fw * 2.05, 0.0, 1.0);
		if (nfade > 0.04) {
			vec2 nm = (texture(normal_tex, uv_p * ns).rg * 2.0 - 1.0) * clamp(normal_strength, 0.0, 0.92) * nfade * (1.0 - puddle_m * 0.78);
			vec3 dp_loc = dom_x ? vec3(0.0, nm.y, nm.x) : (dom_y ? (roof_uv > 0.5 ? vec3(-nm.y, 0.0, nm.x) : vec3(nm.x, 0.0, -nm.y)) : vec3(nm.x, nm.y, 0.0));
			mat3 v_rot = mat3(rot_x, rot_y, rot_z);
			vec3 w_sum = wnrm + v_rot * dp_loc;
			vec3 w_pert = length(w_sum) > 1e-4 ? normalize(w_sum) : wnrm;
			vec3 v_n = (VIEW_MATRIX * vec4(w_pert, 0.0)).xyz;
			NORMAL = length(v_n) > 1e-4 ? normalize(v_n) : NORMAL;
		}
	}

	vec3 dn = fwidth(NORMAL);
	float var_n = dot(dn, dn) * (1.0 - puddle_m * 0.80);
	float tex_ao = use_albedo_tex > 0.5 ? clamp((0.62 - tex_luma) * 0.42, 0.0, 0.20) : 0.0;
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = clamp(sqrt(max(rough * rough + min(1.1 * var_n, 0.20), 0.0)), mix(0.12, 0.09, puddle_m), 1.0);
	SPECULAR = mix(mix(0.46, 0.80, worn * metal_wear), 0.56, puddle_m);
	AO = clamp(1.0 - tex_ao - seam * mix(0.16, 0.36, metal_wear) - low * grime * 0.28 - under * 0.16, 0.42, 1.0);
	AO_LIGHT_AFFECT = 0.42;
	if (occ_fade > 0.01) {
		ALBEDO = occ_soft_mist(ALBEDO, occ_fade);
		ROUGHNESS = mix(ROUGHNESS, 0.96, occ_fade * 0.65);
		SPECULAR *= 1.0 - occ_fade * 0.72;
	}
}
