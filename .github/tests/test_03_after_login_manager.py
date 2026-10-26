"""Next-boot Ly selection with private unit state and native offline unit checks."""

import json
import shutil
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import PYTHON, calls, render_python, run_setup, stub
from test_setup import env as env

HOOK = "run_onchange_after_09_login_manager.py"
LY = "ly@tty1.service"
GETTY = "getty@tty1.service"


@pytest.fixture
def login(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    source = tmp_path / "checkout with spaces/home"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    for directory in ("etc/ly", "etc/systemd/system", "run/systemd/system", "vendor", "usr/bin"):
        (tmp_path / directory).mkdir(parents=True)
    (tmp_path / "etc/ly/config.ini").write_text(
        "# existing configuration\nallow_empty_password = true\npath = /custom\nwaylandsessions = /usr/share/wayland-sessions\nunmanaged = keep\n"
    )
    (tmp_path / "etc/ly/config.ini").chmod(0o640)
    (tmp_path / "etc/ly/save.ini").write_text("user=fixture\nsession_index=17\n")
    (tmp_path / "usr/bin/ly-dm").write_text("#!/bin/sh\nexit 97\n")
    (tmp_path / "usr/bin/ly-dm").chmod(0o755)
    for name in ("ly@.service", "getty@tty1.service", "getty@tty2.service"):
        (tmp_path / "vendor" / name).write_text("fixture unit\n")
    (tmp_path / "units.json").write_text(
        json.dumps(
            {
                LY: {"state": "disabled", "active": "inactive"},
                GETTY: {"state": "enabled", "active": "active"},
                "getty@tty2.service": {"state": "enabled", "active": "active"},
            }
        )
    )
    text = (SCRIPTS / HOOK).read_text()
    for target in (
        "/usr/bin/ly-dm",
        "/etc/ly/config.ini",
        "/etc/systemd/system",
        "/run/systemd/system",
    ):
        text = text.replace(
            f'Path("{target}")', f"Path({str(tmp_path / target.removeprefix('/'))!r})"
        )
    # As in the existing policy fixtures, only private copies waive root identity.
    text = text.replace("if os.geteuid() != 0:", "if False:").replace(
        "if os.geteuid() == 0:", "if False:"
    )
    (scripts / HOOK).write_text(text)
    helper = source / ".chezmoitemplates/lib/policy_files.py"
    helper.write_text(
        helper.read_text().replace("parent.st_uid != 0", "parent.st_uid != os.getuid()")
    )
    env["LOGIN_SOURCE"] = str(source)
    stub(env, "pacman", 'exit "${PACKAGE_STATUS:-0}"', log=True)
    stub(
        env,
        "sudo",
        """case "$1" in
    -v) exit 0 ;;
    -n) shift; unset CHEZMOI_SOURCE_DIR CHEZMOI_WORKING_TREE DOTFILES_PERSONAL_ENABLED DOTFILES_DISTRO_FAMILY; exec "$@" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    command = Path(env["PATH"]) / "systemctl"
    command.write_text(r"""#!/usr/bin/python3 -B
import json, os, sys
from pathlib import Path
home = Path(os.environ["HOME"])
args = sys.argv[1:]
with Path(os.environ["CALLS"]).open("a") as stream:
    stream.write("systemctl\t" + "\t".join(args) + "\t\n")
if any(arg in args for arg in ("--now", "--force", "start", "stop", "restart", "isolate", "reboot", "mask", "unmask")):
    sys.exit(97)
state_file = home / "units.json"
units = json.loads(state_file.read_text())
roots = (home / "etc/systemd/system", home / "run/systemd/system")
def fragment(name):
    return home / "vendor" / ("ly@.service" if name.startswith("ly@") else name)
if args[0] == "list-unit-files":
    for name, info in units.items():
        if name.startswith("ly@") and info["state"] in ("enabled", "enabled-runtime"):
            print(name, info["state"], "disabled")
    sys.exit(0)
name = args[-1]
if args[0] == "show":
    canonical = name
    if name == "display-manager.service":
        alias = next((root / name for root in roots if (root / name).is_symlink()), None)
        if alias is not None:
            canonical = alias.readlink().name
    info = units.get(canonical)
    print("Id=" + canonical)
    print("LoadState=" + ("loaded" if info is not None else "not-found"))
    print("UnitFileState=" + (info["state"] if info is not None else ""))
    print("FragmentPath=" + (str(fragment(canonical)) if info is not None else ""))
    print("TTYPath=" + ("/dev/tty1" if canonical == "ly@tty1.service" else ""))
    print("Conflicts=" + ("getty@tty1.service shutdown.target" if canonical == "ly@tty1.service" else ""))
    sys.exit(0)
runtime = args[0] == "--runtime"
action = args[1] if runtime else args[0]
if action not in ("enable", "disable") or name not in units:
    sys.exit(97)
root = roots[1] if runtime else roots[0]
alias = root / "display-manager.service"
if action == "enable":
    if not name.startswith(("ly@", "getty@")):
        if alias.is_symlink() and alias.resolve() != fragment(name):
            print("Refusing an existing foreign alias", file=sys.stderr)
            sys.exit(17)
        if not alias.is_symlink():
            alias.symlink_to(fragment(name))
    if name == "ly@tty1.service" and os.environ.get("NO_ENABLE_EFFECT"):
        sys.exit(0)
    if runtime:
        if units[name]["state"] == "enabled":
            units[name]["runtime_enabled"] = "true"
        else:
            units[name]["state"] = "enabled-runtime"
    else:
        if units[name]["state"] == "enabled-runtime":
            units[name]["runtime_enabled"] = "true"
        units[name]["state"] = "enabled"
else:
    if runtime:
        if units[name]["state"] == "enabled-runtime":
            units[name]["state"] = "disabled"
        units[name].pop("runtime_enabled", None)
    elif units[name]["state"] == "enabled":
        units[name]["state"] = "enabled-runtime" if units[name].pop("runtime_enabled", None) else "disabled"
    if alias.is_symlink() and alias.resolve() == fragment(name):
        alias.unlink()
state_file.write_text(json.dumps(units))
# Fail only after mutating links/state, as a real systemctl failure can do.
if (name == "ly@tty1.service" and action == "enable" and os.environ.get("FAIL_LY_ENABLE")):
    print("fixture enable failed after changing links", file=sys.stderr)
    sys.exit(23)
if action == "disable" and os.environ.get("FAIL_DISABLE") == name:
    sys.exit(24)
""")
    command.chmod(0o755)
    return env


def states(login: dict[str, str]) -> dict[str, dict[str, str]]:
    return cast(
        "dict[str, dict[str, str]]", json.loads((Path(login["HOME"]) / "units.json").read_text())
    )


def add_manager(login: dict[str, str], name: str, *, scope: str = "etc") -> None:
    home = Path(login["HOME"])
    units = states(login)
    units[name] = {"state": "enabled", "active": "active"}
    (home / "units.json").write_text(json.dumps(units))
    (home / "vendor" / name).write_text("fixture manager\n")
    (home / scope / "systemd/system/display-manager.service").symlink_to(home / "vendor" / name)


def apply_login(login: dict[str, str]):
    script = render_python(login, HOOK, source=Path(login["LOGIN_SOURCE"]))
    return run_setup(login, [PYTHON, "-B", str(script)])


def mutations(login: dict[str, str]) -> list[list[str]]:
    return [
        call
        for call in calls(login)
        if call[0] == "systemctl" and any(action in call for action in ("enable", "disable"))
    ]


@pytest.mark.parametrize("already_enabled", [False, True], ids=["fresh", "existing-ly"])
def test_ly_selection_preserves_sessions_saved_choice_and_reapplication(
    login: dict[str, str], tmp_path: Path, already_enabled: bool
) -> None:
    if already_enabled:
        units = states(login)
        units[LY] = {"state": "enabled", "active": "active"}
        (tmp_path / "units.json").write_text(json.dumps(units))
        (tmp_path / "vendor" / LY).symlink_to("ly@.service")
        (tmp_path / "etc/systemd/system/display-manager.service").symlink_to(
            tmp_path / "vendor" / LY
        )
    active = {name: unit["active"] for name, unit in states(login).items()}
    saved = tmp_path / "etc/ly/save.ini"
    saved_before = (saved.read_bytes(), saved.stat().st_mtime_ns)
    result = apply_login(login)
    assert result.returncode == 0, result.stderr
    current = states(login)
    assert current[LY]["state"] == "enabled"
    assert current[GETTY]["state"] == "disabled"
    assert current["getty@tty2.service"]["state"] == "enabled"
    assert {name: unit["active"] for name, unit in current.items()} == active
    assert (saved.read_bytes(), saved.stat().st_mtime_ns) == saved_before
    assert "next boot" in result.stderr
    config = tmp_path / "etc/ly/config.ini"
    assert "unmanaged = keep\n" in config.read_text()
    assert "waylandsessions = /usr/share/wayland-sessions" in config.read_text()
    assert config.stat().st_mode & 0o777 == 0o640
    before = (config.read_bytes(), config.stat().st_mtime_ns, mutations(login))
    repeated = apply_login(login)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stdout == repeated.stderr == ""
    assert (config.read_bytes(), config.stat().st_mtime_ns, mutations(login)) == before
    assert (["systemctl", "enable", LY] in mutations(login)) == (not already_enabled)
    assert all("getty@tty2.service" not in call for call in mutations(login))


@pytest.mark.parametrize(
    "manager,runtime",
    [("sddm.service", False), ("greetd.service", False), ("sddm.service", True)],
    ids=["sddm", "greetd", "both-scopes"],
)
def test_recognized_manager_is_disabled_before_ly_without_stopping_it(
    login: dict[str, str], manager: str, runtime: bool
) -> None:
    add_manager(login, manager)
    if runtime:
        units = states(login)
        units[manager]["runtime_enabled"] = "true"
        home = Path(login["HOME"])
        (home / "units.json").write_text(json.dumps(units))
        (home / "run/systemd/system/display-manager.service").symlink_to(home / "vendor" / manager)
    result = apply_login(login)
    assert result.returncode == 0, result.stderr
    assert mutations(login) == [
        ["systemctl", "disable", manager],
        *([["systemctl", "--runtime", "disable", manager]] if runtime else []),
        ["systemctl", "disable", GETTY],
        ["systemctl", "enable", LY],
    ]
    assert states(login)[manager] == {"state": "disabled", "active": "active"}
    assert not (Path(login["HOME"]) / "etc/systemd/system/display-manager.service").exists()
    # All other recognized manager packages are deliberately absent in this fixture.
    assert all(call[-1] in (manager, GETTY, LY) for call in mutations(login))


@pytest.mark.parametrize("ownership", ["unknown", "ambiguous"])
def test_unexpected_alias_ownership_fails_before_changing_config_or_units(
    login: dict[str, str], tmp_path: Path, ownership: str
) -> None:
    add_manager(login, "custom-manager.service" if ownership == "unknown" else "sddm.service")
    if ownership == "ambiguous":
        add_manager(login, "greetd.service", scope="run")
    before = (states(login), (tmp_path / "etc/ly/config.ini").read_bytes())
    result = apply_login(login)
    assert result.returncode == 1, result.stderr
    assert "alias" in result.stderr or "ownership" in result.stderr
    assert mutations(login) == []
    assert (states(login), (tmp_path / "etc/ly/config.ini").read_bytes()) == before


@pytest.mark.parametrize(
    "failure,status,runtime",
    [
        ("FAIL_LY_ENABLE", 23, False),
        ("NO_ENABLE_EFFECT", 1, False),
        ("FAIL_DISABLE", 24, False),
        ("FAIL_LY_ENABLE", 23, True),
    ],
)
def test_failed_transition_restores_prior_enablement_and_config(
    login: dict[str, str], tmp_path: Path, failure: str, status: int, runtime: bool
) -> None:
    add_manager(login, "sddm.service")
    if runtime:
        units = states(login)
        units["sddm.service"]["runtime_enabled"] = "true"
        (tmp_path / "units.json").write_text(json.dumps(units))
        (tmp_path / "run/systemd/system/display-manager.service").symlink_to(
            tmp_path / "vendor/sddm.service"
        )
    login[failure] = "sddm.service" if failure == "FAIL_DISABLE" else "1"
    before = states(login)
    config = tmp_path / "etc/ly/config.ini"
    original = config.read_bytes()
    result = apply_login(login)
    assert result.returncode == status, result.stderr
    assert states(login) == before
    assert config.read_bytes() == original
    assert config.stat().st_mode & 0o777 == 0o640
    assert (
        tmp_path / "etc/systemd/system/display-manager.service"
    ).readlink() == tmp_path / "vendor/sddm.service"
    if runtime:
        assert (
            tmp_path / "run/systemd/system/display-manager.service"
        ).readlink() == tmp_path / "vendor/sddm.service"
    assert "Ly is enabled" not in result.stdout + result.stderr


def test_other_enabled_ly_instance_is_not_stopped_or_kept_for_next_boot(
    login: dict[str, str], tmp_path: Path
) -> None:
    units = states(login)
    units["ly@tty2.service"] = {"state": "enabled", "active": "active"}
    (tmp_path / "units.json").write_text(json.dumps(units))
    result = apply_login(login)
    assert result.returncode == 0, result.stderr
    assert states(login)["ly@tty2.service"] == {"state": "disabled", "active": "active"}
    assert states(login)["getty@tty2.service"]["state"] == "enabled"


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_chezmoi_order_retry_cache_and_stripped_privileged_environment(
    login: dict[str, str], tmp_path: Path, personal: bool
) -> None:
    assert CHEZMOI is not None
    source = Path(login["LOGIN_SOURCE"])
    scripts = source / ".chezmoiscripts/linux"
    for order in ("08", "10"):
        (scripts / f"run_onchange_after_{order}_probe.sh").write_text(
            f'#!/bin/sh\necho {order} >> "$HOME/order"\n'
        )
    config = tmp_path / "chezmoi.json"
    config.write_text(
        json.dumps({"scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "1" if personal else "0"}})
    )
    command = [
        CHEZMOI,
        "--config",
        str(config),
        "--source",
        str(source),
        "--destination",
        str(tmp_path / "target"),
        "--no-tty",
        "apply",
    ]
    login["FAIL_LY_ENABLE"] = "1"
    first = run_setup(login, command)
    assert (first.returncode != 0) == personal, first.stderr
    assert (tmp_path / "order").read_text() == ("08\n" if personal else "08\n10\n")
    if personal:
        assert states(login)[LY]["state"] == "disabled"
    else:
        assert calls(login) == []
    login.pop("FAIL_LY_ENABLE")
    retried = run_setup(login, command)
    assert retried.returncode == 0, retried.stderr
    assert (tmp_path / "order").read_text() == "08\n10\n"
    recorded = calls(login)
    cached = run_setup(login, command)
    assert cached.returncode == 0, cached.stderr
    assert calls(login) == recorded


def test_packaged_tty1_unit_and_getty_enablement_with_native_systemctl(tmp_path: Path) -> None:
    import subprocess

    native = shutil.which("systemctl")
    ly = Path("/usr/lib/systemd/system/ly@.service")
    getty = Path("/usr/lib/systemd/system/getty@.service")
    if native is None or not ly.exists() or not getty.exists():
        pytest.skip("Native offline unit validation requires systemctl and packaged Ly/getty units")
    units = tmp_path / "usr/lib/systemd/system"
    units.mkdir(parents=True)
    for path in (ly, getty):
        shutil.copy(path, units / path.name)
    (units / "autovt@.service").symlink_to("getty@.service")
    ly_text = ly.read_text()
    assert "TTYPath=/dev/%I" in ly_text and "Conflicts=getty@%i.service" in ly_text
    assert "WantedBy=multi-user.target" in ly_text
    assert "Alias=" not in ly_text
    for action, unit in (("enable", GETTY), ("disable", GETTY), ("enable", LY)):
        result = subprocess.run(
            [native, "--root", str(tmp_path), action, unit],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, result.stderr
    for unit, expected in ((GETTY, "disabled"), (LY, "enabled")):
        result = subprocess.run(
            [native, "--root", str(tmp_path), "is-enabled", unit],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.stdout.strip() == expected
    assert (units / "autovt@.service").readlink() == Path("getty@.service")

    (units / "sddm.service").write_text(
        "[Service]\nExecStart=/usr/bin/false\n[Install]\nWantedBy=graphical.target\nAlias=display-manager.service\n"
    )
    for flags, action, expected in (
        ([], "enable", "enabled"),
        (["--runtime"], "enable", "enabled"),
        ([], "disable", "enabled-runtime"),
        (["--runtime"], "disable", "disabled"),
    ):
        result = subprocess.run(
            [native, "--root", str(tmp_path), *flags, action, "sddm.service"],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, result.stderr
        result = subprocess.run(
            [native, "--root", str(tmp_path), "is-enabled", "sddm.service"],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.stdout.strip() == expected
    assert not (tmp_path / "etc/systemd/system/display-manager.service").is_symlink()
    assert not (tmp_path / "run/systemd/system/display-manager.service").is_symlink()
