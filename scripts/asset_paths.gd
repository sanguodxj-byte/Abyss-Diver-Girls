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
const AVATAR := "res://assets/avatars/%s.png"
const ITEM_ICON := "res://assets/icons/items/%s.png"
const MAP_CARD := "res://assets/cards/maps/%s.png"
const CHAPTER_CARD := "res://assets/cards/chapters/%s.png"
const ILLUSTRATION := "res://assets/illustrations/%s.png"
const LOGO := "res://assets/logo/logo.png"
const GAME_ICON := "res://assets/logo/icon.png"


## 立绘动画；没有对应片段时返回空串，由调用方退回静态立绘。
## 奈绪的片段以 nao_f 为前缀，其余角色与 id 同名；表情缺失时退回 idle。
static func portrait_clip(char_id: String, expr := "") -> String:
	if char_id == "":
		return ""
	var pre := "nao_f" if char_id == "nao" else char_id
	if expr != "":
		var p := PORTRAIT_CLIP % [pre, expr]
		if ResourceLoader.exists(p):
			return p
	var idle := PORTRAIT_CLIP % [pre, "idle"]
	return idle if ResourceLoader.exists(idle) else ""


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
