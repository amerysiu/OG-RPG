class_name WordBank
extends RefCounted

## Word data for the early Orton-Gillingham levels.
##
## Every word is 4 letters and fully decodable: only short vowels, single
## consonants, and the first blends/digraphs a beginner meets.
##
##   "w"   - the target word
##   "tip" - the phonics pattern the player should notice after solving
##
## Keep every word exactly 4 letters so it matches WORD_LENGTH in word_game.gd.

const WORDS := [
	{"w": "stop", "tip": "s-t blend: two sounds said back to back, no vowel between them."},
	{"w": "fish", "tip": "s-h makes ONE sound: /sh/."},
	{"w": "jump", "tip": "m-p blend at the end - say both, stop the air after p."},
	{"w": "sand", "tip": "n-d blend at the end; a says /a/ like apple."},
	{"w": "lamp", "tip": "short a, then the m-p blend at the end."},
	{"w": "milk", "tip": "l-k blend at the end; i says /i/ like itch."},
	{"w": "gift", "tip": "f-t blend at the end; i says /i/ like itch."},
	{"w": "hand", "tip": "n-d blend at the end; a says /a/ like apple."},
	{"w": "desk", "tip": "s-k blend at the end; e says /e/ like egg."},
	{"w": "nest", "tip": "s-t blend at the end; e says /e/ like egg."},
	{"w": "ship", "tip": "s-h makes ONE sound: /sh/."},
	{"w": "chat", "tip": "c-h makes ONE sound: /ch/."},
	{"w": "ring", "tip": "n-g at the end says /ng/ - one sound, humming in the nose."},
	{"w": "moth", "tip": "t-h makes ONE quiet sound: /th/."},
	{"w": "flag", "tip": "f-l blend at the start - keep both sounds."},
	{"w": "plum", "tip": "p-l blend at the start; u says /u/ like up."},
	{"w": "crab", "tip": "c-r blend at the start; a says /a/ like apple."},
	{"w": "drum", "tip": "d-r blend at the start; u says /u/ like up."},
	{"w": "star", "tip": "s-t blend at the start; a-r says /ar/."},
	{"w": "frog", "tip": "f-r blend at the start; o says /o/ like octopus."},
	{"w": "grin", "tip": "g-r blend at the start; i says /i/ like itch."},
	{"w": "trap", "tip": "t-r blend at the start; a says /a/ like apple."},
	{"w": "slug", "tip": "s-l blend at the start; u says /u/ like up."},
	{"w": "swim", "tip": "s-w blend at the start; i says /i/ like itch."},
]


## The word of the day: the same word for every player on a given date.
static func daily_word() -> Dictionary:
	var date_key := Time.get_date_string_from_system(false)
	var index: int = abs(hash(date_key)) % WORDS.size()
	return WORDS[index]


## A random word for free practice after the daily is finished.
static func practice_word(exclude: String = "") -> Dictionary:
	var pool: Array = WORDS
	if not exclude.is_empty():
		var filtered: Array = []
		for entry in WORDS:
			if String(entry["w"]).to_upper() != exclude.to_upper():
				filtered.append(entry)
		if not filtered.is_empty():
			pool = filtered
	return pool[randi() % pool.size()]
