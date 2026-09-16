# pw2agent learnings

- [CLI token flows beat pw2agent handoff](cli-token-flows-beat-handoff.md) -- check for a service CLI browser-auth flow (`modal token new`, `gh auth login`, etc) before invoking pw2agent; let the CLI mint its own credential file.
- [The modal is what lets an agent START the ask](modal-is-the-only-agent-startable-prompt.md) -- a GUI dialog can be raised by an agent but only answered by the person at the screen; a headless host must exit 2, never fall back to a TTY prompt nobody can see.
