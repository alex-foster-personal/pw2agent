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

**First: are you on the machine the user is sitting at?** If your shell is an ssh session,
a headless box (agentbox), or a background job, skip to "When you are on the wrong
machine" below. `[ -n "$SSH_CONNECTION" ]` is the quick tell. Running it there anyway is
harmless - it exits 2 immediately rather than hanging - but do not make that your check.

**On the user's own machine, run it yourself.** The modal is drawn by that machine's
window server, so raising the question costs one dialog and no round trip. You cannot
answer it: only the person at that screen can.

```bash
pw2agent pushcut --doppler PUSHCUT_API_KEY --no-stash
```

Before you do, two cheap things:

1. **Check whether you already have it.** `doppler secrets get NAME --project general
   --config dev_personal --plain >/dev/null 2>&1` (or `op item get "<title>"`) exits 0 if
   it is already stored. Do not interrupt the user for a secret they have given before -
   and note `--doppler` OVERWRITES, so this same check is what stops you clobbering a
   working credential when you only meant to add one.
2. **Say in chat, in one line, what you are asking for and why, before the dialog appears.**
   The modal shows only your label and prompt, so an unexplained password box titled
   `pushcut` gives the user no grounds to trust it. `--prompt "TEXT"` sets the wording.

Use a short label: it titles the modal and names the stash file, so `pushcut`, not
`pushcut_api_key_for_agent1`. The Doppler NAME is separate and should be descriptive
UPPER_SNAKE (`PUSHCUT_API_KEY`, `HETZNER_API_TOKEN`) - name it in your chat line too, so
the user can check afterwards where it landed. Project/config default to
`general`/`dev_personal`, which is the home for anything personal to this Mac; work
credentials belong in `construct`/`dev_af` (`--project construct --config dev_af`).

Exit codes, which is how you tell the three outcomes apart:

| Code | Meaning | What to do |
|:--|:--|:--|
| 0 | stored, and verified in each destination | carry on |
| 1 | the user cancelled, or a destination failed (the message says which) | do not retry blindly; a cancel is an answer |
| 2 | nothing here can ask: no window server and no TTY | see below |

**Exit 2 means you are on the wrong machine.** A remote or headless host (an ssh session,
agentbox, a background job) has no window server, and the command says so instead of
hanging. Do not work around it: give the user the command in a bash block to run **on
their own machine**, and pick a destination they and you can both reach. `--doppler` and
`--op` are shared stores; **the stash file is machine-local**, so a stash written on their
Mac is invisible to an agent on another host. That makes `--doppler NAME --no-stash` the
only sane form for a remote handoff.

Shared does not mean reachable: the round trip the command verifies happens on THEIR
machine, and proves nothing about yours. Confirm your own host can read the store first
(`doppler configure get token` / a redirected `doppler secrets get`) and fix that before
asking, or the user answers a dialog for a value you still cannot use.

**If the user may be away**, a modal nobody answers blocks your shell until it is
dismissed. Run it detached and poll the destination, rather than stalling the turn:

```bash
pw2agent pushcut --doppler PUSHCUT_API_KEY --no-stash &        # same machine as you
for _ in $(seq 60); do   # 20 minutes, then give up and say so
  doppler secrets get PUSHCUT_API_KEY --project general --config dev_personal --plain >/dev/null 2>&1 && break
  sleep 20
done
```

The same poll is how you wait in the remote case, where only the poll runs on your host and
the `pw2agent` line runs on the user's machine. **You never see their exit code there**: a
cancelled modal looks exactly like a slow one, so always bound the wait and report an
unanswered ask rather than spinning.

### Reading it back

The rules in "Consuming a NOTE FOR AGENT block" about never printing a value apply to
**every** path, not just the stash. From a store, inject rather than print:

```bash
doppler run --project general --config dev_personal -- ./script.py        # preferred
HCLOUD_TOKEN=$(doppler secrets get HETZNER_API_TOKEN --project general --config dev_personal --plain) hcloud server list  # when the CLI wants a different var name than the key
op read "op://Personal/<item>/password" | some-cli --secret-stdin
```

Never run a bare `doppler secrets get ... --plain` or `op read` on its own: the value lands
in the transcript as tool output. Redirected to `/dev/null` it is an existence check, not a
read, which is why the probe and the poll below are safe.

### Flags worth knowing

- `--no-stash` is not the default. Without it you get the stash file **as well as** the
  store, which is a second copy at rest with a NOTE and an `rm -f` to remember. Pass it
  whenever you name a destination.
- `--doppler` **overwrites** an existing key (that is how rotation works), so check first
  if you did not intend to replace one. `--op` refuses an item that already exists.
- The clipboard is only touched on the stash path, to carry the NOTE. With `--no-stash`
  nothing goes to the clipboard.
- `--prompt "TEXT"` sets the modal wording. Use it: the dialog otherwise shows only the
  label, and the user is deciding whether an unexpected password box is legitimate.
- `pw2agent` installs to `~/.local/bin`. If the bare name is not found, call
  `~/.local/bin/pw2agent`, or re-run `afmac/scripts/setup_nested_repos.sh` to install it.

### What stays off limits, modal or not

Alex types these into the 1Password app himself, and you never script them in: card
numbers, bank account numbers, sort codes, IBANs, 2FA secret keys, and 1Password's own
Secret Key. `pw2agent --op` is for a new, ordinary credential item, and it refuses to
touch an item that already exists (editing one would put the value in argv, where `ps`
can read it).

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
which needs a real TTY and is therefore the user's path, never yours. `base64 -d` works on
macOS, Linux and Git Bash alike.
