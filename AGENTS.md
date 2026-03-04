# Colyseus GDScript SDK

A pure GDScript client library for Colyseus 0.15.x multiplayer framework, targeting Godot 4.x. Zero dependencies — only Godot built-in classes.

## Project Structure

- `addons/colyseus/src/` — SDK source (what users install)
- `tests/unit/` — GdUnit4 unit tests
- `tests/integration/` — Live server integration tests
- `tests/test_server/` — Docker + Node.js Colyseus test server for integration tests
- `examples/` — Usage examples

## Tech Stack

- **Language**: GDScript (Godot 4.6)
- **Testing**: GdUnit4 (dev dependency, gitignored — install separately into `addons/gdUnit4/`)
- **Integration tests**: Docker + Node.js + Colyseus 0.15.x
- **Dev tooling**: just (command runner)

## Dev Workflow

Run `just` to see all available commands:

```bash
just test            # Run all unit tests
just test-unit       # Unit tests only
just test-integration # Integration tests (requires Docker)
just doctor          # Check prerequisites
```

Override the Godot binary: `GODOT=/path/to/godot just test`

## Coding Conventions

- Use typed variables: `var x: float = 0.0`
- `snake_case` for functions and variables, `PascalCase` for classes
- Use signals for async communication
- Zero external dependencies — only Godot built-in classes
- SDK source uses `class_name` for cross-file references, not `res://` paths

## Testing

- Unit tests reference SDK via `res://addons/colyseus/src/...` paths
- Run `just test` before committing — all tests must pass
- GdUnit4 must be installed in `addons/gdUnit4/` (gitignored)

## Commits

- **Logically sized**: One commit per logical change. A feature and its tests belong in one commit.
- **Always working**: Every commit must leave all tests passing (`just test`).
- **No micro-commits**: Accumulate related changes, commit once complete and verified.
- **No merge commits, no squash commits**: Clean, linear history.
- **Good messages**: Conventional commits (`feat`, `fix`, `refactor`, `docs`, `test`). Concise subject describing *what* and *why*.
- Do **not** include a `Co-authored-by:` line.
