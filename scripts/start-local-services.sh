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
PACKAGE="📦"
WRENCH="🔧"
HOURGLASS="⏳"
SPARKLES="✨"

# Print banner
print_banner() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║        Telemetry Server Local Setup          ║"
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

# Print info message
print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Check if Docker is running
check_docker() {
    if ! docker info &> /dev/null; then
        return 1
    fi
    return 0
}

# Start Docker daemon
start_docker() {
    print_status "Docker is not running. Attempting to start Docker..."
    
    # macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v open &> /dev/null; then
            open -a Docker
            print_status "Starting Docker Desktop..."
            
            # Wait for Docker to start (max 60 seconds)
            local count=0
            while ! check_docker && [ $count -lt 60 ]; do
                sleep 1
                count=$((count + 1))
                if [ $((count % 5)) -eq 0 ]; then
                    echo -ne "\r${BLUE}${HOURGLASS} Waiting for Docker to start... ${count}s${NC}"
                fi
            done
            echo "" # New line after waiting
            
            if check_docker; then
                print_success "Docker started successfully!"
                return 0
            else
                print_error "Failed to start Docker after 60 seconds"
                return 1
            fi
        fi
    # Linux with systemd
    elif command -v systemctl &> /dev/null; then
        print_status "Attempting to start Docker service with systemd..."
        if sudo systemctl start docker; then
            sleep 2
            if check_docker; then
                print_success "Docker service started successfully!"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Check if container exists and is healthy
check_container() {
    local container_name=$1
    local container_status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        if [ "$container_status" == "running" ]; then
            return 0
        elif [ "$container_status" == "exited" ] || [ "$container_status" == "stopped" ] || [ "$container_status" == "created" ]; then
            return 2
        fi
    fi
    return 1
}

# Heal unhealthy container
heal_container() {
    local container_name=$1
    local service_name=$2
    
    print_warning "Healing $service_name container..."
    
    # Stop and remove the container
    docker stop "$container_name" &> /dev/null
    docker rm "$container_name" &> /dev/null
    
    print_success "$service_name container cleaned up"
}

# Check if port is in use
check_port_in_use() {
    local port=$1
    local service_name=$2
    
    if lsof -i :$port > /dev/null 2>&1; then
        print_error "Port $port is already in use!"
        
        # Check if it's used by a Docker container
        local docker_container=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep ":$port->" | awk '{print $1}')
        
        if [ ! -z "$docker_container" ]; then
            print_warning "Port $port is used by Docker container: $docker_container"
            echo -e "${CYAN}Options:${NC}"
            echo -e "  1. Stop the Docker container '$docker_container'"
            echo -e "  2. Use a different port for $service_name"
            echo -e "  3. Skip $service_name setup"
            echo -e "  4. Exit"
            echo ""
            read -p "Choose an option (1-4): " -n 1 -r
            echo ""
            
            case $REPLY in
                1)
                    print_warning "Stopping container $docker_container..."
                    if docker stop "$docker_container" > /dev/null 2>&1; then
                        print_success "Container stopped"
                        sleep 1
                        return 0
                    else
                        print_error "Failed to stop container"
                        return 1
                    fi
                    ;;
                2)
                    print_info "Please configure a different port in your .env file"
                    return 1
                    ;;
                3)
                    print_warning "Skipping $service_name setup"
                    return 2
                    ;;
                *)
                    print_warning "Exiting..."
                    exit 1
                    ;;
            esac
        else
            # Not a Docker container, show regular process info
            echo -e "${YELLOW}The following process is using port $port:${NC}"
            lsof -i :$port | grep LISTEN
            echo ""
            echo -e "${CYAN}Options:${NC}"
            echo -e "  1. Kill the process using port $port"
            echo -e "  2. Use a different port for $service_name"
            echo -e "  3. Skip $service_name setup"
            echo -e "  4. Exit"
            echo ""
            read -p "Choose an option (1-4): " -n 1 -r
            echo ""
        
            case $REPLY in
                1)
                    print_warning "Killing process on port $port..."
                
                # Get the PID and process name
                local pid=$(lsof -ti :$port | head -1)
                local process_info=$(lsof -i :$port | grep LISTEN | head -1)
                
                # Check if it's a Docker process
                if echo "$process_info" | grep -q "com.docke"; then
                    print_warning "This appears to be a Docker process!"
                    echo -e "${YELLOW}Killing this process might affect Docker containers.${NC}"
                    read -p "Are you sure you want to continue? (y/N) " -n 1 -r
                    echo ""
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        print_warning "Skipping process termination"
                        return 1
                    fi
                fi
                
                # Try graceful shutdown first
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    kill $pid 2>/dev/null || true
                    sleep 2
                    # Force kill if still running
                    if lsof -i :$port > /dev/null 2>&1; then
                        kill -9 $pid 2>/dev/null || true
                    fi
                else
                    fuser -k $port/tcp
                fi
                
                sleep 1
                
                # Check if Docker is still running after the kill
                if echo "$process_info" | grep -q "com.docke"; then
                    if ! docker info &> /dev/null; then
                        print_error "Docker daemon stopped! Attempting to restart..."
                        if start_docker; then
                            print_success "Docker restarted successfully"
                        else
                            print_error "Failed to restart Docker"
                            return 1
                        fi
                    fi
                fi
                
                if lsof -i :$port > /dev/null 2>&1; then
                    print_error "Failed to kill process on port $port"
                    return 1
                else
                    print_success "Port $port is now free"
                    return 0
                fi
                ;;
            2)
                print_info "Please configure a different port in your .env file"
                return 1
                ;;
            3)
                print_warning "Skipping $service_name setup"
                return 2
                ;;
            *)
                print_warning "Exiting..."
                exit 1
                ;;
            esac
        fi
    fi
    return 0
}

# Wait for service to be ready
wait_for_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=0
    
    echo -ne "${BLUE}${HOURGLASS} Waiting for $service_name to be ready"
    
    while [ $attempt -lt $max_attempts ]; do
        if nc -z localhost "$port" 2>/dev/null; then
            echo -e "\r${GREEN}${CHECK_MARK} $service_name is ready!                    ${NC}"
            return 0
        fi
        
        echo -ne "."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    echo -e "\r${RED}${CROSS_MARK} $service_name failed to start after $max_attempts seconds${NC}"
    return 1
}

# Main script
print_banner

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    echo -e "${CYAN}Please install Docker from: https://www.docker.com/get-started${NC}"
    exit 1
fi

# Check if Docker is running, try to start if not
if ! check_docker; then
    if ! start_docker; then
        print_error "Failed to start Docker. Please start Docker manually and try again."
        exit 1
    fi
fi

print_success "Docker is running"

# MongoDB setup
print_status "Setting up MongoDB..."

# First check if container already exists and is running
check_container "telemetry-mongo"
mongo_status=$?

if [ $mongo_status -eq 0 ]; then
    # Container is already running
    print_success "MongoDB container is already running"
    mongodb_skipped=false
elif [ $mongo_status -eq 2 ]; then
    # Container exists but not running, heal it
    heal_container "telemetry-mongo" "MongoDB"
    mongo_status=1
    mongodb_skipped=false
fi

# Only check port if we need to create a new container
if [ $mongo_status -eq 1 ]; then
    # Check if MongoDB port is already in use
    check_port_in_use 27017 "MongoDB"
    mongo_port_status=$?

    if [ $mongo_port_status -eq 2 ]; then
        # User chose to skip MongoDB
        print_warning "Skipping MongoDB setup"
        mongodb_skipped=true
    elif [ $mongo_port_status -eq 1 ]; then
        # Port issue couldn't be resolved
        print_error "Cannot proceed with MongoDB setup"
        exit 1
    else
        # Port is free, start container
        print_status "Starting MongoDB container..."
        if docker run -d \
            --name telemetry-mongo \
            -p 27017:27017 \
            -e MONGO_INITDB_ROOT_USERNAME=admin \
            -e MONGO_INITDB_ROOT_PASSWORD=password \
            --restart unless-stopped \
            mongo:latest > /dev/null; then
            print_success "MongoDB container started"
            # Wait for MongoDB to be ready
            wait_for_service "MongoDB" 27017
            mongodb_skipped=false
        else
            print_error "Failed to start MongoDB container"
            exit 1
        fi
    fi
fi

# Redis setup
print_status "Setting up Redis..."

# First check if container already exists and is running
check_container "telemetry-redis"
redis_status=$?

if [ $redis_status -eq 0 ]; then
    # Container is already running
    print_success "Redis container is already running"
    redis_skipped=false
elif [ $redis_status -eq 2 ]; then
    # Container exists but not running, heal it
    heal_container "telemetry-redis" "Redis"
    redis_status=1
    redis_skipped=false
fi

# Only check port if we need to create a new container
if [ $redis_status -eq 1 ]; then
    # Check if Redis port is already in use
    check_port_in_use 6379 "Redis"
    redis_port_status=$?

    if [ $redis_port_status -eq 2 ]; then
        # User chose to skip Redis
        print_warning "Skipping Redis setup"
        redis_skipped=true
    elif [ $redis_port_status -eq 1 ]; then
        # Port issue couldn't be resolved
        print_error "Cannot proceed with Redis setup"
        exit 1
    else
        # Port is free, start container
        print_status "Starting Redis container..."
        if docker run -d \
            --name telemetry-redis \
            -p 6379:6379 \
            --restart unless-stopped \
            redis:latest > /dev/null; then
            print_success "Redis container started"
            # Wait for Redis to be ready
            wait_for_service "Redis" 6379
            redis_skipped=false
        else
            print_error "Failed to start Redis container"
            # Check if it's a port conflict error
            if docker logs telemetry-redis 2>&1 | grep -q "port is already allocated"; then
                print_error "Port 6379 is already allocated to another container"
                print_info "Try running: docker ps -a | grep 6379"
            fi
            exit 1
        fi
    fi
fi

# Display connection information
echo ""

# Determine success message based on what was set up
if [ "${mongodb_skipped:-false}" = true ] && [ "${redis_skipped:-false}" = true ]; then
    print_warning "No services were started"
    exit 0
elif [ "${mongodb_skipped:-false}" = true ] || [ "${redis_skipped:-false}" = true ]; then
    echo -e "${YELLOW}${BOLD}${WRENCH} Some services are ready ${WRENCH}${NC}"
else
    echo -e "${GREEN}${BOLD}${SPARKLES} All services are ready! ${SPARKLES}${NC}"
fi

echo ""
echo -e "${CYAN}${BOLD}Connection Details:${NC}"

if [ "${mongodb_skipped:-false}" != true ]; then
    echo -e "${PACKAGE} MongoDB: ${YELLOW}mongodb://admin:password@localhost:27017${NC}"
else
    echo -e "${PACKAGE} MongoDB: ${RED}Not running (skipped)${NC}"
fi

if [ "${redis_skipped:-false}" != true ]; then
    echo -e "${PACKAGE} Redis:   ${YELLOW}redis://localhost:6379${NC}"
else
    echo -e "${PACKAGE} Redis:   ${RED}Not running (skipped)${NC}"
fi

echo ""

# Show container status only if we have running containers
if docker ps | grep -E "telemetry-mongo|telemetry-redis" > /dev/null; then
    echo -e "${PURPLE}${BOLD}Container Status:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "telemetry-mongo|telemetry-redis"
    echo ""
fi

echo -e "${BLUE}To stop services: ${YELLOW}./scripts/stop-local-services.sh${NC}"

if [ "${mongodb_skipped:-false}" != true ] || [ "${redis_skipped:-false}" != true ]; then
    echo -e "${BLUE}To view logs:     ${YELLOW}docker logs telemetry-mongo${NC} or ${YELLOW}docker logs telemetry-redis${NC}"
fi

echo ""

# Show warnings if services were skipped
if [ "${mongodb_skipped:-false}" = true ] || [ "${redis_skipped:-false}" = true ]; then
    echo -e "${YELLOW}${WARNING} Warning: Some services were skipped!${NC}"
    echo -e "${YELLOW}The telemetry server may not function properly without all services.${NC}"
    echo ""
fi

echo -e "${GREEN}${ROCKET} Happy coding! ${ROCKET}${NC}"