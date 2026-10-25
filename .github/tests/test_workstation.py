"""Common workstation tasks preserve service scopes and personal-only provisioning."""

import json
import shlex
import shutil
import tomllib
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import calls, run_setup, stub
from test_setup import env as env

HOOK = "run_onchange_after_14_services.sh.tmpl"


def render_services(env: dict[str, str], personal: bool) -> list[str]:
    assert CHEZMOI is not None, "chezmoi is required for workstation validation"
    home = Path(env["HOME"])
    config = home / "render.json"
    config.write_text("{}")
    result = run_setup(
        env,
        [
            CHEZMOI,
            "--config",
            str(config),
            "--source",
            str(ROOT / "home"),
            "--working-tree",
            str(ROOT),
            "--destination",
            str(home),
            "--override-data",
            json.dumps({"personal": personal, "distroFamily": "arch"}),
            "execute-template",
        ],
        input=(SCRIPTS / HOOK).read_text(),
    )
    assert result.returncode == 0, result.stderr
    script = home / "services.sh"
    # Validate the fixed binary check against an isolated executable in these tests.
    fish = home / "fish"
    fish.write_text("#!/bin/sh\nexit 0\n")
    fish.chmod(0o755)
    script.write_text(result.stdout.replace("/usr/bin/fish", str(fish)))
    return ["/bin/bash", str(script)]


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
        stub(workstation, "id", "echo 0")
    elif invalid == "fish":
        (tmp_path / "fish").chmod(0o644)
    else:
        (Path(workstation["PATH"]) / "chsh").unlink()
    result = run_setup(workstation, command)
    assert result.returncode != 0
    assert "ERROR" in result.stderr
    assert calls(workstation) == []
