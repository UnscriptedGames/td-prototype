# Handover - [2026-02-15]

## Current State
- **Loadout System Architecture:** Fully refactored to use strictly typed resources. `LoadoutItem` (Base) -> `TowerData`, `BuffData`, `RelicData`. `LoadoutConfig` now uses typed dictionaries for Inspector drag-and-drop.
- **Buff Migration:** Created `BuffEffectStandard` and migrated standard buffs (Attack Speed, Slow) to new `BuffData` resources.
- **Drag-and-Drop Polish:**
    - New "Ghost Button" system in `SidebarButton.gd` mimics the button appearance during drag.
    - Drag preview is anchored to the click point and preserves aspect ratio.
    - Mouse cursor hides during drag and reappears on drop/cancel.
    - Dedicated `DropZone` overlay ensures reliable drop detection in the game view.
- **UI Logic:** `SidebarButton` and `SidebarHUD` updated to handle the new `LoadoutItem` types.

## Signal Maps
- `GameManager.loadout_stock_changed(tower_data: TowerData, new_stock: int)` -> Updates stock labels in Sidebar.
- `GlobalSignals.buff_applied(buff_effect: BuffEffectStandard)` -> Triggers visual cooldowns.
- `BuildManager.tower_selected(tower: TemplateTower)` -> Opens the Tower Inspector.
- `NOTIFICATION_DRAG_END` -> Cleanly handles cursor restoration and ghost cleanup (in `game_view_dropper.gd` and `sidebar_button.gd`).

## Next Steps (Next Session)
1. **Connect Buffs to Game View:** Currently, `game_view_dropper.gd` has placeholders for buff application (`build_manager.apply_buff_at`). This needs to be wired up to actually find the target tower and apply the `BuffData.effect`.
2. **Buff Visual Feedback:** Ensure when dragging a buff, the map/towers highlight valid targets.
3. **Verification:** Confirm that applying a "Slow" or "Attack Speed" buff correctly modifies the tower's `BuffManager` state.
