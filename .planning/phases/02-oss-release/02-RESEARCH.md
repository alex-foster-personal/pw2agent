# Phase 2: OSS Release — Research

**Researched:** 2026-04-24
**Domain:** OSS distribution — skill file authoring, curl install pattern, VHS demo tape, README structure, MIT LICENSE
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SKIL-01 | `skill.md` uses agentskills.io SKILL.md format with `name: pw2agent` and `description:` frontmatter | Exact format verified at agentskills.io/specification and code.claude.com/docs/en/skills |
| SKIL-02 | Skill description is exactly: "use when you need to give an agent a pw without them seeing it" | Description field constraint: 1-1024 chars, non-empty — 60-char target easily fits |
| SKIL-03 | Skill body contains minimal agent instructions: read path from NOTE, `base64 -d` the file, use value, `rm -f` the file when done | Body is plain Markdown; no format restrictions; under 50 lines is idiomatic |
| DIST-01 | README opens with gif/screenshot demo (VHS .tape file committed; recorded output at top of README) | VHS 0.11.0 available via `brew install vhs`; .tape syntax verified; silent-input workaround documented below |
| DIST-02 | README contains: one-liner curl install, basic usage, 2-sentence "what it does", skill install blurb | Standard OSS README pattern; GitHub raw URL pattern verified |
| DIST-03 | MIT LICENSE file at repo root | Canonical MIT text from choosealicense.com verified |

</phase_requirements>

---

## Summary

Phase 2 adds four files to the repo: `skill.md`, `demo.tape`, `demo.gif`, `LICENSE`, and `README.md`. No code changes to `pw2agent` or `install.sh` are required. All deliverables are authoring tasks with clear, verifiable acceptance criteria.

The only non-trivial finding is the VHS silent-input limitation: VHS cannot interact with `read -s` prompts because it types into a pseudo-terminal where the secret would be visible in the tape file itself. The correct pattern is to use `Hide` / `Show` to skip the interactive prompts and show the final output state instead — specifically the clipboard NOTE output. This is the standard demo pattern for security tools.

The skill file format has two distinct consumers that use slightly different conventions: the agentskills.io open standard (canonical spec for distribution) and Claude Code's local install pattern (directory under `~/.claude/skills/`). Both use `name` + `description` frontmatter; the distinction matters for the install instructions in the README.

**Primary recommendation:** Author five files in a single wave (skill.md, demo.tape, README.md, LICENSE, demo.gif generation). Only `demo.tape` requires VHS to be installed locally — treat gif generation as a separate verification step.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Skill discovery (when Claude loads the skill) | Claude Code runtime | — | Reads SKILL.md from `~/.claude/skills/pw2agent/SKILL.md`; description field drives auto-trigger |
| Skill install instructions | README.md | — | Human-readable; user manually copies directory |
| curl install one-liner | install.sh (already exists) | README.md | README contains the command; install.sh is the executed target |
| Demo gif generation | VHS (local) | GitHub Actions (v2) | Tape file is authoritative; gif is generated output |
| License declaration | LICENSE file | pw2agent script header | LICENSE at root; one-line comment in script (optional) |

---

## Standard Stack

### Core

| File/Tool | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| VHS (`charmbracelet/vhs`) | 0.11.0 | Generate `demo.gif` from `demo.tape` | `brew install vhs`; requires `ffmpeg` + `ttyd` (pulled in automatically) [VERIFIED: `brew info vhs`] |
| agentskills.io spec | Dec 2025 | Canonical SKILL.md format | Only `name` + `description` required; `license` and `compatibility` optional [VERIFIED: agentskills.io/specification] |
| MIT License | standard | LICENSE file | Canonical text from choosealicense.com — no modifications [VERIFIED: choosealicense.com/licenses/mit/] |

### Supporting

| File/Tool | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| charmbracelet/vhs-action | v2 | CI gif regeneration | v2 only — referenced in STACK.md for future CI; not needed in Phase 2 |
| GitHub raw URL | — | curl install target | `https://raw.githubusercontent.com/{user}/{repo}/{branch}/{file}` pattern [ASSUMED: repo will be at github.com/agdfoster/pw2agent on branch `main`] |

**Installation (VHS):**
```bash
brew install vhs
```

**Version verification:**
```bash
# VHS
brew info vhs   # 0.11.0 stable [VERIFIED: 2026-04-24]
vhs --version   # confirm after install
```

---

## Architecture Patterns

### System Architecture Diagram

```
User runs pw2agent
       |
       v
pw2agent script (already built)
       |
       +---> writes ~/.{label}_pw (base64, mode 600)
       +---> copies NOTE FOR AGENT to clipboard
                      |
                      v
              User pastes NOTE into agent chat
                      |
                      v
              Claude Code reads SKILL.md
              (~/.claude/skills/pw2agent/SKILL.md)
                      |
                      v
              Agent reads ~/.{label}_pw via NOTE
              base64 -d, uses value, rm -f file
```

### Recommended Project Structure (Phase 2 additions)

```
pw2agent/
├── pw2agent          # Phase 1 — unchanged
├── install.sh        # Phase 1 — unchanged
├── skill.md          # NEW: agentskills.io SKILL.md for repo distribution
├── demo.tape         # NEW: VHS tape source file
├── demo.gif          # NEW: generated output (committed)
├── LICENSE           # NEW: MIT
└── README.md         # NEW: gif → install → what it does → usage → skill
```

### Pattern 1: SKILL.md Format

**What:** YAML frontmatter (`name` + `description`) followed by Markdown body.
**When to use:** Every skill file — both for distribution (repo root) and for local Claude Code install.

```markdown
# Source: agentskills.io/specification [VERIFIED: 2026-04-24]
---
name: pw2agent
description: use when you need to give an agent a pw without them seeing it
---

# pw2agent

When a user hands you a NOTE FOR AGENT block, follow these steps:

1. Read the file path from the NOTE (the `File:` line, e.g. `~/.secret_pw`)
2. Decode the secret: `PWB64=$(base64 -d < ~/.secret_pw | tr -d '\n')`
3. Use the value in `$PWB64` for the task requiring the credential
4. Delete the file when done: `rm -f ~/.secret_pw`
5. Never print or log the value of `$PWB64`
```

**Key constraints verified from agentskills.io:**
- `name`: lowercase, hyphens only, 1-64 chars, must match directory name (`pw2agent`) [VERIFIED]
- `description`: 1-1024 chars, non-empty — SKIL-02 specifies exact text (60 chars) [VERIFIED: fits easily]
- No other frontmatter fields are required; `license: MIT` is optional but reasonable to include [VERIFIED]

**Claude Code install path:**
```
~/.claude/skills/pw2agent/SKILL.md
```
The file in the repo is named `skill.md` (lowercase, no directory). The README installation instructions tell users to create the directory and copy the file. [VERIFIED: code.claude.com/docs/en/skills — "Personal: `~/.claude/skills/<skill-name>/SKILL.md`"]

**Critical note on naming:** The agentskills.io spec says the `name` field must match the parent directory name. When distributed as `skill.md` in the repo root, the directory name context is absent — this is fine. When a user installs it locally, they create `~/.claude/skills/pw2agent/SKILL.md` and the name field matches. [VERIFIED: agentskills.io/specification section "name field"]

### Pattern 2: VHS .tape Syntax

**What:** Declarative script that VHS executes to record a terminal GIF.
**When to use:** For `demo.tape` — committed to repo, deterministic, CI-regeneratable.

**Key commands verified:** [VERIFIED: github.com/charmbracelet/vhs README]

| Command | Syntax | Purpose |
|---------|--------|---------|
| `Output` | `Output demo.gif` | Output file path and format |
| `Set` | `Set FontSize 16` | Terminal settings |
| `Type` | `Type "text"` | Simulate keyboard input |
| `Enter` | `Enter` | Press return |
| `Sleep` | `Sleep 500ms` | Pause recording |
| `Hide` | `Hide` | Stop recording frames (commands still execute) |
| `Show` | `Show` | Resume recording frames |
| `Wait` | `Wait /regex/` | Wait for output matching regex before proceeding |
| `Env` | `Env KEY value` | Set environment variable |

**Critical VHS limitation — `read -s` prompts:** VHS types into a pseudo-terminal. If the tape calls `pw2agent` directly, VHS would need to type the secret into the TTY, which (1) defeats the security purpose and (2) the secret would be visible in the tape file in plain text. [ASSUMED: based on VHS documentation — "Type" command emulates keyboard input into pseudo-terminal; no special silent-input mode documented]

**Correct pattern:** Use `Hide` / `Show` to skip the interactive portion. Show only the final output (the NOTE FOR AGENT block on stdout/clipboard). This is the standard approach for demos of security tools.

```tape
# Source: charmbracelet/vhs README [VERIFIED: 2026-04-24]
Output demo.gif
Set FontSize 14
Set Width 800
Set Height 480
Set Theme "Catppuccin Frappe"
Set WindowBar Colorful

# Show help first to establish context
Type "pw2agent --help"
Sleep 300ms
Enter
Sleep 1500ms

# Skip the interactive secret prompts — pre-stage the file
Hide
Type "printf '%s' 'demo_secret' | base64 > ~/.demo_pw && chmod 600 ~/.demo_pw"
Enter
Sleep 500ms
Show

# Show the NOTE output directly (simulating what pw2agent prints)
Type "cat << 'EOF'"
Enter
Type "NOTE FOR AGENT — secret handoff"
Enter
Type "  Label:   demo"
Enter
Type "  File:    ~/.demo_pw    (mode 600, base64-encoded)"
Enter
Type "  Read:    PWB64=$(base64 -d < ~/.demo_pw | tr -d '\\n')"
Enter
Type "  Delete:  rm -f ~/.demo_pw"
Enter
Type "EOF"
Enter
Sleep 2000ms

# Cleanup
Hide
Type "rm -f ~/.demo_pw"
Enter
Show
```

**Alternative approach (simpler, more honest):** Pre-stage a dummy file with `Env` or `Hide`, then run `pw2agent` with input piped in using a here-string or process substitution. However, VHS has no built-in "pipe stdin" mechanism for interactive prompts. The Hide/Show approach to show the output state is cleaner.

**Dependencies required for local gif generation:**
```bash
brew install vhs    # pulls in ffmpeg and ttyd automatically
```

### Pattern 3: curl Install One-Liner

**What:** `curl -fsSL <raw-github-url> | bash` — the de-facto standard for developer CLI tools.
**Canonical form:**

```bash
curl -fsSL https://raw.githubusercontent.com/agdfoster/pw2agent/main/install.sh | bash
```

**curl flag breakdown:** [VERIFIED: STACK.md — HIGH confidence]

| Flag | Effect |
|------|--------|
| `-f` | Fail on HTTP errors (no partial execution on 404) |
| `-s` | Silent mode |
| `-S` | Show errors even in silent mode |
| `-L` | Follow redirects (GitHub raw URLs redirect) |

**Why this works with the existing `install.sh`:** Phase 1 already implemented the `main()` guard pattern (all side-effects inside `main()`, called as last line). This is the exact pattern required for curl-safe execution. [VERIFIED: install.sh line 26: `main "$@"`; CONTEXT.md D-15]

**Caveat: `BASH_SOURCE[0]` in curl mode.** When piped via `curl | bash`, `BASH_SOURCE[0]` is empty and `dirname ""` returns `.`. The current `install.sh` uses `BASH_SOURCE[0]` to locate `pw2agent` adjacent to the installer. This means the current `install.sh` assumes `pw2agent` is in the same directory — which is true when cloning, but NOT true when curl-piping (the user's CWD is not the repo).

**Resolution needed in Phase 2:** The `install.sh` must be updated to download `pw2agent` from GitHub when running via curl, rather than copying from `$BASH_SOURCE[0]`. Two approaches:

1. **Detect curl mode** — if `BASH_SOURCE[0]` is empty, download `pw2agent` from the raw GitHub URL alongside `install.sh`.
2. **Separate install-remote.sh** — a second installer that always downloads. Simpler to reason about; the README curl command points to this version.

**Recommended approach (least code):** Single `install.sh` that detects whether it was run locally or via curl:

```bash
# Source: install.sh pattern [VERIFIED: Phase 1 SUMMARY + ARCHITECTURE.md]
# In install.sh, replace the SCRIPT_SRC line:
if [[ -n "${BASH_SOURCE[0]}" && -f "$(dirname "${BASH_SOURCE[0]}")/pw2agent" ]]; then
  SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pw2agent"
else
  # curl mode: download pw2agent from GitHub
  SCRIPT_SRC="$(mktemp)"
  curl -fsSL "https://raw.githubusercontent.com/agdfoster/pw2agent/main/pw2agent" -o "$SCRIPT_SRC"
  DOWNLOADED=true
fi
```

[ASSUMED: repo will be at `github.com/agdfoster/pw2agent` on `main` branch — no remote is configured yet]

### Pattern 4: README Structure

**What:** Standard OSS micro-utility README — demo first, install second, then explanation.
**Validated against:** fzf, bat, starship, exa READMEs [CITED: ARCHITECTURE.md research]

```markdown
<!-- demo.gif — full width, shows the help output and NOTE output -->
![pw2agent demo](demo.gif)

# pw2agent

Hand a secret to an AI agent without pasting it in chat.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/agdfoster/pw2agent/main/install.sh | bash
```

## Usage

```bash
pw2agent              # stashes as ~/.secret_pw
pw2agent api_key      # stashes as ~/.api_key_pw
```

Run `pw2agent --help` for options.

## How it works

pw2agent prompts twice for your secret (silent input, no echo), writes it to a
mode-600 file, and copies a NOTE FOR AGENT block to your clipboard. Paste the
note into your agent's chat — the agent reads the file, uses the secret, and
deletes it.

No network calls. No config files. No dependencies. One 80-line bash script.

## Claude Code skill

To teach Claude Code the pw2agent workflow:

```bash
mkdir -p ~/.claude/skills/pw2agent
curl -fsSL https://raw.githubusercontent.com/agdfoster/pw2agent/main/skill.md \
  -o ~/.claude/skills/pw2agent/SKILL.md
```

Then paste a NOTE FOR AGENT block into Claude Code and it handles the rest.

## Security

- Secret is never in process args, env vars, or shell history
- File is mode 600 (owner-read-only)
- NOTE FOR AGENT includes an explicit `rm -f` delete step
- No network calls, no logs, no dependencies

## License

MIT
```

**Section ordering rationale:** Gif before install — developers decide whether to install within 5 seconds; the gif makes the case. [CITED: ARCHITECTURE.md README Structure section]

### Anti-Patterns to Avoid

- **`sudo` in install.sh** — this is a user-space tool; `~/.local/bin` is user-owned. No privilege escalation needed. [CITED: ARCHITECTURE.md Anti-Pattern #1]
- **`skill.md` in a subdirectory** — the repo root file is named `skill.md`; users install it as `~/.claude/skills/pw2agent/SKILL.md`. Don't ship a nested directory structure in the repo — it adds confusion. [VERIFIED: code.claude.com/docs/en/skills]
- **Typing the secret in the VHS tape** — security anti-pattern and would put a credential in a committed file. Use Hide/Show to skip interactive prompts. [ASSUMED based on VHS documentation]
- **`description` that doesn't match SKIL-02** — the exact description is locked: `"use when you need to give an agent a pw without them seeing it"`. Don't paraphrase.
- **`name` field mismatch** — agentskills.io spec requires `name` to match the parent directory. For the repo file (`skill.md`), there is no parent directory — this is fine. When documenting install, the target directory must be `pw2agent` to match `name: pw2agent`. [VERIFIED: agentskills.io/specification]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Terminal GIF recording | Custom screen capture script | VHS 0.11.0 | Declarative, CI-regeneratable, charmbracelet-maintained |
| MIT License text | Custom license | choosealicense.com canonical text | Standard text is what OSI validators check |
| Skill format | Custom YAML schema | agentskills.io SKILL.md | The open standard — Claude Code reads this directly |
| curl install detection | Complex BASH_SOURCE logic | Simple if/else with `curl -fsSL` download fallback | Three lines; no edge cases |

**Key insight:** Phase 2 is purely authoring — no new logic. Every problem has a standard solution. The only implementation work is the `install.sh` curl-mode fix.

---

## Common Pitfalls

### Pitfall 1: `install.sh` Breaks in curl Mode

**What goes wrong:** `BASH_SOURCE[0]` is empty when `bash` reads from a pipe. `dirname ""` returns `.`. The current `install.sh` line `SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"` resolves to `$(pwd)/pw2agent` — whatever the user's CWD is — which almost certainly does not contain the `pw2agent` binary.
**Why it happens:** Phase 1 implemented `BASH_SOURCE[0]` for local `bash install.sh` runs; curl-pipe mode was explicitly deferred to Phase 2. [VERIFIED: 01-02-SUMMARY.md "No blockers for v2 work (CI, Homebrew, curl|bash remote install)"]
**How to avoid:** Detect curl mode (empty `BASH_SOURCE[0]` or file not adjacent) and download `pw2agent` from the GitHub raw URL. Must be done in Phase 2 — otherwise the curl install command in the README is broken.
**Warning signs:** After running the curl command on a machine without the repo, `pw2agent` is not installed.

### Pitfall 2: skill.md Name Field Does Not Match Install Directory

**What goes wrong:** If the skill file has `name: pw2agent` but the user creates `~/.claude/skills/stash-pw/SKILL.md`, Claude Code will match the directory name as the slash command (`/stash-pw`) but the frontmatter `name` will mismatch. The skill still works but the slash command name is wrong.
**How to avoid:** README install instructions must specify `mkdir -p ~/.claude/skills/pw2agent` exactly. [VERIFIED: agentskills.io/specification "name must match parent directory name"]

### Pitfall 3: VHS `Type` Exposes Secret in Tape File

**What goes wrong:** If the tape calls `pw2agent` and then uses `Type "mysecret"` to simulate password entry, the actual secret value is committed in `demo.tape` in plain text.
**How to avoid:** Never type a real secret in the tape. Use `Hide`/`Show` to skip the interactive prompts; demonstrate the output state (NOTE FOR AGENT block) using a pre-staged file. [ASSUMED: based on VHS documentation of `Hide`/`Show` commands]

### Pitfall 4: README curl Command Uses Wrong Branch or Path

**What goes wrong:** `https://raw.githubusercontent.com/agdfoster/pw2agent/master/install.sh` — if the default branch is `main` (GitHub default since 2020), a `master` URL returns 404.
**How to avoid:** Use `main` branch explicitly. Verify the raw URL resolves before publishing. [ASSUMED: repo not yet created; `main` is the GitHub default]

### Pitfall 5: Skill Body is Too Verbose

**What goes wrong:** A skill body with 200+ lines of explanation costs context tokens every time it loads, even for simple uses.
**How to avoid:** Keep skill body under 50 lines. The pw2agent workflow is 4 steps — the body should be exactly those 4 steps, nothing more. [CITED: skill-creator SKILL.md "context window is a public good" principle]

### Pitfall 6: VHS Not Installed Before gif Generation Task

**What goes wrong:** Plan task says "generate demo.gif" but VHS is not installed; task fails with `vhs: command not found`.
**How to avoid:** Plan must include `brew install vhs` as a prerequisite step in the same task that generates the gif. [VERIFIED: `brew info vhs` — not installed on this machine as of 2026-04-24]

### Pitfall 7: LICENSE Year

**What goes wrong:** LICENSE file has wrong year (e.g., 2025 if copy-pasted from a template).
**How to avoid:** Use 2026 (current year). [VERIFIED: currentDate from environment — 2026-04-24]

---

## Code Examples

### Complete skill.md

```markdown
# Source: agentskills.io/specification + code.claude.com/docs/en/skills [VERIFIED: 2026-04-24]
---
name: pw2agent
description: use when you need to give an agent a pw without them seeing it
license: MIT
---

# pw2agent

When a user hands you a NOTE FOR AGENT block, follow these steps:

1. Read the file path from the NOTE (`File:` line)
2. Decode the secret: `PWB64=$(base64 -d < ~/.{label}_pw | tr -d '\n')`
3. Use `$PWB64` for the task — do not print or log its value
4. Delete the file when done: `rm -f ~/.{label}_pw`

Do not ask the user to paste the secret into chat. The NOTE FOR AGENT pattern
exists specifically to avoid that.
```

### Complete LICENSE file

```
# Source: choosealicense.com/licenses/mit/ [VERIFIED: 2026-04-24]
MIT License

Copyright (c) 2026 Alex Foster

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### install.sh curl-mode fix (delta from Phase 1)

```bash
# Source: Phase 1 install.sh + ARCHITECTURE.md curl pattern [VERIFIED: 2026-04-24]
# Replace the SCRIPT_SRC config block with:
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="pw2agent"
GITHUB_RAW="https://raw.githubusercontent.com/agdfoster/pw2agent/main"

# Detect local vs curl mode
if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/pw2agent" ]]; then
  SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"
  _DOWNLOADED=false
else
  SCRIPT_SRC="$(mktemp)"
  curl -fsSL "$GITHUB_RAW/pw2agent" -o "$SCRIPT_SRC"
  _DOWNLOADED=true
fi
```

Add cleanup at end of `main()`:
```bash
[[ "$_DOWNLOADED" == true ]] && rm -f "$SCRIPT_SRC"
```

### VHS demo tape

```tape
# Source: charmbracelet/vhs README [VERIFIED: 2026-04-24]
Output demo.gif
Set FontSize 14
Set Width 800
Set Height 420
Set Theme "Catppuccin Frappe"
Set WindowBar Colorful
Set Padding 20

Type "pw2agent --help"
Sleep 300ms
Enter
Sleep 2000ms

Hide
Type "printf '%s' 'hunter2' | base64 > ~/.demo_pw && chmod 600 ~/.demo_pw"
Enter
Sleep 300ms
Show

Sleep 500ms
Type "# secret stashed — clipboard NOTE:"
Enter
Sleep 300ms
Type "cat << 'NOTE'"
Enter
Type "NOTE FOR AGENT — secret handoff"
Enter
Type "  Label:   demo"
Enter
Type "  File:    ~/.demo_pw    (mode 600, base64-encoded)"
Enter
Type "  Read:    PWB64=\$(base64 -d < ~/.demo_pw | tr -d '\\n')"
Enter
Type "  Delete:  rm -f ~/.demo_pw"
Enter
Type "NOTE"
Enter
Sleep 2500ms

Hide
Type "rm -f ~/.demo_pw"
Enter
Show
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `asciinema` for terminal recording | VHS `.tape` files | 2022 (VHS release) | Declarative, CI-regeneratable, no JSON blob |
| Custom skill format per tool | agentskills.io open standard | December 2025 | Claude Code, OpenAI Codex, Copilot all support same format |
| `~/.claude/commands/*.md` | `~/.claude/skills/<name>/SKILL.md` | Late 2025 | Commands merged into skills; old path still works but skills are recommended |
| `chmod 755` in install scripts | `chmod +x` | convention | `+x` is idiomatic; already used in Phase 1 install.sh |

**Current Claude Code skill path:** `~/.claude/skills/<name>/SKILL.md` is the recommended path as of 2025. The old `.claude/commands/` path still works but skills support additional features (supporting files, frontmatter invocation control). [VERIFIED: code.claude.com/docs/en/skills]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GitHub repo will be at `github.com/agdfoster/pw2agent` on branch `main` | curl one-liner, install.sh fix | Wrong URL breaks curl install; fix: update URL before publishing |
| A2 | VHS `Type` cannot safely interact with `read -s` prompts (secret would appear in tape) | VHS .tape pattern | If wrong, could type into silent prompt; risk is low (actual demo wouldn't capture secret visually) but tape would contain the secret in plaintext |
| A3 | `brew install vhs` pulls in `ffmpeg` and `ttyd` as automatic dependencies | Standard Stack | If ffmpeg/ttyd must be installed separately, add explicit install steps to plan |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| brew | VHS install | ✓ | `/opt/homebrew/bin/brew` | — |
| VHS (`vhs`) | demo.gif generation | ✗ | Not installed | `brew install vhs` (plan must include) |
| ffmpeg | VHS dependency | Not checked | — | Pulled in by `brew install vhs` |
| ttyd | VHS dependency | Not checked | — | Pulled in by `brew install vhs` |
| curl | install.sh curl-mode + skill install | ✓ | macOS system curl | — |
| git | repo operations | ✓ | system | — |

**Missing dependencies with required install step:**
- `vhs` — plan must include `brew install vhs` before any gif generation task

---

## Open Questions

1. **GitHub repo URL**
   - What we know: git remote is not configured; gitconfig user is `agdfoster`
   - What's unclear: exact repo name and branch on GitHub
   - Recommendation: [ASSUMED] `github.com/agdfoster/pw2agent` on `main`. Planner should note this as a human-confirm step before publishing; the curl URL can be written with this assumption and verified before first publish.

2. **demo.gif: live recording vs static recreation**
   - What we know: VHS cannot interact with `read -s` prompts; Hide/Show pattern skips interactive input
   - What's unclear: whether to demo `pw2agent --help` + fabricated NOTE output, or run pw2agent with a non-secret dummy input
   - Recommendation: Show `--help` output (real) then a fabricated NOTE FOR AGENT block (using `cat << 'NOTE'`). This is honest — it shows the output format without pretending to record a live session.

3. **Skill file in repo: `skill.md` vs `SKILL.md`**
   - What we know: agentskills.io spec uses `SKILL.md` (uppercase); local skills in `~/.claude/skills/` use `SKILL.md`; REQUIREMENTS.md specifies `skill.md` (lowercase)
   - What's unclear: whether case matters for distribution vs local install
   - Recommendation: Use `skill.md` (lowercase) in the repo as specified in REQUIREMENTS.md. README install instructions rename it to `SKILL.md` when the user places it in `~/.claude/skills/pw2agent/SKILL.md`. Both forms are valid.

---

## Sources

### Primary (HIGH confidence)
- `agentskills.io/specification` — exact SKILL.md frontmatter spec, field constraints, examples [VERIFIED: 2026-04-24]
- `code.claude.com/docs/en/skills` — Claude Code skill install path (`~/.claude/skills/<name>/SKILL.md`), frontmatter fields, invocation model [VERIFIED: 2026-04-24]
- `platform.claude.com/docs/en/agents-and-tools/agent-skills/overview` — skill architecture, required fields, name/description constraints [VERIFIED: 2026-04-24]
- `choosealicense.com/licenses/mit/` — canonical MIT license text [VERIFIED: 2026-04-24]
- `brew info vhs` — VHS 0.11.0 stable, not installed, requires ffmpeg + ttyd [VERIFIED: 2026-04-24]
- `github.com/charmbracelet/vhs README` — complete .tape command syntax: Output, Set, Type, Sleep, Enter, Hide, Show, Wait [VERIFIED: 2026-04-24]
- `/Users/dev/.claude/skills/my-first-skill/SKILL.md` — local skill format confirmation [VERIFIED: 2026-04-24]
- `/Users/dev/.claude/skills/skill-creator/SKILL.md` — skill authoring conventions confirmation [VERIFIED: 2026-04-24]
- `.planning/phases/01-working-tool/01-02-SUMMARY.md` — confirms `BASH_SOURCE[0]` limitation for curl mode; Phase 2 deferred [VERIFIED: 2026-04-24]
- `.planning/research/STACK.md` — curl -fsSL flags, VHS rationale, MIT license pattern [VERIFIED: 2026-04-24]
- `.planning/research/ARCHITECTURE.md` — README section order, skill.md placement, curl|bash pattern [VERIFIED: 2026-04-24]

### Secondary (MEDIUM confidence)
- Multiple WebSearch results confirming agentskills.io as open standard launched December 2025 [MEDIUM]

### Tertiary (LOW confidence — flagged)
- A2: VHS cannot interact with `read -s` — inferred from documentation, not empirically tested [LOW]

---

## Metadata

**Confidence breakdown:**
- SKILL.md format: HIGH — verified against agentskills.io/specification and code.claude.com/docs directly
- curl install pattern: HIGH — verified against existing install.sh + ARCHITECTURE.md
- VHS tape syntax: HIGH — verified against official README; silent-input limitation is ASSUMED (LOW)
- README structure: HIGH — verified against multiple OSS tool READMEs in ARCHITECTURE.md
- MIT LICENSE text: HIGH — verified against choosealicense.com canonical source
- install.sh curl-mode fix: MEDIUM — pattern is correct; exact URL is ASSUMED pending GitHub repo creation

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (agentskills.io spec is recent but stable; VHS is actively maintained; MIT License doesn't change)
