extends Control

## The unified word-fight screen: one popup for the whole fight.
##
## A blown-up monster breathes at the top left, the three attack methods sit
## below it, and the Orton-Gillingham question is answered on the right. The
## player - never the monster - chooses the attack, and the attack decides the
## question:
##
##   Light Hit  (sword) - build the word from its sounds, 1 hit
##   Heavy Hit  (sword) - build a harder word, 2 hits
##   Wand Magic (wand)  - listen only, then tap the sounds in order, 1 hit
##
## Three wrong tries end the attack as a miss. This screen reports facts only;
## the world decides what a hit or a miss costs.

signal word_solved(word: String)
signal attack_missed
signal attack_chosen(method: String)
signal flee_requested

const OGWords := preload("res://scripts/og_words.gd")

## Wrong answers on the current sound before the whole attack misses.
const MAX_TRIES := 3
## Gap between phonemes when the word prompt is played.
const PICK_SECONDS := 0.55

var _active := false
var _locked := true
var _defeated := false

var _zone_id := 1
var _level := 1
var _hits_left := 1
var _hits_total := 1
var _monster_name := "Monster"

var _entry: Dictionary = {}
var _tiles: Array = []
var _placed: Array = []
var _slot_buttons: Array = []
var _tries := 0
var _distractors := 4
var _audio_only := false
var _typed := ""
var _exclude: Array = []

var _audio: AudioStreamPlayer
var _idle_tween: Tween
var _sprite_home := Vector2.ZERO

@onready var _sprite: TextureRect = %MonsterSprite
@onready var _sprite_name: Label = %MonsterName
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _attack_prompt: Label = %AttackPrompt
@onready var _light: Button = %LightButton
@onready var _heavy: Button = %HeavyButton
@onready var _magic: Button = %MagicButton
@onready var _prompt: Label = %Prompt
@onready var _sound_row: HBoxContainer = %SoundRow
@onready var _slot_row: HBoxContainer = %SlotRow
@onready var _tile_pool: HFlowContainer = %TilePool
@onready var _message: Label = %Message
@onready var _hear: Button = %HearButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	hide()
	_sprite_home = _sprite.position
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_light.pressed.connect(_on_attack.bind("light"))
	_heavy.pressed.connect(_on_attack.bind("heavy"))
	_magic.pressed.connect(_on_attack.bind("magic"))
	_hear.pressed.connect(_play_word)
	_back.pressed.connect(_take_back)
	%FleeButton.pressed.connect(func(): flee_requested.emit())


# ----------------------------------------------------------------- encounter

## Open the screen for one monster. `texture` is the blown-up portrait.
func open_battle(monster_name: String, texture: Texture2D, zone_id: int, level: int, hits_left: int, hits_total: int) -> void:
	_active = true
	_defeated = false
	_zone_id = maxi(1, zone_id)
	_level = maxi(1, level)
	_monster_name = monster_name
	_hits_total = maxi(1, hits_total)
	_hits_left = hits_left
	_exclude.clear()
	_sprite.texture = texture
	_sprite_name.text = monster_name
	_sprite.position = _sprite_home
	_sprite.scale = Vector2.ONE
	_sprite.modulate = Color.WHITE
	_refresh_hp()
	show()
	begin_round("Choose your attack - each method asks a different question.")


## Back to the attack menu, with a note about what just happened.
func begin_round(note: String) -> void:
	if not _active:
		return
	_locked = false
	_entry = {}
	_tiles = []
	_placed = []
	_typed = ""
	_tries = 0
	_clear_question()
	for button in [_light, _heavy, _magic]:
		button.disabled = false
	_attack_prompt.text = "Choose your attack"
	_prompt.text = "Pick an attack on the left."
	_message.text = note
	_start_idle()


func set_hits_left(value: int) -> void:
	_hits_left = maxi(0, value)
	_refresh_hp()


## Play the monster out: it shrinks and fades.
func show_defeat() -> void:
	_defeated = true
	_stop_idle()
	# Shrink around the sprite's centre, never its top-left corner.
	_sprite.pivot_offset = _sprite.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector2(0.55, 0.55), 0.5)
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 0), 0.5)
	tw.tween_property(_sprite, "position", _sprite_home + Vector2(0, 26), 0.5)


func close_overlay() -> void:
	_active = false
	_locked = true
	_stop_idle()
	_clear_question()
	hide()


# ------------------------------------------------------------------- attacks

func _on_attack(method: String) -> void:
	if not _active or _locked:
		return
	_locked = true
	for button in [_light, _heavy, _magic]:
		button.disabled = true
	_attack_prompt.text = "Answer the question on the right"
	attack_chosen.emit(method)
	match method:
		"heavy":
			_audio_only = false
			_distractors = 6
			_entry = _pick_word(_level + 1)
		"magic":
			_audio_only = true
			_distractors = 4
			_entry = _pick_word(_level)
		_:
			_audio_only = false
			_distractors = 4
			_entry = _pick_word(_level)
	_load_question()


## One word for this attack. `max_level` lets a Heavy Hit reach one step harder.
func _pick_word(max_level: int) -> Dictionary:
	var entry: Dictionary = OGWords.pick_word_for_zone(_zone_id, _level, _exclude, max_level)
	var word := String(entry.get("word", ""))
	if word != "":
		_exclude.append(word)
		if _exclude.size() > 8:
			_exclude.pop_front()
	return entry


func _load_question() -> void:
	_tiles = _entry.get("tiles", [])
	_placed.clear()
	_slot_buttons.clear()
	_typed = ""
	_tries = 0
	_clear_question()
	if _audio_only:
		_prompt.text = "Listen, then tap the matching sounds in order."
	else:
		_prompt.text = "Build the word: tap each sound in order."
		_rebuild_chips()
		_sound_row.show()
	_rebuild_slots()
	_slot_row.show()
	_rebuild_tiles()
	_tile_pool.show()
	_hear.show()
	_back.show()
	_message.text = "A correct answer is a hit. %d wrong tries and the attack misses." % MAX_TRIES
	_play_word()


func _rebuild_chips() -> void:
	for child in _sound_row.get_children():
		child.queue_free()
	for sound in _entry.get("sounds", []):
		var chip := Label.new()
		chip.text = String(sound)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.custom_minimum_size = Vector2(72, 34)
		chip.add_theme_font_size_override("font_size", 18)
		chip.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95, 1))
		_sound_row.add_child(chip)


func _rebuild_slots() -> void:
	for child in _slot_row.get_children():
		child.queue_free()
	for i in _tiles.size():
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.focus_mode = Control.FOCUS_NONE
		slot.disabled = true
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)


func _rebuild_tiles() -> void:
	for child in _tile_pool.get_children():
		child.queue_free()
	for grapheme in OGWords.tile_pool(_entry, _distractors):
		var g := String(grapheme)
		var btn := CombatUI.grapheme_button(g, Vector2(76, 76))
		btn.pressed.connect(_on_tile.bind(g, btn))
		_tile_pool.add_child(btn)


func _clear_question() -> void:
	for row in [_sound_row, _slot_row, _tile_pool]:
		for child in row.get_children():
			child.queue_free()
	_slot_buttons.clear()
	_sound_row.hide()
	_slot_row.hide()
	_tile_pool.hide()
	_hear.hide()
	_back.hide()


# ----------------------------------------------------------------- answering

func _on_tile(g: String, btn: Button) -> void:
	if not _active or _locked or _entry.is_empty():
		return
	if _placed.size() >= _tiles.size():
		return
	_typed = ""
	var expected := String(_tiles[_placed.size()]).to_lower()
	if g.to_lower() != expected:
		_reject(g, expected)
		return
	_accept(g, btn)


## Typing builds up, so sh / ch / th are two keys even though they are one tile.
func _on_typed_letter(letter: String) -> void:
	if _placed.size() >= _tiles.size():
		return
	var expected := String(_tiles[_placed.size()]).to_lower()
	_typed += letter
	if expected.begins_with(_typed):
		if _typed == expected:
			_typed = ""
			_accept(expected, _find_tile_button(expected))
		else:
			_message.text = "Keep going - %s ..." % _typed
		return
	var attempt := _typed
	_typed = ""
	_reject(attempt, expected)


func _find_tile_button(g: String) -> Button:
	for child in _tile_pool.get_children():
		if child is Button and not child.disabled and String(child.text).to_lower() == g.to_lower():
			return child
	return null


func _accept(g: String, btn: Button) -> void:
	if btn != null:
		btn.disabled = true
	_placed.append(g)
	var slot: Button = _slot_buttons[_placed.size() - 1]
	slot.text = g
	if CombatUI.is_vowel(g):
		slot.add_theme_color_override("font_color", CombatUI.COLOR_VOWEL)
	_play_tile(g)
	_message.text = "Yes - %s" % g
	if _placed.size() >= _tiles.size():
		_resolve_hit()


func _reject(attempt: String, expected: String) -> void:
	_tries += 1
	_message.text = "That was %s. Try %s next." % [attempt, expected]
	_play_tile(expected)
	if _tries >= MAX_TRIES:
		_resolve_miss()


func _take_back() -> void:
	if _placed.is_empty() or _locked:
		return
	_placed.pop_back()
	var slot: Button = _slot_buttons[_placed.size()]
	slot.text = ""
	slot.remove_theme_color_override("font_color")
	_message.text = "Take another sound."


func _resolve_hit() -> void:
	_locked = true
	_message.text = "Hit! %s" % String(_entry.get("word", "")).to_upper()
	_play_hit_anim()
	word_solved.emit(String(_entry.get("word", "")))


func _resolve_miss() -> void:
	_locked = true
	_message.text = "No tries left - the attack misses."
	attack_missed.emit()


# --------------------------------------------------------------- monster look

func _start_idle() -> void:
	if not _active or _defeated:
		return
	_stop_idle()
	_sprite.position = _sprite_home
	_idle_tween = create_tween().set_loops()
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(_sprite, "position", _sprite_home + Vector2(0, -10), 1.1)
	_idle_tween.tween_property(_sprite, "position", _sprite_home, 1.1)


func _stop_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null


func _play_hit_anim() -> void:
	_stop_idle()
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 0.5, 0.5, 1), 0.06)
	tw.parallel().tween_property(_sprite, "position", _sprite_home + Vector2(16, 0), 0.06)
	tw.tween_property(_sprite, "position", _sprite_home - Vector2(16, 0), 0.08)
	tw.parallel().tween_property(_sprite, "modulate", Color.WHITE, 0.14)
	tw.tween_property(_sprite, "position", _sprite_home, 0.08)
	tw.tween_callback(_start_idle)


# -------------------------------------------------------------------- audio

func _play_word() -> void:
	if _entry.is_empty():
		return
	_play_next(_tiles, 0)


func _play_next(tiles: Array, i: int) -> void:
	if not _active or i >= tiles.size():
		return
	_play_tile(String(tiles[i]))
	get_tree().create_timer(PICK_SECONDS).timeout.connect(func(): _play_next(tiles, i + 1))


func _play_tile(tile: String) -> void:
	var stream := CCAssetFetcher.phoneme_stream(tile)
	if stream != null:
		_audio.stream = stream
		_audio.play()


# -------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		flee_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _locked or _entry.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var letter := String.chr(event.unicode).to_lower()
		if letter.length() == 1 and letter >= "a" and letter <= "z":
			_on_typed_letter(letter)
			get_viewport().set_input_as_handled()


func _refresh_hp() -> void:
	_hp_bar.max_value = _hits_total
	_hp_bar.value = _hits_left
	_hp_label.text = "HP  %d / %d" % [_hits_left, _hits_total]
