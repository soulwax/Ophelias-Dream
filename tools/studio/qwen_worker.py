"""Warm Qwen3-TTS preview process used only by Story Studio's voice lab."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
loaded_path = None
model = None


def load(model_path):
    global loaded_path, model
    resolved = Path(model_path).resolve()
    allowed = (ROOT / "build/voice/hf").resolve()
    if allowed not in resolved.parents:
        raise ValueError("model path must be inside build/voice/hf")
    if not (resolved / "config.json").is_file() or not (resolved / "model.safetensors").is_file():
        raise FileNotFoundError(f"model files are incomplete at {resolved}")
    if loaded_path == resolved and model is not None:
        return model
    import torch
    from qwen_tts import Qwen3TTSModel
    model = Qwen3TTSModel.from_pretrained(
        str(resolved), device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
    loaded_path = resolved
    return model


def main():
    import soundfile as sf
    import torch
    print(json.dumps({"ready": torch.cuda.is_available()}), flush=True)
    for raw in sys.stdin:
        try:
            request = json.loads(raw)
            if not torch.cuda.is_available():
                raise RuntimeError("Qwen preview needs the NVIDIA GPU runtime.")
            engine = load(request["model_path"])
            text = str(request["text"]).strip()
            instruction = str(request.get("instruction", "")).strip()
            seed = int(request.get("seed", 1))
            temperature = float(request.get("temperature", 0.85))
            torch.manual_seed(seed)
            torch.cuda.manual_seed_all(seed)
            kind = request["mode"]
            if kind == "design":
                wavs, rate = engine.generate_voice_design(
                    text=text, language="English", instruct=instruction, max_new_tokens=384,
                    do_sample=True, temperature=temperature)
            elif kind in ("custom", "custom-small"):
                wavs, rate = engine.generate_custom_voice(
                    text=text, language="English", speaker=request.get("speaker", "Serena"),
                    instruct=instruction if kind == "custom" else None, max_new_tokens=384,
                    do_sample=True, temperature=temperature)
            else:
                raise ValueError(f"unsupported Qwen model mode: {kind}")
            out = Path(request["out"]).resolve()
            if (ROOT / "build/studio/scratch").resolve() not in out.parents:
                raise ValueError("preview output must stay in build/studio/scratch")
            out.parent.mkdir(parents=True, exist_ok=True)
            sf.write(out, wavs[0], rate, subtype="PCM_16")
            print(json.dumps({"ok": True, "seconds": round(len(wavs[0]) / rate, 2)}), flush=True)
        except Exception as error:
            print(json.dumps({"ok": False, "error": str(error)}), flush=True)


if __name__ == "__main__":
    main()
