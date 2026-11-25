extends RefCounted
## 混凝土龙牙反坦锥与半掩输油管弹坑（B5-24 · 对应远端 scripts/raid.gd & maps.gd (M3.2)）
## 优化清单：P1-M3.2 | 标准占地：Vector3(10.4, 2.3, 7.6) | 外挑预算 <= 0.4m
## 荒原反装甲防线微观战术掩体群：前排由地下混凝土连系梁串联双排交错共 9 座四棱台钢筋混凝土“龙牙”反坦克锥（含顶吊装钢环与穿甲弹崩裂露筋细节），后侧横卧被炮火炸断的 1.06m 大口径法兰锈蚀输油管道与隆起焦土重炮弹坑环。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const HS = preload("res://scripts/hs.gd")

static func build(target_sz := Vector3(10.4, 2.3, 7.6)) -> Node3D:
	var root := Node3D.new()
	root.name = "Ter_DragonTeethAndPipe"
	var base_sz := Vector3(10.4, 2.3, 7.6)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)
	var M_TOOTH := A.concrete(Color(0.46, 0.44, 0.40), false)
	var M_BEAM := A.concrete(Color(0.35, 0.34, 0.31), false)
	var M_CHIP := A.concrete(Color(0.32, 0.31, 0.28), false)
	var M_REBAR := A.paint(Color(0.34, 0.19, 0.11), 0.55, 0.80, {"rust": 0.94, "wear": 0.62, "grime": 0.82, "panel_scale": 0.0})
	var M_PIPE := A.paint(Color(0.33, 0.24, 0.18), 0.42, 0.82, {"rust": 0.92, "wear": 0.68, "grime": 0.88, "dust": 0.24, "scratches": 0.28, "panel_scale": 0.0})
	var M_CRADLE := A.concrete(Color(0.42, 0.40, 0.37), false)
	var n_1 := K.node(root, Vector3.ZERO, Vector3.ZERO, "GroundedApron")
	# 去掉突兀的 10.4x7.6 方形沙盘底板，仅保留龙牙底部的嵌入式钢筋混凝土连系垫层，自然融入真实地表
	K.bb(n_1, Vector3(9.4, 0.12, 2.75), A.concrete(Color(0.38, 0.37, 0.34), false), Vector3(0, 0.06, -1.55), Vector3.ZERO, 0.02)
	var n_2 := K.node(root, Vector3(0, -0.10, 0), Vector3.ZERO, "DragonTeethBarrier")
	K.bb(n_2, Vector3(9.1, 0.18, 0.56), M_BEAM, Vector3(0, 0.28, -2.25), Vector3.ZERO, 0.015)
	K.bb(n_2, Vector3(8.2, 0.18, 0.56), M_BEAM, Vector3(0, 0.28, -0.88), Vector3.ZERO, 0.015)
	# 9 座硬棱四棱台现浇混凝土反坦“龙牙”（使用平直倒角棱台替代光滑 4 边圆柱，消除塑料圆锥感）
	var n_3 := K.node(n_2, Vector3(-4, 0.26, -2.25), Vector3(0, -4, 0), "DragonTooth")
	K.bb(n_3, Vector3(0.96, 1.19, 0.96), M_TOOTH, Vector3(0, 0.595, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_3, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.21, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	var n_4 := K.node(n_2, Vector3(-2, 0.26, -2.25), Vector3.ZERO, "DragonTooth")
	K.bb(n_4, Vector3(0.96, 1.19, 0.96), M_TOOTH, Vector3(0, 0.595, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_4, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.21, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	K.bb(n_4, Vector3(0.28, 0.22, 0.18), M_CHIP, Vector3(0.16, 0.738, -0.28), Vector3(16, -18, 8), 0.012)
	K.cy(n_4, 0.014, 0.36, M_REBAR, Vector3(0.18, 0.857, -0.32), Vector3(32, 0, -22), 0.014, 6)
	var n_5 := K.node(n_2, Vector3(0, 0.26, -2.25), Vector3(0, 4, 0), "DragonTooth")
	K.bb(n_5, Vector3(0.96, 1.339, 0.96), M_TOOTH, Vector3(0, 0.67, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_5, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.359, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	var n_6 := K.node(n_2, Vector3(2, 0.26, -2.25), Vector3(0, -4, 0), "DragonTooth")
	K.bb(n_6, Vector3(0.96, 1.19, 0.96), M_TOOTH, Vector3(0, 0.595, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_6, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.21, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	K.bb(n_6, Vector3(0.28, 0.22, 0.18), M_CHIP, Vector3(0.16, 0.738, -0.28), Vector3(16, -18, 8), 0.012)
	K.cy(n_6, 0.014, 0.36, M_REBAR, Vector3(0.18, 0.857, -0.32), Vector3(32, 0, -22), 0.014, 6)
	var n_7 := K.node(n_2, Vector3(4, 0.26, -2.25), Vector3.ZERO, "DragonTooth")
	K.bb(n_7, Vector3(0.96, 1.19, 0.96), M_TOOTH, Vector3(0, 0.595, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_7, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.21, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	var n_8 := K.node(n_2, Vector3(-3, 0.26, -0.88), Vector3(0, 5, 0), "DragonTooth")
	K.bb(n_8, Vector3(0.96, 1.265, 0.96), M_TOOTH, Vector3(0, 0.632, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_8, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.285, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	var n_9 := K.node(n_2, Vector3(-1, 0.26, -0.88), Vector3(0, -5, 0), "DragonTooth")
	K.bb(n_9, Vector3(0.96, 1.166, 0.96), M_TOOTH, Vector3(0, 0.583, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_9, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.186, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	var n_10 := K.node(n_2, Vector3(1, 0.26, -0.88), Vector3(0, 5, 0), "DragonTooth")
	K.bb(n_10, Vector3(0.96, 1.265, 0.96), M_TOOTH, Vector3(0, 0.632, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_10, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.285, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	K.bb(n_10, Vector3(0.28, 0.22, 0.18), M_CHIP, Vector3(0.16, 0.784, -0.28), Vector3(16, -18, 8), 0.012)
	K.cy(n_10, 0.014, 0.36, M_REBAR, Vector3(0.18, 0.911, -0.32), Vector3(32, 0, -22), 0.014, 6)
	var n_11 := K.node(n_2, Vector3(3, 0.26, -0.88), Vector3(0, -5, 0), "DragonTooth")
	K.bb(n_11, Vector3(0.96, 1.166, 0.96), M_TOOTH, Vector3(0, 0.583, 0), Vector3.ZERO, 0.032, 0.34)
	A.add(n_11, A.torus(0.055, 0.078, 10), K.dark(), Vector3(0, 1.186, 0), Vector3(90, 0, 0), Vector3(1, 0.8, 1), false)
	var n_12 := K.node(root, Vector3(1.15, 0.0, 1.35), Vector3.ZERO, "ArtilleryShellCrater")
	# 用自然焦痕贴花与不规则碎岩堆替代原先规整的十棱圆台与 8 块等距方盒
	var M_CR_ROCK := A.rock_mat(Color(0.32, 0.29, 0.25))
	A.ground_decal(n_12, A.scorch_tex(), Color(0.85, 0.80, 0.74, 0.88), 4.6, Vector3(0.0, 0.04, 0.0))
	for ri in 7:
		var ra := TAU * float(ri) / 7.0 + float(ri % 3) * 0.18
		var rr := 1.45 + float(ri % 2) * 0.34
		var rsc := 0.42 + float((ri * 5) % 4) * 0.12
		A.add(n_12, A.rock_mesh(ri * 3 + 7), M_CR_ROCK,
			Vector3(cos(ra) * rr, rsc * 0.22, sin(ra) * rr),
			Vector3(float(ri % 3 - 1) * 14.0, float(ri) * 53.0, float((ri + 1) % 3 - 1) * 12.0),
			Vector3(rsc * 1.45, rsc * 0.52, rsc * 1.15))
	var n_13 := K.node(root, Vector3.ZERO, Vector3.ZERO, "RupturedOilPipeline")
	var n_14 := K.node(n_13, Vector3(-2.45, 0.92, 1.35), Vector3(0, -8, 4), "PipelineWest")
	K.bb(n_14, Vector3(0.62, 0.64, 1.32), M_CRADLE, Vector3(-1.15, -0.34, 0), Vector3.ZERO, 0.016)
	K.bb(n_14, Vector3(0.62, 0.64, 1.32), M_CRADLE, Vector3(0.85, -0.34, 0), Vector3.ZERO, 0.016)
	K.cy(n_14, 0.53, 3.85, M_PIPE, Vector3(0, 0.08, 0), Vector3(0, 0, 90), 0.53, 18)
	K.cy(n_14, 0.46, 0.28, K.bore_mat(), Vector3(1.88, 0.08, 0), Vector3(0, 0, 90), 0.46, 14)
	A.add(n_14, A.torus(0.51, 0.61, 18), K.gunmetal(), Vector3(-1.45, 0.08, 0), Vector3(0, 0, 90), Vector3(1, 0.65, 1), false)
	A.add(n_14, A.torus(0.51, 0.61, 18), K.gunmetal(), Vector3(0.25, 0.08, 0), Vector3(0, 0, 90), Vector3(1, 0.65, 1), false)
	K.bb(n_14, Vector3(0.42, 0.045, 0.22), K.dark(), Vector3(2.02, 0.56, 0), Vector3(0, 0, 18), 0.005)
	K.bb(n_14, Vector3(0.42, 0.045, 0.22), K.dark(), Vector3(2.02, 0.228, 0.457), Vector3(0, -12, 90), 0.005)
	K.bb(n_14, Vector3(0.42, 0.045, 0.22), K.dark(), Vector3(2.02, -0.308, 0.282), Vector3(0, -24, 162), 0.005)
	K.bb(n_14, Vector3(0.42, 0.045, 0.22), K.dark(), Vector3(2.02, -0.308, -0.282), Vector3(0, -36, 234), 0.005)
	K.bb(n_14, Vector3(0.42, 0.045, 0.22), K.dark(), Vector3(2.02, 0.228, -0.457), Vector3(0, -48, 306), 0.005)
	var n_15 := K.node(n_13, Vector3(3.35, 0.84, 1.72), Vector3(0, 12, -8), "PipelineEast")
	K.bb(n_15, Vector3(0.68, 0.58, 1.24), M_CRADLE, Vector3(0.35, -0.28, 0), Vector3.ZERO, 0.016)
	K.cy(n_15, 0.53, 2.25, M_PIPE, Vector3(0, 0.06, 0), Vector3(0, 0, 90), 0.53, 18)
	K.cy(n_15, 0.46, 0.24, K.bore_mat(), Vector3(-1.06, 0.06, 0), Vector3(0, 0, 90), 0.46, 14)
	A.add(n_15, A.torus(0.51, 0.61, 18), K.gunmetal(), Vector3(0.42, 0.06, 0), Vector3(0, 0, 90), Vector3(1, 0.65, 1), false)
	return root
