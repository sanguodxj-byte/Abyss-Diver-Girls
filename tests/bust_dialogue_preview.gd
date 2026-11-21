extends "res://tests/lib/test_base.gd"
## 3 号画风亚人胸像实机对话场景预览：使用真实 DialoguePlayer 渲染全员 11 位角色双人同框对话并截图至 review\。
const PLAYER = preload("res://scripts/story/dialogue_player.gd")
const AP = preload("res://scripts/asset_paths.gd")
const START := "none"


class Stub extends Node:
	const NAMES := {
		"nao": "奈绪", "rei": "零", "kurumi": "胡桃", "lina": "莉娜",
		"mia": "米娅", "ajin": "阿堇", "xiaoman": "小满", "shiori": "诗织",
		"karasu": "鸦", "nihong": "霓虹", "gin": "银",
	}

	func char_name(id: String, fallback := "") -> String:
		return str(NAMES.get(id, fallback))

	func chapter_data(_id: String) -> Dictionary:
		return {}

	func line_text(ln: Dictionary) -> String:
		return str(ln.get("zh", ""))

	func set_progress(_a: String, _b: int) -> void:
		pass


func _apply_static_bust(p, side: String, cid: String, talking: bool, alpha: float) -> void:
	var n = p._slots[side]["node"]
	p._slots[side]["char"] = cid
	p._slots[side]["talking"] = false
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	n.set_emotion("calm", talking, n.accent)
	n.set_clip("")
	n.set_tex(AP.portrait(cid))
	n.modulate.a = alpha
	n.queue_redraw()


func _capture_pair(left_id: String, right_id: String, speaker_side: String, tag: String, zh: String, out_name: String) -> void:
	var p = PLAYER.new()
	add_child(p)
	var sp := left_id if speaker_side == "left" else right_id
	var sc := {
		"title": "",
		"bg": "",
		"lines": [
			{"speaker": left_id, "expr": "", "tag": tag, "zh": zh, "voice": ""},
			{"speaker": right_id, "expr": "", "tag": tag, "zh": zh, "voice": ""},
		],
	}
	if speaker_side == "left":
		sc["lines"] = [
			{"speaker": right_id, "expr": "", "tag": tag, "zh": zh, "voice": ""},
			{"speaker": left_id, "expr": "", "tag": tag, "zh": zh, "voice": ""},
		]
	p.open(Stub.new(), sc, "bust_preview", 0)
	await frames(2)
	p._advance() # 完成第 0 句打字
	p._advance() # 切到第 1 句，让左右两席由真实 DialoguePlayer 完整入场
	p._advance() # 完成第 1 句打字
	# 等待入场与暗化 Tween (0.30s) 全部结束后替换成新版静态胸像并截图
	await get_tree().create_timer(0.40).timeout
	_apply_static_bust(p, "left", left_id, speaker_side == "left", 1.0 if speaker_side == "left" else 0.72)
	_apply_static_bust(p, "right", right_id, speaker_side == "right", 1.0 if speaker_side == "right" else 0.72)
	await frames(4)
	await shot(out_name)
	p._finish("skip")
	await frames(2)


func run() -> void:
	await _capture_pair(
		"nao", "rei", "left", "沉着",
		"进入灰港市外廓。断桥和旧总站周边视野开阔，小心高速游荡虫群。",
		"对话预览_1_奈绪与零.png"
	)
	await _capture_pair(
		"kurumi", "mia", "left", "自信",
		"尘土平原风沙大，视野会被压低。跟紧我。",
		"对话预览_2_胡桃与米娅.png"
	)
	await _capture_pair(
		"lina", "karasu", "left", "凝重",
		"灰港市上空。云层很薄，注意楼顶的拦截火力。",
		"对话预览_3_莉娜与鸦.png"
	)
	await _capture_pair(
		"ajin", "shiori", "right", "凝重",
		"进入赤湖新区。观测所与栈桥附近孢子雾气很浓，注意岸边浅滩的活性甲壳。",
		"对话预览_4_阿堇与诗织.png"
	)
	await _capture_pair(
		"xiaoman", "nihong", "left", "自信",
		"运输机航线已清空，等着。",
		"对话预览_5_小满与霓虹.png"
	)
	await _capture_pair(
		"mia", "gin", "left", "警戒",
		"进入铁锈工业带了。一号高炉和转炉区热信号很杂，注意钢架夹缝里的伏兵。",
		"对话预览_6_米娅与银.png"
	)
	log_line("bust_dialogue_preview ok")
