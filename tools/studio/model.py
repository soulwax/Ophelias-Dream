"""Every spoken line in the game as one model, with the state of its clip.

Reads the generated tables (each is kept in step with its script of record by
that tool's --check) and the clip folders; standard library only, so it runs
anywhere. docs/STORY_STUDIO.md, section 4.
"""
import hashlib
import json
from dataclasses import dataclass, field, asdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VOICE = ROOT / "assets/audio/voice"

# Where each chapter's lines come from, and where their clips land.
CHAPTERS = {
    "ophelia": {"doc": "docs/MATHILDA_STORY.md", "table": VOICE / "lines.json", "clips": VOICE},
    "mathilda": {"doc": "docs/MATHILDA_POV.md", "table": VOICE / "mathilda/lines.json", "clips": VOICE / "mathilda"},
    "lake": {"doc": "docs/LAKE_MEETING.md", "table": VOICE / "lake/lines.json", "clips": VOICE / "lake"},
    "doorway": {"doc": "docs/MATHILDA_MEETING.md", "table": VOICE / "meeting/lines.json", "clips": VOICE / "meeting"},
}
MOODS = ["steady", "warm", "hushed", "shaken", "breaking", "resolve", "calling",
         "numb", "bitter", "pleading", "wry", "remembering", "panicked", "spent"]

# Who can perform a final clip for whom. Kokoro is final for Mathilda's own
# chapter and the lake; everything else waits for Chatterbox on the desktop.
FINAL_ENGINE = {
    ("ophelia", "ophelia"): "desktop:chatterbox",
    ("mathilda", "mathilda"): "kokoro",
    ("lake", "mathilda"): "kokoro",
    ("lake", "ophelia"): "desktop:chatterbox",
    ("doorway", "ophelia"): "desktop:chatterbox",
    ("doorway", "mathilda"): "desktop:chatterbox",
}


def clip_key(text, mood):
    return hashlib.sha256((text + "|" + mood).encode("utf-8")).hexdigest()


@dataclass
class Line:
    uid: str
    chapter: str
    group: str
    speaker: str
    mood: str
    text: str
    clip_key: str = ""
    clip: str = "missing"          # final | draft | missing
    clip_path: str = ""            # res-relative path of the clip that plays, if any
    owed_to: str = ""              # the engine still owed a final clip
    source: str = ""               # doc:line
    meta: dict = field(default_factory=dict)

    def as_dict(self):
        return asdict(self)


def _read(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def _ophelia_lines(data):
    """Walk script_to_lines.py's shapes: keyed, staged, flat and single groups."""
    for group, value in data.items():
        if isinstance(value, list):
            for i, item in enumerate(value):
                yield f"{group}/{i}", group, item
        elif isinstance(value, dict) and "text" in value:
            yield group, group, value
        elif isinstance(value, dict):
            for key, item in value.items():
                if isinstance(item, list):
                    for i, sub in enumerate(item):
                        yield f"{group}/{key}/{i}", f"{group}/{key}", sub
                else:
                    yield f"{group}/{key}", group, item


def load(read=None, locate=True):
    """Every line, from the tables on disk, or through `read(path)` (e.g. as they were at a commit)."""
    read = read or _read
    lines = []
    data = read(CHAPTERS["ophelia"]["table"]) or {}
    for uid, group, item in _ophelia_lines(data):
        extra = {k: v for k, v in item.items() if k not in ("text", "mood")}
        lines.append(Line(f"ophelia/{uid}", "ophelia", group, "ophelia", item["mood"], item["text"], meta=extra))
    for group, entries in (read(CHAPTERS["mathilda"]["table"]) or {}).items():
        for i, item in enumerate(entries):
            name = item.get("id", str(i))
            lines.append(Line(f"mathilda/{group}/{name}", "mathilda", group, "mathilda", item["mood"], item["text"]))
    for item in read(CHAPTERS["lake"]["table"]) or []:
        lines.append(Line(f"lake/{item['id']}", "lake", "lake", item["speaker"], item["mood"], item["text"],
                          meta={"pause": item.get("pause")}))
    for item in read(CHAPTERS["doorway"]["table"]) or []:
        meta = {k: item.get(k) for k in ("reaction", "answers", "quote", "intensity", "pause", "overlap", "break") if k in item}
        lines.append(Line(f"doorway/{item['id']}", "doorway", "doorway", item["speaker"], item["mood"], item["text"], meta=meta))
    for line in lines:
        _state(line)
    if locate:
        _locate(lines)
    return lines


def _state(line):
    line.clip_key = clip_key(line.text, line.mood)
    folder = CHAPTERS[line.chapter]["clips"]
    final = folder / (line.clip_key + ".wav")
    draft = folder / "draft" / (line.clip_key + ".wav")
    engine = FINAL_ENGINE[(line.chapter, line.speaker)]
    if final.exists():
        line.clip, line.clip_path = "final", final.relative_to(ROOT).as_posix()
    elif draft.exists():
        line.clip, line.clip_path, line.owed_to = "draft", draft.relative_to(ROOT).as_posix(), engine
    else:
        line.clip, line.owed_to = "missing", engine


def _locate(lines):
    """Point each line at the place in its script of record that holds its text."""
    docs = {}
    for line in lines:
        doc = CHAPTERS[line.chapter]["doc"]
        if doc not in docs:
            path = ROOT / doc
            docs[doc] = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
        # A script entry, not prose that happens to contain the words: a list item
        # or quote that ends with the text, or a table row that holds it as a cell.
        fallback = ""
        key = f"**{line.uid.rsplit('/', 1)[-1]}:**"
        keyed = next((n for n, raw in enumerate(docs[doc], 1) if key in raw and line.text in raw), 0)
        if keyed:
            line.source = f"{doc}:{keyed}"
            continue
        for number, raw in enumerate(docs[doc], 1):
            if not line.text or line.text not in raw:
                continue
            item = raw.strip()
            if (item.startswith(("- ", "> ")) and item.endswith(line.text)) or \
                    (item.startswith("|") and f"| {line.text} |" in item):
                line.source = f"{doc}:{number}"
                break
            fallback = fallback or f"{doc}:{number}"
        else:
            line.source = fallback


def orphans(lines):
    """Clips on disk that no line plays any more (an older text, a renamed mood)."""
    keys = {line.clip_key for line in lines}
    found = []
    for spec in CHAPTERS.values():
        for folder in (spec["clips"], spec["clips"] / "draft"):
            if folder.exists():
                for wav in folder.glob("*.wav"):
                    if wav.stem not in keys and len(wav.stem) == 64:
                        found.append(wav.relative_to(ROOT).as_posix())
    return sorted(set(found))


def summary(lines):
    table = {}
    for line in lines:
        row = table.setdefault(line.chapter, {"lines": 0, "final": 0, "draft": 0, "missing": 0})
        row["lines"] += 1
        row[line.clip] += 1
    return table


def owed(lines):
    by = {}
    for line in lines:
        if line.owed_to:
            by.setdefault(line.owed_to, []).append(line)
    return by
