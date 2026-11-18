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
	add_to_group("coop_devices")
	set_meta("coop_device", "barrier")
	radius = rad
	life = dur


func _ready() -> void:
	add_to_group("extract_barrier")
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var p := Vector3(cos(a) * radius * 0.82, 0.0, sin(a) * radius * 0.82)
		A.add(self, A.bevel_box(Vector3(0.14, 1.42, 0.14), 0.02), A.metal(Color(0.20, 0.22, 0.22)), p + Vector3(0, 0.71, 0))
		A.add(self, A.bevel_box(Vector3(0.22, 0.16, 0.22), 0.02), A.metal(Color(0.14, 0.15, 0.16)), p + Vector3(0, 1.48, 0))
		A.add(self, A.bevel_box(Vector3(0.08, 0.18, 0.08), 0.01), A.emit(FIELD.darkened(0.15), 1.6), p + Vector3(0, 1.56, 0), Vector3.ZERO, Vector3.ONE, false)
		_posts.append(p)
	A.add(self, A.quad(radius * 2.04, radius * 2.04), A.extract_pad_mat(Color(FIELD.r * 0.85, FIELD.g * 0.85, FIELD.b * 0.85, 0.48), 0.44, 3), Vector3(0, 0.126, 0), Vector3.ZERO, Vector3.ONE, false)
	A.emitter(self, Vector3(0, 0.25, 0), {"tex": A.smoke_tex(), "additive": false, "soft_depth": 0.45, "amount": 14, "life": 1.8, "size": 0.65,
		"spread": 180.0, "vmin": 0.25, "vmax": 0.85, "gravity": Vector3(0, 0.35, 0),
		"c0": Color(0.45, 0.78, 0.68, 0.24), "c1": Color(0.22, 0.42, 0.38, 0.0), "grow0": 0.5, "grow1": 1.6, "box": Vector3(radius * 0.55, 0.1, radius * 0.55)})
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
			if int(round(life * 2.5)) % 3 == 0:
				FX.ring(raid, global_position, Color(FIELD.r, FIELD.g, FIELD.b, 0.36), radius, 0.55)
	if life <= 0.0:
		set_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(0.85, 0.6, 0.85), 0.4)
		tw.tween_callback(queue_free)
