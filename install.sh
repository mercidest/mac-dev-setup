#!/bin/bash
# install.sh — set this Mac up with the same terminal, editor and AI-agent
# environment as the source machine.
#
#   ./install.sh                  everything
#   ./install.sh --no-brew        skip Homebrew installs (tools already present)
#   ./install.sh --no-optional    skip Brewfile.optional (Anaconda, ~1 GB)
#   ./install.sh --only codex     just one section (e.g. Codex CLI + its usage bar)
#   ./install.sh --list           show section names and exit
#
# Sections: brew shell tmux iterm2 sublime python node claude codex pi opencode
#           ("ai" is shorthand for codex + pi + opencode)
#
# Safe to re-run. Anything it replaces is backed up next to the original as
# <file>.backup.<timestamp>. It installs no credentials: you sign in to each
# service yourself at the end.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"
SECTIONS="brew shell tmux iterm2 sublime python node claude codex pi opencode"
DO_OPTIONAL=1
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --no-brew)     SECTIONS="${SECTIONS/brew /}" ;;
    --no-optional) DO_OPTIONAL=0 ;;
    --only)        shift; ONLY="${1:-}"; [ -n "$ONLY" ] || { echo "--only needs a section name" >&2; exit 2; } ;;
    --list)        echo "$SECTIONS" | tr ' ' '\n'; echo 'ai  (= codex pi opencode)'; exit 0 ;;
    -h|--help)     sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)             echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done
if [ -n "$ONLY" ]; then
  ONLY="${ONLY//ai/codex pi opencode}"     # `ai` is shorthand for all three harnesses
  for want in $ONLY; do
    case " brew shell tmux iterm2 sublime python node claude codex pi opencode " in
      *" $want "*) ;;
      *) echo "unknown section: $want" >&2
         echo "known: brew shell tmux iterm2 sublime python node claude codex pi opencode (or: ai)" >&2
         exit 2 ;;
    esac
  done
  SECTIONS="$ONLY"
fi

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '    \033[2m·\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
has()  { case " $SECTIONS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

[ "$(uname -s)" = "Darwin" ] || { echo "This script is macOS-only." >&2; exit 1; }

backup() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    mv "$1" "$1.backup.$STAMP"
    warn "backed up $(basename "$1") → $(basename "$1").backup.$STAMP"
  fi
}

# symlink repo file → home, so `git pull` updates live config
link() {
  local src="$REPO/$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then skip "$(basename "$dst") already linked"; return; fi
  backup "$dst"; mkdir -p "$(dirname "$dst")"; ln -s "$src" "$dst"; ok "$(basename "$dst") → $1"
}

# copy repo file → home, for files the app itself rewrites (which must not
# live inside the git repo, or every settings change dirties the checkout)
copy() {
  local src="$REPO/$1" dst="$2"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then skip "$(basename "$dst") already current"; return; fi
  backup "$dst"; mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; ok "$(basename "$dst") installed"
}

# create ~/.ai-keys.env (empty, chmod 600) — never writes a key
seed_keys_file() {
  if [ -f "$HOME/.ai-keys.env" ]; then
    chmod 600 "$HOME/.ai-keys.env"; skip "~/.ai-keys.env exists (permissions tightened)"
  else
    cp "$REPO/ai/ai-keys.env.example" "$HOME/.ai-keys.env"; chmod 600 "$HOME/.ai-keys.env"
    ok "~/.ai-keys.env created (empty — add your OpenRouter key)"
  fi
}

# ---------------------------------------------------------------- 1. Homebrew
if has brew; then
  say "Homebrew + packages"
  if ! command -v brew >/dev/null; then
    echo "    Homebrew not found — installing it (you'll be asked for your password)."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  brew bundle --file="$REPO/Brewfile"
  ok "Brewfile installed"
  if [ "$DO_OPTIONAL" = 1 ]; then
    brew bundle --file="$REPO/Brewfile.optional"
    ok "Brewfile.optional installed"
  else
    skip "Brewfile.optional skipped (--no-optional)"
  fi
fi
command -v brew >/dev/null && eval "$(/opt/homebrew/bin/brew shellenv)" || true

# ------------------------------------------------------------- 2. zsh + shell
if has shell; then
  say "oh-my-zsh"
  if [ -d "$HOME/.oh-my-zsh" ]; then
    skip "already installed"
  else
    # --unattended + KEEP_ZSHRC: don't launch zsh, don't write a .zshrc — ours follows
    RUNZSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "installed"
  fi

  say "Shell config (zsh)"
  link shell/zshrc            "$HOME/.zshrc"
  link shell/zprofile         "$HOME/.zprofile"
  link shell/zshenv           "$HOME/.zshenv"
  link shell/zsh_plugins.txt  "$HOME/.zsh_plugins.txt"
  link shell/gitignore_global "$HOME/.gitignore_global"
  git config --global core.excludesfile "$HOME/.gitignore_global"
  ok "git core.excludesfile → ~/.gitignore_global"
  if ! git config --global user.name >/dev/null 2>&1; then
    warn "git identity not set — run:"
    warn "  git config --global user.name 'Your Name'"
    warn "  git config --global user.email 'you@example.com'"
  fi
fi

# ------------------------------------------------------------------- 3. tmux
if has tmux; then
  say "tmux"
  link tmux/tmux.conf "$HOME/.tmux.conf"
  mkdir -p "$HOME/bin"
  link tmux/tmux-assign-color.sh "$HOME/bin/tmux-assign-color.sh"
fi

# ----------------------------------------------------------------- 4. iTerm2
if has iterm2; then
  say "iTerm2 profile"
  DP="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  mkdir -p "$DP"
  cp "$REPO/iterm2/profiles/Snazzy-JetBrains.json" "$DP/"
  ok "Snazzy profile installed (iTerm2 picks it up live, no restart)"
  echo "      Set it as default: iTerm2 → Settings → Profiles → Snazzy"
  echo "      → Other Actions… → Set as Default"
fi

# ----------------------------------------------------------- 5. Sublime Text
if has sublime; then
  say "Sublime Text"
  ST="$HOME/Library/Application Support/Sublime Text/Packages/User"
  if [ -d "/Applications/Sublime Text.app" ]; then
    mkdir -p "$ST"
    for f in "$REPO"/sublime/*.sublime-*; do copy "sublime/$(basename "$f")" "$ST/$(basename "$f")"; done
    ok "settings installed — open Sublime once and wait for Package Control"
  else
    warn "Sublime Text not installed; skipping (brew install --cask sublime-text)"
  fi
fi

# ----------------------------------------------------------------- 6. Python
if has python; then
  say "Python"
  copy python/condarc "$HOME/.condarc"
  command -v uv    >/dev/null && ok "uv $(uv --version | awk '{print $2}')"    || warn "uv missing (brew install uv)"
  command -v conda >/dev/null && ok "conda $(conda --version | awk '{print $2}')" || skip "conda not installed (optional)"
  ok "Apple's python3: $(/usr/bin/python3 -V 2>&1) — used by both status bars"
fi

# ------------------------------------------------------------------- 7. Node
if has node; then
  say "Node global packages"
  if command -v npm >/dev/null; then
    while read -r pkg; do
      [ -z "$pkg" ] && continue
      case "$pkg" in \#*) continue ;; esac
      if npm ls -g --depth=0 "$pkg" >/dev/null 2>&1; then skip "$pkg already installed"
      else npm install -g "$pkg" >/dev/null && ok "$pkg"; fi
    done < "$REPO/node/npm-global.txt"
  else
    warn "npm missing (brew install node)"
  fi
fi

# ------------------------------------------------------------- 8. Claude Code
if has claude; then
  say "Claude Code"
  if ! command -v claude >/dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
  fi
  command -v claude >/dev/null && ok "claude $(claude --version 2>/dev/null || echo installed)"
  mkdir -p "$HOME/.claude/skills"
  copy claude/settings.json       "$HOME/.claude/settings.json"
  copy claude/statusline-usage.py "$HOME/.claude/statusline-usage.py"
  chmod +x "$HOME/.claude/statusline-usage.py"
  for s in "$REPO"/claude/skills/*/; do
    src="${s%/}"; name="$(basename "$src")"; dst="$HOME/.claude/skills/$name"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then skip "skill $name already linked"; continue; fi
    backup "$dst"; ln -s "$src" "$dst"; ok "skill $name"
  done
fi

# ----------------------------------------------------- 9. Codex CLI + its bar
if has codex; then
  say "Codex CLI + usage bar"
  if ! command -v codex >/dev/null; then
    if command -v brew >/dev/null; then brew install codex && ok "codex installed"
    else warn "Homebrew missing — install it first, then: brew install codex"; fi
  fi
  command -v codex >/dev/null && ok "codex $(codex --version 2>/dev/null || echo installed)"

  mkdir -p "$HOME/bin"
  cp "$REPO/ai/bin/codex-usage.py" "$HOME/bin/codex-usage"
  chmod +x "$HOME/bin/codex-usage"
  ok "codex-usage → ~/bin/codex-usage"
  case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) warn "~/bin is not on your PATH. Either add it:"
       warn "  echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> ~/.zshrc && exec zsh"
       warn "or just run it by full path: ~/bin/codex-usage" ;;
  esac

  # Codex rewrites config.toml at runtime with machine-specific plugin paths,
  # so seed it only when there is nothing to lose.
  if [ -f "$HOME/.codex/config.toml" ]; then
    skip "~/.codex/config.toml exists — left alone (compare with ai/codex/config.toml)"
  else
    mkdir -p "$HOME/.codex"; cp "$REPO/ai/codex/config.toml" "$HOME/.codex/config.toml"
    ok "~/.codex/config.toml seeded"
  fi
fi

# ------------------------------------------------------------------- 10. Pi
if has pi; then
  say "Pi"
  if command -v npm >/dev/null; then
    command -v pi >/dev/null || npm install -g @earendil-works/pi-coding-agent >/dev/null
    command -v pi >/dev/null && ok "pi $(pi --version 2>/dev/null || echo installed)"
  else
    warn "npm missing (brew install node)"
  fi
  copy ai/pi/models.json "$HOME/.pi/agent/models.json"
  seed_keys_file
fi

# ------------------------------------------------------------- 11. OpenCode
if has opencode; then
  say "OpenCode"
  if ! command -v opencode >/dev/null && command -v brew >/dev/null; then
    brew install opencode && ok "opencode installed"
  fi
  command -v opencode >/dev/null && ok "opencode $(opencode --version 2>/dev/null || echo installed)"
  copy ai/opencode/opencode.jsonc "$HOME/.config/opencode/opencode.jsonc"
  seed_keys_file
fi

if [ -n "$ONLY" ]; then
  say "Done ($ONLY)"
  exit 0
fi

say "Done"
cat <<'NEXT'
    Next, in order:

    1. Open a NEW iTerm2 window (or run: exec zsh) so the shell config loads.
    2. Sign in to the agents you want — each uses YOUR OWN account:
         claude                 → browser sign-in (Claude Pro/Max)
         codex login            → browser sign-in (ChatGPT plan)
         opencode auth login    → OpenCode Zen, or an OpenRouter key
       For pay-per-token models, put an OpenRouter key in ~/.ai-keys.env
       (see ai/README.md — set a spend limit on the key).
    3. iTerm2 → Settings → Profiles → Snazzy → Other Actions… → Set as Default.
    4. Open Sublime Text once and wait for Package Control to fetch its packages.
    5. Set your git identity if the installer warned about it.

    Check the fonts:  echo -e " "      two glyphs, no boxes.
    Check Codex bar:  usage
NEXT
