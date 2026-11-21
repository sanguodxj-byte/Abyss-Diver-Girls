extends CharacterBody3D
## 虫族（参考《绝地潜兵2》终端虫）：跳虫=猎手(近战快)、酸液虫=胆汁喷吐者(远程)、甲虫=冲锋者(肉盾)。
## 黑褐色厚重切角甲壳 + 甲片缝隙露出的橙黄肉质 + 发光脓包。

const Prof = preload("res://scripts/prof.gd")

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const RB = preload("res://scripts/render_batch.gd")

const KINDS := {
	"ling": {"name": "跳虫", "hp": 26.0, "speed": 8.8, "dmg": 6.0, "range": 2.0, "rate": 0.7, "radius": 0.6, "color": Color(0.36, 0.09, 0.16), "scale": 0.8, "drop": 0.25},
	"spitter": {"name": "酸液虫", "hp": 42.0, "speed": 5.0, "dmg": 9.0, "range": 14.0, "rate": 2.0, "radius": 0.75, "color": Color(0.2, 0.28, 0.1), "scale": 1.0, "drop": 0.4},
	"beetle": {"name": "甲虫", "hp": 190.0, "armor": 0.35, "speed": 4.2, "dmg": 20.0, "range": 2.8, "rate": 1.6, "radius": 1.35, "color": Color(0.24, 0.15, 0.1), "scale": 1.8, "drop": 0.9},

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
var state := "idle":
	set(v):
		state = v
		if _sleeping and v != "idle":
			_wake()
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
var _hit_meshes: Array = []
var _hit_meshes_ready := false
var _hit_flash_q := 0
var _occ_fade := 0.0
var _occ_meshes: Array = []
var _occ_shader_mats: Array = []
var _occ_emit_mats: Array = []
var _occ_mob_mats: Array = []      ## 移动端（Forward Mobile 不支持 GeometryInstance3D.transparency）材质级透明虚化缓存
var _occ_meshes_ready := false
static var _bug_occ_exempt_mats := {}
static var _occ_use_mat_alpha := -1
var _cached_bar_y := -1.0
const FLASH_DUR := 0.13
static var _dead_eye_mat: StandardMaterial3D
var _dead_lights: Array[MeshInstance3D] = []
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
var _body_node: Node3D
var _leg_anim: Array = []
var _leg_anim_cnt := -1


func setup(k: String, r, tgt) -> void:
	kind = k
	data = GameData.ENEMIES.get(k, KINDS.get(k, KINDS.ling))
	beh = data.get("beh", k)
	sfx = str(data.get("sfx", k))
	hp = data.hp
	raid = r
	target = tgt
	add_to_group("bugs")
	if bool(data.get("boss", false)) or float(data.get("scale", 1.0)) >= 1.45:
		add_to_group("occ_fade_bugs")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 16 | 32   # 16 流浪者机甲 / 32 战斗队友机甲
	# 8 = 河湖护堤 / 湖面：地面虫子也过不了水（飞行种照飞）
	if str(data.get("ai", "")) != "flyer" and float(data.get("hover", 0.0)) <= 0.0:
		collision_mask |= 8
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = data.radius
	shape.height = maxf(3.2, float(data.scale) * 1.6 + 1.0)   # 故意做高：俯视角下子弹从机甲肩部高度射出也能命中
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)
	strafe = 1.0 if randf() < 0.5 else -1.0
	anim_t = randf() * 10.0
	_lod_acc = randf() * 0.5
	_perc_t = randf()
	_build_visual()
	# 静态零件按材质合批：一只虫近百个网格压到十几个，动画部件（腿/颚/镰/翼等）保持独立
	_batch_static()
	if gun_glow and gun_glow.material_override:
		gun_glow.material_override = gun_glow.material_override.duplicate()
	var cmi = get("core_mi")
	if cmi is MeshInstance3D and cmi.material_override:
		cmi.material_override = cmi.material_override.duplicate()
	# 地面已有影子贴片；实时阴影在虫群多时会把绘制调用翻倍，零件一律不投影；同时为桌面与移动端均设合理视距剔除，避免地图远端 150+ 虫体常驻渲染列表
	var mob_perf := A.is_mobile_perf()
	var big := float(data.get("scale", 1.0)) >= 2.0 or bool(data.get("boss", false))
	var vis_end := 0.0
	if mob_perf:
		vis_end = 135.0 if big else (74.0 if GameData.quality == 0 else 92.0)
	else:
		vis_end = 260.0 if big else 165.0
	var vis_margin := 5.0 if mob_perf else 10.0
	for mi in parts:
		if is_instance_valid(mi) and mi is MeshInstance3D:
			var mi3: MeshInstance3D = mi as MeshInstance3D
			mi3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mo: Material = mi3.material_override
			if mo is ShaderMaterial:
				var sm := mo as ShaderMaterial
				if sm.shader != null and sm.shader.resource_path.contains("mech_paint"):
					var mid := sm.get_instance_id()
					var ex_m: ShaderMaterial = _bug_occ_exempt_mats.get(mid)
					if ex_m == null:
						ex_m = sm.duplicate() as ShaderMaterial
						ex_m.set_shader_parameter("occ_exempt", 1.0)
						_bug_occ_exempt_mats[mid] = ex_m
					mi3.material_override = ex_m
			if vis_end > 0.0 and not (mi3.mesh is PlaneMesh):
				mi3.visibility_range_end = vis_end
				mi3.visibility_range_end_margin = vis_margin
	_anchor_visual()
	# 死亡时只改已知发光件，避免临场逐节点读取材质（渲染线程同步）。
	_dead_lights.clear()
	for mi in parts:
		if is_instance_valid(mi) and mi.material_override is StandardMaterial3D and mi.material_override.emission_enabled:
			_dead_lights.append(mi)
	_get_dead_eye_mat().get_rid()


## 遮挡玩家机甲时由 raid.gd 平滑驱动的大型敌人虚化透明度（strength 0..1）
## Forward+ 使用原生 GeometryInstance3D.transparency；Forward Mobile / Compatibility 自动回退到材质级 TRANSPARENCY_ALPHA，
## 并在多舱段超巨型首领（六足要塞/浮空母舰）上按视线距离梯度加深中心穿透（外缘 0.62 → 核心 0.91），同步衰减自发光核心。
func set_occ_fade(strength: float, cam_p := Vector3.ZERO, mech_c := Vector3.ZERO) -> void:
	var clamped := clampf(strength, 0.0, 1.0)
	var is_giant := has_meta("modular_glb") or float(data.get("scale", 1.0)) >= 3.5
	if not is_giant and absf(clamped - _occ_fade) < 0.004 and not (clamped == 0.0 and _occ_fade > 0.0):
		return
	if clamped == 0.0 and _occ_fade == 0.0:
		return
	_occ_fade = clamped
	if _occ_use_mat_alpha < 0:
		_occ_use_mat_alpha = 0 if RenderingServer.get_current_rendering_method() == "forward_plus" else 1
	var use_mat_alpha := (_occ_use_mat_alpha == 1)

	if not _occ_meshes_ready:
		_occ_meshes_ready = true
		_occ_meshes.clear()
		_occ_shader_mats.clear()
		_occ_emit_mats.clear()
		_occ_mob_mats.clear()
		var local_sm_map := {}
		var local_em_map := {}
		var local_mob_map := {}
		if visual != null and is_instance_valid(visual):
			for n in visual.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi == null or mi.mesh == null or (mi.mesh is PlaneMesh):
					continue
				var mo: Material = mi.material_override
				if mo is ShaderMaterial:
					var sm := mo as ShaderMaterial
					if sm.shader != null and (sm.shader.resource_path.contains("mech_paint") or sm.shader.resource_path.contains("bug_chitin")):
						var sid := sm.get_instance_id()
						var dup_sm: ShaderMaterial = local_sm_map.get(sid)
						if dup_sm == null:
							dup_sm = sm.duplicate() as ShaderMaterial
							if sm.shader.resource_path.contains("mech_paint"):
								dup_sm.set_shader_parameter("occ_exempt", 1.0)
							local_sm_map[sid] = dup_sm
							_occ_shader_mats.append(dup_sm)
						mi.material_override = dup_sm
				elif use_mat_alpha:
					if mo is BaseMaterial3D:
						var bm := mo as BaseMaterial3D
						var dup_bm: BaseMaterial3D
						if is_giant:
							dup_bm = bm.duplicate() as BaseMaterial3D
						else:
							var bid := bm.get_instance_id()
							dup_bm = local_mob_map.get(bid)
							if dup_bm == null:
								dup_bm = bm.duplicate() as BaseMaterial3D
								local_mob_map[bid] = dup_bm
						mi.material_override = dup_bm
						_occ_mob_mats.append([mi, dup_bm, bm.albedo_color.a, bm.transparency, bm.emission_enabled, bm.emission_energy_multiplier])
					elif mo == null:
						for si in mi.mesh.get_surface_count():
							var smat: Material = mi.get_active_material(si)
							if smat is BaseMaterial3D:
								var bm2 := smat as BaseMaterial3D
								var dup_bm2: BaseMaterial3D
								if is_giant:
									dup_bm2 = bm2.duplicate() as BaseMaterial3D
								else:
									var bid2 := bm2.get_instance_id()
									dup_bm2 = local_mob_map.get(bid2)
									if dup_bm2 == null:
										dup_bm2 = bm2.duplicate() as BaseMaterial3D
										local_mob_map[bid2] = dup_bm2
								mi.set_surface_override_material(si, dup_bm2)
								_occ_mob_mats.append([mi, dup_bm2, bm2.albedo_color.a, bm2.transparency, bm2.emission_enabled, bm2.emission_energy_multiplier])
				elif mo is StandardMaterial3D and (mo as StandardMaterial3D).emission_enabled:
					var std := mo as StandardMaterial3D
					var eid := std.get_instance_id()
					var dup_em: StandardMaterial3D = local_em_map.get(eid)
					if dup_em == null:
						dup_em = std.duplicate() as StandardMaterial3D
						local_em_map[eid] = dup_em
						_occ_emit_mats.append([dup_em, std.emission_energy_multiplier])
					mi.material_override = dup_em
				_occ_meshes.append(mi)

	var has_ray := is_giant and clamped > 0.005 and cam_p != mech_c
	var sight_dir := (mech_c - cam_p).normalized() if has_ray else Vector3.ZERO
	var sight_len := cam_p.distance_to(mech_c) if has_ray else 1.0
	var base_tr := clamped * (0.90 if is_giant else 0.76)

	if use_mat_alpha:
		var applied := {}
		for rec in _occ_mob_mats:
			var mi: MeshInstance3D = rec[0]
			var bm: BaseMaterial3D = rec[1]
			if not is_instance_valid(mi) or not is_instance_valid(bm):
				continue
			var bmid := bm.get_instance_id()
			if not is_giant and applied.has(bmid):
				continue
			applied[bmid] = true
			var tr := base_tr
			if has_ray:
				var mp_w := mi.global_position
				var s_p := clampf((mp_w - cam_p).dot(sight_dir), 0.0, sight_len)
				var d_p := (cam_p + sight_dir * s_p).distance_to(mp_w)
				var k := 1.0 - smoothstep(4.5, 11.5, d_p)
				tr = clamped * lerpf(0.62, 0.91, k)
			var orig_a: float = float(rec[2])
			var orig_t: int = int(rec[3])
			var c := bm.albedo_color
			if tr <= 0.004:
				c.a = orig_a
				bm.albedo_color = c
				bm.transparency = orig_t as BaseMaterial3D.Transparency
				if bool(rec[4]):
					bm.emission_energy_multiplier = float(rec[5])
			else:
				c.a = orig_a * (1.0 - tr)
				bm.albedo_color = c
				bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				if bool(rec[4]):
					bm.emission_energy_multiplier = float(rec[5]) * pow(maxf(1.0 - tr, 0.0), 2.2)
	else:
		for mi in _occ_meshes:
			if not is_instance_valid(mi):
				continue
			var tr := base_tr
			if has_ray:
				var mp_w := (mi as MeshInstance3D).global_position
				var s_p := clampf((mp_w - cam_p).dot(sight_dir), 0.0, sight_len)
				var d_p := (cam_p + sight_dir * s_p).distance_to(mp_w)
				var k := 1.0 - smoothstep(4.5, 11.5, d_p)
				tr = clamped * lerpf(0.62, 0.91, k)
			(mi as MeshInstance3D).transparency = tr
		var em_scale := pow(maxf(1.0 - base_tr, 0.0), 2.2)
		for rec in _occ_emit_mats:
			var em_m: StandardMaterial3D = rec[0]
			if is_instance_valid(em_m):
				em_m.emission_energy_multiplier = float(rec[1]) * em_scale

	# 对自定义不透明 ShaderMaterial 补足一致的溶解穿透，避免与 StandardMaterial3D 脱节
	var sm_fade := clamped * (0.86 if is_giant else 0.74)
	for sm in _occ_shader_mats:
		if is_instance_valid(sm):
			sm.set_shader_parameter("occ_self_fade", sm_fade)


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
	parts.append(mi)
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
	var mob := A.is_mobile_perf()
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = A._bug_tex(tex)
	m.roughness = rough
	m.uv1_scale = Vector3(0.8, 0.8, 1.0)
	if mob:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		m.normal_enabled = true
		m.normal_texture = A._bug_tex("chitin_n.png" if tex.begins_with("chitin") else "leg_n.png")
		m.normal_scale = 1.3
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
	parts.append(A.add(p, A.sphere(r, -1, 10), A.emit(c, e), pos, Vector3.ZERO, Vector3(1, 0.75, 1), false))


# ---------------------------------------------------------------- v2 异形虫族（星际争霸 Zerg × 绝地潜兵 Terminid）
# 统一配色：暗褐黑亮面甲壳 → 骨白刃尖（顶点色渐变），甲片缝隙露出橙红发光肉质，橙色发光眼/囊。
# 造型语言：弯曲的镰刃、背脊长刺、分段拱形甲、反关节腿、前倾猎食姿态 —— 不是现实昆虫。
static var _sm := {}
const C_CH := Color(0.32, 0.34, 0.365)     # 重工暗枪灰轧制钢
const C_CH2 := Color(0.48, 0.50, 0.525)    # 机加工中灰钢甲
const C_BONE := Color(0.72, 0.71, 0.67)    # 锻造钨钢刃面
const C_FL := Color(0.14, 0.145, 0.16)     # 内部暗色骨架
const C_GLOW := Color(1.0, 0.38, 0.10)     # 工业高温炉芯琥珀橙红


static func _vmat() -> StandardMaterial3D:
	if _sm.has("v"):
		return _sm["v"]
	var mob := A.is_mobile_perf()
	var m := StandardMaterial3D.new()
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if mob else BaseMaterial3D.DIFFUSE_BURLEY
	m.albedo_color = Color(1.16, 1.16, 1.18)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.38
	m.metallic = 0.52
	m.metallic_specular = 0.72
	if not mob:
		m.rim_enabled = true
		m.rim = 0.24
		m.rim_tint = 0.65
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_panelize(m)
	_sm["v"] = m
	return m


static func _flesh(c := C_FL, glow := 0.12) -> StandardMaterial3D:
	# 内部机体：暗色金属骨架，透出能量辉光
	var key := "fl%s%.2f" % [c.to_html(), glow]
	if _sm.has(key):
		return _sm[key]
	var mob := A.is_mobile_perf()
	var m := StandardMaterial3D.new()
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if mob else BaseMaterial3D.DIFFUSE_BURLEY
	m.albedo_color = c
	m.metallic = 0.9
	m.roughness = 0.35
	if not mob:
		m.rim_enabled = true
		m.rim = 0.5
		m.rim_tint = 1.0
	m.emission_enabled = true
	m.emission = C_GLOW
	m.emission_energy_multiplier = glow
	_sm[key] = m
	return m


static func _glow(e := 2.5) -> StandardMaterial3D:
	return A.emit(C_GLOW, 0.0 if e <= 0.05 else (1.4 if e < 1.75 else 2.3))


static func _ball() -> SphereMesh:
	if _sm.has("ball"):
		return _sm["ball"]
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.rings = 14
	s.radial_segments = 28
	_sm["ball"] = s
	return s


## 静态零件合批：同材质的零件并成一个网格，动画部件所在的子树整段跳过
## 合批后的网格按「种类 + 第几次合批 + 第几个材质桶」缓存：同种虫的外形是确定的（零件随机数按固定种子），
## 第二只起直接复用合好的网格，省掉 SurfaceTool 逐只重新合并（开局铺 150 只虫时这是大头）
static var _merge_cache := {}
var _merge_n := 0


func _merged_mesh(tag: String, bi: int, list: Array, top: Node3D, tints: Array = [], modes: Array = []) -> Mesh:
	var key := "%s|%.3f|%s%d|%d|%d" % [kind, float(data.scale), tag, _merge_n, bi, list.size()]
	if _merge_cache.has(key):
		return _merge_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in list.size():
		var mi: MeshInstance3D = list[i]
		var tint: Color = tints[i] if i < tints.size() else Color.WHITE
		var tmode: int = modes[i] if i < modes.size() else 2
		var rxf := _rel_xf(mi, top)
		for si in mi.mesh.get_surface_count():
			st.append_from(RB._tinted_surface(mi.mesh, si, tint, tmode), 0, rxf)
	var m := st.commit()
	_merge_cache[key] = m
	return m


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
	for hip in legs:
		if is_instance_valid(hip) and hip is Node and hip.has_meta("knee"):
			var kn = hip.get_meta("knee")
			if is_instance_valid(kn) and kn is Node:
				roots.append(kn)
	for n in roots:
		skip[n.get_instance_id()] = true
	for c in visual.get_children():
		if c is Node3D and not (c is MeshInstance3D):
			_batch_container(c, skip)
	# 动画根节点及其下属静态子容器递归合批；遇到嵌套的其他动画根节点（skip）自动停下
	for n in roots:
		if is_instance_valid(n) and n is Node3D:
			_batch_container(n, skip)
	parts = parts.filter(func(p): return is_instance_valid(p))


func _batch_container(top: Node3D, skip: Dictionary) -> void:
	var buckets := {}
	var empty_dirs: Array = []
	var stack: Array = [top]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != top and skip.has(n.get_instance_id()):
			continue
		if n is MeshInstance3D and n != top:
			var mi: MeshInstance3D = n
			if mi.mesh != null and mi.material_override != null and is_instance_valid(mi):
				var mat: Material = mi.material_override
				var has_vc := mat.has_meta("_vc_tint")
				var base_mat: Material = mat.get_meta("_vc_base") if mat.has_meta("_vc_base") else mat
				var tint: Color = mat.get_meta("_vc_tint") if has_vc else Color.WHITE
				var key := str(base_mat.get_instance_id())
				if not buckets.has(key):
					buckets[key] = {"mat": base_mat, "list": [], "tints": [], "modes": []}
				buckets[key]["list"].append(mi)
				buckets[key]["tints"].append(tint)
				buckets[key]["modes"].append(2 if has_vc else 0)
			continue
		if n != top and n is Node3D and n.get_class() == "Node3D":
			empty_dirs.append(n)
		for ch in n.get_children():
			stack.append(ch)
	_merge_n += 1
	var bi := 0
	for key in buckets:
		var b: Dictionary = buckets[key]
		var list: Array = b["list"]
		bi += 1
		if list.size() < 2:
			if list.size() == 1:
				var s_mi: MeshInstance3D = list[0]
				if s_mi.get_parent() != top:
					var rxf := _rel_xf(s_mi, top)
					s_mi.get_parent().remove_child(s_mi)
					s_mi.transform = rxf
					top.add_child(s_mi)
			continue
		var merged := MeshInstance3D.new()
		merged.mesh = _merged_mesh("c", bi, list, top, b["tints"], b["modes"])
		merged.material_override = b["mat"]
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top.add_child(merged)
		parts.append(merged)
		for mi in list:
			if mi.get_parent():
				mi.get_parent().remove_child(mi)
			mi.free()
	for i in range(empty_dirs.size() - 1, -1, -1):
		var d: Node3D = empty_dirs[i]
		if is_instance_valid(d) and d.get_child_count() == 0:
			if d.get_parent():
				d.get_parent().remove_child(d)
			d.free()


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
func _sweep(parent: Node3D, pts: Array, radii: Array, c0: Color, c1: Color, rx := 1.0, ry := 1.0, up := Vector3.UP, steps := 8, rad := 18, m: Material = null, grad_start := 0.45, hard := false) -> MeshInstance3D:
	# 低面数红线：有机扫掠截面 ≥18（移动 ≥14），路径插值 ≥8（移动 ≥6）
	var _mob := A.is_mobile_perf()
	rad = maxi(rad, 14 if _mob else 18)
	steps = maxi(steps, 6 if _mob else 8)
	var key := "sw%s|%s|%s|%s|%.3f|%.3f|%s|%d|%d|%.3f|%d" % [str(pts), str(radii), c0.to_html(), c1.to_html(), rx, ry, str(up), steps, rad, grad_start, 1 if hard else 0]
	var smesh: ArrayMesh = _sm.get(key)
	if smesh == null:
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
		smesh = st.commit()
		_sm[key] = smesh
	var mi := MeshInstance3D.new()
	mi.mesh = smesh
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


## 机械足垫：踝伺服 + 液压缓冲柱 + 防滑齿切角抓地底板
func _foot_pad(hip: Node3D, foot: Vector3, w: float) -> void:
	_servo(hip, foot + Vector3(0, w * 0.82, 0), w * 0.76)
	_p(hip, A.cyl(w * 0.68, w * 0.92, w * 0.82, 8), _steel(), foot + Vector3(0, w * 0.34, 0))
	_p(hip, HS.cbox(Vector3(w * 2.7, w * 0.46, w * 3.1), w * 0.14), _vmat_solid(C_CH), foot + Vector3(0, -w * 0.2, 0))
	for kz: float in [-1.0, 1.0]:
		_box(hip, _steel(), foot + Vector3(0, -w * 0.36, kz * w * 1.18), Vector3(w * 2.3, w * 0.22, w * 0.42))


## 双级液压作动筒：深色外缸筒 + 黄铜油封压盖 + 高亮镀铬活塞杆 + 两端耳轴座
func _hydraulic(parent: Node3D, p0: Vector3, p1: Vector3, r: float, cyl_mat: Material = null) -> void:
	if p0.distance_to(p1) < 0.005:
		return
	var cm: Material = cyl_mat if cyl_mat else _vmat_matte(Color(0.32, 0.34, 0.29))
	var mid := p0.lerp(p1, 0.56)
	var gland0 := p0.lerp(p1, 0.50)
	var gland1 := p0.lerp(p1, 0.60)
	_seg(parent, p0, mid, r * 1.38, r * 1.38, cm, 8, false)
	_seg(parent, gland0, gland1, r * 1.56, r * 1.56, _brass(), 8, false)
	_seg(parent, p0.lerp(p1, 0.52), p1, r * 0.78, r * 0.78, _chrome(), 8, false)


## 机械连杆腿：髋 → 膝（外上）→ 跗（外下靠后）→ 液压足垫 + 双级液压作动筒
func _zleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, reach: float, by: float, w: float, phase: float, _spur := true) -> Node3D:
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0, yaw, 0)
	body.add_child(hip)
	var knee := Vector3(sx * reach * 0.42, by * 0.42, 0)
	var hock := Vector3(sx * reach * 0.78, -by * 0.35, w * 0.6)
	var tip := Vector3(sx * reach, -by + 0.01, -w * 0.8)
	var DKm := _vmat_solid(C_CH)
	var ARm := _vmat_solid(C_CH2)
	var foot := Vector3(tip.x, -by + w * 0.5, tip.z)
	_servo(hip, Vector3.ZERO, w * 1.28)
	_limb(hip, Vector3.ZERO, knee, w * 1.75, w * 1.95, DKm, 0.78, 1.16)
	_bar(hip, Vector3(0, w * 0.85, 0), knee + Vector3(0, w * 0.75, 0), w * 1.25, w * 0.42, ARm)
	_hydraulic(hip, Vector3(sx * w * 0.45, -w * 1.15, 0), knee.lerp(hock, 0.38) + Vector3(0, -w * 0.28, 0), w * 0.26)
	var kj := Node3D.new()
	kj.name = "Knee"
	kj.position = knee
	hip.add_child(kj)
	var hock_rel := hock - knee
	var foot_rel := foot - knee
	_servo(kj, Vector3.ZERO, w * 1.04)
	_limb(kj, Vector3.ZERO, hock_rel, w * 1.45, w * 1.65, ARm, 0.72, 1.12, Vector3.FORWARD)
	_servo(kj, hock_rel, w * 0.74)
	_limb(kj, hock_rel, foot_rel + Vector3(0, w * 0.8, 0), w * 1.05, w * 1.15, DKm, 0.86, 1.02, Vector3.FORWARD)
	_foot_pad(kj, foot_rel, w)
	hip.set_meta("knee", kj)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


## 已废弃：虫族不得有眼、嘴等仿生物部位（用户 2026-11-02）。保留空函数以兼容旧调用。
func _eyes(_head: Node3D, _z: float, _y: float, _xs: Array, _r: float) -> void:
	pass


## 重工轴承耳轴关节：铸钢外法兰座 + 机加工轴承鼓 + 黄铜油封环 + 六角锁紧端盖（无廉价霓虹光圈）
func _servo(parent: Node3D, pos: Vector3, r: float) -> void:
	_p(parent, A.cyl(r * 1.05, r * 0.92, r * 1.05, 12), _vmat_solid(Color(0.16, 0.17, 0.18)), pos, Vector3(0, 0, 90), Vector3.ONE, false)
	_p(parent, A.cyl(r * 0.84, r * 1.34, r * 0.84, 12), _steel(), pos, Vector3(0, 0, 90), Vector3.ONE, false)
	_p(parent, A.cyl(r * 0.92, r * 1.10, r * 0.92, 10), _brass(), pos, Vector3(0, 0, 90), Vector3.ONE, false)
	_p(parent, A.cyl(r * 0.42, r * 1.50, r * 0.42, 6), _vmat_matte(Color(0.22, 0.23, 0.25)), pos, Vector3(0, 0, 90), Vector3.ONE, false)


static func _steel() -> StandardMaterial3D:
	if _sm.has("steel"):
		return _sm["steel"]
	var m := StandardMaterial3D.new()
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.albedo_color = Color(0.58, 0.60, 0.63)
	m.metallic = 0.76
	m.metallic_specular = 0.82
	m.roughness = 0.28
	m.rim_enabled = true
	m.rim = 0.22
	m.rim_tint = 0.75
	m.set_meta("_vc_base", _vmat())
	m.set_meta("_vc_tint", m.albedo_color)
	_sm["steel"] = m
	return m


static func _chrome() -> StandardMaterial3D:
	if _sm.has("chrome"):
		return _sm["chrome"]
	var m := _vmat_solid(Color(0.78, 0.80, 0.82))
	_sm["chrome"] = m
	return m


static func _brass() -> StandardMaterial3D:
	if _sm.has("brass"):
		return _sm["brass"]
	var m := _vmat_solid(Color(0.68, 0.53, 0.26))
	_sm["brass"] = m
	return m


static func _rust_plate() -> StandardMaterial3D:
	if _sm.has("rust_pl"):
		return _sm["rust_pl"]
	var m := _vmat_matte(Color(0.44, 0.28, 0.20))
	_sm["rust_pl"] = m
	return m


static func _hazard_yel() -> StandardMaterial3D:
	if _sm.has("haz_y"):
		return _sm["haz_y"]
	var m := _vmat_matte(Color(0.82, 0.64, 0.14))
	_sm["haz_y"] = m
	return m


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var s: float = data.scale
	var sd := A.ground_vfx(visual, A.blob_tex(), Color(1, 1, 1, 0.75), 2.6 * s, Vector3(0, 0.03, 0), false, 0.34, false, 1)
	sd.set_meta("no_flash", true)
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


## 机械腿：髋伺服 → 方形股节（顶部装甲板）→ 膝伺服 → 切面胫节 + 双级液压油缸 + 抓地足垫
func _mleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, reach: float, by: float, w: float, phase: float, _spur := true) -> Node3D:
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
	_bar(hip, Vector3(0, w * 0.9, 0), knee + Vector3(0, w * 0.9, 0), w * 1.9, w * 0.52, AR)
	var ank := knee.lerp(foot, 0.55) + Vector3(sx * w * 0.8, 0, 0)
	var fp := Vector3(foot.x, -by + w * 0.5, foot.z)
	_hydraulic(hip, Vector3(0, -w * 0.95, 0), knee.lerp(ank, 0.48) + Vector3(-sx * w * 0.55, 0, 0), w * 0.24, DK)
	var kj := Node3D.new()
	kj.name = "Knee"
	kj.position = knee
	hip.add_child(kj)
	var ank_rel := ank - knee
	var fp_rel := fp - knee
	_servo(kj, Vector3.ZERO, w * 1.15)
	_limb(kj, Vector3.ZERO, ank_rel, w * 1.5, w * 1.7, DK, 0.75, 1.12, Vector3.FORWARD)
	_bar(kj, Vector3(sx * w * 0.55, 0, 0), ank_rel + Vector3(sx * w * 0.35, 0, 0), w * 0.42, w * 1.35, AR, Vector3.FORWARD)
	_limb(kj, ank_rel, fp_rel + Vector3(0, w * 0.8, 0), w * 1.05, w * 1.15, AR, 0.85, 1.0, Vector3.FORWARD)
	_foot_pad(kj, fp_rel, w)
	hip.set_meta("knee", kj)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


## 跳虫：铁血「Dinergate 衍生军工突击猎犬」。方核心舱外包一块 Γ 形浅灰轧制钢护壳（盖顶并包住一侧），
## 正面圆形螺栓装甲舱盖，左前上方遮光罩激光传感头；腹下两把液压折叠剪刃；尾部双矢量喷口跳跃推进器；
## 四条短粗切面冲压腿 + 侧置液压撑杆。
func _dleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, s: float, by: float, phase: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0, yaw, 0)
	body.add_child(hip)
	var DK := _vmat_solid(C_CH)
	var AR := _vmat_solid(C_CH2)
	var LT := _vmat_matte(Color(0.56, 0.58, 0.55))
	var knee := Vector3(sx * 0.21 * s, -0.07 * s, 0)
	var foot := Vector3(sx * 0.31 * s, -by + 0.01, 0)
	_servo(hip, Vector3.ZERO, 0.075 * s)
	_bar(hip, Vector3.ZERO, knee, 0.13 * s, 0.15 * s, AR)
	_hydraulic(hip, Vector3(sx * 0.04 * s, 0.06 * s, 0.055 * s), knee + Vector3(sx * 0.03 * s, -0.08 * s, 0.055 * s), 0.022 * s, DK)
	# 胫：上宽下窄的切面冲压钢柱 + 橡胶防滑靴底
	var sh := Node3D.new()
	sh.name = "Knee"
	sh.position = knee
	hip.add_child(sh)
	var L := knee.y - foot.y
	_prism(sh, [Vector2(-0.085 * s, 0), Vector2(0.085 * s, 0), Vector2(0.065 * s, -L + 0.06 * s), Vector2(0.02 * s, -L), Vector2(-0.055 * s, -L), Vector2(-0.065 * s, -L + 0.08 * s)],
		0.145 * s, 0.05, DK, Vector3.ZERO, Vector3(0, 90, 0))
	_box(sh, LT, Vector3(0, -L * 0.56, 0), Vector3(0.158, 0.07, 0.154) * s, Vector3(0, 0, sx * 6.0))
	_box(sh, _hazard_yel(), Vector3(sx * 0.076 * s, -L * 0.30, 0), Vector3(0.008, 0.09, 0.036) * s)
	_box(sh, _steel(), Vector3(0, -L + 0.022 * s, 0), Vector3(0.14, 0.042, 0.18) * s)
	hip.set_meta("knee", sh)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


func _build_ling(body: Node3D, s: float) -> void:
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var LT := _vmat_matte(Color(0.56, 0.58, 0.55))
	var OL := _vmat_matte(Color(0.30, 0.33, 0.26))
	var BL := _vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.52 * s
	# 核心舱：斜切铸钢方舱
	_prism(body, [Vector2(-0.24, -0.16) * s, Vector2(0.24, -0.16) * s, Vector2(0.27, -0.08) * s, Vector2(0.27, 0.16) * s, Vector2(-0.27, 0.16) * s, Vector2(-0.27, -0.08) * s],
		0.74 * s, 0.05, DK, Vector3(0, by, 0.02 * s))
	# Γ 形轧制装甲护壳：盖住顶面并包住右侧，左侧外露散热百叶与管线
	_prism(body, [Vector2(-0.3, 0.3) * s, Vector2(0.28, 0.3) * s, Vector2(0.36, 0.22) * s, Vector2(0.36, -0.16) * s, Vector2(0.28, -0.2) * s, Vector2(0.28, 0.18) * s, Vector2(-0.3, 0.18) * s],
		0.8 * s, 0.08, LT, Vector3(0, by, 0.06 * s))
	_panels(body, Vector3(0, by + 0.3 * s + 0.005, 0.06 * s), Vector3(-90, 0, 0), 0.6 * s, 0.76 * s, 11, 5)
	_panels(body, Vector3(0, by, -0.34 * s - 0.005), Vector3(0, 180, 0), 0.5 * s, 0.3 * s, 14, 4)
	_panels(body, Vector3(0, by + 0.06 * s, 0.445 * s), Vector3.ZERO, 0.5 * s, 0.26 * s, 15, 3)
	_panels(body, Vector3(0.36 * s + 0.005, by + 0.03 * s, 0.06 * s), Vector3(0, 90, 0), 0.74 * s, 0.34 * s, 12, 4)
	_panels(body, Vector3(-0.272 * s, by - 0.08 * s, 0.22 * s), Vector3(0, -90, 0), 0.26 * s, 0.12 * s, 13, 2)
	# 护壳前缘防跳弹凸边 + 顶部起吊耳 + 侧面防撞钢条与警示黄条
	_box(body, OL, Vector3(0.0, by + 0.27 * s, -0.36 * s), Vector3(0.62, 0.1, 0.06) * s, Vector3(20, 0, 0))
	_box(body, AR, Vector3(-0.05 * s, by + 0.33 * s, 0.22 * s), Vector3(0.4, 0.06, 0.3) * s)
	for zz: float in [-0.12, 0.30]:
		_box(body, _steel(), Vector3(0.18 * s, by + 0.33 * s, zz * s), Vector3(0.03, 0.065, 0.07) * s)
	_box(body, _steel(), Vector3(0.366 * s, by - 0.08 * s, 0.06 * s), Vector3(0.018, 0.038, 0.68) * s)
	_box(body, _hazard_yel(), Vector3(0.365 * s, by + 0.05 * s, -0.16 * s), Vector3(0.01, 0.032, 0.22) * s)
	_p(body, A.cyl(0.018 * s, 0.52 * s, 0.018 * s, 8), _brass(), Vector3(-0.282 * s, by - 0.02 * s, 0.06 * s), Vector3(90, 0, 0))
	for k in 4:
		_box(body, BL, Vector3(-0.273 * s, by + 0.07 * s, (-0.14 + k * 0.09) * s), Vector3(0.008, 0.12, 0.042) * s)
	# 正面圆形铸钢检修舱盖（非眼睛：实心法兰钢盖 + 一圈六角螺栓 + 横闩，无发光、无暗腔）
	var eye := Vector3(-0.02 * s, by + 0.0, -0.35 * s)
	_p(body, A.cyl(0.175 * s, 0.075 * s, 0.175 * s, 14), AR, eye, Vector3(90, 0, 0))
	_p(body, A.cyl(0.135 * s, 0.028 * s, 0.135 * s, 14), _steel(), eye + Vector3(0, 0, -0.042 * s), Vector3(90, 0, 0))
	_box(body, DK, eye + Vector3(0, 0, -0.058 * s), Vector3(0.20, 0.042, 0.022) * s)
	for bi in 6:
		var ba := float(bi) * TAU / 6.0
		_p(body, A.cyl(0.016 * s, 0.018 * s, 0.016 * s, 6), _brass(), eye + Vector3(cos(ba) * 0.15 * s, sin(ba) * 0.15 * s, -0.044 * s), Vector3(90, 0, 0))
	# 左前上方装甲激光测距传感盒（带遮光檐与细窄琥珀光缝）
	var head := Node3D.new()
	head.position = Vector3(-0.17 * s, by + 0.38 * s, -0.24 * s)
	body.add_child(head)
	_box(head, DK, Vector3(0, 0, 0.06 * s), Vector3(0.12, 0.09, 0.24) * s)
	_box(head, OL, Vector3(0, 0.01 * s, -0.08 * s), Vector3(0.14, 0.105, 0.08) * s)
	_box(head, _steel(), Vector3(0, 0.055 * s, -0.125 * s), Vector3(0.145, 0.016, 0.045) * s, Vector3(12, 0, 0))
	_box(head, BL, Vector3(0, -0.005 * s, -0.118 * s), Vector3(0.095, 0.036, 0.01) * s)
	_box(head, _glow(1.5), Vector3(0, -0.005 * s, -0.122 * s), Vector3(0.072, 0.016, 0.006) * s)
	# 腹下液压折叠工业剪刃（jaws：攻击时向内剪合）
	for sx: float in [-1.0, 1.0]:
		var jaw := Node3D.new()
		jaw.position = Vector3(sx * 0.17 * s, by - 0.15 * s, -0.26 * s)
		body.add_child(jaw)
		_servo(jaw, Vector3.ZERO, 0.055 * s)
		_box(jaw, AR, Vector3(0, -0.02 * s, -0.08 * s), Vector3(0.065, 0.075, 0.19) * s, Vector3(18, 0, 0))
		_hydraulic(jaw, Vector3(sx * 0.035 * s, 0.02 * s, -0.01 * s), Vector3(sx * 0.025 * s, -0.035 * s, -0.15 * s), 0.016 * s, DK)
		_prism(jaw, [Vector2(0, 0.025) * s, Vector2(0.32, 0.005) * s, Vector2(0.44, 0.075) * s, Vector2(0.30, -0.055) * s, Vector2(0, -0.065) * s],
			0.032 * s, 0.35, _steel(), Vector3(0, -0.06 * s, -0.16 * s), Vector3(0, 90, 0))
		_box(jaw, DK, Vector3(0, -0.042 * s, -0.25 * s), Vector3(0.042, 0.035, 0.22) * s)
		jaws.append(jaw)
	# 尾部跳跃推进器：双收敛喷管 + 隔热外罩 + 深黑喷膛
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx * 0.135 * s, by + 0.06 * s, 0.46 * s)
		_p(body, A.cyl(0.082 * s, 0.15 * s, 0.098 * s, 10), DK, n, Vector3(-80, 0, 0))
		_p(body, A.cyl(0.088 * s, 0.035 * s, 0.088 * s, 10), _steel(), n + Vector3(0, -0.006 * s, -0.035 * s), Vector3(-80, 0, 0))
		_p(body, A.cyl(0.062 * s, 0.016 * s, 0.062 * s, 10), BL, n + Vector3(0, 0.013 * s, 0.074 * s), Vector3(-80, 0, 0), Vector3.ONE, false)
	_box(body, DK, Vector3(0, by + 0.06 * s, 0.4 * s), Vector3(0.38, 0.17, 0.09) * s)
	sac = _box(body, _glow(1.1), Vector3(0, by + 0.06 * s, 0.448 * s), Vector3(0.08, 0.035, 0.012) * s)
	# 四条短粗腿：前腿前外、后腿后外
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			_dleg(body, Vector3(sx * 0.26 * s, by - 0.1 * s, (-0.2 + i * 0.42) * s), sx * (-20.0 + i * 40.0), sx, s, by - 0.1 * s,
				float(i % 2) * PI + (PI if sx > 0 else 0.0))


## 面板分割：在一个矩形面上（本地 +Z 朝外）用确定性随机切出 3~6 块凸起工业装甲子板，
## 多色调交替（铸铁深灰 / 轧制钢中灰 / 军工橄榄灰 / 铁锈检修板），缝隙露出底面形成分缝线，
## 并加六角螺栓、深黑散热百叶槽、工业黄警示条或黄铜铭牌，打碎大面积单一色块。
func _panels(parent: Node3D, center: Vector3, rot: Vector3, w: float, h: float, seed: int, n := 4, tones: Array = []) -> void:
	var f := Node3D.new()
	f.position = center
	f.rotation_degrees = rot
	parent.add_child(f)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if tones.is_empty():
		tones = [
			_vmat_solid(Color(0.15, 0.16, 0.175)),
			_vmat_matte(Color(0.30, 0.32, 0.34)),
			_vmat_matte(Color(0.46, 0.48, 0.49)),
			_vmat_matte(Color(0.28, 0.31, 0.25)),
			_vmat_solid(C_CH)
		]
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
		if r < 0.34:
			# 四角高强螺栓
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				_box(f, _steel(), Vector3(cc.x + q.x * (cw * 0.5 - g * 1.5), cc.y + q.y * (ch * 0.5 - g * 1.5), z + g * 0.3), Vector3(g * 1.05, g * 1.05, g * 0.6))
		elif r < 0.60:
			# 散热百叶槽
			var nv := clampi(int(cw / (g * 4.0)), 2, 6)
			for v in nv:
				_box(f, BL, Vector3(cc.x - cw * 0.35 + v * cw * 0.7 / maxf(nv - 1, 1), cc.y, z + 0.002), Vector3(g * 1.2, ch * 0.55, g * 0.35))
		elif r < 0.78:
			# 工程警示黄条
			_box(f, _hazard_yel(), Vector3(cc.x, cc.y - ch * 0.3, z + 0.002), Vector3(cw * 0.85, ch * 0.13, g * 0.32))
		elif r < 0.90:
			# 氧化检修铭牌 + 黄铜锁扣
			_box(f, _rust_plate(), Vector3(cc.x, cc.y + ch * 0.28, z + 0.002), Vector3(cw * 0.62, ch * 0.22, g * 0.32))
			_box(f, _brass(), Vector3(cc.x + cw * 0.22, cc.y + ch * 0.28, z + g * 0.35), Vector3(g * 1.3, g * 0.9, g * 0.45))


## 挤出棱柱：2D 多边形（XY 平面）沿 Z 挤出 depth，四周倒一圈斜角，用于盾形甲板、鳍片等异形硬表面
func _prism(parent: Node3D, pts: Array, depth: float, bev: float, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var key := "pr%s|%.4f|%.3f" % [str(pts), depth, bev]
	var pm: ArrayMesh = _sm.get(key)
	if pm == null:
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
		pm = st.commit()
		_sm[key] = pm
	var mi := _p(parent, pm, m, pos, rot)
	mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED if mi.material_override is BaseMaterial3D else 0
	return mi


## 蝎狮式高抬盾腿：髋 → 双梁股节 + 双级液压油缸 → 高抬膝枢纽 → 垂直胫柱 + 抓地足靴；
## 膝外侧挂载风筝形反应装甲防弹盾（4×2 叠鳞 ERA 模块 + 起吊环 + 工程警示条）。
func _tleg(body: Node3D, hip_pos: Vector3, yaw: float, sx: float, s: float, by: float, phase: float, ss := 1.0) -> Node3D:
	var hip := Node3D.new()
	hip.position = hip_pos
	hip.rotation_degrees = Vector3(0, yaw, 0)
	body.add_child(hip)
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var LT := _vmat_matte(Color(0.20, 0.21, 0.23))
	var LT2 := _vmat_matte(Color(0.46, 0.48, 0.50))
	var OL := _vmat_matte(Color(0.28, 0.31, 0.24))
	var knee := Vector3(sx * 0.9 * s, 0.8 * s * ss, 0)
	var foot := Vector3(sx * 1.38 * s, -by + 0.02, 0)
	var ank := foot + Vector3(0, 0.32 * s, 0)
	_servo(hip, Vector3.ZERO, 0.15 * s)
	_box(hip, DK, Vector3(sx * 0.05 * s, 0, 0), Vector3(0.22, 0.24, 0.3) * s)
	for zz: float in [-0.08, 0.08]:
		_bar(hip, Vector3(0, 0, zz * s), knee + Vector3(0, 0, zz * s), 0.1 * s, 0.15 * s, DK)
	_hydraulic(hip, Vector3(sx * 0.08 * s, -0.12 * s, 0), knee + Vector3(-sx * 0.14 * s, -0.1 * s, 0), 0.048 * s, AR)
	var kj := Node3D.new()
	kj.name = "Knee"
	kj.position = knee
	hip.add_child(kj)
	var ank_rel := ank - knee
	var foot_rel := foot - knee
	_servo(kj, Vector3.ZERO, 0.15 * s)
	_bar(kj, Vector3.ZERO, ank_rel, 0.14 * s, 0.16 * s, DK)
	_hydraulic(kj, Vector3(-sx * 0.1, -0.08, 0.1) * s, ank_rel + Vector3(-sx * 0.06, 0.06, 0.1) * s, 0.038 * s, AR)
	# 足：重型驻锄靴 + 防滑齿底板
	_box(kj, DK, ank_rel + Vector3(0, -0.06 * s, 0), Vector3(0.21, 0.26, 0.25) * s)
	_box(kj, AR, foot_rel + Vector3(0, 0.04 * s, 0), Vector3(0.28, 0.075, 0.38) * s)
	for cz: float in [-0.14, 0.0, 0.14]:
		_box(kj, _steel(), foot_rel + Vector3(0, 0.015 * s, cz * s), Vector3(0.29, 0.028, 0.045) * s)
	# 大盾：挂在膝外侧，盾面朝外（沿腿方向），顶部向内后仰
	var sh := Node3D.new()
	sh.position = Vector3(sx * 1.36 * s, (0.3 + 0.05 * ss) * s, 0) - knee
	sh.rotation_degrees = Vector3(0, 90.0 * sx, 0)
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(-12, 0, 0)
	tilt.scale = Vector3.ONE * ss
	sh.add_child(tilt)
	kj.add_child(sh)
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
	_box(tilt, _steel(), Vector3(0, 0.0, 0.105 * s), Vector3(0.055, 1.7, 0.024) * s)
	# 分鳞：四排人字形反应装甲块（轧制钢灰与军工橄榄灰交替 + 螺栓）
	for r in 4:
		var cy0 := 0.5 - r * 0.33
		var w: float = hw.call(cy0) * 0.42
		for kx: float in [-1.0, 1.0]:
			var cx: float = kx * (w + 0.035) * s
			var cy := cy0 * s
			_prism(tilt, [Vector2(-w, -0.12) * s, Vector2(w, -0.1) * s, Vector2(w + 0.03, 0.1) * s, Vector2(-w + 0.02, 0.12) * s], 0.14 * s, 0.1, LT2 if (r + int(kx > 0)) % 2 == 0 else OL,
				Vector3(cx, cy, 0.14 * s), Vector3(6, 0, -kx * 16.0))
			_box(tilt, _steel(), Vector3(cx + kx * (w * 0.65) * s, cy, 0.215 * s), Vector3(0.026, 0.026, 0.014) * s)
	for k in 3:
		_p(tilt, A.cyl(0.025 * s, 0.014 * s, 0.025 * s, 8), _brass(), Vector3((-0.09 + k * 0.09) * s, -0.72 * s, 0.108 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	_prism(tilt, [Vector2(0, 1.24) * s, Vector2(0.24, 0.92) * s, Vector2(0.3, 0.68) * s, Vector2(-0.3, 0.68) * s, Vector2(-0.24, 0.92) * s], 0.14 * s, 0.08, DK, Vector3(0, 0, 0.1 * s))
	_box(tilt, _hazard_yel(), Vector3(0, 0.78 * s, 0.175 * s), Vector3(0.36, 0.055, 0.012) * s)
	_box(tilt, _steel(), Vector3(0, 1.04 * s, 0.178 * s), Vector3(0.045, 0.14, 0.028) * s)
	# 盾背连接臂（与膝相连）
	_bar(kj, Vector3.ZERO, Vector3(sx * 1.28 * s, 0.45 * s, 0) - knee, 0.13 * s, 0.13 * s, AR)
	hip.set_meta("knee", kj)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


## 酸液/重炮虫：重工业「蝎狮 Manticore」四足盾装突击炮。
## 六边形斜切装甲船体 + 楔形测距头舱 + 右侧长身管驻退火炮（双液压复进机 + 穿孔散热套筒 + 多室开槽制退器）+
## 腹下捆扎钢制高压储液罐 + 背部百叶散热器总成 + 四条挂装 ERA 大盾的高抬机械足。
func _build_spitter(body: Node3D, s: float) -> void:
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var OL := _vmat_matte(Color(0.28, 0.31, 0.24))
	var by := 0.75 * s
	var GX := 0.36 * s
	var BL := _vmat_solid(Color(0.03, 0.03, 0.035))
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
		_p(body, A.cyl(0.016 * s, 0.58 * s, 0.016 * s, 8), _brass(), Vector3(sx * 0.368 * s, by + 0.37 * s, 0.1 * s), Vector3(84, 0, 0))
		_panels(body, Vector3(sx * 0.37 * s, by + 0.3 * s, 0.1 * s), Vector3(0, 90 * sx, 0), 0.7 * s, 0.32 * s, 31 + int(sx), 4)
		_box(body, BL, Vector3(sx * 0.364 * s, by + 0.21 * s, 0.2 * s), Vector3(0.008, 0.12, 0.22) * s)
		for k in 3:
			_box(body, _steel(), Vector3(sx * 0.366 * s, by + 0.11 * s, (0.05 + k * 0.12) * s), Vector3(0.012, 0.028, 0.028) * s)
	# 楔形火控头舱：前端叠层防盾 + 遮光罩光学测距窗 + 两侧排风百叶
	var head := Node3D.new()
	head.position = Vector3(GX * 0.6, by + 0.5 * s, -0.4 * s)
	head.scale = Vector3.ONE * 1.25
	head.rotation_degrees = Vector3(0, -10, 0)
	body.add_child(head)
	_prism(head, side.call([Vector2(0.75, 0.0), Vector2(0.45, 0.32), Vector2(-0.05, 0.42), Vector2(-0.15, 0.05), Vector2(0.35, -0.16)]), 0.4 * s, 0.06, DK, Vector3.ZERO, Vector3(0, 90, 0))
	_prism(head, side.call([Vector2(0.55, 0.3), Vector2(0.3, 0.46), Vector2(-0.12, 0.5), Vector2(-0.12, 0.38), Vector2(0.4, 0.3)]), 0.46 * s, 0.08, OL, Vector3.ZERO, Vector3(0, 90, 0))
	_prism(head, side.call([Vector2(0.3, 0.47), Vector2(0.12, 0.56), Vector2(-0.2, 0.58), Vector2(-0.2, 0.48)]), 0.3 * s, 0.1, AR, Vector3.ZERO, Vector3(0, 90, 0))
	# 正面内凹光学观瞄狭缝
	_box(head, BL, Vector3(0, 0.14 * s, -0.56 * s), Vector3(0.28, 0.055, 0.04) * s, Vector3(24, 0, 0))
	_box(head, _glow(1.4), Vector3(0, 0.14 * s, -0.575 * s), Vector3(0.22, 0.022, 0.01) * s, Vector3(24, 0, 0))
	for sx: float in [-1.0, 1.0]:
		for k in 4:
			_box(head, BL, Vector3(sx * 0.205 * s, 0.12 * s, (-0.05 - k * 0.07) * s), Vector3(0.01, 0.14, 0.03) * s)
		_box(head, _hazard_yel(), Vector3(sx * 0.236 * s, 0.33 * s, -0.18 * s), Vector3(0.01, 0.028, 0.28) * s, Vector3(-12, 0, 0))
	for j in 2:
		var jaw := Node3D.new()
		jaw.position = Vector3((j * 2 - 1) * 0.1 * s, -0.12 * s, -0.4 * s)
		head.add_child(jaw)
		jaws.append(jaw)
	# 腹下高压推进剂钢瓶（带钢箍与黄铜法兰盖，保留 sac 引用）
	sac = _p(body, A.cyl(0.17 * s, 0.56 * s, 0.17 * s, 12), _rust_plate(), Vector3(0, by - 0.11 * s, 0.22 * s), Vector3(90, 0, 0))
	for sz: float in [0.04, 0.22, 0.40]:
		_p(body, A.cyl(0.182 * s, 0.035 * s, 0.182 * s, 12), _steel(), Vector3(0, by - 0.11 * s, sz * s), Vector3(90, 0, 0))
	_p(body, A.cyl(0.12 * s, 0.04 * s, 0.12 * s, 10), _brass(), Vector3(0, by - 0.11 * s, 0.51 * s), Vector3(90, 0, 0))
	# 顶部长背甲脊梁 + 尾部重型散热器箱与双排烟短管
	var d0 := Vector3(GX * 0.7, by + 0.92 * s, -0.3 * s)
	var d1 := Vector3(-0.05 * s, by + 1.2 * s, 0.5 * s)
	_bar(body, d0, d1, 0.56 * s, 0.2 * s, AR)
	_bar(body, d0 + Vector3(0, 0.12 * s, 0.05 * s), d1 + Vector3(0, 0.12 * s, 0), 0.4 * s, 0.07 * s, DK)
	for sx: float in [-1.0, 1.0]:
		_bar(body, d0 + Vector3(sx * 0.3 * s, -0.08 * s, 0.05 * s), d1 + Vector3(sx * 0.3 * s, -0.1 * s, -0.05 * s), 0.05 * s, 0.22 * s, DK)
	_box(body, AR, Vector3(-0.08 * s, by + 1.28 * s, 0.6 * s), Vector3(0.36, 0.28, 0.40) * s)
	for k in 5:
		_box(body, BL, Vector3((-0.20 + k * 0.06) * s, by + 1.28 * s, 0.802 * s), Vector3(0.032, 0.20, 0.012) * s)
		_box(body, _steel(), Vector3((-0.20 + k * 0.06) * s, by + 1.45 * s, 0.6 * s), Vector3(0.026, 0.09, 0.34) * s)
	for sx: float in [-1.0, 1.0]:
		var ex := Vector3((-0.08 + sx * 0.11) * s, by + 1.48 * s, 0.76 * s)
		_p(body, A.cyl(0.042 * s, 0.18 * s, 0.048 * s, 10), DK, ex, Vector3(-32, 0, 0))
		_p(body, A.cyl(0.034 * s, 0.015 * s, 0.034 * s, 10), BL, ex + Vector3(0, 0.078 * s, 0.048 * s), Vector3(-32, 0, 0), Vector3.ONE, false)
	_box(body, DK, Vector3(-0.12 * s, by + 0.66 * s, 0.45 * s), Vector3(0.14, 0.18, 0.24) * s)
	# 主炮：长身管高初速火炮（铸钢炮尾机匣 + 上置驻退复进筒 + 穿孔散热护套 + 多室开槽制退器 + 深黑膛口）
	var GM := _vmat_solid(Color(0.19, 0.20, 0.22))
	gun = Node3D.new()
	gun.name = "Gun"
	body.add_child(gun)
	var g0 := Vector3(GX, by - 0.02 * s, -0.4 * s)
	_prism(gun, side.call([Vector2(0.7, -0.12), Vector2(0.7, 0.1), Vector2(0.45, 0.16), Vector2(-0.55, 0.16), Vector2(-0.6, -0.12), Vector2(-0.3, -0.2), Vector2(0.4, -0.2)]),
		0.32 * s, 0.06, AR, g0, Vector3(0, 90, 0))
	_box(gun, DK, g0 + Vector3(0, 0.2 * s, 0.0), Vector3(0.18, 0.065, 1.12) * s)
	_box(gun, OL, g0 + Vector3(0, -0.26 * s, 0.2 * s), Vector3(0.24, 0.15, 0.48) * s)
	_box(gun, _hazard_yel(), g0 + Vector3(0.162 * s, -0.24 * s, 0.2 * s), Vector3(0.008, 0.045, 0.36) * s)
	for k in 6:
		_box(gun, BL, g0 + Vector3(0.162 * s, 0.0, (-0.45 + k * 0.1) * s), Vector3(0.008, 0.1, 0.042) * s)
	var b0 := g0 + Vector3(0, 0.0, -0.7 * s)
	var b1 := b0 + Vector3(0, 0, -2.0 * s)
	# 炮盾护套 + 上下驻退液压筒
	_box(gun, DK, b0 + Vector3(0, 0, -0.3 * s), Vector3(0.25, 0.23, 0.62) * s)
	_p(gun, A.cyl(0.046 * s, 0.72 * s, 0.046 * s, 10), _chrome(), b0 + Vector3(0, 0.155 * s, -0.36 * s), Vector3(90, 0, 0))
	_p(gun, A.cyl(0.056 * s, 0.18 * s, 0.056 * s, 10), _brass(), b0 + Vector3(0, 0.155 * s, -0.08 * s), Vector3(90, 0, 0))
	for k in 4:
		_box(gun, AR, b0 + Vector3(0, 0, (-0.06 - k * 0.17) * s), Vector3(0.29, 0.27, 0.06) * s)
	_p(gun, A.cyl(0.082 * s, 2.0 * s, 0.082 * s, 14), GM, (b0 + b1) * 0.5, Vector3(90, 0, 0))
	_p(gun, A.cyl(0.115 * s, 0.64 * s, 0.115 * s, 12), DK, b0 + Vector3(0, 0, -1.0 * s), Vector3(90, 0, 0))
	for k in 5:
		_p(gun, A.cyl(0.122 * s, 0.03 * s, 0.122 * s, 12), _steel(), b0 + Vector3(0, 0, (-0.75 - k * 0.12) * s), Vector3(90, 0, 0))
	for k in 3:
		_p(gun, A.cyl(0.102 * s, 0.038 * s, 0.102 * s, 12), _steel(), b0 + Vector3(0, 0, (-1.45 - k * 0.18) * s), Vector3(90, 0, 0))
	var mz := b1 + Vector3(0, 0, 0.1 * s)
	_box(gun, DK, mz, Vector3(0.26, 0.21, 0.34) * s)
	_box(gun, _steel(), mz + Vector3(0, 0, -0.14 * s), Vector3(0.27, 0.22, 0.05) * s)
	for k in 2:
		for sx: float in [-1.0, 1.0]:
			_box(gun, BL, mz + Vector3(sx * 0.132 * s, 0, (-0.06 + k * 0.12) * s), Vector3(0.01, 0.13, 0.055) * s)
	_p(gun, A.cyl(0.072 * s, 0.02 * s, 0.072 * s, 12), BL, mz + Vector3(0, 0, -0.172 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	gun_tip = Node3D.new()
	gun_tip.position = mz + Vector3(0, 0, -0.32 * s)
	gun.add_child(gun_tip)
	gun_glow = _p(gun, A.cyl(0.055 * s, 0.02 * s, 0.055 * s, 10), _glow(0.0), mz + Vector3(0, 0, -0.176 * s), Vector3(90, 0, 0), Vector3.ONE, false)
	# 四条高抬蛛腿：前腿向前外伸、后腿向后外伸
	var hp := [Vector3(0.28, 0.05, -0.1), Vector3(0.28, 0.0, 0.32)]
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			var h: Vector3 = hp[i]
			_tleg(body, Vector3(sx * h.x * s, by + h.y * s, h.z * s), sx * (35.0 - i * 85.0), sx, s, by + h.y * s, float(i % 2) * PI + (PI if sx > 0 else 0.0), 1.0 - i * 0.12)


## 攻城虫：重工业矿山/破障机。低宽六边形铆接底盘，正面五层重型推土破城楔（高碳钢刃口 + 缓冲梁 + 工程黄黑警示条），
## 冲角顶端嵌铸钢潜望观瞄塔；两侧双液压岩石破碎钳；后部柴油涡轮动力塔（百叶散热罩 + 炉芯视窗 + 双防烫网排烟管）；
## 六条重型液压活塞支腿 + 宽扁防滑足垫。
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
	_bar(hip, Vector3(0, 0.13 * s, 0), knee + Vector3(0, 0.13 * s, 0), 0.26 * s, 0.055 * s, AR)
	_hydraulic(hip, Vector3(sx * 0.06 * s, -0.11 * s, 0), knee + Vector3(-sx * 0.08 * s, -0.06 * s, 0), 0.042 * s, DK)
	var kj := Node3D.new()
	kj.name = "Knee"
	kj.position = knee
	hip.add_child(kj)
	_servo(kj, Vector3.ZERO, 0.13 * s)
	# 活塞胫：重型方形油缸外筒 + 黄铜密封法兰 + 镀铬活塞杆 + 六角驻锄足垫
	var mid := Vector3(foot.x, knee.y - 0.32 * s, 0)
	var mid_rel := mid - knee
	var foot_rel := foot - knee
	_bar(kj, Vector3.ZERO, mid_rel, 0.21 * s, 0.21 * s, AR, Vector3.FORWARD)
	_box(kj, _hazard_yel(), mid_rel + Vector3(sx * 0.106 * s, 0.12 * s, 0), Vector3(0.008, 0.14, 0.055) * s)
	_p(kj, A.cyl(0.088 * s, 0.045 * s, 0.088 * s, 10), _brass(), mid_rel + Vector3(0, -0.01 * s, 0))
	_p(kj, A.cyl(0.064 * s, mid.y - foot.y, 0.064 * s, 10), _chrome(), Vector3(foot_rel.x, (mid_rel.y + foot_rel.y) * 0.5, 0))
	_foot_pad(kj, foot_rel + Vector3(0, 0.06 * s, 0), 0.13 * s)
	hip.set_meta("knee", kj)
	hip.set_meta("side", sx)
	hip.set_meta("phase", phase)
	hip.set_meta("base_y", hip.rotation.y)
	legs.append(hip)
	return hip


func _build_brute(body: Node3D, s: float) -> void:
	var AR := _vmat_solid(C_CH2)
	var DK := _vmat_solid(C_CH)
	var LT := _vmat_matte(Color(0.46, 0.48, 0.50))
	var OL := _vmat_matte(Color(0.29, 0.31, 0.24))
	var BL := _vmat_solid(Color(0.03, 0.03, 0.035))
	var by := 0.62 * s
	# 六边形重型铸钢底盘 + 上层甲板
	_prism(body, [Vector2(-0.5, -0.6) * s, Vector2(0.5, -0.6) * s, Vector2(0.66, 0.0) * s, Vector2(0.52, 0.72) * s, Vector2(-0.52, 0.72) * s, Vector2(-0.66, 0.0) * s],
		0.34 * s, 0.06, DK, Vector3(0, by, 0), Vector3(90, 0, 0))
	_prism(body, [Vector2(-0.38, -0.4) * s, Vector2(0.38, -0.4) * s, Vector2(0.48, 0.05) * s, Vector2(0.4, 0.62) * s, Vector2(-0.4, 0.62) * s, Vector2(-0.48, 0.05) * s],
		0.16 * s, 0.08, OL, Vector3(0, by + 0.24 * s, 0), Vector3(90, 0, 0))
	_panels(body, Vector3(0, by + 0.32 * s + 0.005, 0.05 * s), Vector3(-90, 0, 0), 0.62 * s, 0.7 * s, 21, 6)
	for sx: float in [-1.0, 1.0]:
		_panels(body, Vector3(sx * 0.6 * s, by, 0.36 * s), Vector3(0, 90 * sx, 0), 0.5 * s, 0.26 * s, 22 + int(sx), 3)
		_box(body, _steel(), Vector3(sx * 0.665 * s, by + 0.02 * s, 0.0), Vector3(0.022, 0.055, 0.56) * s)
		_box(body, _hazard_yel(), Vector3(sx * 0.668 * s, by + 0.02 * s, -0.14 * s), Vector3(0.024, 0.042, 0.18) * s)
		for k in 4:
			_box(body, _brass(), Vector3(sx * 0.61 * s, by - 0.1 * s, (-0.15 + k * 0.12) * s), Vector3(0.014, 0.03, 0.03) * s)
	# 破城冲角：五层人字形重型推土铲板 + 高强钢铲刃 + 工程警示条 + 后置液压顶杆
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
			_prism(ram, [Vector2(-w * 0.82, 0.088) * s, Vector2(0, -0.062) * s, Vector2(w * 0.82, 0.088) * s, Vector2(w * 0.82, 0.105) * s, Vector2(0, -0.045) * s, Vector2(-w * 0.82, 0.105) * s],
				0.035 * s, 0.0, BL, Vector3(0, y * s, -0.085 * s))
		for sx: float in [-1.0, 1.0]:
			var edge_m: Material = _hazard_yel() if r == 0 else (_steel() if r == 1 else DK)
			_box(ram, edge_m, Vector3(sx * w * 0.52 * s, (y - 0.06) * s, -0.114 * s), Vector3(w * 0.56, 0.052, 0.016) * s, Vector3(0, 0, sx * 11.0))
			_box(ram, _steel(), Vector3(sx * w * 0.88 * s, (y + 0.01) * s, -0.118 * s), Vector3(0.034, 0.034, 0.016) * s)
			_box(ram, BL, Vector3(sx * w * 0.5 * s, (y - 0.03) * s, -0.118 * s), Vector3(0.05, 0.035, 0.012) * s, Vector3(0, 0, sx * 14.0))
	for sx: float in [-1.0, 1.0]:
		_hydraulic(body, Vector3(sx * 0.34 * s, by + 0.12 * s, -0.36 * s), Vector3(sx * 0.38 * s, by - 0.02 * s, -0.72 * s), 0.042 * s, DK)
	_panels(body, Vector3(0, by - 0.05 * s, -0.6 * s - 0.005), Vector3(0, 180, 0), 0.9 * s, 0.2 * s, 27, 3)
	_box(ram, _steel(), Vector3(0, 0.36 * s, -0.125 * s), Vector3(0.09, 0.82, 0.035) * s)
	# 冲角顶部铸钢潜望观瞄塔（防弹遮檐 + 三联内凹光学窄窗）
	var head := Node3D.new()
	head.position = Vector3(0, by + 0.42 * s, -0.42 * s)
	body.add_child(head)
	_prism(head, [Vector2(-0.22, 0) * s, Vector2(0.22, 0) * s, Vector2(0.17, 0.14) * s, Vector2(-0.17, 0.14) * s], 0.32 * s, 0.08, DK, Vector3.ZERO)
	_box(head, _steel(), Vector3(0, 0.135 * s, -0.14 * s), Vector3(0.36, 0.025, 0.09) * s, Vector3(10, 0, 0))
	for vx: float in [-0.10, 0.0, 0.10]:
		_box(head, BL, Vector3(vx * s, 0.075 * s, -0.158 * s), Vector3(0.075, 0.042, 0.018) * s)
		_box(head, _glow(1.5), Vector3(vx * s, 0.075 * s, -0.165 * s), Vector3(0.058, 0.018, 0.008) * s)
	# 两侧重型液压破碎钳
	for sx: float in [-1.0, 1.0]:
		var sc := Node3D.new()
		sc.position = Vector3(sx * 0.58 * s, by + 0.08 * s, -0.42 * s)
		body.add_child(sc)
		_servo(sc, Vector3.ZERO, 0.15 * s)
		var el := Vector3(sx * 0.2, -0.05, -0.38) * s
		_bar(sc, Vector3.ZERO, el, 0.17 * s, 0.2 * s, AR)
		_hydraulic(sc, Vector3(0, 0.13 * s, 0.05 * s), el + Vector3(0, 0.11 * s, 0.02 * s), 0.038 * s, DK)
		_servo(sc, el, 0.115 * s)
		var wr := el + Vector3(-sx * 0.06, -0.12, -0.32) * s
		_bar(sc, el, wr, 0.15 * s, 0.17 * s, DK)
		_box(sc, LT, wr + Vector3(0, 0.0, 0.08 * s), Vector3(0.24, 0.21, 0.14) * s)
		_p(sc, A.cyl(0.045 * s, 0.23 * s, 0.045 * s, 8), _brass(), wr + Vector3(0, 0, 0.04 * s))
		for j: float in [-1.0, 1.0]:
			_prism(sc, [Vector2(0, -0.065) * s, Vector2(0.21, -0.035) * s, Vector2(0.29, 0.05) * s, Vector2(0.18, 0.035) * s, Vector2(0, 0.065) * s],
				0.075 * s, 0.18, _steel(), wr + Vector3(j * 0.065 * s, 0, 0), Vector3(0, 90, j * 18.0))
		scythes.append(sc)
	# 后部柴油动力塔：竖向散热百叶鳍 + 防爆笼内炉芯视窗（保留 sac 引用）+ 双穿孔防烫网排烟管
	var rc := Vector3(0, by + 0.42 * s, 0.4 * s)
	_prism(body, [Vector2(-0.32, -0.16) * s, Vector2(0.32, -0.16) * s, Vector2(0.25, 0.35) * s, Vector2(-0.25, 0.35) * s], 0.42 * s, 0.06, DK, rc)
	_panels(body, rc + Vector3(0, 0.09 * s, -0.215 * s), Vector3(0, 180, 0), 0.52 * s, 0.44 * s, 25, 4)
	for sx: float in [-1.0, 1.0]:
		_panels(body, rc + Vector3(sx * 0.29 * s, 0.09 * s, 0), Vector3(0, 90 * sx, 6 * sx), 0.36 * s, 0.4 * s, 26 + int(sx), 3)
	for k in 5:
		_box(body, AR, rc + Vector3((-0.2 + k * 0.1) * s, 0.1 * s, 0.225 * s), Vector3(0.032, 0.4, 0.085) * s)
	sac = _p(body, A.cyl(0.095 * s, 0.30 * s, 0.095 * s, 10), _flesh(Color(0.86, 0.34, 0.08), 0.8), rc + Vector3(0, 0.08 * s, -0.13 * s))
	for ci in 4:
		var ca := float(ci) * TAU / 4.0 + PI * 0.25
		_box(body, _steel(), rc + Vector3(cos(ca) * 0.105 * s, 0.08 * s, -0.13 * s + sin(ca) * 0.105 * s), Vector3(0.018, 0.31, 0.018) * s)
	_p(body, A.cyl(0.13 * s, 0.045 * s, 0.13 * s, 10), _brass(), rc + Vector3(0, 0.25 * s, -0.13 * s))
	for sx: float in [-1.0, 1.0]:
		var e0 := rc + Vector3(sx * 0.21 * s, 0.25 * s, 0.05 * s)
		_p(body, A.cyl(0.052 * s, 0.44 * s, 0.058 * s, 10), DK, e0 + Vector3(0, 0.16 * s, 0.065 * s), Vector3(18, 0, 0))
		_p(body, A.cyl(0.068 * s, 0.26 * s, 0.068 * s, 10), _rust_plate(), e0 + Vector3(0, 0.11 * s, 0.045 * s), Vector3(18, 0, 0))
		_p(body, A.cyl(0.042 * s, 0.018 * s, 0.042 * s, 10), BL, e0 + Vector3(0, 0.372 * s, 0.132 * s), Vector3(18, 0, 0), Vector3.ONE, false)
	# 六条活塞腿（三角步态）
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			_pleg(body, Vector3(sx * 0.55 * s, by - 0.08 * s, (-0.35 + i * 0.42) * s), sx * (-25.0 + i * 25.0), sx, s, by - 0.08 * s,
				float(i % 2) * PI + (PI if sx > 0 else 0.0))


static func _vmat_matte_vc() -> StandardMaterial3D:
	if _sm.has("vm_vc"):
		return _sm["vm_vc"]
	var mob := A.is_mobile_perf()
	var m := StandardMaterial3D.new()
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if mob else BaseMaterial3D.DIFFUSE_BURLEY
	m.albedo_color = Color(1.14, 1.14, 1.16)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.52
	m.metallic = 0.40
	m.metallic_specular = 0.58
	if not mob:
		m.rim_enabled = true
		m.rim = 0.18
		m.rim_tint = 0.48
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_panelize(m)
	_sm["vm_vc"] = m
	return m


static func _vmat_matte(c: Color) -> StandardMaterial3D:
	var key := "vm%s" % c.to_html()
	if _sm.has(key):
		return _sm[key]
	var mob := A.is_mobile_perf()
	var m := StandardMaterial3D.new()
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if mob else BaseMaterial3D.DIFFUSE_BURLEY
	m.albedo_color = c
	m.roughness = 0.56
	m.metallic = 0.42
	m.metallic_specular = 0.55
	if not mob:
		m.rim_enabled = true
		m.rim = 0.14
		m.rim_tint = 0.45
	_panelize(m)
	m.set_meta("_vc_base", _vmat_matte_vc())
	m.set_meta("_vc_tint", c)
	_sm[key] = m
	return m


static func _vmat_solid(c: Color) -> StandardMaterial3D:
	var key := "vs%s" % c.to_html()
	if _sm.has(key):
		return _sm[key]
	var mob := A.is_mobile_perf()
	var m := StandardMaterial3D.new()
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if mob else BaseMaterial3D.DIFFUSE_BURLEY
	m.albedo_color = c
	m.roughness = 0.38
	m.metallic = 0.62
	m.metallic_specular = 0.72
	if not mob:
		m.rim_enabled = true
		m.rim = 0.18
		m.rim_tint = 0.55
	_panelize(m)
	m.set_meta("_vc_base", _vmat())
	m.set_meta("_vc_tint", c)
	_sm[key] = m
	return m


## 被噪音惊动（机甲开火、空投落地）：视距内转入追击，视距外只朝声源处搜寻查看（禁止视距外直接锁定先手）
func alert(pos: Vector3) -> void:
	_wake()
	if state == "idle":
		if raid and _alive(raid.mech):
			var d_mech := global_position.distance_to(raid.mech.global_position)
			var max_v: float = raid.vision_toward_player(global_position) if raid.has_method("vision_toward_player") else _lose_dist()
			# 机甲在当前视距外（远处的空投、枪声或诱饵信标）：不直接锁定机甲，只去声源处查看
			if d_mech > max_v:
				target = null
				_set_investigate(pos)
				return
			target = raid.mech
		state = "chase"
		# 听到动静：朝声源方向搜过去，多给几秒「看不见也继续找」的宽限，找不到就去声源处查看
		last_seen = pos
		_unseen_t = -NOISE_GRACE
		_alert_pack(target)


## 当前敌人是否处于玩家的默认视距内（防止视距外敌人对玩家进行超视距先手打击）
func _in_player_view(d: float) -> bool:
	if raid != null and target == raid.mech and raid.has_method("vision_toward_player"):
		return d <= raid.vision_toward_player(global_position)
	return true


# ================= 感知 / 巡逻 / LOD =================
## 虫群：一群里第一只是群首，其余成员跟在群首身后的固定站位上；群首在领地（home 周围 territory 米）里挑路点巡逻。
## 视野：目标（机甲、战斗队友、流浪者）在察觉距离内、且胸口高度的视线没被静态地形挡住，才算「看见」→ 整群转入追击。
##   察觉距离 = raid.scaled_aggro(数据表 aggro)，封顶 raid.vision_range()（玩家视野 × 0.9）；看玩家机甲时再按屏幕方向收紧。
## 受击锁定：被谁打就锁定谁（玩家子弹记为机甲），无视视野一路追，直到拉开到 raid.lose_range()（视野 × 1.5）才丢失；同群被叫醒的成员同样锁定。
## 没锁定的追击：发现之后只要视线不断、没拉开到 lose_range 就一直跟；视线断开超过 UNSEEN_GIVEUP 秒或拉开到 lose_range → 丢失。丢失后先去最后看见目标的位置查看几秒，再回到巡逻。
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
	return is_instance_valid(n) and n.get("dead") != true and n.get("dying") != true and n.get("net_done") != true


## 远处（LOD 2）的虫每 0.5 秒才真正模拟一次，其余物理帧只是进来累加时间、马上返回；150 只虫里这类空转占了虫群 AI 的大头。
## 改成：LOD 2 走完一步就关掉物理回调“睡”到下一步前夕（引擎计时器叫醒），醒来时把睡过的物理帧补进累计时间，
## 之后与原来逐帧累加完全一样地判断 LOD 与步长。被外部改成追击 / 受击 / 听到动静时立即叫醒，反应时机不变
const SLEEP_FAR := true
const SLEEP_TICKS := 31
var _sleeping := false
var _sleep_frame := 0
var _sleep_staggered := false


func _can_sleep() -> bool:
	return not bool(data.get("boss", false)) and not dying


func _sleep() -> void:
	if _sleeping or not _can_sleep() or not is_inside_tree():
		return
	_sleeping = true
	_sleep_frame = Engine.get_physics_frames()
	set_physics_process(false)
	var pd := get_physics_process_delta_time()
	# 首次休眠把同帧生成的 150+ 远距虫均匀错峰到 ~28 个物理帧，杜绝集体惊群尖刺；此后按 >=0.5s 节拍一次醒来即执行，避免提前空转多帧
	var ticks: int
	if not _sleep_staggered:
		_sleep_staggered = true
		ticks = SLEEP_TICKS + randi_range(0, 26)
	else:
		ticks = SLEEP_TICKS + randi_range(0, 4)
	get_tree().create_timer(pd * ticks, false, true).timeout.connect(_wake)


## 叫醒：恢复物理回调，睡过的物理帧（不含醒来这一帧，它会照常传 delta 进来）补进 LOD 累计时间
func _wake() -> void:
	if not _sleeping:
		return
	_sleeping = false
	if dying or hp <= 0.0 or not is_instance_valid(self) or not is_inside_tree():
		return
	var missed := maxi(0, Engine.get_physics_frames() - _sleep_frame - 1)
	var slept := missed * get_physics_process_delta_time()
	_lod_acc += slept
	_on_wake(slept)
	set_physics_process(true)


## 子类在睡眠期间不随 LOD 走的逐帧计时（如 enemy 的 guard_t）在这里补扣
func _on_wake(_slept: float) -> void:
	pass


## 本帧要模拟的时间：近处返回 delta；中远处累计到节拍才返回累计值，其余帧返回 0（跳过）
func _lod_dt(delta: float) -> float:
	var busy: bool = act != "" or spawn_t > 0.0 or flash_t > 0.0
	var d2 := 0.0
	if raid and is_instance_valid(raid.mech):
		d2 = global_position.distance_squared_to(raid.mech.global_position)
		if "cam_focus" in raid and raid.cam_focus != Vector3.ZERO:
			d2 = minf(d2, global_position.distance_squared_to(raid.cam_focus))
	if busy or d2 < LOD_NEAR * LOD_NEAR:
		lod = 0
	elif d2 < LOD_MID * LOD_MID or state == "chase":
		lod = 1
	else:
		lod = 2
	var want_detail := lod == 0 or raid == null or bool(data.get("boss", false))
	if vis_anchor != null and vis_anchor.visible != want_detail:
		vis_anchor.visible = want_detail
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
	if lod == 2 and SLEEP_FAR:
		_sleep()
	return dt


## 一次 move_and_slide 走完 dt：低频更新时按比例放大速度，碰撞照常结算。
## 画面外（LOD 中 / 远）闲逛巡逻的虫不跑物理：直接平移，只用建筑占地格子挡一下（撞上就换路点），省掉绝大部分 move_and_slide
func _slide(dt: float) -> void:
	_slide_impl(dt)
	_vis_sync()


func _slide_impl(dt: float) -> void:
	# 保险：被挤穿地面（重叠的碰撞体解穿透时往下推）就拉回地表，不让虫子在地下一直掉
	if global_position.y < -4.0:
		global_position.y = 0.5
		velocity.y = 0.0
	if lod > 0 and state == "idle" and act == "" and raid and raid.has_method("ai_free"):
		var step := Vector3(velocity.x, 0.0, velocity.z) * dt
		if step.length_squared() < 0.0001:
			return
		var np := global_position + step
		var in_b: bool = raid.in_bounds(np, 4.0) if raid.has_method("in_bounds") else (absf(np.x) < raid.HALF - 4.0 and absf(np.z) < raid.HALF - 4.0)
		if raid.ai_free(np, float(data.radius)) and in_b:
			global_position = np
			return
		# 自己已经压在不可走格子里（网格带通行间隙，比实际碰撞体略大）：走真实物理挤出去，否则会永远卡在原地
		if raid.ai_free(global_position, float(data.radius)):
			wander_to = Vector3.ZERO
			return
	var _pt := Prof.t0()
	_slide_phys(dt)
	Prof.add("bug.move_and_slide", _pt)


func _slide_phys(dt: float) -> void:
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
	var _pt := Prof.t0()
	_perceive_impl()
	Prof.add("bug.perceive", _pt)


func _perceive_impl() -> void:
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
				# 已经交上手的目标：只要在丢失距离内、视线没断就一直盯着（察觉要进视野，跟踪放宽到 1.5 倍）
				target_los = raid.has_los(p, best.global_position) if raid.has_method("has_los") else true
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
	# 体型大的虫（半径 > 1 米）走机甲那张间隙更宽的网格，免得被引进挤不过去的窄缝（代价：也会绕开只挡机甲的河岸）
	var _pt := Prof.t0()
	var v: Vector3 = nav_agent.steer(raid.nav, global_position, goal, delta, float(data.radius) > 1.0, _nav_period())
	Prof.add("bug.nav", _pt)
	return v


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
	if raid != null and raid.coop != null and Net.is_client(): return
	var _pt := Prof.t0()
	var local_mech = raid.mech if raid != null else null
	if raid != null and raid.coop != null: raid.mech = raid.nearest_player(global_position)
	_physics_tick(delta)
	if raid != null: raid.mech = local_mech
	Prof.add("phys.bugs", _pt)
	if Prof.on:
		Prof.add("bugs.lod%d.%s" % [lod, "chase" if state == "chase" else "idle"], _pt)


func _physics_tick(delta: float) -> void:
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
		flash_t = maxf(0.0, flash_t - delta)
		_update_flash()
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
				# 隔着墙或还在玩家视距外时不吐酸：先靠近到玩家可见范围内再射击
				var los := target_los and _in_player_view(d)
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
	var _pt := Prof.t0()
	_animate_impl(delta, mv)
	Prof.add("bug.anim", _pt)


func _rebuild_leg_anim() -> void:
	_leg_anim_cnt = legs.size()
	_leg_anim.clear()
	for hip in legs:
		if not is_instance_valid(hip):
			continue
		var kj: Node3D = hip.get_meta("knee") if hip.has_meta("knee") else null
		_leg_anim.append([
			hip,
			float(hip.get_meta("phase", 0.0)),
			float(hip.get_meta("side", 1.0)),
			float(hip.get_meta("base_y", hip.rotation.y)),
			kj if is_instance_valid(kj) else null,
		])


func _animate_impl(delta: float, mv: float) -> void:
	move_amt = move_toward(move_amt, clampf(mv, 0.0, 1.0), delta * 6.0)
	var cad: float = 14.0 if beh == "ling" else (9.0 if beh == "spitter" else 6.5)
	anim_t += delta * (0.3 + move_amt)
	var amt := move_amt
	var swing := 0.42 if beh != "beetle" else 0.4
	var liftk := 0.45 if beh == "ling" else (0.32 if beh == "spitter" else 0.32)
	var k := clampf(16.0 * delta, 0.0, 1.0)
	if _leg_anim_cnt != legs.size():
		_rebuild_leg_anim()
	for la in _leg_anim:
		var hip: Node3D = la[0]
		var ph: float = anim_t * cad + float(la[1])
		var side: float = float(la[2])
		var s_ph := sin(ph)
		var c_ph := cos(ph)
		var sy := float(la[3]) - s_ph * swing * amt * side
		var lz := (pow(c_ph, 0.82) * liftk if c_ph > 0.0 else c_ph * 0.08) * amt * side
		var kz := ((-0.48 * c_ph + 0.28 * s_ph * c_ph) * liftk if c_ph > 0.0 else -c_ph * 0.15) * amt * side
		if act == "wind":
			lz += 0.16 * side
			kz -= 0.26 * side
		elif act == "strike":
			lz -= 0.12 * side
			kz += 0.20 * side
		hip.rotation.y = lerp_angle(hip.rotation.y, sy, k)
		hip.rotation.x = 0.0
		hip.rotation.z = lerp(hip.rotation.z, lz, k)
		var kj: Node3D = la[4]
		if kj != null:
			kj.rotation.z = lerp(kj.rotation.z, kz, k)
			kj.rotation.x = lerp(kj.rotation.x, c_ph * 0.14 * amt, k)
	if _body_node == null or not is_instance_valid(_body_node):
		_body_node = visual.get_node_or_null("Body")
	var body: Node3D = _body_node
	if body == null:
		return
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


func _collect_hit_meshes() -> void:
	if _hit_meshes_ready or not is_instance_valid(visual):
		return
	_hit_meshes_ready = true
	_hit_meshes.clear()
	var body := visual.get_node_or_null("Body")
	if body != null:
		for ch in body.get_children():
			if ch is MeshInstance3D:
				var mi := ch as MeshInstance3D
				if not mi.get_meta("no_flash", false) and not mi.get_meta("shield", false) and not (mi.mesh is PlaneMesh):
					_hit_meshes.append(mi)
	if is_instance_valid(sac) and not _hit_meshes.has(sac):
		_hit_meshes.append(sac)
	var abd = get("abdomen")
	if abd is Node3D and is_instance_valid(abd):
		for ch in (abd as Node3D).get_children():
			if ch is MeshInstance3D and not _hit_meshes.has(ch):
				_hit_meshes.append(ch)
	if not _hit_meshes.is_empty():
		return
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.get_meta("no_flash", false) or mi.get_meta("shield", false):
			continue
		if mi.mesh is PlaneMesh:
			continue
		_hit_meshes.append(mi)
	for p in parts:
		if is_instance_valid(p) and not p.get_meta("no_flash", false) and not _hit_meshes.has(p):
			_hit_meshes.append(p)


func _update_flash() -> void:
	var q := clampi(int(ceil(clampf(flash_t / FLASH_DUR, 0.0, 1.0) * 5.0)), 0, 5) if flash_t > 0.0 else 0
	if q == _hit_flash_q:
		return
	_hit_flash_q = q
	_collect_hit_meshes()
	var mat: Material = A.hit_flash_overlay(float(q) / 5.0) if q > 0 else null
	for p in _hit_meshes:
		if is_instance_valid(p):
			p.material_overlay = mat


func _set_flash(on: bool) -> void:
	if not on:
		flash_t = 0.0
	elif flash_t <= 0.0:
		flash_t = FLASH_DUR
	_update_flash()


func _apply_hit_jolt(from: Vector3, push: float) -> void:
	var mag := maxf(push, 0.22) * 4.2
	var away := Vector3.ZERO
	if from != Vector3.ZERO:
		away = global_position - from
		away.y = 0.0
	if away.length_squared() > 0.0025 and is_instance_valid(visual):
		away = away.normalized()
		var local_away := visual.global_transform.basis.inverse() * away
		hit_v.x += local_away.z * mag + randf_range(-0.4, 0.4) * mag
		hit_v.z += -local_away.x * mag + randf_range(-0.4, 0.4) * mag
	else:
		hit_v += Vector3(randf_range(0.6, 1.1), 0, randf_range(-0.7, 0.7)) * mag


func _head_bar_y() -> float:
	if _cached_bar_y > 0.0:
		return _cached_bar_y
	var max_y := -1e9
	if visual != null and is_instance_valid(visual):
		var inv := visual.global_transform.affine_inverse()
		for n in visual.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null or (mi.mesh is PlaneMesh) or mi.get_meta("no_flash", false) or mi.get_meta("shield", false):
				continue
			var aabb := mi.get_aabb()
			var rel := inv * mi.global_transform
			for ix in 2:
				for iy in 2:
					for iz in 2:
						var p := rel * Vector3(
							aabb.position.x + aabb.size.x * float(ix),
							aabb.position.y + aabb.size.y * float(iy),
							aabb.position.z + aabb.size.z * float(iz)
						)
						max_y = maxf(max_y, p.y)
	var sc := float(data.get("scale", 1.0))
	if max_y > 0.2:
		_cached_bar_y = max_y + clampf(0.28 + sc * 0.16, 0.35, 0.85)
	else:
		_cached_bar_y = maxf(2.0, sc * 1.45 + 0.6)
	return _cached_bar_y


func take_damage(amount: float, from := Vector3.ZERO, ap := 0.0) -> void:
	if hp <= 0.0:
		return
	_wake()
	var base_arm := float(data.get("armor", 0.22 if kind == "beetle" else 0.0))
	var eff_arm := clampf(base_arm * (1.0 - clampf(ap, 0.0, 0.85)), 0.0, 0.9) if ap > 0.0 else 0.0
	var dmg := amount * (1.0 - eff_arm) if ap > 0.0 else amount
	var prev_hp := hp
	hp -= dmg
	var damage_t := Prof.t0()
	if raid != null and raid.hud != null and raid.hud.has_method("notify_enemy_hit") and not bool(data.get("boss", false)):
		raid.hud.notify_enemy_hit(self, prev_hp, hp, float(data.get("hp", 30.0)))
	Prof.add("damage.bar", damage_t)
	damage_t = Prof.t0()
	_aggro_on_hit()
	Prof.add("damage.aggro", damage_t)
	damage_t = Prof.t0()
	flash_t = FLASH_DUR
	_update_flash()
	Prof.add("damage.flash", damage_t)
	# 受击倾斜冲击：按来弹方位沿受击侧倾仰
	var push := clampf(amount / float(data.hp) * 6.0, 0.15, 1.0) / float(data.scale)
	_apply_hit_jolt(from, push)
	if hp <= 0.0:
		damage_t = Prof.t0()
		raid.on_bug_killed(self)
		Prof.add("damage.kill_event", damage_t)
		damage_t = Prof.t0()
		_die()
		Prof.add("damage.die", damage_t)


## 死亡：移出战斗、残骸塌落（腿外撇、机身砸地侧翻）、冒火花与黑烟，数秒后沉入地面
func _die() -> void:
	var death_t := Prof.t0()
	dying = true
	remove_from_group("bugs")
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	_set_flash(false)
	Prof.add("death.detach", death_t)
	death_t = Prof.t0()
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
		Prof.add("death.tweens", death_t)
		death_t = Prof.t0()
		tw.tween_property(gun, "rotation:x", -0.18, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		# 发光件熄灭
		var dead_em := _get_dead_eye_mat()
		for m in _dead_lights:
			if not is_instance_valid(m):
				continue
			m.material_override = dead_em
		if raid:
			Prof.add("death.materials", death_t)
			death_t = Prof.t0()
			var p := global_position + Vector3(0, 0.8 * sc, 0)
			A.burst(raid.fx, p, {"amount": 16, "life": 0.5, "size": 0.1, "tex": A.soft_dot(), "additive": true, "vmin": 4.0, "vmax": 9.0, "spread": 80.0, "dir": Vector3.UP,
				"gravity": Vector3(0, -14, 0), "c0": Color(1, 0.85, 0.5), "c1": Color(1, 0.35, 0.1, 0)})
			A.burst(raid.fx, p, {"amount": 10, "life": 1.6, "size": 0.7 * sc, "additive": false, "vmin": 0.5, "vmax": 1.5, "spread": 30.0, "dir": Vector3.UP,
				"gravity": Vector3(0, 1.2, 0), "damp": 0.5, "tex": A.soft_dot(), "c0": Color(0.12, 0.12, 0.13, 0.45), "c1": Color(0.15, 0.15, 0.16, 0.0), "grow0": 0.6, "grow1": 1.8})
		Prof.add("death.particles", death_t)
	tw.finished.connect(_finalize_corpse)


static func _get_dead_eye_mat() -> StandardMaterial3D:
	if _dead_eye_mat == null:
		_dead_eye_mat = StandardMaterial3D.new()
		_dead_eye_mat.albedo_color = Color(0.08, 0.08, 0.09)
		_dead_eye_mat.roughness = 0.85
		_dead_eye_mat.metallic = 0.25
	return _dead_eye_mat


func _finalize_corpse() -> void:
	if not is_instance_valid(self):
		return
	set_physics_process(false)
	set_process(false)
	set_notify_transform(false)
	var sh_fx = get_meta("shield_fx") if has_meta("shield_fx") else null
	if sh_fx != null and is_instance_valid(sh_fx):
		sh_fx.queue_free()
		remove_meta("shield_fx")
	var dm := _get_dead_eye_mat()
	var vis_end := 42.0 if A.is_mobile_perf() else 62.0
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_overlay = null
		if not (mi.mesh is PlaneMesh):
			mi.visibility_range_end = vis_end
			mi.visibility_range_end_margin = 4.0
		var m := mi.material_override as StandardMaterial3D
		if m != null and m.emission_enabled:
			mi.material_override = dm


static func _panelize(m: StandardMaterial3D, scale := 0.45) -> void:
	# 重工轧制钢微肌理贴图：三平面连续金属拉丝与法线微起伏，保持硬表面几何零件棱线清晰
	if A.is_mobile_perf():
		m.albedo_texture = A.world_tex("steel_plate_a.png")
		m.uv1_scale = Vector3.ONE * (scale * 0.85)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		return
	m.albedo_texture = A.world_tex("steel_plate_a.png")
	m.normal_enabled = true
	m.normal_texture = A.world_tex("steel_plate_n.png")
	m.normal_scale = 0.42
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


# ---------------- 外观挂点 ----------------
## 外观子树挂在一个 top_level 的空节点（VisAnchor）下，而不是直接挂在机体上：
## move_and_slide 每次迭代都会改写机体变换，外观直接挂在机体下时，每次改写都要把整棵外观子树（机甲约 700 个节点、虫子约 80 个）
## 标脏并逐个通知渲染。挂点只在机体变换真正变了之后同步一次（移动后显式同步 + 变换通知兜底：传送、补间、死亡下沉都跟得上）
var vis_anchor: Node3D = null


func _anchor_visual() -> void:
	if visual == null or vis_anchor != null:
		return
	vis_anchor = Node3D.new()
	vis_anchor.name = "VisAnchor"
	vis_anchor.top_level = true
	for ch in get_children():
		if ch is MeshInstance3D:
			remove_child(ch)
			vis_anchor.add_child(ch)
	add_child(vis_anchor)
	if visual.get_parent():
		visual.get_parent().remove_child(visual)
	vis_anchor.add_child(visual)
	set_notify_transform(true)
	_vis_sync()


func _vis_sync() -> void:
	if vis_anchor != null and is_inside_tree():
		var gt := global_transform
		if vis_anchor.transform != gt:
			vis_anchor.transform = gt


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_vis_sync()
