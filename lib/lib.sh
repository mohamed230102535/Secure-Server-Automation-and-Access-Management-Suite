#!/bin/bash

# File: lib/lib.sh
# Description: Shared functions for the Secure Server Automation Suite
# Usage: Source this file in other scripts with `source ./lib/lib.sh`

# Default log file (can be overridden by scripts)
LOGFILE="logs/default.log"
MAX_LOG_SIZE=1048576  # 1MB in bytes

# Function to rotate logs if size exceeds MAX_LOG_SIZE
rotate_log() {
  if [ -f "$LOGFILE" ] && [ $(stat -c%s "$LOGFILE") -ge $MAX_LOG_SIZE ]; then
    mv "$LOGFILE" "$LOGFILE.$(date +%Y%m%d%H%M%S)"
  fi
}

# Function to log messages with levels (INFO, ERROR, WARNING)
# Usage: log <level> <server> <message>
log() {
  local level=$1
  local server=$2
  local message=$3
  rotate_log
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $level - $server - $message" >> "$LOGFILE"
  case $level in
    INFO) echo -e "\033[32m[INFO]\033[0m $server: $message" ;;
    ERROR) echo -e "\033[31m[ERROR]\033[0m $server: $message" ;;
    WARNING) echo -e "\033[33m[WARNING]\033[0m $server: $message" ;;
  esac
}

# Function to check if servers.txt exists
# Usage: check_servers_file
check_servers_file() {
  if [ ! -f servers.txt ]; then
    log "ERROR" "None" "servers.txt not found"
    echo "servers.txt not found"
    exit 1
  fi
}

# Function to check SSH connectivity
# Usage: check_ssh <server>
# Returns: 0 if successful, 1 if failed
check_ssh() {
  local server=$1
  if ssh -o ConnectTimeout=5 "$server" true 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Function to prompt for confirmation
# Usage: confirm_prompt <message> <force_flag>
# Exits if user does not confirm unless force_flag is "--force"
confirm_prompt() {
  local message=$1
  local force_flag=$2
  if [ "$force_flag" != "--force" ]; then
    read -p "$message [y/N] " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
      echo "Operation cancelled"
      exit 0
    fi
  fi
}
