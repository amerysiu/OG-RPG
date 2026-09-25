extends Control

## The 4-letter word puzzle, now served as an NPC quest inside the village.
##
## The board and the on-screen keyboard are built in code so they always match
## WORD_LENGTH. The village opens this overlay for a quest and closes it when
## the player walks back to the village; solving reports the word back.

signal puzzle_solved(word: String)
signal puzzle_closed

const WORD_LENGTH := 4
const MAX_GUESSES := 5

# Loaded by path so the game always finds its word list, even if the editor's
# global class cache has not picked the script up yet.
const WordSource := preload("res://scripts/word_bank.gd")

const COLOR_TILE_EMPTY := Color(1, 1, 1, 1)
const COLOR_TILE_BORDER := Color(0.72, 0.68, 0.88, 1)
const COLOR_CORRECT := Color(0.36, 0.72, 0.42, 1)
const COLOR_PRESENT := Color(0.95, 0.76, 0.25, 1)
const COLOR_ABSENT := Color(0.63, 0.64, 0.72, 1)
const COLOR_TEXT_EMPTY := Color(0.24, 0.18, 0.42, 1)
const COLOR_TEXT_MARKED := Color(1, 1, 1, 1)
const COLOR_TEXT_NORMAL := Color(0.33, 0.33, 0.45, 1)
const COLOR_TEXT_GOOD := Color(0.12, 0.52, 0.28, 1)
const COLOR_TEXT_BAD := Color(0.76, 0.30, 0.30, 1)
const COLOR_TEXT_TIP := Color(0.20, 0.42, 0.62, 1)

const KEY_ROWS := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

@onready var grid: GridContainer = %Grid
@onready var keyboard: VBoxContainer = %Keyboard
@onready var message_label: Label = %Message
@onready var tip_label: Label = %Tip
@onready var replay_button: Button = %Replay
@onready var close_button: Button = %CloseButton
@onready var title_label: Label = %Title

var _tiles: Array = []
var _target := ""
var _tip := ""
var _guess := ""
var _row := 0
var _finished := true
var _active := false
var _rewarded := false


func _ready() -> void:
	randomize()
	_build_grid()
	_build_keyboard()
	replay_button.pressed.connect(_start_practice_round)
	close_button.pressed.connect(close_puzzle)
	hide()
	_reset_idle()


# ------------------------------------------------------------------ quest API

## Called by the village when an NPC's quest starts.
func start_quest(entry: Dictionary, npc_name: String, quest_hint: String) -> void:
	_apply_entry(entry)
	_active = true
	title_label.text = "%s's word" % npc_name
	var hint := quest_hint.strip_edges()
	if hint.is_empty():
		hint = "Guess the %d-letter word, then press Enter." % WORD_LENGTH
	_set_message(hint, COLOR_TEXT_NORMAL)
	show()


## Closes the overlay and tells the village to restore world movement.
func close_puzzle() -> void:
	_active = false
	_finished = true
	hide()
	puzzle_closed.emit()


func is_active() -> bool:
	return _active


# --------------------------------------------------------------- round setup

func _apply_entry(entry: Dictionary) -> void:
	_target = String(entry["w"]).to_upper()
	_tip = String(entry["tip"])
	_guess = ""
	_row = 0
	_finished = false

	for row in _tiles:
		for tile in row:
			(tile["label"] as Label).text = ""
			_paint_tile(tile, "empty")

	tip_label.text = ""
	replay_button.visible = false


func _reset_idle() -> void:
	_apply_entry({"w": "", "tip": ""})
	_finished = true
	_active = false
	title_label.text = "Word Hunt"
	_set_message("Walk up to a friend in the village to start a word.", COLOR_TEXT_NORMAL)


func _start_practice_round() -> void:
	_apply_entry(WordSource.practice_word(_target))
	_active = true
	title_label.text = "Practice word"
	_set_message("Practice word! Guess the %d-letter word." % WORD_LENGTH, COLOR_TEXT_NORMAL)


func _build_grid() -> void:
	grid.columns = WORD_LENGTH
	_tiles.clear()
	for r in MAX_GUESSES:
		var row: Array = []
		for c in WORD_LENGTH:
			var panel := Panel.new()
			panel.custom_minimum_size = Vector2(64, 64)
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(12)
			style.set_border_width_all(3)
			panel.add_theme_stylebox_override("panel", style)

			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 32)
			panel.add_child(label)
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

			grid.add_child(panel)
			var tile := {"panel": panel, "style": style, "label": label}
			_paint_tile(tile, "empty")
			row.append(tile)
		_tiles.append(row)


func _build_keyboard() -> void:
	for i in KEY_ROWS.size():
		var row_box := HBoxContainer.new()
		row_box.alignment = BoxContainer.ALIGNMENT_CENTER
		row_box.add_theme_constant_override("separation", 6)
		if i == KEY_ROWS.size() - 1:
			row_box.add_child(_make_key("ENTER", "Enter", 82))
		for letter in KEY_ROWS[i]:
			row_box.add_child(_make_key(letter, letter, 52))
		if i == KEY_ROWS.size() - 1:
			row_box.add_child(_make_key("DEL", "Del", 66))
		keyboard.add_child(row_box)


func _make_key(action: String, text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 46)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_on_key_pressed.bind(action))
	return button


# -------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not _active or not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_puzzle()
		return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code: int = event.keycode
	if code >= KEY_A and code <= KEY_Z:
		_type_letter(char(code))
	elif code == KEY_BACKSPACE:
		_delete_letter()
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		_submit()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_key_pressed(action: String) -> void:
	if action == "ENTER":
		_submit()
	elif action == "DEL":
		_delete_letter()
	elif action.length() == 1:
		_type_letter(action)


func _type_letter(letter: String) -> void:
	if _finished or _guess.length() >= WORD_LENGTH:
		return
	_guess += letter
	_refresh_row()


func _delete_letter() -> void:
	if _finished or _guess.is_empty():
		return
	_guess = _guess.substr(0, _guess.length() - 1)
	_refresh_row()


func _refresh_row() -> void:
	var row: Array = _tiles[_row]
	for i in WORD_LENGTH:
		var label: Label = row[i]["label"]
		label.text = _guess[i] if i < _guess.length() else ""


# ------------------------------------------------------------------ scoring

func _submit() -> void:
	if _finished or _row >= MAX_GUESSES:
		return
	if _guess.length() < WORD_LENGTH:
		_set_message("Need %d letters - press Enter when the row is full." % WORD_LENGTH, COLOR_TEXT_BAD)
		return

	var marks := _score_guess(_guess)
	for i in WORD_LENGTH:
		var tile: Dictionary = _tiles[_row][i]
		(tile["label"] as Label).text = _guess[i]
		_paint_tile(tile, marks[i])
		_pop_tile(tile["panel"])

	if _guess == _target:
		_finished = true
		_set_message("You got it: %s! Here is the pattern to remember:" % _target, COLOR_TEXT_GOOD)
		_reveal_tip()
		# Report the solved word once so the village can pay the quest reward.
		if not _rewarded:
			_rewarded = true
			puzzle_solved.emit(_target)
		return

	_row += 1
	if _row >= MAX_GUESSES:
		_finished = true
		_set_message("Good try! The word was %s." % _target, COLOR_TEXT_BAD)
		_reveal_tip()
	else:
		_set_message("Not yet - keep going, you have %d tries left." % (MAX_GUESSES - _row), COLOR_TEXT_NORMAL)


## Wordle-style scoring, correct about repeated letters.
func _score_guess(guess: String) -> Array:
	var marks: Array = []
	marks.resize(WORD_LENGTH)
	var unmatched: Array = []
	for i in WORD_LENGTH:
		if guess[i] == _target[i]:
			marks[i] = "correct"
		else:
			marks[i] = "unmarked"
			unmatched.append(_target[i])
	for i in WORD_LENGTH:
		if marks[i] == "correct":
			continue
		var at: int = unmatched.find(guess[i])
		if at != -1:
			marks[i] = "present"
			unmatched.remove_at(at)
		else:
			marks[i] = "absent"
	return marks


# ------------------------------------------------------------------ visuals

func _paint_tile(tile: Dictionary, state: String) -> void:
	var style: StyleBoxFlat = tile["style"]
	var label: Label = tile["label"]
	match state:
		"correct":
			style.bg_color = COLOR_CORRECT
			style.border_color = COLOR_CORRECT
			label.add_theme_color_override("font_color", COLOR_TEXT_MARKED)
		"present":
			style.bg_color = COLOR_PRESENT
			style.border_color = COLOR_PRESENT
			label.add_theme_color_override("font_color", COLOR_TEXT_MARKED)
		"absent":
			style.bg_color = COLOR_ABSENT
			style.border_color = COLOR_ABSENT
			label.add_theme_color_override("font_color", COLOR_TEXT_MARKED)
		_:
			style.bg_color = COLOR_TILE_EMPTY
			style.border_color = COLOR_TILE_BORDER
			label.add_theme_color_override("font_color", COLOR_TEXT_EMPTY)


func _pop_tile(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.86, 0.86)
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reveal_tip() -> void:
	tip_label.text = "%s  %s" % [_target, _tip]
	tip_label.add_theme_color_override("font_color", COLOR_TEXT_TIP)
	replay_button.visible = true


func _set_message(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
