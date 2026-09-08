# mac-dev-setup

My terminal + Claude Code environment, packaged so a fresh Mac ends up looking and
behaving the same. Built for **macOS on Apple Silicon** with **iTerm2**.

```sh
git clone https://github.com/mercidest/mac-dev-setup.git
cd mac-dev-setup
./install.sh
```

Re-runnable. Anything it replaces is backed up next to the original as
`<file>.backup.<timestamp>`.

> **It contains no logins, tokens or keys.** After installing, you run `claude` and
> sign in with **your own** Claude account. Same for `gh auth login` and your git
> identity. Nothing here is shared credentials.

---

## What you get

| Piece | What it is |
|---|---|
| **Claude Code statusline** | A live bar for context window, 5-hour and 7-day plan usage — the numbers `/usage` shows, always on screen |
| **Claude Code settings** | `auto` theme, fullscreen TUI, `high` effort, two skill marketplaces auto-installed |
| **Claude Code skills** | `commit`, `pr`, `fix-tests`, `new-skill` — plus Karpathy's and Matt Pocock's skill packs from GitHub |
| **iTerm2** | Snazzy colors (`#282A36`) + JetBrainsMono Nerd Font 15, as a drop-in profile |
| **zsh** | oh-my-zsh + antidote + the Pure prompt, autosuggestions, syntax highlighting |
| **CLI tools** | `eza`, `bat`, `ripgrep`, `fd`, `fzf`, `zoxide`, `atuin` — aliased over `ls`/`cat`/`grep`/`find` |
| **tmux** | Tokyo-Night status bar, `Ctrl-Space` prefix, and a unique color per session |

## Layout

```
mac-dev-setup/
├── install.sh        the one command that does everything
├── Brewfile          every dependency, installed by `brew bundle`
├── claude/           settings.json, statusline-usage.py, skills/
├── shell/            zshrc, zprofile, zshenv, zsh_plugins.txt, gitignore_global
├── tmux/             tmux.conf + the per-session color script
└── iterm2/           color presets and the Snazzy dynamic profile
```

`shell/`, `tmux/` and `claude/skills/` are **symlinked** into your home directory, so
`git pull` updates your live config. `claude/settings.json` and the statusline are
**copied**, because Claude Code rewrites them as you change settings — copies keep your
personal tweaks out of this repo's git history.

## Installing only part of it

```sh
./install.sh --claude     # only the Claude Code config (statusline, settings, skills)
./install.sh --no-brew    # skip Homebrew if you already have the tools
```

---

## Daily driving it

### Claude Code

The statusline reads:

```
[Opus 5]  ~/dev/project   ctx ████░░░░░░ 38%   5h ██░░░░░░░░ 21%   7d █████░░░░░ 47%
```

`ctx` is the context window for this session; `5h` and `7d` are your plan's rate limits.
Each bar turns red past 80%. The 5h/7d numbers only appear after the first response in a
session — Claude has to receive them from the server first.

### Shell

| Command | Does |
|---|---|
| `z <part-of-dir-name>` | Jump to the directory you use most matching that. `zi` to pick interactively |
| `Ctrl-R` | Fuzzy-search your whole shell history (atuin) |
| `Ctrl-T` / `Alt-C` | Fuzzy-pick a file / cd into a directory (fzf) |
| `ll`, `la`, `lt` | Long / all / tree listing with git status and icons (eza) |
| `reload` | Restart the shell after editing `.zshrc` |

`cat`, `grep` and `find` are aliased to `bat`, `rg` and `fd`. If a script needs the real
one, call it as `\cat` or `/usr/bin/grep`.

### tmux

The prefix is **`Ctrl-Space`**, not `Ctrl-b`.

| Command | Does |
|---|---|
| `ts <name>` | Attach to session `<name>`, creating it if needed |
| `cs <name>` | New session named `<name>` running `claude` |
| `tl` | List sessions with their assigned color |
| `tk <name>` | Kill a session — the name is required on purpose, so a typo can't wipe everything |
| `prefix + \|` / `prefix + -` | Split vertically / horizontally, keeping the current directory |
| `prefix + s` | Session switcher |
| `prefix + r` | Reload `~/.tmux.conf` |

Every session gets its own status-bar color automatically, so you can tell at a glance
which one you're in.

---

## If something looks wrong

**Boxes (□) instead of icons** — the Nerd Font didn't install or isn't selected.
Run `brew install --cask font-jetbrains-mono-nerd-font`, then iTerm2 → Settings →
Profiles → Text → Font → *JetBrainsMono Nerd Font Mono 15*.

**Colors look wrong / the profile didn't appear** — iTerm2 loads dynamic profiles live,
but only from the right folder. Check that
`~/Library/Application Support/iTerm2/DynamicProfiles/Snazzy-JetBrains.json` exists, then
set it as default under Settings → Profiles → Other Actions…

**Prefer not to add a profile at all?** Import just the colors instead: iTerm2 → Settings
→ Profiles → Colors → Color Presets… → Import… → `iterm2/Snazzy.itermcolors`
(`Material-Theme.itermcolors` is an alternative palette; its profile needs Operator Mono,
which isn't on Homebrew).

**The statusline is blank** — it needs Apple's Python, which is preinstalled at
`/usr/bin/python3`. Test it directly:
`echo '{}' | /usr/bin/python3 ~/.claude/statusline-usage.py`

**`prompt pure` errors on shell startup** — `brew install pure zsh-async`, then `reload`.

**Want your old setup back** — every file the installer replaced is sitting next to it as
`.backup.<timestamp>`. Move it back and `reload`.

## Deliberately not included

Machine-specific or personal, and would only break on another Mac: SSH config and keys,
the `moshi-hook` Claude Code hooks, `settings.local.json` permission allowlists (they
contain LAN addresses), and skills that talk to my own servers and vaults. Secrets live in
1Password and never on disk.
