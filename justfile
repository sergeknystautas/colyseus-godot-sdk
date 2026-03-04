# Colyseus GDScript SDK — Developer Workflow
# Run `just` to see all available commands.

# Default Godot binary (override with GODOT=/path/to/godot)
godot := env("GODOT", if os() == "macos" { "/Applications/Godot.app/Contents/MacOS/Godot" } else { "godot" })

# Show all available commands
default:
    @just --list

# Check all required tools are installed
doctor:
    #!/usr/bin/env bash
    set -euo pipefail
    ok=true
    check() {
        if command -v "$1" &>/dev/null; then
            printf "  %-12s %s\n" "$1" "$($2)"
        else
            printf "  %-12s MISSING\n" "$1"
            ok=false
        fi
    }
    echo "Prerequisites:"
    check just "just --version"
    if [[ -x "{{ godot }}" ]]; then
        printf "  %-12s %s\n" "godot" "$({{ godot }} --version 2>/dev/null || echo 'present')"
    elif command -v godot &>/dev/null; then
        printf "  %-12s %s\n" "godot" "$(godot --version 2>/dev/null || echo 'present')"
    else
        printf "  %-12s MISSING\n" "godot"
        ok=false
    fi
    check docker "docker --version"
    echo ""
    if [[ -d "addons/gdUnit4" ]]; then
        echo "GdUnit4: installed"
    else
        echo "GdUnit4: NOT INSTALLED (copy into addons/gdUnit4/)"
        ok=false
    fi
    echo ""
    if $ok; then
        echo "All required tools found."
    else
        echo "Some tools are missing. Install them before continuing."
        exit 1
    fi

# --- Test ---

# Run unit tests (GdUnit4)
test-unit:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ justfile_directory() }}"
    if [[ ! -d ".godot" ]]; then
        echo "First run: importing project..."
        "{{ godot }}" --headless --import 2>/dev/null || true
    fi
    echo "Running unit tests..."
    "{{ godot }}" --headless --path "{{ justfile_directory() }}" \
        -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
        --ignoreHeadlessMode \
        -a "res://tests/unit" 2>&1 | grep -v "ObjectDB instances leaked\|resources still in use\|at: cleanup\|at: clear"
    exit "${PIPESTATUS[0]}"

# Run integration tests (Docker test server + GdUnit4)
test-integration:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ justfile_directory() }}"
    IMAGE_NAME="colyseus-test-server"
    CONTAINER_NAME="colyseus-integration-test"
    PORT=2570
    HEALTHZ_URL="http://localhost:${PORT}/healthz"
    MAX_WAIT=30
    cleanup() {
        echo "Stopping test server..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    }
    trap cleanup EXIT
    echo "Building test server..."
    docker build -t "$IMAGE_NAME" tests/test_server/
    echo "Starting test server on port ${PORT}..."
    docker run -d -p "${PORT}:${PORT}" --name "$CONTAINER_NAME" "$IMAGE_NAME"
    echo "Waiting for server to be ready..."
    for i in $(seq 1 "$MAX_WAIT"); do
        if curl -s -f "$HEALTHZ_URL" > /dev/null 2>&1; then
            echo "Server ready after ${i}s"
            break
        fi
        if [ "$i" -eq "$MAX_WAIT" ]; then
            echo "Server failed to start after ${MAX_WAIT}s"
            docker logs "$CONTAINER_NAME"
            exit 1
        fi
        sleep 1
    done
    echo "Running integration tests..."
    if [[ ! -d ".godot" ]]; then
        "{{ godot }}" --headless --import 2>/dev/null || true
    fi
    "{{ godot }}" --headless --path "{{ justfile_directory() }}" \
        -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
        --ignoreHeadlessMode \
        -a "res://tests/integration" 2>&1 | grep -v "ObjectDB instances leaked\|resources still in use\|at: cleanup\|at: clear"
    exit "${PIPESTATUS[0]}"

# Run all tests
test: test-unit
