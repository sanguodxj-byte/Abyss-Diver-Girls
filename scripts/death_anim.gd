extends RefCounted
## 机甲与虫族/首领通用死亡物理贴地、防穿墙散落与残骸断电焦化工具库。
## 核心目标：通过物理地面采样 + 姿态预演包围盒最低点（PMRT）精确解算，确保任何平地、斜坡、高空击坠或模块崩脱均 100% 贴地零浮空。

const A = preload("res://scripts/art.gd")

const SKIP_NODE_NAMES := {
	"Shadow": true,
	"MechShadow": true,
	"Plug": true,
	"Receiver": true,
	"Tag": true,
	"Marker": true,
}


## 采样世界坐标 (wx, wz) 下方的真实承载地面高度与法线；无碰撞体场景（如纯逻辑单测）安全回退至 y=0。
static func sample_ground(ctx: Node, world_pos: Vector3, up_pad := 2.6, max_drop := 48.0) -> Dictionary:
	if ctx == null or not is_instance_valid(ctx) or not (ctx is Node3D) or not ctx.is_inside_tree():
		return {"y": 0.0, "normal": Vector3.UP, "hit": false}
	var w3d := (ctx as Node3D).get_world_3d()
	if w3d == null or w3d.direct_space_state == null:
		return {"y": 0.0, "normal": Vector3.UP, "hit": false}
	var sp := w3d.direct_space_state
	var from := Vector3(world_pos.x, world_pos.y + up_pad, world_pos.z)
	var to := Vector3(world_pos.x, world_pos.y - max_drop, world_pos.z)
	for _attempt in 4:
		var rq := PhysicsRayQueryParameters3D.create(from, to, 1)
		rq.hit_from_inside = false
		var hit := sp.intersect_ray(rq)
		if hit.is_empty():
			break
		var nrm: Vector3 = hit.get("normal", Vector3.UP)
		var hp: Vector3 = hit.get("position", Vector3.ZERO)
		if nrm.y >= 0.42:
			return {"y": hp.y, "normal": nrm.normalized(), "hit": true}
		# 擦碰到建筑立面或陡直岩壁：向下跳过继续寻找真实地面
		from = hp + Vector3(0.0, -0.22, 0.0)
		if from.y <= to.y:
			break
	return {"y": 0.0, "normal": Vector3.UP, "hit": false}


## 水平防穿墙射线约束：防止散落模块飞入建筑墙体内部或落到高处房顶。
static func clamp_scatter_xz(ctx: Node, origin_w: Vector3, target_w: Vector3, clearance := 0.68) -> Vector3:
	if ctx == null or not is_instance_valid(ctx) or not (ctx is Node3D) or not ctx.is_inside_tree():
		return target_w
	var w3d := (ctx as Node3D).get_world_3d()
	if w3d == null or w3d.direct_space_state == null:
		return target_w
	var a := Vector3(origin_w.x, origin_w.y + 0.95, origin_w.z)
	var b := Vector3(target_w.x, origin_w.y + 0.95, target_w.z)
	var delta := b - a
	var dist := delta.length()
	if dist < 0.15:
		return target_w
	var rq := PhysicsRayQueryParameters3D.create(a, b, 1)
	var hit := w3d.direct_space_state.intersect_ray(rq)
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		var safe_d := maxf(0.25, a.distance_to(hp) - clearance)
		var dir := delta / dist
		var clamped := origin_w + dir * safe_d
		return Vector3(clamped.x, target_w.y, clamped.z)
	return target_w


## 计算节点子树内全部实体可见网格在当前世界变换下的最低世界 Y 坐标（跳过平面贴花、阴影与接口辅助件）。
static func lowest_world_y(root: Node3D) -> float:
	if root == null or not is_instance_valid(root):
		return 0.0
	var min_y := INF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if not is_instance_valid(cur):
			continue
		var cname := str(cur.name)
		if SKIP_NODE_NAMES.has(cname):
			continue
		if cur is Node3D:
			var n3 := cur as Node3D
			if not n3.visible or n3.get_meta("no_ground_bounds", false) or n3.get_meta("player_ring", false):
				continue
			if cur != root and n3.top_level:
				continue
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var msh := mi.mesh
			if msh != null and not (msh is PlaneMesh) and not (msh is QuadMesh) and mi.transparency < 0.98:
				var ab := mi.get_aabb()
				if ab.size.length_squared() > 1e-6:
					var gxf := mi.global_transform
					for i in 8:
						var wy := (gxf * ab.get_endpoint(i)).y
						if wy < min_y:
							min_y = wy
		for ch in cur.get_children():
			stack.append(ch)
	return min_y if is_finite(min_y) else root.global_position.y


## 计算 root 子树（自动跳过已解绑 top_level 的飞散模块）相对于过 ground_pt、法线为 ground_nrm 的切平面地形的最小铅垂净空。
## 平地上等价于 lowest_world_y(root) - ground_pt.y；斜坡上精确消除宽体多足底盘上下坡高度差带来的伪悬空。
static func lowest_slope_clearance(root: Node3D, ground_pt: Vector3, ground_nrm := Vector3.UP) -> float:
	if root == null or not is_instance_valid(root):
		return 0.0
	var nrm := ground_nrm.normalized() if ground_nrm.length_squared() > 1e-5 else Vector3.UP
	var ny := maxf(nrm.y, 0.35)
	var min_clr := INF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if not is_instance_valid(cur):
			continue
		var cname := str(cur.name)
		if SKIP_NODE_NAMES.has(cname):
			continue
		if cur is Node3D:
			var n3 := cur as Node3D
			if not n3.visible or n3.get_meta("no_ground_bounds", false) or n3.get_meta("player_ring", false):
				continue
			if cur != root and n3.top_level:
				continue
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var msh := mi.mesh
			if msh != null and not (msh is PlaneMesh) and not (msh is QuadMesh) and mi.transparency < 0.98:
				var ab := mi.get_aabb()
				if ab.size.length_squared() > 1e-6:
					var gxf := mi.global_transform
					for i in 8:
						var wp := gxf * ab.get_endpoint(i)
						var local_gy := ground_pt.y - (nrm.x * (wp.x - ground_pt.x) + nrm.z * (wp.z - ground_pt.z)) / ny
						var clr := wp.y - local_gy
						if clr < min_clr:
							min_clr = clr
		for ch in cur.get_children():
			stack.append(ch)
	return min_clr if is_finite(min_clr) else 0.0


## 计算 root 在绕自身原点左乘纯旋转 R_world 后，相对于法线为 ground_nrm 的坡面最低铅垂偏移（<= 0）。
static func lowest_offset_under_world_rot(root: Node3D, R_world: Basis, ground_nrm := Vector3.UP) -> float:
	if root == null or not is_instance_valid(root):
		return -0.2
	var nrm := ground_nrm.normalized() if ground_nrm.length_squared() > 1e-5 else Vector3.UP
	var ny := maxf(nrm.y, 0.35)
	var origin := root.global_position
	var min_dy := INF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if not is_instance_valid(cur):
			continue
		if SKIP_NODE_NAMES.has(str(cur.name)):
			continue
		if cur is Node3D:
			var n3 := cur as Node3D
			if not n3.visible or n3.get_meta("no_ground_bounds", false):
				continue
			if cur != root and n3.top_level:
				continue
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var msh := mi.mesh
			if msh != null and not (msh is PlaneMesh) and not (msh is QuadMesh):
				var ab := mi.get_aabb()
				if ab.size.length_squared() > 1e-6:
					var gxf := mi.global_transform
					for i in 8:
						var rel_w := (gxf * ab.get_endpoint(i)) - origin
						var rot_w := R_world * rel_w
						var dy := rot_w.y + (nrm.x * rot_w.x + nrm.z * rot_w.z) / ny
						if dy < min_dy:
							min_dy = dy
		for ch in cur.get_children():
			stack.append(ch)
	return min_dy if is_finite(min_dy) else -0.2


## 将局部欧拉角姿态贴合到地形坡面法线（避免残骸在山坡上水平悬挑）。
static func slope_basis(ground_nrm: Vector3, yaw: float, pitch: float, roll: float, slope_weight := 0.78) -> Basis:
	var up := Vector3.UP.lerp(ground_nrm.normalized(), clampf(slope_weight, 0.0, 1.0)).normalized()
	var fwd_flat := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var rgt := fwd_flat.cross(up)
	if rgt.length_squared() < 1e-5:
		rgt = Vector3.RIGHT
	else:
		rgt = rgt.normalized()
	var fwd := up.cross(rgt).normalized()
	var slope_b := Basis(rgt, up, -fwd)
	return (slope_b * Basis.from_euler(Vector3(pitch, 0.0, roll))).orthonormalized()


## 断电熄灯与战损烟熏压暗：关闭光源、清除受击闪白覆盖层、熄灭发光件并赋予轻度焦黑质感（绝不污染全局共享材质）。
static func power_down_wreck(root: Node3D, tw: Tween = null, dur := 0.55, char_tint := 0.62) -> void:
	if root == null or not is_instance_valid(root):
		return
	var mat_map := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if not is_instance_valid(cur):
			continue
		if cur is OmniLight3D or cur is SpotLight3D:
			var lt := cur as Light3D
			if tw != null and dur > 0.05:
				tw.tween_property(lt, "light_energy", 0.0, dur * 0.65)
				tw.tween_callback(func():
					if is_instance_valid(lt):
						lt.visible = false).set_delay(dur * 0.66)
			else:
				lt.visible = false
		elif cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			mi.material_overlay = null
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var msh := mi.mesh
			if msh != null and not (msh is PlaneMesh) and not (msh is QuadMesh):
				var mo: Material = mi.material_override
				if mo != null:
					var mid := mo.get_instance_id()
					var dm: Material = mat_map.get(mid)
					if dm == null:
						dm = _make_wreck_mat(mo, char_tint)
						if dm != null:
							mat_map[mid] = dm
					if dm != null:
						mi.material_override = dm
		for ch in cur.get_children():
			stack.append(ch)


static func _make_wreck_mat(mo: Material, char_tint: float) -> Material:
	if mo is StandardMaterial3D:
		var sm := mo as StandardMaterial3D
		var d := sm.duplicate() as StandardMaterial3D
		if d.emission_enabled:
			d.emission_energy_multiplier = 0.0
			d.emission_enabled = false
			d.albedo_color = Color(0.06, 0.065, 0.075, d.albedo_color.a)
			d.roughness = 0.86
		else:
			d.albedo_color = Color(
				d.albedo_color.r * char_tint,
				d.albedo_color.g * (char_tint * 0.96),
				d.albedo_color.b * (char_tint * 0.92),
				d.albedo_color.a
			)
			d.roughness = clampf(d.roughness + 0.16, 0.0, 0.96)
		return d
	elif mo is ShaderMaterial:
		var shm := mo as ShaderMaterial
		if shm.shader != null:
			var sp := shm.shader.resource_path
			if sp.contains("mech_decal"):
				return null
			if sp.contains("mech_trim") or sp.contains("mech_paint") or sp.contains("enemy_pbr"):
				var dsh := shm.duplicate() as ShaderMaterial
				var bc = dsh.get_shader_parameter("base_color")
				if bc is Color:
					dsh.set_shader_parameter("base_color", Color(bc.r * char_tint, bc.g * (char_tint * 0.96), bc.b * (char_tint * 0.93), bc.a))
				if sp.contains("mech_trim") or sp.contains("enemy_pbr"):
					var gr = dsh.get_shader_parameter("grime")
					if gr != null:
						dsh.set_shader_parameter("grime", clampf(float(gr) + 0.28, 0.0, 0.95))
				return dsh
	return null
