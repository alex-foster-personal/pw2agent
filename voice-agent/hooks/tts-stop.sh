#!/usr/bin/env bash
# Claude Code Stop hook: speak Claude's last response with Hume Octave TTS.
#
# Strictly read-only: the full text response is already in the transcript
# before this hook runs. The hook never echoes content back into the session,
# so chat context is always intact.
#
# Strategy: extract the TTS_SUMMARY marker if Claude included one (cheap,
# instant). If absent, pipe the response to `claude -p --model sonnet` to
# rewrite it as a short spoken script. Synthesize via Hume, play with afplay.
#
# Env knobs:
#   CC_VOICE=0              disable speech for this session
#   HUME_API_KEY=...        Hume API key (falls back to base64-decoded ~/.hume_api_pw)
#   HUME_VOICE_NAME=Cara    voice name
#   HUME_VOICE_PROVIDER=HUME_AI    or CUSTOM_VOICE for your own saved voices
#   CC_VOICE_MODEL=claude-sonnet-4-6    model for the rewrite fallback

set -uo pipefail

INPUT=$(cat)

[ "${CC_VOICE:-1}" = "0" ] && exit 0

# Don't fire when Claude Code is continuing under hook control
STOP_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$STOP_ACTIVE" = "true" ] && exit 0

(
  # Brief settle so the transcript JSONL finishes flushing
  sleep 1

  RESPONSE=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)

  if [ -z "$RESPONSE" ]; then
    TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
    TRANSCRIPT="${TRANSCRIPT/#\~/$HOME}"
    if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
      RESPONSE=$(python3 - "$TRANSCRIPT" <<'PY'
import json, sys
path = sys.argv[1]
out = ""
seen_tool_result = False
try:
    with open(path) as f:
        lines = f.readlines()
    for line in reversed(lines):
        try:
            obj = json.loads(line)
        except Exception:
            continue
        t = obj.get("type")
        if t == "tool_result":
            seen_tool_result = True
            continue
        if t == "assistant":
            blocks = obj.get("message", {}).get("content", [])
            text = "\n".join(b.get("text","") for b in blocks if b.get("type") == "text")
            if text and not seen_tool_result:
                out = text
                break
except Exception:
    pass
print(out)
PY
)
    fi
  fi

  [ -z "$RESPONSE" ] && exit 0

  # Dedup: don't re-speak the same response if the hook fires twice
  HASH=$(printf '%s' "$RESPONSE" | { md5sum 2>/dev/null || md5 -q; } | awk '{print $1}')
  HASH_FILE="$HOME/.claude/.tts-last-hash"
  if [ -n "$HASH" ] && [ -f "$HASH_FILE" ] && [ "$(cat "$HASH_FILE")" = "$HASH" ]; then
    exit 0
  fi
  [ -n "$HASH" ] && printf '%s' "$HASH" > "$HASH_FILE"

  # 1) Try the TTS_SUMMARY marker
  SPOKEN=$(printf '%s' "$RESPONSE" | python3 -c '
import sys, re
text = sys.stdin.read()
m = re.search(r"<!--\s*TTS_SUMMARY\s*(.*?)\s*TTS_SUMMARY\s*-->", text, re.DOTALL)
if m: print(m.group(1).strip())
')

  # Explicit silence marker
  if [ "$SPOKEN" = "SILENT" ]; then exit 0; fi

  # 2) Fallback: headless Sonnet rewrite
  if [ -z "$SPOKEN" ] && command -v claude >/dev/null 2>&1; then
    SPOKEN=$(printf '%s' "$RESPONSE" | claude -p \
      --model "${CC_VOICE_MODEL:-claude-sonnet-4-6}" \
      "Rewrite the assistant response below as a short spoken script for text-to-speech.
Rules:
- 2 to 4 conversational sentences, natural spoken English.
- Drop all code, tables, file paths, URLs, command names, and technical jargon.
- Summarize the gist, not the mechanics.
- Output ONLY the spoken text, no preamble, no quotes." 2>/dev/null)
  fi

  [ -z "$SPOKEN" ] && exit 0

  # 3) Synthesize via Hume Octave
  KEY="${HUME_API_KEY:-}"
  if [ -z "$KEY" ] && [ -f "$HOME/.hume_api_pw" ]; then
    KEY=$(base64 -d < "$HOME/.hume_api_pw" 2>/dev/null | tr -d '\n')
  fi
  [ -z "$KEY" ] && exit 0

  VOICE_NAME="${HUME_VOICE_NAME:-Cara}"
  VOICE_PROVIDER="${HUME_VOICE_PROVIDER:-HUME_AI}"
  AUDIO="${TMPDIR:-/tmp}/claude-tts.mp3"

  BODY=$(jq -nc \
    --arg t "$SPOKEN" \
    --arg vn "$VOICE_NAME" \
    --arg vp "$VOICE_PROVIDER" \
    '{utterances:[{text:$t, voice:{name:$vn, provider:$vp}}], format:{type:"mp3"}}')

  curl -sf -X POST https://api.hume.ai/v0/tts/file \
    -H "X-Hume-Api-Key: $KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    --output "$AUDIO" 2>/dev/null || exit 0

  # Stop any prior playback so segments don't overlap
  pkill -x afplay 2>/dev/null
  [ -s "$AUDIO" ] && afplay "$AUDIO" 2>/dev/null
) >/dev/null 2>&1 &

exit 0
