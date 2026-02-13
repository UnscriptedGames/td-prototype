# Enemy Creation & Configuration Instructions

This document explains the technical architecture and step-by-step process for creating new enemies in **TD-Prototype**.

## Architecture & Data Hierarchy

Enemies use a data-driven approach to support varied stats and visual "variants" (colors/types) using a single scene:

1.  **TemplateEnemy (`template_enemy.tscn/.gd`)**: The base scene and logic. All enemies MUST inherit from this.
2.  **EnemyData (`template_enemy_data.gd`)**: A resource defining stats, variants, and which animations are required.

---

## 1. Creating the Enemy Scene

### Step-by-Step
1.  In the FileSystem, locate `res://Entities/Enemies/_TemplateEnemy/template_enemy.tscn`.
2.  Right-click it and select **New Inherited Scene**.
3.  Save the new scene in its own folder (e.g., `res://Entities/Enemies/Orc/orc_enemy.tscn`).
4.  Select the root node and, in the Inspector, assign your **EnemyData** resource to the `Data` slot.

---

## 2. Animation System (Critical)

The project uses a highly structured animation system to support multi-directional movement and variants.

### Strict Naming Convention
Animations in your `SpriteFrames` resource MUST follow this pattern:
`[variant_name]_[action_name]_[direction]`

*   **Variants**: Names defined in your `EnemyData.variants` array (e.g., `red`, `blue`).
*   **Actions**: Names defined in your `EnemyData.required_actions` array (e.g., `move`, `die`).
*   **Directions**: `north_west` or `south_west`.

**Example Names**:
-   `green_move_south_west`
-   `purple_die_north_west`

### 4-Way Direction Handling
The code automatically handles **East/West** movements by flipping the **West** animations horizontally (`flip_h`). You only need to provide the two base diagonal animations (`north_west` and `south_west`).

---

## 3. Creating & Populating EnemyData (`.tres`)

### Step-by-Step
1.  **Create Resource**:
    -   Right-click in your config folder (e.g., `Config/Enemies`).
    -   Select **Create New > Resource..** and choose **EnemyData**.
2.  **Assign Stats**: Set health, speed, damage, and rewards.
3.  **Define Variants/Actions**:
    -   Add strings to **Variants** (e.g., "tier1", "tier2").
    -   Add strings to **Required Actions** (e.g., "move", "die").
4.  **Link Animations**: Assign a `SpriteFrames` resource containing the correctly named animations.

---

## 💡 Troubleshooting & Validation

-   **Enemy Disappearing?** The `TemplateEnemy.gd` script performs an automated validation check during `_ready`. If even ONE required animation is missing for a variant, it will disable the enemy and push an error to the log.
-   **Variants**: When an enemy spawns, it picks a variant from your `variants` array at random. If you want a specific variant, you can modify the `_variant` selection logic in `template_enemy.gd`.
-   **Flying Units**: Toggle the `is_flying` bool in the `EnemyData`. This handles z-indexing and allows anti-air towers to target them.
-   **Path Offset**: The `max_path_offset` defines how far from the exact center of the path the enemy can walk (to create a "mob" look).
