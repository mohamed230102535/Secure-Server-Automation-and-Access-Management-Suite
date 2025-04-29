# Secure Server Automation and Access Management Suite

This Bash-based project automates server management and enhances security across multiple Linux servers on Ubuntu 22.04 LTS or similar Debian-based distributions.

## Directory Structure
- `lib/`: Shared functions (`lib.sh`).
- `logs/`: Log files (e.g., `fail2ban_setup.log`).
- `scripts/`: Executable scripts:
  - `fail2ban_setup.sh`
  - `cron_manager.sh`
  - `password_generator.sh`
  - `remote_command.sh`
  - `server_health.sh`
  - `menu.sh`
- `servers.txt`: List of remote servers.
- `README.md`: This documentation.

## Setup Instructions
1. **Configure SSH Keys**:
   - Generate: `ssh-keygen -t rsa`
   - Copy to servers: `ssh-copy-id user@host`
   - Ensure sudo without password for `fail2ban_setup.sh` (add `user ALL=(ALL) NOPASSWD:ALL` to `/etc/sudoers`).
2. **Edit servers.txt**:
   - Format: `user@host` per line.
3. **Set Permissions**:
   - `chmod +x scripts/*.sh`
4. **Run Scripts**:
   - From project root (e.g., `./scripts/menu.sh`).

## Scripts
1. **fail2ban_setup.sh**
   - Installs/configures Fail2Ban with customizable settings.
   - Usage: `./scripts/fail2ban_setup.sh [--maxretry <num>] [--bantime <time>] [--findtime <time>] [--harden-ssh] [--force]`
   - Example: `./scripts/fail2ban_setup.sh --maxretry 3 --harden-ssh`
   - Features: Parallel execution, skips existing installations, SSH hardening.

2. **cron_manager.sh**
   - Manages cron jobs (list, add, remove).
   - Usage: `./scripts/cron_manager.sh <action> [cron_job] [--force]`
   - Example: `./scripts/cron_manager.sh add "0 0 * * * /backup.sh"`
   - Features: Parallel execution, confirmation for removal.

3. **password_generator.sh**
   - Generates secure passwords.
   - Usage: `./scripts/password_generator.sh <length> [number] [--alphanum|--symbols|--hex] [--output <file>]`
   - Example: `./scripts/password_generator.sh 16 3 --symbols --output passwords.txt`
   - Features: Custom character sets, file output.

4. **remote_command.sh**
   - Executes commands on servers.
   - Usage: `./scripts/remote_command.sh "<command>" [--force]`
   - Example: `./scripts/remote_command.sh "uptime"`
   - Features: Parallel execution, confirmation prompt.

5. **server_health.sh**
   - Checks disk, CPU, memory, and uptime.
   - Usage: `./scripts/server_health.sh`
   - Example Output:
     ```
     Health report for admin@server1:
     Disk usage: 50%
     CPU load: 0.5
     Memory usage: 60%
     Uptime: up 1 day
     ```
   - Features: Parallel execution, threshold warnings.

6. **menu.sh**
   - Interactive menu to run scripts.
   - Usage: `./scripts/menu.sh`
   - Features: `select`-based interface.

## New Features
- **Parallel SSH**: Operations run concurrently using background subshells, improving performance.
- **Logging**: Rotates logs at 1MB, uses INFO/ERROR/WARNING levels, and color-coded terminal output.
- **Error Reporting**: Summarizes successes/failures and captures SSH errors.
- **Hardening**: Option to disable root login and password authentication.
- **Flags**: `--force`, `--output`, `--alphanum`, etc., for flexibility.

## Requirements
- SSH key-based authentication.
- Sudo without password for `fail2ban_setup.sh`.
- Run scripts from project root.

## Logs
- Stored in `logs/` with format: `YYYY-MM-DD HH:MM:SS - LEVEL - SERVER - MESSAGE`.
- Rotated when exceeding 1MB.

## Example Outputs
- **remote_command.sh**:
  ```
  Output from admin@server1:
  10:00:00 up 1 day
  Summary: 1 successful, 0 failed
  ```
- **server_health.sh**:
  ```
  Health report for admin@server1:
  Disk usage: 50%
  CPU load: 0.5
  Memory usage: 60%
  Uptime: up 1 day
  ```

## Known Limitations
- Requires passwordless SSH and sudo for some operations.
- Exact cron job matching needed for removal.
- Assumes reliable network connectivity.
- Hardening changes may lock out users if not tested.

## Compatibility
Designed for Ubuntu 22.04 LTS, compatible with Debian-based distributions.
