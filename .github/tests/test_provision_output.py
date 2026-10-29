"""Noninteractive provisioning diagnostics stay private and failures keep their status."""

import subprocess
import sys
from pathlib import Path
from typing import cast

import pytest
from loguru import logger


@pytest.mark.parametrize("status", [0, 23])
def test_command_output_is_logged_without_terminal_noise(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    status: int,
) -> None:
    from lib.provision_logging import configure_logging, run_logged

    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path))
    _ = configure_logging()
    command = [
        sys.executable,
        "-B",
        "-c",
        "import sys; print('routine output ✓', flush=True); "
        + "print('fatal: fixture diagnostic', file=sys.stderr); sys.exit(int(sys.argv[1]))",
        str(status),
    ]
    try:
        if status:
            with pytest.raises(subprocess.CalledProcessError) as failure:
                run_logged(command, "Clone fixture repository")
            assert failure.value.returncode == status
            assert (
                cast("str | None", failure.value.stderr)
                == "Clone fixture repository: fatal: fixture diagnostic"
            )
        else:
            run_logged(command, "Clone fixture repository")
        captured = capsys.readouterr()
        assert captured.out == captured.err == ""
        log = tmp_path / "chezmoi/logs/setup.log"
        diagnostic = log.read_text()
        assert "Clone fixture repository diagnostic:" in diagnostic
        assert "routine output ✓" in diagnostic
        assert "fatal: fixture diagnostic" in diagnostic
        assert log.stat().st_mode & 0o777 == 0o600
        assert log.parent.stat().st_mode & 0o777 == 0o700
    finally:
        logger.remove()
