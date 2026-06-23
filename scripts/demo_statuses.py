#!/usr/bin/env python3
from pathlib import Path
import sys
import time

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_ROOT))

from desktop_pet.state import write_state


DEMO = [
    ("idle", "Ready"),
    ("thinking", "Thinking through the task"),
    ("success", "Finished"),
    ("error", "Needs attention"),
    ("sleeping", "Resting"),
    ("idle", "Ready"),
]


def main() -> int:
    for state, message in DEMO:
        write_state(state, message)
        print(f"{state}: {message}")
        time.sleep(1.8)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
