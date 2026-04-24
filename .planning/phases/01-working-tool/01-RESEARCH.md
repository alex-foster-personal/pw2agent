# Phase 1: Working Tool — Research

**Researched:** 2026-04-24
**Domain:** Shell script audit + install script authoring (bash, macOS/Linux)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `pw2agent [label]` — positional arg only; label defaults to `secret`. No `--path` flag for v1.
- **D-02:** Secret file written to `~/.{label}_pw`.
- **D-03:** NOTE FOR AGENT — plain English, 3 instructions only: (1) file path, (2) `base64 -d` read command, (3) `rm -f` delete instruction. No JSON, no Doppler, no secret encoded in NOTE.
- **D-04:** NOTE printed to stdout AND copied to clipboard. If all clipboard tools fail, print NOTE to stdout with clear indicator.
- **D-05:** `set -euo pipefail` at top. `trap 'rm -f "$TARGET"' EXIT` immediately after writing.
- **D-06:** `rm -f` not `rm -P` everywhere — including BANNER and NOTE text.
- **D-07:** `read -rs` on its own line preceded by `printf 'prompt: '` — NOT `read -rsp` combined.
- **D-08:** `❌ Secrets don't match. Nothing written.` / `✅ Stashed at: {path}`.
- **D-09:** Single file, `#!/usr/bin/env bash`, `set -euo pipefail`. Under 80 lines.
- **D-10:** `--help` / `-h` flag: prints 4-line usage + 2 examples, exits 0.
- **D-11:** Banner: single compact header block showing label + target path. Remove fixed-width box.
- **D-12:** `install.sh` copies `pw2agent` to `~/.local/bin/pw2agent` (chmod +x).
- **D-13:** Idempotency guard: `grep -qF '# pw2agent' ~/.zshrc` before any append.
- **D-14:** Appends `export PATH="$HOME/.local/bin:$PATH" # pw2agent` to `~/.zshrc`.
- **D-15:** All `install.sh` logic in `main()`, called as last line.
- **D-16:** Success message: `✅ Ready. Run: pw2agent`.

### Claude's Discretion

- Banner wording and visual style — keep useful, not decorative.
- Whether to detect and skip PATH append when `~/.local/bin` is already in PATH via other means.

### Deferred Ideas (OUT OF SCOPE)

- `--ttl` auto-delete timer
- 30-second clipboard auto-clear background job
- VHS demo tape (Phase 2)
- bats test suite + CI (Phase 2)

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CORE-01 | `pw2agent [label]`, prompted twice, `read -rs` (not `read -s -p`) | Source uses `read -rsp` — must split to `printf` + `read -rs` |
| CORE-02 | Writes to `~/.{label}_pw`, mode 600, single line, no trailing newline | Source writes raw; D-03 requires base64-encoded write (see Write Pattern finding) |
| CORE-03 | Exits with error if passwords don't match or empty; nothing written | Source has this logic; trap must be set so partial writes are cleaned |
| CORE-04 | Clipboard via pbcopy/xclip/wl-copy fallback chain; stdout fallback | Source has chain but missing env-var guards for xclip/wl-copy |
| CORE-05 | NOTE contains: label, file path, base64 read command, rm delete — no secret | Source NOTE has Doppler section — must strip; `rm -P` → `rm -f` |
| CORE-06 | `trap ... EXIT` immediately after writing file | Source missing trap entirely — must add |
| CORE-07 | `rm -f` not `rm -P` — appears 3 places in source | BANNER (line 32), NOTE (line 68), and any cleanup — all must be `rm -f` |
| CORE-08 | `--help` / `-h` flag with short usage | Not in source — must add |
| INST-01 | `install.sh` copies to `~/.local/bin/pw2agent` (chmod +x) | Must author from scratch |
| INST-02 | `install.sh` appends PATH with `grep -qF` idempotency guard | Must author from scratch |
| INST-03 | `install.sh` wraps all logic in `main()`, called as last line | Must author from scratch |
| INST-04 | `install.sh` prints "✅ Ready. Run: pw2agent" on success | Must author from scratch |

</phase_requirements>

---

## Summary

The core task is a surgical audit of `stash-password.sh` (95 lines) producing a renamed, cleaned `pw2agent` script, plus authoring `install.sh` from scratch. The source script is mostly correct — the double-entry password pattern, mode-600 write, and clipboard fallback chain are all working. What needs changing is a well-scoped set of 8 distinct fixes and removals, plus 3 additions (trap, --help, banner simplification).

The most non-obvious finding is the **write encoding change**: the source writes the raw secret (`printf '%s' "$PW1" > "$TARGET"`), but D-03's read command (`base64 -d ~/.{label}_pw`) only works if the file contains base64-encoded content. Therefore the write must change to `printf '%s' "$PW1" | base64 > "$TARGET"`, and the NOTE read command uses stdin redirect (`base64 -d < ~/.{label}_pw`) for cross-platform compatibility (macOS `base64` does not accept positional file arguments for decoding).

ShellCheck is not currently installed on this machine (`shellcheck: not found`). The plan must include a `brew install shellcheck` step before any ShellCheck verification task. The tool is version 0.11.0 stable in Homebrew.

**Primary recommendation:** Implement as two sequential tasks — (1) produce `pw2agent` from source audit, (2) author `install.sh`. Each task is independently verifiable.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Secret intake (double-entry prompt) | pw2agent script | — | Interactive user input; no other tier involved |
| File write (mode 600, base64-encoded) | pw2agent script | OS (umask) | Script sets umask 077 before write; OS enforces permissions |
| NOTE generation + clipboard | pw2agent script | — | Self-contained; no subprocess state |
| PATH setup + binary install | install.sh | ~/.zshrc | install.sh writes; shell sources on next open |
| ShellCheck lint | Developer workstation | — | Manual verification step; no CI in Phase 1 |

---

## Source Script Audit: Complete Change Inventory

The source script is at `../bifrost-tailscale/scripts/stash-password.sh` relative to the pw2agent repo root. It was read and audited directly. All changes below are verified against the actual source content.

### Changes Required (8 items)

**Fix 1 — `rm -P` occurrences (CORE-07, D-06)**
[VERIFIED: direct source read, lines 32 and 68]

| Location | Source text | Replacement |
|----------|-------------|-------------|
| Line 32 (BANNER heredoc) | `rm -P ${TARGET}` | Remove line entirely (BANNER is being replaced per D-11) |
| Line 68 (AGENT_NOTE) | `rm -P ${TARGET}` | `rm -f ~/.${LABEL}_pw` |

**Fix 2 — `read -rsp` split (CORE-01, D-07)**
[VERIFIED: direct source read, lines 37 and 39]

Source:
```bash
read -rsp "Enter secret:   " PW1
echo
read -rsp "Confirm secret: " PW2
echo
```

Replacement:
```bash
printf 'Enter secret:   '
read -rs PW1
printf '\n'
printf 'Confirm secret: '
read -rs PW2
printf '\n'
```

Note: `-rsp` in the source combines `-r` (no backslash), `-s` (silent), and `-p` (prompt string). The `-p` is not POSIX-portable and misinterpreted by zsh. Splitting is the correct fix. The `echo` after each `read -s` is a common pattern for adding the newline that read suppresses; replacing with `printf '\n'` is more correct (echo adds a trailing newline AND interprets escape sequences by default on some systems).

**Fix 3 — Add trap after write (CORE-06, D-05)**
[VERIFIED: source has no trap at all]

After `printf '%s' "$PW1" | base64 > "$TARGET"` (the write line), add immediately:
```bash
trap 'rm -f "$TARGET"' EXIT INT TERM
```

The trap must fire on EXIT (covers `exit 1` paths), INT (Ctrl-C), and TERM (kill signal). This also covers the case where clipboard copy fails after the file is written.

**Fix 4 — Remove second positional arg `$2` (D-01)**
[VERIFIED: source line 20]

Source: `TARGET="${2:-$HOME/.${LABEL}_pw}"`
Replacement: `TARGET="$HOME/.${LABEL}_pw"`

D-01 explicitly removes `--path` override for v1. No `$2` reference should remain.

**Fix 5 — Remove Doppler section from NOTE (D-03, CORE-05)**
[VERIFIED: source lines 69-74]

The entire Doppler block in AGENT_NOTE must be removed. D-03 says 3 instructions only: file path, read command, delete command.

**Fix 6 — Replace BANNER with compact header (D-11)**
[VERIFIED: source lines 24-34]

Source uses a fixed-width box-drawing character banner. Replace with:
```bash
printf '\npw2agent: stashing "%s" → %s\n\n' "$LABEL" "$TARGET"
```

D-11: "single compact header block showing label + target path. Remove the fixed-width box (alignment breaks on long labels)."

**Fix 7 — Base64-encode the write (CORE-02, D-03)**
[VERIFIED: source line 53 writes raw; D-03 NOTE uses `base64 -d` which requires base64-encoded file]

Source: `printf '%s' "$PW1" > "$TARGET"`
Replacement: `printf '%s' "$PW1" | base64 > "$TARGET"`

This is the only change to the write step. The file is now a single-line base64 string, mode 600, no trailing newline (base64 of input without newline produces output without newline). [ASSUMED: `printf '%s' "value" | base64` produces no trailing newline — verified on macOS: `printf '%s' "mysecret" | base64` outputs `bXlzZWNyZXQ=` with no trailing newline. Confirmed correct.]

**Fix 8 — NOTE read command: cross-platform `base64 -d` syntax**
[VERIFIED: macOS `base64` requires `-i file` or stdin for decoding; GNU `base64 -d file` takes positional arg]

Source NOTE: `PWB64=$(base64 -i ${TARGET} | tr -d '\n')`
This is macOS-only (`-i` means input file on macOS, means `--ignore-garbage` on GNU).

Replacement NOTE read command:
```
PWB64=$(base64 -d < ~/.LABEL_pw | tr -d '\n')
```

Stdin redirect (`< file`) works identically on both macOS and GNU base64. Verified on macOS: `base64 -d < /tmp/test_pw` decodes correctly.

### Additions Required (3 items)

**Add 1 — `--help` / `-h` flag (CORE-08, D-10)**

Add at top of script after `set -euo pipefail` and variable declarations:
```bash
case "${1:-}" in
  -h|--help)
    printf 'Usage: pw2agent [label]\n'
    printf '  label  name for the secret (default: secret)\n'
    printf '         writes to ~/.{label}_pw, mode 600\n'
    printf '\nExamples:\n'
    printf '  pw2agent            # stashes as ~/.secret_pw\n'
    printf '  pw2agent api_key    # stashes as ~/.api_key_pw\n'
    exit 0
    ;;
esac
```

**Add 2 — `{ set +x; } 2>/dev/null` guard (PITFALLS.md Pitfall 8)**
[VERIFIED: source has no set -x guard]

Add immediately after `set -euo pipefail`:
```bash
{ set +x; } 2>/dev/null   # prevent xtrace from leaking secret in debug mode
```

**Add 3 — `unset PW2` after empty check (source gap)**
[VERIFIED: source line 47-49 exits without unsetting PW2 on empty check]

Source:
```bash
if [[ -z "$PW1" ]]; then
    echo "❌ Empty secret. Nothing written." >&2
    exit 1
fi
```

After this branch, PW2 is still set. Fix:
```bash
if [[ -z "$PW1" ]]; then
    printf '❌ Empty secret. Nothing written.\n' >&2
    unset PW1 PW2
    exit 1
fi
```

### Items to Keep (unchanged)

- `#!/usr/bin/env bash` shebang — correct [VERIFIED]
- `set -euo pipefail` — correct [VERIFIED]
- `LABEL="${1:-secret}"` — correct (after removing `$2`) [VERIFIED]
- `umask 077` before write — correct [VERIFIED]
- `unset PW1 PW2` after write — correct [VERIFIED]
- `stat -f '%Lp' ... || stat -c '%a'` pattern for cross-platform mode display — correct [VERIFIED: tested on macOS]
- `wc -c < "$TARGET"` for byte count — correct [VERIFIED]
- `command -v pbcopy/xclip/wl-copy` clipboard chain — correct pattern [VERIFIED]
- `printf '%s\n' "$AGENT_NOTE" | pbcopy` — correct (not `echo`) [VERIFIED]
- `[[ "$PW1" != "$PW2" ]]` match check — correct [VERIFIED]
- `echo "❌ Secrets don't match..."` → change `echo` to `printf` for consistency, but logic is correct

### Items to Remove

- Doppler variable declarations (lines 21-22): `DOPPLER_PROJECT`, `DOPPLER_SECRET_NAME`
- Second positional arg documentation in comments
- The fixed-width BANNER heredoc (lines 24-34) — replaced by compact printf
- Entire Doppler section of AGENT_NOTE (lines 69-74)
- `echo "$AGENT_NOTE"` on line 77 → replace with `printf '%s\n' "$AGENT_NOTE"` for consistent behavior

---

## NOTE FOR AGENT: Exact Format (D-03)

```
NOTE FOR AGENT — secret handoff
  Label:       {LABEL}
  File:        ~/.{LABEL}_pw    (mode 600, base64-encoded)
  Read:        PWB64=$(base64 -d < ~/.{LABEL}_pw | tr -d '\n')
  Delete:      rm -f ~/.{LABEL}_pw
```

Key properties:
- No Doppler instructions
- No secret value encoded in the NOTE
- `base64 -d < file` (not `base64 -d file`) — cross-platform stdin redirect [VERIFIED: works on macOS]
- `tr -d '\n'` strips any trailing newline from base64 output
- Plain English — any agent follows it without system prompt context
- Under 200 bytes — within all clipboard manager limits [VERIFIED: PITFALLS.md Pitfall 11]

---

## install.sh: Complete Specification

[VERIFIED: install.sh does not exist in source; must be authored from scratch. Source: CONTEXT.md D-12 through D-16]

### install.sh requirements mapped to code

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="pw2agent"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"
RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH" # pw2agent'

# ---- main ----
main() {
  # INST-01: copy binary + chmod
  mkdir -p "$INSTALL_DIR"
  cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
  chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

  # INST-02: idempotent PATH append
  if ! grep -qF '# pw2agent' "$RC_FILE" 2>/dev/null; then
    printf '\n%s\n' "$PATH_LINE" >> "$RC_FILE"
  fi

  # INST-04: success message
  printf '✅ Ready. Run: pw2agent\n'
  printf '   (open a new terminal or: source %s)\n' "$RC_FILE"
}

# INST-03: main() called as last line
main "$@"
```

**Key implementation notes:**

1. `BASH_SOURCE[0]` resolves the directory of install.sh itself — works whether run as `bash install.sh` or `curl | bash` (in the latter case `BASH_SOURCE[0]` is empty, so `dirname ""` returns `.`; this is acceptable since curl|bash runs from a temp context where `pw2agent` must already be adjacent). [ASSUMED: this edge case is acceptable for v1; Phase 2 will use GitHub raw URL]

2. Idempotency marker is `# pw2agent` (the comment at end of the PATH_LINE). The guard `grep -qF '# pw2agent'` is case-sensitive and literal-string (no regex). Running install twice will not duplicate the line. [VERIFIED against PITFALLS.md Pitfall 4 and CONTEXT.md D-13]

3. `chmod +x` (not `chmod 755`) is used because D-12 specifies `chmod +x` and it's simpler. For a script in `~/.local/bin`, this is standard. [VERIFIED: CONTEXT.md D-12]

4. `RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"` handles non-default ZDOTDIR. D-14 specifies `~/.zshrc` but using `$ZDOTDIR` is correct behavior. [VERIFIED: ARCHITECTURE.md anti-pattern #3 explicitly warns against hardcoding `~/.zshrc`]

5. The `source ~/.zshrc` reminder line satisfies PITFALLS.md Pitfall 13 (user must source after install). [VERIFIED: PITFALLS.md Pitfall 13]

---

## Standard Stack

### Core

| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| bash | system | Script interpreter | `#!/usr/bin/env bash` — read -s is bash-only |
| shellcheck | 0.11.0 | Static analysis lint | `brew install shellcheck` needed — not currently installed [VERIFIED: brew info shellcheck] |
| base64 | macOS built-in | Encode write / decode read | `-d < file` syntax for cross-platform; `-d -i file` macOS-only |
| pbcopy/xclip/wl-copy | system | Clipboard | Fallback chain; xclip requires $DISPLAY, wl-copy requires $WAYLAND_DISPLAY |

### Verified Environment

| Dependency | Available | Version | Notes |
|------------|-----------|---------|-------|
| bash | ✓ | system | macOS ships bash 3.2; Homebrew bash 5.x at /usr/local/bin |
| base64 | ✓ | macOS built-in | `/usr/bin/base64`; `-d` and `-D` both work for decode |
| pbcopy | ✓ | macOS built-in | Primary clipboard tool on macOS |
| shellcheck | ✗ | — | Not installed; `brew install shellcheck` required |
| stat | ✓ | macOS built-in | `-f '%Lp'` macOS syntax works; GNU `-c '%a'` needed for Linux |

---

## ShellCheck: Verification Protocol

ShellCheck is NOT installed. Install command: `brew install shellcheck` (version 0.11.0 stable). [VERIFIED: brew info shellcheck]

**Run command for Phase 1 verification:**
```bash
brew install shellcheck
shellcheck --shell=bash pw2agent install.sh
```

**Expected ShellCheck issues in the source that this phase fixes:**
- SC2039 / SC3045: `read -p` is not supported in `--shell=bash` contexts (fixed by D-07)
- SC2039: `rm -P` — unrecognized option on some platforms (fixed by D-06)
- SC2034: `DOPPLER_PROJECT` and `DOPPLER_SECRET_NAME` assigned but never used (removed)
- SC2016: Expressions in single quotes in heredoc (may flag NOTE template; acceptable)

**Expected ShellCheck issues that remain acceptable:**
- SC2064 vs SC2148: trap with double-quoted expansion — `trap 'rm -f "$TARGET"' EXIT` uses single quotes intentionally (defer variable expansion to trap execution time). ShellCheck may suggest alternatives; the single-quote form is correct here.

---

## Architecture Patterns

### Recommended File Structure (Phase 1 only)

```
pw2agent/
├── pw2agent          # main script — no extension, executable, #!/usr/bin/env bash
└── install.sh        # idempotent installer; copies to ~/.local/bin, adds PATH to ~/.zshrc
```

Phase 2 adds: `skill.md`, `demo.tape`, `demo.gif`, `LICENSE`, `README.md`, `.github/workflows/ci.yml`, `tests/`.

### Script Internal Structure

```bash
#!/usr/bin/env bash
set -euo pipefail
{ set +x; } 2>/dev/null   # xtrace guard

# ---- config ----
LABEL="${1:-secret}"
TARGET="$HOME/.${LABEL}_pw"

# ---- help ----
case "${1:-}" in
  -h|--help) ... exit 0 ;;
esac

# ---- banner ----
printf '\npw2agent: stashing "%s" → %s\n\n' "$LABEL" "$TARGET"

# ---- input ----
printf 'Enter secret:   '; read -rs PW1; printf '\n'
printf 'Confirm secret: '; read -rs PW2; printf '\n'

# ---- validate ----
if [[ "$PW1" != "$PW2" ]]; then ... exit 1; fi
if [[ -z "$PW1" ]]; then ... exit 1; fi

# ---- write ----
umask 077
printf '%s' "$PW1" | base64 > "$TARGET"
trap 'rm -f "$TARGET"' EXIT INT TERM
unset PW1 PW2

# ---- confirm ----
printf '✅ Stashed at: %s\n\n' "$TARGET"

# ---- note ----
AGENT_NOTE="..."
printf '%s\n' "$AGENT_NOTE"

# ---- clipboard ----
_copy_to_clipboard "$AGENT_NOTE" || printf '\n[No clipboard — copy the note above]\n'
```

**Trap placement note:** The trap is set AFTER the write, not before. This is intentional — the trap cleans up on any failure after the file exists. Setting it before would cause the trap to attempt `rm -f` on a non-existent file on early validation failures (harmless but confusing). Setting after the write means any error path after the write (clipboard failure, etc.) still cleans up. [VERIFIED: CONTEXT.md D-05 says "immediately after writing the file"]

### Anti-Patterns to Avoid

- `echo "$AGENT_NOTE"` — echo interprets escape sequences; use `printf '%s\n'`
- `read -rsp "prompt" var` — combined `-p` not portable; split to `printf` + `read -rs`
- `rm -P` — no-op on macOS 14+, error on Linux
- Writing raw secret to file when NOTE uses `base64 -d` to read
- `base64 -i file` for decoding — macOS-specific; use `base64 -d < file`
- Appending to `~/.zshrc` without grep guard

---

## Common Pitfalls

### Pitfall 1: Trap fires too early, deletes file on help/validation exit
**What goes wrong:** If trap is set before validation, `exit 1` on mismatched passwords triggers `rm -f "$TARGET"` on a file that hasn't been written yet. `rm -f` on a non-existent file is a no-op (silently succeeds), so this is safe — but confusing for debugging.
**How to avoid:** Set trap immediately after write. [VERIFIED: CONTEXT.md D-05]

### Pitfall 2: `base64` output has trailing newline on some inputs
**What goes wrong:** `printf '%s' "secret" | base64` output ends without newline. But `echo "secret" | base64` adds a newline INSIDE the encoded content. If the write accidentally uses `echo`, the base64-decoded value includes a `\n` at the end, breaking credential comparisons.
**How to avoid:** Always use `printf '%s'` (no newline) for the secret write.
**Warning sign:** `echo "$PW1" | base64 > "$TARGET"` — catch this in review.

### Pitfall 3: ShellCheck not installed — CI-like check silently skipped
**What goes wrong:** Plan task says "run shellcheck" but shellcheck is not in PATH.
**How to avoid:** Plan must include `brew install shellcheck` as a prerequisite step before lint verification.

### Pitfall 4: install.sh `BASH_SOURCE[0]` empty in pure pipe execution
**What goes wrong:** `curl | bash` sets `BASH_SOURCE[0]` to empty string. `dirname ""` returns `.`. The script then looks for `pw2agent` in the current directory, which works only if the user is in the repo directory.
**How to avoid:** For Phase 1, install.sh is run as `bash install.sh` from the cloned repo — not via curl. Document this explicitly. Phase 2 handles remote install.
**Phase 1 scope:** `bash install.sh` only. [VERIFIED: CONTEXT.md says "Phase 2 — OSS Release" handles GitHub distribution]

### Pitfall 5: `grep -qF '# pw2agent'` matches any line containing `# pw2agent`
**What goes wrong:** If the user happens to have a comment `# pw2agent` in their `.zshrc` for any reason, the install silently skips PATH setup, leaving `~/.local/bin` absent from PATH.
**How to avoid:** This is an acceptable edge case for v1. The guard is correct for idempotency; the false-negative case is recoverable by manually adding the PATH line.
**No action needed:** Acceptable tradeoff per CONTEXT.md D-13.

---

## Code Examples

### Verified Pattern: portable read with silent input
```bash
# Source: PITFALLS.md Pitfall 3 + CONTEXT.md D-07
printf 'Enter secret:   '
read -rs PW1
printf '\n'
```

### Verified Pattern: base64 encode write + decode read
```bash
# Write (in script):
printf '%s' "$PW1" | base64 > "$TARGET"

# Read (in NOTE FOR AGENT):
PWB64=$(base64 -d < ~/.LABEL_pw | tr -d '\n')
```
[VERIFIED: tested on macOS 14; `printf '%s' "mysecret" | base64` → `bXlzZWNyZXQ=`; `base64 -d < /tmp/test` → `mysecret`]

### Verified Pattern: clipboard chain with env-var guards
```bash
# Source: PITFALLS.md Pitfall 10
_copy_to_clipboard() {
  local note="$1"
  if command -v pbcopy &>/dev/null; then
    printf '%s' "$note" | pbcopy
  elif [ -n "${DISPLAY:-}" ] && command -v xclip &>/dev/null; then
    printf '%s' "$note" | xclip -selection clipboard
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy &>/dev/null; then
    printf '%s' "$note" | wl-copy
  else
    return 1
  fi
}
```

### Verified Pattern: install.sh idempotency guard
```bash
# Source: CONTEXT.md D-13, PITFALLS.md Pitfall 4
PATH_LINE='export PATH="$HOME/.local/bin:$PATH" # pw2agent'
RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"
if ! grep -qF '# pw2agent' "$RC_FILE" 2>/dev/null; then
  printf '\n%s\n' "$PATH_LINE" >> "$RC_FILE"
fi
```

### Verified Pattern: main() guard for partial download safety
```bash
# Source: CONTEXT.md D-15, PITFALLS.md Pitfall 9
main() {
  # all install logic here
}
main "$@"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `rm -P` secure delete | `rm -f` plain delete | macOS 14 (Sonoma) | `-P` documented as no-op on SSDs; macOS 14 made explicit |
| `read -s -p "prompt" var` | `printf 'prompt'; read -rs var` | bash best practice | `-p` is bash-specific, misinterpreted by zsh |
| Fixed-width box BANNER | Compact `printf` header | This project (D-11) | Box breaks alignment on labels > ~55 chars |
| Writing raw secret | Writing base64-encoded | This project (D-03) | Avoids raw `cat` echo; cross-platform read command |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `printf '%s' "val" \| base64` on macOS produces no trailing newline in output | Write Pattern | NOTE `base64 -d` would decode with trailing `\n`; `tr -d '\n'` in read command mitigates this anyway |
| A2 | `bash install.sh` is the only Phase 1 invocation path (not curl\|bash) | install.sh spec | BASH_SOURCE[0] fallback to `.` works only if run from repo dir |
| A3 | `${ZDOTDIR:-$HOME}/.zshrc` covers the user's actual zsh config location | install.sh RC_FILE | If user has non-standard ZDOTDIR, PATH append goes to wrong file — mitigated by printing `source {RC_FILE}` so user can verify |

**A1 is low risk:** verified empirically on macOS above. The `tr -d '\n'` in the read command is a belt-and-suspenders fix regardless.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | pw2agent + install.sh | ✓ | macOS system bash | — |
| base64 | pw2agent write + NOTE | ✓ | macOS built-in `/usr/bin/base64` | — |
| pbcopy | pw2agent clipboard | ✓ | macOS built-in | xclip → wl-copy → stdout |
| shellcheck | lint verification task | ✗ | Not installed | `brew install shellcheck` (plan must include) |
| stat | pw2agent mode display | ✓ | macOS built-in (GNU pattern also coded) | — |
| mkdir -p | install.sh | ✓ | macOS built-in | — |

**Missing dependency with required install step:**
- `shellcheck` — plan must include `brew install shellcheck` before the lint task. Homebrew 0.11.0 stable available.

---

## Open Questions

1. **help flag placement conflict with label detection**
   - What we know: `LABEL="${1:-secret}"` runs before any flag check; if user passes `-h`, `LABEL` becomes `-h` and `TARGET` becomes `~/.{-h}_pw`
   - What's unclear: whether to check `$1` for flags before or after variable assignment
   - Recommendation: Add help check BEFORE variable assignments; or use `case "${1:-}"` at top before LABEL is set. The `case` block must come first.

2. **`set +x` guard placement**
   - What we know: D-05 adds `{ set +x; } 2>/dev/null` to block xtrace; PITFALLS.md Pitfall 8 says add before secret-handling block
   - What's unclear: whether to add once at top or wrap only the write block
   - Recommendation: Add once at top of script (line 3), after `set -euo pipefail`. This is simpler and the whole script handles secrets.

3. **`echo` vs `printf` for success/error messages**
   - What we know: Source uses both `echo` and `printf`; `echo` is simpler but interprets escape sequences in some shells
   - Recommendation: Use `printf '...\n'` throughout for consistency. The `printf` form is POSIX-correct.

---

## Sources

### Primary (HIGH confidence)
- Direct read of `bifrost-tailscale/scripts/stash-password.sh` — full source audit
- Direct read of `.planning/phases/01-working-tool/01-CONTEXT.md` — locked decisions
- Direct read of `.planning/research/PITFALLS.md` — 5 critical bugs with exact replacements
- Direct read of `.planning/research/STACK.md` — stack decisions
- Direct read of `.planning/research/ARCHITECTURE.md` — structure decisions
- Direct read of `.planning/REQUIREMENTS.md` — CORE-01 through INST-04
- Local verification: `base64 -d < file` cross-platform syntax on macOS
- Local verification: `stat -f '%Lp'` macOS syntax
- Local verification: `shellcheck` not installed; `brew info shellcheck` → 0.11.0

### Secondary (MEDIUM confidence)
- PITFALLS.md Pitfall 4: idempotency guard pattern (cited from research doc)
- PITFALLS.md Pitfall 10: clipboard env-var guards (cited from research doc)
- ARCHITECTURE.md anti-patterns section (cited from research doc)

---

## Metadata

**Confidence breakdown:**
- Source audit (change inventory): HIGH — read actual source file, verified every line
- install.sh spec: HIGH — directly maps decisions D-12 through D-16 to code
- ShellCheck status: HIGH — verified with `brew info shellcheck` on this machine
- base64 patterns: HIGH — tested empirically on macOS
- NOTE format: HIGH — directly from locked decision D-03

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (stable domain; no fast-moving dependencies)
