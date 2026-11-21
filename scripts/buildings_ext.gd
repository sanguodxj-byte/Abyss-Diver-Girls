extends RefCounted
## 扩展写实重工与城市建筑样式库（13 种新增建筑类型 + 远景 MultiMesh 轮廓同步）
## 全部接入 scripts/buildings/prefab_lib.gd 精修硬表面建筑资产（压顶女儿墙、真内凹窗洞、出屋面机房、高勒脚散水与多面体雷达罩），
## 统一走 raid._bldg_body / _imesh，既走 48m 分块合批与 MultiMesh，又支持地标清场自动剥离。
## 严格限制任何外挑构件 <= 0.85m，配合 world_city 全局 4.15m OBB 间距，实现 100% 零穿模重叠。

const A = preload("res://scripts/art.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func build(raid, kind: String, p: Vector3, sz: Vector3, rot: float) -> bool:
	match kind:
		"civic_block":
			_place_ext(raid, "bldg_civic_block", p, sz, rot, _rand_masonry(raid, [Color(0.68, 0.65, 0.59), Color(0.62, 0.60, 0.55), Color(0.72, 0.69, 0.63)], 0.0))
		"midrise_office":
			_place_ext(raid, "bldg_midrise_office", p, sz, rot, _rand_masonry(raid, [Color(0.62, 0.56, 0.48), Color(0.55, 0.36, 0.28), Color(0.66, 0.63, 0.57), Color(0.50, 0.44, 0.39)], 0.52))
		"rowblock":
			_place_ext(raid, "bldg_rowblock", p, sz, rot, null)
		"arcade_shop":
			_place_ext(raid, "bldg_arcade_shop", p, sz, rot, _rand_masonry(raid, [Color(0.54, 0.49, 0.42), Color(0.49, 0.42, 0.37), Color(0.46, 0.47, 0.43)], 0.5))
		"stepped_tower":
			_place_ext(raid, "bldg_stepped_tower", p, sz, rot, _rand_masonry(raid, [Color(0.47, 0.48, 0.49), Color(0.51, 0.48, 0.43), Color(0.43, 0.45, 0.47)], 0.0))
		"courtyard_blk":
			_place_ext(raid, "bldg_courtyard_blk", p, sz, rot, _rand_masonry(raid, [Color(0.50, 0.39, 0.33), Color(0.47, 0.45, 0.41), Color(0.44, 0.34, 0.29)], 0.72))
		"substation":
			_place_ext(raid, "bldg_substation", p, sz, rot, null, raid.rng.randf() < 0.55, "HV-110KV")
		"terrace":
			_place_ext(raid, "bldg_terrace", p, sz, rot, _rand_masonry(raid, [Color(0.48, 0.35, 0.29), Color(0.52, 0.45, 0.39), Color(0.44, 0.38, 0.34)], 0.78))
		"duplex":
			_place_ext(raid, "poi_duplex_coldstore", p, sz, rot, _rand_masonry(raid, [Color(0.53, 0.47, 0.41), Color(0.48, 0.38, 0.32), Color(0.50, 0.49, 0.45)], 0.55))
		"tenement":
			_place_ext(raid, "bldg_tenement", p, sz, rot, _rand_masonry(raid, [Color(0.46, 0.44, 0.40), Color(0.44, 0.37, 0.33), Color(0.40, 0.42, 0.41)], 0.55))
		"foundry":
			_place_ext(raid, "bldg_foundry", p, sz, rot, _rand_masonry(raid, [Color(0.41, 0.28, 0.22), Color(0.35, 0.32, 0.29), Color(0.32, 0.35, 0.37)], 0.68), raid.rng.randf() < 0.45)
		"chem_plant":
			_place_ext(raid, "bldg_chem_plant", p, sz, rot, null, raid.rng.randf() < 0.45)
		"cold_store":
			var cc: Color = [Color(0.50, 0.55, 0.57), Color(0.45, 0.50, 0.54), Color(0.54, 0.54, 0.51)][raid.rng.randi() % 3]
			_place_ext(raid, "poi_duplex_coldstore", p, sz, rot, A.corrugated(cc, 0.34, 0.34), raid.rng.randf() < 0.55, "COLD-04")
		"loco_shed":
			var use_br: bool = raid.rng.randi() % 2 == 0
			var lc := Color(0.42, 0.29, 0.22) if use_br else Color(0.34, 0.36, 0.38)
			var lmat: Material = A.brick(lc) if use_br else A.corrugated(lc, 0.48, 0.32)
			_place_ext(raid, "bldg_loco_shed", p, sz, rot, lmat, raid.rng.randf() < 0.45)
		"command_bunker":
			_place_ext(raid, "bldg_command_bunker", p, sz, rot, null, true, "CMD-HQ")
		"silo_barn":
			_place_ext(raid, "poi_silo_radar", p, sz, rot, null, raid.rng.randf() < 0.45)
		_:
			return false
	return true


static func _rand_masonry(raid, cols: Array, brick_prob: float) -> Material:
	var c: Color = cols[raid.rng.randi() % cols.size()]
	return A.brick(c) if raid.rng.randf() < brick_prob else A.concrete(c, true)


static func _place_ext(raid, prefab_id: String, p: Vector3, sz: Vector3, rot: float, tint_mat: Material = null, with_stencil := false, stencil_text := "") -> void:
	var safe_sz := PrefabLib.clamp_building_height(prefab_id, sz)
	var sb: StaticBody3D = raid._bldg_body(safe_sz, p + Vector3(0, safe_sz.y * 0.5, 0))
	sb.rotation.y = -rot
	PrefabLib.place_on_body(raid, sb, prefab_id, safe_sz, true, tint_mat, -999.0, with_stencil, stencil_text)


## 远景外围城区建筑 MultiMesh 形态映射（使战区边界内外的 23 种建筑轮廓自然贯通）
static func add_backdrop(kind: String, bs: Basis, p0: Vector3, sx: float, sz: float, h: float, brng: RandomNumberGenerator,
		hull_con0: Array, hull_con1: Array, hull_brick: Array, hull_wh: Array, hull_mil: Array,
		trim_dark: Array, roof_dark: Array, win_dark: Array, gable_slate: Array, gable_rust: Array,
		barrel_wh: Array, saw_shed: Array, tank_cyls: Array) -> bool:
	match kind:
		"civic_block":
			hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx, h * 0.90, sz)), p0 + Vector3(0.0, h * 0.45, 0.0)))
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx * 0.58, h * 0.14, sz * 0.48)), p0 + Vector3(0.0, h * 0.95, 0.0)))
			win_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.92, h * 0.58, sz + 0.08)), p0 + Vector3(0.0, h * 0.50, 0.0)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.92, 0.25, sz * 0.92)), p0 + Vector3(0.0, h * 0.91, 0.0)))
		"midrise_office":
			var target_hull := hull_brick if brng.randf() < 0.45 else hull_con0
			target_hull.append(Transform3D(bs.scaled_local(Vector3(sx, h * 0.92, sz)), p0 + Vector3(0.0, h * 0.46, 0.0)))
			win_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.90, h * 0.64, sz + 0.08)), p0 + Vector3(0.0, h * 0.52, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.22, 1.9, sz * 0.24)), p0 + bs * Vector3(-sx * 0.24, h * 0.96, -sz * 0.12)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.15, 2.4, 1.15)), p0 + bs * Vector3(sx * 0.24, h * 0.92 + 1.4, -sz * 0.12)))
		"rowblock":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			win_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.90, h * 0.52, sz + 0.08)), p0 + Vector3(0.0, h * 0.52, 0.0)))
			roof_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.94, 0.22, sz * 0.92)), p0 + Vector3(0.0, h + 0.08, 0.0)))
		"terrace", "duplex":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			win_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.82, 0.72, sz + 0.08)), p0 + Vector3(0.0, h * 0.55, 0.0)))
			var rh := minf(sx, sz) * 0.30
			var r_bs := bs * (Basis(Vector3.UP, PI * 0.5) if kind == "terrace" else Basis.IDENTITY)
			var r_sc := Vector3(sz + 0.36, rh, sx + 0.24) if kind == "terrace" else Vector3(sx + 0.36, rh, sz + 0.32)
			(gable_slate if brng.randf() < 0.55 else gable_rust).append(Transform3D(r_bs.scaled_local(r_sc), p0 + Vector3(0.0, h, 0.0)))
		"stepped_tower":
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx, h * 0.38, sz)), p0 + Vector3(0.0, h * 0.19, 0.0)))
			hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx * 0.78, h * 0.62, sz * 0.78)), p0 + Vector3(0.0, h * 0.69, 0.0)))
			win_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.80, h * 0.42, sz * 0.80)), p0 + Vector3(0.0, h * 0.66, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.36, 1.5, sz * 0.36)), p0 + Vector3(0.0, h + 0.75, 0.0)))
		"courtyard_blk":
			var wd := clampf(minf(sx, sz) * 0.30, 2.0, 3.2)
			for sd_z in [-1.0, 1.0]:
				hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, wd)), p0 + bs * Vector3(0.0, h * 0.5, sd_z * (sz * 0.5 - wd * 0.5))))
			for sd_x in [-1.0, 1.0]:
				hull_brick.append(Transform3D(bs.scaled_local(Vector3(wd, h, maxf(1.0, sz - wd * 2.02))), p0 + bs * Vector3(sd_x * (sx * 0.5 - wd * 0.5), h * 0.5, 0.0)))
		"foundry":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			var s_bs := bs * Basis(Vector3.UP, PI * 0.5)
			for s_i in 2:
				var oz := (float(s_i) - 0.5) * sz * 0.48
				saw_shed.append(Transform3D(s_bs.scaled_local(Vector3(sz * 0.50, 1.05, sx + 0.20)), p0 + bs * Vector3(0.0, h, oz)))
		"chem_plant":
			hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx * 0.56, h * 0.84, sz * 0.86)), p0 + bs * Vector3(-sx * 0.20, h * 0.42, 0.0)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.5, h + 2.4, 1.5)), p0 + bs * Vector3(sx * 0.24, (h + 2.4) * 0.5, -sz * 0.18)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.3, h + 1.2, 1.3)), p0 + bs * Vector3(sx * 0.24, (h + 1.2) * 0.5, sz * 0.20)))
		"cold_store", "loco_shed":
			hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.46, 1.0, sz * 0.72)), p0 + Vector3(0.0, h + 0.5, 0.0)))
		"command_bunker", "substation":
			hull_mil.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.32, 0.48, sz + 0.32)), p0 + Vector3(0.0, h + 0.20, 0.0)))
		"silo_barn":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx * 0.64, h * 0.85, sz * 0.88)), p0 + bs * Vector3(-sx * 0.18, h * 0.42, 0.0)))
			var g_bs := bs
			gable_rust.append(Transform3D(g_bs.scaled_local(Vector3(sx * 0.66, 1.8, sz * 0.90)), p0 + bs * Vector3(-sx * 0.18, h * 0.85, 0.0)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.6, h + 2.2, 2.6)), p0 + bs * Vector3(sx * 0.28, (h + 2.2) * 0.5, -sz * 0.20)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.6, h + 2.2, 2.6)), p0 + bs * Vector3(sx * 0.28, (h + 2.2) * 0.5, sz * 0.20)))
		_:
			return false
	return true
