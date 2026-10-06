"""Write, check and perform the doorway meeting (docs/MEETING_VOICE.md).

The script of record is docs/MATHILDA_MEETING.md; the tree that joins its lines
is assets/dialogue/meeting.json.

  python tools/bake_meeting.py --write    lines.json from the script, then timing
  python tools/bake_meeting.py --check    script, tree, lines.json and timing.json agree,
                                          and the argument stays coherent (below)
  python tools/bake_meeting.py --paths    every path through the tree as a transcript
  --engine kokoro                          drafts for both speakers into meeting/draft/
                                          (CPU; the game uses them only as a fallback)
  --engine chatterbox                      final clips (desktop, CUDA, build/voice/cb-venv)

Coherence is a hard requirement, so --check fails when:
- a line has no "Action / reaction", or no "Answers:" naming the line it answers
  with a quote that really is in that line;
- intensity jumps by more than MAX_JUMP between two lines that can follow each
  other anywhere in the tree, unless the later line is marked "Break: yes"
  (coming back after walking away is exempt: there was a real silence);
- an overlap is authored between two lines of the same speaker;
- a line in the tree is missing from the script, or a script line is unused.

The Chatterbox bake conditions each speaker on her own locked references only:
Ophelia on tools/voice/ref/<mood>.wav, Mathilda on tools/voice/ref/mathilda/<mood>.wav.
Takes must pass the Whisper gate and a stricter speaker gate than the field
lines; among those, the take whose loudness change from the previous line best
matches the authored intensity change wins. Clips are cleaned and levelled by
dialogue_post.clean(). Existing clips are kept; nothing is deleted.
"""
import argparse
import json
import re
import sys
from pathlib import Path

import bake_speech
import dialogue_post

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "docs/MATHILDA_MEETING.md"
TREE = ROOT / "assets/dialogue/meeting.json"
OUT = ROOT / "assets/audio/voice/meeting"
DRAFT = OUT / "draft"
REFS = {"ophelia": bake_speech.REF, "mathilda": bake_speech.REF / "mathilda"}
DRAFT_VOICES = {"ophelia": ("af_sarah", 0.92), "mathilda": ("af_bella", 0.94)}
MAX_JUMP = 0.4
# Stricter than the field lines: two voices drifting together mid-argument is the worst failure.
MIN_SIMILARITY = 0.72
# dB of loudness change expected per unit of intensity change between adjacent lines.
DB_PER_INTENSITY = 12.0
HEAD = re.compile(r"^### ([a-z0-9]+) \| (ophelia|mathilda) \| ([a-z]+) \| ([0-9.]+)$")
ANSWERS = re.compile(r'^Answers: (none|any|[a-z0-9]+)(?: "(.+)")?$')


def parse():
    lines, current = [], None
    for raw in SCRIPT.read_text(encoding="utf-8").splitlines():
        match = HEAD.match(raw)
        if match:
            current = dict(id=match[1], speaker=match[2], mood=match[3], text="", reaction="",
                           pause=float(match[4]), answers="", quote="", intensity=None, overlap=0.0)
            lines.append(current)
        elif raw.startswith("## ") and raw not in ("## Spoken exchange", "## Branches"):
            current = None
        elif current is None:
            continue
        elif raw.startswith("Action / reaction: "):
            current["reaction"] = raw[len("Action / reaction: "):].rstrip(".")
        elif raw.startswith("Answers: "):
            found = ANSWERS.match(raw)
            if not found:
                sys.exit(f"line {current['id']}: cannot read {raw!r}")
            current["answers"], current["quote"] = found[1], found[2] or ""
        elif raw.startswith("Intensity: "):
            current["intensity"] = float(raw.split(": ", 1)[1])
        elif raw == "Break: yes":
            current["break"] = True
        elif raw.startswith("Overlap: "):
            current["overlap"] = float(raw.split(": ", 1)[1])
        elif raw.startswith("> ") and not current["text"]:
            current["text"] = raw[2:].strip()
    return lines


def pairs(tree):
    """Every (before, after) line-id pair the tree can play back to back, and
    whether a real silence (walking away) falls between them."""
    found = set()
    nodes = tree["nodes"]
    leave = [tree["leave"]["say"]] + tree["leave"].get("reply", [])

    def chain(ids):
        for a, b in zip(ids, ids[1:]):
            found.add((a, b, False))

    for node_id, node in nodes.items():
        say = node.get("say", [])
        chain(say)
        chain(tree.get("resume", []) + say)
        before = {say[-1]} if say else set()
        for choice in node["choices"]:
            spoken = [choice["say"]] + choice.get("reply", [])
            chain(spoken)
            if "goto" not in choice and "end" not in choice:
                before.add(spoken[-1])
        for last in before:
            for choice in node["choices"]:
                found.add((last, choice["say"], False))
            found.add((last, leave[0], False))
        for choice in node["choices"]:
            spoken = [choice["say"]] + choice.get("reply", [])
            if "goto" in choice and nodes[choice["goto"]].get("say"):
                found.add((spoken[-1], nodes[choice["goto"]]["say"][0], False))
    chain(leave)
    return found


def walk(tree, by_id, limit=4000):
    """Every path through the tree, side topics taken in every order up to
    once each, as lists of line ids, each ending with how it ended."""
    nodes = tree["nodes"]
    done = []

    def visit(node_id, spoken, taken):
        if len(done) >= limit:
            return
        node = nodes[node_id]
        spoken = spoken + node.get("say", [])
        offer(node_id, spoken, taken)

    def offer(node_id, spoken, taken):
        for index, choice in enumerate(nodes[node_id]["choices"]):
            key = f"{node_id}/{index}"
            if key in taken:
                continue
            said = spoken + [choice["say"]] + choice.get("reply", [])
            if "end" in choice:
                done.append((said, choice["end"]))
            elif "goto" in choice:
                visit(choice["goto"], said, taken | {key})
            else:
                offer(node_id, said, taken | {key})

    visit(tree["start"], [], frozenset())
    return done


def problems(lines, tree):
    found = []
    by_id = {line["id"]: line for line in lines}
    if len(by_id) != len(lines):
        found.append("duplicate line ids")
    for line in lines:
        name = line["id"]
        if not line["text"]:
            found.append(f"{name}: no text")
        if line["mood"] not in bake_speech.MOODS:
            found.append(f"{name}: unknown mood {line['mood']}")
        if not line["reaction"]:
            found.append(f"{name}: no Action / reaction")
        if line["intensity"] is None or not 0.0 <= line["intensity"] <= 1.0:
            found.append(f"{name}: needs Intensity between 0 and 1")
        answers = line["answers"]
        if answers == "":
            found.append(f"{name}: no Answers")
        elif answers == "none":
            if name != tree["nodes"][tree["start"]]["say"][0]:
                found.append(f"{name}: only the opening line answers none")
        elif answers != "any":
            if answers not in by_id:
                found.append(f"{name}: answers unknown line {answers}")
            elif not line["quote"] or line["quote"] not in by_id[answers]["text"]:
                found.append(f'{name}: quote "{line["quote"]}" is not in line {answers}')
    used = set(tree.get("resume", [])) | {tree["leave"]["say"]} | set(tree["leave"].get("reply", []))
    for node in tree["nodes"].values():
        used |= set(node.get("say", []))
        for choice in node["choices"]:
            used |= {choice["say"]} | set(choice.get("reply", []))
    for name in sorted(used - set(by_id)):
        found.append(f"tree uses {name}, which the script lacks")
    for name in sorted(set(by_id) - used):
        found.append(f"script line {name} is not in the tree")
    if found:
        return found
    for before, after, _silence in sorted(pairs(tree)):
        a, b = by_id[before], by_id[after]
        if before in tree.get("resume", []) or before == tree["leave"]["reply"][-1]:
            continue
        jump = abs(b["intensity"] - a["intensity"])
        if jump > MAX_JUMP + 1e-6 and not b.get("break"):
            found.append(f"intensity jumps {jump:.2f} from {before} to {after}; soften it or mark {after} Break: yes")
        if b["overlap"] > 0 and a["speaker"] == b["speaker"]:
            found.append(f"{after} overlaps {before}, the same speaker")
    return found


def transcript(tree, by_id):
    for number, (path, ending) in enumerate(walk(tree, by_id), 1):
        print(f"\n--- path {number} -> {ending} ({len(path)} lines)")
        for name in path:
            line = by_id[name]
            print(f"  {name:>4} {line['speaker']:<8} [{line['mood']}, {line['intensity']:.2f}] {line['text']}")


def write(lines):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "lines.json").write_text(json.dumps(lines, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (OUT / "timing.json").write_text(json.dumps(dialogue_post.timing(lines), indent=2) + "\n", encoding="utf-8")


def continuity(previous_db, take_db, previous_intensity, intensity):
    """How far a take's loudness change from the line before strays from the
    change its intensity asks for, in dB (lower is better)."""
    if previous_db is None:
        return 0.0
    return abs((take_db - previous_db) - DB_PER_INTENSITY * (intensity - previous_intensity))


def loudness_db(samples):
    import numpy as np
    voiced = samples[np.abs(samples) > 1e-3]
    if len(voiced) == 0:
        return -90.0
    return float(20.0 * np.log10(np.sqrt(np.mean(np.square(voiced))) + 1e-9))


class Chatter:
    """Chatterbox conditioned on one speaker's locked reference for the mood."""

    def __init__(self):
        import torch
        from chatterbox.tts import ChatterboxTTS
        self.torch = torch
        self.model = ChatterboxTTS.from_pretrained(device="cuda")

    def perform(self, line, seed):
        import numpy as np
        _, _, exaggeration, cfg, temperature, _ = bake_speech.MOODS[line["mood"]]
        # Intensity leans on the mood's own controls, never past their range.
        exaggeration = min(1.0, exaggeration * (0.8 + 0.4 * line["intensity"]))
        self.torch.manual_seed(seed)
        wav = self.model.generate(line["text"], audio_prompt_path=str(REFS[line["speaker"]] / f"{line['mood']}.wav"),
                                  exaggeration=exaggeration, cfg_weight=cfg, temperature=temperature)
        return wav.squeeze(0).cpu().numpy().astype(np.float32), int(self.model.sr)


def best_take(chatter, judge, line, previous):
    judge.anchor = judge.embed_file(REFS[line["speaker"]] / f"{line['mood']}.wav")
    scored = []
    for seed in range(1, bake_speech.TAKES + 1):
        samples, rate = chatter.perform(line, seed)
        samples = dialogue_post.clean(samples, rate, line["mood"])
        heard = judge.hear(samples, rate)
        take = dict(samples=samples, rate=rate, wer=bake_speech.wer(line["text"], heard),
                    similarity=judge.similarity(samples, rate), db=loudness_db(samples))
        take["fit"] = continuity(previous and previous["db"], take["db"], previous and previous["intensity"], line["intensity"])
        scored.append(take)
        print(f"    take {seed}: wer {take['wer']:.2f}  sim {take['similarity']:.2f}  fit {take['fit']:.1f} dB | {heard}", flush=True)
    good = [t for t in scored if t["wer"] <= bake_speech.MAX_WER and t["similarity"] >= MIN_SIMILARITY]
    if not good:
        return None
    return min(good, key=lambda t: t["fit"] - 4.0 * t["similarity"])


def bake(lines, tree, engine, accept_bad):
    import soundfile as sf
    by_id = {line["id"]: line for line in lines}
    # The spine's previous line, for continuity; branch lines follow what they answer.
    previous_of = {line["id"]: by_id.get(line["answers"]) for line in lines}
    chatter = judge = None
    speakers = {}
    loudness = {}
    if engine == "chatterbox":
        for line in lines:
            ref = REFS[line["speaker"]] / f"{line['mood']}.wav"
            if not ref.exists():
                sys.exit(f"No locked reference {ref.relative_to(ROOT)}; see docs/MEETING_VOICE.md, stage 3a.")
    bad = []
    for line in lines:
        name = dialogue_post.clip_name(line["text"], line["mood"])
        target = (DRAFT if engine == "kokoro" else OUT) / name
        if target.exists():
            loudness[line["id"]] = dict(db=loudness_db(sf.read(target, dtype="float32")[0]), intensity=line["intensity"])
            continue
        print(f"{line['id']} {line['speaker']} [{line['mood']}] {line['text']}", flush=True)
        if engine == "kokoro":
            if line["speaker"] not in speakers:
                from types import SimpleNamespace
                voice, speed = DRAFT_VOICES[line["speaker"]]
                speakers[line["speaker"]] = bake_speech.bake_kokoro(SimpleNamespace(voice=voice, speed=speed))
            samples, rate = speakers[line["speaker"]](line["text"])
            samples = dialogue_post.clean(samples, rate, line["mood"])
        else:
            if chatter is None:
                chatter, judge = Chatter(), bake_speech.Judge()
            previous = previous_of[line["id"]]
            take = best_take(chatter, judge, line, loudness.get(previous["id"]) if previous else None)
            if take is None:
                bad.append(f"{line['id']} {line['text']}")
                if not accept_bad:
                    continue
                print("    no take passed both gates; kept nothing", flush=True)
                continue
            samples, rate = take["samples"], take["rate"]
        target.parent.mkdir(parents=True, exist_ok=True)
        sf.write(target, samples, rate, subtype="PCM_16")
        loudness[line["id"]] = dict(db=loudness_db(samples), intensity=line["intensity"])
    write(lines)
    if bad:
        sys.exit("No take passed for:\n  " + "\n  ".join(bad))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="Fail on drift or incoherence")
    parser.add_argument("--write", "--lines", dest="write", action="store_true", help="Only rewrite lines.json and timing.json")
    parser.add_argument("--paths", action="store_true", help="Print every path through the tree")
    parser.add_argument("--engine", choices=["kokoro", "chatterbox"], help="Perform missing clips")
    parser.add_argument("--accept-bad", action="store_true")
    args = parser.parse_args()
    lines = parse()
    tree = json.loads(TREE.read_text(encoding="utf-8"))
    found = problems(lines, tree)
    if found:
        sys.exit("The meeting script is not coherent:\n  " + "\n  ".join(found))
    if args.paths:
        return transcript(tree, {line["id"]: line for line in lines})
    if args.check:
        stored = OUT / "lines.json"
        if not stored.exists() or json.loads(stored.read_text(encoding="utf-8")) != lines:
            sys.exit("meeting/lines.json has drifted from docs/MATHILDA_MEETING.md; run --write")
        timing = OUT / "timing.json"
        if not timing.exists() or json.loads(timing.read_text(encoding="utf-8")) != dialogue_post.timing(lines):
            sys.exit("meeting/timing.json is stale; run --write or tools/dialogue_post.py")
        print(f"Meeting coherent: {len(lines)} lines, {len(pairs(tree))} transitions, "
              f"{len(walk(tree, None))} paths; lines.json and timing.json match")
        return
    if args.engine:
        return bake(lines, tree, args.engine, args.accept_bad)
    write(lines)
    print(f"Wrote {len(lines)} lines and their timing")


if __name__ == "__main__":
    main()
