#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOG_DIR="/opt/secure-server-suite/logs"
LOG_FILE="$LOG_DIR/password_generator_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Default values
length=16
count=1
use_symbols=true
use_numbers=true
log_file=""
copy_to_clipboard=false

# Check if pwgen is installed, else fallback to openssl
use_pwgen=false
if command -v pwgen &>/dev/null; then
    use_pwgen=true
fi

usage() {
    echo -e "${YELLOW}Usage: $0 [-l length] [-n count] [-s (disable symbols)] [-d (disable numbers)] [-c (copy to clipboard)] [-o output_file]${NC}"
    echo "  -l LENGTH       Length of password (default: 16)"
    echo "  -n COUNT        Number of passwords to generate (default: 1)"
    echo "  -s              Disable symbols"
    echo "  -d              Disable numbers"
    echo "  -c              Copy last password to clipboard (requires xclip)"
    echo "  -o FILE         Output log file"
    exit 1
}

while getopts "l:n:sdo:c" opt; do
    case "$opt" in
        l) length="$OPTARG" ;;
        n) count="$OPTARG" ;;
        s) use_symbols=false ;;
        d) use_numbers=false ;;
        o) log_file="$OPTARG" ;;
        c) copy_to_clipboard=true ;;
        *) usage ;;
    esac
done

generate_password() {
    if $use_pwgen; then
        pwgen_opts="-1"
        $use_symbols && pwgen_opts="$pwgen_opts -y"
        $use_numbers && pwgen_opts="$pwgen_opts -n"
        pwgen $pwgen_opts $length
    else
        charset="A-Za-z"
        $use_numbers && charset="${charset}0-9"
        $use_symbols && charset="${charset}!@#$%^&*_+"
        tr -dc "$charset" </dev/urandom | head -c "$length"
        echo
    fi
}

log "${GREEN}Generating $count password(s) of length $length...${NC}"

for ((i = 1; i <= count; i++)); do
    password=$(generate_password)
    log "[${i}] $password"
    [[ -n "$log_file" ]] && echo "$password" >>"$log_file"
done

if $copy_to_clipboard; then
    if command -v xclip &>/dev/null; then
        echo -n "$password" | xclip -selection clipboard
        log "${GREEN}Password copied to clipboard!${NC}"
    else
        log "${RED}xclip not installed; cannot copy to clipboard.${NC}"
    fi
fi
