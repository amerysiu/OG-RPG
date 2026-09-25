extends RefCounted

## The wild encounter referee.
##
## The village owns the world but delegates every monster fight to this object,
## so the two responsibilities stay apart and each file stays short.
##
## A fight works like this:
##   contact -> freeze the player and the NPCs -> open the Word Build overlay
##   one correctly built word -> one hit
##   hits left above zero        -> deal the next word for the same monster
##   hits left zero              -> mark the monster defeated, award gold and a
##                                  resource, close and restore movement
##   Escape at any time          -> flee: close, restore movement, monster alive
##
## Nothing here can trap the player: flee always restores the world.

signal status_changed(text: String)
signal encounter_started(monster: Node)
signal monster_hit(monster: Node, hits_left: int)
signal monster_defeated(monster: Node, gold: int, resource: int)
signal word_solved(word: String)

## Gold and resource handed out for each hit landed on a monster.
const GOLD_PER_HIT := 2
const RESOURCE_PER_HIT := 1

var _world: Node = null
var _player: Node = null
var _overlay: Control = null
var _npcs: Array = []
var _monster: Node = null
var _hits_total: int = 0
var _hits_left: int = 0
var _active: bool = false


## The village hands over everything the encounter needs to referee a fight.
func setup(world: Node, player: Node, overlay: Control, npcs: Array) -> void:
	_world = world
	_player = player
	_overlay = overlay
	_npcs = npcs

	if _overlay != null:
		_overlay.word_solved.connect(_on_word_solved)
		_overlay.flee_requested.connect(flee)
		_overlay.close_overlay()

	if world == null:
		return
	var handler := Callable(self, "_on_player_contacted")
	for monster in world.get_tree().get_nodes_in_group("monster"):
		if not monster.is_connected("player_contacted", handler):
			monster.connect("player_contacted", handler)


func is_busy() -> bool:
	return _active


# ------------------------------------------------------------------- fight

## True when an encounter actually opened.
func start(monster: Node) -> bool:
	if _active or monster == null or not is_instance_valid(monster):
		return false
	if bool(monster.call("is_defeated")):
		return false
	# An NPC quest overlay has priority: never stack two overlays.
	if _world != null and _world.has_method("is_world_busy") and bool(_world.call("is_world_busy")):
		return false

	_active = true
	_monster = monster
	_hits_total = maxi(1, int(monster.call("starting_hits")))
	_hits_left = _hits_total

	_set_world_frozen(true)
	monster.call("set_encounter_paused", true)
	monster.call("set_hits_left", _hits_left)

	if _overlay != null:
		_overlay.call("start_encounter", String(monster.get("display_name")), int(monster.get("word_level")), _hits_left)

	encounter_started.emit(monster)
	status_changed.emit("%s blocks the path - build its word to hit it." % String(monster.get("display_name")))
	return true


## Escape, or the Run away button: leave the fight with the monster alive.
func flee() -> void:
	if not _active:
		return
	var monster := _monster
	var monster_name := _monster_name(monster)
	_close()
	if monster != null and is_instance_valid(monster):
		monster.call("flee_from_player")
	status_changed.emit("You slipped away. %s is still out there." % monster_name)


func _on_player_contacted(monster: Node) -> void:
	start(monster)


func _on_word_solved(word: String) -> void:
	if not _active:
		return
	word_solved.emit(word)
	var monster := _monster
	if monster == null or not is_instance_valid(monster):
		return

	_hits_left = maxi(0, _hits_left - 1)
	monster.call("set_hits_left", _hits_left)
	monster_hit.emit(monster, _hits_left)

	if _hits_left > 0:
		status_changed.emit("%s - one hit! %s has %d hits left." % [word.to_upper(), String(monster.get("display_name")), _hits_left])
		if _overlay != null:
			_overlay.call("set_hits_left", _hits_left)
			_overlay.call("next_round")
		return

	var monster_name := _monster_name(monster)
	var gold := maxi(1, _hits_total * GOLD_PER_HIT)
	var resource := maxi(1, _hits_total * RESOURCE_PER_HIT)
	monster.call("mark_defeated")
	monster_defeated.emit(monster, gold, resource)
	_close()
	status_changed.emit("%s is defeated! You earn %d gold and %d resource." % [monster_name, gold, resource])


# ---------------------------------------------------------------- housekeeping

func _close() -> void:
	if _overlay != null:
		_overlay.call("close_overlay")
	_set_world_frozen(false)
	_monster = null
	_active = false


func _set_world_frozen(frozen: bool) -> void:
	if _player != null and is_instance_valid(_player):
		_player.call("set_input_enabled", not frozen)
	for npc in _npcs:
		if npc != null and is_instance_valid(npc):
			npc.call("set_interaction_enabled", not frozen)


func _monster_name(monster: Node) -> String:
	if monster == null or not is_instance_valid(monster):
		return "The monster"
	return String(monster.get("display_name"))
