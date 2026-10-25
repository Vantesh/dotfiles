<img width="1280" height="720" alt="Hyprland desktop" src="https://github.com/user-attachments/assets/5edaf197-b81f-4d5f-be7c-5acab8b7764e" />

<h1 align="center">Dotfiles</h1>

<p align="center">
  My desktop setup: Hyprland, Noctalia, Fish, and Kitty. Managed with <a href="https://www.chezmoi.io/quick-start/">chezmoi</a>.
</p>

<p align="center">
  <a href="#fresh-install"><img height="36" alt="Install" src="https://img.shields.io/badge/Install-1e1e2e?style=flat" /></a>
  <a href="#customizing-the-setup"><img height="36" alt="Customize" src="https://img.shields.io/badge/Customize-1e1e2e?style=flat" /></a>
  <a href="#btrfs-layout"><img height="36" alt="Layout" src="https://img.shields.io/badge/Layout-1e1e2e?style=flat" /></a>
  <a href="#boot-configuration"><img height="36" alt="Boot" src="https://img.shields.io/badge/Boot-1e1e2e?style=flat" /></a>
  <a href="#chroot-recovery"><img height="36" alt="Recovery" src="https://img.shields.io/badge/Recovery-1e1e2e?style=flat" /></a>
</p>

## Fresh install

Start from a fresh Arch Linux or Arch-based installation with network access and a regular user with sudo access. Arch-family detection and the existing CachyOS/Garuda handling are retained. Other operating systems are unsupported.

Support is best effort; I only test this setup on machines I own.

> [!WARNING]
> **Package setup enables Chaotic-AUR by default**, adding its third-party repository and signing keys to pacman.

```bash
sudo pacman -S --needed chezmoi
chezmoi init --apply vantesh
```

Setup installs its prerequisites and asks one question: **Is this a personal setup?** The answer defaults to No and is saved for subsequent applies.

- **Nonpersonal:** installs baseline packages and applies nonsecret dotfiles. It does not access Bitwarden, provision drivers, configure services, firewall, login shell or login manager, customize desktop preferences, modify boot/filesystem/firmware settings, enroll devices, or reboot.
- **Personal:** adds private configuration and the existing driver, Btrfs/Snapper, swapfile/hibernation, Zswap, Limine/Secure Boot, desktop and service provisioning. Hardware and system-integrity checks still apply. Authentication and enrollment can require interaction.

Both profiles support repeated application. Previous dotfiles versions and profile transitions are unsupported; use manual cleanup or a fresh installation rather than expecting migration. Nonpersonal installs retain the existing package prerequisites, including Chaotic-AUR trust/repository setup, the initial full system upgrade, and an AUR helper. A compatible Vulkan provider must already be installed so baseline dependencies cannot select an unintended driver stack.

> [!WARNING]
> **If you are not me, answer No to “Is this a personal setup”.** This option is for me only. It expects my private Bitwarden entries and their exact fields; missing or incorrect entries will make setup fail.

## Customizing the setup

Mise files in the repository (`chezmoi cd`):

- `mise/config.toml` → required mise version.
- `mise/conf.d/packages.toml` → baseline packages and personal hardware groups.
- `mise/conf.d/services.toml` → system services and timers.
- `mise/conf.d/login-shell.toml` → sets Fish as the default login shell (`/usr/bin/fish`).
- `mise/conf.d/firewall.toml` → firewall rules.
- `mise/conf.d/pacman-hooks.toml` → package-cache cleanup hooks.

A small shell entry point installs Arch’s `python` and `python-loguru` packages when missing, then runs `.chezmoitemplates/bootstrap.py` with system Python. That bootstrap owns Git, base-devel, Mise availability and personal-only rbw/pinentry initialization; desktop package selection stays in Mise.

Service, firewall, login-shell and other provisioning declarations apply only to personal setups. Fish configuration is included in both profiles.

## Btrfs layout

This is the Btrfs layout I use; these dotfiles do not create it. Personal hibernation can add `@swap`, and Snapper manages `/.snapshots`.

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
- **Personal:** Secure Boot, Snapper snapshots, and supported laptop hibernation are selected automatically. Snapper is independent of hibernation. Existing Plymouth is retained. Zswap is configured after successful hibernation setup on machines with at least 30 GiB RAM, unless explicit settings or existing Zram prevent it; setup does not install Zram.

This setup intentionally uses `systemd.tpm2_measured_os=0` to disable systemd's additional measured-OS/NvPCR services and avoid their errors on newer systemd versions. This changes TPM measurements; it is more than a logging option. See the [Arch Linux discussion](https://bbs.archlinux.org/viewtopic.php?id=314939&p=2).

> [!IMPORTANT]
> If selecting Secure Boot for first-time key enrollment, put UEFI in **Setup Mode** with **Secure Boot disabled** before applying. Enable Secure Boot in firmware only after setup and the boot rebuild succeed.

Limine defaults live in `/etc/limine-entry-tool.d/01-default.conf`. After editing, rebuild with `sudo limine-update` or `sudo limine-mkinitcpio`; do not run mkinitcpio directly.

### Device names and LUKS UUID

Find your devices with:

```bash
lsblk -o NAME,PATH,FSTYPE,UUID,MOUNTPOINTS
```

Replace the placeholders below with your own values, without the angle brackets:

- `<luks-partition>` → the `crypto_LUKS` partition backing your root, such as `nvme0n1p2`.
- `<root-mapper>` → its unlocked name under `/dev/mapper/`, such as `root` or `luks-…`.
- `<efi-partition>` → your EFI System Partition, usually `vfat` and mounted at `/boot`.
- `<LUKS-UUID>` → the encrypted partition's UUID, **not** the mapped Btrfs filesystem UUID. Print it with:

```bash
sudo cryptsetup luksUUID /dev/<luks-partition>
```

### TPM2 automatic LUKS unlocking

For LUKS2 with a TPM2, enrollment and boot configuration are separate. Use the encrypted partition identified above:

```bash
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

Boot an Arch Linux live USB and use its root shell. Identify the partitions using [the device names above](#device-names-and-luks-uuid).

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

Use `limine-update` or `limine-mkinitcpio` for rebuilds so the installed Limine hooks run. Check the output before leaving.

```bash
exit
umount -R /mnt
reboot
```

### From a Snapper snapshot

With Snapper enabled, reboot and **press any key as Limine starts**. Tap an arrow key repeatedly to catch the **0.5-second timeout** and reveal the boot menu. Open **Snapshots**, select a snapshot, and boot it.

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

Setup-script tests require Python 3.11+, Loguru (`python-loguru`), Bash, and chezmoi; static checks also require ShellCheck.

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
- **Fingerprint:** setup offers enrollment only with its fingerprint packages installed and a detected reader without enrolled prints. Touch the reader when prompted, or run `fprintd-enroll` later.
- **WARP:** setup registers it once without connecting. Connect manually when wanted.

## Credits

- [Noctalia](https://github.com/noctalia-dev/noctalia) → bar, desktop shell, and theming.
- [Matt-FTW's dotfiles](https://github.com/Matt-FTW/dotfiles) → some application configurations.
