extends Node
## 接口贴合检查：godot --path . -- --iface
## 对每个模块：
##   插头侧 —— 插头背面（模块内部一侧）必须有本体结构紧贴（间隙 ≤ TOL），且本体不能整块穿进父模块
##   插座侧 —— 躯干/底盘上的母座背后必须有本体结构承托（母座不能悬空）
const MV = preload("res://scripts/mech_visual.gd")
const K = preload("res://scripts/modules/kit.gd")

const TOL := 0.035
## 插头 / 母座的厚度（接合面 z=0，本体从这个深度开始）
const PLUG_DEPTH := {"HP-C1": 0.12, "HP-A1": 0.06, "HP-B1": 0.12, "HP-G1": 0.06}
const RECV_DEPTH := {"HP-C1": 0.1, "HP-A1": 0.06, "HP-B1": 0.05, "HP-G1": 0.045}
## 接口投影范围（半宽，XY）
const FOOT := {"HP-C1": Vector2(0.38, 0.38), "HP-A1": Vector2(0.2, 0.2), "HP-B1": Vector2(0.38, 0.28), "HP-G1": Vector2(0.37, 0.32)}

var errors := 0
var lines: Array = []


func _ready() -> void:
	var only: String = OS.get_environment("IFACE_ONLY")
	for id in GameData.MODULES:
		if only != "" and not id.begins_with(only):
			continue
		var info: Dictionary = GameData.MODULES[id]
		var slot: String = info.slot
		if slot == "arm":
			for s in ["arm_l", "arm_r"]:
				_check(id, s)
		else:
			_check(id, slot)
	for l in lines:
		print(l)
	print("[iface] modules=%d errors=%d" % [GameData.MODULES.size(), errors])
	get_tree().quit(0 if errors == 0 else 1)


func _check(id: String, slot: String) -> void:
	var m: Node3D = MV.build_module(slot, id, false)
	add_child(m)
	if slot != "legs":
		var plug: Node3D = m.get_node_or_null("Plug")
		if plug == null:
			_err("%s/%s 没有插头" % [id, slot])
		else:
			var iface: String = m.get_meta("iface")
			var r := _gap(m, plug, PLUG_DEPTH[iface], FOOT[iface], ["Plug"])
			if r.n == 0:
				_err("%s/%s 插头背后没有本体（悬空插头）" % [id, slot])
			elif r.gap > TOL:
				_err("%s/%s 插头与本体间隙 %.3fm" % [id, slot, r.gap])
			else:
				lines.append("  ok %s/%s 插头 gap=%.3f" % [id, slot, r.gap])
	# 母座
	for c in m.get_children():
		if c is Marker3D and str(c.name).begins_with("Socket_"):
			var recv: Node3D = c.get_node("Receiver")
			var iface2: String = c.get_meta("iface")
			var r2 := _gap(m, recv, RECV_DEPTH[iface2], FOOT[iface2], ["Plug", str(c.name)])
			if r2.n == 0:
				_err("%s 的母座 %s 背后没有承托结构" % [id, c.name])
			elif r2.gap > TOL:
				_err("%s 的母座 %s 与本体间隙 %.3fm" % [id, c.name, r2.gap])
			else:
				lines.append("  ok %s %s gap=%.3f" % [id, c.name, r2.gap])
	m.free()


## 在接口坐标系（-Z 朝外，z=0 接合面，+Z 为本体内部）里，找投影落在接口范围内的本体网格，
## 返回它们离接口背面（z=depth）的最小间隙
func _gap(m: Node3D, iface_node: Node3D, depth: float, foot: Vector2, skip: Array) -> Dictionary:
	var inv := iface_node.global_transform.affine_inverse()
	var best := INF
	var n := 0
	for mi in _meshes(m, skip):
		var ab: AABB = mi.get_aabb()
		var t: Transform3D = inv * mi.global_transform
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for i in 8:
			var p: Vector3 = t * ab.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
		if hi.x < -foot.x or lo.x > foot.x or hi.y < -foot.y or lo.y > foot.y:
			continue
		if hi.z < depth - 0.02:
			continue   # 在接合面外侧（穿进父模块的部分另算）
		n += 1
		best = minf(best, maxf(0.0, lo.z - depth))
	return {"gap": best, "n": n}


func _meshes(n: Node, skip: Array) -> Array:
	var out: Array = []
	for c in n.get_children():
		if str(c.name) in skip or (c is Marker3D and str(c.name).begins_with("Socket_")):
			continue
		if c is MeshInstance3D:
			out.append(c)
		out += _meshes(c, skip)
	return out


func _err(s: String) -> void:
	errors += 1
	lines.append("  !! " + s)
