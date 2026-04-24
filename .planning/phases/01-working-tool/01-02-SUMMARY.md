---
phase: 01-working-tool
plan: 02
subsystem: infra
tags: [bash, shellcheck, install, path, zshrc]

requires:
  - phase: 01-working-tool plan 01
    provides: pw2agent executable at repo root

provides:
  - install.sh — idempotent installer copying pw2agent to ~/.local/bin and appending PATH to ~/.zshrc

affects:
  - Any future plan distributing pw2agent (curl|bash, Homebrew, CI)

tech-stack:
  added: []
  patterns:
    - "main() guard pattern: all side-effects inside main(), called as last line — safe for partial curl|bash"
    - "Idempotency via grep -qF literal match before any shell config append"
    - "ZDOTDIR-aware RC file resolution"

key-files:
  created:
    - install.sh
  modified: []

key-decisions:
  - "SC2016 suppressed with inline shellcheck disable — PATH_LINE must be single-quoted to defer $HOME expansion to write time"
  - "BASH_SOURCE[0] self-location chosen over $0 — reliable when sourced or piped"
  - "grep -qF (literal, quiet) not grep -q (regex) — '#' is not a regex special char but literal is safer and clearer"

patterns-established:
  - "Installer pattern: config block → main() → main \"\$@\" last line"
  - "Idempotency marker: trailing comment '# pw2agent' both in PATH_LINE and grep guard"

requirements-completed: [INST-01, INST-02, INST-03, INST-04]

duration: 1min
completed: 2026-04-24
---

# Phase 1 Plan 02: Install Script Summary

**Idempotent bash installer copying pw2agent to ~/.local/bin with ZDOTDIR-aware PATH append and curl|bash-safe main() guard**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-04-24T00:55:41Z
- **Completed:** 2026-04-24T00:56:42Z
- **Tasks:** 1 (+ auto-mode checkpoint verification)
- **Files modified:** 1

## Accomplishments

- Wrote `install.sh` (26 lines, under 35 limit) passing ShellCheck with zero warnings
- Verified binary installs to `~/.local/bin/pw2agent` and is executable
- Confirmed idempotency: two consecutive runs leave exactly one `# pw2agent` line in `~/.zshrc`

## Task Commits

1. **Task 1: Write install.sh** - `76cc45b` (feat)

**Plan metadata:** (pending docs commit)

## Files Created/Modified

- `install.sh` — 26-line idempotent installer; copies pw2agent to `~/.local/bin`, appends PATH line to `~/.zshrc` once

## Decisions Made

- Added `# shellcheck disable=SC2016` above `PATH_LINE` — single-quoting is intentional (prevents premature `$HOME` expansion at assignment time; expansion happens when the line is written into `~/.zshrc`). Without disable, ShellCheck exits 1.
- No other deviations from the specified skeleton.

## Acceptance Criteria Results

| Check | Expected | Result |
|-------|----------|--------|
| `test -x install.sh` | exit 0 | PASS |
| `shellcheck --shell=bash install.sh` | exit 0, no output | PASS |
| `grep -c '^main()' install.sh` | 1 | PASS (1) |
| `tail -1 install.sh` | `main "$@"` | PASS |
| `grep -c 'grep -qF' install.sh` | >= 1 | PASS (1) |
| `grep -c 'ZDOTDIR:-\$HOME' install.sh` | >= 1 | PASS (1) |
| `grep -c '✅ Ready. Run: pw2agent' install.sh` | 1 | PASS (1) |
| `wc -l < install.sh` | <= 35 | PASS (26) |

## 6-Step Idempotency Verification

| Step | Command | Expected | Result |
|------|---------|----------|--------|
| 1 | `grep -c '# pw2agent' ~/.zshrc` (before) | 0 | PASS (0) |
| 2 | `bash install.sh` (first run) | "✅ Ready. Run: pw2agent" | PASS |
| 3 | `test -x ~/.local/bin/pw2agent` | PASS | PASS |
| 4 | `grep -c '# pw2agent' ~/.zshrc` (after first) | 1 | PASS (1) |
| 5 | `bash install.sh` (second run) | same success output, no error | PASS |
| 6 | `grep -c '# pw2agent' ~/.zshrc` (after second) | still 1 | PASS (1) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added `# shellcheck disable=SC2016` to pass ShellCheck**
- **Found during:** Task 1 (Write install.sh)
- **Issue:** ShellCheck SC2016 fired on `PATH_LINE='export PATH="$HOME/.local/bin:$PATH" # pw2agent'` — single quotes are intentional but ShellCheck warns on unexpanded `$HOME`
- **Fix:** Added inline `# shellcheck disable=SC2016` comment on the line above `PATH_LINE`
- **Files modified:** install.sh
- **Verification:** `shellcheck --shell=bash install.sh` exits 0 with no output
- **Committed in:** `76cc45b`

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking ShellCheck failure)
**Impact on plan:** Single-line inline suppression; semantics unchanged. No scope creep.

## Issues Encountered

ShellCheck SC2016 warning on the intentionally single-quoted PATH_LINE. Resolved with inline disable comment (standard practice for this pattern). No other issues.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. install.sh only touches `~/.local/bin/` (private bin dir) and `~/.zshrc` (user shell config). Both are within the plan's declared trust boundaries.

## Known Stubs

None.

## Next Phase Readiness

- `install.sh` is complete and idempotent — any developer cloning the repo can run `bash install.sh` once to get `pw2agent` on PATH
- Phase 1 is now fully complete: pw2agent script exists and installs cleanly
- No blockers for v2 work (CI, Homebrew, curl|bash remote install)

---
*Phase: 01-working-tool*
*Completed: 2026-04-24*
