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

The shell entry point checks `python`, `python-loguru`, `git`, `base-devel` and `mise`, adding `rbw` and `pinentry` only for personal setups. It installs missing packages in one native Pacman transaction before Python starts. The next before-script, `.chezmoiscripts/linux/run_before_00_authentication.py`, configures private logging and personal-only Bitwarden authentication; it does not install prerequisites again. Desktop package selection stays in Mise.

Common services and Fish login-shell setup apply to both profiles. `mise/config.personal.toml` adds the existing WARP and UFW service declarations only in the personal environment; the firewall phase remains personal-only. Fish's interactive configuration stays under Chezmoi.

## Package execution and early XDG setup

Chezmoi directly runs `.chezmoiscripts/linux/run_onchange_before_02_packages.py.tmpl`. It prepares the XDG paths needed by package builds, establishes Chaotic-AUR trust and configuration, completes the initial full system upgrade, and then delegates installation to Mise. Runtime and package prerequisites are established by the earlier shell bootstrap. A missing AUR helper is installed through the `aur-helper` group in `mise/conf.d/packages.toml`; an existing yay or paru is retained.

The existing `chezmoi/chaotic-aur-updated` marker under XDG state records only a successful initial upgrade. Failures retry on the next apply. Package execution state belongs to Chezmoi: changes to `mise/config.toml`, `mise/conf.d/packages.toml`, the Python run script, or the selected profile rerun the package hook. Unrelated service, theme or authentication edits do not. Add a dependency hash to that hook if package declarations move into another file.

Nonpersonal runs select only baseline packages and require no installed Vulkan provider. Zed is personal-only because its package requires a Vulkan driver. Personal runs add the declared hardware groups: Intel, the supported NVIDIA families, laptop utilities, the known Goodix reader and available Limine/mkinitcpio integration. CachyOS/Garuda keep their distribution-managed NVIDIA modules. Unknown or mixed NVIDIA architectures require manual driver setup. Existing driver-family conflicts, mismatched kernel headers and missing kernel modules still stop setup; legacy NVIDIA utilities precede the rest of that driver stack. Exact kernel/header pairs use pacman directly because Mise cannot install pacman version pins.

Early setup respects XDG overrides and prepares private GnuPG storage, Bash/Python history parents and create-only Maven settings. Only Rust/Go/GnuPG build variables are exported for package commands; application session settings stay in `environment.d/00-xdg.conf.tmpl`. Existing Maven settings are preserved, and unused tool cache directories are left for their tools to create.

`OFFLINE` continues to control supported external downloads; it does not turn package setup into an offline installer. Pacman/AUR still need the packages and repository access they normally require. Package commands remain unattended (`--yes`/`--noconfirm`); sudo authentication is still required. Mise applies missing packages without `--update`, avoiding a separate database refresh or partial system upgrade.

## Personal sudo and Pacman policy

The direct Python before-scripts `01_sudo` and `03_pacman` remain personal-only through early runtime guards. Sudoers retains `passwd_timeout=0`, `passwd_tries=10` and preservation of `EDITOR`/`VISUAL`; faillock retains `deny=20`, `unlock_time=120` and `fail_interval=900`. All sudoers candidates and the existing policy are checked with `visudo` before activation, with a full-policy check afterward.

Pacman enables its existing Color, VerbosePkgLists and ParallelDownloads settings, keeps the configured download count, adds ILoveCandy and places the exact packaged mirrorlist exclusion last in `[options]`. Native `pacman-conf` parsing accounts for included NoExtract entries. Paccache keeps two versions. Mise still owns the declared cache hooks and Reflector files, followed by a systemd daemon reload; mirrors and unrelated repositories are preserved.

Each policy hook authenticates through native sudo before one synchronous privileged Python invocation. Shared `lib/policy_files.py` snapshots the affected files, preserves metadata, rejects unsafe targets and publishes atomically only if the target still matches its snapshot. Failure rolls back only this invocation's versions; intervening edits are preserved and reported. Unchanged reapplication does not rewrite policy files or log changes. A later Mise/reload failure remains retryable with the successfully published Pacman settings retained.

## Common services and Fish

The Python service after-hook (`14_services`) runs native Mise service and login-shell provisioning for both profiles. Common system units are NetworkManager, Bluetooth, `fstrim.timer`, `reflector.timer`, `pacman-filesdb-refresh.timer`, `paccache.timer` and `pkgfile-update.timer`. The existing disabled/masked `systemd-networkd-wait-online.service` policy is retained. Personal-only WARP, SSH agent and NVIDIA sleep services keep their existing enrollment or hardware boundaries. UFW rules/activation and Ly lifecycle remain personal-only and unchanged.

A short state-aware loop retains the existing packaged user units: GNOME Keyring's socket/service, MPRIS proxy and udiskie. System services run first; healthy user units are not re-enabled or restarted, and unavailable optional units are skipped. These are existing unit identities, rather than newly generated Mise user services. Personal snapshot exclusions for locate and avatar assignment remain gated. Nonpersonal Reflector uses its packaged defaults; the existing personal Pacman/Reflector customization remains in its earlier phase.

Fish remains fixed at `/usr/bin/fish`, installed by the common package declarations. Setup rejects root and a missing/non-executable Fish binary before applying workstation tasks. Mise reads the current account's login shell, validates its shell-list entry and changes it only when needed; chsh authentication remains native. The new login shell takes effect at the next login. No other account is selected through shell environment variables.

## Common desktop

Both profiles receive the existing GTK/Qt appearance, Nautilus preferences, MIME associations, XDG integration, terminal and editor configuration. The independent Python Nautilus hook (`06_nautilus`) runs before consolidated desktop theming (`06_theming`), so icon/font failures do not prevent its preferences from applying. Both read managed preferences before setting them; GSettings and its installed schemas/session must be usable. The root GTK mirror remains personal-only, follows the current GTK theme/dark preference and links to the regular account's Noctalia CSS. Its settings use guarded atomic publication; correct files and links remain untouched. Private identities/accounts stay personal. The fixed Dell/laptop monitor placement, dual-display workspace automation and movie-mode binding are personal-only; both profiles retain the existing automatic output fallback and general workspace appearance.

Mise supplies the existing theme and font packages. Chezmoi externals retain Apple Color Emoji and Maple Mono downloads (336-hour refresh) and macOS cursor downloads (744-hour refresh). The consolidated theming hook invokes the upstream MacTahoe installer through a space-free temporary clone and destination alias into the XDG data icons directory; Noctalia's runtime recoloring, cursor mappings and light/dark switching remain separate and unchanged. Unrelated package changes do not rerun desktop theming. GTK font/profile or `OFFLINE` changes can rerun it, but each asset independently checks completion. MacTahoe records successful installation in `$XDG_STATE_HOME/chezmoi/mactahoe-installed` (default `~/.local/state`) and verifies the default, light and dark variants' indexes, icon caches, applications and cursor directories before skipping. An interrupted/partial install remains retryable. There is no scheduled MacTahoe refresh; a deliberate upstream refresh requires invalidating its completion record and explicitly re-executing the theming hook.

SF Pro Text still comes from Apple's official DMG and installs under `~/.local/share/fonts/SF-Pro-Text`. Its checksum manifest skips intact fonts; completion is recorded only after the font cache refresh succeeds. `OFFLINE` skips missing SF Pro and MacTahoe downloads, as well as the existing externals; removing it makes the consolidated hook eligible again. A correctly installed SF Pro collection is not downloaded or cached again. Failed hooks remain retryable through Chezmoi.

## Python execution

The prerequisite installer remains shell because Python may not exist yet. Authentication runs next on every personal apply. The personal sudo/faillock policy runs before packages; personal Pacman policy runs after packages, and Snapper remains a personal-only after-script. Chezmoi explicitly uses `/usr/bin/python3 -B` for Python scripts. Public package/desktop setup stays available to both profiles.

The workflows live directly in `.chezmoiscripts/linux/`; the shared `configure_logging()` implementation lives in `.chezmoitemplates/lib/provision_logging.py`. Every Python provisioning entry point resolves and validates Chezmoi's native `CHEZMOI_SOURCE_DIR` once inside `main()`. It adds `.chezmoitemplates` to its import path and passes required paths to functions explicitly, independently of the working directory and global `PYTHONPATH`. Ordinary library files cannot live under `.chezmoiscripts/`, where Chezmoi requires scripts.

Chezmoi executes temporary rendered files. Snapper locates its retained boot helper in the real source directory and waits for its privileged fstab self-invocation to finish before Chezmoi removes the temporary script. The privileged branch retains its root check and avoids configuring logs in the regular account's private directory.

Chezmoi exports `DOTFILES_PERSONAL_ENABLED` as exactly `"0"` or `"1"` and `DOTFILES_DISTRO_FAMILY` as `"arch"`. The former gates personal bootstrap prerequisites and the plain authentication/sudo workflows; the latter remains consumed by Secure Boot. Chezmoi's own source-directory environment remains unchanged; no duplicate source-path export is needed.

Authentication and sudo/faillock check the profile before logging, imports of provisioning helpers or any personal operation. Disabled mode exits quietly; missing/malformed state fails with a diagnostic. The privileged sudo child receives the source path and validated profile as explicit arguments and still requires root. Sudo's plain `run_onchange` hook tracks source edits, not environment-only profile changes; profile transitions remain unsupported, so use manual cleanup or a fresh install. Reapplying a fixed profile remains idempotent.

Runtime profile selection comes from `scriptEnv`; Python reads the distribution ID, working tree and source path from Chezmoi's existing environment where needed. Templates track the same values and declaration hashes through safely encoded, single-line dependency comments. `OFFLINE` and `NOCONFIRM` keep their existing runtime meanings.

Privileged Python children receive an explicit absolute source-directory argument and validate it before imports or system writes; they do not depend on sudo preserving the environment. Prior source-path triggers remain as comments, preserving `run_onchange` eligibility. No duplicate source export or discovery subprocess is needed. GTK's complete font name remains a rendered value: `.chezmoidata` is unavailable while the init configuration template runs, and `scriptEnv` values are literal rather than dynamically re-rendered. Keeping that value in the hook preserves font-data changes without stale exports or a custom loader. GTK and locate children receive validated personal context explicitly. Validation also checks unrendered Python templates whose Go syntax is confined to comments.

Run-script contents and existing configuration inputs control reapplication. Package declarations and profile/distro selection retain their meaningful triggers; shared logging changes do not automatically rerun package or filesystem provisioning. Deliberate helper-only reruns can use a scoped Chezmoi state reset. No library-wide fingerprint scheme is used.

## Bootstrap logs

Python provisioning workflows use the shared Loguru configuration. Terminal messages show time, level and a short action or error; color is enabled only on a suitable TTY and respects `NO_COLOR`. Successful checks stay quiet. Deferred Bash provisioning retains its existing logging.

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

The personal Snapper workflow checks its runtime profile before logging or system inspection and runs directly from `.chezmoiscripts/linux/run_onchange_after_01_snapshots.py.tmpl`. Python verifies a writable Btrfs root mounted from `@`, validates existing `root`/`/.snapshots` state, and lets native Snapper create its configuration and snapshot subvolume. Conflicting layouts or orphaned snapshot trees stop setup for manual inspection; nothing is deleted or adopted automatically. CachyOS/Garuda retain their existing preconfigured-Snapper skip.

Snapper's number cleanup (limit 10), disabled timeline creation and empty pre/post cleanup (minimum age 1800 seconds) are unchanged. Only differing settings are applied. The two snapshot units remain enable-only; healthy units are untouched. Locate snapshot exclusions stay in the existing personal services hook.

Root's explicit `relatime` fstab option becomes `noatime` through a guarded atomic edit that preserves ownership/mode and other mount entries, including `@swap`. Reload failures restore this invocation's edit while preserving intervening manual changes. Failures stop setup and remain retryable through Chezmoi. There are no new completion markers. Python uses the existing private Loguru logs; sudo authentication stays native.

Snapshot boot configuration now lives in `.chezmoitemplates/lib/snapshot_boot.py`, invoked through the Snapper entry point with explicit privileged arguments. Limine settings, overlay selection and pending rebuild coordination are preserved. The late Python rebuild consumes the shared pending request after all boot configuration hooks.

## Laptop power management

The personal `run_onchange_after_02_laptop_power.py` hook uses `hostnamectl chassis` and skips non-laptops before any download or privileged operation. Failed hardware inspection stops setup. Nonpersonal installs skip the hook before logging or inspecting hardware.

A missing `/usr/local/bin/auto-cpufreq` is installed from the latest stable upstream Git release, using a full checkout for upstream version detection. The source installer installs the application; the installed CLI's `--install` then deploys its daemon. This two-step contract was verified against [auto-cpufreq v3.2.0](https://github.com/AdnanHodzic/auto-cpufreq/tree/v3.2.0). Upstream owns unit creation, enablement/start and power-manager integration: it disables supported power-profiles-daemon/tuned services and warns about TLP. It also disables Bluetooth autostart when Bluetooth support is present; setup no longer overrides that upstream choice. Use upstream's `sudo auto-cpufreq --bluetooth_boot_on` if wanted.

The hook only reads daemon activity because upstream refuses `--install` while already running. Inactive or missing daemons use the official installer, including after a failed attempt; inspection errors fail explicitly. Dotfiles do not unmask or activate the service themselves, and Mise has no auto-cpufreq declaration. Native installer output and sudo prompts stay visible. Source checkouts are removed after each attempt, including root-owned build files. Existing application installations are reused rather than automatically updated; use upstream's update workflow deliberately. Chezmoi caches successful runs and retries failures on the next apply without extra state markers.

## Managed laptop hibernation

The personal `run_onchange_after_03_hibernation.py.tmpl` workflow supports Limine, mkinitcpio and the existing single-device Btrfs laptop layout, either plain or directly LUKS-backed. Non-Btrfs systems and non-laptops skip it. A supported Btrfs laptop requires working Limine and mkinitcpio before setup can continue. Independently managed swap/resume settings, unsupported device topologies and swapfiles without a matching ownership record remain untouched for manual setup.

Native Btrfs creates `@swap` and `/swap/swapfile` only when missing. The size formula remains rounded-up RAM in GiB plus the rounded square root of that RAM, with a 2 GiB minimum. Existing managed files are never resized or reformatted. Filesystem/block-device UUIDs, mount identity, link count and native `map-swapfile` suitability/offset checks precede activation and resume publication. Guarded fstab edits preserve unrelated entries and intervening changes; temporary top-level mounts are checked and cleaned up even after interruption.

State stays under `$XDG_STATE_HOME/chezmoi` (default `~/.local/state/chezmoi`). `hibernation.swapfile` records the verified filesystem UUID, path and inode. The change-triggered after-hook checks the profile and supported laptop layout, and inspects/reuses actual managed swap state. Complete setup and verified manual/unsupported outcomes exit zero and are not repeated unchanged. Missing Limine/mkinitcpio or unverifiable persistent arguments fail explicitly; command failures preserve their nonzero status. Failed hooks remain eligible for native Chezmoi retry without script edits or markers. A nonzero result stops the current apply before later hooks, including the late initramfs rebuild; resolve the prerequisite/conflict and reapply. No hibernation retry counter or completion marker is used. `initramfs.pending` is never cleared by this workflow: the late verified rebuild is the only workflow that clears the request.

The entry point keeps profile/source validation, native sudo boundaries, logging, prerequisites and high-level swap/resume orchestration visible. Three cohesive modules under `.chezmoitemplates/lib/` hold the details: `hibernation_swap.py` owns Btrfs/LUKS identity, swap ownership and safe fstab/mount handling; `hibernation_policy.py` owns resume, Zswap, sleep and rebuild requests; `hibernation_nvidia.py` keeps NVIDIA sleep services in Mise and publishes PCI power policy. Explicit dependency comments track these implementation files and the NVIDIA declarations, without hashing unrelated shared libraries.

Zswap runs only after managed swap/resume succeeds, requires at least 30 GiB RAM and skips available/configured Zram without changing it. Existing Zswap preferences, including explicit disablement, remain intact. The existing `zswap.conf` Limine fragment retains `zswap.enabled=1 zswap.compressor=lz4`; no `/etc/cmdline.d` or replacement kernel-command-line mechanism is introduced. Eligible Zswap configuration failures stop setup after preserving or rolling back their own edits; existing managed swap/resume state is safely reused on reapplication.

Systemd sleep/logind policy and USB wakeup rules are unchanged. NVIDIA detection still gates its existing Mise-owned sleep units, which stay enabled but stopped outside sleep transactions, and its PCI power-control tmpfiles entry. The persistent Limine parser lives in `.chezmoitemplates/lib/limine_cmdline.py` and is shared with early initramfs and quiet-boot configuration. Hibernation only requests rebuilding; the late boot hook deploys and verifies artifacts. Setup never attempts suspend or hibernation.

## Boot configuration

Direct Python Chezmoi hooks run in this order: `00_initramfs_config`, `01_snapshots`, `03_hibernation`, `04_quiet_boot`, `05_secure_boot`, `08_limine_theme`, `13_initramfs`, then `99_finalize`. Configuration hooks use `run_onchange`: failures halt the apply and remain eligible for retry. `run_after_13_initramfs.py` runs on every apply but does nothing without `initramfs.pending`.

Early configuration preserves the systemd base hooks, optional graphics/Plymouth settings, independent snapshot overlay and verified LUKS root policy. Trusted mkinitcpio configuration and its generated drop-ins remain Bash syntax because that is mkinitcpio's native format. Quiet-boot preferences stay in `20-quiet-boot.conf`; they never rewrite `/etc/kernel/cmdline`. Existing installer unlock conversion remains a guarded early transaction; TPM2 tokens, PCR policies and recovery credentials remain manually managed.

The late rebuild verifies the mounted FAT32 ESP's device/UUID identity, invokes `limine-install --no-efi-register` and `limine-mkinitcpio`, then checks generated entries, kernel payloads and initramfs contents. Package post-hooks enroll the final Limine config checksum and sign afterward. When checksum enrollment is enabled, setup verifies that checksum and requires positive sbctl signature results for each managed EFI/UKI artifact. It clears the existing request only after verification; failures and changed requests preserve it. Reapplication without a request does not regenerate boot artifacts.

`/boot` is the EFI system partition and lies outside Btrfs snapshots. Restoring a root snapshot does **not** restore matching kernels or initramfs files on the ESP. Preserve the existing recovery procedure and rebuild/verify the corresponding installed artifacts before assuming a rollback is bootable.

Secure Boot key enrollment requires UEFI Setup Mode, Secure Boot disabled, and an explicit interactive confirmation. Unattended first-time enrollment fails with guidance. Existing signing material is reused; incomplete key directories are preserved and rejected before key creation. Microsoft certificates are retained, and firmware-builtin certificates follow the existing vendor rule. Signing alone does not enable firmware Secure Boot. Finalization only offers a reboot; unattended applies never reboot automatically.


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

`python3 -B .github/tests/validate.py` coordinates these checks plus both profiles of rendered Python run scripts and settings modifiers, shell/Python syntax and Mise TOML validation. It runs pytest once; do not run the suite again through unittest. `ruff.toml` and `pyproject.toml` target Python 3.14; pytest discovers the retained tests under `.github/tests`. Native pytest migration remains a separate task.

BasedPyright explicitly includes `.github/tests`, `home/.chezmoiscripts` and `home/.chezmoitemplates/lib`; confirm actual discovery with `basedpyright --verbose`. BasedPyright 1.40.2 (Pyright 1.1.414) has the [upstream hidden-directory regression](https://github.com/microsoft/pyright/issues/11861): it checks zero files and rejects `useDefaultExcludes`. That installation cannot validate this layout; the validator fails rather than accepting an empty check. The option is appropriate only with a checker release that supports it. Tool versions are managed externally, with no pinned installer or fallback here. Kitty's embedded module and the separate theme updater retain Ruff/syntax checks outside the provisioning type-check scope.

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
