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

- **Nonpersonal:** installs common packages and nonsecret dotfiles, applies common system/user services, sets Fish as the login shell and configures the common desktop, including public fonts, icons and cursor themes. It does not access Bitwarden, provision personal services, drivers, firewall or the login manager, modify boot/filesystem/firmware settings, enroll devices, or reboot.
- **Personal:** adds private configuration and the existing driver, Btrfs/Snapper, swapfile/hibernation, Zswap, Limine/Secure Boot and personal service provisioning. Hardware and system-integrity checks still apply. Authentication and enrollment can require interaction.

Both profiles support repeated application. Previous dotfiles versions and profile transitions are unsupported; use manual cleanup or a fresh installation rather than expecting migration. Nonpersonal installs retain the existing package prerequisites, including Chaotic-AUR trust/repository setup, the initial full system upgrade, and an AUR helper.

> [!WARNING]
> **If you are not me, answer No to “Is this a personal setup”.** This option is for me only. It expects my private Bitwarden entries and their exact fields; missing or incorrect entries will make setup fail.

## Customizing the setup

Mise files in the repository (`chezmoi cd`):

- `mise/config.toml` → required Mise version.
- `mise/conf.d/packages.toml` → baseline packages and personal hardware groups.
- `mise/conf.d/services.toml` → system services and timers.
- `mise/conf.d/login-shell.toml` → sets Fish as the default login shell (`/usr/bin/fish`).
- `mise/conf.d/firewall.toml` → firewall rules.
- `mise/conf.d/pacman-hooks.toml` → package-cache cleanup hooks.

The shell entry point checks `python`, `python-loguru`, `git`, `base-devel` and `mise`, adding `rbw` and `pinentry` only for personal setups. It installs missing packages in one native Pacman transaction before Python starts. Python then configures private logging and personal-only Bitwarden authentication; it does not install prerequisites again. Desktop package selection stays in Mise.

Common services and Fish login-shell setup apply to both profiles. `mise/config.personal.toml` adds the existing WARP and UFW service declarations only in the personal environment; the firewall phase remains personal-only. Fish's interactive configuration stays under Chezmoi.

## Package execution and early XDG setup

Chezmoi’s package before-hook runs `.chezmoitemplates/packages.py`. It prepares the XDG paths needed by package builds, establishes Chaotic-AUR trust and configuration, completes the initial full system upgrade, and then delegates installation to Mise. Runtime and package prerequisites are established by the earlier shell bootstrap. A missing AUR helper is installed through the `aur-helper` group in `mise/conf.d/packages.toml`; an existing yay or paru is retained.

The existing `chezmoi/chaotic-aur-updated` marker under XDG state records only a successful initial upgrade. Failures retry on the next apply. Package execution state belongs to Chezmoi: changes to `mise/config.toml`, `mise/conf.d/packages.toml`, the coordinator, or the selected profile rerun the package hook. Unrelated service, theme or authentication edits do not. Add a dependency hash to that hook if package declarations move into another file.

Nonpersonal runs select only baseline packages and require no installed Vulkan provider. Zed is personal-only because its package requires a Vulkan driver. Personal runs add the declared hardware groups: Intel, the supported NVIDIA families, laptop utilities, the known Goodix reader and available Limine/mkinitcpio integration. CachyOS/Garuda keep their distribution-managed NVIDIA modules. Unknown or mixed NVIDIA architectures require manual driver setup. Existing driver-family conflicts, mismatched kernel headers and missing kernel modules still stop setup; legacy NVIDIA utilities precede the rest of that driver stack. Exact kernel/header pairs use pacman directly because Mise cannot install pacman version pins.

Early setup respects XDG overrides and prepares private GnuPG storage, Bash/Python history parents and create-only Maven settings. Only Rust/Go/GnuPG build variables are exported for package commands; application session settings stay in `environment.d/00-xdg.conf.tmpl`. Existing Maven settings are preserved, and unused tool cache directories are left for their tools to create.

`OFFLINE` continues to control supported external downloads; it does not turn package setup into an offline installer. Pacman/AUR still need the packages and repository access they normally require. Package commands remain unattended (`--yes`/`--noconfirm`); sudo authentication is still required. Mise applies missing packages without `--update`, avoiding a separate database refresh or partial system upgrade.

## Common services and Fish

The service after-hook runs native Mise service and login-shell provisioning for both profiles. Common system units are NetworkManager, Bluetooth, `fstrim.timer`, `reflector.timer`, `pacman-filesdb-refresh.timer`, `paccache.timer` and `pkgfile-update.timer`. The existing disabled/masked `systemd-networkd-wait-online.service` policy is retained. Personal-only WARP, SSH agent and NVIDIA sleep services keep their existing enrollment or hardware boundaries. UFW rules/activation and Ly lifecycle remain personal-only and unchanged.

A short state-aware loop retains the existing packaged user units: GNOME Keyring's socket/service, MPRIS proxy and udiskie. System services run first; healthy user units are not re-enabled or restarted, and unavailable optional units are skipped. These are existing unit identities, rather than newly generated Mise user services. Personal snapshot exclusions for locate and avatar assignment remain gated. Nonpersonal Reflector uses its packaged defaults; the existing personal Pacman/Reflector customization remains in its earlier phase.

Fish remains fixed at `/usr/bin/fish`, installed by the common package declarations. Setup rejects root and a missing/non-executable Fish binary before applying workstation tasks. Mise reads the current account's login shell, validates its shell-list entry and changes it only when needed; chsh authentication remains native. The new login shell takes effect at the next login. No other account is selected through shell environment variables.

## Common desktop

Both profiles receive the existing GTK/Qt appearance, Nautilus preferences, MIME associations, XDG integration, terminal and editor configuration. The GTK and Nautilus hooks read the four managed preferences before setting them; GSettings and its installed schemas/session must be usable. The existing root GTK mirror remains personal-only. Private identities/accounts stay personal. The fixed Dell/laptop monitor placement, dual-display workspace automation and movie-mode binding are personal-only; both profiles retain the existing automatic output fallback and general workspace appearance.

Mise supplies the existing theme and font packages. Chezmoi externals retain Apple Color Emoji and Maple Mono downloads (336-hour refresh) and macOS cursor downloads (744-hour refresh). The MacTahoe hook installs the upstream repository into the user's XDG data icons directory; Noctalia's runtime recoloring, cursor mappings and light/dark switching remain separate and unchanged. Unrelated package changes do not rerun the asset hooks.

SF Pro Text still comes from Apple's official DMG and installs under `~/.local/share/fonts/SF-Pro-Text`. Its checksum manifest skips intact fonts; completion is recorded only after the font cache refresh succeeds. `OFFLINE` skips missing SF Pro and MacTahoe downloads, as well as the existing externals; removing it makes those hooks eligible again. A correctly installed SF Pro collection is not downloaded or cached again. Failed hooks remain retryable through Chezmoi.

## Bootstrap logs

The Python prerequisite bootstrap and package coordinator use Loguru. Terminal messages show time, level and a short action or error; color is enabled only on a suitable TTY and respects `NO_COLOR`. Successful checks stay quiet. Later provisioning hooks still use their existing Bash logging.

Diagnostics are written to `$XDG_STATE_HOME/chezmoi/logs/setup.log`, falling back to `~/.local/state/chezmoi/logs/setup.log`. The log directory is private (`0700`); current and rotated logs are user-owned with mode `0600`. Loguru rotates at 5 MiB and retains five rotated files. The file is opened only when a message is logged, so successful no-op checks do not create or append a setup log.

Vault output, email arguments, tokens and subprocess environments are not recorded. Authentication errors report the failing operation and exit status with a retry hint; use rbw directly when deeper vault diagnostics are needed. A logging/storage error stops Python setup rather than continuing without private diagnostics. Run chezmoi as the regular account; sudo is used only for system operations. Initial prerequisite installation failures occur before the logger is available and use pacman's terminal diagnostics.

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

The personal Snapper hook is a thin launcher for `.chezmoitemplates/snapshots.py`. Python verifies a writable Btrfs root mounted from `@`, validates existing `root`/`/.snapshots` state, and lets native Snapper create its configuration and snapshot subvolume. Conflicting layouts or orphaned snapshot trees stop setup for manual inspection; nothing is deleted or adopted automatically. CachyOS/Garuda retain their existing preconfigured-Snapper skip.

Snapper's number cleanup (limit 10), disabled timeline creation and empty pre/post cleanup (minimum age 1800 seconds) are unchanged. Only differing settings are applied. The two snapshot units remain enable-only; healthy units are untouched. Locate snapshot exclusions stay in the existing personal services hook.

Root's explicit `relatime` fstab option becomes `noatime` through a guarded atomic edit that preserves ownership/mode and other mount entries, including `@swap`. Reload failures restore this invocation's edit while preserving intervening manual changes. Failures stop setup and remain retryable through Chezmoi. There are no new completion markers. Python uses the existing private Loguru logs; sudo authentication stays native.

Snapshot boot configuration remains in `.chezmoitemplates/lib/snapper_boot.sh` until Phase 6C. Its Limine settings, overlay selection and deferred rebuild behavior are unchanged. Shared boot/hibernation Bash helpers remain because those phases still consume them.

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

Validation requires separately provided Python 3.14, Ruff, BasedPyright, pytest 9+, chezmoi, Bash and ShellCheck. Python and Loguru remain runtime dependencies of the actual dotfiles bootstrap. The repository does not install development tools or manage a development environment.

```bash
ruff check .
ruff format --check .
basedpyright
pytest -q
```

`python3 -B .github/tests/validate.py` coordinates these checks plus both profiles of rendered Python settings modifiers, shell/Python syntax and Mise TOML validation. It runs pytest once; do not run the suite again through unittest. `ruff.toml` and `pyproject.toml` target Python 3.14; pytest discovers the retained tests under `.github/tests`. Native pytest migration remains a separate task.

BasedPyright explicitly includes `.github/tests` and `home/.chezmoitemplates`; confirm actual discovery with `basedpyright --verbose`. BasedPyright 1.40.2 (Pyright 1.1.414) has the [upstream hidden-directory regression](https://github.com/microsoft/pyright/issues/11861): it checks zero files and rejects `useDefaultExcludes`. That installation cannot validate this layout; the validator fails rather than accepting an empty check. The option is appropriate only with a checker release that supports it. Tool versions are managed externally, with no pinned installer or fallback here. Kitty's embedded module and the separate theme updater retain Ruff/syntax checks outside the provisioning type-check scope.

CI invokes the same validator and reports missing prerequisites. The stock Arch container does not provide the complete development toolchain; a suitable runner/image must supply it separately. This repository does not bootstrap one.

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
