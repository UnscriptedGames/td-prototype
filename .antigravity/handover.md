# Handover Document

**Date:** 2026-02-01
**Session Goal:** Refactor Buff System (Drag-and-Drop) & Fix UI Layouts.

## 1. Current State
The **Buff System** has been successfully refactored from a "Select -> Click" workflow to a modern "Drag -> Drop" workflow. The User Interface has been stabilized.

### Key Features Implemented:
- **Universal Drag System:** `BuildManager` now handles both Tower and Buff drags logically.
- **Visuals:** 
    - **Ghost Card:** Visible when dragging in the Sidebar.
    - **Snapped Ghost Cursor:** Visible when dragging in the Game Viewport (Red Brackets).
    - **Banishment:** Drags are "banished" (hidden/disabled) if they exit the viewport to prevent visual clutter.
- **Grid Snapping:** The buff cursor (Red Brackets) snaps perfectly to the 64x64 grid tiles.
- **Layout:** The `GameWindow` sidebar now uses a **Fixed Cell Size** (162x215) for the card grid. This ensures 8 cards fit perfectly without resizing the window or squashing the Top Bar.

### Critical Files:
- `Systems/build_manager.gd`: The brain of the drag logic. Handles `start_drag_buff`, `update_drag_buff` (with snapping), and `banish_drag_session`.
- `UI/Layout/game_window.gd`: Handles the layout and the high-level `_can_drop_data` logic for banishment.
- `UI/Layout/game_view_dropper.gd`: The input catcher for the viewport. Delegates logic to `BuildManager` and hides the default drag preview.

## 2. Signal Map (Relevant Subsystems)

### BuildManager
- `tower_selected(tower)` -> `GameWindow` (Updates selection state)
- `tower_deselected()` -> `GameWindow`
- Note: `buff_started` signals are currently handled internally or via effects.

### GameWindow
- `drop_overlay.card_dropped` -> `_on_card_effect_completed_from_drag` (Consumes currency, shifts deck)

### CardManager
- `hand_changed(new_hand)` -> `GameWindow._on_hand_changed` (Rebuilds the grid)

## 3. Immediate Next Steps / Roadmap
The user has explicitly defined the goal for the next session:

**Goal: Integrate Old Level HUD into New Design**
- **Objective:** The game currently has a minimal `GameWindow` UI. We need to bring back the functional elements of the old `level_hud` (Health, Wave Info, Currency, etc.) and integrate them into the new DAW-style layout.
- **Location:** Likely into `GameWindow/TopBar` or a new overlay layer.
- **References:** Check `UI/HUD/level_hud.tscn` (if it exists) or previous component logic.

## 4. Known Issues / Notes
- The `Card.tscn` uses `AnimationPlayer` for hover effects. Ensure fixed sizing doesn't conflict with scale animations (current testing shows it's fine).
- The `BuildManager` manual sprite loader (`Image.load_from_file`) is a workaround for some import lag/issues. Keep this in mind if assets change.
