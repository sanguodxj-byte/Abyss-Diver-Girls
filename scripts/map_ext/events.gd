extends Node
## 局内动态事件：补给空投、求救信号、坠落货柜。三者都是限时争夺目标，不是定时虫潮，
## 落点的动静只通过 raid.alert_noise 惊动附近已经存在的虫群，不额外生成敌人。
## 另外负责两件与地图内容绑定的解锁：档案物件拾取后解锁图鉴，中继塔终端打开后放出铅封军械箱。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/map_ext/poi_kit.gd")
const FM = preload("res://scripts/modules/field_models.gd")

var raid
var _t := 0.0
var _next := 0.0
var _count := 0
var _kind_i := 0
var _falling: Array = []   ## {node, y, vy, kind, pos, chute}
var _unlocks: Array = []
var _done := {}
var _erng := RandomNumberGenerator.new()
var _used_sites: Array = []


func setup(r) -> void:
	raid = r
	_erng.seed = r._map_seed(30)
	_next = 80.0
	_used_sites.clear()
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
		_next = _t + 90.0
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


func _valid_event_spot(p: Vector3) -> bool:
	if not raid.in_bounds(p, 10.0):
		return false
	if raid.in_wet(Vector2(p.x, p.z), 2.5):
		return false
	if raid._blocked(p, 2.8, true):
		return false
	if raid.nav != null and not raid.nav.is_reachable(p, true, 0.0):
		return false
	for u: Vector3 in _used_sites:
		if Vector2(u.x - p.x, u.z - p.z).length() < 18.0:
			return false
	return true


## 优先选择地图上固定的开阔广场/地标前坪/路口落点，不再用随机极坐标乱扔；若附近无预设点则按固定方位环择优
func _pick_spot() -> Vector3:
	var base: Vector3 = raid.mech.global_position
	var cands: Array = []
	for e: Array in raid.MAP.get("labels", []):
		cands.append(Vector3(float(e[1]), 0.0, float(e[2])))
	for ex: Array in raid.MAP.get("extracts", []):
		cands.append(Vector3(float(ex[1]), 0.0, float(ex[2])))
	for m: Dictionary in raid.get_meta("ext_landmarks", []):
		cands.append(Vector3(float(m.get("x", 0.0)), 0.0, float(m.get("z", 0.0))))
	var best := Vector3(INF, 0, INF)
	var best_d := INF
	for c: Vector3 in cands:
		var d := Vector2(c.x - base.x, c.z - base.z).length()
		if d < 22.0 or d > 82.0 or d >= best_d:
			continue
		if _valid_event_spot(c):
			best_d = d
			best = c
	if best.x != INF:
		_used_sites.append(best)
		return best
	# 确定性八方位同心环（固定角度与半径顺序，无随机漂移）
	for dist: float in [34.0, 48.0, 26.0, 58.0]:
		for k in 12:
			var a := TAU * float(k) / 12.0
			var p := base + Vector3(cos(a) * dist, 0.0, sin(a) * dist)
			if _valid_event_spot(p):
				_used_sites.append(p)
				return p
	return Vector3(INF, 0, INF)


# ---------- 补给空投 ----------
## 运输机从头顶掠过时抛下的装甲补给空投舱：多幅开缝减速伞 + 八棱缓冲空投舱 + 四角液压着陆脚，落地后成为补给箱
func _supply_drop(p: Vector3) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = Vector3(p.x, 60.0, p.z)
	var pod := Node3D.new()
	n.add_child(pod)
	pod.position = Vector3(0, 1.55, 0)
	var M_POD := A.paint(Color(0.38, 0.41, 0.34), 0.38, 0.58, {"wear": 0.6, "rust": 0.48, "dust": 0.45})
	var pod_info := FM.build_supply_pod(pod, M_POD)
	var chute := Node3D.new()
	n.add_child(chute)
	chute.position = pod.position + (pod_info.top as Vector3) + Vector3(0, 0.9, 0)
	chute.rotation_degrees = Vector3(10, 24.0, -7)
	FM.build_parachute(chute)
	A.add(pod, A.bevel_box(Vector3(0.56, 0.08, 0.05), 0.01), A.emit(Color(1.0, 0.35, 0.12), 2.2), Vector3(0, 0.95, -1.0), Vector3.ZERO, Vector3.ONE, false)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.4, 0.15)
	glow.light_energy = 2.4
	glow.omni_range = 14.0
	glow.position = Vector3(0, 2.0, 0)
	n.add_child(glow)
	_falling.append({"node": n, "y": 60.0, "vy": 7.5, "kind": "supply", "pos": p})
	Audio.play_sfx("transport_arrive", p)


# ---------- 求救信号 ----------
## 一段反复播放的求救电波：三脚架军用应急战术信标台 + 太阳能翼板 + 护笼频闪红灯，旁边留一只军用箱
func _distress(p: Vector3) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = p
	var M_CASE := A.paint(Color(0.30, 0.34, 0.28), 0.42, 0.58, {"rust": 0.55, "wear": 0.55})
	FM.build_distress_beacon(n, M_CASE, Color(1.0, 0.18, 0.12))
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
## 从高空掉下来的轨道装甲货运柜：四角ISO吊装角件 + 加强外肋 + 逆喷制动环，拖着火星砸进地面
func _cargo_crash(p: Vector3) -> void:
	var n := Node3D.new()
	raid.world.add_child(n)
	n.position = Vector3(p.x, 70.0, p.z)
	var M := A.paint(Color(0.32, 0.34, 0.3), 0.45, 0.58, {"wear": 0.72, "rust": 0.7, "dust": 0.5, "panel_scale": 1.2})
	var M_RIB := A.paint(Color(0.24, 0.26, 0.24), 0.5, 0.58, {"rust": 0.8})
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	var body := Node3D.new()
	n.add_child(body)
	body.rotation_degrees = Vector3(18, 24, -12)
	A.add(body, A.bevel_box(Vector3(2.4, 2.4, 6.0), 0.1), M, Vector3.ZERO)
	for i in 7:
		A.add(body, A.bevel_box(Vector3(2.50, 2.46, 0.14), 0.03), M_RIB, Vector3(0, 0, -2.55 + i * 0.85))
	for sx in [-1.18, 1.18]:
		for sy in [-1.18, 1.18]:
			for sz in [-2.96, 2.96]:
				A.add(body, A.bevel_box(Vector3(0.26, 0.26, 0.28), 0.02), M_DARK, Vector3(sx, sy, sz))
	A.add(body, A.bevel_box(Vector3(2.52, 0.28, 6.04), 0.03), A.hazard(), Vector3(0, -0.95, 0))
	for rx_c in [-0.75, 0.75]:
		A.add(body, A.cyl(0.34, 0.45, 0.42, 12), M_DARK, Vector3(rx_c, 0.75, 3.12), Vector3(90, 0, 0))
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
			var b = K.crate(raid, p, "supply", GameData.roll_loot("supply", _erng) + ["fuel_cell"], 0.0)
			raid.alert_noise(p, 24.0)
			Events.emit_custom("supply_drop", {"pos": [p.x, p.y, p.z], "items": b.items.duplicate(), "map": raid.map_id})
		"cargo":
			raid.explode_fx(p, 9.0, Color(1.0, 0.55, 0.2))
			raid.shake = max(raid.shake, 0.7)
			raid.alert_noise(p, 46.0)
			_spawn_cargo_wreck(p)
			var b2 = K.crate(raid, p + Vector3(2.8, 0, 2.4), "military", GameData.roll_loot("military", _erng) + ["bug_crystal"], 90.0)
			K.crate(raid, p + Vector3(-2.8, 0, 1.8), "supply", [], -90.0)
			Events.emit_custom("cargo_crash", {"pos": [p.x, p.y, p.z], "items": b2.items.duplicate(), "map": raid.map_id})
		_:
			raid.explode_fx(p, 3.0, Color(0.8, 0.7, 0.5))


func _spawn_cargo_wreck(p: Vector3) -> void:
	var w := Node3D.new()
	raid.world.add_child(w)
	w.position = p
	var yaw: float = 16.0
	w.rotation_degrees.y = yaw
	A.ground_vfx(w, A.cloud_tex(), Color(0.06, 0.05, 0.04, 0.78), 8.5, Vector3(0, 0.038, 0))
	var M := A.paint(Color(0.28, 0.30, 0.26), 0.48, 0.62, {"wear": 0.75, "rust": 0.78, "grime": 0.85, "panel_scale": 1.2})
	var M_RIB := A.paint(Color(0.20, 0.22, 0.20), 0.52, 0.60, {"rust": 0.85, "grime": 0.8})
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	var body := Node3D.new()
	w.add_child(body)
	body.position = Vector3(0, 0.92, 0)
	body.rotation_degrees = Vector3(11, 0, -8)
	A.add(body, A.bevel_box(Vector3(2.35, 2.25, 5.6), 0.10), M, Vector3.ZERO)
	for i in 6:
		A.add(body, A.bevel_box(Vector3(2.46, 2.32, 0.14), 0.03), M_RIB, Vector3(0, 0, -2.25 + i * 0.90))
	for sx in [-1.14, 1.14]:
		for sy in [-1.08, 1.08]:
			for sz in [-2.76, 2.76]:
				A.add(body, A.bevel_box(Vector3(0.26, 0.26, 0.28), 0.02), M_DARK, Vector3(sx, sy, sz))
	A.add(body, A.bevel_box(Vector3(2.42, 0.26, 5.64), 0.03), A.hazard(), Vector3(0, 0.62, 0))
	for rx_c in [-0.72, 0.72]:
		A.add(body, A.cyl(0.32, 0.44, 0.40, 12), M_DARK, Vector3(rx_c, 0.65, 2.92), Vector3(90, 0, 0))
	for dk in 4:
		var da := TAU * float(dk) / 4.0 + 0.4
		A.add(w, A.rock_mesh((dk * 3 + 1) % 12), A.rock_mat(Color(0.26, 0.22, 0.18)),
			Vector3(cos(da) * 1.9, 0.18, sin(da) * 2.8), Vector3(0, dk * 62.0, 0), Vector3(0.95, 0.36, 0.82))
	A.emitter(w, Vector3(0.2, 1.8, -0.4), {"amount": 12, "life": 4.2, "size": 2.0, "tex": A.smoke_tex(), "additive": false,
		"vmin": 0.6, "vmax": 1.3, "gravity": Vector3(0.4, 0.7, 0.2), "radius": 0.5,
		"c0": Color(0.12, 0.10, 0.10, 0.55), "c1": Color(0.26, 0.24, 0.24, 0.0), "grow0": 0.5, "grow1": 2.6})
	K.blocker(raid, p, Vector3(2.5, 2.2, 5.6), yaw)


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
