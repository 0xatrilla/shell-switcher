# Shell Switcher

TUI for switching between desktop shells (e.g. Noctalia, DMS) on niri or hyprland. Run `shell-switch`, pick a shell from the menu, and it stops the current one and starts the selected one. Config and keybindings are updated automatically.

**Install:** clone this repo, run `./install.sh`. Needs `fzf` and `jq`.

## Adding more shells

Edit `lib/shell-manager.sh` and add a new block in `init_shell_db()`, following the existing entries. For each shell you need:

- **id** – short identifier (e.g. `myshell`)
- **name** – display name in the menu
- **launch_cmd** – command to start the shell
- **launcher_cmd** – command to open its app launcher (used for the Super+Space keybinding)
- **process_pattern** – pattern for `pgrep` to detect the running process
- **packages** – space-separated package names so the installer can detect if it is installed

Example:

```bash
SHELL_DB[myshell.id]="myshell"
SHELL_DB[myshell.name]="My Shell"
SHELL_DB[myshell.launch_cmd]="my-shell run"
SHELL_DB[myshell.launcher_cmd]="my-shell ipc launcher toggle"
SHELL_DB[myshell.process_pattern]="my-shell run"
SHELL_DB[myshell.packages]="my-shell my-shell-git"
```

Save the file; the new shell will appear in the switcher menu on the next run.
