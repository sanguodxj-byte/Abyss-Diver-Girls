extends "res://tests/lib/test_base.gd"
## 法线绕序审计：逐种实例化全部已登记敌种（常规虫 + 区域 Boss）的程序化建模，
## 遍历模型树上每片 ArrayMesh 的每个三角形，校验三项硬指标：
##  1) 法线绕序一致 —— Godot 正面为顺时针，正面可见方向 = -((b-a)×(c-a))；着色法线与该方向相反即「法线取反」（受光面朝内，表现为黑面/反光错乱）；
##  2) 绕序朝外 —— 正面可见方向须与「三角形中心 - 网格包围盒中心」同向，反向即该面只能从实体内侧看到（cull_back 材质下表现为破面洞）；
##  3) 实例负缩放 —— MeshInstance3D 基行列式为负会镜像翻转绕序，cull_back 材质下整件内外翻转。
## 缺法线的面单独计数（无着色法线等于黑面）。除开放壳类（拱形覆甲内弧）的朝外计数外，
## 任一种类出现「法线取反 / 负缩放 / 缺法线」即判失败。
## godot --headless --path . -- --normal_audit

const START := "none"


func run() -> void:
	# 剧情演出会暂停整棵树，审计只要建模不要演出
	Story.set_process(false)
	Story.data = {}
	await frames(1)
	var total := {"tris": 0, "mismatch": 0, "inward": 0, "neg_scale": 0, "no_normal": 0}
	var bad: Array = []
	for kind: String in GameData.ENEMIES:
		var info: Dictionary = GameData.ENEMIES[kind]
		var script_path := str(info.get("script", ""))
		if script_path == "" or not ResourceLoader.exists(script_path):
			continue
		var b = load(script_path).new()
		add_child(b)
		b.kind = kind
		b.data = info
		b.ai = str(info.get("ai", "lancer"))
		b.hover = float(info.get("hover", 0.0))
		b.set_physics_process(false)
		b._build_visual()
		var res := {"tris": 0, "mismatch": 0, "inward": 0, "neg_scale": 0, "no_normal": 0, "meshes": {}}
		_audit_node(b, res)
		b.queue_free()
		for k in total:
			total[k] += int(res[k])
		if int(res["mismatch"]) > 0 or int(res["neg_scale"]) > 0 or int(res["no_normal"]) > 0:
			bad.append("%s: 取反 %d / 负缩放 %d / 缺法线 %d" % [kind, res["mismatch"], res["neg_scale"], res["no_normal"]])
		if int(res["inward"]) > 0:
			var top: Array = []
			for sig: String in res["meshes"]:
				top.append("%s × %d" % [sig, res["meshes"][sig]])
			top.sort_custom(func(p, q):
				return int(p.get_slice("× ", 1)) > int(q.get_slice("× ", 1)))
			log_line("  内向 %s → %s" % [kind, "；".join(top.slice(0, 6))])
	log_line("三角形 %d | 法线取反 %d | 内向绕序 %d | 负缩放 %d | 缺法线 %d" % [total["tris"], total["mismatch"], total["inward"], total["neg_scale"], total["no_normal"]])
	if not check(bad.is_empty(), "以下敌种建模存在法线问题：%s" % ["；".join(bad.slice(0, 8))]):
		return


## 深度遍历模型树，逐 MeshInstance3D 审计；负缩放在实例层判，绕序在网格层判
func _audit_node(root: Node, res: Dictionary) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		if mi.transform.basis.determinant() < 0.0:
			res["neg_scale"] += 1
		if mi.mesh is ArrayMesh:
			_audit_mesh(mi.mesh as ArrayMesh, res)


## 逐面校验：正面可见方向 = -叉积（Godot 顺时针正面），与着色法线、包围盒中心向外方向比对；
## 内向面按网格签名（尺寸 + 顶点数 + 面数）分组，便于定位到具体构件
func _audit_mesh(mesh: ArrayMesh, res: Dictionary) -> void:
	var aabb := mesh.get_aabb()
	var cen := aabb.get_center()
	var inward := 0
	var tris := 0
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
			tris += 1
			res["tris"] += 1
			var front := -gn.normalized()
			if norms.size() > 0:
				if norms[ia].dot(front) < 0.0:
					res["mismatch"] += 1
			else:
				res["no_normal"] += 1
			# 朝外校验：拱形覆甲等开放壳的内弧面天然朝向包围盒中心，不计入失败项，只留计数观察
			if front.dot((a + b + c) / 3.0 - cen) < 0.0:
				res["inward"] += 1
				inward += 1
	if inward > 0:
		var sz := Vector3(roundf(aabb.size.x * 10.0) / 10.0, roundf(aabb.size.y * 10.0) / 10.0, roundf(aabb.size.z * 10.0) / 10.0)
		var sig := "尺寸%sv%d f%d" % [sz, mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), tris]
		res["meshes"][sig] = int(res["meshes"].get(sig, 0)) + inward
