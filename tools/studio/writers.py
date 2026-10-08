"""Write one line's text and mood back into its script of record.

Only the span that holds the line changes; everything else in the file,
including its line endings, is left byte for byte. docs/STORY_STUDIO.md,
phase 2. Standard library only.
"""
import re
import json
from pathlib import Path

from studio import model

ROW = re.compile(r"^\| ([a-z]\d\d) \| (ophelia|mathilda) \| ([a-z]+) \| (.+) \|$")
# Each chapter's table is regenerated from its script by these (cwd = repo root).
TABLE_WRITERS = {
    "ophelia": ["tools/script_to_lines.py"],
    "mathilda": ["tools/bake_mathilda.py", "--write"],
    "lake": ["tools/bake_lake.py", "--write"],
    "doorway": ["tools/bake_meeting.py", "--write"],
}


class EditError(ValueError):
    pass


def check(line, text, mood, lines):
    """Why this edit can't be written, or "" if it can."""
    if mood not in model.MOODS:
        return f"'{mood}' is not one of the 14 moods"
    if not text or text != text.strip():
        return "the text is empty or has spaces at its ends"
    if "\n" in text or "\r" in text:
        return "one line only: no line breaks"
    if line.chapter == "lake" and "|" in text:
        return "the lake script is a table: no '|' in the text"
    if not line.source:
        return "this line could not be found in its script"
    shared = [other.uid for other in lines if other is not line and other.source == line.source]
    if shared:
        return f"this script line is shared with {', '.join(shared)}; edit it by hand"
    return ""


def check_dialogue(line, dialogue, lines):
    """Validate the doorway choreography fields before changing its script."""
    if line.chapter != "doorway":
        return "dialogue choreography is only available for doorway lines"
    reaction = str(dialogue.get("reaction", "")).strip()
    speaker = str(dialogue.get("speaker", ""))
    answers = str(dialogue.get("answers", "")).strip()
    quote = str(dialogue.get("quote", "")).strip()
    try:
        intensity = float(dialogue.get("intensity"))
        pause = float(dialogue.get("pause"))
        overlap = float(dialogue.get("overlap"))
    except (TypeError, ValueError):
        return "intensity, pause and overlap must be numbers"
    if not reaction or any(ch in reaction for ch in "\r\n"):
        return "Action / reaction must be one non-empty line"
    if speaker not in ("ophelia", "mathilda"):
        return "speaker must be Ophelia or Mathilda"
    if any(ch in quote for ch in '\r\n"'):
        return 'the answer quote cannot contain a line break or a double quote'
    if not 0.0 <= intensity <= 1.0:
        return "intensity must be between 0 and 1"
    if not 0.0 <= pause <= 5.0:
        return "pause must be between 0 and 5 seconds"
    if not 0.0 <= overlap <= 3.0:
        return "overlap must be between 0 and 3 seconds"
    if answers not in ("none", "any"):
        answered = next((other for other in lines if other.chapter == "doorway" and other.uid.endswith("/" + answers)), None)
        if answered is None:
            return f"Answers must name a doorway line, not '{answers}'"
        if answered.uid == line.uid:
            return "a line cannot answer itself"
        if not quote or quote not in answered.text:
            return "the answer quote must appear in the line it answers"
    elif answers == "none":
        tree = json.loads((model.ROOT / "assets/dialogue/meeting.json").read_text(encoding="utf-8"))
        opening = tree["nodes"][tree["start"]]["say"][0]
        if line.uid.rsplit("/", 1)[-1] != opening:
            return f"only the opening line ({opening}) can answer none"
    return ""


def rewrite(document, line, text, mood):
    """The document with this one line changed. Raises EditError if the file
    no longer holds the line where the model says it is."""
    newline = "\r\n" if "\r\n" in document else "\n"
    rows = document.split(newline)
    index = int(line.source.rsplit(":", 1)[1]) - 1
    if index >= len(rows):
        raise EditError("the script has changed since it was read; reload")
    row = rows[index]
    if line.chapter in ("ophelia", "mathilda"):
        tail = f"[{line.mood}] {line.text}"
        if not row.rstrip().endswith(tail):
            raise EditError("the script has changed since it was read; reload")
        at = row.rindex(tail)
        rows[index] = row[:at] + f"[{mood}] {text}" + row[at + len(tail):]
    elif line.chapter == "lake":
        found = ROW.match(row.strip())
        if not found or found[1] != line.uid.split("/")[-1] or found[4].strip() != line.text:
            raise EditError("the script has changed since it was read; reload")
        rows[index] = row.replace(f"| {found[3]} | {found[4]} |", f"| {mood} | {text} |", 1)
    elif line.chapter == "doorway":
        ident = line.uid.split("/")[-1]
        if row != f"> {line.text}":
            raise EditError("the script has changed since it was read; reload")
        head = next((i for i in range(index, -1, -1) if rows[i].startswith(f"### {ident} |")), -1)
        if head < 0:
            raise EditError(f"no heading for {ident} above its text")
        parts = rows[head].split(" | ")
        if len(parts) != 4 or parts[2] != line.mood:
            raise EditError(f"the heading for {ident} is not '### id | speaker | mood | pause'")
        parts[2] = mood
        rows[head] = " | ".join(parts)
        rows[index] = f"> {text}"
    else:
        raise EditError(f"unknown chapter {line.chapter}")
    return newline.join(rows)


def rewrite_dialogue(document, line, dialogue):
    """Rewrite only the doorway line's choreography block."""
    newline = "\r\n" if "\r\n" in document else "\n"
    rows = document.split(newline)
    ident = line.uid.split("/")[-1]
    head = next((i for i, row in enumerate(rows) if row.startswith(f"### {ident} |")), -1)
    end = next((i for i in range(head + 1, len(rows)) if rows[i].startswith("### ") or rows[i].startswith("## ")), len(rows)) if head >= 0 else -1
    text_index = next((i for i in range(head + 1, end) if rows[i] == f"> {line.text}"), -1) if head >= 0 else -1
    if head < 0 or text_index < 0:
        raise EditError("the script has changed since it was read; reload")
    parts = rows[head].split(" | ")
    if len(parts) != 4 or not parts[0].startswith("### "):
        raise EditError(f"the heading for {ident} is not '### id | speaker | mood | pause'")
    try:
        pause = float(dialogue["pause"])
        intensity = float(dialogue["intensity"])
        overlap = float(dialogue["overlap"])
    except (KeyError, TypeError, ValueError) as error:
        raise EditError("incomplete dialogue choreography") from error
    parts[1] = str(dialogue["speaker"])
    parts[2] = str(dialogue["mood"])
    parts[3] = f"{pause:.2f}"
    rows[head] = " | ".join(parts)

    block = rows[head + 1:end]

    def replace(prefix, value):
        found = next((i for i, row in enumerate(block) if row.startswith(prefix)), None)
        if found is None:
            return False
        block[found] = value
        return True

    def insert_field(value):
        at = next((i for i, row in enumerate(block) if row.startswith("> ")), len(block))
        block.insert(at, value)

    reaction = str(dialogue["reaction"]).strip().rstrip(".")
    reaction_text = reaction if reaction.endswith((".", "!", "?")) else reaction + "."
    answers = str(dialogue["answers"]).strip()
    quote = str(dialogue.get("quote", "")).strip()
    replace("Action / reaction: ", f"Action / reaction: {reaction_text}")
    replace("Answers: ", f'Answers: {answers}' + (f' "{quote}"' if quote else ""))
    replace("Intensity: ", f"Intensity: {intensity:.2f}")
    has_break = replace("Break: ", "Break: yes")
    if dialogue.get("break") and not has_break:
        insert_field("Break: yes")
    elif not dialogue.get("break") and has_break:
        block.remove("Break: yes")
    has_overlap = replace("Overlap: ", f"Overlap: {overlap:.2f}")
    if overlap > 0 and not has_overlap:
        insert_field(f"Overlap: {overlap:.2f}")
    elif overlap == 0 and has_overlap:
        block.remove(f"Overlap: {overlap:.2f}")
    rows[head + 1:end] = block
    return newline.join(rows)


def diff(before, after, name):
    import difflib
    return "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                        f"a/{name}", f"b/{name}", n=1))


def read(path):
    with open(path, encoding="utf-8", newline="") as handle:
        return handle.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def doc_path(line):
    return model.ROOT / model.CHAPTERS[line.chapter]["doc"]


def quoted_by(line, lines):
    """Doorway lines whose 'Answers' quote this line: editing its words can break them."""
    ident = line.uid.split("/")[-1]
    return [other for other in lines if other.chapter == "doorway" and other.meta.get("answers") == ident
            and other.meta.get("quote")]
