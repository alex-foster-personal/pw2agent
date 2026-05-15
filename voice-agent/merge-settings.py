#!/usr/bin/env python3
# Merge voice-agent hook entries into an existing ~/.claude/settings.json.
# Idempotent: a hook with a command already present for that event is skipped.
import json, sys

existing_path, incoming_path = sys.argv[1], sys.argv[2]

try:
    with open(existing_path) as f:
        existing = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    existing = {}

with open(incoming_path) as f:
    incoming = json.load(f)

existing.setdefault("hooks", {})

for event, new_entries in incoming.get("hooks", {}).items():
    existing["hooks"].setdefault(event, [])
    existing_cmds = {
        h.get("command")
        for entry in existing["hooks"][event]
        for h in entry.get("hooks", [])
        if h.get("type") == "command"
    }
    for entry in new_entries:
        filtered = [
            h for h in entry.get("hooks", [])
            if h.get("type") != "command" or h.get("command") not in existing_cmds
        ]
        if filtered:
            new_entry = dict(entry)
            new_entry["hooks"] = filtered
            existing["hooks"][event].append(new_entry)

json.dump(existing, sys.stdout, indent=2)
sys.stdout.write("\n")
