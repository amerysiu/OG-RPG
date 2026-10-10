extends CharacterBody2D

@export var speed: float = 220.0
var input_enabled: bool = true
var facing: float = 1.0

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite


func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	add_to_group("summer_player")
	var tex := CCAssetFetcher.player_texture(0)
	if tex != null and _sprite != null:
		_sprite.texture = tex
		_sprite.centered = true
		var h := float(tex.get_height())
		_sprite.scale = Vector2.ONE * clampf(96.0 / h, 0.18, 0.7)
		_sprite.offset = Vector2(0, -h * 0.08)
	if _sprite.texture == null:
		_sprite.texture = CCAssetFetcher.player_texture(1)


func _physics_process(_delta: float) -> void:
	if not input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	if not is_zero_approx(direction.x):
		facing = signf(direction.x)
		_visual.scale.x = facing
	move_and_slide()


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		velocity = Vector2.ZERO


func set_synced(key: String, value: Variant) -> void:
	set_meta("sync_" + key, value)


func get_synced(key: String) -> Variant:
	var meta_key := "sync_" + key
	if has_meta(meta_key):
		return get_meta(meta_key)
	return null
