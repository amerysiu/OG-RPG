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
		"title": "English phoneme snippets",
		"license": "CC-BY-NC 4.0",
		"kind": "audio",
		"url": "https://freesound.org/people/margo_heston/packs/12249/",
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


## Grapheme -> the recording that says that phoneme.
##
## res://audio/phonemes is a mix: some sounds have their own trimmed short file
## (a.wav, sh.wav, th.wav, ...) and the rest still sit under the original
## Freesound filenames from the "English phoneme" pack. This map lets a
## consonant such as m, n or s play without copying or renaming anything.
## "c" and "ck" say the same sound as "k", and "x" says /ks/.
## There is no /b/ recording in the pack, so "b" is deliberately absent.
const PHONEME_ALIASES: Dictionary = {
	"c": "193283__margo_heston__k.wav",
	"k": "193283__margo_heston__k.wav",
	"ck": "193283__margo_heston__k.wav",
	"d": "193268__margo_heston__d.wav",
	"f": "193270__margo_heston__ff.wav",
	"g": "193279__margo_heston__g.wav",
	"h": "193278__margo_heston__hh.wav",
	"j": "193276__margo_heston__jj.wav",
	"l": "193282__margo_heston__ll.wav",
	"m": "193281__margo_heston__mm.wav",
	"n": "193280__margo_heston__nn.wav",
	"p": "193284__margo_heston__pp.wav",
	"q": "193274__margo_heston__qu.wav",
	"qu": "193274__margo_heston__qu.wav",
	"r": "193275__margo_heston__rr.wav",
	"s": "193272__margo_heston__ss.wav",
	"t": "193273__margo_heston__tt.wav",
	"v": "193322__margo_heston__vvv.wav",
	"w": "193326__margo_heston__wuh.wav",
	"x": "193323__margo_heston__kss.wav",
	"y": "193324__margo_heston__yyuh.wav",
	"z": "193321__margo_heston__zzz.wav",
	"ng": "193310__margo_heston__nng.wav",
	"sh": "193312__margo_heston__shh.wav",
	"ch": "193305__margo_heston__ch.wav",
	"th": "193320__margo_heston__th.wav",
	"wh": "193311__margo_heston__hw.wav",
	"ee": "193267__margo_heston__ee.wav",
	"ay": "193262__margo_heston__ay.wav",
	"ai": "193262__margo_heston__ay.wav",
	"igh": "193269__margo_heston__aye.wav",
	"oa": "193285__margo_heston__ohh.wav",
	"oo": "193319__margo_heston__oo.wav",
	"ow": "193308__margo_heston__oww.wav",
	"oi": "193313__margo_heston__oy.wav",
	"oy": "193313__margo_heston__oy.wav",
	"aw": "193263__margo_heston__aww.wav",
	"au": "193306__margo_heston__au.wav",
	"er": "193304__margo_heston__err.wav",
	"ar": "193307__margo_heston__arr.wav",
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
	# 1. A trimmed short file named exactly for this grapheme, if one exists.
	var direct := "res://audio/phonemes/%s.wav" % key
	if ResourceLoader.exists(direct):
		return load(direct) as AudioStream
	# 2. Otherwise the original phoneme-pack recording for this grapheme.
	var alias := String(PHONEME_ALIASES.get(key, ""))
	if alias != "":
		var alias_path := "res://audio/phonemes/%s" % alias
		if ResourceLoader.exists(alias_path):
			return load(alias_path) as AudioStream
	# 3. A whole word file (used by the older word-build mini-game).
	if key.length() > 1 and ResourceLoader.exists(direct):
		return load(direct) as AudioStream
	# 4. Last resort: the first sound of the grapheme, if it has its own file.
	if key.length() > 0:
		var first := "res://audio/phonemes/%s.wav" % key.substr(0, 1)
		if ResourceLoader.exists(first):
			return load(first) as AudioStream
	return null


func catalog_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for entry in CATALOG:
		lines.append("%s [%s] %s -> %s" % [entry["id"], entry["license"], entry["url"], entry["local"]])
	return "\n".join(lines)
