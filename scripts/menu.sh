#!/bin/bash

# File: scripts/menu.sh
# Description: Interactive menu to run Secure Server Suite scripts
# Usage: ./menu.sh [--help]
#   --help: Show this message
# Logs: Stored in logs/menu.log

# Source shared functions
source ./lib/lib.sh

scanner $1

# Set log file
LOGFILE="logs/menu.log"

# Function to display usage
usage() {
  echo "Usage: $0 [--help]"
  echo "  --help: Show this message"
  exit 1
}

# Parse arguments
while [ $# -gt 0 ]; do
  case $1 in
    --help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Menu options
options=(
  "Install Fail2Ban"
  "Manage Cron Jobs"
  "Generate Passwords"
  "Run Remote Command"
  "Check Server Health"
  "Quit"
)

# Display menu
while true; do
  echo "Secure Server Automation Suite"
  PS3="Select an option: "
  select opt in "${options[@]}"; do
    case $opt in
      "Install Fail2Ban")
        read -p "Enter options (e.g., --maxretry 5 --harden-ssh): " args
        ./scripts/fail2ban_setup.sh $args
        log "INFO" "Menu" "Ran fail2ban_setup.sh with args: $args"
        break
        ;;
      "Manage Cron Jobs")
        read -p "Enter action (list/add/remove) and args: " args
        ./scripts/cron_manager.sh $args
        log "INFO" "Menu" "Ran cron_manager.sh with args: $args"
        break
        ;;
      "Generate Passwords")
        read -p "Enter length, number, and options (e.g., 16 3 --symbols): " args
        ./scripts/password_generator.sh $args
        log "INFO" "Menu" "Ran password_generator.sh with args: $args"
        break
        ;;
      "Run Remote Command")
        read -p "Enter command and options: " args
        ./scripts/remote_command.sh $args
        log "INFO" "Menu" "Ran remote_command.sh with args: $args"
        break
        ;;
      "Check Server Health")
        ./scripts/server_health.sh
        log "INFO" "Menu" "Ran server_health.sh"
        break
        ;;
      "Quit")
        log "INFO" "Menu" "User quit"
        exit 0
        ;;
      *) echo "Invalid option" ;;
    esac
  done
done
