#!/usr/bin/python3 -B
"""Apply the personal sudo Defaults and faillock policy without replacing unrelated settings."""

import os
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import traceback
from pathlib import Path
from typing import cast

from loguru import logger

SUDOERS_DIR = Path("/etc/sudoers.d")
SUDOERS = Path("/etc/sudoers")
FAILLOCK_CONF = Path("/etc/security/faillock.conf")
FRAGMENTS = {
    "timeout": "Defaults passwd_timeout=0\n",
    "passwd_tries": "Defaults passwd_tries=10\n",
    "keep_env": 'Defaults env_keep += "EDITOR VISUAL"\n',
}


def configure_faillock(content: str) -> str:
    spaced = re.search(r"^\s*[^#;\s][^=\s]*\s+=\s+", content, re.MULTILINE) is not None
    for key, value in {"deny": "20", "unlock_time": "120", "fail_interval": "900"}.items():
        assignment = f"{key} = {value}" if spaced else f"{key}={value}"
        pattern = rf"^[ \t]*#?[ \t]*{key}[ \t]*=.*$"
        if re.search(pattern, content, re.MULTILINE):
            content = re.sub(pattern, assignment, content, flags=re.MULTILINE)
        else:
            content += f"\n{assignment}\n"
    return content


def apply_policy() -> None:
    from lib.policy_files import publish_config, rollback_configs, snapshot_config

    if os.geteuid() != 0:
        raise PermissionError("Policy publication requires root privileges.")
    if SUDOERS_DIR.is_symlink():
        raise ValueError(f"Refusing symlink directory: {SUDOERS_DIR}")
    SUDOERS_DIR.mkdir(mode=0o750, exist_ok=True)
    info = SUDOERS_DIR.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError(f"Sudoers directory must be root-owned and not writable: {SUDOERS_DIR}")
    with tempfile.TemporaryDirectory(prefix="chezmoi-sudo-") as directory:
        work = Path(directory)
        configs = [snapshot_config(SUDOERS_DIR / name, work / name) for name in FRAGMENTS]
        configs.append(snapshot_config(FAILLOCK_CONF, work / "faillock"))
        try:
            # Defaults fragments are self-contained; validate all candidates and
            # the existing full policy before activating any fragment.
            for name, content in FRAGMENTS.items():
                candidate = work / f"{name}.candidate"
                _ = candidate.write_text(content)
                candidate.chmod(0o440)
                _ = subprocess.run(
                    ["visudo", "-c", "-f", str(candidate)], check=True, stdout=subprocess.DEVNULL
                )
            _ = subprocess.run(
                ["visudo", "-c", "-f", str(SUDOERS)], check=True, stdout=subprocess.DEVNULL
            )
            changed: list[str] = []
            for config, content in zip(configs[:-1], FRAGMENTS.values(), strict=True):
                if publish_config(config, content.encode(), mode=0o440):
                    changed.append(f"Configured sudoers fragment {config.path.name}.")
            faillock = configs[-1]
            if publish_config(faillock, configure_faillock(faillock.backup.read_text()).encode()):
                changed.append("Configured faillock: deny=20, unlock_time=120, fail_interval=900.")
            _ = subprocess.run(
                ["visudo", "-c", "-f", str(SUDOERS)], check=True, stdout=subprocess.DEVNULL
            )
        except BaseException:
            rollback_configs(configs)
            raise
        for message in changed:
            print(message)


def terminate(_signum: int, _frame: object) -> None:
    raise SystemExit(143)


def main() -> int:
    privileged = sys.argv[1:2] == ["--apply-policy"]
    if privileged and len(sys.argv) != 4:
        print(
            "ERROR: Privileged policy setup requires its source path and profile.", file=sys.stderr
        )
        return 1
    personal = sys.argv[3] if privileged else os.environ.get("DOTFILES_PERSONAL_ENABLED")
    if personal == "0":
        return 0
    if personal != "1":
        print(
            "ERROR: DOTFILES_PERSONAL_ENABLED must be '0' or '1'; run through Chezmoi.",
            file=sys.stderr,
        )
        return 1
    # Carry validated context as arguments: sudo need not preserve scriptEnv.
    try:
        source_dir = Path(sys.argv[2]) if privileged else Path(os.environ["CHEZMOI_SOURCE_DIR"])
    except KeyError:
        print("ERROR: Chezmoi must supply CHEZMOI_SOURCE_DIR.", file=sys.stderr)
        return 1
    if not source_dir.is_absolute():
        print("ERROR: Chezmoi must supply an absolute CHEZMOI_SOURCE_DIR.", file=sys.stderr)
        return 1
    sys.path.insert(0, str(source_dir / ".chezmoitemplates"))
    _ = signal.signal(signal.SIGTERM, terminate)
    if privileged:
        try:
            apply_policy()
            return 0
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            traceback.print_exc()
            return error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        except KeyboardInterrupt:
            return 130
    from lib.provision_logging import configure_logging

    file_sink = None
    try:
        file_sink = configure_logging()
        if sys.argv[1:]:
            raise ValueError("Unsupported sudo policy arguments.")
        if os.geteuid() == 0:
            raise ValueError(
                "Run policy setup as the regular account; sudo publishes system files."
            )
        for command in ("sudo", "visudo"):
            if shutil.which(command) is None:
                raise FileNotFoundError(f"Required command missing: {command}")
        # Authenticate with native terminal I/O before capturing the unattended
        # privileged operation. One synchronous process owns its entire update.
        _ = subprocess.run(["sudo", "-v"], check=True)
        result = subprocess.run(
            [
                "sudo",
                "-n",
                sys.executable,
                "-B",
                str(Path(__file__).resolve()),
                "--apply-policy",
                str(source_dir),
                personal,
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        for message in result.stdout.splitlines():
            logger.info(message)
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        status = error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        try:
            if isinstance(error, subprocess.CalledProcessError):
                diagnostic = cast("str | None", error.stderr)
                reason = (
                    diagnostic.strip().splitlines()[-1]
                    if diagnostic and diagnostic.strip()
                    else " ".join(cast("list[str]", error.cmd))
                )
                logger.error("Sudo/faillock policy failed (exit {}): {}", status, reason)
                if diagnostic:
                    logger.debug("Policy diagnostic:\n{}", diagnostic.rstrip())
            else:
                logger.opt(exception=True).error("Sudo/faillock policy stopped: {}", error)
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return status
    except KeyboardInterrupt:
        logger.warning("Sudo/faillock policy interrupted; reapply when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
