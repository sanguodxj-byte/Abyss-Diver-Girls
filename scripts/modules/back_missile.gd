extends RefCounted
## 蜂巢导弹：双联装 6 发发射巢，带挂架与装填门
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
	var M_BACK := K.armor(c, 0.56)
	var M_SUB := K.armor_sub(c, 0.58)
	var M_WARHEAD := A.paint(Color(0.28, 0.31, 0.24), 0.22, 0.50, {"wear": 0.35, "panel_scale": 0.0})
	var M_BAND := A.paint(Color(0.68, 0.48, 0.14), 0.15, 0.52, {"wear": 0.45, "panel_scale": 0.0})
	# 中央火控接线分线箱 + 横向承力主梁 + 双侧液压俯仰挂架
	K.bb(root, Vector3(0.86, 0.18, 0.38), M_FRAME, Vector3(0, 0.04, 0.08), Vector3.ZERO, 0.025)
	K.bb(root, Vector3(0.36, 0.22, 0.34), M_SUB, Vector3(0, 0.18, 0.14), Vector3.ZERO, 0.02)
	K.bb(root, Vector3(1.54, 0.14, 0.28), M_FRAME, Vector3(0, 0.12, 0.10), Vector3.ZERO, 0.028)
	for sx in [-1.0, 1.0]:
		K.bb(root, Vector3(0.22, 0.34, 0.28), M_GUN, Vector3(sx * 0.65, 0.25, 0.15), Vector3(0, 0, sx * -14.0), 0.024)
		K.cy(root, 0.075, 0.28, M_DARK, Vector3(sx * 0.68, 0.36, 0.17), Vector3(0, 0, 90), -1.0, 20)
		K.piston(root, Vector3(sx * 0.28, 0.10, 0.08), Vector3(sx * 0.66, 0.28, 0.22), 0.032)
		A.hose(root, Vector3(sx * 0.17, 0.22, 0.24), Vector3(sx * 0.54, 0.38, 0.32), Vector3(0, 0.08, 0.06), 0.022)
		var pod := K.node(root, Vector3(sx * 0.75, 0.43, 0.18), Vector3(-16, 0, 0))
		# 装甲发射巢外壳 + 侧装甲护板 + 顶部吊耳抓手
		K.plate(pod, K.crect(0.92, 0.50, [0.16, 0.06, 0.04, 0.04]), 0.62, M_BACK, Vector3.ZERO, Vector3(0, 90, 0), 0.038)
		K.plate(pod, K.crect(0.54, 0.32, [0.06, 0.0, 0.0, 0.06]), 0.66, M_SUB, Vector3(0, -0.02, 0.16), Vector3(0, 90, 0), 0.02)
		K.grab_iron(pod, 0.24, 0.045, Vector3(0, 0.25, -0.05), Vector3(-90, 90, 0))
		# 前部防爆面板 + 6 孔深凹发射管口 + 内缩战术导弹寻的头
		K.bb(pod, Vector3(0.56, 0.44, 0.05), M_GUN, Vector3(0, 0, -0.455), Vector3.ZERO, 0.012)
		for i in 3:
			for j in 2:
				var mp := Vector3(-0.175 + i * 0.175, 0.10 - j * 0.20, -0.48)
				K.barrel_bore(pod, 0.074, 0.062, mp, 0.14)
				K.cy(pod, 0.052, 0.08, M_WARHEAD, mp + Vector3(0, 0, 0.035), Vector3(-90, 0, 0), 0.026, 20)
				K.cy(pod, 0.046, 0.018, M_BAND, mp + Vector3(0, 0, 0.012), Vector3(90, 0, 0), -1.0, 20)
				A.add(pod, A.sphere(0.024, 0.048, 20), K.canopy(Color(0.55, 0.35, 0.15), 0.28), mp + Vector3(0, 0, -0.004), Vector3.ZERO, Vector3(1, 1, 0.7))
		# 尾部燃气泄放百叶 + 锁紧法兰
		K.bb(pod, Vector3(0.54, 0.40, 0.06), M_DARK, Vector3(0, 0, 0.46), Vector3.ZERO, 0.012)
		A.vent(pod, Vector3(0.44, 0.28, 0.04), Vector3(0, 0.0, 0.495), Vector3(0, 180, 0), 5)
		K.plate(pod, K.crect(0.50, 0.045), 0.64, K.accent(), Vector3(0, 0.18, 0.10), Vector3(0, 90, 0), 0.005)
		A.rivets(pod, Vector3(sx * 0.32, 0.19, -0.34), Vector3(sx * 0.32, 0.19, 0.34), 6, 0.014, Vector3(0, 0, 90))
		A.stencil(pod, "AGM-6", Vector3(sx * 0.325, 0.02, 0.04), Vector3(0, sx * 90.0, 0), 0.0032, Color(0.92, 0.88, 0.78, 0.82))
	return root
