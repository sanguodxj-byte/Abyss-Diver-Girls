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
			{"speaker": "kurumi", "expr": "smile", "zh": "测试台词一", "voice": ""},
			{"speaker": "nao", "expr": "idle", "zh": "测试台词二", "voice": ""},
		],
	}
	p.open(Stub.new(), sc, "anim_test", 0)
	await wait(0.9)
	var left = p._slots["left"]["node"]
	if not check(left.rect != null and left.rect.visible and left.vid.stream != null, "左席立绘动画没有播放"):
		return
	await wait(0.6)
	await shot("story_anim_left.png")
	p._next()
	await wait(0.9)
	var right = p._slots["right"]["node"]
	if not check(right.rect != null and right.rect.visible and right.vid.stream != null, "右席立绘动画没有播放"):
		return
	await wait(0.4)
	await shot("story_anim_right.png")
	p._finish("skip")
	await wait(0.2)
	log_line("story_anim ok")
