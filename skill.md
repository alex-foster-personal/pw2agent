---
name: pw2agent
description: use when you need a secret from the user without it entering chat, or when a "NOTE FOR AGENT -- secret handoff" block is pasted
license: MIT
---

# pw2agent

Two sides: the user-side stash command, and the agent-side consumption protocol.

## Asking the user for a secret

Never ask the user to paste a secret into chat. Tell them:

> Run `pw2agent <label>` in your terminal - it consumes the secret (hidden input,
> confirmed twice), stashes it at `~/.{label}_pw` (mode 600), and copies a NOTE
> to your clipboard telling me how to use it without ever printing it.

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
