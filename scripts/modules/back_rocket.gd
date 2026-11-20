extends RefCounted
## 双联火箭巢 RK-4：两只 2×2 箱式发射巢，耳轴 + 俯仰液压缸，前盖露出弹头，后部易碎封盖
## 接口：插头 HP-B1 → b1_mount（导轨卡箍 + 横梁）→ 发射巢；局部 +Y 远离躯干
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const DM = preload("res://scripts/modules/device_models.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("back", ctx.id, Vector3(0, -1, -0.25))
	var M_A := K.armor(c, 0.55)
	var M_A2 := K.armor_sub(c, 0.58)
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var top := K.b1_mount(root, M_A, 1.32)
	var M_WARHEAD := A.paint(Color(0.29, 0.32, 0.24), 0.20, 0.52, {"wear": 0.42, "panel_scale": 0.0})
	# 中央点火分配盒 + 旋转测角传感器
	K.bb(top, Vector3(0.34, 0.20, 0.42), M_A2, Vector3(0, 0.10, 0.05), Vector3.ZERO, 0.02)
	K.cy(top, 0.08, 0.05, M_GUN, Vector3(0, 0.22, 0.02), Vector3.ZERO, -1.0, 20)
	A.stencil(top, "RK-4", Vector3(0, 0.202, 0.14), Vector3(-90, 0, 0), 0.003, Color(0.92, 0.90, 0.84, 0.78))
	for sx in [-1.0, 1.0]:
		# 重型耳轴立座 + 法兰轴承 + 点火脐带软管
		K.bb(top, Vector3(0.11, 0.34, 0.24), M_DARK, Vector3(sx * 0.25, 0.17, 0.0), Vector3.ZERO, 0.016)
		K.cy(top, 0.085, 0.14, M_GUN, Vector3(sx * 0.30, 0.27, 0.0), Vector3(0, 0, 90), -1.0, 20)
		K.bolt_ring(top, 0.068, 6, 0.012, Vector3(sx * 0.23, 0.27, 0.0), Vector3(0, 0, 90))
		A.hose(top, Vector3(sx * 0.16, 0.14, 0.20), Vector3(sx * 0.42, 0.22, 0.34), Vector3(0, -0.05, 0.06), 0.020)
		var pod := K.node(top, Vector3(sx * 0.56, 0.33, 0.0), Vector3(-6, 0, 0), "Pod%d" % (0 if sx < 0 else 1))
		# 模块化储运发射箱（MLRS 压筋箱体 + 前后加强钢框 + 吊耳）
		K.bb(pod, Vector3(0.48, 0.48, 1.02), M_A, Vector3.ZERO, Vector3.ZERO, 0.028)
		for rz in [-0.32, -0.10, 0.12, 0.34]:
			K.bb(pod, Vector3(0.505, 0.495, 0.036), M_A2, Vector3(0, 0, rz), Vector3.ZERO, 0.008)
		K.plate(pod, K.crect(0.92, 0.38, [0.05, 0.0, 0.0, 0.05]), 0.035, M_A2, Vector3(sx * 0.245, 0, 0), Vector3(0, 90, 0), 0.01)
		K.bb(pod, Vector3(0.51, 0.51, 0.055), M_GUN, Vector3(0, 0, -0.50), Vector3.ZERO, 0.012)
		K.bb(pod, Vector3(0.51, 0.51, 0.055), M_GUN, Vector3(0, 0, 0.50), Vector3.ZERO, 0.012)
		K.grab_iron(pod, 0.22, 0.045, Vector3(0, 0.245, -0.22), Vector3(-90, 90, 0))
		K.grab_iron(pod, 0.22, 0.045, Vector3(0, 0.245, 0.22), Vector3(-90, 90, 0))
		for i in 2:
			for j in 2:
				var tp := Vector3(-0.115 + i * 0.23, -0.115 + j * 0.23, 0)
				# 已装填 MLRS 火箭：加厚倒圆管口唇 + 探出管口的高爆战斗部（黄色识别环 + 黄铜引信）
				DM.launch_tube(pod, tp + Vector3(0, 0, -0.528), 0.084, Color(0.29, 0.32, 0.24))
				# 尾部易碎防潮封盖（带十字预刻破片筋）
				var M_CAP := A.paint(Color(0.44, 0.42, 0.36), 0.05, 0.82, {"wear": 0.25, "panel_scale": 0.0})
				K.cy(pod, 0.088, 0.022, M_CAP, tp + Vector3(0, 0, 0.525), Vector3(90, 0, 0), -1.0, 20)
				K.bb(pod, Vector3(0.15, 0.012, 0.008), M_DARK, tp + Vector3(0, 0, 0.538), Vector3(0, 0, 45), 0.002)
				K.bb(pod, Vector3(0.15, 0.012, 0.008), M_DARK, tp + Vector3(0, 0, 0.538), Vector3(0, 0, -45), 0.002)
		K.bb(pod, Vector3(0.49, 0.045, 0.065), K.accent(), Vector3(0, 0.232, -0.40), Vector3.ZERO, 0.005)
		A.stencil(pod, "DANGER", Vector3(sx * 0.268, -0.11, 0.02), Vector3(0, sx * 90.0, 0), 0.0025, Color(0.95, 0.84, 0.30, 0.82))
		# 俯仰液压作动缸
		K.piston(top, Vector3(sx * 0.40, 0.03, 0.30), Vector3(sx * 0.50, 0.14, 0.42), 0.028)
	return root
