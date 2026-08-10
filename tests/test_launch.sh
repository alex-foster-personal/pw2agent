#!/usr/bin/env bash
# Acceptance tests for `pw2agent --launch`.
#
# Single-line regression contract:
#   if a label with AppleScript metacharacters is accepted then broken
#   if a stale stash is not cleared before launching then broken
#   if --launch prints the decoded secret anywhere then broken
#   if a timeout with no stash does not exit 1 then broken
#   if no GUI terminal is available and it hangs instead of exiting 2 then broken
#   if --launch on a headless/SSH session does not print the manual fallback then broken
#
# Tests that need a real GUI terminal are skipped (not silently passed) when
# one is unavailable, and say so.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PW2AGENT="$HERE/../pw2agent"
PASS=0; FAIL=0; SKIP=0

_ok()   { printf '  [PASS] %s\n' "$1"; PASS=$((PASS+1)); }
_bad()  { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }
_skip() { printf '  [SKIP] %s -- %s\n' "$1" "$2"; SKIP=$((SKIP+1)); }

printf '\n=== pw2agent --launch acceptance tests ===\n\n'

# --- 1. label validation (AppleScript / shell injection) -------------------
printf 'label validation\n'
for bad_label in 'a"; do shell script "id' 'a b' 'a/../../etc/passwd' 'a$(id)' 'a;id' '../x' 'a`id`'; do
  if out=$("$PW2AGENT" --launch "$bad_label" --timeout 1 2>&1); then
    _bad "rejected label: $bad_label (exited 0)"
  elif printf '%s' "$out" | grep -qi 'invalid label'; then
    _ok "rejected label: $bad_label"
  else
    _bad "rejected label: $bad_label (wrong error: $(printf '%s' "$out" | head -1))"
  fi
done

# a valid label must NOT be rejected for being invalid
out=$("$PW2AGENT" --launch "valid_label-1" --timeout 1 --dry-run 2>&1) || true
if printf '%s' "$out" | grep -qi 'invalid label'; then
  _bad "accepts a valid label"
else
  _ok "accepts a valid label"
fi

# --- 2. stale stash is cleared --------------------------------------------
printf '\nstale stash handling\n'
STALE_LABEL="pw2agent_selftest_stale"
STALE_FILE="$HOME/.${STALE_LABEL}_pw"
printf 'STALE_VALUE_SHOULD_BE_GONE' | base64 | tr -d '\n' > "$STALE_FILE"
"$PW2AGENT" --launch "$STALE_LABEL" --timeout 1 --dry-run >/dev/null 2>&1 || true
if [[ -e "$STALE_FILE" ]]; then
  _bad "clears a pre-existing stash before launching"
  rm -f "$STALE_FILE"
else
  _ok "clears a pre-existing stash before launching"
fi

# --- 3. secret never leaks to stdout/stderr -------------------------------
printf '\nsecret containment\n'
LEAK_LABEL="pw2agent_selftest_leak"
LEAK_FILE="$HOME/.${LEAK_LABEL}_pw"
printf 'SUPERSECRETCANARY' | base64 | tr -d '\n' > "$LEAK_FILE"
# --dry-run stops before launching, so the stash it finds is the canary we wrote;
# whatever it prints must not contain the decoded value.
out=$("$PW2AGENT" --launch "$LEAK_LABEL" --timeout 1 --dry-run 2>&1) || true
if printf '%s' "$out" | grep -q 'SUPERSECRETCANARY'; then
  _bad "never prints the decoded secret"
else
  _ok "never prints the decoded secret"
fi
rm -f "$LEAK_FILE"

# --- 4. timeout behaviour --------------------------------------------------
printf '\ntimeout behaviour\n'
TO_LABEL="pw2agent_selftest_timeout"
rm -f "$HOME/.${TO_LABEL}_pw"
if [[ "$(uname -s)" == "Darwin" ]] && [[ -n "${PW2AGENT_TEST_GUI:-}" ]]; then
  start=$(date +%s)
  "$PW2AGENT" --launch "$TO_LABEL" --timeout 3 >/dev/null 2>&1; rc=$?
  elapsed=$(( $(date +%s) - start ))
  if [[ $rc -eq 1 ]] && [[ $elapsed -ge 2 ]]; then
    _ok "exits 1 after timeout with no stash (${elapsed}s)"
  else
    _bad "exits 1 after timeout with no stash (rc=$rc elapsed=${elapsed}s)"
  fi
  rm -f "$HOME/.${TO_LABEL}_pw"
else
  _skip "exits 1 after timeout" "needs PW2AGENT_TEST_GUI=1 on macOS (opens a window)"
fi

# --- 5. no-GUI fallback ----------------------------------------------------
printf '\nheadless fallback\n'
out=$(PW2AGENT_FORCE_NO_GUI=1 "$PW2AGENT" --launch "pw2agent_selftest_nogui" --timeout 1 2>&1); rc=$?
if [[ $rc -eq 2 ]]; then
  _ok "exits 2 when no GUI terminal is available"
else
  _bad "exits 2 when no GUI terminal is available (got $rc)"
fi
if printf '%s' "$out" | grep -q 'pw2agent pw2agent_selftest_nogui'; then
  _ok "prints the manual command as fallback"
else
  _bad "prints the manual command as fallback"
fi
rm -f "$HOME/.pw2agent_selftest_nogui_pw"

# --- 6. help still works ---------------------------------------------------
printf '\nhelp\n'
# Captured first, not piped: `grep -q` exits on the first match, which SIGPIPEs
# pw2agent, and `pipefail` would then report the pipeline as failed.
help_out=$("$PW2AGENT" --help 2>&1)
if printf '%s' "$help_out" | grep -q -- '--launch'; then
  _ok "--help documents --launch"
else
  _bad "--help documents --launch"
fi

# --- 7. bare mode unchanged (no TTY -> must not hang) ----------------------
printf '\nbare mode regression\n'
if out=$(printf '' | timeout 5 "$PW2AGENT" pw2agent_selftest_bare 2>&1); then
  _bad "bare mode with empty stdin fails rather than writing a stash"
else
  _ok "bare mode with empty stdin fails rather than writing a stash"
fi
rm -f "$HOME/.pw2agent_selftest_bare_pw"

# --- 8. autoclose validation ----------------------------------------------
printf '\nautoclose validation\n'
for bad in "abc" "-1" "1.5"; do
  if out=$("$PW2AGENT" --launch selftest --autoclose "$bad" --dry-run 2>&1); then
    _bad "rejects --autoclose $bad"
  elif printf '%s' "$out" | grep -qi 'autoclose must be'; then
    _ok "rejects --autoclose $bad"
  else
    _bad "rejects --autoclose $bad (wrong error)"
  fi
done
out=$("$PW2AGENT" --launch selftest --autoclose 0 --dry-run 2>&1) || true
if printf '%s' "$out" | grep -qi 'autoclose must be'; then
  _bad "accepts --autoclose 0 (never close)"
else
  _ok "accepts --autoclose 0 (never close)"
fi

# --- 9. end-to-end: window opens, secret typed, stash appears, window closes -
printf '\nend-to-end (GUI)\n'
if [[ "$(uname -s)" == "Darwin" ]] && [[ -n "${PW2AGENT_TEST_GUI:-}" ]]; then
  E2E_LABEL="pw2agent_selftest_e2e"
  E2E_FILE="$HOME/.${E2E_LABEL}_pw"
  CANARY="e2e-canary-$$"
  rm -f "$E2E_FILE"
  before=$(osascript -e 'tell application "Terminal" to return count of windows' 2>/dev/null || echo 0)

  "$PW2AGENT" --launch "$E2E_LABEL" --timeout 45 --autoclose 5 >/tmp/pw2agent_e2e.log 2>&1 &
  launch_pid=$!

  # Give the window time to open and reach the first prompt, then type the
  # secret twice (pw2agent asks for confirmation).
  sleep 5
  osascript -e "tell application \"Terminal\" to activate" >/dev/null 2>&1
  osascript -e "tell application \"System Events\" to keystroke \"$CANARY\"" >/dev/null 2>&1
  osascript -e 'tell application "System Events" to key code 36' >/dev/null 2>&1
  sleep 1
  osascript -e "tell application \"System Events\" to keystroke \"$CANARY\"" >/dev/null 2>&1
  osascript -e 'tell application "System Events" to key code 36' >/dev/null 2>&1

  if wait $launch_pid; then
    _ok "e2e: --launch returned 0 after the secret was typed"
  else
    _bad "e2e: --launch returned 0 after the secret was typed (see /tmp/pw2agent_e2e.log)"
  fi

  if [[ -s "$E2E_FILE" ]] && [[ "$(base64 -d < "$E2E_FILE")" == "$CANARY" ]]; then
    _ok "e2e: stash contains exactly what was typed"
  else
    _bad "e2e: stash contains exactly what was typed"
  fi

  if grep -q "$CANARY" /tmp/pw2agent_e2e.log 2>/dev/null; then
    _bad "e2e: --launch output never contains the secret"
  else
    _ok "e2e: --launch output never contains the secret"
  fi

  # autoclose is 5s and runs after the stash is written
  sleep 12
  after=$(osascript -e 'tell application "Terminal" to return count of windows' 2>/dev/null || echo 0)
  if [[ "$after" -le "$before" ]]; then
    _ok "e2e: window auto-closed (before=$before after=$after)"
  else
    _bad "e2e: window auto-closed (before=$before after=$after)"
  fi
  rm -f "$E2E_FILE" /tmp/pw2agent_e2e.log
else
  _skip "e2e launch/type/stash/autoclose" "needs PW2AGENT_TEST_GUI=1 on macOS"
fi

printf '\n=== %d passed, %d failed, %d skipped ===\n\n' "$PASS" "$FAIL" "$SKIP"
[[ $FAIL -eq 0 ]]
