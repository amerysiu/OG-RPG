"""Validate (and optionally trim/normalize) generated phoneme and word WAVs.

Stdlib-only (wave + array), no ffmpeg/pydub needed.

Checks per file:
  - digital silence (peak == 0 or RMS below -50 dBFS)  -> FAIL
  - duration < 80 ms or > 3 s                          -> WARN
  - peak clipping (>= -0.5 dBFS)                       -> WARN

Options:
  --trim       strip leading/trailing silence (keeps 30 ms pad), in place
  --normalize  peak-normalize to -1 dBFS, in place (implies nothing about trim)
  --dirs ...   limit to specific directories (default: audio/phonemes audio/words)

Run from repo root:
  python tools/audio/qa_audio.py
  python tools/audio/qa_audio.py --trim --normalize
"""

import argparse
import array
import math
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SILENCE_DBFS = -50.0
MIN_MS, MAX_MS = 80, 3000
PAD_MS = 30
NORMALIZE_PEAK = int(10 ** (-1.0 / 20) * 32767)  # -1 dBFS


def read_wav(path: Path):
    with wave.open(str(path), "rb") as w:
        params = w.getparams()
        if params.sampwidth != 2 or params.nchannels != 1:
            return None, f"unsupported format ({params.nchannels}ch, {params.sampwidth*8}bit)"
        samples = array.array("h")
        samples.frombytes(w.readframes(params.nframes))
        return (params, samples), None


def write_wav(path: Path, params, samples) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(params.framerate)
        w.writeframes(samples.tobytes())


def dbfs(value: float) -> float:
    if value <= 0:
        return -math.inf
    return 20 * math.log10(value / 32768)


def trim(samples, threshold: int, pad_frames: int):
    start = 0
    end = len(samples)
    while start < end and abs(samples[start]) <= threshold:
        start += 1
    while end > start and abs(samples[end - 1]) <= threshold:
        end -= 1
    start = max(0, start - pad_frames)
    end = min(len(samples), end + pad_frames)
    return samples[start:end]


def normalize(samples, target_peak: int):
    peak = max((abs(s) for s in samples), default=0)
    if peak == 0 or peak <= target_peak:
        return samples
    gain = target_peak / peak
    return array.array("h", (int(s * gain) for s in samples))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dirs", nargs="*", default=["audio/phonemes", "audio/words"])
    ap.add_argument("--trim", action="store_true")
    ap.add_argument("--normalize", action="store_true")
    ap.add_argument("--report", default=str(Path(__file__).with_name("qa_report.md")))
    args = ap.parse_args()

    rows = []
    fails = 0
    warns = 0
    for rel_dir in args.dirs:
        d = ROOT / rel_dir
        if not d.is_dir():
            continue
        for path in sorted(d.glob("*.wav")):
            parsed, err = read_wav(path)
            if err:
                rows.append((path.name, "FAIL", err))
                fails += 1
                continue
            params, samples = parsed
            changed = False
            if args.trim:
                threshold = int(10 ** (SILENCE_DBFS / 20) * 32768)
                trimmed = trim(samples, threshold, int(params.framerate * PAD_MS / 1000))
                if len(trimmed) != len(samples):
                    samples = trimmed
                    changed = True
            if args.normalize:
                normalized = normalize(samples, NORMALIZE_PEAK)
                if normalized is not samples:
                    samples = normalized
                    changed = True
            if changed:
                write_wav(path, params, samples)

            duration_ms = 1000 * len(samples) / params.framerate
            peak = max((abs(s) for s in samples), default=0)
            rms = math.sqrt(sum(float(s) * s for s in samples) / len(samples)) if samples else 0.0
            status = "OK"
            note = f"{duration_ms:6.0f} ms  peak {dbfs(peak):6.1f} dBFS  rms {dbfs(rms):6.1f} dBFS"
            if peak == 0 or dbfs(rms) < SILENCE_DBFS:
                status, note = "FAIL", "silent"
                fails += 1
            elif duration_ms < MIN_MS:
                status, note = "WARN", f"very short ({duration_ms:.0f} ms)"
                warns += 1
            elif duration_ms > MAX_MS:
                status, note = "WARN", f"very long ({duration_ms:.0f} ms)"
                warns += 1
            elif peak >= 32768 * 10 ** (-0.5 / 20):
                status, note = "WARN", note + "  (near clipping)"
                warns += 1
            rows.append((f"{rel_dir}/{path.name}", status, note))

    lines = ["# Audio QA report", ""]
    for name, status, note in rows:
        lines.append(f"- `{status:4s}` **{name}** — {note}")
        print(f"{status:4s} {name}  {note}")
    Path(args.report).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\n{len(rows)} files: {fails} FAIL, {warns} WARN")
    print(f"report: {args.report}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
