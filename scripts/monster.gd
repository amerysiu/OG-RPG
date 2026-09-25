extends Area2D

## A wild monster: it wanders its own little patrol, drifts toward the player
## when the player comes close, and on touch asks the world to start a Word
## Build encounter.
##
## The monster owns only its own motion and its own look. It never opens the
## mini-game and never decides a fight: it emits player_contacted and the
## encounter referee decides whether an encounter starts. The referee also
## tells the monster when it is paused (encounter open) or defeated.

signal player_contacted(monster: Node)

enum State { WANDER, CHASE, DEFEATED }

@export var display_name: String = "Wild Thing"
@export var word_level: int = 1
@export var max_hits: int = 2
@export var body_color: Color = Color(0.86, 0.4, 0.56, 1)
@export var wander_radius: float = 130.0
@export var wander_speed: float = 46.0
@export var chase_speed: float = 84.0
@export var detect_radius: float = 150.0
@export var flee_seconds: float = 2.2

var _home: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _state: int = State.WANDER
var _hits_left: int = 0
var _flee_timer: float = 0.0
var _player_node: Node2D = null

@onready var _visual: Node2D = get_node_or_null("Visual") as Node2D
@onready var _body: Polygon2D = get_node_or_null("Visual/Body") as Polygon2D
@onready var _tag: Label = get_node_or_null("Tag") as Label
@onready var _hits_label: Label = get_node_or_null("HitsLabel") as Label


func _ready() -> void:
	if not is_in_group("monster"):
		add_to_group("monster")
	_home = global_position
	_target = global_position
	_hits_left = maxi(1, max_hits)
	if _body != null:
		_body.color = body_color
	if _tag != null:
		_tag.text = display_name
	_refresh_hits_label()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


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


# ------------------------------------------------------------- encounter API

## Hits this monster takes before it is defeated.
func starting_hits() -> int:
	return maxi(1, max_hits)


func set_hits_left(value: int) -> void:
	_hits_left = maxi(0, value)
	_refresh_hits_label()


## True while an encounter is open: stand still so the frozen player is safe.
func set_encounter_paused(paused: bool) -> void:
	set_physics_process(not paused)


func is_defeated() -> bool:
	return _state == State.DEFEATED


## The player ran away: stop chasing, walk it back home, and let the player
## go. A child must never be trapped in an encounter.
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
	if _visual != null:
		_visual.visible = false
	if _tag != null:
		_tag.visible = false
	if _hits_label != null:
		_hits_label.visible = false


# ------------------------------------------------------------------ movement

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


# ------------------------------------------------------------------ contacts

func _on_body_entered(body: Node2D) -> void:
	if _state == State.DEFEATED or _flee_timer > 0.0:
		return
	if not body.is_in_group("player"):
		return
	player_contacted.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		# The player stepped away: ready to be greeted again next time.
		_player_node = body


func _refresh_hits_label() -> void:
	if _hits_label != null:
		_hits_label.text = "Hits: %d" % _hits_left
