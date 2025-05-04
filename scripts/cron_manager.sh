#!/bin/bash

# Exit on error and undefined variables
set -eu

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="/opt/secure-server-suite/logs"
SERVERS_FILE="/opt/secure-server-suite/servers.txt"
LOG_FILE="$LOG_DIR/cron_manager_$(date +%Y%m%d_%H%M%S).log"
SSH_TIMEOUT=10
CRON_BACKUP_DIR="/opt/secure-server-suite/backups/cron"

# Create directories if they don't exist
mkdir -p "$LOG_DIR" "$CRON_BACKUP_DIR"

# Function to print usage/help
usage() {
    echo -e "${BLUE}Usage:${NC} $0"
    echo -e "This script manages cron jobs on multiple servers."
    echo -e "Servers file: ${YELLOW}$SERVERS_FILE${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    echo
    echo "You will be prompted for actions interactively."
    echo
}

# Function to log messages (with color for INFO/ERROR)
log() {
    local msg="$1"
    if [[ "$msg" == ERROR* ]]; then
        echo -e "[${RED}$(date '+%Y-%m-%d %H:%M:%S')${NC}] $msg" | tee -a "$LOG_FILE"
    elif [[ "$msg" == *completed* || "$msg" == *added* || "$msg" == *saved* || "$msg" == *removed* ]]; then
        echo -e "[${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}] $msg" | tee -a "$LOG_FILE"
    else
        echo -e "[${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${NC}] $msg" | tee -a "$LOG_FILE"
    fi
}

# Function to backup current cron jobs
backup_cron() {
    local ip="$1"
    local user="$2"
    local backup_file="$CRON_BACKUP_DIR/cron_${ip}_$(date +%Y%m%d_%H%M%S).txt"

    log "Backing up cron jobs for $ip..."
    ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" "crontab -l" > "$backup_file" 2>/dev/null || true
    log "Backup saved to $backup_file"
}

# Function to list cron jobs
list_cron() {
    local ip="$1"
    local user="$2"
    log "Listing cron jobs for $ip..."
    ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" "crontab -l" 2>/dev/null || echo -e "${YELLOW}No cron jobs found on $ip${NC}"
}

# Function to add a cron job
add_cron() {
    local ip="$1"
    local user="$2"
    local schedule="$3"
    local command="$4"
    local comment="$5"
    local temp_file="/tmp/cron_${ip}_$$"

    log "Adding cron job to $ip: $schedule $command"
    ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" "crontab -l 2>/dev/null" > "$temp_file" || touch "$temp_file"
    echo "# $comment" >> "$temp_file"
    echo "$schedule $command" >> "$temp_file"
    scp "$temp_file" "$user@$ip:/tmp/cron_new_$$" >/dev/null
    ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" "crontab /tmp/cron_new_$$ && rm /tmp/cron_new_$$"
    rm -f "$temp_file"
    log "Cron job added to $ip"
}

# Function to remove a cron job by pattern
remove_cron() {
    local ip="$1"
    local user="$2"
    local pattern="$3"
    local temp_file="/tmp/cron_${ip}_$$"

    log "Removing cron jobs matching '$pattern' from $ip"
    ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" "crontab -l 2>/dev/null" | grep -v "$pattern" > "$temp_file" || touch "$temp_file"
    scp "$temp_file" "$user@$ip:/tmp/cron_new_$$" >/dev/null
    ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" "crontab /tmp/cron_new_$$ && rm /tmp/cron_new_$$"
    rm -f "$temp_file"
    log "Matching cron jobs removed from $ip"
}

# Show help if requested
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

log "Starting Cron Manager..."

# Check if servers file exists
if [[ ! -f "$SERVERS_FILE" ]]; then
    log "ERROR: Servers file not found at $SERVERS_FILE"
    exit 1
fi

# Display available servers
log "Available servers:"
column -t "$SERVERS_FILE" | tee -a "$LOG_FILE"
echo

# Get server selection
while true; do
    read -rp "$(echo -e "${YELLOW}Do you want to run on all servers or a specific server? (all/specific/exit): ${NC}")" choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    if [[ "$choice" == "exit" ]]; then
        log "Exiting by user request."
        exit 0
    fi

    if [[ "$choice" == "specific" ]]; then
        read -rp "Enter server IP or hostname: " target
        TARGET_SERVERS=$(grep -E "^$target[[:space:]]+" "$SERVERS_FILE" || true)

        if [[ -z "$TARGET_SERVERS" ]]; then
            log "ERROR: Server '$target' not found in $SERVERS_FILE"
            continue
        else
            break
        fi
    elif [[ "$choice" == "all" ]]; then
        TARGET_SERVERS=$(grep -v '^#' "$SERVERS_FILE" | grep -v '^$' || true)
        break
    else
        log "Invalid choice. Please enter 'all', 'specific', or 'exit'."
    fi
done

if [[ -z "$TARGET_SERVERS" ]]; then
    log "ERROR: No valid servers selected."
    exit 1
fi

# Select action (with menu)
echo -e "${BLUE}Select action:${NC}"
echo -e "${GREEN}1.${NC} List cron jobs"
echo -e "${GREEN}2.${NC} Add cron job"
echo -e "${GREEN}3.${NC} Remove cron job"
echo -e "${GREEN}4.${NC} Backup cron jobs"
echo -e "${GREEN}5.${NC} Exit"
while true; do
    read -rp "$(echo -e "${YELLOW}Enter choice (1-5): ${NC}")" action
    case "$action" in
        1)
            while read -r IP USER; do
                [[ -z "$IP" || "$IP" == \#* ]] && continue
                list_cron "$IP" "$USER"
            done <<< "$TARGET_SERVERS"
            break
            ;;
        2)
            read -rp "Enter cron schedule (e.g., '0 * * * *'): " schedule
            read -rp "Enter command to execute: " command
            read -rp "Enter comment for the job: " comment
            echo -e "${YELLOW}You are about to add the following cron job:${NC}"
            echo -e "${GREEN}$schedule $command # $comment${NC}"
            read -rp "Proceed? (y/n): " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || { log "Cancelled by user."; exit 0; }
            while read -r IP USER; do
                [[ -z "$IP" || "$IP" == \#* ]] && continue
                add_cron "$IP" "$USER" "$schedule" "$command" "$comment"
            done <<< "$TARGET_SERVERS"
            break
            ;;
        3)
            read -rp "Enter pattern to match jobs for removal: " pattern
            echo -e "${RED}WARNING: This will remove all jobs matching: '$pattern'${NC}"
            read -rp "Are you sure? (y/n): " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || { log "Cancelled by user."; exit 0; }
            while read -r IP USER; do
                [[ -z "$IP" || "$IP" == \#* ]] && continue
                remove_cron "$IP" "$USER" "$pattern"
            done <<< "$TARGET_SERVERS"
            break
            ;;
        4)
            while read -r IP USER; do
                [[ -z "$IP" || "$IP" == \#* ]] && continue
                backup_cron "$IP" "$USER"
            done <<< "$TARGET_SERVERS"
            break
            ;;
        5)
            log "Exiting by user request."
            exit 0
            ;;
        *)
            log "Invalid action. Please enter 1-5."
            ;;
    esac
done

log "Cron Manager completed. Detailed log saved to $LOG_FILE"
