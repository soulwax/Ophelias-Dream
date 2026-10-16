"""SFX inventory and replacement safeguards without changing game assets."""
import hashlib
import io
import json
import sys
import tempfile
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio import sfx  # noqa: E402


def wav(payload):
	buffer = io.BytesIO()
	with wave.open(buffer, "wb") as sound:
		sound.setnchannels(1)
		sound.setsampwidth(2)
		sound.setframerate(22050)
		sound.writeframes(payload)
	return buffer.getvalue()


def main():
	items = sfx.catalog()
	by_path = {item["path"]: item for item in items}
	assert len(items) >= 200
	for name in ("assets/audio/errands/bell.wav", "assets/audio/steps/snow_00.wav",
		"assets/audio/weather/storm_0.ogg", "assets/derived/doors/audio/door_01.ogg"):
		assert by_path[name]["used"], name
	assert not by_path["assets/audio/wind.wav"]["used"]
	with tempfile.TemporaryDirectory() as directory:
		root = Path(directory)
		audio = root / "assets/audio"
		audio.mkdir(parents=True)
		old, new = wav(b"\x00\x00" * 8), wav(b"\x01\x00" * 8)
		path = audio / "bell.wav"
		path.write_bytes(old)
		(audio / "provenance.json").write_text(json.dumps({"files": {"bell.wav": {"license": "CC0 1.0"}}}), encoding="utf-8")
		revision = hashlib.sha256(old).hexdigest()
		meta = {"title": "Test bell", "author": "Test recorder", "license": "CC0 1.0", "page": ""}
		for bad_path in ("../../outside.wav", "assets/audio/voice/clip.wav", "assets/audio/music/theme.ogg"):
			try:
				sfx.replace(bad_path, revision, new, meta, root)
			except ValueError:
				pass
			else:
				raise AssertionError(f"unsafe path accepted: {bad_path}")
		for bad_data, bad_meta in ((b"not audio", meta), (new, {**meta, "license": "unknown"})):
			try:
				sfx.replace("assets/audio/bell.wav", revision, bad_data, bad_meta, root)
			except ValueError:
				pass
			else:
				raise AssertionError("invalid replacement accepted")
		assert path.read_bytes() == old
		result = sfx.replace("assets/audio/bell.wav", revision, new, meta, root)
		assert path.read_bytes() == new
		assert (root / result["archive"]).read_bytes() == old
		assert json.loads((audio / "provenance.json").read_text(encoding="utf-8"))["files"]["bell.wav"]["title"] == "Test bell"
		try:
			sfx.replace("assets/audio/bell.wav", revision, old, meta, root)
		except sfx.ConflictError:
			pass
		else:
			raise AssertionError("stale replacement overwrote new audio")
	print("SFX inventory, dynamic families, archive, provenance, format, path, and stale-edit guards checked")


if __name__ == "__main__":
	main()
