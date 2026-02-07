#!/usr/bin/env bash
# install.sh - Installation script for shell-switch
# Detects environment, installs dependencies, and sets up configuration

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/compositor.sh"
source "${SCRIPT_DIR}/lib/shell-manager.sh"

# Installation paths
INSTALL_BIN="${HOME}/.local/bin/shell-switch"
CONFIG_FILE="${SHELL_SWITCH_DIR}/config.json"

#######################################
# Print installation banner
#######################################
print_banner() {
    echo ""
    color_echo cyan "╔═══════════════════════════════════════════╗"
    color_echo cyan "║     Shell Switcher Installation          ║"
    color_echo cyan "║     TUI for Noctalia & DMS                ║"
    color_echo cyan "╚═══════════════════════════════════════════╝"
    echo ""
}

#######################################
# Detect and verify AUR helper
# Outputs:
#   AUR helper command (yay or paru) to stdout
# Returns:
#   0 on success, 1 if none found
#######################################
detect_aur_helper() {
    info "Checking for AUR helper..."

    if command -v yay &>/dev/null; then
        success "Found AUR helper: yay"
        echo "yay"
        return 0
    elif command -v paru &>/dev/null; then
        success "Found AUR helper: paru"
        echo "paru"
        return 0
    else
        error "No AUR helper found (yay or paru)"
        error "Please install an AUR helper and run this script again"
        error ""
        error "Install yay: https://github.com/Jguer/yay#installation"
        error "Install paru: https://github.com/Morganamilo/paru#installation"
        return 1
    fi
}

#######################################
# Check and install required dependencies
# Arguments:
#   $1 - AUR helper command
# Returns:
#   0 on success, 1 on failure
#######################################
check_dependencies() {
    local aur_helper="$1"

    info "Checking dependencies..."

    local missing_deps=()

    # Check for fzf
    if ! command -v fzf &>/dev/null; then
        warning "fzf is not installed"
        missing_deps+=("fzf")
    fi

    # Check for jq
    if ! command -v jq &>/dev/null; then
        warning "jq is not installed"
        missing_deps+=("jq")
    fi

    # Install missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo ""
        info "Installing missing dependencies: ${missing_deps[*]}"

        if confirm "Install ${missing_deps[*]} using $aur_helper?" "y"; then
            if sudo pacman -S --needed "${missing_deps[@]}"; then
                success "Dependencies installed successfully"
            else
                error "Failed to install dependencies"
                return 1
            fi
        else
            error "Cannot proceed without required dependencies"
            return 1
        fi
    else
        success "All dependencies are installed"
    fi

    return 0
}

#######################################
# Check and install desktop shells
# Arguments:
#   $1 - AUR helper command
# Returns:
#   0 on success
#######################################
check_shells() {
    local aur_helper="$1"

    info "Checking installed desktop shells..."

    local noctalia_installed=false
    local dms_installed=false

    if is_shell_installed "noctalia"; then
        local pkg
        pkg=$(get_installed_package "noctalia")
        success "Noctalia Shell is installed ($pkg)"
        noctalia_installed=true
    else
        warning "Noctalia Shell is not installed"
    fi

    if is_shell_installed "dms"; then
        local pkg
        pkg=$(get_installed_package "dms")
        success "DMS (Dank Material Shell) is installed ($pkg)"
        dms_installed=true
    fi

    # Offer to install missing shells
    if ! $noctalia_installed; then
        echo ""
        if confirm "Install Noctalia Shell from AUR?" "y"; then
            info "Installing noctalia-shell-git..."
            if $aur_helper -S --needed noctalia-shell-git; then
                success "Noctalia Shell installed successfully"
                noctalia_installed=true
            else
                warning "Failed to install Noctalia Shell (continuing anyway)"
            fi
        fi
    fi

    if ! $dms_installed; then
        echo ""
        if confirm "Install DMS (Dank Material Shell) from AUR?" "y"; then
            info "Installing dms-shell-git..."
            if $aur_helper -S --needed dms-shell-git; then
                success "DMS installed successfully"
                dms_installed=true
            else
                warning "Failed to install DMS (continuing anyway)"
            fi
        fi
    fi

    # Warn if no shells installed
    if ! $noctalia_installed && ! $dms_installed; then
        error "No desktop shells are installed!"
        error "You need at least one shell to use the switcher"
        return 1
    fi

    return 0
}

#######################################
# Detect current running shell
# Outputs:
#   Shell ID to stdout
# Returns:
#   0 on success, 1 if none detected
#######################################
detect_current_shell() {
    info "Detecting current running shell..." >&2

    local shell_id
    if shell_id=$(detect_running_shell 2>/dev/null); then
        local shell_name
        shell_name=$(get_shell_info "$shell_id" "name")
        success "Detected running shell: $shell_name" >&2
        echo "$shell_id"
        return 0
    else
        warning "No shell detected running" >&2

        # Prompt user to select
        echo "" >&2
        info "Please select your preferred shell:" >&2

        local shells
        shells=$(get_all_shells)
        local options=()
        local i=1

        for shell in $shells; do
            if is_shell_installed "$shell"; then
                local name
                name=$(get_shell_info "$shell" "name")
                options+=("$i" "$name")
                ((i++))
            fi
        done

        if [[ ${#options[@]} -eq 0 ]]; then
            error "No shells available to select"
            return 1
        fi

        # Simple menu selection
        PS3="Enter selection (1-$((i-1))): "
        select choice in "${options[@]}"; do
            if [[ -n "$choice" ]]; then
                # Find shell ID from name
                for shell in $shells; do
                    local name
                    name=$(get_shell_info "$shell" "name")
                    if [[ "$name" == "$choice" ]]; then
                        echo "$shell"
                        return 0
                    fi
                done
            fi
        done

        return 1
    fi
}

#######################################
# Create initial config.json
# Arguments:
#   $1 - Compositor name
#   $2 - Initial shell ID
# Returns:
#   0 on success, 1 on failure
#######################################
create_config() {
    local compositor="$1"
    local initial_shell="$2"

    info "Creating configuration file..."

    local noctalia_pkg=""
    local dms_pkg=""

    if is_shell_installed "noctalia"; then
        noctalia_pkg=$(get_installed_package "noctalia")
    fi

    if is_shell_installed "dms"; then
        dms_pkg=$(get_installed_package "dms")
    fi

    cat > "$CONFIG_FILE" <<EOF
{
  "version": "1.0",
  "current_shell": "${initial_shell}",
  "compositor": "${compositor}",
  "config_paths": {
    "niri": {
      "main": "${HOME}/.config/niri/config.kdl",
      "startup": "${HOME}/.config/niri/shell-switcher-startup.kdl",
      "binds": "${HOME}/.config/niri/shell-switcher-binds.kdl"
    },
    "hyprland": {
      "main": "${HOME}/.config/hypr/hyprland.conf",
      "startup": "${HOME}/.config/hypr/shell-switcher-startup.conf",
      "binds": "${HOME}/.config/hypr/shell-switcher-binds.conf"
    }
  },
  "shells": {
    "noctalia": {
      "name": "Noctalia Shell",
      "installed": $(is_shell_installed "noctalia" && echo "true" || echo "false"),
      "package": "${noctalia_pkg}"
    },
    "dms": {
      "name": "Dank Material Shell",
      "installed": $(is_shell_installed "dms" && echo "true" || echo "false"),
      "package": "${dms_pkg}"
    }
  },
  "last_switch": "$(date -Iseconds)",
  "switch_count": 0
}
EOF

    if [[ $? -eq 0 ]]; then
        success "Created config file: $CONFIG_FILE"
        return 0
    else
        error "Failed to create config file"
        return 1
    fi
}

#######################################
# Generate compositor config files from templates
# Arguments:
#   $1 - Compositor name
#   $2 - Shell ID
# Returns:
#   0 on success, 1 on failure
#######################################
generate_compositor_configs() {
    local compositor="$1"
    local shell_id="$2"

    info "Generating compositor configuration files..."

    local startup_config
    startup_config=$(get_startup_config_path "$compositor")
    local binds_config
    binds_config=$(get_binds_config_path "$compositor")

    local shell_name
    shell_name=$(get_shell_info "$shell_id" "name")
    local launch_cmd
    launch_cmd=$(get_shell_info "$shell_id" "launch_cmd")
    local launcher_cmd
    launcher_cmd=$(get_shell_info "$shell_id" "launcher_cmd")

    # For KDL files, format commands as quoted arguments
    local launch_cmd_args
    local launcher_cmd_args
    launch_cmd_args=$(echo "$launch_cmd" | awk '{for(i=1;i<=NF;i++) printf "\"%s\" ", $i}' | sed 's/ $//')
    launcher_cmd_args=$(echo "$launcher_cmd" | awk '{for(i=1;i<=NF;i++) printf "\"%s\" ", $i}' | sed 's/ $//')

    local template_dir="${SCRIPT_DIR}/templates/${compositor}"

    # Generate startup config
    if [[ "$compositor" == "niri" ]]; then
        sed -e "s|{{SHELL_NAME}}|${shell_name}|g" \
            -e "s|{{LAUNCH_CMD_ARGS}}|${launch_cmd_args}|g" \
            "${template_dir}/shell-start.kdl.template" > "$startup_config"

        sed -e "s|{{SHELL_NAME}}|${shell_name}|g" \
            -e "s|{{LAUNCHER_CMD_ARGS}}|${launcher_cmd_args}|g" \
            "${template_dir}/shell-binds.kdl.template" > "$binds_config"
    elif [[ "$compositor" == "hyprland" ]]; then
        sed -e "s|{{SHELL_NAME}}|${shell_name}|g" \
            -e "s|{{LAUNCH_CMD}}|${launch_cmd}|g" \
            "${template_dir}/shell-start.conf.template" > "$startup_config"

        sed -e "s|{{SHELL_NAME}}|${shell_name}|g" \
            -e "s|{{LAUNCHER_CMD}}|${launcher_cmd}|g" \
            "${template_dir}/shell-binds.conf.template" > "$binds_config"
    fi

    success "Generated: $startup_config"
    success "Generated: $binds_config"

    return 0
}

#######################################
# Integrate with compositor config
# Arguments:
#   $1 - Compositor name
# Returns:
#   0 on success, 1 on failure
#######################################
integrate_with_compositor() {
    local compositor="$1"

    info "Integrating with $compositor configuration..."

    # Add include statements
    if ! add_include_statement "$compositor" "shell-switcher-startup.kdl"; then
        return 1
    fi

    if ! add_include_statement "$compositor" "shell-switcher-binds.kdl"; then
        return 1
    fi

    # For niri, comment out existing shell startup in startup.kdl
    if [[ "$compositor" == "niri" ]]; then
        local startup_kdl="${HOME}/.config/niri/startup.kdl"
        if [[ -f "$startup_kdl" ]]; then
            # Backup first
            backup_file "$startup_kdl"

            # Comment out existing shell startups
            sed -i -E 's/^([^/]*spawn-at-startup.*"(qs|dms)".*)$/\/\/ \1 \/\/ Commented by shell-switcher/' "$startup_kdl"
            info "Commented out existing shell startup in startup.kdl"
        fi

        # For niri binds.kdl, comment out Mod+Space binding
        local binds_kdl="${HOME}/.config/niri/binds.kdl"
        if [[ -f "$binds_kdl" ]]; then
            backup_file "$binds_kdl"

            # Comment out Mod+Space launcher bindings
            sed -i -E '/Mod\+Space.*hotkey-overlay-title.*Launcher/,/}/s/^(.*)$/\/\/ \1 \/\/ Commented by shell-switcher/' "$binds_kdl"
            info "Commented out existing Mod+Space binding in binds.kdl"
        fi
    fi

    success "Successfully integrated with $compositor"
    return 0
}

#######################################
# Install shell-switch executable
# Returns:
#   0 on success, 1 on failure
#######################################
install_executable() {
    info "Installing shell-switch executable..."

    # Create ~/.local/bin if it doesn't exist
    mkdir -p "$(dirname "$INSTALL_BIN")"

    # Create symlink
    if ln -sf "${SCRIPT_DIR}/shell-switch" "$INSTALL_BIN"; then
        success "Installed: $INSTALL_BIN"
    else
        error "Failed to install executable"
        return 1
    fi

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
        warning "${HOME}/.local/bin is not in your PATH"
        info "Add this to your shell profile (~/.bashrc or ~/.zshrc):"
        echo ""
        color_echo yellow "    export PATH=\"\${HOME}/.local/bin:\${PATH}\""
        echo ""
    else
        success "${HOME}/.local/bin is in PATH"
    fi

    return 0
}

#######################################
# Print success message and usage info
# Arguments:
#   $1 - Compositor name
#   $2 - Current shell ID
#######################################
print_success_message() {
    local compositor="$1"
    local current_shell="$2"
    local current_name
    current_name=$(get_shell_info "$current_shell" "name")

    echo ""
    echo ""
    color_echo green "╔═══════════════════════════════════════════╗"
    color_echo green "║   ${ICON_SUCCESS} Shell Switcher Installed Successfully!  ║"
    color_echo green "╚═══════════════════════════════════════════╝"
    echo ""

    info "Current configuration:"
    echo "  ${ICON_INFO} Compositor: $compositor"
    echo "  ${ICON_INFO} Active Shell: $current_name"
    echo ""

    info "Keybindings:"
    echo "  ${ICON_INFO} Super+Space: Open app launcher"
    echo ""

    info "Usage:"
    echo "  ${ICON_INFO} Run 'shell-switch' to change shells"
    echo ""

    if [[ "$compositor" == "niri" ]]; then
        info "Config files:"
        echo "  ${ICON_INFO} ${HOME}/.config/niri/shell-switcher-startup.kdl"
        echo "  ${ICON_INFO} ${HOME}/.config/niri/shell-switcher-binds.kdl"
    elif [[ "$compositor" == "hyprland" ]]; then
        info "Config files:"
        echo "  ${ICON_INFO} ${HOME}/.config/hypr/shell-switcher-startup.conf"
        echo "  ${ICON_INFO} ${HOME}/.config/hypr/shell-switcher-binds.conf"
    fi

    echo ""
    info "You can add additional keybindings to the binds config file"
    echo ""

    color_echo cyan "Reload your compositor to activate the keybindings!"
    echo ""
}

#######################################
# Main installation flow
#######################################
main() {
    print_banner

    log "INFO" "=== Installation Started ==="

    # Step 1: Detect compositor
    local compositor
    if ! compositor=$(detect_compositor); then
        error "Could not detect compositor (niri or hyprland)"
        error "Are you running niri or hyprland?"
        exit 1
    fi

    success "Detected compositor: $compositor"
    echo ""

    # Step 2: Detect AUR helper
    local aur_helper
    if ! aur_helper=$(detect_aur_helper); then
        exit 1
    fi
    echo ""

    # Step 3: Check and install dependencies
    if ! check_dependencies "$aur_helper"; then
        exit 1
    fi
    echo ""

    # Step 4: Check and install shells
    if ! check_shells "$aur_helper"; then
        exit 1
    fi
    echo ""

    # Step 5: Detect current shell
    local current_shell
    if ! current_shell=$(detect_current_shell); then
        error "Could not determine current shell"
        exit 1
    fi
    echo ""

    # Step 6: Create config.json
    if ! create_config "$compositor" "$current_shell"; then
        exit 1
    fi
    echo ""

    # Step 7: Generate compositor configs
    if ! generate_compositor_configs "$compositor" "$current_shell"; then
        exit 1
    fi
    echo ""

    # Step 8: Integrate with compositor
    if ! integrate_with_compositor "$compositor"; then
        exit 1
    fi
    echo ""

    # Step 9: Install executable
    if ! install_executable; then
        exit 1
    fi

    # Step 10: Print success message
    print_success_message "$compositor" "$current_shell"

    log "INFO" "=== Installation Completed Successfully ==="
}

# Run main
main "$@"
