"""Bake the reviewed lines with CPU Kokoro; no model runs during gameplay.

Setup and model downloads: docs/VOICE.md. Clips land in assets/audio/voice/.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path

os.environ.setdefault("OMP_NUM_THREADS", "4")

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--voice", default="af_sarah")
    parser.add_argument("--speed", type=float, default=0.92)
    parser.add_argument("--force", action="store_true", help="Re-synthesize clips even if their wav already exists")
    args = parser.parse_args()
    import numpy as np
    import onnxruntime as ort
    import soundfile as sf
    from kokoro_onnx import Kokoro

    models = ROOT / "build/voice/models"
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(models / "kokoro-v1.0.int8.onnx"),
                                   sess_options=options, providers=["CPUExecutionProvider"])
    kokoro = Kokoro.from_session(session, str(models / "voices-v1.0.bin"))
    output = ROOT / "assets/audio/voice"
    output.mkdir(parents=True, exist_ok=True)
    data = json.loads((output / "lines.json").read_text(encoding="utf-8"))
    lines = list(dict.fromkeys([*data["pages"].values(), *data["places"].values(), *data["bored"]]))
    manifest = {"voice": args.voice, "speed": args.speed, "clips": []}
    keep = set()
    for text in lines:
        name = hashlib.sha256(text.encode("utf-8")).hexdigest() + ".wav"
        keep.add(name)
        target = output / name
        if target.exists() and not args.force:
            duration = float(sf.info(target).duration)
        else:
            samples, rate = kokoro.create(text, voice=args.voice, speed=args.speed, lang="en-us")
            if len(samples) == 0 or not np.isfinite(samples).all():
                raise ValueError(f"Invalid speech for {text!r}")
            # Match the project's levelled recordings: loudest 50 ms at -12 dBFS.
            window = max(1, int(rate * 0.05))
            power = np.convolve(samples.astype(np.float64) ** 2,
                                np.ones(window) / window, mode="valid")
            gain = min(10 ** (-12 / 20) / max(float(np.sqrt(power.max())), 1e-8),
                       0.95 / max(float(np.abs(samples).max()), 1e-8))
            sf.write(target, samples * gain, rate, subtype="PCM_16")
            duration = len(samples) / rate
        manifest["clips"].append({"text": text, "file": name, "seconds": duration})
        print(f"{duration:.2f}s {text}", flush=True)
    for old in output.glob("*.wav"):
        if old.name not in keep:
            old.unlink()
            import_file = output / (old.name + ".import")
            if import_file.exists():
                import_file.unlink()
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Baked {len(lines)} clips into {output}")


if __name__ == "__main__":
    main()
