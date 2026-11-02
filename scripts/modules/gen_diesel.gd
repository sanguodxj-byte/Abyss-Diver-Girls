extends RefCounted
## 柴油发电机组 DG-130：直列缸体 + 带肋缸盖、排气歧管接竖置消音筒（防雨帽）、尾部散热器 + 风扇护罩、燃油滤清器
## 接口：插头 HP-G1（朝前插入动力舱）→ g1_mount（背板 + 四角锁销）→ 机组；局部 +Z 向后
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var c: Color = ctx.color
	var root := K.module_root("gen", ctx.id, Vector3.FORWARD)
	var M_H := K.armor(c, 0.6)
	var M_DARK := K.dark()
	var M_BLOCK := A.metal(Color(0.2, 0.21, 0.2))
	var b := K.g1_mount(root, M_H, 0.82, 0.66)
	# 缸体 + 缸盖
	K.bb(b, Vector3(0.6, 0.4, 0.42), M_BLOCK, Vector3(0, -0.06, 0.21), Vector3.ZERO, 0.03)
	K.bb(b, Vector3(0.5, 0.12, 0.38), M_H, Vector3(0, 0.2, 0.21), Vector3.ZERO, 0.025)
	for i in 6:
		K.bb(b, Vector3(0.46, 0.025, 0.02), M_H, Vector3(0, 0.27, 0.06 + i * 0.06), Vector3.ZERO, 0.004)
	A.stencil(b, "DIESEL", Vector3(-0.301, -0.06, 0.21), Vector3(0, -90, 0), 0.0028, Color(0.95, 0.85, 0.3, 0.85))
	# 排气歧管 → 竖置消音筒 + 防雨帽
	for i in 3:
		K.cy(b, 0.03, 0.08, M_DARK, Vector3(0.27, 0.12, 0.1 + i * 0.1), Vector3(0, 0, 90), -1.0, 8)
	A.hose(b, Vector3(0.3, 0.12, 0.2), Vector3(0.33, 0.3, 0.32), Vector3(0.04, 0.0, 0), 0.04, A.metal(Color(0.32, 0.26, 0.2)))
	K.cy(b, 0.075, 0.5, A.metal(Color(0.3, 0.26, 0.22)), Vector3(0.33, 0.52, 0.32), Vector3.ZERO, -1.0, 14)
	for yy in [0.38, 0.66]:
		K.cy(b, 0.085, 0.03, M_DARK, Vector3(0.33, yy, 0.32), Vector3.ZERO, -1.0, 14)
	K.bb(b, Vector3(0.18, 0.015, 0.18), M_DARK, Vector3(0.33, 0.8, 0.32), Vector3(0, 0, 25), 0.004)
	# 尾部散热器 + 风扇护罩
	K.bb(b, Vector3(0.68, 0.52, 0.08), M_H, Vector3(0, -0.02, 0.48), Vector3.ZERO, 0.02)
	A.vent(b, Vector3(0.56, 0.42, 0.03), Vector3(0, -0.02, 0.53), Vector3(0, 180, 0), 8)
	A.add(b, A.torus(0.15, 0.19, 24), M_DARK, Vector3(0, -0.02, 0.55), Vector3(90, 0, 0), Vector3(1, 0.4, 1), false)
	for i in 4:
		K.bb(b, Vector3(0.03, 0.15, 0.01), M_DARK, Vector3(0, -0.02, 0.555), Vector3(0, 0, i * 45.0), 0.003)
	# 交流发电机 + 燃油滤清器 + 油管
	K.cy(b, 0.12, 0.26, M_DARK, Vector3(-0.2, -0.24, 0.32), Vector3(90, 0, 0), -1.0, 16)
	K.cy(b, 0.045, 0.14, A.paint(Color(0.6, 0.45, 0.12), 0.1, 0.6, {"panel_scale": 0.0}), Vector3(-0.33, 0.06, 0.24), Vector3.ZERO, -1.0, 10)
	A.hose(b, Vector3(-0.33, -0.02, 0.24), Vector3(-0.28, -0.1, 0.06), Vector3(-0.03, -0.04, 0), 0.015)
	return root
