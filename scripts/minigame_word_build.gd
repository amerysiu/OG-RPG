extends Control

signal word_solved(word: String)
signal flee_requested

const OGWords := preload("res://scripts/og_words.gd")

@onready var _sound_row: HBoxContainer = %SoundRow
@onready var _slot_row: HBoxContainer = %SlotRow
@onready var _tile_pool: HFlowContainer = %TilePool
@onready var _message: Label = %Message

var _active: bool = false
var _entry: Dictionary = {}
var _placed: Array = []
var _slot_buttons: Array = []

func start_encounter(monster_name: String, level: int, hits_left: int) -> void:
	show()
	_placed.clear()
	_entry = OGWords.pick_word(level)
	
	# Rebuild child containers programmatically
	_build_ui_nodes()

func _build_ui_nodes() -> void:
	for child in _tile_pool.get_children(): child.queue_free()
	for child in _slot_row.get_children(): child.queue_free()
	_slot_buttons.clear()
	
	# Populate target entry letter blocks sequentially
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
# ==============================================================================
# ENCOUNTER MANAGEMENT LIFECYCLE
# ==============================================================================
func close_overlay() -> void:
	# Hide the interface canvas and drop execution block states cleanly
	_active = false
	hide()
	print("[SYSTEM] Word Build overlay closed successfully.")

func is_active() -> bool:
	return _active
