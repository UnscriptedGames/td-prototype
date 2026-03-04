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

Instead of drawing curves, you now simply define coordinates in the **SpawnInstruction** resource inside your **StemData**.

### Defining Spawn Points
1.  Open your **Level/Layout Scene**.
2.  Determine the grid coordinates of your primary and secondary entrances.
3.  In your **StemData** resource, set the `spawns` array to these Vector2i coordinates.

### Defining the Exit
1.  Set the `goal_x` and `goal_y` in the `maze_generator.gd` tool.
2.  All enemies automatically navigate towards this single goal using AStar.

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
