#!/usr/bin/env bash
# Install the Claude Code voice agent (Hume Octave TTS via Stop hook).
# Idempotent: safe to re-run. Merges into existing ~/.claude config.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- prereqs ----
for cmd in jq curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { printf '❌ missing dependency: %s\n' "$cmd" >&2; exit 1; }
done

mkdir -p "$HOME/.claude/hooks"

# ---- install hook scripts ----
install -m 755 "$HERE/hooks/tts-stop.sh"      "$HOME/.claude/hooks/tts-stop.sh"
install -m 755 "$HERE/hooks/tts-interrupt.sh" "$HOME/.claude/hooks/tts-interrupt.sh"
printf '✅ hooks installed → ~/.claude/hooks/\n'

# ---- merge settings.json ----
SETTINGS="$HOME/.claude/settings.json"
SNIPPET="$HERE/settings.json.snippet"
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"
fi
TMP=$(mktemp)
python3 "$HERE/merge-settings.py" "$SETTINGS" "$SNIPPET" > "$TMP"
mv "$TMP" "$SETTINGS"
printf '✅ settings.json merged → %s\n' "$SETTINGS"

# ---- append CLAUDE.md instructions ----
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
MARKER="## TTS Summary (voice agent)"
touch "$CLAUDE_MD"
if grep -qF "$MARKER" "$CLAUDE_MD"; then
  printf 'ℹ️  CLAUDE.md already has TTS Summary block — skipping\n'
else
  printf '\n\n' >> "$CLAUDE_MD"
  cat "$HERE/CLAUDE.md.snippet" >> "$CLAUDE_MD"
  printf '✅ CLAUDE.md appended\n'
fi

printf '\nNext steps:\n'
printf '  1. Stash your Hume key (no chat paste):\n'
printf '       pw2agent hume_api      # writes ~/.hume_api_pw (mode 600, base64)\n'
printf '     OR export HUME_API_KEY=... in your shell rc.\n\n'
printf '  2. Confirm the Cara voice. Install the Hume CLI if you want:\n'
printf '       npm install -g @humeai/cli && hume login\n'
printf '       hume voices list --provider HUME_AI | grep -i cara\n'
printf '       hume voices list                            # your custom voices\n'
printf '     If not under HUME_AI, set in shell rc:\n'
printf '       export HUME_VOICE_PROVIDER=CUSTOM_VOICE\n'
printf '     If renamed:\n'
printf '       export HUME_VOICE_NAME="YourVoice"\n\n'
printf '  3. Smoke test the hook directly:\n'
printf '       printf %%s '"'"'{"last_assistant_message":"Quick test of the voice."}'"'"' \\\n'
printf '         | ~/.claude/hooks/tts-stop.sh\n'
printf '     (wait ~3 seconds for audio)\n\n'
printf '  4. Toggle off any time:  export CC_VOICE=0\n'
