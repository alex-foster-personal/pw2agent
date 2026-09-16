![pw2agent demo](demo.gif)

# pw2agent

Hand a secret to an AI agent without pasting it in chat.

A GUI modal asks for the value on your own screen. The agent can start the command, but
only the person at that machine can answer the dialog, and the value goes straight to the
store you name.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/alex-foster-personal/pw2agent/main/install.sh | bash
```

## Usage

```bash
pw2agent api_key                                  # modal -> ~/.api_key_pw + clipboard NOTE
pw2agent pushcut --doppler PUSHCUT_API_KEY --no-stash   # modal -> Doppler, no file at all
pw2agent router --op "Home router admin" --no-stash     # modal -> a new 1Password item
pw2agent api_key --tty                            # the old terminal prompt
```

Run `pw2agent --help` for the full option list.

| Destination | Flag | Notes |
|:--|:--|:--|
| Doppler | `--doppler NAME` | `NAME` must be UPPER_SNAKE. Defaults to project `general`, config `dev_personal` (`--project` / `--config`). Written on stdin and round-trip verified. |
| 1Password | `--op "Title"` | Creates a new Password item in `Personal` (`--vault`). Refuses if the item already exists, because editing one would put the value in argv. |
| Stash file | default | `~/.{label}_pw`, mode 600, base64. `--no-stash` turns it off. |

## How it works

The modal is AppleScript on macOS, zenity or kdialog on Linux with a display, and a
WinForms dialog on Windows. The value is returned to the script on stdout, passed to each
destination on **stdin**, and then unset. Nothing echoes it.

Why a modal rather than a terminal prompt: a terminal `read -rs` needs a TTY, which an
agent-started process does not have, so the old flow could only ever be run by hand. The
modal is drawn by the window server, so the agent can raise the question and still be
unable to answer it. On a host with no window server (ssh, headless) the command exits 2
and says so, instead of hanging on a prompt nobody can see.

## Claude Code skill

To teach Claude Code the pw2agent workflow:

```bash
mkdir -p ~/.claude/skills/pw2agent
curl -fsSL https://raw.githubusercontent.com/alex-foster-personal/pw2agent/main/skill.md \
  -o ~/.claude/skills/pw2agent/SKILL.md
```

## Security

- The secret is never in process args, env vars, or shell history
- Destinations receive it on stdin; `doppler secrets set` echoes values in its own output
  table, so that output is silenced rather than merely redirected
- The stash file is mode 600 (owner-read-only) and the NOTE includes an explicit `rm -f`
- Base64 is used to survive shell-unsafe bytes - it is encoding, not encryption.
  Confidentiality comes from the mode-600 file and the `rm -f` step, not the encoding
- No network calls, no logs, no dependencies beyond the store CLI you ask for

## Tests

```bash
bash tests/test_pw2agent.sh
```

17 checks, no real secret and no real store: `doppler` and `op` are stubbed to record what
they were handed, and the terminal path runs on a pty with echo off so the captured output
can be asserted not to contain the value. T14 is the control proving that leak check can
fail. Three mutations (removing the headless fail-fast, passing the value in argv, dropping
the existing-item guard) are each caught by exactly one check.

## License

MIT
