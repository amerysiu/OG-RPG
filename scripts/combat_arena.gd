extends Node2D

const OGWords := preload("res://scripts/og_words.gd")

const COLOR_VOWEL := Color(1.0, 0.4, 0.4, 1)      # Pink/Red layout tracking
const COLOR_CONSONANT := Color(1.0, 1.0, 1.0, 1)  # White layout tracking

@onready var action_bar: HBoxContainer = %ActionBar
@onready var cue_label: Label = $Battlefield/Cue
@onready var phoneme_player: AudioStreamPlayer2D = $PhonemePlayer
@onready var sfx_player: AudioStreamPlayer2D = $SfxPlayer
@onready var glyph_bubble: Label = $Battlefield/MonsterNode/EmoteMarker/Glyph

var current_target_word: String = ""
var expected_sequence: Array = []
var current_input_index: int = 0
var current_level: int = 1

func _ready() -> void:
	initialize_new_round(current_level)

func initialize_new_round(level: int) -> void:
	current_input_index = 0
	current_level = level
	
	# Fetch random word from database registry map
	var word_entry = OGWords.pick_word(current_level)
	current_target_word = String(word_entry["word"])
	expected_sequence = word_entry.get("tiles", [])
	
	if cue_label:
		cue_label.text = "Can you spell: " + current_target_word.to_upper() + "?"
	if glyph_bubble:
		glyph_bubble.text = "!"
		
	# Play full synthesis prompt sequence
	play_word_phoneme_sequence()
	generate_dynamic_grapheme_cards(word_entry)

func play_word_phoneme_sequence() -> void:
	# Orton-Gillingham Multi-Sensory Rule: Pronounce individual sounds step-by-step
	for tile in expected_sequence:
		play_audio_resource("res://audio/phonemes/" + String(tile) + ".wav")
		await get_tree().create_timer(0.6).timeout

func generate_dynamic_grapheme_cards(entry: Dictionary) -> void:
	if not action_bar: return
	for child in action_bar.get_children():
		child.queue_free()
		
	var randomized_tiles = OGWords.tile_pool(entry)
	
	for grapheme in randomized_tiles:
		var btn = Button.new()
		btn.text = String(grapheme)
		btn.custom_minimum_size = Vector2(100, 100)
		btn.focus_mode = Control.FOCUS_NONE
		
		# Identify vowel groups to apply font accents
		if String(grapheme) in ["a", "e", "i", "o", "u"]:
			btn.add_theme_color_override("font_color", COLOR_VOWEL)
		else:
			btn.add_theme_color_override("font_color", COLOR_CONSONANT)
			
		btn.pressed.connect(self._on_card_pressed.bind(String(grapheme), btn))
		action_bar.add_child(btn)

func _on_card_pressed(grapheme_value: String, button_node: Button) -> void:
	# Kinesthetic Touch Trigger response
	play_audio_resource("res://audio/phonemes/" + grapheme_value + ".wav")
	
	if grapheme_value == expected_sequence[current_input_index]:
		current_input_index += 1
		button_node.disabled = true
		
		if current_input_index >= expected_sequence.size():
			execute_victory_feedback()
	else:
		play_sfx_resource("res://audio/effects/clink.wav")
		shake_card_node(button_node)

func execute_victory_feedback() -> void:
	play_sfx_resource("res://audio/effects/hit.wav")
	if glyph_bubble: glyph_bubble.text = "⭐"
	
	# Transition tracking levels milestone checks
	var next_lvl = current_level
	if current_level < 3 and randf() > 0.7:
		next_lvl += 1
		
	get_tree().create_timer(1.5).timeout.connect(func(): initialize_new_round(next_lvl))

func play_audio_resource(file_path: String) -> void:
	if ResourceLoader.exists(file_path) and phoneme_player:
		phoneme_player.stream = load(file_path)
		phoneme_player.play()

func play_sfx_resource(file_path: String) -> void:
	if ResourceLoader.exists(file_path) and sfx_player:
		sfx_player.stream = load(file_path)
		sfx_player.play()

func shake_card_node(node: Control) -> void:
	var orig_pos = node.position
	var tween = create_tween()
	tween.tween_property(node, "position", orig_pos + Vector2(-6, 0), 0.04)
	tween.tween_property(node, "position", orig_pos + Vector2(6, 0), 0.04)
	tween.tween_property(node, "position", orig_pos, 0.04)
