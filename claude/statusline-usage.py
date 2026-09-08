#!/usr/bin/python3
"""Claude Code status line: shows plan usage limits + context window as bars.

Reads the status-line JSON from stdin and renders, each as a colored bar plus
percentage:
  - the 5-hour and 7-day plan rate limits (the same numbers `/usage` shows), and
  - the current context-window usage (read from the session transcript),
alongside the model name and current directory.
"""
import json
import os
import subprocess
import sys
import time

# ---- tunables ---------------------------------------------------------------
BAR_WIDTH = 10          # number of cells in each consumption bar
FILLED = "█"
EMPTY = "░"
DEFAULT_CONTEXT_WINDOW = 200_000   # tokens; auto-bumped to 1M for [1m] models
MAX_DIR_LEN = 18        # truncate long project/dir names with an ellipsis (0 = no cap)

# ANSI colors
RESET = "\033[0m"
DIM = "\033[2m"
BOLD = "\033[1m"
CYAN = "\033[36m"
BLUE = "\033[34m"
MAGENTA = "\033[35m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"

# per-bar identity colors, so ctx/5h/7d are distinguishable at a glance
BAR_COLORS = {
    "ctx": GREEN,
    "5h": BLUE,
    "7d": MAGENTA,
}


def bar(pct, color):
    pct = max(0.0, min(100.0, float(pct)))
    filled = int(round(pct / 100.0 * BAR_WIDTH))
    filled = min(BAR_WIDTH, max(0, filled))
    c = RED if pct >= 80 else color
    cells = c + FILLED * filled + DIM + EMPTY * (BAR_WIDTH - filled) + RESET
    return f"{cells} {c}{pct:.0f}%{RESET}"


def until(resets_at):
    """Compact 'resets in' hint, e.g. (1h) or (12m)."""
    try:
        secs = int(resets_at) - int(time.time())
    except (TypeError, ValueError):
        return ""
    if secs <= 0:
        return ""
    if secs >= 3600:
        return f"{DIM}({secs // 3600}h){RESET}"
    return f"{DIM}({max(1, secs // 60)}m){RESET}"



# ---- meter: record the plan limits this status line receives ---------------
# Appends one line per refresh (deduped per minute per session) to
# ~/.local/state/meter/max.log so the 5h / 7d utilization has a history.
# Never raises: the status line must render whatever happens here.
METER_LOG = os.path.expanduser("~/.local/state/meter/max.log")


def meter_log(data, rl):
    try:
        f5 = rl.get("five_hour") or {}
        f7 = rl.get("seven_day") or {}
        if "used_percentage" not in f5 and "used_percentage" not in f7:
            return
        now = int(time.time())
        sid = (data.get("session_id") or "")[:8]
        minute = now // 60
        stamp_path = METER_LOG + ".last"
        try:
            with open(stamp_path) as h:
                if h.read().strip() == f"{sid}:{minute}":
                    return
        except OSError:
            pass
        cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or ""
        cost = data.get("cost") or {}
        rec = {
            "ts": now,
            "sid": sid,
            "model": (data.get("model") or {}).get("id"),
            "dir": os.path.basename(cwd.rstrip("/")),
            "h5": f5.get("used_percentage"),
            "h5_reset": f5.get("resets_at"),
            "d7": f7.get("used_percentage"),
            "d7_reset": f7.get("resets_at"),
            "usd": cost.get("total_cost_usd"),
            "dur_ms": cost.get("total_duration_ms"),
        }
        os.makedirs(os.path.dirname(METER_LOG), exist_ok=True)
        with open(METER_LOG, "a") as h:
            h.write(json.dumps(rec, separators=(",", ":")) + "\n")
        with open(stamp_path, "w") as h:
            h.write(f"{sid}:{minute}")
    except Exception:
        pass

def limit_segment(label, node):
    if not isinstance(node, dict) or "used_percentage" not in node:
        return None
    pct = node.get("used_percentage", 0)
    reset = until(node.get("resets_at"))
    color = BAR_COLORS.get(label, GREEN)
    seg = f"{DIM}{label}{RESET} {bar(pct, color)}"
    return f"{seg} {reset}".rstrip()


def git_segment(cwd):
    """Current git branch (or short SHA if detached), with a dirty marker."""
    if not cwd or not os.path.isdir(cwd):
        return None
    try:
        branch = subprocess.run(
            ["git", "--no-optional-locks", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=cwd, capture_output=True, text=True, timeout=0.5,
        )
    except Exception:
        return None
    if branch.returncode != 0:
        return None
    name = branch.stdout.strip()
    if not name:
        return None
    if name == "HEAD":
        try:
            sha = subprocess.run(
                ["git", "--no-optional-locks", "rev-parse", "--short", "HEAD"],
                cwd=cwd, capture_output=True, text=True, timeout=0.5,
            )
            name = sha.stdout.strip() or "detached"
        except Exception:
            name = "detached"

    dirty = ""
    try:
        status = subprocess.run(
            ["git", "--no-optional-locks", "status", "--porcelain"],
            cwd=cwd, capture_output=True, text=True, timeout=0.5,
        )
        if status.returncode == 0 and status.stdout.strip():
            dirty = f"{YELLOW}*{RESET}"
    except Exception:
        pass

    return f"{CYAN} {name}{RESET}{dirty}"


def context_window_for(model_id):
    """200k normally, 1M for the [1m] long-context variants."""
    if model_id and "[1m]" in str(model_id):
        return 1_000_000
    return DEFAULT_CONTEXT_WINDOW


def context_tokens(transcript_path):
    """Input tokens occupied by the current context, from the latest turn.

    Fallback for older Claude Code builds that don't provide a `context_window`
    object. Each API call resends the whole prompt, so the most recent
    assistant message's input + cache (read + creation) tokens is the current
    context occupancy. Output is excluded to match `/context` semantics.
    Returns None if it can't be determined.
    """
    if not transcript_path or not os.path.exists(transcript_path):
        return None
    latest = None
    try:
        with open(transcript_path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue
                msg = obj.get("message")
                if isinstance(msg, dict) and isinstance(msg.get("usage"), dict):
                    latest = msg["usage"]
    except OSError:
        return None
    if not latest:
        return None
    return (
        latest.get("input_tokens", 0)
        + latest.get("cache_read_input_tokens", 0)
        + latest.get("cache_creation_input_tokens", 0)
    )


def context_segment(data):
    """Prefer the `context_window` object Claude Code provides; otherwise
    fall back to reading the session transcript."""
    cw = data.get("context_window")
    used_pct = None
    used_tokens = None
    window = None

    if isinstance(cw, dict):
        window = cw.get("context_window_size")
        if cw.get("used_percentage") is not None:
            used_pct = float(cw.get("used_percentage"))
        cu = cw.get("current_usage")
        if isinstance(cu, dict) and cu:
            used_tokens = (
                cu.get("input_tokens", 0)
                + cu.get("cache_creation_input_tokens", 0)
                + cu.get("cache_read_input_tokens", 0)
            )
        elif cw.get("total_input_tokens") is not None:
            used_tokens = cw.get("total_input_tokens")

    if used_pct is None:
        # Fallback: compute from the transcript.
        toks = context_tokens(data.get("transcript_path"))
        if toks is None:
            return None
        window = window or context_window_for((data.get("model") or {}).get("id"))
        used_tokens = toks
        used_pct = used_tokens / window * 100.0
    elif used_tokens is None and window:
        used_tokens = used_pct / 100.0 * window

    seg = f"{DIM}ctx{RESET} {bar(used_pct, BAR_COLORS['ctx'])}"
    if used_tokens is not None:
        seg = f"{seg} {DIM}({used_tokens / 1000:.0f}k){RESET}"
    return seg


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("")
        return

    parts = []

    # model name (shorten the verbose 1M-context label)
    model = (data.get("model") or {}).get("display_name")
    if model:
        model = model.replace("(1M context)", "(1M)")
        parts.append(f"{BOLD}{CYAN}{model}{RESET}")

    # git branch (skips optional locks so it never blocks on a concurrent git op)
    cwd_for_git = (data.get("workspace") or {}).get("current_dir") or data.get("cwd")
    git_seg = git_segment(cwd_for_git)
    if git_seg:
        parts.append(git_seg)

    # context-window usage — placed early so a long dir name can't push it
    # off the right edge (the terminal truncates the line from the right)
    ctx = context_segment(data)
    if ctx:
        parts.append(ctx)

    # usage limits — the main event
    rl = data.get("rate_limits") or {}
    meter_log(data, rl)
    seg5 = limit_segment("5h", rl.get("five_hour"))
    seg7 = limit_segment("7d", rl.get("seven_day"))
    limit_parts = [s for s in (seg5, seg7) if s]

    if limit_parts:
        parts.extend(limit_parts)
    else:
        # Pro/Max only, and only after the first API response of a session
        parts.append(f"{DIM}limits: n/a{RESET}")

    # current directory (basename) — last, and length-capped, since it's the
    # least critical and the most variable in width
    cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd")
    if cwd:
        name = os.path.basename(cwd.rstrip("/")) or "/"
        if MAX_DIR_LEN and len(name) > MAX_DIR_LEN:
            name = name[: MAX_DIR_LEN - 1] + "…"
        parts.append(f"{DIM}{name}{RESET}")

    print(f" {DIM}│{RESET} ".join(parts))


if __name__ == "__main__":
    main()
