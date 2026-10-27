# Architecture Audit — Kultura't Tradisyon

## Scope and confidence

This audit is based on the repository's GDScript and scene structure on `main`. The project has not been launched in Godot during this review, so findings are static-analysis observations rather than runtime-verified defects.

## Current architecture

The project is best described as a hybrid of MVC-inspired separation and scene/component composition.

### Areas with useful separation

- `scripts/kitchen/kitchen_task_model.gd`: ingredient definitions, validation, and task progress rules.
- `scripts/kitchen/kitchen_task_controller.gd`: coordinates player input, task flow, dialogue, and overlays.
- `scripts/UI/journal_overlay.gd`: presents journal findings and handles journal navigation.
- Scene files encapsulate rooms and UI overlays.

### Inconsistencies identified

1. **Living-room story data was embedded in an interaction script.** This mixed content definitions with input handling and dialogue orchestration. The first refactor moves that data into `scripts/living room/heritage_story_catalog.gd`.
2. **The kitchen controller still owns several presentation details.** It dynamically builds recipe/pot overlays and also coordinates progress. This is workable for the current scope, but it has a broad responsibility and should be split only after runtime behavior is covered by tests.
3. **Shared progress is stored as metadata on the HUD autoload.** This survives room changes, but makes the HUD a general-purpose state store. A future `GameState`/progress service should own persistent gameplay state, with HUD responsible for display and input.
4. **Scene interactions use direct node-path lookups and string method names.** These are convenient but fragile when scene nodes or methods are renamed. Prefer exported NodePaths, typed references, signals, and small interfaces for important cross-component links.
5. **There are placeholder scripts.** `scripts/backyard/backyard.gd`, `scripts/HUD/Hotbar.gd`, and `scripts/HUD/settings.gd` contain empty lifecycle methods. Remove them if unused or implement them when their owning feature is added.
6. **Input and presentation are sometimes combined.** The living-room script still handles pixel-hit testing, dialogue sequencing, persistent progress updates, and object state. These responsibilities should be separated gradually to avoid a risky rewrite.
7. **No automated project validation was run.** A Godot editor import, parse check, and manual playthrough are still required.

## Target responsibility map

- **Models / data resources:** story catalog, task definitions, progress validation and state.
- **Controllers:** interpret interaction requests, coordinate dialogue/task transitions, and update models.
- **Views:** journal, dialogue, recipe and pot overlays; render state and emit user intent.
- **Reusable components:** opaque-pixel hit testing, interaction prompts, fade transitions, and shared overlay behavior where repeated.
- **Game state service:** persistent collected items and story/task progress, decoupled from the HUD.
- **HUD:** display inventory/progress and emit signals; it should not become the authoritative owner of every gameplay system's state.

## Safe migration order

1. Extract static content/data without changing dialogue text or progression (started: heritage story catalog).
2. Add typed signals/interfaces at component boundaries.
3. Move persistent gameplay metadata from HUD into a dedicated state service, preserving existing keys and save/restore behavior.
4. Split kitchen overlay presentation from task orchestration.
5. Extract common interaction/hit-testing utilities only where multiple scripts share identical behavior.
6. Validate in Godot after each step; keep each refactor small and reversible.

## Validation checklist

- Project opens and imports without parse/resource errors.
- Each of the 11 living-room stories can be viewed once and recorded once.
- Living-room completion and kitchen introduction still gate each other correctly.
- Ingredient collection, inventory fade-in, drag-to-pot, completion dialogue, and room re-entry persistence still work.
- Journal displays four findings per spread and navigation handles incomplete final spreads.
- HUD navigation, cursor behavior, dialogue locking, and room transitions remain unchanged.

## GameState service migration

Implemented the first migration step:

- Added `scripts/autoload/game_state.gd` and registered it as the `GameState` autoload.
- Moved living-room heritage visit/record/completion flags, journal findings, camera/journal collection flags, inventory data, and kitchen introduction/ingredient/pot progress into the service.
- Updated living-room, kitchen, kitchen-task model/controller, and HUD scripts to read and write persistent gameplay progress through `GameState`.
- Added persistent runtime pot-placement IDs so a room change does not lose which ingredients were already placed.

Important limitation: this service currently persists in memory across scene/room changes, not across closing and reopening the game. Save-file persistence is a separate future step. Godot import/parse checks and a complete gameplay regression pass have not yet been run; verify the listed validation checklist before treating this migration as runtime-tested.
