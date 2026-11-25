extends RefCounted
## 城市群世界布局（v0.8）：所有地表战区是同一张连续大地图上的 360 米见方「窗口」。
##
## 世界坐标：灰港市中心 = (0, 0)，+x 向东、+z 向南，单位米。战区按 scripts/world_link.gd 的 LINKS 邻接排成格子
## （灰港居中，赤湖在北、铁锈工业带在东、尘土平原在南、裂谷矿区在东南），相邻战区共用边界、没有间隔带；
## 不在 LINKS 里的战区（零号深渊井等竖井）放在远离地表的「地下」格子，四周是黑曜岩。
##
## 这里只做确定性的「规划」，不建任何节点：同一个世界坐标在任何战区、任何一局算出来都一样，所以跨战区边界的道路、
## 河流、街区、建筑轮廓天然无缝；scripts/raid.gd 取当前战区窗口（zone_layout）实例化，tools/gen_worldmap.py 取全部格子
## （tests/worldmap_export.gd 导出）画大地图，两者 1:1 对应。
##
## 组成：
##   区块（district）  每个战区 9×9 的区块字符表（scripts/maps.gd zones）铺在全局 40 米格点上，格点种子随机抖动后取最近种子
##                    （Voronoi），查询点先做域扭曲 —— 区块边界成为不规则的折线 / 曲线；战区以外由 terrain() 给出城市群的
##                    外围地形：东湾海岸与沙滩、河口湿地（L）、东北港区卫星城、西部丘陵农田与山地、北部林带与水库、南部荒漠、
##                    东南玄武岩台地。
##   全局要素          河流（灰港河、赤湖出水、干河）、湖与水库、铁路干线与支线、主干道 / 外环高速 / 跨区公路（Catmull-Rom 平滑的
##                    有机曲线），都用世界坐标写在下面的常量表里，跨越战区边界连续。
##   街区（neighborhood）96 米抖动格点的 Voronoi 单元。城区单元各有自己的街道朝向与路网间距（旋转、略带弯曲的格网），
##                    灰港旧城是放射环路；单元边界是支路（略做扭曲），农田之间偶有土路。街道只铺在城区区块上，遇水、悬崖、
##                    遗迹院落自动截断；主干道与选中的支路过河架桥。
##   地块与建筑        格网单元裁成凸多边形街块，沿街块每条边切出临街地块，建筑朝向它所临的街道；各区块的地块尺寸、进深、
##                    退界不同（旧城密实、居民区带院子、工业区大厂房）。建筑轮廓 / 高度档是确定的（大地图与游戏一致），
##                    每局只随机外观细节（坍塌、窗、屋顶设备）与杂物。
##
## 坐标约定：建筑 ang = 本地 +x 轴在 XZ 平面的方向角（u = (cos ang, sin ang)），本地 +z = (-sin ang, cos ang) 指向临街面；
## Godot 节点 rotation.y = -ang。

const WorldLink = preload("res://scripts/world_link.gd")
const WorldGates = preload("res://scripts/world_gates.gd")

const TILE := 360.0
const HALF := 180.0
const ZONE_HALF := 230.0         ## 不规则战区多边形的本地包围半宽（米）
const BACKDROP_HALF := 290.0     ## 地表战区外围连续城市群远景的采样半宽（米）
const CELL := 40.0
const NB := 120.0                ## 街区格点间距
const RAST := 2.0                ## 区块栅格分辨率（米）
const RAST_PAD := 76.0           ## 栅格在战区外多算的一圈（道路裁切用）
const CLIP_PAD := 72.0           ## 战区窗口里的道路收口时向外多看一圈街区，跨边界处两端判据一致
const URBAN := "DRIHYM"          ## 城区区块（铺街道、盖临街建筑）
const NO_COLLECTOR := "KSTLAB"   ## 支路不进入的区块
## 世界大地图范围（tools/gen_worldmap.py 按这个范围出图）
const WORLD_RECT := Rect2(-560, -900, 1480, 1760)
## 竖井 / 地下战区放在 z ≥ UNDER_Z 的格子里
const UNDER_Z := 30

## 灰港旧城历史环道中心（世界坐标）：采用非对称折线林荫环道与 8 向主街，消除圆规同心圆感
const RADIAL := [{"c": [-30, -30], "r": 114.0, "rings": [38.0, 78.0], "spokes": 8}]

# ---------------------------------------------------------------- 全局要素（世界坐标）
## 河流：w 河宽，dry 干河床；pts 控制点（平滑后加密）
const RIVERS := [
	{"name": "灰港河上游", "w": 12.0, "dry": false, "pts": [[-360, -748], [-330, -690], [-270, -640], [-220, -585], [-170, -530], [-120, -500], [-70, -478], [-22, -448], [10, -422]]},
	{"name": "灰港河", "w": 18.0, "dry": false, "pts": [[56, -384], [68, -364], [70, -334], [64, -300], [58, -262], [60, -222], [62, -180], [56, -120], [70, -58],
		[72, -6], [100, 22], [140, 34], [180, 32], [240, 16], [320, 30], [400, 26], [470, 40], [540, 34], [595, 40], [665, 52], [750, 62], [835, 70]]},
	{"name": "干河", "w": 16.0, "dry": true, "pts": [[-640, 60], [-500, 105], [-370, 160], [-270, 192], [-200, 212], [-140, 262], [-110, 322], [-90, 390],
		[-40, 450], [40, 480], [120, 494], [180, 488], [240, 466], [300, 440], [360, 402], [420, 390], [480, 420], [560, 446], [635, 468], [725, 492], [830, 518]]},
	{"name": "北溪", "w": 8.0, "dry": false, "pts": [[-600, -900], [-540, -870], [-490, -836], [-455, -812]]},
]
## 湖 / 水库 / 池：[x, z, 基准半径]（每个湖泊经 lake_radius 多谐波有机岸线调制，彻底消除正圆与椭圆几何边）
const LAKES := [
	[14, -418, 25], [34, -425, 22], [55, -429, 17], [69, -435, 12.5], [47, -404, 21], [54, -388, 19.5], [36, -382, 17.5], [16, -396, 19.5], [-3, -411, 16], # 赤湖（西北主盆 + 东北狭湾 + 东南浅滩）
	[-152, -1, 12.5], [-144, -5, 11.0], [-137, -8, 8.8],                                                                                                   # 灰港镜湖
	[490, 131, 15.5], [498, 138, 14.5], [506, 146, 12.5],                                                                                                  # 铁锈工业带废渣池
	[-158, 404, 10.5], [-151, 409, 8.0],                                                                                                                   # 尘土平原池塘
	[430, 210, 11.0], [437, 214, 8.5],                                                                                                                     # 裂谷北矿坑积水
	[-430, -800, 60], [-370, -790, 50], [-480, -760, 40], [-400, -845, 45], [-330, -762, 30],                                                              # 北郊水库
]
## 道路：kind = hwy 外环高速 / art 主干道（都过河架桥）
const ROADS := [
	{"name": "南北大道", "kind": "art", "w": 13.0, "pts": [[-80, -900], [-78, -760], [-88, -640], [-96, -560], [-92, -480], [-84, -400], [-72, -320], [-62, -250],
		[-58, -180], [-48, -110], [-30, -30], [-24, 40], [-20, 110], [-20, 180], [-22, 250], [-24, 330], [-16, 420], [0, 500], [24, 580], [50, 700], [70, 880]]},
	{"name": "东西大道", "kind": "art", "w": 13.0, "pts": [[-640, -70], [-480, -58], [-340, -44], [-240, -36], [-180, -34], [-110, -34], [-30, -30], [30, -38],
		[74, -46], [120, -44], [180, -40], [260, -48], [360, -58], [450, -50], [518, -46], [552, -64], [560, -96], [554, -136]]},
	{"name": "外环高速", "kind": "hwy", "w": 16.0, "pts": [[554, -136], [538, -216], [540, -380], [470, -560], [320, -640], [120, -652], [-100, -648], [-262, -622],
		[-300, -480], [-282, -300], [-264, -120], [-262, 60], [-272, 240], [-282, 420], [-252, 600], [-100, 642], [120, 634], [280, 640], [403, 640]]},
	{"name": "西南斜街", "kind": "art", "w": 11.0, "pts": [[-273.3, 262.5], [-200, 194], [-150, 142], [-108, 98], [-74, 58], [-48, 36], [-25, 28]]},
	{"name": "工矿公路", "kind": "art", "w": 11.0, "pts": [[388, -512], [404, -432], [412, -372], [408, -288], [404, -202], [390, -126], [380, -52], [384, 0], [388, 48], [380, 120], [372, 180], [380, 240], [382, 310], [384, 382], [388, 442], [388, 498], [384, 556], [403, 640], [420, 760]]},
	{"name": "港湾西路", "kind": "art", "w": 9.5, "pts": [[84, -366], [118, -322], [172, -297], [248, -292], [332, -304], [408, -288], [486, -296], [535, -296]]},
	{"name": "赤湖环湖路", "kind": "art", "w": 10.0, "closed": true, "pts": [[98, -392], [84, -366], [58, -354], [28, -352], [-4, -364], [-26, -382],
		[-36, -408], [-28, -436], [-4, -452], [28, -458], [64, -465], [96, -452], [108, -422]]},
	{"name": "赤湖西南路", "kind": "art", "w": 9.0, "pts": [[-4, -364], [-38, -330], [-78, -280], [-110, -230], [-130, -172], [-140, -120], [-152, -70], [-160, -34]]},
	{"name": "湖东路", "kind": "art", "w": 9.0, "pts": [[98, -392], [148, -396], [202, -394], [262, -380], [360, -370], [480, -378], [540, -380]]},
]
## 滨河路：沿灰港河右岸（灰港段西岸、运河段南岸）偏移生成，从赤湖出水口到河口
const RIVERSIDE := {"name": "滨河路", "river": 1, "off": 22.0, "w": 10.0, "from_z": -360.0, "to_x": 600.0}
## 铁路：每条是一串控制点
const RAILS := [
	[[-640, -300], [-470, -245], [-320, -196], [-200, -158], [-90, -128], [20, -112], [120, -104], [200, -100], [300, -100], [420, -100], [540, -100], [580, -108]],
	[[392, -100], [412, -78], [416, -34], [424, 16], [428, 72], [430, 140], [420, 200], [406, 248], [402, 294]],
	[[256, -100], [286, -114], [360, -114], [434, -114], [464, -100]],
	[[240, -100], [282, -132], [360, -132], [438, -132], [480, -100]],
	[[224, -100], [278, -150], [360, -150], [442, -150], [496, -100]],
	[[136, -103], [164, -88], [230, -88], [296, -88], [324, -100]],
	[[300, -100], [326, -138], [330, -210], [338, -282], [362, -334], [434, -334]],
]
## 山脊巨石线
const RIDGES := [
	[[110, 190], [130, 250], [120, 300], [140, 350], [130, 410]],
	[[-170, 500], [-130, 510], [-110, 535]],
]

# ---------------------------------------------------------------- 噪声 / 哈希
static var _nw: FastNoiseLite      ## 区块边界大尺度域扭曲
static var _nw2: FastNoiseLite     ## 区块边界中尺度域扭曲（打碎直线 Voronoi 边）
static var _nw3: FastNoiseLite     ## 区块边界细尺度域扭曲
static var _nt: FastNoiseLite      ## 外围地形大尺度
static var _nt2: FastNoiseLite     ## 外围地形小尺度
static var _na: FastNoiseLite      ## 街区朝向场
static var _nr: FastNoiseLite      ## 支路扭曲


static func _init_noise() -> void:
	if _nw != null:
		return
	_nw = FastNoiseLite.new()
	_nw.seed = 7177
	_nw.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nw.frequency = 1.0 / 70.0
	_nw.fractal_octaves = 2
	_nw2 = FastNoiseLite.new()
	_nw2.seed = 7193
	_nw2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nw2.frequency = 1.0 / 21.0
	_nw2.fractal_octaves = 2
	_nw3 = FastNoiseLite.new()
	_nw3.seed = 7219
	_nw3.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nw3.frequency = 1.0 / 8.5
	_nt = FastNoiseLite.new()
	_nt.seed = 911
	_nt.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nt.frequency = 1.0 / 190.0
	_nt2 = FastNoiseLite.new()
	_nt2.seed = 1213
	_nt2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nt2.frequency = 1.0 / 70.0
	_na = FastNoiseLite.new()
	_na.seed = 333
	_na.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_na.frequency = 1.0 / 520.0
	_nr = FastNoiseLite.new()
	_nr.seed = 4242
	_nr.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_nr.frequency = 1.0 / 45.0


## 整数格点哈希 → [0, 1)
static func h2(x: int, y: int, s: int) -> float:
	var v: int = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xFFFFFFFF
	v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
	v = v ^ (v >> 16)
	return float(v & 0xFFFFFF) / 16777216.0


static func _warp(p: Vector2) -> Vector2:
	var dx := _nw.get_noise_2d(p.x, p.y) * 17.5 + _nw2.get_noise_2d(p.x, p.y) * 7.8 + _nw3.get_noise_2d(p.x, p.y) * 3.2
	var dz := _nw.get_noise_2d(p.x + 517.0, p.y - 291.0) * 17.5 + _nw2.get_noise_2d(p.x + 313.0, p.y - 173.0) * 7.8 + _nw3.get_noise_2d(p.x - 197.0, p.y + 409.0) * 3.2
	return Vector2(dx, dz)


# ---------------------------------------------------------------- 战区格子
static var _tiles := {}       ## 战区 id → Vector2i
static var _tile_ids := {}    ## Vector2i → 战区 id


static func _layout_tiles() -> void:
	if not _tiles.is_empty():
		return
	_tiles["greyport"] = Vector2i.ZERO
	var queue: Array = ["greyport"]
	var dv := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}
	while not queue.is_empty():
		var a: String = queue.pop_front()
		for e: String in WorldLink.LINKS.get(a, {}):
			var b: String = WorldLink.LINKS[a][e]
			if not _tiles.has(b):
				_tiles[b] = _tiles[a] + dv[e]
				queue.append(b)
	var ids: Array = GameData.map_ids()
	ids.sort()
	var k := 0
	for id: String in ids:
		if not _tiles.has(id):
			_tiles[id] = Vector2i(k * 3, UNDER_Z)
			k += 1
	for id: String in _tiles:
		_tile_ids[_tiles[id]] = id


static func tile_of(id: String) -> Vector2i:
	_layout_tiles()
	return _tiles.get(id, Vector2i(0, UNDER_Z))


## 战区中心的世界坐标
static func origin(id: String) -> Vector2:
	var t := tile_of(id)
	return Vector2(t.x * TILE, t.y * TILE)


static func zone_of_tile(t: Vector2i) -> String:
	_layout_tiles()
	return _tile_ids.get(t, "")


static func is_surface(id: String) -> bool:
	return tile_of(id).y < UNDER_Z - 5


## 世界坐标落在哪个格子
static func tile_at(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x + HALF) / TILE), floori((p.y + HALF) / TILE))


# ---------------------------------------------------------------- 不规则战区截取轮廓（世界坐标 / 本地坐标）
## 相邻战区共用的不规则分界折线（世界坐标，首尾相接构成平面分区图，零重叠、零十字网格缝）
const B_RL_GP := [
	[-132.0, -168.0], [-88.0, -176.0], [-30.0, -192.0], [-10.0, -214.0],
	[28.0, -208.0], [60.0, -172.0], [118.0, -162.0], [148.0, -196.0],
]
const B_BP_RL := [
	[204.0, -468.0], [212.0, -394.0], [166.0, -352.0], [178.0, -242.0], [148.0, -196.0],
]
const B_BP_GP := [[148.0, -196.0], [194.0, -154.0]]
const B_BP_IB := [
	[194.0, -154.0], [218.0, -172.0], [336.0, -174.0], [364.0, -206.0],
	[448.0, -198.0], [532.0, -152.0],
]
const B_GP_IB := [
	[194.0, -154.0], [168.0, -104.0], [168.0, -72.0], [184.0, -14.0],
	[208.0, -2.0], [198.0, 34.0], [148.0, 64.0], [152.0, 128.0], [184.0, 168.0],
]
const B_GP_CY := [[184.0, 168.0], [158.0, 152.0]]
const B_DF_GP := [
	[158.0, 152.0], [102.0, 198.0], [46.0, 194.0], [18.0, 184.0],
	[-54.0, 158.0], [-92.0, 142.0], [-148.0, 138.0],
]
const B_DF_CY := [
	[158.0, 152.0], [206.0, 208.0], [204.0, 262.0], [194.0, 286.0],
	[152.0, 352.0], [144.0, 392.0], [148.0, 434.0], [182.0, 488.0], [208.0, 532.0],
]
const B_IB_CY := [
	[184.0, 168.0], [248.0, 152.0], [306.0, 176.0], [338.0, 172.0],
	[406.0, 190.0], [438.0, 198.0], [486.0, 192.0], [542.0, 208.0],
]
const ABYSS_LOCAL_PTS := [
	[-26.0, -196.0], [28.0, -196.0], [52.0, -156.0], [104.0, -168.0], [144.0, -128.0],
	[118.0, -68.0], [194.0, -34.0], [194.0, 18.0], [148.0, 38.0], [162.0, 92.0],
	[108.0, 134.0], [44.0, 122.0], [32.0, 194.0], [-22.0, 194.0], [-52.0, 152.0],
	[-96.0, 136.0], [-124.0, 72.0], [-194.0, 36.0], [-194.0, -16.0], [-138.0, -36.0],
	[-158.0, -94.0], [-108.0, -144.0], [-48.0, -142.0],
]

static var _zpoly_world_cache := {}
static var _zpoly_local_cache := {}


static func _pts_arr(raw: Array, rev := false) -> Array:
	var out: Array = raw.duplicate()
	if rev:
		out.reverse()
	return out


static func _chain_poly(parts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for part: Array in parts:
		for q in part:
			var pt := Vector2(float(q[0]), float(q[1]))
			if out.is_empty() or out[out.size() - 1].distance_to(pt) > 0.01:
				out.append(pt)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= 0.01:
		out.remove_at(out.size() - 1)
	return out


## 战区的不规则多边形（世界坐标）
static func zone_poly_world(id: String) -> PackedVector2Array:
	if _zpoly_world_cache.has(id):
		return _zpoly_world_cache[id]
	var poly := PackedVector2Array()
	match id:
		"redlake":
			poly = _chain_poly([[
				[-132.0, -168.0], [-142.0, -252.0], [-196.0, -328.0], [-198.0, -416.0],
				[-146.0, -482.0], [-88.0, -518.0], [18.0, -512.0], [116.0, -528.0], [204.0, -468.0],
			], B_BP_RL, _pts_arr(B_RL_GP, true)])
		"bayport":
			poly = _chain_poly([[
				[204.0, -468.0], [266.0, -546.0], [338.0, -518.0], [418.0, -548.0],
				[482.0, -486.0], [538.0, -426.0], [558.0, -348.0], [512.0, -276.0],
				[552.0, -206.0], [532.0, -152.0],
			], _pts_arr(B_BP_IB, true), _pts_arr(B_BP_GP, true), _pts_arr(B_BP_RL, true)])
		"greyport":
			poly = _chain_poly([
				B_RL_GP, B_BP_GP, B_GP_IB, B_GP_CY, B_DF_GP,
				[[-148.0, 138.0], [-118.0, 92.0], [-168.0, 52.0], [-208.0, 4.0],
				[-204.0, -48.0], [-168.0, -72.0], [-174.0, -138.0], [-132.0, -168.0]],
			])
		"ironbelt":
			poly = _chain_poly([
				B_BP_IB,
				[[532.0, -152.0], [562.0, -96.0], [572.0, -28.0],
				[532.0, 28.0], [558.0, 108.0], [552.0, 172.0], [542.0, 208.0]],
				_pts_arr(B_IB_CY, true), _pts_arr(B_GP_IB, true),
			])
		"dustfield":
			poly = _chain_poly([
				_pts_arr(B_DF_GP, true), B_DF_CY,
				[[208.0, 532.0], [148.0, 562.0], [52.0, 558.0], [-18.0, 524.0],
				[-92.0, 508.0], [-156.0, 464.0], [-196.0, 408.0], [-208.0, 342.0],
				[-188.0, 272.0], [-158.0, 208.0], [-148.0, 138.0]],
			])
		"canyon":
			poly = _chain_poly([
				B_IB_CY,
				[[542.0, 208.0], [522.0, 276.0], [564.0, 326.0], [558.0, 378.0],
				[488.0, 434.0], [456.0, 518.0], [392.0, 566.0], [324.0, 552.0], [208.0, 532.0]],
				_pts_arr(B_DF_CY, true), _pts_arr(B_GP_CY, true),
			])
		_:
			var org := origin(id)
			poly = _shift(_chain_poly([ABYSS_LOCAL_PTS]), org)
	_zpoly_world_cache[id] = poly
	return poly


## 战区的不规则多边形（战区本地坐标，中心 = (0, 0)）
static func zone_poly(id: String) -> PackedVector2Array:
	if _zpoly_local_cache.has(id):
		return _zpoly_local_cache[id]
	var poly := _shift(zone_poly_world(id), -origin(id))
	_zpoly_local_cache[id] = poly
	return poly


## 两个相邻战区之间的规范共享分界折线（世界坐标，对 (a, b) 与 (b, a) 返回同一方向折线，保证弧长参数 100% 一致）
static func canonical_border_world(a: String, b: String) -> PackedVector2Array:
	var lo := a if a < b else b
	var hi := b if a < b else a
	var key := "%s|%s" % [lo, hi]
	match key:
		"greyport|redlake": return _chain_poly([B_RL_GP])
		"bayport|redlake": return _chain_poly([B_BP_RL])
		"bayport|greyport": return _chain_poly([B_BP_GP])
		"bayport|ironbelt": return _chain_poly([B_BP_IB])
		"greyport|ironbelt": return _chain_poly([B_GP_IB])
		"dustfield|greyport": return _chain_poly([B_DF_GP])
		"canyon|dustfield": return _chain_poly([B_DF_CY])
		"canyon|ironbelt": return _chain_poly([B_IB_CY])
		"canyon|greyport": return _chain_poly([B_GP_CY])
	return PackedVector2Array()


## 点到任意简单多边形（含凹多边形）的有符号边界距离：内部为正，外部为负
static func poly_signed_dist(poly: PackedVector2Array, p: Vector2) -> float:
	var m := poly.size()
	if m < 3:
		return -INF
	var best := INF
	for i in m:
		var d := seg_dist(p, poly[i], poly[(i + 1) % m])
		if d < best:
			best = d
	return best if Geometry2D.is_point_in_polygon(p, poly) else -best


static func in_zone_poly(id: String, local_p: Vector2, margin := 0.0) -> bool:
	return poly_signed_dist(zone_poly(id), local_p) >= margin


static func in_zone_world(id: String, world_p: Vector2, margin := 0.0) -> bool:
	return poly_signed_dist(zone_poly_world(id), world_p) >= margin


# ---------------------------------------------------------------- 区块
## 全局 40 米格点 (ci, cj) 的区块字符：落在战区格子里取该战区 zones 表，否则取外围地形
static func cell_char(ci: int, cj: int) -> String:
	var tx := floori(ci / 9.0)
	var tz := floori(cj / 9.0)
	var id := zone_of_tile(Vector2i(tx, tz))
	if id != "":
		var zs: Array = GameData.map_data(id).zones
		return str(zs[cj - tz * 9])[ci - tx * 9]
	return terrain(Vector2(-HALF + CELL * (ci + 0.5), -HALF + CELL * (cj + 0.5)))


static func _cell_seed(ci: int, cj: int) -> Vector2:
	return Vector2(-HALF + CELL * (ci + 0.5) + (h2(ci, cj, 11) - 0.5) * 26.0, -HALF + CELL * (cj + 0.5) + (h2(ci, cj, 12) - 0.5) * 26.0)


## 东湾海岸线：给定 z 的海岸 x
static func coast_x(z: float) -> float:
	var x := 640.0 + 45.0 * sin(z / 230.0) + 22.0 * sin(z / 83.0 + 1.3)
	x -= 70.0 * exp(-pow((z - 40.0) / 90.0, 2.0))
	x += 60.0 * clampf((-z - 500.0) / 300.0, 0.0, 1.0)
	return x


## 城市群外围地形（战区格子以外连续求值，不量化为 40 米多边形）。A 海 / B 沙滩只出现在海岸，离战区很远。
static func terrain(p: Vector2) -> String:
	_init_noise()
	if p.y > (UNDER_Z - 5) * TILE:
		return "K"
	var n := _nt.get_noise_2d(p.x, p.y)
	var n2 := _nt2.get_noise_2d(p.x, p.y)
	var cx := coast_x(p.y) + n2 * 14.0
	if p.x > cx + 4.0:
		return "A"
	if p.x > cx - 20.0:
		return "B"
	# 东北港区卫星城 + 河口湿地
	if p.x > 170.0 and p.y < 190.0:
		if p.x > cx - 110.0 + n * 40.0 and absf(p.y - 40.0) < 150.0 + n * 50.0:
			return "L"
		if p.y < -600.0 + n * 40.0:
			return "T" if n2 > -0.2 else "L"
		if p.x > cx - 70.0:
			return "H" if n2 > -0.1 else "I"
		if n2 > 0.45:
			return "P"
		if p.y > -330.0 and p.x > 420.0:
			return "I"
		return "R"
	# 东南玄武岩台地
	if p.x > 540.0 and p.y >= 190.0:
		return "K" if n2 > -0.3 else "W"
	# 南部荒漠
	if p.y > 540.0:
		if p.x > 190.0:
			return "K" if n2 > 0.15 else "W"
		if p.y < 650.0 + n * 50.0 and n > -0.1:
			return "F"
		return "C" if n2 > 0.55 else "W"
	# 北部林带与山地
	if p.y < -540.0:
		if p.y < -830.0 + n * 60.0:
			return "K"
		return "W" if n2 > 0.5 else "T"
	# 西部：近郊农田 → 丘陵林地 → 山地
	var d := -HALF - p.x
	if d < 100.0 + n * 40.0:
		if n2 > 0.5:
			return "R"
		return "F" if n2 > -0.35 else "W"
	if d < 270.0 + n * 60.0:
		return "T" if n2 > -0.15 else "K"
	return "K"


## 世界坐标处的区块字符（精确计算，较慢；战区内请用栅格 dist_at）
static func district(p: Vector2) -> String:
	_init_noise()
	var q := p + _warp(p)
	var ci := floori((q.x + HALF) / CELL)
	var cj := floori((q.y + HALF) / CELL)
	var best := INF
	var bi := ci
	var bj := cj
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var s := _cell_seed(ci + di, cj + dj)
			var d := q.distance_squared_to(s)
			if d < best:
				best = d
				bi = ci + di
				bj = cj + dj
	if zone_of_tile(Vector2i(floori(bi / 9.0), floori(bj / 9.0))) == "":
		return terrain(q)
	return cell_char(bi, bj)


## 一块栅格（世界坐标原点 o、宽 n 像素、分辨率 RAST）：返回字符码 PackedByteArray
static func _raster(o: Vector2, n: int) -> PackedByteArray:
	_init_noise()
	var out := PackedByteArray()
	out.resize(n * n)
	# 预取覆盖范围内（含扭曲余量）的格点种子与字符
	var span := n * RAST
	var c0 := Vector2i(floori((o.x - 32.0 + HALF) / CELL) - 1, floori((o.y - 32.0 + HALF) / CELL) - 1)
	var c1 := Vector2i(floori((o.x + span + 32.0 + HALF) / CELL) + 1, floori((o.y + span + 32.0 + HALF) / CELL) + 1)
	var cw := c1.x - c0.x + 1
	var ch_ := c1.y - c0.y + 1
	var sx := PackedFloat32Array()
	var sy := PackedFloat32Array()
	var sc := PackedByteArray()
	var szone := PackedByteArray()
	sx.resize(cw * ch_)
	sy.resize(cw * ch_)
	sc.resize(cw * ch_)
	szone.resize(cw * ch_)
	for j in ch_:
		for i in cw:
			var gi := c0.x + i
			var gj := c0.y + j
			var s := _cell_seed(gi, gj)
			var idx := j * cw + i
			sx[idx] = s.x
			sy[idx] = s.y
			sc[idx] = cell_char(gi, gj).unicode_at(0)
			szone[idx] = 1 if zone_of_tile(Vector2i(floori(gi / 9.0), floori(gj / 9.0))) != "" else 0
	for y in n:
		var pz := o.y + (y + 0.5) * RAST
		for x in n:
			var px := o.x + (x + 0.5) * RAST
			var w := _warp(Vector2(px, pz))
			var qx := px + w.x
			var qz := pz + w.y
			var ci := clampi(floori((qx + HALF) / CELL) - c0.x, 1, cw - 2)
			var cj := clampi(floori((qz + HALF) / CELL) - c0.y, 1, ch_ - 2)
			var best := INF
			var bk := 0
			for dj in range(-1, 2):
				var row := (cj + dj) * cw
				for di in range(-1, 2):
					var k := row + ci + di
					var dx := qx - sx[k]
					var dz := qz - sy[k]
					var d := dx * dx + dz * dz
					if d < best:
						best = d
						bk = k
			if szone[bk] == 0:
				out[y * n + x] = terrain(Vector2(qx, qz)).unicode_at(0)
			else:
				out[y * n + x] = sc[bk]
	return out


# ---------------------------------------------------------------- 几何工具
## Catmull-Rom 平滑：控制点 [[x, z], ...] → 每 step 米一个点
static func smooth(ctrl: Array, step := 4.0, closed := false) -> PackedVector2Array:
	var p := PackedVector2Array()
	for c in ctrl:
		p.append(Vector2(float(c[0]), float(c[1])))
	var n := p.size()
	var out := PackedVector2Array()
	if n < 2:
		return p
	var segs := n if closed else n - 1
	for i in segs:
		var p1 := p[i]
		var p2 := p[(i + 1) % n]
		var p0 := p[(i - 1 + n) % n] if closed else p[maxi(i - 1, 0)]
		var p3 := p[(i + 2) % n] if closed else p[mini(i + 2, n - 1)]
		var m := maxi(1, int(p1.distance_to(p2) / step))
		for k in m:
			var t := float(k) / m
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(p[0] if closed else p[n - 1])
	return out


## 向心 Catmull-Rom 转三次贝塞尔采样（α = 0.5）：消除均匀参数化在不等距控制点处的曲率突变
static func smooth_bezier(ctrl: Array, step := 2.4, closed := false) -> PackedVector2Array:
	var p := PackedVector2Array()
	for c in ctrl:
		p.append(Vector2(float(c[0]), float(c[1])))
	var n := p.size()
	if n < 2:
		return p
	var out := PackedVector2Array()
	var segs := n if closed else n - 1
	for i in segs:
		var p1 := p[i]
		var p2 := p[(i + 1) % n]
		var p0 := p[(i - 1 + n) % n] if closed else (p[i - 1] if i > 0 else 2.0 * p1 - p2)
		var p3 := p[(i + 2) % n] if closed else (p[i + 2] if i + 2 < n else 2.0 * p2 - p1)
		var d01 := maxf(0.01, sqrt(p1.distance_to(p0)))
		var d12 := maxf(0.01, sqrt(p2.distance_to(p1)))
		var d23 := maxf(0.01, sqrt(p3.distance_to(p2)))
		var b1 := p1 + ((p1 - p0) / d01 - (p2 - p0) / (d01 + d12) + (p2 - p1) / d12) * (d12 / 3.0)
		var b2 := p2 - ((p2 - p1) / d12 - (p3 - p1) / (d12 + d23) + (p3 - p2) / d23) * (d12 / 3.0)
		var m := maxi(1, ceili(p1.distance_to(p2) / maxf(step, 0.25)))
		for k in m:
			var u := float(k) / float(m)
			var v := 1.0 - u
			out.append((v * v * v) * p1 + (3.0 * v * v * u) * b1 + (3.0 * v * u * u) * b2 + (u * u * u) * p2)
	out.append(p[0] if closed else p[n - 1])
	return out


static func dense(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return pts
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		for i in n:
			out.append(a.lerp(b, float(i) / n))
	out.append(pts[pts.size() - 1])
	return out


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func poly_dist(pts: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for k in pts.size() - 1:
		best = minf(best, seg_dist(p, pts[k], pts[k + 1]))
	return best


## 凸多边形被半平面 (p - a)·n ≥ 0 裁切（Sutherland–Hodgman）
static func clip_half(poly: PackedVector2Array, a: Vector2, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := poly.size()
	if m == 0:
		return out
	for i in m:
		var p := poly[i]
		var q := poly[(i + 1) % m]
		var dp := (p - a).dot(n)
		var dq := (q - a).dot(n)
		if dp >= 0.0:
			out.append(p)
		if (dp >= 0.0) != (dq >= 0.0):
			out.append(p + (q - p) * (dp / (dp - dq)))
	return out


static func clip_convex(subject: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	var out := subject
	var m := clip.size()
	var ccw := poly_area_signed(clip) > 0.0
	for i in m:
		var a := clip[i]
		var b := clip[(i + 1) % m]
		var e := b - a
		var n := Vector2(-e.y, e.x) if ccw else Vector2(e.y, -e.x)
		out = clip_half(out, a, n)
		if out.size() < 3:
			return PackedVector2Array()
	return out


static func poly_area_signed(poly: PackedVector2Array) -> float:
	var s := 0.0
	var m := poly.size()
	for i in m:
		s += poly[i].cross(poly[(i + 1) % m])
	return s * 0.5


static func poly_area(poly: PackedVector2Array) -> float:
	return absf(poly_area_signed(poly))


static func centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(1.0, poly.size())


## 凸多边形整体内缩 d 米
static func inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := poly
	var m := poly.size()
	var ccw := poly_area_signed(poly) > 0.0
	for i in m:
		var a := poly[i]
		var b := poly[(i + 1) % m]
		var e := (b - a).normalized()
		var n := Vector2(-e.y, e.x) if ccw else Vector2(e.y, -e.x)
		out = clip_half(out, a + n * d, n)
		if out.size() < 3:
			return PackedVector2Array()
	return out


static func in_convex(poly: PackedVector2Array, p: Vector2) -> bool:
	var m := poly.size()
	if m < 3:
		return false
	var sgn := 0.0
	for i in m:
		var c := (poly[(i + 1) % m] - poly[i]).cross(p - poly[i])
		if c != 0.0:
			if sgn == 0.0:
				sgn = signf(c)
			elif signf(c) != sgn:
				return false
	return true


## 旋转矩形的四角（c 中心、ang 本地 x 方向、sx × sz）
static func obb_corners(c: Vector2, ang: float, sx: float, sz: float) -> PackedVector2Array:
	var u := Vector2(cos(ang), sin(ang)) * sx * 0.5
	var v := Vector2(-sin(ang), cos(ang)) * sz * 0.5
	return PackedVector2Array([c - u - v, c + u - v, c + u + v, c - u + v])


## 两个凸多边形是否相交（分离轴）
static func convex_overlap(a: PackedVector2Array, b: PackedVector2Array, margin := 0.0) -> bool:
	for poly: PackedVector2Array in [a, b]:
		var m := poly.size()
		for i in m:
			var e := poly[(i + 1) % m] - poly[i]
			var n := Vector2(-e.y, e.x).normalized()
			var amin := INF
			var amax := -INF
			for p in a:
				var d := p.dot(n)
				amin = minf(amin, d)
				amax = maxf(amax, d)
			var bmin := INF
			var bmax := -INF
			for p in b:
				var d := p.dot(n)
				bmin = minf(bmin, d)
				bmax = maxf(bmax, d)
			if amax + margin <= bmin or bmax + margin <= amin:
				return false
	return true


# ---------------------------------------------------------------- 线段空间索引
## 折线段按格子分桶：查询点到最近路面边缘 / 水面边缘的距离
class SegGrid:
	var cell := 16.0
	var reach := 14.0                 ## 段的包围盒外扩：查询 pad 不超过它才精确
	var grid := {}
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var hw := PackedFloat32Array()    ## 半宽
	var tag := PackedInt32Array()     ## 所属折线序号

	func add_poly(pts: PackedVector2Array, half_w: float, t: int) -> void:
		for k in pts.size() - 1:
			add(pts[k], pts[k + 1], half_w, t)

	func add(p: Vector2, q: Vector2, half_w: float, t: int) -> void:
		var i := a.size()
		a.append(p)
		b.append(q)
		hw.append(half_w)
		tag.append(t)
		var r := half_w + reach
		var x0 := floori((minf(p.x, q.x) - r) / cell)
		var x1 := floori((maxf(p.x, q.x) + r) / cell)
		var z0 := floori((minf(p.y, q.y) - r) / cell)
		var z1 := floori((maxf(p.y, q.y) + r) / cell)
		for gz in range(z0, z1 + 1):
			for gx in range(x0, x1 + 1):
				var key := Vector2i(gx, gz)
				if grid.has(key):
					grid[key].append(i)
				else:
					grid[key] = PackedInt32Array([i])

	## 到最近段边缘的距离（负数 = 在段内）；附近没有段时返回 INF
	func edge_dist(p: Vector2, skip := -1) -> float:
		var lst = grid.get(Vector2i(floori(p.x / cell), floori(p.y / cell)))
		if lst == null:
			return INF
		var best := INF
		for i: int in lst:
			if tag[i] == skip:
				continue
			var ab: Vector2 = b[i] - a[i]
			var t := clampf((p - a[i]).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d := p.distance_to(a[i] + ab * t) - hw[i]
			if d < best:
				best = d
		return best

	## 离最近段中心线最近的段序号（-1 = 没有）
	func nearest(p: Vector2, pad: float) -> int:
		var lst = grid.get(Vector2i(floori(p.x / cell), floori(p.y / cell)))
		if lst == null:
			return -1
		var best := INF
		var bi := -1
		for i: int in lst:
			var ab: Vector2 = b[i] - a[i]
			var t := clampf((p - a[i]).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d := p.distance_to(a[i] + ab * t) - hw[i]
			if d < pad and d < best:
				best = d
				bi = i
		return bi


# ---------------------------------------------------------------- 全局要素（缓存）
static var _feat := {}


static func features() -> Dictionary:
	if not _feat.is_empty():
		return _feat
	_init_noise()
	var rivers: Array = []
	for r: Dictionary in RIVERS:
		rivers.append({"name": r.name, "pts": smooth(r.pts, 4.0), "w": float(r.w), "dry": bool(r.dry)})
	var lakes: Array = []
	for l: Array in LAKES:
		lakes.append(Vector3(l[0], l[1], l[2]))
	var roads: Array = []
	for r: Dictionary in ROADS:
		roads.append({"name": r.name, "pts": smooth_bezier(r.pts, 2.4, bool(r.get("closed", false))), "w": float(r.w), "dirt": str(r.kind) == "dirt",
			"kind": str(r.kind), "bridge": str(r.kind) != "dirt"})
	# 滨河路：灰港河右岸偏移
	var rv: PackedVector2Array = rivers[RIVERSIDE.river].pts
	var side := PackedVector2Array()
	for i in rv.size():
		var t := (rv[mini(i + 1, rv.size() - 1)] - rv[maxi(i - 1, 0)]).normalized()
		var q: Vector2 = rv[i] + Vector2(-t.y, t.x) * float(RIVERSIDE.off)
		if rv[i].y < float(RIVERSIDE.from_z) or rv[i].x > float(RIVERSIDE.to_x):
			continue
		side.append(q)
	var sd_ctrl: Array = []
	for i in range(0, side.size(), 3):
		sd_ctrl.append([side[i].x, side[i].y])
	if side.size() >= 2 and (side.size() - 1) % 3 != 0:
		var last_s := side[side.size() - 1]
		if Vector2(float(sd_ctrl[sd_ctrl.size() - 1][0]), float(sd_ctrl[sd_ctrl.size() - 1][1])).distance_to(last_s) > 1.5:
			sd_ctrl.append([last_s.x, last_s.y])
	var side_pts := smooth_bezier(sd_ctrl, 2.0) if sd_ctrl.size() >= 3 else dense(side, 2.0)
	roads.append({"name": RIVERSIDE.name, "pts": side_pts, "w": float(RIVERSIDE.w), "dirt": false, "kind": "art", "bridge": true})
	var rails: Array = []
	for line: Array in RAILS:
		rails.append(smooth(line, 6.0) if line.size() > 2 else dense(PackedVector2Array([Vector2(line[0][0], line[0][1]), Vector2(line[1][0], line[1][1])]), 6.0))
	var ridges: Array = []
	for line: Array in RIDGES:
		ridges.append(smooth(line, 3.2))
	# 空间索引：水面（河道 + 湖 用圆近似）与主干道 / 铁路
	var water := SegGrid.new()
	water.cell = 24.0
	water.reach = 24.0
	for i in rivers.size():
		water.add_poly(rivers[i].pts, rivers[i].w * 0.5, i)
	var art := SegGrid.new()
	art.cell = 24.0
	art.reach = 24.0
	for i in roads.size():
		art.add_poly(roads[i].pts, roads[i].w * 0.5, i)
	var rail := SegGrid.new()
	rail.cell = 24.0
	rail.reach = 20.0
	for i in rails.size():
		rail.add_poly(rails[i], 1.8, i)
	_feat = {"rivers": rivers, "lakes": lakes, "roads": roads, "rails": rails, "ridges": ridges, "water": water, "art": art, "rail": rail}
	return _feat


## 湖泊多谐波自然岸线半径（消除圆规画圆的正圆与椭圆感，所有湖塘共用确定性公式）
static func lake_radius(l: Vector3, ang: float) -> float:
	var sx := posmod(roundi(l.x), int(TILE))
	var sy := posmod(roundi(l.y), int(TILE))
	var p1 := h2(sx, sy, 301) * TAU
	var p2 := h2(sx, sy, 302) * TAU
	var p3 := h2(sx, sy, 303) * TAU
	var p4 := h2(sx, sy, 304) * TAU
	var m := 0.90 + 0.085 * sin(2.0 * ang + p1) + 0.062 * sin(3.0 * ang + p2) + 0.038 * sin(5.0 * ang + p3) + 0.018 * sin(7.0 * ang + p4)
	return l.z * clampf(m, 0.74, 1.04)


static func lake_poly(l: Vector3, segs := 56, extra := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := Vector2(l.x, l.y)
	for i in segs:
		var a := TAU * float(i) / float(segs)
		out.append(c + Vector2(cos(a), sin(a)) * maxf(1.2, lake_radius(l, a) + extra))
	return out


static func lake_dist(l: Vector3, p: Vector2) -> float:
	var d := p - Vector2(l.x, l.y)
	var len_d := d.length()
	if len_d > l.z * 1.08 + 24.0:
		return len_d - l.z
	var a := atan2(d.y, d.x) if len_d > 1e-4 else 0.0
	return len_d - lake_radius(l, a)


## 水面判定（世界坐标）：wet_only = 只算有水的河道
static func water_dist(p: Vector2, wet_only := false) -> float:
	var f := features()
	var best := INF
	var g: SegGrid = f.water
	var lst = g.grid.get(Vector2i(floori(p.x / g.cell), floori(p.y / g.cell)))
	if lst != null:
		for i: int in lst:
			if wet_only and f.rivers[g.tag[i]].dry:
				continue
			best = minf(best, seg_dist(p, g.a[i], g.b[i]) - g.hw[i])
	for l: Vector3 in f.lakes:
		best = minf(best, lake_dist(l, p))
	return best


# ---------------------------------------------------------------- 街区（Voronoi）
static var _nbc := {}


static func nb_seed(i: int, j: int) -> Vector2:
	return Vector2((i + 0.5) * NB + (h2(i, j, 21) - 0.5) * 36.0, (j + 0.5) * NB + (h2(i, j, 22) - 0.5) * 36.0)


## 相邻两个街区之间的边界路：col 城区支路 / "" 没有路（相邻同向城区街区约四分之一直接合并成连续格网；已移除田间机耕土路）
static func col_kind(a: Vector2i, b: Vector2i) -> String:
	var na := nb_info(a)
	var nb2 := nb_info(b)
	if (na.kind == "yard" and nb2.kind == "yard") or (na.kind == "yard" and nb2.kind == "rural") or (nb2.kind == "yard" and na.kind == "rural"):
		return ""
	var lo := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi := b if lo == a else a
	var r := h2(lo.x * 7 + hi.x * 3, lo.y * 13 + hi.y * 5, 31)
	var ua: bool = na.kind != "rural"
	var ub: bool = nb2.kind != "rural"
	if ua and ub:
		return "col" if r < 0.76 else ""
	if ua or ub:
		return "col"
	return ""


## 街区多边形按边内缩：有支路的边让出半个路宽 + 人行道，没有路的边只留窄缝
static func nb_inner(nb: Dictionary) -> PackedVector2Array:
	if nb.has("inner"):
		return nb.inner
	var poly: PackedVector2Array = nb.poly
	var out := poly
	var m := poly.size()
	var ccw := poly_area_signed(poly) > 0.0
	for i in m:
		var o = nb.labels[i]
		var d := 0.8
		if o != null and col_kind(nb.k, o) == "col":
			d = 5.4
		var a := poly[i]
		var e := (poly[(i + 1) % m] - a).normalized()
		var n := Vector2(-e.y, e.x) if ccw else Vector2(e.y, -e.x)
		out = clip_half(out, a + n * d, n)
		if out.size() < 3:
			break
	nb["inner"] = out if out.size() >= 3 else PackedVector2Array()
	return nb.inner


## 世界坐标所属的街区格点
static func nb_owner(p: Vector2) -> Vector2i:
	var ci := floori(p.x / NB)
	var cj := floori(p.y / NB)
	var best := INF
	var bk := Vector2i(ci, cj)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var d := p.distance_squared_to(nb_seed(ci + di, cj + dj))
			if d < best:
				best = d
				bk = Vector2i(ci + di, cj + dj)
	return bk


## 街区信息：多边形（边上记着对面街区）、类型、街道朝向与间距
static func nb_info(k: Vector2i) -> Dictionary:
	if _nbc.has(k):
		return _nbc[k]
	_init_noise()
	var s := nb_seed(k.x, k.y)
	var poly := PackedVector2Array([s + Vector2(-160, -160), s + Vector2(160, -160), s + Vector2(160, 160), s + Vector2(-160, 160)])
	var labels: Array = [null, null, null, null]
	for dj in range(-2, 3):
		for di in range(-2, 3):
			if di == 0 and dj == 0:
				continue
			var o := Vector2i(k.x + di, k.y + dj)
			var so := nb_seed(o.x, o.y)
			var mid := (s + so) * 0.5
			var n := (s - so).normalized()
			# 带标签的半平面裁切：新生成的边标记为对面街区 o
			var out := PackedVector2Array()
			var lab: Array = []
			var m := poly.size()
			for i in m:
				var p := poly[i]
				var q := poly[(i + 1) % m]
				var dp := (p - mid).dot(n)
				var dq := (q - mid).dot(n)
				if dp >= 0.0:
					out.append(p)
					lab.append(labels[i])
					if dq < 0.0:
						out.append(p + (q - p) * (dp / (dp - dq)))
						lab.append(o)
				elif dq >= 0.0:
					out.append(p + (q - p) * (dp / (dp - dq)))
					lab.append(labels[i])
			poly = out
			labels = lab
	# 街区类型按多边形里的区块构成定：城区占三成以上就按城区（取最多的城区字符），否则取最多的字符
	var cnt := {}
	var tot := 0
	var br := _poly_rect(poly)
	for gy in 6:
		for gx in 6:
			var q := br.position + Vector2((gx + 0.5) / 6.0 * br.size.x, (gy + 0.5) / 6.0 * br.size.y)
			if not in_convex(poly, q):
				continue
			var c0 := district(q)
			cnt[c0] = int(cnt.get(c0, 0)) + 1
			tot += 1
	var ch := district(s)
	var urb := 0
	var best_u := ""
	var best_any := ch
	for c1: String in cnt:
		if c1 in URBAN:
			urb += cnt[c1]
			if best_u == "" or cnt[c1] > cnt[best_u]:
				best_u = c1
		if cnt[c1] > int(cnt.get(best_any, 0)):
			best_any = c1
	if tot > 0:
		ch = best_u if float(urb) / tot >= 0.3 else best_any
	var kind := "rural"
	var raw_ang := _na.get_noise_2d(s.x, s.y) * 0.42
	var ang := roundf(raw_ang / 0.20) * 0.20 + (h2(k.x, k.y, 23) - 0.5) * 0.06
	var sp := Vector2(38, 28)
	if ch in URBAN:
		kind = "grid"
		match ch:
			"D": sp = Vector2(lerpf(44, 56, h2(k.x, k.y, 24)), lerpf(32, 40, h2(k.x, k.y, 25)))
			"R": sp = Vector2(lerpf(48, 60, h2(k.x, k.y, 24)), lerpf(34, 42, h2(k.x, k.y, 25)))
			"I": sp = Vector2(lerpf(102, 126, h2(k.x, k.y, 24)), lerpf(64, 82, h2(k.x, k.y, 25)))
			"H": sp = Vector2(lerpf(74, 90, h2(k.x, k.y, 24)), lerpf(50, 62, h2(k.x, k.y, 25)))
			"Y": sp = Vector2(140, 66)
			"M": sp = Vector2(lerpf(64, 78, h2(k.x, k.y, 24)), lerpf(48, 58, h2(k.x, k.y, 25)))
		if ch == "I" or ch == "Y" or ch == "H":
			ang = (h2(k.x, k.y, 26) - 0.5) * 0.08          # 厂区、港区、编组站顺着东西向铁路与岸线规整排布
		if ch == "M":
			kind = "mil"
		elif ch == "Y":
			kind = "yard"
		for rc: Dictionary in RADIAL:
			if ch == "D" and (in_convex(poly, Vector2(rc.c[0], rc.c[1])) or s.distance_to(Vector2(rc.c[0], rc.c[1])) < 68.0):
				kind = "radial"
	var info := {"k": k, "seed": s, "poly": poly, "labels": labels, "ch": ch, "kind": kind, "ang": ang, "sp": sp,
		"ph": Vector2(h2(k.x, k.y, 27), h2(k.x, k.y, 28))}
	_nbc[k] = info
	return info


# ---------------------------------------------------------------- 战区内的遗迹 / 地标 / 撤离点
static var _poi_cache := {}


## 战区的遗迹中心（世界坐标）与类型：从数据里的格子中心出发，螺旋搜索避开主干道、铁路、水面与其他遗迹
static func zone_pois(id: String) -> Array:
	if _poi_cache.has(id):
		return _poi_cache[id]
	var md: Dictionary = GameData.map_data(id)
	var org := origin(id)
	var f := features()
	var out: Array = []
	var auto := 0
	var order: Array = preload("res://scripts/maps.gd").POI_ORDER
	for c: Array in md.get("pois", []):
		var pid: String = str(c[2]) if c.size() > 2 else str(order[auto % order.size()])
		if c.size() <= 2:
			auto += 1
		var base := Vector2(-HALF + CELL * (int(c[0]) + 0.5), -HALF + CELL * (int(c[1]) + 0.5))
		var best := base
		var found := false
		for r in range(0, 56, 4):
			var steps := 1 if r == 0 else 12
			for k in steps:
				var a := TAU * k / steps + (h2(int(c[0]), int(c[1]), r) * 0.5)
				var q := base + Vector2(cos(a), sin(a)) * r
				if not in_zone_poly(id, q, 18.0):
					continue
				var w := org + q
				if f.art.edge_dist(w) < 13.5 or f.rail.edge_dist(w) < 13.0 or water_dist(w) < 14.0:
					continue
				var clash := false
				for o: Dictionary in out:
					if o.c.distance_to(w) < 30.0:
						clash = true
				if clash:
					continue
				best = q
				found = true
				break
			if found:
				break
		out.append({"c": org + best, "id": pid})
	_poi_cache[id] = out
	return out


## 地标落位点（战区本地坐标，确定性）：数据里的原位压在遗迹院落上时，按固定的环形顺序向外找第一处离开所有院落的点；
## 城市群建筑留空（_clear_zones）、生成杂物留空（raid._shield_spots）和地标脚本（map_ext/landmarks.gd）都用这同一个点，
## 这样地标原位从头到尾都是空地，不再在生成末尾按随机杂物临时挪位（挪位结果随种子漂移）
static var _lm_cache := {}


static func landmark_spot(id: String, e: Dictionary) -> Vector2:
	var raw := Vector2(float(e.get("x", 0)), float(e.get("z", 0)))
	if bool(e.get("water", false)):
		return raw
	var key := "%s|%s|%.1f|%.1f" % [id, str(e.get("type", "")), raw.x, raw.y]
	if _lm_cache.has(key):
		return _lm_cache[key]
	var org := origin(id)
	var cl := float(e.get("clear", 7.0))
	var need := cl + 16.5
	var pois := zone_pois(id)
	var best := raw
	var found := false
	for r in range(0, 60, 4):
		var steps := 1 if r == 0 else 16
		for k in steps:
			var a := TAU * k / steps
			var q := raw + Vector2(cos(a), sin(a)) * r
			if not in_zone_poly(id, q, maxf(16.0, cl + 4.0)):
				continue
			if is_surface(id) and water_dist(org + q, true) < cl + 2.0:
				continue
			var ok := true
			for p: Dictionary in pois:
				if (p.c as Vector2).distance_to(org + q) < need:
					ok = false
					break
			if ok:
				best = q
				found = true
				break
		if found:
			break
	_lm_cache[key] = best
	return best


## 需要清空建筑的圆：遗迹院落、地标、撤离点（世界坐标 Vector3(x, z, r)），按格子收集周围 3×3 个战区
static func _clear_zones(t: Vector2i) -> Array:
	var out: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var id := zone_of_tile(t + Vector2i(dx, dz))
			if id == "":
				continue
			var org := origin(id)
			var md: Dictionary = GameData.map_data(id)
			for p: Dictionary in zone_pois(id):
				out.append(Vector3(p.c.x, p.c.y, 15.5))
			for e in md.get("landmarks", []):
				if not bool(e.get("water", false)):
					var ls := landmark_spot(id, e)
					out.append(Vector3(org.x + ls.x, org.y + ls.y, float(e.get("clear", 7.0)) + 3.0))
			for e: Array in md.get("extracts", []):
				out.append(Vector3(org.x + float(e[1]), org.y + float(e[2]), 10.0))
	return out


# ---------------------------------------------------------------- 转场口（相邻战区共用的不规则共享分界段）
static var _gate_cache := {}
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}


## 战区 id 的 edge 互通分界线上转场口的弧长参数（米；沿 canonical_border_world 折线度量，相邻两战区共用同一弧长）：
## 只在长度 ≥ 40 米的直分界段内侧选点，两侧向内 6~28 米都得是平地（非水面、悬崖、建筑、遗迹院落），道路跨界处优先。
static var use_gate_table := true


static func gate_along(id: String, edge: String) -> float:
	var key := "%s|%s" % [id, edge]
	if _gate_cache.has(key):
		return _gate_cache[key]
	if use_gate_table and WorldGates.GATES.has(key):
		return float(WorldGates.GATES[key])
	return gate_compute(id, edge)


## 把规范共享分界折线上的弧长 along 还原成战区本地 / 世界坐标、内向法线与沿界切线
static func border_at(id: String, to: String, along: float) -> Dictionary:
	var chain := canonical_border_world(id, to)
	var o := origin(id)
	if chain.size() < 2:
		var inw0: Vector2 = {"N": Vector2(0, 1), "S": Vector2(0, -1), "W": Vector2(1, 0), "E": Vector2(-1, 0)}.get("N", Vector2(0, 1))
		return {"world": o, "pos": Vector2.ZERO, "inward": inw0, "tangent": Vector2(inw0.y, -inw0.x), "along": along}
	var acc := 0.0
	var wp := chain[0]
	var seg_dir := (chain[1] - chain[0]).normalized()
	for i in chain.size() - 1:
		var a := chain[i]
		var b := chain[i + 1]
		var sl := a.distance_to(b)
		if along <= acc + sl or i == chain.size() - 2:
			var t := clampf((along - acc) / maxf(sl, 0.001), 0.0, 1.0)
			wp = a.lerp(b, t)
			seg_dir = (b - a) / maxf(sl, 0.001)
			break
		acc += sl
	var n1 := Vector2(-seg_dir.y, seg_dir.x)
	var zp := zone_poly_world(id)
	var inw := n1 if Geometry2D.is_point_in_polygon(wp + n1 * 5.0, zp) else -n1
	# 本地 +z = inw，本地 +x = tangent（与 Godot rotation.y = atan2(inw.x, inw.y) 右手系严格一致）
	var tang := Vector2(inw.y, -inw.x)
	return {"world": wp, "pos": wp - o, "inward": inw, "tangent": tang, "along": along}


static func gate_info(id: String, edge: String) -> Dictionary:
	var to: String = WorldLink.LINKS.get(id, {}).get(edge, "")
	var along := gate_along(id, edge)
	return border_at(id, to, along)


## 转场口弧长现算（不查表；规范化 (min(id,to), max(id,to)) 保证两侧结果 100% 一致）
static func gate_compute(id: String, edge: String) -> float:
	var to: String = WorldLink.LINKS.get(id, {}).get(edge, "")
	var key := "%s|%s" % [id, edge]
	if _gate_cache.has(key):
		return _gate_cache[key]
	if to == "":
		_gate_cache[key] = 0.0
		return 0.0
	var a_id := id if id < to else to
	var b_id := to if id < to else id
	var chain := canonical_border_world(a_id, b_id)
	var ta := tile_of(a_id)
	var tb := tile_of(b_id)
	var la := tile_layout(ta)
	var lb := tile_layout(tb)
	var f := features()
	var zp_a := zone_poly_world(a_id)
	var near_b: Array = []
	for L: Dictionary in [la, lb]:
		for b: Dictionary in L.bldgs:
			if poly_dist(chain, b.c) < 52.0:
				near_b.append(obb_corners(b.c, b.ang, b.sx + 9.0, b.sz + 9.0))
	var clears := _clear_zones(ta) + _clear_zones(tb)
	var total_len := 0.0
	for i in chain.size() - 1:
		total_len += chain[i].distance_to(chain[i + 1])
	var half_span: float = float(WorldLink.HALF_SPAN)
	var best := total_len * 0.5
	var bs := -INF
	var acc := 0.0
	for i in chain.size() - 1:
		var pa := chain[i]
		var pb := chain[i + 1]
		var sl := pa.distance_to(pb)
		var margin := half_span + 3.5
		if sl >= margin * 2.0:
			var dir := (pb - pa) / sl
			var n1 := Vector2(-dir.y, dir.x)
			var inw_a := n1 if Geometry2D.is_point_in_polygon(pa.lerp(pb, 0.5) + n1 * 5.0, zp_a) else -n1
			var s := margin
			while s <= sl - margin + 0.01:
				var wp := pa + dir * s
				var ok := true
				var road := false
				if f.art.edge_dist(wp) < 4.5:
					road = true
				for side in [1.0, -1.0]:
					var L: Dictionary = la if side > 0.0 else lb
					for inset: float in [6.0, 13.0, 21.0, 28.0]:
						var lats: Array = [-9.0, 0.0, 9.0] if inset <= 7.0 else [0.0]
						for lat: float in lats:
							var q: Vector2 = wp + dir * lat + inw_a * (inset * side)
							if water_dist(q, true) < 2.5 or dist_at(L, q) == "K":
								ok = false
								break
							for poly: PackedVector2Array in near_b:
								if in_convex(poly, q):
									ok = false
									break
							if not ok:
								break
							for cz: Vector3 in clears:
								if q.distance_to(Vector2(cz.x, cz.y)) < cz.z + 4.5 and cz.z > 12.0:
									ok = false
									break
							if not ok:
								break
							var rg: SegGrid = L.road_grid
							if rg.edge_dist(q) < 1.5:
								road = true
						if not ok:
							break
					if not ok:
						break
				if ok:
					var center_bias := -absf((acc + s) - total_len * 0.5) * 0.08
					var seg_room := minf(s, sl - s) * 0.22
					var sc := center_bias + seg_room + (45.0 if road else 0.0)
					if sc > bs:
						bs = sc
						best = acc + s
				s += 4.0
		acc += sl
	_gate_cache[key] = best
	_gate_cache["%s|%s" % [to, OPP[edge]]] = best
	return best


# ---------------------------------------------------------------- 格子与战区窗口布局
static var _tile_cache := {}


## 任意世界矩形窗口的确定性布局（世界坐标）；tile_layout 与 zone_layout 共用同一套生成管线
static func _rect_layout(rect: Rect2, id: String, t: Vector2i) -> Dictionary:
	var f := features()
	var big := rect.grow(CLIP_PAD)
	var ro := rect.position - Vector2(RAST_PAD, RAST_PAD)
	var rn := int(roundf((rect.size.x + RAST_PAD * 2.0) / RAST))
	var rast := _raster(ro, rn)
	var L := {"tile": t, "id": id, "rect": rect, "r_o": ro, "r_n": rn, "rast": rast}
	var clears := _clear_zones(t)
	var local_feat := _local_features(id)
	# 河流 / 湖 / 铁路 / 山脊：取与窗口相交的
	var rivers: Array = []
	for r: Dictionary in f.rivers + local_feat.rivers:
		if _poly_hits(r.pts, big.grow(r.w)):
			rivers.append(r)
	var lakes: Array = []
	for l: Vector3 in f.lakes + local_feat.lakes:
		if big.grow(l.z).has_point(Vector2(l.x, l.y)):
			lakes.append(l)
	if id == "" or is_surface(id):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var nt := t + Vector2i(dx, dz)
				if zone_of_tile(nt) != "":
					continue
				var nrect := Rect2(Vector2(nt.x * TILE - HALF, nt.y * TILE - HALF), Vector2(TILE, TILE))
				if not big.intersects(nrect):
					continue
				for mp: Vector3 in _marsh_pools(nt):
					if big.grow(mp.z).has_point(Vector2(mp.x, mp.y)):
						lakes.append(mp)
	var rails: Array = []
	for r: PackedVector2Array in f.rails + local_feat.rails:
		if _poly_hits(r, big):
			rails.append(r)
	var rg_rail := SegGrid.new()
	rg_rail.cell = 20.0
	rg_rail.reach = 18.0
	for ri in rails.size():
		rg_rail.add_poly(rails[ri], 2.0, ri)
	var ridges: Array = []
	for r: PackedVector2Array in f.ridges + local_feat.ridges:
		if _poly_hits(r, big):
			ridges.append(r)
	L.rivers = rivers
	L.lakes = lakes
	L.rails = rails
	L.rail_grid = rg_rail
	L.ridges = ridges
	# ---- 道路
	var roads: Array = []
	for r: Dictionary in f.roads + local_feat.roads:
		for run: PackedVector2Array in _clip_rect(r.pts, big):
			roads.append({"pts": run, "w": r.w, "dirt": r.dirt, "kind": r.kind, "bridge": r.bridge, "name": r.get("name", "")})
	var surf_layout := (id == "" or is_surface(id))
	var nbs := _tile_nbs(rect.grow(NB * 1.5))
	var col_done := {}
	var blocks: Array = []
	var fields: Array = []
	var parks: Array = []
	for k: Vector2i in nbs:
		var nb := nb_info(k)
		# 支路：街区边界（每对相邻街区只生成一次，仅限地表战区/城市群瓦片）
		var poly: PackedVector2Array = nb.poly
		if surf_layout:
			for i in poly.size():
				var o = nb.labels[i]
				if o == null:
					continue
				var key := [k, o] if (k.x < o.x or (k.x == o.x and k.y < o.y)) else [o, k]
				var ks := str(key)
				if col_done.has(ks):
					continue
				col_done[ks] = true
				var a := poly[i]
				var b := poly[(i + 1) % poly.size()]
				if not big.grow(10).intersects(Rect2(a, Vector2.ZERO).expand(b)):
					continue
				var kind := col_kind(k, o)
				if kind == "":
					continue
				var w := 9.0 if kind == "col" else 6.0
				var dirt := kind == "track"
				var pts := dense(PackedVector2Array([a, b]), 3.0)
				for j in pts.size():
					pts[j] += Vector2(_nr.get_noise_2d(pts[j].x, pts[j].y), _nr.get_noise_2d(pts[j].x - 333.0, pts[j].y + 777.0)) * 2.4
				var bridge := h2(k.x * 3 + o.x, k.y * 5 + o.y, 32) < 0.5
				for run in _filter_road(L, pts, kind, w, clears, bridge):
					for r2 in _clip_rect(run, big):
						roads.append({"pts": r2, "w": w, "dirt": dirt, "kind": kind, "bridge": bridge})
		# 街区内部
		match str(nb.kind):
			"grid", "mil", "yard":
				_grid_streets(L, nb, roads, blocks, clears)
			"radial":
				_radial_blocks(L, nb, blocks)
			_:
				if nb.ch == "F":
					fields.append_array(_make_fields(L, poly, nb.ang, k))
				elif nb.ch == "P":
					parks.append(centroid(poly))
	if surf_layout:
		for rc: Dictionary in RADIAL:
			_radial_streets(L, rc, roads, clears)
	# 道路收口与空间索引
	roads = _link_roads(L, roads, clears)
	var rg := SegGrid.new()
	rg.cell = 16.0
	rg.reach = 8.0
	for i in roads.size():
		rg.add_poly(roads[i].pts, roads[i].w * 0.5, i)
	L.road_grid = rg
	var clipped_roads: Array = []
	var clip_r := rect.grow(3.0)
	for r: Dictionary in roads:
		clipped_roads.append_array(_clip_road(r, clip_r))
	L.roads = clipped_roads
	# ---- 建筑（按确定性街块 / 田块顺序生成，并用空间网格强制全局最小间距 >= ALLEY，彻底杜绝跨街块重叠或窄缝）
	blocks.sort_custom(func(a, b):
		var ia: Vector3i = a.id
		var ib: Vector3i = b.id
		if ia.x != ib.x:
			return ia.x < ib.x
		if ia.y != ib.y:
			return ia.y < ib.y
		return ia.z < ib.z
	)
	fields.sort_custom(func(a, b):
		var ka: Vector2i = a.k
		var kb: Vector2i = b.k
		if ka.x != kb.x:
			return ka.x < kb.x
		if ka.y != kb.y:
			return ka.y < kb.y
		return int(a.sub) < int(b.sub)
	)
	var bl: Array = []
	var bgrid := {}
	var bcell := 24.0
	for blk: Dictionary in blocks:
		if not big.intersects(_poly_rect(blk.poly)):
			continue
		for b: Dictionary in _block_buildings(blk, L, clears):
			if _bldg_ok(L, b, clears) and _bldg_grid_ok(bgrid, bcell, b):
				_bldg_grid_add(bgrid, bcell, b)
				bl.append(b)
	for fd: Dictionary in fields:
		if not big.intersects(_poly_rect(fd.poly)) or fd.poly.size() < 3:
			continue
		for b: Dictionary in _farm_buildings(fd):
			if _bldg_ok(L, b, clears) and _bldg_grid_ok(bgrid, bcell, b):
				_bldg_grid_add(bgrid, bcell, b)
				bl.append(b)
	if surf_layout:
		_fill_urban_gaps(L, bl, bgrid, bcell, clears)
	L.blocks = blocks
	L.fields = fields
	L.parks = parks
	L.bldgs = bl
	return L


## 城区空洞补充：对位于中心城（D）/ 街坊（R）但因街区接缝、未修成的虚构格网街道或斜交主干道而落在街块多边形之外的空白地块，
## 沿最近实修道路朝向紧凑贴街补建宽体城市建筑，严格通过 _bldg_ok 与 _bldg_grid_ok（保证 >= 1.35m 路缘、>= 4.3m 巷距、零侵入清空圈）。
static func _fill_urban_gaps(L: Dictionary, bl: Array, bgrid: Dictionary, bcell: float, clears: Array) -> void:
	var rect: Rect2 = (L.rect as Rect2).grow(24.0)
	var rg: SegGrid = L.road_grid
	var f := features()
	var rg_rail: SegGrid = L.get("rail_grid", null)
	const STEP := 8.0
	var gx0 := floori(rect.position.x / STEP)
	var gx1 := ceili(rect.end.x / STEP)
	var gz0 := floori(rect.position.y / STEP)
	var gz1 := ceili(rect.end.y / STEP)
	# 两阶段补建：第一轮优先在主街面落位宽体大楼（civic_block / midrise_office / rowblock），第二轮再把紧凑角楼塞进剩余小缝隙，杜绝小方块抢占大街面
	var passes_d: Array = [
		[[24.0, 14.0], [21.5, 11.5], [18.5, 12.5], [16.0, 10.5]],
		[[13.5, 9.5], [10.8, 8.6], [9.4, 7.8]],
	]
	var passes_r: Array = [
		[[21.0, 10.5], [17.5, 9.5], [14.0, 8.8]],
		[[10.8, 8.0], [9.0, 7.4]],
	]
	for pass_i in 2:
		for gz in range(gz0, gz1 + 1):
			for gx in range(gx0, gx1 + 1):
				var p := Vector2((float(gx) + 0.5) * STEP, (float(gz) + 0.5) * STEP)
				var ch := dist_at(L, p)
				if not (ch in ["D", "R"]):
					continue
				# 保留约 6% 确定性呼吸口袋供街心公园 / 地面停车场落位
				if h2(gx, gz, 731) < 0.06:
					continue
				if rg.edge_dist(p) < 4.4 or water_dist(p) < 5.0 or f.rail.edge_dist(p) < 4.6:
					continue
				if rg_rail != null and rg_rail.edge_dist(p) < 4.6:
					continue
				var in_clr := false
				for cz: Vector3 in clears:
					var cp := Vector2(cz.x, cz.y)
					var rr := maxf(2.0, cz.z - 2.0)
					if p.distance_squared_to(cp) < rr * rr:
						in_clr = true
						break
				if in_clr:
					continue
				var si := rg.nearest(p, 56.0)
				var ang := 0.0
				var road_cp := Vector2.ZERO
				var road_out := Vector2.ZERO
				var road_hw := 0.0
				var has_road := false
				if si >= 0:
					var sa: Vector2 = rg.a[si]
					var sb: Vector2 = rg.b[si]
					var sdir := (sb - sa).normalized()
					road_cp = Geometry2D.get_closest_point_to_segment(p, sa, sb)
					var diff := p - road_cp
					if diff.length_squared() > 0.25:
						road_out = diff.normalized()
						var to_road := -road_out
						ang = atan2(-to_road.x, to_road.y)
						road_hw = rg.hw[si]
						has_road = true
					else:
						ang = atan2(sdir.y, sdir.x)
				else:
					ang = float(nb_info(nb_owner(p)).ang)
				var rng := RandomNumberGenerator.new()
				rng.seed = int(h2(gx, gz, 733 + pass_i * 19) * 2147483647.0) + 91
				var shapes: Array = passes_d[pass_i] if ch == "D" else passes_r[pass_i]
				var placed_one := false
				for sh: Array in shapes:
					var tw: float = float(sh[0])
					var td: float = float(sh[1])
					var cands: Array[Vector2] = []
					if has_road:
						var rd_d := p.distance_to(road_cp) - road_hw
						if rd_d >= td * 0.5 + 1.4 and rd_d <= 22.0:
							var hug_c: Vector2 = road_cp + road_out * (road_hw + 1.85 + td * 0.5)
							if dist_at(L, hug_c) in ["D", "R"]:
								cands.append(hug_c)
					cands.append(p)
					for cand_c: Vector2 in cands:
						for a_off: float in [0.0, PI * 0.5]:
							var test_ang := ang + a_off
							var cand := {"c": cand_c, "ang": test_ang, "sx": tw, "sz": td, "h": 12.0, "kind": "bld", "ch": ch}
							if _bldg_ok(L, cand, clears) and _bldg_grid_ok(bgrid, bcell, cand):
								if rg_rail != null and rg_rail.edge_dist(cand_c) < Vector2(tw, td).length() * 0.5 + 2.2:
									continue
								var sp_h: Array = FRONT_SPEC[ch].h
								var picked := _pick_style(ch, tw, td, rng.randf_range(sp_h[0], sp_h[1]), rng)
								cand.kind = picked[0]
								cand.h = picked[1]
								_bldg_grid_add(bgrid, bcell, cand)
								bl.append(cand)
								placed_one = true
								break
						if placed_one:
							break
					if placed_one:
						break


static func _bldg_grid_ok(bgrid: Dictionary, cell: float, b: Dictionary) -> bool:
	var cs := obb_corners(b.c, b.ang, b.sx, b.sz)
	var r := _poly_rect(cs).grow(ALLEY + 0.5)
	var x0 := floori(r.position.x / cell)
	var x1 := floori(r.end.x / cell)
	var y0 := floori(r.position.y / cell)
	var y1 := floori(r.end.y / cell)
	var checked := {}
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var lst = bgrid.get(Vector2i(gx, gy))
			if lst == null:
				continue
			for item: Array in lst:
				var idx: int = item[0]
				if checked.has(idx):
					continue
				checked[idx] = true
				if convex_overlap(item[1], cs, ALLEY - 0.15):
					return false
	return true


static func _bldg_grid_add(bgrid: Dictionary, cell: float, b: Dictionary) -> void:
	var cs := obb_corners(b.c, b.ang, b.sx, b.sz)
	var r := _poly_rect(cs)
	var idx: int = int(bgrid.get("_n", 0))
	bgrid["_n"] = idx + 1
	var item := [idx, cs]
	for gy in range(floori(r.position.y / cell), floori(r.end.y / cell) + 1):
		for gx in range(floori(r.position.x / cell), floori(r.end.x / cell) + 1):
			var key := Vector2i(gx, gy)
			if not bgrid.has(key):
				bgrid[key] = []
			bgrid[key].append(item)


## 一个 360 米格子的确定性布局（世界坐标，供大地图导出与转场口计算缓存）
static func tile_layout(t: Vector2i) -> Dictionary:
	if _tile_cache.has(t):
		return _tile_cache[t]
	var c := Vector2(t.x * TILE, t.y * TILE)
	var rect := Rect2(c - Vector2(HALF, HALF), Vector2(TILE, TILE))
	var L := _rect_layout(rect, zone_of_tile(t), t)
	_tile_cache[t] = L
	return L


## 战区窗口的布局（转成战区本地坐标，raid.gd 用：含不规则战区多边形 poly 与周界外的连续城市群远景 backdrop_bldgs）
static var _zone_cache := {}


static func zone_layout(id: String) -> Dictionary:
	if _zone_cache.has(id):
		return _zone_cache[id]
	var surf := is_surface(id)
	var wh := BACKDROP_HALF if surf else ZONE_HALF
	var o := origin(id)
	var rect := Rect2(o - Vector2(wh, wh), Vector2(wh * 2.0, wh * 2.0))
	var L := _rect_layout(rect, id, tile_of(id))
	var zpoly := zone_poly(id)
	var Z := {
		"id": id, "origin": o, "poly": zpoly, "half": ZONE_HALF, "ext_half": wh, "surface": surf,
		"r_o": L.r_o - o, "r_n": L.r_n, "rast": L.rast,
	}
	var roads: Array = []
	for r: Dictionary in L.roads:
		roads.append({"pts": _shift(r.pts, -o), "w": r.w, "w0": float(r.get("w0", r.w)), "w1": float(r.get("w1", r.w)), "dirt": r.dirt, "kind": r.kind, "bridge": r.bridge, "caps": r.get("caps", [false, false])})
	Z.roads = roads
	var rivers: Array = []
	for r: Dictionary in L.rivers:
		rivers.append({"pts": _shift(_clip_one(r.pts, L.rect.grow(CLIP_PAD)), -o), "w": r.w, "dry": r.dry, "name": r.get("name", "")})
	Z.rivers = rivers
	var lakes: Array = []
	for l: Vector3 in L.lakes:
		lakes.append(Vector3(l.x - o.x, l.y - o.y, l.z))
	Z.lakes = lakes
	var rails: Array = []
	for r: PackedVector2Array in L.rails:
		for run in _clip_rect(r, L.rect.grow(CLIP_PAD)):
			rails.append(_shift(run, -o))
	Z.rails = rails
	var ridges: Array = []
	for r: PackedVector2Array in L.ridges:
		for run in _clip_rect(r, L.rect.grow(-4)):
			ridges.append(_shift(run, -o))
	Z.ridges = ridges
	var blocks: Array = []
	for b: Dictionary in L.blocks:
		var c: Vector2 = centroid(b.poly) - o
		if absf(c.x) < wh + 20.0 and absf(c.y) < wh + 20.0:
			blocks.append({"poly": _shift(b.poly, -o), "ch": b.ch, "ang": b.ang, "kind": b.kind})
	Z.blocks = blocks
	var fields: Array = []
	for fd: Dictionary in L.fields:
		fields.append({"poly": _shift(fd.poly, -o), "ang": fd.ang})
	Z.fields = fields
	var parks: Array = []
	for p: Vector2 in L.parks:
		parks.append(p - o)
	Z.parks = parks
	var gate_pts: Array = []
	for e_key: String in WorldLink.LINKS.get(id, {}):
		gate_pts.append(gate_info(id, e_key).pos)
	var bl: Array = []
	var bg_bl: Array = []
	for b: Dictionary in L.bldgs:
		var lc: Vector2 = b.c - o
		var near_gate := false
		for gp: Vector2 in gate_pts:
			if lc.distance_to(gp) < maxf(b.sx, b.sz) * 0.5 + 16.0:
				near_gate = true
				break
		if near_gate:
			continue
		var cs := obb_corners(lc, b.ang, b.sx, b.sz)
		var min_sd := poly_signed_dist(zpoly, lc)
		var max_sd := min_sd
		for q in cs:
			var sd := poly_signed_dist(zpoly, q)
			min_sd = minf(min_sd, sd)
			max_sd = maxf(max_sd, sd)
		if min_sd >= 3.2:
			var nb2: Dictionary = b.duplicate()
			nb2.c = lc
			bl.append(nb2)
		elif surf and max_sd <= -4.5 and absf(lc.x) < wh - 8.0 and absf(lc.y) < wh - 8.0:
			var nb3: Dictionary = b.duplicate()
			nb3.c = lc
			bg_bl.append(nb3)
	Z.bldgs = bl
	Z.backdrop_bldgs = bg_bl
	var pois: Array = []
	for p: Dictionary in zone_pois(id):
		pois.append({"c": p.c - o, "id": p.id})
	Z.pois = pois
	_zone_cache[id] = Z
	return Z


## 给定世界坐标的区块字符（用格子栅格；格子外退回精确计算）
static func dist_at(L: Dictionary, p: Vector2) -> String:
	var n: int = L.r_n
	var x := floori((p.x - L.r_o.x) / RAST)
	var y := floori((p.y - L.r_o.y) / RAST)
	if x < 0 or y < 0 or x >= n or y >= n:
		return district(p)
	return char(L.rast[y * n + x])


# ---------------------------------------------------------------- 布局细节
## 数据里写的战区本地要素（竖井战区等用：curves / river / lakes / rails / ridges），转成世界坐标
static func _local_features(id: String) -> Dictionary:
	var out := {"rivers": [], "lakes": [], "roads": [], "rails": [], "ridges": []}
	if id == "":
		return out
	var md: Dictionary = GameData.map_data(id)
	var o := origin(id)
	var rv: Dictionary = md.get("river", {})
	if rv.get("pts", []).size() > 1:
		out.rivers.append({"name": "", "pts": _shift(smooth(_offset_ctrl(rv.pts, o), 4.0), Vector2.ZERO), "w": float(rv.w), "dry": bool(rv.dry)})
	for l: Array in md.get("lakes", []):
		out.lakes.append(Vector3(l[0] + o.x, l[1] + o.y, l[2]))
	for cv: Array in md.get("curves", []):
		var closed := cv.size() > 3 and bool(cv[3])
		out.roads.append({"name": "", "pts": smooth_bezier(_offset_ctrl(cv[2], o), 2.4, closed), "w": float(cv[0]), "dirt": bool(cv[1]),
			"kind": "dirt" if bool(cv[1]) else "art", "bridge": not bool(cv[1])})
	for line: Array in md.get("rails", []):
		out.rails.append(dense(PackedVector2Array(_offset_ctrl(line, o).map(func(q): return Vector2(q[0], q[1]))), 6.0))
	for line: Array in md.get("ridges", []):
		out.ridges.append(smooth(_offset_ctrl(line, o), 3.2))
	return out


static func _offset_ctrl(ctrl: Array, o: Vector2) -> Array:
	var out: Array = []
	for q in ctrl:
		out.append([float(q[0]) + o.x, float(q[1]) + o.y])
	return out


static func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + d
	return out


static func _poly_rect(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


static func _poly_hits(pts: PackedVector2Array, r: Rect2) -> bool:
	return pts.size() > 1 and r.intersects(_poly_rect(pts))


## 折线截成在矩形内的若干段
static func _clip_rect(pts: PackedVector2Array, r: Rect2) -> Array:
	var out: Array = []
	var run := PackedVector2Array()
	for p in pts:
		if r.has_point(p):
			run.append(p)
		else:
			if run.size() >= 2:
				out.append(run)
			run = PackedVector2Array()
	if run.size() >= 2:
		out.append(run)
	return out


## 裁切道路到矩形内；只有仍保持原端点的那一头才保留断头圆帽标记及渐变端宽
static func _clip_road(r: Dictionary, rect: Rect2) -> Array:
	var pts: PackedVector2Array = r.pts
	if pts.size() < 2:
		return []
	var c0: Array = r.get("caps", [false, false])
	var w_def := float(r.w)
	var w0_orig := float(r.get("w0", w_def))
	var w1_orig := float(r.get("w1", w_def))
	var out: Array = []
	for run: PackedVector2Array in _clip_rect(pts, rect):
		if _poly_len(run) < 6.0:
			continue
		var nr := r.duplicate()
		nr.pts = run
		nr.caps = [bool(c0[0]) and run[0].is_equal_approx(pts[0]), bool(c0[1]) and run[run.size() - 1].is_equal_approx(pts[pts.size() - 1])]
		nr.w0 = w0_orig if run[0].is_equal_approx(pts[0]) else w_def
		nr.w1 = w1_orig if run[run.size() - 1].is_equal_approx(pts[pts.size() - 1]) else w_def
		out.append(nr)
	return out


## 只保留矩形附近（含首尾各多一个点）的那一段，供河道 / 水面判定
static func _clip_one(pts: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var i0 := -1
	var i1 := -1
	for i in pts.size():
		if r.has_point(pts[i]):
			if i0 < 0:
				i0 = i
			i1 = i
	if i0 < 0:
		return PackedVector2Array()
	return pts.slice(maxi(0, i0 - 1), mini(pts.size(), i1 + 2))


## 与矩形相交的街区格点
static func _tile_nbs(r: Rect2) -> Array:
	var out: Array = []
	for j in range(floori(r.position.y / NB) - 1, floori(r.end.y / NB) + 2):
		for i in range(floori(r.position.x / NB) - 1, floori(r.end.x / NB) + 2):
			var s := nb_seed(i, j)
			if r.grow(NB).has_point(s):
				out.append(Vector2i(i, j))
	return out


static func _near_non_yard_urban(L: Dictionary, p: Vector2, rad: float) -> bool:
	for d: Vector2 in [Vector2(rad, 0.0), Vector2(-rad, 0.0), Vector2(0.0, rad), Vector2(0.0, -rad)]:
		if dist_at(L, p + d) in "DRIHM":
			return true
	return false


## 道路采样点过滤：按道路类型去掉落在水面、悬崖、铁轨冲突区、遗迹院落里的部分，返回保留的连续段
static func _filter_road(L: Dictionary, pts: PackedVector2Array, kind: String, w: float, clears: Array, bridge := false) -> Array:
	var rg_rail: SegGrid = L.get("rail_grid", null)
	var keep := PackedByteArray()
	keep.resize(pts.size())
	for i in pts.size():
		var p := pts[i]
		var ok := true
		var ch := dist_at(L, p)
		match kind:
			"loc":
				ok = ch in URBAN and ch != "M" and ch != "Y"
			"col":
				ok = not (ch in NO_COLLECTOR) and ch != "Y" and (ch in "DRIHM" or ch == "P" or _near_non_yard_urban(L, p, 8.0) or (bridge and water_dist(p, false) < w * 0.5 + 8.0))
			"track":
				ok = not (ch in NO_COLLECTOR) and ch != "M" and ch != "Y"
		if ok and rg_rail != null:
			if kind == "loc" or kind == "track":
				if rg_rail.edge_dist(p) < w * 0.5 + 3.6:
					ok = false
			elif kind == "col":
				var si := rg_rail.nearest(p, w * 0.5 + 7.5)
				if si >= 0:
					var td := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
					var rdir := (rg_rail.b[si] - rg_rail.a[si]).normalized()
					if td == Vector2.ZERO or absf(td.dot(rdir)) >= 0.45:
						ok = false
					else:
						var base_tag: int = rg_rail.tag[si]
						var multi_rail := false
						var c0 := Vector2i(floori(p.x / rg_rail.cell), floori(p.y / rg_rail.cell))
						for dz_r in range(-1, 2):
							for dx_r in range(-1, 2):
								var lst = rg_rail.grid.get(Vector2i(c0.x + dx_r, c0.y + dz_r))
								if lst == null:
									continue
								for ri2: int in lst:
									if rg_rail.tag[ri2] != base_tag and seg_dist(p, rg_rail.a[ri2], rg_rail.b[ri2]) < 14.0:
										multi_rail = true
										break
								if multi_rail:
									break
							if multi_rail:
								break
						if multi_rail:
							ok = false
		if ok:
			var wd := water_dist(p, false)
			if wd < w * 0.5 + 2.0:
				# 有水河道只有允许架桥的大角交支路能过；干河床禁止局部格网路，支路与土路只准大角度横穿（禁沿河槽纵向伴行）
				var wet := water_dist(p, true) < w * 0.5 + 1.0
				if wet:
					ok = kind == "col" and bridge and _lake_free(p, w * 0.5 + 2.0) and features().art.edge_dist(p) > 18.0 and _cross_angle_ok(pts, i)
				else:
					ok = kind != "loc" and _dry_cross_ok(pts, i)
		if ok:
			for cz: Vector3 in clears:
				if p.distance_to(Vector2(cz.x, cz.y)) < cz.z - 2.0 + w * 0.5:
					ok = false
					break
		keep[i] = 1 if ok else 0
	var out: Array = []
	var run := PackedVector2Array()
	for i in pts.size():
		if keep[i] == 1:
			run.append(pts[i])
		else:
			if run.size() >= 3:
				out.append(run)
			run = PackedVector2Array()
	if run.size() >= 3:
		out.append(run)
	return out


## 支路过河：只有和河道接近垂直（夹角 > 55°）才架桥
static func _cross_angle_ok(pts: PackedVector2Array, i: int) -> bool:
	var f := features()
	var g: SegGrid = f.water
	var si := g.nearest(pts[i], 30.0)
	if si < 0:
		return false
	var rd: Vector2 = (g.b[si] - g.a[si]).normalized()
	var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
	return absf(d.cross(rd)) > 0.82


## 干河床穿越检查：只准大于 ~40° 横穿，严禁沿干河床纵向伴行
static func _dry_cross_ok(pts: PackedVector2Array, i: int) -> bool:
	var g: SegGrid = features().water
	var si := g.nearest(pts[i], 30.0)
	if si < 0:
		return false
	var rd: Vector2 = (g.b[si] - g.a[si]).normalized()
	var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
	return d != Vector2.ZERO and absf(d.cross(rd)) > 0.65


static func _lake_free(p: Vector2, pad: float) -> bool:
	for l: Vector3 in features().lakes:
		if lake_dist(l, p) < pad:
			return false
	return true


# ---------------------------------------------------------------- 道路收口（路口衔接 / 断头路）
## 每条道路的两端（只处理战区窗口里的端点，伸出窗口外的不管）：
##   · 端点已经压在别的路面上（路口）：没伸到对方中心线的补到中心线，路口里两条路的路面 / 人行道就一定重叠衔接，不会留缝；
##   · 顺着走向（或左右偏一点）LINK_REACH 米内能碰到别的路：接过去（中途遇到有水的河湖、遗迹院落、悬崖就放弃）；
##   · 都不是：断头路，caps 记下（渲染时画圆头，人行道绕过去）。一头断开且很短、或两头都断开且不长的残段直接去掉。
## 去掉残段后别的路可能变成断头，所以多轮迭代直到稳定。
const LINK_REACH := {"loc": 20.0, "col": 24.0, "track": 26.0, "art": 18.0, "hwy": 18.0, "dirt": 26.0}
const STUB_MIN_BY_KIND := {"loc": 145.0, "col": 135.0, "track": 145.0}
const ORPHAN_MIN := 420.0    ## 两头都断开的孤立程序化残段一律去掉
const TAIL_MAX := 92.0       ## 穿过路口后又伸出这么短一截断头尾巴的，齐根裁回到路口


## 点 p 沿切线 td（单位向量）是否落在 g 中某条道路/铁轨的伴行带宽内
static func _parallel_hit(g: SegGrid, p: Vector2, td: Vector2, pad: float, min_dot: float) -> bool:
	var lst = g.grid.get(Vector2i(floori(p.x / g.cell), floori(p.y / g.cell)))
	if lst == null:
		return false
	for i: int in lst:
		if seg_dist(p, g.a[i], g.b[i]) - g.hw[i] < pad:
			if min_dot < 0.0:
				return true
			var sd := (g.b[i] - g.a[i]).normalized()
			if sd != Vector2.ZERO and absf(td.dot(sd)) > min_dot:
				return true
	return false


## 沿折线剥除满足 drop_fn(p, td) 的伴行段，只保留足够长的连续段
static func _strip_parallel_runs(r: Dictionary, pts: PackedVector2Array, drop_fn: Callable, min_len: float) -> Array:
	var out: Array = []
	var run := PackedVector2Array()
	for k in pts.size():
		var p := pts[k]
		var td := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		if bool(drop_fn.call(p, td)):
			if run.size() >= 4 and _poly_len(run) >= min_len:
				var nr := r.duplicate()
				nr.pts = run
				out.append(nr)
			run = PackedVector2Array()
		else:
			run.append(p)
	if run.size() >= 4 and _poly_len(run) >= min_len:
		var nr := r.duplicate()
		nr.pts = run
		out.append(nr)
	return out


## 在没有第三条路介入的 Voronoi 顶点处，将同级共线的程序化道路首尾焊成一条，消除端点互爬穿模
static func _merge_collinear_proc_roads(roads: Array) -> Array:
	var cur: Array = roads.duplicate()
	for _pass in 8:
		var g := SegGrid.new()
		g.cell = 16.0
		g.reach = 10.0
		for i in cur.size():
			g.add_poly(cur[i].pts, float(cur[i].w) * 0.5, i)
		var merged_any := false
		var dead := PackedByteArray()
		dead.resize(cur.size())
		var nxt: Array = []
		for i in cur.size():
			if dead[i] == 1:
				continue
			var ri: Dictionary = cur[i]
			var ki := str(ri.kind)
			var pts_i: PackedVector2Array = ri.pts
			var ring_i := pts_i.size() > 8 and pts_i[0].distance_to(pts_i[pts_i.size() - 1]) < float(ri.w) * 0.5
			if not (ki in ["loc", "col", "track"]) or pts_i.size() < 2 or ring_i:
				nxt.append(ri)
				continue
			var joined := false
			for j in range(i + 1, cur.size()):
				if dead[j] == 1:
					continue
				var rj: Dictionary = cur[j]
				if str(rj.kind) != ki or absf(float(ri.w) - float(rj.w)) > 0.05 or bool(ri.dirt) != bool(rj.dirt):
					continue
				var pts_j: PackedVector2Array = rj.pts
				var ring_j := pts_j.size() > 8 and pts_j[0].distance_to(pts_j[pts_j.size() - 1]) < float(rj.w) * 0.5
				if pts_j.size() < 2 or ring_j:
					continue
				var best_ei := -1
				var best_ej := -1
				var best_d := 2.4
				for ei in 2:
					var pi: Vector2 = pts_i[0] if ei == 0 else pts_i[pts_i.size() - 1]
					for ej in 2:
						var pj: Vector2 = pts_j[0] if ej == 0 else pts_j[pts_j.size() - 1]
						var d := pi.distance_to(pj)
						if d < best_d:
							best_d = d
							best_ei = ei
							best_ej = ej
				if best_ei < 0:
					continue
				var pi: Vector2 = pts_i[0] if best_ei == 0 else pts_i[pts_i.size() - 1]
				var qi: Vector2 = pts_i[mini(2, pts_i.size() - 1)] if best_ei == 0 else pts_i[maxi(pts_i.size() - 3, 0)]
				var pj: Vector2 = pts_j[0] if best_ej == 0 else pts_j[pts_j.size() - 1]
				var qj: Vector2 = pts_j[mini(2, pts_j.size() - 1)] if best_ej == 0 else pts_j[maxi(pts_j.size() - 3, 0)]
				var t_arr := (pi - qi).normalized()
				var t_dep := (qj - pj).normalized()
				if t_arr == Vector2.ZERO or t_dep == Vector2.ZERO or t_arr.dot(t_dep) <= 0.80:
					continue
				var jp := (pi + pj) * 0.5
				var third_near := false
				var lst = g.grid.get(Vector2i(floori(jp.x / g.cell), floori(jp.y / g.cell)))
				if lst != null:
					for si: int in lst:
						if g.tag[si] != i and g.tag[si] != j and seg_dist(jp, g.a[si], g.b[si]) - g.hw[si] < 2.0:
							third_near = true
							break
				if third_near:
					continue
				var a_pts := pts_i.duplicate()
				if best_ei == 0:
					a_pts.reverse()
				var b_pts := pts_j.duplicate()
				if best_ej == 1:
					b_pts.reverse()
				if not a_pts.is_empty() and not b_pts.is_empty() and a_pts[a_pts.size() - 1].distance_to(b_pts[0]) < 0.5:
					b_pts = b_pts.slice(1)
				a_pts.append_array(b_pts)
				var nr := ri.duplicate()
				nr.pts = a_pts
				nr.bridge = bool(ri.bridge) or bool(rj.bridge)
				nxt.append(nr)
				dead[i] = 1
				dead[j] = 1
				joined = true
				merged_any = true
				break
			if not joined:
				nxt.append(ri)
		cur = nxt
		if not merged_any:
			break
	return cur


## 按连通分量清理土路/旷野中的孤立超短程序化铺装残块（与主干道/外框无任何铺装连通、且总铺装长 < 64m，瓦片与战区窗口边界绝对对称）
static func _prune_isolated_paved(roads: Array, inner: Rect2) -> Array:
	var paved_idx: Array = []
	for i in roads.size():
		if not bool(roads[i].dirt):
			paved_idx.append(i)
	if paved_idx.is_empty():
		return roads
	var g := SegGrid.new()
	g.cell = 16.0
	g.reach = 10.0
	for i: int in paved_idx:
		g.add_poly(roads[i].pts, float(roads[i].w) * 0.5, i)
	var adj := {}
	for i: int in paved_idx:
		adj[i] = {}
	for i: int in paved_idx:
		var pts: PackedVector2Array = roads[i].pts
		var hwi := float(roads[i].w) * 0.5
		if pts.size() < 2:
			continue
		var total_s := _poly_len(pts)
		var samples: Array = [pts[0], pts[pts.size() - 1]]
		var step_s := 4.0
		var s := step_s
		var cur_acc := 0.0
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var seg := a.distance_to(b)
			while cur_acc + seg >= s and s < total_s:
				samples.append(a.lerp(b, (s - cur_acc) / maxf(seg, 0.001)))
				s += step_s
			cur_acc += seg
		for q: Vector2 in samples:
			var lst = g.grid.get(Vector2i(floori(q.x / g.cell), floori(q.y / g.cell)))
			if lst == null:
				continue
			for si: int in lst:
				var j: int = g.tag[si]
				if j == i:
					continue
				if seg_dist(q, g.a[si], g.b[si]) <= g.hw[si] + hwi + 0.8:
					adj[i][j] = true
					adj[j][i] = true
	var drop := {}
	var seen := {}
	for i: int in paved_idx:
		if seen.has(i):
			continue
		var comp: Array = []
		var q_bfs: Array = [i]
		seen[i] = true
		var has_preset := false
		var crosses := false
		var tot_len := 0.0
		while not q_bfs.is_empty():
			var u: int = q_bfs.pop_back()
			comp.append(u)
			var ru: Dictionary = roads[u]
			var pts_u: PackedVector2Array = ru.pts
			tot_len += _poly_len(pts_u)
			if not (str(ru.kind) in ["loc", "col", "track"]):
				has_preset = true
			if pts_u.size() >= 2 and (not inner.has_point(pts_u[0]) or not inner.has_point(pts_u[pts_u.size() - 1])):
				crosses = true
			for v: int in adj[u]:
				if not seen.has(v):
					seen[v] = true
					q_bfs.append(v)
		if not has_preset and not crosses and tot_len < 175.0:
			for u: int in comp:
				drop[u] = true
	if drop.is_empty():
		return roads
	var out: Array = []
	for i in roads.size():
		if not drop.has(i):
			out.append(roads[i])
	return out


static func _link_roads(L: Dictionary, roads: Array, clears: Array) -> Array:
	var inner: Rect2 = (L.rect as Rect2).grow(CLIP_PAD - 4.0)
	var presets: Array = []
	var cols: Array = []
	var locs: Array = []
	var tracks: Array = []
	for r: Dictionary in roads:
		match str(r.kind):
			"col":
				cols.append(r)
			"loc":
				locs.append(r)
			"track":
				tracks.append(r)
			_:
				presets.append(r)
	# 同层级按长度降序过滤，保证长路优先保留、两侧瓦片结果对称
	var sort_len_desc := func(a: Dictionary, b: Dictionary) -> bool:
		return _poly_len(a.pts) > _poly_len(b.pts)
	cols.sort_custom(sort_len_desc)
	locs.sort_custom(sort_len_desc)
	tracks.sort_custom(sort_len_desc)
	var g_rail := SegGrid.new()
	g_rail.cell = 20.0
	g_rail.reach = 22.0
	for ri in (L.get("rails", []) as Array).size():
		g_rail.add_poly(L.rails[ri], 2.0, ri)
	var g_paved_preset := SegGrid.new()
	g_paved_preset.cell = 16.0
	g_paved_preset.reach = 28.0
	var g_dirt_preset := SegGrid.new()
	g_dirt_preset.cell = 16.0
	g_dirt_preset.reach = 22.0
	for i in presets.size():
		var pr: Dictionary = presets[i]
		if bool(pr.dirt):
			g_dirt_preset.add_poly(pr.pts, float(pr.w) * 0.5, i)
		else:
			g_paved_preset.add_poly(pr.pts, float(pr.w) * 0.5, i)
	var g_col := SegGrid.new()
	g_col.cell = 16.0
	g_col.reach = 22.0
	var g_loc := SegGrid.new()
	g_loc.cell = 16.0
	g_loc.reach = 22.0
	var g_track := SegGrid.new()
	g_track.cell = 16.0
	g_track.reach = 22.0
	var accepted: Array = presets.duplicate()
	for r: Dictionary in cols:
		var hw := float(r.w) * 0.5
		var pts := _relax_road_kinks(L, r.pts, hw, clears)
		for nr: Dictionary in _strip_parallel_runs(r, pts, func(p: Vector2, td: Vector2) -> bool:
			return _parallel_hit(g_paved_preset, p, td, hw + 18.5, 0.64) \
				or _parallel_hit(g_col, p, td, hw + 11.5, 0.68) \
				or _parallel_hit(g_rail, p, td, hw + 7.5, 0.45), 20.0):
			g_col.add_poly(nr.pts, hw, accepted.size())
			accepted.append(nr)
	for r: Dictionary in locs:
		var hw := float(r.w) * 0.5
		for nr: Dictionary in _strip_parallel_runs(r, r.pts, func(p: Vector2, td: Vector2) -> bool:
			return _parallel_hit(g_paved_preset, p, td, hw + 14.0, 0.66) \
				or _parallel_hit(g_col, p, td, hw + 9.5, 0.68) \
				or _parallel_hit(g_loc, p, td, hw + 7.5, 0.68) \
				or _parallel_hit(g_rail, p, td, hw + 3.6, -1.0), 18.0):
			g_loc.add_poly(nr.pts, hw, accepted.size())
			accepted.append(nr)
	for r: Dictionary in tracks:
		var hw := float(r.w) * 0.5
		var pts := _relax_road_kinks(L, r.pts, hw, clears)
		for nr: Dictionary in _strip_parallel_runs(r, pts, func(p: Vector2, td: Vector2) -> bool:
			return _parallel_hit(g_paved_preset, p, td, hw + 10.0, 0.62) \
				or _parallel_hit(g_dirt_preset, p, td, hw + 10.0, 0.62) \
				or _parallel_hit(g_col, p, td, hw + 10.0, 0.62) \
				or _parallel_hit(g_loc, p, td, hw + 10.0, 0.62) \
				or _parallel_hit(g_track, p, td, hw + 8.5, 0.68) \
				or _parallel_hit(g_rail, p, td, hw + 4.0, -1.0), 24.0):
			g_track.add_poly(nr.pts, hw, accepted.size())
			accepted.append(nr)
	roads = _merge_collinear_proc_roads(accepted)
	for it in 6:
		var g_all := SegGrid.new()
		g_all.cell = 16.0
		g_all.reach = 12.0
		var g_paved := SegGrid.new()
		g_paved.cell = 16.0
		g_paved.reach = 12.0
		for i in roads.size():
			var hw_i := float(roads[i].w) * 0.5
			g_all.add_poly(roads[i].pts, hw_i, i)
			if not bool(roads[i].dirt):
				g_paved.add_poly(roads[i].pts, hw_i, i)
		var keep: Array = []
		var removed := false
		for i in roads.size():
			var r: Dictionary = roads[i]
			var pts: PackedVector2Array = r.pts
			var caps := [false, false]
			var g_target: SegGrid = g_all if bool(r.dirt) else g_paved
			# 首尾相接的环（放射旧城的环路）
			var ring := pts.size() > 8 and pts[0].distance_to(pts[pts.size() - 1]) < float(r.w) * 0.5
			if not ring:
				for e in 2:
					var old_n := pts.size()
					var res: Array = _link_end(L, g_target, i, r, pts, e, inner, clears)
					pts = res[0]
					caps[e] = res[1]
					if pts.size() < old_n:
						removed = true
			r.pts = pts
			r.caps = caps
			var dead := (1 if caps[0] else 0) + (1 if caps[1] else 0)
			var ln := _poly_len(pts)
			var is_proc := str(r.kind) in ["loc", "col", "track"]
			if pts.size() < 2 or (is_proc and ln < 18.0):
				removed = true
				continue
			var has_bridge := false
			if bool(r.bridge):
				for p2: Vector2 in pts:
					if water_dist(p2, true) < 2.0:
						has_bridge = true
						break
			var stub_min: float = float(STUB_MIN_BY_KIND.get(str(r.kind), 135.0))
			if is_proc and ((has_bridge and dead >= 1) or (not has_bridge and ((dead == 2 and ln < ORPHAN_MIN) or (dead == 1 and ln < stub_min)))):
				removed = true
				continue
			keep.append(r)
		roads = keep
		if not removed:
			break
	var pruned := _prune_isolated_paved(roads, inner)
	if pruned.size() < roads.size():
		roads = pruned
		var g2_all := SegGrid.new()
		g2_all.cell = 16.0
		g2_all.reach = 12.0
		var g2_paved := SegGrid.new()
		g2_paved.cell = 16.0
		g2_paved.reach = 12.0
		for i in roads.size():
			var hw2 := float(roads[i].w) * 0.5
			g2_all.add_poly(roads[i].pts, hw2, i)
			if not bool(roads[i].dirt):
				g2_paved.add_poly(roads[i].pts, hw2, i)
		for i in roads.size():
			var r: Dictionary = roads[i]
			var pts: PackedVector2Array = r.pts
			var g2_target: SegGrid = g2_all if bool(r.dirt) else g2_paved
			var ring := pts.size() > 8 and pts[0].distance_to(pts[pts.size() - 1]) < float(r.w) * 0.5
			if not ring:
				var caps := [false, false]
				for e in 2:
					var res: Array = _link_end(L, g2_target, i, r, pts, e, inner, clears)
					pts = res[0]
					caps[e] = res[1]
				r.pts = pts
				r.caps = caps
	roads = _weld_corner_roads(L, roads, inner, clears)
	roads = _smooth_all_road_corners(L, roads, inner, clears)
	return roads


static func _poly_len(pts: PackedVector2Array) -> float:
	var s := 0.0
	for k in pts.size() - 1:
		s += pts[k].distance_to(pts[k + 1])
	return s


## 离 p 最近、且 p 深入它路面至少 depth 米的别的道路线段（跳过 skip 号道路）；没有返回 -1
static func _seg_inside(g: SegGrid, p: Vector2, skip: int, depth: float) -> int:
	var lst = g.grid.get(Vector2i(floori(p.x / g.cell), floori(p.y / g.cell)))
	if lst == null:
		return -1
	var best := INF
	var bi := -1
	for i: int in lst:
		if g.tag[i] == skip:
			continue
		var d := seg_dist(p, g.a[i], g.b[i]) - g.hw[i]
		if d < -depth and d < best:
			best = d
			bi = i
	return bi


## 接路途中不能穿过的地方：有水的河湖、铁路冲突带、遗迹 / 地标 / 撤离点清空圈、悬崖
static func _link_blocked(L: Dictionary, x: Vector2, hw: float, clears: Array) -> bool:
	if water_dist(x, true) < hw + 1.0:
		return true
	if L.has("rail_grid") and (L.rail_grid as SegGrid).edge_dist(x) < hw + 2.2:
		return true
	for cz: Vector3 in clears:
		if x.distance_to(Vector2(cz.x, cz.y)) < cz.z - 2.0 + hw:
			return true
	return dist_at(L, x) == "K"


## 从端点往回剥离小角度压在别的路面上重叠的残段，防止人行道切出长水泥尖刺
static func _peel_parallel_overlap(g: SegGrid, i: int, pts: PackedVector2Array, e: int, hw: float) -> PackedVector2Array:
	var n := pts.size()
	if n < 3:
		return PackedVector2Array()
	var peeled := 0.0
	if e == 0:
		var k := 0
		while k < n - 2 and peeled < 36.0 and _seg_inside(g, pts[k], i, -hw * 0.65) >= 0:
			peeled += pts[k].distance_to(pts[k + 1])
			k += 1
		var out := pts.slice(k)
		return out if out.size() >= 2 and _poly_len(out) >= 18.0 else PackedVector2Array()
	else:
		var k := n - 1
		while k > 1 and peeled < 36.0 and _seg_inside(g, pts[k], i, -hw * 0.65) >= 0:
			peeled += pts[k].distance_to(pts[k - 1])
			k -= 1
		var out := pts.slice(0, k + 1)
		return out if out.size() >= 2 and _poly_len(out) >= 18.0 else PackedVector2Array()


static func _ray_seg_hit(p: Vector2, dir: Vector2, a: Vector2, b: Vector2, max_dist: float) -> Variant:
	var ab := b - a
	if ab.length_squared() < 1e-6 or dir.length_squared() < 1e-6:
		return null
	var hit = Geometry2D.line_intersects_line(p, dir, a, ab)
	if hit == null:
		return null
	var hv: Vector2 = hit
	var u := clampf((hv - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var cp := a + ab * u
	if hv.distance_to(cp) > 0.9:
		return null
	if absf((cp - p).dot(dir)) > max_dist:
		return null
	return cp


static func _trim_overshoot_at_road(g: SegGrid, pts: PackedVector2Array, e: int, target_tag: int, max_walk: float) -> PackedVector2Array:
	var n := pts.size()
	if n < 3:
		return PackedVector2Array()
	var acc := 0.0
	if e == 0:
		for k in range(0, n - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var seg := a.distance_to(b)
			if acc > max_walk:
				break
			var mid := (a + b) * 0.5
			var c0 := Vector2i(floori(mid.x / g.cell), floori(mid.y / g.cell))
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var lst = g.grid.get(Vector2i(c0.x + dx, c0.y + dz))
					if lst == null:
						continue
					for si: int in lst:
						if g.tag[si] != target_tag:
							continue
						var xing = Geometry2D.segment_intersects_segment(a, b, g.a[si], g.b[si])
						if xing != null:
							var xp: Vector2 = xing
							var out := pts.slice(k + 1)
							var out2 := PackedVector2Array([xp])
							out2.append_array(out)
							if out2.size() >= 2 and _poly_len(out2) >= 12.0:
								return out2
							return PackedVector2Array()
			acc += seg
	else:
		for k in range(n - 1, 0, -1):
			var a := pts[k]
			var b := pts[k - 1]
			var seg := a.distance_to(b)
			if acc > max_walk:
				break
			var mid := (a + b) * 0.5
			var c0 := Vector2i(floori(mid.x / g.cell), floori(mid.y / g.cell))
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var lst = g.grid.get(Vector2i(c0.x + dx, c0.y + dz))
					if lst == null:
						continue
					for si: int in lst:
						if g.tag[si] != target_tag:
							continue
						var xing = Geometry2D.segment_intersects_segment(a, b, g.a[si], g.b[si])
						if xing != null:
							var xp: Vector2 = xing
							var out := pts.slice(0, k)
							out.append(xp)
							if out.size() >= 2 and _poly_len(out) >= 12.0:
								return out
							return PackedVector2Array()
			acc += seg
	return PackedVector2Array()


## 处理一端（e = 0 起点 / 1 终点）：返回 [新折线, 是否断头]
static func _link_end(L: Dictionary, g: SegGrid, i: int, r: Dictionary, pts: PackedVector2Array, e: int, inner: Rect2, clears: Array) -> Array:
	var n := pts.size()
	if n < 2:
		return [pts, false]
	var p: Vector2 = pts[0] if e == 0 else pts[n - 1]
	if not inner.has_point(p):
		return [pts, false]
	var q: Vector2 = pts[mini(2, n - 1)] if e == 0 else pts[maxi(n - 3, 0)]
	var t := (p - q).normalized()
	if t == Vector2.ZERO:
		return [pts, false]
	var hw := float(r.w) * 0.5
	# 1. 已经压在别的路面上（或两路面边缘已搭接）：沿来向射线精确交到对方中心线（零折角），若已越过对方中心线冒出半截则精准裁回中心线
	var s := _seg_inside(g, p, i, -hw * 0.85)
	if s >= 0:
		var seg_dir := (g.b[s] - g.a[s]).normalized()
		if absf(t.dot(seg_dir)) >= 0.74:
			if str(r.kind) in ["loc", "col", "track"]:
				return [_peel_parallel_overlap(g, i, pts, e, hw), true]
			return [pts, false]
		if minf(p.distance_to(g.a[s]), p.distance_to(g.b[s])) < 0.8:
			return [pts, false]
		var hit_v = _ray_seg_hit(p, t, g.a[s], g.b[s], g.hw[s] + hw + 4.5)
		var c: Vector2 = hit_v if hit_v != null else Geometry2D.get_closest_point_to_segment(p, g.a[s], g.b[s])
		var proj := (c - p).dot(t)
		var edge_d := p.distance_to(c) - g.hw[s]
		if proj < -0.35 and str(r.kind) in ["loc", "col", "track"]:
			var trimmed := _trim_overshoot_at_road(g, pts, e, g.tag[s], g.hw[s] + hw + 6.0)
			if not trimmed.is_empty():
				return [trimmed, false]
		if p.distance_to(c) > 0.45 and proj > -0.10 and (c - p).normalized().dot(t) > 0.20 and not _link_blocked(L, c, hw, clears):
			return [_extend(pts, e, dense(PackedVector2Array([p, c]), 2.5).slice(1)), false]
		if edge_d <= -0.35:
			return [pts, false]
	# 2. 顺着走向往前找别的路（直行优先，射线交点一步直连到对方中心线，严禁垂直投影制造 Z 形折角）
	var reach: float = LINK_REACH.get(str(r.kind), 10.0)
	for ang: float in [0.0, 0.14, -0.14, 0.28, -0.28, 0.42, -0.42]:
		var dv := t.rotated(ang)
		var d := 1.5
		while d <= reach:
			var x := p + dv * d
			if _link_blocked(L, x, hw, clears):
				break
			var s2 := _seg_inside(g, x, i, 1.0)
			if s2 >= 0 and absf(dv.dot((g.b[s2] - g.a[s2]).normalized())) < 0.74:
				var hit2 = _ray_seg_hit(p, dv, g.a[s2], g.b[s2], reach + g.hw[s2] + 3.0)
				if hit2 != null:
					var h2p: Vector2 = hit2
					if (h2p - p).dot(dv) > 0.45 and not _link_blocked(L, h2p, hw, clears):
						return [_extend(pts, e, dense(PackedVector2Array([p, h2p]), 2.5).slice(1)), false]
				var add := dense(PackedVector2Array([p, x]), 2.5)
				add = add.slice(1)
				var c2 := Geometry2D.get_closest_point_to_segment(x, g.a[s2], g.b[s2])
				if x.distance_to(c2) > 0.6 and (c2 - x).normalized().dot(dv) > 0.15:
					add.append(c2)
				return [_extend(pts, e, add), false]
			d += 1.5
	# 3. 接不上别的路：若从断头往回 TAIL_MAX 米内刚刚穿过一条别的路，把这段冒头的盲肠残尾裁回到路口
	return _trim_dead_tail(g, i, pts, e, TAIL_MAX)


## 平滑 Voronoi 边界支路 / 土路的生硬折角，保持端点不动且不压入水面或清空圈
static func _relax_road_kinks(L: Dictionary, pts: PackedVector2Array, hw: float, clears: Array) -> PackedVector2Array:
	var n := pts.size()
	if n < 5:
		return pts
	var cur := pts.duplicate()
	for _pass in 4:
		var nxt := cur.duplicate()
		for k in range(1, n - 1):
			var mid := (cur[k - 1] + cur[k + 1]) * 0.5
			var cand := cur[k].lerp(mid, 0.48)
			if water_dist(cand, true) >= hw + 2.0 and not _link_blocked(L, cand, hw, clears):
				nxt[k] = cand
		cur = nxt
	return cur


static func _clean_dup_pts(pts: PackedVector2Array, min_d := 0.25) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		if out[out.size() - 1].distance_to(pts[i]) >= min_d:
			out.append(pts[i])
	var last := pts[pts.size() - 1]
	if out.size() >= 2 and out[out.size() - 1].distance_to(last) < min_d:
		out[out.size() - 1] = last
	elif out[out.size() - 1].distance_to(last) >= 1e-4:
		out.append(last)
	return out


static func _poly_s_arr(pts: PackedVector2Array) -> PackedFloat32Array:
	var n := pts.size()
	var s := PackedFloat32Array()
	s.resize(n)
	if n == 0:
		return s
	s[0] = 0.0
	for k in n - 1:
		s[k + 1] = s[k] + pts[k].distance_to(pts[k + 1])
	return s


static func _sample_poly_at_s(pts: PackedVector2Array, s_arr: PackedFloat32Array, target_s: float) -> Array:
	var n := pts.size()
	var total := s_arr[n - 1]
	var s := clampf(target_s, 0.0, total)
	for k in n - 1:
		if s <= s_arr[k + 1] + 1e-5 or k == n - 2:
			var seg := pts[k].distance_to(pts[k + 1])
			var t := (pts[k + 1] - pts[k]) / maxf(seg, 1e-4)
			var u := clampf((s - s_arr[k]) / maxf(seg, 1e-4), 0.0, 1.0)
			return [pts[k].lerp(pts[k + 1], u), k, t]
	var t_end := (pts[n - 1] - pts[n - 2]).normalized()
	return [pts[n - 1], n - 2, t_end]


static func _eval_cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, step := 0.60, force_even := false) -> PackedVector2Array:
	var l_est := (p0.distance_to(p1) + p1.distance_to(p2) + p2.distance_to(p3) + p0.distance_to(p3)) * 0.5
	var t0_dir := (p1 - p0).normalized()
	var t1_dir := (p3 - p2).normalized()
	var turn := acos(clampf(t0_dir.dot(t1_dir), -1.0, 1.0)) if (t0_dir != Vector2.ZERO and t1_dir != Vector2.ZERO) else 0.0
	var n_len := ceili(l_est / maxf(step, 0.20))
	var n_ang := ceili(turn / deg_to_rad(3.2))
	var n_seg := clampi(maxi(6, maxi(n_len, n_ang)), 6, 64)
	if force_even and (n_seg % 2) == 1:
		n_seg += 1
	var out := PackedVector2Array()
	out.resize(n_seg + 1)
	for i in n_seg + 1:
		var u := float(i) / float(n_seg)
		var v := 1.0 - u
		out[i] = (v * v * v) * p0 + (3.0 * v * v * u) * p1 + (3.0 * v * u * u) * p2 + (u * u * u) * p3
	return out


static func _make_corner_bezier(a: Vector2, t_a: Vector2, b: Vector2, t_b: Vector2, step := 0.60, force_even := false) -> PackedVector2Array:
	var chord := a.distance_to(b)
	if chord < 0.35:
		return PackedVector2Array([a, b])
	var cos_th := clampf(t_a.dot(t_b), -0.96, 1.0)
	var theta := acos(cos_th)
	var cos_h := cos(theta * 0.5)
	var k_arc := (4.0 * cos_h) / (3.0 * maxf(0.18, 1.0 + cos_h))
	var h_def := (chord / 3.0) * minf(1.15, 2.0 / maxf(0.5, 1.0 + cos_h))
	var hA := h_def
	var hB := h_def
	if theta >= 0.08 and absf(t_a.cross(t_b)) >= 0.08:
		var v_hit = Geometry2D.line_intersects_line(a, t_a, b, -t_b)
		if v_hit != null:
			var v: Vector2 = v_hit
			var dA := (v - a).dot(t_a)
			var dB := (b - v).dot(t_b)
			if dA > 0.22 * chord and dA < 2.2 * chord and dB > 0.22 * chord and dB < 2.2 * chord:
				hA = dA * k_arc
				hB = dB * k_arc
	return _eval_cubic_bezier(a, a + t_a * hA, b - t_b * hB, b, step, force_even)


static func _arc_ok(L: Dictionary, pts: PackedVector2Array, hw: float, bridge: bool, clears: Array) -> bool:
	for q: Vector2 in pts:
		if _link_blocked(L, q, hw, clears):
			return false
		if not bridge and water_dist(q, false) < hw + 1.2:
			return false
	return true


static func _fillet_closed_ring(verts: PackedVector2Array, radius: float, step := 0.70) -> PackedVector2Array:
	var n := verts.size()
	if n < 3:
		return verts
	var out := PackedVector2Array()
	for i in n:
		var prev := verts[(i - 1 + n) % n]
		var curr := verts[i]
		var nxt := verts[(i + 1) % n]
		var la := prev.distance_to(curr)
		var lb := curr.distance_to(nxt)
		if la < 0.5 or lb < 0.5:
			out.append(curr)
			continue
		var u_in := (curr - prev) / la
		var u_out := (nxt - curr) / lb
		var theta := acos(clampf(u_in.dot(u_out), -0.96, 1.0))
		if theta < deg_to_rad(2.5):
			out.append(curr)
			continue
		var d := minf(radius * tan(theta * 0.5), minf(la, lb) * 0.40)
		var a := curr - u_in * d
		var b := curr + u_out * d
		var arc := _make_corner_bezier(a, u_in, b, u_out, step, false)
		for pt: Vector2 in arc:
			if out.is_empty() or out[out.size() - 1].distance_to(pt) > 0.08:
				out.append(pt)
	if out.size() >= 2 and out[0].distance_to(out[out.size() - 1]) > 0.05:
		out.append(out[0])
	return out


static func _end_tangent_in(pts: PackedVector2Array, e: int) -> Vector2:
	var n := pts.size()
	if n < 2:
		return Vector2.ZERO
	var p_end := pts[0] if e == 0 else pts[n - 1]
	var acc := 0.0
	var ref := p_end
	if e == 0:
		for k in range(0, n - 1):
			acc += pts[k].distance_to(pts[k + 1])
			ref = pts[k + 1]
			if acc >= 4.5:
				break
	else:
		for k in range(n - 1, 0, -1):
			acc += pts[k].distance_to(pts[k - 1])
			ref = pts[k - 1]
			if acc >= 4.5:
				break
	return (p_end - ref).normalized()


static func _self_interior_near(pts: PackedVector2Array, e: int, jp: Vector2, hw: float) -> bool:
	var n := pts.size()
	if n < 4:
		return false
	var skip_dist := maxf(14.0, hw * 3.0)
	var acc := 0.0
	if e == 0:
		for k in range(0, n - 1):
			var seg := pts[k].distance_to(pts[k + 1])
			if acc >= skip_dist and seg_dist(jp, pts[k], pts[k + 1]) - hw < 2.6:
				return true
			acc += seg
	else:
		for k in range(n - 1, 0, -1):
			var seg := pts[k].distance_to(pts[k - 1])
			if acc >= skip_dist and seg_dist(jp, pts[k - 1], pts[k]) - hw < 2.6:
				return true
			acc += seg
	return false


static func _trim_past_vertex_back(pts: PackedVector2Array, v: Vector2, t_arr: Vector2, max_back: float) -> PackedVector2Array:
	var n := pts.size()
	if n < 2:
		return pts
	var acc := 0.0
	var keep := n - 1
	while keep > 0 and acc < max_back:
		if (pts[keep] - v).dot(t_arr) <= -0.25:
			break
		acc += pts[keep].distance_to(pts[keep - 1])
		keep -= 1
	var out := pts.slice(0, keep + 1)
	if out.is_empty():
		out.append(pts[0])
	if out[out.size() - 1].distance_to(v) > 0.15:
		out.append(v)
	return _clean_dup_pts(out, 0.20)


static func _trim_past_vertex_fwd(pts: PackedVector2Array, v: Vector2, t_dep: Vector2, max_fwd: float) -> PackedVector2Array:
	var n := pts.size()
	if n < 2:
		return pts
	var acc := 0.0
	var start := 0
	while start < n - 1 and acc < max_fwd:
		if (pts[start] - v).dot(t_dep) >= 0.25:
			break
		acc += pts[start].distance_to(pts[start + 1])
		start += 1
	var out := PackedVector2Array([v])
	for k in range(start, n):
		if out[out.size() - 1].distance_to(pts[k]) > 0.15:
			out.append(pts[k])
	return _clean_dup_pts(out, 0.20)


static func _weld_corner_roads(L: Dictionary, roads: Array, inner: Rect2, clears: Array) -> Array:
	const KIND_PRI := {"track": 0, "loc": 1, "col": 2, "art": 3, "hwy": 4}
	var cur: Array = roads.duplicate()
	for _pass in 8:
		var g := SegGrid.new()
		g.cell = 16.0
		g.reach = 12.0
		for i in cur.size():
			g.add_poly(cur[i].pts, float(cur[i].w) * 0.5, i)
		var cands: Array = []
		for i in cur.size():
			var ri: Dictionary = cur[i]
			var pts_i: PackedVector2Array = ri.pts
			var wi := float(ri.w)
			var ring_i := pts_i.size() > 8 and pts_i[0].distance_to(pts_i[pts_i.size() - 1]) < wi * 0.5
			if pts_i.size() < 2 or ring_i:
				continue
			for j in range(i + 1, cur.size()):
				var rj: Dictionary = cur[j]
				if bool(ri.dirt) != bool(rj.dirt):
					continue
				var pts_j: PackedVector2Array = rj.pts
				var wj := float(rj.w)
				var ring_j := pts_j.size() > 8 and pts_j[0].distance_to(pts_j[pts_j.size() - 1]) < wj * 0.5
				if pts_j.size() < 2 or ring_j:
					continue
				var reach_d := maxf(wi, wj) * 0.5 + 2.6
				var best_d := reach_d
				var best_ei := -1
				var best_ej := -1
				for ei in 2:
					var pi: Vector2 = pts_i[0] if ei == 0 else pts_i[pts_i.size() - 1]
					var wei := float(ri.get("w0", wi)) if ei == 0 else float(ri.get("w1", wi))
					if absf(wei - wi) > 0.05:
						continue
					for ej in 2:
						var pj: Vector2 = pts_j[0] if ej == 0 else pts_j[pts_j.size() - 1]
						var wej := float(rj.get("w0", wj)) if ej == 0 else float(rj.get("w1", wj))
						if absf(wej - wj) > 0.05:
							continue
						var d := pi.distance_to(pj)
						if d < best_d:
							best_d = d
							best_ei = ei
							best_ej = ej
				if best_ei < 0:
					continue
				var pi: Vector2 = pts_i[0] if best_ei == 0 else pts_i[pts_i.size() - 1]
				var pj: Vector2 = pts_j[0] if best_ej == 0 else pts_j[pts_j.size() - 1]
				var jp := (pi + pj) * 0.5
				if not inner.has_point(jp):
					continue
				var t_arr := _end_tangent_in(pts_i, best_ei)
				var t_dep := -_end_tangent_in(pts_j, best_ej)
				if t_arr == Vector2.ZERO or t_dep == Vector2.ZERO or t_arr.dot(t_dep) < -0.65:
					continue
				var blocked3 := _self_interior_near(pts_i, best_ei, jp, wi * 0.5) or _self_interior_near(pts_j, best_ej, jp, wj * 0.5)
				if not blocked3:
					var c0 := Vector2i(floori(jp.x / g.cell), floori(jp.y / g.cell))
					for dz in range(-1, 2):
						for dx in range(-1, 2):
							var lst = g.grid.get(Vector2i(c0.x + dx, c0.y + dz))
							if lst == null:
								continue
							for si: int in lst:
								var tg := g.tag[si]
								if tg != i and tg != j:
									var md := minf(seg_dist(jp, g.a[si], g.b[si]), minf(seg_dist(pi, g.a[si], g.b[si]), seg_dist(pj, g.a[si], g.b[si])))
									if md - g.hw[si] < 2.8:
										blocked3 = true
										break
							if blocked3:
								break
						if blocked3:
							break
				if not blocked3:
					cands.append([snappedf(best_d, 0.05), snappedf(jp.x, 0.1), snappedf(jp.y, 0.1), i, best_ei, j, best_ej])
		if cands.is_empty():
			break
		cands.sort_custom(func(a: Array, b: Array) -> bool:
			if a[0] != b[0]:
				return a[0] < b[0]
			if a[1] != b[1]:
				return a[1] < b[1]
			return a[2] < b[2]
		)
		var touched := PackedByteArray()
		touched.resize(cur.size())
		var dead := PackedByteArray()
		dead.resize(cur.size())
		var added: Array = []
		var changed := false
		for cd: Array in cands:
			var i: int = cd[3]
			var ei: int = cd[4]
			var j: int = cd[5]
			var ej: int = cd[6]
			if touched[i] == 1 or touched[j] == 1:
				continue
			var ri: Dictionary = cur[i]
			var rj: Dictionary = cur[j]
			var wi := float(ri.w)
			var wj := float(rj.w)
			var a_pts: PackedVector2Array = ri.pts.duplicate()
			var caps_i: Array = ri.get("caps", [false, false])
			var cap_a0: bool = bool(caps_i[1]) if ei == 0 else bool(caps_i[0])
			var w_a0: float = float(ri.get("w1", wi)) if ei == 0 else float(ri.get("w0", wi))
			if ei == 0:
				a_pts.reverse()
			var b_pts: PackedVector2Array = rj.pts.duplicate()
			var caps_j: Array = rj.get("caps", [false, false])
			var cap_b1: bool = bool(caps_j[0]) if ej == 1 else bool(caps_j[1])
			var w_b1: float = float(rj.get("w0", wj)) if ej == 1 else float(rj.get("w1", wj))
			if ej == 1:
				b_pts.reverse()
			var pi := a_pts[a_pts.size() - 1]
			var pj := b_pts[0]
			var jp := (pi + pj) * 0.5
			var t_arr := _end_tangent_in(a_pts, 1)
			var t_dep := -_end_tangent_in(b_pts, 0)
			var v := jp
			var max_w := maxf(wi, wj)
			if absf(t_arr.cross(t_dep)) >= 0.15:
				var vh = Geometry2D.line_intersects_line(pi, t_arr, pj, -t_dep)
				if vh != null:
					var vp: Vector2 = vh
					if vp.distance_to(jp) <= max_w * 1.6 and (vp - pi).dot(t_arr) > -max_w and (pj - vp).dot(t_dep) > -max_w and not _link_blocked(L, vp, max_w * 0.5, clears):
						v = vp
			var a_base := _trim_past_vertex_back(a_pts, v, t_arr, max_w * 1.8)
			var b_base := _trim_past_vertex_fwd(b_pts, v, t_dep, max_w * 1.8)
			var bridge := bool(ri.bridge) or bool(rj.bridge)
			var keep_arcs: Array = []
			keep_arcs.append_array(ri.get("_keep_arcs", []))
			keep_arcs.append_array(rj.get("_keep_arcs", []))
			if absf(wi - wj) <= 0.6:
				var stitched := a_base.duplicate()
				stitched.append_array(b_base.slice(1))
				stitched = _clean_dup_pts(stitched, 0.25)
				if stitched.size() < 2:
					continue
				var ki := str(ri.kind)
				var kj := str(rj.kind)
				var k_best := ki if int(KIND_PRI.get(ki, 0)) >= int(KIND_PRI.get(kj, 0)) else kj
				var nr := ri.duplicate()
				nr.pts = stitched
				nr.w = max_w
				nr.w0 = w_a0
				nr.w1 = w_b1
				nr.kind = k_best
				nr.bridge = bridge
				nr.caps = [cap_a0, cap_b1]
				if not keep_arcs.is_empty():
					nr._keep_arcs = keep_arcs
				if str(nr.get("name", "")) == "" and str(rj.get("name", "")) != "":
					nr.name = rj.name
				added.append(nr)
				dead[i] = 1
				dead[j] = 1
				touched[i] = 1
				touched[j] = 1
				changed = true
			else:
				var sa := _poly_s_arr(a_base)
				var sb := _poly_s_arr(b_base)
				var la := sa[sa.size() - 1]
				var lb := sb[sb.size() - 1]
				var min_arm := minf(la * 0.42, lb * 0.42)
				if min_arm < 2.2:
					continue
				var theta := acos(clampf(t_arr.dot(t_dep), -0.95, 1.0))
				var r_t := maxf(max_w * 1.15, 9.0)
				var d_base := clampf(r_t * tan(theta * 0.5), 4.5, minf(min_arm, 22.0)) if theta >= 0.20 else minf(7.0, min_arm)
				var arc := PackedVector2Array()
				var d_used := 0.0
				var samp_a := []
				var samp_b := []
				for sc: float in [1.0, 0.65, 0.40, 0.22]:
					var dt := d_base * sc
					if dt < 1.8:
						continue
					var sa_res := _sample_poly_at_s(a_base, sa, la - dt)
					var sb_res := _sample_poly_at_s(b_base, sb, dt)
					var cand_arc := _make_corner_bezier(sa_res[0], sa_res[2], sb_res[0], sb_res[2], 0.60, true)
					if _arc_ok(L, cand_arc, max_w * 0.5, bridge, clears):
						arc = cand_arc
						d_used = dt
						samp_a = sa_res
						samp_b = sb_res
						break
				if arc.size() < 3:
					continue
				var mid_idx := (arc.size() - 1) / 2
				var m_pt := arc[mid_idx]
				var segA: int = samp_a[1]
				var new_a := a_base.slice(0, segA + 1)
				for k in range(0, mid_idx + 1):
					if new_a.is_empty() or new_a[new_a.size() - 1].distance_to(arc[k]) > 0.08:
						new_a.append(arc[k])
				if new_a[new_a.size() - 1].distance_to(m_pt) > 0.04:
					new_a.append(m_pt)
				else:
					new_a[new_a.size() - 1] = m_pt
				var segB: int = samp_b[1]
				var new_b := PackedVector2Array()
				for k in range(mid_idx, arc.size()):
					if new_b.is_empty() or new_b[new_b.size() - 1].distance_to(arc[k]) > 0.08:
						new_b.append(arc[k])
				for k in range(segB + 1, b_base.size()):
					if new_b[new_b.size() - 1].distance_to(b_base[k]) > 0.08:
						new_b.append(b_base[k])
				var w_mid := 0.5 * (wi + wj)
				var ka := keep_arcs.duplicate()
				ka.append([m_pt, maxf(d_used, 5.0) + 1.5])
				var nr_a := ri.duplicate()
				nr_a.pts = new_a
				nr_a.w0 = w_a0
				nr_a.w1 = w_mid
				nr_a.caps = [cap_a0, false]
				nr_a._keep_arcs = ka
				var nr_b := rj.duplicate()
				nr_b.pts = new_b
				nr_b.w0 = w_mid
				nr_b.w1 = w_b1
				nr_b.caps = [false, cap_b1]
				nr_b._keep_arcs = ka
				cur[i] = nr_a
				cur[j] = nr_b
				touched[i] = 1
				touched[j] = 1
				changed = true
		var nxt: Array = []
		for i in cur.size():
			if dead[i] == 0:
				nxt.append(cur[i])
		nxt.append_array(added)
		cur = nxt
		if not changed:
			break
	return cur


static func _smooth_all_road_corners(L: Dictionary, roads: Array, inner: Rect2, clears: Array) -> Array:
	for r: Dictionary in roads:
		var keep_arcs: Array = r.get("_keep_arcs", [])
		r.erase("_keep_arcs")
		var pts := _clean_dup_pts(r.pts, 0.20)
		if pts.size() < 3:
			r.pts = pts
			continue
		var w := float(r.w)
		var hw := w * 0.5
		var bridge := bool(r.bridge)
		var ring := pts.size() > 8 and pts[0].distance_to(pts[pts.size() - 1]) < 1.0
		if ring:
			var max_ang := 0.0
			var body := pts.slice(0, pts.size() - 1)
			var m := body.size()
			for i in m:
				var a := body[(i - 1 + m) % m]
				var b := body[i]
				var c := body[(i + 1) % m]
				var d0 := (b - a).normalized()
				var d1 := (c - b).normalized()
				if d0 != Vector2.ZERO and d1 != Vector2.ZERO:
					max_ang = maxf(max_ang, acos(clampf(d0.dot(d1), -1.0, 1.0)))
			if max_ang >= deg_to_rad(3.0):
				var r_t := 8.0 if w < 8.0 else (11.0 if w < 10.5 else 15.5)
				var fil := _fillet_closed_ring(body, r_t, 0.70)
				if _arc_ok(L, fil, hw, bridge, clears):
					r.pts = fil
			continue
		var s_arr := _poly_s_arr(pts)
		var n := pts.size()
		var total := s_arr[n - 1]
		if total < 8.0:
			r.pts = pts
			continue
		var w0 := float(r.get("w0", w))
		var w1 := float(r.get("w1", w))
		var pin_start := 2.0 if absf(w0 - w) > 0.05 else 0.4
		var pin_end := 2.0 if absf(w1 - w) > 0.05 else 0.4
		var v_angs := PackedFloat32Array()
		var v_crs := PackedFloat32Array()
		v_angs.resize(n)
		v_crs.resize(n)
		for k in range(1, n - 1):
			var d0 := (pts[k] - pts[k - 1]).normalized()
			var d1 := (pts[k + 1] - pts[k]).normalized()
			if d0 != Vector2.ZERO and d1 != Vector2.ZERO:
				v_angs[k] = acos(clampf(d0.dot(d1), -1.0, 1.0))
				v_crs[k] = d0.cross(d1)
		var bends: Array = []
		for k in range(1, n - 1):
			if s_arr[k] < pin_start or total - s_arr[k] < pin_end:
				continue
			var in_kept := false
			for ka: Array in keep_arcs:
				if pts[k].distance_to(ka[0]) < float(ka[1]):
					in_kept = true
					break
			if in_kept:
				continue
			var ang_v := v_angs[k]
			var ang_w := 0.0
			var l_prev := pts[k - 1].distance_to(pts[k])
			var l_next := pts[k].distance_to(pts[k + 1])
			if minf(l_prev, l_next) < 2.6:
				var sb := _sample_poly_at_s(pts, s_arr, maxf(0.0, s_arr[k] - 2.5))
				var sf := _sample_poly_at_s(pts, s_arr, minf(total, s_arr[k] + 2.5))
				var t_b := (pts[k] - (sb[0] as Vector2)).normalized()
				var t_f := ((sf[0] as Vector2) - pts[k]).normalized()
				if t_b != Vector2.ZERO and t_f != Vector2.ZERO:
					ang_w = acos(clampf(t_b.dot(t_f), -1.0, 1.0))
			var prev_ang := v_angs[k - 1]
			var next_ang := v_angs[k + 1]
			var iso_mild := ang_v >= deg_to_rad(1.8) and (minf(prev_ang, next_ang) < minf(ang_v * 0.45, deg_to_rad(1.0)) or minf(prev_ang, next_ang) < deg_to_rad(0.6) or maxf(l_prev, l_next) >= 4.2)
			if ang_v >= deg_to_rad(7.5) or ang_w >= deg_to_rad(12.0) or iso_mild:
				bends.append(k)
		if bends.is_empty():
			r.pts = pts
			continue
		var spans: Array = []
		var k_lo: int = bends[0]
		var k_hi: int = bends[0]
		for bi in range(1, bends.size()):
			var kb: int = bends[bi]
			if s_arr[kb] - s_arr[k_hi] < 6.5 and s_arr[kb] - s_arr[k_lo] <= 14.0 and v_crs[kb] * v_crs[k_hi] >= -1e-4:
				k_hi = kb
			else:
				spans.append([k_lo, k_hi])
				k_lo = kb
				k_hi = kb
		spans.append([k_lo, k_hi])
		var active: Array = []
		var r_t := 8.0 if w < 8.0 else (11.0 if w < 10.5 else 15.5)
		for sp: Array in spans:
			var klo: int = sp[0]
			var khi: int = sp[1]
			var kmid := (klo + khi) / 2
			if not inner.has_point(pts[kmid]):
				continue
			var s_lo := s_arr[klo]
			var s_hi := s_arr[khi]
			var s_mid := 0.5 * (s_lo + s_hi)
			var half_span := 0.5 * (s_hi - s_lo)
			var tin_s := _sample_poly_at_s(pts, s_arr, maxf(0.0, s_lo - 4.0))
			var tout_s := _sample_poly_at_s(pts, s_arr, minf(total, s_hi + 4.0))
			var theta := acos(clampf((tin_s[2] as Vector2).dot(tout_s[2] as Vector2), -0.96, 1.0))
			var half_des := clampf(maxf(r_t * tan(theta * 0.5), half_span + 3.0), half_span + 1.5, 22.0)
			active.append([klo, khi, s_mid, maxf(pin_start, s_mid - half_des), minf(total - pin_end, s_mid + half_des)])
		if active.is_empty():
			r.pts = pts
			continue
		for ai in active.size() - 1:
			var cur_sp: Array = active[ai]
			var nxt_sp: Array = active[ai + 1]
			var sb_c: float = cur_sp[4]
			var sa_n: float = nxt_sp[3]
			if sb_c > sa_n - 0.5:
				var split_s := 0.5 * (float(cur_sp[2]) + float(nxt_sp[2]))
				var s_hi_prev := s_arr[int(cur_sp[1])]
				var s_lo_next := s_arr[int(nxt_sp[0])]
				if s_hi_prev + 0.6 < s_lo_next - 0.6:
					split_s = clampf(split_s, s_hi_prev + 0.6, s_lo_next - 0.6)
				cur_sp[4] = minf(sb_c, split_s - 0.25)
				nxt_sp[3] = maxf(sa_n, split_s + 0.25)
		var splices: Array = []
		for sp: Array in active:
			var s_lo := s_arr[int(sp[0])]
			var s_hi := s_arr[int(sp[1])]
			var sa_lim := float(sp[3])
			var sb_lim := float(sp[4])
			if sb_lim - sa_lim < 2.2 or sa_lim >= s_lo - 0.25 or sb_lim <= s_hi + 0.25:
				continue
			var arm_l := s_lo - sa_lim
			var arm_r := sb_lim - s_hi
			for sc: float in [1.0, 0.70, 0.45, 0.25]:
				var sa_t := s_lo - arm_l * sc
				var sb_t := s_hi + arm_r * sc
				if sa_t > s_lo - 0.45 or sb_t < s_hi + 0.45:
					continue
				var samp_a := _sample_poly_at_s(pts, s_arr, sa_t)
				var samp_b := _sample_poly_at_s(pts, s_arr, sb_t)
				var arc := _make_corner_bezier(samp_a[0], samp_a[2], samp_b[0], samp_b[2], 0.60, false)
				if _arc_ok(L, arc, hw, bridge, clears):
					splices.append([sa_t, sb_t, arc])
					break
		if splices.is_empty():
			r.pts = pts
			continue
		var out := PackedVector2Array([pts[0]])
		var cur_s := 0.0
		var v_idx := 1
		for sp: Array in splices:
			var sa_t: float = sp[0]
			var sb_t: float = sp[1]
			var arc: PackedVector2Array = sp[2]
			while v_idx < n - 1 and s_arr[v_idx] <= sa_t + 0.05:
				if s_arr[v_idx] > cur_s + 0.05 and out[out.size() - 1].distance_to(pts[v_idx]) > 0.08:
					out.append(pts[v_idx])
				v_idx += 1
			for pt: Vector2 in arc:
				if out[out.size() - 1].distance_to(pt) > 0.08:
					out.append(pt)
			while v_idx < n - 1 and s_arr[v_idx] < sb_t - 0.05:
				v_idx += 1
			cur_s = sb_t
		while v_idx < n - 1:
			if out[out.size() - 1].distance_to(pts[v_idx]) > 0.08:
				out.append(pts[v_idx])
			v_idx += 1
		out.append(pts[n - 1])
		r.pts = _clean_dup_pts(out, 0.08)
	return roads


static func _trim_dead_tail(g: SegGrid, i: int, pts: PackedVector2Array, e: int, max_tail: float) -> Array:
	var n := pts.size()
	var dist := 0.0
	var wet_end := water_dist(pts[0] if e == 0 else pts[n - 1], true) <= 6.0
	if e == 0:
		for k in range(0, n - 1):
			if k > 0:
				dist += pts[k - 1].distance_to(pts[k])
			if dist > max_tail or (not wet_end and water_dist(pts[k], true) < 0.0):
				break
			var s := _seg_inside(g, pts[k], i, -0.35)
			if s < 0 and k > 0:
				s = _seg_inside(g, (pts[k - 1] + pts[k]) * 0.5, i, -0.45)
			if s >= 0:
				var k2 := k
				while k2 + 1 < n - 1 and _seg_inside(g, pts[k2 + 1], i, -0.35) >= 0:
					k2 += 1
				var sb := _seg_inside(g, pts[k2], i, -0.35)
				if sb < 0:
					sb = s
				var trimmed := pts.slice(k2)
				trimmed[0] = Geometry2D.get_closest_point_to_segment(trimmed[0], g.a[sb], g.b[sb])
				if trimmed.size() < 2 or _poly_len(trimmed) < 15.0:
					return [PackedVector2Array(), true]
				return [trimmed, false]
	else:
		for k in range(n - 1, 0, -1):
			if k < n - 1:
				dist += pts[k + 1].distance_to(pts[k])
			if dist > max_tail or (not wet_end and water_dist(pts[k], true) < 0.0):
				break
			var s := _seg_inside(g, pts[k], i, -0.35)
			if s < 0 and k < n - 1:
				s = _seg_inside(g, (pts[k] + pts[k + 1]) * 0.5, i, -0.45)
			if s >= 0:
				var k2 := k
				while k2 - 1 > 0 and _seg_inside(g, pts[k2 - 1], i, -0.35) >= 0:
					k2 -= 1
				var sb := _seg_inside(g, pts[k2], i, -0.35)
				if sb < 0:
					sb = s
				var trimmed := pts.slice(0, k2 + 1)
				trimmed[trimmed.size() - 1] = Geometry2D.get_closest_point_to_segment(trimmed[trimmed.size() - 1], g.a[sb], g.b[sb])
				if trimmed.size() < 2 or _poly_len(trimmed) < 15.0:
					return [PackedVector2Array(), true]
				return [trimmed, false]
	return [pts, true]


## 在折线起点（e = 0，add 按由近到远的顺序）或终点接上一串点
static func _extend(pts: PackedVector2Array, e: int, add: PackedVector2Array) -> PackedVector2Array:
	if e == 1:
		var out := pts.duplicate()
		out.append_array(add)
		return out
	var rev := add.duplicate()
	rev.reverse()
	rev.append_array(pts)
	return rev


## 格网街区：旋转格网的街道 + 街块（凸多边形）
static func _grid_streets(L: Dictionary, nb: Dictionary, roads: Array, blocks: Array, clears: Array) -> void:
	var poly: PackedVector2Array = nb.poly
	var ang: float = nb.ang
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-sin(ang), cos(ang))
	var s: Vector2 = nb.seed
	var sp: Vector2 = nb.sp
	var ph: Vector2 = nb.ph
	# 多边形在 (u, v) 坐标系里的范围
	var umin := INF
	var umax := -INF
	var vmin := INF
	var vmax := -INF
	for p in poly:
		var d := p - s
		umin = minf(umin, d.dot(u))
		umax = maxf(umax, d.dot(u))
		vmin = minf(vmin, d.dot(v))
		vmax = maxf(vmax, d.dot(v))
	var u0 := floorf((umin - ph.x * sp.x) / sp.x) * sp.x + ph.x * sp.x
	var v0 := floorf((vmin - ph.y * sp.y) / sp.y) * sp.y + ph.y * sp.y
	var draw: bool = nb.kind == "grid"
	if draw:
		# 沿 v 方向的街道（u = 常数）与沿 u 方向的街道（v = 常数）
		var uu := u0
		while uu <= umax:
			_street_in(L, poly, s + u * uu - v * 400.0, s + u * uu + v * 400.0, roads, clears)
			uu += sp.x
		var vv := v0
		while vv <= vmax:
			_street_in(L, poly, s + v * vv - u * 400.0, s + v * vv + u * 400.0, roads, clears)
			vv += sp.y
	# 街块：格网单元 ∩ 街区（内缩 6.5 米给支路）
	var inner := nb_inner(nb)
	if inner.size() < 3:
		return
	var uu2 := u0
	while uu2 < umax:
		var vv2 := v0
		while vv2 < vmax:
			var cellp := PackedVector2Array([s + u * uu2 + v * vv2, s + u * (uu2 + sp.x) + v * vv2, s + u * (uu2 + sp.x) + v * (vv2 + sp.y), s + u * uu2 + v * (vv2 + sp.y)])
			cellp = inset(cellp, 3.6 if draw else 0.8)
			if cellp.size() >= 3:
				var bp := clip_convex(cellp, inner)
				var sub := 0
				for piece: PackedVector2Array in _split_by_art(bp):
					var ext_p := _extent(piece, ang)
					if piece.size() >= 3 and poly_area(piece) > 105.0 and minf(ext_p.x, ext_p.y) >= 7.2:
						var ch := _block_char(L, piece)
						if ch != "":
							blocks.append({"poly": piece, "ch": ch, "ang": ang, "kind": nb.kind, "nb": nb.k, "id": Vector3i(nb.k.x, nb.k.y, roundi(uu2 * 7.0 + vv2 * 131.0) * 4 + sub)})
					sub += 1
			vv2 += sp.y
		uu2 += sp.x


## 街块的区块字符：中心点是城区就取它；否则在块里抽样，城区点过半时取最多的城区字符（压在区块边界上的街块不再整块丢掉）；
## 不算城区返回 ""
static func _block_char(L: Dictionary, piece: PackedVector2Array) -> String:
	var c := centroid(piece)
	var ch := dist_at(L, c)
	if ch in URBAN:
		return ch
	var cnt := {}
	var urb := 0
	var tot := 0
	for q in piece:
		for t: float in [0.35, 0.7]:
			var s := dist_at(L, c.lerp(q, t))
			tot += 1
			if s in URBAN:
				urb += 1
				cnt[s] = int(cnt.get(s, 0)) + 1
	if tot == 0 or urb * 2 < tot:
		return ""
	var best := ""
	for k: String in cnt:
		if best == "" or cnt[k] > cnt[best]:
			best = k
	return best


## 主干道 / 滨河路、铁路、河道穿过街块时，沿它的局部切线把街块切成两侧（让出半个宽度 + 留边），每种最多切四次
static func _split_by_art(poly: PackedVector2Array) -> Array:
	if poly.size() < 3:
		return []
	var f := features()
	var out: Array = [poly]
	for cut: Array in [[f.art, 2.2, 2.0], [f.rail, 2.4, 4.5], [f.water, 3.0, 5.0]]:
		var nxt: Array = []
		for pp: PackedVector2Array in out:
			nxt.append_array(_split_by(pp, cut[0], cut[1], cut[2]))
		out = nxt
	return out


static func _split_by(poly: PackedVector2Array, g: SegGrid, extra: float, pad: float) -> Array:
	# 快速排除：街块外接矩形覆盖的格子里没有任何段
	var br := _poly_rect(poly)
	var any := false
	for gz in range(floori(br.position.y / g.cell), floori(br.end.y / g.cell) + 1):
		for gx in range(floori(br.position.x / g.cell), floori(br.end.x / g.cell) + 1):
			if g.grid.has(Vector2i(gx, gz)):
				any = true
				break
		if any:
			break
	if not any:
		return [poly]
	var todo: Array = [[poly, 0]]
	var out: Array = []
	while not todo.is_empty():
		var it: Array = todo.pop_back()
		var pp: PackedVector2Array = it[0]
		var hit := -1
		var c := centroid(pp)
		var probe: Array = Array(pp)
		probe.append(c)
		for i in pp.size():
			probe.append((pp[i] + pp[(i + 1) % pp.size()]) * 0.5)
			probe.append(c.lerp(pp[i], 0.5))
		var best := INF
		for q: Vector2 in probe:
			var si := g.nearest(q, pad)
			if si >= 0:
				var d := seg_dist(q, g.a[si], g.b[si]) - g.hw[si]
				if d < best:
					best = d
					hit = si
		if hit < 0 or int(it[1]) >= 4:
			out.append(pp)
			continue
		var a: Vector2 = g.a[hit]
		var e: Vector2 = (g.b[hit] - a).normalized()
		var n := Vector2(-e.y, e.x)
		var off: float = g.hw[hit] + extra
		var pieces: Array = []
		for sgn: float in [1.0, -1.0]:
			var piece := clip_half(pp, a + n * off * sgn, n * sgn)
			if piece.size() >= 3 and poly_area(piece) > 40.0:
				pieces.append(piece)
		if pieces.size() == 1 and absf(poly_area(pieces[0]) - poly_area(pp)) < 1.0:
			out.append(pp)     # 切线没碰到这块
			continue
		for piece in pieces:
			todo.append([piece, int(it[1]) + 1])
	return out


## 一条直线与凸多边形的交段，加密后过滤成街道
static func _street_in(L: Dictionary, poly: PackedVector2Array, a: Vector2, b: Vector2, roads: Array, clears: Array) -> void:
	var t0 := 0.0
	var t1 := 1.0
	var m := poly.size()
	var ccw := poly_area_signed(poly) > 0.0
	var d := b - a
	for i in m:
		var p := poly[i]
		var e := poly[(i + 1) % m] - p
		var n := Vector2(-e.y, e.x) if ccw else Vector2(e.y, -e.x)
		var num := (a - p).dot(n)
		var den := d.dot(n)
		if absf(den) < 1e-6:
			if num < 0.0:
				return
			continue
		var t := -num / den
		if den > 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 >= t1:
			return
	var pa := a + d * t0
	var pb := a + d * t1
	if pa.distance_to(pb) < 12.0:
		return
	var big: Rect2 = (L.rect as Rect2).grow(CLIP_PAD)
	for run in _filter_road(L, dense(PackedVector2Array([pa, pb]), 3.0), "loc", 7.0, clears):
		for cr in _clip_rect(run, big):
			if _poly_len(cr) >= 12.0:
				roads.append({"pts": cr, "w": 7.0, "dirt": false, "kind": "loc", "bridge": false})


## 历史港口旧城街网节点：用不规则折线环街代替规整同心圆，既保留老城向心骨架又彻底消除圆规感
static func _radial_pt(c: Vector2, r: float, si: int, ns: int) -> Vector2:
	var idx := ((si % ns) + ns) % ns
	var a := TAU * (idx + 0.5) / ns + 0.08 * sin(float(idx) * 2.3 + 0.6)
	var rr := r * (1.0 + 0.11 * sin(float(idx) * 1.7 + r * 0.025) - 0.07 * cos(float(idx) * 2.9 - 0.4))
	return c + Vector2(cos(a), sin(a)) * rr


## 放射旧城：折线林荫环街 + 辐射街（只铺在 radial 街区里，无圆弧）
static func _radial_streets(L: Dictionary, rc: Dictionary, roads: Array, clears: Array) -> void:
	var c := Vector2(rc.c[0], rc.c[1])
	var rr: float = rc.r
	if not L.rect.grow(CLIP_PAD).intersects(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0)):
		return
	var ns: int = rc.spokes
	var lines: Array = []
	for r: float in rc.rings:
		var ring_ctrl := PackedVector2Array()
		for i in ns:
			ring_ctrl.append(_radial_pt(c, r, i, ns))
		lines.append([dense(_fillet_closed_ring(ring_ctrl, 9.5, 0.70), 2.0), 9.0 if r == rc.rings[0] else 7.0])
	for i in ns:
		var spk := PackedVector2Array([
			_radial_pt(c, float(rc.rings[0]), i, ns),
			_radial_pt(c, float(rc.rings[rc.rings.size() - 1]), i, ns),
			_radial_pt(c, float(rc.r) + 18.0, i, ns),
		])
		lines.append([dense(spk, 3.0), 7.0])
	for ln: Array in lines:
		var pts: PackedVector2Array = ln[0]
		var keep := PackedVector2Array()
		var runs: Array = []
		for p in pts:
			var ok: bool = nb_info(nb_owner(p)).kind == "radial"
			if ok:
				keep.append(p)
			else:
				if keep.size() >= 3:
					runs.append(keep)
				keep = PackedVector2Array()
		if keep.size() >= 3:
			runs.append(keep)
		for run: PackedVector2Array in runs:
			for r2 in _filter_road(L, run, "loc", ln[1], clears):
				if L.rect.grow(CLIP_PAD).intersects(_poly_rect(r2)):
					for r3 in _clip_rect(r2, L.rect.grow(CLIP_PAD)):
						roads.append({"pts": r3, "w": ln[1], "dirt": false, "kind": "loc", "bridge": false})


## 放射街区的街块：折线环街与辐射街围成的凸多边形街块 ∩ 街区
static func _radial_blocks(L: Dictionary, nb: Dictionary, blocks: Array) -> void:
	for rc: Dictionary in RADIAL:
		var c := Vector2(rc.c[0], rc.c[1])
		var rings: Array = rc.rings + [float(rc.r) + 22.0]
		var ns: int = rc.spokes
		var inner := nb_inner(nb)
		if inner.size() < 3:
			continue
		# 中心内环核心街块（整体折线多边形内缩，避免放射状饼图切片）
		var core := PackedVector2Array()
		for si in ns:
			core.append(_radial_pt(c, float(rc.rings[0]), si, ns))
		core = inset(core, 4.4)
		if core.size() >= 3:
			var cbp := clip_convex(core, inner)
			var csub := 0
			for cpiece: PackedVector2Array in _split_by_art(cbp):
				if cpiece.size() >= 3 and poly_area(cpiece) > 110.0:
					var cch := _block_char(L, cpiece)
					if cch != "":
						blocks.append({"poly": cpiece, "ch": cch, "ang": 0.22, "kind": "radial", "nb": nb.k,
							"id": Vector3i(nb.k.x, nb.k.y, 9000 + csub)})
				csub += 1
		for ri in rings.size() - 1:
			var r0: float = float(rings[ri])
			var r1: float = float(rings[ri + 1])
			for si in ns:
				var p00 := _radial_pt(c, r0, si, ns)
				var p01 := _radial_pt(c, r0, si + 1, ns)
				var p11 := _radial_pt(c, r1, si + 1, ns)
				var p10 := _radial_pt(c, r1, si, ns)
				var q := inset(PackedVector2Array([p00, p10, p11, p01]), 3.6)
				if q.size() < 3:
					continue
				var bp := clip_convex(q, inner)
				var sub := 0
				for piece: PackedVector2Array in _split_by_art(bp):
					var chord_ang := (p01 - p00).angle()
					var ext_p := _extent(piece, chord_ang)
					if piece.size() >= 3 and poly_area(piece) > 105.0 and minf(ext_p.x, ext_p.y) >= 7.2:
						var ch := _block_char(L, piece)
						if ch != "":
							blocks.append({"poly": piece, "ch": ch, "ang": chord_ang, "kind": "radial", "nb": nb.k,
								"id": Vector3i(nb.k.x, nb.k.y, (ri * 100 + si) * 4 + sub)})
					sub += 1


## 河口湿地的小水塘（只在非战区格子里，确定性）
static func _marsh_pools(t: Vector2i) -> Array:
	var out: Array = []
	for cj in range(t.y * 9, t.y * 9 + 9):
		for ci in range(t.x * 9, t.x * 9 + 9):
			if cell_char(ci, cj) != "L":
				continue
			for k in 2:
				if h2(ci, cj, 40 + k) < 0.55:
					var p := Vector2(-HALF + CELL * (ci + h2(ci, cj, 50 + k)), -HALF + CELL * (cj + h2(ci, cj, 60 + k)))
					out.append(Vector3(p.x, p.y, 4.0 + h2(ci, cj, 70 + k) * 8.0))
	return out


# ---------------------------------------------------------------- 建筑
## 各区块的地块切分与建筑：lot 目标地块面积范围，m 建筑离地块边的间距，h 高度档，empty 空地块概率，court 内院地块留空概率
const BLD_SPEC := {
	"D": {"lot": [150.0, 360.0], "m": [0.20, 0.45], "kind": "bld", "h": [16.0, 38.0], "empty": 0.03, "court": 0.24},
	"R": {"lot": [160.0, 320.0], "m": [0.45, 0.90], "kind": "tenement", "h": [10.5, 26.0], "empty": 0.05, "court": 0.38},
	"H": {"lot": [380.0, 800.0], "m": [1.8, 3.0], "kind": "wh", "h": [6.5, 8.5], "empty": 0.18, "court": 0.3},
	"I": {"lot": [450.0, 1100.0], "m": [2.0, 3.5], "kind": "wh", "h": [7.0, 10.0], "empty": 0.1, "court": 0.12},
	"Y": {"lot": [700.0, 1200.0], "m": [3.0, 3.0], "kind": "shed", "h": [3.0, 3.6], "empty": 0.6, "court": 0.9},
	"M": {"lot": [380.0, 600.0], "m": [4.0, 6.0], "kind": "barrack", "h": [3.6, 3.6], "empty": 0.3, "court": 0.5},
}


## 一个街块的建筑（确定性：随机数按街块 id 定种）。街块按块的朝向递归切成大小不一的地块，每块地上一栋顺着街道朝向的楼；
## 门脸（本地 +z）朝向离它最近的街块边（即临街面）
static func _block_buildings(blk: Dictionary, L := {}, clears := []) -> Array:
	var rng := RandomNumberGenerator.new()
	var bid: Vector3i = blk.id
	rng.seed = int(h2(bid.x, bid.y, bid.z) * 2147483647.0) + 17
	var poly: PackedVector2Array = blk.poly
	if FRONT_SPEC.has(str(blk.ch)):
		return _frontage_buildings(blk, rng, L, clears)
	return _lot_buildings(blk, rng)


## 按地块切分：每块地上一栋顺着街块朝向的楼
static func _lot_buildings(blk: Dictionary, rng: RandomNumberGenerator) -> Array:
	var poly: PackedVector2Array = blk.poly
	var spec: Dictionary = BLD_SPEC.get(str(blk.ch), BLD_SPEC.R)
	var ang: float = blk.ang
	var lots := _split_lots(poly, ang, spec.lot, rng, 0)
	var out: Array = []
	var ccw := poly_area_signed(poly) > 0.0
	for lot: PackedVector2Array in lots:
		var lc := centroid(lot)
		# 最近的街块边：决定临街面
		var bd := INF
		var bn := Vector2.ZERO
		var m := poly.size()
		for i in m:
			var a := poly[i]
			var b := poly[(i + 1) % m]
			var d := seg_dist(lc, a, b)
			if d < bd:
				bd = d
				var e := (b - a).normalized()
				bn = Vector2(-e.y, e.x) if ccw else Vector2(e.y, -e.x)
		var touches := false
		for q in lot:
			for i in m:
				if seg_dist(q, poly[i], poly[(i + 1) % m]) < 0.6:
					touches = true
		if not touches and rng.randf() < float(spec.court):
			continue
		if rng.randf() < float(spec.empty):
			continue
		# 楼的朝向：顺着街块格网，门脸转向临街面
		var fa := atan2(bn.x, -bn.y)
		var k := roundf((fa - ang) / (PI * 0.5))
		var ba := ang + k * PI * 0.5
		var mg := rng.randf_range(spec.m[0], spec.m[1])
		var fit := _fit_obb(lot, ba, mg)
		if fit.is_empty():
			continue
		var kind: String = spec.kind
		var hgt := rng.randf_range(spec.h[0], spec.h[1])
		var c: Vector2 = fit.c
		var sx: float = fit.sx
		var sz: float = fit.sz
		match str(blk.ch):
			"D":
				var picked := _pick_style("D", sx, sz, hgt, rng)
				kind = picked[0]
				hgt = picked[1]
			"R":
				if sx > 13.5 and sz > 8.6:
					sx = minf(sx, rng.randf_range(15.5, 24.5))
					sz = minf(sz, rng.randf_range(9.5, 13.8))
					var picked_r := _pick_style("R", sx, sz, rng.randf_range(12.0, 26.0), rng)
					kind = picked_r[0]
					hgt = picked_r[1]
				else:
					sx = minf(sx, rng.randf_range(10.5, 17.5))
					sz = minf(sz, rng.randf_range(7.8, 11.5))
					var picked_r2 := _pick_style("R", sx, sz, hgt, rng)
					kind = picked_r2[0]
					hgt = picked_r2[1]
				var vz := Vector2(-sin(ba), cos(ba))
				c = fit.c + vz * maxf(0.0, (float(fit.sz) - sz) * 0.5 - 0.35)
			"Y":
				sx = minf(sx, rng.randf_range(8.5, 18.5))
				sz = minf(sz, rng.randf_range(5.5, 11.5))
				var picked_y := _pick_style("Y", sx, sz, hgt, rng)
				kind = picked_y[0]
				hgt = picked_y[1]
			"M":
				sx = minf(sx, rng.randf_range(8.5, 20.0))
				sz = minf(sz, rng.randf_range(6.2, 12.5))
				var picked_m := _pick_style("M", sx, sz, hgt, rng)
				kind = picked_m[0]
				hgt = picked_m[1]
			"I", "H":
				sx = minf(sx, 42.0)
				sz = minf(sz, 28.0)
				var picked_ih := _pick_style(str(blk.ch), sx, sz, hgt, rng)
				kind = picked_ih[0]
				hgt = picked_ih[1]
		if sx < 4.2 or sz < 4.2:
			continue
		var lcs := obb_corners(c, ba, sx, sz)
		if not _all_in(lot, lcs, 0.0):
			c = fit.c
			lcs = obb_corners(c, ba, sx, sz)
		var clash := false
		for prev: Dictionary in out:
			if convex_overlap(obb_corners(prev.c, prev.ang, prev.sx, prev.sz), lcs, ALLEY):
				clash = true
				break
		if clash:
			continue
		out.append({"c": c, "ang": ba, "sx": sx, "sz": sz, "h": hgt, "kind": kind, "ch": blk.ch})
	return out


## 根据街区属性与地块尺度分配多样化写实工业 / 城区建筑样式（严控高宽比防非等比拉伸畸变）
static func _pick_style(ch: String, w: float, d: float, base_h: float, rng: RandomNumberGenerator) -> Array:
	var r := rng.randf()
	match ch:
		"D":
			if w >= 16.5 and d >= 10.8:
				if r < 0.36:
					return ["highrise_office", rng.randf_range(28.5, 39.5)]
				if r < 0.62:
					return ["brutalist_slab", rng.randf_range(22.5, 30.5)]
				if r < 0.78:
					return ["midrise_office", rng.randf_range(18.5, 24.5)]
				if r < 0.87:
					return ["civic_block", rng.randf_range(15.0, 19.2)]
				if r < 0.93:
					return ["police_precinct", rng.randf_range(11.0, 13.8)]
				return ["fire_station", rng.randf_range(12.0, 14.8)]
			if w >= 13.5 and d >= 8.6:
				if r < 0.28:
					return ["highrise_office", rng.randf_range(26.0, 34.5)]
				if r < 0.54:
					return ["brutalist_slab", rng.randf_range(20.5, 27.5)]
				if r < 0.74:
					return ["midrise_office", rng.randf_range(17.5, 22.8)]
				if r < 0.86:
					return ["stepped_tower", rng.randf_range(15.5, 20.2)]
				if r < 0.94:
					return ["arcade_shop", rng.randf_range(8.8, 11.4)]
				return ["rowblock", rng.randf_range(10.2, 12.6)]
			if w >= 10.5 and d >= 7.4:
				if r < 0.42:
					return ["stepped_tower", rng.randf_range(15.2, 19.8)]
				if r < 0.72:
					return ["tenement", rng.randf_range(11.8, 15.2)]
				if r < 0.88:
					return ["arcade_shop", rng.randf_range(8.6, 11.0)]
				return ["apt", rng.randf_range(10.8, 13.8)]
			if w <= 10.5 and d <= 9.5 and r > 0.90:
				return ["substation", rng.randf_range(5.4, 7.0)]
			return ["bld", rng.randf_range(12.0, 18.5)]
		"R":
			if w >= 14.5 and d >= 8.2:
				if d >= 10.0 and r >= 0.90:
					if r < 0.95:
						return ["water_tower", rng.randf_range(17.5, 21.5)]
					return ["b6_gas_station", rng.randf_range(5.6, 6.8)]
				if r < 0.38:
					return ["brutalist_slab", rng.randf_range(21.5, 28.5)]
				if r < 0.62:
					return ["midrise_office", rng.randf_range(17.5, 23.0)]
				if r < 0.84:
					return ["rowblock", rng.randf_range(10.2, 12.8)]
				return ["courtyard_blk", rng.randf_range(10.0, 12.4)]
			if w >= 10.8 and d >= 6.8:
				if r < 0.34:
					return ["stepped_tower", rng.randf_range(15.0, 19.5)]
				if r < 0.66:
					return ["tenement", rng.randf_range(11.5, 14.8)]
				if r < 0.86:
					return ["apt", rng.randf_range(10.5, 13.6)]
				return ["arcade_shop", rng.randf_range(8.2, 10.4)]
			if w >= 8.2 and d >= 6.5:
				if r < 0.56:
					return ["tenement", rng.randf_range(10.8, 13.8)]
				if r < 0.84:
					return ["apt", rng.randf_range(9.8, 12.6)]
				return ["duplex", rng.randf_range(6.2, 7.8)]
			if w >= 6.8 and r < 0.72:
				return ["duplex", rng.randf_range(5.8, 7.4)]
			return ["house", rng.randf_range(4.4, 5.8)]
		"I":
			if w * d < 95.0:
				if r < 0.42:
					return ["substation", rng.randf_range(4.6, 6.6)]
				if r < 0.64 and w >= 8.0 and d >= 6.5:
					return ["bldg_water_tower", rng.randf_range(8.6, 10.6)]
				if r < 0.80 and w >= 9.0 and d >= 7.0:
					return ["b6_foundry_kiln", rng.randf_range(8.2, 10.2)]
				return ["shed", rng.randf_range(3.6, 4.8)]
			if w >= 14.5 and d >= 10.5:
				if r < 0.18:
					return ["foundry", rng.randf_range(8.0, 12.2)]
				if r < 0.34:
					return ["chem_plant", rng.randf_range(7.2, 10.8)]
				if r < 0.46:
					return ["wh", base_h]
				if r < 0.57:
					return ["cooling_tower", rng.randf_range(13.8, 17.0)]
				if r < 0.68:
					return ["fuel_tank_farm", rng.randf_range(10.0, 12.2)]
				if r < 0.79:
					return ["salvage_foundry", rng.randf_range(12.2, 14.8)]
				if r < 0.90:
					if w >= 15.5 and d >= 11.2:
						return ["factory_smelter", rng.randf_range(14.0, 17.2)]
					return ["salvage_foundry", rng.randf_range(12.2, 14.8)]
				return ["water_tower_pump", rng.randf_range(13.4, 16.2)]
			if w >= 10.0 and d >= 8.0:
				if r < 0.24:
					if w >= 12.0 and d >= 9.0:
						return ["foundry", rng.randf_range(8.0, 12.2)]
					return ["b6_foundry_kiln", rng.randf_range(8.4, 10.4)]
				if r < 0.46:
					return ["chem_plant", rng.randf_range(6.8, 10.2)]
				if r < 0.64:
					return ["wh", base_h]
				if r < 0.76:
					return ["b6_foundry_kiln", rng.randf_range(8.4, 10.4)]
				if r < 0.86:
					if w >= 12.0 and d >= 9.2:
						return ["water_tower_pump", rng.randf_range(13.0, 15.8)]
					return ["bldg_water_tower", rng.randf_range(8.8, 10.8)]
				if r < 0.94:
					return ["bldg_water_tower", rng.randf_range(8.8, 10.8)]
				return ["substation", rng.randf_range(5.0, 7.0)]
			if r < 0.85:
				return ["wh", base_h]
			return ["substation", rng.randf_range(5.0, 7.0)]
		"H":
			if w * d < 95.0:
				if r < 0.25 and w >= 8.8 and d >= 6.8:
					return ["b6_lighthouse", rng.randf_range(9.4, 11.4)]
				if r < 0.55 and w >= 9.0 and d >= 7.0:
					return ["b6_drydock_yard", rng.randf_range(6.4, 8.0)]
				return ["shed", rng.randf_range(3.5, 4.8)]
			if w >= 14.5 and d >= 9.8:
				if r < 0.20:
					return ["wh", base_h]
				if r < 0.32:
					return ["cold_store", rng.randf_range(7.0, 9.8)]
				if r < 0.44:
					return ["port_warehouse", rng.randf_range(9.2, 11.4)]
				if r < 0.56:
					return ["cold_storage", rng.randf_range(9.0, 11.0)]
				if r < 0.67:
					return ["ferry_terminal", rng.randf_range(9.8, 12.0)]
				if r < 0.79:
					return ["dockside_gantry", rng.randf_range(12.8, 15.6)]
				if r < 0.90:
					return ["drydock_crane", rng.randf_range(13.6, 16.8)]
				return ["drawbridge_gatehouse", rng.randf_range(11.2, 13.6)]
			if w >= 9.5 and d >= 7.2:
				if r < 0.34:
					return ["wh", base_h]
				if r < 0.58:
					return ["cold_store", rng.randf_range(7.0, 9.8)]
				if r < 0.86:
					return ["b6_drydock_yard", rng.randf_range(6.4, 8.0)]
				return ["b6_lighthouse", rng.randf_range(9.4, 11.4)]
			return ["wh", base_h]
		"Y":
			if w >= 13.5 and d >= 8.8:
				if r < 0.26:
					return ["loco_shed", rng.randf_range(5.4, 7.2)]
				if r < 0.48:
					return ["locomotive_roundhouse", rng.randf_range(10.2, 12.4)]
				if r < 0.68:
					return ["train_depot", rng.randf_range(9.4, 11.4)]
				if r < 0.88:
					return ["ore_crusher_tipple", rng.randf_range(12.2, 14.8)]
				return ["b6_rail_depot", rng.randf_range(6.2, 7.6)]
			if w >= 9.0 and d >= 5.5:
				if r < 0.38:
					return ["loco_shed", rng.randf_range(5.2, 7.0)]
				if r < 0.72:
					return ["b6_rail_depot", rng.randf_range(6.0, 7.6)]
				if r < 0.86:
					return ["substation", rng.randf_range(4.6, 6.2)]
				return ["shed", base_h]
			if r > 0.78 and w >= 6.5 and d >= 5.5:
				return ["substation", rng.randf_range(4.4, 6.0)]
			return ["shed", base_h]
		"M":
			if w >= 13.5 and d >= 9.2:
				if r < 0.24:
					return ["command_bunker", rng.randf_range(5.4, 8.0)]
				if r < 0.42:
					return ["barrack", rng.randf_range(3.8, 4.6)]
				if r < 0.68:
					return ["hangar_quonset", rng.randf_range(8.2, 10.2)]
				if r < 0.88:
					return ["radar_array", rng.randf_range(13.2, 16.2)]
				return ["b6_helipad", rng.randf_range(5.6, 7.0)]
			if w >= 9.5 and d >= 6.5:
				if r < 0.28:
					return ["barrack", base_h]
				if r < 0.48:
					return ["command_bunker", rng.randf_range(4.8, 6.8)]
				if r < 0.68:
					return ["b6_helipad", rng.randf_range(5.6, 7.0)]
				if r < 0.86:
					return ["b6_artillery_nest", rng.randf_range(4.4, 5.6)]
				return ["fort_pillbox_bunker_ruined", rng.randf_range(3.8, 4.8)]
			if r < 0.45:
				return ["fort_pillbox_bunker_ruined", rng.randf_range(3.8, 4.8)]
			if r < 0.75 and w >= 8.0 and d >= 6.0:
				return ["b6_artillery_nest", rng.randf_range(4.4, 5.4)]
			return ["barrack", base_h]
		"F":
			if w >= 14.5 and d >= 10.0:
				if r < 0.24:
					return ["grain_silo_elevator", rng.randf_range(13.2, 16.0)]
				if r < 0.46:
					return ["grain_silo", rng.randf_range(14.8, 18.0)]
				if r < 0.66:
					return ["fuel_depot", rng.randf_range(7.4, 9.0)]
				if r < 0.84:
					return ["water_tower", rng.randf_range(16.5, 20.5)]
				return ["silo_barn", rng.randf_range(7.2, 9.2)]
			if w >= 9.5 and d >= 7.0:
				if r < 0.28:
					return ["bldg_grain_silo", rng.randf_range(8.6, 10.4)]
				if r < 0.50:
					return ["b6_gas_station", rng.randf_range(5.4, 6.6)]
				if r < 0.76:
					return ["silo_barn", rng.randf_range(6.8, 8.2)]
				return ["barn", rng.randf_range(5.8, 7.2)]
			return ["farm", rng.randf_range(4.2, 5.2)]
	return ["bld", base_h]


## 临街排楼（城区 / 住宅 / 厂区 / 港区）：沿街块每条边顺着街向排布；城区优先使用整块/双主楼与 24m 连排一体式街墙（civic_block / midrise_office / rowblock），
## 任意两栋独立 OBB 之间严格保持 >= ALLEY（4.3 米）通行巷道，兼顾纽约/华盛顿级高街块占空比与 4m 机甲流畅机动。
const ALLEY := 4.3
const FRONT_SPEC := {
	"D": {"w": [15.5, 29.5], "d": [10.8, 17.5], "set": [0.3, 0.8], "empty": 0.01, "inner": 0.84, "h": [18.0, 38.0], "kind": "highrise_office"},
	"R": {"w": [14.0, 26.5], "d": [8.8, 13.6], "set": [0.4, 1.0], "empty": 0.02, "inner": 0.72, "h": [12.5, 27.5], "kind": "brutalist_slab"},
	"I": {"w": [9.0, 21.0], "d": [8.5, 16.0], "set": [1.4, 3.0], "empty": 0.06, "inner": 0.85, "h": [6.5, 10.5], "kind": "wh"},
	"H": {"w": [8.5, 19.0], "d": [7.5, 14.0], "set": [1.4, 2.6], "empty": 0.06, "inner": 0.68, "h": [6.2, 8.8], "kind": "wh"},
	"Y": {"w": [8.0, 18.5], "d": [5.5, 11.5], "set": [1.6, 3.0], "empty": 0.30, "inner": 0.30, "h": [3.2, 4.2], "kind": "shed"},
	"M": {"w": [8.5, 20.0], "d": [6.2, 13.0], "set": [2.0, 3.5], "empty": 0.14, "inner": 0.58, "h": [3.6, 4.4], "kind": "barrack"},
}


## 尝试按整块主楼 / 双主楼（中留 6m 穿行街巷）优先排布中心城区（D）与高密街坊（R）街块，消除“大水泥地插细牙签”；返回是否已预留街心广场半区
static func _try_urban_block_massing(blk: Dictionary, poly: PackedVector2Array, ch: String, rng: RandomNumberGenerator, L: Dictionary, clears: Array, placed: Array, out: Array) -> bool:
	var area := poly_area(poly)
	if area < 240.0:
		return false
	# 约 10% 的中大型中心城街块预留一半作为街心绿地公园或地面停车场，不塞死整块
	var reserve_plaza := (ch == "D" and area >= 720.0 and rng.randf() < 0.10)
	var ang := float(blk.ang)
	var fit := _fit_obb(poly, ang, 0.55)
	var edge_ang := _longest_edge(poly).angle()
	var fit2 := _fit_obb(poly, edge_ang, 0.55)
	if fit.is_empty() or (not fit2.is_empty() and float(fit2.sx) * float(fit2.sz) > float(fit.sx) * float(fit.sz) * 1.12):
		fit = fit2
		ang = edge_ang
	if fit.is_empty():
		return false
	var fx: float = float(fit.sx)
	var fz: float = float(fit.sz)
	if minf(fx, fz) < 9.2 or maxf(fx, fz) < 13.5:
		return false
	# 保证局部 u 轴沿街块长边、v 轴沿短边（让宽体建筑顺街块长轴延展）
	var rot_ang := ang
	var long_l := fx
	var short_l := fz
	if fz > fx * 1.08:
		rot_ang = ang + PI * 0.5
		long_l = fz
		short_l = fx
	var u := Vector2(cos(rot_ang), sin(rot_ang))
	var v := Vector2(-sin(rot_ang), cos(rot_ang))
	var fc: Vector2 = fit.c
	var sp: Dictionary = FRONT_SPEC[ch]
	var alley_w := 5.6 if ch == "D" else 5.0

	# 模式 A：超大深街块（short_l >= 25.5m），前后双排宽体联排街墙 + 中间穿行服务内巷
	if not reserve_plaza and short_l >= 25.5 and long_l >= 18.0:
		var band_d := clampf((short_l - alley_w) * 0.5, 9.6, 16.5 if ch == "D" else 12.0)
		var off_v := band_d * 0.5 + alley_w * 0.5
		var any_put := false
		for side_v: float in [-1.0, 1.0]:
			var row_ang := rot_ang if side_v > 0.0 else (rot_ang + PI)
			if long_l >= 38.0:
				var w2 := clampf((long_l - alley_w) * 0.5, 14.5, 27.5)
				for side_u: float in [-1.0, 1.0]:
					var c2 := fc + u * (side_u * (w2 * 0.5 + alley_w * 0.5)) + v * (side_v * off_v)
					var cs2 := obb_corners(c2, row_ang, w2, band_d)
					if _all_in(poly, cs2, 0.35) and _gap_ok(placed, cs2) and _site_ok(L, clears, c2, row_ang, w2, band_d):
						var pk := _pick_style(ch, w2, band_d, rng.randf_range(sp.h[0], sp.h[1]), rng)
						out.append({"c": c2, "ang": row_ang, "sx": w2, "sz": band_d, "h": pk[1], "kind": pk[0], "ch": ch})
						placed.append(cs2)
						any_put = true
			else:
				var w1 := clampf(long_l * 0.92, 15.0, 29.0)
				var c1 := fc + v * (side_v * off_v)
				var cs1 := obb_corners(c1, row_ang, w1, band_d)
				if _all_in(poly, cs1, 0.35) and _gap_ok(placed, cs1) and _site_ok(L, clears, c1, row_ang, w1, band_d):
					var pk1 := _pick_style(ch, w1, band_d, rng.randf_range(sp.h[0], sp.h[1]), rng)
					out.append({"c": c1, "ang": row_ang, "sx": w1, "sz": band_d, "h": pk1[1], "kind": pk1[0], "ch": ch})
					placed.append(cs1)
					any_put = true
		if any_put:
			return false

	# 模式 B：长街块（long_l >= 34m），拆成两栋宽厚主楼 + 中间穿行广场/过道（或半块留给街心公园/停车场）
	if long_l >= 34.0:
		var w_each := clampf((long_l - alley_w) * 0.5, 14.0, 28.5)
		var d_each := clampf(short_l * 0.90, 9.5, 18.5 if ch == "D" else 13.0)
		var any_b := false
		var sides: Array = [-1.0] if reserve_plaza else [-1.0, 1.0]
		for side_u: float in sides:
			var b_ang := rot_ang if (rng.randf() < 0.5) else (rot_ang + PI)
			var cb := fc + u * (side_u * (w_each * 0.5 + alley_w * 0.5))
			var csb := obb_corners(cb, b_ang, w_each, d_each)
			if _all_in(poly, csb, 0.35) and _gap_ok(placed, csb) and _site_ok(L, clears, cb, b_ang, w_each, d_each):
				var pkb := _pick_style(ch, w_each, d_each, rng.randf_range(sp.h[0], sp.h[1]), rng)
				out.append({"c": cb, "ang": b_ang, "sx": w_each, "sz": d_each, "h": pkb[1], "kind": pkb[0], "ch": ch})
				placed.append(csb)
				any_b = true
		if any_b:
			return reserve_plaza

	# 模式 C：紧凑-中型华盛顿/曼哈顿整块大楼（一栋宽厚主楼撑满 85% 街块）
	if not reserve_plaza and long_l >= 14.0 and short_l >= 9.4:
		var w_full := clampf(long_l * 0.92, 13.5, 30.0)
		var d_full := clampf(short_l * 0.88, 9.2, 19.5 if ch == "D" else 13.5)
		var f_ang := rot_ang if (rng.randf() < 0.5) else (rot_ang + PI)
		var csf := obb_corners(fc, f_ang, w_full, d_full)
		if _all_in(poly, csf, 0.35) and _gap_ok(placed, csf) and _site_ok(L, clears, fc, f_ang, w_full, d_full):
			var pkf := _pick_style(ch, w_full, d_full, rng.randf_range(sp.h[0], sp.h[1]), rng)
			out.append({"c": fc, "ang": f_ang, "sx": w_full, "sz": d_full, "h": pkf[1], "kind": pkf[0], "ch": ch})
			placed.append(csf)
			return false
	return false


static func _frontage_buildings(blk: Dictionary, rng: RandomNumberGenerator, L: Dictionary, clears: Array) -> Array:
	var poly: PackedVector2Array = blk.poly
	var ch := str(blk.ch)
	var sp: Dictionary = FRONT_SPEC[ch]
	var m := poly.size()
	var ccw := poly_area_signed(poly) > 0.0
	var placed: Array = []      ## 已放的轮廓（严格 >= ALLEY 间隔）
	var out: Array = []
	if ch in ["D", "R"]:
		if _try_urban_block_massing(blk, poly, ch, rng, L, clears, placed, out):
			return out
	var order: Array = []
	for i in m:
		order.append(i)
	order.sort_custom(func(x, y): return poly[x].distance_to(poly[(x + 1) % m]) > poly[y].distance_to(poly[(y + 1) % m]))
	var min_w := 7.4 if ch == "D" else (6.6 if ch == "R" else 4.5)
	var min_d := 6.6 if ch == "D" else (5.8 if ch == "R" else 4.5)
	for i: int in order:
		var a := poly[i]
		var b := poly[(i + 1) % m]
		var el := a.distance_to(b)
		if el < min_w + 1.0:
			continue
		var e := (b - a) / el
		var n := Vector2(-e.y, e.x) if ccw else Vector2(e.y, -e.x)    # 向内
		var ang := atan2(n.x, -n.y)                                       # 本地 +z 朝街（-n）
		var t := rng.randf_range(0.3, 1.2)
		while t < el - min_w:
			var w := minf(rng.randf_range(sp.w[0], sp.w[1]), el - t - 0.3)
			var d := rng.randf_range(sp.d[0], sp.d[1])
			var st := rng.randf_range(sp.set[0], sp.set[1])
			if rng.randf() < float(sp.empty):
				t += maxf(ALLEY + 0.5, w * 0.55)
				continue
			var cs := PackedVector2Array()
			var c := Vector2.ZERO
			var ok := false
			for k in 8:
				var ww: float = maxf(min_w, w * [1.0, 1.0, 0.84, 0.80, 0.68, 0.56, 0.46, 0.38][k])
				var dd: float = maxf(min_d, d * [1.0, 0.82, 1.0, 0.78, 0.72, 0.62, 0.58, 0.52][k])
				if t + ww > el - 0.25:
					ww = el - t - 0.3
				if ww < min_w or dd < min_d:
					continue
				c = a + e * (t + ww * 0.5) + n * (st + dd * 0.5)
				cs = obb_corners(c, ang, ww, dd)
				if _all_in(poly, cs, 0.35) and _gap_ok(placed, cs) and _site_ok(L, clears, c, ang, ww, dd):
					w = ww
					d = dd
					ok = true
					break
			if not ok:
				t += 2.0
				continue
			var base_h := rng.randf_range(sp.h[0], sp.h[1])
			var picked := _pick_style(ch, w, d, base_h, rng)
			out.append({"c": c, "ang": ang, "sx": w, "sz": d, "h": picked[1], "kind": picked[0], "ch": ch})
			placed.append(cs)
			t += w + rng.randf_range(ALLEY + 0.25, ALLEY + (1.2 if ch in "DR" else 3.4))
	# 内院：块够深时在中间再放一栋（离四周的楼至少一条巷宽）
	if rng.randf() < float(sp.inner):
		var fit := _fit_obb(poly, float(blk.ang), 0.7)
		if not fit.is_empty():
			for k in 6:
				var w := minf(rng.randf_range(sp.w[0] * 0.85, sp.w[1]), float(fit.sx))
				var d := minf(rng.randf_range(sp.d[0] * 0.85, sp.d[1]), float(fit.sz))
				var ba := float(blk.ang) + (PI * 0.5 if rng.randf() < 0.3 else 0.0)
				var c: Vector2 = fit.c + Vector2(rng.randf_range(-1, 1) * float(fit.sx), rng.randf_range(-1, 1) * float(fit.sz)) * 0.18
				var cs := obb_corners(c, ba, w, d)
				if w >= min_w and d >= min_d and _all_in(poly, cs, 0.55) and _gap_ok(placed, cs) and _site_ok(L, clears, c, ba, w, d):
					var base_h2 := rng.randf_range(sp.h[0], sp.h[1]) * (0.85 if ch == "D" else 1.0)
					var picked2 := _pick_style(ch, w, d, base_h2, rng)
					out.append({"c": c, "ang": ba, "sx": w, "sz": d, "h": picked2[1], "kind": picked2[0], "ch": ch, "inner": true})
					placed.append(cs)
					break
	return out


## 任意两栋独立建筑 OBB 之间严格隔开至少 ALLEY（4.3m），杜绝转角叠楼、屋檐穿模与卡机甲窄缝
static func _gap_ok(placed: Array, cs: PackedVector2Array) -> bool:
	for o: PackedVector2Array in placed:
		if convex_overlap(o, cs, ALLEY):
			return false
	return true


static func _site_ok(L: Dictionary, clears: Array, c: Vector2, ang: float, sx: float, sz: float) -> bool:
	return L.is_empty() or _bldg_ok(L, {"c": c, "ang": ang, "sx": sx, "sz": sz}, clears)


## 把凸多边形按块的朝向递归切成面积在 lot 范围里的地块（切线位置随机，地块大小不一）
static func _split_lots(poly: PackedVector2Array, ang: float, lot: Array, rng: RandomNumberGenerator, depth: int) -> Array:
	var area := poly_area(poly)
	if depth > 8 or area <= rng.randf_range(lot[0], lot[1]):
		return [poly]
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-sin(ang), cos(ang))
	var ext := _extent(poly, ang)
	var axis := u if ext.x >= ext.y else v
	var lo := INF
	var hi := -INF
	for p in poly:
		lo = minf(lo, p.dot(axis))
		hi = maxf(hi, p.dot(axis))
	var cut := lerpf(lo, hi, rng.randf_range(0.36, 0.64))
	var a := clip_half(poly, axis * cut, axis)
	var b := clip_half(poly, axis * cut, -axis)
	if a.size() < 3 or b.size() < 3:
		return [poly]
	return _split_lots(a, ang, lot, rng, depth + 1) + _split_lots(b, ang, lot, rng, depth + 1)


## 在凸多边形里放一个朝向 ang 的尽量大的矩形（四边各留 margin）：在块的朝向坐标系里从外接矩形出发，
## 每个出界的角沿 x 或 y 收回到多边形边界（取收得少的方向）；放不下返回 {}
static func _fit_obb(poly: PackedVector2Array, ang: float, margin: float) -> Dictionary:
	var a := _fit_obb_snap(poly, ang, margin)
	var b := _fit_obb_shrink(poly, ang, margin)
	if a.is_empty():
		return b
	if b.is_empty() or float(a.sx) * float(a.sz) >= float(b.sx) * float(b.sz):
		return a
	return b


## 回退：外接矩形逐角收较长边
static func _fit_obb_shrink(poly: PackedVector2Array, ang: float, margin: float) -> Dictionary:
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-sin(ang), cos(ang))
	var inner := inset(poly, margin)
	if inner.size() < 3:
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in inner:
		lo = Vector2(minf(lo.x, p.dot(u)), minf(lo.y, p.dot(v)))
		hi = Vector2(maxf(hi.x, p.dot(u)), maxf(hi.y, p.dot(v)))
	for it in 60:
		if hi.x - lo.x < 3.5 or hi.y - lo.y < 3.5:
			return {}
		var bad := false
		var cs := [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]
		for k in 4:
			var q: Vector2 = cs[k]
			if in_convex(inner, u * q.x + v * q.y):
				continue
			bad = true
			if (hi.x - lo.x) >= (hi.y - lo.y):
				if k == 0 or k == 3:
					lo.x += 0.7
				else:
					hi.x -= 0.7
			else:
				if k == 0 or k == 1:
					lo.y += 0.7
				else:
					hi.y -= 0.7
		if not bad:
			return {"c": u * (lo.x + hi.x) * 0.5 + v * (lo.y + hi.y) * 0.5, "sx": hi.x - lo.x, "sz": hi.y - lo.y}
	return {}


static func _fit_obb_snap(poly: PackedVector2Array, ang: float, margin: float) -> Dictionary:
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-sin(ang), cos(ang))
	var inner := inset(poly, margin)
	if inner.size() < 3:
		return {}
	var pf := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in inner:
		var q := Vector2(p.dot(u), p.dot(v))
		pf.append(q)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	for it in 80:
		if hi.x - lo.x < 3.5 or hi.y - lo.y < 3.5:
			return {}
		var bad := false
		var cs := [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]
		for k in 4:
			var q: Vector2 = cs[k]
			if in_convex(pf, q):
				continue
			bad = true
			var ix := _span(pf, q.y, true)     # 水平线 y = q.y 与多边形的交段（x 范围）
			var iy := _span(pf, q.x, false)    # 竖直线 x = q.x 与多边形的交段（y 范围）
			var tx := INF
			var ty := INF
			if ix.x <= ix.y:
				tx = maxf(ix.x - q.x, q.x - ix.y)
			if iy.x <= iy.y:
				ty = maxf(iy.x - q.y, q.y - iy.y)
			if tx == INF and ty == INF:
				tx = 0.8
				ty = 0.8
			if tx <= ty:
				var nx := clampf(q.x, ix.x, ix.y) if ix.x <= ix.y else q.x
				if k == 0 or k == 3:
					lo.x = maxf(lo.x + 0.05, nx + 0.02) if tx != INF else lo.x + 0.8
				else:
					hi.x = minf(hi.x - 0.05, nx - 0.02) if tx != INF else hi.x - 0.8
			else:
				var ny := clampf(q.y, iy.x, iy.y) if iy.x <= iy.y else q.y
				if k == 0 or k == 1:
					lo.y = maxf(lo.y + 0.05, ny + 0.02) if ty != INF else lo.y + 0.8
				else:
					hi.y = minf(hi.y - 0.05, ny - 0.02) if ty != INF else hi.y - 0.8
			break
		if not bad:
			var c := u * (lo.x + hi.x) * 0.5 + v * (lo.y + hi.y) * 0.5
			return {"c": c, "sx": hi.x - lo.x, "sz": hi.y - lo.y}
	return {}


## 凸多边形与水平线（horiz = true，y = c）或竖直线（x = c）的交段：返回 Vector2(最小, 最大)，不相交时 x > y
static func _span(pf: PackedVector2Array, c: float, horiz: bool) -> Vector2:
	var a := INF
	var b := -INF
	var m := pf.size()
	for i in m:
		var p := pf[i]
		var q := pf[(i + 1) % m]
		var pc := p.y if horiz else p.x
		var qc := q.y if horiz else q.x
		if (pc - c) * (qc - c) <= 0.0 and pc != qc:
			var t := (c - pc) / (qc - pc)
			var x := (p.x + (q.x - p.x) * t) if horiz else (p.y + (q.y - p.y) * t)
			a = minf(a, x)
			b = maxf(b, x)
	return Vector2(a, b)


## 农田分块与倒角：把大块 Voronoi 街区裁开主干道与河道、沿耕作方向切分为自然条田并做圆角，消除生硬多边形轮廓
static func _make_fields(L: Dictionary, poly: PackedVector2Array, ang: float, k: Vector2i) -> Array:
	var base := inset(poly, 5.5)
	if base.size() < 3:
		return []
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-sin(ang), cos(ang))
	var pieces: Array = _split_by_art(base)
	var sub_pieces: Array = []
	for p: PackedVector2Array in pieces:
		if p.size() < 3 or poly_area(p) < 280.0:
			continue
		var ext := _extent(p, ang)
		var c := centroid(p)
		if ext.x > 74.0:
			var off := (h2(k.x, k.y, 91) - 0.5) * 14.0
			var p1 := clip_half(p, c + u * (off - 2.0), -u)
			var p2 := clip_half(p, c + u * (off + 2.0), u)
			for q in [p1, p2]:
				if q.size() >= 3 and poly_area(q) >= 260.0:
					sub_pieces.append(q)
		else:
			sub_pieces.append(p)
	var final_pieces: Array = []
	for p: PackedVector2Array in sub_pieces:
		var ext := _extent(p, ang)
		var c := centroid(p)
		if ext.y > 68.0:
			var off := (h2(k.x, k.y, 92) - 0.5) * 12.0
			var p1 := clip_half(p, c + v * (off - 2.0), -v)
			var p2 := clip_half(p, c + v * (off + 2.0), v)
			for q in [p1, p2]:
				if q.size() >= 3 and poly_area(q) >= 240.0:
					final_pieces.append(q)
		else:
			final_pieces.append(p)
	var out: Array = []
	var idx := 0
	for p: PackedVector2Array in final_pieces:
		if dist_at(L, centroid(p)) != "F":
			continue
		var rp := _round_convex(p, 5.5)
		if rp.size() >= 3 and poly_area(rp) >= 220.0:
			var fang := ang if (idx + k.x + k.y) % 2 == 0 else ang + PI * 0.5
			out.append({"poly": rp, "ang": fang, "k": k, "sub": idx})
			idx += 1
	return out


## 凸多边形圆角化（保持严格凸性，消除尖锐顶点）
static func _round_convex(poly: PackedVector2Array, r := 5.0) -> PackedVector2Array:
	var m := poly.size()
	if m < 3:
		return poly
	var out := PackedVector2Array()
	for i in m:
		var a := poly[(i - 1 + m) % m]
		var b := poly[i]
		var c := poly[(i + 1) % m]
		var la := b.distance_to(a)
		var lc := b.distance_to(c)
		var d := minf(r, minf(la, lc) * 0.32)
		if d < 1.0:
			out.append(b)
			continue
		var p0 := b + (a - b) / la * d
		var p1 := b + (c - b) / lc * d
		var pm := (p0 + p1) * 0.36 + b * 0.28
		out.append(p0)
		out.append(pm)
		out.append(p1)
	return out


## 农场：农舍 + 谷仓 / 筒仓粮库 / 油库 / 加油站 / 水塔，两栋之间留够 >= 6.5m 院坝间距
static func _farm_buildings(fd: Dictionary) -> Array:
	var sub_idx := int(fd.get("sub", 0))
	if sub_idx > 1:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(h2(fd.k.x, fd.k.y, 88 + sub_idx * 17) * 2147483647.0) + 3
	var out: Array = []
	if rng.randf() < (0.22 if sub_idx == 0 else 0.52):
		return out
	var fc := centroid(fd.poly)
	var c := fc + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0))
	var a: float = fd.ang
	var u := Vector2(cos(a), sin(a))
	var v := Vector2(-sin(a), cos(a))
	var h := {"c": c, "ang": a, "sx": 8.0, "sz": 7.0, "h": 4.6, "kind": "farm", "ch": "F"}
	var has_h := _all_in(fd.poly, obb_corners(h.c, h.ang, h.sx, h.sz), 2.0)
	if has_h:
		out.append(h)
	var fr := rng.randf()
	var bn_sx := 12.0
	var bn_sz := 9.0
	var bn_h := 6.5
	var bkind := "barn"
	if fr < 0.16:
		bkind = "grain_silo_elevator"
		bn_sx = 16.5
		bn_sz = 11.8
		bn_h = 14.5
	elif fr < 0.30:
		bkind = "grain_silo"
		bn_sx = 17.0
		bn_sz = 12.8
		bn_h = 15.8
	elif fr < 0.42:
		bkind = "fuel_depot"
		bn_sx = 17.5
		bn_sz = 12.8
		bn_h = 7.8
	elif fr < 0.52:
		bkind = "water_tower"
		bn_sx = 14.0
		bn_sz = 13.6
		bn_h = 18.4
	elif fr < 0.66:
		bkind = "bldg_grain_silo"
		bn_sx = 11.8
		bn_sz = 8.4
		bn_h = 9.6
	elif fr < 0.78:
		bkind = "b6_gas_station"
		bn_sx = 12.0
		bn_sz = 8.6
		bn_h = 5.8
	elif fr < 0.90:
		bkind = "silo_barn"
		bn_sx = 12.0
		bn_sz = 9.0
		bn_h = 7.2
	else:
		bkind = "barn"
		bn_sx = 12.0
		bn_sz = 9.0
		bn_h = 6.5
	var gap_u := 4.0 + bn_sx * 0.5 + 6.8
	var placed_bn := false
	for dir_s: float in [1.0, -1.0]:
		var bn_c: Vector2 = (c + u * (dir_s * gap_u) + v * 2.0) if has_h else fc
		var bn := {"c": bn_c, "ang": a, "sx": bn_sx, "sz": bn_sz, "h": bn_h, "kind": bkind, "ch": "F"}
		if _all_in(fd.poly, obb_corners(bn.c, bn.ang, bn.sx, bn.sz), 2.0):
			out.append(bn)
			placed_bn = true
			break
		if not has_h:
			break
	if not placed_bn and bn_sx > 12.5:
		var fb_kind := "bldg_grain_silo" if rng.randf() < 0.55 else "b6_gas_station"
		var fb_h := 9.6 if fb_kind == "bldg_grain_silo" else 5.8
		for dir_s: float in [1.0, -1.0]:
			var fb_c: Vector2 = (c + u * (dir_s * 16.8) + v * 2.0) if has_h else fc
			var fb := {"c": fb_c, "ang": a, "sx": 12.0, "sz": 8.6, "h": fb_h, "kind": fb_kind, "ch": "F"}
			if _all_in(fd.poly, obb_corners(fb.c, fb.ang, fb.sx, fb.sz), 2.0):
				out.append(fb)
				break
			if not has_h:
				break
	return out


static func _longest_edge(poly: PackedVector2Array) -> Vector2:
	var best := Vector2.RIGHT
	var bl := 0.0
	for i in poly.size():
		var e := poly[(i + 1) % poly.size()] - poly[i]
		if e.length() > bl:
			bl = e.length()
			best = e
	return best


## 多边形在 ang 方向坐标系里的宽 / 深
static func _extent(poly: PackedVector2Array, ang: float) -> Vector2:
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-sin(ang), cos(ang))
	var a := Vector2(INF, INF)
	var b := Vector2(-INF, -INF)
	for p in poly:
		a = Vector2(minf(a.x, p.dot(u)), minf(a.y, p.dot(v)))
		b = Vector2(maxf(b.x, p.dot(u)), maxf(b.y, p.dot(v)))
	return b - a


static func _all_in(poly: PackedVector2Array, pts: PackedVector2Array, margin: float) -> bool:
	var inner := inset(poly, margin) if margin > 0.0 else poly
	if inner.size() < 3:
		return false
	for p in pts:
		if not in_convex(inner, p):
			return false
	return true


static func _hits(placed: Array, cs: PackedVector2Array, margin: float) -> bool:
	for o: PackedVector2Array in placed:
		if convex_overlap(o, cs, margin):
			return true
	return false


## 建筑能否保留：沿周界密集采样，确保整栋建筑不压路、不压水、不压铁轨、不进遗迹 / 地标 / 撤离点的清空圈
static func _bldg_ok(L: Dictionary, b: Dictionary, clears: Array) -> bool:
	var f := features()
	var u := Vector2(cos(b.ang), sin(b.ang))
	var v := Vector2(-sin(b.ang), cos(b.ang))
	var hx: float = b.sx * 0.5
	var hz: float = b.sz * 0.5
	var bc: Vector2 = b.c
	# 精确 OBB 到清空圆的距离判定（避免用外接圆半径误杀遗迹/地标旁 24m 宽体建筑）
	for cz: Vector3 in clears:
		var cp := Vector2(cz.x, cz.y)
		var rel: Vector2 = cp - bc
		var lx := clampf(rel.dot(u), -hx, hx)
		var lz := clampf(rel.dot(v), -hz, hz)
		var closest: Vector2 = bc + u * lx + v * lz
		var cr: float = cz.z + 0.8
		if closest.distance_squared_to(cp) < cr * cr:
			return false
	var rg: SegGrid = L.road_grid
	var rd := Vector2(b.sx, b.sz).length() * 0.5
	if rd + 1.35 <= rg.reach and rd + 2.6 <= 16.0 and rd + 2.2 <= f.rail.reach:
		if rg.edge_dist(b.c) > rd + 1.35 and f.rail.edge_dist(b.c) > rd + 2.2 and water_dist(b.c) > rd + 2.6:
			return true
	var cs := obb_corners(b.c, b.ang, b.sx, b.sz)
	var pts: Array = [b.c]
	for i in 4:
		var p0 := cs[i]
		var p1 := cs[(i + 1) % 4]
		var seg_n := maxi(2, ceili(p0.distance_to(p1) / 2.5))
		for s in seg_n:
			pts.append(p0.lerp(p1, float(s) / float(seg_n)))
	if maxf(b.sx, b.sz) > 10.0:
		pts.append(b.c + u * (b.sx * 0.25))
		pts.append(b.c - u * (b.sx * 0.25))
		pts.append(b.c + v * (b.sz * 0.25))
		pts.append(b.c - v * (b.sz * 0.25))
	for p: Vector2 in pts:
		if rg.edge_dist(p) < 1.35 or water_dist(p) < 2.6 or f.rail.edge_dist(p) < 2.2:
			return false
	return true
