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
if [ "$1" = rm ] && [ "${FAIL_REMOVE:-0}" = 1 ]; then exit 23; fi
exec "$@"''', log=True)

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

    def alternate_configs(self):
        paths = (
            "EFI/BOOT/limine.conf", "EFI/limine/limine.conf", "EFI/limine.conf",
            "boot/limine/limine.conf", "boot/limine.conf", "limine/limine.conf",
            "EFI/BOOT/BOOTX64.EFI", "EFI/limine/limine_x64.efi",
            "EFI/other/limine.conf",
        )
        for name in paths:
            path = self.boot / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("preserve " + name + "\n")
        return {name: (self.boot / name).read_text() for name in paths}

    def validate_location(self):
        return self.shell(self.libraries("snapboot.sh") + r'''
LAST_ERROR="stale error"
validate_limine_config_location "$BOOT"
status=$?
printf '%s\n' "$LAST_ERROR" >&2
exit "$status"
''')

    def test_public_alternates_are_preserved_without_blocking(self):
        originals = self.alternate_configs()
        for personal in (None, "0", "true"):
            with self.subTest(personal=personal):
                if personal is None:
                    self.env.pop("PERSONAL", None)
                else:
                    self.env["PERSONAL"] = personal
                result = self.validate_location()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr.strip(), "")
                self.assertEqual(self.config.read_text(), self.original)
                for name, content in originals.items():
                    self.assertEqual((self.boot / name).read_text(), content)
        self.assertFalse(any(call[:2] == ["sudo", "rm"]
                             for call in self.logged_calls()))

    def test_public_alternate_does_not_block_staging(self):
        originals = self.alternate_configs()
        self.env["PERSONAL"] = "0"
        result = self.configure()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.config.read_text(), self.original)
        for name, content in originals.items():
            self.assertEqual((self.boot / name).read_text(), content)
        self.assertTrue(self.marker.exists())
        self.assertIn(["stage-write"], self.logged_calls())
        self.assertFalse((self.boot / "limine.conf.new").exists())

    def test_personal_removes_only_explicit_legacy_configs(self):
        originals = self.alternate_configs()
        self.env["PERSONAL"] = "1"
        result = self.validate_location()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr.strip(), "")
        self.assertEqual(self.config.read_text(), self.original)
        legacy = {"EFI/BOOT/limine.conf", "EFI/limine/limine.conf", "EFI/limine.conf"}
        for name, content in originals.items():
            if name in legacy:
                self.assertFalse((self.boot / name).exists())
            else:
                self.assertEqual((self.boot / name).read_text(), content)
        removals = [call for call in self.logged_calls() if call[:2] == ["sudo", "rm"]]
        self.assertEqual(len(removals), 3)
        for call in removals:
            self.assertEqual(call[2:4], ["-f", "--"])
            self.assertEqual(len(call), 5)
            self.assertIn(call[4], {str(self.boot / name) for name in legacy})
        result = self.validate_location()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_personal_cleanup_failure_blocks_staging_and_reports_path(self):
        originals = self.alternate_configs()
        self.env.update(PERSONAL="1", FAIL_REMOVE="1")
        result = self.shell(self.libraries("snapboot.sh") + r'''
validate_limine_config_location "$BOOT"
status=$?
printf '%s\n' "$LAST_ERROR" >&2
exit "$status"
''')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Failed", result.stderr)
        self.assertIn(str(self.boot / "EFI/"), result.stderr)
        result = self.configure()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse(self.marker.exists())
        self.assertNotIn(["stage-write"], self.logged_calls())
        self.assertEqual(self.config.read_text(), self.original)
        for name, content in originals.items():
            self.assertEqual((self.boot / name).read_text(), content)

    def test_personal_cleanup_does_not_recursively_remove_directories(self):
        legacy = self.boot / "EFI/BOOT/limine.conf"
        legacy.mkdir(parents=True)
        recovery = legacy / "recovery.conf"
        recovery.write_text("recovery config\n")
        self.env["PERSONAL"] = "1"
        result = self.validate_location()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(str(legacy), result.stderr)
        self.assertEqual(recovery.read_text(), "recovery config\n")
        self.assertEqual(self.config.read_text(), self.original)
