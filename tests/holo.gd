extends "res://tests/lib/test_base.gd"
## 全息投影截图：godot --path . -- --holo → review\holo.png
const HL = preload("res://scripts/hud_l.gd")
const START := "none"
class FakeMech:
	var hp := 82.0
	var max_hp := 100.0
	var parts := {"core": 1.0, "legs": 0.62, "arm_l": 1.0, "arm_r": 0.38, "back": 0.0, "gen": 0.18}
	var loadout := {"core":"core_std","legs":"legs_biped","arm_l":"arm_mg","arm_r":"arm_mg","back":"back_missile","gen":"gen_reactor"}
func run() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var bg := ColorRect.new(); bg.color = Color(0.05,0.05,0.06); bg.size = Vector2(1280,720); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(bg)
	var h = HL.HoloPortrait.new()
	h.position = Vector2(40, 40); h.size = Vector2(500, 400)
	cl.add_child(h)
	h.setup(FakeMech.new())
	await wait(1.5)
	await shot("holo.png")
