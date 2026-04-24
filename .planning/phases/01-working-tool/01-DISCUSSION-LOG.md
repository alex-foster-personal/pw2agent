# Phase 1: Working Tool — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 01-working-tool
**Mode:** --auto (all options selected via recommended defaults)
**Areas discussed:** Script Invocation, NOTE Format, Error Handling, Install Behavior

---

## Script Invocation

| Option | Description | Selected |
|--------|-------------|----------|
| Positional arg only: `pw2agent [label]` | Simple, under 80 lines, matches source script | ✓ |
| Add `--path` override flag | Flexible but adds complexity | |

**Auto-selected:** Positional arg only
**Notes:** `--path` deferred to v2 if users request it.

---

## NOTE FOR AGENT Format

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal plain English (3 lines) | Path + base64 read cmd + rm cmd — no encoding | ✓ |
| Structured YAML front-matter | Machine-parseable but over-engineered for one-shot use | |
| Current verbose format with Doppler reference | Already in source script — Doppler stripped for v1 | |

**Auto-selected:** Minimal plain English
**Notes:** Research confirmed agents follow plain-English file-read instructions without structured markup. Clipboard contains the NOTE (instructions), not the secret itself.

---

## Error Handling & Safety

| Option | Description | Selected |
|--------|-------------|----------|
| `set -euo pipefail` + `trap EXIT` + `rm -f` | Correct cross-platform approach | ✓ |
| Keep `rm -P` + no trap | Current source behavior — known broken | |

**Auto-selected:** Full defensive bash
**Notes:** All 5 pitfalls from PITFALLS.md addressed here: rm -P→rm -f, read -s -p→printf+read -rs, trap EXIT added, install idempotency, set -x xtrace guard.

---

## Install Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| PATH export to `~/.local/bin` with idempotency guard | Works in non-interactive shells, standard convention | ✓ |
| Direct alias to script path | Breaks in non-interactive shells, tilde in single quotes doesn't expand | |

**Auto-selected:** PATH export with grep -qF guard
**Notes:** Architecture research confirmed PATH is non-negotiable — aliases fail in Makefiles, subprocesses, scripts.

---

## Claude's Discretion

- Banner wording and visual style
- Whether to skip PATH append detection when `~/.local/bin` already in PATH via other means
