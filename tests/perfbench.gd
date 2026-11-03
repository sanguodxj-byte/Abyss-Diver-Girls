extends "res://tests/lib/test_base.gd"
## 微基准（比整帧计时稳定得多）：
##  hud  — HUD 刷新函数单次耗时
##  ai   — 24 只虫子一次物理帧逻辑（含 move_and_slide）总耗时
##  lights — 双机枪连射 3 秒新建的灯光节点数
## godot --headless --path . -- --perfbench
const TIMEOUT := 600.0
const KINDS := ["ling", "ling", "spitter", "beetle", "ling", "bomber"]
var _new_lights := 0

func run() -> void:
	await wait(0.3)
	var raid = await deploy({"core": "core_std", "legs": "legs_biped", "arm_l": "arm_mg", "arm_r": "arm_mg", "back": "back_missile", "gen": "gen_reactor"})
	var m = raid.mech
	m.shield_time = 99999
	m.hp = 1e9
	m.max_hp = 1e9
	await frames(20)
	# HUD
	var hs: Array = []
	for r in 5:
		var t0 := Time.get_ticks_usec()
		for i in 200:
			raid.hud.refresh()
		hs.append((Time.get_ticks_usec() - t0) / 200.0 / 1000.0)
		await frames(2)
	hs.sort()
	# 虫子（定身，避免死亡/位置差异）
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	await frames(3)
	var bugs: Array = []
	for i in 24:
		var a := TAU * i / 24.0
		var b = raid.spawn_bug(KINDS[i % KINDS.size()], m.global_position + Vector3(cos(a) * 14.0, 0.5, sin(a) * 14.0))
		if b:
			bugs.append(b)
	await frames(10)
	for b in bugs:
		b.set_physics_process(false)
	var ai: Array = []
	for r in 5:
		var acc := 0
		for k in 30:
			var t0 := Time.get_ticks_usec()
			for b in bugs:
				if is_instance_valid(b):
					b._physics_process(1.0 / 60.0)
			acc += Time.get_ticks_usec() - t0
			await get_tree().physics_frame
		ai.append(acc / 30.0 / 1000.0)
	ai.sort()
	for b in bugs:
		if is_instance_valid(b):
			b.queue_free()
	await frames(5)
	# 灯光节点创建数
	get_tree().node_added.connect(func(n): if n is OmniLight3D: _new_lights += 1)
	raid.aim_override = m.global_position + Vector3(6, 1.8, -6)
	Input.action_press("fire_left")
	Input.action_press("fire_right")
	await wait(3.0)
	Input.action_release("fire_left")
	Input.action_release("fire_right")
	print("[perfbench] hud_refresh_ms=%.3f ai24_ms=%.3f bugs=%d new_lights_3s=%d" % [hs[2], ai[2], bugs.size(), _new_lights])
