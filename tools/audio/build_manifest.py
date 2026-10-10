"""Build tools/audio/manifest.json from scripts/og_words.gd.

The manifest is the single source of truth for audio generation:
  - phoneme keys: every grapheme tile a player may tap (entry tiles, level
    distractor pools, confusable neighbours) that has a curated prompt.
  - word keys: every distinct word in the word bank (single-letter
    letter-sound "words" reuse the phoneme prompt).

Run from the repo root:  python tools/audio/build_manifest.py
"""

import json
import re
import sys
from pathlib import Path

from phoneme_prompts import PROMPTS, word_prompt

ROOT = Path(__file__).resolve().parents[2]
OG_WORDS = ROOT / "scripts" / "og_words.gd"
OUT = Path(__file__).with_name("manifest.json")


def tiles_in(src: str) -> set[str]:
    found: set[str] = set()
    for body in re.findall(r'"tiles":\s*\[([^\]]*)\]', src):
        found |= set(re.findall(r'"([^"]+)"', body))
    return found


def words_in(src: str) -> set[str]:
    return set(re.findall(r'"word":\s*"([^"]+)"', src))


def pool_keys(src: str) -> set[str]:
    pools = src.split("LEVEL_POOLS")[1].split("CONFUSABLES")[0]
    conf = src.split("CONFUSABLES")[1].split("##")[0]
    return set(re.findall(r'"([^"]+)"', pools)) | set(
        re.findall(r'"([^"]+)"', conf)
    )


def main() -> int:
    src = OG_WORDS.read_text(encoding="utf-8")

    tapped = tiles_in(src) | pool_keys(src)

    # Multi-letter syllable tiles (pic, nic, play, ...) are spelled units, not
    # phonemes; the game falls back to their first letter today. Skip them.
    phoneme_keys = sorted(k for k in tapped if k in PROMPTS)

    missing = sorted(tapped - set(PROMPTS) - {
        k for k in tapped if len(k) > 2 or (len(k) == 2 and k not in PROMPTS)
    })
    # Report 1-2 letter tapped keys that have no prompt (e.g. blends st/fl).
    blends = sorted(k for k in tapped if k not in PROMPTS and len(k) <= 2)

    words = sorted(w.lower() for w in words_in(src))

    manifest = {
        "source": "scripts/og_words.gd",
        "phonemes": {
            k: {"text": PROMPTS[k][0], "alts": PROMPTS[k][1:]}
            for k in phoneme_keys
        },
        "words": {w: {"text": word_prompt(w)} for w in words},
        "notes": {
            "skipped_blend_tiles": blends,
            "comment": (
                "Blend tiles (st, fl, ...) have no single-phoneme prompt; the "
                "game should play their letters in sequence instead."
            ),
        },
    }

    OUT.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"phoneme keys : {len(phoneme_keys)}")
    print(f"word keys    : {len(words)}")
    print(f"blend tiles (no prompt, skipped): {blends}")
    print(f"written: {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
