"""Apply common desktop hooks in private homes without a live desktop or downloads."""

import json
import shutil
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import calls, render_python, run_setup, stub
from test_setup import env as env

HOOKS = (
    "run_onchange_after_06_theming.py.tmpl",
    "run_onchange_after_06_nautilus.py",
)


@pytest.fixture
def desktop(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    for name in ("install", "mkdir"):
        executable = shutil.which(name)
        assert executable is not None
        (Path(env["PATH"]) / name).symlink_to(executable)
    (tmp_path / "preferences").mkdir()
    stub(env, "id", "echo 1000")
    stub(env, "rbw", "exit 97", log=True)
    stub(
        env,
        "gtk-update-icon-cache",
        '[ "${ICON_CACHE_STATUS:-0}" = 0 ] || exit "$ICON_CACHE_STATUS"; touch "$1/icon-theme.cache"',
        log=True,
    )
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
    -v) exit 0 ;;
    -n) shift; unset CHEZMOI_SOURCE_DIR CHEZMOI_WORKING_TREE DOTFILES_PERSONAL_ENABLED; exec "$@" ;;
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
for name in MacTahoe MacTahoe-light MacTahoe-dark; do
    mkdir -p "$2/$name/apps" "$2/$name/cursors"
    printf 'fixture icon theme\\n' > "$2/$name/index.theme"
    gtk-update-icon-cache "$2/$name"
done
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
    source = tmp_path / "source with spaces"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    for hook in HOOKS:
        text = (SCRIPTS / hook).read_text()
        text = text.replace('Path("/root/.config")', f"Path({str(tmp_path / 'root-config')!r})")
        text = text.replace("if os.geteuid() != 0:", "if False:")
        (scripts / hook).write_text(text)
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    helper = source / ".chezmoitemplates/lib/policy_files.py"
    text = helper.read_text().replace("parent.st_uid != 0", "parent.st_uid != os.getuid()")
    text = text.replace(
        "os.chown(stage, 0, 0)", "os.chown(stage, os.getuid(), os.getgid())"
    ).replace("== (0, 0, mode)", "== (os.getuid(), os.getgid(), mode)")
    helper.write_text(text)
    shutil.copytree(ROOT / "home/.chezmoidata", source / ".chezmoidata")
    shutil.copytree(ROOT / "home/dot_config/hypr", source / "dot_config/hypr")
    shutil.copy(ROOT / "home/.chezmoiignore.tmpl", source / ".chezmoiignore.tmpl")
    config = tmp_path / "chezmoi.json"
    config.write_text(
        json.dumps(
            {
                "data": {"personal": personal, "distroFamily": "arch"},
                "scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "1" if personal else "0"},
                "interpreters": {"py": {"command": "/usr/bin/python3", "args": ["-B"]}},
            }
        )
    )
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
    root_settings = [tmp_path / f"root-config/gtk-{version}.0/settings.ini" for version in (3, 4)]
    for path in root_settings:
        assert path.exists() == personal
        if personal:
            assert path.stat().st_mode & 0o777 == 0o644
            assert "gtk-application-prefer-dark-theme=true" in path.read_text()
            assert (path.parent / "gtk.css").readlink() == Path(
                desktop["XDG_CONFIG_HOME"]
            ) / path.parent.name / "gtk.css"
    root_times = {path: path.stat().st_mtime_ns for path in root_settings if personal}
    repeated = run_setup(desktop, command)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stderr == ""
    assert calls(desktop) == observed
    # Re-execution still checks installed fonts and preference state. A package
    # declaration change alone must not invalidate these independent hooks.
    for hook in HOOKS:
        with (tmp_path / "source with spaces/.chezmoiscripts/linux" / hook).open("a") as script:
            script.write("\n# Exercise reapplication of the existing desired state.\n")
    (tmp_path / "source with spaces/unrelated-package-change").touch()
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    subsequent = calls(desktop)[len(observed) :]
    assert all(call[0] not in ("curl", "git", "fc-cache", "rbw") for call in subsequent)
    assert not any(call[:2] == ["gsettings", "set"] for call in subsequent)
    assert {path: path.stat().st_mtime_ns for path in root_times} == root_times
    # Changing the real GTK font input reruns only theming; valid assets stay put.
    fonts_data = tmp_path / "source with spaces/.chezmoidata/fonts.yaml"
    fonts_data.write_text(fonts_data.read_text().replace('"SF Pro Text"', '"Fixture UI"'))
    before_change = len(calls(desktop))
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    changed = calls(desktop)[before_change:]
    assert (tmp_path / "preferences/font-name").read_text() == "'Fixture UI 12'\n"
    assert not any(call[0] in ("git", "curl", "fc-cache") for call in changed)
    assert not any("org.gnome.nautilus" in " ".join(call) for call in changed)


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
    assert "fc-cache" in result.stderr
    assert (tmp_path / "preferences/show-delete-permanently").read_text() == "true\n"
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


def test_mactahoe_partial_install_retries_with_space_free_paths(
    desktop: dict[str, str], tmp_path: Path
) -> None:
    desktop["XDG_DATA_HOME"] = str(tmp_path / "data with spaces")
    desktop["TMPDIR"] = str(tmp_path / "temporary files")
    Path(desktop["TMPDIR"]).mkdir()
    desktop["ICON_CACHE_STATUS"] = "23"
    command = desktop_command(tmp_path, False)
    result = run_setup(desktop, command)
    assert result.returncode != 0
    completion = Path(desktop["XDG_STATE_HOME"]) / "chezmoi/mactahoe-installed"
    assert not completion.exists()
    assert not any(call[0] == "curl" for call in calls(desktop))
    desktop.pop("ICON_CACHE_STATUS")
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert completion.exists()
    for call in calls(desktop):
        if call[0] == "git":
            assert " " not in call[-1]
    # An actual missing variant must override the successful installation record.
    (Path(desktop["XDG_DATA_HOME"]) / "icons/MacTahoe-dark/icon-theme.cache").unlink()
    target = tmp_path / "source with spaces/.chezmoiscripts/linux" / HOOKS[0]
    target.write_text(target.read_text() + "\n# Check the installed variants.\n")
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert sum(call[0] == "git" for call in calls(desktop)) == 3
    assert sum(call[0] == "curl" for call in calls(desktop)) == 1


def test_font_corruption_is_repaired_without_reinstalling_icons(
    desktop: dict[str, str], tmp_path: Path
) -> None:
    command = desktop_command(tmp_path, False)
    assert run_setup(desktop, command).returncode == 0
    font = tmp_path / ".local/share/fonts/SF-Pro-Text/SF-Pro-Text-Regular.otf"
    font.write_text("damaged font")
    target = tmp_path / "source with spaces/.chezmoiscripts/linux" / HOOKS[0]
    target.write_text(target.read_text() + "\n# Check font integrity.\n")
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert font.read_text() == "fixture font\n"
    assert sum(call[0] == "git" for call in calls(desktop)) == 1
    assert sum(call[0] == "curl" for call in calls(desktop)) == 2


@pytest.mark.parametrize("failure", ["download", "payload"])
def test_asset_failures_preserve_status_and_never_publish_font_completion(
    desktop: dict[str, str], tmp_path: Path, failure: str
) -> None:
    _ = desktop_command(tmp_path, False)
    if failure == "download":
        stub(desktop, "curl", "exit 23", log=True)
    else:
        stub(desktop, "bsdtar", '[ "$1" != -xOf ] || exit 23; cat >/dev/null', log=True)
    script = render_python(
        desktop, HOOKS[0], personal=False, source=tmp_path / "source with spaces"
    )
    result = run_setup(desktop, ["/usr/bin/python3", "-B", str(script)])
    assert result.returncode == 23, result.stderr
    assert not (tmp_path / ".local/share/fonts/SF-Pro-Text/.installed.sha256").exists()
    assert not any(call[0] == "fc-cache" for call in calls(desktop))


def test_nautilus_can_be_applied_without_the_theming_workflow(
    desktop: dict[str, str], tmp_path: Path
) -> None:
    command = desktop_command(tmp_path, False)
    (tmp_path / "source with spaces/.chezmoiscripts/linux" / HOOKS[0]).unlink()
    desktop["CACHE_STATUS"] = "23"
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "preferences/show-delete-permanently").read_text() == "true\n"
    assert all(call[0] == "gsettings" for call in calls(desktop))
    observed = calls(desktop)
    # Runtime context does not change the content hash of the plain hook.
    desktop.update(OFFLINE="1", NOCONFIRM="1", RBW_PROFILE="unused")
    repeated = run_setup(desktop, command)
    assert repeated.returncode == 0, repeated.stderr
    assert calls(desktop) == observed
