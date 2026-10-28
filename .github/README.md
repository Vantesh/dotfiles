# Dotfiles

My Arch-based workstation: Hyprland, Noctalia, Fish and Kitty, managed with chezmoi, Mise and Python. This is an opinionated personal setup, not a general-purpose installer; support is best effort on the machines I use.

## Installation

Start with a fresh, bootable Arch Linux or Arch-based installation, network access and a regular account with sudo access. Run setup from that account, not root. Desktop preferences and user services require a working user session, D-Bus and systemd user manager.

```bash
sudo pacman -Syu --needed chezmoi
chezmoi init --apply vantesh
```

The shell bootstrap installs missing prerequisites in one Pacman transaction before Python provisioning starts. Python 3.14 and Mise **2026.10.20 or newer** are required; the managed shell configuration targets Noctalia **5.4**. Packages come from the configured repositories, so an older packaged Mise must be updated before setup can finish.

**Both profiles enable Chaotic-AUR and its signing trust, perform an initial full system upgrade, and install an AUR helper if needed.** Package installation uses native unattended options; sudo, vault authentication and optional fingerprint enrollment can still require interaction.

Setup asks **“Is this a personal setup?”**, defaults to No, and saves the answer:

- **Nonpersonal:** common packages and nonsecret dotfiles, desktop themes/fonts, Fish as the login shell, common system/user services, Noctalia Greeter through greetd, and WARP device registration without connecting. No Bitwarden access or personal hardware, firewall, filesystem or boot provisioning.
- **Personal:** everything above, plus private configuration, declared hardware drivers, personal services/firewall, supported Btrfs/Snapper and laptop hibernation, boot/Secure Boot setup, and optional fingerprint enrollment.

**Answer No unless you are using my private setup.** Personal mode expects my exact Bitwarden entries and fields, and makes privileged system changes. It is not a menu of optional provisioning features.

Repeated application of the selected profile is supported. Existing dotfiles versions and switching profiles are unsupported; use manual cleanup or a fresh installation. Other operating systems are unsupported.

## Responsibilities

- **Chezmoi** manages files, profile selection, script ordering and change-triggered execution under [home/](../home/).
- **Mise** declares packages, system/user services, the Fish login shell and firewall policy under [mise/](../mise/).
- **Python** coordinates provisioning and safety checks in [the setup scripts](../home/.chezmoiscripts/linux/), with domain helpers under [lib/](../home/.chezmoitemplates/lib/). The initial prerequisite installer remains Bash because Python may not exist yet.

Common package installation does not detect GPUs or require an installed Vulkan provider. Personal driver selection retains the existing Intel/NVIDIA support and CachyOS/Garuda policies; unknown or mixed NVIDIA families need manual setup.

## Applying changes

```bash
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
chezmoi apply --exclude=scripts
chezmoi cd
```

Edit managed templates and Mise declarations in the source repository. Failed hooks stop the apply and remain eligible for retry: fix the reported problem and rerun `chezmoi apply`. Successful change-triggered scripts are cached; the late boot rebuild checks for outstanding work on every apply.

Provisioning logs live at `$XDG_STATE_HOME/chezmoi/logs/setup.log`, defaulting to `~/.local/state/chezmoi/logs/setup.log`. Logs are private and rotated; vault contents and credentials are excluded. Package-manager output and interactive prompts remain native.

`OFFLINE=1` skips supported external asset downloads; it does not make package installation offline. `NOCONFIRM=1` suppresses optional setup prompts and first-time fingerprint enrollment, but does not bypass authentication. Personal-profile Secure Boot provisioning does not ask for separate enrollment consent.

Greetd is configured for the next boot in **both** profiles. Recognized competing display managers are disabled without stopping the running session or forcing an alias overwrite. Resolve any setup failure before rebooting. Fish takes effect on the next login; first-time WARP registration accepts its terms but leaves the tunnel disconnected. Personal greeter appearance authorization is limited to the selected account.

Atuin is personal-only. Its single managed configuration stays at `~/.config/atuin/config.toml`, even with a different `XDG_CONFIG_HOME`; native environment settings place data and logs under XDG data/state paths.

## Personal system requirements

The dotfiles do not partition disks or create the base installation. Snapper expects a writable Btrfs root mounted from `@`; conflicting snapshot layouts are left for manual inspection. Managed hibernation targets supported single-device Btrfs laptops, plain or directly LUKS-backed, with Limine and mkinitcpio already working. Existing unmanaged swap/resume configuration is preserved rather than adopted. Unsupported hardware may need manual configuration.

First-time Secure Boot enrollment requires **UEFI Setup Mode and Secure Boot disabled**. Personal-profile provisioning automatically initializes local keys when needed and enrolls them in Setup Mode, replacing firmware key databases with the configured local/Microsoft certificates and applicable vendor certificates. Enable Secure Boot in firmware only after setup and boot verification succeed. TPM2 unlock enrollment and PCR policies remain manual; keep a working LUKS password or recovery key.

Quiet boot sets `systemd.tpm2_measured_os=0`, disabling systemd's additional measured-OS services. This affects TPM measurements, not just logging. Laptop auto-cpufreq uses its upstream installer, including upstream power-service and Bluetooth-autostart policy. Fingerprint enrollment is limited to the declared Goodix reader/driver and does not enable fingerprint PAM authentication.

## Boot recovery

The usual layout mounts the FAT32 EFI System Partition at `/boot`, outside Btrfs snapshots. Restoring a root snapshot does **not** restore matching kernels or initramfs files there. After correcting boot configuration, use the installed Limine tooling rather than invoking mkinitcpio directly:

```bash
sudo limine-update
```

If the installation will not boot, start an Arch live USB. Identify the root and EFI partitions with `lsblk -f`. For a LUKS-backed root, the following is a **template**: replace `LUKS_PARTITION` and `EFI_PARTITION` with the actual partition names before running it in the live environment's root shell.

```bash
cryptsetup open /dev/LUKS_PARTITION root
mount -o subvol=@ /dev/mapper/root /mnt
mount --mkdir /dev/EFI_PARTITION /mnt/boot
arch-chroot /mnt
# Inspect and repair /etc/limine-entry-tool.d/01-default.conf and /etc/kernel/cmdline.
limine-update
exit
umount -R /mnt
reboot
```

For a plain Btrfs root, mount its block device directly and omit `cryptsetup`; use the installation's actual ESP mount point. Verify the rebuild output before rebooting. From a booted Snapper overlay, mount the installed `@` root and ESP and repair through `arch-chroot` rather than changing the temporary overlay; `arch-chroot` requires `arch-install-scripts` in that environment. Limine's menu timeout is 0.5 seconds; tap an arrow key during startup to reach snapshot entries.

## Validation

Provide Python 3.14, Loguru, Ruff, BasedPyright, pytest 9+, chezmoi, Bash and ShellCheck separately; this repository does not install a development environment. From the repository root:

```bash
python3 -B .github/tests/validate.py
```

This runs lint/format checks, type checking, pytest, rendered-template checks for both profiles, Bash/ShellCheck and Mise TOML syntax validation. It does not provision the host or prove that hardware-specific setup works. [AGENTS.md](../AGENTS.md) describes maintenance and safety conventions.

GitHub Actions uses `archlinux:latest` and installs the validation toolchain explicitly before running the same checks under an unprivileged account with an isolated home. BasedPyright is pinned to a version that analyzes the hidden source/test directories. Local validation and fresh-install testing remain necessary.

## Credits

[Noctalia](https://github.com/noctalia-dev/noctalia) provides the desktop shell and theming. Some application configurations originated in [Matt-FTW's dotfiles](https://github.com/Matt-FTW/dotfiles).
