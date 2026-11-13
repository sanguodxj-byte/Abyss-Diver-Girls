extends RefCounted
## 重型转管炮 GAU-H：加强法兰 + 加强筋、厚机匣 + 驱动电机、外侧超大弹鼓 + 节段供弹槽、七管转管 + 三道管箍
## 接口：插头 HP-A1 → a1_mount（加强）→ 机匣；导出 muzzle
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var side: float = ctx.get("side", 1.0)
	var root := K.module_root(ctx.get("slot", "arm_r"), ctx.id, Vector3(-side, 0, 0))
	var arm := K.node(root, Vector3(side * 0.25, 0, 0), Vector3.ZERO, "Body")
	var M_ARM := K.armor(c, 0.52)
	var M_ARM2 := K.armor_sub(c, 0.55)
	var M_STEEL := K.gunmetal()
	var M_DARK := K.dark()
	K.a1_mount(arm, side, M_ARM)
	K.heavy_gussets(arm, side, M_ARM2)
	# 收敛重型肩甲比例，使其与重装躯干紧凑协调（消除夸张卡通肥大感）
	var sh := K.node(arm, Vector3(side * 0.22, 0.48, 0.04), Vector3(0, 0, side * -12.0))
	K.plate(sh, K.trap(0.98, 0.68, 0.32, 0.08), 0.78, M_ARM, Vector3.ZERO, Vector3(0, 90, 0), 0.042)
	K.plate(sh, K.crect(0.06, 0.28), 0.72, K.accent(), Vector3(side * 0.15, 0, 0), Vector3(0, 90, 0), 0.006)
	K.grab_iron(sh, 0.24, 0.045, Vector3(0, 0.17, 0), Vector3(-90, 90, 0))
	A.emblem(arm, Vector3(side * 0.52, 0.46, 0.06), Vector3(0, side * 90.0, side * -12.0), 0.24)

	var g := K.node(arm, Vector3(side * 0.50, -0.04, 0), Vector3.ZERO, "Gun")
	# 紧凑重工转管机匣 + 顶部液压驱动马达 + 退壳导流管
	K.bb(g, Vector3(0.58, 0.66, 0.98), M_STEEL, Vector3(0, 0, -0.02), Vector3.ZERO, 0.04)
	for sx in [-1.0, 1.0]:
		K.plate(g, K.crect(0.92, 0.56, [0.0, 0.14, 0.08, 0.0]), 0.07, M_ARM2, Vector3(sx * 0.31, 0.0, -0.02), Vector3(0, 90, 0), 0.015)
	K.cy(g, 0.15, 0.40, M_DARK, Vector3(0, 0.38, 0.16), Vector3(90, 0, 0), -1.0, 18)
	K.cy(g, 0.16, 0.04, K.brass(), Vector3(0, 0.38, 0.37), Vector3(90, 0, 0), -1.0, 18)
	A.hose(g, Vector3(0, 0.38, 0.38), Vector3(-side * 0.22, 0.16, 0.34), Vector3(-side * 0.08, 0.06, 0.08), 0.024)
	A.vent(g, Vector3(0.42, 0.20, 0.04), Vector3(-side * 0.34, 0.0, 0.08), Vector3(0, -side * 90.0, 0), 5)
	K.number(g, ctx.get("serial", "00"), Vector3(0, 0.34, -0.26), Vector3(-90, 0, 0), 0.004)

	# 外侧军规重型无链供弹鼓（低饱和橄榄钢灰 + 黄黑警示带 + 径向加强肋，彻底告别巨型亮橙奶酪轮）
	var M_DRUM := A.paint(Color(0.27, 0.30, 0.25), 0.24, 0.54, {"wear": 0.54, "panel_scale": 0.0})
	K.cy(g, 0.38, 0.40, M_DRUM, Vector3(side * 0.56, -0.10, 0.18), Vector3(0, 0, 90), -1.0, 26)
	for dx in [0.37, 0.75]:
		K.cy(g, 0.395, 0.035, M_DARK, Vector3(side * dx, -0.10, 0.18), Vector3(0, 0, 90), -1.0, 26)
	K.cy(g, 0.386, 0.06, A.hazard(), Vector3(side * 0.56, -0.10, 0.18), Vector3(0, 0, 90), -1.0, 26)
	K.cy(g, 0.11, 0.44, M_STEEL, Vector3(side * 0.56, -0.10, 0.18), Vector3(0, 0, 90), -1.0, 14)
	K.bolt_ring(g, 0.22, 8, 0.015, Vector3(side * 0.77, -0.10, 0.18), Vector3(0, 0, -side * 90.0))
	for i in 6:
		var a := TAU * float(i) / 6.0
		K.bb(g, Vector3(0.40, 0.035, 0.035), M_DARK, Vector3(side * 0.56, -0.10 + sin(a) * 0.26, 0.18 + cos(a) * 0.26), Vector3(rad_to_deg(a), 0, 0), 0.006)
	# 铰接柔性输弹带槽
	for i in 5:
		var t := float(i) / 4.0
		K.bb(g, Vector3(0.22, 0.15, 0.12), M_STEEL, Vector3(side * lerpf(0.48, 0.28, t), lerpf(-0.44, -0.22, t) - sin(t * PI) * 0.05, lerpf(0.02, -0.26, t)), Vector3(0, 0, side * -18.0), 0.016)

	# GAU-8 式七管加特林转管簇：回转座 + 上半防破片导流护罩 + 7根精车重枪管 + 三道多孔支撑箍 + 深黑膛口
	K.cy(g, 0.30, 0.30, M_DARK, Vector3(0, 0, -0.62), Vector3(90, 0, 0), -1.0, 24)
	K.plate(g, K.trap(0.52, 0.40, 0.56, 0.05), 0.10, M_ARM, Vector3(0, 0.22, -0.96), Vector3(88, 0, 0), 0.02)
	for i in 7:
		var a := TAU * float(i) / 7.0
		var bx := cos(a) * 0.165
		var by := sin(a) * 0.165
		K.cy(g, 0.050, 1.46, M_DARK, Vector3(bx, by, -1.48), Vector3(90, 0, 0), -1.0, 12)
		K.barrel_bore(g, 0.050, 0.035, Vector3(bx, by, -2.21), 0.07)
	K.cy(g, 0.072, 1.44, M_STEEL, Vector3(0, 0, -1.48), Vector3(90, 0, 0), -1.0, 12)
	for zz in [-0.95, -1.52, -2.08]:
		K.cy(g, 0.245, 0.09, M_STEEL, Vector3(0, 0, zz), Vector3(90, 0, 0), -1.0, 24)
		K.cy(g, 0.252, 0.03, M_DARK, Vector3(0, 0, zz), Vector3(90, 0, 0), -1.0, 24)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	g.add_child(muzzle)
	muzzle.position = Vector3(0, 0, -2.25)
	root.set_meta("muzzle", muzzle)
	return root
