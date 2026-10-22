"""Enrollment preserves existing accounts and requires a usable fingerprint reader."""

from helpers import SCRIPTS, ScriptCase


class EnrollmentTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.source = self.render(SCRIPTS / "run_onchange_after_15_enrollment.sh.tmpl")
        self.stub("figlet", "exit 0")

    def test_warp_registration_is_created_once_without_connecting(self):
        registration = self.directory / "registration"
        self.env["REGISTRATION"] = str(registration)
        self.stub("warp-cli", """
case "$*" in
    '--accept-tos registration show')
        if [ -e "$REGISTRATION" ]; then echo 'Account type: Free'; else
            echo 'Error: Missing registration. Try running: "warp-cli registration new"' >&2
            exit 1
        fi ;;
    '--accept-tos registration new') echo 'fixture-account' > "$REGISTRATION" ;;
    *) exit 97 ;;
esac
""", log=True)
        for attempt in ("initial", "repeated"):
            with self.subTest(attempt=attempt):
                result = self.shell(self.source)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(registration.is_file(), result.stderr)
                self.assertEqual(registration.read_text(), "fixture-account\n")
        self.assertEqual(self.logged_calls(), [
            ["warp-cli", "--accept-tos", "registration", "show"],
            ["warp-cli", "--accept-tos", "registration", "new"],
            ["warp-cli", "--accept-tos", "registration", "show"],
        ])

    def test_warp_preserves_existing_registration_and_reports_unavailable_setup(self):
        self.stub("warp-cli", """
case "$*" in
    '--accept-tos registration show')
        case "$WARP_CASE" in
            existing) echo 'Account type: Team'; exit 0 ;;
            unavailable) echo 'Unable to connect to CloudflareWARP daemon' >&2 ;;
            failed) echo 'Error: Missing registration.' >&2 ;;
        esac
        exit 1 ;;
    '--accept-tos registration new') exit 23 ;;
    *) exit 97 ;;
esac
""", log=True)
        for scenario in ("existing", "unavailable", "failed", "ci"):
            with self.subTest(scenario=scenario):
                self.calls.unlink(missing_ok=True)
                self.env.update(WARP_CASE=scenario, CI="1" if scenario == "ci" else "")
                result = self.shell(self.source)
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = [] if scenario == "ci" else [
                    ["warp-cli", "--accept-tos", "registration", "show"],
                ]
                if scenario == "failed":
                    expected.append(["warp-cli", "--accept-tos", "registration", "new"])
                self.assertEqual(self.logged_calls(), expected)
                if scenario in ("unavailable", "failed"):
                    self.assertIn("WARN:", result.stderr)

    def test_fingerprint_enrollment_requires_a_reader_without_prints_and_interactive_consent(self):
        terminal = self.directory / "terminal"
        enrolled = self.directory / "enrolled"
        self.env["ENROLLED"] = str(enrolled)
        source = self.source.replace("/dev/tty", str(terminal))
        package_check = ["pacman", "-Q", "--", "libfprint-goodix53x5-533c-git", "fprintd"]
        self.stub("pacman", """
[ "$*" = '-Q -- libfprint-goodix53x5-533c-git fprintd' ] || exit 97
case "$FPRINT_CASE" in
    packages-unused|packages-incomplete) exit 1 ;;
    package-query-failed) exit 23 ;;
    *) exit 0 ;;
esac
""", log=True)
        manager = ["gdbus", "call", "--system", "--dest", "net.reactivated.Fprint",
                   "--object-path", "/net/reactivated/Fprint/Manager",
                   "--method", "net.reactivated.Fprint.Manager.GetDefaultDevice"]
        listing = ["gdbus", "call", "--system", "--dest", "net.reactivated.Fprint",
                   "--object-path", "/net/reactivated/Fprint/Device/0",
                   "--method", "net.reactivated.Fprint.Device.ListEnrolledFingers", ""]
        self.stub("gdbus", """
case "$*" in
    'call --system --dest net.reactivated.Fprint --object-path /net/reactivated/Fprint/Manager --method net.reactivated.Fprint.Manager.GetDefaultDevice')
        if [ "$FPRINT_CASE" = absent ]; then
            echo 'Error: GDBus.Error:net.reactivated.Fprint.Error.NoSuchDevice: No devices available' >&2
            exit 1
        fi
        echo "(objectpath '/net/reactivated/Fprint/Device/0',)" ;;
    'call --system --dest net.reactivated.Fprint --object-path /net/reactivated/Fprint/Device/0 --method net.reactivated.Fprint.Device.ListEnrolledFingers ')
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
""", log=True)
        self.stub("fprintd-enroll", """
[ "$#" = 0 ] || exit 97
[ "$FPRINT_CASE" != failed ] || exit 23
echo 'right-index-finger' > "$ENROLLED"
""", log=True)
        for scenario in ("packages-unused", "packages-incomplete", "package-query-failed",
                         "absent", "existing", "denied", "declined", "headless",
                         "unattended", "ci", "failed", "empty", "fresh"):
            with self.subTest(scenario=scenario):
                self.calls.unlink(missing_ok=True)
                enrolled.unlink(missing_ok=True)
                terminal.unlink(missing_ok=True)
                if scenario != "headless":
                    terminal.write_text("n\n" if scenario == "declined" else "y\n")
                self.env.update(FPRINT_CASE=scenario, CI="1" if scenario == "ci" else "",
                                NOCONFIRM="1" if scenario == "unattended" else "0")
                result = self.shell(source)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = self.logged_calls()
                self.assertEqual(enrolled.exists(), scenario in ("empty", "fresh"))
                if scenario == "ci":
                    self.assertEqual(calls, [])
                elif scenario in ("packages-unused", "packages-incomplete", "package-query-failed"):
                    self.assertEqual(calls, [package_check])
                else:
                    self.assertIn(package_check, calls)
                    self.assertIn(manager, calls)
                    if scenario != "absent":
                        self.assertIn(listing, calls)
                    self.assertEqual(["fprintd-enroll"] in calls,
                                     scenario in ("failed", "empty", "fresh"))
                if scenario in ("denied", "failed"):
                    self.assertIn("WARN:", result.stderr)
                if scenario in ("empty", "fresh"):
                    self.calls.unlink()
                    repeated = self.shell(source)
                    self.assertEqual(repeated.returncode, 0, repeated.stderr)
                    self.assertNotIn(["fprintd-enroll"], self.logged_calls())
                    self.assertEqual(enrolled.read_text(), "right-index-finger\n")
