#!/bin/bash
# Post-installation cleanup script
# Run this after reconnecting with your new user

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "=============================================="
echo "  POST-INSTALLATION CLEANUP"
echo "=============================================="
echo ""

# Check we're not running as the user we want to delete
CURRENT_USER=$(whoami)

if [ "$CURRENT_USER" = "ubuntu" ]; then
    error "You are still logged in as 'ubuntu'. Please login with your new user first."
fi

# Check if ubuntu user exists
if ! id ubuntu &>/dev/null; then
    log "User 'ubuntu' doesn't exist (already removed)"
    exit 0
fi

echo "This will remove the 'ubuntu' user and its home directory."
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    warn "Cleanup cancelled"
    exit 0
fi

# Remove ubuntu user
echo "Removing user 'ubuntu'..."
sudo pkill -9 -u ubuntu 2>/dev/null || true
sleep 2

if sudo deluser --remove-home ubuntu 2>/dev/null; then
    log "User 'ubuntu' removed successfully"
elif sudo userdel -r -f ubuntu 2>/dev/null; then
    log "User 'ubuntu' removed successfully"
else
    error "Could not remove 'ubuntu' automatically. Try: sudo userdel -r -f ubuntu"
fi

# Verify
if ! id ubuntu &>/dev/null; then
    log "Verified: 'ubuntu' no longer exists"
else
    warn "User 'ubuntu' still exists - remove manually"
fi

echo ""
echo "=============================================="
echo "  CLEANUP COMPLETE"
echo "=============================================="
echo ""
