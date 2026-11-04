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
	"ironbelt": {"W": "greyport", "S": "canyon"},
	"redlake": {"S": "greyport"},
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

static var force_open := false   ## 测试用：忽略战区解锁条件

var raid
var gates := {}            ## edge -> {to, name, center: Vector3, along: float, open: bool, node, label}
var busy := false
var _hold := 0.0
var _cool := 2.0
var _in_gate := ""


func setup(r) -> void:
	raid = r
	var links: Dictionary = LINKS.get(raid.map_id, {})
	for edge: String in links:
		var to: String = links[edge]
		if not GameData.MAPS.has(to):
			continue
		var along := _pick_along(edge)
		var open := force_open or GameData.map_available(to)
		var g := {"edge": edge, "to": to, "name": str(GameData.map_data(to).get("name", to)), "along": along,
			"center": _edge_point(edge, along, 0.0), "open": open}
		gates[edge] = g
		_build_gate(g)


func gate_list() -> Array:
	return gates.values()


## 边界上 along 处、向内 inset 米的点
func _edge_point(edge: String, along: float, inset: float) -> Vector3:
	var H: float = raid.HALF - inset
	match edge:
		"N": return Vector3(along, 0, -H)
		"S": return Vector3(along, 0, H)
		"W": return Vector3(-H, 0, along)
		_: return Vector3(H, 0, along)


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
	var inw := _inward(g.edge)
	n.global_position = _edge_point(g.edge, g.along, 2.5)
	n.rotation.y = atan2(inw.x, inw.z)   # 本地 +z 朝地图内侧，本地 x 沿边界
	# 光幕
	var qm := QuadMesh.new()
	qm.size = Vector2(HALF_SPAN * 2.0, 8.0)
	var curtain := MeshInstance3D.new()
	curtain.mesh = qm
	curtain.material_override = _curtain_mat(Color(c.r, c.g, c.b, 0.9 if g.open else 0.45))
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain.position = Vector3(0, 4.0, 0)
	n.add_child(curtain)
	# 两侧信标柱
	for sx in [-HALF_SPAN, HALF_SPAN]:
		A.add(n, A.bevel_box(Vector3(0.9, 0.3, 0.9), 0.05), A.concrete(Color(0.45, 0.45, 0.47)), Vector3(sx, 0.15, 0))
		A.add(n, A.cyl(0.14, 7.0, 0.2, 8), A.metal(Color(0.3, 0.3, 0.33)), Vector3(sx, 3.6, 0))
		A.add(n, A.bevel_box(Vector3(0.45, 0.45, 0.45), 0.05), A.emit(c, 5.0), Vector3(sx, 7.3, 0), Vector3.ZERO, Vector3.ONE, false)
	# 地面箭头：三道人字形，指向边界外
	var am = A.emit(c, 3.0 if g.open else 1.0)
	for k in 3:
		var z := 6.0 + k * 4.5
		for s in [-1.0, 1.0]:
			var bar := A.add(n, A.bevel_box(Vector3(3.4, 0.08, 0.55), 0.03), am, Vector3(s * 1.2, 0.07, z - 1.2), Vector3(0, s * 45.0, 0), Vector3.ONE, false)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 地面边框
	A.ground_decal(n, A.ring_tex(), Color(c.r, c.g, c.b, 0.35), HALF_SPAN * 1.6, Vector3(0, 0.04, 6.0), true)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 2.2
	l.omni_range = 16.0
	l.position = Vector3(0, 3.0, 4.0)
	n.add_child(l)
	var lab := Label3D.new()
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.font_size = 56
	lab.pixel_size = 0.02
	lab.modulate = c.lightened(0.3)
	lab.outline_size = 10
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.position = Vector3(0, 9.5, 3.0)
	lab.text = ("通往 %s ➜" % g.name) if g.open else ("%s · 尚未开放" % g.name)
	n.add_child(lab)
	g["node"] = n
	g["label"] = lab


## 在地形图（小地图 / 大地图共用）上画出转场口：边上一段亮色粗线 + 向外的小三角
func paint_map(tex: ImageTexture) -> void:
	if tex == null or gates.is_empty():
		return
	var img := tex.get_image()
	var k: float = float(img.get_width()) / (raid.HALF * 2.0)
	for g: Dictionary in gates.values():
		var c: Color = GATE_COLOR if g.open else Color(0.55, 0.55, 0.6)
		var a := _edge_point(g.edge, g.along - HALF_SPAN, 1.5)
		var b := _edge_point(g.edge, g.along + HALF_SPAN, 1.5)
		var steps := 64
		for i in steps + 1:
			var p := a.lerp(b, float(i) / steps)
			var px := int((p.x + raid.HALF) * k)
			var pz := int((p.z + raid.HALF) * k)
			img.fill_rect(Rect2i(px - 3, pz - 3, 7, 7).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), c)
		var inw := _inward(g.edge)
		var tip := _edge_point(g.edge, g.along, 3.0)
		for d in 12:
			var q: Vector3 = tip + inw * (d + 4.0)
			var w := int(12 - d)
			var px := int((q.x + raid.HALF) * k)
			var pz := int((q.z + raid.HALF) * k)
			var r := Rect2i(px - (w if inw.x == 0 else 1), pz - (w if inw.z == 0 else 1), (w * 2 + 1) if inw.x == 0 else 3, (w * 2 + 1) if inw.z == 0 else 3)
			img.fill_rect(r.intersection(Rect2i(0, 0, img.get_width(), img.get_height())), c)
	tex.update(img)


# ---------------------------------------------------------------- 触发
func gate_at(p: Vector3) -> String:
	for g: Dictionary in gates.values():
		var depth := 0.0
		var along := 0.0
		match g.edge:
			"N": depth = p.z + raid.HALF; along = p.x
			"S": depth = raid.HALF - p.z; along = p.x
			"W": depth = p.x + raid.HALF; along = p.z
			_: depth = raid.HALF - p.x; along = p.z
		if depth < DEPTH and absf(along - float(g.along)) < HALF_SPAN:
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
		_in_gate = e
		_hold = 0.0
		if e != "" and raid.hud:
			var g: Dictionary = gates[e]
			raid.hud.msg(("穿越边界：保持在光幕内，即将进入「%s」" % g.name) if g.open else ("「%s」尚未开放，边界封锁" % g.name))
		for g: Dictionary in gates.values():
			g.label.text = ("通往 %s ➜" % g.name) if g.open else ("%s · 尚未开放" % g.name)
	if e == "" or not gates[e].open:
		return
	_hold += delta
	var g: Dictionary = gates[e]
	g.label.text = "进入 %s  %.1f" % [g.name, maxf(HOLD - _hold, 0.0)]
	if _hold >= HOLD:
		go(e)


## 穿过 edge 边的转场口
func go(edge: String) -> void:
	if busy or not gates.has(edge):
		return
	busy = true
	var g: Dictionary = gates[edge]
	var m = raid.mech
	m.input_locked = true
	if raid.open_box:
		raid.close_box()
	Audio.play_sfx("drop_retro")
	var ov := _overlay(0.0, "穿越战区边界\n%s ➜ %s" % [str(raid.MAP.get("name", raid.map_id)), g.name])
	var tw := ov.create_tween()
	tw.tween_property(ov.get_child(0), "color:a", 1.0, 0.55)
	tw.parallel().tween_property(ov.get_child(1), "modulate:a", 1.0, 0.4)
	await tw.finished
	var state := capture(edge)
	var parent: Node = raid.get_parent()
	var nr = load("res://scripts/raid.gd").new()
	for c in raid.get_signal_connection_list("raid_ended"):
		nr.raid_ended.connect(c.callable)
	var keep_map: String = GameData.map_id
	GameData.map_id = str(g.to)
	parent.add_child(nr)
	if "raid" in parent:
		parent.raid = nr
	nr.start(raid.loadout.duplicate(), state.mech.cargo.duplicate(), state)
	GameData.map_id = keep_map
	Events.deployed.emit(nr.map_id, raid.loadout.duplicate())
	raid.queue_free()


## 转场时要带走的状态
func capture(edge: String) -> Dictionary:
	var m = raid.mech
	var to: String = gates[edge].to if gates.has(edge) else ""
	var visited: Array = raid.visited_maps.duplicate()
	if not visited.has(to):
		visited.append(to)
	return {
		"edge": OPP.get(edge, "S"), "from": raid.map_id, "to": to,
		"time": raid.time, "kills": raid.kills, "start_cargo": raid.start_cargo.duplicate(),
		"seen": raid._seen_kinds.duplicate(), "visited": visited, "found_pois": {},
		"mech": {"hp": m.hp, "energy": m.energy, "parts": m.parts.duplicate(), "ammo": m.ammo.duplicate(), "mag": m.mag.duplicate(),
			"cargo": m.cargo.duplicate(), "skill_e_cd": m.skill_e_cd, "skill_r_cd": m.skill_r_cd, "ability_cd": m.ability_cd,
			"dash_cd": m.dash_cd, "emergency": m.emergency},
		"allies": raid.factions.ally_state() if raid.factions else [],
	}


## 转场进入的落点：对应边的转场口向内 16 米；该边没有转场口时退回原空投点
func entry_point(edge: String, fallback: Vector3) -> Vector3:
	if not gates.has(edge):
		return fallback
	var g: Dictionary = gates[edge]
	return _edge_point(edge, float(g.along), 16.0)


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
	for k in ["skill_e_cd", "skill_r_cd", "ability_cd", "dash_cd", "emergency"]:
		if ms.has(k):
			m.set(k, float(ms[k]))
	raid.time = float(state.get("time", 0.0))
	raid.kills = int(state.get("kills", 0))
	raid.start_cargo = (state.get("start_cargo", []) as Array).duplicate()
	raid._seen_kinds = (state.get("seen", {}) as Dictionary).duplicate()
	raid.visited_maps = (state.get("visited", [raid.map_id]) as Array).duplicate()
	m.global_position = Vector3(at.x, 0.3, at.z)
	var inw := _inward(str(state.get("edge", "S")))
	m.legs.rotation.y = atan2(-inw.x, -inw.z)
	m.torso.rotation.y = m.legs.rotation.y
	m.aim_point = m.global_position + inw * 10.0
	raid.dropping = false
	m.input_locked = false
	raid.camera.global_position = Vector3(at.x, 0, at.z) + raid.CAM_OFFSET * raid.cam_zoom
	raid.camera.look_at(Vector3(at.x, 0, at.z), Vector3.UP)
	_cool = 2.5
	var nm := str(raid.MAP.get("name", raid.map_id))
	var ov := _overlay(1.0, "进入战区\n%s" % nm)
	var tw := ov.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(ov.get_child(0), "color:a", 0.0, 0.8)
	tw.parallel().tween_property(ov.get_child(1), "modulate:a", 0.0, 1.4)
	tw.tween_callback(ov.queue_free)
	if raid.hud:
		raid.hud.msg("进入战区：%s（来自%s）。撤离仍需前往撤离点" % [nm, str(GameData.map_data(str(state.get("from", ""))).get("name", ""))])


func _overlay(alpha: float, text: String) -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = 90
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(0.0, 0.0, 0.0, alpha)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)
	var l: Label = preload("res://scripts/ui.gd").label(text, 24, GATE_COLOR.lightened(0.3), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.modulate.a = alpha
	cl.add_child(l)
	return cl
