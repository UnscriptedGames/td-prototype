# Player Instructions

This document explains how to configure the player's starting state and general session settings in **TD-Prototype**.

## Architecture Overview

The player state is defined by a single `PlayerData` resource. At game startup, the `GameManager` (found in `Systems/game_manager.gd`) looks for this specific file:
`res://Config/Players/player_data.tres`

---

## 1. Configuring Player Stats

Open `res://Config/Players/player_data.tres` in the Inspector to modify the following:

-   **Health**: The player's starting health points. When an enemy reaches the goal, this is reduced by the enemy's damage stat.
-   **Currency**: The starting gold/currency available for building towers, upgrading, and playing cards.
-   **Hand Size**: The maximum number of cards the player can hold in their hand at once.
-   **Deck**: The `DeckData` resource that will be used for this game session.

---

## 2. Advanced: Swapping Profiles

If you want to create different "Player Classes" or difficulty modes (e.g., "Hard Mode" starts with less health/gold):

1.  Create a new `PlayerData` resource (e.g., `hard_mode_player.tres`).
2.  Configure your desired stats.
3.  **How to swap**:
    -   In a production game, you would swap these via a menu.
    -   In this prototype, you can change which file `GameManager.gd` loads in its `_ready()` function, or simply edit the default `player_data.tres`.

---

## 💡 Integration Details

-   **GameManager Logic**: The `GameManager` acts as the central hub. It provides the `can_afford()` helper and handles signals like `health_changed` and `currency_changed` that update the HUD.
-   **Death**: When `health` reaches 0, the game logic (triggered via `GameManager`) will handle end-game states.
