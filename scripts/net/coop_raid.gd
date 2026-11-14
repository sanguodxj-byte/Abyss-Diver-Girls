extends Node
## Host owns simulation. Clients only submit intent and render authoritative state.
const Protocol = preload("res://scripts/net/protocol.gd")
const PLAYER_FIELDS := ["hp", "max_hp", "energy", "max_energy", "emergency", "ability_cd", "dash_cd", "dash_time", "shield_time", "guard_t", "stealth_t", "overdrive_t", "dead", "parts", "ammo", "mag", "reload_t", "arm_cd"]
const BUG_FIELDS := ["hp", "state", "act", "act_t", "spawn_t", "dying", "move_amt", "flash_t", "awake", "phase", "core_open", "focus", "underground", "fuse_lit"]
const SHARED_EVENTS := ["enemy_killed", "nest_destroyed", "boss_appeared", "boss_phase_changed", "boss_defeated", "transport_called", "transport_landed", "transport_departed"]
var raid
var units := {} # peer -> mech
var contexts := {} # peer -> {box, progress, target, status, result}
var entities := {} # id -> node
var descriptors := {}
var _next_entity := 1
var _serial := 0
var _received := -1
var _send_t := 0.0
var _input_t := 0.0
var _seq := 0
var _inputs := {}
var _personal_cache := {}
var _entity_state := {}
var _reusable := {}
var applying := false
var _gate_t := 0.0
var _gate := ""
var _world_state := {}
var _hud_proxy
var _status: Label
var _geometry := 0

class RemoteHud extends RefCounted:
	var owner
	var peer := 1
	func msg(t: String) -> void: Net.tell(peer, t)
	func refresh_loot() -> void: pass
	func open_loot(_box) -> void: pass
	func close_loot() -> void: pass
	func set_prompt(_t: String) -> void: pass
	func on_loadout_changed() -> void: pass
	func hurt() -> void: pass
	func inv_open() -> bool: return false
	func map_open() -> bool: return false
	func is_touch_busy() -> bool: return false

func setup(r, config: Dictionary) -> void:
	raid = r
	Net.controller = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_proxy = RemoteHud.new()
	_hud_proxy.owner = self
	var local := Net.local_id()
	units[local] = raid.mech
	var ids: Array = Net.roster.keys()
	ids.sort()
	var drop: Vector3 = raid.mech.position
	drop.y = 0.3
	var zones: Array = []
	for zone in raid.extracts: zones.append([zone.position, zone.title])
	_geometry = hash([raid.map_id, raid.blocks, zones])
	applying = true
	for id in ids:
		var profile: Dictionary = Net.roster[id]
		var saved: Dictionary = config.get("transit", {}).get("players", {}).get(id, {})
		if id != local:
			var m = load("res://scripts/mech.gd").new()
			m.raid = raid
			m.net_peer = id
			m.name = "Player_%d" % id
			raid.add_child(m)
			m.setup(saved.get("loadout", profile.loadout), saved.get("cargo", profile.cargo))
			units[id] = m
		var m = units[id]
		var slot_idx := ids.find(id)
		m.position = _spawn_position(drop, slot_idx)
		m.net_peer = id
		m.add_to_group("coop_players")
		var ring_col: Color = m.PLAYER_RING_COLORS[slot_idx % m.PLAYER_RING_COLORS.size()]
		m.set_player_ring_color(ring_col)
		m.died.connect(func(reason): finish_player(id, false, reason))
		m.message.connect(func(t): Net.tell(id, t) if Net.is_host() else null)
		contexts[id] = {"box": null, "progress": 0.0, "target": null, "status": "行动中", "result": {}, "start": profile.cargo.duplicate()}
		_label_player(m, str(profile.name), id, ring_col)
		if not saved.is_empty():
			_apply_player(m, saved, true)
			contexts[id].start = saved.get("start", contexts[id].start)
			contexts[id].status = saved.get("status", "行动中")
			contexts[id].result = saved.get("result", {})
			m.net_done = not contexts[id].result.is_empty()
		if Net.is_client():
			m.collision_layer = 0
			m.collision_mask = 0
	applying = false
	if not config.get("transit", {}).is_empty():
		raid.time = config.transit.time
		raid.kills = config.transit.kills
		raid.visited_maps = config.transit.visited
		raid.start_cargo = contexts[local].start.duplicate()
	raid.world_link.set_process(false)
	if Net.is_client():
		# Geometry is generated identically; simulation nodes are recreated from server descriptors.
		for group in ["bugs", "npc_mechs"]:
			for n in get_tree().get_nodes_in_group(group):
				if raid.is_ancestor_of(n):
					n.get_parent().remove_child(n)
					n.queue_free()
		for group in ["lootboxes", "nests"]:
			for n in get_tree().get_nodes_in_group(group):
				if raid.is_ancestor_of(n):
					_reusable[_static_key(n, group)] = n
					n.set_physics_process(false)
		raid.factions.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		Events.any.connect(_shared_event)
	_status = Label.new()
	_status.position = Vector2(18, 146)
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	_status.add_theme_color_override("font_shadow_color", Color.BLACK)
	_status.add_theme_constant_override("shadow_offset_x", 2)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid.hud.add_child(_status)
	Net.notice.connect(_notice)
	raid.process_mode = Node.PROCESS_MODE_DISABLED

func geometry_signature() -> int:
	return _geometry

func _spawn_position(drop: Vector3, slot: int) -> Vector3:
	if slot == 0: return drop
	for i in 24:
		var angle := float(i + slot * 6) * TAU / 24.0
		var candidate := drop + Vector3(cos(angle), 0, sin(angle)) * (3.0 + slot)
		if raid.ai_free(candidate, 1.2, true): return candidate
	return drop

func _exit_tree() -> void:
	if Net.controller == self: Net.controller = null
	units.clear()
	contexts.clear()
	entities.clear()
	_hud_proxy = null

func _notice(t: String) -> void:
	if is_instance_valid(raid) and is_instance_valid(raid.hud):
		raid.hud.msg(t)

func _label_player(m, nickname: String, id: int, ring_col := Color(0.28, 0.88, 1.0)) -> void:
	var label := Label3D.new()
	label.text = ("★ " if id == 1 else "") + nickname
	label.position.y = 5.6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 32
	label.pixel_size = 0.016
	label.modulate = ring_col.lightened(0.22)
	m.add_child(label)

func release() -> void:
	raid.process_mode = Node.PROCESS_MODE_INHERIT
	for id in units:
		units[id].input_locked = false
	if Net.is_host():
		for id in units:
			if not Net.players.has(id): disconnected(id)
		_check_complete()
		_sync_entities()
		_send_snapshot()

func _process(delta: float) -> void:
	if not is_instance_valid(raid):
		return
	if Net.state == "loading":
		_status.text = Loc.t("等待小队完成战区加载…", "Waiting for squad to finish sector loading...")
		return
	if Net.state != "raid":
		return
	if Net.is_client() and Net.snapshot_age_ms() > 2500:
		_status.text = Loc.t("网络中断，正在等待房主恢复…", "Connection interrupted — waiting for host...")
		return
	_status.text = Loc.t("合作小队 %d/4  ·  %s\n", "Co-op Squad %d/4  ·  %s\n") % [Net.players.size(), Loc.t("房主", "Host") if Net.is_host() else "%d ms" % Net.ping_ms]
	for id in units:
		var m = units[id]
		_status.text += "%s  %d%%  %s\n" % [Net.roster[id].name, maxi(0, int(m.hp / maxf(m.max_hp, 1) * 100)), Loc.t(str(contexts[id].status))]
	if Net.is_host():
		_tick_players(delta)
		_tick_gate(delta)
		_send_t -= delta
		if _send_t <= 0:
			_send_t = 1.0 / 15.0
			_sync_entities()
			_send_snapshot()
	else:
		_client_input(delta)
		_interpolate(delta)

func _client_input(delta: float) -> void:
	var m = raid.mech
	var blocked: bool = m.input_locked or m.dead or m.net_done or raid.dropping or raid.hud.pause_panel.visible or raid.hud.settings_panel.visible or Story.flow.is_playing()
	var move: Vector3 = m.move_vec() if not blocked else Vector3.ZERO
	var fire := 0
	if not blocked and not raid.hud.map_open() and not raid.hud.is_touch_busy():
		if Input.is_action_pressed("fire_left") or m.joy_aim.length() >= 0.28: fire |= 1
		if Input.is_action_pressed("fire_right"): fire |= 2
	_input_t -= delta
	if _input_t <= 0:
		_input_t = 1.0 / 30.0
		_seq += 1
		Net.send_input(_seq, Vector2(move.x, move.z), m.aim_point, fire, blocked)
	if blocked:
		return
	for pair in [["dash", "dash"], ["ability", "ability"], ["reload", "reload"], ["use_fuel", "fuel"], ["use_repair", "repair"]]:
		if Input.is_action_just_pressed(pair[0]):
			Net.command(pair[1], [Vector2(move.x, move.z)] if pair[1] == "dash" else [])

func accept_input(id: int, seq: int, move: Vector2, aim: Vector3, fire: int, locked: bool) -> void:
	if not units.has(id) or not Protocol.valid_input(move, aim) or seq <= int(_inputs.get(id, {}).get("seq", -1)):
		return
	_inputs[id] = {"seq": seq, "at": Time.get_ticks_msec()}
	var m = units[id]
	m.net_move = move.limit_length(1.0)
	m.net_fire = fire & 3
	m.aim_point = Vector3(aim.x, 1.8, aim.z)
	m.input_locked = locked or contexts[id].box != null or m.net_done

func _tick_players(delta: float) -> void:
	if raid.dropping:
		return
	for id in units:
		var m = units[id]
		if m.net_done:
			continue
		if id != 1 and Time.get_ticks_msec() - int(_inputs.get(id, {}).get("at", 0)) > 500:
			m.net_move = Vector2.ZERO
			m.net_fire = 0
		if m.dead:
			finish_player(id, false, "机甲结构损毁")
			continue
		var ctx: Dictionary = contexts[id]
		var box = ctx.box
		if box != null and not is_instance_valid(box):
			ctx.box = null
			m.input_locked = false
		if is_instance_valid(box):
			if box.global_position.distance_to(m.global_position) > 4.5:
				ctx.box = null
				m.input_locked = false
			else:
				# A container is revealed once per frame even when several people search it.
				if box.get_meta("reveal_frame", -1) != Engine.get_process_frames():
					box.set_meta("reveal_frame", Engine.get_process_frames())
					box.reveal_t += delta
					if box.reveal_t >= 0.55 and box.revealed < box.items.size():
						box.reveal_t = 0.0
						box.revealed += 1
						var item: String = box.items[box.revealed - 1]
						Net.player_event(id, "item_revealed", [item, int(GameData.item(item).rar)])
		var zone = null
		for z in raid.extracts:
			if z.contains(m.global_position): zone = z
		if raid.transport_state == "landed" and is_instance_valid(raid.transport_zone) and raid.transport_zone.contains(m.global_position):
			zone = raid.transport_zone
		if zone != ctx.target:
			if is_instance_valid(ctx.target): Net.player_event(id, "extract_cancelled", [ctx.target.title])
			ctx.target = zone
			ctx.progress = 0.0
			if zone != null: Net.player_event(id, "extract_started", [zone.title, zone.need, zone.is_transport])
		if zone != null:
			ctx.progress += delta
			if ctx.progress >= zone.need:
				Net.player_event(id, "extract_completed", [zone.title, zone.is_transport])
				finish_player(id, true, Loc.t("成功撤离（%s）", "Extracted (%s)") % zone.title)
		if id == 1:
			if ctx.box == null and raid.open_box != null:
				raid.open_box = null
				raid.hud.close_loot()
			raid.extract_target = ctx.target
			raid.extract_progress = ctx.progress

func finish_player(id: int, success: bool, reason: String) -> void:
	if not Net.is_host() or not units.has(id) or not contexts.has(id) or not contexts[id].result.is_empty():
		return
	var m = units[id]
	var ctx: Dictionary = contexts[id]
	ctx.result = {"success": success, "reason": reason, "cargo": m.cargo.duplicate(), "loadout": m.loadout.duplicate(), "start_cargo": ctx.start.duplicate(), "kills": raid.kills, "time": raid.time, "map_id": raid.map_id}
	ctx.status = "已撤离" if success else "已失去机甲"
	ctx.box = null
	m.net_done = true
	m.input_locked = true
	m.net_fire = 0
	m.velocity = Vector3.ZERO
	m.collision_layer = 0
	Net.commit_personal(id, ctx.result)
	Net.tell(id, Loc.t(reason) + Loc.t("；正在等待其余队员，镜头跟随存活队友", "; awaiting squadmates — spectating survivors"))
	if id == 1:
		raid.open_box = null
		raid.hud.close_loot()
	_check_complete()

func _check_complete() -> void:
	var out := {}
	for id in contexts:
		if contexts[id].result.is_empty():
			return
		out[id] = contexts[id].result
	raid.ended = true
	Net.complete(out)

func disconnected(id: int) -> void:
	finish_player(id, false, "驾驶员掉线，机甲与货物遗失")

func view_position() -> Vector3:
	if raid.mech.net_done or raid.mech.dead:
		for id in units:
			if not units[id].net_done and not units[id].dead:
				return units[id].global_position
	return raid.mech.global_position

func _tick_gate(delta: float) -> void:
	var edge := ""
	for id in units:
		if units[id].net_done: continue
		var e: String = raid.world_link.gate_at(units[id].global_position)
		if e == "" or (edge != "" and edge != e):
			_gate_t = 0.0
			return
		edge = e
	if edge == "": return
	if edge != _gate:
		_gate = edge
		_gate_t = 0.0
	_gate_t += delta
	if _gate_t < 2.0: return
	var saved := {"map": raid.world_link.gates[edge].to, "players": {}, "time": raid.time, "kills": raid.kills, "visited": raid.visited_maps.duplicate()}
	if saved.map not in saved.visited: saved.visited.append(saved.map)
	for id in units:
		var d := _player_state(units[id])
		d.merge({"start": contexts[id].start, "status": contexts[id].status, "result": contexts[id].result})
		saved.players[id] = d
	Net.transit(raid.world_link.OPP[edge], saved)

func make_command(action: String, args: Array) -> Dictionary:
	var b = raid.open_box
	return {"action": action, "args": args, "box": int(b.get_meta("net_id", 0)) if is_instance_valid(b) else 0,
		"revision": int(b.get_meta("net_revision", 0)) if is_instance_valid(b) else 0, "cargo": hash(raid.mech.cargo)}

func route(action: String, args: Array = []) -> bool:
	if applying: return false
	if action == "close" and not is_instance_valid(raid.open_box):
		raid.hud.close_loot()
		raid.mech.input_locked = raid.mech.net_done
	Net.command(action, args)
	return true

func execute(id: int, request: Dictionary) -> void:
	if not units.has(id) or not contexts[id].result.is_empty() or raid.dropping:
		return
	var action = request.get("action")
	var args = request.get("args", [])
	if not action is String or not args is Array or args.size() > 2:
		return
	var allowed := ["open", "close", "take", "take_all", "put", "discard", "equip_cargo", "equip_box", "use_box", "sort", "item", "item_index", "transport", "dash", "ability", "reload", "fuel", "repair", "abandon"]
	if action not in allowed: return
	var m = units[id]
	var ctx: Dictionary = contexts[id]
	if action == "abandon":
		finish_player(id, false, "驾驶员紧急弃机逃生")
		return
	if m.dead: return
	if action == "close" and id == Net.local_id() and ctx.box == null:
		raid.hud.close_loot()
		m.input_locked = m.net_done
	if action in ["take", "put", "discard", "equip_cargo", "equip_box", "use_box", "item_index"]:
		if args.is_empty() or not args[0] is int or args[0] < 0 or args[0] > Protocol.MAX_CARGO: return
	if action in ["equip_cargo", "equip_box"] and (args.size() != 2 or not args[1] is String or (args[1] != "" and args[1] not in Protocol.SLOTS)): return
	if action == "item" and (args.size() != 1 or not args[0] is String or args[0].length() > 96): return
	if action == "dash" and (args.size() != 1 or not args[0] is Vector2 or not args[0].is_finite()): return
	if action == "open":
		if args.size() != 1 or not args[0] is int: return
		var b = entities.get(args[0])
		if not is_instance_valid(b) or not b.is_in_group("lootboxes") or b.global_position.distance_to(m.global_position) > 4.5: return
		ctx.box = b
	elif action in ["take", "take_all", "put", "equip_box", "use_box"]:
		var b = ctx.box
		if not is_instance_valid(b) or b.global_position.distance_to(m.global_position) > 4.5: return
		if request.get("box", -1) != b.get_meta("net_id", 0) or request.get("revision", -1) != b.get_meta("net_revision", 0):
			Net.tell(id, "容器已被队友更新，请重新选择物品")
			return
	if action in ["put", "discard", "equip_cargo", "item_index"] and request.get("cargo", -1) != hash(m.cargo):
		Net.tell(id, "货舱已更新，请重新选择物品")
		return
	var keep_m = raid.mech
	var keep_h = raid.hud
	var keep_box = raid.open_box
	var keep_lo = raid.loadout
	var keep_target = raid.extract_target
	var keep_progress: float = raid.extract_progress
	raid.mech = m
	raid.loadout = m.loadout
	raid.open_box = ctx.box
	raid.extract_target = ctx.target
	raid.extract_progress = ctx.progress
	if id != 1:
		_hud_proxy.peer = id
		raid.hud = _hud_proxy
	applying = true
	match action:
		"open": raid.open_container(ctx.box)
		"close": raid.close_box()
		"take": raid.take_from_box(args[0])
		"take_all": raid.take_all_from_box()
		"put": raid.put_into_box(args[0])
		"discard": raid.discard_from_cargo(args[0])
		"equip_cargo": raid.equip_from_cargo(args[0], args[1])
		"equip_box": raid.equip_from_box(args[0], args[1])
		"use_box": raid.use_from_box(args[0])
		"sort": raid.sort_cargo()
		"item": m.use_item(args[0])
		"item_index": m.use_item_at_cargo(args[0])
		"transport": raid.call_transport()
		"dash":
			if ctx.box == null and not m.input_locked: m.try_dash(Vector3(args[0].x, 0, args[0].y).limit_length(1.0))
		"ability":
			if ctx.box == null and not m.input_locked: m.try_ability()
		"reload": m.reload_all()
		"fuel": m.use_item("fuel_cell")
		"repair": m.use_item("repair_kit")
	ctx.box = raid.open_box
	if action == "open" and id != 1:
		var world_events = raid.get_node_or_null("ext_events")
		if world_events != null:
			world_events._on_box_opened(str(ctx.box.kind), ctx.box.position)
	if is_instance_valid(ctx.box):
		ctx.box.set_meta("net_revision", int(ctx.box.get_meta("net_revision", 0)) + 1)
	applying = false
	raid.mech = keep_m
	raid.hud = keep_h
	raid.open_box = ctx.box if id == 1 else keep_box
	raid.loadout = m.loadout if id == 1 else keep_lo
	raid.extract_target = keep_target
	raid.extract_progress = keep_progress
	_sync_entities()
	_send_personal()

func _static_key(n, group: String) -> String:
	return "%s:%s:%s" % [group, n.position.snapped(Vector3.ONE * 0.05), n.get("kind") if group == "lootboxes" else ""]

func _sync_entities() -> void:
	var live := {}
	var created: Array = []
	for group in ["bugs", "npc_mechs", "nests", "lootboxes", "coop_devices"]:
		for n in get_tree().get_nodes_in_group(group):
			if not raid.is_ancestor_of(n) or n.is_queued_for_deletion(): continue
			var id := int(n.get_meta("net_id", 0))
			if id == 0:
				id = _next_entity
				_next_entity += 1
				n.set_meta("net_id", id)
				n.set_meta("net_revision", 0)
				entities[id] = n
				var d := {"id": id, "group": group, "position": n.position, "rotation": n.rotation}
				match group:
					"bugs", "lootboxes": d.kind = n.kind
					"npc_mechs":
						d.loadout = n.loadout.duplicate()
						d.faction = n.faction
						d.tier = n.tier
					"coop_devices":
						d.kind = n.get_meta("coop_device")
						d.radius = n.radius
						d.life = n.life
				descriptors[id] = d
				created.append(d)
			live[id] = true
	var removed: Array = []
	for id in entities.keys():
		if not live.has(id):
			removed.append(id)
			entities.erase(id)
			descriptors.erase(id)
	if not created.is_empty() or not removed.is_empty():
		# Bounded reliable batches avoid a huge initial packet and RPC queue spikes.
		for i in range(0, created.size(), 24):
			Net.entities.rpc(Net.mission, created.slice(i, i + 24), [])
		if not removed.is_empty(): Net.entities.rpc(Net.mission, [], removed)

func _player_state(m) -> Dictionary:
	var d := {"position": m.position, "velocity": m.velocity, "torso": m.torso.rotation.y, "legs": m.legs.rotation.y,
		"loadout": m.loadout.duplicate(), "cargo": m.cargo.duplicate(), "stats": m.stats.duplicate(), "done": m.net_done}
	for f in PLAYER_FIELDS: d[f] = m.get(f)
	return d

func _send_snapshot() -> void:
	_serial += 1
	var data := {"players": {}, "entities": {}, "time": raid.time, "kills": raid.kills, "dropping": raid.dropping,
		"transport": raid.transport_state, "transport_t": raid.transport_t}
	if is_instance_valid(raid.transport_zone): data.transport_pos = raid.transport_zone.position
	for id in units:
		var d := _player_state(units[id])
		d.erase("cargo")
		d.erase("loadout")
		d.erase("stats")
		d.status = contexts[id].status
		data.players[id] = d
	for id in entities:
		var n = entities[id]
		if not is_instance_valid(n) or n.is_in_group("lootboxes") or n.is_in_group("coop_devices"): continue
		var d := {"position": n.position, "rotation": n.rotation}
		if n.is_in_group("bugs"):
			for f in BUG_FIELDS:
				if f in n: d[f] = n.get(f)
		elif n.is_in_group("npc_mechs"):
			d.merge(_player_state(n))
		else: d.hp = n.hp
		data.entities[id] = d
	Net.send_snapshot(_serial, data)
	_send_personal()

func _send_personal() -> void:
	for id in Net.players:
		if not units.has(id): continue
		var ctx: Dictionary = contexts[id]
		var m = units[id]
		var d := {"cargo": m.cargo.duplicate(), "loadout": m.loadout.duplicate(), "stats": m.stats.duplicate(), "box": {}, "extract": ctx.progress,
			"zone": ctx.target.title if is_instance_valid(ctx.target) else "", "need": ctx.target.need if is_instance_valid(ctx.target) else 0.0}
		if is_instance_valid(ctx.box):
			d.box = {"id": ctx.box.get_meta("net_id", 0), "items": ctx.box.items.duplicate(), "revealed": ctx.box.revealed, "revision": ctx.box.get_meta("net_revision", 0)}
		# Extraction progress uses snapshots; reliable inventory is sent only when it changes.
		var stable := d.duplicate(true)
		stable.erase("extract")
		var h := hash(stable)
		if _personal_cache.get(id) != h:
			_personal_cache[id] = h
			if id == 1:
				raid.hud.refresh_loot()
			else:
				Net.personal.rpc_id(id, Net.mission, d)
		if id != 1:
			Net.extraction.rpc_id(id, Net.mission, ctx.progress)
	# Loadout swaps on other players must also refresh their replicas.
	var outfits := {}
	for id in units: outfits[id] = units[id].loadout.duplicate()
	var outfit_hash := hash(outfits)
	if _personal_cache.get("outfits") != outfit_hash:
		_personal_cache["outfits"] = outfit_hash
		Net.outfits.rpc(Net.mission, outfits)

func apply_entities(created: Array, removed: Array) -> void:
	applying = true
	for id in removed:
		var n = entities.get(id)
		if is_instance_valid(n):
			if raid.open_box == n:
				raid.open_box = null
				raid.hud.close_loot()
				raid.mech.input_locked = raid.mech.net_done
			if n.is_in_group("bugs"):
				if is_instance_valid(n.visual):
					raid.explode_fx(n.position, 1.0, Color(0.4, 0.5, 0.1))
				n._die()
			elif n.is_in_group("npc_mechs"):
				n.die("destroyed")
			else:
				n.get_parent().remove_child(n)
				n.queue_free()
		entities.erase(id)
		_entity_state.erase(id)
	for d in created:
		if entities.has(d.id): continue
		var n
		match d.group:
			"lootboxes", "nests":
				var key := "%s:%s:%s" % [d.group, d.position.snapped(Vector3.ONE * 0.05), d.get("kind", "")]
				n = _reusable.get(key)
				_reusable.erase(key)
				if not is_instance_valid(n):
					if d.group == "lootboxes": n = raid._place_box(d.kind, d.position, [])
					else:
						n = load("res://scripts/nest.gd").new()
						raid.world.add_child(n)
						n.position = d.position
						n.setup(raid)
			"bugs": n = raid.spawn_bug(d.kind, d.position, 10000)
			"npc_mechs":
				n = load("res://scripts/factions/npc_mech.gd").new()
				n.raid = raid
				raid.add_child(n)
				n.setup_npc(d.loadout, d.faction, d.tier)
			"coop_devices":
				var scripts := {"decoy": "res://scripts/modules/decoy_beacon.gd", "barrier": "res://scripts/modules/extract_barrier.gd", "web": "res://scripts/modules/slow_web.gd"}
				if not scripts.has(d.kind): continue
				n = load(scripts[d.kind]).new()
				n.raid = raid
				n.radius = d.radius
				n.life = d.life
				raid.fx.add_child(n)
		if n == null: continue
		n.position = d.position
		n.rotation = d.rotation
		n.set_meta("net_id", d.id)
		n.set_physics_process(false)
		n.set_process(false)
		if n is CollisionObject3D:
			n.collision_layer = 0
			n.collision_mask = 0
		entities[d.id] = n
		descriptors[d.id] = d
	applying = false

func apply_snapshot(serial: int, data: Dictionary) -> void:
	if serial <= _received: return
	_received = serial
	_world_state = data
	_entity_state = data.entities
	raid.time = data.time
	raid.kills = data.kills
	raid.dropping = data.dropping
	for id in data.players:
		if not units.has(id): continue
		_apply_player(units[id], data.players[id], false)
		contexts[id].status = data.players[id].status
	var previous: String = raid.transport_state
	raid.transport_state = data.transport
	raid.transport_t = data.transport_t
	if data.has("transport_pos") and not is_instance_valid(raid.transport_zone):
		raid.transport_zone = load("res://scripts/extract_zone.gd").new()
		raid.world.add_child(raid.transport_zone)
		raid.transport_zone.position = data.transport_pos
		raid.transport_zone.setup(Loc.t("运输机降落区", "Dropship LZ"), Color(1, 0.75, 0.2), 3.0, true)
	if previous != "landed" and data.transport == "landed": raid._spawn_transport_ship()
	if data.transport == "gone" and is_instance_valid(raid.transport_ship):
		raid.transport_ship.queue_free()
		raid.transport_ship = null
	if data.transport == "gone" and is_instance_valid(raid.transport_zone):
		raid.transport_zone.set_active(false)

func _apply_player(m, d: Dictionary, full: bool) -> void:
	var was_dead: bool = m.dead
	for f in PLAYER_FIELDS:
		if d.has(f): m.set(f, d[f])
	m.net_done = d.get("done", false)
	m.velocity = d.get("velocity", Vector3.ZERO)
	m.set_meta("net_pose", d)
	if full:
		m.cargo = d.cargo.duplicate()
		m.stats = d.stats.duplicate()
		# Entry position is deliberately retained on map transitions.
	if m.net_done:
		m.input_locked = true
	if not was_dead and m.dead and Net.is_client():
		load("res://scripts/mech_visual.gd").scatter(m.visual)

func apply_personal(data: Dictionary) -> void:
	var m = raid.mech
	m.cargo = data.cargo.duplicate()
	m.stats = data.stats.duplicate()
	apply_outfits({Net.local_id(): data.loadout})
	if data.box.is_empty():
		if is_instance_valid(raid.open_box):
			raid.open_box = null
			raid.hud.close_loot()
			m.input_locked = m.net_done
	else:
		var b = entities.get(data.box.id)
		if is_instance_valid(b):
			b.items = data.box.items.duplicate()
			b.revealed = data.box.revealed
			b.set_meta("net_revision", data.box.revision)
			if raid.open_box != b:
				raid.open_box = b
				m.input_locked = true
				raid.hud.open_loot(b)
	raid.extract_target = null
	if data.zone != "":
		for z in raid.extracts:
			if z.title == data.zone: raid.extract_target = z
		if is_instance_valid(raid.transport_zone) and raid.transport_zone.title == data.zone: raid.extract_target = raid.transport_zone
		if is_instance_valid(raid.extract_target): raid.extract_target.need = data.need
	raid.extract_progress = data.extract
	raid.hud.refresh_loot()

func apply_outfits(outfits: Dictionary) -> void:
	applying = true
	for id in outfits:
		if not units.has(id): continue
		var m = units[id]
		for slot in Protocol.SLOTS:
			var desired: String = outfits[id].get(slot, "")
			if desired != "" and m.loadout.get(slot, "") != desired:
				m.equip_module_in_raid(slot, desired)
	applying = false

func _interpolate(delta: float) -> void:
	for m in units.values():
		var d: Dictionary = m.get_meta("net_pose", {})
		if d.is_empty(): continue
		_pose_mech(m, d, delta)
	for id in _entity_state:
		var n = entities.get(id)
		if not is_instance_valid(n): continue
		var d: Dictionary = _entity_state[id]
		if n.is_in_group("npc_mechs"):
			_apply_player(n, d, false)
			_pose_mech(n, d, delta)
		else:
			n.position = n.position.lerp(d.position, minf(1.0, delta * 18.0))
			n.rotation.y = lerp_angle(n.rotation.y, d.rotation.y, minf(1, delta * 18))
			if n.is_in_group("bugs"):
				for f in BUG_FIELDS:
					if d.has(f): n.set(f, d[f])
				n.set_physics_process(false)
				n.vis_anchor.visible = true
				n._vis_sync()
				n.flash_t = maxf(0.0, n.flash_t - delta)
				n._update_flash()
				if not n.dying: n._animate(delta, n.move_amt)

func _pose_mech(m, d: Dictionary, delta: float) -> void:
	var t: float = minf(1, delta * 22.0)
	if m.position.distance_to(d.position) > 8: m.position = d.position
	else: m.position = m.position.lerp(d.position, t)
	m.torso.rotation.y = lerp_angle(m.torso.rotation.y, d.torso, t)
	m.legs.rotation.y = lerp_angle(m.legs.rotation.y, d.legs, t)
	m._vis_sync()
	if not m.dead: m._animate(delta, m.velocity.normalized())
	m.shield_mesh.visible = m.shield_time > 0.0
	if m == raid.mech:
		RenderingServer.global_shader_parameter_set("mech_damage", clampf(1.0 - m.hp / maxf(m.max_hp, 1), 0, 1))

func emit_effect(kind: String, args: Array) -> void:
	if Net.is_host() and Net.state == "raid":
		if kind == "hazard": Net.important_effect.rpc(Net.mission, kind, args)
		else: Net.effect.rpc(Net.mission, kind, args)

func play_effect(kind: String, args: Array) -> void:
	applying = true
	match kind:
		"muzzle":
			raid.muzzle_flash(args[0], args[1], args[2], args[3], float(args[4]) if args.size() > 4 else 10.0)
			if args[3] != "": Audio.play_sfx("wpn_%s_fire" % args[3], args[0])
			for m in units.values():
				for slot in ["arm_l", "arm_r"]:
					if m.muzzles.has(slot) and m.muzzles[slot].global_position.distance_to(args[0]) < 1.0:
						m.recoil[slot] = 1.0
						m.fired.emit(slot)
		"explosion": raid.explode_fx(args[0], args[1], args[2])
		"impact": raid.impact(args[0], args[1], args[2], args[3], args[4], args[5])
		"shot":
			var skind: String = str(args[5]) if args.size() > 5 else "shell"
			var p
			if skind.begins_with("tracer:"):
				p = raid._tracer(args[0], args[1], 0.0, args[2], args[3], args[4], float(args[4]) * 0.56, skind.trim_prefix("tracer:"))
				p.pool_key = ""
			else:
				p = raid._proj(args[0], args[1], 0.0, args[2], 0, args[3], args[4], false, skind)
			p.mask = 0
			p.set_meta("net_visual", true)
		"beam": raid.laser_visual(args[0], args[1], args[2], args[3])
		"hazard":
			var H = load("res://scripts/enemies/hazards.gd")
			var n
			match args[0]:
				"mark": n = H.Mark.new()
				"pool": n = H.AcidPool.new()
				"ring": n = H.ShockRing.new()
				"telegraph_ring", "telegraph_lane": n = H.Telegraph.new()
				"spikes": n = H.SpikeRow.new()
				"shell": n = H.LobShell.new()
			if n != null:
				raid.fx.add_child(n)
				var method := "setup_ring" if args[0] == "telegraph_ring" else ("setup_lane" if args[0] == "telegraph_lane" else "setup")
				n.callv(method, [raid] + args.slice(1))
	applying = false

func _shared_event(event: String, data: Dictionary) -> void:
	if event not in SHARED_EVENTS or Net.state != "raid": return
	var args: Array = []
	for arg in Events.args_of(event): args.append(data[arg])
	Net.event_received.rpc(Net.mission, event, args)
