#!/bin/bash

# Exit on error and undefined variables
set -eu

# Configuration
LOG_DIR="/opt/secure-server-suite/logs"
SERVERS_FILE="/opt/secure-server-suite/servers.txt"
LOG_FILE="$LOG_DIR/fail2ban_$(date +%Y%m%d_%H%M%S).log"
SSH_TIMEOUT=10
CONFIG_BACKUP_DIR="/opt/secure-server-suite/backups/fail2ban"

# Fail2Ban Configuration
FAIL2BAN_SSHD_CONFIG="[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
findtime = 10m
bantime = 1h
ignoreip = 127.0.0.1/8"

# Create directories if they don't exist
mkdir -p "$LOG_DIR" "$CONFIG_BACKUP_DIR"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to install Fail2Ban
install_fail2ban() {
    local ip="$1"
    local user="$2"
    
    log "Detecting OS on $ip..."
    OS_ID=$(ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" \
        'source /etc/os-release 2>/dev/null && echo $ID || echo "unknown"')
    
    case "$OS_ID" in
        rhel|centos|fedora|almalinux|rocky)
            log "Installing Fail2Ban on RHEL-based system ($OS_ID)..."
            ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" \
                "sudo dnf install -y epel-release && \
                 sudo dnf install -y fail2ban && \
                 sudo systemctl enable --now fail2ban"
            ;;
            
        ubuntu|debian)
            log "Installing Fail2Ban on Debian-based system ($OS_ID)..."
            ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" \
                "sudo apt update && \
                 sudo apt install -y fail2ban && \
                 sudo systemctl enable --now fail2ban"
            ;;
            
        *)
            log "ERROR: Unsupported OS ($OS_ID) on $ip"
            return 1
            ;;
    esac
    
    return 0
}

# Function to configure Fail2Ban
configure_fail2ban() {
    local ip="$1"
    local user="$2"
    
    log "Backing up existing Fail2Ban config on $ip..."
    ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" \
        "sudo mkdir -p /etc/fail2ban/backups && \
         sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/backups/jail.conf.bak_$(date +%Y%m%d)"
    
    log "Configuring Fail2Ban on $ip..."
    ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" \
        "echo '$FAIL2BAN_SSHD_CONFIG' | sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null && \
         sudo systemctl restart fail2ban"
}

# Function to verify installation
verify_installation() {
    local ip="$1"
    local user="$2"
    
    if ssh -o ConnectTimeout=$SSH_TIMEOUT "$user@$ip" "sudo fail2ban-client status sshd"; then
        log "SUCCESS: Fail2Ban is active on $ip"
        return 0
    else
        log "ERROR: Fail2Ban verification failed on $ip"
        return 1
    fi
}

# Main execution
log "Starting Fail2Ban setup..."

# Check if servers file exists
if [[ ! -f "$SERVERS_FILE" ]]; then
    log "ERROR: Servers file not found at $SERVERS_FILE"
    exit 1
fi

# Display available servers
log "Available servers:"
column -t "$SERVERS_FILE" | tee -a "$LOG_FILE"

# Get server selection
while true; do
    read -rp "Do you want to run on all servers or a specific server? (all/specific): " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    
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
        log "Invalid choice. Please enter 'all' or 'specific'."
    fi
done

if [[ -z "$TARGET_SERVERS" ]]; then
    log "ERROR: No valid servers selected."
    exit 1
fi

# Process each server
while read -r IP USER; do
    # Skip empty lines or comments
    [[ -z "$IP" || "$IP" == \#* ]] && continue
    
    log "Processing server $IP (user $USER)..."
    
    # Check SSH connection first
    if ! ssh -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes "$USER@$IP" true; then
        log "ERROR: Failed to connect to $IP"
        continue
    fi

    # Install Fail2Ban
    if ! install_fail2ban "$IP" "$USER"; then
        continue
    fi

    # Configure Fail2Ban
    if ! configure_fail2ban "$IP" "$USER"; then
        continue
    fi

    # Verify installation
    verify_installation "$IP" "$USER"
    
done <<< "$TARGET_SERVERS"

log "Fail2Ban setup completed. Detailed log saved to $LOG_FILE"
