extends Node2D

## The 2.5D world: 8 zones in OG order (see ZoneCatalog), one monster per
## stage, a boss per zone and sealed gates between zones. A zone opens when
## the previous boss falls; the boss wakes once every stage of its zone is
## mastered (Learner). Fights happen on the battle screen.

const PlayerScene := preload("res://scenes/iso_player.tscn")
const RemoteScene := preload("res://scenes/iso_remote_avatar.tscn")
const BattleScene := preload("res://scenes/combat/battle_screen.tscn")
const ProgressPanel := preload("res://scripts/ui/progress_panel.gd")

const CAMERA_FOLLOW := 6.0
## Monster hit points by difficulty tier (Easy / Normal / Hard).
const HITS_BY_TIER := [3, 4, 6]
const BOSS_EXTRA_HITS := 3

var _player: CharacterBody2D
var _camera: Camera2D
var _modulate: CanvasModulate
var _light: PointLight2D
var _actors: Node2D
var _status: Label
var _zone_label: Label
var _stage_label: Label
var _party_label: Label
var _gold_label: Label
var _net_label: Label
var _toast: Label
var _ip_edit: LineEdit
var _battle: Control
var _panel: Control
var _monster: Node
var _hits_left := 0
var _hits_total := 0
var _busy := false
var _zone := 0
var _last_safe_pos := Vector2.ZERO
var _avatars: Dictionary = {}
var _fog: GPUParticles2D
var _seal_notice_cooldown := 0.0


func _ready() -> void:
	randomize()
	_build_tree()
	IsoMapBuilder.build($World, _actors)
	_spawn_player()
	_wire_monsters()
	_wire_overlays()
	_refresh_gates()
	Learner.changed.connect(_on_progress_changed)
	RoomStateManager.peer_updated.connect(_on_peer_updated)
	RoomStateManager.peer_left.connect(_on_peer_left)
	_status.text = "Walk with WASD / arrows. Touch an awake monster to start a word fight. M = Learning Map."
	_refresh_hud()
	if not bool(Learner.settings.get("started", false)):
		_open_panel(true)


func _process(delta: float) -> void:
	if _player == null:
		return
	_seal_notice_cooldown = maxf(0.0, _seal_notice_cooldown - delta)
	var weight := clampf(CAMERA_FOLLOW * delta, 0.0, 1.0)
	_camera.global_position = _camera.global_position.lerp(_player.global_position, weight)
	var cart := IsoMath.iso_to_cart(_player.global_position)
	var zone := ZoneCatalog.zone_at_cart(cart)
	if not Learner.is_zone_unlocked(zone):
		# Sealed gate: step back out and say why.
		_player.global_position = _last_safe_pos
		if _seal_notice_cooldown <= 0.0:
			_seal_notice_cooldown = 2.5
			var prev := ZoneCatalog.data(zone - 1)
			_status.text = "The gate to %s is sealed. Master every stage here, then beat %s." % [String(ZoneCatalog.data(zone)["name"]), String(prev["boss"])]
	else:
		_last_safe_pos = _player.global_position
		if zone != _zone:
			_zone = zone
			_apply_zone_look()
	RoomStateManager.set_local_pose(_player.global_position, _zone, _player.facing)
	if _light != null:
		_light.global_position = _player.global_position + Vector2(0, -20)
	if _fog != null:
		_fog.global_position = _player.global_position


func is_world_busy() -> bool:
	return _busy


func _build_tree() -> void:
	var bounds := ZoneCatalog.world_bounds()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.07, 0.09, 0.14, 1)
	backdrop.position = bounds.position - Vector2(600, 400)
	backdrop.size = bounds.size + Vector2(1200, 800)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -20
	add_child(backdrop)
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	_actors = Node2D.new()
	_actors.name = "Actors"
	_actors.y_sort_enabled = true
	_actors.z_index = 2
	world.add_child(_actors)
	_modulate = CanvasModulate.new()
	_modulate.name = "WorldModulate"
	add_child(_modulate)
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
	_camera.limit_smoothed = true
	add_child(_camera)
	_light = PointLight2D.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 0.95, 0.8, 1), Color(1, 0.9, 0.6, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.width = 256
	tex.height = 256
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_light.texture = tex
	_light.texture_scale = 2.6
	_light.energy = 1.05
	_light.range_item_cull_mask = 1
	add_child(_light)
	_fog = GPUParticles2D.new()
	_fog.amount = 40
	_fog.lifetime = 4.5
	_fog.preprocess = 2.0
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(420, 260, 1)
	mat.direction = Vector3(0.2, -1, 0)
	mat.spread = 40.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(0, -4, 0)
	mat.particle_flag_disable_z = true
	mat.scale_min = 1.2
	mat.scale_max = 3.4
	mat.color = Color(1, 1, 1, 0.35)
	_fog.process_material = mat
	add_child(_fog)
	_build_hud()
	_build_combat_layer()
	_apply_zone_look()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.07, 0.16, 0.82)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(640, 232)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(24, 18)
	box.size = Vector2(616, 220)
	box.add_theme_constant_override("separation", 3)
	layer.add_child(box)
	_zone_label = _hud_line(box, "")
	_stage_label = _hud_line(box, "")
	_stage_label.add_theme_color_override("font_color", Color(1, 0.88, 0.5, 1))
	_party_label = _hud_line(box, "")
	_gold_label = _hud_line(box, "")
	_gold_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.28, 1))
	_net_label = _hud_line(box, "Offline · local room")
	_status = _hud_line(box, "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(600, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_net_button(row, "Map (M)", func(): _open_panel(false))
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size = Vector2(130, 28)
	row.add_child(_ip_edit)
	_net_button(row, "Host", _on_host)
	_net_button(row, "Join", _on_join)
	_net_button(row, "Leave", _on_leave)
	_toast = Label.new()
	_toast.position = Vector2(0, 560)
	_toast.size = Vector2(1154, 40)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.2))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


func _hud_line(box: VBoxContainer, text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(0.92, 0.93, 1.0, 1))
	box.add_child(lab)
	return lab


func _net_button(row: HBoxContainer, text: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(cb)
	row.add_child(btn)


func _build_combat_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.name = "CombatLayer"
	add_child(layer)
	_battle = BattleScene.instantiate()
	layer.add_child(_battle)
	var panel_layer := CanvasLayer.new()
	panel_layer.layer = 30
	add_child(panel_layer)
	_panel = ProgressPanel.new()
	panel_layer.add_child(_panel)
	_panel.closed.connect(_on_panel_closed)
	_panel.placed.connect(_on_placed)


func _wire_overlays() -> void:
	_battle.word_solved.connect(_on_word_solved)
	_battle.attack_missed.connect(_on_attack_missed)
	_battle.attack_chosen.connect(_on_attack_chosen)
	_battle.flee_requested.connect(_on_flee)
	_battle.progress_event.connect(_show_toast)
	_battle.hide()


func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	_actors.add_child(_player)
	_place_player_at_zone(Learner.highest_unlocked_zone())


func _place_player_at_zone(zone_id: int) -> void:
	var spawn: Vector2 = ZoneCatalog.data(zone_id)["spawn"]
	_player.position = IsoMath.cart_to_iso(spawn.x, spawn.y)
	_last_safe_pos = _player.global_position
	_camera.global_position = _player.global_position
	_zone = zone_id
	_apply_zone_look()


func _wire_monsters() -> void:
	for monster in get_tree().get_nodes_in_group("monster"):
		if monster.has_signal("player_contacted") and not monster.player_contacted.is_connected(_on_monster_contacted):
			monster.player_contacted.connect(_on_monster_contacted)


# ------------------------------------------------------------------- fights

func _on_monster_contacted(monster: Node) -> void:
	if _busy or monster == null or not is_instance_valid(monster) or _panel.visible:
		return
	if bool(monster.call("is_defeated")):
		return
	if bool(monster.call("is_asleep")):
		_status.text = String(monster.call("sleep_reason"))
		return
	_busy = true
	_monster = monster
	var info: Dictionary = monster.call("battle_info")
	var tier_stage := String(info["stage"])
	if String(info["kind"]) == "heart":
		tier_stage = "H1"
	elif String(info["kind"]) == "quest":
		tier_stage = "R1"
	_hits_total = HITS_BY_TIER[Learner.tier_index(tier_stage)]
	if String(info["kind"]) == "boss":
		_hits_total += BOSS_EXTRA_HITS
	_hits_left = _hits_total
	monster.set("max_hits", _hits_total)
	info["hits_total"] = _hits_total
	info["hits_left"] = _hits_left
	_player.set_input_enabled(false)
	monster.call("set_encounter_paused", true)
	monster.call("set_hits_left", _hits_left)
	var tex := CCAssetFetcher.monster_texture(String(info["combat_mode"]), int(monster.get("sprite_index")))
	RoomStateManager.set_combat("choose", String(monster.display_name))
	_battle.call("open_battle", info, tex)
	_status.text = "%s blocks the path - choose an attack and answer its question." % String(monster.display_name)


func _on_attack_chosen(method: String) -> void:
	if _monster == null or not is_instance_valid(_monster):
		return
	var labels := {"light": "Sword Light (review)", "heavy": "Sword Heavy (spell it)", "wand": "Wand Magic (listen)"}
	_status.text = "%s: %s." % [String(_monster.display_name), String(labels.get(method, method))]
	RoomStateManager.set_combat(method, String(_monster.display_name))


func _on_word_solved(word: String, damage: int = 1) -> void:
	if not _busy or _monster == null or not is_instance_valid(_monster):
		return
	_hits_left = maxi(0, _hits_left - maxi(1, damage))
	_monster.call("set_hits_left", _hits_left)
	if _hits_left > 0:
		_battle.call("set_hits_left", _hits_left)
		_status.text = "%s (−%d)! %s has %d HP left." % [word.to_upper(), maxi(1, damage), String(_monster.display_name), _hits_left]
		await get_tree().create_timer(0.8).timeout
		if _busy and _monster != null:
			_battle.call("begin_round", "%s hit for %d. %d HP left — pick another attack." % [word.to_upper(), maxi(1, damage), _hits_left])
			RoomStateManager.set_combat("choose", String(_monster.display_name))
		return
	_battle.call("set_hits_left", 0)
	var gold := maxi(1, _hits_total * 2)
	var wood := maxi(1, _hits_total)
	Learner.add_loot(gold, wood)
	RoomStateManager.grant_party_xp(_hits_total)
	var kind := String(_monster.get("kind"))
	var msg := "%s is defeated! +%d gold, +%d wood." % [String(_monster.display_name), gold, wood]
	if kind == "boss":
		var z := int(_monster.get("zone_id"))
		Learner.mark_boss_defeated(z)
		if z + 1 < ZoneCatalog.count():
			msg = "%s falls! The gate to %s is open!" % [String(_monster.display_name), String(ZoneCatalog.data(z + 1)["name"])]
			_show_toast("Zone %d unlocked: %s" % [z + 1, String(ZoneCatalog.data(z + 1)["name"])])
		else:
			msg = "%s falls! You have finished the whole OG journey!" % String(_monster.display_name)
			_show_toast("You finished the whole journey! ★")
		_refresh_gates()
	_monster.call("mark_defeated")
	_status.text = msg
	_battle.call("show_defeat")
	await get_tree().create_timer(1.1).timeout
	_close_fight()


func _on_attack_missed() -> void:
	if not _busy or _monster == null or not is_instance_valid(_monster):
		return
	var monster_name := String(_monster.display_name)
	_status.text = "The attack missed - %s is still standing. Pick another attack." % monster_name
	await get_tree().create_timer(1.4).timeout
	if _busy and _monster != null:
		_battle.call("begin_round", "Miss! Pick another attack.")
		RoomStateManager.set_combat("choose", monster_name)


func _on_flee() -> void:
	if not _busy:
		return
	if _monster != null and is_instance_valid(_monster):
		_monster.call("flee_from_player")
		_status.text = "You slipped away. %s is still out there." % String(_monster.display_name)
	_close_fight()


func _close_fight() -> void:
	if _battle != null:
		_battle.call("close_overlay")
	if _player != null:
		_player.set_input_enabled(true)
	RoomStateManager.set_combat("none", "")
	_monster = null
	_busy = false
	_refresh_hud()


# ------------------------------------------------------------- progress UI

func _on_progress_changed() -> void:
	_refresh_hud()
	_refresh_gates()


func _show_toast(text: String) -> void:
	_status.text = text
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _refresh_gates() -> void:
	for gate in get_tree().get_nodes_in_group("zone_gate"):
		var nz := int(gate.get_meta("next_zone", 1))
		var open := Learner.is_zone_unlocked(nz)
		var seal: Node2D = gate.get_node_or_null("Seal")
		if seal != null:
			seal.visible = not open
		var lab: Label = gate.get_node_or_null("Label")
		if lab != null:
			if open:
				lab.text = "→ %s" % String(ZoneCatalog.data(nz)["name"])
			else:
				lab.text = "Sealed · beat %s" % String(ZoneCatalog.data(nz - 1)["boss"])


func _open_panel(welcome: bool) -> void:
	if _busy:
		return
	_player.set_input_enabled(false)
	_panel.call("open", welcome)


func _on_panel_closed() -> void:
	_player.set_input_enabled(true)
	_refresh_hud()
	_refresh_gates()


func _on_placed(zone_id: int) -> void:
	_place_player_at_zone(zone_id)
	_refresh_gates()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		if not _busy and not _panel.visible:
			_open_panel(false)
			get_viewport().set_input_as_handled()


func _apply_zone_look() -> void:
	if _modulate == null:
		return
	var z: Dictionary = ZoneCatalog.data(_zone)
	_modulate.color = z["modulate"]
	_light.color = z["light"]
	if _fog != null and _fog.process_material is ParticleProcessMaterial:
		(_fog.process_material as ParticleProcessMaterial).color = z["fog"]
	if _zone_label != null:
		_zone_label.text = "Zone %d · %s  ·  %s" % [_zone, z["name"], z["task"]]


func _refresh_hud() -> void:
	if _party_label == null:
		return
	var cur := Learner.current_stage()
	_stage_label.text = "Now learning: %s  ·  %s  ·  %s" % [OGCurriculum.label(cur), Learner.status_text(cur), Learner.tier_for(cur).capitalize()]
	_party_label.text = "Level %d   XP %d/%d   ·   %d stages mastered" % [Learner.level, Learner.xp, Learner.level * 10, Learner.mastered_stages().size()]
	_gold_label.text = "Gold: %d   Wood: %d" % [Learner.gold, Learner.wood]
	var snap := RoomStateManager.snapshot()
	if bool(snap["online"]):
		_net_label.text = "Room %s  ·  %d readers  ·  %s" % [snap["room_id"], snap["peers"].size(), "host" if snap["authority"] else "peer"]
	else:
		_net_label.text = "Offline · local room (Host to play with a friend)"


func _on_host() -> void:
	_status.text = RoomStateManager.host_room()


func _on_join() -> void:
	_status.text = RoomStateManager.join_room(_ip_edit.text)


func _on_leave() -> void:
	RoomStateManager.leave_room()
	_status.text = "Left the shared room."


func _on_peer_updated(peer_id: int, state: Dictionary) -> void:
	if peer_id == RoomStateManager.local_peer_id:
		return
	if not _avatars.has(peer_id):
		var avatar: Node2D = RemoteScene.instantiate()
		avatar.peer_id = peer_id
		avatar.display_name = String(state.get("display_name", "Friend"))
		_actors.add_child(avatar)
		_avatars[peer_id] = avatar
	_avatars[peer_id].apply_state(state)


func _on_peer_left(peer_id: int) -> void:
	if _avatars.has(peer_id):
		_avatars[peer_id].queue_free()
		_avatars.erase(peer_id)
