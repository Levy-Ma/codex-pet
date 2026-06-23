#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import sys

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_ROOT))

SYSTEM_PYTHON = Path("/usr/bin/python3")


def restart_with_system_python_if_needed(exc: ModuleNotFoundError) -> None:
    if exc.name != "_tkinter":
        raise exc
    if os.environ.get("CODEX_PET_TK_RETRY") == "1":
        raise exc
    if not SYSTEM_PYTHON.exists():
        raise exc

    result = subprocess.run(
        [str(SYSTEM_PYTHON), "-c", "import tkinter"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        raise exc

    env = os.environ.copy()
    env["CODEX_PET_TK_RETRY"] = "1"
    os.execve(str(SYSTEM_PYTHON), [str(SYSTEM_PYTHON), *sys.argv], env)


try:
    from desktop_pet.app import main
except ModuleNotFoundError as exc:
    restart_with_system_python_if_needed(exc)
    raise


if __name__ == "__main__":
    raise SystemExit(main())
