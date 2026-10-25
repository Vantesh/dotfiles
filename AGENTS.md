# Engineering conventions

## Supported setup

- Target fresh installations on Arch-based distributions. Preserve existing Arch-family detection and CachyOS/Garuda behavior; add no legacy migrations or speculative hardware/OS compatibility.
- Nonpersonal setups receive baseline packages and non-secret dotfiles only. Secrets, driver selection, and opinionated system provisioning belong to personal setups.
- Keep responsibilities clear: Chezmoi owns configuration, profiles and execution triggers; Mise owns package/service declarations; Fish is the interactive shell; Python handles meaningful orchestration.
- Reapplying the new architecture must be safe and idempotent. Preserve necessary Btrfs, swapfile, hibernation, Zswap, Limine and Secure Boot protections. Do not start another phase without explicit authorization.

## Python and safety

- Write modern, readable Python for the target in `ruff.toml`. Prefer pathlib, context managers, straightforward functions and useful type annotations. Keep dependencies minimal.
- Use Ruff for linting and formatting: `ruff check .` and `ruff format --check .`. Fix real violations; avoid blanket exclusions and widespread suppressions. Format with `ruff format .`.
- Do not introduce generic runners, namespace classes, speculative abstractions or function-wrapper hell. Keep one-line operations direct; share helpers only for meaningful repeated responsibilities or invariants.
- Preserve unmanaged configuration, ownership and permissions. Avoid unnecessary rewrites. Publish important configuration atomically, create temporary files safely, clean them up, and do not follow untrusted symlinks in privileged writes.
- Use explicit subprocess argument lists and handle exit statuses. Capture only needed output; use timeouts for bounded operations while preserving interactive authentication and package-manager behavior. Propagate meaningful failures.
- Prefer sequential execution. Retain necessary locks and atomic publication for real shared-state risks; close files, descriptors and subprocess resources deterministically. Do not build hypothetical recovery or concurrency frameworks.
- Use Loguru directly for Python provisioning. Keep terminal output concise and TTY-aware, respect `NO_COLOR`, and preserve private XDG logs (0700 directories, 0600 files), rotation and retention. Keep `diagnose=False` and `backtrace=False`; never log secrets, vault responses, sensitive arguments or environments. Logging failures must not report provisioning success.
- Keep tests small and behavior-focused using the existing unittest infrastructure. Protect idempotency, profile isolation, failure propagation, secret-safe diagnostics and meaningful publication/boot/filesystem safety. Do not add test frameworks, coverage targets or tests for trivial helpers.

Run the meaningful behavioral tests and existing validation workflow before committing:

```sh
python3 -B -m unittest discover -s .github/tests -v
python3 -B .github/tests/validate.py
```

The validator also lints/formats rendered Python modifier templates. Keep functional corrections distinguishable from formatting changes where practical.

## Git and phase completion

- Use `wt` for branch/worktree management with its installed supported syntax. Continue this rebuild in `refactor/dotfiles-simplification` and its existing worktree; never modify `main`.
- Use focused Conventional Commits. Sign every commit with the existing Git configuration and immediately verify it with `git verify-commit`. Stop on signing failure; never bypass signing or weaken its configuration.
- Open one final PR only after all phases and integration validation, using `.github/pull_request_template.md`. Do not create intermediate PRs.
- End each phase in the final response with: **What changed**, **Why it changed**, **What I should know**, **Validation**, **Git status**, and **Next phase**. Explain behavior, decisions and maintenance implications; report actual tests and limitations, commits/signature verification, worktree status and unchanged `main`. Do not create review documents by default.
- Write naturally, developer to developer. Never refer to the repository owner as “the user” or narrate requests/confirmations. Preserve applicable nested `AGENTS.md` guidance.
