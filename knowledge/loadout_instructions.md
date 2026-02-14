# Loadout System Instructions
**Version:** 1.0 (Phase 1)
**Context:** The Loadout System replaces the random Deck mechanic. Players now bring a fixed set of "Stock" towers and "Spells" into a level.

## 1. Creating a Loadout
Since the UI is not yet built (Phase 2), you must create Loadouts in the Godot Inspector.

### Step 1: Create the Resource
1.  In the FileSystem, right-click a folder (e.g., `Config/Decks` or `Config`).
2.  Select **Create New > Resource**.
3.  Search for `LoadoutConfig`.
4.  Save it as `test_loadout.tres`.

### Step 2: Configure the Loadout
1.  Open `test_loadout.tres` in the Inspector.
2.  **Towers Map:**
    *   Click to add entries.
    *   **Key:** Drag a `TowerData` resource (e.g., `Entities/Towers/tower_gun_data.tres`).
    *   **Value:** Set the Integer Quantity (e.g., `5`). This is your **Stock**.
3.  **Spells Array:**
    *   Add elements.
    *   Drag `CardData` resources (e.g., `Config/Cards/card_fireball.tres`).

## 2. Using the Loadout (In-Game)
*   **Building:** You can only build towers if you have Stock remaining.
*   **Selling:** Selling a tower refunds +1 to your Stock.
*   **Spells:** Spells are always available (subject to Gold Cost + Cooldown).

## 3. Debugging / Testing
*   The `GameManager` currently loads a dummy loadout in `_ready()`.
*   To test your custom loadout, you will need to manually call `GameManager.set_active_loadout(load("res://path/to/your/loadout.tres"))` in a debug script or temporary hook.
