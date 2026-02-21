# Session Handover - 2026-02-21

## Current State
- **Enemy Visuals:** Fully refactored to use `EnemyData` as the single source of truth for waveform texturing and scrolling. 
- **Shader:** `template_enemy.gdshader` now handles `corner_radius_px`, `border_width`, and `border_color` via a pixel-aware SDF with `fwidth()` sharpening.
- **Editor Parity:** `TemplateEnemy.gd` is now a `@tool` script. It actively drives the shader preview in the Godot inspector based on the assigned `EnemyData`.
- **Peak Meter:** Animates using `unscaled_delta` to prevent jitter when the game is fast-forwarded.

## Signal Maps
- `EnemyData` changes → Applied manually or via `@tool` script in `TemplateEnemy`.
- Game Speed changes → `TemplateEnemy` and `game_window.gd` now handle unscaled time/delta correctly.

## Immediate Next Step
- **Enemy Navigation:** Improve movement and clipping when enemies navigate maze branches. The user noted that enemies seem to "clip" or behave oddly when pathing through junctions.

## Technical Debt / Notes
- `BasicEnemy.tscn` uses a unique `ShaderMaterial` instance (local to the scene) for its sprite.
- `TemplateEnemy` duplicates these materials at runtime to prevent instance fighting.
- The `shadow` node in `BasicEnemy.tscn` was manually offset by the user to create a 3D drop depth.
