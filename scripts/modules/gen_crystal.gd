extends RefCounted
## 虫晶反应炉：约束笼 + 悬浮虫晶 + 抑制线圈
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
	# 重工业高危样本谐振约束舱：上下装甲端盖 + 四角液压减震立柱 + 侧向防爆百叶护罩
	for sy in [-0.26, 0.26]:
		K.plate(b, K.crect(0.68, 0.48, [0.09, 0.09, 0.09, 0.09]), 0.085, M_H, Vector3(0, sy, 0.26), Vector3(90, 0, 0), 0.018)
		K.cy(b, 0.21, 0.045, M_GUN, Vector3(0, sy - signf(sy) * 0.05, 0.26), Vector3.ZERO, -1.0, 18)
	for sx in [-1.0, 1.0]:
		K.plate(b, K.crect(0.36, 0.42, [0.0, 0.06, 0.06, 0.0]), 0.045, M_SUB, Vector3(sx * 0.34, 0, 0.22), Vector3(0, 90, 0), 0.012)
		K.grab_iron(b, 0.20, 0.04, Vector3(sx * 0.37, 0.0, 0.22), Vector3(0, -sx * 90.0, 90))
	for p in [Vector2(-0.27, 0.08), Vector2(0.27, 0.08), Vector2(-0.27, 0.44), Vector2(0.27, 0.44)]:
		K.cy(b, 0.032, 0.44, M_DARK, Vector3(p.x, 0, p.y), Vector3.ZERO, -1.0, 10)
		K.cy(b, 0.020, 0.48, A.chrome(), Vector3(p.x, 0, p.y), Vector3.ZERO, -1.0, 8)
		K.cy(b, 0.040, 0.04, K.brass(), Vector3(p.x, 0.16, p.y), Vector3.ZERO, -1.0, 10)
		K.cy(b, 0.040, 0.04, K.brass(), Vector3(p.x, -0.16, p.y), Vector3.ZERO, -1.0, 10)
	# 双层纯铜电磁拾取感应线圈 + 钢制防爆竖肋笼 + 深色石英观察腔
	for y in [-0.11, 0.11]:
		A.add(b, A.torus(0.165, 0.198, 24), K.copper(), Vector3(0, y, 0.26), Vector3.ZERO, Vector3.ONE, false)
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.52
		K.bb(b, Vector3(0.018, 0.42, 0.028), M_GUN, Vector3(cos(a) * 0.195, 0, 0.26 + sin(a) * 0.195), Vector3(0, -rad_to_deg(a), 0), 0.004)
	# 上下机械卡爪电极夹持虫晶原石（克制半透明晶簇辉光，避免廉价纯白荧光块）
	for sy in [-1.0, 1.0]:
		K.cy(b, 0.055, 0.08, M_DARK, Vector3(0, sy * 0.19, 0.26), Vector3.ZERO, 0.035, 10)
	var cm := K.canopy(gc, 1.15)
	A.add(b, A.cyl(0.015, 0.17, 0.085, 6), cm, Vector3(0, 0.085, 0.26), Vector3(0, 18, 0), Vector3.ONE, false)
	A.add(b, A.cyl(0.085, 0.17, 0.015, 6), cm, Vector3(0, -0.085, 0.26), Vector3(0, 18, 0), Vector3.ONE, false)
	# 尾部重型联锁插销与高压引线
	K.bb(b, Vector3(0.32, 0.055, 0.04), K.accent(), Vector3(0, 0.265, 0.48), Vector3.ZERO, 0.005)
	for sx in [-1.0, 1.0]:
		A.hose(b, Vector3(sx * 0.18, -0.11, 0.26), Vector3(sx * 0.28, -0.20, 0.04), Vector3(sx * 0.06, -0.04, 0), 0.020)
	A.stencil(b, "HAZMAT  CLASS-4", Vector3(0.0, 0.305, 0.26), Vector3(-90, 0, 0), 0.0024, Color(0.95, 0.85, 0.30, 0.85))
	if lights:
		K.light(b, gc, Vector3(0, 0, 0.48), 0.16, 1.5)
	return root
