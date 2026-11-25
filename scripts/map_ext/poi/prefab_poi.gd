extends RefCounted
## 通用数据驱动预制体 POI 建造器：从 GameData.POIS[pid] 读取配置，
## 统一走 PrefabLib.place_at_ground 接入静态合批/阴影/流式管线，并配置实体碰撞、可达容器、守卫与氛围灯。

const K = preload("res://scripts/map_ext/poi_kit.gd")
const PrefabLib = preload("res://scripts/buildings/prefab_lib.gd")


static func _add_block(raid, pos: Vector3, sz: Vector3, rot_deg := 0.0, cyl := false) -> void:
	K.blocker(raid, pos, sz, rot_deg, cyl)
	var fp := sz
	if not cyl and absf(fmod(absf(rot_deg), 180.0) - 90.0) < 45.0:
		fp = Vector3(sz.z, sz.y, sz.x)
	raid.blocks.append(raid._rect_for(pos, fp))


static func _in_any_block(p: Vector3, placed_blocks: Array) -> bool:
	for b: Dictionary in placed_blocks:
		var bp: Vector3 = b["pos"]
		var bsz: Vector3 = b["sz"]
		var d: Vector3 = p - bp
		if bool(b["cyl"]):
			var rad: float = bsz.x * 0.5 + 1.4
			if d.x * d.x + d.z * d.z <= rad * rad:
				return true
		else:
			var rot_rad: float = -deg_to_rad(float(b["rot"]))
			var loc: Vector3 = d.rotated(Vector3.UP, rot_rad)
			if absf(loc.x) <= bsz.x * 0.5 + 1.2 and absf(loc.z) <= bsz.z * 0.5 + 1.2:
				return true
	return false


static func build(raid, c: Vector3, pid: String) -> void:
	var cfg: Dictionary = GameData.POIS.get(pid, {})
	var prefab_id: String = str(cfg.get("prefab", ""))
	if prefab_id == "":
		push_warning("[prefab_poi] missing prefab id for POI: %s" % pid)
		return
	var rot_deg: float = float(cfg.get("rot", 0.0))
	var rot_rad: float = deg_to_rad(rot_deg)
	var target_sz: Vector3 = cfg.get("sz", Vector3.ZERO) as Vector3
	var bsz: Vector3 = PrefabLib.base_size(prefab_id) if target_sz == Vector3.ZERO else target_sz
	var off_local: Vector3 = cfg.get("offset", Vector3(0.0, 0.0, -4.5)) as Vector3
	var origin: Vector3 = c + off_local.rotated(Vector3.UP, rot_rad)

	PrefabLib.place_at_ground(raid, raid.world, prefab_id, origin, rot_deg, target_sz)

	var placed_blocks: Array = []
	var custom_blocks: Array = cfg.get("blockers", [])
	if not custom_blocks.is_empty():
		for bd_v in custom_blocks:
			var bd: Dictionary = bd_v as Dictionary
			var bpos: Vector3 = c + (bd.get("pos", Vector3.ZERO) as Vector3).rotated(Vector3.UP, rot_rad)
			var bsz_b: Vector3 = bd.get("sz", Vector3(4.0, 4.0, 4.0)) as Vector3
			var brot: float = rot_deg + float(bd.get("rot", 0.0))
			var bcyl: bool = bool(bd.get("cyl", false))
			_add_block(raid, bpos, bsz_b, brot, bcyl)
			placed_blocks.append({"pos": bpos, "sz": bsz_b, "rot": brot, "cyl": bcyl})
	else:
		# 默认紧贴建筑主体但确保中心 c 留出 >=3.2m 开阔前场（保证 --maps 连通与可达）
		var bx: float = clampf(bsz.x * 0.68, 3.0, 14.0)
		var by: float = clampf(bsz.y * 0.75, 3.2, 12.0)
		var bz: float = clampf(bsz.z * 0.56, 3.0, 10.0)
		var b_off := off_local
		var front_z: float = b_off.z + bz * 0.5
		if front_z > 1.8:
			var shift: float = front_z - 1.8
			bz = maxf(2.6, bz - shift * 0.5)
			b_off.z -= shift * 0.5
		var bpos: Vector3 = c + b_off.rotated(Vector3.UP, rot_rad)
		var bsz_def := Vector3(bx, by, bz)
		_add_block(raid, bpos, bsz_def, rot_deg, false)
		placed_blocks.append({"pos": bpos, "sz": bsz_def, "rot": rot_deg, "cyl": false})

	var custom_crates: Array = cfg.get("crates", [])
	if not custom_crates.is_empty():
		for cd_v in custom_crates:
			var cd: Dictionary = cd_v as Dictionary
			var cpos: Vector3 = c + (cd.get("pos", Vector3.ZERO) as Vector3).rotated(Vector3.UP, rot_rad)
			var kind: String = str(cd.get("kind", "supply"))
			var cyaw: float = rot_deg + float(cd.get("yaw", 0.0))
			var items: Array = cd.get("items", [])
			if items.is_empty():
				K.crate(raid, cpos, kind, [], cyaw)
			else:
				K.fixed(raid, cpos, items, kind, cyaw)
	else:
		var flank_x: float = clampf(bsz.x * 0.5 + 1.8, 6.2, 12.2)
		var defaults := [
			{"off": Vector3(-3.8, 0.0, 5.2), "kind": "supply", "yaw": 0.0},
			{"off": Vector3(3.8, 0.0, 5.2), "kind": "military", "yaw": 0.0},
			{"off": Vector3(-flank_x, 0.0, 1.4), "kind": "tech", "yaw": -90.0},
			{"off": Vector3(flank_x, 0.0, 1.4), "kind": "safe", "yaw": 90.0},
		]
		for d_info: Dictionary in defaults:
			var lp: Vector3 = d_info["off"]
			var wp: Vector3 = c + lp.rotated(Vector3.UP, rot_rad)
			if _in_any_block(wp, placed_blocks):
				var push_dir := Vector3(lp.x, 0.0, maxf(lp.z, 2.0)).normalized()
				wp = c + (lp + push_dir * 3.0).rotated(Vector3.UP, rot_rad)
			K.crate(raid, wp, str(d_info["kind"]), [], rot_deg + float(d_info["yaw"]))

	var custom_lamps: Array = cfg.get("lamps", [])
	if not custom_lamps.is_empty():
		for ld_v in custom_lamps:
			var ld: Dictionary = ld_v as Dictionary
			var lpos: Vector3 = c + (ld.get("pos", Vector3.ZERO) as Vector3).rotated(Vector3.UP, rot_rad)
			var lcol: Color = ld.get("col", Color(1.0, 0.76, 0.44)) as Color
			K.lamp(raid, lpos, lcol)
	else:
		K.lamp(raid, c + Vector3(-9.4, 0.0, 6.2).rotated(Vector3.UP, rot_rad), Color(1.0, 0.76, 0.44))
		K.lamp(raid, c + Vector3(9.4, 0.0, -7.8).rotated(Vector3.UP, rot_rad), Color(0.68, 0.86, 1.0))

	var custom_guards: Array = cfg.get("guards", [])
	if not custom_guards.is_empty():
		for gd_v in custom_guards:
			var gd: Dictionary = gd_v as Dictionary
			var gpos: Vector3 = c + (gd.get("pos", Vector3.ZERO) as Vector3).rotated(Vector3.UP, rot_rad)
			var gkind: String = str(gd.get("kind", "beetle"))
			var grad: float = float(gd.get("r", 2.8))
			K.guard(raid, gpos, gkind, grad)
	else:
		K.guard(raid, c + Vector3(0.0, 0.0, 4.4).rotated(Vector3.UP, rot_rad), "beetle", 2.8)
		K.guard(raid, c + Vector3(5.2, 0.0, 3.2).rotated(Vector3.UP, rot_rad), "ling", 2.4)

	K.label(raid, c, str(cfg.get("name", "")), maxf(8.5, bsz.y * 0.7))
	var tag_rad: float = float(cfg.get("tag_rad", 17.0))
	K.tag_boxes(raid, c, pid, tag_rad)
