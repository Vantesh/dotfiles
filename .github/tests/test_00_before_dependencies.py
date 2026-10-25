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
            (ROOT / "home/.chezmoi.yaml.tmpl").read_text())
        self.config = self.directory / "chezmoi.yaml"
        self.stub("git", 'exec /usr/bin/git "$@"')
        self.command = [CHEZMOI, "--config", str(self.config), "--source", str(self.source),
                        "--destination", str(self.directory / "destination"), "--no-tty"]

    def test_fresh_profiles_persist_only_the_personal_choice(self):
        for personal in (False, True):
            with self.subTest(personal=personal):
                self.config.unlink(missing_ok=True)
                command = self.command + ["--override-data",
                    '{"chezmoi":{"osRelease":{"id":"arch"}}}']
                result = self.run_process(command + ["init", "--promptBool",
                    f"Is this a personal setup={str(personal).lower()}"], name="initialize profile")
                self.assertEqual(result.returncode, 0, result.stderr)
                result = self.run_process(command + ["dump-config", "--format=json"], name="read profile")
                config = json.loads(result.stdout)
                self.assertEqual(config["data"], {"personal": personal, "distroFamily": "arch"})
                self.assertEqual(config["scriptEnv"], {
                    "PERSONAL": "1" if personal else "0", "DISTRO": "arch", "DISTRO_FAMILY": "arch"})
                # Reinitializing this architecture preserves the selected profile.
                self.env["NOCONFIRM"] = "1"
                result = self.run_process(command + ["init"], name="repeat initialization")
                self.assertEqual(result.returncode, 0, result.stderr)
                repeated = self.run_process(command + ["dump-config", "--format=json"], name="read repeated profile")
                self.assertEqual(json.loads(repeated.stdout)["data"], config["data"])
                self.env.pop("NOCONFIRM")

    def test_arch_family_is_accepted_and_non_arch_is_rejected(self):
        for release, accepted in (({"id": "arch", "idLike": ""}, True),
                                  ({"id": "cachyos", "idLike": "arch"}, True),
                                  ({"id": "debian", "idLike": ""}, False)):
            with self.subTest(release=release):
                self.config.unlink(missing_ok=True)
                template = (ROOT / "home/.chezmoi.yaml.tmpl").read_text()
                # init supplies native OS metadata; substitute just that input.
                (self.source / ".chezmoi.yaml.tmpl").write_text(
                    '{{- $_ := set .chezmoi "osRelease" (fromJson '
                    + json.dumps(json.dumps(release)) + ') -}}\n' + template)
                result = self.run_process(self.command + ["init", "--promptDefaults"],
                                          name="initialize distribution")
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
        self.stub("id", 'echo 1000')
        self.stub("figlet", "exit 0")
        self.stub("yay", "exit 97")
        self.stub("pacman", '[ "$1" = -Q ] || [ "$1" = -T ] || exit 97')
        self.stub("pacman-conf", '[ "$*" = --repo-list ] || exit 97; echo chaotic-aur')
        self.stub("sudo", r'''case "$*" in
    -v|'-n true'|'pacman -Syu --noconfirm') exit 0 ;;
    *) echo "Unexpected provisioning: $*" >&2; exit 97 ;;
esac''', log=True)
        self.stub("mise", '[ "$*" = "--env packages bootstrap packages apply --yes" ] || exit 97', log=True)
        for name in ("rbw", "lspci", "hostnamectl", "systemctl", "gsettings", "sbctl", "findmnt", "busctl"):
            self.stub(name, 'echo "Unexpected personal operation" >&2; exit 97', log=True)
        command = [CHEZMOI, "--config", str(self.config), "--source", str(ROOT),
                   "--working-tree", str(ROOT), "--destination", str(self.directory), "--no-tty",
                   "--override-data", '{"chezmoi":{"osRelease":{"id":"arch"}}}']
        result = self.run_process(command + ["init", "--data=false"], name="initialize nonpersonal")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        before = None
        for attempt in range(2):
            result = self.run_process(command + ["apply"], name="apply nonpersonal")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((self.directory / ".config/fish/config.fish").is_file())
            self.assertFalse((self.directory / ".ssh/id_rsa").exists())
            self.assertFalse((self.directory / ".config/git/identity").exists())
            self.assertNotIn("CHEZMOI_GITHUB_ACCESS_TOKEN", (self.directory / ".config/fish/conf.d/secrets.fish").read_text()
                             if (self.directory / ".config/fish/conf.d/secrets.fish").exists() else "")
            result = self.run_process(command + ["verify", "--exclude=scripts"], name="verify nonpersonal files")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            current = {str(path.relative_to(self.directory)): (path.read_bytes(), path.stat().st_mtime_ns)
                       for path in (self.directory / ".config").rglob("*")
                       if path.is_file() and not path.is_symlink()}
            if attempt:
                self.assertEqual(current, before)
            before = current
        calls = self.logged_calls()
        self.assertEqual([call for call in calls if call[0] == "mise"],
                         [["mise", "--env", "packages", "bootstrap", "packages", "apply", "--yes"]])
        self.assertFalse(any(call[0] not in ("sudo", "mise") for call in calls), calls)

    def test_personal_secret_settings_are_applied_once_and_excluded_from_nonpersonal(self):
        self.stub("rbw", '[ "$*" = "get --field client_id spotify" ] || exit 97; echo fixture-client-id', log=True)
        for personal in (False, True):
            with self.subTest(personal=personal):
                self.calls.unlink(missing_ok=True)
                script = self.directory / "spotifast.py"
                script.write_text(self.render(ROOT / "home/dot_config/spotifast/modify_settings.json.tmpl",
                                              personal=personal))
                command = [shutil.which("python3"), str(script)]
                result = self.run_process(command, input="{}", name="apply secret settings")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout).get("web_client_id"),
                                 "fixture-client-id" if personal else None)
                repeated = self.run_process(command, input=result.stdout, name="reapply secret settings")
                self.assertEqual(repeated.returncode, 0, repeated.stderr)
                self.assertEqual(repeated.stdout, result.stdout)
                self.assertEqual(self.logged_calls(),
                                 [["rbw", "get", "--field", "client_id", "spotify"]] if personal else [])


class DependencyTests(ScriptCase):
    def test_prerequisite_install_failure_stops_public_setup(self):
        self.env.update(CHEZMOI_SOURCE_DIR=str(SCRIPTS.parents[1]), PERSONAL="0")
        self.stub("pacman", "exit 1")
        self.stub("sudo", "exit 23", log=True)
        self.stub("rbw", "exit 97", log=True)
        result = self.shell(
            (SCRIPTS / "run_before_00-install-pre-requisites.sh").read_text()
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([call[0] for call in self.logged_calls()], ["sudo"])
        self.assertEqual(self.logged_calls()[0][1:3], ["pacman", "-S"])

    def test_package_installer_failure_is_not_reported_as_success(self):
        source = self.render(SCRIPTS / "run_onchange_before_02_packages.sh.tmpl", personal=False)
        # Bypass completed prerequisites, not the installer or its failure handling.
        source = source.replace(
            'if [[ "$(id -u)" -eq 0 ]]; then',
            """
keep_sudo_alive() { return 0; }
setup_xdg() { return 0; }
setup_chaotic_aur() { return 0; }
install_aur_helper() { return 0; }
is_laptop() { return 1; }
if [[ "$(id -u)" -eq 0 ]]; then""",
        )
        self.stub("id", "echo 1000")
        self.stub("figlet", "exit 0")
        self.stub("pacman", '[ "$1" = -T ] || exit 97')
        self.stub("mise", "exit 23", log=True)
        result = self.shell(source)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.logged_calls()), 1)
        self.assertEqual(self.logged_calls()[0][0], "mise")


class RbwPrerequisiteTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.env.update(CHEZMOI_SOURCE_DIR=str(SCRIPTS.parents[1]), PERSONAL="1")
        self.source = (SCRIPTS / "run_before_00-install-pre-requisites.sh").read_text()
        self.config = {
            "email": "fixture@example.invalid", "sso_id": None, "base_url": None,
            "identity_url": None, "ui_url": None, "notifications_url": None,
            "lock_timeout": 10800, "sync_interval": 3600,
            "pinentry": "pinentry", "client_cert_path": None,
        }
        config_file = self.directory / "config/rbw/config.json"
        config_file.parent.mkdir(parents=True)
        config_file.write_text("{}")
        self.stub("pacman", "exit 0")
        self.stub("mise", "exit 97")
        self.stub("figlet", "exit 0")
        self.stub("rbw", '''
case "$*" in
  "config show")
    printf '%s\\n' "$RBW_CONFIG"
    printf '%s\\n' "${RBW_CONFIG_ERROR:-}" >&2
    exit "${RBW_CONFIG_STATUS:-0}" ;;
  "config set email fixture@example.invalid"|"config set lock_timeout 10800") exit 0 ;;
  login)
    printf '%s\\n' "${RBW_LOGIN_ERROR:-}" >&2
    exit "${RBW_LOGIN_STATUS:-0}" ;;
  *) exit 97 ;;
esac
''', log=True)

    def run_prerequisite(self, *, email=None):
        self.env["RBW_CONFIG"] = json.dumps(self.config, indent=2)
        if email is None:
            return self.shell(self.source)
        script = self.directory / "fixture.sh"
        script.write_text(self.source)
        master, slave = pty.openpty()
        try:
            os.write(master, (email + "\n").encode())
            return subprocess.run(
                ["/bin/bash", str(script)], stdin=slave, cwd=self.directory,
                env=self.env, capture_output=True, text=True, timeout=15,
            )
        finally:
            os.close(master)
            os.close(slave)

    def test_matching_configuration_preserves_unlocked_agent(self):
        result = self.run_prerequisite()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.logged_calls(), [["rbw", "config", "show"], ["rbw", "login"]])

    def test_only_changed_timeout_is_set_before_login(self):
        self.config["lock_timeout"] = 3600
        result = self.run_prerequisite()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.logged_calls(), [
            ["rbw", "config", "show"], ["rbw", "config", "set", "lock_timeout", "10800"],
            ["rbw", "login"],
        ])

    def test_login_error_keeps_original_diagnostic_and_status_without_reconfiguration(self):
        self.env.update(RBW_LOGIN_STATUS="23", RBW_LOGIN_ERROR="fixture pinentry failed")
        result = self.run_prerequisite()
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertIn("fixture pinentry failed", result.stderr)
        self.assertNotIn("Enter your Bitwarden email", result.stderr)
        self.assertEqual(self.logged_calls(), [["rbw", "config", "show"], ["rbw", "login"]])

    def test_configuration_read_failure_never_reconfigures_or_logs_in(self):
        self.env.update(RBW_CONFIG_STATUS="23", RBW_CONFIG_ERROR="fixture unreadable config")
        for profile in ("", "work"):
            with self.subTest(profile=profile):
                self.calls.unlink(missing_ok=True)
                self.env["RBW_PROFILE"] = profile
                if profile:
                    (self.directory / "config/rbw/config.json").unlink()
                    config_file = self.directory / "config/rbw-work/config.json"
                    config_file.parent.mkdir()
                    config_file.write_text("{invalid")
                result = self.run_prerequisite(email="fixture@example.invalid")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.logged_calls(), [["rbw", "config", "show"]])

    def test_missing_email_is_configured_before_first_login(self):
        for missing in (None, ""):
            with self.subTest(email=missing):
                self.calls.unlink(missing_ok=True)
                self.config["email"] = missing
                result = self.run_prerequisite(email="fixture@example.invalid")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.logged_calls(), [
                    ["rbw", "config", "show"],
                    ["rbw", "config", "set", "email", "fixture@example.invalid"],
                    ["rbw", "login"],
                ])

    def test_absent_configuration_preserves_interactive_first_time_setup(self):
        (self.directory / "config/rbw/config.json").unlink()
        self.env.update(RBW_CONFIG_STATUS="1", RBW_CONFIG_ERROR="fixture no such file")
        for profile in (None, "", "work"):
            with self.subTest(profile=profile):
                self.calls.unlink(missing_ok=True)
                if profile is not None:
                    self.env["RBW_PROFILE"] = profile
                result = self.run_prerequisite(email="fixture@example.invalid")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.logged_calls(), [
                    ["rbw", "config", "show"],
                    ["rbw", "config", "set", "email", "fixture@example.invalid"],
                    ["rbw", "config", "set", "lock_timeout", "10800"], ["rbw", "login"],
                ])

    def test_missing_email_without_interaction_fails_with_configuration_instruction(self):
        self.config["email"] = None
        for controls in ({"NOCONFIRM": "1"}, {"CI": "1"}, {}):
            with self.subTest(controls=controls):
                self.calls.unlink(missing_ok=True)
                self.env.pop("NOCONFIRM", None)
                self.env.pop("CI", None)
                self.env.update(controls)
                result = self.run_prerequisite()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("rbw config set email", result.stderr)
                self.assertNotIn("Enter your Bitwarden email", result.stderr)
                self.assertEqual(self.logged_calls(), [["rbw", "config", "show"]])

    def test_public_setup_does_not_touch_bitwarden(self):
        self.env["PERSONAL"] = "0"
        result = self.run_prerequisite()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.logged_calls(), [])


class NvidiaPackageTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.source = self.render(SCRIPTS / "run_onchange_before_02_packages.sh.tmpl")
        self.source = self.source.replace(
            'if [[ "$(id -u)" -eq 0 ]]; then',
            """
keep_sudo_alive() { return 0; }
setup_xdg() { return 0; }
setup_chaotic_aur() { return 0; }
install_aur_helper() { return 0; }
is_laptop() { return 1; }

if [[ "$(id -u)" -eq 0 ]]; then""",
        )
        self.env.update(
            DISTRO="arch",
            MODULE_FAILURE="", FAILURE_RELEASE="6.12-fixture",
        )
        self.stub("id", "echo 1000")
        self.stub("figlet", "exit 0")
        self.stub(
            "lspci",
            'printf "01:00.0 VGA compatible controller [0300]: NVIDIA Corporation %s [10de:1234]\\n" "$GPU"',
        )
        self.stub(
            "pacman",
            """case "$*" in
    -Q) printf '%s\\n' "$PACKAGES" ;;
    '-Q nvidia-utils'|'-Q nvidia-580xx-utils')
        printf '%s\\n' "$PACKAGES" | awk -v name="$2" '$1 == name { print; found=1 } END { exit !found }' ;;
    '-Qql linux') echo /usr/lib/modules/6.18-fixture/pkgbase ;;
    '-Qql linux-lts') echo /usr/lib/modules/6.12-fixture/pkgbase ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "modinfo",
            """[ "$#" = 5 ] && [ "$1" = -k ] && [ "$3" = -F ] && [ "$5" = nvidia ] || exit 97
if [ "$2" = "$FAILURE_RELEASE" ] && [ "$MODULE_FAILURE" = missing ]; then exit 1; fi
case "$4" in
    vermagic)
        if [ "$2" = "$FAILURE_RELEASE" ] && [ "$MODULE_FAILURE" = wrong-abi ]; then
            echo 'wrong-release SMP'
        else
            printf '%s SMP\\n' "$2"
        fi ;;
    version)
        if [ "$2" = "$FAILURE_RELEASE" ] && [ "$MODULE_FAILURE" = stale ]; then
            echo 580.119.02
        else
            echo 615.78.08
        fi ;;
    *) exit 97 ;;
esac""",
        )
        self.stub("mise", "exit 0", log=True)

    def test_matching_partial_stacks_keep_the_selected_packages_and_installed_module(
        self,
    ):
        for gpu, packages, family, module_group in (
            (
                "GP106",
                "nvidia-580xx-utils 580.119.02-1",
                "nvidia-legacy",
                "nvidia-legacy-dkms",
            ),
            ("GA106", "nvidia-utils 590.48.01-1", "nvidia-current", "nvidia-open"),
            (
                "GA106",
                "nvidia-utils 590.48.01-1\nnvidia-open 590.48.01-1",
                "nvidia-current",
                None,
            ),
        ):
            with self.subTest(gpu=gpu, packages=packages):
                self.env.update(GPU=gpu, PACKAGES=packages)
                self.calls.unlink(missing_ok=True)
                result = self.shell(self.source)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = self.logged_calls()
                groups = calls[-1][2].split(",")
                self.assertIn("personal", groups)
                self.assertIn(family, groups)
                if module_group:
                    self.assertIn(module_group, groups)
                else:
                    self.assertNotIn("nvidia-open", groups)
                if family == "nvidia-legacy":
                    self.assertEqual(calls[0][1:3], ["--env", "nvidia-legacy-utils"])

    def test_conflicting_standard_stacks_stop_before_nvidia_installation(self):
        for gpu, package in (
            ("GP106", "nvidia-utils"),
            ("GA106", "nvidia-580xx-utils"),
            ("GP106", "lib32-nvidia-utils"),
            ("GP106", "nvidia-open-dkms"),
        ):
            with self.subTest(gpu=gpu, package=package):
                self.env.update(GPU=gpu, PACKAGES=f"{package} 580.119.02-1")
                self.calls.unlink(missing_ok=True)
                result = self.shell(self.source)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(package, result.stderr)
                self.assertEqual(self.logged_calls(), [])

    def test_fixed_modules_cover_every_installed_kernel_before_skipping_selection(self):
        kernels = (
            "linux 6.18-1\nlinux-headers 6.18-1\n"
            "linux-lts 6.12-1\nlinux-lts-headers 6.12-1\n"
            "nvidia-utils 615.78.08-1\n"
        )
        declarations = tomllib.loads(
            (ROOT / "mise/conf.d/packages.toml").read_text()
        )["bootstrap"]["packages"]
        for modules, expected_group, expected_package in (
            ("nvidia-open-lts 615.78.08-1", "nvidia-open-linux", "pacman:nvidia-open"),
            ("nvidia-open 615.78.08-1", "nvidia-open-lts", "pacman:nvidia-open-lts"),
            ("nvidia-open 615.78.08-1\nnvidia-open-lts 615.78.08-1", None, None),
            ("nvidia-open-dkms 615.78.08-1", None, None),
        ):
            with self.subTest(modules=modules):
                self.env.update(GPU="GA106", PACKAGES=kernels + modules)
                self.calls.unlink(missing_ok=True)
                result = self.shell(self.source)
                self.assertEqual(result.returncode, 0, result.stderr)
                groups = self.logged_calls()[-1][2].split(",")
                self.assertIn("nvidia-current", groups)
                self.assertEqual(
                    {group for group in groups if group.startswith("nvidia-open")},
                    {expected_group} if expected_group else set(),
                )
                if expected_package:
                    self.assertEqual(declarations[expected_package]["env"], expected_group)

    def test_uncovered_kernels_do_not_replace_installed_fixed_modules_with_dkms(self):
        for kernel in ("linux-zen", "linux-hardened"):
            with self.subTest(kernel=kernel):
                self.env.update(
                    GPU="GA106",
                    PACKAGES=(
                        "linux 6.18-1\nlinux-headers 6.18-1\n"
                        f"{kernel} 6.18-1\n{kernel}-headers 6.18-1\n"
                        "nvidia-utils 615.78.08-1\nnvidia-open 615.78.08-1"
                    ),
                )
                self.calls.unlink(missing_ok=True)
                result = self.shell(self.source)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(kernel, result.stderr)
                self.assertEqual(self.logged_calls(), [])

    def test_dkms_package_presence_does_not_hide_missing_or_mismatched_kernel_modules(self):
        kernels = (
            "linux 6.18-1\nlinux-headers 6.18-1\n"
            "linux-lts 6.12-1\nlinux-lts-headers 6.12-1\n"
            "nvidia-utils 615.78.08-1\n"
        )
        for failure, release, dkms_package in (
            ("missing", "6.12-fixture", "nvidia-open-dkms 615.78.08-1"),
            ("missing", "6.18-fixture", "nvidia-open-dkms 615.78.08-1"),
            ("wrong-abi", "6.12-fixture", "nvidia-open-dkms 615.78.08-1"),
            ("stale", "6.12-fixture", "nvidia-open-dkms 615.78.08-1"),
            ("missing", "6.12-fixture", ""),
            ("", "6.12-fixture", "nvidia-open-dkms 615.78.08-1"),
        ):
            with self.subTest(failure=failure, release=release, installed=bool(dkms_package)):
                self.env.update(
                    GPU="GA106", PACKAGES=kernels + dkms_package,
                    MODULE_FAILURE=failure, FAILURE_RELEASE=release,
                )
                self.calls.unlink(missing_ok=True)
                result = self.shell(self.source)
                self.assertEqual(result.returncode, 1 if failure else 0, result.stderr)
                if failure:
                    self.assertIn(release, result.stderr)
