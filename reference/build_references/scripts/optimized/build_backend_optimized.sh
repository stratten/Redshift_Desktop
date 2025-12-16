#!/bin/bash

export PATH="$HOME/.local/bin:$PATH"

# Log which Poetry is being used
which poetry
poetry --version
poetry self show plugins

# Exit on error
set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/../../../.." && pwd )"
SRC_DIR="$ROOT_DIR/Basil/src"
CONFIG_DIR="$ROOT_DIR/Basil/src/config"

EXPECTED_ARG_COUNT=1
if [ "$#" -ne "$EXPECTED_ARG_COUNT" ]; then
    echo "❌ ERROR: Incorrect number of arguments supplied to build_backend.sh"
    echo "Usage: ./build_backend.sh <main_output_directory>"
    exit 1
fi

MAIN_OUTPUT_DIR_ARG="$1"

# Resolve MAIN_OUTPUT_DIR_ARG to an absolute path to prevent issues in subshells
# Check if MAIN_OUTPUT_DIR_ARG is already absolute
if [[ "$MAIN_OUTPUT_DIR_ARG" = /* ]]; then
    ABS_MAIN_OUTPUT_DIR_ARG="$MAIN_OUTPUT_DIR_ARG"
else
    # It's relative, resolve it based on the script's current directory before any cd
    ABS_MAIN_OUTPUT_DIR_ARG="$(cd "$SCRIPT_DIR/$MAIN_OUTPUT_DIR_ARG" && pwd)"
fi
echo "ℹ️ Resolved MAIN_OUTPUT_DIR_ARG to absolute path: $ABS_MAIN_OUTPUT_DIR_ARG"

# Determine the actual backend destination path
TIMESTAMP_PATTERN="[0-9]{8}_[0-9]{6}" # YYYYMMDD_HHMMSS
PARENT_DIR_OF_ABS_ARG=$(dirname "$ABS_MAIN_OUTPUT_DIR_ARG")
BASENAME_OF_PARENT_DIR_ABS_ARG=$(basename "$PARENT_DIR_OF_ABS_ARG")
BASENAME_OF_ABS_ARG=$(basename "$ABS_MAIN_OUTPUT_DIR_ARG")

# Check if the ABS_MAIN_OUTPUT_DIR_ARG looks like it's from build_app.sh
if [[ "$BASENAME_OF_PARENT_DIR_ABS_ARG" =~ $TIMESTAMP_PATTERN && "$BASENAME_OF_ABS_ARG" == "backend" ]]; then
    ACTUAL_BACKEND_DEST="$ABS_MAIN_OUTPUT_DIR_ARG"
    echo "ℹ️ Absolute path ('$ABS_MAIN_OUTPUT_DIR_ARG') matches specific build structure. Using directly."
else
    BASE_OUTPUT_DIR="$ABS_MAIN_OUTPUT_DIR_ARG"
    CURRENT_TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
    ACTUAL_BACKEND_DEST="$BASE_OUTPUT_DIR/${CURRENT_TIMESTAMP}_backend_build"
    echo "ℹ️ Absolute path ('$ABS_MAIN_OUTPUT_DIR_ARG') treated as base directory. Creating timestamped output subdirectory: $ACTUAL_BACKEND_DEST"
fi

# Specific destination for backend files, this is the directory path passed from build_app.sh
# e.g., /Users/user/Desktop/Basil - V2/builds/output/YYYYMMDD_HHMMSS/backend
BACKEND_DEST="$ACTUAL_BACKEND_DEST"

# Ensure the backend destination directory exists
mkdir -p "$BACKEND_DEST"

# Log all output to a file within BACKEND_DEST
LOG_FILE="$BACKEND_DEST/backend_build.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Output_DIR is the parent of BACKEND_DEST, e.g., .../output/TIMESTAMP/
# This might be useful if any script operations needed to reference that parent.
OUTPUT_DIR="$(dirname "$BACKEND_DEST")"

# Directory for libraries (relative to the script's location or root)
LIBS_DIR="$ROOT_DIR/builds/common/dependencies/libs"

# Try to find python3.11, then python3, and verify version
PYTHON_BIN=""
if command -v python3.11 &> /dev/null; then
    PYTHON_BIN="python3.11"
elif command -v python3 &> /dev/null; then
    PYTHON_BIN="python3"
else
    echo "❌ Python 3 not found. Please install Python 3 (preferably Python 3.11)."
    exit 1
fi

# Verify the selected Python version is >=3.11 and <3.12
PYTHON_VERSION=$($PYTHON_BIN -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "🐍 Using Python interpreter: $PYTHON_BIN (Version: $PYTHON_VERSION)"

# Simplified version comparison (assuming X.Y format)
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if ! ( [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -eq 11 ] ); then
    echo "❌ ERROR: Incorrect Python version. Found $PYTHON_VERSION, but project requires Python >=3.11, <3.12."
    echo "Please ensure python3.11 is installed and in your PATH, or your default python3 is 3.11."
    exit 1
fi

# Ensure output directories exist
mkdir -p "$LIBS_DIR"

# Create a Python virtual environment for the backend
cd "$BACKEND_DEST"
echo "🐍 Creating Python virtual environment..."
$PYTHON_BIN -m venv venv

# Activate the venv and install dependencies
source venv/bin/activate # CWD is $BACKEND_DEST. Venv active.
# cd "$SRC_DIR" # REMOVED: Do NOT cd "$SRC_DIR" here. CWD remains $BACKEND_DEST.

# Use Poetry or requirements.txt if available
PROJECT_ROOT_FOR_POETRY="$ROOT_DIR/Basil" # Define helper variable
if [ -f "$PROJECT_ROOT_FOR_POETRY/poetry.lock" ]; then
    if ! command -v poetry &> /dev/null; then
        echo "📦 Installing Poetry..."
        curl -sSL https://install.python-poetry.org | $PYTHON_BIN -
        export PATH="$HOME/.local/bin:$PATH" # This ensures poetry command is found
    fi
    echo "📦 Installing dependencies with Poetry from $PROJECT_ROOT_FOR_POETRY..."
    ( # Subshell for cd to project root
      cd "$PROJECT_ROOT_FOR_POETRY" || { echo "❌ ERROR: Failed to cd to $PROJECT_ROOT_FOR_POETRY"; exit 1; }
      echo "   Current directory for export: $(pwd)"
      echo "   Target requirements.txt path: $BACKEND_DEST/requirements.txt"
      echo "   Checking existence and permissions of target directory $BACKEND_DEST:"
      ls -ld "$BACKEND_DEST"
      echo "   Running poetry export (excluding datasets package)..."
    poetry export --without-hashes -f requirements.txt | grep -v "^datasets==" > "$BACKEND_DEST/requirements.txt"
    ) # End subshell, CWD reverts to $BACKEND_DEST
    if [ ! -f "$BACKEND_DEST/requirements.txt" ]; then
        echo "❌ ERROR: requirements.txt was not created by poetry export from $PROJECT_ROOT_FOR_POETRY."
        exit 1
    fi
    echo "🐍 Installing dependencies from generated requirements.txt into $BACKEND_DEST/venv..."
    pip install -r "$BACKEND_DEST/requirements.txt" # CWD: $BACKEND_DEST. Venv active.
else
    if [ -f "$SRC_DIR/requirements.txt" ]; then # $SRC_DIR is absolute.
        echo "📦 Copying requirements.txt from $SRC_DIR to $BACKEND_DEST..."
        cp "$SRC_DIR/requirements.txt" "$BACKEND_DEST/requirements.txt"
        if [ ! -f "$BACKEND_DEST/requirements.txt" ]; then
            echo "❌ ERROR: Failed to copy requirements.txt to $BACKEND_DEST."
            exit 1
        fi
        echo "🐍 Installing dependencies from copied requirements.txt into $BACKEND_DEST/venv..."
        pip install -r "$BACKEND_DEST/requirements.txt" # CWD: $BACKEND_DEST. Venv active.
    else
        echo "⚠️ No poetry.lock found at $PROJECT_ROOT_FOR_POETRY/poetry.lock and no requirements.txt found at $SRC_DIR/requirements.txt."
    fi
fi

deactivate # CWD: $BACKEND_DEST.

# Copy backend source code
cd "$SRC_DIR" # This is necessary now, as CWD was $BACKEND_DEST.
echo "📦 Copying backend source code..."
rsync -av --progress --exclude='__pycache__' --exclude='api/core/models/__pycache__/' --exclude='*.pyc' --exclude='build/' --exclude='dist/' --exclude='tests/' . "$BACKEND_DEST/src/"

# Copy config files
echo "📦 Copying config files..."
mkdir -p "$BACKEND_DEST/config"
cp -R "$CONFIG_DIR"/* "$BACKEND_DEST/config/"

# Copy backend startup script
echo "📦 Copying backend startup script..."
BACKEND_STARTUP_SCRIPT="$SCRIPT_DIR/../start_backend.sh"
if [ -f "$BACKEND_STARTUP_SCRIPT" ]; then
    cp "$BACKEND_STARTUP_SCRIPT" "$BACKEND_DEST/start_backend.sh"
    chmod +x "$BACKEND_DEST/start_backend.sh"
    echo "✅ Backend startup script copied to $BACKEND_DEST/start_backend.sh"
else
    echo "⚠️ Warning: Backend startup script not found at $BACKEND_STARTUP_SCRIPT"
fi

# Copy required libraries (e.g., sox)
echo "📦 Copying required libraries to $LIBS_DIR..."
if [ -f "/opt/homebrew/Cellar/sox/14.4.2_6/lib/libsox.dylib" ]; then
    cp "/opt/homebrew/Cellar/sox/14.4.2_6/lib/libsox.dylib" "$LIBS_DIR/"
    cp "/opt/homebrew/Cellar/sox/14.4.2_6/lib/libsox.3.dylib" "$LIBS_DIR/" 2>/dev/null || :
fi
ln -sf "$LIBS_DIR/libsox.dylib" "$BACKEND_DEST/libsox.dylib"
ln -sf "$LIBS_DIR/libsox.3.dylib" "$BACKEND_DEST/libsox.3.dylib"

# Create a launch script for the backend
cat > "$BACKEND_DEST/run_backend.sh" << 'EOF'
#!/bin/bash
# Ensure the script runs from its own directory
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

# Define log directory and create it
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# Activate virtual environment
source venv/bin/activate

# Set PYTHONPATH to include the src directory for Huey
export PYTHONPATH=$(pwd)/src:$PYTHONPATH

# PIDs for background processes
HUEY_PID=""
UVICORN_PID=""

# Function to clean up background processes
cleanup() {
    echo "Cleanup initiated in run_backend.sh..."
    # Clean up port file if we created it
    if [ -n "$PORT_FILE" ] && [ -f "$PORT_FILE" ]; then
        rm -f "$PORT_FILE"
        echo "Port file $PORT_FILE removed."
    fi
    
    # Clean up Huey worker process
    if [ -n "$HUEY_PID" ]; then
        echo "Shutting down Huey worker (PID: $HUEY_PID)..."
        if ps -p "$HUEY_PID" > /dev/null; then # Check if process exists before killing
            kill $HUEY_PID 2>/dev/null
            wait $HUEY_PID 2>/dev/null
            echo "Huey worker shut down."
        else
            echo "Huey worker (PID: $HUEY_PID) was not running or already shut down."
        fi
    fi

    if [ -n "$UVICORN_PID" ]; then
        echo "Shutting down Uvicorn (PID: $UVICORN_PID)..."
        if ps -p "$UVICORN_PID" > /dev/null; then # Check if process exists
            kill $UVICORN_PID 2>/dev/null
            wait $UVICORN_PID 2>/dev/null # Wait for Uvicorn to actually terminate
            echo "Uvicorn shut down."
        else
            echo "Uvicorn (PID: $UVICORN_PID) was not running or already shut down."
        fi
    fi
    
    # Check if deactivate exists as a command before calling it
    if command -v deactivate &> /dev/null; then
        deactivate
        echo "Virtual environment deactivated."
    else
        echo "Deactivate command not found, skipping venv deactivation."
    fi
    echo "Cleanup finished in run_backend.sh."
}

# Trap signals to run cleanup
trap cleanup EXIT SIGINT SIGTERM

# Function to check if a port is available
check_port() {
    local port_to_check=$1
    if nc -z localhost $port_to_check 2>/dev/null; then
        return 1 # Port is in use
    else
        return 0 # Port is available
    fi
}

# Define HOST, PORT, and WORKERS with defaults for Uvicorn
HOST="${BACKEND_HOST:-0.0.0.0}"
START_PORT="${BACKEND_PORT:-8000}" # Default starting port
MAX_PORT_ATTEMPTS=10
FOUND_PORT=""

echo "🔍 Searching for an available port starting from $START_PORT..."
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

if [ -z "$FOUND_PORT" ]; then
    echo "❌ Error: Could not find an available port in the range $START_PORT-$((START_PORT + MAX_PORT_ATTEMPTS))."
    exit 1
fi

# Write the port to the port file if specified
if [ -n "$PORT_FILE" ]; then
    # Create the directory for the port file if it doesn't exist
    mkdir -p "$(dirname "$PORT_FILE")"
    echo "$PORT" > "$PORT_FILE"
    echo "✅ Port $PORT written to $PORT_FILE"
fi

# Use multiple workers for better performance, with external Huey workers
WORKERS="${BACKEND_WORKERS:-1}"

# Start external Huey consumer for background tasks  
echo "🔧 Starting Huey consumer for background tasks..."
huey_consumer api.huey_init.huey --workers=4 > "$LOG_DIR/huey_direct.log" 2>&1 &
HUEY_PID=$!
echo "✅ Huey consumer started with PID: $HUEY_PID"

# Start FastAPI application (Uvicorn) with external task processing
echo "🚀 Starting Uvicorn server on $HOST:$PORT with $WORKERS workers..."
# Use api.main:app for multi-worker setup with external Huey
uvicorn api.main:app --host $HOST --port $PORT --workers $WORKERS > "$LOG_DIR/api.log" 2>&1 &
UVICORN_PID=$!
echo "PID for Uvicorn: $UVICORN_PID. Output in $LOG_DIR/api.log"

wait "$UVICORN_PID"

exit $EXIT_CODE

# Note: The 'deactivate' and script exit are handled by the EXIT trap.
EOF
chmod +x "$BACKEND_DEST/run_backend.sh"

echo "✅ Backend build complete! Backend artifacts saved to: $BACKEND_DEST"
echo "   Build log: $LOG_FILE" 