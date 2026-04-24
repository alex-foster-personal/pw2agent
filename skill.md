---
name: pw2agent
description: use when you need to give an agent a pw without them seeing it
license: MIT
---

# pw2agent

When a user hands you a NOTE FOR AGENT block, follow these steps:

1. Read the file path from the NOTE (`File:` line, e.g. `~/.secret_pw`)
2. Decode the secret: `PWB64=$(base64 -d < ~/.secret_pw | tr -d '\n')`
3. Use `$PWB64` for the task — do not print or log its value
4. When done: `rm -f ~/.secret_pw; unset PWB64`

Do not ask the user to paste the secret into chat. The NOTE FOR AGENT pattern
exists specifically to avoid that.
