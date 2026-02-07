#!/usr/bin/env bash
# compositor.sh - Compositor detection and management
# Handles niri and hyprland compositor detection, config paths, and reloading

# Source common utilities if not already sourced
if [[ -z "${SHELL_SWITCH_COMMON_SOURCED:-}" ]]; then
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${LIB_DIR}/common.sh"
fi

#######################################
# Detect which compositor is currently running
# Checks both $XDG_CURRENT_DESKTOP and running processes
# Outputs:
#   "niri" or "hyprland" to stdout
# Returns:
#   0 if compositor detected, 1 if unknown
#######################################
detect_compositor() {
    local compositor=""

    # First check XDG_CURRENT_DESKTOP environment variable
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        case "${XDG_CURRENT_DESKTOP,,}" in
            niri)
                compositor="niri"
                ;;
            hyprland)
                compositor="hyprland"
                ;;
        esac
    fi

    # If not found, check running processes
    if [[ -z "$compositor" ]]; then
        if pgrep -x "niri" &>/dev/null; then
            compositor="niri"
        elif pgrep -x "Hyprland" &>/dev/null; then
            compositor="hyprland"
        fi
    fi

    if [[ -n "$compositor" ]]; then
        log "INFO" "Detected compositor: $compositor"
        echo "$compositor"
        return 0
    else
        log "ERROR" "Could not detect compositor (niri or hyprland)"
        return 1
    fi
}

#######################################
# Get the main config file path for a compositor
# Arguments:
#   $1 - Compositor name (niri or hyprland)
# Outputs:
#   Config file path to stdout
# Returns:
#   0 if path exists, 1 if not
#######################################
get_config_path() {
    local compositor="$1"
    local config_path=""

    case "$compositor" in
        niri)
            config_path="${HOME}/.config/niri/config.kdl"
            ;;
        hyprland)
            config_path="${HOME}/.config/hypr/hyprland.conf"
            ;;
        *)
            error "Unknown compositor: $compositor"
            return 1
            ;;
    esac

    if [[ -f "$config_path" ]]; then
        log "DEBUG" "Config path for $compositor: $config_path"
        echo "$config_path"
        return 0
    else
        error "Config file not found: $config_path"
        return 1
    fi
}

#######################################
# Get the shell-switcher startup config file path for a compositor
# Arguments:
#   $1 - Compositor name (niri or hyprland)
# Outputs:
#   Startup config file path to stdout
#######################################
get_startup_config_path() {
    local compositor="$1"

    case "$compositor" in
        niri)
            echo "${HOME}/.config/niri/shell-switcher-startup.kdl"
            ;;
        hyprland)
            echo "${HOME}/.config/hypr/shell-switcher-startup.conf"
            ;;
        *)
            error "Unknown compositor: $compositor"
            return 1
            ;;
    esac
}

#######################################
# Get the shell-switcher binds config file path for a compositor
# Arguments:
#   $1 - Compositor name (niri or hyprland)
# Outputs:
#   Binds config file path to stdout
#######################################
get_binds_config_path() {
    local compositor="$1"

    case "$compositor" in
        niri)
            echo "${HOME}/.config/niri/shell-switcher-binds.kdl"
            ;;
        hyprland)
            echo "${HOME}/.config/hypr/shell-switcher-binds.conf"
            ;;
        *)
            error "Unknown compositor: $compositor"
            return 1
            ;;
    esac
}

#######################################
# Reload the compositor configuration
# Arguments:
#   $1 - Compositor name (niri or hyprland)
# Returns:
#   0 on success, 1 on failure
#######################################
reload_compositor() {
    local compositor="$1"

    log "INFO" "Reloading $compositor configuration"

    case "$compositor" in
        niri)
            if command -v niri &>/dev/null; then
                if niri msg action reload-config &>/dev/null; then
                    success "Reloaded niri configuration"
                    return 0
                else
                    error "Failed to reload niri configuration"
                    return 1
                fi
            else
                error "niri command not found"
                return 1
            fi
            ;;
        hyprland)
            if command -v hyprctl &>/dev/null; then
                if hyprctl reload &>/dev/null; then
                    success "Reloaded hyprland configuration"
                    return 0
                else
                    error "Failed to reload hyprland configuration"
                    return 1
                fi
            else
                error "hyprctl command not found"
                return 1
            fi
            ;;
        *)
            error "Unknown compositor: $compositor"
            return 1
            ;;
    esac
}

#######################################
# Validate compositor config syntax (if possible)
# Arguments:
#   $1 - Compositor name (niri or hyprland)
# Returns:
#   0 if valid or validation not available, 1 if invalid
#######################################
validate_compositor_config() {
    local compositor="$1"

    log "INFO" "Validating $compositor configuration"

    case "$compositor" in
        niri)
            # niri doesn't have a built-in config validator
            # We just check if the config file is readable
            local config_path
            config_path=$(get_config_path "$compositor")
            if [[ -r "$config_path" ]]; then
                log "INFO" "niri config file is readable"
                return 0
            else
                error "niri config file is not readable: $config_path"
                return 1
            fi
            ;;
        hyprland)
            # hyprland also doesn't have a standalone validator
            # Check if config is readable
            local config_path
            config_path=$(get_config_path "$compositor")
            if [[ -r "$config_path" ]]; then
                log "INFO" "hyprland config file is readable"
                return 0
            else
                error "hyprland config file is not readable: $config_path"
                return 1
            fi
            ;;
        *)
            error "Unknown compositor: $compositor"
            return 1
            ;;
    esac
}

#######################################
# Check if include/source statement exists in compositor config
# Arguments:
#   $1 - Compositor name (niri or hyprland)
#   $2 - File to check for (basename only)
# Returns:
#   0 if exists, 1 if not
#######################################
has_include_statement() {
    local compositor="$1"
    local file_basename="$2"
    local config_path
    config_path=$(get_config_path "$compositor")

    case "$compositor" in
        niri)
            if grep -q "^[[:space:]]*include[[:space:]]*\"${file_basename}\"" "$config_path"; then
                return 0
            fi
            ;;
        hyprland)
            if grep -q "^[[:space:]]*source[[:space:]]*=.*${file_basename}" "$config_path"; then
                return 0
            fi
            ;;
        *)
            return 1
            ;;
    esac

    return 1
}

#######################################
# Add include/source statement to compositor config
# Arguments:
#   $1 - Compositor name (niri or hyprland)
#   $2 - File to include (basename only)
# Returns:
#   0 on success, 1 on failure
#######################################
add_include_statement() {
    local compositor="$1"
    local file_basename="$2"
    local config_path
    config_path=$(get_config_path "$compositor")

    # Check if already included
    if has_include_statement "$compositor" "$file_basename"; then
        log "INFO" "$file_basename already included in $compositor config"
        return 0
    fi

    # Backup the config first
    if ! backup_file "$config_path"; then
        error "Failed to backup config before adding include"
        return 1
    fi

    case "$compositor" in
        niri)
            echo "" >> "$config_path"
            echo "// Shell Switcher - Auto-generated include" >> "$config_path"
            echo "include \"${file_basename}\"" >> "$config_path"
            success "Added include statement for $file_basename to niri config"
            log "INFO" "Added niri include: $file_basename"
            return 0
            ;;
        hyprland)
            echo "" >> "$config_path"
            echo "# Shell Switcher - Auto-generated source" >> "$config_path"
            echo "source = ~/.config/hypr/${file_basename}" >> "$config_path"
            success "Added source statement for $file_basename to hyprland config"
            log "INFO" "Added hyprland source: $file_basename"
            return 0
            ;;
        *)
            error "Unknown compositor: $compositor"
            return 1
            ;;
    esac
}

#######################################
# Get the config directory for a compositor
# Arguments:
#   $1 - Compositor name (niri or hyprland)
# Outputs:
#   Config directory path to stdout
#######################################
get_config_dir() {
    local compositor="$1"

    case "$compositor" in
        niri)
            echo "${HOME}/.config/niri"
            ;;
        hyprland)
            echo "${HOME}/.config/hypr"
            ;;
        *)
            error "Unknown compositor: $compositor"
            return 1
            ;;
    esac
}
