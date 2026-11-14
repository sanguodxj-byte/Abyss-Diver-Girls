extends RefCounted
## High-res baked 3D item icon loader & HD2 flat tactical vector icon synthesizer.
## Items & mech modules load baked multi-cell 3D renders from res://assets/icons/items/<id>.png.
## Facility, navigation, and active skill glyphs are synthesized as crisp anti-aliased 48x48 icons.

const S := 48
const BAKED_DIR := "res://assets/icons/items"

const _HD2_Y := Color(0.81, 0.51, 0.19, 1.0)
const _HD2_W := Color(0.86, 0.88, 0.88, 1.0)
const _HD2_C := Color(0.58, 0.73, 0.78, 1.0)
const _HD2_G := Color(0.48, 0.76, 0.52, 1.0)

static var _cache: Dictionary = {}


static func _gamedata() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("GameData")
	return null


static func _base_id(id: String) -> String:
	var gd := _gamedata()
	if gd != null:
		return str(gd.call("base_id", id))
	var hash_pos := id.find("#")
	return id.substr(0, hash_pos) if hash_pos >= 0 else id


static func atlas() -> Texture2D:
	return null


static func sprite_key(id: String) -> String:
	return _base_id(id)


static func atlas_icon(key: String) -> Texture2D:
	if key == "":
		return null
	return ui_icon(key)


## Returns baked 3D PNG icon for any item or module ID.
static func icon(id: String) -> Texture2D:
	var base := _base_id(id)
	var ck := "@item_" + base
	if _cache.has(ck):
		var cached: Texture2D = _cache[ck]
		return cached
	var path := "%s/%s.png" % [BAKED_DIR, base]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res as Texture2D
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = _vector_icon("unknown")
	_cache[ck] = tex
	return tex


## Returns crisp 48x48 flat tactical vector icon for airship facilities.
static func facility_icon(id: String) -> Texture2D:
	var ck := "@fac_" + id
	if _cache.has(ck):
		var cached: Texture2D = _cache[ck]
		return cached
	var tex: Texture2D = _vector_icon("fac_" + id)
	_cache[ck] = tex
	return tex


## Resolves UI icons: returns baked 3D icon if key is an item ID (e.g. Growth tracks),
## otherwise returns a crisp 48x48 anti-aliased HD2 tactical glyph.
static func ui_icon(key: String) -> Texture2D:
	if key == "":
		return null
	var ck := "@ui_" + key
	if _cache.has(ck):
		var cached: Texture2D = _cache[ck]
		return cached
	var gd := _gamedata()
	var base := _base_id(key)
	if gd != null:
		var items_dict: Variant = gd.get("ITEMS")
		if items_dict is Dictionary and (items_dict as Dictionary).has(base):
			var it_tex := icon(base)
			_cache[ck] = it_tex
			return it_tex
	var tex: Texture2D = _vector_icon(key)
	_cache[ck] = tex
	return tex


# ==============================================================================
# Analytic 48x48 SDF vector glyph renderer (mipmapped, smooth anti-aliasing)
# ==============================================================================

static func _sd_box(p: Vector2, c: Vector2, half: Vector2) -> float:
	var d := (p - c).abs() - half
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)


static func _sd_seg(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var denom := maxf(ba.dot(ba), 1e-6)
	var h := clampf(pa.dot(ba) / denom, 0.0, 1.0)
	return (pa - ba * h).length() - r


static func _sd_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var e0 := b - a
	var e1 := c - b
	var e2 := a - c
	var v0 := p - a
	var v1 := p - b
	var v2 := p - c
	var pq0 := v0 - e0 * clampf(v0.dot(e0) / maxf(e0.dot(e0), 1e-6), 0.0, 1.0)
	var pq1 := v1 - e1 * clampf(v1.dot(e1) / maxf(e1.dot(e1), 1e-6), 0.0, 1.0)
	var pq2 := v2 - e2 * clampf(v2.dot(e2) / maxf(e2.dot(e2), 1e-6), 0.0, 1.0)
	var s := signf(e0.x * e2.y - e0.y * e2.x)
	var d0 := Vector2(pq0.dot(pq0), s * (v0.x * e0.y - v0.y * e0.x))
	var d1 := Vector2(pq1.dot(pq1), s * (v1.x * e1.y - v1.y * e1.x))
	var d2 := Vector2(pq2.dot(pq2), s * (v2.x * e2.y - v2.y * e2.x))
	var dm := Vector2(minf(d0.x, minf(d1.x, d2.x)), minf(d0.y, minf(d1.y, d2.y)))
	return -sqrt(dm.x) * signf(dm.y)


static func _sd_ring(p: Vector2, c: Vector2, r: float, thick: float) -> float:
	return absf((p - c).length() - r) - thick


static func _sd_hex(p: Vector2, c: Vector2, r: float) -> float:
	var q := (p - c).abs()
	return maxf(q.x * 0.8660254 + q.y * 0.5, q.y) - r


static func _blend(dst: Color, col: Color, sd: float) -> Color:
	var cov := clampf(0.65 - sd, 0.0, 1.0)
	if cov <= 0.001:
		return dst
	var src_a := col.a * cov
	var out_a := src_a + dst.a * (1.0 - src_a)
	if out_a <= 0.0001:
		return Color(0, 0, 0, 0)
	var out_rgb := (Vector3(col.r, col.g, col.b) * src_a + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - src_a)) / out_a
	return Color(out_rgb.x, out_rgb.y, out_rgb.z, out_a)


static func _vector_icon(kind: String) -> Texture2D:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ctr := Vector2(24.0, 24.0)
	var key := kind.to_lower()

	for y in S:
		for x in S:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var col := Color(0, 0, 0, 0)

			match key:
				"nav_maintenance", "fac_hangar":
					# Tactical wrench + gear plate
					var plate := maxf(_sd_hex(p, ctr, 18.0), -_sd_hex(p, ctr, 14.5))
					col = _blend(col, Color(_HD2_W.r, _HD2_W.g, _HD2_W.b, 0.35), plate)
					var shaft := _sd_seg(p, Vector2(14, 34), Vector2(31, 17), 3.0)
					var head := _sd_box(Vector2((p.x - 32.5) * 0.707 - (p.y - 15.5) * 0.707, (p.x - 32.5) * 0.707 + (p.y - 15.5) * 0.707), Vector2.ZERO, Vector2(6.5, 5.5))
					var jaw := _sd_box(Vector2((p.x - 35.5) * 0.707 - (p.y - 12.5) * 0.707, (p.x - 35.5) * 0.707 + (p.y - 12.5) * 0.707), Vector2.ZERO, Vector2(3.6, 2.4))
					var pommel := (p - Vector2(13.0, 35.0)).length() - 4.4
					col = _blend(col, _HD2_Y, minf(shaft, minf(pommel, maxf(head, -jaw))))

				"fac_workshop":
					# Crossed wrench + hex nut
					var nut := maxf(_sd_hex(p, ctr, 14.5), -((p - ctr).length() - 5.5))
					var bar1 := _sd_seg(p, Vector2(11, 37), Vector2(37, 11), 2.4)
					var bar2 := _sd_seg(p, Vector2(11, 11), Vector2(22, 22), 2.4)
					col = _blend(col, Color(_HD2_W.r, _HD2_W.g, _HD2_W.b, 0.36), nut)
					col = _blend(col, _HD2_Y, minf(bar1, bar2))

				"nav_trade":
					# Exchange double chevrons + credit diamond
					var a_top := _sd_seg(p, Vector2(10, 17), Vector2(34, 17), 2.3)
					var a_head := _sd_tri(p, Vector2(39, 17), Vector2(29, 11), Vector2(29, 23))
					var b_bot := _sd_seg(p, Vector2(14, 31), Vector2(38, 31), 2.3)
					var b_head := _sd_tri(p, Vector2(9, 31), Vector2(19, 25), Vector2(19, 37))
					col = _blend(col, _HD2_Y, minf(a_top, a_head))
					col = _blend(col, _HD2_W, minf(b_bot, b_head))

				"nav_deploy":
					# HD2 Hellpod drop reticle + triple downward chevron
					var ring := _sd_ring(p, ctr, 18.0, 1.5)
					var pod := _sd_tri(p, Vector2(24, 35), Vector2(15, 19), Vector2(33, 19))
					var fin := _sd_box(p, Vector2(24, 14.5), Vector2(7.0, 2.5))
					var core := _sd_tri(p, Vector2(24, 29), Vector2(20, 22), Vector2(28, 22))
					col = _blend(col, _HD2_W, ring)
					col = _blend(col, _HD2_Y, maxf(minf(pod, fin), -core))

				"nav_skills", "fac_talent", "fac_training", "fac_star", "fac_star_b":
					# Sharp 4-point tactical chevron star + ring
					var is_b := key.ends_with("_b")
					var tint := _HD2_C if is_b else _HD2_Y
					var ring := _sd_ring(p, ctr, 18.5, 1.2)
					var s1 := _sd_tri(p, Vector2(24, 7), Vector2(28.5, 24), Vector2(19.5, 24))
					var s2 := _sd_tri(p, Vector2(24, 41), Vector2(19.5, 24), Vector2(28.5, 24))
					var s3 := _sd_tri(p, Vector2(7, 24), Vector2(24, 19.5), Vector2(24, 28.5))
					var s4 := _sd_tri(p, Vector2(41, 24), Vector2(24, 28.5), Vector2(24, 19.5))
					col = _blend(col, Color(_HD2_W.r, _HD2_W.g, _HD2_W.b, 0.55), ring)
					col = _blend(col, tint, minf(minf(s1, s2), minf(s3, s4)))

				"nav_stash":
					# 2x2 tactical cargo grid emblem
					var outer := maxf(_sd_box(p, ctr, Vector2(17, 17)), -_sd_box(p, ctr, Vector2(14.5, 14.5)))
					var c1 := _sd_box(p, Vector2(17.5, 17.5), Vector2(4.8, 4.8))
					var c2 := _sd_box(p, Vector2(30.5, 17.5), Vector2(4.8, 4.8))
					var c3 := _sd_box(p, Vector2(17.5, 30.5), Vector2(4.8, 4.8))
					var c4 := _sd_box(p, Vector2(30.5, 30.5), Vector2(4.8, 4.8))
					col = _blend(col, _HD2_W, outer)
					col = _blend(col, _HD2_Y, minf(c1, c4))
					col = _blend(col, Color(_HD2_W.r, _HD2_W.g, _HD2_W.b, 0.78), minf(c2, c3))

				"nav_codex":
					# Open tactical dossier plates
					var left_p := _sd_box(p, Vector2(16.5, 24.0), Vector2(6.5, 13.0))
					var right_p := _sd_box(p, Vector2(31.5, 24.0), Vector2(6.5, 13.0))
					var spine := _sd_box(p, ctr, Vector2(1.5, 14.0))
					var l1 := _sd_box(p, Vector2(31.5, 18.0), Vector2(4.0, 1.3))
					var l2 := _sd_box(p, Vector2(31.5, 23.0), Vector2(4.0, 1.3))
					var l3 := _sd_box(p, Vector2(31.5, 28.0), Vector2(3.0, 1.3))
					col = _blend(col, _HD2_W, minf(left_p, spine))
					col = _blend(col, _HD2_Y, maxf(right_p, -minf(l1, minf(l2, l3))))

				"fac_infirmary":
					# Medical hex badge + crisp cross
					var shield := _sd_hex(p, ctr, 18.0)
					var hole := _sd_hex(p, ctr, 14.5)
					var cross_v := _sd_box(p, ctr, Vector2(3.2, 9.5))
					var cross_h := _sd_box(p, ctr, Vector2(9.5, 3.2))
					col = _blend(col, _HD2_W, maxf(shield, -hole))
					col = _blend(col, _HD2_G, minf(cross_v, cross_h))

				"fac_lab", "fac_research", "fac_flask", "fac_flask_b":
					# Crisp flat Erlenmeyer flask
					var is_b := key.ends_with("_b") or key.ends_with("research")
					var liq_c := _HD2_Y if is_b else _HD2_C
					var neck := _sd_box(p, Vector2(24, 14), Vector2(3.6, 5.5))
					var lip := _sd_box(p, Vector2(24, 9.5), Vector2(5.5, 1.5))
					var body := _sd_tri(p, Vector2(24, 16), Vector2(10, 38), Vector2(38, 38))
					var outer := minf(lip, minf(neck, body))
					var inner_body := _sd_tri(p, Vector2(24, 21), Vector2(14, 35.5), Vector2(34, 35.5))
					var fluid := maxf(inner_body, 28.5 - p.y)
					col = _blend(col, _HD2_W, maxf(outer, -maxf(inner_body, 28.0 - p.y)))
					col = _blend(col, liq_c, fluid)

				"fac_kitchen", "fac_meal":
					# Ration tin / supply canister
					var can := _sd_box(p, ctr, Vector2(12.0, 14.0))
					var band := _sd_box(p, Vector2(24.0, 24.0), Vector2(12.5, 4.0))
					var lid := _sd_box(p, Vector2(24.0, 9.5), Vector2(13.5, 2.0))
					col = _blend(col, _HD2_W, minf(can, lid))
					col = _blend(col, _HD2_Y, band)

				"fac_ability", "dash":
					# Triple forward tactical boost chevrons (>>>)
					var d := 1e6
					for off: float in [-10.0, 0.0, 10.0]:
						var s1 := _sd_seg(p, Vector2(18.0 + off, 12.0), Vector2(27.0 + off, 24.0), 2.3)
						var s2 := _sd_seg(p, Vector2(27.0 + off, 24.0), Vector2(18.0 + off, 36.0), 2.3)
						d = minf(d, minf(s1, s2))
					col = _blend(col, _HD2_W, d)

				"ram":
					# Armored ram plow wedge
					var w1 := _sd_tri(p, Vector2(40, 24), Vector2(14, 10), Vector2(18, 24))
					var w2 := _sd_tri(p, Vector2(40, 24), Vector2(18, 24), Vector2(14, 38))
					var trail := _sd_seg(p, Vector2(8, 17), Vector2(16, 17), 2.0)
					var trail2 := _sd_seg(p, Vector2(8, 31), Vector2(16, 31), 2.0)
					col = _blend(col, _HD2_W, minf(minf(w1, w2), minf(trail, trail2)))

				"leap":
					# Parabolic thruster leap arc + upward arrowhead
					var arc := maxf(_sd_ring(p, Vector2(24, 34), 16.0, 2.2), p.y - 31.0)
					var tip := _sd_tri(p, Vector2(41, 29), Vector2(31, 22), Vector2(36, 33))
					var pad := _sd_box(p, Vector2(24, 38), Vector2(14, 1.8))
					col = _blend(col, _HD2_W, minf(pad, minf(arc, tip)))

				"quake":
					# Concentric ground impact shockwaves
					var r1 := _sd_ring(p, ctr, 18.0, 2.0)
					var r2 := _sd_ring(p, ctr, 11.0, 2.0)
					var dot := (p - ctr).length() - 4.5
					col = _blend(col, _HD2_W, minf(r1, minf(r2, dot)))

				"missile":
					# Salvo trio of angled warheads
					var d := 1e6
					for off: Vector2 in [Vector2(-9, 2), Vector2(0, -4), Vector2(9, 2)]:
						var bp: Vector2 = Vector2(24, 26) + off
						var fin := _sd_box(p, bp + Vector2(0, 7), Vector2(4.2, 2.0))
						var shaft := _sd_box(p, bp + Vector2(0, 1), Vector2(2.4, 7.0))
						var nose := _sd_tri(p, bp + Vector2(0, -10), bp + Vector2(-2.6, -5), bp + Vector2(2.6, -5))
						d = minf(d, minf(fin, minf(shaft, nose)))
					col = _blend(col, _HD2_W, d)

				"shield":
					# Hexagonal deflective shield barrier
					var hex_o := _sd_hex(p, ctr, 18.5)
					var hex_i := _sd_hex(p, ctr, 14.2)
					var cross_v := _sd_box(p, ctr, Vector2(2.2, 8.5))
					var cross_h := _sd_box(p, ctr, Vector2(8.5, 2.2))
					col = _blend(col, _HD2_W, minf(maxf(hex_o, -hex_i), minf(cross_v, cross_h)))

				"lock":
					# Shackle + padlock body
					var shackle := maxf(_sd_ring(p, Vector2(24, 18), 7.5, 2.2), p.y - 22.0)
					var body := _sd_box(p, Vector2(24, 30), Vector2(11.0, 9.0))
					var slit := _sd_box(p, Vector2(24, 30), Vector2(1.8, 4.0))
					col = _blend(col, _HD2_W, minf(shackle, maxf(body, -slit)))

				"reload":
					# Circular reload arrows
					var ring := _sd_ring(p, ctr, 14.0, 2.2)
					var cut1 := _sd_box(p, Vector2(36, 14), Vector2(6, 5))
					var cut2 := _sd_box(p, Vector2(12, 34), Vector2(6, 5))
					var a1 := _sd_tri(p, Vector2(37, 23), Vector2(30, 17), Vector2(41, 16))
					col = _blend(col, _HD2_Y, minf(maxf(ring, -minf(cut1, cut2)), a1))

				_:
					# Unknown / tactical emblem hexagon
					var ring := maxf(_sd_hex(p, ctr, 16.5), -_sd_hex(p, ctr, 13.0))
					var dot := (p - ctr).length() - 3.5
					col = _blend(col, _HD2_Y, minf(ring, dot))

			img.set_pixel(x, y, col)

	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
