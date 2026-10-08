"""Check the Studio's curated Hugging Face catalog without downloading weights."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio import models  # noqa: E402


def main():
    assert len(models.CATALOG) == 3
    for key, entry in models.CATALOG.items():
        assert key == entry["id"]
        assert entry["path"].is_relative_to(models.HF_ROOT)
        assert entry["repo"].startswith("Qwen/")

    original_which = models.shutil.which
    models.shutil.which = lambda name: "uv.exe" if name == "uv" else None
    try:
        action = models.download_action("qwen-voice-design")
        command = action["commands"][0]
        assert command[command.index("download") + 1] == models.CATALOG["qwen-voice-design"]["repo"]
        assert command[-1] == str(models.CATALOG["qwen-voice-design"]["path"])
        try:
            models.download_action("https://huggingface.co/someone/arbitrary")
        except ValueError:
            pass
        else:
            raise AssertionError("arbitrary Hugging Face repositories must not be accepted")
    finally:
        models.shutil.which = original_which

    assert models.CATALOG["qwen-custom-voice-small"]["mode"] == "custom-small"
    assert "can_unify" in models.view()
    print(f"Curated model catalog checked: {len(models.CATALOG)} entries")


if __name__ == "__main__":
    main()
