# Handover: TD-Prototype

**Date:** 2026-02-26
**Status:** Data Model Consolidated, UI Refined.

## Current State
- **Data Model:** `WaveData` is fully deprecated and deleted. `StemData` is now the unit of work for all encounters, containing audio streams and `SpawnInstruction` arrays.
- **UI Architecture:** `GameWindow.tscn` uses a `GameViewWrapper` (Control) to hold the `SubViewportContainer` and `DebugToolbar` as siblings. This fixed a critical bug where UI clicks were swallowed by the viewport.
- **Top Bar:** Cleaned up. Removed `SpeedLabel`; added `RestartButton` + confirmation flow.

## Signal Map Highlights
- `GameManager.game_speed_changed` -> Updates `DebugToolbar` (if present).
- `GameWindow._on_restart_confirmed` -> Calls `StageManager.restart_stem()` or `GameManager.reset_state()` / `_load_level()`.

## Immediate Next Steps (Next Session)
- **Pool Manager Migration:** Discuss and implement moving object pooling tasks (pre-warming/initialization) from the loading screen to the `SetlistUI` screen to optimize transition times.
- **Testing Tool Implementation:** Implement functional testing buttons for manual wave spawning and audio quality shifting.
- **Audio Crossfades:** Implement the 3-tier layering logic in `AudioManager`.
