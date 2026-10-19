"""Check regular Linux and UKI rebuilds; unsupported entry/resource layouts fail closed.

This is a completion check, not proof of hook semantics, signing, or freshness.
Successful build diagnostics are required because intact old artifacts can survive
failed builds. Paths come from generated entries, never assumed output filenames.
"""

import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
from itertools import pairwise
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "blake2b").hexdigest()


def inventory(fallback, uki):
    require(uki in ("", "no", "yes"), "unsupported ENABLE_UKI")
    machine = Path("/etc/machine-id").read_text().strip()
    require(re.fullmatch(r"[0-9a-f]{32}", machine), "invalid machine-id")
    kernels = {}
    for builtin in sorted(Path("/usr/lib/modules").glob("*/modules.builtin")):
        source = builtin.parent / "vmlinuz"
        owner = subprocess.run(
            ["pacman", "-Qqo", str(builtin)], capture_output=True, text=True, check=True
        ).stdout.strip()
        require(re.fullmatch(r"[A-Za-z0-9@._+-]+", owner), f"ambiguous kernel owner: {builtin}")
        require(owner not in kernels, f"multiple installed versions of {owner}; unsupported layout")
        require(source.is_file() and source.stat().st_size, f"missing installed kernel: {source}")
        kernels[owner] = [builtin.parent.name, str(source), digest(source)]
    require(kernels, "no installed kernels found")
    require(fallback in ("", "no", "yes") or fallback in kernels, "unsupported MKINITCPIO_FALLBACK")
    return {"machine": machine, "kernels": kernels, "fallback": fallback, "uki": uki == "yes"}


def entries(config):
    stack = []
    result = []
    for line in config.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        heading = re.fullmatch(r"(/+)(.+)", line)
        if heading:
            depth = len(heading[1])
            stack = stack[:depth - 1]
            require(depth == len(stack) + 1, "unsupported menu nesting")
            entry = {"options": {}, "machine": stack[-1]["machine"] if stack else ""}
            stack.append(entry)
            result.append(entry)
        elif stack and ":" in line:
            key, value = (part.strip() for part in line.split(":", 1))
            key = key.lower()
            if key == "comment":
                for field, identifier in re.findall(r"(?:^|\s)(machine-id|kernel-id)=([^\s]+)", value):
                    field = "machine" if field == "machine-id" else "kernel"
                    require(field not in stack[-1] or not stack[-1][field] or stack[-1][field] == identifier,
                            f"ambiguous {field} identifier")
                    stack[-1][field] = identifier
            else:
                stack[-1]["options"].setdefault(key, []).append(value)
    return result


def uki_sections(path):
    """Read bounded PE section payloads, excluding file-alignment padding.

    This checks the payload layout, not EFI signatures or firmware acceptance.
    Certificates/other trailing data need not be interpreted to read sections.
    """
    data = path.read_bytes()
    require(len(data) >= 64 and data[:2] == b"MZ", f"invalid PE DOS header: {path}")
    pe = struct.unpack_from("<I", data, 60)[0]
    require(64 <= pe <= len(data) - 24 and data[pe:pe + 4] == b"PE\0\0",
            f"invalid PE/COFF header: {path}")
    count = struct.unpack_from("<H", data, pe + 6)[0]
    optional_size = struct.unpack_from("<H", data, pe + 20)[0]
    optional = pe + 24
    table = optional + optional_size
    require(count and optional_size >= 2 and table + count * 40 <= len(data),
            f"truncated PE section table: {path}")
    magic = struct.unpack_from("<H", data, optional)[0]
    require(magic in (0x10B, 0x20B) and optional_size >= (96 if magic == 0x10B else 112),
            f"unsupported PE optional header: {path}")
    image_size, headers_size = struct.unpack_from("<II", data, optional + 56)
    require(table + count * 40 <= headers_size <= len(data) and image_size >= headers_size,
            f"invalid PE header bounds: {path}")
    sections, raw_ranges, virtual_ranges = {}, [], []
    for index in range(count):
        offset = table + index * 40
        name = data[offset:offset + 8].rstrip(b"\0")
        size, address, raw_size, raw_offset = struct.unpack_from("<IIII", data, offset + 8)
        if raw_size:
            require(headers_size <= raw_offset and raw_offset + raw_size <= len(data),
                    f"out-of-bounds PE section {name!r}: {path}")
            raw_ranges.append((raw_offset, raw_offset + raw_size))
        mapped_size = max(size, raw_size)
        if mapped_size:
            require(headers_size <= address and address + mapped_size <= image_size,
                    f"invalid PE virtual section {name!r}: {path}")
            virtual_ranges.append((address, address + mapped_size))
        if name in (b".linux", b".initrd"):
            require(name not in sections and 0 < size <= raw_size,
                    f"duplicate, empty, or unbacked PE section {name!r}: {path}")
            sections[name] = data[raw_offset:raw_offset + size]
    for ranges in (raw_ranges, virtual_ranges):
        ranges.sort()
        require(all(left[1] <= right[0] for left, right in pairwise(ranges)),
                f"overlapping PE sections: {path}")
    require(sections.keys() == {b".linux", b".initrd"}, f"missing .linux/.initrd PE section: {path}")
    return sections


def verify_initramfs(image, version):
    archive = subprocess.run(
        ["lsinitcpio", "--cpio", "--list", "--nocolor", str(image)],
        capture_output=True, text=True, check=True,
    )
    contents = {line.removeprefix("./").rstrip("/") for line in archive.stdout.splitlines()}
    versions = {match[1] for item in contents
                if (match := re.match(r"(?:usr/)?lib/modules/([^/]+)(?:/|$)", item))}
    require("init" in contents and versions == {version}, f"incomplete or wrong-kernel initramfs: {image}")


def verify(boot, expected, output, fallback, uki):
    require(inventory(fallback, uki) == expected, "installed kernel inventory or rebuild mode changed during rebuild")
    config = boot / "limine.conf"
    require(config.is_file() and config.stat().st_size, f"missing or empty config: {config}")
    generated = entries(config.read_text())
    output = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", output)
    builds = re.split(r"(?m)^Building (initramfs|fallback initramfs|UKI|UKI fallback) for ", output)

    def resource(value):
        match = re.fullmatch(r"boot\(\):(/[^#]+)(?:#([0-9a-fA-F]{128}))?", value)
        if match is None or any(char in value for char in "$%{}"):
            raise ValueError(f"unsupported resource: {value}")
        path = (boot / match[1].lstrip("/")).resolve()
        require(path.is_relative_to(boot) and path.is_file() and path.stat().st_size,
                f"missing, empty, or out-of-ESP artifact: {value}")
        if match[2]:
            require(digest(path) == match[2].lower(), f"artifact checksum mismatch: {path}")
        return path

    for name, (version, source, kernel_hash) in expected["kernels"].items():
        variants = [name]
        if expected["fallback"] in ("yes", name):
            variants.append(name + "-fallback")
        # Also validate an existing fallback even when it was not requested.
        if any(item.get("kernel") == name + "-fallback" and item["machine"] == expected["machine"]
               for item in generated):
            variants = list(dict.fromkeys([*variants, name + "-fallback"]))
        for variant in variants:
            matches = [item["options"] for item in generated
                       if item["machine"] == expected["machine"] and item.get("kernel") == variant]
            require(len(matches) == 1, f"missing or ambiguous generated kernel entry: {variant}")
            options = matches[0]
            uki = expected["uki"]
            protocols = (["efi"], ["efi_chainload"], ["uefi"]) if uki else (["linux"],)
            require(options.get("protocol") in protocols, f"unsupported protocol for {variant}")
            allowed_paths = ("image_path",) if uki else ("kernel_path", "module_path")
            require(not any(key.endswith("_path") and key not in allowed_paths
                            or key == "efi_dtb" for key in options), f"unsupported resource layout for {variant}")
            paths = options.get("path", []) + options.get("image_path" if uki else "kernel_path", [])
            require(len(paths) == 1, f"ambiguous kernel/EFI path for {variant}")
            payload = resource(paths[0])
            if uki:
                sections = uki_sections(payload)
                require(hashlib.blake2b(sections[b".linux"]).hexdigest() == kernel_hash,
                        f"UKI kernel differs from {source}")
                with tempfile.TemporaryDirectory(prefix="chezmoi-uki-") as temporary:
                    image = Path(temporary) / "initramfs"
                    image.write_bytes(sections[b".initrd"])
                    verify_initramfs(image, version)
            else:
                require(digest(payload) == kernel_hash, f"deployed kernel differs from {source}")
                modules = options.get("module_path", [])
                require(len(modules) == 1, f"unsupported initramfs layout for {variant}")
                verify_initramfs(resource(modules[0]), version)
            if variant == name or expected["fallback"] in ("yes", name):
                progress = name + " (" + version + ")"
                kinds = ("UKI", "UKI fallback") if uki else ("initramfs", "fallback initramfs")
                kind = kinds[0 if variant == name else 1]
                require(any(label == kind and block.startswith(progress + "\n") and
                            re.search(r"(?m)^==> Initcpio image generation successful\s*$", block) and
                            (not uki or re.search(r"(?m)^==> Unified kernel image generation successful\s*$", block))
                            for label, block in zip(builds[1::2], builds[2::2])),
                        f"no successful build reported for {variant}")
    print("Verified generated boot entries, kernel payloads, and initramfs archives")


def verify_enrollment(boot):
    # Match the integration's architecture-based target, never a firmware setting.
    arch = os.uname().machine
    suffix = {"x86_64": "x64", "aarch64": "aa64", "riscv64": "riscv64",
              "loongarch64": "loongarch64"}.get(arch)
    if re.fullmatch(r"i.86", arch):
        suffix = "ia32"
    require(suffix, "unsupported Limine EFI architecture")
    image = boot / "EFI/limine" / f"limine_{suffix}.efi"
    data = image.read_bytes()
    marker = b"++CONFIG_B2SUM_SIGNATURE++"
    require(data.count(marker) == 1, f"missing or ambiguous checksum slot: {image}")
    start = data.index(marker) + len(marker)
    enrolled = data[start:start + 128].decode("ascii")
    require(re.fullmatch(r"[0-9a-fA-F]{128}", enrolled), f"invalid checksum slot: {image}")
    require(enrolled != "0" * 128 and enrolled.lower() == digest(boot / "limine.conf"),
            "deployed EFI checksum does not match the final Limine config")
    print("Verified the final Limine config checksum without modifying the EFI image")


try:
    mode, directory = sys.argv[1:3]
    if mode == "enrollment":
        verify_enrollment(Path(directory).resolve())
    else:
        fallback, uki = sys.argv[3:5]
        if mode == "inventory":
            print(json.dumps(inventory(fallback, uki)))
        else:
            require(mode == "verify", "unknown verification mode")
            verify(Path(directory).resolve(), json.loads(sys.argv[5]), sys.stdin.read(), fallback, uki)
except (OSError, ValueError, subprocess.CalledProcessError) as error:
    if isinstance(error, subprocess.CalledProcessError) and error.stderr:
        print(error.stderr, file=sys.stderr, end="")
    print(f"Limine rebuild verification failed: {error}", file=sys.stderr)
    sys.exit(1)
