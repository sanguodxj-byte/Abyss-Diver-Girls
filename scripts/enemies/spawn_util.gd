extends RefCounted
## 战区布置的公共步骤：先按 GameData.SPAWNS 里的密度与种类权重铺开常规虫群，再在指定区块里放下 Boss。
## 环境规则：虫群是固定分布，不生成定时虫潮；Boss 只在地图上的菌毯/弹坑区里伏着，等机甲靠近才苏醒。


## 铺常规虫群：分布表由 data\ext\enemies.gd 提供，这里只负责把它交给 raid 的按格生成流程
static func fill(raid, drop: Vector3) -> void:
	var sp: Dictionary = GameData.SPAWNS.get(str(raid.map_id), {})
	if sp.is_empty() or not sp.has("kinds"):
		raid.spawn_default_bugs(drop)
		return
	raid._spawn_table_bugs(drop, sp)


## 在给定区块字符里找一个离空投点足够远、且没有被建筑占住的落点
static func spot_in_zone(raid, want: Array, min_dist: float, drop: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := min_dist
	for j in 9:
		for i in 9:
			var t: String = str(raid.zones[j][i])
			if not want.has(t):
				continue
			var r: Rect2 = raid._cell_rect(i, j)
			var p: Vector3 = raid._spot_in(r, 7.0)
			if p == Vector3.INF:
				continue
			var d: float = Vector2(p.x - drop.x, p.z - drop.z).length()
			if d > best_d:
				best_d = d
				best = p
	return best


## 放 Boss：找不到合适的区块时退回任意空地；spawn_bug 受全场虫数上限约束，满了就这次不放
static func place_boss(raid, boss_id: String, zones: Array, min_dist: float, drop: Vector3) -> Node:
	var p := spot_in_zone(raid, zones, min_dist, drop)
	if p == Vector3.INF:
		p = raid._free_spot(9.0)
	if p == Vector3.INF or p == Vector3.ZERO:
		return null
	var b = raid.spawn_bug(boss_id, Vector3(p.x, 0.5, p.z))
	if b != null:
		b.home = Vector3(p.x, 0, p.z)
		b.rotation_degrees.y = randf() * 360.0
	return b
