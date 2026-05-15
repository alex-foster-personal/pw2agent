#!/usr/bin/env bash
# UserPromptSubmit hook: kill in-flight TTS audio so a new turn starts fresh.
# Prevents the prior response's speech from talking over your next prompt.
pkill -x afplay 2>/dev/null
exit 0
