extends Area2D

signal player_contacted(monster: Node)

enum State { WANDER, CHASE, DEFEATED }
enum CombatMode { SPEED, AUDIO, FORGE }

## Each monster guards one OG stage. kind: stage | boss | heart | quest.
## A monster sleeps until its stage is unlocked (bosses: until the whole zone
## is mastered). Defeated stage monsters come back after RESPAWN_SECONDS so
## the child can keep practising; a defeated boss stays down for good.
const RESPAWN_SECONDS := 18.0

@export var display_name: String = "Wild Thing"
@export var word_level: int = 1
@export var zone_id: int = 1
@export var stage_id: String = "C1"
@export var kind: String = "stage"
@export var boss_stages: Array = []
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
var _asleep := false
var _respawn_timer: Timer

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
	if kind == "boss":
		_visual.scale = Vector2(1.45, 1.45)
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_respawn)
	add_child(_respawn_timer)
	body_entered.connect(_on_body_entered)
	if Learner.has_signal("changed"):
		Learner.changed.connect(refresh_state)
	refresh_state()


## Wake or sleep according to the child's progress, and relabel.
func refresh_state() -> void:
	if _state == State.DEFEATED and kind != "boss":
		return
	if kind == "boss" and Learner.is_boss_defeated(zone_id):
		_state = State.DEFEATED
		visible = false
		set_physics_process(false)
		set_deferred("monitoring", false)
		return
	_asleep = not is_awake()
	if _visual != null:
		_visual.modulate = Color(0.55, 0.55, 0.7, 0.75) if _asleep else Color.WHITE
	if _tag != null:
		var what := OGCurriculum.label(stage_id) if kind == "stage" else ""
		match kind:
			"boss":
				what = "BOSS · review of zone %d" % zone_id
			"heart":
				what = "Heart words"
			"quest":
				what = "Daily review"
		_tag.text = "%s\n%s" % [display_name, what]
		_tag.offset_top = -130.0
		_tag.add_theme_font_size_override("font_size", 13)
	_refresh_hits_label()


func is_awake() -> bool:
	match kind:
		"boss":
			return Learner.is_boss_ready(zone_id) and not Learner.is_boss_defeated(zone_id)
		"heart":
			return Learner.is_zone_unlocked(zone_id)
		"quest":
			return not Learner.mastered_stages().is_empty()
	return Learner.is_stage_unlocked(stage_id)


## Why this monster is asleep, for the status line.
func sleep_reason() -> String:
	match kind:
		"boss":
			if not Learner.is_zone_unlocked(zone_id):
				return "%s is sealed away. Beat the previous boss first." % display_name
			return "%s sleeps until every stage in this zone is mastered." % display_name
		"quest":
			return "The Quest Board opens once you master your first stage."
		"heart":
			return "This zone is still sealed."
	var prev := OGCurriculum.previous_stage(stage_id)
	if not Learner.is_zone_unlocked(zone_id):
		return "This zone is sealed. Beat the previous zone's boss to open it."
	return "%s is asleep. Master %s first." % [display_name, OGCurriculum.label(prev)]


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


func is_asleep() -> bool:
	return _asleep


## What the battle screen needs to know about this monster.
func battle_info() -> Dictionary:
	var pool: Array = []
	for sid in boss_stages:
		pool.append(String(sid))
	return {
		"name": display_name, "zone": zone_id, "stage": stage_id, "kind": kind,
		"stages": pool, "combat_mode": combat_mode_key(),
	}


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
	if kind != "boss":
		_respawn_timer.start(RESPAWN_SECONDS)


func _respawn() -> void:
	_state = State.WANDER
	global_position = _home
	_target = _home
	_hits_left = maxi(1, max_hits)
	visible = true
	set_physics_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	_flee_timer = flee_seconds
	refresh_state()


func _physics_process(delta: float) -> void:
	if _state == State.DEFEATED:
		return
	if _asleep:
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
	if _asleep:
		if body.is_in_group("player"):
			player_contacted.emit(self)
		return
	if not body.is_in_group("player"):
		return
	player_contacted.emit(self)


func _refresh_hits_label() -> void:
	if _hits_label != null:
		_hits_label.text = "zzz  asleep" if _asleep else ("%s ★  ·  %s" % [{"audio": "Wand", "speed": "Light", "forge": "Heavy"}[combat_mode_key()], "ready"])


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
