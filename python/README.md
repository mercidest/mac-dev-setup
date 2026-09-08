# Python

Three Pythons coexist on a Mac set up this way. Picking the wrong one is the most
common source of confusion here, so the rule is worth learning once.

| Python | Path | Use it for |
|---|---|---|
| **Apple's** | `/usr/bin/python3` | Anything that reads other apps' data, or that a background job runs |
| **Homebrew** | `/opt/homebrew/bin/python3` | General 3.14 scripting that never touches app data |
| **Anaconda** | `/opt/homebrew/anaconda3/bin/python` | Data science: numpy, pandas, notebooks |
| **uv** | per-project `.venv` | Project dependencies — the default for anything real |

## The macOS privacy-prompt rule

Homebrew's `python@3.14` is only ad-hoc signed, so macOS **cannot persist a privacy
grant for it**. Every new Homebrew-python process that reads another app's data
re-triggers the *"…would like to access data from other apps"* dialog. Affected
locations include Mail, Chrome, Things, iCloud/Obsidian containers,
`~/Library/Application Support/<app>`, `~/Library/Containers` and `Group Containers`.

So:

- **Use `/usr/bin/python3`** for any script that touches app data or serves local
  files. Apple's Python is properly signed and its Full Disk Access grant sticks.
- **Never launch a long-running server** with a bare `python3` from a scratch
  directory — that is the usual culprit.
- The status-line scripts in this repo (`claude/statusline-usage.py`,
  `ai/bin/codex-usage.py`) both hardcode `#!/usr/bin/python3` for exactly this reason.

## Per-project environments — use uv

`uv` is installed by the Brewfile and is the right default. It is much faster than
`venv` + `pip` and manages the interpreter too.

```sh
uv init myproject && cd myproject
uv add pandas requests        # resolves, locks and installs
uv run script.py              # runs inside the project env, no activate needed
uv python install 3.11        # a specific interpreter, if a project needs one
```

Standalone CLI tools go in uv's tool space, not in a project:

```sh
uv tool install <tool>        # like pipx
uv tool list
```

## Anaconda

The `anaconda` cask installs to `/opt/homebrew/anaconda3`. `.zshrc` puts it on
`PATH` when present, without running `conda init` — that keeps shell startup fast
and stops conda hijacking every new shell with a `(base)` prefix.

```sh
conda create -n ds python=3.12 numpy pandas matplotlib jupyter
conda activate ds
conda env list
conda env export -n ds > environment.yml    # to reproduce it elsewhere
```

`condarc` here → `~/.condarc` pins the `defaults` channel. If you want
conda-forge, add it there rather than passing `-c conda-forge` every time.

> Reach for conda only when a package genuinely needs it (compiled scientific
> stacks, R interop). For everything else `uv` is faster and less invasive.
