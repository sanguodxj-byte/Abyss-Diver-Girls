extends RefCounted
## 程序化美术库：倒角网格、PBR 材质（三平面映射 + 噪声细节）、粒子、贴图。
## 所有资源按参数缓存，避免重复创建。

static var _mesh_cache := {}
static var _mat_cache := {}
static var _tex_cache := {}


static func is_mobile_perf() -> bool:
	return OS.has_feature("mobile") or RenderingServer.get_current_rendering_method() == "mobile"


# ======================================================================
# 网格
# ======================================================================
static var _vc := Color(1, 1, 1)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	st.set_color(_vc)
	var n := (b - a).cross(c - a)
	# Godot 以顺时针为正面：叉积朝内时才是朝外的正面
	if n.dot((a + b + c) / 3.0 - center) > 0.0:
		var t := b
		b = c
		c = t
	# 盒式投影 UV（供生成切线，法线贴图才有正确的切线空间）
	var o := -(b - a).cross(c - a)
	var ao := o.abs()
	for v in [a, b, c]:
		var uv: Vector2
		if ao.x >= ao.y and ao.x >= ao.z:
			uv = Vector2(v.z * signf(o.x), -v.y)
		elif ao.y >= ao.z:
			uv = Vector2(v.x, v.z * signf(o.y))
		else:
			uv = Vector2(-v.x * signf(o.z), -v.y)
		st.set_uv(uv)
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, center: Vector3) -> void:
	_tri(st, a, b, c, center)
	_tri(st, a, c, d, center)


## 倒角方块。bevel = 倒角宽度；taper = 顶面相对底面的缩放（<1 为梯形）。
static func bevel_box(size: Vector3, bevel := 0.06, taper := 1.0) -> ArrayMesh:
	var key := "bb%s|%.3f|%.3f" % [size, bevel, taper]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var h := size * 0.5
	var b: float = min(bevel, min(h.x, min(h.y, h.z)) * 0.9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var P := func(sx: float, sy: float, sz: float, ix: float, iy: float, iz: float) -> Vector3:
		# ix/iy/iz：该轴是否内缩 b（1 = 内缩）
		var v := Vector3(sx * (h.x - b * ix), sy * (h.y - b * iy), sz * (h.z - b * iz))
		if sy > 0.0:
			v.x *= taper
			v.z *= taper
		return v
	var C := Vector3.ZERO
	var S := [-1.0, 1.0]
	# 6 个面（顶点色白），棱与角（宽斜面衰减边缘掉漆权重，避免宽斜面整块出现斑点）
	_vc = Color(1, 1, 1)
	for s in S:
		_quad(st, P.call(s, -1, -1, 0, 1, 1), P.call(s, 1, -1, 0, 1, 1), P.call(s, 1, 1, 0, 1, 1), P.call(s, -1, 1, 0, 1, 1), C)
		_quad(st, P.call(-1, s, -1, 1, 0, 1), P.call(1, s, -1, 1, 0, 1), P.call(1, s, 1, 1, 0, 1), P.call(-1, s, 1, 1, 0, 1), C)
		_quad(st, P.call(-1, -1, s, 1, 1, 0), P.call(1, -1, s, 1, 1, 0), P.call(1, 1, s, 1, 1, 0), P.call(-1, 1, s, 1, 1, 0), C)
	# 12 条棱
	var edge_r := 1.0 - clampf(0.068 / maxf(b, 0.01), 0.12, 1.0)
	_vc = Color(edge_r, 1, 1)
	for s1 in S:
		for s2 in S:
			# 平行 Z 轴的棱（X、Y 两面之间）
			_quad(st, P.call(s1, s2, -1, 0, 1, 1), P.call(s1, s2, 1, 0, 1, 1), P.call(s1, s2, 1, 1, 0, 1), P.call(s1, s2, -1, 1, 0, 1), C)
			# 平行 X 轴的棱（Y、Z 之间）
			_quad(st, P.call(-1, s1, s2, 1, 0, 1), P.call(1, s1, s2, 1, 0, 1), P.call(1, s1, s2, 1, 1, 0), P.call(-1, s1, s2, 1, 1, 0), C)
			# 平行 Y 轴的棱（X、Z 之间）
			_quad(st, P.call(s1, -1, s2, 0, 1, 1), P.call(s1, 1, s2, 0, 1, 1), P.call(s1, 1, s2, 1, 1, 0), P.call(s1, -1, s2, 1, 1, 0), C)
	# 8 个角
	for sx in S:
		for sy in S:
			for sz in S:
				_tri(st, P.call(sx, sy, sz, 0, 1, 1), P.call(sx, sy, sz, 1, 0, 1), P.call(sx, sy, sz, 1, 1, 0), C)
	_vc = Color(1, 1, 1)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func cyl(r: float, hgt: float, r2 := -1.0, seg := 28) -> CylinderMesh:
	var rb := r if r2 < 0 else r2
	var rmax := maxf(r, rb)
	var s_seg := seg
	if seg >= 8:
		var mob := is_mobile_perf()
		var cap_seg := (12 if rmax < 0.08 else (14 if rmax < 0.2 else (18 if rmax < 0.45 else (22 if rmax < 1.2 else 28)))) if mob \
			else (16 if rmax < 0.08 else (20 if rmax < 0.2 else (24 if rmax < 0.45 else (28 if rmax < 1.2 else 36))))
		s_seg = cap_seg if seg == 28 else clampi(max(seg, cap_seg - 2), 8, cap_seg + 4)
	var key := "cy%.3f|%.3f|%.3f|%d" % [r, hgt, r2, s_seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = rb
	c.height = hgt
	c.radial_segments = s_seg
	c.rings = 1
	_mesh_cache[key] = c
	return c


static func sphere(r: float, hgt := -1.0, seg := 28) -> SphereMesh:
	var s_seg := seg
	if seg >= 8:
		var mob := is_mobile_perf()
		var cap_seg := (12 if r < 0.08 else (14 if r < 0.2 else (18 if r < 0.5 else (22 if r < 1.2 else 28)))) if mob \
			else (16 if r < 0.08 else (20 if r < 0.2 else (24 if r < 0.5 else (28 if r < 1.2 else 32))))
		s_seg = cap_seg if seg == 28 else clampi(max(seg, cap_seg - 2), 8, cap_seg + 4)
	var key := "sp%.3f|%.3f|%d" % [r, hgt, s_seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if hgt < 0 else hgt
	s.radial_segments = s_seg
	s.rings = maxi(6, s_seg / 2)
	_mesh_cache[key] = s
	return s


## 自然多面岩体网格（中心在原点，基础半径约 0.92，底面平稳、硬朗切面节理与沉积岩层台，按 variant 缓存）
static func rock_mesh(variant := 0, detail := 18) -> ArrayMesh:
	var v_id := posmod(variant, 12)
	var nu := maxi(14, detail)
	var nv := maxi(10, detail / 2 + 2)
	var key := "rk%d|%d" % [v_id, nu]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = v_id * 7919 + 1337
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var ph3 := rng.randf() * TAU
	var ph4 := rng.randf() * TAU
	var a1 := rng.randf_range(0.13, 0.23)
	var a2 := rng.randf_range(0.10, 0.18)
	var a3 := rng.randf_range(0.06, 0.13)
	var skew := Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
	var planes: Array = []
	for k in 20:
		var z := rng.randf_range(-0.88, 0.90) if k < 14 else (rng.randf_range(0.76, 0.96) if k % 2 == 0 else rng.randf_range(-0.96, -0.74))
		var a := rng.randf() * TAU
		var rxy := sqrt(maxf(0.0, 1.0 - z * z))
		var n := Vector3(cos(a) * rxy, z, sin(a) * rxy).normalized()
		planes.append([n, rng.randf_range(0.30, 0.45)])
	var ring_pts: Array = []
	var ring_cuts: Array = []
	for iv in range(nv + 1):
		var v := float(iv) / float(nv)
		var theta := v * PI
		var st_t := sin(theta)
		var ct_t := -cos(theta)
		var step_band: float = floorf(v * 7.0) / 7.0
		var ledge := 1.0 + 0.065 * sin(step_band * TAU * 2.5 + ph3) + 0.038 * cos(theta * 11.0 + ph1)
		var row: Array = []
		var crow: Array = []
		for iu in range(nu):
			var phi := TAU * float(iu) / float(nu) if (iv > 0 and iv < nv) else 0.0
			var d0 := Vector3(st_t * cos(phi), ct_t, st_t * sin(phi))
			var crag := 0.045 * sin(7.0 * phi + 4.0 * theta + ph2)
			var rh := 0.56 * ledge * (1.0 + a1 * cos(2.0 * phi + ph1) + a2 * cos(3.0 * phi + ph2) + a3 * cos(5.0 * phi + ph3) + crag)
			var ry := 0.52 * (1.0 + 0.08 * sin(3.0 * theta + ph4))
			var taper := lerpf(1.18, 0.70, clampf((d0.y + 0.6) / 1.5, 0.0, 1.0))
			var p := Vector3(d0.x * rh * taper + d0.y * skew.x, d0.y * ry, d0.z * rh * taper + d0.y * skew.y)
			var cuts := 0
			for pl: Array in planes:
				var pn: Vector3 = pl[0]
				var pd: float = pl[1]
				var over := p.dot(pn) - pd
				if over > 0.0:
					p -= pn * (over * 0.96)
					cuts += 1
			if p.y < -0.40:
				p.y = lerpf(-0.47, p.y, 0.16)
			row.append(p * 1.96)
			crow.append(cuts)
		ring_pts.append(row)
		ring_cuts.append(crow)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var C := Vector3.ZERO
	for iv in range(nv):
		var r0: Array = ring_pts[iv]
		var r1: Array = ring_pts[iv + 1]
		var c0: Array = ring_cuts[iv]
		var c1: Array = ring_cuts[iv + 1]
		for iu in range(nu):
			var iu1 := (iu + 1) % nu
			var p00: Vector3 = r0[iu]
			var p10: Vector3 = r0[iu1]
			var p11: Vector3 = r1[iu1]
			var p01: Vector3 = r1[iu]
			var max_c: int = maxi(maxi(int(c0[iu]), int(c0[iu1])), maxi(int(c1[iu1]), int(c1[iu])))
			_vc = Color(0.76 if max_c >= 3 else 0.96, 1.0, 1.0)
			if iv == 0:
				_tri(st, p00, p11, p01, C)
			elif iv == nv - 1:
				_tri(st, p00, p10, p11, C)
			else:
				_quad(st, p00, p10, p11, p01, C)
	_vc = Color(1, 1, 1)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


## 内部辅助：向 SurfaceTool 追加一段圆锥/弯曲树干或树枝管段（保证正面朝外）
static func _branch_tube(st: SurfaceTool, pts: Array, radii: Array, seg := 7) -> void:
	var n_rings := pts.size()
	if n_rings < 2:
		return
	var up := Vector3.FORWARD
	var rings: Array = []
	var v_acc := 0.0
	for i in n_rings:
		if i > 0:
			v_acc += (pts[i] as Vector3).distance_to(pts[i - 1] as Vector3)
		var tng: Vector3 = ((pts[mini(i + 1, n_rings - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		if tng.length_squared() < 1e-4:
			tng = Vector3.UP
		if absf(tng.dot(up)) > 0.92:
			up = Vector3.RIGHT
		var nx := tng.cross(up).normalized()
		var ny := nx.cross(tng).normalized()
		up = ny
		var rad: float = float(radii[i])
		var ring: Array = []
		for j in seg:
			var a := TAU * float(j) / float(seg)
			var nrm := nx * cos(a) + ny * sin(a)
			# 根部带自然板根棱脊起伏
			var flare := 1.0 + (0.24 * cos(a * 4.0 + 0.7) if i == 0 and rad > 0.08 else 0.0)
			ring.append([(pts[i] as Vector3) + nrm * (rad * flare), nrm, v_acc])
		rings.append(ring)
	for i in range(n_rings - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for j in seg:
			var j2 := (j + 1) % seg
			var a0: Array = r0[j]
			var b0: Array = r0[j2]
			var c1: Array = r1[j2]
			var d1: Array = r1[j]
			var u0 := float(j) / float(seg)
			var u1 := float(j + 1) / float(seg)
			for vtx in [[a0, u0], [c1, u1], [d1, u0], [a0, u0], [b0, u1], [c1, u1]]:
				var inf: Array = vtx[0]
				st.set_color(Color(1.0, 1.0, 1.0, 1.0))
				st.set_normal(inf[1])
				st.set_uv(Vector2(float(vtx[1]), float(inf[2]) * 1.4))
				st.add_vertex(inf[0])


## 写实树木主干与多级分叉木质大枝网格（原点在地面 y=0，总高约 1.0，底部板根+微弯主干+5~7根斜伸侧枝）
static func tree_trunk_mesh(variant := 0, gnarled := false) -> ArrayMesh:
	var v_id := posmod(variant, 8)
	var key := "tr_trunk_%d_%d" % [v_id, 1 if gnarled else 0]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = v_id * 3571 + (901 if gnarled else 211)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lean_x := rng.randf_range(-0.07, 0.07) * (1.8 if gnarled else 1.0)
	var lean_z := rng.randf_range(-0.07, 0.07) * (1.8 if gnarled else 1.0)
	var r_base := 0.135 if gnarled else 0.115
	var main_pts := [
		Vector3(0.0, -0.02, 0.0),
		Vector3(lean_x * 0.15, 0.14, lean_z * 0.15),
		Vector3(lean_x * 0.55, 0.42, lean_z * 0.45),
		Vector3(lean_x * 0.85, 0.70, lean_z * 0.90),
		Vector3(lean_x * 1.05, 0.95, lean_z * 1.05),
	]
	var main_r := [r_base * 1.42, r_base, r_base * 0.74, r_base * 0.46, r_base * 0.16]
	_branch_tube(st, main_pts, main_r, 8)

	var n_limbs := 7 if gnarled else 5
	for b in n_limbs:
		var t_h := lerpf(0.36, 0.82, float(b) / float(maxi(1, n_limbs - 1))) + rng.randf_range(-0.03, 0.03)
		var az := float(b) * 2.39996 + rng.randf_range(-0.35, 0.35)
		var dir := Vector3(cos(az), 0.0, sin(az))
		var p0 := Vector3(lean_x * t_h, t_h, lean_z * t_h)
		var reach := rng.randf_range(0.28, 0.46) * (1.28 if gnarled else (1.15 - t_h * 0.45))
		var rise := rng.randf_range(0.14, 0.28) if gnarled else rng.randf_range(0.04, 0.16)
		var p1 := p0 + dir * (reach * 0.52) + Vector3(0.0, rise * 0.55, 0.0)
		var p2 := p0 + dir * reach + Vector3(rng.randf_range(-0.04, 0.04), rise, rng.randf_range(-0.04, 0.04))
		var rb := r_base * lerpf(0.54, 0.30, (t_h - 0.32) / 0.55)
		_branch_tube(st, [p0, p1, p2], [rb, rb * 0.62, rb * 0.18], 5)
		if gnarled and b < 4:
			var sub_az := az + rng.randf_range(0.55, 0.95) * (1.0 if b % 2 == 0 else -1.0)
			var sdir := Vector3(cos(sub_az), 0.0, sin(sub_az))
			var sp2 := p1 + sdir * (reach * 0.55) + Vector3(0.0, rise * 0.65, 0.0)
			_branch_tube(st, [p1, (p1 + sp2) * 0.5 + Vector3(0, 0.03, 0), sp2], [rb * 0.52, rb * 0.32, rb * 0.10], 4)

	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


## 内部辅助：向植物冠层写入一片微拱曲立体枝叶扇（两段折弯 + 纵向交叉副翼，杜绝纸片感；顶点色 R=内芯AO，G=色差）
static func _foliage_bough(st: SurfaceTool, origin: Vector3, dir_xz: Vector3, length: float, width: float,
		droop: float, tip_lift: float, crown_center: Vector3, var_g: float, add_cross := true) -> void:
	var side := Vector3(-dir_xz.z, 0.0, dir_xz.x).normalized()
	var p_root := origin
	var p_mid := origin + dir_xz * (length * 0.52) + Vector3(0.0, -droop, 0.0)
	var p_tip := origin + dir_xz * length + Vector3(0.0, -droop + tip_lift, 0.0)
	var hw_root := width * 0.36
	var hw_mid := width * 0.54
	var hw_tip := width * 0.44

	var emit_q := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uvs: Array, aos: Array) -> void:
		var pts := [a, b, c, d]
		var idx := [0, 1, 2, 0, 2, 3]
		for k in idx:
			var vp: Vector3 = pts[k]
			var nrm := (vp - crown_center).normalized()
			nrm = (nrm + Vector3(0.0, 0.55, 0.0)).normalized()
			st.set_color(Color(float(aos[k]), var_g, 1.0, 1.0))
			st.set_normal(nrm)
			st.set_uv(uvs[k])
			st.add_vertex(vp)

	# 主水平微拱松针/枝叶扇（两段曲率：基部->中段略垂 + 左右微拱，中段->梢部微翘）
	var arch := Vector3(0.0, width * 0.11, 0.0)
	emit_q.call(
		p_root - side * hw_root, p_root + side * hw_root,
		p_mid + side * hw_mid - arch, p_mid - side * hw_mid - arch,
		[Vector2(0.14, 0.98), Vector2(0.86, 0.98), Vector2(0.98, 0.48), Vector2(0.02, 0.48)],
		[0.36, 0.36, 0.78, 0.78]
	)
	emit_q.call(
		p_mid - side * hw_mid - arch, p_mid + side * hw_mid - arch,
		p_tip + side * hw_tip, p_tip - side * hw_tip,
		[Vector2(0.02, 0.48), Vector2(0.98, 0.48), Vector2(0.92, 0.03), Vector2(0.08, 0.03)],
		[0.78, 0.78, 1.0, 1.0]
	)
	# 斜置立体副翼：令平视/侧视时每层树枝都呈现饱满蓬松厚度，绝不露单薄横线
	if add_cross:
		var tilt := (side * 0.58 + Vector3(0.0, 0.81, 0.0)).normalized() * (width * 0.34)
		emit_q.call(
			p_root - tilt * 0.55, p_root + tilt * 0.55,
			p_tip + tilt * 0.85, p_tip - tilt * 0.85,
			[Vector2(0.16, 0.96), Vector2(0.84, 0.96), Vector2(0.90, 0.05), Vector2(0.10, 0.05)],
			[0.38, 0.46, 0.98, 0.92]
		)


## 多层轮生写实针叶松柏树冠网格（y=0..1，底半径约 1.0，6 层错位下垂松枝轮 + 顶梢簇）
static func pine_crown_mesh(variant := 0) -> ArrayMesh:
	var v_id := posmod(variant, 6)
	var key := "pine_cr_%d" % v_id
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = v_id * 4933 + 617
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, 0.42, 0.0)
	var tiers := [
		[0.08, 1.04, 7, 0.16, 0.05],
		[0.24, 0.90, 7, 0.13, 0.05],
		[0.40, 0.76, 6, 0.10, 0.06],
		[0.56, 0.61, 6, 0.07, 0.06],
		[0.71, 0.46, 5, 0.04, 0.07],
		[0.84, 0.31, 5, 0.01, 0.08],
	]
	for ti in tiers.size():
		var t: Array = tiers[ti]
		var y0: float = float(t[0])
		var r_len: float = float(t[1])
		var cnt: int = int(t[2])
		var drp: float = float(t[3])
		var lft: float = float(t[4])
		var az_off := float(ti) * 0.92 + rng.randf() * TAU
		for i in cnt:
			var az := az_off + TAU * float(i) / float(cnt) + rng.randf_range(-0.18, 0.18)
			var dir := Vector3(cos(az), 0.0, sin(az))
			var blen := r_len * rng.randf_range(0.88, 1.12)
			var bw := blen * rng.randf_range(0.78, 0.94)
			var root_p := dir * 0.05 + Vector3(0.0, y0 + rng.randf_range(-0.025, 0.025), 0.0)
			_foliage_bough(st, root_p, dir, blen, bw, drp, lft, center, rng.randf(), ti < 4)
	# 顶部直立塔尖针叶束
	for k in 3:
		var az_t := float(k) * TAU / 3.0 + rng.randf_range(-0.2, 0.2)
		var s_t := Vector3(cos(az_t), 0.0, sin(az_t)) * 0.19
		var pts_t := [Vector3(0, 0.78, 0) - s_t, Vector3(0, 0.78, 0) + s_t, Vector3(0, 1.03, 0) + s_t * 0.45, Vector3(0, 1.03, 0) - s_t * 0.45]
		var uvs_t := [Vector2(0.08, 0.96), Vector2(0.92, 0.96), Vector2(0.82, 0.04), Vector2(0.18, 0.04)]
		var aos_t := [0.58, 0.58, 1.0, 1.0]
		for vi in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(aos_t[vi], 0.75, 1.0, 1.0))
			st.set_normal((pts_t[vi] - center + Vector3(0, 0.7, 0)).normalized())
			st.set_uv(uvs_t[vi])
			st.add_vertex(pts_t[vi])
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


## 写实阔叶乔木不规则团簇树冠网格（y=0..1，半径约 1.0，由 6 个高低错落的叶团分枝构成自然树冠轮廓）
static func broad_crown_mesh(variant := 0) -> ArrayMesh:
	var v_id := posmod(variant, 6)
	var key := "broad_cr_%d" % v_id
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = v_id * 6151 + 829
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, 0.48, 0.0)
	# 主冠外围不规则叶团锚点 + 顶部中心主冠团
	var lobes := [Vector3(0.0, 0.62, 0.0)]
	for li in 5:
		var az := float(li) * TAU / 5.0 + rng.randf_range(-0.32, 0.32)
		var rad := rng.randf_range(0.28, 0.44)
		lobes.append(Vector3(cos(az) * rad, rng.randf_range(0.24, 0.54), sin(az) * rad))
	for li in lobes.size():
		var lc: Vector3 = lobes[li]
		var n_fans := 6 if li == 0 else 5
		var f_scale := 0.64 if li == 0 else rng.randf_range(0.54, 0.68)
		for fi in n_fans:
			var faz := float(fi) * TAU / float(n_fans) + rng.randf_range(-0.28, 0.28)
			var dir := Vector3(cos(faz), 0.0, sin(faz))
			var lift := rng.randf_range(0.08, 0.28) if li == 0 else rng.randf_range(-0.02, 0.22)
			_foliage_bough(st, lc - dir * 0.08, dir, f_scale, f_scale * 1.02, 0.03, lift, center, rng.randf(), fi % 2 == 0)
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


## 废土灌木丛 / 绿篱团簇网格（y=0..1，半径约 1.0，多枝放射状阔叶灌丛，替代原先绿色石头块）
static func shrub_mesh(variant := 0) -> ArrayMesh:
	var v_id := posmod(variant, 4)
	var key := "shrub_m_%d" % v_id
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = v_id * 2713 + 409
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, 0.25, 0.0)
	for i in 9:
		var az := float(i) * TAU / 9.0 + rng.randf_range(-0.22, 0.22)
		var dir := Vector3(cos(az), 0.0, sin(az))
		var bl := rng.randf_range(0.75, 1.02)
		var lift := rng.randf_range(0.28, 0.68)
		_foliage_bough(st, Vector3(0.0, rng.randf_range(0.04, 0.16), 0.0), dir, bl, bl * 0.95, 0.0, lift, center, rng.randf(), i % 3 == 0)
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


## 自然弯曲散射野草/芦苇丛网格（原点在地面 y=0，高 1.0，4 组弧形外倾交叉草叶带，根部贴地融合法线）
static func grass_clump_mesh() -> ArrayMesh:
	const KEY := "grass_clump_v2"
	if _mesh_cache.has(KEY):
		return _mesh_cache[KEY]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var az := float(i) * PI * 0.25 + (0.14 if i % 2 == 1 else -0.09)
		var tang := Vector3(cos(az), 0.0, sin(az)) * 0.46
		var out_lean := Vector3(-sin(az), 0.0, cos(az)) * (0.16 if i % 2 == 0 else -0.16)
		var p_b0 := -tang * 0.78
		var p_b1 := tang * 0.78
		var p_m0 := -tang * 0.95 + out_lean * 0.45 + Vector3(0.0, 0.50, 0.0)
		var p_m1 := tang * 0.95 + out_lean * 0.45 + Vector3(0.0, 0.50, 0.0)
		var p_t0 := -tang * 1.05 + out_lean + Vector3(0.0, 1.0, 0.0)
		var p_t1 := tang * 1.05 + out_lean + Vector3(0.0, 1.0, 0.0)
		var nrm := (Vector3(0.0, 0.88, 0.0) + out_lean).normalized()
		var segs := [
			[[p_b0, p_b1, p_m1, p_m0], [Vector2(0.0, 0.99), Vector2(1.0, 0.99), Vector2(1.0, 0.50), Vector2(0.0, 0.50)], [0.46, 0.46, 0.78, 0.78]],
			[[p_m0, p_m1, p_t1, p_t0], [Vector2(0.0, 0.50), Vector2(1.0, 0.50), Vector2(1.0, 0.01), Vector2(0.0, 0.01)], [0.78, 0.78, 1.0, 1.0]],
		]
		var vg := float(i) * 0.28
		for sg: Array in segs:
			var pts: Array = sg[0]
			var uvs: Array = sg[1]
			var aos: Array = sg[2]
			for vi in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(float(aos[vi]), vg, 1.0, 1.0))
				st.set_normal(nrm)
				st.set_uv(uvs[vi])
				st.add_vertex(pts[vi])
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[KEY] = m
	return m


static func capsule(r: float, hgt: float) -> CapsuleMesh:
	var key := "ca%.3f|%.3f" % [r, hgt]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = hgt
	c.radial_segments = 10 if r < 0.2 else (14 if r < 0.5 else 18)
	c.rings = 4
	_mesh_cache[key] = c
	return c


static func torus(inner: float, outer: float, seg := 36) -> TorusMesh:
	var mob := is_mobile_perf()
	var cap_seg := (14 if outer < 0.12 else (18 if outer < 0.35 else (22 if outer < 1.0 else 28))) if mob \
		else (18 if outer < 0.12 else (24 if outer < 0.35 else (28 if outer < 1.0 else 36)))
	var s_seg := mini(seg, cap_seg) if seg >= 24 else clampi(max(seg, cap_seg - 2), 8, cap_seg + 4)
	var key := "to%.3f|%.3f|%d" % [inner, outer, s_seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = s_seg
	t.ring_segments = 10 if (outer - inner) < 0.15 else 12
	_mesh_cache[key] = t
	return t


static func quad(w: float, d: float) -> PlaneMesh:
	var key := "pl%.3f|%.3f" % [w, d]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var p := PlaneMesh.new()
	p.size = Vector2(w, d)
	_mesh_cache[key] = p
	return p


# ======================================================================
# 贴图
# ======================================================================
static func noise_tex(kind := "grime", size := 256) -> Texture2D:
	var key := "n_%s_%d" % [kind, size]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := FastNoiseLite.new()
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	match kind:
		"grime":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.012
			n.fractal_octaves = 5
			var g := Gradient.new()
			g.set_color(0, Color(0.62, 0.6, 0.58))
			g.set_color(1, Color(1, 1, 1))
			t.color_ramp = g
		"grime_raw":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.012
			n.fractal_octaves = 5
		"hi_raw":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.075
			n.fractal_octaves = 4
			n.fractal_gain = 0.62
		"rough":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.045
			n.fractal_octaves = 4
			var g := Gradient.new()
			g.set_color(0, Color(0.75, 0.75, 0.75))
			g.set_color(1, Color(1, 1, 1))
			t.color_ramp = g
		"normal":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.085
			n.fractal_octaves = 4
			t.as_normal_map = true
			t.bump_strength = 5.5
		"ground":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.008
			n.fractal_octaves = 6
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.45, 0.6, 1.0])
			g.colors = PackedColorArray([Color(0.55, 0.5, 0.45), Color(0.8, 0.74, 0.64), Color(0.9, 0.84, 0.72), Color(1.0, 0.95, 0.85)])
			t.color_ramp = g
		"ground_n":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.065
			n.fractal_octaves = 5
			t.as_normal_map = true
			t.bump_strength = 9.5
		"creep":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.03
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.03, 0.09, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1), Color(0.75, 0.75, 0.75), Color(0.0, 0.0, 0.0), Color(0, 0, 0)])
			t.color_ramp = g
		"concrete":
			n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
			n.frequency = 0.085
			n.fractal_octaves = 5
			var g := Gradient.new()
			g.set_color(0, Color(0.66, 0.64, 0.62))
			g.set_color(1, Color(1, 1, 1))
			t.color_ramp = g
	_tex_cache[key] = t
	return t


## 黄黑警示条纹
static func hazard_tex() -> Texture2D:
	if _tex_cache.has("hazard"):
		return _tex_cache["hazard"]
	# 256px + 边缘抗锯齿 + mipmap，远看不再闪
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var u := fmod(float(x + y) / 64.0, 2.0)
			var on := u < 1.0
			var k := 0.5 + (0.5 if on else -0.5) * clampf(minf(u if on else u - 1.0, (1.0 - u) if on else (2.0 - u)) * 64.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.08, 0.08, 0.08).lerp(Color(0.95, 0.68, 0.1), k))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["hazard"] = t
	return t


## 柔和圆点（粒子用）
static func soft_dot() -> Texture2D:
	if _tex_cache.has("dot"):
		return _tex_cache["dot"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_tex_cache["dot"] = t
	return t


## 体积感卷云烟团（256px 域扭曲 FBM + 内置明暗自阴影，彻底告别圆形棉球）
static func smoke_tex() -> Texture2D:
	if _tex_cache.has("smoke"):
		return _tex_cache["smoke"]
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 19
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.024
	nz.fractal_octaves = 4
	nz.fractal_gain = 0.52
	var nw := FastNoiseLite.new()
	nw.seed = 53
	nw.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nw.frequency = 0.016
	nw.fractal_octaves = 3
	var half := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) - half, float(y) - half) / (float(sz) * 0.5)
			var wx := nw.get_noise_2d(float(x), float(y)) * 18.0
			var wy := nw.get_noise_2d(float(x) + 113.0, float(y) + 71.0) * 18.0
			var n0 := nz.get_noise_2d(float(x) + wx, float(y) + wy) * 0.5 + 0.5
			var n1 := nz.get_noise_2d(float(x) * 2.1 - wy * 0.6, float(y) * 2.1 + wx * 0.6) * 0.5 + 0.5
			var d := p.length()
			# 外廓被噪声侵蚀出凹凸云瓣，绝非几何正圆
			var edge_w := d + (0.5 - n0) * 0.34 + (0.5 - n1) * 0.14
			var mask := smoothstep(0.96, 0.30, edge_w)
			var core := smoothstep(0.84, 0.18, edge_w)
			var wisp := clampf(mask * (0.48 + 0.68 * n0 + 0.20 * n1), 0.0, 1.0)
			var a := clampf(mix_f(wisp, core * 0.94, 0.45), 0.0, 1.0)
			# 轻微斜上方受光 + 下缘冷暗自阴影，增强立体烟团体积感
			var upper_lit := clampf(0.5 - p.y * 0.42 - p.x * 0.18 + (n0 - 0.5) * 0.36, 0.0, 1.0)
			var shade := clampf(0.68 + upper_lit * 0.32 + n1 * 0.06, 0.64, 1.02)
			img.set_pixel(x, y, Color(shade, shade * 0.99, shade * 0.97, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["smoke"] = t
	return t


static func mix_f(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


## 风切颗粒扬尘贴图（256px 破碎絮状沙尘，适合脚步、冲刺尾流、落点尘环与着弹扬土）
static func dust_tex() -> Texture2D:
	if _tex_cache.has("dust_vfx"):
		return _tex_cache["dust_vfx"]
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 83
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.028
	nz.fractal_octaves = 4
	nz.fractal_gain = 0.56
	var nw := FastNoiseLite.new()
	nw.seed = 127
	nw.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nw.frequency = 0.015
	nw.fractal_octaves = 3
	var half := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) - half, float(y) - half) / (float(sz) * 0.5)
			var q := Vector2(p.x * 0.92, p.y * 1.12)
			var wx := nw.get_noise_2d(float(x) * 0.8, float(y) * 1.2) * 22.0
			var wy := nw.get_noise_2d(float(x) * 0.8 + 61.0, float(y) * 1.2 + 97.0) * 16.0
			var n0 := nz.get_noise_2d(float(x) + wx, float(y) + wy) * 0.5 + 0.5
			var n1 := nz.get_noise_2d(float(x) * 2.4 + wy, float(y) * 2.4 - wx) * 0.5 + 0.5
			var d := q.length() + (0.5 - n0) * 0.40 + (0.5 - n1) * 0.16
			var radial := smoothstep(0.95, 0.22, d)
			var grain := smoothstep(0.24, 0.82, n0 * 0.65 + n1 * 0.35)
			var a := clampf(radial * (0.34 + grain * 0.66) * 0.88, 0.0, 1.0)
			var shade := clampf(0.80 + n0 * 0.16 + (0.5 - q.y) * 0.08, 0.74, 1.0)
			img.set_pixel(x, y, Color(shade, shade * 0.99, shade * 0.96, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["dust_vfx"] = t
	return t


## 地面战术光圈贴图（锐利外圈 + 细内刻度环 + 柔和光晕，mipmap 抗锯齿）
static func ring_tex() -> Texture2D:
	if _tex_cache.has("ring"):
		return _tex_cache["ring"]
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var half := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var dx := (float(x) - half) / (float(sz) * 0.5)
			var dy := (float(y) - half) / (float(sz) * 0.5)
			var r := Vector2(dx, dy).length()
			var ang := atan2(dy, dx)
			# Segmented weathered stencil ticks instead of a solid geometric bullseye disc
			var arc_gap := smoothstep(0.24, 0.50, abs(sin(ang * 2.0)))
			var grain := 0.72 + 0.28 * sin(ang * 13.0 + r * 9.0) * cos(float(x) * 0.37 - float(y) * 0.41)
			var thin_band := exp(-pow((r - 0.875) / 0.020, 2.0)) * (0.20 + 0.80 * arc_gap)
			var tick_band := exp(-pow((r - 0.765) / 0.012, 2.0)) * pow(abs(cos(ang * 4.0)), 6.0) * 0.32
			var soft_halo := exp(-pow((r - 0.875) / 0.068, 2.0)) * (0.25 + 0.75 * arc_gap) * 0.16
			var edge := 1.0 - smoothstep(0.92, 0.99, r)
			var a := clampf((thin_band * 0.78 + tick_band + soft_halo) * grain * edge, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["ring"] = t
	return t

static func shockwave_tex() -> Texture2D:
	if _tex_cache.has("shockwave"):
		return _tex_cache["shockwave"]
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var half := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var dx := (float(x) - half) / (float(sz) * 0.5)
			var dy := (float(y) - half) / (float(sz) * 0.5)
			var r := Vector2(dx, dy).length()
			var ang := atan2(dy, dx)
			var turb := 0.45 * sin(ang * 3.0 + r * 5.0) + 0.32 * cos(ang * 5.0 - 1.4) + 0.23 * sin(ang * 9.0 + r * 4.2 + 0.9)
			var fine := sin(float(x) * 0.41 + float(y) * 0.33) * cos(float(x) * 0.27 - float(y) * 0.47)
			var rw := r + turb * 0.060 + fine * 0.016
			var front := exp(-pow((rw - 0.74) / 0.105, 2.0))
			var wake := exp(-pow((rw - 0.54) / 0.155, 2.0)) * 0.44
			var wisp := clampf(0.54 + 0.46 * (0.52 * sin(ang * 4.0 + 0.7) + 0.32 * cos(ang * 7.0 - r * 4.5) + 0.16 * sin(ang * 11.0 + 1.8)), 0.16, 1.0)
			var center := smoothstep(0.16, 0.44, r)
			var edge := 1.0 - smoothstep(0.84, 0.99, r)
			var a := clampf((front + wake) * wisp * center * edge * 0.86, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["shockwave"] = t
	return t


## 柔和薄雾 / 飘烟贴图（256px 不规则域扭曲云斑，无圆盘感）
static func cloud_tex() -> Texture2D:
	if _tex_cache.has("cloud"):
		return _tex_cache["cloud"]
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 7
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.020
	nz.fractal_octaves = 4
	var nw := FastNoiseLite.new()
	nw.seed = 29
	nw.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nw.frequency = 0.014
	nw.fractal_octaves = 3
	var half := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) - half, float(y) - half) / (float(sz) * 0.5)
			var wx := nw.get_noise_2d(float(x), float(y)) * 24.0
			var wy := nw.get_noise_2d(float(x) + 89.0, float(y) + 43.0) * 24.0
			var n := nz.get_noise_2d(float(x) + wx, float(y) + wy) * 0.5 + 0.5
			var d := p.length() + (0.5 - n) * 0.42
			var border := smoothstep(0.98, 0.70, maxf(absf(p.x), absf(p.y)))
			var fall := smoothstep(0.94, 0.16, d) * border
			var a := clampf(fall * smoothstep(0.24, 0.78, n), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["cloud"] = t
	return t


## 爆炸弹坑与放射性焦痕贴图（中心碳化坑洞 + 碎土环唇 + 不规则放射状烟炱喷射纹）
static func scorch_tex() -> Texture2D:
	if _tex_cache.has("scorch"):
		return _tex_cache["scorch"]
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 211
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.032
	nz.fractal_octaves = 4
	var nr := FastNoiseLite.new()
	nr.seed = 307
	nr.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nr.frequency = 0.055
	nr.fractal_octaves = 3
	var half := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) - half, float(y) - half) / (float(sz) * 0.5)
			var ang := atan2(p.y, p.x)
			var n0 := nz.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var n1 := nr.get_noise_2d(float(x) * 1.4, float(y) * 1.4) * 0.5 + 0.5
			# 放射状爆轰烟炱条纹
			var ray_samp := nz.get_noise_2d(cos(ang) * 44.0 + 128.0, sin(ang) * 44.0 + 128.0) * 0.5 + 0.5
			var ray_fine := nr.get_noise_2d(cos(ang) * 96.0 + 64.0, sin(ang) * 96.0 + 64.0) * 0.5 + 0.5
			var rays := smoothstep(0.32, 0.78, ray_samp * 0.65 + ray_fine * 0.35)
			var r := p.length() + (0.5 - n0) * 0.14
			var pit := smoothstep(0.38, 0.10, r + (n1 - 0.5) * 0.06)
			var rim := smoothstep(0.24, 0.36, r) * (1.0 - smoothstep(0.38, 0.54, r))
			var outer_soot := smoothstep(0.86, 0.30, r) * (0.28 + 0.72 * rays) * (0.45 + 0.55 * n0)
			var streak := smoothstep(1.00, 0.42, r) * rays * smoothstep(0.36, 0.72, n1) * 0.68
			var a := clampf(maxf(pit * 0.94, maxf(rim * 0.72, maxf(outer_soot * 0.78, streak))), 0.0, 1.0)
			# 中心黑炭 -> 翻起灰褐碎土唇缘 -> 深褐烟炱射线
			var col_pit := Color(0.035, 0.032, 0.03)
			var col_rim := Color(0.24, 0.20, 0.16)
			var col_soot := Color(0.08, 0.075, 0.07)
			var rgb := col_soot.lerp(col_rim, rim * 0.82).lerp(col_pit, pit)
			rgb *= 0.85 + 0.30 * n1
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["scorch"] = t
	return t


## 有机污渍 / 油渍 / 苔藓斑贴图（不规则域扭曲边界 + 微弱干燥潮汐边缘，替代纯黑圆点）
static func grime_stain_tex() -> Texture2D:
	if _tex_cache.has("grime_stain"):
		return _tex_cache["grime_stain"]
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 401
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.026
	nz.fractal_octaves = 4
	var nw := FastNoiseLite.new()
	nw.seed = 433
	nw.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nw.frequency = 0.015
	nw.fractal_octaves = 3
	var half := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) - half, float(y) - half) / (float(sz) * 0.5)
			var wx := nw.get_noise_2d(float(x), float(y)) * 28.0
			var wy := nw.get_noise_2d(float(x) + 47.0, float(y) + 93.0) * 28.0
			var n := nz.get_noise_2d(float(x) + wx, float(y) + wy) * 0.5 + 0.5
			var n2 := nz.get_noise_2d(float(x) * 2.2 - wy * 0.4, float(y) * 2.2 + wx * 0.4) * 0.5 + 0.5
			var d := p.length() + (0.5 - n) * 0.46 + (0.5 - n2) * 0.18
			var shape := smoothstep(0.94, 0.34, d)
			var rim := smoothstep(0.46, 0.72, d) * (1.0 - smoothstep(0.76, 0.94, d))
			var interior := 0.42 + 0.58 * smoothstep(0.22, 0.80, n * 0.65 + n2 * 0.35)
			var a := clampf(shape * maxf(interior, rim * 0.85), 0.0, 1.0)
			var v := clampf(0.82 + n2 * 0.18 - rim * 0.14, 0.65, 1.0)
			img.set_pixel(x, y, Color(v, v, v, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["grime_stain"] = t
	return t


static func blob_tex() -> Texture2D:
	if _tex_cache.has("blob"):
		return _tex_cache["blob"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_tex_cache["blob"] = t
	return t


## 玩家机甲脚下战术定位圆环贴图（内孔透明避免遮挡足部，外圈双环清晰锐利）
static func player_ring_tex() -> Texture2D:
	if _tex_cache.has("player_ring"):
		return _tex_cache["player_ring"]
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := float(sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var dx := (float(x) - c) / (float(sz) * 0.5)
			var dy := (float(y) - c) / (float(sz) * 0.5)
			var r := Vector2(dx, dy).length()
			var ang := atan2(dy, dx)
			# Four open diagonal compass brackets + subtle cardinal ticks, feathered edge
			var diag_mask := smoothstep(0.30, 0.58, abs(sin(ang * 2.0)))
			var card_tick := pow(abs(cos(ang * 2.0)), 18.0) * 0.45
			var main_band := exp(-pow((r - 0.805) / 0.022, 2.0)) * maxf(diag_mask, card_tick)
			var inner_hair := exp(-pow((r - 0.675) / 0.013, 2.0)) * diag_mask * 0.24
			var outer_glow := exp(-pow((r - 0.805) / 0.055, 2.0)) * diag_mask * 0.18
			var edge := 1.0 - smoothstep(0.90, 0.985, r)
			var a := clampf((main_band * 0.72 + inner_hair + outer_glow) * edge, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["player_ring"] = t
	return t


# ======================================================================
# 材质
# ======================================================================
static func _is_headless_server() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	var u := OS.get_cmdline_user_args()
	return ("--server" in u) or ("--dedicated" in u)

const WORLD_TEX_DIR := "res://assets/textures/world/"
static func world_tex(file: String) -> Texture2D:
	if _is_headless_server():
		return null
	var key := "wtex_" + file
	if _tex_cache.has(key):
		return _tex_cache[key]
	var t: Texture2D = null
	var path := WORLD_TEX_DIR + file
	if ResourceLoader.exists(path):
		t = load(path)
		if t != null:
			var chk := t.get_image()
			if chk != null and not chk.has_mipmaps():
				chk.generate_mipmaps()
				t = ImageTexture.create_from_image(chk)
	else:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


## 写实涂装（自定义着色器）：默认绑定轧制重工钢板底纹与法线凹凸，彻底消除大面积纯色塑料块。
static var _paint_shader: Shader
static func paint(c: Color, metal_val := 0.15, rough := 0.62, opts := {}) -> ShaderMaterial:
	var key := "paint%s|%.2f|%.2f|%s" % [c.to_html(), metal_val, rough, str(opts)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _paint_shader == null:
		_paint_shader = load("res://shaders/mech_paint_mobile.gdshader" if is_mobile_perf() else "res://shaders/mech_paint.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _paint_shader
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("metal_base", metal_val)
	m.set_shader_parameter("rough_base", rough)
	m.set_shader_parameter("noise_lo", noise_tex("grime_raw"))
	m.set_shader_parameter("noise_hi", noise_tex("hi_raw"))
	m.set_shader_parameter("albedo_tex", world_tex("steel_plate_a.png"))
	m.set_shader_parameter("use_albedo_tex", 1.0)
	m.set_shader_parameter("albedo_tex_scale", 0.24)
	m.set_shader_parameter("albedo_tex_strength", 0.52)
	m.set_shader_parameter("normal_tex", world_tex("steel_plate_n.png"))
	m.set_shader_parameter("normal_strength", 0.52)
	if not opts.has("panel_scale"):
		m.set_shader_parameter("panel_scale", 0.0)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	_mat_cache[key] = m
	return m


static func metal(c := Color(0.28, 0.30, 0.33)) -> ShaderMaterial:
	var mc := Color(maxf(c.r, 0.27), maxf(c.g, 0.28), maxf(c.b, 0.30)).lerp(c.lightened(0.18), 0.45)
	return paint(mc, 0.65, 0.36, {
		"wear": 0.36, "panel_scale": 0.0, "dust": 0.10, "rust": 0.06,
		"scratches": 0.30, "bare_metal": mc.lightened(0.48),
		"albedo_tex_strength": 0.42, "normal_strength": 0.45,
	})


static func chrome() -> ShaderMaterial:
	return paint(Color(0.68, 0.70, 0.72), 0.90, 0.24, {
		"wear": 0.0, "panel_scale": 0.0, "dust": 0.08, "rust": 0.0,
		"scratches": 0.16, "grime": 0.16, "albedo_tex_strength": 0.22, "normal_strength": 0.18,
	})


static func rubber() -> ShaderMaterial:
	return paint(Color(0.065, 0.065, 0.07), 0.0, 0.88, {
		"use_albedo_tex": 0.0, "normal_tex": world_tex("asphalt_n.png"), "normal_strength": 0.28,
		"wear": 0.0, "panel_scale": 0.0, "scratches": 0.0, "rust": 0.0, "dust": 0.45,
	})


static func emit(c: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "emit%s|%.2f" % [c.to_html(), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	_mat_cache[key] = m
	return m


static func hazard() -> ShaderMaterial:
	return paint(Color(1, 1, 1), 0.1, 0.6, {"stripes": 1.0, "panel_scale": 0.0, "wear": 0.8, "albedo_tex_strength": 0.35})


static var _glass_shader: Shader
## 写实重工钢框窗格与采光天窗（带钢窗棂凹凸、污渍雨痕、室内结构剪影与克制内透，彻底消灭纯青/纯黑无贴图色块）
static func window_mat(lit_chance := 0.14, pitch := Vector2(1.05, 1.25), tint := Color(0.10, 0.13, 0.16), emit_col := Color(0.92, 0.68, 0.36), emit_str := 0.45) -> ShaderMaterial:
	var key := "winm|%.2f|%s|%s|%s|%.2f" % [lit_chance, str(pitch), tint.to_html(), emit_col.to_html(), emit_str]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _glass_shader == null:
		_glass_shader = load("res://shaders/ind_glass.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _glass_shader
	m.set_shader_parameter("glass_tint", tint)
	m.set_shader_parameter("frame_color", Color(0.14, 0.145, 0.15))
	m.set_shader_parameter("lit_color", emit_col)
	m.set_shader_parameter("mullion_u", pitch.x)
	m.set_shader_parameter("mullion_v", pitch.y)
	m.set_shader_parameter("lit_chance", lit_chance)
	m.set_shader_parameter("emit_strength", emit_str)
	m.set_shader_parameter("dirt_amount", 0.44)
	m.set_shader_parameter("noise_tex", noise_tex("grime_raw"))
	_mat_cache[key] = m
	return m


static func glass(c: Color) -> ShaderMaterial:
	# 将亮青/亮蓝纯色发光块收敛为烟灰钢框工业采光窗与控制室玻璃
	var muted := Color(lerpf(c.r, 0.85, 0.35), lerpf(c.g, 0.72, 0.35), lerpf(c.b, 0.52, 0.35))
	return window_mat(0.52, Vector2(0.88, 1.08), c.darkened(0.72), muted, 0.48)


## 现浇模板混凝土：宽模板缝（防桥墩/护墙横线摩尔纹）+ 废土雨水烟熏与钢筋渗锈做旧
static func concrete(c: Color, seams := true) -> ShaderMaterial:
	return paint(c, 0.0, 0.91, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("concrete_a.png"), "albedo_tex_scale": 0.11, "albedo_tex_strength": 0.50,
		"normal_tex": world_tex("concrete_n.png"), "normal_strength": 0.40,
		"wear": 0.48, "metal_wear": 0.0, "bare_metal": c.lightened(0.20), "scratches": 0.0,
		"rust": 0.44, "rust_color": Color(0.22, 0.16, 0.11), "grime": 0.74, "dust": 0.26, "dust_color": Color(0.38, 0.35, 0.30),
		"panel_scale": 0.22 if seams else 0.0, "detail_scale": 0.82,
	})


## 重工业顺丁错缝窑变砖墙：沉稳风化陶砖 + 雨渍烟灰做旧
static func brick(c := Color(0.42, 0.27, 0.20), scale := 0.28) -> ShaderMaterial:
	return paint(c, 0.0, 0.90, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("brick_a.png"), "albedo_tex_scale": scale * 0.84, "albedo_tex_strength": 0.76,
		"normal_tex": world_tex("brick_n.png"), "normal_strength": 0.66,
		"wear": 0.44, "metal_wear": 0.0, "bare_metal": c.lightened(0.18), "scratches": 0.0,
		"rust": 0.36, "rust_color": Color(0.17, 0.13, 0.10), "grime": 0.72, "dust": 0.22, "dust_color": Color(0.40, 0.36, 0.31),
		"panel_scale": 0.0, "detail_scale": 0.92,
	})


## 梯形压型波纹钢墙板：宽距压型肋 + 工业锈蚀镀锌钢质感（防高频白条闪烁同时保留废土锈蚀）
static func corrugated(c: Color, rust_amt := 0.36, scale := 0.22) -> ShaderMaterial:
	return paint(c, 0.36, 0.66, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("corrugated_a.png"), "albedo_tex_scale": scale * 0.74, "albedo_tex_strength": 0.64,
		"normal_tex": world_tex("corrugated_n.png"), "normal_strength": 0.48,
		"wear": 0.54, "metal_wear": 1.0, "scratches": 0.24,
		"rust": minf(rust_amt * 1.10, 0.92), "grime": 0.68, "dust": 0.22,
		"panel_scale": 0.0, "detail_scale": 0.92,
	})


## 直立锁边 / 重工金属瓦屋面：锈蚀铁皮与工业落灰质感
static func roof_mat(c: Color, rust_amt := 0.32, sloped := true) -> ShaderMaterial:
	return paint(c, 0.32, 0.72, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("roof_seam_a.png"), "albedo_tex_scale": 0.19, "albedo_tex_strength": 0.66,
		"normal_tex": world_tex("roof_seam_n.png"), "normal_strength": 0.48,
		"roof_uv": 1.0 if sloped else 0.0,
		"wear": 0.48, "metal_wear": 1.0, "scratches": 0.18,
		"rust": minf(rust_amt * 1.05, 0.88), "grime": 0.64, "dust": 0.26,
		"panel_scale": 0.0, "detail_scale": 0.92,
	})


## 沥青油毡防水工业平屋面：深炭旧油毡与风化尘渍
static func tar_roof(c := Color(0.24, 0.25, 0.26), dust_amt := 0.26) -> ShaderMaterial:
	return paint(c, 0.0, 0.90, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("tar_roof_a.png"), "albedo_tex_scale": 0.20, "albedo_tex_strength": 0.62,
		"normal_tex": world_tex("tar_roof_n.png"), "normal_strength": 0.48,
		"roof_uv": 1.0,
		"wear": 0.34, "metal_wear": 0.0, "bare_metal": c.lightened(0.14), "scratches": 0.0,
		"rust": 0.28, "rust_color": Color(0.16, 0.14, 0.12), "grime": 0.66, "dust": dust_amt, "dust_color": Color(0.36, 0.34, 0.30),
		"panel_scale": 0.0, "detail_scale": 0.90,
	})


## 粗骨料工业沥青路面：深炭黑湿润沥青 + 磨耗骨料肌理
static func asphalt(c := Color(0.20, 0.205, 0.215)) -> ShaderMaterial:
	return paint(c, 0.0, 0.80, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("asphalt_a.png"), "albedo_tex_scale": 0.28, "albedo_tex_strength": 0.62,
		"normal_tex": world_tex("asphalt_n.png"), "normal_strength": 0.48,
		"wear": 0.28, "metal_wear": 0.0, "bare_metal": c.lightened(0.14), "scratches": 0.0,
		"rust": 0.22, "rust_color": Color(0.14, 0.13, 0.12), "grime": 0.56,
		"dust": 0.16, "dust_color": Color(0.30, 0.28, 0.25),
		"panel_scale": 0.0, "detail_scale": 0.92,
	})


## 压实道砟 / 砂砾河滩与土路材质（低频干净颗粒，抑制远距沙粒闪点）
static func gravel_mat(c := Color(0.38, 0.35, 0.31), rough := 0.92) -> ShaderMaterial:
	return paint(c, 0.0, rough, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("ground_gravel_a.png"), "albedo_tex_scale": 0.24, "albedo_tex_strength": 0.58,
		"normal_tex": world_tex("ground_gravel_n.png"), "normal_strength": 0.48,
		"wear": 0.12, "metal_wear": 0.0, "bare_metal": c.lightened(0.10), "scratches": 0.0,
		"rust": 0.16, "rust_color": c.darkened(0.24), "grime": 0.40,
		"dust": 0.14, "dust_color": c.lightened(0.06),
		"panel_scale": 0.0, "detail_scale": 0.90,
	})


## 自然层理山岩 / 碎石：沉积岩倾斜层理 + 连续风化节理凹凸
static func rock_mat(c: Color) -> ShaderMaterial:
	return paint(c, 0.0, 0.95, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("rock_strata_a.png"), "albedo_tex_scale": 0.16, "albedo_tex_strength": 0.88,
		"normal_tex": world_tex("rock_strata_n.png"), "normal_strength": 1.05,
		"wear": 0.24, "metal_wear": 0.0, "bare_metal": c.lightened(0.10), "scratches": 0.0,
		"rust": 0.46, "rust_color": c.darkened(0.34), "grime": 0.86,
		"dust": 0.28, "dust_color": c.lightened(0.07),
		"panel_scale": 0.0, "detail_scale": 0.80,
	})


## 纵裂老树皮材质
static func bark_mat(c := Color(0.30, 0.24, 0.19)) -> ShaderMaterial:
	return paint(c, 0.0, 0.96, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("bark_a.png"), "albedo_tex_scale": 0.42, "albedo_tex_strength": 0.92,
		"normal_tex": world_tex("bark_n.png"), "normal_strength": 1.08,
		"wear": 0.12, "metal_wear": 0.0, "bare_metal": c.lightened(0.10), "scratches": 0.0,
		"rust": 0.30, "rust_color": c.darkened(0.32), "grime": 0.72,
		"dust": 0.15, "dust_color": Color(0.36, 0.33, 0.27),
		"panel_scale": 0.0, "detail_scale": 1.0,
	})


static var _foliage_shader: Shader
## 双面裁切植物材质（kind: "pine" 针叶 / "broad" 阔叶 / "autumn" 荒原枯黄阔叶 / "shrub" 灌木 / "grass" 野草芦苇）
static func foliage_mat(kind := "pine") -> ShaderMaterial:
	var key := "fol_" + kind
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _foliage_shader == null:
		_foliage_shader = load("res://shaders/foliage_mobile.gdshader" if is_mobile_perf() else "res://shaders/foliage.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _foliage_shader
	m.set_meta("no_outline", true)
	match kind:
		"pine":
			m.set_shader_parameter("albedo_tex", world_tex("pine_frond_a.png"))
			m.set_shader_parameter("normal_tex", world_tex("pine_frond_n.png"))
			m.set_shader_parameter("use_normal", 1.0)
			m.set_shader_parameter("tint_a", Color(0.84, 0.88, 0.76))
			m.set_shader_parameter("tint_b", Color(0.98, 0.94, 0.78))
			m.set_shader_parameter("albedo_gain", 1.18)
			m.set_shader_parameter("rough_val", 0.82)
			m.set_shader_parameter("alpha_cut", 0.34)
			m.set_shader_parameter("sway_amp", 0.04)
			m.set_shader_parameter("backlight_str", 0.36)
		"broad":
			m.set_shader_parameter("albedo_tex", world_tex("broadleaf_a.png"))
			m.set_shader_parameter("normal_tex", world_tex("broadleaf_n.png"))
			m.set_shader_parameter("use_normal", 1.0)
			m.set_shader_parameter("tint_a", Color(0.84, 0.88, 0.74))
			m.set_shader_parameter("tint_b", Color(1.02, 0.92, 0.70))
			m.set_shader_parameter("albedo_gain", 1.14)
			m.set_shader_parameter("rough_val", 0.82)
			m.set_shader_parameter("alpha_cut", 0.34)
			m.set_shader_parameter("sway_amp", 0.05)
			m.set_shader_parameter("backlight_str", 0.34)
		"autumn":
			m.set_shader_parameter("albedo_tex", world_tex("broadleaf_a.png"))
			m.set_shader_parameter("normal_tex", world_tex("broadleaf_n.png"))
			m.set_shader_parameter("use_normal", 1.0)
			m.set_shader_parameter("tint_a", Color(1.02, 0.76, 0.50))
			m.set_shader_parameter("tint_b", Color(1.16, 0.86, 0.56))
			m.set_shader_parameter("albedo_gain", 1.14)
			m.set_shader_parameter("rough_val", 0.84)
			m.set_shader_parameter("alpha_cut", 0.36)
			m.set_shader_parameter("sway_amp", 0.045)
		"shrub":
			m.set_shader_parameter("albedo_tex", world_tex("broadleaf_a.png"))
			m.set_shader_parameter("normal_tex", world_tex("broadleaf_n.png"))
			m.set_shader_parameter("use_normal", 1.0)
			m.set_shader_parameter("tint_a", Color(0.82, 0.86, 0.70))
			m.set_shader_parameter("tint_b", Color(0.96, 0.88, 0.68))
			m.set_shader_parameter("albedo_gain", 1.20)
			m.set_shader_parameter("rough_val", 0.84)
			m.set_shader_parameter("alpha_cut", 0.32)
			m.set_shader_parameter("sway_amp", 0.025)
		"grass":
			m.set_shader_parameter("albedo_tex", world_tex("grass_tuft_a.png"))
			m.set_shader_parameter("use_normal", 0.0)
			m.set_shader_parameter("tint_a", Color(0.78, 0.80, 0.58))
			m.set_shader_parameter("tint_b", Color(0.92, 0.82, 0.56))
			m.set_shader_parameter("albedo_gain", 2.30)
			m.set_shader_parameter("up_normal_blend", 0.82)
			m.set_shader_parameter("rough_val", 0.90)
			m.set_shader_parameter("alpha_cut", 0.28)
			m.set_shader_parameter("sway_amp", 0.055)
			m.set_shader_parameter("backlight_str", 0.42)
	_mat_cache[key] = m
	return m


## 虫族甲壳：低粗糙度、湿润高光。
static var _chitin_shader: Shader
static func chitin(c: Color, opts := {}) -> ShaderMaterial:
	var key := "chitin%s%s" % [c.to_html(), str(opts)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _chitin_shader == null:
		_chitin_shader = load("res://shaders/bug_chitin.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _chitin_shader
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("noise_lo", noise_tex("grime_raw"))
	m.set_shader_parameter("noise_hi", noise_tex("hi_raw"))
	m.set_shader_parameter("normal_tex", noise_tex("normal"))
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	_mat_cache[key] = m
	return m


## 写实虫族材质：离线手绘贴图（tools/gen_bug_textures.py 生成），按网格自身 UV 贴附。
## part: "shell" 甲壳 / "leg" 腿节 / "eye" 复眼 / "membrane" 节间膜 / "sac" 酸囊 / "claw" 颚爪
const BUG_TEX_DIR := "res://assets/textures/bugs/"
static func _bug_tex(file: String) -> Texture2D:
	if _is_headless_server():
		return null
	var key := "bugtex_" + file
	if _mat_cache.has(key):
		return _mat_cache[key]
	var t: Texture2D = null
	var path := BUG_TEX_DIR + file
	if ResourceLoader.exists(path):
		t = load(path)
		if t != null:
			var chk := t.get_image()
			if chk != null and not chk.has_mipmaps():
				chk.generate_mipmaps()
				t = ImageTexture.create_from_image(chk)
	else:  # 未经编辑器导入时（纯命令行运行）直接读 PNG
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_mat_cache[key] = t
	return t


static func bug_mat(kind: String, part := "shell", tint := Color.WHITE, uv_scale := Vector2.ONE) -> StandardMaterial3D:
	var key := "bugmat_%s_%s_%s_%s" % [kind, part, tint.to_html(), str(uv_scale)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mob := is_mobile_perf()
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if mob else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.normal_enabled = not mob
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if mob else BaseMaterial3D.DIFFUSE_BURLEY
	match part:
		"shell":
			m.albedo_texture = _bug_tex("chitin_%s.png" % kind)
			if not mob:
				m.normal_texture = _bug_tex("chitin_n.png")
				m.normal_scale = 1.0
				m.roughness_texture = _bug_tex("chitin_r.png")
				m.roughness = 1.0
				m.clearcoat_enabled = true
				m.clearcoat = 0.55
				m.clearcoat_roughness = 0.25
				m.rim_enabled = true
				m.rim = 0.12
				m.rim_tint = 0.6
			else:
				m.roughness = 0.48
		"leg":
			m.albedo_texture = _bug_tex("leg_%s.png" % kind)
			if not mob:
				m.normal_texture = _bug_tex("leg_n.png")
				m.roughness_texture = _bug_tex("leg_r.png")
				m.roughness = 1.0
				m.clearcoat_enabled = true
				m.clearcoat = 0.3
				m.clearcoat_roughness = 0.35
			else:
				m.roughness = 0.52
		"eye":
			m.albedo_texture = _bug_tex("eye_a.png")
			m.roughness = 0.12
			m.metallic_specular = 0.8
			if not mob:
				m.normal_texture = _bug_tex("eye_n.png")
				m.normal_scale = 0.8
				m.clearcoat_enabled = true
				m.clearcoat = 1.0
				m.clearcoat_roughness = 0.05
		"membrane":
			m.albedo_texture = _bug_tex("membrane_a.png")
			m.roughness = 0.4
			if not mob:
				m.normal_texture = _bug_tex("membrane_n.png")
				m.subsurf_scatter_enabled = true
				m.subsurf_scatter_strength = 0.4
		"sac":
			m.albedo_texture = _bug_tex("sac_a.png")
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = Color(0.35, 0.6, 0.1)
			m.emission_energy_multiplier = 0.3
			m.emission_texture = _bug_tex("sac_e.png")
			if not mob:
				m.normal_texture = _bug_tex("membrane_n.png")
				m.clearcoat_enabled = true
				m.clearcoat = 1.0
				m.clearcoat_roughness = 0.15
		"claw":
			m.albedo_texture = _bug_tex("claw_a.png")
			m.roughness = 0.3
			if not mob:
				m.normal_texture = _bug_tex("leg_n.png")
				m.normal_scale = 0.5
				m.clearcoat_enabled = true
				m.clearcoat = 0.6
	_mat_cache[key] = m
	return m


## 虫族菌毯：带发光脉络的地表贴片。
static func creep() -> StandardMaterial3D:
	if _mat_cache.has("creep"):
		return _mat_cache["creep"]
	var mob := is_mobile_perf()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.11, 0.08, 0.06, 0.82)
	m.albedo_texture = noise_tex("grime")
	m.emission_enabled = true
	m.emission = Color(0.45, 0.2, 0.06)
	m.emission_energy_multiplier = 0.08
	m.emission_texture = noise_tex("creep")
	m.roughness = 0.28
	if mob:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
		m.uv1_scale = Vector3(1.8, 1.8, 1.8)
	else:
		m.normal_enabled = true
		m.normal_texture = noise_tex("ground_n", 512)
		m.normal_scale = 1.35
		m.clearcoat_enabled = true
		m.clearcoat = 0.65
		m.clearcoat_roughness = 0.2
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	_mat_cache["creep"] = m
	return m


static func _ground_mobile() -> ShaderMaterial:
	if _mat_cache.has("ground"):
		return _mat_cache["ground"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grav_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grav_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D conc_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D conc_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 dirt_a : source_color = vec3(0.46, 0.41, 0.32);
uniform vec3 dirt_b : source_color = vec3(0.32, 0.27, 0.20);
uniform vec3 mud : source_color = vec3(0.25, 0.21, 0.17);
uniform vec3 grass : source_color = vec3(0.28, 0.31, 0.17);
uniform vec3 grass2 : source_color = vec3(0.39, 0.38, 0.23);
uniform sampler2D zone_tex : filter_linear, repeat_disable;
uniform sampler2D sector_tex : filter_linear, repeat_disable;
uniform float zone_half = 180.0;
uniform float zone_on = 0.0;
uniform float sector_on = 0.0;
uniform float wet_amt = 0.0;
varying highp vec3 wp;

void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	highp vec2 p = wp.xz;
	float low = texture(n_low, p * 0.0055).r;
	float mid = texture(n_low, p * 0.021 + 0.37).r;
	float hi = texture(n_hi, p * 0.095).r;

	// 写实废土地表混合：恢复中频干土/碎石/混凝土实物质感（继续保持低噪防远距闪点）
	highp vec2 p_rot = vec2(p.x * 0.80 - p.y * 0.60, p.x * 0.60 + p.y * 0.80);
	float macro_var = texture(n_low, p_rot * 0.0085 + vec2(0.19, 0.71)).r;
	vec3 s_col = mix(vec3(0.72), texture(soil_a, p * 0.19).rgb * 1.16, 0.64);
	vec3 g_col = mix(vec3(0.72), texture(grav_a, p * 0.21).rgb * 1.18, 0.66);
	vec3 c_col = mix(vec3(0.74), texture(conc_a, p * 0.14).rgb * 1.15, 0.58);

	vec3 col = mix(dirt_b, dirt_a, smoothstep(0.26, 0.74, low + (hi - 0.5) * 0.16)) * s_col * 1.16;
	float mudm = smoothstep(0.66, 0.86, mid + (hi - 0.5) * 0.12);
	col = mix(col, mud * s_col * 1.16, mudm * 0.34);

	float gm = smoothstep(0.44, 0.74, 1.0 - mid + (low - 0.5) * 0.36 + (hi - 0.5) * 0.10) * (1.0 - mudm * 0.55);
	vec3 gcol = mix(grass, grass2, smoothstep(0.28, 0.72, low * 0.6 + hi * 0.4)) * mix(vec3(1.0), s_col * 1.24, 0.42);
	col = mix(col, gcol, gm * 0.78);

	float grav_patch = smoothstep(0.58, 0.80, hi * 0.55 + (1.0 - low) * 0.45) * (1.0 - gm * 0.75);
	col = mix(col, dirt_a * 0.90 * g_col * 1.24, grav_patch * 0.44);
	col *= mix(0.88, 1.12, low * 0.55 + macro_var * 0.45);

	vec2 bfade = smoothstep(vec2(zone_half + 4.0), vec2(zone_half - 14.0), abs(p));
	float zfade = bfade.x * bfade.y * zone_on;
	vec2 z_uv = clamp((p + zone_half) / (zone_half * 2.0) + (vec2(low, mid) - 0.5) * 0.014, vec2(0.002), vec2(0.998));
	vec4 zt = texture(zone_tex, z_uv) * zfade;

	float row_id = floor(p.y / 2.4);
	vec2 slab_uv = vec2((p.x + mod(row_id, 2.0) * 1.8) / 3.6, p.y / 2.4);
	vec2 tf = abs(fract(slab_uv) - 0.5);
	float seam = smoothstep(0.476, 0.495, max(tf.x, tf.y)) * smoothstep(0.48, 0.80, zt.r);
	vec3 pave = vec3(0.29, 0.285, 0.27) * c_col * 1.22 * mix(0.90, 1.08, low * 0.6 + macro_var * 0.4) * (1.0 - seam * 0.36);
	float pm = smoothstep(0.28, 0.72, zt.r + (low - 0.5) * 0.12 + (mid - 0.5) * 0.08);
	col = mix(col, pave, pm);

	vec3 gr = mix(vec3(0.18, 0.22, 0.12), vec3(0.29, 0.30, 0.17), smoothstep(0.25, 0.75, low * 0.6 + macro_var * 0.4)) * mix(vec3(1.0), s_col * 1.24, 0.42);
	float gmm = smoothstep(0.24, 0.76, zt.g + (low - 0.5) * 0.15 + (mid - 0.5) * 0.16) * (1.0 - pm * 0.84);
	col = mix(col, gr, gmm);

	vec3 soil = mix(vec3(0.22, 0.18, 0.13), vec3(0.31, 0.25, 0.17), mid) * s_col * 1.24;
	float smm = smoothstep(0.24, 0.78, zt.b + (low - 0.5) * 0.16 + (mid - 0.5) * 0.14);
	col = mix(col, soil, smm);

	vec3 grv = mix(vec3(0.22, 0.215, 0.20), vec3(0.28, 0.265, 0.24), low * 0.6 + macro_var * 0.4) * g_col * 1.24;
	float am = smoothstep(0.28, 0.74, zt.a + (low - 0.5) * 0.14 + (mid - 0.5) * 0.10) * (1.0 - pm * 0.55);
	col = mix(col, grv, am);

	float road_v = 0.0;
	float bldg_contact = 0.0;
	if (abs(sector_on) > 0.5) {
		vec2 s_uv = (p + zone_half) / (zone_half * 2.0);
		float s_in = 0.0;
		if (s_uv.x >= 0.0 && s_uv.x <= 1.0 && s_uv.y >= 0.0 && s_uv.y <= 1.0) {
			vec3 sec = texture(sector_tex, s_uv).rgb;
			s_in = smoothstep(0.20, 0.80, sec.r + (low - 0.5) * 0.16);
			road_v = sec.g * (1.0 - pm * 0.48);
			bldg_contact = sec.b;
		}
		col = mix(col, grv * 0.86, road_v * 0.65);
		col *= mix(vec3(1.0), vec3(0.50, 0.52, 0.55), bldg_contact * 0.68);
		vec3 out_mul = (sector_on > 0.0) ? vec3(0.74, 0.75, 0.78) : vec3(0.24, 0.22, 0.28);
		col = mix(col * out_mul, col, s_in);
	}
	// 写实雨后泥地湿润反光与克制积水
	float w_amt = clamp(wet_amt, 0.0, 1.0);
	float p_allow = (1.0 - gmm * 0.82) * (1.0 - smm * 0.75);
	float basin = 0.50 + (0.5 - low) * 0.74 + (macro_var - 0.5) * 0.56 + (mid - 0.5) * 0.28;
	float puddle = w_amt * p_allow * smoothstep(0.700, 0.795, basin);
	float soak = w_amt * p_allow * smoothstep(0.600, 0.730, basin);
	col *= mix(1.0, 0.86, w_amt * 0.28);
	col *= mix(1.0, 0.78, soak * 0.62);
	col = mix(col, col * 0.56 + vec3(0.018, 0.022, 0.028), puddle * 0.72);
	ALBEDO = col;

	vec3 n_det = mix(texture(soil_n, p * 0.19).rgb, texture(conc_n, p * 0.14).rgb, pm);
	vec3 n_macro = texture(n_nrm, p * 0.055).rgb;
	vec3 n_comb = normalize((n_det * 2.0 - 1.0) * 0.48 + (n_macro * 2.0 - 1.0) * 0.42 + vec3(0.0, 0.0, 0.76));
	n_comb = normalize(mix(n_comb, vec3(0.0, 0.0, 1.0), puddle * 0.85));
	ROUGHNESS = mix(mix(0.90, 0.80, pm), 0.13, puddle * 0.90);
	ROUGHNESS = mix(ROUGHNESS, 0.40, soak * 0.60 * (1.0 - puddle));
	SPECULAR = mix(0.28, 0.56, puddle * 0.85);
	AO = clamp(1.0 - pm * seam * 0.34 - road_v * 0.16 - bldg_contact * 0.66, 0.22, 1.0);
	AO_LIGHT_AFFECT = 0.68;
	NORMAL_MAP = n_comb * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.52 * (1.0 - puddle * 0.82);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("n_low", noise_tex("grime_raw", 512))
	m.set_shader_parameter("n_hi", noise_tex("hi_raw", 512))
	m.set_shader_parameter("n_nrm", noise_tex("ground_n", 512))
	m.set_shader_parameter("soil_a", world_tex("ground_soil_a.png"))
	m.set_shader_parameter("soil_n", world_tex("ground_soil_n.png"))
	m.set_shader_parameter("grav_a", world_tex("ground_gravel_a.png"))
	m.set_shader_parameter("grav_n", world_tex("ground_gravel_n.png"))
	m.set_shader_parameter("conc_a", world_tex("concrete_a.png"))
	m.set_shader_parameter("conc_n", world_tex("concrete_n.png"))
	m.set_shader_parameter("wet_amt", 0.0)
	m.set_meta("no_outline", true)
	_mat_cache["ground"] = m
	return m


static func ground() -> ShaderMaterial:
	if is_mobile_perf():
		return _ground_mobile()
	# 写实工业废土地表着色器：多尺度双角旋转无缝混合 壤土碎石 / 压实道砟 / 现浇混凝土 / 荒原草甸 / 泥滩，彻底消除全图蜂窝网格伪影与马赛克噪点
	if _mat_cache.has("ground"):
		return _mat_cache["ground"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D n_low : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_hi : filter_linear_mipmap, repeat_enable;
uniform sampler2D n_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grav_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grav_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D conc_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D conc_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 dirt_a : source_color = vec3(0.46, 0.41, 0.32);
uniform vec3 dirt_b : source_color = vec3(0.32, 0.27, 0.20);
uniform vec3 mud : source_color = vec3(0.25, 0.21, 0.17);
uniform vec3 grass : source_color = vec3(0.28, 0.31, 0.17);
uniform vec3 grass2 : source_color = vec3(0.39, 0.38, 0.23);
uniform sampler2D zone_tex : filter_linear, repeat_disable;
uniform sampler2D sector_tex : filter_linear, repeat_disable;
uniform float zone_half = 180.0;
uniform float zone_on = 0.0;
uniform float sector_on = 0.0;
uniform float wet_amt = 0.0;
global uniform float weather_rain;
varying vec3 wp;

vec2 h2(vec2 p){ p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
vec2 g_ripple(vec2 p, float t){
	vec2 sl = vec2(0.0);
	for (int i = 0; i < 2; i++){
		float sc = i == 0 ? 1.40 : 2.20;
		vec2 gp = p * sc + float(i) * vec2(13.7, 7.9);
		vec2 cell = floor(gp);
		vec2 f = fract(gp) - 0.5;
		vec2 h = h2(cell);
		vec2 dv = f - (h - 0.5) * 0.52;
		float d = length(dv);
		float cyc = fract(t * (0.86 + float(i) * 0.29) + fract(h.x * 6.31 + h.y * 4.17));
		float rad = cyc * 0.44;
		float env = exp(-abs(d - rad) * 34.0) * (1.0 - cyc) * (1.0 - cyc) * smoothstep(0.008, 0.045, d);
		sl += (dv / max(d, 1e-3)) * cos((d - rad) * 68.0) * env;
	}
	return sl * 0.14;
}
float cracks(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++){
		vec2 g = vec2(float(x), float(y));
		vec2 o = h2(i + g);
		float d = length(g + o - f);
		if (d < d1){ d2 = d1; d1 = d; } else if (d < d2){ d2 = d; }
	}
	return d2 - d1;
}
vec2 rot2(vec2 q){ return vec2(q.x * 0.80 - q.y * 0.60, q.x * 0.60 + q.y * 0.80); }

void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz;
	float low = texture(n_low, p * 0.0055).r;
	float med2 = texture(n_low, p * 0.0085 + vec2(0.19, 0.71)).r;
	float mid = texture(n_low, p * 0.021 + 0.37).r;
	float hi = texture(n_hi, p * 0.095).r;
	float hi2 = texture(n_hi, p * 0.42 + 0.2).r;
	float fw = clamp(1.0 - length(fwidth(p)) * 0.42, 0.0, 1.0);
	float hi2_aa = mix(0.5, hi2, fw);

	// 写实废土双角旋转混合：保留中频碎石/干土/风化混凝土板肌理与龟裂，远距自动降频防沙粒闪点
	vec2 uv_a = p * 0.20;
	vec2 uv_b = rot2(p * 0.14 + vec2(7.3, 11.9));
	float m_blend = smoothstep(0.28, 0.72, med2);
	vec2 uv_ga = p * 0.22;
	vec2 uv_gb = rot2(p * 0.15 + vec2(3.7, 5.1));
	vec2 uv_ca = p * 0.14;
	vec2 uv_cb = rot2(p * 0.10 + vec2(9.1, 2.3));
	vec3 s_col = mix(vec3(0.72), mix(texture(soil_a, uv_a).rgb, texture(soil_a, uv_b).rgb, m_blend) * 1.16, 0.64);
	vec3 g_col = mix(vec3(0.72), mix(texture(grav_a, uv_ga).rgb, texture(grav_a, uv_gb).rgb, m_blend) * 1.18, 0.66);
	vec3 c_col = mix(vec3(0.74), mix(texture(conc_a, uv_ca).rgb, texture(conc_a, uv_cb).rgb, m_blend) * 1.15, 0.58);

	vec3 col = mix(dirt_b, dirt_a, smoothstep(0.26, 0.74, low + (hi - 0.5) * 0.16)) * s_col * 1.16;

	// 废土干涸泥滩龟裂与压实泥泞过渡
	float mudm = smoothstep(0.66, 0.86, mid + (hi - 0.5) * 0.12);
	float cr = cracks(p * 0.36 + vec2(low, mid) * 1.4);
	float crack_mud = (1.0 - smoothstep(0.015, 0.068, cr)) * mudm;
	col = mix(col, mud * s_col * 1.16, mudm * 0.34);
	col *= 1.0 - crack_mud * 0.34;

	// 荒原衰草与尘苔：克制脱饱和的枯绿与褐草
	float gm = smoothstep(0.44, 0.74, 1.0 - mid + (low - 0.5) * 0.38 + (hi - 0.5) * 0.12) * (1.0 - mudm * 0.55);
	vec3 gcol = mix(grass, grass2, smoothstep(0.26, 0.74, low * 0.55 + hi2_aa * 0.45)) * mix(vec3(1.0), s_col * 1.24, 0.42);
	col = mix(col, gcol, gm * 0.78 * smoothstep(0.18, 0.62, hi2_aa + 0.18));

	// 散落粗骨料与废墟碎砾斑块
	float grav_patch = smoothstep(0.58, 0.80, hi * 0.55 + (1.0 - low) * 0.45) * (1.0 - gm * 0.72);
	col = mix(col, dirt_a * 0.90 * g_col * 1.24, grav_patch * 0.44);
	col *= mix(0.87, 1.12, low * 0.55 + med2 * 0.45);

	// 分区地表：R 风化混凝土场坪 / G 废土荒草 / B 翻耕泥土 / A 工业压实油渣道砟
	vec2 bfade = smoothstep(vec2(zone_half + 4.0), vec2(zone_half - 14.0), abs(p));
	float zfade = bfade.x * bfade.y * zone_on;
	vec2 z_uv = clamp((p + zone_half) / (zone_half * 2.0) + (vec2(low, mid) - 0.5) * 0.014, vec2(0.002), vec2(0.998));
	vec4 zt = texture(zone_tex, z_uv) * zfade;

	float row_id = floor(p.y / 2.4);
	vec2 slab_uv = vec2((p.x + mod(row_id, 2.0) * 1.8) / 3.6, p.y / 2.4);
	vec2 tf = abs(fract(slab_uv) - 0.5);
	float seam_mask = smoothstep(0.46, 0.80, zt.r) * (1.0 - smoothstep(0.66, 0.88, mid));
	float seam = smoothstep(0.476, 0.495, max(tf.x, tf.y)) * seam_mask;
	float tar_seal = smoothstep(0.486, 0.498, max(tf.x, tf.y)) * seam_mask;
	float slab_var = fract(sin(dot(floor(slab_uv), vec2(41.3, 289.1))) * 43758.5453);
	vec3 pave = vec3(0.29, 0.285, 0.27) * c_col * 1.22 * mix(0.90, 1.08, low * 0.6 + med2 * 0.4) * (0.91 + slab_var * 0.16);
	pave *= 1.0 - seam * 0.34;
	pave = mix(pave, vec3(0.10, 0.105, 0.11), tar_seal * 0.58);
	pave = mix(pave, vec3(0.22, 0.215, 0.20) * c_col * 1.20, smoothstep(0.60, 0.86, mid) * 0.28);
	float pm = smoothstep(0.28, 0.72, zt.r + (low - 0.5) * 0.12 + (mid - 0.5) * 0.08 + (hi - 0.5) * 0.05);
	col = mix(col, pave, pm);

	vec3 gr = mix(vec3(0.18, 0.22, 0.12), vec3(0.29, 0.30, 0.17), smoothstep(0.25, 0.75, low * 0.55 + hi2_aa * 0.45)) * mix(vec3(1.0), s_col * 1.24, 0.42) * (0.90 + low * 0.20);
	float gmm = smoothstep(0.24, 0.76, zt.g + (low - 0.5) * 0.15 + (mid - 0.5) * 0.18 + (hi - 0.5) * 0.08) * (1.0 - pm * 0.84);
	col = mix(col, gr, gmm);

	float furrow = 0.5 + 0.5 * sin((p.x * 0.35 + p.y * 0.94) * 2.1 + (low - 0.5) * 2.4 + (mid - 0.5) * 1.4) * fw;
	vec3 soil = mix(vec3(0.22, 0.18, 0.13), vec3(0.31, 0.25, 0.17), smoothstep(0.2, 0.8, mix(mid, furrow, 0.34))) * s_col * 1.24;
	float smm = smoothstep(0.24, 0.78, zt.b + (low - 0.5) * 0.16 + (mid - 0.5) * 0.14 + (hi - 0.5) * 0.08);
	col = mix(col, soil, smm);

	float rut = smoothstep(0.66, 0.92, abs(sin((p.x * 0.72 + (low - 0.5) * 6.0) * 2.2))) * smoothstep(0.42, 0.72, mid) * fw;
	vec3 grv = mix(vec3(0.22, 0.215, 0.20), vec3(0.28, 0.265, 0.24), low * 0.65 + med2 * 0.35) * g_col * 1.24;
	grv = mix(grv, vec3(0.16, 0.155, 0.145) * g_col * 1.22, smoothstep(0.64, 0.86, mid) * 0.26 + rut * 0.16);
	float am = smoothstep(0.28, 0.74, zt.a + (low - 0.5) * 0.14 + (mid - 0.5) * 0.10 + (hi - 0.5) * 0.06) * (1.0 - pm * 0.55);
	col = mix(col, grv, am);

	float zone_cov = clamp(pm + gmm * 0.88 + smm * 0.88 + am * 0.88, 0.0, 0.94);
	float wet_film = mudm * (1.0 - zone_cov) * smoothstep(0.70, 0.88, mid) * (1.0 - crack_mud * 0.85);
	col = mix(col, col * 0.76, wet_film * 0.36);
	float road_v = 0.0;
	float bldg_contact = 0.0;
	if (abs(sector_on) > 0.5) {
		vec2 s_uv = (p + zone_half) / (zone_half * 2.0);
		float s_in = 0.0;
		if (s_uv.x >= 0.0 && s_uv.x <= 1.0 && s_uv.y >= 0.0 && s_uv.y <= 1.0) {
			vec3 sec = texture(sector_tex, s_uv).rgb;
			s_in = smoothstep(0.20, 0.80, sec.r + (low - 0.5) * 0.16);
			road_v = sec.g * smoothstep(0.25, 0.80, 0.55 + (low - 0.5) * 0.30 + (mid - 0.5) * 0.25) * (1.0 - pm * 0.48);
			bldg_contact = sec.b;
		}
		col = mix(col, grv * 0.86, road_v * 0.65);
		// 沉稳烟灰冷调建筑接地接触暗影
		col *= mix(vec3(1.0), vec3(0.48, 0.50, 0.54), bldg_contact * 0.68);
		vec3 out_mul = (sector_on > 0.0) ? vec3(0.74, 0.75, 0.78) : vec3(0.24, 0.22, 0.28);
		col = mix(col * out_mul, col, s_in);
	}
	// 写实雨后湿润地面反光与低洼浅积水（保持平滑低频边界，无脏黑锯齿斑）
	float w_amt = clamp(wet_amt, 0.0, 1.0);
	float p_allow = (1.0 - gmm * 0.84) * (1.0 - smm * 0.78) * (1.0 - crack_mud * 0.65);
	float basin = 0.50 + (0.5 - low) * 0.76 + (med2 - 0.5) * 0.58 + (mid - 0.5) * 0.28;
	float puddle = w_amt * p_allow * smoothstep(0.700, 0.795, basin);
	float p_deep = smoothstep(0.755, 0.880, basin);
	float soak_rim = w_amt * p_allow * smoothstep(0.600, 0.730, basin);
	float damp_halo = w_amt * smoothstep(0.400, 0.590, basin);
	float col_lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, max(mix(vec3(col_lum), col, 1.08), vec3(0.0)), clamp(max(damp_halo * 0.60, soak_rim), 0.0, 1.0));
	col *= mix(1.0, 0.85, max(damp_halo * 0.60, w_amt * 0.22) * (1.0 - soak_rim * 0.65));
	col *= mix(1.0, 0.74, soak_rim);
	col = mix(col, mix(col * 0.72, mix(col * 0.50, vec3(0.020, 0.024, 0.030), 0.40), p_deep), puddle);
	ALBEDO = col;

	// 中频实感地表法线（远距 fw 自动平滑防闪点，近中景呈现碎石与混凝土块面微凹凸）
	vec3 ns = mix(texture(soil_n, uv_a).rgb, texture(soil_n, uv_b).rgb, m_blend);
	vec3 ng = mix(texture(grav_n, uv_ga).rgb, texture(grav_n, uv_gb).rgb, m_blend);
	vec3 nc = mix(texture(conc_n, uv_ca).rgb, texture(conc_n, uv_cb).rgb, m_blend);
	vec3 n_macro = texture(n_nrm, p * 0.055).rgb;
	vec3 n_det = mix(ns, ng, clamp(am + grav_patch * 0.45 + road_v * 0.55, 0.0, 1.0));
	n_det = mix(n_det, nc, pm);
	vec3 n_comb = normalize((n_det * 2.0 - 1.0) * mix(0.32, 0.66, fw) + (n_macro * 2.0 - 1.0) * 0.40 + vec3(0.0, 0.0, 0.72));
	vec2 rip_sl = vec2(0.0);
	if (puddle > 0.02 && weather_rain > 0.01) {
		float cam_d = length(wp - INV_VIEW_MATRIX[3].xyz);
		float r_fade = (1.0 - smoothstep(12.0, 42.0, cam_d)) * clamp(weather_rain, 0.0, 1.0);
		if (r_fade > 0.015) {
			rip_sl = g_ripple(p, TIME) * puddle * r_fade;
		}
	}
	n_comb = normalize(mix(n_comb, normalize(vec3(rip_sl.x, rip_sl.y, 1.0)), puddle * 0.88));
	vec3 dn = (dFdx(n_comb) + dFdy(n_comb)) * (1.0 - puddle * 0.78);
	float r_var = clamp(dot(dn, dn) * 0.65, 0.0, 0.22);
	float r_base = mix(0.92, 0.80, mudm * (1.0 - zone_cov));
	r_base = mix(r_base, 0.80, pm * (1.0 - seam));
	r_base = mix(r_base, 0.34, pm * tar_seal);
	r_base = mix(r_base, 0.90, am);
	r_base = mix(r_base, 0.50, max(wet_film, max(damp_halo * 0.68, w_amt * 0.26)));
	r_base = mix(r_base, 0.26, soak_rim * 0.78);
	r_base = sqrt(clamp(r_base * r_base + r_var, 0.04, 1.0));
	ROUGHNESS = mix(r_base, mix(0.12, 0.085, p_deep), puddle * 0.94);
	SPECULAR = mix(0.28, 0.66, pm * 0.14 + wet_film * 0.16 + soak_rim * 0.36 + puddle * 0.88);
	AO = clamp(1.0 - crack_mud * 0.48 - pm * seam * 0.36 - am * rut * 0.18 - road_v * 0.16 - bldg_contact * 0.68, 0.18, 1.0);
	AO_LIGHT_AFFECT = 0.68;
	CLEARCOAT = max(puddle * 0.54, soak_rim * 0.24);
	CLEARCOAT_ROUGHNESS = mix(0.18, 0.085, puddle);
	NORMAL_MAP = n_comb * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = (mix(0.42, 0.66, fw) + crack_mud * 0.95 + pm * seam * 0.80 + am * 0.18) * (1.0 - puddle * 0.84);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("n_low", noise_tex("grime_raw", 512))
	m.set_shader_parameter("n_hi", noise_tex("hi_raw", 512))
	m.set_shader_parameter("n_nrm", noise_tex("ground_n", 512))
	m.set_shader_parameter("soil_a", world_tex("ground_soil_a.png"))
	m.set_shader_parameter("soil_n", world_tex("ground_soil_n.png"))
	m.set_shader_parameter("grav_a", world_tex("ground_gravel_a.png"))
	m.set_shader_parameter("grav_n", world_tex("ground_gravel_n.png"))
	m.set_shader_parameter("conc_a", world_tex("concrete_a.png"))
	m.set_shader_parameter("conc_n", world_tex("concrete_n.png"))
	m.set_shader_parameter("wet_amt", 0.0)
	m.set_meta("no_outline", true)
	_mat_cache["ground"] = m
	return m


## 3D 视口专用 16x16x16 末世废土胶片 LUT：银留工艺（Bleach-Bypass）适度脱饱和、扎实暗部冷钢青、氧化钨丝微暖高光与扎实电影 S 曲线。
static func cinematic_lut() -> ImageTexture3D:
	if _tex_cache.has("cinematic_lut"):
		return _tex_cache["cinematic_lut"]
	var n := 16
	var slices: Array[Image] = []
	slices.resize(n)
	for z in n:
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		var b0 := float(z) / float(n - 1)
		for y in n:
			var g0 := float(y) / float(n - 1)
			for x in n:
				var r0 := float(x) / float(n - 1)
				var luma := r0 * 0.299 + g0 * 0.587 + b0 * 0.114
				var sr := lerpf(r0, r0 * r0 * (3.0 - 2.0 * r0), 0.22)
				var sg := lerpf(g0, g0 * g0 * (3.0 - 2.0 * g0), 0.22)
				var sb := lerpf(b0, b0 * b0 * (3.0 - 2.0 * b0), 0.22)
				# 保留沉稳深黑层次与暗部细节可读性，暗部冷钢青，高光微暖锈黄滚降
				var floor_lift := (1.0 - smoothstep(0.0, 0.18, luma)) * 0.009
				var sh := (1.0 - smoothstep(0.0, 0.45, luma)) * smoothstep(0.0, 0.04, luma)
				var hi := smoothstep(0.48, 0.94, luma) * (1.0 - smoothstep(0.95, 1.0, luma) * 0.60)
				sr += floor_lift * 0.80 - 0.009 * sh + 0.012 * hi
				sg += floor_lift * 0.92 + 0.002 * sh + 0.005 * hi
				sb += floor_lift * 1.02 + 0.008 * sh - 0.009 * hi
				# 轻度银留脱饱和（Bleach-Bypass），赋予钢铁、混凝土与尘雾写实冷峻质感
				var lum2 := sr * 0.299 + sg * 0.587 + sb * 0.114
				var sat_mul := lerpf(0.88, 0.96, hi)
				sr = clampf(lum2 + (sr - lum2) * sat_mul, 0.0, 1.0)
				sg = clampf(lum2 + (sg - lum2) * sat_mul, 0.0, 1.0)
				sb = clampf(lum2 + (sb - lum2) * sat_mul, 0.0, 1.0)
				img.set_pixel(x, y, Color(sr, sg, sb, 1.0))
		slices[z] = img
	var lut := ImageTexture3D.new()
	lut.create(Image.FORMAT_RGB8, n, n, n, false, slices)
	_tex_cache["cinematic_lut"] = lut
	return lut


## 柔和圆角矩形接地接触阴影贴图（供箱体、集装箱、载具残骸与机甲底盘共用，零锯齿、低画质/移动端 equally 有效）
static func contact_shadow_tex() -> ImageTexture:
	if _tex_cache.has("contact_shadow_tex"):
		return _tex_cache["contact_shadow_tex"]
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var ny := (float(y) + 0.5) / float(n) * 2.0 - 1.0
		for x in n:
			var nx := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			# 圆角超椭圆距离场：贴合箱子/集装箱/载具底盘，四周极其柔和晕开
			var qx := maxf(absf(nx) - 0.34, 0.0)
			var qy := maxf(absf(ny) - 0.34, 0.0)
			var d := sqrt(qx * qx + qy * qy) / 0.66
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.15)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache["contact_shadow_tex"] = tex
	return tex


## 统一冷靛灰接地软阴影材质（支持单 MultiMesh 合批绘制，微量视线前拉防路面吃影与 z-fighting，极低开销）
static func contact_shadow_mat(alpha := 0.52) -> ShaderMaterial:
	var key := "contact_shadow_mat_%.2f" % alpha
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ground_vfx_mat(contact_shadow_tex(), Color(0.020, 0.023, 0.028, alpha), false, 0.14, true, 0)
	m.render_priority = -4
	m.set_meta("no_outline", true)
	_mat_cache[key] = m
	return m


## 叠加用的贴地材质（光圈、阴影斑等），不受光。
static func decal_mat(tex: Texture2D, c: Color, additive := false) -> StandardMaterial3D:
	var key := "decal%s%s%s" % [tex.get_instance_id(), c.to_html(), additive]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.render_priority = 0
	elif tex == blob_tex():
		m.render_priority = -3
	elif tex == cloud_tex():
		m.render_priority = -2
	else:
		m.render_priority = -1
	_mat_cache[key] = m
	return m


static func particle_mat(tex: Texture2D, additive := true, prox_fade := -1.0) -> StandardMaterial3D:
	var pd: float = prox_fade if prox_fade >= 0.0 else (0.18 if additive else 0.26)
	var key := "pm%s%s%.2f" % [tex.get_instance_id(), additive, pd]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	if not is_mobile_perf():
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = pd
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


static func _is_cloud_tex(tex: Texture2D) -> bool:
	return tex == smoke_tex() or tex == dust_tex() or tex == cloud_tex()


## 受击热冲击叠加层：双面 Fresnel 轮廓受击脉冲 + 钨钢余烬着色，量化 5 档避免每帧新建材质
static func hit_flash_overlay(intensity := 1.0) -> ShaderMaterial:
	var q := clampi(int(ceil(clampf(intensity, 0.0, 1.0) * 5.0)), 1, 5)
	var key := "hit_flash_%d" % q
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh: Shader = _mat_cache.get("_hit_flash_sh")
	if sh == null:
		sh = Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float intensity = 1.0;
void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(clamp(1.0 - ndv, 0.0, 1.0), 1.55);
	float hot = rim * 1.15 + 0.28;
	vec3 ember = vec3(1.0, 0.48, 0.14);
	vec3 tungsten = vec3(1.0, 0.88, 0.68);
	ALBEDO = mix(ember, tungsten, clamp(rim * 1.1, 0.0, 1.0)) * hot * intensity;
	ALPHA = clamp(hot * intensity, 0.0, 1.0);
}
"""
		_mat_cache["_hit_flash_sh"] = sh
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("intensity", float(q) / 5.0)
	_mat_cache[key] = m
	return m


## 兼容旧调用的受击叠加层入口
static func flash_overlay() -> Material:
	return hit_flash_overlay(1.0)


# ======================================================================
# 组装辅助
# ======================================================================
static func add(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## 贴地平面（光圈、阴影斑、血迹）
static func ground_decal(parent: Node3D, tex: Texture2D, c: Color, size: float, pos: Vector3, additive := false) -> MeshInstance3D:
	var mi := add(parent, quad(size, size), decal_mat(tex, c, additive), pos, Vector3.ZERO, Vector3.ONE, false)
	return mi


## 地面特效着色器（按视线方向前拉 depth_pull，确保在地面铺装 / 人行道 / 首领战区台面上方可见且无视差偏移，仍被高墙与机体上半身遮挡）
static func ground_vfx_shader(additive := false) -> Shader:
	var key := "_gvfx_sh_%s" % ("add" if additive else "mix")
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	var blend_mode := "blend_add" if additive else "blend_mix"
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, %s;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 col : source_color = vec4(1.0);
uniform float depth_pull = 0.44;
void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float pull = min(depth_pull, max(0.0, length(vp) - 0.5));
	VERTEX = vp - normalize(vp) * pull;
}
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = col.rgb * t.rgb;
	ALPHA = col.a * t.a;
}
""" % blend_mode
	_mat_cache[key] = sh
	return sh


static func ground_vfx_mat(tex: Texture2D, c: Color, additive := false, depth_pull := 0.44, unique := false, priority := -1) -> ShaderMaterial:
	var prio: int = priority if priority >= 0 else (4 if additive else 2)
	if not unique:
		var key := "gvfx|%d|%s|%s|%.2f|%d" % [tex.get_instance_id(), c, additive, depth_pull, prio]
		if _mat_cache.has(key):
			return _mat_cache[key]
		var m := ShaderMaterial.new()
		m.shader = ground_vfx_shader(additive)
		m.render_priority = prio
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("col", c)
		m.set_shader_parameter("depth_pull", depth_pull)
		_mat_cache[key] = m
		return m
	var m := ShaderMaterial.new()
	m.shader = ground_vfx_shader(additive)
	m.render_priority = prio
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("col", c)
	m.set_shader_parameter("depth_pull", depth_pull)
	return m


static func ground_vfx_solid_mat(tex: Texture2D, c: Color, depth_pull := 0.34, priority := 1) -> ShaderMaterial:
	return ground_vfx_mat(tex, c, false, depth_pull, false, priority)


static func ground_vfx(parent: Node3D, tex: Texture2D, c: Color, size: float, pos: Vector3, additive := false, depth_pull := 0.44, unique := false, priority := -1) -> MeshInstance3D:
	return add(parent, quad(size, size), ground_vfx_mat(tex, c, additive, depth_pull, unique, priority), pos, Vector3.ZERO, Vector3.ONE, false)


static func _tactical_ring_shader() -> Shader:
	var key := "_tac_ring_sh"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, blend_mix;
uniform vec4 col : source_color = vec4(1.0, 0.30, 0.20, 1.0);
uniform float fill_alpha = 0.22;
uniform float progress = 0.0;
uniform float alpha_mul = 1.0;
uniform float depth_pull = 0.44;
uniform float ticks = 24.0;
void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float pull = min(depth_pull, max(0.0, length(vp) - 0.5));
	VERTEX = vp - normalize(vp) * pull;
}
float _grime(vec2 p) {
	float a = sin(p.x * 11.3 + p.y * 7.9) * cos(p.y * 13.7 - p.x * 6.4);
	float b = sin(p.x * 23.1 - p.y * 19.3 + a * 1.4);
	return clamp(0.5 + 0.30 * a + 0.20 * b, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float grime = _grime(p);
	float wisp_r = r + (grime - 0.5) * 0.070;
	// Sparse broken corner stencil wisps + organic thermal shockwave (never a solid outline circle or bright center bullseye)
	float bracket_mask = smoothstep(0.64, 0.88, abs(sin(ang * 2.0 + 0.25)));
	float aa = max(fwidth(r), 0.006);
	float arc_line = exp(-pow((r - 0.895) / max(0.018, aa * 1.9), 2.0)) * bracket_mask * (0.55 + 0.45 * grime);
	float scorch_mist = exp(-pow((wisp_r - 0.64) / 0.34, 2.0)) * (0.38 + 0.62 * grime) * (1.0 - smoothstep(0.86, 0.98, wisp_r));
	float prog = clamp(progress, 0.0, 1.0);
	float pr = prog * 0.905;
	float prog_heat = (1.0 - smoothstep(max(0.0, pr - 0.14), pr + 0.05, wisp_r)) * smoothstep(0.08, 0.22, prog) * (0.45 + 0.55 * grime);
	float prog_wave = exp(-pow((wisp_r - pr) / 0.068, 2.0)) * smoothstep(0.10, 0.24, prog) * (1.0 - smoothstep(0.94, 1.0, prog)) * (0.60 + 0.40 * grime);
	float total_fill = (scorch_mist * fill_alpha * 0.72 + prog_heat * fill_alpha * 0.85) * (1.0 - smoothstep(0.90, 0.99, wisp_r));
	float rim = clamp(arc_line * 0.66 + prog_wave * 0.82, 0.0, 1.0);
	vec3 rgb = mix(col.rgb * 0.76, col.rgb * 1.18 + vec3(0.04, 0.02, 0.0), clamp(rim + prog_wave * 0.35, 0.0, 1.0));
	float a = clamp(total_fill + rim * 0.60, 0.0, 0.76) * col.a * alpha_mul * (1.0 - smoothstep(0.92, 0.995, r));
	ALBEDO = rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
	_mat_cache[key] = sh
	return sh


static func tactical_ring_mat(c: Color, fill_alpha := 0.22, ticks := 24.0, depth_pull := 0.44, priority := 3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _tactical_ring_shader()
	m.render_priority = priority
	m.set_shader_parameter("col", c)
	m.set_shader_parameter("fill_alpha", fill_alpha)
	m.set_shader_parameter("progress", 0.0)
	m.set_shader_parameter("alpha_mul", 1.0)
	m.set_shader_parameter("ticks", ticks)
	m.set_shader_parameter("depth_pull", depth_pull)
	return m


static func _tactical_lane_shader() -> Shader:
	var key := "_tac_lane_sh"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, blend_mix;
uniform vec4 col : source_color = vec4(1.0, 0.35, 0.18, 1.0);
uniform float aspect = 3.0;
uniform float progress = 0.0;
uniform float alpha_mul = 1.0;
uniform float chevron_dir = -1.0;
uniform float depth_pull = 0.44;
void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float pull = min(depth_pull, max(0.0, length(vp) - 0.5));
	VERTEX = vp - normalize(vp) * pull;
}
void fragment() {
	vec2 u = vec2((UV.x - 0.5) * 2.0, UV.y);
	float ax = abs(u.x);
	float fwd = (chevron_dir < 0.0) ? (1.0 - u.y) : u.y;
	// Softly tapered organic dust/ember corridor — no closed box frame
	float axial_fade = smoothstep(0.0, 0.14, u.y) * smoothstep(1.0, 0.80, u.y);
	float side_taper = exp(-pow(ax / 0.58, 2.2));
	float n1 = sin(u.x * 13.0 + fwd * aspect * 7.0 - TIME * 2.8) * cos(u.x * 8.5 - fwd * aspect * 11.0 + TIME * 1.9);
	float n2 = sin(u.x * 23.0 - fwd * aspect * 15.0 + TIME * 4.2 + n1 * 1.2);
	float streak = clamp(0.50 + 0.32 * n1 + 0.18 * n2, 0.0, 1.0);
	// Discontinuous dashed flank stencil ticks (20% duty cycle, soft ends)
	float dash = smoothstep(0.62, 0.86, sin(fwd * max(aspect, 1.0) * 5.2));
	float flank_guide = exp(-pow((ax - 0.86) / 0.032, 2.0)) * dash * axial_fade * 0.52;
	// Flowing angled directional wake wisps instead of sharp geometric chevrons
	float wake_ph = fract(fwd * max(aspect * 0.95, 1.0) + ax * 0.42 - TIME * 1.35);
	float wake = exp(-pow((wake_ph - 0.5) / 0.16, 2.0)) * side_taper * axial_fade * (0.55 + 0.45 * streak);
	float prog = clamp(progress, 0.0, 1.0);
	float front_dist = fwd - prog;
	float wave_front = exp(-pow(front_dist / 0.065, 2.0)) * smoothstep(0.02, 0.09, prog) * (1.0 - smoothstep(0.94, 1.0, prog)) * side_taper * (0.65 + 0.35 * streak);
	float behind_glow = (1.0 - smoothstep(prog - 0.10, prog + 0.04, fwd)) * smoothstep(0.02, 0.08, prog) * side_taper * axial_fade * (0.20 + 0.25 * streak);
	float body_mist = side_taper * axial_fade * (0.12 + 0.18 * streak);
	float total_a = (body_mist + wake * 0.34 + behind_glow * 0.45 + wave_front * 0.62 + flank_guide * (0.5 + 0.5 * streak)) * col.a * alpha_mul;
	vec3 rgb = mix(col.rgb * 0.72, col.rgb * 1.22 + vec3(0.05, 0.02, 0.0), clamp(wake * 0.6 + wave_front * 0.9 + flank_guide * 0.5, 0.0, 1.0));
	ALBEDO = rgb;
	ALPHA = clamp(total_a, 0.0, 0.78);
}
"""
	_mat_cache[key] = sh
	return sh


static func tactical_lane_mat(c: Color, aspect := 3.0, chevron_dir := -1.0, depth_pull := 0.44, priority := 3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _tactical_lane_shader()
	m.render_priority = priority
	m.set_shader_parameter("col", c)
	m.set_shader_parameter("aspect", aspect)
	m.set_shader_parameter("progress", 0.0)
	m.set_shader_parameter("alpha_mul", 1.0)
	m.set_shader_parameter("chevron_dir", chevron_dir)
	m.set_shader_parameter("depth_pull", depth_pull)
	return m


static func _extract_pad_shader() -> Shader:
	var key := "_ext_pad_sh"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, blend_mix;
uniform vec4 col : source_color = vec4(0.32, 0.78, 0.44, 1.0);
uniform float progress = 0.0;
uniform float active_pulse = 1.0;
uniform float depth_pull = 0.44;
void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float pull = min(depth_pull, max(0.0, length(vp) - 0.5));
	VERTEX = vp - normalize(vp) * pull;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float grime = 0.68 + 0.32 * sin(p.x * 19.0 + p.y * 13.0) * cos(p.y * 23.0 - p.x * 11.0);
	// Four subtle corner stencil brackets only — no solid disc or neon outer ring
	float corner = smoothstep(0.46, 0.70, abs(sin(ang * 2.0)));
	float bracket = exp(-pow((r - 0.89) / 0.018, 2.0)) * corner;
	float sub_tick = exp(-pow((r - 0.84) / 0.008, 2.0)) * pow(abs(cos(ang * 2.0)), 14.0) * 0.45;
	// Small stencil crosshair hash at pad center
	float cx = exp(-pow(abs(p.y) / 0.012, 2.0)) * step(0.06, abs(p.x)) * (1.0 - smoothstep(0.16, 0.22, abs(p.x)));
	float cy = exp(-pow(abs(p.x) / 0.012, 2.0)) * step(0.06, abs(p.y)) * (1.0 - smoothstep(0.16, 0.22, abs(p.y)));
	float cross_mark = max(cx, cy) * 0.35;
	// Subtle inward radar sweep when active
	float pr = mix(0.88, 0.20, fract(TIME * 0.42));
	float sweep = exp(-pow((r - pr) / 0.045, 2.0)) * active_pulse * (0.14 + 0.20 * progress) * (1.0 - smoothstep(0.88, 0.95, r));
	float ink = (bracket * 0.62 + sub_tick + cross_mark + sweep) * grime;
	float a = clamp(ink, 0.0, 0.62) * col.a * (1.0 - smoothstep(0.94, 0.995, r));
	ALBEDO = mix(col.rgb * 0.76, col.rgb * 1.15, clamp(bracket + sweep, 0.0, 1.0));
	ALPHA = a;
}
"""
	_mat_cache[key] = sh
	return sh


static func extract_pad_mat(c: Color, depth_pull := 0.44, priority := 2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _extract_pad_shader()
	m.render_priority = priority
	m.set_shader_parameter("col", c)
	m.set_shader_parameter("progress", 0.0)
	m.set_shader_parameter("active_pulse", 1.0)
	m.set_shader_parameter("depth_pull", depth_pull)
	return m


static func _reactive_arc_shader() -> Shader:
	var key := "_react_arc_sh"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 col : source_color = vec4(0.42, 0.78, 1.0, 1.0);
uniform float surge = 0.0;
uniform float fade = 1.0;
void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(clamp(1.0 - ndv, 0.0, 1.0), 2.1);
	// Fine scrolling diagonal ionized filaments + vertical edge fade along strip V
	float edge_v = smoothstep(0.0, 0.24, UV.y) * smoothstep(1.0, 0.76, UV.y);
	float edge_u = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x);
	float fil = 0.5 + 0.5 * sin(UV.x * 26.0 - TIME * 4.5 + sin(UV.y * 9.0) * 1.8);
	float lattice = pow(fil, 3.0);
	float base_i = (0.05 + 0.22 * rim + 0.12 * lattice * rim);
	float hit_i = surge * (0.55 + 0.95 * lattice + 0.45 * rim);
	float a = clamp((base_i + hit_i) * edge_v * edge_u * fade * col.a, 0.0, 0.95);
	ALBEDO = col.rgb * (0.85 + 1.35 * surge + 0.45 * lattice);
	ALPHA = a;
}
"""
	_mat_cache[key] = sh
	return sh


static func reactive_arc_mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _reactive_arc_shader()
	m.render_priority = 6
	m.set_shader_parameter("col", c)
	m.set_shader_parameter("surge", 0.0)
	m.set_shader_parameter("fade", 1.0)
	return m


static func reactive_arc_mesh(radius := 1.48, height := 1.50, blades := 5, segs := 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bi in blades:
		var t_b := float(bi) / float(maxi(blades, 1))
		var base_a := t_b * TAU + sin(float(bi) * 2.3) * 0.25
		var span := lerpf(0.88, 1.24, fmod(float(bi) * 0.37, 1.0))
		var y_off := (float(bi % 3) - 1.0) * (height * 0.24)
		var tilt := ((float((bi * 7) % 5) / 4.0) - 0.5) * 0.42
		var half_w := lerpf(0.14, 0.22, fmod(float(bi) * 0.61 + 0.2, 1.0)) * (height / 1.5)
		var rad := radius * lerpf(0.92, 1.08, fmod(float(bi) * 0.43, 1.0))
		var prev_top := Vector3.ZERO
		var prev_bot := Vector3.ZERO
		var prev_nrm := Vector3.UP
		for si in range(segs + 1):
			var u := float(si) / float(segs)
			var ang := base_a + (u - 0.5) * span
			var taper := sin(u * PI)
			var w_here := half_w * (0.28 + 0.72 * taper)
			var r_here := rad + sin(u * PI * 2.0 + float(bi)) * 0.06
			var center := Vector3(cos(ang) * r_here, y_off + sin((u - 0.5) * 2.2) * tilt * r_here, sin(ang) * r_here)
			var radial := Vector3(cos(ang), sin(ang) * 0.12 * tilt, sin(ang)).normalized()
			var tang := Vector3(-sin(ang), tilt * cos((u - 0.5) * 2.2), cos(ang)).normalized()
			var binorm := radial.cross(tang).normalized()
			var top := center + binorm * w_here
			var bot := center - binorm * w_here
			if si > 0:
				st.set_normal(prev_nrm); st.set_uv(Vector2(float(si - 1) / float(segs), 1.0)); st.add_vertex(prev_top)
				st.set_normal(radial);   st.set_uv(Vector2(u, 1.0)); st.add_vertex(top)
				st.set_normal(radial);   st.set_uv(Vector2(u, 0.0)); st.add_vertex(bot)
				st.set_normal(prev_nrm); st.set_uv(Vector2(float(si - 1) / float(segs), 1.0)); st.add_vertex(prev_top)
				st.set_normal(radial);   st.set_uv(Vector2(u, 0.0)); st.add_vertex(bot)
				st.set_normal(prev_nrm); st.set_uv(Vector2(float(si - 1) / float(segs), 0.0)); st.add_vertex(prev_bot)
			prev_top = top
			prev_bot = bot
			prev_nrm = radial
	return st.commit()


static func _acid_pool_shader() -> Shader:
	var key := "_acid_pool_sh"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, blend_mix;
uniform vec4 col : source_color = vec4(0.32, 0.92, 0.24, 0.90);
uniform float alpha_mul = 1.0;
uniform float seed = 0.0;
uniform float depth_pull = 0.44;
void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float pull = min(depth_pull, max(0.0, length(vp) - 0.5));
	VERTEX = vp - normalize(vp) * pull;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = atan(p.y, p.x);
	float warp = sin(ang * 3.0 + seed * 6.28) * 0.08 + sin(ang * 5.0 - seed * 11.3) * 0.055 + sin(p.x * 5.2 + p.y * 4.7 + seed * 4.1) * 0.045;
	float micro_warp = 0.04 * sin(p.x * 17.0 - p.y * 19.0 + seed * 2.7);
	float r = length(p) + warp + micro_warp;
	float mask = 1.0 - smoothstep(0.62, 0.94, r);
	float v1 = sin(p.x * 8.5 + cos(p.y * 7.2 + TIME * 1.3 + seed * 5.0));
	float v2 = cos(p.y * 9.0 - sin(p.x * 7.8 - TIME * 1.1 + seed * 3.0));
	float veins = smoothstep(0.45, 0.95, 0.5 + 0.5 * v1 * v2);
	vec2 cell = p * 5.2 + vec2(seed * 3.1, TIME * 0.35);
	vec2 cf = fract(cell) - 0.5;
	float cid = fract(sin(dot(floor(cell), vec2(127.1, 311.7))) * 43758.5453);
	float bphase = fract(TIME * (0.45 + cid * 0.4) + cid * 7.0);
	float brad = 0.10 + bphase * 0.16;
	float inner_mask = smoothstep(0.86, 0.42, r);
	float bubble = (1.0 - smoothstep(brad - 0.05, brad + 0.04, length(cf))) * (1.0 - bphase) * smoothstep(0.55, 0.85, cid) * inner_mask;
	vec3 base_c = col.rgb * vec3(0.32, 0.52, 0.28);
	vec3 damp_edge = mix(base_c * 0.55, base_c, smoothstep(0.90, 0.58, r));
	vec3 bright_c = col.rgb * vec3(1.25, 1.45, 0.88) + vec3(0.05, 0.10, 0.02);
	float core_fx = clamp((veins * 0.58 + bubble * 0.95) * inner_mask, 0.0, 1.0);
	vec3 rgb = mix(damp_edge, bright_c, core_fx);
	float a = mask * mix(0.42, 0.88, clamp(smoothstep(0.92, 0.52, r) * 0.55 + veins * 0.28 * inner_mask + bubble * 0.65, 0.0, 1.0)) * col.a * alpha_mul;
	ALBEDO = rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
	_mat_cache[key] = sh
	return sh


static func acid_pool_mat(c: Color, seed := 0.0, depth_pull := 0.44, priority := 2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _acid_pool_shader()
	m.render_priority = priority
	m.set_shader_parameter("col", c)
	m.set_shader_parameter("alpha_mul", 1.0)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("depth_pull", depth_pull)
	return m


## 一次性爆发粒子，播完自动销毁。
## 一次性粒子池：枪口火光 / 命中火花 / 硝烟每秒上百个，每个都新建粒子节点 + 网格 + 曲线 + 渐变很贵（节点进出场景树、渲染资源创建与释放）。
## 同一父节点、同一组参数（方向除外）的粒子播完后回池，下次直接移位重播；网格 / 曲线 / 渐变按参数缓存共用
const BURST_POOL_MAX := 24
static var _burst_pool := {}
static var _burst_res := {}


static func _burst_res_get(key: String, make: Callable) -> Resource:
	var r = _burst_res.get(key)
	if r == null:
		r = make.call()
		_burst_res[key] = r
	return r


static func _burst_done(p: CPUParticles3D) -> void:
	if not is_instance_valid(p):
		return
	var key: String = p.get_meta("_bk", "")
	var pool: Array = _burst_pool.get(key, [])
	if key == "" or pool.size() >= BURST_POOL_MAX or not p.is_inside_tree():
		p.queue_free()
		return
	p.visible = false
	pool.append(p)
	_burst_pool[key] = pool


static func burst(parent: Node, pos: Vector3, opts: Dictionary) -> CPUParticles3D:
	var o := opts.duplicate()
	o.erase("dir")
	var key := "%d|%s" % [parent.get_instance_id(), o]
	var flat_val: float = float(opts.get("flat", 0.0))
	var pool: Array = _burst_pool.get(key, [])
	while not pool.is_empty():
		var q = pool.pop_back()
		if is_instance_valid(q) and q.is_inside_tree() and q.get_parent() == parent:
			q.visible = true
			q.flatness = flat_val
			q.direction = opts.get("dir", Vector3.UP)
			q.global_position = pos
			q.restart()
			return q
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = opts.get("explosive", 0.95)
	var b_amt: int = int(opts.get("amount", 16))
	p.amount = maxi(3, int(round(float(b_amt) * 0.45))) if is_mobile_perf() else b_amt
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.lifetime = opts.get("life", 0.5)
	p.local_coords = false
	p.flatness = flat_val
	var tex: Texture2D = opts.get("tex", soft_dot())
	var add: bool = opts.get("additive", true)
	var sz: float = opts.get("size", 0.3)
	var prox: float = float(opts.get("soft_depth", -1.0))
	if opts.has("mesh"):
		p.mesh = opts["mesh"]
		p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, bool(opts.get("align_y", true)))
		p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ROTATE_Y, true)
		p.angular_velocity_min = opts.get("ang_min", -540.0)
		p.angular_velocity_max = opts.get("ang_max", 540.0)
	else:
		p.mesh = _burst_res_get("q%d|%s|%s|%.2f" % [tex.get_instance_id(), add, sz, prox], func():
			var qm := QuadMesh.new()
			qm.size = Vector2.ONE * sz
			qm.material = particle_mat(tex, add, prox)
			return qm)
		var is_cloud: bool = _is_cloud_tex(tex)
		if is_cloud or opts.has("angle_min") or opts.has("angle_max"):
			p.angle_min = float(opts.get("angle_min", -180.0))
			p.angle_max = float(opts.get("angle_max", 180.0))
		if is_cloud or opts.has("ang_min") or opts.has("ang_max"):
			p.angular_velocity_min = float(opts.get("ang_min", -28.0))
			p.angular_velocity_max = float(opts.get("ang_max", 28.0))
	p.direction = opts.get("dir", Vector3.UP)
	p.spread = opts.get("spread", 180.0)
	p.initial_velocity_min = opts.get("vmin", 3.0)
	p.initial_velocity_max = opts.get("vmax", 8.0)
	p.gravity = opts.get("gravity", Vector3(0, -12, 0))
	p.damping_min = opts.get("damp", 2.0)
	p.damping_max = opts.get("damp", 2.0)
	p.scale_amount_min = opts.get("smin", 0.6)
	p.scale_amount_max = opts.get("smax", 1.2)
	var g0: float = opts.get("grow0", 1.0)
	var g1: float = opts.get("grow1", 0.0)
	var has_gm: bool = opts.has("grow_mid")
	var gm_val: float = float(opts.get("grow_mid", (g0 + g1) * 0.5))
	var gmp: float = clampf(float(opts.get("grow_mid_pos", 0.28)), 0.05, 0.95)
	p.scale_amount_curve = _burst_res_get("c%s|%s|%s|%s|%s" % [g0, g1, has_gm, gm_val, gmp], func():
		var curve := Curve.new()
		curve.add_point(Vector2(0, g0))
		if has_gm:
			curve.add_point(Vector2(gmp, gm_val))
		curve.add_point(Vector2(1, g1))
		return curve)
	var c0: Color = opts.get("c0", Color(1, 0.8, 0.4))
	var c1: Color = opts.get("c1", Color(c0.r, c0.g * 0.4, 0.0, 0.0))
	var has_cm: bool = opts.has("cmid")
	var cm_val: Color = opts.get("cmid", c0)
	var cmp: float = clampf(float(opts.get("cmid_pos", 0.28)), 0.05, 0.95)
	p.color_ramp = _burst_res_get("g%s|%s|%s|%s|%s" % [c0, c1, has_cm, cm_val, cmp], func():
		var g := Gradient.new()
		g.set_color(0, c0)
		g.set_color(1, c1)
		if has_cm:
			g.add_point(cmp, cm_val)
		return g)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = opts.get("radius", 0.1)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.set_meta("_bk", key)
	p.finished.connect(_burst_done.bind(p))
	return p


## 持续粒子（火焰、烟柱、尘埃）
static func emitter(parent: Node3D, pos: Vector3, opts: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var e_amt: int = int(opts.get("amount", 24))
	p.amount = maxi(3, int(round(float(e_amt) * 0.45))) if is_mobile_perf() else e_amt
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.lifetime = opts.get("life", 1.0)
	p.local_coords = opts.get("local", false)
	p.explosiveness = float(opts.get("explosive", 0.0))
	p.flatness = float(opts.get("flat", 0.0))
	var tex: Texture2D = opts.get("tex", soft_dot())
	var add: bool = bool(opts.get("additive", true))
	var prox: float = float(opts.get("soft_depth", -1.0))
	if opts.has("mesh"):
		p.mesh = opts["mesh"]
		p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ROTATE_Y, true)
		p.angular_velocity_min = opts.get("ang_min", -240.0)
		p.angular_velocity_max = opts.get("ang_max", 240.0)
	else:
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * opts.get("size", 0.5)
		qm.material = particle_mat(tex, add, prox)
		p.mesh = qm
		var is_cloud: bool = _is_cloud_tex(tex)
		if is_cloud or opts.has("angle_min") or opts.has("angle_max"):
			p.angle_min = float(opts.get("angle_min", -180.0))
			p.angle_max = float(opts.get("angle_max", 180.0))
		if is_cloud or opts.has("ang_min") or opts.has("ang_max"):
			p.angular_velocity_min = float(opts.get("ang_min", -28.0))
			p.angular_velocity_max = float(opts.get("ang_max", 28.0))
	p.direction = opts.get("dir", Vector3.UP)
	p.spread = opts.get("spread", 15.0)
	p.initial_velocity_min = opts.get("vmin", 1.0)
	p.initial_velocity_max = opts.get("vmax", 2.0)
	p.gravity = opts.get("gravity", Vector3(0, 1, 0))
	if opts.has("damp"):
		p.damping_min = float(opts["damp"])
		p.damping_max = float(opts["damp"])
	p.scale_amount_min = opts.get("smin", 0.6)
	p.scale_amount_max = opts.get("smax", 1.2)
	var curve := Curve.new()
	curve.add_point(Vector2(0, opts.get("grow0", 0.5)))
	if opts.has("grow_mid"):
		curve.add_point(Vector2(clampf(float(opts.get("grow_mid_pos", 0.3)), 0.05, 0.95), float(opts["grow_mid"])))
	curve.add_point(Vector2(1, opts.get("grow1", 1.0)))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, opts.get("c0", Color(1, 0.7, 0.3)))
	g.set_color(1, opts.get("c1", Color(0.3, 0.1, 0.0, 0.0)))
	if opts.has("cmid"):
		g.add_point(clampf(float(opts.get("cmid_pos", 0.3)), 0.05, 0.95), opts.cmid)
	p.color_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE if not opts.has("box") else CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_sphere_radius = opts.get("radius", 0.2)
	if opts.has("box"):
		p.emission_box_extents = opts.box
	parent.add_child(p)
	p.position = pos
	return p


# ======================================================================
# 写实细节件（greebles）
# ======================================================================
## 沿 Catmull-Rom 曲线生成管子（液压软管、线缆）
## 多边形装甲板：凸多边形轮廓（XY 平面）沿 Z 挤出 thick，四周倒角 bevel。
## 用于 B.o.T 式的多面切角装甲。棱的顶点色 R=0，供涂装着色器做边缘掉漆。
static func prism(outline: PackedVector2Array, thick: float, bevel := 0.03) -> ArrayMesh:
	var key := "pr%s|%.3f|%.3f" % [outline, thick, bevel]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var n := outline.size()
	# 统一为顺时针（y 向上），镜像出来的逆时针轮廓自动翻转，保证法线朝外
	var area := 0.0
	for i in n:
		var a2 := outline[i]
		var b2 := outline[(i + 1) % n]
		area += a2.x * b2.y - b2.x * a2.y
	if area > 0.0:
		outline = outline.duplicate()
		outline.reverse()
	var cen := Vector2.ZERO
	for q in outline:
		cen += q
	cen /= n
	var b: float = min(bevel, thick * 0.45)
	# 内缩轮廓（沿各顶点角平分线收 b）
	var inset := PackedVector2Array()
	for i in n:
		var p0 := outline[(i - 1 + n) % n]
		var p1 := outline[i]
		var p2 := outline[(i + 1) % n]
		var d1 := (p1 - p0).normalized()
		var d2 := (p2 - p1).normalized()
		var n1 := Vector2(d1.y, -d1.x)
		var n2 := Vector2(d2.y, -d2.x)
		if n1.dot(cen - p1) < 0.0:
			n1 = -n1
			n2 = -n2
		var bis := (n1 + n2).normalized()
		var k: float = b / max(0.3, bis.dot(n1))
		inset.append(p1 + bis * k)
	var h := thick * 0.5
	var C := Vector3(cen.x, cen.y, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_vc = Color(1, 1, 1)
	for i in range(1, n - 1):
		_tri(st, Vector3(inset[0].x, inset[0].y, -h), Vector3(inset[i].x, inset[i].y, -h), Vector3(inset[i + 1].x, inset[i + 1].y, -h), C)
		_tri(st, Vector3(inset[0].x, inset[0].y, h), Vector3(inset[i].x, inset[i].y, h), Vector3(inset[i + 1].x, inset[i + 1].y, h), C)
	for i in n:
		var j := (i + 1) % n
		var oi := outline[i]
		var oj := outline[j]
		var ii := inset[i]
		var ij := inset[j]
		_vc = Color(0, 1, 1)
		_quad(st, Vector3(ii.x, ii.y, -h), Vector3(ij.x, ij.y, -h), Vector3(oj.x, oj.y, -h + b), Vector3(oi.x, oi.y, -h + b), C)
		_quad(st, Vector3(ii.x, ii.y, h), Vector3(ij.x, ij.y, h), Vector3(oj.x, oj.y, h - b), Vector3(oi.x, oi.y, h - b), C)
		_vc = Color(1, 1, 1)
		_quad(st, Vector3(oi.x, oi.y, -h + b), Vector3(oj.x, oj.y, -h + b), Vector3(oj.x, oj.y, h - b), Vector3(oi.x, oi.y, h - b), C)
	_vc = Color(1, 1, 1)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func tube(pts: Array, r: float, seg := 7, sub := 6) -> ArrayMesh:
	var path: Array = []
	for i in pts.size() - 1:
		var p0: Vector3 = pts[max(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[min(i + 2, pts.size() - 1)]
		for k in sub:
			var t := float(k) / sub
			var t2 := t * t
			var t3 := t2 * t
			path.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	path.append(pts[pts.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP
	var rings: Array = []
	for i in path.size():
		var tng: Vector3 = (path[min(i + 1, path.size() - 1)] - path[max(i - 1, 0)]).normalized()
		if abs(tng.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var nx := tng.cross(up).normalized()
		var ny := nx.cross(tng).normalized()
		up = ny
		var ring: Array = []
		for j in seg:
			var a := TAU * j / seg
			ring.append([path[i] + (nx * cos(a) + ny * sin(a)) * r, (nx * cos(a) + ny * sin(a))])
		rings.append(ring)
	for i in rings.size() - 1:
		for j in seg:
			var j2 := (j + 1) % seg
			var a = rings[i][j]
			var b = rings[i][j2]
			var c = rings[i + 1][j2]
			var d = rings[i + 1][j]
			for k in [[a, j, i], [c, j + 1, i + 1], [d, j, i + 1], [a, j, i], [b, j + 1, i], [c, j + 1, i + 1]]:
				st.set_normal(k[0][1])
				st.set_uv(Vector2(float(k[1]) / seg, float(k[2]) * 0.15))
				st.add_vertex(k[0][0])
	st.generate_tangents()
	return st.commit()


## 两点之间带下垂的软管
static func hose(parent: Node3D, a: Vector3, b: Vector3, sag: Vector3, r := 0.035, m: Material = null) -> MeshInstance3D:
	var mid := (a + b) * 0.5 + sag
	var pts := [a, a.lerp(mid, 0.6) + sag * 0.3, mid, b.lerp(mid, 0.6) + sag * 0.3, b]
	var mi := MeshInstance3D.new()
	mi.mesh = tube(pts, r)
	mi.material_override = m if m else rubber()
	parent.add_child(mi)
	A_end_caps(parent, a, b, r)
	return mi


static func A_end_caps(parent: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	for p in [a, b]:
		add(parent, sphere(r * 1.5, -1, 8), metal(Color(0.5, 0.48, 0.42)), p, Vector3.ZERO, Vector3.ONE, false)


## 一排铆钉。normal_rot：让铆钉圆柱轴朝外的旋转（度）
static func rivets(parent: Node3D, from: Vector3, to: Vector3, n: int, r := 0.022, normal_rot := Vector3(90, 0, 0)) -> void:
	var m := metal(Color(0.35, 0.35, 0.36))
	var mesh := cyl(r, r * 1.2, r * 1.3, 6)
	for i in n:
		var t: float = float(i) / max(1, n - 1)
		add(parent, mesh, m, from.lerp(to, t), normal_rot, Vector3.ONE, false)


## 散热格栅：深色凹槽 + 若干横向叶片。size 的 z 为厚度方向（朝外 = -Z）
static func vent(parent: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO, slats := 5) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	parent.add_child(n)
	add(n, bevel_box(size, 0.015), paint(Color(0.04, 0.04, 0.045), 0.3, 0.8, {"panel_scale": 0.0, "wear": 0.0}), Vector3.ZERO)
	var fr := metal(Color(0.22, 0.22, 0.24))
	for i in slats:
		var y := -size.y * 0.5 + (i + 0.5) * size.y / slats
		add(n, bevel_box(Vector3(size.x * 0.94, size.y / slats * 0.35, size.z * 0.6), 0.008), fr, Vector3(0, y, -size.z * 0.35), Vector3(-30, 0, 0), Vector3.ONE, false)
	return n


## 喷涂字样
static func stencil(parent: Node3D, text: String, pos: Vector3, rot: Vector3, px := 0.004, c := Color(0.92, 0.9, 0.85, 0.85), fs := 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = fs
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = rot
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	parent.add_child(l)
	return l


## 传感器镜头：车削遮光镜筒 + 内壁消光环 + 镀膜光学镜片（避免玩具灯泡感）
static func lens(parent: Node3D, pos: Vector3, rot: Vector3, r: float, c := Color(1.0, 0.28, 0.14), energy := 1.6) -> void:
	var dir := Basis.from_euler(rot * PI / 180.0)
	add(parent, cyl(r * 1.38, r * 0.95, r * 1.48, 16), metal(Color(0.11, 0.115, 0.125)), pos, rot)
	add(parent, torus(r * 0.92, r * 1.34, 16), metal(Color(0.20, 0.21, 0.23)), pos + dir * Vector3(0, r * 0.46, 0), rot, Vector3(1, 0.45, 1), false)
	add(parent, cyl(r * 1.02, r * 0.22, r * 1.02, 14), paint(Color(0.02, 0.02, 0.025), 0.1, 0.92, {"wear": 0.0}), pos + dir * Vector3(0, r * 0.36, 0), rot, Vector3.ONE, false)
	var g_key := "lens_g_%s_%.2f" % [c.to_html(), energy]
	var mat: StandardMaterial3D = _mat_cache.get(g_key)
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.albedo_color = c.darkened(0.55)
		mat.metallic = 0.65
		mat.roughness = 0.08
		if not is_mobile_perf():
			mat.clearcoat_enabled = true
			mat.clearcoat = 1.0
			mat.clearcoat_roughness = 0.04
		if energy >= 0.45:
			mat.emission_enabled = true
			mat.emission = c
			mat.emission_energy_multiplier = minf(energy * 0.55, 1.8)
		_mat_cache[g_key] = mat
	add(parent, sphere(r * 0.94, r * 0.62, 14), mat, pos + dir * Vector3(0, r * 0.34, 0), rot, Vector3.ONE, false)



## 打捞团队徽：圆环 + 三爪抓钩（程序化 SDF 绘制，带做旧斑驳）
static var _emblem: ImageTexture
static func emblem_tex() -> ImageTexture:
	if _emblem:
		return _emblem
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.08
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
			var r := p.length()
			var a := 0.0
			if r > 0.78 and r < 0.95:
				a = 1.0
			# 三爪：从中心向下三条放射线 + 上方横杆
			var ang := atan2(p.y, p.x)
			for k in 3:
				var dir := deg_to_rad(60.0 + k * 30.0)
				var d := absf(sin(ang - dir)) * r
				if d < 0.07 and r < 0.68 and cos(ang - dir) > 0.0:
					a = 1.0
			if absf(p.y + 0.35) < 0.07 and absf(p.x) < 0.45:
				a = 1.0
			if absf(p.x) < 0.07 and p.y < -0.35 and p.y > -0.66:
				a = 1.0
			var worn := nz.get_noise_2d(x, y) * 0.5 + 0.5
			a *= smoothstep(0.25, 0.45, worn)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_emblem = ImageTexture.create_from_image(img)
	return _emblem


static func emblem(parent: Node3D, pos: Vector3, rot: Vector3, size := 0.3, c := Color(0.95, 0.62, 0.18, 0.9)) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = emblem_tex()
	s.pixel_size = size / 128.0
	s.modulate = c
	s.shaded = true
	s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	s.position = pos
	s.rotation_degrees = rot
	parent.add_child(s)
	return s
