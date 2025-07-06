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
HEART="❤️"
PACKAGE="📦"
WARNING="⚠️"
INFO="ℹ️"

# Print banner
print_banner() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║       Telemetry Server Health Check          ║"
    echo "║         System Status Monitor                ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
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
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

# Print info message
print_info() {
    echo -e "${CYAN}${INFO} $1${NC}"
}

# Check service health
check_service() {
    local service_name=$1
    local url=$2
    local expected_response=$3
    
    echo -ne "${BLUE}Checking $service_name... ${NC}"
    
    response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" == "200" ]; then
        if [ ! -z "$expected_response" ] && [[ "$body" == *"$expected_response"* ]]; then
            echo -e "${GREEN}${CHECK_MARK} Healthy${NC}"
            return 0
        elif [ -z "$expected_response" ]; then
            echo -e "${GREEN}${CHECK_MARK} Healthy${NC}"
            return 0
        else
            echo -e "${YELLOW}${WARNING} Unexpected response${NC}"
            return 1
        fi
    else
        echo -e "${RED}${CROSS_MARK} Unreachable (HTTP $http_code)${NC}"
        return 1
    fi
}

# Check Docker container
check_container() {
    local container_name=$1
    local service_name=$2
    
    echo -ne "${BLUE}Checking $service_name container... ${NC}"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${RED}${CROSS_MARK} Not running${NC}"
        return 1
    fi
    
    # Get container health status if available
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
    
    if [ "$health_status" == "healthy" ]; then
        echo -e "${GREEN}${CHECK_MARK} Healthy${NC}"
    elif [ "$health_status" == "none" ]; then
        # No health check defined, just check if running
        echo -e "${GREEN}${CHECK_MARK} Running${NC}"
    else
        echo -e "${YELLOW}${WARNING} Status: $health_status${NC}"
    fi
    
    return 0
}

# Check port availability
check_port() {
    local port=$1
    local service_name=$2
    
    echo -ne "${BLUE}Checking $service_name port ($port)... ${NC}"
    
    if nc -z localhost "$port" 2>/dev/null; then
        echo -e "${GREEN}${CHECK_MARK} Open${NC}"
        return 0
    else
        echo -e "${RED}${CROSS_MARK} Closed${NC}"
        return 1
    fi
}

# Get server info
get_server_info() {
    local base_url="${1:-http://localhost:8080}"
    
    # Get version info
    version_info=$(curl -s "$base_url/version" 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$version_info" ]; then
        version=$(echo "$version_info" | jq -r '.version // "unknown"')
        build_date=$(echo "$version_info" | jq -r '.build_date // "unknown"')
        echo -e "${CYAN}Server Version: ${YELLOW}$version${NC}"
        echo -e "${CYAN}Build Date: ${YELLOW}$build_date${NC}"
    fi
}

# Main script
print_banner

# Parse command line arguments
SERVER_URL="http://localhost:8080"
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            SERVER_URL="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--url SERVER_URL]"
            echo "  --url    Server URL (default: http://localhost:8080)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}${BOLD}System Status Check${NC}"
echo -e "${CYAN}Server URL: ${YELLOW}$SERVER_URL${NC}"
echo ""

# Track overall health
all_healthy=true

# Check Docker
echo -e "${PURPLE}${BOLD}Docker Status:${NC}"
if command -v docker &> /dev/null && docker info &> /dev/null; then
    print_success "Docker is running"
    
    # Check containers
    check_container "telemetry-mongo" "MongoDB" || all_healthy=false
    check_container "telemetry-redis" "Redis" || all_healthy=false
else
    print_error "Docker is not running"
    all_healthy=false
fi

echo ""

# Check ports
echo -e "${PURPLE}${BOLD}Port Status:${NC}"
check_port 27017 "MongoDB" || all_healthy=false
check_port 6379 "Redis" || all_healthy=false
check_port 8080 "Telemetry Server" || all_healthy=false

echo ""

# Check API endpoints
echo -e "${PURPLE}${BOLD}API Health Checks:${NC}"
check_service "Health endpoint" "$SERVER_URL/health" "healthy" || all_healthy=false
check_service "Version endpoint" "$SERVER_URL/version" "version" || all_healthy=false
check_service "Metrics endpoint" "$SERVER_URL/metrics" "" || all_healthy=false

echo ""

# Get server info if available
if check_service "Server" "$SERVER_URL/version" "version" &> /dev/null; then
    echo -e "${PURPLE}${BOLD}Server Information:${NC}"
    get_server_info "$SERVER_URL"
    echo ""
fi

# Check MongoDB connection
echo -e "${PURPLE}${BOLD}Database Connectivity:${NC}"
echo -ne "${BLUE}Checking MongoDB connection... ${NC}"
if docker exec telemetry-mongo mongosh --quiet --eval "db.adminCommand('ping')" &> /dev/null; then
    echo -e "${GREEN}${CHECK_MARK} Connected${NC}"
else
    echo -e "${RED}${CROSS_MARK} Connection failed${NC}"
    all_healthy=false
fi

# Check Redis connection
echo -ne "${BLUE}Checking Redis connection... ${NC}"
if docker exec telemetry-redis redis-cli ping &> /dev/null; then
    echo -e "${GREEN}${CHECK_MARK} Connected${NC}"
else
    echo -e "${RED}${CROSS_MARK} Connection failed${NC}"
    all_healthy=false
fi

echo ""

# Summary
echo -e "${PURPLE}${BOLD}Summary:${NC}"
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}${BOLD}${HEART} All systems operational! ${HEART}${NC}"
    echo -e "${GREEN}The telemetry server is ready to use.${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}${WARNING} Some services are not healthy ${WARNING}${NC}"
    echo -e "${YELLOW}Please check the failed services above.${NC}"
    echo ""
    echo -e "${CYAN}Troubleshooting tips:${NC}"
    echo -e "  - Run ${YELLOW}./scripts/start-local-services.sh${NC} to start MongoDB and Redis"
    echo -e "  - Run ${YELLOW}cargo run${NC} to start the telemetry server"
    echo -e "  - Check logs with ${YELLOW}docker logs telemetry-mongo${NC} or ${YELLOW}docker logs telemetry-redis${NC}"
    exit 1
fi