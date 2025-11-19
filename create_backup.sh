#!/bin/bash
# Create complete system backup before modifications

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/banner.sh" ]; then
    source "$SCRIPT_DIR/banner.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

BACKUP_BASE="/var/backups/vps-hardening"
BACKUP_DIR="$BACKUP_BASE/$(date +%Y%m%d_%H%M%S)"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║                  💾  SYSTEM BACKUP CREATION  💾                  ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

log_step "Creating backup directory..."
sudo mkdir -p "$BACKUP_DIR"

log_step "Backing up SSH configuration..."
if [ -d /etc/ssh ]; then
    sudo cp -r /etc/ssh "$BACKUP_DIR/" 2>/dev/null || true
    log_success "SSH config backed up"
fi

log_step "Backing up UFW configuration..."
if [ -d /etc/ufw ]; then
    sudo cp -r /etc/ufw "$BACKUP_DIR/" 2>/dev/null || true
    log_success "UFW config backed up"
fi

log_step "Backing up Docker configuration..."
if [ -d /etc/docker ]; then
    sudo cp -r /etc/docker "$BACKUP_DIR/" 2>/dev/null || true
    log_success "Docker config backed up"
fi

log_step "Backing up iptables rules..."
if command -v iptables &> /dev/null; then
    sudo iptables-save > "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
    log_success "iptables rules backed up"
fi

log_step "Backing up system users..."
sudo cp /etc/passwd "$BACKUP_DIR/passwd.bak" 2>/dev/null || true
sudo cp /etc/group "$BACKUP_DIR/group.bak" 2>/dev/null || true
sudo cp /etc/shadow "$BACKUP_DIR/shadow.bak" 2>/dev/null || true
log_success "User database backed up"

log_step "Backing up network configuration..."
if [ -d /etc/netplan ]; then
    sudo cp -r /etc/netplan "$BACKUP_DIR/" 2>/dev/null || true
fi
if [ -f /etc/systemd/resolved.conf ]; then
    sudo cp /etc/systemd/resolved.conf "$BACKUP_DIR/" 2>/dev/null || true
fi
log_success "Network config backed up"

log_step "Creating backup manifest..."
cat > "$BACKUP_DIR/manifest.txt" << EOF
Backup created: $(date)
Hostname: $(hostname)
User: $(whoami)
Kernel: $(uname -r)
OS: $(lsb_release -d | cut -f2)

Backed up:
- SSH configuration (/etc/ssh)
- UFW configuration (/etc/ufw)
- Docker configuration (/etc/docker)
- iptables rules
- User database (/etc/passwd, /etc/group, /etc/shadow)
- Network configuration (/etc/netplan, /etc/systemd/resolved.conf)

Restore instructions:
1. Stop services: sudo systemctl stop ssh docker
2. Restore configs: sudo cp -r $BACKUP_DIR/ssh /etc/
3. Restart services: sudo systemctl start ssh docker
4. Restore iptables: sudo iptables-restore < $BACKUP_DIR/iptables.rules
EOF

sudo chmod 600 "$BACKUP_DIR"/*
sudo chown -R root:root "$BACKUP_DIR"

# Save backup location
echo "$BACKUP_DIR" > /tmp/last_backup_location.txt

echo ""
log_success "Backup completed successfully!"
echo ""
echo "Backup location: ${CYAN}$BACKUP_DIR${NC}"
echo "Manifest: ${CYAN}$BACKUP_DIR/manifest.txt${NC}"
echo ""
echo "To restore from this backup:"
echo "  ${CYAN}sudo cp -r $BACKUP_DIR/ssh /etc/${NC}"
echo "  ${CYAN}sudo systemctl restart ssh${NC}"
echo ""

# Keep only last 5 backups
log_step "Cleaning old backups (keeping last 5)..."
cd "$BACKUP_BASE"
ls -t | tail -n +6 | xargs -r sudo rm -rf
log_success "Old backups cleaned"

echo ""
