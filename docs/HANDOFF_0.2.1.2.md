# Handoff: release 0.2.1.2 and Ophelia's voice at the door

Written 2026-10-06 by session `run-d0` on the ThinkPad (Iris Xe, no CUDA), when the user asked it to stop. Nothing in this file has been committed or pushed. Delete it once the release is out.

## Goal

Publish **Ophelia's Dream 0.2.1.2** (0.2.1.1 + 0.0.0.1) as a signed GitHub release with the Windows x64 build. First, fix the problem the user wants fixed: **in the meeting at the door, Ophelia's voice does not match her voice everywhere else.**

The user rejected both easy ways out. Shipping the mismatched drafts and shipping the meeting with subtitles only were both offered, and the answer was "resolve the problem".

## Where things stand

| Item | State |
|---|---|
| Branch | `mathilda-story` (not `main`) |
| `v0.2.1.1` | Released and pushed: commit `9927ac3`, signed tag, asset `Ophelias-Dream-0.2.1.1-win-x64.exe`. https://github.com/soulwax/Ophelias-Dream/releases/tag/v0.2.1.1 |
| `6995932` | "Add audio assets and update dialogue system for Mathilda's chapter". Signed (G), soulwax. **Local only: the branch is 1 ahead of origin.** It contains `run-23`'s meeting work: 39 Kokoro draft clips in `assets/audio/voice/meeting/draft/` with their `.import` files, `timing.json` pointing at them, `docs/DIALOGUE.md`, `docs/MATHILDA_POV.md`, `docs/MEETING_VOICE.md`, and the `_returning` to `_going_home` rename in `scripts/player/mathilda_pov.gd` and `tools/meeting_probe.gd`. |
| Unstaged | `scripts/ui/conversation_menu.gd`. `run-23`'s fix: a mouse cursor resting over the topic list no longer steals the first topic. `run-23` says it belongs in the release. |
| Version | Still `0.2.1.1` in `project.godot` and both version fields of `export_presets.cfg`. Not bumped yet. |
| CHANGELOG | Has a `0.2.1.1` entry. No `0.2.1.2` entry yet. |

`run-23`'s report on its work (run on its working tree, before `6995932`):

- `python tools/bake_meeting.py --check` passes: 39 lines, 75 transitions, 64 paths, coherent.
- `python tools/dialogue_post.py --check` passes.
- `tools/meeting_probe.tscn` prints MEETING PASS with 39 draft voices.
- `mathilda_probe`, `dialogue_probe`, `voice_probe` and `journal_probe` all pass.
- A windowed capture of the open meeting renders correctly.

I did not re-run these after `6995932`.

## The problem, exactly

The meeting has 39 lines: **20 Ophelia, 19 Mathilda** (`assets/audio/voice/meeting/lines.json`). All 39 play from Kokoro drafts (`tools/bake_meeting.py --engine kokoro`, `DRAFT_VOICES`).

- **Ophelia's drafts are wrong.** They are Kokoro `af_sarah` at 0.92. Her 137 field lines are Chatterbox clones of her mood impressions, `tools/voice/ref/<mood>.wav` (16 refs plus `anchor.wav`, locked in `tools/voice/voice_lock.json`). Her voice audibly changes when the meeting starts.
- **Mathilda's drafts are right for now.** Her chapter lines are Kokoro `af_bella` at 0.94 (`tools/bake_mathilda.py:33`), and her meeting drafts use the same voice. She sounds the same at the door as in her chapter.

So the fix is only about Ophelia's 20 lines.

**Watch out:** the documented "finals" path (`build/voice/cb-venv/Scripts/python.exe tools/bake_meeting.py --engine chatterbox`, `docs/MEETING_VOICE.md` stage 3b) re-voices *both* speakers. It needs Mathilda's refs at `tools/voice/ref/mathilda/<mood>.wav`, which don't exist. It would also put Mathilda's meeting in a Chatterbox voice that no longer matches her `af_bella` chapter, unless her chapter is re-baked from the same refs. The full path is "Ophelia done; Mathilda not built" in the stage table. Don't run it as a quick fix.

## Options

### A. Chatterbox finals for Ophelia only (best quality; needs the CUDA desktop)

On the RTX 3070 Ti desktop, which has `build/voice/cb-venv` with CUDA torch, `HF_HOME=build/voice/hf/cache` and the cached models:

1. Change `tools/bake_meeting.py` so the Chatterbox engine can be limited to one speaker, e.g. `--speaker ophelia`. Today `bake()` exits when *any* line's ref is missing (lines 275–277), and Mathilda's refs are missing. Skip the other speaker's lines instead of exiting.
2. `build/voice/cb-venv/Scripts/python.exe tools/bake_meeting.py --engine chatterbox --speaker ophelia`. Each line gets 3 takes, conditioned on `tools/voice/ref/<mood>.wav`, with exaggeration scaled by the line's intensity. The Judge keeps a take only if WER ≤ 0.15 and speaker similarity ≥ `MIN_SIMILARITY` (0.72) against that mood's ref. Don't use `--accept-bad` without the user's say-so.
3. `python tools/dialogue_post.py` cleans and levels the takes and rewrites `timing.json` (Ophelia lines become `final`, Mathilda stays `draft`). Then `python tools/dialogue_post.py --check` and `python tools/bake_meeting.py --check`.
4. `docs/MEETING_VOICE.md` § Sign-off says nothing moves from draft to final until full-path previews are heard and signed off. Stage 8, `--preview`, is not built. At minimum, have the user listen to the 20 new Ophelia clips next to a few field lines in the same mood before releasing. Better, play the meeting in game (`RUN_SPAWN` is not needed; choose MATHILDA in the menu, examine cups, gloves and note, choose Return, speak to Ophelia).
5. Update the stage table in `docs/MEETING_VOICE.md` (3b: Ophelia done).

### B. Voice-convert Ophelia's 20 drafts to her timbre (works on CPU; untested)

This keeps Kokoro's timing and delivery and swaps in her voice identity with `ChatterboxVC`, the same model `bake_speech.py --unify` uses (`bake_speech.py:313`). It's close to stage 4 in `MEETING_VOICE.md`, with a TTS read standing in for a human scratch read.

- On this ThinkPad, `build/voice/dialogue-venv` already has torch `2.6.0+cpu`, torchaudio, `chatterbox-tts 0.1.7`, librosa and soundfile. All of them import. There is **no** `build/voice/hf` cache here, so the Chatterbox weights would download on first use (a few GB). `bake_speech.py` hard-codes `device="cuda"` for `ChatterboxVC` (line 323) and `ChatterboxTTS` (216). A CPU path needs a device switch.
- Target ref per line: `tools/voice/ref/<line mood>.wav` (all are already unified to `steady`'s voice).
- Then run `dialogue_post.py` as in A step 3. Whether VC output should count as `final` or `draft` in `timing.json` is a question for the author; record it either way in `MEETING_VOICE.md`.
- Downsides: the delivery is still Kokoro's, flatter than Chatterbox's mood conditioning. It is also unmeasured. Judge the result with `bake_speech.Judge` similarity against the mood ref, the same 0.72 bar, before using it.
- **This ThinkPad has hard-frozen under load before** (CLAUDE.md). A long CPU torch job is a real risk. Use `./tools/run_blackbox.ps1`-style care: run it in small batches, save each clip as soon as it's made, and close the game while it runs.

### C. Not acceptable to the user

Shipping the `af_sarah` drafts as they are, or dropping the drafts so the meeting is subtitles only. Both were offered and declined.

**Recommendation:** A on the desktop. Use B only if the release has to go out from the ThinkPad, and then tell the user it's a stopgap.

## Release procedure for 0.2.1.2 (once the voice is fixed)

Use the `signed-release` skill (`C:\Users\soulwax\.claude\skills\signed-release\SKILL.md`). It is the source of truth; these notes are what applied in practice for 0.2.1.1.

1. **Decide what goes in.** `6995932` plus the voice fix plus `scripts/ui/conversation_menu.gd`. Confirm the `conversation_menu.gd` change with `run-23` or the user if it's still unstaged. Stage named paths only. Never stage `build/`, `.godot/`, `godot.gdkey` or scratch files.
2. **Bump the version** in `project.godot` (`config/version`) and `export_presets.cfg` (`application/file_version` and `application/product_version`): `0.2.1.1` to `0.2.1.2`. Add a `## 0.2.1.2 — <date>` entry at the top of `CHANGELOG.md`: the conversation menu fix, Ophelia's meeting voice now matching her own, and whatever else is in `6995932` that players notice.
3. **Commit.** This environment appends a `Co-authored-by: Cursor` trailer to any command line containing `git commit`, and the user wants no co-author. Use the skill's `commit-tree` recipe: real git at `C:\Program Files\Git\cmd\git.exe`, `GIT_AUTHOR_*` and `GIT_COMMITTER_*` set to soulwax / soulwax-95@protonmail.com, `-S10FC7065C1CC17351D75D617C13B61245F467316`, then `update-ref HEAD`. Message: one plain sentence, e.g. "Release Ophelia's Dream 0.2.1.2 with Ophelia's own voice at the door and a steadier conversation menu." Check `git log -1 --format="%an %ae%n%G?%n%B"`: G, soulwax, no Co-authored-by.
4. **Export from a clean worktree, not the working tree.** Other sessions edit files while you work. During 0.2.1.x a rename landed mid-export, so the first build had to be thrown away.
   ```powershell
   $wt = "C:\Users\soulwax\Workspace\Godot\run-release-0.2.1.2"
   git worktree add --detach $wt HEAD
   robocopy .godot "$wt\.godot" /E /NFL /NDL /NJH /NJS /NP   # reuse the import cache; skips a 1 GB reimport
   New-Item -ItemType Directory -Force "$wt\build\windows" | Out-Null
   & "C:\Users\soulwax\scoop\apps\godot-mono\4.7.2\godot-mono.console.exe" --headless --path $wt --export-release "Windows Desktop" "build/windows/Ophelia's Dream.exe"
   ```
   - New `.wav` files (the voice fix) need importing in the worktree first, or copy their `.godot/imported` entries. Running `--headless --path $wt --import` before exporting is the safe choice.
   - Mono templates are present at `scoop\apps\godot-mono\4.7.2\editor_data\export_templates\4.7.2.stable.mono\windows_release_x86_64.exe`, so `custom_template` stays empty. The 0.2.1.1 build was about 1.1 GB, unencrypted, with the PCK embedded in the exe.
   - The only gitignored files under `assets/` are `.blend1` backups, so the worktree is missing nothing the game needs.
5. **Tag and push**, only after the export succeeded:
   ```powershell
   & $git tag -s -u 10FC7065C1CC17351D75D617C13B61245F467316 v0.2.1.2 -m v0.2.1.2
   & $git push origin HEAD; & $git push origin v0.2.1.2
   ```
   This also pushes `6995932`, which is currently local only.
6. **Publish:**
   ```powershell
   Copy-Item "$wt\build\windows\Ophelia's Dream.exe" "build/windows/Ophelias-Dream-0.2.1.2-win-x64.exe"
   gh release create v0.2.1.2 "build/windows/Ophelias-Dream-0.2.1.2-win-x64.exe" --title "Ophelia's Dream v0.2.1.2" --notes "<a few sentences in plain prose>"
   ```
   Then check with `gh release view v0.2.1.2 --json assets,isDraft,isPrerelease` that the asset is `uploaded`. Remove the worktree with `git worktree remove --force $wt`.

## Gotchas

- **Godot binary.** On this ThinkPad only `godot-mono` is installed (`C:\Users\soulwax\scoop\apps\godot-mono\4.7.2\godot-mono.console.exe`). Plain `godot` is not on PATH in PowerShell or Git Bash.
- **Other sessions.** `run-23` did the meeting work and said it won't commit unless asked. Someone committed it as `6995932` anyway; it may have been the user. Message `run-23` before touching meeting files.
- **Clip names** for the field lines are SHA-256 of `text|mood`. Nothing is deleted: `bake_speech.py` moves replaced clips to `build/voice/archive/`.
- **`tools/bake_voice.py` is obsolete** and overwrites the voice script. Don't run it.
- **Timing sources.** `timing.json` records which file each line plays (`final` / `draft` / `none`). After any clip change, run `python tools/dialogue_post.py`, or its `--check` and the meeting probe will fail.
- **Version format** is four parts. Bump the last part only for this release.

## Open questions for the user

1. Option A on the desktop, or B now on the ThinkPad as a stopgap?
2. Should Mathilda eventually get Chatterbox refs too (stage 3a)? That would mean re-baking her chapter lines from those refs so her chapter and meeting voices still match. That is a bigger job than this release.
3. Should anything be merged to `main`? Every release so far has been tagged from `mathilda-story`.
