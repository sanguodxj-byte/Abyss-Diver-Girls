extends "res://tests/lib/test_base.gd"
## 模块化装配测试：godot --headless --path . -- --modular
## 1) 每个槽位遍历所有模块（含扩展数据里的新模块），逐个热插拔，检查接口一致、插座齐全、muzzle 有效、有专属建模脚本
## 2) 有窗口时在机库里截拆解视图与换装动画：review\modular_explode.png / modular_swap.png / modular_after.png
const MV = preload("res://scripts/mech_visual.gd")
const K = preload("res://scripts/modules/kit.gd")

func run() -> void:
	var errors := 0
	var lo: Dictionary = GameData.STARTER.duplicate()
	var root := MV.build(lo, false)
	add_child(root)
	var by_slot := {}
	for id in GameData.MODULES:
		var s: String = GameData.MODULES[id].slot
		by_slot[s] = by_slot.get(s, []) + [id]
	var swaps := 0
	for slot in MV.SLOTS:
		var key: String = "arm" if slot.begins_with("arm") else slot
		for id in by_slot.get(key, []):
			lo[slot] = id
			MV.apply(root, lo, false)
			swaps += 1
			var m: Node3D = root.get_meta("modules").get(slot)
			if m == null:
				printerr("[modular] 缺少模块 ", slot, " ", id); errors += 1; continue
			if not ResourceLoader.exists("res://scripts/modules/%s.gd" % id):
				printerr("[modular] 没有专属建模脚本 ", id); errors += 1
			if slot != "legs" and str(m.get_meta("iface")) != K.IFACES[slot]:
				printerr("[modular] 接口不符 ", id); errors += 1
			if slot != "legs" and str(m.get_parent().get_meta("iface", "HP-C1")) != str(m.get_meta("iface")):
				printerr("[modular] 插座/插头不匹配 ", id); errors += 1
			var core: Node3D = root.get_meta("modules").get("core")
			for s2 in ["arm_l", "arm_r", "back", "gen"]:
				if core.get_node_or_null("Socket_" + s2) == null:
					printerr("[modular] 躯干缺插座 ", s2); errors += 1
			for s3 in ["arm_l", "arm_r"]:
				var mz = root.get_meta("muzzles").get(s3)
				if mz == null or not is_instance_valid(mz):
					printerr("[modular] muzzle 失效 ", s3); errors += 1
		lo[slot] = GameData.STARTER[slot]
		MV.apply(root, lo, false)
	# 子模块在换躯干后必须仍然挂在新躯干上
	lo["core"] = "core_heavy"
	MV.apply(root, lo, false)
	var arm: Node3D = root.get_meta("modules")["arm_l"]
	if arm.get_parent().get_parent() != root.get_meta("modules")["core"]:
		printerr("[modular] 换躯干后左臂没有转插"); errors += 1
	await get_tree().process_frame
	log_line("swaps=%d errors=%d" % [swaps, errors])
	root.queue_free()
	if not check(errors == 0 and swaps > 0, "装配错误 %d 处（换装 %d 次）" % [errors, swaps]):
		return
	if not headless() and main.hub:
		var hub = main.hub
		await wait(1.0)
		hub._toggle_explode()
		await wait(1.2)
		await shot("modular_explode.png")
		hub._toggle_explode()
		await wait(0.8)
		GameData.loadout["arm_r"] = "arm_laser"
		GameData.loadout["back"] = "back_missile"
		hub.refresh()
		await wait(0.3)
		await shot("modular_swap.png")
		await wait(1.0)
		await shot("modular_after.png")
