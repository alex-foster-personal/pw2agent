# Roadmap: pw2agent

## Overview

From a working source script to a published OSS tool. Phase 1 delivers a correct, installable utility that a developer can use today. Phase 2 turns it into a releasable open-source project with README, skill file, and license.

## Phases

- [ ] **Phase 1: Working Tool** - Script audited, installable, and usable on macOS + Linux
- [ ] **Phase 2: OSS Release** - README with demo, skill file, LICENSE — everything needed to publish

## Phase Details

### Phase 1: Working Tool
**Goal**: A developer can install pw2agent in one command and hand a secret to an AI agent without it appearing in chat.
**Depends on**: Nothing (first phase)
**Requirements**: CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06, CORE-07, CORE-08, INST-01, INST-02, INST-03, INST-04
**Success Criteria** (what must be TRUE):
  1. User runs `pw2agent [label]`, is prompted twice silently, and a mode-600 file is written with no echo leak on Ctrl-C
  2. A "NOTE FOR AGENT" block (with path, base64 read command, rm instruction) is on the clipboard or printed to stdout on headless systems
  3. Running `bash install.sh` twice leaves exactly one PATH line in `~/.zshrc` and prints "Ready. Run: pw2agent"
  4. Script passes ShellCheck with zero warnings on macOS and Linux
**Plans**: TBD

### Phase 2: OSS Release
**Goal**: The repo is ready to publish — a stranger can find it on GitHub, install it in one curl command, and wire it into Claude Code via the skill file.
**Depends on**: Phase 1
**Requirements**: SKIL-01, SKIL-02, SKIL-03, DIST-01, DIST-02, DIST-03
**Success Criteria** (what must be TRUE):
  1. README opens with a gif/screenshot demo and a single curl install command that works on a fresh machine
  2. `skill.md` loads in Claude Code and the slash command description reads "use when you need to give an agent a pw without them seeing it"
  3. MIT `LICENSE` file is present at repo root
  4. A user who has never heard of pw2agent can understand what it does and install it within 60 seconds of landing on the repo
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Working Tool | 0/? | Not started | - |
| 2. OSS Release | 0/? | Not started | - |
