extends RefCounted
## 氢燃料电池堆 HFC-180：两只卧式高压储氢罐（箍带 + 阀门）、层叠电堆（端板 + 拉杆）、冷却液管
## 接口：插头 HP-G1（朝前插入动力舱）→ g1_mount → 罐组与电堆；局部 +Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("gen", ctx.id, Vector3.FORWARD)
	var M_H := K.armor(c, 0.46)
	var M_SUB := K.armor_sub(c, 0.52)
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var b := K.g1_mount(root, M_H, 0.82, 0.66)
	# 防撞鞍座底架 + 两侧防护耳板
	K.bb(b, Vector3(0.74, 0.58, 0.065), K.frame(), Vector3(0, 0, 0.032), Vector3.ZERO, 0.015)
	for sx in [-0.39, 0.39]:
		K.plate(b, K.crect(0.32, 0.54, [0.0, 0.06, 0.06, 0.0]), 0.04, M_SUB, Vector3(sx, 0, 0.20), Vector3(0, 90, 0), 0.01)
	# 双卧式 700 BAR 碳纤维缠绕储氢瓶（深灰碳纤中段 + 浅灰封头 + 鞍座钢箍 + 黄铜减压阀与波登压力表）
	var M_WRAP := A.paint(Color(0.19, 0.20, 0.22), 0.25, 0.52, {"wear": 0.25, "panel_scale": 0.0})
	var M_BOSS := A.paint(Color(0.56, 0.58, 0.56), 0.35, 0.42, {"wear": 0.38, "panel_scale": 0.0})
	for sy in [-1.0, 1.0]:
		var y: float = sy * 0.155
		K.cy(b, 0.132, 0.42, M_WRAP, Vector3(0, y, 0.20), Vector3(0, 0, 90), -1.0, 20)
		for sx in [-1.0, 1.0]:
			K.cy(b, 0.130, 0.06, M_BOSS, Vector3(sx * 0.23, y, 0.20), Vector3(0, 0, 90), -1.0, 20)
			A.add(b, A.sphere(0.13, 0.26, 16), M_BOSS, Vector3(sx * 0.26, y, 0.20), Vector3.ZERO, Vector3(0.48, 1, 1))
		for sx in [-0.15, 0.15]:
			K.cy(b, 0.140, 0.042, M_GUN, Vector3(sx, y, 0.20), Vector3(0, 0, 90), -1.0, 20)
			K.bb(b, Vector3(0.045, 0.035, 0.18), M_DARK, Vector3(sx, y, 0.10), Vector3.ZERO, 0.005)
		# 右端高压黄铜截止阀总成 + 压力表盘
		K.cy(b, 0.032, 0.08, K.brass(), Vector3(0.35, y, 0.20), Vector3(0, 0, 90), -1.0, 10)
		K.cy(b, 0.026, 0.018, A.chrome(), Vector3(0.36, y + 0.042, 0.23), Vector3(90, 0, 0), -1.0, 10)
	# 高压氢气管汇连接电堆
	A.hose(b, Vector3(0.36, 0.155, 0.20), Vector3(0.24, 0.10, 0.40), Vector3(0.05, 0, 0.05), 0.016, A.chrome())
	A.hose(b, Vector3(0.36, -0.155, 0.20), Vector3(0.24, -0.10, 0.40), Vector3(0.05, 0, 0.05), 0.016, A.chrome())
	A.stencil(b, "H2  700 BAR", Vector3(0, 0.155, 0.335), Vector3.ZERO, 0.0024, Color(0.88, 0.90, 0.94, 0.85))
	A.stencil(b, "FLAMMABLE", Vector3(0, -0.155, 0.335), Vector3.ZERO, 0.0024, Color(0.86, 0.38, 0.22, 0.88))
	# 层叠质子交换膜电堆（重型压紧端板 + 双极板叠片 + 6 根高强拉杆 + 铜集流母排）
	var M_PLATE_A := A.metal(Color(0.26, 0.27, 0.29))
	var M_PLATE_B := A.paint(Color(0.11, 0.12, 0.13), 0.2, 0.62, {"panel_scale": 0.0})
	K.bb(b, Vector3(0.54, 0.52, 0.055), M_H, Vector3(0, 0, 0.385), Vector3.ZERO, 0.012)
	for i in 14:
		K.bb(b, Vector3(0.46, 0.44, 0.012), M_PLATE_A if i % 2 == 0 else M_PLATE_B, Vector3(0, 0, 0.42 + i * 0.016), Vector3.ZERO, 0.002)
	K.bb(b, Vector3(0.54, 0.52, 0.055), M_H, Vector3(0, 0, 0.665), Vector3.ZERO, 0.012)
	for cx in [-0.23, 0.23]:
		for cy_ in [-0.22, 0.0, 0.22]:
			K.cy(b, 0.013, 0.34, A.chrome(), Vector3(cx, cy_, 0.525), Vector3(90, 0, 0), -1.0, 8)
			K.cy(b, 0.022, 0.02, M_GUN, Vector3(cx, cy_, 0.70), Vector3(90, 0, 0), -1.0, 6)
	# 顶部铜电极引出排与警示护盖 + 尾部水蒸气冷凝排放管口
	K.bb(b, Vector3(0.36, 0.018, 0.22), K.copper(), Vector3(0, 0.235, 0.525), Vector3.ZERO, 0.003)
	K.bb(b, Vector3(0.46, 0.036, 0.25), K.accent(), Vector3(0, 0.262, 0.525), Vector3.ZERO, 0.005)
	K.cy(b, 0.042, 0.07, M_GUN, Vector3(-0.14, -0.14, 0.71), Vector3(90, 0, 0), -1.0, 12)
	K.barrel_bore(b, 0.042, 0.030, Vector3(-0.14, -0.14, 0.745), 0.05, Vector3(-90, 0, 0))
	# 冷却液回路软管 + 低亮度凹陷运行指示灯
	var M_COOL := A.paint(Color(0.16, 0.29, 0.39), 0.12, 0.58, {"panel_scale": 0.0})
	for sx in [-1.0, 1.0]:
		A.hose(b, Vector3(sx * 0.26, -0.18, 0.66), Vector3(sx * 0.33, -0.25, 0.08), Vector3(sx * 0.06, -0.04, 0), 0.022, M_COOL)
	K.bb(b, Vector3(0.065, 0.035, 0.022), M_DARK, Vector3(0.15, 0.14, 0.698), Vector3.ZERO, 0.004)
	K.bb(b, Vector3(0.038, 0.014, 0.008), A.emit(Color(0.35, 0.85, 0.45), 0.85), Vector3(0.15, 0.14, 0.708), Vector3.ZERO, 0.002)
	return root
