"""Apply common desktop hooks in private homes without a live desktop or downloads."""

import json
import shutil
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import calls, render_python, run_setup, stub
from test_setup import env as env

HOOK = "run_onchange_after_06_theming.py.tmpl"


@pytest.fixture
def desktop(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    for name in ("install", "mkdir"):
        executable = shutil.which(name)
        assert executable is not None
        (Path(env["PATH"]) / name).symlink_to(executable)
    (tmp_path / "preferences").mkdir()
    stub(env, "rbw", "exit 97", log=True)
    stub(
        env,
        "gtk-update-icon-cache",
        '[ "${ICON_CACHE_STATUS:-0}" = 0 ] || exit "$ICON_CACHE_STATUS"; touch "$1/icon-theme.cache"',
        log=True,
    )
    stub(env, "fc-cache", "exit 0", log=True)
    stub(
        env,
        "gsettings",
        """case "$1" in
    get)
        if test -f "$HOME/preferences/$3"; then cat "$HOME/preferences/$3"
        elif test "$3" = color-scheme; then echo "'prefer-dark'"
        elif test "$3" = gtk-theme; then echo "'adw-gtk3-dark'"
        else echo "'old'"; fi ;;
    set)
        printf "'%s'\\n" "$4" > "$HOME/preferences/$3" ;;
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
    text = (SCRIPTS / HOOK).read_text()
    text = text.replace('Path("/root/.config")', f"Path({str(tmp_path / 'root-config')!r})")
    text = text.replace("if os.geteuid() != 0:", "if False:")
    (scripts / HOOK).write_text(text)
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    helper = source / ".chezmoitemplates/lib/policy_files.py"
    text = helper.read_text().replace("parent.st_uid != 0", "parent.st_uid != os.getuid()")
    text = text.replace(
        "os.chown(stage, 0, 0)", "os.chown(stage, os.getuid(), os.getgid())"
    ).replace("== (0, 0, mode)", "== (os.getuid(), os.getgid(), mode)")
    helper.write_text(text)
    shutil.copytree(ROOT / "home/.chezmoidata", source / ".chezmoidata")
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
def test_root_gtk_mirror_is_personal_and_safe_to_reapply(
    desktop: dict[str, str], tmp_path: Path, personal: bool
) -> None:
    command = desktop_command(tmp_path, personal)
    first = run_setup(desktop, command)
    assert first.returncode == 0, first.stderr
    observed = calls(desktop)
    assert all(call[0] != "rbw" for call in observed)
    assert any(call[0] == "sudo" for call in observed) == personal
    root_settings = [tmp_path / f"root-config/gtk-{version}.0/settings.ini" for version in (3, 4)]
    for path in root_settings:
        assert path.exists() == personal
        if personal:
            assert path.stat().st_mode & 0o777 == 0o644
            assert (path.parent / "gtk.css").readlink() == Path(
                desktop["XDG_CONFIG_HOME"]
            ) / path.parent.name / "gtk.css"
    root_times = {path: path.stat().st_mtime_ns for path in root_settings if personal}
    # Force re-execution to inspect state rather than only Chezmoi's cache.
    target = tmp_path / "source with spaces/.chezmoiscripts/linux" / HOOK
    target.write_text(target.read_text() + "\n# Recheck configured state.\n")
    result = run_setup(desktop, command)
    assert result.returncode == 0, result.stderr
    assert {path: path.stat().st_mtime_ns for path in root_times} == root_times


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


@pytest.mark.parametrize("failure", ["download", "payload"])
def test_asset_failures_preserve_status_and_never_publish_font_completion(
    desktop: dict[str, str], tmp_path: Path, failure: str
) -> None:
    _ = desktop_command(tmp_path, False)
    if failure == "download":
        stub(desktop, "curl", "exit 23", log=True)
    else:
        stub(desktop, "bsdtar", '[ "$1" != -xOf ] || exit 23; cat >/dev/null', log=True)
    script = render_python(desktop, HOOK, personal=False, source=tmp_path / "source with spaces")
    result = run_setup(desktop, ["/usr/bin/python3", "-B", str(script)])
    assert result.returncode == 23, result.stderr
    assert not (tmp_path / ".local/share/fonts/SF-Pro-Text/.installed.sha256").exists()
    assert not any(call[0] == "fc-cache" for call in calls(desktop))
