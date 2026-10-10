extends Node2D

var peer_id: int = 0
var display_name: String = "Friend"

@onready var _sprite: Sprite2D = $Sprite
@onready var _tag: Label = $Tag


func _ready() -> void:
	var tex := CCAssetFetcher.player_texture(peer_id % 5)
	if tex != null:
		_sprite.texture = tex
		_sprite.centered = true
		var h := float(tex.get_height())
		_sprite.scale = Vector2.ONE * clampf(88.0 / h, 0.16, 0.65)
		_sprite.offset = Vector2(0, -h * 0.08)
		_sprite.modulate = Color(0.82, 0.9, 1.0, 0.92)
	_tag.text = display_name


func apply_state(state: Dictionary) -> void:
	var dest := Vector2(float(state.get("x", global_position.x)), float(state.get("y", global_position.y)))
	global_position = global_position.lerp(dest, 0.35)
	display_name = String(state.get("display_name", display_name))
	_tag.text = display_name
	var facing := float(state.get("facing", 1.0))
	if not is_zero_approx(facing):
		_sprite.flip_h = facing < 0.0
