#!/bin/bash

# This script is launched by the Swift launcher stub and manages the backend and frontend processes
# Removed 'set -e' to handle errors gracefully instead of failing immediately

SCRIPT_DIR_MACOS="$(cd "$(dirname "$0")" && pwd)" # Will be in Basil.app/Contents/Resources/
APP_RESOURCES_DIR="$SCRIPT_DIR_MACOS"  # Since this script will be in Resources
APP_SUPPORT_DIR="${APP_SUPPORT_DIR:-$APP_RESOURCES_DIR/AppSupport}" # Use env var if set by Swift launcher
LOG_DIR="$APP_SUPPORT_DIR/logs"
LOG_FILE="$LOG_DIR/basil_master_launcher.log"

mkdir -p "$LOG_DIR"

log_msg() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Redirect stdout/stderr to the log file
exec > "$LOG_FILE" 2>&1

log_msg "================ Main Controller Script Starting ================"
log_msg "Script Dir: $SCRIPT_DIR_MACOS"
log_msg "App Resources Dir: $APP_RESOURCES_DIR"
log_msg "App Support Dir: $APP_SUPPORT_DIR"

# Write our PID for the Swift launcher to find
echo $$ > "$APP_SUPPORT_DIR/.main_controller.pid"
log_msg "Written PID $$ to $APP_SUPPORT_DIR/.main_controller.pid"

BACKEND_DIR="$APP_RESOURCES_DIR/backend"
BACKEND_SCRIPT_PATH="$BACKEND_DIR/run_backend.sh"
FRONTEND_APP_PATH="$APP_RESOURCES_DIR/BasilClient.app"
SERVER_PORT_FILE="$APP_SUPPORT_DIR/server_port"
BACKEND_PID_FILE="$APP_SUPPORT_DIR/.basil_backend.pid"
UVICORN_ACTUAL_PID_FILE="$APP_SUPPORT_DIR/.uvicorn_actual.pid"

# Function to kill processes on specific ports
kill_port_processes() {
    local port=$1
    log_msg "Checking for processes on port $port..."
    local pids=$(lsof -ti:$port 2>/dev/null || true)
    if [ -n "$pids" ]; then
        log_msg "Found processes on port $port: $pids"
        for pid in $pids; do
            log_msg "Killing process $pid on port $port"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                log_msg "Force killing process $pid"
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    else
        log_msg "No processes found on port $port"
    fi
}

# Function to kill old Basil processes
kill_old_basil_processes() {
    log_msg "Cleaning up old Basil processes..."
    
    # Kill old BasilClient processes
    local basil_client_pids=$(pgrep -f "BasilClient" 2>/dev/null || true)
    if [ -n "$basil_client_pids" ]; then
        log_msg "Found old BasilClient processes: $basil_client_pids"
        for pid in $basil_client_pids; do
            # Verify the process still exists before trying to kill it
            if kill -0 "$pid" 2>/dev/null; then
                log_msg "Killing old BasilClient process $pid"
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done
        sleep 2
    fi
    
    # Kill old backend processes - but be more specific to avoid killing our own
    # Look for uvicorn processes that are NOT from the current app bundle
    local backend_pids=$(ps aux | grep -E "uvicorn.*basil" | grep -v "$(pwd)" | awk '{print $2}' 2>/dev/null || true)
    if [ -n "$backend_pids" ]; then
        log_msg "Found old backend processes from different locations: $backend_pids"
        for pid in $backend_pids; do
            # Verify the process still exists and is actually a uvicorn process
            if kill -0 "$pid" 2>/dev/null && ps -p "$pid" -o comm= | grep -q "python" 2>/dev/null; then
                log_msg "Killing old backend process $pid"
                kill -TERM "$pid" 2>/dev/null || true
            else
                log_msg "Skipping stale PID $pid (process no longer exists or not python)"
            fi
        done
        sleep 2
    fi
    
    # Kill processes using common ports
    kill_port_processes 8000
    kill_port_processes 8001
    kill_port_processes 8080
}

# Clean up old port file and processes
rm -f "$SERVER_PORT_FILE"
kill_old_basil_processes

# Simplified cleanup function - most cleanup is now handled by Swift launcher
cleanup() {
    log_msg "Main controller script cleanup initiated..."
    # Remove our own PID file
    rm -f "$APP_SUPPORT_DIR/.main_controller.pid"
    log_msg "Main controller script cleanup completed"
}

trap cleanup EXIT

log_msg "Starting backend from $BACKEND_DIR..."
# Pass our AppSupport server_port file location AND AppSupport directory to run_backend.sh
# Redirect stdout and stderr of run_backend.sh itself to /dev/null to keep master log clean
if cd "$BACKEND_DIR" && ./run_backend.sh --port-file "$SERVER_PORT_FILE" --app-support-dir "$APP_SUPPORT_DIR" > /dev/null 2>&1 & then
    BACKEND_PID=$!
    echo $BACKEND_PID > "$BACKEND_PID_FILE"
    log_msg "Backend started with PID: $BACKEND_PID. PID stored in $BACKEND_PID_FILE."
else
    log_msg "ERROR: Failed to start backend script"
    exit 1
fi

# Health check for backend
MAX_ATTEMPTS=60 # Approx 60 seconds (60 * 1s interval)
HEALTH_CHECK_URL="http://127.0.0.1" # Port will be appended
HEALTH_CHECK_SUCCESSFUL=false

log_msg "Waiting for backend to be healthy (port file: $SERVER_PORT_FILE)..."

for i in $(seq 1 $MAX_ATTEMPTS)
do
    if [ -f "$SERVER_PORT_FILE" ]; then
        ACTUAL_PORT=$(cat "$SERVER_PORT_FILE")
        log_msg "Port file found. Backend listening on port: $ACTUAL_PORT. Checking health endpoint..."
        # Check if backend process is still running
        if ! kill -0 $BACKEND_PID 2>/dev/null; then
            log_msg "ERROR: Backend process (PID $BACKEND_PID) died during health check."
            HEALTH_CHECK_SUCCESSFUL=false
            break
        fi
        # Check health endpoint - don't fail script if curl fails
        if curl --silent --fail "$HEALTH_CHECK_URL:$ACTUAL_PORT/health" > /dev/null 2>&1; then
            log_msg "Backend health check successful on port $ACTUAL_PORT."
            HEALTH_CHECK_SUCCESSFUL=true
            BACKEND_URL="$HEALTH_CHECK_URL:$ACTUAL_PORT"
            break
        else
            log_msg "Backend health check failed (attempt $i/$MAX_ATTEMPTS) on port $ACTUAL_PORT. Retrying in 1 sec..."
        fi
    else
        log_msg "Port file $SERVER_PORT_FILE not found yet (attempt $i/$MAX_ATTEMPTS). Retrying in 1 sec..."
    fi
    sleep 1
done

if [ "$HEALTH_CHECK_SUCCESSFUL" = true ]; then
    log_msg "Backend is healthy. Launching frontend client..."
    FRONTEND_EXEC_PATH="$FRONTEND_APP_PATH/Contents/MacOS/BasilClient"
    if [ -x "$FRONTEND_EXEC_PATH" ]; then
        log_msg "Executing: $FRONTEND_EXEC_PATH --backend-url $BACKEND_URL"
        
        # Launch frontend (BasilClient) with its output going to a separate log file
        FRONTEND_LOG_FILE="$LOG_DIR/basil_client.log"
        # Set BASIL_BUNDLED environment variable for frontend
        if env BASIL_BUNDLED=true "$FRONTEND_EXEC_PATH" --backend-url "$BACKEND_URL" >> "$FRONTEND_LOG_FILE" 2>&1 & then
            FRONTEND_PID=$!
            log_msg "Frontend (BasilClient) launched with PID: $FRONTEND_PID. Log: $FRONTEND_LOG_FILE"
        else
            log_msg "ERROR: Failed to launch frontend"
        fi
    else
        log_msg "ERROR: Frontend executable not found or not executable at $FRONTEND_EXEC_PATH"
        sleep 3
    fi
else
    log_msg "Backend failed to start or become healthy. Frontend will not be launched."
    sleep 3
fi

# Wait for background jobs
wait
log_msg "Main Controller Script Exiting." 