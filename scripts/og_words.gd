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
	{"word": "glad", "level": 3, "pattern": "CCVC - gl blend", "sounds": ["/g/", "/l/", "/a/", "/d/"], "tiles": ["g", "l", "a", "d"], "hint": "A happy feeling."},
	{"word": "plum", "level": 3, "pattern": "CCVC - pl blend", "sounds": ["/p/", "/l/", "/u/", "/m/"], "tiles": ["p", "l", "u", "m"], "hint": "A type of fruit."},
	{"word": "from", "level": 3, "pattern": "CCVC - fr blend", "sounds": ["/f/", "/r/", "/o/", "/m/"], "tiles": ["f", "r", "o", "m"], "hint": "Origin or source."},
	{"word": "brim", "level": 3, "pattern": "CCVC - br blend", "sounds": ["/b/", "/r/", "/i/", "/m/"], "tiles": ["b", "r", "i", "m"], "hint": "Edge of a container."},
	{"word": "crown", "level": 3, "pattern": "CCVC - cr blend", "sounds": ["/k/", "/r/", "/o/", "/w/"], "tiles": ["c", "r", "o", "w"], "hint": "Head adornment."},
	{"word": "drift", "level": 3, "pattern": "CCVC - dr blend", "sounds": ["/d/", "/r/", "/i/", "/f/"], "tiles": ["d", "r", "i", "f"], "hint": "Being carried by wind."},
	{"word": "sweep", "level": 3, "pattern": "CCVC - sw blend", "sounds": ["/s/", "/w/", "/e/", "/p/"], "tiles": ["s", "w", "e", "p"], "hint": "To clean with a broom."},
	{"word": "slash", "level": 3, "pattern": "CCVC - sl blend", "sounds": ["/s/", "/l/", "/a/", "/sh/"], "tiles": ["s", "l", "a", "sh"], "hint": "To cut with a sliding motion."},
	{"word": "twin", "level": 3, "pattern": "CCVC - tw blend", "sounds": ["/t/", "/w/", "/i/", "/n/"], "tiles": ["t", "w", "i", "n"], "hint": "Two of a kind."},
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
	for entry in ZONE1_WORDS:
		if int(entry.get("level", 1)) == level:
			found.append(entry)
	for entry in ZONE3_WORDS:
		if int(entry.get("level", 13)) == level:
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


static func answer(entry: Dictionary) -> String:
	var joined := ""
	for tile in entry.get("tiles", []):
		joined += String(tile)
	return joined


const ZONE1_WORDS: Array = [
	{"word": "a", "level": 1, "zone": 1, "pattern": "short vowel", "sounds": ["/a/"], "tiles": ["a"], "hint": "Short a, as in apple."},
	{"word": "i", "level": 1, "zone": 1, "pattern": "short vowel", "sounds": ["/i/"], "tiles": ["i"], "hint": "Short i, as in igloo."},
	{"word": "m", "level": 1, "zone": 1, "pattern": "continuous consonant", "sounds": ["/m/"], "tiles": ["m"], "hint": "Mmm, the humming sound."},
	{"word": "s", "level": 1, "zone": 1, "pattern": "continuous consonant", "sounds": ["/s/"], "tiles": ["s"], "hint": "Sss, the snake sound."},
	{"word": "t", "level": 1, "zone": 1, "pattern": "stop consonant", "sounds": ["/t/"], "tiles": ["t"], "hint": "The tapping t sound."},
	{"word": "n", "level": 1, "zone": 1, "pattern": "continuous consonant", "sounds": ["/n/"], "tiles": ["n"], "hint": "Nnn, the nose sound."},
	{"word": "p", "level": 1, "zone": 1, "pattern": "stop consonant", "sounds": ["/p/"], "tiles": ["p"], "hint": "The popping p sound."},
	{"word": "at", "level": 2, "zone": 1, "pattern": "VC", "sounds": ["/a/", "/t/"], "tiles": ["a", "t"], "hint": "You are at a place."},
	{"word": "am", "level": 2, "zone": 1, "pattern": "VC", "sounds": ["/a/", "/m/"], "tiles": ["a", "m"], "hint": "I am here."},
	{"word": "it", "level": 2, "zone": 1, "pattern": "VC", "sounds": ["/i/", "/t/"], "tiles": ["i", "t"], "hint": "It is a thing."},
	{"word": "in", "level": 2, "zone": 1, "pattern": "VC", "sounds": ["/i/", "/n/"], "tiles": ["i", "n"], "hint": "In the box."},
	{"word": "sat", "level": 3, "zone": 1, "pattern": "CVC continuous", "sounds": ["/s/", "/a/", "/t/"], "tiles": ["s", "a", "t"], "hint": "Sat down on a mat."},
	{"word": "mat", "level": 3, "zone": 1, "pattern": "CVC continuous", "sounds": ["/m/", "/a/", "/t/"], "tiles": ["m", "a", "t"], "hint": "A mat on the floor."},
	{"word": "sam", "level": 3, "zone": 1, "pattern": "CVC continuous", "sounds": ["/s/", "/a/", "/m/"], "tiles": ["s", "a", "m"], "hint": "A boy's name."},
	{"word": "man", "level": 3, "zone": 1, "pattern": "CVC continuous", "sounds": ["/m/", "/a/", "/n/"], "tiles": ["m", "a", "n"], "hint": "A grown-up person."},
	{"word": "sit", "level": 4, "zone": 1, "pattern": "CVC continuous", "sounds": ["/s/", "/i/", "/t/"], "tiles": ["s", "i", "t"], "hint": "Sit in a chair."},
	{"word": "sip", "level": 4, "zone": 1, "pattern": "CVC", "sounds": ["/s/", "/i/", "/p/"], "tiles": ["s", "i", "p"], "hint": "A tiny drink."},
	{"word": "pin", "level": 4, "zone": 1, "pattern": "CVC", "sounds": ["/p/", "/i/", "/n/"], "tiles": ["p", "i", "n"], "hint": "A small sharp pin."},
	{"word": "map", "level": 5, "zone": 1, "pattern": "CVC continuous", "sounds": ["/m/", "/a/", "/p/"], "tiles": ["m", "a", "p"], "hint": "A map shows the way."},
	{"word": "tap", "level": 5, "zone": 1, "pattern": "CVC", "sounds": ["/t/", "/a/", "/p/"], "tiles": ["t", "a", "p"], "hint": "Tap with a finger."},
	{"word": "nap", "level": 5, "zone": 1, "pattern": "CVC continuous", "sounds": ["/n/", "/a/", "/p/"], "tiles": ["n", "a", "p"], "hint": "A short sleep."},
	{"word": "pan", "level": 5, "zone": 1, "pattern": "CVC continuous", "sounds": ["/p/", "/a/", "/n/"], "tiles": ["p", "a", "n"], "hint": "You cook in a pan."},
	{"word": "cap", "level": 5, "zone": 1, "pattern": "CVC", "sounds": ["/k/", "/a/", "/p/"], "tiles": ["c", "a", "p"], "hint": "A container for holding things."},
	{"word": "cat", "level": 5, "zone": 1, "pattern": "CVC", "sounds": ["/k/", "/a/", "/t/"], "tiles": ["c", "a", "t"], "hint": "A soft pet that says meow."},
	{"word": "bat", "level": 5, "zone": 1, "pattern": "CVC", "sounds": ["/b/", "/a/", "/t/"], "tiles": ["b", "a", "t"], "hint": "It flies at night and sleeps upside down."},
	{"word": "dog", "level": 5, "zone": 1, "pattern": "CVC", "sounds": ["/d/", "/o/", "/g/"], "tiles": ["d", "o", "g"], "hint": "A pet that barks and wags its tail."},
]

const ZONE3_WORDS: Array = [
	{"word": "picnic", "level": 13, "zone": 3, "pattern": "two closed syllables", "sounds": ["/p/", "/i/", "/k/", "/n/", "/i/", "/k/"], "tiles": ["pic", "nic"], "hint": "A meal outside on a blanket.", "syllables": ["pic", "nic"]},
	{"word": "rabbit", "level": 13, "zone": 3, "pattern": "two closed syllables", "sounds": ["/r/", "/a/", "/b/", "/i/", "/t/"], "tiles": ["rab", "bit"], "hint": "A hopping animal with long ears.", "syllables": ["rab", "bit"]},
	{"word": "sunset", "level": 13, "zone": 3, "pattern": "two closed syllables", "sounds": ["/s/", "/u/", "/n/", "/s/", "/e/", "/t/"], "tiles": ["sun", "set"], "hint": "The sky when the sun goes down.", "syllables": ["sun", "set"]},
	{"word": "napkin", "level": 14, "zone": 3, "pattern": "two closed syllables", "sounds": ["/n/", "/a/", "/p/", "/k/", "/i/", "/n/"], "tiles": ["nap", "kin"], "hint": "You wipe your mouth with it.", "syllables": ["nap", "kin"]},
	{"word": "cabin", "level": 14, "zone": 3, "pattern": "two closed syllables", "sounds": ["/k/", "/a/", "/b/", "/i/", "/n/"], "tiles": ["cab", "in"], "hint": "A small house in the woods.", "syllables": ["cab", "in"]},
	{"word": "magnet", "level": 14, "zone": 3, "pattern": "two closed syllables", "sounds": ["/m/", "/a/", "/g/", "/n/", "/e/", "/t/"], "tiles": ["mag", "net"], "hint": "It pulls metal toward it.", "syllables": ["mag", "net"]},
	{"word": "replay", "level": 15, "zone": 3, "pattern": "prefix re-", "sounds": ["/r/", "/ē/", "/p/", "/l/", "/ā/"], "tiles": ["re", "play"], "hint": "Play it again.", "syllables": ["re", "play"]},
	{"word": "unpack", "level": 15, "zone": 3, "pattern": "prefix un-", "sounds": ["/u/", "/n/", "/p/", "/a/", "/k/"], "tiles": ["un", "pack"], "hint": "Take things out of a bag.", "syllables": ["un", "pack"]},
	{"word": "reread", "level": 15, "zone": 3, "pattern": "prefix re-", "sounds": ["/r/", "/ē/", "/r/", "/ē/", "/d/"], "tiles": ["re", "read"], "hint": "Read it one more time.", "syllables": ["re", "read"]},
	{"word": "helpful", "level": 16, "zone": 3, "pattern": "suffix -ful", "sounds": ["/h/", "/e/", "/l/", "/p/", "/f/", "/u/", "/l/"], "tiles": ["help", "ful"], "hint": "Ready to help.", "syllables": ["help", "ful"]},
	{"word": "sadness", "level": 16, "zone": 3, "pattern": "suffix -ness", "sounds": ["/s/", "/a/", "/d/", "/n/", "/e/", "/s/"], "tiles": ["sad", "ness"], "hint": "The feeling of being sad.", "syllables": ["sad", "ness"]},
	{"word": "kindness", "level": 16, "zone": 3, "pattern": "suffix -ness", "sounds": ["/k/", "/ī/", "/n/", "/d/", "/n/", "/e/", "/s/"], "tiles": ["kind", "ness"], "hint": "Being kind to others.", "syllables": ["kind", "ness"]},
	{"word": "said", "level": 17, "zone": 3, "pattern": "irregular", "sounds": ["/s/", "/e/", "/d/"], "tiles": ["s", "ai", "d"], "hint": "He said hello. Rule breaker: ai says /e/."},
	{"word": "was", "level": 17, "zone": 3, "pattern": "irregular", "sounds": ["/w/", "/u/", "/z/"], "tiles": ["w", "a", "s"], "hint": "It was sunny. Rule breaker: a says /u/."},
	{"word": "come", "level": 18, "zone": 3, "pattern": "irregular", "sounds": ["/k/", "/u/", "/m/"], "tiles": ["c", "o", "me"], "hint": "Come here. Rule breaker: o says /u/."},
	{"word": "have", "level": 18, "zone": 3, "pattern": "irregular", "sounds": ["/h/", "/a/", "/v/"], "tiles": ["h", "a", "ve"], "hint": "I have a book. Rule breaker: a is short."},
	{"word": "friend", "level": 19, "zone": 3, "pattern": "irregular", "sounds": ["/f/", "/r/", "/e/", "/n/", "/d/"], "tiles": ["fr", "ie", "nd"], "hint": "A person who cares for you. Rule breaker: ie says /e/."},
	{"word": "because", "level": 19, "zone": 3, "pattern": "irregular two-syllable", "sounds": ["/b/", "/ē/", "/k/", "/u/", "/z/"], "tiles": ["be", "cause"], "hint": "Why something happens.", "syllables": ["be", "cause"]},
	{"word": "area", "level": 20, "zone": 3, "pattern": "irregular", "sounds": ["/e/", "/r/", "/i/", "/ə/"], "tiles": ["a", "r", "ea"], "hint": "A region or space.", "syllables": ["a", "r", "ea"]},
	{"word": "music", "level": 20, "zone": 3, "pattern": "irregular two-syllable", "sounds": ["/m/", "/u/", "/z/", "/i/", "/k/"], "tiles": ["mu", "sic"], "hint": "Sound produced by instruments.", "syllables": ["mu", "sic"]},
]


static func words_for_zone(zone_id: int) -> Array:
	match zone_id:
		1:
			return ZONE1_WORDS.duplicate()
		2:
			return words_for_level(1) + words_for_level(2)
		3:
			return ZONE3_WORDS.duplicate()
		_:
			return WORDS.duplicate()


## `max_level` optionally caps how hard the asked-for word may be (99 = no cap).
## A Heavy Hit asks with a stepped-up `monster_level` instead, so each zone's own
## tier rule decides what "one step harder" means.
static func pick_word_for_zone(zone_id: int, monster_level: int, exclude: Array = [], max_level: int = 99) -> Dictionary:
	var pool: Array = []
	match zone_id:
		1:
			for entry in ZONE1_WORDS:
				if int(entry.get("level", 1)) <= maxi(1, mini(5, monster_level)):
					pool.append(entry)
		2:
			if monster_level >= 10:
				pool = words_for_level(1) + words_for_level(2) + words_for_level(3)
			elif monster_level >= 8:
				pool = words_for_level(2)
			else:
				pool = words_for_level(1)
		3:
			for entry in ZONE3_WORDS:
				if int(entry.get("level", 13)) <= maxi(13, monster_level):
					pool.append(entry)
			if pool.is_empty():
				pool = ZONE3_WORDS.duplicate()
		_:
			pool = WORDS.duplicate()
	if pool.is_empty():
		pool = words_for_zone(zone_id)
	if max_level < 99:
		var capped: Array = []
		for entry in pool:
			if int(entry.get("level", 1)) <= max_level:
				capped.append(entry)
		if not capped.is_empty():
			pool = capped
	var filtered: Array = []
	for entry in pool:
		if not exclude.has(String(entry["word"])):
			filtered.append(entry)
	if filtered.is_empty():
		filtered = pool
	return filtered[randi() % filtered.size()]


## Every distinct phoneme the bank teaches, mapped to one grapheme that spells
## it. Only entries whose sounds and tiles line up one-to-one contribute, so a
## phoneme always has a spelling the audio player can say. Used to build the
## redundant (wrong) sound tiles in the phoneme-picking question.
static func phoneme_bank() -> Dictionary:
	var bank: Dictionary = {}
	for entry in WORDS + ZONE1_WORDS + ZONE3_WORDS:
		var sounds: Array = entry.get("sounds", [])
		var tiles: Array = entry.get("tiles", [])
		if sounds.size() != tiles.size():
			continue
		for i in sounds.size():
			var sound := String(sounds[i])
			if not bank.has(sound):
				bank[sound] = String(tiles[i])
	return bank


static func is_vowel_grapheme(grapheme: String) -> bool:
	var g := grapheme.to_lower()
	return g in ["a", "e", "i", "o", "u", "ai", "ie", "me", "ve"]


## True when the word ends in a /k/ sound spelled c, k or ck — the classic
## Which Spelling? rule (duck, sock, lock, kit, cat...).
static func is_which_spelling_k(entry: Dictionary) -> bool:
	var tiles: Array = entry.get("tiles", [])
	if tiles.is_empty():
		return false
	var last := String(tiles[tiles.size() - 1]).to_lower()
	return last in ["c", "k", "ck"]


## The correct final /k/ grapheme for a Which Spelling? question.
static func which_spelling_k_answer(entry: Dictionary) -> String:
	var tiles: Array = entry.get("tiles", [])
	if tiles.is_empty():
		return ""
	return String(tiles[tiles.size() - 1]).to_lower()


## A chain partner for `entry`: same level, exactly one tile different when
## possible. Falls back to any other same-level word so the chain always runs.
static func chain_partner(entry: Dictionary, exclude: Array = []) -> Dictionary:
	var level := int(entry.get("level", 1))
	var mine: Array = entry.get("tiles", [])
	var all: Array = words_for_level(level)
	if all.is_empty():
		all = WORDS.duplicate()
	var word := String(entry.get("word", ""))
	var near: Array = []
	var far: Array = []
	for other in all:
		var w := String(other.get("word", ""))
		if w == word or exclude.has(w):
			continue
		var tiles: Array = other.get("tiles", [])
		var diff := 0
		var n := mini(mine.size(), tiles.size())
		for i in n:
			if String(mine[i]).to_lower() != String(tiles[i]).to_lower():
				diff += 1
		diff += absi(mine.size() - tiles.size())
		if diff == 1:
			near.append(other)
		else:
			far.append(other)
	if not near.is_empty():
		return near[randi() % near.size()]
	if not far.is_empty():
		return far[randi() % far.size()]
	return entry
