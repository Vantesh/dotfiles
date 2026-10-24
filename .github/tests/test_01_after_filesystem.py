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

    def resume_fixture(
        self,
        *,
        encrypted=False,
        failure="",
        mapping="system-volume.v2",
        mapper_source=False,
        whole_device=False,
    ):
        swap = self.directory / "swap"
        swap.mkdir(exist_ok=True)
        (swap / "swapfile").touch()
        dev = self.directory / "dev"
        for directory in (
            dev,
            dev / "mapper",
            dev / "disk/by-id",
            dev / "disk/by-uuid",
            dev / "block",
        ):
            directory.mkdir(parents=True, exist_ok=True)
        for name in ("fixture", "container", "other"):
            (dev / name).touch()
        device_id = "240:5" if encrypted else "8:1"
        aliases = {
            dev / "mapper" / mapping: dev / "fixture",
            dev / "disk/by-id/system-volume": dev / "fixture",
            dev / "disk/by-uuid/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa": dev
            / ("container" if failure == "uuid" else "fixture"),
            dev / "block/8:17": dev / "container",
        }
        for alias, destination in aliases.items():
            alias.unlink(missing_ok=True)
            alias.symlink_to(destination)
        block = self.directory / "sys/dev/block" / device_id
        slaves = block / "slaves"
        slaves.mkdir(parents=True, exist_ok=True)
        for slave in slaves.iterdir():
            slave.unlink()
        parent = self.directory / "sys/backing-device"
        parent.mkdir(parents=True, exist_ok=True)
        (parent / "dev").write_text("8:17\n")
        if encrypted and failure != "missing-parent":
            (slaves / "backing-device").symlink_to(parent)
            if failure == "parents":
                (slaves / "second-device").symlink_to(parent)
        (block / "dm").mkdir(exist_ok=True)
        (block / "dm/name").write_text(mapping + "\n")
        source = dev / (
            "mapper/" + mapping if mapper_source else "disk/by-id/system-volume"
        )
        self.env.update(
            SWAP=str(swap),
            ENCRYPTED="1" if encrypted else "0",
            FAILURE=failure,
            DEV=str(dev),
            DEVICE_ID=device_id,
            MOUNT_SOURCE=str(source),
            WHOLE_DEVICE="1" if whole_device else "0",
        )
        self.stub(
            "findmnt",
            r"""case "$*" in
    '--nofsroot -rn -o SOURCE --target /'|'--nofsroot -n -o SOURCE --target /') printf '%s\n' "$MOUNT_SOURCE" ;;
    '-n -o SOURCE --target /') printf '%s[/releases/root.v2]\n' "$MOUNT_SOURCE" ;;
    '--nofsroot -rn -o TARGET,SOURCE,FSTYPE,UUID --target '*|'-rn -o TARGET,SOURCE,FSTYPE,UUID --target '*)
        [ "$FAILURE" != identity ] || exit 23
        for target do :; done
        if [ "$target" = / ]; then mount=/; else mount="$SWAP"; fi
        case "$1" in --nofsroot) source="$MOUNT_SOURCE" ;; *) source="$MOUNT_SOURCE[/releases/root.v2]" ;; esac
        printf '%s %s btrfs aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\n' "$mount" "$source" ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "lsblk",
            r"""case "$*" in
    "-dnro FSTYPE,UUID $DEV/fixture") echo 'btrfs aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' ;;
    "-dnro FSTYPE,UUID,MAJ:MIN $DEV/fixture") printf 'btrfs aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa %s\n' "$DEVICE_ID" ;;
    "-dnro MAJ:MIN $DEV/fixture") echo "$DEVICE_ID" ;;
    "-dnro MAJ:MIN $DEV/container") echo '8:17' ;;
    "-dnro MAJ:MIN $DEV/other") echo '8:18' ;;
    "-srn -o TYPE $DEV/fixture")
        [ "$FAILURE" != ancestry ] || { printf 'lvm\ncrypt\npart\ndisk\n'; exit; }
        [ "$ENCRYPTED" != 1 ] || printf 'crypt\n'
        [ "$WHOLE_DEVICE" = 1 ] || printf 'part\n'
        printf 'disk\n' ;;
    "-dnro PKNAME $DEV/fixture") exit 0 ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "blkid",
            r"""case "$*" in
    "-p -s TYPE -o value $DEV/container")
        if [ "$FAILURE" = not-luks ]; then echo ext4; else echo crypto_LUKS; fi ;;
    "-p -s UUID -o value $DEV/container") echo bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "sudo",
            r"""case "$*" in
    'btrfs filesystem show --raw '*)
        # This command selects mounted filesystems by directory, not swapfile.
        case "$5" in /|"$SWAP") ;; *) exit 23 ;; esac
        if [ "$FAILURE" = multi ]; then echo 'Total devices 2 FS bytes used 0'; else echo 'Total devices 1 FS bytes used 0'; fi
        printf 'devid 1 size 100 used 0 path %s/disk/by-uuid/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\n' "$DEV" ;;
    'blkid -p '*) exec "$@" ;;
    'bash '*) echo 'Hibernation must not inspect initramfs or unlocking policy' >&2; exit 97 ;;
    "cryptsetup status $DEV/fixture"|"env LC_ALL=C cryptsetup status $DEV/fixture")
        if [ "$FAILURE" = backing ]; then backing="$DEV/other"; else backing="$DEV/container"; fi
        printf '  type: LUKS2\n  device: %s\n' "$backing" ;;
    'btrfs inspect-internal map-swapfile -r '*)
        [ "$FAILURE" != offset ] || exit 23; echo 123 ;;
    *) echo "Unexpected sudo: $*" >&2; exit 97 ;;
esac""",
        )
        source = (LIB / "hibernation.sh").read_text().replace(
            '"/swap"', f'"{swap}"').replace('"/swap/swapfile"', f'"{swap}/swapfile"')
        return (
            self.libraries("common.sh")
            + (LIB / "snapboot.sh")
            .read_text()
            .replace('"/dev/', f'"{dev}/')
            .replace("/sys/", f"{self.directory}/sys/")
            + source
            + r"""
check_hibernation_swap_policy() { return 0; }
get_limine_cmdline() { echo 'root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; }
create_btrfs_swap() { printf 'reuse\t\n' >> "$CALLS"; }
ensure_limine_cmdline_defaults() { printf 'defaults\t\n' >> "$CALLS"; }
update_limine_cmdline() { printf '%s\t' update-limine "$@" >> "$CALLS"; printf '\n' >> "$CALLS"; }
setup_hibernation
"""
        )

    def test_detector_resolves_subvolume_sources_and_mapper_aliases(self):
        script = self.resume_fixture(
            encrypted=True, mapping="data[system]:v2", mapper_source=True
        ).rsplit("setup_hibernation\n", 1)[0]
        result = self.shell(
            "set -euo pipefail\nshopt -s nullglob\n"
            + script
            + r"""
inspect_btrfs_device / || { printf '%s\n' "$LAST_ERROR" >&2; exit 1; }
printf '%s|%s|%s|%s\n' "$resume_uuid" "$luks_uuid" "$root_mapping" "$luks_device_id"
get_btrfs_root_device
"""
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            [
                "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa|bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb|data[system]:v2|8:17",
                str(self.directory / "dev/mapper/data[system]:v2"),
            ],
        )

    def test_resume_uses_verified_filesystem_for_plain_and_luks_btrfs(self):
        for encrypted, whole_device in (
            (False, False),
            (True, False),
            (False, True),
            (True, True),
        ):
            with self.subTest(encrypted=encrypted, whole_device=whole_device):
                script = self.resume_fixture(
                    encrypted=encrypted, whole_device=whole_device
                )
                self.calls.unlink(missing_ok=True)
                result = self.shell(script)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(["update-limine", "50-hibernation.conf",
                               "hibernate.compressor=lz4",
                               "resume=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                               "resume_offset=123"], self.logged_calls())

    def test_ambiguous_identity_or_offset_never_publishes_resume(self):
        for failure in (
            "identity",
            "uuid",
            "multi",
            "ancestry",
            "not-luks",
            "missing-parent",
            "parents",
            "backing",
            "offset",
        ):
            with self.subTest(failure=failure):
                self.calls.unlink(missing_ok=True)
                result = self.shell(
                    "set -euo pipefail\nshopt -s nullglob\n"
                    + self.resume_fixture(encrypted=True, failure=failure)
                )
                self.assertNotEqual(result.returncode, 0)
                reasons = {
                    "missing-parent": "one direct backing",
                    "parents": "one direct backing",
                    "backing": "LUKS backing",
                }
                if failure in reasons:
                    self.assertIn(reasons[failure], result.stderr)
                self.assertFalse(
                    any(
                        call[0] in ("defaults", "update-limine")
                        for call in self.logged_calls()
                    )
                )

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
        kernel = self.directory / "etc/kernel/cmdline"
        kernel.parent.mkdir(parents=True)
        kernel.write_text("root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\n")
        self.stub("python3", 'exec /usr/bin/python3 "$@"')
        sudo = self.bin / "sudo"
        body = sudo.read_text().replace(
            '    *) echo "Unexpected sudo: $*" >&2; exit 97 ;;', r'''
    'python3 '*) exec "$@" ;;
    'test '*|'stat '*|'cp '*|'cat '*|'cmp '*|'mkdir '*|'mktemp '*|'tee '*|'chmod '*|'mv '*|'rm '*)
        for arg do
            case "$arg" in /*) case "$arg" in "$HOME"/*) ;; *) exit 97 ;; esac ;; esac
        done
        exec "$@" ;;
    *) exit 97 ;;''')
        sudo.write_text(body)
        script = script.replace(
            "readonly INITRAMFS_PENDING_FILE=", "INITRAMFS_PENDING_FILE="
        ).replace("readonly MKINITCPIO_DROPIN_DIR=", "MKINITCPIO_DROPIN_DIR=")
        script += f'INITRAMFS_PENDING_FILE="{marker}"\nMKINITCPIO_DROPIN_DIR="{dropins}"\n'
        for name in ("request_initramfs_rebuild", "update_limine_cmdline", "_stage_limine_fragment", "get_limine_cmdline"):
            script += self.function(LIB / "snapboot.sh", name).replace(
                "/etc/limine-entry-tool.d", str(boot)).replace(
                "/etc/", f"{self.directory}/etc/").replace(
                "/usr/share/", f"{self.directory}/share/")
        script += f'''setup_hibernation || exit 1
[[ -f "{marker}" ]] || exit 1
rm -- "{marker}"
setup_hibernation || exit 1
[[ ! -e "{marker}" ]] || exit 1
[[ ! -e "{dropins}" ]]
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
        owner = self.directory / "state/chezmoi/hibernation.swapfile"
        owner.parent.mkdir(parents=True)
        for ownership in ("matching", "missing", "stale"):
            with self.subTest(ownership=ownership):
                self.calls.unlink(missing_ok=True)
                entries = f"UUID=root-uuid {swap} btrfs subvol=@swap\n"
                entries += f"{swapfile} none swap defaults\n"
                fstab.write_text(entries)
                owner.unlink(missing_ok=True)
                if ownership != "missing":
                    inode = swapfile.stat().st_ino if ownership == "matching" else 0
                    owner.write_text(f"root-uuid {swapfile} {inode}\n")
                result = self.shell(self.libraries("common.sh") + source + '''
get_btrfs_root_device() { echo /dev/fixture; }
create_btrfs_swap
''')
                self.assertEqual(result.returncode, 0 if ownership == "matching" else 3, result.stderr)
                self.assertEqual(swapfile.read_text(), "existing swap contents")
                self.assertEqual(fstab.read_text(), entries)
                self.assertFalse(any("mkswapfile" in call for call in self.logged_calls()))

    def test_swap_unit_inventory_accepts_no_matches_but_rejects_command_errors(self):
        self.stub("swapon", "exit 0")
        self.stub("findmnt", "echo '/dev/mapper/root / btrfs defaults'")
        self.stub(
            "systemctl",
            r"""case "$*" in
    'list-unit-files --type=swap --no-legend --no-pager')
        printf '%s' "$UNITS"
        printf '%s' "$DIAGNOSTIC" >&2
        exit "$STATUS" ;;
    'show --property=What --value '*.swap) printf '%s\n' "$SWAP_PATH" ;;
    *) exit 97 ;;
esac""",
        )
        for units, diagnostic, status, path, expected in (
            ("", "", 1, "", 0),
            ("", "Failed to connect to system scope bus\n", 1, "", 1),
            ("", "", 2, "", 1),
            ("custom.swap enabled enabled\n", "", 0, "/other/swapfile", 3),
            ("dev-zram0.swap generated -\n", "", 0, "/dev/zram0", 0),
            ("swap-swapfile.swap generated -\n", "", 0, "/swap/swapfile", 0),
        ):
            with self.subTest(units=units, diagnostic=diagnostic, status=status):
                self.env.update(
                    UNITS=units,
                    DIAGNOSTIC=diagnostic,
                    STATUS=str(status),
                    SWAP_PATH=path,
                )
                result = self.shell(self.libraries("common.sh", "hibernation.sh") +
                                    "check_hibernation_swap_policy\n")
                self.assertEqual(result.returncode, expected, result.stderr)

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
        source = (
            self.function(LIB / "snapboot.sh", "get_limine_cmdline")
            .replace("/etc/", f"{etc}/")
            .replace("/usr/share/", f"{self.directory}/share/")
        )
        self.stub("sudo", 'exec "$@"')
        self.stub("python3", 'exec /usr/bin/python3 "$@"')
        script = source + "get_limine_cmdline hibernation\n"
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
        result = self.shell(source + "get_limine_cmdline initramfs\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "root=UUID=filesystem")
        late.unlink()
        custom = dropins / "60-custom.conf"
        custom.write_text('KERNEL_CMDLINE[linux]="root=UUID=filesystem rd.luks.uuid=other"\n')
        self.assertNotEqual(self.shell(script).returncode, 0)
        custom.unlink()
        (dropins / "50-hibernation.conf").write_text('KERNEL_CMDLINE[default]+= "root=UUID=user-owned"\n')
        self.assertNotEqual(self.shell(script).returncode, 0)

    def test_hook_verification_matches_mkinitcpio_version_order(self):
        etc = self.directory / "etc"
        etc.mkdir()
        (etc / "mkinitcpio.conf").write_text("HOOKS=(base systemd block filesystems)\n")
        dropins = etc / "mkinitcpio.conf.d"
        dropins.mkdir()
        (dropins / "2-unlock.conf").write_text("HOOKS=(base systemd block sd-encrypt filesystems)\n")
        (dropins / "10-local.conf").write_text(
            "HOOKS=(base systemd block filesystems fsck)\n"
        )
        self.stub("sudo", 'exec "$@"')
        self.stub("sort", 'exec /usr/bin/sort "$@"')
        source = self.function(LIB / "snapboot.sh", "get_mkinitcpio_hooks").replace(
            "/etc/", f"{etc}/"
        )
        result = self.shell(source + "get_mkinitcpio_hooks\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "base systemd block filesystems fsck")

    def test_failed_swap_setup_does_not_publish_resume_and_keeps_retry_pending(self):
        script = self.resume_fixture(encrypted=True)
        script = script.replace(
            "setup_hibernation\n",
            "create_btrfs_swap() { return 1; }\nsetup_hibernation\n",
        )
        result = self.shell(script)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse(any(call[0] in ("defaults", "update-limine")
                             for call in self.logged_calls()))

        etc = self.directory / "etc"
        (etc / "kernel").mkdir(parents=True)
        kernel = etc / "kernel/cmdline"
        kernel.write_text("root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\n")
        fstab = etc / "fstab"
        original = "# existing fstab\n"
        swapfile = self.directory / "swap/swapfile"
        swapfile.parent.mkdir(exist_ok=True)
        swapfile.touch()
        self.env["FSTAB"] = str(fstab)
        self.stub("limine", "exit 97")
        self.stub("mkinitcpio", "exit 97")
        self.stub("python3", 'exec /usr/bin/python3 "$@"')
        self.stub("tee", 'exec /usr/bin/tee "$@"')
        self.stub("findmnt", '''[ "$1" = --fstab ] || exit 97
awk '!/^[[:space:]]*(#|$)/ {print $1, $2, $3, $4}' "$FSTAB"''')
        self.stub("sudo", r'''case "$1" in
    bash|python3) exec "$@" ;;
    btrfs) [ "$2 $3 $4" = 'inspect-internal map-swapfile -r' ] && echo 123; exit ;;
    test|stat|cp|cat|cmp|mkdir|mktemp|tee|chmod|mv|rm) ;;
    *) exit 97 ;;
esac
for arg do
    case "$arg" in /*) case "$arg" in "$HOME"/*) ;; *) exit 97 ;; esac ;; esac
done
if [ "$1" = mv ]; then
    for target do :; done
    if [ "$target" = "$HOME/etc/limine-entry-tool.d/50-hibernation.conf" ]; then
        if [ "$FAILURE" = concurrent-edit ]; then printf '# independent edit\n' >> "$FSTAB"; fi
        exit 23
    fi
fi
exec "$@"''')
        source = self.render(SCRIPTS / "run_onchange_after_03_hibernation.sh.tmpl")
        source = source.replace("/etc/", f"{etc}/").replace(
            "/usr/share/", f"{self.directory}/share/")
        source = source.replace('"/swap"', f'"{swapfile.parent}"').replace(
            '"/swap/swapfile"', f'"{swapfile}"')
        source = source.replace("/usr/bin/limine", str(self.bin / "limine"))
        source = source.replace('\nmain "$@"', '''
check_btrfs() { return 0; }
is_laptop() { return 0; }
keep_sudo_alive() { return 0; }
reload_systemd_daemon() { return 0; }
check_hibernation_swap_policy() { return 0; }
inspect_btrfs_device() {
    resume_uuid=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
    luks_uuid=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
}
# Storage preparation is simulated; fstab edits, resume staging and rollback are real.
create_btrfs_swap() {
    _add_hibernation_fstab_entry "$SWAP_FILE_PATH none swap defaults 0 0" fixture
}
main "$@"''')
        pending = self.directory / "state/chezmoi/hibernation.pending"
        rebuild = self.directory / "state/chezmoi/initramfs.pending"
        for failure in ("publish", "concurrent-edit"):
            with self.subTest(failure=failure):
                fstab.write_text(original)
                pending.unlink(missing_ok=True)
                rebuild.unlink(missing_ok=True)
                self.env["FAILURE"] = failure
                result = self.shell(source)
                self.assertEqual(result.returncode, 1, result.stderr)
                expected = original if failure == "publish" else (
                    original + f"\n{swapfile} none swap defaults 0 0\n# independent edit\n")
                self.assertEqual(fstab.read_text(), expected)
                self.assertEqual(pending.read_text(), ".")
                self.assertTrue(rebuild.exists())
                self.assertFalse((etc / "limine-entry-tool.d/50-hibernation.conf").exists())
                self.assertNotIn("resume=", (etc / "limine-entry-tool.d/01-default.conf").read_text())
                self.assertEqual(kernel.read_text(), "root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\n")
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
