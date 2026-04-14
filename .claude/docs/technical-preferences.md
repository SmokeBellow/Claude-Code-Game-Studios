# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical)
- **Rendering**: Forward+ (default)
- **Physics**: Jolt Physics (default в Godot 4.6)

## Naming Conventions

- **Classes**: PascalCase (пример: `PlayerController`)
- **Variables/Functions**: snake_case (пример: `move_speed`, `take_damage()`)
- **Signals/Events**: snake_case, прошедшее время (пример: `health_changed`, `enemy_died`)
- **Files**: snake_case совпадает с классом (пример: `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase совпадает с корневым узлом (пример: `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (пример: `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60 FPS
- **Frame Budget**: 16.6 ms
- **Draw Calls**: [TO BE CONFIGURED]
- **Memory Ceiling**: [TO BE CONFIGURED]

## Testing

- **Framework**: GUT (Godot Unit Testing)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]
