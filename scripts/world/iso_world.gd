extends Node2D

const OGWords := preload("res://scripts/og_words.gd")
const PlayerScene := preload("res://scenes/iso_player.tscn")
const RemoteScene := preload("res://scenes/iso_remote_avatar.tscn")
const SpeedScene := preload("res://scenes/combat/speed_blending.tscn")
const AudioScene := preload("res://scenes/combat/audio_shielding.tscn")
const ForgeScene := preload("res://scenes/combat/kinesthetic_forging.tscn")
const PickerScene := preload("res://scenes/combat/attack_picker.tscn")

const CAMERA_FOLLOW := 6.0
const RESOURCE_NAME := "Wood"

var _player: CharacterBody2D
var _camera: Camera2D
var _modulate: CanvasModulate
var _light: PointLight2D
var _actors: Node2D
var _status: Label
var _zone_label: Label
var _party_label: Label
var _gold_label: Label
var _resource_label: Label
var _net_label: Label
var _ip_edit: LineEdit
var _speed: Control
var _audio: Control
var _forge: Control
var _picker: Control
var _active_overlay: Control
var _monster: Node
var _hits_left := 0
var _hits_total := 0
var _pending_damage := 0
var _pending_attack := ""
var _busy := false
var _gold := 0
var _resource := 0
var _zone := 1
var _avatars: Dictionary = {}
var _fog: GPUParticles2D


func _ready() -> void:
	randomize()
	_build_tree()
	IsoMapBuilder.build($World, _actors)
	_spawn_player()
	_wire_monsters()
	_wire_overlays()
	RoomStateManager.peer_updated.connect(_on_peer_updated)
	RoomStateManager.peer_left.connect(_on_peer_left)
	_status.text = "Phoneme Village. Walk with WASD. Touch a monster to begin a word fight. Host to invite a friend."
	_refresh_hud()


func _process(delta: float) -> void:
	if _player == null:
		return
	var weight := clampf(CAMERA_FOLLOW * delta, 0.0, 1.0)
	_camera.global_position = _camera.global_position.lerp(_player.global_position, weight)
	var cart := IsoMath.iso_to_cart(_player.global_position)
	var zone := ZoneCatalog.zone_at_cart(cart)
	if zone != _zone:
		_zone = zone
		_apply_zone_look()
	RoomStateManager.set_local_pose(_player.global_position, _zone, _player.facing)
	if _light != null:
		_light.global_position = _player.global_position + Vector2(0, -20)
	if _fog != null:
		_fog.global_position = _player.global_position
	_refresh_hud()


func is_world_busy() -> bool:
	return _busy


func _build_tree() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.07, 0.09, 0.14, 1)
	backdrop.position = Vector2(-400, -300)
	backdrop.size = Vector2(4200, 2600)
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
	_camera.limit_left = 200
	_camera.limit_top = -40
	_camera.limit_right = 3100
	_camera.limit_bottom = 1750
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
	panel.size = Vector2(620, 210)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(24, 20)
	box.size = Vector2(596, 190)
	box.add_theme_constant_override("separation", 3)
	layer.add_child(box)
	_zone_label = _hud_line(box, "Phoneme Village")
	_party_label = _hud_line(box, "Party Lv 1")
	_gold_label = _hud_line(box, "Gold: 0")
	_gold_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.28, 1))
	_resource_label = _hud_line(box, "Wood: 0")
	_net_label = _hud_line(box, "Offline · local room")
	_status = _hud_line(box, "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(580, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size = Vector2(140, 28)
	row.add_child(_ip_edit)
	_net_button(row, "Host", _on_host)
	_net_button(row, "Join", _on_join)
	_net_button(row, "Leave", _on_leave)


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
	_speed = SpeedScene.instantiate()
	_audio = AudioScene.instantiate()
	_forge = ForgeScene.instantiate()
	_picker = PickerScene.instantiate()
	layer.add_child(_speed)
	layer.add_child(_audio)
	layer.add_child(_forge)
	layer.add_child(_picker)


func _wire_overlays() -> void:
	# Light and Heavy sword hits both answer a word in Speed Blending; the wand
	# answers in Audio Shielding. Kinesthetic Forging stays in the project for a
	# future body-kinesthetic spell, but it is not on the attack menu yet.
	for overlay in [_speed, _audio]:
		overlay.word_solved.connect(_on_word_solved)
		overlay.attack_missed.connect(_on_attack_missed)
		overlay.flee_requested.connect(_on_flee)
		overlay.hide()
	_forge.hide()
	_picker.attack_chosen.connect(_on_attack_chosen)
	_picker.flee_requested.connect(_on_flee)
	_picker.hide()


func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	var spawn: Vector2 = ZoneCatalog.data(1)["spawn"]
	_player.position = IsoMath.cart_to_iso(spawn.x, spawn.y)
	_actors.add_child(_player)
	_camera.global_position = _player.global_position


func _wire_monsters() -> void:
	for monster in get_tree().get_nodes_in_group("monster"):
		if monster.has_signal("player_contacted") and not monster.player_contacted.is_connected(_on_monster_contacted):
			monster.player_contacted.connect(_on_monster_contacted)


func _on_monster_contacted(monster: Node) -> void:
	if _busy or monster == null or not is_instance_valid(monster):
		return
	if bool(monster.call("is_defeated")):
		return
	_busy = true
	_monster = monster
	_hits_total = maxi(1, int(monster.call("starting_hits")))
	_hits_left = _hits_total
	_pending_damage = 0
	_pending_attack = ""
	_player.set_input_enabled(false)
	monster.call("set_encounter_paused", true)
	monster.call("set_hits_left", _hits_left)
	_show_picker()
	RoomStateManager.set_combat("choose", String(monster.display_name))
	_status.text = "%s blocks the path - choose your attack." % String(monster.display_name)


# ------------------------------------------------------------------- attacks

## The player picked Light, Heavy or Magic in the attack menu. The choice picks
## both the question and the payoff: Light is a quick word for one hit, Heavy is
## a harder word for two, and Magic is the listen-and-shield question for one.
func _on_attack_chosen(method: String) -> void:
	if not _busy or _monster == null or not is_instance_valid(_monster):
		return
	var level := int(_monster.word_level)
	var zone := int(_monster.zone_id)
	_picker.call("close_overlay")
	_active_overlay = null
	if method == "heavy":
		_pending_attack = "heavy"
		_pending_damage = 2
		_launch_question(_speed, OGWords.pick_word_for_zone(zone, level + 2))
	elif method == "magic":
		_pending_attack = "magic"
		_pending_damage = 1
		_launch_question(_audio, OGWords.pick_word_for_zone(zone, level))
	else:
		_pending_attack = "light"
		_pending_damage = 1
		_launch_question(_speed, OGWords.pick_word_for_zone(zone, level))
	RoomStateManager.set_combat(_pending_attack, String(_monster.display_name))


func _launch_question(overlay: Control, entry: Dictionary) -> void:
	_active_overlay = overlay
	overlay.call("start_encounter", String(_monster.display_name), entry, _hits_left)


## A correct answer: the attack the player chose lands, for its own damage.
func _on_word_solved(word: String) -> void:
	if not _busy or _monster == null or not is_instance_valid(_monster):
		return
	var dmg := maxi(1, _pending_damage)
	_hits_left = maxi(0, _hits_left - dmg)
	_monster.call("set_hits_left", _hits_left)
	if _hits_left > 0:
		_status.text = "%s! %s takes %d hits - %d left. Choose your next attack." % [word.to_upper(), String(_monster.display_name), dmg, _hits_left]
		_show_picker("That hit landed. Pick your next attack.")
		return
	var gold := maxi(1, _hits_total * 2)
	var wood := maxi(1, _hits_total)
	_gold += gold
	_resource += wood
	RoomStateManager.grant_party_xp(int(_monster.word_level))
	_monster.call("mark_defeated")
	_status.text = "%s is defeated! +%d gold, +%d wood." % [String(_monster.display_name), gold, wood]
	_close_fight()


## The tries ran out: the attack whiffs and the player picks again. A miss costs
## no damage, it only ends that attack.
func _on_attack_missed() -> void:
	if not _busy or _monster == null or not is_instance_valid(_monster):
		return
	_status.text = "Your attack missed. %s is still standing - choose another attack." % String(_monster.display_name)
	_show_picker("That attack missed. Nothing lost - try again.")


## Show the attack menu again: at the start of a fight and between attacks.
func _show_picker(note: String = "") -> void:
	if _picker == null or _monster == null or not is_instance_valid(_monster):
		return
	if _active_overlay != null and _active_overlay != _picker:
		_active_overlay.call("close_overlay")
	_active_overlay = _picker
	_picker.call("open", String(_monster.display_name), _hits_left, _hits_total, note)


func _on_flee() -> void:
	if not _busy:
		return
	if _monster != null and is_instance_valid(_monster):
		_monster.call("flee_from_player")
		_status.text = "You slipped away. %s is still out there." % String(_monster.display_name)
	_close_fight()


func _close_fight() -> void:
	if _active_overlay != null:
		_active_overlay.call("close_overlay")
	if _player != null:
		_player.set_input_enabled(true)
	RoomStateManager.set_combat("none", "")
	_monster = null
	_active_overlay = null
	_pending_damage = 0
	_pending_attack = ""
	_busy = false
	_refresh_hud()


func _apply_zone_look() -> void:
	var z: Dictionary = ZoneCatalog.data(_zone)
	_modulate.color = z["modulate"]
	_light.color = z["light"]
	if _fog != null and _fog.process_material is ParticleProcessMaterial:
		(_fog.process_material as ParticleProcessMaterial).color = z["fog"]
	_fog.global_position = _player.global_position if _player != null else Vector2.ZERO
	_zone_label.text = "%s  ·  Lv %d–%d  ·  %s" % [z["name"], z["level_min"], z["level_max"], z["task"]]


func _refresh_hud() -> void:
	if _party_label == null:
		return
	_party_label.text = "Party Lv %d   XP %d" % [RoomStateManager.party_level, RoomStateManager.party_xp]
	_gold_label.text = "Gold: %d" % _gold
	_resource_label.text = "%s: %d" % [RESOURCE_NAME, _resource]
	var snap := RoomStateManager.snapshot()
	if bool(snap["online"]):
		_net_label.text = "Room %s  ·  %d readers  ·  %s" % [snap["room_id"], snap["peers"].size(), "host" if snap["authority"] else "peer"]
	else:
		_net_label.text = "Offline · local room (Host to sync friends)"


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
