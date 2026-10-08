"""Curated Hugging Face speech models and their local, ignored cache paths."""
import functools
import shutil
import subprocess

from studio import model

HF_ROOT = model.ROOT / "build/voice/hf"
QWEN_PYTHON = model.ROOT / "build/voice/gpu-venv/Scripts/python.exe"

CATALOG = {
    "qwen-voice-design": {
        "id": "qwen-voice-design",
        "name": "Qwen3 VoiceDesign · 1.7B",
        "repo": "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
        "path": HF_ROOT / "VoiceDesign",
        "size": "4.52 GB",
        "license": "Apache-2.0",
        "mode": "design",
        "role": "Design a consistent voice and direct a specific emotional performance in natural language.",
        "url": "https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
    },
    "qwen-custom-voice": {
        "id": "qwen-custom-voice",
        "name": "Qwen3 CustomVoice · 1.7B",
        "repo": "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice",
        "path": HF_ROOT / "CustomVoice-1.7B",
        "size": "4.52 GB",
        "license": "Apache-2.0",
        "mode": "custom",
        "role": "Keep a selected built-in timbre while directing emotion, pacing and delivery with an instruction.",
        "url": "https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice",
    },
    "qwen-custom-voice-small": {
        "id": "qwen-custom-voice-small",
        "name": "Qwen3 CustomVoice · 0.6B",
        "repo": "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
        "path": HF_ROOT / "CustomVoice-0.6B",
        "size": "2.5 GB",
        "license": "Apache-2.0",
        "mode": "custom-small",
        "role": "A smaller set of built-in timbres for quick voice comparisons; this variant has no instruction control.",
        "url": "https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
    },
}


def is_downloaded(entry):
    return (entry["path"] / "config.json").is_file() and (entry["path"] / "model.safetensors").is_file()


def runtime_ready():
    return QWEN_PYTHON.is_file() and nvidia_available()


@functools.lru_cache(maxsize=1)
def nvidia_available():
    executable = shutil.which("nvidia-smi")
    if not executable:
        return False
    try:
        result = subprocess.run([executable, "-L"], capture_output=True, text=True, timeout=5)
        return result.returncode == 0 and "GPU" in result.stdout
    except (OSError, subprocess.TimeoutExpired):
        return False


def view():
    ready = runtime_ready()
    anchor = model.ROOT / "tools/voice/ref/steady.wav"
    chatterbox_ready = (model.ROOT / "build/voice/cb-venv/Scripts/python.exe").is_file()
    can_unify = chatterbox_ready and anchor.is_file() and nvidia_available()
    rows = []
    for entry in CATALOG.values():
        downloaded = is_downloaded(entry)
        rows.append({key: value for key, value in entry.items() if key not in ("path", "mode")}
                    | {"downloaded": downloaded, "can_try": downloaded and ready,
                       "contextual": entry["mode"] != "custom-small"})
    return {"models": rows, "runtime_ready": ready,
            "runtime_path": "build/voice/gpu-venv" if ready else "",
            "downloader_ready": bool(shutil.which("uv")),
            "chatterbox_ready": chatterbox_ready, "can_unify": can_unify}


def download_action(model_id):
    """Build an argv-only download action from the fixed allow-listed catalog."""
    entry = CATALOG.get(model_id)
    if entry is None:
        raise ValueError("unknown curated model")
    uv = shutil.which("uv")
    if not uv:
        raise RuntimeError("Install uv to download Hugging Face model files.")
    if is_downloaded(entry):
        raise ValueError("this model is already downloaded")
    return {"id": "download-" + model_id, "label": "Download " + entry["name"], "commands": [[
        uv, "tool", "run", "--from", "huggingface_hub", "hf", "download", entry["repo"],
        "--local-dir", str(entry["path"]),
    ]]}
