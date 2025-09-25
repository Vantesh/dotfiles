<h1 align="center">HyprNiri</h1>
<div align="center">

<a href="https://github.com/Vantesh/dotfiles/commits/main/"><img alt="Commit Activity" src="https://img.shields.io/github/commit-activity/m/Vantesh/dotfiles/main?style=for-the-badge&logo=github&color=F2CDCD&logoColor=D9E0EE&labelColor=302D41"/></a>
<a href="https://github.com/Vantesh/dotfiles"><img alt="Size" src="https://img.shields.io/github/repo-size/Vantesh/dotfiles?style=for-the-badge&logo=discord&color=DDB6F2&logoColor=D9E0EE&labelColor=302D41"></a>

</div>

##

Hyprland and Niri dotfiles managed with [chezmoi](https://github.com/twpayne/chezmoi).

## Demo

https://github.com/user-attachments/assets/bd263e88-f2b6-477a-97dc-e8c1afa23669

## Screenshots

<details>
<summary>Click to expand</summary>
<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/e21a6d4d-f885-4eab-842d-e178f580c2d9" />

<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/34511907-02ce-461f-a83e-c44478e45d4f" />

<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/a15b55ca-2017-403d-9eea-9a87f3b2a654" />

<img width="1921" height="1080" alt="Image" src="https://github.com/user-attachments/assets/d3be0e12-8798-4ede-949b-e15fe3cf0762" />

<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/69c53c38-0a6c-45db-9f5b-070f5c7117b3" />

<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/17a301e1-1f64-48eb-b053-d7baf2634830" />

<img width="1921" height="1044" alt="Image" src="https://github.com/user-attachments/assets/190724a6-ac40-4e2d-8fb0-6b0349166ea8" />

<img width="1857" height="1021" alt="Image" src="https://github.com/user-attachments/assets/304c5803-05ec-4036-8fc8-f2cba922f56b" />

<img width="1921" height="1079" alt="Image" src="https://github.com/user-attachments/assets/a3c36b91-b11d-4b54-9200-3384daee3544" />

</details>

## Requirements

- **Fresh arch installation** - The script is designed for a fresh minimal Arch Linux installation.
- (Other arch based distros or existing arch setups may work but may require manual adjustments)

## Installation

```bash
# Clone the dotfiles repository
git clone https://github.com/vantesh/dotfiles.git

# Navigate to the cloned directory
cd dotfiles

# Make the install script executable
chmod +x install.sh

# Run the installation script
./install.sh

# Follow the on-screen prompts to complete the installation
```

### Keybindings

Use **SUPER + F2** to view all available keybindings and shortcuts.
Super is the **Windows** key

### What The Script Does

<details>
<summary>Click to expand</summary>

- **System Configuration** - Configures sudo, pacman, and installs AUR helper(paru/yay)
- **Dependencies** - Installs core packages and GPU drivers
- **Services** - Configures system services and settings
- **Theming** - Sets up fonts, cursors, and visual themes
- **Dotfiles** - Applies configuration files
- **Shell Setup** - Configures ZSH/Fish
- **Snapshots** - Sets up Snapper for BTRFS (optional)
- **Bootloader** - Configures GRUB or limine theme (optional)
- **Laptop Tweaks** - Applies laptop-specific optimizations if detected

</details>

### Post Installation

- **Capslock** - By default capslock is remapped to escape. To change this, edit the `~/.config/hypr/hyprland/input.conf`

- **Terminal** - `Kitty` is the default terminal. Edit `~/.config/xdg-terminals.list` to set default terminal

- **Niri** - Since niri doesn't support blur yet, adjust the transparency from settings → Theme & colors → transparency to your liking.

## Credits

- [END4 Dotfiles](https://github.com/end-4/dots-hyprland) for monet stuff
- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) for the quickshell
