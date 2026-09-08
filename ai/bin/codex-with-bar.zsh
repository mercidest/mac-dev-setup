#!/bin/zsh
# Launch interactive Codex with a Claude-style graphical usage bar below it.
# Headless Codex subcommands bypass tmux and call the real binary directly.

setopt no_unset pipe_fail
zmodload zsh/datetime

readonly SELF="${0:A}"
readonly USAGE_BAR="${CODEX_USAGE_BAR:-$HOME/bin/codex-usage}"

find_real_codex() {
  local candidate
  local -a candidates

  candidates=("${(@f)$(whence -a -p codex 2>/dev/null)}")
  candidates+=(
    /opt/homebrew/bin/codex
    /usr/local/bin/codex
    "$HOME/.local/bin/codex"
  )

  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" && -x "$candidate" && "${candidate:A}" != "$SELF" ]] || continue
    print -r -- "$candidate"
    return 0
  done
  return 1
}

readonly REAL_CODEX="${CODEX_REAL_BIN:-$(find_real_codex)}"
if [[ -z "$REAL_CODEX" || ! -x "$REAL_CODEX" ]]; then
  print -u2 "codex: could not find the real Codex CLI binary"
  exit 127
fi

# Internal entry point used for the main pane of a temporary tmux session.
if [[ "${1:-}" == "--codex-bar-inside" ]]; then
  session="$2"
  shift 2
  "$REAL_CODEX" -c 'tui.status_line=[]' "$@"
  result=$?
  tmux kill-session -t "$session" >/dev/null 2>&1 || true
  exit "$result"
fi

# Preserve normal behavior for automation, authentication, diagnostics, and
# other commands that do not open the interactive terminal interface.
case "${1:-}" in
  -h|--help|-V|--version|agents|exec|e|review|login|logout|mcp|plugin|mcp-server|app-server|remote-control|app|completion|update|doctor|sandbox|debug|apply|queue|archive|delete|migrate-rollouts|unarchive|cloud|exec-server|features|help)
    exec "$REAL_CODEX" "$@"
    ;;
esac

if [[ "${CODEX_NO_BAR:-0}" == "1" || ! -t 0 || ! -t 1 || ! -x "$USAGE_BAR" ]] || ! command -v tmux >/dev/null 2>&1; then
  exec "$REAL_CODEX" "$@"
fi

readonly LAUNCHED_AT="$EPOCHREALTIME"
session_cwd="$PWD"
for (( i = 1; i <= $#; i++ )); do
  if [[ "${@[i]}" == "-C" || "${@[i]}" == "--cd" ]]; then
    (( i++ ))
    [[ $i -le $# ]] && session_cwd="${@[i]}"
  elif [[ "${@[i]}" == --cd=* ]]; then
    session_cwd="${@[i]#--cd=}"
  fi
done
watch_command="${(q)USAGE_BAR} --watch 2 --since ${(q)LAUNCHED_AT} --cwd ${(q)session_cwd}"

if [[ -n "${TMUX:-}" ]]; then
  watcher="$(tmux split-window -d -v -l 2 -c "$PWD" -P -F '#{pane_id}' "$watch_command")" || {
    exec "$REAL_CODEX" "$@"
  }
  cleanup_watcher() {
    tmux kill-pane -t "$watcher" >/dev/null 2>&1 || true
  }
  trap cleanup_watcher EXIT HUP TERM
  "$REAL_CODEX" -c 'tui.status_line=[]' "$@"
  result=$?
  trap - EXIT HUP TERM
  cleanup_watcher
  exit "$result"
fi

# Outside tmux, create an isolated one-window session. The top pane runs Codex;
# the two-line bottom pane renders the live gauge. The session removes itself
# when Codex exits.
session="codex-bar-$$-$RANDOM"
command_parts=("$SELF" --codex-bar-inside "$session" "$@")
codex_command="${(j: :)${(q)command_parts[@]}}"

if ! tmux new-session -d -s "$session" -c "$PWD" "$codex_command"; then
  exec "$REAL_CODEX" "$@"
fi
tmux set-option -t "$session" status off
if ! tmux split-window -d -v -l 2 -t "$session":1.1 -c "$PWD" "$watch_command"; then
  tmux kill-session -t "$session" >/dev/null 2>&1 || true
  exec "$REAL_CODEX" "$@"
fi
tmux select-pane -t "$session":1.1
tmux attach-session -t "$session"
