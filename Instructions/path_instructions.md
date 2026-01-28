# Path Instructions

This document explains how to set up enemy paths and branching logic in **TD-Prototype** using Godot's built-in `Path2D` system and the custom `path_data.gd` logic.

## Core Components

The pathing system relies on three parts:
1.  **Path2D Nodes**: Define the actual geometric curve the enemies follow.
2.  **PathFollow2D (Pooled)**: Managed by the `ObjectPoolManager`, these internal nodes handle the math of "walking" along the `Path2D`.
3.  **PathData (`path_data.gd`)**: A helper script attached to `Path2D` nodes that enables branching.

---

## 1. Creating a New Path

### Step-by-Step
1.  In your level scene, locate the **Paths** node (nested under `Node2D`).
2.  Right-click the **Paths** node and select **Add Child Node > Path2D**.
3.  Give the node a descriptive name (e.g., `SpawnMain`, `BranchSouth`, `GateEnd`).
4.  **Draw the Curve**: 
    -   Select the `Path2D` node.
    -   Use the Toolbar at the top of the 2D Viewport to add points.
    -   **Important**: Click "Add Point" (pen icon) and click in the viewport to trace the trail you want enemies to follow.
5.  **Placement**: Ensure the first point of your path starts exactly where the previous path ended (or where enemies should spawn).

---

## 2. Enabling Branching Logic

By default, an enemy will simply stop when it reaches the end of a `Path2D`. To make them continue onto a new path, you must use `path_data.gd`.

### Step-by-Step
1.  Select your `Path2D` node.
2.  In the Inspector, locate the **Script** property and drag/drop `res://Levels/TemplateLevel/path_data.gd` into it.
3.  A new **Branches** property will appear in the Inspector.
4.  **Define Branches**:
    -   Expand the **Branches** array.
    -   Add an element for each possible path the enemy can choose next.
    -   Assign the `NodePath` to the next `Path2D` node (e.g., `../End01`).

### How Decision Making Works
-   When an enemy reaches the 100% progress mark on its current path, `TemplateLevel` checks the `branches` array.
-   If multiple branches exist, the game **randomly picks one** for the enemy.
-   The enemy is then seamlessly transferred to the start of the new path.

---

## 3. Reaching the Goal (GameOver Logic)

A path is considered a **Terminal Path** if it has no script attached or if its `branches` array is empty.

-   **Goal Action**: When an enemy reaches the end of a terminal path, it triggers the `reached_goal` function.
-   **Damage**: The player takes damage based on the enemy's `damage` value defined in its `EnemyData`.
-   **Cleanup**: The enemy plays its "death/goal" animation and is returned to the object pool.

---

## 💡 Pro-Tips for Level Designers

-   **Visual Organization**: Group your paths logically. Use names like `SpawnA_01`, `SpawnA_02` for segments of the same main route.
-   **Y-Sorting**: If paths cross over each other, ensure their `z_index` or parent sorting allows enemies to appear at the correct depth.
-   **Flying Paths**: For flying units, create separate `Path2D` nodes with a higher `z_index` (e.g., `10`) to distinguish them from ground troops.
-   **Overlapping Points**: To ensure visual smoothness, the last point of "Path A" should be at the same pixel coordinates as the first point of "Path B".
