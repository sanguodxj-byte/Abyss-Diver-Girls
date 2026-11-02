extends Node3D
## 动能回收炉 K-2 的回收过程：挂在机甲身上，按行走速度把震动换算成电能。
## 站着也有基础回收，跑起来更高；到期自己摘掉，不打断移动与开火。

const A = preload("res://scripts/art.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")

const SPARK := Color(0.55, 1.0, 0.82)

var mech
var life := 8.0
var idle_rate := 2.0
var move_rate := 7.0
var _tick := 0.0


func setup(m, dur: float, rate: float, run_rate: float) -> void:
	mech = m
	life = dur
	idle_rate = rate
	move_rate = run_rate


func _ready() -> void:
	add_to_group("kinetic_regen")


func _process(delta: float) -> void:
	if not is_instance_valid(mech) or mech.dead:
		queue_free()
		return
	life -= delta
	var sp := Vector2(mech.velocity.x, mech.velocity.z).length()
	var rate := move_rate if sp > 1.0 else idle_rate
	mech.energy = minf(mech.max_energy, mech.energy + rate * delta)
	_tick -= delta
	if _tick <= 0.0 and sp > 1.0:
		_tick = 0.35
		var p: Vector3 = mech.global_position
		A.burst(mech.raid.fx if mech.raid != null and is_instance_valid(mech.raid) else self, Vector3(p.x, 0.3, p.z),
			{"amount": 4, "life": 0.4, "size": 0.1, "additive": true, "vmin": 0.5, "vmax": 1.6, "gravity": Vector3(0, 0.6, 0),
			"c0": SPARK, "c1": Color(0.2, 0.6, 0.6, 0.0), "grow0": 0.8, "grow1": 0.2})
	if life <= 0.0:
		queue_free()
