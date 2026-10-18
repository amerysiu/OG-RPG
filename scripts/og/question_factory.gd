extends RefCounted
class_name QuestionFactory

## Turns (stage, attack, tier) into one OG question the battle screen can show.
##
## The stage fixes the CONTENT; the tier only changes SCAFFOLDING (audio,
## distractors, tries, rule cards). Attacks map to the OG lesson parts:
##   wand  - listening question on the current stage            (1 damage)
##   light - recognition question on a MASTERED stage (review)  (1 damage)
##   heavy - encoding: spell / build the current pattern        (2 damage)
##
## A question is a Dictionary. Every question has:
##   kind     build | phoneme | choice | count | split | type
##   mode     mode key (see MODE_NAMES), stage, tier, damage, tries, prompt,
##   rule     rule-card text ("" = hidden), audio (list of audio refs),
##   entry    the word entry ({} when none), word (for logging)
## Audio refs: {"w": word} {"s": "/k/"} {"u": [sound, tile]} {"k": chunk} {"pause": sec}

const Data := preload("res://scripts/og/og_data.gd")

const MODE_NAMES := {
	"rhyme_hunt": "Rhyme Hunt",
	"syllable_drum": "Syllable Drum",
	"onset_forge": "Onset Forge",
	"echo_shield": "Echo Shield",
	"sound_slide": "Sound Slide",
	"elkonin": "Elkonin Boxes",
	"word_chain": "Word Chain",
	"vowel_pick": "Vowel Pick",
	"twin_caves": "Twin Caves",
	"word_build": "Word Build",
	"sound_pick": "Sound Pick",
	"which_spelling": "Which Spelling?",
	"morpheme_smith": "Morpheme Smith",
	"magic_e": "Magic-e Wand",
	"syllable_sort": "Syllable Sort",
	"syllable_splitter": "Syllable Splitter",
	"real_or_nonsense": "Real or Nonsense?",
	"rule_gate": "Rule Gate",
	"meaning_pick": "Meaning Match",
	"root_tree": "Root Tree",
	"heart_word": "Heart Word",
	"stress_pick": "Loud Syllable",
	"schwa_pick": "Lazy Vowel",
	"sentence_scroll": "Sentence Scroll",
	"dictation": "Dictation Scroll",
}

## Scaffolding by tier (index 0 easy, 1 normal, 2 hard).
const TIER := [
	{"name": "Easy", "distractors": 1, "options": 2, "tries": -1, "repeat": true, "chips": true, "tile_audio": true, "rule": true, "gap": 0.15},
	{"name": "Normal", "distractors": 3, "options": 3, "tries": 3, "repeat": false, "chips": false, "tile_audio": true, "rule": false, "gap": 0.45},
	{"name": "Hard", "distractors": 5, "options": 4, "tries": 2, "repeat": false, "chips": false, "tile_audio": false, "rule": false, "gap": 0.45},
]

## Deliberately confusable neighbours: the classic OG confusions.
const CONFUSABLES := {
	"sh": ["ch", "th", "s"], "ch": ["sh", "th", "tch"], "th": ["sh", "ch", "t"], "wh": ["w", "h"],
	"ck": ["c", "k"], "c": ["k", "ck", "s"], "k": ["c", "ck"], "qu": ["kw", "q"],
	"b": ["d", "p"], "d": ["b", "p"], "p": ["b", "d", "q"], "q": ["p", "g"], "t": ["d", "f"],
	"m": ["n", "w"], "n": ["m", "r"], "f": ["v", "ff"], "g": ["j", "q"], "v": ["f", "w"],
	"l": ["ll", "r"], "r": ["l", "w"], "s": ["z", "ss", "c"], "w": ["m", "wh"], "z": ["s", "zz"],
	"j": ["g", "dge"], "h": ["n", "wh"], "x": ["ks", "z"], "y": ["i", "j"],
	"a": ["e", "o", "u"], "e": ["i", "a"], "i": ["e", "a"], "o": ["a", "u"], "u": ["o", "a"],
	"ff": ["f"], "ll": ["l"], "ss": ["s"], "zz": ["z"], "tch": ["ch"], "dge": ["ge", "j"], "ge": ["dge"],
	"ai": ["ay", "a"], "ay": ["ai"], "ee": ["ea", "e"], "ea": ["ee"], "oa": ["ow", "o"], "ow": ["oa", "ou"], "igh": ["i", "ie"],
	"ar": ["or", "er"], "or": ["ar", "er"], "er": ["ir", "ur"], "ir": ["er", "ur"], "ur": ["er", "ir"],
	"oi": ["oy"], "oy": ["oi"], "ou": ["ow"], "aw": ["au"], "au": ["aw"], "oo": ["ew", "u"], "ew": ["oo", "ue"],
	"kn": ["n"], "wr": ["r"], "mb": ["m"], "gn": ["n"],
	"ing": ["ang", "ink"], "ang": ["ing", "ank"], "ong": ["ung", "ang"], "ung": ["ong", "ing"],
	"ink": ["ing", "ank"], "ank": ["ang", "ink"], "unk": ["ung", "ank"], "all": ["al", "ill"],
}

const VOWELS := ["a", "e", "i", "o", "u"]

## Which Which-Spelling? families each stage practises (OG: only what's taught).
const STAGE_FAMILIES := {
	"C2": ["k_final"], "C3": ["floss"], "C7": ["tch", "dge"], "C8": ["s_es"],
	"D3": ["ai_ay", "ee_ea", "oa_ow"], "D4": ["ar_or", "er_ir_ur"], "D5": ["oi_oy", "ou_ow", "aw_au"],
}


# ===================================================================== entry

## ctx keys: stage (String), attack (wand|light|heavy), tier (0..2),
## exclude (Array of recent words), band ("C" etc., for heart words / sentences)
static func make(ctx: Dictionary) -> Dictionary:
	var stage_id := String(ctx.get("stage", "C1"))
	var attack := String(ctx.get("attack", "wand"))
	var tier := clampi(int(ctx.get("tier", 1)), 0, 2)
	var st := OGCurriculum.stage(stage_id)
	if st.is_empty():
		stage_id = "C1"
		st = OGCurriculum.stage(stage_id)
	var mode := String(st["modes"].get(attack, "word_build"))
	if attack == "heavy":
		tier = mini(tier + 1, 2)
	elif attack == "light":
		tier = maxi(tier - 1, 0)
	var q := _make_mode(mode, stage_id, tier, ctx)
	if q.is_empty():
		q = _fallback(stage_id, tier, ctx)
	q["stage"] = stage_id
	q["tier"] = tier
	q["attack"] = attack
	q["damage"] = 2 if attack == "heavy" else 1
	q["tries"] = int(TIER[tier]["tries"])
	q["repeat"] = bool(TIER[tier]["repeat"])
	if not q.has("rule"):
		q["rule"] = String(st.get("rule", "")) if bool(TIER[tier]["rule"]) else ""
	q["mode_name"] = String(MODE_NAMES.get(String(q.get("mode", mode)), String(q.get("mode", mode))))
	if not q.has("word"):
		q["word"] = String(q.get("entry", {}).get("word", ""))
	return q


static func _make_mode(mode: String, stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	match mode:
		"rhyme_hunt":
			return rhyme_hunt(stage_id, tier, ctx)
		"syllable_drum":
			return syllable_drum(stage_id, tier, ctx)
		"onset_forge":
			return onset_forge(stage_id, tier, ctx)
		"echo_shield":
			return echo_shield(stage_id, tier, ctx)
		"sound_slide":
			return sound_slide(stage_id, tier, ctx)
		"elkonin":
			return elkonin(stage_id, tier, ctx)
		"word_chain":
			return word_chain(stage_id, tier, ctx)
		"vowel_pick":
			return vowel_pick(stage_id, tier, ctx)
		"twin_caves":
			return twin_caves(stage_id, tier, ctx)
		"word_build":
			return word_build(stage_id, tier, ctx)
		"sound_pick":
			return sound_pick(stage_id, tier, ctx)
		"which_spelling":
			return which_spelling(stage_id, tier, ctx)
		"morpheme_smith":
			return morpheme_smith(stage_id, tier, ctx)
		"magic_e":
			return magic_e(stage_id, tier, ctx)
		"syllable_sort":
			return syllable_sort(stage_id, tier, ctx)
		"syllable_splitter":
			return syllable_splitter(stage_id, tier, ctx)
		"real_or_nonsense":
			return real_or_nonsense(stage_id, tier, ctx)
		"rule_gate":
			return rule_gate(stage_id, tier, ctx)
		"meaning_pick":
			return meaning_pick(stage_id, tier, ctx)
		"root_tree":
			return root_tree(stage_id, tier, ctx)
		"heart_word":
			return heart_word(stage_id, tier, ctx)
		"stress_pick":
			return stress_pick(stage_id, tier, ctx, false)
		"schwa_pick":
			return stress_pick(stage_id, tier, ctx, true)
		"sentence_scroll":
			return sentence_scroll(stage_id, tier, ctx)
		"dictation":
			return dictation(stage_id, tier, ctx)
	return {}


static func _fallback(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	if OGCurriculum.band_of(stage_id) == "A":
		var q := sound_slide(stage_id, tier, ctx)
		if not q.is_empty():
			return q
	var b := word_build(stage_id, tier, ctx)
	if not b.is_empty():
		return b
	return word_build("C1", tier, ctx)


# =================================================================== helpers

static func _entries(stage_id: String, ctx: Dictionary) -> Array:
	if stage_id == "H1":
		return OGCurriculum.heart_words_up_to(String(ctx.get("band", "B")))
	if stage_id == "R1":
		var pool: Array = []
		for sid in ctx.get("review_stages", []):
			for e in OGCurriculum.words(String(sid)):
				if not bool(e.get("letter", false)) and String(e.get("unit", "")) == "":
					pool.append(e)
		if pool.is_empty():
			pool = OGCurriculum.words("C1")
		return pool
	return OGCurriculum.words(stage_id)


## Entries that may be the TARGET of a question: contrast words (closed words
## in the open-syllable stage, FLOSS rule-breakers, hard c/g ...) only ever
## appear as sorting items or distractors.
static func _targets(stage_id: String, ctx: Dictionary) -> Array:
	return _entries(stage_id, ctx).filter(func(e): return not bool(e.get("contrast", false)))


## Letters taught so far: in the letter band only earlier B stages count, so
## untaught letters never show up as distractors.
static func _taught_letters(stage_id: String) -> Array:
	var out: Array = []
	var limit := OGCurriculum.stage_index(stage_id)
	for st in Data.STAGES:
		if String(st["band"]) != "B":
			continue
		if limit >= 0 and OGCurriculum.band_of(stage_id) == "B" and OGCurriculum.stage_index(String(st["id"])) > limit:
			continue
		for e in Data.WORDS.get(String(st["id"]), []):
			for t in e["tiles"]:
				var g := String(t).to_lower()
				if g.length() <= 2 and not out.has(g):
					out.append(g)
	return out


static func _pick(entries: Array, ctx: Dictionary, filter: Callable = Callable()) -> Dictionary:
	var exclude: Array = ctx.get("exclude", [])
	var ok: Array = []
	var any: Array = []
	for e in entries:
		if filter.is_valid() and not bool(filter.call(e)):
			continue
		any.append(e)
		if not exclude.has(String(e.get("word", ""))):
			ok.append(e)
	if ok.is_empty():
		ok = any
	if ok.is_empty():
		return {}
	return ok[randi() % ok.size()]


static func _is_oral(stage_id: String) -> bool:
	return OGCurriculum.band_of(stage_id) == "A"


static func _clean_sounds(entry: Dictionary) -> bool:
	var sounds: Array = entry.get("sounds", [])
	if sounds.size() != entry.get("tiles", []).size():
		return false
	if String(entry.get("unit", "")) != "":
		return false
	for s in sounds:
		if String(s) == "-":
			return false
	return true


static func _word_audio(word: String) -> Array:
	return [{"w": word}]


static func _sounds_audio(entry: Dictionary, gap: float) -> Array:
	var out: Array = []
	var sounds: Array = entry.get("sounds", [])
	var tiles: Array = entry.get("tiles", [])
	for i in sounds.size():
		if String(sounds[i]) == "-":
			continue
		if String(entry.get("unit", "")) != "":
			out.append({"k": String(tiles[i])})
		else:
			out.append({"u": [String(sounds[i]), String(tiles[i])]})
		out.append({"pause": gap})
	return out


static func _option(text: String, correct: bool, audio: Array = []) -> Dictionary:
	return {"text": text, "correct": correct, "audio": audio}


## Oral options show a speaker label (no print); text appears only as a
## fallback when the clip is missing, so the item never becomes impossible.
static func _oral_option(index: int, word: String, correct: bool) -> Dictionary:
	var label := "▶ %d" % (index + 1)
	if not _has_word_audio(word):
		label = "▶ %d  (%s)" % [index + 1, word]
	return {"text": label, "correct": correct, "audio": _word_audio(word), "word": word}


static func _has_word_audio(word: String) -> bool:
	var fetcher = Engine.get_main_loop().root.get_node_or_null("CCAssetFetcher") if Engine.get_main_loop() is SceneTree else null
	if fetcher == null:
		return true
	return bool(fetcher.call("has_word_audio", word))


static func _shuffle_options(opts: Array) -> Array:
	var out := opts.duplicate()
	out.shuffle()
	return out


static func _choice(mode: String, entry: Dictionary, prompt: String, options: Array, audio: Array, oral: bool = false) -> Dictionary:
	var opts := _shuffle_options(options)
	if oral:
		# Re-number the speaker labels after shuffling.
		for i in opts.size():
			var o: Dictionary = opts[i]
			if o.has("word"):
				var w := String(o["word"])
				o["text"] = ("▶ %d" % (i + 1)) if _has_word_audio(w) else ("▶ %d  (%s)" % [i + 1, w])
	var answer := ""
	for o in opts:
		if bool(o["correct"]):
			answer = String(o.get("word", o["text"]))
			break
	return {
		"kind": "choice", "mode": mode, "entry": entry, "prompt": prompt, "options": opts,
		"audio": audio, "oral": oral, "confirm": oral, "answer_text": answer,
	}


static func _rime(entry: Dictionary) -> String:
	var tiles: Array = entry.get("tiles", [])
	var out := ""
	for i in range(1, tiles.size()):
		out += String(tiles[i])
	return out


static func _diff_positions(a: Dictionary, b: Dictionary) -> Array:
	var sa: Array = a.get("sounds", [])
	var sb: Array = b.get("sounds", [])
	if sa.size() != sb.size():
		return [-1]
	var diffs: Array = []
	for i in sa.size():
		if String(sa[i]) != String(sb[i]):
			diffs.append(i)
	return diffs


static func _vowel_index(entry: Dictionary) -> int:
	var tiles: Array = entry.get("tiles", [])
	for i in tiles.size():
		if String(tiles[i]).to_lower() in VOWELS:
			return i
	return -1


static func _blank_word(entry: Dictionary, index: int) -> String:
	var tiles: Array = entry.get("tiles", [])
	var parts: Array = []
	for i in tiles.size():
		parts.append("_" if i == index else String(tiles[i]))
	return " ".join(parts)


# ================================================================ oral modes

static func rhyme_hunt(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return e.get("tiles", []).size() == 3)
	if pool.size() < 4:
		return {}
	var target := _pick(pool, ctx)
	var rime := _rime(target)
	var rhymes: Array = pool.filter(func(e): return _rime(e) == rime and e["word"] != target["word"])
	var others: Array = pool.filter(func(e): return _rime(e) != rime)
	rhymes.shuffle()
	others.shuffle()
	if rhymes.is_empty() or others.size() < 3:
		return {}
	match tier:
		0:
			var partner: Dictionary = rhymes[0] if randf() < 0.5 else others[0]
			var yes := _rime(partner) == rime
			var opts := [
				_option("Yes, they rhyme", yes, _word_audio("yes")),
				_option("No", not yes, _word_audio("no")),
			]
			var q := _choice("rhyme_hunt", target, "Listen. Do these two words rhyme?", opts,
				[{"w": target["word"]}, {"pause": 0.6}, {"w": partner["word"]}])
			q["options"] = opts  # keep Yes before No
			return q
		1:
			var opts: Array = [_oral_option(0, rhymes[0]["word"], true)]
			for i in 2:
				opts.append(_oral_option(i + 1, others[i]["word"], false))
			return _choice("rhyme_hunt", target, "Listen to the word. Which one RHYMES with it?", opts,
				[{"w": target["word"]}], true)
		_:
			if rhymes.size() < 2:
				return rhyme_hunt(stage_id, 1, ctx)
			var opts: Array = [
				_oral_option(0, target["word"], false),
				_oral_option(1, rhymes[0]["word"], false),
				_oral_option(2, rhymes[1]["word"], false),
				_oral_option(3, others[0]["word"], true),
			]
			return _choice("rhyme_hunt", others[0], "Three of these words rhyme. Which one does NOT?", opts, [], true)


static func syllable_drum(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx)
	if tier == 2:
		var long_pool := pool.filter(func(e): return e.get("tiles", []).size() >= 3)
		var compounds := pool.filter(func(e): return e.get("tiles", []).size() == 2)
		if _is_oral(stage_id) and not compounds.is_empty() and randf() < 0.5:
			var c := _pick(compounds, ctx)
			var tiles: Array = c["tiles"]
			var drop := randi() % 2
			var keep := 1 - drop
			var opts := [
				_option("▶ 1", true, [{"k": String(tiles[keep])}]),
				_option("▶ 2", false, [{"k": String(tiles[drop])}]),
				_option("▶ 3", false, [{"w": c["word"]}]),
			]
			var q := _choice("syllable_drum", c, "Say %s without %s. Which is left?" % ["the word", "one part"], opts,
				[{"w": c["word"]}, {"pause": 0.5}, {"k": String(tiles[drop])}], true)
			q["prompt"] = "Listen: the word, then the part to take away. What is left?"
			return q
		if not long_pool.is_empty():
			pool = long_pool
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var units: Array = []
	for t in e["tiles"]:
		units.append([{"k": String(t)}])
	return {
		"kind": "count", "mode": "syllable_drum", "entry": e,
		"prompt": "Listen. Hit the drum once for each beat (syllable), then press Done.",
		"audio": _word_audio(e["word"]) if tier > 0 else _sounds_audio(e, 0.35) + [{"pause": 0.3}, {"w": e["word"]}],
		"target": e["tiles"].size(), "unit": "syllable", "unit_audio": units,
		"show_count": false, "guide": tier == 0, "token": "♪ Drum",
	}


static func onset_forge(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return e.get("tiles", []).size() == 3)
	var target := _pick(pool, ctx)
	if target.is_empty():
		return {}
	var rime := _rime(target)
	if tier < 2:
		var same_rime: Array = pool.filter(func(e): return _rime(e) == rime and e["sounds"][0] != target["sounds"][0])
		same_rime.shuffle()
		var n := 2 if tier == 0 else 3
		var opts: Array = []
		var first_audio: Array = [{"s": String(target["sounds"][0])}]
		if tier == 0:
			first_audio += [{"pause": 0.35}, {"w": target["word"]}]
		opts.append(_option("▶ 1", true, first_audio))
		var used: Array = [String(target["sounds"][0])]
		for e in same_rime:
			if opts.size() >= n:
				break
			var s := String(e["sounds"][0])
			if used.has(s):
				continue
			used.append(s)
			var a: Array = [{"s": s}]
			if tier == 0:
				a += [{"pause": 0.35}, {"w": e["word"]}]
			opts.append(_option("▶ %d" % (opts.size() + 1), false, a))
		if opts.size() < 2:
			return {}
		var q := _choice("onset_forge", target, "Which first sound goes on -%s to make the word you hear?" % "", opts,
			[{"w": target["word"]}, {"pause": 0.5}, {"k": "-" + rime}], true)
		q["prompt"] = "Listen to the word, then the ending. Which FIRST sound forges the word?"
		return q
	# Hard: keep the first sound, swap the ending.
	var onset := String(target["sounds"][0])
	var same_onset: Array = pool.filter(func(e): return String(e["sounds"][0]) == onset and _rime(e) != rime)
	var other_rimes: Array = []
	for e in pool:
		var r := _rime(e)
		if r != rime and not other_rimes.has(r):
			other_rimes.append(r)
	other_rimes.shuffle()
	var opts: Array = [_option("▶ 1", true, [{"k": "-" + rime}])]
	for r in other_rimes:
		if opts.size() >= 3:
			break
		opts.append(_option("▶ %d" % (opts.size() + 1), false, [{"k": "-" + String(r)}]))
	var q := _choice("onset_forge", target, "", opts, [{"s": onset}, {"pause": 0.4}, {"w": target["word"]}], true)
	q["prompt"] = "Keep the first sound. Which ENDING makes the word you hear?"
	return q


static func echo_shield(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var band := OGCurriculum.band_of(stage_id)
	var pool := _entries(stage_id, ctx)
	if band == "A":
		var cvc := pool.filter(func(e): return _clean_sounds(e) and e["sounds"].size() == 3)
		var pos: int = [0, 2, 1][tier]
		var where: String = ["Which word STARTS with this sound?", "Which word ENDS with this sound?", "Which word has this sound in the MIDDLE?"][tier]
		var target := _pick(cvc, ctx)
		if target.is_empty():
			return {}
		var snd := String(target["sounds"][pos])
		var others: Array = cvc.filter(func(e): return String(e["sounds"][pos]) != snd)
		others.shuffle()
		var n: int = [2, 3, 4][tier]
		var opts: Array = [_oral_option(0, target["word"], true)]
		var used: Array = [target["word"]]
		for e in others:
			if opts.size() >= n:
				break
			if used.has(e["word"]):
				continue
			used.append(e["word"])
			opts.append(_oral_option(opts.size(), e["word"], false))
		var q := _choice("echo_shield", target, where, opts,
			[{"s": snd}, {"pause": 0.5}, {"s": snd}], true)
		return q
	# Letter bands: hear a sound, raise the shield with its letter.
	var letters := pool.filter(func(e): return bool(e.get("letter", false)))
	if not letters.is_empty():
		var target := _pick(letters, ctx)
		var g := String(target["tiles"][0])
		var n: int = [2, 3, 5][tier]
		var taught := _taught_letters(stage_id)
		var cands: Array = []
		for c in CONFUSABLES.get(g, []):
			if String(c).length() == 1 and taught.has(String(c)):
				cands.append(String(c))
		for e in letters:
			cands.append(String(e["tiles"][0]))
		var shuffled_taught := taught.duplicate()
		shuffled_taught.shuffle()
		for c in shuffled_taught:
			if String(c).length() == 1:
				cands.append(String(c))
		var opts: Array = [_option(g, true, [{"s": String(target["sounds"][0])}])]
		var used: Array = [g]
		for c in cands:
			if opts.size() >= n:
				break
			if used.has(c):
				continue
			used.append(c)
			opts.append(_option(c, false, []))
		return _choice("echo_shield", target, "Listen to the sound. Which letter makes it?", opts,
			[{"s": String(target["sounds"][0])}, {"pause": 0.5}, {"s": String(target["sounds"][0])}])
	# Pattern bands (D4/D5, B6 words): which letters spell the sound you hear?
	var fam_pool := _targets(stage_id, ctx).filter(func(e): return e.has("family") or e.has("sort"))
	var target := _pick(fam_pool, ctx)
	if target.is_empty():
		return {}
	var tiles: Array = target["tiles"]
	var idx := -1
	var options: Array = []
	if target.has("family") and Data.FAMILIES.has(String(target["family"])):
		options = Data.FAMILIES[String(target["family"])]["options"].duplicate()
		for i in tiles.size():
			if options.has(String(tiles[i])):
				idx = i
				break
	else:
		idx = 0
		options = ["b", "d", "p"]
	if idx < 0:
		return {}
	var answer := String(tiles[idx])
	var opts: Array = [_option(answer, true, [{"u": [String(target["sounds"][idx]), answer]}])]
	for o in options:
		if String(o) != answer and opts.size() < [2, 3, 4][tier]:
			opts.append(_option(String(o), false, []))
	if tier == 2:
		for c in CONFUSABLES.get(answer, []):
			if opts.size() >= 4:
				break
			var dup := false
			for o in opts:
				if String(o["text"]) == String(c):
					dup = true
			if not dup:
				opts.append(_option(String(c), false, []))
	var where := "its FIRST sound" if idx == 0 else "its VOWEL sound"
	return _choice("echo_shield", target, "Listen to the word. Which letters spell %s?" % where, opts, _word_audio(target["word"]))


static func sound_slide(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var oral := _is_oral(stage_id)
	var pool := _targets(stage_id, ctx).filter(func(e): return not bool(e.get("letter", false)) and (_clean_sounds(e) or String(e.get("unit", "")) != "" or e.get("sounds", []).has("-")))
	if tier == 2:
		var longer := pool.filter(func(e): return e.get("sounds", []).size() >= 4 or e.get("tiles", []).size() >= 3)
		if longer.size() >= 2:
			pool = longer
	var target := _pick(pool, ctx)
	if target.is_empty():
		return {}
	var n: int = [2, 3, 4][tier]
	var others := _entries(stage_id, ctx).filter(func(e): return e["word"] != target["word"] and not bool(e.get("letter", false)))
	# Prefer distractors that share sounds with the target (harder to guess).
	others.sort_custom(func(a, b): return _shared(a, target) > _shared(b, target))
	var opts: Array = []
	if oral:
		opts.append(_oral_option(0, target["word"], true))
	else:
		opts.append(_option(target["word"], true, _word_audio(target["word"])))
	var used: Array = [target["word"]]
	for e in others:
		if opts.size() >= n:
			break
		if used.has(e["word"]):
			continue
		used.append(e["word"])
		if oral:
			opts.append(_oral_option(opts.size(), e["word"], false))
		else:
			opts.append(_option(e["word"], false, []))
	var gap: float = float(TIER[tier]["gap"])
	return _choice("sound_slide", target, "Listen to the sounds and slide them together. Which word is it?", opts,
		_sounds_audio(target, gap), oral)


static func _shared(a: Dictionary, b: Dictionary) -> int:
	var n := 0
	for s in a.get("sounds", []):
		if b.get("sounds", []).has(s):
			n += 1
	return n


static func elkonin(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _targets(stage_id, ctx).filter(func(e): return _clean_sounds(e))
	if tier == 2:
		var longer := pool.filter(func(e): return e["sounds"].size() >= 4)
		if not longer.is_empty():
			pool = longer
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var units: Array = []
	for i in e["sounds"].size():
		units.append([{"u": [String(e["sounds"][i]), String(e["tiles"][i])]}])
	return {
		"kind": "count", "mode": "elkonin", "entry": e,
		"prompt": "Say the word slowly. Push one token into a box for EACH sound, then press Done.",
		"audio": _word_audio(e["word"]), "target": e["sounds"].size(), "unit": "sound", "unit_audio": units,
		"show_count": tier == 0, "guide": tier == 0, "token": "● Token",
	}


static func word_chain(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var oral := _is_oral(stage_id)
	var pool := _entries(stage_id, ctx).filter(func(e): return _clean_sounds(e))
	var want: int = [0, 2, 1][tier]
	pool.shuffle()
	var start: Dictionary = {}
	var partner: Dictionary = {}
	var pos := -1
	for a in pool:
		for b in pool:
			if a["word"] == b["word"]:
				continue
			var d := _diff_positions(a, b)
			if d.size() == 1 and int(d[0]) >= 0:
				if start.is_empty() or int(d[0]) == want:
					start = a
					partner = b
					pos = int(d[0])
				if pos == want:
					break
		if pos == want and not start.is_empty():
			break
	if start.is_empty():
		return {}
	var from_s := String(start["sounds"][pos])
	var to_s := String(partner["sounds"][pos])
	var n: int = [2, 3, 4][tier]
	var opts: Array = []
	if oral:
		opts.append(_oral_option(0, partner["word"], true))
	else:
		opts.append(_option(partner["word"], true, _word_audio(partner["word"])))
	var used: Array = [partner["word"], start["word"]]
	for e in pool:
		if opts.size() >= n:
			break
		if used.has(e["word"]):
			continue
		used.append(e["word"])
		if oral:
			opts.append(_oral_option(opts.size(), e["word"], false))
		else:
			opts.append(_option(e["word"], false, []))
	var prompt := "Say the word. Now change %s to %s. What is the new word?" % [from_s, to_s]
	if not oral:
		prompt = "%s → change %s to %s. Which word do you get?" % [String(start["word"]).to_upper(), String(start["tiles"][pos]), String(partner["tiles"][pos])]
	var q := _choice("word_chain", partner, prompt, opts,
		[{"w": start["word"]}, {"pause": 0.5}, {"s": from_s}, {"pause": 0.3}, {"s": to_s}], oral)
	return q


static func vowel_pick(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _targets(stage_id, ctx).filter(func(e): return not bool(e.get("letter", false)) and _vowel_index(e) >= 0 and _clean_sounds(e))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var vi := _vowel_index(e)
	var v := String(e["tiles"][vi]).to_lower()
	var n: int = [2, 3, 5][tier]
	var allowed: Array = VOWELS
	if OGCurriculum.band_of(stage_id) == "B":
		allowed = _taught_letters(stage_id).filter(func(c): return VOWELS.has(c))
	var order: Array = [v]
	for c in CONFUSABLES.get(v, []):
		if allowed.has(c):
			order.append(c)
	for c in allowed:
		order.append(c)
	var opts: Array = []
	var used: Array = []
	for c in order:
		if opts.size() >= n:
			break
		if used.has(c):
			continue
		used.append(c)
		opts.append(_option(String(c), String(c) == v, [{"s": "/%s/" % c}]))
	var shown := _blank_word(e, vi) if tier < 2 else "_ _ _"
	return _choice("vowel_pick", e, "Listen. Which vowel is missing?   %s" % shown, opts, _word_audio(e["word"]))


static func twin_caves(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return e.has("sort"))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var group := String(e.get("group", ""))
	var cats: Array = []
	for x in pool:
		if String(x.get("group", "")) != group:
			continue
		var s := String(x["sort"])
		if not cats.has(s):
			cats.append(s)
	var answer := String(e["sort"])
	var n := 2 if tier == 0 else (3 if tier == 1 else cats.size())
	var chosen: Array = [answer]
	cats.shuffle()
	for c in cats:
		if chosen.size() >= n:
			break
		if not chosen.has(c):
			chosen.append(c)
	chosen.sort()
	var anchors := {"b": "b · bat", "d": "d · dog", "p": "p · pig", "u": "u · up", "e": "e · Ed", "i": "i · itch"}
	var opts: Array = []
	for c in chosen:
		var label := String(c)
		if tier == 0 and anchors.has(label):
			label = String(anchors[label])
		opts.append(_option(label + " cave", String(c) == answer, []))
	var b := OGCurriculum.band_of(stage_id)
	var prompt := "Which cave does this word belong in?   %s" % String(e["word"]).to_upper()
	var audio: Array = _word_audio(e["word"])
	if stage_id == "B4":
		prompt = "Listen. Which vowel sound is in the word?" + ("   %s" % String(e["word"]).to_upper() if tier == 0 else "")
	elif stage_id == "C8" or stage_id == "F1":
		prompt = "Listen to the ending. What sound does it make?   %s" % String(e["word"]).to_upper()
	elif String(e.get("group", "")) == "c":
		prompt = "Is the c HARD /k/ or SOFT /s/?   %s" % String(e["word"]).to_upper()
	elif String(e.get("group", "")) == "g":
		prompt = "Is the g HARD /g/ or SOFT /j/?   %s" % String(e["word"]).to_upper()
	elif String(e.get("group", "")) == "y":
		prompt = "What does the y say at the end?   %s" % String(e["word"]).to_upper()
	elif stage_id == "B6":
		prompt = "Which letter does this word START with?   %s" % String(e["word"])
		audio = [] if tier > 0 else audio
	var q := _choice("twin_caves", e, prompt, opts, audio)
	q["options"] = opts
	return q


static func word_build(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _targets(stage_id, ctx).filter(func(e): return not bool(e.get("letter", false)))
	if pool.is_empty():
		return {}
	var e := _pick(pool, ctx)
	# Hard Heavy Hits alternate between free-typed dictation and a tile build
	# crowded with confusable distractors.
	if tier == 2 and String(ctx.get("attack", "")) == "heavy" and randf() < 0.5:
		return dictation_for(e, tier)
	var tiles: Array = e["tiles"]
	var cfg: Dictionary = TIER[tier]
	var pool_tiles := _tile_pool(e, stage_id, int(cfg["distractors"]) if tier > 0 else (0 if tiles.size() <= 3 else 1), ctx)
	var syllabic := String(e.get("unit", "")) != ""
	var prompt := "Build the word: tap each sound in order."
	if syllabic:
		prompt = "Build the word: tap each part in order."
	return {
		"kind": "build", "mode": "word_build", "entry": e, "prompt": prompt,
		"tiles": tiles, "sounds": e["sounds"], "pool": pool_tiles,
		"chips": bool(cfg["chips"]) and not syllabic, "tile_audio": bool(cfg["tile_audio"]),
		"audio": _sounds_audio(e, 0.12) + [{"pause": 0.2}, {"w": e["word"]}] if tier == 0 else _word_audio(e["word"]),
		"meaning": "",
	}


static func _tile_pool(e: Dictionary, stage_id: String, distractors: int, ctx: Dictionary) -> Array:
	var correct: Array = []
	for t in e["tiles"]:
		correct.append(String(t))
	var picks: Array = []
	var conf: Array = []
	var taught: Array = _taught_letters(stage_id) if OGCurriculum.band_of(stage_id) == "B" else []
	for t in correct:
		for c in CONFUSABLES.get(t.to_lower(), []):
			if not taught.is_empty() and not taught.has(c):
				continue
			if not correct.has(c) and not conf.has(c):
				conf.append(c)
	conf.shuffle()
	for c in conf:
		if picks.size() >= distractors:
			break
		picks.append(c)
	if picks.size() < distractors:
		var filler: Array = []
		for x in _entries(stage_id, ctx):
			for t in x.get("tiles", []):
				var s := String(t)
				if not correct.has(s) and not picks.has(s) and not filler.has(s):
					filler.append(s)
		filler.shuffle()
		for s in filler:
			if picks.size() >= distractors:
				break
			picks.append(s)
	var out := correct.duplicate()
	out.append_array(picks)
	out.shuffle()
	return out


static func sound_pick(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _targets(stage_id, ctx).filter(func(e): return _clean_sounds(e) and not bool(e.get("letter", false)))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var n: int = [2, 3, 5][tier]
	var items: Array = []
	for i in e["sounds"].size():
		items.append({"sound": String(e["sounds"][i]), "grapheme": String(e["tiles"][i])})
	var bank := _phoneme_bank()
	var extras: Array = []
	for k in bank.keys():
		if not e["sounds"].has(k):
			extras.append({"sound": String(k), "grapheme": String(bank[k])})
	extras.shuffle()
	# Confusable sounds first so the distractors are the classic OG pairs.
	var first: Array = []
	for t in e["tiles"]:
		for c in CONFUSABLES.get(String(t), []):
			for x in extras:
				if String(x["grapheme"]) == String(c) and not first.has(x):
					first.append(x)
	for x in first + extras:
		if items.size() >= e["sounds"].size() + n:
			break
		var dup := false
		for y in items:
			if y["sound"] == x["sound"]:
				dup = true
		if not dup:
			items.append(x)
	items.shuffle()
	return {
		"kind": "phoneme", "mode": "sound_pick", "entry": e,
		"prompt": "Listen, then tap the SOUNDS you hear, in order.",
		"sounds": e["sounds"], "tiles": e["tiles"], "items": items, "audio": _word_audio(e["word"]),
		"tile_audio": true,
	}


static func _phoneme_bank() -> Dictionary:
	var bank := {}
	for e in OGCurriculum.all_words():
		if not _clean_sounds(e):
			continue
		for i in e["sounds"].size():
			var s := String(e["sounds"][i])
			if not bank.has(s):
				bank[s] = String(e["tiles"][i])
	return bank


static func which_spelling(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx)
	if tier < 2:
		pool = pool.filter(func(e): return not bool(e.get("exception", false)))
	var allowed: Array = STAGE_FAMILIES.get(stage_id, [])
	var found := {}
	pool.shuffle()
	for e in pool:
		var exclude: Array = ctx.get("exclude", [])
		var spot := _spelling_spot(e, allowed)
		if spot.is_empty():
			continue
		found = spot
		if not exclude.has(String(e["word"])):
			break
	if found.is_empty():
		return {}
	var e: Dictionary = found["entry"]
	var idx := int(found["index"])
	var answer := String(e["tiles"][idx])
	var opts: Array = []
	for o in found["options"]:
		opts.append(_option(String(o), String(o) == answer, []))
	var shown := _blank_word(e, idx)
	var q := _choice("which_spelling", e, "Which spelling fills the gap?   %s" % shown, opts, _word_audio(e["word"]))
	q["options"] = opts
	if tier == 0:
		q["rule"] = String(found["rule"])
	else:
		q["rule"] = ""
	q["after"] = String(found["rule"])
	if bool(e.get("exception", false)):
		q["after"] = "Rule breaker! %s keeps just one letter." % String(e["word"])
	return q


static func _spelling_spot(e: Dictionary, allowed: Array = []) -> Dictionary:
	var spot := _spelling_spot_any(e)
	if spot.is_empty() or allowed.is_empty():
		return spot
	return spot if allowed.has(String(spot.get("family", ""))) else {}


static func _spelling_spot_any(e: Dictionary) -> Dictionary:
	var tiles: Array = e.get("tiles", [])
	if tiles.is_empty():
		return {}
	var last := String(tiles[tiles.size() - 1])
	var fam := String(e.get("family", ""))
	if fam != "" and Data.FAMILIES.has(fam):
		var options: Array = Data.FAMILIES[fam]["options"]
		for i in tiles.size():
			if options.has(String(tiles[i])):
				return {"entry": e, "index": i, "options": options, "rule": Data.FAMILIES[fam]["rule"], "family": fam}
		# tch / dge families: lunch, hinge use the other spelling.
	if fam == "tch" or fam == "dge":
		pass
	if last in ["c", "k", "ck"] and tiles.size() >= 2:
		return {"entry": e, "index": tiles.size() - 1, "options": ["c", "k", "ck"], "rule": Data.FAMILIES["k_final"]["rule"], "family": "k_final"}
	if Data.FLOSS_PAIRS.has(last) and tiles.size() >= 2 and String(tiles[tiles.size() - 2]) in VOWELS:
		var pair := [last, String(Data.FLOSS_PAIRS[last])]
		pair.sort()
		return {"entry": e, "index": tiles.size() - 1, "options": pair, "rule": Data.FAMILIES["floss"]["rule"], "family": "floss"}
	if last == "s" or last == "es":
		if String(e.get("unit", "")) == "morpheme":
			return {"entry": e, "index": tiles.size() - 1, "options": ["s", "es"], "rule": Data.FAMILIES["s_es"]["rule"], "family": "s_es"}
	if last == "ch" or last == "tch":
		return {"entry": e, "index": tiles.size() - 1, "options": ["ch", "tch"], "rule": Data.FAMILIES["tch"]["rule"], "family": "tch"}
	if last == "ge" or last == "dge":
		return {"entry": e, "index": tiles.size() - 1, "options": ["dge", "ge"], "rule": Data.FAMILIES["dge"]["rule"], "family": "dge"}
	return {}


static func morpheme_smith(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return e.get("tiles", []).size() >= 2)
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	if tier == 2 and String(ctx.get("attack", "")) == "heavy" and randf() < 0.5:
		return dictation_for(e, tier)
	var distract: int = [1, 2, 4][tier]
	var tiles := _tile_pool(e, stage_id, distract, ctx)
	var meaning := String(e.get("meaning", e.get("hint", "")))
	var prompt := "Forge the word from its parts: %s" % String(e["word"]).to_upper()
	if tier >= 1 and meaning != "":
		prompt = "Forge the word that means: \"%s\"" % meaning
		if String(e.get("root", "")) != "":
			prompt = "Forge the word you hear (root %s = %s)." % [String(e["root"]), meaning]
	return {
		"kind": "build", "mode": "morpheme_smith", "entry": e, "prompt": prompt,
		"tiles": e["tiles"], "sounds": e["sounds"], "pool": tiles, "chips": false,
		"tile_audio": tier < 2, "audio": _word_audio(e["word"]),
		"meaning": ("Meaning: " + meaning) if tier == 0 and meaning != "" else "",
	}


static func magic_e(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return String(e["word"]).ends_with("e"))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	if tier == 2:
		return dictation_for(e, tier)
	var word := String(e["word"])
	var closed := String(e.get("closed", word.substr(0, word.length() - 1)))
	var opts: Array = [_option(word, true, _word_audio(word)), _option(closed, false, [])]
	if tier == 1:
		var vi := _vowel_index(e)
		for v in VOWELS:
			if v != String(e["tiles"][vi]):
				var t: Array = e["tiles"].duplicate()
				t[vi] = v
				opts.append(_option("".join(t), false, []))
				break
	var q := _choice("magic_e", e, "Wave the magic e! Which word do you hear?   %s + e" % closed.to_upper(), opts, _word_audio(word))
	return q


static func syllable_sort(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var items: Array = []
	for e in _entries(stage_id, ctx):
		if e.has("syl_type"):
			var text := String(e["word"])
			if stage_id == "E4":
				text = String(e["tiles"][e["tiles"].size() - 1])
			items.append({"text": text, "type": String(e["syl_type"]), "entry": e})
	if stage_id == "E4" or tier == 2:
		for x in Data.SYLLABLE_SORT_EXTRA:
			items.append({"text": String(x[0]), "type": String(x[1]), "entry": {}})
	if stage_id == "D2" and tier == 2:
		items = []
		for x in Data.SYLLABLE_NONSENSE:
			items.append({"text": String(x[0]), "type": String(x[1]), "entry": {}})
	if items.is_empty():
		return {}
	var item: Dictionary = items[randi() % items.size()]
	var houses: Array = []
	for x in items:
		if not houses.has(x["type"]):
			houses.append(x["type"])
	var n := 2 if tier == 0 else (3 if tier == 1 else houses.size())
	var chosen: Array = [item["type"]]
	houses.shuffle()
	for h in houses:
		if chosen.size() >= n:
			break
		if not chosen.has(h):
			chosen.append(h)
	var order := ["closed", "open", "magic e", "vowel team", "r-controlled", "consonant-le"]
	chosen.sort_custom(func(a, b): return order.find(a) < order.find(b))
	var opts: Array = []
	for h in chosen:
		opts.append(_option(String(h) + " house", String(h) == String(item["type"]), []))
	var entry: Dictionary = item["entry"]
	var audio: Array = _word_audio(String(entry["word"])) if not entry.is_empty() and tier == 0 else []
	var q := _choice("syllable_sort", entry, "Which syllable house does this belong in?   %s" % String(item["text"]).to_upper(), opts, audio)
	q["options"] = opts
	q["word"] = String(item["text"])
	return q


static func syllable_splitter(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var word := ""
	var parts: Array = []
	var entry: Dictionary = {}
	if tier == 2 and randf() < 0.4 and not Data.SPLIT_NONSENSE.is_empty():
		var n: Array = Data.SPLIT_NONSENSE[randi() % Data.SPLIT_NONSENSE.size()]
		word = String(n[0])
		parts = String(n[1]).split(" ")
	else:
		var pool := _entries(stage_id, ctx).filter(func(e): return e.get("tiles", []).size() >= 2)
		entry = _pick(pool, ctx)
		if entry.is_empty():
			return {}
		word = String(entry["word"])
		parts = entry["tiles"]
	var cuts: Array = []
	var at := 0
	for i in range(parts.size() - 1):
		at += String(parts[i]).length()
		cuts.append(at)
	return {
		"kind": "split", "mode": "syllable_splitter", "entry": entry, "word": word,
		"prompt": "Slash the word into syllables: tap between letters, then press Done." + ("  (%d parts)" % parts.size() if tier == 0 else ""),
		"letters": word, "cuts": cuts, "mark_vowels": tier == 0,
		"audio": _word_audio(word) if not entry.is_empty() and tier < 2 else [],
	}


static func real_or_nonsense(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var nonsense: Array = Data.NONSENSE.get(stage_id, Data.NONSENSE.get("R1", []))
	var real_pool := _entries(stage_id, ctx).filter(func(e): return not bool(e.get("letter", false)))
	var is_real := randf() < 0.5
	var text := ""
	var entry: Dictionary = {}
	if is_real or nonsense.is_empty():
		entry = _pick(real_pool, ctx)
		if entry.is_empty():
			return {}
		text = String(entry["word"])
		is_real = true
	else:
		text = String(nonsense[randi() % nonsense.size()])
	var opts := [_option("Real word", is_real, []), _option("Nonsense", not is_real, [])]
	var q := _choice("real_or_nonsense", entry, "Read it. Is it a REAL word or NONSENSE?   %s" % text, opts, [])
	q["options"] = opts
	q["word"] = text
	return q


static func rule_gate(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return e.has("rule"))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var opts: Array = [_option(String(e["word"]), true, _word_audio(e["word"]))]
	var wrong: Array = e["wrong"].duplicate()
	var n: int = [2, 3, 3][tier]
	for w in wrong:
		if opts.size() >= n:
			break
		opts.append(_option(String(w), false, []))
	var rules := {"double": "1-1-1 rule: one syllable, one vowel, one final consonant -> double it.", "drop e": "Silent e: drop the e before a vowel suffix.", "y to i": "Consonant + y: change y to i (but keep y before -ing).", "just add": "No rule needed: just add the suffix."}
	var q := _choice("rule_gate", e, "The gate opens for the right spelling:   %s + %s" % [String(e["base"]), String(e["suffix"])], opts, [] if tier > 0 else _word_audio(e["word"]))
	q["rule"] = String(rules.get(String(e["rule"]), "")) if tier == 0 else ""
	q["after"] = String(rules.get(String(e["rule"]), ""))
	return q


static func meaning_pick(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return e.has("meaning"))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var answer := String(e["meaning"])
	var others: Array = []
	for x in pool:
		var m := String(x["meaning"])
		if m != answer and not others.has(m):
			others.append(m)
	others.shuffle()
	var opts: Array = [_option(answer, true, [])]
	for m in others:
		if opts.size() >= [2, 3, 4][tier]:
			break
		opts.append(_option(String(m), false, []))
	return _choice("meaning_pick", e, "What does it mean?   %s" % String(e["word"]).to_upper(), opts, _word_audio(e["word"]))


static func root_tree(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return e.has("root"))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var roots := {}
	for x in pool:
		roots[String(x["root"])] = String(x["meaning"])
	var answer := String(e["root"])
	var keys: Array = roots.keys()
	keys.erase(answer)
	keys.shuffle()
	var n: int = [2, 3, 4][tier]
	var opts: Array = []
	if tier < 2:
		opts.append(_option(answer + (" = " + String(roots[answer]) if tier == 0 else ""), true, []))
		for k in keys:
			if opts.size() >= n:
				break
			opts.append(_option(String(k) + (" = " + String(roots[k]) if tier == 0 else ""), false, []))
		return _choice("root_tree", e, "Hang the word on its root branch:   %s" % String(e["word"]).to_upper(), opts, _word_audio(e["word"]))
	var meanings: Array = []
	for k in roots.keys():
		var m := String(roots[k])
		if m != String(roots[answer]) and not meanings.has(m):
			meanings.append(m)
	meanings.shuffle()
	opts.append(_option(String(roots[answer]), true, []))
	for m in meanings:
		if opts.size() >= n:
			break
		opts.append(_option(String(m), false, []))
	return _choice("root_tree", e, "%s - which meaning does its root carry?" % String(e["word"]).to_upper(), opts, _word_audio(e["word"]))


static func heart_word(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _entries(stage_id, ctx).filter(func(e): return (e.has("heart") or e.has("silent")) and e.get("tiles", []).size() >= 2)
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	if tier == 2 and String(ctx.get("attack", "")) == "heavy":
		return dictation_for(e, tier)
	var hearts: Array = e.get("heart", [e.get("silent", 0)])
	var opts: Array = []
	for i in e["tiles"].size():
		opts.append({"text": String(e["tiles"][i]), "correct": hearts.has(i), "audio": []})
	var prompt := "Tap the TRICKY part - the heart part you learn by heart:   %s" % String(e["word"])
	if e.has("silent"):
		prompt = "Tap the SILENT letters:   %s" % String(e["word"])
	var q := {
		"kind": "choice", "mode": "heart_word", "entry": e, "prompt": prompt, "options": opts,
		"audio": _word_audio(e["word"]), "oral": false, "confirm": false, "answer_text": ", ".join(hearts.map(func(i): return String(e["tiles"][i]))),
		"inline": true,
	}
	return q


static func stress_pick(stage_id: String, tier: int, ctx: Dictionary, schwa: bool) -> Dictionary:
	var key := "schwa" if schwa else "stress"
	var pool := _entries(stage_id, ctx).filter(func(e): return e.has(key))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	var answer := int(e[key])
	var opts: Array = []
	for i in e["tiles"].size():
		opts.append(_option(String(e["tiles"][i]), i == answer, [{"k": String(e["tiles"][i])}] if tier == 0 else []))
	var prompt := "Listen. Which part is LOUD (stressed)?   %s" % String(e["word"])
	if schwa:
		prompt = "Which part has the lazy /uh/ vowel (schwa)?   %s" % String(e["word"])
	var q := _choice("schwa_pick" if schwa else "stress_pick", e, prompt, opts, _word_audio(e["word"]))
	q["options"] = opts
	q["inline"] = true
	return q


static func sentence_scroll(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var band := String(ctx.get("band", "C"))
	var pool := OGCurriculum.sentences_up_to(band)
	if pool.is_empty():
		pool = OGCurriculum.sentences_up_to("C")
	if pool.is_empty():
		return {}
	var s: Dictionary = pool[randi() % pool.size()]
	var opts: Array = [_option(String(s["answer"]), true, _word_audio(String(s["answer"])))]
	for w in s["wrong"]:
		if opts.size() >= [2, 3, 3][tier]:
			break
		opts.append(_option(String(w), false, []))
	var q := _choice("sentence_scroll", {}, "Read the scroll. Which word fits?\n%s" % String(s["text"]), opts, [])
	q["word"] = String(s["answer"])
	return q


static func dictation(stage_id: String, tier: int, ctx: Dictionary) -> Dictionary:
	var pool := _targets(stage_id, ctx).filter(func(e): return not bool(e.get("letter", false)))
	var e := _pick(pool, ctx)
	if e.is_empty():
		return {}
	return dictation_for(e, tier)


static func dictation_for(e: Dictionary, tier: int) -> Dictionary:
	return {
		"kind": "type", "mode": "dictation", "entry": e,
		"prompt": "Dictation: listen, then TYPE the word and press Enter.",
		"answer": String(e["word"]).to_lower(), "audio": _word_audio(e["word"]),
	}
