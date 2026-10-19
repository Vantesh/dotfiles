![Hyprland desktop](https://github.com/user-attachments/assets/093b4800-a1ec-49d2-b169-f6b6293cf2c0)

# Hyprland dotfiles

My Arch Linux setup: Hyprland, Noctalia, Fish, and Kitty. Managed with chezmoi.

## Fresh install

Back up my existing config first. Run as regular user with sudo access.

```sh
sudo pacman -S --needed chezmoi
chezmoi init --apply vantesh
```

**Personal setup limitation:** Bitwarden installation and login remain in the
normal prerequisite script. Chezmoi can render secret-backed templates before
that phase, so the original bootstrap-ordering issue is not solved here.
Personal secret rendering requires `rbw` to be installed and authenticated in
advance, or `CHEZMOI_GITHUB_ACCESS_TOKEN` for the GitHub token lookup only. Other
personal workflows still require the vault. Non-personal setup does not use it.

If you generated a config from the discarded source-state-hook proposal, run
plain `chezmoi init` **without `--apply`** once to remove the saved hook. No new
bootstrap mode or replacement hook is provided.

### Yazi plugins (manual)

After applying, install the Yazi plugins manually; chezmoi does not install them.
Run each `add` command only if that plugin is not already registered:

```sh
ya pkg add ahkohd/eza-preview
ya pkg add yazi-rs/plugins:full-border
ya pkg install
```

## Usual commands

```sh
chezmoi status                 # See which files differ
chezmoi diff                   # See the actual changes before applying
chezmoi apply                  # Apply my local edits and eligible setup scripts
chezmoi apply -nv              # Dry run: show what would happen without changing anything
chezmoi apply --exclude=scripts # Apply files without running setup scripts
chezmoi update                 # Pull from GitHub and apply
chezmoi cd                     # Open a shell in this repo
```

### Working on a file

```sh
chezmoi edit ~/.bashrc          # Edit the managed source, then run chezmoi apply
chezmoi add ~/.bashrc           # Track the live file, or import edits I made to it
chezmoi apply ~/.bashrc         # Apply only this file
chezmoi forget ~/.bashrc        # Stop tracking it; keep the live file
chezmoi destroy ~/.bashrc       # remove from machine and repo
```

Normally, edit the managed source rather than the live `~/.config` copies. If I edit a live file, use `chezmoi add` to bring it back into the repo. For `.tmpl` files, edit the template directly instead.

## Script tests

Tests cover only chezmoi setup scripts and their shared helpers, not application
dotfiles. Requires Python 3.10+ and Bash. Run manually with:

```sh
python3 -B -m unittest discover -s .github/tests -v
```

CI runs the tests only for pull requests targeting `main`.

## Reminders

- **Super + F2:** keybinding cheat sheet.
- **Super + W:** wallpaper picker. My wallpapers live in `~/Pictures/Wallpapers`.
- **Super + U:** system update.
- **Super + B:** Open browser.
- **Bash history:** move `~/.bash_history` to `~/.local/state/bash/history` manually if needed; don't overwrite existing history.
- **Laptop power:** auto-cpufreq handles AC/battery automatically. Check with `auto-cpufreq --stats`.

Based on [END4's dotfiles](https://github.com/end-4/dots-hyprland), with Noctalia for the shell and theming.
