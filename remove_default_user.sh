#!/bin/bash
# Script to safely remove the default ubuntu user
# Can be run standalone or called from menu

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/banner.sh" ]; then
    source "$SCRIPT_DIR/banner.sh"
else
    # Fallback colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

DEFAULT_USER="${1:-ubuntu}"
LOG_FILE="/var/log/user_removal.log"

clear
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║              🗑️  REMOVE DEFAULT USER: $DEFAULT_USER              ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Security check: don't run as the user being deleted
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "$DEFAULT_USER" ]; then
    echo -e "${RED}❌ ERROR: Cannot remove the user you're currently logged in as!${NC}"
    echo ""
    echo "Please:"
    echo "  1. Logout from this session"
    echo "  2. Login with a different user"
    echo "  3. Run this script again"
    exit 1
fi

# Check if user exists
echo "→ Checking if user '$DEFAULT_USER' exists..."
if ! getent passwd "$DEFAULT_USER" > /dev/null; then
    echo -e "${GREEN}✅ User '$DEFAULT_USER' doesn't exist (already removed)${NC}"
    echo ""
    read -p "Press Enter to continue..."
    exit 0
fi

echo -e "${YELLOW}⚠️  User '$DEFAULT_USER' found${NC}"
echo ""

# Show user info
echo "User information:"
getent passwd "$DEFAULT_USER" | sed 's/^/  /'
echo ""

# Check for running processes
PROCESS_COUNT=$(ps -u "$DEFAULT_USER" 2>/dev/null | wc -l)
if [ "$PROCESS_COUNT" -gt 1 ]; then
    echo -e "${YELLOW}⚠️  User has $((PROCESS_COUNT - 1)) running process(es)${NC}"
    echo ""
    echo "Running processes:"
    ps -u "$DEFAULT_USER" -o pid,cmd | sed 's/^/  /'
    echo ""
fi

# Confirmation
echo -e "${RED}⚠️  WARNING: This will permanently delete:${NC}"
echo "  • User account: $DEFAULT_USER"
echo "  • Home directory: /home/$DEFAULT_USER"
echo "  • All files owned by this user"
echo "  • Mail spool"
echo ""
echo -e "${YELLOW}This action CANNOT be undone!${NC}"
echo ""

read -p "Are you sure you want to remove user '$DEFAULT_USER'? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Create log file
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"

echo "$(date): Starting removal of user '$DEFAULT_USER'" | sudo tee -a "$LOG_FILE"

# Step 1: Kill all processes
echo "→ Terminating all processes for user '$DEFAULT_USER'..."
if sudo pkill -u "$DEFAULT_USER" 2>/dev/null; then
    echo "  ✓ Sent SIGTERM to processes"
    sleep 2
else
    echo "  ℹ No processes to terminate"
fi

# Force kill if still running
if pgrep -u "$DEFAULT_USER" > /dev/null; then
    echo "→ Force killing remaining processes..."
    sudo pkill -9 -u "$DEFAULT_USER" 2>/dev/null || true
    sleep 2
fi

# Verify all processes are dead
if pgrep -u "$DEFAULT_USER" > /dev/null; then
    echo -e "${RED}⚠️  Some processes still running:${NC}"
    ps -u "$DEFAULT_USER" -o pid,cmd | sed 's/^/  /'
    echo ""
    read -p "Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} All processes terminated"
fi

# Step 2: Remove user
echo ""
echo "→ Removing user account and home directory..."

# Try deluser first (Debian/Ubuntu preferred method)
if command -v deluser &> /dev/null; then
    echo "  Using 'deluser' command..."
    if sudo deluser --remove-home "$DEFAULT_USER" 2>&1 | sudo tee -a "$LOG_FILE"; then
        echo -e "${GREEN}✅ User removed successfully with deluser${NC}"
        REMOVAL_SUCCESS=true
    else
        echo -e "${YELLOW}⚠️  deluser failed, trying userdel...${NC}"
        REMOVAL_SUCCESS=false
    fi
else
    REMOVAL_SUCCESS=false
fi

# Fallback to userdel
if [ "$REMOVAL_SUCCESS" != "true" ]; then
    echo "  Using 'userdel' command..."
    if sudo userdel -r -f "$DEFAULT_USER" 2>&1 | sudo tee -a "$LOG_FILE"; then
        echo -e "${GREEN}✅ User removed successfully with userdel${NC}"
        REMOVAL_SUCCESS=true
    else
        echo -e "${RED}❌ userdel also failed${NC}"
        REMOVAL_SUCCESS=false
    fi
fi

# Step 3: Verify removal
echo ""
echo "→ Verifying removal..."

if ! getent passwd "$DEFAULT_USER" > /dev/null; then
    echo -e "${GREEN}✅ User '$DEFAULT_USER' successfully removed from system${NC}"
else
    echo -e "${RED}❌ User '$DEFAULT_USER' still exists in /etc/passwd${NC}"
    REMOVAL_SUCCESS=false
fi

if [ ! -d "/home/$DEFAULT_USER" ]; then
    echo -e "${GREEN}✅ Home directory removed${NC}"
else
    echo -e "${YELLOW}⚠️  Home directory still exists: /home/$DEFAULT_USER${NC}"
    echo "  You can remove it manually with: sudo rm -rf /home/$DEFAULT_USER"
fi

# Step 4: Clean up related files
echo ""
echo "→ Cleaning up related files..."

# Remove from groups
if grep -q "^.*:.*:.*:.*$DEFAULT_USER" /etc/group; then
    echo "  Removing from groups..."
    sudo sed -i "s/[:,]$DEFAULT_USER//g" /etc/group
    echo -e "${GREEN}✓${NC} Removed from groups"
fi

# Remove mail spool if exists
if [ -f "/var/mail/$DEFAULT_USER" ]; then
    sudo rm -f "/var/mail/$DEFAULT_USER"
    echo -e "${GREEN}✓${NC} Removed mail spool"
fi

# Remove cron jobs if exist
if [ -f "/var/spool/cron/crontabs/$DEFAULT_USER" ]; then
    sudo rm -f "/var/spool/cron/crontabs/$DEFAULT_USER"
    echo -e "${GREEN}✓${NC} Removed cron jobs"
fi

echo ""
echo "$(date): User removal completed" | sudo tee -a "$LOG_FILE"

# Final summary
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
if [ "$REMOVAL_SUCCESS" = "true" ]; then
    echo "║                    ✅  REMOVAL SUCCESSFUL  ✅                     ║"
else
    echo "║                    ⚠️   REMOVAL INCOMPLETE  ⚠️                   ║"
fi
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$REMOVAL_SUCCESS" = "true" ]; then
    echo "User '$DEFAULT_USER' has been completely removed from the system."
    echo ""
    echo "✓ User account deleted"
    echo "✓ Home directory removed"
    echo "✓ All processes terminated"
    echo "✓ Related files cleaned up"
else
    echo "User removal encountered issues. Please check:"
    echo "  • Log file: $LOG_FILE"
    echo "  • User status: getent passwd $DEFAULT_USER"
    echo "  • Home directory: ls -la /home/$DEFAULT_USER"
    echo ""
    echo "You may need to manually clean up remaining files."
fi

echo ""
echo "Log file: $LOG_FILE"
echo ""

read -p "Press Enter to continue..."
