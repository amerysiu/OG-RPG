"""Curated TTS prompts for isolated English phonemes, keyed by the grapheme
tile the game plays.

The game plays audio by grapheme name (res://audio/phonemes/<grapheme>.wav),
so every key here is a tile a player may tap. Each key has one or more
candidate synthesis texts; the first is the default, the rest exist for the
pilot listening pass ("a~ah.wav" style alternates when generated with
generate_audio.py --alts).

Notes on the tricky ones:
  - Stop consonants (t, p, k...) need a light schwa ("tuh") or TTS says the
    letter name ("tee"). "tuh" is the standard OG phonics-song convention.
  - Short o /a~:/ in American English overlaps with the "ah" interjection;
    short a /ae/ does not, so "ah" alone is an imperfect match - pilot
    alternates let a human pick.
  - "ai" is only ever used for the /e/ in "said" (og_words.gd ZONE3), so it
    gets the /e/ prompt, not the long-a one.
"""

# grapheme -> list of candidate synthesis texts (first = default)
PROMPTS = {
    # --- short vowels -------------------------------------------------------
    "a": ["ah", "aah", "at"],
    "e": ["eh", "ehh", "ed"],
    "i": ["ih", "ihh", "it"],
    "o": ["o", "oh", "off"],
    "u": ["uh", "uhh", "up"],

    # --- single consonants (continuants: elongated form) --------------------
    "f": ["fff"],
    "l": ["lll"],
    "m": ["mmm"],
    "n": ["nnn"],
    "r": ["rrr"],
    "s": ["sss"],
    "v": ["vvv"],
    "z": ["zzz"],

    # --- single consonants (stops / affricates: light schwa) ----------------
    "b": ["buh"],
    "c": ["kuh"],
    "d": ["duh"],
    "g": ["guh"],
    "h": ["huh", "hhh"],
    "j": ["juh"],
    "k": ["kuh"],
    "p": ["puh"],
    "t": ["tuh"],
    "w": ["wuh"],
    "x": ["ks", "kss"],
    "y": ["yuh", "yoo"],

    # --- digraphs -----------------------------------------------------------
    "sh": ["shh", "shhh"],
    "ch": ["chuh", "ch"],
    "th": ["th", "thh", "thuh"],
    "ck": ["kuh"],
    "ng": ["ng", "ung"],
    "qu": ["qu", "qua"],
    "wh": ["wuh"],

    # --- vowel teams / r-controlled (long sounds) ---------------------------
    "ai": ["eh"],          # only used for /e/ in "said"
    "ay": ["ay", "eye"],
    "ee": ["ee"],
    "ea": ["ee"],
    "oa": ["oh"],
    "ow": ["oh", "ow"],
    "oi": ["oy"],
    "oy": ["oy"],
    "aw": ["aw"],
    "au": ["aw"],
    "er": ["er"],
    "ar": ["ar"],
    "zh": ["zh", "si"],
}


## Single-letter ZONE1 "words" (a, i, m, s, ...) are letter-sound practice,
## not real words - they reuse the phoneme prompt for that letter.
def word_prompt(word: str) -> str:
    w = word.lower()
    if len(w) == 1 and w in PROMPTS:
        return PROMPTS[w][0]
    return w
