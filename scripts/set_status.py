#!/usr/bin/env python3
from pathlib import Path
import sys

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_ROOT))

from desktop_pet.state import VALID_STATES, write_state


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        allowed = ", ".join(sorted(VALID_STATES))
        print(f"Usage: set_status.py <state> [message]\nStates: {allowed}", file=sys.stderr)
        return 2
    state = argv[1]
    message = " ".join(argv[2:])
    try:
        path = write_state(state, message)
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 2
    print(f"Codex Pet is now {state}. State file: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
