# Level Data Instructions

This document explains the hierarchical structure of level data in **TD-Prototype** and provides step-by-step instructions for creating new levels, waves, and spawn instructions using the Godot Inspector.

## Hierarchical Structure Overview

The level data system is built using Godot's **Resource** system. It follows a three-tier hierarchy:

1.  **StageData (`stage_data.gd`)**: The root resource for a stage. It defines the available loadout and links to its 5 stems.
2.  **StemData (`stem_data.gd`)**: Defines a single stem level. It contains the audio reference, performance thresholds, and an array of Spawn Instructions.
3.  **SpawnInstruction (`spawn_instruction.gd`)**: The most granular unit. It defines which enemy variant to spawn, how many to spawn, and the timing.

---

## 1. Creating Stage Data (`.tres`)

A Stage Data file binds all stems together for a single song.

### Step-by-Step
1.  In the FileSystem dock, right-click your desired folder (e.g., `Config/Stages`).
2.  Select **Create New > Resource..**.
3.  Search for and select **StageData**.
4.  Save it as `stage_name_config.tres`.
5.  In the Inspector:
    -   **Stems**: This is where you will link your individual StemData resources (5 stems + 1 boss).

---

## 2. Creating Stem Data (`.tres`)

Each stage contains 5 stems and a boss wave. Each stem is its own file to allow for independent configuration and audio quality handling.

### Step-by-Step
1.  Right-click your stem folder (e.g., `Config/Stages/StageName/Stems`).
2.  Select **Create New > Resource..**.
3.  Search for and select **StemData**.
4.  Save it as `stage_name_stem_01.tres`.
5.  In the Inspector:
    -   **Layout Scene Path**: Link to the lightweight layout scene (e.g., `stage01_stem01_drums.tscn`).
    -   **Maze Styles**: Add `MazeTileStyle` resources here to define health-based colors.
    -   **Audio Stream**: Link the `.mp3` or `.wav` for this stem.
    -   **Is Boss Wave**: Check this if special boss logic or UI should trigger.
    -   **Spawns**: An array where you will add individual spawn instructions.

---

## 3. Creating Spawn Instructions

Spawn Instructions are kept **local** to the Stem file (Sub-resources) rather than separate files, as they are specific to a single stem level.

### Step-by-Step
1.  Open a **StemData** `.tres` file in the Inspector.
2.  Expand the **Spawns** array and click **Add Element**.
3.  Click the empty slot for the new element and select **New SpawnInstruction**.
4.  Click the newly created `SpawnInstruction` to expand its properties:
    -   **Enemy Scene**: Drag and drop the enemy `.tscn` file (e.g., `goblin_enemy.tscn`).
    -   **Spawn Tile**: Enter the Vector2i coordinates for the spawn (e.g., `0, 8`).
    -   **Count**: How many enemies of this type spawn in this specific instruction.
    -   **Enemy Delay**: The gap (in seconds) between each individual enemy spawning in this group.
    -   **Start Delay**: How long to wait *within the wave* before this specific spawn starts.

---

## 4. Linking Everything Together

1.  Open your `StageData` file.
2.  Drag your `StemData` files into the **Stems** array in the correct order.
3.  Assign the `StageData` resource to your stage scene (typically in the `AudioManager` or `GameManager` slot in the scene inspector).

### 💡 Best Practices
-   **Sequential Order**: Ensure Stem 1 is placed in the first slot, as it is mandatory.
-   **No-Underscore Convention**: Use `stage01.tres` style naming to prevent automated path failures.
-   **Injection Pattern**: `BaseStage` handles all rendering logic; stems only provide the data and layout scenes.
-   **Single Exit Pattern**: All enemies automatically find the shortest path to the exit coordinate defined in the maze layout. Weighted exit targets are no longer used.
-   **Damage Logic**: Distortion (Peak Meter) increases based on the enemy's **remaining health** when they reach the single goal at the end of their path.
