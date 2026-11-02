extends "res://tests/lib/test_base.gd"
## 剧情系统：数据接口、图鉴解锁、场景播放、逐字字幕与名牌、立绘站位、回看记录、自动与跳过、
## Esc 在打字与记录面板中直接退出并复位状态、演出进度随存档往返并从该句续播退出、
## 行动中无线电通讯按事件触发且不阻断操作、行动中的剧情改走小窗、小窗不压住 L 形状态栏与雷达。
## godot --headless --path . -- --story / godot --path . -- --story（非无界面时截图到 review）
const START := "none"
const SCENE := "main_prologue"
const RAID_SCENE := "main_ch4_boss_in"

var _mouse0 := Input.MOUSE_MODE_VISIBLE


func run() -> void:
	await frames(2)
	var flow = Story.flow
	if not check(flow != null, "没有剧情流程节点"):
		return
	_mouse0 = Input.mouse_mode
	flow.set_auto(false, false)
	log_line("save=%s test=%s" % [GameData.save_path, GameData.test_mode])
	log_line("scenes main=%d side=%d comms=%d codex=%d chapters=%d" % [Story.data.get("main", {}).size(), Story.data.get("side", {}).size(),
		Story.data.get("comms", []).size(), Story.data.get("codex", {}).size(), Story.data.get("chapters", []).size()])
	if Story.data.get("main", {}).is_empty():
		log_line("剧情数据为空（剧情文本已清空），跳过场景演出断言")
		return
	if not check(Story.data.get("main", {}).has(SCENE), "主线场景数据没有读进来"):
		return
	if not check(Story.scene(SCENE).get("lines", []).size() >= 4, "场景台词数量不对"):
		return
	if not check(Story.character("laojiao").get("name_zh", "") == "米娅", "说话人表没有读进来"):
		return
	if not check(Story.codex_progress().x >= 10, "没有 unlock 条件的图鉴条目应在启动时解锁：%s" % [Story.codex_progress()]):
		return
	if not check(Story.codex_entries("enemy").size() >= 10, "图鉴按类别取条目的接口不对"):
		return

	# ---- 图鉴按事件解锁 ----
	Events.enemy_seen.emit("mantis", true, Vector3.ZERO)
	await frames(1)
	if not check(Story.is_codex_unlocked("enemy_mantis"), "遇到镰爪虫后图鉴没有解锁"):
		return
	if not check(not Story.is_codex_unlocked("enemy_abyss_queen"), "未触发的图鉴条目不应提前解锁"):
		return

	# ---- 事件触发：章节过场由数据里的 trigger 自动开演，once 场景不重播 ----
	flow.set_auto(true, false)
	Events.chapter_changed.emit("ch2")
	await frames(2)
	if not check(flow.player != null and str(flow.current) == "main_ch2_intro", "事件触发的场景没有自动播放：%s" % [flow.current]):
		return
	flow.player.press(KEY_S)
	await frames(2)
	if not check(flow.player == null and Story.was_seen("main_ch2_intro"), "触发的场景跳过后没有记入已看过"):
		return
	Events.chapter_changed.emit("ch2")
	await frames(2)
	if not check(flow.player == null, "once 场景在已看过之后又播了一遍"):
		return
	flow.set_auto(false, false)

	# ---- 播放场景：暂停、鼠标、逐字、名牌、立绘站位 ----
	if not check(Story.play_scene(SCENE), "播放场景失败"):
		return
	await frames(2)
	var p = flow.player
	if not check(p != null and p.is_open(), "没有打开对话演出"):
		return
	if not check(get_tree().paused, "演出期间游戏树应暂停"):
		return
	if not check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "演出期间鼠标应可见"):
		return
	if not check(p.line_count() >= 4 and p.current_line() == 0, "演出没有从第一句开始"):
		return
	if not check(p.name_text() == "", "旁白不应显示名牌"):
		return
	if not check(p.visible_text().length() < p._text_lbl.text.length(), "字幕没有逐字显示"):
		return
	_click(p)
	_click(p)
	await frames(2)
	if not check(p.current_line() == 1, "点击推进没有走到第二句"):
		return
	if not check(p.name_text() == Story.character("laojiao").get("name_zh", ""), "说话人名牌不对：%s" % p.name_text()):
		return
	if not check(str(p._slots.left.get("char", "")) == "laojiao", "说话人立绘没有站到左席"):
		return
	p._btn_ff.button_pressed = true
	p._toggle_ff()
	if not check(p._ff, "快进没有打开"):
		return
	p._btn_ff.button_pressed = false
	p._toggle_ff()
	if not check(not p._ff, "快进没有关上"):
		return
	await frames(24)
	await shot("story_01_dialogue.png")

	# ---- 回看记录 ----
	p.press(KEY_L)
	await frames(2)
	if not check(p.backlog_open(), "回看记录没有打开"):
		return
	if not check(p._hist.size() >= 2, "记录里没有已播过的台词"):
		return
	await shot("story_02_backlog.png")
	p.press(KEY_L)
	await frames(1)
	if not check(not p.backlog_open(), "回看记录没有关上"):
		return

	# ---- 自动播放开关 + 跳过 ----
	p.press(KEY_A)
	if not check(p.auto_on(), "自动播放没有打开"):
		return
	p.press(KEY_A)
	if not check(not p.auto_on(), "自动播放没有关上"):
		return
	p.press(KEY_S)
	await frames(2)
	if not check(flow.player == null, "跳过后演出没有关闭"):
		return
	if not check(not get_tree().paused and Input.mouse_mode == _mouse0, "跳过后没有恢复演出前的暂停与鼠标状态"):
		return
	if not check(Story.was_seen(SCENE), "跳过的场景没有记入已看过"):
		return
	if not check(Story.progress.is_empty(), "跳过后演出进度没有清空"):
		return

	# ---- Esc：开场动效尚未结束时也能直接退出 ----
	Story.play_scene("main_ch1_brief")
	var p2 = flow.player
	if not check(p2 != null, "第二个场景没有开始"):
		return
	p2.press(KEY_ESCAPE)
	await frames(2)
	if not check(flow.player == null and not get_tree().paused, "开场动效期间 Esc 不能直接退出"):
		return

	# ---- Esc：记录面板打开时直接结束整场演出 ----
	Story.play_scene("main_ch1_brief")
	await frames(2)
	var p3 = flow.player
	p3.press(KEY_L)
	await frames(1)
	p3.press(KEY_ESCAPE)
	await frames(2)
	if not check(flow.player == null and not get_tree().paused, "记录面板打开时 Esc 没有结束演出"):
		return

	# ---- 演出进度：随存档往返并从该句续播，续播后仍能退出 ----
	Story.play_scene(SCENE)
	await frames(2)
	var p4 = flow.player
	p4._advance()
	p4._advance()
	p4._advance()
	p4._advance()
	await frames(1)
	var line: int = p4.current_line()
	GameData.save_game()
	var saved := Story.progress.duplicate()
	Story.clear_progress()
	if not check(GameData.load_game(), "载入存档失败"):
		return
	if not check(str(Story.progress.get("scene", "")) == SCENE and int(Story.progress.get("line", -1)) == line,
			"演出进度没有随存档保存：%s" % [Story.progress]):
		return
	p4.press(KEY_ESCAPE)
	await frames(2)
	if not check(flow.player == null and not get_tree().paused, "退出演出后没有复位"):
		return
	if not check(Story.play_scene(SCENE, int(saved.get("line", 0))), "从存档进度续播失败"):
		return
	await frames(2)
	var p5 = flow.player
	if not check(p5 != null and p5.current_line() == line, "续播没有停在上次那一句：%s" % [p5.current_line() if p5 else -1]):
		return
	p5.press(KEY_ESCAPE)
	await frames(2)
	if not check(flow.player == null and not get_tree().paused and Input.mouse_mode == _mouse0, "续播的演出无法退出"):
		return

	# ---- 行动中：无线电通讯按事件触发，不暂停、不接管鼠标、不压住现有 HUD ----
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	var hud = raid.hud
	if not check(hud != null and hud.radio != null, "行动界面没有挂上无线电小窗"):
		return
	var window = hud.radio
	await frames(2)
	var vp := get_viewport().get_visible_rect().size
	var rr: Rect2 = window.window_rect()
	if not check(rr.size.x >= 300.0 and rr.size.y >= 60.0, "小窗尺寸不对：%s" % [rr]):
		return
	if not check(rr.position.x >= 0.0 and rr.position.y >= 0.0 and rr.end.y <= vp.y - 574.0, "小窗压住了左下 L 形状态栏：%s / %s" % [rr, vp]):
		return
	if not check(rr.end.x <= vp.x - 258.0, "小窗压住了右上雷达：%s / %s" % [rr, vp]):
		return
	window.clear()
	flow.set_auto(false, true)
	var mouse_before := Input.mouse_mode
	var tries := 0
	while not window.busy() and tries < 8:
		tries += 1
		Events.extract_cancelled.emit("撤离点 A")
		await frames(1)
	if not check(window.busy(), "事件总线触发的通讯没有进小窗"):
		return
	if not check(window.current_name() != "", "通讯没有显示说话人名字"):
		return
	if not check(_comm_has_text("extract_cancelled", window.current_text()), "通讯字幕不是 comms.json 的原文：%s" % window.current_text()):
		return
	if not check(not get_tree().paused, "通讯小窗不应暂停游戏"):
		return
	if not check(Input.mouse_mode == mouse_before, "通讯小窗不应接管鼠标"):
		return

	# ---- 行动中的剧情改走小窗，不开全屏演出 ----
	window.clear()
	flow.set_auto(true, false)
	Events.boss_appeared.emit("broodmother", "赤湖巢母")
	await frames(2)
	if not check(flow.player == null, "行动中的 Boss 剧情不应打开全屏演出"):
		return
	if not check(window.busy() and window.current_id().begins_with(RAID_SCENE + "_"), "行动中的剧情没有逐句进小窗：%s" % window.current_id()):
		return
	if not check(window.current_name() == Story.character("lina").get("name_zh", ""), "小窗说话人不对：%s" % window.current_name()):
		return
	if not check(Story.was_seen(RAID_SCENE), "行动中播过的场景没有记入已看过"):
		return
	await frames(20)
	await shot("story_03_radio.png")
	flow.set_auto(false, false)
	if not check(not get_tree().paused, "行动中播剧情后游戏树不应保持暂停"):
		return
	log_line("radio id=%s name=%s queued=%d" % [window.current_id(), window.current_name(), window.queued_count()])


func _comm_has_text(event: String, text: String) -> bool:
	for c in Story.data.get("comms", []):
		if typeof(c) == TYPE_DICTIONARY and str(c.get("event", "")) == event and str(c.get("zh", "")) == text:
			return true
	return false


## 模拟一次左键点击：走对话框背景的 gui_input 回调，与玩家点击是同一条推进路径
func _click(p) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	p._on_backdrop_input(ev)
