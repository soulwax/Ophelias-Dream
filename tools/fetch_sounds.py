"""Downloads the recorded sound sources (all CC0) into build/sfx_src/.

    python tools/fetch_sounds.py

BigSoundBank (Joseph Sardin, CC0) serves its original WAVs. Freesound serves
its originals only to signed-in users, so the high-quality OGG preview of each
CC0 sound is used instead; every Freesound page is checked for the CC0 licence
before anything is taken. tools/make_soundscape.py cuts and levels them.
"""

import json
import pathlib
import re
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "sfx_src"
AGENT = {"User-Agent": "OpheliasDream-soundscape-fetch/1.0 (CC0 sources for a Godot game)"}
CC0 = "creativecommons.org/publicdomain/zero/1.0"

# name -> (source, id). Names are what make_soundscape.py refers to.
SOURCES = {
	# Footsteps
	"snow_bsb_2890": ("bigsoundbank", "2890"),
	"snow_bsb_0208": ("bigsoundbank", "0208"),
	"snow_bsb_3363": ("bigsoundbank", "3363"),
	"snow_fs_613849": ("freesound", "613849"),
	"snow_fs_554726": ("freesound", "554726"),
	"wood_bsb_0165": ("bigsoundbank", "0165"),
	"wood_bsb_0376": ("bigsoundbank", "0376"),
	"wood_fs_614291": ("freesound", "614291"),
	"wood_fs_142000": ("freesound", "142000"),
	"stone_bsb_0606": ("bigsoundbank", "0606"),
	"stone_bsb_0514": ("bigsoundbank", "0514"),
	"stone_fs_521590": ("freesound", "521590"),
	"stone_fs_677069": ("freesound", "677069"),
	"stone_fs_813622": ("freesound", "813622"),
	"creak_fs_506665": ("freesound", "506665"),
	"creak_fs_264306": ("freesound", "264306"),
	"creak_bsb_0518": ("bigsoundbank", "0518"),
	# Grass and forest floor, for the green land beyond the snow
	"grass_fs_521587": ("freesound", "521587"),
	"grass_fs_331167": ("freesound", "331167"),
	"grass_fs_505833": ("freesound", "505833"),
	"grass_fs_206030": ("freesound", "206030"),
	"grass_fs_389625": ("freesound", "389625"),
	# Weather
	"storm_fs_505999": ("freesound", "505999"),
	"storm_fs_35480": ("freesound", "35480"),
	"wind_bsb_0595": ("bigsoundbank", "0595"),
	"wind_bsb_0625": ("bigsoundbank", "0625"),
	"window_fs_69512": ("freesound", "69512"),
	"howl_fs_256862": ("freesound", "256862"),
	# Flora and fauna
	"trees_bsb_1051": ("bigsoundbank", "1051"),
	"trees_bsb_0904": ("bigsoundbank", "0904"),
	"treecreak_fs_140047": ("freesound", "140047"),
	"treecreak_fs_95264": ("freesound", "95264"),
	"snowfall_fs_116136": ("freesound", "116136"),
	"crow_fs_252685": ("freesound", "252685"),
	"crow_fs_334231": ("freesound", "334231"),
	"raven_fs_675958": ("freesound", "675958"),
	"raven_fs_864903": ("freesound", "864903"),
}


def get(url: str) -> bytes:
	for attempt in range(5):
		try:
			with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=120) as reply:
				return reply.read()
		except Exception as error:  # noqa: BLE001 - retry anything, report the last
			if attempt == 4:
				raise
			print(f"  retry {url}: {error}")
			time.sleep(6.0 * (attempt + 1))
	return b""


def bigsoundbank(number: str) -> dict:
	page = f"https://bigsoundbank.com/search?q={number}"
	return {
		"url": f"https://bigsoundbank.com/UPLOAD/bwf-en/{number}.wav",
		"page": page,
		"author": "Joseph Sardin (BigSoundBank)",
		"license": "CC0 1.0",
		"format": "wav",
	}


def freesound(number: str) -> dict:
	page = f"https://freesound.org/s/{number}/"
	html = get(page).decode("utf-8", "replace")
	if CC0 not in html:
		raise RuntimeError(f"freesound {number} is not CC0")
	preview = re.search(r'data-mp3="(https://cdn\.freesound\.org/previews/[^"]+)-lq\.mp3"', html)
	author = re.search(r'data-username="([^"]+)"', html)
	title = re.search(r'data-title="([^"]*)"', html)
	if not preview:
		raise RuntimeError(f"freesound {number}: no preview found")
	return {
		"url": preview.group(1) + "-hq.ogg",
		"page": page,
		"title": title.group(1) if title else "",
		"author": author.group(1) if author else "",
		"license": "CC0 1.0",
		"format": "ogg",
	}


def main() -> int:
	OUT.mkdir(parents=True, exist_ok=True)
	record = {}
	for name, (site, number) in SOURCES.items():
		info = bigsoundbank(number) if site == "bigsoundbank" else freesound(number)
		target = OUT / f"{name}.{info['format']}"
		if not target.exists():
			print(f"fetch {name} <- {info['url']}")
			target.write_bytes(get(info["url"]))
			time.sleep(1.5)
		info["file"] = target.name
		info["source"] = site
		info["id"] = number
		record[name] = info
	(OUT / "sources.json").write_text(json.dumps(record, indent="\t"), encoding="utf-8")
	print(f"{len(record)} sources in {OUT}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
