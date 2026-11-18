extends "res://tests/lib/test_base.gd"
## ogv 重编码验收：用引擎自带 Theora 解码器实播合成测试图与重编码样片并截图 → review/ogvcheck_*.png
const START := "none"

var _pl: VideoStreamPlayer


func run() -> void:
	var clips := [
		["load", "res://assets/animations/kurumi_talk_surprised.ogv", "ogvcheck_0_kurumi_fix.png"],
		["load", "res://assets/animations/nao_f_talk_neutral.ogv", "ogvcheck_1_nao.png"],
		["load", "res://assets/animations/radio/kurumi_serious.ogv", "ogvcheck_2_radio.png"],
		["load", "res://assets/animations/deepseek_smile.ogv", "ogvcheck_3_orig.png"],
	]
	for c in clips:
		var pl := VideoStreamPlayer.new()
		add_child(pl)
		if c[0] == "load":
			pl.stream = load(c[1])
		else:
			var stream := VideoStreamTheora.new()
			stream.file = c[1]
			pl.stream = stream
		pl.loop = true
		pl.expand = false
		pl.play()
		await frames(6)
		# 按视频原始比例整窗内接居中，杜绝验收 rig 自己把画面拉扁
		var tex := pl.get_video_texture()
		if tex != null and tex.get_width() > 0:
			var vs := tex.get_size()
			var wins: Vector2 = pl.get_viewport_rect().size
			var sc: float = minf(wins.x / vs.x, wins.y / vs.y)
			pl.size = vs * sc
			pl.position = (wins - pl.size) * 0.5
		await wait(2.0)
		await frames(4)
		await shot(c[2])
		pl.stop()
		pl.queue_free()
		await frames(2)
	log_line("ogvshot ok")
