extends RefCounted
## 相位护盾：发生器箱、桅杆、环形发射器
## 接口：插头 HP-B1（朝下，贴躯干顶部后方导轨）；局部 +Y 向上，+Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var root := K.module_root("back", id, Vector3(0, -1, -0.25))
	var M_BACK := K.armor(c, 0.54)
	var M_SUB := K.armor_sub(c, 0.58)
	var ec := Color(0.32, 0.62, 0.78)
	# 脉冲成形电容装甲主机箱（取代原外露霓虹灯管）
	K.bb(root, Vector3(0.82, 0.18, 0.44), M_FRAME, Vector3(0, 0.04, 0.09), Vector3.ZERO, 0.024)
	K.plate(root, K.crect(0.64, 0.52, [0.12, 0.10, 0.04, 0.04]), 0.84, M_BACK, Vector3(0, 0.30, 0.18), Vector3(0, 90, 0), 0.036)
	K.plate(root, K.crect(0.06, 0.32), 0.86, K.accent(), Vector3(0, 0.36, -0.04), Vector3(0, 90, 0), 0.005)
	A.vent(root, Vector3(0.54, 0.28, 0.04), Vector3(0, 0.30, 0.495), Vector3(0, 180, 0), 5)
	# 两侧油冷脉冲变压器模块 + 铜汇流排 + 陶瓷绝缘子
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.16, 0.36, 0.42), M_SUB, Vector3(sx * 0.49, 0.30, 0.18), Vector3.ZERO, 0.02)
		for fz in [-0.14, -0.05, 0.04, 0.13, 0.22]:
			K.bb(root, Vector3(0.19, 0.28, 0.018), M_GUN, Vector3(sx * 0.50, 0.30, 0.14 + fz), Vector3.ZERO, 0.004)
		K.cy(root, 0.038, 0.10, A.paint(Color(0.62, 0.60, 0.56), 0.05, 0.32, {"panel_scale": 0.0}), Vector3(sx * 0.49, 0.52, 0.14), Vector3.ZERO, 0.028, 10)
		K.cy(root, 0.022, 0.05, K.copper(), Vector3(sx * 0.49, 0.58, 0.14), Vector3.ZERO, -1.0, 10)
		A.hose(root, Vector3(sx * 0.49, 0.58, 0.14), Vector3(sx * 0.14, 0.96, 0.30), Vector3(sx * 0.06, 0.14, 0.06), 0.022)
	# 折叠桁架支撑桅杆 + 俯仰液压撑杆
	for sx in [-0.13, 0.13]:
		K.bb(root, Vector3(0.065, 0.72, 0.09), M_GUN, Vector3(sx, 0.82, 0.30), Vector3(-8, 0, 0), 0.012)
	K.bb(root, Vector3(0.32, 0.08, 0.10), M_FRAME, Vector3(0, 0.78, 0.29), Vector3.ZERO, 0.012)
	K.piston(root, Vector3(0, 0.48, 0.12), Vector3(0, 0.98, 0.27), 0.030)
	# 军工三联装八角相控阵电磁偏导天线（彻底取代棒棒糖圆盘与悬浮发光球）
	var array_head := K.node(root, Vector3(0, 1.18, 0.28), Vector3(-28, 0, 0))
	K.bb(array_head, Vector3(0.56, 0.28, 0.18), M_GUN, Vector3(0, 0, 0.09), Vector3.ZERO, 0.02)
	for p_idx in [-1, 0, 1]:
		var px := float(p_idx) * 0.40
		var yaw := float(p_idx) * -22.0
		var pz := absf(float(p_idx)) * 0.08
		var pan := K.node(array_head, Vector3(px, 0, pz), Vector3(0, yaw, 0))
		var w := 0.40 if p_idx == 0 else 0.34
		var h := 0.44 if p_idx == 0 else 0.38
		K.plate(pan, K.crect(w, h, [0.08, 0.08, 0.08, 0.08]), 0.09, M_BACK, Vector3.ZERO, Vector3.ZERO, 0.018)
		K.plate(pan, K.crect(w * 0.84, h * 0.84, [0.06, 0.06, 0.06, 0.06]), 0.03, K.bore_mat(), Vector3(0, 0, -0.042), Vector3.ZERO, 0.006)
		# 相控阵铜波导偶极子阵列与深凹低亮度工作指示窄缝
		for ry in [-0.11, 0.0, 0.11]:
			K.bb(pan, Vector3(w * 0.70, 0.018, 0.016), K.copper(), Vector3(0, ry, -0.050), Vector3.ZERO, 0.003)
		K.bb(pan, Vector3(w * 0.56, 0.018, 0.012), K.canopy(ec, 0.55), Vector3(0, 0.055, -0.052), Vector3.ZERO, 0.002)
		# 外围防撞钢护栏
		K.grab_iron(pan, w * 0.88, 0.045, Vector3(0, h * 0.42, -0.03), Vector3.ZERO, 0.011)
		K.grab_iron(pan, w * 0.88, 0.045, Vector3(0, -h * 0.42, -0.03), Vector3.ZERO, 0.011)
	# 顶部避雷与场强探针
	K.cy(array_head, 0.018, 0.12, K.brass(), Vector3(0, 0.27, 0.02), Vector3.ZERO, -1.0, 8)
	K.cy(array_head, 0.007, 0.30, M_GUN, Vector3(0, 0.45, 0.02), Vector3.ZERO, 0.004, 6)
	A.stencil(root, "EM-BARRIER", Vector3(0, 0.46, 0.49), Vector3(0, 180, 0), 0.0026, Color(0.92, 0.88, 0.78, 0.78))
	return root
