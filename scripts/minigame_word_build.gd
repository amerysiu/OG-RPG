extends Control

## "Word Build" - the Orton-Gillingham letter-tile encoding mini-game.
##
## A wild monster blocks the path, so the player builds the target word by
## tapping grapheme tiles in sound order. Every sound of the word is shown as a
## chip (/f/ /i/ /sh/), so the cue is visual: this milestone has no audio at
## all and never depends on sound playback.
##
## Building the whole word correctly emits word_solved(); the encounter turns
## that into one hit. Nothing is timed and a wrong order is never punished - the
## player just takes a tile back and tries again. Fleeing emits flee_requested()
## so the world can release the monster and give the player back the world.
##
## The chip row, slot row and tile pool are all built from the OG word data in
## code, so they can never drift away from the target word.

signal word_solved(word: String)
signal flee_requested

const OGWords := preload("res://scripts/og_words.gd")

const COLOR_TEXT_TITLE := Color(0.24, 0.16, 0.5, 1)
const COLOR_TEXT_SUB := Color(0.44, 0.34, 0.62, 1)
const COLOR_TEXT_HINT := Color(0.16, 0.4, 0.34, 1)
const COLOR_TEXT_TIP := Color(0.2, 0.42, 0.62, 1)
const COLOR_TEXT_GOOD := Color(0.12, 0.52, 0.28, 1)
const COLOR_TEXT_BAD := Color(0.76, 0.3, 0.3, 1)
const COLOR_CHIP_BG := Color(1, 0.93, 0.74, 1)
const COLOR_CHIP_EDGE := Color(0.9, 0.66, 0.24, 1)
const COLOR_CHIP_TEXT := Color(0.38, 0.24, 0.06, 1)
const COLOR_SLOT_EMPTY := Color(0.93, 0.95, 0.99, 1)
const COLOR_SLOT_FILLED := Color(0.74, 0.88, 1, 1)
const COLOR_SLOT_EDGE := Color(0.55, 0.62, 0.86, 1)
const COLOR_TILE_EDGE := Color(0.66, 0.7, 0.92, 1)

@onready var _title: Label = %Title
@onready var _sub_header: Label = %SubHeader
@onready var _hint: Label = %Hint
@onready var _sound_caption: Label = %SoundCaption
@onready var _sound_row: HBoxContainer = %SoundRow
@onready var _slot_row: HBoxContainer = %SlotRow
@onready var _message: Label = %Message
@onready var _tile_pool: HFlowContainer = %TilePool
@onready var _back_button: Button = %BackButton
@onready var _flee_button: Button = %FleeButton

var _monster_name: String = "Monster"
var _level: int = 1
var _hits_left: int = 1
var _entry: Dictionary = {}
var _placed: Array = []
var _slot_buttons: Array = []
var _used_words: Array = []
var _locked: bool = false
var _active: bool = false


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_flee_button.pressed.connect(_on_flee_pressed)
	hide()


# --------------------------------------------------------------- encounter API

## Called by the encounter when the player touches a monster.
func start_encounter(monster_name: String, level: int, hits_left: int) -> void:
	_monster_name = monster_name
	_level = clampi(level, 1, 3)
	_hits_left = maxi(1, hits_left)
	_used_words.clear()
	_active = true
	show()
	next_round()


## The encounter reports the hits still standing after a solved word.
func set_hits_left(hits_left: int) -> void:
	_hits_left = maxi(0, hits_left)
	_refresh_header()


## Deals the next word of the same level (a monster needs several words).
func next_round() -> void:
	_entry = OGWords.pick_word(_level, _used_words)
	_used_words.append(String(_entry["word"]))
	while _used_words.size() > 3:
		_used_words.pop_front()
	_placed.clear()
	_locked = false
	_build_sounds()
	_build_slots()
	_build_tiles()
	_refresh_header()
	_set_message("Say each sound, then tap its letters in order.", COLOR_TEXT_TIP)


## Hides the overlay. The encounter owns the world, so it calls this itself.
func close_overlay() -> void:
	_active = false
	_locked = false
	hide()


func is_active() -> bool:
	return _active


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_flee()


# ------------------------------------------------------------------ tile board

func _on_tile_pressed(grapheme: String) -> void:
	if _locked or not _active:
		return
	if _placed.size() >= _tile_count():
		return
	_placed.append(grapheme)
	_refresh_slots()
	_check_build()


## Tapping a filled slot takes that tile back, and any tile after it.
func _on_slot_pressed(index: int) -> void:
	if _locked or not _active:
		return
	if index < 0 or index >= _placed.size():
		return
	while _placed.size() > index:
		_placed.pop_back()
	_refresh_slots()
	_set_message("Tiles taken back. Tap the next sound.", COLOR_TEXT_TIP)


func _on_back_pressed() -> void:
	if _locked or not _active or _placed.is_empty():
		return
	_placed.pop_back()
	_refresh_slots()
	_set_message("One tile back. Tap the next sound.", COLOR_TEXT_TIP)


func _on_flee_pressed() -> void:
	_request_flee()


func _request_flee() -> void:
	if not _active:
		return
	flee_requested.emit()


func _check_build() -> void:
	if _placed.size() < _tile_count():
		return
	var attempt := ""
	for tile in _placed:
		attempt += String(tile)
	if attempt == String(_entry["word"]):
		_locked = true
		_set_message("Yes! %s - that is one hit." % attempt.to_upper(), COLOR_TEXT_GOOD)
		word_solved.emit(attempt)
	else:
		_set_message("Almost. Take a tile back, check each sound, and try again.", COLOR_TEXT_BAD)


# ------------------------------------------------------------------ building UI

func _tile_count() -> int:
	var tiles: Array = _entry.get("tiles", [])
	return tiles.size()


func _refresh_header() -> void:
	_title.text = "%s wants a word" % _monster_name
	_sub_header.text = "Hits left: %d   -   Level %d: %s" % [_hits_left, _level, OGWords.level_focus(_level)]
	_hint.text = "Meaning hint: %s" % String(_entry.get("hint", ""))
	_sound_caption.text = "Pattern: %s   -   %d sounds. Tap one letter tile for each sound." % [String(_entry.get("pattern", "")), _tile_count()]


func _set_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_sounds() -> void:
	_clear_children(_sound_row)
	for sound in _entry.get("sounds", []):
		_sound_row.add_child(_make_chip(String(sound)))


func _make_chip(text: String) -> Control:
	var panel: Panel = Panel.new()
	panel.custom_minimum_size = Vector2(64, 46)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_CHIP_BG
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = COLOR_CHIP_EDGE
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", COLOR_CHIP_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func _build_slots() -> void:
	_clear_children(_slot_row)
	_slot_buttons.clear()
	for index in _tile_count():
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(62, 62)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_color_override("font_color", COLOR_TEXT_TITLE)
		button.pressed.connect(_on_slot_pressed.bind(index))
		_style_box(button, COLOR_SLOT_EMPTY, COLOR_SLOT_EDGE, 10)
		_slot_row.add_child(button)
		_slot_buttons.append(button)
	_refresh_slots()


func _refresh_slots() -> void:
	for index in _slot_buttons.size():
		var button: Button = _slot_buttons[index]
		if index < _placed.size():
			button.text = String(_placed[index])
			_style_box(button, COLOR_SLOT_FILLED, COLOR_SLOT_EDGE, 10)
		else:
			button.text = ""
			_style_box(button, COLOR_SLOT_EMPTY, COLOR_SLOT_EDGE, 10)


func _build_tiles() -> void:
	_clear_children(_tile_pool)
	for grapheme in OGWords.tile_pool(_entry):
		var text := String(grapheme)
		var button: Button = Button.new()
		button.text = text
		button.custom_minimum_size = Vector2(76, 58)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", COLOR_TEXT_TITLE)
		_style_box(button, Color(1, 1, 1, 1), COLOR_TILE_EDGE, 12)
		button.pressed.connect(_on_tile_pressed.bind(text))
		_tile_pool.add_child(button)


func _style_box(button: Button, fill: Color, edge: Color, radius: int) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.border_color = edge
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
