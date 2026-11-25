shader_type spatial;
// 深渊压电晶簇写实矿物着色器：
// - 利用顶点色通道（R=高度梯度，G=晶棱倒角边掩码，B=晶簇能量档位，A=晶柱随机相位）+ 世界空间 3D 视差内层纹理
// - 实现深邃半透晶体折射层次、水平石英生长纹、锐利晶面高光清漆与克制的内部裂隙/棱边/晶尖发光，杜绝扁平纯色发光块
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.010, 0.044, 0.105);
uniform vec3 mid_color : source_color = vec3(0.032, 0.235, 0.340);
uniform vec3 tip_color : source_color = vec3(0.200, 0.760, 0.850);
uniform vec3 outer_violet : source_color = vec3(0.090, 0.100, 0.320);
uniform vec3 core_glow_color : source_color = vec3(0.200, 0.920, 0.980);
uniform vec3 edge_glow_color : source_color = vec3(0.580, 0.990, 1.000);
uniform float glow_strength : hint_range(0.0, 3.0) = 1.02;

varying highp vec3 wp;
varying vec3 wn;
varying vec4 vcol;

float _hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float _noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = _hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = _hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = _hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = _hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = _hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = _hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = _hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = _hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float _fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.55;
	v += a * _noise3(p);
	p = p * 2.07 + vec3(17.3, 9.1, 23.7);
	a *= 0.5;
	v += a * _noise3(p);
	p = p * 2.03 + vec3(5.4, 31.2, 11.8);
	a *= 0.5;
	v += a * _noise3(p);
	return v;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR;
}

void fragment() {
	vec3 N = normalize(wn);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - wp);
	float ndv = clamp(dot(N, view_dir), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.1);

	float h = clamp(vcol.r, 0.0, 1.0);
	float edge = clamp(vcol.g, 0.0, 1.0);
	float energy = clamp(vcol.b, 0.0, 1.0);
	float phase = vcol.a * 6.2831853;

	// 模拟晶体内部折射视差（两层解理裂隙与内含能量云雾）
	vec3 refr = refract(-view_dir, N, 0.68);
	if (length(refr) < 0.001) {
		refr = -view_dir;
	}
	vec3 p_in1 = wp + refr * 0.45 + vec3(phase * 0.37, 0.0, phase * 0.21);
	vec3 p_in2 = wp + refr * 0.95 + vec3(0.0, phase * 0.43, 0.0);
	float f1 = _fbm3(p_in1 * 2.55);
	float f2 = _fbm3(p_in2 * 1.55);
	float cleavage = pow(clamp(1.0 - abs(f1 * 2.0 - 1.0) * 1.75, 0.0, 1.0), 4.4);
	float core_cloud = smoothstep(0.40, 0.82, f2) * smoothstep(0.10, 0.65, h);

	// 天然石英横向生长纹与微晶裂理
	float stria_wave = sin(h * 84.0 + _noise3(wp * 3.2) * 3.5);
	float stria = smoothstep(-0.2, 0.85, stria_wave) * (1.0 - smoothstep(0.76, 0.96, h));
	float micro_frost = smoothstep(0.55, 0.88, _noise3(wp * 7.5));

	// 晶面微妙横向法线起伏（保留各晶面硬朗大折角，只增加近景石英纹闪烁）
	vec3 tangent_hint = abs(N.y) < 0.92 ? normalize(cross(N, vec3(0.0, 1.0, 0.0))) : vec3(1.0, 0.0, 0.0);
	vec3 bitangent_hint = normalize(cross(N, tangent_hint));
	vec3 n_world = normalize(N + bitangent_hint * (stria_wave * 0.038 * (1.0 - edge)) + tangent_hint * ((f1 - 0.5) * 0.032));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// 矿物色彩层次：基部深邃黑蓝 -> 中段冰川青碧 -> 尖端透亮青翠；外围暗晶略带深渊冷紫
	vec3 base_root = mix(outer_violet * 0.55, deep_color, energy);
	vec3 base_mid = mix(mix(outer_violet, mid_color, 0.48), mid_color, energy);
	vec3 base_tip = mix(mid_color * 1.35, tip_color, 0.35 + 0.65 * energy);
	vec3 col = mix(base_root, base_mid, smoothstep(0.04, 0.56, h));
	col = mix(col, base_tip, smoothstep(0.50, 0.96, h));
	// 内部折射亮云与解理纹在深色晶面里隐约透出
	col += mid_color * core_cloud * (0.28 + 0.36 * energy);
	col = mix(col, edge_glow_color * 0.82, edge * (0.24 + 0.26 * h));
	// 晶根岩石共生结霜过渡
	float root_crust = smoothstep(0.16, 0.0, h) * (0.45 + 0.55 * micro_frost);
	col = mix(col, vec3(0.10, 0.11, 0.14), root_crust * 0.72);

	ALBEDO = col;
	ROUGHNESS = clamp(mix(0.24, 0.06, smoothstep(0.06, 0.36, h)) + stria * 0.045 + edge * 0.055 + root_crust * 0.52, 0.05, 0.88);
	METALLIC = clamp(0.05 + fres * 0.14 - root_crust * 0.05, 0.0, 0.25);
	SPECULAR = mix(0.92, 0.38, root_crust);
	CLEARCOAT = mix(0.92, 0.08, root_crust);
	CLEARCOAT_ROUGHNESS = 0.07 + stria * 0.04;

	// 克制的压电微光呼吸：集中在内部解理、棱边菲涅尔、晶尖与根部地裂，绝不糊成平面亮块
	float pulse = 0.88 + 0.12 * sin(TIME * 1.5 + phase + h * 2.4);
	float root_fissure = smoothstep(0.24, 0.02, h) * cleavage * (0.45 + 0.55 * energy);
	float inner_glow = (cleavage * 0.62 + core_cloud * 0.34) * (0.24 + 0.76 * energy);
	float rim_glow = (edge * 0.52 + fres * 0.44) * (0.22 + 0.78 * h) * (0.36 + 0.64 * energy);
	float tip_glow = pow(h, 3.0) * (0.14 + 0.52 * energy);

	vec3 em_core = mix(vec3(0.12, 0.58, 0.88), core_glow_color, energy);
	vec3 em_col = em_core * (inner_glow + root_fissure * 0.65 + tip_glow) + edge_glow_color * rim_glow;
	EMISSION = em_col * glow_strength * pulse * (1.0 - root_crust * 0.68);
}
