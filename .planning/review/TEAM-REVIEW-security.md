# Security Skeptic Review

## Verdict
SHIP — with two POLISH items the author should knock out before tagging v1.

The core design is sound: secret enters via `read -rs` (never in argv, env, or history), gets base64-encoded and written under `umask 077` to a mode-600 file, and the clipboard NOTE contains the file *path*, not the secret. No network calls, no logs, no temp files holding plaintext. I looked for the usual leakage vectors and did not find a blocker.

## Findings

### [POLISH] Trap for cleanup is armed AFTER the write, not before
**CVE-class:** TOCTOU / Window-of-exposure
**Evidence:** `pw2agent:42-44`
```
umask 077
printf '%s' "$PW1" | base64 > "$TARGET"
trap 'rm -f "$TARGET"' EXIT INT TERM
```
**Attack scenario:** Between line 43 (file created) and line 44 (trap armed), a SIGINT leaves `~/.{label}_pw` on disk with no cleanup trap yet registered. The window is microseconds and the file is already mode 600, so real exposure is minimal — but the *intent* of the trap is to catch exactly these cases and it doesn't cover the first instant of the file's existence. Also note: on the successful path the trap is intentionally disarmed at line 80 so the file persists for the agent, which is correct.
**Fix:** Arm the trap first, then write:
```
umask 077
trap 'rm -f "$TARGET"' EXIT INT TERM
printf '%s' "$PW1" | base64 > "$TARGET"
```
No behavioural change on the happy path; closes the tiny gap.

### [POLISH] README undersells that base64 is encoding, not encryption
**CVE-class:** Misleading-security / user-expectation
**Evidence:** `README.md:44-48`, `pw2agent:55` ("base64-encoded")
**Attack scenario:** A user skimming the "Security" section sees "base64-encoded" alongside "mode 600" and may infer that base64 provides confidentiality. It doesn't — anyone who reads the file reads the secret (one `base64 -d` away). The file-mode does the real work; base64 is just there so the secret survives newlines/binary bytes cleanly in a text file.
**Fix:** One line in `README.md` under "Security": *"Base64 is format-encoding, not encryption — confidentiality comes from the mode-600 file permissions, not the base64 wrapper."* Also consider rewording the NOTE block's `File:` line to `(mode 600, base64-wrapped)` or similar to avoid the encryption vibe.

### [NIT] `set -x` defence runs after the shebang, not in the environment
**CVE-class:** Information Disclosure (niche)
**Evidence:** `pw2agent:3` (`{ set +x; } 2>/dev/null`)
**Attack scenario:** If a caller does `SHELLOPTS=xtrace pw2agent` (exported xtrace inherited across the bash invocation), line 3 suppresses further tracing, but `set -euo pipefail` on line 2 will already have emitted a trace line before the disable takes effect. More concerning: if someone invokes `bash -x ./pw2agent`, the very first traced line is `set -euo pipefail`, then `{ set +x; } 2>/dev/null` — and from there tracing is off. So in practice the secret on line 43 is *not* traced. I'm flagging this as a nit rather than a finding because I could not construct a realistic scenario where the plaintext reaches xtrace output. The existing line-3 guard is sufficient.
**Fix:** None required. Optionally add a comment explaining why line 3 exists, to protect future refactors.

### [NIT] `install.sh` curl-mode has no checksum / signature
**CVE-class:** Supply-chain / MITM-against-TLS-break
**Evidence:** `install.sh:17` (`curl -fsSL "$GITHUB_RAW/pw2agent" -o "$SCRIPT_SRC"`) and `README.md:10` (`curl ... | bash`)
**Attack scenario:** Standard `curl | bash` concerns — a compromise of the GitHub repo, a compromised CA, or any MITM that breaks TLS delivers arbitrary code. This is the same threat model as every `curl | bash` installer in the world, so I'm not blocking on it. For a tool whose *value prop is security-conscious handling of secrets*, though, it's worth at least acknowledging.
**Fix (optional, v1.x):** Publish a tagged release, have `install.sh` download `pw2agent` at a pinned commit or tag, and verify SHA-256 against a value embedded in `install.sh`. Or tell users to `git clone && ./install.sh` and treat `curl | bash` as the convenience path with a noted trust assumption.

### [NIT] `install.sh` mktemp has no cleanup trap
**CVE-class:** Temp-file leak (non-secret)
**Evidence:** `install.sh:16,31` — `mktemp` creates temp, `rm -f` at line 31 cleans it up, but if `cp`/`chmod`/`grep`/`>>` fails between lines 17 and 31 the temp file persists.
**Attack scenario:** The contents are the public `pw2agent` script, not a secret. So "leak" is aesthetic — no confidentiality impact. `set -e` means a failure exits before `rm -f`, leaving a temp file in `$TMPDIR` until the OS cleans it.
**Fix:** `trap 'rm -f "$SCRIPT_SRC"' EXIT` right after `SCRIPT_SRC="$(mktemp)"`. One line.

### [NIT] `skill.md` does not tell the agent to `unset PWB64` after use
**CVE-class:** In-memory secret persistence
**Evidence:** `skill.md:11-14`
**Attack scenario:** The skill correctly tells the agent to `rm -f ~/.{label}_pw` after use, but `$PWB64` remains in the shell's environment for the life of the session (and any subshells the agent spawns). A later `env` dump, a crash report, a child process that inherits environment, or a later command captured in a transcript could expose it.
**Fix:** Add step 5 to `skill.md`: `5. Clear the variable: unset PWB64`. Also recommend the agent avoid exporting `PWB64` to child processes (use it in the same shell only).

### [OBSERVATION — not a finding] `demo.tape` uses `hunter2`
Confirmed intentional per brief. No real credential committed. The `rm -f ~/.demo_pw` cleanup is present.

### [OBSERVATION — not a finding] skill.md "do not print or log its value" is best-effort
Models follow natural-language instructions at best-effort. Any downstream prompt (e.g., "echo your env vars to debug") could override. This is a fundamental limitation of prompt-based control, not a bug in this skill. The README doesn't claim otherwise. Acceptable.

## Summary
- Argv / env / history: clean.
- File permissions: mode 600 via `umask 077` set before write — correct.
- Clipboard: NOTE contains the path, not the secret — correct and nicely thought-through.
- Trap: off-by-one but microsecond window, already-protected file — polish.
- Xtrace: defended; I could not break it.
- Base64: functionally fine, README wording could be clearer.
- Installer: standard `curl | bash` caveats, no worse than peers.

The tool does what it advertises. Ship with the two POLISH items; the NITs can wait for v1.1.

## Questions for Other Reviewers
- @shipping-skeptic: README's "No network calls" claim is true of `pw2agent` itself but `install.sh` obviously does network. Do you think the README wording is misleading enough to flag?
- @portability-skeptic: `stat -f` (BSD) / `stat -c` (GNU) fallback on `pw2agent:49` looks right to me — can you confirm on Linux? Also, `pbcopy`/`xclip`/`wl-copy` triage on lines 62-73 — any terminals / distros where none of those are present and the user would expect better?
- @spec-skeptic: The skill says "use `$PWB64` for the task" but doesn't define "the task" — does the user's NOTE need to include task context, or is the skill relying on the surrounding conversation? Seems fine but worth your read.

---

## Round 2 — on commit 8911a3d

### Verification of round-1 findings

- **[POLISH] Trap before write** — **FIXED.** `pw2agent:43` now arms the trap before `pw2agent:44` writes. Cleanup covers the write itself. The intentional `trap - EXIT INT TERM` on line 80 remains, so the file still persists for the agent on the happy path.
- **[POLISH] Base64-is-not-encryption note** — **FIXED.** `README.md:47` adds: *"Base64 is used to survive shell-unsafe bytes — it is encoding, not encryption. Confidentiality comes from the mode-600 file and the `rm -f` step, not the encoding."* Wording is accurate and well-placed.
- **[NIT] install.sh mktemp trap** — **FIXED.** `install.sh:23-24` arms `trap 'rm -f "$SCRIPT_SRC"' EXIT INT TERM` immediately after `mktemp`. Also moved inside `main()`, which is correct (bash traps are process-scoped, so this still fires on script exit). Disarm on success at line 37.
- **[NIT] skill.md unset PWB64** — **FIXED.** `skill.md:14` now reads `rm -f ~/.secret_pw && unset PWB64`.
- **[NIT] `set -x` defence** — unchanged. Still sufficient.
- **[NIT] curl-bash no checksum** — unchanged. Acceptable for v1 per original review.

All round-1 findings that asked for code change are resolved. No regressions introduced.

### New issues introduced by the round-1 fixes

I went looking for regressions and found none at blocker or polish level. Notes:

#### [NIT — tiny] `rm -f && unset PWB64` fails open on rm failure
**Evidence:** `skill.md:14`
**Scenario:** `&&` short-circuits — if `rm -f ~/.secret_pw` fails (e.g., the file was chmod'd or owned by another user in a pathological setup), `unset PWB64` never runs and the secret lingers in the shell's memory.
**Fix:** Change `&&` to `;` or a newline so the unset always runs: `rm -f ~/.secret_pw; unset PWB64`. For `rm -f` on a user-owned file this is nearly impossible to hit, so it's a belt-and-braces thing — raising for completeness, not blocking.

#### [OBSERVATION — not a finding] `tr -d '\n'` on base64 output
**Evidence:** `pw2agent:44` — `printf '%s' "$PW1" | base64 | tr -d '\n' > "$TARGET"`
macOS `base64` wraps at 76 columns by default; `tr -d '\n'` strips the wrap newlines AND any trailing newline, collapsing output to one line. The skill's read recipe also does `| tr -d '\n'`, so this is idempotent end-to-end. No security impact.

#### [OBSERVATION — not a finding] `$SHELL` drives rc-file choice
**Evidence:** `install.sh:11-15`
`$SHELL` is user-controllable but the `case` maps only to three hardcoded paths (`${ZDOTDIR:-$HOME}/.zshrc`, `$HOME/.bashrc`, `$HOME/.profile`). No content from `$SHELL` is interpolated into a path, so there's no injection surface. Fish / dash / other-shell users fall through to `.profile`, which Fish doesn't source — that's a portability nit for `@portability-skeptic`, not a security issue.

#### [OBSERVATION — not a finding] Trap inside `main()`
**Evidence:** `install.sh:24`
Bash traps are process-scoped, not function-scoped, so arming inside `main` and disarming inside `main` works correctly. If `curl` fails, `set -e` exits the process, the EXIT trap fires, `$SCRIPT_SRC` is removed. If `cp`/`chmod` fail after download, same thing. Good.

### Verdict (Round 2)
**SHIP.** All R1 items addressed. No new blockers or polish items introduced. The one tiny `&&`-vs-`;` nit in `skill.md` is a future-you robustness improvement, not a ship gate.
