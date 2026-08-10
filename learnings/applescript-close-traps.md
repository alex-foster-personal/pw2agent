# Closing a Terminal.app window from AppleScript returns 0 and does nothing

Hit three times while building `pw2agent --launch --autoclose`. Every failure
mode exits 0, so nothing surfaces as an error -- the window simply stays.

1. **`whose` will not traverse a nested property.**
   `close (every window whose tty of selected tab is "/dev/ttys018")` matches
   nothing. Direct properties are fine (`whose id is 2807`). Compare inside an
   explicit `repeat` instead.

2. **Closing while iterating drops the close.**
   Mutating the collection inside `repeat with w in windows` loses it. Collect
   ids in one pass, close in a second.

3. **The real one: a window with a live process raises a confirmation sheet.**
   macOS asks "Terminate?" (buttons: Cancel, Terminate). That sheet is modal and
   **blocks every later AppleScript close**, so one stuck sheet silently breaks
   all subsequent cleanup. Detect with:
   `osascript -e 'tell application "System Events" to tell process "Terminal" to return (count of sheets of windows)'`
   and dismiss with `click button "Terminate" of sheet 1 of window 1`.

**The fix is structural, not a better incantation:** have the shell in the window
`exit` as soon as its job is done, then close the window later from a *detached*
process. No running process means no sheet. Corollary: never schedule a close for
a window still waiting on input -- it both raises the sheet and yanks a window the
user may be typing into. `--launch` therefore closes only on success, never on
timeout.

Also: `busy of window` is the safe filter for "is anything running here", and is
what `close_idle_terminals.applescript` uses to never kill live work.
