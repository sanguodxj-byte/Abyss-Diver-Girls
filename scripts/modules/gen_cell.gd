extends RefCounted
## 电池组 B-40：6 节电芯阵列 + 电量指示条
## 接口：插头 HP-G1（朝前，插入躯干背面动力舱）；局部 +Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var root := K.module_root("gen", id, Vector3.FORWARD)
	var gc: Color = ctx.info.color
	var M_H := K.armor(c, 0.50)
	var M_SUB := K.armor_sub(c, 0.56)
	var b := K.g1_mount(root, M_H, 0.80, 0.64)
	# 军规防震装甲电池柜框架（取代裸露发光蓝圆片）
	K.bb(b, Vector3(0.76, 0.58, 0.36), M_SUB, Vector3(0, 0, 0.18), Vector3.ZERO, 0.024)
	for sx in [-1.0, 1.0]:
		K.plate(b, K.crect(0.38, 0.60, [0.0, 0.08, 0.08, 0.0]), 0.055, M_H, Vector3(sx * 0.39, 0, 0.19), Vector3(0, 90, 0), 0.014)
		K.grab_iron(b, 0.22, 0.04, Vector3(sx * 0.42, 0.16, 0.19), Vector3(0, -sx * 90.0, 0))
	# 6 组磷酸铁锂重型电芯模组 + 铜汇流母排 + 红黑绝缘护套 + 钢压条
	var M_BOOT_R := A.paint(Color(0.54, 0.14, 0.11), 0.05, 0.72, {"panel_scale": 0.0})
	var M_BOOT_B := A.paint(Color(0.11, 0.12, 0.13), 0.05, 0.78, {"panel_scale": 0.0})
	for i in 3:
		for j in 2:
			var p := Vector3(-0.22 + i * 0.22, 0.13 - j * 0.26, 0.22)
			K.cy(b, 0.092, 0.32, M_GUN, p, Vector3(90, 0, 0), -1.0, 16)
			K.cy(b, 0.098, 0.032, M_DARK, p + Vector3(0, 0, 0.12), Vector3(90, 0, 0), -1.0, 16)
			# 正负极接线柱与铜汇流排
			for tx in [-0.036, 0.036]:
				K.cy(b, 0.018, 0.03, M_BOOT_R if tx > 0 else M_BOOT_B, p + Vector3(tx, 0, 0.175), Vector3(90, 0, 0), -1.0, 8)
				K.cy(b, 0.011, 0.045, K.copper(), p + Vector3(tx, 0, 0.185), Vector3(90, 0, 0), -1.0, 8)
	# 横向串联实心铜母排 + 中央防爆断路旋钮 + 内凹电量窄条表
	for ry in [0.13, -0.13]:
		K.bb(b, Vector3(0.50, 0.022, 0.012), K.copper(), Vector3(0, ry + 0.035, 0.402), Vector3.ZERO, 0.003)
		K.bb(b, Vector3(0.68, 0.032, 0.024), M_DARK, Vector3(0, ry, 0.388), Vector3.ZERO, 0.005)
	# 中央主断路急停开关盒 + 低亮度凹陷电量指示窗
	K.bb(b, Vector3(0.24, 0.10, 0.06), M_H, Vector3(0, 0, 0.39), Vector3.ZERO, 0.01)
	K.cy(b, 0.028, 0.03, M_BOOT_R, Vector3(-0.06, 0, 0.425), Vector3(90, 0, 0), -1.0, 10)
	K.bb(b, Vector3(0.08, 0.014, 0.018), M_BOOT_R, Vector3(-0.06, 0, 0.438), Vector3(0, 0, 35), 0.003)
	K.bb(b, Vector3(0.10, 0.032, 0.015), K.bore_mat(), Vector3(0.05, 0, 0.420), Vector3.ZERO, 0.003)
	for seg in 4:
		K.bb(b, Vector3(0.016, 0.018, 0.010), A.emit(gc, 0.75), Vector3(0.018 + seg * 0.021, 0, 0.424), Vector3.ZERO, 0.002)
	# 底部风冷格栅与主高压输出铠装电缆
	A.vent(b, Vector3(0.56, 0.08, 0.03), Vector3(0, -0.25, 0.365), Vector3(0, 180, 0), 4)
	A.hose(b, Vector3(-0.32, -0.24, 0.04), Vector3(-0.18, -0.27, 0.36), Vector3(0, -0.07, 0), 0.026, M_BOOT_R)
	A.hose(b, Vector3(0.32, -0.24, 0.04), Vector3(0.18, -0.27, 0.36), Vector3(0, -0.07, 0), 0.026)
	A.stencil(b, "B-40  480V", Vector3(0.418, -0.04, 0.19), Vector3(0, 90, 0), 0.0026, Color(0.92, 0.90, 0.84, 0.78))
	if lights:
		K.light(b, gc, Vector3(0.05, 0, 0.52), 0.10, 1.2)
	return root
