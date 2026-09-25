extends RefCounted

## Orton-Gillingham word data for the "Word Build" encoding mini-game.
##
## Every word is fully decodable and belongs to ONE step of the OG scope and
## sequence, so practice stays explicit, systematic and cumulative:
##
##   level 1 - CVC closed syllables, short vowels (cat, dog, sun)
##   level 2 - digraphs sh, ch, th, ck (fish, moth, duck)
##   level 3 - blends st, fl, cr, dr, fr, gr, tr, sw (stop, flag, drum)
##
## Each entry carries:
##   "word"    - the target word the player must build
##   "sounds"  - the phoneme list in order; a digraph is ONE sound, ONE chip
##   "tiles"   - the grapheme tapped for each sound, in the same order.
##               "sounds" and "tiles" are always the same length, so the chip
##               row, the slot row and the answer can never drift apart.
##   "hint"    - a meaning hint, because this milestone has no audio at all
##   "pattern" - the phonics pattern to name after building the word
##   "level"   - 1, 2 or 3
##
## Data only: the mini-game reads it, nothing else writes it.

const WORDS: Array = [
	# ---------------------------------------------------------------- level 1
	{"word": "cat", "level": 1, "pattern": "CVC", "sounds": ["/k/", "/a/", "/t/"], "tiles": ["c", "a", "t"], "hint": "A soft pet that says meow."},
	{"word": "dog", "level": 1, "pattern": "CVC", "sounds": ["/d/", "/o/", "/g/"], "tiles": ["d", "o", "g"], "hint": "A pet that barks and wags its tail."},
	{"word": "pig", "level": 1, "pattern": "CVC", "sounds": ["/p/", "/i/", "/g/"], "tiles": ["p", "i", "g"], "hint": "A pink farm animal that rolls in mud."},
	{"word": "sun", "level": 1, "pattern": "CVC", "sounds": ["/s/", "/u/", "/n/"], "tiles": ["s", "u", "n"], "hint": "It shines in the sky and keeps you warm."},
	{"word": "map", "level": 1, "pattern": "CVC", "sounds": ["/m/", "/a/", "/p/"], "tiles": ["m", "a", "p"], "hint": "It shows you where places are."},
	{"word": "bed", "level": 1, "pattern": "CVC", "sounds": ["/b/", "/e/", "/d/"], "tiles": ["b", "e", "d"], "hint": "You sleep in it at night."},
	{"word": "jam", "level": 1, "pattern": "CVC", "sounds": ["/j/", "/a/", "/m/"], "tiles": ["j", "a", "m"], "hint": "Sweet fruit spread on your toast."},
	{"word": "log", "level": 1, "pattern": "CVC", "sounds": ["/l/", "/o/", "/g/"], "tiles": ["l", "o", "g"], "hint": "A thick piece of a fallen tree."},
	{"word": "hen", "level": 1, "pattern": "CVC", "sounds": ["/h/", "/e/", "/n/"], "tiles": ["h", "e", "n"], "hint": "A mother chicken that lays eggs."},
	{"word": "bat", "level": 1, "pattern": "CVC", "sounds": ["/b/", "/a/", "/t/"], "tiles": ["b", "a", "t"], "hint": "It flies at night and sleeps upside down."},
	{"word": "web", "level": 1, "pattern": "CVC", "sounds": ["/w/", "/e/", "/b/"], "tiles": ["w", "e", "b"], "hint": "A spider spins this to catch flies."},
	{"word": "top", "level": 1, "pattern": "CVC", "sounds": ["/t/", "/o/", "/p/"], "tiles": ["t", "o", "p"], "hint": "A toy that spins round and round."},
	{"word": "box", "level": 1, "pattern": "CVC", "sounds": ["/b/", "/o/", "/ks/"], "tiles": ["b", "o", "x"], "hint": "You put things inside it."},
	{"word": "rip", "level": 1, "pattern": "CVC", "sounds": ["/r/", "/i/", "/p/"], "tiles": ["r", "i", "p"], "hint": "To tear paper in two."},
	# ---------------------------------------------------------------- level 2
	{"word": "fish", "level": 2, "pattern": "CVCC - sh digraph", "sounds": ["/f/", "/i/", "/sh/"], "tiles": ["f", "i", "sh"], "hint": "It swims in water and has fins."},
	{"word": "ship", "level": 2, "pattern": "CCVC - sh digraph", "sounds": ["/sh/", "/i/", "/p/"], "tiles": ["sh", "i", "p"], "hint": "It carries people across the sea."},
	{"word": "chat", "level": 2, "pattern": "CCVC - ch digraph", "sounds": ["/ch/", "/a/", "/t/"], "tiles": ["ch", "a", "t"], "hint": "To talk in a friendly way."},
	{"word": "chip", "level": 2, "pattern": "CCVC - ch digraph", "sounds": ["/ch/", "/i/", "/p/"], "tiles": ["ch", "i", "p"], "hint": "A thin slice of potato you crunch."},
	{"word": "moth", "level": 2, "pattern": "CVCC - th digraph", "sounds": ["/m/", "/o/", "/th/"], "tiles": ["m", "o", "th"], "hint": "A soft flying insect that likes lamps."},
	{"word": "thin", "level": 2, "pattern": "CCVC - th digraph", "sounds": ["/th/", "/i/", "/n/"], "tiles": ["th", "i", "n"], "hint": "Not thick at all."},
	{"word": "duck", "level": 2, "pattern": "CVCC - ck digraph", "sounds": ["/d/", "/u/", "/k/"], "tiles": ["d", "u", "ck"], "hint": "A bird that quacks on the pond."},
	{"word": "sock", "level": 2, "pattern": "CVCC - ck digraph", "sounds": ["/s/", "/o/", "/k/"], "tiles": ["s", "o", "ck"], "hint": "You wear it on your foot."},
	{"word": "lock", "level": 2, "pattern": "CVCC - ck digraph", "sounds": ["/l/", "/o/", "/k/"], "tiles": ["l", "o", "ck"], "hint": "A key opens it."},
	{"word": "shop", "level": 2, "pattern": "CCVC - sh digraph", "sounds": ["/sh/", "/o/", "/p/"], "tiles": ["sh", "o", "p"], "hint": "A place where you buy things."},
	{"word": "then", "level": 2, "pattern": "CCVC - th digraph", "sounds": ["/th/", "/e/", "/n/"], "tiles": ["th", "e", "n"], "hint": "It means after that."},
	{"word": "wish", "level": 2, "pattern": "CVCC - sh digraph", "sounds": ["/w/", "/i/", "/sh/"], "tiles": ["w", "i", "sh"], "hint": "You make one when you blow out candles."},
	{"word": "chin", "level": 2, "pattern": "CCVC - ch digraph", "sounds": ["/ch/", "/i/", "/n/"], "tiles": ["ch", "i", "n"], "hint": "The part of your face under your mouth."},
	{"word": "rich", "level": 2, "pattern": "CVCC - ch digraph", "sounds": ["/r/", "/i/", "/ch/"], "tiles": ["r", "i", "ch"], "hint": "Having lots of gold."},
	# ---------------------------------------------------------------- level 3
	{"word": "stop", "level": 3, "pattern": "CCVC - st blend", "sounds": ["/s/", "/t/", "/o/", "/p/"], "tiles": ["s", "t", "o", "p"], "hint": "You do this to make your cart halt."},
	{"word": "flag", "level": 3, "pattern": "CCVC - fl blend", "sounds": ["/f/", "/l/", "/a/", "/g/"], "tiles": ["f", "l", "a", "g"], "hint": "It waves on a pole."},
	{"word": "crab", "level": 3, "pattern": "CCVC - cr blend", "sounds": ["/k/", "/r/", "/a/", "/b/"], "tiles": ["c", "r", "a", "b"], "hint": "It walks sideways on the sand."},
	{"word": "drum", "level": 3, "pattern": "CCVC - dr blend", "sounds": ["/d/", "/r/", "/u/", "/m/"], "tiles": ["d", "r", "u", "m"], "hint": "You bang it with two sticks."},
	{"word": "frog", "level": 3, "pattern": "CCVC - fr blend", "sounds": ["/f/", "/r/", "/o/", "/g/"], "tiles": ["f", "r", "o", "g"], "hint": "It hops and croaks by the pond."},
	{"word": "grin", "level": 3, "pattern": "CCVC - gr blend", "sounds": ["/g/", "/r/", "/i/", "/n/"], "tiles": ["g", "r", "i", "n"], "hint": "A big happy smile."},
	{"word": "trap", "level": 3, "pattern": "CCVC - tr blend", "sounds": ["/t/", "/r/", "/a/", "/p/"], "tiles": ["t", "r", "a", "p"], "hint": "A net that catches things."},
	{"word": "swim", "level": 3, "pattern": "CCVC - sw blend", "sounds": ["/s/", "/w/", "/i/", "/m/"], "tiles": ["s", "w", "i", "m"], "hint": "To move through water."},
	{"word": "slip", "level": 3, "pattern": "CCVC - sl blend", "sounds": ["/s/", "/l/", "/i/", "/p/"], "tiles": ["s", "l", "i", "p"], "hint": "To slide and fall down."},
	{"word": "plan", "level": 3, "pattern": "CCVC - pl blend", "sounds": ["/p/", "/l/", "/a/", "/n/"], "tiles": ["p", "l", "a", "n"], "hint": "An idea you make before you start."},
	{"word": "spin", "level": 3, "pattern": "CCVC - sp blend", "sounds": ["/s/", "/p/", "/i/", "/n/"], "tiles": ["s", "p", "i", "n"], "hint": "To turn round and round fast."},
	{"word": "trip", "level": 3, "pattern": "CCVC - tr blend", "sounds": ["/t/", "/r/", "/i/", "/p/"], "tiles": ["t", "r", "i", "p"], "hint": "A journey to a place."},
	{"word": "clap", "level": 3, "pattern": "CCVC - cl blend", "sounds": ["/k/", "/l/", "/a/", "/p/"], "tiles": ["c", "l", "a", "p"], "hint": "You do this with your hands to cheer."},
	{"word": "snap", "level": 3, "pattern": "CCVC - sn blend", "sounds": ["/s/", "/n/", "/a/", "/p/"], "tiles": ["s", "n", "a", "p"], "hint": "The quick sound a dry twig makes."},
]

## Every grapheme a player may meet at each level, used only to build
## plausible distractor tiles. A distractor is never a correct tile.
const LEVEL_POOLS: Dictionary = {
	1: ["a", "e", "i", "o", "u", "b", "d", "p", "c", "k", "g", "t", "m", "n", "s", "f", "h", "j", "l", "r", "w"],
	2: ["sh", "ch", "th", "ck", "a", "e", "i", "o", "u", "b", "d", "p", "c", "t", "m", "n", "s", "f", "h", "l", "r", "w"],
	3: ["st", "fl", "cr", "dr", "fr", "gr", "tr", "sw", "sl", "pl", "sp", "sn", "cl", "a", "e", "i", "o", "u", "b", "d", "p", "c", "k", "g", "t", "m", "n", "s", "f", "h", "l", "r", "w"],
}

## Deliberately confusable neighbours: the classic OG confusions (sh/ch/th,
## c/k/ck, b/d/p) and the blends that share a leading sound.
const CONFUSABLES: Dictionary = {
	"sh": ["ch", "th", "s", "h"], "ch": ["sh", "th", "c", "h"], "th": ["sh", "ch", "t", "h"],
	"ck": ["c", "k", "g"], "c": ["k", "ck", "g"], "k": ["c", "ck", "g"],
	"b": ["d", "p", "t"], "d": ["b", "p", "t"], "p": ["b", "d", "t"], "t": ["d", "p", "b"],
	"m": ["n", "w"], "n": ["m", "r"], "f": ["v", "t", "h"], "g": ["j", "k", "c"],
	"l": ["i", "t", "r"], "r": ["n", "l", "w"], "s": ["z", "sh", "f"], "w": ["m", "v", "u"],
	"j": ["g", "ch", "d"], "h": ["n", "b", "th"],
	"a": ["e", "o", "u"], "e": ["a", "i", "u"], "i": ["e", "o"], "o": ["a", "u", "e"], "u": ["o", "a", "e"],
	"st": ["sl", "sp", "sn", "tr"], "fl": ["fr", "sl", "cl"], "cr": ["cl", "gr", "tr"],
	"dr": ["br", "tr", "gr"], "fr": ["fl", "tr", "br"], "gr": ["cr", "dr", "br"],
	"tr": ["cr", "dr", "ch"], "sw": ["sl", "sp", "st"], "sl": ["st", "sw", "fl"],
	"pl": ["cl", "bl", "fl"], "sp": ["st", "sw", "sn"], "sn": ["st", "sp", "sl"], "cl": ["cr", "pl", "fl"],
}


## Every word that belongs to one OG level.
static func words_for_level(level: int) -> Array:
	var found: Array = []
	for entry in WORDS:
		if int(entry["level"]) == level:
			found.append(entry)
	return found


## The scope-and-sequence name of a level, shown on the mini-game card.
static func level_focus(level: int) -> String:
	match level:
		1:
			return "CVC closed syllables, short vowels"
		2:
			return "digraphs sh, ch, th, ck"
		3:
			return "blends st, fl, cr, dr, fr, gr, tr, sw"
		_:
			return "review words"


## A word for the level that is not one of the last few words played.
static func pick_word(level: int, exclude: Array = []) -> Dictionary:
	var all: Array = words_for_level(level)
	if all.is_empty():
		all = WORDS.duplicate()
	var pool: Array = []
	for entry in all:
		if not exclude.has(String(entry["word"])):
			pool.append(entry)
	if pool.is_empty():
		pool = all
	return pool[randi() % pool.size()]


## The graphemes the player may tap: the correct tiles plus deliberately
## confusable distractors drawn from the same level's grapheme pool.
static func tile_pool(entry: Dictionary, distractor_count: int = 4) -> Array:
	var correct: Array = []
	for tile in entry.get("tiles", []):
		correct.append(String(tile))

	var picks: Array = []
	var confusable: Array = []
	for tile in correct:
		for neighbour in CONFUSABLES.get(tile, []):
			var candidate := String(neighbour)
			if not correct.has(candidate) and not confusable.has(candidate):
				confusable.append(candidate)
	confusable.shuffle()
	for candidate in confusable:
		if picks.size() >= distractor_count:
			break
		picks.append(candidate)

	var pool: Array = LEVEL_POOLS.get(int(entry.get("level", 1)), [])
	var filler: Array = []
	for grapheme in pool:
		var text := String(grapheme)
		if not correct.has(text) and not picks.has(text):
			filler.append(text)
	filler.shuffle()
	for text in filler:
		if picks.size() >= distractor_count:
			break
		picks.append(text)

	var tiles: Array = correct.duplicate()
	tiles.append_array(picks)
	tiles.shuffle()
	return tiles


## The correct answer for an entry, built from its tiles.
static func answer(entry: Dictionary) -> String:
	var joined := ""
	for tile in entry.get("tiles", []):
		joined += String(tile)
	return joined
