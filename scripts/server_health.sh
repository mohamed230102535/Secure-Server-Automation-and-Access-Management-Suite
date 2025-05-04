#!/bin/bash

SERVERS_FILE="/opt/secure-server-suite/servers.txt"
LOG_FILE="/opt/secure-server-suite/logs/health_$(date +%Y%m%d_%H%M%S).log"

if [[ ! -f "$SERVERS_FILE" ]]; then
    echo "Error: $SERVERS_FILE not found."
    exit 1
fi

umask 027
touch "$LOG_FILE"

collect_health() {
    local IP="$1"
    local USER="$2"
    echo "Collecting health info for $IP as $USER..." | tee -a "$LOG_FILE"
    if [[ "$IP" == "192.168.100.60" || "$IP" == "localhost" || "$IP" == "$(hostname -I | awk '{print $1}')" ]]; then
        OUTPUT=$(
            echo "OS Version:"
            cat /etc/os-release | grep -E "^NAME|^VERSION" || echo "N/A"
            echo "Kernel Version:"
            uname -r
            echo "Disk Usage:"
            df -h / | tail -n 1
            echo "CPU Load:"
            uptime
            echo "Memory Usage:"
            free -h | grep -E "Mem|total" || echo "N/A"
            echo "Uptime:"
            uptime -p
            echo "Running Processes:"
            ps aux | wc -l
            echo "Network Interfaces:"
            ip -br addr show || ifconfig
        ) 2>&1
    else
        OUTPUT=$(ssh -n "$USER@$IP" '
            echo "OS Version:"
            cat /etc/os-release | grep -E "^NAME|^VERSION" || echo "N/A"
            echo "Kernel Version:"
            uname -r
            echo "Disk Usage:"
            df -h / | tail -n 1
            echo "CPU Load:"
            uptime
            echo "Memory Usage:"
            free -h | grep -E "Mem|total" || echo "N/A"
            echo "Uptime:"
            uptime -p
            echo "Running Processes:"
            ps aux | wc -l
            echo "Network Interfaces:"
            ip -br addr show || ifconfig
        ' 2>&1)
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

echo "Available servers:"
cat "$SERVERS_FILE"
read -p "Do you want to run on all servers or a specific server? (all/specific): " CHOICE
if [[ "$CHOICE" == "all" ]]; then
    while IFS=' ' read -r IP USER; do
        [[ -z "$IP" || -z "$USER" ]] && continue
        collect_health "$IP" "$USER"
    done < "$SERVERS_FILE"
elif [[ "$CHOICE" == "specific" ]]; then
    read -p "Enter IP: " IP
    read -p "Enter username: " USER
    if grep -q "$IP $USER" "$SERVERS_FILE"; then
        collect_health "$IP" "$USER"
    else
        echo "Error: $IP $USER not found in $SERVERS_FILE" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    echo "Invalid choice. Use 'all' or 'specific'." | tee -a "$LOG_FILE"
    exit 1
fi

echo "Health check completed. Log saved to $LOG_FILE" | tee -a "$LOG_FILE"
