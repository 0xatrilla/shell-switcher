#!/usr/bin/env bash
# shell-manager.sh - Shell lifecycle management
# Handles detection, starting, stopping, and verification of desktop shells

# Source common utilities if not already sourced
if [[ -z "${SHELL_SWITCH_COMMON_SOURCED:-}" ]]; then
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${LIB_DIR}/common.sh"
fi

# Shell database - defines all supported shells
declare -A SHELL_DB

# Initialize shell database
init_shell_db() {
    # Noctalia Shell
    SHELL_DB[noctalia.name]="Noctalia Shell"
    SHELL_DB[noctalia.launch_cmd]="qs -c noctalia-shell"
    SHELL_DB[noctalia.launcher_cmd]="qs -c noctalia-shell ipc call launcher toggle"
    SHELL_DB[noctalia.process_pattern]="qs.*noctalia-shell"
    SHELL_DB[noctalia.packages]="noctalia-shell noctalia-shell-git"
    SHELL_DB[noctalia.id]="noctalia"

    # DMS (Dank Material Shell)
    SHELL_DB[dms.name]="Dank Material Shell"
    SHELL_DB[dms.launch_cmd]="dms run"
    SHELL_DB[dms.launcher_cmd]="dms ipc call spotlight toggle"
    SHELL_DB[dms.process_pattern]="dms run"
    SHELL_DB[dms.packages]="dms-shell dms-shell-bin dms-shell-git"
    SHELL_DB[dms.id]="dms"

    # ii Shell
    SHELL_DB[ii.name]="ii Shell"
    SHELL_DB[ii.launch_cmd]="qs -c ii"
    SHELL_DB[ii.launcher_cmd]="qs -c ii ipc call launcher toggle"
    SHELL_DB[ii.process_pattern]="qs -c ii"
    SHELL_DB[ii.packages]="quickshell ii-shell"
    SHELL_DB[ii.id]="ii"

    # Nucleus Shell
    SHELL_DB[nucleus.name]="Nucleus Shell"
    SHELL_DB[nucleus.launch_cmd]="qs -c nucleus-shell"
    SHELL_DB[nucleus.launcher_cmd]="qs -c nucleus-shell ipc call launcher toggle"
    SHELL_DB[nucleus.process_pattern]="qs -c nucleus-shell"
    SHELL_DB[nucleus.packages]="quickshell nucleus-shell"
    SHELL_DB[nucleus.id]="nucleus"
}

# Initialize on source
init_shell_db

#######################################
# Get shell information from database
# Arguments:
#   $1 - Shell ID (noctalia, dms)
#   $2 - Property name (name, launch_cmd, launcher_cmd, process_pattern, packages)
# Outputs:
#   Property value to stdout
# Returns:
#   0 on success, 1 if shell or property not found
#######################################
get_shell_info() {
    local shell_id="$1"
    local property="$2"
    local key="${shell_id}.${property}"

    if [[ -n "${SHELL_DB[$key]:-}" ]]; then
        echo "${SHELL_DB[$key]}"
        return 0
    else
        log "ERROR" "Shell info not found: $key"
        return 1
    fi
}

#######################################
# Get list of all available shell IDs
# Outputs:
#   Space-separated list of shell IDs to stdout
#######################################
get_all_shells() {
    echo "noctalia dms ii nucleus"
}

#######################################
# Detect which shell is currently running
# Checks running processes against known shell patterns
# Outputs:
#   Shell ID (noctalia, dms) to stdout, or empty if none
# Returns:
#   0 if shell detected, 1 if none running
#######################################
detect_running_shell() {
    local shells
    shells=$(get_all_shells)

    for shell in $shells; do
        local pattern
        pattern=$(get_shell_info "$shell" "process_pattern")

        if pgrep -f "$pattern" &>/dev/null; then
            log "INFO" "Detected running shell: $shell"
            echo "$shell"
            return 0
        fi
    done

    log "WARN" "No shell detected running"
    return 1
}

#######################################
# Check if a specific shell is running
# Arguments:
#   $1 - Shell ID (noctalia, dms)
# Returns:
#   0 if running, 1 if not
#######################################
is_shell_running() {
    local shell_id="$1"
    local pattern
    pattern=$(get_shell_info "$shell_id" "process_pattern")

    if pgrep -f "$pattern" &>/dev/null; then
        log "DEBUG" "Shell $shell_id is running"
        return 0
    else
        log "DEBUG" "Shell $shell_id is not running"
        return 1
    fi
}

#######################################
# Start a desktop shell
# Arguments:
#   $1 - Shell ID (noctalia, dms)
# Returns:
#   0 on success, 1 on failure
#######################################
start_shell() {
    local shell_id="$1"
    local launch_cmd
    launch_cmd=$(get_shell_info "$shell_id" "launch_cmd")
    local shell_name
    shell_name=$(get_shell_info "$shell_id" "name")

    log "INFO" "Starting shell: $shell_name ($launch_cmd)"
    info "Starting $shell_name..."

    # Launch the shell in the background
    if eval "$launch_cmd" &>/dev/null & then
        local pid=$!
        log "INFO" "Started $shell_name with PID $pid"

        # Give it a moment to start
        sleep 0.5

        return 0
    else
        error "Failed to start $shell_name"
        return 1
    fi
}

#######################################
# Stop a desktop shell
# Arguments:
#   $1 - Shell ID (noctalia, dms)
# Returns:
#   0 on success, 1 on failure
#######################################
stop_shell() {
    local shell_id="$1"
    local pattern
    pattern=$(get_shell_info "$shell_id" "process_pattern")
    local shell_name
    shell_name=$(get_shell_info "$shell_id" "name")

    if ! is_shell_running "$shell_id"; then
        log "INFO" "$shell_name is not running, nothing to stop"
        return 0
    fi

    log "INFO" "Stopping shell: $shell_name (pattern: $pattern)"
    info "Stopping $shell_name..."

    # Try graceful termination first
    if pkill -f "$pattern"; then
        log "INFO" "Sent SIGTERM to $shell_name"

        # Wait up to 3 seconds for graceful shutdown
        local timeout=3
        while [[ $timeout -gt 0 ]]; do
            if ! is_shell_running "$shell_id"; then
                success "Stopped $shell_name"
                return 0
            fi
            sleep 0.5
            ((timeout--))
        done

        # If still running, force kill
        warning "$shell_name did not stop gracefully, forcing..."
        if pkill -9 -f "$pattern"; then
            log "WARN" "Force killed $shell_name"
            sleep 0.5

            if ! is_shell_running "$shell_id"; then
                success "Stopped $shell_name (forced)"
                return 0
            fi
        fi
    fi

    error "Failed to stop $shell_name"
    return 1
}

#######################################
# Verify a shell is running (with timeout)
# Arguments:
#   $1 - Shell ID (noctalia, dms)
#   $2 - Timeout in seconds (default: 5)
# Returns:
#   0 if shell is verified running, 1 if not
#######################################
verify_shell_running() {
    local shell_id="$1"
    local timeout="${2:-5}"
    local shell_name
    shell_name=$(get_shell_info "$shell_id" "name")

    log "INFO" "Verifying $shell_name is running (timeout: ${timeout}s)"

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if is_shell_running "$shell_id"; then
            success "$shell_name is running"
            return 0
        fi

        sleep 0.5
        elapsed=$((elapsed + 1))
    done

    error "$shell_name failed to start within ${timeout} seconds"
    return 1
}

#######################################
# Check if a shell package is installed
# Arguments:
#   $1 - Shell ID (noctalia, dms)
# Returns:
#   0 if installed, 1 if not
#######################################
is_shell_installed() {
    local shell_id="$1"
    local packages
    packages=$(get_shell_info "$shell_id" "packages")

    # Check if any of the packages are installed
    for pkg in $packages; do
        if pacman -Q "$pkg" &>/dev/null; then
            log "INFO" "Shell $shell_id is installed (package: $pkg)"
            return 0
        fi
    done

    log "WARN" "Shell $shell_id is not installed"
    return 1
}

#######################################
# Get the installed package name for a shell
# Arguments:
#   $1 - Shell ID (noctalia, dms)
# Outputs:
#   Package name to stdout
# Returns:
#   0 if found, 1 if not installed
#######################################
get_installed_package() {
    local shell_id="$1"
    local packages
    packages=$(get_shell_info "$shell_id" "packages")

    for pkg in $packages; do
        if pacman -Q "$pkg" &>/dev/null; then
            echo "$pkg"
            return 0
        fi
    done

    return 1
}

#######################################
# Switch from one shell to another
# This is the main switching logic with error handling and rollback
# Arguments:
#   $1 - Current shell ID
#   $2 - New shell ID
# Returns:
#   0 on success, 1 on failure
#######################################
switch_shell() {
    local current_shell="$1"
    local new_shell="$2"
    local current_name
    current_name=$(get_shell_info "$current_shell" "name")
    local new_name
    new_name=$(get_shell_info "$new_shell" "name")

    log "INFO" "Switching from $current_name to $new_name"

    # Stop current shell
    if ! stop_shell "$current_shell"; then
        error "Failed to stop $current_name"
        notify "critical" "Shell Switch Failed" "Could not stop $current_name"
        return 1
    fi

    # Start new shell
    if ! start_shell "$new_shell"; then
        error "Failed to start $new_name"
        warning "Attempting to rollback to $current_name"

        # Try to rollback
        if start_shell "$current_shell"; then
            warning "Rolled back to $current_name"
            notify "normal" "Shell Switch Failed" "Rolled back to $current_name"
        else
            error "CRITICAL: Rollback failed! No shell is running"
            notify "critical" "Shell Switch Failed" "CRITICAL: No shell is running!"
        fi

        return 1
    fi

    # Verify new shell is running
    if ! verify_shell_running "$new_shell" 5; then
        error "$new_name failed to start properly"
        warning "Attempting to rollback to $current_name"

        # Kill the failed shell attempt
        stop_shell "$new_shell"

        # Try to rollback
        if start_shell "$current_shell" && verify_shell_running "$current_shell" 5; then
            warning "Rolled back to $current_name"
            notify "normal" "Shell Switch Failed" "Rolled back to $current_name"
        else
            error "CRITICAL: Rollback failed! No shell is running"
            notify "critical" "Shell Switch Failed" "CRITICAL: No shell is running!"
        fi

        return 1
    fi

    success "Successfully switched to $new_name"
    log "INFO" "Shell switch completed successfully: $current_name -> $new_name"

    return 0
}
