extends Node3D
## 子弹/火焰/酸液/导弹。每帧用射线检测，避免高速穿透。

const Prof = preload("res://scripts/prof.gd")
const Growth = preload("res://scripts/progression/growth.gd")

var vel := Vector3.ZERO
var dmg := 10.0
var ap := 0.0                ## 穿甲系数（0.0 ~ 0.85）：按武器穿深削减目标护甲与正面折射
var life := 1.0
var mask := 1
var pierce := false
var homing := false
var aoe := 0.0
var color := Color(1, 0.8, 0.3)
var raid
var exclude: Array = []
var grow := 0.0
var tail: Node3D = null      ## 曳光尾迹：从弹尾向后延伸到 tail_len
var tail_len := 0.0
var tail_offset := 0.0
var traveled := 0.0
var body_node: Node3D = null ## 3D 实体弹头/导弹/酸囊节点（用于膛线自旋或脉动翻滚）
var spin_spd := 0.0          ## 沿弹轴 (-Z) 的自旋角速度（弧度/秒）
var tumble := Vector3.ZERO   ## 三轴翻滚角速度（用于酸液团/火焰团）
## 命中音效 id；空串时按命中对象自动选 hit_chitin / hit_metal，"-" 为不发声（火焰等高频命中）
var hit_sfx := ""
## 开火者（玩家机甲 / 流浪者 / 队友）：命中虫子或机甲时记为它的仇恨来源，用于反击与击杀归属
var source = null
## 对象池键（raid._tracer 设置）；非空时寿命结束 / 命中后回池而不是删除
var pool_key := ""


## 复用前把所有飞行状态恢复成新建时的默认值（外观节点保留）
func reset_state() -> void:
	vel = Vector3.ZERO
	dmg = 10.0
	ap = 0.0
	life = 1.0
	mask = 1
	pierce = false
	homing = false
	aoe = 0.0
	color = Color(1, 0.8, 0.3)
	exclude = []
	grow = 0.0
	tail_offset = 0.0
	traveled = 0.0
	hit_sfx = ""
	source = null
	scale = Vector3.ONE
	if body_node != null and is_instance_valid(body_node):
		body_node.rotation = Vector3.ZERO


func _retire() -> void:
	if pool_key != "" and raid != null and is_instance_valid(raid) and raid.recycle_projectile(self):
		return
	queue_free()


func _physics_process(delta: float) -> void:
	var _pt := Prof.t0()
	_physics_tick(delta)
	Prof.add("phys.projectile", _pt)


func _physics_tick(delta: float) -> void:
	if get_meta("net_visual", false):
		position += vel * delta
		if tail:
			traveled += vel.length() * delta
			var L := clampf(traveled - tail_offset, 0.0, tail_len)
			tail.visible = L > 0.012
			tail.scale.z = maxf(L, 0.01)
			tail.position.z = tail_offset + L * 0.5
		if body_node != null and is_instance_valid(body_node) and spin_spd != 0.0:
			body_node.rotation.z += spin_spd * delta
		life -= delta
		if life <= 0: queue_free()
		return
	if homing:
		var t = raid.nearest_bug(global_position, 30.0)
		if t:
			var want: Vector3 = (t.global_position + Vector3(0, 1.0, 0) - global_position).normalized() * vel.length()
			vel = vel.lerp(want, clamp(4.0 * delta, 0.0, 1.0))
		else:
			vel.y = lerp(vel.y, 0.0, 3.0 * delta)
	var from := global_position
	var to := from + vel * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		var c = r.collider
		if aoe > 0.0:
			raid.explode(r.position, aoe, dmg)
			_retire()
			return
		var organic: bool = c.is_in_group("bugs") or c.is_in_group("nests")
		if source != null and is_instance_valid(source) and "aggressor" in c:
			c.aggressor = source
		if c.has_method("take_damage"):
			if c.is_in_group("bugs"):
				c.take_damage(dmg, from, ap)
			else:
				c.take_damage(dmg)
			if source != null and is_instance_valid(source) and source.has_method("_is_local_actor") and source._is_local_actor():
				Growth.record_skill_xp("ab_firearm", clampf(dmg * 0.025, 0.14, 1.15))
		raid.impact(r.position, r.normal, color, c.has_method("take_damage"), vel, organic)
		if hit_sfx != "-":
			Audio.play_sfx(hit_sfx if hit_sfx != "" else ("hit_chitin" if organic else "hit_metal"), r.position)
		if pierce and c.has_method("take_damage"):
			exclude.append(c.get_rid())
		else:
			_retire()
			return
	global_position = to
	if tail:
		traveled += vel.length() * delta
		var L := clampf(traveled - tail_offset, 0.0, tail_len)
		tail.visible = L > 0.012
		tail.scale.z = maxf(L, 0.01)
		tail.position.z = tail_offset + L * 0.5
	if vel.length() > 0.1:
		look_at(global_position + vel, Vector3.UP if abs(vel.normalized().y) < 0.95 else Vector3.FORWARD)
	if body_node != null and is_instance_valid(body_node):
		if spin_spd != 0.0:
			body_node.rotation.z += spin_spd * delta
		if tumble != Vector3.ZERO:
			body_node.rotation += tumble * delta
	if grow > 0.0:
		scale += Vector3.ONE * grow * delta
	life -= delta
	if life <= 0.0:
		if aoe > 0.0:
			raid.explode(global_position, aoe, dmg)
		_retire()
