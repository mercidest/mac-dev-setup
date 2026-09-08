#!/bin/bash
# tmux-assign-color.sh
# Give every tmux session a unique status color (@scolor).
#
# A color counts as "in use" only while its session is alive, so killing a
# session automatically returns its color to the random pool. Idempotent:
# only sessions that lack @scolor get a new one. Invoked by the
# `session-created` hook in ~/.tmux.conf; also safe to run by hand.
#
# Stays bash-3.2 compatible (stock macOS /bin/bash) -> no associative arrays.

set -uo pipefail
TMUX_BIN="${TMUX_BIN:-/opt/homebrew/bin/tmux}"
[ -x "$TMUX_BIN" ] || TMUX_BIN=tmux

# Serialize concurrent runs: the session-created/client-attached hooks can fire
# several invocations at once, which would otherwise read the same "free" pool
# and hand out duplicate colors. mkdir is atomic, so it makes a simple mutex.
LOCKDIR="${TMPDIR:-/tmp}/tmux-assign-color.lock"
# Clear a stale lock from a crashed run (older than ~10s).
if [ -d "$LOCKDIR" ]; then
  if [ -n "$(find "$LOCKDIR" -prune -mmin +0.16 2>/dev/null)" ]; then rmdir "$LOCKDIR" 2>/dev/null; fi
fi
i=0
while ! mkdir "$LOCKDIR" 2>/dev/null; do
  i=$((i + 1)); [ "$i" -gt 100 ] && break   # ~5s ceiling, then proceed anyway
  sleep 0.05
done
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

# Distinct, truecolor-friendly palette (Tokyo Night-ish).
# Well-separated hues so any two live sessions look clearly different.
# (Green #9ece6a is intentionally NOT here — it's reserved for window text.)
PALETTE=( '#f7768e' '#ff9e64' '#e0af68' '#7dcfff' \
          '#7aa2f7' '#bb9af7' '#c678dd' )

# Optional: pin a color to a known session name (must be a palette value).
# Used only if that color is still free; otherwise the name gets a random one.
preferred_for() {
  case "$1" in
    rym)      echo '#f7768e' ;;
    wise-lms) echo '#e0af68' ;;
    openclaw) echo '#ff9e64' ;;
    research) echo '#7dcfff' ;;
    content)  echo '#7aa2f7' ;;
    scout)    echo '#bb9af7' ;;
  esac
}

# Space-padded string of colors currently claimed by live sessions.
USED=" $($TMUX_BIN list-sessions -F '#{@scolor}' 2>/dev/null | tr '\n' ' ') "
is_used() { case "$USED" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

pick_color() {  # $1 = session name -> prints a hex color
  local name="$1" c pref free h
  pref=$(preferred_for "$name")
  if [ -n "$pref" ] && ! is_used "$pref"; then echo "$pref"; return; fi
  free=()
  for c in "${PALETTE[@]}"; do is_used "$c" || free+=("$c"); done
  if [ ${#free[@]} -gt 0 ]; then echo "${free[RANDOM % ${#free[@]}]}"; return; fi
  # Pool exhausted (>12 live sessions): deterministic fallback by name hash.
  h=$(cksum <<<"$name" | cut -d' ' -f1)
  echo "${PALETTE[h % ${#PALETTE[@]}]}"
}

# Assign a color to any session that doesn't have one yet.
# Process substitution (not a pipe) keeps USED updates in this shell, so
# several uncolored sessions in one run still get distinct colors.
while IFS= read -r name; do
  [ -z "$name" ] && continue
  cur=$($TMUX_BIN show-options -qv -t "$name" @scolor 2>/dev/null)
  [ -n "$cur" ] && continue
  color=$(pick_color "$name")
  $TMUX_BIN set-option -t "$name" @scolor "$color"
  USED="$USED$color "
done < <($TMUX_BIN list-sessions -F '#{session_name}' 2>/dev/null)
