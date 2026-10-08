"""Write one line's text and mood back into its script of record.

Only the span that holds the line changes; everything else in the file,
including its line endings, is left byte for byte. docs/STORY_STUDIO.md,
phase 2. Standard library only.
"""
import re
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
