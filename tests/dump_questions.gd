extends Node
func _ready() -> void:
	Learner.use_memory_only()
	for sid in ["A1","A2","C1","D1","E2"]:
		Learner._st(sid)["mastered"] = true
	for st in OGCurriculum.Data.STAGES:
		var sid := String(st["id"])
		for attack in ["wand","light","heavy"]:
			var tier := 1
			var q := QuestionFactory.make({"stage": sid, "attack": attack, "tier": tier, "exclude": [], "band": "F", "review_stages": ["A1","C1","D1"]})
			var line := "%s %-5s %-17s [%s t%d] %s" % [q["stage"], attack, q["mode"], q["kind"], q["tier"], String(q["prompt"]).replace("\n"," / ")]
			match String(q["kind"]):
				"choice":
					line += "  OPTS: " + " | ".join(q["options"].map(func(o): return ("*" if o["correct"] else "") + String(o.get("word", o["text"]))))
				"build":
					line += "  TILES: " + " ".join(q["tiles"]) + "  POOL: " + " ".join(q["pool"])
				"phoneme":
					line += "  SOUNDS: " + " ".join(q["sounds"])
				"count":
					line += "  TARGET %d (%s)" % [q["target"], q["entry"]["word"]]
				"split":
					line += "  %s cuts %s" % [q["letters"], str(q["cuts"])]
				"type":
					line += "  ANSWER " + String(q["answer"])
			if String(q.get("rule","")) != "": line += "  RULE: " + String(q["rule"])
			print(line)
	get_tree().quit()
