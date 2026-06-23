---
name: codex-pet
description: Control the local Codex Pet desktop companion prototype by launching it or changing its status.
---

# Codex Pet

Use this skill when the user asks to start, demo, or update the Codex Pet desktop companion.

## Commands

Run these from the plugin root.

Start the desktop pet:

```bash
python3 scripts/start_pet.py
```

Set a status:

```bash
python3 scripts/set_status.py idle "Ready"
python3 scripts/set_status.py thinking "Thinking"
python3 scripts/set_status.py success "Done"
python3 scripts/set_status.py error "Needs attention"
python3 scripts/set_status.py sleeping "Resting"
```

Demo all statuses:

```bash
python3 scripts/demo_statuses.py
```

## Behavior

- `idle` means calm companion motion.
- `thinking` means Codex is working.
- `success` means work finished successfully.
- `error` means work hit a problem.
- `sleeping` means the pet should rest.

The status bridge is `runtime/pet-state.json`. Scripts should update this file instead of editing the desktop app directly.
