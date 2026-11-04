extends "res://tests/lib/test_base.gd"
## 地图生成耗时基准：godot --headless --path . -- --perf_build
## 逐个地表战区真实 raid.start() 3 次，打印每次的生成耗时（_load_map → _bake_static）、world 子树节点数、占地矩形数与
## MultiMesh 实例数，最后给出各战区平均值。结果打印为 [perf_build] 行。
## 可选 --maps=greyport,ironbelt 只测这几个战区；--runs=N 改测量次数

const START := "none"
const TIMEOUT := 600.0
const RaidScript = preload("res://scripts/raid.gd")
const RUNS := 3


func run() -> void:
	await frames(2)
	var Fac = load("res://scripts/factions/factions.gd")
	Fac.rovers_enabled = false
	var total := 0.0
	var n := 0
	var only: Array = []
	var runs := RUNS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			only = Array(a.substr(7).split(","))
		elif a.begins_with("--runs="):
			runs = int(a.substr(7))
	for mid: String in GameData.map_ids():
		if not only.is_empty() and not only.has(mid):
			continue
		var ms := 0.0
		var nodes := 0
		var blocks := 0
		var mmi := 0
		for k in runs:
			GameData.map_id = mid
			var raid = RaidScript.new()
			var t0 := Time.get_ticks_usec()
			add_child(raid)
			raid.start(GameData.STARTER.duplicate(), [])
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			ms += dt
			nodes += raid._count_nodes(raid.world)
			blocks += raid.blocks.size()
			mmi += raid.world.find_children("*", "MultiMeshInstance3D", true, false).size()
			raid.queue_free()
			await frames(3)
		log_line("%s start=%.0fms nodes=%d blocks=%d multimesh=%d" % [mid, ms / runs, nodes / runs, blocks / runs, mmi / runs])
		total += ms / runs
		n += 1
	log_line("AVG start=%.0fms over %d maps" % [total / n, n])
	Fac.rovers_enabled = true
