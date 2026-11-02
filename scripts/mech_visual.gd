extends RefCounted
## 机甲装配器：按 loadout 把独立的模块模型通过标准接口拼装起来。
##
## 每个模块是 res://scripts/modules/<模块id>.gd 里的独立建模脚本（static func build(ctx) -> Node3D），
## 互相不引用；它们只通过 kit.gd 定义的标准接口（HP-C1 / HP-A1 / HP-B1 / HP-G1）对接：
##   底盘 ──HP-C1──▶ 躯干 ──HP-A1──▶ 左臂 / 右臂
##                          ├─HP-B1──▶ 背部挂载
##                          └─HP-G1──▶ 动力炉
## 新增模块只需：在 data\ext\equipment.gd 的 MODULES 里登记 + 新建同名建模脚本，并在根节点上放好对应接口的插头。
## 找不到建模脚本时用 _generic() 生成一个带标准插头的通用占位件。
##
## build() 返回的根节点 meta：torso / legs / muzzles{arm_l,arm_r} / leg_parts / torso_base_y / leg_type /
##   modules{slot: 模块节点} / loadout（当前装配）
## 机库用 swap()（单个模块拆装动画）与 explode()（爆炸视图）。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

const SLOTS := ["legs", "core", "arm_l", "arm_r", "back", "gen"]
const PARENT := {"core": "legs", "arm_l": "core", "arm_r": "core", "back": "core", "gen": "core"}
const EXPLODE := {"legs": 0.0, "core": 1.0, "arm_l": 1.5, "arm_r": 1.5, "back": 1.4, "gen": 1.4}
const SIDE := {"arm_l": -1.0, "arm_r": 1.0}


static func _gd():
	return Engine.get_main_loop().root.get_node("GameData")


# ================================================================ 单个模块
static func build_module(slot: String, id: String, lights := true, serial := "00") -> Node3D:
	var GD = _gd()
	if id == "" or not GD.is_module(id):
		return null
	# 变体（id#后缀）沿用基础模块的建模脚本；ctx.variant 为完整 id，ctx.info 为变体数值
	var base: String = GD.base_id(id)
	var info: Dictionary = GD.module(id)
	var ctx := {
		"id": base, "variant": id, "info": info, "slot": slot, "side": SIDE.get(slot, 0.0),
		"color": K.real(base, info.get("color", Color(0.5, 0.5, 0.5))),
		"lights": lights, "serial": serial,
	}
	var path := "res://scripts/modules/%s.gd" % base
	var m: Node3D
	if ResourceLoader.exists(path):
		m = load(path).build(ctx)
	else:
		m = _generic(slot, ctx)
	# 接口校验：插头必须与该槽位的标准接口一致
	var want: String = K.IFACES.get(slot, "")
	if str(m.get_meta("iface", "")) != want:
		push_warning("模块 %s 的接口 %s 与槽位 %s 需要的 %s 不符" % [id, m.get_meta("iface", ""), slot, want])
	m.set_meta("slot", slot)
	return m


## 通用占位件：任何没有专属建模的模块也能按标准接口装上
static func _generic(slot: String, ctx: Dictionary) -> Node3D:
	var M := K.armor(ctx.color)
	match slot:
		"legs":
			var r := K.module_root("legs", ctx.id, Vector3.ZERO)
			var parts: Array = []
			for sx in [-0.6, 0.6]:
				var leg := K.node(r, Vector3(sx, 1.5, 0))
				K.bb(leg, Vector3(0.4, 1.5, 0.45), M, Vector3(0, -0.75, 0))
				parts.append(leg)
			K.socket(r, "core", Vector3(0, 2.05, 0), Vector3.UP)
			r.set_meta("leg_parts", parts)
			r.set_meta("leg_type", "biped")
			return r
		"core":
			var r := K.module_root("core", ctx.id, Vector3.DOWN)
			K.bb(r, Vector3(1.4, 0.9, 1.2), M, Vector3(0, 0.35, 0.05))
			K.socket(r, "arm_l", Vector3(-0.72, 0.3, 0), Vector3.LEFT, -1.0)
			K.socket(r, "arm_r", Vector3(0.72, 0.3, 0), Vector3.RIGHT, 1.0)
			K.socket(r, "back", Vector3(0, 0.8, 0.3), Vector3(0, 1, 0.25))
			K.socket(r, "gen", Vector3(0, 0.12, 0.65), Vector3.BACK)
			return r
		"arm_l", "arm_r":
			var side: float = ctx.side
			var r := K.module_root(slot, ctx.id, Vector3(-side, 0, 0))
			K.bb(r, Vector3(0.36, 0.36, 1.2), M, Vector3(side * 0.25, 0, -0.35))
			var mz := Marker3D.new()
			mz.position = Vector3(side * 0.25, 0, -1.0)
			r.add_child(mz)
			r.set_meta("muzzle", mz)
			return r
		"back":
			var r := K.module_root("back", ctx.id, Vector3(0, -1, -0.25))
			K.bb(r, Vector3(0.9, 0.6, 0.7), M, Vector3(0, 0.35, 0.1))
			return r
		_:
			var r := K.module_root("gen", ctx.id, Vector3.FORWARD)
			K.bb(r, Vector3(0.7, 0.55, 0.4), M, Vector3(0, 0, 0.3))
			return r


# ================================================================ 装配
static func build(lo: Dictionary, with_lights := true) -> Node3D:
	var root := Node3D.new()
	root.name = "MechVisual"
	root.set_meta("lights", with_lights)
	root.set_meta("serial", "%02d" % (abs(hash(str(lo.get("core", "")) + str(lo.get("legs", "")))) % 90 + 10))
	root.set_meta("modules", {})
	root.set_meta("loadout", {})
	root.set_meta("explode", 0.0)
	A.ground_decal(root, A.blob_tex(), Color(1, 1, 1, 0.9), 3.8, Vector3(0, 0.03, 0))
	var mount := Node3D.new()
	mount.name = "TorsoMount"
	mount.set_meta("out", Vector3.UP)
	root.add_child(mount)
	var legs_id: String = lo.get("legs", "")
	if legs_id == "":
		legs_id = "legs_biped"
	for slot in SLOTS:
		var id: String = legs_id if slot == "legs" else str(lo.get(slot, ""))
		_install(root, slot, id, false)
	_refresh_meta(root)
	return root


## 插座查找：躯干挂在 TorsoMount（位置跟随底盘的 HP-C1 插座），其余挂在躯干的同名插座
static func _socket_for(root: Node3D, slot: String) -> Node3D:
	if slot == "legs":
		return root
	if slot == "core":
		return root.get_node("TorsoMount")
	var core: Node3D = root.get_meta("modules").get("core")
	if core == null:
		return null
	return core.get_node_or_null("Socket_" + slot)


static func _out(sock: Node3D) -> Vector3:
	return sock.get_meta("out", Vector3.UP) if sock else Vector3.UP


static func _rest_pos(root: Node3D, slot: String, sock: Node3D) -> Vector3:
	return _out(sock) * EXPLODE.get(slot, 0.0) * float(root.get_meta("explode", 0.0))


## 装入（或替换）一个模块。animate=true 时旧模块沿接口方向退出、新模块滑入对接。
static func _install(root: Node3D, slot: String, id: String, animate: bool) -> void:
	var mods: Dictionary = root.get_meta("modules")
	var lo: Dictionary = root.get_meta("loadout")
	var old: Node3D = mods.get(slot)
	var sock := _socket_for(root, slot)
	var m := build_module(slot, id, root.get_meta("lights"), root.get_meta("serial"))
	lo[slot] = id
	if m == null:
		mods.erase(slot)
	else:
		mods[slot] = m
	# 躯干换了：把它下面的臂 / 背 / 动力炉转插到新躯干的同名插座
	if slot == "core" and m != null:
		sock.add_child(m)
		for child_slot in ["arm_l", "arm_r", "back", "gen"]:
			var cm: Node3D = mods.get(child_slot)
			var ns: Node3D = m.get_node_or_null("Socket_" + child_slot)
			if cm and ns:
				cm.reparent(ns, false)
				cm.position = _rest_pos(root, child_slot, ns)
		m.position = _rest_pos(root, slot, sock)
	elif m != null and sock != null:
		sock.add_child(m)
		m.position = _rest_pos(root, slot, sock)
	# 底盘换了：躯干座圈移到新底盘的 HP-C1 插座高度
	if slot == "legs" and m != null:
		var ls: Node3D = m.get_node_or_null("Socket_core")
		var mount: Node3D = root.get_node("TorsoMount")
		var target := ls.position if ls else Vector3(0, 2.0, 0)
		if animate:
			var tw := root.create_tween()
			tw.tween_property(mount, "position", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			mount.position = target
	if animate:
		var out := _out(sock) if slot != "legs" else Vector3.DOWN
		var dist := 2.4 if slot != "legs" else 1.6
		if m != null:
			var rest := m.position
			m.position = rest + out * dist
			var tw := root.create_tween()
			tw.tween_interval(0.18 if old else 0.0)
			tw.tween_property(m, "position", rest, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if old:
			var tw2 := root.create_tween()
			tw2.tween_property(old, "position", old.position + out * dist, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw2.parallel().tween_property(old, "scale", Vector3.ONE * 0.6, 0.28)
			tw2.tween_callback(old.queue_free)
	elif old:
		old.queue_free()


## 机库：把装配同步到新 loadout，只拆装有变化的模块
static func apply(root: Node3D, lo: Dictionary, animate := true) -> void:
	var cur: Dictionary = root.get_meta("loadout")
	for slot in SLOTS:
		var id: String = str(lo.get(slot, ""))
		if slot == "legs" and id == "":
			id = "legs_biped"
		if str(cur.get(slot, "")) != id:
			_install(root, slot, id, animate)
	_refresh_meta(root)


## 爆炸视图：t=0 装配状态，t=1 各模块沿接口方向分离并显示接口铭牌
static func explode(root: Node3D, t: float, dur := 0.5) -> void:
	root.set_meta("explode", t)
	var mods: Dictionary = root.get_meta("modules")
	var tw := root.create_tween().set_parallel(true)
	for slot in mods:
		var m: Node3D = mods[slot]
		if not is_instance_valid(m) or slot == "legs":
			continue
		var sock := m.get_parent() as Node3D
		tw.tween_property(m, "position", _out(sock) * EXPLODE[slot] * t, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for tag in root.find_children("Tag", "Label3D", true, false):
		tag.visible = t > 0.5


static func _refresh_meta(root: Node3D) -> void:
	var mods: Dictionary = root.get_meta("modules")
	var mount: Node3D = root.get_node("TorsoMount")
	var legs: Node3D = mods.get("legs")
	root.set_meta("torso", mount)
	root.set_meta("legs", legs)
	root.set_meta("leg_parts", legs.get_meta("leg_parts", []) if legs else [])
	root.set_meta("leg_type", legs.get_meta("leg_type", "biped") if legs else "biped")
	root.set_meta("torso_base_y", mount.position.y)
	var muzzles := {}
	for slot in ["arm_l", "arm_r"]:
		var arm: Node3D = mods.get(slot)
		if arm and arm.has_meta("muzzle"):
			muzzles[slot] = arm.get_meta("muzzle")
		else:
			var sock := _socket_for(root, slot)
			var mz := Marker3D.new()
			mz.name = "Muzzle_" + slot
			(sock if sock else mount).add_child(mz)
			mz.position = Vector3(0, 0, -0.6)
			muzzles[slot] = mz
	root.set_meta("muzzles", muzzles)


## 机体损毁：所有模块在接口处脱开，沿接口方向抛出、翻滚后落地（纯表现，不影响逻辑）
static func scatter(root: Node3D) -> void:
	var mods: Dictionary = root.get_meta("modules")
	for slot in ["arm_l", "arm_r", "back", "gen", "core"]:
		var m: Node3D = mods.get(slot)
		if m == null or not is_instance_valid(m):
			continue
		var sock := m.get_parent() as Node3D
		var gpos := m.global_position
		m.reparent(root, true)
		var out := root.global_transform.basis.inverse() * (sock.global_transform.basis * _out(sock)) if sock else Vector3.UP
		var start := m.position
		var land := start + out * randf_range(1.2, 2.2) + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		land.y = 0.35 if slot != "core" else 0.9
		var peak := (start + land) * 0.5 + Vector3(0, 1.2, 0)
		var spin := Vector3(randf_range(-2.5, 2.5), randf_range(-2, 2), randf_range(-2.5, 2.5))
		var tw := root.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(m):
				m.position = start.lerp(peak, t).lerp(peak.lerp(land, t), t)
				m.rotation = spin * t, 0.0, 1.0, 0.75 + randf() * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		A.burst(root.get_parent() if root.get_parent() else root, gpos, {"amount": 10, "life": 0.6, "size": 0.12, "tex": A.soft_dot(), "additive": true,
			"vmin": 3.0, "vmax": 7.0, "spread": 70.0, "dir": Vector3.UP, "gravity": Vector3(0, -12, 0), "c0": Color(1, 0.8, 0.4), "c1": Color(1, 0.3, 0.1, 0)})
