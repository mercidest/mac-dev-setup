#!/bin/bash
# bootstrap.sh — the zero-to-configured entry point for a brand-new Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/mercidest/mac-dev-setup/main/bootstrap.sh | bash
#
# Installs the Xcode command line tools (for git) if missing, clones this repo
# to ~/mac-dev-setup, and hands over to install.sh. Everything it does is
# re-runnable; a repo that is already cloned is updated with `git pull`.
set -euo pipefail

REPO_URL="https://github.com/mercidest/mac-dev-setup.git"
DEST="${MAC_DEV_SETUP_DIR:-$HOME/mac-dev-setup}"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[ "$(uname -s)" = "Darwin" ] || { echo "macOS only." >&2; exit 1; }

if ! xcode-select -p >/dev/null 2>&1; then
  say "Installing Xcode command line tools"
  echo "    A dialog will open. Click Install, wait for it to finish, then re-run this."
  xcode-select --install || true
  exit 1
fi

if [ -d "$DEST/.git" ]; then
  say "Updating $DEST"
  git -C "$DEST" pull --ff-only
else
  say "Cloning into $DEST"
  git clone "$REPO_URL" "$DEST"
fi

say "Running the installer"
exec "$DEST/install.sh" "$@"
