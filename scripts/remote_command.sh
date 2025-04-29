#!/bin/bash

# File: scripts/remote_command.sh
# Description: Executes a command on remote servers listed in servers.txt
# Usage: ./remote_command.sh "<command>" [--force] [--help]
#   --force: Skip confirmation prompt
#   --help: Show this message
# Example: ./remote_command.sh "uptime" --force
# Requirements: SSH key-based authentication
# Logs: Stored in logs/remote_command.log

# Source shared functions
source ./lib/lib.sh

# Set log file
LOGFILE="logs/remote_command.log"

# Function to display usage
usage() {
  echo "Usage: $0 \"<command>\" [--force] [--help]"
  echo "  --force: Skip confirmation prompt"
  echo "  --help: Show this message"
  exit 1
}

# Validate arguments
if [ $# -lt 1 ]; then
  usage
fi

COMMAND=$1
FORCE=""
shift

while [ $# -gt 0 ]; do
  case $1 in
    --force) FORCE="--force"; shift ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Prompt for confirmation
confirm_prompt "Execute '$COMMAND' on all servers?" "$FORCE"

# Check servers.txt
check_servers_file

# Initialize counters
success_count=0
failure_count=0

# Execute command in parallel
while read -r server; do
  (
    if check_ssh "$server"; then
      echo "Output from $server:"
      output=$(ssh -o ConnectTimeout=5 "$server" "$COMMAND" 2>&1)
      if [ $? -eq 0 ]; then
        echo "$output"
        log "INFO" "$server" "Executed command: $COMMAND"
        ((success_count++))
      else
        log "ERROR" "$server" "Failed to execute command: $output"
        ((failure_count++))
      fi
      echo ""
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
