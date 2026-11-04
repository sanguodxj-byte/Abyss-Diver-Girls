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

const TILE := 360.0
const HALF := 180.0
const CELL := 40.0
const NB := 120.0                ## 街区格点间距
const RAST := 2.0                ## 区块栅格分辨率（米）
const RAST_PAD := 40.0           ## 栅格在战区外多算的一圈（道路裁切用）
const CLIP_PAD := 30.0           ## 战区窗口里的道路伸出边界的长度
const URBAN := "DRIHYM"          ## 城区区块（铺街道、盖临街建筑）
const NO_COLLECTOR := "KSTLAB"   ## 支路不进入的区块
## 世界大地图范围（tools/gen_worldmap.py 按这个范围出图）
const WORLD_RECT := Rect2(-560, -900, 1480, 1760)
## 竖井 / 地下战区放在 z ≥ UNDER_Z 的格子里
const UNDER_Z := 30

## 灰港旧城放射路网的中心（世界坐标）
const RADIAL := [{"c": [-30, -30], "r": 118.0, "rings": [26.0, 54.0, 84.0], "spokes": 12}]

# ---------------------------------------------------------------- 全局要素（世界坐标）
## 河流：w 河宽，dry 干河床；pts 控制点（平滑后加密）
const RIVERS := [
	{"name": "灰港河上游", "w": 12.0, "dry": false, "pts": [[-360, -748], [-330, -690], [-270, -640], [-220, -585], [-170, -530], [-120, -500], [-70, -478], [-20, -450], [12, -424]]},
	{"name": "灰港河", "w": 18.0, "dry": false, "pts": [[74, -374], [72, -340], [64, -300], [58, -262], [60, -222], [62, -180], [56, -120], [70, -58],
		[72, -6], [100, 22], [140, 34], [180, 32], [240, 16], [320, 30], [400, 26], [470, 40], [540, 34], [590, 38], [650, 50], [740, 60]]},
	{"name": "干河", "w": 16.0, "dry": true, "pts": [[-640, 60], [-500, 105], [-370, 160], [-270, 192], [-200, 212], [-140, 262], [-110, 322], [-90, 390],
		[-40, 450], [40, 480], [120, 494], [180, 488], [240, 466], [300, 440], [360, 402], [420, 390], [480, 420], [560, 446], [640, 470], [740, 480]]},
	{"name": "北溪", "w": 8.0, "dry": false, "pts": [[-600, -900], [-540, -870], [-490, -836], [-455, -812]]},
]
## 湖 / 水库 / 池：[x, z, 半径]（多个圆拼成湖面）
const LAKES := [
	[30, -410, 26], [60, -390, 22], [14, -384, 14], [52, -420, 18],         # 赤湖
	[-150, -2, 12], [-136, -8, 7],                                          # 灰港镜湖
	[492, 132, 15], [510, 150, 11],                                         # 铁锈工业带废渣池
	[-158, 404, 9],                                                         # 尘土平原池塘
	[430, 210, 10],                                                         # 裂谷北矿坑积水
	[-430, -800, 60], [-370, -790, 50], [-480, -760, 40], [-400, -845, 45], [-330, -762, 30],   # 北郊水库
]
## 道路：kind = hwy 外环高速 / art 主干道（都过河架桥） / dirt 跨区土路
const ROADS := [
	{"name": "南北大道", "kind": "art", "w": 13.0, "pts": [[-80, -900], [-78, -760], [-88, -640], [-96, -560], [-92, -480], [-84, -400], [-72, -320], [-62, -250],
		[-58, -180], [-48, -110], [-30, -30], [-24, 40], [-20, 110], [-20, 180], [-22, 250], [-24, 330], [-16, 420], [0, 500], [24, 580], [50, 700], [70, 880]]},
	{"name": "东西大道", "kind": "art", "w": 13.0, "pts": [[-640, -70], [-480, -58], [-340, -44], [-240, -36], [-180, -34], [-110, -34], [-30, -30], [30, -38],
		[74, -46], [120, -44], [180, -40], [260, -48], [360, -58], [450, -50], [540, -36], [600, -52], [680, -110], [780, -160]]},
	{"name": "外环高速", "kind": "hwy", "w": 16.0, "pts": [[560, -110], [530, -220], [540, -380], [470, -560], [320, -640], [120, -652], [-100, -648], [-262, -622],
		[-300, -480], [-282, -300], [-264, -120], [-262, 60], [-272, 240], [-282, 420], [-252, 600], [-100, 642], [120, 634], [300, 642], [480, 652], [630, 604]]},
	{"name": "西南斜街", "kind": "art", "w": 11.0, "pts": [[-262, 252], [-200, 194], [-150, 142], [-108, 98], [-70, 52], [-46, 6], [-30, -30]]},
	{"name": "工矿公路", "kind": "art", "w": 11.0, "pts": [[380, -52], [384, 0], [388, 48], [380, 120], [372, 180], [376, 236], [380, 246]]},
	{"name": "峡谷矿道", "kind": "dirt", "w": 9.0, "pts": [[172, 320], [240, 300], [280, 250], [340, 230], [420, 250], [450, 320], [420, 370], [380, 420], [350, 450],
		[350, 490], [370, 548], [390, 620], [420, 760]]},
	{"name": "平原东西路", "kind": "dirt", "w": 10.0, "pts": [[-640, 352], [-420, 346], [-280, 342], [-180, 342], [-100, 340], [-24, 336], [60, 338], [120, 330], [172, 320]]},
	{"name": "平原南路", "kind": "dirt", "w": 8.0, "pts": [[-272, 388], [-188, 374], [-140, 384], [-110, 410], [-60, 426], [-18, 430], [40, 425], [100, 415], [150, 425],
		[180, 420], [230, 402], [300, 380], [380, 420]]},
	{"name": "缆车站支路", "kind": "dirt", "w": 7.0, "pts": [[450, 320], [490, 360], [548, 360], [600, 380], [640, 372]]},
	{"name": "赤湖环湖路", "kind": "art", "w": 10.0, "closed": true, "pts": [[100, -400], [95, -382], [82, -366], [62, -356], [38, -352], [14, -356], [-6, -366], [-19, -382],
		[-24, -400], [-19, -418], [-6, -434], [14, -444], [38, -448], [62, -444], [82, -434], [95, -418]]},
	{"name": "赤湖西南路", "kind": "art", "w": 9.0, "pts": [[-6, -366], [-40, -330], [-80, -280], [-110, -230], [-130, -172], [-140, -120], [-152, -70], [-160, -34]]},
	{"name": "湖东路", "kind": "art", "w": 9.0, "pts": [[100, -400], [150, -402], [200, -396], [260, -380], [360, -370], [480, -378], [540, -380]]},
	{"name": "北岭林道", "kind": "dirt", "w": 7.0, "pts": [[-290, -526], [-188, -510], [-120, -525], [-40, -510], [40, -530], [120, -510], [188, -520], [300, -540], [420, -560]]},
	{"name": "东南土路", "kind": "dirt", "w": 8.0, "pts": [[100, 150], [130, 170], [172, 166], [200, 124], [230, 96], [262, 66], [290, 56]]},
	{"name": "农场南北路", "kind": "dirt", "w": 8.0, "pts": [[100, 150], [98, 190], [80, 250], [70, 320], [86, 390], [100, 415]]},
	{"name": "平原西北路", "kind": "dirt", "w": 7.0, "pts": [[-60, 296], [-100, 240], [-150, 172], [-172, 118]]},
	{"name": "渣池路", "kind": "dirt", "w": 7.0, "pts": [[404, 62], [420, 96], [450, 108], [456, 140], [444, 190], [425, 246]]},
]
## 滨河路：沿灰港河右岸（灰港段西岸、运河段南岸）偏移生成，从赤湖出水口到河口
const RIVERSIDE := {"name": "滨河路", "river": 1, "off": 22.0, "w": 10.0, "from_z": -360.0, "to_x": 600.0}
## 铁路：每条是一串控制点
const RAILS := [
	[[-640, -300], [-470, -245], [-320, -196], [-200, -158], [-90, -128], [20, -112], [120, -104], [200, -100], [300, -100], [420, -100], [540, -100], [620, -118], [700, -150]],
	[[330, -100], [372, -60], [410, 0], [426, 60], [430, 140], [420, 200], [405, 250], [400, 300]],
	[[300, -150], [420, -150]], [[300, -132], [420, -132]], [[300, -114], [420, -114]], [[160, -88], [300, -88]],
]
## 山脊巨石线
const RIDGES := [
	[[110, 190], [130, 250], [120, 300], [140, 350], [130, 410]],
	[[-170, 500], [-130, 510], [-110, 535]],
]

# ---------------------------------------------------------------- 噪声 / 哈希
static var _nw: FastNoiseLite      ## 区块边界域扭曲
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
	return Vector2(_nw.get_noise_2d(p.x, p.y), _nw.get_noise_2d(p.x + 517.0, p.y - 291.0)) * 17.0


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


## 城市群外围地形（战区格子以外的 40 米格点）。A 海 / B 沙滩只出现在海岸，离战区很远。
static func terrain(p: Vector2) -> String:
	_init_noise()
	if p.y > (UNDER_Z - 5) * TILE:
		return "K"
	var cx := coast_x(p.y)
	if p.x > cx + 4.0:
		return "A"
	if p.x > cx - 20.0:
		return "B"
	var n := _nt.get_noise_2d(p.x, p.y)
	var n2 := _nt2.get_noise_2d(p.x, p.y)
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
	return cell_char(bi, bj)


## 一块栅格（世界坐标原点 o、宽 n 像素、分辨率 RAST）：返回字符码 PackedByteArray
static func _raster(o: Vector2, n: int) -> PackedByteArray:
	_init_noise()
	var out := PackedByteArray()
	out.resize(n * n)
	# 预取覆盖范围内（含扭曲余量）的格点种子与字符
	var span := n * RAST
	var c0 := Vector2i(floori((o.x - 24.0 + HALF) / CELL) - 1, floori((o.y - 24.0 + HALF) / CELL) - 1)
	var c1 := Vector2i(floori((o.x + span + 24.0 + HALF) / CELL) + 1, floori((o.y + span + 24.0 + HALF) / CELL) + 1)
	var cw := c1.x - c0.x + 1
	var ch_ := c1.y - c0.y + 1
	var sx := PackedFloat32Array()
	var sy := PackedFloat32Array()
	var sc := PackedByteArray()
	sx.resize(cw * ch_)
	sy.resize(cw * ch_)
	sc.resize(cw * ch_)
	for j in ch_:
		for i in cw:
			var s := _cell_seed(c0.x + i, c0.y + j)
			sx[j * cw + i] = s.x
			sy[j * cw + i] = s.y
			sc[j * cw + i] = cell_char(c0.x + i, c0.y + j).unicode_at(0)
	for y in n:
		var pz := o.y + (y + 0.5) * RAST
		for x in n:
			var px := o.x + (x + 0.5) * RAST
			var qx := px + _nw.get_noise_2d(px, pz) * 17.0
			var qz := pz + _nw.get_noise_2d(px + 517.0, pz - 291.0) * 17.0
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
		roads.append({"name": r.name, "pts": smooth(r.pts, 3.0, bool(r.get("closed", false))), "w": float(r.w), "dirt": str(r.kind) == "dirt",
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
	var sd := PackedVector2Array()
	for i in range(0, side.size(), 3):
		sd.append(side[i])
	roads.append({"name": RIVERSIDE.name, "pts": dense(sd, 3.0), "w": float(RIVERSIDE.w), "dirt": false, "kind": "art", "bridge": true})
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
		best = minf(best, p.distance_to(Vector2(l.x, l.y)) - l.z)
	return best


# ---------------------------------------------------------------- 街区（Voronoi）
static var _nbc := {}


static func nb_seed(i: int, j: int) -> Vector2:
	return Vector2((i + 0.5) * NB + (h2(i, j, 21) - 0.5) * 70.0, (j + 0.5) * NB + (h2(i, j, 22) - 0.5) * 70.0)


## 相邻两个街区之间的边界路：col 城区支路 / track 田间土路 / "" 没有路（两个城区街区之间也有三成不开路，街块直接相接）
static func col_kind(a: Vector2i, b: Vector2i) -> String:
	var na := nb_info(a)
	var nb2 := nb_info(b)
	var lo := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi := b if lo == a else a
	var r := h2(lo.x * 7 + hi.x * 3, lo.y * 13 + hi.y * 5, 31)
	var ua: bool = na.kind != "rural"
	var ub: bool = nb2.kind != "rural"
	if ua and ub:
		return "col" if r < 0.7 or na.kind != nb2.kind else ""
	if ua or ub:
		return "col"
	if r > 0.42 or na.ch in NO_COLLECTOR or nb2.ch in NO_COLLECTOR:
		return ""
	return "track"


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
		var d := 2.2
		if o != null:
			match col_kind(nb.k, o):
				"col": d = 8.2
				"track": d = 6.0
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
	var ang := _na.get_noise_2d(s.x, s.y) * 0.55 + (h2(k.x, k.y, 23) - 0.5) * 0.5
	var sp := Vector2(36, 26)
	if ch in URBAN:
		kind = "grid"
		match ch:
			"D": sp = Vector2(lerpf(42, 54, h2(k.x, k.y, 24)), lerpf(30, 38, h2(k.x, k.y, 25)))
			"R": sp = Vector2(lerpf(46, 58, h2(k.x, k.y, 24)), lerpf(32, 40, h2(k.x, k.y, 25)))
			"I": sp = Vector2(lerpf(100, 124, h2(k.x, k.y, 24)), lerpf(62, 80, h2(k.x, k.y, 25)))
			"H": sp = Vector2(lerpf(72, 88, h2(k.x, k.y, 24)), lerpf(48, 60, h2(k.x, k.y, 25)))
			"Y": sp = Vector2(140, 64)
			"M": sp = Vector2(lerpf(62, 76, h2(k.x, k.y, 24)), lerpf(46, 56, h2(k.x, k.y, 25)))
		if ch == "I" or ch == "Y":
			ang = (h2(k.x, k.y, 26) - 0.5) * 0.16          # 厂区、编组站顺着东西向铁路
		if ch == "M":
			kind = "mil"
		for rc: Dictionary in RADIAL:
			if ch == "D" and (in_convex(poly, Vector2(rc.c[0], rc.c[1])) or s.distance_to(Vector2(rc.c[0], rc.c[1])) < 70.0):
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
		for r in range(0, 44, 4):
			var steps := 1 if r == 0 else 12
			for k in steps:
				var a := TAU * k / steps + (h2(int(c[0]), int(c[1]), r) * 0.5)
				var q := base + Vector2(cos(a), sin(a)) * r
				if absf(q.x) > HALF - 18.0 or absf(q.y) > HALF - 18.0:
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
					out.append(Vector3(org.x + float(e.get("x", 0)), org.y + float(e.get("z", 0)), float(e.get("clear", 7.0)) + 3.0))
			for e: Array in md.get("extracts", []):
				out.append(Vector3(org.x + float(e[1]), org.y + float(e[2]), 10.0))
	return out


# ---------------------------------------------------------------- 转场口（相邻战区共用）
static var _gate_cache := {}
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}


## 战区 id 的 edge 边上转场口的位置（沿边坐标，米；两侧战区共用同一处，确定性）：
## 沿边每 8 米试一处，边两侧向内 6~30 米都得是空地（不是水、悬崖、建筑、遗迹院落）；有道路跨过边界的地方优先，其次靠近边的中段
static func gate_along(id: String, edge: String) -> float:
	var to: String = WorldLink.LINKS.get(id, {}).get(edge, "")
	var key := "%s|%s" % [id, edge]
	if _gate_cache.has(key):
		return _gate_cache[key]
	var ta := tile_of(id)
	var la := tile_layout(ta)
	var lb := {}
	if to != "":
		lb = tile_layout(tile_of(to))
	var o := origin(id)
	var inw: Vector2 = {"N": Vector2(0, 1), "S": Vector2(0, -1), "W": Vector2(1, 0), "E": Vector2(-1, 0)}[edge]
	var near_b: Array = []
	for L: Dictionary in [la, lb]:
		if L.is_empty():
			continue
		for b: Dictionary in L.bldgs:
			var lc: Vector2 = b.c - o
			if absf(absf(lc.x if edge in ["E", "W"] else lc.y) - HALF) < 50.0:
				near_b.append(obb_corners(b.c, b.ang, b.sx + 9.0, b.sz + 9.0))
	var clears := _clear_zones(ta)
	var best := 0.0
	var bs := -INF
	var t := -128.0
	while t <= 128.0:
		var ok := true
		var road := false
		for side in [1.0, -1.0]:
			if side < 0.0 and lb.is_empty():
				continue
			var L: Dictionary = la if side > 0.0 else lb
			for inset: float in [6.0, 12.0, 20.0, 30.0]:
				var e := _edge_local(edge, t)
				var q: Vector2 = o + e + inw * inset * side
				if water_dist(q, true) < 2.0 or dist_at(L, q) == "K":
					ok = false
					break
				for poly: PackedVector2Array in near_b:
					if in_convex(poly, q):
						ok = false
						break
				for cz: Vector3 in clears:
					if q.distance_to(Vector2(cz.x, cz.y)) < cz.z + 4.5 and cz.z > 12.0:
						ok = false
				if not ok:
					break
				var rg: SegGrid = L.road_grid
				if rg.edge_dist(q) < 1.0:
					road = true
			if not ok:
				break
		if ok:
			var sc := -absf(t) * 0.15 + (30.0 if road else 0.0)
			if sc > bs:
				bs = sc
				best = t
		t += 8.0
	_gate_cache[key] = best
	if to != "":
		_gate_cache["%s|%s" % [to, OPP[edge]]] = best
	return best


static func _edge_local(edge: String, along: float) -> Vector2:
	match edge:
		"N": return Vector2(along, -HALF)
		"S": return Vector2(along, HALF)
		"W": return Vector2(-HALF, along)
		_: return Vector2(HALF, along)


# ---------------------------------------------------------------- 格子布局
static var _tile_cache := {}


## 一个 360 米格子的确定性布局（世界坐标）
static func tile_layout(t: Vector2i) -> Dictionary:
	if _tile_cache.has(t):
		return _tile_cache[t]
	var f := features()
	var id := zone_of_tile(t)
	var c := Vector2(t.x * TILE, t.y * TILE)
	var rect := Rect2(c - Vector2(HALF, HALF), Vector2(TILE, TILE))
	var big := rect.grow(CLIP_PAD)
	var ro := rect.position - Vector2(RAST_PAD, RAST_PAD)
	var rn := int((TILE + RAST_PAD * 2.0) / RAST)
	var rast := _raster(ro, rn)
	var L := {"tile": t, "id": id, "rect": rect, "r_o": ro, "r_n": rn, "rast": rast}
	var clears := _clear_zones(t)
	var local_feat := _local_features(id)
	# 河流 / 湖 / 铁路 / 山脊：取与格子相交的
	var rivers: Array = []
	for r: Dictionary in f.rivers + local_feat.rivers:
		if _poly_hits(r.pts, big.grow(r.w)):
			rivers.append(r)
	var lakes: Array = []
	for l: Vector3 in f.lakes + local_feat.lakes:
		if big.grow(l.z).has_point(Vector2(l.x, l.y)):
			lakes.append(l)
	if id == "":
		lakes.append_array(_marsh_pools(t))
	var rails: Array = []
	for r: PackedVector2Array in f.rails + local_feat.rails:
		if _poly_hits(r, big):
			rails.append(r)
	var ridges: Array = []
	for r: PackedVector2Array in f.ridges + local_feat.ridges:
		if _poly_hits(r, big):
			ridges.append(r)
	L.rivers = rivers
	L.lakes = lakes
	L.rails = rails
	L.ridges = ridges
	# ---- 道路
	var roads: Array = []
	for r: Dictionary in f.roads + local_feat.roads:
		for run: PackedVector2Array in _clip_rect(r.pts, big):
			roads.append({"pts": run, "w": r.w, "dirt": r.dirt, "kind": r.kind, "bridge": r.bridge, "name": r.get("name", "")})
	var nbs := _tile_nbs(rect.grow(NB * 1.5))
	var col_done := {}
	var blocks: Array = []
	var fields: Array = []
	var parks: Array = []
	for k: Vector2i in nbs:
		var nb := nb_info(k)
		# 支路：街区边界（每对相邻街区只生成一次）
		var poly: PackedVector2Array = nb.poly
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
				roads.append({"pts": run, "w": w, "dirt": dirt, "kind": kind, "bridge": bridge})
		# 街区内部
		match str(nb.kind):
			"grid", "mil":
				_grid_streets(L, nb, roads, blocks, clears)
			"radial":
				_radial_blocks(L, nb, blocks)
			_:
				if nb.ch == "F":
					fields.append({"poly": inset(poly, 5.0), "ang": nb.ang, "k": k})
				elif nb.ch == "P":
					parks.append(centroid(poly))
	for rc: Dictionary in RADIAL:
		_radial_streets(L, rc, roads, clears)
	L.roads = roads
	# 道路空间索引（建筑避让用）
	var rg := SegGrid.new()
	rg.cell = 16.0
	rg.reach = 8.0
	for i in roads.size():
		rg.add_poly(roads[i].pts, roads[i].w * 0.5, i)
	L.road_grid = rg
	# ---- 建筑
	var bl: Array = []
	for blk: Dictionary in blocks:
		if not big.intersects(_poly_rect(blk.poly)):
			continue
		for b: Dictionary in _block_buildings(blk):
			if _bldg_ok(L, b, clears):
				bl.append(b)
	for fd: Dictionary in fields:
		if not big.intersects(_poly_rect(fd.poly)) or fd.poly.size() < 3:
			continue
		for b: Dictionary in _farm_buildings(fd):
			if _bldg_ok(L, b, clears):
				bl.append(b)
	L.blocks = blocks
	L.fields = fields
	L.parks = parks
	L.bldgs = bl
	_tile_cache[t] = L
	return L


## 战区窗口的布局（转成战区本地坐标，raid.gd 用）
static var _zone_cache := {}


static func zone_layout(id: String) -> Dictionary:
	if _zone_cache.has(id):
		return _zone_cache[id]
	var L := tile_layout(tile_of(id))
	var o := origin(id)
	var Z := {"id": id, "origin": o, "r_o": L.r_o - o, "r_n": L.r_n, "rast": L.rast}
	var roads: Array = []
	for r: Dictionary in L.roads:
		roads.append({"pts": _shift(r.pts, -o), "w": r.w, "dirt": r.dirt, "kind": r.kind, "bridge": r.bridge})
	Z.roads = roads
	var rivers: Array = []
	for r: Dictionary in L.rivers:
		rivers.append({"pts": _shift(_clip_one(r.pts, L.rect.grow(60)), -o), "w": r.w, "dry": r.dry, "name": r.get("name", "")})
	Z.rivers = rivers
	var lakes: Array = []
	for l: Vector3 in L.lakes:
		lakes.append(Vector3(l.x - o.x, l.y - o.y, l.z))
	Z.lakes = lakes
	var rails: Array = []
	for r: PackedVector2Array in L.rails:
		for run in _clip_rect(r, L.rect.grow(12)):
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
		if absf(c.x) < HALF + 20.0 and absf(c.y) < HALF + 20.0:
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
	var bl: Array = []
	for b: Dictionary in L.bldgs:
		var lc: Vector2 = b.c - o
		var cs := obb_corners(lc, b.ang, b.sx, b.sz)
		var inside := true
		for q in cs:
			if absf(q.x) > HALF - 1.5 or absf(q.y) > HALF - 1.5:
				inside = false
		if inside:
			var nb2: Dictionary = b.duplicate()
			nb2.c = lc
			bl.append(nb2)
	Z.bldgs = bl
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
		out.roads.append({"name": "", "pts": smooth(_offset_ctrl(cv[2], o), 3.0), "w": float(cv[0]), "dirt": bool(cv[1]),
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


## 道路采样点过滤：按道路类型去掉落在水面、悬崖、遗迹院落里的部分，返回保留的连续段
static func _filter_road(L: Dictionary, pts: PackedVector2Array, kind: String, w: float, clears: Array, bridge := false) -> Array:
	var keep := PackedByteArray()
	keep.resize(pts.size())
	for i in pts.size():
		var p := pts[i]
		var ok := true
		var ch := dist_at(L, p)
		match kind:
			"loc":
				ok = ch in URBAN and ch != "M"
			"col":
				ok = not (ch in NO_COLLECTOR)
			"track":
				ok = not (ch in NO_COLLECTOR) and ch != "M"
		if ok:
			var wd := water_dist(p, false)
			if wd < w * 0.5 + 1.0:
				# 干河床允许土路 / 支路涉过；有水的地方只有允许架桥的支路能过（之后由 raid 在河道交点建桥）
				var wet := water_dist(p, true) < w * 0.5 + 1.0
				if wet:
					ok = kind == "col" and bridge and _lake_free(p, w * 0.5 + 2.0) and _cross_angle_ok(pts, i)
				else:
					ok = kind != "loc"
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


static func _lake_free(p: Vector2, pad: float) -> bool:
	for l: Vector3 in features().lakes:
		if p.distance_to(Vector2(l.x, l.y)) < l.z + pad:
			return false
	return true


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
			cellp = inset(cellp, 4.8 if draw else 1.0)
			if cellp.size() >= 3:
				var bp := clip_convex(cellp, inner)
				var sub := 0
				for piece: PackedVector2Array in _split_by_art(bp):
					if piece.size() >= 3 and poly_area(piece) > 70.0:
						var ch := dist_at(L, centroid(piece))
						if ch in URBAN:
							blocks.append({"poly": piece, "ch": ch, "ang": ang, "kind": nb.kind, "nb": nb.k, "id": Vector3i(nb.k.x, nb.k.y, roundi(uu2 * 7.0 + vv2 * 131.0) * 4 + sub)})
					sub += 1
			vv2 += sp.y
		uu2 += sp.x


## 主干道 / 滨河路穿过街块时，沿道路的局部切线把街块切成两侧（各让出半个路宽 + 2.2 米），最多切两次
static func _split_by_art(poly: PackedVector2Array) -> Array:
	if poly.size() < 3:
		return []
	var f := features()
	var g: SegGrid = f.art
	var todo: Array = [[poly, 0]]
	var out: Array = []
	while not todo.is_empty():
		var it: Array = todo.pop_back()
		var pp: PackedVector2Array = it[0]
		var hit := -1
		var probe: Array = Array(pp)
		probe.append(centroid(pp))
		for i in pp.size():
			probe.append((pp[i] + pp[(i + 1) % pp.size()]) * 0.5)
		var best := INF
		for q: Vector2 in probe:
			var si := g.nearest(q, 2.0)
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
		var off: float = g.hw[hit] + 2.2
		for sgn: float in [1.0, -1.0]:
			var piece := clip_half(pp, a + n * off * sgn, n * sgn)
			if piece.size() >= 3 and poly_area(piece) > 40.0:
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
	for run in _filter_road(L, dense(PackedVector2Array([pa, pb]), 3.0), "loc", 7.0, clears):
		roads.append({"pts": run, "w": 7.0, "dirt": false, "kind": "loc", "bridge": false})


## 放射旧城：环路 + 辐射路（只铺在 radial 街区里）
static func _radial_streets(L: Dictionary, rc: Dictionary, roads: Array, clears: Array) -> void:
	var c := Vector2(rc.c[0], rc.c[1])
	var rr: float = rc.r
	if not L.rect.grow(CLIP_PAD).intersects(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0)):
		return
	var lines: Array = []
	for r: float in rc.rings:
		var pts := PackedVector2Array()
		var n := maxi(24, int(TAU * r / 3.0))
		for i in n + 1:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		lines.append([pts, 9.0 if r == rc.rings[0] else 7.0])
	var ns: int = rc.spokes
	for i in ns:
		var a := TAU * (i + 0.5) / ns
		var dir := Vector2(cos(a), sin(a))
		lines.append([dense(PackedVector2Array([c + dir * float(rc.rings[0]), c + dir * float(rc.r)]), 3.0), 7.0])
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


## 放射街区的街块：环与辐射路围成的扇形（取四角成凸四边形）∩ 街区
static func _radial_blocks(L: Dictionary, nb: Dictionary, blocks: Array) -> void:
	for rc: Dictionary in RADIAL:
		var c := Vector2(rc.c[0], rc.c[1])
		var rings: Array = [12.0] + rc.rings + [float(rc.r) + 26.0]
		var ns: int = rc.spokes
		var inner := nb_inner(nb)
		if inner.size() < 3:
			continue
		for ri in rings.size() - 1:
			var r0: float = float(rings[ri]) + (5.2 if ri > 0 else 0.0)
			var r1: float = float(rings[ri + 1]) - 4.6
			if r1 - r0 < 8.0:
				continue
			for si in ns:
				var a0 := TAU * (si + 0.5) / ns
				var a1 := TAU * (si + 1.5) / ns
				var da := 5.6 / r0
				var q := PackedVector2Array()
				# 扇形用 3 段折线近似外弧，保证是凸多边形
				q.append(c + Vector2(cos(a0 + da), sin(a0 + da)) * r0)
				for k in 4:
					var a := lerpf(a0 + 5.6 / r1, a1 - 5.6 / r1, k / 3.0)
					q.append(c + Vector2(cos(a), sin(a)) * r1)
				q.append(c + Vector2(cos(a1 - da), sin(a1 - da)) * r0)
				if ri == 0:
					q = PackedVector2Array([c] + Array(q).slice(1, q.size() - 1))
				var bp := clip_convex(q, inner)
				var sub := 0
				for piece: PackedVector2Array in _split_by_art(bp):
					if piece.size() >= 3 and poly_area(piece) > 70.0:
						var ch := dist_at(L, centroid(piece))
						if ch in URBAN:
							var am := (a0 + a1) * 0.5
							blocks.append({"poly": piece, "ch": ch, "ang": am + PI * 0.5, "kind": "radial", "nb": nb.k,
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
	"D": {"lot": [90.0, 210.0], "m": [0.25, 0.55], "kind": "bld", "h": [8.0, 22.0], "empty": 0.05, "court": 0.35},
	"R": {"lot": [110.0, 190.0], "m": [0.8, 1.3], "kind": "house", "h": [3.2, 6.4], "empty": 0.1, "court": 0.6},
	"H": {"lot": [380.0, 800.0], "m": [1.8, 3.0], "kind": "wh", "h": [6.5, 8.5], "empty": 0.18, "court": 0.3},
	"I": {"lot": [450.0, 1100.0], "m": [2.0, 3.5], "kind": "wh", "h": [7.0, 10.0], "empty": 0.1, "court": 0.12},
	"Y": {"lot": [700.0, 1200.0], "m": [3.0, 3.0], "kind": "shed", "h": [3.0, 3.6], "empty": 0.6, "court": 0.9},
	"M": {"lot": [380.0, 600.0], "m": [4.0, 6.0], "kind": "barrack", "h": [3.6, 3.6], "empty": 0.3, "court": 0.5},
}


## 一个街块的建筑（确定性：随机数按街块 id 定种）。街块按块的朝向递归切成大小不一的地块，每块地上一栋顺着街道朝向的楼；
## 门脸（本地 +z）朝向离它最近的街块边（即临街面）
static func _block_buildings(blk: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	var bid: Vector3i = blk.id
	rng.seed = int(h2(bid.x, bid.y, bid.z) * 2147483647.0) + 17
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
				if rng.randf() < 0.12:
					hgt = rng.randf_range(22.0, 30.0)
			"R":
				if rng.randf() < 0.16 and sx > 10.0 and sz > 8.0:
					kind = "apt"
					sx = minf(sx, rng.randf_range(11.0, 16.0))
					sz = minf(sz, rng.randf_range(9.0, 12.0))
					hgt = rng.randf_range(7.0, 12.0)
				else:
					sx = minf(sx, rng.randf_range(6.5, 9.5))
					sz = minf(sz, rng.randf_range(6.5, 9.0))
				# 小楼往临街面靠，后面留院子
				var vz := Vector2(-sin(ba), cos(ba))
				c = fit.c + vz * maxf(0.0, (float(fit.sz) - sz) * 0.5 - 0.5)
			"Y":
				sx = minf(sx, rng.randf_range(8.0, 12.0))
				sz = minf(sz, rng.randf_range(5.0, 7.0))
			"M":
				sx = minf(sx, rng.randf_range(14.0, 20.0))
				sz = minf(sz, 6.5)
			"I", "H":
				if sx * sz < 90.0:
					kind = "bld"
					hgt = rng.randf_range(4.0, 7.0)
				sx = minf(sx, 46.0)
				sz = minf(sz, 30.0)
		if sx < 4.0 or sz < 4.0:
			continue
		if not _all_in(lot, obb_corners(c, ba, sx, sz), 0.0):
			c = fit.c
		out.append({"c": c, "ang": ba, "sx": sx, "sz": sz, "h": hgt, "kind": kind, "ch": blk.ch})
	return out


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


## 农场：农舍 + 谷仓，放在田块里离中心不远处
static func _farm_buildings(fd: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(h2(fd.k.x, fd.k.y, 88) * 2147483647.0) + 3
	var out: Array = []
	if rng.randf() < 0.25:
		return out
	var c := centroid(fd.poly) + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
	var a: float = fd.ang
	var u := Vector2(cos(a), sin(a))
	var v := Vector2(-sin(a), cos(a))
	var h := {"c": c, "ang": a, "sx": 8.0, "sz": 7.0, "h": 4.5, "kind": "farm", "ch": "F"}
	var bn := {"c": c + u * 14.0 + v * 2.0, "ang": a, "sx": 12.0, "sz": 9.0, "h": 6.5, "kind": "barn", "ch": "F"}
	for b: Dictionary in [h, bn]:
		if _all_in(fd.poly, obb_corners(b.c, b.ang, b.sx, b.sz), 2.0):
			out.append(b)
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


## 建筑能否保留：不压路、不压水、不压铁轨、不进遗迹 / 地标 / 撤离点的清空圈
static func _bldg_ok(L: Dictionary, b: Dictionary, clears: Array) -> bool:
	var f := features()
	var cs := obb_corners(b.c, b.ang, b.sx, b.sz)
	var pts: Array = Array(cs)
	pts.append(b.c)
	for i in 4:
		pts.append((cs[i] + cs[(i + 1) % 4]) * 0.5)
	var rg: SegGrid = L.road_grid
	for p: Vector2 in pts:
		if rg.edge_dist(p) < 1.2 or water_dist(p) < 2.5 or f.rail.edge_dist(p) < 2.0:
			return false
	var r := maxf(b.sx, b.sz) * 0.5
	for cz: Vector3 in clears:
		if b.c.distance_to(Vector2(cz.x, cz.y)) < cz.z + r:
			return false
	return true
