#!/bin/bash
# Demo script to showcase all banners

source banner.sh

echo "Press Enter to see each banner..."
read

show_install_banner
echo "This is the main installation banner"
echo ""
read

show_user_banner
echo "This is the user creation banner"
echo ""
read

show_setup_banner
echo "This is the main setup banner"
echo ""
read

show_ssl_banner
echo "This is the SSL configuration banner"
echo ""
read

show_check_banner
echo "This is the system check banner"
echo ""
read

show_success_banner
echo "This is the success banner"
echo ""
read

show_error_banner
echo "This is the error banner"
echo ""
read

show_section "Example Section"
echo "This is how sections look"
echo ""
read

show_info_box "Information Box" \
    "Line 1: This is an info box" \
    "Line 2: It can have multiple lines" \
    "Line 3: ${GREEN}With colors!${NC}"
read

show_warning_box "Warning Box" \
    "This is a warning message" \
    "It highlights important information" \
    "${YELLOW}Be careful!${NC}"
read

echo "Progress bar demo:"
for i in {1..10}; do
    show_progress $i 10 "Installing packages"
    sleep 0.3
done
echo ""
read

echo -e "${GREEN}Demo complete!${NC}"
