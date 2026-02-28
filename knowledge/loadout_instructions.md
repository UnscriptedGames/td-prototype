# Loadout System Instructions
**Version:** 1.1 (**Phase 2 - UI Implemented**)
**Context:** The Loadout System replaces the random Deck mechanic. Players bring a fixed set of "Stock" towers and "Spells" into a level via the **SidebarHUD**.

## 1. Interaction Rules
The **SidebarHUD** is a persistent part of the `GameWindow` shell. 
*   **Menu Locking:** In the Main Menu or Setlist, the sidebar is covered by an `[ OFFLINE ]` overlay that prevents interaction.
*   **Gameplay Access:** The overlay slides away automatically when a level begins, exposing the tower inventory for the current stage.

## 2. Configuration (Inspector)
While the in-game Studio UI is being finalized, you must still define Loadouts as resources.
1.  **Create Resource:** Create a new `LoadoutConfig` resource.
2.  **Towers Map:** Drag `TowerData` resources into the key and set the **Stock** quantity in the value.
3.  **Spells Array:** Add `LoadoutData` (Spell) resources.

## 3. Dynamic Stock
*   **Building:** Decreases Stock count on the Sidebar item.
*   **Selling:** Refunds Stock (+1) and updates the HUD instantly.
