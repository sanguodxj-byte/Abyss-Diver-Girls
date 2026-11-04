extends StaticBody3D
## 虫巢：玩家靠近时不断孵化虫子，摧毁后留下高价值残骸。

const Prof = preload("res://scripts/prof.gd")

const A = preload("res://scripts/art.gd")

var hp := 260.0
var raid
var spawn_t := 4.0
var children_alive: Array = []
var pulse: MeshInstance3D
var t := 0.0


func setup(r) -> void:
	raid = r
	add_to_group("nests")
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.8
	sh.height = 4.0
	cs.shape = sh
	cs.position.y = 2.0
	add_child(cs)
	var M := A.chitin(Color(0.32, 0.22, 0.14))
	var M2 := A.chitin(Color(0.18, 0.13, 0.09))
	A.add(self, A.cyl(4.5, 0.06, 6.5, 32), A.creep(), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	# 主体：几层鼓胀的囊
	A.add(self, A.sphere(1.8, 2.4, 20), M, Vector3(0, 0.9, 0), Vector3.ZERO, Vector3(1, 1, 1))
	A.add(self, A.sphere(1.2, 2.2, 18), M2, Vector3(0.2, 2.0, -0.1), Vector3(0, 0, 8))
	for i in 6:
		var a := TAU * i / 6.0
		A.add(self, A.cyl(0.0, 2.6, 0.4, 7), M2, Vector3(cos(a) * 1.5, 1.1, sin(a) * 1.5), Vector3(sin(a) * 30.0, 0, -cos(a) * 30.0))
		A.add(self, A.sphere(0.35, -1, 10), A.emit(Color(1.0, 0.55, 0.15), 1.6), Vector3(cos(a + 0.5) * 1.6, 0.5, sin(a + 0.5) * 1.6), Vector3.ZERO, Vector3.ONE, false)
	pulse = A.add(self, A.sphere(0.75, -1, 18), A.emit(Color(1.0, 0.5, 0.12), 0.9), Vector3(0.2, 3.0, -0.1), Vector3.ZERO, Vector3.ONE, false)
	A.emitter(self, Vector3(0, 3.0, 0), {"amount": 12, "life": 2.5, "size": 0.2, "spread": 60.0, "vmin": 0.4, "vmax": 1.0, "gravity": Vector3(0, 0.4, 0),
		"c0": Color(0.7, 0.62, 0.5, 0.6), "c1": Color(0.4, 0.35, 0.3, 0.0), "grow0": 1.0, "grow1": 0.2})
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.5
	l.omni_range = 9.0
	l.position.y = 3.2
	add_child(l)


func _physics_process(delta: float) -> void:
	var _pt := Prof.t0()
	_physics_tick(delta)
	Prof.add("phys.nest", _pt)


func _physics_tick(delta: float) -> void:
	t += delta
	pulse.scale = Vector3.ONE * (1.0 + sin(t * 3.0) * 0.15)
	children_alive = children_alive.filter(func(b): return is_instance_valid(b) and not b.dying)
	if raid == null or raid.mech == null or raid.mech.dead:
		return
	var d := global_position.distance_to(raid.mech.global_position)
	var lk := "nest_%d" % get_instance_id()
	if d > 42.0:
		if Audio.has_loop(lk):
			Audio.loop_stop(lk, 0.8)
		return
	if not Audio.has_loop(lk):
		Audio.loop_start(lk, "nest_loop", self)
	spawn_t -= delta
	if spawn_t <= 0.0 and children_alive.size() < 5:
		spawn_t = randf_range(5.0, 8.0)
		var k := "ling" if randf() < 0.75 else "spitter"
		var b = raid.spawn_bug(k, global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2)))
		if b:
			b.state = "chase"
			b.spawn_t = 0.7
			children_alive.append(b)
			Audio.play_sfx("nest_spawn", global_position + Vector3(0, 1.5, 0))


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	pulse.scale = Vector3.ONE * 1.4
	if hp <= 0.0:
		Audio.play_sfx("nest_destroyed", global_position + Vector3(0, 1.5, 0))
		raid.on_nest_destroyed(self)
		queue_free()
	else:
		Audio.play_sfx("nest_hurt", global_position + Vector3(0, 1.5, 0))
