"""Fixed-reference and bounded-emotion checks for experimental auditions."""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio import pipelines  # noqa: E402


def main():
    ophelia, words = pipelines.reference("ophelia", "steady")
    assert ophelia.name == "steady.wav" and "kettle" in words
    mathilda, words = pipelines.reference("mathilda", "steady")
    assert mathilda.is_file() and "tent" in words
    for character, mood in (("stranger", "steady"), ("ophelia", "unknown")):
        try:
            pipelines.reference(character, mood)
        except ValueError:
            pass
        else:
            raise AssertionError("unapproved character reference accepted")
    low = pipelines.chatter_controls("shaken", 0.0)
    high = pipelines.chatter_controls("shaken", 1.0)
    assert low["exaggeration"] < high["exaggeration"]
    assert low["cfg_weight"] > high["cfg_weight"]
    for energy in (-0.1, 1.1, float("nan")):
        try:
            pipelines.chatter_controls("steady", energy)
        except ValueError:
            pass
        else:
            raise AssertionError("out-of-range energy accepted")
    with tempfile.TemporaryDirectory() as directory:
        folder = Path(directory)
        source, anchor = folder / "take.wav", folder / "steady.wav"
        source.write_bytes(b"expressive take")
        anchor.write_bytes(b"approved character")
        first = pipelines.identity_output(source, anchor, folder)
        assert first == pipelines.identity_output(source, anchor, folder)
        anchor.write_bytes(b"new approved character")
        assert first != pipelines.identity_output(source, anchor, folder)
        anchor.write_bytes(b"approved character")
        source.write_bytes(b"new expressive take")
        assert first != pipelines.identity_output(source, anchor, folder)
    print("Voice references, exact transcripts, and bounded emotion controls checked")


if __name__ == "__main__":
    main()
