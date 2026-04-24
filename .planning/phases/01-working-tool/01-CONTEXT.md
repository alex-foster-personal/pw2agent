# Phase 1: Working Tool — Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a correct, installable shell utility: the `pw2agent` script (audited from stash-password.sh) plus `install.sh`. A developer can run `bash install.sh`, then `pw2agent [label]` to silently stash a secret and get a NOTE FOR AGENT on their clipboard. Nothing shipped to GitHub yet — that's Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Script Invocation
- **D-01:** Positional arg only: `pw2agent [label]` where label defaults to `secret`. No `--path` flag for v1 — keeps usage obvious and under 80 lines.
- **D-02:** Secret file written to `~/.{label}_pw` (matches source script, predictable to agents reading the NOTE).

### NOTE FOR AGENT Format
- **D-03:** Plain English, minimal — 3 instructions only: (1) file path, (2) `base64 -d ~/.{label}_pw` read command, (3) `rm -f ~/.{label}_pw` delete instruction. No JSON, no structured markup, no secret encoded in the NOTE itself.
- **D-04:** NOTE is printed to stdout AND copied to clipboard. If all clipboard tools fail (headless/SSH), print NOTE to stdout with a clear indicator so the session isn't broken.

### Error Handling & Safety
- **D-05:** `set -euo pipefail` at top. `trap 'rm -f "$TARGET"' EXIT` immediately after writing the file — ensures cleanup on any error path including Ctrl-C.
- **D-06:** `rm -f` not `rm -P` — `rm -P` is a documented no-op on macOS 14+ (Sonoma). Remove all `rm -P` references.
- **D-07:** `read -rs` on its own line preceded by `printf 'prompt: '` — NOT `read -s -p` (breaks zsh, errors on dash).
- **D-08:** Concise error/success messages: `❌ Secrets don't match. Nothing written.` / `✅ Stashed at: {path}`.

### Script Structure
- **D-09:** Single file, `#!/usr/bin/env bash`, `set -euo pipefail`. Under 80 lines.
- **D-10:** `--help` / `-h` flag: prints 4-line usage + 2 examples, then exits 0.
- **D-11:** Banner: single compact header block showing label + target path. Remove the fixed-width box (alignment breaks on long labels).

### Install Script
- **D-12:** `install.sh` downloads/copies `pw2agent` to `~/.local/bin/pw2agent` (chmod +x).
- **D-13:** Idempotency guard: `grep -qF '# pw2agent' ~/.zshrc` before any append. Marker comment prevents duplication on re-run.
- **D-14:** Appends `export PATH="$HOME/.local/bin:$PATH" # pw2agent` to `~/.zshrc` (PATH, not alias — aliases fail in non-interactive shells).
- **D-15:** All logic in `main()`, called as last line — safe for partial curl download.
- **D-16:** Success message: `✅ Ready. Run: pw2agent` (matches INST-04).

### Claude's Discretion
- Banner wording and visual style — keep it useful, not decorative.
- Whether to detect and skip PATH append when `~/.local/bin` is already in PATH via other means.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source Script
- `../bifrost-tailscale/scripts/stash-password.sh` — Working source; start from this, apply the 5 known fixes (rm -P, read -s -p, no trap, install idempotency, set -x xtrace)

### Requirements
- `.planning/REQUIREMENTS.md` — CORE-01→08, INST-01→04 are Phase 1 scope
- `.planning/research/PITFALLS.md` — 5 critical bugs to fix, all with exact replacement code
- `.planning/research/STACK.md` — bash shebang, VHS for demo (Phase 2), bats for tests (Phase 2)
- `.planning/research/ARCHITECTURE.md` — PATH vs alias decision, single-file structure, no subcommands

### Project Context
- `.planning/PROJECT.md` — Constraints: single file, no deps, under 80 lines

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `../bifrost-tailscale/scripts/stash-password.sh` — 90% of the work is done; audit and fix rather than rewrite

### Established Patterns
- Clipboard chain (pbcopy → xclip → wl-copy → stdout fallback) is correct and tested
- Double-entry password read pattern is correct
- Mode-600 write pattern is correct

### Integration Points
- `pw2agent` is standalone; no external dependencies
- `install.sh` touches only `~/.local/bin/` and `~/.zshrc`

</code_context>

<specifics>
## Specific Ideas

- The NOTE FOR AGENT wording should be simple enough that any agent (Claude, Cursor, Aider, Copilot) follows it without extra system prompt context.
- The base64 read command in the NOTE: `PWB64=$(base64 -d ~/.{label}_pw | tr -d '\n')` — avoids raw `cat` echo, works cross-platform.

</specifics>

<deferred>
## Deferred Ideas

- `--ttl` auto-delete timer — Phase 2 or later
- 30-second clipboard auto-clear background job — clipboard is the NOTE (not the secret), lower priority
- VHS demo tape — Phase 2 (OSS Release)
- bats test suite + CI — Phase 2

</deferred>

---

*Phase: 01-working-tool*
*Context gathered: 2026-04-24*
