#!/usr/bin/env python3
import os
import platform
from pathlib import Path
import subprocess
import sys

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_ROOT))

NATIVE_SOURCE = PLUGIN_ROOT / "desktop_pet" / "macos" / "CodexPet.swift"
NATIVE_BINARY = PLUGIN_ROOT / "runtime" / "CodexPetNative"
SYSTEM_PYTHON = Path("/usr/bin/python3")


def build_native_pet() -> bool:
    swiftc = "/usr/bin/xcrun"
    if not Path(swiftc).exists() or not NATIVE_SOURCE.exists():
        return False
    NATIVE_BINARY.parent.mkdir(parents=True, exist_ok=True)
    module_cache = PLUGIN_ROOT / "runtime" / "swift-module-cache"
    module_cache.mkdir(parents=True, exist_ok=True)
    needs_build = not NATIVE_BINARY.exists() or NATIVE_BINARY.stat().st_mtime < NATIVE_SOURCE.stat().st_mtime
    if needs_build:
        env = os.environ.copy()
        env["CLANG_MODULE_CACHE_PATH"] = str(module_cache)
        result = subprocess.run(
            [swiftc, "--sdk", "macosx", "swiftc", str(NATIVE_SOURCE), "-o", str(NATIVE_BINARY)],
            cwd=str(PLUGIN_ROOT),
            env=env,
            check=False,
        )
        if result.returncode != 0:
            return False
    return True


def run_native_pet() -> None:
    state_path = PLUGIN_ROOT / "runtime" / "pet-state.json"
    os.execv(str(NATIVE_BINARY), [str(NATIVE_BINARY), str(state_path)])


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


def main() -> int:
    if platform.system() == "Darwin" and build_native_pet():
        run_native_pet()

    try:
        from desktop_pet.app import main as tk_main
    except ModuleNotFoundError as exc:
        restart_with_system_python_if_needed(exc)
        raise
    return tk_main()


if __name__ == "__main__":
    raise SystemExit(main())
