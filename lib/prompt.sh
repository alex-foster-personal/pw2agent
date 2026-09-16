#!/usr/bin/env bash
# prompt.sh -- read one secret from the human, without it passing through an agent.
#
# The GUI modal is the standard path: it is the only input that works when an AGENT
# starts the command, because a terminal `read -rs` needs a TTY the agent does not have
# (and any value it did capture would be the agent's, not Alex's). The modal is drawn by
# the window server on the machine's own screen, so only the person sitting there can
# answer it, and the value is returned on stdout to the calling script alone.
#
# Every function here prints the secret on stdout. NOTHING may log, echo or trace it.

# Returns: 0 value on stdout, 1 cancelled by the user, 2 no GUI available here.
_prompt_gui() {
  local prompt="$1" title="$2"

  case "$(uname -s)" in
    Darwin)
      /usr/bin/osascript 2>/dev/null <<OSA
tell application "System Events"
  activate
  set r to display dialog "${prompt//\"/\\\"}" default answer "" with hidden answer ¬
    with title "${title//\"/\\\"}" buttons {"Cancel", "OK"} default button "OK" with icon caution
  return text returned of r
end tell
OSA
      # osascript exits 1 on Cancel, and 1 on "no window server" too. A session with no
      # GUI is the `aqua` check below, so anything reaching here is a real cancel.
      return $?
      ;;

    Linux)
      [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || return 2
      if command -v zenity >/dev/null 2>&1; then
        zenity --password --title="$title" 2>/dev/null
        return $?
      elif command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$title" --password "$prompt" 2>/dev/null
        return $?
      fi
      return 2
      ;;

    MINGW*|MSYS*|CYGWIN*)
      command -v powershell.exe >/dev/null 2>&1 || return 2
      PW2AGENT_PROMPT="$prompt" PW2AGENT_TITLE="$title" \
      powershell.exe -NoProfile -NonInteractive -STA -Command '
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $f = New-Object Windows.Forms.Form
        $f.Text = $env:PW2AGENT_TITLE
        $f.Size = New-Object Drawing.Size(460, 170)
        $f.StartPosition = "CenterScreen"
        $f.TopMost = $true
        $l = New-Object Windows.Forms.Label
        $l.Text = $env:PW2AGENT_PROMPT
        $l.SetBounds(12, 12, 420, 32)
        $t = New-Object Windows.Forms.TextBox
        $t.UseSystemPasswordChar = $true
        $t.SetBounds(12, 52, 420, 24)
        $ok = New-Object Windows.Forms.Button
        $ok.Text = "OK"; $ok.DialogResult = "OK"; $ok.SetBounds(256, 92, 84, 26)
        $no = New-Object Windows.Forms.Button
        $no.Text = "Cancel"; $no.DialogResult = "Cancel"; $no.SetBounds(348, 92, 84, 26)
        $f.Controls.AddRange(@($l, $t, $ok, $no))
        $f.AcceptButton = $ok; $f.CancelButton = $no
        $f.Add_Shown({ $f.Activate(); $t.Focus() })
        if ($f.ShowDialog() -ne "OK") { exit 1 }
        [Console]::Out.Write($t.Text)
      ' 2>/dev/null | tr -d '\r'
      return "${PIPESTATUS[0]}"
      ;;
  esac
  return 2
}

# True when a GUI modal can actually be drawn for a person to answer.
_gui_available() {
  case "$(uname -s)" in
    # An ssh session inherits no window server, so `launchctl managername` reports
    # Background rather than Aqua. Asking that is what stops a modal being "shown"
    # to nobody on a headless or remote invocation.
    Darwin) [ "$(launchctl managername 2>/dev/null)" = "Aqua" ] ;;
    Linux)  [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] &&
            { command -v zenity >/dev/null 2>&1 || command -v kdialog >/dev/null 2>&1; } ;;
    MINGW*|MSYS*|CYGWIN*) command -v powershell.exe >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# Terminal fallback. Requires a real TTY, and says so rather than hanging on a pipe.
_prompt_tty() {
  local prompt="$1" pw1 pw2
  [ -t 0 ] || { printf '[ERROR] no TTY and no GUI: nothing can ask for this secret here\n' >&2; return 2; }
  printf '%s: ' "$prompt" >&2; read -rs pw1; printf '\n' >&2
  printf 'Confirm: ' >&2;     read -rs pw2; printf '\n' >&2
  [ "$pw1" = "$pw2" ] || { printf '[ERROR] secrets do not match\n' >&2; return 1; }
  printf '%s' "$pw1"
}

# The one entry point. PW2AGENT_INPUT=tty|gui forces a path; default prefers the modal.
# Retries an empty answer up to 3 times, since a modal makes a mis-paste cheap to redo.
read_secret() {
  local prompt="${1:-Paste the secret}" title="${2:-pw2agent}" value rc attempt
  local mode="${PW2AGENT_INPUT:-auto}"

  for attempt in 1 2 3; do
    if [ "$mode" = tty ]; then
      value="$(_prompt_tty "$prompt")"; rc=$?
    elif _gui_available; then
      value="$(_prompt_gui "$prompt" "$title")"; rc=$?
    elif [ "$mode" = gui ]; then
      printf '[ERROR] a GUI modal was required but no window server is reachable here\n' >&2
      return 2
    else
      value="$(_prompt_tty "$prompt")"; rc=$?
    fi

    [ "$rc" -eq 2 ] && return 2
    [ "$rc" -ne 0 ] && { printf '[ERROR] cancelled\n' >&2; return 1; }
    [ -n "$value" ] && { printf '%s' "$value"; return 0; }
    prompt="That was empty. $1"
  done

  printf '[ERROR] no value after 3 attempts\n' >&2
  return 1
}
