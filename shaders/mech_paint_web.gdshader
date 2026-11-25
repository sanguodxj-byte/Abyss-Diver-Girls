shader_type spatial;
// Web 专用材质：保留装甲配色、贴图、磨损与遮挡淡出，限制片元分支以缩短 WebGL 编译。
// 使用主轴单平面映射替代三平面 3 倍采样、使用 Lambert 漫反射并省略 Clearcoat 分支，大幅降低移动 GPU 带宽与着色开销。
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
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float use_rough_tex = 0.0;
uniform float rough_tex_strength : hint_range(0.0, 1.0) = 0.0;

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
    if (occ_self_fade > 0.005) {
        vec3 dc = INV_VIEW_MATRIX[3].xyz - occ_cam_pos;
        if (dot(dc, dc) < 0.25 && occ_ign(FRAGCOORD.xy) < occ_self_fade) discard;
    } else if (occ_exempt < 0.5) {
        if (occ_clip_whole_bldg(wpos, INV_VIEW_MATRIX[3].xyz)) discard;
        if (occ_params.x > 0.005 && occ_ign(FRAGCOORD.xy) < occ_calc_fade(wpos, INV_VIEW_MATRIX[3].xyz, occ_params.x, 0.40)) discard;
    }
    vec3 an = abs(normalize(lnrm));
    vec3 p = lpos * detail_scale;
    vec2 uv = an.x >= an.y && an.x >= an.z ? vec2(p.z, -p.y) : (an.y >= an.z ? p.xz : vec2(p.x, -p.y));
    vec3 base = base_color.rgb * tint;
    vec3 at = texture(albedo_tex, uv * albedo_tex_scale * 1.6).rgb;
    float noise = texture(noise_lo, uv * 0.42).r;
    vec3 col = base * mix(vec3(1.0), at * 1.48, use_albedo_tex * albedo_tex_strength);
    col *= 0.94 + 0.12 * noise;
    float low = (1.0 - smoothstep(0.0, 1.85, wpos.y)) * (1.0 - abs(wnrm.y));
    col *= 1.0 - grime * low * 0.32;
    col = mix(col, dust_color.rgb, max(wnrm.y, 0.0) * dust * noise * 0.12);
    col = mix(col, rust_color.rgb, rust * smoothstep(0.65, 0.92, noise) * 0.30);
    col += edge * wear * base * 0.24;
    if (stripes > 0.5) {
        float band = step(0.5, fract((p.x + p.y + p.z) * 2.2));
        col = mix(vec3(0.06), vec3(0.86, 0.60, 0.11), band);
    }
    float dmg = clamp(mech_damage * takes_damage, 0.0, 1.0);
    col *= 1.0 - dmg * smoothstep(0.45, 0.9, noise) * 0.7;
    ALBEDO = col * (1.0 - weather_wet * 0.10);
    METALLIC = metal_base;
    ROUGHNESS = clamp(rough_base - weather_wet * 0.16, 0.25, 1.0);
    SPECULAR = 0.45;
}
