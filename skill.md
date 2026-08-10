---
name: pw2agent
description: use when you need a secret from the user without it entering chat, or when a "NOTE FOR AGENT -- secret handoff" block is pasted
license: MIT
---

# pw2agent

Two sides: the user-side stash command, and the agent-side consumption protocol.

Windows note: `pw2agent` is installed at `~/.local/bin/pw2agent` (on PATH in Git
Bash). It is a bash script - the user must run it from Git Bash, not PowerShell.
The clipboard step uses Windows `clip.exe`.

## Asking the user for a secret

Never ask the user to paste a secret into chat.

**Default: run `--launch` and wait.** One call opens a real terminal window for
the user, blocks while they type the secret, and returns when it is stashed:

```bash
pw2agent --launch <label> --timeout 600
```

Use a short label (it becomes `~/.{label}_pw`, so `pushcut`, not
`pushcut_api_key_for_agent1`). Then consume the stash per the rules below -
nothing needs pasting back, since you already know the path. Tell the user in
one line that a window has opened and what to type into it.

This works from an agent with no TTY because the *window* has one. On macOS it
reaches the GUI session via `osascript` even when the agent runs in launchd's
`Background` domain, so nothing needs restarting.

`--launch` never reads the secret: it opens the window, then polls for the file.

| exit | meaning | your move |
|:--|:--|:--|
| 0 | stash ready | consume it (below) |
| 1 | timed out | re-launch, or fall back to the manual flow |
| 2 | no GUI terminal (SSH, headless, container) | fall back to the manual flow |
| 3 | bad usage | label must match `[A-Za-z0-9_-]+`; timeout a positive int |

Set `--timeout` to how long the user plausibly needs. It blocks for that long,
so never wrap it in a shorter foreground timeout.

**Never run bare `pw2agent` yourself** (without `--launch`). It reads with
`read -rs`, so with no TTY it hangs or fails, and any value it captured would be
yours rather than the user's.

### Manual fallback (exit 2, or no GUI at all)

Output exactly this, then stop:

````
```bash
pw2agent <label>
```
````

One line of context is enough: it takes the secret with hidden input, confirms
it twice, stashes it at `~/.{label}_pw` (mode 600), and copies a NOTE FOR AGENT
to the clipboard to paste back. No preamble, no checking whether the stash
already exists, no reading the pw2agent source.

## Consuming a stashed secret

Applies to both routes: a stash you got from `--launch` (path is
`~/.{label}_pw`), and a NOTE FOR AGENT block the user pasted.

1. Get the file path - from `--launch`'s label, or the NOTE's `File:` line.
2. The file is base64-encoded but NOT encrypted - treat it as plaintext at rest.
3. The decoded value must NEVER reach stdout/stderr or a tool parameter
   (tool output and tool params are recorded verbatim in the transcript):
   - never cat/echo/print the file or the decoded value
   - consume it in ONE Bash call, inside the destination command:
     - env var: `MYVAR=$(base64 -d < ~/.secret_pw) ./script.py`
     - to file: `printf 'PW=%s\n' "$(base64 -d < ~/.secret_pw)" >> .env.local`
     - stdin:   `base64 -d < ~/.secret_pw | some-cli --secret-stdin`
   - prefer stdin/env over CLI args (argv is visible in `ps`)
   - if the destination CLI echoes values back, suppress it (`--silent`, `>/dev/null`)
4. MCP tool parameters (send_message text, browser form-fill values) CANNOT
   stay private - the value unavoidably enters the transcript. If the task
   requires that, say so and let the user do that one step manually.
5. **Persist reusable secrets to Doppler.** If the secret is reusable (a
   password, API key, token - anything with a life beyond this one command),
   store it before deleting the stash, per the `doppler-secrets` skill's
   golden rule (default `general`/`dev_personal`, descriptive
   UPPERCASE_SNAKE name):
   `base64 -d < ~/.secret_pw | ~/.claude/skills/doppler-secrets/scripts/store_secret.sh NAME general dev_personal`
   Skip this only for genuinely one-off, non-reusable secrets (a single OTP,
   a session token expiring in minutes) - and say why you're skipping it.
6. When done: `rm -f ~/.secret_pw; unset PWB64`
