#!/bin/bash

# File: scripts/cron_manager.sh
# Description: Manages cron jobs on remote servers listed in servers.txt
# Usage: ./cron_manager.sh <action> [cron_job] [--force] [--help]
#   <action>: list, add <cron_job>, remove <cron_job>
#   --force: Skip confirmation for remove action
#   --help: Show this message
# Requirements: SSH key-based authentication
# Logs: Stored in logs/cron_manager.log

# Source shared functions
source ./lib/lib.sh

# Set log file
LOGFILE="logs/cron_manager.log"

# Function to display usage
usage() {
  echo "Usage: $0 <action> [cron_job] [--force] [--help]"
  echo "  <action>: list, add <cron_job>, remove <cron_job>"
  echo "  --force: Skip confirmation for remove action"
  echo "  --help: Show this message"
  echo "Example: $0 add \"0 0 * * * /backup.sh\" --force"
  exit 1
}

# Validate arguments
if [ $# -lt 1 ]; then
  usage
fi

ACTION=$1
CRON_JOB=""
FORCE=""
shift

while [ $# -gt 0 ]; do
  case $1 in
    --force) FORCE="--force"; shift ;;
    --help) usage ;;
    *) CRON_JOB="$1"; shift ;;
  esac
done

# Check servers.txt
check_servers_file

# Initialize counters
success_count=0
failure_count=0

if [ "$ACTION" = "list" ]; then
  while read -r server; do
    (
      if check_ssh "$server"; then
        echo "Cron jobs for $server:"
        output=$(ssh -o ConnectTimeout=5 "$server" "crontab -l" 2>&1)
        if [ $? -eq 0 ]; then
          echo "$output"
          log "INFO" "$server" "Listed cron jobs"
          ((success_count++))
        else
          log "ERROR" "$server" "Failed to list cron jobs: $output"
          ((failure_count++))
        fi
      else
        log "ERROR" "$server" "Cannot connect via SSH"
        ((failure_count++))
      fi
    ) &
  done < servers.txt
  wait
elif [ "$ACTION" = "add" ]; then
  if [ -z "$CRON_JOB" ]; then
    echo "Cron job required for add action"
    usage
  fi
  while read -r server; do
    (
      if check_ssh "$server"; then
        output=$(ssh -o ConnectTimeout=5 "$server" "crontab -l" 2>/dev/null)
        if echo "$output" | grep -q "^$CRON_JOB$"; then
          log "WARNING" "$server" "Cron job already exists: $CRON_JOB"
          ((success_count++))
        else
          if [ -z "$output" ]; then
            echo "$CRON_JOB" | ssh -o ConnectTimeout=5 "$server" "crontab -" 2>/dev/null
          else
            echo -e "$output\n$CRON_JOB" | ssh -o ConnectTimeout=5 "$server" "crontab -" 2>/dev/null
          fi
          if [ $? -eq 0 ]; then
            log "INFO" "$server" "Added cron job: $CRON_JOB"
            ((success_count++))
          else
            log "ERROR" "$server" "Failed to add cron job: $CRON_JOB"
            ((failure_count++))
          fi
        fi
      else
        log "ERROR" "$server" "Cannot connect via SSH"
        ((failure_count++))
      fi
    ) &
  done < servers.txt
  wait
elif [ "$ACTION" = "remove" ]; then
  if [ -z "$CRON_JOB" ]; then
    echo "Cron job required for remove action"
    usage
  fi
  confirm_prompt "Remove cron job '$CRON_JOB' from all servers?" "$FORCE"
  while read -r server; do
    (
      if check_ssh "$server"; then
        output=$(ssh -o ConnectTimeout=5 "$server" "crontab -l" 2>/dev/null)
        new_cron=$(echo "$output" | grep -v "^$CRON_JOB$")
        if [ "$output" != "$new_cron" ]; then
          echo "$new_cron" | ssh -o ConnectTimeout=5 "$server" "crontab -" 2>/dev/null
          if [ $? -eq 0 ]; then
            log "INFO" "$server" "Removed cron job: $CRON_JOB"
            ((success_count++))
          else
            log "ERROR" "$server" "Failed to remove cron job: $CRON_JOB"
            ((failure_count++))
          fi
        else
          log "WARNING" "$server" "Cron job not found: $CRON_JOB"
          ((success_count++))
        fi
      else
        log "ERROR" "$server" "Cannot connect via SSH"
        ((failure_count++))
      fi
    ) &
  done < servers.txt
  wait
else
  echo "Invalid action: $ACTION"
  usage
fi

# Display summary
echo "Summary: $success_count successful, $failure_count failed"
log "INFO" "Summary" "$success_count successful, $failure_count failed"
