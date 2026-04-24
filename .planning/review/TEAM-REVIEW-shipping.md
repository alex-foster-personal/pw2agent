# Shipping Skeptic Review

> Note on Round 1: my original review landed in the **Unicode right-quote** twin
> directory (`Alex’s…`) rather than here (`Alex's…`), because team-lead's first
> briefing routed me through the wrong apostrophe. Content of the original BLOCK
> review is summarized in the Round 2 section below so reviewers can see what
> was already flagged and what is now resolved.

## Round 1 (summary)

Reviewed against the wrong path — BLOCKed on an empty tree. Findings were
necessarily abstract. Re-done properly in Round 2 below.

## Round 2

### Verdict
**SHIP** — with one non-blocking caveat the team already knows about (repo not
yet pushed to GitHub, so the curl one-liner cannot work on a stranger's machine
*yet*). Everything that can be audited locally is in good shape.

### Verification of Round-1 concerns

| Round-1 finding | Status in 8911a3d | Evidence |
|---|---|---|
| Empty repo — nothing to ship | RESOLVED | `ls -la` shows LICENSE, README.md, demo.gif, demo.tape, install.sh, pw2agent, skill.md, .planning/; `git log` shows 5 commits on `feat/pw2agent/a`, tip 8911a3d |
| `install.sh` would silently no-op on 404 | PARTIALLY RESOLVED | `set -euo pipefail` + `curl -fsSL` now fails loudly on 404. The *GitHub URL itself* is still 404 (see new finding DIST-01) |
| Demo fidelity (Hide/Show mocks command) | DOCUMENTED / INTENTIONAL | `demo.tape` does use `Hide` to fake the write; the gif shows help output + a typed-out NOTE-FOR-AGENT template rather than a live pw2agent run. Not ideal but not dishonest — no fake `✅ Stashed` or fake byte count is shown. Acceptable for v0.1.0 |
| 60-second comprehension unverifiable | IMPROVED | README is 52 lines, install one-liner on line 10, "How it works" is exactly 2 sentences on lines 24-27. Objectively passes the inspectable proxies I proposed. Still not empirically tested on strangers, but that is hard to block on |

### New findings (introduced or still open)

### [BLOCKER-external] `install.sh` curl URL is still a 404
**Evidence:**
```
$ curl -sSL -o /dev/null -w "%{http_code}\n" https://github.com/agdfoster/pw2agent
404
$ curl -fsSL -o /dev/null -w "%{http_code}\n" \
    https://raw.githubusercontent.com/agdfoster/pw2agent/main/install.sh
404
```
**Impact:** The README's headline install command still fails for any stranger
today. With `set -euo pipefail` and `curl -fsSL`, the failure is at least loud:
`curl` exits 22, `install.sh` exits, and nothing is written to `$INSTALL_DIR`.
So it's a "loud 404" rather than a "silent broken binary" — graduation from
round-1 BLOCKER to round-2 release-gate.

**Fix:** Push the repo public before publicizing the README. Consider pinning
the curl path to a tag (`…/releases/download/v0.1.0/pw2agent`) so future
`main` rewrites don't silently change what users install.

---

### [NIT] `install.sh` does not verify anything it downloaded
**Evidence:** `install.sh:25` does `curl -fsSL "$GITHUB_RAW/pw2agent" -o "$SCRIPT_SRC"`
with no checksum, no signature, no size sanity check, and then `cp`s straight
to `$HOME/.local/bin/pw2agent` and `chmod +x`.

**Impact:** A compromised `raw.githubusercontent.com` response, a cache
poisoning, or an accidental force-push of a broken `main` would all be
executed as-is. This is the standard curl-pipe-bash trust model and common to
100s of OSS tools, so I'm not calling it a blocker — just noting that once
there's a v0.1.0 tag, pinning to a released binary with a published sha256
raises the floor meaningfully for ~20 extra lines.

**Fix (optional for v0.1.0, recommended for v1):** publish a `SHA256SUMS` file
per release; have `install.sh` verify after download.

---

### [NIT] Install "open a new terminal" instruction is easy to miss
**Evidence:** `install.sh:40` prints:
```
✅ Ready. Run: pw2agent
   (open a new terminal or: source /tmp/.../.zshrc)
```
but the *very next line* of a first-time user's session will usually be
`pw2agent` typed immediately — and PATH will not be updated in the current
shell. This is a classic "I followed the install and `command not found`"
moment.

**Impact:** Predictable friction for the stranger we're optimizing for. Not
broken, just slightly annoying.

**Fix:** Either (a) print a 2-line note highlighting the PATH reload more
boldly, or (b) add `hash -r 2>/dev/null || true` and tell the user to run
`exec $SHELL -l` if they want to try immediately. Or document this in the
README's Install section.

---

### [NIT] Trailing lines in pw2agent script
**Evidence:** `pw2agent:80` is the last `trap - EXIT INT TERM`, and `file`
showed the last line without a trailing newline. Harmless — many shells and
editors tolerate this — but ruff-ish shops prefer final newlines.

**Impact:** None functional. Purely cosmetic.

**Fix:** Add a terminating newline to `pw2agent`.

---

### [NIT] Demo gif shows a *typed* NOTE, not a real one
**Evidence:** `demo.tape:24-37` literally types out each line of the NOTE via
`Type "..."` `Enter` pairs. A viewer who knows VHS can tell this is synthesized.

**Impact:** Marginal honesty concern — the NOTE a user would actually see
happens to be character-for-character identical to what is typed, so this is
functionally accurate, just not "live". Since no fabricated success banner
(`✅ Stashed`, byte count, mode) is shown, I'm not calling it misleading.

**Fix (post-v0.1.0 polish):** once VHS supports passing to `read -rs`
(or via `expect`-style scripting), re-record with a real `pw2agent` invocation.

---

### Verified by live execution

```
$ export HOME=/tmp/pw2test  SHELL=/bin/zsh
$ bash install.sh
✅ Ready. Run: pw2agent
$ cat /tmp/pw2test/.zshrc
export PATH="$HOME/.local/bin:$PATH" # pw2agent
$ bash install.sh   # re-run: idempotent, no duplicate PATH line
$ printf 'hunter2\nhunter2\n' | ~/.local/bin/pw2agent testlbl
✅ Stashed at: /tmp/pw2test/.testlbl_pw (      12 bytes, mode 600)
…
📋 NOTE copied to clipboard. Paste into your agent.
$ xxd ~/.testlbl_pw
00000000: 6148 5675 6447 5679 4d67 3d3d            aHVudGVyMg==
$ base64 -d < ~/.testlbl_pw; echo
hunter2
```

Confirms CORE-02 fix (no trailing newline: 12 bytes for 8-byte secret = exactly
`base64("hunter2")` with no `\n`), the zsh-path selection (DIST-03), idempotent
PATH-line install (grep-guard), mode-600 enforcement, and round-trip decode.

---

## Questions for Other Reviewers

- **@security-skeptic:** `pw2agent:44` now reads `printf '%s' "$PW1" | base64 | tr -d '\n' > "$TARGET"`. The `trap rm -f "$TARGET"` on line 43 fires *before* the write — good. One edge: if the base64 pipeline fails partway (disk full mid-write), the trap cleans up, but `set -e` + pipefail should abort. Do you see any race where `$TARGET` exists with partial content *and* the trap has already fired (unset via `trap -` on line 80) before a later failure? I don't, but it's worth your eye.

- **@portability-skeptic:** `install.sh:11-15` switches on `${SHELL##*/}`. Verify the common cases (`zsh`, `bash`) and the Linux default-to-`.profile` fallback behave as expected. Also: `stat -f '%Lp'` vs `stat -c '%a'` in `pw2agent:49` is the BSD/GNU fallback you'd want — confirm on your end.

- **@spec-skeptic:** Phase-2 criterion #4 was "60-second comprehension." Objectively, the README is 52 lines, install is one curl line, "How it works" is 2 sentences. Are those the right proxies, or does the spec demand an actual user study before we claim this criterion is met?
