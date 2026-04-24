# Portability Skeptic Review

## Verdict
**BLOCK** — install.sh assumes zsh on a project that advertises Linux support; Ubuntu/Debian/Fedora default to bash and will silently install a PATH line into a file their shell never reads.

## Linux Compatibility Matrix

| Feature | macOS 14 | Ubuntu 22/24 (bash) | Alpine | Risk |
|---|---|---|---|---|
| Shebang `#!/usr/bin/env bash` (pw2agent:1, install.sh:1) | ✓ | ✓ | ✗ default (needs `apk add bash`) | MEDIUM — Alpine users get "bash: not found" |
| `set -euo pipefail` | ✓ | ✓ | ✓ (with bash) | none |
| `read -rs` (pw2agent:26-27) | ✓ | ✓ | ✓ (with bash) | none — bash builtin |
| `printf '%s'` and `\n` only | ✓ | ✓ | ✓ | none — POSIX |
| `stat -f '%Lp' 2>/dev/null \|\| stat -c '%a'` (pw2agent:49) | ✓ BSD first arm | ✓ falls through to GNU `-c` | ✓ (busybox stat supports `-c`) | none — fallback chain works |
| `base64` encode (pw2agent:43) | ✓ wraps at 76 | ✓ wraps at 76 | ✓ (busybox base64) | none |
| `base64 -d` decode in NOTE (pw2agent:56) | ✓ | ✓ | ✓ | none — wrapping decodes correctly both ways |
| `wc -c < file` | ✓ | ✓ | ✓ | none — POSIX |
| `umask 077` | ✓ | ✓ | ✓ | none |
| `trap … EXIT INT TERM` | ✓ | ✓ | ✓ | none |
| `command -v pbcopy` (pw2agent:64) | ✓ present | ✗ absent → falls through | ✗ absent → falls through | none — fallback handled |
| `xclip` / `wl-copy` (pw2agent:66-69) | N/A | ✗ **not preinstalled** on stock Ubuntu/Debian/Fedora — stdout fallback fires | ✗ absent → stdout fallback | LOW — acceptable UX, NOTE is printed to stdout anyway at line 59 |
| `mkdir -p "$HOME/.local/bin"` (install.sh:23) | ✓ | ✓ (XDG) | ✓ | none |
| `grep -qF '# pw2agent'` (install.sh:27) | ✓ | ✓ | ✓ (busybox grep -F) | none — POSIX |
| `mktemp` no-args (install.sh:16) | ✓ `/tmp/tmp.XXXXXXXX` | ✓ `/tmp/tmp.XXXXXXXXXX` | ✓ (busybox mktemp) | none |
| `curl -fsSL` (install.sh:17, README:10) | ✓ preinstalled | ✓ desktop, ✗ slim/server/minimal containers | ✗ `apk add curl` needed | LOW — dev workstations have it |
| **Unconditional `${ZDOTDIR:-$HOME}/.zshrc` target (install.sh:8)** | ✓ zsh is default on macOS 10.15+ | ✗ **bash is default; .zshrc is never sourced** | ✗ ash is default; .zshrc never sourced | **BLOCKER** |
| VHS demo regen (demo.tape) | `brew install vhs` | `go install` + chromium | n/a | out of Phase 2 scope, but undocumented |

## Findings

### [BLOCKER] install.sh hardcodes `.zshrc` — breaks on bash-default Linux distros
**Evidence:** `install.sh:8` — `RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"` with no shell detection. Line 28 appends the PATH export to that file regardless of the user's login shell.
**Platform:** Ubuntu 20.04/22.04/24.04, Debian, Fedora, Alpine — every Linux distro whose default login shell is not zsh.
**User impact:**
1. User runs `curl … | bash` on Ubuntu. Installer creates `~/.zshrc` (if absent) or appends to it, then prints "✅ Ready. Run: pw2agent".
2. User opens a new terminal (bash reads `~/.bashrc` / `~/.profile`, **never `.zshrc`**).
3. `pw2agent` → `command not found`. User has no way to discover why — the installer reported success.
4. Idempotency check `grep -qF '# pw2agent' "$RC_FILE"` looks only at `.zshrc`; re-running the installer keeps writing to the wrong file.
**Fix:** detect login shell and target the correct rc file. Minimal patch:
```bash
case "${SHELL##*/}" in
  zsh)  RC_FILE="${ZDOTDIR:-$HOME}/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="$HOME/.profile" ;;
esac
```
Or append to both `.bashrc` and `.zshrc` if they exist, guarded by the same grep check. Either way, Phase 1 success criterion #4 ("passes ShellCheck with zero warnings on macOS and Linux") is about lint, not runtime correctness, so it wouldn't have caught this. ROADMAP Phase 1 goal — "installable and usable on macOS + Linux" — is **not met** as shipped.

### [BLOCKER] ROADMAP claims "ShellCheck zero warnings on macOS AND Linux" — unverified
**Evidence:** `.planning/ROADMAP.md:22` asserts the criterion but no CI config, no `shellcheckrc`, no recorded run exists in the repo. No `.github/workflows/`. The phase is marked complete ✅.
**Platform:** verification gap affects any platform.
**User impact:** none direct; it's a credibility issue — the "Complete ✅ 2026-04-24" stamp on Phase 1 is based on an unverified claim. If a stranger runs ShellCheck on Linux and finds warnings, the OSS reputation takes a hit on day 1.
**Fix:** run `shellcheck pw2agent install.sh` on both macOS and a Linux box; commit the output, or better, add a GitHub Actions workflow that runs ShellCheck on `ubuntu-latest` + `macos-latest`.

### [NIT] Alpine requires `bash` and `curl` — README is silent
**Evidence:** `pw2agent:1` and `install.sh:1` both use `#!/usr/bin/env bash`. `install.sh:17` uses `curl`. Alpine's default shell is `ash` (busybox) and `curl` is not preinstalled.
**Platform:** Alpine, minimal Docker base images.
**User impact:** `curl … | bash` fails with "bash: not found" or "curl: not found" depending on which is missing. Confusing error for devs trying to use pw2agent inside a container.
**Fix:** add one line to README under Install: `# Alpine users: apk add bash curl first`. Or state "Linux: bash + curl required" explicitly.

### [NIT] xclip/wl-copy not preinstalled on stock Linux desktops
**Evidence:** `pw2agent:66-69` checks `command -v xclip` and `command -v wl-copy`. Neither is installed by default on Ubuntu desktop, Fedora Workstation, or Debian.
**Platform:** stock Linux desktops without clipboard helpers.
**User impact:** acceptable — falls through to stdout fallback at line 78, user copies the NOTE manually. The NOTE is already printed to stdout at line 59 regardless, so this is not a data-loss scenario. Just worth calling out in README.
**Fix:** one-line README note: "Linux: install xclip (X11) or wl-clipboard (Wayland) for auto-copy; otherwise copy the printed NOTE by hand."

### [POLISH] `trap 'rm -f "$TARGET"' EXIT` (pw2agent:44) is cleared only at line 80 — if the clipboard step fails the secret file is deleted
**Evidence:** `_copy_to_clipboard` returns 1 when no tool is found (pw2agent:71); the `if` at line 75 takes the `else` branch and prints to stderr, but `trap - EXIT INT TERM` at line 80 still runs **after** the else branch — so the file survives. OK, verified. This is fine, noting only that the trap guarding the whole post-write block is subtle; any future editor who adds an early `exit 1` between line 44 and 80 will silently destroy the user's just-entered secret.
**Platform:** all.
**User impact:** none currently; future-hazard.
**Fix:** add a code comment at pw2agent:44 — `# NB: trap is cleared at line 80 on success path only — any early exit between here and there deletes the file on purpose (protects against half-writes on Ctrl-C).`

### [POLISH] demo.tape regeneration not documented
**Evidence:** `demo.tape` exists but no `make demo` target, no README note about VHS.
**Platform:** contributor workflow.
**User impact:** a PR author who wants to update the demo has to reverse-engineer the toolchain (`brew install vhs` on macOS, `go install github.com/charmbracelet/vhs@latest` + Chrome/Chromium on Linux).
**Fix:** out of Phase 2 scope per the brief; flag for later.

## Questions for Other Reviewers

- **@shipping-skeptic:** ROADMAP Phase 1 is marked ✅ complete on 2026-04-24 with criterion "installable and usable on macOS + Linux." The `.zshrc`-only install.sh makes this criterion demonstrably false on Linux. Do we consider this a ship-blocker, or does the README caveat ("install one-liner") implicitly cover only zsh users?
- **@spec-skeptic:** REQUIREMENTS should explicitly state what "Linux support" means — which distros, which default shells. Right now it's ambient in the ROADMAP success criteria. Worth pinning down before ship.
- **@security-skeptic:** the base64 `NOTE FOR AGENT` recommends `PWB64=$(base64 -d < ~/.${LABEL}_pw | tr -d '\n')` — `tr -d '\n'` strips newlines after decode, which is correct for wrapped base64 but the variable lives in shell env afterwards. Is that an acceptable surface? (Orthogonal to portability but I noticed.)

## Summary for team-lead

The core pw2agent script is remarkably portable — the `stat` fallback, base64, umask, trap, and clipboard chain all work correctly across macOS and common Linux distros. The installer is where portability breaks: one hardcoded path (`.zshrc`) silently fails for the majority of Linux users, who are on bash. This is a 5-line fix but until it lands, "Linux support" in the ROADMAP is aspirational, not factual. Hold the OSS publish until install.sh is shell-aware.

---

## Round 2 — commit 8911a3d verification

### Re-verification of Round 1 findings

| Round 1 finding | Status in 8911a3d | Evidence |
|---|---|---|
| **BLOCKER:** install.sh hardcodes `.zshrc` | ✅ **FIXED** | `install.sh:11-15` — `case "${SHELL##*/}"` picks `.zshrc` / `.bashrc` / `.profile` |
| **BLOCKER:** ShellCheck Linux claim unverified | ⚠️ **Still unverified but downgraded** — no `.github/workflows/` added, no recorded Linux run. Code reads lint-clean; not blocking v1 OSS release on its own. |
| Alpine needs `apk add bash curl` (NIT) | Not addressed in README. Still a NIT. |
| xclip/wl-copy not preinstalled on stock Linux (NIT) | Not addressed. Stdout fallback still fires. Still acceptable UX — NOTE is printed regardless. |
| Trap timing future-hazard (POLISH) | Addressed differently: trap moved to **before** write (`pw2agent:43`), which is actually safer — if base64 or `tr -d '\n'` pipeline fails under pipefail, file is cleaned up. Good. |
| VHS regen undocumented (POLISH) | Not addressed. Out of Phase 2 scope. |

### New Round-2 findings

### [POLISH] `$SHELL` detection falls to `.profile` for fish/nu/xonsh users
**Evidence:** `install.sh:11-15` — `case "${SHELL##*/}" in zsh|bash|*)`. Anything non-bash/zsh lands in `*) RC_FILE="$HOME/.profile"`.
**Platform:** Linux/macOS fish, nu, xonsh users.
**User impact:** fish does not source `.profile`. Non-login bash doesn't either. A fish user running the one-liner would get "✅ Ready" but `pw2agent` not on PATH when they open a new fish session.
**Fix (optional):** either detect fish explicitly (`fish) RC_FILE="$HOME/.config/fish/conf.d/pw2agent.fish" ...` with fish syntax) or print a conspicuous warning when falling to `.profile`: "Your shell ($SHELL) doesn't have specific support — wrote PATH to ~/.profile, which may not be sourced. Add `$HOME/.local/bin` to PATH manually if `pw2agent` isn't found."
**Severity:** POLISH — fish is <5% of dev population. Don't block on this.

### [NIT] `$DISPLAY` gate on xclip (pw2agent:66) vs WSL2
**Evidence:** `pw2agent:66` — `[ -n "${DISPLAY:-}" ] && command -v xclip`. On WSL2, $DISPLAY may be set (for WSLg) but X server state can be flaky.
**Platform:** WSL2.
**User impact:** xclip may hang waiting for a display on some WSL2 configs. Low probability; WSL2 + wl-copy is usually preferred.
**Fix:** acceptable as-is. Could add a timeout wrapper (`timeout 2 xclip …`) if complaints surface. POLISH.

### [NIT] `set -e` + `[[ … ]] && { … }` on install.sh:37 is safe
**Evidence:** `install.sh:37` — `[[ "$downloaded" == true ]] && { rm -f "$SCRIPT_SRC"; trap - EXIT INT TERM; }`. When `downloaded=false`, the left side returns 1, compound returns 1. Under `set -e`, this would normally exit — but bash excludes commands in `&&`/`||` contexts from `-e` triggering. Verified the pattern is safe.
**Platform:** all.
**User impact:** none. Just noting I checked.

### [POLISH] Trap on install.sh:24 is armed only on download path
**Evidence:** `install.sh:24` — `trap 'rm -f "$SCRIPT_SRC"' EXIT INT TERM` only inside the `else` (download) branch. On the local-install path (`-f "$(dirname …)/pw2agent"` exists), no trap is set — correct because `SCRIPT_SRC` is a real checked-in file, not a temp.
**Platform:** all.
**User impact:** none. Correct design.

### [POLISH] `unset PWB64` in skill.md step 4 is a shell-in-caller hint
Not portability-relevant, but noting: the `rm -f … && unset PWB64` recommendation in the NOTE/skill.md assumes the agent ran the read in the same shell where `unset` applies. For Claude Code and most agent runners, `bash -c` is a new shell each time, so `unset` is a no-op. Harmless but non-load-bearing. Flag for @security-skeptic.

### Round 2 matrix delta (only changed rows)

| Feature | macOS | Ubuntu/Debian (bash) | Fish/Nu | Risk change |
|---|---|---|---|---|
| install.sh shell detection | ✓ `.zshrc` | ✓ `.bashrc` | ⚠ falls to `.profile` (not sourced by fish) | **BLOCKER → POLISH** |
| trap placement on write | ✓ pre-write | ✓ pre-write | ✓ | POLISH → resolved |
| base64 trailing newline in file | ✓ `tr -d '\n'` strips | ✓ | ✓ | no regression |

### Round 2 verdict

**SHIP** — the portability BLOCKER is fully resolved. Remaining items are POLISH/NIT that don't block an initial OSS v1 release. Recommend:
- Ship now with the current fix.
- Post-release: add a GitHub Actions workflow running ShellCheck on `ubuntu-latest` + `macos-latest` to put the ROADMAP claim on record.
- Post-release: fish-shell warning when falling to `.profile`.
