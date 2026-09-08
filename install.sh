#!/bin/bash
# install.sh — set this Mac up with the same terminal + Claude Code environment.
#
#   ./install.sh              # everything
#   ./install.sh --no-brew    # skip Homebrew installs (tools already present)
#   ./install.sh --claude     # only the Claude Code config
#
# Safe to re-run. Anything it replaces is backed up next to the original as
# <file>.backup.<timestamp>. It never touches your Claude account or logins:
# you sign in yourself with `claude` afterwards.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"
DO_BREW=1
ONLY_CLAUDE=0

for arg in "$@"; do
  case "$arg" in
    --no-brew) DO_BREW=0 ;;
    --claude)  ONLY_CLAUDE=1; DO_BREW=0 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '    \033[2m·\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }

[ "$(uname -s)" = "Darwin" ] || { echo "This script is macOS-only." >&2; exit 1; }

# back up $1 if it exists and is not already the symlink we want
backup() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mv "$target" "$target.backup.$STAMP"
    warn "backed up $(basename "$target") → $(basename "$target").backup.$STAMP"
  fi
}

# symlink $1 (in repo) to $2 (in home), backing up whatever is there
link() {
  local src="$REPO/$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    skip "$(basename "$dst") already linked"; return
  fi
  backup "$dst"
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "$(basename "$dst") → $1"
}

# copy $1 (in repo) to $2, backing up whatever is there. Used for files the app
# itself rewrites, which must not live inside the git repo.
copy() {
  local src="$REPO/$1" dst="$2"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then skip "$(basename "$dst") already current"; return; fi
  backup "$dst"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  ok "$(basename "$dst") installed"
}

# ---------------------------------------------------------------- 1. Homebrew
if [ "$DO_BREW" = 1 ]; then
  say "Homebrew + packages"
  if ! command -v brew >/dev/null; then
    echo "    Homebrew not found — installing it (you'll be asked for your password)."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  brew bundle --file="$REPO/Brewfile"
  ok "Brewfile installed"
fi

# ------------------------------------------------------------- 2. oh-my-zsh
if [ "$ONLY_CLAUDE" = 0 ]; then
  say "oh-my-zsh"
  if [ -d "$HOME/.oh-my-zsh" ]; then
    skip "already installed"
  else
    # --unattended: don't run zsh or overwrite .zshrc; we install our own next.
    RUNZSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "installed"
  fi

  # ------------------------------------------------------------ 3. shell files
  say "Shell config (zsh)"
  link shell/zshrc           "$HOME/.zshrc"
  link shell/zprofile        "$HOME/.zprofile"
  link shell/zshenv          "$HOME/.zshenv"
  link shell/zsh_plugins.txt "$HOME/.zsh_plugins.txt"
  link shell/gitignore_global "$HOME/.gitignore_global"
  git config --global core.excludesfile "$HOME/.gitignore_global"
  ok "git core.excludesfile pointed at ~/.gitignore_global"
  if ! git config --global user.name >/dev/null 2>&1; then
    warn "git identity not set — run: git config --global user.name 'Your Name'"
    warn "                            git config --global user.email 'you@example.com'"
  fi

  # ------------------------------------------------------------------ 4. tmux
  say "tmux"
  link tmux/tmux.conf "$HOME/.tmux.conf"
  mkdir -p "$HOME/bin"
  link tmux/tmux-assign-color.sh "$HOME/bin/tmux-assign-color.sh"

  # ---------------------------------------------------------------- 5. iTerm2
  say "iTerm2 profile"
  DP="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  mkdir -p "$DP"
  cp "$REPO/iterm2/profiles/Snazzy-JetBrains.json" "$DP/"
  ok "Snazzy profile installed (iTerm2 picks it up live, no restart)"
  echo "      Make it the default: iTerm2 → Settings → Profiles → Snazzy"
  echo "      → Other Actions… → Set as Default"
fi

# ------------------------------------------------------------- 6. Claude Code
say "Claude Code"
if ! command -v claude >/dev/null; then
  echo "    Installing Claude Code…"
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v claude >/dev/null && ok "claude: $(claude --version 2>/dev/null || echo installed)"

mkdir -p "$HOME/.claude/skills"
copy claude/settings.json        "$HOME/.claude/settings.json"
copy claude/statusline-usage.py  "$HOME/.claude/statusline-usage.py"
chmod +x "$HOME/.claude/statusline-usage.py"
for s in "$REPO"/claude/skills/*/; do
  src="${s%/}"
  name="$(basename "$src")"
  dst="$HOME/.claude/skills/$name"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then skip "skill $name already linked"; continue; fi
  backup "$dst"
  ln -s "$src" "$dst"
  ok "skill $name"
done

say "Done"
cat <<'NEXT'
    Next steps, in order:

    1. Open a NEW iTerm2 window (or run: exec zsh) so the shell config loads.
    2. Run `claude` and sign in with YOUR OWN Claude account.
       Nothing in this repo carries anyone else's login.
    3. In iTerm2: Settings → Profiles → Snazzy → Other Actions… → Set as Default.
    4. Sanity check the fonts:  echo -e " "
       Two glyphs, no empty boxes = the Nerd Font is installed correctly.

    The Claude plugin marketplaces (karpathy + mattpocock skills) install
    themselves the first time you run `claude`.
NEXT
