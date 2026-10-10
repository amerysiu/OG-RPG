extends Area2D

signal player_contacted(monster: Node)

enum State { WANDER, CHASE, DEFEATED }
enum CombatMode { SPEED, AUDIO, FORGE }

@export var display_name: String = "Wild Thing"
@export var word_level: int = 1
@export var zone_id: int = 1
@export var max_hits: int = 2
@export var combat_mode: CombatMode = CombatMode.SPEED
@export var wander_radius: float = 90.0
@export var wander_speed: float = 42.0
@export var chase_speed: float = 78.0
@export var detect_radius: float = 130.0
@export var flee_seconds: float = 2.2
@export var sprite_index: int = 0

var _home: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _state: int = State.WANDER
var _hits_left: int = 0
var _flee_timer: float = 0.0
var _player_node: Node2D = null

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _tag: Label = $Tag
@onready var _hits_label: Label = $HitsLabel
@onready var _shadow: Polygon2D = $Visual/Shadow


func _ready() -> void:
	if not is_in_group("monster"):
		add_to_group("monster")
	_home = global_position
	_target = global_position
	_hits_left = maxi(1, max_hits)
	_apply_sprite()
	if _tag != null:
		_tag.text = "%s  Lv%d" % [display_name, word_level]
	_refresh_hits_label()
	body_entered.connect(_on_body_entered)


func combat_mode_key() -> String:
	match combat_mode:
		CombatMode.AUDIO:
			return "audio"
		CombatMode.FORGE:
			return "forge"
		_:
			return "speed"


func starting_hits() -> int:
	return maxi(1, max_hits)


func set_hits_left(value: int) -> void:
	_hits_left = maxi(0, value)
	_refresh_hits_label()


func set_encounter_paused(paused: bool) -> void:
	set_physics_process(not paused)


func is_defeated() -> bool:
	return _state == State.DEFEATED


func flee_from_player() -> void:
	if _state == State.DEFEATED:
		return
	_state = State.WANDER
	_flee_timer = flee_seconds
	_target = _home
	set_physics_process(true)


func mark_defeated() -> void:
	if _state == State.DEFEATED:
		return
	_state = State.DEFEATED
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	visible = false


func _physics_process(delta: float) -> void:
	if _state == State.DEFEATED:
		return
	if _flee_timer > 0.0:
		_flee_timer = maxf(0.0, _flee_timer - delta)
		_state = State.WANDER
	else:
		_update_aggro()
	if _state == State.CHASE:
		_update_chase(delta)
	else:
		_update_wander(delta)


func _update_aggro() -> void:
	var player := _find_player()
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= detect_radius:
		_state = State.CHASE
	elif _state == State.CHASE and distance > detect_radius * 1.4:
		_state = State.WANDER
		_target = _home


func _update_chase(delta: float) -> void:
	var player := _find_player()
	if player == null:
		_state = State.WANDER
		_target = _home
		return
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > 0.001:
		global_position += to_player.normalized() * chase_speed * delta
		if _visual != null and not is_zero_approx(to_player.x):
			_visual.scale.x = signf(to_player.x)


func _update_wander(delta: float) -> void:
	var to_target: Vector2 = _target - global_position
	if to_target.length() < 10.0:
		_pick_wander_target()
		return
	global_position += to_target.normalized() * wander_speed * delta


func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var distance := randf_range(wander_radius * 0.35, wander_radius)
	_target = _home + Vector2(cos(angle), sin(angle)) * distance


func _find_player() -> Node2D:
	if _player_node != null and is_instance_valid(_player_node):
		return _player_node
	var found := get_tree().get_first_node_in_group("player")
	if found is Node2D:
		_player_node = found as Node2D
	return _player_node


func _on_body_entered(body: Node2D) -> void:
	if _state == State.DEFEATED or _flee_timer > 0.0:
		return
	if not body.is_in_group("player"):
		return
	player_contacted.emit(self)


func _refresh_hits_label() -> void:
	if _hits_label != null:
		_hits_label.text = "%s  Hits:%d" % [combat_mode_key().capitalize(), _hits_left]


func _apply_sprite() -> void:
	var tex := CCAssetFetcher.monster_texture(combat_mode_key(), sprite_index)
	if tex == null or _sprite == null:
		return
	_sprite.texture = tex
	_sprite.centered = true
	var h := float(tex.get_height())
	_sprite.scale = Vector2.ONE * clampf(110.0 / h, 0.2, 0.85)
	_sprite.offset = Vector2(0, -h * 0.06)
	if _shadow != null:
		_shadow.polygon = PackedVector2Array([Vector2(-22, 8), Vector2(22, 8), Vector2(14, 18), Vector2(-14, 18)])
