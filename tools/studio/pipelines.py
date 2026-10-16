"""Fixed character references and bounded audition controls for Story Studio."""
import json
import hashlib
from pathlib import Path

from . import model


ROOT = model.ROOT
LOCK = ROOT / "tools/voice/voice_lock.json"
OPHELIA_REF = ROOT / "tools/voice/ref"
MATHILDA_REFERENCE_UID = "mathilda/arrival/0"


def reference(character, mood="steady"):
    """Return a repository-owned reference with the words actually spoken in it."""
    if character == "ophelia":
        lock = json.loads(LOCK.read_text(encoding="utf-8"))
        entry = lock["moods"].get(mood)
        if entry is None:
            raise ValueError("unknown Ophelia mood reference")
        path = OPHELIA_REF / f"{mood}.wav"
        text = entry["impression"]
    elif character == "mathilda":
        line = next((item for item in model.load() if item.uid == MATHILDA_REFERENCE_UID), None)
        if line is None or not line.clip_path:
            raise RuntimeError("Mathilda's chapter reference clip is missing")
        path = ROOT / line.clip_path
        text = line.text
    else:
        raise ValueError("choose Ophelia or Mathilda")
    if not path.is_file():
        raise RuntimeError(f"character reference is missing: {path.relative_to(ROOT)}")
    return path, text


def identity_output(source, anchor, scratch):
    """Key a converted take to both recordings so a new voice lock cannot reuse stale audio."""
    digest = hashlib.sha256(source.read_bytes() + b"\0" + anchor.read_bytes()).hexdigest()[:20]
    return scratch / f"{source.stem}-ophelia-{digest}.wav"


def chatter_controls(mood, energy):
    if not isinstance(energy, (int, float)) or isinstance(energy, bool) or not 0.0 <= energy <= 1.0:
        raise ValueError("performance energy must be between 0 and 1")
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    entry = lock["moods"].get(mood)
    if entry is None:
        raise ValueError("unknown performance mood")
    # Keep the approved mood as the center. The experimental dial is deliberately bounded.
    exaggeration = min(1.1, max(0.2, float(entry["exaggeration"]) + (energy - 0.5) * 0.5))
    cfg = min(0.8, max(0.15, float(entry["cfg_weight"]) - (energy - 0.5) * 0.2))
    return {"exaggeration": round(exaggeration, 2), "cfg_weight": round(cfg, 2),
            "temperature": float(entry["temperature"])}
