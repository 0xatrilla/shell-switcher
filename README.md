<p align="center">
  <img src="assets/shell-switch.png" alt="Shell Switch Logo" width="200">
</p>

<h1 align="center">Shell Switcher - TUI for Noctalia & DMS</h1>

A Terminal User Interface (TUI) for seamlessly switching between desktop shells on niri and hyprland compositors.

## Features

- **Interactive TUI**: Uses `fzf` for a clean, keyboard-driven interface
- **Multi-Compositor Support**: Works with both niri and hyprland
- **Safe Switching**: Automatic backups and rollback on failure
- **Smart Integration**: Non-invasive config management with separate include files
- **Shell Support**: Currently supports Noctalia Shell and Dank Material Shell (DMS)

<p align="center">
  <img src="assets/Screenshot from 2026-01-22 09-10-04.png" alt="Shell Switch TUI Screenshot">
</p>

## Installation

```bash
git clone https://gitlab.com/theblackdon/shell-switch.git ~/.config/shell-switch
cd ~/.config/shell-switch
./install.sh
```

The installer will:
- Detect your compositor (niri or hyprland)
- Check for and install dependencies (fzf, jq)
- Offer to install Noctalia Shell and/or DMS from AUR
- Generate compositor config files
- Set up keybindings (Super+Space for launcher)
- Create a symlink at `~/.local/bin/shell-switch`

### What gets installed

1. **Main Scripts**:
   - `~/.local/bin/shell-switch` - Main executable (symlinked)
   - `~/.config/shell-switch/shell-switch` - Actual script
   - `~/.config/shell-switch/install.sh` - Installation script

2. **Libraries**:
   - `lib/common.sh` - Utility functions (logging, colors, backups)
   - `lib/compositor.sh` - Compositor detection and management
   - `lib/shell-manager.sh` - Shell lifecycle management

3. **Templates**:
   - `templates/niri/` - KDL templates for niri
   - `templates/hyprland/` - Conf templates for hyprland

4. **Generated Configs**:
   - `~/.config/niri/shell-switcher-startup.kdl` - Shell startup commands
   - `~/.config/niri/shell-switcher-binds.kdl` - Keybindings

5. **State Management**:
   - `~/.config/shell-switch/config.json` - Current configuration and shell state
   - `~/.config/shell-switch/shell-switch.log` - Operation logs
   - `~/.config/shell-switch/backups/` - Config backups (last 5)

## Usage

### Interactive Switching

Run:

```bash
shell-switch
```

Use arrow keys or type to select a shell, then press Enter to switch.

### Keybindings

- **Super+Space**: Open app launcher for current shell
  - Noctalia: Opens Noctalia launcher
  - DMS: Opens DMS Spotlight

You can add your own keybinding for the shell switcher in your compositor config.

### Current Configuration

- **Compositor**: niri
- **Active Shell**: Noctalia Shell
- **Available Shells**: Noctalia Shell, Dank Material Shell

## How It Works

1. **Detection**: Detects your compositor and currently running shell
2. **Selection**: Shows fzf menu with available shells
3. **Switching Process**:
   - Backs up current configs
   - Stops current shell gracefully
   - Updates config files
   - Starts new shell
   - Verifies startup (5-second timeout)
   - Reloads compositor config
   - Updates state tracking
4. **Safety**: If anything fails, automatically rolls back to previous shell

## Supported Shells

### Noctalia Shell
- **Launch Command**: `qs -c noctalia-shell`
- **Launcher**: `qs -c noctalia-shell ipc call launcher toggle`
- **AUR Package**: `noctalia-shell-git`

### Dank Material Shell (DMS)
- **Launch Command**: `dms run`
- **Launcher**: `dms ipc call spotlight toggle`
- **AUR Package**: `dms-shell-git`

## Adding Custom Keybindings

You can add your own shell-specific keybindings to:

```
~/.config/niri/shell-switcher-binds.kdl
```

Add them below the `=== END MANAGED SECTION ===` comment to prevent them from being overwritten.

Example:
```kdl
binds {
    // === MANAGED BY SHELL-SWITCH - DO NOT EDIT THIS SECTION ===
    // ... managed bindings ...
    // === END MANAGED SECTION ===
    
    // Your custom bindings:
    Mod+Shift+L { spawn "your-custom-command"; }
}
```

## File Structure

```
~/.config/shell-switch/
├── shell-switch              # Main TUI script
├── install.sh                # Installation script
├── config.json               # State file (current shell, compositor, etc.)
├── shell-switch.log          # Operation logs
├── README.md                 # This file
├── lib/
│   ├── common.sh            # Shared utilities
│   ├── compositor.sh        # Compositor management
│   └── shell-manager.sh     # Shell lifecycle
├── templates/
│   ├── niri/
│   │   ├── shell-start.kdl.template
│   │   └── shell-binds.kdl.template
│   └── hyprland/
│       ├── shell-start.conf.template
│       └── shell-binds.conf.template
└── backups/                  # Automatic backups (last 5)
```

## Configuration

The `config.json` file tracks:
- Current active shell
- Detected compositor
- Config file paths
- Installed shells and packages
- Switch history and count

## Troubleshooting

### View Logs
```bash
tail -f ~/.config/shell-switch/shell-switch.log
```

### Check Current Shell
```bash
pgrep -fa "qs.*noctalia|dms run"
```

### Verify Config
```bash
cat ~/.config/shell-switch/config.json | jq .
```

### Restore Backup
If something goes wrong, backups are stored in:
```
~/.config/shell-switch/backups/
```

### Reload Compositor
After making manual config changes:
```bash
niri msg action reload-config
```

## Adding More Shells

To add support for additional shells, edit:
```bash
~/.config/shell-switch/lib/shell-manager.sh
```

Add a new shell definition in the `init_shell_db()` function following the existing pattern.

## Dependencies

- **Required**:
  - `bash` (≥4.0)
  - `fzf` (TUI menu)
  - `jq` (JSON processing)
  - `pgrep`/`pkill` (process management)
  
- **Optional**:
  - `notify-send` (desktop notifications)

- **Shells**:
  - `noctalia-shell-git` or `noctalia-shell`
  - `dms-shell-git`, `dms-shell-bin`, or `dms-shell`

## Uninstallation

To remove the shell switcher:

```bash
# Remove executable
rm ~/.local/bin/shell-switch

# Remove config directory
rm -rf ~/.config/shell-switch

# Remove generated configs (for niri)
rm ~/.config/niri/shell-switcher-*.kdl

# Remove include statements from your compositor config
# Edit ~/.config/niri/config.kdl and remove the lines:
#   include "shell-switcher-startup.kdl"
#   include "shell-switcher-binds.kdl"

# Uncomment your original shell startup in startup.kdl and binds.kdl
```

## Architecture

- **Modular Design**: Separate libraries for different concerns
- **Non-Invasive**: Uses include files, doesn't modify your main configs
- **Safe Operations**: Automatic backups, verification, and rollback
- **Extensible**: Easy to add new shells or compositors
- **Logging**: Full operation logging for debugging

## Future Enhancements

Potential improvements (not yet implemented):
- Support for more shells (AGS, Waybar, etc.)
- Hyprland testing and validation
- Per-shell theme management
- GUI version alongside TUI
- Shell profiles/presets

## License

This is a custom tool created for personal use. Feel free to modify and share!

## Version

- **Version**: 1.0
- **Installation Date**: 2026-01-22
- **Compositor**: niri
- **Initial Shell**: Noctalia Shell
