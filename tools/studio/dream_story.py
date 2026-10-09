"""Read, validate and save the separately authored dream branch story."""
import hashlib
import json
import re
import threading
from pathlib import Path

from studio import model

STORY_PATH = model.ROOT / "assets/dialogue/dream.json"
BEAT_COUNT = 4  # The dream's four approach beats align with its four movement markers.
_ID = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")
_LOCK = threading.Lock()


class ConflictError(ValueError):
    """The story changed on disk since the editor loaded it."""


def _text(value, label, limit, *, multiline=False):
    if not isinstance(value, str):
        raise ValueError(f"{label} must be text")
    value = value.strip()
    if not value:
        raise ValueError(f"{label} cannot be empty")
    if len(value) > limit:
        raise ValueError(f"{label} is longer than {limit} characters")
    if not multiline and ("\n" in value or "\r" in value):
        raise ValueError(f"{label} must stay on one line")
    return value


def normalize(payload):
    """Return a bounded story document safe for both the editor and game."""
    if not isinstance(payload, dict) or payload.get("version") != 1:
        raise ValueError("dream story must use schema version 1")
    opening = _text(payload.get("opening"), "opening", 400, multiline=True)
    raw_beats = payload.get("beats")
    if not isinstance(raw_beats, list) or len(raw_beats) != BEAT_COUNT:
        raise ValueError(f"dream story needs exactly {BEAT_COUNT} movement beats")
    beats, beat_ids = [], set()
    for index, beat in enumerate(raw_beats, 1):
        if not isinstance(beat, dict):
            raise ValueError(f"beat {index} is invalid")
        ident = _text(beat.get("id"), f"beat {index} id", 32)
        if not _ID.fullmatch(ident) or ident in beat_ids:
            raise ValueError(f"beat {index} needs a unique lowercase id")
        beat_ids.add(ident)
        beats.append({"id": ident, "text": _text(beat.get("text"), f"beat {index}", 240)})
    raw_small_talk = payload.get("small_talk", [])
    if not isinstance(raw_small_talk, list) or len(raw_small_talk) > 3:
        raise ValueError("dream story small talk needs at most 3 rounds")
    small_talk = []
    for round_index, round_data in enumerate(raw_small_talk, 1):
        if not isinstance(round_data, dict):
            raise ValueError(f"small-talk round {round_index} is invalid")
        raw_choices = round_data.get("choices")
        if not isinstance(raw_choices, list) or not 2 <= len(raw_choices) <= 4:
            raise ValueError(f"small-talk round {round_index} needs 2 to 4 choices")
        choices = []
        for choice_index, choice in enumerate(raw_choices, 1):
            if not isinstance(choice, dict):
                raise ValueError(f"small-talk choice {choice_index} in round {round_index} is invalid")
            choices.append({
                "label": _text(choice.get("label"), f"small-talk round {round_index} choice {choice_index}", 120),
                "response": _text(choice.get("response"), f"small-talk round {round_index} reply {choice_index}", 240),
            })
        small_talk.append({
            "prompt": _text(round_data.get("prompt"), f"small-talk round {round_index} prompt", 180),
            "choices": choices,
        })
    raw_branches = payload.get("branches")
    if not isinstance(raw_branches, list) or not 2 <= len(raw_branches) <= 8:
        raise ValueError("dream story needs between 2 and 8 answer branches")
    branches, branch_ids = [], set()
    for index, branch in enumerate(raw_branches, 1):
        if not isinstance(branch, dict):
            raise ValueError(f"branch {index} is invalid")
        ident = _text(branch.get("id"), f"branch {index} id", 32)
        if not _ID.fullmatch(ident) or ident in branch_ids:
            raise ValueError(f"branch {index} needs a unique lowercase id")
        branch_ids.add(ident)
        branches.append({
            "id": ident,
            "label": _text(branch.get("label"), f"branch {index} choice", 120),
            "response": _text(branch.get("response"), f"branch {index} response", 360, multiline=True),
            "ophelia": _text(branch.get("ophelia"), f"branch {index} Ophelia reflection", 360),
            "mathilda": _text(branch.get("mathilda"), f"branch {index} Mathilda reflection", 360),
        })
    return {
        "version": 1,
        "opening": opening,
        "beats": beats,
        "arrival": _text(payload.get("arrival"), "arrival", 240),
        "small_talk": small_talk,
        "question": _text(payload.get("question"), "choice prompt", 180),
        "branches": branches,
        "ending": _text(payload.get("ending", payload.get("arrival")), "ending", 360),
    }


def _read(path):
    raw = path.read_bytes()
    story = normalize(json.loads(raw.decode("utf-8")))
    return story, hashlib.sha256(raw).hexdigest()


def load(path=STORY_PATH):
    return _read(Path(path))


def save(payload, expected_revision, path=STORY_PATH):
    """Validate and atomically write; reject stale editors instead of clobbering."""
    path = Path(path)
    story = normalize(payload)
    with _LOCK:
        _, current_revision = _read(path)
        if expected_revision != current_revision:
            raise ConflictError("The dream story changed on disk. Reload it before saving your edits.")
        encoded = (json.dumps(story, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_bytes(encoded)
        temporary.replace(path)
    return story, hashlib.sha256(encoded).hexdigest()
