extends RefCounted
## 程序化美术库：倒角网格、PBR 材质（三平面映射 + 噪声细节）、粒子、贴图。
## 所有资源按参数缓存，避免重复创建。

static var _mesh_cache := {}
static var _mat_cache := {}
static var _tex_cache := {}


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
	# 6 个面（顶点色白），棱与角（顶点色 R=0，供着色器做掉漆）
	_vc = Color(1, 1, 1)
	for s in S:
		_quad(st, P.call(s, -1, -1, 0, 1, 1), P.call(s, 1, -1, 0, 1, 1), P.call(s, 1, 1, 0, 1, 1), P.call(s, -1, 1, 0, 1, 1), C)
		_quad(st, P.call(-1, s, -1, 1, 0, 1), P.call(1, s, -1, 1, 0, 1), P.call(1, s, 1, 1, 0, 1), P.call(-1, s, 1, 1, 0, 1), C)
		_quad(st, P.call(-1, -1, s, 1, 1, 0), P.call(1, -1, s, 1, 1, 0), P.call(1, 1, s, 1, 1, 0), P.call(-1, 1, s, 1, 1, 0), C)
	# 12 条棱
	_vc = Color(0, 1, 1)
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
	if seg >= 5:
		var cap_seg := 8 if rmax < 0.08 else (10 if rmax < 0.2 else (14 if rmax < 0.45 else (18 if rmax < 1.2 else 28)))
		s_seg = mini(seg, cap_seg) if seg == 28 else clampi(seg, 5, cap_seg + 4)
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
	if seg >= 5:
		var cap_seg := 8 if r < 0.08 else (10 if r < 0.2 else (14 if r < 0.5 else (18 if r < 1.2 else 26)))
		s_seg = mini(seg, cap_seg) if seg == 28 else clampi(seg, 5, cap_seg + 4)
	var key := "sp%.3f|%.3f|%d" % [r, hgt, s_seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if hgt < 0 else hgt
	s.radial_segments = s_seg
	s.rings = maxi(5, s_seg / 2)
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
	var cap_seg := 10 if outer < 0.12 else (14 if outer < 0.35 else (18 if outer < 1.0 else 28))
	var s_seg := mini(seg, cap_seg) if seg >= 24 else clampi(seg, 6, cap_seg + 4)
	var key := "to%.3f|%.3f|%d" % [inner, outer, s_seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = s_seg
	t.ring_segments = 8 if (outer - inner) < 0.15 else 10
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


## 烟雾团
static func smoke_tex() -> Texture2D:
	if _tex_cache.has("smoke"):
		return _tex_cache["smoke"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32).length() / 32.0
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = a * a * (0.6 + 0.4 * n.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(1, 1, 1, clamp(a, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["smoke"] = t
	return t


## 地面光圈/阴影斑
static func ring_tex() -> Texture2D:
	if _tex_cache.has("ring"):
		return _tex_cache["ring"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.78, 0.86, 0.92, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.14), Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	_tex_cache["ring"] = t
	return t


## 柔和烟团贴图（白色、极软边，用于大团飘烟）
static func cloud_tex() -> Texture2D:
	if _tex_cache.has("cloud"):
		return _tex_cache["cloud"]
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 7
	nz.frequency = 0.035
	nz.fractal_octaves = 4
	for y in 128:
		for x in 128:
			var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
			var fall: float = clamp(1.0 - d, 0.0, 1.0)
			fall = fall * fall * (3.0 - 2.0 * fall)
			var n: float = nz.get_noise_2d(x, y) * 0.5 + 0.5
			img.set_pixel(x, y, Color(1, 1, 1, clamp(fall * (0.35 + n * 0.9), 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_tex_cache["cloud"] = t
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
	t.width = 64
	t.height = 64
	_tex_cache["blob"] = t
	return t


# ======================================================================
# 材质
# ======================================================================
const WORLD_TEX_DIR := "res://assets/textures/world/"
static func world_tex(file: String) -> Texture2D:
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
		_paint_shader = load("res://shaders/mech_paint.gdshader")
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
	m.set_shader_parameter("albedo_tex_strength", 0.44)
	m.set_shader_parameter("normal_tex", world_tex("steel_plate_n.png"))
	m.set_shader_parameter("normal_strength", 0.42)
	if not opts.has("panel_scale"):
		m.set_shader_parameter("panel_scale", 0.0)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	_mat_cache[key] = m
	return m


static func metal(c := Color(0.18, 0.19, 0.21)) -> ShaderMaterial:
	return paint(c, 0.68, 0.44, {
		"wear": 0.35, "panel_scale": 0.0, "dust": 0.12, "rust": 0.08,
		"scratches": 0.28, "bare_metal": c.lightened(0.55),
		"albedo_tex_strength": 0.56, "normal_strength": 0.55,
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


## 现浇模板混凝土：木模板横纹 + 对拉螺杆孔 + 骨料砂砾法线 + 雨水流痕
static func concrete(c: Color, seams := true) -> ShaderMaterial:
	return paint(c, 0.0, 0.92, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("concrete_a.png"), "albedo_tex_scale": 0.24, "albedo_tex_strength": 0.84,
		"normal_tex": world_tex("concrete_n.png"), "normal_strength": 0.85,
		"wear": 0.42, "metal_wear": 0.0, "bare_metal": c.lightened(0.22), "scratches": 0.0,
		"rust": 0.52, "rust_color": Color(0.16, 0.14, 0.12), "grime": 0.82, "dust": 0.22, "dust_color": Color(0.42, 0.38, 0.33),
		"panel_scale": 0.26 if seams else 0.0, "detail_scale": 0.85,
	})


## 重工业顺丁错缝窑变砖墙：真实灰缝凹陷法线 + 单砖窑变色阶 + 烟熏泛碱
static func brick(c := Color(0.46, 0.30, 0.23), scale := 0.34) -> ShaderMaterial:
	return paint(c, 0.0, 0.91, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("brick_a.png"), "albedo_tex_scale": scale, "albedo_tex_strength": 0.92,
		"normal_tex": world_tex("brick_n.png"), "normal_strength": 1.05,
		"wear": 0.32, "metal_wear": 0.0, "bare_metal": c.lightened(0.20), "scratches": 0.0,
		"rust": 0.46, "rust_color": Color(0.15, 0.12, 0.10), "grime": 0.82, "dust": 0.20, "dust_color": Color(0.44, 0.40, 0.35),
		"panel_scale": 0.0, "detail_scale": 1.0,
	})


## 梯形压型波纹钢墙板：立体竖向波纹肋 + 横向螺栓搭接板缝 + 搭接处锈蚀
static func corrugated(c: Color, rust_amt := 0.42, scale := 0.24) -> ShaderMaterial:
	return paint(c, 0.46, 0.56, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("corrugated_a.png"), "albedo_tex_scale": scale, "albedo_tex_strength": 0.88,
		"normal_tex": world_tex("corrugated_n.png"), "normal_strength": 0.82,
		"wear": 0.46, "metal_wear": 1.0, "scratches": 0.24,
		"rust": rust_amt, "grime": 0.65, "dust": 0.22,
		"panel_scale": 0.0, "detail_scale": 1.0,
	})


## 直立锁边 / 重工金属瓦屋面：顺坡向立体锁边肋 + 横向叠瓦阶梯缝
static func roof_mat(c: Color, rust_amt := 0.36, sloped := true) -> ShaderMaterial:
	return paint(c, 0.34, 0.66, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("roof_seam_a.png"), "albedo_tex_scale": 0.23, "albedo_tex_strength": 0.88,
		"normal_tex": world_tex("roof_seam_n.png"), "normal_strength": 0.78,
		"roof_uv": 1.0 if sloped else 0.0,
		"wear": 0.38, "metal_wear": 1.0, "scratches": 0.15,
		"rust": rust_amt, "grime": 0.58, "dust": 0.30,
		"panel_scale": 0.0, "detail_scale": 1.0,
	})


## 沥青油毡防水工业平屋面：卷材搭接缝 + 粗砾石撒面 + 积水补丁
static func tar_roof(c := Color(0.26, 0.27, 0.28), dust_amt := 0.30) -> ShaderMaterial:
	return paint(c, 0.0, 0.89, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("tar_roof_a.png"), "albedo_tex_scale": 0.26, "albedo_tex_strength": 0.88,
		"normal_tex": world_tex("tar_roof_n.png"), "normal_strength": 0.88,
		"roof_uv": 1.0,
		"wear": 0.24, "metal_wear": 0.0, "bare_metal": c.lightened(0.14), "scratches": 0.0,
		"rust": 0.24, "rust_color": Color(0.15, 0.14, 0.13), "grime": 0.62, "dust": dust_amt, "dust_color": Color(0.36, 0.34, 0.31),
		"panel_scale": 0.0, "detail_scale": 1.0,
	})


## 粗骨料工业沥青路面：玄武岩碎石颗粒 + 修补油渍 + 骨料凹凸
static func asphalt(c := Color(0.28, 0.285, 0.295)) -> ShaderMaterial:
	return paint(c, 0.0, 0.88, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("asphalt_a.png"), "albedo_tex_scale": 0.38, "albedo_tex_strength": 0.88,
		"normal_tex": world_tex("asphalt_n.png"), "normal_strength": 0.88,
		"wear": 0.18, "metal_wear": 0.0, "bare_metal": c.lightened(0.14), "scratches": 0.0,
		"rust": 0.20, "rust_color": Color(0.14, 0.13, 0.12), "grime": 0.45,
		"dust": 0.12, "dust_color": Color(0.32, 0.30, 0.27),
		"panel_scale": 0.0, "detail_scale": 1.0,
	})


## 压实道砟 / 砂砾河滩与土路材质
static func gravel_mat(c := Color(0.36, 0.33, 0.29), rough := 0.94) -> ShaderMaterial:
	return paint(c, 0.0, rough, {
		"use_albedo_tex": 1.0, "albedo_tex": world_tex("ground_gravel_a.png"), "albedo_tex_scale": 0.34, "albedo_tex_strength": 0.88,
		"normal_tex": world_tex("ground_gravel_n.png"), "normal_strength": 0.92,
		"wear": 0.15, "metal_wear": 0.0, "bare_metal": c.lightened(0.10), "scratches": 0.0,
		"rust": 0.22, "rust_color": c.darkened(0.28), "grime": 0.55,
		"dust": 0.16, "dust_color": c.lightened(0.06),
		"panel_scale": 0.0, "detail_scale": 1.0,
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
		_foliage_shader = load("res://shaders/foliage.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _foliage_shader
	m.set_meta("no_outline", true)
	match kind:
		"pine":
			m.set_shader_parameter("albedo_tex", world_tex("pine_frond_a.png"))
			m.set_shader_parameter("normal_tex", world_tex("pine_frond_n.png"))
			m.set_shader_parameter("use_normal", 1.0)
			m.set_shader_parameter("tint_a", Color(0.92, 0.96, 0.84))
			m.set_shader_parameter("tint_b", Color(1.12, 1.04, 0.86))
			m.set_shader_parameter("rough_val", 0.80)
			m.set_shader_parameter("alpha_cut", 0.34)
			m.set_shader_parameter("sway_amp", 0.04)
		"broad":
			m.set_shader_parameter("albedo_tex", world_tex("broadleaf_a.png"))
			m.set_shader_parameter("normal_tex", world_tex("broadleaf_n.png"))
			m.set_shader_parameter("use_normal", 1.0)
			m.set_shader_parameter("tint_a", Color(0.94, 1.00, 0.84))
			m.set_shader_parameter("tint_b", Color(1.16, 1.02, 0.80))
			m.set_shader_parameter("rough_val", 0.76)
			m.set_shader_parameter("alpha_cut", 0.34)
			m.set_shader_parameter("sway_amp", 0.05)
		"autumn":
			m.set_shader_parameter("albedo_tex", world_tex("broadleaf_a.png"))
			m.set_shader_parameter("normal_tex", world_tex("broadleaf_n.png"))
			m.set_shader_parameter("use_normal", 1.0)
			m.set_shader_parameter("tint_a", Color(1.12, 0.84, 0.56))
			m.set_shader_parameter("tint_b", Color(1.26, 0.96, 0.62))
			m.set_shader_parameter("rough_val", 0.82)
			m.set_shader_parameter("alpha_cut", 0.36)
			m.set_shader_parameter("sway_amp", 0.045)
		"shrub":
			m.set_shader_parameter("albedo_tex", world_tex("broadleaf_a.png"))
			m.set_shader_parameter("normal_tex", world_tex("broadleaf_n.png"))
			m.set_shader_parameter("use_normal", 1.0)
			m.set_shader_parameter("tint_a", Color(0.88, 0.94, 0.78))
			m.set_shader_parameter("tint_b", Color(1.06, 0.96, 0.76))
			m.set_shader_parameter("rough_val", 0.82)
			m.set_shader_parameter("alpha_cut", 0.32)
			m.set_shader_parameter("sway_amp", 0.025)
		"grass":
			m.set_shader_parameter("albedo_tex", world_tex("grass_tuft_a.png"))
			m.set_shader_parameter("use_normal", 0.0)
			m.set_shader_parameter("tint_a", Color(0.86, 0.88, 0.74))
			m.set_shader_parameter("tint_b", Color(1.10, 0.98, 0.76))
			m.set_shader_parameter("rough_val", 0.88)
			m.set_shader_parameter("alpha_cut", 0.30)
			m.set_shader_parameter("sway_amp", 0.055)
			m.set_shader_parameter("backlight_str", 0.44)
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
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.normal_enabled = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	match part:
		"shell":
			m.albedo_texture = _bug_tex("chitin_%s.png" % kind)
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
		"leg":
			m.albedo_texture = _bug_tex("leg_%s.png" % kind)
			m.normal_texture = _bug_tex("leg_n.png")
			m.roughness_texture = _bug_tex("leg_r.png")
			m.roughness = 1.0
			m.clearcoat_enabled = true
			m.clearcoat = 0.3
			m.clearcoat_roughness = 0.35
		"eye":
			m.albedo_texture = _bug_tex("eye_a.png")
			m.normal_texture = _bug_tex("eye_n.png")
			m.normal_scale = 0.8
			m.roughness = 0.12
			m.metallic_specular = 0.8
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.05
		"membrane":
			m.albedo_texture = _bug_tex("membrane_a.png")
			m.normal_texture = _bug_tex("membrane_n.png")
			m.roughness = 0.4
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.4
		"sac":
			m.albedo_texture = _bug_tex("sac_a.png")
			m.normal_texture = _bug_tex("membrane_n.png")
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = Color(0.35, 0.6, 0.1)
			m.emission_energy_multiplier = 0.3
			m.emission_texture = _bug_tex("sac_e.png")
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.1
			m.clearcoat_roughness = 0.15
		"claw":
			m.albedo_texture = _bug_tex("claw_a.png")
			m.normal_texture = _bug_tex("leg_n.png")
			m.normal_scale = 0.5
			m.roughness = 0.3
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
	_mat_cache[key] = m
	return m


## 虫族菌毯：带发光脉络的地表贴片。
static func creep() -> StandardMaterial3D:
	if _mat_cache.has("creep"):
		return _mat_cache["creep"]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.11, 0.08, 0.06, 0.82)
	m.albedo_texture = noise_tex("grime")
	m.emission_enabled = true
	m.emission = Color(0.45, 0.2, 0.06)
	m.emission_energy_multiplier = 0.08
	m.emission_texture = noise_tex("creep")
	m.normal_enabled = true
	m.normal_texture = noise_tex("ground_n", 512)
	m.normal_scale = 1.35
	m.roughness = 0.28
	m.clearcoat_enabled = true
	m.clearcoat = 0.65
	m.clearcoat_roughness = 0.2
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	_mat_cache["creep"] = m
	return m


static func ground() -> ShaderMaterial:
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
varying vec3 wp;

vec2 h2(vec2 p){ p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
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

	// 双尺度非周期旋转采样，兼顾近景颗粒锐度与高空俯拍零重复感
	vec2 uv_near = p * 0.27;
	vec2 uv_far = rot2(p * 0.072 + vec2(11.3, 7.9));
	vec3 s_col = mix(texture(soil_a, uv_near).rgb, texture(soil_a, uv_far).rgb, 0.44) * 1.50;
	vec3 g_col = mix(texture(grav_a, p * 0.31).rgb, texture(grav_a, rot2(p * 0.088)).rgb, 0.42) * 1.54;
	vec3 c_col = mix(texture(conc_a, p * 0.22).rgb, texture(conc_a, rot2(p * 0.065)).rgb, 0.38) * 1.50;

	vec3 col = mix(dirt_b, dirt_a, smoothstep(0.28, 0.72, low + (hi - 0.5) * 0.32)) * s_col;

	// 仅在干涸泥滩区域出现自然扭曲干裂纹（彻底移除污染全图的 1.1m 蜂窝网格）
	float mudm = smoothstep(0.60, 0.78, mid + (hi - 0.5) * 0.14);
	float cr = cracks(p * 0.42 + vec2(low, mid) * 1.6);
	float crack_mud = (1.0 - smoothstep(0.015, 0.065, cr)) * mudm;
	col = mix(col, mud * s_col * 0.92, mudm);
	col *= 1.0 - crack_mud * 0.34;

	// 荒草苔斑：融入壤土碎屑底纹
	float gm = smoothstep(0.44, 0.72, 1.0 - mid + (low - 0.5) * 0.42 + (hi - 0.5) * 0.22) * (1.0 - mudm);
	vec3 gcol = mix(grass, grass2, hi2) * mix(vec3(1.0), s_col, 0.58);
	col = mix(col, gcol, gm * 0.82 * smoothstep(0.22, 0.68, hi2 + 0.12));

	// 散落自然碎石斑块
	float grav_patch = smoothstep(0.58, 0.78, hi * 0.65 + (1.0 - low) * 0.35) * (1.0 - gm * 0.75);
	col = mix(col, dirt_a * 0.90 * g_col, grav_patch * 0.46);
	col *= mix(0.82, 1.14, low * 0.55 + med2 * 0.45);

	// 分区地表：R 硬化混凝土场坪 / G 林草荒地 / B 翻耕熟土 / A 工业压实道砟碎石
	vec2 bfade = smoothstep(vec2(zone_half + 4.0), vec2(zone_half - 14.0), abs(p));
	float zfade = bfade.x * bfade.y * zone_on;
	vec2 z_uv = clamp((p + zone_half) / (zone_half * 2.0) + (vec2(low, mid) - 0.5) * 0.030, vec2(0.002), vec2(0.998));
	vec4 zt = texture(zone_tex, z_uv) * zfade;

	float row_id = floor(p.y / 2.4);
	vec2 slab_uv = vec2((p.x + mod(row_id, 2.0) * 1.8) / 3.6, p.y / 2.4);
	vec2 tf = abs(fract(slab_uv) - 0.5);
	float seam_mask = smoothstep(0.58, 0.88, zt.r) * (1.0 - smoothstep(0.50, 0.76, mid));
	float seam = smoothstep(0.482, 0.497, max(tf.x, tf.y)) * seam_mask;
	float slab_var = fract(sin(dot(floor(slab_uv), vec2(41.3, 289.1))) * 43758.5453);
	vec3 pave = vec3(0.34, 0.335, 0.32) * c_col * mix(0.88, 1.08, low * 0.6 + med2 * 0.4) * (0.95 + slab_var * 0.09);
	pave *= 1.0 - seam * 0.28;
	pave = mix(pave, vec3(0.22, 0.215, 0.205) * c_col, smoothstep(0.54, 0.80, mid) * 0.36);
	float pm = smoothstep(0.32, 0.86, zt.r + (low - 0.5) * 0.26 + (mid - 0.5) * 0.22 + (hi - 0.5) * 0.16) * (1.0 - mudm * 0.42);
	col = mix(col, pave, pm);

	vec3 gr = mix(vec3(0.21, 0.26, 0.13), vec3(0.35, 0.36, 0.19), hi2) * mix(vec3(1.0), s_col, 0.62) * (0.85 + low * 0.30);
	float gmm = smoothstep(0.22, 0.82, zt.g + (low - 0.5) * 0.24 + (mid - 0.5) * 0.36 + (hi - 0.5) * 0.20);
	col = mix(col, gr, gmm);

	float fw = clamp(1.0 - length(fwidth(p)) * 0.45, 0.0, 1.0);
	float furrow = 0.5 + 0.5 * sin((p.x * 0.35 + p.y * 0.94) * 2.1 + (low - 0.5) * 2.4 + (mid - 0.5) * 1.4) * fw;
	vec3 soil = mix(vec3(0.24, 0.19, 0.13), vec3(0.34, 0.27, 0.18), smoothstep(0.2, 0.8, mix(mid, furrow, 0.36))) * s_col;
	float smm = smoothstep(0.24, 0.82, zt.b + (low - 0.5) * 0.28 + (mid - 0.5) * 0.24 + (hi - 0.5) * 0.18);
	col = mix(col, soil, smm);

	float rut = smoothstep(0.64, 0.92, abs(sin((p.x * 0.72 + (low - 0.5) * 6.0) * 2.2))) * smoothstep(0.38, 0.70, mid) * fw;
	vec3 grv = mix(vec3(0.36, 0.34, 0.305), vec3(0.45, 0.40, 0.33), low * 0.65 + med2 * 0.35) * g_col;
	grv = mix(grv, vec3(0.22, 0.21, 0.195) * g_col, smoothstep(0.56, 0.78, mid) * 0.40 + rut * 0.16);
	float am = smoothstep(0.28, 0.84, zt.a + (low - 0.5) * 0.26 + (mid - 0.5) * 0.22 + (hi - 0.5) * 0.18) * (1.0 - mudm * 0.35);
	col = mix(col, grv, am);

	float zone_cov = clamp(pm + gmm * 0.88 + smm * 0.88 + am * 0.88, 0.0, 0.94);
	float wet_film = mudm * (1.0 - zone_cov) * smoothstep(0.65, 0.84, mid) * (1.0 - crack_mud * 0.85);
	col = mix(col, col * 0.74, wet_film * 0.42);
	if (abs(sector_on) > 0.5) {
		vec2 s_uv = (p + zone_half) / (zone_half * 2.0);
		float s_in = 0.0;
		if (s_uv.x >= 0.0 && s_uv.x <= 1.0 && s_uv.y >= 0.0 && s_uv.y <= 1.0) {
			s_in = smoothstep(0.20, 0.80, texture(sector_tex, s_uv).r + (low - 0.5) * 0.16);
		}
		vec3 out_mul = (sector_on > 0.0) ? vec3(0.76, 0.78, 0.82) : vec3(0.28, 0.25, 0.32);
		col = mix(col * out_mul, col, s_in);
	}
	ALBEDO = col;
	float r_base = mix(0.93, 0.78, mudm * (1.0 - zone_cov));
	r_base = mix(r_base, 0.84, pm * (1.0 - seam));
	r_base = mix(r_base, 0.91, am);
	ROUGHNESS = mix(r_base, 0.56, wet_film);
	SPECULAR = mix(0.32, 0.48, pm * 0.35 + wet_film * 0.35);
	AO = clamp(1.0 - crack_mud * 0.58 - pm * seam * 0.42 - am * rut * 0.18, 0.30, 1.0);
	AO_LIGHT_AFFECT = 0.55;
	CLEARCOAT = 0.0;

	// 按地表类型融合真实壤土颗粒、碎石道砟与混凝土法线贴图
	vec3 ns = mix(texture(soil_n, uv_near).rgb, texture(soil_n, uv_far).rgb, 0.35);
	vec3 ng = texture(grav_n, p * 0.31).rgb;
	vec3 nc = texture(conc_n, p * 0.22).rgb;
	vec3 n_macro = texture(n_nrm, p * 0.065).rgb;
	vec3 n_det = mix(ns, ng, clamp(am + grav_patch * 0.45, 0.0, 1.0));
	n_det = mix(n_det, nc, pm);
	NORMAL_MAP = normalize((n_det * 2.0 - 1.0) * mix(0.48, 0.85, fw) + (n_macro * 2.0 - 1.0) * 0.52 + vec3(0.0, 0.0, 0.52)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.76, 1.12, fw) + crack_mud * 1.25 + pm * seam * 1.05 + am * 0.30;
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
	m.set_meta("no_outline", true)
	_mat_cache["ground"] = m
	return m


## 叠加用的贴地材质（光圈、阴影斑等），不受光。
static func decal_mat(tex: Texture2D, c: Color, additive := false) -> StandardMaterial3D:
	var key := "decal%s%s%s" % [tex.get_instance_id(), c.to_html(), additive]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.render_priority = -1
	_mat_cache[key] = m
	return m


static func particle_mat(tex: Texture2D, additive := true) -> StandardMaterial3D:
	var key := "pm%s%s" % [tex.get_instance_id(), additive]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


## 受击闪白叠加层
static func flash_overlay() -> StandardMaterial3D:
	if _mat_cache.has("flash"):
		return _mat_cache["flash"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_cache["flash"] = m
	return m


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
	var pool: Array = _burst_pool.get(key, [])
	while not pool.is_empty():
		var q = pool.pop_back()
		if is_instance_valid(q) and q.is_inside_tree() and q.get_parent() == parent:
			q.visible = true
			q.flatness = 0.0
			q.direction = opts.get("dir", Vector3.UP)
			q.global_position = pos
			q.restart()
			return q
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = opts.get("explosive", 0.95)
	p.amount = opts.get("amount", 16)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.lifetime = opts.get("life", 0.5)
	p.local_coords = false
	var tex: Texture2D = opts.get("tex", soft_dot())
	var add: bool = opts.get("additive", true)
	var sz: float = opts.get("size", 0.3)
	if opts.has("mesh"):
		p.mesh = opts["mesh"]
		p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, bool(opts.get("align_y", false)))
		p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ROTATE_Y, true)
		p.angular_velocity_min = opts.get("ang_min", -360.0)
		p.angular_velocity_max = opts.get("ang_max", 360.0)
	else:
		p.mesh = _burst_res_get("q%d|%s|%s" % [tex.get_instance_id(), add, sz], func():
			var qm := QuadMesh.new()
			qm.size = Vector2.ONE * sz
			qm.material = particle_mat(tex, add)
			return qm)
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
	p.scale_amount_curve = _burst_res_get("c%s|%s" % [g0, g1], func():
		var curve := Curve.new()
		curve.add_point(Vector2(0, g0))
		curve.add_point(Vector2(1, g1))
		return curve)
	var c0: Color = opts.get("c0", Color(1, 0.8, 0.4))
	var c1: Color = opts.get("c1", Color(c0.r, c0.g * 0.4, 0.0, 0.0))
	p.color_ramp = _burst_res_get("g%s|%s" % [c0, c1], func():
		var g := Gradient.new()
		g.set_color(0, c0)
		g.set_color(1, c1)
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
	p.amount = opts.get("amount", 24)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.lifetime = opts.get("life", 1.0)
	p.local_coords = opts.get("local", false)
	if opts.has("mesh"):
		p.mesh = opts["mesh"]
		p.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ROTATE_Y, true)
		p.angular_velocity_min = opts.get("ang_min", -240.0)
		p.angular_velocity_max = opts.get("ang_max", 240.0)
	else:
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * opts.get("size", 0.5)
		qm.material = particle_mat(opts.get("tex", soft_dot()), opts.get("additive", true))
		p.mesh = qm
	p.direction = opts.get("dir", Vector3.UP)
	p.spread = opts.get("spread", 15.0)
	p.initial_velocity_min = opts.get("vmin", 1.0)
	p.initial_velocity_max = opts.get("vmax", 2.0)
	p.gravity = opts.get("gravity", Vector3(0, 1, 0))
	p.scale_amount_min = opts.get("smin", 0.6)
	p.scale_amount_max = opts.get("smax", 1.2)
	var curve := Curve.new()
	curve.add_point(Vector2(0, opts.get("grow0", 0.5)))
	curve.add_point(Vector2(1, opts.get("grow1", 1.0)))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, opts.get("c0", Color(1, 0.7, 0.3)))
	g.set_color(1, opts.get("c1", Color(0.3, 0.1, 0.0, 0.0)))
	if opts.has("cmid"):
		g.add_point(0.3, opts.cmid)
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
