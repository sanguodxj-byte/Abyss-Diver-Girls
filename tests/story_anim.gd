extends "res://tests/lib/test_base.gd"
## 立绘动画接入：对话演出里说话人若有 ogv 片段，立绘位改播循环动画并去掉黑底。
## godot --path . -- --story_anim → review\story_anim_left.png / story_anim_right.png
const PLAYER = preload("res://scripts/story/dialogue_player.gd")
const START := "none"


class Stub extends Node:
	func character(id: String) -> Dictionary:
		return {"name_zh": id}

	func set_progress(_a: String, _b: int) -> void:
		pass


func run() -> void:
	var p = PLAYER.new()
	add_child(p)
	var sc := {
		"bg": "",
		"lines": [
			{"speaker": "kurumi", "expr": "smile", "tag": "振奋", "zh": "测试台词一", "voice": ""},
			{"speaker": "nao", "expr": "angry", "tag": "急促", "zh": "测试台词二", "voice": ""},
		],
	}
	p.open(Stub.new(), sc, "anim_test", 0)
	if not check(p._tag_lbl != null and p._tag_lbl.text == "[振奋]", "情绪标签没有显示在名牌上：%s" % [p._tag_lbl.text if p._tag_lbl else ""]):
		return
	if not check(str(p._slots["left"]["node"]._clip_path).contains("talk_happy"), "振奋标签没有触发 talk_happy 谈话动画：%s" % p._slots["left"]["node"]._clip_path):
		return
	await wait(0.9)
	var left = p._slots["left"]["node"]
	if not check(left.rect != null and left.rect.visible and left.vid.stream != null, "左席立绘动画没有播放"):
		return
	await wait(0.6)
	await shot("story_anim_left.png")
	p._next()
	if not check(p._tag_lbl != null and p._tag_lbl.text == "[急促]", "第二句情绪标签没有更新：%s" % [p._tag_lbl.text if p._tag_lbl else ""]):
		return
	if not check(str(p._slots["right"]["node"]._clip_path).contains("talk_angry"), "急促标签没有触发 talk_angry 谈话动画：%s" % p._slots["right"]["node"]._clip_path):
		return
	await wait(0.9)
	var right = p._slots["right"]["node"]
	if not check(right.rect != null and right.rect.visible and right.vid.stream != null, "右席立绘动画没有播放"):
		return
	await wait(0.4)
	await shot("story_anim_right.png")
	p._finish("skip")
	await wait(0.2)
	log_line("story_anim ok")
