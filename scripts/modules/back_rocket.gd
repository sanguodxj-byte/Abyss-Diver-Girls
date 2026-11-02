extends RefCounted
## 双联火箭巢 RK-4：两只 2×2 箱式发射巢，耳轴 + 俯仰液压缸，前盖露出弹头，后部易碎封盖
## 接口：插头 HP-B1 → b1_mount（导轨卡箍 + 横梁）→ 发射巢；局部 +Y 远离躯干
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("back", ctx.id, Vector3(0, -1, -0.25))
	var M_A := K.armor(c, 0.55)
	var M_A2 := K.armor(c.darkened(0.22), 0.55)
	var M_DARK := K.dark()
	var top := K.b1_mount(root, M_A, 1.3)
	var M_WARHEAD := A.paint(Color(0.32, 0.34, 0.26), 0.2, 0.55, {"wear": 0.4, "panel_scale": 0.0})
	var M_TIP := A.paint(Color(0.8, 0.62, 0.12), 0.2, 0.5, {"wear": 0.5, "panel_scale": 0.0})
	# 中央电缆盒
	K.bb(top, Vector3(0.32, 0.18, 0.4), M_A2, Vector3(0, 0.09, 0.05), Vector3.ZERO, 0.02)
	A.stencil(top, "RK-4", Vector3(0, 0.181, 0.05), Vector3(-90, 0, 0), 0.003, Color(0.95, 0.92, 0.85, 0.75))
	for sx in [-1.0, 1.0]:
		# 耳轴支座
		K.bb(top, Vector3(0.1, 0.32, 0.22), M_DARK, Vector3(sx * 0.25, 0.16, 0.0), Vector3.ZERO, 0.015)
		K.cy(top, 0.07, 0.12, A.chrome(), Vector3(sx * 0.3, 0.26, 0.0), Vector3(0, 0, 90), -1.0, 12)
		var pod := K.node(top, Vector3(sx * 0.55, 0.32, 0.0), Vector3(-6, 0, 0), "Pod%d" % (0 if sx < 0 else 1))
		K.bb(pod, Vector3(0.46, 0.46, 1.0), M_A, Vector3.ZERO, Vector3.ZERO, 0.03)
		K.plate(pod, K.crect(0.94, 0.4, [0.06, 0.0, 0.0, 0.06]), 0.04, M_A2, Vector3(sx * 0.245, 0, 0), Vector3(0, 90, 0), 0.01)
		K.bb(pod, Vector3(0.48, 0.48, 0.04), M_DARK, Vector3(0, 0, -0.5), Vector3.ZERO, 0.01)
		K.bb(pod, Vector3(0.48, 0.48, 0.04), M_DARK, Vector3(0, 0, 0.5), Vector3.ZERO, 0.01)
		for i in 2:
			for j in 2:
				var tp := Vector3(-0.11 + i * 0.22, -0.11 + j * 0.22, 0)
				K.cy(pod, 0.09, 0.04, A.metal(Color(0.05, 0.05, 0.05)), tp + Vector3(0, 0, -0.52), Vector3(90, 0, 0), -1.0, 14)
				K.cy(pod, 0.07, 0.12, M_WARHEAD, tp + Vector3(0, 0, -0.5), Vector3(-90, 0, 0), 0.02, 12)
				K.cy(pod, 0.022, 0.03, M_TIP, tp + Vector3(0, 0, -0.57), Vector3(-90, 0, 0), 0.01, 8)
				K.cy(pod, 0.085, 0.02, A.paint(Color(0.5, 0.48, 0.42), 0.0, 0.8, {"panel_scale": 0.0}), tp + Vector3(0, 0, 0.52), Vector3(90, 0, 0), -1.0, 14)
		A.rivets(pod, Vector3(sx * 0.235, 0.18, -0.4), Vector3(sx * 0.235, 0.18, 0.4), 6, 0.014, Vector3(0, 0, 90))
		K.bb(pod, Vector3(0.47, 0.05, 0.06), K.accent(), Vector3(0, 0.215, -0.38), Vector3.ZERO, 0.005)
		A.stencil(pod, "DANGER", Vector3(sx * 0.27, -0.1, 0.1), Vector3(0, sx * 90.0, 0), 0.0024, Color(0.95, 0.85, 0.3, 0.8))
		# 俯仰液压缸：横梁 → 发射巢后部下方
		K.piston(top, Vector3(sx * 0.4, 0.02, 0.32), Vector3(sx * 0.5, 0.12, 0.42), 0.025)
	return root
