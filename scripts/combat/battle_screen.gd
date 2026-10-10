extends Control

## The unified word-fight screen: one popup for the whole fight.
##
## A blown-up monster breathes at the top left, the three attack methods sit
## below it, and the Orton-Gillingham question is answered on the right. The
## player - never the monster - chooses the attack, and the attack decides
## which question is asked:
##
##   Light Hit  (sword) - the word is given; click its sounds in order, 1 hit.
##                        Final /k/ words become a Which Spelling? c/k/ck pick.
##   Heavy Hit  (sword) - build a harder word from its letters, 2 hits.
##                        Forge monsters chain two related words.
##   Wand Magic (wand)  - hear the word only, then click its sounds, 1 hit.
##
## The monster's combat mode (speed / audio / forge) stars its signature attack
## so each bestiary type has a visible home. Harder questions carry more
## redundant sounds (or letters) that do not belong in the word. Every click
## plays the sound it stands for. Backspace, or tapping a chosen tile again,
## takes it back.
##
## Three wrong tries end the attack as a miss. This screen reports facts only;
## the world decides what a hit or a miss costs.

signal word_solved(word: String, damage: int)
signal attack_missed
signal attack_chosen(method: String)
signal flee_requested

const OGWords := preload("res://scripts/og_words.gd")

## Wrong answers on the current sound before the whole attack misses.
const MAX_TRIES := 3
## Gap between phonemes when the word prompt is played.
const PICK_SECONDS := 0.55

## Which question the player is answering.
##   BUILD      - tap grapheme (or syllable) tiles to spell the word.
##   PHONEME    - the word is given; click the sounds that make it.
##   SPELL_RULE - Which Spelling? — choose c / k / ck for a final /k/.
enum QMode { BUILD, PHONEME, SPELL_RULE }

var _active := false
var _locked := true
var _defeated := false

var _zone_id := 1
var _level := 1
var _hits_left := 1
var _hits_total := 1
var _monster_name := "Monster"
var _combat_mode := "speed"

var _entry: Dictionary = {}
var _mode: int = QMode.BUILD
var _tiles: Array = []
var _placed: Array = []
var _slot_buttons: Array = []
var _tries := 0
var _damage := 1
var _distractors := 4
var _audio_only := false
var _typed := ""
var _exclude: Array = []

## Word Chain (forge / Heavy Hit): a second word that must be solved after
## the first. Solving only the first word is not a full hit.
var _chain: Dictionary = {}
var _chain_step := 0

## Phoneme-pick state: the correct sound sequence, the clickable tiles (each a
## {"sound", "grapheme", "node"} dictionary) and the tiles chosen so far.
var _phoneme_sounds: Array = []
var _phoneme_tiles: Array = []
var _picked: Array = []

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
## `combat_mode` (speed / audio / forge) marks that type's signature attack.
func open_battle(monster_name: String, texture: Texture2D, zone_id: int, level: int, hits_left: int, hits_total: int, combat_mode: String = "speed") -> void:
	_active = true
	_defeated = false
	_zone_id = maxi(1, zone_id)
	_level = maxi(1, level)
	_monster_name = monster_name
	_combat_mode = combat_mode
	_hits_total = maxi(1, hits_total)
	_hits_left = hits_left
	_exclude.clear()
	_sprite.texture = texture
	_sprite_name.text = monster_name
	_sprite.position = _sprite_home
	_sprite.scale = Vector2.ONE
	_sprite.modulate = Color.WHITE
	_refresh_hp()
	_refresh_signature()
	show()
	begin_round("Sword Light is easier (1 HP). Sword Heavy is harder (2 HP). Wand is listen-only (1 HP).")


## Back to the attack menu, with a note about what just happened.
func begin_round(note: String) -> void:
	if not _active:
		return
	_locked = false
	_entry = {}
	_chain = {}
	_chain_step = 0
	_tiles = []
	_placed = []
	_picked = []
	_phoneme_tiles = []
	_phoneme_sounds = []
	_typed = ""
	_tries = 0
	_clear_question()
	for button in [_light, _heavy, _magic]:
		button.disabled = false
	_attack_prompt.text = "Choose your attack"
	_prompt.text = "Pick Sword Light, Sword Heavy, or Wand Magic."
	_message.text = note
	_start_idle()
	_refresh_signature()


## The monster type's matching attack is starred so bestiary variety is visible.
func _refresh_signature() -> void:
	var labels := {
		"light": "Sword Light  ·  1",
		"heavy": "Sword Heavy  ·  2",
		"magic": "Wand Magic  ·  1",
	}
	var star := {"light": "Sword Light ★  ·  1", "heavy": "Sword Heavy ★  ·  2", "magic": "Wand Magic ★  ·  1"}
	var sig := "light"
	match _combat_mode:
		"audio":
			sig = "magic"
		"forge":
			sig = "heavy"
		_:
			sig = "light"
	_light.text = String(star["light"] if sig == "light" else labels["light"])
	_heavy.text = String(star["heavy"] if sig == "heavy" else labels["heavy"])
	_magic.text = String(star["magic"] if sig == "magic" else labels["magic"])


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
			_mode = QMode.BUILD
			_audio_only = false
			_distractors = 6
			_damage = 2
			_entry = _pick_word(_level + 1)
		"magic":
			_mode = QMode.PHONEME
			_audio_only = true
			_distractors = 3
			_damage = 1
			_entry = _pick_word(_level)
		_:
			_mode = QMode.PHONEME
			_audio_only = false
			_distractors = 2
			_damage = 1
			_entry = _pick_word(maxi(1, _level - 1))
	# A word whose sounds and letters do not line up one-to-one (a two-syllable
	# word) cannot be answered sound by sound, so fall back to spelling it.
	if _mode == QMode.PHONEME and _entry.get("sounds", []).size() != _entry.get("tiles", []).size():
		_mode = QMode.BUILD
	# Which Spelling? for Light Hit on a final /k/ word (c / k / ck rule).
	if _mode == QMode.PHONEME and method == "light" and OGWords.is_which_spelling_k(_entry):
		_mode = QMode.SPELL_RULE
	# Word Chain: forge monsters' Heavy Hit asks two related words in a row.
	_chain = {}
	_chain_step = 0
	if method == "heavy" and _combat_mode == "forge":
		_chain = OGWords.chain_partner(_entry, _exclude)
		var partner := String(_chain.get("word", ""))
		if partner != "":
			_exclude.append(partner)
			if _exclude.size() > 8:
				_exclude.pop_front()
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
	_picked.clear()
	_slot_buttons.clear()
	_phoneme_tiles.clear()
	_typed = ""
	_tries = 0
	_clear_question()
	var chain_note := ""
	if _chain_step > 0:
		chain_note = "  (Word Chain 2 of 2)"
	match _mode:
		QMode.SPELL_RULE:
			_load_spell_rule(chain_note)
		QMode.PHONEME:
			_load_phoneme(chain_note)
		_:
			_load_build(chain_note)
	_hear.show()
	_back.show()
	_message.text = "Land it for %d HP.%s  %d wrong tries and this attack misses." % [_damage, chain_note, MAX_TRIES]
	# The question is ready, so unlock answering. _on_attack locked the screen
	# while it picked the word; without this the tiles and keys stay dead.
	_locked = false
	_play_word()


## Which Spelling? — the word is known; pick c, k or ck for the final /k/.
func _load_spell_rule(chain_note: String) -> void:
	_phoneme_sounds = []
	_prompt.text = "Which spelling makes the final /k/ in %s?%s" % [String(_entry.get("word", "")).to_upper(), chain_note]
	_rebuild_slots(["final /k/"])
	_slot_row.show()
	for child in _tile_pool.get_children():
		child.queue_free()
	for g in ["c", "k", "ck"]:
		var btn := CombatUI.grapheme_button(g, Vector2(96, 76))
		btn.pressed.connect(_on_spell_rule.bind(g, btn))
		_tile_pool.add_child(btn)
	_tile_pool.show()


func _load_phoneme(chain_note: String) -> void:
	_phoneme_sounds = _entry.get("sounds", [])
	if _audio_only:
		_prompt.text = "Listen, then click the sounds you hear.%s" % chain_note
	else:
		_prompt.text = "Which sounds make %s?%s" % [String(_entry.get("word", "")).to_upper(), chain_note]
	_rebuild_slots(_phoneme_sounds)
	_slot_row.show()
	_rebuild_phoneme_tiles()
	_tile_pool.show()


func _load_build(chain_note: String) -> void:
	_phoneme_sounds = []
	if _audio_only:
		_prompt.text = "Listen, then tap the matching sounds in order.%s" % chain_note
	else:
		_prompt.text = "Build the word: tap each sound in order.%s" % chain_note
		_rebuild_chips()
		_sound_row.show()
	_rebuild_slots(_tiles)
	_slot_row.show()
	_rebuild_tiles()
	_tile_pool.show()


## The scaffold row of the target sounds. Hidden when the sounds ARE the answer.
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


## One empty slot per unit the player must supply (letters, or sounds).
func _rebuild_slots(fills: Array) -> void:
	for child in _slot_row.get_children():
		child.queue_free()
	for i in fills.size():
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


## The sound tiles: the sounds of the word, plus redundant sounds that belong to
## other words. Tapping one says it, and the chosen tile stays tappable so it
## can be taken back.
func _rebuild_phoneme_tiles() -> void:
	for child in _tile_pool.get_children():
		child.queue_free()
	var sounds: Array = _entry.get("sounds", [])
	var tiles: Array = _entry.get("tiles", [])
	var entries: Array = []
	for i in sounds.size():
		entries.append({"sound": String(sounds[i]), "grapheme": String(tiles[i])})
	var bank: Dictionary = OGWords.phoneme_bank()
	var extras: Array = []
	for key in bank.keys():
		if not sounds.has(key):
			extras.append({"sound": String(key), "grapheme": String(bank[key])})
	extras.shuffle()
	var added := 0
	for extra in extras:
		if added >= _distractors:
			break
		entries.append(extra)
		added += 1
	entries.shuffle()
	for item in entries:
		var btn := CombatUI.grapheme_button(String(item["sound"]), Vector2(84, 64))
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_phoneme.bind(item, btn))
		_tile_pool.add_child(btn)
		_phoneme_tiles.append({"sound": String(item["sound"]), "grapheme": String(item["grapheme"]), "node": btn})


func _clear_question() -> void:
	for row in [_sound_row, _slot_row, _tile_pool]:
		for child in row.get_children():
			child.queue_free()
	_slot_buttons.clear()
	_picked.clear()
	_phoneme_tiles.clear()
	_sound_row.hide()
	_slot_row.hide()
	_tile_pool.hide()
	_hear.hide()
	_back.hide()


# ------------------------------- answering: build the word from its letters

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


# ------------------------------ answering: click the sounds that make a word

func _on_spell_rule(g: String, btn: Button) -> void:
	if not _active or _locked or _entry.is_empty():
		return
	_play_tile(g)
	var expected := OGWords.which_spelling_k_answer(_entry)
	if g != expected:
		_tries += 1
		_message.text = "Not %s. The word spells it %s." % [g, expected]
		if _tries >= MAX_TRIES:
			_resolve_miss()
		return
	_message.text = "Yes — %s spells the final /k/." % g
	_resolve_hit()


func _on_phoneme(item: Dictionary, btn: Button) -> void:
	if not _active or _locked or _entry.is_empty():
		return
	# Tapping a tile already chosen takes it back - and any pick after it.
	var chosen := _picked_index(btn)
	if chosen != -1:
		_undo_to(chosen)
		return
	if _picked.size() >= _phoneme_sounds.size():
		return
	_play_tile(String(item["grapheme"]))
	var expected := String(_phoneme_sounds[_picked.size()])
	if String(item["sound"]) != expected:
		_reject(String(item["sound"]), expected)
		return
	_picked.append(item)
	btn.modulate = Color(0.55, 0.92, 0.62)
	var slot: Button = _slot_buttons[_picked.size() - 1]
	slot.text = String(item["sound"])
	slot.add_theme_font_size_override("font_size", 20)
	_message.text = "Yes - %s" % String(item["sound"])
	if _picked.size() >= _phoneme_sounds.size():
		_resolve_hit()


func _picked_index(btn: Button) -> int:
	for i in _picked.size():
		if _picked[i].get("node", null) == btn:
			return i
	return -1


## Take back the pick at `index` and everything chosen after it.
func _undo_to(index: int) -> void:
	if index < 0 or index >= _picked.size():
		return
	for i in range(_picked.size() - 1, index - 1, -1):
		var node = _picked[i].get("node", null)
		if node != null and is_instance_valid(node):
			node.modulate = Color.WHITE
		if i < _slot_buttons.size():
			var slot: Button = _slot_buttons[i]
			slot.text = ""
			slot.remove_theme_color_override("font_color")
		_picked.remove_at(i)
	_message.text = "Take another sound."


func _reject(attempt: String, expected: String) -> void:
	_tries += 1
	_message.text = "That was %s. Try %s next." % [attempt, expected]
	if _tries >= MAX_TRIES:
		_resolve_miss()


## The "Take back" button, and Backspace, share this.
func _take_back() -> void:
	if _locked:
		return
	if _mode == QMode.PHONEME:
		_undo_to(_picked.size() - 1)
		return
	if _placed.is_empty():
		return
	_placed.pop_back()
	var slot: Button = _slot_buttons[_placed.size()]
	slot.text = ""
	slot.remove_theme_color_override("font_color")
	_message.text = "Take another sound."


func _resolve_hit() -> void:
	_locked = true
	# Word Chain: the first of two words only advances the chain.
	if not _chain.is_empty() and _chain_step == 0:
		_chain_step = 1
		_message.text = "First word down! Chain the next one — same attack."
		_entry = _chain
		_chain = {}
		var tw := create_tween()
		tw.tween_interval(0.55)
		tw.tween_callback(func():
			if _active:
				_load_question())
		return
	var word := String(_entry.get("word", ""))
	_message.text = "Hit! %s  (−%d HP)" % [word.to_upper(), _damage]
	_play_hit_anim()
	word_solved.emit(word, _damage)


func _resolve_miss() -> void:
	_locked = true
	_message.text = "Miss! The attack did not land."
	_play_miss_anim()
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


func _play_miss_anim() -> void:
	_stop_idle()
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(0.7, 0.75, 0.85, 1), 0.08)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.16)
	tw.tween_callback(_start_idle)


# -------------------------------------------------------------------- audio

func _play_word() -> void:
	if _entry.is_empty():
		return
	_play_next(_tiles, 0)
	# After the sound tiles, say the whole word so the player hears the result.
	var word_stream := CCAssetFetcher.word_stream(String(_entry.get("word", "")))
	if word_stream == null or not _active:
		return
	var total := 0.12
	for tile in _tiles:
		var stream := CCAssetFetcher.phoneme_stream(String(tile))
		total += maxf(PICK_SECONDS, (stream.get_length() if stream != null else 0.25) + 0.12)
	get_tree().create_timer(total).timeout.connect(func():
		if _active:
			_audio.stream = word_stream
			_audio.play())


func _play_next(tiles: Array, i: int) -> void:
	if not _active or i >= tiles.size():
		return
	_play_tile(String(tiles[i]))
	# Cadence must fit the clip: generated phoneme wavs run 0.7-1.3 s.
	var gap := PICK_SECONDS
	var stream := CCAssetFetcher.phoneme_stream(String(tiles[i]))
	if stream != null:
		gap = maxf(PICK_SECONDS, stream.get_length() + 0.12)
	get_tree().create_timer(gap).timeout.connect(func(): _play_next(tiles, i + 1))


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
		if event.keycode == KEY_BACKSPACE:
			_take_back()
			get_viewport().set_input_as_handled()
			return
		if _mode != QMode.BUILD:
			return
		var letter := String.chr(event.unicode).to_lower()
		if letter.length() == 1 and letter >= "a" and letter <= "z":
			_on_typed_letter(letter)
			get_viewport().set_input_as_handled()


func _refresh_hp() -> void:
	_hp_bar.max_value = _hits_total
	_hp_bar.value = _hits_left
	_hp_label.text = "HP  %d / %d" % [_hits_left, _hits_total]
