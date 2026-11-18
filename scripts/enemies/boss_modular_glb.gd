extends RefCounted
## 模块化 Meshy GLB 巨型首领组装与程序化骨骼/关节驱动器：
##   1) citadel_behemoth（六足要塞·陆地巡洋舰）：全高 ~12.8m（主角机甲 4.5 倍以上），
##      组装 citadel_hull + 6 条独立铰接液压巨足 citadel_leg（三角交替步态）+ 1 座顶置双联主炮 citadel_main_turret + 4 座四角副炮塔 citadel_sub_turret；
##   2) sky_carrier（苍穹铁砧·重工浮空母舰）：全长 ~14.8m 浮空航母，
##      组装 carrier_hull + 4 具倾转矢量涵道涡扇舱 carrier_thruster + 3 座舰载独立旋转炮塔 citadel_sub_turret。
## 所有加载的 ArrayMesh 均经 BossGlb._get_sanitized_mesh 校验法线，且严禁负缩放，确保 normal_audit 零误差。

const ART = preload("res://scripts/art.gd")
const BossGlb = preload("res://scripts/enemies/boss_glb.gd")

const GLB_PATHS := {
	"citadel_hull": "res://assets/models/boss/citadel_hull.glb",
	"citadel_leg": "res://assets/models/boss/citadel_leg.glb",
	"citadel_main_turret": "res://assets/models/boss/citadel_main_turret.glb",
	"citadel_sub_turret": "res://assets/models/boss/citadel_sub_turret.glb",
	"carrier_hull": "res://assets/models/boss/carrier_hull.glb",
	"carrier_thruster": "res://assets/models/boss/carrier_thruster.glb",
}

static var _packed_cache := {}


static func _spawn_glb(h, parent: Node3D, key: String, u_scale: float, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, xz_thick_mult := 1.0) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = key.to_pascal_case()
	wrap.position = pos
	wrap.rotation_degrees = rot_deg
	var sy := maxf(u_scale, 0.001)
	var sxz := maxf(u_scale * xz_thick_mult, 0.001)
	wrap.scale = Vector3(sxz, sy, sxz)
	parent.add_child(wrap)

	var path: String = str(GLB_PATHS.get(key, ""))
	var ps: PackedScene = _packed_cache.get(path)
	if ps == null and path != "" and ResourceLoader.exists(path):
		ps = load(path) as PackedScene
		if ps != null:
			_packed_cache[path] = ps
	if ps != null:
		var inst: Node = ps.instantiate()
		if inst != null:
			wrap.add_child(inst)
			var mob_perf: bool = ART.is_mobile_perf()
			for n in inst.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi == null or mi.mesh == null:
					continue
				if mi.mesh is ArrayMesh:
					mi.mesh = BossGlb._get_sanitized_mesh(mi.mesh as ArrayMesh)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if mob_perf:
					mi.visibility_range_end = 155.0
					mi.visibility_range_end_margin = 6.0
				h.parts.append(mi)
			return wrap

	# 无 GLB 时的兜底重工几何块（保证无资源环境下亦不崩溃）
	var fb := MeshInstance3D.new()
	fb.mesh = ART.bevel_box(Vector3(1.2, 0.8, 1.2), 0.06)
	fb.material_override = ART.metal(Color(0.24, 0.26, 0.29))
	fb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wrap.add_child(fb)
	h.parts.append(fb)
	return wrap


static func _add_part(h, parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, sc := Vector3.ONE, flashable := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not flashable:
		mi.set_meta("no_flash", true)
	parent.add_child(mi)
	h.parts.append(mi)
	return mi


# ==============================================================================
# 1. 超巨型宽体六足陆地巡洋舰（citadel_behemoth，s = 5.6 -> 全高 ~17.0m [>4.2x 机甲]，全宽 ~32.7m，长 ~26.5m）
# ==============================================================================
static func build_citadel_behemoth(h, body: Node3D, s: float) -> void:
	var m_dark: Material = ART.metal(Color(0.16, 0.18, 0.20))
	var m_steel: Material = ART.paint(Color(0.26, 0.28, 0.30), 0.62, 0.48, {"rust": 0.45, "wear": 0.42})
	var m_chrome: Material = ART.metal(Color(0.76, 0.79, 0.83))
	var m_brass: Material = ART.paint(Color(0.82, 0.63, 0.22), 0.88, 0.28, {"panel_scale": 0.0})
	var m_haz: Material = ART.hazard()
	var core_col := Color(0.28, 0.90, 1.0)

	# 1) 六条超粗重承重三角桁架液压巨足（径向加粗逾 2.0x 股/胫柱 + 腹底双联斜撑镀铬液压主油缸 + 7m 宽四爪铆接驻锄重靴）
	var fem_s: float = 0.74 * s
	var tib_s: float = 0.76 * s
	var fem_thick := 1.90 # 股节截面加粗 1.90 倍（实宽逾 3.8m）
	var tib_thick := 2.12 # 胫节与四爪巨足截面加粗 2.12 倍（小腿粗逾 4.1m，四爪PBR重靴宽逾 7.1m！）
	var sole_h: float = 0.055 * s # 重型防陷钢底板厚度，垫在四爪下方而不遮挡四爪PBR细节
	var fem_elev_deg := 11.0
	var fem_elev_rad := deg_to_rad(fem_elev_deg)
	var tib_splay_rad := 0.10 # 胫节近垂直承重（仅外倾 ~5.7°），确保巨型承压底靴平贴地面
	var fem_span: float = 1.54 * fem_s
	var fem_dy: float = fem_span * sin(fem_elev_rad)
	var tib_drop: float = (1.712 * tib_s + sole_h) * cos(tib_splay_rad)
	var hip_y: float = tib_drop - fem_dy # 精确求得髋高，六足承压底板零悬空平踩 y=0

	var legs_root := Node3D.new()
	legs_root.name = "HexapodLegs"
	body.add_child(legs_root)

	var leg_specs := [
		[1.62, -1.08, -32.0, 0],
		[1.82, 0.02, 0.0, 1],
		[1.62, 1.10, 32.0, 2],
	]
	var mod_legs: Array = []
	for spec in leg_specs:
		var lx_k: float = float(spec[0])
		var lz_k: float = float(spec[1])
		var yaw_deg: float = float(spec[2])
		var row_i: int = int(spec[3])
		for sx: float in [-1.0, 1.0]:
			var hip_yaw := Node3D.new()
			hip_yaw.name = "Hip_%d_%s" % [row_i, "R" if sx > 0.0 else "L"]
			hip_yaw.position = Vector3(sx * lx_k * s, hip_y, lz_k * s)
			var base_yaw: float = deg_to_rad(sx * yaw_deg)
			hip_yaw.rotation.y = base_yaw
			legs_root.add_child(hip_yaw)

			# 下腹底盘斜撑支座耳耳轴（构成真实工程学 A 字三角承力桁架）
			var brace_anchor := Vector3(-sx * 0.26 * s, -0.48 * s, 0.0)
			_add_part(h, hip_yaw, ART.bevel_box(Vector3(0.32, 0.28, 0.56) * s, 0.03 * s), m_dark, brace_anchor)

			var fem_lift := Node3D.new()
			fem_lift.name = "FemurLift"
			hip_yaw.add_child(fem_lift)

			# 外伸重装加粗股节（Femur）
			var dir_fk := Vector3(sx * cos(fem_elev_rad), sin(fem_elev_rad), 0.0)
			var fem_z_deg: float = -79.0 if sx > 0.0 else 79.0
			_spawn_glb(h, fem_lift, "citadel_leg", fem_s, dir_fk * (0.78 * fem_s), Vector3(0.0, 0.0, fem_z_deg), fem_thick)

			# 膝关节直接露出 citadel_leg 原生 2K PBR 球形铆接钢关节与液压双油缸（无素色圆盘遮挡）
			var knee := Node3D.new()
			knee.name = "KneeJoint"
			knee.position = dir_fk * fem_span
			var base_knee_z: float = -sx * tib_splay_rad
			knee.rotation.z = base_knee_z
			fem_lift.add_child(knee)

			var tib_yaw: float = 90.0 if sx > 0.0 else -90.0
			_spawn_glb(h, knee, "citadel_leg", tib_s, Vector3(0.0, -0.76 * tib_s, 0.0), Vector3(0.0, tib_yaw, 0.0), tib_thick)

			# 四爪巨足下垫低矮重型防陷驻锄承压底板（完整保留上方 PBR 四爪装甲细节同时扩大接地面积）
			var sole_y: float = -1.712 * tib_s - sole_h
			var foot_pad := Node3D.new()
			foot_pad.name = "StompPad"
			foot_pad.position = Vector3(0.0, sole_y, 0.0)
			knee.add_child(foot_pad)
			_add_part(h, foot_pad, ART.cyl(0.62 * s, sole_h, 0.68 * s, 8), m_dark, Vector3(0.0, sole_h * 0.5, 0.0), Vector3(0.0, 22.5, 0.0))
			_add_part(h, foot_pad, ART.bevel_box(Vector3(0.08, 0.048, 0.68) * s, 0.01 * s), m_haz, Vector3(sx * 0.61 * s, sole_h * 0.5, 0.0))
			for cz: float in [-0.42, 0.0, 0.42]:
				_add_part(h, foot_pad, ART.bevel_box(Vector3(1.26, 0.036, 0.12) * s, 0.01 * s), m_steel, Vector3(0.0, sole_h * 0.3, cz * s))

			# 膝下斜撑锚点（随 FemurLift 运动）与腹底双联重型液压支撑油缸（实时伸缩承力）
			var knee_lug := Marker3D.new()
			knee_lug.position = dir_fk * (fem_span * 0.88) + Vector3(0.0, -0.22 * s, 0.0)
			fem_lift.add_child(knee_lug)

			var rams: Array = []
			for rz: float in [-0.17, 0.17]:
				var barrel := Node3D.new()
				barrel.position = brace_anchor + Vector3(0.0, 0.0, rz * s)
				hip_yaw.add_child(barrel)
				# 外套暗钢油缸筒（沿局部 -Z 朝向目标伸出）
				_add_part(h, barrel, ART.cyl(0.095 * s, 0.72 * s, 0.105 * s, 12), m_dark, Vector3(0.0, 0.0, -0.36 * s), Vector3(-90.0, 0.0, 0.0))
				_add_part(h, barrel, ART.cyl(0.115 * s, 0.08 * s, 0.115 * s, 12), m_brass, Vector3(0.0, 0.0, -0.70 * s), Vector3(-90.0, 0.0, 0.0))

				var rod := Node3D.new()
				rod.position = knee_lug.position + Vector3(0.0, 0.0, rz * s)
				hip_yaw.add_child(rod)
				# 内芯镀铬实心活塞杆（从膝下耳轴插回油缸筒内）
				_add_part(h, rod, ART.cyl(0.068 * s, 0.78 * s, 0.068 * s, 12), m_chrome, Vector3(0.0, 0.0, -0.39 * s), Vector3(-90.0, 0.0, 0.0))
				rams.append({"barrel": barrel, "rod": rod, "z_off": rz * s})
			_sync_leg_rams(hip_yaw, knee_lug, brace_anchor, rams)

			# 三角交替步态：L0 + R1 + L2 为 A 组（0），R0 + L1 + R2 为 B 组（PI）
			var is_group_a: bool = (row_i % 2 == 0 and sx < 0.0) or (row_i % 2 == 1 and sx > 0.0)
			var ph: float = 0.0 if is_group_a else PI
			mod_legs.append({
				"hip": hip_yaw,
				"lift": fem_lift,
				"knee": knee,
				"foot_pad": foot_pad,
				"was_lifted": false,
				"knee_lug": knee_lug,
				"brace_anchor": brace_anchor,
				"rams": rams,
				"side": sx,
				"base_yaw": base_yaw,
				"base_splay": 0.0,
				"base_knee_z": base_knee_z,
				"phase": ph,
			})

	# 舰腹正下方深色接地环境光遮蔽暗影（压暗腹底亮黄沙地，拉开深铁灰装甲与地面的明暗对比）
	var belly_ao := ART.ground_vfx(h, ART.blob_tex(), Color(0.02, 0.02, 0.03, 0.90), 5.4 * s, Vector3(0.0, 0.036, 0.0), false, 0.42, false, 1)
	belly_ao.set_meta("no_flash", true)

	# 2) 超宽体多舱段复合装甲堡垒主船体（主舰体 + 左右重装舷侧翼舱 + 前后装甲首尾甲板，船体实宽逾 21m、长逾 18m）
	var hull_deck := Node3D.new()
	hull_deck.name = "HullDeck"
	var hull_base_y: float = 1.16 * s # 压低重心稳坐六足拱架中央，彻底告别瘦高塔形
	hull_deck.position = Vector3(0.0, hull_base_y, 0.0)
	body.add_child(hull_deck)

	# 中央核心堡垒 + 左右宽展舷侧重装炮廓翼舱 + 前后延伸装甲段（船体实宽逾 25m，无贴图拉伸、无负缩放）
	_spawn_glb(h, hull_deck, "citadel_hull", 1.28 * s, Vector3(0.0, 0.04 * s, 0.0), Vector3(0.0, 180.0, 0.0))
	_spawn_glb(h, hull_deck, "citadel_hull", 1.12 * s, Vector3(-1.32 * s, -0.06 * s, 0.04 * s), Vector3(0.0, -90.0, 0.0))
	_spawn_glb(h, hull_deck, "citadel_hull", 1.12 * s, Vector3(1.32 * s, -0.06 * s, 0.04 * s), Vector3(0.0, 90.0, 0.0))
	_spawn_glb(h, hull_deck, "citadel_hull", 1.02 * s, Vector3(0.0, -0.10 * s, -0.88 * s), Vector3(0.0, 180.0, 0.0))
	_spawn_glb(h, hull_deck, "citadel_hull", 1.02 * s, Vector3(0.0, -0.10 * s, 0.90 * s), Vector3(0.0, 0.0, 0.0))

	# 贯通宽体底盘横梁桁架（横向连接左右六处外扩髋关节支座）
	var under := Node3D.new()
	under.name = "UnderChassis"
	hull_deck.add_child(under)
	_add_part(h, under, ART.bevel_box(Vector3(3.15, 0.22, 2.15) * s, 0.04 * s), m_dark, Vector3(0.0, -0.48 * s, 0.0))
	for row_z: float in [-1.06, 0.02, 1.08]:
		_add_part(h, under, ART.bevel_box(Vector3(3.65, 0.18, 0.26) * s, 0.025 * s), m_steel, Vector3(0.0, -0.22 * s, row_z * s))

	# 3) 前首楼凹槽反应堆芯（core_mi）与双开液压防爆闸门（plates）
	var core_box := Node3D.new()
	core_box.name = "CoreVault"
	core_box.position = Vector3(0.0, -0.22 * s, -1.28 * s)
	hull_deck.add_child(core_box)
	var core: MeshInstance3D = _add_part(h, core_box, ART.cyl(0.14 * s, 0.24 * s, 0.14 * s, 14), ART.emit(core_col, 0.55), Vector3.ZERO, Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
	h.core_mi = core
	_add_part(h, core_box, ART.torus(0.16 * s, 0.21 * s, 14), m_brass, Vector3(0.0, 0.0, -0.06 * s), Vector3.ZERO, Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.name = "CoreDoorR" if sx > 0.0 else "CoreDoorL"
		pl.position = Vector3(sx * 0.24 * s, -0.22 * s, -1.42 * s)
		pl.set_meta("side", sx)
		hull_deck.add_child(pl)
		_add_part(h, pl, ART.bevel_box(Vector3(0.24, 0.36, 0.06) * s, 0.015 * s), m_dark, Vector3(-sx * 0.11 * s, 0.0, 0.0))
		_add_part(h, pl, ART.bevel_box(Vector3(0.19, 0.08, 0.065) * s, 0.008 * s), m_haz, Vector3(-sx * 0.11 * s, 0.0, -0.005 * s))
		h.plates.append(pl)

	# 4) 7 座宽幅横向展开独立旋转炮塔（1 座中置低矮重装双联主炮 + 6 座遍布前首、左右外翼与后尾的独立副炮塔）
	var turret_mounts: Array = []

	# 4a) 宽底座低矮直接嵌装双联攻城主炮（无瘦高脖颈，全高定格 ~17.0m = 4.24x 主角机甲全高）
	var main_yaw := Node3D.new()
	main_yaw.name = "MainTurretYaw"
	main_yaw.position = Vector3(0.0, 0.56 * s, 0.04 * s)
	hull_deck.add_child(main_yaw)

	var main_recoil := Node3D.new()
	main_recoil.name = "MainRecoil"
	main_yaw.add_child(main_recoil)

	var ms: float = 1.04 * s # 双联巨炮长达 11.0m，宽厚贴合主甲板
	_spawn_glb(h, main_recoil, "citadel_main_turret", ms, Vector3(0.0, 0.37 * ms, -0.22 * ms), Vector3(0.0, -90.0, 0.0))

	# 宽幅横置相控阵火控指挥桥架（全机顶高 ~17.0m，横向加宽顶部轮廓）
	var mast := Node3D.new()
	mast.name = "FireControlMast"
	mast.position = Vector3(0.0, 0.72 * ms, 0.12 * ms)
	main_recoil.add_child(mast)
	_add_part(h, mast, ART.bevel_box(Vector3(0.34, 0.24, 0.22) * s, 0.02 * s), m_dark, Vector3(0.0, 0.12 * s, 0.0))
	var radar_spin := Node3D.new()
	radar_spin.position = Vector3(0.0, 0.32 * s, 0.0)
	mast.add_child(radar_spin)
	_add_part(h, radar_spin, ART.bevel_box(Vector3(0.68, 0.09, 0.12) * s, 0.015 * s), m_brass, Vector3.ZERO)
	h.spinners.append([radar_spin, Vector3.UP, 2.2, 5.5])

	var muz_l := Marker3D.new()
	muz_l.name = "MuzzleL"
	muz_l.position = Vector3(-0.18 * ms, 0.36 * ms, -1.16 * ms)
	main_recoil.add_child(muz_l)
	var muz_r := Marker3D.new()
	muz_r.name = "MuzzleR"
	muz_r.position = Vector3(0.18 * ms, 0.36 * ms, -1.16 * ms)
	main_recoil.add_child(muz_r)

	turret_mounts.append({
		"role": "main",
		"yaw_node": main_yaw,
		"recoil_node": main_recoil,
		"muzzles": [muz_l, muz_r],
		"home_yaw": 0.0,
		"arc_half": PI,
		"turn_speed": 1.70,
		"cd": 1.6,
		"wind_rem": 0.0,
	})

	# 4b) 6 座遍布宽体甲板的独立副炮塔（前首双炮 + 左右远端外翼舷侧双炮 + 后尾双炮，横向间距近 20m）
	var ss: float = 0.38 * s
	var sub_defs := [
		[Vector3(-0.82, 0.34, -1.04), 0.38, 2.15, 0.70],     # 左前首楼副炮
		[Vector3(0.82, 0.34, -1.04), -0.38, 2.15, 1.05],     # 右前首楼副炮
		[Vector3(-1.72, 0.42, 0.04), 1.35, 2.25, 1.40],      # 左翼远端舷侧副炮
		[Vector3(1.72, 0.42, 0.04), -1.35, 2.25, 1.75],      # 右翼远端舷侧副炮
		[Vector3(-0.84, 0.34, 1.08), PI - 0.42, 2.15, 2.10], # 左后尾楼副炮
		[Vector3(0.84, 0.34, 1.08), -PI + 0.42, 2.15, 2.45], # 右后尾楼副炮
	]
	for idx in sub_defs.size():
		var sd: Array = sub_defs[idx]
		var rel_p: Vector3 = (sd[0] as Vector3) * s
		var h_yaw: float = float(sd[1])
		var arc_h: float = float(sd[2])
		var init_cd: float = float(sd[3])

		var pad := Node3D.new()
		pad.name = "SponsonPad_%d" % idx
		pad.position = rel_p
		hull_deck.add_child(pad)
		_add_part(h, pad, ART.cyl(0.20 * s, 0.08 * s, 0.22 * s, 12), m_dark, Vector3(0.0, -0.02 * s, 0.0))

		var syaw := Node3D.new()
		syaw.name = "SubTurretYaw_%d" % idx
		syaw.position = rel_p + Vector3(0.0, 0.02 * s, 0.0)
		syaw.rotation.y = h_yaw
		hull_deck.add_child(syaw)

		var srecoil := Node3D.new()
		srecoil.name = "SubRecoil"
		syaw.add_child(srecoil)
		_spawn_glb(h, srecoil, "citadel_sub_turret", ss, Vector3(0.0, 0.69 * ss, 0.08 * ss), Vector3(0.0, 180.0, 0.0))

		var m_gun := Marker3D.new()
		m_gun.name = "MuzzleGun"
		m_gun.position = Vector3(-0.66 * ss, 0.68 * ss, -0.85 * ss)
		srecoil.add_child(m_gun)
		var m_pod := Marker3D.new()
		m_pod.name = "MuzzlePod"
		m_pod.position = Vector3(0.72 * ss, 0.80 * ss, -0.58 * ss)
		srecoil.add_child(m_pod)

		turret_mounts.append({
			"role": "sub",
			"yaw_node": syaw,
			"recoil_node": srecoil,
			"muzzles": [m_gun, m_pod],
			"home_yaw": h_yaw,
			"arc_half": arc_h,
			"turn_speed": 2.75,
			"cd": init_cd,
			"burst_left": 0,
			"burst_t": 0.0,
			"shots_n": idx,
		})

	h.set_meta("turret_mounts", turret_mounts)
	h.set_meta("modular_glb", {
		"type": "citadel",
		"hull_deck": hull_deck,
		"hull_base_y": hull_base_y,
		"legs": mod_legs,
		"awaken_t": 0.0,
	})


# ==============================================================================
# 2. 重工业浮空要塞母舰（sky_carrier，s = 3.8，hover = 5.6 -> 舰长 ~14.8m，翼展 ~14.2m）
# ==============================================================================
static func build_sky_carrier(h, body: Node3D, s: float) -> void:
	var m_dark: Material = ART.metal(Color(0.15, 0.18, 0.22))
	var m_steel: Material = ART.paint(Color(0.24, 0.28, 0.33), 0.60, 0.46, {"rust": 0.38, "wear": 0.36})
	var m_brass: Material = ART.paint(Color(0.82, 0.64, 0.22), 0.88, 0.26, {"panel_scale": 0.0})
	var m_haz: Material = ART.hazard()
	var m_jet: Material = ART.emit(Color(0.26, 0.88, 1.0), 2.2)
	var core_col := Color(0.26, 0.90, 1.0)

	var ship_rig := Node3D.new()
	ship_rig.name = "CarrierRig"
	body.add_child(ship_rig)

	# 1) 浮空母舰主舰体（carrier_hull raw 舰首朝 -X，绕 Y 转 -90° 对齐 -Z 正前）
	var hs: float = 2.05 * s # ~7.79 -> 舰长 14.8m，舰宽 9.5m
	_spawn_glb(h, ship_rig, "carrier_hull", hs, Vector3.ZERO, Vector3(0.0, -90.0, 0.0))

	# 2) 四具倾转涵道涡扇推进舱（carrier_thruster.glb，挂在左右四处短翼挂架外端）
	var ts: float = 0.50 * s # ~1.90 -> 推进舱高 3.58m
	var thrusters: Array = []
	var pylon_z_list := [-0.88, 0.78]
	for z_i in pylon_z_list.size():
		var pz: float = float(pylon_z_list[z_i]) * s
		for sx: float in [-1.0, 1.0]:
			var arm := Node3D.new()
			arm.name = "Pylon_%d_%s" % [z_i, "R" if sx > 0.0 else "L"]
			arm.position = Vector3(sx * 1.18 * s, -0.26 * s, pz)
			ship_rig.add_child(arm)
			_add_part(h, arm, ART.bevel_box(Vector3(0.42, 0.18, 0.28) * s, 0.025 * s), m_dark, Vector3(-sx * 0.16 * s, 0.0, 0.0))

			var pod := Node3D.new()
			pod.name = "ThrusterPod"
			pod.position = Vector3(sx * 0.22 * s, 0.0, 0.0)
			arm.add_child(pod)

			var pod_yaw: float = 0.0 if sx > 0.0 else 180.0
			_spawn_glb(h, pod, "carrier_thruster", ts, Vector3.ZERO, Vector3(0.0, pod_yaw, 0.0))

			# 尾喷口内嵌电浆尾焰芯（紧凑收束于矢量喷口内侧）
			var flame: MeshInstance3D = _add_part(h, pod, ART.cyl(0.03 * ts, 0.42 * ts, 0.17 * ts, 10), m_jet, Vector3(0.0, -1.02 * ts, 0.0), Vector3.ZERO, Vector3.ONE, false)
			thrusters.append({
				"pod": pod,
				"flame": flame,
				"side": sx,
				"is_front": z_i == 0,
			})

	# 3) 前机库内凹反应堆晶核（core_mi）与左右装甲机库门（plates）
	var hangar := Node3D.new()
	hangar.name = "BowHangarCore"
	hangar.position = Vector3(0.0, -0.22 * s, -1.68 * s)
	ship_rig.add_child(hangar)
	var core: MeshInstance3D = _add_part(h, hangar, ART.cyl(0.12 * s, 0.20 * s, 0.12 * s, 14), ART.emit(core_col, 0.60), Vector3.ZERO, Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
	h.core_mi = core
	_add_part(h, hangar, ART.torus(0.14 * s, 0.18 * s, 14), m_brass, Vector3(0.0, 0.0, -0.05 * s), Vector3.ZERO, Vector3.ONE, false)
	for sx: float in [-1.0, 1.0]:
		var pl := Node3D.new()
		pl.name = "HangarDoorR" if sx > 0.0 else "HangarDoorL"
		pl.position = Vector3(sx * 0.22 * s, -0.22 * s, -1.80 * s)
		pl.set_meta("side", sx)
		ship_rig.add_child(pl)
		_add_part(h, pl, ART.bevel_box(Vector3(0.22, 0.30, 0.06) * s, 0.015 * s), m_dark, Vector3(-sx * 0.10 * s, 0.0, 0.0))
		_add_part(h, pl, ART.bevel_box(Vector3(0.18, 0.07, 0.065) * s, 0.008 * s), m_haz, Vector3(-sx * 0.10 * s, 0.0, -0.005 * s))
		h.plates.append(pl)

	# 4) 3 座独立旋转对地火力炮塔（2 座前腹下沉炮座 + 1 座前甲板全向炮塔）
	var ss: float = 0.33 * s
	var turret_mounts: Array = []
	var carrier_turrets := [
		[Vector3(-0.68, -0.62, -0.95), 0.32, 2.25, 0.90],  # 左前舰腹耳台炮塔
		[Vector3(0.68, -0.62, -0.95), -0.32, 2.25, 1.45],  # 右前舰腹耳台炮塔
		[Vector3(0.0, 0.17, -0.68), 0.0, PI, 2.00],        # 前飞行甲板全向防卫炮塔（紧贴前甲板）
	]
	for idx in carrier_turrets.size():
		var td: Array = carrier_turrets[idx]
		var rel_p: Vector3 = (td[0] as Vector3) * s
		var h_yaw: float = float(td[1])
		var arc_h: float = float(td[2])
		var init_cd: float = float(td[3])

		var pylon := Node3D.new()
		pylon.name = "GunSponson_%d" % idx
		pylon.position = rel_p
		ship_rig.add_child(pylon)
		if idx < 2:
			# 下沉式装甲吊篮把舰腹炮塔托在船体侧下方，射界开阔无遮挡
			_add_part(h, pylon, ART.cyl(0.18 * s, 0.36 * s, 0.24 * s, 10), m_dark, Vector3(0.0, 0.18 * s, 0.0))
		else:
			_add_part(h, pylon, ART.cyl(0.26 * s, 0.12 * s, 0.30 * s, 12), m_dark, Vector3(0.0, -0.04 * s, 0.0))

		var tyaw := Node3D.new()
		tyaw.name = "CarrierTurretYaw_%d" % idx
		tyaw.position = rel_p
		tyaw.rotation.y = h_yaw
		ship_rig.add_child(tyaw)

		var trecoil := Node3D.new()
		trecoil.name = "CarrierTurretRecoil"
		tyaw.add_child(trecoil)
		_spawn_glb(h, trecoil, "citadel_sub_turret", ss, Vector3(0.0, 0.69 * ss, 0.08 * ss), Vector3(0.0, 180.0, 0.0))

		var m_gun := Marker3D.new()
		m_gun.name = "MuzzleGun"
		m_gun.position = Vector3(-0.66 * ss, 0.68 * ss, -0.85 * ss)
		trecoil.add_child(m_gun)
		var m_pod := Marker3D.new()
		m_pod.name = "MuzzlePod"
		m_pod.position = Vector3(0.72 * ss, 0.80 * ss, -0.58 * ss)
		trecoil.add_child(m_pod)

		turret_mounts.append({
			"role": "sub",
			"yaw_node": tyaw,
			"recoil_node": trecoil,
			"muzzles": [m_gun, m_pod],
			"home_yaw": h_yaw,
			"arc_half": arc_h,
			"turn_speed": 2.85,
			"cd": init_cd,
			"burst_left": 0,
			"burst_t": 0.0,
			"shots_n": idx,
		})

	# 太阳斜射偏置深黑舰体投影（在 2.5D 俯视镜头下清晰锚定母舰距地 ~5.6m 的高空悬停高度感）
	var sun_shadow := Node3D.new()
	sun_shadow.name = "CarrierSunShadow"
	sun_shadow.position = Vector3(3.8, 0.038, 3.0)
	h.add_child(sun_shadow)
	var sh_decal := ART.ground_vfx(sun_shadow, ART.blob_tex(), Color(0.015, 0.02, 0.03, 0.88), 4.5 * s, Vector3.ZERO, false, 0.40, false, 1)
	sh_decal.scale = Vector3(0.78, 1.0, 1.32)
	sh_decal.set_meta("no_flash", true)

	h.set_meta("turret_mounts", turret_mounts)
	h.set_meta("modular_glb", {
		"type": "carrier",
		"ship_rig": ship_rig,
		"thrusters": thrusters,
		"sun_shadow": sun_shadow,
		"awaken_t": 0.0,
	})


# ==============================================================================
# 3. 实时程序化动作与死亡坍塌演出
# ==============================================================================
static func _info(h):
	return h.get_meta("modular_glb") if (h != null and is_instance_valid(h) and h.has_meta("modular_glb")) else null


static func _sync_leg_rams(hip: Node3D, knee_lug: Node3D, brace_anchor: Vector3, rams: Array) -> void:
	# 计算膝下耳轴在 hip 局部空间中的实时坐标（注意节点尚未进树时不能用 global_transform，直接用局部矩阵复合）
	var lift_p: Node3D = knee_lug.get_parent() as Node3D
	if lift_p == null or not is_instance_valid(hip):
		return
	var lug_in_hip: Vector3 = lift_p.transform * knee_lug.position
	for rm in rams:
		var barrel: Node3D = rm.get("barrel")
		var rod: Node3D = rm.get("rod")
		var z_off: float = float(rm.get("z_off", 0.0))
		if not is_instance_valid(barrel) or not is_instance_valid(rod):
			continue
		var p_a: Vector3 = brace_anchor + Vector3(0.0, 0.0, z_off)
		var p_b: Vector3 = lug_in_hip + Vector3(0.0, 0.0, z_off)
		var dir_ab: Vector3 = p_b - p_a
		var dist: float = dir_ab.length()
		if dist < 0.05:
			continue
		var d_norm: Vector3 = dir_ab / dist
		barrel.transform = Transform3D(Basis.looking_at(d_norm, Vector3.UP), p_a)
		rod.transform = Transform3D(Basis.looking_at(-d_norm, Vector3.UP), p_b)


static func on_awaken(h) -> void:
	var info = _info(h)
	if info != null:
		info["awaken_t"] = 1.6


static func on_cancel_act(h) -> void:
	if h != null and is_instance_valid(h):
		h.hit_v += Vector3(-0.7, 0.0, 0.0)


static func animate(h, delta: float, mv: float) -> void:
	var info = _info(h)
	if info == null:
		return
	var mtype := str(info.get("type", ""))
	h.move_amt = move_toward(h.move_amt, clampf(mv, 0.0, 1.0), delta * 5.0)
	var sc: float = float(h.data.get("scale", 4.0))
	h.hit_v += (-h.hit_tilt * 150.0 - h.hit_v * 12.5) * delta
	h.hit_tilt += h.hit_v * delta
	info["awaken_t"] = maxf(0.0, float(info.get("awaken_t", 0.0)) - delta)

	# 旋转雷达等常驻转子
	for sp in h.spinners:
		if sp is Array and sp.size() >= 4 and is_instance_valid(sp[0]):
			var active_spin: bool = h.act != "" and h.act != "recover"
			var w: float = float(sp[3]) if active_spin else float(sp[2])
			(sp[0] as Node3D).rotate_object_local(sp[1], w * delta)

	# 复位防爆门初值，随后交由 boss.gd 按 core_vis 叠加开启角度
	for pl in h.plates:
		if is_instance_valid(pl):
			var sd: float = float(pl.get_meta("side", 1.0))
			pl.rotation.z = lerp(pl.rotation.z, 0.0, clampf(10.0 * delta, 0.0, 1.0))
			pl.rotation.y = lerp(pl.rotation.y, sd * h.core_vis * 0.85, clampf(10.0 * delta, 0.0, 1.0))

	if h.core_mi and is_instance_valid(h.core_mi) and h.core_mi.material_override is StandardMaterial3D:
		var em: StandardMaterial3D = h.core_mi.material_override
		var e0: float = 0.55 + sin(h.anim_t * 3.2) * 0.16 + (h.focus * 1.9 if h.act == "wind" else 0.0)
		em.emission_energy_multiplier = lerp(em.emission_energy_multiplier, e0, clampf(8.0 * delta, 0.0, 1.0))

	if mtype == "citadel":
		_animate_citadel(h, info, delta, sc)
	elif mtype == "carrier":
		_animate_carrier(h, info, delta, sc)


static func _animate_citadel(h, info: Dictionary, delta: float, sc: float) -> void:
	var cad := 4.4 if h.act != "charge" else 7.2
	h.anim_t += delta * (0.25 + h.move_amt * 1.15)
	var amt: float = h.move_amt
	var k := clampf(12.0 * delta, 0.0, 1.0)

	# 1) 六足双节蜘蛛三角步态驱动（股节抬举时膝节反向补偿，保持宽大驻锄底靴水平贴地）
	var legs_arr: Array = info.get("legs", [])
	for ld in legs_arr:
		var hip: Node3D = ld.get("hip")
		var lift: Node3D = ld.get("lift")
		var knee: Node3D = ld.get("knee")
		if not is_instance_valid(hip) or not is_instance_valid(lift):
			continue
		var sx: float = float(ld.get("side", 1.0))
		var base_yaw: float = float(ld.get("base_yaw", 0.0))
		var base_splay: float = float(ld.get("base_splay", 0.0))
		var base_knee_z: float = float(ld.get("base_knee_z", 0.0))
		var ph: float = h.anim_t * cad + float(ld.get("phase", 0.0))
		var s_ph := sin(ph)
		var c_ph := cos(ph)

		var want_yaw: float = base_yaw - s_ph * 0.22 * amt * sx
		var lift_ang: float = maxf(0.0, c_ph) * 0.22 * amt * (-sx)
		if h.act == "wind" and h._next_step() == "stomp":
			lift_ang += 0.20 * (-sx) * h.focus
		elif h.act == "stomp":
			lift_ang -= 0.10 * (-sx)
		hip.rotation.y = lerp_angle(hip.rotation.y, want_yaw, k)
		lift.rotation.z = lerp(lift.rotation.z, base_splay + lift_ang, k)
		if is_instance_valid(knee):
			knee.rotation.z = lerp(knee.rotation.z, base_knee_z - lift_ang * 0.85, k)
		var knee_lug: Node3D = ld.get("knee_lug")
		var rams: Array = ld.get("rams", [])
		if is_instance_valid(knee_lug) and not rams.is_empty():
			_sync_leg_rams(hip, knee_lug, ld.get("brace_anchor", Vector3.ZERO), rams)
		# 巨足落步扬尘与震地反馈：每次迈步由抬起转为踏实地面时在脚掌处激起环形沙尘
		var lifted_now: bool = h.awake and amt > 0.12 and c_ph > 0.18
		if bool(ld.get("was_lifted", false)) and not lifted_now and h.raid != null and is_instance_valid(h.raid.fx):
			var fp: Node3D = ld.get("foot_pad")
			if is_instance_valid(fp):
				var gp := Vector3(fp.global_position.x, 0.16, fp.global_position.z)
				ART.burst(h.raid.fx, gp, {"amount": 10, "life": 0.68, "size": 1.35, "tex": ART.dust_tex(), "additive": false, "flat": 0.88,
					"dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": 2.4, "vmax": 5.8, "gravity": Vector3(0, 0.3, 0), "damp": 5.0,
					"c0": Color(0.58, 0.50, 0.38, 0.0), "cmid": Color(0.58, 0.50, 0.38, 0.46), "cmid_pos": 0.18,
					"c1": Color(0.46, 0.40, 0.32, 0.0), "grow0": 0.55, "grow1": 1.85})
				h.raid.shake = maxf(h.raid.shake, 0.12)
		ld["was_lifted"] = lifted_now

	# 2) 巨型堡垒船体沉重起伏与前摇蓄势
	var hull_deck: Node3D = info.get("hull_deck")
	var base_y: float = float(info.get("hull_base_y", 1.60 * sc))
	if is_instance_valid(hull_deck):
		var dy := sin(h.anim_t * cad * 2.0) * 0.045 * amt * sc + sin(h.anim_t * 1.6) * 0.015 * sc
		var pitch := 0.0
		var roll := sin(h.anim_t * cad) * 0.025 * amt
		if not h.awake:
			dy -= 0.18 * sc
		elif float(info.get("awaken_t", 0.0)) > 0.0:
			pitch = -0.10
			dy += 0.06 * sc
		elif h.act == "wind":
			var nxt: String = h._next_step()
			if nxt == "stomp":
				dy += 0.22 * sc * h.focus
				pitch = -0.12 * h.focus
			elif nxt == "charge":
				dy -= 0.10 * sc * h.focus
				pitch = 0.10 * h.focus
			else:
				pitch = -0.06 * h.focus
		elif h.act == "stomp":
			dy -= 0.24 * sc
			pitch = 0.12
		elif h.act == "charge":
			pitch = 0.08
		hull_deck.position.y = lerp(hull_deck.position.y, base_y + dy, clampf(9.0 * delta, 0.0, 1.0))
		hull_deck.rotation.x = lerp(hull_deck.rotation.x, pitch, clampf(8.0 * delta, 0.0, 1.0)) + clampf(h.hit_tilt.x * 0.18, -0.12, 0.12)
		hull_deck.rotation.z = lerp(hull_deck.rotation.z, roll, clampf(8.0 * delta, 0.0, 1.0)) + clampf(h.hit_tilt.z * 0.18, -0.12, 0.12)

	if is_instance_valid(h.visual):
		h.visual.position.y = 0.0
		h.visual.rotation.x = 0.0


static func _animate_carrier(h, info: Dictionary, delta: float, _sc: float) -> void:
	h.anim_t += delta * (0.55 + h.move_amt * 0.85)
	var ship_rig: Node3D = info.get("ship_rig")
	var hover_h: float = maxf(float(h.hover), 5.2)

	# 1) 浮空母舰悬停高度与机动倾侧
	if is_instance_valid(h.visual):
		var sun_sh: Node3D = info.get("sun_shadow")
		if is_instance_valid(sun_sh):
			sun_sh.rotation.y = h.visual.rotation.y
			sun_sh.visible = not h.dying
		var want_y: float = hover_h + sin(h.anim_t * 1.55) * 0.28
		if not h.awake:
			want_y = hover_h - 0.8
		elif h.act == "wind" and h._next_step() == "stomp":
			want_y = hover_h + 0.85 * h.focus
		elif h.act == "stomp":
			want_y = hover_h - 1.15
		elif h.act == "charge":
			want_y = hover_h - 0.95
		h.visual.position.y = lerp(h.visual.position.y, want_y, clampf(5.5 * delta, 0.0, 1.0))

	if is_instance_valid(ship_rig):
		var local_vel := Vector3.ZERO
		if is_instance_valid(h.visual):
			local_vel = h.visual.global_transform.basis.inverse() * h.velocity
		var fwd_spd: float = clampf(-local_vel.z / maxf(float(h.data.get("speed", 4.2)), 1.0), -1.2, 1.6)
		var side_spd: float = clampf(local_vel.x / maxf(float(h.data.get("speed", 4.2)), 1.0), -1.2, 1.2)
		var want_pitch: float = -0.07 * fwd_spd + sin(h.anim_t * 1.2) * 0.025
		var want_roll: float = -0.11 * side_spd + cos(h.anim_t * 1.1) * 0.03
		if h.act == "wind" and h._next_step() == "slug":
			want_pitch = -0.16 * h.focus
		elif h.act == "charge":
			want_pitch = -0.18
		ship_rig.rotation.x = lerp(ship_rig.rotation.x, want_pitch, clampf(6.5 * delta, 0.0, 1.0)) + clampf(h.hit_tilt.x * 0.20, -0.14, 0.14)
		ship_rig.rotation.z = lerp(ship_rig.rotation.z, want_roll, clampf(6.5 * delta, 0.0, 1.0)) + clampf(h.hit_tilt.z * 0.20, -0.14, 0.14)

		# 2) 四具倾转涵道涡扇实时矢量偏转 + 尾焰脉动
		var thrusters: Array = info.get("thrusters", [])
		for td in thrusters:
			var pod: Node3D = td.get("pod")
			var flame: MeshInstance3D = td.get("flame")
			var sd: float = float(td.get("side", 1.0))
			if is_instance_valid(pod):
				var tilt_x: float = clampf(fwd_spd * 0.34, -0.35, 0.48) + sin(h.anim_t * 2.3 + sd) * 0.04
				if h.act == "charge":
					tilt_x = 0.55
				elif h.act == "stomp":
					tilt_x = -0.12
				pod.rotation.x = lerp(pod.rotation.x, tilt_x, clampf(8.0 * delta, 0.0, 1.0))
			if is_instance_valid(flame):
				var pulse: float = 0.92 + sin(h.anim_t * 19.0 + sd * 1.7) * 0.18 + h.move_amt * 0.28
				if h.act in ["charge", "stomp"]:
					pulse += 0.45
				flame.scale = Vector3(1.0, pulse, 1.0)


static func flash_turret_visual(h, tur: Dictionary) -> void:
	if h == null or not is_instance_valid(h) or bool(tur.get("destroyed", false)):
		return
	var rec: Node3D = tur.get("recoil_node")
	if not is_instance_valid(rec):
		return
	var now_t: float = float(Time.get_ticks_msec()) * 0.001
	if now_t - float(tur.get("last_flash_s", -9.0)) < 0.16:
		return
	tur["last_flash_s"] = now_t
	var ov: Material = ART.hit_flash_overlay(0.55)
	for n in rec.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null:
			mi.material_overlay = ov
	var tw: Tween = (h as Node).create_tween()
	tw.tween_interval(0.065)
	tw.tween_callback(func():
		if not is_instance_valid(rec):
			return
		for n in rec.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi != null:
				mi.material_overlay = null)


static func wreck_turret_visual(_h, tur: Dictionary) -> void:
	var rec: Node3D = tur.get("recoil_node")
	if not is_instance_valid(rec):
		return
	rec.rotation_degrees = Vector3(26.0, randf_range(-20.0, 20.0), randf_range(-24.0, 24.0))
	var charred: Material = ART.paint(Color(0.07, 0.07, 0.08), 0.32, 0.88, {"rust": 0.78, "wear": 0.70})
	for n in rec.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null:
			mi.material_overlay = null
			mi.material_override = charred
	ART.emitter(rec, Vector3(0.0, 0.55, 0.0), {"amount": 14, "life": 1.35, "size": 0.52, "tex": ART.smoke_tex(), "additive": false,
		"spread": 32.0, "vmin": 0.8, "vmax": 2.2, "gravity": Vector3(0.0, 2.4, 0.0), "damp": 1.6,
		"c0": Color(0.08, 0.08, 0.09, 0.0), "cmid": Color(0.10, 0.09, 0.09, 0.68), "cmid_pos": 0.18,
		"c1": Color(0.12, 0.12, 0.13, 0.0), "grow0": 0.55, "grow1": 2.2})


static func on_die(h, body: Node3D) -> bool:
	var info = _info(h)
	if info == null:
		return false
	var mtype := str(info.get("type", ""))
	var sc: float = float(h.data.get("scale", 4.0))
	var tw: Tween = (h as Node).create_tween().set_parallel(true)

	if mtype == "citadel":
		var hull_deck: Node3D = info.get("hull_deck")
		if is_instance_valid(hull_deck):
			tw.tween_property(hull_deck, "position:y", 0.52 * sc, 1.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(hull_deck, "rotation:z", randf_range(-0.18, 0.18), 1.5)
			tw.tween_property(hull_deck, "rotation:x", randf_range(0.08, 0.20), 1.5)
		var legs_arr: Array = info.get("legs", [])
		for ld in legs_arr:
			var lift: Node3D = ld.get("lift")
			var sx: float = float(ld.get("side", 1.0))
			if is_instance_valid(lift):
				tw.tween_property(lift, "rotation:z", -sx * 0.72, 1.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif mtype == "carrier":
		if is_instance_valid(h.visual):
			tw.tween_property(h.visual, "position:y", 0.42 * sc, 1.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		var ship_rig: Node3D = info.get("ship_rig")
		if is_instance_valid(ship_rig):
			tw.tween_property(ship_rig, "rotation:z", randf_range(-0.42, 0.42), 1.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(ship_rig, "rotation:x", randf_range(0.16, 0.30), 1.55)
		var thrusters: Array = info.get("thrusters", [])
		for td in thrusters:
			var flame: MeshInstance3D = td.get("flame")
			if is_instance_valid(flame):
				tw.tween_property(flame, "scale", Vector3.ZERO, 0.55)

	if h.has_meta("turret_mounts"):
		var mounts: Array = h.get_meta("turret_mounts")
		for tur in mounts:
			var rec: Node3D = tur.get("recoil_node")
			if is_instance_valid(rec):
				tw.tween_property(rec, "rotation:x", 0.22, 1.1)

	for m in body.find_children("*", "MeshInstance3D", true, false):
		var mat = m.material_override
		if mat is StandardMaterial3D and mat.emission_enabled:
			var dm: StandardMaterial3D = mat.duplicate()
			m.material_override = dm
			tw.tween_property(dm, "emission_energy_multiplier", 0.0, 1.8)
	if h.core_mi and is_instance_valid(h.core_mi):
		tw.tween_property(h.core_mi, "scale", Vector3.ZERO, 1.6)

	var fin_tw: Tween = (h as Node).create_tween()
	fin_tw.tween_interval(1.9)
	fin_tw.tween_callback(func():
		if not is_instance_valid(h):
			return
		for m in h.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D and not (m.mesh is PlaneMesh):
				m.visibility_range_end = 110.0
				m.visibility_range_end_margin = 6.0
		h._finalize_corpse())
	return true
