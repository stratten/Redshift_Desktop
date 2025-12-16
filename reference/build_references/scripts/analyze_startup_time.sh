#!/bin/bash

# Startup Time Analysis Script for Basil
# Measures various phases of application startup to identify bottlenecks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ANALYSIS_DIR="$ROOT_DIR/builds/startup_analysis"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
ANALYSIS_FILE="$ANALYSIS_DIR/startup_analysis_$TIMESTAMP.log"

print_status() {
    echo -e "${BLUE}[ANALYSIS]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[ANALYSIS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ANALYSIS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ANALYSIS]${NC} $1"
}

# Function to get timestamp in milliseconds
get_timestamp_ms() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        python3 -c "import time; print(int(time.time() * 1000))"
    else
        # Linux
        date +%s%3N
    fi
}

# Function to calculate duration
calculate_duration() {
    local start_time=$1
    local end_time=$2
    echo $((end_time - start_time))
}

create_analysis_dir() {
    mkdir -p "$ANALYSIS_DIR"
    echo "# Basil Startup Time Analysis - $TIMESTAMP" > "$ANALYSIS_FILE"
    echo "# Testing startup performance and identifying bottlenecks" >> "$ANALYSIS_FILE"
    echo "" >> "$ANALYSIS_FILE"
}

analyze_backend_startup() {
    print_status "Analyzing backend startup time..."
    
    # Find the latest build
    local latest_build
    latest_build=$(find "$ROOT_DIR/builds/outputs" -maxdepth 1 -type d -name "20*" | sort -r | head -n 1)
    
    if [[ -z "$latest_build" ]]; then
        print_error "No build found. Please run ./build_app.sh first."
        print_status "Looking in: $ROOT_DIR/builds/outputs"
        print_status "Available directories:"
        ls -la "$ROOT_DIR/builds/outputs" || true
        return 1
    fi
    
    local backend_dir="$latest_build/backend"
    if [[ ! -d "$backend_dir" ]]; then
        print_error "Backend directory not found in latest build."
        return 1
    fi
    
    print_status "Using backend from: $backend_dir"
    
    # Start measuring backend startup
    local backend_start_time=$(get_timestamp_ms)
    
    # Change to backend directory
    cd "$backend_dir"
    
    # Create a temporary port file for analysis
    local temp_port_file="/tmp/basil_analysis_port_$$"
    
    # Start backend in background
    print_status "Starting backend..."
    ./run_backend.sh --port-file "$temp_port_file" &
    local backend_pid=$!
    
    # Wait for port file to appear
    local port_file_start_time=$(get_timestamp_ms)
    local port_file_timeout=60000  # 60 seconds
    local port=""
    
    while [[ ! -f "$temp_port_file" ]] && [[ $(($(get_timestamp_ms) - port_file_start_time)) -lt $port_file_timeout ]]; do
        sleep 0.1
    done
    
    if [[ -f "$temp_port_file" ]]; then
        port=$(cat "$temp_port_file")
        local port_file_ready_time=$(get_timestamp_ms)
        local port_file_duration=$(calculate_duration $port_file_start_time $port_file_ready_time)
        
        print_status "Port file created in ${port_file_duration}ms, port: $port"
        
        # Wait for health endpoint to respond
        local health_start_time=$(get_timestamp_ms)
        local health_timeout=60000  # 60 seconds
        local health_ready=false
        
        while [[ $(($(get_timestamp_ms) - health_start_time)) -lt $health_timeout ]]; do
            if curl --silent --fail "http://127.0.0.1:$port/health" > /dev/null 2>&1; then
                health_ready=true
                break
            fi
            sleep 0.1
        done
        
        if [[ "$health_ready" == "true" ]]; then
            local health_ready_time=$(get_timestamp_ms)
            local health_duration=$(calculate_duration $health_start_time $health_ready_time)
            local total_backend_duration=$(calculate_duration $backend_start_time $health_ready_time)
            
            print_success "Backend fully ready in ${total_backend_duration}ms"
            
            # Log detailed timing
            {
                echo "=== BACKEND STARTUP ANALYSIS ==="
                echo "Port file ready: ${port_file_duration}ms"
                echo "Health endpoint ready: ${health_duration}ms"
                echo "Total backend startup: ${total_backend_duration}ms"
                echo ""
            } >> "$ANALYSIS_FILE"
            
            # Analyze what took time during startup
            analyze_backend_logs "$backend_dir" "$backend_start_time" "$health_ready_time"
            
        else
            print_error "Backend health endpoint never responded"
            {
                echo "=== BACKEND STARTUP ANALYSIS ==="
                echo "ERROR: Health endpoint timeout after ${health_timeout}ms"
                echo ""
            } >> "$ANALYSIS_FILE"
        fi
        
        # Clean up
        rm -f "$temp_port_file"
    else
        print_error "Port file never created"
        {
            echo "=== BACKEND STARTUP ANALYSIS ==="
            echo "ERROR: Port file timeout after ${port_file_timeout}ms"
            echo ""
        } >> "$ANALYSIS_FILE"
    fi
    
    # Kill backend
    if kill $backend_pid 2>/dev/null; then
        wait $backend_pid 2>/dev/null || true
    fi
    
    cd "$SCRIPT_DIR"
}

analyze_backend_logs() {
    local backend_dir="$1"
    local start_time="$2"
    local end_time="$3"
    
    print_status "Analyzing backend startup logs..."
    
    local log_file="$backend_dir/logs/api.log"
    if [[ -f "$log_file" ]]; then
        local duration=$(calculate_duration $start_time $end_time)
        
        {
            echo "=== BACKEND LOG ANALYSIS ==="
            echo "Startup duration: ${duration}ms"
            echo ""
            echo "Key startup events from logs:"
            
            # Extract key startup events (last 50 lines to focus on this startup)
            tail -n 50 "$log_file" | grep -E "(Startup:|DEBUG:|INFO:|WARNING:|ERROR:)" | head -20
            echo ""
            
        } >> "$ANALYSIS_FILE"
    else
        print_warning "Backend log file not found: $log_file"
    fi
}

analyze_frontend_startup() {
    print_status "Analyzing frontend startup time..."
    
    # Find the BasilClient.app
    local latest_build
    latest_build=$(find "$ROOT_DIR/builds/outputs" -maxdepth 1 -type d -name "20*" | sort -r | head -n 1)
    
    local frontend_app="$latest_build/Basil.app"
    if [[ ! -d "$frontend_app" ]]; then
        print_error "Frontend app not found: $frontend_app"
        return 1
    fi
    
    print_status "Using frontend app: $frontend_app"
    
    # Measure frontend launch time
    local frontend_start_time=$(get_timestamp_ms)
    
    # Launch the app in background
    open "$frontend_app" &
    local open_pid=$!
    
    # Wait a moment for the app to fully initialize
    sleep 5
    
    local frontend_end_time=$(get_timestamp_ms)
    local frontend_duration=$(calculate_duration $frontend_start_time $frontend_end_time)
    
    print_success "Frontend startup measured: ${frontend_duration}ms"
    
    {
        echo "=== FRONTEND STARTUP ANALYSIS ==="
        echo "App launch duration: ${frontend_duration}ms"
        echo "Note: This measures time to launch, not full initialization"
        echo ""
    } >> "$ANALYSIS_FILE"
    
    # Close the app
    osascript -e 'tell application "Basil" to quit' 2>/dev/null || true
    sleep 2
}

analyze_coordinator_startup() {
    print_status "Analyzing full application coordination startup..."
    
    # Find the latest build
    local latest_build
    latest_build=$(find "$ROOT_DIR/builds/outputs" -maxdepth 1 -type d -name "20*" | sort -r | head -n 1)
    
    local master_app="$latest_build/Basil.app"
    if [[ ! -d "$master_app" ]]; then
        print_error "Master app not found: $master_app"
        return 1
    fi
    
    print_status "Testing full application startup coordination..."
    
    # This simulates the master launcher startup
    local coord_start_time=$(get_timestamp_ms)
    
    # Launch the master application
    open "$master_app" &
    
    # Wait for the application to be fully ready (status bar should appear)
    local ready_timeout=90000  # 90 seconds for full startup
    local ready_start_time=$(get_timestamp_ms)
    local app_ready=false
    
    print_status "Waiting for application to be fully ready..."
    
    # Check if Basil appears in running applications
    while [[ $(($(get_timestamp_ms) - ready_start_time)) -lt $ready_timeout ]]; do
        if pgrep -f "Basil" > /dev/null 2>&1; then
            # Wait an additional moment for full initialization
            sleep 2
            app_ready=true
            break
        fi
        sleep 1
    done
    
    if [[ "$app_ready" == "true" ]]; then
        local coord_end_time=$(get_timestamp_ms)
        local coord_duration=$(calculate_duration $coord_start_time $coord_end_time)
        
        print_success "Full application startup: ${coord_duration}ms"
        
        {
            echo "=== FULL APPLICATION STARTUP ANALYSIS ==="
            echo "Total coordination time: ${coord_duration}ms"
            echo "This includes backend startup + frontend launch + coordination"
            echo ""
        } >> "$ANALYSIS_FILE"
    else
        print_error "Application never appeared to start successfully"
        {
            echo "=== FULL APPLICATION STARTUP ANALYSIS ==="
            echo "ERROR: Application startup timeout after ${ready_timeout}ms"
            echo ""
        } >> "$ANALYSIS_FILE"
    fi
    
    # Clean up - quit the application
    osascript -e 'tell application "Basil" to quit' 2>/dev/null || true
    pkill -f "Basil" 2>/dev/null || true
    sleep 3
}

generate_recommendations() {
    print_status "Generating optimization recommendations..."
    
    {
        echo "=== OPTIMIZATION RECOMMENDATIONS ==="
        echo ""
        echo "Based on the startup analysis, here are potential optimizations:"
        echo ""
        echo "1. BACKEND OPTIMIZATIONS:"
        echo "   - Lazy load heavy dependencies (models, ML libraries)"
        echo "   - Implement async initialization for non-critical components"
        echo "   - Cache model scanning results"
        echo "   - Optimize Python import order"
        echo ""
        echo "2. FRONTEND OPTIMIZATIONS:"
        echo "   - Defer non-essential UI setup until after launch"
        echo "   - Implement progressive loading of settings"
        echo "   - Cache frequently accessed data"
        echo ""
        echo "3. COORDINATION OPTIMIZATIONS:"
        echo "   - Implement health check optimization"
        echo "   - Reduce health check polling frequency"
        echo "   - Parallel initialization where possible"
        echo ""
        echo "4. BUNDLE SIZE OPTIMIZATIONS:"
        echo "   - Consider post-install dependency downloads"
        echo "   - Implement model streaming/download on demand"
        echo "   - Optimize virtual environment size"
        echo ""
    } >> "$ANALYSIS_FILE"
    
    print_success "Recommendations written to analysis file"
}

main() {
    print_status "Starting Basil startup time analysis..."
    
    create_analysis_dir
    
    print_status "Analysis will be saved to: $ANALYSIS_FILE"
    
    # Run individual analyses
    analyze_backend_startup
    echo ""
    
    analyze_frontend_startup  
    echo ""
    
    analyze_coordinator_startup
    echo ""
    
    generate_recommendations
    
    print_success "Startup analysis complete!"
    print_success "Results saved to: $ANALYSIS_FILE"
    
    # Show summary
    if [[ -f "$ANALYSIS_FILE" ]]; then
        echo ""
        print_status "=== ANALYSIS SUMMARY ==="
        grep -E "(ready|duration|Total)" "$ANALYSIS_FILE" | grep -v "ERROR" || true
    fi
}

# Show usage if help requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Analyzes Basil application startup time to identify bottlenecks."
    echo ""
    echo "This script will:"
    echo "  1. Test backend startup time"
    echo "  2. Test frontend startup time"  
    echo "  3. Test full application coordination"
    echo "  4. Generate optimization recommendations"
    echo ""
    echo "Output:"
    echo "  Creates detailed analysis in builds/startup_analysis/"
    exit 0
fi

# Ensure we have a recent build
if [[ ! -d "$ROOT_DIR/builds/outputs" ]]; then
    print_error "No builds found. Please run ./build_app.sh first."
    exit 1
fi

# Run main analysis
main "$@" 