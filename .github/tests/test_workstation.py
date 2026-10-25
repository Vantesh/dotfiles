"""Common workstation tasks preserve service scopes and personal-only provisioning."""

import json
import os
import shlex
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
    stub(
        env,
        "systemctl",
        """case "$*" in
    '--user show '*) echo 'LoadState=not-found' ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    for command in ("rbw", "sbctl", "busctl", "ufw", "chsh"):
        stub(env, command, "exit 97", log=True)
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
    config.write_text(json.dumps({"data": {"personal": personal, "distroFamily": "arch"}}))
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
    assert [call for call in calls(workstation) if call[0] == "mise"] == [expected]
    recorded = calls(workstation)
    assert all(call[0] in ("mise", "systemctl") for call in recorded), recorded
    assert all(call[1] == "--user" for call in recorded if call[0] == "systemctl")
    repeated = run_setup(workstation, command)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stderr == ""
    assert calls(workstation) == recorded


def test_service_declarations_keep_masks_and_personal_boundaries() -> None:
    common = cast(
        "dict[str, dict[str, str | bool]]",
        tomllib.loads((ROOT / "mise/conf.d/services.toml").read_text())["bootstrap"]["services"],
    )
    assert set(common) == {
        "NetworkManager.service",
        "bluetooth.service",
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
    assert set(personal) == {"warp-svc.service", "ufw.service"}
    assert personal["ufw.service"] == {"state": "running", "enabled": True}
    assert tomllib.loads((ROOT / "mise/conf.d/login-shell.toml").read_text()) == {
        "bootstrap": {"user": {"login_shell": "/usr/bin/fish"}}
    }


def test_packaged_user_services_only_change_missing_state(
    workstation: dict[str, str], tmp_path: Path
) -> None:
    stub(
        workstation,
        "systemctl",
        """case "$*" in
    '--user show '*' -- udiskie')
        echo LoadState=loaded
        if test -f "$HOME/enabled"; then echo UnitFileState=enabled; else echo UnitFileState=disabled; fi
        if test -f "$HOME/active"; then echo ActiveState=active; else echo ActiveState=inactive; fi ;;
    '--user show '*) echo LoadState=not-found ;;
    '--user --quiet enable -- udiskie') touch "$HOME/enabled" ;;
    '--user --quiet start -- udiskie') touch "$HOME/active" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    command = render_services(workstation, False)
    first = run_setup(workstation, command)
    assert first.returncode == 0, first.stderr
    assert (tmp_path / "active").exists() and (tmp_path / "enabled").exists()
    repeated = run_setup(workstation, command)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stderr == ""
    recorded = calls(workstation)
    assert recorded.count(["systemctl", "--user", "--quiet", "enable", "--", "udiskie"]) == 1
    assert recorded.count(["systemctl", "--user", "--quiet", "start", "--", "udiskie"]) == 1
    assert not any("restart" in call or "disable" in call for call in recorded)
    services = next(call for call in recorded if call[0] == "mise")
    assert recorded.index(services) < recorded.index(
        ["systemctl", "--user", "--quiet", "start", "--", "udiskie"]
    )


@pytest.mark.parametrize("failure", ["inspect", "start", "mise"])
def test_service_failures_preserve_status(workstation: dict[str, str], failure: str) -> None:
    if failure == "mise":
        workstation["MISE_STATUS"] = "23"
    else:
        stub(
            workstation,
            "systemctl",
            f"""case "$*" in
    '--user show '*)
        [ {shlex.quote(failure)} != inspect ] || exit 23
        printf 'LoadState=loaded\\nUnitFileState=enabled\\nActiveState=inactive\\n' ;;
    '--user --quiet start '*) exit 23 ;;
    *) exit 97 ;;
esac""",
            log=True,
        )
    result = run_setup(workstation, render_services(workstation, False))
    assert result.returncode == 23, result.stderr
    assert "ERROR" in result.stderr


@pytest.mark.parametrize("invalid", ["root", "fish", "chsh"])
def test_invalid_account_or_fish_stops_before_tasks(
    workstation: dict[str, str], tmp_path: Path, invalid: str
) -> None:
    command = render_services(workstation, False)
    if invalid == "root":
        script = Path(command[-1])
        script.write_text(script.read_text().replace("if os.getuid() == 0:", "if True:"))
    elif invalid == "fish":
        (tmp_path / "fish").chmod(0o644)
    else:
        (Path(workstation["PATH"]) / "chsh").unlink()
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
    -n) shift; exec "$@" ;;
    systemctl) exit 23 ;;
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
        assert "indexing is deferred" in first.stderr
        assert next(
            index for index, call in enumerate(recorded) if "--configure-locate" in call
        ) < next(index for index, call in enumerate(recorded) if call[0] == "mise")
        workstation["AVATAR_STATUS"] = "23"
        failed = run_setup(workstation, command)
        assert failed.returncode == 23


def test_masked_static_user_unit_is_unmasked_and_started_once(workstation: dict[str, str]) -> None:
    stub(
        workstation,
        "systemctl",
        """case "$*" in
    '--user show --property=UnitFileState --value -- udiskie') echo static ;;
    '--user show '*' -- udiskie')
        if test -f "$HOME/unmasked"; then echo LoadState=loaded; echo UnitFileState=static; else echo LoadState=masked; echo UnitFileState=masked; fi
        if test -f "$HOME/active"; then echo ActiveState=active; else echo ActiveState=inactive; fi ;;
    '--user show '*) echo LoadState=not-found ;;
    '--user --quiet unmask -- udiskie') touch "$HOME/unmasked" ;;
    '--user --quiet start -- udiskie') touch "$HOME/active" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    command = render_services(workstation, False)
    for _ in range(2):
        result = run_setup(workstation, command)
        assert result.returncode == 0, result.stderr
    recorded = calls(workstation)
    assert recorded.count(["systemctl", "--user", "--quiet", "unmask", "--", "udiskie"]) == 1
    assert recorded.count(["systemctl", "--user", "--quiet", "start", "--", "udiskie"]) == 1
    assert not any("enable" in call or "restart" in call for call in recorded)


@pytest.mark.parametrize(
    ("offline", "kind", "status", "success"),
    [
        ("1", "missing", "0", True),
        ("1", "empty", "0", True),
        ("1", "directory", "0", True),
        ("1", "unreadable", "0", True),
        ("1", "usable", "0", True),
        ("", "usable", "0", True),
        ("", "missing", "0", False),
        ("", "empty", "0", False),
        ("1", "usable", "23", False),
        ("", "usable", "23", False),
    ],
)
def test_avatar_assignment_skips_unusable_offline_files_and_preserves_errors(
    workstation: dict[str, str], tmp_path: Path, offline: str, kind: str, status: str, success: bool
) -> None:
    if kind == "unreadable" and os.geteuid() == 0:
        pytest.skip("Root can read files regardless of mode bits")
    avatar = tmp_path / ".local/share/avatars/profile.png"
    avatar.parent.mkdir(parents=True)
    if kind == "directory":
        avatar.mkdir()
    elif kind != "missing":
        avatar.write_bytes(b"" if kind == "empty" else b"fixture image")
        if kind == "unreadable":
            avatar.chmod(0)
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
