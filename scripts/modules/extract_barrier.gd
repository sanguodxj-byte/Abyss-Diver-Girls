extends Node3D
## 撤离屏障：四根立柱撑开的阻滞力场，持续把范围内的虫群拖慢。
## 只减速、不伤害，也不影响机甲与运输机；到期后立柱熄灯并自行消失。

const A = preload("res://scripts/art.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")
const Status = preload("res://scripts/modules/status.gd")

const FIELD := Color(0.45, 0.95, 0.8)

var raid
var life := 14.0
var radius := 6.0
var factor := 0.4
var _tick := 0.0
var _posts: Array = []


func setup(r, rad: float, dur: float) -> void:
	raid = r
	radius = rad
	life = dur


func _ready() -> void:
	add_to_group("extract_barrier")
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var p := Vector3(cos(a) * radius * 0.82, 0.0, sin(a) * radius * 0.82)
		A.add(self, A.bevel_box(Vector3(0.12, 1.5, 0.12), 0.02), A.metal(Color(0.22, 0.24, 0.24)), p + Vector3(0, 0.75, 0))
		A.add(self, A.torus(0.12, 0.17, 14), A.emit(FIELD, 2.0), p + Vector3(0, 1.55, 0), Vector3(90, 0, 0), Vector3(1, 0.5, 1), false)
		_posts.append(p)
	A.ground_decal(self, A.ring_tex(), Color(FIELD.r, FIELD.g, FIELD.b, 0.8), radius * 2.1, Vector3(0, 0.05, 0), true)
	A.ground_decal(self, A.blob_tex(), Color(FIELD.r, FIELD.g, FIELD.b, 0.18), radius * 2.4, Vector3(0, 0.04, 0), true)
	A.emitter(self, Vector3(0, 0.2, 0), {"amount": 18, "life": 1.6, "size": 0.3, "spread": 180.0, "vmin": 0.2, "vmax": 0.8, "gravity": Vector3(0, 0.4, 0),
		"c0": Color(0.5, 1.0, 0.85, 0.6), "c1": Color(0.2, 0.6, 0.55, 0.0), "grow0": 0.6, "grow1": 1.4})
	Audio.play_sfx("barrier_deploy", global_position)


func _process(delta: float) -> void:
	life -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.4
		if raid != null and is_instance_valid(raid):
			var tree: SceneTree = raid.get_tree()
			for b in Status.near(tree, global_position, radius):
				Status.slow(b, factor, 0.8, tree)
			FX.ring(raid, global_position, FIELD, radius, 0.5)
	if life <= 0.0:
		set_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(0.85, 0.6, 0.85), 0.4)
		tw.tween_callback(queue_free)
