#!/bin/bash

# File: scripts/server_health.sh
# Description: Checks disk space, CPU load, memory usage, and uptime on remote servers
# Usage: ./server_health.sh [--help]
#   --help: Show this message
# Thresholds:
#   Disk usage > 80%
#   CPU load > number of CPUs
#   Memory usage > 90%
# Requirements: SSH key-based authentication
# Logs: Stored in logs/server_health.log

# Source shared functions
source ./lib/lib.sh

# Set log file
LOGFILE="logs/server_health.log"

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

# Check servers.txt
check_servers_file

# Initialize counters
success_count=0
failure_count=0

# Check health in parallel
while read -r server; do
  (
    if check_ssh "$server"; then
      echo "Health report for $server:"
      # Disk usage
      disk_usage=$(ssh -o ConnectTimeout=5 "$server" "df -h / | tail -1 | awk '{print \$5}' | tr -d '%'" 2>/dev/null)
      if [ $? -eq 0 ]; then
        echo "Disk usage: ${disk_usage}%"
        [ "$disk_usage" -gt 80 ] && log "WARNING" "$server" "High disk usage: ${disk_usage}%"
      fi
      # CPU load
      cpu_load=$(ssh -o ConnectTimeout=5 "$server" "uptime | awk '{print \$(NF-2)}' | tr -d ','" 2>/dev/null)
      cpu_count=$(ssh -o ConnectTimeout=5 "$server" "nproc" 2>/dev/null)
      if [ -n "$cpu_load" ] && [ -n "$cpu_count" ]; then
        echo "CPU load: $cpu_load"
        if (( $(echo "$cpu_load > $cpu_count" | bc -l) )); then
          log "WARNING" "$server" "High CPU load: $cpu_load"
        fi
      fi
      # Memory usage
      mem_info=$(ssh -o ConnectTimeout=5 "$server" "free | grep Mem | awk '{print \$3/\$2 * 100}'" 2>/dev/null)
      if [ -n "$mem_info" ]; then
        mem_usage=$(printf "%.0f" "$mem_info")
        echo "Memory usage: ${mem_usage}%"
        [ "$mem_usage" -gt 90 ] && log "WARNING" "$server" "High memory usage: ${mem_usage}%"
      fi
      # Uptime
      uptime=$(ssh -o ConnectTimeout=5 "$server" "uptime -p" 2>/dev/null)
      if [ $? -eq 0 ]; then
        echo "Uptime: $uptime"
      fi
      log "INFO" "$server" "Health check completed"
      ((success_count++))
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
