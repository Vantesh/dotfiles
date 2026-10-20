"""Shared rollback safety and the hibernation workflow that edits fstab."""

from helpers import LIB, SCRIPTS, ScriptCase


class ConfigRollbackTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.original = self.directory / "config"
        self.original.write_text("original\n")
        self.original.chmod(0o640)
        self.env.update(ORIGINAL=str(self.original), NEW=str(self.directory / "new"))
        self.stub("sudo", r'''case "$1" in
    test|stat|cmp|cp|cat|mktemp|mv|chmod|rm) ;;
    *) exit 97 ;;
esac
for arg do
    case "$arg" in /*) case "$arg" in "$HOME"/*) ;; *) exit 97 ;; esac ;; esac
done
exec "$@"''')

    def transaction(self, verify):
        return self.shell(self.libraries("common.sh") + r'''
edit() { printf 'updated\n' > "$1"; printf 'new\n' > "$2"; }
verify() { ''' + verify + r'''; }
edit_system_configs edit verify "$ORIGINAL" "$NEW"
''')

    def test_failed_or_interrupted_postcheck_rolls_back_only_its_own_files(self):
        for verify, status in (("return 1", 1), ('kill -TERM "$BASHPID"', 143)):
            with self.subTest(verify=verify):
                result = self.transaction(verify)
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(self.original.read_text(), "original\n")
                self.assertEqual(self.original.stat().st_mode & 0o777, 0o640)
                self.assertFalse((self.directory / "new").exists())

    def test_rollback_preserves_configuration_changed_by_another_actor(self):
        result = self.transaction('printf "user edit\\n" > "$ORIGINAL"; return 1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.original.read_text(), "user edit\n")
        self.assertFalse((self.directory / "new").exists())


class HibernationTests(ScriptCase):
    def test_unsafe_filesystem_or_fstab_stops_before_swap_changes(self):
        fstab = self.directory / "fstab"
        fstab.write_text("# existing fstab\n")
        swap = self.directory / "swap"
        source = (LIB / "hibernation.sh").read_text().replace(
            "/etc/fstab", str(fstab)
        ).replace('"/swap"', f'"{swap}"').replace('"/swap/swapfile"', f'"{swap}/swapfile"')
        self.stub("lsblk", "echo root-uuid")
        # Listing is safe; any attempted mutation must fail the test.
        self.stub("sudo", '[ "$*" = "btrfs subvolume list /" ] || exit 97', log=True)
        for failure in ("identity", "fstab"):
            with self.subTest(failure=failure):
                self.calls.unlink(missing_ok=True)
                self.env.update(FAILURE=failure, SWAP=str(swap))
                self.stub("findmnt", r'''case "$*" in
    '-rn -o FSTYPE,UUID --mountpoint /')
        if [ "$FAILURE" = identity ]; then echo 'btrfs wrong-uuid'; else echo 'btrfs root-uuid'; fi ;;
    '--fstab --tab-file '*) printf 'UUID=other %s btrfs subvol=@swap\n' "$SWAP" ;;
    *) exit 97 ;;
esac''')
                result = self.shell(self.libraries("common.sh") + source + '''
get_btrfs_root_device() { echo /dev/fixture; }
create_btrfs_swap
''')
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(fstab.read_text(), "# existing fstab\n")
                self.assertFalse(swap.exists())
                self.assertEqual(self.logged_calls(), [] if failure == "identity" else
                                 [["sudo", "btrfs", "subvolume", "list", "/"]])

    def test_resume_uses_swap_filesystem_and_stops_before_writes_on_lookup_failure(self):
        swapfile = self.directory / "swapfile"
        swapfile.touch()
        self.env["SWAPFILE"] = str(swapfile)
        self.stub("update-limine", "exit 0", log=True)
        script = self.libraries("common.sh", "hibernation.sh") + r'''
get_swap_path() { echo "$SWAPFILE"; }
ensure_limine_cmdline_defaults() { printf 'defaults\t\n' >> "$CALLS"; }
update_limine_cmdline() { update-limine "$@"; }
write_mkinitcpio_dropin() { printf 'dropin\t\n' >> "$CALLS"; }
setup_hibernation
'''
        for failure in ("", "uuid", "offset"):
            with self.subTest(failure=failure):
                self.calls.unlink(missing_ok=True)
                self.stub("findmnt", "exit 23" if failure == "uuid" else "echo swap-uuid", log=True)
                self.stub("sudo", "exit 23" if failure == "offset" else "echo 123", log=True)
                result = self.shell(script)
                calls = self.logged_calls()
                self.assertEqual(calls[0], ["findmnt", "-n", "-o", "UUID", "--target", str(swapfile)])
                if failure:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(any(call[0] in ("defaults", "update-limine", "dropin") for call in calls))
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(["update-limine", "50-hibernation.conf", "--append",
                                   "hibernate.compressor=lz4", "resume=UUID=swap-uuid", "resume_offset=123"], calls)

    def test_consecutive_deferrals_keep_changing_the_onchange_retry_state(self):
        path = SCRIPTS / "run_onchange_after_03_hibernation.sh.tmpl"
        self.stub("limine", "exit 97")
        rendered = []
        for _ in range(3):
            source = self.render(path)
            rendered.append(source)
            source = source.replace("/usr/bin/limine", str(self.bin / "limine"))
            source = source.replace('\nmain "$@"', '''
check_btrfs() { return 0; }
is_laptop() { return 0; }
command_exists() { return 1; }
main "$@"''')
            result = self.shell(source)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(set(rendered)), 3)
        self.assertEqual((self.directory / "state/chezmoi/hibernation.pending").stat().st_size, 3)
