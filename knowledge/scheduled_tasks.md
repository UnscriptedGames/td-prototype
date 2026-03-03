# Scheduled Jules Tasks

This document contains a list of recurring maintenance tasks for the Jules asynchronous agent to perform. Use these prompts to keep the project clean and consistent.

## Task Schedule

| # | Task Name | Category | Frequency | Mode | Last Executed |
|:--|:----------|:---------|:----------|:-----|:--------------|
| 1 | The Signal Janitor | Memory Management | Weekly+ | **Interactive** | 2026-03-02 |
| 2 | The Constitution Specialist | Naming & Standards | 3–4 Features | **Review** | — |
| 3 | The Documentation Clerk | Project Tracking | Fortnightly | **Interactive** | 2026-03-03 |
| 4 | The Test Architect | Quality Assurance | Major System | **Interactive** | — |
| 5 | The Typist | Static Typing | Monthly | **Start** | — |
| 6 | The Inspector | Performance Guard | Bi-weekly | **Review** | — |
| 7 | The Custodian | Dead Code Cleanup | Per Phase | **Review** | — |
| 8 | The UI Architect | Hierarchy Enforcer | New UI | **Interactive** | — |
| 9 | The Cartographer | Scene Tree Auditor | Monthly | **Review** | — |

### 🧪 Model Tiering Guide
Use this guide to select the most token-efficient model for each maintenance phase.

| Task # | Category | Execution (Jules) | Review (Antigravity) | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **1** | Logical | 💎 **Pro** | 💎 **Pro** | Memory/lifecycle analysis requires high reasoning. |
| **2** | Syntactic | ⚡ **Flash** | ⚡ **Flash** | Pattern matching for naming conventions. |
| **3** | Contextual | 💎 **Pro** | 💎 **Pro** | Deep code-to-doc analysis is reasoning-heavy. |
| **4** | Logical | 💎 **Pro** | 💎 **Pro** | Logic synthesis for unit tests is high-risk. |
| **5** | Syntactic | ⚡ **Flash** | ⚡ **Flash** / 💎 Pro | Bulk syntax updates; Pro for final safety audit. |
| **6** | Logical | 💎 **Pro** | 💎 **Pro** | Nuanced loop/math optimization. |
| **7** | Syntactic | ⚡ **Flash** | 💎 **Pro** | Cleanup is fast; Pro ensures no broken dependencies. |
| **8** | Structural | ⚡ **Flash** | 💎 **Pro** | Structural checks are fast; review needs context. |
| **9** | Structural | ⚡ **Flash** | 💎 **Pro** | Reference audits are fast; review needs context. |

---

## 🛠️ Jules maintenance task workflow

Follow these steps to safely run maintenance tasks and sync changes back to your project.

### 1. Preparation
1.  **Select Task:** Choose a task from the **Task Schedule** (below).
2.  **Create Branch (Optional):** In your IDE, create a new branch (e.g., `maint/task-name`). This acts as a safety buffer. 

### 2. Configure Jules (Web UI)
1.  **Paste Prompt:** Select your branch and paste the corresponding **Jules Prompt** into the Jules task window.
2.  **Set Recommended Mode:** Look at the **Mode** column in the Task Schedule and set the start button dropdown accordingly:
    -   🚀 **Start:** Get started immediately. Best for low-risk tasks (Typing, Cleanup).
    -   📄 **Review:** Jules generates a plan and waits for your "Yes" before starting.
    -   🔮 **Interactive plan:** Chat with Jules first to clarify goals and target files. **Best for most tasks.**
3.  **Confirm Scope:** If using Interactive, respond to Jules' initial clarification questions (e.g., "Documentation only," "Ignore the `/addons/` folder").

### 3. Review & Approve
1.  **Review Plan:** Jules will provide a multi-step plan. Ensure it targets the correct files and respects project rules.
2.  **Approve:** Click **Approve** (or "Start") to let Jules perform the research and implementation.

### 4. GitHub Merge
1.  **View PR:** Once Jules finishes, click **View PR** to open GitHub.
2.  **Merge:** Review the diff, then click **Merge pull request** followed by **Confirm merge**.
3.  **Delete Branch:** Click **Delete branch** on GitHub to clean up the temporary workspace Jules created.

### 5. Local Sync & Cleanup
1.  **Sync IDE:** In your Source Control sidebar, click **Sync Changes ↓** (or run `git pull`) to bring Jules' work down to your local branch.
2.  **Merge to Main:** Switch to your `main` branch and merge your maintenance branch into it.
3.  **Delete Remote & Local Branch:** After the merge, use the **Delete Remote Branch...** option in your IDE to remove the branch from GitHub, then delete the local branch to keep your workspace clean.

---

## 1. The Signal Janitor (Memory Management) — [Mode: Interactive]
**Description:** Audits the codebase to ensure all signals are properly disconnected in `_exit_tree()` to prevent memory leaks.
**Frequency:** Weekly or after major system refactors.

### Jules Prompt
```text
Scan all GDScript files in the project. Identify any nodes that connect to signals but do not explicitly disconnect those signals in the `_exit_tree()` function. Provide a list of missing disconnections and, if requested, implement the `_exit_tree()` logic for those files following the "Call Down, Signal Up" pattern from the project constitution.

Finally, update the 'Last Executed' column for **Task 1 (The Signal Janitor)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```

---

## 2. The Constitution Specialist (Naming & Standards) — [Mode: Review]
**Description:** Verifies that all variables, functions, and file names strictly adhere to the `constitution.md` naming and formatting rules.
**Frequency:** After every 3–4 feature implementations.

### Jules Prompt
```text
Review all recently modified scripts and compare them against the rules in `.agent/rules/constitution.md` (specifically Section 3: Coding Standards). Check for:
- Snake_case for functions/variables.
- No abbreviated or single-letter variables (e.g., no 'pos', 'v', 'i').
- Proper private variable prefixing (`_`).
- Correct script section order (Tool/Class/Extends, Signals/Enums/Const, Exports/Vars, Onready, Overrides, Methods).
- Leading/trailing zeroes on all floats (e.g., `0.5` not `.5`).
- Underscores in large numbers (e.g., `1_000_000`).
List any violations and suggest refactors to bring the code into 100% compliance.

Finally, update the 'Last Executed' column for **Task 2 (The Constitution Specialist)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```

---

## 3. The Documentation Clerk (Project Tracking) — [Mode: Interactive]
**Description:** Synchronises newly implemented code features back into the core knowledge briefs to maintain a single source of truth.
**Frequency:** Fortnightly or at the end of a developmental "milestone."

### Jules Prompt
```text
Analyze the current implementation of towers, stage management, and UI systems. Compare the actual code state against all files in the `Knowledge/` folder (including but not limited to `game_brief.md`, `towers_brief.md`, and any `tower_design_*.md` documents). Identify any discrepancies (implemented features not documented, or documented features not yet implemented) and update the markdown files to reflect the current reality of the codebase.

Finally, update the 'Last Executed' column for **Task 3 (The Documentation Clerk)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```

---

## 4. The Test Architect (Quality Assurance) — [Mode: Interactive]
**Description:** Generates boilerplate unit tests for core systems to ensure mathematical and logic stability.
**Frequency:** Once per major new system (e.g., armor/damage rework).

### Jules Prompt
```text
Examine the core logic in `Systems/` and `Towers/`. Create a set of unit test scripts (compatible with the project's testing framework) that specifically validate:
- Damage calculation accuracy against armor types.
- Stage progression and wave completion logic.
- UI state transitions.
Focus on edge cases and ensure no side-effects are introduced.

Finally, update the 'Last Executed' column for **Task 4 (The Test Architect)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```

---

## 5. The Typist (Static Typing Enforcer) — [Mode: Start]
**Description:** Audits the codebase for missing return types (e.g., `-> void`) and missing variable type hints (e.g., `var health: int`).
**Frequency:** Monthly or before long breaks in development.

### Jules Prompt
```text
Review all `.gd` scripts in the project. Identify any functions missing explicit return types (like `-> void`, `-> int`, or `-> Node`) and any variables declared without type hints (like `var speed: float = 10.0`). Add the correct static typing to these declarations based on Godot 4 best practices to improve performance and autocomplete accuracy. Ensure no type casting errors are introduced.

Finally, update the 'Last Executed' column for **Task 5 (The Typist)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```

---

## 6. The Inspector (Performance Guard) — [Mode: Review]
**Description:** Scans the `_process()` and `_physics_process()` functions across all scripts to ensure performance best practices.
**Frequency:** Bi-weekly, especially when handling many instances (like projectiles or enemies).

### Jules Prompt
```text
Analyze the `_process` and `_physics_process` loops across the entire codebase. Identify performance bottlenecks such as:
- Calling `get_node()` or `$` inside the loop (should be cached with `@onready`).
- Missing `delta` multiplication for movement or rotation.
- Over-reliance on heavy math operations where simple caching could work.
- Unsafe type casts that do not follow the safe pattern (`as` followed by `assert(node != null)`).
Refactor these sections and provide the updated function bodies as atomic changes. Only use `move_toward()` for velocity damping per the constitution rules.

Finally, update the 'Last Executed' column for **Task 6 (The Inspector)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```

---

## 7. The Custodian (Dead Code Cleanup) — [Mode: Review]
**Description:** Scans the codebase for unused variables, orphan functions, and deprecated logic.
**Frequency:** At the end of every major development phase before committing to main.

### Jules Prompt
```text
Perform a sweeping audit of the repository to identify dead code. Specifically look for:
- Declared variables that are never read from.
- Functions that are defined but never called anywhere in the project.
- Large blocks of commented-out logical instructions.
- Scripts in the project folders that are not attached to any active `.tscn` files.
Present a detailed list of all findings with file paths and line numbers. Do NOT delete any code automatically. Propose each removal as a separate, reviewable change so that each can be approved or rejected individually.

Finally, update the 'Last Executed' column for **Task 7 (The Custodian)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```

---

## 8. The UI Architect (Hierarchy Enforcer) — [Mode: Interactive]
**Description:** Analyses UI `.tscn` files and scripts to ensure they follow layering and viewport architecture rules.
**Frequency:** Whenever new UI overlays, menus, or HUD elements are introduced.

### Jules Prompt
```text
Review the project's UI structure, specifically focusing on any `.tscn` files that contain a `SubViewport` or `SubViewportContainer`. Check against the architectural rules in `/.antigravity/constitution.md` (Section 4: UI Architecture Rules). Ensure that any UI overlays intended to sit "on top" of a game view are placed as siblings to the `SubViewportContainer` within a shared `Control` wrapper, relying on node tree order instead of hardcoded Z-indexing where possible. Suggest the necessary structural tree changes if violations are found.

Finally, update the 'Last Executed' column for **Task 8 (The UI Architect)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```

---

## 9. The Cartographer (Scene Tree Auditor) — [Mode: Review]
**Description:** Cross-references all `NodePath` strings in `.gd` scripts and `.tscn` files against the actual scene tree structure to detect broken references caused by node renames or restructures.
**Frequency:** Monthly or after any significant scene tree restructuring (e.g., SPA refactors, sidebar changes).

### Jules Prompt
```text
Audit the entire project for broken or stale node references. Specifically:
- Compare all `@onready var` declarations and `get_node()` / `$` calls in `.gd` scripts against the actual node paths defined in their corresponding `.tscn` files.
- Identify any `NodePath` properties set within `.tscn` resource files that point to nodes which no longer exist in the tree.
- Flag any `@onready` variables that reference a node path that has been renamed or moved.
Present a list of all mismatches with the current path vs. the expected path. Do NOT auto-fix; propose corrections for review.

Finally, update the 'Last Executed' column for **Task 9 (The Cartographer)** in the 'Task Schedule' table at the top of this document (`Knowledge/scheduled_tasks.md`) with today's date (YYYY-MM-DD).
```
