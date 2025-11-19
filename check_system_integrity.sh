#!/bin/bash
# System Integrity Check - Verify critical binaries haven't been tampered with

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "=================================================================="
echo "  🔍 System Integrity Check"
echo "=================================================================="
echo ""

ISSUES=0
WARNINGS=0

# Check if debsums is installed
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}⚠️  debsums not installed, installing...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y debsums
fi

# Critical packages to verify
CRITICAL_PACKAGES=(
    "openssh-server"
    "sudo"
    "coreutils"
    "bash"
    "systemd"
)

echo "Checking integrity of critical packages..."
echo ""

for package in "${CRITICAL_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        echo -n "  Checking $package... "
        
        if sudo debsums -s "$package" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
            echo -e "    ${RED}⚠️  Package $package has modified files!${NC}"
            ISSUES=$((ISSUES + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠️  $package not installed${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
done

echo ""

# Check for suspicious SUID binaries
echo "Checking for suspicious SUID binaries..."
SUID_COUNT=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
echo "  Found $SUID_COUNT SUID binaries"

# Known safe SUID binaries count (approximate)
if [ "$SUID_COUNT" -gt 50 ]; then
    echo -e "  ${YELLOW}⚠️  Unusually high number of SUID binaries${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# Check for rootkits with basic checks
echo "Basic rootkit checks..."

# Check for suspicious kernel modules
SUSPICIOUS_MODULES=$(lsmod | grep -iE "(hide|rootkit|backdoor)" || true)
if [ -n "$SUSPICIOUS_MODULES" ]; then
    echo -e "  ${RED}⚠️  Suspicious kernel modules found:${NC}"
    echo "$SUSPICIOUS_MODULES" | sed 's/^/    /'
    ISSUES=$((ISSUES + 1))
else
    echo -e "  ${GREEN}✓${NC} No suspicious kernel modules"
fi

# Check for suspicious processes
SUSPICIOUS_PROCS=$(ps aux | grep -iE "(nc -l|ncat -l|/dev/tcp)" | grep -v grep || true)
if [ -n "$SUSPICIOUS_PROCS" ]; then
    echo -e "  ${YELLOW}⚠️  Suspicious processes found:${NC}"
    echo "$SUSPICIOUS_PROCS" | sed 's/^/    /'
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "  ${GREEN}✓${NC} No suspicious processes"
fi

echo ""
echo "=================================================================="
echo "  Summary"
echo "=================================================================="
echo -e "${RED}Issues:   $ISSUES${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

if [ $ISSUES -gt 0 ]; then
    echo -e "${RED}❌ System integrity check FAILED${NC}"
    echo ""
    echo "Recommended actions:"
    echo "  1. Review modified files: sudo debsums -c"
    echo "  2. Reinstall affected packages: sudo apt-get install --reinstall <package>"
    echo "  3. Consider running a full rootkit scanner: sudo apt-get install rkhunter && sudo rkhunter --check"
    echo ""
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  System integrity check completed with warnings${NC}"
    exit 0
else
    echo -e "${GREEN}✅ System integrity check passed${NC}"
    exit 0
fi
