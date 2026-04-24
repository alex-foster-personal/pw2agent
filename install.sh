#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="pw2agent"
GITHUB_RAW="https://raw.githubusercontent.com/agdfoster/pw2agent/main"
RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"
# shellcheck disable=SC2016
PATH_LINE='export PATH="$HOME/.local/bin:$PATH" # pw2agent'
_DOWNLOADED=false

if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/pw2agent" ]]; then
  SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"
else
  SCRIPT_SRC="$(mktemp)"
  curl -fsSL "$GITHUB_RAW/pw2agent" -o "$SCRIPT_SRC"
  _DOWNLOADED=true
fi

# ---- main ----
main() {
  mkdir -p "$INSTALL_DIR"
  cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
  chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

  if ! grep -qF '# pw2agent' "$RC_FILE" 2>/dev/null; then
    printf '\n%s\n' "$PATH_LINE" >> "$RC_FILE"
  fi

  [[ "$_DOWNLOADED" == true ]] && rm -f "$SCRIPT_SRC"

  printf '✅ Ready. Run: pw2agent\n'
  printf '   (open a new terminal or: source %s)\n' "$RC_FILE"
}

main "$@"
