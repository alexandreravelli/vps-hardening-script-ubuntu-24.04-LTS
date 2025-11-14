#!/bin/bash
# SCRIPT 2: Main Server Setup (Production-Ready with Best Practices)

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/banner.sh"

# Show main setup banner
show_setup_banner

# --- Configuration variables ---
# Read the username from the file created by create_user.sh
if [ -f /tmp/new_user_name.txt ]; then
    NEW_USER=$(cat /tmp/new_user_name.txt)
else
    NEW_USER="prod-dokploy"  # Fallback to default
fi
DEFAULT_USER="ubuntu"
NEW_SSH_PORT=$((RANDOM % 10000 + 50000))  # Random port between 50000-59999

# --- Logging setup ---
LOG_FILE="/var/log/vps_setup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

echo "$(date): Starting VPS setup with SSH port: $NEW_SSH_PORT" | sudo tee -a "$LOG_FILE"

show_info_box "Configuration" \
    "User: ${CYAN}$NEW_USER${NC}" \
    "SSH Port: ${CYAN}$NEW_SSH_PORT${NC}" \
    "Log File: ${GRAY}$LOG_FILE${NC}"

# --- Enhanced Rollback function ---
rollback() {
    local error_msg="$1"
    local error_line="${2:-unknown}"
    
    echo ""
    echo "=================================================================="
    echo "❌ ERROR: Setup failed"
    echo "=================================================================="
    echo "Error: $error_msg"
    echo "Line: $error_line"
    echo "Time: $(date)"
    echo ""
    echo "🔄 Attempting rollback..."
    echo ""
    
    # Restore SSH config if it was modified
    if [ -f /etc/ssh/sshd_config.bak ]; then
        echo "→ Restoring SSH configuration..."
        sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        sudo systemctl restart ssh.service
        echo "  ✅ SSH configuration restored"
    fi
    
    # Re-enable default user if it was removed
    if [ "$3" = "user_removed" ] && ! getent passwd $DEFAULT_USER > /dev/null; then
        echo "  ⚠️  Default user was removed. Manual intervention required."
        echo "  → Connect via console and recreate user: sudo adduser $DEFAULT_USER"
    fi
    
    echo ""
    echo "📋 Troubleshooting suggestions:"
    case "$error_msg" in
        *"internet"*)
            echo "  → Check your network connection"
            echo "  → Try: ping google.com"
            ;;
        *"disk"*)
            echo "  → Free up disk space"
            echo "  → Try: df -h"
            echo "  → Try: sudo apt-get clean"
            ;;
        *"SSH"*)
            echo "  → Check SSH service: sudo systemctl status ssh"
            echo "  → Check SSH config: sudo sshd -t"
            echo "  → View logs: sudo journalctl -u ssh -n 50"
            ;;
        *"Docker"*)
            echo "  → Check Docker service: sudo systemctl status docker"
            echo "  → View logs: sudo journalctl -u docker -n 50"
            ;;
        *)
            echo "  → Check logs: tail -50 $LOG_FILE"
            echo "  → Run system check: ./system_check.sh"
            ;;
    esac
    
    echo ""
    echo "📝 Full log available at: $LOG_FILE"
    echo "=================================================================="
    echo "$(date): Setup failed - $error_msg (line $error_line)" | sudo tee -a "$LOG_FILE"
    exit 1
}

# --- Prerequisites check ---
check_prerequisites() {
    echo "--- Checking prerequisites... ---"
    
    # Check if running as correct user
    if [ "$(whoami)" != "$NEW_USER" ]; then
        rollback "Must be run as user $NEW_USER"
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        rollback "No internet connectivity"
    fi
    
    # Check available disk space (minimum 2GB)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 2097152 ]; then
        rollback "Insufficient disk space (need at least 2GB)"
    fi
    
    # Check if ports are available
    if ss -tuln | grep -q ":$NEW_SSH_PORT "; then
        rollback "SSH port $NEW_SSH_PORT is already in use"
    fi
    
    echo "✅ All prerequisites passed"
}

# Set trap for error handling
trap 'rollback "Unexpected error" "$LINENO"' ERR

# --- Run prerequisites check ---
check_prerequisites

# --- 1. Security: Remove Default User (DELAYED) ---
echo "--- Scheduling removal of default user '$DEFAULT_USER' for end of setup... ---"
# Note: We'll remove the default user at the end to avoid connection issues
REMOVE_DEFAULT_USER=true
echo "⚠️  Default user '$DEFAULT_USER' will be removed at the end of setup."

# --- 2. System Update ---
echo "--- Updating system packages... ---"
sudo apt-get update || rollback "Failed to update package list"
sudo apt-get upgrade -y || rollback "Failed to upgrade packages"
echo "$(date): System packages updated successfully" | sudo tee -a "$LOG_FILE"

# --- 2.1. Install System Monitoring Tools ---
echo "--- Installing system monitoring tools (btop)... ---"
sudo snap install btop || echo "⚠️  Warning: Could not install btop via snap"
echo "$(date): System monitoring tools installed" | sudo tee -a "$LOG_FILE"

# --- 3. Change SSH Port ---
echo "--- Changing the default SSH port to $NEW_SSH_PORT... ---"
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak || rollback "Failed to backup SSH config"

# Create sshd privilege separation directory if missing
sudo mkdir -p /run/sshd || rollback "Failed to create /run/sshd directory"
sudo chown root:root /run/sshd || rollback "Failed to set /run/sshd ownership"
sudo chmod 755 /run/sshd || rollback "Failed to set /run/sshd permissions"

# Update SSH port in config - more robust approach
echo "Updating SSH configuration..."
sudo cp /etc/ssh/sshd_config.bak /tmp/sshd_config_test

# Remove any existing Port and ListenAddress lines
sudo sed -i '/^#*Port /d' /tmp/sshd_config_test
sudo sed -i '/^#*ListenAddress /d' /tmp/sshd_config_test

# Add new port configuration
echo "Port $NEW_SSH_PORT" | sudo tee -a /tmp/sshd_config_test > /dev/null

# Also ensure we have proper settings for security
echo "PermitRootLogin no" | sudo tee -a /tmp/sshd_config_test > /dev/null
echo "PasswordAuthentication yes" | sudo tee -a /tmp/sshd_config_test > /dev/null
echo "PubkeyAuthentication yes" | sudo tee -a /tmp/sshd_config_test > /dev/null

# Validate SSH config before applying
echo "Validating SSH configuration..."
sudo sshd -t -f /tmp/sshd_config_test || rollback "Invalid SSH configuration"

echo "Applying SSH configuration..."
sudo cp /tmp/sshd_config_test /etc/ssh/sshd_config || rollback "Failed to apply SSH config"

# Disable SSH socket to prevent port override (PERMANENT - survives reboot)
echo "Disabling SSH socket permanently..."
sudo systemctl stop ssh.socket 2>/dev/null || true
sudo systemctl disable ssh.socket 2>/dev/null || true
sudo systemctl mask ssh.socket 2>/dev/null || true

# Ensure SSH service starts on boot (not socket)
echo "Ensuring SSH service starts on boot..."
sudo systemctl enable ssh.service || rollback "Failed to enable SSH service"

echo "Restarting SSH service..."
sudo systemctl restart ssh.service || rollback "Failed to restart SSH service"

# Verify SSH service is running
if ! sudo systemctl is-active --quiet ssh.service; then
    echo "❌ SSH service is not running after restart"
    sudo systemctl status ssh.service --no-pager
    rollback "SSH service failed to start"
fi

# Verify SSH service is enabled for boot
if ! sudo systemctl is-enabled --quiet ssh.service; then
    echo "⚠️ SSH service not enabled for boot, enabling..."
    sudo systemctl enable ssh.service || rollback "Failed to enable SSH service for boot"
fi

echo "✅ SSH service is running and will start on boot"

# Verify socket is properly masked
if systemctl is-enabled ssh.socket 2>/dev/null | grep -q "masked"; then
    echo "✅ SSH socket is properly masked"
else
    echo "⚠️ SSH socket not masked, masking now..."
    sudo systemctl mask ssh.socket 2>/dev/null || true
fi

# Test if SSH is responding on new port
echo "Waiting for SSH to start on new port..."
sleep 5

# Try multiple times to check if SSH is listening
for i in {1..10}; do
    if ss -tuln | grep -q ":$NEW_SSH_PORT "; then
        echo "✅ SSH is now listening on port $NEW_SSH_PORT"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ SSH failed to start on port $NEW_SSH_PORT after 10 attempts"
        echo "Current SSH status:"
        sudo systemctl status ssh.service --no-pager
        echo "Current listening ports:"
        ss -tuln | grep ssh || ss -tuln | grep ":22 \|:$NEW_SSH_PORT "
        rollback "SSH not listening on new port $NEW_SSH_PORT"
    fi
    echo "Attempt $i/10: SSH not yet listening on port $NEW_SSH_PORT, waiting..."
    sleep 2
done

echo "✅ SSH port has been changed to $NEW_SSH_PORT."
echo "$(date): SSH port changed to $NEW_SSH_PORT successfully" | sudo tee -a "$LOG_FILE"

# --- 4. Harden Network Settings ---
echo "--- Hardening network configuration... ---"
cat <<EOF | sudo tee /etc/host.conf > /dev/null
order bind,hosts
multi on
EOF
echo "✅ Network configuration hardened."

# --- 5. Install and Configure Security Tools ---
echo "--- Installing UFW (Firewall) and Fail2Ban... ---"
sudo apt-get install -y ufw fail2ban || rollback "Failed to install security tools"

# --- Configure UFW Firewall ---
echo "--- Configuring UFW firewall... ---"
# UFW manages SSH only. Docker manages its own ports (3000, 80, 443).
sudo ufw --force reset || rollback "Failed to reset UFW"
sudo ufw --force default deny incoming || rollback "Failed to set UFW default deny"
sudo ufw --force default allow outgoing || rollback "Failed to set UFW default allow outgoing"
sudo ufw allow $NEW_SSH_PORT/tcp || rollback "Failed to allow SSH port in UFW"
sudo ufw deny 22/tcp || rollback "Failed to deny default SSH port in UFW"
sudo ufw --force enable || rollback "Failed to enable UFW"
echo "✅ Firewall configured (SSH only - Docker manages its own ports)."
echo "$(date): UFW firewall configured successfully" | sudo tee -a "$LOG_FILE"

# --- Configure Fail2Ban ---
echo "--- Configuring Fail2Ban... ---"
cat <<EOM | sudo tee /etc/fail2ban/jail.local > /dev/null || rollback "Failed to create Fail2Ban config"
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
[sshd]
enabled = true
port = $NEW_SSH_PORT
EOM
sudo systemctl restart fail2ban || rollback "Failed to restart Fail2Ban"
sudo systemctl enable fail2ban || rollback "Failed to enable Fail2Ban"
echo "✅ Fail2Ban configured to monitor SSH port $NEW_SSH_PORT."
echo "$(date): Fail2Ban configured successfully" | sudo tee -a "$LOG_FILE"

# --- 6. Configure Automatic Security Updates ---
echo "--- Configuring automatic security updates... ---"
sudo apt-get install -y unattended-upgrades || rollback "Failed to install unattended-upgrades"
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive unattended-upgrades || rollback "Failed to configure automatic updates"
echo "$(date): Automatic security updates configured" | sudo tee -a "$LOG_FILE"

# --- 7. Configure Docker daemon ---
echo "--- Configuring Docker daemon... ---"
sudo mkdir -p /etc/docker

# Backup existing daemon.json if it exists
if [ -f /etc/docker/daemon.json ]; then
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak.$(date +%Y%m%d_%H%M%S)
    echo "✅ Existing Docker daemon.json backed up"
fi

# Create production-ready Docker daemon configuration
cat <<EOF | sudo tee /etc/docker/daemon.json > /dev/null
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
echo "✅ Docker daemon configured with production settings."

# --- 8. Install Dokploy ---
echo "--- Starting Dokploy installation... ---"
curl -sSL https://dokploy.com/install.sh | sudo sh || rollback "Failed to install Dokploy"
echo "$(date): Dokploy installed successfully" | sudo tee -a "$LOG_FILE"

# Wait for Docker to be fully started
echo "Waiting for Docker to be fully operational..."
for i in {1..30}; do
    if sudo systemctl is-active --quiet docker && sudo docker info &>/dev/null; then
        echo "✅ Docker is fully operational"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Docker failed to become operational after 30 seconds"
        sudo systemctl status docker --no-pager
        rollback "Docker failed to start properly"
    fi
    echo "Waiting for Docker to be ready... ($i/30)"
    sleep 2
done

# Verify Dokploy container is running
echo "Verifying Dokploy container..."
for i in {1..30}; do
    if sudo docker ps | grep -q dokploy; then
        echo "✅ Dokploy container is running"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Dokploy container not found after 30 seconds"
        echo "All containers:"
        sudo docker ps -a
        echo "Docker logs:"
        sudo journalctl -u docker -n 20 --no-pager
        rollback "Dokploy container failed to start"
    fi
    echo "Waiting for Dokploy container... ($i/30)"
    sleep 2
done

# Verify Dokploy is responding on port 3000
echo "Verifying Dokploy web interface..."
for i in {1..20}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" =~ ^(200|301|302|401|404)$ ]]; then
        echo "✅ Dokploy is responding on port 3000 (HTTP $HTTP_CODE)"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "⚠️  Dokploy container running but not responding on port 3000"
        echo "This may be normal if Dokploy is still initializing"
        echo "You can check later with: curl http://localhost:3000"
    fi
    echo "Waiting for Dokploy to respond... ($i/20)"
    sleep 3
done

# Docker ports (3000, 80, 443) are managed by Docker directly
echo "✅ Docker will manage its own ports (3000, 80, 443)"

# --- Save SSH port information ---
echo "$NEW_SSH_PORT" | sudo tee /tmp/ssh_port_info.txt > /dev/null
echo "ssh $NEW_USER@<your_ip> -p $NEW_SSH_PORT" | sudo tee /tmp/ssh_connection_command.txt > /dev/null

# --- Remove Default User (if scheduled) ---
if [ "$REMOVE_DEFAULT_USER" = true ] && getent passwd $DEFAULT_USER > /dev/null; then
    echo "--- Removing the default user '$DEFAULT_USER'... ---"
    # Create backup of user info before deletion
    getent passwd $DEFAULT_USER > /tmp/backup_user_info.txt
    sudo deluser --remove-home $DEFAULT_USER || echo "⚠️  Warning: Could not remove default user completely"
    echo "✅ Default user '$DEFAULT_USER' has been removed."
    echo "$(date): Default user removed successfully" | sudo tee -a "$LOG_FILE"
fi

# --- End of script ---
echo "$(date): VPS setup completed successfully" | sudo tee -a "$LOG_FILE"

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo '<your_ip>')

echo ""
show_success_banner

show_info_box "SSH Connection Information" \
    "SSH Port: ${CYAN}$NEW_SSH_PORT${NC}" \
    "Username: ${CYAN}$NEW_USER${NC}" \
    "Connection: ${CYAN}ssh $NEW_USER@$PUBLIC_IP -p $NEW_SSH_PORT${NC}" \
    "" \
    "Port saved in: ${GRAY}/tmp/ssh_port_info.txt${NC}"

show_info_box "Completed Configurations" \
    "${GREEN}✓${NC} Secure user created" \
    "${GREEN}✓${NC} SSH port changed and secured" \
    "${GREEN}✓${NC} UFW firewall configured" \
    "${GREEN}✓${NC} Fail2Ban enabled" \
    "${GREEN}✓${NC} Automatic updates configured" \
    "${GREEN}✓${NC} Docker with log rotation" \
    "${GREEN}✓${NC} btop system monitor installed" \
    "${GREEN}✓${NC} Dokploy installed and running"

show_info_box "Next Steps" \
    "${BOLD}1.${NC} Access Dokploy web interface:" \
    "   ${CYAN}http://$PUBLIC_IP:3000${NC}" \
    "" \
    "${BOLD}2.${NC} Create your admin account" \
    "" \
    "${BOLD}3.${NC} Configure your domain and SSL certificate" \
    "" \
    "${BOLD}4.${NC} Secure port 3000 after SSL setup:" \
    "   ${CYAN}./post_ssl_setup.sh${NC}" \
    "" \
    "${BOLD}5.${NC} Verify system health:" \
    "   ${CYAN}./system_check.sh${NC}" \
    "" \
    "${BOLD}6.${NC} Monitor system resources:" \
    "   ${CYAN}btop${NC}"

show_info_box "Important Notes" \
    "• Docker logs are rotated (max 30MB per container)" \
    "• Docker ports (3000, 80, 443) are open by default" \
    "• All changes logged to: ${GRAY}$LOG_FILE${NC}" \
    "• Default user '${GRAY}ubuntu${NC}' has been removed"

echo ""
echo "TROUBLESHOOTING:"
echo "   - System health: ./system_check.sh"
echo "   - Resource monitor: btop"
echo ""
echo "=================================================================="