#!/bin/bash

# Configuration
SCRIPT_DIR="/opt/secure-server-suite/scripts"
LOG_DIR="/opt/secure-server-suite/logs"
MENU_LOG="$LOG_DIR/menu_$(date +%Y%m%d_%H%M%S).log"
VERSION="1.2.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to display header
show_header() {
    clear
    echo -e "${BLUE}"
    echo "   _____                           __   ___   __"
    echo "  / ___/___  ______   _____  _____/ /__/   | / /___ _____"
    echo "  \__ \/ _ \/ ___/ | / / _ \/ ___/ //_/ /| |/ / __ \`/ __/"
    echo " ___/ /  __/ /   | |/ /  __/ /  / ,< / ___ / /_/ / /_  "
    echo "/____/\___/_/    |___/\___/_/  /_/|_/_/  |_\__,_/\__/  "
    echo -e "${NC}"
    echo -e "${YELLOW}Secure Server Automation and Access Management Suite v${VERSION}${NC}"
    echo -e "${BLUE}----------------------------------------------------${NC}"     
}

# Function to log menu actions
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MENU_LOG"
}

# Function to display menu
show_menu() {
    show_header
    echo -e "${GREEN}Main Menu:${NC}"
    echo -e "  ${YELLOW}1.${NC} Run Remote Command"
    echo -e "  ${YELLOW}2.${NC} Check Server Health"
    echo -e "  ${YELLOW}3.${NC} Setup Fail2Ban Protection"
    echo -e "  ${YELLOW}4.${NC} Manage Cron Jobs"
    echo -e "  ${YELLOW}5.${NC} Secure Password Generator"
    echo -e "  ${YELLOW}6.${NC} Exit"
    echo ""
}

# Function to validate scripts exist
validate_script() {
    local script="$1"
    if [[ ! -x "$SCRIPT_DIR/$script" ]]; then
        echo -e "${RED}ERROR: Script $script not found or not executable!${NC}"    
        log_action "Failed to execute $script - not found or not executable"       
        return 1
    fi
    return 0
}

# Function to execute script with error handling
run_script() {
    local script_name="$1"
    local script_file="$2"

    if validate_script "$script_file"; then
        log_action "Starting $script_name"
        echo -e "${BLUE}Starting $script_name...${NC}"
        if "$SCRIPT_DIR/$script_file"; then
            echo -e "${GREEN}$script_name completed successfully${NC}"
            log_action "$script_name completed successfully"
        else
            echo -e "${RED}$script_name encountered errors${NC}"
            log_action "$script_name encountered errors"
        fi
    fi
}

# Main menu loop
while true; do
    show_menu
    read -p "$(echo -e ${YELLOW}"Select an option (1-6): "${NC}) " OPTION

    case $OPTION in
        1)
            run_script "Remote Command" "remote_command.sh"
            ;;
        2)
            run_script "Server Health Check" "server_health.sh"
            ;;
        3)
            run_script "Fail2Ban Setup" "fail2ban_setup.sh"
            ;;
        4)
            run_script "Cron Job Manager" "cron_manager.sh"
            ;;
        5)
            run_script "Secure Password Generator" "password_generator.sh"
            ;;
        6)
            log_action "User exited the menu"
            echo -e "${GREEN}Exiting... Thank you for using the Secure Server Suite!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please select 1, 2, 3, 4, 5, or 6.${NC}"   
            log_action "Invalid option selected: $OPTION"
            ;;
    esac

    read -p "$(echo -e ${YELLOW}"Press Enter to return to menu..."${NC}) " -r      
done


# ... existing code ...

show_menu() {
    show_header
    echo -e "${GREEN}Main Menu:${NC}"
    echo -e "  ${YELLOW}1.${NC} Run Remote Command"
    echo -e "  ${YELLOW}2.${NC} Check Server Health"
    echo -e "  ${YELLOW}3.${NC} Setup Fail2Ban Protection"
    echo -e "  ${YELLOW}4.${NC} Manage Cron Jobs"
    echo -e "  ${YELLOW}5.${NC} Secure Password Generator"
    echo -e "  ${YELLOW}6.${NC} Exit"
    echo ""
}


