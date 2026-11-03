extends Node3D
## 子弹/火焰/酸液/导弹。每帧用射线检测，避免高速穿透。

var vel := Vector3.ZERO
var dmg := 10.0
var life := 1.0
var mask := 1
var pierce := false
var homing := false
var aoe := 0.0
var color := Color(1, 0.8, 0.3)
var raid
var exclude: Array = []
var grow := 0.0
var tail: Node3D = null      ## 曳光尾迹：从枪口逐渐拉长到 tail_len
var tail_len := 0.0
var traveled := 0.0
## 命中音效 id；空串时按命中对象自动选 hit_chitin / hit_metal，"-" 为不发声（火焰等高频命中）
var hit_sfx := ""
## 开火者（玩家机甲 / 流浪者 / 队友）：命中虫子或机甲时记为它的仇恨来源，用于反击与击杀归属
var source = null


func _physics_process(delta: float) -> void:
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
			queue_free()
			return
		var organic: bool = c.is_in_group("bugs") or c.is_in_group("nests")
		if source != null and is_instance_valid(source) and "aggressor" in c:
			c.aggressor = source
		if c.has_method("take_damage"):
			c.take_damage(dmg)
		raid.impact(r.position, r.normal, color, c.has_method("take_damage"), vel)
		if hit_sfx != "-":
			Audio.play_sfx(hit_sfx if hit_sfx != "" else ("hit_chitin" if organic else "hit_metal"), r.position)
		if pierce and c.has_method("take_damage"):
			exclude.append(c.get_rid())
		else:
			queue_free()
			return
	global_position = to
	if tail:
		traveled += vel.length() * delta
		var L := minf(traveled, tail_len)
		tail.scale.z = maxf(L, 0.01)
		tail.position.z = L * 0.5
	if vel.length() > 0.1:
		look_at(global_position + vel, Vector3.UP if abs(vel.normalized().y) < 0.95 else Vector3.FORWARD)
	if grow > 0.0:
		scale += Vector3.ONE * grow * delta
	life -= delta
	if life <= 0.0:
		if aoe > 0.0:
			raid.explode(global_position, aoe, dmg)
		queue_free()
