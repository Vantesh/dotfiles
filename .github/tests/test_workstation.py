"""Common workstation tasks preserve service scopes and personal-only provisioning."""

import json
import os
import shutil
import tomllib
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import calls, render_python, run_setup, stub
from test_setup import env as env

HOOK = "run_onchange_after_14_services.py.tmpl"


def render_services(
    env: dict[str, str], personal: bool, *, source: Path = ROOT / "home"
) -> list[str]:
    home = Path(env["HOME"])
    script = render_python(env, HOOK, personal=personal, source=source)
    # Validate the fixed binary check against an isolated executable in these tests.
    fish = home / "fish"
    fish.write_text("#!/bin/sh\nexit 0\n")
    fish.chmod(0o755)
    script.write_text(script.read_text().replace("/usr/bin/fish", str(fish)))
    return ["/usr/bin/python3", "-B", str(script)]


@pytest.fixture
def workstation(env: dict[str, str]) -> dict[str, str]:
    env.update(
        NOCONFIRM="1",
        OFFLINE="1",
        MISE_ENV="nvidia-sleep",
        MISE_CONFIG_FILE="/unrelated/config.toml",
    )
    stub(env, "id", "echo 1000")
    stub(
        env,
        "mise",
        '''[ -z "${MISE_ENV+x}" ] && [ -z "${MISE_CONFIG_FILE+x}" ] || exit 98
exit "${MISE_STATUS:-0}"''',
        log=True,
    )
    stub(env, "systemctl", "exit 97", log=True)
    for command in ("rbw", "sbctl", "busctl", "ufw", "chsh", "updatedb"):
        stub(env, command, "exit 97", log=True)
    stub(
        env,
        "sudo",
        """case "$1" in
    -v) exit 0 ;;
    -n) case "$*" in *--configure-locate*) exit 0 ;; *) exit 97 ;; esac ;;
    systemctl) [ "$*" = 'systemctl start plocate-updatedb.timer' ] ;;
    *) exit 97 ;;
esac""",
    )
    return env


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_chezmoi_applies_workstation_tasks_in_both_profiles(
    workstation: dict[str, str], tmp_path: Path, personal: bool
) -> None:
    assert CHEZMOI is not None
    repository = tmp_path / "source"
    templates = repository / "home/.chezmoitemplates"
    scripts = repository / "home/.chezmoiscripts/linux"
    templates.mkdir(parents=True)
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "mise", repository / "mise")
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", templates / "lib")
    # This is the real apply path, including its actual fixed Fish path check.
    shutil.copy(SCRIPTS / HOOK, scripts / HOOK)
    config = tmp_path / "chezmoi.json"
    config.write_text(
        json.dumps(
            {
                "data": {"personal": personal, "distroFamily": "arch"},
                "scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "1" if personal else "0"},
            }
        )
    )
    command = [
        CHEZMOI,
        "--config",
        str(config),
        "--source",
        str(repository / "home"),
        "--working-tree",
        str(repository),
        "--destination",
        str(tmp_path / "target"),
        "--no-tty",
        "apply",
    ]
    first = run_setup(workstation, command)
    assert first.returncode == 0, first.stderr
    expected = [
        "mise",
        *([] if personal else ["--quiet"]),
        "--env",
        "personal" if personal else "",
        "bootstrap",
        "--only",
        "services,firewall,user" if personal else "services,user",
        "--yes",
    ]
    recorded = calls(workstation)
    assert recorded == [expected]  # All service activation belongs to Mise.
    repeated = run_setup(workstation, command)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stderr == ""
    assert calls(workstation) == recorded


def test_service_declarations_keep_masks_and_personal_boundaries() -> None:
    common = cast(
        "dict[str, dict[str, str | bool]]",
        tomllib.loads((ROOT / "mise/conf.d/services.toml").read_text())["bootstrap"]["services"],
    )
    system = {
        name: declaration
        for name, declaration in common.items()
        if declaration.get("scope") != "user"
    }
    assert set(system) == {
        "NetworkManager.service",
        "bluetooth.service",
        "warp-svc.service",
        "fstrim.timer",
        "reflector.timer",
        "pacman-filesdb-refresh.timer",
        "paccache.timer",
        "pkgfile-update.timer",
        "systemd-networkd-wait-online.service",
    }
    assert common["systemd-networkd-wait-online.service"] == {
        "state": "stopped",
        "enabled": False,
        "masked": True,
    }
    personal = cast(
        "dict[str, dict[str, str | bool]]",
        tomllib.loads((ROOT / "mise/config.personal.toml").read_text())["bootstrap"]["services"],
    )
    assert common["warp-svc.service"] == {"state": "running", "enabled": True}
    assert set(personal) == {"ufw.service", "ssh-agent.socket"}
    assert personal["ufw.service"] == {"state": "running", "enabled": True}
    assert tomllib.loads((ROOT / "mise/conf.d/login-shell.toml").read_text()) == {
        "bootstrap": {"user": {"login_shell": "/usr/bin/fish"}}
    }
    user_units = {
        name: declaration
        for name, declaration in common.items()
        if declaration.get("scope") == "user"
    }
    assert set(user_units) == {
        "gnome-keyring-daemon.service",
        "gnome-keyring-daemon.socket",
        "mpris-proxy.service",
        "udiskie.service",
    }
    for declaration in (*user_units.values(), personal["ssh-agent.socket"]):
        assert declaration == {
            "scope": "user",
            "state": "running",
            "enabled": True,
            "masked": False,
        }
    assert tomllib.loads((ROOT / "mise/config.toml").read_text())["min_version"] == "2026.10.20"


def test_workstation_tasks_reject_root(workstation: dict[str, str]) -> None:
    command = render_services(workstation, False)
    script = Path(command[-1])
    script.write_text(script.read_text().replace("if os.getuid() == 0:", "if True:"))
    result = run_setup(workstation, command)
    assert result.returncode != 0
    assert "ERROR" in result.stderr
    assert calls(workstation) == []


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_locate_and_avatar_remain_personal_and_retryable(
    workstation: dict[str, str], tmp_path: Path, personal: bool
) -> None:
    source = tmp_path / "source with spaces/home"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "mise", source.parent / "mise")
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    updatedb = tmp_path / "etc/updatedb.conf"
    updatedb.parent.mkdir()
    updatedb.write_text('# preserve\nPRUNENAMES=".git cache"\nOTHER="keep"\n')
    updatedb.chmod(0o640)
    text = (
        (SCRIPTS / HOOK)
        .read_text()
        .replace('Path("/etc/updatedb.conf")', f"Path({str(updatedb)!r})")
        .replace("if os.geteuid() != 0:", "if False:")
    )
    (scripts / HOOK).write_text(text)
    helper = source / ".chezmoitemplates/lib/policy_files.py"
    helper.write_text(
        helper.read_text().replace("parent.st_uid != 0", "parent.st_uid != os.getuid()")
    )
    avatar = tmp_path / ".local/share/avatars/profile.png"
    avatar.parent.mkdir(parents=True)
    avatar.write_bytes(b"fixture-avatar")
    stub(workstation, "updatedb", "exit 97", log=True)
    stub(workstation, "busctl", 'exit "${AVATAR_STATUS:-0}"', log=True)
    stub(
        workstation,
        "sudo",
        """case "$1" in
    -v) exit 0 ;;
    -n) shift; unset CHEZMOI_SOURCE_DIR CHEZMOI_WORKING_TREE DOTFILES_PERSONAL_ENABLED; exec "$@" ;;
    systemctl) exit "${TIMER_STATUS:-0}" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    command = render_services(workstation, personal, source=source)
    first = run_setup(workstation, command)
    assert first.returncode == 0, first.stderr
    before = updatedb.stat().st_mtime_ns
    for _ in range(2):
        result = run_setup(workstation, command)
        assert result.returncode == 0, result.stderr
    assert updatedb.stat().st_mtime_ns == before
    assert updatedb.stat().st_mode & 0o777 == 0o640
    expected = ".git cache .snapshots" if personal else ".git cache"
    assert updatedb.read_text() == f'# preserve\nPRUNENAMES="{expected}"\nOTHER="keep"\n'
    recorded = calls(workstation)
    assert any(call[0] == "sudo" for call in recorded) == personal
    assert any(call[0] == "busctl" for call in recorded) == personal
    assert not any(call[0] == "updatedb" for call in recorded)
    if personal:
        assert next(
            index for index, call in enumerate(recorded) if "--configure-locate" in call
        ) < next(index for index, call in enumerate(recorded) if call[0] == "mise")
        workstation["TIMER_STATUS"] = "23"
        failed = run_setup(workstation, command)
        assert failed.returncode == 23
        workstation.pop("TIMER_STATUS")
        workstation["AVATAR_STATUS"] = "23"
        failed = run_setup(workstation, command)
        assert failed.returncode == 23


@pytest.mark.parametrize(
    ("offline", "kind", "status", "success"),
    [
        ("1", "missing", "0", True),
        ("", "missing", "0", False),
        ("1", "usable", "23", False),
    ],
)
def test_avatar_assignment_skips_unusable_offline_files_and_preserves_errors(
    workstation: dict[str, str], tmp_path: Path, offline: str, kind: str, status: str, success: bool
) -> None:
    avatar = tmp_path / ".local/share/avatars/profile.png"
    avatar.parent.mkdir(parents=True)
    if kind == "usable":
        avatar.write_bytes(b"fixture image")
    workstation["OFFLINE"] = offline
    stub(workstation, "busctl", f"exit {status}", log=True)
    result = run_setup(workstation, render_services(workstation, True))
    assert (result.returncode == 0) == success, result.stderr
    expected = (
        [
            [
                "busctl",
                "call",
                "org.freedesktop.Accounts",
                f"/org/freedesktop/Accounts/User{os.getuid()}",
                "org.freedesktop.Accounts.User",
                "SetIconFile",
                "s",
                str(avatar),
            ]
        ]
        if kind == "usable"
        else []
    )
    assert [call for call in calls(workstation) if call[0] == "busctl"] == expected
    if not success:
        assert "[ERROR]" in result.stderr


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_offline_transition_invalidates_only_personal_services(
    workstation: dict[str, str], personal: bool
) -> None:
    workstation.pop("OFFLINE", None)
    online = render_python(workstation, HOOK, personal=personal).read_text()
    workstation["OFFLINE"] = "1"
    offline = render_python(workstation, HOOK, personal=personal).read_text()
    assert (online != offline) == personal
    workstation["OFFLINE"] = "yes"
    assert offline == render_python(workstation, HOOK, personal=personal).read_text()
    workstation["OFFLINE"] = ""
    assert online == render_python(workstation, HOOK, personal=personal).read_text()


def test_mise_service_failure_preserves_status(workstation: dict[str, str]) -> None:
    workstation["MISE_STATUS"] = "23"
    result = run_setup(workstation, render_services(workstation, False))
    assert result.returncode == 23, result.stderr
    assert "ERROR" in result.stderr
