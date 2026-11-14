extends RefCounted
## Deterministic 2D top-to-bottom, left-to-right grid bin-packer for backpack & storage grids.


static func pack(sizes: Array, cols: int, max_rows: int = 0) -> Dictionary:
	var c_cols: int = maxi(1, cols)
	var occ: Array = []
	var placements: Array = []
	var rows_used: int = 0
	var ok: bool = true

	for i: int in sizes.size():
		var raw_sz: Variant = sizes[i]
		var sz: Vector2i = raw_sz if raw_sz is Vector2i else Vector2i(1, 1)
		var gw: int = clampi(sz.x, 1, c_cols)
		var gh: int = maxi(1, sz.y)
		var placed: Rect2i = Rect2i(-1, -1, gw, gh)
		var gy: int = 0
		var found: bool = false

		while true:
			if max_rows > 0 and gy + gh > max_rows:
				break
			while occ.size() < gy + gh:
				var row_buf: PackedByteArray = PackedByteArray()
				row_buf.resize(c_cols)
				row_buf.fill(0)
				occ.append(row_buf)
			for gx: int in range(0, c_cols - gw + 1):
				var fits: bool = true
				for dy: int in gh:
					var rbuf: PackedByteArray = occ[gy + dy]
					for dx: int in gw:
						if rbuf[gx + dx] != 0:
							fits = false
							break
					if not fits:
						break
				if fits:
					for dy: int in gh:
						var rbuf: PackedByteArray = occ[gy + dy]
						for dx: int in gw:
							rbuf[gx + dx] = 1
						occ[gy + dy] = rbuf
					placed = Rect2i(gx, gy, gw, gh)
					rows_used = maxi(rows_used, gy + gh)
					found = true
					break
			if found:
				break
			gy += 1

		if not found:
			ok = false
		placements.append(placed)

	var total_rows: int = maxi(max_rows, rows_used)
	var cell_to_idx: PackedInt32Array = PackedInt32Array()
	cell_to_idx.resize(c_cols * maxi(1, total_rows))
	cell_to_idx.fill(-1)

	for i: int in placements.size():
		var rc: Rect2i = placements[i]
		if rc.position.x < 0 or rc.position.y < 0:
			continue
		for dy: int in rc.size.y:
			var ry: int = rc.position.y + dy
			if ry < 0 or ry >= total_rows:
				continue
			for dx: int in rc.size.x:
				var rx: int = rc.position.x + dx
				if rx >= 0 and rx < c_cols:
					cell_to_idx[ry * c_cols + rx] = i

	return {
		"ok": ok,
		"placements": placements,
		"rows_used": rows_used,
		"total_rows": total_rows,
		"cell_to_idx": cell_to_idx,
	}


static func _try_order(sizes: Array, order: PackedInt32Array, cols: int, max_rows: int) -> bool:
	var reordered: Array = []
	reordered.resize(order.size())
	for k: int in order.size():
		reordered[k] = sizes[order[k]]
	var res: Dictionary = pack(reordered, cols, max_rows)
	return bool(res.get("ok", false))


static func find_packing_order(sizes: Array, cols: int, max_rows: int) -> PackedInt32Array:
	var n: int = sizes.size()
	var c_cols: int = maxi(1, cols)
	var identity: PackedInt32Array = PackedInt32Array()
	identity.resize(n)
	for i: int in n:
		identity[i] = i
	if n == 0:
		return identity

	var total_cells: int = 0
	for i: int in n:
		var raw_sz: Variant = sizes[i]
		var sz: Vector2i = raw_sz if raw_sz is Vector2i else Vector2i(1, 1)
		total_cells += clampi(sz.x, 1, c_cols) * maxi(1, sz.y)
	if max_rows > 0 and total_cells > c_cols * max_rows:
		return PackedInt32Array()

	var first_res: Dictionary = pack(sizes, c_cols, max_rows)
	if bool(first_res.get("ok", false)):
		return identity

	var idx_by_area: Array = []
	for i: int in n:
		idx_by_area.append(i)
	idx_by_area.sort_custom(func(a: int, b: int) -> bool:
		var sa: Vector2i = sizes[a]
		var sb: Vector2i = sizes[b]
		var gwa: int = clampi(sa.x, 1, c_cols)
		var gha: int = maxi(1, sa.y)
		var gwb: int = clampi(sb.x, 1, c_cols)
		var ghb: int = maxi(1, sb.y)
		var aa: int = gwa * gha
		var ab: int = gwb * ghb
		if aa != ab:
			return aa > ab
		var ma: int = maxi(gwa, gha)
		var mb: int = maxi(gwb, ghb)
		if ma != mb:
			return ma > mb
		if gha != ghb:
			return gha > ghb
		if gwa != gwb:
			return gwa > gwb
		return a < b
	)
	var ord1: PackedInt32Array = PackedInt32Array(idx_by_area)
	if _try_order(sizes, ord1, c_cols, max_rows):
		return ord1

	var idx_by_w: Array = []
	for i: int in n:
		idx_by_w.append(i)
	idx_by_w.sort_custom(func(a: int, b: int) -> bool:
		var sa: Vector2i = sizes[a]
		var sb: Vector2i = sizes[b]
		var gwa: int = clampi(sa.x, 1, c_cols)
		var gha: int = maxi(1, sa.y)
		var gwb: int = clampi(sb.x, 1, c_cols)
		var ghb: int = maxi(1, sb.y)
		if gwa != gwb:
			return gwa > gwb
		if gha != ghb:
			return gha > ghb
		return a < b
	)
	var ord2: PackedInt32Array = PackedInt32Array(idx_by_w)
	if _try_order(sizes, ord2, c_cols, max_rows):
		return ord2

	return PackedInt32Array()


static func can_fit(sizes: Array, cols: int, max_rows: int) -> bool:
	return sizes.is_empty() or not find_packing_order(sizes, cols, max_rows).is_empty()
