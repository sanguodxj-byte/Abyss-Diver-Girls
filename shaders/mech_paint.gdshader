shader_type spatial;
// 写实机甲涂装：三平面噪声细节 + 倒角边缘掉漆露金属 + 面板接缝 + 积灰 + 锈迹流痕 + 底部泥污。
// 倒角网格把棱边顶点色 R 设为 0（平面为 1），这里用 1-COLOR.r 作为边缘遮罩。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

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
uniform float takes_damage = 0.0;                      // 1 = 随机甲受损程度出现烧蚀/弹痕
global uniform float mech_damage;
uniform vec4 bare_metal : source_color = vec4(0.62, 0.62, 0.6, 1.0);
uniform vec4 dust_color : source_color = vec4(0.52, 0.46, 0.38, 1.0);
uniform vec4 rust_color : source_color = vec4(0.36, 0.17, 0.08, 1.0);
uniform sampler2D noise_lo : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_albedo_tex = 0.0;
uniform float albedo_tex_scale = 0.18;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;
varying vec3 wnrm;
varying float edge;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	edge = 1.0 - COLOR.r;
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(6.0));
	return w / (w.x + w.y + w.z + 1e-5);
}

float tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy).r * w.x + texture(t, p.xz).r * w.y + texture(t, p.xy).r * w.z;
}

void fragment() {
	vec3 w = tri_w(lnrm);
	vec3 p = lpos * detail_scale;
	float n_lo = tri(noise_lo, p * 0.35 + wpos * 0.02, w);
	float n_hi = tri(noise_hi, p * 2.2, w);
	float n_sc = tri(noise_hi, p * vec3(9.0, 1.2, 9.0), w); // 拉长的划痕噪声

	vec3 col = base_color.rgb * (0.9 + 0.16 * n_lo) * (0.98 + 0.03 * n_hi);
	if (use_albedo_tex > 0.5) {
		vec3 tp = wpos * albedo_tex_scale;
		vec3 tw = tri_w(wnrm);
		vec3 at = texture(albedo_tex, tp.zy).rgb * tw.x + texture(albedo_tex, tp.xz).rgb * tw.y + texture(albedo_tex, tp.xy).rgb * tw.z;
		col *= at * 1.5;
	}
	float met = metal_base;
	float rough = rough_base * (0.9 + 0.2 * n_hi);

	// 警示条纹
	if (stripes > 0.5) {
		float s = fract((p.x + p.y + p.z) * 2.2);
		float sw = max(fwidth(s), 1e-4);
		col = mix(vec3(0.05), vec3(0.95, 0.66, 0.1), smoothstep(0.5 - sw, 0.5 + sw, s)) * (0.85 + 0.25 * n_lo);
	}

	// 面板接缝：沿主投影平面画细线
	float seam = 0.0;
	if (panel_scale > 0.0) {
		vec2 uv = w.x > 0.5 ? p.zy : (w.y > 0.5 ? p.xz : p.xy);
		vec2 g = uv * panel_scale;
		g += vec2(0.13, 0.31);
		vec2 f = abs(fract(g) - 0.5);
		// 按屏幕导数做抗锯齿：线宽至少 1 像素过渡，远处线条比像素还细时淡出，避免闪烁
		vec2 fw = max(fwidth(g), vec2(1e-4));
		vec2 dist = 0.5 - f;
		float lw = 0.004;
		float lx = 1.0 - smoothstep(lw, lw + fw.x * 1.5, dist.x);
		float ly = 1.0 - smoothstep(lw, lw + fw.y * 1.5, dist.y);
		float fade = clamp(1.0 - (max(fw.x, fw.y) - 0.01) * 18.0, 0.0, 1.0);
		seam = max(lx, ly) * fade;
		col *= 1.0 - seam * 0.65;
		rough = mix(rough, 0.9, seam);
	}

	// 缝隙/底部暗化
	float low = 1.0 - smoothstep(0.0, 1.4, wpos.y);
	col *= 1.0 - grime * (0.45 * low * (0.6 + 0.6 * n_lo));
	col = mix(col, dust_color.rgb * 0.6, grime * low * 0.5 * smoothstep(0.4, 0.7, n_lo));

	// 锈迹流痕：垂直面上自上而下的条带
	float vert = 1.0 - abs(wnrm.y);
	float streak = smoothstep(0.55, 0.85, n_sc) * vert * smoothstep(0.35, 0.65, n_lo);
	col = mix(col, rust_color.rgb, rust * streak * 0.8);
	rough = mix(rough, 0.95, rust * streak);

	// 边缘掉漆 → 露出金属
	float chipn = n_hi * 0.8 + n_lo * 0.5;
	float chip = edge * smoothstep(0.95 - wear * 0.35, 1.05 - wear * 0.35, chipn);
	float scr = smoothstep(0.85, 0.89, n_sc) * scratches * (1.0 - seam) * smoothstep(0.5, 0.7, n_lo);
	float wm = max(chip, scr);
	float worn = smoothstep(0.5, 0.8, wm);
	// 掉漆边缘的深色描边（底漆）
	float primer = clamp(edge * smoothstep(0.85 - wear * 0.35, 0.95 - wear * 0.35, chipn) - worn, 0.0, 1.0);
	col = mix(col, col * 0.45, clamp(primer, 0.0, 1.0) * 0.8);
	col = mix(col, bare_metal.rgb * 0.75 * (0.85 + 0.3 * n_hi), worn);
	// 棱边整体略微提亮（磨损抛光）
	col *= 1.0 + edge * 0.08;
	met = mix(met, 0.95, worn);
	rough = mix(rough, 0.32 + 0.2 * n_hi, worn);

	// 战损：烧蚀焦黑 + 更多掉漆（随结构值降低）
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
		// 弹孔：小而深
		float hn = tri(noise_hi, p * 7.0 + vec3(5.0), w);
		float hole = smoothstep(0.8 - dmg * 0.06, 0.82 - dmg * 0.06, hn) * step(0.45, n_sc2) * step(0.2, dmg);
		col = mix(col, vec3(0.01), hole);
		rough = mix(rough, 1.0, hole);
	}

	// 积灰：朝上的面
	float up = smoothstep(0.55, 0.95, wnrm.y);
	float d = up * dust * smoothstep(0.55, 0.8, n_lo + n_hi * 0.2);
	col = mix(col, dust_color.rgb, d * 0.85);
	rough = mix(rough, 0.95, d);
	met = mix(met, 0.0, d);

	ALBEDO = col;
	METALLIC = met;
	// 几何高光抗锯齿（Kaplanyan）：法线在一个像素内变化越大，粗糙度越高，消除细小倒角上的高光闪烁
	vec3 dn = fwidth(NORMAL);
	float var_n = dot(dn, dn);
	float r2 = rough * rough + min(2.0 * var_n, 0.25);
	ROUGHNESS = clamp(sqrt(r2), 0.08, 1.0);
	// 三平面法线细节（锤击金属感）
	vec3 nm = texture(normal_tex, (w.x > 0.5 ? p.zy : (w.y > 0.5 ? p.xz : p.xy)) * 1.3).rgb;
	// 细节法线随距离淡出（纹素小于像素时只会产生噪点）
	float nfade = clamp(1.0 - length(fwidth(p * 1.3)) * 3.0, 0.0, 1.0);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nm, (0.08 + seam * 0.5 + d * 0.3) * nfade);
	SPECULAR = 0.5;
}
