GDSCRIPT PROJECT INSTRUCTIONS & STYLE GUIDE
===========================================

## General Formatting
- Use Tabs for indentation (not spaces). (Keeps indentation consistent with Godot's editor and avoids alignment issues.)
- Keep lines under 100 characters (aim for 80 where possible). (Improves readability on smaller screens and in side-by-side views.)
- Use LF line endings, UTF-8 encoding without BOM. (Ensures cross-platform compatibility and avoids encoding issues.)
- One statement per line (except ternary expressions). (Helps with debugging and reading each logic step clearly.)
- Add two blank lines between functions and classes. (Visually separates code blocks for better structure.)
- Separate logical blocks inside functions with one blank line. (Improves flow and highlights related code sections.)

## Comments
- Start all comments with a single space after # or ##. Use ## for section headings (variable groupings) and # for in-line or end-of-line comments. Section headings should be capitalised and describe the purpose (e.g., ## Weapons, not ## variables).
- Prefer full-line comments. Inline comments should be short only. (Keeps logic and explanation separate and clean.)
- Keep comments concise by explaining what the code does, not why it is designed that way. Avoid lengthy, multi-line explanations of concepts and focus on describing the immediate action.
- Code comments must only explain what the code does in its final state. All explanations about the development process—including notes about fixes, refactors, or changes from a previous version—must be kept exclusively in the main chat and omitted from the code blocks.

## Indentation
- One level for nested blocks (e.g. inside loops or functions). (Reflects logical structure and flow of the code.)
- Two levels for multi-line continuations, e.g. long function calls. (Helps distinguish wrapped lines from regular blocks.)
- Single level only for multi-line arrays, dictionaries, and enums. (Keeps data definitions clean and uniform.)

## Naming Conventions
| Element          | Style                   | Example                        |
|------------------|-------------------------|--------------------------------|
| File names       | snake_case              | enemy_spawner.gd               |
| Scene files      | snake_case              | player_ship.tscn, main_menu.tscn|
| Class names      | PascalCase              | class_name EnemySpawner        |
| Node names       | PascalCase              | Player, MainCamera             |
| Functions/Vars   | snake_case              | func deal_damage()             |
| Private Vars     | _snake_case             | var _health                    |
| Constants        | CONSTANT_CASE           | const MAX_SPEED = 100          |
| Enums            | PascalCase/CONSTANT_CASE| enum State { IDLE, MOVING }      |
| Signals          | snake_case (past tense)| signal damage_taken            |

## Code Structure Order
1. @tool, @icon, class_name
2. extends base class
3. Documentation (##)
4. signal declarations
5. enum declarations
6. const declarations
7. Static variables
8. @export variables
9. Regular variables
10. @onready variables
11. _static_init(), then static methods
12. Overridden built-in methods:
    - _init()
    - _enter_tree()
    - _ready()
    - _process()
    - _physics_process()
13. Custom public methods
14. Custom private methods
15. Subclasses

## Best Practices
- Avoid unnecessary parentheses in if/while unless for grouping. (Reduces visual clutter.)
- Use English boolean operators: `and`, `or`, `not`. (Easier to read.)
- Use double quotes "like this" unless 'single quotes' reduce escaping. (Minimises backslashes.)
- Add trailing commas in multi-line arrays/dictionaries/enums for clean diffs. (Simplifies version control.)
- Use type hints when types are unclear, omit them when clearly inferred. (Balances readability with clarity.)
    var health: int = 100       # Explicit type
    var pos := Vector2()        # Inferred type
- Use `as` for safe type casting when retrieving nodes. (Ensures correct type and editor tool support.)
    @onready var label := get_node("MyLabel") as Label
- Always use delta time (`delta`) in movement, physics, or animation calculations. (Ensures consistent behaviour across machines.)
- Use `move_toward(Vector2.ZERO, damping)` when applying velocity-based friction or braking. (Avoids overshooting and removes the need for manual length checks.)
- Disconnect signals in `_exit_tree()` or when no longer needed. (Prevents memory leaks.)
- Use `@onready` for unique scenes; use `_ready()` for instanced scenes. For unique scenes (Player, UI), `@onready` is clean. For scenes instanced many times (bullets, enemies), get node references inside `_ready()` to avoid minor performance overhead.
- Prefer direct method calls over signals for tightly coupled components. (Signals introduce slight overhead.)
- Use short `match` statements or dispatch tables for large enums. (Improves runtime performance.)
- Wrap `print()` statements with debug checks to prevent logging in export builds.
    if OS.is_debug_build():
        print("Debug info")
- Check null safety when using `as` casting or type hints to prevent silent errors.
    @onready var label := get_node("UI/Label") as Label
    assert(label != null)
- Avoid object instantiation in `_process` or loops (e.g., `Vector2()`, `Dictionary()`). (Reduces garbage collection pressure.)
- Cache nodes instead of calling `get_node()` every frame. If nodes exist at startup, use `@onready` vars. If not, cache them in `_ready()` and handle null safely.
- Centralise input checks at the beginning of `_process()` or `_physics_process()` by storing them in local variables.

## Numbers
- Use leading and trailing zeroes in floats: `0.5`, `1.0`. (Prevents confusion with integers.)
- Use underscores for large numbers: `1_000_000`. (Improves readability.)
- Use lowercase hex: `0xffaabb`. (Enhances visual parsing.)

## Project Workflow & Approach
- All instructions and code must be compatible with Godot 4.4.x and verified against the official documentation and provided PDFs. Do not recommend using any deprecated nodes or features.
- Use British English spelling.
- Provide one task at a time and wait for confirmation before proceeding. When debugging, offer only one potential resolution at a time.
- All code and instructions must be beginner-friendly and clearly commented.
- Code blocks must only explain what the code does, not why or how it was changed. Detailed explanations of concepts or design choices must be kept exclusively in the main chat and omitted from the code blocks.
- Propose improvements as suggestions, but do not implement them without explicit confirmation. Always prioritise the user's requested functionality.
- Employ a "call down and signal up" approach for modularity and reduced coupling.
- If multiple methods exist for a task, briefly explain their pros and cons.