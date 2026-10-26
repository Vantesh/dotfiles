"""Boot-option writes must preserve a usable config and a pending rebuild."""

import subprocess
from itertools import product
from typing import override

from helpers import LIB, SCRIPTS, ScriptCase


class SystemdInitramfsTests(ScriptCase):
    @override
    def setUp(self) -> None:
        super().setUp()
        self.etc = self.directory / "etc"
        self.etc.mkdir()
        parser_source = self.directory / "parser-source"
        parser = parser_source / ".chezmoitemplates/lib/limine_cmdline.py"
        parser.parent.mkdir(parents=True)
        parser.write_text(
            (LIB / "limine_cmdline.py")
            .read_text()
            .replace("/etc/", f"{self.etc}/")
            .replace("/usr/share/", f"{self.directory}/share/")
            .replace("/crypto_keyfile.bin", f"{self.directory}/crypto_keyfile.bin")
        )
        self.env["CHEZMOI_SOURCE_DIR"] = str(parser_source)
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
    '-c /dev/null -t UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb -o device'|\
    '-c /dev/null -t PARTUUID=fd8ce3d8-1e48-4b0e-91a8-24cdb2f14ce1 -o device')
        [ "$FAILURE" != source-missing ] || exit 2
        if [ "$FAILURE" = source-device ]; then echo /dev/other-container; else echo /dev/fixture-container; fi
        if [ "$FAILURE" = source-ambiguous ] || [ "$FAILURE:$4" = ambiguous:UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb ]; then
            echo /dev/duplicate-container
        fi ;;
    '-p -s TYPE -o value /dev/fixture-container')
        if [ "$FAILURE" = not-luks ]; then echo ext4; else echo crypto_LUKS; fi ;;
    '-p -s UUID -o value /dev/fixture-container')
        if [ "$FAILURE" = source-uuid ]; then echo dddddddd-dddd-dddd-dddd-dddddddddddd;
        else echo bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb; fi ;;
    *) exit 97 ;;
esac""",
            log=True,
        )
        self.stub(
            "lsblk",
            r"""case "$*" in
    '-dnro MAJ:MIN /dev/fixture-container')
        [ "$FAILURE" != not-block ] || exit 23
        echo 8:2 ;;
    '-dnro MAJ:MIN /dev/other-container') echo 8:3 ;;
    *) exit 97 ;;
esac""",
            log=True,
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
    blkid|test|stat|cp|cat|cmp|mkdir|mktemp|tee|chmod|mv|rm)
        for arg do
            case "$arg" in /*) case "$arg" in "$HOME"/*) ;; *) exit 97 ;; esac ;; esac
        done
        [ "$1:$FAILURE" != tee:write ] || exit 23
        case "$FAILURE:$*" in publish:mv*00-chezmoi-systemd.conf*) exit 23 ;; esac
        case "$FAILURE:$*" in defaults-publish:mv*01-default.conf.chezmoi.*) exit 23 ;; esac
        case "$FAILURE:$*" in fragment-publish:mv*20-quiet-boot.conf*) exit 23 ;; esac
        case "$FAILURE:$*" in postcheck:mv*00-chezmoi-systemd.conf.chezmoi.*)
            printf 'KERNEL_CMDLINE[default]= "root=UUID=independent"\n' > "$HOME/etc/default/limine" ;;
        esac
        exec "$@" ;;
    *) exit 97 ;;
esac""",
        )
        self.env.update(
            FAILURE="",
            ENCRYPTED="0",
            UKI_OPTIONS="",
            UNLOCK="rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root",
        )

    def configure(
        self, *, persistent: bool = False, entrypoint: bool = False
    ) -> subprocess.CompletedProcess[str]:
        source = (
            (LIB / "snapboot.sh")
            .read_text()
            .replace("/etc/", f"{self.etc}/")
            .replace("/usr/share/", f"{self.directory}/share/")
            .replace("/crypto_keyfile.bin", f"{self.directory}/crypto_keyfile.bin")
        )
        if not persistent:
            source += "\nget_limine_cmdline() { get_limine_cmdline_fixture; }\n"
        run = 'configure_systemd_initramfs || { printf "%s\\n" "$LAST_ERROR" >&2; exit 1; }\n'
        if entrypoint:
            self.stub("limine", "exit 97")
            run = (
                self.function(
                    SCRIPTS / "run_onchange_after_00_initramfs_config.sh.tmpl", "main"
                ).replace("/usr/bin/limine", str(self.bin / "limine"))
                + r"""
command_exists() { return 0; }
check_btrfs() { return 0; }
is_laptop() { [[ "$LAPTOP" = 1 ]]; }
keep_sudo_alive() { return 0; }
main || exit 1
"""
            )
        return self.shell(
            self.libraries("common.sh")
            + source
            + r"""
inspect_btrfs_device() {
    [[ "$FAILURE" != identity ]] || return 3
    resume_uuid=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
    luks_uuid=""; luks_device_id=""; root_mapping=""
    if [[ "$ENCRYPTED" = 1 ]]; then
        luks_uuid=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
        luks_device_id=8:2
        root_mapping="${MAPPING:-root}"
    fi
}
get_limine_cmdline_fixture() {
    if [[ "$FAILURE" = unlock ]]; then echo 'root=/dev/mapper/root';
    elif [[ "$FAILURE" = conflict ]]; then echo "root=/dev/mapper/root $UNLOCK rd.luks.name=cccccccc-cccc-cccc-cccc-cccccccccccc=root";
    else echo "root=/dev/mapper/root $UNLOCK"; fi
}
get_limine_config_value() { printf '%s\n' "$UKI_OPTIONS"; }
mkinitcpio_hook_exists() { [[ "$1:$FAILURE" != sd-encrypt:hook ]]; }
"""
            + run
            + "get_mkinitcpio_hooks\n"
        )

    def ensure_defaults(self) -> subprocess.CompletedProcess[str]:
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

    def write_fragment(self, name: str, params: str) -> subprocess.CompletedProcess[str]:
        self.env.update(FRAGMENT=name, PARAMETERS=params)
        source = (
            (LIB / "snapboot.sh")
            .read_text()
            .replace("/etc/", f"{self.etc}/")
            .replace("/usr/share/", f"{self.directory}/share/")
        )
        return self.shell(
            self.libraries("common.sh")
            + source
            + '\nupdate_limine_cmdline "$FRAGMENT" "$PARAMETERS" || { printf "%s\\n" "$LAST_ERROR" >&2; exit 1; }\n'
        )

    def test_feature_fragments_preserve_directives_and_request_only_changed_writes(self) -> None:
        for name, old, new in (
            ("20-quiet-boot.conf", "quiet loglevel=3 splash", "quiet loglevel=3"),
            (
                "50-hibernation.conf",
                "hibernate.compressor=lz4 resume=UUID=aaaa-bbbb resume_offset=123",
                "hibernate.compressor=lz4 resume=UUID=aaaa-bbbb resume_offset=456",
            ),
        ):
            with self.subTest(name=name):
                path = self.defaults.with_name(name)
                self.marker.unlink(missing_ok=True)
                result = self.write_fragment(name, old)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(path.read_text(), f'KERNEL_CMDLINE[default]+= "{old}"\n')
                original = f'# local settings\r\nOTHER_SETTING=yes\r\nKERNEL_CMDLINE[default]+= "{old}"\r\n'
                path.write_bytes(original.encode())
                path.chmod(0o640)
                self.marker.unlink()
                result = self.write_fragment(name, new)
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = original.replace(old, new).encode()
                self.assertEqual(path.read_bytes(), expected)
                self.assertEqual(path.stat().st_mode & 0o777, 0o640)
                self.assertTrue(self.marker.exists())
                self.marker.unlink()
                result = self.write_fragment(name, new)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(path.read_bytes(), expected)
                self.assertFalse(self.marker.exists())

    def test_unsafe_or_failed_feature_updates_preserve_existing_configuration(self) -> None:
        path = self.defaults.with_name("20-quiet-boot.conf")
        for original, failure in (
            ('# keep\nKERNEL_CMDLINE[default]= "root=UUID=user"\n', ""),
            ('KERNEL_CMDLINE[default]+= "quiet loglevel=7"\n', ""),
            ('KERNEL_CMDLINE[default]+= "quiet custom=keep"\n', ""),
            ('KERNEL_CMDLINE[default]+= "quiet"\nKERNEL_CMDLINE[default]+= "splash"\n', ""),
            ('# keep\nKERNEL_CMDLINE[default]+= "quiet splash"\n', "fragment-publish"),
        ):
            with self.subTest(original=original, failure=failure):
                path.write_text(original)
                self.marker.unlink(missing_ok=True)
                self.env["FAILURE"] = failure
                result = self.write_fragment(path.name, "quiet loglevel=3")
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual(path.read_text(), original)
                self.assertEqual(self.marker.exists(), failure == "fragment-publish")

    def test_defaults_remove_only_exact_active_owner_tokens_and_preserve_other_bytes(
        self,
    ) -> None:
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

    def test_default_cleanup_respects_missing_and_overridden_owners(self) -> None:
        original = 'KERNEL_CMDLINE[default]= "root=UUID=filesystem quiet resume_offset=123 loglevel=7 loglevel=3"\n'
        quiet = self.defaults.with_name("20-quiet-boot.conf")
        hibernation = self.defaults.with_name("50-hibernation.conf")
        late = self.etc / "default/limine"
        late.parent.mkdir()
        for case in (
            "missing",
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
                if case == "inactive":
                    quiet.write_text('# KERNEL_CMDLINE[default]+= "quiet"\n')
                elif case == "overridden":
                    quiet.write_text('KERNEL_CMDLINE[default]+= "quiet"\n')
                    late.write_text('KERNEL_CMDLINE[default]= "root=UUID=other quiet"\n')
                elif case == "conflict":
                    quiet.write_text('KERNEL_CMDLINE[default]+= "quiet loglevel=3"\n')
                    self.defaults.write_text(
                        'KERNEL_CMDLINE[default]= "root=UUID=filesystem loglevel=7 quiet"\n'
                    )
                elif case == "quoted-conflict":
                    hibernation.write_text('KERNEL_CMDLINE[default]+= "resume=UUID=managed"\n')
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
                    hibernation.write_text('KERNEL_CMDLINE[default]+= "resume_offset=123"\n')
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

    def test_initialization_preserves_settings_and_existing_prepend_arguments(self) -> None:
        base = "rd.luks.name=container=data rd.luks.options=container=tpm2-device=auto root=/dev/mapper/data quiet custom=quiet"
        original = (
            '# local settings\nOTHER_SETTING=yes\nKERNEL_CMDLINE[default]+= "local=first quiet"\n\n'
        )
        initialized = 'KERNEL_CMDLINE[default]= "rd.luks.name=container=data rd.luks.options=container=tpm2-device=auto root=/dev/mapper/data  custom=quiet"\n'
        self.defaults.with_name("20-quiet-boot.conf").write_text(
            'KERNEL_CMDLINE[default]+= "quiet"\n'
        )
        for case in ("missing-defaults", "existing-settings-and-prepend"):
            with self.subTest(case=case):
                self.kernel.write_text(base + "\n")
                self.defaults.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                expected = initialized
                if case == "existing-settings-and-prepend":
                    self.defaults.write_text(original)
                    self.defaults.chmod(0o640)
                    expected += '# local settings\nOTHER_SETTING=yes\nKERNEL_CMDLINE[default]+= "local=first "\n\n'
                result = self.ensure_defaults()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.defaults.read_text(), expected)
                self.assertEqual(
                    self.defaults.stat().st_mode & 0o777,
                    0o644 if case == "missing-defaults" else 0o640,
                )
                self.assertEqual(self.kernel.read_text(), base + "\n")
                self.assertTrue(self.marker.exists())
                self.marker.unlink()
                result = self.ensure_defaults()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.defaults.read_text(), expected)
                self.assertEqual(self.kernel.read_text(), base + "\n")
                self.assertFalse(self.marker.exists())

    def test_initialization_publication_failure_preserves_existing_defaults(self) -> None:
        original = "# user settings\nOTHER_SETTING=yes\n"
        self.defaults.write_text(original)
        self.kernel.write_text("root=UUID=filesystem quiet\n")
        self.env["FAILURE"] = "defaults-publish"
        result = self.ensure_defaults()
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.defaults.read_text(), original)
        self.assertEqual(self.kernel.read_text(), "root=UUID=filesystem quiet\n")
        self.assertTrue(self.marker.exists())

    def persistent_sources(self, unlock: str, *, mapping: str = "root") -> None:
        self.env.update(ENCRYPTED="1", MAPPING=mapping)
        arguments = (
            f"{unlock} root=/dev/mapper/{mapping} rootflags=subvol=/releases/root.v2 "
            'rw rootfstype=btrfs systemd.setenv="WELCOME=hello world"'
        )
        self.kernel.write_text(arguments + "\n")
        self.defaults.write_text(
            f'# local defaults\nKERNEL_CMDLINE[default]= "{arguments}"\nOTHER_SETTING=yes\n'
        )

    def test_active_legacy_unlock_arguments_preserve_boot_files_and_name_the_source(self) -> None:
        named = "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root"
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        extra = self.etc / "default/limine"
        extra.parent.mkdir()
        previous = "HOOKS=(base systemd block filesystems fsck)\n"
        for source, argument in (
            (self.defaults, legacy.replace(":root", ":other")),
            (self.defaults, legacy + ":allow-discards"),
            (self.defaults, named + " cryptkey=rootfs:/keyfile"),
            (self.defaults, named + " crypto=sha256:aes:256:0:"),
            (self.defaults, named + ' "cryptdevice=UUID=container:root"'),
            (self.kernel, legacy.replace("bbbbbbbb", "dddddddd")),
            (extra, legacy),
            (extra, named + " cryptkey=rootfs:/keyfile"),
        ):
            with self.subTest(source=source, argument=argument):
                self.persistent_sources(named)
                extra.unlink(missing_ok=True)
                self.managed.write_text(previous)
                self.marker.unlink(missing_ok=True)
                if source == self.kernel:
                    self.defaults.write_text("# no default override\nOTHER_SETTING=yes\n")
                    source.write_text(f"{argument} root=/dev/mapper/root\n")
                else:
                    source.write_text(
                        f'KERNEL_CMDLINE[default]= "{argument} root=/dev/mapper/root"\n'
                    )
                paths = [self.main, self.kernel, self.defaults, self.managed]
                if extra.exists():
                    paths.append(extra)
                before = [path.read_bytes() for path in paths]
                for encrypted in ("0", "1"):
                    self.env["ENCRYPTED"] = encrypted
                    result = self.configure(persistent=True)
                    self.assertNotEqual(result.returncode, 0, result.stderr)
                    self.assertIn(str(source), result.stderr)
                    self.assertEqual([path.read_bytes() for path in paths], before)
                    self.assertFalse(self.marker.exists())

    def test_fresh_luks_conversion_updates_active_sources_without_losing_tokens(self) -> None:
        named = "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=data-volume.v2"
        for identifier, sources in product(
            (
                "UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                "PARTUUID=fd8ce3d8-1e48-4b0e-91a8-24cdb2f14ce1",
            ),
            ("both", "kernel", "default", "no-kernel", "no-default", "filesystem-root"),
        ):
            with self.subTest(identifier=identifier, sources=sources):
                legacy = f"cryptdevice={identifier}:data-volume.v2"
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                self.persistent_sources(legacy, mapping="data-volume.v2")
                self.env.update(LAPTOP="0")
                custom = (
                    'custom=cryptdevice=unchanged  systemd.setenv="WORDS=hello world"\tloglevel=3'
                )
                for path in (self.kernel, self.defaults):
                    path.write_text(path.read_text().replace(legacy, legacy + "  " + custom))
                self.defaults.write_text("# " + legacy + "\n" + self.defaults.read_text())
                if sources == "kernel":
                    self.defaults.write_text("# unrelated defaults\nOTHER_SETTING=yes\n")
                elif sources == "default":
                    self.kernel.write_text("root=UUID=independent quiet\n")
                elif sources == "no-kernel":
                    self.kernel.unlink()
                elif sources == "no-default":
                    self.defaults.unlink()
                elif sources == "filesystem-root":
                    for path in (self.kernel, self.defaults):
                        path.write_text(
                            path.read_text().replace(
                                "root=/dev/mapper/data-volume.v2",
                                "root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                            )
                        )
                before = {
                    path: path.read_text() for path in (self.kernel, self.defaults) if path.exists()
                }
                result = self.configure(persistent=True, entrypoint=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                for path, text in before.items():
                    expected = (
                        text.replace(legacy, named)
                        if path == self.kernel
                        else text.replace(legacy + "  " + custom, named + "  " + custom)
                    )
                    self.assertEqual(path.read_text(), expected)
                self.assertEqual(self.kernel.exists(), sources != "no-kernel")
                self.assertEqual(self.defaults.exists(), sources != "no-default")
                self.assertIn(" sd-encrypt ", result.stdout)
                self.assertFalse(self.defaults.with_name("50-hibernation.conf").exists())
                self.assertTrue(self.marker.exists())
                paths = [*before, self.managed]
                after = [path.read_bytes() for path in paths]
                self.marker.unlink()
                result = self.configure(persistent=True, entrypoint=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([path.read_bytes() for path in paths], after)
                self.assertFalse(self.marker.exists())

    def test_archinstall_partuuid_uses_container_uuid_and_preserves_root_arguments(self) -> None:
        legacy = "cryptdevice=PARTUUID=fd8ce3d8-1e48-4b0e-91a8-24cdb2f14ce1:root"
        named = "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root"
        arguments = (
            legacy
            + " root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs\n"
        )
        self.env["ENCRYPTED"] = "1"
        self.kernel.write_text(arguments)
        result = self.configure(persistent=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.kernel.read_text(), arguments.replace(legacy, named))
        self.assertFalse(self.defaults.exists())
        self.assertIn(" sd-encrypt ", result.stdout)
        self.marker.unlink()
        after = (self.kernel.read_bytes(), self.managed.read_bytes())
        self.calls.unlink()
        result = self.configure(persistent=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.kernel.read_bytes(), self.managed.read_bytes()), after)
        self.assertFalse(self.marker.exists())
        self.assertEqual(self.logged_calls(), [])

    def test_unverified_installer_devices_never_publish_arguments_or_hooks(self) -> None:
        for identifier, failure in product(
            (
                "UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                "PARTUUID=fd8ce3d8-1e48-4b0e-91a8-24cdb2f14ce1",
            ),
            (
                "source-missing",
                "source-ambiguous",
                "source-device",
                "not-block",
                "not-luks",
                "source-uuid",
                "ambiguous",
            ),
        ):
            with self.subTest(identifier=identifier, failure=failure):
                self.env["FAILURE"] = failure
                self.persistent_sources(f"cryptdevice={identifier}:root")
                paths = (self.kernel, self.defaults, self.main)
                before = [path.read_bytes() for path in paths]
                result = self.configure(persistent=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual([path.read_bytes() for path in paths], before)
                self.assertFalse(self.managed.exists())
                self.assertFalse(self.marker.exists())

    def test_matching_busybox_and_systemd_selections_reuse_existing_policy(self) -> None:
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        named = "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root"
        options = "rd.luks.options=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=tpm2-device=auto,tpm2-pin=yes,tries=3"
        self.persistent_sources(legacy + " " + named + " " + options)
        before = (self.kernel.read_text(), self.defaults.read_text())
        result = self.configure(persistent=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.kernel.read_text(), before[0].replace(legacy, ""))
        self.assertEqual(self.defaults.read_text(), before[1].replace(legacy, ""))
        self.assertEqual(self.kernel.read_text().count(named), 1)

    def test_unsupported_installer_unlocks_never_publish_arguments_or_hooks(self) -> None:
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        for unlock in (
            legacy + ":allow-discards",
            legacy + " " + legacy,
            legacy.replace("UUID=", "PARTUUID="),  # Unresolvable PARTUUID, not the LUKS UUID.
            "cryptdevice=PARTUUID=fd8ce3d8-1e48-4b0e-91a8-24cdb2f14ce1:other",
            legacy + " cryptdevice=PARTUUID=fd8ce3d8-1e48-4b0e-91a8-24cdb2f14ce1:root",
            legacy.replace("UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "/dev/sda2"),
            legacy.replace("bbbbbbbb", "aaaaaaaa"),
            legacy.replace(":root", ":other"),
            legacy + " cryptkey=rootfs:/keyfile",
            legacy + " crypto=sha256:aes:256:0:",
            legacy + " rd.luks.name=dddddddd-dddd-dddd-dddd-dddddddddddd=root",
            legacy + " rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=other",
            legacy + " rd.luks=0",
            '"' + legacy + '"',
            'systemd.setenv="WORDS=before ' + legacy + ' after"',
            legacy + " -- init=custom",
        ):
            with self.subTest(unlock=unlock):
                self.persistent_sources(unlock)
                before = (
                    self.kernel.read_bytes(),
                    self.defaults.read_bytes(),
                    self.main.read_bytes(),
                )
                result = self.configure(persistent=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    (self.kernel.read_bytes(), self.defaults.read_bytes(), self.main.read_bytes()),
                    before,
                )
                self.assertFalse(self.managed.exists())
                self.assertFalse(self.marker.exists())

    def test_conversion_preserves_implicit_keys_independent_crypttab_and_hook_failures(
        self,
    ) -> None:
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        for failure in ("implicit", "embedded", "key-hook", "crypttab", "hook", "ambiguous"):
            with self.subTest(failure=failure):
                self.persistent_sources(legacy)
                self.main.write_text(self.original)
                implicit = self.directory / "crypto_keyfile.bin"
                table = self.etc / "crypttab"
                hook = self.etc / "initcpio/install/local-keyfiles"
                for path in (implicit, table, hook):
                    path.unlink(missing_ok=True)
                self.env["FAILURE"] = failure if failure in ("hook", "ambiguous") else ""
                if failure == "implicit":
                    implicit.touch()
                elif failure == "embedded":
                    self.main.write_text(
                        self.original.replace("FILES=(/keyfile)", f"FILES=({implicit})")
                    )
                elif failure == "key-hook":
                    self.main.write_text(self.original.replace("fsck)", "fsck local-keyfiles)"))
                    hook.parent.mkdir(parents=True, exist_ok=True)
                    hook.write_text("build() { add_file /private/key /crypto_keyfile.bin; }\n")
                elif failure == "crypttab":
                    table.write_text(
                        "other UUID=dddddddd-dddd-dddd-dddd-dddddddddddd none x-initrd.attach,tpm2-device=auto\n"
                    )
                paths = [self.kernel, self.defaults, self.main] + (
                    [table] if table.exists() else []
                )
                before = [path.read_bytes() for path in paths]
                result = self.configure(persistent=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual([path.read_bytes() for path in paths], before)
                self.assertFalse(self.managed.exists())
                self.assertFalse(self.marker.exists())

    def test_conversion_publication_failure_rolls_back_arguments_and_hooks(self) -> None:
        legacy = "cryptdevice=UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:root"
        previous = "# Managed systemd base; snapshot hooks belong to Snapper.\nHOOKS=(base systemd block filesystems fsck)\n"
        late = self.etc / "default/limine"
        late.parent.mkdir()
        for failure in ("publish", "postcheck"):
            with self.subTest(failure=failure):
                late.unlink(missing_ok=True)
                self.persistent_sources(legacy)
                self.managed.write_text(previous)
                self.marker.unlink(missing_ok=True)
                self.env["FAILURE"] = failure
                before = (
                    self.kernel.read_bytes(),
                    self.defaults.read_bytes(),
                    self.managed.read_bytes(),
                )
                result = self.configure(persistent=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    (
                        self.kernel.read_bytes(),
                        self.defaults.read_bytes(),
                        self.managed.read_bytes(),
                    ),
                    before,
                )
                self.assertIn("Rolled back", result.stderr)
                self.assertTrue(self.marker.exists())

    def test_matching_systemd_selection_and_crypttab_policy_are_preserved(self) -> None:
        table = self.etc / "crypttab"
        entry = "root UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb none x-initrd.attach,tpm2-device=auto,tpm2-pin=yes,tries=3\n"
        table.write_text(entry)
        for name in (
            "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root",
            "luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root",
            "rd.luks.uuid=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        ):
            with self.subTest(name=name):
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                options = "rd.luks.options=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=tpm2-device=auto,tpm2-pin=yes,tries=3"
                self.persistent_sources(name + " " + options)
                # Neither an inactive source nor comments are migration targets.
                self.kernel.write_text("cryptdevice=UUID=old:old root=/dev/mapper/old\n")
                self.defaults.write_text(
                    "# cryptkey=historical-reference\n" + self.defaults.read_text()
                )
                before = (self.kernel.read_bytes(), self.defaults.read_bytes())
                result = self.configure(persistent=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(table.read_text(), entry)
                self.assertEqual((self.kernel.read_bytes(), self.defaults.read_bytes()), before)
                self.assertIn(" sd-encrypt ", result.stdout)
                self.marker.unlink()
                result = self.configure(persistent=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.marker.exists())

    def test_kernel_only_systemd_defaults_and_plain_root_are_not_rewritten(self) -> None:
        named = "rd.luks.name=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=root"
        for encrypted, unlock in (("1", named), ("0", "")):
            with self.subTest(encrypted=encrypted):
                self.persistent_sources(unlock)
                self.env["ENCRYPTED"] = encrypted
                self.defaults.write_text("# unrelated defaults\nOTHER_SETTING=yes\n")
                before = (self.kernel.read_bytes(), self.defaults.read_bytes())
                result = self.configure(persistent=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(" sd-encrypt " in result.stdout, encrypted == "1")
                self.assertEqual((self.kernel.read_bytes(), self.defaults.read_bytes()), before)

    def test_later_dropins_are_judged_by_hook_ownership_not_filename(self) -> None:
        dropin = self.dropins / "zz-chezmoi-systemd.conf"
        for content, valid in (
            ("MODULES+=(amdgpu)\n", True),
            ("HOOKS+=(btrfs)\n", True),
            ("HOOKS=(base systemd block filesystems)\n", False),
        ):
            with self.subTest(content=content):
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                dropin.write_text(content)
                result = self.configure()
                self.assertEqual(result.returncode == 0, valid, result.stderr)
                self.assertEqual(dropin.read_text(), content)
                self.assertEqual(self.managed.exists(), valid)
                self.assertEqual(self.marker.exists(), valid)
                if valid:
                    self.marker.unlink()
                    result = self.configure()
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertFalse(self.marker.exists())

    def test_baseline_systemd_hooks_support_plain_and_encrypted_roots(self) -> None:
        for encrypted in ("0", "1"):
            with self.subTest(encrypted=encrypted):
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                unlock = self.env["UNLOCK"] if encrypted == "1" else ""
                self.persistent_sources(unlock)
                if encrypted == "0":
                    for path in (self.kernel, self.defaults):
                        path.write_text(
                            path.read_text().replace(
                                "root=/dev/mapper/root",
                                "root=UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                            )
                        )
                self.env["ENCRYPTED"] = encrypted
                before = (self.kernel.read_bytes(), self.defaults.read_bytes())
                result = self.configure(persistent=True, entrypoint=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                hooks = result.stdout.split()
                self.assertIn("systemd", hooks)
                self.assertEqual("sd-encrypt" in hooks, encrypted == "1")
                self.assertTrue(self.marker.exists())
                self.assertEqual((self.kernel.read_bytes(), self.defaults.read_bytes()), before)
                self.assertFalse(self.defaults.with_name("50-hibernation.conf").exists())
                self.assertFalse({"udev", "encrypt", "resume"}.intersection(hooks))
                self.marker.unlink()
                result = self.configure(persistent=True, entrypoint=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.marker.exists())

    def test_independent_base_target_is_preserved_before_publication(self) -> None:
        header = "# Managed systemd base; snapshot hooks belong to Snapper.\n"
        for content in (
            'FILES+=(/private/root.key)\nCOMPRESSION="lz4"\nHOOKS=(base systemd block filesystems fsck)\n',
            header + "HOOKS=(base systemd block filesystems fsck)\nFILES+=(/private/root.key)\n",
        ):
            with self.subTest(content=content):
                self.managed.write_text(content)
                result = self.configure()
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertIn(str(self.managed), result.stderr)
                self.assertEqual(self.managed.read_text(), content)
                self.assertFalse(self.marker.exists())

    def test_plain_and_encrypted_roots_preserve_optional_hooks_and_queue_once(self) -> None:
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
                config = self.original if plymouth else self.original.replace(" plymouth", "")
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

    def test_final_order_preserves_independent_snapper_and_unrelated_settings(self) -> None:
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

    def test_preflight_checks_the_exact_candidate_not_only_the_ownership_probe(self) -> None:
        function = self.function(
            LIB / "snapper_boot.sh",
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
        conditional.write_text('if [[ "${HOOKS[-1]}" != strip ]]; then HOOKS+=(strip); fi\n')
        result = self.configure()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.strip(),
            "base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth filesystems fsck sd-btrfs-overlayfs strip",
        )
        previous = self.managed.read_text()
        (self.dropins / "snapper.conf").unlink()
        self.main.write_text(self.original)
        conditional.write_text('if [[ "${HOOKS[-1]}" == fsck ]]; then HOOKS+=(sd-encrypt); fi\n')
        self.marker.unlink()
        result = self.configure()
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.managed.read_text(), previous)
        self.assertFalse(self.marker.exists())

    def test_failed_preflight_or_write_preserves_previous_hooks(self) -> None:
        previous = "# Managed systemd base; snapshot hooks belong to Snapper.\nHOOKS=(base systemd block filesystems fsck)\n"
        self.managed.write_text(previous)
        for failure in (
            "identity",
            "unlock",
            "conflict",
            "hook",
            "late",
            "late-matching",
            "snapshot",
            "write",
            "publish",
        ):
            with self.subTest(failure=failure):
                self.env.update(ENCRYPTED="1", FAILURE=failure)
                self.main.write_text(self.original)
                self.managed.write_text(previous)
                self.marker.unlink(missing_ok=True)
                late = self.dropins / "99-local.conf"
                late.unlink(missing_ok=True)
                if failure == "late":
                    late.write_text("HOOKS=(base systemd block filesystems)\n")
                elif failure == "late-matching":
                    late.write_text(
                        "HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block plymouth sd-encrypt filesystems fsck)\n"
                    )
                elif failure == "snapshot":
                    self.main.write_text(self.original.replace("fsck)", "fsck btrfs-overlayfs)"))
                result = self.configure()
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.managed.read_text(), previous)
                self.assertFalse(list(self.dropins.glob(".*.??????")))
                self.assertEqual(self.marker.exists(), failure in ("write", "publish"))

    def test_user_managed_early_unlock_presence_is_required_and_never_rewritten(self) -> None:
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
                named + " rd.luks.options=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb=tmp=ext4",
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

        early = self.etc / "crypttab.initramfs"
        self.env["UNLOCK"] = ""
        conflicting = entry.replace("root UUID=", "other UUID=")
        for case, host, included, valid in (
            (
                "included-root-overrides-host-conflict",
                conflicting,
                entry.replace("x-initrd.attach,", ""),
                True,
            ),
            ("included-conflict-overrides-host-root", entry, conflicting, False),
        ):
            with self.subTest(source=case):
                self.managed.unlink(missing_ok=True)
                self.marker.unlink(missing_ok=True)
                table.write_text(host)
                early.write_text(included)
                result = self.configure()
                self.assertEqual(result.returncode == 0, valid, result.stderr)
                self.assertEqual(self.managed.exists(), valid)
                self.assertEqual(self.marker.exists(), valid)
                self.assertEqual(table.read_text(), host)
                self.assertEqual(early.read_text(), included)
                self.assertEqual(self.main.read_text(), self.original)

    def test_unsafe_uki_overrides_never_publish_hooks(self) -> None:
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

    def test_snapper_hook_is_applied_once(self) -> None:
        function = self.function(
            LIB / "snapper_boot.sh",
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
                self.env.update(HOOK_ENV=hooks, FAILURE="snapshot-hook" if expected is None else "")
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
    @override
    def setUp(self) -> None:
        super().setUp()
        self.boot = self.directory / "esp"
        self.boot.mkdir()
        self.config = self.boot / "limine.conf"
        self.original = "timeout: 5\n/Arch\nprotocol: linux\n"
        self.config.write_text(self.original)
        self.marker = self.directory / "state/chezmoi/initramfs.pending"
        self.env["BOOT"] = str(self.boot)
        self.env["FAIL_STAGING"] = "1"
        self.stub("tee", 'exec /usr/bin/tee "$@"')
        self.stub("limine-entry-tool", "exit 97")
        self.stub(
            "sudo",
            r'''case "$1" in
    test|cmp|grep|awk|install|chmod|mv|rm) ;;
    tee) if [ "$FAIL_STAGING" = 1 ]; then printf 'stage-write\t\n' >> "$CALLS"; exit 23; fi ;;
    *) exit 97 ;;
esac
for arg do
    case "$arg" in /*) case "$arg" in "$HOME"/*|/dev/null) ;; *) exit 97 ;; esac ;; esac
done
exec "$@"''',
        )

    def configure(self) -> subprocess.CompletedProcess[str]:
        return self.shell(
            self.libraries("common.sh", "snapboot.sh")
            + r"""
get_limine_boot_directory() { echo "$BOOT"; }
LIMINE_OPTIONS=(timeout=0.5)
"""
            + self.function(
                SCRIPTS / "run_onchange_after_08_theming.sh.tmpl", "configure_limine_options"
            )
            + "\nconfigure_limine_options\n"
        )

    def test_failed_staging_preserves_boot_config_and_rebuild_request(self) -> None:
        result = self.configure()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.config.read_text(), self.original)
        self.assertTrue(self.marker.exists())
        self.assertIn(["stage-write"], self.logged_calls())
        self.assertFalse((self.boot / "limine.conf.new").exists())

    def test_alternative_config_does_not_block_managed_config_update(self) -> None:
        alternate = self.boot / "EFI/BOOT/limine.conf"
        alternate.parent.mkdir(parents=True)
        alternate.write_text("recovery config\n")
        self.env["FAIL_STAGING"] = "0"
        result = self.configure()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("timeout: 0.5\n", self.config.read_text())
        self.assertIn("/Arch\nprotocol: linux\n", self.config.read_text())
        self.assertEqual(alternate.read_text(), "recovery config\n")
        self.assertTrue(self.marker.exists())
