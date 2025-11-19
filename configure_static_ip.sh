#!/bin/bash
# SCRIPT: Configure Static IP (Safe Mode with Netplan)
# Uses 'netplan try' to prevent lockout

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/banner.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check for root
check_root

clear
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║                 🌐  STATIC IP CONFIGURATION  🌐                  ║"
echo "║                                                                   ║
echo "║           Safe configuration using 'netplan try'                  ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}⚠️  IMPORTANT SAFETY INFORMATION${NC}"
echo "This script uses 'netplan try'. If you lose connection after applying settings,"
echo "the changes will automatically revert after 120 seconds."
echo "DO NOT panic if the terminal freezes. Just wait."
echo ""

# 1. Detect Active Interface
echo "🔍 Detecting network interface..."
# Get the interface with the default route
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [ -z "$DEFAULT_IFACE" ]; then
    echo -e "${RED}❌ Could not detect default interface.${NC}"
    echo "Available interfaces:"
    ip link show
    read -p "Please enter interface name manually: " DEFAULT_IFACE
else
    echo -e "✅ Detected interface: ${GREEN}$DEFAULT_IFACE${NC}"
fi

# Get current IP details for suggestion
CURRENT_IP=$(ip -4 addr show "$DEFAULT_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -n1)
CURRENT_GW=$(ip route | grep default | awk '{print $3}' | head -n1)

echo ""
echo "Current Configuration:"
echo "  IP: $CURRENT_IP"
echo "  Gateway: $CURRENT_GW"
echo ""

# 2. Collect New Configuration
echo "------------------------------------------------------------------"
echo "Please enter new configuration:"
echo "------------------------------------------------------------------"

# IPv4
while true; do
    read -p "IPv4 Address with CIDR (e.g., 192.168.1.100/24): " NEW_IP
    if [[ "$NEW_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}Invalid format. Example: 192.168.1.50/24${NC}"
    fi
done

# Gateway
while true; do
    read -p "Gateway IPv4 (e.g., 192.168.1.1): " NEW_GW
    if [[ "$NEW_GW" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}Invalid format. Example: 192.168.1.1${NC}"
    fi
done

# IPv6 (Optional)
read -p "IPv6 Address (Optional, press Enter to skip): " NEW_IPV6
if [ -n "$NEW_IPV6" ]; then
    read -p "Gateway IPv6 (Optional): " NEW_GW6
fi

echo ""
echo -e "${CYAN}Proposed Configuration:${NC}"
echo "  Interface: $DEFAULT_IFACE"
echo "  IPv4:      $NEW_IP"
echo "  Gateway:   $NEW_GW"
if [ -n "$NEW_IPV6" ]; then
    echo "  IPv6:      $NEW_IPV6"
    echo "  Gateway6:  $NEW_GW6"
fi
echo "  DNS:       9.9.9.11, 149.112.112.11 (Quad9 Enforced)"
echo ""

read -p "Create configuration and apply? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Aborted."
    exit 0
fi

# 3. Generate Netplan Config
CONFIG_FILE="/etc/netplan/60-static-ip.yaml"

echo "→ Generating Netplan configuration..."

# Create backup of existing netplan files
mkdir -p /etc/netplan/backup
cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null || true

# Build YAML content
cat <<EOF > "$CONFIG_FILE"
network:
  version: 2
  ethernets:
    $DEFAULT_IFACE:
      dhcp4: false
      dhcp6: false
      addresses:
        - $NEW_IP
EOF

if [ -n "$NEW_IPV6" ]; then
    cat <<EOF >> "$CONFIG_FILE"
        - $NEW_IPV6
EOF
fi

cat <<EOF >> "$CONFIG_FILE"
      routes:
        - to: default
          via: $NEW_GW
EOF

if [ -n "$NEW_GW6" ]; then
    cat <<EOF >> "$CONFIG_FILE"
        - to: default
          via: "$NEW_GW6"
EOF
fi

cat <<EOF >> "$CONFIG_FILE"
      nameservers:
        addresses:
          - 9.9.9.11
          - 149.112.112.11
          - 2620:fe::11
          - 2620:fe::fe:11
EOF

chmod 600 "$CONFIG_FILE"
echo "✅ Configuration written to $CONFIG_FILE"

# Validate netplan configuration syntax
echo "→ Validating netplan configuration..."
if ! netplan generate 2>/dev/null; then
    echo -e "${RED}❌ Invalid netplan configuration syntax${NC}"
    echo "Configuration file: $CONFIG_FILE"
    echo ""
    echo "Errors:"
    netplan generate 2>&1 | sed 's/^/  /'
    echo ""
    rm -f "$CONFIG_FILE"
    exit 1
fi
echo "✅ Configuration syntax is valid"

# 4. Apply with Safety Net
echo ""
echo "=================================================================="
echo -e "${YELLOW}APPLYING CHANGES WITH 'NETPLAN TRY'${NC}"
echo "=================================================================="
echo "1. The system will attempt to apply the new IP."
echo "2. You will have 120 seconds to confirm if you can still see this screen."
echo "3. If you get disconnected, JUST WAIT. It will revert automatically."
echo ""
read -p "Press Enter to start..."

netplan try --timeout 120

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Configuration applied successfully!${NC}"
    echo "Please update your SSH connection info if your IP changed."
else
    echo ""
    echo -e "${RED}❌ Configuration failed or timed out. Reverted to previous state.${NC}"
    rm -f "$CONFIG_FILE"
    echo "Removed temporary config file."
fi
