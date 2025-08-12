<h1 align="center">Hyprland Dotfiles</h1>
<div align="center">

<a href="https://github.com/Vantesh/dotfiles/commits/main/"><img alt="Commit Activity" src="https://img.shields.io/github/commit-activity/m/Vantesh/dotfiles/main?style=for-the-badge&logo=github&color=F2CDCD&logoColor=D9E0EE&labelColor=302D41"/></a>
<a href="https://github.com/Vantesh/dotfiles"><img alt="Size" src="https://img.shields.io/github/repo-size/Vantesh/dotfiles?style=for-the-badge&logo=discord&color=DDB6F2&logoColor=D9E0EE&labelColor=302D41"></a>

</div>

##

Hyprland dotfiles managed with [chezmoi](https://github.com/twpayne/chezmoi).

## Demo

https://github.com/user-attachments/assets/bd263e88-f2b6-477a-97dc-e8c1afa23669

## Requirements

- **Fresh arch installation** - The script is designed for a fresh minimal Arch Linux installation.
- (Other arch based distros or existing setups may work but may require manual adjustments)

## Installation

### Method 1: Direct Installation

Initialize and apply the dotfiles directly:

```bash
chezmoi init --apply vantesh
```

### Method 2: Clone and Install

If you prefer to clone the repository first:

```bash
# Clone the dotfiles repository
git clone https://github.com/vantesh/dotfiles.git

# Navigate to the cloned directory
cd dotfiles

# Make the install script executable
chmod +x install.sh

# Run the installation script
./install.sh
```

This method allows you to inspect and modify the configurations before installation.

### Keybindings

Use **SUPER + F2** to view all available keybindings and shortcuts.
Super is the **Windows** key

### What The Script Does

<details>
<summary>Click to expand</summary>

- **System Configuration** - Configures sudo, pacman, and installs AUR helper
- **Dependencies** - Installs core packages and GPU drivers
- **Services** - Configures system services and settings
- **Theming** - Sets up fonts, cursors, and visual themes
- **Dotfiles** - Applies configuration files
- **Shell Setup** - Configures ZSH (optional)
- **Snapshots** - Sets up Snapper for BTRFS (optional)
- **Bootloader** - Configures GRUB or limine theme
- **Laptop Tweaks** - Applies laptop-specific optimizations if detected

</details>

### Post Installation

After running the script, you may need to:

- **Hyprland:** Reload Hyprland with `hyprctl reload` if theme doesnt autoreload.
- **Yazi:** Run `ya pkg install` to install any missing plugins.
- **Neovim:** Remove the `~/.local/share/nvim` directory then run `nvim` to install plugins.

## Credits

- [END4 Dotfiles](https://github.com/end-4/dots-hyprland) for monet stuff
