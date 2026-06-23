# Codex Pet

Codex Pet is an MVP desktop companion plugin for Codex. The first prototype is an original 2D black cat that floats above the desktop and reacts to local Codex-style states.

## MVP Scope

- Floating, borderless, always-on-top desktop pet window
- Original black-cat visual inspired by nimble anime cat companions, not a copy of any existing character
- Companion animation: breathing, blinking, tail sway, ears, and status-specific reactions
- Status bridge through `runtime/pet-state.json`
- Codex plugin skill that tells Codex how to start and update the pet

## States

- `idle`: calm companion motion
- `thinking`: focused animation with floating dots
- `success`: bright, happy reaction
- `error`: alert reaction
- `sleeping`: resting pose

## Run

From this folder:

```bash
python3 scripts/start_pet.py
```

In another terminal, try:

```bash
python3 scripts/set_status.py thinking "Working through the task"
python3 scripts/set_status.py success "Done"
python3 scripts/demo_statuses.py
```

## Project Shape

- `.codex-plugin/plugin.json`: Codex plugin manifest
- `skills/codex-pet/SKILL.md`: instructions Codex can use when this plugin is installed
- `desktop_pet/app.py`: desktop pet window and animation
- `scripts/start_pet.py`: launcher
- `scripts/set_status.py`: writes the current pet state
- `scripts/demo_statuses.py`: cycles through all MVP states
- `runtime/pet-state.json`: generated status bridge file

## Next Build Steps

- Replace canvas-drawn cat with layered bitmap sprites or Live2D-style assets
- Add direct Codex lifecycle hooks if/when the plugin host exposes stable task-state events
- Add preferences for size, screen position, opacity, and startup behavior
- Package the desktop app for macOS
