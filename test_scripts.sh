#!/bin/bash
# Script de test pour vérifier la syntaxe de tous les scripts

echo "=================================================================="
echo "  🧪 Testing Script Syntax"
echo "=================================================================="
echo ""

ERRORS=0
WARNINGS=0

# Liste des scripts à tester
SCRIPTS=(
    "create_user.sh"
    "main_setup.sh"
    "post_ssl_setup.sh"
    "system_check.sh"
    "install.sh"
    "quick_start.sh"
    "configure_docker.sh"
    "make_executable.sh"
)

echo "Testing ${#SCRIPTS[@]} scripts..."
echo ""

for script in "${SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "❌ $script - FILE NOT FOUND"
        ERRORS=$((ERRORS + 1))
        continue
    fi
    
    # Test syntax with bash -n
    if bash -n "$script" 2>/dev/null; then
        echo "✅ $script - Syntax OK"
    else
        echo "❌ $script - SYNTAX ERROR"
        bash -n "$script"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check if executable
    if [ -x "$script" ]; then
        echo "   ✓ Executable"
    else
        echo "   ⚠️  Not executable (run: chmod +x $script)"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    echo ""
done

echo "=================================================================="
echo "  📊 Test Results"
echo "=================================================================="
echo ""
echo "Scripts tested: ${#SCRIPTS[@]}"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ All scripts passed syntax check!"
    exit 0
else
    echo "❌ Some scripts have errors. Please fix them before deployment."
    exit 1
fi
