#!/bin/bash
# Make all scripts executable

echo "Making all scripts executable..."

chmod +x create_user.sh
chmod +x main_setup.sh
chmod +x post_ssl_setup.sh
chmod +x system_check.sh
chmod +x install.sh
chmod +x quick_start.sh
chmod +x menu.sh
chmod +x configure_docker.sh
chmod +x configure_static_ip.sh
chmod +x security_audit.sh
chmod +x emergency_rollback.sh
chmod +x check_system_integrity.sh
chmod +x validate_scripts.sh
chmod +x remove_default_user.sh
chmod +x banner.sh

echo "✅ All scripts are now executable!"
echo ""
echo "Run validation: ./validate_scripts.sh"
