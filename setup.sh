#!/bin/bash
# VPS Hardening Script - Simple & Reliable
# Ubuntu 24.04 LTS + Dokploy
# Usage: curl -sSL https://raw.githubusercontent.com/.../setup.sh | bash

set -e

# === CONFIGURATION ===
CURRENT_USER=$(whoami)
SSH_PORT=$((RANDOM % 10000 + 50000))
LOG_FILE="/var/log/vps_setup.log"
CONFIG_FILE="/root/.vps_hardening_config"

# Save SSH port for recovery
echo "SSH_PORT=$SSH_PORT" | sudo tee $CONFIG_FILE > /dev/null
sudo chmod 600 $CONFIG_FILE

# === COLORS (minimal) ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# === FUNCTIONS ===
log() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo ""; echo "=== $1 ==="; echo ""; }

# === PRE-CHECKS ===
step "Pre-flight checks"

# Must have sudo
if ! sudo -v; then
    error "This script requires sudo privileges"
fi

# Must be Ubuntu 24.04
if ! grep -q "Ubuntu 24" /etc/os-release 2>/dev/null; then
    warn "This script is designed for Ubuntu 24.04 LTS"
fi

# Internet connectivity
if ! ping -c 1 8.8.8.8 &>/dev/null; then
    error "No internet connection"
fi
log "Internet OK"

# === STEP 1: CREATE USER ===
step "Step 1/8: Create secure user"

echo "Choose a username for your admin account:"
read -p "Username: " NEW_USER

# Validate username
if [ -z "$NEW_USER" ]; then
    error "Username cannot be empty"
fi

if id "$NEW_USER" &>/dev/null; then
    error "User '$NEW_USER' already exists"
fi

# Create user
sudo adduser --gecos "" --disabled-password "$NEW_USER"
log "User '$NEW_USER' created"

# Set password
echo "Set password for $NEW_USER (min 12 chars, mixed case, numbers, symbols):"
while true; do
    read -s -p "Password: " PASS1; echo
    read -s -p "Confirm: " PASS2; echo
    
    if [ -z "$PASS1" ]; then
        warn "Password cannot be empty"
        continue
    fi
    
    # Basic validation (12+ chars)
    if [ ${#PASS1} -lt 12 ]; then
        warn "Password must be at least 12 characters"
        continue
    fi
    
    if [ "$PASS1" != "$PASS2" ]; then
        warn "Passwords don't match"
        continue
    fi
    
    echo "$NEW_USER:$PASS1" | sudo chpasswd && break
done
log "Password set"

# Add to sudo group
sudo usermod -aG sudo "$NEW_USER"
log "Sudo access granted"

# === STEP 2: SSH KEY ===
step "Step 2/8: Configure SSH key"

echo "Paste your SSH public key (ssh-ed25519 or ssh-rsa):"
read -r SSH_KEY

if [ -z "$SSH_KEY" ]; then
    error "SSH key cannot be empty"
fi

# Validate SSH key format
if ! echo "$SSH_KEY" | grep -qE "^(ssh-rsa|ssh-ed25519|ecdsa)"; then
    error "Invalid SSH key format"
fi

# Setup SSH directory
sudo mkdir -p /home/$NEW_USER/.ssh
echo "$SSH_KEY" | sudo tee /home/$NEW_USER/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/$NEW_USER/.ssh
sudo chmod 600 /home/$NEW_USER/.ssh/authorized_keys
sudo chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
log "SSH key configured"

# === STEP 3: SYSTEM UPDATE ===
step "Step 3/8: Update system"

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
log "System updated"

# Configure timezone (UTC for servers)
sudo timedatectl set-timezone UTC
log "Timezone set to UTC"

# Configure swap if not present (2GB)
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile > /dev/null
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    # Optimize swap usage
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
        sudo sysctl -p > /dev/null
    fi
    log "Swap configured (2GB, swappiness=10)"
else
    log "Swap already exists"
fi

# === STEP 4: INSTALL SECURITY TOOLS ===
step "Step 4/8: Install security tools"

sudo apt-get install -y -qq ufw fail2ban unattended-upgrades libpam-pwquality auditd
log "UFW, Fail2Ban, unattended-upgrades, pwquality and auditd installed"

# Configure strong password policy
sudo tee /etc/security/pwquality.conf > /dev/null << EOF
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
reject_username
enforce_for_root
EOF
log "Strong password policy configured (min 12 chars, mixed case, numbers, symbols)"

# Configure audit logging
sudo tee /etc/audit/rules.d/hardening.rules > /dev/null << EOF
# Log all sudo commands
-a always,exit -F arch=b64 -S execve -F euid=0 -k sudo_commands
# Log authentication events
-w /var/log/auth.log -p wa -k auth_log
# Log SSH config changes
-w /etc/ssh/sshd_config -p wa -k sshd_config
# Log user/group changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes
# Log network config changes
-w /etc/hosts -p wa -k hosts_changes
-w /etc/network -p wa -k network_changes
EOF
sudo systemctl restart auditd
log "Audit logging configured (sudo, auth, SSH, user changes)"

# Configure automatic security updates
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
log "Automatic security updates enabled"

# Verify AppArmor is active (enabled by default on Ubuntu 24.04)
if sudo aa-status &>/dev/null; then
    PROFILES=$(sudo aa-status 2>/dev/null | grep "profiles are loaded" | awk '{print $1}')
    log "AppArmor active ($PROFILES profiles loaded)"
else
    warn "AppArmor not running - installing..."
    sudo apt-get install -y -qq apparmor apparmor-utils
    sudo systemctl enable apparmor
    sudo systemctl start apparmor
    log "AppArmor installed and enabled"
fi

# Configure Fail2Ban for custom SSH port
sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[sshd]
enabled = true
port = 22,$SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
sudo systemctl restart fail2ban
log "Fail2Ban configured for ports 22 and $SSH_PORT"

# === STEP 5: CONFIGURE FIREWALL ===
step "Step 5/8: Configure firewall"

sudo ufw --force reset > /dev/null
sudo ufw default deny incoming > /dev/null
sudo ufw default allow outgoing > /dev/null
sudo ufw allow 22/tcp > /dev/null      # Keep port 22 for now (no rate limit during setup)
sudo ufw allow $SSH_PORT/tcp > /dev/null  # No rate limit during setup
sudo ufw allow 80/tcp > /dev/null
sudo ufw allow 443/tcp > /dev/null
sudo ufw allow 3000/tcp > /dev/null    # Dokploy
sudo ufw --force enable > /dev/null
log "Firewall configured (ports: 22, $SSH_PORT, 80, 443, 3000)"

# === STEP 6: CONFIGURE SSH ===
step "Step 6/8: Configure SSH"

# Backup
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Configure SSH - KEEP PASSWORD AUTH FOR NOW (will disable after test)
sudo tee /etc/ssh/sshd_config.d/hardening.conf > /dev/null << EOF
Port 22
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
EOF

# Restart SSH
sudo systemctl restart ssh
log "SSH configured (ports: 22 and $SSH_PORT, password auth still enabled)"

# === STEP 7: INSTALL DOCKER ===
step "Step 7/8: Install Docker"

# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $NEW_USER
log "Docker installed"

# Configure Docker
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"}
}
EOF
sudo systemctl restart docker
log "Docker configured"

# === STEP 8: INSTALL DOKPLOY ===
step "Step 8/8: Install Dokploy"

curl -sSL https://dokploy.com/install.sh | sudo sh
log "Dokploy installed"

# Wait for Dokploy
echo "Waiting for Dokploy to start..."
for i in {1..30}; do
    if curl -s http://localhost:3000 &>/dev/null; then
        log "Dokploy is running"
        break
    fi
    sleep 2
done

# === TEST SSH CONNECTION ===
step "CRITICAL: Test SSH connection"

PUBLIC_IP=$(curl -s ifconfig.me)

echo ""
echo "=============================================="
echo "  BEFORE CONTINUING, TEST YOUR SSH CONNECTION"
echo "=============================================="
echo ""
echo "Open a NEW terminal and run:"
echo ""
echo "  ssh $NEW_USER@$PUBLIC_IP -p $SSH_PORT"
echo ""
echo "If it works, come back here and type 'yes'"
echo "If it fails, type 'no' (port 22 will stay open)"
echo ""

read -p "Did SSH work? (yes/no): " SSH_TEST

if [ "$SSH_TEST" != "yes" ]; then
    warn "SSH test failed - keeping port 22 and password auth open"
    warn "Fix the issue, then run:"
    warn "  sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/hardening.conf"
    warn "  sudo sed -i '/^Port 22$/d' /etc/ssh/sshd_config.d/hardening.conf"
    warn "  sudo systemctl restart ssh"
    warn "  sudo ufw delete allow 22/tcp"
else
    # Close port 22 AND disable password auth
    sudo tee /etc/ssh/sshd_config.d/hardening.conf > /dev/null << EOF
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
EOF
    sudo systemctl restart ssh
    sudo ufw delete allow 22/tcp
    
    # Update Fail2Ban for final port only
    sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
    sudo systemctl restart fail2ban
    
    # Apply rate limiting now that SSH is confirmed working
    sudo ufw delete allow $SSH_PORT/tcp > /dev/null
    sudo ufw limit $SSH_PORT/tcp > /dev/null
    
    log "Security hardened: Port 22 closed, password auth disabled, rate limiting enabled"
fi

# === STEP 9: REMOVE OLD USER ===
step "Step 9/9: Remove old user"

# The old user is the one we started with (detected at the beginning)
OLD_USER="$CURRENT_USER"

# Don't remove if it's the same as the new user
if [ "$OLD_USER" = "$NEW_USER" ]; then
    log "Old user and new user are the same - nothing to remove"
elif [ "$OLD_USER" = "root" ]; then
    log "Running as root - no user to remove"
elif ! id "$OLD_USER" &>/dev/null; then
    log "User '$OLD_USER' doesn't exist (already removed)"
else
    echo ""
    echo "You are currently logged in as '$OLD_USER'."
    echo "For security, this user should be removed after setup."
    echo ""
    echo "WARNING: Make sure you can login with '$NEW_USER' before removing!"
    echo ""
    
    # Check if we're running as the user we want to delete (dangerous!)
    if [ "$OLD_USER" = "$(whoami)" ]; then
        warn "Cannot auto-remove '$OLD_USER' - you're currently logged in as this user!"
        echo ""
        echo "To remove this user safely:"
        echo "  1. Disconnect from this session"
        echo "  2. Login as '$NEW_USER': ssh $NEW_USER@\$(curl -s ifconfig.me) -p $SSH_PORT"
        echo "  3. Run: sudo deluser --remove-home $OLD_USER"
        echo ""
    else
        read -p "Remove user '$OLD_USER'? (yes/no): " REMOVE_USER
        
        if [ "$REMOVE_USER" = "yes" ]; then
            echo "Removing user '$OLD_USER'..."
            
            # Kill all processes for that user
            sudo pkill -9 -u $OLD_USER 2>/dev/null || true
            sleep 2
            
            # Remove user
            if sudo deluser --remove-home $OLD_USER 2>/dev/null; then
                log "User '$OLD_USER' removed with deluser"
            elif sudo userdel -r -f $OLD_USER 2>/dev/null; then
                log "User '$OLD_USER' removed with userdel"
            else
                warn "Could not remove '$OLD_USER' automatically"
                echo "Try manually: sudo userdel -r -f $OLD_USER"
            fi
            
            # Verify
            if ! id "$OLD_USER" &>/dev/null; then
                log "Verified: '$OLD_USER' no longer exists"
            else
                warn "User '$OLD_USER' still exists - remove manually"
            fi
        else
            warn "User '$OLD_USER' NOT removed"
            echo "You can remove it later with: sudo deluser --remove-home $OLD_USER"
        fi
    fi
fi

# === DONE ===
step "Setup Complete!"

echo ""
echo "=============================================="
echo "  YOUR SERVER IS READY"
echo "=============================================="
echo ""
echo "SSH:     ssh $NEW_USER@$PUBLIC_IP -p $SSH_PORT"
echo "Dokploy: http://$PUBLIC_IP:3000"
echo ""
echo "IMPORTANT: SSH port saved in $CONFIG_FILE"
echo ""
echo "Next steps:"
echo "  1. Access Dokploy and create admin account"
echo "  2. Configure your domain + SSL"
echo "  3. After SSL, block port 3000:"
echo "     sudo iptables -I DOCKER-USER -p tcp --dport 3000 -j DROP"
echo "     sudo iptables -I DOCKER-USER -i lo -p tcp --dport 3000 -j ACCEPT"
echo ""
echo "=============================================="
