"""Round-trip test for the studio's writer: for every line in every script,
changing it and changing it back gives the file back byte for byte, and the
changed file differs from the original in exactly that line's rows.

  python tools/studio/test_writers.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio import model, writers  # noqa: E402


def main():
    lines = model.load()
    docs = {}
    checked = skipped = 0
    failures = []
    for line in lines:
        if writers.check(line, "Probe text.", "warm", lines):
            skipped += 1
            continue
        path = writers.doc_path(line)
        original = docs.setdefault(path, writers.read(path))
        mood = "warm" if line.mood != "warm" else "numb"
        try:
            changed = writers.rewrite(original, line, "Probe text.", mood)
            moved = model.Line(**{**line.as_dict(), "text": "Probe text.", "mood": mood})
            back = writers.rewrite(changed, moved, line.text, line.mood)
        except writers.EditError as error:
            failures.append(f"{line.uid}: {error}")
            continue
        rows_before = original.splitlines()
        rows_after = changed.splitlines()
        touched = [i for i, (a, b) in enumerate(zip(rows_before, rows_after)) if a != b]
        expected = 2 if line.chapter == "doorway" else 1
        if back != original:
            failures.append(f"{line.uid}: did not round-trip")
        elif len(rows_before) != len(rows_after) or len(touched) != expected or "Probe text." not in changed:
            failures.append(f"{line.uid}: touched rows {touched}")
        checked += 1

    doorway = next((line for line in lines if line.chapter == "doorway" and line.meta.get("answers") not in ("none", "any")), None)
    if doorway:
        path = writers.doc_path(doorway)
        original = docs.setdefault(path, writers.read(path))
        meta = doorway.meta
        choreography = {
            "speaker": doorway.speaker, "mood": doorway.mood,
            "reaction": meta["reaction"], "answers": meta["answers"], "quote": meta["quote"],
            "intensity": meta["intensity"], "pause": meta["pause"], "overlap": 0.2, "break": True,
        }
        problem = writers.check_dialogue(doorway, choreography, lines)
        if problem:
            failures.append(f"{doorway.uid}: test fixture rejected: {problem}")
        else:
            try:
                changed = writers.rewrite_dialogue(original, doorway, choreography)
                back = writers.rewrite_dialogue(changed, doorway, {
                    "speaker": doorway.speaker, "mood": doorway.mood,
                    "reaction": meta["reaction"], "answers": meta["answers"], "quote": meta["quote"],
                    "intensity": meta["intensity"], "pause": meta["pause"],
                    "overlap": meta.get("overlap", 0), "break": meta.get("break", False),
                })
                if back != original:
                    failures.append(f"{doorway.uid}: choreography did not round-trip")
                elif "Break: yes" not in changed or "Overlap: 0.20" not in changed:
                    failures.append(f"{doorway.uid}: optional choreography fields were not added")
            except writers.EditError as error:
                failures.append(f"{doorway.uid}: choreography rewrite failed: {error}")
        invalid = {**choreography, "quote": "not in the answered line"}
        if not writers.check_dialogue(doorway, invalid, lines):
            failures.append(f"{doorway.uid}: accepted a quote missing from its answer")
    for failure in failures:
        print("FAIL", failure)
    print(f"writers: {checked} lines round-trip, {skipped} not editable here, {len(failures)} failures")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
