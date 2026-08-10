-- Close only Terminal.app windows with no running process (busy = false).
-- A busy window is left alone, so this can never kill work in progress.
-- Other terminal apps (ghostty, iTerm, Warp) are a different process and untouched.
tell application "Terminal"
  set closed to 0
  set kept to 0
  repeat with w in (windows as list)
    try
      if busy of w is false then
        close w saving no
        set closed to closed + 1
      else
        set kept to kept + 1
      end if
    end try
  end repeat
  return "closed=" & closed & " kept_busy=" & kept
end tell
