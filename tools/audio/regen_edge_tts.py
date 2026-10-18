"""Regenerate phoneme and word audio with Microsoft Edge neural TTS.

Edge-tts is free, sounds far cleaner than the old VoiceStudio clips, and
needs no local model. Run from repo root:

  python tools/audio/regen_edge_tts.py              (only missing clips)
  python tools/audio/regen_edge_tts.py --force      (redo everything)
  python tools/audio/regen_edge_tts.py --kind pilot

The list of clips comes from tools/audio/audio_manifest.json, written by
tools/curriculum/curriculum.py: every phoneme / syllable / rime key the
game can play and every word in the curriculum.

Output matches the layout the game loads:
  audio/phonemes/<grapheme>.wav
  audio/words/<word>.wav
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import wave
from pathlib import Path

import edge_tts
import numpy as np
import soundfile as sf

HERE = Path(__file__).parent
ROOT = HERE.parents[1]

VOICE = "en-US-JennyNeural"
RATE = "-8%"

# Grapheme -> synthesis text. Stops use the light-schwa phonics form so TTS
# does not read the letter name ("tee" instead of /t/). Multi-letter tiles
# (syllable chunks like "cab", blends like "fr") say the chunk itself.
PHONEMES: dict[str, str] = {
    # short vowels
    "a": "ah",
    "e": "eh",
    "i": "ih",
    "o": "aw",
    "u": "uh",
    # long-vowel macron keys used in "sounds" arrays
    "ā": "ay",
    "ē": "ee",
    "ī": "eye",
    "ə": "uh",
    # continuants
    "f": "ffff",
    "l": "llll",
    "m": "mmmm",
    "n": "nnnn",
    "r": "rrrr",
    "s": "ssss",
    "v": "vvvv",
    "z": "zzzz",
    # stops / affricates
    "b": "buh",
    "c": "kuh",
    "d": "duh",
    "g": "guh",
    "h": "huh",
    "j": "juh",
    "k": "kuh",
    "p": "puh",
    "t": "tuh",
    "w": "wuh",
    "x": "ks",
    "ks": "ks",
    "y": "yuh",
    # digraphs
    "sh": "shhh",
    "ch": "chuh",
    "th": "thhh",
    "ck": "kuh",
    # vowel teams seen in the bank
    "ai": "ay",
    "ea": "eee",
    "oa": "oh",
    "ie": "eye",
    # blends
    "fr": "frr",
    "nd": "nd",
    # syllable-chunk tiles (level 4+ words)
    "be": "b ee",
    "bit": "bit",
    "cab": "cab",
    "cause": "cause",
    "ful": "full",
    "help": "help",
    "in": "in",
    "kin": "kin",
    "kind": "kind",
    "mag": "mag",
    "me": "me",
    "mu": "myoo",
    "nap": "nap",
    "ness": "ness",
    "net": "net",
    "nic": "nick",
    "pack": "pack",
    "pic": "pick",
    "play": "play",
    "rab": "rab",
    "re": "ree",
    "read": "read",
    "sad": "sad",
    "set": "set",
    "sic": "sick",
    "sun": "sun",
    "un": "un",
    "ve": "ve",
}

PILOT_PHONEMES = ["a", "e", "i", "o", "u", "s", "m", "t", "sh", "th"]
PILOT_WORDS = ["cat", "sun", "fish", "chip", "stop", "frog", "map", "ship", "because"]


MANIFEST = HERE / "audio_manifest.json"


def manifest() -> dict:
    import json

    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {"phonemes": {}, "words": []}


def words_from_bank() -> list[str]:
    """Every word the game can say (curriculum manifest; legacy fallback)."""
    words = manifest().get("words", [])
    if words:
        return list(dict.fromkeys(w.lower() for w in words))
    text = (ROOT / "scripts" / "og_words.gd").read_text(encoding="utf-8")
    found: list[str] = []
    for line in text.splitlines():
        if '"word":' not in line:
            continue
        rest = line.split('"word":', 1)[1]
        word = rest.split('"', 1)[1].split('"', 1)[0].strip().lower()
        if word and word not in found:
            found.append(word)
    return found


def tiles_from_bank() -> list[str]:
    """Every phoneme / chunk key the game can play (manifest; legacy fallback)."""
    keys = list(manifest().get("phonemes", {}).keys())
    if keys:
        return keys
    import re

    text = (ROOT / "scripts" / "og_words.gd").read_text(encoding="utf-8")
    found: list[str] = []
    for m in re.finditer(r'"tiles":\s*\[([^\]]*)\]', text):
        for t in re.findall(r'"([^"]+)"', m.group(1)):
            if t not in found:
                found.append(t)
    return found


def phoneme_prompt(key: str) -> str:
    if key in PHONEMES:
        return PHONEMES[key]
    return manifest().get("phonemes", {}).get(key, key.lstrip("-"))


def word_prompt(word: str) -> str:
    # Single-letter "words" (zone 1) are letter-sound practice, not the
    # article "a" / pronoun "i" — reuse the phoneme prompt.
    if len(word) == 1 and word in PHONEMES:
        return PHONEMES[word]
    return word


def postprocess(src: Path, dst: Path) -> tuple[int, float]:
    """Trim silence, normalize peak, write 22.05 kHz mono 16-bit WAV."""
    data, rate = sf.read(src, always_2d=False)
    if data.ndim > 1:
        data = data.mean(axis=1)
    data = data.astype(np.float64)

    # Absolute gate around 5% of peak so room noise does not count as speech.
    peak = float(np.max(np.abs(data))) or 1.0
    gate = peak * 0.05
    idx = np.where(np.abs(data) > gate)[0]
    if idx.size == 0:
        return 0, 0.0
    start = max(0, int(idx[0]) - int(rate * 0.02))
    end = min(len(data), int(idx[-1]) + int(rate * 0.06))
    data = data[start:end]

    # Gentle fade so clicks never survive.
    fade = int(rate * 0.01)
    if len(data) > fade * 2:
        data[:fade] *= np.linspace(0, 1, fade)
        data[-fade:] *= np.linspace(1, 0, fade)

    # Peak-normalize to -1.5 dBFS with a little headroom.
    peak = float(np.max(np.abs(data))) or 1.0
    data = data * (10 ** (-1.5 / 20.0)) / peak

    # Resample to 22050 with linear interp (adequate for speech tiles).
    if rate != 22050:
        duration = len(data) / rate
        n_out = max(1, int(round(duration * 22050)))
        x_old = np.linspace(0.0, duration, num=len(data), endpoint=False)
        x_new = np.linspace(0.0, duration, num=n_out, endpoint=False)
        data = np.interp(x_new, x_old, data)
        rate = 22050

    pcm = np.clip(data * 32767.0, -32768, 32767).astype(np.int16)
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.with_suffix(".wav.tmp")
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    tmp.replace(dst)
    return int(idx[-1] - idx[0]), duration_ms(data, rate)


def duration_ms(data: np.ndarray, rate: int) -> float:
    return len(data) / rate * 1000.0


async def synth_one(text: str, path: Path, voice: str, rate: str, retries: int = 3) -> bool:
    raw = path.with_suffix(".raw.tmp")
    for attempt in range(1, retries + 1):
        try:
            communicate = edge_tts.Communicate(text, voice=voice, rate=rate)
            await communicate.save(str(raw))
            if not raw.exists() or raw.stat().st_size < 200:
                raise RuntimeError("empty synthesis")
            postprocess(raw, path)
            raw.unlink(missing_ok=True)
            return True
        except Exception as err:  # noqa: BLE001
            if attempt == retries:
                shown = str(path.name).encode("ascii", "replace").decode("ascii")
                print(f"  FAIL {shown}: {err}")
                raw.unlink(missing_ok=True)
                return False
            await asyncio.sleep(0.4 * attempt)
    return False


async def run_jobs(jobs: list[tuple[Path, str]], voice: str, rate: str) -> int:
    ok = 0
    total = len(jobs)
    sem = asyncio.Semaphore(4)

    async     def one(path: Path, text: str, i: int) -> bool:
        async with sem:
            good = await synth_one(text, path, voice, rate)
            mark = "ok" if good else "FAIL"
            shown = str(path.relative_to(ROOT)).encode("ascii", "replace").decode("ascii")
            print(f"[{i:3d}/{total}] {mark:4s} {shown}  <- {text!r}")
            return good

    results = await asyncio.gather(*(one(p, t, i) for i, (p, t) in enumerate(jobs, 1)))
    ok = sum(1 for r in results if r)
    print(f"done: {ok}/{total} ok")
    return 0 if ok == total else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kind", choices=["phonemes", "words", "all", "pilot"], default="all")
    ap.add_argument("--voice", default=VOICE)
    ap.add_argument("--rate", default=RATE)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    jobs: list[tuple[Path, str]] = []
    if args.kind in ("phonemes", "all", "pilot"):
        if args.kind == "pilot":
            keys = PILOT_PHONEMES
        else:
            keys = list(dict.fromkeys([*PHONEMES, *tiles_from_bank()]))
        for key in keys:
            path = ROOT / "audio" / "phonemes" / f"{key}.wav"
            if args.force or not path.exists():
                jobs.append((path, phoneme_prompt(key)))
    if args.kind in ("words", "all", "pilot"):
        if args.kind == "pilot":
            words = PILOT_WORDS
        else:
            words = words_from_bank()
        for word in words:
            path = ROOT / "audio" / "words" / f"{word}.wav"
            if args.force or not path.exists():
                jobs.append((path, word_prompt(word)))

    print(f"edge-tts {args.voice} rate={args.rate} -> {len(jobs)} files")
    return asyncio.run(run_jobs(jobs, args.voice, args.rate))


if __name__ == "__main__":
    sys.exit(main())
