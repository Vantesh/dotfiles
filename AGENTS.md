# Engineering conventions

## Supported setup

- Target fresh installations on Arch-based distributions. Preserve existing Arch-family detection and CachyOS/Garuda behavior; add no legacy migrations or speculative hardware/OS compatibility.
- Both profiles receive common packages, non-secret dotfiles, common system/user services, Fish as the login shell and common desktop preferences/assets (including public font, icon and cursor downloads). Secrets, personal-only services, hardware, filesystem/boot provisioning and firewall configuration remain personal-only.
- Keep responsibilities clear: Chezmoi owns configuration, profiles and execution triggers; Mise owns package/service declarations; Fish is the interactive shell; direct Python scripts in `home/.chezmoiscripts/linux/` own provisioning workflows. Shared Python helpers live in `home/.chezmoitemplates/lib/`; `.chezmoiscripts/` accepts scripts only. Keep the initial missing-prerequisite bootstrap in shell.
- Reapplying the new architecture must be safe and idempotent. Preserve necessary Btrfs, swapfile, hibernation, Zswap, Limine and Secure Boot protections. Do not start another phase without explicit authorization.

## Python and safety

- Write modern, readable Python 3.14, matching `ruff.toml` and `pyproject.toml`. Prefer pathlib, context managers, straightforward functions and useful type annotations. Keep dependencies minimal.
- Use BasedPyright in recommended mode for static type checking and Ruff for linting and formatting: `ruff check .` and `ruff format --check .`. Fix real violations; avoid blanket exclusions and widespread suppressions. Format with `ruff format .`.
- Do not introduce generic runners, namespace classes, speculative abstractions or function-wrapper hell. Keep one-line operations direct; share helpers only for meaningful repeated responsibilities or invariants.
- Preserve unmanaged configuration, ownership and permissions. Avoid unnecessary rewrites. Publish important configuration atomically, create temporary files safely, clean them up, and do not follow untrusted symlinks in privileged writes.
- Use explicit subprocess argument lists and handle exit statuses. Capture only needed output; use timeouts for bounded operations while preserving interactive authentication and package-manager behavior. Propagate meaningful failures.
- Prefer sequential execution. Retain necessary locks and atomic publication for real shared-state risks; close files, descriptors and subprocess resources deterministically. Do not build hypothetical recovery or concurrency frameworks.
- Use Loguru directly for Python provisioning. Keep terminal output concise and TTY-aware, respect `NO_COLOR`, and preserve private XDG logs (0700 directories, 0600 files), rotation and retention. Keep `diagnose=False` and `backtrace=False`; never log secrets, vault responses, sensitive arguments or environments. Logging failures must not report provisioning success.
- pytest is the sole Python test runner. New tests use native pytest functions and ordinary assertions; retained unittest tests are temporary and migrate incrementally alongside relevant code. Keep fixtures/utilities small and test only supported behavior, real requirements and meaningful failures: idempotency, profile isolation, secret-safe diagnostics, failure propagation and necessary publication/boot/filesystem safety. Do not pursue test counts, coverage targets, hypothetical matrices or tests for trivial helpers.

Contributors manage development tools themselves. The repository configures and validates tools; it never installs, bootstraps or substitutes them. Require Python 3.14, Ruff, BasedPyright and pytest on PATH; report missing tools by executable name and fail without installing anything.

Run `python3 -B .github/tests/validate.py` before committing Python changes. It coordinates Ruff, BasedPyright, pytest and the retained shell/template/configuration checks, running the suite once. The independent tool commands are documented in `.github/README.md`. Report missing or unsupported tools; never claim an unavailable check passed.

Validate both profiles of Python run templates as well as settings modifiers; keep rendered paths unique and Python out of Bash checks. Reject zero-file type checks. Verify hidden-source discovery with `basedpyright --verbose`; use `useDefaultExcludes = false` only when supported by the installed checker. Keep functional corrections distinguishable from formatting changes where practical.

## Git and phase completion

- Use `wt` for branch/worktree management with its installed supported syntax. Continue this rebuild in `refactor/dotfiles-simplification` and its existing worktree; never modify `main`.
- Use focused Conventional Commits. Sign every commit with the existing Git configuration and immediately verify it with `git verify-commit`. Stop on signing failure; never bypass signing or weaken its configuration.
- Open one final PR only after all phases and integration validation, using `.github/pull_request_template.md`. Do not create intermediate PRs.
- End each phase in the final response with: **What changed**, **Why it changed**, **What I should know**, **Validation**, **Git status**, and **Next phase**. Explain behavior, decisions and maintenance implications; report actual tests and limitations, commits/signature verification, worktree status and unchanged `main`. Do not create review documents by default.
- Write naturally, developer to developer. Never refer to the repository owner as “the user” or narrate requests/confirmations. Preserve applicable nested `AGENTS.md` guidance.
