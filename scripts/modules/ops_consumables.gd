extends Node3D
## 行动内的新消耗品按键：3 = 声波诱饵信标，4 = 撤离引导烟幕，5 = 高能电池棒，
## 6 = 冷却剂罐，7 = 撤离屏障，8 = 超频电芯。
## 只在机甲可操作、没有开大地图 / 搜刮面板、不在空投过程里时响应；
## 物品效果写在各自的 item_*.gd 里，这里只负责把按键接到 mech.use_item。

const BINDINGS := {"use_decoy": "sonic_decoy", "use_flare": "extract_flare", "use_battery": "energy_rod",
	"use_coolant": "coolant_pack", "use_barrier": "extract_barrier", "use_surge": "surge_cell"}

var raid


func setup(r) -> void:
	raid = r


func _process(_delta: float) -> void:
	if raid == null or raid.ended or raid.dropping:
		return
	if raid.mech == null or raid.mech.dead or raid.mech.input_locked:
		return
	if raid.hud != null and raid.hud.map_open():
		return
	if raid.open_box != null:
		return
	for a in BINDINGS:
		if Input.is_action_just_pressed(a):
			raid.mech.use_item(BINDINGS[a])
