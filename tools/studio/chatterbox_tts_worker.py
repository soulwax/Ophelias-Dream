"""One experimental Chatterbox TTS take from a fixed character reference."""
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRATCH = (ROOT / "build/studio/scratch").resolve()


def main():
    try:
        request = json.loads(sys.stdin.readline())
        reference = Path(request["reference"]).resolve()
        output = Path(request["out"]).resolve()
        approved = ((ROOT / "tools/voice/ref").resolve(),
                    (ROOT / "assets/audio/voice/mathilda").resolve())
        if not any(reference.is_relative_to(folder) for folder in approved) or not reference.is_file():
            raise ValueError("reference must be a project character clip")
        if not output.is_relative_to(SCRATCH) or output.suffix.lower() != ".wav":
            raise ValueError("output must stay in the studio scratch folder")
        import soundfile as sf
        import torch
        from chatterbox.tts import ChatterboxTTS
        if not torch.cuda.is_available():
            raise RuntimeError("Chatterbox direct previews require CUDA")
        torch.manual_seed(int(request["seed"]))
        engine = ChatterboxTTS.from_pretrained(device="cuda")
        generated = engine.generate(str(request["text"]), audio_prompt_path=str(reference),
            exaggeration=float(request["exaggeration"]), cfg_weight=float(request["cfg_weight"]),
            temperature=float(request["temperature"]))
        samples = generated.squeeze(0).cpu().numpy().astype("float32")
        output.parent.mkdir(parents=True, exist_ok=True)
        sf.write(output, samples, engine.sr, subtype="PCM_16")
        print(json.dumps({"ok": True, "seconds": round(len(samples) / engine.sr, 2)}), flush=True)
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}), flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
