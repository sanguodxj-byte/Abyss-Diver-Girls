extends "res://tests/lib/test_base.gd"
const START := "none"
const UI = preload("res://scripts/ui.gd")

func run() -> void:
	var vp := get_viewport()
	var before := vp.size_changed.get_connections().size()
	for cycle in 8:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(620, 450)
		add_child(p)
		UI.bind_fit_panel(p)
		await frames(2)
		p.queue_free()
		await frames(2)
		if not check(vp.size_changed.get_connections().size() == before, "面板销毁后残留 viewport 回调"): return
		vp.size_changed.emit()
		await frames(2)
