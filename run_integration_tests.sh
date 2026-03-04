#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="colyseus-test-server"
CONTAINER_NAME="colyseus-integration-test"
PORT=2570
HEALTHZ_URL="http://localhost:${PORT}/healthz"
MAX_WAIT=30

# Cleanup on exit (success or failure)
cleanup() {
    echo "Stopping test server..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# Build the Docker image
echo "Building test server..."
docker build -t "$IMAGE_NAME" tests/test_server/

# Start the container
echo "Starting test server on port ${PORT}..."
docker run -d -p "${PORT}:${PORT}" --name "$CONTAINER_NAME" "$IMAGE_NAME"

# Wait for healthz
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

# Run integration tests
echo "Running integration tests..."
./run_tests.sh integration
