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
        self.stub(
            "sudo",
            r"""case "$1" in
    bash) exec "$@" ;;
    chown) exit 0 ;;
    test|cmp|mkdir|mktemp|tee|chmod|mv|rm)
        for arg do
            case "$arg" in /*) case "$arg" in "$HOME"/*) ;; *) exit 97 ;; esac ;; esac
        done
        [ "$1:$FAILURE" != tee:write ] || exit 23
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

    def configure(self):
        source = (LIB / "snapboot.sh").read_text().replace("/etc/", f"{self.etc}/")
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
        root_mapping=root
    fi
}
get_limine_cmdline() {
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
