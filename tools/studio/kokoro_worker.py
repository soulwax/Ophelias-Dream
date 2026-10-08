"""A long-lived Kokoro process for the studio's voice lab.

Runs in build/voice/venv (kokoro_onnx, onnxruntime, soundfile). Reads one JSON
request per line on stdin and answers one JSON line on stdout:
  {"text": ..., "voice": "af_bella", "speed": 0.94, "out": "<wav path>"} -> {"ok": true, "seconds": 2.1}
  {"voices": true} -> {"voices": [...]}
The model loads once, so a reading takes about as long as it lasts.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    import numpy as np
    import onnxruntime as ort
    import soundfile as sf
    from kokoro_onnx import Kokoro
    models = ROOT / "build/voice/models"
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    session = ort.InferenceSession(str(models / "kokoro-v1.0.int8.onnx"), sess_options=options,
                                   providers=["CPUExecutionProvider"])
    kokoro = Kokoro.from_session(session, str(models / "voices-v1.0.bin"))
    print(json.dumps({"ready": True}), flush=True)
    for raw in sys.stdin:
        try:
            request = json.loads(raw)
            if request.get("voices"):
                print(json.dumps({"voices": sorted(kokoro.get_voices())}), flush=True)
                continue
            samples, rate = kokoro.create(request["text"], voice=request.get("voice", "af_bella"),
                                          speed=float(request.get("speed", 0.94)), lang="en-us")
            samples = np.asarray(samples, dtype=np.float32)
            out = Path(request["out"])
            out.parent.mkdir(parents=True, exist_ok=True)
            sf.write(out, samples, rate, subtype="PCM_16")
            print(json.dumps({"ok": True, "seconds": round(len(samples) / rate, 2)}), flush=True)
        except Exception as error:  # one bad request must not end the lab
            print(json.dumps({"ok": False, "error": str(error)}), flush=True)


if __name__ == "__main__":
    main()
