#!/bin/bash
# One-Command Installation Script for Dokploy VPS Setup
# Usage: curl -sSL https://raw.githubusercontent.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS/main/install.sh | bash

set -e

# Configuration
REPO_URL="${REPO_URL:-https://github.com/alexandreravelli/vps-hardening-script-ubuntu-24.04-LTS.git}"
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

# Check if running with sudo privileges (accept any user with sudo)
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "root" ]; then
    if ! sudo -n true 2>/dev/null && ! sudo -v 2>/dev/null; then
        echo -e "${RED}❌ Error: This script requires sudo privileges${NC}"
        echo "Current user: $CURRENT_USER"
        echo ""
        echo "Please run as a user with sudo access (ubuntu, root, or any sudo user)"
        exit 1
    fi
fi

if [ "$CURRENT_USER" != "$DEFAULT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
    echo -e "${YELLOW}⚠️  Running as '$CURRENT_USER'${NC}"
    echo "Continuing with sudo privileges..."
    echo ""
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

# Detect both IPv4 and IPv6 with validation
IPV4=$(curl -4 -s --max-time 5 --retry 2 ifconfig.me 2>/dev/null || echo "")
IPV6=$(curl -6 -s --max-time 5 --retry 2 ifconfig.me 2>/dev/null || echo "")

# Validate IPv4 format
if [ -n "$IPV4" ]; then
    if [[ "$IPV4" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Public IPv4: $IPV4"
    else
        echo "Public IPv4: Unable to detect (invalid format)"
        IPV4=""
    fi
fi

# Validate IPv6 format (basic check)
if [ -n "$IPV6" ]; then
    if [[ "$IPV6" =~ ^[0-9a-fA-F:]+$ ]]; then
        echo "Public IPv6: $IPV6"
    else
        echo "Public IPv6: Unable to detect (invalid format)"
        IPV6=""
    fi
fi

if [ -z "$IPV4" ] && [ -z "$IPV6" ]; then
    echo "Public IP: Unable to detect"
fi

echo ""

# Ask for confirmation
echo "=================================================================="
echo "  ⚠️  IMPORTANT INFORMATION"
echo "=================================================================="
echo ""
echo "This installation will:"
echo "  1. Create a new secure user"
echo "     → You MUST choose a unique username (no default)"
echo "     → Provide your SSH public key"
echo "  2. Change SSH port to a random port (50000-59999)"
echo "  3. Configure firewall (UFW)"
echo "  4. Install Docker and Dokploy"
echo "  5. Remove the current default user (if exists)"
echo ""
echo -e "${YELLOW}⚠️  You will need to reconnect with the new user after step 1${NC}"
echo ""

# Robust input reading
CONFIRM=""

if [ -t 0 ]; then
    # Standard interactive shell
    read -p "Do you want to continue? (yes/no): " -r CONFIRM
elif [ -c /dev/tty ]; then
    # Piped input (curl | bash), try explicit TTY
    # Disable set -e temporarily as read might return non-zero on some systems
    set +e
    read -p "Do you want to continue? (yes/no): " -r CONFIRM < /dev/tty
    set -e
else
    # No TTY available (headless/CI)
    echo "⚠️  No interactive terminal detected."
    echo "Assuming 'yes' to proceed..."
    CONFIRM="yes"
fi

if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Step 1: Create user
echo "=================================================================="
echo "  Step 1/2: Creating secure user"
echo "=================================================================="
echo ""

# Run create_user.sh with explicit TTY input
if [ -c /dev/tty ]; then
    ./create_user.sh < /dev/tty
else
    ./create_user.sh
fi

# Read the created username
if [ -f /tmp/new_user_name.txt ]; then
    CREATED_USER=$(cat /tmp/new_user_name.txt)
else
    CREATED_USER="prod-dokploy"
fi

# Note: Scripts are already copied by create_user.sh
# Just verify and display the path
if [ -f /tmp/vps_setup_dirname.txt ]; then
    DIRNAME=$(cat /tmp/vps_setup_dirname.txt)
    echo ""
    echo "✅ Scripts are ready in: /home/$CREATED_USER/$DIRNAME"
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
if [ -n "$IPV4" ]; then
    echo "   ssh $CREATED_USER@$IPV4"
elif [ -n "$IPV6" ]; then
    echo "   ssh $CREATED_USER@$IPV6"
else
    echo "   ssh $CREATED_USER@<your_server_ip>"
fi
echo ""
echo "3. Navigate to the installation directory:"
DIRNAME=$(basename "$INSTALL_DIR")
echo "   cd ~/$DIRNAME"
echo ""
echo "4. Continue the setup:"
echo "   ${CYAN}./continue_setup.sh${NC}"
echo ""
echo "   This will automatically:"
echo "   • Create a system backup"
echo "   • Run the complete setup"
echo "   • Configure everything"
echo ""
echo "   OR use the interactive menu:"
echo "   ./menu.sh"
echo ""
echo "=================================================================="
echo ""
echo -e "${GREEN}💡 TIP: Use continue_setup.sh for a seamless experience!${NC}"
echo ""
