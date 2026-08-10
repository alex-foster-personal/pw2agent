# pw2agent learnings

- [CLI token flows beat pw2agent handoff](cli-token-flows-beat-handoff.md) -- check for a service CLI browser-auth flow (`modal token new`, `gh auth login`, etc) before invoking pw2agent; let the CLI mint its own credential file.
- [AppleScript window-close traps](applescript-close-traps.md) -- three separate reasons a Terminal `close` returns 0 and closes nothing; all three bit while building `--launch --autoclose`.
