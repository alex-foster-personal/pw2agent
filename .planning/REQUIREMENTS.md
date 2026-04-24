# pw2agent — v1 Requirements

## v1 Requirements

### Core Script (CORE)

- [ ] **CORE-01**: User can run `pw2agent [label]` and be prompted twice for a secret with no echo (`read -rs`, not `read -s -p`)
- [ ] **CORE-02**: Script writes secret to `~/.{label}_pw` (default label: `secret`) with mode 600, single line, no trailing newline
- [ ] **CORE-03**: Script exits with error if passwords don't match or if secret is empty; nothing written
- [ ] **CORE-04**: Script copies NOTE FOR AGENT block to clipboard via pbcopy/xclip/wl-copy fallback chain; prints NOTE to stdout if no clipboard tool available
- [ ] **CORE-05**: NOTE FOR AGENT contains: label, file path, base64 read command, rm delete instruction — plain English, no secret encoded
- [ ] **CORE-06**: Script uses `trap ... EXIT` immediately after writing file so temp state is cleaned on any error path
- [ ] **CORE-07**: Script uses `rm -f` (not `rm -P`) — `rm -P` is a documented no-op on macOS 14+
- [ ] **CORE-08**: Script supports `--help` / `-h` flag with short usage

### Install & Setup (INST)

- [ ] **INST-01**: `install.sh` copies `pw2agent` to `~/.local/bin/pw2agent` (chmod +x)
- [ ] **INST-02**: `install.sh` appends `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` with `grep -qF` idempotency guard (marker: `# pw2agent`)
- [ ] **INST-03**: `install.sh` wraps all logic in `main()`, called as last line (safe for curl|sh partial download)
- [ ] **INST-04**: `install.sh` prints "✅ Ready. Run: pw2agent" on success

### Agent Skill (SKIL)

- [ ] **SKIL-01**: `skill.md` uses agentskills.io SKILL.md format with `name: pw2agent` and `description:` frontmatter
- [ ] **SKIL-02**: Skill description is exactly: "use when you need to give an agent a pw without them seeing it"
- [ ] **SKIL-03**: Skill body contains minimal agent instructions: read path from NOTE, `base64 -d` the file, use value, `rm -f` the file when done

### Distribution (DIST)

- [ ] **DIST-01**: README opens with gif/screenshot demo (VHS .tape file committed; recorded output at top of README)
- [ ] **DIST-02**: README contains: one-liner curl install, basic usage, 2-sentence "what it does", skill install blurb
- [ ] **DIST-03**: MIT `LICENSE` file at repo root

---

## v2 Requirements (Deferred)

- **CI**: GitHub Actions — shellcheck lint + bats tests (no macOS runner needed; clipboard mocked)
- **Tests**: `tests/pw2agent.bats` covering: match fail, empty secret, permissions assert (mode 600), clipboard fallback
- **VHS demo tape**: `.tape` file for CI-regeneratable demo gif
- **Homebrew formula**: post-launch, once install.sh is validated
- **Clipboard auto-clear**: 30s background `printf '' | pbcopy` — useful but not core

---

## Out of Scope

- **Doppler/1Password integration** — graduation path, adds 40+ lines; defeats "single file" constraint
- **`--ttl` auto-delete timer** — nice-to-have; agent deletes on use is sufficient
- **`pw2agent-read` companion script** — plain-English NOTE is enough for any competent agent
- **Windows/PowerShell support** — macOS/Linux first; credential store patterns are completely different
- **GPG/age encryption** — wrong abstraction; secret lives on disk <60 seconds
- **Subcommands** (`pw2agent stash/read/clear`) — single operation tool; subcommands add dispatch complexity for no UX gain
- **Alias instead of PATH** — aliases don't work in non-interactive shells; PATH is the correct install pattern

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| CORE-01 → CORE-08 | Phase 1 | Pending |
| INST-01 → INST-04 | Phase 1 | Pending |
| SKIL-01 → SKIL-03 | Phase 2 | Pending |
| DIST-01 → DIST-03 | Phase 2 | Pending |
