"""Before hooks must stop when essential package installation fails."""

from helpers import SCRIPTS, ScriptCase


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
        source = self.render(SCRIPTS / "run_onchange_before_02_packages.sh.tmpl")
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
        self.env.update(INSTALL_DRIVERS="0", SETUP_SNAPPER="0")
        self.stub("id", "echo 1000")
        self.stub("figlet", "exit 0")
        self.stub("pacman", '[ "$1" = -T ] || exit 97')
        self.stub("mise", "exit 23", log=True)
        result = self.shell(source)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.logged_calls()), 1)
        self.assertEqual(self.logged_calls()[0][0], "mise")


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
        self.env.update(INSTALL_DRIVERS="1", SETUP_SNAPPER="0", DISTRO="arch")
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
