"""Ask the local Qwen server once for each of her lines and save them.

The game reads assets/audio/voice/lines.json. It does not call the model
while she is playing. Start the server first (the page at 127.0.0.1:8765).
"""

import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "voice" / "lines.json"
URL = "http://127.0.0.1:8765/v1/chat/completions"
SYSTEM = (
    "You are the woman in a winter horror game, muttering to herself. "
    "Reply with one sentence, at most 18 words, first person. "
    "No quotation marks, no lists. Quiet, angsty, a little bitter toward herself. "
    "React to one concrete detail from the prompt: a latch, cuff, candle tin, bootprint, or handwriting. "
    "Do not invent a person in the room, a remembered visit, or a confirmed supernatural explanation. "
    "Avoid stock phrases such as I knew, I didn't ask for this, and I shouldn't have come. "
    "Vary the sentence openings. Use plain speech, physical discomfort, and restrained self-directed irritation. "
    "Do not explain and do not be helpful."
)

PAGES = {
    "Field Note — Day 3": "Ridge still open. Mara stopped at the pines and lifted her hand. I told her it was a skier. It was not wearing skis. She says it lifted its hand after she did. The cabin lantern was lit when I woke. I do not remember lighting it.",
    "from the pack": "Strap stamped M. Aune. The candle has not been burned. I counted the prints twice. The second count had one more, and it stopped where the mat is. The mat was straight. None of them lead back to the pack.",
    "torn page": "It stands where the snow will not settle on the branches. I held my breath and the lantern did not care. The lights were already on at the end. Mara said a car. The road is closed.",
    "the handwriting changes": "Mara did not lift her hand. I lifted mine. The gap lifted it back. I am writing with the hand that waved. The line did not fog. The lantern is out if you walk away and lit if you go back. The mat is still straight.",
    "don't": "Stay until the end of the line. I stamped the strap. I am not the one who waved. Three strikes on the door means you are counting for whatever is on the step. The lights have been on longer than the snow. It is behind you.",
    "by the bed": "The lantern was already burning. I did not light it. The candle is burned to the tin. The wool is still warm. It is not from me. I do not know your name.",
    "intake": "Length under the sheet: 1.6 m. Brought down from the step. Initial copied from the strap: R. The rest of the name was not taken down. A second stroke was started and left.",
}

PLACES = {
    "bedroom": "the bedroom, and the wool that was already warm",
    "hall": "the front hall, and the door to the snow",
    "living": "the living room, with the candle burned down",
    "backhall": "the back hall, and the stairs going down",
    "stair": "the stairs down under the house",
    "landing": "the bottom of the stairs",
    "corridor": "a cellar corridor",
    "janitor": "a janitor's room in the cellar",
    "morgue": "the room with the chambers, and a sheet",
    "snow": "the snow outside, after the wool and the lantern",
    "lights": "the lights at the far end of the field, already on",
}

BORED = [
    "She has been standing still in the cold and she is bored. Angsty small talk. Not a plan.",
    "She is tired of her own feet and of not moving. One bitter mutter.",
    "The quiet has gone on too long. She talks to herself so it is not the only voice.",
    "She does not want to be the person the pages are writing about. She says so, briefly.",
    "She is watching the snow do nothing. She resents standing in it.",
    "She thinks about the road and does not start walking. Angsty, not hopeful.",
    "She has been still long enough to start counting things that are not hers.",
    "She misses nothing in particular and is annoyed that she noticed.",
]


def ask(prompt: str) -> str:
    body = json.dumps({
        "max_tokens": 40,
        "temperature": 0.8,
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": prompt},
        ],
    }).encode("utf-8")
    request = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = json.load(response)
    text = payload["choices"][0]["message"]["content"].replace("\n", " ").strip().strip('"')
    for mark in (". ", "! ", "? "):
        at = text.find(mark)
        if at >= 0:
            text = text[: at + 1]
            break
    return text.strip()


def main() -> None:
    pages = {}
    for title, excerpt in PAGES.items():
        line = ask(f'She just opened a page titled "{title}". It says: {excerpt} She answers the claim. She does not summarize it.')
        pages[title] = line
        print("page", title, "->", line)
    places = {}
    for key, about in PLACES.items():
        line = ask(f"She has just come upon {about}. One muttered reaction, as if she expected it and resents that.")
        places[key] = line
        print("place", key, "->", line)
    bored = []
    for prompt in BORED:
        line = ask(prompt)
        bored.append(line)
        print("bored ->", line)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"pages": pages, "places": places, "bored": bored}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
