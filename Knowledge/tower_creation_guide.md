# Tower Creation & Configuration Guide

This document explains the technical architecture and step-by-step process for creating new towers in **TD-Prototype**.

## Architecture & Data Hierarchy

Towers utilize a "Data-Driven" approach combined with "Scene Inheritance":

1.  **TemplateTower (`template_tower.tscn/.gd`)**: The base scene and logic. All towers MUST inherit from this.
2.  **TowerData (`tower_data.gd`)**: A resource that links the tower's scene, ghost textures, and stats.
3.  **TowerLevelData (`tower_level_data.gd`)**: A nested resource that defines stats for a specific upgrade tier (Level 1, Level 2, etc.).

---

## 1. Creating the Tower Scene

### Step-by-Step
1.  In the FileSystem, locate `res://Entities/Towers/_TemplateTower/template_tower.tscn`.
2.  Right-click it and select **New Inherited Scene**.
3.  Save the new scene in its own folder (e.g., `res://Entities/Towers/FrostTower/frost_tower.tscn`).
4.  **Configure Visuals**:
    -   Select the **Sprite** node and assign your texture/spritesheet.
    -   Ensure `Hframes` or `Vframes` are set correctly if using a spritesheet.
5.  **Configure Muzzle**: Move the `Muzzle` node to the point where projectiles should spawn.
6.  **Pause Selection (Critical)**: Select the **Hitbox** node and set its `Process > Mode` to **`Always`**. This ensures the tower can still be clicked/selected even when the rest of the game level is paused.

---

## 2. Setting Up Animations (Critical)

Your tower's logic is driven by the **AnimationPlayer**. You MUST define the following naming convention for the game to function:

### Required Animations:
-   `level_01_idle`, `level_02_idle`, etc.
-   `level_01_shoot`, `level_02_shoot`, etc.

### The Attack Hook (Method Track)
The `TemplateTower.gd` script does NOT automatically spawn projectiles. It waits for the animation to tell it when it's ready.
1.  Open the `level_0X_shoot` animation.
2.  Add a **Method Call Track** to the `AnimationPlayer`.
3.  Select the root node of the tower.
4.  Insert a key at the exact moment the projectile(s) should appear (e.g., when the archer releases the string).
5.  Choose the function: **`_spawn_projectiles`**.

---

## 3. Creating & Linking Data (`.tres`)

### Step-by-Step
1.  **Create TowerData**:
    -   Right-click in your config folder (e.g., `Config/Towers`).
    -   Select **Create New > Resource..** and choose **TowerData**.
2.  **Assign Visuals**:
    -   `ghost_texture`: The texture shown during drag-to-build placement.
    -   `ghost_scale`: Adjust if the ghost needs to be scaled to fit the grid.
    -   `visual_offset`: Shift the ghost sprite if it doesn't centre on the 64×64 tile.
    -   `icon` (inherited from `LoadoutItem`): The texture used for the sidebar button.
3.  **Define Levels**:
    -   In the `TowerData` Inspector, expand the **Levels** array.
    -   Add a new element and choose **New TowerLevelData**.
    -   **Important**: The **Level 0** index is your base tower. Every index after that is an upgrade path.
    -   Each level requires a `projectile_scene`.
4.  **Link the Data to the Tower Scene**:
    -   Go back to your **Tower Scene**.
    -   In the Inspector for the root node, drag/drop your new `.tres` file into the **Data** slot.

---

## 4. Integration with Loadout

Towers must be added to a **Loadout** resource to be available in "The Studio" and "The Live Set".

1.  Open your active **Loadout** resource (e.g., `res://Config/Loadouts/default_loadout.tres`).
2.  Add your `TowerData` resource to the appropriate array.
3.  Configure the **AP (Allocation Point)** cost for the tower within the loadout.

---

## 💡 Troubleshooting & Tips

-   **Projectile Not Firing?** Check if you added the `_spawn_projectiles` call to your shoot animation's Method Call Track.
-   **Range Issues?** Tower range is defined in the `TowerLevelData`. If you change it, the square grid highlight will automatically adjust.
-   **Y-Offset**: Use the `visual_offset` in `TowerData` to shift the ghost tower during placement if it doesn't align with the 64×64 grid correctly.
-   **Upgrades**: The game supports branching upgrades. The indices in the `levels` array determine the order shown in the UI.
