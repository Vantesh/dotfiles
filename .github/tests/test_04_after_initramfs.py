"""Late rebuild commit boundary and small real-artifact verifier fixtures."""

import hashlib
import json
import struct
import sys

from helpers import LIB, SCRIPTS, ScriptCase


class InitramfsTests(ScriptCase):
    def test_pending_request_is_cleared_only_after_a_verified_rebuild(self):
        boot = self.directory / "esp"
        boot.mkdir()
        marker = self.directory / "state/chezmoi/initramfs.pending"
        marker.parent.mkdir(parents=True)
        self.env.update(BOOT=str(boot), MARKER=str(marker))
        self.stub("limine", "exit 97")
        self.stub("limine-install", "exit 0", log=True)
        self.stub("limine-mkinitcpio", '''
[ -f "$MARKER" ] || exit 97
if [ "$FAILURE" = rebuild ]; then echo 'ERROR: generation failed'; fi
exit 0''', log=True)
        self.stub("limine-enroll-config", "exit 97")
        hook = self.directory / "post.d/90-limine-enroll-config"
        hook.parent.mkdir()
        hook.write_bytes((self.bin / "limine-enroll-config").read_bytes())
        hook.chmod(0o755)
        self.stub("jq", '''[ "$*" = '-e .installed == true' ] &&
[ "$(cat)" = '{"installed":true}' ]''')
        # Exercise orchestration; the verifier itself runs against real fixtures below.
        self.stub("sudo", r'''case "$1" in
    test|cmp) exec "$@" ;;
    env) shift; exec env "$@" ;;
    sbctl) [ "$*" = 'sbctl setup --print-state --json' ] && printf '{"installed":true}\n' ;;
    python3)
        case "$6" in
            inventory) printf '{}\n' ;;
            verify|enrollment)
                [ -f "$MARKER" ] || exit 97
                printf '%s\t\n' "$6" >> "$CALLS"
                [ "$FAILURE" != "$6" ] ;;
            *) exit 97 ;;
        esac ;;
    *) exit 97 ;;
esac''')
        source = self.render(SCRIPTS / "run_after_13_initramfs.sh.tmpl")
        source = source.replace("/usr/bin/limine", str(self.bin / "limine"))
        source = source.replace("/etc/boot/hooks/post.d/90-limine-enroll-config", str(hook))
        source = source.replace('\nmain "$@"', '''
command_exists() { return 0; }
keep_sudo_alive() { return 0; }
get_limine_boot_directory() { echo "$BOOT"; }
get_limine_config_value() {
    if [[ "$1" = ENABLE_ENROLL_LIMINE_CONFIG ]]; then echo "$ENROLL"; else echo no; fi
}
main "$@"''')
        for failure, enrollment in (
            ("rebuild", "no"), ("verify", "no"), ("", "no"),
            ("enrollment", "yes"), ("", "yes"),
        ):
            with self.subTest(failure=failure or "success", enrollment=enrollment):
                self.env.update(FAILURE=failure, ENROLL=enrollment)
                marker.touch()
                self.calls.unlink(missing_ok=True)
                result = self.shell(source)
                self.assertEqual(result.returncode, 1 if failure else 0, result.stderr)
                self.assertEqual(marker.exists(), bool(failure))
                calls = self.logged_calls()
                self.assertIn(["limine-install", "--no-efi-register"], calls)
                self.assertIn(["limine-mkinitcpio"], calls)
                self.assertEqual(["verify"] in calls, failure != "rebuild")
                self.assertEqual(["enrollment"] in calls, enrollment == "yes")
                if enrollment == "yes":
                    self.assertLess(calls.index(["verify"]), calls.index(["enrollment"]))


class RebuildVerifierTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.machine = "0123456789abcdef" * 2
        machine_file = self.directory / "machine-id"
        machine_file.write_text(self.machine)
        modules = self.directory / "modules"
        kernel_dir = modules / "fixture-version"
        kernel_dir.mkdir(parents=True)
        (kernel_dir / "modules.builtin").write_text("fixture\n")
        self.kernel = kernel_dir / "vmlinuz"
        self.kernel.write_bytes(b"fixture kernel")
        self.boot = self.directory / "esp"
        self.boot.mkdir()
        (self.boot / "vmlinuz").write_bytes(self.kernel.read_bytes())
        (self.boot / "initramfs.img").write_bytes(b"fixture initramfs")
        self.stub("pacman", "echo linux")
        self.stub("lsinitcpio", '''[ "$(cat "$4")" = 'fixture initramfs' ] || exit 23
printf '%s\\n' init usr/lib/modules/fixture-version/kernel/fixture.ko''')
        self.verifier = (LIB / "verify_limine_rebuild.py").read_text().replace(
            "/etc/machine-id", str(machine_file)
        ).replace("/usr/lib/modules", str(modules))
        self.current = ("//Kernel\ncomment: kernel-id=linux\nprotocol: linux\n"
                        "kernel_path: boot():/vmlinuz\nmodule_path: boot():/initramfs.img\n")
        self.uki_entry = ("//Kernel\ncomment: kernel-id=linux\nprotocol: efi\n"
                          "image_path: boot():/fixture.efi\n")
        self.history = ("//Snapshots\n///Old snapshot\n////Kernel\ncomment: kernel-id=linux\n"
                        "protocol: linux\nkernel_path: boot():/old/missing-kernel\n")

    def write_uki(self, kernel=b"fixture kernel", initrd=b"fixture initramfs"):
        # One fixed PE32+ image with two bounded, padded sections; never executable.
        image = bytearray(0x600)
        image[:2] = b"MZ"
        struct.pack_into("<I", image, 60, 0x80)
        image[0x80:0x84] = b"PE\0\0"
        struct.pack_into("<H", image, 0x86, 2)
        struct.pack_into("<H", image, 0x94, 112)
        struct.pack_into("<H", image, 0x98, 0x20B)
        struct.pack_into("<II", image, 0xD0, 0x3000, 0x200)
        for index, (name, payload) in enumerate(((b".linux", kernel), (b".initrd", initrd))):
            header = 0x108 + index * 40
            raw = 0x200 + index * 0x200
            struct.pack_into("<8sIIII", image, header, name, len(payload),
                             0x1000 + index * 0x1000, 0x200, raw)
            image[raw:raw + len(payload)] = payload
        (self.boot / "fixture.efi").write_bytes(image)

    def verify(self, entries, *, uki=False):
        (self.boot / "limine.conf").write_text(
            f"/+Fixture\ncomment: machine-id={self.machine}\n" + entries
        )
        expected = {"machine": self.machine, "fallback": "no", "uki": uki,
                    "kernels": {"linux": ["fixture-version", str(self.kernel),
                                          hashlib.blake2b(self.kernel.read_bytes()).hexdigest()]}}
        output = ("Building UKI for linux (fixture-version)\n"
                  "==> Initcpio image generation successful\n"
                  "==> Unified kernel image generation successful\n") if uki else (
                      "Building initramfs for linux (fixture-version)\n"
                      "==> Initcpio image generation successful\n")
        return self.run_process(
            [sys.executable, "-I", "-B", "-c", self.verifier, "verify", str(self.boot),
             "no", "yes" if uki else "no", json.dumps(expected)],
            name="rebuild verifier", input=output,
        )

    def test_current_artifacts_are_verified_independently_of_snapshot_history(self):
        for uki in (False, True):
            with self.subTest(protocol="UKI" if uki else "Linux"):
                self.write_uki()
                entries = self.uki_entry if uki else self.current
                result = self.verify(entries + self.history, uki=uki)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_current_entry_or_stale_artifact_cannot_verify_a_rebuild(self):
        result = self.verify(self.history)
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("missing or ambiguous", result.stderr)
        (self.boot / "vmlinuz").write_bytes(b"stale kernel")
        result = self.verify(self.current + self.history)
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("deployed kernel differs", result.stderr)
        for failure in ("stale-kernel", "wrong-initrd", "truncated-initrd"):
            with self.subTest(protocol="UKI", failure=failure):
                self.write_uki(kernel=b"stale kernel" if failure == "stale-kernel" else b"fixture kernel",
                               initrd=b"wrong initramfs" if failure == "wrong-initrd" else b"fixture initramfs")
                if failure == "truncated-initrd":
                    image = self.boot / "fixture.efi"
                    image.write_bytes(image.read_bytes()[:0x480])
                result = self.verify(self.uki_entry + self.history, uki=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                diagnostic = {"stale-kernel": "UKI kernel differs",
                              "wrong-initrd": "verification failed",
                              "truncated-initrd": "out-of-bounds PE section"}[failure]
                self.assertIn(diagnostic, result.stderr)

    def test_enrolled_checksum_matches_final_config_without_modifying_efi(self):
        config = self.boot / "limine.conf"
        config.write_text("timeout: 5\n/+Fixture\n")
        checksum = hashlib.blake2b(config.read_bytes()).hexdigest().encode()
        slot = b"++CONFIG_B2SUM_SIGNATURE++"
        image = self.boot / "EFI/limine/limine_x64.efi"
        image.parent.mkdir(parents=True)
        verifier = self.verifier.replace("arch = os.uname().machine", "arch = 'x86_64'")
        for case, payload in (
            ("matching", slot + checksum),
            ("stale", slot + b"f" * 128),
            ("zeroed", slot + b"0" * 128),
            ("missing", b"no checksum slot"),
            ("duplicate", slot + checksum + slot + checksum),
        ):
            with self.subTest(checksum=case):
                original = b"fixture EFI prefix" + payload + b"fixture suffix"
                image.write_bytes(original)
                result = self.run_process(
                    [sys.executable, "-I", "-B", "-c", verifier, "enrollment", str(self.boot)],
                    name="Limine enrolled checksum verifier",
                )
                self.assertEqual(result.returncode, 0 if case == "matching" else 1, result.stderr)
                self.assertEqual(image.read_bytes(), original)
                self.assertEqual(config.read_text(), "timeout: 5\n/+Fixture\n")
