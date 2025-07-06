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
STOP_SIGN="🛑"
PACKAGE="📦"
WRENCH="🔧"
HOURGLASS="⏳"
WAVE="👋"

# Print banner
print_banner() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║       Telemetry Server Services Stop         ║"
    echo "║            MongoDB & Redis                   ║"
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

# Check if container exists
container_exists() {
    local container_name=$1
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        return 0
    fi
    return 1
}

# Get container status
get_container_status() {
    local container_name=$1
    docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null
}

# Stop and remove container with status updates
stop_container() {
    local container_name=$1
    local service_name=$2
    
    if ! container_exists "$container_name"; then
        print_warning "$service_name container not found"
        return 0
    fi
    
    local status=$(get_container_status "$container_name")
    
    if [ "$status" == "running" ]; then
        print_status "Stopping $service_name container..."
        if docker stop "$container_name" > /dev/null 2>&1; then
            print_success "$service_name stopped"
        else
            print_error "Failed to stop $service_name"
            return 1
        fi
    else
        print_warning "$service_name was not running (status: $status)"
    fi
    
    print_status "Removing $service_name container..."
    if docker rm "$container_name" > /dev/null 2>&1; then
        print_success "$service_name container removed"
    else
        print_error "Failed to remove $service_name container"
        return 1
    fi
    
    return 0
}

# Check for running processes on ports
check_port_usage() {
    local port=$1
    local service_name=$2
    
    if lsof -i :$port > /dev/null 2>&1; then
        print_warning "Port $port is still in use after stopping $service_name"
        echo -e "${YELLOW}You may need to manually kill the process using port $port${NC}"
        echo -e "${CYAN}Run: ${YELLOW}lsof -i :$port${NC} to see what's using the port"
    fi
}

# Main script
print_banner

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running!"
    exit 1
fi

# Display current container status before stopping
echo -e "${CYAN}${BOLD}Current Container Status:${NC}"
echo ""

mongo_running=false
redis_running=false

if container_exists "telemetry-mongo"; then
    status=$(get_container_status "telemetry-mongo")
    echo -e "${PACKAGE} MongoDB: ${YELLOW}$status${NC}"
    [ "$status" == "running" ] && mongo_running=true
else
    echo -e "${PACKAGE} MongoDB: ${YELLOW}not found${NC}"
fi

if container_exists "telemetry-redis"; then
    status=$(get_container_status "telemetry-redis")
    echo -e "${PACKAGE} Redis:   ${YELLOW}$status${NC}"
    [ "$status" == "running" ] && redis_running=true
else
    echo -e "${PACKAGE} Redis:   ${YELLOW}not found${NC}"
fi

echo ""

# Ask for confirmation if services are running
if [ "$mongo_running" == true ] || [ "$redis_running" == true ]; then
    echo -e "${YELLOW}${STOP_SIGN} This will stop the running services.${NC}"
    read -p "Are you sure you want to continue? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled"
        exit 0
    fi
    echo ""
fi

# Stop MongoDB
stop_container "telemetry-mongo" "MongoDB"
mongo_result=$?

# Stop Redis
stop_container "telemetry-redis" "Redis"
redis_result=$?

echo ""

# Check if ports are still in use
if [ "$mongo_running" == true ]; then
    check_port_usage 27017 "MongoDB"
fi

if [ "$redis_running" == true ]; then
    check_port_usage 6379 "Redis"
fi

# Summary
echo ""
if [ $mongo_result -eq 0 ] && [ $redis_result -eq 0 ]; then
    echo -e "${GREEN}${BOLD}${CHECK_MARK} All services stopped successfully! ${CHECK_MARK}${NC}"
else
    echo -e "${RED}${BOLD}${CROSS_MARK} Some services failed to stop properly ${CROSS_MARK}${NC}"
fi

echo ""
echo -e "${BLUE}To start services again: ${YELLOW}./scripts/start-local-services.sh${NC}"
echo ""
echo -e "${PURPLE}${WAVE} Goodbye! ${WAVE}${NC}"