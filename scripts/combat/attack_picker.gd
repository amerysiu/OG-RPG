extends Control

## The attack menu shown at the start of every round of a word fight.
##
## The player - not the monster - chooses HOW to attack, and the attack decides
## which Orton-Gillingham question they answer and how hard it is:
##
##   Light Hit  (sword) - a quick word at the monster's level, 1 hit
##   Heavy Hit  (sword) - a harder word one level up, 2 hits
##   Wand Magic (wand)  - listen and shield the word from sound alone, 1 hit
##
## This overlay only reports the choice. The world (iso_world.gd) owns the
## monster, the mini-games and the hit or miss result.

signal attack_chosen(method: String)
signal flee_requested

var _active := false

@onready var _title: Label = %Title
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _message: Label = %Message


func _ready() -> void:
	hide()
	%LightButton.pressed.connect(func(): _pick("light"))
	%HeavyButton.pressed.connect(func(): _pick("heavy"))
	%MagicButton.pressed.connect(func(): _pick("magic"))
	%FleeButton.pressed.connect(func(): flee_requested.emit())


## Show the menu for one monster. `note` carries the last result, if any.
func open(monster_name: String, hits_left: int, hits_total: int, note: String = "") -> void:
	_active = true
	_title.text = "%s   choose your attack" % monster_name
	_hp_bar.max_value = maxi(1, hits_total)
	set_hits_left(hits_left)
	_message.text = note if note != "" else "Every correct word is a hit. Pick an attack and answer its word."
	show()


func set_hits_left(value: int) -> void:
	_hp_bar.max_value = maxi(1, int(_hp_bar.max_value))
	_hp_bar.value = value
	_hp_label.text = "HP  %d / %d" % [value, int(_hp_bar.max_value)]


func close_overlay() -> void:
	_active = false
	hide()


func is_active() -> bool:
	return _active


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		flee_requested.emit()
		get_viewport().set_input_as_handled()


func _pick(method: String) -> void:
	if not _active:
		return
	attack_chosen.emit(method)
