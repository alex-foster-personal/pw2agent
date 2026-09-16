#!/usr/bin/env python3
"""Run a command on a pty with echo OFF, feed it lines, print what it wrote.

pw2agent's terminal path requires a real TTY (a pipe makes it refuse rather than hang),
so the tests need a pty. `script` is not usable here because it echoes the input back,
which would put the test secret in the captured output and make a leak check meaningless.
"""
import os, pty, select, sys, termios

lines = sys.argv[1].split("\n")
argv = sys.argv[2:]

pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)

attrs = termios.tcgetattr(fd)
attrs[3] &= ~termios.ECHO
termios.tcsetattr(fd, termios.TCSANOW, attrs)
for line in lines:
    os.write(fd, (line + "\n").encode())

out = b""
while True:
    try:
        r, _, _ = select.select([fd], [], [], 10)
        if not r:
            break
        chunk = os.read(fd, 4096)
        if not chunk:
            break
        out += chunk
    except OSError:
        break
_, status = os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
sys.exit(os.waitstatus_to_exitcode(status) if status else 0)
