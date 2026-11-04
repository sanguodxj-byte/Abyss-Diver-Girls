extends "res://tests/lib/test_base.gd"
## 渲染结构统计（无界面下数不了 draw call，改数结构）：godot --headless --path . -- --render_stats [--map=greyport]
## 统计 raid 子树里可见的 MeshInstance3D / MultiMeshInstance3D 数、去重材质数、估算 draw call（网格数 × 表面数）；
## 「视野内」= 包围盒到机甲水平距离 ≤ 45 米（俯视相机视锥约 ±40 米），且未被 visibility_range_end 剔除。
## --all=1：先把所有懒构建分块建好再统计（看整图合批后的总量）
## 结果打印为 [render_stats] 行

const TIMEOUT := 300.0


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return def


func run() -> void:
	GameData.map_id = _arg("map", "greyport")
	var Fac = load("res://scripts/factions/factions.gd")
	if Fac:
		Fac.rovers_enabled = false
	await wait(0.3)
	var raid = await deploy()
	if not check(raid != null, "出击失败"):
		return
	await frames(10)
	if _arg("all", "0") == "1" and raid.get("_rbatch") != null:
		raid._rbatch.show_all()   # 全部分块建好（看整图合批后的总量）
	var all := _stats(raid, raid.mech.global_position, raid.camera.global_position, false)
	var vis := _stats(raid, raid.mech.global_position, raid.camera.global_position, true)
	for pair in [["all", all], ["view", vis]]:
		var s: Dictionary = pair[1]
		print("[render_stats] map=%s scope=%s mesh_inst=%d multimesh=%d mm_instances=%d materials=%d est_draw_calls=%d world_draw_calls=%d static_draw_calls=%d static_materials=%d mm_without_aabb=%d" % [
			GameData.map_id, pair[0], s.mi, s.mmi, s.mm_inst, s.mats, s.dc, s.world_dc, s.static_dc, s.static_mats, s.mm_noaabb])
	if _arg("detail", "0") == "1":
		_detail(raid)
		if raid.get("_rbatch") != null:
			_mat_detail(raid)
	if Fac:
		Fac.rovers_enabled = true


func _stats(raid: Node, focus: Vector3, cam: Vector3, view_only: bool) -> Dictionary:
	var r := {"mi": 0, "mmi": 0, "mm_inst": 0, "dc": 0, "world_dc": 0, "static_dc": 0, "mm_noaabb": 0}
	var mats := {}
	var smats := {}
	var stack: Array = [[raid, false]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var dyn: bool = it[1] or n.is_in_group("bugs") or n.is_in_group("lootboxes") or n.is_in_group("allies") or n.is_in_group("rovers") \
				or n.is_in_group("extracts") or n.is_in_group("nests") or n == raid.mech
		if n is Node3D and not (n as Node3D).visible:
			continue
		if n is CanvasItem or n is CanvasLayer:
			continue
		for ch in n.get_children():
			stack.append([ch, dyn])
		if not (n is GeometryInstance3D):
			continue
		var gi: GeometryInstance3D = n
		var mesh: Mesh = null
		var mm_n := 0
		if gi is MeshInstance3D:
			mesh = gi.mesh
		elif gi is MultiMeshInstance3D and gi.multimesh:
			mesh = gi.multimesh.mesh
			mm_n = gi.multimesh.visible_instance_count if gi.multimesh.visible_instance_count >= 0 else gi.multimesh.instance_count
			if mm_n == 0:
				continue
		if mesh == null:
			continue
		if view_only:
			var ab: AABB
			if gi is MultiMeshInstance3D:
				if gi.custom_aabb.size != Vector3.ZERO:
					ab = gi.global_transform * gi.custom_aabb
				else:
					# 无界面下渲染服务器是空实现，读不到实例变换：没有 custom_aabb 的 MultiMesh 一律按「在视野内」计（上界）
					r.mm_noaabb += 1
					ab = AABB(focus, Vector3.ONE)
			else:
				ab = gi.global_transform * gi.get_aabb()
			var cx := clampf(focus.x, ab.position.x, ab.end.x)
			var cz := clampf(focus.z, ab.position.z, ab.end.z)
			if Vector2(cx - focus.x, cz - focus.z).length() > 45.0:
				continue
			if gi.visibility_range_end > 0.0 and cam.distance_to(ab.get_center()) > gi.visibility_range_end + gi.visibility_range_end_margin:
				continue
		var sc := mesh.get_surface_count()
		if gi is MeshInstance3D:
			r.mi += 1
		else:
			r.mmi += 1
			r.mm_inst += mm_n
		r.dc += sc
		var in_world: bool = raid.world and raid.world.is_ancestor_of(gi)
		if in_world:
			r.world_dc += sc
		if in_world and not dyn:
			r.static_dc += sc
		for i in sc:
			var m: Material = gi.material_override
			if m == null and gi is MeshInstance3D:
				m = (gi as MeshInstance3D).get_active_material(i)
			elif m == null:
				m = mesh.surface_get_material(i)
			if m:
				mats[m.get_rid()] = true
				if in_world and not dyn:
					smats[m.get_rid()] = true
	r["mats"] = mats.size()
	r["static_mats"] = smats.size()
	return r


## 按 world 下顶层子节点（脚本 / 分组 / 类型）汇总其子树里单个 MeshInstance3D 的数量
func _detail(raid: Node) -> void:
	var cnt := {}
	for top in raid.world.get_children():
		var scr = top.get_script()
		var k := "%s %s %s" % [top.get_class(), scr.resource_path.get_file() if scr else "-", str(top.get_groups().filter(func(g): return not str(g).begins_with("_")))]
		var c := 0
		var stack: Array = [top]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for ch in n.get_children():
				stack.append(ch)
			if n is MeshInstance3D:
				c += 1
		cnt[k] = int(cnt.get(k, 0)) + c
	var ks := cnt.keys()
	ks.sort_custom(func(a, b): return cnt[a] > cnt[b])
	for k in ks.slice(0, 20):
		print("[render_stats] detail %6d  %s" % [cnt[k], k])


## 合批分块里材质的来源分布（按类型 / 着色器）
func _mat_detail(raid: Node) -> void:
	var cnt := {}
	for gi in raid._rbatch.find_children("*", "GeometryInstance3D", true, false):
		var m: Material = gi.material_override
		var k := "null"
		if m is ShaderMaterial:
			k = "shader " + m.shader.resource_path.get_file() + " tint=" + str(m.get_shader_parameter("tint_mode"))
		elif m:
			k = m.get_class() + " " + str(m.get("albedo_color")) + " tex=" + str(m.get("albedo_texture") != null)
		if not cnt.has(k):
			cnt[k] = {}
		cnt[k][m] = true
	var ks := cnt.keys()
	ks.sort_custom(func(a, b): return cnt[a].size() > cnt[b].size())
	for k in ks.slice(0, 12):
		print("[render_stats] mats %4d  %s" % [cnt[k].size(), k])
	# 去色材质里哪些参数还在变（合不成一份的原因）
	var var_p := {}
	for k in cnt:
		if not k.begins_with("shader"):
			continue
		for m: ShaderMaterial in cnt[k]:
			for u in m.shader.get_shader_uniform_list():
				if not var_p.has(u.name):
					var_p[u.name] = {}
				var_p[u.name][str(m.get_shader_parameter(u.name))] = true
	for n in var_p:
		if var_p[n].size() > 3:
			print("[render_stats] param %s distinct=%d" % [n, var_p[n].size()])
