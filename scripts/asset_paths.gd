extends RefCounted
## 2D 素材的路径约定与加载。所有 id 为小写 ASCII（字母、数字、下划线）；文件缺失时返回 null，调用方留空或用占位。
##
##   立绘        res://assets/portraits/<角色 id>.png            透明 PNG，默认表情
##   表情差分    res://assets/portraits/<角色 id>_<表情 id>.png   与默认立绘同尺寸、同站位，可直接替换
##   头像        res://assets/avatars/<角色 id>.png               256×256 透明 PNG；按表情的头像为 <角色 id>_<表情 id>.png
##   物品图标    res://assets/icons/items/<物品 id>.png           256×256 透明 PNG，模块也在这里；变体（id#后缀）用基础 id 的图标
##   战区卡      res://assets/cards/maps/<战区 id>.png             16:9
##   章节卡      res://assets/cards/chapters/<章节 id>.png         16:9
##   插画        res://assets/illustrations/<插画 id>.png          结算插画为 result_success / result_fail，剧情背景用场景的 bg id
##   Logo        res://assets/logo/logo.png（透明背景）；游戏图标 res://assets/logo/icon.png 与 icon.ico
##   界面贴图    res://assets/ui/<名字>.png                        九宫格贴图以 9 结尾（如 panel9.png），由 scripts\ui.gd 的 UI.tex / UI.tex9 读取
##   配音、音效、音乐见 scripts\audio\audio_registry.gd

const PORTRAIT := "res://assets/portraits/%s.png"
const PORTRAIT_CLIP := "res://assets/animations/%s_%s.ogv"
const RADIO_CLIP := "res://assets/animations/radio/%s_%s.ogv"
const AVATAR := "res://assets/avatars/%s.png"
const ITEM_ICON := "res://assets/icons/items/%s.png"
const MAP_CARD := "res://assets/cards/maps/%s.png"
const CHAPTER_CARD := "res://assets/cards/chapters/%s.png"
const ILLUSTRATION := "res://assets/illustrations/%s.png"
const LOGO := "res://assets/logo/logo.png"
const GAME_ICON := "res://assets/logo/icon.png"


## 情绪标签与谈话动画映射表：
## label  UI 显示的中文情绪标签
## talk   说话时触发的立绘谈话动画后缀（匹配 <角色>_talk_<后缀>.ogv）
## idle   说话结束或待机时的立绘后缀（匹配 <角色>_<后缀>.ogv，缺失退回 idle）
## radio  无线电小窗短片后缀（匹配 radio/<角色>_<后缀>.ogv）
## motion 立绘与无线电头像的程序化谈话动态类型
## color  名牌情绪标签徽章颜色
const EMOTION_MAP := {
	"calm": {"label": "沉着", "talk": "talk_neutral", "idle": "idle", "radio": "neutral", "motion": "calm", "color": Color(0.56, 0.78, 0.92)},
	"neutral": {"label": "沉着", "talk": "talk_neutral", "idle": "idle", "radio": "neutral", "motion": "calm", "color": Color(0.56, 0.78, 0.92)},
	"沉着": {"label": "沉着", "talk": "talk_neutral", "idle": "idle", "radio": "neutral", "motion": "calm", "color": Color(0.56, 0.78, 0.92)},
	"冷静": {"label": "冷静", "talk": "talk_neutral", "idle": "idle", "radio": "neutral", "motion": "calm", "color": Color(0.56, 0.78, 0.92)},
	"serious": {"label": "凝重", "talk": "talk_neutral", "idle": "serious", "radio": "serious", "motion": "serious", "color": Color(0.86, 0.72, 0.42)},
	"凝重": {"label": "凝重", "talk": "talk_neutral", "idle": "serious", "radio": "serious", "motion": "serious", "color": Color(0.86, 0.72, 0.42)},
	"tense": {"label": "警戒", "talk": "talk_angry", "idle": "serious", "radio": "serious", "motion": "serious", "color": Color(0.94, 0.68, 0.30)},
	"警戒": {"label": "警戒", "talk": "talk_angry", "idle": "serious", "radio": "serious", "motion": "serious", "color": Color(0.94, 0.68, 0.30)},
	"urgent": {"label": "急促", "talk": "talk_angry", "idle": "serious", "radio": "serious", "motion": "urgent", "color": Color(0.96, 0.42, 0.34)},
	"in a hurry tone": {"label": "急促", "talk": "talk_angry", "idle": "serious", "radio": "serious", "motion": "urgent", "color": Color(0.96, 0.42, 0.34)},
	"急促": {"label": "急促", "talk": "talk_angry", "idle": "serious", "radio": "serious", "motion": "urgent", "color": Color(0.96, 0.42, 0.34)},
	"alarmed": {"label": "惊骇", "talk": "talk_surprised", "idle": "surprised", "radio": "surprised", "motion": "urgent", "color": Color(0.98, 0.36, 0.32)},
	"screaming": {"label": "急促", "talk": "talk_angry", "idle": "surprised", "radio": "surprised", "motion": "urgent", "color": Color(0.98, 0.36, 0.32)},
	"hysterical": {"label": "急促", "talk": "talk_angry", "idle": "surprised", "radio": "surprised", "motion": "urgent", "color": Color(0.98, 0.36, 0.32)},
	"惊骇": {"label": "惊骇", "talk": "talk_surprised", "idle": "surprised", "radio": "surprised", "motion": "urgent", "color": Color(0.98, 0.36, 0.32)},
	"angry": {"label": "恼火", "talk": "talk_angry", "idle": "serious", "radio": "serious", "motion": "urgent", "color": Color(0.95, 0.40, 0.35)},
	"frustrated": {"label": "恼火", "talk": "talk_angry", "idle": "serious", "radio": "serious", "motion": "urgent", "color": Color(0.95, 0.48, 0.36)},
	"恼火": {"label": "恼火", "talk": "talk_angry", "idle": "serious", "radio": "serious", "motion": "urgent", "color": Color(0.95, 0.48, 0.36)},
	"smile": {"label": "欣喜", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.48, 0.88, 0.58)},
	"happy": {"label": "欣喜", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.48, 0.88, 0.58)},
	"delighted": {"label": "欣喜", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.48, 0.88, 0.58)},
	"satisfied": {"label": "欣喜", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.48, 0.88, 0.58)},
	"欣喜": {"label": "欣喜", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.48, 0.88, 0.58)},
	"excited": {"label": "振奋", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.96, 0.78, 0.32)},
	"proud": {"label": "振奋", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.96, 0.78, 0.32)},
	"振奋": {"label": "振奋", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.96, 0.78, 0.32)},
	"confident": {"label": "自信", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.46, 0.86, 0.72)},
	"自信": {"label": "自信", "talk": "talk_happy", "idle": "smile", "radio": "smile", "motion": "happy", "color": Color(0.46, 0.86, 0.72)},
	"relieved": {"label": "释然", "talk": "talk_tired", "idle": "smile", "radio": "smile", "motion": "calm", "color": Color(0.52, 0.86, 0.68)},
	"释然": {"label": "释然", "talk": "talk_tired", "idle": "smile", "radio": "smile", "motion": "calm", "color": Color(0.52, 0.86, 0.68)},
	"sad": {"label": "忧虑", "talk": "talk_sad", "idle": "sad", "radio": "serious", "motion": "sad", "color": Color(0.62, 0.68, 0.90)},
	"worried": {"label": "忧虑", "talk": "talk_sad", "idle": "sad", "radio": "serious", "motion": "sad", "color": Color(0.62, 0.68, 0.90)},
	"scared": {"label": "忧虑", "talk": "talk_sad", "idle": "sad", "radio": "surprised", "motion": "sad", "color": Color(0.62, 0.68, 0.90)},
	"忧虑": {"label": "忧虑", "talk": "talk_sad", "idle": "sad", "radio": "serious", "motion": "sad", "color": Color(0.62, 0.68, 0.90)},
	"surprised": {"label": "警觉", "talk": "talk_surprised", "idle": "surprised", "radio": "surprised", "motion": "surprised", "color": Color(0.98, 0.72, 0.28)},
	"shocked": {"label": "警觉", "talk": "talk_surprised", "idle": "surprised", "radio": "surprised", "motion": "surprised", "color": Color(0.98, 0.72, 0.28)},
	"警觉": {"label": "警觉", "talk": "talk_surprised", "idle": "surprised", "radio": "surprised", "motion": "surprised", "color": Color(0.98, 0.72, 0.28)},
	"shy": {"label": "柔和", "talk": "talk_shy", "idle": "idle", "radio": "neutral", "motion": "whisper", "color": Color(0.88, 0.66, 0.84)},
	"柔和": {"label": "柔和", "talk": "talk_shy", "idle": "idle", "radio": "neutral", "motion": "whisper", "color": Color(0.88, 0.66, 0.84)},
	"whispering": {"label": "低语", "talk": "talk_shy", "idle": "idle", "radio": "neutral", "motion": "whisper", "color": Color(0.76, 0.64, 0.88)},
	"mysterious": {"label": "低语", "talk": "talk_shy", "idle": "idle", "radio": "neutral", "motion": "whisper", "color": Color(0.76, 0.64, 0.88)},
	"低语": {"label": "低语", "talk": "talk_shy", "idle": "idle", "radio": "neutral", "motion": "whisper", "color": Color(0.76, 0.64, 0.88)},
	"curious": {"label": "好奇", "talk": "talk_shy", "idle": "idle", "radio": "neutral", "motion": "calm", "color": Color(0.64, 0.82, 0.92)},
	"好奇": {"label": "好奇", "talk": "talk_shy", "idle": "idle", "radio": "neutral", "motion": "calm", "color": Color(0.64, 0.82, 0.92)},
	"tired": {"label": "疲惫", "talk": "talk_tired", "idle": "tired", "radio": "neutral", "motion": "tired", "color": Color(0.68, 0.68, 0.72)},
	"疲惫": {"label": "疲惫", "talk": "talk_tired", "idle": "tired", "radio": "neutral", "motion": "tired", "color": Color(0.68, 0.68, 0.72)},
}


## 从台词/通讯字典解析情绪信息（优先读 tag/emotion，其次解析 zh/ja 前置 [标签]，最后按 expr 推断）
static func resolve_emotion(ln: Dictionary) -> Dictionary:
	var key := str(ln.get("tag", ln.get("emotion", ""))).strip_edges()
	if key.begins_with("[") and key.ends_with("]"):
		key = key.substr(1, key.length() - 2).strip_edges()
	if key == "" or not EMOTION_MAP.has(key):
		for field in ["zh", "ja"]:
			var s := str(ln.get(field, "")).strip_edges()
			while s.begins_with("["):
				var close := s.find("]")
				if close <= 1:
					break
				var cand := s.substr(1, close - 1).strip_edges()
				if EMOTION_MAP.has(cand):
					key = cand
					break
				s = s.substr(close + 1).strip_edges()
			if key != "" and EMOTION_MAP.has(key):
				break
	if key == "" or not EMOTION_MAP.has(key):
		var ex := str(ln.get("expr", "")).strip_edges()
		if EMOTION_MAP.has(ex):
			key = ex
	var info: Dictionary = EMOTION_MAP.get(key, EMOTION_MAP["neutral"]).duplicate()
	if key != "" and not EMOTION_MAP.has(key):
		info["label"] = key
	info["label"] = emotion_text(str(info.get("label", "")))
	return info


static func emotion_text(label_zh: String) -> String:
	var t := Engine.get_main_loop() as SceneTree
	var loc := t.root.get_node_or_null("Loc") if t != null else null
	if loc != null and loc.has_method("emotion"):
		return str(loc.call("emotion", label_zh))
	return label_zh


## 立绘动画；没有对应片段时返回空串，由调用方退回静态立绘。
## 奈绪的片段以 nao_f 为前缀，其余角色与 id 同名；根据情绪标签或表情匹配对应的 talk_<情绪> 谈话片段，
## 当 talking 为 false（说话完毕或非当前发言席位）时自动退回待机片段。
static func portrait_clip(char_id: String, expr := "", talking := true, tag := "") -> String:
	if char_id == "":
		return ""
	var pre := "nao_f" if char_id == "nao" else char_id
	var em: Dictionary = EMOTION_MAP.get(tag, EMOTION_MAP.get(expr, {}))
	var tries: Array = []
	if talking:
		if not em.is_empty():
			tries.append(str(em.get("talk", "talk_neutral")))
		if expr != "":
			if not expr.begins_with("talk_"):
				tries.append("talk_" + expr)
				if expr == "smile":
					tries.append("talk_happy")
				elif expr == "serious":
					tries.append("talk_neutral")
					tries.append("talk_angry")
			tries.append(expr)
		tries.append("talk_neutral")
		if not em.is_empty():
			tries.append(str(em.get("idle", "idle")))
	else:
		if not em.is_empty():
			tries.append(str(em.get("idle", "idle")))
		if expr != "" and not expr.begins_with("talk_"):
			tries.append(expr)
		tries.append("idle")
		if expr != "":
			tries.append("talk_" + expr.trim_prefix("talk_"))
		tries.append("talk_neutral")
	for e: String in tries:
		if e == "":
			continue
		var p := PORTRAIT_CLIP % [pre, e]
		if ResourceLoader.exists(p):
			return p
	var idle := PORTRAIT_CLIP % [pre, "idle"]
	return idle if ResourceLoader.exists(idle) else ""


## 无线电小窗专用短片：192×192 全关键帧，避免小尺寸播放时的压缩噪点；没有时返回空串
static func radio_clip(char_id: String, expr := "", tag := "") -> String:
	if char_id == "":
		return ""
	var e := expr.trim_prefix("talk_")
	var em: Dictionary = EMOTION_MAP.get(tag, EMOTION_MAP.get(e, {}))
	var tries: Array = []
	if not em.is_empty():
		tries.append(str(em.get("radio", "neutral")))
	if e != "":
		if e == "happy":
			tries.append("smile")
		elif e in ["angry", "sad", "tired"]:
			tries.append("serious")
		tries.append(e)
	tries.append("neutral")
	for x: String in tries:
		if x == "":
			continue
		var p := RADIO_CLIP % [char_id, x]
		if ResourceLoader.exists(p):
			return p
	return ""


## 立绘；expr 为空或该表情没有文件时用默认立绘
static func portrait(char_id: String, expr := "") -> Texture2D:
	if expr != "":
		var t := tex(PORTRAIT % ("%s_%s" % [char_id, expr]))
		if t:
			return t
	return tex(PORTRAIT % char_id)


static func avatar(char_id: String, expr := "") -> Texture2D:
	if expr != "":
		var t := tex(AVATAR % ("%s_%s" % [char_id, expr]))
		if t:
			return t
	return tex(AVATAR % char_id)


static func item_icon(item_id: String) -> Texture2D:
	var k := item_id.find("#")
	return tex(ITEM_ICON % (item_id if k < 0 else item_id.substr(0, k)))


static func map_card(map_id: String) -> Texture2D:
	return tex(MAP_CARD % map_id)


static func chapter_card(chapter_id: String) -> Texture2D:
	return tex(CHAPTER_CARD % chapter_id)


static func illustration(id: String) -> Texture2D:
	return tex(ILLUSTRATION % id)


static func logo() -> Texture2D:
	return tex(LOGO)


static func tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
