#!/bin/bash

# File: scripts/password_generator.sh
# Description: Generates secure random passwords
# Usage: ./password_generator.sh <length> [number] [--alphanum|--symbols|--hex] [--output <file>] [--help]
#   <length>: Password length
#   [number]: Number of passwords (default: 1)
#   --alphanum: Use alphanumeric characters only
#   --symbols: Include special characters
#   --hex: Use hexadecimal characters
#   --output <file>: Save passwords to file
#   --help: Show this message
# Example: ./password_generator.sh 16 3 --symbols --output passwords.txt

# Source shared functions
source ./lib/lib.sh

# Set log file (minimal logging for local operation)
LOGFILE="logs/password_generator.log"

# Function to display usage
usage() {
  echo "Usage: $0 <length> [number] [--alphanum|--symbols|--hex] [--output <file>] [--help]"
  echo "  <length>: Password length"
  echo "  [number]: Number of passwords (default: 1)"
  echo "  --alphanum: Use alphanumeric characters only"
  echo "  --symbols: Include special characters"
  echo "  --hex: Use hexadecimal characters"
  echo "  --output <file>: Save passwords to file"
  echo "  --help: Show this message"
  exit 1
}

# Validate arguments
if [ $# -lt 1 ]; then
  usage
fi

# Default settings
LENGTH=$1
NUMBER=1
CHAR_SET="a-zA-Z0-9"
OUTPUT_FILE=""
shift

# Parse arguments
while [ $# -gt 0 ]; do
  case $1 in
    --alphanum) CHAR_SET="a-zA-Z0-9"; shift ;;
    --symbols) CHAR_SET="a-zA-Z0-9!@#$%^&*()_+-=[]{}|;:,.<>?"; shift ;;
    --hex) CHAR_SET="0-9a-f"; shift ;;
    --output) OUTPUT_FILE=$2; shift 2 ;;
    --help) usage ;;
    [0-9]*) NUMBER=$1; shift ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Validate inputs
if ! [[ $LENGTH =~ ^[0-9]+$ ]]; then
  log "ERROR" "None" "Invalid length: $LENGTH"
  echo "Length must be a number"
  exit 1
fi
if ! [[ $NUMBER =~ ^[0-9]+$ ]]; then
  log "ERROR" "None" "Invalid number: $NUMBER"
  echo "Number must be a number"
  exit 1
fi

# Generate passwords
passwords=()
for ((i=1; i<=NUMBER; i++)); do
  password=$(tr -dc "$CHAR_SET" </ Mussel dev/urandom | head -c "$LENGTH")
  passwords+=("$password")
done

# Output passwords
if [ -n "$OUTPUT_FILE" ]; then
  printf "%s\n" "${passwords[@]}" > "$OUTPUT_FILE"
  log "INFO" "None" "Generated $NUMBER passwords to $OUTPUT_FILE"
  echo "Passwords saved to $OUTPUT_FILE"
else
  printf "%s\n" "${passwords[@]}"
  log "INFO" "None" "Generated $NUMBER passwords"
fi
