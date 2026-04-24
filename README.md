![pw2agent demo](demo.gif)

# pw2agent

Hand a secret to an AI agent without pasting it in chat.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/agdfoster/pw2agent/main/install.sh | bash
```

## Usage

```bash
pw2agent              # stashes as ~/.secret_pw
pw2agent api_key      # stashes as ~/.api_key_pw
```

Run `pw2agent --help` for options.

## How it works

pw2agent prompts twice for your secret (silent input, no echo) and writes it
base64-encoded to a mode-600 file. A NOTE FOR AGENT block with the path, read
command, and delete command is placed on your clipboard for you to paste into
the agent.

## Claude Code skill

To teach Claude Code the pw2agent workflow:

```bash
mkdir -p ~/.claude/skills/pw2agent
curl -fsSL https://raw.githubusercontent.com/agdfoster/pw2agent/main/skill.md \
  -o ~/.claude/skills/pw2agent/SKILL.md
```

Then paste a NOTE FOR AGENT block into Claude Code and it handles the rest.

## Security

- Secret is never in process args, env vars, or shell history
- File is mode 600 (owner-read-only)
- NOTE FOR AGENT includes an explicit `rm -f` delete step
- No network calls, no logs, no dependencies
- Base64 is used to survive shell-unsafe bytes — it is encoding, not encryption. Confidentiality comes from the mode-600 file and the `rm -f` step, not the encoding.

## License

MIT
