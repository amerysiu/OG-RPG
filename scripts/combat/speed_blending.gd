extends Control

## Speed Blending - the "Light Hit" word game.
##
## The player reads the grapheme tiles and taps them in the order of the sounds
## of the target word. This overlay reports facts only: the world decides what a
## hit or a miss does.
##
##   word_solved(word) - the whole word was built correctly
##   attack_missed     - every try was used up, so the attack missed

signal word_solved(word: String)
signal attack_missed
signal flee_requested

## A wrong tap costs one try. Running out of tries is a miss.
const MAX_TRIES := 3

var _active := false
var _entry: Dictionary = {}
var _tiles: Array = []
var _index := 0
var _tries := 0
var _stream := 1.0
var _flyers: Array = []
var _audio: AudioStreamPlayer

@onready var _hint: Label = %Hint
@onready var _message: Label = %Message
@onready var _stream_bar: ProgressBar = %StreamBar
@onready var _lane: Control = %Lane
@onready var _title: Label = %Title


func _ready() -> void:
	hide()
	set_process(false)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	%FleeButton.pressed.connect(func(): flee_requested.emit())


func _process(delta: float) -> void:
	if not _active:
		return
	_stream -= delta * 0.12
	if _stream <= 0.0:
		_stream = 1.0
		_message.text = "The blend stream loops. Listen again and catch the next sound."
		_rebuild_flyers()
	_stream_bar.value = _stream * 100.0
	for flyer in _flyers:
		if not is_instance_valid(flyer):
			continue
		flyer.position.x += 90.0 * delta
		if flyer.position.x > maxf(780.0, _lane.size.x) - 20.0:
			flyer.position.x = -80.0


func start_encounter(monster_name: String, entry: Dictionary, hits_left: int) -> void:
	_entry = entry
	_tiles = entry.get("tiles", [])
	_index = 0
	_tries = 0
	_stream = 1.0
	_active = true
	show()
	set_process(true)
	_title.text = "Light Hit  ·  %s" % monster_name
	_hint.text = "%s   Hits left: %d" % [String(entry.get("hint", "")), hits_left]
	_message.text = "Tap the sounds in order. A wrong tap costs one of %d tries; run out and the hit misses." % MAX_TRIES
	_rebuild_flyers()
	_play_current()


func set_hits_left(value: int) -> void:
	_hint.text = "%s   Hits left: %d" % [String(_entry.get("hint", "")), value]


func close_overlay() -> void:
	_active = false
	set_process(false)
	hide()
	_clear_flyers()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		flee_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var typed := String.chr(event.unicode).to_lower()
		if typed.length() == 1:
			_try_grapheme(typed)
			get_viewport().set_input_as_handled()


func _rebuild_flyers() -> void:
	_clear_flyers()
	for i in _tiles.size():
		var g := String(_tiles[i])
		var btn := CombatUI.grapheme_button(g, Vector2(72, 72))
		btn.position = Vector2(40 + i * 110, 18)
		btn.pressed.connect(_try_grapheme.bind(g))
		_lane.add_child(btn)
		_flyers.append(btn)


func _clear_flyers() -> void:
	for flyer in _flyers:
		if is_instance_valid(flyer):
			flyer.queue_free()
	_flyers.clear()


func _try_grapheme(g: String) -> void:
	if _index >= _tiles.size():
		return
	var expected := String(_tiles[_index]).to_lower()
	if g.to_lower() != expected:
		_tries += 1
		_message.text = "That was %s. Try %s next." % [g, expected]
		_play_tile(expected)
		if _tries >= MAX_TRIES:
			_message.text = "No tries left. The hit misses - choose an attack again."
			_active = false
			set_process(false)
			attack_missed.emit()
		return
	_index += 1
	_play_tile(g)
	_message.text = "Yes - %s" % g
	if _index >= _tiles.size():
		_message.text = "Blended %s! Hit!" % String(_entry.get("word", "")).to_upper()
		_active = false
		set_process(false)
		word_solved.emit(String(_entry.get("word", "")))


func _play_current() -> void:
	if _index < _tiles.size():
		_play_tile(String(_tiles[_index]))


func _play_tile(tile: String) -> void:
	var stream := CCAssetFetcher.phoneme_stream(tile)
	if stream != null:
		_audio.stream = stream
		_audio.play()
