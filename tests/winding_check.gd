extends "res://tests/lib/test_base.gd"
## 网格朝向自检：godot --headless --path . -- --winding_check
## 程序化网格的三角形绕序应与 Godot 内置网格（BoxMesh）一致，且凸体的法线朝外（圆环、软管的内侧法线本来就朝向中心，不查朝外）。
const A = preload("res://scripts/art.gd")
const START := "none"
const NO_OUTWARD := ["torus", "tube", "quad"]   # 圆环与软管的内侧法线朝向中心；平面没有内外

var ref_sign := 0
var problems: Array = []


func measure(name: String, mesh: Mesh) -> Vector3i:
	var good := 0
	var bad := 0
	var outw_bad := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var c := Vector3.ZERO
		for p in v: c += p
		c /= max(1, v.size())
		var tri := []
		if idx == null or idx.size() == 0:
			for i in range(0, v.size(), 3): tri.append([i, i+1, i+2])
		else:
			for i in range(0, idx.size(), 3): tri.append([idx[i], idx[i+1], idx[i+2]])
		for t in tri:
			var a: Vector3 = v[t[0]]; var b: Vector3 = v[t[1]]; var cc: Vector3 = v[t[2]]
			var fn := (b - a).cross(cc - a)
			if fn.length() < 1e-9: continue
			var vn: Vector3 = n[t[0]] + n[t[1]] + n[t[2]]
			if fn.dot(vn) > 0: good += 1
			else: bad += 1
			if vn.dot((a + b + cc) / 3.0 - c) < 0: outw_bad += 1
	log_line("%-16s cross.n>0: %d  <0: %d   normals-inward: %d" % [name, good, bad, outw_bad])
	return Vector3i(good, bad, outw_bad)


## 与参考网格同绕序（全部三角形同号）且凸体法线朝外
func verify(name: String, mesh: Mesh, kind: String) -> void:
	var r := measure(name, mesh)
	if r.x + r.y == 0:
		problems.append("%s 没有三角形" % name)
		return
	var mixed := r.x > 0 and r.y > 0
	var sg := 1 if r.x > 0 else -1
	if mixed or sg != ref_sign:
		problems.append("%s 绕序与内置网格不一致（%d / %d）" % [name, r.x, r.y])
	if not (kind in NO_OUTWARD) and r.z > 0:
		problems.append("%s 有 %d 个三角形法线朝内" % [name, r.z])


func run() -> void:
	var ref := measure("REF BoxMesh", BoxMesh.new())
	if not check(ref.x + ref.y > 0 and (ref.x == 0 or ref.y == 0), "参考网格 BoxMesh 的绕序无法判定"):
		return
	ref_sign = 1 if ref.x > 0 else -1
	verify("REF CylinderMesh", CylinderMesh.new(), "cyl")
	verify("bevel_box", A.bevel_box(Vector3(1, 1, 1), 0.06), "box")
	verify("bevel_box taper", A.bevel_box(Vector3(1, 1, 1), 0.06, 0.7), "box")
	verify("cyl", A.cyl(0.5, 1.0), "cyl")
	verify("cyl r2", A.cyl(0.5, 1.0, 0.2), "cyl")
	verify("cone", A.cyl(0.0, 1.0, 0.3), "cyl")
	verify("sphere", A.sphere(0.5), "sphere")
	verify("torus", A.torus(0.4, 0.5), "torus")
	verify("tube", A.tube([Vector3.ZERO, Vector3(0, 0, 1), Vector3(0.5, 0, 2)], 0.1), "tube")
	verify("quad", A.quad(1, 1), "quad")
	await frames(1)
	check(problems.is_empty(), "; ".join(problems))
