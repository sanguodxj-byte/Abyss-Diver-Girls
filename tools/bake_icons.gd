extends RefCounted
## Renders all 86 item/module 3D models into 2x-supersampled transparent PNGs at
## res://assets/icons/items/<id>.png (96*gw x 96*gh) plus labeled contact sheets.

const ItemModels = preload("res://scripts/item_models.gd")
const OUT_DIR := "res://assets/icons/items"
const CELL_OUT := 96
const SUPERSAMPLE := 2
const FOV_DEG := 18.0
const FILL_RATIO := 0.84


static func _gather_mesh_corners(node: Node, acc_xform: Transform3D, corners: Array[Vector3]) -> void:
	var xf: Transform3D = acc_xform
	if node is Node3D:
		xf = acc_xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.visible and mi.mesh != null:
			var aabb: AABB = mi.mesh.get_aabb()
			if aabb.size.length_squared() > 1e-9:
				for dx in 2:
					for dy in 2:
						for dz in 2:
							var local_p := Vector3(
								aabb.position.x + aabb.size.x * float(dx),
								aabb.position.y + aabb.size.y * float(dy),
								aabb.position.z + aabb.size.z * float(dz)
							)
							corners.append(xf * local_p)
	for ch in node.get_children():
		_gather_mesh_corners(ch, xf, corners)


static func _bleed_transparent_edges(img: Image, passes: int = 2) -> void:
	## Copies RGB from opaque neighbors into zero-alpha edge pixels so Lanczos downsampling avoids dark fringing.
	var w: int = img.get_width()
	var h: int = img.get_height()
	for _p in passes:
		var src := img.duplicate() as Image
		var changed := false
		for y in h:
			for x in w:
				var c: Color = src.get_pixel(x, y)
				if c.a > 0.004:
					continue
				var r_sum := 0.0
				var g_sum := 0.0
				var b_sum := 0.0
				var w_sum := 0.0
				for oy in range(-1, 2):
					var ny: int = y + oy
					if ny < 0 or ny >= h:
						continue
					for ox in range(-1, 2):
						if ox == 0 and oy == 0:
							continue
						var nx: int = x + ox
						if nx < 0 or nx >= w:
							continue
						var nc: Color = src.get_pixel(nx, ny)
						if nc.a > 0.02:
							r_sum += nc.r * nc.a
							g_sum += nc.g * nc.a
							b_sum += nc.b * nc.a
							w_sum += nc.a
				if w_sum > 0.0:
					img.set_pixel(x, y, Color(r_sum / w_sum, g_sum / w_sum, b_sum / w_sum, 0.0))
					changed = true
		if not changed:
			break


static func _image_stats(img: Image) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var opaque := 0
	var max_a := 0.0
	var corner_a: float = maxf(
		maxf(img.get_pixel(0, 0).a, img.get_pixel(w - 1, 0).a),
		maxf(img.get_pixel(0, h - 1).a, img.get_pixel(w - 1, h - 1).a)
	)
	for y in h:
		for x in w:
			var a: float = img.get_pixel(x, y).a
			if a > 0.08:
				opaque += 1
			if a > max_a:
				max_a = a
	return {"opaque": opaque, "max_a": max_a, "corner_a": corner_a}


static func bake_all(host: Node, log_cb: Callable) -> Dictionary:
	var abs_out: String = ProjectSettings.globalize_path(OUT_DIR)
	var mk_err: Error = DirAccess.make_dir_recursive_absolute(abs_out)
	if mk_err != OK:
		return {"ok": false, "error": "Failed to create %s (%d)" % [abs_out, mk_err]}

	var vp := SubViewport.new()
	vp.name = "IconBakeVP"
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_hdr_2d = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(CELL_OUT * SUPERSAMPLE, CELL_OUT * SUPERSAMPLE)
	host.add_child(vp)

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.58, 0.65, 0.76)
	sky_mat.sky_horizon_color = Color(0.45, 0.48, 0.54)
	sky_mat.ground_bottom_color = Color(0.15, 0.16, 0.19)
	sky_mat.ground_horizon_color = Color(0.25, 0.27, 0.30)
	sky_mat.sun_angle_max = 35.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.fog_enabled = false

	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var cam := Camera3D.new()
	cam.fov = FOV_DEG
	cam.near = 0.02
	cam.far = 200.0
	cam.current = true
	vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, -38.0, 0.0)
	key.light_color = Color(1.0, 0.96, 0.90)
	key.light_energy = 1.85
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.shadow_bias = 0.012
	key.shadow_normal_bias = 0.02
	key.shadow_blur = 1.2
	cam.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14.0, 48.0, 0.0)
	fill.light_color = Color(0.70, 0.82, 1.0)
	fill.light_energy = 0.82
	fill.shadow_enabled = false
	cam.add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(24.0, 146.0, 0.0)
	rim.light_color = Color(1.0, 0.90, 0.65)
	rim.light_energy = 1.40
	rim.shadow_enabled = false
	cam.add_child(rim)

	var ids: Array = GameData.ITEMS.keys()
	ids.sort()
	var module_ids: Array[String] = []
	var item_ids: Array[String] = []
	var baked_images: Dictionary = {}

	var fov_rad: float = deg_to_rad(FOV_DEG)
	var tan_y: float = tan(fov_rad * 0.5)
	var tree: SceneTree = host.get_tree()

	for idx in ids.size():
		var id: String = str(ids[idx])
		if GameData.is_module(id):
			module_ids.append(id)
		else:
			item_ids.append(id)

		var gsz: Vector2i = GameData.item_grid_size(id)
		var gw: int = maxi(1, gsz.x)
		var gh: int = maxi(1, gsz.y)
		var w2: int = gw * CELL_OUT * SUPERSAMPLE
		var h2: int = gh * CELL_OUT * SUPERSAMPLE
		vp.size = Vector2i(w2, h2)

		var model: Node3D = ItemModels.build_item_3d(id)
		if model == null:
			vp.queue_free()
			return {"ok": false, "error": "build_item_3d returned null for %s" % id}
		vp.add_child(model)

		var corners: Array[Vector3] = []
		_gather_mesh_corners(model, Transform3D.IDENTITY, corners)
		if corners.is_empty():
			model.queue_free()
			vp.queue_free()
			return {"ok": false, "error": "No mesh corners found for %s" % id}

		var raw_dir: Variant = model.get_meta("cam_dir", Vector3(0.56, 0.42, 0.72))
		var cam_dir: Vector3 = (raw_dir as Vector3).normalized()
		var up_hint := Vector3.UP if absf(cam_dir.dot(Vector3.UP)) < 0.95 else Vector3(0.0, 0.0, -1.0)
		var look_basis: Basis = Basis.looking_at(-cam_dir, up_hint)
		var cam_right: Vector3 = look_basis.x.normalized()
		var cam_up: Vector3 = look_basis.y.normalized()

		var min_x := INF
		var max_x := -INF
		var min_y := INF
		var max_y := -INF
		var min_z := INF
		var max_z := -INF
		for c in corners:
			var px: float = cam_right.dot(c)
			var py: float = cam_up.dot(c)
			var pz: float = cam_dir.dot(c)
			min_x = minf(min_x, px)
			max_x = maxf(max_x, px)
			min_y = minf(min_y, py)
			max_y = maxf(max_y, py)
			min_z = minf(min_z, pz)
			max_z = maxf(max_z, pz)

		var center_world: Vector3 = (
			cam_right * ((min_x + max_x) * 0.5)
			+ cam_up * ((min_y + max_y) * 0.5)
			+ cam_dir * ((min_z + max_z) * 0.5)
		)
		var aspect: float = float(gw) / float(gh)
		var tan_x: float = tan_y * aspect
		var d_req := 0.06
		for c in corners:
			var rel: Vector3 = c - center_world
			var rx: float = absf(cam_right.dot(rel))
			var ry: float = absf(cam_up.dot(rel))
			var rz: float = cam_dir.dot(rel)
			d_req = maxf(d_req, rz + rx / (tan_x * FILL_RATIO))
			d_req = maxf(d_req, rz + ry / (tan_y * FILL_RATIO))

		cam.position = center_world + cam_dir * d_req
		cam.look_at(center_world, up_hint)
		key.directional_shadow_max_distance = maxf(6.0, d_req * 3.0)

		var wait_n: int = 5 if idx == 0 else 2
		for _f in wait_n:
			await tree.process_frame
		await RenderingServer.frame_post_draw

		var img: Image = vp.get_texture().get_image()
		if img == null:
			model.queue_free()
			vp.queue_free()
			return {"ok": false, "error": "Null viewport image for %s" % id}
		img.convert(Image.FORMAT_RGBA8)

		var st: Dictionary = _image_stats(img)
		if float(st["corner_a"]) > 0.02:
			model.queue_free()
			vp.queue_free()
			return {"ok": false, "error": "Background not transparent for %s (corner alpha=%.3f)" % [id, float(st["corner_a"])]}
		if int(st["opaque"]) < 40:
			model.queue_free()
			vp.queue_free()
			return {"ok": false, "error": "Blank render for %s (opaque=%d)" % [id, int(st["opaque"])]}

		_bleed_transparent_edges(img, 2)
		var w_out: int = gw * CELL_OUT
		var h_out: int = gh * CELL_OUT
		img.resize(w_out, h_out, Image.INTERPOLATE_LANCZOS)

		var file_path: String = abs_out.path_join("%s.png" % id)
		var save_err: Error = img.save_png(file_path)
		if save_err != OK:
			model.queue_free()
			vp.queue_free()
			return {"ok": false, "error": "Failed saving %s (%d)" % [file_path, save_err]}

		baked_images[id] = img
		model.queue_free()
		if idx % 20 == 19 or idx == ids.size() - 1:
			log_cb.call("Baked %d/%d (%s %dx%d)" % [idx + 1, ids.size(), id, gw, gh])

	vp.queue_free()
	return {
		"ok": true,
		"count": ids.size(),
		"module_ids": module_ids,
		"item_ids": item_ids,
		"images": baked_images,
	}


class _SheetCanvas extends Control:
	var entries: Array = []
	var cols: int = 8
	var cell_w: int = 190
	var cell_h: int = 148

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 1.0), true)
		var font: Font = PixelUI.pixel_font()
		var n: int = entries.size()
		for i in n:
			var col: int = i % cols
			var row: int = i / cols
			var rx: float = 16.0 + float(col) * float(cell_w)
			var ry: float = 16.0 + float(row) * float(cell_h)
			var card := Rect2(rx + 4.0, ry + 4.0, float(cell_w - 8), float(cell_h - 8))
			draw_rect(card, Color(0.11, 0.13, 0.16, 1.0), true)
			draw_rect(card, Color(0.24, 0.28, 0.34, 1.0), false, 1.0)
			var ent: Dictionary = entries[i]
			var tex: Texture2D = ent["tex"]
			var gsz: Vector2i = ent["grid"]
			var id: String = ent["id"]
			var icon_area := Rect2(card.position.x + 8.0, card.position.y + 6.0, card.size.x - 16.0, card.size.y - 34.0)
			var tw: float = float(tex.get_width())
			var th: float = float(tex.get_height())
			var sc: float = minf(icon_area.size.x / tw, icon_area.size.y / th)
			var dst_sz := Vector2(tw * sc, th * sc)
			var dst := Rect2(icon_area.position + (icon_area.size - dst_sz) * 0.5, dst_sz)
			draw_rect(dst, Color(0.16, 0.19, 0.23, 0.8), true)
			draw_rect(dst, Color(0.98, 0.82, 0.10, 0.45), false, 1.0)
			draw_texture_rect(tex, dst, false)
			var tag: String = "%s (%dx%d)" % [id, gsz.x, gsz.y]
			draw_string(font, Vector2(card.position.x + 8.0, card.end.y - 8.0), tag, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 16.0, 12, Color(0.95, 0.96, 0.98))


static func render_contact_sheet(host: Node, ids: Array[String], images: Dictionary, out_res_path: String, cols: int) -> Error:
	var entries: Array = []
	for id in ids:
		var img: Image = images[id]
		var tex := ImageTexture.create_from_image(img)
		entries.append({"id": id, "tex": tex, "grid": GameData.item_grid_size(id)})
	var rows: int = ceili(float(entries.size()) / float(cols))
	var cell_w := 196
	var cell_h := 148
	var w: int = 32 + cols * cell_w
	var h: int = 32 + rows * cell_h

	var vp := SubViewport.new()
	vp.own_world_3d = false
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(w, h)
	host.add_child(vp)

	var canvas := _SheetCanvas.new()
	canvas.entries = entries
	canvas.cols = cols
	canvas.cell_w = cell_w
	canvas.cell_h = cell_h
	canvas.position = Vector2.ZERO
	canvas.size = Vector2(w, h)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	vp.add_child(canvas)

	var tree: SceneTree = host.get_tree()
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw

	var out_img: Image = vp.get_texture().get_image()
	var abs_path: String = ProjectSettings.globalize_path(out_res_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err: Error = out_img.save_png(abs_path)
	vp.queue_free()
	return err
