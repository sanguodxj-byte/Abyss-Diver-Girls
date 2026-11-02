extends Node3D
## 声波诱饵信标：落地后按节奏播放机炮噪音，把周围的虫子引向自己。
## 虫子会把它当成机甲（同样的 target / dead 字段），咬坏后爆成一团电磁火花；
## 到期或被咬碎时把还活着的追击者交还给机甲那边重新索敌。

const A = preload("res://scripts/art.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")

const LURE := Color(1.0, 0.72, 0.22)

var raid
var life := 12.0
var hp := 70.0
var dead := false
var radius := 26.0
var _pulse_t := 0.0
var _lured: Array = []
var _lamp: MeshInstance3D


func setup(r) -> void:
	raid = r


func _ready() -> void:
	add_to_group("decoy")
	# 三脚架 + 喇叭口 + 天线 + 闪灯
	var m := A.metal(Color(0.24, 0.25, 0.27))
	for i in 3:
		var a := TAU * i / 3.0
		A.add(self, A.bevel_box(Vector3(0.07, 0.8, 0.07), 0.02), m, Vector3(cos(a) * 0.26, 0.4, sin(a) * 0.26), Vector3(sin(a) * 16.0, 0, -cos(a) * 16.0))
	A.add(self, A.cyl(0.16, 0.24, 0.2, 14), m, Vector3(0, 0.86, 0))
	A.add(self, A.cyl(0.34, 0.32, 0.1, 18), A.metal(Color(0.32, 0.33, 0.36)), Vector3(0, 1.12, 0), Vector3(0, 0, 0))
	A.add(self, A.cyl(0.02, 0.6, 0.02, 6), m, Vector3(0.18, 1.5, 0))
	_lamp = A.add(self, A.sphere(0.07, -1, 12), A.emit(LURE, 4.0), Vector3(0.18, 1.82, 0), Vector3.ZERO, Vector3.ONE, false)
	A.ground_decal(self, A.ring_tex(), Color(LURE.r, LURE.g, LURE.b, 0.7), radius * 1.1, Vector3(0, 0.06, 0), true)
	A.emitter(self, Vector3(0, 1.15, 0), {"amount": 10, "life": 1.4, "size": 0.3, "spread": 60.0, "vmin": 0.4, "vmax": 1.2, "gravity": Vector3(0, 0.8, 0),
		"c0": Color(1.0, 0.8, 0.3, 0.6), "c1": Color(0.6, 0.3, 0.0, 0.0), "grow0": 0.6, "grow1": 1.4})
	Audio.play_sfx("decoy_deploy", global_position)
	_pulse()
	_pulse_t = 1.2


func _process(delta: float) -> void:
	if dead:
		return
	life -= delta
	_pulse_t -= delta
	var k := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
	if is_instance_valid(_lamp):
		_lamp.scale = Vector3.ONE * (0.8 + 0.3 * k)
	if _pulse_t <= 0.0:
		_pulse_t = 1.4
		_pulse()
	if life <= 0.0:
		_expire(false)


## 一次鸣叫：范围内的虫子改追信标
func _pulse() -> void:
	if raid == null or not is_instance_valid(raid):
		return
	raid.alert_noise(global_position, radius)
	for b in get_tree().get_nodes_in_group("bugs"):
		if b == null or not is_instance_valid(b):
			continue
		if b.global_position.distance_to(global_position) > radius:
			continue
		b.target = self
		b.state = "chase"
		if not _lured.has(b):
			_lured.append(b)
	FX.ring(raid, global_position, LURE, 3.2, 0.7)
	FX.light(raid, global_position + Vector3(0, 1.2, 0), LURE, 2.0, 6.0, 0.2)


func take_damage(amount: float, _from := Vector3.ZERO) -> void:
	if dead:
		return
	hp -= amount
	A.burst(raid.fx if raid else self, global_position + Vector3(0, 1.0, 0), {"amount": 6, "life": 0.3, "size": 0.1, "vmin": 2.0, "vmax": 5.0,
		"gravity": Vector3(0, -14, 0), "damp": 1.5, "c0": Color(1.0, 0.9, 0.6), "c1": Color(1.0, 0.4, 0.1, 0.0)})
	if hp <= 0.0:
		_expire(true)


func _expire(exploded: bool) -> void:
	if dead:
		return
	dead = true
	set_process(false)
	for b in _lured:
		if is_instance_valid(b) and b.target == self:
			b.state = "idle"
			b.home = b.global_position
			b.target = raid.mech if raid != null and is_instance_valid(raid) and is_instance_valid(raid.mech) else null
	if exploded and raid != null and is_instance_valid(raid):
		raid.explode(global_position, 2.4, 18.0, "explosion")
	else:
		Audio.play_sfx("decoy_off", global_position)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
