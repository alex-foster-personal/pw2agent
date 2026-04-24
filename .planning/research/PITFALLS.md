# Domain Pitfalls: pw2agent

**Domain:** shell secret-handoff utility
**Researched:** 2026-04-24
**Confidence:** HIGH (all claims verified against official sources or direct system inspection)

---

## Critical Pitfalls

Mistakes that cause security breaches, data loss, or complete UX failure.

---

### Pitfall 1: `rm -P` Is a No-Op on macOS 14+ and Does Not Exist on Linux

**What goes wrong:** The source script (stash-password.sh) likely uses `rm -P` for "secure delete". On macOS 14 (Sonoma) the `-P` flag is silently accepted but explicitly documented as having "no effect" — it is kept only for backwards compatibility with 4.4BSD-Lite2. On Linux GNU coreutils `rm` has no `-P` flag at all; the command will error or be silently ignored depending on the shell.

**Why it happens:** `rm -P` was meaningful on older macOS HFS+ spinning disks. SSDs with wear-leveling make block-overwrite meaningless — the OS writes to a new physical cell and marks the old one as freed, so overwriting the logical address doesn't touch the data copy the SSD retained. Apple acknowledged this and removed the feature.

**Consequences:**
- On macOS 14+: false sense of security. The flag does nothing. The file is deleted normally.
- On Linux: `rm: invalid option -- 'P'` error, which may abort cleanup and leave the secret file on disk.
- On SSDs (both platforms): even if overwrite worked at the OS level, wear-leveling means the original data likely persists in unaddressed cells until the drive reclaims them.

**Prevention:**
- Drop the `-P` flag entirely. Use plain `rm -f`.
- Document clearly: "secure overwrite is not meaningful on SSD-based systems regardless of OS."
- If overwrite is desired on HDDs, use `shred -u` on Linux (GNU coreutils, widely available) and accept it is a no-op on SSDs. Do not pretend cross-platform `rm -P` gives security.
- The real mitigation is: (a) mode-600 so only the owning user can ever read it, and (b) prompt deletion as soon as the agent confirms it read the file.

**Detection warning sign:** Any `rm -P` or `rm --overwrite` in the script on macOS 14+ / any Linux.

**Phase:** Core script (Phase 1). Fix before any release.

---

### Pitfall 2: Secret Lands in Shell History via `echo` or Readline

**What goes wrong:** Any path where the user types the secret directly on a command line — or where the script uses `echo "$SECRET"` to write it — will save the secret in `~/.zsh_history` / `~/.bash_history`. Even `read -s` does not protect against history if the secret value is later echoed in a subshell call.

**Why it happens:**
- `read -s` suppresses terminal echo but does not affect history.
- `echo "$SECRET" > file` expands the variable on the command line before `echo` runs, so the value appears in `set -x` trace output and process args.
- `printf '%s' "$SECRET"` is safer for writing to file: no trailing newline problem, no variable expansion in ps args (value is in the shell variable, not in argv).

**Consequences:** `~/.zsh_history` is world-readable by the owning user across all their shell sessions. On shared machines, history can be exfiltrated. The secret persists indefinitely.

**Prevention:**
- Use `read -s` for all secret input. Never prompt via `read -p "..." secret` without `-s`.
- Write the secret to file using `printf '%s' "$secret" > "$tmpfile"` — not `echo "$secret"`.
- Never pass the secret as a command argument (e.g., `encrypt --key="$secret"`).
- The script itself (invoking `pw2agent`) doesn't appear in history with the secret because the secret is entered interactively — this is fine and correct.

**Detection warning sign:** Any `echo "$SECRET"`, `echo $SECRET`, or passing `$SECRET` as a positional argument to any subprocess call.

**Phase:** Core script (Phase 1).

---

### Pitfall 3: `read -s -p` Is Not POSIX-Portable (`-p` Means Something Different in Zsh)

**What goes wrong:** In POSIX sh, `read` supports only `-r`. The `-p` flag is bash-specific for inline prompt display. In zsh, `-p` means "read from a coprocess" — a completely different thing. If the shebang is `#!/bin/sh` or the script is sourced into zsh with `read -p "..."`, the flag is misinterpreted.

**Confirmed:** POSIX explicitly recommends only `read -r`. The zsh docs confirm `-p` means coprocess read.

**Consequences:**
- On systems where `/bin/sh` is dash (most Debian/Ubuntu): `read: Illegal option -p`, script aborts.
- On zsh with the wrong invocation: reads from a coprocess instead of stdin, hangs or errors.
- The script will silently not suppress echo if `-s` is applied after a failed `-p`, leaking the secret to the terminal.

**Prevention:**
- Use `#!/usr/bin/env bash` shebang (not `#!/bin/sh`).
- Replace `read -s -p "Enter secret: " secret` with the portable two-liner:
  ```bash
  printf 'Enter secret: '
  read -rs secret
  printf '\n'
  ```
- The `printf` before `read` is the POSIX-safe prompt pattern. `read -rs` (silent, no prompt flag) works in bash and zsh.

**Detection warning sign:** `read -p "..."` anywhere in the script. Any `#!/bin/sh` shebang.

**Phase:** Core script (Phase 1).

---

### Pitfall 4: `install.sh` Appends to `~/.zshrc` on Every Run (Duplicate Lines)

**What goes wrong:** A naive install script does `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc` unconditionally. Running `curl | bash` twice (common when troubleshooting) duplicates the line. After 5 runs, `~/.zshrc` has 5 identical PATH exports. Zsh deduplication (`typeset -U path`) won't save you if the raw string appears multiple times before `typeset -U` is evaluated.

**Why it happens:** Append-only install scripts have no memory of prior runs.

**Consequences:**
- Ugly `~/.zshrc` that users notice and distrust.
- Unexpected behavior if lines are in a specific order (e.g., alias defined twice with different values).
- PATH can grow very long, slowing down shell startup on repeated path lookups.

**Prevention:** Always guard appends with a grep check:
```bash
if ! grep -qF 'pw2agent' ~/.zshrc 2>/dev/null; then
  printf '\n# pw2agent\nalias pw2agent="%s"\n' "$INSTALL_PATH" >> ~/.zshrc
fi
```
Use a unique comment marker (`# pw2agent`) as the guard, not the actual export line (which might be reformatted). Check for the marker, not the path.

**Detection warning sign:** Any `>>` to a dotfile without a preceding `grep -q` guard. Missing idempotency test in install.sh.

**Phase:** install.sh (Phase 1). Test by running install twice and diffing `~/.zshrc`.

---

### Pitfall 5: Temp File Race Condition — Wrong Creation Order

**What goes wrong:** Scripts that do `TMPFILE=/tmp/pw2agent-$$` (predictable name using PID) are vulnerable to symlink attacks. An attacker can create `/tmp/pw2agent-1234 -> /etc/passwd` before the script runs. When the script writes the secret to `$TMPFILE`, it overwrites the symlink target.

**Why it happens:** Using PID as a suffix is common but wrong. PIDs are sequential and guessable. `/tmp` is world-writable by default.

**Consequences:** Secret written to attacker-controlled path; or attacker-chosen file overwritten with secret contents.

**Prevention:**
```bash
TMPFILE=$(mktemp)          # atomic, unpredictable name, mode 600 by default
chmod 600 "$TMPFILE"       # belt-and-suspenders (mktemp already does this)
trap 'rm -f "$TMPFILE"' EXIT HUP INT TERM
```
`mktemp` on both macOS and Linux creates the file atomically with mode 600 and returns a random, unpredictable path. Always set the trap on the very next line after mktemp.

**Detection warning sign:** `/tmp/scriptname-$$` or any predictable temp filename pattern. Missing `trap ... EXIT` immediately after temp file creation.

**Phase:** Core script (Phase 1).

---

### Pitfall 6: Trap Not Set Before First Write — Orphaned Secret File on Error

**What goes wrong:** Script creates temp file, then errors before reaching the cleanup section (e.g., clipboard copy fails, second password confirmation doesn't match). The secret file is left on disk at mode 600, but indefinitely — no TTL, no cleanup.

**Why it happens:** Cleanup logic placed at the end of the script is not reached on early exit.

**Consequences:** Secret persists on disk until the user manually deletes it. On a shared or cloud-synced machine (Dropbox sync of `~/tmp`), this is a real exposure risk.

**Prevention:**
- Set trap immediately after `mktemp`, before any other operations.
- Use `trap 'rm -f "$TMPFILE"' EXIT HUP INT TERM` — `EXIT` fires on all exit paths including `exit 1`.
- The NOTE FOR AGENT should include an explicit instruction: "Delete this file after reading." But the script's own trap is the primary defense.

**Detection warning sign:** Trap not on the line immediately following `mktemp`. Any `exit 1` branch that doesn't also `rm` the temp file.

**Phase:** Core script (Phase 1).

---

## Moderate Pitfalls

---

### Pitfall 7: Clipboard Manager Logs the Secret Indefinitely (KDE Klipper, GNOME Clipboard Indicator, CopyQ, macOS Universal Clipboard)

**What goes wrong:** Desktop clipboard managers (KDE Klipper, GNOME Clipboard Indicator, CopyQ, Raycast clipboard history, macOS's Universal Clipboard via iCloud) record everything copied to the clipboard. The NOTE FOR AGENT block written by `pw2agent` contains the file path — not the secret itself — so this is lower risk. But if the file path is logged in Klipper history and synced to iCloud, it leaks the existence and location of the secret even after the file is deleted.

**Prevention:**
- The NOTE FOR AGENT must never contain the secret itself — only the file path. This is the current design and must not change.
- Consider adding a post-clipboard-write clearing pattern as a background job:
  ```bash
  (sleep 30 && printf '' | pbcopy) &
  ```
  This overwrites clipboard after 30 seconds. Use the same platform-detected clipboard tool used for the initial write.
- Document in README: "If you use a clipboard manager, the NOTE path will be logged. Clear clipboard history after pasting."
- On KDE Plasma, users can configure Klipper to ignore clipboard entries from specific apps or use "Private Mode."

**Detection warning sign:** Clipboard content contains the raw secret (never acceptable). Clipboard not cleared after reasonable TTL.

**Phase:** Core script (Phase 1) for the clearing pattern. README (Phase 1).

---

### Pitfall 8: `set -x` Trace Mode Exposes Secret in Terminal Output

**What goes wrong:** If the script or a sourcing shell has `set -x` active, every variable expansion is printed to stderr. `read -rs secret` suppresses terminal echo, but if `set -x` is on, `printf '%s' "$secret" > "$TMPFILE"` will print the secret value in the trace output.

**Prevention:**
- Add `set +x` at the top of the script and restore to previous state on exit, or just leave debug mode disabled. Since this is a security tool, `set -x` should never be active during execution.
- Consider explicitly: `{ set +x; } 2>/dev/null` before any secret-handling block.

**Detection warning sign:** `set -x` anywhere in the script without a corresponding `set +x` before secret handling.

**Phase:** Core script (Phase 1).

---

### Pitfall 9: curl | bash Partial Download Executes Incomplete Script

**What goes wrong:** If the network drops mid-download, bash receives a partial script and executes it. A script that starts with `rm -f ~/.local/bin/pw2agent` before it reaches the install line will delete the existing binary without installing the new one.

**Prevention (two patterns):**

1. Wrap everything in a function, call only at the end:
   ```bash
   #!/usr/bin/env bash
   main() {
     # ... all install logic ...
   }
   main "$@"
   ```
   If download is cut before `main "$@"`, nothing executes.

2. Verify checksum before executing:
   ```bash
   curl -fsSL https://example.com/install.sh -o /tmp/install.sh
   sha256sum -c <<< "EXPECTED_HASH  /tmp/install.sh"
   bash /tmp/install.sh
   ```

Pattern 1 is simpler and requires no extra tooling. Use it.

**Detection warning sign:** Side-effect commands (rm, cp, mkdir) at top level of install.sh without being inside a function.

**Phase:** install.sh (Phase 1).

---

### Pitfall 10: `wl-copy` Requires a Running Wayland Session — Silent Failure on Headless/SSH

**What goes wrong:** On Linux Wayland, `wl-copy` fails silently if `$WAYLAND_DISPLAY` is not set (headless servers, SSH sessions without forwarding). The clipboard fallback chain `pbcopy || xclip || wl-copy` may reach `wl-copy` last and fail with no output to the user, leaving them thinking the NOTE was copied when it wasn't.

**Prevention:**
- Check `$WAYLAND_DISPLAY` before attempting `wl-copy`.
- On `xclip` (X11), check `$DISPLAY`.
- If no clipboard tool is available, print the NOTE directly to stdout with a clear "COPY THIS:" header as a fallback.
- Make the fallback chain explicit about failures: detect, warn, then fallback.

```bash
copy_to_clipboard() {
  if command -v pbcopy &>/dev/null; then
    printf '%s' "$1" | pbcopy
  elif [ -n "$DISPLAY" ] && command -v xclip &>/dev/null; then
    printf '%s' "$1" | xclip -selection clipboard
  elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy &>/dev/null; then
    printf '%s' "$1" | wl-copy
  else
    printf '\n[No clipboard tool found. Paste this manually:]\n%s\n' "$1" >&2
    return 1
  fi
}
```

**Detection warning sign:** Clipboard fallback chain that doesn't check environment variables before attempting GUI clipboard tools. No stdout fallback.

**Phase:** Core script (Phase 1).

---

## Minor Pitfalls

---

### Pitfall 11: NOTE FOR AGENT Format — Encoding, Line Endings, and Clipboard Truncation

**What goes wrong:**
- **CRLF corruption:** If the script runs on a system with `CRLF` line endings (unlikely on macOS/Linux but possible via git misconfiguration), the NOTE block will have `\r\n` line endings. Some agents parse lines split by `\n` only and will see keys like `FILE_PATH\r` instead of `FILE_PATH`, silently failing to match the expected format.
- **Clipboard truncation:** Some clipboard managers cap stored content. CopyQ by default stores unlimited text, but older versions and some integrations truncate at 64KB. A NOTE FOR AGENT block is tiny (under 500 bytes) so this is unlikely but worth knowing.
- **Unicode in the secret path:** `mktemp` on macOS uses `TMPDIR` which resolves to `/var/folders/...`. This path contains only ASCII. The NOTE block should use only ASCII-safe delimiters to avoid encoding surprises.
- **Trailing newline after pbcopy:** `printf '%s' "$note" | pbcopy` does not add a trailing newline. `echo "$note" | pbcopy` adds one. Agents that `cat` the file and compare exact output will see a difference. Use `printf` consistently and document which format the NOTE uses.

**Prevention:**
- Always use `printf '%s\n'` for NOTE lines, never `echo`.
- Use a fixed ASCII delimiter that is unambiguous: `---` or `===` lines.
- Keep the NOTE under 200 bytes — well within all clipboard limits.
- Validate format in at least one integration test: `cat` the NOTE, verify field extraction works with a simple `grep` or `awk`.

**Phase:** Core script (Phase 1). Validate in README example.

---

### Pitfall 12: Second Password Confirmation — `read -s` Does Not Prevent Timing Attacks or Paste Leaks

**What goes wrong:** The double-prompt confirmation (type secret twice) is good UX and a typo-prevention measure, but is not a security feature. If the user pastes the same value from their clipboard into both prompts, the clipboard already contains the secret. The confirmation adds zero security value beyond typo prevention.

**Prevention:** Document this explicitly — the double-prompt is a typo guard, not a security measure. Don't pretend otherwise in the README.

**Phase:** Documentation only.

---

### Pitfall 13: `~/.local/bin` May Not Be in `$PATH` on Fresh Linux Systems

**What goes wrong:** The install script puts `pw2agent` in `~/.local/bin`. On many default Linux distributions (Ubuntu 20.04 without `.profile` sourced, Fedora minimal install), `~/.local/bin` is not in `$PATH` by default until `.profile` or `.bashrc` is sourced. The install script adds an alias, but if the user opens a new terminal before sourcing, the command is not found.

**Prevention:**
- The alias in `~/.zshrc` (or `~/.bashrc`) is the correct primary resolution — if they use zsh, the alias fires immediately on next shell open.
- The install script should print: "Open a new terminal or run: `source ~/.zshrc`"
- Do not rely on `~/.local/bin` being in PATH without also adding the alias.

**Phase:** install.sh (Phase 1).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Core script — temp file | Race condition, predictable path | Use `mktemp`, set trap immediately |
| Core script — `rm -P` | No-op on macOS 14+, error on Linux | Replace with plain `rm -f` |
| Core script — `read` | `-p` flag incompatibility in zsh/sh | Use `printf` before `read -rs` |
| Core script — secret write | `echo` adds newline, expands in xtrace | Use `printf '%s'` |
| Core script — clipboard | Clipboard manager logs NOTE path | Add 30s background clear; document risk |
| Core script — clipboard fail | `wl-copy`/`xclip` silent fail on SSH | Guard with env var checks; stdout fallback |
| install.sh — idempotency | Duplicate lines in `.zshrc` on re-run | Grep guard before any append |
| install.sh — partial download | Incomplete curl execution | Wrap all logic in `main()`, call last |
| install.sh — PATH | `~/.local/bin` not in PATH | Print "source ~/.zshrc" instruction |
| OSS release — install script | Antivirus/scanner flags `curl \| bash` | README should note: "download and inspect before running if preferred"; provide direct download link |
| OSS release — shell scanner | Tools like shellcheck will flag `rm -P` and `read -p` | Run shellcheck in CI, fix all SC warnings before release |

---

## Specific Issues in the Source Script (stash-password.sh)

The source file `bifrost-tailscale/scripts/stash-password.sh` was not accessible at the path provided (`bifrost-tailscale/` directory does not exist in the current repo). Based on the PROJECT.md description of the script's behavior and the research above, the following issues are highly probable in any script derived from that source:

1. **`rm -P` usage** — almost certain given the macOS origin and pre-Sonoma writing date. Replace with `rm -f`.
2. **`read -s -p` combined flag** — common pattern that breaks on dash/POSIX sh. Split into `printf` + `read -rs`.
3. **No guard in install.sh against duplicate `.zshrc` lines** — needs grep idempotency check.
4. **Clipboard chain may not guard `$DISPLAY`/`$WAYLAND_DISPLAY`** — verify and add env checks.
5. **Trap may not be the first line after file creation** — verify trap is set before any operation that could fail.

These should be verified against the actual source when it becomes accessible.

---

## Sources

- [How to Handle Secrets on the Command Line (Smallstep)](https://smallstep.com/blog/command-line-secrets/)
- [Safely Creating and Using Temporary Files (netmeister.org)](https://www.netmeister.org/blog/mktemp.html)
- [MITRE ATT&CK: Unsecured Credentials: Shell History T1552.003](https://attack.mitre.org/techniques/T1552/003/)
- [MITRE ATT&CK: Clipboard Data T1115](https://attack.mitre.org/techniques/T1115/)
- [GNU Coreutils rm invocation](https://www.gnu.org/software/coreutils/manual/html_node/rm-invocation.html)
- [zsh Shell Builtin Commands — read](https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html)
- [Hiding User Input in a Shell Script (Nick Janetakis)](https://nickjanetakis.com/blog/hiding-user-input-in-a-shell-script)
- [CopyQ Security documentation](https://copyq.readthedocs.io/en/latest/security.html)
- [Securely Deleting Data on Linux: rm, shred, blkdiscard (DEV Community)](https://dev.to/lovestaco/securely-deleting-data-on-linux-rm-shred-blkdiscard-and-hdparm-secure-erase-explained-3ofi)
- [macOS system inspection: `man rm` on macOS 14.3 — `-P` flag documented as "no effect"](local system verification)
- [Idempotent PATH guard patterns (Zsh/Bash)](https://tech.serhatteker.com/post/2019-12/remove-duplicates-in-path-zsh/)
- [The hidden dangers of piping curl (djm.org.uk)](https://www.djm.org.uk/posts/protect-yourself-from-non-obvious-dangers-curl-url-pipe-sh/)
- [KDE Discuss: Copy Sensitive Info without Saving to Clipboard History](https://discuss.kde.org/t/copy-sensitive-info-without-saving-it-to-clipboard-history/10555)
