extends Control

signal word_solved(word: String)
signal flee_requested

const OGWords := preload("res://scripts/og_words.gd")

enum QType { BUILD, CHOICE }

var _active := false
var _entry: Dictionary = {}
var _placed: Array = []
var _hits_left := 0
var _hits_total := 1
var _qtype: int = QType.BUILD
var _audio: AudioStreamPlayer
var _slot_buttons: Array = []

@onready var _monster_sprite: TextureRect = %MonsterSprite
@onready var _monster_name: Label = %MonsterName
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _backdrop: TextureRect = %Backdrop
@onready var _prompt: Label = %Prompt
@onready var _pattern: Label = %Pattern
@onready var _sound_row: HBoxContainer = %SoundRow
@onready var _slot_row: HBoxContainer = %SlotRow
@onready var _tile_pool: HFlowContainer = %TilePool
@onready var _choice_box: VBoxContainer = %ChoiceBox
@onready var _message: Label = %Message
@onready var _monster_anchor: Control = %MonsterAnchor
@onready var _slash: ColorRect = %Slash


func _ready() -> void:
	hide()
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	%FleeButton.pressed.connect(func(): flee_requested.emit())
	%HearButton.pressed.connect(_play_word)
	%BackButton.pressed.connect(_take_back)
	_slash.visible = false


func start_encounter(monster_name: String, entry: Dictionary, hits_left: int, hits_total: int, texture: Texture2D, zone_id: int) -> void:
	_active = true
	_hits_left = hits_left
	_hits_total = maxi(1, hits_total)
	_monster_name.text = monster_name
	_monster_sprite.texture = texture
	_backdrop.texture = CCAssetFetcher.backdrop_for_zone(zone_id)
	_hp_bar.max_value = _hits_total
	_refresh_hp()
	show()
	_load_question(entry)


func set_hits_left(value: int) -> void:
	_hits_left = value
	_refresh_hp()


func next_round(entry: Dictionary) -> void:
	_load_question(entry)


func play_hit() -> void:
	_slash.visible = true
	_slash.modulate.a = 0.95
	var start := _monster_anchor.position
	var tw := create_tween()
	tw.tween_property(_monster_anchor, "position", start + Vector2(18, 0), 0.06)
	tw.tween_property(_monster_anchor, "modulate", Color(1.0, 0.45, 0.45, 1), 0.05)
	tw.tween_property(_monster_anchor, "position", start, 0.1)
	tw.tween_property(_monster_anchor, "modulate", Color.WHITE, 0.12)
	tw.parallel().tween_property(_slash, "modulate:a", 0.0, 0.18)
	tw.finished.connect(func(): _slash.visible = false)


func close_overlay() -> void:
	_active = false
	hide()
	_clear_rows()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		flee_requested.emit()
		get_viewport().set_input_as_handled()


func _load_question(entry: Dictionary) -> void:
	_entry = entry
	_placed.clear()
	var tiles: Array = entry.get("tiles", [])
	if tiles.size() <= 1:
		_qtype = QType.CHOICE
	elif randf() < 0.4:
		_qtype = QType.CHOICE
	else:
		_qtype = QType.BUILD
	_pattern.text = String(entry.get("pattern", ""))
	_message.text = "A correct answer is one hit."
	if _qtype == QType.BUILD:
		_setup_build()
	else:
		_setup_choice()
	_play_word()


func _setup_build() -> void:
	_choice_box.hide()
	_sound_row.show()
	_slot_row.show()
	_tile_pool.show()
	%BackButton.show()
	_prompt.text = "Build the word. Tap each sound in order."
	_rebuild_elkonin()
	_rebuild_tiles(OGWords.tile_pool(_entry, 4))


func _setup_choice() -> void:
	_sound_row.hide()
	_slot_row.hide()
	_tile_pool.hide()
	%BackButton.hide()
	_choice_box.show()
	for child in _choice_box.get_children():
		child.queue_free()
	var tiles: Array = _entry.get("tiles", [])
	if tiles.size() <= 1:
		_prompt.text = "Which letter makes this sound?"
		_rebuild_elkonin()
		_sound_row.show()
		var options: Array = OGWords.tile_pool(_entry, 3)
		for g in options:
			_choice_box.add_child(_choice_button(String(g), String(g) == String(tiles[0])))
	else:
		_prompt.text = String(_entry.get("hint", "Which word is this?"))
		_rebuild_elkonin()
		_sound_row.show()
		var correct := String(_entry.get("word", ""))
		var options: Array = [correct]
		var pool: Array = OGWords.words_for_zone(int(_entry.get("zone", 2)))
		if pool.is_empty():
			pool = OGWords.WORDS.duplicate()
		pool.shuffle()
		for other in pool:
			var w := String(other.get("word", ""))
			if w != correct and not options.has(w):
				options.append(w)
			if options.size() >= 3:
				break
		options.shuffle()
		for w in options:
			_choice_box.add_child(_choice_button(w.to_upper(), w == correct))


func _choice_button(label: String, is_correct: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 24)
	if CombatUI.is_vowel(label.to_lower()) and label.length() <= 2:
		btn.add_theme_color_override("font_color", CombatUI.COLOR_VOWEL)
	btn.pressed.connect(_on_choice.bind(is_correct, label))
	return btn


func _on_choice(is_correct: bool, label: String) -> void:
	if not _active:
		return
	if is_correct:
		_message.text = "Hit!"
		word_solved.emit(String(_entry.get("word", label)))
	else:
		_message.text = "Not that one. Listen again."
		_play_word()


func _rebuild_elkonin() -> void:
	for child in _sound_row.get_children():
		child.queue_free()
	for child in _slot_row.get_children():
		child.queue_free()
	_slot_buttons.clear()
	var sounds: Array = _entry.get("sounds", [])
	var tiles: Array = _entry.get("tiles", [])
	for i in sounds.size():
		var chip := Label.new()
		chip.text = String(sounds[i])
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.custom_minimum_size = Vector2(64, 36)
		chip.add_theme_font_size_override("font_size", 18)
		chip.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95, 1))
		_sound_row.add_child(chip)
	for i in tiles.size():
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.focus_mode = Control.FOCUS_NONE
		slot.disabled = true
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)


func _rebuild_tiles(pool: Array) -> void:
	for child in _tile_pool.get_children():
		child.queue_free()
	for grapheme in pool:
		var g := String(grapheme)
		var btn := CombatUI.grapheme_button(g, Vector2(72, 72))
		btn.pressed.connect(_on_tile.bind(g, btn))
		_tile_pool.add_child(btn)


func _on_tile(grapheme: String, btn: Button) -> void:
	if not _active or _qtype != QType.BUILD:
		return
	var expected: Array = _entry.get("tiles", [])
	if _placed.size() >= expected.size():
		return
	if grapheme != String(expected[_placed.size()]):
		_message.text = "Try the next sound again."
		_play_tile(String(expected[_placed.size()]))
		return
	_placed.append(grapheme)
	btn.disabled = true
	var slot: Button = _slot_buttons[_placed.size() - 1]
	slot.text = grapheme
	if CombatUI.is_vowel(grapheme):
		slot.add_theme_color_override("font_color", CombatUI.COLOR_VOWEL)
	_play_tile(grapheme)
	if _placed.size() == expected.size():
		_message.text = "Hit!"
		word_solved.emit(String(_entry["word"]))


func _take_back() -> void:
	if _placed.is_empty():
		return
	_placed.pop_back()
	var slot: Button = _slot_buttons[_placed.size()]
	slot.text = ""
	_message.text = "Take another sound."


func _play_word() -> void:
	var tiles: Array = _entry.get("tiles", [])
	_play_next(tiles, 0)
	# After the sound tiles, say the whole word so the player hears the result.
	var word_stream := CCAssetFetcher.word_stream(String(_entry.get("word", "")))
	if word_stream == null:
		return
	var total := 0.12
	for tile in tiles:
		var stream := CCAssetFetcher.phoneme_stream(String(tile))
		total += maxf(0.55, (stream.get_length() if stream != null else 0.25) + 0.12)
	get_tree().create_timer(total).timeout.connect(func():
		_audio.stream = word_stream
		_audio.play())


func _play_next(tiles: Array, i: int) -> void:
	if i >= tiles.size():
		return
	_play_tile(String(tiles[i]))
	# Cadence must fit the clip: generated phoneme wavs run 0.7-1.3 s.
	var gap := 0.55
	var stream := CCAssetFetcher.phoneme_stream(String(tiles[i]))
	if stream != null:
		gap = maxf(0.55, stream.get_length() + 0.12)
	get_tree().create_timer(gap).timeout.connect(func(): _play_next(tiles, i + 1))


func _play_tile(tile: String) -> void:
	var stream := CCAssetFetcher.phoneme_stream(tile)
	if stream != null:
		_audio.stream = stream
		_audio.play()


func _refresh_hp() -> void:
	_hp_bar.max_value = _hits_total
	_hp_bar.value = _hits_left
	_hp_label.text = "HP  %d / %d" % [_hits_left, _hits_total]


func _clear_rows() -> void:
	for row in [_sound_row, _slot_row, _tile_pool, _choice_box]:
		if row == null:
			continue
		for child in row.get_children():
			child.queue_free()
	_slot_buttons.clear()
