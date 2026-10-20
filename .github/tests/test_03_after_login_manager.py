"""Verify display-manager handoff ordering without invoking systemctl."""

from helpers import SCRIPTS, ScriptCase


class LoginManagerTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.env.update(
            LY_STATE="enabled",
            LY_LINK="/etc/systemd/system/multi-user.target.wants/ly@tty2.service",
        )
        self.stub("change_enablement", "exit 0", log=True)
        self.stub(
            "unit_state",
            """case "$1" in
                ly@tty2.service) printf "%s\n" "$LY_STATE" ;;
                sddm.service) printf "%s\n" disabled ;;
                *) exit 97 ;;
            esac""",
            log=True,
        )
        self.stub(
            "sudo",
            """[ "$#" -eq 3 ] && [ "$1" = test ] &&
            [ "$2" = -L ] && [ "$3" = "$LY_LINK" ]""",
            log=True,
        )
        self.stub("systemctl", "exit 97", log=True)

    def migrate(self):
        function = self.function(
            SCRIPTS / "run_onchange_after_09_login_manager.sh.tmpl",
            "migrate_display_managers",
        )
        return self.shell(
            "set -euo pipefail\n"
            + self.libraries("common.sh")
            + "\n" + function + """
            declare -A DM_STATES=(
                [ly@tty2.service]=disabled
                [sddm.service]=enabled
                [getty@tty2.service]=enabled
            )
            migrate_display_managers
            """,
            name="display-manager handoff",
        )

    def test_ly_is_enabled_and_verified_before_previous_manager_and_getty_disable(self):
        result = self.migrate()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.logged_calls()
        enabled = calls.index(["change_enablement", "enable", "ly@tty2.service"])
        verified = calls.index(["unit_state", "ly@tty2.service"])
        linked = calls.index(["sudo", "test", "-L", self.env["LY_LINK"]])
        self.assertLess(enabled, verified)
        self.assertLess(verified, linked)
        for unit in ("sddm.service", "getty@tty2.service"):
            disabled = calls.index(["change_enablement", "disable", unit])
            runtime = calls.index(["change_enablement", "--runtime", "disable", unit])
            self.assertLess(linked, disabled)
            self.assertLess(disabled, runtime)
        self.assertLess(
            calls.index(["change_enablement", "--runtime", "disable", "sddm.service"]),
            calls.index(["change_enablement", "disable", "getty@tty2.service"]),
        )
        self.assertFalse(any(call[0] == "systemctl" for call in calls))

    def test_failed_ly_verification_leaves_previous_manager_and_getty_enabled(self):
        self.env["LY_STATE"] = "disabled"
        result = self.migrate()
        self.assertNotEqual(result.returncode, 0)
        calls = self.logged_calls()
        self.assertIn(["change_enablement", "enable", "ly@tty2.service"], calls)
        self.assertIn(["unit_state", "ly@tty2.service"], calls)
        self.assertFalse(any("disable" in call for call in calls))
        self.assertFalse(any(call[0] == "systemctl" for call in calls))
