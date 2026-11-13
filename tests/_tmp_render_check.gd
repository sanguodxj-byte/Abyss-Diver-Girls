extends "res://tests/lib/test_base.gd"

const START := "hub"
const TIMEOUT := 90.0
const ART_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b38734f-02e8-4000-8590-4f365bc26509"


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ART_DIR)
	await frames(2)

	GameData.map_id = "ironbelt"
	var r = await deploy(GameData.STARTER)
	if not check(r != null, "deploy into ironbelt failed"):
		return
	r.mech.max_hp = 1e6
	r.mech.hp = 1e6
	r.mech.shield_time = 0.0
	await wait_real(3.3)
	if r.hud and r.hud.radio:
		r.hud.radio.visible = false
	log_line("ironbelt spawn cam_pos=%s fov=%.1f zoom=%.2f player_view=%.2fm vision=%.2fm vp=%s" % [
		str(r.camera.global_position),
		r.camera.fov,
		r.cam_zoom,
		r.player_view_range(),
		r.vision_range(),
		str(get_viewport().get_visible_rect().size),
	])
	await _save_art("render_opt_ironbelt.png")

	var origin: Vector3 = r.mech.global_position
	var best_blk := Rect2()
	var best_d := INF
	for b in r.blocks:
		var br: Rect2 = b
		if maxf(br.size.x, br.size.y) >= 12.0:
			var c: Vector2 = br.get_center()
			var d: float = Vector2(origin.x, origin.z).distance_to(c)
			if d < best_d:
				best_d = d
				best_blk = br
	if best_d < INF:
		var tp := Vector3(best_blk.get_center().x, 0.2, best_blk.end.y + 8.0)
		r.mech.global_position = tp
		r.camera.global_position = tp + r.CAM_OFFSET * r.cam_zoom
		r.camera.look_at(tp, Vector3.UP)
		if r._rbatch:
			r._rbatch.show_all()
		await wait_real(1.0)
		if r.hud and r.hud.radio:
			r.hud.radio.visible = false
		log_line("ironbelt roof blk=%s cam_pos=%s" % [str(best_blk), str(r.camera.global_position)])
		await _save_art("render_opt_ironbelt_roof.png")
	main.show_hub()
	await frames(3)


func _save_art(filename: String) -> void:
	if headless():
		return
	await frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		fail("Screenshot failed: " + filename)
		return
	log_line("saved %s (%dx%d)" % [filename, img.get_width(), img.get_height()])
	var err: int = img.save_png(ART_DIR.path_join(filename))
	if err != OK:
		fail("Screenshot save failed (%d): %s" % [err, filename])
