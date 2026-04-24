# pw2agent

## What This Is

A 70-line shell utility that lets you hand a secret (password, API token, SSH key) to an AI coding agent **without pasting it into chat**. You run `pw2agent`, it prompts twice for match, writes the secret to a mode-600 temp file, and copies a clean "NOTE FOR AGENT" block to your clipboard. Paste the note into the agent's chat — the agent reads the file, uses the secret, and deletes it.

## Core Value

The clipboard-to-agent NOTE pattern: structured enough that any competent agent can follow it without extra prompting, cheap enough to replace the "just paste it in chat" anti-pattern.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] `pw2agent` script: prompt twice for secret, write to mode-600 file, copy NOTE FOR AGENT to clipboard
- [ ] `install.sh`: one-command install to `~/.local/bin/pw2agent`, add alias to `~/.zshrc`
- [ ] `skill.md`: openskill-format Claude Code skill with slash command "use when you need to give an agent a pw without them seeing it"
- [ ] README with gif/screenshot demo at top, one-liner install, 3 usage examples
- [ ] MIT license
- [ ] Works first time on macOS and Linux (pbcopy/xclip/wl-copy clipboard chain)

### Out of Scope

- Doppler/1Password integration — v2 graduation path, adds complexity for v1
- `--ttl` auto-delete timer — nice-to-have, not core
- Agent-side `pw2agent-read` companion script — convention is enough for v1; agent follows NOTE
- Homebrew formula — post-launch
- Windows support — macOS/Linux first

## Context

- Source script: `bifrost-tailscale/scripts/stash-password.sh` in parent afmac repo — already works, needs cleanup and packaging
- The script already handles macOS (pbcopy), Linux X11 (xclip), Wayland (wl-copy) clipboard fallback chain
- Key insight: the "NOTE FOR AGENT" format is the differentiator — structured text that any agent can parse without being prompted
- OSS release: standalone GitHub repo, curl-pipeable installer
- Target users: developers using AI coding agents (Claude Code, Cursor, Aider, Copilot) who need to hand off one-off secrets

## Constraints

- **Simplicity**: Single-file script — no dependencies, no config files, just shell
- **Security**: mode-600 file, no secret in process args or env, no logging
- **Compatibility**: bash (not POSIX-only — `read -s` is bash but widely supported); macOS + Linux
- **Size**: Under 80 lines — if it needs more, scope is wrong

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Name: `pw2agent` | Short, memorable, clearly communicates direction (pw TO agent) | — Pending |
| Drop Doppler from v1 | Keeps script under 80 lines; Doppler is graduation path | — Pending |
| Alias in `~/.zshrc` not just PATH | Ensures it "just works" after install without shell restart confusion | — Pending |
| openskill skill format | Standard format for Claude Code plugins; distributable | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-24 after initialization*
