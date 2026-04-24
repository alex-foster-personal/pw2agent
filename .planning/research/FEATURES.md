# Feature Landscape

**Domain:** OSS shell secret/credential handoff utility for AI coding agents
**Researched:** 2026-04-24
**Scope of research:** `pass`, `op` (1Password CLI), `gopass`, `secret-tool`/`keychain`, `summon`, `ks`, temp-file security patterns, agent handoff format conventions

---

## Table Stakes

Features users expect when they encounter a "shell secret utility." Absence is either annoying or trust-breaking.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Silent input (`read -s`) | Every password prompt since forever — visible typing is a blocker | Low | Bash built-in; `stty -echo` fallback for POSIX. Trailing `echo` for newline is required. |
| Double-entry confirmation | `passwd`-style UX; prevents silently storing a mistype | Low | Second prompt must also be silent |
| Mismatch re-prompt, not abort | Users expect retry, not failure + restart | Low | Any mismatch: clear, re-prompt from top |
| Exit confirmation on ^C | Trap `INT`/`TERM` to restore terminal echo — without this, `stty` is left broken | Low | `trap 'stty echo; exit' INT TERM EXIT` pattern; critical |
| Mode-600 file | All credential-passing conventions (op, pass, gopass, summon) gate on owner-only read | Low | `mktemp` gives 600 by default; explicit `chmod 600` is belt-and-suspenders |
| `trap EXIT` cleanup | Industry standard — `mktemp` + `trap 'rm -f "$file"' EXIT` is the non-negotiable pattern for temp secrets | Low | Covered in every "secure bash tempfile" reference |
| Cross-platform clipboard | macOS (`pbcopy`), Linux X11 (`xclip`), Wayland (`wl-copy`) — any missing one gets a GitHub issue immediately | Low | Fallback chain already exists in source script |
| Clear success/failure feedback | Users need to know the note is on clipboard, not guess | Low | Single confirmation line to stdout is enough |
| Works without dependencies | Any tool requiring GPG, age, or a vault loses the "just works" user | None | Single-file bash; zero dependencies is a hard constraint |

---

## Differentiators

What makes pw2agent distinct from every other "put a secret somewhere secure" utility.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **The NOTE FOR AGENT block** | Structured, copy-pasteable text any competent agent can follow without extra prompting — solves the "just paste it in chat" anti-pattern | Low | This is the entire raison d'etre. No other credential tool generates an agent-readable handoff note. |
| **Agent-specific instructions in the NOTE** | The note tells the agent to read the file, use the secret, delete the file, and never echo it — encoding the safe-use protocol | Low | Inline instructions remove the need for agents to infer policy; removes prompting overhead for the user |
| **File path in the NOTE** | Agent gets the exact path, no guessing or ls needed | Low | Absolute path from `mktemp` is the right call |
| **One-shot flow** | Run once, note lands on clipboard, done. No vault account, no GPG key, no config | None | The entire UX advantage over `op`, `pass`, `gopass` |
| **openskill `skill.md`** | Distributable Claude Code slash command — makes pw2agent a community-shareable skill, not just a local script | Low | Format is established; this is a packaging decision |
| **Intentionally ephemeral** | Not a store, not a manager — specifically a one-time handoff. Framing matters for user trust. | None | "Write a secret to a temp file, hand it off, delete it" is cognitively simpler than any vault story |

---

## Anti-Features

Things explicitly NOT to build. Each one is a complexity trap that would break the 80-line constraint or dilute the value prop.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| GPG/age encryption | Requires keygen setup, breaks "no dependencies" contract, adds 10x onboarding friction | File is ephemeral and mode-600; encryption is overkill for a temp handoff |
| TTL / auto-expiry timer | Background process needed, platform-specific, race conditions; adds ~30 lines | Convention in the NOTE: agent deletes on use. Convention is enough. |
| Secret storage / vault | Turns pw2agent into a competitor to pass/1Password; loses the one-shot identity | v2+ graduation path: reference `op` or `pass` as the store |
| Named secret labels / lookup | Requires a store, an index, a query interface — all of pass/gopass's complexity | Not a store; the file IS the handoff |
| `pw2agent-read` companion command | Agents already follow plain-English file-read instructions; a companion binary adds install surface | The NOTE already tells the agent exactly what to do |
| Homebrew/apt formula | Premature; curl-pipe install covers 100% of target users for v1 | Add post-launch once OSS community requests it |
| Windows support | Different clipboard, different shell, entirely different test matrix | macOS + Linux first; Windows is a separate project |
| Clipboard auto-clear timer | `pass` does 45s, gopass does 10s — but pw2agent's clipboard content is the NOTE, not the secret; clearing it breaks agent paste flow | The NOTE is safe to leave on clipboard. The file is the security boundary. |
| Interactive TUI / dialog | `whiptail`/`dialog`-style asterisk feedback is a UX nicety that adds a dependency | Blank input is universal and understood |
| Config file (`~/.pw2agentrc`) | Any config introduces "where does X live?" support burden | All configurable decisions (file path prefix, note format) stay in the script as clearly-named variables at the top |
| Doppler / vault integration | Adds auth flow, token management, network calls — entirely different complexity tier | v2 graduation path; document as "if you use Doppler, do X instead" in README |

---

## UX Patterns for Silent Read

Findings from ecosystem research — what the established tools do and why.

**Universal pattern** (`read -s`):
```bash
read -s -p "Enter secret: " SECRET
echo   # newline after hidden input
```
- `-s` is a bash extension (not POSIX). For POSIX shells, `stty -echo` / `stty echo` is the fallback.
- The bare `echo` after `read -s` is required — without it the next line of output runs on the same terminal line.
- Terminal echo restoration on interrupt is non-negotiable. `stty` left in `-echo` state after `^C` leaves the user with a broken terminal. Trap pattern: `trap 'stty echo; exit 1' INT TERM`.

**Confirmation pattern:**
- Two silent reads, compare. On mismatch: print error, re-prompt from the top (not abort). This matches `passwd`, `sudo`, and every `read -s` confirmation in the wild.
- Clear the variables before re-prompting to avoid stale comparisons.

**What NOT to do:**
- Asterisk-per-keystroke feedback via char-by-char loop — adds 15+ lines, introduces platform edge cases with backspace handling, provides marginal UX uplift for a two-prompt flow.
- `dialog`/`whiptail` — dependency, overkill for two prompts.
- Echoing the secret back to confirm it ("You entered: ****") — pointless and leaks length.

---

## NOTE / Handoff Format — What the Ecosystem Tells Us

No existing tool generates an agent-readable handoff note. This is an unclaimed niche. Research on adjacent patterns:

**What agents need in a handoff note (from AGENTS.md conventions, agent handoff SDKs):**
- Explicit action ("read this file")
- Exact location (absolute path)
- What to do with the value (use it for X)
- What NOT to do (don't echo, don't log, don't write to disk)
- Cleanup instruction (delete the file when done)

**What 1Password CLI does for scripts** (the closest analogue):
`op read op://vault/item/field` — the reference IS the instruction. pw2agent's NOTE is the human-language equivalent of a secret reference URI.

**What the note should NOT be:**
- JSON (agents don't need structure; markdown prose is fine and more paste-friendly)
- Base64-encoded (adds decode step, no security benefit for a temp file reference)
- A URL scheme (invents infrastructure that doesn't exist)

**Minimal effective format:**
```
NOTE FOR AGENT: A secret has been written to [path].
Read the file contents directly. Use the value for [intended use].
Do NOT echo, log, or output the secret. Delete the file when done.
```

The format is intentionally minimal: one path, three instructions. Agents (Claude Code, Cursor, Aider) follow plain-English file instructions without prompting — this is validated by Claude Code's behavior with `cat` references in chat context.

---

## Feature Dependencies

```
Silent read (read -s)
  → Double-entry confirmation
    → Mismatch re-prompt

mktemp (mode-600 file creation)
  → trap EXIT cleanup
  → NOTE generation (absolute path from mktemp)

NOTE generation
  → Clipboard write (pbcopy / xclip / wl-copy chain)
  → Stdout confirmation message
```

---

## MVP Recommendation

For the v1 80-line script, prioritize in this order:

1. **Silent double-entry with mismatch re-prompt** — core UX, zero tolerance for regression
2. **`mktemp` + `trap EXIT` cleanup** — security floor, non-negotiable
3. **NOTE FOR AGENT block with absolute path + three-instruction protocol** — the differentiator
4. **Cross-platform clipboard chain** — already implemented in source; keep it
5. **Stdout confirmation** — single line confirming note is on clipboard

Defer everything else. The skill.md and install.sh are packaging, not features — separate concerns.

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Table stakes (read -s, 600, trap) | HIGH | Multiple official docs, ArchWiki, Linux Journal, universal convention |
| Clipboard auto-clear convention | HIGH | pass docs (45s default), gopass docs (10s cliptimeout) — confirmed behavior |
| NOTE format — no prior art | HIGH | Negative finding confirmed: no tool generates agent-readable handoff notes. pw2agent is genuinely novel here. |
| Anti-features (GPG etc) | HIGH | 1Password, gopass, pass complexity documented; "no deps" constraint is explicit in PROJECT.md |
| Agent instruction-following behavior | MEDIUM | Based on AGENTS.md conventions and Claude Code observed behavior; not formally documented |

---

## Sources

- [Pass: The Standard Unix Password Manager](https://www.passwordstore.org/)
- [pass - ArchWiki](https://wiki.archlinux.org/title/Pass)
- [Use the Bash trap Statement to Clean Up Temporary Files - Linux Journal](https://www.linuxjournal.com/content/use-bash-trap-statement-cleanup-temporary-files)
- [1Password CLI: Load secrets into scripts](https://developer.1password.com/docs/cli/secrets-scripts/)
- [gopass features.md](https://github.com/gopasspw/gopass/blob/master/docs/features.md)
- [AI Agents Don't Understand Secrets. That's Your Problem.](https://dev.to/0x711/ai-agents-dont-understand-secrets-thats-your-problem-43n4)
- [Secrets Management for AI-Assisted Development (2026)](https://www.turbogeek.co.uk/secrets-management-ai-development-2026/)
- [29 million leaked secrets in 2025: Why AI agent credentials are out of control](https://www.helpnetsecurity.com/2026/04/14/gitguardian-ai-agents-credentials-leak/)
- [mktemp - Working with Temporary Files in Shell Scripts](https://www.putorius.net/mktemp-working-with-temporary-files.html)
- [AGENTS.md open format](https://agents.md/)
- [Hiding User Input in a Bash Terminal - Baeldung](https://www.baeldung.com/linux/bash-hide-user-input)
- [Simple secret sharing with gopass and summon - DEV Community](https://dev.to/camptocamp-ops/simple-secret-sharing-with-gopass-and-summon-40jk)
