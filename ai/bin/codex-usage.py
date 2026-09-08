#!/usr/bin/python3
"""A standalone context-window and rate-limit bar for the Codex CLI.

Codex has a native in-session status line for percentage readouts. This helper
adds graphical bars outside Codex (including tmux), reading the numbers from the
session file Codex is already writing:

    codex-usage
    [gpt-5.6-terra]  ctx ███░░░░░░░ 31%  5h ██░░░░░░░░ 18%  7d █████░░░░░ 46%

Source of truth is a rollout under $CODEX_HOME/sessions/**, where Codex appends
a `token_count` event per turn carrying `info.last_token_usage`,
`info.model_context_window` and `rate_limits`. Nothing is scraped and no network
call is made.

Usage:
  codex-usage                 render the newest session
  codex-usage --plain         no ANSI colors (for tmux, pipes, logs)
  codex-usage --watch [SECS]  redraw every SECS seconds (default 5)
  codex-usage --json          the raw numbers, for scripting
  codex-usage --session PATH  render one exact rollout

The launcher uses `--since EPOCH --cwd DIR` internally. That makes a new gauge
wait for, and then remain attached to, the session that was just launched.
"""
import datetime
import glob
import json
import os
import sys
import time

BAR_WIDTH = 10
FILLED = "█"
EMPTY = "░"
DEFAULT_CONTEXT_WINDOW = 272_000   # gpt-5.x default when the session omits it

RESET, DIM, BOLD = "\033[0m", "\033[2m", "\033[1m"
CYAN, BLUE, MAGENTA, GREEN, RED = (
    "\033[36m", "\033[34m", "\033[35m", "\033[32m", "\033[31m")
BAR_COLORS = {"ctx": GREEN, "5h": BLUE, "7d": MAGENTA}

PLAIN = False


def c(code):
    return "" if PLAIN else code


def codex_home():
    return os.path.expanduser(os.environ.get("CODEX_HOME") or "~/.codex")


def newest_session():
    """Most recently modified rollout file, or None if Codex has never run."""
    pattern = os.path.join(codex_home(), "sessions", "*", "*", "*", "rollout-*.jsonl")
    files = glob.glob(pattern)
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def session_started_at(path):
    """Creation timestamp recorded by Codex in the rollout's first record."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            rec = json.loads(fh.readline())
        stamp = rec.get("timestamp")
        if not stamp:
            return None
        return datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp()
    except (OSError, ValueError, TypeError):
        return None


def session_cwd(path):
    """Working directory recorded in the rollout's session_meta record."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            rec = json.loads(fh.readline())
        return (rec.get("payload") or {}).get("cwd")
    except (OSError, ValueError, TypeError):
        return None


def launched_session(since, cwd=None):
    """Newest session created after `since`, optionally restricted by cwd."""
    pattern = os.path.join(codex_home(), "sessions", "*", "*", "*", "rollout-*.jsonl")
    matches = []
    wanted_cwd = os.path.realpath(cwd) if cwd else None
    for path in glob.glob(pattern):
        started = session_started_at(path)
        if started is None or started < since:
            continue
        if wanted_cwd:
            actual_cwd = session_cwd(path)
            if not actual_cwd or os.path.realpath(actual_cwd) != wanted_cwd:
                continue
        matches.append((started, path))
    return max(matches)[1] if matches else None


def tail_lines(path, limit=400):
    """Last `limit` lines, read from the end so huge sessions stay cheap."""
    try:
        with open(path, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            size = fh.tell()
            block, data = 65536, b""
            while size > 0 and data.count(b"\n") <= limit:
                step = min(block, size)
                size -= step
                fh.seek(size)
                data = fh.read(step) + data
        return data.decode("utf-8", "replace").splitlines()[-limit:]
    except OSError:
        return []


def read_session(path):
    """Latest token_count payload and model name from a rollout file."""
    info, limits, model = None, None, None
    for line in tail_lines(path):
        if '"token_count"' not in line and '"model"' not in line:
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        payload = rec.get("payload") or {}
        if payload.get("type") == "token_count":
            # Later events supersede earlier ones; keep the last non-empty.
            info = payload.get("info") or info
            limits = payload.get("rate_limits") or limits
        model = payload.get("model") or rec.get("model") or model
    return info, limits, model


def bar(pct, color):
    pct = max(0.0, min(100.0, float(pct)))
    filled = min(BAR_WIDTH, max(0, int(round(pct / 100.0 * BAR_WIDTH))))
    hue = c(RED) if pct >= 80 else c(color)
    cells = hue + FILLED * filled + c(DIM) + EMPTY * (BAR_WIDTH - filled) + c(RESET)
    return f"{cells} {hue}{pct:.0f}%{c(RESET)}"


def until(seconds):
    try:
        secs = int(seconds)
    except (TypeError, ValueError):
        return ""
    if secs <= 0:
        return ""
    if secs >= 3600:
        return f"{c(DIM)}({secs // 3600}h){c(RESET)}"
    return f"{c(DIM)}({max(1, secs // 60)}m){c(RESET)}"


def context_pct(info):
    """Percent of the context window in use, or None if the session is idle."""
    if not isinstance(info, dict):
        return None, None, None
    # total_token_usage is the lifetime sum across every turn and compaction.
    # last_token_usage is Codex's current-context figure for the latest turn.
    usage = info.get("last_token_usage") or {}
    used = usage.get("total_tokens")
    if not used:
        return None, None, None
    window = info.get("model_context_window") or DEFAULT_CONTEXT_WINDOW
    try:
        window = int(window)
        used = int(used)
    except (TypeError, ValueError):
        return None, None, None
    if window <= 0:
        return None, None, None
    return min(100.0, used * 100.0 / window), used, window


def window_label(node):
    """Codex names its limit windows by length, not by '5h' / '7d'."""
    minutes = node.get("window_minutes") or node.get("window_size_minutes")
    try:
        minutes = int(minutes)
    except (TypeError, ValueError):
        return None
    if minutes <= 60:
        return f"{minutes}m"
    if minutes < 1440:
        return f"{minutes // 60}h"
    return f"{minutes // 1440}d"


def limit_segments(limits):
    """(label, percent, resets_in) for each rate-limit window Codex reported."""
    out = []
    if not isinstance(limits, dict):
        return out
    for key in ("primary", "secondary"):
        node = limits.get(key)
        if not isinstance(node, dict):
            continue
        pct = node.get("used_percent", node.get("used_percentage"))
        if pct is None:
            continue
        label = window_label(node) or ("5h" if key == "primary" else "7d")
        out.append((label, pct, node.get("resets_in_seconds")))
    return out


def collect(path=None):
    path = path or newest_session()
    if not path:
        return None
    info, limits, model = read_session(path)
    pct, used, window = context_pct(info)
    return {
        "session": path,
        "model": model,
        "context_percent": pct,
        "context_tokens": used,
        "context_window": window,
        "limits": [
            {"label": lbl, "used_percent": p, "resets_in_seconds": r}
            for lbl, p, r in limit_segments(limits)
        ],
    }


def render(data):
    if data is None:
        return f"{c(DIM)}codex: no sessions yet — run `codex` once{c(RESET)}"
    parts = [f"{c(BOLD)}{c(CYAN)}[{data['model'] or 'codex'}]{c(RESET)}"]
    if data["context_percent"] is not None:
        parts.append(f"{c(DIM)}ctx{c(RESET)} {bar(data['context_percent'], BAR_COLORS['ctx'])}")
    for i, lim in enumerate(data["limits"]):
        color = BAR_COLORS["5h"] if i == 0 else BAR_COLORS["7d"]
        seg = f"{c(DIM)}{lim['label']}{c(RESET)} {bar(lim['used_percent'], color)}"
        reset = until(lim["resets_in_seconds"])
        parts.append(f"{seg} {reset}".rstrip())
    if len(parts) == 1:
        # A session exists but has no usage yet: say so rather than show nothing.
        parts.append(f"{c(DIM)}idle — no usage recorded in this session yet{c(RESET)}")
    return "  ".join(parts)


def render_starting():
    """Show empty context plus the latest account-wide limits until first turn."""
    recent = collect()
    if recent is None:
        return f"{c(DIM)}codex: starting session…{c(RESET)}"
    recent["model"] = "codex"
    recent["context_percent"] = 0.0
    recent["context_tokens"] = 0
    return render(recent)


def option_value(args, option, default=None):
    if option not in args:
        return default
    idx = args.index(option)
    try:
        return args[idx + 1]
    except IndexError:
        raise SystemExit(f"codex-usage: {option} requires a value")


def main():
    global PLAIN
    args = sys.argv[1:]
    if "-h" in args or "--help" in args:
        print(__doc__.strip())
        return 0
    PLAIN = "--plain" in args or not sys.stdout.isatty()
    exact_path = option_value(args, "--session")
    since_text = option_value(args, "--since")
    wanted_cwd = option_value(args, "--cwd")
    try:
        since = float(since_text) if since_text is not None else None
    except ValueError:
        raise SystemExit("codex-usage: --since must be a Unix timestamp")

    def resolve(bound=None):
        if bound:
            return bound
        if exact_path:
            return os.path.expanduser(exact_path)
        if since is not None:
            return launched_session(since, wanted_cwd)
        return newest_session()

    if "--json" in args:
        path = resolve()
        data = None if since is not None and not path else collect(path)
        print(json.dumps(data, indent=2))
        return 0
    if "--watch" in args:
        idx = args.index("--watch")
        try:
            every = float(args[idx + 1])
        except (IndexError, ValueError):
            every = 5.0
        bound_path = None
        try:
            while True:
                bound_path = resolve(bound_path)
                if since is not None and not bound_path:
                    output = render_starting()
                else:
                    output = render(collect(bound_path))
                sys.stdout.write("\r\033[2K" + output)
                sys.stdout.flush()
                time.sleep(every)
        except KeyboardInterrupt:
            print()
        return 0
    path = resolve()
    if since is not None and not path:
        print(render_starting())
    else:
        print(render(collect(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
