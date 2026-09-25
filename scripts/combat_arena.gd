extends Node2D

## CombatArena - the phoneme vs grapheme battle.
##
## The monster "says" a phoneme and the player taps the card that spells that
## sound. This is the OG auditory drill: hear the sound, choose its spelling.
## The three wrong cards are the other digraphs a reader actually confuses the
## target with, never random letters.
##
## Wrong taps are never punished. No XP, health or items are ever deducted.
## A wrong tap only plays a dull clink, replays the sound, and flashes the
## correct card - and that flash always ends turned off, so it is a hint rather
## than a permanent answer key.

const PHONEMES := ["sh", "ch", "th", "wh"]

## Fallback cue for when a phoneme has no audio clip yet: a keyword the player
## can look inside to find the sound. Audio always wins when a clip exists, so
## dropping the sound files in later restores the pure listening drill by itself.
const PHONEME_KEYWORDS := {
	"sh": "ship",
	"ch": "chin",
	"th": "thin",
	"wh": "when",
}

## One audio file per phoneme, named after the phoneme: sh.ogg, ch.ogg, ...
const PHONEME_DIR := "res://audio/phonemes/"
## Interface feedback: the dull "clink" and the hit sound.
const UI_SFX_DIRS := ["res://audio/ui/", "res://audio/"]
const AUDIO_EXTS := ["ogg", "wav", "mp3"]

const CARD_IDLE := Color(0.95, 0.96, 1, 1)
const BORDER_FLASH := Color(1, 0.78, 0.22, 1)
const BORDER_OFF := Color(1, 0.78, 0.22, 0)

const EMOTE_ALERT := "!"
const EMOTE_CONFUSED := "?"
const EMOTE_HURT := "sweat"

@export var max_hits: int = 3

@onready var _battlefield: Control = $Battlefield
@onready var _monster: Node2D = $Battlefield/MonsterNode
@onready var _body: Polygon2D = $Battlefield/MonsterNode/Body
@onready var _health_fill: ColorRect = $Battlefield/MonsterNode/HealthFill
@onready var _swipe: Node2D = $Battlefield/MonsterNode/Swipe
@onready var _emote: Node2D = $Battlefield/MonsterNode/EmoteMarker
@onready var _emote_glyph: Label = $Battlefield/MonsterNode/EmoteMarker/Glyph
@onready var _emote_sweat: Polygon2D = $Battlefield/MonsterNode/EmoteMarker/Sweat
@onready var _action_bar: HBoxContainer = $ActionBar
@onready var _prompt: Label = $Prompt
@onready var _cue: Label = $Battlefield/Cue
@onready var _replay: Button = $ReplayButton
@onready var _sfx: AudioStreamPlayer2D = $SfxPlayer
@onready var _phoneme_player: AudioStreamPlayer2D = $PhonemePlayer

var _cards: Array = []
var _phoneme := ""
var _hits_left := 0
var _locked := true
var _health_width := 0.0
var _phoneme_streams := {}
var _sfx_streams := {}


func _ready() -> void:
	randomize()
	_collect_cards()
	_load_audio()
	# Nothing to replay until at least one phoneme clip exists.
	_replay.visible = not _phoneme_streams.is_empty()
	_health_width = _health_fill.size.x
	_battlefield.resized.connect(_layout_monster)
	_replay.pressed.connect(_play_phoneme)
	_layout_monster.call_deferred()
	_hide_emote()
	_spawn_monster()


# ------------------------------------------------------------------- setup

## The four skill cards are the real TextureButton nodes in the action bar.
func _collect_cards() -> void:
	_cards.clear()
	for child in _action_bar.get_children():
		if child is TextureButton:
			var card: TextureButton = child
			card.pressed.connect(_on_card_pressed.bind(card))
			_cards.append(card)


# ------------------------------------------------------------------ spawning

func _spawn_monster() -> void:
	_locked = true
	_hits_left = max_hits
	_update_health()
	_body.position = Vector2.ZERO
	_body.scale = Vector2.ONE
	_body.modulate = Color(1, 1, 1, 1)
	_swipe.visible = false
	_hide_emote()

	_phoneme = _pick_phoneme()
	_build_cards(_phoneme)
	_show_emote(EMOTE_ALERT)
	_announce_prompt()
	_play_phoneme()

	await get_tree().create_timer(0.4).timeout
	_locked = false


func _pick_phoneme() -> String:
	var pool := PHONEMES.duplicate()
	if pool.size() > 1 and pool.has(_phoneme):
		pool.erase(_phoneme)
	return pool[randi() % pool.size()]


## Sets the question. With a clip this is a pure listening drill; without one the
## cue names a keyword the player can look inside, which keeps the answer out of
## the card row itself.
func _announce_prompt() -> void:
	if _phoneme_streams.has(_phoneme):
		_cue.text = "Listen!"
		_prompt.text = "Tap the spelling of the sound you hear."
	else:
		_cue.text = "Which letters make the sound in \"%s\"?" % _keyword_for(_phoneme)
		_prompt.text = "Tap the two letters that spell it."


func _keyword_for(phoneme: String) -> String:
	return String(PHONEME_KEYWORDS.get(phoneme, phoneme))


func _build_cards(correct: String) -> void:
	var options := [correct]
	var others := PHONEMES.duplicate()
	others.erase(correct)
	others.shuffle()
	for glyph in others:
		if options.size() >= _cards.size():
			break
		options.append(glyph)
	options.shuffle()

	for i in _cards.size():
		var card: TextureButton = _cards[i]
		var grapheme := ""
		if i < options.size():
			grapheme = String(options[i])
		(card.get_node("Glyph") as Label).text = grapheme
		card.set_meta("grapheme", grapheme)
		(card.get_node("Face") as ColorRect).color = CARD_IDLE
		(card.get_node("Border") as ColorRect).color = BORDER_OFF


# ------------------------------------------------------------------- answers

func _on_card_pressed(card: TextureButton) -> void:
	if _locked:
		return
	var grapheme := String(card.get_meta("grapheme", ""))
	if grapheme.is_empty():
		return
	if grapheme == _phoneme:
		_resolve_correct()
	else:
		_resolve_wrong()


func _resolve_correct() -> void:
	_locked = true
	_play_sfx("hit")
	_swipe_attack()
	_hits_left = maxi(_hits_left - 1, 0)
	_update_health()

	if _hits_left > 0:
		_prompt.text = "Yes! %s spells that sound. %d more." % [_phoneme, _hits_left]
		await get_tree().create_timer(0.8).timeout
		_spawn_monster()
	else:
		_show_emote(EMOTE_HURT)
		_prompt.text = "That was the last one - defeated!"
		await _play_defeat()
		_spawn_monster()


func _resolve_wrong() -> void:
	# Non-punitive by design: nothing is deducted here, ever.
	_play_sfx("clink")
	_show_emote(EMOTE_CONFUSED)
	_flash_correct_card()
	_play_phoneme()
	_prompt.text = "Not quite - the glowing card shows the letters."


func _flash_correct_card() -> void:
	for card in _cards:
		if String(card.get_meta("grapheme", "")) != _phoneme:
			continue
		var border := card.get_node("Border") as ColorRect
		var tween := create_tween()
		for i in 3:
			tween.tween_property(border, "color", BORDER_FLASH, 0.1)
			tween.tween_property(border, "color", BORDER_OFF, 0.14)
		return


# ------------------------------------------------------------------ feedback

func _swipe_attack() -> void:
	_swipe.visible = true
	_swipe.position = Vector2(-150.0, -20.0)
	_swipe.rotation = -0.7
	_swipe.modulate.a = 0.0

	var swing := create_tween()
	swing.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing.tween_property(_swipe, "modulate:a", 1.0, 0.05)
	swing.parallel().tween_property(_swipe, "position", Vector2(150.0, 24.0), 0.18)
	swing.parallel().tween_property(_swipe, "rotation", 0.55, 0.18)
	swing.tween_property(_swipe, "modulate:a", 0.0, 0.12)
	swing.tween_callback(_hide_swipe)

	var flinch := create_tween()
	flinch.tween_property(_body, "position", Vector2(12.0, -8.0), 0.06)
	flinch.tween_property(_body, "position", Vector2.ZERO, 0.18)


func _hide_swipe() -> void:
	_swipe.visible = false


func _play_defeat() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_body, "scale", Vector2(0.1, 0.1), 0.35)
	tween.parallel().tween_property(_body, "modulate:a", 0.0, 0.35)
	await tween.finished
	_body.scale = Vector2.ONE
	_body.modulate = Color(1, 1, 1, 1)


func _show_emote(symbol: String) -> void:
	_emote.visible = true
	if symbol == EMOTE_HURT:
		_emote_glyph.visible = false
		_emote_sweat.visible = true
	else:
		_emote_glyph.visible = true
		_emote_sweat.visible = false
		_emote_glyph.text = symbol

	_emote.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_emote, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_emote() -> void:
	_emote.visible = false


func _update_health() -> void:
	var ratio := 0.0
	if max_hits > 0:
		ratio = clampf(float(_hits_left) / float(max_hits), 0.0, 1.0)
	_health_fill.size = Vector2(maxf(_health_width * ratio, 0.0), _health_fill.size.y)


func _layout_monster() -> void:
	var field := _battlefield.size
	_monster.position = Vector2(field.x * 0.5, field.y * 0.56)


# --------------------------------------------------------------------- audio

## Everything is loaded up front so playback has no load hitch.
func _load_audio() -> void:
	for phoneme in PHONEMES:
		var stream := _find_stream(PHONEME_DIR, phoneme)
		if stream != null:
			_phoneme_streams[phoneme] = stream
	for sfx_name in ["clink", "hit"]:
		for dir in UI_SFX_DIRS:
			var stream := _find_stream(dir, sfx_name)
			if stream != null:
				_sfx_streams[sfx_name] = stream
				break


func _find_stream(dir: String, base: String) -> AudioStream:
	for ext in AUDIO_EXTS:
		var path := "%s%s.%s" % [dir, base, ext]
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res
	return null


func _play_phoneme() -> void:
	# No clip yet: the on-screen cue carries the question instead.
	if not _phoneme_streams.has(_phoneme):
		return
	_phoneme_player.stream = _phoneme_streams[_phoneme]
	_phoneme_player.play()


func _play_sfx(sfx_name: String) -> void:
	if not _sfx_streams.has(sfx_name):
		return
	_sfx.stream = _sfx_streams[sfx_name]
	_sfx.play()
