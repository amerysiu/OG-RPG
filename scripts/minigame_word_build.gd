extends Control
signal word_solved(word: String)
signal flee_requested
signal question_answered(correct: bool, word: String = "")

enum QuestionMode { SPELL, MATCH, MULTIPLE_CHOICE }

const OGWords := preload("res://scripts/og_words.gd")

var _active: bool = false
var _entry: Dictionary = {}
var _placed: Array = []
var _slot_buttons: Array = []
var _question_mode: QuestionMode = QuestionMode.SPELL
var _distractor_count: int = 4

@onready var _sound_row: HBoxContainer = %SoundRow
@onready var _slot_row: HBoxContainer = %SlotRow
@onready var _tile_pool: HFlowContainer = %TilePool
@onready var _message: Label = %Message

func start_encounter(monster_name: String, level: int, hits_left: int, mode: QuestionMode = QuestionMode.SPELL, distractor_count: int = 4) -> void:
	show()
	_placed.clear()
	_question_mode = mode
	_distractor_count = max(1, distractor_count)
	_entry = OGWords.pick_word(level)
	
	# Rebuild child containers programmatically
	_build_ui_nodes()

func _build_ui_nodes() -> void:
	for child in _tile_pool.get_children(): child.queue_free()
	for child in _slot_row.get_children(): child.queue_free()
	_slot_buttons.clear()
	
	match _question_mode:
		QuestionMode.SPELL:
			_build_spell_mode()
		QuestionMode.MATCH:
			_build_match_mode()
		QuestionMode.MULTIPLE_CHOICE:
			_build_multiple_choice_mode()

func _build_spell_mode() -> void:
	var tiles_needed = _entry.get("tiles", [])
	for i in range(tiles_needed.size()):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(60, 60)
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)
		
	var pool_selection = OGWords.tile_pool(_entry)
	for grapheme in pool_selection:
		var tile_btn = Button.new()
		tile_btn.text = String(grapheme)
		tile_btn.custom_minimum_size = Vector2(80, 80)
		tile_btn.pressed.connect(self._on_tile_selected.bind(String(grapheme)))
		_tile_pool.add_child(tile_btn)

func _build_match_mode() -> void:
	var tiles_needed = _entry.get("tiles", [])
	for i in range(tiles_needed.size()):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(60, 60)
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)
	
	var pool_selection = OGWords.tile_pool(_entry, _distractor_count)
	var correct_idx = randi() % pool_selection.size()
	var placed_set = false
	for i, grapheme in pool_selection:
		var tile_btn = Button.new()
		tile_btn.text = String(grapheme)
		tile_btn.custom_minimum_size = Vector2(80, 80)
		var is_correct = not placed_set and i == correct_idx
		if is_correct:
			placed_set = true
		tile_btn.pressed.connect(_on_match_selected.bind(is_correct, String(grapheme)))
		_tile_pool.add_child(tile_btn)

func _build_multiple_choice_mode() -> void:
	var tiles_needed = _entry.get("tiles", [])
	for i in range(tiles_needed.size()):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(60, 60)
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)
	
	var pool_selection = OGWords.tile_pool(_entry, _distractor_count)
	var all_tiles = _entry.get("tiles", []).duplicate()
	all_tiles.append_array(pool_selection)
	all_tiles.shuffle()
	for i, grapheme in all_tiles:
		var tile_btn = Button.new()
		tile_btn.text = String(grapheme)
		tile_btn.custom_minimum_size = Vector2(80, 80)
		tile_btn.pressed.connect(_on_mc_selected.bind(String(grapheme)))
		_tile_pool.add_child(tile_btn)

func _on_tile_selected(grapheme: String) -> void:
	var current_idx = _placed.size()
	var expected = _entry.get("tiles", [])
	
	if grapheme == expected[current_idx]:
		_placed.append(grapheme)
		_slot_buttons[current_idx].text = grapheme
		
		if _placed.size() == expected.size():
			_message.text = "Perfect spelling structural construction!"
			word_solved.emit(String(_entry["word"]))
		else:
			_message.text = "Try that sound block selection position again."
	else:
		_message.text = "Try that sound block selection position again."

func _on_match_selected(is_correct: bool, grapheme: String) -> void:
	if is_correct:
		_message.text = "Correct phoneme-grapheme match!"
		word_solved.emit(String(_entry["word"]))
	else:
		_message.text = "Try matching the sound to the correct grapheme."
	question_answered.emit(false, String(_entry["word"]))

func _on_mc_selected(grapheme: String) -> void:
	var expected = _entry.get("tiles", [])
	var correct_tile = expected[0] if expected.size() > 0 else ""
	if grapheme == correct_tile:
		_message.text = "Correct word construction!"
		word_solved.emit(String(_entry["word"]))
	else:
		_message.text = "Try again - select the correct grapheme."
	question_answered.emit(false, String(_entry["word"]))

func close_overlay() -> void:
	# Hide the interface canvas and drop execution block states cleanly
	_active = false
	hide()
	print("[SYSTEM] Word Build overlay closed successfully.")

func is_active() -> bool:
	return _active