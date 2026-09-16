---
name: pw2agent
description: use when you need a secret from the user without it entering chat, or when a "NOTE FOR AGENT -- secret handoff" block is pasted
license: MIT
---

# pw2agent

A GUI modal asks the user for the secret on their own screen, and the value goes
straight to where it belongs. It never enters chat, the transcript, shell history,
or your context.

## Asking the user for a secret

Never ask the user to paste a secret into chat.

**Decide the destination first**, because it changes the command:

| The secret is | Destination | Command |
|:--|:--|:--|
| reusable by agents or apps (API key, token, password for automation) | **Doppler** | `pw2agent <label> --doppler NAME --no-stash` |
| one of Alex's personal logins, new item | **1Password** | `pw2agent <label> --op "<Item title>" --no-stash` |
| a one-off you consume in this session and then delete | the stash file | `pw2agent <label>` |

`--doppler` defaults to `general`/`dev_personal` (`--project` / `--config` to change it) and
round-trip verifies. `--op` creates a new Password item in `Personal` (`--vault` to change it).
Prefer a real destination over the stash: with `--no-stash` no file is written and there is no
NOTE to paste, so there is one less copy of the secret on disk. The house rule stands unchanged
- Doppler is the home for agent and app secrets, 1Password holds Alex's own logins, and you
never move a secret from one to the other.

### Running it

The modal is drawn by the machine's window server, so **you may run the command yourself on the
machine the user is sitting at**. Only the person at that screen can answer it, and the value is
returned to the script alone.

```bash
pw2agent pushcut --doppler PUSHCUT_API_KEY --no-stash
```

Use a short label: it names the stash file and titles the modal, so `pushcut`, not
`pushcut_api_key_for_agent1`.

Two cases where you must NOT just run it:

- **A remote or headless host** (an ssh session, agentbox, a background job) has no window
  server. The command exits 2 with `no window server is reachable here` rather than hanging.
  There, emit the command in a bash block for the user to run on their own machine instead.
- **The user is away.** A modal nobody answers blocks your shell until it is dismissed. Run it
  in the background, or say you are about to raise it, if you are not sure they are there.

Say in one line what you are asking for and why, then run it. No preamble, no checking whether
the stash already exists, no reading the pw2agent source.

Optional, only when the wait would otherwise idle a long-running task: arm a background watcher
on the stash path (or poll `doppler secrets get`) so you auto-resume when it lands, rather than
making the user report back.

### What stays off limits, modal or not

Alex types these into the 1Password app himself, and you never script them in: card numbers,
bank account numbers, sort codes, IBANs, 2FA secret keys, and 1Password's own Secret Key.
`pw2agent --op` is for a new, ordinary credential item, and it refuses to touch an item that
already exists (editing one would put the value in argv, where `ps` can read it).

## Consuming a NOTE FOR AGENT block

This is the stash path only. With `--doppler` or `--op` there is no NOTE: read the value from
that store at the moment you need it.

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
5. **Persist reusable secrets to Doppler.** If the secret is reusable (a
   password, API key, token - anything with a life beyond this one command),
   store it before deleting the stash, per the `doppler-secrets` skill's
   golden rule (default `general`/`dev_personal`, descriptive
   UPPERCASE_SNAKE name):
   `base64 -d < ~/.secret_pw | ~/.claude/skills/doppler-secrets/scripts/store_secret.sh NAME general dev_personal`
   Skip this only for genuinely one-off, non-reusable secrets (a single OTP,
   a session token expiring in minutes) - and say why you're skipping it.
   Next time, ask with `--doppler NAME --no-stash` and this step disappears.
6. When done: `rm -f ~/.secret_pw; unset PWB64`

## Platform notes

The modal is AppleScript on macOS, zenity or kdialog on Linux with a display, and a WinForms
dialog on Windows. `pw2agent` is a bash script, so on Windows the user runs it from Git Bash,
not PowerShell; its clipboard step uses `clip.exe`. `--tty` forces the old terminal prompt,
which needs a real TTY and is therefore the user's path, never yours.
