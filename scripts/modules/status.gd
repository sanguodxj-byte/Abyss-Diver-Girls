extends RefCounted
## 虫群状态：减速、麻痹、脱离追击。
## 只使用敌人脚本已有的公开字段（data / state / act / home / aggro_range），不改 scripts\bug.gd 与核心敌人表。
##
## 减速不能就地改敌人数值：data 指向 GameData.ENEMIES 里的共享字典，改它会让同种敌人整体变慢。
## 这里把原字典留在 meta 上，给该敌人换一份缩放过的副本，到期再换回去。
## 同一种状态带令牌，重复施加时以最后一次的到期时间为准。

const SLOW_KEY := "_st_slow_tok"
const QUIET_KEY := "_st_quiet_tok"


static func _base(b) -> Dictionary:
	if b.has_meta("_st_base"):
		return b.get_meta("_st_base")
	var base: Dictionary = b.data
	b.set_meta("_st_base", base)
	return base


## 速度乘以 factor（0 = 原地麻痹），dur 秒后恢复
static func slow(b, factor: float, dur: float, tree: SceneTree) -> void:
	if b == null or not is_instance_valid(b) or b.get("data") == null:
		return
	var tok := int(b.get_meta(SLOW_KEY, 0)) + 1
	b.set_meta(SLOW_KEY, tok)
	var base := _base(b)
	var d: Dictionary = base.duplicate(true)
	d["speed"] = float(base.get("speed", 1.0)) * clampf(factor, 0.0, 1.0)
	b.data = d
	var id: int = b.get_instance_id()
	var t := tree.create_timer(dur)
	t.timeout.connect(func():
		var o = instance_from_id(id)
		if o == null or int(o.get_meta(SLOW_KEY, 0)) != tok:
			return
		if o.has_meta("_st_base"):
			o.data = o.get_meta("_st_base")
			o.remove_meta("_st_base"))


## 麻痹：停住并打断正在出手的动作
static func stun(b, dur: float, tree: SceneTree) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b.get("act") != null:
		b.act = ""
	slow(b, 0.0, dur, tree)


## 让范围内的追击者退回闲逛；quiet > 0 时在这段时间里把它们的索敌半径压到 0，脱离后需要重新发现机甲
static func disengage(bugs: Array, from: Vector3, radius: float, tree: SceneTree, quiet := 0.0) -> int:
	var n := 0
	for b in bugs:
		if b == null or not is_instance_valid(b):
			continue
		if b.global_position.distance_to(from) > radius:
			continue
		if str(b.state) == "chase":
			n += 1
		b.state = "idle"
		if b.get("act") != null:
			b.act = ""
		b.home = b.global_position
		if quiet > 0.0 and b.get("aggro_range") != null:
			if not b.has_meta("_st_aggro"):
				b.set_meta("_st_aggro", b.aggro_range)
			var tok := int(b.get_meta(QUIET_KEY, 0)) + 1
			b.set_meta(QUIET_KEY, tok)
			b.aggro_range = 0.0
			var id: int = b.get_instance_id()
			var t := tree.create_timer(quiet)
			t.timeout.connect(func():
				var o = instance_from_id(id)
				if o == null or int(o.get_meta(QUIET_KEY, 0)) != tok:
					return
				if o.has_meta("_st_aggro"):
					o.aggro_range = o.get_meta("_st_aggro")
					o.remove_meta("_st_aggro"))
	return n


## 范围内的虫子
static func near(tree: SceneTree, p: Vector3, radius: float) -> Array:
	var out: Array = []
	for b in tree.get_nodes_in_group("bugs"):
		if is_instance_valid(b) and b.global_position.distance_to(p) <= radius:
			out.append(b)
	return out
