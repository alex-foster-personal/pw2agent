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

**Never run `pw2agent` yourself.** It is a user-side command: it reads from the
terminal with `read -rs`, so with no TTY it hangs or fails, and any value it did
capture would be yours rather than the user's. Invoking this skill to obtain a
secret means one thing - emit the command for the user to run, then stop.

Output exactly this, with a short label (it becomes `~/.{label}_pw`, so
`pushcut`, not `pushcut_api_key_for_agent1`):

````
```bash
pw2agent <label>
```
````

One line of context is enough: it takes the secret with hidden input, confirms
it twice, stashes it at `~/.{label}_pw` (mode 600), and copies a NOTE FOR AGENT
to the clipboard to paste back. No preamble, no checking whether the stash
already exists, no reading the pw2agent source.

Optional, only when the wait would otherwise idle a long-running task: arm a
background watcher on the stash path so you auto-resume when it appears, rather
than making the user report back.

## Consuming a NOTE FOR AGENT block

1. Read the file path from the NOTE (`File:` line, e.g. `~/.secret_pw`).
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
5. When done: `rm -f ~/.secret_pw; unset PWB64`
