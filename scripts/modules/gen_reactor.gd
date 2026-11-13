extends RefCounted
## 微型反应堆：圆柱压力容器、径向散热片、冷却回路
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
	# 铅屏蔽重型承力鞍座 + 锻钢圆柱压力安全壳（取代原外露巨型荧光甜甜圈）
	for sx in [-1.0, 1.0]:
		K.plate(b, K.trap(0.38, 0.24, 0.54, 0.04), 0.06, M_SUB, Vector3(sx * 0.34, 0, 0.20), Vector3(0, 90, 0), 0.012)
	K.cy(b, 0.26, 0.44, M_H, Vector3(0, 0, 0.24), Vector3(90, 0, 0), -1.0, 24)
	K.cy(b, 0.28, 0.055, M_DARK, Vector3(0, 0, 0.06), Vector3(90, 0, 0), -1.0, 24)
	K.cy(b, 0.285, 0.065, M_GUN, Vector3(0, 0, 0.45), Vector3(90, 0, 0), -1.0, 24)
	K.bolt_ring(b, 0.25, 12, 0.016, Vector3(0, 0, 0.485), Vector3(-90, 0, 0))
	# 12 片径向锻造热交换散热翼片 + 中腰紧固钢箍
	K.cy(b, 0.305, 0.032, M_DARK, Vector3(0, 0, 0.25), Vector3(90, 0, 0), -1.0, 24)
	for i in 12:
		var a := TAU * i / 12.0
		K.bb(b, Vector3(0.018, 0.095, 0.34), M_GUN, Vector3(cos(a) * 0.295, sin(a) * 0.295, 0.25), Vector3(0, 0, rad_to_deg(a) + 90.0), 0.004)
	# 尾部螺栓封头 + 厚重铅玻璃防辐射观察窗 + 十字防爆钢栅栏（克制内敛的切伦科夫辉光）
	A.add(b, A.sphere(0.24, 0.48, 20), M_SUB, Vector3(0, 0, 0.46), Vector3.ZERO, Vector3(1, 1, 0.36))
	K.cy(b, 0.145, 0.06, M_DARK, Vector3(0, 0, 0.525), Vector3(90, 0, 0), -1.0, 18)
	K.bolt_ring(b, 0.125, 8, 0.012, Vector3(0, 0, 0.558), Vector3(-90, 0, 0))
	K.cy(b, 0.098, 0.03, K.bore_mat(), Vector3(0, 0, 0.542), Vector3(90, 0, 0), -1.0, 16)
	K.cy(b, 0.088, 0.016, K.canopy(gc, 0.95), Vector3(0, 0, 0.548), Vector3(90, 0, 0), -1.0, 16)
	for rot_z in [0.0, 90.0]:
		K.bb(b, Vector3(0.19, 0.020, 0.018), M_GUN, Vector3(0, 0, 0.558), Vector3(0, 0, rot_z), 0.003)
	# 顶部稳压泄压阀、黄铜剂量计接口与双侧主冷却剂循环泵管路
	K.cy(b, 0.045, 0.11, K.brass(), Vector3(0, 0.31, 0.16), Vector3.ZERO, -1.0, 10)
	K.cy(b, 0.062, 0.025, K.accent(), Vector3(0, 0.37, 0.16), Vector3.ZERO, -1.0, 10)
	var M_COOL := A.paint(Color(0.15, 0.28, 0.38), 0.15, 0.55, {"panel_scale": 0.0})
	for sx in [-1.0, 1.0]:
		K.cy(b, 0.065, 0.18, M_DARK, Vector3(sx * 0.31, -0.16, 0.22), Vector3(90, 0, 0), -1.0, 12)
		A.hose(b, Vector3(sx * 0.31, 0.20, 0.04), Vector3(sx * 0.24, 0.18, 0.42), Vector3(sx * 0.08, 0.05, 0), 0.026, M_COOL)
		A.hose(b, Vector3(sx * 0.31, -0.16, 0.31), Vector3(sx * 0.28, -0.22, 0.04), Vector3(sx * 0.04, -0.04, 0), 0.024)
	A.stencil(b, "CAUTION  RADIATION", Vector3(0, -0.285, 0.24), Vector3(90, 180, 0), 0.0022, Color(0.95, 0.84, 0.28, 0.85))
	if lights:
		K.light(b, gc, Vector3(0, 0, 0.66), 0.14, 1.4)
	return root
