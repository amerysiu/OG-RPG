"""Batch-generate audio through a local VoiceStudio backend.

Requires the VoiceStudio app running (backend on http://127.0.0.1:3900).
Uses the OpenAI-compatible endpoint POST /v1/audio/speech with
response_format=wav (no ffmpeg needed).

Examples (run from repo root):
  python tools/audio/generate_audio.py --pilot
  python tools/audio/generate_audio.py --kind phonemes --alts
  python tools/audio/generate_audio.py --kind all
  python tools/audio/generate_audio.py --kind words --voice alloy --speed 0.9

Output:
  audio/phonemes/<grapheme>.wav          (+ <grapheme>~<alt>.wav for alternates)
  audio/words/<word>.wav
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parents[1]
MANIFEST = HERE / "manifest.json"

PILOT_PHONEMES = ["a", "e", "i", "o", "u", "s", "m", "t", "sh", "th"]
PILOT_WORDS = ["cat", "sun", "fish", "chip", "stop", "frog", "map", "plum", "ship", "because"]


def synthesize(base_url: str, model: str, voice: str, text: str,
               speed: float, timeout: float) -> bytes:
    payload = json.dumps({
        "model": model,
        "voice": voice,
        "input": text,
        "response_format": "wav",
        "speed": speed,
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{base_url}/v1/audio/speech",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = resp.read()
    if not data.startswith(b"RIFF"):
        raise RuntimeError(f"response is not a WAV file ({len(data)} bytes)")
    return data


def generate_one(base_url: str, model: str, voice: str, text: str,
                 out_path: Path, speed: float, retries: int, timeout: float,
                 force: bool) -> str:
    if out_path.exists() and not force:
        return "skip"
    last_err: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            data = synthesize(base_url, model, voice, text, speed, timeout)
            out_path.parent.mkdir(parents=True, exist_ok=True)
            tmp = out_path.with_suffix(".wav.tmp")
            tmp.write_bytes(data)
            tmp.replace(out_path)
            return "ok"
        except Exception as err:  # noqa: BLE001 - report any failure, retry
            last_err = err
            if attempt < retries:
                time.sleep(1.5 * attempt)
    print(f"  FAIL {out_path.name}: {last_err}")
    return "fail"


def jobs_for(kind: str, manifest: dict, alts: bool):
    if kind in ("phonemes", "pilot", "all"):
        entries = manifest["phonemes"]
        keys = PILOT_PHONEMES if kind == "pilot" else list(entries)
        for key in keys:
            entry = entries[key]
            yield f"phonemes/{key}.wav", entry["text"], key
            if alts or kind == "pilot":
                for alt in entry.get("alts", []):
                    yield f"phonemes/{key}~{alt}.wav", alt, key
    if kind in ("words", "pilot", "all"):
        entries = manifest["words"]
        keys = PILOT_WORDS if kind == "pilot" else list(entries)
        for key in keys:
            yield f"words/{key}.wav", entries[key]["text"], key


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default="http://127.0.0.1:3900")
    ap.add_argument("--model", default="omnivoice", help="TTS model id (see GET /v1/models)")
    ap.add_argument("--voice", default="alloy", help="Voice name (see GET /v1/audio/voices)")
    ap.add_argument("--speed", type=float, default=1.0)
    ap.add_argument("--kind", choices=["phonemes", "words", "all", "pilot"], default="all")
    ap.add_argument("--alts", action="store_true", help="also generate phoneme alternates")
    ap.add_argument("--out", default=str(ROOT / "audio"), help="output root")
    ap.add_argument("--retries", type=int, default=3)
    ap.add_argument("--timeout", type=float, default=120.0)
    ap.add_argument("--force", action="store_true", help="overwrite existing files")
    args = ap.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    out_root = Path(args.out)

    counts = {"ok": 0, "skip": 0, "fail": 0}
    total = sum(1 for _ in jobs_for(args.kind, manifest, args.alts))
    print(f"generating {total} files via {args.base_url} (model={args.model}, voice={args.voice})")
    for i, (rel, text, _key) in enumerate(jobs_for(args.kind, manifest, args.alts), 1):
        out_path = out_root / rel
        status = generate_one(args.base_url, args.model, args.voice, text,
                              out_path, args.speed, args.retries, args.timeout,
                              args.force)
        counts[status] += 1
        print(f"[{i:3d}/{total}] {status:4s} {rel}  <- {text!r}")

    print(f"done: {counts['ok']} generated, {counts['skip']} skipped, {counts['fail']} failed")
    return 1 if counts["fail"] else 0


if __name__ == "__main__":
    sys.exit(main())
