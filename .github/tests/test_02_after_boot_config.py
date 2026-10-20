"""Boot-option writes must preserve a usable config and a pending rebuild."""

from helpers import SCRIPTS, ScriptCase


class BootConfigTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.boot = self.directory / "esp"
        self.boot.mkdir()
        self.config = self.boot / "limine.conf"
        self.original = "timeout: 5\n/Arch\nprotocol: linux\n"
        self.config.write_text(self.original)
        self.marker = self.directory / "state/chezmoi/initramfs.pending"
        self.env["BOOT"] = str(self.boot)
        self.stub("limine-entry-tool", "exit 97")
        self.stub("sudo", r'''case "$1" in
    test|cmp|grep|awk|install|chmod|mv|rm) ;;
    tee) printf 'stage-write\t\n' >> "$CALLS"; exit 23 ;;
    *) exit 97 ;;
esac
for arg do
    case "$arg" in /*) case "$arg" in "$HOME"/*|/dev/null) ;; *) exit 97 ;; esac ;; esac
done
exec "$@"''')

    def configure(self):
        return self.shell(self.libraries("common.sh", "snapboot.sh") + r'''
get_limine_boot_directory() { echo "$BOOT"; }
LIMINE_OPTIONS=(timeout=0.5)
''' + self.function(SCRIPTS / "run_onchange_after_08_theming.sh.tmpl",
                    "configure_limine_options") + "\nconfigure_limine_options\n")

    def test_failed_staging_preserves_boot_config_and_rebuild_request(self):
        result = self.configure()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.config.read_text(), self.original)
        self.assertTrue(self.marker.exists())
        self.assertIn(["stage-write"], self.logged_calls())
        self.assertFalse((self.boot / "limine.conf.new").exists())

    def test_ambiguous_active_config_is_not_overwritten(self):
        alternate = self.boot / "EFI/BOOT/limine.conf"
        alternate.parent.mkdir(parents=True)
        alternate.write_text("recovery config\n")
        result = self.configure()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.config.read_text(), self.original)
        self.assertEqual(alternate.read_text(), "recovery config\n")
        self.assertFalse(self.marker.exists())
