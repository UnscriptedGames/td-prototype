# Level Data Instructions

This document explains the hierarchical structure of level data in **TD-Prototype** and provides step-by-step instructions for creating new levels, waves, and spawn instructions using the Godot Inspector.

## Hierarchical Structure Overview

The level data system is built using Godot's **Resource** system. It follows a three-tier hierarchy:

1.  **LevelData (`template_data.gd`)**: The root resource for a level. It defines available towers and contains an array of Waves.
2.  **WaveData (`wave_data.gd`)**: Defines a single wave. It contains properties like boss status, reward multipliers, and an array of Spawn Instructions.
3.  **SpawnInstruction (`spawn_instruction.gd`)**: The most granular unit. It defines which enemy scene to spawn, the path it follows, how many to spawn, and the timing.

---

## 1. Creating Level Data (`.tres`)

A Level Data file binds all waves and tower restrictions together.

### Step-by-Step
1.  In the FileSystem dock, right-click your desired folder (e.g., `Config/Levels`).
2.  Select **Create New > Resource..**.
3.  Search for and select **LevelData**.
4.  Save it as `level_name_data.tres`.
5.  In the Inspector:
    -   **Available Towers**: Add elements to this array for each tower type allowed in this level (e.g., Archer, Magic, Bomb).
    -   **Waves**: This is where you will link your individual wave resources.

---

## 2. Creating Wave Data (`.tres`)

Each level contains multiple waves. Each wave is its own file to allow for easy reuse or adjustment.

### Step-by-Step
1.  Right-click your wave folder (e.g., `Config/Waves/LevelName`).
2.  Select **Create New > Resource..**.
3.  Search for and select **WaveData**.
4.  Save it as `level_name_wave_01.tres`.
5.  In the Inspector:
    -   **Start Delay**: The time (in seconds) to wait before this wave begins.
    -   **Reward Multiplier**: Adjusts the gold/currency reward for this specific wave.
    -   **Is Boss Wave**: Check this if special boss logic or UI should trigger.
    -   **Spawns**: An array where you will add individual spawn instructions.

---

## 3. Creating Spawn Instructions

Spawn Instructions are usually kept **local** to the Wave file (Sub-resources) rather than separate files, as they are specific to a single wave.

### Step-by-Step
1.  Open a **WaveData** `.tres` file in the Inspector.
2.  Expand the **Spawns** array and click **Add Element**.
3.  Click the empty slot for the new element and select **New SpawnInstruction**.
4.  Click the newly created `SpawnInstruction` to expand its properties:
    -   **Enemy Scene**: Drag and drop the enemy `.tscn` file (e.g., `goblin_enemy.tscn`).
    -   **Path**: Enter the **NodePath** relative to the level's `Paths` node (e.g., `Paths/Spawn01`).
    -   **Count**: How many enemies of this type spawn in this specific instruction.
    -   **Enemy Delay**: The gap (in seconds) between each individual enemy spawning in this group.
    -   **Start Delay**: How long to wait *within the wave* before this specific spawn starts.

---

## 4. Linking Everything Together

1.  Open your `LevelData` file.
2.  Drag your `WaveData` files into the **Waves** array in the correct order.
3.  Assign the `LevelData` resource to your level scene (typically in the `WorldData` or `GameManager` slot in the scene inspector).

### 💡 Best Practices
-   **Sequential Timing**: Use `Start Delay` in `WaveData` to provide "breather" time between waves. 
-   **Path Checking**: Ensure the `Path` NodePath matches the name of a `Path2D` node nested under the `Paths` node in your Level scene.
-   **Naming Convention**: Use `level01_wave01.tres` style naming for clear sorting.
