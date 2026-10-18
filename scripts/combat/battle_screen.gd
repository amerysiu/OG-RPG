extends Control

## The unified word-fight screen: one popup for the whole fight.
##
## The player - never the monster - chooses the attack, and the attack decides
## which OG question is asked (see QuestionFactory):
##
##   Wand Magic  - a LISTENING question on the monster's stage       1 hit
##   Light Hit   - a REVIEW question on a stage already mastered      1 hit
##   Heavy Hit   - SPELL / BUILD the stage's pattern (one tier harder) 2 hits
##
## Difficulty (Easy / Normal / Hard) comes from the Learner profile and only
## changes scaffolding: rule cards, audio, distractors, tries and hints.
## Easy never misses: after two slips the answer is modelled and the child
## finishes it (OG error correction). Every answered item is recorded so the
## stage can be mastered.
##
## This screen reports facts only; the world decides what a hit or miss costs.

signal word_solved(word: String, damage: int)
signal attack_missed
signal attack_chosen(method: String)
signal flee_requested
signal progress_event(text: String)

## Gap between clips when a sequence is played.
const PICK_SECONDS := 0.5
## Silence after the full sequence before it repeats once (Easy only).
const REPEAT_DELAY_SECONDS := 2.0
const COLOR_GOOD := Color(0.55, 0.92, 0.62)
const COLOR_HINT := Color(1.0, 0.9, 0.45)
const COLOR_BAD := Color(1.0, 0.55, 0.55)

var _active := false
var _locked := true
var _defeated := false

var _info: Dictionary = {}
var _hits_left := 1
var _hits_total := 1
var _exclude: Array = []

var _q: Dictionary = {}
var _method := "light"
var _errors := 0
var _step_errors := 0
var _hinted := false
var _modelled := false
var _typed := ""

## Per-kind answer state.
var _placed: Array = []
var _slot_buttons: Array = []
var _tile_buttons: Array = []
var _picked: Array = []
var _option_buttons: Array = []
var _selected := -1
var _count := 0
var _cut_buttons: Array = []
var _cuts: Array = []

var _play_gen := 0
var _audio: AudioStreamPlayer
var _idle_tween: Tween
var _sprite_home := Vector2.ZERO

var _header: Label
var _rule: Label
var _check: Button
var _hint: Button
var _type_edit: LineEdit

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
	_build_extra_nodes()
	_light.pressed.connect(_on_attack.bind("light"))
	_heavy.pressed.connect(_on_attack.bind("heavy"))
	_magic.pressed.connect(_on_attack.bind("wand"))
	_hear.pressed.connect(_play_question_audio)
	_back.pressed.connect(_take_back)
	_check.pressed.connect(_on_check)
	_hint.pressed.connect(_on_hint)
	%FleeButton.pressed.connect(func(): flee_requested.emit())
	for b in [_light, _heavy, _magic]:
		b.custom_minimum_size = Vector2(140, 62)
		b.add_theme_font_size_override("font_size", 16)


func _build_extra_nodes() -> void:
	var qbox: VBoxContainer = _prompt.get_parent()
	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", 15)
	_header.add_theme_color_override("font_color", Color(0.62, 0.8, 1.0, 1))
	qbox.add_child(_header)
	qbox.move_child(_header, 0)
	_rule = Label.new()
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rule.add_theme_font_size_override("font_size", 16)
	_rule.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1))
	qbox.add_child(_rule)
	qbox.move_child(_rule, 2)
	_type_edit = LineEdit.new()
	_type_edit.custom_minimum_size = Vector2(320, 56)
	_type_edit.add_theme_font_size_override("font_size", 30)
	_type_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_edit.placeholder_text = "type here"
	_type_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_type_edit.text_submitted.connect(func(_t): _on_check())
	qbox.add_child(_type_edit)
	qbox.move_child(_type_edit, _slot_row.get_index() + 1)
	_type_edit.hide()
	var row: HBoxContainer = _hear.get_parent()
	_check = Button.new()
	_check.text = "Done ✓"
	_check.custom_minimum_size = Vector2(130, 40)
	_check.focus_mode = Control.FOCUS_NONE
	row.add_child(_check)
	_hint = Button.new()
	_hint.text = "Hint"
	_hint.custom_minimum_size = Vector2(100, 40)
	_hint.focus_mode = Control.FOCUS_NONE
	row.add_child(_hint)
	_check.hide()
	_hint.hide()


# ----------------------------------------------------------------- encounter

## info: name, zone, stage, kind (stage|boss|heart|quest), stages (boss pool),
## combat_mode (speed|audio|forge), hits_left, hits_total.
func open_battle(info: Dictionary, texture: Texture2D) -> void:
	_active = true
	_defeated = false
	_info = info
	_hits_total = maxi(1, int(info.get("hits_total", 3)))
	_hits_left = int(info.get("hits_left", _hits_total))
	_exclude.clear()
	_sprite.texture = texture
	_sprite_name.text = String(info.get("name", "Monster"))
	_sprite.position = _sprite_home
	_sprite.scale = Vector2.ONE
	_sprite.modulate = Color.WHITE
	_refresh_hp()
	_refresh_signature()
	show()
	begin_round("Wand = listen (1).  Light = review (1).  Heavy = spell it (2).")


func begin_round(note: String) -> void:
	if not _active:
		return
	_locked = false
	_q = {}
	_clear_question()
	for button in [_light, _heavy, _magic]:
		button.disabled = false
	_attack_prompt.text = "Choose your attack"
	var sid := _base_stage()
	var tier := Learner.tier_for(sid).capitalize() if Learner.has_method("tier_for") else "Normal"
	_header.text = "%s   ·   %s" % [OGCurriculum.label(sid), tier]
	_prompt.text = "Pick Wand Magic, Sword Light, or Sword Heavy."
	_rule.text = ""
	_message.text = note
	_start_idle()
	_refresh_signature()


func _base_stage() -> String:
	var kind := String(_info.get("kind", "stage"))
	if kind == "heart":
		return "H1"
	if kind == "quest":
		return "R1"
	if kind == "boss":
		var pool: Array = _info.get("stages", [])
		return String(pool[pool.size() - 1]) if not pool.is_empty() else String(_info.get("stage", "C1"))
	return String(_info.get("stage", "C1"))


func _refresh_signature() -> void:
	var sig := "light"
	match String(_info.get("combat_mode", "speed")):
		"audio":
			sig = "wand"
		"forge":
			sig = "heavy"
	var star := func(key: String, text: String) -> String:
		return text.replace("·", "★ ·") if key == sig else text
	_magic.text = star.call("wand", "Wand Magic · 1\nlisten")
	_light.text = star.call("light", "Sword Light · 1\nreview")
	_heavy.text = star.call("heavy", "Sword Heavy · 2\nspell it")


func set_hits_left(value: int) -> void:
	_hits_left = maxi(0, value)
	_refresh_hp()


func show_defeat() -> void:
	_defeated = true
	_stop_idle()
	_sprite.pivot_offset = _sprite.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector2(0.55, 0.55), 0.5)
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 0), 0.5)
	tw.tween_property(_sprite, "position", _sprite_home + Vector2(0, 26), 0.5)


func close_overlay() -> void:
	_active = false
	_locked = true
	_play_gen += 1
	_stop_idle()
	_clear_question()
	hide()


## The question currently on screen (tests use this).
func current_question() -> Dictionary:
	return _q


# ------------------------------------------------------------------- attacks

func _on_attack(method: String) -> void:
	if not _active or _locked:
		return
	_locked = true
	for button in [_light, _heavy, _magic]:
		button.disabled = true
	_method = method
	_attack_prompt.text = "Answer the question on the right"
	attack_chosen.emit(method)
	_q = QuestionFactory.make(_question_context(method))
	var word := String(_q.get("word", ""))
	if word != "":
		_exclude.append(word)
		while _exclude.size() > 8:
			_exclude.pop_front()
	_load_question()


func _question_context(method: String) -> Dictionary:
	var base := _base_stage()
	var stage_id := base
	var kind := String(_info.get("kind", "stage"))
	if kind == "boss":
		var pool: Array = _info.get("stages", [])
		if not pool.is_empty():
			stage_id = String(pool[randi() % pool.size()])
	if method == "light":
		var review := Learner.review_stage(stage_id)
		if review != "":
			stage_id = review
	elif kind == "quest" and method == "heavy":
		stage_id = "R1"
	return {
		"stage": stage_id,
		"attack": method,
		"tier": Learner.tier_index(base),
		"exclude": _exclude,
		"band": Learner.reached_band(),
		"review_stages": Learner.mastered_stages(),
	}


func _load_question() -> void:
	_clear_question()
	_errors = 0
	_step_errors = 0
	_hinted = false
	_modelled = false
	_typed = ""
	var tier_name: String = QuestionFactory.TIER[int(_q.get("tier", 1))]["name"]
	_header.text = "%s   ·   %s   ·   %s" % [OGCurriculum.label(String(_q["stage"])), String(_q.get("mode_name", "")), tier_name]
	_prompt.text = String(_q.get("prompt", ""))
	var rule := String(_q.get("rule", ""))
	var meaning := String(_q.get("meaning", ""))
	_rule.text = ("Rule: " + rule if rule != "" else "") + ("\n" if rule != "" and meaning != "" else "") + meaning
	match String(_q.get("kind", "build")):
		"build":
			_load_build()
		"phoneme":
			_load_phoneme()
		"choice":
			_load_choice()
		"count":
			_load_count()
		"split":
			_load_split()
		"type":
			_load_type()
	_hear.visible = not _q.get("audio", []).is_empty()
	_hint.visible = int(_q.get("tier", 1)) > 0 and String(_q.get("kind", "")) in ["build", "phoneme", "choice", "type"]
	var tries := int(_q.get("tries", 3))
	if tries > 0 and String(_q.get("kind", "")) == "choice":
		# Never let a child win by elimination: you may slip at most once per
		# wrong option, minus one (a 2-option item misses on the first slip).
		var wrong := 0
		for o in _q.get("options", []):
			if not bool(o["correct"]):
				wrong += 1
		tries = clampi(mini(tries, wrong), 1, tries)
		_q["tries"] = tries
	if tries < 0:
		_message.text = "Land it for %d HP. Take your time." % int(_q.get("damage", 1))
	else:
		_message.text = "Land it for %d HP.  %d slips and this attack misses." % [int(_q.get("damage", 1)), tries]
	_locked = false
	_play_question_audio()


# ------------------------------------------------------------------ build

func _load_build() -> void:
	var tiles: Array = _q["tiles"]
	if bool(_q.get("chips", false)):
		for sound in _q.get("sounds", []):
			var chip := Label.new()
			chip.text = String(sound) if String(sound) != "-" else "(silent)"
			chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.custom_minimum_size = Vector2(72, 34)
			chip.add_theme_font_size_override("font_size", 18)
			chip.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95, 1))
			_sound_row.add_child(chip)
		_sound_row.show()
	_rebuild_slots(tiles.size())
	var syllabic := false
	for t in tiles:
		if String(t).length() > 3:
			syllabic = true
	for g in _q.get("pool", []):
		var text := String(g)
		var size := Vector2(76, 76) if not syllabic else Vector2(120, 70)
		var btn := CombatUI.grapheme_button(text, size)
		btn.pressed.connect(_on_build_tile.bind(text, btn))
		_tile_pool.add_child(btn)
		_tile_buttons.append(btn)
	_tile_pool.show()
	_back.show()


func _on_build_tile(g: String, btn: Button) -> void:
	if not _ready_for_input():
		return
	var tiles: Array = _q["tiles"]
	if _placed.size() >= tiles.size():
		return
	_typed = ""
	var expected := String(tiles[_placed.size()]).to_lower()
	if g.to_lower() != expected:
		if bool(_q.get("tile_audio", true)):
			_play_refs([{"u": ["", g]}])
		_slip(g, expected, btn)
		return
	_accept_build(expected, btn)


func _on_typed_letter(letter: String) -> void:
	var tiles: Array = _q["tiles"]
	if _placed.size() >= tiles.size():
		return
	var expected := String(tiles[_placed.size()]).to_lower()
	_typed += letter
	if expected.begins_with(_typed):
		if _typed == expected:
			_typed = ""
			_accept_build(expected, _find_tile_button(expected))
		else:
			_message.text = "Keep going - %s ..." % _typed
		return
	var attempt := _typed
	_typed = ""
	_slip(attempt, expected, null)


func _find_tile_button(g: String) -> Button:
	for b in _tile_buttons:
		if is_instance_valid(b) and not b.disabled and String(b.text).to_lower() == g.to_lower():
			return b
	return null


func _accept_build(g: String, btn: Button) -> void:
	if btn != null:
		btn.disabled = true
		btn.modulate = Color.WHITE
	_step_errors = 0
	var i := _placed.size()
	_placed.append(g)
	var slot: Button = _slot_buttons[i]
	slot.text = g
	if CombatUI.is_vowel(g):
		slot.add_theme_color_override("font_color", CombatUI.COLOR_VOWEL)
	if bool(_q.get("tile_audio", true)):
		var sounds: Array = _q.get("sounds", [])
		var snd := String(sounds[i]) if i < sounds.size() else ""
		if String(_q.get("mode", "")) == "morpheme_smith" or snd.length() > 4:
			_play_refs([{"k": g}])
		else:
			_play_refs([{"u": [snd, g]}])
	_message.text = "Yes - %s" % g
	if _placed.size() >= _q["tiles"].size():
		_resolve_hit()


# ---------------------------------------------------------------- phoneme

func _load_phoneme() -> void:
	_rebuild_slots(_q["sounds"].size())
	for item in _q.get("items", []):
		var btn := CombatUI.grapheme_button(String(item["sound"]), Vector2(84, 64))
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_phoneme.bind(item, btn))
		_tile_pool.add_child(btn)
		_tile_buttons.append(btn)
	_tile_pool.show()
	_back.show()


func _on_phoneme(item: Dictionary, btn: Button) -> void:
	if not _ready_for_input():
		return
	for i in _picked.size():
		if _picked[i]["node"] == btn:
			_undo_picks_to(i)
			return
	var sounds: Array = _q["sounds"]
	if _picked.size() >= sounds.size():
		return
	_play_refs([{"u": [String(item["sound"]), String(item["grapheme"])]}])
	var expected := String(sounds[_picked.size()])
	if String(item["sound"]) != expected:
		_slip(String(item["sound"]), expected, btn)
		return
	_step_errors = 0
	_picked.append({"node": btn})
	btn.modulate = COLOR_GOOD
	var slot: Button = _slot_buttons[_picked.size() - 1]
	slot.text = String(item["sound"])
	slot.add_theme_font_size_override("font_size", 20)
	_message.text = "Yes - %s" % String(item["sound"])
	if _picked.size() >= sounds.size():
		_resolve_hit()


func _undo_picks_to(index: int) -> void:
	for i in range(_picked.size() - 1, index - 1, -1):
		var node = _picked[i]["node"]
		if node != null and is_instance_valid(node):
			node.modulate = Color.WHITE
		if i < _slot_buttons.size():
			_slot_buttons[i].text = ""
		_picked.remove_at(i)
	_message.text = "Take another sound."


# ----------------------------------------------------------------- choice

func _load_choice() -> void:
	var inline := bool(_q.get("inline", false))
	var opts: Array = _q.get("options", [])
	for i in opts.size():
		var o: Dictionary = opts[i]
		var btn := Button.new()
		btn.text = String(o["text"])
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 26 if inline or String(o["text"]).length() <= 6 else 19)
		btn.custom_minimum_size = Vector2(84, 72) if inline else Vector2(200, 64)
		if CombatUI.is_vowel(String(o["text"])):
			btn.add_theme_color_override("font_color", CombatUI.COLOR_VOWEL)
		btn.pressed.connect(_on_option.bind(i, btn))
		_tile_pool.add_child(btn)
		_option_buttons.append(btn)
	_tile_pool.show()
	if bool(_q.get("confirm", false)):
		_check.text = "That one ✓"
		_check.show()
		_check.disabled = true


func _on_option(index: int, btn: Button) -> void:
	if not _ready_for_input():
		return
	var o: Dictionary = _q["options"][index]
	var audio: Array = o.get("audio", [])
	if bool(_q.get("confirm", false)):
		_selected = index
		for b in _option_buttons:
			if is_instance_valid(b) and not b.disabled:
				b.modulate = Color.WHITE
		btn.modulate = COLOR_HINT
		_check.disabled = false
		_play_refs(audio)
		return
	_judge_option(index, btn)


func _judge_option(index: int, btn: Button) -> void:
	var o: Dictionary = _q["options"][index]
	if bool(o["correct"]):
		btn.modulate = COLOR_GOOD
		var audio: Array = o.get("audio", [])
		if not audio.is_empty() and not bool(_q.get("confirm", false)):
			_play_refs(audio)
		var after := String(_q.get("after", ""))
		_message.text = "Yes!" + ("  " + after if after != "" else "")
		_resolve_hit()
		return
	btn.disabled = true
	btn.modulate = COLOR_BAD
	_selected = -1
	if bool(_q.get("confirm", false)):
		_check.disabled = true
	_slip(String(o["text"]), String(_q.get("answer_text", "")), null)


# ------------------------------------------------------------------ count

func _load_count() -> void:
	_count = 0
	if bool(_q.get("show_count", false)):
		_rebuild_slots(int(_q["target"]))
	_slot_row.show()
	var token := Button.new()
	token.text = String(_q.get("token", "● Token"))
	token.custom_minimum_size = Vector2(220, 96)
	token.add_theme_font_size_override("font_size", 28)
	token.focus_mode = Control.FOCUS_NONE
	token.pressed.connect(_on_count_tap)
	_tile_pool.add_child(token)
	_tile_pool.show()
	_back.show()
	_check.text = "Done ✓"
	_check.show()


func _on_count_tap() -> void:
	if not _ready_for_input():
		return
	if _count >= int(_q["target"]) + 3:
		return
	_count += 1
	if not bool(_q.get("show_count", false)):
		_add_slot()
	var slot: Button = _slot_buttons[mini(_count, _slot_buttons.size()) - 1]
	slot.text = "●"
	if bool(_q.get("guide", false)):
		var units: Array = _q.get("unit_audio", [])
		if _count <= units.size():
			_play_refs(units[_count - 1])
	if bool(_q.get("show_count", false)) and _count > _slot_buttons.size():
		_message.text = "That's more tokens than boxes - press Take back."


func _check_count() -> void:
	if _count == int(_q["target"]):
		_message.text = "Yes - %d %ss!" % [_count, String(_q.get("unit", "sound"))]
		_resolve_hit()
		return
	var target := int(_q["target"])
	_errors += 1
	_step_errors += 1
	var tier := int(_q.get("tier", 1))
	if tier == 0:
		_message.text = "You pushed %d. Listen to each %s and try again." % [_count, String(_q.get("unit", "sound"))]
		_play_units()
	elif tier == 1:
		_message.text = "Not quite - listen again."
		_play_question_audio()
	else:
		_message.text = "Try again."
	# Clear the boxes so the next try starts fresh.
	_count = 0
	if bool(_q.get("show_count", false)):
		for b in _slot_buttons:
			b.text = ""
	else:
		for b in _slot_buttons:
			b.queue_free()
		_slot_buttons.clear()
	_after_slip(str(target))


func _play_units() -> void:
	var refs: Array = []
	for u in _q.get("unit_audio", []):
		refs.append_array(u)
		refs.append({"pause": 0.35})
	_play_refs(refs)


# ------------------------------------------------------------------ split

func _load_split() -> void:
	_cuts.clear()
	_cut_buttons.clear()
	for child in _slot_row.get_children():
		child.queue_free()
	var word := String(_q["letters"])
	for i in word.length():
		var ch := word.substr(i, 1)
		var lab := Label.new()
		lab.text = ch
		lab.add_theme_font_size_override("font_size", 40)
		var vowel := ch.to_lower() in ["a", "e", "i", "o", "u"]
		lab.add_theme_color_override("font_color", CombatUI.COLOR_VOWEL if vowel and bool(_q.get("mark_vowels", false)) else Color(0.96, 0.98, 1, 1))
		_slot_row.add_child(lab)
		if i < word.length() - 1:
			var cut := Button.new()
			cut.text = "·"
			cut.custom_minimum_size = Vector2(26, 56)
			cut.focus_mode = Control.FOCUS_NONE
			cut.add_theme_font_size_override("font_size", 26)
			cut.pressed.connect(_on_cut.bind(i + 1, cut))
			_slot_row.add_child(cut)
			_cut_buttons.append(cut)
	_slot_row.show()
	_check.text = "Done ✓"
	_check.show()


func _on_cut(at: int, btn: Button) -> void:
	if not _ready_for_input():
		return
	if _cuts.has(at):
		_cuts.erase(at)
		btn.text = "·"
		btn.modulate = Color.WHITE
	else:
		_cuts.append(at)
		btn.text = "|"
		btn.modulate = COLOR_HINT


func _check_split() -> void:
	var mine := _cuts.duplicate()
	mine.sort()
	var want: Array = _q["cuts"].duplicate()
	want.sort()
	if mine == want:
		var parts: Array = []
		var word := String(_q["letters"])
		var last := 0
		for c in want:
			parts.append(word.substr(last, int(c) - last))
			last = int(c)
		parts.append(word.substr(last))
		_message.text = "Yes - %s" % " | ".join(parts)
		_resolve_hit()
		return
	_errors += 1
	_step_errors += 1
	var tier := int(_q.get("tier", 1))
	_message.text = "Not quite. Look for the vowels - each syllable has one vowel sound." if tier == 0 else "Not quite - try again."
	_after_slip("|")


# ------------------------------------------------------------------- type

func _load_type() -> void:
	_type_edit.text = ""
	_type_edit.show()
	_type_edit.editable = true
	_type_edit.grab_focus.call_deferred()
	_check.text = "Done ✓"
	_check.show()


func _check_type() -> void:
	var said := _type_edit.text.strip_edges().to_lower()
	if said == "":
		return
	if said == String(_q["answer"]):
		_message.text = "Yes - %s" % said
		_type_edit.editable = false
		_resolve_hit()
		return
	_errors += 1
	_step_errors += 1
	var answer := String(_q["answer"])
	var first_wrong := 0
	while first_wrong < mini(said.length(), answer.length()) and said[first_wrong] == answer[first_wrong]:
		first_wrong += 1
	_message.text = "Close! The first %d letters are right. Listen again." % first_wrong if first_wrong > 0 else "Not quite. Listen again."
	_play_question_audio()
	_after_slip(answer)


# ------------------------------------------------------ slips, hints, done

func _ready_for_input() -> bool:
	return _active and not _locked and not _q.is_empty()


## A wrong answer. Feedback depends on the tier; Easy models the answer after
## two slips and never misses, Normal / Hard miss after `tries` slips.
func _slip(attempt: String, expected: String, btn: Button) -> void:
	_errors += 1
	_step_errors += 1
	var tier := int(_q.get("tier", 1))
	if btn != null and is_instance_valid(btn):
		var flash := create_tween()
		flash.tween_property(btn, "modulate", COLOR_BAD, 0.06)
		flash.tween_property(btn, "modulate", Color.WHITE, 0.25)
	match tier:
		0:
			_message.text = "Not %s. Listen: it's %s." % [attempt, expected] if expected != "" else "Not that one - listen again."
			_highlight_expected()
		1:
			_message.text = "Not %s - listen again." % attempt
		_:
			_message.text = "Try again."
	_after_slip(expected)


func _after_slip(_expected: String) -> void:
	var tries := int(_q.get("tries", 3))
	if tries > 0 and String(_q.get("kind", "")) == "choice":
		# Never let a child win by elimination: you may slip at most once per
		# wrong option, minus one (a 2-option item misses on the first slip).
		var wrong := 0
		for o in _q.get("options", []):
			if not bool(o["correct"]):
				wrong += 1
		tries = clampi(mini(tries, wrong), 1, tries)
		_q["tries"] = tries
	if tries < 0:
		if _step_errors >= 2 and not _modelled:
			_modelled = true
			_highlight_expected()
			_message.text += "  I'll show you - now you do it."
		return
	if _errors >= tries:
		_resolve_miss()


func _on_hint() -> void:
	if not _ready_for_input():
		return
	_hinted = true
	_highlight_expected()
	_play_question_audio()
	_message.text = "Here's a clue. (Hints don't count toward mastery.)"


## Glow on the next correct tile / option so the child can finish the item.
func _highlight_expected() -> void:
	match String(_q.get("kind", "")):
		"build":
			var tiles: Array = _q["tiles"]
			if _placed.size() < tiles.size():
				var b := _find_tile_button(String(tiles[_placed.size()]))
				if b != null:
					b.modulate = COLOR_HINT
		"phoneme":
			var sounds: Array = _q["sounds"]
			if _picked.size() < sounds.size():
				var want := String(sounds[_picked.size()])
				for b in _tile_buttons:
					if is_instance_valid(b) and String(b.text) == want and b.modulate != COLOR_GOOD:
						b.modulate = COLOR_HINT
						break
		"choice":
			var opts: Array = _q["options"]
			for i in opts.size():
				if bool(opts[i]["correct"]) and i < _option_buttons.size():
					_option_buttons[i].modulate = COLOR_HINT
					break
		"type":
			var answer := String(_q["answer"])
			_message.text = "It starts with: %s" % answer.substr(0, maxi(1, answer.length() / 2))
		"count":
			_play_units()
		"split":
			var want: Array = _q["cuts"]
			if not want.is_empty():
				var idx := int(want[0]) - 1
				if idx >= 0 and idx < _cut_buttons.size():
					_cut_buttons[idx].modulate = COLOR_HINT


func _on_check() -> void:
	if not _ready_for_input():
		return
	match String(_q.get("kind", "")):
		"choice":
			if _selected >= 0 and _selected < _option_buttons.size():
				_judge_option(_selected, _option_buttons[_selected])
		"count":
			_check_count()
		"split":
			_check_split()
		"type":
			_check_type()


func _take_back() -> void:
	if _locked:
		return
	match String(_q.get("kind", "")):
		"phoneme":
			if not _picked.is_empty():
				_undo_picks_to(_picked.size() - 1)
		"build":
			if _placed.is_empty():
				return
			_placed.pop_back()
			var slot: Button = _slot_buttons[_placed.size()]
			var g := String(slot.text)
			slot.text = ""
			slot.remove_theme_color_override("font_color")
			for b in _tile_buttons:
				if is_instance_valid(b) and b.disabled and String(b.text).to_lower() == g.to_lower():
					b.disabled = false
					break
			_message.text = "Take another sound."
		"count":
			if _count <= 0:
				return
			_count -= 1
			if bool(_q.get("show_count", false)):
				_slot_buttons[_count].text = ""
			else:
				var s: Button = _slot_buttons.pop_back()
				s.queue_free()


func _resolve_hit() -> void:
	_locked = true
	var correct := _errors == 0 and not _hinted
	_record(correct)
	var word := String(_q.get("word", ""))
	_play_hit_anim()
	if not _q.get("entry", {}).is_empty() and String(_q.get("kind", "")) != "count":
		_play_refs([{"pause": 0.35}, {"w": String(_q["entry"]["word"])}])
	word_solved.emit(word if word != "" else "word", int(_q.get("damage", 1)))


func _resolve_miss() -> void:
	_locked = true
	_record(false)
	_message.text = "Miss! The attack did not land."
	_highlight_expected()
	_play_miss_anim()
	attack_missed.emit()


func _record(correct: bool) -> void:
	var sid := String(_q.get("stage", ""))
	if sid == "":
		return
	var result: Dictionary = Learner.record(sid, correct, {
		"mode": String(_q.get("mode", "")),
		"word": String(_q.get("word", "")),
		"tier": int(_q.get("tier", 1)),
		"attack": _method,
		"errors": _errors,
		"hint": _hinted,
	})
	if bool(result.get("mastered_now", false)):
		var nxt := OGCurriculum.next_stage(sid)
		progress_event.emit("★ %s mastered!%s" % [OGCurriculum.label(sid), ("  Next: " + OGCurriculum.label(nxt)) if nxt != "" else ""])
	if String(result.get("tier_to", "")) != String(result.get("tier_from", "")):
		var up := QuestionFactory.TIER.map(func(t): return String(t["name"]).to_lower()).find(String(result["tier_to"])) > QuestionFactory.TIER.map(func(t): return String(t["name"]).to_lower()).find(String(result["tier_from"]))
		progress_event.emit(("Getting stronger! %s is now %s." if up else "Let's add some support: %s is now %s.") % [sid, String(result["tier_to"]).capitalize()])
	if bool(result.get("level_up", false)):
		progress_event.emit("Level up! You are now level %d." % Learner.level)


# ------------------------------------------------------------- UI helpers

func _rebuild_slots(n: int) -> void:
	for child in _slot_row.get_children():
		child.queue_free()
	_slot_buttons.clear()
	for i in n:
		_add_slot()
	_slot_row.show()


func _add_slot() -> void:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.focus_mode = Control.FOCUS_NONE
	slot.disabled = true
	_slot_row.add_child(slot)
	_slot_buttons.append(slot)


func _clear_question() -> void:
	for row in [_sound_row, _slot_row, _tile_pool]:
		for child in row.get_children():
			child.queue_free()
	_slot_buttons.clear()
	_tile_buttons.clear()
	_option_buttons.clear()
	_cut_buttons.clear()
	_cuts.clear()
	_placed.clear()
	_picked.clear()
	_selected = -1
	_count = 0
	_sound_row.hide()
	_slot_row.hide()
	_tile_pool.hide()
	_hear.hide()
	_back.hide()
	if _check != null:
		_check.hide()
		_check.disabled = false
		_check.text = "Done ✓"
		_hint.hide()
		_type_edit.hide()
		_type_edit.release_focus()


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

func _play_question_audio() -> void:
	var refs: Array = _q.get("audio", [])
	if refs.is_empty():
		return
	_play_refs(refs)
	if bool(_q.get("repeat", false)):
		var gen := _play_gen
		get_tree().create_timer(_refs_duration(refs) + REPEAT_DELAY_SECONDS).timeout.connect(func():
			if _active and gen == _play_gen:
				_play_refs(refs))


func _play_refs(refs: Array) -> void:
	_play_gen += 1
	_play_step(refs, 0, _play_gen)


func _play_step(refs: Array, i: int, gen: int) -> void:
	if not _active or gen != _play_gen or i >= refs.size():
		return
	var ref: Dictionary = refs[i]
	var wait := 0.0
	if ref.has("pause"):
		wait = float(ref["pause"])
	else:
		var stream := _stream_for(ref)
		if stream != null:
			_audio.stream = stream
			_audio.play()
			wait = maxf(0.2, stream.get_length() + 0.08)
		else:
			wait = 0.05
	if i + 1 >= refs.size():
		return
	get_tree().create_timer(wait).timeout.connect(func(): _play_step(refs, i + 1, gen))


func _refs_duration(refs: Array) -> float:
	var total := 0.0
	for ref in refs:
		if ref.has("pause"):
			total += float(ref["pause"])
		else:
			var s := _stream_for(ref)
			total += maxf(0.2, s.get_length() + 0.08) if s != null else 0.05
	return total


func _stream_for(ref: Dictionary) -> AudioStream:
	if ref.has("w"):
		return CCAssetFetcher.word_stream(String(ref["w"]))
	if ref.has("s"):
		return CCAssetFetcher.sound_stream(String(ref["s"]))
	if ref.has("u"):
		var pair: Array = ref["u"]
		return CCAssetFetcher.unit_stream(String(pair[0]), String(pair[1]))
	if ref.has("k"):
		return CCAssetFetcher.chunk_stream(String(ref["k"]))
	return null


# -------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		flee_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _locked or _q.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE:
			_take_back()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_check()
			get_viewport().set_input_as_handled()
			return
		if String(_q.get("kind", "")) != "build":
			return
		var letter := String.chr(event.unicode).to_lower()
		if letter.length() == 1 and letter >= "a" and letter <= "z":
			_on_typed_letter(letter)
			get_viewport().set_input_as_handled()


func _refresh_hp() -> void:
	_hp_bar.max_value = _hits_total
	_hp_bar.value = _hits_left
	_hp_label.text = "HP  %d / %d" % [_hits_left, _hits_total]


# ----------------------------------------------------------- test helpers

## Answer the current question correctly (automated tests only).
func debug_answer_correctly() -> void:
	match String(_q.get("kind", "")):
		"build":
			for t in _q["tiles"].duplicate():
				if _locked:
					break
				_on_build_tile(String(t), _find_tile_button(String(t)))
		"phoneme":
			for s in _q["sounds"].duplicate():
				for b in _tile_buttons:
					if is_instance_valid(b) and String(b.text) == String(s) and b.modulate != COLOR_GOOD:
						var item := {"sound": String(s), "grapheme": ""}
						for it in _q["items"]:
							if String(it["sound"]) == String(s):
								item = it
						_on_phoneme(item, b)
						break
		"choice":
			var opts: Array = _q["options"]
			for i in opts.size():
				if bool(opts[i]["correct"]):
					_on_option(i, _option_buttons[i])
					if bool(_q.get("confirm", false)):
						_on_check()
					break
		"count":
			for i in int(_q["target"]):
				_on_count_tap()
			_on_check()
		"split":
			for c in _q["cuts"]:
				var idx := int(c) - 1
				_on_cut(int(c), _cut_buttons[idx])
			_on_check()
		"type":
			_type_edit.text = String(_q["answer"])
			_on_check()


## Answer wrongly once (automated tests only).
func debug_answer_wrong() -> void:
	match String(_q.get("kind", "")):
		"build":
			for b in _tile_buttons:
				var expected := String(_q["tiles"][_placed.size()]).to_lower()
				if is_instance_valid(b) and String(b.text).to_lower() != expected:
					_on_build_tile(String(b.text), b)
					return
			_slip("?", "", null)
		"choice":
			var opts: Array = _q["options"]
			for i in opts.size():
				if not bool(opts[i]["correct"]) and not _option_buttons[i].disabled:
					_on_option(i, _option_buttons[i])
					if bool(_q.get("confirm", false)):
						_on_check()
					return
		"count":
			for i in int(_q["target"]) + 1:
				_on_count_tap()
			_on_check()
		"type":
			_type_edit.text = "zzz"
			_on_check()
		_:
			_slip("?", "", null)
