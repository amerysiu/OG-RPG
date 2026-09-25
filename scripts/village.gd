extends Node2D

## The village is the game world and the referee for village quests.
##
## It owns the HUD counters, connects each village friend's word quest, opens the
## shared quest puzzle overlay, freezes the world while that overlay is open, and
## credits the reward when the puzzle reports a solved word.
##
## Wild monster fights are NOT handled here: they are delegated to the encounter
## referee in res://scripts/encounter.gd, which freezes the world, runs the Word
## Build mini-game and reports back gold and resource rewards.

# Loaded by path so the game always finds its word list, even if the editor's
# global class cache has not picked the script up yet.
const WordSource := preload("res://scripts/word_bank.gd")
const EncounterSource := preload("res://scripts/encounter.gd")

## How quickly the camera catches up to the player each frame.
const CAMERA_FOLLOW_SPEED := 6.0

## The resource a defeated wild monster drops, shown on the HUD.
const RESOURCE_NAME := "Wood"

@onready var _player = $Player
@onready var _camera: Camera2D = $Camera2D
@onready var _puzzle = $PuzzleLayer/WordPuzzle
@onready var _word_build = $PuzzleLayer/WordBuild
@onready var _quests_label: Label = $HUD/HUDBox/QuestsLabel
@onready var _coins_label: Label = $HUD/HUDBox/CoinsLabel
@onready var _gold_label: Label = $HUD/HUDBox/GoldLabel
@onready var _resource_label: Label = $HUD/HUDBox/ResourceLabel
@onready var _status_label: Label = $HUD/HUDBox/StatusLabel

var _encounter = null
var _npcs: Array = []
var _active_npc = null
var _puzzle_open: bool = false
var _quests_done: int = 0
var _coins: int = 0
var _gold: int = 0
var _resource: int = 0
var _total_quests: int = 0


func _ready() -> void:
	randomize()
	_npcs = get_tree().get_nodes_in_group("npc")
	_total_quests = _npcs.size()
	for npc in _npcs:
		npc.quest_requested.connect(_on_quest_requested)

	# The village quest puzzle: unchanged, still wired to its own signals.
	_puzzle.connect("puzzle_solved", _on_puzzle_solved)
	_puzzle.connect("puzzle_closed", _on_puzzle_closed)
	_puzzle.hide()

	# The wild encounter referee: it owns monster fights for the whole world.
	_encounter = EncounterSource.new()
	_encounter.status_changed.connect(_on_status_changed)
	_encounter.monster_hit.connect(_on_monster_hit)
	_encounter.monster_defeated.connect(_on_monster_defeated)
	_encounter.setup(self, _player, _word_build, _npcs)

	_refresh_hud()
	_status_label.text = "Walk with W A S D or the arrow keys. The gate east of the village leads into the wild."


## The camera is a sibling of the player, so it eases toward it here. The
## Camera2D's own limits keep the view inside the world bounds.
func _process(delta: float) -> void:
	var weight := clampf(CAMERA_FOLLOW_SPEED * delta, 0.0, 1.0)
	_camera.global_position = _camera.global_position.lerp(_player.global_position, weight)


## Asked by the encounter referee before it starts a fight: only one overlay at
## a time, so a village quest outranks a wandering monster.
func is_world_busy() -> bool:
	return _puzzle_open or (_encounter != null and _encounter.is_busy())


# ------------------------------------------------------------------ quests

func _on_quest_requested(npc) -> void:
	if _puzzle_open or npc.quest_complete or is_world_busy():
		return

	var entry: Dictionary = _find_word(String(npc.quest_word))
	_active_npc = npc
	_puzzle_open = true

	# The puzzle types W A S D as letters, so the world stops listening.
	_player.set_input_enabled(false)
	_set_npcs_enabled(false)

	_puzzle.start_quest(entry, String(npc.display_name), String(npc.quest_hint))
	_puzzle.show()
	_status_label.text = "%s needs help with a word." % String(npc.display_name)


func _on_puzzle_solved(_word: String) -> void:
	if _active_npc == null or _active_npc.quest_complete:
		return
	var npc_name := String(_active_npc.display_name)
	_active_npc.mark_quest_complete()
	_quests_done += 1
	_coins += 1
	_refresh_hud()
	_status_label.text = "Great reading! %s gives you a coin." % npc_name


func _on_puzzle_closed() -> void:
	_puzzle_open = false
	_player.set_input_enabled(true)
	_set_npcs_enabled(true)

	if _active_npc != null and not _active_npc.quest_complete:
		_status_label.text = "%s is still waiting for that word." % String(_active_npc.display_name)
	_active_npc = null


func _find_word(word: String) -> Dictionary:
	var wanted := word.strip_edges().to_lower()
	for entry in WordSource.WORDS:
		if String(entry["w"]).to_lower() == wanted:
			return entry
	# Never leave a quest without a word to spell.
	return WordSource.practice_word()


func _set_npcs_enabled(value: bool) -> void:
	for npc in _npcs:
		npc.set_interaction_enabled(value)


# ------------------------------------------------------- wild monster fights

func _on_monster_hit(monster: Node, hits_left: int) -> void:
	if monster == null or not is_instance_valid(monster):
		return
	_status_label.text = "%s has %d hits left. Keep building!" % [String(monster.get("display_name")), hits_left]


func _on_monster_defeated(monster: Node, gold: int, resource: int) -> void:
	_gold += gold
	_resource += resource
	_refresh_hud()
	var monster_name := "The monster"
	if monster != null and is_instance_valid(monster):
		monster_name = String(monster.get("display_name"))
	_status_label.text = "%s drops %d gold and %d %s." % [monster_name, gold, resource, RESOURCE_NAME.to_lower()]


func _on_status_changed(text: String) -> void:
	_status_label.text = text


# --------------------------------------------------------------------- HUD

func _refresh_hud() -> void:
	_quests_label.text = "Quests: %d / %d" % [_quests_done, _total_quests]
	_coins_label.text = "Coins: %d" % _coins
	_gold_label.text = "Gold: %d" % _gold
	_resource_label.text = "%s: %d" % [RESOURCE_NAME, _resource]
