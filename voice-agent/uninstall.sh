#!/usr/bin/env bash
# Remove the voice-agent hooks from ~/.claude.
# Leaves settings.json and CLAUDE.md edits in place — you can drop those by hand.
set -euo pipefail

rm -f "$HOME/.claude/hooks/tts-stop.sh"
rm -f "$HOME/.claude/hooks/tts-interrupt.sh"
rm -f "$HOME/.claude/.tts-last-hash"
rmdir "$HOME/.claude/hooks" 2>/dev/null || true

printf '✅ hook scripts removed.\n'
printf 'ℹ️  ~/.claude/settings.json and ~/.claude/CLAUDE.md still contain voice-agent\n'
printf '   entries — edit those by hand if you want a full clean.\n'
