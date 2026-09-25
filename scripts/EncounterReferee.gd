extends Node

@onready var word_build_overlay: Control = $"../PuzzleLayer/WordBuild"

func _ready() -> void:
	print("[SYSTEM] Encounter Referee initialized. Listening for monster contacts...")
	
	# Automatically find and connect to every wandering monster on the map
	for monster in get_tree().get_nodes_in_group("monster"):
		if monster.has_signal("player_contacted"):
			monster.player_contacted.connect(_on_monster_contacted)
			print("  Connected referee link to: ", monster.display_name)
			
	# Connect the mini-game buttons back to the referee rules
	if word_build_overlay:
		if not word_build_overlay.word_solved.is_connected(_on_word_solved):
			word_build_overlay.word_solved.connect(_on_word_solved)
		if not word_build_overlay.flee_requested.is_connected(_on_flee_requested):
			word_build_overlay.flee_requested.connect(_on_flee_requested)

func _on_monster_contacted(monster: Node) -> void:
	print("[REF] Player touched monster: ", monster.display_name)
	
	# Freeze the monster so it doesn't move or damage the player during the puzzle
	if monster.has_method("set_encounter_paused"):
		monster.set_encounter_paused(true)
		
	# Extract stats from the monster scene file properties
	var lvl = monster.word_level if "word_level" in monster else 1
	var hp = monster._hits_left if "_hits_left" in monster else 1
	
	# Launch the spelling minigame overlay panel!
	if word_build_overlay:
		word_build_overlay.start_encounter(monster.display_name, lvl, hp)

func _on_word_solved(word: String) -> void:
	print("[REF] Puzzle solved! Word was: ", word)
	# Find which monster we are fighting and mark it defeated
	var monsters = get_tree().get_nodes_in_group("monster")
	for m in monsters:
		if m.has_method("set_encounter_paused") and not m.is_disabled():
			# Inflict 1 hit of spelling damage
			var new_hp = m._hits_left - 1
			m.set_hits_left(new_hp)
			
			if new_hp <= 0:
				m.mark_defeated()
				if word_build_overlay:
					word_build_overlay.close_overlay()
			else:
				# Drop a brand new word tier block card for the next round
				if word_build_overlay:
					word_build_overlay.set_hits_left(new_hp)
					word_build_overlay.next_round()
			break

func _on_flee_requested() -> void:
	print("[REF] Player ran away!")
	var monsters = get_tree().get_nodes_in_group("monster")
	for m in monsters:
		if m.has_method("flee_from_player"):
			m.flee_from_player()
			m.set_encounter_paused(false)
	if word_build_overlay:
		word_build_overlay.close_overlay()
