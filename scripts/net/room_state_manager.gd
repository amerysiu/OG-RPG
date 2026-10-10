extends Node

signal room_changed(snapshot: Dictionary)
signal peer_updated(peer_id: int, state: Dictionary)
signal peer_left(peer_id: int)

const PORT := 18765
const SYNC_HZ := 12.0

var room_id := "og-phoneme-realm"
var local_peer_id := 1
var peers: Dictionary = {}
var party_level := 1
var party_xp := 0
var party_zone := 1
var combat_mode := "none"
var combat_target := ""
var _sync_accum := 0.0
var _local_pose := Vector2.ZERO
var _display_name := "Reader"


func _ready() -> void:
	randomize()
	_display_name = "Reader-%d" % (100 + randi() % 900)
	local_peer_id = 1
	peers[local_peer_id] = _blank_state()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


func _process(delta: float) -> void:
	_sync_accum += delta
	if _sync_accum < 1.0 / SYNC_HZ:
		return
	_sync_accum = 0.0
	_push_local()


func is_authority() -> bool:
	if Engine.has_singleton("Summer"):
		var summer = Engine.get_singleton("Summer")
		if summer != null and summer.has_method("is_server"):
			return bool(summer.call("is_server"))
	if not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()


func is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func host_room() -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 8)
	if err != OK:
		return "Could not host on port %d." % PORT
	multiplayer.multiplayer_peer = peer
	local_peer_id = 1
	peers.clear()
	peers[local_peer_id] = _blank_state()
	room_changed.emit(snapshot())
	return "Hosting room %s on port %d." % [room_id, PORT]


func join_room(ip: String) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		return "Could not join %s." % ip
	multiplayer.multiplayer_peer = peer
	return "Joining %s..." % ip


func leave_room() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	local_peer_id = 1
	peers.clear()
	peers[local_peer_id] = _blank_state()
	room_changed.emit(snapshot())


func set_local_pose(pos: Vector2, zone: int, facing: float) -> void:
	_local_pose = pos
	party_zone = zone
	var st: Dictionary = peers.get(local_peer_id, _blank_state())
	st["x"] = pos.x
	st["y"] = pos.y
	st["zone"] = zone
	st["facing"] = facing
	peers[local_peer_id] = st


func set_combat(mode: String, target: String) -> void:
	combat_mode = mode
	combat_target = target
	if is_authority():
		_write_synced("combat_mode", mode)
		_write_synced("combat_target", target)


func grant_party_xp(amount: int) -> void:
	if not is_authority():
		return
	party_xp += maxi(0, amount)
	while party_xp >= party_level * 8 and party_level < 20:
		party_xp -= party_level * 8
		party_level += 1
	_write_synced("party_level", party_level)
	_write_synced("party_xp", party_xp)


func snapshot() -> Dictionary:
	return {
		"room_id": room_id,
		"local_peer_id": local_peer_id,
		"online": is_online(),
		"authority": is_authority(),
		"party_level": party_level,
		"party_xp": party_xp,
		"party_zone": party_zone,
		"combat_mode": combat_mode,
		"combat_target": combat_target,
		"peers": peers.duplicate(true),
	}


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	peers[local_peer_id] = _blank_state()
	room_changed.emit(snapshot())


func _push_local() -> void:
	if is_online():
		local_peer_id = multiplayer.get_unique_id()
	else:
		local_peer_id = 1
	var st := _blank_state()
	st["x"] = _local_pose.x
	st["y"] = _local_pose.y
	st["zone"] = party_zone
	st["combat_mode"] = combat_mode
	st["combat_target"] = combat_target
	st["party_level"] = party_level
	st["party_xp"] = party_xp
	st["display_name"] = _display_name
	peers[local_peer_id] = st
	_bind_summer_player(st)
	if is_online():
		_rpc_state.rpc(st)
	peer_updated.emit(local_peer_id, st)
	room_changed.emit(snapshot())


@rpc("any_peer", "unreliable_ordered")
func _rpc_state(state: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = int(state.get("peer_id", local_peer_id))
	state["peer_id"] = id
	peers[id] = state
	if is_authority():
		party_level = maxi(party_level, int(state.get("party_level", 1)))
		if int(state.get("zone", 1)) > 0:
			pass
	peer_updated.emit(id, state)


func _on_peer_connected(id: int) -> void:
	peers[id] = _blank_state()
	peers[id]["peer_id"] = id
	if is_online():
		_rpc_state.rpc_id(id, peers.get(local_peer_id, _blank_state()))
	room_changed.emit(snapshot())


func _on_peer_disconnected(id: int) -> void:
	peers.erase(id)
	peer_left.emit(id)
	room_changed.emit(snapshot())


func _blank_state() -> Dictionary:
	return {
		"peer_id": local_peer_id,
		"x": _local_pose.x,
		"y": _local_pose.y,
		"zone": party_zone,
		"facing": 1.0,
		"combat_mode": combat_mode,
		"combat_target": combat_target,
		"party_level": party_level,
		"party_xp": party_xp,
		"display_name": _display_name,
	}


func _write_synced(key: String, value: Variant) -> void:
	var st: Dictionary = peers.get(local_peer_id, _blank_state())
	st[key] = value
	peers[local_peer_id] = st
	_bind_summer_player(st)


func _bind_summer_player(state: Dictionary) -> void:
	var summer_player := get_tree().get_first_node_in_group("summer_player")
	if summer_player != null and summer_player.has_method("set_synced"):
		for key in state.keys():
			summer_player.call("set_synced", String(key), state[key])
	elif Engine.has_singleton("Summer"):
		var summer = Engine.get_singleton("Summer")
		if summer != null and summer.has_method("get_players"):
			for p in summer.call("get_players"):
				if p != null and p.has_method("set_synced"):
					for key in state.keys():
						p.call("set_synced", String(key), state[key])
					break
