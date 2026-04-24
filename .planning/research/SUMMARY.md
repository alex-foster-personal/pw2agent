# Project Research Summary

**Project:** pw2agent — OSS shell secret-handoff utility for AI coding agents
**Domain:** Security micro-utility / developer CLI tool
**Researched:** 2026-04-24
**Confidence:** HIGH

## Executive Summary

pw2agent is a sub-80-line bash utility that solves a specific, unoccupied niche: handing a secret (password, API key, token) to an AI coding agent without it appearing in chat history. The mechanism is a "NOTE FOR AGENT" block copied to clipboard — structured plain-English instructions pointing the agent at a mode-600 temp file. No existing tool (pass, 1Password CLI, gopass, summon) generates an agent-readable handoff note; this is genuinely novel. Expert consensus on how to build a tool of this type converges on: single-file bash with `#!/usr/bin/env bash`, `set -euo pipefail`, `mktemp` for temp files, `trap EXIT` for cleanup, and a `curl | bash` installer to `~/.local/bin`.

The recommended approach is to treat the working source script (`stash-password.sh`) as a rough draft that must be audited against a specific list of known defects before OSS release. Five concrete bugs are almost certain to be present: `rm -P` (no-op on macOS 14+, error on Linux), `read -s -p` combined flag (breaks on dash/zsh), install.sh appending to `.zshrc` without idempotency guard, clipboard fallback chain not checking `$DISPLAY`/`$WAYLAND_DISPLAY`, and trap possibly not set on the line immediately after `mktemp`. Fixing these five before writing anything new is the right first milestone.

The packaging work — `install.sh`, `skill.md`, README, CI, VHS demo — is well-defined and low-risk. The technology choices (VHS for the demo GIF, bats-core + ShellCheck for testing, agentskills.io SKILL.md format for the Claude Code skill) are all HIGH-confidence selections with strong ecosystem precedent. The OSS release does not require any novel engineering decisions; it requires careful execution of established patterns on a simple script.

---

## Key Findings

### Recommended Stack

The stack is almost entirely "no choice" decisions: the security model requires `read -s`, which is bash-only, so `#!/usr/bin/env bash` is mandatory (not `#!/bin/sh`). The `set -euo pipefail` trio is industry-standard for bash scripts that must not fail silently. For demo generation, VHS (charmbracelet/vhs) wins because its `.tape` files commit to git and are CI-regeneratable — critical for a security tool where you cannot record live sessions with real secrets. Testing is ShellCheck (static analysis, pre-installed on GitHub runners) plus bats-core (TAP-compliant bash integration testing). The skill format is agentskills.io SKILL.md, published as an open standard in December 2025 and supported by Claude Code, Codex, and Copilot agent mode.

**Core technologies:**
- `bash` + `#!/usr/bin/env bash`: shell language — `read -s` is bash-only; fzf/gh-cli use same shebang
- `set -euo pipefail`: defensive flags — exits on error, catches unset vars, propagates pipe failures
- `mktemp` + `trap EXIT`: temp file security — atomic creation at mode 600, guaranteed cleanup on all exit paths
- `curl -fsSL | bash` to `~/.local/bin`: install pattern — no sudo, developer-standard, XDG-compliant path
- VHS `.tape`: demo GIF — reproducible, version-controlled, CI-regeneratable, no live recording needed
- ShellCheck + bats-core: testing pair — static analysis + integration tests, canonical 2025 approach
- agentskills.io SKILL.md: skill packaging — official open standard, Claude Code + Codex + Copilot compatible
- MIT License: single comment header + `LICENSE` file, no per-file boilerplate needed

### Expected Features

The feature space is unusually clear-cut: the script already exists, the differentiator is the NOTE FOR AGENT format (no prior art found), and the anti-features are all things that would bloat the script past 80 lines without adding core value.

**Must have (table stakes):**
- Silent double-entry input (`read -rs`) — visible typing is a trust-breaker; double-prompt prevents mistyped secrets
- Mismatch re-prompt (not abort) — `passwd`-style UX; users expect retry, not restart
- `trap EXIT INT TERM` to restore terminal echo — without this, `^C` leaves the terminal broken (no echo)
- Mode-600 file — every credential convention gates on owner-only read; non-negotiable
- Cross-platform clipboard chain (pbcopy / xclip / wl-copy) — any missing platform gets an immediate GitHub issue
- Stdout fallback when clipboard unavailable — SSH/headless users cannot be left with no output
- Clear success confirmation — one line telling the user the NOTE is on clipboard

**Should have (differentiators):**
- NOTE FOR AGENT block — the entire raison d'etre; structured agent-readable handoff note with path, use instruction, delete instruction, no-echo instruction
- Optional `LABEL` positional argument (`pw2agent api_key`) — names the file; the only user-facing configurability needed
- `skill.md` in agentskills.io format — makes pw2agent a distributable Claude Code skill
- 30-second background clipboard clear — mitigates clipboard manager logging risk for NOTE path

**Defer (v2+):**
- GPG/age encryption — breaks "no dependencies" contract; overkill for ephemeral temp file
- `--ttl` auto-delete timer — background process complexity; agent convention is enough
- Secret storage / vault features — turns tool into a pass competitor; wrong identity
- Homebrew/apt formula — post-launch, curl-pipe covers all v1 target users
- Windows support — entirely different clipboard and shell; separate project

### Architecture Approach

pw2agent is a single-file script (`pw2agent`, no extension) with no subcommands. The repository structure is flat: `pw2agent` (main script), `install.sh`, `skill.md`, `demo.tape`, `demo.gif`, `LICENSE`, `README.md`, `.github/workflows/ci.yml`, and `tests/`. There is no `src/` directory, no `lib/`, no shared code between `pw2agent` and `install.sh` — they are completely independent scripts. The script's internal layout follows strict top-to-bottom execution order: shebang + flags, config block (all tunable variables at top), helper functions (`_copy_to_clipboard`, `_prompt_secret`), then the main sequence (trap, double-entry loop, file write, NOTE generation, clipboard, confirm).

The installer installs to `~/.local/bin` (XDG convention, no sudo) and appends `export PATH="$HOME/.local/bin:$PATH"` to the detected shell rc file — NOT an alias. PATH beats alias because it works in non-interactive shells, has no tilde-in-single-quotes expansion bug, is discoverable via `which`/`command -v`, and idempotency check is simpler.

**Major components:**
1. `pw2agent` (main script) — all runtime logic: silent double-entry, mktemp + trap, NOTE generation, clipboard chain, stdout confirm
2. `install.sh` — PATH setup only: copy binary to `~/.local/bin`, detect shell rc, idempotent PATH append, print source instruction
3. `skill.md` — agent trigger + NOTE FOR AGENT handling instructions; body under 50 lines; no subfiles needed
4. `tests/pw2agent.bats` + `tests/helpers.bash` — integration tests with clipboard mocks; validates permissions, clipboard chain, NOTE format
5. `.github/workflows/ci.yml` — ShellCheck (lint job) + bats (test job) + VHS (demo regen on main)

### Critical Pitfalls

These five are pre-ship blockers. All are likely present in the source `stash-password.sh` and must be fixed before OSS release.

1. **`rm -P` is a no-op on macOS 14+ and errors on Linux** — replace with plain `rm -f`; the mode-600 + prompt-deletion convention is the real mitigation; document that secure overwrite is not meaningful on SSDs.

2. **`read -s -p` breaks on dash/zsh** — in POSIX sh (dash), `-p` is illegal and the script aborts; in zsh, `-p` means "read from coprocess." Replace all `read -s -p "prompt" var` with: `printf 'prompt: '; read -rs var; printf '\n'`.

3. **`install.sh` without idempotency guard duplicates `.zshrc` lines** — wrap every `>>` append with `if ! grep -qF '# pw2agent' "$RC_FILE"` guard. Test by running install twice and diffing the rc file.

4. **Clipboard silent fail on SSH/headless** — `wl-copy` fails silently when `$WAYLAND_DISPLAY` is unset; `xclip` fails when `$DISPLAY` is unset. Guard each tool with its env var check. Add stdout fallback ("COPY THIS:") when no clipboard tool is available.

5. **Trap not set immediately after `mktemp`** — any code path between `mktemp` and the trap that fails leaves an orphaned secret file on disk. Exact order required: `TMPFILE=$(mktemp)` then `trap 'rm -f "$TMPFILE"; stty echo 2>/dev/null || true' EXIT INT TERM HUP` then everything else.

---

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Core Script Audit and Fix
**Rationale:** The source script already works but contains 5 confirmed pre-ship blockers. Fix these before building anything new — they are cheap to fix now and expensive after packaging decisions are locked in. ShellCheck catches most of them; bats tests validate the fixes.
**Delivers:** A correct, secure `pw2agent` script passing ShellCheck with zero warnings and no known security defects.
**Addresses:** All 5 critical pitfalls + 2 moderate pitfalls (set -x exposure, printf vs echo)
**Avoids:** Shipping a script where `rm -P` errors on Linux, `read -s -p` breaks on zsh, or a secret file is orphaned on interrupt

### Phase 2: Test Infrastructure
**Rationale:** Tests can be written alongside the audit. ShellCheck catches static issues; bats tests validate runtime behavior (permissions, clipboard chain, NOTE format, mismatch re-prompt). Tests written now prevent regression during packaging changes.
**Delivers:** `tests/pw2agent.bats` + `tests/helpers.bash` with mocked clipboard; CI `.github/workflows/ci.yml` running ShellCheck + bats
**Uses:** ShellCheck (pre-installed on GitHub runners) + bats-core + bats-support + bats-assert
**Implements:** Validates all table-stakes features; clipboard fallback matrix (pbcopy / xclip / wl-copy mocks)

### Phase 3: Install Script
**Rationale:** `install.sh` is independent of the main script and can be written cleanly once the main script is settled. The patterns are fully specified. Highest-risk bug is the idempotency issue; write it correctly from scratch rather than adapting existing code.
**Delivers:** Idempotent `install.sh` wrapping all logic in `main()`, installing to `~/.local/bin`, detecting shell rc, adding PATH without duplication, printing clear "source ~/.zshrc" instruction
**Avoids:** Duplicate lines in `.zshrc` (Pitfall 4), partial-download execution of destructive commands (Pitfall 9), sudo requirement

### Phase 4: Skill and README Packaging
**Rationale:** `skill.md` and README require the script to be stable before writing accurate examples. VHS demo tape can only be written after the script UX is final. This phase turns a working script into a releasable OSS project.
**Delivers:** `skill.md` (agentskills.io format, under 50 lines), README.md (GIF hero, one-liner install, how it works, security notes), `demo.tape` + `demo.gif`, MIT `LICENSE`
**Uses:** VHS for demo GIF generation (note: VHS cannot interact with `read -s` prompts — demo tape must show clipboard output state, not live input)
**Implements:** Complete repo ready for OSS release; distributable Claude Code skill

### Phase Ordering Rationale

- Phase 1 before everything: audit is cheap, blast radius is small, all other work is wasted if core script has security defects
- Phase 2 immediately after Phase 1: tests validate the fixes and prevent regression during later changes
- Phase 3 before packaging: README install instructions depend on knowing exact install behavior
- Phase 4 last: VHS demo tape, README examples, and skill instructions all depend on final UX being locked

### Research Flags

Phases with well-documented patterns (skip `/gsd-research-phase` for all phases):
- **Phase 1:** All 5 fixes are specific and concrete — PITFALLS.md provides exact code fixes
- **Phase 2:** bats-core patterns are standard; test structure specified in STACK.md
- **Phase 3:** Exact idempotent install pattern provided in ARCHITECTURE.md
- **Phase 4:** VHS tape structure, SKILL.md format, and README structure all specified in research files

No phase requires additional research. The entire implementation is fully specified.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All decisions verified against official sources; fzf/gh-cli shebang, agentskills.io spec, VHS repo, bats-core all confirmed active |
| Features | HIGH | Table stakes derived from pass/gopass/1Password docs; NOTE FOR AGENT format confirmed novel (negative finding is high confidence) |
| Architecture | HIGH | Patterns verified against fzf, nvm, starship install scripts; local skill format confirmed from primary source (`~/.claude/skills/`) |
| Pitfalls | HIGH | `rm -P` no-op verified against macOS man page; `read -p` zsh behavior confirmed in zsh docs; all 5 critical pitfalls independently sourced |

**Overall confidence:** HIGH

### Gaps to Address

- **Agent instruction-following (MEDIUM):** The claim that agents follow plain-English file-read instructions in a NOTE FOR AGENT block is based on observed Claude Code behavior, not formal documentation. Validate in Phase 4 by testing the skill with a real agent before OSS release.
- **Source script actual contents:** `stash-password.sh` was not directly accessible during research — the 5 critical pitfalls are "highly probable" from PROJECT.md description, not confirmed line-by-line. Phase 1 audit resolves this immediately.
- **VHS + `read -s` interaction:** VHS cannot type into silent prompts — demo tape must work around this. Final tape design needs local validation against VHS behavior.

---

## Sources

### Primary (HIGH confidence)
- fzf install script shebang — https://github.com/junegunn/fzf/blob/master/install
- agentskills.io specification — https://agentskills.io/specification
- VHS README — https://github.com/charmbracelet/vhs/blob/main/README.md
- bats-core — https://github.com/bats-core/bats-core
- MIT License canonical text — https://choosealicense.com/licenses/mit/
- nvm install.sh shell detection — https://github.com/nvm-sh/nvm/blob/v0.40.1/install.sh
- GNU Coreutils rm invocation — https://www.gnu.org/software/coreutils/manual/html_node/rm-invocation.html
- zsh Shell Builtins: read — https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html
- macOS `man rm` — `-P` flag documented as "no effect" (local system verification on macOS 14.3)
- Local skill format — `/Users/dev/.claude/skills/my-first-skill/SKILL.md` (primary source)
- XDG Base Directory Specification — freedesktop.org
- pass password manager — https://www.passwordstore.org/
- 1Password CLI secrets scripts — https://developer.1password.com/docs/cli/secrets-scripts/

### Secondary (MEDIUM confidence)
- Agent instruction-following behavior — AGENTS.md open format conventions + Claude Code observed behavior
- curl | bash security analysis — https://www.kicksecure.com/wiki/Dev/curl_bash_pipe

---
*Research completed: 2026-04-24*
*Ready for roadmap: yes*
