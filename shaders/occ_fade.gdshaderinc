// 遮挡机甲的前景建筑/窗格/树冠虚化穿透公共模块
// 1) 整栋建筑虚化模式：主镜头通道内由 occ_box0/occ_box1 干净隐藏被遮挡的整栋建筑原不透明网格（保留太阳投影），
//    由 raid.gd 的双通道单壳半透明代理（occ_bldg_depth + occ_bldg_ghost）平滑渲染整栋半透明虚化建筑；
// 2) 非独立盒体结构（如超大桥梁/岩崖）与树冠自动走视线锥平滑溶解兜底。
global uniform vec3 occ_cam_pos;
global uniform vec3 occ_mech_pos;
global uniform vec4 occ_params; // x: 兜底局部溶解强度(0..1), y: 内核心清晰半径(m), z: 外羽化半径(m), w: 第三人称树冠虚化开关(0..1)
global uniform vec4 occ_box0_pos; // xyz: 建筑0 OBB中心, w: >0.5 表示主镜头隐藏不透明本体
global uniform vec4 occ_box0_ext; // xyz: 建筑0 OBB半尺寸, w: 绕Y偏航角(rad)
global uniform vec4 occ_box1_pos; // xyz: 建筑1 OBB中心, w: >0.5 表示主镜头隐藏不透明本体
global uniform vec4 occ_box1_ext; // xyz: 建筑1 OBB半尺寸, w: 绕Y偏航角(rad)

float occ_ign(highp vec2 frag_xy) {
	return fract(52.9829189 * fract(dot(frag_xy, vec2(0.06711056, 0.00583715))));
}

bool occ_in_obb(highp vec3 wp, highp vec4 b_pos, highp vec4 b_ext) {
	if (b_pos.w < 0.5) {
		return false;
	}
	if (wp.y < 0.22) {
		return false;
	}
	highp vec3 d = wp - b_pos.xyz;
	highp float cy = cos(b_ext.w);
	highp float sy = sin(b_ext.w);
	highp float lx = d.x * cy - d.z * sy;
	highp float lz = d.x * sy + d.z * cy;
	return abs(lx) <= b_ext.x && abs(d.y) <= b_ext.y && abs(lz) <= b_ext.z;
}

bool occ_clip_whole_bldg(highp vec3 wp, highp vec3 cam_now) {
	if (occ_box0_pos.w < 0.5 && occ_box1_pos.w < 0.5) {
		return false;
	}
	highp vec3 dc = cam_now - occ_cam_pos;
	if (dot(dc, dc) > 0.25) {
		return false;
	}
	return occ_in_obb(wp, occ_box0_pos, occ_box0_ext) || occ_in_obb(wp, occ_box1_pos, occ_box1_ext);
}

float occ_calc_fade(highp vec3 wp, highp vec3 cam_now, float strength, float y_floor_off) {
	if (strength <= 0.005) {
		return 0.0;
	}
	highp vec3 dc = cam_now - occ_cam_pos;
	if (dot(dc, dc) > 0.25) {
		return 0.0;
	}
	// 保留地面、路面与低矮路缘（机甲脚下平面绝不镂空）
	float h_mask = smoothstep(occ_mech_pos.y - 1.75 + y_floor_off, occ_mech_pos.y - 1.00 + y_floor_off, wp.y);
	if (h_mask <= 0.001) {
		return 0.0;
	}
	highp vec3 ev = wp - occ_cam_pos;
	highp float d_frag = length(ev);
	if (d_frag < 0.25) {
		return 0.0;
	}
	highp vec3 rd = ev / d_frag;
	// 像素视线到机甲竖直中轴线段 [A, B] 的精确最近点（任意建筑高度/距离下屏幕窗口比例一致）
	highp vec3 a_pt = occ_mech_pos + vec3(0.0, -1.25, 0.0);
	highp float seg_h = 3.05;
	highp vec3 w0 = a_pt - occ_cam_pos;
	highp float denom = max(seg_h * (1.0 - rd.y * rd.y), 1e-4);
	highp float t_seg = clamp((rd.y * dot(w0, rd) - w0.y) / denom, 0.0, 1.0);
	highp vec3 p_mech = a_pt + vec3(0.0, t_seg * seg_h, 0.0);
	highp float s_mech = dot(p_mech - occ_cam_pos, rd);
	// 仅虚化严格位于机甲前方的遮挡体，机甲身后建筑保持完全实心
	float front_mask = smoothstep(0.15, 0.95, s_mech - d_frag);
	if (front_mask <= 0.001) {
		return 0.0;
	}
	highp float d_perp = length((occ_cam_pos + rd * s_mech) - p_mech);
	float rad_mask = 1.0 - smoothstep(occ_params.y, occ_params.z, d_perp);
	rad_mask = rad_mask * rad_mask * (3.0 - 2.0 * rad_mask);
	return clamp(strength * h_mask * front_mask * rad_mask, 0.0, 1.0);
}

vec3 occ_soft_mist(vec3 col, float fade) {
	float edge_soft = smoothstep(0.06, 0.90, fade);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	return mix(col, vec3(lum), edge_soft * 0.28);
}
