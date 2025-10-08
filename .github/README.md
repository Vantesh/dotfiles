<h1 align="center">HyprNiri</h1>
<p align="center">Hyprland + Niri dotfiles Managed with <a href="https://github.com/twpayne/chezmoi">chezmoi</a></p>

<p align="center">
	<br><br>
	<a href="#screenshots"><kbd> <br> Screenshots <br> </kbd></a>&ensp;&ensp;
	<a href="#installation"><kbd> <br> Installation <br> </kbd></a>&ensp;&ensp;
	<a href="#features"><kbd> <br> Features <br> </kbd></a>&ensp;&ensp;
	<a href="#post-install"><kbd> <br> Post Install <br> </kbd></a>
</p>

> [!IMPORTANT]
> Optimized for Arch and Fedora based distros.
> **Tested on Arch, CachyOS, Garuda, Manjaro, Fedora and Nobara.**
> Minimal Arch-based distros recommended for best results.

> [!WARNING]
> On Manjaro, you may need to uninstall conflicting packages: `qt5ct`, `qt6ct` and `reflector`.

> [!TIP]
> Hit **SUPER + F2** for the full keybinding cheat-sheet (SUPER = Windows key).
>
> To update an existing install, run:
>
> ```
> chezmoi update
> ```

> [!CAUTION]
> The installer backs up most configs it touches, but you're still responsible for any critical data. Make personal backups before continuing — I can't take responsibility for any loss.

<a id="screenshots"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Preview)](https://git.io/typing-svg)

#### Demo

https://github.com/user-attachments/assets/bd263e88-f2b6-477a-97dc-e8c1afa23669

<details close>
<summary>Distros</summary>
<p align="center">
<img aligh="center" width="49%" src="https://github.com/user-attachments/assets/1afa6f23-86c7-4528-bca9-f0fef1956148" />
<img aligh="center" width="49%" src="https://github.com/user-attachments/assets/074f625a-da26-481d-89ce-059f4097ef81" /> <br>

<img aligh="center" width="49%" src="https://github.com/user-attachments/assets/e9bb5d28-6a90-4169-a5d8-6ea30a3a82bf" />
<img aligh="center" width="49%" src="https://github.com/user-attachments/assets/9d13c1c0-c251-482e-822b-d0d027d79df4" />

<img aligh="center" width="49%" src="https://github.com/user-attachments/assets/a224b5bf-642f-4f23-b7d1-353e795af106" />
<img aligh="center" width="49%" src="https://github.com/user-attachments/assets/286cde9f-05ff-4eec-a8f2-3caac84aa581" />
</p><br>
</details>

<details close>
<summary>Overall</summary>
<p align="center">
<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/3e8f1692-a216-4f7d-beb1-fa5c12388cf6" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/a15b55ca-2017-403d-9eea-9a87f3b2a654" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/d3be0e12-8798-4ede-949b-e15fe3cf0762" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/69c53c38-0a6c-45db-9f5b-070f5c7117b3" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/17a301e1-1f64-48eb-b053-d7baf2634830" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/190724a6-ac40-4e2d-8fb0-6b0349166ea8" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/304c5803-05ec-4036-8fc8-f2cba922f56b" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/a3c36b91-b11d-4b54-9200-3384daee3544" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/e21a6d4d-f885-4eab-842d-e178f580c2d9" />

<img aligh="center" width="49%" alt="Image" src="https://github.com/user-attachments/assets/34511907-02ce-461f-a83e-c44478e45d4f" />
</p><br>
</details>

<a id="installation"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Installation)](https://git.io/typing-svg)

### Requirements

- Fresh Arch-based install (tested on Arch, CachyOS, Garuda).
- `curl` (for grabbing the bootstrap script).
- Internet access.

### Direct installation

```bash
curl -fsSL https://raw.githubusercontent.com/Vantesh/dotfiles/main/install.sh | bash
```

### Manual installation

```bash
# Clone the dotfiles repository
git clone https://github.com/vantesh/dotfiles.git --depth=1

# Navigate to the cloned directory
cd dotfiles

# Make the install script executable
chmod +x install.sh

# Run the installation script
./install.sh
```

<a id="features"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Features)](https://git.io/typing-svg)

- Auto-generated Matugen themes with synchronized light and dark palettes across apps.
- Pacman, sudo, and AUR helper tuning so your base system feels polished out of the box.
- Kitty, Fish, Neovim, and other dotfiles polished to suit developer needs.
- Optional extras like Snapper, GRUB/Limine themes, and laptop-specific power tweaks.

<a id="post-install"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Post-install+notes)](https://git.io/typing-svg)

- **Caps Lock** → Mapped as Escape by default. Change it in `~/.config/hypr/hyprland/input.conf`.
- **Terminal** → Kitty is the default; adjust via `~/.config/xdg-terminals.list`.
- **Niri** → Tweak transparency under Settings → Theme & Colors.

> [!NOTE]
> If hyprland throws config errors on first start, simply change the wallpaper once and they should clear up.
>
> The keybind for changing wallpapers is **SUPER + W**.

<a id="credits"></a>

## [![Typing SVG](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&pause=1000&color=84D2E7&width=435&lines=Credits)](https://git.io/typing-svg)

- [END4 Dotfiles](https://github.com/end-4/dots-hyprland) for monet stuff.
- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) for quickshell config.
