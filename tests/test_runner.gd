extends Node

## Headless self-test for the OG systems. Run from the project folder:
##   godot --headless res://tests/test_runner.tscn
## It never touches the child's real save (Learner.use_memory_only()).

const Data := preload("res://scripts/og/og_data.gd")
const BattleScene := preload("res://scenes/combat/battle_screen.tscn")
const WorldScene := preload("res://scenes/iso_world.tscn")

var fails: Array = []
var checks := 0
var mode_seen := {}
var fallbacks := {}


func _ready() -> void:
	Learner.use_memory_only()
	await get_tree().process_frame
	test_questions()
	await test_battles()
	test_learner()
	await test_world()
	print("\n=== OG SELF-TEST ===")
	print("checks: %d   failures: %d" % [checks, fails.size()])
	var modes := mode_seen.keys()
	modes.sort()
	print("modes produced (%d): %s" % [modes.size(), ", ".join(modes)])
	if not fallbacks.is_empty():
		print("fallbacks (requested -> produced): %s" % str(fallbacks))
	for f in fails.slice(0, 60):
		print("FAIL ", f)
	get_tree().quit(1 if fails.size() > 0 else 0)


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails.append(what)


# ------------------------------------------------------------- questions

func validate_question(q: Dictionary, where: String) -> void:
	check(not q.is_empty(), where + " empty question")
	if q.is_empty():
		return
	var kind := String(q.get("kind", ""))
	check(kind in ["build", "phoneme", "choice", "count", "split", "type"], where + " bad kind " + kind)
	check(String(q.get("prompt", "")) != "", where + " no prompt")
	match kind:
		"build":
			var e: Dictionary = q["entry"]
			check("".join(q["tiles"]).to_lower() == String(e["word"]).to_lower(), where + " tiles don't spell " + String(e["word"]))
			for t in q["tiles"]:
				check(q["pool"].has(t), where + " pool missing tile " + String(t))
		"phoneme":
			for s in q["sounds"]:
				var found := false
				for it in q["items"]:
					if String(it["sound"]) == String(s):
						found = true
				check(found, where + " phoneme item missing " + String(s))
			check(not q["sounds"].has("-"), where + " silent sound in phoneme question")
		"choice":
			var opts: Array = q["options"]
			check(opts.size() >= 2, where + " fewer than 2 options")
			var n_ok := 0
			var texts := {}
			for o in opts:
				if bool(o["correct"]):
					n_ok += 1
				texts[String(o["text"])] = true
			check(n_ok >= 1, where + " no correct option")
			check(bool(q.get("inline", false)) or texts.size() == opts.size(), where + " duplicate option text " + str(opts.map(func(o): return o["text"])))
			if String(q["mode"]) != "heart_word":
				check(n_ok == 1, where + " more than one correct option " + str(opts.map(func(o): return o["text"])))
		"count":
			check(int(q["target"]) >= 1, where + " count target < 1")
		"split":
			var w := String(q["letters"])
			for c in q["cuts"]:
				check(int(c) > 0 and int(c) < w.length(), where + " bad cut")
			check(q["cuts"].size() >= 1, where + " no cuts")
		"type":
			check(String(q["answer"]) != "", where + " no answer")


func test_questions() -> void:
	# Pretend a few stages are mastered so Light (review) has material.
	for sid in ["A1", "A4", "B1", "C1", "C2", "D1", "E2", "F3"]:
		Learner._st(sid)["mastered"] = true
	for st in Data.STAGES:
		var sid := String(st["id"])
		for attack in ["wand", "light", "heavy"]:
			for tier in 3:
				for i in 12:
					var ctx := {"stage": sid, "attack": attack, "tier": tier, "exclude": [], "band": "F", "review_stages": Learner.mastered_stages()}
					var q := QuestionFactory.make(ctx)
					var where := "%s/%s/t%d" % [sid, attack, tier]
					validate_question(q, where)
					mode_seen[String(q.get("mode", "?"))] = true
					var want := String(st["modes"][attack])
					if attack != "light" and String(q.get("mode", "")) != want and not (want in ["word_build", "morpheme_smith", "magic_e", "heart_word"] and String(q.get("mode", "")) == "dictation"):
						fallbacks["%s:%s" % [sid, want]] = String(q.get("mode", ""))
	for sid in ["A1", "A4", "B1", "C1", "C2", "D1", "E2", "F3"]:
		Learner._st(sid)["mastered"] = false


# --------------------------------------------------------------- battles

func test_battles() -> void:
	var battle: Control = BattleScene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	var hits := [0]
	var misses := [0]
	battle.word_solved.connect(func(_w, _d): hits[0] += 1)
	battle.attack_missed.connect(func(): misses[0] += 1)
	for st in Data.STAGES:
		var sid := String(st["id"])
		if sid == "R1" or sid == "H1":
			continue
		for attack in ["wand", "light", "heavy"]:
			for tier_name in ["easy", "normal", "hard"]:
				Learner.settings["tier_override"] = tier_name
				# correct answer -> exactly one hit
				battle.open_battle({"name": "T", "zone": 0, "stage": sid, "kind": "stage", "combat_mode": "speed", "hits_total": 3, "hits_left": 3}, null)
				var h0: int = hits[0]
				battle._on_attack(attack)
				var q: Dictionary = battle.current_question()
				battle.debug_answer_correctly()
				check(hits[0] == h0 + 1, "%s/%s/%s correct answer did not hit (mode %s kind %s word %s)" % [sid, attack, tier_name, q.get("mode"), q.get("kind"), q.get("word")])
				# wrong answers: Easy never misses, Normal/Hard miss within their tries
				battle.begin_round("")
				battle._on_attack(attack)
				q = battle.current_question()
				var m0: int = misses[0]
				for i in 4:
					if battle._locked:
						break
					battle.debug_answer_wrong()
				if int(q.get("tier", 0)) == 0:
					check(misses[0] == m0, "%s/%s easy item missed (mode %s)" % [sid, attack, q.get("mode")])
				else:
					check(misses[0] == m0 + 1, "%s/%s/%s wrong answers never missed (mode %s kind %s)" % [sid, attack, tier_name, q.get("mode"), q.get("kind")])
	# boss, heart and quest fights
	Learner.settings["tier_override"] = "normal"
	for info in [
		{"name": "Boss", "zone": 2, "stage": "C8", "kind": "boss", "stages": ["C1", "C2", "C3"], "combat_mode": "forge"},
		{"name": "Heart", "zone": 2, "stage": "H1", "kind": "heart", "combat_mode": "speed"},
		{"name": "Quest", "zone": 1, "stage": "R1", "kind": "quest", "combat_mode": "forge"},
	]:
		for attack in ["wand", "light", "heavy"]:
			battle.open_battle(info, null)
			var h0: int = hits[0]
			battle._on_attack(attack)
			battle.debug_answer_correctly()
			check(hits[0] == h0 + 1, "%s/%s did not hit (mode %s)" % [info["kind"], attack, battle.current_question().get("mode")])
	Learner.settings["tier_override"] = "auto"
	battle.close_overlay()
	battle.queue_free()
	Learner.reset_progress(false)
	await get_tree().process_frame


# --------------------------------------------------------------- learner

func test_learner() -> void:
	Learner.reset_progress(false)
	check(Learner.current_stage() == "A1", "fresh profile should start at A1, got " + Learner.current_stage())
	check(Learner.is_stage_unlocked("A1"), "A1 should be unlocked")
	check(not Learner.is_stage_unlocked("A2"), "A2 should be locked")
	check(not Learner.is_zone_unlocked(1), "zone 1 should be sealed")
	Learner.settings["mastery_days"] = 1
	for i in 10:
		Learner.record("A1", true)
	check(Learner.is_mastered("A1"), "A1 should master after 10/10 with 1 day")
	check(Learner.is_stage_unlocked("A2"), "A2 should unlock after A1")
	check(Learner.tier_for("A1") != "easy", "tier should step up after high accuracy")
	Learner.settings["mastery_days"] = 2
	for i in 10:
		Learner.record("A2", true)
	check(not Learner.is_mastered("A2"), "A2 must not master in one day when 2 days are required")
	check(Learner.days_at_mastery("A2") == 1, "A2 should have one day at mastery")
	Learner.stages["A2"]["days"].append("2000-01-01")
	Learner.record("A2", true)
	check(Learner.is_mastered("A2"), "A2 should master after a second day")
	for i in 8:
		Learner.record("A3", false)
	check(not Learner.is_mastered("A3"), "A3 must not master with 0%")
	check(Learner.tier_for("A3") == "easy", "low accuracy keeps Easy")
	check(Learner.review_stage() in ["A1", "A2"], "review stage must be a mastered stage")
	# boss gate
	for sid in OGCurriculum.zone_stages(0):
		Learner._st(String(sid))["mastered"] = true
	check(Learner.is_boss_ready(0), "boss 0 ready when zone 0 mastered")
	check(not Learner.is_zone_unlocked(1), "zone 1 sealed until boss beaten")
	Learner.mark_boss_defeated(0)
	check(Learner.is_zone_unlocked(1), "zone 1 opens after boss 0")
	check(Learner.current_stage() == "B1", "current stage after zone 0 should be B1")
	Learner.place_at_zone(3)
	check(Learner.is_zone_unlocked(3) and Learner.is_stage_unlocked("D1"), "placement opens zone 3 / D1")
	check(not Learner.is_zone_unlocked(4), "placement at 3 keeps 4 sealed")
	Learner.reset_progress(false)
	check(Learner.current_stage() == "A1", "reset returns to A1")


# ----------------------------------------------------------------- world

func test_world() -> void:
	Learner.reset_progress(false)
	Learner.settings["started"] = true
	var world: Node2D = WorldScene.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var monsters := get_tree().get_nodes_in_group("monster")
	var expected := 0
	for z in OGCurriculum.zone_count():
		expected += OGCurriculum.zone_stages(z).size() + 1 + (1 if z >= 1 else 0) + (1 if z == 1 else 0)
	check(monsters.size() == expected, "monster count %d expected %d" % [monsters.size(), expected])
	var awake: Array = []
	for m in monsters:
		if not m.is_asleep():
			awake.append("%s/%s" % [m.kind, m.stage_id])
	check(awake == ["stage/A1"], "fresh world: only A1 monster awake, got " + str(awake))
	Learner.place_at_zone(2)
	await get_tree().process_frame
	awake.clear()
	for m in monsters:
		if not m.is_asleep() and m.zone_id == 2:
			awake.append("%s/%s" % [m.kind, m.stage_id])
	awake.sort()
	check(awake == ["heart/H1", "stage/C1"], "zone 2 after placement: C1 + heart awake, got " + str(awake))
	# simulate a full fight against the C1 monster through the world
	var c1: Node = null
	for m in monsters:
		if m.stage_id == "C1" and m.kind == "stage":
			c1 = m
	world._on_monster_contacted(c1)
	check(world.is_world_busy(), "fight should start on contact")
	var battle: Control = world._battle
	var guard := 0
	while world.is_world_busy() and guard < 20:
		guard += 1
		battle._on_attack("heavy")
		battle.debug_answer_correctly()
		await get_tree().create_timer(1.3).timeout
	check(not world.is_world_busy(), "fight should end after enough heavy hits")
	check(c1.is_defeated(), "C1 monster should be defeated")
	check(Learner.gold > 0, "loot should be granted")
	world.queue_free()
	await get_tree().process_frame
