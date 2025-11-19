#!/bin/bash
# SCRIPT 1: Secure User Creation (Enhanced with Best Practices)

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/banner.sh"

DEFAULT_USER="ubuntu"

# Check if running as default user OR root (for flexibility)
CURRENT_USER=$(whoami)

# Allow ubuntu, root, or any user with sudo privileges
if [ "$CURRENT_USER" != "$DEFAULT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
  # Check if user has sudo privileges
  if ! sudo -n true 2>/dev/null && ! sudo -v 2>/dev/null; then
    echo "ERROR: This script must be run by a user with sudo privileges."
    echo "Current user: $CURRENT_USER"
    echo ""
    echo "Allowed users: ubuntu, root, or any user with sudo access"
    exit 1
  fi
  echo "⚠️  Running as '$CURRENT_USER' (not default 'ubuntu' user)"
  echo "Continuing with sudo privileges..."
fi

# Show banner
show_user_banner

show_section "User Configuration"

# Ask for the new username (REQUIRED - no default)
echo -e "${CYAN}Choose a username for your new administrative user${NC}"
echo -e "${YELLOW}⚠️  This is REQUIRED - you must choose a unique username${NC}"
echo -e "${GRAY}Examples: admin, devops, myname, etc.${NC}"
echo ""

# Loop until a valid username is provided
while true; do
    echo -n "Username: "
    if [ -c /dev/tty ]; then
        read NEW_USER < /dev/tty
    else
        read NEW_USER
    fi
    
    # Check if username is empty
    if [ -z "$NEW_USER" ]; then
        echo -e "${RED}❌ Username cannot be empty. Please choose a username.${NC}"
        echo ""
        continue
    fi
    
    # Check if username is valid (alphanumeric, dash, underscore)
    if ! [[ "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "${RED}❌ Invalid username. Use only lowercase letters, numbers, dash, and underscore.${NC}"
        echo -e "${GRAY}Must start with a letter or underscore.${NC}"
        echo ""
        continue
    fi
    
    # Check if username already exists
    if id "$NEW_USER" &>/dev/null; then
        echo -e "${RED}❌ User '$NEW_USER' already exists. Please choose a different username.${NC}"
        echo ""
        continue
    fi
    
    # Check if username is a system user (UID < 1000)
    if [ "$NEW_USER" = "root" ] || [ "$NEW_USER" = "ubuntu" ] || [ "$NEW_USER" = "admin" ]; then
        echo -e "${YELLOW}⚠️  '$NEW_USER' is a common system username. Choose something more unique for security.${NC}"
        if [ -c /dev/tty ]; then
            read -p "Are you sure you want to use '$NEW_USER'? (yes/no): " -r < /dev/tty
        else
            read -p "Are you sure you want to use '$NEW_USER'? (yes/no): " -r
        fi
        if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
            echo ""
            continue
        fi
    fi
    
    # Username is valid
    echo -e "${GREEN}✓${NC} Username accepted: ${CYAN}$NEW_USER${NC}"
    break
done

echo ""
show_section "Creating User: $NEW_USER"
# Create user non-interactively first
sudo adduser --gecos "" --disabled-password "$NEW_USER"

# Set password manually (robust method for curl | bash)
echo ""
echo "Set password for $NEW_USER:"

while true; do
    # Use /dev/tty explicitly for password input
    if [ -c /dev/tty ]; then
        # Read password with proper TTY handling
        PASS1=""
        PASS2=""
        
        # First password
        echo -n "New password: " > /dev/tty
        IFS= read -rs PASS1 < /dev/tty
        echo "" > /dev/tty
        
        # Second password
        echo -n "Retype new password: " > /dev/tty
        IFS= read -rs PASS2 < /dev/tty
        echo "" > /dev/tty
    else
        # Fallback if TTY is somehow missing
        echo "ERROR: No TTY detected for password input."
        exit 1
    fi

    # Validate password is not empty
    if [ -z "$PASS1" ]; then
        echo -e "${RED}❌ Password cannot be empty.${NC}"
        continue
    fi
    
    # Validate minimum length (8 characters)
    if [ ${#PASS1} -lt 8 ]; then
        echo -e "${RED}❌ Password must be at least 8 characters long.${NC}"
        continue
    fi

    # Check if passwords match
    if [ "$PASS1" != "$PASS2" ]; then
        echo -e "${RED}❌ Passwords do not match. Try again.${NC}"
        continue
    fi

    # Apply password using chpasswd (avoids interactive passwd command issues)
    echo "$NEW_USER:$PASS1" | sudo chpasswd
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Password set successfully${NC}"
        # Clear password variables from memory
        PASS1=""
        PASS2=""
        break
    else
        echo -e "${RED}❌ Failed to set password. Please try again.${NC}"
    fi
done

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
if [ -c /dev/tty ]; then
    read -r SSH_KEY < /dev/tty
else
    read -r SSH_KEY
fi

# Validate SSH key is not empty
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

# Validate SSH key format (basic validation)
if ! [[ "$SSH_KEY" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]][A-Za-z0-9+/]+[=]{0,3}([[:space:]].*)?$ ]]; then
    echo ""
    echo "❌ ERROR: Invalid SSH key format!"
    echo ""
    echo "The key should start with one of:"
    echo "  - ssh-rsa"
    echo "  - ssh-ed25519"
    echo "  - ecdsa-sha2-nistp256"
    echo ""
    echo "Example of valid key:"
    echo "  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx... user@host"
    echo ""
    exit 1
fi

# Additional validation: check key length
SSH_KEY_TYPE=$(echo "$SSH_KEY" | awk '{print $1}')
SSH_KEY_DATA=$(echo "$SSH_KEY" | awk '{print $2}')

if [ ${#SSH_KEY_DATA} -lt 50 ]; then
    echo ""
    echo "❌ ERROR: SSH key appears to be too short or incomplete!"
    echo ""
    echo "Make sure you copied the entire key including the base64 data."
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}✓${NC} SSH key format validated ($SSH_KEY_TYPE)"

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

# Save the username for other scripts (both temp and persistent)
echo "$NEW_USER" | sudo tee /tmp/new_user_name.txt > /dev/null
sudo chmod 644 /tmp/new_user_name.txt

# Also save in user's home directory (persistent across reboots)
sudo -u $NEW_USER bash -c "echo '$NEW_USER' > /home/$NEW_USER/.vps_setup_user"
sudo chmod 644 /home/$NEW_USER/.vps_setup_user

echo ""
show_success_banner

show_info_box "User Configuration Summary" \
    "User created: ${GREEN}$NEW_USER${NC}" \
    "Sudo access: ${GREEN}Enabled${NC}" \
    "SSH key: ${GREEN}Configured${NC}"

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

show_info_box "Next Steps" \
    "${BOLD}1.${NC} Open a ${YELLOW}NEW${NC} terminal window (keep this one open!)" \
    "" \
    "${BOLD}2.${NC} Test your SSH connection:" \
    "   ${CYAN}ssh $NEW_USER@$PUBLIC_IP${NC}" \
    "" \
    "${BOLD}3.${NC} ${YELLOW}CRITICAL:${NC} Verify you can login successfully!" \
    "   Try running: ${CYAN}whoami${NC} and ${CYAN}sudo ls${NC}" \
    "" \
    "${BOLD}4.${NC} If the connection works, disconnect from this session:" \
    "   ${CYAN}exit${NC}" \
    "" \
    "${BOLD}5.${NC} Reconnect with the new user and run the main setup:" \
    "   ${CYAN}cd vps-hardening-script-ubuntu-24.04-LTS${NC}" \
    "   ${CYAN}./main_setup.sh${NC}"

show_warning_box "⚠️  CRITICAL SECURITY WARNING" \
    "DO NOT close this terminal until you verify the new SSH connection works!" \
    "If you can't connect with the new user, you can still fix it from here." \
    "" \
    "Test checklist:" \
    "  ✓ Can you SSH with the new user?" \
    "  ✓ Can you run 'sudo' commands?" \
    "  ✓ Is your SSH key working?"

echo ""