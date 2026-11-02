extends "res://tests/lib/test_base.gd"
## 音频文件清单：遍历合并后音效表里全部登记的变体文件、全部音乐槽文件（含各战区按约定读取的探索曲槽），
## 每个不存在的文件打印一行「[audio_manifest] MISSING 路径」（项目内相对路径），再打印「[audio_manifest] TOTAL 文件数」。
## 缺文件不算失败。godot --headless --path . -- --audio_manifest
const START := "none"
const AudioReg = preload("res://scripts/audio/audio_registry.gd")


func run() -> void:
	await frames(1)
	var paths: Array = []
	for id: String in GameData.SFX:
		for p in AudioReg.sfx_paths(id, GameData.SFX):
			if not paths.has(p):
				paths.append(p)
	var slots: Array = GameData.MUSIC.keys()
	for mid: String in GameData.MAPS:
		var slot := str(GameData.MAPS[mid].get("music", mid + "_explore"))
		if not slots.has(slot):
			slots.append(slot)
	for slot: String in slots:
		var p := AudioReg.music_path(slot, GameData.MUSIC)
		if not paths.has(p):
			paths.append(p)
	for p: String in paths:
		if not FileAccess.file_exists(p):
			print("[%s] MISSING %s" % [test_name, p.trim_prefix("res://").replace("/", "\\")])
	print("[%s] TOTAL %d" % [test_name, paths.size()])
