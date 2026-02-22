# Grid Navigation Instructions

This document explains how to set up enemy navigation in **TD-Prototype** using the **AStarGrid2D** system. We have moved away from manual geometric splines (Path2D) to a more dynamic grid-based logic.

## 1. Core Concepts

The system uses a 24x16 grid where:
- **Wall Tiles**: Are automatically marked as "solid" in the AStar grid. Enemies cannot walk through them.
- **Path Tiles**: Are reachable.
- **Spawn Tiles**: The starting coordinate for a wave.
- **Goal Tiles (Weighted Targets)**: The destinations enemies must reach.

---

## 2. Setting Up Navigation in a Level

Instead of drawing curves, you now simply define coordinates in the **SpawnManager** or **SpawnInstruction**.

### Defining Spawn Points
1.  Open your **Level Scene**.
2.  Determine the grid coordinates of your entrance (e.g., `(0, 8)` for the left edge).
3.  In your **SpawnInstruction** resource, set the `spawn_tile` property to this Vector2i.

### Defining Goals (Weighted Targets)
Levels now support multiple exit points.
1.  Navigate to `Core/Data/Waves/` and create a `WeightedTarget` resource.
2.  Set the **Target Tile** (the exit coordinate).
3.  Set the **Weight** (a higher relative number means more enemies will choose this path).
4.  In your **LevelData** or **Level Scene**, add these targets to the `Weighted Targets` array.

---

## 3. Sub-Stepping Movement
Movement is mathematically calculated to be "corner-perfect." 

- **At 1x Speed:** Enemies follow the shortest path with smooth steering.
- **At 12x Speed:** The "Sub-Stepper" logic ensures enemies don't overshoot corners or "tunnel" through walls. It logically consumes the path distance segment-by-segment in a single frame.

---

## 💡 Tips for Level Designers
- **Maze Layout:** Use the tilemap to create corridors. Ensure there is at least one valid path from spawn to goal, or the enemies will fail to find a path.
- **Randomization:** Use multiple Goal Tiles with equal weights to create branching paths without needing extra logic scripts.
- **Blocked Paths:** If a path is blocked (e.g., by a tower placement if we enabled that in future), the AStar system will automatically reroute enemies in real-time.
