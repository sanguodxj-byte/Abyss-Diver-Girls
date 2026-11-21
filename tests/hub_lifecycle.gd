extends "res://tests/lib/test_base.gd"
## 真实渲染下反复创建/释放机库，定位每次退图新增的 Texture RID 警告。
const START := "none"
const Monitor = preload("res://tests/lib/frame_monitor.gd")


func run() -> void:
	if not check(not headless(), "机库显存回归需要真实渲染"): return
	GameData.quality = 1
	Engine.max_fps = 60
	var cycles := 4
	var tag := "latest"
	var stable := "--expect-stable" in OS.get_cmdline_user_args()
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--cycles="): cycles = maxi(2, int(value.get_slice("=", 1)))
		if value.begins_with("--tag="): tag = value.get_slice("=", 1).validate_filename()
	var records: Array = []
	for cycle in cycles:
		main.show_hub()
		for node in main.hub.preview_root.get_children():
			if node is ReflectionProbe and "--no-probe" in OS.get_cmdline_user_args(): node.queue_free()
			if node is WorldEnvironment:
				if "--no-sky" in OS.get_cmdline_user_args():
					node.environment.sky = null
					node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
					node.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
				if "--no-ssao" in OS.get_cmdline_user_args(): node.environment.ssao_enabled = false
				if "--no-glow" in OS.get_cmdline_user_args(): node.environment.glow_enabled = false
		if "--no-msaa" in OS.get_cmdline_user_args(): main.hub.hangar_vp.msaa_3d = Viewport.MSAA_DISABLED
		await wait_real(3.0)
		var before := Monitor.memory()
		var old_id: int = main.hub.get_instance_id()
		main.hub.queue_free()
		main.hub = null
		await wait_real(3.0)
		if not check(not is_instance_id_valid(old_id), "机库节点没有释放"): return
		var after := Monitor.memory()
		records.append({"cycle": cycle, "before": before, "after": after})
		log_line("cycle %d before=%s after=%s" % [cycle, before, after])
	var out := FileAccess.open("res://review/hub_lifecycle_%s.json" % tag, FileAccess.WRITE)
	out.store_string(JSON.stringify(records, "  "))
	out.close()
	if stable:
		var growth := float(records[-1].after.vram_mb) - float(records[0].after.vram_mb)
		if not check(growth <= 0.5, "反复退图后显存基线增长 %.3f MiB" % growth): return
		for record in records:
			if not check(record.after.orphans == 0, "退图后存在孤儿节点"): return
		log_line("stable VRAM growth=%.3f MiB over %d cycles" % [growth, cycles])
