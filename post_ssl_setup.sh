#!/bin/bash
# SCRIPT 3: Post-SSL Configuration Security (Production-Ready with Best Practices)

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/banner.sh"

# Show SSL banner
show_ssl_banner

# Read the username from the file created by create_user.sh
USER_FILE="$HOME/.vps_setup_user"
if [ -f "$USER_FILE" ]; then
    NEW_USER=$(cat "$USER_FILE")
elif [ -f /tmp/new_user_name.txt ]; then
    NEW_USER=$(cat /tmp/new_user_name.txt)
else
    NEW_USER="prod-dokploy"  # Fallback to default
fi
LOG_FILE="/var/log/vps_setup.log"

# --- Security Check ---
if [ "$(whoami)" != "$NEW_USER" ]; then
  echo -e "${RED}ERROR: This script must be run by the user '$NEW_USER'${NC}"
  echo "Current user: $(whoami)"
  exit 1
fi

echo "$(date): Starting post-SSL security setup" | sudo tee -a "$LOG_FILE"

show_section "Securing Dokploy Port 3000"

# --- Verify SSL is actually configured ---
echo "→ Verifying SSL/HTTPS is configured..."
echo ""
echo "Before blocking port 3000, please confirm:"
echo "  1. You have configured your domain in Dokploy"
echo "  2. SSL certificate is installed and working"
echo "  3. You can access Dokploy via HTTPS (https://your-domain.com)"
echo ""
read -p "Is SSL/HTTPS working correctly? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo ""
    echo "=================================================================="
    echo "  ⚠️  SSL Not Ready - Aborting"
    echo "=================================================================="
    echo ""
    echo "Port 3000 will remain open until SSL is properly configured."
    echo "Once SSL is working, run this script again."
    echo ""
    exit 0
fi

# Wait for Docker to be ready
echo "→ Checking Docker status..."
if ! sudo systemctl is-active --quiet docker; then
    echo "❌ Docker is not running"
    exit 1
fi
echo "✅ Docker is running"

# Verify Dokploy is accessible locally
echo "→ Testing Dokploy local access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
if [[ ! "$HTTP_CODE" =~ ^(200|301|302|401)$ ]]; then
    echo "⚠️  Warning: Dokploy not responding on localhost:3000 (HTTP $HTTP_CODE)"
    echo "This might cause issues. Continue anyway? (yes/no)"
    read -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        exit 0
    fi
else
    echo "✅ Dokploy is accessible locally"
fi

# Backup current iptables rules
echo "→ Backing up current iptables rules..."
sudo mkdir -p /etc/iptables/backups
sudo iptables-save | sudo tee /etc/iptables/backups/rules.v4.$(date +%Y%m%d_%H%M%S) > /dev/null

# Create DOCKER-USER chain if it doesn't exist
if ! sudo iptables -L DOCKER-USER -n &>/dev/null; then
    echo "→ Creating DOCKER-USER chain..."
    sudo iptables -N DOCKER-USER
    sudo iptables -I FORWARD -j DOCKER-USER
    sudo iptables -A DOCKER-USER -j RETURN
fi

# Block port 3000 from external access using iptables
# Allow localhost, block everything else
echo "→ Configuring iptables rules for port 3000..."

# Remove any existing rules for port 3000
sudo iptables -D DOCKER-USER -p tcp --dport 3000 -j DROP 2>/dev/null || true
sudo iptables -D DOCKER-USER -i lo -p tcp --dport 3000 -j ACCEPT 2>/dev/null || true

# Add new rules (order matters: ACCEPT first, then DROP)
sudo iptables -I DOCKER-USER 1 -p tcp --dport 3000 -j DROP || {
    echo "❌ Failed to add DROP rule"
    exit 1
}
sudo iptables -I DOCKER-USER 1 -i lo -p tcp --dport 3000 -j ACCEPT || {
    echo "❌ Failed to add ACCEPT rule"
    exit 1
}

echo "✅ Port 3000 blocked from external access (localhost still allowed)"

# Verify rules are in place
echo "→ Verifying iptables rules..."
if sudo iptables -L DOCKER-USER -n | grep -q "tcp dpt:3000"; then
    echo "✅ Rules verified"
    sudo iptables -L DOCKER-USER -n -v | grep "3000" | sed 's/^/  /'
else
    echo "❌ Rules not found in iptables"
    exit 1
fi

# Make iptables rules persistent
echo "→ Making iptables rules persistent..."
sudo mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null

# Use netfilter-persistent if available, otherwise create systemd service
if command -v netfilter-persistent &> /dev/null; then
    echo "→ Using netfilter-persistent..."
    if sudo netfilter-persistent save 2>/dev/null; then
        sudo systemctl enable netfilter-persistent 2>/dev/null || true
        echo "  ✅ Rules saved with netfilter-persistent"
    else
        echo "  ⚠️  netfilter-persistent failed, using systemd service instead..."
        # Fall through to systemd service creation
    fi
fi

# If netfilter-persistent is not available or failed, create systemd service
if ! command -v netfilter-persistent &> /dev/null || ! sudo systemctl is-enabled netfilter-persistent &>/dev/null; then
    echo "→ Creating systemd service for iptables restore..."
    # Create systemd service to restore rules on boot
    cat <<'EOFSVC' | sudo tee /etc/systemd/system/iptables-restore.service > /dev/null
[Unit]
Description=Restore iptables rules
Before=network-pre.target docker.service
Wants=network-pre.target
After=systemd-sysctl.service

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
ExecReload=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOFSVC

    sudo systemctl daemon-reload
    sudo systemctl enable iptables-restore.service
fi

echo "✅ iptables rules saved and will persist after reboot"
echo "$(date): Post-SSL security configuration completed" | sudo tee -a "$LOG_FILE"

# --- Test external access is blocked ---
echo ""
echo "→ Testing external access blocking..."
PUBLIC_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || echo "")

if [ -n "$PUBLIC_IP" ]; then
    echo "  Testing from external IP: $PUBLIC_IP"
    # This should fail/timeout
    if timeout 3 curl -s http://$PUBLIC_IP:3000 &>/dev/null; then
        echo "  ⚠️  WARNING: Port 3000 is still accessible externally!"
        echo "  This might be a firewall configuration issue."
    else
        echo "  ✅ Port 3000 is properly blocked from external access"
    fi
fi

# Test local access still works
echo "→ Testing local access..."
if timeout 3 curl -s http://localhost:3000 &>/dev/null; then
    echo "  ✅ Local access to port 3000 still works"
else
    echo "  ⚠️  WARNING: Local access to port 3000 failed"
    echo "  Dokploy might not be running properly"
fi

echo ""
show_success_banner

show_info_box "Security Hardening Completed" \
    "${GREEN}✓${NC} Port 3000: Blocked from external access" \
    "${GREEN}✓${NC} Port 443: Open (HTTPS/Dokploy)" \
    "${GREEN}✓${NC} Port 80: Open (HTTP redirect)" \
    "${GREEN}✓${NC} iptables rules: Persistent across reboots" \
    "" \
    "Backup saved: ${GRAY}/etc/iptables/backups/${NC}"

show_info_box "Access Information" \
    "Dokploy Web: ${CYAN}https://your-domain.com${NC}" \
    "Local Test: ${CYAN}curl http://localhost:3000${NC}" \
    "" \
    "Logs: ${GRAY}$LOG_FILE${NC}"

show_info_box "Verification Commands" \
    "Check iptables: ${CYAN}sudo iptables -L DOCKER-USER -n -v${NC}" \
    "Check Dokploy: ${CYAN}sudo docker ps | grep dokploy${NC}" \
    "Test local: ${CYAN}curl -I http://localhost:3000${NC}" \
    "System check: ${CYAN}./system_check.sh${NC}"

echo ""
echo "=================================================================="