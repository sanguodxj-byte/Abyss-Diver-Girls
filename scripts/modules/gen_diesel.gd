extends RefCounted
## 柴油发电机组 DG-130：直列缸体 + 带肋缸盖、排气歧管接竖置消音筒（防雨帽）、尾部散热器 + 风扇护罩、燃油滤清器
## 接口：插头 HP-G1（朝前插入动力舱）→ g1_mount（背板 + 四角锁销）→ 机组；局部 +Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("gen", ctx.id, Vector3.FORWARD)
	var M_H := K.armor(c, 0.60)
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_BLOCK := A.metal(Color(0.18, 0.19, 0.18))
	var b := K.g1_mount(root, M_H, 0.82, 0.66)
	# 铸铁加强筋直列柴油缸体 + 压铸气门室盖 + 加机油口盖
	K.bb(b, Vector3(0.60, 0.40, 0.42), M_BLOCK, Vector3(0, -0.06, 0.21), Vector3.ZERO, 0.028)
	for rz in [0.09, 0.17, 0.25, 0.33]:
		K.bb(b, Vector3(0.625, 0.28, 0.022), M_DARK, Vector3(0, -0.08, rz), Vector3.ZERO, 0.005)
	K.bb(b, Vector3(0.50, 0.12, 0.38), M_H, Vector3(0, 0.20, 0.21), Vector3.ZERO, 0.024)
	for i in 6:
		K.bb(b, Vector3(0.46, 0.024, 0.02), M_GUN, Vector3(0, 0.27, 0.06 + i * 0.058), Vector3.ZERO, 0.004)
	K.cy(b, 0.036, 0.035, K.brass(), Vector3(-0.14, 0.275, 0.12), Vector3.ZERO, -1.0, 10)
	A.stencil(b, "DG-130", Vector3(-0.315, -0.04, 0.21), Vector3(0, -90, 0), 0.0028, Color(0.95, 0.85, 0.30, 0.85))
	# 左侧旋风空气滤清器罐 + 涡轮增压蜗壳 + 排气歧管 → 打孔隔热罩竖置消音烟囱（带深膛孔与防雨帽）
	K.cy(b, 0.085, 0.28, M_DARK, Vector3(-0.34, 0.24, 0.18), Vector3(90, 0, 0), -1.0, 14)
	K.cy(b, 0.098, 0.05, M_GUN, Vector3(-0.34, 0.24, 0.04), Vector3(90, 0, 0), -1.0, 14)
	K.cy(b, 0.068, 0.09, M_GUN, Vector3(0.24, 0.18, 0.16), Vector3(0, 0, 90), -1.0, 12)
	for i in 3:
		K.cy(b, 0.030, 0.09, M_DARK, Vector3(0.27, 0.12, 0.10 + i * 0.10), Vector3(0, 0, 90), -1.0, 8)
	var M_EXH := A.metal(Color(0.28, 0.23, 0.19))
	A.hose(b, Vector3(0.30, 0.14, 0.20), Vector3(0.34, 0.30, 0.32), Vector3(0.04, 0.0, 0), 0.042, M_EXH)
	K.cy(b, 0.072, 0.52, M_EXH, Vector3(0.34, 0.53, 0.32), Vector3.ZERO, -1.0, 16)
	K.cy(b, 0.090, 0.36, M_GUN, Vector3(0.34, 0.49, 0.32), Vector3.ZERO, -1.0, 16)
	K.holes(b, Vector3(0.432, 0.49, 0.32), Vector3(0, -90, 0), 3, 5, 0.052, 0.013)
	for yy in [0.32, 0.66]:
		K.cy(b, 0.095, 0.028, M_DARK, Vector3(0.34, yy, 0.32), Vector3.ZERO, -1.0, 16)
	K.barrel_bore(b, 0.072, 0.056, Vector3(0.34, 0.79, 0.32), 0.10, Vector3.ZERO)
	# 铰链配重防雨翻板帽
	K.bb(b, Vector3(0.025, 0.04, 0.08), M_DARK, Vector3(0.27, 0.80, 0.32), Vector3.ZERO, 0.004)
	K.cy(b, 0.082, 0.014, M_GUN, Vector3(0.34, 0.835, 0.32), Vector3(0, 0, 22), -1.0, 14)
	# 尾部装甲水箱散热器 + 6 叶风扇 + 钢丝防石护网
	K.bb(b, Vector3(0.68, 0.52, 0.09), M_H, Vector3(0, -0.02, 0.48), Vector3.ZERO, 0.02)
	K.bb(b, Vector3(0.56, 0.40, 0.02), K.bore_mat(), Vector3(0, -0.02, 0.525), Vector3.ZERO, 0.005)
	A.vent(b, Vector3(0.56, 0.40, 0.03), Vector3(0, -0.02, 0.535), Vector3(0, 180, 0), 8)
	A.add(b, A.torus(0.16, 0.195, 24), M_GUN, Vector3(0, -0.02, 0.555), Vector3(90, 0, 0), Vector3(1, 0.38, 1), false)
	K.cy(b, 0.05, 0.03, M_DARK, Vector3(0, -0.02, 0.552), Vector3(90, 0, 0), -1.0, 12)
	for i in 6:
		K.bb(b, Vector3(0.032, 0.15, 0.008), M_DARK, Vector3(0, -0.02, 0.548), Vector3(18, 0, i * 60.0), 0.002)
	for r_ring in [0.09, 0.14]:
		A.add(b, A.torus(r_ring, r_ring + 0.008, 20), M_DARK, Vector3(0, -0.02, 0.565), Vector3(90, 0, 0), Vector3.ONE, false)
	# 下挂无刷交流发电机 + 双联旋装式柴油滤清器 + 黄铜油压表
	K.cy(b, 0.12, 0.26, M_DARK, Vector3(-0.20, -0.24, 0.32), Vector3(90, 0, 0), -1.0, 16)
	for fz in [0.21, 0.32]:
		K.cy(b, 0.042, 0.13, A.paint(Color(0.56, 0.42, 0.14), 0.12, 0.58, {"wear": 0.4, "panel_scale": 0.0}), Vector3(-0.34, 0.03, fz), Vector3.ZERO, -1.0, 12)
	K.cy(b, 0.030, 0.022, K.brass(), Vector3(-0.34, 0.13, 0.34), Vector3(0, 0, 90), -1.0, 10)
	A.hose(b, Vector3(-0.34, -0.04, 0.26), Vector3(-0.28, -0.12, 0.06), Vector3(-0.03, -0.04, 0), 0.016)
	return root
