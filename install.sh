#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="pw2agent"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"
RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"
# shellcheck disable=SC2016
PATH_LINE='export PATH="$HOME/.local/bin:$PATH" # pw2agent'

# ---- main ----
main() {
  mkdir -p "$INSTALL_DIR"
  cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
  chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

  if ! grep -qF '# pw2agent' "$RC_FILE" 2>/dev/null; then
    printf '\n%s\n' "$PATH_LINE" >> "$RC_FILE"
  fi

  printf '✅ Ready. Run: pw2agent\n'
  printf '   (open a new terminal or: source %s)\n' "$RC_FILE"
}

main "$@"
