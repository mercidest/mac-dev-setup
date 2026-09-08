# Agent runbook

You are an AI coding agent asked to set up a **new Mac** from this repository.
This file is the contract: follow it top to bottom. It is the same for every
harness — Claude Code reads it via `CLAUDE.md`, Codex CLI and OpenCode read
`AGENTS.md` directly.

## What the user wants

A machine that matches the source Mac: iTerm2 + zsh + tmux + Sublime Text +
Python/Node toolchains + several AI coding agents, all signed in to **the user's
own accounts**.

## Rules — read before doing anything

1. **`./install.sh` does the work. Do not reimplement it.** Your job is to run
   it, read its output, and fix what it reports. Do not hand-write `brew install`
   sequences or `cp` commands that duplicate what the script already does.
2. **Never ask for, generate, echo, or store a credential.** No API keys, no
   passwords, no tokens. Sign-in is interactive and the *user* does it. If a step
   needs a browser login, stop and tell them to run that command themselves.
3. **Never commit `~/.ai-keys.env`** or paste its contents anywhere, including
   into your own reasoning output.
4. **`sudo` only where Homebrew's own installer asks for it.** Nothing else here
   needs root. If a command seems to need `sudo`, stop and ask.
5. **Do not delete or overwrite the user's existing files yourself.** `install.sh`
   backs up everything it touches as `<file>.backup.<timestamp>`. Preserve those.
6. **Report honestly.** If a section fails, say so and show the error. Do not
   claim the machine is configured when a step was skipped.

## Sequence

```sh
# 1. Verify you are on the right kind of machine
uname -s          # must be Darwin
uname -m          # arm64 expected; on x86_64 Homebrew lives in /usr/local, warn the user

# 2. Run the installer. It is idempotent — re-run it freely.
./install.sh

#    Variants, if the user asks:
./install.sh --no-optional      # skip Anaconda (~1 GB)
./install.sh --only claude      # one section: brew shell tmux iterm2 sublime python node claude ai
./install.sh --list             # section names
```

Then verify, and report the result of each line:

```sh
zsh -lic 'echo OK'                       # shell config loads without errors
command -v claude codex opencode pi      # harnesses on PATH
/usr/bin/python3 ~/.claude/statusline-usage.py </dev/null   # Claude statusline renders
codex-usage                              # Codex usage bar renders
ls ~/Library/Application\ Support/iTerm2/DynamicProfiles/   # Snazzy profile present
tmux -f ~/.tmux.conf new -d -s smoke \; kill-session -t smoke  # tmux config parses
```

## What you must leave to the user

These are interactive, involve the user's identity, and are **not** yours to do:

| Step | Command the user runs |
|---|---|
| Claude Code sign-in | `claude` |
| Codex sign-in | `codex login` |
| OpenCode sign-in | `opencode auth login` |
| OpenRouter key | Create at <https://openrouter.ai/settings/keys>, paste into `~/.ai-keys.env`, `chmod 600` |
| git identity | `git config --global user.name` / `user.email` |
| Default iTerm2 profile | Settings → Profiles → Snazzy → Other Actions… → Set as Default |
| Sublime packages | Open Sublime once; Package Control fetches them |

Tell the user these remain, as a short checklist, when you finish.

## Known failure modes and their fixes

| Symptom | Cause | Fix |
|---|---|---|
| `brew: command not found` after install | Homebrew not on PATH in this shell | `eval "$(/opt/homebrew/bin/brew shellenv)"` |
| Boxes instead of icons | Nerd Font missing or not selected | `brew install --cask font-jetbrains-mono-nerd-font`, then set the font in iTerm2 |
| `prompt pure` not found | `pure`/`zsh-async` missing | `brew install pure zsh-async` |
| Statusline blank in Claude Code | Wrong Python | It must be `/usr/bin/python3`; see `python/README.md` |
| `codex-usage` says "no sessions yet" | Codex has never run | Run `codex` once; this is not an error |
| Sublime looks unthemed | Package Control hasn't run | Open Sublime, wait, restart it |
| Homebrew at `/usr/local` not `/opt/homebrew` | Intel Mac | Paths in `shell/zprofile` assume Apple Silicon; tell the user rather than silently editing |

## Repo map

| Path | Contents |
|---|---|
| `install.sh` | The installer. Sections are `--only`-selectable. |
| `bootstrap.sh` | `curl \| bash` entry point: clones this repo, then runs `install.sh`. |
| `Brewfile`, `Brewfile.optional` | Every dependency. Optional = Anaconda. |
| `claude/` | Claude Code settings, statusline, skills. |
| `ai/` | Codex, Pi, OpenCode, OpenRouter configs + `codex-usage` bar. |
| `shell/`, `tmux/`, `iterm2/`, `sublime/` | Dotfiles and app config. |
| `python/`, `node/` | Toolchain notes and package lists. |

`shell/`, `tmux/` and `claude/skills/` are **symlinked** into `$HOME`, so editing
them here changes the live config. `claude/settings.json`, the statusline and the
app configs are **copied**, because those apps rewrite their own files.

## Out of scope

Do not add the user's personal infrastructure to this machine: SSH keys, VPN or
Tailscale membership, home-server access, private repos, or password-manager
vaults. This repo is deliberately limited to a portable developer environment.
