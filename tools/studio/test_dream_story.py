"""Validation and safe-save checks for the dream's separate branching script."""
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio import dream_story  # noqa: E402


def main():
    story, _ = dream_story.load()
    assert len(story["beats"]) == dream_story.BEAT_COUNT
    assert len(story["branches"]) == 6
    assert len(story["small_talk"]) == 4
    assert len(story["events"]) == 3
    assert story["event_talk"] == {"thread": 0, "window": 1}
    assert len(story["repair"]["choices"]) == 3
    assert {branch["id"] for branch in story["branches"]} == {
        "name", "waiting", "remember", "silence", "walk_beside", "present_need"
    }
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "dream.json"
        path.write_text(json.dumps(story), encoding="utf-8")
        _, original_revision = dream_story.load(path)
        changed_story = {**story, "opening": story["opening"] + " A second breath."}
        saved, next_revision = dream_story.save(changed_story, original_revision, path)
        assert saved == changed_story and next_revision == dream_story.load(path)[1]
        try:
            dream_story.save(story, original_revision, path)
        except dream_story.ConflictError:
            pass
        else:
            raise AssertionError("stale editor overwrote a newer story")
    duplicate = {**story, "branches": [*story["branches"], {**story["branches"][0]}]}
    try:
        dream_story.normalize(duplicate)
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate branch id was accepted")
    incomplete = {**story, "unresolved": {}}
    try:
        dream_story.normalize(incomplete)
    except ValueError:
        pass
    else:
        raise AssertionError("incomplete runtime ending was accepted")
    bad_event = {**story, "event_talk": {"thread": 99}}
    try:
        dream_story.normalize(bad_event)
    except ValueError:
        pass
    else:
        raise AssertionError("invalid event conversation was accepted")
    print("Dream branching script: current schema, metadata round-trip, and stale-save guard checked")


if __name__ == "__main__":
    main()
