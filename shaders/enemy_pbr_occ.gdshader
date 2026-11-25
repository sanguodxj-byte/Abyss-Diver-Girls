shader_type spatial;
// 《B.o.T》敌群构装体硬派军工 PBR 着色器（遮挡透视同步版，配套 enemy_pbr.gdshader）
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx, ensure_correct_normals;
#include "res://shaders/occ_fade.gdshaderinc"

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float metal_base : hint_range(0.0, 1.0) = 0.05;
uniform float rough_base : hint_range(0.0, 1.0) = 0.56;
uniform float wear : hint_range(0.0, 1.0) = 0.58;
uniform float rust : hint_range(0.0, 1.0) = 0.18;
uniform float grime : hint_range(0.0, 1.0) = 0.44;
uniform float dust : hint_range(0.0, 1.0) = 0.26;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.92;
uniform float detail_scale : hint_range(0.2, 6.0) = 1.15;
uniform int tint_mode = 0;
uniform float occ_exempt = 0.0;
uniform float occ_self_fade = 0.0;

uniform vec4 bare_metal : source_color = vec4(0.56, 0.59, 0.63, 1.0);
uniform vec4 primer_tint : source_color = vec4(0.22, 0.15, 0.12, 1.0);
uniform vec4 rust_color : source_color = vec4(0.34, 0.16, 0.08, 1.0);
uniform vec4 dust_color : source_color = vec4(0.54, 0.48, 0.39, 1.0);

global uniform float weather_wet;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 lpos;
varying vec3 lnrm;
varying vec3 rot_x;
varying vec3 rot_y;
varying vec3 rot_z;
varying float v_edge;
varying vec3 v_tint;

vec3 srgb_to_lin(vec3 c) {
	vec3 sc = max(c, vec3(0.0));
	return mix(pow((sc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), sc * (1.0 / 12.92), lessThan(sc, vec3(0.04045)));
}

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
	vec3 n_sc = NORMAL / sc;
	lnrm = length(n_sc) > 1e-4 ? normalize(n_sc) : vec3(0.0, 1.0, 0.0);
	wnrm = normalize(rot_m * lnrm);
	lpos = VERTEX * sc;
	v_edge = clamp(1.0 - COLOR.r, 0.0, 1.0);
	v_tint = (tint_mode == 1) ? srgb_to_lin(COLOR.gba) : vec3(1.0);
}

void fragment() {
	if (occ_self_fade > 0.005) {
		highp vec3 dc_s = INV_VIEW_MATRIX[3].xyz - occ_cam_pos;
		if (dot(dc_s, dc_s) <= 0.25) {
			if (occ_ign(FRAGCOORD.xy) < clamp(occ_self_fade, 0.0, 0.92)) {
				discard;
			}
		}
	}

	vec3 n_w = FRONT_FACING ? normalize(wnrm) : -normalize(wnrm);
	vec3 n_loc = FRONT_FACING ? normalize(lnrm) : -normalize(lnrm);
	vec3 an = abs(n_loc);
	vec3 p = lpos * detail_scale;
	bool dom_x = (an.x >= an.y && an.x >= an.z);
	bool dom_y = (!dom_x && an.y >= an.z);
	vec2 tuv = dom_x ? p.zy : (dom_y ? p.xz : p.xy);

	vec3 ta = texture(albedo_tex, tuv * 0.72).rgb;
	float tr = texture(rough_tex, tuv * 0.72).r;
	float n_macro = texture(noise_lo, lpos.xy * 0.36 + lpos.zz * 0.28 + vec2(0.31, 0.57)).r;
	float n_lo = texture(noise_lo, lpos.xz * 0.92 + lpos.yy * 0.64 + vec2(0.17, 0.43)).r;
	float n_hi = texture(noise_lo, tuv * 2.65 + vec2(0.41, 0.19)).r;
	float mottle = n_macro * 0.58 + n_lo * 0.42;

	float is_dielectric = 1.0 - smoothstep(0.35, 0.65, metal_base);
	vec3 bc = base_color.rgb * v_tint;
	vec3 min_m = mix(vec3(0.026, 0.028, 0.032), vec3(0.088, 0.094, 0.105), metal_base);
	bc = max(bc, min_m);

	float t_lum = clamp(dot(ta, vec3(0.333)) * 1.38, 0.68, 1.24);
	vec3 col = bc * mix(1.0, t_lum, 0.58) * (0.90 + 0.20 * mottle);

	float anat_grad = clamp(0.56 + 0.28 * n_w.y + clamp(lpos.y * 0.16, -0.18, 0.22), 0.18, 1.0);
	col *= mix(0.78, 1.08, anat_grad);

	float met = metal_base;
	float rough = clamp(mix(rough_base, tr, 0.44) + (mottle - 0.5) * 0.14 + (0.5 - n_hi) * 0.06, 0.14, 0.95);

	float down_cav = clamp((0.35 - n_w.y) * 0.55 + (1.0 - t_lum) * 0.45, 0.0, 1.0);
	float grime_m = down_cav * grime;
	col *= 1.0 - grime_m * 0.44;
	rough = mix(rough, 0.90, grime_m * 0.50);
	met *= 1.0 - clamp(grime_m * 0.35, 0.0, 0.55);

	float vert = 1.0 - abs(n_w.y);
	float n_streak = texture(noise_lo, vec2((lpos.x + lpos.z) * 2.1, lpos.y * 0.45)).r;
	if (rust > 0.01) {
		float r_mask = smoothstep(0.54, 0.84, mottle * 0.48 + n_streak * 0.52) * (0.38 + 0.62 * vert) * rust;
		col = mix(col, rust_color.rgb, r_mask * 0.66);
		rough = mix(rough, 0.92, r_mask * 0.72);
		met *= 1.0 - r_mask * 0.70;
	}

	float curv_fw = smoothstep(0.012, 0.065, length(fwidth(n_w)));
	float edge_sharp = clamp(max(v_edge * mix(0.45, 1.0, curv_fw), curv_fw * 0.72), 0.0, 1.0);
	float wear_sig = edge_sharp * (0.48 + 0.74 * wear) * (0.52 + 0.58 * n_hi);

	float primer_m = smoothstep(0.44, 0.56, wear_sig) * (1.0 - smoothstep(0.58, 0.72, wear_sig)) * is_dielectric;
	col = mix(col, mix(bc * 0.55, primer_tint.rgb, 0.45), primer_m * 0.54);
	rough = mix(rough, 0.82, primer_m * 0.52);
	met = mix(met, 0.05, primer_m * 0.58);

	float steel_m = smoothstep(0.56, 0.78, wear_sig);
	vec3 raw_steel = bare_metal.rgb * (0.88 + 0.18 * n_hi);
	col = mix(col, raw_steel, steel_m * mix(0.78, 0.36, metal_base));
	met = mix(met, 0.88, steel_m * 0.85);
	rough = mix(rough, 0.26 + 0.08 * n_hi, steel_m * 0.80);
	col *= 1.0 + edge_sharp * 0.09;

	float wet_g = clamp(weather_wet, 0.0, 1.0);
	float up = smoothstep(0.52, 0.94, n_w.y);
	float top_dust = up * dust * (1.0 - wet_g * 0.82) * smoothstep(0.42, 0.82, mottle);
	float foot_mud = (1.0 - smoothstep(0.05, 0.95, wpos.y)) * dust * (0.52 + 0.48 * smoothstep(0.32, 0.76, n_lo));
	float dust_all = clamp(max(top_dust * 0.46, foot_mud * 0.74), 0.0, 0.82);
	vec3 eff_dust = mix(dust_color.rgb, dust_color.rgb * 0.58, wet_g);
	col = mix(col, eff_dust, dust_all * 0.54);
	rough = mix(rough, mix(0.88, 0.36, wet_g), dust_all * 0.64);
	met *= 1.0 - dust_all * 0.60;

	if (wet_g > 0.01) {
		float wet_f = wet_g * clamp(up * 0.75 + vert * 0.45, 0.0, 1.0);
		col *= mix(1.0, 0.86, wet_f);
		rough = mix(rough, min(rough, 0.24), wet_f * 0.58);
	}

	float det_fw = length(fwidth(tuv));
	float det_fade = clamp(1.0 - det_fw * 2.4, 0.0, 1.0);
	if (det_fade > 0.02 && normal_strength > 0.01) {
		vec2 dn2 = (texture(normal_tex, tuv * 0.72).rg * 2.0 - 1.0) * (normal_strength * 0.42 * det_fade);
		vec3 dp_loc = dom_x ? vec3(0.0, dn2.y, dn2.x) : (dom_y ? vec3(dn2.x, 0.0, -dn2.y) : vec3(dn2.x, dn2.y, 0.0));
		dp_loc -= n_loc * dot(dp_loc, n_loc);
		mat3 v_rot = mat3(rot_x, rot_y, rot_z);
		vec3 w_pert = normalize(n_w + v_rot * dp_loc);
		vec3 v_n = (VIEW_MATRIX * vec4(w_pert, 0.0)).xyz;
		if (length(v_n) > 1e-4) {
			NORMAL = normalize(v_n);
		}
	}

	vec3 dn_v = fwidth(NORMAL);
	float rough_aa = sqrt(clamp(rough * rough + min(1.10 * dot(dn_v, dn_v), 0.18), 0.02, 1.0));

	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = clamp(rough_aa, 0.15, 0.96);
	SPECULAR = clamp(mix(0.46, 0.88, max(steel_m, smoothstep(0.3, 0.9, met))) + wet_g * 0.10, 0.0, 1.0);
	AO = clamp(0.72 + 0.28 * anat_grad - grime_m * 0.22, 0.25, 1.0);
	AO_LIGHT_AFFECT = 0.45;

	vec3 v_w = normalize(CAMERA_POSITION_WORLD - wpos);
	float ndv = clamp(dot(n_w, v_w), 0.0, 1.0);
	float sky_up = smoothstep(-0.15, 0.78, n_w.y);
	float rim_f = pow(1.0 - ndv, 3.2) * sky_up * (0.18 + 0.54 * edge_sharp + 0.28 * met);
	EMISSION = vec3(0.74, 0.82, 0.92) * (rim_f * 0.022 * (1.0 - rough * 0.55));
}
