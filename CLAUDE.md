# Colyseus GDScript SDK

A pure GDScript client library for Colyseus 0.15.x multiplayer framework, targeting Godot 4.x. Zero dependencies — only Godot built-in classes.

## Project Structure

- `addons/colyseus/src/` — SDK source (what users install)
- `tests/unit/` — GdUnit4 unit tests
- `tests/integration/` — Live server integration tests
- `tests/test_server/` — Docker + Node.js Colyseus test server for integration tests
- `examples/` — Usage examples

## Reference Repos

- **Colyseus source**: `~/dev/colyseus` — The full Colyseus monorepo (packages/core, packages/transport, etc). Use this when you need to read server-side protocol source code (Protocol.ts, Room.ts, WebSocketTransport.ts). Do NOT use npm, GitHub, or web fetches to find Colyseus source.

## Tech Stack

- **Language**: GDScript (Godot 4.6)
- **Testing**: GdUnit4 (dev dependency, gitignored — install separately)
- **Integration tests**: Docker + Node.js + Colyseus 0.15.x
- **Dev tooling**: just (command runner)

## Key Architecture Decisions

1. **Zero dependencies** — Only Godot built-in classes: `WebSocketPeer`, `HTTPRequest`, `StreamPeerBuffer`, `RefCounted`. No third-party addons.
2. **Asset Library structure** — SDK lives at `addons/colyseus/` so it extracts cleanly from the Godot Asset Library. `.gitattributes` controls what ships.
3. **class_name references** — SDK source uses `class_name` for cross-file references, not `res://` paths. This makes the SDK relocatable.

## Dev Workflow

Run `just` to see all available commands. Key recipes:

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

## Testing Strategy

1. **Unit tests** (GdUnit4) — Protocol encoding/decoding, schema deserialization, client/room lifecycle
2. **Integration tests** (GdUnit4 + Docker) — Full protocol against a real Colyseus server

GdUnit4 is a dev dependency. It's gitignored — install it into `addons/gdUnit4/` before running tests.

## Commits

- **Logically sized**: One commit per logical change — not one per file or step. A feature and its tests belong in one commit.
- **Always working**: Every commit must leave all tests passing. The definition of done: `just test` passes.
- **No micro-commits**: Don't commit after every small edit. Accumulate related changes and commit once the unit of work is complete and verified.
- **No merge commits, no squash commits**: Keep a clean, linear history.
- **Good messages**: Concise subject line describing *what* and *why*, not a list of files touched. Use conventional commits (`feat`, `fix`, `refactor`, `docs`, `test`).
- Do **not** include a `Co-authored-by:` line.
