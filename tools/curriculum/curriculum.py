"""OG curriculum source of truth.

Edit THIS file to change stages, words, heart words or sentences, then run:

    python tools/curriculum/curriculum.py

It validates every entry and regenerates:
    scripts/og/og_data.gd           (game data, do not hand-edit)
    tools/audio/audio_manifest.json (every phoneme key + word the game can say)

After adding words, regenerate audio on a machine with edge-tts:
    python tools/audio/regen_edge_tts.py

Notation
--------
Tiles are space-separated graphemes (or syllables / morphemes for long words):
    "sh i p"   -> tiles ["sh", "i", "p"]
Sounds default from the tile (see DEFAULT_SOUND). Override with a
space-separated string; "-" marks a silent tile:
    W("cape", "c a p e", "...", s="k ā p -")
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_GD = ROOT / "scripts" / "og" / "og_data.gd"
OUT_AUDIO = ROOT / "tools" / "audio" / "audio_manifest.json"

# ----------------------------------------------------------------------------
# Stages (teaching order). zone = world zone id 0..7; -1 = cross-zone strand.
# modes: wand = listening question, light = recognition (used when this stage
# is the REVIEW stage), heavy = encoding / production (2 damage).
# ----------------------------------------------------------------------------
STAGES = [
    # id, band, zone, name, focus, rule card, wand, light, heavy
    ("A1", "A", 0, "Word & rhyme awareness", "Hear rhyme", "Rhyming words end with the same sounds: cat, hat.", "rhyme_hunt", "rhyme_hunt", "rhyme_hunt"),
    ("A2", "A", 0, "Syllable awareness", "Clap the beats in a word", "Every beat in a word is a syllable: sun-set has 2.", "syllable_drum", "syllable_drum", "syllable_drum"),
    ("A3", "A", 0, "Onset & rime", "First sound + the rest", "b + at = bat. Change the first sound to make a new word.", "onset_forge", "rhyme_hunt", "onset_forge"),
    ("A4", "A", 0, "Phoneme isolation", "Find first, last, middle sound", "Listen for one sound at a time.", "echo_shield", "echo_shield", "echo_shield"),
    ("A5", "A", 0, "Phoneme blending", "Slide sounds into a word", "Push the sounds together: /s/ /a/ /t/ -> sat.", "sound_slide", "sound_slide", "sound_slide"),
    ("A6", "A", 0, "Phoneme segmentation", "One token per sound", "Say the word slowly. Push one token for each sound.", "elkonin", "sound_slide", "elkonin"),
    ("A7", "A", 0, "Phoneme manipulation", "Swap one sound", "Change one sound to make a new word: cat -> hat.", "word_chain", "word_chain", "word_chain"),
    ("B1", "B", 1, "Continuous consonants + short a", "m s f l n r a", "These sounds can be stretched: mmm, sss, fff. a says /a/ as in apple.", "echo_shield", "echo_shield", "word_build"),
    ("B2", "B", 1, "Stop consonants", "t p b d c g h", "Stop sounds are short and quick. Say /t/, not 'tuh'.", "echo_shield", "echo_shield", "word_build"),
    ("B3", "B", 1, "Short i and o", "i (itch), o (octopus)", "i says /i/ as in itch. o says /o/ as in octopus.", "vowel_pick", "vowel_pick", "word_build"),
    ("B4", "B", 1, "Short u and e", "u (up), e (Ed)", "u says /u/ as in up. e says /e/ as in Ed. Listen: e or i?", "vowel_pick", "twin_caves", "word_build"),
    ("B5", "B", 1, "Remaining consonants", "j k v w x y z qu", "qu always stick together. x says /ks/.", "echo_shield", "echo_shield", "word_build"),
    ("B6", "B", 1, "Reversal guard b d p", "Tell b and d apart", "b: bat then ball. d: door then knob.", "echo_shield", "twin_caves", "word_build"),
    ("C1", "C", 2, "VC & CVC (closed syllable)", "One vowel, closed in = short", "A closed syllable has one vowel closed in by a consonant. The vowel is short.", "sound_slide", "vowel_pick", "word_build"),
    ("C2", "C", 2, "Consonant digraphs", "sh ch th wh ck", "Two letters, ONE sound. ck comes right after a short vowel.", "sound_pick", "which_spelling", "word_build"),
    ("C3", "C", 2, "FLOSS rule", "ff ll ss zz", "After a short vowel at the end of a one-syllable word, double f, l, s, z.", "sound_pick", "which_spelling", "word_build"),
    ("C4", "C", 2, "Initial blends", "fl cr st sw ...", "In a blend each letter keeps its own sound.", "sound_slide", "sound_pick", "word_build"),
    ("C5", "C", 2, "Final blends", "-nd -st -mp -lk -ft", "Two consonants at the end: say both.", "sound_pick", "sound_slide", "word_build"),
    ("C6", "C", 2, "Glued (welded) sounds", "-ng -nk -all", "Some sounds stick together: ing, ank, all.", "sound_pick", "word_chain", "word_build"),
    ("C7", "C", 2, "-tch / -dge", "match, badge", "Right after a short vowel use tch and dge. After a consonant use ch and ge.", "sound_pick", "which_spelling", "word_build"),
    ("C8", "C", 2, "Suffix -s / -es", "cats, boxes", "Add -es after s, x, z, ch, sh. Otherwise add -s.", "twin_caves", "which_spelling", "morpheme_smith"),
    ("D1", "D", 3, "Magic e (VCe)", "cap -> cape", "Silent e makes the vowel say its name.", "magic_e", "real_or_nonsense", "word_build"),
    ("D2", "D", 3, "Open syllable", "go, me, hi", "When a vowel ends the syllable, it says its name.", "sound_slide", "syllable_sort", "word_build"),
    ("D3", "D", 3, "Vowel teams", "ai ay ee ea oa ow igh", "Two vowels, one sound. ai in the middle, ay at the end.", "sound_pick", "which_spelling", "word_build"),
    ("D4", "D", 4, "R-controlled vowels", "ar or er ir ur", "Bossy r changes the vowel. er, ir, ur all say /er/.", "echo_shield", "which_spelling", "word_build"),
    ("D5", "D", 4, "Diphthongs & variant vowels", "oi oy ou ow aw oo", "oi in the middle, oy at the end. ou in the middle, ow at the end.", "echo_shield", "which_spelling", "word_build"),
    ("D6", "D", 4, "Soft c & g, y as a vowel", "city, gem, my, happy", "c and g are soft before e, i, y. y at the end says /ī/ or /ē/.", "twin_caves", "twin_caves", "word_build"),
    ("D7", "D", 4, "Silent letters", "kn wr gn mb", "Some letters don't speak: kn, wr, gn, mb.", "sound_slide", "heart_word", "word_build"),
    ("E1", "E", 5, "Compound words", "sun + set", "Two small words join to make one big word.", "sound_slide", "syllable_splitter", "word_build"),
    ("E2", "E", 5, "VC/CV division", "rab | bit", "Split between the two consonants. Both syllables are closed.", "syllable_drum", "syllable_splitter", "word_build"),
    ("E3", "E", 5, "V/CV and VC/V", "ro | bot, cam | el", "Try splitting before the consonant first (open). If it isn't a word, split after it.", "sound_slide", "syllable_splitter", "word_build"),
    ("E4", "E", 5, "Consonant-le", "ta | ble", "Count back three letters from the end: -ble, -dle, -tle.", "sound_slide", "syllable_sort", "word_build"),
    ("E5", "E", 5, "3+ syllables & VCCCV", "fan | tas | tic", "Keep blends and digraphs together when you split.", "syllable_drum", "syllable_splitter", "word_build"),
    ("E6", "E", 5, "Schwa", "a | bout, so | fa", "A vowel in a quiet syllable often says lazy /uh/.", "stress_pick", "schwa_pick", "word_build"),
    ("F1", "F", 6, "Suffixes -ed, -ing", "jumped, landed", "-ed says /t/, /d/ or /id/.", "twin_caves", "morpheme_smith", "morpheme_smith"),
    ("F2", "F", 6, "Suffix spelling rules", "hopping, hoping, cried", "1-1-1: double. Silent e: drop it. Consonant + y: change y to i.", "rule_gate", "rule_gate", "rule_gate"),
    ("F3", "F", 6, "Anglo-Saxon prefixes", "un- re- mis- pre- dis-", "A prefix goes in front and changes the meaning.", "meaning_pick", "meaning_pick", "morpheme_smith"),
    ("F4", "F", 6, "Derivational suffixes", "-ful -less -ness -ly -est", "A suffix goes at the end and changes the word.", "meaning_pick", "meaning_pick", "morpheme_smith"),
    ("F5", "F", 7, "Latin roots", "port rupt tract spect dict struct", "Latin roots carry the meaning: port = carry.", "root_tree", "root_tree", "morpheme_smith"),
    ("F6", "F", 7, "Greek combining forms", "phon graph tele scope bio", "Greek forms join together: tele + scope = see far.", "root_tree", "root_tree", "morpheme_smith"),
    ("H1", "H", -1, "Heart words", "Irregular high-frequency words", "Most of the word is regular. Learn the tricky (heart) part by heart.", "heart_word", "heart_word", "word_build"),
    ("R1", "R", -1, "Decodable sentences", "Read connected text", "Read every word. Use the sounds you know.", "sentence_scroll", "sentence_scroll", "real_or_nonsense"),
]

ZONES = [
    # id, key, name, bands/stages, level range, task text, boss name
    (0, "meadow", "Echo Meadow", ["A1", "A2", "A3", "A4", "A5", "A6", "A7"], "Sounds only - no letters yet", "Great Echo"),
    (1, "village", "Phoneme Village", ["B1", "B2", "B3", "B4", "B5", "B6"], "Letters and their sounds", "Letter Golem"),
    (2, "woods", "Closed-Syllable Woods", ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"], "Short-vowel words, digraphs, blends", "Thornwood Treant"),
    (3, "lake", "Long-Vowel Lake", ["D1", "D2", "D3"], "Magic e, open syllables, vowel teams", "Lake Wyrm"),
    (4, "caves", "Growling Caves", ["D4", "D5", "D6", "D7"], "Bossy r, oi/ou, soft c/g, silent letters", "Roaring Drake"),
    (5, "mountains", "Syllable Mountains", ["E1", "E2", "E3", "E4", "E5", "E6"], "Splitting long words into syllables", "Mountain Giant"),
    (6, "citadel", "Morpheme Citadel", ["F1", "F2", "F3", "F4"], "Prefixes, suffixes and spelling rules", "Citadel King"),
    (7, "ruins", "Root Ruins", ["F5", "F6"], "Latin roots and Greek forms", "Ancient Lexicon"),
]

# ----------------------------------------------------------------------------
# Grapheme -> default sound key (sounds are written "/key/").
# ----------------------------------------------------------------------------
DEFAULT_SOUND = {
    **{c: c for c in "bdfghjklmnprstvwyz"},
    "c": "k", "ck": "k", "x": "ks", "qu": "kw", "q": "k",
    "a": "a", "e": "e", "i": "i", "o": "o", "u": "u",
    "sh": "sh", "ch": "ch", "th": "th", "wh": "w", "tch": "ch", "dge": "j", "ge": "j",
    "ff": "f", "ll": "l", "ss": "s", "zz": "z",
    "ng": "ng", "ing": "ing", "ang": "ang", "ong": "ong", "ung": "ung",
    "ink": "ink", "ank": "ank", "unk": "unk", "all": "all",
    "ai": "ā", "ay": "ā", "ee": "ē", "ea": "ē", "oa": "ō", "ow": "ō", "igh": "ī",
    "ar": "ar", "or": "or", "er": "er", "ir": "er", "ur": "er",
    "oi": "oi", "oy": "oi", "ou": "ou", "aw": "aw", "au": "aw", "oo": "oo", "ew": "oo", "ue": "oo",
    "kn": "n", "wr": "r", "gn": "n", "mb": "m",
}

# Text the TTS says for each phoneme key (only keys not already obvious).
PHONEME_PROMPTS = {
    "a": "ah", "e": "eh", "i": "ih", "o": "aw", "u": "uh",
    "ā": "ay", "ē": "ee", "ī": "eye", "ō": "oh", "ū": "yoo", "ə": "uh",
    "f": "ffff", "l": "llll", "m": "mmmm", "n": "nnnn", "r": "rrrr", "s": "ssss", "v": "vvvv", "z": "zzzz",
    "b": "buh", "c": "kuh", "d": "duh", "g": "guh", "h": "huh", "j": "juh", "k": "kuh", "p": "puh",
    "t": "tuh", "w": "wuh", "x": "ks", "ks": "ks", "kw": "kwuh", "y": "yuh",
    "sh": "shhh", "ch": "chuh", "th": "thhh", "ng": "ing", "ck": "kuh",
    "ar": "ar", "or": "or", "er": "er", "oi": "oy", "ou": "ow", "aw": "aw", "oo": "oo", "ŏŏ": "oo, as in book",
    "ing": "ing", "ang": "ang", "ong": "ong", "ung": "ung", "ink": "ink", "ank": "ank", "unk": "unk", "all": "all",
    "iz": "iz", "id": "id",
    "ble": "bul", "dle": "dul", "gle": "gul", "ple": "pul", "tle": "tul", "zle": "zul", "fle": "ful", "kle": "kul",
}


class Entry(dict):
    pass


def W(word, tiles, hint="", s=None, **extra):
    t = tiles.split()
    if s is None:
        snd = []
        for g in t:
            key = DEFAULT_SOUND.get(g)
            if key is None:
                key = g  # syllable / morpheme tile: the "sound" is the chunk
            snd.append(key)
    else:
        snd = s.split()
    e = Entry(word=word, tiles=t, sounds=["-" if x == "-" else "/%s/" % x for x in snd], hint=hint)
    e.update(extra)
    return e


def SYL(word, syls, hint="", **extra):
    """Multi-syllable / morpheme word: tiles are the parts."""
    parts = syls.split()
    e = Entry(word=word, tiles=parts, sounds=["/%s/" % p for p in parts], hint=hint, unit="syllable")
    e.update(extra)
    return e


# ---------------------------------------------------------------- shared CVC
CVC = [
    W("cat", "c a t", "A soft pet that says meow."), W("hat", "h a t", "You wear it on your head."),
    W("bat", "b a t", "It flies at night."), W("mat", "m a t", "A rug by the door."),
    W("sat", "s a t", "Sat down on a chair."), W("sun", "s u n", "It shines in the sky."),
    W("fun", "f u n", "Playing is fun."), W("run", "r u n", "Go very fast on your feet."),
    W("bun", "b u n", "A soft bread roll."), W("pig", "p i g", "A pink farm animal."),
    W("dig", "d i g", "Make a hole with a spade."), W("wig", "w i g", "Fake hair."),
    W("big", "b i g", "Not small."), W("hop", "h o p", "Jump on one foot."),
    W("top", "t o p", "The highest part."), W("mop", "m o p", "You clean the floor with it."),
    W("pop", "p o p", "A balloon goes pop."), W("bed", "b e d", "You sleep in it."),
    W("red", "r e d", "The colour of a fire truck."), W("fed", "f e d", "Gave food to."),
    W("ten", "t e n", "The number after nine."), W("hen", "h e n", "A mother chicken."),
    W("pen", "p e n", "You write with it."), W("cut", "c u t", "Use scissors."),
    W("hit", "h i t", "Strike the ball."), W("map", "m a p", "It shows the way."),
    W("man", "m a n", "A grown-up boy."), W("mug", "m u g", "A cup with a handle."),
    W("bug", "b u g", "A tiny crawling animal."), W("rug", "r u g", "A small carpet."),
]


def cvc(*words):
    by = {e["word"]: e for e in CVC}
    return [Entry(by[w]) for w in words]


WORDS = {}

# ------------------------------------------------------------- Band A (oral)
WORDS["A1"] = cvc("cat", "hat", "bat", "mat", "sun", "fun", "run", "bun", "pig", "dig", "wig", "big", "hop", "top", "mop", "pop", "bed", "red", "fed", "ten", "hen", "pen")
WORDS["A2"] = [
    SYL("sun", "sun", "It shines."), SYL("dog", "dog", "A pet that barks."), SYL("hat", "hat", ""),
    SYL("sunset", "sun set", "When the sun goes down."), SYL("cupcake", "cup cake", "A little cake."),
    SYL("rainbow", "rain bow", "Colours in the sky."), SYL("popcorn", "pop corn", "A snack that pops."),
    SYL("rabbit", "rab bit", "It hops."), SYL("pumpkin", "pump kin", "A big orange fruit."),
    SYL("banana", "ba na na", "A yellow fruit."), SYL("elephant", "el e phant", "A huge grey animal."),
    SYL("butterfly", "but ter fly", "It has colourful wings."), SYL("dinosaur", "di no saur", "A giant from long ago."),
    SYL("hotdog", "hot dog", "Food in a bun."), SYL("bathtub", "bath tub", "You wash in it."),
    SYL("catfish", "cat fish", "A fish with whiskers."), SYL("caterpillar", "cat er pil lar", "It turns into a butterfly."),
]
WORDS["A3"] = cvc("cat", "hat", "bat", "mat", "sat", "pig", "dig", "wig", "big", "hop", "top", "mop", "pop", "sun", "fun", "run", "bun", "hen", "ten", "pen")
WORDS["A4"] = cvc("map", "man", "mop", "mug", "sun", "sat", "top", "ten", "hat", "hop", "hen", "bed", "bug", "big", "pig", "pen", "cat", "cut", "dig", "red")
WORDS["A5"] = cvc("sat", "man", "sun", "mat", "fun", "run", "map", "mop", "cat", "pig", "bed", "hop", "top", "big", "bug") + [
    W("frog", "f r o g", "It hops by the pond."), W("stop", "s t o p", "Don't go!"), W("flag", "f l a g", "It waves on a pole."),
]
WORDS["A6"] = cvc("sat", "man", "sun", "cat", "pig", "bed", "hop", "top", "big", "bug", "ten", "hen") + [
    W("frog", "f r o g", ""), W("stop", "s t o p", ""), W("flag", "f l a g", ""), W("swim", "s w i m", ""),
]
WORDS["A7"] = cvc("cat", "hat", "bat", "mat", "sat", "cut", "hit", "pig", "dig", "big", "wig", "bug", "mug", "rug", "hop", "top", "mop", "pop", "bed", "red", "fed", "hen", "ten", "pen", "sun", "run", "fun", "bun")

# --------------------------------------------------------- Band B (letters)


def letter(ch, key, hint):
    return W(ch, ch, hint, s=key, letter=True)


WORDS["B1"] = [
    letter("m", "m", "Mmm, the humming sound."), letter("s", "s", "Sss, the snake sound."),
    letter("f", "f", "Fff, like a cat hissing."), letter("l", "l", "Lll, tongue up."),
    letter("n", "n", "Nnn, the nose sound."), letter("r", "r", "Rrr, like a growl."),
    letter("a", "a", "/a/ as in apple."),
    W("am", "a m", "I am here."), W("an", "a n", "An apple."), W("man", "m a n", "A grown-up boy."),
    W("ran", "r a n", "Ran fast."), W("fan", "f a n", "It blows cool air."), W("ram", "r a m", "A boy sheep."),
]
WORDS["B2"] = [
    letter("t", "t", "Quick /t/."), letter("p", "p", "Pop your lips: /p/."), letter("b", "b", "Bounce your lips: /b/."),
    letter("d", "d", "Tap your tongue: /d/."), letter("c", "k", "c says /k/ as in cat."), letter("g", "g", "/g/ from your throat."),
    letter("h", "h", "A puff of air: /h/."),
    W("tap", "t a p", "Tap with a finger."), W("pat", "p a t", "Pat the dog."), W("bat", "b a t", "It flies at night."),
    W("cab", "c a b", "A taxi."), W("dad", "d a d", "Your father."), W("gap", "g a p", "A space between."),
    W("bag", "b a g", "You carry things in it."), W("hat", "h a t", "You wear it on your head."),
]
WORDS["B3"] = [
    letter("i", "i", "/i/ as in itch."), letter("o", "o", "/o/ as in octopus."),
    W("sit", "s i t", "Sit on a chair."), W("pin", "p i n", "A small sharp pin."), W("hot", "h o t", "Not cold."),
    W("dog", "d o g", "A pet that barks."), W("fig", "f i g", "A sweet fruit."), W("top", "t o p", "The highest part."),
    W("mop", "m o p", "Clean the floor."), W("dig", "d i g", "Make a hole."), W("lip", "l i p", "Part of your mouth."),
    W("pot", "p o t", "You cook soup in it."),
]
WORDS["B4"] = [
    letter("u", "u", "/u/ as in up."), letter("e", "e", "/e/ as in Ed."),
    W("sun", "s u n", "It shines.", sort="u"), W("cup", "c u p", "You drink from it.", sort="u"),
    W("bed", "b e d", "You sleep in it.", sort="e"), W("net", "n e t", "It catches fish.", sort="e"),
    W("bug", "b u g", "A tiny crawling animal.", sort="u"), W("hen", "h e n", "A mother chicken.", sort="e"),
    W("pet", "p e t", "An animal you care for.", sort="e"), W("rug", "r u g", "A small carpet.", sort="u"),
    W("mud", "m u d", "Wet dirt.", sort="u"), W("ten", "t e n", "After nine.", sort="e"),
    W("pin", "p i n", "A small sharp pin.", sort="i", contrast=True), W("big", "b i g", "Not small.", sort="i", contrast=True),
    W("sit", "s i t", "Sit down.", sort="i", contrast=True), W("lid", "l i d", "The top of a pot.", sort="i", contrast=True),
]
WORDS["B5"] = [
    letter("j", "j", "/j/ as in jam."), letter("k", "k", "/k/ as in kit."), letter("v", "v", "/v/ as in van."),
    letter("w", "w", "/w/ as in web."), letter("x", "ks", "x says /ks/ as in box."), letter("y", "y", "/y/ as in yes."),
    letter("z", "z", "/z/ as in zip."),
    W("jam", "j a m", "Sweet fruit spread."), W("kit", "k i t", "A set of tools."), W("van", "v a n", "A big car."),
    W("web", "w e b", "A spider spins it."), W("box", "b o x", "You put things in it."), W("yes", "y e s", "Not no."),
    W("zip", "z i p", "Close your coat."), W("quit", "qu i t", "Stop doing it."), W("fox", "f o x", "A red wild animal."),
    W("wig", "w i g", "Fake hair."),
]
WORDS["B6"] = [
    W("bat", "b a t", "It flies at night.", sort="b"), W("bag", "b a g", "You carry things in it.", sort="b"),
    W("bun", "b u n", "A bread roll.", sort="b"), W("bib", "b i b", "A baby wears it.", sort="b"),
    W("bed", "b e d", "You sleep in it.", sort="b"), W("bug", "b u g", "A tiny crawling animal.", sort="b"),
    W("dog", "d o g", "A pet that barks.", sort="d"), W("dig", "d i g", "Make a hole.", sort="d"),
    W("den", "d e n", "A fox's home.", sort="d"), W("dot", "d o t", "A tiny spot.", sort="d"),
    W("dad", "d a d", "Your father.", sort="d"), W("dip", "d i p", "Dip a chip in sauce.", sort="d"),
    W("pod", "p o d", "Peas grow in it.", sort="p"), W("pup", "p u p", "A baby dog.", sort="p"),
    W("pig", "p i g", "A pink farm animal.", sort="p"), W("pan", "p a n", "You cook in it.", sort="p"),
]

# ------------------------------------------------------- Band C (closed)
WORDS["C1"] = [
    W("at", "a t", "Look at me."), W("in", "i n", "In the box."), W("up", "u p", "Not down."),
    W("cat", "c a t", "A soft pet that says meow."), W("dog", "d o g", "A pet that barks."), W("pig", "p i g", "A pink farm animal."),
    W("sun", "s u n", "It shines in the sky."), W("map", "m a p", "It shows the way."), W("bed", "b e d", "You sleep in it."),
    W("jam", "j a m", "Sweet fruit spread."), W("log", "l o g", "A piece of a fallen tree."), W("hen", "h e n", "A mother chicken."),
    W("web", "w e b", "A spider spins it."), W("top", "t o p", "A spinning toy."), W("box", "b o x", "You put things in it."),
    W("rip", "r i p", "Tear paper in two."), W("cup", "c u p", "You drink from it."), W("fix", "f i x", "Make it work again."),
]
WORDS["C2"] = [
    W("ship", "sh i p", "It sails on the sea."), W("fish", "f i sh", "It swims and has fins."), W("shop", "sh o p", "A place to buy things."),
    W("wish", "w i sh", "You make one on a birthday."), W("chin", "ch i n", "Under your mouth."), W("chop", "ch o p", "Cut with an axe."),
    W("rich", "r i ch", "Lots of gold."), W("much", "m u ch", "A lot."), W("moth", "m o th", "A night insect."),
    W("thin", "th i n", "Not thick."), W("path", "p a th", "A trail to walk on."), W("then", "th e n", "After that.", s="th e n"),
    W("when", "wh e n", "What time?"), W("whip", "wh i p", "Whip the cream."), W("duck", "d u ck", "It quacks."),
    W("sock", "s o ck", "You wear it on your foot."), W("lock", "l o ck", "A key opens it."), W("back", "b a ck", "Behind you."),
    W("kick", "k i ck", "Kick the ball."), W("chick", "ch i ck", "A baby chicken."),
]
WORDS["C3"] = [
    W("puff", "p u ff", "A little blow of air."), W("cuff", "c u ff", "The end of a sleeve."), W("off", "o ff", "Not on."),
    W("bell", "b e ll", "It rings."), W("hill", "h i ll", "A small mountain."), W("doll", "d o ll", "A toy person."),
    W("fell", "f e ll", "Fell down."), W("miss", "m i ss", "Not hit."), W("kiss", "k i ss", "A kiss goodnight."),
    W("mess", "m e ss", "Not tidy."), W("buzz", "b u zz", "The sound a bee makes."), W("fizz", "f i zz", "Bubbles in a drink."),
    W("bus", "b u s", "Rule breaker: only one s.", exception=True, contrast=True), W("if", "i f", "Rule breaker: only one f.", exception=True, contrast=True),
    W("yes", "y e s", "Rule breaker: only one s.", exception=True, contrast=True),
]
WORDS["C4"] = [
    W("stop", "s t o p", "Don't go."), W("flag", "f l a g", "It waves on a pole."), W("crab", "c r a b", "It walks sideways."),
    W("drum", "d r u m", "Bang it with sticks."), W("frog", "f r o g", "It croaks by the pond."), W("grin", "g r i n", "A big smile."),
    W("trap", "t r a p", "It catches things."), W("swim", "s w i m", "Move in water."), W("slip", "s l i p", "Slide and fall."),
    W("plan", "p l a n", "An idea before you start."), W("spin", "s p i n", "Turn round and round."), W("clap", "c l a p", "Clap your hands."),
    W("snap", "s n a p", "A twig goes snap."), W("glad", "g l a d", "Happy."), W("plum", "p l u m", "A purple fruit."),
    W("twin", "t w i n", "Two born together."), W("skip", "s k i p", "Hop on one foot then the other."), W("brim", "b r i m", "The edge of a cup."),
]
WORDS["C5"] = [
    W("hand", "h a n d", "You wave it."), W("fast", "f a s t", "Very quick."), W("lamp", "l a m p", "It gives light."),
    W("milk", "m i l k", "A white drink."), W("tent", "t e n t", "You sleep in it when camping."), W("help", "h e l p", "Lend a hand."),
    W("gift", "g i f t", "A present."), W("jump", "j u m p", "Spring up high."), W("best", "b e s t", "Better than all."),
    W("pond", "p o n d", "A small lake."), W("belt", "b e l t", "It holds up pants."), W("drift", "d r i f t", "Float along."),
    W("stamp", "s t a m p", "Stick it on a letter."), W("crust", "c r u s t", "The edge of bread."),
]
WORDS["C6"] = [
    W("ring", "r ing", "You wear it on a finger."), W("sing", "s ing", "Sing a song."), W("king", "k ing", "He wears a crown."),
    W("rang", "r ang", "The bell rang."), W("fang", "f ang", "A sharp tooth."), W("long", "l ong", "Not short."),
    W("song", "s ong", "Music with words."), W("hung", "h ung", "Hung on a hook."), W("sung", "s ung", "The song was sung."),
    W("rung", "r ung", "A step on a ladder."), W("bank", "b ank", "It keeps money."), W("sink", "s ink", "Wash your hands here."),
    W("pink", "p ink", "A light red colour."), W("junk", "j unk", "Old stuff."), W("ball", "b all", "You kick it."),
    W("tall", "t all", "Not short."), W("wall", "w all", "A side of a room."), W("fall", "f all", "Drop down."),
]
WORDS["C7"] = [
    W("match", "m a tch", "It lights a fire.", family="tch"), W("catch", "c a tch", "Catch the ball.", family="tch"),
    W("fetch", "f e tch", "Go and get it.", family="tch"), W("itch", "i tch", "Scratch it!", family="tch"),
    W("ditch", "d i tch", "A long hole by a road.", family="tch"), W("lunch", "l u n ch", "A meal at noon.", family="tch"),
    W("bench", "b e n ch", "A long seat.", family="tch"), W("pinch", "p i n ch", "A tiny squeeze.", family="tch"),
    W("badge", "b a dge", "A pin you wear.", family="dge"), W("edge", "e dge", "The side of a table.", family="dge"),
    W("fudge", "f u dge", "A sweet treat.", family="dge"), W("bridge", "b r i dge", "It goes over a river.", family="dge"),
    W("hinge", "h i n ge", "A door swings on it.", family="dge"), W("plunge", "p l u n ge", "Dive in.", family="dge"),
]
WORDS["C8"] = [
    SYL("cats", "cat s", "More than one cat.", sort="/s/", unit="morpheme", meaning="more than one"),
    SYL("cups", "cup s", "More than one cup.", sort="/s/", unit="morpheme", meaning="more than one"),
    SYL("maps", "map s", "More than one map.", sort="/s/", unit="morpheme", meaning="more than one"),
    SYL("hats", "hat s", "More than one hat.", sort="/s/", unit="morpheme", meaning="more than one"),
    SYL("dogs", "dog s", "More than one dog.", sort="/z/", unit="morpheme", meaning="more than one"),
    SYL("pigs", "pig s", "More than one pig.", sort="/z/", unit="morpheme", meaning="more than one"),
    SYL("bells", "bell s", "More than one bell.", sort="/z/", unit="morpheme", meaning="more than one"),
    SYL("beds", "bed s", "More than one bed.", sort="/z/", unit="morpheme", meaning="more than one"),
    SYL("boxes", "box es", "More than one box.", sort="/iz/", unit="morpheme", meaning="more than one"),
    SYL("wishes", "wish es", "More than one wish.", sort="/iz/", unit="morpheme", meaning="more than one"),
    SYL("dishes", "dish es", "More than one dish.", sort="/iz/", unit="morpheme", meaning="more than one"),
    SYL("foxes", "fox es", "More than one fox.", sort="/iz/", unit="morpheme", meaning="more than one"),
    SYL("buses", "bus es", "More than one bus.", sort="/iz/", unit="morpheme", meaning="more than one"),
    SYL("benches", "bench es", "More than one bench.", sort="/iz/", unit="morpheme", meaning="more than one"),
]

# --------------------------------------------------- Band D (vowel patterns)
WORDS["D1"] = [
    W("cape", "c a p e", "A hero wears it.", s="k ā p -", closed="cap"), W("cake", "c a k e", "A birthday treat.", s="k ā k -"),
    W("game", "g a m e", "Something you play.", s="g ā m -"), W("lake", "l a k e", "Water with land all around.", s="l ā k -"),
    W("kite", "k i t e", "It flies on a string.", s="k ī t -", closed="kit"), W("bike", "b i k e", "Two wheels and pedals.", s="b ī k -"),
    W("pine", "p i n e", "A tree with needles.", s="p ī n -", closed="pin"), W("hope", "h o p e", "Wish for something.", s="h ō p -", closed="hop"),
    W("rope", "r o p e", "Thick string.", s="r ō p -"), W("home", "h o m e", "Where you live.", s="h ō m -"),
    W("cube", "c u b e", "A box shape.", s="k ū b -", closed="cub"), W("tube", "t u b e", "Toothpaste comes in it.", s="t ū b -", closed="tub"),
    W("note", "n o t e", "A short letter.", s="n ō t -", closed="not"), W("tape", "t a p e", "Sticky strip.", s="t ā p -", closed="tap"),
]
NONSENSE = {
    "D1": ["bape", "lote", "mune", "fide", "jate", "vope", "kime", "nube", "dite", "hute"],
    "C1": ["vop", "jit", "mib", "fot", "lun", "pab", "zed", "gim"],
    "C5": ["damp", "tisk"],  # placeholder, not used
    "R1": ["blim", "chup", "shent", "frob", "glet", "drim", "stog", "thap", "mibe", "rafe", "plake"],
    "E3": [],
}
NONSENSE["C5"] = ["filt", "bomp", "rist", "lunt", "gand", "mesk"]
WORDS["D2"] = [
    W("go", "g o", "Not stop.", s="g ō", syl_type="open"), W("no", "n o", "Not yes.", s="n ō", syl_type="open"),
    W("so", "s o", "So happy.", s="s ō", syl_type="open"), W("me", "m e", "Look at me.", s="m ē", syl_type="open"),
    W("he", "h e", "He is tall.", s="h ē", syl_type="open"), W("she", "sh e", "She is kind.", s="sh ē", syl_type="open"),
    W("we", "w e", "You and me.", s="w ē", syl_type="open"), W("hi", "h i", "Hello!", s="h ī", syl_type="open"),
    W("be", "b e", "Be kind.", s="b ē", syl_type="open"),
    W("got", "g o t", "I got it.", syl_type="closed", contrast=True), W("met", "m e t", "We met.", syl_type="closed", contrast=True),
    W("hit", "h i t", "Hit the ball.", syl_type="closed", contrast=True), W("not", "n o t", "No way.", syl_type="closed", contrast=True),
    W("bed", "b e d", "You sleep in it.", syl_type="closed", contrast=True),
    W("make", "m a k e", "Build it.", s="m ā k -", syl_type="magic e", contrast=True), W("bike", "b i k e", "Two wheels.", s="b ī k -", syl_type="magic e", contrast=True),
]
SYLLABLE_NONSENSE = [
    ("bo", "open"), ("fe", "open"), ("pi", "open"), ("lu", "open"), ("lom", "closed"), ("zat", "closed"),
    ("nib", "closed"), ("pud", "closed"), ("mape", "magic e"), ("vite", "magic e"),
]
WORDS["D3"] = [
    W("rain", "r ai n", "Water from clouds.", family="ai_ay"), W("train", "t r ai n", "It runs on tracks.", family="ai_ay"),
    W("tail", "t ai l", "A dog wags it.", family="ai_ay"), W("play", "p l ay", "Have fun.", family="ai_ay"),
    W("day", "d ay", "Not night.", family="ai_ay"), W("tray", "t r ay", "Carry food on it.", family="ai_ay"),
    W("see", "s ee", "Look with your eyes.", family="ee_ea"), W("tree", "t r ee", "It has leaves.", family="ee_ea"),
    W("feet", "f ee t", "You walk on them.", family="ee_ea"), W("eat", "ea t", "Have food.", family="ee_ea"),
    W("leaf", "l ea f", "It falls from a tree.", family="ee_ea"), W("seat", "s ea t", "A place to sit.", family="ee_ea"),
    W("boat", "b oa t", "It floats.", family="oa_ow"), W("road", "r oa d", "Cars drive on it.", family="oa_ow"),
    W("snow", "s n ow", "Cold and white.", family="oa_ow"), W("grow", "g r ow", "Get bigger.", family="oa_ow"),
    W("night", "n igh t", "When it is dark."), W("light", "l igh t", "It helps you see."),
]
WORDS["D4"] = [
    W("car", "c ar", "You drive it.", family="ar_or"), W("star", "s t ar", "It twinkles at night.", family="ar_or"),
    W("park", "p ar k", "Play on the swings here.", family="ar_or"), W("farm", "f ar m", "Cows live here.", family="ar_or"),
    W("fork", "f or k", "Eat with it.", family="ar_or"), W("corn", "c or n", "Yellow and sweet.", family="ar_or"),
    W("storm", "s t or m", "Wind and rain.", family="ar_or"), W("horn", "h or n", "Beep beep!", family="ar_or"),
    W("her", "h er", "It is her book.", family="er_ir_ur"), W("fern", "f er n", "A leafy plant.", family="er_ir_ur"),
    W("bird", "b ir d", "It flies and sings.", family="er_ir_ur"), W("girl", "g ir l", "A young lady.", family="er_ir_ur"),
    W("shirt", "sh ir t", "You wear it.", family="er_ir_ur"), W("fur", "f ur", "Soft animal hair.", family="er_ir_ur"),
    W("turn", "t ur n", "Go round.", family="er_ir_ur"), W("burn", "b ur n", "Fire can do this.", family="er_ir_ur"),
]
WORDS["D5"] = [
    W("coin", "c oi n", "Money you can hold.", family="oi_oy"), W("boil", "b oi l", "Very hot water.", family="oi_oy"),
    W("soil", "s oi l", "Dirt for plants.", family="oi_oy"), W("boy", "b oy", "A young man.", family="oi_oy"),
    W("toy", "t oy", "Something to play with.", family="oi_oy"), W("joy", "j oy", "Great happiness.", family="oi_oy"),
    W("out", "ou t", "Not in.", family="ou_ow"), W("loud", "l ou d", "Not quiet.", family="ou_ow"),
    W("cloud", "c l ou d", "White and fluffy in the sky.", family="ou_ow"), W("cow", "c ow", "It says moo.", s="k ou", family="ou_ow"),
    W("town", "t ow n", "A small city.", s="t ou n", family="ou_ow"), W("now", "n ow", "Right away.", s="n ou", family="ou_ow"),
    W("saw", "s aw", "A tool that cuts wood.", family="aw_au"), W("paw", "p aw", "A dog's foot.", family="aw_au"),
    W("haul", "h au l", "Pull something heavy.", family="aw_au"), W("moon", "m oo n", "It shines at night."),
    W("book", "b oo k", "You read it.", s="b ŏŏ k"), W("new", "n ew", "Not old."),
]
WORDS["D6"] = [
    W("cat", "c a t", "A pet.", sort="hard c", group="c", contrast=True), W("cup", "c u p", "Drink from it.", sort="hard c", group="c", contrast=True),
    W("cot", "c o t", "A small bed.", sort="hard c", group="c", contrast=True), W("city", "c i t y", "A big town.", s="s i t ē", sort="soft c", group="c"),
    W("cent", "c e n t", "A penny.", s="s e n t", sort="soft c", group="c"), W("face", "f a c e", "Eyes, nose and mouth.", s="f ā s -", sort="soft c", group="c"),
    W("rice", "r i c e", "Small white grains.", s="r ī s -", sort="soft c", group="c"),
    W("gem", "g e m", "A shiny jewel.", s="j e m", sort="soft g", group="g"), W("cage", "c a ge", "A bird lives in it.", s="k ā j", sort="soft g", group="g"),
    W("page", "p a ge", "Part of a book.", s="p ā j", sort="soft g", group="g"), W("gum", "g u m", "You chew it.", sort="hard g", group="g", contrast=True),
    W("gas", "g a s", "Cars need it.", sort="hard g", group="g", contrast=True), W("got", "g o t", "I got it.", sort="hard g", group="g", contrast=True),
    W("my", "m y", "It is my book.", s="m ī", sort="y = /ī/", group="y"), W("fly", "f l y", "Birds can fly.", s="f l ī", sort="y = /ī/", group="y"),
    W("cry", "c r y", "Tears fall when you cry.", s="k r ī", sort="y = /ī/", group="y"),
    W("happy", "h a pp y", "Feeling glad.", s="h a p ē", sort="y = /ē/", group="y"), W("funny", "f u nn y", "It makes you laugh.", s="f u n ē", sort="y = /ē/", group="y"),
    W("puppy", "p u pp y", "A baby dog.", s="p u p ē", sort="y = /ē/", group="y"),
]
WORDS["D7"] = [
    W("knit", "kn i t", "Make a scarf with yarn.", silent=0), W("knot", "kn o t", "Tie a knot.", silent=0),
    W("knee", "kn ee", "It bends your leg.", silent=0), W("write", "wr i t e", "Use a pencil.", s="r ī t -", silent=0),
    W("wrap", "wr a p", "Wrap a present.", silent=0), W("wrist", "wr i s t", "It joins hand and arm.", silent=0),
    W("lamb", "l a mb", "A baby sheep.", silent=2), W("thumb", "th u mb", "Your short finger.", silent=2),
    W("comb", "c o mb", "Tidy your hair.", s="k ō m", silent=2), W("gnat", "gn a t", "A tiny fly.", silent=0),
    W("climb", "c l i mb", "Go up a tree.", s="k l ī m", silent=3),
]

# ------------------------------------------------- Band E (multisyllable)
WORDS["E1"] = [
    SYL("sunset", "sun set", "When the sun goes down."), SYL("catnip", "cat nip", "A plant cats love."),
    SYL("bathtub", "bath tub", "You wash in it."), SYL("hotdog", "hot dog", "Food in a bun."),
    SYL("cupcake", "cup cake", "A little cake."), SYL("sandbox", "sand box", "Play with sand in it."),
    SYL("laptop", "lap top", "A small computer."), SYL("backpack", "back pack", "Carry it on your back."),
    SYL("pigpen", "pig pen", "Where pigs live."), SYL("bedbug", "bed bug", "A tiny bug."),
    SYL("sunfish", "sun fish", "A round fish."), SYL("dishpan", "dish pan", "Wash dishes in it."),
]
WORDS["E2"] = [
    SYL("rabbit", "rab bit", "It hops."), SYL("napkin", "nap kin", "Wipe your mouth."), SYL("picnic", "pic nic", "A meal outside."),
    SYL("magnet", "mag net", "It pulls metal."), SYL("basket", "bas ket", "Carry eggs in it."), SYL("muffin", "muf fin", "A small cake."),
    SYL("kitten", "kit ten", "A baby cat."), SYL("tennis", "ten nis", "A game with rackets."), SYL("insect", "in sect", "A bug with six legs."),
    SYL("puppet", "pup pet", "A toy you move with your hand."), SYL("goblin", "gob lin", "A small monster."), SYL("dentist", "den tist", "A tooth doctor."),
]
WORDS["E3"] = [
    SYL("robot", "ro bot", "A machine that moves."), SYL("tiger", "ti ger", "A big striped cat."), SYL("music", "mu sic", "Songs and tunes."),
    SYL("baby", "ba by", "A very young child."), SYL("paper", "pa per", "You write on it."), SYL("pilot", "pi lot", "Flies a plane."),
    SYL("camel", "cam el", "It has a hump."), SYL("lemon", "lem on", "A sour yellow fruit."), SYL("cabin", "cab in", "A small house in the woods."),
    SYL("wagon", "wag on", "A cart with wheels."), SYL("seven", "sev en", "After six."), SYL("planet", "plan et", "Earth is one."),
]
SPLIT_NONSENSE = [("nabkin", "nab kin"), ("lubnap", "lub nap"), ("pimtod", "pim tod"), ("rofep", "ro fep"), ("tumlid", "tum lid"), ("sidop", "si dop")]
WORDS["E4"] = [
    SYL("table", "ta ble", "You eat at it.", syl_type="consonant-le"), SYL("puddle", "pud dle", "Water on the road.", syl_type="consonant-le"),
    SYL("apple", "ap ple", "A red fruit.", syl_type="consonant-le"), SYL("candle", "can dle", "It has a flame.", syl_type="consonant-le"),
    SYL("bubble", "bub ble", "It floats and pops.", syl_type="consonant-le"), SYL("little", "lit tle", "Small.", syl_type="consonant-le"),
    SYL("simple", "sim ple", "Easy.", syl_type="consonant-le"), SYL("jungle", "jun gle", "A wild forest.", syl_type="consonant-le"),
    SYL("giggle", "gig gle", "A small laugh.", syl_type="consonant-le"), SYL("puzzle", "puz zle", "Fit the pieces together.", syl_type="consonant-le"),
    SYL("waffle", "waf fle", "A breakfast treat.", syl_type="consonant-le"), SYL("pickle", "pick le", "A sour cucumber.", syl_type="consonant-le"),
]
SYLLABLE_SORT_EXTRA = [
    ("cat", "closed"), ("hop", "closed"), ("go", "open"), ("me", "open"), ("bike", "magic e"), ("cake", "magic e"),
    ("rain", "vowel team"), ("boat", "vowel team"), ("car", "r-controlled"), ("fern", "r-controlled"),
    ("ble", "consonant-le"), ("tle", "consonant-le"),
]
WORDS["E5"] = [
    SYL("fantastic", "fan tas tic", "Really great."), SYL("hundred", "hun dred", "Ten tens."), SYL("pumpkin", "pump kin", "A big orange fruit."),
    SYL("important", "im por tant", "It matters a lot."), SYL("umbrella", "um brel la", "Keeps the rain off."), SYL("octopus", "oc to pus", "Eight arms."),
    SYL("hamster", "ham ster", "A small furry pet."), SYL("monster", "mon ster", "A scary creature."), SYL("children", "chil dren", "More than one child."),
    SYL("dragonfly", "drag on fly", "A flying insect."), SYL("fisherman", "fish er man", "He catches fish."), SYL("cucumber", "cu cum ber", "A long green vegetable."),
]
WORDS["E6"] = [
    SYL("about", "a bout", "It is about a dog.", stress=1, schwa=0), SYL("sofa", "so fa", "A soft couch.", stress=0, schwa=1),
    SYL("lemon", "lem on", "A sour fruit.", stress=0, schwa=1), SYL("pencil", "pen cil", "Write with it.", stress=0, schwa=1),
    SYL("panda", "pan da", "A black and white bear.", stress=0, schwa=1), SYL("again", "a gain", "One more time.", stress=1, schwa=0),
    SYL("wagon", "wag on", "A cart.", stress=0, schwa=1), SYL("ago", "a go", "Long ago.", stress=1, schwa=0),
    SYL("alone", "a lone", "By yourself.", stress=1, schwa=0), SYL("salad", "sal ad", "Mixed leaves.", stress=0, schwa=1),
    SYL("balloon", "bal loon", "It floats on a string.", stress=1, schwa=0), SYL("zebra", "ze bra", "A striped horse.", stress=0, schwa=1),
]

# ---------------------------------------------------------- Band F (morphemes)
WORDS["F1"] = [
    SYL("jumped", "jump ed", "Jumped up.", unit="morpheme", sort="/t/", meaning="it already happened"),
    SYL("helped", "help ed", "Helped a friend.", unit="morpheme", sort="/t/", meaning="it already happened"),
    SYL("kicked", "kick ed", "Kicked the ball.", unit="morpheme", sort="/t/", meaning="it already happened"),
    SYL("wished", "wish ed", "Wished on a star.", unit="morpheme", sort="/t/", meaning="it already happened"),
    SYL("played", "play ed", "Played a game.", unit="morpheme", sort="/d/", meaning="it already happened"),
    SYL("filled", "fill ed", "Filled the cup.", unit="morpheme", sort="/d/", meaning="it already happened"),
    SYL("called", "call ed", "Called a friend.", unit="morpheme", sort="/d/", meaning="it already happened"),
    SYL("rained", "rain ed", "It rained all day.", unit="morpheme", sort="/d/", meaning="it already happened"),
    SYL("landed", "land ed", "The plane landed.", unit="morpheme", sort="/id/", meaning="it already happened"),
    SYL("wanted", "want ed", "Wanted a snack.", unit="morpheme", sort="/id/", meaning="it already happened"),
    SYL("rested", "rest ed", "Rested on the bed.", unit="morpheme", sort="/id/", meaning="it already happened"),
    SYL("planted", "plant ed", "Planted a seed.", unit="morpheme", sort="/id/", meaning="it already happened"),
    SYL("jumping", "jump ing", "Jumping now.", unit="morpheme", meaning="happening now"),
    SYL("singing", "sing ing", "Singing a song.", unit="morpheme", meaning="happening now"),
    SYL("reading", "read ing", "Reading a book.", unit="morpheme", meaning="happening now"),
]
RULES = [
    # base, suffix, answer, wrong options, rule, answer split into tiles
    ("hop", "ing", "hopping", ["hoping", "hopeing"], "double", "hop p ing"),
    ("run", "ing", "running", ["runing", "runeing"], "double", "run n ing"),
    ("sit", "ing", "sitting", ["siting", "sitteing"], "double", "sit t ing"),
    ("stop", "ed", "stopped", ["stoped", "stopt"], "double", "stop p ed"),
    ("hope", "ing", "hoping", ["hopeing", "hopping"], "drop e", "hop ing"),
    ("make", "ing", "making", ["makeing", "makking"], "drop e", "mak ing"),
    ("bake", "ed", "baked", ["bakeed", "bakked"], "drop e", "bak ed"),
    ("shine", "ing", "shining", ["shineing", "shinning"], "drop e", "shin ing"),
    ("cry", "ed", "cried", ["cryed", "creid"], "y to i", "cri ed"),
    ("try", "ed", "tried", ["tryed", "treid"], "y to i", "tri ed"),
    ("baby", "es", "babies", ["babys", "babyes"], "y to i", "babi es"),
    ("happy", "ness", "happiness", ["happyness", "hapiness"], "y to i", "happi ness"),
    ("jump", "ing", "jumping", ["jumpping", "jumpeing"], "just add", "jump ing"),
    ("play", "ed", "played", ["plaied", "playd"], "just add", "play ed"),
]
WORDS["F2"] = [SYL(a, t, "%s + %s" % (b, s), unit="morpheme", rule=r, wrong=w, base=b, suffix=s) for (b, s, a, w, r, t) in RULES]
WORDS["F3"] = [
    SYL("unlock", "un lock", "Open with a key.", unit="morpheme", meaning="not locked / opposite of lock", affix="un"),
    SYL("undo", "un do", "Take it back.", unit="morpheme", meaning="opposite of do", affix="un"),
    SYL("unpack", "un pack", "Take things out.", unit="morpheme", meaning="opposite of pack", affix="un"),
    SYL("redo", "re do", "Do it again.", unit="morpheme", meaning="do again", affix="re"),
    SYL("replay", "re play", "Play it again.", unit="morpheme", meaning="play again", affix="re"),
    SYL("reread", "re read", "Read it again.", unit="morpheme", meaning="read again", affix="re"),
    SYL("misspell", "mis spell", "Spell it wrong.", unit="morpheme", meaning="spell wrongly", affix="mis"),
    SYL("mislead", "mis lead", "Lead the wrong way.", unit="morpheme", meaning="lead wrongly", affix="mis"),
    SYL("preheat", "pre heat", "Heat it before.", unit="morpheme", meaning="heat before", affix="pre"),
    SYL("pretest", "pre test", "A test before.", unit="morpheme", meaning="test before", affix="pre"),
    SYL("dislike", "dis like", "Not like.", unit="morpheme", meaning="not like", affix="dis"),
    SYL("distrust", "dis trust", "Not trust.", unit="morpheme", meaning="not trust", affix="dis"),
]
WORDS["F4"] = [
    SYL("helpful", "help ful", "Full of help.", unit="morpheme", meaning="full of help", affix="ful"),
    SYL("painful", "pain ful", "It hurts.", unit="morpheme", meaning="full of pain", affix="ful"),
    SYL("careless", "care less", "Without care.", unit="morpheme", meaning="without care", affix="less"),
    SYL("hopeless", "hope less", "Without hope.", unit="morpheme", meaning="without hope", affix="less"),
    SYL("sadness", "sad ness", "Being sad.", unit="morpheme", meaning="the state of being sad", affix="ness"),
    SYL("kindness", "kind ness", "Being kind.", unit="morpheme", meaning="the state of being kind", affix="ness"),
    SYL("darkness", "dark ness", "Being dark.", unit="morpheme", meaning="the state of being dark", affix="ness"),
    SYL("quickly", "quick ly", "In a quick way.", unit="morpheme", meaning="in a quick way", affix="ly"),
    SYL("softly", "soft ly", "In a soft way.", unit="morpheme", meaning="in a soft way", affix="ly"),
    SYL("fastest", "fast est", "More fast than all.", unit="morpheme", meaning="the most fast", affix="est"),
    SYL("tallest", "tall est", "More tall than all.", unit="morpheme", meaning="the most tall", affix="est"),
    SYL("payment", "pay ment", "Money you pay.", unit="morpheme", meaning="the act of paying", affix="ment"),
]
WORDS["F5"] = [
    SYL("transport", "trans port", "Carry across.", unit="morpheme", root="port", meaning="carry"),
    SYL("import", "im port", "Carry in.", unit="morpheme", root="port", meaning="carry"),
    SYL("export", "ex port", "Carry out.", unit="morpheme", root="port", meaning="carry"),
    SYL("erupt", "e rupt", "Burst out.", unit="morpheme", root="rupt", meaning="break"),
    SYL("interrupt", "inter rupt", "Break in.", unit="morpheme", root="rupt", meaning="break"),
    SYL("tractor", "tract or", "It pulls.", unit="morpheme", root="tract", meaning="pull"),
    SYL("attract", "at tract", "Pull toward.", unit="morpheme", root="tract", meaning="pull"),
    SYL("inspect", "in spect", "Look into.", unit="morpheme", root="spect", meaning="look"),
    SYL("spectator", "spect ator", "Someone who looks on.", unit="morpheme", root="spect", meaning="look"),
    SYL("predict", "pre dict", "Say before.", unit="morpheme", root="dict", meaning="say"),
    SYL("dictate", "dict ate", "Say for someone to write.", unit="morpheme", root="dict", meaning="say"),
    SYL("construct", "con struct", "Build together.", unit="morpheme", root="struct", meaning="build"),
    SYL("instruct", "in struct", "Build knowledge in.", unit="morpheme", root="struct", meaning="build"),
]
WORDS["F6"] = [
    SYL("phonics", "phon ics", "Sounds of letters.", unit="morpheme", root="phon", meaning="sound"),
    SYL("telephone", "tele phone", "Sound from far.", unit="morpheme", root="tele", meaning="far"),
    SYL("telescope", "tele scope", "See far.", unit="morpheme", root="scope", meaning="see"),
    SYL("microscope", "micro scope", "See small things.", unit="morpheme", root="micro", meaning="small"),
    SYL("autograph", "auto graph", "Write your own name.", unit="morpheme", root="graph", meaning="write"),
    SYL("paragraph", "para graph", "Writing beside.", unit="morpheme", root="graph", meaning="write"),
    SYL("photograph", "photo graph", "Write with light.", unit="morpheme", root="photo", meaning="light"),
    SYL("biology", "bio logy", "Study of life.", unit="morpheme", root="bio", meaning="life"),
    SYL("geology", "geo logy", "Study of the earth.", unit="morpheme", root="geo", meaning="earth"),
    SYL("microphone", "micro phone", "Makes small sounds big.", unit="morpheme", root="phone", meaning="sound"),
]

# ------------------------------------------------------------- heart words
# band = the band that needs them; heart = indices of the tricky tiles.
HEART = [
    ("the", "th e", "th ə", [1], "B"), ("a", "a", "ə", [0], "B"), ("I", "I", "ī", [0], "B"),
    ("is", "i s", "i z", [1], "B"), ("his", "h i s", "h i z", [2], "B"), ("of", "o f", "u v", [0, 1], "B"),
    ("to", "t o", "t oo", [1], "B"), ("do", "d o", "d oo", [1], "B"), ("you", "y ou", "y oo", [1], "B"),
    ("said", "s ai d", "s e d", [1], "B"), ("was", "w a s", "w u z", [1, 2], "B"),
    ("who", "wh o", "h oo", [0, 1], "C"), ("what", "wh a t", "w u t", [1], "C"), ("where", "wh ere", "w air", [1], "C"),
    ("from", "f r o m", "f r u m", [2], "C"), ("friend", "f r ie n d", "f r e n d", [2], "C"),
    ("come", "c o m e", "k u m -", [1, 3], "D"), ("some", "s o m e", "s u m -", [1, 3], "D"), ("done", "d o n e", "d u n -", [1, 3], "D"),
    ("have", "h a v e", "h a v -", [3], "D"), ("give", "g i v e", "g i v -", [3], "D"),
    ("great", "g r ea t", "g r ā t", [2], "D"),     ("word", "w or d", "w er d", [1], "D"), ("work", "w or k", "w er k", [1], "D"),
    ("could", "c ou l d", "k ŏŏ - d", [1, 2], "D"), ("would", "w ou l d", "w ŏŏ - d", [1, 2], "D"), ("should", "sh ou l d", "sh ŏŏ - d", [1, 2], "D"),
    ("because", "b e c au s e", "b ē k u z -", [3, 4, 5], "E"), ("people", "p e o p le", "p ē - p ul", [2], "E"),
]
for (w, t, s, h, band) in HEART:
    pass
WORDS["H1"] = [W(w, t, "Heart word: learn the tricky part by heart.", s=s, heart=h, band=band) for (w, t, s, h, band) in HEART]

WORDS["R1"] = []

# ---------------------------------------------------------------- sentences
# (sentence with ___, answer, distractors, band needed)
SENTENCES = [
    ("The cat sat on the ___.", "mat", ["map", "mud"], "C"),
    ("A fish can ___.", "swim", ["sing", "stamp"], "C"),
    ("The duck is in the ___.", "pond", ["pink", "path"], "C"),
    ("I will ring the ___.", "bell", ["belt", "bench"], "C"),
    ("The king has a big ___.", "ring", ["rung", "rug"], "C"),
    ("Dad will ___ the dog.", "fetch", ["fudge", "fizz"], "C"),
    ("The kite is up in the ___.", "sky", ["sea", "sock"], "D"),
    ("We ride on the ___ to the lake.", "boat", ["boot", "bait"], "D"),
    ("The bird sat in the ___.", "tree", ["train", "toy"], "D"),
    ("A cow says ___.", "moo", ["meow", "map"], "D"),
    ("I hope we can ___ a cake.", "bake", ["bike", "book"], "D"),
    ("The rabbit hid in the ___.", "basket", ["bubble", "button"], "E"),
    ("We had a picnic at ___.", "sunset", ["sandbox", "seven"], "E"),
    ("The robot can ___ the box.", "lift", ["lemon", "light"], "E"),
    ("Please ___ the door with the key.", "unlock", ["unpack", "undo"], "F"),
    ("She was ___ to help her friend.", "helpful", ["hopeless", "careless"], "F"),
]

# --------------------------------------------------------------------------
# Spelling families for Which Spelling?
FAMILIES = {
    "k_final": {"options": ["c", "k", "ck"], "rule": "ck right after a short vowel; k after a consonant or vowel team."},
    "floss": {"options": ["f", "ff", "l", "ll", "s", "ss", "z", "zz"], "rule": "Double f, l, s, z after a short vowel."},
    "tch": {"options": ["tch", "ch"], "rule": "tch right after a short vowel; ch after a consonant."},
    "dge": {"options": ["dge", "ge"], "rule": "dge right after a short vowel; ge after a consonant."},
    "ai_ay": {"options": ["ai", "ay"], "rule": "ai in the middle of a word, ay at the end."},
    "ee_ea": {"options": ["ee", "ea"], "rule": "No rule - remember which one the word uses."},
    "oa_ow": {"options": ["oa", "ow"], "rule": "oa in the middle, ow at the end."},
    "ar_or": {"options": ["ar", "or"], "rule": "ar says /ar/, or says /or/."},
    "er_ir_ur": {"options": ["er", "ir", "ur"], "rule": "er, ir and ur all say /er/ - remember which one."},
    "oi_oy": {"options": ["oi", "oy"], "rule": "oi in the middle, oy at the end."},
    "ou_ow": {"options": ["ou", "ow"], "rule": "ou in the middle, ow at the end (or before n)."},
    "aw_au": {"options": ["aw", "au"], "rule": "aw at the end or before n/l; au in the middle."},
    "s_es": {"options": ["s", "es"], "rule": "-es after s, x, z, ch, sh. Otherwise -s."},
}
FLOSS_PAIRS = {"f": "ff", "l": "ll", "s": "ss", "z": "zz", "ff": "f", "ll": "l", "ss": "s", "zz": "z"}


# ============================================================================
def validate():
    errors = []
    stage_ids = [s[0] for s in STAGES]
    for sid, entries in WORDS.items():
        if sid not in stage_ids:
            errors.append("unknown stage %s" % sid)
        seen = set()
        for e in entries:
            w = e["word"]
            if (w, sid) in seen:
                errors.append("%s: duplicate %s" % (sid, w))
            seen.add((w, sid))
            joined = "".join(e["tiles"])
            if joined.lower() != w.lower():
                errors.append("%s: tiles %s spell %r not %r" % (sid, e["tiles"], joined, w))
            if len(e["sounds"]) != len(e["tiles"]):
                errors.append("%s: %s has %d sounds for %d tiles" % (sid, w, len(e["sounds"]), len(e["tiles"])))
    for sid, *_ in STAGES:
        if sid == "R1":
            continue  # sentences + review words drawn from mastered stages
        if sid not in WORDS or len(WORDS[sid]) < 6:
            errors.append("stage %s has fewer than 6 entries" % sid)
    for sent, ans, wrong, band in SENTENCES:
        if "___" not in sent:
            errors.append("sentence without gap: %s" % sent)
    for (b, s, a, w, r, _t) in RULES:
        if a in w:
            errors.append("rule answer listed as wrong: %s" % a)
    return errors


def gd_value(v, indent=0):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(gd_value(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join("%s: %s" % (json.dumps(k), gd_value(x)) for k, x in v.items()) + "}"
    raise TypeError(type(v))


def build():
    stages = []
    for i, (sid, band, zone, name, focus, rule, wand, light, heavy) in enumerate(STAGES):
        stages.append({
            "id": sid, "order": i, "band": band, "zone": zone, "name": name, "focus": focus, "rule": rule,
            "modes": {"wand": wand, "light": light, "heavy": heavy},
        })
    words = {}
    for sid, entries in WORDS.items():
        rows = []
        for e in entries:
            d = dict(e)
            d["stage"] = sid
            rows.append(d)
        words[sid] = rows
    zones = [{"id": z, "key": k, "name": n, "stages": st, "task": t, "boss": b} for (z, k, n, st, t, b) in ZONES]
    sentences = [{"text": s, "answer": a, "wrong": w, "band": b} for (s, a, w, b) in SENTENCES]

    lines = [
        "extends RefCounted",
        "## GENERATED by tools/curriculum/curriculum.py - do not edit by hand.",
        "## Edit the Python file and re-run it; it validates every entry.",
        "",
        "const STAGES: Array = %s" % gd_value(stages),
        "",
        "const ZONES: Array = %s" % gd_value(zones),
        "",
        "const WORDS: Dictionary = {",
    ]
    for sid, rows in words.items():
        lines.append("\t%s: [" % json.dumps(sid))
        for r in rows:
            lines.append("\t\t%s," % gd_value(r))
        lines.append("\t],")
    lines.append("}")
    lines += [
        "",
        "const SENTENCES: Array = %s" % gd_value(sentences),
        "",
        "const NONSENSE: Dictionary = %s" % gd_value(NONSENSE),
        "",
        "const SYLLABLE_NONSENSE: Array = %s" % gd_value([list(x) for x in SYLLABLE_NONSENSE]),
        "",
        "const SYLLABLE_SORT_EXTRA: Array = %s" % gd_value([list(x) for x in SYLLABLE_SORT_EXTRA]),
        "",
        "const SPLIT_NONSENSE: Array = %s" % gd_value([list(x) for x in SPLIT_NONSENSE]),
        "",
        "const FAMILIES: Dictionary = %s" % gd_value(FAMILIES),
        "",
        "const FLOSS_PAIRS: Dictionary = %s" % gd_value(FLOSS_PAIRS),
        "",
    ]
    OUT_GD.parent.mkdir(parents=True, exist_ok=True)
    OUT_GD.write_text("\n".join(lines), encoding="utf-8")

    # ---- audio manifest: every phoneme key and every word the game may say
    keys = {}
    word_list = []
    for sid, rows in words.items():
        for r in rows:
            if r["word"] not in word_list:
                word_list.append(r["word"])
            for snd in r["sounds"]:
                if snd == "-":
                    continue
                k = snd.strip("/")
                keys.setdefault(k, PHONEME_PROMPTS.get(k, k))
            for t in r["tiles"]:
                keys.setdefault(t.lower(), PHONEME_PROMPTS.get(t.lower(), PHONEME_PROMPTS.get(DEFAULT_SOUND.get(t, ""), t)))
    for s in sentences:
        for w in [s["answer"]] + s["wrong"]:
            if w not in word_list:
                word_list.append(w)
    for (w, _t) in SPLIT_NONSENSE:
        word_list.append(w)
    for lst in NONSENSE.values():
        for w in lst:
            if w not in word_list:
                word_list.append(w)
    for (syl, _k) in SYLLABLE_NONSENSE + SYLLABLE_SORT_EXTRA:
        keys.setdefault(syl, PHONEME_PROMPTS.get(syl, syl))
    # rimes for Onset Forge
    for r in ["at", "un", "ig", "op", "ed", "en", "ug", "it", "ut"]:
        keys.setdefault("-" + r, r)
    manifest = {"phonemes": keys, "words": word_list}
    OUT_AUDIO.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    return stages, words


if __name__ == "__main__":
    errs = validate()
    if errs:
        print("\n".join("ERROR " + e for e in errs))
        sys.exit(1)
    st, wd = build()
    n = sum(len(v) for v in wd.values())
    print("ok: %d stages, %d word entries -> %s" % (len(st), n, OUT_GD.relative_to(ROOT)))
