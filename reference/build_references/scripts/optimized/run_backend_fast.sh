#!/bin/bash
# Fast startup mode for Basil backend - minimal initialization

cd "$(dirname "$0")"

# Parse command line arguments
PORT_FILE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --port-file)
            PORT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Find the backend directory (assuming we're in builds/common/scripts/optimized)
BACKEND_DIR="$(find ../../../../builds/outputs -name "backend" -type d | head -n 1)"

if [[ -z "$BACKEND_DIR" || ! -d "$BACKEND_DIR" ]]; then
    echo "❌ Backend directory not found"
    exit 1
fi

cd "$BACKEND_DIR"

# Define log directory
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# Activate virtual environment
source venv/bin/activate

# Set PYTHONPATH
export PYTHONPATH=$(pwd)/src:$PYTHONPATH

# Function to check if a port is available
check_port() {
    local port_to_check=$1
    if nc -z localhost $port_to_check 2>/dev/null; then
        return 1 # Port is in use
    else
        return 0 # Port is available
    fi
}

# Find available port
HOST="${BACKEND_HOST:-127.0.0.1}"
START_PORT="${BACKEND_PORT:-8000}"
MAX_PORT_ATTEMPTS=10
FOUND_PORT=""

echo "🔍 Searching for available port starting from $START_PORT..."
for i in $(seq 0 $MAX_PORT_ATTEMPTS); do
    CURRENT_PORT=$((START_PORT + i))
    if check_port $CURRENT_PORT; then
        PORT=$CURRENT_PORT
        FOUND_PORT="true"
        echo "✅ Port $PORT is available."
        break
    else
        echo "⚠️ Port $CURRENT_PORT is in use."
    fi
done

if [[ -z "$FOUND_PORT" ]]; then
    echo "❌ Error: Could not find available port"
    exit 1
fi

# Write port file immediately
if [[ -n "$PORT_FILE" ]]; then
    mkdir -p "$(dirname "$PORT_FILE")"
    echo "$PORT" > "$PORT_FILE"
    echo "✅ Port $PORT written to $PORT_FILE"
fi

# Start with optimized main if available, otherwise use regular
if [[ -f "src/api/main_optimized.py" ]]; then
    echo "🚀 Starting with optimized backend (lazy loading)..."
    python src/api/main_optimized.py --host $HOST --port $PORT --port-file "$PORT_FILE" &
else
    echo "🚀 Starting with regular backend..."
    uvicorn api.main:app --host $HOST --port $PORT --workers 1 > "$LOG_DIR/api.log" 2>&1 &
fi

UVICORN_PID=$!
echo "Backend PID: $UVICORN_PID"

# Wait for the process
wait "$UVICORN_PID"