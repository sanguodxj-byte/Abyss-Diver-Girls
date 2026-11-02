extends "res://tests/lib/test_base.gd"
## 战区截图：godot --path . -- --mapshot [--map=<战区 id>]（也认环境变量 MAP）
## → review\mapshot_<战区>_hub.png / _play.png / _far.png / _bigmap.png

func run() -> void:
	var mid := OS.get_environment("MAP")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			mid = a.substr(6)
	if mid != "":
		if not check(GameData.MAPS.has(mid), "没有这个战区：%s" % mid):
			return
		GameData.map_id = mid
	await wait(0.3)
	await shot("mapshot_%s_hub.png" % GameData.map_id)
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	await wait(0.8)
	await shot("mapshot_%s_play.png" % GameData.map_id)
	raid.cam_zoom = 1.3
	await wait(1.2)
	await shot("mapshot_%s_far.png" % GameData.map_id)
	raid.hud.toggle_map()
	await wait(0.3)
	await shot("mapshot_%s_bigmap.png" % GameData.map_id)
	log_line("%s drop=%s bridges=%d blocks=%d fps=%d" % [GameData.map_id, raid.mech.global_position, raid.bridges.size(), raid.blocks.size(), Engine.get_frames_per_second()])
