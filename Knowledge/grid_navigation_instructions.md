# Grid Navigation Instructions

This document explains how to set up enemy navigation in **TD-Prototype** using the **AStarGrid2D** system. We have moved away from manual geometric splines (Path2D) to a more dynamic grid-based logic.

## 1. Core Concepts

The system uses a **19x12** grid (84px tiles for a 1536x1024 workspace) where:
- **Wall Tiles**: Are automatically marked as "solid" in the AStar grid. Enemies cannot walk through them.
- **Path Tiles**: Are reachable (Source ID 1 by default).
- **Spawn Tiles**: The starting coordinates for waves (Supports 1–3 distinct entry points).
- **Goal Tile**: The single exit destination all enemies must reach.
- **Merge Point**: An internal coordinate where secondary paths converge onto the primary path.

---

## 2. Setting Up Navigation in a Level

Spawn and goal positions are defined by **Terrain Tags** — `Marker2D` nodes baked into the layout `.tscn` by the **Maze Generator** tool. You no longer define coordinates manually in StemData.

### Terrain Tag Nodes
When you click **Save to Disk** in the `MazeGenerator` tool inspector, a `TerrainTags` node is automatically created inside the saved layout scene with these children:
-   **`Spawn_0`, `Spawn_1`, ...** — One `Marker2D` per entrance, positioned at the on-grid edge tile.
-   **`Goal`** — A single `Marker2D` at the exit tile.

### Configuring Spawn Instructions
1.  Open your **StemData** `.tres` file.
2.  Expand the `Spawns` array and create or edit a `SpawnInstruction`.
3.  Set **Spawn Location Tag** to the desired entry: `"Spawn_0"`, `"Spawn_1"`, etc., or leave it as `"Random"` to pick a random entrance at runtime.
4.  At runtime, `BaseStage` reads the layout scene's `TerrainTags`, caches the positions, and resolves each tag on spawn.

---

### Handling Convergence
Because AStar finds the single shortest path, distribution is now handled by the **Maze Generator**'s topology:
- **Primary Lane:** Carves a direct route from Spawn 0 to the Exit.
- **Secondary Lanes:** Carve from Spawn 1/2 toward the **Merge Point** and stop on contact with the primary lane.
- **Visual Crossing:** Lanes may naturally cross or overlap depending on the merge point's location.

---

## 4. Sub-Stepping Movement
Movement is mathematically calculated to be "corner-perfect." 

- **At 1x Speed:** Enemies follow the shortest path with smooth steering.
- **At 12x Speed:** The "Sub-Stepper" logic in `template_enemy.gd` ensures enemies don't overshoot corners or "tunnel" through walls by consuming the path distance segment-by-segment in a single frame.

---

## 5. Path Standards (Insulation Rules)
To ensure the game is readable and tower placement is fair, all generated mazes MUST follow these standards:
- **Strict 1-Tile Width:** Paths never form 2x2 "clumps."
- **2-Tile Clearance:** Parallel paths must have a minimum of 2 wall tiles between them to prevent towers from "double-dipping" too easily without a deliberate strategy.
- **Guaranteed Entrance/Exit:** All paths are forced to run straight for 2 tiles when entering or exiting the grid.

---

## 💡 Tips for Level Designers
- **Maze Layout:** Use the `@tool` generator to iterate quickly. Ensure the `merge_point` is centrally located for interesting lane overlaps.
- **Reliability:** The generator includes an auto-retry loop. If a valid path cannot be found for all spawns, it will automatically attempt a new seed.
- **Blocked Paths:** If a path is blocked (e.g., by a future tower system), the AStar system will automatically reroute enemies.
