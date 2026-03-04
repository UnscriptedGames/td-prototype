# Grid Navigation Instructions

This document explains how to set up enemy navigation in **TD-Prototype** using the **AStarGrid2D** system. We have moved away from manual geometric splines (Path2D) to a more dynamic grid-based logic.

## 1. Core Concepts

The system uses a **19x12** grid (84px tiles for a 1536x1024 workspace) where:
- **Wall Tiles**: Are automatically marked as "solid" in the AStar grid. Enemies cannot walk through them.
- **Path Tiles**: Are reachable (Source ID 1 by default).
- **Spawn Tiles**: The starting coordinate for a wave.
- **Goal Tiles (Weighted Targets)**: The destinations enemies must reach.

---

## 2. Setting Up Navigation in a Level

Instead of drawing curves, you now simply define coordinates in the **SpawnInstruction** resource inside your **StemData**.

### Defining Spawn Points
1.  Open your **Level/Layout Scene**.
2.  Determine the grid coordinates of your entrance.
3.  In your **SpawnInstruction** resource, set the `spawn_tile` property to this Vector2i.

### Defining Goals (Weighted Targets)
Levels support multiple exit points via the `WeightedTarget` resource.
1.  Create a `WeightedTarget` resource (found in `Core/Data/Waves/`).
2.  Set the **Goal Tile** (the exit coordinate).
3.  Set the **Weight** (relative probability of choice).
4.  Add these to the `weighted_targets` array in your **SpawnInstruction**.

---

## 3. Handling Symmetrical & Branching Paths

AStar finds the single shortest path. To distribute enemies across multiple symmetrical routes, use these strategies:

- **Weighted Target Split**: Place two `WeightedTarget` resources at the exit, offset slightly so one is mathematically closer to each branch.
- **Path Weight Noise**: (Planned) Injecting tiny random costs (e.g., `1.0 + rand * 0.01`) into walkable tiles to disrupt tie-breaking.
- **Intermediary Waypoints**: Use a "Bus" waypoint in the middle of a loop. Direct enemies to the loop first, then to the exit on Arrival.

---

## 4. Sub-Stepping Movement
Movement is mathematically calculated to be "corner-perfect." 

- **At 1x Speed:** Enemies follow the shortest path with smooth steering.
- **At 12x Speed:** The "Sub-Stepper" logic in `template_enemy.gd` ensures enemies don't overshoot corners or "tunnel" through walls by consuming the path distance segment-by-segment in a single frame.

---

## 💡 Tips for Level Designers
- **Maze Layout:** Ensure there is at least one valid path from spawn to goal, or the enemies will fail to find a path.
- **Randomization:** Multiple Goal Tiles in the same area will naturally create distribution due to float-precision tie-breaking and weighting.
- **Blocked Paths:** If a path is blocked (e.g., by a future tower system), the AStar system will automatically reroute enemies.
