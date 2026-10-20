"""Late rebuild commit boundary and a small real-artifact verifier fixture."""

import hashlib
import json
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
        # Never execute the privileged verifier or real boot/package commands here.
        self.stub("sudo", r'''case "$1" in
    test) shift; exec test "$@" ;;
    env) shift; exec env "$@" ;;
    python3)
        case "$6" in
            inventory) printf '{}\n' ;;
            verify)
                [ -f "$MARKER" ] || exit 97
                printf 'verify\t\n' >> "$CALLS"
                [ "$FAILURE" != verify ] ;;
            *) exit 97 ;;
        esac ;;
    *) exit 97 ;;
esac''')
        source = self.render(SCRIPTS / "run_after_13_initramfs.sh.tmpl")
        source = source.replace("/usr/bin/limine", str(self.bin / "limine"))
        source = source.replace('\nmain "$@"', '''
command_exists() { return 0; }
keep_sudo_alive() { return 0; }
get_limine_boot_directory() { echo "$BOOT"; }
get_limine_config_value() { echo no; }
main "$@"''')
        for failure in ("rebuild", "verify", ""):
            with self.subTest(failure=failure or "success"):
                self.env["FAILURE"] = failure
                marker.touch()
                self.calls.unlink(missing_ok=True)
                result = self.shell(source)
                self.assertEqual(result.returncode, 1 if failure else 0, result.stderr)
                self.assertEqual(marker.exists(), bool(failure))
                calls = self.logged_calls()
                self.assertIn(["limine-install", "--no-efi-register"], calls)
                self.assertIn(["limine-mkinitcpio"], calls)
                self.assertEqual(["verify"] in calls, failure != "rebuild")


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
        self.stub("lsinitcpio", "printf '%s\\n' init usr/lib/modules/fixture-version/kernel/fixture.ko")
        self.verifier = (LIB / "verify_limine_rebuild.py").read_text().replace(
            "/etc/machine-id", str(machine_file)
        ).replace("/usr/lib/modules", str(modules))
        self.current = ("//Kernel\ncomment: kernel-id=linux\nprotocol: linux\n"
                        "kernel_path: boot():/vmlinuz\nmodule_path: boot():/initramfs.img\n")
        self.history = ("//Snapshots\n///Old snapshot\n////Kernel\ncomment: kernel-id=linux\n"
                        "protocol: linux\nkernel_path: boot():/old/missing-kernel\n")

    def verify(self, entries):
        (self.boot / "limine.conf").write_text(
            f"/+Fixture\ncomment: machine-id={self.machine}\n" + entries
        )
        expected = {"machine": self.machine, "fallback": "no", "uki": False,
                    "kernels": {"linux": ["fixture-version", str(self.kernel),
                                          hashlib.blake2b(self.kernel.read_bytes()).hexdigest()]}}
        return self.run_process(
            [sys.executable, "-I", "-B", "-c", self.verifier, "verify", str(self.boot),
             "no", "no", json.dumps(expected)],
            name="rebuild verifier",
            input="Building initramfs for linux (fixture-version)\n==> Initcpio image generation successful\n",
        )

    def test_current_artifacts_are_verified_independently_of_snapshot_history(self):
        result = self.verify(self.current + self.history)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_current_entry_or_stale_artifact_cannot_verify_a_rebuild(self):
        result = self.verify(self.history)
        self.assertNotEqual(result.returncode, 0)
        (self.boot / "vmlinuz").write_bytes(b"stale kernel")
        result = self.verify(self.current + self.history)
        self.assertNotEqual(result.returncode, 0)
