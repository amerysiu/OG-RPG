extends Control

signal word_solved(word: String)
signal flee_requested

const TRACES := {
	"a": ["move_left", "move_down", "move_right", "move_up"],
	"e": ["move_right", "move_down", "move_left"],
	"i": ["move_down", "move_up"],
	"o": ["move_right", "move_down", "move_left", "move_up"],
	"u": ["move_down", "move_right", "move_up"],
	"m": ["move_up", "move_down", "move_up", "move_down"],
	"n": ["move_up", "move_down", "move_up"],
	"s": ["move_right", "move_down", "move_left", "move_down", "move_right"],
	"t": ["move_right", "move_down"],
	"p": ["move_up", "move_right", "move_down"],
	"c": ["move_left", "move_down", "move_right"],
	"d": ["move_down", "move_right", "move_up"],
	"r": ["move_up", "move_right", "move_down"],
	"l": ["move_down", "move_right"],
	"b": ["move_up", "move_right", "move_down", "move_right"],
	"f": ["move_up", "move_right"],
	"g": ["move_left", "move_down", "move_right", "move_up"],
	"h": ["move_down", "move_up", "move_right", "move_down"],
	"k": ["move_down", "move_right"],
	"w": ["move_down", "move_up", "move_down", "move_up"],
	"y": ["move_down", "move_right"],
	"sh": ["move_right", "move_down", "move_left", "move_down", "move_right"],
	"ch": ["move_left", "move_down", "move_right"],
	"th": ["move_right", "move_down"],
	"ck": ["move_left", "move_down", "move_right"],
}

const ARROWS := {
	"move_up": "↑",
	"move_down": "↓",
	"move_left": "←",
	"move_right": "→",
}

var _active := false
var _entry: Dictionary = {}
var _tiles: Array = []
var _tile_index := 0
var _step := 0
var _trace: Array = []
var _audio: AudioStreamPlayer

@onready var _hint: Label = %Hint
@onready var _message: Label = %Message
@onready var _trace_row: HBoxContainer = %TraceRow
@onready var _title: Label = %Title
@onready var _glyph: Label = %Glyph
@onready var _path: Line2D = %TracePath


func _ready() -> void:
	hide()
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	%FleeButton.pressed.connect(func(): flee_requested.emit())


func start_encounter(monster_name: String, entry: Dictionary, hits_left: int) -> void:
	_entry = entry
	_tiles = entry.get("tiles", [])
	_tile_index = 0
	_active = true
	show()
	_title.text = "Kinesthetic Forging  ·  %s" % monster_name
	_hint.text = "%s   Hits left: %d" % [String(entry.get("hint", "")), hits_left]
	_message.text = "Trace each sound-shape with WASD or the arrow keys, like writing in the air."
	_begin_tile()


func set_hits_left(value: int) -> void:
	_hint.text = "%s   Hits left: %d" % [String(_entry.get("hint", "")), value]


func next_round() -> void:
	_tile_index = 0
	_begin_tile()


func close_overlay() -> void:
	_active = false
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		flee_requested.emit()
		get_viewport().set_input_as_handled()
		return
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		if event.is_action_pressed(action):
			_on_trace(action)
			get_viewport().set_input_as_handled()
			return


func _begin_tile() -> void:
	if _tile_index >= _tiles.size():
		word_solved.emit(String(_entry["word"]))
		return
	var tile := String(_tiles[_tile_index]).to_lower()
	_trace = TRACES.get(tile, TRACES.get(tile.substr(0, 1), ["move_down", "move_up"]))
	_step = 0
	_glyph.text = String(_tiles[_tile_index])
	if CombatUI.is_vowel(tile):
		_glyph.add_theme_color_override("font_color", CombatUI.COLOR_VOWEL)
	else:
		_glyph.add_theme_color_override("font_color", CombatUI.COLOR_CONSONANT)
	_refresh_trace_row()
	_draw_path()
	_play_tile(tile)


func _on_trace(action: String) -> void:
	if _step >= _trace.size():
		return
	if action != String(_trace[_step]):
		_message.text = "Feel the shape again. Next stroke: %s" % ARROWS.get(String(_trace[_step]), "?")
		return
	_step += 1
	_refresh_trace_row()
	if _step >= _trace.size():
		_message.text = "Forged %s." % String(_tiles[_tile_index])
		_tile_index += 1
		if _tile_index >= _tiles.size():
			_message.text = "The rune is complete: %s!" % String(_entry.get("word", "")).to_upper()
			word_solved.emit(String(_entry["word"]))
		else:
			_begin_tile()


func _refresh_trace_row() -> void:
	for child in _trace_row.get_children():
		child.queue_free()
	for i in _trace.size():
		var lab := Label.new()
		lab.text = ARROWS.get(String(_trace[i]), "?")
		lab.add_theme_font_size_override("font_size", 32)
		if i < _step:
			lab.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55, 1))
		elif i == _step:
			lab.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 1))
		else:
			lab.add_theme_color_override("font_color", Color(0.7, 0.72, 0.85, 1))
		_trace_row.add_child(lab)


func _draw_path() -> void:
	_path.clear_points()
	var cursor := Vector2(0, 0)
	_path.add_point(cursor)
	for action in _trace:
		match String(action):
			"move_up":
				cursor += Vector2(0, -46)
			"move_down":
				cursor += Vector2(0, 46)
			"move_left":
				cursor += Vector2(-46, 0)
			"move_right":
				cursor += Vector2(46, 0)
		_path.add_point(cursor)


func _play_tile(tile: String) -> void:
	var stream := CCAssetFetcher.phoneme_stream(tile)
	if stream != null:
		_audio.stream = stream
		_audio.play()
