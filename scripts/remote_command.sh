#!/bin/bash

# Check if running on main server
MAIN_SERVER_IP="192.168.64.132"
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [[ "$CURRENT_IP" != "$MAIN_SERVER_IP" ]]; then
    echo "Error: This script can only be run on the main server ($MAIN_SERVER_IP)."
    exit 1
fi

SERVERS_FILE="/opt/secure-server-suite/servers.txt"
LOG_FILE="/opt/secure-server-suite/logs/command_$(date +%Y%m%d_%H%M%S).log"

if [[ ! -f "$SERVERS_FILE" ]]; then
    echo "Error: $SERVERS_FILE not found."
    exit 1
fi

umask 027
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

execute_command() {
    local IP="$1"
    local USER="$2"
    local CMD="$3"
    
    echo "Executing '$CMD' on $IP as $USER..." | tee -a "$LOG_FILE"
    
    if [[ "$IP" == "192.168.100.60" || "$IP" == "localhost" || "$IP" == "$MAIN_SERVER_IP" ]]; then
        OUTPUT=$(bash -c "$CMD" 2>&1)
    else
        OUTPUT=$(ssh -n "$USER@$IP" "bash -c '$CMD'" 2>&1)
    fi
    
    EXIT_STATUS=$?
    echo "$OUTPUT" | tee -a "$LOG_FILE"
    
    if [[ $EXIT_STATUS -eq 0 ]]; then
        echo "Success on $IP" | tee -a "$LOG_FILE"
    else
        echo "Failed on $IP" | tee -a "$LOG_FILE"
    fi
    
    echo "----------------------------------------" | tee -a "$LOG_FILE"
}

echo "Choose an action: (command/update/install)"
read -p "Action: " ACTION

case "$ACTION" in
    command)
        read -p "Enter the command to run: " COMMAND
        if [[ -z "$COMMAND" ]]; then
            echo "Error: No command provided." | tee -a "$LOG_FILE"
            exit 1
        fi
        ;;
    update)
        COMMAND="sudo dnf update -y --skip-broken"
        ;;
    install)
        read -p "Enter the package to install: " PACKAGE
        if [[ -z "$PACKAGE" ]]; then
            echo "Error: No package provided." | tee -a "$LOG_FILE"
            exit 1
        fi
        COMMAND="sudo dnf install -y $PACKAGE"
        ;;
    *)
        echo "Invalid action. Use 'command', 'update', or 'install'." | tee -a "$LOG_FILE"
        exit 1
        ;;
esac

echo "Available servers:"
cat "$SERVERS_FILE"
read -p "Do you want to run on all servers or a specific server? (all/specific): " CHOICE

if [[ "$CHOICE" == "all" ]]; then
    while IFS=' ' read -r IP USER; do
        [[ -z "$IP" || -z "$USER" ]] && continue
        execute_command "$IP" "$USER" "$COMMAND"
    done < "$SERVERS_FILE"
elif [[ "$CHOICE" == "specific" ]]; then
    read -p "Enter IP: " IP
    read -p "Enter username: " USER
    
    if grep -q "$IP $USER" "$SERVERS_FILE"; then
        execute_command "$IP" "$USER" "$COMMAND"
    else
        echo "Error: $IP $USER not found in $SERVERS_FILE" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    echo "Invalid choice. Use 'all' or 'specific'." | tee -a "$LOG_FILE"
    exit 1
fi

echo "Command execution completed. Log saved to $LOG_FILE" | tee -a "$LOG_FILE"
