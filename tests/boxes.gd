extends "res://tests/lib/test_base.gd"
## 容器外观自检：在机甲附近摆出全部容器类型，用游戏镜头和近景各截一张 → review\boxes_game.png / boxes_close.png

func run() -> void:
	await wait(0.3)
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	var m = raid.mech
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	m.max_hp = 99999.0; m.hp = 99999.0
	var c: Vector3 = m.global_position
	var kinds := ["supply", "tool", "military", "safe", "bug"]
	for i in kinds.size():
		raid._place_box(kinds[i], Vector3(c.x - 6 + i * 3.0, 0, c.z - 4.0))
	m.global_position = c + Vector3(-3.0, 0, -1.4)
	raid.aim_override = c + Vector3(0, 1.8, -10)
	await wait(2.5)
	raid.hud.visible = false
	await shot("boxes_game.png")
	var cam := Camera3D.new()
	raid.add_child(cam)
	cam.current = true
	cam.global_position = c + Vector3(0, 5.5, 4.0)
	cam.look_at(c + Vector3(0, 0, -4.0), Vector3.UP)
	cam.fov = 50
	await frames(10)
	await shot("boxes_close.png")
