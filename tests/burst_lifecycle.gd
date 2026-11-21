extends "res://tests/lib/test_base.gd"
## 相同效果应复用；切换父场景后，静态池不得留下已释放场景的节点引用。
const START := "none"
const Art = preload("res://scripts/art.gd")


func run() -> void:
	var initial := Art._burst_pool.size()
	for cycle in 3:
		var owner := Node3D.new()
		add_child(owner)
		var opts := {"pool": "lifecycle", "amount": 3, "life": 0.08}
		var first := Art.burst(owner, Vector3.ZERO, opts)
		# 无界面渲染器不推进 CPU 粒子；用同一个 finished 信号进入正式回池路径。
		if headless():
			first.emitting = false
			first.finished.emit()
		else:
			if not check(await until(func(): return not first.visible, 3.0), "一次性粒子没有回池"): return
		var again := Art.burst(owner, Vector3.ONE, opts)
		if not check(again == first, "相同参数没有复用已完成粒子"): return
		if headless():
			again.emitting = false
			again.finished.emit()
		else:
			if not check(await until(func(): return not again.visible, 3.0), "重播粒子没有回池"): return
		owner.queue_free()
		await frames(3)
	log_line("pool keys before=%d after three scene exits=%d" % [initial, Art._burst_pool.size()])
	if not check(Art._burst_pool.size() == initial, "静态粒子池残留已退出场景的键与节点引用"): return
