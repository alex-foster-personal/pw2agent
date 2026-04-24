# Architecture Patterns: pw2agent

**Domain:** OSS shell secret-handoff micro-utility
**Researched:** 2026-04-24
**Confidence:** HIGH

---

## Recommended Directory Structure

```
pw2agent/
├── pw2agent          # main script — no extension, executable, shebang #!/usr/bin/env bash
├── install.sh        # idempotent installer; copies to ~/.local/bin, adds PATH to shell rc
├── skill.md          # openskill SKILL.md — agent-readable slash command skill
├── demo.tape         # VHS tape for README GIF (deterministic, CI-regeneratable)
├── demo.gif          # committed output of demo.tape (for README display)
├── LICENSE           # MIT, no modification needed
├── README.md         # gif → one-liner install → what it does → usage → how it works
├── .github/
│   └── workflows/
│       └── ci.yml    # shellcheck + bats + vhs demo regen
└── tests/
    ├── pw2agent.bats  # bats-core integration tests
    └── helpers.bash   # clipboard mocks, temp dir setup
```

This is the complete repository. No `src/`, no `lib/`, no subdirectories for the main script. Single-file utilities (fzf, z.sh, git-secret) do not need source layout — it adds navigation cost with zero benefit.

---

## Script Structure: Single File, No Subcommands

**Decision: single-file `pw2agent`, no subcommands.**

pw2agent does one thing. The subcommand pattern (`pw2agent stash`, `pw2agent read`, `pw2agent clear`) is for tools with genuinely distinct operations that share state — git-credential-*, pass, gopass, op. pw2agent has no persistent state and no operations to dispatch between.

The subcommand comparison:

| Pattern | Used by | When appropriate |
|---------|---------|-----------------|
| Single-command script | fzf install, z.sh, starship install, mktemp | One action, no state, < 100 lines |
| Subcommand dispatch | git-extras, pass, op, gopass | Multiple distinct operations, shared state or config |
| Plugin-per-command | git-credential-* | Composable protocol, external callers dispatch |

git-credential-* are separate binaries (git-credential-osxkeychain, git-credential-gnome-libsecret) because git calls them via exec — that is a protocol requirement, not a structural preference. pw2agent has no such caller.

**Conclusion:** `pw2agent` runs, prompts, writes file, copies NOTE, exits. No dispatch logic. One script.

---

## File Naming: No Extension

**The script is named `pw2agent` — no `.sh` extension.**

This is the universal convention for executables that live in PATH:

- `git`, `curl`, `fzf`, `gh`, `starship`, `rg` — no extension
- `install.sh`, `setup.sh`, `build.sh` — `.sh` extension for scripts called by humans directly, not invoked as commands

The `.sh` extension signals "run me with bash explicitly" and implies the script is a utility, not a command. For a tool users type at the prompt, drop the extension.

`install.sh` retains `.sh` because it is never in PATH — it is invoked once via `curl | bash` and never run again.

---

## Install Script: PATH Modification, Not Alias

**Decision: `install.sh` adds `~/.local/bin` to PATH in the detected shell rc file. It does NOT add an alias.**

This is the correct answer and the reasoning matters:

### PATH in `~/.local/bin` is already the XDG convention

XDG Base Directory Specification (freedesktop.org) designates `~/.local/bin` as the user-local executable directory. Modern Linux distros (Ubuntu 20.04+, Fedora, Arch) include it in the default PATH. pipx, cargo, go install, and dozens of other tools install to `~/.local/bin` or add it to PATH by default. On this machine `~/.local/bin` is already in PATH (confirmed in `.zshrc` line 50).

### PATH beats alias for four concrete reasons

1. **Works in non-interactive shells.** Aliases are only expanded in interactive shells (`~/.zshrc`). If a user calls `pw2agent` from a script, a Makefile, a cron job, or another program's subprocess, PATH works. Aliases silently fail.

2. **No quoting or expansion hazards.** `alias pw2agent='~/.local/bin/pw2agent'` — the tilde is inside single quotes, which means it is a literal `~` and does NOT expand. The correct alias would be `alias pw2agent="$HOME/.local/bin/pw2agent"`, but this is an easy bug to ship and hard to debug. PATH has no equivalent footgun.

3. **Standard discoverable pattern.** `which pw2agent`, `command -v pw2agent`, and `type pw2agent` all work with PATH entries. Aliases are invisible to `which` in some shells. Debuggability matters.

4. **Idempotent deduplication is simpler.** Checking "is `~/.local/bin` already in PATH?" is one grep. Checking "is this alias already defined?" requires parsing shell rc syntax.

### nvm is the wrong reference for pw2agent

nvm uses a shell function (not an alias, not a binary) because it needs to modify the calling shell's environment (`cd`, `export NVM_DIR`). pw2agent is a binary that does its work and exits — it never needs to modify the parent shell's environment. nvm's pattern is irrelevant.

### fzf is the right reference

fzf appends `PATH="${PATH:+${PATH}:}$fzf_base/bin"` to `~/.fzf.bash` / `~/.fzf.zsh` and sources that from `~/.zshrc`. For pw2agent, there is no need for a separate sourced file — appending the export directly to `~/.zshrc` is simpler for a single-binary tool.

### Idempotent install.sh pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="pw2agent"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"

# --- install binary
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
chmod 755 "$INSTALL_DIR/$SCRIPT_NAME"

# --- detect shell rc file
_detect_rc() {
  case "${SHELL##*/}" in
    zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash) [[ -f "$HOME/.bashrc" ]] && echo "$HOME/.bashrc" || echo "$HOME/.bash_profile" ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

RC_FILE="$(_detect_rc)"
PATH_LINE="export PATH=\"\$HOME/.local/bin:\$PATH\""

# --- idempotent: add PATH only if ~/.local/bin not already present
if ! grep -qF '.local/bin' "$RC_FILE" 2>/dev/null; then
  printf '\n# pw2agent\n%s\n' "$PATH_LINE" >> "$RC_FILE"
  echo "Added ~/.local/bin to PATH in $RC_FILE"
else
  echo "~/.local/bin already in $RC_FILE — skipping PATH update"
fi

echo ""
echo "pw2agent installed to $INSTALL_DIR/$SCRIPT_NAME"
echo "Restart your shell or run: source $RC_FILE"
```

Key properties:
- `grep -qF '.local/bin'` — idempotent check before writing (no duplicate PATH entries)
- No `sudo` — `~/.local/bin` is user-owned
- Detects shell from `$SHELL` — handles zsh/bash/other
- `chmod 755` — executable by user, readable by others (standard for installed commands)
- Single clear success message — "Restart your shell or run: `source ~/.zshrc`"

The `curl | bash` variant works because the script uses `BASH_SOURCE` detection — when piped, this falls back gracefully. A download-then-run pattern (`curl -o install.sh && bash install.sh`) is cleaner and should be the README recommendation for users who want to inspect first.

---

## SKILL.md: openskill Format

**The skill file lives at `skill.md` in the repo root.** Users drop it into `~/.claude/skills/pw2agent/SKILL.md`.

The format is confirmed from local skill inspection:

```
~/.claude/skills/
├── my-first-skill/
│   └── SKILL.md        # YAML frontmatter + body
├── skill-creator/
│   ├── SKILL.md
│   ├── references/
│   └── scripts/
└── pw2agent/           # ← where users install it
    └── SKILL.md
```

Minimum viable structure for pw2agent: `SKILL.md` only — no `references/`, no `scripts/`. The skill's job is purely instructional: tell the agent how to handle a NOTE FOR AGENT block. No scripts to run, no references to load.

Required frontmatter fields (confirmed from local skills):
- `name` — must match directory name
- `description` — the primary trigger text; must include "Use when..."

No other frontmatter fields are required. `license` and `compatibility` are optional.

The skill body should be under 200 lines (ideally under 50). It encodes one workflow: see NOTE FOR AGENT → read file → use value → delete file → never echo.

---

## README Structure

For a micro-utility, this order is validated by high-engagement CLI tool READMEs (fzf, bat, starship, exa):

```markdown
[demo GIF — full width, shows the two-prompt flow and NOTE output]

# pw2agent

Hand a secret to an AI agent without pasting it in chat.

## Install

curl -fsSL https://raw.githubusercontent.com/agdfoster/pw2agent/main/install.sh | bash

## Usage

pw2agent

[GIF or screenshot of the NOTE FOR AGENT output]

## How it works

1. Prompts twice for the secret (silent input, no echo)
2. Writes to `~/.{label}_pw` with mode 600
3. Copies a NOTE FOR AGENT block to your clipboard
4. Paste the note into your agent's chat — the agent reads the file, uses the secret, deletes it

## Claude Code skill

[link to skill install instructions or one-liner]

## Security notes

- Secret is never in process args, env vars, or shell history
- File is mode 600 (owner-read-only)
- Agent instructions in the NOTE include an explicit delete step
- No network calls, no config files, no dependencies

## License

MIT
```

The GIF is the hero. It appears before the install command. Developers decide whether to install a CLI tool in the first 5 seconds of seeing the README — the GIF makes the case; text confirms the details.

---

## Component Boundaries

| Component | Responsibility | File |
|-----------|---------------|------|
| Secret intake | `read -s` double-entry, mismatch re-prompt, `trap` cleanup | `pw2agent` |
| File write | `mktemp`, `chmod 600`, write secret | `pw2agent` |
| NOTE generation | Format the handoff block with absolute path | `pw2agent` |
| Clipboard | pbcopy/xclip/wl-copy fallback chain | `pw2agent` |
| PATH setup | Copy binary, detect shell rc, append PATH if absent | `install.sh` |
| Agent skill | Trigger + instructions for handling NOTE FOR AGENT | `skill.md` |
| Demo | Reproducible GIF showing the flow | `demo.tape` |
| CI | ShellCheck + bats + VHS regen | `.github/workflows/ci.yml` |
| Tests | Integration tests with clipboard mocks | `tests/pw2agent.bats` |

All of `pw2agent`'s runtime logic lives in a single file. There are no shared functions between `pw2agent` and `install.sh` — they are completely independent scripts with different jobs.

---

## Internal Script Structure

The `pw2agent` script should be organized top-to-bottom in execution order with clear section dividers:

```
#!/usr/bin/env bash
set -euo pipefail

# ---- config (all user-tunable decisions at the top) ----
LABEL="${1:-secret}"
FILE="$HOME/.${LABEL}_pw"
NOTE_TEMPLATE="..."

# ---- helpers ----
_copy_to_clipboard() { ... }
_prompt_secret() { ... }

# ---- main ----
trap 'rm -f "$FILE"; stty echo 2>/dev/null || true' EXIT INT TERM

# double-entry loop
# write file
# generate NOTE
# copy to clipboard
# confirm
```

`LABEL` as a positional argument (`pw2agent api_key`) lets users name the file — this is the only user-facing configurability needed. All other decisions (file path prefix, NOTE format) live as named variables at the top of the script, not in a config file.

---

## Anti-Patterns to Avoid

### 1. Installing to `/usr/local/bin` (requires sudo)
**What goes wrong:** User is prompted for sudo password, feels like the tool is overreaching, or install fails in rootless environments (containers, CI).
**Instead:** `~/.local/bin` — user-owned, no privilege escalation.

### 2. Adding an alias instead of PATH
**What goes wrong:** Alias only works in interactive shells. Scripts, Makefiles, and subprocesses that call `pw2agent` silently fail with "command not found." Tilde in single-quoted alias string doesn't expand.
**Instead:** `export PATH="$HOME/.local/bin:$PATH"` in the rc file.

### 3. Hardcoding `~/.zshrc`
**What goes wrong:** Breaks for bash users and anyone with `$ZDOTDIR` set to a non-default location.
**Instead:** Detect from `$SHELL`, check for `$ZDOTDIR`, handle bash variants.

### 4. Sourcing the installer output immediately via `eval`
**What goes wrong:** Dangerous in a piped install — code executes before the user sees it.
**Instead:** Write to rc file, print `source ~/.zshrc`, let the user run it.

### 5. Subcommand dispatch for a single-action tool
**What goes wrong:** `pw2agent stash` feels like overhead for a tool that does one thing. Users have to remember the subcommand.
**Instead:** `pw2agent` with an optional label argument. No subcommands.

### 6. `.sh` extension on the main command
**What goes wrong:** `pw2agent.sh` looks like a utility script, not a command. Users feel like they're running an internal tool.
**Instead:** No extension. Executables in PATH don't have extensions.

---

## Scalability Considerations

This is not an applicable concern for pw2agent. The tool writes one file, exits. There is no server, no concurrency, no state. The only "scale" question is: does it work on macOS 12+ and Ubuntu 20.04+? Answer: yes, if tested with bats in CI.

The one valid operational concern is clipboard detection across platforms — handled by the existing fallback chain. Document clearly in the script which clipboard command is detected so users can debug.

---

## Sources

- XDG Base Directory Specification (freedesktop.org): `~/.local/bin` as user executable path (HIGH)
- nvm install.sh shell detection pattern: https://github.com/nvm-sh/nvm/blob/v0.40.1/install.sh (HIGH — reviewed directly)
- fzf install script PATH append pattern: https://github.com/junegunn/fzf/blob/master/install (HIGH — reviewed directly)
- Starship install PATH vs `/usr/local/bin` choice: https://starship.rs/install.sh (HIGH — reviewed directly)
- git-extras Makefile `BINPREFIX`: https://github.com/tj/git-extras/blob/main/Makefile (HIGH — reviewed directly)
- Local skill format confirmed from: `/Users/dev/.claude/skills/my-first-skill/SKILL.md` and `/Users/dev/.claude/skills/skill-creator/SKILL.md` (HIGH — primary source)
- User `.zshrc` line 50: `PATH="/Users/dev/.local/bin:$PATH"` — confirms `~/.local/bin` already in PATH, added by pipx (HIGH — primary source)
- alias tilde-in-single-quotes non-expansion: bash manual, confirmed behavior (HIGH)
- `command -v` vs `which` alias visibility: bash/zsh manual difference, well-documented (HIGH)
