"""Render and apply the common greeter setup without live system changes."""

import json
import os
import pwd
import shutil
import tomllib
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import PYTHON, calls, render_python, run_setup, stub
from test_setup import env as env

HOOK = "run_onchange_after_09_login_manager.py.tmpl"


@pytest.fixture
def login(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    source = tmp_path / "checkout with spaces/home"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "home/.chezmoitemplates", source / ".chezmoitemplates")
    for directory in (
        "etc/greetd",
        "etc/pam.d",
        "usr/share/wayland-sessions",
        "sys/class/drm/card1-DP-1",
        "var/lib",
    ):
        (tmp_path / directory).mkdir(parents=True)
    packaged = tmp_path / "usr/share/wayland-sessions/hyprland-uwsm.desktop"
    packaged.write_text(
        "[Desktop Entry]\nName=Hyprland (uwsm-managed)\nComment=Keep this field\nExec=uwsm start -e -D Hyprland hyprland.desktop\nTryExec=uwsm\nDesktopNames=Hyprland\nType=Application\n"
    )
    (tmp_path / "units.json").write_text(
        json.dumps(
            {
                "sddm.service": "enabled",
                "ly@tty2.service": "enabled-runtime",
                "greetd.service": "disabled",
            }
        )
    )
    text = (SCRIPTS / HOOK).read_text()
    for target in (
        "/etc/greetd/config.toml",
        "/etc/pam.d/greetd",
        "/var/lib/noctalia-greeter",
        "/usr/share/wayland-sessions/hyprland-uwsm.desktop",
        "/usr/local/share/wayland-sessions/hyprland-uwsm.desktop",
        "/sys/class/drm",
    ):
        text = text.replace(
            f'Path("{target}")', f"Path({str(tmp_path / target.removeprefix('/'))!r})"
        )
    text = (
        text.replace("if os.geteuid() != 0:", "if False:")
        .replace("or os.geteuid() == 0:", "or False:")
        .replace('pwd.getpwnam("greeter")', "pwd.getpwuid(os.getuid())")
    )
    (scripts / HOOK).write_text(text)
    helper = source / ".chezmoitemplates/lib/policy_files.py"
    helper.write_text(
        helper.read_text()
        .replace("parent.st_uid != 0", "parent.st_uid != os.getuid()")
        .replace("os.chown(stage, 0, 0)", "os.chown(stage, os.getuid(), os.getgid())")
        .replace("== (0, 0, mode)", "== (os.getuid(), os.getgid(), mode)")
    )
    stub(
        env,
        "sudo",
        """case "$1" in
    -v) exit 0 ;;
    -n) shift; unset CHEZMOI_SOURCE_DIR DOTFILES_PERSONAL_ENABLED; exec "$@" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(env, "pacman", "exit 0", log=True)
    stub(
        env,
        "install",
        '''for directory do :; done
python3 -c 'from pathlib import Path; import sys; p=Path(sys.argv[1]); p.mkdir(exist_ok=True); p.chmod(0o750)' "$directory"''',
        log=True,
    )
    stub(
        env,
        "noctalia-greeter",
        '''[ "$1" = passwordless-sync ] && [ "$2" = enable ] || exit 97
printf '%s' "$3" > "$HOME/appearance-account"''',
        log=True,
    )
    command = Path(env["PATH"]) / "systemctl"
    command.write_text("""#!/usr/bin/python3 -B
import fnmatch, json, os, sys
from pathlib import Path
from typing import cast
home = Path(os.environ["HOME"])
args = sys.argv[1:]
with Path(os.environ["CALLS"]).open("a") as stream:
    stream.write("systemctl\\t" + "\\t".join(args) + "\\t\\n")
if any(arg in args for arg in ("--now", "--force", "start", "stop", "restart", "isolate", "reboot", "mask")):
    sys.exit(97)
path = home / "units.json"
units = json.loads(path.read_text())
name = args[-1]
if args[0] == "list-unit-files":
    if os.environ.get("FAIL_DISCOVERY"):
        print("Failed to list unit files: Permission denied", file=sys.stderr)
        sys.exit(23)
    patterns = [arg for arg in args[1:] if not arg.startswith("--")]
    states = next((arg.split("=", 1)[1].split(",") for arg in args if arg.startswith("--state=")), None)
    found = False
    for unit, state in units.items():
        if patterns and not any(fnmatch.fnmatchcase(unit, pattern) for pattern in patterns):
            continue
        if states is not None and state not in states:
            continue
        print(unit, state, "disabled")
        found = True
    sys.exit(0 if found else 1)
if args[0] == "is-enabled":
    state = units.get(name, "disabled")
    if "--quiet" not in args: print(state)
    sys.exit(0 if state.startswith("enabled") else 1)
if args[0] == "--runtime": args.pop(0)
if args[0] == "disable":
    units[name] = "disabled"
elif args[0] == "enable" and name == "greetd.service":
    if os.environ.get("FAIL_ENABLE"):
        print("display-manager.service already points to unexpected.service", file=sys.stderr)
        sys.exit(23)
    units[name] = "enabled"
else:
    sys.exit(97)
path.write_text(json.dumps(units))
""")
    command.chmod(0o755)
    env["LOGIN_SOURCE"] = str(source)
    return env


def chezmoi_command(login: dict[str, str], personal: bool) -> list[str]:
    assert CHEZMOI is not None
    home = Path(login["HOME"])
    config = home / "chezmoi.json"
    config.write_text(
        json.dumps(
            {
                "data": {"personal": personal},
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
        login["LOGIN_SOURCE"],
        "--destination",
        str(home),
        "--no-tty",
        "apply",
    ]


@pytest.mark.parametrize(
    "personal,matching", [(False, False), (True, False), (True, True), (False, True)]
)
def test_greeter_configs_profiles_and_next_boot_only_transition(
    login: dict[str, str], tmp_path: Path, personal: bool, matching: bool
) -> None:
    edid = tmp_path / "sys/class/drm/card1-DP-1/edid"
    edid.write_bytes(b"DELL P2425H\n2RHZH14\n" if matching else b"Another display")
    command = chezmoi_command(login, personal)
    result = run_setup(login, command)
    assert result.returncode == 0, result.stderr
    config = tomllib.loads((tmp_path / "etc/greetd/config.toml").read_text())
    assert config == {
        "terminal": {"vt": 1},
        "default_session": {"command": "/usr/bin/noctalia-greeter-session", "user": "greeter"},
    }
    pam = (tmp_path / "etc/pam.d/greetd").read_text()
    assert pam == (ROOT / "home/.chezmoitemplates/login-manager/greetd.pam").read_text()
    assert "auth       include      system-local-login" in pam
    assert "session    optional     pam_gnome_keyring.so auto_start" in pam
    greeter_path = tmp_path / "var/lib/noctalia-greeter/greeter.toml"
    settings = tomllib.loads(greeter_path.read_text())
    assert settings["session"] == {"default": "Hyprland (uwsm-managed)"}
    assert settings["appearance"] == {
        "hide_logo": True,
        "scheme": "Synced",
        "password_style": "random",
        "scheme_selector_position": "hidden",
    }
    assert settings["idle"] == {"timeout": 600}
    assert ("output" in settings) == (personal and matching)
    if personal and matching:
        assert settings["output"] == {
            "name": "Dell Inc. DELL P2425H 2RHZH14; eDP-1",
            "refresh_rate": 100,
        }
    assert greeter_path.stat().st_mode & 0o777 == 0o640
    assert greeter_path.stat().st_uid == os.getuid()
    assert greeter_path.parent.stat().st_mode & 0o777 == 0o750
    assert not (greeter_path.parent / "sync.toml").exists()
    packaged = (tmp_path / "usr/share/wayland-sessions/hyprland-uwsm.desktop").read_text()
    override = (tmp_path / "usr/local/share/wayland-sessions/hyprland-uwsm.desktop").read_text()
    assert override == packaged.replace(
        "Exec=uwsm start", "Exec=env UWSM_SILENT_START=1 uwsm start"
    )
    assert (tmp_path / "appearance-account").exists() == personal
    if personal:
        assert (tmp_path / "appearance-account").read_text() == pwd.getpwuid(os.getuid()).pw_name
    assert json.loads((tmp_path / "units.json").read_text()) == {
        "sddm.service": "disabled",
        "ly@tty2.service": "disabled",
        "greetd.service": "enabled",
    }
    assert [call for call in calls(login) if call[0] == "systemctl" and "disable" in call] == [
        ["systemctl", "disable", "sddm.service"],
        ["systemctl", "--runtime", "disable", "ly@tty2.service"],
    ]
    packages = cast(
        "dict[str, dict[str, str]]",
        tomllib.loads((ROOT / "mise/conf.d/packages.toml").read_text())["bootstrap"]["packages"],
    )
    assert "pacman:ly" not in packages
    assert all(
        packages[f"pacman:{name}"] == {"env": "packages"}
        for name in ("greetd", "noctalia-greeter", "gnome-keyring")
    )
    previous = calls(login)
    before = greeter_path.stat().st_mtime_ns
    assert run_setup(login, command).returncode == 0
    assert calls(login) == previous  # Native run_onchange success caching.
    assert greeter_path.stat().st_mtime_ns == before
    # Explicit reapplication also preserves the managed file and service state.
    script = render_python(login, HOOK, personal=personal, source=Path(login["LOGIN_SOURCE"]))
    repeated = run_setup(login, [PYTHON, "-B", str(script)])
    assert repeated.returncode == 0, repeated.stderr
    assert greeter_path.stat().st_mtime_ns == before
    subsequent = calls(login)[len(previous) :]
    assert all(
        "enable" not in call and "disable" not in call
        for call in subsequent
        if call[0] == "systemctl"
    )


@pytest.mark.parametrize(
    "units,disabled",
    [
        ({"greetd.service": "disabled"}, []),
        (
            {
                "greetd.service": "enabled",
                "display-manager.service": "alias",
                "unrelated.service": "enabled",
                "ly@.service": "indirect",
            },
            [],
        ),
        (
            {
                "greetd.service": "disabled",
                "display-manager.service": "alias",
                "gdm3.service": "alias",
                "gdm.service": "enabled-runtime",
                "ly@seat0.service": "enabled",
            },
            [
                ["systemctl", "--runtime", "disable", "gdm.service"],
                ["systemctl", "disable", "ly@seat0.service"],
            ],
        ),
    ],
    ids=["fresh-disabled-greetd", "greetd-alias", "enabled-conflicts-with-aliases"],
)
def test_installed_units_allow_fresh_setup_and_ignore_aliases(
    login: dict[str, str], tmp_path: Path, units: dict[str, str], disabled: list[list[str]]
) -> None:
    (tmp_path / "units.json").write_text(json.dumps(units))
    command = chezmoi_command(login, False)
    result = run_setup(login, command)
    assert result.returncode == 0, result.stderr
    assert json.loads((tmp_path / "units.json").read_text())["greetd.service"] == "enabled"
    assert [
        call for call in calls(login) if call[0] == "systemctl" and "disable" in call
    ] == disabled


@pytest.mark.parametrize(
    "failure,diagnostic",
    [
        ("FAIL_ENABLE", "display-manager.service already points to unexpected.service"),
        ("FAIL_DISCOVERY", "Failed to list unit files: Permission denied"),
    ],
)
def test_systemctl_failure_preserves_exit_and_is_retried(
    login: dict[str, str], tmp_path: Path, failure: str, diagnostic: str
) -> None:
    command = chezmoi_command(login, False)
    login[failure] = "1"
    failed = run_setup(login, command)
    assert failed.returncode != 0
    assert "exit 23" in failed.stderr
    assert diagnostic in failed.stderr
    assert "greetd is enabled" not in failed.stderr
    login.pop(failure)
    result = run_setup(login, command)
    assert result.returncode == 0, result.stderr
    assert json.loads((tmp_path / "units.json").read_text())["greetd.service"] == "enabled"
