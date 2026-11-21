extends "res://tests/lib/test_base.gd"
## 缓存精确参数、逐顶点等价、容量上限，以及加载取消时预制模块的释放。
const START := "none"
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const Factions = preload("res://scripts/factions/factions.gd")
const MV = preload("res://scripts/mech_visual.gd")
const Mech = preload("res://scripts/mech.gd")


class RaidStub extends Node:
	var hud = null
	var transit := {}
	var ended := false
	var dropping := true
	func _map_seed(stage: int) -> int:
		return 77 + stage


func run() -> void:
	var pts := [Vector3.ZERO, Vector3(0.3, 0.4, 0.5), Vector3.ONE]
	var first := A.tube(pts, 0.03, 16, 10)
	var original: Array = first.surface_get_arrays(0)
	if not check(first == A.tube(pts.duplicate(), 0.03, 16, 10), "相同软管未复用网格"):
		return
	for other in [A.tube(pts, 0.030001, 16, 10), A.tube(pts, 0.03, 18, 10), A.tube(pts, 0.03, 16, 12)]:
		if not check(first != other, "不同参数的软管错误共用网格"):
			return
	pts[1].x += 0.00001
	if not check(first != A.tube(pts, 0.03, 16, 10), "修改控制点未产生新几何"):
		return
	pts[1].x = 0.3
	for i in A.TUBE_CACHE_LIMIT + 1:
		A.tube([Vector3.ZERO, Vector3(float(i) + 2.0, 0, 0)], 0.02, 3, 1)
	if not check(A._tube_cache.size() <= A.TUBE_CACHE_LIMIT, "软管缓存超出容量"):
		return
	var rebuilt := A.tube(pts, 0.03, 16, 10)
	if not check(original == rebuilt.surface_get_arrays(0), "缓存淘汰重建改变了顶点、法线或切线"):
		return
	if not check(original == first.surface_get_arrays(0), "淘汰破坏了仍在使用的网格"):
		return
	var glass := K.canopy(Color(0.2, 0.4, 0.3), 0.18)
	if not check(glass == K.canopy(Color(0.2, 0.4, 0.3), 0.18), "座舱材质未复用"):
		return
	if not check(glass != K.canopy(Color(0.20001, 0.4, 0.3), 0.18) and glass != K.canopy(Color(0.2, 0.4, 0.3), 0.18001), "材质参数精度丢失"):
		return
	var fac := Factions.new()
	var stub := RaidStub.new()
	add_child(stub)
	stub.add_child(fac)
	Factions.test_ally_squad = [{"pilot": "rei", "tier": 2}, {"pilot": "kurumi", "tier": 2}]
	fac.setup(stub, Vector3.ZERO)
	Factions.test_ally_squad = null
	if not check(fac.allies.is_empty() and fac._spawn_jobs.size() == 2, "队友应在加载时准备、落地后才加入战场"):
		stub.free()
		return
	var held: Array = []
	for job: Dictionary in fac._spawn_jobs:
		if not check(job.slot_idx == MV.SLOTS.size() and job.prebuilt.size() == MV.SLOTS.size(), "队友仍有模块留到交战时冷构建"):
			stub.free()
			return
		for slot in MV.SLOTS:
			var mod: Node3D = job.prebuilt[slot]
			held.append(mod)
			if slot.begins_with("arm_"):
				if not check(mod.is_ancestor_of(mod.get_meta("muzzle")), "合批后炮口挂点丢失"):
					stub.free()
					return
	stub.free()
	for mod in held:
		if not check(not is_instance_valid(mod), "加载取消后预制模块泄漏"):
			return
	MV.request_module("arm_cannon")
	if not check(await until(func(): return MV.module_ready("arm_cannon"), 10.0), "后台模块脚本加载超时"):
		return
	var sync := MV.build_module("legs", "legs_tread", true, "42")
	var sliced := MV.build_module("legs", "legs_tread", true, "42")
	Mech._batch_visual(sync)
	await Mech._batch_visual(sliced, get_tree())
	var identical := _geometry(sync) == _geometry(sliced)
	sync.free()
	sliced.free()
	if not check(identical, "分帧合批改变了网格、变换或材质"):
		return
	var cancelled := MV.build_module("core", "core_fortress", true, "42")
	var finished := [false]
	_batch_task(cancelled, finished)
	cancelled.free()
	if not check(await until(func(): return finished[0], 2.0), "取消的分帧合批未结束"):
		return
	# 同时覆盖真正持有协程的调度器被销毁，而非仅销毁传入的模型根。
	var owner := Factions.new()
	add_child(owner)
	var pending := MV.build_module("legs", "legs_hex_colossus", true, "42")
	owner._spawn_jobs.append({"lo": {"legs": "legs_hex_colossus"}, "kind": "rover", "slot_idx": 0,
		"phase": 1, "pending_mod": pending, "prebuilt": {}})
	owner._step_spawn_queue()
	owner.free()
	await frames(3)
	if not check(not is_instance_valid(pending), "场景退出时正在合批的模块未释放"):
		return
	log_line("geometry, cache capacity, threaded loading, sliced batch equivalence and cancellation passed")


func _batch_task(root: Node3D, finished: Array) -> void:
	await Mech._batch_visual(root, get_tree())
	finished[0] = true


func _geometry(root: Node3D) -> Array:
	var out: Array = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := mi.transform
		var parent := mi.get_parent()
		while parent != root:
			xf = parent.transform * xf
			parent = parent.get_parent()
		var surfaces: Array = []
		for si in mi.mesh.get_surface_count():
			surfaces.append(mi.mesh.surface_get_arrays(si))
		out.append([xf, surfaces, mi.material_override, mi.cast_shadow])
	return out
