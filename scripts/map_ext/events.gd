extends Node
## 局内动态事件：补给空投、求救信号、坠落货柜。三者都是限时争夺目标，不是定时虫潮，
## 落点的动静只通过 raid.alert_noise 惊动附近已经存在的虫群，不额外生成敌人。
## 另外负责两件与地图内容绑定的解锁：档案物件拾取后解锁图鉴，中继塔终端打开后放出铅封军械箱。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")

var raid
var _t := 0.0
var _next := 0.0
var _count := 0
var _kind_i := 0
var _falling: Array = []   ## {node, y, vy, kind, pos, chute}
var _unlocks: Array = []
var _done := {}


func setup(r) -> void:
	raid = r
	_next = raid.rng.randf_range(70.0, 100.0)
	_unlocks = raid.get_meta("poi_unlocks", [])
	Events.item_picked.connect(_on_item_picked)
	Events.box_opened.connect(_on_box_opened)


func _process(delta: float) -> void:
	if raid == null or not is_instance_valid(raid) or raid.ended or raid.dropping:
		return
	_t += delta
	for i in range(_falling.size() - 1, -1, -1):
		var f: Dictionary = _falling[i]
		f.y -= float(f.vy) * delta
		if f.node and is_instance_valid(f.node):
			f.node.position = Vector3(f.pos.x, f.y, f.pos.z)
		if f.y <= 0.0:
			_land(f)
			_falling.remove_at(i)
	if _count < 3 and _t >= _next:
		_count += 1
		_next = _t + raid.rng.randf_range(72.0, 108.0)
		_launch(_kind_i % 3)
		_kind_i += 1


## 按顺序轮换三种事件，避免同一局连续两次都是空投
func _launch(kind: int) -> void:
	var p := _pick_spot()
	if p.x == INF or p.z == INF:
		return
	match kind:
		0: _supply_drop(p)
		1: _distress(p)
		_: _cargo_crash(p)


func _pick_spot() -> Vector3:
	var base: Vector3 = raid.mech.global_position
	for i in 36:
		var a = raid.rng.randf() * TAU
		var d = raid.rng.randf_range(24.0, 58.0)
		var p := base + Vector3(cos(a) * d, 0, sin(a) * d)
		if absf(p.x) > 168.0 or absf(p.z) > 168.0:
			continue
		if raid.in_wet(Vector2(p.x, p.z), 2.0):
			continue
		if raid._blocked(p, 2.8, true):
			continue
		return p
	return Vector3(INF, 0, INF)


# ---------- 补给空投 ----------
## 运输机从头顶掠过时抛下的补给舱：减速伞 + 舱体 + 落地扬尘，落地后成为补给箱
func _supply_drop(p: Vector3) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = Vector3(p.x, 60.0, p.z)
	var chute := Node3D.new()
	n.add_child(chute)
	chute.position = Vector3(0, 6.0, 0)
	chute.rotation_degrees = Vector3(14, raid.rng.randf() * 360, -9)
	A.add(chute, A.sphere(3.4, -1, 20), A.paint(Color(0.62, 0.6, 0.5), 0.0, 0.9, {"wear": 0.4, "dust": 0.6, "panel_scale": 0.0}), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
	for i in 6:
		var a := TAU * i / 6.0
		A.add(chute, A.cyl(0.02, 4.6, 0.02, 4), A.metal(Color(0.5, 0.48, 0.42)), Vector3(cos(a) * 2.4, -2.4, sin(a) * 2.4), Vector3(sin(a) * 26.0, 0, -cos(a) * 26.0))
	var pod := A.add(n, A.bevel_box(Vector3(2.2, 2.4, 2.2), 0.12, 0.92), A.paint(Color(0.4, 0.42, 0.34), 0.3, 0.6, {"wear": 0.6, "rust": 0.5, "dust": 0.5}), Vector3(0, 1.6, 0))
	A.add(pod, A.bevel_box(Vector3(2.24, 0.3, 1.6), 0.02), A.hazard(), Vector3(0, -0.4, 0))
	A.add(pod, A.bevel_box(Vector3(0.6, 0.1, 0.1), 0.01), A.emit(Color(1.0, 0.35, 0.12), 2.0), Vector3(0, 1.3, -1.14), Vector3.ZERO, Vector3.ONE, false)
	for i in 4:
		A.add(pod, A.bevel_box(Vector3(0.06, 2.4, 0.06), 0.01), A.metal(Color(0.28, 0.28, 0.27)), Vector3(-1.2 + i * 0.8, 0, 1.15))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.4, 0.15)
	glow.light_energy = 2.4
	glow.omni_range = 14.0
	glow.position = Vector3(0, 2.0, 0)
	n.add_child(glow)
	_falling.append({"node": n, "y": 60.0, "vy": 7.5, "kind": "supply", "pos": p})
	Audio.play_sfx("transport_arrive", p)


# ---------- 求救信号 ----------
## 一段反复播放的求救电波：地面竖起的应急信标 + 被惊动的虫群，信标旁边留一只军用箱
func _distress(p: Vector3) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	A.add(n, A.bevel_box(Vector3(0.9, 0.24, 0.9), 0.04), A.paint(Color(0.3, 0.3, 0.28), 0.5, 0.5), Vector3(0, 0.12, 0))
	A.add(n, A.cyl(0.07, 3.2, 0.07, 6), A.metal(Color(0.42, 0.42, 0.4)), Vector3(0, 1.7, 0))
	A.add(n, A.bevel_box(Vector3(0.6, 0.5, 0.4), 0.04), A.paint(Color(0.32, 0.34, 0.3), 0.4, 0.6, {"rust": 0.6}), Vector3(0, 3.3, 0))
	A.add(n, A.sphere(0.18, -1, 10), A.emit(Color(1.0, 0.18, 0.12), 3.0), Vector3(0, 3.66, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.cyl(0.03, 1.6, 0.03, 4), A.metal(Color(0.4, 0.4, 0.38)), Vector3(0.3, 4.2, 0), Vector3(0, 0, -18))
	A.emitter(raid.world, p + Vector3(0, 3.6, 0), {"amount": 10, "life": 4.0, "size": 1.6, "tex": A.smoke_tex(), "additive": false, "spread": 20.0,
		"vmin": 0.6, "vmax": 1.2, "gravity": Vector3(0.2, 0.8, 0.1), "c0": Color(0.35, 0.3, 0.28, 0.4), "c1": Color(0.4, 0.38, 0.36, 0.0), "grow0": 0.5, "grow1": 2.4})
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.2, 0.12)
	l.light_energy = 2.2
	l.omni_range = 12.0
	l.position = Vector3(0, 3.6, 0)
	n.add_child(l)
	raid._add_flicker(l)
	K.crate(raid, p + Vector3(2.4, 0, 0.8), "military", ["repair_kit", "fuel_cell", "credit_s"])
	raid.alert_noise(p, 30.0)
	Audio.play_sfx("ui_open", p)
	Events.emit_custom("distress_signal", {"pos": [p.x, p.y, p.z], "map": raid.map_id})


# ---------- 坠落货柜 ----------
## 从高空掉下来的货运柜：拖着火星砸进地面，落地后柜体裂开，里面是军用物资
func _cargo_crash(p: Vector3) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = Vector3(p.x, 70.0, p.z)
	var M := A.paint(Color(0.32, 0.34, 0.3), 0.4, 0.6, {"wear": 0.7, "rust": 0.7, "dust": 0.5, "panel_scale": 1.2})
	var body := A.add(n, A.bevel_box(Vector3(2.4, 2.4, 6.0), 0.1), M, Vector3.ZERO)
	for i in 7:
		A.add(body, A.bevel_box(Vector3(2.44, 2.2, 0.12), 0.03), A.paint(Color(0.27, 0.29, 0.26), 0.4, 0.6, {"rust": 0.8}), Vector3(0, 0, -2.6 + i * 0.85))
	A.add(body, A.bevel_box(Vector3(2.5, 0.28, 6.04), 0.04), A.hazard(), Vector3(0, -1.0, 0))
	A.emitter(n, Vector3(0, 1.2, 0), {"amount": 24, "life": 0.7, "size": 0.7, "vmin": 1.0, "vmax": 2.6, "gravity": Vector3(0, 2.0, 0), "radius": 0.4,
		"c0": Color(1.0, 0.75, 0.3), "cmid": Color(1.0, 0.35, 0.08), "c1": Color(0.4, 0.05, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
	_falling.append({"node": n, "y": 70.0, "vy": 24.0, "kind": "cargo", "pos": p})
	Audio.play_sfx("drop_fall", p)


func _land(f: Dictionary) -> void:
	var p: Vector3 = f.pos
	var n = f.node
	if n and is_instance_valid(n):
		n.queue_free()
	match str(f.kind):
		"supply":
			raid.explode_fx(p, 6.0, Color(0.85, 0.72, 0.5))
			raid.shake = max(raid.shake, 0.35)
			var b = K.crate(raid, p, "supply", GameData.roll_loot("supply", raid.rng) + ["fuel_cell"])
			raid.alert_noise(p, 24.0)
			Events.emit_custom("supply_drop", {"pos": [p.x, p.y, p.z], "items": b.items.duplicate(), "map": raid.map_id})
		"cargo":
			raid.explode_fx(p, 9.0, Color(1.0, 0.55, 0.2))
			raid.shake = max(raid.shake, 0.7)
			raid.alert_noise(p, 46.0)
			var b2 = K.crate(raid, p + Vector3(1.6, 0, 2.2), "military", GameData.roll_loot("military", raid.rng) + ["bug_crystal"])
			K.crate(raid, p + Vector3(-2.0, 0, 1.4), "supply")
			Events.emit_custom("cargo_crash", {"pos": [p.x, p.y, p.z], "items": b2.items.duplicate(), "map": raid.map_id})
		_:
			raid.explode_fx(p, 3.0, Color(0.8, 0.7, 0.5))


# ---------- 解锁：档案图鉴 ----------
## 档案物件在 ITEMS 里带 codex 字段，拾取即解锁同名图鉴条目
func _on_item_picked(item_id: String, _rarity: int) -> void:
	var it: Dictionary = GameData.item(item_id)
	var cid := str(it.get("codex", ""))
	if cid == "":
		return
	if Story and Story.has_method("unlock_codex"):
		Story.unlock_codex(cid)


# ---------- 解锁：中继塔铅封军械箱 ----------
## POI 建造时把终端位置与铅封箱写进 raid 的 meta；终端被打开的瞬间把铅封箱换成真容器
func _on_box_opened(kind: String, pos: Vector3) -> void:
	if pos == Vector3.ZERO:
		return
	for u: Dictionary in _unlocks:
		if bool(u.get("done", false)):
			continue
		var term: Vector3 = u.get("terminal", Vector3.ZERO)
		if pos.distance_to(term) > 3.4:
			continue
		u["done"] = true
		for c in u.get("caches", []):
			var node = c.get("node")
			if node and is_instance_valid(node):
				node.queue_free()
			var cp: Vector3 = c.get("pos", Vector3.ZERO)
			K.crate(raid, cp, "military")
		Audio.play_sfx("loot_open_military", pos)
		Events.emit_custom("poi_cache_unlocked", {"pos": [pos.x, pos.y, pos.z], "kind": kind, "map": raid.map_id})
