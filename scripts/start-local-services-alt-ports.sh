#!/bin/bash

# Alternative script that uses different ports to avoid conflicts
# MongoDB: 27018 (instead of 27017)
# Redis: 6380 (instead of 6379)

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
INFO="ℹ️"

echo -e "${PURPLE}${BOLD}"
echo "╔══════════════════════════════════════════════╗"
echo "║    Telemetry Server (Alternative Ports)      ║"
echo "║         MongoDB: 27018 | Redis: 6380         ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Docker
if ! docker info &> /dev/null; then
    echo -e "${RED}${CROSS_MARK} Docker is not running!${NC}"
    echo -e "${CYAN}Please start Docker and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}${CHECK_MARK} Docker is running${NC}"
echo ""

# Stop existing telemetry containers if they exist
echo -e "${BLUE}Cleaning up existing containers...${NC}"
docker stop telemetry-mongo-alt telemetry-redis-alt 2>/dev/null || true
docker rm telemetry-mongo-alt telemetry-redis-alt 2>/dev/null || true

# Start MongoDB on port 27018
echo -e "${BLUE}Starting MongoDB on port 27018...${NC}"
if docker run -d \
    --name telemetry-mongo-alt \
    -p 27018:27017 \
    -e MONGO_INITDB_ROOT_USERNAME=admin \
    -e MONGO_INITDB_ROOT_PASSWORD=password \
    --restart unless-stopped \
    mongo:latest > /dev/null; then
    echo -e "${GREEN}${CHECK_MARK} MongoDB started on port 27018${NC}"
else
    echo -e "${RED}${CROSS_MARK} Failed to start MongoDB${NC}"
    exit 1
fi

# Start Redis on port 6380
echo -e "${BLUE}Starting Redis on port 6380...${NC}"
if docker run -d \
    --name telemetry-redis-alt \
    -p 6380:6379 \
    --restart unless-stopped \
    redis:latest > /dev/null; then
    echo -e "${GREEN}${CHECK_MARK} Redis started on port 6380${NC}"
else
    echo -e "${RED}${CROSS_MARK} Failed to start Redis${NC}"
    exit 1
fi

# Wait for services
echo ""
echo -e "${BLUE}Waiting for services to be ready...${NC}"
sleep 3

# Verify services
echo ""
echo -e "${GREEN}${BOLD}✨ Services are ready! ✨${NC}"
echo ""
echo -e "${CYAN}${BOLD}Connection Details:${NC}"
echo -e "${PACKAGE} MongoDB: ${YELLOW}mongodb://admin:password@localhost:27018${NC}"
echo -e "${PACKAGE} Redis:   ${YELLOW}redis://localhost:6380${NC}"
echo ""
echo -e "${INFO} ${YELLOW}Note: Use .env.local or update your .env file with these ports${NC}"
echo -e "${INFO} ${YELLOW}Example: MONGO_URI=mongodb://localhost:27018${NC}"
echo -e "${INFO} ${YELLOW}         REDIS_URI=redis://localhost:6380${NC}"
echo ""
echo -e "${PURPLE}${BOLD}Container Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "telemetry-mongo-alt|telemetry-redis-alt"
echo ""
echo -e "${BLUE}To stop: ${YELLOW}docker stop telemetry-mongo-alt telemetry-redis-alt${NC}"
echo -e "${BLUE}To remove: ${YELLOW}docker rm telemetry-mongo-alt telemetry-redis-alt${NC}"
echo ""
echo -e "${GREEN}${ROCKET} Happy coding! ${ROCKET}${NC}"