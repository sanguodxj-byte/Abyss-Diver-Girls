extends "res://tests/lib/test_base.gd"
const START := "none"
const Hazards = preload("res://scripts/enemies/hazards.gd")
const Loot = preload("res://scripts/loot_box.gd")
const A = preload("res://scripts/art.gd")
const DM = preload("res://scripts/modules/device_models.gd")
const MM = preload("res://scripts/modules/munition_models.gd")


func run() -> void:
	Hazards.warm_visuals()
	for kind in ["lob", "slug", "rocket"]:
		var color := Color(0.66, 0.95, 0.3)
		var direct := Node3D.new()
		match kind:
			"lob": MM.build_lob_shell(direct, color)
			"slug": MM.build_kinetic_slug(direct, A.emit(color.lightened(0.28), 3.2))
			"rocket": DM.build_salvo_rocket(direct)
		var packed: Node3D = Hazards.BodyCache._body_scene(kind, color).instantiate()
		if not check(_geometry(direct) == _geometry(packed), "缓存弹体改变几何或材质：" + kind): return
		direct.free()
		packed.free()
	var sync := Loot.new()
	var sliced := Loot.new()
	add_child(sync)
	add_child(sliced)
	for box in [sync, sliced]:
		box.kind = "bug"
		box.items = ["bolts"]
		box._rng.seed = 1234
		box._build_wreck(Loot.STYLE.bug.size)
	await sync._batch_loot_meshes()
	sliced._batch_loot_meshes(get_tree())
	if not check(not sliced.items.is_empty() and not sliced._meshes.is_empty(), "分帧前掉落不可见或物品缺失"): return
	if not check(await until(func(): return sliced.batch_ready, 3), "残骸合批未完成"): return
	if not check(_geometry(sync) == _geometry(sliced), "残骸分帧改变最终外观"): return
	var cancel := Loot.new()
	add_child(cancel)
	cancel.kind = "bug"
	cancel._build_wreck(Loot.STYLE.bug.size)
	cancel._batch_loot_meshes(get_tree())
	cancel.free()
	await frames(3)
	log_line("hazard geometry/material parity; wreck visibility, items, sliced batch and cancellation passed")


func _geometry(root: Node3D) -> Array:
	var out: Array = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := mi.transform
		var parent := mi.get_parent()
		while parent != root:
			xf = parent.transform * xf
			parent = parent.get_parent()
		var surfaces: Array = []
		for i in mi.mesh.get_surface_count(): surfaces.append([mi.mesh.surface_get_arrays(i), mi.mesh.surface_get_material(i)])
		out.append([xf, surfaces, mi.material_override, mi.cast_shadow])
	return out
