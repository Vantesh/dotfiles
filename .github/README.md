![Hyprland desktop](https://github.com/user-attachments/assets/093b4800-a1ec-49d2-b169-f6b6293cf2c0)

# Hyprland dotfiles

My Arch Linux setup: Hyprland, Noctalia, Fish, and Kitty. Managed with chezmoi.

## Fresh install

Back up my existing config first. Run as regular user with sudo access.

```sh
sudo pacman -S --needed chezmoi
chezmoi init --apply vantesh
```

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

## Initramfs migration

The three setup components have separate responsibilities:

- **Initramfs:** `00-chezmoi-systemd.conf` owns the systemd base hooks, with
  `sd-encrypt` only for a verified single-device LUKS-backed Btrfs root. Plymouth
  remains optional. Other settings and compatible hook contributions are kept;
  a later replacement of the base array stops the apply before publication.
- **Snapper:** its own `snapper.conf` selects the snapshot overlay from the
  effective initramfs environment and adds it once. With the managed systemd
  base, Snapper selects `sd-btrfs-overlayfs`; its standalone selector handles an external
  non-systemd environment. Snapper's feature gate is independent of hibernation.
- **Hibernation:** manages only the existing Btrfs swapfile layout, safe reuse,
  resume parameters and retry state. `resume=UUID=` uses the **unlocked Btrfs
  filesystem UUID**, not the LUKS UUID. The offset comes from `map-swapfile -r`.
  Systemd supplies resume support; hibernation does not inspect or write hooks.

**Encrypted-root unlocking is user-managed.** Before applying, establish a
matching systemd early-unlock definition in persistent Limine defaults (for
example `rd.luks.name=<LUKS-superblock-UUID>=root`) or an included crypttab entry
with the correct UUID/mapping and `x-initrd.attach`. The installed `sd-encrypt`
hook gives `/etc/crypttab.initramfs` precedence over `/etc/crypttab`. An ordinary
host crypttab entry without early inclusion is insufficient. The setup performs
a read-only presence check and rejects destructive/non-LUKS root modes; it never
configures TPM2, keyfiles, credentials or unlock arguments, and never translates
legacy `cryptdevice=` policy. Encrypted-root preflight also requires explicit
persistent Limine defaults, rather than relying on a running/rescue boot.
Verify authentication, required initramfs assets and recovery/password fallback
yourself, especially when TPM PCR policy may be affected by rebuilt boot images.
Custom UKI options cannot bypass the managed config, command line or signing.

If the earlier migration was applied, review and retire the superseded
`zz-chezmoi-systemd.conf` before retrying, preserving any local changes. It must
not replace the new earlier base and erase Snapper's independent contribution.
Unknown user drop-ins are never deleted automatically. If an existing legacy
snapshot hook would disappear, preflight requires Snapper's independent selector
rather than silently disabling snapshot boot.

Changed configuration queues the existing late Limine rebuild, signing and
artifact-verification flow; identical configuration does not queue another build.
Before rebooting, verify successful rebuild/signing, hooks, unlock configuration,
and resume UUID/offset. Development tests never publish live boot artifacts.

## Script tests

Tests cover only chezmoi setup scripts and their shared helpers, not application
dotfiles. Requires Python 3.11+, Bash, and chezmoi; static validation also needs
ShellCheck. Run manually with:

```sh
python3 -B -m unittest discover -s .github/tests -v && python3 -B .github/tests/validate.py
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
