# Scheduled Jules Tasks

This document contains a list of recurring maintenance tasks for the Jules asynchronous agent to perform. Use these prompts to keep the project clean and consistent.

## Task Schedule

| # | Task Name | Category | Frequency | Last Executed |
|:--|:----------|:---------|:----------|:--------------|
| 1 | The Signal Janitor | Memory Management | Weekly / After refactors | — |
| 2 | The Constitution Specialist | Naming & Standards | Every 3–4 features | — |
| 3 | The Documentation Clerk | Project Tracking | Fortnightly / Milestone | — |
| 4 | The Test Architect | Quality Assurance | Per major new system | — |
| 5 | The Typist | Static Typing | Monthly / Pre-break | — |
| 6 | The Inspector | Performance Guard | Bi-weekly | — |
| 7 | The Custodian | Dead Code Cleanup | Per dev phase | — |
| 8 | The UI Architect | Hierarchy Enforcer | Per new UI element | — |
| 9 | The Cartographer | Scene Tree Auditor | Monthly / After restructures | — |

---

## 1. The Signal Janitor (Memory Management)
**Description:** Audits the codebase to ensure all signals are properly disconnected in `_exit_tree()` to prevent memory leaks.
**Frequency:** Weekly or after major system refactors.

### Jules Prompt
```text
Scan all GDScript files in the project. Identify any nodes that connect to signals but do not explicitly disconnect those signals in the `_exit_tree()` function. Provide a list of missing disconnections and, if requested, implement the `_exit_tree()` logic for those files following the "Call Down, Signal Up" pattern from the project constitution.
```

---

## 2. The Constitution Specialist (Naming & Standards)
**Description:** Verifies that all variables, functions, and file names strictly adhere to the `constitution.md` naming and formatting rules.
**Frequency:** After every 3–4 feature implementations.

### Jules Prompt
```text
Review all recently modified scripts and compare them against the rules in `/.antigravity/constitution.md` (specifically Section 3: Coding Standards). Check for:
- Snake_case for functions/variables.
- No abbreviated or single-letter variables (e.g., no 'pos', 'v', 'i').
- Proper private variable prefixing (`_`).
- Correct script section order (Tool/Class/Extends, Signals/Enums/Const, Exports/Vars, Onready, Overrides, Methods).
- Leading/trailing zeroes on all floats (e.g., `0.5` not `.5`).
- Underscores in large numbers (e.g., `1_000_000`).
List any violations and suggest refactors to bring the code into 100% compliance.
```

---

## 3. The Documentation Clerk (Project Tracking)
**Description:** Synchronises newly implemented code features back into the core knowledge briefs to maintain a single source of truth.
**Frequency:** Fortnightly or at the end of a developmental "milestone."

### Jules Prompt
```text
Analyze the current implementation of towers, stage management, and UI systems. Compare the actual code state against all files in the `Knowledge/` folder (including but not limited to `game_brief.md`, `towers_brief.md`, and any `tower_design_*.md` documents). Identify any discrepancies (implemented features not documented, or documented features not yet implemented) and update the markdown files to reflect the current reality of the codebase.
```

---

## 4. The Test Architect (Quality Assurance)
**Description:** Generates boilerplate unit tests for core systems to ensure mathematical and logic stability.
**Frequency:** Once per major new system (e.g., armor/damage rework).

### Jules Prompt
```text
Examine the core logic in `Systems/` and `Towers/`. Create a set of unit test scripts (compatible with the project's testing framework) that specifically validate:
- Damage calculation accuracy against armor types.
- Stage progression and wave completion logic.
- UI state transitions.
Focus on edge cases and ensure no side-effects are introduced.
```

---

## 5. The Typist (Static Typing Enforcer)
**Description:** Audits the codebase for missing return types (e.g., `-> void`) and missing variable type hints (e.g., `var health: int`).
**Frequency:** Monthly or before long breaks in development.

### Jules Prompt
```text
Review all `.gd` scripts in the project. Identify any functions missing explicit return types (like `-> void`, `-> int`, or `-> Node`) and any variables declared without type hints (like `var speed: float = 10.0`). Add the correct static typing to these declarations based on Godot 4 best practices to improve performance and autocomplete accuracy. Ensure no type casting errors are introduced.
```

---

## 6. The Inspector (Performance Guard)
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
```

---

## 7. The Custodian (Dead Code Cleanup)
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
```

---

## 8. The UI Architect (Hierarchy Enforcer)
**Description:** Analyses UI `.tscn` files and scripts to ensure they follow layering and viewport architecture rules.
**Frequency:** Whenever new UI overlays, menus, or HUD elements are introduced.

### Jules Prompt
```text
Review the project's UI structure, specifically focusing on any `.tscn` files that contain a `SubViewport` or `SubViewportContainer`. Check against the architectural rules in `/.antigravity/constitution.md` (Section 4: UI Architecture Rules). Ensure that any UI overlays intended to sit "on top" of a game view are placed as siblings to the `SubViewportContainer` within a shared `Control` wrapper, relying on node tree order instead of hardcoded Z-indexing where possible. Suggest the necessary structural tree changes if violations are found.
```

---

## 9. The Cartographer (Scene Tree Auditor)
**Description:** Cross-references all `NodePath` strings in `.gd` scripts and `.tscn` files against the actual scene tree structure to detect broken references caused by node renames or restructures.
**Frequency:** Monthly or after any significant scene tree restructuring (e.g., SPA refactors, sidebar changes).

### Jules Prompt
```text
Audit the entire project for broken or stale node references. Specifically:
- Compare all `@onready var` declarations and `get_node()` / `$` calls in `.gd` scripts against the actual node paths defined in their corresponding `.tscn` files.
- Identify any `NodePath` properties set within `.tscn` resource files that point to nodes which no longer exist in the tree.
- Flag any `@onready` variables that reference a node path that has been renamed or moved.
Present a list of all mismatches with the current path vs. the expected path. Do NOT auto-fix; propose corrections for review.
```
