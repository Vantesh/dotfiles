![Hyprland desktop screenshot 1](https://github.com/user-attachments/assets/ec0a2f68-732e-4d42-8290-3f2cf352002a)

<h1 align="center">Hyprland Dotfiles</h1>
<p align="center">Hyprland dotfiles Managed with <a href="https://github.com/twpayne/chezmoi">chezmoi</a></p>

<p align="center">
<br><br>
<a href="#screenshots"><kbd> <br> Screenshots <br> </kbd></a>&ensp;&ensp;
<a href="#installation"><kbd> <br> Installation <br> </kbd></a>&ensp;&ensp;
<a href="#features"><kbd> <br> Features <br> </kbd></a>&ensp;&ensp;
<a href="#post-install"><kbd> <br> Post Install <br> </kbd></a>
</p>

> [!IMPORTANT]
> These dotfiles are for Arch Linux.
> Arch-based distros may work, but expect manual intervention.

> [!WARNING]
> Arch-based distros may ship conflicting defaults, so you may need to adjust packages or services manually.

> [!TIP]
> Hit **SUPER + F2** for the full keybinding cheat-sheet (SUPER = Windows key).
>
> To update an existing install, run:
>
> ```
> chezmoi update
> ```

> [!CAUTION]
> Applying these dotfiles can overwrite existing configuration. There is no automatic backup of `~/.config`; back up your configuration and critical data before continuing — I can't take responsibility for any loss.

<a id="screenshots"></a>

<details>
<summary>Screenshots</summary>

![Hyprland desktop screenshot 2](https://github.com/user-attachments/assets/c536aa81-8e47-40d2-94af-da0192bf08e8)

![Hyprland desktop screenshot 3](https://github.com/user-attachments/assets/0e339f79-d71b-4ba2-bb26-b8b20df2cee0)

![Hyprland desktop screenshot 4](https://github.com/user-attachments/assets/02434f8c-eec6-4bf4-8bf6-3e9ee7be8daa)

![Hyprland desktop screenshot 5](https://github.com/user-attachments/assets/feab8134-bf03-4768-8465-331a75ec5a90)

</details>

<a id="installation"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Installation)](https://git.io/typing-svg)

### Requirements

- Fresh Arch Linux install.
- A regular user with `sudo` access.
- An interactive terminal and internet access.

### Installation

Run these commands directly in your terminal, not through a piped shell script:

```bash
# Install chezmoi
sudo pacman -S --needed chezmoi

# Fetch the dotfiles, choose setup options, and apply
chezmoi init --apply vantesh
```

<a id="features"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Features)](https://git.io/typing-svg)

- Noctalia desktop shell with a bar, launcher, control center, clipboard manager, and wallpaper picker.
- Wallpaper-based theming through Noctalia, with light and dark palettes and templates for terminal, editor, and desktop apps.
- Modular Hyprland Lua configuration for keybindings, input, monitors, workspaces, and window rules.
- Pacman, sudo, and AUR helper tuning so your base system feels polished out of the box.
- Kitty, Fish, Neovim, and other dotfiles polished to suit developer needs.
- Optional extras like Snapper, GRUB/Limine themes, and laptop-specific power tweaks.

<a id="post-install"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Post-install+notes)](https://git.io/typing-svg)

- **Hyprland** → Uses `~/.config/hypr/hyprland.lua`, with modules in `~/.config/hypr/config/`
- **Input** → Configure keyboard and touchpad settings in `~/.config/hypr/config/inputs.lua`.
- **Keybindings** → Customize `~/.config/hypr/config/binds.lua`; **SUPER + F2** opens the keybinding cheat-sheet.
- **Terminal** → Kitty is the default; adjust via `~/.config/xdg-terminals.list`.
- **Wallpapers** → **SUPER + W** opens Noctalia's wallpaper picker. Wallpapers are loaded from `~/Pictures/Wallpapers`.
- **Theming** → Noctalia's theme settings and app templates are configured in `~/.config/noctalia/theme.toml` and `~/.config/noctalia/templates.toml`.

<a id="credits"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Credits)](https://git.io/typing-svg)

- [END4 Dotfiles](https://github.com/end-4/dots-hyprland) for monet stuff.
- Noctalia for the desktop shell and app theming.
