# ==============================================================================
#           SUMMER ENGINE / GODOT 4 ORTON-GILLINGHAM GAME SYSTEM CORE
# ==============================================================================
# Unified script containing global state progression, structural linguistic rules, 
# and multi-sensory action button events optimized for web, desktop, and touch inputs.
# ==============================================================================

extends Node2D

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

# --- WORD PROGRESSION TIERS (OG SCOPE & SEQUENCE) ---
var cvc_words = ["cat", "hop", "bin", "mat", "sun", "pig", "fed", "cup", "map", "net"]
var ccvc_words = ["stop", "frog", "flag", "plum", "spot", "drop", "skid", "clip", "plan"]
var cvcc_words = ["fast", "tent", "hand", "lamp", "desk", "milk", "rust", "belt", "fond"]

# --- ACTIVE COMBAT DATA ---
var current_target_word: String = ""
var expected_sequence: Array = []
var player_input_sequence: Array = []

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
	setup_node_hierarchy()
	start_new_battle_encounter()

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
	action_bar_container = HBoxContainer.new()
	action_bar_container.name = "ActionBar"
	action_bar_container.set_anchors_and_offsets_preset(12)
	canvas.add_child(action_bar_container)

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
	player_input_sequence.clear()
	if cast_progress_bar: cast_progress_bar.value = 0
	
	match current_job:
		JobClass.NOVICE:
			current_target_word = cvc_words[randi() % cvc_words.size()]
		JobClass.SWORDSMAN:
			var combined_pool = ccvc_words + cvcc_words
			current_target_word = combined_pool[randi() % combined_pool.size()]
			
	expected_sequence = split_word_into_graphemes(current_target_word)
	play_phoneme_sound(current_target_word)
	generate_grapheme_interface_cards()

func generate_grapheme_interface_cards() -> void:
	if not action_bar_container: return
	for child in action_bar_container.get_children():
		child.queue_free()
		
	var available_choices = []
	for g in expected_sequence:
		if not g in available_choices: available_choices.append(g)
		
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
	var path = "res://audio/phonemes/" + sound_name.to_lower() + ".wav"
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
	if player_xp >= 100:
		award_level_up()
		
	get_tree().create_timer(1.2).timeout.connect(self.start_new_battle_encounter)

func award_level_up() -> void:
	player_level += 1
	player_xp = 0
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
