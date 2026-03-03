# Loadout System Instructions
**Version:** 1.1 (**Phase 2 - UI Implemented**)
**Context:** The Loadout System replaces the random Deck mechanic. Players bring a fixed set of "Stock" towers and "Spells" into a level via the **SidebarHUD**.

## 1. Interaction Rules
The **SidebarHUD** is a persistent part of the `GameWindow` shell. 
*   **Menu Locking:** In the Main Menu or Setlist, the sidebar is covered by an `[ OFFLINE ]` overlay that prevents interaction.
*   **Gameplay Access:** The overlay slides away automatically when a level begins, exposing the tower inventory for the current stage.

## 2. Technical Architecture
The Loadout is stored in `PlayerData` as a fixed-size array:
1.  **Selection Path:** `GameManager.player_data.tower_slots`.
2.  **Slot Content:** Each element is either `null` or a Dictionary: `{"data": TowerData, "stock": int}`.
3.  **Persistence:** Changes to this array are canonical; the `SidebarHUD` rebuilds purely by iterating this array (indices 0-5).

## 3. Studio Interaction (UX)
*   **Single Click:** Adds the catalog item to the first `null` entry in `tower_slots`.
*   **Drag & Drop:**
    *   **Catalog to Slot:** Places the item at the specific `slot_index` hovered, replacing any existing item.
    *   **Slot to Slot:** Swaps the Dictionary entries in the `tower_slots` array at the source and target indices.
*   **Rebuild Pattern:** Always emit `GlobalSignals.loadout_rebuild_requested` after modifying the array to sync the UI.

## 4. Cursor Stability
*   **No Manual Hiding:** Do NOT use `Input.MOUSE_MODE_HIDDEN` during drags. Use `set_drag_preview()` only to ensure OS-level cursor sync and prevent "jumping" when the drag ends.
