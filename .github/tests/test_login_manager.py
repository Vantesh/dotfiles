"""Isolated regressions for Ly migration state guards and config rollback."""

import json
import os
import signal
import stat
import subprocess

from script_helpers import SCRIPTS, ScriptCase


SYSTEMCTL_STUB = r"""
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(os.environ["FIXTURE_ROOT"])
args = sys.argv[1:]
operation = " ".join(args)
with (Path(os.environ["HOME"]) / "commands").open("a") as log:
    log.write(operation + "\n")

def unitfile(unit):
    path = root / "usr/lib/systemd/system" / unit
    if not path.exists() and "@" in unit:
        path = path.with_name(unit.split("@")[0] + "@.service")
    return path

if args[0] == "show":
    unit = args[-1]
    if args[1] == "--property=LoadState":
        print("loaded" if unitfile(unit).exists() else "not-found")
    elif args[1] == "--property=Id":
        print(unit)
    else:
        sys.exit(97)
elif args[0] == "cat":
    print(unitfile(args[-1]).read_text())
elif args == ["daemon-reload"]:
    pass
elif args[0] == "is-enabled" or "enable" in args or "disable" in args:
    if args == ["is-enabled", "gdm.service"] and os.environ.get("INDIRECT"):
        # Also= is deliberately unsupported by preflight; model only its state.
        print("indirect")
        sys.exit(0)
    if "disable" in args and args[-1] == os.environ.get("FORBID_DISABLE"):
        print("Attempted to disable a skipped competitor", file=sys.stderr)
        sys.exit(97)
    result = subprocess.run(
        ["/usr/bin/systemctl", "--root", str(root), *args], check=False
    )
    if operation == os.environ.get("INTERRUPT_OPERATION"):
        published = {
            name: (root / "etc/ly" / name).read_text()
            for name in ("config.ini", "save.ini")
        }
        (Path(os.environ["HOME"]) / "published.json").write_text(json.dumps(published))
        if os.environ.get("CANCEL"):
            target = (
                int(os.environ["FIXTURE_PARENT_PID"])
                if os.environ.get("PARENT_CANCEL") else os.getppid()
            )
            if os.environ.get("GROUP_CANCEL"):
                group = os.getpgid(int(os.environ["FIXTURE_PARENT_PID"]))
                if group != int(os.environ["FIXTURE_PARENT_PID"]) or group == int(os.environ["FIXTURE_RUNNER_PGID"]):
                    sys.exit("Refusing to signal a non-isolated process group")
                os.killpg(group, int(os.environ["CANCEL"]))
            else:
                os.kill(target, int(os.environ["CANCEL"]))
        else:
            sys.exit(1)
    sys.exit(result.returncode)
else:
    print("Unexpected systemctl operation: " + repr(args), file=sys.stderr)
    sys.exit(97)
"""


class LoginManagerTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.root = self.directory / "root"
        self.units = self.root / "usr/lib/systemd/system"
        self.etc = self.root / "etc/systemd/system"
        self.run = self.root / "run/systemd/system"
        for directory in (self.units, self.etc, self.run):
            directory.mkdir(parents=True)
        self.env.update(FIXTURE_ROOT=str(self.root), USER="fixture")
        for unit, target in (
            ("ly@.service", "multi-user.target"),
            ("getty@.service", "getty.target"),
            ("sddm.service", "graphical.target"),
            ("gdm.service", "graphical.target"),
        ):
            self.write_unit(unit, target)
        self.config = self.root / "etc/ly/config.ini"
        self.config.parent.mkdir()
        self.config.write_text("#allow_empty_password = true\n# fixture config\n")
        self.config.chmod(0o640)
        self.save = self.config.with_name("save.ini")
        self.save.write_text("user=previous\nsession_index=7\n")
        self.save.chmod(0o600)
        ly = self.root / "usr/bin/ly-dm"
        ly.parent.mkdir(parents=True)
        ly.write_text("fixture")
        ly.chmod(0o755)
        self.link("graphical.target.wants/sddm.service", self.units / "sddm.service")
        self.link("display-manager.service", "../../../usr/lib/systemd/system/sddm.service")
        self.link("getty.target.wants/getty@tty2.service", self.units / "getty@.service")
        self.stub("sudo", 'case "$1" in -v|-n) exit 0;; *) exec "$@";; esac')
        systemctl = self.bin / "systemctl"
        systemctl.write_text("#!/usr/bin/python3\n" + SYSTEMCTL_STUB)
        systemctl.chmod(0o755)
        self.source = self.render(SCRIPTS / "run_onchange_after_09_login_manager.sh.tmpl")
        for original in ("/etc/systemd/system", "/run/systemd/system", "/usr/bin/ly-dm", "/etc/ly"):
            self.source = self.source.replace(original, str(self.root) + original)
        self.source = self.source.replace(
            'main "$@"',
            'print_box() { :; }; export FIXTURE_PARENT_PID=$BASHPID; main "$@"',
        )

    def write_unit(self, name, target=None):
        contents = "[Unit]\nDescription=Fixture\n[Service]\nExecStart=/bin/true\n"
        if target:
            contents += f"[Install]\nWantedBy={target}\n"
        (self.units / name).write_text(contents)

    def link(self, name, target):
        path = self.etc / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(target)

    def links(self):
        return {
            str(path): os.readlink(path)
            for directory in (self.etc, self.run)
            for path in directory.rglob("*")
            if path.is_symlink()
        }

    def files(self):
        return {
            path.name: (path.read_bytes(), stat.S_IMODE(path.stat().st_mode))
            if path.exists() else None
            for path in (self.config, self.save)
        }

    def migrate(self):
        script = self.directory / "login-manager"
        script.write_text(self.source)
        self.env["FIXTURE_RUNNER_PGID"] = str(os.getpgrp())
        try:
            # A separate session keeps group cancellation away from the runner/editor.
            result = subprocess.run(
                ["/bin/bash", str(script)], cwd=self.directory, env=self.env,
                capture_output=True, text=True, check=False, timeout=15,
                start_new_session=True,
            )
        except subprocess.TimeoutExpired:
            self.fail("isolated login-manager migration timed out after 15s")
        calls = (self.directory / "commands").read_text().splitlines()
        for call in calls:
            self.assertFalse(
                set(call.split()) & {"start", "stop", "restart", "isolate", "--now", "mask"},
                call,
            )
        return result, calls

    def assert_competitor_skipped(self):
        self.env["FORBID_DISABLE"] = "gdm.service"
        result, calls = self.migrate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("enable ly@tty2.service", calls)
        self.assertFalse(any("disable" in call.split() and call.endswith("gdm.service") for call in calls))

    def test_static_competitor_is_not_disabled(self):
        self.write_unit("gdm.service")
        self.assert_competitor_skipped()

    def test_indirect_competitor_is_not_disabled(self):
        self.env["INDIRECT"] = "1"
        self.assert_competitor_skipped()

    def test_disabled_competitor_is_not_disabled(self):
        self.assert_competitor_skipped()

    def assert_failed_migration_restores_files(
        self, *, cancel=False, parent_cancel=False, cancel_signal=signal.SIGTERM
    ):
        before_files, before_links = self.files(), self.links()
        # Fail after real systemctl has already removed persistent manager links.
        operation = "disable sddm.service"
        self.env["INTERRUPT_OPERATION"] = operation
        if cancel:
            self.env["CANCEL"] = str(int(cancel_signal))
        if parent_cancel:
            self.env["PARENT_CANCEL"] = "1"
        result, calls = self.migrate()
        self.assertEqual(result.returncode, 128 + cancel_signal if cancel else 1, result.stderr)
        self.assertIn(operation, calls)
        published = json.loads((self.directory / "published.json").read_text())
        self.assertIn("allow_empty_password=false", published["config.ini"])
        self.assertEqual(published["save.ini"], "user=fixture\nsession_index=2\n")
        self.assertEqual(self.files(), before_files, result.stderr)
        self.assertEqual(self.links(), before_links, result.stderr)

    def test_disable_failure_restores_both_existing_files_and_modes(self):
        self.assert_failed_migration_restores_files()

    def test_disable_failure_removes_previously_absent_save_file(self):
        self.save.unlink()
        self.assert_failed_migration_restores_files()

    def test_cancellation_restores_files_modes_and_enablement(self):
        self.assert_failed_migration_restores_files(cancel=True)

    def test_parent_only_sigterm_restores_files_modes_and_enablement(self):
        self.assert_failed_migration_restores_files(cancel=True, parent_cancel=True)

    def test_parent_only_sigint_restores_files_modes_and_enablement(self):
        self.assert_failed_migration_restores_files(
            cancel=True, parent_cancel=True, cancel_signal=signal.SIGINT
        )

    def test_process_group_sigterm_restores_files_modes_and_enablement(self):
        self.env["GROUP_CANCEL"] = "1"
        self.assert_failed_migration_restores_files(cancel=True)

    def test_parent_sigterm_during_committed_cleanup_keeps_files_and_enablement(self):
        sudo = self.bin / "sudo"
        sudo.write_text("#!/usr/bin/python3\n" + r"""
import os
import signal
import sys
from pathlib import Path

args = sys.argv[1:]
if args[0] in ("-v", "-n"):
    sys.exit(0)
if args[:3] == ["rm", "-f", "--"] and len(args) == 4:
    stage = Path(args[3])
    if stage.parent == Path(os.environ["FIXTURE_ROOT"]) / "etc/ly" and stage.name.startswith("config.ini.chezmoi."):
        (Path(os.environ["HOME"]) / "cleanup-signal").touch()
        os.kill(int(os.environ["FIXTURE_PARENT_PID"]), signal.SIGTERM)
os.execvp(args[0], args)
""")
        result, calls = self.migrate()
        self.assertTrue((self.directory / "cleanup-signal").exists())
        self.assertEqual(result.returncode, 143, result.stderr)
        self.assert_committed_configuration(calls)

    def test_success_retains_published_configuration(self):
        result, calls = self.migrate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_committed_configuration(calls)

    def assert_committed_configuration(self, calls):
        self.assertIn("allow_empty_password=false", self.config.read_text())
        self.assertIn("# fixture config", self.config.read_text())
        self.assertEqual(self.save.read_text(), "user=fixture\nsession_index=2\n")
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o640)
        self.assertEqual(stat.S_IMODE(self.save.stat().st_mode), 0o600)
        self.assertIn("disable sddm.service", calls)
        self.assertTrue((self.etc / "multi-user.target.wants/ly@tty2.service").is_symlink())
        self.assertFalse((self.etc / "display-manager.service").is_symlink())
        self.assertFalse((self.etc / "graphical.target.wants/sddm.service").is_symlink())
        self.assertFalse((self.etc / "getty.target.wants/getty@tty2.service").is_symlink())
