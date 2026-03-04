#!/usr/bin/env bash
set -euo pipefail

# ── Colyseus GDScript SDK Test Runner ──
# Usage:
#   ./run_tests.sh              # run all tests
#   ./run_tests.sh unit         # run only unit tests
#   ./run_tests.sh integration  # run only integration tests
#   ./run_tests.sh <file>       # run a specific test file (relative to tests/)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Find Godot binary
GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
    if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
        GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
    elif command -v godot &>/dev/null; then
        GODOT="godot"
    else
        echo "Error: Godot not found. Set GODOT=/path/to/godot" >&2
        exit 1
    fi
fi

# Import project on first run (creates .godot/ cache)
if [[ ! -d ".godot" ]]; then
    echo "First run: importing project..."
    "$GODOT" --headless --import 2>/dev/null || true
fi

# Determine test path
TARGET="res://tests"
case "${1:-all}" in
    unit)
        TARGET="res://tests/unit"
        ;;
    integration)
        TARGET="res://tests/integration"
        ;;
    all)
        TARGET="res://tests"
        ;;
    *)
        # Assume it's a specific file path
        if [[ -f "tests/$1" ]]; then
            TARGET="res://tests/$1"
        elif [[ -f "$1" ]]; then
            TARGET="res://$1"
        else
            echo "Error: test not found: $1" >&2
            exit 1
        fi
        ;;
esac

echo "Running tests: $TARGET"
echo "Godot: $GODOT"
echo "──────────────────────────"

# Run tests, filtering out benign Godot engine cleanup warnings
"$GODOT" --headless --path "$SCRIPT_DIR" \
    -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode \
    -a "$TARGET" 2>&1 | grep -v "ObjectDB instances leaked\|resources still in use\|at: cleanup\|at: clear"
exit "${PIPESTATUS[0]}"
