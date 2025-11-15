#!/bin/bash
# Docker Configuration Script (Production-Ready with Best Practices)
# Configures logging, storage driver, and network cleanup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "=================================================================="
echo "  🐳 Docker Configuration"
echo "=================================================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

# Check if Docker is running
if ! sudo systemctl is-active --quiet docker; then
    echo -e "${YELLOW}⚠️  Docker is not running, starting...${NC}"
    sudo systemctl start docker || {
        echo -e "${RED}❌ Failed to start Docker${NC}"
        exit 1
    }
fi

echo -e "${GREEN}✓${NC} Docker is running"
echo ""

# Backup existing daemon.json if it exists
if [ -f /etc/docker/daemon.json ]; then
    BACKUP_FILE="/etc/docker/daemon.json.bak.$(date +%Y%m%d_%H%M%S)"
    echo "→ Backing up existing daemon.json to $BACKUP_FILE"
    sudo cp /etc/docker/daemon.json "$BACKUP_FILE"
fi

# Create or update daemon.json
echo "→ Configuring Docker daemon..."
sudo mkdir -p /etc/docker

sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "compress": "true"
  },
  "storage-driver": "overlay2",
  "default-address-pools": [
    {
      "base": "172.17.0.0/12",
      "size": 24
    }
  ],
  "userland-proxy": false,
  "iptables": true,
  "log-level": "warn"
}
EOF

echo -e "${YELLOW}⚠️  Note: live-restore is disabled (incompatible with Docker Swarm/Dokploy)${NC}"

echo -e "${GREEN}✓${NC} daemon.json configured"
echo ""

# Validate JSON syntax
echo "→ Validating configuration..."
if ! python3 -m json.tool /etc/docker/daemon.json > /dev/null 2>&1; then
    echo -e "${RED}❌ Invalid JSON in daemon.json${NC}"
    if [ -f "$BACKUP_FILE" ]; then
        echo "→ Restoring backup..."
        sudo cp "$BACKUP_FILE" /etc/docker/daemon.json
    fi
    exit 1
fi
echo -e "${GREEN}✓${NC} Configuration is valid"
echo ""

# Check if any containers are running
RUNNING_CONTAINERS=$(sudo docker ps -q | wc -l)
if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: $RUNNING_CONTAINERS container(s) running${NC}"
    echo "Restarting Docker will temporarily stop these containers."
    echo ""
    echo "Running containers:"
    sudo docker ps --format "  - {{.Names}} ({{.Status}})"
    echo ""
    read -p "Continue with Docker restart? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        echo "Configuration saved but not applied."
        echo "Restart Docker manually when ready: sudo systemctl restart docker"
        exit 0
    fi
fi

# Restart Docker to apply changes
echo "→ Restarting Docker..."
sudo systemctl restart docker || {
    echo -e "${RED}❌ Failed to restart Docker${NC}"
    if [ -f "$BACKUP_FILE" ]; then
        echo "→ Restoring backup..."
        sudo cp "$BACKUP_FILE" /etc/docker/daemon.json
        sudo systemctl restart docker
    fi
    exit 1
}

# Wait for Docker to be ready
echo "→ Waiting for Docker to be ready..."
for i in {1..30}; do
    if sudo docker info &>/dev/null; then
        echo -e "${GREEN}✓${NC} Docker is operational"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Docker failed to start after 30 seconds${NC}"
        exit 1
    fi
    sleep 1
done
echo ""

# Verify containers restarted
if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    echo "→ Checking containers..."
    sleep 3
    CURRENT_RUNNING=$(sudo docker ps -q | wc -l)
    if [ "$CURRENT_RUNNING" -eq "$RUNNING_CONTAINERS" ]; then
        echo -e "${GREEN}✓${NC} All containers restarted successfully"
    else
        echo -e "${YELLOW}⚠️  Warning: Only $CURRENT_RUNNING/$RUNNING_CONTAINERS containers running${NC}"
        echo "Check container status: sudo docker ps -a"
    fi
    echo ""
fi

# Clean up unused networks
echo "→ Cleaning up unused Docker networks..."
PRUNED=$(sudo docker network prune -f 2>&1 | grep "Deleted Networks" || echo "")
if [ -n "$PRUNED" ]; then
    echo -e "${GREEN}✓${NC} $PRUNED"
else
    echo -e "${GREEN}✓${NC} No unused networks to clean"
fi
echo ""

# Display current configuration
echo "=================================================================="
echo "  ✅ Docker Configuration Complete"
echo "=================================================================="
echo ""
echo "Current settings:"
echo "  • Log rotation: 10MB max, 3 files, compressed"
echo "  • Storage driver: overlay2"
echo "  • Network pool: 172.17.0.0/12"
echo "  • Live restore: disabled (Swarm-compatible)"
echo "  • Userland proxy: disabled (better performance)"
echo ""
echo "Verification commands:"
echo "  • Check config: ${CYAN}sudo docker info${NC}"
echo "  • View logs: ${CYAN}sudo journalctl -u docker -n 50${NC}"
echo "  • List containers: ${CYAN}sudo docker ps${NC}"
echo ""
echo "=================================================================="
