# Spec Skeptic Review (revised — audited against feat/pw2agent/a)

## Verdict
HOLD — two literal spec violations, neither catastrophic but both trivially fixable. Do not ship until corrected.

## Requirement Coverage Matrix

| REQ-ID | Spec says | Actual state | Verdict |
|--------|-----------|--------------|---------|
| CORE-01 | Prompted twice, no echo, `read -rs` not `read -s -p` | `pw2agent:26-27` uses `read -rs PW1` / `read -rs PW2` — both use `-rs`, prompts are separate `printf`s | PASS |
| CORE-02 | Mode 600, single line, no trailing newline | `umask 077` before write (mode 600 ✓), `base64` on macOS does not wrap (single line ✓), BUT `base64` emits a trailing `\n` — live test shows file is 13 bytes for 8-char secret (12 base64 chars + `\n`) | **PARTIAL / FAIL on "no trailing newline"** |
| CORE-03 | Error if mismatch or empty; nothing written | `pw2agent:30-39` checks both; exits 1 before write block at line 43 | PASS |
| CORE-04 | pbcopy/xclip/wl-copy chain + stdout | `pw2agent:62-73` has the chain; line 59 always prints NOTE to stdout before attempting clipboard | PASS |
| CORE-05 | NOTE has label, path, base64 cmd, rm cmd — plain English, no secret | `pw2agent:53-57` contains all four, base64 is a read command not the encoded secret | PASS |
| CORE-06 | `trap ... EXIT` IMMEDIATELY after writing file | Write at line 43, trap at line 44 — literally the next line | PASS |
| CORE-07 | `rm -f` not `rm -P` | `grep 'rm -P'` returns CLEAN. `rm -f` used at line 44, 80 (implicit), and in NOTE | PASS |
| CORE-08 | `--help` / `-h` with short usage | `pw2agent:6-16` handles both, prints usage, exits 0. Verified by running | PASS |
| INST-01 | Copy to `~/.local/bin/pw2agent`, chmod +x | `install.sh:23-25` — mkdir, cp, chmod +x | PASS |
| INST-02 | PATH append with `grep -qF '# pw2agent'` idempotency | `install.sh:27-29` — exact pattern | PASS |
| INST-03 | ALL logic in `main()`, called as last line | `main "$@"` IS the last line ✓. BUT lines 13-19 (SCRIPT_SRC resolution + curl download + mktemp) are OUTSIDE `main()`. Spec rationale is "safe for curl|sh partial download" — the curl fallback logic outside main() defeats that safety property | **PARTIAL FAIL** |
| INST-04 | Exact string "✅ Ready. Run: pw2agent" | `install.sh:33` — exact match | PASS |
| SKIL-01 | agentskills.io frontmatter with name+description | `skill.md:1-5` — valid YAML frontmatter with `name: pw2agent` and `description:` | PASS |
| SKIL-02 | Description byte-exact: "use when you need to give an agent a pw without them seeing it" | `od -c` confirms byte-exact, no quotes, no period, ends with `\n` | PASS |
| SKIL-03 | Body: read path, `base64 -d`, use value, `rm -f` | `skill.md:9-14` — all four steps present | PASS |
| DIST-01 | README opens with gif; `demo.tape` + `demo.gif` present | `README.md:1` is `![pw2agent demo](demo.gif)`; both `demo.tape` (713B) and `demo.gif` (229KB) committed | PASS |
| DIST-02 | one-liner install, usage, **2-sentence** "what it does", skill blurb | Install ✓, usage ✓, skill blurb ✓. BUT "How it works" section is **6 sentences** (2 prose sentences + 4 terse declarative "No network calls. No config files. No dependencies. One 80-line bash script.") | **FAIL — 6 sentences, spec says 2** |
| DIST-03 | MIT LICENSE at root | `LICENSE` (no extension) exists, MIT text, copyright 2026 Alex Foster (matches current date 2026-04-24) | PASS |

**Summary: 15 PASS, 2 FAIL, 1 PARTIAL FAIL = 15 of 18 fully pass.**

## Findings

### [BLOCKER] DIST-02: "How it works" is 6 sentences, spec mandates 2
**Spec text:** "README contains: one-liner curl install, basic usage, 2-sentence 'what it does', skill install blurb"
**Actual** (`README.md:24-29`):
> pw2agent prompts twice for your secret (silent input, no echo), writes it to a mode-600 file, and copies a NOTE FOR AGENT block to your clipboard. Paste the note into your agent's chat — the agent reads the file, uses the secret, and deletes it.
>
> No network calls. No config files. No dependencies. One 80-line bash script.

That's 6 sentences — the first paragraph is 2 (matches spec), then a SECOND paragraph of 4 terse sentences was added. Classic scope creep.
**Gap:** +4 sentences beyond spec. Exactly the kind of "close enough" the team-lead warned me to look for.
**Fix:** Delete line 29 entirely. The 2-sentence first paragraph is correct. Or move "No network calls…" line into the Security section where it belongs.

### [BLOCKER] CORE-02: File has trailing newline
**Spec text:** "Script writes secret to `~/.{label}_pw` … with mode 600, single line, **no trailing newline**"
**Actual:** `pw2agent:43` is `printf '%s' "$PW1" | base64 > "$TARGET"`. macOS `base64` appends `\n` to its output. Verified by live run with 8-char secret `testpass` → file is 13 bytes (12 base64 chars `dGVzdHBhc3M=` + `\n`). `od -c` confirms the terminating `\n`.
**Gap:** Literal "no trailing newline" requirement violated on every invocation. The decode side (`base64 -d | tr -d '\n'`) works anyway because `tr -d '\n'` is defensive, so the bug is latent — but the spec line is clear and currently violated.
**Fix:** Change line 43 to `printf '%s' "$PW1" | base64 | tr -d '\n' > "$TARGET"` (or `| awk 'NF{printf "%s",$0}'`). Trivial one-pipe addition.

### [NIT] INST-03: curl-download logic lives outside `main()`
**Spec text:** "wraps all logic in `main()`, called as last line (safe for curl|sh partial download)"
**Actual** (`install.sh:13-19`):
```bash
if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/pw2agent" ]]; then
  SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"
else
  SCRIPT_SRC="$(mktemp)"
  curl -fsSL "$GITHUB_RAW/pw2agent" -o "$SCRIPT_SRC"
  _DOWNLOADED=true
fi
```
This is top-level logic — including a network call — running before `main()` is defined. A partial curl|bash download that truncates mid-download of the installer itself can still cause the mktemp + curl to fire (if bash has parsed past line 19) before `main()` is defined. The spec's stated rationale ("safe for curl|sh partial download") is the whole point of the `main()` wrapper pattern, so putting any logic outside it erodes that safety.
**Gap:** Partial rationalization — the *dispatch* (`main "$@"`) is at the end, but meaningful logic runs before it.
**Fix:** Move the SCRIPT_SRC resolution block inside `main()` before the `mkdir -p`. Downside: `_DOWNLOADED` and `SCRIPT_SRC` become locals (fine). Or accept the risk and amend REQUIREMENTS.md to acknowledge the exception.

## Rationalizations Found

1. **DIST-02 "2 sentences" → 6 sentences.** The planner appears to have counted only the first paragraph as "the 2 sentences" and treated the second paragraph as "bonus marketing". The spec says the README section should *be* 2 sentences, not *contain* 2 sentences among more.

2. **CORE-02 "no trailing newline" → accepted the base64 default.** I suspect the author tested that decode still works (because the `tr -d '\n'` on the decode side eats it) and moved on. But the spec says what the *file* looks like, not what survives round-trip. The verification in `.planning` (if it exists) likely called this PASS without an `od -c` check.

3. **INST-03 "all logic in main()" → "main dispatch is last line, which is the important bit".** The literal spec is violated; the *spirit* (top-level file is mostly declarative) is partly honored, but a network call outside main() is still logic.

4. The `# Claude Code skill` section in README (lines 31-41) is a legitimate "skill install blurb" per DIST-02, so that's not a gap.

5. Good news: SKIL-02 byte-exact match, CORE-07 clean of `rm -P`, CORE-06 trap literally on next line, INST-04 exact string — the discipline on these is actually strong. The gaps are narrow, not systemic.

## Questions for Other Reviewers

- @security-skeptic: Re-audit now against `feat/pw2agent/a`. Specifically look at: (a) `unset PW1 PW2` at line 45 happens AFTER `base64` reads from `$PW1` via the pipe — is there any pidns/argv exposure window? (b) `trap - EXIT INT TERM` disarm at line 80 runs unconditionally — what if the `_copy_to_clipboard` branch printf fails between the trap-disarm intent and process exit? (c) `umask 077` is set inline with no restore — does this leak to parent shell if sourced? (It's executed, not sourced, so no — but worth a note.)
- @portability-skeptic: The `base64` trailing-newline issue is macOS behavior; on some BSDs and Linux coreutils versions the default wraps at 76 cols by default, which would additionally violate "single line". Please verify across platforms.
- @shipping-skeptic: Confirm the 6-sentence "How it works" against your DIST-02 read. If you also flagged it, it's consensus; if not, please push back on my read.
- @team-lead: My recommendation is HOLD. Two 1-line fixes + a small `main()` restructure unblock ship. Not a BLOCK because the spec violations are cosmetic-to-minor and obvious to fix.

---

## Round 2 (audited against commit 8911a3d on feat/pw2agent/a)

### Round 2 Verdict
**SHIP** — all three round-1 findings resolved. Two new spec-literalism notes, neither blocking; both are cases where portability/safety won against literal spec text, and both are the right call.

### Round 1 Findings — resolution

| Finding | Round 1 state | Round 2 state | Verified by |
|---------|---------------|---------------|-------------|
| CORE-02 trailing newline | FAIL — 13 bytes for 8-char secret | **PASS** — 12 bytes for 8-char secret (`dGVzdHBhc3M=` exactly), `od -c` confirms no terminal `\n`, mode still 600 | live run `pw2agent:44`: `printf '%s' "$PW1" \| base64 \| tr -d '\n' > "$TARGET"` |
| DIST-02 sentence count | FAIL — 6 sentences | **PASS** — 2 sentences, exactly (`README.md:24-27`). Tight, readable, spec-compliant | visual + sentence-split verification |
| INST-03 logic outside main() | PARTIAL FAIL | **PASS** — SCRIPT_SRC resolution, mktemp, curl, download trap all inside `main()` at lines 18-41. `main "$@"` is last line (43). No side-effect commands run at top level. The `case` block at lines 11-15 is declarative assignment only, which matches the main() pattern's intent | `install.sh:17-43` |

### Round 2 spec matrix (18 requirements)

All 18 now PASS against the literal spec OR have a documented portability/safety deviation that is strictly better than the literal spec. No BLOCKERS remain.

### New issues introduced by the fixes

#### [POLISH] CORE-06: trap now BEFORE write, not "immediately after"
**Spec text (REQUIREMENTS.md:18):** "Script uses `trap ... EXIT` immediately **after** writing file so temp state is cleaned on any error path"
**Actual** (`pw2agent:43-44`):
```bash
trap 'rm -f "$TARGET"' EXIT INT TERM
printf '%s' "$PW1" | base64 | tr -d '\n' > "$TARGET"
```
**Gap:** Literal spec says "after writing", code now traps before. The arm-before-write is strictly safer (if the base64 pipeline fails mid-write, the partial file is cleaned up by the trap; under the old ordering that partial file would survive). Security-skeptic flagged the old ordering and this fix addresses it.
**Call:** This is the correct behavior change; the spec phrasing is wrong, not the code. Recommend amending REQUIREMENTS.md CORE-06 to "trap installed to cover the file-write block; must fire on any exit path after the first moment the file can exist". No code change needed. Not blocking.

#### [POLISH] INST-02: rc file is now `$SHELL`-dependent, spec says `~/.zshrc` specifically
**Spec text (REQUIREMENTS.md:29):** "`install.sh` appends `export PATH=…` to **`~/.zshrc`** with `grep -qF` idempotency guard"
**Actual** (`install.sh:11-15`):
```bash
case "${SHELL##*/}" in
  zsh)  RC_FILE="${ZDOTDIR:-$HOME}/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="$HOME/.profile" ;;
esac
```
**Gap:** Literal spec hardcodes `.zshrc`; code dispatches by current shell. Portability-skeptic's blocker — bash-default Linux installs would have been broken. Idempotency guard (`grep -qF '# pw2agent'`) preserved at line 33. Marker format unchanged.
**Call:** Portability fix is correct. Recommend amending REQUIREMENTS.md INST-02 to "picks user's shell rc file: `~/.zshrc` for zsh, `~/.bashrc` for bash, `~/.profile` otherwise, with `grep -qF '# pw2agent'` idempotency guard". No code change needed. Not blocking.

### Fresh audit pass — any other issues?

Read every file top-to-bottom. No new bugs introduced by the fixes. Specific items I verified:

- **`tr -d '\n'` placement (pw2agent:44)**: correct — strips newline from base64 output, not from `$PW1` (which would be wrong if the secret ended with `\n`). A secret containing embedded newlines remains intact inside the base64 payload.
- **Trap disarm timing (pw2agent:80)**: still only disarmed after successful clipboard branch. If `_copy_to_clipboard` succeeds but printf on line 76 fails (stdout closed), trap would still fire and delete a legitimately-stashed file. Edge case, inherited from round 1, not introduced by round 2. Not blocking.
- **`download` local variable (install.sh:19)**: correctly declared `local`, only read inside main(). No scope leakage.
- **Download trap coverage (install.sh:24)**: trap ARMED on the download path, DISARMED on line 37 after cp. If cp fails between lines 30-31 before disarm, trap correctly cleans up mktemp. Good.
- **`trap - EXIT INT TERM` inside conditional (install.sh:37)**: `[[ "$downloaded" == true ]] && { rm -f "$SCRIPT_SRC"; trap - EXIT INT TERM; }` — if downloaded=false, no trap was ever set, so no disarm needed. Correct.
- **Skill body step 4 change**: `rm -f ~/.secret_pw && unset PWB64` is a tightening of SKIL-03, not a violation. PWB64 hygiene is a genuine improvement.
- **README base64-is-not-encryption note (README.md:47)**: responds to security-skeptic's concern about base64-as-obfuscation misleading readers. Accurate, well-phrased. Good addition.
- **LICENSE, demo.tape, demo.gif**: unchanged from round 1 (all PASS).
- **Skill description byte-exact**: re-ran `od -c`, still byte-exact match to spec text.
- **`rm -P` absent**: `grep -n 'rm -P' pw2agent install.sh` returns CLEAN.
- **Help flag**: `./pw2agent --help` exits 0, prints usage starting with `Usage: pw2agent [label]`.

### Recommended updates to REQUIREMENTS.md (non-blocking)

For future traceability — the authoring agent reasonably made two portability/safety deviations that improve on the literal spec. The spec should be updated to reflect actual (correct) behavior:

1. CORE-06: change "immediately after writing file" → "installed before the write block, covering the write itself and any subsequent error path"
2. INST-02: change `~/.zshrc` → "user's shell rc file (`~/.zshrc` / `~/.bashrc` / `~/.profile`)"

This is doc hygiene, not a ship-blocker. The code is correct.

### Final verdict
**SHIP.** 18 of 18 requirements satisfied; two cases where code correctly improves on literal spec. No new defects introduced. Ready to publish as OSS.
