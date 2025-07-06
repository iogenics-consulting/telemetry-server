#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Emojis/symbols
CHECK_MARK="✅"
CROSS_MARK="❌"
ROCKET="🚀"
TEST_TUBE="🧪"
WRENCH="🔧"
HOURGLASS="⏳"
SPARKLES="✨"
GEAR="⚙️"

# Print banner
print_banner() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║        Telemetry Server Test Suite           ║"
    echo "║          Automated Test Runner               ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print status message
print_status() {
    echo -e "${BLUE}${HOURGLASS} $1${NC}"
}

# Print success message
print_success() {
    echo -e "${GREEN}${CHECK_MARK} $1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}${CROSS_MARK} $1${NC}"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}${WRENCH} $1${NC}"
}

# Print test message
print_test() {
    echo -e "${CYAN}${TEST_TUBE} $1${NC}"
}

# Cleanup function
cleanup() {
    local exit_code=$1
    
    echo ""
    print_status "Cleaning up test environment..."
    
    # Kill the server if it's still running
    if [ ! -z "$SERVER_PID" ] && kill -0 $SERVER_PID 2>/dev/null; then
        print_status "Stopping test server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null || true
        
        # Give it time to shutdown gracefully
        sleep 2
        
        # Force kill if still running
        if kill -0 $SERVER_PID 2>/dev/null; then
            print_warning "Force killing test server..."
            kill -9 $SERVER_PID 2>/dev/null || true
        fi
        
        print_success "Test server stopped"
    fi
    
    # Stop local services
    echo ""
    ./scripts/stop-local-services.sh
    
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}${BOLD}${SPARKLES} All tests passed successfully! ${SPARKLES}${NC}"
    else
        echo -e "${RED}${BOLD}${CROSS_MARK} Tests failed with exit code: $exit_code ${CROSS_MARK}${NC}"
    fi
    
    exit $exit_code
}

# Trap to ensure cleanup runs on exit
trap 'cleanup $?' EXIT INT TERM

# Wait for server with timeout
wait_for_server() {
    local port=8081
    local max_attempts=30
    local attempt=0
    
    echo -ne "${BLUE}${HOURGLASS} Waiting for test server to be ready"
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:$port/health > /dev/null 2>&1; then
            echo -e "\r${GREEN}${CHECK_MARK} Test server is ready!                         ${NC}"
            return 0
        fi
        
        echo -ne "."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    echo -e "\r${RED}${CROSS_MARK} Test server failed to start after $max_attempts seconds${NC}"
    return 1
}

# Main script
print_banner

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v cargo &> /dev/null; then
    print_error "Cargo is not installed!"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    exit 1
fi

print_success "All prerequisites met"
echo ""

# Start local services
print_test "Starting test environment..."
echo ""

# Check if we should use alternative ports
if [ "${USE_ALT_PORTS}" = "true" ]; then
    print_info "Using alternative ports (MongoDB: 27018, Redis: 6380)"
    export ENVIRONMENT=local  # This will load .env.local
    if ! ./scripts/start-local-services-alt-ports.sh; then
        print_error "Failed to start local services on alternative ports"
        exit 1
    fi
else
    if ! ./scripts/start-local-services.sh; then
        print_error "Failed to start local services"
        print_info "Tip: If ports are in use, try: USE_ALT_PORTS=true ./scripts/run-tests.sh"
        exit 1
    fi
fi

echo ""

# Build the project first
print_status "Building project in test mode..."
if ENVIRONMENT=test cargo build; then
    print_success "Build completed successfully"
else
    print_error "Build failed"
    exit 1
fi

echo ""

# Set test environment
export ENVIRONMENT=test

# Run the server in background
print_status "Starting test server on port 8081..."
ENVIRONMENT=test cargo run &
SERVER_PID=$!

# Store PID for cleanup
echo $SERVER_PID > .test-server.pid

print_success "Test server started with PID: $SERVER_PID"

# Wait for server to be ready
if ! wait_for_server; then
    print_error "Test server failed to start properly"
    
    # Show server logs
    echo ""
    print_warning "Server logs:"
    sleep 1
    exit 1
fi

echo ""

# Run tests
print_test "Running test suite..."
echo ""

# Run unit tests
print_status "Running unit tests..."
if cargo test --lib -- --nocapture; then
    print_success "Unit tests passed"
else
    print_error "Unit tests failed"
    exit 1
fi

echo ""

# Run integration tests
print_status "Running integration tests..."
if cargo test --test '*' -- --nocapture; then
    print_success "Integration tests passed"
else
    print_error "Integration tests failed"
    exit 1
fi

echo ""

# Run doc tests
print_status "Running documentation tests..."
if cargo test --doc; then
    print_success "Documentation tests passed"
else
    print_error "Documentation tests failed"
    exit 1
fi

echo ""

# Optional: Run benchmarks if they exist
if cargo bench --no-run 2>/dev/null; then
    print_status "Running benchmarks..."
    cargo bench
    print_success "Benchmarks completed"
    echo ""
fi

# Check test coverage (optional - requires cargo-tarpaulin)
if command -v cargo-tarpaulin &> /dev/null; then
    print_status "Generating test coverage report..."
    cargo tarpaulin --out Stdout
    echo ""
fi

print_success "All tests completed successfully!"

# Cleanup will be called automatically due to trap