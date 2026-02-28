# Handover: TD-Prototype

## Current State
- **Sidebar Loadout Overlay:** Successfully implemented in `GameWindow`. It now features a smooth left-to-right slide animation, an "OFFLINE" label, and blocks interaction during menus.
- **Context Modes:** The Top Bar and Sidebar now synchronize visibility based on `ContextMode` (Gameplay, Setlist, Empty).
- **Initialization Fix:** Fixed a race condition where the overlay would snap or fail to show on boot by forcing a sync in `_ready()` and using `call_deferred` for the animation.
- **Customizable Timing:** Designers can now adjust `sidebar_overlay_anim_time` in the `GameWindow` inspector.

## Signal Maps
- **GameManager:** `peak_meter_changed`, `game_state_changed`, `wave_status_changed`.
- **GameWindow:** Internal `_set_sidebar_offline` driven by `ContextMode` transitions in `change_workspace`.

## Immediate Next Step
- **Task 3: Stem Maze Refactor**
    - **Proposal:** Transition the maze layout from a static TileMap in the `TemplateStage` scene into a data-driven path defined within each `StemData` resource. This will allow each musical stem in a stage to have a unique path/strategy while sharing the same environmental background.
    - **Technical Approach:** Add a `maze_path: Array[Vector2i]` (or similar) to `StemData.gd`. Update `TemplateStage.gd` to clear and rebuild the `MazeLayer` using these coordinates during level initialization.

## Git Commit Summary
Implemented animated Sidebar Loadout Overlay with customizable timing and context-driven visibility logic.

