"""Verify immutable Git checkouts and downloaded artifacts before use."""

import hashlib
import hmac
import re
import subprocess
from pathlib import Path

_COMMIT = re.compile(r"[0-9a-f]{40}")
_SHA256 = re.compile(r"[0-9a-f]{64}")


def verify_sha256(path: Path, expected: str, label: str) -> None:
    """Fail closed unless *path* matches the committed SHA-256 checksum."""
    checksum = expected.strip().lower()
    if not _SHA256.fullmatch(checksum):
        raise ValueError(f"Missing or invalid SHA-256 checksum for {label}.")
    with path.open("rb") as stream:
        actual = hashlib.file_digest(stream, "sha256").hexdigest()
    if not hmac.compare_digest(actual, checksum):
        raise ValueError(f"SHA-256 checksum mismatch for {label}.")


def verify_git_commit(repository: Path, expected: str, label: str) -> None:
    """Fail closed unless the checked-out commit is the pinned full SHA."""
    commit = expected.strip().lower()
    if not _COMMIT.fullmatch(commit):
        raise ValueError(f"Missing or invalid Git commit for {label}.")
    result = subprocess.run(
        ["git", "-C", str(repository), "rev-parse", "--verify", "HEAD^{commit}"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    actual = result.stdout.strip()
    if actual != commit:
        raise ValueError(f"Git commit mismatch for {label}: expected {commit}, got {actual}.")
