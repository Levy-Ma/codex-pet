#!/usr/bin/env python3
from pathlib import Path
import sys

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_ROOT))

from desktop_pet.app import main


if __name__ == "__main__":
    raise SystemExit(main())
