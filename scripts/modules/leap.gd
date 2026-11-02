extends RefCounted
## 位移跃迁：带抛物线的短距位移，落点前先做一次水平射线，避免跳进墙体。
## 位置由补间推进，不锁输入也不改物理状态；落地统一处理扬尘、镜头与落地音。

const A = preload("res://scripts/art.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")


## 从机甲当前位置朝 dir 跃出 dist 米，返回实际落点
static func launch(mech, dir: Vector3, dist: float, height := 2.2, dur := 0.5) -> Vector3:
	var from: Vector3 = mech.global_position
	var to: Vector3 = from + dir * dist
	var raid = mech.raid
	if raid != null:
		var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.4, to + Vector3.UP * 1.4, 1, [mech])
		var r: Dictionary = raid.get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			to = r.position - dir * 0.9
	to.y = from.y
	mech.velocity = Vector3.ZERO
	A.burst(raid.fx if raid != null else mech, Vector3(from.x, from.y + 0.2, from.z), {"amount": 12, "life": 0.8, "size": 1.2, "tex": A.smoke_tex(), "additive": false,
		"dir": Vector3(1, 0.2, 0), "spread": 180.0, "vmin": 2.5, "vmax": 5.0, "gravity": Vector3(0, 0.4, 0), "damp": 4.0,
		"c0": Color(0.76, 0.7, 0.6, 0.6), "c1": Color(0.7, 0.65, 0.58, 0.0), "grow0": 0.5, "grow1": 1.8}).flatness = 0.9
	var tw: Tween = mech.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(mech):
			return
		mech.global_position = from.lerp(to, t) + Vector3.UP * (sin(t * PI) * height), 0.0, 1.0, dur)
	tw.tween_callback(func():
		if not is_instance_valid(mech):
			return
		mech.land_t = 0.42
		mech.velocity = Vector3.ZERO
		if raid != null and is_instance_valid(raid):
			raid.shake = maxf(raid.shake, 0.14)
			A.burst(raid.fx, Vector3(to.x, to.y + 0.2, to.z), {"amount": 12, "life": 0.9, "size": 1.4, "tex": A.smoke_tex(), "additive": false,
				"dir": Vector3(1, 0.15, 0), "spread": 180.0, "vmin": 3.0, "vmax": 6.0, "gravity": Vector3(0, 0.4, 0), "damp": 5.0,
				"c0": Color(0.76, 0.7, 0.6, 0.65), "c1": Color(0.7, 0.65, 0.58, 0.0), "grow0": 0.5, "grow1": 2.0}).flatness = 0.9
			Audio.play_sfx("mech_land", to))
	return to
