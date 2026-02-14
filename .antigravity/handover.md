# Handover - [2026-02-14]

## Current State
- **SidebarHUD Refactor:** Converted from procedural `VBoxContainer` to a `Control` root scene with manual placeholder nodes.
- **Visuals:** Applied `daw_theme.tres`. Adjusted `TowerGrid` (2 columns) and `BuffContainer` (vertical list).
- **Logic:** `sidebar_hud.gd` updated to reuse existing scene nodes instead of clearing them. Fixed runtime `null` value type error for empty slots.
- **Layout:** Root nodes set to `Full Rect` anchors with `offset_bottom = -56.0` to respect the `TopBar` height in `GameWindow`.

## Signal Maps
- `GameManager.loadout_stock_changed(tower_data: Resource, new_stock: int)` -> Updates Tower stock labels.
- `GameManager.relic_state_changed(is_available: bool)` -> Enables/Disables Relic buttons.
- `GlobalSignals.buff_applied(buff_data: Resource)` -> Triggers cooldown visual on Buff buttons.

## Revised Next Steps
1. **Create Test Loadout:** Create `res://Resources/Loadouts/test_loadout.tres` (Type: `LoadoutConfig`).
2. **Populate Data:** Assign `basic_tower_data.tres` and test spells to the resource in the inspector.
3. **Connect to GameManager:** Load and assign this resource to `GameManager.active_loadout` in its `_ready()` function.
4. **Verification:** Confirm the SidebarHUD correctly populates icons/text from the real data and stock counts are live.
