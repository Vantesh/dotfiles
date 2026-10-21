"""Boot-option writes must preserve a usable config and a pending rebuild."""

from helpers import LIB, SCRIPTS, ScriptCase


class SystemdInitramfsTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.etc = self.directory / "etc"
        self.etc.mkdir()
        self.dropins = self.etc / "mkinitcpio.conf.d"
        self.dropins.mkdir()
        self.main = self.etc / "mkinitcpio.conf"
        self.original = (
            "MODULES=(nvidia)\nBINARIES=(custom)\nFILES=(/keyfile)\n"
            'COMPRESSION="zstd"\nCOMPRESSION_OPTIONS=(-T0)\n'
            "HOOKS=(base udev autodetect microcode modconf kms keyboard keymap "
            "consolefont block plymouth encrypt filesystems fsck)\n"
        )
        self.main.write_text(self.original)
        self.managed = self.dropins / "00-chezmoi-systemd.conf"
        self.marker = self.directory / "state/chezmoi/initramfs.pending"
        self.stub("sort", 'exec /usr/bin/sort "$@"')
        self.stub("tee", 'exec /usr/bin/tee "$@"')
        self.stub("python3", 'exec /usr/bin/python3 "$@"')
        self.stub(
            "blkid",
            r"""case "$*" in
    '-t UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb -o device'|'-t PARTUUID=cccccccc-cccc-cccc-cccc-cccccccccccc -o device') echo /dev/fixture-container ;;
    *) exit 1 ;;
esac""",
        )
        self.stub(
            "lsblk",
            r"""case "$*" in
    '-dnro MAJ:MIN /dev/fixture-container'|'-dnro MAJ:MIN /dev/disk/by-id/fixture-container') echo 8:17 ;;
    '-dnro UUID /dev/disk/by-id/fixture-root') echo aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa ;;
    *) exit 1 ;;
esac""",
        )
        (self.etc / "kernel").mkdir()
        (self.etc / "limine-entry-tool.d").mkdir()
        self.kernel = self.etc / "kernel/cmdline"
        self.defaults = self.etc / "limine-entry-tool.d/01-default.conf"
        self.stub(
            "sudo",
            r"""case "$1" in
    bash|python3) exec "$@" ;;
    chown) exit 0 ;;
    test|stat|cp|cat|cmp|mkdir|mktemp|tee|chmod|mv|rm)
        for arg do
            case "$arg" in /*) case "$arg" in "$HOME"/*) ;; *) exit 97 ;; esac ;; esac
        done
        [ "$1:$FAILURE" != tee:write ] || exit 23
        case "$FAILURE:$*" in publish:mv*00-chezmoi-systemd.conf.chezmoi.*) exit 23 ;; esac
        exec "$@" ;;
    *) exit 97 ;;
esac""",
        )
        self.env.update(
            FAILURE="",
            ENCRYPTED="0",
            UKI_OPTIONS="",
            SETUP_HIBERNATION="0",
            UNLOCK="rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root",
        )

    def configure(self, *, persistent=False):
        source = (
            (LIB / "snapboot.sh")
            .read_text()
            .replace("/etc/", f"{self.etc}/")
            .replace("/usr/share/", f"{self.directory}/share/")
            .replace("/crypto_keyfile.bin", f"{self.directory}/crypto_keyfile.bin")
        )
        if not persistent:
            source += "\nget_limine_cmdline() { get_limine_cmdline_fixture; }\n"
        return self.shell(
            self.libraries("common.sh")
            + source
            + r"""
inspect_btrfs_device() {
    [[ "$FAILURE" != identity ]] || return 3
    resume_uuid=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
    luks_uuid=""; root_mapping=""
    if [[ "$ENCRYPTED" = 1 ]]; then
        luks_uuid=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
        root_mapping="${MAPPING:-root}"
        luks_device_id=8:17
    fi
}
get_limine_cmdline_fixture() {
    if [[ "$FAILURE" = unlock ]]; then echo 'root=/dev/mapper/root';
    elif [[ "$FAILURE" = conflict ]]; then echo "root=/dev/mapper/root $UNLOCK rd.luks.name=cccccccc-cccc-cccc-cccc-cccccccccccc=root";
    else echo "root=/dev/mapper/root $UNLOCK"; fi
}
get_limine_config_value() { printf '%s\n' "$UKI_OPTIONS"; }
mkinitcpio_hook_exists() { [[ "$1:$FAILURE" != sd-encrypt:hook ]]; }
configure_systemd_initramfs || { printf '%s\n' "$LAST_ERROR" >&2; exit 1; }
get_mkinitcpio_hooks
"""
        )

    def ensure_defaults(self):
        self.stub("sed", 'exec /usr/bin/sed "$@"')
        source = (
            (LIB / "snapboot.sh")
            .read_text()
            .replace("/etc/", f"{self.etc}/")
            .replace("/usr/share/", f"{self.directory}/share/")
        )
        return self.shell(
            self.libraries("common.sh")
            + source
            + '\nensure_limine_cmdline_defaults || { printf "%s\\n" "$LAST_ERROR" >&2; exit 1; }\n'
        )

    def test_defaults_remove_only_exact_active_owner_tokens_and_preserve_other_bytes(
        self,
    ):
        self.env["SETUP_HIBERNATION"] = "1"
        base = "rd.luks.name=container=data rd.luks.options=container=tpm2-device=auto root=/dev/mapper/data rootflags=subvol=/custom rw rootfstype=btrfs"
        custom = 'custom=quiet systemd.setenv="WORDS=quiet splash extra" nvidia_drm.modeset=1'
        original = f'# keep quiet and splash here\nKERNEL_CMDLINE[default]= "{base} quiet splash hibernate.compressor=lz4 resume=UUID=filesystem resume_offset=123 loglevel=3 {custom}"\nOTHER=yes\n\n'
        expected = f'# keep quiet and splash here\nKERNEL_CMDLINE[default]= "{base}       {custom}"\nOTHER=yes\n\n'
        self.defaults.write_text(original)
        self.kernel.write_text("root=/dev/mapper/data quiet splash\n")
        quiet = self.defaults.with_name("20-quiet-boot.conf")
        quiet.write_text('KERNEL_CMDLINE[default]+= "quiet splash loglevel=3"\n')
        hibernation = self.defaults.with_name("50-hibernation.conf")
        hibernation.write_text(
            'KERNEL_CMDLINE[default]+= "hibernate.compressor=lz4 resume=UUID=filesystem resume_offset=123"\n'
        )
        before = (
            self.kernel.read_bytes(),
            quiet.read_bytes(),
            hibernation.read_bytes(),
        )
        result = self.ensure_defaults()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.defaults.read_text(), expected)
        self.assertEqual(
            (self.kernel.read_bytes(), quiet.read_bytes(), hibernation.read_bytes()),
            before,
        )
        self.assertTrue(self.marker.exists())
        self.marker.unlink()
        result = self.ensure_defaults()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.defaults.read_text(), expected)
        self.assertFalse(self.marker.exists())

    def test_default_cleanup_respects_missing_disabled_and_overridden_owners(self):
        original = 'KERNEL_CMDLINE[default]= "root=UUID=filesystem quiet resume_offset=123 loglevel=7 loglevel=3"\n'
        quiet = self.defaults.with_name("20-quiet-boot.conf")
        hibernation = self.defaults.with_name("50-hibernation.conf")
        late = self.etc / "default/limine"
        late.parent.mkdir()
        for case in (
            "missing",
            "disabled",
            "inactive",
            "overridden",
            "conflict",
            "quoted-conflict",
            "separator",
            "crlf",
            "per-kernel",
            "alias-conflict",
            "bare-conflict",
        ):
            with self.subTest(case=case):
                self.defaults.write_text(original)
                self.marker.unlink(missing_ok=True)
                independent = self.etc / "limine-entry-tool.conf"
                for path in (quiet, hibernation, late, independent):
                    path.unlink(missing_ok=True)
                self.env["SETUP_HIBERNATION"] = "0"
                if case == "disabled":
                    hibernation.write_text(
                        'KERNEL_CMDLINE[default]+= "resume_offset=123"\n'
                    )
                elif case == "inactive":
                    quiet.write_text('# KERNEL_CMDLINE[default]+= "quiet"\n')
                elif case == "overridden":
                    quiet.write_text('KERNEL_CMDLINE[default]+= "quiet"\n')
                    late.write_text(
                        'KERNEL_CMDLINE[default]= "root=UUID=other quiet"\n'
                    )
                elif case == "conflict":
                    quiet.write_text('KERNEL_CMDLINE[default]+= "quiet loglevel=3"\n')
                    self.defaults.write_text(
                        'KERNEL_CMDLINE[default]= "root=UUID=filesystem loglevel=7 quiet"\n'
                    )
                elif case == "quoted-conflict":
                    self.env["SETUP_HIBERNATION"] = "1"
                    hibernation.write_text(
                        'KERNEL_CMDLINE[default]+= "resume=UUID=managed"\n'
                    )
                    self.defaults.write_text(
                        'KERNEL_CMDLINE[default]= "root=UUID=filesystem "resume=UUID=external" resume=UUID=managed"\n'
                    )
                elif case == "separator":
                    quiet.write_text('KERNEL_CMDLINE[default]+= "quiet"\n')
                    self.defaults.write_text(
                        'KERNEL_CMDLINE[default]= "root=UUID=filesystem init=/custom-init -- quiet"\n'
                    )
                elif case == "crlf":
                    self.defaults.write_bytes(original.replace("\n", "\r\n").encode())
                elif case == "per-kernel":
                    independent.write_text(
                        'KERNEL_CMDLINE[linux-custom]= "root=UUID=custom quiet"\n'
                    )
                elif case == "alias-conflict":
                    self.env["SETUP_HIBERNATION"] = "1"
                    hibernation.write_text(
                        'KERNEL_CMDLINE[default]+= "resume_offset=123"\n'
                    )
                    self.defaults.write_text(
                        'KERNEL_CMDLINE[default]= "root=UUID=filesystem resume-offset=456 resume_offset=123"\n'
                    )
                elif case == "bare-conflict":
                    quiet.write_text('KERNEL_CMDLINE[default]+= "quiet"\n')
                    self.defaults.write_text(
                        'KERNEL_CMDLINE[default]= "root=UUID=filesystem debug quiet"\n'
                    )
                expected = self.defaults.read_bytes()
                result = self.ensure_defaults()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.defaults.read_bytes(), expected)
                self.assertFalse(self.marker.exists())
                if case == "conflict":
                    self.assertIn("loglevel", result.stderr)

    def test_generated_defaults_deduplicate_without_rewriting_persistent_kernel_line(
        self,
    ):
        self.kernel.write_text("root=/dev/mapper/data quiet custom=quiet\n")
        self.defaults.with_name("20-quiet-boot.conf").write_text(
            'KERNEL_CMDLINE[default]+= "quiet"\n'
        )
        result = self.ensure_defaults()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.defaults.read_text(),
            'KERNEL_CMDLINE[default]= "root=/dev/mapper/data  custom=quiet"\n',
        )
        self.assertEqual(
            self.kernel.read_text(), "root=/dev/mapper/data quiet custom=quiet\n"
        )

    def legacy_sources(self, unlock, *, mapping="root"):
        self.env.update(ENCRYPTED="1", MAPPING=mapping)
        arguments = (
            f"{unlock} root=/dev/mapper/{mapping} rootflags=subvol=/releases/root.v2 "
            'rw rootfstype=btrfs resume=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa resume_offset=123 systemd.setenv="WELCOME=hello world"'
        )
        self.kernel.write_text(arguments + "\n")
        self.defaults.write_text(
            f'# local defaults\nKERNEL_CMDLINE[default]= "{arguments}"\nOTHER_SETTING=yes\n'
        )

    def test_legacy_root_selection_updates_both_sources_once(self):
        name = "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=data-volume.v2"
        for identifier in (
            "UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            "PARTUUID=cccccccc-cccc-cccc-cccc-cccccccccccc",
            "/dev/disk/by-id/fixture-container",
        ):
            with self.subTest(identifier=identifier):
                legacy = f"cryptdevice={identifier}:data-volume.v2"
                self.legacy_sources(legacy, mapping="data-volume.v2")
                if identifier.startswith("/dev/"):
                    for path in (self.defaults, self.kernel):
                        path.write_text(
                            path.read_text().replace(
                                "root=/dev/mapper/data-volume.v2",
                                "root=/dev/disk/by-id/fixture-root",
                            )
                        )
                before = self.defaults.read_text()
                kernel_before = self.kernel.read_text()
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                (self.etc / "limine-entry-tool.d/20-quiet-boot.conf").write_text(
                    'KERNEL_CMDLINE[default]+= "quiet splash"\n'
                )
                result = self.configure(persistent=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    self.defaults.read_text(), before.replace(legacy, name)
                )
                self.assertEqual(
                    self.kernel.read_text(), kernel_before.replace(legacy, name)
                )
                self.assertEqual(self.kernel.read_text().count(name), 1)
                self.assertIn(" sd-encrypt ", result.stdout)
                self.assertTrue(self.marker.exists())
                self.marker.unlink()
                result = self.configure(persistent=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.marker.exists())

    def test_unsupported_legacy_selection_never_changes_boot_files(self):
        valid = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        for unlock in (
            valid + ":allow-discards",
            valid + " cryptkey=rootfs:/keyfile",
            valid + ' "rd.luks=0"',
            valid + ' rd.luks.options="swap"',
            valid
            + ' systemd.setenv="BOOT_ARGS=before rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root after"',
            valid.replace(":root", ":other"),
            valid.replace(
                "UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                "UUID=dddddddd-dddd-dddd-dddd-dddddddddddd",
            ),
            valid + " " + valid,
            valid + " rd.luks.name=dddddddd-dddd-dddd-dddd-dddddddddddd=root",
        ):
            with self.subTest(unlock=unlock):
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                self.legacy_sources(unlock)
                before = (self.kernel.read_bytes(), self.defaults.read_bytes())
                result = self.configure(persistent=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    (self.kernel.read_bytes(), self.defaults.read_bytes()), before
                )
                self.assertFalse(self.managed.exists())
                self.assertFalse(self.marker.exists())

    def test_independent_sources_and_legacy_authentication_are_not_overwritten(self):
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        for failure in (
            "independent",
            "kernel-conflict",
            "embedded-key",
            "key-hook",
            "crypttab",
        ):
            with self.subTest(failure=failure):
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                self.legacy_sources(legacy)
                extra = self.etc / "default/limine"
                extra.parent.mkdir(exist_ok=True)
                extra.unlink(missing_ok=True)
                table = self.etc / "crypttab"
                table.unlink(missing_ok=True)
                self.main.write_text(self.original)
                if failure == "independent":
                    extra.write_text(
                        f'KERNEL_CMDLINE[default]= "{self.kernel.read_text().strip()}"\n'
                    )
                elif failure == "kernel-conflict":
                    self.kernel.write_text(
                        "rd.luks.name=dddddddd-dddd-dddd-dddd-dddddddddddd=root root=/dev/mapper/root\n"
                    )
                elif failure == "embedded-key":
                    self.main.write_text(
                        self.original.replace(
                            "FILES=(/keyfile)", "FILES=(/crypto_keyfile.bin)"
                        )
                    )
                elif failure == "key-hook":
                    self.main.write_text(
                        self.original.replace("fsck)", "fsck local-keyfiles)")
                    )
                    hook = self.etc / "initcpio/install/local-keyfiles"
                    hook.parent.mkdir(parents=True, exist_ok=True)
                    hook.write_text(
                        "build() { add_file /private/key /crypto_keyfile.bin; }\n"
                    )
                else:
                    table.write_text(
                        "other UUID=dddddddd-dddd-dddd-dddd-dddddddddddd none x-initrd.attach,tpm2-device=auto\n"
                    )
                before = (self.kernel.read_bytes(), self.defaults.read_bytes())
                result = self.configure(persistent=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    (self.kernel.read_bytes(), self.defaults.read_bytes()), before
                )
                self.assertFalse(self.managed.exists())
                self.assertFalse(self.marker.exists())

    def test_matching_systemd_selection_and_crypttab_policy_are_preserved(self):
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        table = self.etc / "crypttab"
        entry = "root UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb none x-initrd.attach,tpm2-device=auto,tpm2-pin=yes,tries=3\n"
        table.write_text(entry)
        for name in (
            "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root",
            "luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root",
            "rd.luks.uuid=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        ):
            with self.subTest(name=name):
                self.legacy_sources(legacy + " " + name)
                result = self.configure(persistent=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(table.read_text(), entry)
                self.assertEqual(self.kernel.read_text().count(name), 1)
                self.assertEqual(self.defaults.read_text().count(name), 1)
                self.assertNotIn("cryptdevice=", self.kernel.read_text())
                self.marker.unlink()
                result = self.configure(persistent=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.marker.exists())

    def test_comment_copy_is_preserved_while_active_default_is_migrated(self):
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        self.legacy_sources(legacy)
        active = self.defaults.read_text().splitlines(keepends=True)[1]
        self.defaults.write_text("# " + active + self.defaults.read_text())
        before = self.defaults.read_text()
        result = self.configure(persistent=True)
        self.assertEqual(result.returncode, 0, result.stderr)

        # Only the active line changes; the commented reference remains untouched.
        expected = (
            "# "
            + active
            + before[len("# " + active) :].replace(
                legacy, "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root"
            )
        )
        self.assertEqual(self.defaults.read_text(), expected)

    def test_hook_publication_failure_rolls_back_cmdlines_and_keeps_rebuild_pending(
        self,
    ):
        self.legacy_sources(
            "cryptdevice=PARTUUID=cccccccc-cccc-cccc-cccc-cccccccccccc:root"
        )
        self.env["FAILURE"] = "publish"
        before = (self.kernel.read_bytes(), self.defaults.read_bytes())
        result = self.configure(persistent=True)
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.kernel.read_bytes(), self.defaults.read_bytes()), before)
        self.assertFalse(self.managed.exists())
        self.assertTrue(self.marker.exists())

    def test_kernel_only_legacy_defaults_are_persisted_and_plain_root_is_untouched(
        self,
    ):
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        self.legacy_sources(legacy)
        self.defaults.write_text("# unrelated defaults\nOTHER_SETTING=yes\n")
        result = self.configure(persistent=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "# unrelated defaults\nOTHER_SETTING=yes\n", self.defaults.read_text()
        )
        self.assertNotIn("cryptdevice=", self.defaults.read_text())
        self.assertIn("rd.luks.name=", self.kernel.read_text())
        self.legacy_sources(legacy)
        self.env["ENCRYPTED"] = "0"
        before = (self.kernel.read_bytes(), self.defaults.read_bytes())
        result = self.configure(persistent=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("sd-encrypt", result.stdout)
        self.assertEqual((self.kernel.read_bytes(), self.defaults.read_bytes()), before)

    def test_plain_and_encrypted_roots_preserve_optional_hooks_and_queue_once(self):
        for encrypted, plymouth, extra, expected in (
            (
                "0",
                True,
                "",
                "base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth filesystems fsck",
            ),
            (
                "1",
                True,
                "",
                "base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth sd-encrypt filesystems fsck",
            ),
            (
                "0",
                False,
                "btrfs",
                "base systemd autodetect microcode modconf kms keyboard sd-vconsole block btrfs filesystems fsck",
            ),
            (
                "1",
                True,
                "strip",
                "base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth sd-encrypt filesystems fsck strip",
            ),
            (
                "0",
                True,
                "sd-btrfs-overlayfs",
                "base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth filesystems fsck sd-btrfs-overlayfs",
            ),
        ):
            with self.subTest(encrypted=encrypted, plymouth=plymouth, extra=extra):
                self.env["ENCRYPTED"] = encrypted
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                config = (
                    self.original
                    if plymouth
                    else self.original.replace(" plymouth", "")
                )
                config = (
                    config.replace("fsck)", f"fsck {extra})")
                    if extra in ("strip", "sd-btrfs-overlayfs")
                    else config.replace(" filesystems", f" {extra} filesystems")
                )
                self.main.write_text(config)
                result = self.configure()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)
                self.assertTrue(self.marker.exists())
                self.assertEqual(self.main.read_text(), config)
                self.marker.unlink()
                result = self.configure()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.marker.exists())

    def test_final_order_preserves_independent_snapper_and_unrelated_settings(self):
        (self.dropins / "99-local.conf").write_text(
            "MODULES+=(amdgpu)\nFILES+=(/other)\nHOOKS+=(btrfs)\n"
        )
        (self.dropins / "snapper.conf").write_text(
            'if [[ " ${HOOKS[*]} " = *" systemd "* && " ${HOOKS[*]} " != *" sd-btrfs-overlayfs "* ]]; then HOOKS+=(sd-btrfs-overlayfs); fi\n'
        )
        for prefix, expected in (
            (
                "",
                "base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth filesystems fsck btrfs sd-btrfs-overlayfs",
            ),
            (
                "HOOKS+=(sd-btrfs-overlayfs)\n",
                "base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth filesystems fsck sd-btrfs-overlayfs btrfs",
            ),
        ):
            with self.subTest(prefix=prefix):
                (self.dropins / "00-a-local.conf").write_text(prefix)
                result = self.configure()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)
                config = self.main.read_text() + "".join(
                    path.read_text() for path in sorted(self.dropins.iterdir())
                )
                result = self.shell(
                    config
                    + '\nprintf "%s\\n" "${MODULES[*]}|${BINARIES[*]}|${FILES[*]}|$COMPRESSION|${COMPRESSION_OPTIONS[*]}"\n'
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    result.stdout.strip(),
                    "nvidia amdgpu|custom|/keyfile /other|zstd|-T0",
                )

    def test_preflight_checks_the_exact_candidate_not_only_the_ownership_probe(self):
        function = self.function(
            SCRIPTS / "run_onchange_after_01_snapper.sh.tmpl",
            "add_mkinitcpio_overlay_hook",
        )
        result = self.shell(
            self.libraries("common.sh")
            + function
            + r"""
get_mkinitcpio_hooks() { echo 'base systemd block filesystems strip'; }
mkinitcpio_hook_exists() { return 0; }
write_mkinitcpio_dropin() { printf '%s\n' "$2"; }
add_mkinitcpio_overlay_hook
"""
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        (self.dropins / "snapper.conf").write_text(result.stdout)
        self.main.write_text(self.original.replace("fsck)", "fsck strip)"))
        conditional = self.dropins / "zz-strip.conf"
        conditional.write_text(
            'if [[ "${HOOKS[-1]}" != strip ]]; then HOOKS+=(strip); fi\n'
        )
        result = self.configure()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.strip(),
            "base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth filesystems fsck sd-btrfs-overlayfs strip",
        )
        previous = self.managed.read_text()
        (self.dropins / "snapper.conf").unlink()
        self.main.write_text(self.original)
        conditional.write_text(
            'if [[ "${HOOKS[-1]}" == fsck ]]; then HOOKS+=(sd-encrypt); fi\n'
        )
        self.marker.unlink()
        result = self.configure()
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.managed.read_text(), previous)
        self.assertFalse(self.marker.exists())

    def test_failed_preflight_or_write_preserves_previous_hooks(self):
        previous = "HOOKS=(base systemd block filesystems fsck)\n"
        self.managed.write_text(previous)
        for failure in (
            "identity",
            "unlock",
            "conflict",
            "hook",
            "late",
            "late-matching",
            "superseded",
            "snapshot",
            "write",
        ):
            with self.subTest(failure=failure):
                self.env.update(ENCRYPTED="1", FAILURE=failure, SETUP_SNAPPER="0")
                self.main.write_text(self.original)
                self.managed.write_text(previous)
                self.marker.unlink(missing_ok=True)
                late = self.dropins / "99-local.conf"
                superseded = self.dropins / "zz-chezmoi-systemd.conf"
                late.unlink(missing_ok=True)
                superseded.unlink(missing_ok=True)
                if failure == "late":
                    late.write_text("HOOKS=(base systemd block filesystems)\n")
                elif failure == "late-matching":
                    late.write_text(
                        "HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth sd-encrypt filesystems fsck)\n"
                    )
                elif failure == "superseded":
                    superseded.write_text(previous)
                elif failure == "snapshot":
                    self.main.write_text(
                        self.original.replace("fsck)", "fsck btrfs-overlayfs)")
                    )
                result = self.configure()
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.managed.read_text(), previous)
                self.assertFalse(list(self.dropins.glob(".*.??????")))
                self.assertEqual(self.marker.exists(), failure == "write")
                if failure == "superseded":
                    self.assertEqual(superseded.read_text(), previous)

    def test_user_managed_early_unlock_presence_is_required_and_never_rewritten(self):
        self.env.update(ENCRYPTED="1", UNLOCK="")
        table = self.etc / "crypttab"
        entry = "root UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb none x-initrd.attach,tpm2-device=auto,tpm2-pin=yes,tries=3\n"
        named = "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root"
        for contents, arguments, valid in (
            ("", "", False),
            (entry.replace("x-initrd.attach,", ""), "", False),
            (entry.replace("root UUID=", "other UUID="), "", False),
            (entry, "", True),
            (entry.replace("tries=3", "swap"), "", False),
            (entry.replace("tries=3", "swap"), named, False),
            (entry.replace("tries=3", "tmp=ext4"), "", False),
            (
                "",
                named
                + " rd.luks.options=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=tmp=ext4",
                False,
            ),
            (
                "",
                named + " rd.luks.options=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=swap",
                False,
            ),
        ):
            with self.subTest(contents=contents):
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                table.write_text(contents)
                self.env["UNLOCK"] = arguments
                result = self.configure()
                self.assertEqual(result.returncode == 0, valid, result.stderr)
                self.assertEqual(self.managed.exists(), valid)
                self.assertEqual(table.read_text(), contents)
                self.assertEqual(self.main.read_text(), self.original)

    def test_unsafe_uki_overrides_never_publish_hooks(self):
        self.env["ENCRYPTED"] = "1"
        for options in (
            "--skiphoo=sd-encrypt",
            "--conf=/etc/mkinitcpio.conf",
            "--nopo",
            "--cmdline /legacy",
        ):
            with self.subTest(options=options):
                self.env["UKI_OPTIONS"] = options
                result = self.configure()
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.managed.exists())
                self.assertFalse(self.marker.exists())

    def test_standalone_snapper_selects_once_with_hibernation_disabled(self):
        function = self.function(
            SCRIPTS / "run_onchange_after_01_snapper.sh.tmpl",
            "add_mkinitcpio_overlay_hook",
        )
        for hooks, expected in (
            (
                "base systemd block filesystems",
                "base systemd block filesystems sd-btrfs-overlayfs",
            ),
            (
                "base systemd block filesystems sd-btrfs-overlayfs",
                "base systemd block filesystems sd-btrfs-overlayfs",
            ),
            (
                "base udev block filesystems",
                "base udev block filesystems btrfs-overlayfs",
            ),
            (
                "base systemd block filesystems strip",
                "base systemd block filesystems sd-btrfs-overlayfs strip",
            ),
            ("base systemd block filesystems", None),
        ):
            with self.subTest(hooks=hooks, expected=expected):
                self.env.update(
                    HOOK_ENV=hooks, FAILURE="snapshot-hook" if expected is None else ""
                )
                (self.directory / "snapper.conf").unlink(missing_ok=True)
                result = self.shell(
                    self.libraries("common.sh")
                    + function
                    + r"""
get_mkinitcpio_hooks() { printf '%s\n' "$HOOK_ENV"; }
mkinitcpio_hook_exists() { [[ "$FAILURE:$1" != snapshot-hook:sd-btrfs-overlayfs ]]; }
write_mkinitcpio_dropin() { printf '%s\n' "$2" > "$HOME/snapper.conf"; }
add_mkinitcpio_overlay_hook || exit 1
HOOKS=("""
                    + hooks
                    + r""")
source "$HOME/snapper.conf"
source "$HOME/snapper.conf"
printf '%s\n' "${HOOKS[*]}"
"""
                )
                if expected is None:
                    self.assertNotEqual(result.returncode, 0, result.stderr)
                    self.assertFalse((self.directory / "snapper.conf").exists())
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), expected)


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
