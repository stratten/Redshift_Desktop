#!/bin/bash

# Function for logging with timestamp
log() {
  # Ensure LOG_DIR is created before trying to log
  if [ -n "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" # Create log directory if it doesn't exist
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
  else
    # Fallback if LOG_DIR somehow isn't set.
    echo "$(date '+%Y-%m-%d %H:%M:%S') - (LOG_DIR_NOT_SET) $1"
  fi
}

# --- Define Log Path ---
# When running from within the bundled Basil.app/Contents/MacOS/Basil script,
# DIR is Basil.app/Contents/MacOS.
# Logs should go into Basil.app/Contents/Resources/AppSupport/logs/
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # This is Basil.app/Contents/MacOS/
LOG_DIR="$SCRIPT_DIR/../Resources/AppSupport/logs" # Relative to MacOS dir
LOG_FILE="$LOG_DIR/launcher_script.log"

# Create the log directory early and clear previous log
mkdir -p "$LOG_DIR"
if [ -f "$LOG_FILE" ]; then
    echo "" > "$LOG_FILE" # Clear previous log
else
    touch "$LOG_FILE" # Ensure file exists if it didn't
fi
# --- End Log Path Definition ---

log "==================== BASIL LAUNCHER SCRIPT STARTING ===================="
log "Script location (SCRIPT_DIR): $SCRIPT_DIR"
log "Logging to: $LOG_FILE"

# Define other common paths relative to SCRIPT_DIR (which is .../MacOS/)
COMMON_DIR_FROM_MACOS="$( cd "$SCRIPT_DIR/../../common" && pwd )" # Heuristic, might be complex if script moved
ROOT_DIR_FROM_MACOS="$( cd "$SCRIPT_DIR/../../../" && pwd )" # Heuristic
LIBS_DIR_FROM_MACOS="$ROOT_DIR_FROM_MACOS/builds/common/dependencies/libs" # Adjusted path

# BUILD_DIR in this context is the MacOS directory itself
BUILD_DIR="$SCRIPT_DIR"

log "Effective Build directory (BUILD_DIR, should be MacOS folder): $BUILD_DIR"
log "Root directory (ROOT_DIR_FROM_MACOS, derived): $ROOT_DIR_FROM_MACOS"

# Set the port for the backend
PORT=8000
log "Using port: $PORT"

# Backend PID file location
BACKEND_PID_FILE="$SCRIPT_DIR/../Resources/AppSupport/backend.pid"
log "Backend PID file will be: $BACKEND_PID_FILE"

# Check for existing backend process and kill it if found
if [ -f "$BACKEND_PID_FILE" ]; then
  OLD_PID=$(cat "$BACKEND_PID_FILE")
  log "Found existing backend PID: $OLD_PID from $BACKEND_PID_FILE, attempting to terminate"
  kill -9 "$OLD_PID" 2>/dev/null || log "No existing process to kill, or kill failed for PID $OLD_PID"
  rm -f "$BACKEND_PID_FILE"
fi

# Set environment variables
export PYTHONUNBUFFERED=1
export QT_MAC_DISABLE_MENUBAR=1
export NSApplicationActivationPolicy=1
# PYTHONPATH should point to the project root where 'src' or 'api' might be.
# If backend is in Basil.app/Contents/Resources/backend/, then project root for it is that dir.
export PYTHONPATH="$BUILD_DIR/../Resources/backend:$BUILD_DIR/../Resources/backend/src:$PYTHONPATH"

# Set path for dynamic libraries - critical for libsox and other dependencies
# LIBS_DIR_FROM_MACOS needs to be accurate or built into the backend's rpath
# $BUILD_DIR/../Resources/backend contains the Python venv and libs
export DYLD_LIBRARY_PATH="$BUILD_DIR/../Resources/backend/venv/lib:$LIBS_DIR_FROM_MACOS:$DYLD_LIBRARY_PATH"
log "Environment variables set"
log "PYTHONPATH: $PYTHONPATH"
log "DYLD_LIBRARY_PATH: $DYLD_LIBRARY_PATH"

# Start the backend using run_backend.sh
# The run_backend.sh is inside Basil.app/Contents/Resources/backend/
BACKEND_SCRIPT_DIR="$BUILD_DIR/../Resources/backend"
BACKEND_SCRIPT_PATH="$BACKEND_SCRIPT_DIR/run_backend.sh"

if [ -f "$BACKEND_SCRIPT_PATH" ]; then
  log "Starting backend process using: $BACKEND_SCRIPT_PATH with port $PORT"
  chmod +x "$BACKEND_SCRIPT_PATH" # Ensure it's executable

  # Run in a subshell to manage cd and backgrounding correctly
  (cd "$BACKEND_SCRIPT_DIR" && ./run_backend.sh --host 127.0.0.1 --port $PORT --log-level info) &
  BACKEND_PID=$!
  log "Backend script started with PID: $BACKEND_PID"
else
  log "ERROR: Backend script not found at $BACKEND_SCRIPT_PATH"
  exit 1
fi

# Store the backend PID
echo "$BACKEND_PID" > "$BACKEND_PID_FILE"
log "Stored backend PID $BACKEND_PID to $BACKEND_PID_FILE"

# Server port file (primarily for this script's health check, Swift gets URL as arg)
SERVER_PORT_FILE="$SCRIPT_DIR/../Resources/AppSupport/server_port"
mkdir -p "$(dirname "$SERVER_PORT_FILE")"
echo "$PORT" > "$SERVER_PORT_FILE"
log "Writing port $PORT to $SERVER_PORT_FILE"

# Health check loop for the backend
MAX_HEALTH_CHECKS=15
HEALTH_CHECK_INTERVAL=5
HEALTH_CHECK_SUCCESSFUL=false

log "Waiting for backend to initialize (up to $((MAX_HEALTH_CHECKS * HEALTH_CHECK_INTERVAL)) seconds)..."

for i in $(seq 1 $MAX_HEALTH_CHECKS); do
  log "Health check attempt $i of $MAX_HEALTH_CHECKS..."
  if kill -0 "$BACKEND_PID" 2>/dev/null; then
    log "Backend process (PID: $BACKEND_PID) is running. Checking health endpoint..."
    if command -v curl >/dev/null 2>&1; then
      HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/health" || echo "000")
      HEALTH_BODY=$(curl -s "http://127.0.0.1:$PORT/health" 2>/dev/null || echo "Failed to get body")
      log "Health check HTTP status: $HEALTH_RESPONSE, Body: $HEALTH_BODY"
      if [[ "$HEALTH_RESPONSE" -eq 200 && "$HEALTH_BODY" == *"healthy"* ]]; then
        log "✅ Backend health check successful!"
        HEALTH_CHECK_SUCCESSFUL=true
        break
      else
        log "Backend health check attempt $i failed (Status: $HEALTH_RESPONSE). Retrying in $HEALTH_CHECK_INTERVAL seconds..."
      fi
    else
      log "curl not available, cannot perform HTTP health check. Assuming backend is okay if process is running."
      HEALTH_CHECK_SUCCESSFUL=true 
      break
    fi
  else
    log "ERROR: Backend process (PID: $BACKEND_PID) is NOT running after attempt $i."
    HEALTH_CHECK_SUCCESSFUL=false
    break # Exit loop if process died
  fi
  sleep $HEALTH_CHECK_INTERVAL
done

if [ "$HEALTH_CHECK_SUCCESSFUL" = false ]; then
  log "❌ ERROR: Backend did not become healthy after $MAX_HEALTH_CHECKS attempts."
  log "Terminating backend process $BACKEND_PID due to health check failure."
  kill -9 "$BACKEND_PID" 2>/dev/null
  exit 1
fi

log "Backend initialized and health check passed."

# Start the frontend
# BasilClient.app is in Basil.app/Contents/Resources/
FRONTEND_APP_PATH="$SCRIPT_DIR/../Resources/BasilClient.app"
FRONTEND_EXEC_PATH="$FRONTEND_APP_PATH/Contents/MacOS/BasilClient"
BACKEND_URL="http://127.0.0.1:$PORT"

if [ -f "$FRONTEND_EXEC_PATH" ]; then
  log "Starting frontend process: $FRONTEND_EXEC_PATH with backend URL: $BACKEND_URL"
  # DYLD_LIBRARY_PATH for frontend - ensure it can find any necessary frameworks/dylibs
  # If BasilClient.app is self-contained or uses @rpath, this might not be strictly needed for it.
  # However, if it loads plugins or libs from backend or common libs, it might be.
  # Keeping it for now, pointing to relevant places.
  DYLD_LIBRARY_PATH_FOR_FRONTEND="$BUILD_DIR/../Resources/backend/venv/lib:$LIBS_DIR_FROM_MACOS:$DYLD_LIBRARY_PATH"
  
  log "Frontend DYLD_LIBRARY_PATH will be: $DYLD_LIBRARY_PATH_FOR_FRONTEND"
  env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH_FOR_FRONTEND" "$FRONTEND_EXEC_PATH" "$BACKEND_URL"
  FRONTEND_EXIT_CODE=$? # Capture exit code
  log "Frontend exited with code: $FRONTEND_EXIT_CODE"
else
  log "ERROR: Frontend executable not found at $FRONTEND_EXEC_PATH"
  log "Terminating backend PID $BACKEND_PID"
  kill -9 "$BACKEND_PID" 2>/dev/null
  exit 1
fi

# When the frontend exits, kill the backend
log "Cleaning up processes and files after frontend exit."
if [ -f "$BACKEND_PID_FILE" ]; then
  # Read PID again in case it was overwritten or script restarted
  LATEST_BACKEND_PID=$(cat "$BACKEND_PID_FILE")
  if [ -n "$LATEST_BACKEND_PID" ]; then
    log "Terminating backend PID: $LATEST_BACKEND_PID from $BACKEND_PID_FILE"
    kill -9 "$LATEST_BACKEND_PID" 2>/dev/null
    rm -f "$BACKEND_PID_FILE"
  else
    log "WARN: Backend PID file $BACKEND_PID_FILE was empty."
  fi
else
  log "WARN: Backend PID file $BACKEND_PID_FILE not found at cleanup."
  # As a fallback, try to kill the PID captured at launch if it's still set
  if [ -n "$BACKEND_PID" ]; then
    log "Attempting to kill original backend PID $BACKEND_PID as a fallback."
    kill -9 "$BACKEND_PID" 2>/dev/null
  fi
fi

# Clean up server port file
log "Removing server port file: $SERVER_PORT_FILE"
rm -f "$SERVER_PORT_FILE"

log "Launcher script completed."
log "==================== BASIL LAUNCHER SCRIPT FINISHED ===================="
exit 0 