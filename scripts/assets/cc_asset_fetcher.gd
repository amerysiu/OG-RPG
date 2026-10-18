extends Node

signal catalog_ready(entries: Array)

const CATALOG: Array = [
	{
		"id": "kenney_iso_dungeon",
		"title": "Kenney Isometric Miniature Dungeon",
		"license": "CC0",
		"kind": "tileset",
		"url": "https://kenney.nl/assets/isometric-miniature-dungeon",
		"local": "res://assets/2.5d_tiles/Tileset/Tileset.png",
	},
	{
		"id": "kenney_toon_characters",
		"title": "Local 2.5D character portraits (placeholder until CC0 iso pack lands)",
		"license": "project-local",
		"kind": "characters",
		"url": "https://kenney.nl/assets/toon-characters-1",
		"local": "res://assets/2.5d_tiles/Characters/Character 1.png",
	},
	{
		"id": "zoonami_monsters",
		"title": "Local 2.5D monster portraits (placeholder)",
		"license": "project-local",
		"kind": "monsters",
		"url": "https://opengameart.org/content/isometric-64x64-outside-tileset",
		"local": "res://assets/2.5d_tiles/Monsters/New Versions/zoonami_chickadee_front.png",
	},
	{
		"id": "phoneme_buffers",
		"title": "English phoneme and word audio (generated locally with VoiceStudio / OmniVoice TTS)",
		"license": "project-local",
		"kind": "audio",
		"url": "https://github.com/debpalash/VoiceStudio",
		"local": "res://audio/phonemes/a.wav",
	},
	{
		"id": "plains_backdrop",
		"title": "Battle backdrop - Plains",
		"license": "project-local",
		"kind": "backdrop",
		"url": "https://kenney.nl/assets/background-elements",
		"local": "res://assets/2.5d_tiles/Battle Backgrounds/Without Textboxes/Plains.png",
	},
	{
		"id": "forest_backdrop",
		"title": "Battle backdrop - Forest",
		"license": "project-local",
		"kind": "backdrop",
		"url": "https://kenney.nl/assets/background-elements",
		"local": "res://assets/2.5d_tiles/Battle Backgrounds/Without Textboxes/Forest.png",
	},
	{
		"id": "citadel_backdrop",
		"title": "Battle backdrop - Underground / stone",
		"license": "project-local",
		"kind": "backdrop",
		"url": "https://kenney.nl/assets/background-elements",
		"local": "res://assets/2.5d_tiles/Battle Backgrounds/Without Textboxes/Underground.png",
	},
]

const PLAYER_SPRITES: Array = [
	"res://assets/2.5d_tiles/Characters/Character 1.png",
	"res://assets/2.5d_tiles/Characters/Character 2.png",
	"res://assets/2.5d_tiles/Characters/Character 3.png",
	"res://assets/2.5d_tiles/Characters/Character 4.png",
	"res://assets/2.5d_tiles/Characters/Character 5.png",
]

const MONSTER_SPRITES: Dictionary = {
	"speed": [
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_chickadee_front.png",
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_spaero_front.png",
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_fuzall_front.png",
	],
	"audio": [
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_howler_front.png",
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_grimlit_front.png",
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_merin_front.png",
	],
	"forge": [
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_ruffalo_front.png",
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_kackaburr_front.png",
		"res://assets/2.5d_tiles/Monsters/New Versions/zoonami_maluga_front.png",
	],
}


## Grapheme -> phoneme key, for the few tiles with no dedicated recording.
##
## res://audio/phonemes now holds one generated recording per phoneme key
## (a.wav, b.wav, sh.wav, th.wav, ...) plus optional alternates named
## <key>~<alt>.wav. Multi-letter tiles without their own file (blends and
## chunks such as "st", "play", "ness") are spoken letter by letter by
## phoneme_stream(); this map only covers letters/graphemes that have no
## recording of their own.
const PHONEME_ALIASES: Dictionary = {
	"q": "k",   # no /kw/ clip; k is the closest stand-in
	"qu": "k",
	"y": "a",   # y-as-vowel (as in "play") is closest to long a; no standalone y clip
}


func _ready() -> void:
	catalog_ready.emit(CATALOG)


func texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func player_texture(index: int = 0) -> Texture2D:
	return texture(PLAYER_SPRITES[index % PLAYER_SPRITES.size()])


func monster_texture(mode: String, index: int = 0) -> Texture2D:
	var pack: Array = MONSTER_SPRITES.get(mode, MONSTER_SPRITES["speed"])
	return texture(String(pack[index % pack.size()]))


func backdrop_for_zone(zone_id: int) -> Texture2D:
	match zone_id:
		2:
			return texture("res://assets/2.5d_tiles/Battle Backgrounds/Without Textboxes/Forest.png")
		3:
			return texture("res://assets/2.5d_tiles/Battle Backgrounds/Without Textboxes/Underground.png")
		_:
			return texture("res://assets/2.5d_tiles/Battle Backgrounds/Without Textboxes/Plains.png")


func phoneme_stream(tile: String) -> AudioStream:
	var key := tile.to_lower().strip_edges()
	# 1. A recording named exactly for this grapheme.
	var single := _phoneme_wav(key)
	if single != null:
		return single
	# 2. Blend / chunk tile with no recording of its own ("st", "play",
	#    "ness", ...): say it letter by letter.
	if key.length() > 1:
		return _concat_letters(key)
	return null


## Whole-word recording, e.g. "because" -> res://audio/words/because.wav.
func word_stream(word: String) -> AudioStream:
	var key := word.to_lower().strip_edges()
	if key.is_empty():
		return null
	var path := "res://audio/words/%s.wav" % key
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


## The recording for a sound written "/k/", "/ā/", "/sh/" ... ("-" = silent).
func sound_stream(sound: String) -> AudioStream:
	var key := sound.strip_edges().trim_prefix("/").trim_suffix("/").to_lower()
	if key.is_empty() or key == "-":
		return null
	return _phoneme_wav(key)


## A tile as it sounds IN THIS WORD: prefer the sound (so the ai in "rain"
## says /ā/ and the ai in "said" says /e/), else the grapheme's own clip.
func unit_stream(sound: String, tile: String) -> AudioStream:
	var by_sound := sound_stream(sound)
	if by_sound != null:
		return by_sound
	if sound.strip_edges() == "-":
		return null
	return phoneme_stream(tile)


## A short chunk such as a syllable ("rab"), a rime ("-at") or a morpheme.
func chunk_stream(chunk: String) -> AudioStream:
	var key := chunk.to_lower().strip_edges()
	var direct := _phoneme_wav(key)
	if direct != null:
		return direct
	var as_word := word_stream(key.trim_prefix("-"))
	if as_word != null:
		return as_word
	return phoneme_stream(key.trim_prefix("-"))


func has_word_audio(word: String) -> bool:
	return ResourceLoader.exists("res://audio/words/%s.wav" % word.to_lower().strip_edges())


## The recording for one phoneme key, resolving PHONEME_ALIASES one level.
func _phoneme_wav(key: String) -> AudioStreamWAV:
	var path := "res://audio/phonemes/%s.wav" % key
	if not ResourceLoader.exists(path):
		var alias := String(PHONEME_ALIASES.get(key, ""))
		if alias.is_empty():
			return null
		path = "res://audio/phonemes/%s.wav" % alias
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStreamWAV


## Stitch per-letter phoneme recordings into one stream so callers that
## expect a single AudioStream keep working unchanged.
func _concat_letters(key: String) -> AudioStream:
	var parts: Array[AudioStreamWAV] = []
	for i in key.length():
		var part := _phoneme_wav(key.substr(i, 1))
		if part == null or part.format != AudioStreamWAV.FORMAT_16_BITS:
			return null
		if not parts.is_empty() and (part.mix_rate != parts[0].mix_rate or part.stereo != parts[0].stereo):
			return null
		parts.append(part)
	if parts.is_empty():
		return null
	if parts.size() == 1:
		return parts[0]
	var out := AudioStreamWAV.new()
	out.format = AudioStreamWAV.FORMAT_16_BITS
	out.mix_rate = parts[0].mix_rate
	out.stereo = parts[0].stereo
	var pcm := PackedByteArray()
	for part in parts:
		pcm.append_array(part.data)
	out.data = pcm
	return out


func catalog_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for entry in CATALOG:
		lines.append("%s [%s] %s -> %s" % [entry["id"], entry["license"], entry["url"], entry["local"]])
	return "\n".join(lines)
