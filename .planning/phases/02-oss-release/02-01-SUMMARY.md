---
phase: 02-oss-release
plan: 01
subsystem: distribution
tags: [install, curl-pipe, skill, license, oss]
dependency_graph:
  requires: [01-02-SUMMARY.md]
  provides: [install.sh curl-mode, skill.md, LICENSE]
  affects: [README.md (Plan 2)]
tech_stack:
  added: []
  patterns: [curl-pipe install pattern, agentskills.io SKILL.md format, MIT license]
key_files:
  created: [skill.md, LICENSE]
  modified: [install.sh]
decisions:
  - BASH_SOURCE[0] empty-string guard chosen over subshell test for curl-pipe detection
  - _DOWNLOADED flag pattern used to defer cleanup to after copy step in main()
  - skill.md description field locked to SKIL-02 exact wording (no trailing period, no quotes)
  - Author "Alex Foster" matches gitconfig user agdfoster; year 2026 matches current date
metrics:
  duration: "1 minute"
  completed: "2026-04-24"
  tasks_completed: 3
  files_modified: 3
---

# Phase 2 Plan 1: OSS Release Prerequisites Summary

Three atomic authoring tasks: curl-pipe mode for install.sh, agentskills.io skill.md, and MIT LICENSE. Enables the README curl install one-liner and OSS publishing in Plan 2.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Patch install.sh for curl-pipe mode | 90b8170 | install.sh |
| 2 | Write skill.md | f2780ae | skill.md |
| 3 | Write LICENSE | 5e41f31 | LICENSE |

## What Was Built

**install.sh — curl-pipe mode detection**

Replaced the static `SCRIPT_SRC` assignment with a two-branch block:
- Local clone path: `BASH_SOURCE[0]` non-empty and `pw2agent` file adjacent → resolves path normally
- curl-pipe path: `BASH_SOURCE[0]` empty → `mktemp` + `curl -fsSL $GITHUB_RAW/pw2agent` downloads the script

`_DOWNLOADED=false` flag set at top level; flipped to `true` in the curl branch. Cleanup `rm -f "$SCRIPT_SRC"` runs in `main()` after copy, before success printf. ShellCheck exits 0 with zero output.

**skill.md — agentskills.io format**

YAML frontmatter: `name: pw2agent`, `description: use when you need to give an agent a pw without them seeing it` (SKIL-02 exact), `license: MIT`. Body: 4-step instruction (read path, base64 -d decode, use without printing, rm -f delete). 17 lines total — well under the 50-line SKIL-03 limit.

**LICENSE — MIT 2026**

Canonical choosealicense.com MIT text. Year 2026, author Alex Foster. No modifications to standard text.

## Decisions Made

1. Used `[[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/pw2agent" ]]` — the `:-` default prevents unbound variable error under `set -u` when script is piped through bash; the adjacent-file check prevents false positives when running from a directory that happens to have a pw2agent file elsewhere.

2. `_DOWNLOADED` cleanup placed inside `main()` after `cp` but before `printf` — ensures temp file is removed even if future steps are added between copy and success message.

3. `skill.md` uses lowercase filename at repo root; users install it as `~/.claude/skills/pw2agent/SKILL.md` per README instructions (Plan 2). No rename needed at source.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Flags

None — no new network endpoints or auth paths beyond the `GITHUB_RAW` curl download already documented in the plan's threat model (T-02-01, T-02-02 both accepted).

## Self-Check: PASSED

- install.sh exists and shellcheck clean: FOUND
- skill.md exists at repo root: FOUND
- LICENSE exists at repo root: FOUND
- Commits 90b8170, f2780ae, 5e41f31: all present in git log
