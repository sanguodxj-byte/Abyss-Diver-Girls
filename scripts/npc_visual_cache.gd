extends RefCounted
## 离线合批的 NPC 模块；只读网格共享，动画节点与编号按实例独立。
const PATH := "res://assets/models/npc_modules.res"
const SERIAL := "__SERIAL__"
static var library: Resource


static func prepare() -> void:
	# 桌面烘焙保留桌面材质；移动渲染器沿用其专用生成器。
	if OS.has_feature("mobile") or RenderingServer.get_current_rendering_method() == "mobile": return
	if library == null and ResourceLoader.exists(PATH):
		library = load(PATH)
		if OS.has_feature("web"):
			# 保留离线网格缓存；只把桌面烘焙材质切到网页轻量着色器。
			for mat in materials():
				if mat is ShaderMaterial and mat.shader.resource_path == "res://shaders/mech_paint.gdshader":
					mat.shader = load("res://shaders/mech_paint_web.gdshader")


static func materials() -> Array:
	var unique := {}
	if library == null: return []
	for scene: PackedScene in library.get_meta("modules", {}).values():
		var state := scene.get_state()
		for node_i in state.get_node_count():
			for prop_i in state.get_node_property_count(node_i):
				if state.get_node_property_name(node_i, prop_i) == "material_override":
					var mat: Material = state.get_node_property_value(node_i, prop_i)
					if mat != null: unique[mat.get_instance_id()] = mat
	return unique.values()


static func instantiate(slot: String, id: String, serial: String) -> Node3D:
	if library == null: return null
	var scenes: Dictionary = library.get_meta("modules", {})
	var packed: PackedScene = scenes.get(slot + ":" + id)
	if packed == null: return null
	var root := packed.instantiate() as Node3D
	for node: Node in [root] + root.find_children("*", "", true, false):
		for key in node.get_meta_list():
			node.set_meta(key, _decode(node.get_meta(key), root))
		if node is Label3D:
			node.text = node.text.replace(SERIAL, serial)
	return root


static func pack(root: Node3D) -> PackedScene:
	for node: Node in [root] + root.find_children("*", "", true, false):
		if node != root: node.owner = root
		for key in node.get_meta_list():
			node.set_meta(key, _encode(node.get_meta(key), root))
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error != OK:
		push_error("Cannot pack NPC module: %d" % error)
		return null
	return packed


static func _encode(value: Variant, root: Node) -> Variant:
	if value is Node:
		assert(value == root or root.is_ancestor_of(value), "External node in NPC module metadata")
		return {"__npc_node_path": root.get_path_to(value)}
	if value is Array:
		var out: Array = []
		for item in value: out.append(_encode(item, root))
		return out
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = _encode(value[key], root)
		return out
	return value


static func _decode(value: Variant, root: Node) -> Variant:
	if value is Dictionary:
		if value.has("__npc_node_path"):
			return root.get_node(value.__npc_node_path)
		var out := {}
		for key in value: out[key] = _decode(value[key], root)
		return out
	if value is Array:
		var out: Array = []
		for item in value: out.append(_decode(item, root))
		return out
	return value


static func signature() -> Dictionary:
	var sources := ["art.gd", "mech.gd", "mech_visual.gd", "render_batch.gd", "npc_visual_cache.gd", "factions/factions.gd", "factions/npc_mech.gd"]
	var result := {}
	for path in sources: result[path] = FileAccess.get_sha256("res://scripts/" + path)
	for path in DirAccess.get_files_at("res://scripts/modules"):
		if path.ends_with(".gd"): result[path] = FileAccess.get_sha256("res://scripts/modules/" + path)
	result.equipment = FileAccess.get_sha256("res://data/ext/equipment.gd")
	return result
