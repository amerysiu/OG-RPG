extends Control

## Audio Shielding - the "Wand Magic" word game.
##
## No word is shown. Each sound of the target word is played in order and the
## player taps the matching tile on the isometric grid to raise a shield. This
## overlay reports facts only: the world decides what a hit or a miss does.
##
##   word_solved(word) - every sound was shielded correctly
##   attack_missed     - the tries ran out

signal word_solved(word: String)
signal attack_missed
signal flee_requested

## A wrong tile costs one try. Running out of tries is a miss.
const MAX_TRIES := 3

var _active := false
var _entry: Dictionary = {}
var _tiles: Array = []
var _index := 0
var _tries := 0
var _audio: AudioStreamPlayer
var _bolt: ColorRect

@onready var _hint: Label = %Hint
@onready var _message: Label = %Message
@onready var _grid: Control = %IsoGrid
@onready var _title: Label = %Title
@onready var _fx: Node2D = %Fx


func _ready() -> void:
	hide()
	set_process(false)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	%FleeButton.pressed.connect(func(): flee_requested.emit())
	%ReplayButton.pressed.connect(_play_current)


func _process(delta: float) -> void:
	if not _active or _bolt == null:
		return
	_bolt.position.y += 70.0 * delta
	_bolt.modulate.a = 0.85
	if _bolt.position.y > 260.0:
		_reset_bolt()
		_message.text = "The spell passed by. Listen again - no harm done."
		_play_current()


func start_encounter(monster_name: String, entry: Dictionary, hits_left: int) -> void:
	_entry = entry
	_tiles = entry.get("tiles", [])
	_index = 0
	_tries = 0
	_active = true
	show()
	set_process(true)
	_title.text = "Wand Magic  ·  %s" % monster_name
	_hint.text = "%s   Hits left: %d" % [String(entry.get("hint", "")), hits_left]
	_message.text = "Listen, then tap the matching tile for each sound. A wrong tile costs one of %d tries; run out and the spell fizzles." % MAX_TRIES
	_rebuild_grid()
	_reset_bolt()
	_play_current()


func set_hits_left(value: int) -> void:
	_hint.text = "%s   Hits left: %d" % [String(_entry.get("hint", "")), value]


func close_overlay() -> void:
	_active = false
	set_process(false)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		flee_requested.emit()
		get_viewport().set_input_as_handled()


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var pool: Array = []
	for t in _tiles:
		pool.append(String(t))
	var extras := ["m", "s", "a", "t", "sh", "ch", "n", "p", "i"]
	for e in extras:
		if pool.size() >= 9:
			break
		if not pool.has(e):
			pool.append(e)
	pool.shuffle()
	var i := 0
	for row in 3:
		for col in 3:
			if i >= pool.size():
				break
			var g := String(pool[i])
			var btn := CombatUI.grapheme_button(g, Vector2(78, 64))
			var iso := Vector2((col - row) * 52.0 + 240.0, (col + row) * 28.0 + 20.0)
			btn.position = iso
			btn.pressed.connect(_on_tile.bind(g))
			_grid.add_child(btn)
			i += 1


func _on_tile(g: String) -> void:
	if _index >= _tiles.size():
		return
	var expected := String(_tiles[_index]).to_lower()
	if g.to_lower() != expected:
		_tries += 1
		_message.text = "Shield missed. That sound was not %s." % expected
		_play_current()
		if _tries >= MAX_TRIES:
			_message.text = "Your shield fails. The spell fizzles - choose an attack again."
			_active = false
			set_process(false)
			attack_missed.emit()
		return
	_index += 1
	_burst()
	_play_tile(g)
	_message.text = "Shield up! Caught %s." % g
	_reset_bolt()
	if _index >= _tiles.size():
		_message.text = "Spell broken with %s!" % String(_entry.get("word", "")).to_upper()
		_active = false
		set_process(false)
		word_solved.emit(String(_entry.get("word", "")))
	else:
		_play_current()


func _reset_bolt() -> void:
	if _bolt == null or not is_instance_valid(_bolt):
		_bolt = ColorRect.new()
		_bolt.size = Vector2(18, 18)
		_bolt.color = Color(0.75, 0.45, 1.0, 0.9)
		_fx.add_child(_bolt)
	_bolt.position = Vector2(310, 8)


func _burst() -> void:
	var p := GPUParticles2D.new()
	p.position = Vector2(320, 120)
	p.amount = 18
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 0.9
	var mat := ParticleProcessMaterial.new()
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 40, 0)
	mat.particle_flag_disable_z = true
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(0.95, 0.85, 0.4, 1)
	p.process_material = mat
	_fx.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _play_current() -> void:
	if _index < _tiles.size():
		_play_tile(String(_tiles[_index]))


func _play_tile(tile: String) -> void:
	var stream := CCAssetFetcher.phoneme_stream(tile)
	if stream != null:
		_audio.stream = stream
		_audio.play()
