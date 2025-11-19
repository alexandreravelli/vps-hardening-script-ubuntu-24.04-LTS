#!/bin/bash
# Continuation script - Run this after reconnecting with new user

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/banner.sh" ]; then
    source "$SCRIPT_DIR/banner.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

clear
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║              🚀  VPS HARDENING - CONTINUE SETUP  🚀              ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if we're the right user
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "ubuntu" ] || [ "$CURRENT_USER" = "root" ]; then
    echo -e "${RED}❌ ERROR: You're still logged in as '$CURRENT_USER'${NC}"
    echo ""
    echo "You need to:"
    echo "  1. Disconnect from this session: ${CYAN}exit${NC}"
    echo "  2. Reconnect with your new user"
    echo "  3. Run this script again"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Logged in as: ${CYAN}$CURRENT_USER${NC}"
echo ""

# Check if scripts are present
if [ ! -f "./main_setup.sh" ]; then
    echo -e "${RED}❌ ERROR: main_setup.sh not found!${NC}"
    echo ""
    echo "Scripts not found in current directory."
    echo "Try:"
    echo "  ${CYAN}cd ~/vps-hardening*${NC}"
    echo "  ${CYAN}./continue_setup.sh${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Scripts found in current directory"
echo ""

# Show what will be done
echo "This script will:"
echo "  1. Create a complete system backup"
echo "  2. Run the main setup (SSH, Firewall, Docker, Dokploy)"
echo "  3. Configure all security features"
echo "  4. Remove the default ubuntu user"
echo ""
echo "Estimated time: ~15 minutes"
echo ""

read -p "Ready to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Setup cancelled. You can run this script again anytime."
    echo ""
    echo "Or use the menu: ${CYAN}./menu.sh${NC}"
    exit 0
fi

# Create backup first
if [ -f "./create_backup.sh" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Creating system backup before modifications..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    ./create_backup.sh
    echo ""
    read -p "Press Enter to continue with setup..."
fi

# Run main setup
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Starting main setup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

./main_setup.sh

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║                    ✅  SETUP COMPLETE!  ✅                       ║"
║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Access Dokploy: ${CYAN}http://$(curl -s ifconfig.me):3000${NC}"
echo "  2. Configure your domain and SSL"
echo "  3. Run: ${CYAN}./post_ssl_setup.sh${NC}"
echo ""
