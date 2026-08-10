tell application "Terminal"
  set out to ""
  repeat with w in windows
    try
      set out to out & (id of w) & " | busy=" & (busy of w) & " | tty=" & (tty of selected tab of w) & linefeed
    end try
  end repeat
  return out
end tell
