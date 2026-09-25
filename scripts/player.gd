extends CharacterBody2D

## Top-down village walker.
##
## The village is flat, so there is no gravity here: movement is a straight
## velocity applied with move_and_slide(). Movement polls the bound actions
## instead of consuming input events, so the village can simply switch
## input_enabled off while the word puzzle overlay is open.

@export var speed: float = 220.0

## False while a quest overlay is open - the world must ignore movement keys.
var input_enabled: bool = true

@onready var visual: Node2D = $Visual


func _physics_process(_delta: float) -> void:
	if not input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed

	# Flip only the visual wrapper, never the physics body.
	if not is_zero_approx(direction.x):
		visual.scale.x = signf(direction.x)

	move_and_slide()


## Called by the village when a quest opens or closes.
func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		velocity = Vector2.ZERO
