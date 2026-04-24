---
phase: 01-working-tool
plan: 01
subsystem: cli
tags: [bash, shellcheck, base64, clipboard, pbcopy, xclip, wl-copy]

# Dependency graph
requires: []
provides:
  - pw2agent executable script at repo root
  - Silent double-entry secret stash with base64 encoding to ~/.{label}_pw (mode 600)
  - NOTE FOR AGENT clipboard handoff (label, file path, base64 read command, rm instruction)
affects: [01-02-install, phase-2-oss-release]

# Tech tracking
tech-stack:
  added: [shellcheck 0.11.0]
  patterns:
    - "printf-then-read pattern: printf 'prompt'; read -rs VAR; printf '\\n' (POSIX-safe, zsh-safe)"
    - "trap-after-write pattern: set trap immediately after file creation, disarm at clean exit"
    - "clipboard chain: pbcopy → xclip (with $DISPLAY guard) → wl-copy (with $WAYLAND_DISPLAY guard) → return 1 fallback"

key-files:
  created:
    - pw2agent
  modified: []

key-decisions:
  - "80-line limit enforced: removed trailing blank line before final trap - to hit exactly 80"
  - "base64 -d < file (stdin redirect) in NOTE rather than base64 -d file (positional) — cross-platform macOS/GNU"
  - "trap disarmed at script end (trap - EXIT INT TERM) so file persists for agent to read"
  - "{ set +x; } 2>/dev/null on line 3 prevents xtrace leaking secret in calling shell"

patterns-established:
  - "Prompt pattern: printf 'prompt'; read -rs VAR; printf '\\n' — never read -rsp or read -s -p"
  - "Write pattern: printf '%s' \"$VAR\" | base64 > file — never echo"
  - "Cleanup trap: immediately after write, disarmed after successful completion"
  - "Clipboard detection: command -v, not which; env-var guards before each tool"

requirements-completed: [CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06, CORE-07, CORE-08]

# Metrics
duration: 1min
completed: 2026-04-24
---

# Phase 1 Plan 01: pw2agent Script Summary

**Single-file bash secret-handoff utility: silent double-entry prompt, base64-encoded ~/.{label}_pw at mode 600, clipboard NOTE FOR AGENT with read/delete instructions, ShellCheck-clean at exactly 80 lines**

## Performance

- **Duration:** 1 min
- **Started:** 2026-04-24T00:52:26Z
- **Completed:** 2026-04-24T00:53:41Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Wrote pw2agent to repo root: silent double-entry prompt, base64 write, mode-600 file, clipboard NOTE
- ShellCheck 0.11.0 passes with zero warnings
- All 9 acceptance criteria pass: executable, help flag, line count, no rm -P, no read -rsp, base64 write, base64 -d < read, line-3 set+x guard, trap ordering

## Task Commits

1. **Task 1: Write pw2agent script** - `7c129a1` (feat)

**Plan metadata:** (docs commit — to follow)

## Files Created/Modified

- `pw2agent` — Main secret-stash script: silent input, base64 encode, mode-600 write, clipboard NOTE FOR AGENT

## Decisions Made

- Removed trailing blank line before `trap - EXIT INT TERM` to hit exactly 80 lines (was 81); blank line was cosmetic only, no functional change
- Used `base64 -d < file` (stdin redirect) in NOTE rather than `base64 -d file` (positional arg) — works identically on both macOS and GNU coreutils
- `trap - EXIT INT TERM` at end disarms cleanup so file persists after clean exit — agent reads it, then runs `rm -f ~/.{label}_pw`

## Acceptance Criteria Results

| Check | Result |
|-------|--------|
| `test -x pw2agent` | PASS |
| `shellcheck --shell=bash pw2agent` exits 0 | PASS |
| `./pw2agent --help` contains "Usage: pw2agent" | PASS |
| `grep -c 'rm -P' pw2agent` returns 0 | PASS |
| `grep -c 'read -rsp\|read -sp\|read -s -p' pw2agent` returns 0 | PASS |
| `grep -c '| base64 >' pw2agent` returns >= 1 | PASS |
| `grep -c 'base64 -d <' pw2agent` returns >= 1 | PASS |
| `sed -n '3p' pw2agent` contains "set +x" | PASS |
| `wc -l < pw2agent` <= 80 | PASS (80 exactly) |

## Deviations from Plan

**1. [Rule 1 - Bug] Script was 81 lines — trimmed trailing blank line before final trap**
- **Found during:** Task 1 verification
- **Issue:** Script had 81 lines due to blank line before `trap - EXIT INT TERM`; plan specifies max 80
- **Fix:** Removed the cosmetic blank line on line 80; `trap - EXIT INT TERM` moved up one line
- **Files modified:** pw2agent
- **Verification:** `wc -l < pw2agent` returns 80; ShellCheck still passes
- **Committed in:** 7c129a1 (same task commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — line count out of spec)
**Impact on plan:** Minimal cosmetic change. No functional impact. Script identical to plan skeleton in all substantive respects.

## Issues Encountered

None beyond the 81-line count which was auto-fixed inline.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- pw2agent is ready to use: `./pw2agent` or `./pw2agent my_label`
- Ready for plan 01-02: install.sh (copies to ~/.local/bin, updates ~/.zshrc PATH)
- No blockers

---
*Phase: 01-working-tool*
*Completed: 2026-04-24*
