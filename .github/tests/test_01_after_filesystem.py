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

    def resume_fixture(self, *, encrypted=False, failure=""):
        swap = self.directory / "swap"
        swap.mkdir(exist_ok=True)
        (swap / "swapfile").touch()
        self.env.update(SWAP=str(swap), ENCRYPTED="1" if encrypted else "0",
                        FAILURE=failure)
        self.stub("findmnt", r'''case "$*" in
    '-rn -o SOURCE,FSTYPE,UUID --target '*)
        [ "$FAILURE" != identity ] || exit 23
        echo '/dev/fixture[/@swap] btrfs aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' ;;
    *) exit 97 ;;
esac''')
        self.stub("readlink", r'''case "$*" in
    *'/dev/disk/by-uuid/'*) [ "$FAILURE" != uuid ] || { echo /dev/container; exit; }; echo /dev/fixture ;;
    *'/dev/container'*) echo /dev/container ;;
    *'/dev/fixture'*) echo /dev/fixture ;;
    *) exec /usr/bin/readlink "$@" ;;
esac''')
        self.stub("lsblk", r'''case "$*" in
    '-dnro FSTYPE,UUID /dev/fixture') echo 'btrfs aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' ;;
    '-srn -o TYPE /dev/fixture')
        if [ "$ENCRYPTED" = 1 ]; then printf 'crypt\npart\ndisk\n'; else printf 'part\ndisk\n'; fi ;;
    '-dnro PKNAME /dev/fixture') echo container ;;
    *) exit 97 ;;
esac''')
        self.stub("blkid", r'''case "$*" in
    '-p -s TYPE -o value /dev/container') echo crypto_LUKS ;;
    '-p -s UUID -o value /dev/container') echo bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb ;;
    *) exit 97 ;;
esac''')
        self.stub("sudo", r'''case "$*" in
    'btrfs filesystem show --raw '*)
        echo 'Total devices 1 FS bytes used 0'
        echo 'devid 1 size 100 used 0 path /dev/fixture' ;;
    'blkid -p '*) exec "$@" ;;
    'cryptsetup status /dev/fixture') printf '  type: LUKS2\n  device: /dev/container\n' ;;
    'btrfs inspect-internal map-swapfile -r '*)
        [ "$FAILURE" != offset ] || exit 23; echo 123 ;;
    *) echo "Unexpected sudo: $*" >&2; exit 97 ;;
esac''')
        source = (LIB / "hibernation.sh").read_text().replace(
            '"/swap"', f'"{swap}"').replace('"/swap/swapfile"', f'"{swap}/swapfile"')
        return self.libraries("common.sh") + source + r'''
check_hibernation_swap_policy() { return 0; }
get_hibernation_cmdline() {
  if [[ "$FAILURE" = unlock ]]; then echo 'root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  else echo 'root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa rd.luks.uuid=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; fi
}
get_hibernation_hooks() { echo 'base systemd block sd-encrypt filesystems'; }
get_limine_config_value() { if [[ "$FAILURE" = hooks ]]; then echo '-S sd-encrypt'; fi; }
create_btrfs_swap() { printf 'reuse\t\n' >> "$CALLS"; }
ensure_limine_cmdline_defaults() { printf 'defaults\t\n' >> "$CALLS"; }
update_limine_cmdline() { printf '%s\t' update-limine "$@" >> "$CALLS"; printf '\n' >> "$CALLS"; }
write_mkinitcpio_dropin() { printf 'dropin\t\n' >> "$CALLS"; }
setup_hibernation
'''

    def test_resume_uses_verified_filesystem_for_plain_and_luks_btrfs(self):
        for encrypted in (False, True):
            with self.subTest(encrypted=encrypted):
                script = self.resume_fixture(encrypted=encrypted)
                self.calls.unlink(missing_ok=True)
                result = self.shell(script)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(["update-limine", "50-hibernation.conf", "--append",
                               "hibernate.compressor=lz4",
                               "resume=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                               "resume_offset=123"], self.logged_calls())

    def test_ambiguous_identity_or_missing_unlock_never_publishes_resume(self):
        for failure in ("identity", "uuid", "offset", "unlock", "hooks"):
            with self.subTest(failure=failure):
                self.calls.unlink(missing_ok=True)
                result = self.shell(self.resume_fixture(encrypted=True, failure=failure))
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(call[0] in ("defaults", "update-limine", "dropin")
                                     for call in self.logged_calls()))

    def test_other_persistent_swap_is_left_untouched(self):
        self.stub("swapon", "echo /dev/other", log=True)
        self.stub("systemctl", "exit 0")
        self.stub("findmnt", "echo '/dev/other none swap defaults'", log=True)
        result = self.shell(self.libraries("common.sh", "hibernation.sh") + "setup_hibernation\n")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("manual", result.stderr.lower())
        self.assertFalse(any(call[0] == "sudo" for call in self.logged_calls()))

    def test_unchanged_resume_does_not_request_another_rebuild(self):
        script = self.resume_fixture(encrypted=True).rsplit("setup_hibernation\n", 1)[0]
        boot = self.directory / "boot-options"
        dropins = self.directory / "initramfs-options"
        marker = self.directory / "state/chezmoi/initramfs.pending"
        self.stub("sed", 'exec /usr/bin/sed "$@"')
        self.stub("tee", 'exec /usr/bin/tee "$@"')
        sudo = self.bin / "sudo"
        body = sudo.read_text().replace(
            '    *) echo "Unexpected sudo: $*" >&2; exit 97 ;;', r'''
    'chown '*) exit 0 ;;
    'cmp '*|'mkdir '*|'mktemp '*|'tee '*|'chmod '*|'mv '*|'rm '*)
        for arg do
            case "$arg" in /*) case "$arg" in "$HOME"/*) ;; *) exit 97 ;; esac ;; esac
        done
        exec "$@" ;;
    *) exit 97 ;;''')
        sudo.write_text(body)
        script += f'INITRAMFS_PENDING_FILE="{marker}"\nMKINITCPIO_DROPIN_DIR="{dropins}"\n'
        for name in ("request_initramfs_rebuild", "update_limine_cmdline", "write_mkinitcpio_dropin"):
            script += self.function(LIB / "snapboot.sh", name).replace(
                "/etc/limine-entry-tool.d", str(boot))
        script += f'''setup_hibernation || exit 1
[[ -f "{marker}" ]] || exit 1
rm -- "{marker}"
setup_hibernation || exit 1
[[ ! -e "{marker}" ]] || exit 1
HOOKS=(base systemd block sd-encrypt filesystems)
source "{dropins}/hibernation.conf"
[[ " ${{HOOKS[*]}} " != *" resume "* ]]
'''
        result = self.shell(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("resume=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                      (boot / "50-hibernation.conf").read_text())

    def test_valid_managed_file_is_reused_but_unregistered_file_is_not_adopted(self):
        swap = self.directory / "swap"
        swap.mkdir()
        swapfile = swap / "swapfile"
        swapfile.write_text("existing swap contents")
        fstab = self.directory / "fstab"
        self.env.update(SWAP=str(swap), FSTAB=str(fstab))
        source = (LIB / "hibernation.sh").read_text().replace(
            "/etc/fstab", str(fstab)).replace('"/swap"', f'"{swap}"').replace(
            '"/swap/swapfile"', f'"{swapfile}"')
        self.stub("lsblk", "echo root-uuid")
        self.stub("mountpoint", "exit 0")
        self.stub("swapon", 'echo "$SWAP/swapfile"', log=True)
        self.stub("findmnt", r'''case "$*" in
    '-rn -o FSTYPE,UUID --mountpoint /') echo 'btrfs root-uuid' ;;
    '-rn -o TARGET,FSTYPE,UUID,FSROOT --mountpoint '*) printf '%s btrfs root-uuid /@swap\n' "$SWAP" ;;
    '-rn -o TARGET --target '*) echo "$SWAP" ;;
    '--fstab --tab-file '*) cat "$FSTAB" ;;
    *) exit 97 ;;
esac''')
        self.stub("sudo", r'''case "$*" in
    'btrfs subvolume list /') echo 'ID 256 gen 1 top level 5 path @swap' ;;
    'btrfs inspect-internal map-swapfile -r '*) echo 123 ;;
    *) echo "Unexpected mutation: $*" >&2; exit 97 ;;
esac''', log=True)
        for managed in (True, False):
            with self.subTest(managed=managed):
                self.calls.unlink(missing_ok=True)
                entries = f"UUID=root-uuid {swap} btrfs subvol=@swap\n"
                if managed:
                    entries += f"{swapfile} none swap defaults\n"
                fstab.write_text(entries)
                result = self.shell(self.libraries("common.sh") + source + '''
get_btrfs_root_device() { echo /dev/fixture; }
create_btrfs_swap
''')
                self.assertEqual(result.returncode, 0 if managed else 3, result.stderr)
                self.assertEqual(swapfile.read_text(), "existing swap contents")
                self.assertEqual(fstab.read_text(), entries)
                self.assertFalse(any("mkswapfile" in call for call in self.logged_calls()))

    def test_zram_is_preserved_and_inactive_or_multiple_persistent_swaps_skip(self):
        self.stub("swapon", 'printf "%s\\n" "$ACTIVE"')
        self.stub("findmnt", 'printf "%s\\n" "$TABLE"')
        self.stub("systemctl", "exit 0")
        for active, table, status in (
            ("/dev/zram0", "", 0),
            ("/dev/zram0\n/swap/swapfile", "/swap/swapfile none swap defaults", 0),
            ("", "/dev/other none swap defaults", 3),
            ("/swap/swapfile\n/dev/other", "", 3),
            ("", "/other/file none swap defaults", 3),
        ):
            with self.subTest(active=active, table=table):
                self.env.update(ACTIVE=active, TABLE=table)
                result = self.shell(self.libraries("common.sh", "hibernation.sh") +
                                    "check_hibernation_swap_policy\n")
                self.assertEqual(result.returncode, status, result.stderr)

    def test_cmdline_preflight_checks_prospective_defaults_and_rejects_overrides(self):
        etc = self.directory / "etc"
        etc.mkdir()
        (etc / "kernel").mkdir()
        (etc / "kernel/cmdline").write_text("root=UUID=filesystem resume=UUID=external noresume\n")
        dropins = etc / "limine-entry-tool.d"
        dropins.mkdir()
        (dropins / "20-quiet-boot.conf").write_text('KERNEL_CMDLINE[default]+= "quiet"\n')
        (etc / "default").mkdir()
        source = self.function(LIB / "hibernation.sh", "get_hibernation_cmdline").replace(
            "/etc/", f"{etc}/").replace("/usr/share/", f"{self.directory}/share/")
        self.stub("sudo", 'exec "$@"')
        self.stub("python3", 'exec /usr/bin/python3 "$@"')
        script = source + "get_hibernation_cmdline\n"
        result = self.shell(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("resume=UUID=external noresume", result.stdout)
        (dropins / "01-default.conf").write_text("KERNEL_CMDLINE[default]=root=UUID=filesystem rd.luks.uuid=container\n")
        result = self.shell(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "quiet root=UUID=filesystem rd.luks.uuid=container")
        late = etc / "default/limine"
        late.write_text('KERNEL_CMDLINE[default]="root=UUID=filesystem"\n')
        self.assertNotEqual(self.shell(script).returncode, 0)
        late.unlink()
        custom = dropins / "60-custom.conf"
        custom.write_text('KERNEL_CMDLINE[linux]="root=UUID=filesystem rd.luks.uuid=other"\n')
        self.assertNotEqual(self.shell(script).returncode, 0)
        custom.unlink()
        (dropins / "50-hibernation.conf").write_text('KERNEL_CMDLINE[default]+= "root=UUID=user-owned"\n')
        self.assertNotEqual(self.shell(script).returncode, 0)

    def test_persistent_unlock_uses_effective_crypttab_and_preserves_boot_intent(self):
        etc = self.directory / "etc"
        etc.mkdir()
        (etc / "mkinitcpio.conf.d").mkdir()
        (etc / "mkinitcpio.conf").write_text("HOOKS=(base systemd block sd-encrypt filesystems)\n")
        (etc / "limine-entry-tool.d").mkdir()
        kernel = etc / "kernel"
        kernel.mkdir()
        (kernel / "cmdline").write_text("root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa quiet\n")
        entry = "root UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb none luks,x-initrd.attach\n"
        (etc / "crypttab").write_text(entry)
        source = (LIB / "hibernation.sh").read_text().replace(
            "/etc/", f"{etc}/").replace("/usr/share/", f"{self.directory}/share/")
        self.stub("sudo", 'exec "$@"')
        self.stub("python3", 'exec /usr/bin/python3 "$@"')
        script = self.libraries("common.sh") + source + '''
get_limine_config_value() { return 0; }
luks_uuid=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
cmdline=$(get_hibernation_cmdline) || exit 1
verify_hibernation_unlock "$cmdline"
'''
        result = self.shell(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        shadow = etc / "crypttab.initramfs"
        shadow.write_text("# shadows the root entry\n")
        self.assertNotEqual(self.shell(script).returncode, 0)
        shadow.write_text(entry)
        self.assertEqual(self.shell(script).returncode, 0)
        (kernel / "cmdline").write_text("root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa luks.uuid=cccccccc-cccc-cccc-cccc-cccccccccccc\n")
        self.assertNotEqual(self.shell(script).returncode, 0)
        self.assertEqual((etc / "crypttab").read_text(), entry)
        self.assertEqual(shadow.read_text(), entry)

    def test_failed_hook_write_does_not_publish_resume_and_keeps_retry_pending(self):
        script = self.resume_fixture(encrypted=True)
        script = script.replace("setup_hibernation\n", "write_mkinitcpio_dropin() { return 1; }\nsetup_hibernation\n")
        result = self.shell(script)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse(any(call[0] in ("defaults", "update-limine")
                             for call in self.logged_calls()))
        self.stub("limine", "exit 97")
        source = self.render(SCRIPTS / "run_onchange_after_03_hibernation.sh.tmpl")
        source = source.replace("/usr/bin/limine", str(self.bin / "limine"))
        source = source.replace('\nmain "$@"', '''
check_btrfs() { return 0; }
is_laptop() { return 0; }
command_exists() { return 0; }
keep_sudo_alive() { return 0; }
validate_mkinitcpio_dropins() { return 0; }
setup_hibernation() { LAST_ERROR="fixture failure"; return 1; }
main "$@"''')
        result = self.shell(source)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual((self.directory / "state/chezmoi/hibernation.pending").read_text(), ".")
        self.assertNotIn("setup completed", result.stderr)

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
