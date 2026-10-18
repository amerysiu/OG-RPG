extends Node

## One child's progress through the OG sequence (autoload "Learner").
##
## OG is diagnostic and prescriptive, so every answered item is recorded
## against its stage. A stage is MASTERED when the child scores >= 80% on
## the last 10 items on `mastery_days` separate days (default 2). Mastery
## opens the next stage; a zone opens when the previous zone's boss falls.
##
## Difficulty (Easy / Normal / Hard) is set per stage by the adaptive rule:
## >= 90% recent accuracy steps up, < 70% steps down. A teacher can force a
## tier, change the number of days, place the child, or reset.

signal changed
signal stage_mastered(stage_id: String)
signal tier_changed(stage_id: String, tier: String)

const SAVE_PATH := "user://og_learner.json"
const WINDOW := 10
## Items needed in the window before accuracy can count toward mastery.
const MIN_ITEMS := 8
const MASTERY := 0.8
const STEP_UP := 0.9
const STEP_DOWN := 0.7
## Items answered at a tier before the adaptive rule may move it again.
const TIER_SETTLE := 6
const TIERS := ["easy", "normal", "hard"]

var settings := {
	"tier_override": "auto",
	"mastery_days": 2,
	"started": false,
}
var stages: Dictionary = {}
var bosses: Dictionary = {}
var xp := 0
var level := 1
var gold := 0
var wood := 0
var history: Array = []

var _persist := true


func _ready() -> void:
	load_profile()


## Tests call this so they never touch the child's real save.
func use_memory_only() -> void:
	_persist = false
	reset_progress(false)


# ------------------------------------------------------------------ queries

func _st(stage_id: String) -> Dictionary:
	if not stages.has(stage_id):
		stages[stage_id] = {
			"recent": [],
			"days": [],
			"mastered": false,
			"tier": "easy",
			"since_tier": 0,
			"total": 0,
			"correct": 0,
		}
	return stages[stage_id]


func accuracy(stage_id: String) -> float:
	var recent: Array = _st(stage_id)["recent"]
	if recent.is_empty():
		return 0.0
	var good := 0
	for r in recent:
		if bool(r):
			good += 1
	return float(good) / float(recent.size())


func recent_count(stage_id: String) -> int:
	return _st(stage_id)["recent"].size()


func days_at_mastery(stage_id: String) -> int:
	return _st(stage_id)["days"].size()


func is_mastered(stage_id: String) -> bool:
	return bool(_st(stage_id)["mastered"])


func tier_for(stage_id: String) -> String:
	var forced := String(settings.get("tier_override", "auto"))
	if forced in TIERS:
		return forced
	return String(_st(stage_id)["tier"])


func tier_index(stage_id: String) -> int:
	return TIERS.find(tier_for(stage_id))


func is_zone_unlocked(zone_id: int) -> bool:
	if zone_id <= 0:
		return true
	return is_boss_defeated(zone_id - 1)


func is_boss_defeated(zone_id: int) -> bool:
	return bool(bosses.get(str(zone_id), false))


## The boss wakes once every stage of its zone is mastered.
func is_boss_ready(zone_id: int) -> bool:
	if not is_zone_unlocked(zone_id):
		return false
	for sid in OGCurriculum.zone_stages(zone_id):
		if not is_mastered(String(sid)):
			return false
	return true


func is_stage_unlocked(stage_id: String) -> bool:
	if stage_id == "H1" or stage_id == "R1":
		return true
	if is_mastered(stage_id):
		return true
	if not is_zone_unlocked(OGCurriculum.zone_of_stage(stage_id)):
		return false
	var prev := OGCurriculum.previous_stage(stage_id)
	if prev == "":
		return true
	return is_mastered(prev)


## The first stage the child has not mastered yet.
func current_stage() -> String:
	for sid in OGCurriculum.sequence():
		if not is_mastered(String(sid)):
			return String(sid)
	var seq := OGCurriculum.sequence()
	return String(seq[seq.size() - 1])


func mastered_stages() -> Array:
	var out: Array = []
	for sid in OGCurriculum.sequence():
		if is_mastered(String(sid)):
			out.append(String(sid))
	return out


## A mastered stage to review (cumulative review). Recently mastered stages
## come up more often; returns "" when nothing is mastered yet.
func review_stage(exclude: String = "") -> String:
	var pool := mastered_stages()
	pool.erase(exclude)
	if pool.is_empty():
		return ""
	# Weight the last three mastered stages double.
	var weighted: Array = pool.duplicate()
	for i in range(maxi(0, pool.size() - 3), pool.size()):
		weighted.append(pool[i])
	return String(weighted[randi() % weighted.size()])


## The highest band the child has reached (for heart words and sentences).
func reached_band() -> String:
	return OGCurriculum.band_of(current_stage())


func highest_unlocked_zone() -> int:
	var best := 0
	for z in OGCurriculum.zone_count():
		if is_zone_unlocked(z):
			best = z
	return best


func status_text(stage_id: String) -> String:
	if is_mastered(stage_id):
		return "Mastered"
	if not is_stage_unlocked(stage_id):
		return "Locked"
	var n := recent_count(stage_id)
	var days := days_at_mastery(stage_id)
	var need := int(settings.get("mastery_days", 2))
	if n < MIN_ITEMS:
		return "Learning · %d/%d items" % [n, MIN_ITEMS]
	return "Learning · %d%% · day %d/%d" % [roundi(accuracy(stage_id) * 100.0), days, need]


# ------------------------------------------------------------------ updates

## Record one answered item. `correct` means right with no errors or hints.
## Returns what changed so the game can celebrate it.
func record(stage_id: String, correct: bool, detail: Dictionary = {}) -> Dictionary:
	var st := _st(stage_id)
	var recent: Array = st["recent"]
	recent.append(correct)
	while recent.size() > WINDOW:
		recent.pop_front()
	st["total"] = int(st["total"]) + 1
	if correct:
		st["correct"] = int(st["correct"]) + 1
	st["since_tier"] = int(st["since_tier"]) + 1

	var result := {"mastered_now": false, "tier_from": tier_for(stage_id), "tier_to": tier_for(stage_id), "level_up": false}
	var acc := accuracy(stage_id)
	if recent.size() >= MIN_ITEMS and acc >= MASTERY:
		var today := Time.get_date_string_from_system()
		var days: Array = st["days"]
		if not days.has(today):
			days.append(today)
	if not bool(st["mastered"]) and st["days"].size() >= int(settings.get("mastery_days", 2)) and stage_id != "H1" and stage_id != "R1":
		st["mastered"] = true
		result["mastered_now"] = true

	_adapt_tier(stage_id, result)

	if correct:
		xp += 1
		while xp >= level * 10:
			xp -= level * 10
			level += 1
			result["level_up"] = true

	var item := {"stage": stage_id, "ok": correct, "date": Time.get_date_string_from_system()}
	item.merge(detail)
	history.append(item)
	while history.size() > 300:
		history.pop_front()
	save()
	if result["mastered_now"]:
		stage_mastered.emit(stage_id)
	changed.emit()
	return result


func _adapt_tier(stage_id: String, result: Dictionary) -> void:
	var st := _st(stage_id)
	if int(st["since_tier"]) < TIER_SETTLE:
		return
	var recent: Array = st["recent"]
	var look := mini(recent.size(), int(st["since_tier"]))
	var good := 0
	for i in range(recent.size() - look, recent.size()):
		if bool(recent[i]):
			good += 1
	var acc := float(good) / float(maxi(1, look))
	var idx := TIERS.find(String(st["tier"]))
	var new_idx := idx
	if acc >= STEP_UP:
		new_idx = mini(idx + 1, TIERS.size() - 1)
	elif acc < STEP_DOWN:
		new_idx = maxi(idx - 1, 0)
	if new_idx != idx:
		st["tier"] = TIERS[new_idx]
		st["since_tier"] = 0
		result["tier_to"] = tier_for(stage_id)
		tier_changed.emit(stage_id, String(st["tier"]))


func mark_boss_defeated(zone_id: int) -> void:
	bosses[str(zone_id)] = true
	save()
	changed.emit()


func add_loot(add_gold: int, add_wood: int) -> void:
	gold += add_gold
	wood += add_wood
	save()
	changed.emit()


## Teacher placement: everything before `zone_id` counts as mastered.
func place_at_zone(zone_id: int) -> void:
	for z in range(0, zone_id):
		for sid in OGCurriculum.zone_stages(z):
			var st := _st(String(sid))
			st["mastered"] = true
			st["placed"] = true
		bosses[str(z)] = true
	settings["started"] = true
	save()
	changed.emit()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save()
	changed.emit()


func reset_progress(persist := true) -> void:
	stages.clear()
	bosses.clear()
	history.clear()
	xp = 0
	level = 1
	gold = 0
	wood = 0
	settings["started"] = false
	if persist:
		save()
	changed.emit()


# -------------------------------------------------------------- save / load

func save() -> void:
	if not _persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": 1,
		"settings": settings,
		"stages": stages,
		"bosses": bosses,
		"xp": xp,
		"level": level,
		"gold": gold,
		"wood": wood,
		"history": history,
	}))


func load_profile() -> void:
	if not _persist or not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var saved_settings: Dictionary = data.get("settings", {})
	for k in saved_settings.keys():
		settings[k] = saved_settings[k]
	settings["mastery_days"] = int(settings.get("mastery_days", 2))
	stages = data.get("stages", {})
	for sid in stages.keys():
		var st: Dictionary = stages[sid]
		st["total"] = int(st.get("total", 0))
		st["correct"] = int(st.get("correct", 0))
		st["since_tier"] = int(st.get("since_tier", 0))
	bosses = data.get("bosses", {})
	xp = int(data.get("xp", 0))
	level = int(data.get("level", 1))
	gold = int(data.get("gold", 0))
	wood = int(data.get("wood", 0))
	history = data.get("history", [])
