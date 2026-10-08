"""Conversation chain prompt and bounds checks; no model runtime or downloads needed."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio import chains  # noqa: E402


def main():
    spec = chains.normalize({
        "context": "They are whispering at a locked door in the snow.",
        "profiles": {"ophelia": "Quiet and guarded", "mathilda": "Warm but tired"},
        "variants": 9,
        "seed": 41,
        "turns": [
            {"uid": "doorway/a", "speaker": "ophelia", "mood": "hushed", "text": "Did you hear that?",
             "voice": "Serena", "direction": "Keep the question close."},
            {"uid": "doorway/b", "speaker": "mathilda", "mood": "shaken", "text": "Only the wind.",
             "voice": "Vivian", "direction": "Reassure her, though you are not sure."},
        ],
    })
    assert spec["variants"] == 3
    bounded = chains.normalize({"turns": spec["turns"], "temperature": 4.0})
    assert bounded["temperature"] == 1.2
    prompt = chains.instruction(spec["context"], spec["profiles"],
        [("ophelia", "hushed", "Did you hear that?")], spec["turns"][1], 2, 2)
    assert "locked door" in prompt and "Did you hear that?" in prompt
    assert "Mathilda's response, turn 2 of 2" in prompt
    for payload in ({"turns": []}, {"turns": spec["turns"] + spec["turns"] * 4}):
        try:
            chains.normalize(payload)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid chain length was accepted")
    bad_voice = {"turns": [*spec["turns"]]}
    bad_voice["turns"][0] = {**bad_voice["turns"][0], "voice": "arbitrary"}
    try:
        chains.normalize(bad_voice)
    except ValueError:
        pass
    else:
        raise AssertionError("unsupported Qwen timbre was accepted")
    try:
        chains.normalize({"turns": spec["turns"], "temperature": "nan"})
    except ValueError:
        pass
    else:
        raise AssertionError("non-finite sampling temperature was accepted")
    print("Conversation chain validation and contextual prompt checked")


if __name__ == "__main__":
    main()
