# Loadout System Refactor: "The Studio" & "The Live Set"
**Status:** DRAFT (Phase 1 Design)  
**Date:** 2026-02-13  
**Context:** Shifting core gameplay from "Reactionary Deckbuilding" to "Deliberate Loadout Strategy".

## 1. Core Concept: The "DAW" Metaphor
The game loop pivots to emphasize preparation and resource allocation, mirroring a music producer configuring their rack before a show.
-   **Pre-Game (The Studio):** The player configures their "Rack" (Loadout) using a limited budget of **Allocation Points** (CPU/RAM).
-   **In-Game (The Live Set):** The player uses the selected tools (Towers, Spells, Relics) to perform, spending **Gold** (Energy) earned from the audience (Enemies).

## 2. Key Mechanics

### 2.1. The Loadout (Studio Phase)
Replacing the **Deck**, the Loadout is a fixed set of tools available for a level.
-   **Allocation Points (AP):** The hard limit on how many items you can bring.
    -   *Progression:* Player upgrades their "CPU" to increase Max AP.
-   **Item Costs:**
    -   **Heavy:** High-Tier Towers, Powerful Relics.
    -   **Medium:** Standard Towers, Global Buffs.
    -   **Light:** Simple Spells, Utility Modules.

### 2.2. Towers: "The Instruments"
Towers are persistent structures that generate the primary defense.
-   **Selection:** Player chooses *Types* and *Quantity* in Loadout.
    -   *Example:* "I allocate 5 Gun Turrets (Cost: 10 AP) and 2 Snipers (Cost: 8 AP)."
-   **In-Game Rule:** The Loadout sets the **Inventory Cap**.
    -   If you bring 5 Gun Turrets, you can have at most 5 built at once.
    -   *Crucial Decision:* This "Stock" system replaces unlimited building, forcing strategic choices during loadout.
-   **Placement & "Amped Tiles":**
    -   **Free Placement:** Towers can be built on any valid wall tile (Green).
    -   **Amped Tiles (High Voltage):** Specific wall tiles pre-marked in the level design that grant bonuses (Range/Speed/Damage) if a tower is built there. This encourages using specific spots without hard-locking placement.
    -   *Future Feature:* **"Acoustic Treatment" Spell:** A high-cost utility spell that allows players to create a temporary Amped Tile on any wall, overriding the level design for strategic flexibility.
-   **Soft-Lock Prevention:**
    -   **Building:** Costs Gold. Decreases Stock (-1).
    -   **Selling:** Returns Gold (Partial) and **Refunds Stock (+1)**.
    -   *Result:* Players can pivot strategies mid-game (sell a Turret to move it), but are still constrained by their initial "Hardware" choice.

### 2.3. Buffs: "The FX Rack"
Replacing "Consumable Cards", these are now repeatable utility modules.
-   **Selection:** 4-6 Vertical Slots in the Sidebar.
-   **Visuals:** Horizontal "Rack Unit" bars (Icon + Name + Status).
-   **Mechanic:** Drag-to-Target (existing system).
-   **Rules:**
    -   **Cooldown:** Progress bar fills Right-to-Left. Interaction disabled while filling.
    -   **Gold Cost:** Deducted on successful application.

### 2.4. Relics: "Mastering Plugins"
Passive modifiers that alter global rules or specific tower types.
-   **Selection:** High AP cost items that define the build's archetype.
-   **Mechanic:** Always active once the level starts.
-   **Future Scope:** "Chaining" – Relics that only affect adjacent slots in the Loadout rack or specific enemy variants.

## 3. Progression & Meta-Game
-   **Unlocks:** New Towers, Spells, and Relics are earned via Level Completion or "Record Label" milestones.
-   **Session Bonus (The "Bounce"):**
    -   Completing a level with **Unused Allocation Points** grants a bonus resource ("High Quality Export").
    -   Incentivizes efficiency and "minimalist" builds.

## 4. UI/UX Implications
-   **Main Menu / Map:** precise "Loadout Screen" needed.
    -   Visuals: Rack-mount style interface. Drag-and-drop modules into slots.
    -   Feedback: Dynamic "CPU Usage" bar.
-   **HUD (In-Game):**
    -   **Sidebar Layout:** "The All-Active Rack" (Vertical Stack).
        1.  **Top:** Relics (HBox, 3 slots).
        2.  **Middle:** Towers (Grid, 2 cols x 3 rows). Shows Stock.
        3.  **Bottom:** Buffs (VBox, 4-6 slots). Rack Units with Cooldown bars.

## 5. Technical Architecture Changes
-   **Remove:** `DeckData`, `CardDrawing` logic.
-   **Refactor:** `GameManager` to hold `LoadoutData` (Dictionary of Active Items).
-   **New Resource:** `LoadoutConfig` (Resource) to save/load user presets.
