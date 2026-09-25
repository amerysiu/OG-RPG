extends Area2D

## One village friend.
##
## The NPC owns its own proximity detection: the Area2D shape reports when the
## player walks in, which shows a "press E" prompt. Pressing the interact
## action then asks the village to open this NPC's word puzzle quest.

signal quest_requested(npc: Node)

@export var display_name: String = "Friend"
@export var quest_word: String = ""
@export var quest_hint: String = "Listen for the sounds and spell it with me."

## Set once the word has been solved - the friend then only says thank you.
var quest_complete: bool = false

var _player_near: bool = false
var _interaction_enabled: bool = true

@onready var _prompt_box: ColorRect = get_node_or_null("PromptBox") as ColorRect
@onready var _prompt: Label = get_node_or_null("Prompt") as Label
@onready var _done_mark: Node2D = get_node_or_null("DoneMark") as Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt != null:
		_prompt.text = "Press E to play with %s" % display_name
	if _done_mark != null:
		_done_mark.visible = false
	_set_prompt_visible(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_enabled or quest_complete or not _player_near:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		quest_requested.emit(self)


## The village disables every NPC while a puzzle overlay is open.
func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	_set_prompt_visible(value and _player_near and not quest_complete)


func mark_quest_complete() -> void:
	quest_complete = true
	_set_prompt_visible(false)
	if _done_mark != null:
		_done_mark.visible = true


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_set_prompt_visible(_interaction_enabled and not quest_complete)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_set_prompt_visible(false)


func _set_prompt_visible(value: bool) -> void:
	if _prompt_box != null:
		_prompt_box.visible = value
	if _prompt != null:
		_prompt.visible = value
