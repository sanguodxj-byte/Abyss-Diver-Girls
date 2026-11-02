extends RefCounted
## 剧情数据：读取 res://data/story 下的 JSON 文件并校验格式。播放与触发由剧情系统实现，这里只管数据。
##
## 文件与归属（每个文件一个顶层对象，编剧各写各的文件）：
##   characters.json   说话人表   {"characters": {角色 id: {"name_zh", "name_ja", "expressions": [表情 id...]}}}
##   characters_<作者>.json  同一格式的追加说话人表，按文件名顺序并入 characters.json（各编剧各写一份，id 不许重复）
##   main_scenes.json  主线场景   {"scenes": {场景 id: 场景}}
##   side_scenes.json  支线与机库日常场景，格式同主线
##   comms.json        局内通讯   {"comms": [通讯条目...]}
##   codex.json        档案图鉴   {"entries": {条目 id: 图鉴条目}}
##   chapters.json     章节       {"chapters": [章节...]}（数组顺序即章节顺序）
##
## 场景：{"chapter": 章节 id 或 "", "title": 中文标题, "trigger": {"event": 事件名, "when": 条件} 或省略,
##        "once": true/false, "bg": 背景插画 id 或 "", "lines": [台词...]}
## 台词：{"speaker": 角色 id（"" 为旁白）, "expr": 表情 id（"" 为默认立绘）,
##        "zh": 中文字幕, "ja": 日语配音文本, "voice": 语音 id（"" 为不配音）}
## 通讯条目：{"id": 唯一 id, "event": 事件名（scripts\events.gd 的信号名，或 Events.emit_custom 的事件名）,
##        "when": 条件, "speaker": 角色 id, "expr": 表情 id, "zh": 中文, "ja": 日语, "voice": 语音 id,
##        "priority": 整数（越大越先播，同时触发时只播最高的）, "chance": 0..1（省略为 1）, "cooldown": 秒（同一条目两次播出的最小间隔，省略为 0）}
## 图鉴条目：{"cat": item / module / enemy / map / poi / character / lore, "ref": 对应注册表 id（lore 可为 ""）,
##        "title": 中文标题, "body": 中文正文, "unlock": {"event": 事件名, "when": 条件} 或省略（省略 = 一开始就解锁）}
## 章节：{"id": 章节 id, "title": 中文标题, "maps": [战区 id...], "unlock": {"flag": 剧情 flag} 或省略,
##        "intro": 场景 id 或 "", "outro": 场景 id 或 ""}
## 条件 when：{参数名: 值}，与事件参数逐项相等（值为数组时匹配其中任一项）；另可写
##        "flag": flag 名（该 flag 为真）、"not_flag": flag 名、"chapter": 章节 id、"map": 战区 id。
## 剧情 flag 与已看过的场景、已解锁的图鉴存进存档分区 "story"：{"flags": {}, "seen": [], "codex": [], "chapter": ""}。
##
## id 一律小写 ASCII：字母、数字、下划线。语音 id 全局唯一，配音文件为 res://assets/audio/voice/<语音 id>.mp3。
## 几个文件由不同作者并行编写，id 带文件前缀以免撞名：主线场景 main_、支线场景 side_、通讯条目 comm_；
## 场景台词的语音 id 为 <场景 id>_<三位序号>（如 main_ch1_brief_003），通讯条目的语音 id 为 <通讯 id>（一条一句）。

const DIR := "res://data/story"
const FILES := {
	"characters": ["characters.json", "characters", TYPE_DICTIONARY],
	"main": ["main_scenes.json", "scenes", TYPE_DICTIONARY],
	"side": ["side_scenes.json", "scenes", TYPE_DICTIONARY],
	"comms": ["comms.json", "comms", TYPE_ARRAY],
	"codex": ["codex.json", "entries", TYPE_DICTIONARY],
	"chapters": ["chapters.json", "chapters", TYPE_ARRAY],
}
## 说话人表按作者拆分：characters.json 之后按文件名顺序并入同目录的 characters_<作者>.json，
## 顶层同为 {"characters": {}}；同一个角色 id 只认先读到的那份，重复时报错。
const CHARACTER_FILE_PREFIX := "characters_"
const CODEX_CATS := ["item", "module", "enemy", "map", "poi", "character", "lore"]


## 读一个文件的顶层内容；文件缺失或格式错误时返回空容器，错误写进 errors
static func load_part(part: String, errors: Array = []) -> Variant:
	var f: Array = FILES[part]
	var path := DIR.path_join(f[0])
	var empty: Variant = {} if f[2] == TYPE_DICTIONARY else []
	if not FileAccess.file_exists(path):
		errors.append("%s 不存在" % path)
		return empty
	var j := JSON.new()
	var err := j.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		errors.append("%s 第 %d 行：%s" % [path, j.get_error_line(), j.get_error_message()])
		return empty
	var d = j.data
	if typeof(d) != TYPE_DICTIONARY or not d.has(f[1]) or typeof(d[f[1]]) != f[2]:
		errors.append("%s 顶层应为 {\"%s\": %s}" % [path, f[1], "{}" if f[2] == TYPE_DICTIONARY else "[]"])
		return empty
	return d[f[1]]


## 说话人表：characters.json 加各作者的 characters_<作者>.json
static func load_characters(errors: Array = []) -> Dictionary:
	var out: Dictionary = load_part("characters", errors)
	var extra: Array = []
	for fn in DirAccess.get_files_at(DIR):
		if fn.begins_with(CHARACTER_FILE_PREFIX) and fn.ends_with(".json"):
			extra.append(fn)
	extra.sort()
	for fn: String in extra:
		var path := DIR.path_join(fn)
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) != OK:
			errors.append("%s 第 %d 行：%s" % [path, j.get_error_line(), j.get_error_message()])
			continue
		var d = j.data
		if typeof(d) != TYPE_DICTIONARY or typeof(d.get("characters")) != TYPE_DICTIONARY:
			errors.append("%s 顶层应为 {\"characters\": {}}" % path)
			continue
		for cid in d.characters:
			if out.has(cid):
				errors.append("%s：角色 id「%s」已在 characters.json 里登记，这份被忽略" % [path, cid])
				continue
			out[cid] = d.characters[cid]
	return out


static func load_all(errors: Array = []) -> Dictionary:
	var out := {}
	for part in FILES:
		out[part] = load_characters(errors) if part == "characters" else load_part(part, errors)
	return out


static func valid_id(s: String) -> bool:
	if s == "":
		return false
	for c in s:
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true


## 校验全部剧情数据，返回问题列表（空 = 通过）；data 为空时读取 data\story 下的文件
static func validate(data: Dictionary = {}) -> Array:
	var errors: Array = []
	var d: Dictionary = data if not data.is_empty() else load_all(errors)
	var chars: Dictionary = d.characters
	var voices := {}
	for cid in chars:
		var c = chars[cid]
		if not valid_id(str(cid)):
			errors.append("characters：角色 id「%s」不是小写 ASCII" % cid)
		if typeof(c) != TYPE_DICTIONARY or str(c.get("name_zh", "")) == "":
			errors.append("characters.%s：缺少 name_zh" % cid)
			continue
		for e in c.get("expressions", []):
			if not valid_id(str(e)):
				errors.append("characters.%s：表情 id「%s」不是小写 ASCII" % [cid, e])
	var scene_ids := {}
	for part in ["main", "side"]:
		var scenes: Dictionary = d[part]
		for sid in scenes:
			var where := "%s.%s" % [FILES[part][0], sid]
			if not valid_id(str(sid)):
				errors.append("%s：场景 id 不是小写 ASCII" % where)
			if scene_ids.has(sid):
				errors.append("%s：场景 id 与 %s 重复" % [where, scene_ids[sid]])
			scene_ids[sid] = where
			var s = scenes[sid]
			if typeof(s) != TYPE_DICTIONARY or typeof(s.get("lines")) != TYPE_ARRAY:
				errors.append("%s：缺少 lines 数组" % where)
				continue
			_check_trigger(s.get("trigger"), where, errors)
			var i := 0
			for ln in s.lines:
				_check_line(ln, "%s.lines[%d]" % [where, i], chars, voices, errors, true)
				i += 1
	var comm_ids := {}
	var k := 0
	for c in d.comms:
		var where := "comms.json[%d]" % k
		k += 1
		if typeof(c) != TYPE_DICTIONARY:
			errors.append("%s：不是对象" % where)
			continue
		var cid := str(c.get("id", ""))
		if not valid_id(cid) or comm_ids.has(cid):
			errors.append("%s：id「%s」缺失、不是小写 ASCII 或重复" % [where, cid])
		comm_ids[cid] = true
		if str(c.get("event", "")) == "":
			errors.append("%s：缺少 event" % where)
		if c.has("when") and typeof(c.when) != TYPE_DICTIONARY:
			errors.append("%s：when 应为对象" % where)
		_check_line(c, where, chars, voices, errors, false)
	var codex: Dictionary = d.codex
	var refs := {"item": GameData.ITEMS, "module": GameData.MODULES, "enemy": GameData.ENEMIES, "map": GameData.MAPS, "poi": GameData.POIS, "character": chars}
	for eid in codex:
		var where := "codex.json.%s" % eid
		var e = codex[eid]
		if not valid_id(str(eid)):
			errors.append("%s：条目 id 不是小写 ASCII" % where)
		if typeof(e) != TYPE_DICTIONARY:
			errors.append("%s：不是对象" % where)
			continue
		var cat := str(e.get("cat", ""))
		if not (cat in CODEX_CATS):
			errors.append("%s：cat「%s」不在 %s 里" % [where, cat, CODEX_CATS])
		elif cat != "lore" and not (refs[cat] as Dictionary).has(str(e.get("ref", ""))):
			errors.append("%s：ref「%s」在 %s 注册表里不存在" % [where, e.get("ref", ""), cat])
		if str(e.get("title", "")) == "" or str(e.get("body", "")) == "":
			errors.append("%s：缺少 title 或 body" % where)
		_check_trigger(e.get("unlock"), where, errors)
	var chap_ids := {}
	k = 0
	for ch in d.chapters:
		var where := "chapters.json[%d]" % k
		k += 1
		if typeof(ch) != TYPE_DICTIONARY:
			errors.append("%s：不是对象" % where)
			continue
		var id := str(ch.get("id", ""))
		if not valid_id(id) or chap_ids.has(id):
			errors.append("%s：id「%s」缺失、不是小写 ASCII 或重复" % [where, id])
		chap_ids[id] = true
		for m in ch.get("maps", []):
			if not GameData.MAPS.has(str(m)):
				errors.append("%s：战区「%s」不存在" % [where, m])
		for key in ["intro", "outro"]:
			var sc := str(ch.get(key, ""))
			if sc != "" and not scene_ids.has(sc):
				errors.append("%s：%s 场景「%s」不存在" % [where, key, sc])
	return errors


static func _check_trigger(t, where: String, errors: Array) -> void:
	if t == null:
		return
	if typeof(t) != TYPE_DICTIONARY or str(t.get("event", "")) == "":
		errors.append("%s：trigger / unlock 应为 {\"event\": 事件名, \"when\": {...}}" % where)
	elif t.has("when") and typeof(t.when) != TYPE_DICTIONARY:
		errors.append("%s：when 应为对象" % where)


static func _check_line(ln, where: String, chars: Dictionary, voices: Dictionary, errors: Array, narrator_ok: bool) -> void:
	if typeof(ln) != TYPE_DICTIONARY:
		errors.append("%s：不是对象" % where)
		return
	var sp := str(ln.get("speaker", ""))
	if sp == "" and not narrator_ok:
		errors.append("%s：缺少 speaker" % where)
	elif sp != "" and not chars.has(sp):
		errors.append("%s：说话人「%s」不在 characters.json 里" % [where, sp])
	var ex := str(ln.get("expr", ""))
	if ex != "" and chars.has(sp):
		var exprs: Array = chars[sp].get("expressions", [])
		if not exprs.is_empty() and not (ex in exprs):
			errors.append("%s：表情「%s」不在 %s 的 expressions 里" % [where, ex, sp])
	if str(ln.get("zh", "")) == "":
		errors.append("%s：缺少 zh" % where)
	var v := str(ln.get("voice", ""))
	if v != "":
		if not valid_id(v):
			errors.append("%s：语音 id「%s」不是小写 ASCII" % [where, v])
		elif voices.has(v):
			errors.append("%s：语音 id「%s」与 %s 重复" % [where, v, voices[v]])
		voices[v] = where
		if str(ln.get("ja", "")) == "":
			errors.append("%s：有语音 id 但缺少 ja" % where)


## 条件匹配：事件参数 args 是否满足 when（flag 类条件由调用方传入 flags）
static func match_when(when: Dictionary, args: Dictionary, flags: Dictionary = {}, chapter := "", map_id := "") -> bool:
	for key in when:
		var want = when[key]
		match str(key):
			"flag":
				if not bool(flags.get(str(want), false)):
					return false
			"not_flag":
				if bool(flags.get(str(want), false)):
					return false
			"chapter":
				if chapter != str(want):
					return false
			"map":
				if map_id != str(want):
					return false
			_:
				if not args.has(key):
					return false
				var got = args[key]
				if typeof(want) == TYPE_ARRAY:
					var hit := false
					for w in want:
						if _same(got, w):
							hit = true
							break
					if not hit:
						return false
				elif not _same(got, want):
					return false
	return true


static func _same(a, b) -> bool:
	if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
		return is_equal_approx(float(a), float(b))
	if typeof(a) == TYPE_STRING_NAME or typeof(b) == TYPE_STRING_NAME:
		return str(a) == str(b)
	return typeof(a) == typeof(b) and a == b
