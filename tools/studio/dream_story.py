"""Read, validate and save the separately authored dream branch story."""
import hashlib
import json
import re
import threading
from copy import deepcopy
from pathlib import Path

from studio import model

STORY_PATH = model.ROOT / "assets/dialogue/dream.json"
BEAT_COUNT = 4  # The dream's four approach beats align with its four movement markers.
MOTION_CUES = {"cut_tree", "delayed_steps", "lantern_witness", "tracks_stop", "tower_gaze", "window_gaze"}
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
    """Validate the runtime schema without stripping fields the editor does not edit."""
    if not isinstance(payload, dict) or payload.get("version") != 1:
        raise ValueError("dream story must use schema version 1")
    _text(payload.get("opening"), "opening", 400, multiline=True)
    _entry(payload.get("journal_cue"), "opening journal cue")
    _text(payload.get("arrival"), "arrival", 240)
    _text(payload.get("question"), "choice prompt", 180)
    _text(payload.get("question_guidance"), "choice guidance", 360)
    _text(payload.get("ending"), "ending", 600, multiline=True)

    beats = payload.get("beats")
    if not isinstance(beats, list) or len(beats) != BEAT_COUNT:
        raise ValueError(f"dream story needs exactly {BEAT_COUNT} movement beats")
    beat_ids = set()
    for index, beat in enumerate(beats, 1):
        if not isinstance(beat, dict):
            raise ValueError(f"beat {index} is invalid")
        _unique_id(beat.get("id"), beat_ids, f"beat {index} id")
        _text(beat.get("text"), f"beat {index}", 600, multiline=True)
        _text(beat.get("motion"), f"beat {index} motion", 40)
        _entry(beat.get("journal"), f"beat {index} journal")

    events = payload.get("events")
    if not isinstance(events, list) or len(events) != 3:
        raise ValueError("dream story needs exactly three trail events")
    event_ids = set()
    previous_offset = -1.0
    for index, event in enumerate(events, 1):
        if not isinstance(event, dict):
            raise ValueError(f"event {index} is invalid")
        _unique_id(event.get("id"), event_ids, f"event {index} id")
        _text(event.get("line"), f"event {index} line", 600, multiline=True)
        if not isinstance(event.get("offset"), (int, float)) or event["offset"] < previous_offset:
            raise ValueError(f"event {index} needs an ascending route offset")
        previous_offset = event["offset"]
        if event.get("motion") and event["motion"] not in MOTION_CUES:
            raise ValueError(f"event {index} has an unsupported movement cue")
        _entry(event.get("journal"), f"event {index} journal")

    rounds = payload.get("small_talk")
    if not isinstance(rounds, list) or len(rounds) > 4:
        raise ValueError("dream story small talk needs at most 4 rounds")
    for round_index, round_data in enumerate(rounds, 1):
        if not isinstance(round_data, dict):
            raise ValueError(f"small-talk round {round_index} is invalid")
        _text(round_data.get("prompt"), f"small-talk round {round_index} prompt", 360)
        _text(round_data.get("guidance"), f"small-talk round {round_index} guidance", 360)
        _choices(round_data.get("choices"), f"small-talk round {round_index}", 2, 4, {"push"})

    event_talk = payload.get("event_talk", {})
    if not isinstance(event_talk, dict):
        raise ValueError("event_talk must map trail events to small-talk rounds")
    if any(event_id not in event_ids or type(round_index) is not int or not 0 <= round_index < len(rounds)
           for event_id, round_index in event_talk.items()):
        raise ValueError("event_talk references an unknown event or small-talk round")

    repair = payload.get("repair")
    if not isinstance(repair, dict):
        raise ValueError("dream story needs a repair conversation")
    _text(repair.get("prompt"), "repair prompt", 360)
    _text(repair.get("guidance"), "repair guidance", 360)
    _choices(repair.get("choices"), "repair", 2, 4, {"repair", "escalate"}, require_advance=False)

    branches = payload.get("branches")
    if not isinstance(branches, list) or not 2 <= len(branches) <= 8:
        raise ValueError("dream story needs between 2 and 8 answer branches")
    branch_ids = set()
    for index, branch in enumerate(branches, 1):
        if not isinstance(branch, dict):
            raise ValueError(f"branch {index} is invalid")
        _unique_id(branch.get("id"), branch_ids, f"branch {index} id")
        _text(branch.get("label"), f"branch {index} choice", 120)
        _text(branch.get("response"), f"branch {index} response", 600, multiline=True)
        _text(branch.get("ophelia"), f"branch {index} Ophelia reflection", 360)
        _text(branch.get("mathilda"), f"branch {index} Mathilda reflection", 360)
        _entry(branch.get("journal"), f"branch {index} journal")

    for outcome_name in ("unresolved", "ruptured"):
        outcome = payload.get(outcome_name)
        if not isinstance(outcome, dict):
            raise ValueError(f"dream story needs a {outcome_name} outcome")
        for field in ("response", "ophelia", "mathilda"):
            _text(outcome.get(field), f"{outcome_name} {field}", 600, multiline=True)
        _entry(outcome.get("journal"), f"{outcome_name} journal")
    # Keep cue, journal and branch metadata intact when Story Studio saves the
    # subset it edits. Older normalization silently deleted these runtime fields.
    return deepcopy(payload)


def _unique_id(value, seen, label):
    ident = _text(value, label, 32)
    if not _ID.fullmatch(ident) or ident in seen:
        raise ValueError(f"{label} needs a unique lowercase id")
    seen.add(ident)


def _entry(value, label):
    if not isinstance(value, dict):
        raise ValueError(f"{label} is invalid")
    _text(value.get("id"), f"{label} id", 32)
    _text(value.get("title"), f"{label} title", 120)
    _text(value.get("text"), f"{label} text", 600, multiline=True)
    _text(value.get("approach"), f"{label} approach", 360, multiline=True)


def _choices(value, label, minimum, maximum, effects, *, require_advance=True):
    if not isinstance(value, list) or not minimum <= len(value) <= maximum:
        raise ValueError(f"{label} needs {minimum} to {maximum} choices")
    for index, choice in enumerate(value, 1):
        if not isinstance(choice, dict):
            raise ValueError(f"{label} choice {index} is invalid")
        _text(choice.get("label"), f"{label} choice {index} label", 180)
        _text(choice.get("response"), f"{label} choice {index} response", 600, multiline=True)
        effect = choice.get("effect", "")
        if effect and effect not in effects:
            raise ValueError(f"{label} choice {index} has an unsupported effect")
        if require_advance and "advance" in choice:
            raise ValueError(f"{label} choice {index} cannot change conversation progression")
        if "advance" in choice and not isinstance(choice["advance"], bool):
            raise ValueError(f"{label} choice {index} advance must be boolean")
        _entry(choice.get("journal"), f"{label} choice {index} journal")


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
