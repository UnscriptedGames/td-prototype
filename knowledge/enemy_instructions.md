# Enemy Creation & Configuration Instructions (Shader-Driven)

This document explains the 4-phase process for creating new enemies in **TD-Prototype**.

## Architecture & Data Hierarchy
Enemies are data-driven. A single logic scene handles all waveform enemies by loading a specific configuration resource:
1. **TemplateEnemy (`template_enemy.tscn/.gd`)**: The base logic that handles path-follow, status effects, and feeding the shader. This is a `@tool` script.
2. **EnemyData (`template_enemy_data.gd`)**: The resource where all stats and visual parameters live.

---

## 1. Creating the Enemy Configuration
1. Right-click your enemy config folder (e.g., `Config/Enemies/`).
2. Select **Create New Resource** and search for `EnemyData`.
3. Save it with a descriptive name (e.g., `heavy_bass_data.tres`).

## 2. Setting Visuals (The Waveform)
1. In the Inspector for your new `.tres` file, assign the **Wave Texture** (the waveform image).
2. Set the **Scroll Speed** (how fast the wave moves horizontally).
3. Set **Max Health**, **Speed**, and **Reward**.
   > [!NOTE]
   > Unlike legacy systems, "Damage" is no longer a variable. Enemies deal damage to the **Peak Meter** equal to their **remaining health** when they leak!

## 3. Customizing Geometry (Shader)
To change the physical appearance of the waveform (rounding or borders) for a specific enemy:
1. Open the enemy scene (e.g., `BasicEnemy.tscn`).
2. Select the `Sprite` node and go to the **Material** section.
3. Adjust **Corner Radius Px** to match your shadow node (Default: 7px).
4. Adjust **Border Width** and **Border Color** to give the waveform a hard outline.

## 4. Spawning
Enemies are spawned by the `SpawnManager` using their `.tres` file path. The system handles all material duplication and stat-loading automatically.
