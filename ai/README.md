# AI harnesses

Five terminal coding agents, plus the usage bars for them. Everything here is
installed by `../install.sh`; this file explains what each one is and how to sign in.

| Harness | Install | Sign in | Billing |
|---|---|---|---|
| **Claude Code** | `curl -fsSL https://claude.ai/install.sh \| bash` | `claude` → browser | Your Claude Pro/Max plan |
| **Codex CLI** | `brew install --cask codex` | `codex login` → browser | Your ChatGPT plan |
| **Pi** | `npm i -g @earendil-works/pi-coding-agent` | key in `~/.ai-keys.env` | Pay-per-token via OpenRouter |
| **OpenCode** | `brew install opencode` | `opencode auth login` | OpenCode Zen, or OpenRouter |
| **Gemini CLI** | `npm i -g @google/gemini-cli` | `gemini` → browser | Google account free tier |

None of these ship credentials in this repo. Each one logs into **your own** account.

---

## OpenRouter — one key, every model

OpenRouter is a single API in front of ~400 models (Anthropic, OpenAI, DeepSeek,
Qwen, Z.ai, Moonshot…). Pi and OpenCode both talk to it, so one key covers both.

1. Sign up at <https://openrouter.ai>, then create a key at
   <https://openrouter.ai/settings/keys>.
2. **Set a monthly spend limit on the key while you are on that page.** It is
   pay-per-token with no plan ceiling — a runaway agent loop bills real money.
3. Put it in your keys file:
   ```sh
   cp ai/ai-keys.env.example ~/.ai-keys.env
   $EDITOR ~/.ai-keys.env        # paste the key after OPENROUTER_API_KEY=
   chmod 600 ~/.ai-keys.env
   exec zsh                      # .zshrc sources it
   ```
4. Check it works and see your credit balance:
   ```sh
   curl -s https://openrouter.ai/api/v1/auth/key \
     -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq
   ```

`~/.ai-keys.env` is deliberately outside this repo and in `.gitignore`. Neither
`pi/models.json` nor `opencode/opencode.jsonc` contains a key — both read it
indirectly, so the config files stay safe to commit.

### Costs, roughly

Prices in `pi/models.json` were read from the live OpenRouter catalogue the day
it was generated, per million tokens. The spread is enormous — GLM 5.3 Flash is
**~60× cheaper** than Claude Opus 5 on input. Start on a cheap model and escalate
only when the task actually needs it.

## Pi

A minimal, scriptable coding agent — good for non-interactive runs, since it
emits JSONL you can parse.

```sh
npm i -g @earendil-works/pi-coding-agent
pi                              # interactive
pi --help                       # flags, including JSONL output
```

`pi/models.json` → `~/.pi/agent/models.json` defines which OpenRouter models it
offers. Edit that list freely; re-check ids against <https://openrouter.ai/models>
because OpenRouter retires models without notice.

## OpenCode

```sh
brew install opencode
opencode auth login             # OpenCode Zen (its own plan), or paste an OpenRouter key
opencode                        # TUI
```

`opencode/opencode.jsonc` → `~/.config/opencode/opencode.jsonc` adds OpenRouter as
a second provider alongside whatever you log into.

---

## Usage bars

Claude Code renders its own statusline (`../claude/statusline-usage.py`) showing
context window plus 5-hour and 7-day plan limits. Current Codex CLI releases can
show the same information in their native status line; this repo also includes a
graphical standalone bar for shells and tmux.

Want only this, on a machine you are not otherwise reconfiguring?

```sh
./install.sh --only codex
```

That installs the Codex CLI (via Homebrew, if missing), writes `~/bin/codex-usage`,
and seeds `~/.codex/config.toml` only if you don't already have one. It installs
no other harness and does not change shell config.

### 1. Native Codex status line — always visible in a session

The seeded config enables these items:

```toml
[tui]
status_line = ["model-with-reasoning", "current-dir", "context-remaining", "five-hour-limit", "weekly-limit"]
status_line_use_colors = true
```

Example:

```
gpt-5.6-sol high · ~/project · Context 82% left · 5h 95% left · weekly 99% left
```

Codex omits a limit until that value is available. If `~/.codex/config.toml`
already existed when the installer ran, it is deliberately preserved; open
Codex and run `/statusline` to select Context remaining, 5-hour limit, and
Weekly limit interactively.

### 2. `codex-usage` — graphical bars outside Codex

`bin/codex-usage.py`, installed as `codex-usage` in `~/bin`:

```
$ codex-usage
[gpt-5.6-terra]  ctx ████░░░░░░ 35%  5h ██░░░░░░░░ 18% (1h)  7d █████████░ 86% (52h)
```

It reads the numbers straight out of the session file Codex is already writing
(`~/.codex/sessions/**/rollout-*.jsonl`, the `token_count` events) — no network
call, no scraping, no API key. Bars turn red past 80%.

```sh
codex-usage                # once
codex-usage --watch 5      # redraw every 5s in a spare pane
codex-usage --plain        # no ANSI, for tmux or logging
codex-usage --json         # raw numbers for scripting
```

Caveats worth knowing: it reports the **most recently written** session, so with
two Codex windows open you see whichever answered last. Rate-limit bars appear only
after Codex has received limits from the server — early in a session you get the
context bar alone. If a session predates the fields, you'll see `idle`.

To keep it in the tmux status bar, add to `~/.tmux.conf`:

```tmux
set -g status-interval 15
set -ag status-right '#[fg=#7aa2f7]#(~/bin/codex-usage --plain)#[default] '
```

### 3. CodexBar — a menu-bar readout for everything at once

`brew install codexbar` (in the Brewfile) puts a live usage readout in the macOS
menu bar and covers ~50 providers, Codex, Claude, OpenCode and OpenRouter included.

```sh
codexbar usage --provider all --format json --pretty
codexbar usage --provider openrouter          # credits remaining
```

Its per-provider fetchers depend on being logged in to each service and on those
services' dashboards, so individual providers can return errors while others work.
That is why `codex-usage` remains as an offline fallback for Codex.
