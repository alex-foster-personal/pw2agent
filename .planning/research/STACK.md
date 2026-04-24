# Technology Stack: pw2agent

**Project:** pw2agent — OSS shell secret-handoff utility
**Researched:** 2026-04-24
**Confidence:** HIGH (verified against official sources and live repos)

---

## Shell Language

**Use: bash with `#!/usr/bin/env bash` shebang.**

`read -s` (silent input, no echo) is a bash extension — not POSIX sh. Since the entire security model of pw2agent depends on it, POSIX portability is off the table. Committing to bash is correct and honest; the alternative (stty -echo workaround for POSIX sh) adds 10 lines of fragile code for no real gain on any platform the tool targets (macOS + Linux, both ship bash).

Pattern used by comparable tools:
- **fzf** (`install`): `#!/usr/bin/env bash`
- **gh-commit** (`install.sh`): `#!/bin/bash`
- Both the broader Charm ecosystem and GitHub CLI scripts use bash explicitly, not sh.

`/usr/bin/env bash` is preferred over `/bin/bash` — bash lives at `/usr/local/bin/bash` on macOS (Homebrew) and Nix systems. `env` lookup handles this.

**Defensive bash flags for the script itself:**

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `set -e` — exit on error (no silent failure)
- `set -u` — error on unset variable (catches typos in var names)
- `set -o pipefail` — pipe failures propagate (critical for clipboard chains)

**Confidence:** HIGH — verified against fzf source, GNU bash manual, and confirmed `read -s` is bash-only.

---

## Install Distribution: `curl | bash` Pattern

**Use: `curl -fsSL | bash` with explicit security flags.**

This is the de-facto standard for developer tools. Every major CLI tool (Homebrew, Rust/rustup, nvm, fzf, Charm tools) uses this pattern. The security tradeoffs are known and accepted by the target audience (developers who already curl-pipe constantly).

**Recommended one-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/agdfoster/pw2agent/main/install.sh | bash
```

**curl flags:**

| Flag | Purpose |
|------|---------|
| `-f` | Fail silently on HTTP errors (no partial script execution) |
| `-s` | Silent mode (no progress bar noise) |
| `-S` | Show errors even in silent mode |
| `-L` | Follow redirects (GitHub raw URLs redirect) |

**`install.sh` must:**
1. Check for existing install and offer upgrade path
2. Install to `~/.local/bin/pw2agent` (no sudo needed, user-writable)
3. Detect shell (`$SHELL`) and append alias to `~/.zshrc` or `~/.bashrc`
4. `chmod 755` the script after install
5. Print a single actionable success line: `pw2agent installed. Restart your shell or run: source ~/.zshrc`

**Security flags for the README:**
Document these explicitly — developers appreciate honesty:

- The script executes with user privileges (not root)
- No sudo required — install target is `~/.local/bin/`
- Source is pinned to `main` branch on a verified GitHub repo
- Users who want to verify can: `curl -fsSL <url> | less` before piping

**What NOT to do:**
- No `sudo` in the installer — this is a user-space tool
- No `pip install` or package manager wrapping — shell script, zero dependencies
- Do not offer a "safe preview" flag in the install URL — servers can detect piping and serve different content (documented attack vector). Trust comes from the GitHub URL + open source, not from a flag.

**Confidence:** HIGH — pattern verified against multiple real installers; security considerations sourced from multiple independent analyses.

---

## Skill Format: Agent Skills / openskill (SKILL.md)

**Use: agentskills.io open standard SKILL.md format.**

This is now an official open standard (published December 2025), supported by Claude Code, OpenAI Codex, and GitHub Copilot agent mode. It is the correct format for `skill.md` distribution.

**Directory structure:**

```
pw2agent/
└── skill.md        # standalone skill — no subdirectory needed for a simple utility
```

For distribution as part of the repo, a single `skill.md` in the project root is sufficient. Users drop it into `~/.claude/skills/pw2agent/SKILL.md` or equivalent.

**Minimal SKILL.md frontmatter format:**

```yaml
---
name: pw2agent
description: >
  Use when you need to receive a secret (password, API key, token) from the user
  without it appearing in chat history. Instructs user to run pw2agent in their
  terminal, then read the secret from the file path in the NOTE FOR AGENT block.
  Use whenever the user says "use pw2agent" or hands you a NOTE FOR AGENT block.
license: MIT
compatibility: Requires pw2agent installed at ~/.local/bin/pw2agent (macOS/Linux)
---
```

**Constraints to observe:**
- `name`: lowercase, hyphens only, must match directory name (`pw2agent`)
- `description`: max 1024 chars, should include "Use when..." triggering language
- Body: under 500 lines, instructions for the agent on how to read the file and delete it

**Key body content the skill needs:**
1. When you see a NOTE FOR AGENT block: read `~/.{label}_pw`, use secret, then `rm` the file
2. Never print or log the secret value
3. Confirm deletion after use

**Confidence:** HIGH — specification verified directly at agentskills.io and cross-referenced with local superpowers skill implementations.

---

## Terminal Demo: README GIF

**Use: VHS (charmbracelet/vhs) for the README demo.**

VHS wins for pw2agent for three reasons specific to this project:

1. **Declarative `.tape` files commit to git** — the demo is reproducible and version-controlled, not a binary blob
2. **CI-regeneratable** — the GIF can be regenerated automatically in GitHub Actions if the script changes
3. **No recording session needed** — critical for a security tool where you don't want to accidentally capture a real secret in a recording

**Comparison:**

| Tool | Format | CI-friendly | Reproducible | Dependencies |
|------|--------|------------|--------------|--------------|
| VHS | `.tape` script | Yes (GitHub Action) | Yes | ttyd, ffmpeg |
| asciinema | JSON capture | No (requires session) | No | asciinema player |
| terminalizer | YAML + HTML | Partial | Partial | Node.js |

**Basic pw2agent demo tape structure:**

```tape
Output demo.gif
Set FontSize 16
Set Width 800
Set Height 400
Set Theme "Dracula"

Type "pw2agent"
Sleep 500ms
Enter
Sleep 1s
# VHS can't type into silent prompts, so show the clipboard output
Type "# secret written to ~/.api_pw"
Sleep 500ms
Enter
Sleep 2s
```

Note: VHS cannot interact with `read -s` prompts interactively — the demo will need to mock the interaction sequence or show the output state. This is a known limitation; show the NOTE FOR AGENT clipboard output as the key frame.

**Dependencies for local use:** `ttyd` and `ffmpeg` (installable via Homebrew: `brew install vhs`).

**Confidence:** HIGH — VHS GitHub repo confirmed active, used by Charm's own tools and widely adopted in the CLI tool community.

---

## Testing: ShellCheck + bats-core

**Use: ShellCheck for static analysis, bats-core for integration tests.**

This is the canonical 2025 pair for shell script testing. ShellCheck is pre-installed on GitHub Ubuntu runners.

**ShellCheck:**
- Catches undefined variables, quoting bugs, portability issues
- Run with `--shell=bash` since pw2agent explicitly requires bash
- Integrate with editor (VSCode extension: timonwong.shellcheck)
- In CI: `shellcheck pw2agent install.sh`

**bats-core (`bats`):**
- TAP-compliant test framework, the standard for bash script integration testing
- Install with bats-support and bats-assert for readable assertions
- Write tests that mock the clipboard commands (pbcopy/xclip/wl-copy) and verify file creation

**Minimal test structure:**

```
tests/
  pw2agent.bats     # main tests
  helpers.bash      # mock setup (clipboard mocks, temp dir helpers)
```

**Example test pattern:**

```bash
@test "writes mode-600 file to ~/.label_pw" {
  export MOCK_CLIPBOARD=true
  echo -e "s3cr3t\ns3cr3t" | pw2agent --label label
  run stat -c "%a" "$HOME/.label_pw"
  assert_output "600"
}
```

**What to test:**
- File permissions are exactly 600
- Secret does not appear in process list (`ps aux` check)
- Clipboard receives expected NOTE FOR AGENT format
- Mismatch input prompts for re-entry (or exits cleanly)
- Clipboard fallback chain works (mock pbcopy absent, test xclip path)

**Confidence:** HIGH — bats-core is actively maintained at bats-core/bats-core; ShellCheck is the definitive static analyzer.

---

## License: MIT

**Use: MIT, with minimal file header + `LICENSE` file.**

There is no official required header format for MIT. The SPDX standard recommends the license live in a `LICENSE` file at the project root. The conventional pattern for shell scripts:

```bash
# pw2agent — hand a secret to an AI agent without pasting in chat
# Copyright (c) 2026 Alex Foster
# MIT License — see LICENSE file
```

**`LICENSE` file:** Standard MIT text from choosealicense.com/licenses/mit/ with year and name filled in. No modifications needed.

This is lighter than Apache-2.0 (which requires a full boilerplate header per file). For a single-file script, one comment line pointing to LICENSE is sufficient and conventional.

**Confidence:** HIGH — verified against choosealicense.com (OSI canonical source) and SPDX specification.

---

## GitHub Actions CI

**Use: Two jobs — `lint` (ShellCheck only) for PRs, `test` (bats-core) for pushes to main.**

For a sub-80-line shell utility, this is the right scope. ShellCheck is instant; bats tests catch regressions on the clipboard fallback chain.

**Recommended workflow (`.github/workflows/ci.yml`):**

```yaml
name: CI
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        run: shellcheck pw2agent install.sh

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install bats
        run: |
          git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats
          /tmp/bats/install.sh /usr/local
      - name: Run tests
        run: bats tests/

  demo:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: charmbracelet/vhs-action@v2
        with:
          path: demo.tape
      - uses: actions/upload-artifact@v4
        with:
          name: demo-gif
          path: demo.gif
```

**Matrix testing for clipboard paths:** Run bats tests with `MOCK_CLIPBOARD=pbcopy`, `MOCK_CLIPBOARD=xclip`, `MOCK_CLIPBOARD=wl-copy` to exercise all three clipboard paths.

**Do not:** Add macOS runner for CI (expensive GitHub Actions minutes). ShellCheck + bash-specific bats tests on Ubuntu cover the logic; clipboard fallback is mocked.

**Confidence:** HIGH — ShellCheck pre-installed on GitHub runners is documented fact; VHS GitHub Action (charmbracelet/vhs-action) confirmed available on GitHub Marketplace.

---

## Summary Table

| Dimension | Decision | Rationale |
|-----------|----------|-----------|
| Shell | `bash` + `#!/usr/bin/env bash` | `read -s` is bash-only; fzf, gh-cli use same pattern |
| Defensive flags | `set -euo pipefail` | Industry standard; catches silent failures |
| Install | `curl -fsSL \| bash` to `~/.local/bin/` | No sudo; developer-standard pattern |
| Skill format | agentskills.io SKILL.md | Official open standard, Claude Code + Codex + Copilot |
| Demo | VHS `.tape` file | Reproducible, CI-regeneratable, no live session |
| Testing | ShellCheck + bats-core | Canonical 2025 pair; ShellCheck pre-installed on GH runners |
| License | MIT, minimal header | Simplest correct approach; single comment + LICENSE file |
| CI | ShellCheck lint + bats tests + VHS demo regen | Right scope for a sub-80-line tool |

---

## Sources

- fzf install script shebang: https://github.com/junegunn/fzf/blob/master/install (verified HIGH)
- agentskills.io specification: https://agentskills.io/specification (verified HIGH)
- VHS README: https://github.com/charmbracelet/vhs/blob/main/README.md (verified HIGH)
- MIT License canonical text: https://choosealicense.com/licenses/mit/ (verified HIGH)
- ShellCheck GitHub Actions: https://github.com/marketplace/actions/shellcheck (verified HIGH)
- bats-core: https://github.com/bats-core/bats-core (active repo, verified HIGH)
- curl|bash security analysis: https://www.kicksecure.com/wiki/Dev/curl_bash_pipe (MEDIUM — community analysis)
- POSIX sh vs bash portability: https://www.gnu.org/software/bash/manual/html_node/Major-Differences-From-The-Bourne-Shell.html (verified HIGH)
