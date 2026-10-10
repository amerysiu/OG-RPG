# ==============================================================================
#           SUMMER ENGINE / GODOT 4 ORTON-GILLINGHAM GAME SYSTEM CORE
# ==============================================================================
# Unified script containing global state progression, structural linguistic rules, 
# and multi-sensory action button events optimized for web, desktop, and touch inputs.
# ==============================================================================

extends Node

# --- LINGUISTIC DICTIONARY DEFINITIONS ---
const VOWELS = ["a", "e", "i", "o", "u"]
const CONSONANTS = [
	"b", "c", "d", "f", "g", "h", "j", "k", "l", "m", 
	"n", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z"
]

# --- JOB CLASS PROGRESSION TRACKING ---
enum JobClass { NOVICE, SWORDSMAN, MAGE, KNIGHT }
var current_job: JobClass = JobClass.NOVICE
var player_level: int = 1
var player_xp: int = 0

# --- OG WORD ACCESS ---
const OGWords := preload("res://scripts/og_words.gd")

# --- ACTIVE COMBAT DATA ---
var current_target_word: String = ""
var expected_sequence: Array = []
var player_input_sequence: Array = []
var current_zone: int = 1
var current_monster_level: int = 1

# --- MULTI-SENSORY UI NODE REFERENCES ---
var action_bar_container: HBoxContainer
var cast_progress_bar: TextureProgressBar
var prompt_audio_player: AudioStreamPlayer2D
var feedback_audio_player: AudioStreamPlayer2D
var monster_anim_sprite: AnimatedSprite2D

# ==============================================================================
# ENGINE INITIALIZATION & CONFIGURATION
# ==============================================================================
func _ready() -> void:
	print("[SYSTEM] Initializing Orton-Gillingham Game Core on Summer Engine...")
	current_zone = 1
	current_monster_level = 1
	# Autoload only tracks progression state. UI and fights live in iso_world /
	# battle_screen; call start_new_battle_encounter() from a scene that wants
	# the legacy action-bar loop.

func setup_node_hierarchy() -> void:
	# Ensure the required audio hierarchy exists
	var audio_root = get_node_or_null("AudioPlayers")
	if not audio_root:
		audio_root = Node.new()
		audio_root.name = "AudioPlayers"
		add_child(audio_root)
		
	prompt_audio_player = AudioStreamPlayer2D.new()
	prompt_audio_player.name = "PromptPlayer"
	audio_root.add_child(prompt_audio_player)
	
	feedback_audio_player = AudioStreamPlayer2D.new()
	feedback_audio_player.name = "FeedbackPlayer"
	audio_root.add_child(feedback_audio_player)

	# Build out standard base UI scaffolding dynamically if missing in viewport
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		add_child(canvas)
		
	action_bar_container = HBoxContainer.new()
	action_bar_container.name = "ActionBar"
	action_bar_container.set_anchors_and_offsets_preset(12)
	canvas.add_child(action_bar_container)

	cast_progress_bar = TextureProgressBar.new()
	cast_progress_bar.name = "CastBar"
	canvas.add_child(cast_progress_bar)

# ==============================================================================
# LINGUISTIC PARSING ENGINE (CVC / CLUSTER ANALYSIS)
# ==============================================================================
func is_valid_cvc(word: String) -> bool:
	word = word.strip_edges().to_lower()
	if word.length() != 3: return false
	return (word[0] in CONSONANTS) and (word[1] in VOWELS) and (word[2] in CONSONANTS)

func split_word_into_graphemes(word: String) -> Array:
	word = word.strip_edges().to_lower()
	var graphemes = []
	
	if is_valid_cvc(word):
		for char in word:
			graphemes.append(char)
		return graphemes
		
	for i in range(word.length()):
		graphemes.append(word[i])
	return graphemes

# ==============================================================================
# MULTI-SENSORY SYSTEM CORE & GAMEPLAY LOOPS
# ==============================================================================
func start_new_battle_encounter() -> void:
	if action_bar_container == null:
		setup_node_hierarchy()
	player_input_sequence.clear()
	if cast_progress_bar: cast_progress_bar.value = 0
	
	# Select word using OG scope & sequence, based on zone and monster level
	var picked = OGWords.pick_word_for_zone(current_zone, current_monster_level)
	current_target_word = String(picked.get("word", "cat"))
	
	# Determine the phonics pattern name for display
	var pattern_name = OGWords.level_focus(1)  # default
	match current_zone:
		1:
			pattern_name = OGWords.level_focus(1)
		2:
			pattern_name = OGWords.level_focus(2)
		3:
			pattern_name = OGWords.level_focus(3)
		else:
			pattern_name = "review words"
	
	# Split word into graphemes for expected sequence
	expected_sequence = split_word_into_graphemes(current_target_word)
	
	# Play the phoneme sound for the target word
	play_phoneme_sound(current_target_word)
	
	# Generate grapheme interface cards
	generate_grapheme_interface_cards(pattern_name)

func generate_grapheme_interface_cards(pattern_name: String = "CVC words") -> void:
	if not action_bar_container: return
	for child in action_bar_container.get_children():
		child.queue_free()
		
	var available_choices: Array = []
	
	# Build choice pool from the expected sequence graphemes
	for g in expected_sequence:
		if not g in available_choices: available_choices.append(g)
		
	# Add distractor graphemes from the same level's pool
	var entry = OGWords.words_for_level(expected_sequence.size())
	if not entry.is_empty():
		var tile_pool = OGWords.tile_pool(entry[0], 3)
		for tile in tile_pool:
			if not tile in available_choices and not tile in expected_sequence:
				available_choices.append(tile)
	
	# Fill up to 4 choices total
	while available_choices.size() < 4:
		var random_letter = CONSONANTS[randi() % CONSONANTS.size()]
		if not random_letter in available_choices:
			available_choices.append(random_letter)
			
	available_choices.shuffle()
	
	for grapheme in available_choices:
		var btn = Button.new()
		btn.text = grapheme
		btn.custom_minimum_size = Vector2(80, 80)
		
		if grapheme in VOWELS:
			btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Pink/Red Vowels
		else:
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0)) # White Consonants
			
		btn.pressed.connect(self._on_grapheme_card_selected.bind(grapheme, btn))
		action_bar_container.add_child(btn)

# ==============================================================================
# AUDITORY REINFORCEMENT CONTROLLER
# ==============================================================================
func play_phoneme_sound(sound_name: String) -> void:
	# Use the consistent phoneme system from cc_asset_fetcher
	var key := sound_name.to_lower().strip_edges()
	var stream := CCAssetFetcher.phoneme_stream(key)
	if stream != null:
		prompt_audio_player.stream = stream
		prompt_audio_player.play()
	else:
		# Fallback: try direct file path
		var path = "res://audio/phonemes/" + key + ".wav"
		if ResourceLoader.exists(path):
			var sound_clip = load(path)
			prompt_audio_player.stream = sound_clip
			prompt_audio_player.play()

func play_feedback_sound(is_correct: bool) -> void:
	var path = "res://audio/effects/" + ("hit.wav" if is_correct else "clink.wav")
	if ResourceLoader.exists(path):
		feedback_audio_player.stream = load(path)
		feedback_audio_player.play()

# ==============================================================================
# EVALUATION LOGIC (NON-PUNITIVE INTERACTION)
# ==============================================================================
func _on_grapheme_card_selected(grapheme_value: String, button_node: Button) -> void:
	play_phoneme_sound(grapheme_value)
	var next_expected_index = player_input_sequence.size()
	
	if grapheme_value == expected_sequence[next_expected_index]:
		player_input_sequence.append(grapheme_value)
		play_feedback_sound(true)
		button_node.disabled = true
		
		if cast_progress_bar:
			cast_progress_bar.value = (float(player_input_sequence.size()) / expected_sequence.size()) * 100
			
		if player_input_sequence.size() == expected_sequence.size():
			execute_successful_word_strike()
	else:
		play_feedback_sound(false)
		shake_interface_node(button_node)

func execute_successful_word_strike() -> void:
	if monster_anim_sprite:
		monster_anim_sprite.play("hurt")
		
	player_xp += 25
	
	# Advance zone/monster level based on word difficulty
	current_monster_level = current_zone * 2 + randi() % 3
	
	var new_level = OGWords.pick_word_for_zone(current_zone, player_level)
	current_target_word = String(new_level.get("word", "cat"))
	
	expected_sequence = split_word_into_graphemes(current_target_word)
	play_phoneme_sound(current_target_word)
	generate_grapheme_interface_cards(OGWords.level_focus(expected_sequence.size()))
	
	if player_xp >= 100:
		award_level_up()
		
	get_tree().create_timer(1.2).timeout.connect(self.start_new_battle_encounter)

func award_xp_for_word() -> void:
	player_xp += 10
	print("[SYSTEM] Word solved! +10 XP. Total: " + str(player_xp))

func award_level_up() -> void:
	player_level += 1
	player_xp = 0
	
	# Advance zone every few levels, increase monster difficulty
	if player_level % 5 == 0:
		current_zone += 1
		if current_zone > 3:
			current_zone = 3
	
	# Update monster level based on zone
	current_monster_level = current_zone * 2 + randi() % 3
	
	if player_level == 5 and current_job == JobClass.NOVICE:
		current_job = JobClass.SWORDSMAN

# ==============================================================================
# UI ANIMATION EFFECTS (TACTILE FEEL)
# ==============================================================================
func shake_interface_node(node: Control) -> void:
	var original_pos = node.position
	var tween = create_tween()
	tween.tween_property(node, "position", original_pos + Vector2(-8, 0), 0.05)
	tween.tween_property(node, "position", original_pos + Vector2(8, 0), 0.05)
	tween.tween_property(node, "position", original_pos, 0.05)
