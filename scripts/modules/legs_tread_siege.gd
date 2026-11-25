extends RefCounted
## 超重四履带铰接底盘 DT-9：中央飞碟式防核爆斜切底壳 + 四组独立摆臂式重型铰接履带舱（Obj-279 / 巨型工程履带风）
## 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var serial: String = ctx.get("serial", "09")
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var root := K.module_root("legs", id, Vector3.ZERO)
	var legs := root
	var M_LEG := K.armor(c, 0.54)
	var M_LEG2 := K.armor_sub(c, 0.58)
	var M_TRACK := A.metal(Color(0.15, 0.145, 0.14))
	var leg_parts: Array = []
	var hip := 1.19

	# ---- 中央高离地防冲击箱梁底壳 + 船型多面防弹装甲壳 + 重型炮塔座圈（顶接 hip+0.55 = 1.74） ----
	K.bb(legs, Vector3(1.24, 0.52, 2.38), M_FRAME, Vector3(0, 0.94, 0.0), Vector3.ZERO, 0.06)
	K.plate(legs, K.crect(1.56, 2.52, [0.38, 0.38, 0.34, 0.34]), 0.30, M_LEG, Vector3(0, 1.16, 0.0), Vector3(90, 0, 0), 0.05)
	K.plate(legs, K.crect(1.20, 2.16, [0.30, 0.30, 0.28, 0.28]), 0.22, M_LEG2, Vector3(0, 0.74, 0.0), Vector3(90, 0, 0), 0.04)
	K.plate(legs, K.crect(1.36, 1.48, [0.32, 0.32, 0.32, 0.32]), 0.24, M_LEG2, Vector3(0, 1.38, 0.0), Vector3(90, 0, 0), 0.045)
	K.cy(legs, 0.42, 0.22, M_LEG, Vector3(0, 1.56, 0.0), Vector3.ZERO, 0.56, 28)
	K.cy(legs, 0.36, 0.09, M_DARK, Vector3(0, 1.68, 0.0), Vector3.ZERO, 0.44, 28)
	for i in 6:
		var ha := TAU * i / 6.0 + 0.3
		A.hose(legs, Vector3(cos(ha) * 0.57, 1.48, sin(ha) * 0.57), Vector3(cos(ha) * 0.42, 1.68, sin(ha) * 0.42), Vector3(cos(ha) * 0.06, 0, sin(ha) * 0.06), 0.022)

	# 车首重型倾斜首上装甲（+36°）+ 防撞推梁 + 牵引耳座 + 装甲防爆投光灯 + 编号钢印
	var prow := K.node(legs, Vector3(0, 1.06, -1.24), Vector3(36, 0, 0))
	K.plate(prow, K.trap(1.44, 1.22, 0.44, 0.08), 0.18, M_LEG, Vector3.ZERO, Vector3.ZERO, 0.04)
	A.stencil(prow, "DT-" + serial, Vector3(0, 0.02, -0.098), Vector3(0, 180, 0), 0.0028, Color(0.95, 0.93, 0.86, 0.88))
	K.bb(legs, Vector3(1.32, 0.22, 0.20), M_GUN, Vector3(0, 0.82, -1.36), Vector3.ZERO, 0.025)
	K.plate(legs, K.crect(0.84, 0.065), 0.19, M_ACC, Vector3(0, 0.88, -1.38), Vector3.ZERO, 0.006)
	K.periscope(legs, 0.26, 0.09, Vector3(0, 1.32, -0.84), Vector3.ZERO)
	for sx in [-0.46, 0.46]:
		K.bb(legs, Vector3(0.20, 0.12, 0.12), M_DARK, Vector3(sx, 1.14, -1.26), Vector3.ZERO, 0.015)
		A.lens(legs, Vector3(sx, 1.14, -1.32), Vector3(-90, 0, 0), 0.032, Color(1.0, 0.92, 0.74), 2.4)
		A.add(legs, A.torus(0.038, 0.072, 12), M_GUN, Vector3(sx, 0.78, -1.46), Vector3(0, 0, 90), Vector3.ONE, false)

	# 车尾重型辅机散热舱 + 双联高压蓄能油罐
	A.vent(legs, Vector3(0.92, 0.30, 0.06), Vector3(0, 0.98, 1.28), Vector3(0, 180, 0), 6)
	for sx in [-0.38, 0.38]:
		K.cy(legs, 0.17, 0.56, M_LEG2, Vector3(sx, 1.24, 1.34), Vector3(0, 0, 90), -1.0, 16)
		K.cy(legs, 0.178, 0.03, M_DARK, Vector3(sx - 0.16, 1.24, 1.34), Vector3(0, 0, 90), -1.0, 16)
		K.cy(legs, 0.178, 0.03, M_DARK, Vector3(sx + 0.16, 1.24, 1.34), Vector3(0, 0, 90), -1.0, 16)

	# ---- 四组独立摆臂式重型铰接履带舱（FL / FR / RL / RR） ----
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var side: float = p.x
		var pod := Node3D.new()
		pod.position = Vector3(side * 0.96, 0.0, p.y * 0.92)
		legs.add_child(pod)

		# 横向重型摆臂耳轴（将独立履带舱与中央车体刚性铰接）+ 俯仰液压稳定油缸
		K.actuator(pod, Vector3(-side * 0.32, 0.62, 0.0), 0.20, 0.48)
		K.bb(pod, Vector3(0.46, 0.24, 0.36), M_FRAME, Vector3(-side * 0.24, 0.62, 0.0), Vector3.ZERO, 0.025)
		K.piston(pod, Vector3(-side * 0.28, 1.04, -p.y * 0.22), Vector3(-side * 0.02, 0.72, -p.y * 0.34), 0.036)
		A.hose(pod, Vector3(-side * 0.32, 0.84, 0.10), Vector3(-side * 0.06, 0.68, 0.16), Vector3(0, 0.08, 0.08), 0.022)

		var straight := 0.96
		var r_arc := 0.27
		K.bb(pod, Vector3(0.56, 0.05, straight + 0.06), A.rubber(), Vector3(0, 0.59, 0), Vector3.ZERO, 0.01)
		K.bb(pod, Vector3(0.56, 0.05, straight + 0.06), A.rubber(), Vector3(0, 0.065, 0), Vector3.ZERO, 0.01)
		for ez in [-straight * 0.5, straight * 0.5]:
			K.cy(pod, 0.255, 0.56, A.rubber(), Vector3(0, 0.33, ez), Vector3(0, 0, 90), -1.0, 18)

		var links := 24
		var per := 2.0 * straight + TAU * r_arc
		for i in links:
			var d := (float(i) / float(links)) * per
			var pos: Vector3
			var ang := 0.0
			if d < straight:
				pos = Vector3(0, 0.60, -straight * 0.5 + d); ang = 0.0
			elif d < straight + PI * r_arc:
				var a := (d - straight) / r_arc
				pos = Vector3(0, 0.33 + cos(a) * r_arc, straight * 0.5 + sin(a) * r_arc); ang = -rad_to_deg(a)
			elif d < 2.0 * straight + PI * r_arc:
				pos = Vector3(0, 0.06, straight * 0.5 - (d - straight - PI * r_arc)); ang = 180.0
			else:
				var a := (d - 2.0 * straight - PI * r_arc) / r_arc
				pos = Vector3(0, 0.33 - cos(a) * r_arc, -straight * 0.5 - sin(a) * r_arc); ang = 180.0 - rad_to_deg(a)
			var shoe := K.node(pod, pos, Vector3(ang, 0, 0))
			K.bb(shoe, Vector3(0.62, 0.05, 0.145), M_TRACK, Vector3.ZERO, Vector3.ZERO, 0.01)
			K.bb(shoe, Vector3(0.58, 0.028, 0.048), M_GUN, Vector3(0, 0.032, 0), Vector3.ZERO, 0.005)

		for ez in [-0.48, 0.48]:
			K.cy(pod, 0.23, 0.48, M_DARK, Vector3(0, 0.34, ez), Vector3(0, 0, 90), -1.0, 18)
			K.cy(pod, 0.11, 0.54, M_GUN, Vector3(0, 0.34, ez), Vector3(0, 0, 90), -1.0, 12)
			K.bolt_ring(pod, 0.16, 8, 0.014, Vector3(side * 0.25, 0.34, ez), Vector3(0, 0, -side * 90.0))
		for wz in [-0.26, 0.0, 0.26]:
			for wx in [-0.14, 0.14]:
				K.cy(pod, 0.175, 0.15, M_DARK, Vector3(wx, 0.24, wz), Vector3(0, 0, 90), -1.0, 16)
				K.cy(pod, 0.115, 0.16, M_LEG2, Vector3(wx, 0.24, wz), Vector3(0, 0, 90), -1.0, 14)
			K.cy(pod, 0.065, 0.50, A.chrome(), Vector3(0, 0.24, wz), Vector3(0, 0, 90), -1.0, 10)

		# 独立履带舱顶盖护罩 + 外侧切角重型防弹护板 + 警示条与吊环
		K.plate(pod, K.crect(1.36, 0.08, [0.10, 0.10, 0.04, 0.04]), 0.68, M_LEG, Vector3(0, 0.72, 0), Vector3(0, 90, 0), 0.022)
		K.plate(pod, K.trap(1.26, 1.04, 0.42, 0.06), 0.11, M_LEG2, Vector3(side * 0.34, 0.52, 0), Vector3(0, 90, 0), 0.025)
		K.plate(pod, K.crect(0.46, 0.055), 0.12, M_ACC, Vector3(side * 0.35, 0.64, -p.y * 0.22), Vector3(0, 90, 0), 0.005)
		K.grab_iron(pod, 0.22, 0.04, Vector3(0, 0.76, 0.0), Vector3(-90, 90, 0), 0.013)
		for fz in [-0.68, 0.68]:
			K.bb(pod, Vector3(0.64, 0.22, 0.045), A.rubber(), Vector3(0, 0.56, fz), Vector3(fz * 18.0, 0, 0), 0.008)
		leg_parts.append(pod)

	K.socket(root, "core", Vector3(0, hip + 0.55, 0), Vector3.UP)
	root.set_meta("leg_parts", leg_parts)
	root.set_meta("leg_type", "tread")
	return root
