#!/bin/bash

# Startup Optimization Implementation Script for Basil
# Based on analysis showing backend startup takes ~56 seconds

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
OPTIMIZED_DIR="$SCRIPT_DIR"  # We're already in the optimized directory

print_status() {
    echo -e "${BLUE}[OPTIMIZE]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OPTIMIZE]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[OPTIMIZE]${NC} $1"
}

print_error() {
    echo -e "${RED}[OPTIMIZE]${NC} $1"
}

show_analysis_summary() {
    print_status "=== CURRENT STARTUP PERFORMANCE ==="
    echo "Based on recent analysis:"
    echo "  • Backend startup: ~56 seconds (MAJOR BOTTLENECK)"
    echo "  • Frontend startup: ~5 seconds (reasonable)"
    echo "  • Full coordination: ~2 seconds (good)"
    echo ""
    echo "PRIMARY ISSUE: Backend takes 56 seconds to become healthy"
    echo "This suggests heavy model loading or dependency initialization"
    echo ""
}

optimize_backend_lazy_loading() {
    print_status "OPTIMIZATION 1: Implementing Backend Lazy Loading"
    
    local backend_main="$ROOT_DIR/Basil/src/api/main.py"
    
    if [[ ! -f "$backend_main" ]]; then
        print_error "Backend main.py not found at $backend_main"
        return 1
    fi
    
    print_status "Creating optimized backend startup with lazy loading in isolated directory..."
    
    # Create optimized version in the isolated directory (DON'T modify originals)
    local optimized_backend_dir="$OPTIMIZED_DIR/backend_files"
    mkdir -p "$optimized_backend_dir"
    
    cat > "$optimized_backend_dir/main_optimized.py" << 'EOF'
import time
import sys
import argparse
import asyncio
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os
import json
import platform
import logging
import threading
import atexit

print(f"{time.time()} - DEBUG: Optimized startup - basic imports complete"); sys.stdout.flush()

# Check if we're running as a bundled executable
IS_BUNDLED = getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS')

# Ensure the project root is in sys.path
sys.path.append(str(Path(__file__).parent.resolve()))

# Import only essential components for startup
from api.core.config.api_settings import settings
from api.core.logging.api_logger import api_logger, setup_api_logger

print(f"{time.time()} - DEBUG: Optimized startup - essential imports complete"); sys.stdout.flush()

# Global variables for lazy-loaded components
model_manager = None
model_downloader = None
huey_worker_thread = None

# Configure logging
logger = setup_api_logger(
    "api.main",
    level=logging.DEBUG if settings.DEBUG else logging.INFO
)

# Create FastAPI app with minimal initial setup
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.API_VERSION,
    description="Basil Backend API - Optimized Startup",
    debug=settings.DEBUG
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Lazy loading flag
_heavy_components_loaded = False
_loading_lock = asyncio.Lock()

async def ensure_heavy_components_loaded():
    """Lazy load heavy components only when needed"""
    global model_manager, model_downloader, _heavy_components_loaded
    
    if _heavy_components_loaded:
        return
        
    async with _loading_lock:
        if _heavy_components_loaded:  # Double-check after acquiring lock
            return
            
        logger.info("🔄 Loading heavy components on demand...")
        start_time = time.time()
        
        try:
            # Import heavy dependencies only when needed
            from api.dependencies import get_model_service
            from api.settings import get_settings
            
            # Initialize model infrastructure
            model_service = get_model_service()
            model_manager = model_service.model_manager
            model_downloader = model_service.model_downloader
            
            # Load settings and scan models
            app_settings = get_settings()
            models_dir = Path(app_settings.models_dir)
            
            # Import and call scan_models
            from api.routes.models import scan_models
            await scan_models(models_dir)
            
            _heavy_components_loaded = True
            load_time = time.time() - start_time
            logger.info(f"✅ Heavy components loaded in {load_time:.2f} seconds")
            
        except Exception as e:
            logger.error(f"❌ Error loading heavy components: {e}", exc_info=True)
            raise

@app.on_event("startup")
async def startup_event():
    """Minimal startup - defer heavy operations"""
    try:
        logger.info("🚀 Optimized startup: beginning minimal initialization")
        
        # Log basic system information only
        logger.info(f"Application '{settings.APP_NAME}' version {settings.API_VERSION}")
        logger.info(f"Python version: {sys.version}")
        logger.info(f"Platform: {platform.platform()}")
        logger.info(f"Debug mode: {settings.DEBUG}")
        
        # Write port information immediately
        port_file = settings.BASE_DIR / ".server_port"
        port_file.write_text(str(settings.PORT))
        logger.info(f"Server listening on {settings.HOST}:{settings.PORT}")
        
        logger.info("✅ Minimal startup complete - heavy components will load on demand")
        
    except Exception as e:
        logger.error(f"🚨 Startup event error: {e}", exc_info=True)

# Health endpoint that works immediately
@app.get("/health")
async def health_check():
    """Immediate health check without heavy dependencies"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "heavy_components_loaded": _heavy_components_loaded
    }

# Optimized endpoints that load components on demand
@app.get("/models")
async def get_models():
    """Get available models - loads heavy components if needed"""
    await ensure_heavy_components_loaded()
    # Import the actual models route handler
    from api.routes.models import get_models as actual_get_models
    return await actual_get_models()

@app.post("/models/download")
async def download_model(request: dict):
    """Download model - loads heavy components if needed"""
    await ensure_heavy_components_loaded()
    from api.routes.models import download_model as actual_download_model
    return await actual_download_model(request)

# Add other essential routes with lazy loading...
# (This is a simplified example - you'd add all routes with lazy loading)

if __name__ == "__main__":
    import uvicorn
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Basil Backend API Server - Optimized")
    parser.add_argument("--host", type=str, default=settings.HOST, help="Host to bind")
    parser.add_argument("--port", type=int, default=settings.PORT, help="Port to bind")
    parser.add_argument("--port-file", type=str, default=None, help="File to write port to")
    
    args = parser.parse_args()
    
    # Write port file if specified
    if args.port_file:
        Path(args.port_file).parent.mkdir(parents=True, exist_ok=True)
        Path(args.port_file).write_text(str(args.port))
    
    logger.info("Starting optimized Uvicorn server")
    uvicorn.run(app, host=args.host, port=args.port, log_level='info')
EOF

    print_success "Created optimized backend main with lazy loading"
    print_status "This version defers heavy model loading until actually needed"
}

optimize_backend_caching() {
    print_status "OPTIMIZATION 2: Implementing Model Scanning Cache"
    
    print_status "Creating model scanning cache system in isolated directory..."
    
    local optimized_backend_dir="$OPTIMIZED_DIR/backend_files"
    mkdir -p "$optimized_backend_dir"
    
    cat > "$optimized_backend_dir/model_cache.py" << 'EOF'
"""
Model scanning cache to avoid expensive filesystem operations on every startup
"""
import json
import time
import hashlib
from pathlib import Path
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)

class ModelScanCache:
    """Caches model scanning results to speed up startup"""
    
    def __init__(self, models_dir: Path, cache_file: Optional[Path] = None):
        self.models_dir = Path(models_dir)
        self.cache_file = cache_file or self.models_dir / ".model_scan_cache.json"
        self.cache_ttl = 3600  # 1 hour cache TTL
        
    def _get_directory_hash(self) -> str:
        """Get a hash of the models directory structure for cache invalidation"""
        if not self.models_dir.exists():
            return "empty"
            
        # Get modification times of all model files
        model_files = []
        for ext in ['*.gguf', '*.bin', '*.safetensors', '*.pt', '*.pth']:
            model_files.extend(self.models_dir.rglob(ext))
            
        # Create hash from file paths and modification times
        hash_input = ""
        for file_path in sorted(model_files):
            try:
                stat = file_path.stat()
                hash_input += f"{file_path}:{stat.st_mtime}:{stat.st_size}"
            except (OSError, FileNotFoundError):
                continue
                
        return hashlib.md5(hash_input.encode()).hexdigest()
    
    def get_cached_scan(self) -> Optional[Dict]:
        """Get cached scan results if valid"""
        try:
            if not self.cache_file.exists():
                return None
                
            with open(self.cache_file, 'r') as f:
                cache_data = json.load(f)
                
            # Check if cache is still valid
            cache_time = cache_data.get('timestamp', 0)
            cache_hash = cache_data.get('directory_hash', '')
            current_hash = self._get_directory_hash()
            
            if (time.time() - cache_time < self.cache_ttl and 
                cache_hash == current_hash):
                logger.info(f"✅ Using cached model scan (age: {time.time() - cache_time:.1f}s)")
                return cache_data.get('models', {})
            else:
                logger.info("🔄 Model cache expired or directory changed, will rescan")
                return None
                
        except Exception as e:
            logger.warning(f"⚠️ Error reading model cache: {e}")
            return None
    
    def save_scan_results(self, models: Dict):
        """Save scan results to cache"""
        try:
            cache_data = {
                'timestamp': time.time(),
                'directory_hash': self._get_directory_hash(),
                'models': models
            }
            
            # Ensure cache directory exists
            self.cache_file.parent.mkdir(parents=True, exist_ok=True)
            
            with open(self.cache_file, 'w') as f:
                json.dump(cache_data, f, indent=2)
                
            logger.info(f"💾 Saved model scan cache to {self.cache_file}")
            
        except Exception as e:
            logger.warning(f"⚠️ Error saving model cache: {e}")
    
    def clear_cache(self):
        """Clear the model scan cache"""
        try:
            if self.cache_file.exists():
                self.cache_file.unlink()
                logger.info("🗑️ Model scan cache cleared")
        except Exception as e:
            logger.warning(f"⚠️ Error clearing cache: {e}")
EOF

    print_success "Created model scanning cache system"
    print_status "This will cache model scan results to avoid expensive filesystem operations"
}

optimize_frontend_settings_loading() {
    print_status "OPTIMIZATION 3: Optimizing Frontend Settings Loading"
    
    local app_delegate="$ROOT_DIR/BasilClient/Sources/App/AppDelegate.swift"
    
    if [[ ! -f "$app_delegate" ]]; then
        print_error "AppDelegate.swift not found"
        return 1
    fi
    
    print_status "Frontend already has some optimizations, but could be improved further"
    print_status "Consider implementing:"
    echo "  • Async settings loading after UI appears"
    echo "  • Settings caching in UserDefaults"
    echo "  • Progressive initialization of non-critical components"
}

create_fast_startup_mode() {
    print_status "OPTIMIZATION 4: Creating Fast Startup Mode"
    
    print_status "Fast startup script already exists in optimized directory"
    
    # The run_backend_fast.sh script is already in the optimized directory
    local fast_backend="$OPTIMIZED_DIR/run_backend_fast.sh"
    
    if [[ -f "$fast_backend" ]]; then
        print_success "Fast startup script found at: $fast_backend"
        # Make sure it's executable
        chmod +x "$fast_backend"
        print_status "This script uses optimized backend when available"
    else
        print_warning "Fast startup script not found, creating it..."
        
        cat > "$fast_backend" << 'EOF'
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

# Find the backend directory (assuming we're in builds/common/scripts)
BACKEND_DIR="$(find ../../../builds/outputs -name "backend" -type d | head -n 1)"

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
EOF

        chmod +x "$fast_backend"
        print_success "Created fast startup script with optimizations"
    fi
}

implement_progressive_loading() {
    print_status "OPTIMIZATION 5: Implementing Progressive Loading Strategy"
    
    cat > "$OPTIMIZED_DIR/progressive_startup.md" << 'EOF'
# Progressive Loading Strategy for Basil

## Current Issues
- Backend takes 56 seconds to start (model scanning, heavy imports)
- Frontend waits for backend health check
- User sees no feedback during long startup

## Progressive Loading Approach

### Phase 1: Immediate Response (0-2 seconds)
- Backend starts with minimal imports
- Health endpoint responds immediately
- Frontend launches and shows "Starting..." status
- User sees app is launching

### Phase 2: Core Functionality (2-10 seconds)
- Load essential API routes
- Initialize basic settings
- Enable basic transcription without models
- User can access settings, see status

### Phase 3: Model Loading (10-60 seconds)
- Load models in background
- Show progress in UI
- Enable advanced features as they become available
- User can use basic features while waiting

### Phase 4: Full Functionality (60+ seconds)
- All models loaded
- All features available
- Background optimization continues

## Implementation Steps

1. **Backend Lazy Loading** ✅
   - Defer model scanning until needed
   - Load routes progressively
   - Immediate health check response

2. **Frontend Progressive UI**
   - Show startup progress
   - Enable features as backend reports ready
   - Graceful degradation for missing features

3. **Model Streaming**
   - Download models on-demand
   - Cache frequently used models
   - Stream large models in chunks

4. **Background Optimization**
   - Pre-warm frequently used models
   - Optimize model loading order
   - Cache scan results
EOF

    print_success "Created progressive loading strategy documentation"
}

show_next_steps() {
    print_status "=== NEXT STEPS FOR STARTUP OPTIMIZATION ==="
    echo ""
    echo "1. IMMEDIATE WINS (implement first):"
    echo "   ✅ Created optimized backend with lazy loading"
    echo "   ✅ Created model scanning cache system"
    echo "   ✅ Created fast startup script"
    echo ""
    echo "2. BACKEND CHANGES NEEDED:"
    echo "   • Replace main.py with main_optimized.py in build process"
    echo "   • Integrate model cache into existing model scanning"
    echo "   • Add progressive route loading"
    echo ""
    echo "3. FRONTEND CHANGES NEEDED:"
    echo "   • Add startup progress UI"
    echo "   • Implement feature availability checking"
    echo "   • Add graceful degradation for missing backend features"
    echo ""
    echo "4. BUILD PROCESS CHANGES:"
    echo "   • Update build scripts to use optimized backend"
    echo "   • Add cache warming during build"
    echo "   • Implement model pre-loading options"
    echo ""
    echo "Expected improvements:"
    echo "   • Backend startup: 56s → 2-5s (for basic functionality)"
    echo "   • User feedback: immediate instead of 56s wait"
    echo "   • Progressive feature availability"
}

main() {
    print_status "Starting Basil startup optimization implementation..."
    echo ""
    
    show_analysis_summary
    
    optimize_backend_lazy_loading
    echo ""
    
    optimize_backend_caching
    echo ""
    
    optimize_frontend_settings_loading
    echo ""
    
    create_fast_startup_mode
    echo ""
    
    implement_progressive_loading
    echo ""
    
    show_next_steps
    
    print_success "Startup optimization implementation complete!"
    print_status "Review the created files and implement the suggested changes."
}

# Show usage if help requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Implements startup optimizations for Basil based on analysis results."
    echo ""
    echo "This script creates:"
    echo "  1. Optimized backend with lazy loading"
    echo "  2. Model scanning cache system"
    echo "  3. Fast startup scripts"
    echo "  4. Progressive loading strategy"
    echo ""
    exit 0
fi

main "$@" 