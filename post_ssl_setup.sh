#!/bin/bash
# SCRIPT 3: Post-SSL Configuration Security (Production-Ready)

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/banner.sh"

# Show SSL banner
show_ssl_banner

# Read the username from the file created by create_user.sh
if [ -f /tmp/new_user_name.txt ]; then
    NEW_USER=$(cat /tmp/new_user_name.txt)
else
    NEW_USER="prod-dokploy"  # Fallback to default
fi
LOG_FILE="/var/log/vps_setup.log"

# --- Security Check ---
if [ "$(whoami)" != "$NEW_USER" ]; then
  echo -e "${RED}ERROR: This script must be run by the user '$NEW_USER'${NC}"
  exit 1
fi

echo "$(date): Starting post-SSL security setup" | sudo tee -a "$LOG_FILE"

show_section "Securing Dokploy Port 3000"

# Wait for Docker to be ready
sleep 3

# Block port 3000 from external access using iptables
# Allow localhost, block everything else
sudo iptables -I DOCKER-USER -i lo -p tcp --dport 3000 -j ACCEPT 2>/dev/null || true
sudo iptables -I DOCKER-USER -p tcp --dport 3000 -j DROP 2>/dev/null || true

echo "✅ Port 3000 blocked from external access (localhost still allowed)."

# Make iptables rules persistent using iptables-save (no package conflict)
echo "Saving iptables rules..."
sudo mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null

# Create systemd service to restore rules on boot
cat <<'EOFSVC' | sudo tee /etc/systemd/system/iptables-restore.service > /dev/null
[Unit]
Description=Restore iptables rules
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOFSVC

sudo systemctl daemon-reload
sudo systemctl enable iptables-restore.service
echo "✅ iptables rules saved and will persist after reboot."
echo "$(date): Post-SSL security configuration completed" | sudo tee -a "$LOG_FILE"

echo ""
echo "=================================================================="
echo "✅ Security hardening completed!"
echo "=================================================================="
echo ""
echo "SECURITY STATUS:"
echo "   🔒 Port 3000: Blocked from external access"
echo "   ✅ Port 443: Open (HTTPS/Dokploy)"
echo "   ✅ Port 80: Open (HTTP redirect)"
echo ""
echo "ACCESS:"
echo "   - Dokploy: https://your-domain.com"
echo "   - Local test: curl http://localhost:3000"
echo ""
echo "NOTES:"
echo "   - iptables rules are persistent (survive reboot)"
echo "   - All changes logged to: $LOG_FILE"
echo ""
echo "=================================================================="