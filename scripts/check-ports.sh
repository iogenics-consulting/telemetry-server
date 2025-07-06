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

echo -e "${PURPLE}${BOLD}Port Usage Check${NC}"
echo ""

# Check MongoDB port
echo -e "${CYAN}Checking port 27017 (MongoDB)...${NC}"
if lsof -i :27017 > /dev/null 2>&1; then
    echo -e "${YELLOW}Port 27017 is in use:${NC}"
    lsof -i :27017 | grep LISTEN
else
    echo -e "${GREEN}Port 27017 is free${NC}"
fi

echo ""

# Check Redis port
echo -e "${CYAN}Checking port 6379 (Redis)...${NC}"
if lsof -i :6379 > /dev/null 2>&1; then
    echo -e "${YELLOW}Port 6379 is in use:${NC}"
    lsof -i :6379 | grep LISTEN
else
    echo -e "${GREEN}Port 6379 is free${NC}"
fi

echo ""

# Check Telemetry Server port
echo -e "${CYAN}Checking port 8080 (Telemetry Server)...${NC}"
if lsof -i :8080 > /dev/null 2>&1; then
    echo -e "${YELLOW}Port 8080 is in use:${NC}"
    lsof -i :8080 | grep LISTEN
else
    echo -e "${GREEN}Port 8080 is free${NC}"
fi

echo ""

# Check Docker containers that might be using these ports
echo -e "${PURPLE}${BOLD}Docker Containers Using Ports:${NC}"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "27017|6379|8080" || echo "No containers found using these ports"