tell application "Terminal"
  set out to ""
  repeat with w in (windows as list)
    try
      set out to out & "id=" & (id of w) ¬
        & " visible=" & (visible of w) ¬
        & " miniaturized=" & (miniaturized of w) ¬
        & " tabs=" & (count of tabs of w) ¬
        & " procs=" & (processes of selected tab of w as string) ¬
        & linefeed
    on error errMsg
      set out to out & "id? ERR " & errMsg & linefeed
    end try
  end repeat
  return out
end tell
