#!/bin/bash
# SCRIPT: Master Menu for VPS Hardening Suite
# Central entry point for all hardening tasks

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/banner.sh" ]; then
    source "$SCRIPT_DIR/banner.sh"
else
    echo "Error: banner.sh not found!"
    exit 1
fi

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check for root/sudo (but allow regular user to run it, will ask for sudo when needed)
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Running as root. It's recommended to run as a regular user.${NC}"
    echo ""
fi

# Main Menu Loop
while true; do
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║               🚀  VPS HARDENING SUITE - MAIN MENU  🚀             ║
║                                                                   ║
║                Ubuntu 24.04 LTS + Dokploy Security                ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}Current User: ${NC}$(whoami)"
    echo -e "${YELLOW}Hostname:     ${NC}$(hostname)"
    echo -e "${YELLOW}IP Address:   ${NC}$(hostname -I | awk '{print $1}')"
    echo ""
    echo "Please select an option:"
    echo ""
    echo -e "  ${BOLD}1.${NC} 🚀 Run Full Setup (New Server)"
    echo -e "     ${GRAY}(Creates user, firewall, Docker, Dokploy)${NC}"
    echo ""
    echo -e "  ${BOLD}2.${NC} 👤 Create Secure User Only"
    echo -e "     ${GRAY}(Just creates a sudo user with SSH keys)${NC}"
    echo ""
    echo -e "  ${BOLD}3.${NC} 🌐 Configure Network"
    echo -e "     ${GRAY}(Static IP, DNS Hardening)${NC}"
    echo ""
    echo -e "  ${BOLD}4.${NC} 🔒 Post-SSL Security"
    echo -e "     ${GRAY}(Block port 3000 after setting up domains)${NC}"
    echo ""
    echo -e "  ${BOLD}5.${NC} 📊 System Health Check"
    echo -e "     ${GRAY}(Verify services, firewall, and security)${NC}"
    echo ""
    echo -e "  ${BOLD}6.${NC} 🐳 Configure Docker"
    echo -e "     ${GRAY}(Log rotation, storage driver)${NC}"
    echo ""
    echo -e "  ${BOLD}7.${NC} 🔍 System Integrity Check"
    echo -e "     ${GRAY}(Verify critical binaries)${NC}"
    echo ""
    echo -e "  ${BOLD}8.${NC} ✅ Validate Scripts"
    echo -e "     ${GRAY}(Check all scripts for issues)${NC}"
    echo ""
    echo -e "  ${BOLD}9.${NC} 🗑️  Remove Default User"
    echo -e "     ${GRAY}(Remove ubuntu user if still present)${NC}"
    echo ""
    echo -e "  ${BOLD}0.${NC} 🚪 Exit"
    echo ""
    
    read -p "Enter choice [0-9]: " choice
    
    case $choice in
        1)
            if [ -f "./main_setup.sh" ]; then
                ./main_setup.sh
            else
                echo -e "${RED}Error: main_setup.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        2)
            if [ -f "./create_user.sh" ]; then
                ./create_user.sh
            else
                echo -e "${RED}Error: create_user.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        3)
            if [ -f "./configure_static_ip.sh" ]; then
                sudo ./configure_static_ip.sh
            else
                echo -e "${RED}Error: configure_static_ip.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        4)
            if [ -f "./post_ssl_setup.sh" ]; then
                ./post_ssl_setup.sh
            else
                echo -e "${RED}Error: post_ssl_setup.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        5)
            if [ -f "./system_check.sh" ]; then
                ./system_check.sh
            else
                echo -e "${RED}Error: system_check.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        6)
            if [ -f "./configure_docker.sh" ]; then
                ./configure_docker.sh
            else
                echo -e "${RED}Error: configure_docker.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        7)
            if [ -f "./check_system_integrity.sh" ]; then
                ./check_system_integrity.sh
            else
                echo -e "${RED}Error: check_system_integrity.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        8)
            if [ -f "./validate_scripts.sh" ]; then
                ./validate_scripts.sh
            else
                echo -e "${RED}Error: validate_scripts.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        9)
            if [ -f "./remove_default_user.sh" ]; then
                ./remove_default_user.sh
            else
                echo -e "${RED}Error: remove_default_user.sh not found!${NC}"
            fi
            read -p "Press Enter to return to menu..."
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            sleep 1
            ;;
    esac
done
