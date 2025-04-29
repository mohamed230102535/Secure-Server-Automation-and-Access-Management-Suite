#!/bin/bash

# File: scripts/fail2ban_setup.sh
# Description: Installs and configures Fail2Ban on remote servers listed in servers.txt
# Usage: ./fail2ban_setup.sh [--maxretry <num>] [--bantime <time>] [--findtime <time>] [--harden-ssh] [--force]
#   --maxretry: Max failed attempts before ban (default: 5)
#   --bantime: Ban duration (e.g., 10m, 1h, default: 10m)
#   --findtime: Time window for maxretry attempts (default: 10m)
#   --harden-ssh: Disable root login and password authentication
#   --force: Skip confirmation prompt
#   --help: Show this message
# Requirements: SSH key-based authentication, sudo without password on remote servers
# Logs: Stored in logs/fail2ban_setup.log

# Source shared functions
source ./lib/lib.sh

# Set log file
LOGFILE="logs/fail2ban_setup.log"

# Default Fail2Ban settings
MAXRETRY=5
BANTIME="10m"
FINDTIME="10m"
HARDEN_SSH=false
FORCE=""

# Function to display usage
usage() {
  echo "Usage: $0 [--maxretry <num>] [--bantime <time>] [--findtime <time>] [--harden-ssh] [--force] [--help]"
  echo "  --maxretry: Max failed attempts (default: 5)"
  echo "  --bantime: Ban duration (e.g., 10m, 1h, default: 10m)"
  echo "  --findtime: Time window (default: 10m)"
  echo "  --harden-ssh: Disable root login and password auth"
  echo "  --force: Skip confirmation prompt"
  echo "  --help: Show this message"
  exit 1
}

# Parse arguments
while [ $# -gt 0 ]; do
  case $1 in
    --maxretry) MAXRETRY=$2; shift 2 ;;
    --bantime) BANTIME=$2; shift 2 ;;
    --findtime) FINDTIME=$2; shift 2 ;;
    --harden-ssh) HARDEN_SSH=true; shift ;;
    --force) FORCE="--force"; shift ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Validate arguments
if ! [[ $MAXRETRY =~ ^[0-9]+$ ]]; then
  log "ERROR" "None" "Invalid maxretry: $MAXRETRY"
  echo "maxretry must be a number"
  exit 1
fi

# Prompt for confirmation
confirm_prompt "Install Fail2Ban on all servers in servers.txt?" "$FORCE"

# Check servers.txt
check_servers_file

# Initialize counters
success_count=0
failure_count=0

# Fail2Ban configuration
JAIL_CONF="[sshd]\nenabled = true\nmaxretry = $MAXRETRY\nbantime = $BANTIME\nfindtime = $FINDTIME"

# SSH hardening configuration
HARDEN_CONF="PermitRootLogin no\nPasswordAuthentication no"

# Install and configure Fail2Ban in parallel
while read -r server; do
  (
    if check_ssh "$server"; then
      # Check if Fail2Ban is already installed
      if ssh -o ConnectTimeout=5 "$server" "command -v fail2ban-client" >/dev/null 2>&1; then
        log "INFO" "$server" "Fail2Ban already installed, updating configuration"
        echo -e "$JAIL_CONF" | ssh -o ConnectTimeout=5 "$server" "sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null"
        ssh -o ConnectTimeout=5 "$server" "sudo systemctl restart fail2ban"
      else
        # Install Fail2Ban
        output=$(ssh -o ConnectTimeout=5 "$server" "sudo apt update && sudo apt install fail2ban -y && sudo systemctl enable fail2ban && sudo systemctl start fail2ban" 2>&1)
        if [ $? -eq 0 ]; then
          echo -e "$JAIL_CONF" | ssh -o ConnectTimeout=5 "$server" "sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null"
          ssh -o ConnectTimeout=5 "$server" "sudo systemctl restart fail2ban"
          log "INFO" "$server" "Fail2Ban installed and configured"
        else
          log "ERROR" "$server" "Failed to install Fail2Ban: $output"
          ((failure_count++))
          exit 1
        fi
      fi
      # Harden SSH if requested
      if [ "$HARDEN_SSH" = true ]; then
        ssh -o ConnectTimeout=5 "$server" "sudo sed -i '/^PermitRootLogin/c\\$HARDEN_CONF' /etc/ssh/sshd_config && sudo systemctl restart sshd"
        log "INFO" "$server" "SSH hardened: root login and password auth disabled"
      fi
      ((success_count++))
    else
      log "ERROR" "$server" "Cannot connect via SSH"
      ((failure_count++))
    fi
  ) &
done < servers.txt
wait

# Display summary
echo "Summary: $success_count successful, $failure_count failed"
log "INFO" "Summary" "$success_count successful, $failure_count failed"
