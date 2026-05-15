# Voice agent — handoff

You're switching laptops. This is where we left off and what to do next.

## What's already done

The `voice-agent/` directory in this repo (branch `claude/setup-voice-agents-SlrtL`,
PR <https://github.com/alexfosterinvisible/pw2agent/pull/1>) is a complete,
installable bundle that rebuilds your old Hume + Sonnet setup:

- `hooks/tts-stop.sh` — Claude Code `Stop` hook. Read-only post-processor.
  Extracts a `<!-- TTS_SUMMARY ... -->` marker if Claude included one; else
  pipes the response through a headless `claude -p --model claude-sonnet-4-6`
  rewrite. Sends the result to Hume Octave (voice "Cara", provider HUME_AI),
  plays via `afplay`. Backgrounded, exits 0, dedupes by md5 hash.
- `hooks/tts-interrupt.sh` — `UserPromptSubmit` hook that `pkill`s in-flight
  audio so the next turn starts cleanly.
- `install.sh` + `merge-settings.py` — idempotent installer. Merges into any
  existing `~/.claude/settings.json` without clobbering other hooks. Appends
  the TTS_SUMMARY instruction block to `~/.claude/CLAUDE.md` if not already
  there.

This solves the original pain points by design:
- **"output went to voice not text"** can't happen — the hook never touches
  the transcript; it only reads the already-written response.
- **truncation / can't hear everything** — synthesis is a complete short
  script (2–4 sentences), played via the file endpoint not a stream, with
  `pkill` on new turns to prevent overlap.

## Getting it onto your Mac

```bash
# pick a home for the repo
cd ~/src   # or wherever you keep code

# clone and switch to the voice branch
git clone https://github.com/alexfosterinvisible/pw2agent.git
cd pw2agent
git checkout claude/setup-voice-agents-SlrtL

# install (idempotent — safe to re-run)
cd voice-agent
./install.sh
```

The installer needs `jq`, `curl`, `python3` — all standard on macOS / Homebrew.

## Get the Hume key in place

You said you'd grab it from the MacBook Air. Two options:

**Option A — env var (simpler).** Add to your `~/.zshrc`:
```bash
export HUME_API_KEY="hume_..."
```

**Option B — the pw2agent stash pattern (no shell history, no chat paste).**
First install the `pw2agent` CLI from this same repo (`./install.sh` at repo
root), then:
```bash
pw2agent hume_api      # prompts twice, writes ~/.hume_api_pw mode 600 base64
```
The voice hook reads `HUME_API_KEY` first, falls back to `~/.hume_api_pw`.

## Confirm the "Cara" voice

The Hume Voice Library is login-gated, so I couldn't verify "Cara" from
public docs. Once the key is set:

```bash
npm install -g @humeai/cli
hume login
hume voices list --provider HUME_AI | grep -i cara   # check the library
hume voices list                                     # check your custom voices
```

- **Library hit** → nothing to do, defaults are `name=Cara, provider=HUME_AI`.
- **Custom voice on your account** → `export HUME_VOICE_PROVIDER=CUSTOM_VOICE`
  in `~/.zshrc`.
- **Renamed** → `export HUME_VOICE_NAME="…"`.
- **Gone** → generate a Californian-accent voice via Voice Design at
  <https://app.hume.ai/voices>, save it as "Cara", set
  `HUME_VOICE_PROVIDER=CUSTOM_VOICE`.

## Smoke test

```bash
printf '%s' '{"last_assistant_message":"Quick test of the voice."}' \
  | ~/.claude/hooks/tts-stop.sh
# wait ~3 seconds — you should hear Cara say the test phrase
```

If you hear nothing, check (in order):
1. `echo $HUME_API_KEY` — is it set?
2. `ls -la ~/.claude/hooks/` — both scripts present and executable?
3. Run the hook in the foreground without backgrounding to see errors:
   ```bash
   bash -x ~/.claude/hooks/tts-stop.sh <<<'{"last_assistant_message":"test"}' 2>&1 | tail -40
   ```
   The first thing it does is `sleep 1`, then it'll show the curl call.
4. Hit Hume directly to confirm the key + voice:
   ```bash
   curl -i -X POST https://api.hume.ai/v0/tts/file \
     -H "X-Hume-Api-Key: $HUME_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"utterances":[{"text":"hi","voice":{"name":"Cara","provider":"HUME_AI"}}],"format":{"type":"mp3"}}' \
     --output /tmp/h.mp3
   afplay /tmp/h.mp3
   ```

## Try it live

Start a Claude Code session in any project. Send a normal prompt. You should
see:
- Your full text response renders in chat **as normal** (this is the
  important bit — context isn't going anywhere).
- Within a few seconds of Claude finishing, Cara reads a 2–4 sentence
  spoken-friendly summary.
- If you start typing a new prompt mid-speech, the audio cuts off cleanly.

## Toggles

| Env var | Default | What it does |
|---|---|---|
| `CC_VOICE` | `1` | `CC_VOICE=0` silences speech for the session |
| `HUME_VOICE_NAME` | `Cara` | Switch voices on the fly |
| `HUME_VOICE_PROVIDER` | `HUME_AI` | or `CUSTOM_VOICE` |
| `CC_VOICE_MODEL` | `claude-sonnet-4-6` | Model for the rewrite fallback |

## If something's off

- **Hook never fires** → `cat ~/.claude/settings.json` and confirm the
  `Stop` and `UserPromptSubmit` entries are there. Re-run `./install.sh` if
  not.
- **Doubled audio** → delete `~/.claude/.tts-last-hash` and retry. The hook
  uses it for dedup.
- **Wants to roll back entirely** → `./uninstall.sh` removes the scripts.
  Strip the `settings.json` and `CLAUDE.md` entries by hand.

## Open items for me / future me

- Verify "Cara" exists on your Hume account once the key is in place.
- macOS-only playback (`afplay`). Edit the bottom of `tts-stop.sh` for
  Linux (`mpg123 -q` / `paplay`).
- Could add a `/voice on|off` slash command later if the env var toggle gets
  annoying.
