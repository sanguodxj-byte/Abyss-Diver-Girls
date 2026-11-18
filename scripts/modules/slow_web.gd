extends Node3D
## 减速网：逆足跃迁留在原地的粘性网，每隔一小段时间把范围内的虫子拖慢，到期收缩消失。
## 只减速，不造成伤害，因此用来脱离虫群而不是清场。

const A = preload("res://scripts/art.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")
const Status = preload("res://scripts/modules/status.gd")

var raid
var radius := 4.2
var life := 4.5
var factor := 0.35
var _tick := 0.0


func setup(r, rad: float, dur: float) -> void:
	raid = r
	add_to_group("coop_devices")
	set_meta("coop_device", "web")
	radius = rad
	life = dur


func _ready() -> void:
	A.ground_vfx(self, A.grime_stain_tex(), Color(0.42, 0.78, 0.74, 0.46), radius * 2.15, Vector3(0, 0.122, 0), false, 0.44, false, 3)
	var m := A.emit(Color(0.52, 0.92, 0.88), 1.6)
	var tips: Array = []
	for i in 11:
		var a := TAU * float(i) / 11.0 + randf_range(-0.22, 0.22)
		var r_len := radius * randf_range(0.68, 1.04)
		var tip := Vector3(cos(a) * r_len, 0.10 + randf() * 0.08, sin(a) * r_len)
		tips.append(tip)
		var mid := tip * randf_range(0.38, 0.56) + Vector3(randf_range(-0.25, 0.25), 0.18 + randf() * 0.10, randf_range(-0.25, 0.25))
		A.add(self, A.tube([Vector3(0, 0.10, 0), mid, tip], 0.036, 5, 5), m, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for i in tips.size():
		if i % 2 == 0:
			var a_pt: Vector3 = (tips[i] as Vector3) * 0.62
			var b_pt: Vector3 = (tips[(i + 1) % tips.size()] as Vector3) * 0.58
			A.add(self, A.tube([a_pt, (a_pt + b_pt) * 0.5 + Vector3(0, 0.08, 0), b_pt], 0.024, 4, 4), m, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.emitter(self, Vector3(0, 0.15, 0), {"amount": 14, "life": 1.2, "size": 0.25, "spread": 180.0, "vmin": 0.1, "vmax": 0.4, "gravity": Vector3(0, 0.4, 0),
		"c0": Color(0.45, 1.0, 0.95, 0.7), "c1": Color(0.2, 0.6, 0.6, 0.0), "grow0": 0.8, "grow1": 0.2})
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.08, 0.2)
	tw.tween_property(self, "scale", Vector3.ONE, 0.2)


func _process(delta: float) -> void:
	life -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.35
		if raid != null and is_instance_valid(raid):
			var tree: SceneTree = raid.get_tree()
			for b in Status.near(tree, global_position, radius):
				Status.slow(b, factor, 0.6, tree)
			Audio.play_sfx("web_pulse", global_position, {"vol": -10.0})
	if life <= 0.0:
		set_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
