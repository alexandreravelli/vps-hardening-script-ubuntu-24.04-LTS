#!/bin/bash
# SCRIPT: Security Audit - Comprehensive System Check
# Verifies: SSH, Firewall, DNS, AppArmor, Kernel, Users, Docker, etc.

set -e

# Load banner functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/banner.sh" ]; then
    source "$SCRIPT_DIR/banner.sh"
else
    # Fallback colors if banner.sh is missing
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    
    show_section() { echo -e "${BLUE}--- $1 ---${NC}"; }
    report_finding() { echo "$1: $2"; }
fi

# Initialize counters
CRITICAL=0
HIGH=0
MEDIUM=0
LOW=0
PASS=0

# Function to report findings with standardized formatting
report_finding() {
    local severity=$1
    local title=$2
    local description=$3
    
    case $severity in
        CRITICAL)
            echo -e "${RED}[CRITICAL]${NC} $title"
            CRITICAL=$((CRITICAL + 1))
            ;;
        HIGH)
            echo -e "${RED}[HIGH]${NC} $title"
            HIGH=$((HIGH + 1))
            ;;
        MEDIUM)
            echo -e "${YELLOW}[MEDIUM]${NC} $title"
            MEDIUM=$((MEDIUM + 1))
            ;;
        LOW)
            echo -e "${CYAN}[LOW]${NC} $title"
            LOW=$((LOW + 1))
            ;;
        PASS)
            echo -e "${GREEN}[PASS]${NC} $title"
            PASS=$((PASS + 1))
            ;;
    esac
    
    if [ -n "$description" ]; then
        echo "  → $description"
    fi
}

clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                 🔒  VPS SECURITY AUDIT REPORT  🔒                ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo ""

# 1. SSH Security
show_section "SSH Configuration"

# Check SSH port
SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
if [ "$SSH_PORT" = "22" ]; then
    report_finding "HIGH" "SSH on default port 22" "Change to non-standard port (50000-59999)"
else
    report_finding "PASS" "SSH on non-standard port: $SSH_PORT"
fi

# Check root login
if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
    report_finding "CRITICAL" "Root login enabled" "Set 'PermitRootLogin no'"
else
    report_finding "PASS" "Root login disabled"
fi

# Check password authentication
if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
    report_finding "MEDIUM" "Password authentication enabled" "Use SSH keys only"
else
    report_finding "PASS" "Password authentication disabled"
fi

# 2. Firewall & Network
show_section "Firewall & Network"

# UFW Status
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        report_finding "PASS" "UFW firewall is active"
    else
        report_finding "CRITICAL" "UFW firewall is inactive" "Enable with: sudo ufw enable"
    fi
else
    report_finding "CRITICAL" "UFW not installed"
fi

# DNS Security (Quad9)
if resolvectl status | grep -q "9.9.9.11"; then
    report_finding "PASS" "Quad9 DNS is configured"
else
    report_finding "HIGH" "Quad9 DNS not detected" "System is using ISP/Default DNS"
fi

# IPv6 Privacy
if resolvectl status | grep -q "2620:fe::11"; then
    report_finding "PASS" "Quad9 IPv6 DNS is configured"
else
    report_finding "MEDIUM" "Quad9 IPv6 DNS not detected" "Check IPv6 DNS settings"
fi

# 3. System Hardening
show_section "System Hardening"

# AppArmor
if command -v aa-status &> /dev/null; then
    if sudo aa-status --enabled 2>/dev/null; then
        report_finding "PASS" "AppArmor is enabled"
    else
        report_finding "HIGH" "AppArmor is disabled"
    fi
else
    report_finding "MEDIUM" "AppArmor not installed"
fi

# Fail2Ban
if systemctl is-active --quiet fail2ban; then
    report_finding "PASS" "Fail2Ban is running"
else
    report_finding "HIGH" "Fail2Ban is not running"
fi

# Swap Encryption/Usage
if [ -f /proc/swaps ]; then
    SWAP_COUNT=$(grep -v "Filename" /proc/swaps | wc -l)
    if [ "$SWAP_COUNT" -eq 0 ]; then
        report_finding "PASS" "No swap file (Good for security/performance on SSD)"
    else
        report_finding "LOW" "Swap file enabled" "Ensure it's encrypted if storing sensitive data"
    fi
fi

# 4. User Security
show_section "User Security"

# Check for 'ubuntu' user
if getent passwd ubuntu > /dev/null; then
    report_finding "HIGH" "Default 'ubuntu' user exists" "Remove immediately"
else
    report_finding "PASS" "Default 'ubuntu' user removed"
fi

# Check for empty passwords
EMPTY_PASS=$(sudo awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow | grep -v "^root$" || true)
if [ -n "$EMPTY_PASS" ]; then
    report_finding "CRITICAL" "Users with empty passwords found"
else
    report_finding "PASS" "No empty password users"
fi

# 5. Docker Security
show_section "Docker Security"

if command -v docker &> /dev/null; then
    # Daemon config
    if [ -f /etc/docker/daemon.json ]; then
        report_finding "PASS" "Docker daemon.json exists"
        
        # Check for live-restore (incompatible with Swarm)
        if grep -q '"live-restore".*true' /etc/docker/daemon.json 2>/dev/null; then
            report_finding "MEDIUM" "live-restore enabled" "Incompatible with Docker Swarm/Dokploy"
        fi
    else
        report_finding "MEDIUM" "Docker daemon.json missing"
    fi
    
    # Port 3000 exposure
    if ss -tuln | grep -q ":3000 "; then
        if sudo iptables -L DOCKER-USER -n 2>/dev/null | grep -q "DROP"; then
            report_finding "PASS" "Port 3000 blocked externally"
        else
            report_finding "HIGH" "Port 3000 exposed to world" "Run post_ssl_setup.sh"
        fi
    fi
    
    # Check Docker socket permissions
    if [ -S /var/run/docker.sock ]; then
        SOCKET_PERMS=$(stat -c %a /var/run/docker.sock)
        if [ "$SOCKET_PERMS" = "660" ] || [ "$SOCKET_PERMS" = "600" ]; then
            report_finding "PASS" "Docker socket permissions secure ($SOCKET_PERMS)"
        else
            report_finding "MEDIUM" "Docker socket permissions too open ($SOCKET_PERMS)"
        fi
    fi
else
    report_finding "LOW" "Docker not installed"
fi

# 6. Backup Status
show_section "Backup Status"

if [ -d /var/backups/vps-hardening ]; then
    BACKUP_COUNT=$(ls -1 /var/backups/vps-hardening 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 0 ]; then
        LATEST_BACKUP=$(ls -t /var/backups/vps-hardening | head -1)
        report_finding "PASS" "System backups exist ($BACKUP_COUNT backups)" "Latest: $LATEST_BACKUP"
    else
        report_finding "MEDIUM" "No system backups found" "Run create_backup.sh"
    fi
else
    report_finding "MEDIUM" "Backup directory doesn't exist" "Run create_backup.sh"
fi

# 7. Setup State
show_section "Setup State"

if [ -d "$HOME/.vps_setup_state" ]; then
    STATE_COUNT=$(ls -1 "$HOME/.vps_setup_state" 2>/dev/null | wc -l)
    if [ "$STATE_COUNT" -gt 5 ]; then
        report_finding "PASS" "Setup completed ($STATE_COUNT steps)"
    else
        report_finding "MEDIUM" "Setup incomplete ($STATE_COUNT steps)" "Run main_setup.sh"
    fi
else
    report_finding "HIGH" "Setup not started" "Run main_setup.sh"
fi

# 8. Log Files
show_section "Log Files"

if [ -f /var/log/vps_setup.log ]; then
    LOG_SIZE=$(du -h /var/log/vps_setup.log | cut -f1)
    report_finding "PASS" "Setup log exists ($LOG_SIZE)"
    
    # Check for errors in log
    ERROR_COUNT=$(grep -c "ERROR\|Failed\|failed" /var/log/vps_setup.log 2>/dev/null || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        report_finding "MEDIUM" "$ERROR_COUNT errors found in setup log" "Review: tail -100 /var/log/vps_setup.log"
    fi
else
    report_finding "LOW" "Setup log not found"
fi

# 9. Port 22 Status
show_section "Port 22 Status"

if ss -tuln | grep -q ":22 "; then
    report_finding "HIGH" "Port 22 still open" "Should be closed after setup"
else
    report_finding "PASS" "Port 22 closed (secure)"
fi

# 10. Dokploy Status
show_section "Dokploy Status"

if command -v docker &> /dev/null; then
    if docker ps | grep -q dokploy; then
        report_finding "PASS" "Dokploy container running"
        
        # Check if accessible
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" =~ ^(200|302)$ ]]; then
            report_finding "PASS" "Dokploy responding (HTTP $HTTP_CODE)"
        else
            report_finding "MEDIUM" "Dokploy not responding (HTTP $HTTP_CODE)"
        fi
    else
        report_finding "MEDIUM" "Dokploy container not running"
    fi
fi

# Summary
echo ""
echo "=================================================================="
echo "  📊 AUDIT SUMMARY"
echo "=================================================================="
echo -e "${RED}Critical: $CRITICAL${NC}"
echo -e "${RED}High:     $HIGH${NC}"
echo -e "${YELLOW}Medium:   $MEDIUM${NC}"
echo -e "${CYAN}Low:      $LOW${NC}"
echo -e "${GREEN}Passed:   $PASS${NC}"
echo ""

# Recommendations
if [ $CRITICAL -gt 0 ] || [ $HIGH -gt 0 ]; then
    echo "=================================================================="
    echo "  🔧 RECOMMENDED ACTIONS"
    echo "=================================================================="
    echo ""
    
    if [ $CRITICAL -gt 0 ]; then
        echo -e "${RED}CRITICAL ISSUES - Fix immediately:${NC}"
        echo "  • Review critical findings above"
        echo "  • Run: ./emergency_rollback.sh if system is unstable"
        echo ""
    fi
    
    if [ $HIGH -gt 0 ]; then
        echo -e "${RED}HIGH PRIORITY:${NC}"
        echo "  • Close port 22 if still open"
        echo "  • Remove default ubuntu user if present"
        echo "  • Secure port 3000 after SSL setup"
        echo ""
    fi
    
    echo "=================================================================="
    echo ""
    echo -e "${RED}❌ Security issues found. Please address critical/high items.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ System security looks good!${NC}"
    echo ""
    echo "Recommendations:"
    echo "  • Run security audit monthly"
    echo "  • Keep system updated: sudo apt update && sudo apt upgrade"
    echo "  • Review logs regularly: tail -100 /var/log/vps_setup.log"
    echo "  • Create backups before changes: ./create_backup.sh"
    echo ""
    exit 0
fi
