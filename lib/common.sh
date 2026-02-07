#!/usr/bin/env bash
# common.sh - Shared utility functions for shell-switch
# Provides logging, notifications, colors, confirmations, backups, and dependency checks

# Prevent double-sourcing
[[ -n "${SHELL_SWITCH_COMMON_SOURCED:-}" ]] && return 0
readonly SHELL_SWITCH_COMMON_SOURCED=1

# Color codes for terminal output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Icons for better visual feedback
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✗"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_ACTIVE="●"
readonly ICON_INACTIVE="○"

# Global paths
readonly SHELL_SWITCH_DIR="${HOME}/.config/shell-switch"
readonly LOG_FILE="${SHELL_SWITCH_DIR}/shell-switch.log"
readonly BACKUP_DIR="${SHELL_SWITCH_DIR}/backups"
readonly SHELL_SWITCH_CONFIG="${SHELL_SWITCH_DIR}/config.json"

# Maximum number of backups to keep
readonly MAX_BACKUPS=5

#######################################
# Log a message to the log file with timestamp
# Arguments:
#   $1 - Log level (INFO, WARN, ERROR, DEBUG)
#   $2+ - Message to log
# Outputs:
#   Appends to LOG_FILE
#######################################
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

#######################################
# Send a desktop notification
# Arguments:
#   $1 - Urgency (low, normal, critical)
#   $2 - Summary
#   $3 - Body (optional)
# Outputs:
#   Desktop notification if notify-send is available
#######################################
notify() {
    local urgency="$1"
    local summary="$2"
    local body="${3:-}"

    if command -v notify-send &>/dev/null; then
        if [[ -n "$body" ]]; then
            notify-send -u "$urgency" -a "Shell Switcher" "$summary" "$body"
        else
            notify-send -u "$urgency" -a "Shell Switcher" "$summary"
        fi
        log "INFO" "Notification sent: $summary"
    else
        log "WARN" "notify-send not available, skipping notification"
    fi
}

#######################################
# Print colorized output to terminal
# Arguments:
#   $1 - Color (red, green, yellow, blue, magenta, cyan, or empty for reset)
#   $2+ - Message to print
# Outputs:
#   Colorized message to stdout
#######################################
color_echo() {
    local color="$1"
    shift
    local message="$*"

    case "$color" in
        red)     echo -e "${COLOR_RED}${message}${COLOR_RESET}" ;;
        green)   echo -e "${COLOR_GREEN}${message}${COLOR_RESET}" ;;
        yellow)  echo -e "${COLOR_YELLOW}${message}${COLOR_RESET}" ;;
        blue)    echo -e "${COLOR_BLUE}${message}${COLOR_RESET}" ;;
        magenta) echo -e "${COLOR_MAGENTA}${message}${COLOR_RESET}" ;;
        cyan)    echo -e "${COLOR_CYAN}${message}${COLOR_RESET}" ;;
        *)       echo -e "${message}" ;;
    esac
}

#######################################
# Print a success message
# Arguments:
#   $1+ - Message to print
# Outputs:
#   Green success message with checkmark
#######################################
success() {
    color_echo green "${ICON_SUCCESS} $*"
    log "INFO" "SUCCESS: $*"
}

#######################################
# Print an error message
# Arguments:
#   $1+ - Message to print
# Outputs:
#   Red error message with X mark
#######################################
error() {
    color_echo red "${ICON_ERROR} $*"
    log "ERROR" "$*"
}

#######################################
# Print a warning message
# Arguments:
#   $1+ - Message to print
# Outputs:
#   Yellow warning message with warning icon
#######################################
warning() {
    color_echo yellow "${ICON_WARNING} $*"
    log "WARN" "$*"
}

#######################################
# Print an info message
# Arguments:
#   $1+ - Message to print
# Outputs:
#   Cyan info message with info icon
#######################################
info() {
    color_echo cyan "${ICON_INFO} $*"
    log "INFO" "$*"
}

#######################################
# Prompt user for yes/no confirmation
# Arguments:
#   $1 - Prompt message
#   $2 - Default response (y/n), optional
# Returns:
#   0 if yes, 1 if no
#######################################
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        prompt="${prompt} [Y/n]: "
    else
        prompt="${prompt} [y/N]: "
    fi

    read -r -p "$prompt" response
    response="${response:-$default}"

    case "$response" in
        [yY]|[yY][eE][sS])
            log "INFO" "User confirmed: $1"
            return 0
            ;;
        *)
            log "INFO" "User declined: $1"
            return 1
            ;;
    esac
}

#######################################
# Create a timestamped backup of a file
# Arguments:
#   $1 - File path to backup
# Outputs:
#   Backup file in BACKUP_DIR
# Returns:
#   0 on success, 1 on failure
#######################################
backup_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log "WARN" "Cannot backup $file: file does not exist"
        return 1
    fi

    local filename
    filename="$(basename "$file")"
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local backup_path="${BACKUP_DIR}/${filename}.${timestamp}.bak"

    if cp "$file" "$backup_path"; then
        log "INFO" "Backed up $file to $backup_path"

        # Clean up old backups, keeping only MAX_BACKUPS
        cleanup_old_backups "$filename"

        return 0
    else
        error "Failed to backup $file"
        return 1
    fi
}

#######################################
# Clean up old backup files, keeping only the most recent MAX_BACKUPS
# Arguments:
#   $1 - Base filename pattern to match
# Outputs:
#   Removes old backup files
#######################################
cleanup_old_backups() {
    local pattern="$1"
    local backup_count

    # Count backups matching the pattern
    backup_count=$(find "$BACKUP_DIR" -name "${pattern}.*.bak" -type f | wc -l)

    if [[ $backup_count -gt $MAX_BACKUPS ]]; then
        local to_delete=$((backup_count - MAX_BACKUPS))
        log "INFO" "Cleaning up $to_delete old backup(s) for $pattern"

        # Delete oldest backups
        find "$BACKUP_DIR" -name "${pattern}.*.bak" -type f -printf '%T+ %p\n' | \
            sort | \
            head -n "$to_delete" | \
            cut -d' ' -f2- | \
            xargs rm -f
    fi
}

#######################################
# Restore a file from the most recent backup
# Arguments:
#   $1 - Original file path
# Returns:
#   0 on success, 1 on failure
#######################################
restore_backup() {
    local file="$1"
    local filename
    filename="$(basename "$file")"

    # Find the most recent backup
    local latest_backup
    latest_backup=$(find "$BACKUP_DIR" -name "${filename}.*.bak" -type f -printf '%T+ %p\n' | \
        sort -r | \
        head -n 1 | \
        cut -d' ' -f2-)

    if [[ -z "$latest_backup" ]]; then
        error "No backup found for $file"
        return 1
    fi

    if cp "$latest_backup" "$file"; then
        success "Restored $file from backup"
        log "INFO" "Restored $file from $latest_backup"
        return 0
    else
        error "Failed to restore $file from backup"
        return 1
    fi
}

#######################################
# Check if a command/dependency exists
# Arguments:
#   $1 - Command name
# Returns:
#   0 if exists, 1 if not
#######################################
check_dependency() {
    local cmd="$1"

    if command -v "$cmd" &>/dev/null; then
        log "DEBUG" "Dependency check: $cmd found"
        return 0
    else
        log "WARN" "Dependency check: $cmd not found"
        return 1
    fi
}

#######################################
# Ensure all required dependencies are installed
# Arguments:
#   $@ - List of required commands
# Returns:
#   0 if all found, 1 if any missing
# Outputs:
#   Error messages for missing dependencies
#######################################
require_dependencies() {
    local missing=()

    for cmd in "$@"; do
        if ! check_dependency "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

#######################################
# Initialize the shell-switch environment
# Creates necessary directories and log file
# Returns:
#   0 on success
#######################################
init_environment() {
    # Create directories if they don't exist
    mkdir -p "$SHELL_SWITCH_DIR"
    mkdir -p "$BACKUP_DIR"

    # Create log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        log "INFO" "Initialized shell-switch environment"
    fi

    return 0
}

# Initialize environment on source
init_environment
