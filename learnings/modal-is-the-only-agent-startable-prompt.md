# The modal is what lets an agent START the ask (Tue 16 Sep 2026)

The original skill said "never run `pw2agent` yourself", and it was right about the
mechanism: `read -rs` needs a TTY, an agent-started process has none, so the command
either hung or captured nothing. The consequence was that every secret handoff cost a
round trip -- the agent emitted a command, stopped, and waited for Alex to notice it,
run it, and paste a NOTE back.

A GUI modal inverts that without weakening anything. The window server draws it on the
machine's own screen, so the agent can raise the question and still be structurally
unable to answer it: only the person at that screen can type into the dialog, and the
value is returned to the script, not to the caller's context.

Two things that had to be got right for it to be safe rather than merely convenient:

- **A headless host must fail, not fall back.** An ssh session or a background job has
  no window server. Falling back to the terminal prompt there produces a process waiting
  on a prompt nobody can see, which looks like a hang with no explanation. `launchctl
  managername` returning something other than `Aqua` is the macOS test; exit 2 with a
  plain message is the behaviour.
- **`--no-stash` beats the stash file.** Once the value can go straight into Doppler or
  1Password, the file, the base64, the clipboard NOTE and the `rm -f` step all stop
  existing. Fewer copies is the whole point.

Measured while building it: `bash -n` calls a CRLF script valid, and `script -q` echoes
its input back into the captured output, which silently defeated a "the secret never
appears in the output" assertion until the pty driver turned echo off.
