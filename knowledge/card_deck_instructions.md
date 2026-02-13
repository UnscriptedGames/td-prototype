# Card & Deck Instructions

This document explains how to create cards, configure their effects, and assemble them into playable decks in **TD-Prototype**.

## 1. Creating a Card

Cards are `CardData` resources that link visual assets to functional effects.

### Step-by-Step
1.  **Create Resource**:
    -   Right-click in `Config/Cards` (choose the appropriate subfolder like `Build` or `Buff`).
    -   Select **Create New > Resource..** and choose **CardData**.
2.  **Assign Visuals**:
    -   Assign the `front_texture` (the illustration on the card).
3.  **Assign Effect**:
    -   Click the **Effect** property and choose **New [EffectType]**.
    -   Valid types include `BuildTowerEffect` and `BuffTowerEffect`.

---

## 2. Configuring Card Effects

The **Effect** property determines what happens when the card is played.

### Build Tower Effect (`BuildTowerEffect`)
Used to place new towers on the battlefield.
-   **Tower Data**: Link the `TowerData` resource (`.tres`) of the tower you want to build.
-   **Tower Scene**: Link the actual `.tscn` file of the tower (e.g., `archer_tower.tscn`).
-   **Note**: This separation avoids circular dependencies in Godot. The card's cost is automatically pulled from the tower's base level cost.

### Buff Tower Effect (`BuffTowerEffect`)
Used to temporarily boost a tower's performance.
-   **Cost**: Set the gold cost to play this card.
-   **Duration**: How long the buff lasts (seconds).
-   **Stats**: Set the increase values for `range`, `damage`, `fire_rate`, or `extra_targets`.
-   **Status Effects**: (Optional) Add status effects (like Fire/Ice) to the tower's attacks for the duration.

---

## 3. Assembling a Deck

A deck is a `DeckData` resource that stores a collection of cards.

### Step-by-Step
1.  **Create Resource**:
    -   Right-click in `Config/Decks`.
    -   Select **Create New > Resource..** and choose **DeckData**.
2.  **Visuals**:
    -   Assign the `card_back_texture` (used for all cards in this deck).
3.  **Add Cards**:
    -   Expand the **Cards** array.
    -   Drag and drop your `CardData` (`.tres`) files into the array elements.
    -   You can add multiple copies of the same card.

---

## 💡 Troubleshooting & Tips

-   **Card Not Appearing?** Ensure the deck is linked to your `PlayerData` resource (see `player_instructions.md`).
-   **Balance**: Remember that cards in this prototype consume the same gold currency as tower upgrades. Consider the "Opportunity Cost" when balancing card costs.
-   **Visuals**: Card illustrations should ideally be high-contrast and clear enough to be read at hand-size.
