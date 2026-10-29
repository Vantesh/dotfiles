"""Literal persistent Limine arguments shared with the deferred boot workflows."""

import glob
import pathlib
import re
import subprocess
import sys
from typing import cast


def main(argv: list[str]) -> None:
    mode = argv[1]
    if mode not in (
        "initramfs",
        "convert-unlock",
        "hibernation",
        "deduplicate-file",
        "fragment-file",
    ):
        raise SystemExit("Unsupported Limine command-line operation")
    hibernation = mode == "hibernation"
    deduplicate = mode == "deduplicate-file"
    kernel = "/etc/kernel/cmdline"
    managed = "/etc/limine-entry-tool.d/50-hibernation.conf"
    default = "/etc/limine-entry-tool.d/01-default.conf"
    converting = mode == "convert-unlock"
    fragment = mode == "fragment-file"
    staged: dict[str, pathlib.Path] = {}
    name = ""
    luks_uuid = mapping = filesystem_uuid = luks_device_id = ""
    if converting:
        luks_uuid, mapping, filesystem_uuid, luks_device_id, kernel_stage, default_stage = argv[2:]
        staged = {
            name: pathlib.Path(stage)
            for name, stage in ((kernel, kernel_stage), (default, default_stage))
            if stage
        }
    feature_files = {
        default,
        managed,
        "/etc/limine-entry-tool.d/20-quiet-boot.conf",
        "/etc/limine-entry-tool.d/zswap.conf",
    }
    files = (
        sorted(glob.glob("/usr/share/limine-entry-tool.d/*.conf"))
        + ["/etc/limine-entry-tool.conf"]
        + sorted(set(glob.glob("/etc/limine-entry-tool.d/*.conf")) | {default, managed})
        + ["/etc/default/limine"]
    )
    if fragment:
        name = "/etc/limine-entry-tool.d/" + argv[2]
        files = [name]
        staged = {name: pathlib.Path(argv[3])}
    records: dict[str, list[tuple[str, str]]] = {}
    locations: dict[str, list[tuple[int, int, int] | None]] = {}
    texts: dict[str, str] = {}
    default_spans: list[tuple[int, int, int, str]] = []
    baseline = False
    for name in files:
        path = pathlib.Path(name)
        records[name] = []
        locations[name] = []
        if deduplicate and name == default:
            text = pathlib.Path(argv[2]).read_bytes().decode()
        else:
            if not path.exists() and name not in staged:
                continue
            path = staged.get(name, path)
            text = path.read_bytes().decode() if converting or fragment else path.read_text()
        lines = text.splitlines(keepends=True)
        for index, raw in enumerate(lines):
            line = raw.rstrip("\r\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if name == managed and hibernation:
                if records[name] or not re.fullmatch(
                    r'KERNEL_CMDLINE\[default\]\+= "hibernate.compressor=lz4 '
                    + r'resume=UUID=[0-9a-fA-F-]+ resume_offset=[0-9]+"',
                    line,
                ):
                    raise SystemExit(
                        "Hibernation fragment contains unrelated configuration; preserve it and configure resume manually"
                    )
                records[name].append(("+=", ""))
                continue
            if not re.match(r"^\s*KERNEL_CMDLINE\[default\]", line):
                if not deduplicate and not fragment and re.match(r"^\s*KERNEL_CMDLINE\[", line):
                    raise SystemExit(
                        "Kernel-specific Limine arguments require manual boot configuration review"
                    )
                continue
            match = re.fullmatch(r"\s*KERNEL_CMDLINE\[default\]\s*(\+?=)\s*(.*?)\s*", line)
            if not match:
                raise SystemExit("Cannot verify Limine default kernel arguments")
            operator, value = match.groups()
            start, end = match.span(2)
            # Limine values are literal: remove one enclosing double-quote pair.
            # Unlike a shell, += prepends and # is not an inline comment.
            if len(value) >= 2 and value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
                start += 1
                end -= 1
            if not value.strip():
                raise SystemExit(
                    "Empty Limine defaults have an unverifiable fallback; configure resume manually"
                )
            if deduplicate and name == default:
                default_spans.append((index, start, end, value))
            records[name].append((operator, value))
            locations[name].append((index, start, end))
            if operator == "=" or name not in feature_files:
                baseline = True
        texts[name] = "".join(lines)
    if fragment:
        entries = records[name]
        params = argv[4].replace('"', r"\"")
        if len(entries) > 1 or entries and entries[0][0] != "+=":
            raise SystemExit(
                f"Preserved {name}: expected a single append-only feature directive; review independent boot configuration manually"
            )
        lines = texts[name].splitlines(keepends=True)
        if entries:
            argument = entries[0][1]
            if name == managed:
                compatible = re.fullmatch(
                    r"hibernate.compressor=lz4 resume=UUID=[0-9a-fA-F-]+ resume_offset=[0-9]+",
                    argument,
                )
            else:
                compatible = set(argument.split()) <= set(params.split()) | {"splash"}
            if not compatible:
                raise SystemExit(
                    f"Preserved {name}: custom feature arguments require manual reconciliation"
                )
            location = locations[name][0]
            if location is None:
                raise ValueError("Missing feature directive location")
            index, start, end = location
            lines[index] = lines[index][:start] + params + lines[index][end:]
            content = "".join(lines)
        else:
            content = texts[name]
            if content and not content.endswith("\n"):
                content += "\n"
            content += 'KERNEL_CMDLINE[default]+= "' + params + '"\n'
        _ = staged[name].write_bytes(content.encode())
        raise SystemExit(0)
    if not baseline:
        if not hibernation and mode not in ("initramfs", "convert-unlock"):
            raise SystemExit(
                "Set explicit persistent Limine defaults; refusing an unverified running-command-line fallback"
            )
        # Model exactly the baseline ensure_limine_cmdline_defaults will publish,
        # before it writes anything or we modify swap.
        value = staged.get(kernel, pathlib.Path(kernel)).read_text().strip()
        if not value or "\n" in value:
            raise SystemExit("No single-line persistent kernel command line")
        records[default] = [("=", value.replace('"', r"\"") if hibernation else value)] + (
            records[default] if not hibernation else []
        )
        locations[default].insert(0, None)
    marker = "__DOTFILES_HIBERNATION__"
    if hibernation:
        records[managed] = [("+=", marker)]
    value = ""
    active_sources: list[tuple[str, str, tuple[int, int, int] | None]] = []
    for name in files:
        for index, (operator, argument) in enumerate(records[name]):
            value = (argument + " " + value).strip() if operator == "+=" else argument
            if mode in ("initramfs", "convert-unlock"):
                source = kernel if not baseline and name == default and index == 0 else name
                record = (source, argument, locations[name][index])
                active_sources = [record] + active_sources if operator == "+=" else [record]
    if mode in ("initramfs", "convert-unlock"):
        for source, argument, _ in active_sources:
            legacy = re.search(r"(?<![\w.=])cryptdevice=", argument)
            eligible = source in (kernel, default) and (converting or len(argv) > 2 and argv[2])
            if re.search(r"(?<![\w.=])(?:cryptkey|crypto)=", argument) or legacy and not eligible:
                raise SystemExit(
                    f"Unsupported BusyBox unlock arguments in {source}; configure systemd early unlocking there manually; boot configuration was not changed"
                )
    if converting:
        tokens = re.compile(r'(?:[^\s"]+|"[^"]*")+')
        arguments = cast("list[str]", tokens.findall(value))
        legacy = [token for token in arguments if token.startswith("cryptdevice=")]
        source = (
            re.fullmatch(
                r"cryptdevice=((?:PART)?UUID=[0-9a-fA-F-]+):" + re.escape(mapping), legacy[0]
            )
            if len(legacy) == 1
            else None
        )
        sources = ", ".join(
            source
            for source, argument, _ in active_sources
            if re.search(r"(?<![\w.=])cryptdevice=", argument)
        )
        roots = [token[5:] for token in arguments if token.startswith("root=")]
        if (
            not luks_uuid
            or not re.fullmatch(r"[\w.+-]+", mapping)
            or not source
            or not re.fullmatch(r"[0-9]+:[0-9]+", luks_device_id)
            or value.count('"') % 2
            or "--" in arguments
            or len(roots) != 1
            or roots[0] not in ("UUID=" + filesystem_uuid, "/dev/mapper/" + mapping)
        ):
            raise SystemExit(
                f"Cannot convert installer cryptdevice in {sources}: require one unquoted cryptdevice=UUID=<uuid>:<active mapper> or cryptdevice=PARTUUID=<partuuid>:<active mapper> and matching root=; reconcile these persistent arguments manually"
            )
        expected = legacy[0]

        def block_output(*args: str) -> str:
            try:
                return subprocess.check_output(args, text=True, stderr=subprocess.PIPE).strip()
            except (OSError, subprocess.CalledProcessError) as error:
                raise SystemExit(
                    f"Cannot verify installer LUKS device in {sources} ({args[0]}); configuration was not changed"
                ) from error

        def resolve_identifier(identifier: str) -> str:
            # Scan without cached results and reject duplicate identifiers, even if
            # a /dev/disk/by-* symlink happens to select the active root device.
            devices = block_output(
                "blkid", "-c", "/dev/null", "-t", identifier, "-o", "device"
            ).splitlines()
            if len(devices) != 1:
                raise SystemExit(
                    f"Installer {identifier} in {sources} is missing or ambiguous; configuration was not changed"
                )
            device = devices[0]
            if block_output("lsblk", "-dnro", "MAJ:MIN", device) != luks_device_id:
                raise SystemExit(
                    f"Installer {identifier} in {sources} does not resolve to the active LUKS backing device; configuration was not changed"
                )
            return device

        identifier = source[1]
        device = resolve_identifier(identifier)
        if (
            block_output("blkid", "-p", "-s", "TYPE", "-o", "value", device) != "crypto_LUKS"
            or block_output("blkid", "-p", "-s", "UUID", "-o", "value", device) != luks_uuid
        ):
            raise SystemExit(
                f"Installer device in {sources} is not the verified root LUKS container; configuration was not changed"
            )
        if identifier != "UUID=" + luks_uuid:
            _ = resolve_identifier("UUID=" + luks_uuid)
        selections = any(
            token.startswith(("rd.luks.name=", "luks.name=", "rd.luks.uuid=", "luks.uuid="))
            for token in arguments
        )
        replacement = "" if selections else "rd.luks.name=" + luks_uuid + "=" + mapping
        if not selections:
            # A new UUID allowlist must not suppress independent early crypttab devices.
            table = pathlib.Path("/etc/crypttab.initramfs")
            if not table.exists():
                table = pathlib.Path("/etc/crypttab")
            if table.exists():
                for line in table.read_text().splitlines():
                    if not line.strip() or line.lstrip().startswith("#"):
                        continue
                    entry = line.split()
                    if table.name != "crypttab.initramfs" and (
                        len(entry) < 4 or "x-initrd.attach" not in entry[3].split(",")
                    ):
                        continue
                    if len(entry) < 2 or entry[:2] not in (
                        [mapping, "UUID=" + luks_uuid],
                        [mapping, "/dev/disk/by-uuid/" + luks_uuid],
                    ):
                        raise SystemExit(
                            f"Independent early unlocking in {table}; configure systemd selectors manually; crypttab was not changed"
                        )
        changes: dict[str, str] = {}
        for source, argument, location in active_sources:
            if expected not in tokens.findall(argument):
                continue
            if pathlib.Path(source).is_symlink():
                raise SystemExit(
                    f"Preserved independently linked configuration {source}; configure systemd unlocking manually"
                )
            if source == kernel:
                changes[kernel] = tokens.sub(
                    lambda match: replacement if match[0] == expected else match[0],
                    staged.get(kernel, pathlib.Path(kernel)).read_bytes().decode(),
                )
            else:
                if location is None:
                    raise ValueError("Missing active directive location")
                index, start, end = location
                lines = changes.get(default, texts[default]).splitlines(keepends=True)
                lines[index] = (
                    lines[index][:start]
                    + tokens.sub(
                        lambda match: replacement if match[0] == expected else match[0], argument
                    )
                    + lines[index][end:]
                )
                changes[default] = "".join(lines)
                # Keep an identical installer copy synchronized, leaving independent
                # or inactive kernel arguments alone.
                path = staged.get(kernel, pathlib.Path(kernel))
                if path.exists() and not pathlib.Path(kernel).is_symlink():
                    text = path.read_bytes().decode()
                    if text.strip() == argument.strip():
                        changes[kernel] = tokens.sub(
                            lambda match: replacement if match[0] == expected else match[0], text
                        )
        value = tokens.sub(lambda match: replacement if match[0] == expected else match[0], value)
        for name, text in changes.items():
            if name in staged:
                _ = staged[name].write_bytes(text.encode())
    if deduplicate:
        # Keep token spelling and all intervening bytes, including quoted values.
        tokens = re.compile(r'(?:[^\s"]+|"[^"]*")+')
        owners = {"/etc/limine-entry-tool.d/20-quiet-boot.conf", managed}
        supplied: set[str] = set()
        default_active = False
        for name in files:
            for operator, argument in records[name]:
                if operator == "=":
                    supplied.clear()
                    default_active = False
                if name == default:
                    default_active = True
                if name in owners and operator == "+=" and argument.count('"') % 2 == 0:
                    supplied.update(cast("list[str]", tokens.findall(argument)))
        effective_tokens = cast("list[str]", tokens.findall(value))
        supplied_keys = {token.lstrip('"').split("=", 1)[0].replace("-", "_") for token in supplied}
        values: dict[str, set[str]] = {}
        for token in effective_tokens:
            if "=" in token:
                key = token.lstrip('"').split("=", 1)[0].replace("-", "_")
                values.setdefault(key, set()).add(token)
        conflicts = {
            key for key, choices in values.items() if len(choices) > 1 and key in supplied_keys
        }
        # These bare options compete for the console loglevel too.
        if "quiet" in supplied and "debug" in {token.strip('"') for token in effective_tokens}:
            conflicts.add("quiet/debug")
        for key in sorted(conflicts):
            print(
                "WARNING: conflicting " + key + " settings; leaving 01-default.conf unchanged",
                file=sys.stderr,
            )
        lines = texts.get(default, "").splitlines(keepends=True)
        if (
            default_active
            and not conflicts
            and value.count('"') % 2 == 0
            and "--" not in {token.strip('"') for token in effective_tokens}
        ):
            for index, start, end, argument in default_spans:
                replacement = tokens.sub(
                    lambda match: "" if match[0] in supplied else match[0], argument
                )
                if replacement.strip():
                    lines[index] = lines[index][:start] + replacement + lines[index][end:]
        content = "".join(lines)
        _ = pathlib.Path(argv[2]).write_bytes(content.encode())
        raise SystemExit(0)
    if hibernation and marker not in value.split():
        raise SystemExit("Later Limine defaults override hibernation; configure resume manually")
    print(value.replace(marker, "").strip() if hibernation else value)


if __name__ == "__main__":
    main(sys.argv)
