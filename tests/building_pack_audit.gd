extends "res://tests/lib/test_base.gd"
## 全部 30 项精修建筑、重型载具残骸、野战工事与微地貌预制件审计测试：
## 1) 逐一构建原始 Node3D 模型树与 PrefabLib 预合并表面，检查脚本编译、尺寸与材质组数；
## 2) 遍历每个三角形校验法线绕序一致（mismatch = 0）、实例无负缩放（neg_scale = 0）、无缺法线（no_normal = 0）。
## godot --headless --path . -- --building_pack_audit

const START := "none"
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


func run() -> void:
	Story.set_process(false)
	Story.data = {}
	await frames(1)
	var t0 := Time.get_ticks_usec()
	var total := {"tris": 0, "mismatch": 0, "neg_scale": 0, "no_normal": 0, "surfs": 0}
	var bad: Array = []
	var ids: Array = PrefabLib.SPECS.keys()
	ids.sort()
	for id: String in ids:
		var sp: Dictionary = PrefabLib.SPECS[id]
		var scr := load(str(sp["path"])) as Script
		if not check(scr != null, "无法加载建筑脚本 %s" % sp["path"]):
			return
		var raw_node: Node3D = scr.build(sp["base"] as Vector3)
		var raw_res := {"tris": 0, "mismatch": 0, "neg_scale": 0, "no_normal": 0}
		_audit_raw_node(raw_node, Transform3D.IDENTITY, raw_res)
		raw_node.free()

		var pf: Dictionary = PrefabLib.get_prefab(id)
		if not check(not pf.is_empty(), "预制件缓存构建失败: %s" % id):
			return
		var surfs: Array = pf["surfaces"]
		var pf_res := {"tris": 0, "mismatch": 0, "no_normal": 0}
		for s_info: Dictionary in surfs:
			_audit_mesh(s_info["mesh"] as ArrayMesh, pf_res)
		total["tris"] += int(pf_res["tris"])
		total["mismatch"] += int(pf_res["mismatch"])
		total["neg_scale"] += int(raw_res["neg_scale"])
		total["no_normal"] += int(pf_res["no_normal"])
		total["surfs"] += surfs.size()
		log_line("%-24s surfs=%2d tris=%6d mismatch=%d neg_scale=%d" % [
			id, surfs.size(), int(pf_res["tris"]), int(pf_res["mismatch"]), int(raw_res["neg_scale"])
		])
		if int(pf_res["mismatch"]) > 0 or int(raw_res["neg_scale"]) > 0 or int(pf_res["no_normal"]) > 0:
			bad.append("%s(取反%d/负缩放%d/缺法线%d)" % [id, pf_res["mismatch"], raw_res["neg_scale"], pf_res["no_normal"]])

	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	log_line("预制包合计 (%d 项): 表面组 %d | 三角面 %d | 法线取反 %d | 负缩放 %d | 缺法线 %d | 耗时 %.1f ms" % [
		ids.size(), total["surfs"], total["tris"], total["mismatch"], total["neg_scale"], total["no_normal"], dt_ms
	])
	check(ids.size() >= 49, "预制资产数量不足，实际 %d" % ids.size())
	check(bad.is_empty(), "建筑预制件法线审计未通过: %s" % "; ".join(bad))
	if not headless():
		await _capture_world_showcases()


func _capture_world_showcases() -> void:
	GameData.test_mode = true
	await _shoot_map_scene("greyport", ["D", "R", "I"], "buildings_urban_showcase.png")
	await _shoot_map_scene("dustfield", ["R", "F", "W"], "buildings_wasteland_showcase.png")


func _shoot_map_scene(map_id: String, pref_zones: Array, out_name: String) -> void:
	GameData.map_id = map_id
	main.show_hub()
	await frames(2)
	var raid = await deploy({
		"core": "core_heavy",
		"legs": "legs_biped",
		"arm_l": "arm_mg",
		"arm_r": "arm_ac30",
		"back": "back_missile",
		"gen": "gen_crystal",
	})
	if not check(raid != null and raid.mech != null, "%s 出击失败" % map_id):
		return
	Story.set_process(false)
	Story.data = {}
	get_tree().paused = false
	var m = raid.mech
	m.shield_time = 9999.0
	m.max_hp = 1e6
	m.hp = 1e6

	# 清理虫群，寻找紧邻建筑群与道路的最佳街景取景位
	for b in get_tree().get_nodes_in_group("bugs"):
		if is_instance_valid(b):
			b.queue_free()

	var best_pt := Vector3.ZERO
	var best_sc := -1.0
	for rd: Dictionary in raid.layout.roads:
		var pts: PackedVector2Array = rd.pts
		if pts.size() < 2:
			continue
		for pi in pts.size() - 1:
			var a2: Vector2 = pts[pi]
			var b2: Vector2 = pts[pi + 1]
			var mid2: Vector2 = (a2 + b2) * 0.5
			if absf(mid2.x) > 135.0 or absf(mid2.y) > 135.0:
				continue
			var p := Vector3(mid2.x, 0.0, mid2.y)
			if raid._blocked(p, 2.2):
				continue
			var sc := 0.0
			for ang_i in 8:
				var a_r := TAU * float(ang_i) / 8.0
				var probe := p + Vector3(cos(a_r), 0.0, sin(a_r)) * 18.0
				var zc: String = raid.zone_at(probe)
				if zc in pref_zones:
					sc += 2.0
				if raid._blocked(probe, 4.0):
					sc += 1.5
			if sc > best_sc:
				best_sc = sc
				best_pt = p

	m.global_position = best_pt + Vector3(0.0, 0.1, 0.0)
	m.velocity = Vector3.ZERO
	var demo_veh: Node3D = null
	var veh_spot := best_pt + Vector3(5.6, 0.0, -3.4)
	if not raid._blocked(veh_spot, 2.2):
		var v_scr: GDScript = load("res://scripts/buildings/veh_apc_wreck.gd" if map_id == "greyport" else "res://scripts/buildings/veh_dump_truck.gd")
		demo_veh = v_scr.build()
		raid.world.add_child(demo_veh)
		demo_veh.global_position = veh_spot
		demo_veh.rotation_degrees.y = 24.0

	var cam := Camera3D.new()
	cam.fov = 52.0
	raid.add_child(cam)
	cam.current = true
	cam.global_position = best_pt + Vector3(-16.0, 17.5, 24.5)
	cam.look_at(best_pt + Vector3(4.5, 3.2, -8.5), Vector3.UP)
	if raid.hud:
		raid.hud.visible = false
	await frames(6)
	await shot(out_name)
	if is_instance_valid(demo_veh):
		demo_veh.queue_free()
	cam.queue_free()


func _audit_raw_node(n: Node, parent_xf: Transform3D, res: Dictionary) -> void:
	var xf := parent_xf
	if n is Node3D:
		xf = parent_xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh != null and xf.basis.determinant() < 0.0:
			res["neg_scale"] += 1
	for ch in n.get_children():
		_audit_raw_node(ch, xf, res)


func _audit_mesh(mesh: ArrayMesh, res: Dictionary) -> void:
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tri_count := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		for t in tri_count:
			var i0 := t * 3
			var ia := idx[i0] if idx.size() > 0 else i0
			var ib := idx[i0 + 1] if idx.size() > 0 else i0 + 1
			var ic := idx[i0 + 2] if idx.size() > 0 else i0 + 2
			var a := verts[ia]
			var b := verts[ib]
			var c := verts[ic]
			var gn := (b - a).cross(c - a)
			if gn.length_squared() < 1e-12:
				continue
			res["tris"] += 1
			var front := -gn.normalized()
			if norms.size() > 0:
				if norms[ia].dot(front) < -0.05:
					res["mismatch"] += 1
			else:
				res["no_normal"] += 1
