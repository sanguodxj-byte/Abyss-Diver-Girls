extends RefCounted
## 三级自然簇化枯木沙棘与倾倒电塔（B5-25 · 对应远端 scripts/raid.gd :: _build_fields & _scatter (M3.1/M3.2)）
## 优化清单：P1-M3.1 / P1-M3.2 | 标准占地：Vector3(10.8, 5.4, 8.2) | 外挑预算 <= 0.4m
## 彻底取代原仓“规则网格暗色方块灌木”的三级荒原自然生态与电力残骸群落：一级为两株多叉扭曲防风林胡杨枯木主干，二级为 4 丛多枝干耐旱沙棘刺灌簇，三级为 6 丛贴地荒漠针茅干草簇，中央斜插半截带陶瓷绝缘子串的倾倒高压输电角钢塔架。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const HS = preload("res://scripts/hs.gd")

static func build(target_sz := Vector3(10.8, 5.4, 8.2)) -> Node3D:
	var root := Node3D.new()
	root.name = "Ter_AridFloraAndPylon"
	var base_sz := Vector3(10.8, 5.4, 8.2)
	root.scale = Vector3(target_sz.x / base_sz.x, target_sz.y / base_sz.y, target_sz.z / base_sz.z)
	# 取消原先突兀的方形硬边塑料底板与光面泥饼土包，所有枯木、灌丛、草簇、碎石与倾倒铁塔直接自然扎根于真实地表
	var M_BARK := A.bark_mat(Color(0.29, 0.24, 0.19))
	var M_ROCK := A.rock_mat(Color(0.35, 0.31, 0.26))
	var M_SHRUB := A.foliage_mat("shrub")
	var M_GRASS := A.foliage_mat("grass")
	# 一级：两株高精板根扭曲分叉枯木（复用新版 tree_trunk_mesh 写实枯木，彻底告别 6 棱棍棒树）
	A.add(root, A.dead_tree_mesh(0), M_BARK, Vector3(-3.15, 0.0, -1.45), Vector3(2.0, 18.0, -2.5), Vector3.ONE * 4.55)
	A.add(root, A.dead_tree_mesh(1), M_BARK, Vector3(3.15, 0.0, 1.58), Vector3(-2.5, -125.0, 3.0), Vector3.ONE * 3.85)
	# 二级：4 丛高精 1024px 多层拱曲耐旱灌丛（取代原先倒扣六棱绿陶杯）
	for si in 4:
		var sp_arr := [
			[Vector3(-2.05, 0.0, -2.05), 15.0, 1.05],
			[Vector3(-3.95, 0.0, 0.65), 72.0, 0.88],
			[Vector3(2.25, 0.0, 2.28), -42.0, 0.96],
			[Vector3(3.85, 0.0, -0.95), 118.0, 0.82],
		]
		var sp: Array = sp_arr[si]
		var ssc: float = float(sp[2])
		A.add(root, A.shrub_mesh(si), M_SHRUB, sp[0], Vector3(0.0, float(sp[1]), 0.0), Vector3(ssc * 1.15, ssc * 0.92, ssc * 1.15), false)
	# 三级：6 丛写实贴地野草簇 + 铁塔底座碎岩砾石
	for gi in 6:
		var gp_arr := [
			[Vector3(-1.25, 0.0, 1.95), 24.0, 0.85],
			[Vector3(-4.25, 0.0, -2.65), 112.0, 0.72],
			[Vector3(0.95, 0.0, -2.45), -35.0, 0.80],
			[Vector3(1.65, 0.0, 0.45), 68.0, 0.70],
			[Vector3(4.35, 0.0, 2.75), -84.0, 0.76],
			[Vector3(-0.45, 0.0, 2.85), 145.0, 0.68],
		]
		var gp: Array = gp_arr[gi]
		var gsc: float = float(gp[2])
		A.add(root, A.grass_clump_mesh(), M_GRASS, gp[0], Vector3(0.0, float(gp[1]), 0.0), Vector3(gsc * 0.95, gsc, gsc * 0.95), false)
	for ri in 5:
		var rp_arr := [
			[Vector3(1.25, 0.14, -0.95), Vector3(0.75, 0.36, 0.62), 28.0],
			[Vector3(-0.55, 0.12, -1.10), Vector3(0.62, 0.30, 0.54), 104.0],
			[Vector3(0.90, 0.16, 0.55), Vector3(0.84, 0.40, 0.68), -45.0],
			[Vector3(-2.65, 0.10, -0.85), Vector3(0.55, 0.24, 0.48), 64.0],
			[Vector3(2.55, 0.11, 1.10), Vector3(0.58, 0.26, 0.50), -118.0],
		]
		var rp: Array = rp_arr[ri]
		A.add(root, A.rock_mesh(ri * 3 + 5), M_ROCK, rp[0], Vector3(0.0, float(rp[2]), 0.0), rp[1])
	var n_14 := K.node(root, Vector3(0.35, 0.08, -0.35), Vector3(0, 22, -26), "CollapsedHVPylon")
	K.bb(n_14, Vector3(1.58, 0.48, 1.58), A.paint(Color("#3d3c39"), 0.08, 0.86, {"wear": 0.36, "panel_scale": 0.0}), Vector3(0, 0.12, 0), Vector3(0, 0, 26), 0.016)
	K.bb(n_14, Vector3(0.075, 4.911, 0.075), K.gunmetal(), Vector3(-0.454, 2.55, -0.454), Vector3(0, 135, 6.519), 0.004)
	K.bb(n_14, Vector3(0.075, 4.911, 0.075), K.gunmetal(), Vector3(-0.454, 2.55, 0.454), Vector3(0, -135, 6.519), 0.004)
	K.bb(n_14, Vector3(0.075, 4.911, 0.075), K.gunmetal(), Vector3(0.454, 2.55, -0.454), Vector3(0, 45, 6.519), 0.004)
	K.bb(n_14, Vector3(0.075, 4.911, 0.075), K.gunmetal(), Vector3(0.454, 2.55, 0.454), Vector3(0, -45, 6.519), 0.004)
	K.bb(n_14, Vector3(0.048, 1.126, 0.048), K.dark(), Vector3(0, 1.45, -0.543), Vector3(0, 180, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 1.126, 0.048), K.dark(), Vector3(0, 1.45, 0.543), Vector3(0, 180, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 1.126, 0.048), K.dark(), Vector3(-0.543, 1.45, 0), Vector3(0, 90, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 1.126, 0.048), K.dark(), Vector3(0.543, 1.45, 0), Vector3(0, 90, 90), 0.004)
	K.bb(n_14, Vector3(0.042, 1.728, 0.042), K.gunmetal(), Vector3(-0.048, 0.85, -0.591), Vector3(0, 175.313, 44.678), 0.004)
	K.bb(n_14, Vector3(0.042, 1.728, 0.042), K.gunmetal(), Vector3(0.048, 0.85, 0.591), Vector3(0, -4.687, 44.678), 0.004)
	K.bb(n_14, Vector3(0.042, 1.728, 0.042), K.gunmetal(), Vector3(-0.591, 0.85, 0.048), Vector3(0, -94.687, 44.678), 0.004)
	K.bb(n_14, Vector3(0.042, 1.728, 0.042), K.gunmetal(), Vector3(0.591, 0.85, -0.048), Vector3(0, 85.313, 44.678), 0.004)
	K.bb(n_14, Vector3(0.048, 0.932, 0.048), K.dark(), Vector3(0, 2.65, -0.446), Vector3(0, 180, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.932, 0.048), K.dark(), Vector3(0, 2.65, 0.446), Vector3(0, 180, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.932, 0.048), K.dark(), Vector3(-0.446, 2.65, 0), Vector3(0, 90, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.932, 0.048), K.dark(), Vector3(0.446, 2.65, 0), Vector3(0, 90, 90), 0.004)
	K.bb(n_14, Vector3(0.042, 1.598, 0.042), K.gunmetal(), Vector3(-0.048, 2.05, -0.494), Vector3(0, 174.398, 39.62), 0.004)
	K.bb(n_14, Vector3(0.042, 1.598, 0.042), K.gunmetal(), Vector3(0.048, 2.05, 0.494), Vector3(0, -5.602, 39.62), 0.004)
	K.bb(n_14, Vector3(0.042, 1.598, 0.042), K.gunmetal(), Vector3(-0.494, 2.05, 0.048), Vector3(0, -95.602, 39.62), 0.004)
	K.bb(n_14, Vector3(0.042, 1.598, 0.042), K.gunmetal(), Vector3(0.494, 2.05, -0.048), Vector3(0, 84.398, 39.62), 0.004)
	K.bb(n_14, Vector3(0.048, 0.738, 0.048), K.dark(), Vector3(0, 3.85, -0.349), Vector3(0, 180, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.738, 0.048), K.dark(), Vector3(0, 3.85, 0.349), Vector3(0, 180, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.738, 0.048), K.dark(), Vector3(-0.349, 3.85, 0), Vector3(0, 90, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.738, 0.048), K.dark(), Vector3(0.349, 3.85, 0), Vector3(0, 90, 90), 0.004)
	K.bb(n_14, Vector3(0.042, 1.483, 0.042), K.gunmetal(), Vector3(-0.048, 3.25, -0.397), Vector3(0, 173.044, 33.711), 0.004)
	K.bb(n_14, Vector3(0.042, 1.483, 0.042), K.gunmetal(), Vector3(0.048, 3.25, 0.397), Vector3(0, -6.956, 33.711), 0.004)
	K.bb(n_14, Vector3(0.042, 1.483, 0.042), K.gunmetal(), Vector3(-0.397, 3.25, 0.048), Vector3(0, -96.956, 33.711), 0.004)
	K.bb(n_14, Vector3(0.042, 1.483, 0.042), K.gunmetal(), Vector3(0.397, 3.25, -0.048), Vector3(0, 83.044, 33.711), 0.004)
	K.bb(n_14, Vector3(0.048, 0.573, 0.048), K.dark(), Vector3(0, 4.87, -0.266), Vector3(0, 180, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.573, 0.048), K.dark(), Vector3(0, 4.87, 0.266), Vector3(0, 180, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.573, 0.048), K.dark(), Vector3(-0.266, 4.87, 0), Vector3(0, 90, 90), 0.004)
	K.bb(n_14, Vector3(0.048, 0.573, 0.048), K.dark(), Vector3(0.266, 4.87, 0), Vector3(0, 90, 90), 0.004)
	K.bb(n_14, Vector3(0.042, 1.234, 0.042), K.gunmetal(), Vector3(-0.041, 4.36, -0.308), Vector3(0, 172.371, 31.328), 0.004)
	K.bb(n_14, Vector3(0.042, 1.234, 0.042), K.gunmetal(), Vector3(0.041, 4.36, 0.308), Vector3(0, -7.629, 31.328), 0.004)
	K.bb(n_14, Vector3(0.042, 1.234, 0.042), K.gunmetal(), Vector3(-0.308, 4.36, 0.041), Vector3(0, -97.629, 31.328), 0.004)
	K.bb(n_14, Vector3(0.042, 1.234, 0.042), K.gunmetal(), Vector3(0.308, 4.36, -0.041), Vector3(0, 82.371, 31.328), 0.004)
	K.bb(n_14, Vector3(2.54, 0.09, 0.86), K.gunmetal(), Vector3(0, 3.55, 0), Vector3.ZERO, 0.006)
	K.bb(n_14, Vector3(0.04, 0.949, 0.04), K.dark(), Vector3(-0.748, 3.72, -0.263), Vector3(0, 11.637, 112.49), 0.004)
	var n_15 := K.node(n_14, Vector3(-1.15, 3.51, 0), Vector3(0, 0, 26), "CeramicInsulatorString")
	K.cy(n_15, 0.028, 0.52, K.dark(), Vector3(0, -0.24, 0), Vector3.ZERO, 0.028, 8)
	K.cy(n_15, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.1, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_15, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.2, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_15, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.3, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_15, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.4, 0), Vector3.ZERO, 0.1, 10)
	K.bb(n_14, Vector3(0.04, 0.949, 0.04), K.dark(), Vector3(0.748, 3.72, -0.263), Vector3(0, 168.363, 112.49), 0.004)
	var n_16 := K.node(n_14, Vector3(1.15, 3.51, 0), Vector3(0, 0, 26), "CeramicInsulatorString")
	K.cy(n_16, 0.028, 0.52, K.dark(), Vector3(0, -0.24, 0), Vector3.ZERO, 0.028, 8)
	K.cy(n_16, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.1, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_16, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.2, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_16, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.3, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_16, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.4, 0), Vector3.ZERO, 0.1, 10)
	K.bb(n_14, Vector3(2.05, 0.09, 0.68), K.gunmetal(), Vector3(0, 4.65, 0), Vector3.ZERO, 0.006)
	K.bb(n_14, Vector3(0.04, 0.796, 0.04), K.dark(), Vector3(-0.581, 4.82, -0.218), Vector3(0, 6.754, 117.513), 0.004)
	var n_17 := K.node(n_14, Vector3(-0.905, 4.61, 0), Vector3(0, 0, 26), "CeramicInsulatorString")
	K.cy(n_17, 0.028, 0.52, K.dark(), Vector3(0, -0.24, 0), Vector3.ZERO, 0.028, 8)
	K.cy(n_17, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.1, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_17, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.2, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_17, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.3, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_17, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.4, 0), Vector3.ZERO, 0.1, 10)
	K.bb(n_14, Vector3(0.04, 0.796, 0.04), K.dark(), Vector3(0.581, 4.82, -0.218), Vector3(0, 173.246, 117.513), 0.004)
	var n_18 := K.node(n_14, Vector3(0.905, 4.61, 0), Vector3(0, 0, 26), "CeramicInsulatorString")
	K.cy(n_18, 0.028, 0.52, K.dark(), Vector3(0, -0.24, 0), Vector3.ZERO, 0.028, 8)
	K.cy(n_18, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.1, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_18, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.2, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_18, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.3, 0), Vector3.ZERO, 0.1, 10)
	K.cy(n_18, 0.068, 0.042, A.paint(Color("#626466"), 0.06, 0.8, {"wear": 0.4, "panel_scale": 0.0}), Vector3(0, -0.4, 0), Vector3.ZERO, 0.1, 10)
	return root
