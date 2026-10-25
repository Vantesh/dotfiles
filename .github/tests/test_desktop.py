"""Apply common desktop hooks in private homes without a live desktop or downloads."""

import json
import shutil
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import calls, run_setup, stub
from test_setup import env as env

HOOKS = (
    "run_onchange_after_06_gtk.sh.tmpl",
    "run_onchange_after_07_nautilus.sh.tmpl",
    "run_onchange_after_08_mactahoe_icons.sh.tmpl",
    "run_onchange_after_12_sf_pro_text.sh.tmpl",
)


@pytest.fixture
def desktop(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    for name in ("cmp", "install", "mkdir", "mktemp", "mv", "rm", "sha256sum"):
        executable = shutil.which(name)
        assert executable is not None
        (Path(env["PATH"]) / name).symlink_to(executable)
    (tmp_path / "preferences").mkdir()
    stub(env, "id", "echo 1000")
    stub(env, "rbw", "exit 97", log=True)
    stub(env, "gtk-update-icon-cache", "exit 0", log=True)
    stub(env, "fc-cache", 'exit "${CACHE_STATUS:-0}"', log=True)
    stub(
        env,
        "gsettings",
        """[ "${SETTINGS_STATUS:-0}" = 0 ] || exit "$SETTINGS_STATUS"
case "$1" in
    get)
        if test -f "$HOME/preferences/$3"; then cat "$HOME/preferences/$3"
        elif test "$3" = color-scheme; then echo "'prefer-dark'"
        elif test "$3" = gtk-theme; then echo "'adw-gtk3-dark'"
        else echo "'old'"; fi ;;
    set)
        case "$3" in
            show-delete-permanently) printf '%s\\n' "$4" ;;
            *) printf "'%s'\\n" "$4" ;;
        esac > "$HOME/preferences/$3" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        env,
        "sudo",
        """case "$1" in
    install|ln) exit 0 ;;
    tee) cat >/dev/null ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        env,
        "git",
        """for source do :; done
mkdir -p "$source"
cat > "$source/install.sh" <<'INSTALL'
set -eu
[ "$1" = --dest ] || exit 97
mkdir -p "$2/MacTahoe"
printf 'fixture icon theme\\n' > "$2/MacTahoe/index.theme"
gtk-update-icon-cache "$2/MacTahoe"
INSTALL""",
        log=True,
    )
    stub(
        env,
        "curl",
        """while [ "$#" -gt 0 ]; do
    if [ "$1" = --output ]; then shift; printf 'fixture dmg\\n' > "$1"; fi
    shift
done""",
        log=True,
    )
    stub(env, "7z", 'touch "${3#-o}/SFProFonts.pkg"', log=True)
    stub(
        env,
        "bsdtar",
        """case "$1" in
    -xOf) printf 'fixture payload' ;;
    -xf)
        cat >/dev/null
        mkdir -p "$4/Library/Fonts"
        printf 'fixture font\\n' > "$4/Library/Fonts/SF-Pro-Text-Regular.otf" ;;
    *) exit 97 ;;
esac""",
    )
    return env


def desktop_command(tmp_path: Path, personal: bool) -> list[str]:
    assert CHEZMOI is not None
    source = tmp_path / "source"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    for hook in HOOKS:
        shutil.copy(SCRIPTS / hook, scripts / hook)
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    shutil.copytree(ROOT / "home/.chezmoidata", source / ".chezmoidata")
    shutil.copytree(ROOT / "home/dot_config/hypr", source / "dot_config/hypr")
    shutil.copy(ROOT / "home/.chezmoiignore.tmpl", source / ".chezmoiignore.tmpl")
    config = tmp_path / "chezmoi.json"
    config.write_text(json.dumps({"data": {"personal": personal, "distroFamily": "arch"}}))
    return [
        CHEZMOI,
        "--config",
        str(config),
        "--source",
        str(source),
        "--destination",
        str(tmp_path),
        "--no-tty",
        "apply",
    ]


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_desktop_assets_apply_and_reapply_in_both_profiles(
    desktop: dict[str, str], tmp_path: Path, personal: bool
) -> None:
    command = desktop_command(tmp_path, personal)
    first = run_setup(desktop, command)
    assert first.returncode == 0, first.stderr
    fonts = tmp_path / ".local/share/fonts/SF-Pro-Text"
    manifest = fonts / ".installed.sha256"
    assert manifest.is_file()
    assert (Path(desktop["XDG_DATA_HOME"]) / "icons/MacTahoe/index.theme").is_file()
    assert (tmp_path / "preferences/font-name").read_text() == "'SF Pro Text 12'\n"
    assert (tmp_path / "preferences/default-zoom-level").read_text() == "'small-plus'\n"
    hypr = tmp_path / ".config/hypr"
    assert ("DELL P2425H" in (hypr / "config/monitors.lua").read_text()) == personal
    assert ("move_workspaces" in (hypr / "config/workspaces.lua").read_text()) == personal
    assert 'workspace = "special:exposed"' in (hypr / "config/workspaces.lua").read_text()
    assert ("scripts.movie_mode" in (hypr / "config/binds.lua").read_text()) == personal
    assert (hypr / "scripts/movie_mode.lua").exists() == personal
    observed = calls(desktop)
    assert any(call[0] == "curl" and call[-1].endswith("/SF-Pro.dmg") for call in observed)
    assert sum(call[0] == "git" for call in observed) == 1
    assert sum(call[0] == "fc-cache" for call in observed) == 1
    assert all(call[0] != "rbw" for call in observed)
    assert any(call[0] == "sudo" for call in observed) == personal
    repeated = run_setup(desktop, command)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stderr == ""
    assert calls(desktop) == observed
    # Re-execution still checks installed fonts and preference state. A package
    # declaration change alone must not invalidate these independent hooks.
    for hook in (HOOKS[0], HOOKS[1], HOOKS[3]):
        with (tmp_path / "source/.chezmoiscripts/linux" / hook).open("a") as script:
            script.write("\n# Exercise reapplication of the existing desired state.\n")
    (tmp_path / "source/unrelated-package-change").touch()
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    subsequent = calls(desktop)[len(observed) :]
    assert all(call[0] not in ("curl", "git", "fc-cache", "rbw") for call in subsequent)
    assert not any(call[:2] == ["gsettings", "set"] for call in subsequent)


def test_offline_assets_retry_when_online(desktop: dict[str, str], tmp_path: Path) -> None:
    desktop["OFFLINE"] = "1"
    command = desktop_command(tmp_path, False)
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert not any(call[0] in ("git", "curl", "fc-cache") for call in calls(desktop))
    del desktop["OFFLINE"]
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / ".local/share/fonts/SF-Pro-Text/.installed.sha256").is_file()
    assert (Path(desktop["XDG_DATA_HOME"]) / "icons/MacTahoe/index.theme").is_file()


def test_font_cache_failure_retries_without_publishing_completion(
    desktop: dict[str, str], tmp_path: Path
) -> None:
    desktop["CACHE_STATUS"] = "23"
    command = desktop_command(tmp_path, False)
    result = run_setup(desktop, command)
    assert result.returncode != 0
    assert "Failed to refresh SF Pro Text font cache" in result.stderr
    assert not (tmp_path / ".local/share/fonts/SF-Pro-Text/.installed.sha256").exists()
    del desktop["CACHE_STATUS"]
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / ".local/share/fonts/SF-Pro-Text/.installed.sha256").is_file()
    assert sum(call[0] == "git" for call in calls(desktop)) == 1


def test_preference_failure_remains_retryable(desktop: dict[str, str], tmp_path: Path) -> None:
    desktop["SETTINGS_STATUS"] = "23"
    command = desktop_command(tmp_path, False)
    result = run_setup(desktop, command)
    assert result.returncode != 0
    assert not any(call[0] in ("git", "curl") for call in calls(desktop))
    del desktop["SETTINGS_STATUS"]
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "preferences/show-delete-permanently").read_text() == "true\n"
