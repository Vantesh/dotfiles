# Dotfiles

My Arch-based workstation with Hyprland, Noctalia, Fish and Kitty, managed using Chezmoi, Mise and Python.

Built for my own machines, not as a general-purpose installer.

## Installation

Start with a fresh Arch-based installation, network access and a regular user with sudo access.

\`\`\`bash
sudo pacman -Syu --needed chezmoi
chezmoi init --apply vantesh
\`\`\`

Setup asks whether this is a personal installation:

- **Nonpersonal:** Common packages, dotfiles, themes, fonts, Fish, services, Noctalia Greeter and WARP registration (without connecting).
- **Personal:** Everything above, plus private configuration, hardware drivers, firewall rules, Btrfs/Snapper, hibernation, Secure Boot and automatic fingerprint enrollment on supported hardware.

Personal setup requires my Bitwarden credentials and makes system-level changes. Choose **No** if you're installing these dotfiles on your own machine.

Both profiles enable Chaotic-AUR, update packages and install Paru through Mise when needed.
AUR builds run as the regular user. Existing Yay installations are left untouched;
Mise's upstream AUR backend still prefers Yay if both helpers are available.
The setup requires Python 3.14, Mise 2026.10.20 or newer, and a working systemd user session.

## Configuration

Each tool has its own role:

- **Chezmoi:** Managed files, templates, profiles and apply lifecycle in [home/](../home/).
- **Mise:** Tool versions, packages, services and tasks in [mise/](../mise/).
- **Python:** Reusable provisioning implementation in [src/dotfiles/](../src/dotfiles/).

To review or apply changes:

\`\`\`bash
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
\`\`\`

Edit configuration in the Chezmoi source directory (\`chezmoi cd\`). Failed setup scripts can be retried with \`chezmoi apply\`.

Logs are stored at \`~/.local/state/chezmoi/logs/setup.log\`, or under \`$XDG_STATE_HOME\` when set.

\`OFFLINE=1\` skips supported external downloads, not package installation. \`NOCONFIRM=1\` skips optional prompts and fingerprint enrollment.

Personal fingerprint setup starts native capture automatically for an unenrolled,
supported Goodix 27c6:5395 reader. Follow \`fprintd-enroll\`'s touch/lift instructions;
there is no separate confirmation. Existing prints are preserved. Unsupported or
unavailable readers, CI, \`NOCONFIRM=1\` and sessions without a terminal skip capture.

## Boot configuration

Personal setup supports Btrfs with the \`@\` root subvolume, Snapper and hibernation on supported laptops. Existing unmanaged swap and resume settings are left alone.

Secure Boot setup requires UEFI Setup Mode with Secure Boot disabled. The installer creates and enrolls keys automatically when needed, including Microsoft and supported firmware certificates.

**Enable Secure Boot in firmware only after setup finishes and the boot files are verified.**

The EFI partition is normally mounted at \`/boot\`, outside Btrfs snapshots. Restoring a snapshot doesn't restore the matching kernel or initramfs.

Rebuild boot files with:

\`\`\`bash
sudo limine-update
\`\`\`

## Development

The development environment is managed by Mise and uv:

- Mise selects Python, uv, Ruff and BasedPyright versions.
- uv creates the project environment and installs the locked Python dependencies.
- \`pyproject.toml\` defines project metadata, dependencies and Python tool configuration.
- \`uv.lock\` records the resolved Python dependency versions.

Use Mise tasks for the documented development workflow. Python commands run through \`uv run\`, so manual environment activation and hardcoded \`.venv\` paths are unnecessary.

See [AGENTS.md](../AGENTS.md), [architecture.md](../docs/architecture.md) and [migration-plan.md](../docs/migration-plan.md) for development constraints and migration details.

## Shell integration

Bash and Fish startup files activate Mise automatically.

If Mise asks you to trust the repository configuration, run:

\`\`\`bash
mise trust
\`\`\`

For Zsh, add this to \`~/.zshrc\`:

\`\`\`zsh
eval "$(mise activate zsh)"
\`\`\`

For editors and GUI applications that do not read shell startup files, use shims:

\`\`\`bash
eval "$(mise activate bash --shims)"
\`\`\`

Fish equivalent:

\`\`\`fish
mise activate fish --shims | source
\`\`\`

Development tools are selected only inside this repository. CI must not depend on shell activation.

## Credits

- [Noctalia](https://github.com/noctalia-dev/noctalia) provides the desktop shell and theming.
- [Matt-FTW's dotfiles](https://github.com/Matt-FTW/dotfiles) for some desktop configs.
