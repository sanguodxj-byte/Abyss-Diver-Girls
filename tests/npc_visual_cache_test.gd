extends "res://tests/lib/test_base.gd"
const START := "none"
const TIMEOUT := 240.0
const Cache = preload("res://scripts/npc_visual_cache.gd")
const MV = preload("res://scripts/mech_visual.gd")
const Mech = preload("res://scripts/mech.gd")
const Factions = preload("res://scripts/factions/factions.gd")


func run() -> void:
	Cache.prepare()
	if not check(Cache.library != null, "NPC 模块缓存不存在"): return
	if not check(Cache.library.get_meta("sources") == Cache.signature(), "NPC 模块缓存过期，请运行 --npc_visual_bake"): return
	var scenes: Dictionary = Cache.library.get_meta("modules")
	for key: String in scenes:
		var parts := key.split(":")
		var original := MV.build_module(parts[0], parts[1], true, "42")
		Mech._batch_visual(original)
		var cached := Cache.instantiate(parts[0], parts[1], "42")
		var other := Cache.instantiate(parts[0], parts[1], "73")
		if not check(_equivalent(original, cached), "缓存模型与原构建不一致：" + key): return
		for node: Node in [cached] + cached.find_children("*", "", true, false):
			for name in node.get_meta_list():
				if not check(_refs_inside(node.get_meta(name), cached), "缓存引用指向其他实例：" + key): return
		var geometry: Array = _geometry(other)
		cached.free()
		if not check(geometry == _geometry(other), "释放实例损坏共享网格：" + key): return
		other.free()
		original.free()
		await frames(1)
	for slot: String in Factions.rover_pools():
		for id: String in Factions.rover_pools()[slot]:
			for side: String in (["arm_l", "arm_r"] if slot == "arm" else [slot]):
				if not check(scenes.has(side + ":" + id), "增援模块未覆盖：" + id): return
	log_line("%d modules: geometry, transforms, materials, lights, serials, metadata references and lifetime passed" % scenes.size())


func _refs_inside(value: Variant, root: Node) -> bool:
	if value is Node: return value == root or root.is_ancestor_of(value)
	if value is Array:
		for item in value:
			if not _refs_inside(item, root): return false
	if value is Dictionary:
		for item in value.values():
			if not _refs_inside(item, root): return false
	return true


func _equivalent(a: Node3D, b: Node3D) -> bool:
	var aa := [a] + a.find_children("*", "", true, false)
	var bb := [b] + b.find_children("*", "", true, false)
	if aa.size() != bb.size(): return false
	for i in aa.size():
		var x: Node3D = aa[i]
		var y: Node3D = bb[i]
		if x.get_class() != y.get_class() or not x.transform.is_equal_approx(y.transform): return false
		if x is Label3D and x.text != y.text: return false
		if x is Light3D and (x.light_color != y.light_color or x.light_energy != y.light_energy): return false
		if x is MeshInstance3D:
			if x.cast_shadow != y.cast_shadow or x.layers != y.layers: return false
			if x.mesh.get_surface_count() != y.mesh.get_surface_count(): return false
			for si in x.mesh.get_surface_count():
				if x.mesh.surface_get_arrays(si) != y.mesh.surface_get_arrays(si): return false
			if not _material_equal(x.material_override, y.material_override): return false
	return true


func _material_equal(a: Material, b: Material) -> bool:
	if a == null or b == null: return a == b
	if a.get_class() != b.get_class(): return false
	if a is ShaderMaterial:
		if a.shader.resource_path != b.shader.resource_path: return false
		for prop in a.shader.get_shader_uniform_list():
			var av = a.get_shader_parameter(prop.name)
			var bv = b.get_shader_parameter(prop.name)
			if av is Resource:
				if bv == null or av.get_class() != bv.get_class(): return false
			elif typeof(av) == TYPE_FLOAT:
				if not is_equal_approx(av, bv): return false
			elif av != bv: return false
	else:
		for name in ["albedo_color", "metallic", "roughness", "emission", "emission_enabled", "transparency", "shading_mode"]:
			if a.get(name) != b.get(name): return false
	return true


func _geometry(root: Node) -> Array:
	var out: Array = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count(): out.append(mi.mesh.surface_get_arrays(si))
	return out
