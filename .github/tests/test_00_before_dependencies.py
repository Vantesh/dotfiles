"""Before hooks must stop when essential package installation fails."""

import json
import os
import pty
import shutil
import subprocess
import tomllib

from helpers import CHEZMOI, ROOT, SCRIPTS, ScriptCase


class SetupPreferenceTests(ScriptCase):
    def setUp(self):
        super().setUp()
        if not CHEZMOI:
            self.skipTest("chezmoi is required for profile initialization")
        self.source = self.directory / "source"
        self.source.mkdir()
        (self.source / ".chezmoi.yaml.tmpl").write_text(
            (ROOT / "home/.chezmoi.yaml.tmpl").read_text()
        )
        self.config = self.directory / "chezmoi.yaml"
        self.stub("git", 'exec /usr/bin/git "$@"')
        self.command = [
            CHEZMOI,
            "--config",
            str(self.config),
            "--source",
            str(self.source),
            "--destination",
            str(self.directory / "destination"),
            "--no-tty",
        ]

    def test_fresh_profiles_persist_only_the_personal_choice(self):
        for personal in (False, True):
            with self.subTest(personal=personal):
                self.config.unlink(missing_ok=True)
                command = self.command + [
                    "--override-data",
                    '{"chezmoi":{"osRelease":{"id":"arch"}}}',
                ]
                result = self.run_process(
                    command
                    + ["init", "--promptBool", f"Is this a personal setup={str(personal).lower()}"],
                    name="initialize profile",
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                result = self.run_process(
                    command + ["dump-config", "--format=json"], name="read profile"
                )
                config = json.loads(result.stdout)
                self.assertEqual(config["data"], {"personal": personal, "distroFamily": "arch"})
                self.assertEqual(
                    config["scriptEnv"],
                    {
                        "PERSONAL": "1" if personal else "0",
                        "DISTRO": "arch",
                        "DISTRO_FAMILY": "arch",
                    },
                )
                # Reinitializing this architecture preserves the selected profile.
                self.env["NOCONFIRM"] = "1"
                result = self.run_process(command + ["init"], name="repeat initialization")
                self.assertEqual(result.returncode, 0, result.stderr)
                repeated = self.run_process(
                    command + ["dump-config", "--format=json"], name="read repeated profile"
                )
                self.assertEqual(json.loads(repeated.stdout)["data"], config["data"])
                self.env.pop("NOCONFIRM")

    def test_arch_family_is_accepted_and_non_arch_is_rejected(self):
        for release, accepted in (
            ({"id": "arch", "idLike": ""}, True),
            ({"id": "cachyos", "idLike": "arch"}, True),
            ({"id": "debian", "idLike": ""}, False),
        ):
            with self.subTest(release=release):
                self.config.unlink(missing_ok=True)
                template = (ROOT / "home/.chezmoi.yaml.tmpl").read_text()
                # init supplies native OS metadata; substitute just that input.
                (self.source / ".chezmoi.yaml.tmpl").write_text(
                    '{{- $_ := set .chezmoi "osRelease" (fromJson '
                    + json.dumps(json.dumps(release))
                    + ") -}}\n"
                    + template
                )
                result = self.run_process(
                    self.command + ["init", "--promptDefaults"], name="initialize distribution"
                )
                self.assertEqual(result.returncode == 0, accepted, result.stdout + result.stderr)
                if accepted:
                    self.assertIn("personal: false", self.config.read_text())

    def test_nonpersonal_apply_installs_baseline_without_provisioning_and_reapplies_cleanly(self):
        # Exercise real chezmoi rendering, hooks and file modifiers in a private home.
        # Only external package operations are substituted; any personal operation fails.
        self.env.update(NOCONFIRM="1", OFFLINE="1", CHEZMOI_SOURCE_DIR=str(ROOT / "home"))
        for name in ("python3", "sleep", "ln"):
            (self.bin / name).symlink_to(shutil.which(name))
        self.stub("chezmoi", f'exec {CHEZMOI} "$@"')
        self.stub("id", "echo 1000")
        self.stub("yay", "exit 97")
        self.stub("pacman", '[ "$1" = -Q ] || exit 127')
        self.stub("pacman-conf", '[ "$*" = --repo-list ] || exit 97; echo chaotic-aur')
        self.stub(
            "sudo",
            r"""case "$*" in
    -v|'-n true'|'pacman -Syu --noconfirm') exit 0 ;;
    *) echo "Unexpected provisioning: $*" >&2; exit 97 ;;
esac""",
            log=True,
        )
        self.stub(
            "mise",
            '[ "$*" = "--env packages bootstrap packages apply --yes" ] || exit 97',
            log=True,
        )
        for name in (
            "rbw",
            "lspci",
            "hostnamectl",
            "systemctl",
            "gsettings",
            "sbctl",
            "findmnt",
            "busctl",
        ):
            self.stub(name, 'echo "Unexpected personal operation" >&2; exit 97', log=True)
        command = [
            CHEZMOI,
            "--config",
            str(self.config),
            "--source",
            str(ROOT),
            "--working-tree",
            str(ROOT),
            "--destination",
            str(self.directory),
            "--no-tty",
            "--override-data",
            '{"chezmoi":{"osRelease":{"id":"arch"}}}',
        ]
        result = self.run_process(command + ["init", "--data=false"], name="initialize nonpersonal")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        before = None
        for attempt in range(2):
            result = self.run_process(command + ["apply"], name="apply nonpersonal")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn("command not found", result.stderr)
            self.assertTrue((self.directory / ".config/fish/config.fish").is_file())
            self.assertFalse((self.directory / ".ssh/id_rsa").exists())
            self.assertFalse((self.directory / ".config/git/identity").exists())
            self.assertNotIn(
                "CHEZMOI_GITHUB_ACCESS_TOKEN",
                (self.directory / ".config/fish/conf.d/secrets.fish").read_text()
                if (self.directory / ".config/fish/conf.d/secrets.fish").exists()
                else "",
            )
            result = self.run_process(
                command + ["verify", "--exclude=scripts"], name="verify nonpersonal files"
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            current = {
                str(path.relative_to(self.directory)): (path.read_bytes(), path.stat().st_mtime_ns)
                for path in (self.directory / ".config").rglob("*")
                if path.is_file() and not path.is_symlink()
            }
            if attempt:
                self.assertEqual(current, before)
            before = current
        calls = self.logged_calls()
        self.assertEqual(
            [call for call in calls if call[0] == "mise"],
            [["mise", "--env", "packages", "bootstrap", "packages", "apply", "--yes"]],
        )
        self.assertFalse(any(call[0] not in ("sudo", "mise") for call in calls), calls)

    def test_personal_secret_settings_are_applied_once_and_excluded_from_nonpersonal(self):
        self.stub(
            "rbw",
            '[ "$*" = "get --field client_id spotify" ] || exit 97; echo fixture-client-id',
            log=True,
        )
        for personal in (False, True):
            with self.subTest(personal=personal):
                self.calls.unlink(missing_ok=True)
                script = self.directory / "spotifast.py"
                script.write_text(
                    self.render(
                        ROOT / "home/dot_config/spotifast/modify_settings.json.tmpl",
                        personal=personal,
                    )
                )
                command = [shutil.which("python3"), str(script)]
                result = self.run_process(command, input="{}", name="apply secret settings")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    json.loads(result.stdout).get("web_client_id"),
                    "fixture-client-id" if personal else None,
                )
                repeated = self.run_process(
                    command, input=result.stdout, name="reapply secret settings"
                )
                self.assertEqual(repeated.returncode, 0, repeated.stderr)
                self.assertEqual(repeated.stdout, result.stdout)
                self.assertEqual(
                    self.logged_calls(),
                    [["rbw", "get", "--field", "client_id", "spotify"]] if personal else [],
                )


class DependencyTests(ScriptCase):
    def test_prerequisite_install_failure_stops_public_setup(self):
        self.env.update(CHEZMOI_SOURCE_DIR=str(SCRIPTS.parents[1]), PERSONAL="0")
        self.stub("pacman", "exit 1")
        self.stub("sudo", "exit 23", log=True)
        self.stub("rbw", "exit 97", log=True)
        result = self.shell((SCRIPTS / "run_before_00-install-pre-requisites.sh").read_text())
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([call[0] for call in self.logged_calls()], ["sudo"])
        self.assertEqual(self.logged_calls()[0][1:3], ["pacman", "-S"])


class BootstrapTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.env.update(CHEZMOI_SOURCE_DIR=str(ROOT / "home"), PERSONAL="1")
        self.source = (SCRIPTS / "run_before_00-install-pre-requisites.sh").read_text()
        self.bootstrap = ROOT / "home/.chezmoitemplates/bootstrap.py"
        self.logs = self.directory / "state/chezmoi/logs"
        self.config = {"email": "fixture@example.invalid", "lock_timeout": 10800}
        self.config_file = self.directory / "config/rbw/config.json"
        self.config_file.parent.mkdir(parents=True)
        self.config_file.write_text("{}")
        self.stub("pacman", "exit 0")
        self.stub("mise", "exit 97")
        self.stub(
            "rbw",
            r"""case "$*" in
    'config show') printf '%s\n' "$RBW_CONFIG"; exit "${RBW_CONFIG_STATUS:-0}" ;;
    'config set email fixture@example.invalid'|'config set lock_timeout 10800') exit 0 ;;
    login) printf '%s\n' "${RBW_LOGIN_ERROR:-}" >&2; exit "${RBW_LOGIN_STATUS:-0}" ;;
    *) exit 97 ;;
esac""",
            log=True,
        )

    def run_prerequisite(self, *, email=None):
        self.env["RBW_CONFIG"] = json.dumps(self.config)
        if email is None:
            return self.shell(self.source)
        script = self.directory / "fixture.sh"
        script.write_text(self.source)
        master, slave = pty.openpty()
        try:
            os.write(master, (email + "\n").encode())
            return subprocess.run(
                ["/bin/bash", str(script)],
                stdin=slave,
                cwd=self.directory,
                env=self.env,
                capture_output=True,
                text=True,
                timeout=15,
            )
        finally:
            os.close(master)
            os.close(slave)

    def test_python_bootstrap_runs_nonpersonal_without_secret_access(self):
        self.env["PERSONAL"] = "0"
        result = self.run_process(
            ["/usr/bin/python3", "-B", str(self.bootstrap)], name="Python bootstrap"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.logged_calls(), [])
        self.assertFalse((self.logs / "setup.log").exists())

    def test_prerequisites_are_installed_once_and_reapplication_is_quiet(self):
        self.env.update(PERSONAL="0", INSTALLED=str(self.directory / "installed"))
        (self.bin / "mise").unlink()
        self.stub(
            "pacman",
            r"""case "$*" in
    '-Q python'|'-Q python-loguru') exit 0 ;;
    '-Q git'|'-Q base-devel'|'-Q mise') test -f "$INSTALLED" ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "sudo",
            r"""[ "$*" = 'pacman -S --needed --noconfirm -- git base-devel mise' ] || exit 97
 touch "$INSTALLED"
 printf '#!/bin/sh\nexit 97\n' > "$HOME/bin/mise"
 chmod 755 "$HOME/bin/mise"
""",
            log=True,
        )
        log_time = None
        for attempt in range(2):
            result = self.run_prerequisite()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((self.directory / "installed").exists())
            if attempt:
                self.assertEqual(result.stderr, "")
                self.assertEqual((self.logs / "setup.log").stat().st_mtime_ns, log_time)
            else:
                self.assertTrue((self.logs / "setup.log").is_file())
                log_time = (self.logs / "setup.log").stat().st_mtime_ns
        self.assertEqual(
            self.logged_calls(),
            [
                [
                    "sudo",
                    "pacman",
                    "-S",
                    "--needed",
                    "--noconfirm",
                    "--",
                    "git",
                    "base-devel",
                    "mise",
                ]
            ],
        )

    def test_personal_authentication_preserves_configuration_on_repeat(self):
        for _ in range(2):
            result = self.run_prerequisite()
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.logged_calls(), [["rbw", "config", "show"], ["rbw", "login"]] * 2)

    def test_personal_authentication_failure_keeps_status_without_exposing_output(self):
        self.env.update(RBW_LOGIN_STATUS="23", RBW_LOGIN_ERROR="secret-token-canary")
        result = self.run_prerequisite()
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertTrue((self.logs / "setup.log").is_file())
        diagnostics = result.stdout + result.stderr + (self.logs / "setup.log").read_text()
        self.assertNotIn("secret-token-canary", diagnostics)
        self.assertNotIn(self.config["email"], diagnostics)
        self.assertNotIn("\x1b[", result.stderr)
        self.assertRegex(result.stderr, r"^\d{2}:\d{2}:\d{2} \| ERROR +\|")
        self.assertIn("23", diagnostics)
        self.assertEqual(self.logged_calls(), [["rbw", "config", "show"], ["rbw", "login"]])

    def test_missing_required_command_is_recorded_without_exception_details(self):
        (self.bin / "rbw").unlink()
        result = self.run_prerequisite()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertTrue((self.logs / "setup.log").is_file())
        diagnostics = result.stderr + (self.logs / "setup.log").read_text()
        self.assertIn("OS error 2", diagnostics)
        self.assertIn("rbw", diagnostics)
        self.assertNotIn("Traceback", diagnostics)
        self.assertNotIn(self.config["email"], diagnostics)

    def test_fresh_personal_authentication_requires_email_and_supports_a_terminal(self):
        self.config_file.unlink()
        self.config = {}
        self.env.update(RBW_CONFIG_STATUS="1", NOCONFIRM="1")
        result = self.run_prerequisite()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("rbw config set email", result.stderr)
        self.calls.unlink()
        self.env.pop("NOCONFIRM")
        result = self.run_prerequisite(email="fixture@example.invalid")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.logged_calls(),
            [
                ["rbw", "config", "show"],
                ["rbw", "config", "set", "email", "fixture@example.invalid"],
                ["rbw", "config", "set", "lock_timeout", "10800"],
                ["rbw", "login"],
            ],
        )

    def test_unreadable_existing_vault_configuration_is_not_reset(self):
        self.env.update(RBW_CONFIG_STATUS="23")
        result = self.run_prerequisite()
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.logged_calls(), [["rbw", "config", "show"]])

    def test_private_logs_rotate_at_five_mib_and_keep_five_archives(self):
        code = """import runpy, sys
namespace = runpy.run_path(sys.argv[1])
namespace['configure_logging']()
for _ in range(7):
    namespace['logger'].debug('rotation-test ' + 'x' * (5 * 1024 * 1024))
namespace['logger'].remove()
"""
        result = self.run_process(
            ["/usr/bin/python3", "-B", "-c", code, str(self.bootstrap)], name="rotate private logs"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        files = list(self.logs.glob("setup*.log"))
        self.assertEqual(len(files), 6)  # Current log plus five rotated files.
        self.assertEqual(self.logs.stat().st_mode & 0o777, 0o700)
        for path in files:
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(path.stat().st_uid, os.getuid())
            self.assertIn(b"rotation-test", path.read_bytes()[:200])

    def test_terminal_logging_uses_color_only_when_allowed(self):
        code = """import runpy, sys
namespace = runpy.run_path(sys.argv[1])
namespace['configure_logging']()
namespace['logger'].warning('terminal check')
"""
        self.env["TERM"] = "linux"
        for no_color in (False, True):
            with self.subTest(no_color=no_color):
                if no_color:
                    self.env["NO_COLOR"] = ""
                else:
                    self.env.pop("NO_COLOR", None)
                master, slave = pty.openpty()
                try:
                    result = subprocess.run(
                        ["/usr/bin/python3", "-B", "-c", code, str(self.bootstrap)],
                        env=self.env,
                        stdout=subprocess.PIPE,
                        stderr=slave,
                        timeout=15,
                    )
                    self.assertEqual(result.returncode, 0)
                    output = os.read(master, 4096).decode()
                    self.assertIn("terminal check", output)
                    self.assertEqual("\x1b[" in output, not no_color)
                finally:
                    os.close(master)
                    os.close(slave)

    def test_symlinked_log_directory_is_rejected_before_bootstrap_operations(self):
        external = self.directory / "external"
        external.mkdir()
        self.logs.parent.mkdir(parents=True)
        self.logs.symlink_to(external, target_is_directory=True)
        self.stub("pacman", "exit 0", log=True)
        result = self.run_process(
            ["/usr/bin/python3", "-B", str(self.bootstrap)], name="reject unsafe logs"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.logged_calls(), [])
        self.assertEqual(list(external.iterdir()), [])


class PackageTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.packages = ROOT / "home/.chezmoitemplates/packages.py"
        self.env.update(
            NOCONFIRM="1",
            OFFLINE="1",
            PACKAGES="linux 6.18-1\nlinux-headers 6.18-1",
            GPU="Intel Corporation [8086:1234]",
            DRIVER_VERSION="615.78.08",
            MISE_STATUS="0",
            UPGRADE_STATUS="0",
        )
        self.stub("id", "echo 1000")
        self.stub("yay", "exit 97")
        self.stub("pacman-conf", "echo chaotic-aur")
        self.stub(
            "pacman",
            r"""case "$*" in
    '-Q chaotic-keyring chaotic-mirrorlist'|-Dk) exit 0 ;;
    '-T vulkan-driver') exit 127 ;;
    -Q) printf '%s\n' "$PACKAGES" ;;
    '-Q nvidia-utils') echo "nvidia-utils $DRIVER_VERSION-1" ;;
    '-Q nvidia-580xx-utils') echo "nvidia-580xx-utils $DRIVER_VERSION-1" ;;
    '-Qql linux') echo /usr/lib/modules/6.18-fixture/pkgbase ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "sudo",
            r'''[ "$*" = 'pacman -Syu --noconfirm' ] || exit 97
exit "$UPGRADE_STATUS"''',
            log=True,
        )
        self.stub("hostnamectl", "echo laptop")
        self.stub("lspci", 'printf "01:00.0 VGA compatible controller [0300]: %s\n" "$GPU"')
        self.stub("limine", "exit 97")
        self.stub("mkinitcpio", "exit 97")
        self.stub(
            "modinfo",
            r"""case "$*" in
    '-k 6.18-fixture -F vermagic nvidia') echo '6.18-fixture SMP' ;;
    '-k 6.18-fixture -F version nvidia') echo "$DRIVER_VERSION" ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "mise",
            r'''/usr/bin/python3 -B - <<'CHECK'
import json, os
from pathlib import Path
assert Path(os.environ['GNUPGHOME']).is_dir()
assert Path(os.environ['GNUPGHOME']).stat().st_mode & 0o777 == 0o700
assert not os.environ.get('MISE_ENV')
assert not os.environ.get('MISE_CONFIG_FILE')
assert os.environ['OFFLINE'] == '1' and os.environ['NOCONFIRM'] == '1'
Path(os.environ['HOME'], 'observed.json').write_text(json.dumps({
    key: os.environ.get(key) for key in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME',
                                       'GOPATH', 'CARGO_HOME', 'GNUPGHOME')}))
CHECK
[ "$?" = 0 ] || exit 98
exit "$MISE_STATUS"''',
            log=True,
        )

    def apply_packages(self, *, personal=False, distro="arch"):
        command = [
            "/usr/bin/python3",
            "-B",
            str(self.packages),
            "--root",
            str(ROOT),
            "--distro",
            distro,
        ]
        if personal:
            command.append("--personal")
        return self.run_process(command, name="package orchestration")

    def test_fresh_kvm_nonpersonal_packages_need_no_vulkan_provider_or_hardware_probe(self):
        for name in ("lspci", "hostnamectl", "rbw", "systemctl", "sbctl"):
            self.stub(name, "exit 97", log=True)
        self.env.update(MISE_ENV="personal", MISE_CONFIG_FILE="/unrelated/config.toml")
        result = self.apply_packages()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [call for call in self.logged_calls() if call[0] == "mise"],
            [["mise", "--env", "packages", "bootstrap", "packages", "apply", "--yes"]],
        )
        self.assertTrue(all(call[0] in ("sudo", "mise") for call in self.logged_calls()))
        observed = json.loads((self.directory / "observed.json").read_text())
        self.assertEqual(observed["GOPATH"], str(self.directory / "data/go"))
        declarations = tomllib.loads((ROOT / "mise/conf.d/packages.toml").read_text())["bootstrap"][
            "packages"
        ]
        # Zed requires a Vulkan driver; it must not let baseline resolution pull NVIDIA.
        self.assertEqual(declarations["pacman:zed"]["env"], "personal")

    def test_chaotic_trust_upgrade_and_mise_helper_are_ordered_and_repeatable(self):
        (self.bin / "yay").unlink()
        self.stub(
            "pacman",
            r"""case "$*" in
    '-Q chaotic-keyring chaotic-mirrorlist') test -f "$HOME/trust-installed" ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "pacman-conf", 'echo core; if test -f "$HOME/repo-enabled"; then echo chaotic-aur; fi'
        )
        self.stub(
            "sudo",
            r"""test -d "$GNUPGHOME" || exit 98
case "$*" in
    'pacman-key --list-keys 3056513887B78AEB') exit 1 ;;
    'pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com'|'pacman-key --lsign-key 3056513887B78AEB') exit 0 ;;
    'pacman -U --needed --noconfirm '*) touch "$HOME/trust-installed" ;;
    'tee -a /etc/pacman.conf') cat >> "$HOME/pacman.conf"; touch "$HOME/repo-enabled" ;;
    'pacman -Syu --noconfirm') test -f "$HOME/trust-installed" && test -f "$HOME/repo-enabled" ;;
    *) exit 97 ;;
esac""",
            log=True,
        )
        self.stub(
            "mise",
            r"""if [ "$*" = '--env aur-helper bootstrap packages apply --yes' ]; then
    printf '#!/bin/sh\nexit 97\n' > "$HOME/bin/yay"
    chmod 755 "$HOME/bin/yay"
elif [ "$*" != '--env packages bootstrap packages apply --yes' ]; then
    exit 97
fi""",
            log=True,
        )
        for _ in range(2):
            result = self.apply_packages()
            self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.logged_calls()
        self.assertEqual(
            [call[1] for call in calls[:6]],
            ["pacman-key", "pacman-key", "pacman-key", "pacman", "tee", "pacman"],
        )
        self.assertEqual(
            [call[2] for call in calls if call[0] == "mise"], ["aur-helper", "packages", "packages"]
        )
        self.assertEqual((self.directory / "pacman.conf").read_text().count("[chaotic-aur]"), 1)
        self.assertTrue((self.directory / "state/chezmoi/chaotic-aur-updated").is_file())

    def test_personal_package_groups_and_legacy_provider_order(self):
        for gpu, version, family, module in (
            (
                "NVIDIA Corporation GP106 [10de:1234]",
                "580.119.02",
                "nvidia-legacy",
                "nvidia-legacy-dkms",
            ),
            ("NVIDIA Corporation GA106 [10de:1234]", "615.78.08", "nvidia-current", "nvidia-open"),
        ):
            with self.subTest(family=family):
                self.calls.unlink(missing_ok=True)
                self.env.update(GPU=gpu, DRIVER_VERSION=version)
                result = self.apply_packages(personal=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = [call for call in self.logged_calls() if call[0] == "mise"]
                groups = calls[-1][2].split(",")
                for group in (
                    "packages",
                    "personal",
                    "driver-utils",
                    "laptop",
                    "limine-mkinitcpio",
                    "snapper",
                    family,
                    module,
                ):
                    self.assertIn(group, groups)
                if family == "nvidia-legacy":
                    self.assertEqual(calls[0][1:3], ["--env", "nvidia-legacy-utils"])

    def test_derivatives_leave_nvidia_modules_to_the_distribution(self):
        self.env["GPU"] = "NVIDIA Corporation GA106 [10de:1234]"
        for distro in ("cachyos", "garuda"):
            with self.subTest(distro=distro):
                self.calls.unlink(missing_ok=True)
                result = self.apply_packages(personal=True, distro=distro)
                self.assertEqual(result.returncode, 0, result.stderr)
                groups = [call for call in self.logged_calls() if call[0] == "mise"][-1][2].split(
                    ","
                )
                self.assertIn("nvidia-current", groups)
                self.assertNotIn("nvidia-open", groups)

    def test_conflicting_drivers_or_kernel_headers_stop_before_mise(self):
        self.env["GPU"] = "NVIDIA Corporation GA106 [10de:1234]"
        for packages in ("linux 6.18-1\nlinux-headers 6.17-1", "nvidia-580xx-utils 580.119.02-1"):
            with self.subTest(packages=packages):
                self.calls.unlink(missing_ok=True)
                self.env["PACKAGES"] = packages
                result = self.apply_packages(personal=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(call[0] == "mise" for call in self.logged_calls()))

    def test_missing_nvidia_module_fails_after_installation(self):
        self.env["GPU"] = "NVIDIA Corporation GA106 [10de:1234]"
        self.stub("modinfo", "exit 23")
        result = self.apply_packages(personal=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("6.18-fixture", result.stderr)
        self.assertTrue(any(call[0] == "mise" for call in self.logged_calls()))

    def test_xdg_reapplication_preserves_custom_paths_and_existing_maven_settings(self):
        self.env.update(
            GNUPGHOME=str(self.directory / "private-gnupg"),
            CARGO_HOME=str(self.directory / "custom-cargo"),
        )
        settings = self.directory / "config/maven/settings.xml"
        settings.parent.mkdir(parents=True)
        settings.write_text("existing-private-settings")
        before = settings.stat().st_mtime_ns
        for _ in range(2):
            result = self.apply_packages()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(settings.read_text(), "existing-private-settings")
            self.assertEqual(settings.stat().st_mtime_ns, before)
        observed = json.loads((self.directory / "observed.json").read_text())
        self.assertEqual(observed["CARGO_HOME"], self.env["CARGO_HOME"])
        self.assertEqual(observed["GNUPGHOME"], self.env["GNUPGHOME"])
        self.assertEqual(
            sum(call == ["sudo", "pacman", "-Syu", "--noconfirm"] for call in self.logged_calls()),
            1,
        )
        self.assertNotIn("existing-private-settings", result.stderr)

    def test_failed_initial_upgrade_does_not_record_success_or_run_mise(self):
        self.env["UPGRADE_STATUS"] = "23"
        result = self.apply_packages()
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertFalse((self.directory / "state/chezmoi/chaotic-aur-updated").exists())
        self.assertFalse(any(call[0] == "mise" for call in self.logged_calls()))

    def test_chezmoi_retries_failures_and_tracks_only_package_dependencies(self):
        repository = self.directory / "source"
        templates = repository / "home/.chezmoitemplates"
        scripts = repository / "home/.chezmoiscripts/linux"
        templates.mkdir(parents=True)
        scripts.mkdir(parents=True)
        shutil.copytree(ROOT / "mise", repository / "mise")
        for name in ("bootstrap.py", "packages.py"):
            shutil.copy(ROOT / "home/.chezmoitemplates" / name, templates / name)
        launcher = "run_onchange_before_02_packages.sh.tmpl"
        shutil.copy(SCRIPTS / launcher, scripts / launcher)
        config = self.directory / "chezmoi.json"
        config.write_text(json.dumps({"data": {"personal": False, "distroFamily": "arch"}}))
        command = [
            CHEZMOI,
            "--config",
            str(config),
            "--source",
            str(repository / "home"),
            "--working-tree",
            str(repository),
            "--destination",
            str(self.directory / "target"),
            "--no-tty",
            "apply",
        ]
        self.env["MISE_STATUS"] = "23"
        failed = self.run_process(command, name="failed package apply")
        self.assertNotEqual(failed.returncode, 0)
        self.env["MISE_STATUS"] = "0"
        for target, expected in (
            (None, 2),
            (None, 2),
            (repository / "mise/conf.d/services.toml", 2),
            (repository / "mise/conf.d/packages.toml", 3),
            (templates / "bootstrap.py", 3),
            (templates / "packages.py", 4),
        ):
            with self.subTest(target=target, expected=expected):
                if target:
                    with target.open("a") as stream:
                        stream.write("\n# changed\n")
                result = self.run_process(command, name="package change detection")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(sum(call[0] == "mise" for call in self.logged_calls()), expected)
