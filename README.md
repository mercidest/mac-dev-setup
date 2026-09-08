# mac-dev-setup

A complete developer environment for a fresh Mac — terminal, editor, toolchains
and five AI coding agents — reproducible from this repo alone. Built for
**macOS on Apple Silicon**.

## Install

One command, on a machine with nothing on it:

```sh
curl -fsSL https://raw.githubusercontent.com/mercidest/mac-dev-setup/main/bootstrap.sh | bash
```

That installs the Xcode command line tools if needed, clones this repo to
`~/mac-dev-setup`, and runs the installer. Or do it by hand:

```sh
git clone https://github.com/mercidest/mac-dev-setup.git
cd mac-dev-setup
./install.sh
```

### Or let an AI agent do it

If you already have a coding agent on the machine, point it at this repo and it
will follow [`AGENTS.md`](AGENTS.md) — a runbook written for exactly that:

> Set up this Mac from https://github.com/mercidest/mac-dev-setup — follow AGENTS.md.

`AGENTS.md` is read by Codex CLI and OpenCode; Claude Code reads the same file
through `CLAUDE.md`. It tells the agent to run `install.sh` rather than improvise,
and lists what it must leave to you (every sign-in, every key).

Re-running is safe. Anything replaced is backed up as `<file>.backup.<timestamp>`.

> **No credentials are in this repo.** You sign in to each service with your own
> account afterwards. Nothing here is shared logins.

---

## What you get

| | |
|---|---|
| **Terminal** | iTerm2, Snazzy (`#282A36`), JetBrainsMono Nerd Font 15 |
| **Shell** | zsh + oh-my-zsh + antidote + Pure prompt, autosuggestions, syntax highlighting |
| **CLI tools** | `eza` `bat` `ripgrep` `fd` `fzf` `zoxide` `atuin`, aliased over `ls`/`cat`/`grep`/`find` |
| **Multiplexer** | tmux with a Tokyo-Night bar, `Ctrl-Space` prefix, a unique color per session |
| **Editor** | Sublime Text 4 — Material Theme, rulers, linting, `subl` on PATH |
| **Python** | `uv` for projects, Anaconda optional, and the rule for which of the three Pythons to use |
| **Node** | Homebrew node + `pnpm`, global packages from a list |
| **AI agents** | Claude Code, Codex CLI, Pi, OpenCode, Gemini CLI |
| **Usage bars** | Claude Code's statusline, plus `codex-usage` — the equivalent Codex is missing |

## Layout

```
mac-dev-setup/
├── bootstrap.sh       curl | bash entry point
├── install.sh         the installer (sections are --only-selectable)
├── AGENTS.md          runbook for an AI agent doing the setup (= CLAUDE.md)
├── Brewfile[.optional] every dependency; optional = Anaconda (~1 GB)
├── claude/            Claude Code settings, statusline, skills
├── ai/                Codex, Pi, OpenCode, OpenRouter + the codex-usage bar
├── shell/             zshrc, zprofile, zshenv, zsh_plugins.txt, gitignore_global
├── sublime/           Sublime Text user settings
├── python/            conda config + which-Python-to-use guide
├── node/              global package list
├── tmux/              tmux.conf + per-session color script
└── iterm2/            color presets and the Snazzy dynamic profile
```

`shell/`, `tmux/` and `claude/skills/` are **symlinked** into your home directory,
so `git pull` updates your live config. App-managed files (`claude/settings.json`,
the statusline, Sublime and OpenCode settings) are **copied**, because those apps
rewrite their own files and symlinks would dirty this checkout on every change.

### Partial installs

```sh
./install.sh --list                 # brew shell tmux iterm2 sublime python node claude ai
./install.sh --only claude          # one section
./install.sh --no-optional          # skip Anaconda
./install.sh --no-brew              # tools already installed
```

---

## Daily driving it

### Usage bars

Claude Code shows its own statusline:

```
[Opus 5]  ~/dev/project   ctx ████░░░░░░ 38%   5h ██░░░░░░░░ 21%   7d █████░░░░░ 47%
```

**Codex CLI has no statusline**, so this repo adds one — `usage` (or `codex-usage`):

```
[gpt-5.6-terra]  ctx ████░░░░░░ 35%  5h ██░░░░░░░░ 18% (1h)  7d █████████░ 86% (52h)
```

It reads Codex's own session files, so it needs no API key and makes no network
call. `--watch 5` redraws it in a spare pane; `--plain` suits the tmux status bar.
For a menu-bar readout across all providers at once, `codexbar` is installed too.
Details and the tmux snippet: [`ai/README.md`](ai/README.md).

### Shell

| Command | Does |
|---|---|
| `z <part-of-name>` | Jump to the directory you use most matching that (`zi` to pick) |
| `Ctrl-R` | Fuzzy-search all shell history (atuin) |
| `Ctrl-T` / `Alt-C` | Fuzzy-pick a file / cd into a directory (fzf) |
| `ll` `la` `lt` | Long / all / tree listing with git status and icons |
| `usage` | The Codex context + limit bar |
| `reload` | Restart the shell after editing `.zshrc` |

`cat`, `grep`, `find` are aliased to `bat`, `rg`, `fd`. For the real one: `\cat`.

### tmux

Prefix is **`Ctrl-Space`**, not `Ctrl-b`.

| Command | Does |
|---|---|
| `ts <name>` | Attach to session `<name>`, creating it if needed |
| `cs <name>` | New session named `<name>` running `claude` |
| `tl` / `tk <name>` | List sessions / kill one (name required, so a typo can't wipe everything) |
| `prefix + \|` `-` | Split, keeping the current directory |
| `prefix + s` / `r` | Session switcher / reload config |

---

## If something looks wrong

**Boxes (□) instead of icons** — `brew install --cask font-jetbrains-mono-nerd-font`,
then iTerm2 → Settings → Profiles → Text → *JetBrainsMono Nerd Font Mono 15*.

**iTerm2 profile missing** — check
`~/Library/Application Support/iTerm2/DynamicProfiles/Snazzy-JetBrains.json` exists,
then Settings → Profiles → Snazzy → Other Actions… → Set as Default. Prefer only the
colors? Import `iterm2/Snazzy.itermcolors` under Colors → Color Presets… → Import…

**Statusline blank** — it needs Apple's Python. Test:
`echo '{}' | /usr/bin/python3 ~/.claude/statusline-usage.py`. See [`python/README.md`](python/README.md).

**`codex-usage` says "no sessions yet"** — Codex hasn't run. Start `codex` once.

**Sublime looks unthemed** — Package Control is still fetching. Open it, wait,
restart. See [`sublime/README.md`](sublime/README.md).

**`prompt pure` errors** — `brew install pure zsh-async`, then `reload`.

**Want your old setup back** — everything replaced is beside it as
`.backup.<timestamp>`. Move it back and `reload`.

## Deliberately not included

Personal or machine-specific, and would break elsewhere: SSH config and keys,
Tailscale/VPN membership, home-server access, private repos, hooks bound to
local-only binaries, and permission allowlists containing LAN addresses. Secrets
belong in a password manager; `~/.ai-keys.env` stays outside this repo and is
git-ignored.
