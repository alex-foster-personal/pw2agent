#!/usr/bin/env bash
# Close the Terminal.app window whose selected tab has the given tty.
# Usage: close_by_tty.sh /dev/ttys018
#
# Two AppleScript traps, both of which return 0 while closing nothing:
#   1. `close (every window whose tty of selected tab is X)` -- `whose` does not
#      traverse a nested property, so it matches nothing.
#   2. closing inside `repeat with w in windows` -- mutating the collection
#      mid-iteration drops the close.
# Collecting ids first and closing in a second pass avoids both.
set -uo pipefail
TTY_PATH="${1:-}"
[[ "$TTY_PATH" =~ ^/dev/tty[a-zA-Z0-9]+$ ]] || { echo "bad tty: $TTY_PATH" >&2; exit 1; }
osascript <<AS
tell application "Terminal"
  set doomed to {}
  repeat with w in (windows as list)
    try
      if (tty of selected tab of w) is "$TTY_PATH" then
        set end of doomed to (id of w)
      end if
    end try
  end repeat
  repeat with wid in doomed
    try
      close (every window whose id is wid) saving no
    end try
  end repeat
  return "closed " & (count of doomed)
end tell
AS
