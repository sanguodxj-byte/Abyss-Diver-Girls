extends RefCounted
## 物品像素图标：v0.7.1 起优先取手绘像素图集 assets/ui/px/atlas16.png（tools/gen_tarkov_px.py 逐像素绘制，16×16 美术像素，
## 界面按 2 倍 / 3 倍最近邻放大，与角色像素头像同一像素尺度）。按物品 id 逐个绘制；没有专属图的物品依次按
## 武器类型 → 底盘类型 → 背部技能 → 模块槽位 → 物品类别回退到同类图标，最后是「?」木箱。
## 图集缺失时（例如删掉了 assets/ui/px）退回旧的运行时程序图标（下方 _make），扩展数据的新物品因此总有图标。

const S := 16
const PX = preload("res://scripts/px_atlas.gd")
const ATLAS_PATH := "res://assets/ui/px/atlas16.png"

## 旧版程序图标（图集缺失时回退）：物品 id → [形状, 主色]
const MAP := {
	"can_food": ["can", Color(0.72, 0.36, 0.22)],
	"biscuit": ["biscuit", Color(0.82, 0.66, 0.38)],
	"water_tab": ["pill", Color(0.45, 0.72, 0.9)],
	"coffee": ["bean", Color(0.5, 0.32, 0.2)],
	"circuit": ["board", Color(0.24, 0.55, 0.3)],
	"wire": ["coil", Color(0.85, 0.5, 0.24)],
	"bolts": ["bolt", Color(0.66, 0.68, 0.7)],
	"hdd": ["hdd", Color(0.42, 0.45, 0.5)],
	"toy": ["toy", Color(0.85, 0.3, 0.3)],
	"chitin": ["shell", Color(0.48, 0.42, 0.52)],
	"bug_crystal": ["gem", Color(0.55, 0.85, 0.95)],
	"fuel_cell": ["cell", Color(0.9, 0.66, 0.18)],
	"repair_kit": ["medkit", Color(0.78, 0.22, 0.2)],
	"beacon": ["antenna", Color(0.95, 0.55, 0.15)],
	"credit_s": ["chip", Color(0.35, 0.6, 0.85)],
	"credit_l": ["chip", Color(0.6, 0.42, 0.9)],
	"gold": ["goldbar", Color(0.95, 0.76, 0.24)],
	"sonic_decoy": ["speaker", Color(0.4, 0.62, 0.55)],
	"extract_flare": ["canister", Color(0.35, 0.8, 0.45)],
	"energy_rod": ["rod", Color(0.95, 0.85, 0.3)],
	"coolant_pack": ["canister", Color(0.4, 0.75, 0.95)],
	"extract_barrier": ["shield", Color(0.4, 0.7, 0.95)],
	"surge_cell": ["cell", Color(0.7, 0.45, 0.95)],
}
## 模块槽位 → 形状
const SLOT_SHAPE := {"core": "core", "legs": "legs", "arm": "arm", "back": "back", "gen": "gen"}
const SLOT_COLOR := {"core": Color(0.62, 0.64, 0.58), "legs": Color(0.55, 0.58, 0.52), "arm": Color(0.5, 0.52, 0.55),
	"back": Color(0.56, 0.6, 0.46), "gen": Color(0.88, 0.62, 0.2)}
const CAT_SHAPE := {"food": ["can", Color(0.7, 0.5, 0.3)], "misc": ["bolt", Color(0.6, 0.62, 0.64)],
	"use": ["cell", Color(0.85, 0.6, 0.2)], "money": ["chip", Color(0.4, 0.6, 0.85)]}
## 飞空艇设施 / 技能卡片图标
const FAC := {"hangar": ["core", Color(0.95, 0.66, 0.16)], "workshop": ["wrench", Color(0.7, 0.72, 0.74)],
	"infirmary": ["medkit", Color(0.8, 0.25, 0.22)], "lab": ["flask", Color(0.45, 0.85, 0.7)], "kitchen": ["can", Color(0.85, 0.5, 0.25)],
	"research": ["flask", Color(0.55, 0.75, 0.95)], "ability": ["gen", Color(0.95, 0.7, 0.2)], "talent": ["star", Color(0.95, 0.8, 0.35)],
	"training": ["star", Color(0.6, 0.85, 0.95)], "meal": ["can", Color(0.9, 0.55, 0.25)]}

static var _cache := {}
static var _atlas: Texture2D
static var _atlas_tried := false


static func atlas() -> Texture2D:
	if not _atlas_tried:
		_atlas_tried = true
		if ResourceLoader.exists(ATLAS_PATH):
			_atlas = load(ATLAS_PATH)
	return _atlas


## 图集里一格（16×16）；没有这一格返回 null
static func atlas_icon(key: String) -> Texture2D:
	if not PX.ICONS.has(key) or atlas() == null:
		return null
	var ck := "@px_" + key
	if _cache.has(ck):
		return _cache[ck]
	var at := AtlasTexture.new()
	at.atlas = atlas()
	var cell: Vector2i = PX.ICONS[key]
	at.region = Rect2(cell.x * S, cell.y * S, S, S)
	at.filter_clip = true
	_cache[ck] = at
	return at


## 物品 id → 图集格名（含回退链）
static func sprite_key(id: String) -> String:
	var gd = Engine.get_main_loop().root.get_node_or_null("GameData")
	var base := id
	if gd != null and gd.has_method("base_id"):
		base = gd.base_id(id)
	if PX.ICONS.has(base):
		return base
	if gd != null and gd.is_module(id):
		var m: Dictionary = gd.module(id)
		var w := str(m.get("weapon", ""))
		if w != "" and PX.WEAPON.has(w):
			return PX.WEAPON[w]
		var slot := str(m.get("slot", ""))
		if slot == "legs" and PX.LEGS.has(str(m.get("type", ""))):
			return PX.LEGS[str(m.get("type", ""))]
		if slot == "back" and PX.BACK.has(str(m.get("ability", ""))):
			return PX.BACK[str(m.get("ability", ""))]
		if PX.SLOT.has(slot):
			return PX.SLOT[slot]
	elif gd != null:
		var cat := str(gd.item(id).get("cat", ""))
		if PX.CAT.has(cat):
			return PX.CAT[cat]
	return "unknown"


static func icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var t := atlas_icon(sprite_key(id))
	if t == null:
		t = _legacy_icon(id)
	_cache[id] = t
	return t


## 设施 / 技能卡图标
static func facility_icon(id: String) -> Texture2D:
	var t := atlas_icon(str(PX.FAC.get(id, "")))
	return t if t != null else _legacy_facility_icon(id)


## 界面图标（底部导航 nav_*、地图标记等，直接按图集格名取）
static func ui_icon(key: String) -> Texture2D:
	return atlas_icon(key)


static func _legacy_icon(id: String) -> Texture2D:
	if _cache.has("@l" + id):
		return _cache["@l" + id]
	var shape := "box"
	var col := Color(0.6, 0.6, 0.6)
	var gd = Engine.get_main_loop().root.get_node_or_null("GameData")
	var base := id
	if gd != null:
		base = gd.base_id(id) if gd.has_method("base_id") else id
	if MAP.has(base):
		shape = MAP[base][0]
		col = MAP[base][1]
	elif gd != null and gd.is_module(id):
		var slot := str(gd.module(id).get("slot", "core"))
		shape = SLOT_SHAPE.get(slot, "box")
		col = SLOT_COLOR.get(slot, col)
	elif gd != null:
		var cat := str(gd.item(id).get("cat", "misc"))
		if CAT_SHAPE.has(cat):
			shape = CAT_SHAPE[cat][0]
			col = CAT_SHAPE[cat][1]
	var t := _make(shape, col)
	_cache["@l" + id] = t
	return t


static func _legacy_facility_icon(id: String) -> Texture2D:
	var key := "@lfac_" + id
	if _cache.has(key):
		return _cache[key]
	var d: Array = FAC.get(id, ["box", Color(0.7, 0.7, 0.7)])
	var t := _make(str(d[0]), d[1])
	_cache[key] = t
	return t


# ---------------------------------------------------------------- 绘制
static func _make(shape: String, c: Color) -> ImageTexture:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hi := c.lightened(0.35)
	var lo := c.darkened(0.35)
	var dk := c.darkened(0.6)
	match shape:
		"core":
			_r(img, 2, 4, 12, 3, c)
			_r(img, 4, 7, 8, 6, c)
			_r(img, 6, 5, 4, 2, Color(0.55, 0.85, 1.0))
			_r(img, 5, 9, 6, 1, dk)
			_r(img, 5, 11, 6, 1, dk)
			_r(img, 2, 4, 12, 1, hi)
			_r(img, 7, 2, 2, 2, lo)
		"legs":
			_r(img, 4, 2, 8, 3, c)
			_r(img, 4, 5, 3, 7, c)
			_r(img, 9, 5, 3, 7, c)
			_r(img, 3, 12, 5, 2, lo)
			_r(img, 8, 12, 5, 2, lo)
			_r(img, 4, 2, 8, 1, hi)
			_r(img, 4, 8, 3, 1, dk)
			_r(img, 9, 8, 3, 1, dk)
		"arm":
			_r(img, 1, 6, 14, 2, lo)
			_r(img, 3, 5, 7, 5, c)
			_r(img, 5, 10, 2, 3, lo)
			_r(img, 13, 5, 2, 4, dk)
			_r(img, 3, 5, 7, 1, hi)
			_r(img, 4, 7, 4, 1, dk)
		"back":
			_r(img, 3, 3, 10, 11, c)
			_r(img, 4, 2, 8, 2, lo)
			_r(img, 5, 8, 6, 4, lo)
			_r(img, 3, 3, 10, 1, hi)
			_r(img, 5, 6, 6, 1, dk)
		"gen":
			_r(img, 4, 3, 8, 11, c)
			_r(img, 6, 2, 4, 1, lo)
			_r(img, 4, 3, 2, 11, hi)
			_r(img, 8, 5, 2, 3, Color(1, 1, 0.85))
			_r(img, 7, 8, 2, 1, Color(1, 1, 0.85))
			_r(img, 6, 9, 2, 3, Color(1, 1, 0.85))
		"can":
			_r(img, 4, 4, 8, 9, c)
			_r(img, 4, 3, 8, 2, Color(0.75, 0.76, 0.78))
			_r(img, 4, 7, 8, 3, Color(0.92, 0.88, 0.72))
			_r(img, 4, 12, 8, 1, Color(0.6, 0.6, 0.62))
			_r(img, 4, 4, 1, 9, hi)
		"biscuit":
			_r(img, 2, 5, 12, 6, c)
			_r(img, 2, 5, 12, 1, hi)
			for x in [4, 7, 10]:
				_r(img, x, 7, 1, 1, lo)
				_r(img, x + 1, 9, 1, 1, lo)
		"pill":
			_r(img, 3, 4, 10, 8, Color(0.78, 0.8, 0.82))
			for p in [Vector2i(4, 5), Vector2i(8, 5), Vector2i(4, 8), Vector2i(8, 8)]:
				_r(img, p.x, p.y, 3, 2, c)
				_r(img, p.x, p.y, 1, 1, hi)
		"bean":
			_r(img, 4, 4, 8, 9, c)
			_r(img, 5, 3, 6, 1, c)
			_r(img, 5, 13, 6, 1, c)
			_r(img, 7, 4, 1, 9, dk)
			_r(img, 5, 5, 1, 3, hi)
		"board":
			_r(img, 2, 3, 12, 10, c)
			_r(img, 5, 5, 4, 4, Color(0.15, 0.16, 0.18))
			_r(img, 10, 6, 2, 2, Color(0.15, 0.16, 0.18))
			_r(img, 3, 10, 9, 1, Color(0.9, 0.75, 0.3))
			_r(img, 9, 4, 1, 6, Color(0.9, 0.75, 0.3))
			_r(img, 2, 3, 12, 1, hi)
		"coil":
			_ring(img, 8, 8, 6, 3, c)
			_ring(img, 8, 8, 5, 4, hi)
			_r(img, 12, 11, 3, 1, lo)
		"bolt":
			_r(img, 4, 2, 8, 4, c)
			_r(img, 6, 6, 4, 8, lo)
			for y in [7, 9, 11]:
				_r(img, 6, y, 4, 1, dk)
			_r(img, 4, 2, 8, 1, hi)
		"hdd":
			_r(img, 2, 3, 12, 10, c)
			_ring(img, 7, 8, 4, 0, Color(0.7, 0.72, 0.75))
			_r(img, 7, 8, 1, 1, dk)
			_r(img, 11, 10, 2, 2, Color(0.4, 1.0, 0.6))
			_r(img, 2, 3, 12, 1, hi)
		"toy":
			_ring(img, 7, 9, 5, 0, c)
			_r(img, 5, 7, 2, 2, Color(1, 1, 1))
			_r(img, 12, 4, 1, 4, Color(0.75, 0.76, 0.78))
			_r(img, 11, 3, 3, 1, Color(0.75, 0.76, 0.78))
			_r(img, 4, 6, 2, 1, hi)
		"shell":
			for y in range(3, 13):
				var hw := int(round(sqrt(max(0.0, 36.0 - pow((y - 9) * 0.9, 2)))))
				_r(img, 8 - hw, y, hw * 2, 1, c)
			_r(img, 7, 3, 2, 10, lo)
			_r(img, 4, 7, 2, 1, hi)
			_r(img, 10, 7, 2, 1, hi)
		"gem":
			for y in range(2, 14):
				var hw := (y - 2) if y < 7 else (13 - y)
				hw = clampi(hw, 0, 5)
				_r(img, 8 - hw, y, hw * 2, 1, c)
			_r(img, 6, 4, 2, 4, hi)
			_r(img, 9, 8, 2, 3, lo)
		"cell":
			_r(img, 5, 3, 6, 11, c)
			_r(img, 6, 2, 4, 1, Color(0.75, 0.76, 0.78))
			_r(img, 5, 6, 6, 1, dk)
			_r(img, 5, 10, 6, 1, dk)
			_r(img, 5, 3, 1, 11, hi)
		"medkit":
			_r(img, 2, 5, 12, 8, Color(0.85, 0.85, 0.82))
			_r(img, 6, 3, 4, 2, Color(0.5, 0.5, 0.5))
			_r(img, 7, 6, 2, 6, c)
			_r(img, 5, 8, 6, 2, c)
		"antenna":
			_r(img, 5, 10, 6, 4, c)
			_r(img, 7, 4, 2, 6, lo)
			_r(img, 7, 3, 2, 1, Color(1, 0.4, 0.3))
			_r(img, 3, 4, 1, 3, hi)
			_r(img, 12, 4, 1, 3, hi)
			_r(img, 1, 3, 1, 5, hi)
			_r(img, 14, 3, 1, 5, hi)
		"chip":
			_r(img, 2, 4, 12, 8, c)
			_r(img, 4, 6, 4, 4, Color(0.95, 0.8, 0.35))
			_r(img, 9, 7, 3, 1, hi)
			_r(img, 9, 9, 3, 1, hi)
			_r(img, 2, 4, 12, 1, hi)
		"goldbar":
			for i in 6:
				_r(img, 2 + i / 2, 11 - i, 12 - i, 1, c if i > 0 else lo)
			_r(img, 5, 7, 6, 1, hi)
		"speaker":
			_r(img, 3, 3, 10, 11, c)
			_ring(img, 8, 9, 3, 1, dk)
			_r(img, 7, 4, 2, 2, dk)
			_r(img, 3, 3, 10, 1, hi)
		"canister":
			_r(img, 5, 4, 6, 10, c)
			_r(img, 6, 2, 4, 2, Color(0.75, 0.76, 0.78))
			_r(img, 5, 8, 6, 2, Color(0.15, 0.16, 0.18))
			_r(img, 5, 4, 1, 10, hi)
		"rod":
			for i in 10:
				_r(img, 3 + i, 12 - i, 2, 2, c)
			_r(img, 2, 12, 3, 3, lo)
			_r(img, 12, 1, 3, 3, Color(1, 1, 0.8))
		"shield":
			for y in range(2, 14):
				var hw := 6 if y < 9 else 6 - (y - 8)
				_r(img, 8 - hw, y, hw * 2, 1, c)
			_r(img, 7, 3, 2, 9, hi)
		"wrench":
			for i in 9:
				_r(img, 3 + i, 12 - i, 2, 2, c)
			_r(img, 10, 2, 4, 2, c)
			_r(img, 12, 4, 2, 2, c)
			_r(img, 2, 11, 3, 3, lo)
		"flask":
			_r(img, 6, 2, 4, 5, Color(0.75, 0.8, 0.82))
			for y in range(7, 14):
				var hw := mini(2 + (y - 7), 6)
				_r(img, 8 - hw, y, hw * 2, 1, c)
			_r(img, 5, 10, 2, 2, hi)
		"star":
			_r(img, 7, 2, 2, 12, c)
			_r(img, 2, 6, 12, 2, c)
			_r(img, 4, 4, 8, 6, c)
			_r(img, 5, 11, 2, 2, c)
			_r(img, 9, 11, 2, 2, c)
			_r(img, 7, 5, 2, 2, hi)
		_:
			_r(img, 3, 3, 10, 10, c)
			_r(img, 3, 3, 10, 1, hi)
	_outline(img)
	return ImageTexture.create_from_image(img)


static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(0, y), mini(S, y + h)):
		for xx in range(maxi(0, x), mini(S, x + w)):
			img.set_pixel(xx, yy, c)


static func _ring(img: Image, cx: int, cy: int, r: int, inner: int, c: Color) -> void:
	for y in S:
		for x in S:
			var d := Vector2(x - cx + 0.5, y - cy + 0.5).length()
			if d <= r + 0.2 and d > inner + 0.2:
				img.set_pixel(x, y, c)


## 透明像素若与不透明像素四邻相接，涂成描边色
static func _outline(img: Image) -> void:
	var src := img.duplicate()
	var oc := Color(0.03, 0.03, 0.035, 1)
	for y in S:
		for x in S:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < S and p.y < S and src.get_pixel(p.x, p.y).a > 0.0:
					img.set_pixel(x, y, oc)
					break
