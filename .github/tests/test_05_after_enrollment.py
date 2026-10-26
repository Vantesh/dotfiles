"""Enrollment preserves existing accounts and requires a usable fingerprint reader."""

import json
import shutil
from pathlib import Path
from typing import override

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS, ScriptCase
from test_setup import PYTHON, calls, render_python, run_setup, stub
from test_setup import env as env
from test_workstation import workstation as workstation


class AvatarTests(ScriptCase):
    def test_avatar_external_requires_personal_online_setup(self) -> None:
        external = ROOT / "home/.chezmoiexternals/20-avatar.yaml.tmpl"
        for personal, offline, enabled in (
            (True, "", True),
            (True, "1", False),
            (False, "", False),
            (False, "1", False),
        ):
            with self.subTest(personal=personal, offline=offline):
                self.env["OFFLINE"] = offline
                source = self.render(external, personal=personal)
                if enabled:
                    self.assertIn('".local/share/avatars/profile.png":', source)
                    self.assertIn('url: "https://github.com/Vantesh.png"', source)
                    self.assertIn("refreshPeriod: 168h", source)
                else:
                    self.assertEqual(source.strip(), "")


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
def test_chezmoi_registers_warp_after_services_and_retries_without_connecting(
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
    warp_env["WARP_NEW_STATUS"] = "23"
    failed = run_setup(warp_env, command)
    assert failed.returncode != 0
    assert "exit 23" in failed.stderr
    assert not (tmp_path / "registered").exists()
    observed = calls(warp_env)
    assert next(i for i, call in enumerate(observed) if call[0] == "mise") < next(
        i for i, call in enumerate(observed) if call[0] == "warp-cli"
    )
    warp_env["WARP_NEW_STATUS"] = "0"
    retried = run_setup(warp_env, command)
    assert retried.returncode == 0, retried.stderr
    assert (tmp_path / "registered").read_text() == "fixture-registration\n"
    observed = calls(warp_env)
    assert [call[1:] for call in observed if call[0] == "warp-cli"] == [
        ["--accept-tos", "registration", "show"],
        ["--accept-tos", "registration", "new"],
        ["--accept-tos", "registration", "show"],
        ["--accept-tos", "registration", "new"],
        ["--accept-tos", "registration", "show"],
    ]
    cached = run_setup(warp_env, command)
    assert cached.returncode == 0, cached.stderr
    assert calls(warp_env) == observed
    log = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    assert "account-private-fixture" not in log + retried.stdout + retried.stderr


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


class FingerprintTests(ScriptCase):
    @override
    def setUp(self) -> None:
        super().setUp()
        self.source = self.render(SCRIPTS / "run_onchange_after_16_fingerprint.sh.tmpl")
        self.stub("pacman", "exit 1")

    def test_fingerprint_enrollment_requires_a_reader_without_prints_and_interactive_consent(
        self,
    ) -> None:
        terminal = self.directory / "terminal"
        enrolled = self.directory / "enrolled"
        self.env["ENROLLED"] = str(enrolled)
        self.env["SUDO_USER"] = "fixture-user"
        source = self.source.replace("/dev/tty", str(terminal))
        enrollment = ["fprintd-enroll", "-f", "right-index-finger", "fixture-user"]
        self.stub(
            "id",
            """
case "$*" in
    -u) case "$FPRINT_CASE" in root-*) echo 0 ;; *) echo 1000 ;; esac ;;
    -un) echo fixture-user ;;
    '-u -- fixture-user') echo 1000 ;;
    '-u -- root') echo 0 ;;
    *) exit 97 ;;
esac
""",
        )
        self.stub(
            "ps",
            """
case "$FPRINT_CASE" in
    tty|tty-failed|root-tty) echo ' tty2' ;;
    terminal-unavailable) exit 1 ;;
    *) echo pts/3 ;;
esac
""",
        )
        self.stub(
            "sudo",
            """
if [ "$1" = -u ]; then
    [ "$2" = fixture-user ] || exit 97
    shift 2
    exec "$@"
fi
[ "$*" = 'fprintd-enroll -f right-index-finger fixture-user' ] || exit 97
PRIVILEGED=1 exec "$@"
""",
            log=True,
        )
        package_check = ["pacman", "-Q", "--", "libfprint-goodix53x5-533c-git"]
        self.stub(
            "pacman",
            """
[ "$*" = '-Q -- libfprint-goodix53x5-533c-git' ] || exit 97
case "$FPRINT_CASE" in
    packages-unused|packages-incomplete) exit 1 ;;
    package-query-failed) exit 23 ;;
    *) exit 0 ;;
esac
""",
            log=True,
        )
        manager = [
            "gdbus",
            "call",
            "--system",
            "--dest",
            "net.reactivated.Fprint",
            "--object-path",
            "/net/reactivated/Fprint/Manager",
            "--method",
            "net.reactivated.Fprint.Manager.GetDefaultDevice",
        ]
        listing = [
            "gdbus",
            "call",
            "--system",
            "--dest",
            "net.reactivated.Fprint",
            "--object-path",
            "/net/reactivated/Fprint/Device/0",
            "--method",
            "net.reactivated.Fprint.Device.ListEnrolledFingers",
            "fixture-user",
        ]
        self.stub(
            "gdbus",
            """
case "$*" in
    'call --system --dest net.reactivated.Fprint --object-path /net/reactivated/Fprint/Manager --method net.reactivated.Fprint.Manager.GetDefaultDevice')
        if [ "$FPRINT_CASE" = absent ]; then
            echo 'Error: GDBus.Error:net.reactivated.Fprint.Error.NoSuchDevice: No devices available' >&2
            exit 1
        fi
        echo "(objectpath '/net/reactivated/Fprint/Device/0',)" ;;
    'call --system --dest net.reactivated.Fprint --object-path /net/reactivated/Fprint/Device/0 --method net.reactivated.Fprint.Device.ListEnrolledFingers fixture-user')
        if [ -e "$ENROLLED" ] || [ "$FPRINT_CASE" = existing ]; then
            echo "(['right-index-finger'],)"; exit 0
        fi
        if [ "$FPRINT_CASE" = denied ]; then
            echo 'Error: GDBus.Error:net.reactivated.Fprint.Error.PermissionDenied: Not authorized' >&2
        elif [ "$FPRINT_CASE" = empty ]; then
            echo '(@as [],)'; exit 0
        else
            echo 'Error: GDBus.Error:net.reactivated.Fprint.Error.NoEnrolledPrints: No prints enrolled' >&2
        fi
        exit 1 ;;
    *) exit 97 ;;
esac
""",
            log=True,
        )
        self.stub(
            "fprintd-enroll",
            """
[ "$*" = '-f right-index-finger fixture-user' ] || exit 97
case "$FPRINT_CASE" in
    tty|root-tty|authorization)
        if [ "${PRIVILEGED:-0}" != 1 ]; then
            echo 'EnrollStart failed: GDBus.Error:net.reactivated.Fprint.Error.PermissionDenied: Not Authorized: net.reactivated.fprint.device.enroll'
            exit 1
        fi ;;
    failed|tty-failed) echo 'Enroll result: enroll-failed'; exit 23 ;;
    unsupported) echo 'EnrollStart failed: net.reactivated.Fprint.Error.EnrollNotSupported'; exit 1 ;;
    communication) echo 'EnrollStart failed: net.reactivated.Fprint.Error.Internal: communication failed'; exit 1 ;;
esac
echo 'right-index-finger' > "$ENROLLED"
""",
            log=True,
        )
        for scenario in (
            "tooling-unavailable",
            "packages-unused",
            "packages-incomplete",
            "package-query-failed",
            "absent",
            "existing",
            "denied",
            "declined",
            "headless",
            "unattended",
            "ci",
            "failed",
            "unsupported",
            "communication",
            "authorization",
            "tty",
            "tty-failed",
            "root-tty",
            "root-desktop",
            "terminal-unavailable",
            "root-unknown",
            "root-user",
            "empty",
            "fresh",
        ):
            with self.subTest(scenario=scenario):
                self.calls.unlink(missing_ok=True)
                enrolled.unlink(missing_ok=True)
                terminal.unlink(missing_ok=True)
                enroller = self.bin / "fprintd-enroll"
                if scenario == "tooling-unavailable":
                    enroller.rename(enroller.with_suffix(".disabled"))
                if scenario != "headless":
                    terminal.write_text("n\n" if scenario == "declined" else "y\n")
                self.env.update(
                    FPRINT_CASE=scenario,
                    CI="1" if scenario == "ci" else "",
                    NOCONFIRM="1" if scenario == "unattended" else "0",
                    SUDO_USER=""
                    if scenario == "root-unknown"
                    else "root"
                    if scenario == "root-user"
                    else "fixture-user",
                )
                result = self.shell(source)
                if scenario == "tooling-unavailable":
                    enroller.with_suffix(".disabled").rename(enroller)
                expected_status = {
                    "tooling-unavailable": 127,
                    "package-query-failed": 23,
                    "root-unknown": 1,
                    "root-user": 1,
                    "denied": 1,
                    "failed": 23,
                    "tty-failed": 23,
                    "unsupported": 1,
                    "communication": 1,
                    "authorization": 1,
                    "terminal-unavailable": 1,
                }.get(scenario, 0)
                self.assertEqual(result.returncode, expected_status, result.stderr)
                calls = self.logged_calls()
                self.assertEqual(
                    enrolled.exists(),
                    scenario in ("empty", "fresh", "tty", "root-tty", "root-desktop"),
                )
                if scenario == "ci":
                    self.assertEqual(calls, [])
                elif scenario in (
                    "tooling-unavailable",
                    "packages-unused",
                    "packages-incomplete",
                    "package-query-failed",
                    "root-unknown",
                    "root-user",
                ):
                    self.assertEqual(calls, [package_check])
                else:
                    self.assertIn(package_check, calls)
                    self.assertIn(manager, calls)
                    if scenario != "absent":
                        self.assertIn(listing, calls)
                    self.assertEqual(
                        enrollment in calls,
                        scenario
                        in (
                            "failed",
                            "unsupported",
                            "communication",
                            "empty",
                            "fresh",
                            "authorization",
                            "tty",
                            "tty-failed",
                            "root-tty",
                            "root-desktop",
                        ),
                    )
                    self.assertLessEqual(calls.count(enrollment), 1)
                privileged = ["sudo", *enrollment]
                self.assertEqual(privileged in calls, scenario in ("tty", "tty-failed", "root-tty"))
                if scenario in ("tty", "root-tty"):
                    self.assertLess(calls.index(privileged), calls.index(enrollment))
                if scenario == "root-desktop":
                    self.assertIn(["sudo", "-u", "fixture-user", *enrollment], calls)
                if scenario in (
                    "denied",
                    "failed",
                    "unsupported",
                    "communication",
                    "authorization",
                    "tty-failed",
                    "terminal-unavailable",
                ):
                    self.assertIn("ERROR:", result.stderr)
                if scenario in ("empty", "fresh"):
                    self.calls.unlink()
                    repeated = self.shell(source)
                    self.assertEqual(repeated.returncode, 0, repeated.stderr)
                    self.assertNotIn(enrollment, self.logged_calls())
                    self.assertEqual(enrolled.read_text(), "right-index-finger\n")
