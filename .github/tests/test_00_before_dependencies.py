"""Before hooks must stop when essential package installation fails."""

from helpers import SCRIPTS, ScriptCase


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

    def test_package_installer_failure_is_not_reported_as_success(self):
        source = self.render(SCRIPTS / "run_onchange_before_02_packages.sh.tmpl")
        # Bypass completed prerequisites, not the installer or its failure handling.
        source = source.replace('if [[ "$(id -u)" -eq 0 ]]; then', '''
keep_sudo_alive() { return 0; }
setup_xdg() { return 0; }
setup_chaotic_aur() { return 0; }
install_aur_helper() { return 0; }
is_laptop() { return 1; }
if [[ "$(id -u)" -eq 0 ]]; then''')
        self.env.update(INSTALL_DRIVERS="0", SETUP_SNAPPER="0")
        self.stub("id", "echo 1000")
        self.stub("figlet", "exit 0")
        self.stub("pacman", '[ "$1" = -T ] || exit 97')
        self.stub("mise", "exit 23", log=True)
        result = self.shell(source)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.logged_calls()), 1)
        self.assertEqual(self.logged_calls()[0][0], "mise")
