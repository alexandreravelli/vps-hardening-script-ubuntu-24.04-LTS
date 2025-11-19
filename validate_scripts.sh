#!/bin/bash
# Script Validation Tool - Check all scripts for common issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "=================================================================="
echo "  🔍 Script Validation Tool"
echo "=================================================================="
echo ""

ERRORS=0
WARNINGS=0
PASSED=0

# Get all shell scripts
SCRIPTS=$(find . -maxdepth 1 -name "*.sh" -type f)

for script in $SCRIPTS; do
    echo "Checking: $script"
    
    # Check if executable
    if [ ! -x "$script" ]; then
        echo -e "  ${YELLOW}⚠️  Not executable${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  ${GREEN}✓${NC} Executable"
    fi
    
    # Check shebang
    FIRST_LINE=$(head -1 "$script")
    if [[ "$FIRST_LINE" =~ ^#!/bin/bash ]]; then
        echo -e "  ${GREEN}✓${NC} Valid shebang"
    else
        echo -e "  ${RED}✗${NC} Invalid or missing shebang: $FIRST_LINE"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check for 'set -e'
    if grep -q "^set -e" "$script"; then
        echo -e "  ${GREEN}✓${NC} Error handling (set -e)"
    else
        echo -e "  ${YELLOW}⚠️  No 'set -e' found${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for dangerous patterns
    if grep -qE "rm -rf /|rm -rf \$HOME" "$script"; then
        echo -e "  ${RED}✗${NC} DANGEROUS: Potentially destructive rm command"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check for unquoted variables in dangerous contexts
    if grep -qE 'rm.*\$[A-Z_]+[^"]' "$script"; then
        echo -e "  ${YELLOW}⚠️  Unquoted variable in rm command${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Run shellcheck if available
    if command -v shellcheck &> /dev/null; then
        if shellcheck -S warning "$script" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Shellcheck passed"
            PASSED=$((PASSED + 1))
        else
            echo -e "  ${YELLOW}⚠️  Shellcheck warnings:${NC}"
            shellcheck -S warning "$script" 2>&1 | head -5 | sed 's/^/    /'
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
    
    echo ""
done

echo "=================================================================="
echo "  Summary"
echo "=================================================================="
echo -e "${GREEN}Passed:   $PASSED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Errors:   $ERRORS${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ Validation FAILED - fix errors before deploying${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Validation completed with warnings${NC}"
    exit 0
else
    echo -e "${GREEN}✅ All scripts validated successfully${NC}"
    exit 0
fi
