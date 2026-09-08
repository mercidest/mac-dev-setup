# Brewfile — everything the shell, editor, tmux and AI harnesses depend on.
# Installed by install.sh, or by hand:  brew bundle --file=Brewfile
# Heavy optional extras (Anaconda) live in Brewfile.optional.

# --- terminal + fonts ---
cask "iterm2"                        # the terminal this setup is tuned for
cask "font-jetbrains-mono-nerd-font"  # required: the profile's font, with Nerd Font glyphs

# --- editor ---
cask "sublime-text"                  # settings in sublime/, `subl` on PATH via zprofile

# --- zsh: plugin manager + prompt ---
brew "antidote"     # zsh plugin manager, loads ~/.zsh_plugins.txt
brew "pure"         # the prompt (`prompt pure`)
brew "zsh-async"    # pure's dependency

# --- modern CLI tools the aliases in .zshrc point at ---
brew "eza"          # ls
brew "bat"          # cat + man pager
brew "ripgrep"      # grep
brew "fd"           # find, and fzf's file source
brew "fzf"          # Ctrl-T / Alt-C / Ctrl-R fuzzy finding
brew "zoxide"       # `z foo` frecency jump
brew "atuin"        # searchable shell history (Ctrl-R)

# --- languages / runtimes ---
brew "node"         # also provides npm; globals listed in node/npm-global.txt
brew "uv"           # Python project + tool manager — see python/README.md

# --- AI coding harnesses (Claude Code installs via its own script in install.sh) ---
brew "codex"        # OpenAI Codex CLI
brew "opencode"     # OpenCode TUI
brew "codexbar"     # menu-bar usage/limit readout across ~50 providers

# --- misc ---
brew "tmux"         # the status bar + per-session colors in tmux/tmux.conf
brew "jq"           # used by shell helpers and for poking at API responses
brew "gh"           # GitHub CLI, so `gh auth login` works out of the box
brew "git"          # newer than Apple's
