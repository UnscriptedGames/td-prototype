# Project Handover - td-prototype

**Current Godot Version:** 4.6.x (Stable)
**Date:** 2026-02-03

## Current State Summary
The project has been successfully migrated to Godot 4.6. All core configuration files (`project.godot`, `.editorconfig`, `.vscode/settings.json`) and agent guidelines (`architecture.md`, `.agent/rules/`) have been updated.

The enemy shadow system has been refactored for simplicity. We moved from a complex, shader-synced sprite-based shadow to a static, modulated `Panel` node in `template_enemy.tscn`. This matches the simple 2.5D aesthetic used elsewhere in the game and reduces script overhead.

## Recent Changes
- **Godot 4.6 Upgrade:** Purged all 4.5 references from docs and configs. Updated VS Code Godot path.
- **Simplified Enemy Shadows:** Replaced `ShadowSprite` with a `Panel` node using `StyleBoxFlat` with 4px rounded corners. Removed syncing logic from `template_enemy.gd`.
- **Wave Shader Refinement:** Reverted modulation support in `wave_scroller.gdshader` as it's no longer needed for shadows, ensuring visual consistency with original designs.
- **Project Cleanup:** Removed legacy `LevelHUD` and `CardsHUD` systems. Simplified `InputManager` to only handle world-space inputs. All UI is now governed by the `GameWindow` and `TowerInspector`.

## Pending Tasks
- [ ] Final visual sign-off on the new enemy shadows.
- [ ] Verification of all tower-spawn methods under Godot 4.6.

## Signal Map / API Notes
- `TemplateEnemy`: `Shadow` node is purely visual; no code interaction required.
- `ObjectPoolManager`: Handles root visibility; `Shadow` inherits visibility correctly.
