extends "res://tests/lib/test_base.gd"
## 存档：测试运行使用按进程号命名的临时存档、不碰真实存档；存档分区（音量、剧情、成长）读写往返；
## 旧格式存档能载入；旧数据目录的存档迁移（复制、不覆盖、旧文件保留）。godot --headless --path . -- --saveio
const START := "none"


func run() -> void:
	await frames(1)
	if not check(GameData.is_test_run() and GameData.test_mode, "带测试参数运行时 test_mode 应为 true"):
		return
	var tmp: String = GameData.save_path
	if not check(tmp.begins_with(GameData.TEST_SAVE_DIR) and tmp.contains(str(OS.get_process_id())), "临时存档路径不对：%s" % tmp):
		return
	# 真实存档在测试运行中不被读写
	var real := "user://" + GameData.SAVE_FILE
	var real_before := _stamp(real)
	GameData.money = 4321
	GameData.seen_enemies = ["ling"]
	Audio.set_volume("Music", 0.33)
	Story.set_flag("saveio_flag", true)
	Story.unlock_codex("saveio_entry")
	Progress.state = {"saveio": 7}
	GameData.save_game()
	if not check(_stamp(real) == real_before, "save_game 改动了真实存档 %s" % real):
		return
	if not check(FileAccess.file_exists(tmp), "临时存档没有写出：%s" % tmp):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if not check(typeof(d) == TYPE_DICTIONARY and typeof(d.get("sections")) == TYPE_DICTIONARY, "存档里没有 sections"):
		return
	for sec in ["audio", "story", "progress"]:
		if not check(d.sections.has(sec), "存档分区缺少 %s" % sec):
			return
	# 往返：改掉内存里的值，再从存档载入
	GameData.money = 1
	GameData.seen_enemies = []
	Audio.set_volume("Music", 0.9)
	Story.flags = {}
	Story.codex = []
	Progress.state = {}
	if not check(GameData.load_game(), "load_game 失败"):
		return
	if not check(GameData.money == 4321 and GameData.seen_enemies == ["ling"], "基础存档字段往返不一致：money=%d seen=%s" % [GameData.money, GameData.seen_enemies]):
		return
	if not check(is_equal_approx(Audio.get_volume("Music"), 0.33), "音量没有随存档保存：%.2f" % Audio.get_volume("Music")):
		return
	if not check(Story.has_flag("saveio_flag") and Story.is_codex_unlocked("saveio_entry"), "剧情状态没有随存档保存"):
		return
	if not check(int(Progress.state.get("saveio", 0)) == 7, "局外成长状态没有随存档保存"):
		return
	# 本次运行没有登记的分区原样保留
	d.sections["other_team"] = {"x": 1}
	_write(tmp, JSON.stringify(d))
	GameData.load_game()
	GameData.save_game()
	var d2 = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if not check(int(d2.sections.get("other_team", {}).get("x", 0)) == 1, "未登记的存档分区在保存时丢失"):
		return
	# 旧格式存档（没有 sections / seen_enemies）
	_write(tmp, JSON.stringify({"money": 900, "stash": [], "cargo": [], "loadout": GameData.STARTER, "raids": 3, "extracts_ok": 1, "request": {}, "quality": 2, "render_style": 0, "map_id": "greyport"}))
	if not check(GameData.load_game(), "旧格式存档载入失败"):
		return
	if not check(GameData.money == 900 and GameData.seen_enemies.is_empty() and Story.flags.is_empty() and Progress.state.is_empty(), "旧格式存档载入后没有补默认值"):
		return
	if not check(is_equal_approx(Audio.get_volume("Music"), Audio.DEFAULT_VOLUME.Music), "旧格式存档载入后音量没有回到默认值"):
		return
	_migration()


## 旧目录迁移：在临时目录里模拟 app_userdata 下的新旧两个数据目录
func _migration() -> void:
	var root := ProjectSettings.globalize_path("%s/mig_%d" % [GameData.TEST_SAVE_DIR, OS.get_process_id()])
	var cur := root.path_join("Abyss Diver Girls")
	var legacy_name: String = GameData.LEGACY_DATA_DIRS[0]
	var old := root.path_join(legacy_name)
	DirAccess.make_dir_recursive_absolute(old)
	var old_file := old.path_join(GameData.SAVE_FILE)
	var cur_file := cur.path_join(GameData.SAVE_FILE)
	if not check(GameData.migrate_legacy_save(cur, [legacy_name]) == "", "没有旧存档时不应迁移"):
		return
	_write(old_file, "{\"money\": 777}")
	var src: String = GameData.migrate_legacy_save(cur, [legacy_name])
	var ok := src == old_file and FileAccess.file_exists(cur_file) and FileAccess.get_file_as_string(cur_file) == "{\"money\": 777}"
	ok = ok and FileAccess.file_exists(old_file) and FileAccess.get_file_as_string(old_file) == "{\"money\": 777}"
	_write(cur_file, "{\"money\": 1}")
	var again: String = GameData.migrate_legacy_save(cur, [legacy_name])
	ok = ok and again == "" and FileAccess.get_file_as_string(cur_file) == "{\"money\": 1}"
	for f in [cur_file, old_file]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	for dd in [cur, old, root]:
		DirAccess.remove_absolute(dd)
	check(ok, "旧目录存档迁移不符合预期（复制、旧文件保留、已有存档时不覆盖）")


func _stamp(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	return "%d/%d" % [FileAccess.get_modified_time(path), FileAccess.get_file_as_bytes(path).size()]


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
