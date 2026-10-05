"""Downloads her feminine-style locomotion takes into build/bandai/.

    python tools/fetch_motion.py

The takes are from the Bandai Namco Research Motion Dataset 1 (Bandai Namco
Research Inc., CC BY-NC 4.0). They come through the GitHub contents API, not
raw.githubusercontent.com, which this network does not reach.
tools/retarget_bvh.gd bakes them onto the elf.
"""

import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "bandai"
API = "https://api.github.com/repos/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset/contents/dataset/Bandai-Namco-Research-Motiondataset-1/"
HEADERS = {"User-Agent": "RunAway-motion-fetch/1.0", "Accept": "application/vnd.github.raw"}
FILES = [
	"data/dataset-1_walk_feminine_001.bvh",
	"data/dataset-1_walk_feminine_002.bvh",
	"data/dataset-1_run_feminine_001.bvh",
	"data/dataset-1_dash_feminine_001.bvh",
	"data/dataset-1_walk-back_feminine_001.bvh",
	"data/dataset-1_walk-left_feminine_001.bvh",
	"data/dataset-1_walk-right_feminine_001.bvh",
	"LICENSE",
	"README.md",
]


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	for name in FILES:
		request = urllib.request.Request(API + name, headers=HEADERS)
		data = urllib.request.urlopen(request, timeout=60).read()
		target = OUT / pathlib.Path(name).name
		target.write_bytes(data)
		print(target.name, len(data))


if __name__ == "__main__":
	main()
