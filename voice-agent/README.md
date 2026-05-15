# voice-agent

A Claude Code `Stop` hook that speaks each response with Hume Octave TTS.

The key design: the hook runs **after** Claude's full text response is already
written to the transcript and is **read-only**. It generates audio as a
dead-end side effect — nothing is ever fed back into the chat. So your
conversational context is always complete, and "the agent put everything in
the voice and nothing in text" cannot happen here.

## How it generates the spoken script

Hybrid, in order of preference:

1. **Marker.** A line in `~/.claude/CLAUDE.md` tells Claude to append a hidden
   `<!-- TTS_SUMMARY ... TTS_SUMMARY -->` block after its normal answer. The
   hook extracts the marker's contents and speaks just that. Zero added
   latency, zero extra API calls.
2. **Headless Sonnet rewrite (fallback).** If the marker is missing, the
   hook pipes the response to `claude -p --model claude-sonnet-4-6` with a
   prompt to rewrite it as a short spoken script (no code, tables, paths,
   jargon). Adds a couple of seconds + one model call per turn.
3. **`SILENT`.** Write `<!-- TTS_SUMMARY SILENT TTS_SUMMARY -->` to skip
   speech for a turn.

Audio path: hook → Hume `/v0/tts/file` (mp3) → `afplay` on macOS, backgrounded
so Claude is never blocked.

## Install

```bash
git clone <this repo>
cd pw2agent/voice-agent
./install.sh
```

Then:

1. **Stash your Hume key** (no chat paste, no shell history):
   ```bash
   pw2agent hume_api      # creates ~/.hume_api_pw (mode 600, base64)
   ```
   …or `export HUME_API_KEY=...` in your shell rc.

2. **Confirm the "Cara" voice** (it's the unconfirmed bit — the Hume Voice
   Library is login-gated):
   ```bash
   npm install -g @humeai/cli && hume login
   hume voices list --provider HUME_AI | grep -i cara   # library
   hume voices list                                     # your custom voices
   ```
   - If she's under `--provider HUME_AI`: nothing to do, that's the default.
   - If she's a custom-saved voice on your account:
     `export HUME_VOICE_PROVIDER=CUSTOM_VOICE`
   - If renamed: `export HUME_VOICE_NAME="..."`
   - If she's gone, generate a Californian-accent voice via Voice Design at
     <https://app.hume.ai/voices> and save it as "Cara".

3. **Smoke test**:
   ```bash
   printf '%s' '{"last_assistant_message":"Quick test of the voice."}' \
     | ~/.claude/hooks/tts-stop.sh
   # wait ~3s for audio
   ```

## Configuration (env vars)

| Var | Default | Effect |
|---|---|---|
| `CC_VOICE` | `1` | `0` disables speech for the session |
| `HUME_API_KEY` | — | Hume key; falls back to base64 `~/.hume_api_pw` |
| `HUME_VOICE_NAME` | `Cara` | Voice to use |
| `HUME_VOICE_PROVIDER` | `HUME_AI` | or `CUSTOM_VOICE` for your saved voices |
| `CC_VOICE_MODEL` | `claude-sonnet-4-6` | Model for the rewrite fallback |

## Files installed

- `~/.claude/hooks/tts-stop.sh` — the Stop hook
- `~/.claude/hooks/tts-interrupt.sh` — UserPromptSubmit hook, kills in-flight
  audio when you start a new turn
- `~/.claude/settings.json` — merged: adds `Stop` and `UserPromptSubmit` hook
  entries (other existing hooks are preserved; the merge is idempotent)
- `~/.claude/CLAUDE.md` — appended: the TTS_SUMMARY instruction block

## Uninstall

```bash
./uninstall.sh
```
Removes the hook scripts. Strip the `settings.json` and `CLAUDE.md` entries by
hand if you want a full clean.

## Known gaps

- **macOS only** for playback (`afplay`). Trivial to swap for `mpg123`/`paplay`
  on Linux — edit the bottom of `tts-stop.sh`.
- **"Cara" voice unconfirmed.** Hume's library is login-gated so I couldn't
  verify her existence from public docs. Step 2 above is the manual check.
