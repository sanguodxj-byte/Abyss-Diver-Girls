extends "res://scripts/raid.gd"
## 大地图导出用的 raid 子类（只读）：按与 raid.start() 相同的顺序跑地图生成（_load_map → _build_map → 转场口 →
## 地形图 → 行动扩展 build），但用固定种子、不生成机甲 / HUD / 虫群 / 撤离点节点。raid.gd 本身不改。
## 生成结果与真实出击同一套代码：地形区块、道路、河湖、铁路、山脊、遗迹中心、地标、撤离候选点完全确定；
## 建筑 / 树木 / 杂物是 raid.rng 随机摆放（游戏每局 rng.randomize()），这里按种子逐个跑出来供统计。

var export_seed := 1


func gen(mid: String, s: int) -> Vector3:
	export_seed = s
	world = Node3D.new()
	add_child(world)
	fx = Node3D.new()
	add_child(fx)
	map_id = mid
	_load_map()
	var drop := _build_map()
	world_link = WorldLinkScript.new()
	world_link.name = "WorldLink"
	add_child(world_link)
	world_link.setup(self)
	_build_map_texture()
	world_link.paint_map(map_tex)
	_run_ext_build(drop)
	return drop


## _load_map 之后立刻定种子：start() 里 rng.randomize() 紧接着就是 _load_map，后面所有随机都走 rng
func _load_map() -> void:
	super._load_map()
	rng.seed = export_seed


## 导出时不生成虫子（军营 / 遗迹里的守卫虫）
func spawn_bug(_kind: String, _pos: Vector3, _cap := MAX_BUGS):
	return null
