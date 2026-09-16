#!/usr/bin/env bash
# Regression tests for pw2agent's modal input and its destinations.
#
# if the modal is not preferred when a GUI exists then an agent-started run hangs on a TTY -> broken
# if a GUI-only run silently falls back to the terminal then it waits forever unseen -> broken
# if cancel does not exit non-zero then a caller believes it stored something -> broken
# if the secret reaches stdout, a log, or argv then the transcript leaks it -> broken
# if the stash is not mode 600 then any local process can read it -> broken
# if a destination failure is not reported then the value is lost silently -> broken
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0
_t() { if [ "$2" = "$3" ]; then echo "[OK] $1"; else echo "[FAIL] $1 (want '$3', got '$2')"; fails=$((fails+1)); fi }
_contains() { case "$2" in *"$3"*) _t "$1" found found ;; *) _t "$1" "missing: $2" "contains: $3" ;; esac }

SECRET='sw0rdf1sh-TEST-not-a-real-secret'

#----- the decision logic in read_secret, with the two prompts stubbed ---------
# Stubbing is how the GUI branch gets tested with nobody at the screen. The shipped
# script has no such hook: these overrides exist only inside this test's shell.

_probe() {  # $1 = PW2AGENT_INPUT, $2 = gui available?, $3 = what the gui returns
  (
    . "$REPO/lib/prompt.sh"
    eval "_gui_available() { [ \"$2\" = yes ]; }"
    eval "_prompt_gui() { case \"$3\" in cancel) return 1 ;; none) return 2 ;; *) printf '%s' \"$3\" ;; esac; }"
    _prompt_tty() { printf 'TTY-WAS-USED'; }
    PW2AGENT_INPUT="$1" read_secret "p" "t" 2>/dev/null
    printf '|rc=%s' "$?"
  )
}

out="$(_probe auto yes "$SECRET")"
_t "T1 modal is used when a GUI is available" "$out" "$SECRET|rc=0"

out="$(_probe auto no "$SECRET")"
_t "T2 terminal is the fallback with no GUI" "$out" "TTY-WAS-USED|rc=0"

out="$(_probe gui no "$SECRET")"
_t "T3 gui-only on a headless host fails fast, never a silent TTY wait" "$out" "|rc=2"

out="$(_probe auto yes cancel)"
_t "T4 cancel exits 1" "$out" "|rc=1"

out="$(_probe tty yes "$SECRET")"
_t "T5 --tty forces the terminal even when a GUI exists" "$out" "TTY-WAS-USED|rc=0"

#----- destinations, with doppler and op stubbed to record what they receive ---

mkdir -p "$TMP/bin" "$TMP/home"
cat > "$TMP/bin/doppler" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "secrets set") cat > "$DOPPLER_SPY"; echo "doppler would echo the value here" ;;
  "secrets get") cat "$DOPPLER_SPY" ;;
esac
EOF
cat > "$TMP/bin/op" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "item get")    [ -f "$OP_SPY" ] && exit 0 || exit 1 ;;
  "item create") cat > "$OP_SPY" ;;
esac
EOF
chmod +x "$TMP/bin/doppler" "$TMP/bin/op"

export DOPPLER_SPY="$TMP/doppler.spy" OP_SPY="$TMP/op.spy"
# A pty is what makes the terminal path testable without a human; the value is fed twice
# because the terminal path asks for a confirmation.
_run_tty() {
  env HOME="$TMP/home" PATH="$TMP/bin:$PATH" PW2AGENT_INPUT=tty \
    python3 "$REPO/tests/pty_run.py" "$SECRET
$SECRET" "$REPO/pw2agent" "$@" 2>&1
}

rm -f "$OP_SPY"
out="$(_run_tty selftest --doppler TEST_SECRET_NAME --op "Test Item")"
_contains "T6 doppler stored and verified" "$out" "[OK] doppler general/dev_personal :: TEST_SECRET_NAME"
_contains "T7 1password item created" "$out" "[OK] 1password Personal :: Test Item"
_contains "T8 stash written" "$out" "[OK] stashed"

_t "T9 doppler received the value on stdin, not in argv" "$(cat "$DOPPLER_SPY")" "$SECRET"
_t "T10 1password template carries the value" \
   "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["fields"][0]["value"])' "$OP_SPY")" "$SECRET"

_t "T11 stash is base64 of the value" "$(base64 -d < "$TMP/home/.selftest_pw")" "$SECRET"
_t "T12 stash is mode 600" "$(stat -f '%Lp' "$TMP/home/.selftest_pw" 2>/dev/null || stat -c '%a' "$TMP/home/.selftest_pw")" "600"

# T13 is the one that matters: the plaintext must never be in what the user or an agent sees.
case "$out" in *"$SECRET"*) _t "T13 the secret never appears in the output" leaked "not leaked" ;;
                         *) _t "T13 the secret never appears in the output" "not leaked" "not leaked" ;; esac

# T14 control: prove T13 can fail. A deliberately leaky run must be caught.
leaky="$out
echo $SECRET"
case "$leaky" in *"$SECRET"*) _t "T14 control: a leak IS detected" caught caught ;;
                           *) _t "T14 control: a leak IS detected" "missed" "caught" ;; esac

#----- refusals ---------------------------------------------------------------

out="$(env HOME="$TMP/home" "$REPO/pw2agent" x --no-stash 2>&1)"
_contains "T15 no destination at all is refused" "$out" "leaves nowhere to put it"

out="$(env HOME="$TMP/home" "$REPO/pw2agent" x --doppler not-upper 2>&1)"
_contains "T16 a non UPPER_SNAKE doppler name is refused" "$out" "must be UPPER_SNAKE"

touch "$OP_SPY"
out="$(_run_tty selftest2 --no-stash --op "Test Item")"
_contains "T17 an existing 1password item is never edited from here" "$out" "already exists"

[ $fails -eq 0 ] && { echo "[OK] all checks passed"; exit 0; } || { echo "[ERROR] $fails check(s) failed"; exit 1; }
