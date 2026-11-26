"""Immutable pins fail closed before anything is executed or installed."""

import hashlib
import subprocess
from pathlib import Path

import pytest
from lib.artifact_verification import verify_git_commit, verify_sha256


def _git(repository: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repository), *arguments],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def _repository(path: Path) -> tuple[Path, str]:
    path.mkdir()
    _ = subprocess.run(["git", "init", "--quiet", str(path)], check=True)
    _ = _git(path, "config", "user.name", "Fixture")
    _ = _git(path, "config", "user.email", "fixture@example.invalid")
    _ = _git(path, "commit", "--quiet", "--allow-empty", "-m", "fixture")
    return path, _git(path, "rev-parse", "HEAD")


def test_committed_checksum_is_accepted(tmp_path: Path) -> None:
    artifact = tmp_path / "artifact"
    artifact.write_bytes(b"pinned content")
    digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
    verify_sha256(artifact, digest.upper(), "fixture artifact")


def test_changed_artifact_is_rejected(tmp_path: Path) -> None:
    artifact = tmp_path / "artifact"
    artifact.write_bytes(b"changed content")
    checksum = hashlib.sha256(b"original content").hexdigest()
    with pytest.raises(ValueError, match="checksum mismatch"):
        verify_sha256(artifact, checksum, "fixture artifact")


@pytest.mark.parametrize("checksum", ["", "abc", "0" * 63, "z" * 64])
def test_missing_or_invalid_checksum_is_rejected(tmp_path: Path, checksum: str) -> None:
    artifact = tmp_path / "artifact"
    artifact.write_bytes(b"content")
    with pytest.raises(ValueError, match="Missing or invalid SHA-256"):
        verify_sha256(artifact, checksum, "fixture artifact")


def test_pinned_commit_is_accepted(tmp_path: Path) -> None:
    repository, commit = _repository(tmp_path / "repository")
    verify_git_commit(repository, commit.upper(), "fixture repository")


@pytest.mark.parametrize("reference", ["main", "HEAD", "abc1234"])
def test_floating_or_short_reference_is_rejected(tmp_path: Path, reference: str) -> None:
    repository, _ = _repository(tmp_path / "repository")
    with pytest.raises(ValueError, match="Missing or invalid Git commit"):
        verify_git_commit(repository, reference, "fixture repository")


def test_unexpected_commit_is_rejected(tmp_path: Path) -> None:
    repository, _ = _repository(tmp_path / "repository")
    with pytest.raises(ValueError, match="Git commit mismatch"):
        verify_git_commit(repository, "0" * 40, "fixture repository")
