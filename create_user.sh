#!/bin/bash
# SCRIPT 1: Secure User Creation

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/banner.sh"

DEFAULT_USER="ubuntu"

if [ "$(whoami)" != "$DEFAULT_USER" ]; then
  echo "ERROR: This script must be run by the user '$DEFAULT_USER'."
  exit 1
fi

# Show banner
show_user_banner

show_section "User Configuration"

# Ask for the new username
echo -e "${CYAN}Enter the name for the new user${NC}"
echo -e "${GRAY}(Press Enter for default: prod-dokploy)${NC}"
echo -n "Username: "
read NEW_USER
NEW_USER=${NEW_USER:-prod-dokploy}

echo ""
show_section "Creating User: $NEW_USER"
sudo adduser $NEW_USER

echo ""
show_section "Granting Sudo Privileges"
sudo usermod -aG sudo $NEW_USER
echo -e "${GREEN}✅ Sudo privileges granted${NC}"

echo ""
show_section "SSH Key Configuration"
echo ""
echo "Please paste your SSH public key below:"
echo "(This is the content of your id_rsa.pub or id_ed25519.pub file)"
echo ""
echo "Example: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host"
echo ""
echo -n "SSH Public Key: "

# Read the public key from user input
read -r SSH_KEY

if [ -z "$SSH_KEY" ]; then
    echo ""
    echo "❌ ERROR: No SSH key provided!"
    echo ""
    echo "You must provide an SSH public key to continue."
    echo "To get your public key, run on your local machine:"
    echo "  cat ~/.ssh/id_rsa.pub"
    echo "  or"
    echo "  cat ~/.ssh/id_ed25519.pub"
    echo ""
    exit 1
fi

# Create .ssh directory for new user
echo ""
echo "→ Configuring SSH access for $NEW_USER..."
sudo mkdir -p /home/$NEW_USER/.ssh
sudo chmod 700 /home/$NEW_USER/.ssh

# Add the key to authorized_keys
echo "$SSH_KEY" | sudo tee /home/$NEW_USER/.ssh/authorized_keys > /dev/null
sudo chmod 600 /home/$NEW_USER/.ssh/authorized_keys
sudo chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh

echo -e "${GREEN}✅ SSH key configured successfully${NC}"

# Save the username for other scripts
echo "$NEW_USER" | sudo tee /tmp/new_user_name.txt > /dev/null
sudo chmod 644 /tmp/new_user_name.txt

echo ""
show_success_banner

show_info_box "User Configuration Summary" \
    "User created: ${GREEN}$NEW_USER${NC}" \
    "Sudo access: ${GREEN}Enabled${NC}" \
    "SSH key: ${GREEN}Configured${NC}"

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo '<your_ip>')

show_info_box "Next Steps" \
    "${BOLD}1.${NC} Open a ${YELLOW}NEW${NC} terminal window (keep this one open!)" \
    "" \
    "${BOLD}2.${NC} Test your SSH connection:" \
    "   ${CYAN}ssh $NEW_USER@$PUBLIC_IP${NC}" \
    "" \
    "${BOLD}3.${NC} If the connection works, disconnect from this session:" \
    "   ${CYAN}exit${NC}" \
    "" \
    "${BOLD}4.${NC} Reconnect with the new user and run the main setup:" \
    "   ${CYAN}cd vps-hardening-script-ubuntu-24.04-LTS${NC}" \
    "   ${CYAN}./main_setup.sh${NC}"

show_warning_box "IMPORTANT" \
    "Test the new SSH connection before closing this terminal!" \
    "If you can't connect, you can still fix it from this session."

echo ""