"""Bake her reviewed lines into clips; no model runs during gameplay.

Engines: qwen (default) speaks each line with Qwen3-TTS VoiceDesign on CUDA,
directed by its mood, renders four takes, and keeps the one Whisper hears
right and that sounds most like her anchor; kokoro is the old CPU voice.
Setup: docs/VOICE.md. Clips land in assets/audio/voice/ as
sha256("text|mood").wav with manifest.json beside them.
"""

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/voice"
REF = ROOT / "build/voice/ref"
HF = ROOT / "build/voice/hf"
DESIGN_MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
BASE_MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-Base"
IDENTITY = ("A woman around thirty. A low, soft alto with a little breath in it, plain North American accent. "
            "She is cold, tired, and talking quietly to herself in an empty place; never theatrical, never narrating.")
# Mood: (direction appended to her identity, loudest-50-ms level in dBFS).
MOODS = {
    "steady": ("Calm and even, trying to reassure herself.", -12.0),
    "warm": ("Tender and fond, almost smiling, a catch at the end.", -12.0),
    "hushed": ("Barely above a whisper, close and careful, as if something might hear.", -18.0),
    "shaken": ("Unsteady, breath short, words coming a little too fast.", -12.0),
    "breaking": ("On the edge of tears, voice cracking, pauses where it gives out.", -13.0),
    "resolve": ("Low and determined, jaw set, each word placed.", -12.0),
    "calling": ("Shouting as loud as she can into a strong wind, straining, desperate.", -10.0),
}
ANCHOR_TEXT = "I'm going to find her. The lantern's lit, the door's open, and she can't have gone far in this."
TAKES = 4
CLONE_TAKES = 2
MAX_WER = 0.15
MIN_SIMILARITY = 0.60


def clip_name(text, mood):
    return hashlib.sha256(f"{text}|{mood}".encode("utf-8")).hexdigest() + ".wav"


def lines(data):
    """Every (category, text, mood) in lines.json, in file order, once each."""
    found = []

    def add(category, item):
        if isinstance(item, str):
            item = {"text": item, "mood": "steady"}
        found.append((category, item["text"].strip(), item.get("mood", "steady")))

    for category in ("pages", "deciphered", "places", "revisits"):
        for item in data.get(category, {}).values():
            add(category, item)
    for category in ("bored", "calls"):
        group = data.get(category, {})
        if isinstance(group, list):
            group = {"hope": group}
        for stage in ("hope", "doubt", "resolve"):
            for item in group.get(stage, []):
                add(category, item)
    for item in data.get("misread", []):
        add("misread", item)
    seen, unique = set(), []
    for category, text, mood in found:
        if (text, mood) not in seen:
            seen.add((text, mood))
            unique.append((category, text, mood))
    return unique


def words(text):
    heard = re.findall(r"[a-z0-9']+", text.lower().replace("’", "'"))
    # Whisper often uses the more common spelling for the same spoken name.
    return ["mathilda" if word == "matilda" else word for word in heard]


def wer(reference, heard):
    ref, hyp = words(reference), words(heard)
    row = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        prev, row[0] = row[0], i
        for j, h in enumerate(hyp, 1):
            prev, row[j] = row[j], min(row[j] + 1, row[j - 1] + 1, prev + (r != h))
    return row[len(hyp)] / max(len(ref), 1)


def level(samples, rate, target_db):
    import numpy as np
    window = max(1, int(rate * 0.05))
    power = np.convolve(samples.astype(np.float64) ** 2, np.ones(window) / window, mode="valid")
    gain = min(10 ** (target_db / 20) / max(float(np.sqrt(power.max())), 1e-8),
               0.95 / max(float(np.abs(samples).max()), 1e-8))
    return samples * gain


def trim(samples, rate, keep=0.06, floor_db=-45.0):
    import numpy as np
    loud = np.abs(samples) > 10 ** (floor_db / 20) * max(float(np.abs(samples).max()), 1e-8)
    idx = np.flatnonzero(loud)
    if idx.size == 0:
        return samples
    pad = int(rate * keep)
    return samples[max(idx[0] - pad, 0): idx[-1] + pad + 1]


class Qwen:
    """Qwen3-TTS: VoiceDesign speaks from a direction; Base clones the anchor."""

    def __init__(self):
        import torch
        from qwen_tts import Qwen3TTSModel
        self.torch = torch
        self.loader = Qwen3TTSModel
        self.kwargs = dict(device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
        self.design = Qwen3TTSModel.from_pretrained(str(HF / "VoiceDesign"), **self.kwargs)
        self.base = None
        self.prompt = None

    def speak(self, text, mood, seed):
        import numpy as np
        self.torch.manual_seed(seed)
        wavs, rate = self.design.generate_voice_design(
            text=text, language="English", instruct=f"{IDENTITY} {MOODS[mood][0]}",
            max_new_tokens=192)
        return np.asarray(wavs[0], dtype=np.float32).reshape(-1), int(rate)

    def speak_many(self, text, mood):
        import numpy as np
        # VoiceDesign accepts a batch; four independently sampled takes are
        # much quicker than four serial calls on the release GPU.
        self.torch.manual_seed(1000)
        wavs, rate = self.design.generate_voice_design(
            text=[text] * TAKES, language="English",
            instruct=[f"{IDENTITY} {MOODS[mood][0]}"] * TAKES,
            max_new_tokens=192)
        return [(np.asarray(wav, dtype=np.float32).reshape(-1), int(rate)) for wav in wavs]

    def clone(self, text, seed):
        import numpy as np
        if self.base is None:
            self.base = self.loader.from_pretrained(str(HF / "Base"), **self.kwargs)
            self.prompt = self.base.create_voice_clone_prompt(
                ref_audio=str(REF / "anchor.wav"), ref_text=ANCHOR_TEXT, x_vector_only_mode=False)
        self.torch.manual_seed(seed)
        wavs, rate = self.base.generate_voice_clone(
            text=text, language="English", voice_clone_prompt=self.prompt,
            max_new_tokens=192)
        return np.asarray(wavs[0], dtype=np.float32).reshape(-1), int(rate)


class Judge:
    """Whisper for the words, an ECAPA embedding for whether it is her."""

    def __init__(self):
        import torch
        # ctranslate2 finds cuDNN/cuBLAS in torch's own lib folder.
        os.add_dll_directory(str(Path(torch.__file__).parent / "lib"))
        import torchaudio
        from faster_whisper import WhisperModel
        from speechbrain.inference.speaker import EncoderClassifier
        from speechbrain.utils.fetching import LocalStrategy
        self.torch, self.torchaudio = torch, torchaudio
        free, _total = torch.cuda.mem_get_info()
        self.device = "cuda" if free >= 2 * 1024**3 else "cpu"
        print(f"Judging on {self.device} ({free / 1024**3:.1f} GiB GPU free)", flush=True)
        self.asr = WhisperModel(str(HF / "whisper-model"), device=self.device,
                                compute_type="int8_float16" if self.device == "cuda" else "int8")
        self.ecapa = EncoderClassifier.from_hparams(
            source=str(HF / "ecapa-model"), savedir=str(HF / "ecapa"),
            run_opts={"device": self.device}, local_strategy=LocalStrategy.COPY)
        self.anchor = None

    def _16k(self, samples, rate):
        wave = self.torch.from_numpy(samples).float().unsqueeze(0)
        return self.torchaudio.functional.resample(wave, rate, 16000)

    def hear(self, samples, rate):
        wave = self._16k(samples, rate).squeeze(0).numpy()
        segments, _ = self.asr.transcribe(wave, language="en", beam_size=5)
        return " ".join(segment.text.strip() for segment in segments)

    def embed(self, samples, rate):
        with self.torch.no_grad():
            vector = self.ecapa.encode_batch(self._16k(samples, rate).to(self.device)).squeeze()
        return vector / vector.norm()

    def similarity(self, samples, rate):
        return float((self.embed(samples, rate) * self.anchor).sum())


def ensure_anchor(engine, judge, new, seed):
    import soundfile as sf
    path = REF / "anchor.wav"
    if new or not path.exists():
        REF.mkdir(parents=True, exist_ok=True)
        samples, rate = engine.speak(ANCHOR_TEXT, "steady", seed)
        sf.write(path, level(trim(samples, rate), rate, -12.0), rate, subtype="PCM_16")
        print(f"New anchor: {path}  (listen; re-roll with --new-anchor --anchor-seed N)")
    if judge is not None:
        samples, rate = sf.read(path, dtype="float32")
        judge.anchor = judge.embed(samples, rate)


def best_take(engine, judge, text, mood):
    takes = [("qwen-design", DESIGN_MODEL, trim(samples, rate), rate)
             for samples, rate in engine.speak_many(text, mood)]
    scored = [score(judge, text, *take) for take in takes]
    if not any(s["wer"] <= MAX_WER and s["similarity"] >= MIN_SIMILARITY for s in scored):
        for take in range(CLONE_TAKES):
            samples, rate = engine.clone(text, seed=2000 + take)
            scored.append(score(judge, text, "qwen-clone", BASE_MODEL, trim(samples, rate), rate))
    good = [s for s in scored if s["wer"] <= MAX_WER]
    return max(good, key=lambda s: s["similarity"]) if good else min(scored, key=lambda s: s["wer"]), bool(good)


def score(judge, text, engine, model, samples, rate):
    heard = judge.hear(samples, rate)
    result = dict(engine=engine, model=model, samples=samples, rate=rate,
                  wer=wer(text, heard), similarity=judge.similarity(samples, rate), heard=heard)
    print(f"    {engine:12s} wer {result['wer']:.2f}  sim {result['similarity']:.2f}  | {heard}", flush=True)
    return result


def bake_kokoro(args, todo):
    import numpy as np
    import onnxruntime as ort
    from kokoro_onnx import Kokoro
    models = ROOT / "build/voice/models"
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    session = ort.InferenceSession(str(models / "kokoro-v1.0.int8.onnx"), sess_options=options,
                                   providers=["CPUExecutionProvider"])
    kokoro = Kokoro.from_session(session, str(models / "voices-v1.0.bin"))

    def speak(text, mood):
        samples, rate = kokoro.create(text, voice=args.voice, speed=args.speed, lang="en-us")
        return np.asarray(samples, dtype=np.float32), rate
    return speak


def self_test():
    assert clip_name("a", "b") == hashlib.sha256(b"a|b").hexdigest() + ".wav"
    assert wer("Mathilda... please.", "Mathilda, please") == 0.0
    assert wer("Mathilda!", "Matilda!") == 0.0
    assert wer("two cups", "two cups here") == 0.5
    assert wer("I'm not lifting that sheet", "im not lifting the sheet") > 0.0
    data = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    every = lines(data)
    assert len(every) == 62, len(every)
    assert all(mood in MOODS for _, _, mood in every)
    print("SELF-TEST PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--engine", choices=["qwen", "kokoro"], default="qwen")
    parser.add_argument("--force", action="store_true", help="Re-bake every line")
    parser.add_argument("--only", help="Re-bake only the line with exactly this text")
    parser.add_argument("--new-anchor", action="store_true", help="Render a new anchor voice")
    parser.add_argument("--anchor-seed", type=int, default=7)
    parser.add_argument("--anchor-only", action="store_true", help="Render the anchor and stop")
    parser.add_argument("--accept-bad", action="store_true", help="Keep the best take even above MAX_WER")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--voice", default="af_sarah", help="kokoro voice")
    parser.add_argument("--speed", type=float, default=0.92, help="kokoro speed")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    import numpy as np
    import soundfile as sf

    todo = lines(json.loads((OUT / "lines.json").read_text(encoding="utf-8")))
    manifest_path = OUT / "manifest.json"
    old = {}
    if manifest_path.exists():
        for clip in json.loads(manifest_path.read_text(encoding="utf-8")).get("clips", []):
            old[clip["file"]] = clip
    engine = judge = kokoro = None
    if args.engine == "qwen":
        engine = Qwen()
        if args.anchor_only:
            ensure_anchor(engine, None, args.new_anchor, args.anchor_seed)
            return
        judge = Judge()
        ensure_anchor(engine, judge, args.new_anchor, args.anchor_seed)
    else:
        kokoro = bake_kokoro(args, todo)

    clips, bad, keep = [], [], set()
    for category, text, mood in todo:
        name = clip_name(text, mood)
        keep.add(name)
        target = OUT / name
        redo = (text == args.only) if args.only is not None else (args.force or not target.exists())
        if not redo:
            if not target.exists():
                continue
            entry = old.get(name) or dict(text=text, mood=mood, file=name,
                                          seconds=float(sf.info(target).duration), engine="unknown")
            entry["category"] = category
            clips.append(entry)
            manifest_path.write_text(json.dumps({"engine": args.engine, "identity": IDENTITY, "clips": clips},
                                                indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            continue
        print(f"[{mood}] {text}", flush=True)
        if kokoro:
            samples, rate = kokoro(text, mood)
            result, ok = dict(engine="kokoro", model=args.voice, samples=trim(samples, rate), rate=rate,
                              wer=None, similarity=None), True
        else:
            result, ok = best_take(engine, judge, text, mood)
        if not ok:
            bad.append(text)
            if not args.accept_bad:
                print("    no take passed; skipped (re-run with --accept-bad to keep the best)")
                continue
        samples = level(result["samples"], result["rate"], MOODS[mood][1])
        if len(samples) == 0 or not np.isfinite(samples).all():
            raise ValueError(f"Invalid speech for {text!r}")
        sf.write(target, samples, result["rate"], subtype="PCM_16")
        clips.append(dict(text=text, mood=mood, category=category, file=name,
                          seconds=len(samples) / result["rate"], wer=result["wer"],
                          similarity=result["similarity"], engine=result["engine"], model=result["model"]))
        manifest_path.write_text(json.dumps({"engine": args.engine, "identity": IDENTITY, "clips": clips},
                                            indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if args.only is None:
        for stale in OUT.glob("*.wav"):
            if stale.name not in keep:
                stale.unlink()
                imported = OUT / (stale.name + ".import")
                if imported.exists():
                    imported.unlink()
    manifest = {"engine": args.engine, "identity": IDENTITY, "clips": clips}
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Baked {len(clips)} clips into {OUT}")
    if bad:
        print("No take passed for:\n  " + "\n  ".join(bad))
        if not args.accept_bad:
            sys.exit(1)


if __name__ == "__main__":
    main()
