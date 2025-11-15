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
USER_FILE="$HOME/.vps_setup_user"
if [ -f "$USER_FILE" ]; then
    NEW_USER=$(cat "$USER_FILE")
elif [ -f /tmp/new_user_name.txt ]; then
    NEW_USER=$(cat /tmp/new_user_name.txt)
    # Migrate to persistent location
    echo "$NEW_USER" > "$USER_FILE"
else
    echo ""
    echo -e "${RED}❌ ERROR: Username file not found!${NC}"
    echo ""
    echo "This script must be run after creating a user with create_user.sh or install.sh"
    echo ""
    echo "Please run one of these first:"
    echo "  ./install.sh"
    echo "  OR"
    echo "  ./create_user.sh"
    echo ""
    exit 1
fi
DEFAULT_USER="ubuntu"

# Generate random SSH port and verify it's not in use
generate_ssh_port() {
    local port
    local max_attempts=10
    for ((i=1; i<=max_attempts; i++)); do
        port=$((RANDOM % 10000 + 50000))
        if ! ss -tuln | grep -q ":$port "; then
            echo "$port"
            return 0
        fi
    done
    echo "50022"  # Fallback port
}

NEW_SSH_PORT=$(generate_ssh_port)

# --- Logging setup ---
LOG_FILE="/var/log/vps_setup.log"
# Ensure log file exists with proper permissions (640 = root + group only)
sudo touch "$LOG_FILE"
sudo chmod 640 "$LOG_FILE"
sudo chown root:adm "$LOG_FILE"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

echo "$(date): Starting VPS setup with SSH port: $NEW_SSH_PORT" | sudo tee -a "$LOG_FILE"

show_info_box "Configuration" \
    "User: ${CYAN}$NEW_USER${NC}" \
    "SSH Port: ${CYAN}$NEW_SSH_PORT${NC}" \
    "Log File: ${GRAY}$LOG_FILE${NC}"

# --- State Management ---
STATE_DIR="$HOME/.vps_setup_state"
mkdir -p "$STATE_DIR"

save_state() {
    local state_name="$1"
    echo "$(date +%s)" > "$STATE_DIR/$state_name"
}

check_state() {
    local state_name="$1"
    [ -f "$STATE_DIR/$state_name" ]
}

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
    
    # Restore UFW if it was configured
    if [ -f "$STATE_DIR/ufw_configured" ] && [ -f /etc/ufw/ufw.conf.bak ]; then
        echo "→ Restoring UFW configuration..."
        sudo ufw --force disable
        sudo cp /etc/ufw/ufw.conf.bak /etc/ufw/ufw.conf 2>/dev/null || true
        echo "  ✅ UFW restored"
    fi
    
    # Restore Docker daemon config
    if [ -f /etc/docker/daemon.json.bak ]; then
        echo "→ Restoring Docker configuration..."
        sudo cp /etc/docker/daemon.json.bak /etc/docker/daemon.json
        sudo systemctl restart docker 2>/dev/null || true
        echo "  ✅ Docker configuration restored"
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
            echo "  → Try: ping -c 3 8.8.8.8"
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
            echo "  → Original SSH port (22) is still accessible"
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
    CURRENT_USER=$(whoami)
    if [ "$CURRENT_USER" != "$NEW_USER" ]; then
        echo "⚠️  Warning: Running as '$CURRENT_USER' but setup was configured for '$NEW_USER'"
        echo "This may cause issues with file permissions and paths."
        read -p "Continue anyway? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
            rollback "User mismatch - please run as $NEW_USER"
        fi
    fi
    
    # Check internet connectivity (multiple targets)
    echo "→ Testing internet connectivity..."
    if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null && \
       ! ping -c 1 -W 2 1.1.1.1 &> /dev/null; then
        rollback "No internet connectivity"
    fi
    echo "  ✅ Internet connection OK"
    
    # Check available disk space (minimum 3GB for safety)
    echo "→ Checking disk space..."
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 3145728 ]; then
        rollback "Insufficient disk space (need at least 3GB, have $(($AVAILABLE_SPACE/1024/1024))GB)"
    fi
    echo "  ✅ Disk space OK ($(($AVAILABLE_SPACE/1024/1024))GB available)"
    
    # Check if ports are available
    echo "→ Checking port availability..."
    if ss -tuln | grep -q ":$NEW_SSH_PORT "; then
        rollback "SSH port $NEW_SSH_PORT is already in use"
    fi
    echo "  ✅ Port $NEW_SSH_PORT is available"
    
    # Check if we can use sudo
    echo "→ Verifying sudo access..."
    if ! sudo -n true 2>/dev/null; then
        echo "  → Testing sudo with password..."
        if ! sudo true; then
            rollback "User $NEW_USER does not have sudo privileges"
        fi
    fi
    echo "  ✅ Sudo access confirmed"
    
    # Verify critical commands exist
    echo "→ Checking required commands..."
    for cmd in curl git systemctl ufw iptables; do
        if ! command -v $cmd &> /dev/null; then
            rollback "Required command not found: $cmd"
        fi
    done
    echo "  ✅ All required commands available"
    
    echo "✅ All prerequisites passed"
}

# Set trap for error handling
trap 'rollback "Unexpected error" "$LINENO"' ERR

# --- Run prerequisites check ---
check_prerequisites

# --- 1. System Update ---
if ! check_state "system_updated"; then
    echo "--- Updating system packages... ---"
    sudo apt-get update || rollback "Failed to update package list"
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || rollback "Failed to upgrade packages"
    save_state "system_updated"
    echo "$(date): System packages updated successfully" | sudo tee -a "$LOG_FILE"
else
    echo "--- System packages already updated, skipping... ---"
fi

# --- 2. Install Essential Security Tools FIRST ---
if ! check_state "security_tools_installed"; then
    echo "--- Installing security tools... ---"
    # Install UFW and Fail2Ban (iptables is already included in Ubuntu)
    # Note: We don't install iptables-persistent as it conflicts with UFW
    # iptables rules will be managed via systemd service instead
    sudo apt-get install -y ufw fail2ban iptables || rollback "Failed to install security tools"
    
    save_state "security_tools_installed"
    echo "✅ Security tools installed (UFW, Fail2Ban, iptables)"
else
    echo "--- Security tools already installed, skipping... ---"
fi



# --- 3. Configure UFW Firewall BEFORE Docker ---
if ! check_state "ufw_configured"; then
    echo "--- Configuring UFW firewall (BEFORE Docker installation)... ---"
    
    # Backup UFW config
    sudo cp /etc/ufw/ufw.conf /etc/ufw/ufw.conf.bak 2>/dev/null || true
    
    # Reset UFW to clean state
    sudo ufw --force reset || rollback "Failed to reset UFW"
    
    # Set default policies
    sudo ufw --force default deny incoming || rollback "Failed to set UFW default deny"
    sudo ufw --force default allow outgoing || rollback "Failed to set UFW default allow outgoing"
    
    # Allow current SSH port (22) first - CRITICAL for not losing connection
    sudo ufw allow 22/tcp comment "Temporary - default SSH" || rollback "Failed to allow port 22 in UFW"
    
    # Allow new SSH port
    sudo ufw allow $NEW_SSH_PORT/tcp comment "Custom SSH port" || rollback "Failed to allow SSH port in UFW"
    
    # Allow HTTP/HTTPS for Dokploy
    sudo ufw allow 80/tcp comment "HTTP" || rollback "Failed to allow port 80"
    sudo ufw allow 443/tcp comment "HTTPS" || rollback "Failed to allow port 443"
    
    # Allow Dokploy port (will be blocked after SSL setup)
    sudo ufw allow 3000/tcp comment "Dokploy (temporary)" || rollback "Failed to allow port 3000"
    
    # Enable UFW
    sudo ufw --force enable || rollback "Failed to enable UFW"
    
    save_state "ufw_configured"
    echo "✅ Firewall configured (SSH, HTTP, HTTPS, Dokploy)"
    echo "$(date): UFW firewall configured successfully" | sudo tee -a "$LOG_FILE"
else
    echo "--- UFW already configured, skipping... ---"
fi

# --- 4. Configure Secure DNS (Quad9 with DoT) ---
if ! check_state "dns_configured"; then
    echo "--- Configuring secure DNS with Quad9 (DNS over TLS)... ---"
    
    # Backup existing resolved.conf
    if [ -f /etc/systemd/resolved.conf ]; then
        sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Configure systemd-resolved with Quad9 DoT (ECS enabled for better CDN performance)
    cat <<EOF | sudo tee /etc/systemd/resolved.conf > /dev/null
[Resolve]
DNS=9.9.9.11#dns11.quad9.net 149.112.112.11#dns11.quad9.net 2620:fe::11#dns11.quad9.net 2620:fe::fe:11#dns11.quad9.net
FallbackDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net
DNSOverTLS=yes
DNSSEC=yes
Cache=yes
DNSStubListener=yes
EOF
    
    # Restart systemd-resolved
    sudo systemctl restart systemd-resolved || rollback "Failed to restart systemd-resolved"
    
    # Verify DNS is working
    if resolvectl status &>/dev/null; then
        echo "✅ DNS configured with Quad9 ECS (IPv4 + IPv6, TLS encrypted, DNSSEC, CDN optimized)"
    else
        echo "⚠️ DNS configured but verification failed (may still work)"
    fi
    
    save_state "dns_configured"
    echo "$(date): Secure DNS configured successfully" | sudo tee -a "$LOG_FILE"
else
    echo "--- DNS already configured, skipping... ---"
fi

# --- 5. Change SSH Port ---
if ! check_state "ssh_configured"; then
    echo "--- Changing the default SSH port to $NEW_SSH_PORT... ---"
    
    # Backup SSH config with timestamp
    BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/ssh/sshd_config "$BACKUP_FILE" || rollback "Failed to backup SSH config"
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak || rollback "Failed to backup SSH config"
    
    # Create sshd privilege separation directory if missing
    sudo mkdir -p /run/sshd || rollback "Failed to create /run/sshd directory"
    sudo chown root:root /run/sshd || rollback "Failed to set /run/sshd ownership"
    sudo chmod 755 /run/sshd || rollback "Failed to set /run/sshd permissions"
    
    # Update SSH port in config - more robust approach
    echo "Updating SSH configuration..."
    sudo cp /etc/ssh/sshd_config /tmp/sshd_config_test
    
    # Remove any existing Port and ListenAddress lines
    sudo sed -i '/^#*Port /d' /tmp/sshd_config_test
    sudo sed -i '/^#*ListenAddress /d' /tmp/sshd_config_test
    
    # Add new port configuration at the top
    sudo sed -i "1i Port $NEW_SSH_PORT" /tmp/sshd_config_test
    sudo sed -i "2i Port 22" /tmp/sshd_config_test
    
    # Ensure we have proper settings for security
    sudo sed -i '/^#*PermitRootLogin/d' /tmp/sshd_config_test
    sudo sed -i '/^#*PasswordAuthentication/d' /tmp/sshd_config_test
    sudo sed -i '/^#*PubkeyAuthentication/d' /tmp/sshd_config_test
    sudo sed -i '/^#*ChallengeResponseAuthentication/d' /tmp/sshd_config_test
    sudo sed -i '/^#*UsePAM/d' /tmp/sshd_config_test
    
    echo "PermitRootLogin no" | sudo tee -a /tmp/sshd_config_test > /dev/null
    echo "PubkeyAuthentication yes" | sudo tee -a /tmp/sshd_config_test > /dev/null
    echo "PasswordAuthentication no" | sudo tee -a /tmp/sshd_config_test > /dev/null
    echo "ChallengeResponseAuthentication no" | sudo tee -a /tmp/sshd_config_test > /dev/null
    echo "UsePAM yes" | sudo tee -a /tmp/sshd_config_test > /dev/null
    
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
    
    echo "✅ SSH service is running and will start on boot"
    
    # Test if SSH is responding on BOTH ports
    echo "Waiting for SSH to start on both ports..."
    sleep 5
    
    # Verify old port still works
    if ! ss -tuln | grep -q ":22 "; then
        echo "⚠️ WARNING: SSH not listening on port 22 anymore"
    else
        echo "✅ SSH still listening on port 22 (safety)"
    fi
    
    # Try multiple times to check if SSH is listening on new port
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
    
    # Test actual SSH connectivity on new port
    echo "Testing SSH connectivity on new port..."
    if timeout 5 bash -c "echo > /dev/tcp/localhost/$NEW_SSH_PORT" 2>/dev/null; then
        echo "✅ SSH is accepting connections on port $NEW_SSH_PORT"
    else
        echo "⚠️ WARNING: Could not verify SSH connectivity on new port"
        echo "Port 22 is still active as fallback"
    fi
    
    save_state "ssh_configured"
    echo "✅ SSH port has been changed to $NEW_SSH_PORT (port 22 still active as fallback)."
    echo "$(date): SSH port changed to $NEW_SSH_PORT successfully" | sudo tee -a "$LOG_FILE"
else
    echo "--- SSH already configured, skipping... ---"
fi

# --- 6. Configure Fail2Ban ---
if ! check_state "fail2ban_configured"; then
    echo "--- Configuring Fail2Ban... ---"
    cat <<EOM | sudo tee /etc/fail2ban/jail.local > /dev/null || rollback "Failed to create Fail2Ban config"
[DEFAULT]
bantime = 24h
findtime = 10m
maxretry = 5
banaction = iptables-multiport
backend = systemd

[sshd]
enabled = true
port = 22,$NEW_SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOM
    sudo systemctl restart fail2ban || rollback "Failed to restart Fail2Ban"
    sudo systemctl enable fail2ban || rollback "Failed to enable Fail2Ban"
    save_state "fail2ban_configured"
    echo "✅ Fail2Ban configured to monitor SSH ports 22 and $NEW_SSH_PORT."
    echo "$(date): Fail2Ban configured successfully" | sudo tee -a "$LOG_FILE"
else
    echo "--- Fail2Ban already configured, skipping... ---"
fi

# --- 7. Configure Automatic Security Updates ---
if ! check_state "auto_updates_configured"; then
    echo "--- Configuring automatic security updates... ---"
    sudo apt-get install -y unattended-upgrades apt-listchanges || rollback "Failed to install unattended-upgrades"
    
    # Enable automatic updates
    echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | sudo debconf-set-selections
    sudo dpkg-reconfigure -f noninteractive unattended-upgrades || rollback "Failed to configure automatic updates"
    
    # Configure unattended-upgrades for security only
    cat <<EOF | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "root";
EOF
    
    # Enable automatic updates in periodic config
    cat <<EOF | sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    # Verify service is enabled
    sudo systemctl enable unattended-upgrades || true
    sudo systemctl start unattended-upgrades || true
    
    save_state "auto_updates_configured"
    echo "✅ Automatic security updates configured and enabled"
    echo "$(date): Automatic security updates configured" | sudo tee -a "$LOG_FILE"
else
    echo "--- Automatic updates already configured, skipping... ---"
fi

# --- 8. Install and Configure Docker ---
if ! check_state "docker_installed"; then
    echo "--- Installing Docker... ---"
    
    # Install Docker prerequisites
    sudo apt-get install -y ca-certificates curl gnupg lsb-release || rollback "Failed to install Docker prerequisites"
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi
    
    # Set up Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update || rollback "Failed to update package list for Docker"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || rollback "Failed to install Docker"
    
    # Add user to docker group
    sudo usermod -aG docker $NEW_USER || rollback "Failed to add user to docker group"
    
    save_state "docker_installed"
    echo "✅ Docker installed successfully"
else
    echo "--- Docker already installed, skipping... ---"
fi

# --- 9. Configure Docker daemon ---
if ! check_state "docker_configured"; then
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
  "storage-driver": "overlay2",
  "default-address-pools": [
    {
      "base": "172.17.0.0/12",
      "size": 24
    }
  ],
  "userland-proxy": false,
  "iptables": true,
  "live-restore": true
}
EOF
    
    # Restart Docker to apply configuration
    sudo systemctl restart docker || rollback "Failed to restart Docker"
    
    # Wait for Docker to be ready
    echo "Waiting for Docker to be ready..."
    for i in {1..30}; do
        if sudo docker info &>/dev/null; then
            echo "✅ Docker is operational"
            break
        fi
        if [ $i -eq 30 ]; then
            rollback "Docker failed to start after configuration"
        fi
        sleep 1
    done
    
    save_state "docker_configured"
    echo "✅ Docker daemon configured with production settings."
else
    echo "--- Docker daemon already configured, skipping... ---"
fi

# --- 10. Install Dokploy ---
if ! check_state "dokploy_installed"; then
    echo "--- Starting Dokploy installation... ---"
    
    # Download and verify Dokploy install script
    echo "→ Downloading Dokploy installer..."
    curl -sSL https://dokploy.com/install.sh -o /tmp/dokploy_install.sh || rollback "Failed to download Dokploy installer"
    
    # Show first few lines of script for transparency
    echo "→ Dokploy installer preview (first 10 lines):"
    head -10 /tmp/dokploy_install.sh | sed 's/^/  /'
    
    echo "→ Running Dokploy installer..."
    sudo bash /tmp/dokploy_install.sh || rollback "Failed to install Dokploy"
    
    rm -f /tmp/dokploy_install.sh
    
    save_state "dokploy_installed"
    echo "$(date): Dokploy installed successfully" | sudo tee -a "$LOG_FILE"
else
    echo "--- Dokploy already installed, skipping... ---"
fi

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

# --- Save SSH port information (persistent location) ---
echo "$NEW_SSH_PORT" > "$HOME/.ssh_port"
echo "$NEW_SSH_PORT" | sudo tee /tmp/ssh_port_info.txt > /dev/null
echo "ssh $NEW_USER@<your_ip> -p $NEW_SSH_PORT" | sudo tee /tmp/ssh_connection_command.txt > /dev/null
sudo chmod 644 /tmp/ssh_port_info.txt /tmp/ssh_connection_command.txt

# --- 11. Test SSH Connection Before Removing Default User ---
echo ""
echo "=================================================================="
echo "  🔐 CRITICAL: SSH Connection Test Required"
echo "=================================================================="
echo ""
echo "Before removing the default user, you MUST test your SSH connection"
echo "with the new port to ensure you won't lose access."
echo ""
echo "In a NEW terminal window, test this connection:"
echo ""

# Detect public IP
IPV4=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || echo "")
IPV6=$(curl -6 -s --max-time 5 ifconfig.me 2>/dev/null || echo "")

if [ -n "$IPV4" ]; then
    PUBLIC_IP="$IPV4"
elif [ -n "$IPV6" ]; then
    PUBLIC_IP="$IPV6"
else
    PUBLIC_IP="<your_server_ip>"
fi

echo -e "${CYAN}ssh $NEW_USER@$PUBLIC_IP -p $NEW_SSH_PORT${NC}"
echo ""
echo "If the connection works, come back here and type 'yes' to continue."
echo "If it doesn't work, type 'no' to abort (port 22 will remain active)."
echo ""

# Interactive confirmation
read -p "Did the SSH connection test succeed? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo ""
    echo "=================================================================="
    echo "  ⚠️  Setup Paused - SSH Test Failed"
    echo "=================================================================="
    echo ""
    echo "The setup has been paused. Your system is in a safe state:"
    echo "  • SSH is accessible on BOTH port 22 and port $NEW_SSH_PORT"
    echo "  • Default user '$DEFAULT_USER' is still active"
    echo "  • All services are running"
    echo ""
    echo "To troubleshoot:"
    echo "  1. Check firewall: sudo ufw status"
    echo "  2. Check SSH: sudo systemctl status ssh"
    echo "  3. Check listening ports: ss -tuln | grep ssh"
    echo ""
    echo "Once fixed, you can:"
    echo "  • Re-run this script to continue"
    echo "  • Or manually remove default user: sudo deluser --remove-home $DEFAULT_USER"
    echo "  • And disable port 22: sudo ufw delete allow 22/tcp"
    echo ""
    echo "=================================================================="
    exit 0
fi

# --- 12. Finalize SSH Configuration ---
echo "--- Finalizing SSH configuration... ---"

# Remove port 22 from SSH config (keep only new port)
sudo sed -i '/^Port 22$/d' /etc/ssh/sshd_config
sudo systemctl restart ssh.service || rollback "Failed to restart SSH after removing port 22"

# Wait and verify
sleep 3
if ! ss -tuln | grep -q ":$NEW_SSH_PORT "; then
    rollback "SSH not listening on port $NEW_SSH_PORT after removing port 22"
fi

# Remove port 22 from UFW
sudo ufw delete allow 22/tcp
echo "✅ Port 22 disabled, only port $NEW_SSH_PORT is active"

# --- 13. Remove Default User ---
if getent passwd $DEFAULT_USER > /dev/null; then
    echo "--- Removing the default user '$DEFAULT_USER'... ---"
    
    # Create backup of user info before deletion
    getent passwd $DEFAULT_USER > /tmp/backup_user_info.txt
    
    # Kill any processes owned by the user
    sudo pkill -u $DEFAULT_USER 2>/dev/null || true
    sleep 2
    
    # Remove user and home directory
    sudo deluser --remove-home $DEFAULT_USER 2>/dev/null || {
        echo "⚠️  Warning: Could not remove default user completely"
        echo "Attempting force removal..."
        sudo userdel -r $DEFAULT_USER 2>/dev/null || true
    }
    
    if ! getent passwd $DEFAULT_USER > /dev/null; then
        echo "✅ Default user '$DEFAULT_USER' has been removed."
        echo "$(date): Default user removed successfully" | sudo tee -a "$LOG_FILE"
    else
        echo "⚠️  Warning: Default user still exists but may be disabled"
    fi
else
    echo "--- Default user '$DEFAULT_USER' already removed ---"
fi

# --- End of script ---
echo "$(date): VPS setup completed successfully" | sudo tee -a "$LOG_FILE"

# Detect both IPv4 and IPv6
IPV4=$(curl -4 -s ifconfig.me 2>/dev/null || echo "")
IPV6=$(curl -6 -s ifconfig.me 2>/dev/null || echo "")

if [ -n "$IPV4" ]; then
    PUBLIC_IP="$IPV4"
elif [ -n "$IPV6" ]; then
    PUBLIC_IP="$IPV6"
else
    PUBLIC_IP="<your_server_ip>"
fi

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


show_info_box "Important Notes" \
    "• Docker logs are rotated (max 30MB per container)" \
    "• Docker ports (3000, 80, 443) are open by default" \
    "• All changes logged to: ${GRAY}$LOG_FILE${NC}" \
    "• Original user '${GRAY}$DEFAULT_USER${NC}' has been removed" \
    "• SSH port 22 is now DISABLED (only $NEW_SSH_PORT works)" \
    "• Setup state saved in: ${GRAY}$STATE_DIR${NC}"

echo ""
echo "TROUBLESHOOTING:"
echo "   - System health: ./system_check.sh"
echo ""
echo "=================================================================="