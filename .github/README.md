![Hyprland desktop](https://github.com/user-attachments/assets/093b4800-a1ec-49d2-b169-f6b6293cf2c0)

# Hyprland dotfiles

My Arch Linux setup: Hyprland, Noctalia, Fish, and Kitty. Managed with [chezmoi](https://www.chezmoi.io/quick-start/).

[Install](#fresh-install) · [Customize](#customizing-the-setup) · [Layout](#btrfs-layout) · [Boot](#boot-configuration) · [Recovery](#chroot-recovery)

## Fresh install

Start from an installed Arch system with network access and a regular user with sudo access. Back up existing configuration first.

```bash
sudo pacman -S --needed chezmoi
chezmoi init --apply vantesh
```

Setup installs its remaining prerequisites and prompts for Snapper, hibernation, Secure Boot, and drivers.

> [!WARNING]
> **If you are not me (Vantesh), answer No to “Is this a personal setup”.** This option is for me only. It expects my private Bitwarden entries and their exact fields; missing or incorrect entries will make setup fail.

## Customizing the setup

Chezmoi deploys `home/` and runs the setup scripts. The scripts use [mise bootstrap](https://mise.jdx.dev/bootstrap.html) to apply the repository's package and system settings. `mise/config.toml` sets the required mise version; `mise/conf.d/` splits the settings by purpose. These are separate from your global mise configuration.

Run `chezmoi cd` to open the repository; all paths below are relative to its root.

| What to change | File |
| --- | --- |
| Packages and optional package groups | `mise/conf.d/packages.toml` |
| System services and timers | `mise/conf.d/services.toml` |
| Login shell (`/usr/bin/fish` by default) | `mise/conf.d/login-shell.toml` |
| Firewall rules | `mise/conf.d/firewall.toml` |
| Pacman cache hooks | `mise/conf.d/pacman-hooks.toml` |

To add a package, follow the existing entries under `[bootstrap.packages]`, for example `"pacman:htop" = { env = "packages" }`. Use `aur:` for AUR packages. The `env` field selects a package group; keep optional driver and feature packages in their existing groups.

For system services, add or edit a `[bootstrap.services."name.service"]` block: `state = "running"` starts it, and `enabled = true` enables it at boot. To stop and disable one, apply `state = "stopped"` and `enabled = false` before removing its block. Deleting a declaration alone does not uninstall its package or stop its service; uninstall unwanted packages separately.

Packaged **user** services are handled separately: edit `USER_SERVICES` in `home/.chezmoiscripts/linux/run_onchange_after_14_services.sh.tmpl`.

After editing, review the source changes with `git diff`, then run `chezmoi apply`. Changes to these mise files make the corresponding setup scripts run again.

### Fish

Fish configuration lives in `home/dot_config/private_fish/`, deployed to `~/.config/fish/`:

- `config.fish`: interactive startup and Fisher setup.
- `conf.d/abbr.fish`: abbreviations; `conf.d/variables.fish`: environment and paths. Other `conf.d/` files configure integrations.
- `functions/`: custom commands and wrappers.
- `fish_plugins`: Fisher plugin list.

## Btrfs layout

This is the Btrfs layout I use; these dotfiles do not create it. Optional hibernation can add `@swap`, and Snapper manages `/.snapshots`.

```text
Btrfs volume
├── @                 → /
│   └── .snapshots    → /.snapshots
├── @home             → /home
├── @root             → /root
├── @srv              → /srv
├── @cache            → /var/cache
├── @machines         → /var/lib/machines
├── @portables        → /var/lib/portables
├── @log              → /var/log
├── @tmp              → /var/tmp
└── @swap             → /swap

/boot                  EFI System Partition
```

## Boot configuration

- **Limine** with systemd-based mkinitcpio on supported Btrfs installations, independently of hibernation.
- **LUKS roots:** `sd-encrypt` is included for verified, directly LUKS-backed Btrfs roots; plain roots omit it.
- **Optional:** Plymouth, Secure Boot, Snapper snapshots, and laptop hibernation. Snapper is independent of hibernation.
- Boot configuration changes queue a deferred rebuild. Credentials, crypttab, and TPM2 policy remain user-managed.

Persistent Limine defaults live in `/etc/limine-entry-tool.d/01-default.conf`, with feature fragments alongside it. The effective command line may differ from `/etc/kernel/cmdline` because later configuration can prepend or replace arguments.

After editing persistent settings, run `sudo limine-update` and inspect the generated `/boot/limine.conf`; after reboot, check `cat /proc/cmdline`. If the ESP is mounted elsewhere, use its configured `ESP_PATH` from `/etc/default/limine`.

Current and historical snapshot UKIs (unified kernel images) can have different BLAKE2b hashes. Each entry's hash must match its referenced boot file. When Limine configuration enrollment is enabled, regenerate through the normal tools rather than manually editing generated hashes.

### TPM2 automatic LUKS unlocking

For LUKS2 with a TPM2, enrollment and boot configuration are separate. Replace the device placeholder with the encrypted partition, then identify its **LUKS UUID**, not the Btrfs UUID:

```bash
sudo cryptsetup luksUUID /dev/<luks-partition>
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=7 \
  /dev/<luks-partition>
```

PCR 7 binds unlocking to the Secure Boot policy. Choose this policy deliberately: changes to Secure Boot mode or keys can affect unlocking. Keep a working LUKS password or recovery key. See [systemd-cryptenroll](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html) for policy details.

Add this option to the existing kernel arguments in `/etc/limine-entry-tool.d/01-default.conf`:

```text
rd.luks.options=<LUKS-UUID>=tpm2-device=auto
```

Merge with existing options for that UUID; preserve `rd.luks.name=`, `root=`, and other custom arguments. Review any existing early crypttab policy too. Run `sudo limine-update` and verify the generated command line before rebooting. The setup scripts do not enroll TPM2 or choose authentication policies.

## Chroot recovery

### From a live USB

Boot an Arch Linux live USB and use its root shell. Replace the device placeholders with the actual partitions.

Unlock LUKS, mount the real `@` root and EFI System Partition, then enter the installation:

```bash
sudo cryptsetup open /dev/<luks-partition> root
sudo mount -o subvol=@ /dev/mapper/root /mnt
sudo mount --mkdir /dev/<efi-partition> /mnt/boot
sudo arch-chroot /mnt
```

Use the installation's actual ESP mount point if it differs from `/boot`. [arch-chroot](https://man.archlinux.org/man/arch-chroot.8.en) comes from `arch-install-scripts` and is included in the standard Arch installation environment.

Inside the chroot, inspect persistent settings and correct them before rebuilding:

```bash
cat /etc/limine-entry-tool.d/01-default.conf
cat /etc/kernel/cmdline
limine-update
```

`limine-update` is the normal path here: it rebuilds through mkinitcpio, generates UKIs when enabled, and runs the configured signing and Limine enrollment hooks. A separate mkinitcpio rebuild is usually unnecessary; for an initramfs-only repair when needed:

```bash
mkinitcpio -P
```

Check the rebuild output before leaving; an initramfs-only rebuild does not replace the full Limine signing/enrollment path.

```bash
exit
umount -R /mnt
reboot
```

### From a Snapper snapshot

To repair the installed root from a booted Snapper overlay, mount the real `@` subvolume. The LUKS container is already unlocked; replace `<root-mapper>` and `<efi-partition>` with their actual names. This requires `arch-install-scripts` in the booted environment.

```bash
sudo mount -o subvol=@ /dev/mapper/<root-mapper> /mnt
sudo mount --mkdir /dev/<efi-partition> /mnt/boot
sudo arch-chroot /mnt
```

Use the repair steps above inside the chroot. When finished:

```bash
exit
sudo umount -R /mnt
sudo reboot
```

## Usual commands

```bash
chezmoi diff                    # Review changes
chezmoi apply -nv                # Dry run with verbose output
chezmoi apply                    # Apply files and eligible setup scripts
chezmoi apply --exclude=scripts  # Apply files only
chezmoi update                   # Pull and apply
chezmoi cd                       # Open a shell in the source repo
```

For file edits:

```bash
chezmoi edit ~/.bashrc           # Edit the managed source
chezmoi add ~/.bashrc            # Track a file or import live edits
chezmoi apply ~/.bashrc          # Apply only this file
chezmoi forget ~/.bashrc         # Stop tracking; keep the live file
```

Edit `.tmpl` files directly in the source repo. Use `chezmoi add` to import deliberate edits to live files.

## Script tests

Setup-script tests require Python 3.11+, Bash, and chezmoi; static checks also require ShellCheck.

```bash
python3 -B -m unittest discover -s .github/tests -v
python3 -B .github/tests/validate.py
```

## Reminders

- **Super + F2:** keybinding cheat sheet.
- **Super + W:** wallpaper picker; wallpapers live in `~/Pictures/Wallpapers`.
- **Super + U:** system update.
- **Super + B:** browser.
- **Bash history:** move `~/.bash_history` to `~/.local/state/bash/history` if needed, preserving existing history.

Based on [END4's dotfiles](https://github.com/end-4/dots-hyprland), with Noctalia for the shell and theming.
