extends "res://tests/lib/test_base.gd"
const START := "none"
const Occ = preload("res://scripts/occ_buildings.gd")


func run() -> void:
	var occ := Occ.new()
	var mi := MeshInstance3D.new()
	var verts := PackedVector3Array()
	for i in 20000:
		var x := float(i % 200) * 0.1 - 10
		var z := float(i / 200) * 0.1 - 5
		verts.append_array(PackedVector3Array([Vector3(x, 2, z), Vector3(x + 0.08, 2, z), Vector3(x, 2, z + 0.08)]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = mesh
	mi.material_override = StandardMaterial3D.new()
	add_child(mi)
	var record := {"world_aabb": AABB(Vector3(-5, 0, -4), Vector3(10, 4, 8)), "center": Vector3(0, 2, 0),
		"half": Vector3(5, 2, 4), "cy": cos(0.2), "sy": sin(0.2), "ghost_mats": []}
	var sync := Node3D.new()
	var sliced := Node3D.new()
	add_child(sync)
	add_child(sliced)
	await occ._extract_from_chunk_mesh(mi, record, sync, {})
	occ._ghost_slice_start = Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	await occ._extract_from_chunk_mesh(mi, record, sliced, {}, get_tree())
	if not check(Engine.get_process_frames() > frame + 1, "大型遮挡代理没有分帧"): return
	if not check(sync.get_child_count() == sliced.get_child_count() and sync.get_child_count() > 0, "遮挡代理丢失"): return
	for i in sync.get_child_count():
		if not check(sync.get_child(i).mesh.surface_get_arrays(0) == sliced.get_child(i).mesh.surface_get_arrays(0), "分帧改变遮挡代理几何"): return
	var cancelled := Node3D.new()
	add_child(cancelled)
	var done := [false]
	_cancel_task(occ, mi, record, cancelled, done)
	cancelled.free()
	if not check(await until(func(): return done[0], 3.0), "退出场景后提取任务未退出"): return
	log_line("large rotated footprint: identical triangles, multi-frame extraction and cancellation passed")


func _cancel_task(occ, mi, record: Dictionary, root: Node3D, done: Array) -> void:
	occ._ghost_slice_start = 0
	await occ._extract_from_chunk_mesh(mi, record, root, {}, get_tree())
	done[0] = true
