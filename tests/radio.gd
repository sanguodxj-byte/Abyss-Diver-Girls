extends "res://tests/lib/test_base.gd"
## 行动左上角无线电小窗：通讯数据能按事件触发、显示说话人与字幕、播放立绘动画且不压其他 HUD
const START := "none"


func run() -> void:
	await frames(2)
	if not check(Story.data.get("comms", []).size() >= 20, "通讯数据太少：%s" % Story.data.get("comms", []).size()):
		return
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	var hud = raid.hud
	if not check(hud != null and hud.radio != null, "行动界面没有挂上无线电小窗"):
		return
	var win = hud.radio
	Story.flow.set_auto(false, true)
	win.clear()
	Events.extract_cancelled.emit("撤离点 A")
	await frames(3)
	if not check(win.busy(), "通讯没有进小窗"):
		return
	if not check(win.current_name() == "莉娜", "通讯说话人不对：%s" % win.current_name()):
		return
	if not check(win.current_tag() != "" and win.current_tag().begins_with("["), "通讯没有显示情绪标签：%s" % win.current_tag()):
		return
	if not check(win.current_text().contains("撤离中断"), "通讯字幕不是 comms.json 原文：%s" % win.current_text()):
		return
	if not check(win._avatar.active_clip() != "", "通讯立绘没有接上动画片段"):
		return
	# 对话时间编排与防重复：同事件短时间内重复触发不应复读入列
	var q_before: int = win.queued_count()
	Events.extract_cancelled.emit("撤离点 A")
	await frames(1)
	if not check(win.queued_count() == q_before, "冷却期内的同一通讯不应重复入队"):
		return
	# 战区固定出生点与移除未开放封堵校验
	if not check(raid.drop_points.size() >= 4, "战区候选出生点数量不足：%d" % raid.drop_points.size()):
		return
	var picked := {}
	for _k in 8:
		var dp: Vector3 = raid._drop_point()
		picked["%.1f_%.1f" % [dp.x, dp.z]] = true
	if not check(picked.size() == 1, "多次获取出生点未固定：%s" % [picked]):
		return
	for g: Dictionary in raid.world_link.gate_list():
		if not check(bool(g.get("open", false)), "边界转场口仍存在未开放封堵：%s" % [g]):
			return
	var vid := str(win._cur.get("voice", ""))
	if vid != "" and Audio.has_voice(vid) and not check(Audio.voice_id == vid, "通讯配音没有播放：%s" % Audio.voice_id):
		return
	var vp := get_viewport().get_visible_rect().size
	var rr: Rect2 = win.window_rect()
	if not check(rr.position.x >= 0.0 and rr.position.y >= 0.0 and rr.end.y <= vp.y - 574.0, "小窗压住左下状态栏：%s" % [rr]):
		return
	if not check(rr.end.x <= vp.x - 258.0, "小窗压住右上雷达：%s" % [rr]):
		return
	if not check(not get_tree().paused, "通讯小窗不应暂停游戏"):
		return
	# 逐条短片都能加载，且小窗里的视频确实在推进
	var d := DirAccess.open("res://assets/animations/radio")
	if not check(d != null, "没有无线电短片目录"):
		return
	var n := 0
	for fn in d.get_files():
		if not fn.ends_with(".ogv"):
			continue
		var st = load("res://assets/animations/radio/" + fn)
		if not check(st is VideoStream, "短片无法加载：%s" % fn):
			return
		n += 1
	if not check(n >= 10, "无线电短片数量不足：%d" % n):
		return
	var p0: float = win._avatar._vid.stream_position
	await wait(0.6)
	var p1: float = win._avatar._vid.stream_position
	if not check(win._avatar._vid.is_playing(), "小窗立绘没有处于播放状态"):
		return
	if not check(absf(p1 - p0) > 0.01, "小窗立绘播放位置没有推进：%.3f → %.3f" % [p0, p1]):
		return
	log_line("clips=%d playing %.2f→%.2f" % [n, p0, p1])
	log_line("radio %s / %s / clip=%s rect=%s" % [win.current_name(), win.current_text(), win._avatar.active_clip(), rr])
	await shot("radio_comm.png")
	log_line("radio ok")
