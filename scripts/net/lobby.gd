extends CanvasLayer
## Accessible from the hangar; all persistent status stays at the screen edge during raids.
const K = preload("res://scripts/hub_kit.gd")
const UI = preload("res://scripts/ui.gd")
var panel: PanelContainer
var name_edit: LineEdit
var address_edit: LineEdit
var port_edit: SpinBox
var password_edit: LineEdit
var roster: VBoxContainer
var map_select: OptionButton
var status: Label
var ready_button: Button
var launch_button: Button
var host_button: Button
var join_button: Button
var leave_button: Button
var _maps: Array = []
var _refreshing := false

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.015, 0.018, 0.025, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.theme = K.theme()
	panel.add_theme_stylebox_override("panel", K.px9("panel9", 16, 16, 16, 14))
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UI.plate_header(Loc.t("联机作战", "Co-op Sortie"), "2–4 PLAYERS", Loc.t("2–4 人小队", "SQUAD COMMS")))
	col.add_child(UI.hazard_strip(8))

	var hint := UI.label(Loc.t("每人驾驶自己的机甲，共享战场与容器，独立携行与撤离；全员准备后由房主出击。",
		"Each pilot brings their own mech into a shared zone with shared containers and independent extraction. Host launches when ready."), 12, K.CREAM_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	# 双栏主体：左栏连接参数 / 右栏小队花名册与状态日志
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	col.add_child(cols)

	var left_card := K.card(false, 12)
	left_card.custom_minimum_size = Vector2(360, 0)
	cols.add_child(left_card)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 8)
	left_card.add_child(lcol)
	lcol.add_child(K.section(Loc.t("链路设置", "Uplink Settings"), "UPLINK", "")[0])
	var def_name: String = Loc.t("驾驶员", "Pilot") if Net.display_name in ["驾驶员", "Pilot"] else Net.display_name
	name_edit = _field(lcol, Loc.t("驾驶员", "Pilot"), def_name)
	name_edit.max_length = 20
	address_edit = _field(lcol, Loc.t("房主地址", "Host IP"), Net.address)
	address_edit.placeholder_text = Loc.t("局域网 IP / 公网 IP / 域名", "LAN IP / Public IP / Domain")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	lcol.add_child(row)
	var label := UI.label(Loc.t("网络端口", "UDP Port"), 12, K.CREAM_DIM)
	label.custom_minimum_size.x = 84
	row.add_child(label)
	port_edit = SpinBox.new()
	port_edit.min_value = 1024
	port_edit.max_value = 65535
	port_edit.value = Net.port
	port_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(port_edit)
	password_edit = _field(lcol, Loc.t("房间口令", "Password"), "")
	password_edit.secret = true
	password_edit.max_length = 64
	password_edit.placeholder_text = Loc.t("可留空", "Optional")
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	lcol.add_child(buttons)
	host_button = _button(buttons, Loc.t("创建房间", "Host"), _host)
	join_button = _button(buttons, Loc.t("加入房间", "Join"), _join)
	leave_button = _button(buttons, Loc.t("离开", "Leave"), func(): Net.leave())
	leave_button.custom_minimum_size = Vector2(76, 34)
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	lcol.add_child(map_row)
	var map_label := UI.label(Loc.t("行动战区", "Sector"), 12, K.CREAM_DIM)
	map_label.custom_minimum_size.x = 84
	map_row.add_child(map_label)
	map_select = OptionButton.new()
	map_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_row.add_child(map_select)
	for id in GameData.MAPS:
		if bool(GameData.map_data(id).get("hidden", false)):
			continue
		_maps.append(id)
		map_select.add_item(str(GameData.map_data(id).get("name", id)))
	map_select.item_selected.connect(func(i):
		if not _refreshing: Net.select_map(_maps[i]))

	var right_card := PanelContainer.new()
	right_card.add_theme_stylebox_override("panel", K.px9("inset9", 8, 8, 12, 10))
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right_card)
	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 8)
	right_card.add_child(rcol)
	rcol.add_child(K.section(Loc.t("小队编制", "Squad Roster"), "ROSTER", "2–4")[0])
	roster = VBoxContainer.new()
	roster.add_theme_constant_override("separation", 6)
	roster.custom_minimum_size.y = 148
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rcol.add_child(roster)

	var st_box := PanelContainer.new()
	st_box.add_theme_stylebox_override("panel", K.px9("card9", 8, 8, 10, 8))
	rcol.add_child(st_box)
	status = UI.label("", 12, K.CREAM)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(360, 56)
	st_box.add_child(status)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	var help := UI.label(Loc.t("跨区时全员需在同出口集合；行动中途掉线视为弃机。",
		"All squadmates must gather at the same border gate to transit; disconnects mid-raid count as MIA."), 12, K.CREAM_DIM)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(help)
	ready_button = _button(bottom, Loc.t("准备", "Ready"), func(): Net.ready_up(not Net.players.get(Net.local_id(), {}).get("ready", false)))
	launch_button = K.primary(Loc.t("全员空投", "Launch Sortie"), 34)
	launch_button.custom_minimum_size = Vector2(138, 34)
	launch_button.pressed.connect(func(): Net.launch())
	bottom.add_child(launch_button)
	_button(bottom, Loc.t("返回整备", "Back"), _close)

	Net.changed.connect(refresh)
	Net.notice.connect(func(t): status.text = t)
	refresh()

func _close() -> void:
	if Net.state == "lobby": Net.ready_up(false)
	queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _field(parent: Node, text: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := UI.label(text, 12, K.CREAM_DIM)
	label.custom_minimum_size.x = 84
	row.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit

func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(104, 34)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func show_panel() -> void:
	visible = true
	refresh()

func _host() -> void:
	if Net.host(name_edit.text, int(port_edit.value), password_edit.text) != OK:
		status.text = Net.last_error

func _join() -> void:
	if Net.join(name_edit.text, address_edit.text, int(port_edit.value), password_edit.text) != OK:
		status.text = Net.last_error

func refresh() -> void:
	_refreshing = true
	var active := Net.active()
	host_button.disabled = active
	join_button.disabled = active
	leave_button.disabled = not active
	name_edit.editable = not active
	address_edit.editable = not active
	password_edit.editable = not active
	port_edit.editable = not active
	map_select.disabled = not Net.is_host() or Net.state != "lobby"
	map_select.select(maxi(0, _maps.find(Net.room_map)))
	ready_button.disabled = Net.state != "lobby"
	ready_button.text = Loc.t("取消准备", "Unready") if Net.players.get(Net.local_id(), {}).get("ready", false) else Loc.t("准备", "Ready")
	launch_button.disabled = not Net.can_launch()
	for n in roster.get_children():
		roster.remove_child(n)
		n.queue_free()
	var ids: Array = Net.players.keys()
	ids.sort()
	if ids.is_empty():
		var empty := UI.label(Loc.t("尚未连接任何小队节点", "No squad nodes connected"), 12, K.CREAM_DIM)
		roster.add_child(empty)
	for id in ids:
		var is_ready := bool(Net.players[id].ready)
		var card := K.card(is_ready, 8)
		roster.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var role_tag := K.tag(Loc.t("★ 房主", "★ Host") if id == 1 else Loc.t("队员", "Member"), id == 1)
		row.add_child(role_tag)
		var lab := UI.label(str(Net.players[id].name), 12, K.CREAM)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		row.add_child(UI.label(Loc.t("已准备", "Ready") if is_ready else Loc.t("整备中", "Staging"), 12, UI.GOOD if is_ready else K.CREAM_DIM))
		if Net.is_host() and id != 1 and Net.state == "lobby":
			var kb := _button(row, Loc.t("移出", "Kick"), func(): Net.kick(id))
			kb.custom_minimum_size = Vector2(56, 26)
	match Net.state:
		"offline": status.text = Net.last_error if Net.last_error != "" else Loc.t("先在机库装备完整机甲并装好货舱，再创建或加入房间。", "Equip a complete mech and cargo in the hangar before hosting or joining.")
		"connecting": status.text = Loc.t("正在连接 %s:%d…（可点击离开取消）", "Connecting to %s:%d... (click Leave to cancel)") % [Net.address, Net.port]
		"lobby":
			var ips: PackedStringArray = []
			for ip in IP.get_local_addresses():
				if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."): ips.append(ip)
			status.text = ((Loc.t("房主地址：%s  ·  端口 %d\n", "Host: %s  ·  UDP %d\n") % [", ".join(ips), Net.port]) if Net.is_host() else Loc.t("已连接房主。\n", "Connected to host.\n")) + Loc.t("至少两人，全员准备后出击。返回整备会取消准备。", "Requires 2+ pilots ready to deploy. Returning to hangar clears ready.")
		"results": status.text = Loc.t("等待其他队员确认结算并返回机库…", "Waiting for squadmates to confirm results...")
		_: status.text = Loc.t("正在同步小队状态…", "Syncing squad state...")
	_refreshing = false
