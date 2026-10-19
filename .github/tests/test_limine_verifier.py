"""Exercise the actual rebuild verifier with isolated kernel and ESP fixtures."""

import ast
import hashlib
import json
import struct
import sys

from script_helpers import LIB, ScriptCase


class LimineVerifierTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.machine = "0123456789abcdef" * 2
        self.version = "fixture-version"
        machine_file = self.directory / "machine-id"
        machine_file.write_text(self.machine + "\n")
        modules = self.directory / "modules"
        kernel_dir = modules / self.version
        kernel_dir.mkdir(parents=True)
        (kernel_dir / "modules.builtin").write_text("fixture\n")
        self.kernel = b"fixture kernel payload"
        self.source = kernel_dir / "vmlinuz"
        self.source.write_bytes(self.kernel)
        self.boot = self.directory / "esp"
        self.boot.mkdir()
        (self.boot / "vmlinuz").write_bytes(self.kernel)
        (self.boot / "initramfs.img").write_bytes(b"fixture initramfs")
        (self.boot / "linux.efi").write_bytes(self.uki_image())
        self.stub("pacman", 'printf "%s\\n" linux')
        self.stub("lsinitcpio", f'printf "%s\\n" init usr/lib/modules/{self.version}/kernel/fixture.ko')
        self.verifier = (LIB / "verify_limine_rebuild.py").read_text().replace(
            "/etc/machine-id", str(machine_file)
        ).replace("/usr/lib/modules", str(modules))

    def uki_image(self):
        # Minimal bounded PE image with real .linux/.initrd section payloads.
        data = bytearray(1536)
        data[:2] = b"MZ"
        struct.pack_into("<I", data, 60, 64)
        data[64:68] = b"PE\0\0"
        struct.pack_into("<HH", data, 68, 0x8664, 2)
        struct.pack_into("<H", data, 84, 112)
        struct.pack_into("<H", data, 88, 0x20B)
        struct.pack_into("<II", data, 144, 0x3000, 512)
        for index, (name, payload) in enumerate(
            ((b".linux", self.kernel), (b".initrd", b"fixture initramfs"))
        ):
            offset = 200 + index * 40
            raw_offset = 512 + index * 512
            data[offset:offset + 8] = name.ljust(8, b"\0")
            struct.pack_into("<IIII", data, offset + 8,
                             len(payload), 0x1000 * (index + 1), 512, raw_offset)
            data[raw_offset:raw_offset + len(payload)] = payload
        return data

    def verify(self, *, uki, protocols, global_options="", extra_entries="", include_current=True):
        options = [f"protocol: {protocol}" for protocol in protocols]
        options += (["path: boot():/linux.efi"] if uki else [
            "kernel_path: boot():/vmlinuz", "module_path: boot():/initramfs.img"
        ])
        current = "//Kernel\ncomment: kernel-id=linux\n" + "\n".join(options) + "\n"
        (self.boot / "limine.conf").write_text(
            global_options + f"/+Fixture\ncomment: Fixture OS\ncomment: machine-id={self.machine}\n"
            + (current if include_current else "") + extra_entries
        )
        expected = {
            "machine": self.machine,
            "kernels": {"linux": [self.version, str(self.source),
                                  hashlib.blake2b(self.kernel).hexdigest()]},
            "fallback": "no",
            "uki": uki,
        }
        kind = "UKI" if uki else "initramfs"
        output = (f"Building {kind} for linux ({self.version})\n"
                  + "==> Initcpio image generation successful\n")
        if uki:
            output += "==> Unified kernel image generation successful\n"
        return self.run_process(
            [sys.executable, "-I", "-B", "-c", self.verifier, "verify",
             str(self.boot), "no", "yes" if uki else "no", json.dumps(expected)],
            input=output, name="Limine protocol verification",
        )

    def test_regular_linux_entry_passes_protocol_and_artifact_checks(self):
        result = self.verify(uki=False, protocols=["linux"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Verified generated boot entries", result.stdout)

    def test_uki_protocol_aliases_pass_protocol_and_artifact_checks(self):
        for protocol in ("efi", "efi_chainload", "uefi"):
            with self.subTest(protocol=protocol):
                result = self.verify(uki=True, protocols=[protocol])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Verified generated boot entries", result.stdout)

    def snapshot_entries(self, *, uki, menu="Snapshots"):
        options = (
            "protocol: efi\npath: boot():/old/limine_history/kernel.efi\n"
            if uki
            else "protocol: linux\nkernel_path: boot():/old/limine_history/vmlinuz\n"
            "module_path: boot():/old/limine_history/initramfs.img\n"
        )
        return f"//{menu}\ncomment: 10 / 10 snapshots\n" + "".join(
            f"///Snapshot {index}\ncomment: historical snapshot\n"
            f"////Kernel\ncomment: Kernel version: old\ncomment: kernel-id={kernel}\n"
            + options
            for index, kernel in enumerate(["linux"] * 10 + ["linux-fallback"])
        )

    def test_parser_marks_nested_snapshot_descendants_but_not_siblings(self):
        # Load definitions without executing the verifier's command-line entrypoint.
        module = ast.parse(self.verifier)
        module.body = [node for node in module.body
                       if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef))]
        namespace = {}
        exec(compile(module, "verify_limine_rebuild.py", "exec"), namespace)
        for menu in ("Snapshots", "+Snapshots"):
            with self.subTest(menu=menu):
                parsed = namespace["entries"](
                    f"/+OS\ncomment: machine-id={self.machine}\n"
                    "//Profiles\n"
                    f"///{menu}\n"
                    "////Historical snapshot\n"
                    "/////Kernel\ncomment: kernel-id=linux\n"
                    "///Live sibling\ncomment: kernel-id=linux\n"
                    "//Root sibling\ncomment: kernel-id=linux\n"
                )
                self.assertEqual([entry["snapshot"] for entry in parsed],
                                 [False, False, True, True, True, False, False])
                self.assertTrue(all(entry["machine"] == self.machine for entry in parsed))
                self.assertEqual([entry.get("kernel") for entry in parsed[4:]],
                                 ["linux", "linux", "linux"])
        self.assertFalse(namespace["is_snapshot_menu"]("Snapshots backup"))

    def test_snapshot_history_does_not_count_as_current_entries(self):
        for uki, protocol in ((False, "linux"), (True, "efi")):
            for menu in ("Snapshots", "+Snapshots"):
                with self.subTest(uki=uki, menu=menu):
                    result = self.verify(
                        uki=uki,
                        protocols=[protocol],
                        extra_entries=self.snapshot_entries(uki=uki, menu=menu),
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("Verified generated boot entries", result.stdout)

    def test_snapshot_history_cannot_replace_missing_current_entry(self):
        for uki, protocol in ((False, "linux"), (True, "efi")):
            with self.subTest(uki=uki):
                result = self.verify(
                    uki=uki,
                    protocols=[protocol],
                    include_current=False,
                    extra_entries=self.snapshot_entries(uki=uki),
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "missing or ambiguous generated kernel entry: linux", result.stderr
                )

    def test_duplicate_current_entries_remain_an_error(self):
        for uki, protocol in ((False, "linux"), (True, "efi")):
            with self.subTest(uki=uki):
                result = self.verify(
                    uki=uki,
                    protocols=[protocol],
                    extra_entries=(
                        "//Other current kernel\ncomment: kernel-id=linux\n"
                        + f"protocol: {protocol}\n"
                        + self.snapshot_entries(uki=uki)
                    ),
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "missing or ambiguous generated kernel entry: linux", result.stderr
                )

    def test_duplicate_protocols_are_rejected(self):
        for uki, protocol in ((False, "linux"), (True, "efi")):
            with self.subTest(uki=uki):
                result = self.verify(uki=uki, protocols=[protocol, protocol])
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("unsupported protocol for linux", result.stderr)

    def test_missing_and_unsupported_protocols_are_rejected(self):
        for uki in (False, True):
            for protocols in ([], ["multiboot2"], ["linux" if uki else "efi"]):
                with self.subTest(uki=uki, protocols=protocols):
                    result = self.verify(uki=uki, protocols=protocols)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("unsupported protocol for linux", result.stderr)

    def test_global_dtb_is_explicitly_unsupported(self):
        for uki, protocol in ((False, "linux"), (True, "efi")):
            for directive in ("global_dtb", "GLOBAL_DTB"):
                with self.subTest(uki=uki, directive=directive):
                    result = self.verify(
                        uki=uki, protocols=[protocol],
                        global_options=f"{directive}: boot():/missing.dtb\n",
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("unsupported global_dtb resource layout", result.stderr)
