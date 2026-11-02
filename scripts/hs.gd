extends RefCounted
## 硬表面建模内核（v0.4.11）：取代"长方体拼接"。
##  cbox    —— 倒角方块（12 条边切面 + 8 个角三角），任何方块都不再是锐利棱角的积木
##  loft    —— 截面放样：沿 Z 轴依次给出截面（多边形、缩放、偏移），平面着色的多面体，
##             用来做收腰 / 鼓肚 / 锥形的肢节、甲壳和炮管
##  limb    —— 两点之间放一段放样肢节（起点 → 鼓起 → 收细），截面为切角矩形
##  shell   —— 弧形覆甲壳：截面是一段有厚度的拱，沿长度改变宽 / 高 / 拱度，做背甲、护盾、腹甲
## 全部平面着色（每个面独立法线），保证硬朗切面感。

static var _cache := {}


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	# Godot 正面为顺时针：按 a、c、b 顺序写入，使外侧（法线方向）为正面
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(c)
	st.set_normal(n)
	st.add_vertex(b)


## 凸多边形：按绕 out 方向的角度排序后扇形三角化，保证朝外
static func _convex(st: SurfaceTool, pts: Array, out: Vector3) -> void:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var u := out.cross(Vector3.UP if absf(out.normalized().y) < 0.9 else Vector3.RIGHT).normalized()
	var v := out.normalized().cross(u)
	var arr := pts.duplicate()
	arr.sort_custom(func(p, q): return atan2((p - c).dot(v), (p - c).dot(u)) < atan2((q - c).dot(v), (q - c).dot(u)))
	for i in range(1, arr.size() - 1):
		var a: Vector3 = arr[0]
		var b: Vector3 = arr[i]
		var d: Vector3 = arr[i + 1]
		if (b - a).cross(d - a).dot(out) < 0.0:
			_tri(st, a, d, b)
		else:
			_tri(st, a, b, d)


## 倒角方块
static func cbox(size: Vector3, bev := -1.0) -> ArrayMesh:
	var h := size * 0.5
	if bev < 0.0:
		bev = minf(minf(size.x, size.y), size.z) * 0.16
	bev = minf(bev, minf(minf(h.x, h.y), h.z) * 0.9)
	var key := "cb%s|%.4f" % [size, bev]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var P := func(sx: float, sy: float, sz: float, ax: int) -> Vector3:
		var p := Vector3(sx * (h.x - bev), sy * (h.y - bev), sz * (h.z - bev))
		p[ax] = [sx, sy, sz][ax] * h[ax]
		return p
	var S := [-1.0, 1.0]
	# 6 个主面
	for ax in 3:
		for sg: float in S:
			var pts: Array = []
			for a: float in S:
				for b: float in S:
					var sv := [0.0, 0.0, 0.0]
					sv[ax] = sg
					sv[(ax + 1) % 3] = a
					sv[(ax + 2) % 3] = b
					pts.append(P.call(sv[0], sv[1], sv[2], ax))
			var o := Vector3.ZERO
			o[ax] = sg
			_convex(st, pts, o)
	# 12 条倒角边
	for ax in 3:
		var a1 := (ax + 1) % 3
		var a2 := (ax + 2) % 3
		for s1: float in S:
			for s2: float in S:
				var pts: Array = []
				for t: float in S:
					var sv := [0.0, 0.0, 0.0]
					sv[ax] = t
					sv[a1] = s1
					sv[a2] = s2
					pts.append(P.call(sv[0], sv[1], sv[2], a1))
					pts.append(P.call(sv[0], sv[1], sv[2], a2))
				var o := Vector3.ZERO
				o[a1] = s1
				o[a2] = s2
				_convex(st, pts, o)
	# 8 个角
	for sx: float in S:
		for sy: float in S:
			for sz: float in S:
				_convex(st, [P.call(sx, sy, sz, 0), P.call(sx, sy, sz, 1), P.call(sx, sy, sz, 2)], Vector3(sx, sy, sz))
	var m := st.commit()
	_cache[key] = m
	return m


## 切角矩形截面（8 点），c 为切角比例
static func crect(w: float, h: float, c := 0.25) -> Array:
	var cx := w * 0.5 * c
	var cy := h * 0.5 * c
	var x := w * 0.5
	var y := h * 0.5
	return [Vector2(x - cx, -y), Vector2(x, -y + cy), Vector2(x, y - cy), Vector2(x - cx, y),
		Vector2(-x + cx, y), Vector2(-x, y - cy), Vector2(-x, -y + cy), Vector2(-x + cx, -y)]


## 正 n 边形截面
static func ngon(n: int, r: float, rot := 0.0) -> Array:
	var o: Array = []
	for k in n:
		var a := rot + TAU * k / n
		o.append(Vector2(cos(a), sin(a)) * r)
	return o


## 盾 / 楔形截面：上窄下宽或带尖底（top 上宽比例，keel 底部尖角深度）
static func keel(w: float, h: float, top := 0.6, keel_d := 0.25) -> Array:
	var x := w * 0.5
	var y := h * 0.5
	return [Vector2(0, -y - h * keel_d), Vector2(x * 0.7, -y), Vector2(x, -y * 0.2), Vector2(x * top, y),
		Vector2(-x * top, y), Vector2(-x, -y * 0.2), Vector2(-x * 0.7, -y)]


## 放样：secs = [[z, Vector2 scale, Vector2 offset], ...]，base 为截面点（所有截面同一拓扑），或者每节给自己的 pts（第 4 项）
static func loft(base: Array, secs: Array, cap0 := true, cap1 := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for sd in secs:
		var pts: Array = sd[3] if sd.size() > 3 else base
		var sc: Vector2 = sd[1]
		var of: Vector2 = sd[2]
		var r: Array = []
		for q in pts:
			r.append(Vector3(q.x * sc.x + of.x, q.y * sc.y + of.y, sd[0]))
		rings.append(r)
	var n: int = rings[0].size()
	# 面朝向：多边形逆时针 + 沿 +Z 推进时，(r1-r0)×(next-cur) 指向外
	var ccw := 0.0
	for i in n:
		var a: Vector2 = base[i]
		var b: Vector2 = base[(i + 1) % n]
		ccw += a.x * b.y - b.x * a.y
	var flip := ccw < 0.0
	var dz: float = secs[-1][0] - secs[0][0]
	if dz < 0.0:
		flip = not flip
	for k in rings.size() - 1:
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		for i in n:
			var j := (i + 1) % n
			if flip:
				_tri(st, r0[i], r1[i], r1[j])
				_tri(st, r0[i], r1[j], r0[j])
			else:
				_tri(st, r0[i], r0[j], r1[j])
				_tri(st, r0[i], r1[j], r1[i])
	var sgn := 1.0 if dz >= 0.0 else -1.0
	for e in [[0, cap0, -sgn], [rings.size() - 1, cap1, sgn]]:
		if not e[1]:
			continue
		var r: Array = rings[e[0]]
		var p2 := PackedVector2Array()
		for p in r:
			p2.append(Vector2(p.x, p.y))
		var idx := Geometry2D.triangulate_polygon(p2)
		var want := Vector3(0, 0, e[2])
		for t in range(0, idx.size(), 3):
			var A0: Vector3 = r[idx[t]]
			var B0: Vector3 = r[idx[t + 1]]
			var C0: Vector3 = r[idx[t + 2]]
			if (B0 - A0).cross(C0 - A0).dot(want) < 0.0:
				_tri(st, A0, C0, B0)
			else:
				_tri(st, A0, B0, C0)
	return st.commit()


## 放样肢节：从 a 到 b，截面切角矩形，w/h 为起点尺寸，taper 为末端比例，bulge 为 35% 处鼓起比例
static func limb_mesh(len_: float, w: float, h: float, taper := 0.7, bulge := 1.15, chamf := 0.35) -> ArrayMesh:
	var key := "lm%.3f|%.3f|%.3f|%.2f|%.2f|%.2f" % [len_, w, h, taper, bulge, chamf]
	if _cache.has(key):
		return _cache[key]
	var base := crect(1.0, 1.0, chamf)
	var e := minf(w, h) * 0.12
	var secs := [
		[-len_ * 0.5, Vector2(w * 0.78, h * 0.78), Vector2.ZERO],
		[-len_ * 0.5 + e, Vector2(w * 0.95, h * 0.95), Vector2.ZERO],
		[-len_ * 0.5 + len_ * 0.35, Vector2(w * bulge, h * bulge), Vector2(0, h * 0.04)],
		[len_ * 0.5 - len_ * 0.2, Vector2(w * lerpf(1.0, taper, 0.8), h * lerpf(1.0, taper, 0.8)), Vector2.ZERO],
		[len_ * 0.5 - e, Vector2(w * taper, h * taper), Vector2.ZERO],
		[len_ * 0.5, Vector2(w * taper * 0.8, h * taper * 0.8), Vector2.ZERO],
	]
	var m := loft(base, secs)
	_cache[key] = m
	return m


## 拱形覆甲截面：外弧 + 内弧（厚度 t），半角 ang（度），seg 段
static func arch(r: float, t: float, ang := 70.0, seg := 6) -> Array:
	var o: Array = []
	for k in seg + 1:
		var a := deg_to_rad(lerpf(-ang, ang, float(k) / seg)) + PI * 0.5
		o.append(Vector2(cos(a), sin(a)) * r)
	for k in range(seg, -1, -1):
		var a := deg_to_rad(lerpf(-ang, ang, float(k) / seg)) + PI * 0.5
		o.append(Vector2(cos(a), sin(a)) * (r - t))
	return o


## 覆甲壳：沿 Z 从 z0 到 z1，profile = [[t(0..1), 宽比例, 高比例, y偏移], ...]
static func shell_mesh(r: float, t: float, z0: float, z1: float, profile: Array, ang := 70.0, seg := 6) -> ArrayMesh:
	var base := arch(r, t, ang, seg)
	var secs: Array = []
	for p in profile:
		secs.append([lerpf(z0, z1, p[0]), Vector2(p[1], p[2]), Vector2(0, p[3] - r * p[2])])
	return loft(base, secs)
