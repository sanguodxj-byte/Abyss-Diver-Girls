extends Node
## 战区互通：相邻战区之间在地图边缘开「转场口」，机甲在转场口里停留 HOLD 秒即穿过边界，进入相邻战区的对应边。
##
## 邻接关系见 LINKS（世界大致布局：赤湖在灰港北面，铁锈工业带在灰港东面，尘土平原在灰港南面，裂谷矿区在工业带南面 / 平原东面；
## 零号深渊井是竖井，不与地表相连）。目标战区还没解锁（GameData.map_available 为 false）时转场口显示为灰色封锁，不能通过。
##
## 转场保留：机甲结构 / 能源 / 部件完好度 / 弹药与弹匣 / 技能冷却、货舱货物、出击时带的货物（结算用）、局内时间、击杀数、
## 已遇见的敌人种类、随行的战斗队友（含剩余结构）。新战区重新生成虫群、容器与撤离点；撤离仍然要去撤离点。
## 过渡：0.55 秒淡出 → 生成新战区 → 0.8 秒淡入，屏幕中央提示「进入战区」。

const LINKS := {
	"greyport": {"N": "redlake", "E": "ironbelt", "S": "dustfield"},
	"ironbelt": {"W": "greyport", "S": "canyon", "N": "bayport"},
	"redlake": {"S": "greyport", "E": "bayport"},
	"bayport": {"W": "redlake", "S": "ironbelt"},
	"dustfield": {"N": "greyport", "E": "canyon"},
	"canyon": {"N": "ironbelt", "W": "dustfield"},
}
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}
const HALF_SPAN := 16.0     ## 转场口半宽（米）
const DEPTH := 9.0          ## 离边界多近算进入转场口
const HOLD := 1.2           ## 停留多久触发转场
const GATE_COLOR := Color(0.35, 0.85, 1.0)

const A = preload("res://scripts/art.gd")
const WC = preload("res://scripts/world_city.gd")
const LoadingScreenScript = preload("res://scripts/loading_screen.gd")

static var force_open := false   ## 测试用：忽略战区解锁条件

var raid
var gates := {}            ## edge -> {to, name, center: Vector3, along: float, open: bool, node, label}
var shaft := {}            ## 隐藏深井入口（canyon -> abyss_maw），不写入 LINKS / gates
var busy := false
var _hold := 0.0
var _cool := 2.0
var _in_gate := ""
var _in_shaft := false


func setup(r) -> void:
	raid = r
	var links: Dictionary = LINKS.get(raid.map_id, {})
	for edge: String in links:
		var to: String = links[edge]
		if not GameData.MAPS.has(to):
			continue
		var info := WC.gate_info(raid.map_id, edge)
		var open := true
		var g := {
			"edge": edge, "to": to, "name": str(GameData.map_data(to).get("name", to)),
			"along": float(info.along), "pos": info.pos as Vector2,
			"inward": info.inward as Vector2, "tangent": info.tangent as Vector2,
			"center": Vector3(info.pos.x, 0.0, info.pos.y), "open": open,
		}
		gates[edge] = g
		_build_gate(g)
	_setup_hidden_shaft()


func gate_list() -> Array:
	return gates.values()


func _gate_point(g: Dictionary, lateral: float, inset: float) -> Vector3:
	var p: Vector2 = (g.pos as Vector2) + (g.tangent as Vector2) * lateral + (g.inward as Vector2) * inset
	return Vector3(p.x, 0.0, p.y)


## 边界上 along 处、向内 inset 米的点（兼容旧接口与不规则分界线）
func _edge_point(edge: String, along: float, inset: float) -> Vector3:
	if gates.has(edge):
		var g: Dictionary = gates[edge]
		return _gate_point(g, along - float(g.along), inset)
	var to: String = LINKS.get(raid.map_id, {}).get(edge, "")
	var info := WC.border_at(raid.map_id, to, along)
	var p: Vector2 = (info.pos as Vector2) + (info.inward as Vector2) * inset
	return Vector3(p.x, 0.0, p.y)


func _gate_inward(edge: String) -> Vector3:
	if gates.has(edge):
		var inw2: Vector2 = gates[edge].inward
		return Vector3(inw2.x, 0.0, inw2.y)
	return _inward(edge)


static func _inward(edge: String) -> Vector3:
	match edge:
		"N": return Vector3(0, 0, 1)
		"S": return Vector3(0, 0, -1)
		"W": return Vector3(1, 0, 0)
		_: return Vector3(-1, 0, 0)


## 转场口位置：由城市群布局统一决定（scripts/world_city.gd gate_along），相邻两个战区共用同一处、每局一致：
## 沿边每 8 米试一处，边两侧向内 6~30 米都得是空地（不是水、悬崖、建筑、遗迹院落）；道路跨过边界的地方优先，其次靠近边的中段。
## 地图生成时（raid._build_map）转场口通道里不摆杂物。
func _pick_along(edge: String) -> float:
	return WC.gate_along(raid.map_id, edge)


# ---------------------------------------------------------------- 外观
static var _curtain_shader: Shader

func _curtain_mat(c: Color) -> ShaderMaterial:
	if _curtain_shader == null:
		_curtain_shader = Shader.new()
		_curtain_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(0.35, 0.85, 1.0, 1.0);
void fragment() {
	float rise = pow(UV.y, 1.6);
	float stripes = 0.55 + 0.45 * sin(UV.x * 70.0 - TIME * 5.0);
	float scan = 0.6 + 0.4 * sin(UV.y * 24.0 + TIME * 7.0);
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	ALBEDO = col.rgb * rise * edge * (0.25 + 0.75 * stripes * scan) * col.a;
}"""
	var m := ShaderMaterial.new()
	m.shader = _curtain_shader
	m.set_shader_parameter("col", c)
	return m


func _build_gate(g: Dictionary) -> void:
	var c: Color = GATE_COLOR if g.open else Color(0.55, 0.55, 0.6)
	var n := Node3D.new()
	n.name = "Gate_" + str(g.edge)
	raid.world.add_child(n)
	var inw := _gate_inward(g.edge)
	n.global_position = _gate_point(g, 0.0, 2.5)
	n.rotation.y = atan2(inw.x, inw.z)   # 本地 +z 朝地图内侧，本地 x 沿边界
	var M_CON := A.concrete(Color(0.46, 0.44, 0.41), false)
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	var M_ST := A.paint(Color(0.26, 0.28, 0.30), 0.58, 0.54, {"wear": 0.52, "rust": 0.48})
	var M_BRASS := A.paint(Color(0.58, 0.44, 0.22), 0.78, 0.36, {"wear": 0.4})
	var m_glow := A.emit(c, 3.2 if g.open else 0.9)
	m_glow.albedo_color = c.darkened(0.45)
	# 界门两侧立柱低对比度边界雾汽粒子（取代大面积平滑矩形光幕）
	for sx_fog in [-HALF_SPAN + 1.2, HALF_SPAN - 1.2]:
		A.emitter(n, Vector3(sx_fog, 1.8, 0.0), {"tex": A.smoke_tex(), "additive": false, "soft_depth": 0.45, "amount": 10, "life": 2.4, "size": 1.65,
			"dir": Vector3(-signf(sx_fog), 0.35, 0.0).normalized(), "spread": 25.0, "vmin": 0.6, "vmax": 1.4, "gravity": Vector3(0, 0.15, 0),
			"c0": Color(c.r * 0.55 + 0.2, c.g * 0.55 + 0.2, c.b * 0.55 + 0.2, 0.20 if g.open else 0.12),
			"c1": Color(c.r * 0.4 + 0.15, c.g * 0.4 + 0.15, c.b * 0.4 + 0.15, 0.0), "grow0": 0.6, "grow1": 2.2, "box": Vector3(0.4, 1.6, 0.3)})
	# 两侧重工战区封锁龙门塔柱：阶梯钢筋混凝土防撞墩 + 双工字钢主立柱 + 内侧力场发射线圈阵 + 侧翼泽西护栏
	for sx_s in [-1.0, 1.0]:
		var sx: float = sx_s * HALF_SPAN
		A.add(n, A.bevel_box(Vector3(2.40, 0.48, 2.80), 0.06), M_CON, Vector3(sx, 0.24, 0))
		A.add(n, A.bevel_box(Vector3(1.85, 1.45, 2.20), 0.08, 0.86), M_CON, Vector3(sx, 1.15, 0))
		A.add(n, A.bevel_box(Vector3(1.92, 0.22, 2.26), 0.02), A.hazard(), Vector3(sx, 0.62, 0))
		for pz in [-0.62, 0.62]:
			A.add(n, A.bevel_box(Vector3(0.42, 7.60, 0.44), 0.03), M_ST, Vector3(sx, 5.45, pz))
		for by in [2.6, 4.6, 6.6, 8.4]:
			A.add(n, A.bevel_box(Vector3(0.52, 0.24, 1.68), 0.02), M_DARK, Vector3(sx, by, 0))
		# 面向通道内侧的装甲力场发生器环组
		var ix: float = sx - sx_s * 0.52
		for cy in [2.4, 4.2, 6.0]:
			A.add(n, A.bevel_box(Vector3(0.46, 0.56, 0.72), 0.03), M_DARK, Vector3(ix, cy, 0))
			A.add(n, A.bevel_box(Vector3(0.18, 0.38, 0.54), 0.02), M_BRASS, Vector3(ix - sx_s * 0.22, cy, 0))
			A.add(n, A.bevel_box(Vector3(0.08, 0.26, 0.40), 0.01), m_glow, Vector3(ix - sx_s * 0.30, cy, 0), Vector3.ZERO, Vector3.ONE, false)
		# 塔顶装甲信标灯笼 + 内倾道路防撞泽西护栏
		A.add(n, A.bevel_box(Vector3(1.15, 0.36, 1.15), 0.04), M_DARK, Vector3(sx, 9.38, 0))
		A.add(n, A.cyl(0.32, 0.52, 0.32, 12), m_glow, Vector3(sx, 9.78, 0), Vector3.ZERO, Vector3.ONE, false)
		A.add(n, A.cyl(0.42, 0.10, 0.38, 12), M_DARK, Vector3(sx, 10.08, 0))
		A.add(n, A.bevel_box(Vector3(2.40, 0.95, 0.68), 0.06, 0.76), M_CON, Vector3(sx + sx_s * 2.15, 0.48, 1.85), Vector3(0, sx_s * -18.0, 0))
	# 高空横跨钢结构龙门桁架梁（净空 8.3m，4 跨分段确保单件远小于合批分块上限）
	var seg_n := 4
	var span_w := HALF_SPAN * 2.0
	var bw := span_w / float(seg_n)
	for bi in seg_n:
		var bx := -HALF_SPAN + (float(bi) + 0.5) * bw
		A.add(n, A.bevel_box(Vector3(bw - 0.03, 0.24, 0.62), 0.02), M_DARK, Vector3(bx, 8.02, 0))
		for ty in [8.35, 9.15]:
			A.add(n, A.bevel_box(Vector3(bw - 0.03, 0.22, 1.38), 0.02), M_ST, Vector3(bx, ty, 0))
		for sd_z in [-0.58, 0.58]:
			A.add(n, A.bevel_box(Vector3(0.16, 0.80, 0.16), 0.01), M_DARK, Vector3(bx - bw * 0.5, 8.75, sd_z), Vector3.ZERO, Vector3.ONE, false)
			A.add(n, A.bevel_box(Vector3(bw * 0.52, 0.10, 0.10), 0.01), M_DARK, Vector3(bx - bw * 0.25, 8.75, sd_z), Vector3(0, 0, 18), Vector3.ONE, false)
			A.add(n, A.bevel_box(Vector3(bw * 0.52, 0.10, 0.10), 0.01), M_DARK, Vector3(bx + bw * 0.25, 8.75, sd_z), Vector3(0, 0, -18), Vector3.ONE, false)
	A.add(n, A.bevel_box(Vector3(6.4, 0.62, 0.22), 0.03), M_DARK, Vector3(0, 8.75, 0.76))
	A.add(n, A.bevel_box(Vector3(6.2, 0.16, 0.24), 0.01), A.hazard(), Vector3(0, 8.38, 0.77))
	for fx_l in [-4.5, 4.5]:
		A.add(n, A.bevel_box(Vector3(0.68, 0.30, 0.42), 0.02), M_DARK, Vector3(fx_l, 8.16, 0.72), Vector3(22, 0, 0))
		A.add(n, A.bevel_box(Vector3(0.54, 0.18, 0.06), 0.01), m_glow, Vector3(fx_l, 8.12, 0.92), Vector3(22, 0, 0), Vector3.ONE, false)
	# 地面装甲导引减速带与三道做旧铁灰减速钢板（两端仅留小型嵌入式指示灯钉，取代大面积发光灯条）
	var m_plate := A.paint(Color(0.22, 0.23, 0.25), 0.52, 0.62, {"wear": 0.65, "rust": 0.45})
	var am := A.emit(c.darkened(0.2), 1.1 if g.open else 0.4)
	am.albedo_color = c.darkened(0.45)
	for k in 3:
		var z := 6.0 + k * 4.5
		for s in [-1.0, 1.0]:
			var dy_s := 0.004 if s > 0.0 else 0.0
			A.add(n, A.bevel_box(Vector3(3.56, 0.05, 0.72), 0.02), M_DARK, Vector3(s * 1.42, 0.115 + dy_s, z - 1.2), Vector3(0, s * 45.0, 0), Vector3.ONE, false)
			var plate := A.add(n, A.bevel_box(Vector3(3.32, 0.070, 0.42), 0.02), m_plate, Vector3(s * 1.42, 0.152 + dy_s, z - 1.2), Vector3(0, s * 45.0, 0), Vector3.ONE, false)
			plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var stud := A.add(n, A.bevel_box(Vector3(0.34, 0.065, 0.16), 0.01), am, Vector3(s * 2.48, 0.162 + dy_s, z - 2.26), Vector3(0, s * 45.0, 0), Vector3.ONE, false)
			stud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 地面边框角标
	A.add(n, A.quad(HALF_SPAN * 1.4, HALF_SPAN * 1.4), A.extract_pad_mat(Color(c.r, c.g, c.b, 0.24), 0.44, 3), Vector3(0, 0.112, 6.0), Vector3.ZERO, Vector3.ONE, false)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 1.4
	l.omni_range = 16.0
	l.position = Vector3(0, 3.0, 4.0)
	n.add_child(l)
	# 边界转场口不再悬挂 3D 漂浮文字，由顶部区域横幅与进入边界时的 HUD 提示承担
	g["node"] = n
	g["label"] = null


## 在地形图（小地图 / 大地图共用）上画出转场口：沿不规则边界段的亮色粗线 + 指向分界外的引导三角
func paint_map(tex: ImageTexture) -> void:
	if tex == null or gates.is_empty():
		return
	var img := tex.get_image()
	var k: float = float(img.get_width()) / (raid.HALF * 2.0)
	var clip := Rect2i(3, 3, img.get_width() - 6, img.get_height() - 6)
	for g: Dictionary in gates.values():
		var c: Color = GATE_COLOR if g.open else Color(0.55, 0.55, 0.6)
		var a := _gate_point(g, -HALF_SPAN, 1.5)
		var b := _gate_point(g, HALF_SPAN, 1.5)
		var steps := 64
		for i in steps + 1:
			var p := a.lerp(b, float(i) / steps)
			var px := int((p.x + raid.HALF) * k)
			var pz := int((p.z + raid.HALF) * k)
			img.fill_rect(Rect2i(px - 2, pz - 2, 5, 5).intersection(clip), c)
		var inw2: Vector2 = g.inward
		var tang2: Vector2 = g.tangent
		var base_p: Vector2 = (g.pos as Vector2) + inw2 * 6.0
		for d in 12:
			var half_w := float(11 - d) * 0.75
			var row_c := base_p - inw2 * float(d) * 0.9
			var rsteps := maxi(1, int(half_w * 2.0))
			for si in rsteps + 1:
				var u := lerpf(-half_w, half_w, float(si) / float(rsteps))
				var q := row_c + tang2 * u
				var px := int((q.x + raid.HALF) * k)
				var pz := int((q.y + raid.HALF) * k)
				img.fill_rect(Rect2i(px - 1, pz - 1, 3, 3).intersection(clip), c)
	tex.update(img)


# ---------------------------------------------------------------- 触发
func gate_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	for g: Dictionary in gates.values():
		var rel: Vector2 = q - (g.pos as Vector2)
		var depth: float = rel.dot(g.inward as Vector2)
		var lat: float = rel.dot(g.tangent as Vector2)
		if depth > -4.5 and depth < DEPTH and absf(lat) < HALF_SPAN:
			return g.edge
	return ""


func _process(delta: float) -> void:
	if raid == null or busy or raid.ended or raid.dropping or raid.mech == null or raid.mech.dead:
		return
	if _cool > 0.0:
		_cool -= delta
		return
	var e := gate_at(raid.mech.global_position)
	if e != _in_gate:
		var was_gate := _in_gate != ""
		_in_gate = e
		_hold = 0.0
		if e != "" and raid.hud:
			var g: Dictionary = gates[e]
			raid.hud.msg(Loc.t("穿越边界：保持在光幕内，即将进入「%s」" % g.name, "Border crossing: hold inside barrier to enter [%s]" % g.name) if g.open else Loc.t("「%s」尚未开放，边界封锁" % g.name, "[%s] not yet open, border sealed" % g.name))
		elif was_gate and raid.hud:
			raid.hud.set_prompt("")
	if e != "" and gates[e].open:
		_in_shaft = false
		_hold += delta
		var g: Dictionary = gates[e]
		if raid.hud:
			raid.hud.set_prompt(Loc.t("穿越边界 · 进入「%s」 %.1fs" % [g.name, maxf(HOLD - _hold, 0.0)], "Crossing Border · Entering [%s] %.1fs" % [g.name, maxf(HOLD - _hold, 0.0)]))
		if _hold >= HOLD:
			if raid.hud:
				raid.hud.set_prompt("")
			go(e)
		return
	if not shaft.is_empty():
		var mp2 := Vector2(raid.mech.global_position.x, raid.mech.global_position.z)
		var on_shaft := mp2.distance_to(shaft.pos as Vector2) < 4.6
		if on_shaft != _in_shaft:
			var was_shaft := _in_shaft
			_in_shaft = on_shaft
			_hold = 0.0
			if on_shaft and raid.hud:
				raid.hud.msg(Loc.t("深井升降台已解锁：保持停靠即可潜入「%s」" % shaft.name, "Shaft lift unlocked: stay docked to descend into [%s]" % shaft.name))
			elif was_shaft and raid.hud:
				raid.hud.set_prompt("")
		if on_shaft:
			_hold += delta
			if raid.hud:
				raid.hud.set_prompt(Loc.t("深井升降台 · 潜入「%s」 %.1fs" % [shaft.name, maxf(HOLD - _hold, 0.0)], "Shaft Lift · Descending to [%s] %.1fs" % [shaft.name, maxf(HOLD - _hold, 0.0)]))
			if _hold >= HOLD:
				if raid.hud:
					raid.hud.set_prompt("")
				go_to_map(str(shaft.to), "")


## 穿过 edge 边的转场口
func go(edge: String) -> void:
	if busy or not gates.has(edge):
		return
	var g: Dictionary = gates[edge]
	go_to_map(str(g.to), OPP.get(edge, "S"), Loc.t("穿越战区边界\n%s ➜ %s" % [str(raid.MAP.get("name", raid.map_id)), g.name], "Sector Border Crossing\n%s ➜ %s" % [str(raid.MAP.get("name", raid.map_id)), g.name]))


## 转场到任意目标战区（供边界转场口与隐藏深井升降台共用）
func go_to_map(to_map: String, arrival_edge: String, banner := "") -> void:
	if busy or to_map == "" or not GameData.MAPS.has(to_map):
		return
	busy = true
	var to_name := str(GameData.map_data(to_map).get("name", to_map))
	if banner == "":
		banner = Loc.t("潜入深渊竖井\n%s ➜ %s" % [str(raid.MAP.get("name", raid.map_id)), to_name], "Descending Abyss Shaft\n%s ➜ %s" % [str(raid.MAP.get("name", raid.map_id)), to_name])
	var m = raid.mech
	m.input_locked = true
	if raid.open_box:
		raid.close_box()
	Audio.play_sfx("drop_retro")
	var state := capture_to(to_map, arrival_edge)
	var parent: Node = raid.get_parent()
	var RaidCls = load("res://scripts/raid.gd")
	var nr = RaidCls.new()
	for c in raid.get_signal_connection_list("raid_ended"):
		nr.raid_ended.connect(c.callable)
	var lo_copy: Dictionary = raid.loadout.duplicate()
	var cargo_copy: Array = state.mech.cargo.duplicate()
	var keep_map: String = GameData.map_id
	if GameData.test_mode and not RaidCls.force_async_load:
		var ov := _overlay(0.0, banner)
		var tw := ov.create_tween()
		tw.tween_property(ov.get_child(0), "color:a", 1.0, 0.55)
		await tw.finished
		GameData.map_id = to_map
		parent.add_child(nr)
		if "raid" in parent:
			parent.raid = nr
		nr.start(lo_copy, cargo_copy, state)
		GameData.map_id = keep_map
		Events.deployed.emit(nr.map_id, lo_copy)
		raid.queue_free()
		return
	var loader = LoadingScreenScript.new()
	parent.add_child(loader)
	loader.setup(to_map, lo_copy, state)
	await loader.play_close(0.32)
	raid.queue_free()
	GameData.map_id = to_map
	parent.add_child(nr)
	if "raid" in parent:
		parent.raid = nr
	await nr.start_async(lo_copy, cargo_copy, state, loader)
	GameData.map_id = keep_map
	Events.deployed.emit(nr.map_id, lo_copy)
	await loader.play_open(0.48)


## 转场时要带走的状态
func capture(edge: String) -> Dictionary:
	var to: String = gates[edge].to if gates.has(edge) else ""
	return capture_to(to, OPP.get(edge, "S"))


func capture_to(to: String, arrival_edge: String) -> Dictionary:
	var m = raid.mech
	var visited: Array = raid.visited_maps.duplicate()
	if to != "" and not visited.has(to):
		visited.append(to)
	return {
		"edge": arrival_edge, "from": raid.map_id, "to": to,
		"time": raid.time, "kills": raid.kills, "start_cargo": raid.start_cargo.duplicate(),
		"seen": raid._seen_kinds.duplicate(), "visited": visited, "found_pois": {},
		"mech": {"hp": m.hp, "energy": m.energy, "parts": m.parts.duplicate(), "ammo": m.ammo.duplicate(), "mag": m.mag.duplicate(),
			"cargo": m.cargo.duplicate(), "ability_cd": m.ability_cd,
			"dash_cd": m.dash_cd, "emergency": m.emergency},
		"allies": raid.factions.ally_state() if raid.factions else [],
	}


func refresh_lang() -> void:
	for g: Dictionary in gates.values():
		g["name"] = str(GameData.map_data(str(g.get("to", ""))).get("name", g.get("to", "")))
		var lbl = g.get("label")
		if lbl != null and is_instance_valid(lbl):
			(lbl as Label3D).text = Loc.t("通往 %s ➜" % g.name, "To %s ➜" % g.name) if g.open else Loc.t("%s · 尚未开放" % g.name, "%s · LOCKED" % g.name)
	if not shaft.is_empty():
		shaft["name"] = str(GameData.map_data("abyss_maw").get("name", Loc.t("零号深渊井", "Abyss Maw")))
		var sl = shaft.get("label")
		if sl != null and is_instance_valid(sl):
			(sl as Label3D).text = Loc.t("▼ 深井升降台 · 潜入「%s」" % shaft.name, "▼ Shaft Lift · Descend to [%s]" % shaft.name)


func _setup_hidden_shaft() -> void:
	if raid.map_id != "canyon" or not GameData.MAPS.has("abyss_maw"):
		return
	var base := Vector3.ZERO
	var found := false
	for i in raid.poi_ids.size():
		if str(raid.poi_ids[i]) == "mining_terminal":
			base = raid.poi_centers[i]
			found = true
			break
	if not found:
		return
	var pos := base + Vector3(0.0, 0.0, 14.5)
	for off: Vector3 in [Vector3(0.0, 0.0, 14.5), Vector3(-16.0, 0.0, 4.0), Vector3(16.0, 0.0, 4.0), Vector3(0.0, 0.0, -14.5)]:
		var cand: Vector3 = base + off
		var q := Vector2(cand.x, cand.z)
		if not raid.in_bounds_xz(q, 6.0) or raid.in_wet(q, 2.5):
			continue
		var blocked := false
		for b: Rect2 in raid.blocks:
			if b.grow(2.5).has_point(q):
				blocked = true
				break
		if not blocked:
			pos = cand
			break
	_build_shaft(pos)


func _build_shaft(pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = "HiddenShaft_abyss_maw"
	raid.world.add_child(n)
	n.global_position = Vector3(pos.x, 0.0, pos.z)
	var col := Color(0.68, 0.42, 0.96)
	var m_dark := A.metal(Color(0.14, 0.15, 0.17))
	var m_emit := A.emit(col, 2.2)
	m_emit.albedo_color = col.darkened(0.45)
	A.add(n, A.cyl(4.4, 0.24, 4.6, 16), A.concrete(Color(0.32, 0.31, 0.30), false), Vector3(0, 0.12, 0))
	A.add(n, A.cyl(3.6, 0.28, 3.8, 16), m_dark, Vector3(0, 0.145, 0))
	A.add(n, A.cyl(3.8, 0.08, 3.9, 16), A.hazard(), Vector3(0, 0.26, 0))
	for ai in 4:
		var ang := float(ai) * PI * 0.5 + PI * 0.25
		var p_off := Vector3(cos(ang) * 3.8, 1.3, sin(ang) * 3.8)
		A.add(n, A.bevel_box(Vector3(0.38, 2.6, 0.38), 0.03), m_dark, p_off)
		A.add(n, A.cyl(0.20, 0.32, 0.20, 10), m_emit, p_off + Vector3(0, 1.45, 0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n, A.quad(9.2, 9.2), A.extract_pad_mat(Color(col.r, col.g, col.b, 0.36), 0.25, 3), Vector3(0, 0.31, 0), Vector3.ZERO, Vector3.ONE, false)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.6
	l.omni_range = 12.0
	l.position = Vector3(0, 2.8, 0)
	n.add_child(l)
	var target_name := str(GameData.map_data("abyss_maw").get("name", Loc.t("零号深渊井", "Abyss Maw")))
	# 深井升降台不再悬挂 3D 漂浮文字，由顶部区域横幅与进入升降台时的 HUD 提示承担
	shaft = {"to": "abyss_maw", "name": target_name, "pos": Vector2(pos.x, pos.z), "open": true, "node": n, "label": null}


## 转场进入的落点：对应边的转场口向内 16 米；该边没有转场口时退回原空投点
func entry_point(edge: String, fallback: Vector3) -> Vector3:
	if not gates.has(edge):
		return fallback
	return _gate_point(gates[edge], 0.0, 16.0)


## 新战区就绪后：恢复机甲与局内状态，跳过空投，淡入
func arrive(state: Dictionary, at: Vector3) -> void:
	var m = raid.mech
	var ms: Dictionary = state.get("mech", {})
	m.hp = clampf(float(ms.get("hp", m.hp)), 1.0, m.max_hp)
	m.energy = clampf(float(ms.get("energy", m.energy)), 0.0, m.max_energy)
	for k in ms.get("parts", {}):
		m.parts[k] = float(ms.parts[k])
	for k in ms.get("ammo", {}):
		m.ammo[k] = int(ms.ammo[k])
	for k in ms.get("mag", {}):
		m.mag[k] = int(ms.mag[k])
	for k in ["ability_cd", "dash_cd", "emergency"]:
		if ms.has(k):
			m.set(k, float(ms[k]))
	raid.time = float(state.get("time", 0.0))
	raid.kills = int(state.get("kills", 0))
	raid.start_cargo = (state.get("start_cargo", []) as Array).duplicate()
	raid._seen_kinds = (state.get("seen", {}) as Dictionary).duplicate()
	raid.visited_maps = (state.get("visited", [raid.map_id]) as Array).duplicate()
	var inw := _gate_inward(str(state.get("edge", "S")))
	var end_pos := Vector3(at.x, 0.3, at.z)
	m.global_position = end_pos
	m.legs.rotation.y = atan2(-inw.x, -inw.z)
	m.torso.rotation.y = m.legs.rotation.y
	m.aim_point = end_pos + inw * 10.0
	raid.dropping = false
	m.input_locked = false
	raid.camera.global_position = end_pos + raid.CAM_OFFSET * raid.cam_zoom
	raid.camera.look_at(end_pos, Vector3.UP)
	_cool = 2.5
	if GameData.test_mode:
		var ov := _overlay(1.0)
		var tw := ov.create_tween()
		tw.tween_interval(0.25)
		tw.tween_property(ov.get_child(0), "color:a", 0.0, 0.8)
		tw.tween_callback(ov.queue_free)


func _overlay(alpha: float, _text := "") -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = 90
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(0.0, 0.0, 0.0, alpha)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)
	return cl
