#!/bin/bash
# One-Command Installation Script for Dokploy VPS Setup
# Usage: curl -sSL https://raw.githubusercontent.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/main/install.sh | bash

set -e

# Configuration
REPO_URL="${REPO_URL:-git@github.com:alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git}"
INSTALL_DIR="$HOME/vps-hardening"
DEFAULT_USER="ubuntu"

# Load banner functions if available, otherwise use simple output
if [ -f "banner.sh" ]; then
    source banner.sh
    show_install_banner
else
    # Colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                              ║"
    echo "║                    🚀 VPS HARDENING - ONE-COMMAND INSTALLER 🚀               ║"
    echo "║                                                                              ║"
    echo "║                    Ubuntu 24.04 LTS Security Hardening                      ║"
    echo "║                         with Dokploy Deployment                             ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
fi

# Check if running as default user
if [ "$(whoami)" != "$DEFAULT_USER" ]; then
    echo -e "${RED}❌ Error: This script must be run as user '$DEFAULT_USER'${NC}"
    echo "Current user: $(whoami)"
    exit 1
fi

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check git
if ! command -v git &> /dev/null; then
    echo "→ Installing git..."
    sudo apt-get update -qq
    sudo apt-get install -y git
fi

# Check curl
if ! command -v curl &> /dev/null; then
    echo "→ Installing curl..."
    sudo apt-get install -y curl
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"
echo ""

# Clone repository
echo "📦 Downloading setup scripts..."
if [ -d "$INSTALL_DIR" ]; then
    echo "→ Removing existing installation directory..."
    rm -rf "$INSTALL_DIR"
fi

git clone "$REPO_URL" "$INSTALL_DIR" 2>&1 | grep -v "Cloning into" || true
cd "$INSTALL_DIR"

echo -e "${GREEN}✅ Scripts downloaded${NC}"
echo ""

# Make scripts executable
chmod +x *.sh

# Display configuration
echo "=================================================================="
echo "  📋 Installation Configuration"
echo "=================================================================="
echo ""
echo "Installation directory: $INSTALL_DIR"
echo "Current user: $(whoami)"
echo "Public IP: $(curl -s ifconfig.me 2>/dev/null || echo 'Unable to detect')"
echo ""

# Ask for confirmation
echo "=================================================================="
echo "  ⚠️  IMPORTANT INFORMATION"
echo "=================================================================="
echo ""
echo "This installation will:"
echo "  1. Create a new secure user (you will choose the username)"
echo "  2. Configure SSH access with your public key"
echo "  3. Change SSH port to a random port (50000-59999)"
echo "  4. Configure firewall (UFW)"
echo "  5. Install Docker and Dokploy"
echo "  6. Remove the default 'ubuntu' user"
echo ""
echo -e "${YELLOW}⚠️  You will need to reconnect with the new user after step 1${NC}"
echo ""

read -p "Do you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Step 1: Create user
echo "=================================================================="
echo "  Step 1/2: Creating secure user"
echo "=================================================================="
echo ""

./create_user.sh

# Read the created username
if [ -f /tmp/new_user_name.txt ]; then
    CREATED_USER=$(cat /tmp/new_user_name.txt)
else
    CREATED_USER="prod-dokploy"
fi

echo ""
echo "=================================================================="
echo "  ✅ User created successfully!"
echo "=================================================================="
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Disconnect from this session:"
echo "   exit"
echo ""
echo "2. Reconnect with the new user:"
echo "   ssh $CREATED_USER@$(curl -s ifconfig.me 2>/dev/null)"
echo ""
echo "3. Navigate to the installation directory:"
echo "   cd $INSTALL_DIR"
echo ""
echo "4. Run the main setup:"
echo "   ./main_setup.sh"
echo ""
echo "=================================================================="
echo ""
echo "💡 TIP: Save your SSH connection command for later!"
echo ""
