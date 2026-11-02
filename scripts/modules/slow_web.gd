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
	radius = rad
	life = dur


func _ready() -> void:
	A.ground_decal(self, A.blob_tex(), Color(0.35, 0.95, 0.9, 0.5), radius * 2.4, Vector3(0, 0.07, 0), true)
	A.ground_decal(self, A.ring_tex(), Color(0.4, 1.0, 0.95, 0.85), radius * 2.1, Vector3(0, 0.08, 0), true)
	var m := A.emit(Color(0.45, 1.0, 0.95), 2.4)
	for i in 8:
		var a := TAU * i / 8.0 + randf() * 0.3
		var tip := Vector3(cos(a) * radius, 0.12 + randf() * 0.1, sin(a) * radius)
		var pts := [Vector3.ZERO, tip * 0.45 + Vector3(randf_range(-0.2, 0.2), 0.25, randf_range(-0.2, 0.2)), tip]
		A.add(self, A.tube(pts, 0.045, 5, 5), m, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
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
