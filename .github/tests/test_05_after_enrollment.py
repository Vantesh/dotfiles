"""Enrollment preserves existing accounts and requires a usable fingerprint reader."""

import json
import os
import pty
import pwd
import shutil
import subprocess
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import PYTHON, calls, render_python, run_setup, stub
from test_setup import env as env
from test_workstation import workstation as workstation

WARP = "run_onchange_after_15_warp.py"


@pytest.fixture
def warp_env(workstation: dict[str, str]) -> dict[str, str]:
    stub(
        workstation,
        "warp-cli",
        """case "$*" in
    '--accept-tos registration show')
        [ "${WARP_UNAVAILABLE:-0}" = 0 ] || exit "$WARP_UNAVAILABLE"
        if [ -f "$HOME/registered" ]; then
            [ "${WARP_VERIFY_STATUS:-0}" = 0 ] || exit "$WARP_VERIFY_STATUS"
            echo 'Account type: Team; account-private-fixture'
        else
            echo 'Error: Missing registration. Try running: "warp-cli registration new"' >&2
            exit 1
        fi ;;
    '--accept-tos registration new')
        [ "${WARP_NEW_STATUS:-0}" = 0 ] || exit "$WARP_NEW_STATUS"
        echo 'fixture-registration' > "$HOME/registered" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    return workstation


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_chezmoi_registers_warp_after_services_without_connecting(
    warp_env: dict[str, str], tmp_path: Path, personal: bool
) -> None:
    assert CHEZMOI is not None
    repository = tmp_path / "source"
    source = repository / "home"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "mise", repository / "mise")
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    for name in ("run_onchange_after_14_services.py.tmpl", WARP):
        shutil.copy(SCRIPTS / name, scripts / name)
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
        str(source),
        "--working-tree",
        str(repository),
        "--destination",
        str(tmp_path / "target"),
        "--no-tty",
        "apply",
    ]
    result = run_setup(warp_env, command)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "registered").read_text() == "fixture-registration\n"
    observed = calls(warp_env)
    assert next(i for i, call in enumerate(observed) if call[0] == "mise") < next(
        i for i, call in enumerate(observed) if call[0] == "warp-cli"
    )
    log = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    assert "account-private-fixture" not in log + result.stdout + result.stderr


def test_warp_reuses_existing_team_registration_without_mutation(
    warp_env: dict[str, str], tmp_path: Path
) -> None:
    existing = tmp_path / "registered"
    existing.write_text("existing-Team-registration")
    before = existing.stat().st_mtime_ns
    script = render_python(warp_env, WARP, personal=False)
    for _ in range(2):
        result = run_setup(warp_env, [PYTHON, "-B", str(script)])
        assert result.returncode == 0, result.stderr
        assert result.stdout == result.stderr == ""
    assert existing.read_text() == "existing-Team-registration"
    assert existing.stat().st_mtime_ns == before
    assert calls(warp_env) == [["warp-cli", "--accept-tos", "registration", "show"]] * 2


@pytest.mark.parametrize(
    "failure,status",
    [
        ("WARP_UNAVAILABLE", 24),
        ("WARP_NEW_STATUS", 23),
        ("WARP_VERIFY_STATUS", 27),
    ],
)
def test_warp_failure_is_required_and_preserves_exit_status(
    warp_env: dict[str, str], tmp_path: Path, failure: str, status: int
) -> None:
    warp_env[failure] = str(status)
    script = render_python(warp_env, WARP, personal=False)
    result = run_setup(warp_env, [PYTHON, "-B", str(script)])
    assert result.returncode == status, result.stderr
    assert f"WARP registration failed (exit {status})" in result.stderr
    assert "check warp-svc and reapply" in result.stderr
    assert "Traceback" not in result.stderr
    log = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    assert "CalledProcessError" in log
    assert "account-private-fixture" not in log + result.stdout + result.stderr


FINGERPRINT = "run_onchange_after_16_fingerprint.py"


@pytest.fixture
def fingerprint_env(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    reader = tmp_path / "usb/1-1"
    reader.mkdir(parents=True)
    (reader / "idVendor").write_text("27c6\n")
    (reader / "idProduct").write_text("5395\n")
    script = render_python(env, FINGERPRINT)
    script.write_text(
        script.read_text().replace('Path("/sys/bus/usb/devices")', f"Path({str(reader.parent)!r})")
    )
    stub(
        env,
        "pacman",
        '''if [ "${DRIVER_DATABASE_ERROR:-0}" = 1 ]; then
    echo 'error: could not open package database' >&2; exit 1
fi
if [ "${DRIVER_STATUS:-0}" = 1 ]; then
    echo "error: package 'libfprint-goodix53x5-533c-git' was not found" >&2
elif [ "${DRIVER_STATUS:-0}" != 0 ]; then
    echo 'error: could not read package database' >&2
fi
exit "${DRIVER_STATUS:-0}"''',
        log=True,
    )
    stub(env, "sudo", 'exec "$@"', log=True)
    stub(
        env,
        "gdbus",
        """case "$*" in
    *Manager.GetDefaultDevice)
        if [ "${NO_DEVICE:-0}" = 1 ]; then
            echo 'GDBus.Error:net.reactivated.Fprint.Error.NoSuchDevice: No devices available' >&2
            exit 1
        fi
        [ "${MANAGER_STATUS:-0}" = 0 ] || exit "$MANAGER_STATUS"
        echo "(objectpath '/net/reactivated/Fprint/Device/0',)" ;;
    *Properties.Get*)
        if [ "${OTHER_READER:-0}" = 1 ]; then echo "(<'Other fingerprint reader'>,)"
        else echo "(<'Goodix HTK32 Fingerprint Sensor'>,)"; fi ;;
    *ListEnrolledFingers*)
        if [ "${LIST_STATUS:-0}" != 0 ]; then
            echo 'GDBus.Error:net.reactivated.Fprint.Error.PermissionDenied: Not authorized' >&2
            exit "$LIST_STATUS"
        fi
        if [ -f "$HOME/enrolled" ]; then echo "(['right-index-finger'],)"
        else
            echo 'GDBus.Error:net.reactivated.Fprint.Error.NoEnrolledPrints: No prints enrolled' >&2
            exit 1
        fi ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        env,
        "fprintd-enroll",
        '''echo 'native-biometric-output-fixture'
[ "${ENROLL_STATUS:-0}" = 0 ] || exit "$ENROLL_STATUS"
[ "${NO_SAVED_PRINT:-0}" = 0 ] || exit 0
touch "$HOME/enrolled"''',
        log=True,
    )
    return env


def fingerprint_with_terminal(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    setsid = shutil.which("setsid")
    assert setsid is not None
    master, slave = pty.openpty()
    try:
        return subprocess.run(
            [setsid, "--ctty", "--wait", PYTHON, "-B", str(Path(env["HOME"]) / FINGERPRINT)],
            stdin=slave,
            capture_output=True,
            text=True,
            env=env,
            check=False,
            timeout=15,
        )
    finally:
        os.close(slave)
        os.close(master)


@pytest.mark.parametrize(
    "scenario", ["absent", "unsupported", "driver-missing", "no-device", "other-reader", "enrolled"]
)
def test_fingerprint_requires_the_supported_reader_and_preserves_existing_prints(
    fingerprint_env: dict[str, str], tmp_path: Path, scenario: str
) -> None:
    if scenario == "absent":
        shutil.rmtree(tmp_path / "usb/1-1")
    elif scenario == "unsupported":
        (tmp_path / "usb/1-1/idProduct").write_text("0000\n")
    elif scenario == "driver-missing":
        fingerprint_env["DRIVER_STATUS"] = "1"
    elif scenario == "no-device":
        fingerprint_env["NO_DEVICE"] = "1"
    elif scenario == "other-reader":
        fingerprint_env["OTHER_READER"] = "1"
    else:
        (tmp_path / "enrolled").write_text("existing-print")
    result = run_setup(fingerprint_env, [PYTHON, "-B", str(tmp_path / FINGERPRINT)])
    assert result.returncode == 0, result.stderr
    observed = calls(fingerprint_env)
    assert not any(call[0] in ("sudo", "fprintd-enroll") for call in observed)
    if scenario in ("absent", "unsupported"):
        assert observed == []
        assert "No supported Goodix 27c6:5395 reader detected" in result.stderr
    elif scenario == "driver-missing":
        assert observed == [["pacman", "-Q", "--", "libfprint-goodix53x5-533c-git"]]
        assert "no declared compatible driver" in result.stderr
    elif scenario == "no-device":
        assert "fprintd has no available fingerprint reader" in result.stderr
    elif scenario == "other-reader":
        assert "not the supported Goodix driver" in result.stderr
    elif scenario == "enrolled":
        assert (tmp_path / "enrolled").read_text() == "existing-print"


@pytest.mark.parametrize("flag", ["CI", "NOCONFIRM", "headless"])
def test_fingerprint_unattended_execution_never_enrolls(
    fingerprint_env: dict[str, str], tmp_path: Path, flag: str
) -> None:
    command = [PYTHON, "-B", str(tmp_path / FINGERPRINT)]
    if flag == "headless":
        setsid = shutil.which("setsid")
        assert setsid is not None
        command = [setsid, "--wait", *command]
    else:
        fingerprint_env[flag] = "1"
    result = run_setup(fingerprint_env, command)
    assert result.returncode == 0, result.stderr
    assert not (tmp_path / "enrolled").exists()
    assert not any(call[0] in ("sudo", "fprintd-enroll") for call in calls(fingerprint_env))
    if flag == "headless":
        assert "Fingerprint enrollment needs a terminal" in result.stderr
    else:
        assert calls(fingerprint_env) == []
        assert "Fingerprint enrollment skipped unattended" in result.stderr


def test_fingerprint_enrollment_starts_without_consent_and_is_verified_before_success(
    fingerprint_env: dict[str, str], tmp_path: Path
) -> None:
    result = fingerprint_with_terminal(fingerprint_env)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "enrolled").exists()
    assert "Starting fingerprint enrollment; touch the reader when prompted" in result.stderr
    assert "Fingerprint enrollment completed" in result.stderr
    repeated = fingerprint_with_terminal(fingerprint_env)
    assert repeated.returncode == 0, repeated.stderr
    user = pwd.getpwuid(os.getuid()).pw_name
    assert [call for call in calls(fingerprint_env) if call[0] == "fprintd-enroll"] == [
        ["fprintd-enroll", "-f", "right-index-finger", user]
    ]
    assert ["sudo", "fprintd-enroll", "-f", "right-index-finger", user] in calls(fingerprint_env)
    log = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    assert "native-biometric-output-fixture" not in log + result.stdout + result.stderr


@pytest.mark.parametrize(
    "failure,status",
    [
        ("DRIVER_STATUS", 23),
        ("DRIVER_DATABASE_ERROR", 1),
        ("MANAGER_STATUS", 24),
        ("LIST_STATUS", 25),
        ("ENROLL_STATUS", 26),
        ("NO_SAVED_PRINT", 1),
    ],
)
def test_fingerprint_required_failures_never_claim_success(
    fingerprint_env: dict[str, str], tmp_path: Path, failure: str, status: int
) -> None:
    fingerprint_env[failure] = "1" if failure == "NO_SAVED_PRINT" else str(status)
    result = fingerprint_with_terminal(fingerprint_env)
    assert result.returncode == status, result.stderr
    assert f"Fingerprint setup failed (exit {status})" in result.stderr
    assert "Fingerprint enrollment completed" not in result.stderr
    assert not (tmp_path / "enrolled").exists()
    assert "Traceback" not in result.stderr
    if failure == "NO_SAVED_PRINT":
        assert "no enrolled prints" in result.stderr
    if failure.startswith("DRIVER_"):
        assert "package database" in result.stderr
    if failure in ("DRIVER_STATUS", "DRIVER_DATABASE_ERROR", "MANAGER_STATUS", "LIST_STATUS"):
        assert not any(call[0] == "fprintd-enroll" for call in calls(fingerprint_env))
