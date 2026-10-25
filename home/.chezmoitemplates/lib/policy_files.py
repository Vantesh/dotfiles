"""Snapshot and guarded atomic publication for the two personal policy workflows."""

import os
import shutil
import signal
import stat
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass
class PolicyFile:
    path: Path
    backup: Path
    original: os.stat_result | None
    published: os.stat_result | None = None
    published_content: bytes | None = None


def inspect_file(path: Path) -> os.stat_result | None:
    parent = path.parent.lstat()
    if not stat.S_ISDIR(parent.st_mode) or parent.st_uid != 0 or parent.st_mode & 0o022:
        raise ValueError(
            f"Configuration directory must be root-owned and not writable: {path.parent}"
        )
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(info.st_mode):
        raise ValueError(f"Refusing non-regular configuration: {path}")
    return info


def same_state(left: os.stat_result | None, right: os.stat_result | None) -> bool:
    if left is None or right is None:
        return left is right
    return all(
        getattr(left, key) == getattr(right, key)
        for key in (
            "st_dev",
            "st_ino",
            "st_mode",
            "st_uid",
            "st_gid",
            "st_size",
            "st_mtime_ns",
            "st_ctime_ns",
        )
    )


def snapshot_config(path: Path, backup: Path) -> PolicyFile:
    initial = inspect_file(path)
    if initial is None:
        _ = backup.write_bytes(b"")
    else:
        # Preserve timestamps, modes and extended attributes; ownership is
        # explicit because these snapshots are made by the privileged process.
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(descriptor, "rb") as stream:
            if not same_state(initial, os.fstat(stream.fileno())):
                raise ValueError(f"Configuration changed while opening it: {path}")
            _ = backup.write_bytes(stream.read())
        os.chown(backup, initial.st_uid, initial.st_gid)
        shutil.copystat(path, backup, follow_symlinks=False)
    if not same_state(initial, inspect_file(path)):
        raise ValueError(f"Configuration changed while taking its snapshot: {path}")
    return PolicyFile(path, backup, initial)


def replace_config(
    path: Path,
    expected: os.stat_result | None,
    content: bytes,
    metadata: Path | None,
    mode: int | None = None,
) -> os.stat_result:
    descriptor, name = tempfile.mkstemp(prefix=f".chezmoi-{path.name}.", dir=path.parent)
    stage = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            _ = stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        if metadata is not None:
            info = metadata.stat()
            os.chown(stage, info.st_uid, info.st_gid)
            shutil.copystat(metadata, stage, follow_symlinks=False)
        else:
            stage.chmod(0o644)
        if mode is not None:
            os.chown(stage, 0, 0)
            stage.chmod(mode)
        if not same_state(expected, inspect_file(path)):
            raise ValueError(f"Configuration changed before publication; preserved {path}")
        os.replace(stage, path)
        return path.lstat()
    finally:
        stage.unlink(missing_ok=True)


def publish_config(config: PolicyFile, content: bytes, *, mode: int | None = None) -> bool:
    if not same_state(config.original, inspect_file(config.path)):
        raise ValueError(f"Configuration changed before publication; preserved {config.path}")
    if (
        config.original is not None
        and config.backup.read_bytes() == content
        and (
            mode is None
            or (
                config.original.st_uid,
                config.original.st_gid,
                stat.S_IMODE(config.original.st_mode),
            )
            == (0, 0, mode)
        )
    ):
        return False
    # Record publication before delivering an interrupt so rollback can identify
    # exactly the version this invocation activated.
    blocked = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM})
    try:
        config.published = replace_config(
            config.path, config.original, content, config.backup if config.original else None, mode
        )
        config.published_content = content
    finally:
        _ = signal.pthread_sigmask(signal.SIG_SETMASK, blocked)
    return True


def rollback_configs(configs: list[PolicyFile]) -> None:
    for config in reversed(configs):
        if config.published is None:
            continue
        try:
            if (
                not same_state(config.published, inspect_file(config.path))
                or config.path.read_bytes() != config.published_content
            ):
                raise ValueError(
                    f"Skipped rollback: configuration changed unexpectedly: {config.path}"
                )
            if config.original is None:
                config.path.unlink()
            else:
                _ = replace_config(
                    config.path, config.published, config.backup.read_bytes(), config.backup
                )
        except (OSError, ValueError) as error:
            # The invoking workflow reports the original failure and retains its
            # exit status; a rollback conflict must never overwrite another edit.
            print(f"Policy rollback: {error}", file=sys.stderr)
