# Brewfile — everything the shell, tmux and Claude Code setup depends on.
# Install with:  brew bundle --file=Brewfile

# --- terminal + editor ---
cask "iterm2"                          # the terminal this setup is tuned for
cask "font-jetbrains-mono-nerd-font"    # required: the profile's font, with Nerd Font glyphs

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

# --- misc ---
brew "tmux"         # the status bar + per-session colors in tmux/tmux.conf
brew "jq"           # used by shell helpers and Claude Code hooks
brew "gh"           # GitHub CLI, so `gh auth login` works out of the box
