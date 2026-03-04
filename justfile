# Colyseus GDScript SDK — Developer Workflow
# Run `just` to see all available commands.

# Default Godot binary (override with GODOT=/path/to/godot)
godot := env("GODOT", if os() == "macos" { "/Applications/Godot.app/Contents/MacOS/Godot" } else { "godot" })

# GdUnit4 version for install-gdunit
gdunit4_version := "v6.1.1"

# Show all available commands
default:
    @just --list

# Install GdUnit4 test framework
install-gdunit:
    #!/usr/bin/env bash
    set -euo pipefail
    VER="{{ gdunit4_version }}"
    echo "Installing GdUnit4 ${VER}..."
    mkdir -p addons/gdUnit4
    curl -sL "https://github.com/MikeSchulze/gdUnit4/archive/refs/tags/${VER}.tar.gz" | \
        tar xz --strip-components=3 -C addons/gdUnit4 "gdUnit4-${VER#v}/addons/gdUnit4"
    echo "GdUnit4 installed to addons/gdUnit4/"

# Remove gitignored dev dependencies
clean:
    rm -rf addons/gdUnit4
    rm -rf .godot

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
    if [[ -f "addons/gdUnit4/plugin.cfg" ]]; then
        installed_ver=$(grep '^version=' addons/gdUnit4/plugin.cfg | cut -d'"' -f2)
        expected_ver="{{ gdunit4_version }}"
        if [[ "v${installed_ver}" == "$expected_ver" ]]; then
            printf "  %-12s %s\n" "GdUnit4" "${installed_ver}"
        else
            printf "  %-12s %s (expected %s, run: just install-gdunit)\n" "GdUnit4" "${installed_ver}" "$expected_ver"
            ok=false
        fi
    else
        printf "  %-12s NOT INSTALLED (run: just install-gdunit)\n" "GdUnit4"
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
test:
    #!/usr/bin/env bash
    set +e
    logfile=$(mktemp)
    summary=""
    failed=false
    for suite in test-unit test-integration; do
        echo ""
        echo "--- $suite ---"
        start=$SECONDS
        just "$suite" 2>&1 | tee -a "$logfile"
        exit_code=${PIPESTATUS[0]}
        elapsed=$((SECONDS - start))
        if [ $exit_code -eq 0 ]; then
            summary="$summary$(printf '  %-25s PASS  %3ds\n' "$suite" "$elapsed")\n"
        else
            summary="$summary$(printf '  %-25s FAIL  %3ds\n' "$suite" "$elapsed")\n"
            failed=true
        fi
    done
    echo ""
    echo "==============================="
    echo "  15 Slowest Tests"
    echo "==============================="
    # Parse per-test timings from GdUnit4 (name PASSED NNms)
    sed 's/\x1b\[[0-9;]*m//g' "$logfile" | \
        grep -E '>\s+\S+.*PASSED\s+[0-9]+ms$' | \
        grep -v 'Statistics:' | \
        sed -E 's/[[:space:]]*PASSED[[:space:]]+([0-9]+)ms$/\t\1/' | \
        sed -E 's/^[[:space:]]*//' | \
        awk -F'\t' '{printf "%06d\t%s\n", $2, $1}' | \
        sort -rn | head -15 | \
        awk -F'\t' '{printf "  %6dms  %s\n", $1+0, $2}'
    rm -f "$logfile"
    echo ""
    echo "==============================="
    echo "  Suite Summary"
    echo "==============================="
    printf "$summary"
    echo "==============================="
    if $failed; then
        echo "  SOME TESTS FAILED"
        exit 1
    else
        echo "  ALL TESTS PASSED"
    fi
