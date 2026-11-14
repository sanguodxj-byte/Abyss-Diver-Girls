extends RefCounted
## 垂直发射箱 VLS-8：2×4 垂直发射单元，铰链舱盖、侧面加强肋、尾部燃气排导口
## 接口：插头 HP-B1 → b1_mount（加宽横梁）→ 发射箱；局部 +Y 远离躯干
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("back", ctx.id, Vector3(0, -1, -0.25))
	var M_A := K.armor(c, 0.54)
	var M_A2 := K.armor_sub(c, 0.58)
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var top := K.b1_mount(root, M_A, 1.52)
	# 舰载 Mk-41 风格紧凑斜切装甲垂直发射模块（降低箱高至 0.66m 紧贴肩背，前向多段折角防爆肋 + 中央火控脐带脊）
	K.bb(top, Vector3(1.54, 0.66, 0.98), M_A, Vector3(0, 0.33, 0.0), Vector3.ZERO, 0.040)
	# 前缘后倾导流眉甲 + 左右分仓防爆检修甲 + 中央重型火控接线脊（消除单块大灰板广告牌感）
	K.plate(top, K.trap(1.52, 1.42, 0.22, 0.04), 0.08, M_GUN, Vector3(0, 0.58, -0.47), Vector3(-24, 0, 0), 0.016)
	K.bb(top, Vector3(0.20, 0.56, 0.08), M_DARK, Vector3(0, 0.30, -0.50), Vector3.ZERO, 0.014)
	K.cy(top, 0.036, 0.05, K.brass(), Vector3(0, 0.20, -0.545), Vector3(90, 0, 0), -1.0, 10)
	A.hose(top, Vector3(0, 0.18, -0.54), Vector3(0.18, 0.04, -0.42), Vector3(0.06, -0.08, -0.08), 0.022)
	for sx in [-1.0, 1.0]:
		var fx: float = sx * 0.44
		K.plate(top, K.trap(0.60, 0.56, 0.48, 0.04), 0.055, M_A2, Vector3(fx, 0.28, -0.50), Vector3(-4, 0, 0), 0.015)
		for ri in 3:
			K.bb(top, Vector3(0.54, 0.034, 0.036), M_GUN, Vector3(fx, 0.13 + ri * 0.14, -0.532), Vector3(-4, 0, 0), 0.006)
		K.era_block(top, Vector3(0.24, 0.14, 0.040), M_A, Vector3(sx * 0.54, 0.44, -0.525), Vector3(-4, 0, 0))
	A.stencil(top, "MK-41", Vector3(0.32, 0.44, -0.538), Vector3(4, 180, 0), 0.0026, Color(0.94, 0.92, 0.86, 0.85))
	A.stencil(top, "HOT LAUNCH", Vector3(-0.34, 0.20, -0.538), Vector3(4, 180, 0), 0.0020, Color(0.95, 0.84, 0.28, 0.88))
	K.bb(top, Vector3(1.60, 0.068, 1.04), M_GUN, Vector3(0, 0.675, 0.0), Vector3.ZERO, 0.018)
	K.bb(top, Vector3(1.50, 0.030, 0.045), K.accent(), Vector3(0, 0.702, -0.495), Vector3.ZERO, 0.005)
	for sx in [-1.0, 1.0]:
		# 两侧切角副装甲裙板 + 外露工字抗爆肋 + 检修法兰盖 + 吊装提手
		K.plate(top, K.trap(0.94, 0.78, 0.58, 0.05), 0.055, M_A2, Vector3(sx * 0.79, 0.34, 0.0), Vector3(0, 90, 0), 0.015)
		for i in 4:
			K.bb(top, Vector3(0.055, 0.60, 0.055), M_GUN, Vector3(sx * 0.82, 0.35, -0.36 + i * 0.24), Vector3.ZERO, 0.01)
		K.era_block(top, Vector3(0.30, 0.18, 0.045), M_A, Vector3(sx * 0.825, 0.22, -0.16), Vector3(0, -sx * 90.0, 0))
		K.grab_iron(top, 0.26, 0.05, Vector3(sx * 0.80, 0.68, 0.0), Vector3(0, -sx * 90.0, 0))
		A.stencil(top, "VLS-8", Vector3(sx * 0.822, 0.48, 0.14), Vector3(0, sx * 90.0, 0), 0.0040, Color(0.94, 0.92, 0.86, 0.82))
		A.stencil(top, "HOT LAUNCH", Vector3(sx * 0.822, 0.32, 0.14), Vector3(0, sx * 90.0, 0), 0.0023, Color(0.95, 0.84, 0.28, 0.85))
	# 2×4 垂直发射单元：深黑井口衬套 + 铰链防爆舱盖（保留 Hatch<i><j> 与 Missile<i><j> 动画契约）
	for i in 4:
		for j in 2:
			var p := Vector3(-0.57 + i * 0.38, 0.72, -0.22 + j * 0.44)
			# 发射井围框与深黑内腔衬口（掀盖开火时可见真实发射筒井口）
			K.bb(top, Vector3(0.355, 0.032, 0.415), M_DARK, p + Vector3(0, -0.018, 0), Vector3.ZERO, 0.008)
			K.cy(top, 0.135, 0.04, K.bore_mat(), p + Vector3(0, -0.015, 0), Vector3.ZERO, -1.0, 14)
			# 舱盖铰链轴与开盖液压作动器包（铰链在后缘 +Z，开火动画绕 X 掀开 Hatch<i><j>）
			K.cy(top, 0.022, 0.30, A.chrome(), p + Vector3(0, 0.018, 0.20), Vector3(0, 0, 90), -1.0, 8)
			K.bb(top, Vector3(0.08, 0.045, 0.06), M_GUN, p + Vector3(0, 0.02, 0.215), Vector3.ZERO, 0.008)
			var h := K.node(top, p + Vector3(0, 0, 0.2), Vector3.ZERO, "Hatch%d%d" % [i, j])
			K.bb(h, Vector3(0.34, 0.042, 0.40), M_A2, Vector3(0, 0, -0.2), Vector3.ZERO, 0.01)
			K.bb(h, Vector3(0.29, 0.016, 0.34), M_GUN, Vector3(0, 0.024, -0.2), Vector3.ZERO, 0.005)
			for rx in [-0.09, 0.09]:
				K.bb(h, Vector3(0.022, 0.014, 0.32), M_DARK, Vector3(rx, 0.032, -0.2), Vector3.ZERO, 0.003)
			K.bb(h, Vector3(0.07, 0.020, 0.038), K.accent(), Vector3(0, 0.030, -0.37), Vector3.ZERO, 0.004)
			# 发射井内战术导弹（Missile<i><j>），平时藏在 0.66m 箱体内
			var ms := K.node(top, Vector3(p.x, 0.0, p.z), Vector3.ZERO, "Missile%d%d" % [i, j])
			K.cy(ms, 0.096, 0.44, A.paint(Color(0.54, 0.55, 0.52), 0.35, 0.44, {"panel_scale": 0.0}), Vector3(0, 0.30, 0), Vector3.ZERO, -1.0, 12)
			K.cy(ms, 0.100, 0.035, K.accent(), Vector3(0, 0.48, 0), Vector3.ZERO, -1.0, 12)
			K.cy(ms, 0.096, 0.14, A.paint(Color(0.28, 0.30, 0.26), 0.22, 0.48, {"wear": 0.35, "panel_scale": 0.0}), Vector3(0, 0.59, 0), Vector3.ZERO, 0.016, 12)
			for f in 4:
				K.bb(ms, Vector3(0.012, 0.11, 0.09), M_DARK, Vector3(cos(f * PI / 2) * 0.098, 0.14, sin(f * PI / 2) * 0.098), Vector3(0, -f * 90.0, 0), 0.003)
	# 尾部双联热燃气排导风道（带熏黑防爆百叶与加强护罩）
	for sx in [-0.46, 0.46]:
		K.bb(top, Vector3(0.54, 0.46, 0.14), M_GUN, Vector3(sx, 0.31, 0.53), Vector3.ZERO, 0.022)
		K.bb(top, Vector3(0.46, 0.36, 0.04), K.bore_mat(), Vector3(sx, 0.31, 0.59), Vector3.ZERO, 0.008)
		A.vent(top, Vector3(0.44, 0.32, 0.04), Vector3(sx, 0.31, 0.602), Vector3(0, 180, 0), 5)
	return root
