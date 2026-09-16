#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
INSTALL_DIR="$HOME/.local/bin"
LIB_DIR="$HOME/.local/lib/pw2agent"
SCRIPT_NAME="pw2agent"
GITHUB_RAW="https://raw.githubusercontent.com/alexfosterinvisible/pw2agent/main"
# shellcheck disable=SC2016
PATH_LINE='export PATH="$HOME/.local/bin:$PATH" # pw2agent'

case "${SHELL##*/}" in
  zsh)  RC_FILE="${ZDOTDIR:-$HOME}/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="$HOME/.profile" ;;
esac

# ---- main ----
main() {
  local downloaded=false
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/pw2agent" ]]; then
    SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"
  else
    SCRIPT_SRC="$(mktemp)"
    trap 'rm -f "$SCRIPT_SRC"' EXIT INT TERM
    curl -fsSL "$GITHUB_RAW/pw2agent" -o "$SCRIPT_SRC"
    downloaded=true
  fi

  mkdir -p "$INSTALL_DIR"
  cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
  chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

  # pw2agent sources lib/prompt.sh (the modal). Installed beside the binary so the
  # command works from anywhere, not only from inside a checkout.
  mkdir -p "$LIB_DIR"
  if [[ -f "$(dirname "$SCRIPT_SRC")/lib/prompt.sh" ]]; then
    cp "$(dirname "$SCRIPT_SRC")/lib/prompt.sh" "$LIB_DIR/prompt.sh"
  else
    curl -fsSL "$GITHUB_RAW/lib/prompt.sh" -o "$LIB_DIR/prompt.sh"
  fi

  if ! grep -qF '# pw2agent' "$RC_FILE" 2>/dev/null; then
    printf '\n%s\n' "$PATH_LINE" >> "$RC_FILE"
  fi

  [[ "$downloaded" == true ]] && { rm -f "$SCRIPT_SRC"; trap - EXIT INT TERM; }

  printf '✅ Ready. Run: pw2agent\n'
  printf '   (open a new terminal or: source %s)\n' "$RC_FILE"
}

main "$@"
