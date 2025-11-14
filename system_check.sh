#!/bin/bash
# SCRIPT 4: System Health Check (Enhanced)

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/banner.sh"

# Show check banner
show_check_banner

# Read the username from the file created by create_user.sh
if [ -f /tmp/new_user_name.txt ]; then
    NEW_USER=$(cat /tmp/new_user_name.txt)
else
    NEW_USER="prod-dokploy"  # Fallback to default
fi
LOG_FILE="/var/log/vps_setup.log"

# Counters
ISSUES=0
WARNINGS=0

echo "$(date): Running system health check" | sudo tee -a "$LOG_FILE"

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to detect")
echo -e "${BLUE}🌍 Public IP: $PUBLIC_IP${NC}"
echo ""

# --- User Check ---
echo "👤 Current user: $(whoami)"
if [ "$(whoami)" = "$NEW_USER" ]; then
    echo -e "   ${GREEN}✅ Running as correct user${NC}"
else
    echo -e "   ${YELLOW}⚠️  Should be running as $NEW_USER${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# --- SSH Configuration ---
echo ""
echo "🔐 SSH Configuration:"
SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
echo "   Current SSH Port: $SSH_PORT"

# Check SSH socket status
if systemctl is-enabled ssh.socket 2>/dev/null | grep -q "masked"; then
    echo -e "   ${GREEN}✅ SSH socket: Properly masked${NC}"
elif systemctl is-enabled ssh.socket 2>/dev/null | grep -q "disabled"; then
    echo -e "   ${YELLOW}⚠️  SSH socket: Disabled (should be masked)${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "   ${RED}❌ SSH socket: ACTIVE (will override port on reboot!)${NC}"
    ISSUES=$((ISSUES + 1))
fi

# Check SSH service status
if systemctl is-enabled ssh.service 2>/dev/null | grep -q "enabled"; then
    echo -e "   ${GREEN}✅ SSH service: Enabled for boot${NC}"
else
    echo -e "   ${RED}❌ SSH service: Not enabled for boot${NC}"
    ISSUES=$((ISSUES + 1))
fi

# Test SSH connectivity
echo "   Testing SSH connectivity on port $SSH_PORT..."
if timeout 2 bash -c "echo > /dev/tcp/localhost/$SSH_PORT" 2>/dev/null; then
    echo -e "   ${GREEN}✅ SSH is responding on port $SSH_PORT${NC}"
else
    echo -e "   ${RED}❌ SSH not responding on port $SSH_PORT${NC}"
    ISSUES=$((ISSUES + 1))
fi

if [ -f /tmp/ssh_port_info.txt ]; then
    SAVED_PORT=$(cat /tmp/ssh_port_info.txt)
    echo "   Saved Port: $SAVED_PORT"
    if [ -f /tmp/ssh_connection_command.txt ]; then
        echo "   Connection Command: $(cat /tmp/ssh_connection_command.txt)"
    fi
else
    echo "   Warning: Port backup file not found"
fi

# --- Firewall Status ---
echo ""
echo "🛡️  Firewall Status:"
if command -v ufw &> /dev/null; then
    sudo ufw status numbered
else
    echo -e "   ${RED}❌ UFW not installed${NC}"
    ISSUES=$((ISSUES + 1))
fi

# --- Services Status ---
echo ""
echo "🔧 Critical Services:"
services=("ssh" "fail2ban" "docker")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo -e "   ${GREEN}✅ $service: Active${NC}"
    else
        echo -e "   ${RED}❌ $service: Inactive${NC}"
        ISSUES=$((ISSUES + 1))
    fi
done

# UFW is not a systemd service, check differently
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        echo -e "   ${GREEN}✅ ufw: Active${NC}"
    else
        echo -e "   ${YELLOW}⚠️  ufw: Installed but inactive${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "   ${RED}❌ ufw: Not installed${NC}"
    ISSUES=$((ISSUES + 1))
fi

# --- Docker Containers ---
echo ""
echo "🐳 Docker Status:"
if command -v docker &> /dev/null; then
    echo "   Docker version: $(docker --version)"
    echo "   Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Check Dokploy specifically
    echo ""
    echo "   Dokploy Status:"
    if docker ps | grep -q dokploy; then
        echo -e "   ${GREEN}✅ Dokploy container is running${NC}"
        
        # Test HTTP response
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
            echo -e "   ${GREEN}✅ Dokploy is responding (HTTP $HTTP_CODE)${NC}"
            echo -e "   ${BLUE}🌐 Access: http://$PUBLIC_IP:3000${NC}"
        else
            echo -e "   ${YELLOW}⚠️  Dokploy not responding on port 3000 (HTTP $HTTP_CODE)${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo -e "   ${RED}❌ Dokploy container not found${NC}"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo -e "   ${RED}❌ Docker not installed${NC}"
    ISSUES=$((ISSUES + 1))
fi

# --- Disk Usage ---
echo ""
echo "💾 Disk Usage:"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
df -h / | awk 'NR==2 {printf "   Root: %s used, %s available (%s)\n", $3, $4, $5}'
if [ "$DISK_USAGE" -gt 80 ]; then
    echo -e "   ${RED}❌ Disk usage above 80%!${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$DISK_USAGE" -gt 70 ]; then
    echo -e "   ${YELLOW}⚠️  Disk usage above 70%${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# --- Memory Usage ---
echo ""
echo "🧠 Memory Usage:"
MEM_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
free -h | awk 'NR==2 {printf "   RAM: %s used, %s available\n", $3, $7}'
if [ "$MEM_USAGE" -gt 90 ]; then
    echo -e "   ${RED}❌ Memory usage above 90%!${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$MEM_USAGE" -gt 80 ]; then
    echo -e "   ${YELLOW}⚠️  Memory usage above 80%${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# --- Network Ports ---
echo ""
echo "🌐 Open Ports:"
ss -tuln | grep LISTEN | awk '{print "   " $1 " " $5}' | sort

# --- Recent Log Entries ---
echo ""
echo "📋 Recent Setup Log (last 5 entries):"
if [ -f "$LOG_FILE" ]; then
    tail -5 "$LOG_FILE" | sed 's/^/   /'
else
    echo "   No setup log found"
fi

# --- iptables Rules (after SSL) ---
echo ""
echo "🔒 iptables Rules:"
if sudo iptables -L DOCKER-USER -n 2>/dev/null | grep -q "tcp dpt:3000"; then
    echo -e "   ${GREEN}✅ Port 3000 rules configured${NC}"
    sudo iptables -L DOCKER-USER -n | grep "3000" | sed 's/^/   /'
else
    if ss -tuln | grep -q ":3000 "; then
        echo -e "   ${YELLOW}⚠️  Port 3000 is open - run post_ssl_setup.sh after SSL configuration${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# --- Security Recommendations ---
echo ""
echo "🔍 Security Status:"
if ! sudo ufw status | grep -q "Status: active"; then
    echo -e "   ${RED}❌ UFW firewall is not active${NC}"
    ISSUES=$((ISSUES + 1))
fi

# Check if default SSH port is blocked
if sudo ufw status | grep -q "22.*DENY"; then
    echo -e "   ${GREEN}✅ Default SSH port (22) is blocked${NC}"
else
    echo -e "   ${YELLOW}⚠️  Default SSH port (22) not explicitly blocked${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# --- Summary ---
echo ""
echo "==================================================================="
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ HEALTH CHECK PASSED - No issues found!${NC}"
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}⚠️  HEALTH CHECK COMPLETED - $WARNINGS warning(s) found${NC}"
else
    echo -e "${RED}❌ HEALTH CHECK FAILED - $ISSUES issue(s) and $WARNINGS warning(s) found${NC}"
fi
echo "==================================================================="
echo ""

# Exit with appropriate code
if [ $ISSUES -gt 0 ]; then
    exit 1
else
    exit 0
fi