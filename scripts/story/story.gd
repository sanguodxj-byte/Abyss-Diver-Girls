extends Node
## 剧情状态：剧情 flag、已看过的场景、已解锁的图鉴、当前章节、演出进度（存档分区 "story"），以及读进来的剧情数据。
## 事件触发、对话演出播放器、局内无线电通讯与图鉴解锁匹配在 scripts\story\story_flow.gd 里，通过这里的接口读写状态。
## 剧情数据格式见 scripts\story\story_data.gd。

const StoryData = preload("res://scripts/story/story_data.gd")
const FlowScript = preload("res://scripts/story/story_flow.gd")
const Growth = preload("res://scripts/progression/growth.gd")

var flags := {}
var seen: Array = []
var codex: Array = []
var chapter := ""
var progress := {}        ## 演出进度 {"scene": 场景 id, "line": 已显示的台词序号}；中断后载入时从这一句继续
var data := {}            ## story_data.load_all() 的结果：characters / main / side / comms / codex / chapters
var load_errors: Array = []
var flow                  ## StoryFlow：事件触发、对话演出、局内通讯、图鉴解锁的调度者


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = StoryData.load_all(load_errors)
	GameData.register_section("story", _save_state, _load_state)
	flow = FlowScript.new()
	flow.name = "StoryFlow"
	add_child(flow)


func set_flag(flag: String, value: Variant = true) -> void:
	if flags.has(flag) and typeof(flags[flag]) == typeof(value) and flags[flag] == value:
		return
	flags[flag] = value
	Events.flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func mark_seen(scene_id: String) -> void:
	if not seen.has(scene_id):
		seen.append(scene_id)


func was_seen(scene_id: String) -> bool:
	return seen.has(scene_id)


## 解锁图鉴条目；第一次解锁时返回 true 并广播 codex_unlocked
func unlock_codex(entry_id: String) -> bool:
	if codex.has(entry_id):
		return false
	codex.append(entry_id)
	Events.codex_unlocked.emit(entry_id)
	return true


func is_codex_unlocked(entry_id: String) -> bool:
	return codex.has(entry_id)


func set_chapter(chapter_id: String) -> void:
	if chapter_id == chapter:
		return
	chapter = chapter_id
	Events.chapter_changed.emit(chapter_id)


## 场景 id 在主线或支线数据里的内容；没有时返回空字典
func scene(scene_id: String) -> Dictionary:
	for part in ["main", "side"]:
		var d: Dictionary = data.get(part, {})
		if d.has(scene_id):
			return d[scene_id]
	return {}


func character(cid: String) -> Dictionary:
	var c: Dictionary = data.get("characters", {}).get(cid, {})
	if cid == Growth.PROTAGONIST and not c.is_empty():
		var row := c.duplicate()
		row["name_zh"] = Growth.player_name()
		return row
	return c


# ---------- 演出进度 ----------
## 记录当前演出停在哪一句；随存档保存，载入后由 story_flow 从这里续播，Esc / 跳过随时可结束。
func set_progress(scene_id: String, line: int) -> void:
	progress = {"scene": scene_id, "line": max(0, line)}


func clear_progress() -> void:
	progress = {}


# ---------- 档案图鉴的数据接口（界面由界面团队实现） ----------
## 按类别取图鉴条目：[{id, cat, ref, title, body, unlocked}]；cat 为空时返回全部，顺序与 codex.json 一致
func codex_entries(cat := "") -> Array:
	var out: Array = []
	for id in data.get("codex", {}):
		var e: Dictionary = data.codex[id]
		if cat != "" and str(e.get("cat", "")) != cat:
			continue
		var row: Dictionary = e.duplicate()
		row["id"] = str(id)
		row["unlocked"] = codex.has(str(id))
		row["title"] = Growth.subst(str(row.get("title", "")))
		row["body"] = Growth.subst(str(row.get("body", "")))
		out.append(row)
	return out


## 单条图鉴条目；没有时返回空字典
func codex_entry(entry_id: String) -> Dictionary:
	var e = data.get("codex", {}).get(entry_id, {})
	if typeof(e) != TYPE_DICTIONARY:
		return {}
	var row: Dictionary = e.duplicate()
	row["id"] = entry_id
	row["unlocked"] = codex.has(entry_id)
	row["title"] = Growth.subst(str(row.get("title", "")))
	row["body"] = Growth.subst(str(row.get("body", "")))
	return row


## 图鉴解锁进度：x = 已解锁条数，y = 总条数
func codex_progress() -> Vector2i:
	return Vector2i(codex.size(), data.get("codex", {}).size())


## 章节定义（chapters.json 的一项）；没有时返回空字典。文案里的主角占位符已替换。
func chapter_data(chapter_id: String) -> Dictionary:
	for ch in data.get("chapters", []):
		if typeof(ch) == TYPE_DICTIONARY and str(ch.get("id", "")) == chapter_id:
			var row: Dictionary = ch.duplicate()
			row["title"] = Growth.subst(str(row.get("title", "")))
			row["synopsis"] = Growth.subst(str(row.get("synopsis", "")))
			return row
	return {}


# ---------- 演出与通讯的入口（供界面与测试调用） ----------
## 立刻播放一个场景（不排队；自动播放关闭时也生效）；场景 id 不存在时返回 false
func play_scene(scene_id: String, line := 0) -> bool:
	return flow != null and flow.play_now(scene_id, line)


## 立刻播放一条通讯；id 不存在时返回 false
func play_comms(comm_id: String) -> bool:
	return flow != null and flow.play_comms_now(comm_id)


## 对话演出是否正在播放（演出期间游戏树暂停、鼠标可见）
func is_playing() -> bool:
	return flow != null and flow.is_playing()


## 行动界面把无线电小窗挂上来 / 卸下
func attach_radio(win) -> void:
	if flow != null:
		flow.attach_radio(win)


func detach_radio(win) -> void:
	if flow != null:
		flow.detach_radio(win)


func _save_state() -> Dictionary:
	return {"flags": flags.duplicate(true), "seen": seen.duplicate(), "codex": codex.duplicate(), "chapter": chapter,
		"progress": progress.duplicate()}


func _load_state(d: Dictionary) -> void:
	flags = Dictionary(d.get("flags", {})).duplicate(true)
	seen = Array(d.get("seen", [])).duplicate()
	codex = Array(d.get("codex", [])).duplicate()
	chapter = str(d.get("chapter", ""))
	var p = d.get("progress", {})
	progress = Dictionary(p).duplicate() if typeof(p) == TYPE_DICTIONARY else {}
