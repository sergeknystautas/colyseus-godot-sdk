# Contributing

## Prerequisites

- Godot 4.6+
- Docker (for integration tests)

## Dev Setup

1. Clone the repository
2. Install [GdUnit4](https://mikeschulze.github.io/gdUnit4/) into `addons/gdUnit4/` (via Godot Asset Library or manual download). This directory is gitignored.
3. Open `project.godot` in the Godot editor

## Running Tests

```bash
./run_tests.sh              # all tests
./run_tests.sh unit         # unit tests only
./run_tests.sh integration  # integration tests only (requires test server)
./run_integration_tests.sh  # starts Docker test server + runs integration tests
```

## Code Style

- Typed GDScript: `var x: float = 0.0`
- `snake_case` for functions and variables, `PascalCase` for classes
- Zero external dependencies — only Godot built-in classes
