extends Node
## Room and transport lifetime, independent of the current menu/map. Server peer is always 1.
signal changed
signal notice(text: String)
signal launch_requested(config: Dictionary)
signal session_lost(reason: String)
signal result_received(result: Dictionary)
signal personal_result_received(result: Dictionary)

const Protocol = preload("res://scripts/net/protocol.gd")
const DEFAULT_PORT := Protocol.PORT
var state := "offline" # offline / connecting / lobby / loading / raid / results
var players := {}
var room_map := "greyport"
var world_seed := 1
var display_name := "驾驶员"
var address := "127.0.0.1"
var port := DEFAULT_PORT
var last_error := ""
var controller = null
var mission := 0
var roster := {}
var results := {}
var _peer: ENetMultiplayerPeer
var _password := ""
var _pending := {}
var _loaded := {}
var _deadline := 0
var _rate := {}
var _returning := {}
var _result_applied := -1
var _fingerprint := ""
var ping_ms := 0
var _ping_at := 0
var _last_heard := 0
var _snapshot_parts := {}
var _snapshot_serial := -1
var local_result := {}
var _command_tokens := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# All traffic is client <-> host. Disable peer relay and its peer-list broadcasts,
	# which can race ENet peer teardown when several clients leave in one poll.
	multiplayer.server_relay = false
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave(Loc.t("无法连接房主，请检查地址、端口和防火墙", "Could not connect to host. Check address, port, and firewall.")))
	multiplayer.server_disconnected.connect(func(): leave(Loc.t("与房主的连接已断开，本次未撤离的物资已遗失", "Disconnected from host. Unextracted loot has been lost.")))
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	var cfg := ConfigFile.new()
	if cfg.load("user://coop.cfg") == OK:
		display_name = Protocol.player_name(str(cfg.get_value("room", "name", display_name)))
		address = str(cfg.get_value("room", "address", address))
		port = clampi(int(cfg.get_value("room", "port", port)), 1024, 65535)

func active() -> bool:
	return state != "offline"

func is_host() -> bool:
	return active() and multiplayer.is_server()

func is_client() -> bool:
	return active() and not multiplayer.is_server()

func local_id() -> int:
	return multiplayer.get_unique_id() if active() else 1

func snapshot_age_ms() -> int:
	return Time.get_ticks_msec() - _last_heard

func _can_send(id: int) -> bool:
	if _peer == null or id not in multiplayer.get_peers(): return false
	var remote_peer := _peer.get_peer(id)
	return remote_peer != null and remote_peer.get_state() == ENetPacketPeer.STATE_CONNECTED

func fingerprint() -> String:
	if _fingerprint == "":
		var paths: Array[String] = []
		_collect_files("res://scripts", paths)
		_collect_files("res://data", paths)
		paths.sort()
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(str(Engine.get_version_info().get("string", "")).to_utf8_buffer())
		for path in paths:
			ctx.update(path.to_utf8_buffer())
			ctx.update(FileAccess.get_file_as_bytes(path))
			if path.ends_with(".remap"):
				var remap := ConfigFile.new()
				if remap.load(path) == OK:
					var target := str(remap.get_value("remap", "path", ""))
					if target != "" and FileAccess.file_exists(target): ctx.update(FileAccess.get_file_as_bytes(target))
		_fingerprint = ctx.finish().hex_encode()
	return _fingerprint

func _collect_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "gdc", "json", "remap"]:
			out.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		_collect_files(dir.path_join(sub), out)

func _preferences() -> void:
	if GameData.test_mode:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("room", "name", display_name)
	cfg.set_value("room", "address", address)
	cfg.set_value("room", "port", port)
	cfg.save("user://coop.cfg")

func host(nickname: String, listen_port := DEFAULT_PORT, password := "") -> Error:
	if active():
		return ERR_ALREADY_IN_USE
	if listen_port < 1024 or listen_port > 65535 or password.length() > 64:
		last_error = Loc.t("端口须为 1024–65535，口令最多 64 字", "Port must be 1024–65535; passcode max 64 chars")
		return ERR_INVALID_PARAMETER
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(listen_port, Protocol.MAX_PLAYERS - 1, 3)
	if err != OK:
		last_error = Loc.t("无法监听端口 %d，端口可能已被占用", "Cannot bind UDP port %d — port may be in use") % listen_port
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	display_name = Protocol.player_name(nickname)
	port = listen_port
	_password = password
	state = "lobby"
	room_map = GameData.map_id
	players = {1: {"name": display_name, "ready": false}}
	last_error = ""
	_preferences()
	changed.emit()
	return OK

func join(nickname: String, host_address: String, host_port := DEFAULT_PORT, password := "") -> Error:
	if active():
		return ERR_ALREADY_IN_USE
	if host_address.strip_edges().is_empty() or host_address.length() > 253 or host_port < 1024 or host_port > 65535 or password.length() > 64:
		last_error = Loc.t("请输入有效的房主地址、端口和口令", "Enter a valid host address, port, and passcode")
		return ERR_INVALID_PARAMETER
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host_address.strip_edges(), host_port, 3)
	if err != OK:
		last_error = Loc.t("无法创建连接（%d）" % err, "Failed to create connection (%d)" % err)
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	display_name = Protocol.player_name(nickname)
	address = host_address.strip_edges()
	port = host_port
	_password = password
	state = "connecting"
	_deadline = Time.get_ticks_msec() + 12000
	last_error = ""
	_preferences()
	changed.emit()
	return OK

func _connected() -> void:
	_hello.rpc_id(1, Protocol.VERSION, fingerprint(), display_name, _password)

func _peer_connected(id: int) -> void:
	if is_host():
		_pending[id] = Time.get_ticks_msec() + 10000

@rpc("any_peer", "call_remote", "reliable")
func _hello(version: int, build: String, nickname: String, password: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if not _pending.has(id):
		return
	_pending.erase(id)
	var reason := ""
	if version != Protocol.VERSION or build != fingerprint():
		reason = "游戏版本或数据不同，请双方使用同一份游戏"
	elif state != "lobby":
		reason = "小队正在行动，请等待房主返回机库"
	elif password != _password:
		reason = "房间口令错误"
	elif players.size() >= Protocol.MAX_PLAYERS:
		reason = "房间已满（最多 4 人）"
	if reason != "":
		_reject.rpc_id(id, reason)
		_disconnect_later(id)
		return
	players[id] = {"name": Protocol.player_name(nickname), "ready": false}
	_invalidate_ready()
	_broadcast_room()

@rpc("authority", "call_remote", "reliable")
func _reject(reason: String) -> void:
	leave(Loc.t(reason))

func _disconnect_later(id: int) -> void:
	var peer := _peer
	await get_tree().create_timer(0.3).timeout
	if peer != null and peer == _peer and id in multiplayer.get_peers():
		peer.disconnect_peer(id)

func kick(id: int) -> void:
	if is_host() and state == "lobby" and id != 1 and players.has(id):
		_reject.rpc_id(id, "你已被房主移出房间")
		_disconnect_later(id)

func _peer_disconnected(id: int) -> void:
	if not is_host():
		return
	_pending.erase(id)
	players.erase(id)
	_loaded.erase(id)
	_returning.erase(id)
	if is_instance_valid(controller):
		controller.disconnected(id)
	if state == "lobby":
		_invalidate_ready()
	_broadcast_room.call_deferred()
	_try_release()
	_try_return()

func leave(reason := "") -> void:
	var was_active := active()
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = "offline"
	players.clear()
	roster.clear()
	_pending.clear()
	_loaded.clear()
	_rate.clear()
	_command_tokens.clear()
	_returning.clear()
	results.clear()
	local_result.clear()
	_result_applied = -1
	_snapshot_parts.clear()
	_snapshot_serial = -1
	controller = null
	_password = ""
	last_error = reason
	ping_ms = 0
	changed.emit()
	if was_active:
		session_lost.emit(reason)

func select_map(id: String) -> void:
	if not is_host() or state != "lobby" or not GameData.MAPS.has(id):
		return
	if room_map != id:
		room_map = id
		_invalidate_ready()
		_broadcast_room()

func _invalidate_ready() -> void:
	for id in players:
		players[id].ready = false
		players[id].erase("loadout")
		players[id].erase("cargo")

func ready_up(value: bool) -> void:
	if state != "lobby":
		return
	if is_host():
		_set_ready(1, value, GameData.loadout, GameData.cargo, Progress.state)
	else:
		_ready_request.rpc_id(1, value, GameData.loadout, GameData.cargo, Progress.state)

@rpc("any_peer", "call_remote", "reliable")
func _ready_request(value: bool, lo: Dictionary, cargo: Array, growth: Dictionary) -> void:
	if is_host() and _allow(multiplayer.get_remote_sender_id(), "ready", 250):
		_set_ready(multiplayer.get_remote_sender_id(), value, lo, cargo, growth)

func _set_ready(id: int, value: bool, lo: Dictionary, cargo: Array, growth := {}) -> void:
	if state != "lobby" or not players.has(id):
		return
	if var_to_bytes(growth).size() > 65536: return
	var profile := Protocol.growth_profile(growth)
	var G = load("res://scripts/progression/growth.gd")
	G.network_profile = profile
	var err := Protocol.equipment_error(lo, cargo, GameData) if value else ""
	G.network_profile = null
	if err != "":
		tell(id, err)
		return
	players[id].ready = value
	players[id].loadout = lo.duplicate(true)
	players[id].cargo = cargo.duplicate()
	players[id].growth = profile
	_broadcast_room()

func can_launch() -> bool:
	if not is_host() or state != "lobby" or players.size() < 2:
		return false
	for p in players.values():
		if not p.ready:
			return false
	return true

func launch() -> void:
	if not can_launch():
		return
	roster = players.duplicate(true)
	results.clear()
	local_result.clear()
	_returning.clear()
	mission += 1
	world_seed = randi() & 0x3fffffff
	_begin({"mission": mission, "map": room_map, "roster": roster, "transit": {}, "seed": world_seed})

func _begin(config: Dictionary) -> void:
	state = "loading"
	_loaded.clear()
	_deadline = Time.get_ticks_msec() + 120000
	for id in players:
		if id != 1 and _can_send(id): _begin_remote.rpc_id(id, config)
	_receive_begin(config)

@rpc("authority", "call_remote", "reliable")
func _begin_remote(config: Dictionary) -> void:
	_receive_begin(config)

func _receive_begin(config: Dictionary) -> void:
	if config.transit.is_empty(): local_result.clear()
	state = "loading"
	mission = config.mission
	roster = config.roster.duplicate(true)
	room_map = config.map
	world_seed = config.seed
	_snapshot_parts.clear()
	_snapshot_serial = -1
	_deadline = Time.get_ticks_msec() + 120000
	changed.emit()
	launch_requested.emit(config)

func loaded() -> void:
	if state != "loading":
		return
	if is_host():
		_loaded[1] = true
		_try_release()
	else:
		_loaded_remote.rpc_id(1, mission, controller.geometry_signature())

@rpc("any_peer", "call_remote", "reliable")
func _loaded_remote(run_id: int, geometry: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host() and state == "loading" and run_id == mission and players.has(id):
		_loaded[id] = geometry
		_try_release()

func _try_release() -> void:
	if not is_host() or state != "loading" or not _loaded.has(1):
		return
	for id in players:
		if not _loaded.has(id):
			return
		if id != 1 and _loaded[id] != controller.geometry_signature():
			leave(Loc.t("战区几何校验失败，请确保所有队员使用完全相同的游戏版本", "Sector geometry verification failed — ensure all players run the exact same build"))
			return
	_release.rpc(mission)
	_release(mission)

@rpc("authority", "call_remote", "reliable")
func _release(run_id: int) -> void:
	if run_id != mission or not is_instance_valid(controller):
		return
	state = "raid"
	_last_heard = Time.get_ticks_msec()
	controller.release()
	changed.emit()

func transit(edge: String, saved: Dictionary) -> void:
	if not is_host() or state != "raid":
		return
	mission += 1 # New scene epoch rejects delayed packets from the previous map.
	_begin({"mission": mission, "map": saved.map, "roster": roster, "transit": saved, "edge": edge, "seed": world_seed})

func player_event(id: int, event: String, args: Array) -> void:
	if id == local_id() or not active():
		Events.callv("emit_signal", [event] + args)
	elif is_host() and players.has(id):
		event_received.rpc_id(id, mission, event, args)

@rpc("authority", "call_remote", "reliable")
func event_received(run_id: int, event: String, args: Array) -> void:
	if run_id == mission and Events.has_event(event) and event not in ["any", "custom"]:
		Events.callv("emit_signal", [event] + args)
		if event == "item_picked" and not args.is_empty():
			var codex := str(GameData.item(str(args[0])).get("codex", ""))
			if codex != "": Story.unlock_codex(codex)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func extraction(run_id: int, progress: float) -> void:
	if run_id == mission and is_instance_valid(controller):
		controller.raid.extract_progress = progress

@rpc("authority", "call_remote", "reliable")
func outfits(run_id: int, data: Dictionary) -> void:
	if run_id == mission and is_instance_valid(controller):
		controller.apply_outfits(data)

func send_input(seq: int, move: Vector2, aim: Vector3, fire: int, locked: bool) -> void:
	if is_client() and state == "raid":
		_receive_input.rpc_id(1, mission, seq, move, aim, fire, locked)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _receive_input(run_id: int, seq: int, move: Vector2, aim: Vector3, fire: int, locked: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host() and state == "raid" and run_id == mission and players.has(id) and is_instance_valid(controller):
		controller.accept_input(id, seq, move, aim, fire, locked)

func command(action: String, args: Array = []) -> void:
	if state != "raid" or not is_instance_valid(controller):
		return
	var request: Dictionary = controller.make_command(action, args)
	if is_host():
		controller.execute(1, request)
	else:
		_command.rpc_id(1, mission, request)

func stats_for(lo: Dictionary, id: int) -> Dictionary:
	var G = load("res://scripts/progression/growth.gd")
	if active() and roster.has(id): G.network_profile = roster[id].get("growth", {})
	var stats: Dictionary = GameData.compute_stats(lo)
	G.network_profile = null
	return stats

@rpc("any_peer", "call_remote", "reliable")
func _command(run_id: int, request: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host() and state == "raid" and run_id == mission and players.has(id) and _command_budget(id) and is_instance_valid(controller):
		controller.execute(id, request)

func _command_budget(id: int) -> bool:
	var now := Time.get_ticks_msec()
	var bucket: Dictionary = _command_tokens.get(id, {"at": now, "tokens": 16.0})
	bucket.tokens = minf(16.0, float(bucket.tokens) + (now - int(bucket.at)) * 0.02)
	bucket.at = now
	_command_tokens[id] = bucket
	if bucket.tokens < 1.0: return false
	bucket.tokens -= 1.0
	return true

func _allow(id: int, key: String, interval: int) -> bool:
	var k := "%d:%s" % [id, key]
	var now := Time.get_ticks_msec()
	if now - int(_rate.get(k, -10000)) < interval:
		return false
	_rate[k] = now
	return true

func send_snapshot(serial: int, data: Dictionary) -> void:
	var bytes := var_to_bytes(data).compress(FileAccess.COMPRESSION_GZIP)
	var parts := ceili(bytes.size() / 1000.0)
	for i in parts:
		snapshot.rpc(mission, serial, i, parts, bytes.slice(i * 1000, (i + 1) * 1000))

@rpc("authority", "call_remote", "unreliable", 2)
func snapshot(run_id: int, serial: int, part: int, count: int, bytes: PackedByteArray) -> void:
	if state != "raid" or run_id != mission or not is_instance_valid(controller) or serial <= _snapshot_serial:
		return
	if count < 1 or count > 128 or part < 0 or part >= count or bytes.size() > 1000:
		return
	if not _snapshot_parts.has(serial):
		_snapshot_parts[serial] = {}
	_snapshot_parts[serial][part] = bytes
	for old in _snapshot_parts.keys():
		if old < serial - 3: _snapshot_parts.erase(old)
	if _snapshot_parts[serial].size() != count: return
	var combined := PackedByteArray()
	for i in count: combined.append_array(_snapshot_parts[serial][i])
	var decoded := combined.decompress_dynamic(524288, FileAccess.COMPRESSION_GZIP)
	var data = bytes_to_var(decoded)
	if not data is Dictionary: return
	_snapshot_serial = serial
	_snapshot_parts.erase(serial)
	_last_heard = Time.get_ticks_msec()
	controller.apply_snapshot(serial, data)

@rpc("authority", "call_remote", "reliable")
func entities(run_id: int, created: Array, removed: Array) -> void:
	if run_id == mission and is_instance_valid(controller):
		controller.apply_entities(created, removed)

@rpc("authority", "call_remote", "reliable")
func personal(run_id: int, data: Dictionary) -> void:
	if run_id == mission and is_instance_valid(controller):
		controller.apply_personal(data)

@rpc("authority", "call_remote", "unreliable", 2)
func effect(run_id: int, kind: String, args: Array) -> void:
	if state == "raid" and run_id == mission and is_instance_valid(controller):
		controller.play_effect(kind, args)

@rpc("authority", "call_remote", "reliable")
func important_effect(run_id: int, kind: String, args: Array) -> void:
	effect(run_id, kind, args)

func tell(id: int, message: String) -> void:
	if id == local_id():
		notice.emit(Loc.t(message))
	elif is_host() and players.has(id) and _can_send(id):
		_notice.rpc_id(id, message)

@rpc("authority", "call_remote", "reliable")
func _notice(message: String) -> void:
	notice.emit(Loc.t(message))

func complete(all_results: Dictionary) -> void:
	if not is_host() or state != "raid":
		return
	results = all_results.duplicate(true)
	state = "results"
	for id in players:
		if results.has(id):
			if id == 1:
				_deliver_result(mission, results[id])
			else:
				_deliver_result.rpc_id(id, mission, results[id])
	changed.emit()

func commit_personal(id: int, result: Dictionary) -> void:
	if id == local_id():
		_commit_personal(mission, result)
	elif players.has(id):
		_commit_personal.rpc_id(id, mission, result)

@rpc("authority", "call_remote", "reliable")
func _commit_personal(run_id: int, result: Dictionary) -> void:
	if run_id != mission or not local_result.is_empty(): return
	local_result = result.duplicate(true)
	personal_result_received.emit(local_result)

@rpc("authority", "call_remote", "reliable")
func _deliver_result(run_id: int, result: Dictionary) -> void:
	if run_id != mission or _result_applied == run_id:
		return
	_result_applied = run_id
	state = "results"
	result_received.emit(result)
	changed.emit()

func return_to_room() -> void:
	if state != "results":
		return
	if is_host():
		_returning[1] = true
		_try_return()
	else:
		_return_remote.rpc_id(1, mission)

@rpc("any_peer", "call_remote", "reliable")
func _return_remote(run_id: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host() and state == "results" and run_id == mission and players.has(id):
		_returning[id] = true
		_try_return()

func _try_return() -> void:
	if not is_host() or state != "results":
		return
	for id in players:
		if not _returning.has(id):
			return
	state = "lobby"
	_invalidate_ready()
	controller = null
	_broadcast_room()

func _broadcast_room() -> void:
	if not is_host(): return
	var public := {}
	for id in players:
		public[id] = {"name": players[id].name, "ready": players[id].ready}
	for id in players:
		if id != 1 and _can_send(id): _room.rpc_id(id, public, room_map, state)
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func _room(members: Dictionary, map_name: String, room_state: String) -> void:
	players = members
	room_map = map_name
	state = room_state
	_last_heard = Time.get_ticks_msec()
	changed.emit()

@rpc("any_peer", "call_remote", "unreliable", 1)
func _ping(stamp: int) -> void:
	if is_host() and players.has(multiplayer.get_remote_sender_id()) and _allow(multiplayer.get_remote_sender_id(), "ping", 500):
		_pong.rpc_id(multiplayer.get_remote_sender_id(), stamp)

@rpc("authority", "call_remote", "unreliable", 1)
func _pong(stamp: int) -> void:
	_last_heard = Time.get_ticks_msec()
	ping_ms = maxi(0, _last_heard - stamp)

func _process(_delta: float) -> void:
	if not active():
		return
	var now := Time.get_ticks_msec()
	if state in ["connecting", "loading"] and now > _deadline:
		leave(Loc.t("连接或战区加载超时，请重新组队", "Connection or sector loading timed out. Please regroup."))
		return
	if is_host():
		for id in _pending.keys():
			if now > int(_pending[id]):
				_pending.erase(id)
				_peer.disconnect_peer(id)
	elif state != "connecting" and now - _ping_at > 1000:
		_ping_at = now
		_ping.rpc_id(1, now)
		if state != "loading" and now - _last_heard > 15000:
			leave(Loc.t("房主长时间未响应，连接已关闭", "Host timed out; connection closed."))
