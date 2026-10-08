# Handoff: Ophelia's last five meeting lines, and how releases are cut

Updated 2026-10-06, after **v0.2.1.4**. It replaces `HANDOFF_0.2.1.2.md`, which was written before any final meeting clips existed.

## In one paragraph

Ophelia's Dream is released from the `mathilda-story` branch as signed tags with a Windows x64 exe on GitHub. The last release is **v0.2.1.4** (`0903fc9`). Its main change: in the meeting at the door (Mathilda's chapter, after she chooses Return), Ophelia now speaks **15 of her 20 lines** in her own Chatterbox voice, the one she has in the field. **Five lines are still Kokoro `af_sarah` drafts** and sound like a different woman. Finishing those five is the open job. Then cut v0.2.1.5 with the procedure below.

## Where things stand

| Item | State |
|---|---|
| Branch | `mathilda-story`, in sync with origin at `0903fc9`. Releases have never been merged to `main`; `main` has been merged *into* this branch (`dad2fdf`, `8fa91df`). |
| Releases | v0.2.1.1 (`9927ac3`), v0.2.1.3 (`17eee1e`), v0.2.1.4 (`0903fc9`). All have signed tags and an `Ophelias-Dream-<version>-win-x64.exe` asset. There is no v0.2.1.2; the user skipped it. |
| Version | `0.2.1.4` in `project.godot` (`config/version`) and `export_presets.cfg` (`application/file_version`, `application/product_version`). The next release is **0.2.1.5**; the user bumps the last part by one. |
| Checks at `0903fc9` | All pass: `bake_meeting.py --check` (39 lines, 75 transitions, 64 paths), `dialogue_post.py --check`, `script_to_lines.py --check`, and the meeting, Mathilda, dialogue, voice and journal probes (voice and journal with `PROBE_CLIPS=1`). |
| Uncommitted | Only two tracked `tools/__pycache__/*.pyc` files, rewritten by running the Python checks. Leave them out of commits (see Loose ends). |

## The open job: five Ophelia lines

Meeting voices, from `assets/audio/voice/meeting/timing.json` (`source`) and `lines.json` (`speaker`):

| Speaker | Final (Chatterbox, own voice) | Draft (Kokoro) |
|---|---|---|
| Ophelia | 15 | **5** |
| Mathilda | 0 | 19, which is intended |

**Mathilda is not part of this job.** Her chapter lines are Kokoro `af_bella` at 0.94 (`tools/bake_mathilda.py:33`), and her meeting drafts use the same voice, so she already sounds like herself. Don't run the Chatterbox bake for her: `tools/voice/ref/mathilda/` doesn't exist, and a Chatterbox Mathilda would no longer match her chapter.

The five lines still on drafts:

| id | mood | intensity | text |
|---|---|---|---|
| 03 | shaken | 0.45 | Are you hurt? |
| 21 | warm | 0.40 | You kept it? |
| 23 | hushed | 0.35 | May I take it? |
| a04 | warm | 0.35 | You said they were perfect. |
| a12 | warm | 0.35 | Out here. All right. |

**Probable cause (not verified; the take logs were printed on the desktop and aren't saved in the repo):** all five are very short, two to five words. `best_take` in `tools/bake_meeting.py` keeps a take only if Whisper WER ≤ 0.15 (`bake_speech.MAX_WER`) **and** ECAPA speaker similarity ≥ 0.72 (`MIN_SIMILARITY`) against `tools/voice/ref/<mood>.wav`. On a one-second clip, a single misheard word blows WER past 0.15 (one word in three is 0.33), and speaker embeddings from so little audio come out low and noisy. So every take was probably rejected and the line kept its draft. Three of the five are `warm`, so it's worth checking whether that mood's ref scores low in general.

### How to finish it (on the RTX 3070 Ti desktop)

The bake needs CUDA. The ThinkPad (Iris Xe) has no `build/voice/cb-venv` and no `build/voice/hf` model cache, and it has hard-frozen under load before.

1. Re-run for Ophelia only, with new seeds and more takes. `--first-seed` exists because the same seeds give the same takes:
   ```powershell
   $env:HF_HOME = "build/voice/hf/cache"
   build/voice/cb-venv/Scripts/python.exe tools/bake_meeting.py --engine chatterbox --speaker ophelia --takes 8 --first-seed 4
   ```
   It only performs lines without a final clip. Read the printed `take N: wer … sim … | <what Whisper heard>` lines; they show which gate is failing.
2. If WER is the problem on short lines (Whisper mishearing, or adding punctuation-level words), look at `bake_speech.wer`'s normalisation before loosening anything.
3. If similarity is the problem, **ask the user** before changing `MIN_SIMILARITY` or using `--accept-bad`. They chose the stricter 0.72 for the meeting on purpose (field lines use a lower bar). A reasonable proposal: a lower bar only for clips under about 1.5 s, recorded in `docs/MEETING_VOICE.md`.
4. Then:
   ```powershell
   python tools/dialogue_post.py            # clean, level, rewrite timing.json (sources become final)
   python tools/dialogue_post.py --check
   python tools/bake_meeting.py --check
   godot --headless --path . --import       # creates the .wav.import files; commit them with the clips
   godot --headless --path . tools/meeting_probe.tscn
   ```
5. Listen before releasing. `docs/MEETING_VOICE.md` § Sign-off asks for full-path previews, and stage 8 (`--preview`) isn't built. At minimum, play the meeting in game: choose MATHILDA in the main menu, examine the cups, gloves and note, choose Return, walk back and speak to Ophelia. Check that those five lines sit with the rest.
6. Update the stage table in `docs/MEETING_VOICE.md`. It is stale: 3b and 5 still say "written, not yet run", although 15 Ophelia finals came out of them.

## How to cut a release

The `signed-release` skill (`C:\Users\soulwax\.claude\skills\signed-release\SKILL.md`) is the source of truth. This is the order that worked for v0.2.1.3 and v0.2.1.4, and the traps hit along the way.

1. **Check first:** the three Python `--check`s and the five probes listed above. Run `godot --headless --path . --import` before the probes so new clips are imported.
2. **Commit new `.wav.import` files.** The project commits them. The 15 finals arrived without theirs, and the release commit added them.
3. **Bump** the three version fields and add a `## <version> — <date>` entry at the top of `CHANGELOG.md`: plain sentences about what a player notices, and honest about what's still a placeholder.
4. **Commit with the `commit-tree` recipe, not `git commit`.** This environment appends `Co-authored-by: Cursor` to any command line containing `git commit`, and the user wants no co-author. Use the real git at `C:\Program Files\Git\cmd\git.exe`, author and committer soulwax / soulwax-95@protonmail.com, `-S10FC7065C1CC17351D75D617C13B61245F467316`, then `update-ref HEAD`. Verify with `git log -1 --format="%an %ae%n%G?%n%B"`: you want `G`, soulwax, and no trailer. Stage named paths only, never `build/`, `.godot/`, `godot.gdkey` or `.pyc` files.
5. **Push the branch immediately, and stop if it's rejected.** For v0.2.1.3 someone pushed during the export. The branch push was rejected but the script carried on and published the tag and release anyway, and a signed merge commit (`50b0e1e`) had to fix it. Check `$LASTEXITCODE` after every push. If the push is rejected, integrate with a signed merge commit (`git merge-tree --write-tree HEAD origin/mathilda-story`, then `commit-tree` with both parents). Never force-push.
6. **Export from a clean worktree at the commit**, because other sessions edit files mid-export:
   ```powershell
   $g  = "C:\Users\soulwax\scoop\apps\godot-mono\4.7.2\godot-mono.console.exe"
   $wt = "C:\Users\soulwax\Workspace\Godot\run-release-<version>"
   git worktree add --detach $wt HEAD
   robocopy .godot "$wt\.godot" /E /NFL /NDL /NJH /NJS /NP     # reuse the import cache
   & $g --headless --path $wt --import
   New-Item -ItemType Directory -Force "$wt\build\windows" | Out-Null
   & $g --headless --path $wt --export-release "Windows Desktop" "build/windows/Ophelia's Dream.exe"
   ```
   Mono templates are installed under `scoop\apps\godot-mono\4.7.2\editor_data\export_templates\4.7.2.stable.mono\`, so `custom_template` stays empty in the preset. The exe is about 1.1 GB, unencrypted, with the PCK embedded. The only gitignored files under `assets/` are `.blend1` backups, so the worktree has everything.
7. **Tag, push the tag, and publish:**
   ```powershell
   & $git tag -s -u 10FC7065C1CC17351D75D617C13B61245F467316 v<version> -m v<version>
   & $git push origin v<version>
   Copy-Item "$wt\build\windows\Ophelia's Dream.exe" "build/windows/Ophelias-Dream-<version>-win-x64.exe"
   gh release create v<version> "build/windows/Ophelias-Dream-<version>-win-x64.exe" --title "Ophelia's Dream v<version>" --notes "<a few plain sentences>"
   gh release view v<version> --json assets,isDraft,isPrerelease    # asset state must be "uploaded"
   git worktree remove --force $wt
   ```

## Machines

- **ThinkPad** (`DESKTOP-MJP7U71`, Iris Xe, 16 GB): this is where releases have been cut. Only `godot-mono` is installed; plain `godot` isn't on PATH in PowerShell or Git Bash. `build/voice/venv` (Kokoro) and `build/voice/dialogue-venv` (CPU torch 2.6, `chatterbox-tts` 0.1.7) exist, but there's no Chatterbox model cache. Graphics run lean automatically.
- **Desktop** (RTX 3070 Ti): has `cb-venv` with CUDA and the HF cache under `build/voice/hf`. All Chatterbox baking happens here.

## Loose ends

- **Tracked `.pyc` files.** `tools/__pycache__/*.pyc` (5 files) are tracked, and every Python run rewrites them. Suggest to the user: `git rm --cached -r tools/__pycache__` and add `__pycache__/` to `.gitignore`.
- **Mathilda's own Chatterbox voice** (stage 3a, `tools/voice/ref/mathilda/`) is a separate, larger job. It only makes sense if her chapter lines are re-baked from the same refs, so both of her voices still match. Not planned.
- **`docs/MEETING_VOICE.md` stage table** is stale (see step 6 above).
- **Other sessions** (`run-23` did the meeting work) and the user also commit to this branch, sometimes unsigned. Expect new commits between your checks and your push.
- **`tools/bake_voice.py` is obsolete** and overwrites the voice script. Never run it.
