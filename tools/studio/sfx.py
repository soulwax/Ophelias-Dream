"""Inventory and safely replace the game's CC0 sound effects."""
import hashlib
import json
import os
import re
import struct
import threading
import time
import wave
from pathlib import Path

from . import model


ROOT = model.ROOT
MAX_BYTES = 32 * 1024 * 1024
_LOCK = threading.Lock()
_NUMBERED = re.compile(r"_\d{1,2}$")


class ConflictError(ValueError):
	pass


def _digest(data):
	return hashlib.sha256(data).hexdigest()


def _usage(relative, scripts, prefix="assets/audio", category_override=""):
	"""Find direct paths and the four known runtime-generated sound families."""
	category = category_override or (relative.parts[0] if len(relative.parts) > 1 else "root")
	stem = relative.stem
	family = _NUMBERED.sub("", stem)
	used = set()
	for source, code in scripts.items():
		if f"res://{prefix}/{relative.as_posix()}" in code:
			used.add(source)
		elif category == "doors" and source.endswith("door_audio.gd") and f'"{relative.name}"' in code:
			used.add(source)
		elif category == "root" and f'"{relative.name}"' in code:
			used.add(source)
		elif category == "root" and stem.startswith("house_") and f'"{stem}"' in code:
			used.add(source)
		elif category == "errands" and f'"{family}"' in code and "ErrandKit.play" in code:
			used.add(source)
		elif category == "steps" and source.endswith("soundscape.gd") and f'"{family}"' in code:
			used.add(source)
		elif category == "steps" and family == "above" and source.endswith("haunting.gd"):
			used.add(source)
		elif category == "nature" and source.endswith("wildlife.gd") and f'"{family}"' in code:
			used.add(source)
		elif category == "weather" and source.endswith("storm_audio.gd") and (f'"{relative.name}"' in code or
			family in ("storm", "breeze") and f'"{family}_%d.ogg"' in code):
			used.add(source)
		elif category == "nature" and family == "trees" and source.endswith("wildlife.gd"):
			used.add(source)
		elif category == "root" and family == "birds" and source.endswith("wildlife.gd"):
			used.add(source)
	return sorted(used)


def catalog(root=ROOT):
	scripts = {p.relative_to(root).as_posix(): p.read_text(encoding="utf-8-sig")
		for p in (root / "scripts").rglob("*.gd")}
	items = []
	for prefix, category in (("assets/audio", ""), ("assets/derived/doors/audio", "doors")):
		base = root / prefix
		provenance_path = base / "provenance.json"
		provenance = json.loads(provenance_path.read_text(encoding="utf-8"))["files"] if provenance_path.exists() else {}
		for path in sorted(base.rglob("*")):
			if not path.is_file() or path.suffix.lower() not in (".wav", ".ogg"):
				continue
			relative = path.relative_to(base)
			if relative.parts[0] in ("voice", "music"):
				continue
			data = path.read_bytes()
			info = provenance.get(relative.as_posix(), {})
			if category == "doors" and not info:
				info = {"title": "CC0 OpenGameArt door audio pack", "author": "OpenGameArt contributors", "license": "CC0 1.0"}
			uses = _usage(relative, scripts, prefix, category)
			items.append({"path": path.relative_to(root).as_posix(), "name": path.name,
				"category": category or (relative.parts[0] if len(relative.parts) > 1 else "root"),
				"family": _NUMBERED.sub("", path.stem), "bytes": len(data), "revision": _digest(data),
				"uses": uses, "used": bool(uses), "source": {key: info.get(key, "")
					for key in ("title", "author", "page", "license")}})
	return items


def _target(relative, root):
	path = (root / relative).resolve()
	bases = [(root / part).resolve() for part in ("assets/audio", "assets/derived/doors/audio")]
	base = next((part for part in bases if path.is_relative_to(part)), None)
	if base is None:
		raise ValueError("choose a game sound effect")
	if path.suffix.lower() not in (".wav", ".ogg") or "voice" in path.relative_to(base).parts or "music" in path.relative_to(base).parts:
		raise ValueError("only existing WAV or Ogg sound effects can be replaced")
	if not path.is_file():
		raise ValueError("sound effect no longer exists")
	return path


def _validate_audio(data, suffix):
	if not data or len(data) > MAX_BYTES:
		raise ValueError("audio must be between 1 byte and 32 MB")
	if suffix == ".wav":
		if data[:4] != b"RIFF" or data[8:12] != b"WAVE" or struct.unpack("<I", data[4:8])[0] + 8 != len(data):
			raise ValueError("replacement must be a complete RIFF/WAVE file")
		import io
		try:
			with wave.open(io.BytesIO(data)) as sound:
				if sound.getnframes() < 1 or sound.getframerate() < 8000 or sound.getnchannels() not in (1, 2):
					raise ValueError("WAV must contain mono or stereo audio at 8 kHz or higher")
				if len(sound.readframes(sound.getnframes())) != sound.getnframes() * sound.getnchannels() * sound.getsampwidth():
					raise ValueError("WAV audio is truncated")
		except (wave.Error, EOFError) as error:
			raise ValueError(f"WAV audio could not be read: {error}") from error
	elif data[:4] != b"OggS" or b"\x01vorbis" not in data[:128]:
		raise ValueError("replacement must be an Ogg Vorbis file")


def replace(relative, revision, data, metadata, root=ROOT):
	"""Archive old bytes, then replace a same-format SFX and its provenance."""
	with _LOCK:
		path = _target(relative, root)
		old = path.read_bytes()
		if _digest(old) != revision:
			raise ConflictError("this sound changed since you opened it; reload the SFX list")
		_validate_audio(data, path.suffix.lower())
		if metadata.get("license") != "CC0 1.0":
			raise ValueError("tracked SFX replacements must be CC0 1.0")
		title = str(metadata.get("title", "")).strip()[:200]
		author = str(metadata.get("author", "")).strip()[:120]
		page = str(metadata.get("page", "")).strip()[:500]
		if not title or not author:
			raise ValueError("enter the replacement's source title and creator")
		base = root / ("assets/audio" if path.is_relative_to(root / "assets/audio") else "assets/derived/doors/audio")
		provenance_path = base / "provenance.json"
		provenance = json.loads(provenance_path.read_text(encoding="utf-8")) if provenance_path.exists() else {"files": {}}
		key = path.relative_to(base).as_posix()
		previous = provenance["files"].get(key, {})
		provenance["files"][key] = {"source": "studio replacement", "id": path.name, "page": page,
			"title": title, "author": author, "license": "CC0 1.0",
			"processing": "replaced in Story Studio", "sha256": _digest(data)}
		archive = root / "build/studio/sfx_archive" / f"{time.strftime('%Y%m%d-%H%M%S')}-{_digest(old)[:12]}" / key
		archive.parent.mkdir(parents=True, exist_ok=True)
		archive.write_bytes(old)
		archive.with_suffix(archive.suffix + ".json").write_text(json.dumps(previous, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
		staged_audio = path.with_name(path.name + ".studio-tmp")
		staged_info = provenance_path.with_name(provenance_path.name + ".studio-tmp")
		try:
			staged_audio.write_bytes(data)
			staged_info.write_text(json.dumps(provenance, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
			os.replace(staged_audio, path)
			os.replace(staged_info, provenance_path)
		except OSError:
			path.write_bytes(old)
			staged_audio.unlink(missing_ok=True)
			staged_info.unlink(missing_ok=True)
			raise
		return {"ok": True, "revision": _digest(data), "archive": archive.relative_to(root).as_posix()}
