from __future__ import annotations

import json
import os
import time
from pathlib import Path

VALID_STATES = {"idle", "thinking", "success", "error", "sleeping"}
DEFAULT_STATE = {"state": "idle", "message": "Ready", "updatedAt": None}


def plugin_root() -> Path:
    return Path(__file__).resolve().parents[1]


def state_path() -> Path:
    return plugin_root() / "runtime" / "pet-state.json"


def ensure_state_file() -> Path:
    path = state_path()
    if not path.exists():
        write_state("idle", "Ready")
    return path


def read_state() -> dict:
    path = ensure_state_file()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return DEFAULT_STATE.copy()

    state = data.get("state", "idle")
    if state not in VALID_STATES:
        state = "idle"
    message = str(data.get("message", "")).strip() or "Ready"
    return {
        "state": state,
        "message": message,
        "updatedAt": data.get("updatedAt"),
    }


def write_state(state: str, message: str = "") -> Path:
    normalized = state.strip().lower()
    if normalized not in VALID_STATES:
        allowed = ", ".join(sorted(VALID_STATES))
        raise ValueError(f"Unknown state '{state}'. Use one of: {allowed}.")

    path = state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "state": normalized,
        "message": message.strip() or normalized.title(),
        "updatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    temp_path = path.with_suffix(".json.tmp")
    temp_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    os.replace(temp_path, path)
    return path
