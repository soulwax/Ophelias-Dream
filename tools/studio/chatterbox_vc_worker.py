"""Convert one experimental voice take to Ophelia's approved steady identity."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRATCH = (ROOT / "build/studio/scratch").resolve()
ANCHOR = (ROOT / "tools/voice/ref/steady.wav").resolve()


def main():
    try:
        request = json.loads(sys.stdin.readline())
        source = Path(request["source"]).resolve()
        anchor = Path(request["anchor"]).resolve()
        out = Path(request["out"]).resolve()
        if SCRATCH not in source.parents or source.suffix.lower() != ".wav" or not source.is_file():
            raise ValueError("source must be a WAV preview in studio scratch")
        if anchor != ANCHOR or not anchor.is_file():
            raise ValueError("target must be the approved steady voice reference")
        if SCRATCH not in out.parents or out.suffix.lower() != ".wav":
            raise ValueError("output must stay in studio scratch")

        import soundfile as sf
        import torch
        from chatterbox.vc import ChatterboxVC
        if not torch.cuda.is_available():
            raise RuntimeError("Chatterbox identity conversion requires CUDA")
        converter = ChatterboxVC.from_pretrained(device="cuda")
        generated = converter.generate(str(source), target_voice_path=str(anchor))
        samples = generated.squeeze(0).cpu().numpy().astype("float32")
        out.parent.mkdir(parents=True, exist_ok=True)
        sf.write(out, samples, converter.sr, subtype="PCM_16")
        print(json.dumps({"ok": True, "seconds": round(len(samples) / converter.sr, 2)}), flush=True)
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}), flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
