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
const MechGlb = preload("res://scripts/modules/mech_glb.gd")
const Prof = preload("res://scripts/prof.gd")
const DA = preload("res://scripts/death_anim.gd")

const SLOTS := ["legs", "core", "arm_l", "arm_r", "back", "gen"]
const PARENT := {"core": "legs", "arm_l": "core", "arm_r": "core", "back": "core", "gen": "core"}
const EXPLODE := {"legs": 0.0, "core": 1.0, "arm_l": 1.5, "arm_r": 1.5, "back": 1.4, "gen": 1.4}
const SIDE := {"arm_l": -1.0, "arm_r": 1.0}
static var _builders := {}
static var _loading_builders := {}


static func _gd():
	return Engine.get_main_loop().root.get_node("GameData")


## 增援入队时提前请求脚本（或高精度 GLB），主线程只在状态为 LOADED 后取结果，避免首次解析阻塞战斗。
static func request_module(id: String) -> void:
	if id.is_empty():
		return
	var base: String = _gd().base_id(id)
	if MechGlb.has_glb(base):
		MechGlb.request_glb(base)
		return
	var path := "res://scripts/modules/%s.gd" % base
	if _builders.has(path) or _loading_builders.has(path) or not ResourceLoader.exists(path):
		return
	var err := ResourceLoader.load_threaded_request(path, "GDScript")
	if err != OK:
		push_error("Module request failed (%d): %s" % [err, path])
	_loading_builders[path] = true


static func module_ready(id: String) -> bool:
	var base: String = _gd().base_id(id)
	if MechGlb.has_glb(base):
		return MechGlb.glb_ready(base)
	var path := "res://scripts/modules/%s.gd" % base
	if not _loading_builders.has(path):
		return true
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_LOADED:
			_builders[path] = ResourceLoader.load_threaded_get(path)
			_loading_builders.erase(path)
			return true
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Module load failed: " + path)
	return false


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
	var m: Node3D = null
	if MechGlb.has_glb(base):
		var t_glb := Prof.t0()
		m = MechGlb.build(slot, ctx)
		Prof.add("spawn.module_build", t_glb)
	if m == null:
		var path := "res://scripts/modules/%s.gd" % base
		if ResourceLoader.exists(path):
			var t := Prof.t0()
			var builder = _builders.get(path)
			if builder == null:
				builder = load(path)
				_builders[path] = builder
			Prof.add("spawn.module_load", t)
			t = Prof.t0()
			m = builder.build(ctx)
			Prof.add("spawn.module_build", t)
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
static func build(lo: Dictionary, with_lights := true, with_shadow := true) -> Node3D:
	var root := Node3D.new()
	root.name = "MechVisual"
	root.set_meta("lights", with_lights)
	root.set_meta("serial", "%02d" % (abs(hash(str(lo.get("core", "")) + str(lo.get("legs", "")))) % 90 + 10))
	root.set_meta("modules", {})
	root.set_meta("loadout", {})
	root.set_meta("explode", 0.0)
	if with_shadow:
		A.add(root, A.quad(4.2, 4.2), A.contact_shadow_mat(0.56), Vector3(0, 0.034, 0), Vector3.ZERO, Vector3.ONE, false)
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
	_sync_ifaces(root)
	return root


## 将分帧预构建（并已按单模块合批）的模块表组装为完整 MechVisual，消除单帧多机甲生成导致的秒级卡顿
static func assemble_prebuilt(lo: Dictionary, prebuilt: Dictionary, with_lights := true, with_shadow := true) -> Node3D:
	var root := Node3D.new()
	root.name = "MechVisual"
	root.set_meta("lights", with_lights)
	root.set_meta("serial", "%02d" % (abs(hash(str(lo.get("core", "")) + str(lo.get("legs", "")))) % 90 + 10))
	root.set_meta("modules", {})
	root.set_meta("loadout", {})
	root.set_meta("explode", 0.0)
	if with_shadow:
		A.add(root, A.quad(4.2, 4.2), A.contact_shadow_mat(0.56), Vector3(0, 0.034, 0), Vector3.ZERO, Vector3.ONE, false)
	var mount := Node3D.new()
	mount.name = "TorsoMount"
	mount.set_meta("out", Vector3.UP)
	root.add_child(mount)
	var legs_id: String = lo.get("legs", "")
	if legs_id == "":
		legs_id = "legs_biped"
	var mods: Dictionary = root.get_meta("modules")
	var lo_meta: Dictionary = root.get_meta("loadout")
	for slot in SLOTS:
		var id: String = legs_id if slot == "legs" else str(lo.get(slot, ""))
		var m: Node3D = prebuilt.get(slot, null)
		if m == null and id != "":
			m = build_module(slot, id, with_lights, root.get_meta("serial"))
		lo_meta[slot] = id
		if m == null:
			continue
		mods[slot] = m
		var sock := _socket_for(root, slot)
		if sock != null:
			sock.add_child(m)
			m.position = Vector3.ZERO
		if slot == "legs":
			var ls: Node3D = m.get_node_or_null("Socket_core")
			var target := ls.position if ls else Vector3(0, 2.0, 0)
			mount.position = target
			mount.set_meta("target_y", target.y)
	_refresh_meta(root)
	_sync_ifaces(root)
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
		mount.set_meta("target_y", target.y)
		if animate:
			var tw := root.create_tween()
			tw.tween_property(mount, "position", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			mount.position = target
	if animate:
		_set_slot_iface_visible(root, slot, m, sock, true)
		var out := _out(sock) if slot != "legs" else Vector3.DOWN
		var dist := 2.4 if slot != "legs" else 1.6
		if m != null:
			var rest := m.position
			m.position = rest + out * dist
			var tw := root.create_tween()
			tw.tween_interval(0.18 if old else 0.0)
			tw.tween_property(m, "position", rest, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func():
				if is_instance_valid(root):
					_sync_ifaces(root))
		if old:
			var old_plug: Node3D = old.get_node_or_null("Plug")
			if old_plug:
				old_plug.visible = true
			old.set_meta("_detaching", true)
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
	if not animate:
		_sync_ifaces(root)


## 爆炸视图：t=0 装配状态，t=1 各模块沿接口方向分离并显示接口铭牌
static func explode(root: Node3D, t: float, dur := 0.5) -> void:
	root.set_meta("explode", t)
	if t > 0.01:
		_sync_ifaces(root)
	var mods: Dictionary = root.get_meta("modules")
	var tw := root.create_tween().set_parallel(true)
	for slot in mods:
		var m: Node3D = mods[slot]
		if not is_instance_valid(m) or slot == "legs":
			continue
		var sock := m.get_parent() as Node3D
		tw.tween_property(m, "position", _out(sock) * EXPLODE[slot] * t, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if slot.begins_with("arm"):
			tw.tween_property(m, "rotation", Vector3.ZERO, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if t <= 0.01:
		tw.finished.connect(func():
			if is_instance_valid(root):
				_sync_ifaces(root))
	for tag in root.find_children("Tag", "Label3D", true, false):
		tag.visible = t > 0.5


static func _set_slot_iface_visible(_root: Node3D, slot: String, m: Node3D, sock: Node3D, vis: bool) -> void:
	if m != null and is_instance_valid(m):
		var plug: Node3D = m.get_node_or_null("Plug")
		if plug:
			plug.visible = vis
	if sock != null and is_instance_valid(sock):
		if slot == "core":
			var legs: Node3D = _root.get_meta("modules", {}).get("legs")
			if legs and is_instance_valid(legs):
				var ls: Node3D = legs.get_node_or_null("Socket_core")
				if ls and ls.has_node("Receiver"):
					(ls.get_node("Receiver") as Node3D).visible = vis
		elif sock.has_node("Receiver"):
			(sock.get_node("Receiver") as Node3D).visible = vis


## 装配紧贴时隐藏接合面内部的程序化公母插头以彻底消除与高精度 GLB 法兰共面闪烁；空槽或爆炸/拆解视图自动显露。
static func _sync_ifaces(root: Node3D) -> void:
	var exploded := float(root.get_meta("explode", 0.0)) > 0.01
	var mods: Dictionary = root.get_meta("modules", {})
	for slot in mods:
		var m: Node3D = mods[slot]
		if not is_instance_valid(m):
			continue
		var plug: Node3D = m.get_node_or_null("Plug")
		if plug:
			plug.visible = exploded
		for c in m.get_children():
			if c is Marker3D and str(c.name).begins_with("Socket_"):
				var child_slot := str(c.name).substr(7)
				var recv: Node3D = c.get_node_or_null("Receiver")
				if recv:
					recv.visible = exploded or (mods.get(child_slot) == null)


static func _local_offset_in(child: Node3D, ancestor: Node3D) -> Vector3:
	var xf := Transform3D.IDENTITY
	var cur: Node = child
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf.origin


static func _refresh_meta(root: Node3D) -> void:
	var mods: Dictionary = root.get_meta("modules")
	var mount: Node3D = root.get_node("TorsoMount")
	var legs: Node3D = mods.get("legs")
	root.set_meta("torso", mount)
	root.set_meta("legs", legs)
	root.set_meta("leg_parts", legs.get_meta("leg_parts", []) if legs else [])
	root.set_meta("leg_type", legs.get_meta("leg_type", "biped") if legs else "biped")
	root.set_meta("torso_base_y", float(mount.get_meta("target_y", mount.position.y)))
	var muzzles := {}
	var arm_sockets := {}
	for slot in ["arm_l", "arm_r"]:
		var sock := _socket_for(root, slot)
		arm_sockets[slot] = sock
		var arm: Node3D = mods.get(slot)
		if arm and arm.has_meta("muzzle"):
			var mz_node: Node3D = arm.get_meta("muzzle")
			muzzles[slot] = mz_node
			if is_instance_valid(mz_node) and not arm.has_meta("muzzle_local"):
				arm.set_meta("muzzle_local", _local_offset_in(mz_node, arm))
		else:
			var mz := Marker3D.new()
			mz.name = "Muzzle_" + slot
			(sock if sock else mount).add_child(mz)
			mz.position = Vector3(0, 0, -0.6)
			muzzles[slot] = mz
			if arm and not arm.has_meta("muzzle_local"):
				arm.set_meta("muzzle_local", Vector3(0, 0, -0.6))
	root.set_meta("muzzles", muzzles)
	root.set_meta("arm_sockets", arm_sockets)


## 机体损毁：三段式重装殉爆解体 —— 模块在接口处分批崩脱，沿世界空间真实抛物线翻滚、触地弹跳滑行并精确贴合地形法线与高度；
## 同时驱动双足/四足/六足/履带底盘按解析逆运动学泄压跪倒坍塌，100% 消除残骸悬空与僵直站立。
static func scatter(root: Node3D, fx_host: Node = null, ctx: Node = null) -> void:
	if root == null or not is_instance_valid(root):
		return
	root.set_meta("explode", 1.0)
	_sync_ifaces(root)
	var world_ctx: Node = ctx if (ctx != null and is_instance_valid(ctx)) else root
	var fx_parent: Node = fx_host if (fx_host != null and is_instance_valid(fx_host)) else (root.get_parent() if root.get_parent() else root)
	var mods: Dictionary = root.get_meta("modules", {})
	var root_w := root.global_position

	# 1. 上装五模块分批崩脱（动力炉过载先崩 → 背挂/双臂飞脱 → 主躯干炸离），全程 top_level 世界空间解算避免底盘跪倒牵连浮空
	var delays := {"gen": 0.0, "back": 0.04, "arm_l": 0.07, "arm_r": 0.09, "core": 0.12}
	for slot in ["gen", "back", "arm_l", "arm_r", "core"]:
		var m: Node3D = mods.get(slot)
		if m == null or not is_instance_valid(m):
			continue
		var sock := m.get_parent() as Node3D
		var g0 := m.global_transform
		var start_w := g0.origin
		var B0 := g0.basis
		var out_w := (sock.global_transform.basis * _out(sock)).normalized() if sock else Vector3.UP
		var horiz := Vector3(out_w.x, 0.0, out_w.z)
		if horiz.length_squared() < 0.04:
			var rand_a := randf() * TAU
			horiz = Vector3(cos(rand_a), 0.0, sin(rand_a))
		else:
			horiz = horiz.rotated(Vector3.UP, randf_range(-0.42, 0.42)).normalized()

		m.reparent(root, false)
		m.top_level = true
		m.global_transform = g0

		var throw_d := randf_range(1.65, 2.75) if slot != "core" else randf_range(1.05, 1.75)
		var skid_d := randf_range(0.32, 0.58) if slot != "core" else randf_range(0.24, 0.42)
		var raw_impact := start_w + horiz * throw_d
		var raw_final := start_w + horiz * (throw_d + skid_d)
		var impact_w := DA.clamp_scatter_xz(world_ctx, root_w, raw_impact, 0.72)
		var final_w := DA.clamp_scatter_xz(world_ctx, impact_w, raw_final, 0.65)
		var g_imp := DA.sample_ground(world_ctx, Vector3(impact_w.x, root_w.y, impact_w.z), 3.0, 48.0)
		var g_fin := DA.sample_ground(world_ctx, Vector3(final_w.x, root_w.y, final_w.z), 3.0, 48.0)

		# 构造自然稳定的世界空间旋转增量（长臂武器侧翻平躺于地面，杜绝炮口竖立插地或悬空；箱体模块按坡面微倾稳坐）
		var fwd0 := -B0.z
		fwd0.y = 0.0
		if fwd0.length_squared() < 1e-4:
			fwd0 = Vector3.FORWARD
		else:
			fwd0 = fwd0.normalized()
		var d_yaw := randf_range(-1.35, 1.35)
		var yaw_rot := Basis(Vector3.UP, d_yaw)
		var fwd1 := (yaw_rot * fwd0).normalized()
		var rgt1 := fwd1.cross(Vector3.UP).normalized()
		var side_sgn := 1.0 if randf() < 0.5 else -1.0
		var roll_end := side_sgn * randf_range(1.36, 1.52) if slot.begins_with("arm") else side_sgn * randf_range(0.18, 0.44)
		var pitch_end := randf_range(-0.10, 0.12) if slot.begins_with("arm") else randf_range(-0.28, 0.34)
		var nrm_fin: Vector3 = g_fin.normal
		var up_tilt := Vector3.UP.lerp(nrm_fin, 0.75).normalized()
		var slope_axis := Vector3.UP.cross(up_tilt)
		var R_slope := Basis(slope_axis.normalized(), Vector3.UP.angle_to(up_tilt)) if slope_axis.length_squared() > 1e-5 else Basis.IDENTITY
		var R_end := (R_slope * Basis(rgt1, pitch_end) * Basis(fwd1, roll_end) * yaw_rot).orthonormalized()
		var q_end := R_end.get_rotation_quaternion()

		# 用精确包围盒最低坡面净空反推模块原点落地世界 Y（确保任意造型、镜像左臂及斜坡落点均 100% 贴地零浮空）
		var embed := 0.026
		var imp_y: float = float(g_imp.y) - DA.lowest_offset_under_world_rot(m, R_end, g_imp.normal) - embed
		var fin_y: float = float(g_fin.y) - DA.lowest_offset_under_world_rot(m, R_end, nrm_fin) - embed
		var arc_h := randf_range(1.15, 1.85) if slot != "core" else randf_range(0.85, 1.35)
		var bounce_h := randf_range(0.16, 0.28) if slot != "core" else 0.14
		var dur := randf_range(0.76, 0.94)
		var dly: float = float(delays.get(slot, 0.0))

		var tw := root.create_tween()
		DA.power_down_wreck(m, tw, 0.55, 0.60 if slot == "core" else 0.68)
		if dly > 0.001:
			tw.tween_interval(dly)
		tw.tween_callback(func():
			if is_instance_valid(fx_parent):
				A.burst(fx_parent, start_w, {"amount": 14, "life": 0.52, "size": 0.14, "tex": A.soft_dot(), "additive": true,
					"vmin": 3.5, "vmax": 8.5, "spread": 78.0, "dir": out_w, "gravity": Vector3(0, -14, 0),
					"c0": Color(1.0, 0.86, 0.45), "c1": Color(1.0, 0.32, 0.08, 0.0)}))
		var impacted := [false]
		tw.tween_method(func(u: float):
			if not is_instance_valid(m):
				return
			var hit_u := 0.74
			var pos_w: Vector3
			var q_cur: Quaternion
			if u <= hit_u:
				var s := u / hit_u
				var xz := start_w.lerp(impact_w, s)
				var py := lerpf(start_w.y, imp_y, s * s * 0.65 + s * 0.35) + arc_h * 4.0 * s * (1.0 - s)
				pos_w = Vector3(xz.x, py, xz.z)
				q_cur = Quaternion.IDENTITY.slerp(q_end, clampf(s * 0.92, 0.0, 1.0))
			else:
				if not impacted[0]:
					impacted[0] = true
					if is_instance_valid(fx_parent):
						var ip := Vector3(impact_w.x, float(g_imp.y) + 0.14, impact_w.z)
						A.burst(fx_parent, ip, {"amount": 10, "life": 0.36, "size": 0.11, "tex": A.soft_dot(), "additive": true,
							"vmin": 2.8, "vmax": 6.8, "spread": 82.0, "dir": Vector3.UP, "gravity": Vector3(0, -15, 0),
							"c0": Color(1.0, 0.82, 0.42), "c1": Color(1.0, 0.35, 0.08, 0.0)})
						A.burst(fx_parent, ip, {"amount": 7, "life": 0.68, "size": 0.72, "tex": A.dust_tex(), "additive": false,
							"vmin": 1.0, "vmax": 2.6, "spread": 86.0, "dir": Vector3(0, 0.28, 0), "gravity": Vector3(0, 0.25, 0), "damp": 4.2,
							"c0": Color(0.56, 0.52, 0.46, 0.0), "cmid": Color(0.52, 0.48, 0.42, 0.44), "cmid_pos": 0.18,
							"c1": Color(0.45, 0.42, 0.38, 0.0), "grow0": 0.45, "grow1": 1.65})
				var b := (u - hit_u) / (1.0 - hit_u)
				var ease_b := 1.0 - (1.0 - b) * (1.0 - b)
				var xz2 := impact_w.lerp(final_w, ease_b)
				var py2 := lerpf(imp_y, fin_y, ease_b) + bounce_h * 4.0 * b * (1.0 - b)
				pos_w = Vector3(xz2.x, py2, xz2.z)
				q_cur = Quaternion.IDENTITY.slerp(q_end, lerpf(0.92, 1.0, ease_b))
			m.global_transform = Transform3D(Basis(q_cur) * B0, pos_w), 0.0, 1.0, dur)
		if slot == "core":
			tw.tween_callback(func():
				if is_instance_valid(m) and is_instance_valid(fx_parent):
					var smk := A.emitter(m, Vector3(0.0, 0.35, 0.0), {"amount": 16, "life": 1.45, "size": 0.88, "tex": A.smoke_tex(),
						"additive": false, "spread": 24.0, "vmin": 0.7, "vmax": 1.8, "gravity": Vector3(0.0, 1.9, 0.0), "damp": 1.5,
						"c0": Color(0.08, 0.08, 0.09, 0.0), "cmid": Color(0.11, 0.10, 0.10, 0.62), "cmid_pos": 0.18,
						"c1": Color(0.16, 0.15, 0.15, 0.0), "grow0": 0.5, "grow1": 2.1})
					var stw := m.create_tween()
					stw.tween_interval(2.6)
					stw.tween_callback(func():
						if is_instance_valid(smk):
							smk.emitting = false)
					stw.tween_interval(1.6)
					stw.tween_callback(func():
						if is_instance_valid(smk):
							smk.queue_free()))

	# 2. 底盘分构型解析逆运动学坍塌（玩家与 NPC 机甲共享同一套重型跪倒/趴窝表现，彻底告别僵尸站立与跷跷板悬空）
	collapse_chassis(root, fx_parent, world_ctx)


## 驱动底盘（双足跪倒、四/六足泄压趴地、履带断轴震沉）并按真实包围盒最低点精确贴地。
static func collapse_chassis(root: Node3D, fx_parent: Node = null, world_ctx: Node = null) -> void:
	var legs: Node3D = root.get_meta("legs", null)
	if legs == null or not is_instance_valid(legs):
		return
	var ctx: Node = world_ctx if (world_ctx != null and is_instance_valid(world_ctx)) else root
	var leg_type := str(root.get_meta("leg_type", "biped"))
	var leg_parts: Array = root.get_meta("leg_parts", [])
	var g_info := DA.sample_ground(ctx, root.global_position, 3.2, 48.0)
	var ground_y: float = float(g_info.y)
	var ground_nrm: Vector3 = g_info.normal

	# 记录初始关节状态
	var orig_legs_pos := legs.position
	var orig_legs_rot := legs.rotation
	var joint_targets: Array = []
	var side_sgn := 1.0 if randf() < 0.5 else -1.0
	var target_legs_rot := Vector3(orig_legs_rot.x, orig_legs_rot.y, orig_legs_rot.z)

	var root_inv_b := root.global_transform.basis.orthonormalized().inverse()
	var world_yaw := (root.global_transform.basis.orthonormalized() * Basis.from_euler(orig_legs_rot)).get_euler().y

	if leg_type == "biped" and leg_parts.size() >= 2:
		var kneel_i := randi() % 2
		var sb_bi := DA.slope_basis(ground_nrm, world_yaw, 0.18, 0.09 if kneel_i == 0 else -0.09, 0.72)
		target_legs_rot = (root_inv_b * sb_bi).get_euler()
		for i in leg_parts.size():
			var lp: Node3D = leg_parts[i]
			if lp == null or not is_instance_valid(lp) or not lp.has_meta("knee") or not lp.has_meta("ankle"):
				continue
			var kj: Node3D = lp.get_meta("knee")
			var aj: Node3D = lp.get_meta("ankle")
			var KN: Vector3 = lp.get_meta("KN")
			var AN: Vector3 = lp.get_meta("AN")
			var is_kneel := (i == kneel_i)
			var dz := -0.30 if is_kneel else 0.38
			var crouch := absf(AN.y) * (0.48 if is_kneel else 0.44)
			var toe := 0.28 if is_kneel else -0.06
			var ik := _solve_2bone_zy(KN, AN, Vector2(AN.z + dz, AN.y + crouch))
			var s_x := -1.0 if i == 0 else 1.0
			joint_targets.append([lp, lp.rotation, Vector3(ik.x, s_x * 0.08, s_x * 0.05)])
			joint_targets.append([kj, kj.rotation, Vector3(ik.y, 0.0, 0.0)])
			joint_targets.append([aj, aj.rotation, Vector3(-(ik.x + ik.y) + toe, 0.0, 0.0)])
	elif leg_type in ["quad", "hex"] and not leg_parts.is_empty():
		var sb_qh := DA.slope_basis(ground_nrm, world_yaw, randf_range(-0.04, 0.06), side_sgn * 0.05, 0.88)
		target_legs_rot = (root_inv_b * sb_qh).get_euler()
		for i in leg_parts.size():
			var lp: Node3D = leg_parts[i]
			if lp == null or not is_instance_valid(lp) or not lp.has_meta("femur") or not lp.has_meta("knee") or not lp.has_meta("ankle"):
				continue
			var fm: Node3D = lp.get_meta("femur")
			var kj: Node3D = lp.get_meta("knee")
			var aj: Node3D = lp.get_meta("ankle")
			var KN: Vector3 = lp.get_meta("KN")
			var AN: Vector3 = lp.get_meta("AN")
			var byaw: float = float(lp.get_meta("base_yaw", lp.rotation.y))
			var r_splay := maxf(AN.z, 0.3) * randf_range(1.14, 1.26)
			var crouch_s := absf(AN.y) * 0.68
			var ik_s := _solve_2bone_zy(KN, AN, Vector2(r_splay, AN.y + crouch_s))
			joint_targets.append([lp, lp.rotation, Vector3(0.0, byaw + randf_range(-0.14, 0.14), 0.0)])
			joint_targets.append([fm, fm.rotation, Vector3(ik_s.x, 0.0, 0.0)])
			joint_targets.append([kj, kj.rotation, Vector3(ik_s.y, 0.0, 0.0)])
			joint_targets.append([aj, aj.rotation, Vector3(-(ik_s.x + ik_s.y) + 0.08, 0.0, 0.0)])
	else:
		# 履带底盘：扭杆悬挂泄压微倾并贴合地面法线（绝不单边翘起悬空）
		var sb := DA.slope_basis(ground_nrm, world_yaw, randf_range(0.03, 0.07), side_sgn * 0.055, 0.85)
		target_legs_rot = (root_inv_b * sb).get_euler()

	# 姿态预演测量（PMRT）：在同一帧内临时应用目标关节角，精确计算保证最低点贴合坡面的 legs.position.y，随后立即还原
	var saved_root_pos := root.global_position
	var gpt_c := Vector3(saved_root_pos.x, ground_y, saved_root_pos.z)
	root.global_position = gpt_c
	legs.position = Vector3(orig_legs_pos.x, 0.0, orig_legs_pos.z)
	legs.rotation = target_legs_rot
	for jt in joint_targets:
		(jt[0] as Node3D).rotation = jt[2]
	var min_clr := DA.lowest_slope_clearance(legs, gpt_c, ground_nrm)
	var root_sy := maxf(root.global_transform.basis.get_scale().y, 0.01)
	var target_legs_y := (-0.024 - min_clr) / root_sy
	# 立即还原起跳帧状态
	root.global_position = saved_root_pos
	legs.position = orig_legs_pos
	legs.rotation = orig_legs_rot
	for jt in joint_targets:
		(jt[0] as Node3D).rotation = jt[1]

	var ctw := root.create_tween()
	DA.power_down_wreck(legs, ctw, 0.65, 0.66)
	var collapse_dur := 0.56 if leg_type != "tread" else 0.36
	ctw.tween_interval(0.08)
	ctw.tween_method(func(u: float):
		if not is_instance_valid(legs):
			return
		# 重力加速砸地 + 末段微量阻尼回弹沉实
		var k: float
		if u < 0.82:
			var s := u / 0.82
			k = s * s
		else:
			var b := (u - 0.82) / 0.18
			k = 1.0 - sin(b * PI) * 0.045
		legs.position = orig_legs_pos.lerp(Vector3(orig_legs_pos.x, target_legs_y, orig_legs_pos.z), k)
		legs.rotation = orig_legs_rot.lerp(target_legs_rot, clampf(k, 0.0, 1.0))
		for jt in joint_targets:
			var jn := jt[0] as Node3D
			if is_instance_valid(jn):
				var r0: Vector3 = jt[1]
				var r1: Vector3 = jt[2]
				jn.rotation = Vector3(lerp_angle(r0.x, r1.x, k), lerp_angle(r0.y, r1.y, k), lerp_angle(r0.z, r1.z, k)), 0.0, 1.0, collapse_dur)
	ctw.tween_callback(func():
		if is_instance_valid(fx_parent) and is_instance_valid(legs):
			var dp := Vector3(legs.global_position.x, ground_y + 0.18, legs.global_position.z)
			A.burst(fx_parent, dp, {"amount": 12, "life": 0.85, "size": 1.15, "tex": A.dust_tex(), "additive": false,
				"vmin": 1.4, "vmax": 3.4, "spread": 88.0, "dir": Vector3(0, 0.22, 0), "gravity": Vector3(0, 0.2, 0), "damp": 4.5,
				"c0": Color(0.58, 0.54, 0.48, 0.0), "cmid": Color(0.52, 0.48, 0.42, 0.48), "cmid_pos": 0.16,
				"c1": Color(0.44, 0.40, 0.36, 0.0), "grow0": 0.5, "grow1": 1.85}))


static func _solve_2bone_zy(KN: Vector3, AN: Vector3, T: Vector2) -> Vector2:
	var L1 := Vector2(KN.z, KN.y).length()
	var L2 := Vector2(AN.z - KN.z, AN.y - KN.y).length()
	var d := clampf(T.length(), absf(L1 - L2) + 0.015, L1 + L2 - 0.006)
	var th := atan2(T.y, T.x)
	var alpha := acos(clampf((L1 * L1 + d * d - L2 * L2) / maxf(2.0 * L1 * d, 0.0001), -1.0, 1.0))
	var th0 := atan2(AN.y, AN.z)
	var p1_0 := atan2(KN.y, KN.z)
	var sgn := 1.0 if wrapf(p1_0 - th0, -PI, PI) > 0.0 else -1.0
	var p1 := th + sgn * alpha
	var kp := Vector2(cos(p1), sin(p1)) * L1
	var p2 := atan2(T.y - kp.y, T.x - kp.x)
	var p2_0 := atan2(AN.y - KN.y, AN.z - KN.z)
	var r_hip := p1_0 - p1
	var r_knee := p2_0 - p2 - r_hip
	return Vector2(r_hip, r_knee)
