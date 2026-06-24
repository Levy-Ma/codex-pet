#!/usr/bin/env python3
import hashlib
import os
import platform
from pathlib import Path
import subprocess
import sys

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_ROOT))

NATIVE_SOURCE = PLUGIN_ROOT / "desktop_pet" / "macos" / "CodexPet.swift"
NATIVE_BINARY = PLUGIN_ROOT / "runtime" / "CodexPetNative"
NATIVE_STAMP = PLUGIN_ROOT / "runtime" / "CodexPetNative.sha256"
SYSTEM_PYTHON = Path("/usr/bin/python3")


def source_digest() -> str:
    return hashlib.sha256(NATIVE_SOURCE.read_bytes()).hexdigest()


def build_native_pet() -> bool:
    swiftc = "/usr/bin/xcrun"
    if not Path(swiftc).exists() or not NATIVE_SOURCE.exists():
        return False
    NATIVE_BINARY.parent.mkdir(parents=True, exist_ok=True)
    module_cache = PLUGIN_ROOT / "runtime" / "swift-module-cache"
    module_cache.mkdir(parents=True, exist_ok=True)
    digest = source_digest()
    previous_digest = NATIVE_STAMP.read_text(encoding="utf-8").strip() if NATIVE_STAMP.exists() else ""
    # Always rebuild during design iteration so the desktop pet cannot show a stale binary.
    needs_build = True
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
        NATIVE_STAMP.write_text(digest + "\n", encoding="utf-8")
    return True


def close_existing_native_pet() -> None:
    subprocess.run(["/usr/bin/pkill", "-x", "CodexPetNative"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def run_native_pet() -> None:
    close_existing_native_pet()
    state_path = PLUGIN_ROOT / "runtime" / "pet-state.json"
    pet_image = PLUGIN_ROOT / "assets" / "pet" / "idle.png"
    blink_image = PLUGIN_ROOT / "assets" / "pet" / "idle_blink.png"
    os.execv(str(NATIVE_BINARY), [str(NATIVE_BINARY), str(state_path), str(pet_image), str(blink_image)])


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
