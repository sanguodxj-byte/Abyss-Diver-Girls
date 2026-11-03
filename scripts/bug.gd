extends CharacterBody3D
## 虫族（参考《绝地潜兵2》终端虫）：跳虫=猎手(近战快)、酸液虫=胆汁喷吐者(远程)、甲虫=冲锋者(肉盾)。
## 黑褐色厚重切角甲壳 + 甲片缝隙露出的橙黄肉质 + 发光脓包。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")

const KINDS := {
	"ling": {"name": "跳虫", "hp": 26.0, "speed": 8.8, "dmg": 6.0, "range": 2.0, "rate": 0.7, "radius": 0.6, "color": Color(0.36, 0.09, 0.16), "scale": 0.8, "drop": 0.25},
	"spitter": {"name": "酸液虫", "hp": 42.0, "speed": 5.0, "dmg": 9.0, "range": 14.0, "rate": 2.0, "radius": 0.75, "color": Color(0.2, 0.28, 0.1), "scale": 1.0, "drop": 0.4},
	"beetle": {"name": "甲虫", "hp": 190.0, "speed": 4.2, "dmg": 20.0, "range": 2.8, "rate": 1.6, "radius": 1.35, "color": Color(0.24, 0.15, 0.1), "scale": 1.8, "drop": 0.9},

}
const Bugs2 = preload("res://scripts/bugs2.gd")
const HS = preload("res://scripts/hs.gd")
const KINDS2 := ["mantis", "bomber", "aegis", "mortar", "lancer", "burrower", "overseer", "ripper", "brood", "colossus"]

var kind := "ling"
## 行为模板：ling（近战快）/ spitter（远程）/ beetle（重型近战）；第二批虫族靠它复用现有 AI 与动画
var beh := "ling"
var data := {}
var hp := 30.0
var raid
var target
var state := "idle"
var atk_cd := 0.0
var aggro_range := 17.0
var home := Vector3.ZERO
var wander_to := Vector3.ZERO
var wander_t := 0.0
var visual: Node3D
var parts: Array = []
var legs: Array = []
var jaws: Array = []
var scythes: Array = []
var spinners: Array = []   ## [节点, 局部轴, 待机转速, 攻击转速]：钻头、雷达、核心转子
var sac: MeshInstance3D
var flash_t := 0.0
var gun: Node3D
var gun_tip: Node3D
var gun_glow: MeshInstance3D
## 动作状态：wind（蓄力前摇）→ strike（出手）→ recover（收招）
var act := ""
var act_t := 0.0
var act_dir := Vector3.FORWARD
var hit_tilt := Vector3.ZERO
var hit_v := Vector3.ZERO
var spawn_t := 0.0
var dying := false
var move_amt := 0.0
var sfx := ""
var _last_state := "idle"
var anim_t := 0.0
var strafe := 1.0


func setup(k: String, r, tgt) -> void:
	kind = k
	data = GameData.ENEMIES.get(k, KINDS.get(k, KINDS.ling))
	beh = data.get("beh", k)
	sfx = str(data.get("sfx", k))
	hp = data.hp
	raid = r
	target = tgt
	add_to_group("bugs")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 16 | 32   # 16 流浪者机甲 / 32 战斗队友机甲
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = data.radius
	shape.height = maxf(3.2, float(data.scale) * 1.6 + 1.0)   # 故意做高：俯视角下子弹从机甲肩部高度射出也能命中
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)
	strafe = 1.0 if randf() < 0.5 else -1.0
	anim_t = randf() * 10.0
	_build_visual()
	# 静态零件按材质合批：一只虫近百个网格压到十几个，动画部件（腿/颚/镰/翼等）保持独立
	_batch_static()
	# 地面已有影子贴片；实时阴影在虫群多时会把绘制调用翻倍，零件一律不投影
	for mi in parts:
		if is_instance_valid(mi):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 两点之间放一段锥形肢节（圆柱 UV：v 沿长度，贴图的关节环/刚毛会顺着肢节走）
func _seg(parent: Node3D, p0: Vector3, p1: Vector3, r0: float, r1: float, m: Material, seg := 10, shadow := true) -> MeshInstance3D:
	var d := p1 - p0
	var l := d.length()
	var mi := MeshInstance3D.new()
	mi.mesh = A.cyl(r1, l, r0, seg)   # cyl(r_top, h, r_bottom)：底端在 p0
	mi.material_override = m
	var y := d / l
	var x := y.cross(Vector3.FORWARD if abs(y.z) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (p0 + p1) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- 终端虫外形
# 对照《绝地潜兵2》参考图：
#  猎手 Hunter   → 骨白色带刺甲壳、粗壮弯曲的尖刺长腿、红橙肉质躯干、背后一对橙色膜翼、头顶橙色褶冠、前伸钩爪
#  胆汁喷吐者     → 巨大发光黄绿色胆汁囊（带暗色脉络），背上一层层参差的暗橄榄色锯齿甲片，暗色刀片腿
#  冲锋者 Charger → 高大，两条巨型锯齿甲壳前腿像柱子撑地，三角形带刺头冠 + 橙色角，后腿短小，尾部橙色肉臀发光
static var _tmats := {}


static func _tmat(c: Color, tex := "chitin_gray.png", rough := 0.55, coat := 0.4) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [c.to_html(), tex, rough]
	if _tmats.has(key):
		return _tmats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = A._bug_tex(tex)
	m.normal_enabled = true
	m.normal_texture = A._bug_tex("chitin_n.png" if tex.begins_with("chitin") else "leg_n.png")
	m.normal_scale = 1.3
	m.roughness = rough
	m.uv1_scale = Vector3(0.8, 0.8, 1.0)
	m.clearcoat_enabled = coat > 0.0
	m.clearcoat = coat
	m.clearcoat_roughness = 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_tmats[key] = m
	return m


## 锯齿刀片轮廓：底宽 w，长 l（向 -Y 延伸），两侧各 teeth 个外凸尖刺，尖端可偏弯 bend
static func _jag_outline(w: float, l: float, teeth: int, tooth: float, seed_v: int, bend := 0.0) -> PackedVector2Array:
	## 平滑收尖的弯刀主体 + 稀疏的后勾尖刺（尖刺朝根部方向勾，像终端虫腿上的倒刺）
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var N := 14
	var right: Array = []
	var left: Array = []
	var tooth_r := {}
	var tooth_l := {}
	for k in teeth:
		tooth_r[int(round((float(k) + 0.7) / float(teeth + 0.6) * (N - 2))) + 1] = true
		if k % 2 == 0:
			tooth_l[int(round((float(k) + 1.2) / float(teeth + 0.8) * (N - 2))) + 1] = true
	for i in range(1, N):
		var t := float(i) / float(N)
		var half: float = w * 0.5 * pow(1.0 - t, 0.85) * (1.0 + 0.12 * sin(t * PI))
		var cx: float = bend * t * t
		var y := -l * t
		var seg := l / float(N)
		right.append(Vector2(cx + half, y))
		if tooth_r.has(i):
			var tl: float = tooth * r.randf_range(0.8, 1.25) * (1.0 - t * 0.5)
			right.append(Vector2(cx + half + tl, y + seg * 0.9))  # 尖端向根部勾
			right.append(Vector2(cx + half * 0.92, y - seg * 0.45))
		left.append(Vector2(cx - half, y))
		if tooth_l.has(i):
			var tl2: float = tooth * r.randf_range(0.5, 0.9) * (1.0 - t * 0.5)
			left.append(Vector2(cx - half - tl2, y + seg * 0.9))
			left.append(Vector2(cx - half * 0.92, y - seg * 0.45))
	var o := PackedVector2Array()
	o.append(Vector2(-w * 0.5, 0.0))
	o.append(Vector2(w * 0.5, 0.0))
	for q in right:
		o.append(q)
	o.append(Vector2(bend, -l))
	for i in range(left.size() - 1, -1, -1):
		# 左侧尖刺的两个点在反向遍历时需保持“先基后尖”的顺序
		o.append(left[i])
	return o


## 任意（可凹）轮廓沿 Z 挤出，硬边法线；中脊略隆起让刀片有体积感
static func _jag_mesh(outline: PackedVector2Array, thick: float, ridge := 0.35) -> ArrayMesh:
	var key := "jag%s|%.4f|%.2f" % [str(outline), thick, ridge]
	if _tmats.has(key):
		return _tmats[key]
	var idx := Geometry2D.triangulate_polygon(outline)
	if idx.is_empty():
		outline = Geometry2D.convex_hull(outline)
		outline.remove_at(outline.size() - 1)
		idx = Geometry2D.triangulate_polygon(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thick * 0.5
	var cx := 0.0
	for q in outline:
		cx += q.x
	cx /= outline.size()
	var mn := outline[0]
	var mx := outline[0]
	for q in outline:
		mn = Vector2(min(mn.x, q.x), min(mn.y, q.y))
		mx = Vector2(max(mx.x, q.x), max(mx.y, q.y))
	var ww: float = max(0.001, (mx.x - mn.x) * 0.5)
	var area := 0.0
	for i in outline.size():
		var q0 := outline[i]
		var q1 := outline[(i + 1) % outline.size()]
		area += q0.x * q1.y - q1.x * q0.y
	var verts: Array = []  # [pos, uv]
	for side in [1.0, -1.0]:
		for t in range(0, idx.size(), 3):
			var tri := []
			for k in [idx[t], idx[t + 1], idx[t + 2]]:
				var q: Vector2 = outline[k]
				var bulge: float = (1.0 - clamp(abs(q.x - cx) / ww, 0.0, 1.0)) * thick * ridge
				tri.append([Vector3(q.x, q.y, side * (h + bulge)), q * 1.5])
			_emit_tri(st, tri, Vector3(0, 0, side))
	var n := outline.size()
	for i in n:
		var p0 := outline[i]
		var p1 := outline[(i + 1) % n]
		var d := p1 - p0
		var outw := Vector3(d.y, -d.x, 0) if area > 0.0 else Vector3(-d.y, d.x, 0)
		var a0 := Vector3(p0.x, p0.y, h)
		var a1 := Vector3(p1.x, p1.y, h)
		var b0 := Vector3(p0.x, p0.y, -h)
		var b1 := Vector3(p1.x, p1.y, -h)
		var u := d.length() * 1.5
		_emit_tri(st, [[a0, Vector2(0, 0)], [b0, Vector2(0, thick)], [b1, Vector2(u, thick)]], outw)
		_emit_tri(st, [[a0, Vector2(0, 0)], [b1, Vector2(u, thick)], [a1, Vector2(u, 0)]], outw)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_tmats[key] = m
	return m


## 按 Godot 顺时针为正面的约定输出三角形，保证法线朝 outward
static func _emit_tri(st: SurfaceTool, tri: Array, outward: Vector3) -> void:
	var v0: Vector3 = tri[0][0]
	var v1: Vector3 = tri[1][0]
	var v2: Vector3 = tri[2][0]
	var order := [0, 1, 2]
	if (v1 - v0).cross(v2 - v0).dot(outward) > 0.0:
		order = [0, 2, 1]
	for k in order:
		st.set_uv(tri[k][1])
		st.add_vertex(tri[k][0])


func _jag(p: Node3D, w: float, l: float, thick: float, m: Material, pos: Vector3, rot: Vector3, teeth := 3, tooth := -1.0, bend := 0.0) -> MeshInstance3D:
	var tt: float = w * 0.35 if tooth < 0.0 else tooth
	var sd: int = parts.size() * 7 + int(l * 100.0)
	var o := _jag_outline(w, l, teeth, tt, sd, bend)
	var tries := 0
	while Geometry2D.triangulate_polygon(o).is_empty() and tries < 4:
		tries += 1
		o = _jag_outline(w, l, teeth if tries < 3 else 0, tt * 0.6, sd + tries, bend * (0.5 if tries > 1 else 1.0))
	var mi := A.add(p, _jag_mesh(o, thick), m, pos, rot)
	parts.append(mi)
	return mi


static func _bx(v: Vector3) -> Mesh:
	return HS.cbox(v)


func _pustule(p: Node3D, pos: Vector3, r: float, c: Color, e := 1.0) -> void:
	A.add(p, A.sphere(r, -1, 10), A.emit(c, e), pos, Vector3.ZERO, Vector3(1, 0.75, 1), false)


# ---------------------------------------------------------------- v2 异形虫族（星际争霸 Zerg × 绝地潜兵 Terminid）
# 统一配色：暗褐黑亮面甲壳 → 骨白刃尖（顶点色渐变），甲片缝隙露出橙红发光肉质，橙色发光眼/囊。
# 造型语言：弯曲的镰刃、背脊长刺、分段拱形甲、反关节腿、前倾猎食姿态 —— 不是现实昆虫。
static var _sm := {}
const C_CH := Color(0.22, 0.225, 0.24)     # 主甲壳
const C_CH2 := Color(0.4, 0.41, 0.44)    # 亮一档甲壳
const C_BONE := Color(0.58, 0.59, 0.63)   # 骨白刃尖
const C_FL := Color(0.05, 0.05, 0.06)      # 肉
const C_GLOW := Color(0.62, 0.22, 1.0)    # 发光


static func _vmat() -> StandardMaterial3D:
	if _sm.has("v"):
		return _sm["v"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.26
	m.metallic = 0.6
	m.metallic_specular = 0.8
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.15
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_panelize(m)
	_sm["v"] = m
	return m


static func _flesh(c := C_FL, glow := 0.12) -> StandardMaterial3D:
	# 内部机体：暗色金属骨架，透出能量辉光
	var key := "fl%s%.2f" % [c.to_html(), glow]
	if _sm.has(key):
		return _sm[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.9
	m.roughness = 0.35
	m.rim_enabled = true
	m.rim = 0.5
	m.rim_tint = 1.0
	m.emission_enabled = true
	m.emission = C_GLOW
	m.emission_energy_multiplier = glow
	_sm[key] = m
	return m


static func _glow(e := 2.5) -> StandardMaterial3D:
	return A.emit(C_GLOW, e)


static func _ball() -> SphereMesh:
	if _sm.has("ball"):
		return _sm["ball"]
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.rings = 14
	s.radial_segments = 24
	_sm["ball"] = s
	return s


## 静态零件合批：同材质的零件并成一个网格，动画部件所在的子树整段跳过
func _batch_static() -> void:
	var skip := {}
	var roots: Array = []
	# 动画部件集合分散在基类与 enemy 子类，按属性名动态取，缺属性返回 null
	for prop in ["legs", "jaws", "scythes", "wings", "plates", "crystals", "sacs", "crown", "turret"]:
		var v = get(prop)
		if v is Array:
			for n in v:
				if is_instance_valid(n) and n is Node:
					roots.append(n)
		elif v is Node:
			roots.append(v)
	for e in spinners:
		roots.append(e[0] if e is Array else e)
	for prop in ["sac", "gun", "gun_tip", "gun_glow", "abdomen", "core_mi"]:
		var v2 = get(prop)
		if is_instance_valid(v2) and v2 is Node:
			roots.append(v2)
	for n in roots:
		skip[n.get_instance_id()] = true
	for c in visual.get_children():
		if c is Node3D:
			_batch_container(c, skip)
	# 动画根节点自身挂的网格只随根节点整体运动，可以直接合批；再往下的子节点不动
	for n in roots:
		if is_instance_valid(n) and n is Node3D:
			_batch_direct(n)


func _batch_direct(root: Node3D) -> void:
	var buckets := {}
	for ch in root.get_children():
		if ch is MeshInstance3D:
			var mi: MeshInstance3D = ch
			if mi.mesh == null or mi.material_override == null:
				continue
			var key := str(mi.material_override.get_instance_id())
			if not buckets.has(key):
				buckets[key] = {"mat": mi.material_override, "list": []}
			buckets[key]["list"].append(mi)
	for key in buckets:
		var b: Dictionary = buckets[key]
		var list: Array = b["list"]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list:
			for si in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, si, mi.transform)
		st.index()
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = b["mat"]
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(merged)
		parts.append(merged)
		for mi in list:
			parts.erase(mi)
			mi.queue_free()


func _batch_container(top: Node3D, skip: Dictionary) -> void:
	var buckets := {}
	var singles: Array = []
	var stack: Array = [top]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n != top:
			var mi: MeshInstance3D = n
			if mi.mesh != null and mi.material_override != null and is_instance_valid(mi):
				var ext: Vector3 = mi.mesh.get_aabb().size * mi.get_global_transform().basis.get_scale()
				var small: bool = maxf(ext.x, maxf(ext.y, ext.z)) < 0.2
				var key := "%d%s" % [mi.material_override.get_instance_id(), "|d" if small else ""]
				if not buckets.has(key):
					buckets[key] = {"mat": mi.material_override, "small": small, "list": []}
				buckets[key]["list"].append(mi)
			continue
		if skip.has(n.get_instance_id()):
			continue
		for ch in n.get_children():
			stack.append(ch)
	for key in buckets:
		var b: Dictionary = buckets[key]
		var list: Array = b["list"]
		if list.size() < 2:
			singles.append(list[0])
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list:
			var xf := _rel_xf(mi, top)
			for si in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, si, xf)
		st.index()
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = b["mat"]
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top.add_child(merged)
		parts.append(merged)
		if b["small"]:
			detail.append(merged)
			merged.visible = _detail_on
		for mi in list:
			parts.erase(mi)
			mi.queue_free()


func _rel_xf(n: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _p(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := A.add(parent, mesh, m, pos, rot, scl, shadow)
	parts.append(mi)
	return mi


func _ell(parent: Node3D, m: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	return _p(parent, _ball(), m, pos, rot, size, shadow)


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## 扫掠体：沿控制点（Catmull-Rom 平滑）扫出椭圆截面管，半径逐点插值，末端可收成尖。
## rx = 侧向（tangent×up）缩放，ry = 法向缩放；c0→c1 顶点色沿长度渐变（甲壳→骨白）。
## 这是所有刃、刺、腿、甲带、蛇颈的共同基元。
func _sweep(parent: Node3D, pts: Array, radii: Array, c0: Color, c1: Color, rx := 1.0, ry := 1.0, up := Vector3.UP, steps := 6, rad := 10, m: Material = null, grad_start := 0.45, hard := false) -> MeshInstance3D:
	var path: Array = []
	var rs: Array = []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[max(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[min(i + 2, n - 1)]
		for k in steps:
			var t := float(k) / steps
			path.append(_cr(p0, p1, p2, p3, t))
			rs.append(lerpf(radii[i], radii[i + 1], t))
	path.append(pts[n - 1])
	rs.append(radii[n - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if hard:
		st.set_smooth_group(-1)
	var cnt := path.size()
	var total := 0.0
	var acc: Array = [0.0]
	for i in range(1, cnt):
		total += (path[i] - path[i - 1]).length()
		acc.append(total)
	var rings: Array = []
	for i in cnt:
		var tg: Vector3 = (path[min(i + 1, cnt - 1)] - path[max(i - 1, 0)]).normalized()
		var sd := tg.cross(up)
		if sd.length() < 0.01:
			sd = tg.cross(Vector3.FORWARD)
		sd = sd.normalized()
		var nm := sd.cross(tg).normalized()
		var ring: Array = []
		var r: float = rs[i]
		for a in rad:
			var ang := TAU * a / rad
			ring.append([path[i] + sd * cos(ang) * r * rx + nm * sin(ang) * r * ry, (sd * cos(ang) * ry + nm * sin(ang) * rx).normalized()])
		rings.append(ring)
	for i in cnt - 1:
		var u0: float = acc[i] / total
		var u1: float = acc[i + 1] / total
		var col0 := c0.lerp(c1, clampf((u0 - grad_start) / (1.0 - grad_start), 0.0, 1.0))
		var col1 := c0.lerp(c1, clampf((u1 - grad_start) / (1.0 - grad_start), 0.0, 1.0))
		for a in rad:
			var b := (a + 1) % rad
			var q := [[rings[i][a], col0], [rings[i + 1][a], col1], [rings[i + 1][b], col1], [rings[i][b], col0]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_color(q[idx][1])
				if not hard:
					st.set_normal(q[idx][0][1])
				st.add_vertex(q[idx][0][0])
	if hard:
		st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m if m else _vmat()
	parent.add_child(mi)
	parts.append(mi)
	return mi


## 刃/刺：两段或多段弯曲、扁平、骨白收尖
func _blade(parent: Node3D, pts: Array, r0: float, flat := 0.35, up := Vector3.UP) -> MeshInstance3D:
	var radii: Array = []
	for i in pts.size():
		var t := float(i) / (pts.size() - 1)
		radii.append(r0 * (1.0 - t * t * 0.9) * (0.0 if i == pts.size() - 1 else 1.0))
	return _sweep(parent, pts, radii, C_CH, C_BONE, flat, 1.0, up, 1, 4, null, 0.45, true)


## 已废弃：虫族纯机械，不得有仿生尖刺（用户 2026-11-02）。保留空函数兼容旧调用。
func _spike(_parent: Node3D, _base: Vector3, _dir: Vector3, _length: float, _r: float, _bend := Vector3.ZERO) -> MeshInstance3D:
	return null


## 拱形甲带：从左侧低处 → 背顶 → 右侧低处的一条扁平甲，前后叠放成分段甲壳
func _band(parent: Node3D, z: float, y: float, half_w: float, arch: float, thick: float, width: float, tilt := 0.0, spines := 0.0) -> void:
	var pts: Array = []
	for k in 7:
		var a := lerpf(-1.0, 1.0, k / 6.0)
		pts.append(Vector3(a * half_w, y + arch * (1.0 - a * a) - abs(a) * 0.05, z + tilt * (1.0 - a * a)))
	var radii: Array = [thick * 0.4, thick, thick, thick, thick, thick, thick * 0.4]
	# 截面：沿身体纵向宽（width），法向薄（thick）
	_sweep(parent, pts, radii, C_CH, C_CH2, width / thick, 1.0, Vector3.UP, 4, 6, null, 0.0, true)
	# 甲片后缘一道发光能量缝
	var seam: Array = []
	for q in pts:
		seam.append(q + Vector3(0, -thick * 0.6, width * 0.95))
	_sweep(parent, seam, [thick * 0.12, thick * 0.3, thick * 0.3, thick * 0.3, thick * 0.3, thick * 0.3, thick * 0.12], C_GLOW, C_GLOW, 1.0, 1.0, Vector3.UP, 3, 5, _glow(2.2))
	if spines > 0.0:
		_spike(parent, Vector3(0, y + arch + thick * 0.5, z + tilt), Vector3(0, 0.55, 1), spines, thick * 1.6, Vector3(0, 0.15, 0) * spines)
		for sx: float in [-1.0, 1.0]:
			_spike(parent, Vector3(sx * half_w * 0.95, y - 0.02, z), Vector3(sx, 0.2, 0.6), spines * 0.7, thick * 1.2)


## 机械足垫：踝伺服 + 八棱缓冲柱 + 切角底板（取代尖足 / 爪）
func _foot_pad(hip: Node3D, foot: Vector3, w: float) -> void:
	_servo(hip, foot + Vector3(0, w * 0.8, 0), w * 0.8)
	_p(hip, A.cyl(w * 0.7, w * 0.9, w * 0.8, 8), _steel(), foot + Vector3(0, w * 0.3, 0))
	_p(hip, HS.cbox(Vector3(w * 2.6, w * 0.45, w * 3.0), w * 0.15), _vmat_solid(C_CH), foot + Vector3(0, -w * 0.25, 0))


## 机械连杆腿：髋 → 膝（外上）→ 跗（外下靠后）→ 液压足垫
func _zleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, reach: float, by: float, w: float, phase: float, spur := true) -> Node3D:
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0, yaw, 0)
	body.add_child(hip)
	var knee := Vector3(sx * reach * 0.42, by * 0.42, 0)
	var hock := Vector3(sx * reach * 0.78, -by * 0.35, w * 0.6)
	var tip := Vector3(sx * reach, -by + 0.01, -w * 0.8)
	# 纯机械：三段放样连杆 + 液压足垫（无尖端）
	var DKm := _vmat_solid(C_CH)
	var ARm := _vmat_solid(C_CH2)
	var foot := Vector3(tip.x, -by + w * 0.5, tip.z)
	_limb(hip, Vector3.ZERO, knee, w * 1.7, w * 1.9, DKm, 0.75, 1.15)
	_limb(hip, knee, hock, w * 1.4, w * 1.6, ARm, 0.7, 1.1, Vector3.FORWARD)
	_limb(hip, hock, foot + Vector3(0, w * 0.8, 0), w * 1.0, w * 1.1, DKm, 0.85, 1.0, Vector3.FORWARD)
	_foot_pad(hip, foot, w)
	_servo(hip, Vector3.ZERO, w * 1.3)
	_servo(hip, knee, w * 1.05)
	_servo(hip, hock, w * 0.7)
	# 液压杆：股节下方平行一根银色活塞
	_seg(hip, Vector3(sx * w * 0.5, -w * 1.2, 0), knee.lerp(hock, 0.35) + Vector3(0, -w * 0.3, 0), w * 0.28, w * 0.2, _steel(), 6)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


## 已废弃：虫族不得有眼、嘴等仿生物部位（用户 2026-11-02）。保留空函数以兼容旧调用。
func _eyes(_head: Node3D, _z: float, _y: float, _xs: Array, _r: float) -> void:
	pass


## 关节伺服：侧向金属圆盘 + 发光环
func _servo(parent: Node3D, pos: Vector3, r: float) -> void:
	var mi := _p(parent, A.cyl(r, r * 1.3, r, 8), _steel(), pos, Vector3(0, 0, 90))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p(parent, A.torus(r * 0.8, r * 1.02, 12), _glow(2.0), pos, Vector3(0, 0, 90), Vector3(1, 1.5, 1), false)


static func _steel() -> StandardMaterial3D:
	if _sm.has("steel"):
		return _sm["steel"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.6, 0.68)
	m.metallic = 0.65
	m.roughness = 0.22
	_sm["steel"] = m
	return m


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var s: float = data.scale
	A.ground_decal(visual, A.blob_tex(), Color(1, 1, 1, 0.75), 2.6 * s, Vector3(0, 0.03, 0))
	var body := Node3D.new()
	body.name = "Body"
	visual.add_child(body)
	if kind in KINDS2:
		match kind:
			"mantis":
				Bugs2.build_mantis(self, body, s)
			"bomber":
				Bugs2.build_bomber(self, body, s)
			"aegis":
				Bugs2.build_aegis(self, body, s)
			"mortar":
				Bugs2.build_mortar(self, body, s)
			"lancer":
				Bugs2.build_lancer(self, body, s)
			"burrower":
				Bugs2.build_burrower(self, body, s)
			"overseer":
				Bugs2.build_overseer(self, body, s)
			"ripper":
				Bugs2.build_ripper(self, body, s)
			"brood":
				Bugs2.build_brood(self, body, s)
			"colossus":
				Bugs2.build_colossus(self, body, s)
		return
	match kind:
		"ling":
			_build_ling(body, s)
		"spitter":
			_build_spitter(body, s)
		_:
			_build_brute(body, s)


## 方棱构件：从 a 到 b 的长方体（w 侧宽、h 高），up 决定朝向
func _bar(parent: Node3D, a: Vector3, b: Vector3, w: float, h: float, m: Material, up := Vector3.UP) -> MeshInstance3D:
	var d := b - a
	var l := d.length()
	var z := d / l
	var x := up.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	var mi := MeshInstance3D.new()
	mi.mesh = _bx(Vector3(w, h, l))
	mi.material_override = m
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	parent.add_child(mi)
	parts.append(mi)
	return mi


## 放样肢节：a → b，起点截面 w×h，末端 taper，中前段鼓起 bulge（硬表面切角截面，取代方棍）
func _limb(parent: Node3D, a: Vector3, b: Vector3, w: float, h: float, m: Material, taper := 0.7, bulge := 1.15, up := Vector3.UP, chamf := 0.35) -> MeshInstance3D:
	var d := b - a
	var l := d.length()
	var z := d / l
	var x := up.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	var mi := MeshInstance3D.new()
	mi.mesh = HS.limb_mesh(l, w, h, taper, bulge, chamf)
	mi.material_override = m
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	parent.add_child(mi)
	parts.append(mi)
	return mi


## 放样体：base 截面 + secs（见 hs.gd loft）
func _loft(parent: Node3D, base: Array, secs: Array, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _p(parent, HS.loft(base, secs), m, pos, rot)


## 弧形覆甲壳（沿局部 Z），profile = [[t, 宽比, 高比, 顶面 y], ...]
func _shell(parent: Node3D, m: Material, pos: Vector3, r: float, t: float, z0: float, z1: float, profile: Array, rot := Vector3.ZERO, ang := 70.0, seg := 6) -> MeshInstance3D:
	return _p(parent, HS.shell_mesh(r, t, z0, z1, profile, ang, seg), m, pos, rot)


func _box(parent: Node3D, m: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _p(parent, _bx(size), m, pos, rot)


## 机械腿：髋伺服 → 方形股节（顶部装甲板）→ 膝伺服 → 菱形截面胫刃插地 + 液压杆
func _mleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, reach: float, by: float, w: float, phase: float, spur := true) -> Node3D:
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0, yaw, 0)
	body.add_child(hip)
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var knee := Vector3(sx * reach * 0.45, by * 0.5, 0)
	var foot := Vector3(sx * reach, -by + 0.01, 0)
	_servo(hip, Vector3.ZERO, w * 1.4)
	_bar(hip, Vector3.ZERO, knee, w * 1.3, w * 1.6, DK)
	_bar(hip, Vector3(0, w * 0.9, 0), knee + Vector3(0, w * 0.9, 0), w * 1.9, w * 0.5, AR)
	_servo(hip, knee, w * 1.15)
	var ank := knee.lerp(foot, 0.55) + Vector3(sx * w * 0.8, 0, 0)
	var fp := Vector3(foot.x, -by + w * 0.5, foot.z)
	_limb(hip, knee, ank, w * 1.5, w * 1.7, DK, 0.75, 1.12, Vector3.FORWARD)
	_limb(hip, ank, fp + Vector3(0, w * 0.8, 0), w * 1.05, w * 1.15, AR, 0.85, 1.0, Vector3.FORWARD)
	_foot_pad(hip, fp, w)
	_seg(hip, Vector3(0, -w * 1.0, 0), knee.lerp(ank, 0.5) + Vector3(-sx * w * 0.6, 0, 0), w * 0.25, w * 0.2, _steel(), 6)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


## 跳虫：铁血「Dinergate 衍生突击犬」。方核心舱外包一块 Γ 形浅灰护壳（盖顶并包住一侧），
## 正面一只大圆透镜独眼，左前上方小传感头；腹下两把折叠刃臂；尾部双喷口跳跃推进器；
## 四条短粗切面腿，胫部浅灰斑带。与炮击虫（高抬腿 + 盾状足）和攻城虫（六足活塞腿）轮廓完全不同。
func _dleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, s: float, by: float, phase: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0, yaw, 0)
	body.add_child(hip)
	var DK := _vmat_solid(C_CH)
	var AR := _vmat_solid(C_CH2)
	var LT := _vmat_matte(Color(0.7, 0.7, 0.72))
	var knee := Vector3(sx * 0.2 * s, -0.08 * s, 0)
	var foot := Vector3(sx * 0.3 * s, -by + 0.01, 0)
	_servo(hip, Vector3.ZERO, 0.07 * s)
	_bar(hip, Vector3.ZERO, knee, 0.13 * s, 0.15 * s, AR)
	# 胫：上宽下窄的切面柱，下端斜切成凿形足尖
	var sh := Node3D.new()
	sh.position = knee
	hip.add_child(sh)
	var L := knee.y - foot.y
	_prism(sh, [Vector2(-0.08 * s, 0), Vector2(0.08 * s, 0), Vector2(0.06 * s, -L + 0.06 * s), Vector2(0.0, -L), Vector2(-0.05 * s, -L + 0.08 * s)],
		0.14 * s, 0.05, DK, Vector3(sx * 0.1 * s - knee.x + foot.x - sx * 0.1 * s, 0, 0) * 0.0, Vector3(0, 90, 0))
	_box(sh, LT, Vector3(0, -L * 0.62, 0), Vector3(0.155, 0.06, 0.15) * s, Vector3(0, 0, sx * 8.0))
	_box(sh, _glow(1.6), Vector3(sx * 0.075 * s, -L * 0.3, 0), Vector3(0.006, 0.12, 0.012) * s)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


func _build_ling(body: Node3D, s: float) -> void:
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var LT := _vmat_matte(Color(0.7, 0.7, 0.72))
	var BL := _vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.52 * s
	# 核心舱：斜切方舱
	_prism(body, [Vector2(-0.24, -0.16) * s, Vector2(0.24, -0.16) * s, Vector2(0.27, -0.08) * s, Vector2(0.27, 0.16) * s, Vector2(-0.27, 0.16) * s, Vector2(-0.27, -0.08) * s],
		0.72 * s, 0.05, DK, Vector3(0, by, 0.02 * s))
	# Γ 形护壳：盖住顶面并包住右侧，左侧露出核心舱
	_prism(body, [Vector2(-0.3, 0.3) * s, Vector2(0.28, 0.3) * s, Vector2(0.36, 0.22) * s, Vector2(0.36, -0.16) * s, Vector2(0.28, -0.2) * s, Vector2(0.28, 0.18) * s, Vector2(-0.3, 0.18) * s],
		0.8 * s, 0.08, LT, Vector3(0, by, 0.06 * s))
	_panels(body, Vector3(0, by + 0.3 * s + 0.005, 0.06 * s), Vector3(-90, 0, 0), 0.6 * s, 0.76 * s, 11, 5)
	_panels(body, Vector3(0, by, -0.34 * s - 0.005), Vector3(0, 180, 0), 0.5 * s, 0.3 * s, 14, 4)
	_panels(body, Vector3(0, by + 0.06 * s, 0.445 * s), Vector3.ZERO, 0.5 * s, 0.26 * s, 15, 3)
	_panels(body, Vector3(0.36 * s + 0.005, by + 0.03 * s, 0.06 * s), Vector3(0, 90, 0), 0.74 * s, 0.34 * s, 12, 4)
	_panels(body, Vector3(-0.272 * s, by - 0.08 * s, 0.22 * s), Vector3(0, -90, 0), 0.26 * s, 0.12 * s, 13, 2)
	# 护壳前缘外翻凸边 + 后部台阶
	_box(body, LT, Vector3(0.0, by + 0.27 * s, -0.36 * s), Vector3(0.62, 0.1, 0.06) * s, Vector3(20, 0, 0))
	_box(body, AR, Vector3(-0.05 * s, by + 0.33 * s, 0.22 * s), Vector3(0.4, 0.06, 0.3) * s)
	_box(body, _glow(2.0), Vector3(0.365 * s, by + 0.05 * s, 0.06 * s), Vector3(0.006, 0.016, 0.6) * s)
	_box(body, _glow(2.0), Vector3(-0.272 * s, by - 0.02 * s, 0.06 * s), Vector3(0.006, 0.016, 0.5) * s)
	for k in 3:
		_box(body, BL, Vector3(-0.273 * s, by + 0.06 * s, (-0.1 + k * 0.1) * s), Vector3(0.006, 0.12, 0.045) * s)
	# 正面圆形装甲舱盖（非眼睛：实心钢盖，无发光、无暗腔）
	var eye := Vector3(-0.02 * s, by + 0.0, -0.34 * s)
	_p(body, A.cyl(0.17 * s, 0.08 * s, 0.17 * s, 16), AR, eye, Vector3(90, 0, 0))
	_p(body, A.cyl(0.14 * s, 0.02 * s, 0.14 * s, 16), _steel(), eye + Vector3(0, 0, -0.045 * s), Vector3(90, 0, 0))
	# 左前上方小传感头（红色狭缝）
	var head := Node3D.new()
	head.position = Vector3(-0.17 * s, by + 0.38 * s, -0.24 * s)
	body.add_child(head)
	_box(head, DK, Vector3(0, 0, 0.06 * s), Vector3(0.1, 0.08, 0.24) * s)
	_box(head, LT, Vector3(0, 0.0, -0.08 * s), Vector3(0.12, 0.1, 0.07) * s)
	_box(head, _glow(2.4), Vector3(0, 0.0, -0.117 * s), Vector3(0.05, 0.022, 0.006) * s)
	# 腹下折叠刃臂（jaws：攻击时向内剪合）
	for sx: float in [-1.0, 1.0]:
		var jaw := Node3D.new()
		jaw.position = Vector3(sx * 0.17 * s, by - 0.15 * s, -0.26 * s)
		body.add_child(jaw)
		_servo(jaw, Vector3.ZERO, 0.05 * s)
		_box(jaw, AR, Vector3(0, -0.02 * s, -0.08 * s), Vector3(0.06, 0.07, 0.18) * s, Vector3(20, 0, 0))
		_prism(jaw, [Vector2(0, 0.02) * s, Vector2(0.3, 0.0) * s, Vector2(0.42, 0.08) * s, Vector2(0.28, -0.05) * s, Vector2(0, -0.06) * s],
			0.025 * s, 0.4, LT, Vector3(0, -0.06 * s, -0.16 * s), Vector3(0, 90, 0))
		jaws.append(jaw)
	# 尾部跳跃推进器：双喷口 + 紫色尾焰芯
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx * 0.13 * s, by + 0.06 * s, 0.46 * s)
		_p(body, A.cyl(0.07 * s, 0.14 * s, 0.09 * s, 8), AR, n, Vector3(-80, 0, 0))
		_p(body, A.cyl(0.05 * s, 0.01 * s, 0.05 * s, 8), _glow(2.2), n + Vector3(0, 0.012 * s, 0.072 * s), Vector3(-80, 0, 0), Vector3.ONE, false)
	_box(body, DK, Vector3(0, by + 0.06 * s, 0.4 * s), Vector3(0.36, 0.16, 0.08) * s)
	sac = _box(body, _glow(0.8), Vector3(0, by + 0.06 * s, 0.445 * s), Vector3(0.06, 0.06, 0.01) * s)
	# 四条短粗腿：前腿前外、后腿后外
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			_dleg(body, Vector3(sx * 0.26 * s, by - 0.1 * s, (-0.2 + i * 0.42) * s), sx * (-20.0 + i * 40.0), sx, s, by - 0.1 * s,
				float(i % 2) * PI + (PI if sx > 0 else 0.0))


## 面板分割：在一个矩形面上（本地 +Z 朝外）用确定性随机切出 3~6 块凸起子面板，
## 多色调交替（深枪灰 / 中灰 / 浅灰），缝隙露出底面形成分缝线，并随机加螺栓、散热槽、警示条纹，
## 用来打碎大面积单一色块。
func _panels(parent: Node3D, center: Vector3, rot: Vector3, w: float, h: float, seed: int, n := 4, tones: Array = []) -> void:
	var f := Node3D.new()
	f.position = center
	f.rotation_degrees = rot
	parent.add_child(f)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if tones.is_empty():
		tones = [_vmat_solid(Color(0.14, 0.14, 0.155)), _vmat_matte(Color(0.34, 0.345, 0.37)), _vmat_matte(Color(0.6, 0.6, 0.62)), _vmat_matte(Color(0.3, 0.26, 0.36)), _vmat_solid(C_CH)]
	var cells: Array = [Rect2(-w * 0.5, -h * 0.5, w, h)]
	for k in n - 1:
		var bi := 0
		for i in cells.size():
			if cells[i].get_area() > cells[bi].get_area():
				bi = i
		var c: Rect2 = cells[bi]
		cells.remove_at(bi)
		var t := rng.randf_range(0.32, 0.68)
		if c.size.x >= c.size.y:
			cells.append(Rect2(c.position, Vector2(c.size.x * t, c.size.y)))
			cells.append(Rect2(c.position + Vector2(c.size.x * t, 0), Vector2(c.size.x * (1.0 - t), c.size.y)))
		else:
			cells.append(Rect2(c.position, Vector2(c.size.x, c.size.y * t)))
			cells.append(Rect2(c.position + Vector2(0, c.size.y * t), Vector2(c.size.x, c.size.y * (1.0 - t))))
	var g := minf(w, h) * 0.035
	var th := minf(w, h) * 0.05
	var BL := _vmat_solid(Color(0.03, 0.03, 0.035))
	for i in cells.size():
		var c: Rect2 = cells[i]
		var cw := c.size.x - g * 2.0
		var ch := c.size.y - g * 2.0
		if cw <= g or ch <= g:
			continue
		var cc := c.get_center()
		var m: Material = tones[rng.randi() % tones.size()]
		var z := th * (0.5 + rng.randf() * 0.6)
		_box(f, m, Vector3(cc.x, cc.y, z * 0.5), Vector3(cw, ch, z))
		var r := rng.randf()
		if r < 0.3:
			# 螺栓四角
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				_box(f, _steel(), Vector3(cc.x + q.x * (cw * 0.5 - g * 1.5), cc.y + q.y * (ch * 0.5 - g * 1.5), z + g * 0.3), Vector3(g, g, g * 0.6))
		elif r < 0.55:
			# 散热槽
			var nv := clampi(int(cw / (g * 4.0)), 2, 6)
			for v in nv:
				_box(f, BL, Vector3(cc.x - cw * 0.35 + v * cw * 0.7 / maxf(nv - 1, 1), cc.y, z + 0.002), Vector3(g * 1.2, ch * 0.55, g * 0.3))
		elif r < 0.72:
			# 浅色警示斜纹带
			_box(f, _vmat_matte(Color(0.78, 0.78, 0.8)), Vector3(cc.x, cc.y - ch * 0.3, z + 0.002), Vector3(cw * 0.9, ch * 0.12, g * 0.3))
		elif r < 0.82:
			_box(f, _glow(1.4), Vector3(cc.x, cc.y + ch * 0.35, z + 0.002), Vector3(cw * 0.7, g * 0.5, g * 0.3))


## 挤出棱柱：2D 多边形（XY 平面）沿 Z 挤出 depth，四周倒一圈斜角，用于盾形甲板、鳍片等异形硬表面
func _prism(parent: Node3D, pts: Array, depth: float, bev: float, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)
	var n := pts.size()
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= n
	var inner: Array = []
	for q in pts:
		inner.append(c + (q - c) * (1.0 - bev))
	var zf := depth * 0.5
	var zb := -depth * 0.5
	for i in n:
		var j := (i + 1) % n
		var o0: Vector2 = pts[i]
		var o1: Vector2 = pts[j]
		var i0: Vector2 = inner[i]
		var i1: Vector2 = inner[j]
		# 正面（内缩面）
		st.add_vertex(Vector3(c.x, c.y, zf)); st.add_vertex(Vector3(i0.x, i0.y, zf)); st.add_vertex(Vector3(i1.x, i1.y, zf))
		# 正面倒角
		var zm := zf - depth * 0.3
		st.add_vertex(Vector3(i0.x, i0.y, zf)); st.add_vertex(Vector3(o0.x, o0.y, zm)); st.add_vertex(Vector3(o1.x, o1.y, zm))
		st.add_vertex(Vector3(i0.x, i0.y, zf)); st.add_vertex(Vector3(o1.x, o1.y, zm)); st.add_vertex(Vector3(i1.x, i1.y, zf))
		# 侧面
		st.add_vertex(Vector3(o0.x, o0.y, zm)); st.add_vertex(Vector3(o0.x, o0.y, zb)); st.add_vertex(Vector3(o1.x, o1.y, zb))
		st.add_vertex(Vector3(o0.x, o0.y, zm)); st.add_vertex(Vector3(o1.x, o1.y, zb)); st.add_vertex(Vector3(o1.x, o1.y, zm))
		# 背面
		st.add_vertex(Vector3(c.x, c.y, zb)); st.add_vertex(Vector3(o1.x, o1.y, zb)); st.add_vertex(Vector3(o0.x, o0.y, zb))
	st.generate_normals()
	var mi := _p(parent, st.commit(), m, pos, rot)
	mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED if mi.material_override is BaseMaterial3D else 0
	return mi


## 蝎狮式高抬腿：髋 → 股节斜向上抬到高过机身的膝 → 胫节斜插地面，股节外侧覆大块锯齿阶梯甲板
func _tleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, s: float, by: float, phase: float, ss := 1.0) -> Node3D:
	# 蝎狮盾状足：髋 → 高抬的膝 → 几乎垂直落地的胫节；膝外侧挂一面与机体等高的风筝形分鳞大盾（盾面朝外），
	# 盾面 2×3 凸起鳞板（侧看呈锯齿），顶端暗色尖兜帽带一道紫光，盾下端露出尖足
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0, yaw, 0)
	body.add_child(hip)
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var LT := _vmat_matte(Color(0.2, 0.2, 0.22))
	var LT2 := _vmat_matte(Color(0.52, 0.52, 0.55))
	var knee := Vector3(sx * 0.9 * s, 0.8 * s * ss, 0)
	var foot := Vector3(sx * 1.38 * s, -by + 0.02, 0)
	var ank := foot + Vector3(0, 0.32 * s, 0)
	_servo(hip, Vector3.ZERO, 0.15 * s)
	_box(hip, DK, Vector3(sx * 0.05 * s, 0, 0), Vector3(0.22, 0.24, 0.3) * s)
	for zz: float in [-0.08, 0.08]:
		_bar(hip, Vector3(0, 0, zz * s), knee + Vector3(0, 0, zz * s), 0.1 * s, 0.15 * s, DK)
	_seg(hip, Vector3(sx * 0.08 * s, -0.12 * s, 0), knee + Vector3(-sx * 0.14 * s, -0.1 * s, 0), 0.05 * s, 0.035 * s, _steel(), 6)
	_servo(hip, knee, 0.15 * s)
	_bar(hip, knee, ank, 0.14 * s, 0.16 * s, DK)
	_seg(hip, knee + Vector3(-sx * 0.1, -0.08, 0.1) * s, ank + Vector3(-sx * 0.06, 0.06, 0.1) * s, 0.04 * s, 0.03 * s, _steel(), 6)
	# 足：暗色足靴 + 切角底板（纯机械）
	_box(hip, DK, ank + Vector3(0, -0.06 * s, 0), Vector3(0.2, 0.26, 0.24) * s)
	_box(hip, AR, foot + Vector3(0, 0.03 * s, 0), Vector3(0.26, 0.06, 0.36) * s)
	# 大盾：挂在膝外侧，盾面朝外（沿腿方向），顶部向内后仰
	var sh := Node3D.new()
	sh.position = Vector3(sx * 1.36 * s, (0.3 + 0.05 * ss) * s, 0)
	sh.rotation_degrees = Vector3(0, 90.0 * sx, 0)
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(-12, 0, 0)
	tilt.scale = Vector3.ONE * ss
	sh.add_child(tilt)
	hip.add_child(sh)
	# 泪滴/风筝盾：上端尖顶，最宽处在上三分之一，向下收成窄尖底；轮廓用多段折线保持硬表面切面感
	var hw := func(y: float) -> float:
		if y >= 0.3:
			return 0.5 * pow(maxf(1.18 - y, 0.0) / 0.88, 0.75)
		return 0.07 + 0.43 * (1.0 - pow((0.3 - y) / 1.3, 1.7))
	var ys := [1.18, 1.0, 0.78, 0.55, 0.3, 0.0, -0.3, -0.58, -0.82, -1.0]
	var ks: Array = []
	var inner: Array = []
	for y: float in ys:
		ks.append(Vector2(hw.call(y), y) * s)
		inner.append(Vector2(hw.call(y) * 0.8, y * 0.9) * s)
	for i in range(ys.size() - 1, -1, -1):
		var y: float = ys[i]
		if hw.call(y) > 0.001:
			ks.append(Vector2(-hw.call(y), y) * s)
			inner.append(Vector2(-hw.call(y) * 0.8, y * 0.9) * s)
	_prism(tilt, ks, 0.2 * s, 0.05, LT, Vector3.ZERO)
	_prism(tilt, inner, 0.14 * s, 0.05, DK, Vector3(0, 0, -0.16 * s))
	_box(tilt, DK, Vector3(0, 0.0, 0.105 * s), Vector3(0.05, 1.7, 0.02) * s)
	# 分鳞：四排人字形板，宽度随盾轮廓收窄
	for r in 4:
		var cy0 := 0.5 - r * 0.33
		var w: float = hw.call(cy0) * 0.42
		for kx: float in [-1.0, 1.0]:
			var cx: float = kx * (w + 0.035) * s
			var cy := cy0 * s
			_prism(tilt, [Vector2(-w, -0.12) * s, Vector2(w, -0.1) * s, Vector2(w + 0.03, 0.1) * s, Vector2(-w + 0.02, 0.12) * s], 0.14 * s, 0.1, LT2 if (r + int(kx > 0)) % 2 == 0 else _vmat_matte(Color(0.33, 0.3, 0.39)),
				Vector3(cx, cy, 0.14 * s), Vector3(6, 0, -kx * 16.0))
			_box(tilt, DK, Vector3(cx + kx * 0.02 * s, cy + 0.02 * s, 0.215 * s), Vector3(w * 0.85, 0.008, 0.004) * s, Vector3(0, 0, kx * 4.0))
	for k in 3:
		_p(tilt, A.cyl(0.025 * s, 0.01 * s, 0.025 * s, 10), DK, Vector3((-0.09 + k * 0.09) * s, -0.72 * s, 0.105 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	_prism(tilt, [Vector2(0, 1.24) * s, Vector2(0.24, 0.92) * s, Vector2(0.3, 0.68) * s, Vector2(-0.3, 0.68) * s, Vector2(-0.24, 0.92) * s], 0.14 * s, 0.08, _vmat_matte(Color(0.12, 0.12, 0.135)), Vector3(0, 0, 0.1 * s))
	_box(tilt, _glow(1.2), Vector3(0, 0.92 * s, 0.175 * s), Vector3(0.04, 0.4, 0.01) * s)
	# 盾背连接臂（与膝相连）
	_bar(hip, knee, Vector3(sx * 1.28 * s, 0.45 * s, 0), 0.12 * s, 0.12 * s, AR)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


## 酸液虫：仿少女前线「蝎狮 Manticore」。正面是与机体等高、上端后仰的风筝形分鳞胸甲（下端尖角垂到地面），
## 胸甲右后方压着方形头舱（通风格栅 + 分层顶甲），头舱下方长身管主炮沿机体右侧前伸，尾部斜立背鳍，
## 四条膝部高抬的蛛腿，股节外侧覆阶梯锯齿大甲板。暗灰金属，紫色装饰线。
func _build_spitter(body: Node3D, s: float) -> void:
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var TR := _glow(1.8)
	var by := 0.75 * s
	var GX := 0.36 * s
	var BL := _vmat_solid(Color(0.03, 0.03, 0.035))
	# 船体：侧视六边形斜切硬壳（沿 X 挤出，前低后高），两侧裙甲 + 一道紫色腰线
	var side := func(pts: Array) -> Array:
		var o: Array = []
		for q in pts:
			o.append(q * s)
		return o
	_prism(body, side.call([Vector2(0.55, -0.05), Vector2(0.35, 0.35), Vector2(-0.1, 0.55), Vector2(-0.6, 0.45), Vector2(-0.65, 0.0), Vector2(-0.35, -0.28), Vector2(0.3, -0.28)]),
		0.62 * s, 0.06, DK, Vector3(0, by + 0.25 * s, 0.05 * s), Vector3(0, 90, 0))
	for sx: float in [-1.0, 1.0]:
		_prism(body, side.call([Vector2(0.4, -0.1), Vector2(0.2, 0.25), Vector2(-0.45, 0.32), Vector2(-0.55, -0.05), Vector2(-0.3, -0.22), Vector2(0.25, -0.22)]),
			0.06 * s, 0.1, AR, Vector3(sx * 0.33 * s, by + 0.25 * s, 0.08 * s), Vector3(0, 90, 0))
		_box(body, TR, Vector3(sx * 0.365 * s, by + 0.37 * s, 0.1 * s), Vector3(0.008, 0.012, 0.55) * s, Vector3(-6, 0, 0))
		_panels(body, Vector3(sx * 0.37 * s, by + 0.3 * s, 0.1 * s), Vector3(0, 90 * sx, 0), 0.7 * s, 0.32 * s, 31 + int(sx), 4)
		# 侧裙检修板 + 螺栓
		_box(body, BL, Vector3(sx * 0.364 * s, by + 0.21 * s, 0.2 * s), Vector3(0.006, 0.12, 0.22) * s)
		for k in 3:
			_box(body, _steel(), Vector3(sx * 0.366 * s, by + 0.11 * s, (0.05 + k * 0.12) * s), Vector3(0.01, 0.025, 0.025) * s)
	# 楔形头舱：前端楔形装甲，顶部两层叠甲后掠，两侧格栅
	var head := Node3D.new()
	head.position = Vector3(GX * 0.6, by + 0.5 * s, -0.4 * s)
	head.scale = Vector3.ONE * 1.25
	head.rotation_degrees = Vector3(0, -10, 0)
	body.add_child(head)
	_prism(head, side.call([Vector2(0.75, 0.0), Vector2(0.45, 0.32), Vector2(-0.05, 0.42), Vector2(-0.15, 0.05), Vector2(0.35, -0.16)]), 0.4 * s, 0.06, DK, Vector3.ZERO, Vector3(0, 90, 0))
	_prism(head, side.call([Vector2(0.55, 0.3), Vector2(0.3, 0.46), Vector2(-0.12, 0.5), Vector2(-0.12, 0.38), Vector2(0.4, 0.3)]), 0.46 * s, 0.08, AR, Vector3.ZERO, Vector3(0, 90, 0))
	_prism(head, side.call([Vector2(0.3, 0.47), Vector2(0.12, 0.56), Vector2(-0.2, 0.58), Vector2(-0.2, 0.48)]), 0.3 * s, 0.1, DK, Vector3.ZERO, Vector3(0, 90, 0))
	for sx: float in [-1.0, 1.0]:
		for k in 4:
			_box(head, BL, Vector3(sx * 0.205 * s, 0.12 * s, (-0.05 - k * 0.07) * s), Vector3(0.01, 0.14, 0.03) * s)
		_box(head, TR, Vector3(sx * 0.235 * s, 0.32 * s, -0.15 * s), Vector3(0.008, 0.01, 0.5) * s, Vector3(-12, 0, 0))
	for j in 2:
		var jaw := Node3D.new()
		jaw.position = Vector3((j * 2 - 1) * 0.1 * s, -0.12 * s, -0.4 * s)
		head.add_child(jaw)
		jaws.append(jaw)
	sac = _box(body, DK, Vector3(0, by - 0.1 * s, 0.2 * s), Vector3(0.36, 0.3, 0.5) * s)
	# 顶部长背甲：从头舱后上方斜升到尾部背鳍，两层（亮灰主板 + 暗色顶盖 + 侧裙）
	var d0 := Vector3(GX * 0.7, by + 0.92 * s, -0.3 * s)
	var d1 := Vector3(-0.05 * s, by + 1.2 * s, 0.5 * s)
	_bar(body, d0, d1, 0.56 * s, 0.2 * s, AR)
	_bar(body, d0 + Vector3(0, 0.12 * s, 0.05 * s), d1 + Vector3(0, 0.12 * s, 0), 0.4 * s, 0.07 * s, DK)
	for sx: float in [-1.0, 1.0]:
		_bar(body, d0 + Vector3(sx * 0.3 * s, -0.08 * s, 0.05 * s), d1 + Vector3(sx * 0.3 * s, -0.1 * s, -0.05 * s), 0.05 * s, 0.22 * s, DK)
	_box(body, TR, d1 + Vector3(0, 0.16 * s, -0.3 * s), Vector3(0.012, 0.012, 0.5) * s, Vector3(-20, 0, 0))
	# 尾部散热器
	var fin := [Vector2(0, 0), Vector2(0.3, 0), Vector2(0.85, 0.95), Vector2(0.75, 1.05), Vector2(0.05, 0.3)]
	var fs: Array = []
	for q in fin:
		fs.append(q * s)
	# 尾部散热器箱（取代背鳍）：箱体 + 四片竖向散热片
	_box(body, AR, Vector3(-0.08 * s, by + 1.28 * s, 0.6 * s), Vector3(0.3, 0.26, 0.36) * s)
	for k in 4:
		_box(body, DK, Vector3((-0.2 + k * 0.08) * s, by + 1.44 * s, 0.6 * s), Vector3(0.03, 0.1, 0.32) * s)
	_box(body, DK, Vector3(-0.12 * s, by + 0.66 * s, 0.45 * s), Vector3(0.12, 0.16, 0.22) * s)
	# 主炮：头舱下方、沿机体右侧前伸的长身管炮（加长机匣 + 前护套 + 三道箍 + 炮口制退器）
	var GM := StandardMaterial3D.new()
	GM.albedo_color = Color(0.2, 0.2, 0.23)
	GM.metallic = 0.85
	GM.roughness = 0.3
	gun = Node3D.new()
	gun.name = "Gun"
	body.add_child(gun)
	var g0 := Vector3(GX, by - 0.02 * s, -0.4 * s)
	# 机匣：长条斜切壳 + 上部导轨 + 下部弹仓 + 侧面散热孔
	_prism(gun, side.call([Vector2(0.7, -0.12), Vector2(0.7, 0.1), Vector2(0.45, 0.16), Vector2(-0.55, 0.16), Vector2(-0.6, -0.12), Vector2(-0.3, -0.2), Vector2(0.4, -0.2)]),
		0.3 * s, 0.06, AR, g0, Vector3(0, 90, 0))
	_box(gun, DK, g0 + Vector3(0, 0.2 * s, 0.0), Vector3(0.16, 0.06, 1.1) * s)
	_box(gun, DK, g0 + Vector3(0, -0.26 * s, 0.2 * s), Vector3(0.22, 0.14, 0.45) * s)
	for k in 6:
		_box(gun, BL, g0 + Vector3(0.152 * s, 0.0, (-0.45 + k * 0.1) * s), Vector3(0.006, 0.1, 0.04) * s)
	_box(gun, TR, g0 + Vector3(0.155 * s, 0.11 * s, 0), Vector3(0.006, 0.012, 1.1) * s)
	var b0 := g0 + Vector3(0, 0.0, -0.7 * s)
	var b1 := b0 + Vector3(0, 0, -2.0 * s)
	# 炮管：前护套 + 多道套环 + 中段散热套 + 方形炮口制退器
	_box(gun, DK, b0 + Vector3(0, 0, -0.3 * s), Vector3(0.24, 0.22, 0.6) * s)
	for k in 4:
		_box(gun, AR, b0 + Vector3(0, 0, (-0.06 - k * 0.17) * s), Vector3(0.28, 0.26, 0.06) * s)
	_p(gun, A.cyl(0.08 * s, 2.0 * s, 0.08 * s, 14), GM, (b0 + b1) * 0.5, Vector3(90, 0, 0))
	_p(gun, A.cyl(0.11 * s, 0.6 * s, 0.11 * s, 10), GM, b0 + Vector3(0, 0, -1.0 * s), Vector3(90, 0, 0))
	for k in 5:
		_p(gun, A.cyl(0.118 * s, 0.03 * s, 0.118 * s, 10), _steel(), b0 + Vector3(0, 0, (-0.75 - k * 0.12) * s), Vector3(90, 0, 0))
	for k in 3:
		_p(gun, A.cyl(0.1 * s, 0.035 * s, 0.1 * s, 12), _steel(), b0 + Vector3(0, 0, (-1.45 - k * 0.18) * s), Vector3(90, 0, 0))
	var mz := b1 + Vector3(0, 0, 0.1 * s)
	_box(gun, DK, mz, Vector3(0.24, 0.2, 0.3) * s)
	for k in 2:
		for sx: float in [-1.0, 1.0]:
			_box(gun, BL, mz + Vector3(sx * 0.121 * s, 0, (-0.06 + k * 0.12) * s), Vector3(0.004, 0.12, 0.05) * s)
	_p(gun, A.cyl(0.075 * s, 0.01 * s, 0.075 * s, 12), BL, mz + Vector3(0, 0, -0.152 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	_p(gun, A.cyl(0.04 * s, 0.012 * s, 0.04 * s, 10), _glow(1.0), mz + Vector3(0, 0, -0.15 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	gun_tip = Node3D.new()
	gun_tip.position = mz + Vector3(0, 0, -0.3 * s)
	gun.add_child(gun_tip)
	gun_glow = _p(gun, A.cyl(0.06 * s, 0.02 * s, 0.06 * s, 10), _glow(0.0), mz + Vector3(0, 0, -0.16 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	# 四条高抬蛛腿：前腿向前外伸、后腿向后外伸
	var hp := [Vector3(0.28, 0.05, -0.1), Vector3(0.28, 0.0, 0.32)]
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			var h: Vector3 = hp[i]
			_tleg(body, Vector3(sx * h.x * s, by + h.y * s, h.z * s), sx * (35.0 - i * 85.0), sx, s, by + h.y * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.0 - i * 0.12)


## 攻城虫：铁血重型破城机。低宽六边形底盘，正面五层人字形楔板堆成破城冲角（层间紫色狭缝），
## 冲角顶端嵌三目传感器；两侧液压破碎钳臂；后部高耸反应堆塔（竖向散热鳍 + 两根后倾排气管）；
## 六条短粗活塞腿 + 宽扁足垫。与炮击虫（盾状足 + 长炮）、跳虫（Γ 护壳 + 独眼）不雷同。
func _pleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, s: float, by: float, phase: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0, yaw, 0)
	body.add_child(hip)
	var DK := _vmat_solid(C_CH)
	var AR := _vmat_solid(C_CH2)
	var knee := Vector3(sx * 0.5 * s, 0.22 * s, 0)
	var foot := Vector3(sx * 0.62 * s, -by + 0.01, 0)
	_servo(hip, Vector3.ZERO, 0.16 * s)
	_bar(hip, Vector3.ZERO, knee, 0.2 * s, 0.22 * s, DK)
	_bar(hip, Vector3(0, 0.13 * s, 0), knee + Vector3(0, 0.13 * s, 0), 0.26 * s, 0.05 * s, AR)
	_servo(hip, knee, 0.13 * s)
	# 活塞胫：外套筒（方）+ 内伸缩钢柱 + 足垫
	var mid := Vector3(foot.x, knee.y - 0.32 * s, 0)
	_bar(hip, knee, mid, 0.2 * s, 0.2 * s, AR, Vector3.FORWARD)
	_box(hip, _glow(1.6), mid + Vector3(sx * 0.101 * s, 0.12 * s, 0), Vector3(0.006, 0.18, 0.02) * s)
	_p(hip, A.cyl(0.06 * s, mid.y - foot.y, 0.06 * s, 10), _steel(), Vector3(foot.x, (mid.y + foot.y) * 0.5, 0))
	_p(hip, A.cyl(0.13 * s, 0.07 * s, 0.17 * s, 6), DK, foot + Vector3(0, 0.035 * s, 0))
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


func _build_brute(body: Node3D, s: float) -> void:
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var LT := _vmat_matte(Color(0.5, 0.5, 0.53))
	var BL := _vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.62 * s
	# 六边形底盘（俯视）+ 上层甲板
	_prism(body, [Vector2(-0.5, -0.6) * s, Vector2(0.5, -0.6) * s, Vector2(0.66, 0.0) * s, Vector2(0.52, 0.72) * s, Vector2(-0.52, 0.72) * s, Vector2(-0.66, 0.0) * s],
		0.34 * s, 0.06, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	_prism(body, [Vector2(-0.38, -0.4) * s, Vector2(0.38, -0.4) * s, Vector2(0.48, 0.05) * s, Vector2(0.4, 0.62) * s, Vector2(-0.4, 0.62) * s, Vector2(-0.48, 0.05) * s],
		0.16 * s, 0.08, AR, Vector3(0, by + 0.24 * s, 0), Vector3(90, 0, 0))
	_panels(body, Vector3(0, by + 0.32 * s + 0.005, 0.05 * s), Vector3(-90, 0, 0), 0.62 * s, 0.7 * s, 21, 6)
	for sx: float in [-1.0, 1.0]:
		_panels(body, Vector3(sx * 0.6 * s, by, 0.36 * s), Vector3(0, 90 * sx, 0), 0.5 * s, 0.26 * s, 22 + int(sx), 3)
	for sx: float in [-1.0, 1.0]:
		_box(body, _glow(1.8), Vector3(sx * 0.66 * s, by, 0.0), Vector3(0.006, 0.02, 0.5) * s)
		for k in 4:
			_box(body, _steel(), Vector3(sx * 0.61 * s, by - 0.1 * s, (-0.15 + k * 0.12) * s), Vector3(0.012, 0.03, 0.03) * s)
	# 破城冲角：五层人字形楔板，越往上越窄、越靠后，整体后仰
	var ram := Node3D.new()
	ram.position = Vector3(0, by - 0.2 * s, -0.68 * s)
	ram.rotation_degrees = Vector3(-28, 0, 0)
	body.add_child(ram)
	for r in 5:
		var w := 0.78 - r * 0.1
		var y := r * 0.17
		_prism(ram, [Vector2(-w, 0.06) * s, Vector2(-w, -0.04) * s, Vector2(0, -0.2) * s, Vector2(w, -0.04) * s, Vector2(w, 0.06) * s, Vector2(0, -0.1) * s],
			0.22 * s, 0.1, LT if r % 2 == 0 else AR, Vector3(0, y * s, 0))
		if r < 4:
			_prism(ram, [Vector2(-w * 0.8, 0.09) * s, Vector2(0, -0.06) * s, Vector2(w * 0.8, 0.09) * s, Vector2(w * 0.8, 0.098) * s, Vector2(0, -0.052) * s, Vector2(-w * 0.8, 0.098) * s],
				0.02 * s, 0.0, _glow(0.9), Vector3(0, y * s, -0.08 * s))
		for sx: float in [-1.0, 1.0]:
			_box(ram, DK if r % 2 == 0 else _vmat_matte(Color(0.3, 0.305, 0.325)), Vector3(sx * w * 0.52 * s, (y - 0.06) * s, -0.112 * s), Vector3(w * 0.55, 0.05, 0.012) * s, Vector3(0, 0, sx * 11.0))
			_box(ram, _steel(), Vector3(sx * w * 0.88 * s, (y + 0.01) * s, -0.115 * s), Vector3(0.03, 0.03, 0.012) * s)
			_box(ram, BL, Vector3(sx * w * 0.5 * s, (y - 0.03) * s, -0.115 * s), Vector3(0.05, 0.035, 0.01) * s, Vector3(0, 0, sx * 14.0))
	_panels(body, Vector3(0, by - 0.05 * s, -0.6 * s - 0.005), Vector3(0, 180, 0), 0.9 * s, 0.2 * s, 27, 3)
	_box(ram, DK, Vector3(0, 0.36 * s, -0.12 * s), Vector3(0.08, 0.8, 0.03) * s)
	# 冲角顶部三目传感器
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.42 * s, -0.42 * s)
	body.add_child(head)
	_prism(head, [Vector2(-0.2, 0) * s, Vector2(0.2, 0) * s, Vector2(0.15, 0.12) * s, Vector2(-0.15, 0.12) * s], 0.3 * s, 0.08, DK, Vector3.ZERO)
	# 两侧液压破碎钳
	for sx: float in [-1.0, 1.0]:
		var sc := Node3D.new()
		sc.position = Vector3(sx * 0.58 * s, by + 0.08 * s, -0.42 * s)
		body.add_child(sc)
		_servo(sc, Vector3.ZERO, 0.15 * s)
		var el := Vector3(sx * 0.2, -0.05, -0.38) * s
		_bar(sc, Vector3.ZERO, el, 0.17 * s, 0.2 * s, AR)
		_seg(sc, Vector3(0, 0.12 * s, 0.05 * s), el + Vector3(0, 0.1 * s, 0), 0.035 * s, 0.03 * s, _steel(), 6)
		_servo(sc, el, 0.11 * s)
		var wr := el + Vector3(-sx * 0.06, -0.12, -0.32) * s
		_bar(sc, el, wr, 0.15 * s, 0.17 * s, DK)
		_box(sc, LT, wr + Vector3(0, 0.0, 0.08 * s), Vector3(0.22, 0.2, 0.12) * s)
		for j: float in [-1.0, 1.0]:
			_prism(sc, [Vector2(0, -0.06) * s, Vector2(0.2, -0.03) * s, Vector2(0.27, 0.05) * s, Vector2(0.17, 0.03) * s, Vector2(0, 0.06) * s],
				0.07 * s, 0.2, DK, wr + Vector3(j * 0.06 * s, 0, 0), Vector3(0, 90, j * 18.0))
		scythes.append(sc)
	# 后部反应堆塔：竖向散热鳍 + 发光堆芯 + 两根后倾排气管
	var rc := Vector3(0, by + 0.42 * s, 0.4 * s)
	_prism(body, [Vector2(-0.3, -0.16) * s, Vector2(0.3, -0.16) * s, Vector2(0.24, 0.34) * s, Vector2(-0.24, 0.34) * s], 0.4 * s, 0.06, DK, rc)
	_panels(body, rc + Vector3(0, 0.09 * s, -0.205 * s), Vector3(0, 180, 0), 0.5 * s, 0.44 * s, 25, 4)
	for sx: float in [-1.0, 1.0]:
		_panels(body, rc + Vector3(sx * 0.28 * s, 0.09 * s, 0), Vector3(-0, 90 * sx, 6 * sx), 0.36 * s, 0.4 * s, 26 + int(sx), 3)
	for k in 5:
		_box(body, AR, rc + Vector3((-0.2 + k * 0.1) * s, 0.1 * s, 0.22 * s), Vector3(0.03, 0.4, 0.08) * s)
	sac = _p(body, A.cyl(0.11 * s, 0.32 * s, 0.11 * s, 8), _flesh(Color(0.55, 0.15, 0.7), 0.9), rc + Vector3(0, 0.08 * s, -0.12 * s))
	_p(body, A.cyl(0.13 * s, 0.04 * s, 0.13 * s, 8), _steel(), rc + Vector3(0, 0.26 * s, -0.12 * s))
	for sx: float in [-1.0, 1.0]:
		var e0 := rc + Vector3(sx * 0.2 * s, 0.25 * s, 0.05 * s)
		_p(body, A.cyl(0.05 * s, 0.4 * s, 0.06 * s, 8), AR, e0 + Vector3(0, 0.15 * s, 0.06 * s), Vector3(18, 0, 0))
		_p(body, A.cyl(0.04 * s, 0.01 * s, 0.04 * s, 8), BL, e0 + Vector3(0, 0.35 * s, 0.125 * s), Vector3(18, 0, 0), Vector3.ONE, false)
	# 六条活塞腿（三角步态）
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			_pleg(body, Vector3(sx * 0.55 * s, by - 0.08 * s, (-0.35 + i * 0.42) * s), sx * (-25.0 + i * 25.0), sx, s, by - 0.08 * s,
				float(i % 2) * PI + (PI if sx > 0 else 0.0))


static func _vmat_matte(c: Color) -> StandardMaterial3D:
	var key := "vm%s" % c.to_html()
	if _sm.has(key):
		return _sm[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.metallic = 0.55
	m.rim_enabled = true
	m.rim = 0.2
	_panelize(m)
	_sm[key] = m
	return m


static func _vmat_solid(c: Color) -> StandardMaterial3D:
	var key := "vs%s" % c.to_html()
	if _sm.has(key):
		return _sm[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.26
	m.metallic = 0.6
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.15
	m.rim_enabled = true
	m.rim = 0.3
	_panelize(m)
	_sm[key] = m
	return m


## 被噪音惊动（机甲开火、空投落地）：转入追击，目标是机甲
func alert(pos: Vector3) -> void:
	if state == "idle":
		if raid and _alive(raid.mech):
			target = raid.mech
			# 机甲远在丢失距离外（远处的空投、诱饵信标）：不扑机甲，只去声源处查看
			if global_position.distance_to(raid.mech.global_position) > _lose_dist():
				target = null
				_set_investigate(pos)
				return
		state = "chase"
		# 听到动静：朝声源方向搜过去，多给几秒「看不见也继续找」的宽限，找不到就去声源处查看
		last_seen = pos
		_unseen_t = -NOISE_GRACE
		_alert_pack(target)


# ================= 感知 / 巡逻 / LOD =================
## 虫群：一群里第一只是群首，其余成员跟在群首身后的固定站位上；群首在领地（home 周围 territory 米）里挑路点巡逻。
## 视野：目标（机甲、战斗队友、流浪者）在察觉距离内、且胸口高度的视线没被静态地形挡住，才算「看见」→ 整群转入追击。
##   察觉距离 = raid.scaled_aggro(数据表 aggro)，封顶 raid.vision_range()（玩家视野 × 0.9）；看玩家机甲时再按屏幕方向收紧。
## 受击锁定：被谁打就锁定谁（玩家子弹记为机甲），无视视野一路追，直到拉开到 raid.lose_range()（视野 × 1.5）才丢失；同群被叫醒的成员同样锁定。
## 没锁定的追击：目标离开视线超过 UNSEEN_GIVEUP 秒或拉开到 lose_range → 丢失。丢失后先去最后看见目标的位置查看几秒，再回到巡逻。
## 追击移动：直线可走就直线扑，被建筑挡住就沿导航网格（raid.nav）的 A* 路径绕；近处追击的虫之间有轻微的分离避让。
## LOD：离玩家机甲越远 AI 越低频（near：逐帧 / mid：10Hz / far：2Hz），远处不跑程序动画，移动用累计步长一次 move_and_slide。
const LEASH := 55.0             ## 没有 raid（单独测试模型）时的后备丢失距离
const UNSEEN_GIVEUP := 4.0      ## 没锁定的目标脱离视线多久后放弃
const NOISE_GRACE := 3.0        ## 听到动静赶过去时额外的搜索宽限（秒）
const INVESTIGATE_T := 5.0      ## 丢失目标后在最后位置附近查看的时长
const LOD_NEAR := 55.0
const LOD_MID := 95.0
var pack_leader = null          ## 群首节点；null 表示自己就是群首（或散兵）
var pack: Array = []            ## 群首持有的成员列表
var follow_off := Vector3.ZERO  ## 跟随站位（群首局部坐标）
var territory := 30.0           ## 巡逻半径
var patrol_speed := 0.4         ## 巡逻速度（相对自身全速）
var aggressor = null            ## 最近一次打中自己的单位（流浪者 / 队友 / 机甲）
var lod := 0                    ## 0 近 / 1 中 / 2 远
var detail: Array = []          ## 中远距离隐藏的小零件
var _detail_on := true
var _lod_acc := 0.0
var _perc_t := 0.0
var _wait_t := 0.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var lock_target = null          ## 受击锁定的目标（与 target 相同时视为锁定追击）
var last_seen := Vector3.INF    ## 最后一次看见（或听见）目标的位置
var _unseen_t := 0.0
var _investigate := Vector3.INF
var _investigate_t := 0.0
var _chase_stuck_t := 0.0
var _chase_stuck_pos := Vector3.ZERO
var nav_agent = preload("res://scripts/nav_grid.gd").Agent.new()
var _aggro_scaled := false
var target_los := true          ## 最近一次感知时与当前目标之间有没有视线


static func _alive(n) -> bool:
	return is_instance_valid(n) and n.get("dead") != true and n.get("dying") != true


## 本帧要模拟的时间：近处返回 delta；中远处累计到节拍才返回累计值，其余帧返回 0（跳过）
func _lod_dt(delta: float) -> float:
	var busy: bool = act != "" or spawn_t > 0.0 or flash_t > 0.0
	var d2 := 0.0
	if raid and is_instance_valid(raid.mech):
		d2 = global_position.distance_squared_to(raid.mech.global_position)
	if busy or d2 < LOD_NEAR * LOD_NEAR:
		lod = 0
	elif d2 < LOD_MID * LOD_MID or state == "chase":
		lod = 1
	else:
		lod = 2
	var want_detail := lod == 0
	if want_detail != _detail_on:
		_detail_on = want_detail
		for mi in detail:
			if is_instance_valid(mi):
				mi.visible = want_detail
	if lod == 0:
		if _lod_acc > 0.0:
			delta += _lod_acc
			_lod_acc = 0.0
		return delta
	_lod_acc += delta
	var step := 0.1 if lod == 1 else 0.5
	if _lod_acc < step:
		return 0.0
	var dt := minf(_lod_acc, 0.6)
	_lod_acc = 0.0
	return dt


## 一次 move_and_slide 走完 dt：低频更新时按比例放大速度，碰撞照常结算。
## 画面外（LOD 中 / 远）闲逛巡逻的虫不跑物理：直接平移，只用建筑占地格子挡一下（撞上就换路点），省掉绝大部分 move_and_slide
func _slide(dt: float) -> void:
	if lod > 0 and state == "idle" and act == "" and raid and raid.has_method("ai_free"):
		var step := Vector3(velocity.x, 0.0, velocity.z) * dt
		if step.length_squared() < 0.0001:
			return
		var np := global_position + step
		if raid.ai_free(np, float(data.radius)) and absf(np.x) < raid.HALF - 4.0 and absf(np.z) < raid.HALF - 4.0:
			global_position = np
			return
		# 自己已经压在不可走格子里（网格带通行间隙，比实际碰撞体略大）：走真实物理挤出去，否则会永远卡在原地
		if raid.ai_free(global_position, float(data.radius)):
			wander_to = Vector3.ZERO
			return
	var pd := get_physics_process_delta_time()
	if pd > 0.0 and dt > pd * 1.5:
		var k := dt / pd
		velocity.x *= k
		velocity.z *= k
		move_and_slide()
		velocity.x /= k
		velocity.z /= k
	else:
		move_and_slide()


func _perceive_period() -> float:
	return 0.25 if lod == 0 else (0.5 if lod == 1 else 1.0)


## 察觉距离：第一次用到时按视野换算数据表的 aggro（setup 时 raid 的镜头还没建好）
func _sight() -> float:
	if not _aggro_scaled and raid and raid.has_method("scaled_aggro") and raid.camera != null:
		_aggro_scaled = true
		aggro_range = raid.scaled_aggro(aggro_range)
	return aggro_range


func _lose_dist() -> float:
	return raid.lose_range() if raid and raid.has_method("lose_range") else LEASH


## 能否看见 f（距离 d）：在察觉距离内（对玩家机甲按屏幕方向收紧）且视线不被地形挡住
func _can_see(f, d: float) -> bool:
	var r := _sight()
	if r <= 0.0 or d >= r:
		return false
	if raid == null or not raid.has_method("has_los"):
		return true
	if f == raid.mech and d >= raid.vision_toward_player(global_position):
		return false
	return raid.has_los(global_position, f.global_position)


## 感知：在可敌对单位（机甲 + 队友 + 流浪者，由 raid.bug_foes() 提供，数量很少）里挑目标。
## 射线只对察觉距离内的候选打，按 LOD 节拍（0.25 / 0.5 / 1 秒）一次，150 只虫里真正打射线的只有近处几只
func _perceive() -> void:
	if raid == null or bool(data.get("boss", false)):
		return
	var foes: Array = raid.bug_foes() if raid.has_method("bug_foes") else ([raid.mech] if raid.mech else [])
	var p := global_position
	var lose := _lose_dist()
	var period := _perceive_period()
	if state == "chase":
		var best = target if _alive(target) else null
		var bd := INF
		if best != null:
			bd = p.distance_to(best.global_position)
			if bd > lose:
				best = null
				bd = INF
			elif best != lock_target:
				# 没锁定：要一直看得见，脱离视线太久就放弃
				target_los = _can_see(best, bd)
				if target_los:
					_unseen_t = 0.0
					last_seen = best.global_position
				else:
					_unseen_t += period
					if _unseen_t > UNSEEN_GIVEUP:
						best = null
						bd = INF
			else:
				last_seen = best.global_position
				# 锁定追击不需要视线，但远程虫要知道隔没隔着墙（隔墙不开火、先绕过去）
				target_los = bd < 30.0 and raid.has_method("has_los") and raid.has_los(p, best.global_position)
		for f in foes:
			if f == best or not _alive(f):
				continue
			var d := p.distance_to(f.global_position)
			if d < bd - 6.0 and _can_see(f, d):
				best = f
				bd = d
				_unseen_t = 0.0
				target_los = true
				last_seen = f.global_position
		if _alive(aggressor) and aggressor != best:
			var da := p.distance_to(aggressor.global_position)
			if da < lose and (best == null or da < bd + 4.0):
				best = aggressor
				lock_target = aggressor
		if best == null:
			_lose_target()
		else:
			if best != target:
				nav_agent.reset()
			target = best
		return
	if aggro_range <= 0.0:
		return
	var pick = null
	var pd := _sight()
	for f in foes:
		if not _alive(f):
			continue
		var d := p.distance_to(f.global_position)
		if d < pd and _can_see(f, d):
			pd = d
			pick = f
	if pick == null and _alive(aggressor) and p.distance_to(aggressor.global_position) < lose:
		pick = aggressor
		lock_target = aggressor
	if pick != null:
		target = pick
		state = "chase"
		target_los = pick != lock_target
		_unseen_t = 0.0
		last_seen = pick.global_position
		nav_agent.reset()
		_alert_pack(pick, pick == lock_target)
	else:
		target = null


## 一只发现目标，40 米内闲着的同群成员一起扑上去；lock 时成员也一起锁定（受击叫醒的整群都追到 1.5 倍视野外才放弃）
func _alert_pack(tgt, lock := false) -> void:
	if not _alive(tgt):
		return
	var lead = pack_leader if _alive(pack_leader) else self
	var members: Array = lead.pack.duplicate()
	members.append(lead)
	for m in members:
		if m == self or not _alive(m):
			continue
		if m.global_position.distance_to(global_position) >= 40.0:
			continue
		if m.state == "idle":
			m.target = tgt
			m.state = "chase"
			m._unseen_t = 0.0
			m.last_seen = tgt.global_position
			m.nav_agent.reset()
			if lock:
				m.lock_target = tgt
		elif lock and m.target == tgt:
			m.lock_target = tgt


## 受击：锁定打自己的单位（玩家的子弹记为机甲），无视视野追击。已经锁定着另一个活目标时不换，免得来回扭头
func _aggro_on_hit() -> void:
	var atk = aggressor if _alive(aggressor) else (raid.mech if raid and _alive(raid.mech) else null)
	if atk == null:
		return
	if state == "chase" and _alive(target) and target == lock_target and target != atk:
		return
	if raid and global_position.distance_to(atk.global_position) > _lose_dist():
		return
	if target != atk:
		nav_agent.reset()
	target = atk
	lock_target = atk
	last_seen = atk.global_position
	_unseen_t = 0.0
	state = "chase"
	_alert_pack(atk, true)


## 丢失目标：回到巡逻（领地不变，群首会走回自己的地盘）；先去最后看见目标的地方查看几秒
func _lose_target() -> void:
	state = "idle"
	target = null
	aggressor = null
	lock_target = null
	_unseen_t = 0.0
	_wait_t = randf_range(0.6, 1.6)
	wander_to = Vector3.ZERO
	nav_agent.reset()
	if last_seen != Vector3.INF:
		_set_investigate(last_seen)
	last_seen = Vector3.INF


## 去 p 查看几秒：只有群首 / 散兵去，而且不出领地太远（虫群守地盘，不会被远处的动静一路勾走）
func _set_investigate(p: Vector3) -> void:
	if pack_leader != null or Vector2(p.x - home.x, p.z - home.z).length() > territory + 12.0:
		return
	_investigate = Vector3(p.x, 0.0, p.z)
	_investigate_t = INVESTIGATE_T
	_wait_t = 0.3


## 导航重算周期：近处 0.5 秒，中 / 远处更慢（错开由 Agent 内的随机系数完成）
func _nav_period() -> float:
	return 0.5 if lod == 0 else (1.0 if lod == 1 else 2.0)


## 朝 goal 移动的方向：直线可走就直线，否则沿 A* 路径；飞行 / 潜地等子类可以覆盖 _uses_nav() 关掉
func _nav_dir(goal: Vector3, delta: float) -> Vector3:
	if not _uses_nav() or raid == null or raid.get("nav") == null:
		var w := goal - global_position
		w.y = 0.0
		return w.normalized() if w.length_squared() > 0.0001 else Vector3.ZERO
	return nav_agent.steer(raid.nav, global_position, goal, delta, false, _nav_period())


func _uses_nav() -> bool:
	return not bool(data.get("boss", false))


## 追击时朝目标走的方向：直线 / 绕路 + 卡住检测（1.5 秒挪不到 0.6 米就强制重新寻路）+ 近处同伴分离
func _chase_dir(fwd: Vector3, d: float, delta: float) -> Vector3:
	if d < 2.5 or not _alive(target):
		return fwd
	var dir := _nav_dir(target.global_position, delta)
	_chase_stuck_t += delta
	if _chase_stuck_t > 1.5:
		if global_position.distance_to(_chase_stuck_pos) < 0.6:
			nav_agent.stuck()
		_chase_stuck_pos = global_position
		_chase_stuck_t = 0.0
	return _separate(dir)


## 局部避让：只在近处（LOD 0）追击时算，推开贴得太近的同伴，不改变总体朝向。
## 推力每 0.12 秒（错开）重算一次，中间帧沿用，几十只虫围着机甲时也不会每帧两两比较
var _sep_push := Vector3.ZERO
var _sep_t := 0.0
func _separate(dir: Vector3) -> Vector3:
	if lod != 0 or raid == null or not raid.has_method("bug_neighbors"):
		return dir
	_sep_t -= get_physics_process_delta_time()
	if _sep_t <= 0.0:
		_sep_t = randf_range(0.1, 0.14)
		_sep_push = Vector3.ZERO
		var p := global_position
		var r0 := float(data.radius)
		for b in raid.bug_neighbors(p):
			if b == self:
				continue
			var o: Vector3 = p - b.global_position
			o.y = 0.0
			var want: float = r0 + float(b.data.radius) + 0.4
			var L := o.length()
			if L > 0.001 and L < want:
				_sep_push += o / L * (want - L) / want
	var push := _sep_push
	if push == Vector3.ZERO:
		return dir
	var out := dir + push.limit_length(0.8)
	return out.normalized() * maxf(dir.length(), 0.3) if out.length_squared() > 0.0001 else dir


## 巡逻：返回期望移动方向（长度 = 相对全速的比例）
func _patrol(delta: float) -> Vector3:
	var lead = pack_leader
	if lead != null and not _alive(lead):
		pack_leader = null
		lead = null
	var spd := maxf(float(data.speed), 0.1)
	if lead != null:
		if lead.state == "chase" and _alive(lead.target):
			target = lead.target
			state = "chase"
			return Vector3.ZERO
		var yaw: float = lead.visual.rotation.y if lead.visual else 0.0
		var goal: Vector3 = lead.global_position + follow_off.rotated(Vector3.UP, yaw)
		var w := goal - global_position
		w.y = 0.0
		var L := w.length()
		var lead_v: float = float(lead.data.speed) * float(lead.patrol_speed)
		if L > 9.0:
			return _nav_dir(goal, delta)
		if L > 1.4:
			return w / L * clampf(lead_v / spd * 1.2, 0.25, 1.0)
		return Vector3.ZERO
	if _wait_t > 0.0:
		_wait_t -= delta
		return Vector3.ZERO
	# 丢失目标后：去最后看见目标的地方查看
	if _investigate_t > 0.0:
		_investigate_t -= delta
		var wi := _investigate - global_position
		wi.y = 0.0
		if wi.length() < 2.0:
			_investigate_t = 0.0
			_wait_t = randf_range(0.8, 1.6)
			return Vector3.ZERO
		return _nav_dir(_investigate, delta) * 0.7
	var w := wander_to - global_position
	w.y = 0.0
	_stuck_t += delta
	if _stuck_t > 2.0:
		var moved := global_position.distance_to(_stuck_pos)
		_stuck_pos = global_position
		_stuck_t = 0.0
		if moved < 0.8 and wander_to != Vector3.ZERO:
			wander_to = Vector3.ZERO
	if wander_to == Vector3.ZERO or w.length() < 1.6:
		wander_to = _next_waypoint()
		nav_agent.reset()
		_wait_t = randf_range(0.8, 3.2) if w.length() < 1.6 else 0.0
		return Vector3.ZERO
	return _nav_dir(wander_to, delta) * patrol_speed


func _next_waypoint() -> Vector3:
	if raid and raid.has_method("ai_patrol_point"):
		return raid.ai_patrol_point(home, territory, global_position)
	if raid and raid.has_method("patrol_point"):
		return raid.patrol_point(home, territory, global_position)
	return home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))


func _sfx(what: String) -> void:
	if sfx != "":
		Audio.play_sfx("bug_%s_%s" % [sfx, what], global_position + Vector3(0, 0.8, 0))


func _physics_process(delta: float) -> void:
	delta = _lod_dt(delta)
	if delta <= 0.0:
		return
	_perc_t -= delta
	if _perc_t <= 0.0:
		_perc_t = _perceive_period() * randf_range(0.8, 1.2)
		_perceive()
	if state != _last_state:
		if state == "chase" and _last_state == "idle" and lod == 0:
			_sfx("appear")
		_last_state = state
	atk_cd = max(0.0, atk_cd - delta)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			_set_flash(false)
	var dir := Vector3.ZERO
	var valid: bool = _alive(target)
	var to := Vector3.ZERO
	var d := 999.0
	if valid:
		to = target.global_position - global_position
		to.y = 0.0
		d = to.length()
	if state == "chase" and not valid:
		_lose_target()
	if state == "idle":
		dir = _patrol(delta)
	elif state == "chase":
		if d > _lose_dist() + 5.0:
			_lose_target()
		else:
			var fwd: Vector3 = to / max(d, 0.01)
			if beh == "spitter":
				# 隔着墙不吐酸：没视线就绕过去找射击位置
				var los := target_los
				if d < 8.0:
					dir = -fwd
				elif d < data.range and los:
					dir = fwd.cross(Vector3.UP) * strafe * 0.5
				else:
					dir = _chase_dir(fwd, d, delta)
				if d < data.range and los and atk_cd <= 0.0 and act == "":
					atk_cd = data.rate
					_begin("wind", 0.45, fwd)
			else:
				if d > data.range * 0.8:
					dir = _chase_dir(fwd, d, delta)
				if d < data.range + 0.8 and atk_cd <= 0.0 and act == "":
					atk_cd = data.rate
					_begin("wind", 0.2 if beh == "ling" else 0.45, fwd)
	if spawn_t > 0.0:
		dir = Vector3.ZERO
	if act != "":
		_tick_act(delta)
		dir = Vector3.ZERO if act != "strike" else act_dir * (2.6 if beh == "ling" else 1.2)
	var spd: float = data.speed
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	velocity.y = -1.0 if is_on_floor() else velocity.y - 30.0 * delta
	_slide(delta)
	var face := dir if dir.length() > 0.05 else to
	if act != "":
		face = act_dir
	if face.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-face.x, -face.z), clamp(10.0 * delta, 0.0, 1.0))
	if lod == 0:
		_animate(delta, Vector3(velocity.x, 0, velocity.z).length() / maxf(float(data.speed), 0.1))


func _begin(a: String, t: float, d: Vector3) -> void:
	act = a
	act_t = t
	act_dir = d


func _tick_act(delta: float) -> void:
	act_t -= delta
	if act_t > 0.0:
		return
	match act:
		"wind":
			act = "strike"
			act_t = 0.14 if beh != "beetle" else 0.18
			_strike()
		"strike":
			act = "recover"
			act_t = 0.3 if beh != "beetle" else 0.45
		_:
			act = ""


func _strike() -> void:
	var valid: bool = target != null and is_instance_valid(target) and not target.dead
	if beh == "spitter":
		if gun_tip and raid:
			var mp: Vector3 = gun_tip.global_position
			var aim := act_dir
			if valid:
				aim = (target.global_position + Vector3(0, 1.2, 0) - mp)
				aim.y = 0.0
				aim = aim.normalized()
			raid.spawn_spit(mp, aim, data.dmg)
			raid.spark(mp, Color(0.8, 0.4, 1.0), 8)
		return
	if valid:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		if to.length() < data.range + 1.4:
			if "aggressor" in target:
				target.aggressor = self
			target.take_damage(data.dmg)
			if raid:
				raid.spark(target.global_position + Vector3(0, 1.4, 0) - to.normalized() * 0.8, Color(1.0, 0.75, 0.3), 10)
				if beh == "beetle" and target == raid.mech:
					raid.shake = max(raid.shake, 0.35)


## 程序动画：步态（抬腿 = 绕腿轴 z 旋转，摆腿 = 绕 y）、身体起伏、攻击前摇/出手/收招、受击后仰、出生爬出
func _animate(delta: float, mv: float) -> void:
	move_amt = move_toward(move_amt, clampf(mv, 0.0, 1.0), delta * 6.0)
	var cad: float = 14.0 if beh == "ling" else (9.0 if beh == "spitter" else 6.5)
	anim_t += delta * (0.3 + move_amt)
	var amt := move_amt
	var swing := 0.42 if beh != "beetle" else 0.4
	var liftk := 0.45 if beh == "ling" else (0.32 if beh == "spitter" else 0.32)
	var k := clampf(16.0 * delta, 0.0, 1.0)
	for hip in legs:
		var ph: float = anim_t * cad + hip.get_meta("phase")
		var side: float = float(hip.get_meta("side"))
		var sy := float(hip.get_meta("base_y")) - sin(ph) * swing * amt * side
		var lz := maxf(0.0, cos(ph)) * liftk * amt * side
		if act == "wind" and beh == "beetle":
			lz += 0.12 * side   # 前摇：收腿蓄力
		hip.rotation.y = lerp_angle(hip.rotation.y, sy, k)
		hip.rotation.x = 0.0
		hip.rotation.z = lerp(hip.rotation.z, lz, k)
	var body: Node3D = visual.get_node("Body")
	# 受击后仰（弹簧）
	hit_v += (-hit_tilt * 160.0 - hit_v * 13.0) * delta
	hit_tilt += hit_v * delta
	var by := absf(sin(anim_t * cad)) * 0.06 * amt * float(data.scale)
	var pitch := 0.0
	var fwd_off := 0.0
	var roll := sin(anim_t * cad * 0.5) * 0.04 * amt
	var a_t := act_t
	match act:
		"wind":
			match beh:
				"ling":
					pitch = 0.18; fwd_off = 0.25; by -= 0.1
				"spitter":
					pitch = -0.06; by -= 0.12
					if gun_glow:
						gun_glow.material_override.emission_energy_multiplier = lerp(gun_glow.material_override.emission_energy_multiplier, 6.0, k * 0.5)
				"beetle":
					pitch = -0.32; fwd_off = 0.35; by += 0.12
		"strike":
			match beh:
				"ling":
					pitch = -0.12; fwd_off = -0.7
				"spitter":
					fwd_off = 0.25; pitch = -0.05
					if gun:
						gun.position.z = 0.5 * float(data.scale)
				"beetle":
					pitch = 0.22; fwd_off = -0.6; by -= 0.15
		"recover":
			pitch = 0.04 * a_t
	if gun:
		gun.position.z = lerp(gun.position.z, 0.0, clampf(10.0 * delta, 0.0, 1.0))
		if act != "wind" and gun_glow:
			gun_glow.material_override.emission_energy_multiplier = move_toward(gun_glow.material_override.emission_energy_multiplier, 0.0, delta * 20.0)
	var kk := clampf((22.0 if act == "strike" else 10.0) * delta, 0.0, 1.0)
	body.position.y = lerp(body.position.y, by, kk)
	body.position.z = lerp(body.position.z, fwd_off * float(data.scale), kk)
	body.rotation.x = lerp(body.rotation.x, pitch, kk) + hit_tilt.x * delta * 0.0
	body.rotation.x += 0.0
	body.rotation.z = lerp(body.rotation.z, roll, kk)
	visual.rotation.x = hit_tilt.x
	visual.rotation.z = hit_tilt.z
	# 跳虫刃臂：蓄力张开，出手剪合
	for j in jaws:
		var open := 0.35 + sin(anim_t * 9.0) * 0.1
		if act == "wind":
			open = 0.9
		elif act == "strike":
			open = -0.1
		j.rotation.y = lerp(j.rotation.y, float(sign(j.position.x)) * open, clampf(18.0 * delta, 0.0, 1.0))
	# 甲虫破碎钳：蓄力高举，出手砸下
	for sc in scythes:
		var rx := sin(anim_t * 3.0) * 0.05
		if act == "wind":
			rx = 0.7
		elif act == "strike":
			rx = -0.35
		sc.rotation.x = lerp(sc.rotation.x, rx, clampf(14.0 * delta, 0.0, 1.0))
	for sp in spinners:
		var on: bool = act == "wind" or act == "strike"
		var w: float = float(sp[3]) if on else float(sp[2])
		sp[0].rotate_object_local(sp[1], w * delta)
	if sac:
		var ks := 1.0 + sin(anim_t * (4.0 if act != "wind" else 22.0)) * (0.08 if act != "wind" else 0.16)
		sac.scale = Vector3(ks, 0.9 * ks, 1.1 * ks)
	# 出生：从地下爬出
	if spawn_t > 0.0:
		spawn_t = maxf(0.0, spawn_t - delta)
		var u := 1.0 - spawn_t / 0.7
		visual.position.y = lerp(-1.6 * float(data.scale), 0.0, ease(u, 0.4))
		visual.rotation.x = (1.0 - u) * 0.6
	else:
		visual.position.y = 0.0


func _set_flash(on: bool) -> void:
	for p in parts:
		p.material_overlay = A.flash_overlay() if on else null


func take_damage(amount: float, from := Vector3.ZERO) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_aggro_on_hit()
	flash_t = 0.07
	_set_flash(true)
	# 受击后仰：越小的虫晃得越厉害
	var push := clampf(amount / float(data.hp) * 6.0, 0.15, 1.0) / float(data.scale)
	hit_v += Vector3(randf_range(-1.0, -0.4), 0, randf_range(-0.6, 0.6)) * push * 4.0
	if hp <= 0.0:
		raid.on_bug_killed(self)
		_die()


## 死亡：移出战斗、残骸塌落（腿外撇、机身砸地侧翻）、冒火花与黑烟，数秒后沉入地面
func _die() -> void:
	dying = true
	remove_from_group("bugs")
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	_set_flash(false)
	var body: Node3D = visual.get_node("Body")
	var tw := create_tween().set_parallel(true)
	var side := 1.0 if randf() < 0.5 else -1.0
	var sc := float(data.scale)
	tw.tween_property(body, "position:y", -0.35 * sc, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "rotation:z", side * randf_range(0.25, 0.5), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "rotation:x", randf_range(-0.25, 0.2), 0.5)
	tw.tween_property(visual, "rotation:x", 0.0, 0.3)
	tw.tween_property(visual, "rotation:z", 0.0, 0.3)
	for hip in legs:
		var sd: float = float(hip.get_meta("side"))
		tw.tween_property(hip, "rotation:z", -sd * randf_range(0.35, 0.7), randf_range(0.25, 0.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hip, "rotation:y", float(hip.get_meta("base_y")) + randf_range(-0.4, 0.4), 0.4)
	for j in jaws:
		tw.tween_property(j, "rotation:y", float(sign(j.position.x)) * 1.0, 0.3)
	for s2 in scythes:
		tw.tween_property(s2, "rotation:x", -0.5, 0.4)
	if gun:
		tw.tween_property(gun, "rotation:x", -0.18, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# 发光件熄灭
	for m in find_children("*", "MeshInstance3D", true, false):
		var mat = m.material_override
		if mat is StandardMaterial3D and mat.emission_enabled:
			var dm: StandardMaterial3D = mat.duplicate()
			m.material_override = dm
			tw.tween_property(dm, "emission_energy_multiplier", 0.0, 0.8)
	if raid:
		var p := global_position + Vector3(0, 0.8 * sc, 0)
		A.burst(raid.fx, p, {"amount": 16, "life": 0.5, "size": 0.1, "tex": A.soft_dot(), "additive": true, "vmin": 4.0, "vmax": 9.0, "spread": 80.0, "dir": Vector3.UP,
			"gravity": Vector3(0, -14, 0), "c0": Color(1, 0.85, 0.5), "c1": Color(1, 0.35, 0.1, 0)})
		A.burst(raid.fx, p, {"amount": 10, "life": 1.6, "size": 0.7 * sc, "additive": false, "vmin": 0.5, "vmax": 1.5, "spread": 30.0, "dir": Vector3.UP,
			"gravity": Vector3(0, 1.2, 0), "damp": 0.5, "tex": A.soft_dot(), "c0": Color(0.12, 0.12, 0.13, 0.45), "c1": Color(0.15, 0.15, 0.16, 0.0), "grow0": 0.6, "grow1": 1.8})
	var t2 := create_tween()
	t2.tween_interval(4.0)
	t2.tween_property(self, "position:y", position.y - 1.4 * sc, 2.0)
	t2.tween_callback(queue_free)


static func _panelize(m: StandardMaterial3D, scale := 1.1) -> void:
	# 机甲面板贴图：分格面板线、铆钉、散热槽、划痕（三平面投射，适配所有构件）
	m.albedo_texture = A._bug_tex("mech_panel.png")
	m.normal_enabled = true
	m.normal_texture = A._bug_tex("mech_panel_n.png")
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
