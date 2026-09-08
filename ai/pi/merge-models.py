#!/usr/bin/python3
"""Merge this repo's Pi providers into an existing ~/.pi/agent/models.json.

Replacing the file outright destroys whatever providers the user configured
themselves, so install.sh calls this instead. The rule is simple and one-way:

    a provider the user already has is never touched; only missing ones are added.

That keeps a hand-tuned provider (different models, a different key source, a
private base URL) intact across re-runs, while still letting a fresh machine pick
up the repo's defaults.

    merge-models.py <repo models.json> <target models.json>

Exit codes, so the caller can print the right line:
    0   target changed (what was added is printed)
    10  nothing to do
    1   refused — target exists but could not be parsed; left untouched

Set PI_MODELS_FORCE=1 to let the repo's copy of a provider overwrite the user's.
"""
import json
import os
import shutil
import sys
import time


def load(path):
    with open(path) as fh:
        return json.load(fh)


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    src_path, dst_path = sys.argv[1], sys.argv[2]
    force = os.environ.get("PI_MODELS_FORCE", "").lower() in ("1", "true", "yes")

    src = load(src_path)
    src_providers = src.get("providers") or {}

    # Nothing there yet: install the repo copy verbatim.
    if not os.path.exists(dst_path):
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        shutil.copyfile(src_path, dst_path)
        print(f"installed with {len(src_providers)} provider(s): "
              f"{', '.join(sorted(src_providers))}")
        return 0

    try:
        dst = load(dst_path)
    except (ValueError, OSError) as exc:
        # Never overwrite something we cannot understand — the user may have
        # hand-edited it and a backup they didn't ask for is small comfort.
        print(f"{dst_path} is not valid JSON ({exc}); left untouched", file=sys.stderr)
        return 1

    if not isinstance(dst, dict):
        print(f"{dst_path} is not a JSON object; left untouched", file=sys.stderr)
        return 1

    dst_providers = dst.get("providers")
    if not isinstance(dst_providers, dict):
        dst_providers = {}

    added, kept = [], []
    for name, cfg in src_providers.items():
        if name in dst_providers and not force:
            kept.append(name)
        else:
            if name in dst_providers:
                added.append(name + " (overwritten, PI_MODELS_FORCE)")
            else:
                added.append(name)
            dst_providers[name] = cfg

    if not added:
        print(f"all {len(kept)} repo provider(s) already present: {', '.join(sorted(kept))}")
        return 10

    # Only now is a write happening, so only now is a backup warranted.
    backup = f"{dst_path}.backup.{time.strftime('%Y%m%d%H%M%S')}"
    shutil.copyfile(dst_path, backup)

    dst["providers"] = dst_providers
    tmp = dst_path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(dst, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, dst_path)   # atomic: never leave a half-written config

    msg = f"added {', '.join(added)}"
    if kept:
        msg += f"; kept your {', '.join(sorted(kept))}"
    print(f"{msg} (backup: {os.path.basename(backup)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
